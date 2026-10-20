// 版面：以線分組的可折疊群組——每條線一個群組、對不到線的派發歸「其他」；群組的活動計數、預設展開、
// 手動切換後的展開狀態，以及標題列與內容各行的顯示文字。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；展開狀態的讀寫由 register.tsx 負責。

import type {
  DispatchContext,
  DispatchRow,
  GateTicket,
  GroupActivity,
  GroupOverrides,
  Lane,
  LaneGroup,
  QueueToken,
  TicketStatus,
} from '../types'
import { parseIsoMs } from './dispatch'
import { formatQueue } from './lanes'
import { shortBranch } from './mergeGate'
import { findSessionByName } from './sessions'
import { formatAge } from './shared'

/** 「其他」群組（收容對不到線的派發）與底部兩個區塊的群組 id；線的群組 id 由 laneGroupId 組出。 */
export const OTHER_GROUP_ID = 'other'
export const SESSIONS_GROUP_ID = 'sessions'
export const MERGE_GATE_GROUP_ID = 'mergeGate'

/** 群組內容相對標題列的縮排（欄）。 */
export const GROUP_INDENT = 2

/** 線的群組 id：`lane:<n>`，也是展開狀態的鍵。 */
export function laneGroupId(lane: number): string {
  return `lane:${lane}`
}

/** 群組標題列 Button 的 key：計數會變，key 只含群組 id，按鍵的位址才穩定。 */
export function groupToggleKey(id: string): string {
  return `toggle:${id}`
}

/** 群組內容 Box 的 key；收合時不畫這個 Box。 */
export function groupBodyKey(id: string): string {
  return `body:${id}`
}

/** 票已完成的 status 值：不算排隊票。與 dispatch.ts 判定「票已完成不列」的值相同。 */
const COMPLETED_STATUS = 'completed'

/** session 停下來等用戶時的 status 值。 */
const WAITING_STATUS = 'waiting'

/** 分組依據：存活的 session、主 checkout 的票狀態、閘門持有者（sessions 讀不到時傳空陣列）。 */
export type LayoutContext = Omit<DispatchContext, 'lanes'>

/**
 * 每條線一個群組（依傳入的順序，即線號排序），派發列歸到 lane 相同的群組；
 * 對不到任何線的派發列歸最後的「其他」群組，沒有這種派發時不產生「其他」。
 */
export function laneGroups(lanes: readonly Lane[], rows: readonly DispatchRow[], context: LayoutContext): LaneGroup[] {
  const groups = lanes.map(lane => laneGroup(lane, rows.filter(row => row.lane === lane.lane), context))
  const others = rows.filter(row => !lanes.some(lane => lane.lane === row.lane))
  if (others.length > 0) {
    groups.push({ id: OTHER_GROUP_ID, lane: null, dispatches: others, gateTickets: [], activity: activityOf(others, [], false, 0) })
  }
  return groups
}

function laneGroup(lane: Lane, dispatches: DispatchRow[], context: LayoutContext): LaneGroup {
  const gateTickets = laneGateTickets(lane, dispatches, context)
  const isWaiting = lane.session !== null && findSessionByName(context.sessions, lane.session)?.status === WAITING_STATUS
  const queued = queueTickets(lane.tokens).filter(id => statusOf(context.tickets, id) !== COMPLETED_STATUS).length
  return { id: laneGroupId(lane.lane), lane, dispatches, gateTickets, activity: activityOf(dispatches, gateTickets, isWaiting, queued) }
}

function activityOf(dispatches: readonly DispatchRow[], gateTickets: readonly GateTicket[], isWaiting: boolean, queued: number): GroupActivity {
  const gateRows = dispatches.filter(row => row.stage === '閘門').length
  return { dispatching: dispatches.length, inGate: gateRows + gateTickets.length, isWaiting, queued }
}

