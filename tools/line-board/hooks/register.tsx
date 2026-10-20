// line-board：多線開發看板。
// 定時讀主 checkout 的 349 現行佇列行（每條線取最後一行）、佇列票的 status、
// 本 repo 各 session 的狀態（~/.claude/sessions/*.json）、派發紀錄（.claude/dispatch-active.json）、
// 合併閘門的開始與結束紀錄，畫在 Pane。
// 畫面資料放 $.state（hot reload 不遺失）；讀檔與命令一律經 $，解析在 parse.ts。

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type {
  BoardSnapshot,
  DispatchesResult,
  LanesResult,
  MergeGateEntry,
  MergeLogResult,
  SessionState,
  SessionsResult,
  TicketStatus,
} from '../types'
import {
  DISPATCH_ACTIVE_PATH,
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  SESSIONS_DIR,
  TICKETS_DIR,
  UNKNOWN_STATUS,
  dispatchRows,
  dispatchTicketIds,
  formatAge,
  formatDispatchRow,
  formatQueue,
  isInRepo,
  isSessionProcessAlive,
  laneSessionStatus,
  formatMergeGateEntry,
  formatMergeGateHolders,
  laneTicketIds,
  mergeGateEntries,
  mergeGateHolders,
  mergeGateResultColor,
  parseDispatchFile,
  parseFrontmatterStatus,
  parseLanes,
  parseSessionFile,
  parseWorktreePaths,
  sessionStatusFileNames,
  sortSessions,
} from './parse'

const PANE = 'line-board'
const PANE_TITLE = '多線看板'
/** 更新間隔：30 秒。 */
const REFRESH_MS = 30_000
/** 合併閘門紀錄顯示的行數（只計開始與結束行）。 */
const MERGE_LOG_LINES = 8

const snapshot = atom({ plugin: 'line-board', key: 'snapshot' } as const, { kind: 'loading' } as BoardSnapshot)

