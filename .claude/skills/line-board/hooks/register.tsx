// line-board：多線開發看板。
// 主 checkout 的專案設定（.claude/project-integration/multi-session.json）指定協調票；設定成立時 session 啟動即開 Pane，
// 定時讀協調票的現行佇列行（每條線取最後一行）、佇列票的 status、
// 本 repo 各 session 的狀態（~/.claude/sessions/*.json）、派發紀錄（.claude/dispatch-active.json）、
// 合併閘門的開始與結束紀錄，畫在 Pane。設定不成立時不自動開 Pane、不定時讀取，/board 開啟後顯示設定提示。
// 畫面資料與群組的手動展開狀態放 $.state（hot reload 不遺失）；讀檔與命令一律經 $，解析經 parse.ts 匯出（實作分在各 domain 模組）。
// 本檔負責 hook 註冊、定時刷新的協調、snapshot 與 Pane 組裝；各項的讀取在 readers.ts，各區塊的繪製在 *View.tsx。
// 另以 session.measure 把本 session 的 context 用量寫到主 checkout 的用量檔（記錄內容見 contextUsage.ts），不論專案設定是否成立。

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BoardSnapshot, UnsetProjectConfig } from '../types'
import { renderConfigNotice, renderGroup, renderLaneGroups, sectionFrame } from './lanesView'
import type { Elements, ToggleGroup } from './lanesView'
import { lineStatusText } from './lineStatus'
import { renderMergeLog } from './mergeGateView'
import {
  MERGE_GATE_GROUP_ID,
  SESSIONS_GROUP_ID,
  contextUsagePath,
  contextUsageRecord,
  dispatchTicketIds,
  isContextChanged,
  laneTicketIds,
  messageOf,
  serializeContextUsage,
  ticketPrefixOf,
  toggledOverrides,
} from './parse'
import type { CompactionWindow, ContextFill } from './parse'
import {
  PROJECT_CONFIG_PATH,
  findCheckouts,
  readDispatches,
  readLanes,
  readMergeLog,
  readProjectConfig,
  readSessions,
  readTicketStatus,
} from './readers'
import { renderSessions } from './sessionsView'
import { renderUserTodos } from './userTodosView'

const PANE = 'line-board'
const PANE_TITLE = '多線看板'
/** 模型可呼叫的接續狀態工具：短名與完整名（mcp__<plugin>__<name>）。 */
const LINE_STATUS_TOOL = 'line_status'
const LINE_STATUS_TOOL_FULL = `mcp__line-board__${LINE_STATUS_TOOL}`
/** 工具說明（模型讀的）：用途、何時呼叫、輸出內容。 */
const LINE_STATUS_DESCRIPTION =
  '多 session 協調：回報協調票上每條線的接續狀態（已收線、/clear 後繼續、/compact 後繼續、新 session 接手、無人持有、來源不明）與判讀依據，並列出過期項（收線寫法不合規、名稱不在存活 session 中但仍有佇列、佇列的票全部 completed 但還沒收線）。主控在 /clear 或 /compact 後自我接續、每輪佇列更新前呼叫。唯讀，不需參數。'
/** 更新間隔：30 秒。 */
const REFRESH_MS = 30_000

const snapshot = atom({ plugin: 'line-board', key: 'snapshot' } as const, { kind: 'loading' } as BoardSnapshot)
/** 使用者按過的群組的展開狀態（群組 id → 是否展開）；與 snapshot 分開，資料刷新不覆寫。 */
const expanded = atom({ plugin: 'line-board', key: 'expanded' } as const, {})

