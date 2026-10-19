// 看板資料的純函式：主 checkout 判定、349 現行佇列行解析、佇列格式化、frontmatter 狀態解析、
// session 狀態檔篩選與解析（含 pid 重複使用的辨識）、合併閘門紀錄篩選與欄位解析（短分支名、目前持有閘門的分支）。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 register.tsx 負責。

import type { Lane, MergeGateEntry, MergeGateHolder, QueueToken, SessionState, TicketStatus } from '../types'

/** 佇列票號的前綴：現行佇列行只寫短票號，補上前綴才是完整票號。 */
export const TICKET_PREFIX = '0.5.0-W1-'

/** 票檔所在目錄，相對 repo root。 */
export const TICKETS_DIR = 'docs/work-logs/v0/v0.5/v0.5.0/tickets'

/** 線與佇列的權威票檔，相對 repo root。 */
export const DISPATCH_TICKET_PATH = `${TICKETS_DIR}/0.5.0-W1-349.md`

/** 合併閘門紀錄檔，相對 repo root。 */
export const MERGE_LOG_PATH = '.claude/logs/worktree-merge.log'

/** 票檔讀不到或沒有 status 欄時顯示的狀態。 */
export const UNKNOWN_STATUS = 'unknown'

/** 各 session 狀態檔所在目錄，相對家目錄。 */
export const SESSIONS_DIR = '.claude/sessions'

/** 狀態檔副檔名；同目錄的 `.key` 是金鑰，一律不讀。 */
const SESSION_FILE_SUFFIX = '.json'

/**
 * 「各 session」區塊的排序組：在等用戶的排最前；`shell`（session 正在執行 shell 命令，實測 2.1.303）屬執行中，與 busy 同組。
 * 不在此表的 status 排在最後；顯示一律保留原值。
 */
const SESSION_STATUS_RANK: Readonly<Record<string, number>> = { waiting: 0, busy: 1, shell: 1, idle: 2 }

/** 未列入排序組的 status 的組別：排在所有已知組之後。 */
const UNKNOWN_STATUS_RANK = 3

/**
 * `ps -o lstart=` 與狀態檔 procStart 的格式（正規化後）：`Mon Oct 19 09:09:02 2026`。
 * 日期為個位數時 ps 以空白補位（`Oct  5`），正規化會把連續空白壓成一個。
 */
const PROC_START_FORMAT = /^[A-Z][a-z]{2} [A-Z][a-z]{2} \d{1,2} \d{2}:\d{2}:\d{2} \d{4}$/

/** 線列的 session 名稱比對不到存活的 session 時顯示的狀態。 */
export const SESSION_OFFLINE = '離線'

/** 現行佇列行掃描範圍的起點：349 的 Solution 二級標題，讀到下一個二級標題前。 */
const SOLUTION_HEADING = '## Solution'

/**
 * 現行佇列行（349〈看板讀取約定〉）：行首即 `**L<n> 現行佇列**`，n 為數字，
 * 其後可帶全形括號的 session 名稱，再接全形冒號與票序。
 * 只比對行首：清單項（`- **L7 …`）與以反引號引用範本的說明行都不算。
 */
const LANE_LINE = /^\*\*L(\d+) 現行佇列\*\*(?:（([^）]*)）)?：(.*)$/

/** 票序寫此值表示這條線結束，看板不顯示。 */
const LANE_ENDED = '（無）'

/** 票序中的分隔符：`→` 依序、`∥` 並行；拆分時保留分隔符本身。 */
const QUEUE_SEPARATOR = /\s*(→|∥)\s*/

/** 一步的開頭短票號：三位數，可帶任意層 `.n` 子序號（如 `337.2.1`）；其後為註記。 */
const STEP_SERIAL = /^(\d{3}(?:\.\d+)*)(.*)$/

/** 合併閘門紀錄中要顯示的行：`[合併閘門] 開始` 與 `[合併閘門] 結束`；預檢、驗收、測試等其他行濾掉。 */
const MERGE_GATE_LINE = /\[合併閘門\] (開始|結束)(｜|$)/

/** 取 Solution 段落的各行（自 `## Solution` 起到下一個 `## ` 標題前）；沒有該標題時回傳空陣列。 */
function solutionLines(text: string): string[] {
  const lines = text.split('\n').map(line => line.trimEnd())
  const start = lines.findIndex(line => line === SOLUTION_HEADING || line.startsWith(`${SOLUTION_HEADING} `))
  if (start === -1) return []
  const rest = lines.slice(start + 1)
  const end = rest.findIndex(line => line.startsWith('## '))
  return end === -1 ? rest : rest.slice(0, end)
}