/** 讀取中旗標：避免上一輪尚未結束時重疊讀取。屬執行期控制，非畫面資料，reload 時歸零即可。 */
let isRefreshing = false

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'board',
      description: '開啟多線看板（349 各線現行佇列、佇列票即時狀態、派發中代理人、各 session 狀態、合併閘門紀錄）',
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
    const { Box, Text } = $.ui.resolve(e)
    const board = await read($, snapshot)

    // hot reload 後 $.state 可能仍是舊版 snapshot（沒有 lanes、sessions、dispatches 欄，或閘門紀錄仍是整行原文），
    // 等下一輪讀取覆寫前先顯示讀取中。
    if (
      board.kind === 'loading' ||
      board.lanes === undefined ||
      board.sessions === undefined ||
      board.dispatches === undefined ||
      (board.mergeLog.kind === 'ok' && (board.mergeLog.entries === undefined || board.mergeLog.holders === undefined))
    ) {
      return <Text dimColor>讀取中…</Text>
    }

    const readAtMs = board.readAtMs
    return (
      <Box flexDirection="column">
        <Text dimColor>
          更新 {board.updatedAt}
          {board.checkoutNote === null ? '' : `｜${board.checkoutNote}`}
        </Text>
        {renderLanes(board.lanes, board.tickets, board.sessions)}
        <Text bold>派發中代理人</Text>
        {renderDispatches(board.dispatches, board.lanes, board.tickets, board.sessions, board.mergeLog)}
        <Text bold>各 session</Text>
        {renderSessions(board.sessions)}
        <Text bold>合併閘門最近紀錄</Text>
        {renderMergeLog(board.mergeLog)}
      </Box>
    )

    function renderLanes(lanes: LanesResult, tickets: readonly TicketStatus[], sessions: SessionsResult) {
      if (lanes.kind === 'error') {
        return <Text color="red">解析失敗：讀取 {DISPATCH_TICKET_PATH} 時發生錯誤（{lanes.message}）</Text>
      }
      if (lanes.lanes.length === 0) return <Text color="yellow">349 尚無現行佇列行</Text>
      return lanes.lanes.map(lane => (
        <Text>
          L{lane.lane}｜{lane.session ?? '（未標 session）'}
          {laneStatusLabel(sessions, lane.session)}｜{formatQueue(lane.tokens, tickets)}
          {laneGoalLabel(lane.goal)}
        </Text>
      ))
    }

    /** 線列票序後的 `｜目標：<文字>`；沒有目標時不顯示。hot reload 後舊 snapshot 的線沒有 goal 欄（undefined），同樣不顯示。 */
    function laneGoalLabel(goal: string | null | undefined): string {
      return goal === null || goal === undefined ? '' : `｜目標：${goal}`
    }

    /** 線列 session 名稱旁的 `［狀態］`；沒標 session 時不顯示，session 狀態讀取失敗時標「狀態不明」。 */
    function laneStatusLabel(sessions: SessionsResult, name: string | null): string {
      if (name === null) return ''
      if (sessions.kind === 'error') return '［狀態不明］'
      return `［${laneSessionStatus(sessions.sessions, name)}］`
    }

    /**
     * 派發中代理人：每列 `L<n> <代理人>｜<任務>｜<階段>｜<距派發時間>`，依線分組、其他最後。
     * 派發紀錄讀取失敗只影響本區塊；sessions 讀不到時無從判定存活，不列條目。
     * 349 或閘門紀錄讀不到時照樣列出：線一律歸其他、不判定閘門。
     */
    function renderDispatches(
      dispatches: DispatchesResult,
      lanes: LanesResult,
      tickets: readonly TicketStatus[],
      sessions: SessionsResult,
      mergeLog: MergeLogResult,
    ) {
      if (dispatches.kind === 'error') {
        return <Text color="red">讀取 {DISPATCH_ACTIVE_PATH} 失敗（{dispatches.message}）</Text>
      }
      if (sessions.kind === 'error') return <Text dimColor>（session 狀態讀取失敗，無法判定派發中的代理人）</Text>
      const rows = dispatchRows(dispatches.records, {
        sessions: sessions.sessions,
        lanes: lanes.kind === 'ok' ? lanes.lanes : [],
        tickets,
        holders: mergeLog.kind === 'ok' ? mergeLog.holders : [],
      })
      if (rows.length === 0) return <Text dimColor>（目前沒有派發中的代理人）</Text>
      return rows.map(row => <Text wrap="truncate-middle">{formatDispatchRow(row, readAtMs)}</Text>)
    }

    function renderSessions(sessions: SessionsResult) {
      if (sessions.kind === 'error') {
        return <Text color="red">讀取 ~/{SESSIONS_DIR} 失敗（{sessions.message}）</Text>
      }
      const rows = sessions.sessions.map(session => renderSession(session))
      const ended =
        sessions.endedCount === 0 ? [] : [<Text dimColor>另有 {sessions.endedCount} 個狀態檔的 pid 已結束，未列出</Text>]
      if (rows.length === 0) return [<Text dimColor>（本 repo 沒有執行中的 session）</Text>, ...ended]
      return [...rows, ...ended]
    }

    function renderSession(session: SessionState) {
      const waitingFor = session.waitingFor === null ? '' : `：${session.waitingFor}`
      const line = `${session.name}｜${session.status}${waitingFor}｜${formatAge(readAtMs, session.statusUpdatedAt)}`
      return session.status === 'waiting' ? (
        <Text color="yellow" bold>
          {line}
        </Text>
      ) : (
        <Text>{line}</Text>
      )
    }

    function renderMergeLog(log: MergeLogResult) {
      if (log.kind === 'error') return <Text color="red">讀取 {MERGE_LOG_PATH} 失敗（{log.message}）</Text>
      const holders = formatMergeGateHolders(log.holders).map(line => (
        <Text color="yellow" bold wrap="truncate-middle">
          {line}
        </Text>
      ))
      if (log.entries.length === 0) return [...holders, <Text dimColor>（尚無紀錄）</Text>]
      return [...holders, ...log.entries.map(entry => renderMergeGateEntry(entry))]
    }

    /**
     * 一行閘門紀錄：欄位行以 truncate-middle 截斷，寬度不足時時間與結果兩端都保留；
     * 結束行依結果上色。格式不符的行原樣換行顯示，不截斷。
     */
    function renderMergeGateEntry(entry: MergeGateEntry) {
      const text = formatMergeGateEntry(entry)
      if (entry.kind === 'raw') return <Text>{text}</Text>
      const color = entry.kind === 'end' ? mergeGateResultColor(entry.result) : undefined
      return (
        <Text color={color} wrap="truncate-middle">
          {text}
        </Text>
      )
    }
  })
}

