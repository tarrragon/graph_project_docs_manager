// line-board：多線開發看板（第一階段）。
// 定時讀主 checkout 的 349〈分派〉段落、佇列票的 status、合併閘門紀錄，畫在 Pane。
// 畫面資料放 $.state（hot reload 不遺失）；讀檔與命令一律經 $，解析在 parse.ts。

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BoardSnapshot, MergeLogResult, SectionResult, TicketStatus } from '../types'
import {
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  TICKETS_DIR,
  UNKNOWN_STATUS,
  annotateQueue,
  extractDispatchSection,
  extractQueueIds,
  parseFrontmatterStatus,
  parseMainCheckout,
  tailLines,
} from './parse'

const PANE = 'line-board'
const PANE_TITLE = '多線看板'
/** 更新間隔：30 秒。 */
const REFRESH_MS = 30_000
/** 合併閘門紀錄顯示的行數。 */
const MERGE_LOG_LINES = 8

const snapshot = atom({ plugin: 'line-board', key: 'snapshot' } as const, { kind: 'loading' } as BoardSnapshot)

/** 讀取中旗標：避免上一輪尚未結束時重疊讀取。屬執行期控制，非畫面資料，reload 時歸零即可。 */
let isRefreshing = false

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'board',
      description: '開啟多線看板（349 分派、佇列票即時狀態、合併閘門紀錄）',
    })
    $.clock.every(REFRESH_MS, () => refresh($))
    void refresh($)
    void $.ui.open({ id: PANE, title: PANE_TITLE })

    return next(e)
  })

  on('command.run', { command: 'board' }, async $ => {
    await $.ui.open({ id: PANE, title: PANE_TITLE })
    void refresh($)

    return { text: '多線看板已開啟。' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Markdown } = $.ui.resolve(e)
    const board = await read($, snapshot)

    if (board.kind === 'loading') {
      return <Text dimColor>讀取中…</Text>
    }

    return (
      <Box flexDirection="column">
        <Text dimColor>
          更新 {board.updatedAt}
          {board.checkoutNote === null ? '' : `｜${board.checkoutNote}`}
        </Text>
        {renderSection(board.section, board.tickets)}
        <Text bold>合併閘門最近紀錄</Text>
        {renderMergeLog(board.mergeLog)}
      </Box>
    )

    function renderSection(section: SectionResult, tickets: readonly TicketStatus[]) {
      if (section.kind === 'ok') return <Markdown text={annotateQueue(section.markdown, tickets)} />
      if (section.kind === 'missing') {
        return <Text color="yellow">沒有資料：{DISPATCH_TICKET_PATH} 找不到「{section.heading}」段落</Text>
      }
      return <Text color="red">解析失敗：讀取 {DISPATCH_TICKET_PATH} 時發生錯誤（{section.message}）</Text>
    }

    function renderMergeLog(log: MergeLogResult) {
      if (log.kind === 'error') return <Text color="red">讀取 {MERGE_LOG_PATH} 失敗（{log.message}）</Text>
      if (log.lines.length === 0) return <Text dimColor>（尚無紀錄）</Text>
      return log.lines.map(line => <Text wrap="truncate-end">{line}</Text>)
    }
  })
}

/** 讀一輪資料並寫入 $.state；任何一項失敗只影響該項的顯示。 */
async function refresh($: EngineInterface): Promise<void> {
  if (isRefreshing) return
  isRefreshing = true
  try {
    const root = await $.session.root()
    const { mainPath, checkoutNote } = await findMainCheckout($, root)
    const section = await readSection($, mainPath)
    const ids = section.kind === 'ok' ? extractQueueIds(section.markdown) : []
    const tickets = await Promise.all(ids.map(id => readTicketStatus($, mainPath, id)))
    const mergeLog = await readMergeLog($, mainPath)
    const next: BoardSnapshot = {
      kind: 'ready',
      updatedAt: formatTime(new Date()),
      mainPath,
      checkoutNote,
      section,
      tickets,
      mergeLog,
    }
    await update($, snapshot, () => next)
  } catch (error) {
    $.ui.log(`line-board refresh 失敗：${messageOf(error)}`, { to: 'debug' })
  } finally {
    isRefreshing = false
  }
}

/**
 * 以 `git worktree list --porcelain` 的第一筆判定主 checkout，看板 session 在 worktree 內啟動也指向主 checkout。
 * 失敗時退回 session root 並帶原因顯示。
 */
async function findMainCheckout(
  $: EngineInterface,
  root: string,
): Promise<{ mainPath: string; checkoutNote: string | null }> {
  try {
    const result = await $.process.run(['git', 'worktree', 'list', '--porcelain'], { cwd: root })
    if (result.exitCode !== 0) {
      const note = `git worktree list 失敗（exit ${result.exitCode}），改讀 session root`
      $.ui.log(`line-board: ${note}: ${result.stderr.trim()}`, { to: 'debug' })
      return { mainPath: root, checkoutNote: note }
    }
    const main = parseMainCheckout(result.stdout)
    if (main === null) return { mainPath: root, checkoutNote: 'git worktree list 無輸出，改讀 session root' }
    return { mainPath: main, checkoutNote: null }
  } catch (error) {
    const note = `git worktree list 無法執行（${messageOf(error)}），改讀 session root`
    $.ui.log(`line-board: ${note}`, { to: 'debug' })
    return { mainPath: root, checkoutNote: note }
  }
}

async function readSection($: EngineInterface, mainPath: string): Promise<SectionResult> {
  try {
    const text = await $.fs.read(`${mainPath}/${DISPATCH_TICKET_PATH}`)
    return extractDispatchSection(text)
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${DISPATCH_TICKET_PATH} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
}

/** 讀主 checkout 內票檔的 status；讀不到或無 status 欄時為 unknown。 */
async function readTicketStatus($: EngineInterface, mainPath: string, id: string): Promise<TicketStatus> {
  const path = `${TICKETS_DIR}/${id}.md`
  try {
    return { id, status: parseFrontmatterStatus(await $.fs.read(`${mainPath}/${path}`)) ?? UNKNOWN_STATUS }
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${path} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { id, status: UNKNOWN_STATUS }
  }
}

async function readMergeLog($: EngineInterface, mainPath: string): Promise<MergeLogResult> {
  try {
    return { kind: 'ok', lines: tailLines(await $.fs.read(`${mainPath}/${MERGE_LOG_PATH}`), MERGE_LOG_LINES) }
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${MERGE_LOG_PATH} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
}

/** 本機時間 `YYYY-MM-DD HH:MM:SS`。 */
function formatTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