/** 票序拆成票號、分隔符與無法辨識的文字，保留原順序。 */
export function parseQueue(queue: string): QueueToken[] {
  const tokens: QueueToken[] = []
  for (const part of queue.trim().split(QUEUE_SEPARATOR)) {
    if (part === '') continue
    if (part === '→' || part === '∥') {
      tokens.push({ kind: 'sep', text: part })
      continue
    }
    const match = STEP_SERIAL.exec(part)
    if (match === null) {
      tokens.push({ kind: 'text', text: part })
      continue
    }
    const serial = match[1] ?? ''
    tokens.push({ kind: 'ticket', serial, id: `${TICKET_PREFIX}${serial}`, note: (match[2] ?? '').trim() })
  }
  return tokens
}

/**
 * 掃 349 的 Solution，每條線只取最後一次出現的現行佇列行，依線號排序。
 * 最後一行票序為 `（無）` 的線不回傳；歷史行（同線較早的行）的票號不進結果。
 */
export function parseLanes(text: string): Lane[] {
  const latest = new Map<number, { session: string | null; queue: string }>()
  for (const line of solutionLines(text)) {
    const match = LANE_LINE.exec(line)
    if (match === null) continue
    latest.set(Number(match[1]), { session: match[2] ?? null, queue: (match[3] ?? '').trim() })
  }
  return [...latest.entries()]
    .filter(([, { queue }]) => queue !== LANE_ENDED)
    .sort(([a], [b]) => a - b)
    .map(([lane, { session, queue }]) => ({ lane, session, tokens: parseQueue(queue) }))
}

/** 所有線的佇列完整票號，保留首次出現順序並去重。 */
export function laneTicketIds(lanes: readonly Lane[]): string[] {
  const ids: string[] = []
  for (const lane of lanes) {
    for (const token of lane.tokens) {
      if (token.kind === 'ticket' && !ids.includes(token.id)) ids.push(token.id)
    }
  }
  return ids
}

/** 票序文字：每張票為 `短票號〔status〕註記`，分隔符前後各一空白；查不到狀態的票只顯示短票號。 */
export function formatQueue(tokens: readonly QueueToken[], tickets: readonly TicketStatus[]): string {
  const byId = new Map(tickets.map(ticket => [ticket.id, ticket.status]))
  return tokens
    .map(token => {
      if (token.kind === 'sep') return ` ${token.text} `
      if (token.kind === 'text') return token.text
      const status = byId.get(token.id)
      return `${token.serial}${status === undefined ? '' : `〔${status}〕`}${token.note}`
    })
    .join('')
}