/** 讀一輪資料並寫入 $.state；任何一項失敗只影響該項的顯示。 */
async function refresh($: EngineInterface): Promise<void> {
  if (isRefreshing) return
  isRefreshing = true
  try {
    const readAtMs = await $.clock.now()
    const root = await $.session.root()
    const { checkoutPaths, checkoutNote } = await findCheckouts($, root)
    const mainPath = checkoutPaths[0] ?? root
    const lanes = await readLanes($, mainPath)
    const dispatches = await readDispatches($, mainPath)
    const laneIds = lanes.kind === 'ok' ? laneTicketIds(lanes.lanes) : []
    const dispatchIds = dispatches.kind === 'ok' ? dispatchTicketIds(dispatches.records) : []
    const ids = [...laneIds, ...dispatchIds.filter(id => !laneIds.includes(id))]
    const tickets = await Promise.all(ids.map(id => readTicketStatus($, mainPath, id)))
    const sessions = await readSessions($, checkoutPaths)
    const mergeLog = await readMergeLog($, mainPath)
    const next: BoardSnapshot = {
      kind: 'ready',
      updatedAt: formatTime(new Date(readAtMs)),
      readAtMs,
      mainPath,
      checkoutNote,
      lanes,
      tickets,
      sessions,
      mergeLog,
      dispatches,
    }
    await update($, snapshot, () => next)
  } catch (error) {
    $.ui.log(`line-board refresh 失敗：${messageOf(error)}`, { to: 'debug' })
  } finally {
    isRefreshing = false
  }
}

/**
 * 以 `git worktree list --porcelain` 取本 repo 的所有 checkout：第一筆為主 checkout（看板 session 在 worktree 內啟動也指向它），
 * 全部用來判定哪些 session 屬於本 repo。失敗時只有 session root 一筆，並帶原因顯示。
 */
async function findCheckouts(
  $: EngineInterface,
  root: string,
): Promise<{ checkoutPaths: string[]; checkoutNote: string | null }> {
  try {
    const result = await $.process.run(['git', 'worktree', 'list', '--porcelain'], { cwd: root })
    if (result.exitCode !== 0) {
      const note = `git worktree list 失敗（exit ${result.exitCode}），改讀 session root`
      $.ui.log(`line-board: ${note}: ${result.stderr.trim()}`, { to: 'debug' })
      return { checkoutPaths: [root], checkoutNote: note }
    }
    const paths = parseWorktreePaths(result.stdout)
    if (paths.length === 0) return { checkoutPaths: [root], checkoutNote: 'git worktree list 無輸出，改讀 session root' }
    return { checkoutPaths: paths, checkoutNote: null }
  } catch (error) {
    const note = `git worktree list 無法執行（${messageOf(error)}），改讀 session root`
    $.ui.log(`line-board: ${note}`, { to: 'debug' })
    return { checkoutPaths: [root], checkoutNote: note }
  }
}

/**
 * 讀 `~/.claude/sessions/` 的狀態檔：只讀副檔名 `.json` 的檔案（`.key` 是金鑰，從不讀取），
 * 留下 cwd 屬於本 repo 的 session，再以 `ps -p <pid> -o lstart=` 對 procStart 確認存活；已結束者只計數不列出。
 */
