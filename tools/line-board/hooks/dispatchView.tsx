// line-board Pane 的「派發中代理人」區塊。
// Text 由 register.tsx 的 ui.render 以 $.ui.resolve(e) 取得後傳入；解析經 parse.ts 匯出。

import type { ElementConstructor, TextProps } from 'claude-code'

import type { DispatchesResult, LanesResult, MergeLogResult, SessionsResult, TicketStatus } from '../types'
import { DISPATCH_ACTIVE_PATH, dispatchRows, formatDispatchRow } from './parse'

/**
 * 派發中代理人：每列 `L<n> <代理人>｜<任務>｜<階段>｜<距派發時間>`，依線分組、其他最後。
 * 派發紀錄讀取失敗只影響本區塊；sessions 讀不到時無從判定存活，不列條目。
 * 349 或閘門紀錄讀不到時照樣列出：線一律歸其他、不判定閘門。
 */
export function renderDispatches(
  Text: ElementConstructor<TextProps>,
  readAtMs: number,
  dispatches: DispatchesResult,
  lanes: LanesResult,
  tickets: readonly TicketStatus[],
  sessions: SessionsResult,
  mergeLog: MergeLogResult,
) {
  if (dispatches.kind === 'error') {
    return <Text color="red">讀取 {DISPATCH_ACTIVE_PATH} 失敗（{dispatches.message}）</Text>
  }
  if (sessions.kind === 'error') return <Text dimColor>（session 狀態讀取失敗，無法判定派發中的代理人）</Text>
  const rows = dispatchRows(dispatches.records, {
    sessions: sessions.sessions,
    lanes: lanes.kind === 'ok' ? lanes.lanes : [],
    tickets,
    holders: mergeLog.kind === 'ok' ? mergeLog.holders : [],
  })
  if (rows.length === 0) return <Text dimColor>（目前沒有派發中的代理人）</Text>
  return rows.map(row => <Text wrap="truncate-middle">{formatDispatchRow(row, readAtMs)}</Text>)
}