/** 讀票檔 frontmatter（第一個 `---` 區塊）的 `status:` 值；沒有 frontmatter 或沒有該欄時回傳 null。 */
export function parseFrontmatterStatus(text: string): string | null {
  const lines = text.split('\n')
  if (lines[0]?.trim() !== '---') return null
  for (const line of lines.slice(1)) {
    if (line.trim() === '---') return null
    const match = /^status:\s*['"]?([\w-]+)['"]?\s*$/.exec(line)
    if (match !== null) return match[1] ?? null
  }
  return null
}

/**
 * 從 `git worktree list --porcelain` 取所有 checkout 路徑：第一筆為主 checkout，其後各 worktree；空輸出回傳空陣列。
 * 票狀態只讀主 checkout：ticket CLI 在 linked worktree 執行時也把票務寫回主 repo，
 * worktree 內的票檔是分支開出當下的舊副本，讀它會顯示過時的狀態。全部路徑用來判定 session 是否屬於本 repo。
 */
export function parseWorktreePaths(porcelain: string): string[] {
  return porcelain
    .split('\n')
    .filter(line => line.startsWith('worktree '))
    .map(line => line.slice('worktree '.length).trim())
}

/**
 * `~/.claude/sessions/` 中可讀的狀態檔名：只取副檔名為 `.json` 的一般檔案。
 * 同目錄的 `<pid>.<hash>.key` 是金鑰，不在回傳之列，呼叫端也就不會讀到它。
 */
export function sessionStatusFileNames(entries: readonly { name: string; kind: string }[]): string[] {
  return entries.filter(entry => entry.kind === 'file' && entry.name.endsWith(SESSION_FILE_SUFFIX)).map(entry => entry.name)
}

/**
 * 解析一個 session 狀態檔；JSON 無效或缺少 pid／name／cwd／status 時回傳 null。
 * 只取看板要的欄位，其他欄位（如 messagingSocketPath）不保存。
 */
export function parseSessionFile(text: string): SessionState | null {
  let value: unknown
  try {
    value = JSON.parse(text)
  } catch {
    // 格式無效的檔案（例如 CC 寫到一半）視為不存在，下一輪重讀即可；呼叫端記 debug 日誌。
    return null
  }
  if (typeof value !== 'object' || value === null) return null
  const record = value as Record<string, unknown>
  const { pid, name, cwd, status, waitingFor, statusUpdatedAt, procStart } = record
  if (typeof pid !== 'number' || typeof name !== 'string' || typeof cwd !== 'string' || typeof status !== 'string') {
    return null
  }
  return {
    pid,
    name,
    cwd,
    status,
    waitingFor: typeof waitingFor === 'string' ? waitingFor : null,
    statusUpdatedAt: typeof statusUpdatedAt === 'number' ? statusUpdatedAt : null,
    procStart: typeof procStart === 'string' ? procStart : null,
  }
}

/** 行程啟動時間字串的正規化：去頭尾空白、連續空白壓成一個；不符 lstart 格式時回傳 null（無從比對）。 */
export function normalizeProcStart(text: string | null): string | null {
  if (text === null) return null
  const normalized = text.trim().replace(/\s+/g, ' ')
  return PROC_START_FORMAT.test(normalized) ? normalized : null
}

/**
 * session 的 pid 是否仍是同一個行程：`ps -p <pid> -o lstart=`（以 TZ=UTC 執行）的結果與狀態檔 procStart 比對。
 * - ps exit 不為 0：pid 已結束
 * - 兩者正規化後相同：存活；不同：pid 已被其他行程重複使用，原 session 已結束
 * - 任一方缺少或格式不符（無從比對）：退回只看 exit code 的判定，視為存活
 * procStart 是 UTC（實測 2026-10-19，CC 2.1.303：與 `TZ=UTC ps -o lstart=` 逐字相同，與本機時區的輸出差 8 小時）。
 */
export function isSessionProcessAlive(exitCode: number, lstart: string, procStart: string | null): boolean {
  if (exitCode !== 0) return false
  const observed = normalizeProcStart(lstart)
  const recorded = normalizeProcStart(procStart)
  if (observed === null || recorded === null) return true
  return observed === recorded
}

/** cwd 是否屬於本 repo：等於任一 checkout 路徑，或位於其下。 */
export function isInRepo(cwd: string, checkoutPaths: readonly string[]): boolean {
  return checkoutPaths.some(path => cwd === path || cwd.startsWith(`${path}/`))
}

/** 依 waiting、busy 與 shell（同組）、idle、其他狀態排序，同組依名稱排序；不改動傳入陣列。 */
export function sortSessions(sessions: readonly SessionState[]): SessionState[] {
  const rank = (status: string) => SESSION_STATUS_RANK[status] ?? UNKNOWN_STATUS_RANK
  return [...sessions].sort((a, b) => rank(a.status) - rank(b.status) || a.name.localeCompare(b.name))
}

/**
 * 依名稱找 session：同名多筆時取 statusUpdatedAt 最新的一筆；找不到回傳 undefined。
 * 傳入的應是已確認 pid 存活的 session。
 */
export function findSessionByName(sessions: readonly SessionState[], name: string): SessionState | undefined {
  return sessions
    .filter(session => session.name === name)
    .sort((a, b) => (b.statusUpdatedAt ?? 0) - (a.statusUpdatedAt ?? 0))[0]
}

/** 線列 session 名稱旁的狀態：存活的同名 session 取其 status（waiting 附 waitingFor），找不到為「離線」。 */
export function laneSessionStatus(sessions: readonly SessionState[], name: string | null): string {
  if (name === null) return ''
  const session = findSessionByName(sessions, name)
  if (session === undefined) return SESSION_OFFLINE
  return session.waitingFor === null ? session.status : `${session.status}：${session.waitingFor}`
}

/** 距上次更新的時間：未滿 1 分鐘以秒計，其後依序以分、小時、天計；未來時間視為 0 秒；缺少時間為「時間不明」。 */
export function formatAge(nowMs: number, thenMs: number | null): string {
  if (thenMs === null) return '時間不明'
  const seconds = Math.max(0, Math.floor((nowMs - thenMs) / 1000))
  if (seconds < 60) return `${seconds} 秒前`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} 分前`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} 小時前`
  return `${Math.floor(hours / 24)} 天前`
}

/** 合併閘門紀錄中最後 count 個 `[合併閘門] 開始／結束` 行，保留原順序。 */
export function mergeGateLines(text: string, count: number): string[] {
  return text
    .split('\n')
    .map(line => line.trimEnd())
    .filter(line => MERGE_GATE_LINE.test(line))
    .slice(-count)
}

/**
 * 一行開始／結束的完整格式：`<YYYY-MM-DD>T<HH:MM:SS> [合併閘門] <開始|結束>`，其後為以 `｜` 分隔的欄位
 * （`target main`、`分支 <branch>`、`commit <sha>`，結束行另有 `結果 <result>`）。
 */
const MERGE_GATE_FIELDS = /^\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2}) \[合併閘門\] (開始|結束)((?:｜[^｜]*)*)$/

