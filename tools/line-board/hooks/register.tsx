// line-board：多線開發看板（第一階段）。
// 定時讀 repo 的 349〈分派〉段落、佇列票在 main 與各 worktree 的 status、合併閘門紀錄，畫在 Pane。
// 畫面資料放 $.state（hot reload 不遺失）；讀檔與命令一律經 $，解析與合併規則在 status.ts。

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BoardSnapshot, MergeLogResult, SectionResult, TicketStatus } from '../types'
import {
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  TICKETS_DIR,
  annotateQueue,
  extractDispatchSection,
  extractQueueIds,
  parseFrontmatterStatus,
  parseWorktreeList,
  pickStatus,
  tailLines,
} from './status'

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

    const fromWorktree = board.tickets.filter(ticket => ticket.source !== 'main')

    return (
      <Box flexDirection="column">
        <Text dimColor>
          更新 {board.updatedAt}｜worktree {board.worktreeCount} 個
          {board.worktreeNote === null ? '' : `｜${board.worktreeNote}`}
        </Text>
        {renderSection(board.section, board.tickets)}
        {fromWorktree.length > 0 && <Text bold>以 worktree 為準（·wt）</Text>}
        {fromWorktree.map(ticket => (
          <Text dimColor>
            {ticket.id} {ticket.status} ← {ticket.source}
          </Text>
        ))}
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
    const { mainPath, worktrees, worktreeNote } = await listWorktrees($, root)
    const section = await readSection($, mainPath)
    const ids = section.kind === 'ok' ? extractQueueIds(section.markdown) : []
    const tickets = await Promise.all(ids.map(id => readTicketStatus($, id, mainPath, worktrees)))
    const mergeLog = await readMergeLog($, mainPath)
    const next: BoardSnapshot = {
      kind: 'ready',
      updatedAt: formatTime(new Date()),
      mainPath,
      worktreeCount: worktrees.length,
      worktreeNote,
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

/** 以 `git worktree list --porcelain` 取 main 與其餘 worktree；失敗時退回只讀 session root。 */
async function listWorktrees(
  $: EngineInterface,
  root: string,
): Promise<{ mainPath: string; worktrees: string[]; worktreeNote: string | null }> {
  try {
    const result = await $.process.run(['git', 'worktree', 'list', '--porcelain'], { cwd: root })
    if (result.exitCode !== 0) {
      const note = `git worktree list 失敗（exit ${result.exitCode}）`
      $.ui.log(`line-board: ${note}: ${result.stderr.trim()}`, { to: 'debug' })
      return { mainPath: root, worktrees: [], worktreeNote: note }
    }
    const { main, worktrees } = parseWorktreeList(result.stdout)
    return { mainPath: main ?? root, worktrees, worktreeNote: null }
  } catch (error) {
    const note = `git worktree list 無法執行（${messageOf(error)}）`
    $.ui.log(`line-board: ${note}`, { to: 'debug' })
    return { mainPath: root, worktrees: [], worktreeNote: note }
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

async function readTicketStatus(
  $: EngineInterface,
  id: string,
  mainPath: string,
  worktrees: readonly string[],
): Promise<TicketStatus> {
  const mainStatus = await readStatusAt($, mainPath, id)
  const worktreeStatuses = await Promise.all(
    worktrees.map(async path => ({ path, status: await readStatusAt($, path, id) })),
  )
  return { id, ...pickStatus(mainStatus, worktreeStatuses) }
}

/** 讀某個 checkout 內票檔的 status；票檔不存在（worktree 開出時尚無此票）屬常態，回傳 null 不記錄。 */
async function readStatusAt($: EngineInterface, checkout: string, id: string): Promise<string | null> {
  try {
    return parseFrontmatterStatus(await $.fs.read(`${checkout}/${TICKETS_DIR}/${id}.md`))
  } catch {
    // 靜默原因：各 worktree 缺票檔是預期情形（分支早於建票），逐檔記錄只會淹沒 debug log。
    return null
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
