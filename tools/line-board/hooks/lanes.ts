// 線與佇列：349 Solution 的現行佇列行與線目標行解析（每線取最後一行）、票序拆分與格式化。
// 不碰 $（無檔案、無行程），讓 *.test.ts 能直接驗證；讀檔與執行命令由 readers.ts 負責。

import type { Lane, QueueToken, TicketStatus } from '../types'
import { TICKETS_DIR, TICKET_PREFIX } from './shared'

/** 線與佇列的權威票檔，相對 repo root。 */
export const DISPATCH_TICKET_PATH = `${TICKETS_DIR}/0.5.0-W1-349.md`

/** 現行佇列行掃描範圍的起點：349 的 Solution 二級標題，讀到下一個二級標題前。 */
const SOLUTION_HEADING = '## Solution'

/**
 * 現行佇列行（349〈看板讀取約定〉）：行首即 `**L<n> 現行佇列**`，n 為數字，
 * 其後可帶全形括號的 session 名稱，再接全形冒號與票序。
 * 只比對行首：清單項（`- **L7 …`）與以反引號引用範本的說明行都不算。
 */
const LANE_LINE = /^\*\*L(\d+) 現行佇列\*\*(?:（([^）]*)）)?：(.*)$/

/** 票序寫此值表示這條線結束，看板不顯示；目標行寫此值表示清除目標。 */
const LANE_ENDED = '（無）'

/**
 * 線目標行（349，337 UI 裁定）：行首即 `**L<n> 目標**`，n 為數字，接全形冒號與一句話目標。
 * 判定與現行佇列行相同：只比對行首，清單項、表格內與以反引號引用範本的行都不算。
 */
const GOAL_LINE = /^\*\*L(\d+) 目標\*\*：(.*)$/

/** 票序中的分隔符：`→` 依序、`∥` 並行；拆分時保留分隔符本身。 */
const QUEUE_SEPARATOR = /\s*(→|∥)\s*/

/** 一步的開頭短票號：三位數，可帶任意層 `.n` 子序號（如 `337.2.1`）；其後為註記。 */
const STEP_SERIAL = /^(\d{3}(?:\.\d+)*)(.*)$/

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
 * 掃 349 Solution 的線目標行，每條線只取最後一行；最後一行寫 `（無）` 或為空的線不在結果中（目標已清除）。
 */
export function parseLaneGoals(text: string): Map<number, string> {
  const goals = new Map<number, string>()
  for (const [lane, match] of lastMatchPerLane(text, GOAL_LINE)) {
    const goal = (match[2] ?? '').trim()
    if (goal !== '' && goal !== LANE_ENDED) goals.set(lane, goal)
  }
  return goals
}

/**
 * 逐行以 pattern 比對 Solution 段落，每條線只留最後一個符合的行；pattern 的第一個群組須為線號。
 * 現行佇列行與線目標行共用此規則：同一條線較早的行是歷史，一律被較晚的行取代。
 */
function lastMatchPerLane(text: string, pattern: RegExp): Map<number, RegExpExecArray> {
  const latest = new Map<number, RegExpExecArray>()
  for (const line of solutionLines(text)) {
    const match = pattern.exec(line)
    if (match !== null) latest.set(Number(match[1]), match)
  }
  return latest
}

/**
 * 掃 349 的 Solution，每條線只取最後一次出現的現行佇列行，依線號排序；各線附上 parseLaneGoals 的目標（沒有時為 null）。
 * 最後一行票序為 `（無）` 的線不回傳；歷史行（同線較早的行）的票號不進結果。
 */
export function parseLanes(text: string): Lane[] {
  const goals = parseLaneGoals(text)
  return [...lastMatchPerLane(text, LANE_LINE)]
    .map(([lane, match]) => [lane, { session: match[2] ?? null, queue: (match[3] ?? '').trim() }] as const)
    .filter(([, { queue }]) => queue !== LANE_ENDED)
    .sort(([a], [b]) => a - b)
    .map(([lane, { session, queue }]) => ({ lane, session, goal: goals.get(lane) ?? null, tokens: parseQueue(queue) }))
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
