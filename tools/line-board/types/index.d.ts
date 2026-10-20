// line-board 的型別契約：$.state 內每個值的形狀，以及 hooks/parse.ts 純函式的輸入輸出。

/** 票序中的一段：ticket 為一張票（短票號、完整票號、其後的註記），sep 為 `→` 或 `∥`，text 為無法辨識為票號的文字。 */
export type QueueToken =
  | { kind: 'ticket'; serial: string; id: string; note: string }
  | { kind: 'sep'; text: '→' | '∥' }
  | { kind: 'text'; text: string }

/** 一條線的現行佇列：線號、session 名稱（行內未寫時為 null）、線目標（349 沒有目標行或已寫（無）清除時為 null）、票序。 */
export type Lane = { lane: number; session: string | null; goal: string | null; tokens: QueueToken[] }

/** 349 現行佇列的讀取結果：ok 為解析出的線（可能為空），error 為讀檔失敗原因。 */
export type LanesResult =
  | { kind: 'ok'; lanes: Lane[] }
  | { kind: 'error'; message: string }

/** 佇列中一張票在主 checkout 的狀態；票檔讀不到或沒有 status 欄時為 'unknown'。 */
export type TicketStatus = { id: string; status: string }

/**
 * 一行 `[合併閘門] 開始／結束` 的欄位：time 為 `HH:MM:SS`，branch 為完整分支名（顯示時才縮短），
 * result 為結束行的結果（寫入、中止等）；raw 為格式不符、原樣保留的整行。
 */
export type MergeGateEntry =
  | { kind: 'start'; time: string; branch: string }
  | { kind: 'end'; time: string; branch: string; result: string }
  | { kind: 'raw'; text: string }

/** 一個持有閘門的分支：最後一筆開始行之後沒有同分支結束行的分支（完整名稱）與該開始行的時間 `HH:MM:SS`。 */
export type MergeGateHolder = { branch: string; since: string }

/**
 * 合併閘門紀錄：ok 為最近幾行開始／結束與目前所有持有者（以整份紀錄判定，依開始順序，沒有時為空陣列），
 * error 為讀檔失敗原因。
 */
export type MergeLogResult =
  | { kind: 'ok'; entries: MergeGateEntry[]; holders: MergeGateHolder[] }
  | { kind: 'error'; message: string }

/**
 * 一個 session 的狀態，取自 `~/.claude/sessions/<pid>.json`（CC 內部檔案，格式無官方承諾）。
 * status 原樣保存，已知值為 waiting／busy／shell／idle，其他值照樣顯示；waitingFor、statusUpdatedAt、procStart 缺少時為 null。
 */
export type SessionState = {
  pid: number
  name: string
  cwd: string
  status: string
  waitingFor: string | null
  /** epoch 毫秒。 */
  statusUpdatedAt: number | null
  /** 行程啟動時間，UTC 的 `ps -o lstart` 格式（如 `Mon Oct 19 09:09:02 2026`）；用來辨識 pid 是否被重複使用。 */
  procStart: string | null
}

/** 各 session 狀態的讀取結果：ok 為本 repo 內 pid 仍存活的 session 與已結束的檔數，error 為讀取失敗原因。 */
export type SessionsResult =
  | { kind: 'ok'; sessions: SessionState[]; endedCount: number }
  | { kind: 'error'; message: string }

/** 一次讀取的完整結果。loading 表示 session 啟動後尚未完成第一次讀取。 */
export type BoardSnapshot =
  | { kind: 'loading' }
  | {
      kind: 'ready'
      updatedAt: string
      /** 讀取當下的 epoch 毫秒，用來算各 session 距上次狀態更新的時間。 */
      readAtMs: number
      mainPath: string
      /** 無法以 `git worktree list` 判定主 checkout 時的原因；此時退回 session root。 */
      checkoutNote: string | null
      lanes: LanesResult
      tickets: TicketStatus[]
      sessions: SessionsResult
      mergeLog: MergeLogResult
    }

declare module 'claude-code' {
  interface PluginState {
    'line-board': { snapshot: BoardSnapshot }
  }
}