async function readSessions($: EngineInterface, checkoutPaths: readonly string[]): Promise<SessionsResult> {
  const home = await $.env.get('HOME')
  if (home === undefined || home === '') return { kind: 'error', message: 'HOME 未設定' }
  const dir = `${home}/${SESSIONS_DIR}`
  let names: string[]
  try {
    names = sessionStatusFileNames(await $.fs.list(dir))
  } catch (error) {
    $.ui.log(`line-board: 列出 ${dir} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
  const parsed = await Promise.all(names.map(name => readSessionFile($, `${dir}/${name}`)))
  const inRepo = parsed.filter((session): session is SessionState => session !== null && isInRepo(session.cwd, checkoutPaths))
  const isAlive = await Promise.all(inRepo.map(session => isSessionAlive($, session)))
  const alive = inRepo.filter((_, index) => isAlive[index])
  return { kind: 'ok', sessions: sortSessions(alive), endedCount: inRepo.length - alive.length }
}

/** 讀一個狀態檔；讀不到或格式無效（例如 CC 寫到一半）時回傳 null，下一輪再讀。 */
async function readSessionFile($: EngineInterface, path: string): Promise<SessionState | null> {
  try {
    const session = parseSessionFile(await $.fs.read(path))
    if (session === null) $.ui.log(`line-board: ${path} 格式無法辨識，略過`, { to: 'debug' })
    return session
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${path} 失敗：${messageOf(error)}`, { to: 'debug' })
    return null
  }
}

/**
 * `ps -o lstart` 的執行環境：procStart 是 UTC，ps 須以 UTC 輸出才能逐字比對；
 * LC_ALL=C 固定星期與月份為英文縮寫，不隨使用者 locale 改變。
 */
const PS_ENV: Readonly<Record<string, string>> = { TZ: 'UTC', LC_ALL: 'C' }

/**
 * `ps -p <pid> -o lstart=` exit 0 且啟動時間與 procStart 相同為存活；時間不同表示 pid 已被其他行程重複使用。
 * 無從比對（procStart 缺少、輸出格式不符）時退回只看 exit code；ps 本身無法執行時視為存活，以免整個區塊被清空。
 */
async function isSessionAlive($: EngineInterface, session: SessionState): Promise<boolean> {
  const pid = String(session.pid)
  try {
    const result = await $.process.run(['ps', '-p', pid, '-o', 'lstart='], { env: { ...PS_ENV } })
    const isAlive = isSessionProcessAlive(result.exitCode, result.stdout, session.procStart)
    if (result.exitCode === 0 && !isAlive) {
      $.ui.log(`line-board: pid ${pid} 的啟動時間與 ${session.name} 的 procStart 不符，視為已結束（pid 重複使用）`, {
        to: 'debug',
      })
    }
    return isAlive
  } catch (error) {
    $.ui.log(`line-board: ps -p ${pid} 無法執行（${messageOf(error)}），視為存活`, { to: 'debug' })
    return true
  }
}

async function readLanes($: EngineInterface, mainPath: string): Promise<LanesResult> {
  try {
    return { kind: 'ok', lanes: parseLanes(await $.fs.read(`${mainPath}/${DISPATCH_TICKET_PATH}`)) }
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

/**
 * 讀主 checkout 的派發紀錄：讀不到或格式錯誤（JSON 無效、dispatches 不是陣列）都回傳 error，只影響派發區塊。
 * 不讀各 worktree 的副本：派發紀錄由主 checkout 的 hook 維護，worktree 內的檔案是分支開出當下的舊副本。
 */
async function readDispatches($: EngineInterface, mainPath: string): Promise<DispatchesResult> {
  try {
    const records = parseDispatchFile(await $.fs.read(`${mainPath}/${DISPATCH_ACTIVE_PATH}`))
    if (records === null) {
      $.ui.log(`line-board: ${DISPATCH_ACTIVE_PATH} 格式無法辨識`, { to: 'debug' })
      return { kind: 'error', message: '格式無法辨識' }
    }
    return { kind: 'ok', records }
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${DISPATCH_ACTIVE_PATH} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
}

async function readMergeLog($: EngineInterface, mainPath: string): Promise<MergeLogResult> {
  try {
    const entries = mergeGateEntries(await $.fs.read(`${mainPath}/${MERGE_LOG_PATH}`))
    return { kind: 'ok', entries: entries.slice(-MERGE_LOG_LINES), holders: mergeGateHolders(entries) }
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
