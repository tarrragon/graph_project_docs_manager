// line-board 的型別契約：$.state 內每個值的形狀，以及 hooks/status.ts 純函式的輸入輸出。

/** 349〈分派〉段落擷取結果：ok 有內容、missing 找不到標題、error 讀檔失敗。 */
export type SectionResult =
  | { kind: 'ok'; markdown: string }
  | { kind: 'missing'; heading: string }
  | { kind: 'error'; message: string }

/** 一個 worktree 內某張票的狀態；status 為 null 表示該 worktree 讀不到此票檔。 */
export type WorktreeStatus = { path: string; status: string | null }

/** pickStatus 的結果：source 為 'main'、worktree 絕對路徑，或 'none'（各處皆讀不到）。 */
export type PickedStatus = { status: string; source: string }

/** 佇列中一張票的即時狀態。 */
export type TicketStatus = { id: string; status: string; source: string }

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
      worktreeCount: number
      /** `git worktree list` 失敗時的原因；此時只讀 main，票狀態不含 worktree。 */
      worktreeNote: string | null
      section: SectionResult
      tickets: TicketStatus[]
      mergeLog: MergeLogResult
    }

declare module 'claude-code' {
  interface PluginState {
    'line-board': { snapshot: BoardSnapshot }
  }
}
