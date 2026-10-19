// 看板資料的純函式：主 checkout 判定、349 現行佇列行解析、佇列格式化、frontmatter 狀態解析、合併閘門紀錄篩選。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 register.tsx 負責。

import type { Lane, QueueToken, TicketStatus } from '../types'

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

/**
 * 從 `git worktree list --porcelain` 取主 checkout 路徑（第一筆 `worktree` 行）；空輸出回傳 null。
 * 票狀態只讀主 checkout：ticket CLI 在 linked worktree 執行時也把票務寫回主 repo，
 * worktree 內的票檔是分支開出當下的舊副本，讀它會顯示過時的狀態。
 */
export function parseMainCheckout(porcelain: string): string | null {
  const head = porcelain.split('\n').find(line => line.startsWith('worktree '))
  return head === undefined ? null : head.slice('worktree '.length).trim()
}

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

/** 合併閘門紀錄中最後 count 個 `[合併閘門] 開始／結束` 行，保留原順序。 */
export function mergeGateLines(text: string, count: number): string[] {
  return text
    .split('\n')
    .filter(line => MERGE_GATE_LINE.test(line))
    .slice(-count)
}
