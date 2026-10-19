// 看板資料的純函式：主 checkout 判定、段落擷取、佇列票號抽取與標示、frontmatter 狀態解析、紀錄尾端。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 register.tsx 負責。

import type { SectionResult, TicketStatus } from '../types'

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

/** 票檔讀不到或沒有 status 欄時顯示的狀態。 */
export const UNKNOWN_STATUS = 'unknown'

/**
 * 從 `git worktree list --porcelain` 取主 checkout 路徑（第一筆 `worktree` 行）；空輸出回傳 null。
 * 票狀態只讀主 checkout：ticket CLI 在 linked worktree 執行時也把票務寫回主 repo，
 * worktree 內的票檔是分支開出當下的舊副本，讀它會顯示過時的狀態。
 */
export function parseMainCheckout(porcelain: string): string | null {
  const head = porcelain.split('\n').find(line => line.startsWith('worktree '))
  return head === undefined ? null : head.slice('worktree '.length).trim()
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
  const byId = new Map(tickets.map(ticket => [ticket.id, ticket.status]))
  return markdown
    .split('\n')
    .map(line => {
      if (!isQueueLine(line)) return line
      return line.replace(QUEUE_ID, serial => {
        const status = byId.get(`${TICKET_PREFIX}${serial}`)
        return status === undefined ? serial : `${serial}〔${status}〕`
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

/** 取文字最後 count 個非空行，保留原順序。 */
export function tailLines(text: string, count: number): string[] {
  return text
    .split('\n')
    .filter(line => line.trim() !== '')
    .slice(-count)
}
