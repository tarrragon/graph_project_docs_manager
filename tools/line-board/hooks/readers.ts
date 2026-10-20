// line-board 的讀取：以 $ 讀檔與執行命令，取得一輪 snapshot 所需的各項資料，解析經 parse.ts 匯出。
// 每個讀取函式自行吸收失敗（回傳 error 結果、null 或 unknown，並記 debug log），只影響該項的顯示。
// register.tsx 的 refresh 依序呼叫本檔各函式並組成 snapshot。

import type { EngineInterface } from 'claude-code'

import type {
  DispatchesResult,
  LanesResult,
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
  isInRepo,
  isSessionProcessAlive,
  mergeGateEntries,
  mergeGateHolders,
  parseDispatchFile,
  parseFrontmatterStatus,
  parseLanes,
  parseSessionFile,
  parseWorktreePaths,
  sessionStatusFileNames,
  sortSessions,
} from './parse'

/** 合併閘門紀錄顯示的行數（只計開始與結束行）。 */
const MERGE_LOG_LINES = 8

/**
 * 以 `git worktree list --porcelain` 取本 repo 的所有 checkout：第一筆為主 checkout（看板 session 在 worktree 內啟動也指向它），
 * 全部用來判定哪些 session 屬於本 repo。失敗時只有 session root 一筆，並帶原因顯示。
 */
export async function findCheckouts(
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
export async function readSessions($: EngineInterface, checkoutPaths: readonly string[]): Promise<SessionsResult> {
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

export async function readLanes($: EngineInterface, mainPath: string): Promise<LanesResult> {
  try {
    return { kind: 'ok', lanes: parseLanes(await $.fs.read(`${mainPath}/${DISPATCH_TICKET_PATH}`)) }
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${DISPATCH_TICKET_PATH} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
}

/** 讀主 checkout 內票檔的 status；讀不到或無 status 欄時為 unknown。 */
export async function readTicketStatus($: EngineInterface, mainPath: string, id: string): Promise<TicketStatus> {
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
export async function readDispatches($: EngineInterface, mainPath: string): Promise<DispatchesResult> {
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

export async function readMergeLog($: EngineInterface, mainPath: string): Promise<MergeLogResult> {
  try {
    const entries = mergeGateEntries(await $.fs.read(`${mainPath}/${MERGE_LOG_PATH}`))
    return { kind: 'ok', entries: entries.slice(-MERGE_LOG_LINES), holders: mergeGateHolders(entries) }
  } catch (error) {
    $.ui.log(`line-board: 讀取 ${MERGE_LOG_PATH} 失敗：${messageOf(error)}`, { to: 'debug' })
    return { kind: 'error', message: messageOf(error) }
  }
}

/** 例外的訊息文字：Error 取 message，其他值轉字串。register.tsx 的失敗日誌也用它。 */
export function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
