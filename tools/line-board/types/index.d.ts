// line-board 的型別契約：$.state 內每個值的形狀，以及 hooks/parse.ts 純函式的輸入輸出。

/** 票序中的一段：ticket 為一張票（短票號、完整票號、其後的註記），sep 為 `→` 或 `∥`，text 為無法辨識為票號的文字。 */
export type QueueToken =
  | { kind: 'ticket'; serial: string; id: string; note: string }
  | { kind: 'sep'; text: '→' | '∥' }
  | { kind: 'text'; text: string }

/** 一條線的現行佇列：線號、session 名稱（行內未寫時為 null）、票序。 */
export type Lane = { lane: number; session: string | null; tokens: QueueToken[] }

/** 349 現行佇列的讀取結果：ok 為解析出的線（可能為空），error 為讀檔失敗原因。 */
export type LanesResult =
  | { kind: 'ok'; lanes: Lane[] }
  | { kind: 'error'; message: string }

/** 佇列中一張票在主 checkout 的狀態；票檔讀不到或沒有 status 欄時為 'unknown'。 */
export type TicketStatus = { id: string; status: string }

/** 合併閘門紀錄：ok 為最近幾行開始／結束，error 為讀檔失敗原因。 */
export type MergeLogResult =
  | { kind: 'ok'; lines: string[] }
  | { kind: 'error'; message: string }

/** 一次讀取的完整結果。loading 表示 session 啟動後尚未完成第一次讀取。 */
export type BoardSnapshot =
  | { kind: 'loading' }
  | {
      kind: 'ready'
      updatedAt: string
      mainPath: string
      /** 無法以 `git worktree list` 判定主 checkout 時的原因；此時退回 session root。 */
      checkoutNote: string | null
      lanes: LanesResult
      tickets: TicketStatus[]
      mergeLog: MergeLogResult
    }

declare module 'claude-code' {
  interface PluginState {
    'line-board': { snapshot: BoardSnapshot }
  }
}