/** 欄位中以 `<label> ` 開頭者的值；沒有該欄或值為空時回傳 null。 */
function gateField(fields: readonly string[], label: string): string | null {
  const field = fields.find(item => item.startsWith(`${label} `))
  const value = field?.slice(label.length + 1).trim()
  return value === undefined || value === '' ? null : value
}

/**
 * 解析一行 `[合併閘門] 開始／結束`：開始行需有分支，結束行需有分支與結果；
 * 時間戳、分支或結果任一缺少時回傳 raw，原樣保留整行，畫面照樣顯示而不丟棄。
 */
export function parseMergeGateLine(line: string): MergeGateEntry {
  const raw: MergeGateEntry = { kind: 'raw', text: line }
  const match = MERGE_GATE_FIELDS.exec(line)
  if (match === null) return raw
  const time = match[1] ?? ''
  const fields = (match[3] ?? '').split('｜').slice(1)
  const branch = gateField(fields, '分支')
  if (branch === null) return raw
  if (match[2] === '開始') return { kind: 'start', time, branch }
  const result = gateField(fields, '結果')
  return result === null ? raw : { kind: 'end', time, branch, result }
}

/** 整份紀錄中所有 `[合併閘門] 開始／結束` 行的解析結果，保留原順序；預檢、驗收、測試等其他行不在其中。 */
export function mergeGateEntries(text: string): MergeGateEntry[] {
  return mergeGateLines(text, Number.POSITIVE_INFINITY).map(parseMergeGateLine)
}

/**
 * 目前持有閘門的所有分支：各分支最後一筆開始行之後沒有同一分支的結束行者，依開始行的順序回傳分支與開始時間；
 * 沒有時回傳空陣列。開始與結束以分支欄配對，不以相鄰行配對：免跑測試的合併不佔 heavy 名額，
 * 可與其他分支的合併重疊，因此持有者可能同時有多個。格式不符的行不參與判定。
 */
export function mergeGateHolders(entries: readonly MergeGateEntry[]): MergeGateHolder[] {
  const open = new Map<string, string>()
  for (const entry of entries) {
    if (entry.kind === 'raw') continue
    // 先刪再設，使同分支重新開始時排到最後，與其最新開始行的位置一致
    open.delete(entry.branch)
    if (entry.kind === 'start') open.set(entry.branch, entry.time)
  }
  return [...open].map(([branch, since]) => ({ branch, since }))
}

/** worktree 代理人分支 `worktree-agent-<id>` 的 id 只顯示前幾碼。 */
const AGENT_ID_PREFIX_LENGTH = 6

/**
 * 分支的短名：`worktree-agent-<id>` 縮成 `agent-<id 前 6 碼>`，`feat/<票號>` 縮成票號，其他分支原樣。
 * 面板停靠在側邊時寬度有限，完整分支名會把結果欄擠出畫面。
 */
export function shortBranch(branch: string): string {
  const agent = /^worktree-agent-(\w+)$/.exec(branch)
  if (agent !== null) return `agent-${(agent[1] ?? '').slice(0, AGENT_ID_PREFIX_LENGTH)}`
  const feature = /^feat\/(.+)$/.exec(branch)
  if (feature !== null) return feature[1] ?? branch
  return branch
}

/** 閘門紀錄一行的顯示文字：`時間｜開始｜短分支` 或 `時間｜結束｜短分支｜結果`；格式不符的行為原文。 */
export function formatMergeGateEntry(entry: MergeGateEntry): string {
  if (entry.kind === 'raw') return entry.text
  const head = `${entry.time}｜${entry.kind === 'start' ? '開始' : '結束'}｜${shortBranch(entry.branch)}`
  return entry.kind === 'start' ? head : `${head}｜${entry.result}`
}

/** 閘門持有者的提示，每個持有者一行：`閘門使用中：<短分支>（自 HH:MM:SS）`；沒有持有者時為空陣列。 */
export function formatMergeGateHolders(holders: readonly MergeGateHolder[]): string[] {
  return holders.map(holder => `閘門使用中：${shortBranch(holder.branch)}（自 ${holder.since}）`)
}

/** 結束行的結果與顏色；結果值取自真實 worktree-merge.log（寫入、中止、拒絕、紅燈）。 */
const MERGE_GATE_RESULT_COLORS: Readonly<Record<string, string>> = {
  寫入: 'green',
  中止: 'yellow',
  拒絕: 'red',
  紅燈: 'red',
}

/** 結束行依結果上色：寫入為綠、中止為黃、拒絕與紅燈為紅；其他結果不上色（回傳 undefined）。 */
export function mergeGateResultColor(result: string): string | undefined {
  return MERGE_GATE_RESULT_COLORS[result]
}