/** 讀取中旗標：避免上一輪尚未結束時重疊讀取。屬執行期控制，非畫面資料，reload 時歸零即可。 */
let isRefreshing = false
/** 定時讀取已啟動：設定成立的 session 啟動時或第一次執行 /board 時啟動一次。屬執行期控制，同 isRefreshing。 */
let isTimerStarted = false
/** 用量檔所在的主 checkout：第一次寫用量檔時以 findCheckouts 取得後沿用（每輪回應都寫，不每次跑 git）。reload 時重取即可。 */
let usageMainPath: string | null = null
/** compaction window 的快取：以模型 window 為鍵，換模型（window 變了）才重量；量測失敗不快取，下次重試。 */
let compactionCache: { window: number; compaction: CompactionWindow | null } | null = null
/** 用量檔寫入失敗已送 transcript：只送第一次（每輪回應都寫，連續失敗不洗版），之後只記 debug。 */
let hasReportedUsageWriteFailure = false

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'board',
      description: '開啟多線看板（協調票各線現行佇列、佇列票即時狀態、派發中代理人、各 session 狀態、合併閘門紀錄）',
    })
    // 工具註冊失敗不影響看板與 session 啟動；送 transcript 使使用者可見（否則與「工具不存在」同形）
    await $.tool
      .register({
        name: LINE_STATUS_TOOL,
        description: LINE_STATUS_DESCRIPTION,
      })
      .catch(error => $.ui.log(`line-board 警告：註冊 ${LINE_STATUS_TOOL} 失敗：${messageOf(error)}`, { to: 'transcript' }))
    void openIfConfigured($)

    return next(e)
  })

  // 只觀察：context 用量變動時寫本 session 的用量檔；失敗不影響量測結果的傳遞
  on('session.measure', async ($, e, next) => {
    if (isContextChanged(e.changed)) await writeContextUsage($, e.context)
    return next(e)
  })

  // 讀取失敗時回傳說明文字（不 deny）：模型要讀得到「為何判不出」，否則與工具壞掉同形
  on('tool.call', { tool: LINE_STATUS_TOOL_FULL }, async $ => {
    try {
      return { result: await lineStatusText($, formatTime(new Date(await $.clock.now()))) }
    } catch (error) {
      $.ui.log(`line-board 警告：${LINE_STATUS_TOOL} 判讀失敗：${messageOf(error)}`, { to: 'debug' })
      return { result: `line_status 判讀失敗：${messageOf(error)}` }
    }
  })

  on('command.run', { command: 'board' }, async $ => {
    startTimer($)
    await $.ui.open({ id: PANE, title: PANE_TITLE })
    void refresh($)

    return { text: '多線看板已開啟。' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const board = await read($, snapshot)
    const overrides = await read($, expanded)
    const elements: Elements = { Box, Text, Button }

    if (board.kind === 'unconfigured') return renderConfigNotice(elements, board)
    // hot reload 後 $.state 可能仍是舊版 snapshot（沒有 lanes、sessions、dispatches 欄，協調票結果沒有原文行與待辦，
    // 或閘門紀錄仍是整行原文），等下一輪讀取覆寫前先顯示讀取中。
    if (
      board.kind === 'loading' ||
      board.lanes === undefined ||
      (board.lanes.kind === 'ok' && (board.lanes.lines === undefined || board.lanes.todos === undefined)) ||
      board.sessions === undefined ||
      board.dispatches === undefined ||
      (board.mergeLog.kind === 'ok' && (board.mergeLog.entries === undefined || board.mergeLog.holders === undefined))
    ) {
      return <Text dimColor>讀取中…</Text>
    }

    // 按下標題列：onPress 寫入手動狀態後 Pane 重畫；失敗為 warning 級（$.ui.log 無級別，送 transcript 使畫面可見）
    const toggle: ToggleGroup = (id, isOpen) => {
      const onError = (error: unknown) => $.ui.log(`line-board 警告：切換群組 ${id} 失敗：${messageOf(error)}`, { to: 'transcript' })
      update($, expanded, map => toggledOverrides(map, id, isOpen)).catch(onError)
    }
    const bottom = (id: string, title: string) => sectionFrame(id, title, overrides)
    return (
      <Box flexDirection="column">
        <Text dimColor>
          更新 {board.updatedAt}
          {board.checkoutNote === null ? '' : `｜${board.checkoutNote}`}
        </Text>
        {renderUserTodos(elements, board, overrides, toggle)}
        {renderLaneGroups(elements, board, overrides, toggle)}
        {renderGroup(elements, bottom(SESSIONS_GROUP_ID, '各 session'), toggle, () => renderSessions(elements, board))}
        {renderGroup(elements, bottom(MERGE_GATE_GROUP_ID, '合併閘門最近紀錄'), toggle, () => renderMergeLog(elements, board))}
      </Box>
    )
  })
}

/** 啟動定時讀取（只啟動一次）。 */
function startTimer($: EngineInterface): void {
  if (isTimerStarted) return
  isTimerStarted = true
  $.clock.every(REFRESH_MS, () => refresh($))
}

/**
 * session 啟動時：專案設定成立才啟動定時讀取並開 Pane；不成立時只把設定提示寫入 $.state（/board 開啟後顯示），
 * 不定時讀取。先讀 session root 的設定，成立即開 Pane，不等 git（主 checkout 的 session 不需找主 checkout）；
 * root 讀不到才以 git worktree list 找主 checkout 再讀（worktree 內的 session）。
 * 失敗送 transcript（使用者可見，否則 Pane 沒開與無設定在畫面上同形），不影響 session 啟動。
 */
async function openIfConfigured($: EngineInterface): Promise<void> {
  try {
    const root = await $.session.root()
    const rootConfig = await readProjectConfig($, root)
    if (rootConfig.kind === 'ok') {
      await openConfiguredPane($)
      return
    }
    const { checkoutPaths } = await findCheckouts($, root)
    const mainPath = checkoutPaths[0] ?? root
    const config = mainPath === root ? rootConfig : await readProjectConfig($, mainPath)
    if (config.kind !== 'ok') {
      await update($, snapshot, () => unconfiguredSnapshot(mainPath, config))
      return
    }
    await openConfiguredPane($)
  } catch (error) {
    $.ui.log(`line-board 啟動檢查失敗：${messageOf(error)}`, { to: 'transcript' })
  }
}

