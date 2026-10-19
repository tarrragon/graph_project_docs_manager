// 看板資料的純函式：段落擷取、佇列票號抽取、frontmatter 狀態解析、worktree 清單解析、狀態合併。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 register.tsx 負責。

import type {
  PickedStatus,
  SectionResult,
  TicketStatus,
  WorktreeStatus,
} from '../types'

/** 349 票檔中，線與佇列所在段落的標題（取第一個以此開頭的三級標題）。 */
export const DISPATCH_HEADING = '### 分派'

/** 佇列票號的前綴：段落內只寫三位數序號，補上前綴才是完整票號。 */
export const TICKET_PREFIX = '0.5.0-W1-'

/** 票檔所在目錄，相對 repo root。 */
export const TICKETS_DIR = 'docs/work-logs/v0/v0.5/v0.5.0/tickets'

/** 線與佇列的權威票檔，相對 repo root。 */
export const DISPATCH_TICKET_PATH = `${TICKETS_DIR}/0.5.0-W1-349.md`

/** 合併閘門紀錄檔，相對 repo root。 */
export const MERGE_LOG_PATH = '.claude/logs/worktree-merge.log'

/** 已結束的狀態：main 為這兩者之一時，不再看 worktree。 */
const FINAL_STATUSES = new Set(['completed', 'closed'])

/** 多個 worktree 狀態都與 main 不同時，取推進程度最高者；未列出的狀態排最前。 */
const STATUS_RANK: Record<string, number> = {
  pending: 1,
  blocked: 2,
  in_progress: 3,
  completed: 4,
  closed: 5,
}

/**
 * 從票檔全文擷取〈分派〉段落：自第一個以 `### 分派` 開頭的行起，到下一個 `## ` 二級標題前止。
 * 找不到標題時回傳 missing，讓畫面分辨「沒有段落」與「讀檔失敗」（後者由呼叫端給 error）。
 */
export function extractDispatchSection(text: string): SectionResult {
  const lines = text.split('\n')
  const start = lines.findIndex(line => line.startsWith(DISPATCH_HEADING))
  if (start === -1) return { kind: 'missing', heading: DISPATCH_HEADING }

  const rest = lines.slice(start + 1)
  const endOffset = rest.findIndex(line => line.startsWith('## '))
  const body = endOffset === -1 ? rest : rest.slice(0, endOffset)
  const markdown = [lines[start] ?? '', ...body].join('\n').trimEnd()
  return { kind: 'ok', markdown }
}

/** 佇列行：含「佇列」且其後（允許粗體記號）緊接全形冒號，例如 `佇列：`、`**L7 現行佇列**：`。 */
const QUEUE_LINE = /佇列\**：/

/** 佇列行中的票序號：三位數，可帶 `.n` 子序號；前後不得緊鄰英數字、`.`、`-`，排除日期與 hash 片段。 */
const QUEUE_ID = /(?<![\w.-])\d{3}(?:\.\d+)?(?![\w-]|\.\d)/g

/** 判斷一行是否為佇列行。 */
export function isQueueLine(line: string): boolean {
  return QUEUE_LINE.test(line)
}

/** 從段落的佇列行抽出完整票號（加前綴），保留首次出現順序並去重。 */
export function extractQueueIds(markdown: string): string[] {
  const ids: string[] = []
  for (const line of markdown.split('\n')) {
    if (!isQueueLine(line)) continue
    for (const match of line.matchAll(QUEUE_ID)) {
      const id = `${TICKET_PREFIX}${match[0]}`
      if (!ids.includes(id)) ids.push(id)
    }
  }
  return ids
}

/** 在佇列行的每個票序號後標上狀態，例如 `341.1` → `341.1〔in_progress〕`；非佇列行原樣保留。 */
export function annotateQueue(markdown: string, tickets: readonly TicketStatus[]): string {
  const byId = new Map(tickets.map(ticket => [ticket.id, ticket]))
  return markdown
    .split('\n')
    .map(line => {
      if (!isQueueLine(line)) return line
      return line.replace(QUEUE_ID, serial => {
        const ticket = byId.get(`${TICKET_PREFIX}${serial}`)
        if (ticket === undefined) return serial
        const mark = ticket.source === 'main' ? ticket.status : `${ticket.status}·wt`
        return `${serial}〔${mark}〕`
      })
    })
    .join('\n')
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

/** 解析 `git worktree list --porcelain`：第一筆為 main，其餘為可讀的 worktree（排除 bare 與 prunable）。 */
export function parseWorktreeList(porcelain: string): { main: string | null; worktrees: string[] } {
  const paths: string[] = []
  for (const block of porcelain.split(/\n\s*\n/)) {
    const lines = block.split('\n').map(line => line.trim())
    const head = lines.find(line => line.startsWith('worktree '))
    if (head === undefined) continue
    const isUsable = !lines.some(line => line === 'bare' || line.startsWith('prunable'))
    if (isUsable) paths.push(head.slice('worktree '.length))
  }
  const [main = null, ...worktrees] = paths
  return { main, worktrees }
}

/** 取文字最後 count 個非空行，保留原順序。 */
export function tailLines(text: string, count: number): string[] {
  return text
    .split('\n')
    .filter(line => line.trim() !== '')
    .slice(-count)
}

/**
 * 合併一張票在 main 與各 worktree 的狀態。
 *
 * [待用戶確認的預設規則]
 * 1. main 為 completed 或 closed：以 main 為準（票已收尾，worktree 內的舊值不再有意義）。
 * 2. 否則，有任一 worktree 讀得到且狀態與 main 不同：以該 worktree 為準，source 為其路徑；
 *    多個 worktree 皆不同時，取推進程度最高者（pending < blocked < in_progress < completed < closed）。
 * 3. 其餘情況以 main 為準；main 與所有 worktree 都讀不到時回傳 unknown／none。
 *
 * 取捨：規則 2 會讓「從較舊 main 開出、未動過該票的 worktree」以舊狀態蓋過 main 的新狀態；
 * 推進程度取最高只能緩解多個 worktree 並存的情形，單一過時 worktree 仍會蓋過 main。
 */
export function pickStatus(
  mainStatus: string | null,
  worktreeStatuses: readonly WorktreeStatus[],
): PickedStatus {
  if (mainStatus !== null && FINAL_STATUSES.has(mainStatus)) {
    return { status: mainStatus, source: 'main' }
  }

  const differing = worktreeStatuses.filter(
    (entry): entry is { path: string; status: string } =>
      entry.status !== null && entry.status !== mainStatus,
  )
  const [first, ...others] = differing
  if (first !== undefined) {
    const best = others.reduce((top, entry) => (rankOf(entry.status) > rankOf(top.status) ? entry : top), first)
    return { status: best.status, source: best.path }
  }

  if (mainStatus !== null) return { status: mainStatus, source: 'main' }
  return { status: 'unknown', source: 'none' }
}

/** 狀態的推進程度；未列出的狀態為 0。 */
function rankOf(status: string): number {
  return STATUS_RANK[status] ?? 0
}
