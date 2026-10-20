// line-board Pane 的「線與佇列」區塊：每條線一列，含 session 狀態、票序與線目標。
// Text 由 register.tsx 的 ui.render 以 $.ui.resolve(e) 取得後傳入；解析經 parse.ts 匯出。

import type { ElementConstructor, TextProps } from 'claude-code'

import type { LanesResult, SessionsResult, TicketStatus } from '../types'
import { DISPATCH_TICKET_PATH, formatQueue, laneSessionStatus } from './parse'

export function renderLanes(
  Text: ElementConstructor<TextProps>,
  lanes: LanesResult,
  tickets: readonly TicketStatus[],
  sessions: SessionsResult,
) {
  if (lanes.kind === 'error') {
    return <Text color="red">解析失敗：讀取 {DISPATCH_TICKET_PATH} 時發生錯誤（{lanes.message}）</Text>
  }
  if (lanes.lanes.length === 0) return <Text color="yellow">349 尚無現行佇列行</Text>
  return lanes.lanes.map(lane => (
    <Text>
      L{lane.lane}｜{lane.session ?? '（未標 session）'}
      {laneStatusLabel(sessions, lane.session)}｜{formatQueue(lane.tokens, tickets)}
      {laneGoalLabel(lane.goal)}
    </Text>
  ))
}

/** 線列票序後的 `｜目標：<文字>`；沒有目標時不顯示。hot reload 後舊 snapshot 的線沒有 goal 欄（undefined），同樣不顯示。 */
function laneGoalLabel(goal: string | null | undefined): string {
  return goal === null || goal === undefined ? '' : `｜目標：${goal}`
}

/** 線列 session 名稱旁的 `［狀態］`；沒標 session 時不顯示，session 狀態讀取失敗時標「狀態不明」。 */
function laneStatusLabel(sessions: SessionsResult, name: string | null): string {
  if (name === null) return ''
  if (sessions.kind === 'error') return '［狀態不明］'
  return `［${laneSessionStatus(sessions.sessions, name)}］`
}
