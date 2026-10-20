// line-board Pane 的線群組：每條線一個可折疊群組，標題列為 Button（▸／▾、線號、session 與狀態、目標、活動計數），
// 展開後依序列出派發列、閘門票與佇列列；對不到線的派發歸最後的「其他」群組。renderGroup 是各群組共用的可折疊外框，
// register.tsx 的「各 session」「合併閘門」兩區塊也用它。元素由 register.tsx 以 $.ui.resolve(e) 取得後傳入；分組經 parse.ts 匯出。

import type { BoxProps, ButtonProps, ElementConstructor, RenderChildren, TextProps } from 'claude-code'

import type { GroupOverrides, LaneGroup, LanesResult, ReadyBoard, SessionsResult, TicketStatus } from '../types'
import { dispatchNotice, dispatchRowsOf } from './dispatchView'
import {
  DISPATCH_TICKET_PATH,
  GROUP_INDENT,
  OTHER_LANE_LABEL,
  formatActivity,
  formatGateTicket,
  formatGroupDispatchRow,
  formatGroupTitle,
  formatQueueRow,
  groupBodyKey,
  groupToggleKey,
  isDefaultExpanded,
  isGroupExpanded,
  laneGroups,
  laneSessionStatus,
} from './parse'

/** 繪製群組所需的元素：由 register.tsx 以 $.ui.resolve(e) 取得。 */
export type Elements = {
  Box: ElementConstructor<BoxProps>
  Text: ElementConstructor<TextProps>
  Button: ElementConstructor<ButtonProps>
}

/** 按下群組標題列：isOpen 為按下當時的展開狀態。由 register.tsx 寫入 $.state 的手動狀態。 */
export type ToggleGroup = (id: string, isOpen: boolean) => void

/** 一個可折疊群組的外框：群組 id、標題列各段、是否展開、是否有活動（無活動的標題列以淡色顯示）。 */
export type GroupFrame = { id: string; title: readonly string[]; isOpen: boolean; isActive: boolean }

/** 底部區塊（各 session、合併閘門）的外框：標題列只有名稱，預設展開，使用者按過後依手動狀態。 */
export function sectionFrame(id: string, title: string, overrides: GroupOverrides): GroupFrame {
  return { id, title: [title], isOpen: isGroupExpanded(id, true, overrides), isActive: true }
}

/** 可折疊外框：標題列為 Button，按下切換；展開時其後接縮排的內容 Box，收合時只有標題列一行。 */
export function renderGroup({ Box, Button }: Elements, frame: GroupFrame, onToggle: ToggleGroup, body: () => RenderChildren) {
  const header = (
    <Button key={groupToggleKey(frame.id)} plain dimColor={!frame.isActive} onPress={() => onToggle(frame.id, frame.isOpen)}>
      {formatGroupTitle(frame.title, frame.isOpen)}
    </Button>
  )
  if (!frame.isOpen) return header
  return [
    header,
    <Box key={groupBodyKey(frame.id)} flexDirection="column" paddingLeft={GROUP_INDENT}>
      {body()}
    </Box>,
  ]
}

/** 線群組區：349 與派發紀錄的提示行在最上方，其後依線號排列各線群組，「其他」最後。 */
export function renderLaneGroups(elements: Elements, board: ReadyBoard, overrides: GroupOverrides, onToggle: ToggleGroup) {
  const rows = dispatchRowsOf(board)
  const groups = laneGroups(board.lanes.kind === 'ok' ? board.lanes.lanes : [], rows, {
    sessions: board.sessions.kind === 'ok' ? board.sessions.sessions : [],
    tickets: board.tickets,
    holders: board.mergeLog.kind === 'ok' ? board.mergeLog.holders : [],
  })
  return [
    ...lanesNotice(elements.Text, board.lanes),
    ...dispatchNotice(elements.Text, board, rows),
    ...groups.map(group => renderLaneGroup(elements, board, group, overrides, onToggle)),
  ]
}

/** 349 的兩種提示：讀不到為「解析失敗」，讀得到但沒有現行佇列行為「349 尚無現行佇列行」。 */
function lanesNotice(Text: ElementConstructor<TextProps>, lanes: LanesResult) {
  if (lanes.kind === 'error') return [<Text color="red">解析失敗：讀取 {DISPATCH_TICKET_PATH} 時發生錯誤（{lanes.message}）</Text>]
  return lanes.lanes.length === 0 ? [<Text color="yellow">349 尚無現行佇列行</Text>] : []
}

function renderLaneGroup(elements: Elements, board: ReadyBoard, group: LaneGroup, overrides: GroupOverrides, onToggle: ToggleGroup) {
  const { Text } = elements
  const isDefaultOpen = isDefaultExpanded(group.activity)
  const isOpen = isGroupExpanded(group.id, isDefaultOpen, overrides)
  const frame = { id: group.id, title: groupTitle(board.sessions, group), isOpen, isActive: isDefaultOpen }
  // 各行的 key：派發列以序號（同一張票可能有多個代理人），閘門票以票號，佇列列每群組一行
  return renderGroup(elements, frame, onToggle, () => [
    ...group.dispatches.map((row, index) => (
      <Text key={`${group.id}:dispatch:${index}`} wrap="truncate-middle">
        {formatGroupDispatchRow(row, board.readAtMs)}
      </Text>
    )),
    ...group.gateTickets.map(gate => (
      <Text key={`${group.id}:gate:${gate.serial}`} color="yellow">
        {formatGateTicket(gate)}
      </Text>
    )),
    ...queueRow(Text, group, board.tickets),
  ])
}

/** 標題列各段：線號、session 名稱與狀態、目標、活動計數；「其他」群組只有名稱與活動計數。空段由 formatGroupTitle 略過。 */
function groupTitle(sessions: SessionsResult, group: LaneGroup): string[] {
  const activity = formatActivity(group.activity)
  if (group.lane === null) return [OTHER_LANE_LABEL, activity]
  const { lane, session, goal } = group.lane
  return [`L${lane}`, `${session ?? '（未標 session）'}${laneStatusLabel(sessions, session)}`, laneGoalLabel(goal), activity]
}

/** 佇列列：線有未完成的票時一行（completed 的票不列）；「其他」群組沒有佇列列。 */
function queueRow(Text: ElementConstructor<TextProps>, group: LaneGroup, tickets: readonly TicketStatus[]) {
  const text = group.lane === null ? null : formatQueueRow(group.lane.tokens, tickets)
  return text === null ? [] : [<Text key={`${group.id}:queue`}>{text}</Text>]
}

/** 標題列的 `目標：<文字>`；沒有目標時為空段。hot reload 後舊 snapshot 的線沒有 goal 欄（undefined），同樣為空段。 */
function laneGoalLabel(goal: string | null | undefined): string {
  return goal === null || goal === undefined ? '' : `目標：${goal}`
}

/** 標題列 session 名稱旁的 `［狀態］`；沒標 session 時不顯示，session 狀態讀取失敗時標「狀態不明」。 */
function laneStatusLabel(sessions: SessionsResult, name: string | null): string {
  if (name === null) return ''
  if (sessions.kind === 'error') return '［狀態不明］'
  return `［${laneSessionStatus(sessions.sessions, name)}］`
}
