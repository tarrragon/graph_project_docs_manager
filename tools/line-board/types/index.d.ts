// line-board 的型別契約：$.state 內每個值的形狀，以及 hooks/parse.ts 純函式的輸入輸出。

/** 349〈分派〉段落擷取結果：ok 有內容、missing 找不到標題、error 讀檔失敗。 */
export type SectionResult =
  | { kind: 'ok'; markdown: string }
  | { kind: 'missing'; heading: string }
  | { kind: 'error'; message: string }

/** 佇列中一張票在主 checkout 的狀態；票檔讀不到或沒有 status 欄時為 'unknown'。 */
export type TicketStatus = { id: string; status: string }

/** 合併閘門紀錄：ok 為最近幾行，error 為讀檔失敗原因。 */
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
      section: SectionResult
      tickets: TicketStatus[]
      mergeLog: MergeLogResult
    }

declare module 'claude-code' {
  interface PluginState {
    'line-board': { snapshot: BoardSnapshot }
  }
}
