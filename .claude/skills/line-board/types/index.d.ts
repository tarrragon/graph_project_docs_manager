// line-board 的型別契約：$.state 內每個值的形狀（snapshot 與群組展開狀態 expanded），以及 hooks/parse.ts 純函式的輸入輸出。

/** 票序中的一段：ticket 為一張票（短票號、完整票號、其後的註記），sep 為 `→` 或 `∥`，text 為無法辨識為票號的文字。 */
export type QueueToken =
  | { kind: 'ticket'; serial: string; id: string; note: string }
  | { kind: 'sep'; text: '→' | '∥' }
  | { kind: 'text'; text: string }

/** 一條線的現行佇列：線號、session 名稱（行內未寫時為 null）、線目標（協調票沒有目標行或已寫（無）清除時為 null）、票序。 */
export type Lane = { lane: number; session: string | null; goal: string | null; tokens: QueueToken[] }

/**
 * 主 checkout 專案設定檔（.claude/project-integration/multi-session.json）的讀取結果：ok 為協調票的完整票號；
 * 其餘為設定不成立的原因——missing 讀不到檔案、invalid-json JSON 無效、missing-field 不是物件或缺 coordinationTicket、
 * invalid-format 值不是完整票號（value 為原值）。
 */
export type ProjectConfigResult =
  | { kind: 'ok'; coordinationTicket: string }
  | { kind: 'missing'; message: string }
  | { kind: 'invalid-json'; message: string }
  | { kind: 'missing-field' }
  | { kind: 'invalid-format'; value: unknown }

/** 設定不成立的讀取結果。 */
export type UnsetProjectConfig = Exclude<ProjectConfigResult, { kind: 'ok' }>

/** 協調票現行佇列的讀取結果：ok 為解析出的線（可能為空），error 為讀檔失敗原因（含票檔路徑）。 */
export type LanesResult =
  | { kind: 'ok'; lanes: Lane[] }
  | { kind: 'error'; message: string }

/**
 * 佇列中一張票在主 checkout 的狀態與 title（同一次讀檔解析）；票檔讀不到或沒有 status 欄時 status 為 'unknown'，
 * 讀不到或沒有 title 欄時 title 為 null。title 為選填：hot reload 前的舊 snapshot 沒有此欄（undefined），視同讀不到。
 */
export type TicketStatus = { id: string; status: string; title?: string | null }

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
  /** session 的 UUID；派發紀錄的 session_id 以此對應 session。缺少時為 null。 */
  sessionId: string | null
}

/**
 * 主 checkout `.claude/dispatch-active.json` 的 dispatches 一筆（只取看板要的欄位）。
 * name 為代理人類型（linux、general-purpose 等）；ticketId 在紀錄寫空字串時為 null；
 * dispatchedAt 與 turnEndedAt 為原樣的 ISO 時間字串，turnEndedAt 為 null 表示代理人尚未結束。
 */
export type DispatchRecord = {
  agentId: string
  name: string
  sessionId: string
  ticketId: string | null
  description: string
  dispatchedAt: string | null
  turnEndedAt: string | null
}

/** 派發紀錄的讀取結果：ok 為 dispatches 中可辨識的條目，error 為讀檔失敗或格式錯誤的原因。 */
export type DispatchesResult =
  | { kind: 'ok'; records: DispatchRecord[] }
  | { kind: 'error'; message: string }

/** 派發中代理人的流程階段。 */
export type DispatchStage = '實作' | '審查' | '事故分析' | '閘門' | '收尾'

/** 派發列的判定依據：存活的 session、協調票的線、主 checkout 的票狀態、閘門持有者。 */
export type DispatchContext = {
  sessions: readonly SessionState[]
  lanes: readonly Lane[]
  tickets: readonly TicketStatus[]
  holders: readonly MergeGateHolder[]
}

/** 派發區塊的一列：所屬線（對不到為 null，顯示為「其他」）、代理人名稱、任務（票號或派發描述）、流程階段、派發時間。 */
export type DispatchRow = {
  lane: number | null
  name: string
  task: string
  stage: DispatchStage
  dispatchedAt: string | null
}

/**
 * 一個群組標題列的活動計數，與展開後的內容一一對應：dispatching 為派發列數；inGate 為派發列中階段為閘門者加上 gateTickets 數；
 * isWaiting 為該線的 session 狀態是 waiting（等你處理）；queued 為佇列列中狀態不是 completed 的票數。
 */
export type GroupActivity = { dispatching: number; inGate: number; isWaiting: boolean; queued: number }

/** 佇列中一張正持有合併閘門的票（閘門持有者為其 `feat/<票號>` 分支）：短票號與開始時間 `HH:MM:SS`。 */
export type GateTicket = { serial: string; since: string }

/**
 * 以線分組的一個群組：id 為展開狀態的鍵（`lane:<n>` 或 `other`）；lane 為 null 表示「其他」群組（收容對不到線的派發）。
 * 展開後依序列出 dispatches、gateTickets（派發列已標閘門的票不重複列）與該線的佇列列。
 */
export type LaneGroup = {
  id: string
  lane: Lane | null
  dispatches: DispatchRow[]
  gateTickets: GateTicket[]
  activity: GroupActivity
}

/** 使用者按過的群組的展開狀態，以群組 id 為鍵；沒有的鍵依預設判定。 */
export type GroupOverrides = Record<string, boolean>

/** 各 session 狀態的讀取結果：ok 為本 repo 內 pid 仍存活的 session 與已結束的檔數，error 為讀取失敗原因。 */
export type SessionsResult =
  | { kind: 'ok'; sessions: SessionState[]; endedCount: number }
  | { kind: 'error'; message: string }

/**
 * 一次讀取的完整結果。loading 表示 session 啟動後尚未完成第一次讀取；
 * unconfigured 表示專案設定不成立（設定檔的絕對路徑與原因），此時不讀其他各項。
 */
export type BoardSnapshot =
  | { kind: 'loading' }
  | { kind: 'unconfigured'; configPath: string; config: UnsetProjectConfig }
  | {
      kind: 'ready'
      updatedAt: string
      /** 讀取當下的 epoch 毫秒，用來算各 session 距上次狀態更新的時間。 */
      readAtMs: number
      mainPath: string
      /** 無法以 `git worktree list` 判定主 checkout 時的原因；此時退回 session root。 */
      checkoutNote: string | null
      /** 短票號前綴（如 `1.2.0-W3-`）：由專案設定的協調票推導（shared.ts ticketPrefixOf），派發列以它去掉票號前綴。 */
      ticketPrefix: string
      lanes: LanesResult
      tickets: TicketStatus[]
      sessions: SessionsResult
      mergeLog: MergeLogResult
      dispatches: DispatchesResult
    }

/** 已完成第一次讀取的 snapshot：Pane 各區塊繪製時的輸入。 */
export type ReadyBoard = Extract<BoardSnapshot, { kind: 'ready' }>

declare module 'claude-code' {
  interface PluginState {
    'line-board': { snapshot: BoardSnapshot; expanded: GroupOverrides }
  }
  /**
   * 本 plugin 以 $.tool.register 註冊的工具。平台型別根的 MCP 條目只列已連線 server 的工具，
   * 列了之後 tool.call 的過濾名稱就收窄為那些名稱；自己註冊的工具須在此補上，過濾器才接受。
   */
  interface McpToolInputs {
    'mcp__line-board__line_status': Record<string, never>
  }
}