/**
 * 佇列中正持有閘門的票：閘門持有者的分支為 `feat/<完整票號>`（shortBranch 縮成完整票號）。
 * 同組已有該票階段為閘門的派發列時不重複列；worktree 代理人的分支由派發列的階段表達，不在此判定。
 */
function laneGateTickets(lane: Lane, dispatches: readonly DispatchRow[], context: LayoutContext): GateTicket[] {
  const shownInGate = dispatches.filter(row => row.stage === '閘門').map(row => row.task)
  const gates: GateTicket[] = []
  for (const token of lane.tokens) {
    if (token.kind !== 'ticket' || shownInGate.includes(token.serial) || gates.some(gate => gate.serial === token.serial)) continue
    const holder = context.holders.find(item => item.branch.startsWith('feat/') && shortBranch(item.branch) === token.id)
    if (holder !== undefined) gates.push({ serial: token.serial, since: holder.since })
  }
  return gates
}

/** 佇列中的完整票號，依出現順序（重複出現的票照計，與佇列列顯示的次數一致）。 */
function queueTickets(tokens: readonly QueueToken[]): string[] {
  return tokens.flatMap(token => (token.kind === 'ticket' ? [token.id] : []))
}

function statusOf(tickets: readonly TicketStatus[], id: string): string | undefined {
  return tickets.find(ticket => ticket.id === id)?.status
}

/** 預設展開：有派發中代理人、該線的 session 為 waiting、或有票在閘門中，任一成立；只有排隊票不算活動。 */
export function isDefaultExpanded(activity: GroupActivity): boolean {
  return activity.dispatching > 0 || activity.isWaiting || activity.inGate > 0
}

/** 群組是否展開：使用者按過的群組以其手動狀態為準，否則依預設。 */
export function isGroupExpanded(id: string, isDefaultOpen: boolean, overrides: GroupOverrides): boolean {
  return overrides[id] ?? isDefaultOpen
}

/** 按下群組標題列後的手動狀態：該群組記成目前狀態的相反，其他群組不變；回傳新物件。 */
export function toggledOverrides(overrides: GroupOverrides, id: string, isOpen: boolean): GroupOverrides {
  return { ...overrides, [id]: !isOpen }
}

/** 標題列的活動計數：`N 派發中`、`N 閘門`、`等你處理`、`N 排隊`，只列不為零的項目，以「 · 」分隔；全無時為空字串。 */
export function formatActivity(activity: GroupActivity): string {
  const parts = [
    activity.dispatching > 0 ? `${activity.dispatching} 派發中` : '',
    activity.inGate > 0 ? `${activity.inGate} 閘門` : '',
    activity.isWaiting ? '等你處理' : '',
    activity.queued > 0 ? `${activity.queued} 排隊` : '',
  ]
  return parts.filter(part => part !== '').join(' · ')
}

/** 標題列：展開為 `▾`、收合為 `▸`，其後各段以「｜」分隔，空段略過。 */
export function formatGroupTitle(parts: readonly string[], isOpen: boolean): string {
  return `${isOpen ? '▾' : '▸'} ${parts.filter(part => part !== '').join('｜')}`
}

/** 群組內的派發列：`<代理人>｜<任務>｜<流程階段>｜<距派發時間>`；所屬線由群組標題表達，不再重複。 */
export function formatGroupDispatchRow(row: DispatchRow, nowMs: number): string {
  return `${row.name}｜${row.task}｜${row.stage}｜${formatAge(nowMs, parseIsoMs(row.dispatchedAt))}`
}

/** 閘門票列：`閘門｜<短票號>｜自 HH:MM:SS`。 */
export function formatGateTicket(gate: GateTicket): string {
  return `閘門｜${gate.serial}｜自 ${gate.since}`
}

/** 佇列列：`排隊：<票序>`，票序同 formatQueue（每張票標主 checkout 的狀態，分隔符原樣）。 */
export function formatQueueRow(tokens: readonly QueueToken[], tickets: readonly TicketStatus[]): string {
  return `排隊：${formatQueue(tokens, tickets)}`
}