/** 設定成立：啟動定時讀取、開 Pane，並讀第一輪資料。先發出開 Pane 再讀，Pane 不等第一輪讀取；開 Pane 失敗由呼叫端 catch。 */
async function openConfiguredPane($: EngineInterface): Promise<void> {
  startTimer($)
  const opening = $.ui.open({ id: PANE, title: PANE_TITLE })
  void refresh($)
  await opening
}

/** 設定不成立時的 snapshot：設定檔的絕對路徑與原因。 */
function unconfiguredSnapshot(mainPath: string, config: UnsetProjectConfig): BoardSnapshot {
  return { kind: 'unconfigured', configPath: `${mainPath}/${PROJECT_CONFIG_PATH}`, config }
}

/**
 * 讀一輪資料並寫入 $.state：先讀專案設定，不成立時只寫設定提示；成立時讀其他各項，
 * 任何一項失敗只影響該項的顯示（各讀取函式自行吸收失敗，見 readers.ts）。
 */
async function refresh($: EngineInterface): Promise<void> {
  if (isRefreshing) return
  isRefreshing = true
  try {
    const readAtMs = await $.clock.now()
    const root = await $.session.root()
    const { checkoutPaths, checkoutNote } = await findCheckouts($, root)
    const mainPath = checkoutPaths[0] ?? root
    const config = await readProjectConfig($, mainPath)
    if (config.kind !== 'ok') {
      await update($, snapshot, () => unconfiguredSnapshot(mainPath, config))
      return
    }
    const lanes = await readLanes($, mainPath, config.coordinationTicket)
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
      // readProjectConfig 已確認協調票推導得出前綴，?? 只為型別收窄；空字串表示不去前綴
      ticketPrefix: ticketPrefixOf(config.coordinationTicket) ?? '',
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
 * 把本 session 的 context 用量寫到主 checkout 的用量檔（看板與 line_status 據以判定待 compact／待 clear）。
 * 不看專案設定：用量檔只在主 checkout 的 hook-logs 下，沒有協調票的專案也無害。
 * 失敗第一次送 transcript（使用者可見，否則與「用量檔沒人寫」同形），之後記 debug，不影響 session。
 */
async function writeContextUsage($: EngineInterface, context: ContextFill): Promise<void> {
  try {
    const sessionId = await $.session.id()
    const path = contextUsagePath(await mainCheckoutForUsage($), sessionId)
    if (path === null) {
      $.ui.log(`line-board: sessionId 含不允許的字元（${sessionId}），不寫用量檔`, { to: 'debug' })
      return
    }
    const compaction = await compactionWindowOf($, context.window)
    const record = contextUsageRecord({ sessionId, context, compaction, measuredAt: await $.clock.now() })
    await $.fs.write(path, serializeContextUsage(record))
  } catch (error) {
    const message = `line-board 警告：寫 context 用量檔失敗：${messageOf(error)}`
    $.ui.log(message, { to: hasReportedUsageWriteFailure ? 'debug' : 'transcript' })
    hasReportedUsageWriteFailure = true
  }
}

/** 用量檔所在的主 checkout：第一次以 findCheckouts 取得後快取（失敗時 findCheckouts 退回 session root）。 */
async function mainCheckoutForUsage($: EngineInterface): Promise<string> {
  if (usageMainPath !== null) return usageMainPath
  const root = await $.session.root()
  const { checkoutPaths } = await findCheckouts($, root)
  usageMainPath = checkoutPaths[0] ?? root
  return usageMainPath
}

/**
 * compaction window（/context 的 rawMaxTokens 與 auto-compact 門檻）：以 summary breakdown 量測（本機估算，不送 API），
 * 依模型 window 快取。量不到時回傳 null 並記 debug，用量檔的 compact 欄位為 null。
 */
async function compactionWindowOf($: EngineInterface, window: number): Promise<CompactionWindow | null> {
  if (compactionCache !== null && compactionCache.window === window) return compactionCache.compaction
  try {
    const { breakdown } = (await $.session.usage({ breakdown: 'summary' })).context
    const compaction = breakdown === undefined ? null : { rawMaxTokens: breakdown.rawMaxTokens, autoCompactThreshold: breakdown.autoCompactThreshold }
    compactionCache = { window, compaction }
    return compaction
  } catch (error) {
    $.ui.log(`line-board: 量測 compaction window 失敗：${messageOf(error)}，用量檔的 compact 欄位為 null`, { to: 'debug' })
    return null
  }
}

/** 本機時間 `YYYY-MM-DD HH:MM:SS`。 */
function formatTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}
