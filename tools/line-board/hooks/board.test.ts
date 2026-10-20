// line-board 的測試：parse.ts 純函式（checkout 判定、現行佇列行解析、佇列格式化、session 狀態檔、閘門紀錄篩選、
// 派發紀錄解析與流程階段推導）與 Pane 的端到端繪製。

import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import type { DispatchRecord, SessionState } from '../types'
import {
  DISPATCH_ACTIVE_PATH,
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  SESSIONS_DIR,
  TICKETS_DIR,
  dispatchRows,
  dispatchStage,
  dispatchTicketIds,
  formatAge,
  formatDispatchRow,
  formatMergeGateEntry,
  formatMergeGateHolders,
  formatQueue,
  isInRepo,
  isSessionProcessAlive,
  laneSessionStatus,
  laneTicketIds,
  mergeGateEntries,
  mergeGateHolders,
  mergeGateLines,
  mergeGateResultColor,
  normalizeProcStart,
  parseDispatchFile,
  parseFrontmatterStatus,
  parseIsoMs,
  parseMergeGateLine,
  parseLaneGoals,
  parseLanes,
  parseQueue,
  parseSessionFile,
  parseWorktreePaths,
  sessionStatusFileNames,
  shortBranch,
  sortSessions,
} from './parse'

/** 〈看板讀取約定〉的格式說明行：行首不是 `**L`，行內以反引號引用範本，不得被當成一條線。 */
const TEMPLATE_NOTE =
  '337 看板掃本票整個 Solution，每個 `L<n>` 只取最後一次出現的現行佇列行。格式：`**L<n> 現行佇列**（<ListAgents 顯示的 session 名稱>）：<短票號，以 → 與 ∥ 分隔>`，獨立成段、行首即 `**L`。'

/** 行首即範本、但 n 不是數字：不得被當成一條線。 */
const TEMPLATE_AT_LINE_START = '**L<n> 現行佇列**（<session 名稱>）：<票序>'

/**
 * 仿 349 票檔結構：舊〈分派〉段的佇列行、清單項的舊格式現行佇列、格式說明行，
 * 以及同一條線的多行現行佇列（歷史行在前、現行行在後），最後接 `## Test Results`。
 */
const TICKET_349 = [
  '---',
  'id: 0.5.0-W1-349',
  'status: in_progress',
  '---',
  '## Problem Analysis',
  '**L30 現行佇列**（s-out）：801',
  '## Solution',
  '### 分派（用戶裁定 2026-10-19）',
  '佇列：341.1 → 343 → 284 收尾',
  '### L7 佇列調整',
  '- **L7 現行佇列**：257 ∥ 350 → 328',
  '### 看板讀取約定（2026-10-19，-1b 定案）',
  TEMPLATE_NOTE,
  '',
  TEMPLATE_AT_LINE_START,
  '',
  '**L7 現行佇列**（graph-project-docs-manager-f8）：351 → 328.1 → 348',
  '',
  '**L9 現行佇列**（graph-project-docs-manager-3e）：356 → 353.1 ∥ 341.2.1 → 284',
  '',
  '**L13 現行佇列**（graph-project-docs-manager-1b）：337.1 → 337.2.1',
  '',
  '**L11 現行佇列**（graph-project-docs-manager-x9）：900',
  '### L13 佇列更正',
  '**L13 現行佇列**（graph-project-docs-manager-1b）：337.1（待用戶實機驗證）→ 337.3 → 337.2.1',
  '',
  '**L7 現行佇列**（graph-project-docs-manager-f9）：351 → 145',
  '',
  '**L11 現行佇列**（graph-project-docs-manager-x9）：（無）',
  '## Test Results',
  '**L20 現行佇列**（s-out）：999',
].join('\n')

/**
 * 仿 349 加上線目標行：清單項、表格內、行內反引號範本、行首範本（n 非數字）、整行以反引號包住的目標行都不算；
 * L13 有兩行（舊目標在前），L7 的最後一行寫（無）清除較早的目標，L9 沒有可採用的目標行；
 * Solution 之外的目標行不算。
 */
const TICKET_349_GOALS = TICKET_349.replace(
  '## Test Results',
  [
    '- **L7 目標**：清單項的目標',
    '| **L9 目標**：表格內的目標 | 備註 |',
    '用戶裁定格式為 `**L<n> 目標**：<一句話目標>`，規則同現行佇列行。',
    '**L<n> 目標**：<一句話目標>',
    '`**L9 目標**：反引號範本的目標`',
    '**L13 目標**：舊目標',
    '',
    '**L13 目標**：顯示各線目標與派發中代理人',
    '',
    '**L7 目標**：會被清除的目標',
    '',
    '**L7 目標**：（無）',
    '## Test Results',
    '**L9 目標**：Solution 之外的目標',
  ].join('\n'),
)

/** 仿 worktree-merge.log：開始／結束之間夾著驗收、測試、預檢等其他行。 */
const MERGE_LOG = [
  '2026-10-19T16:04:26 [合併前驗收] target=0.5.0-W1-328 reason=收尾',
  '2026-10-19T16:04:26 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-328｜commit ee5e80e6b9a4',
  '2026-10-19T16:04:27 [合併閘門] 預檢｜無衝突',
  '2026-10-19T16:09:01 [合併前測試] 套件 hooks：綠燈｜7212 passed',
  '2026-10-19T16:11:45 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-328｜commit a9dc3b442c24｜結果 寫入',
  '',
].join('\n')

/**
 * 仿真實 worktree-merge.log（2026-10-19 16:19–16:41 段）：兩個分支的開始與結束交錯，
 * 最後一筆開始（feat/0.5.0-W1-351）沒有對應結束，代表閘門正被它持有。
 * 另插一筆真實紀錄中分支名最長的中止結束行（取自 2026-10-15 的紀錄格式），測窄面板寬度與中止上色。
 */
const MERGE_LOG_HOLDING = [
  '2026-10-19T16:19:45 [合併閘門] 開始｜target main｜分支 worktree-agent-a352c31d77c3daa98｜commit c6f614e51840',
  '2026-10-19T16:21:08 [合併閘門] 開始｜target main｜分支 worktree-agent-a74808594aa6f7e6f｜commit d198cdfebf44',
  '2026-10-19T16:21:11 [合併閘門] 結束｜target main｜分支 worktree-agent-a74808594aa6f7e6f｜commit fd67ce66f7e5｜結果 寫入',
  '2026-10-19T16:26:50 [合併前測試] 套件 hooks：綠燈｜7222 passed',
  '2026-10-19T16:31:50 [合併閘門] 結束｜target main｜分支 worktree-agent-a352c31d77c3daa98｜commit ca1d747c0332｜結果 寫入',
  '2026-10-15T22:15:13 [合併閘門] 結束｜target main｜分支 worktree-doc-split-338-2-5｜commit 9238cea6802f｜結果 中止',
  '2026-10-19T16:41:49 [合併前驗收] target=0.5.0-W1-351 reason=收尾',
  '2026-10-19T16:41:49 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-351｜commit 52477a34f0ce',
  '',
].join('\n')

/**
 * 仿真實 worktree-merge.log（2026-10-19 16:19–16:31 段）的重疊合併：a352 開始後，免跑測試的 a748 開始並結束，
 * a352 才結束。兩個開始行後各有一行 328.1 之後的三行格式預檢行（帶分支與結果欄），它不是結束行。
 */
const MERGE_LOG_OVERLAP = [
  '2026-10-19T16:19:45 [合併閘門] 開始｜target main｜分支 worktree-agent-a352c31d77c3daa98｜commit c6f614e51840',
  '2026-10-19T16:19:46 [合併閘門] 預檢｜target main｜分支 worktree-agent-a352c31d77c3daa98｜commit c6f614e51840｜結果 無衝突',
  '2026-10-19T16:21:08 [合併閘門] 開始｜target main｜分支 worktree-agent-a74808594aa6f7e6f｜commit d198cdfebf44',
  '2026-10-19T16:21:09 [合併閘門] 預檢｜target main｜分支 worktree-agent-a74808594aa6f7e6f｜commit d198cdfebf44｜結果 無衝突',
  '2026-10-19T16:21:11 [合併閘門] 結束｜target main｜分支 worktree-agent-a74808594aa6f7e6f｜commit fd67ce66f7e5｜結果 寫入',
  '2026-10-19T16:26:50 [合併前測試] 套件 hooks：綠燈｜7222 passed',
  '2026-10-19T16:31:50 [合併閘門] 結束｜target main｜分支 worktree-agent-a352c31d77c3daa98｜commit ca1d747c0332｜結果 寫入',
  '',
].join('\n')

/** 格式不符的 `[合併閘門]` 行：開始行沒有欄位、結束行沒有結果、時間戳不是 ISO 形式。 */
const MALFORMED_GATE_LINES = [
  '2026-10-19T16:50:00 [合併閘門] 開始',
  '2026-10-19T16:51:00 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-400｜commit abc',
  '2026-10-19 16:52:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-401｜commit def',
]

/**
 * 終端機顯示寬度：CJK 與全形字元占 2 欄，其餘 1 欄。
 * 測試套件只拿得到畫出的樹、拿不到終端機的實際繪製，以此推算一行在固定欄寬的面板內是否放得下。
 */
function displayWidth(text: string): number {
  let width = 0
  for (const char of text) {
    const code = char.codePointAt(0) ?? 0
    const isWide =
      (code >= 0x1100 && code <= 0x115f) ||
      (code >= 0x2e80 && code <= 0xa4cf) ||
      (code >= 0xac00 && code <= 0xd7a3) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xfe30 && code <= 0xfe4f) ||
      (code >= 0xff00 && code <= 0xff60) ||
      (code >= 0xffe0 && code <= 0xffe6)
    width += isWide ? 2 : 1
  }
  return width
}

const ticketFile =(status: string) => `---\nid: x\nstatus: ${status}\nwho: y\n---\n# body\nstatus: ignored\n`

describe('parseWorktreePaths', () => {
  test('取 git worktree list 的所有 checkout，主 checkout 在第一筆', () => {
    const porcelain = [
      'worktree /repo',
      'HEAD aaa',
      'branch refs/heads/main',
      '',
      'worktree /repo/.claude/worktrees/agent-x',
      'HEAD ddd',
      'branch refs/heads/worktree-agent-x',
      'locked claude agent agent-x',
      '',
    ].join('\n')
    expect(parseWorktreePaths(porcelain)).toEqual(['/repo', '/repo/.claude/worktrees/agent-x'])
  })

  test('空輸出回傳空陣列', () => {
    expect(parseWorktreePaths('')).toEqual([])
  })
})

/** 仿 `~/.claude/sessions/<pid>.json`：只放看板用到的欄位與一個不應被保存的欄位。 */
const sessionJson = (fields: Record<string, unknown>) =>
  JSON.stringify({ sessionId: 'x', messagingSocketPath: '/tmp/sock', ...fields })

const session = (fields: Partial<SessionState> & { name: string; status: string }): SessionState => ({
  pid: 1,
  cwd: '/repo',
  waitingFor: null,
  statusUpdatedAt: null,
  procStart: null,
  sessionId: null,
  ...fields,
})

describe('sessionStatusFileNames', () => {
  test('只取 .json 一般檔案；.key 金鑰與目錄不在其中', () => {
    const entry = (name: string, kind: 'file' | 'dir' = 'file') => ({ name, kind, size: 1, mtimeMs: 0, isLink: false })
    expect(
      sessionStatusFileNames([
        entry('101.json'),
        entry('101.abc.key'),
        entry('102.json.key'),
        entry('sub.json', 'dir'),
        entry('103.json'),
      ]),
    ).toEqual(['101.json', '103.json'])
  })
})

describe('parseSessionFile', () => {
  test('取 pid、name、cwd、status、waitingFor、statusUpdatedAt、procStart、sessionId，其他欄位不保存', () => {
    const text = sessionJson({
      pid: 7,
      name: 's-7',
      cwd: '/repo',
      status: 'waiting',
      waitingFor: 'input needed',
      statusUpdatedAt: 1000,
      procStart: 'Mon Oct 19 09:09:02 2026',
    })
    expect(parseSessionFile(text)).toEqual({
      pid: 7,
      name: 's-7',
      cwd: '/repo',
      status: 'waiting',
      waitingFor: 'input needed',
      statusUpdatedAt: 1000,
      procStart: 'Mon Oct 19 09:09:02 2026',
      sessionId: 'x',
    })
  })

  test('沒有 waitingFor、statusUpdatedAt、procStart 或 sessionId 時為 null；未知 status 原樣保存', () => {
    expect(parseSessionFile(sessionJson({ pid: 7, name: 's', cwd: '/r', status: 'compacting', sessionId: undefined }))).toEqual({
      pid: 7,
      name: 's',
      cwd: '/r',
      status: 'compacting',
      waitingFor: null,
      statusUpdatedAt: null,
      procStart: null,
      sessionId: null,
    })
  })

  test('JSON 無效或缺少必要欄位時回傳 null', () => {
    expect(parseSessionFile('{"pid": 7, "name"')).toBeNull()
    expect(parseSessionFile('null')).toBeNull()
    expect(parseSessionFile(sessionJson({ pid: '7', name: 's', cwd: '/r', status: 'idle' }))).toBeNull()
    expect(parseSessionFile(sessionJson({ pid: 7, name: 's', cwd: '/r' }))).toBeNull()
  })
})

describe('isInRepo', () => {
  test('等於或位於任一 checkout 之下才算；名稱前綴相同的兄弟目錄不算', () => {
    const paths = ['/repo', '/repo/.claude/worktrees/agent-x']
    expect(isInRepo('/repo', paths)).toBe(true)
    expect(isInRepo('/repo/tools', paths)).toBe(true)
    expect(isInRepo('/repo/.claude/worktrees/agent-x/lib', paths)).toBe(true)
    expect(isInRepo('/repo-other', paths)).toBe(false)
    expect(isInRepo('/other', paths)).toBe(false)
  })
})

describe('sortSessions', () => {
  test('shell 與 busy 同組（組內依名稱交錯），排在 waiting 之後、idle 之前；status 原值保留', () => {
    const sorted = sortSessions([
      session({ name: 'e', status: 'idle' }),
      session({ name: 'c', status: 'shell' }),
      session({ name: 'd', status: 'busy' }),
      session({ name: 'a', status: 'busy' }),
      session({ name: 'f', status: 'waiting' }),
    ])
    expect(sorted.map(item => `${item.status}:${item.name}`)).toEqual(['waiting:f', 'busy:a', 'shell:c', 'busy:d', 'idle:e'])
  })

  test('依 waiting、busy、idle 排序，未知 status 排最後；同狀態依名稱', () => {
    const sorted = sortSessions([
      session({ name: 'b', status: 'idle' }),
      session({ name: 'z', status: 'compacting' }),
      session({ name: 'c', status: 'busy' }),
      session({ name: 'a', status: 'idle' }),
      session({ name: 'd', status: 'waiting' }),
    ])
    expect(sorted.map(item => `${item.status}:${item.name}`)).toEqual([
      'waiting:d',
      'busy:c',
      'idle:a',
      'idle:b',
      'compacting:z',
    ])
  })
})

describe('laneSessionStatus', () => {
  const sessions = [
    session({ name: 's-1', status: 'waiting', waitingFor: 'input needed', statusUpdatedAt: 5 }),
    session({ name: 's-2', status: 'idle', statusUpdatedAt: 1 }),
    session({ name: 's-2', status: 'busy', statusUpdatedAt: 9 }),
  ]

  test('waiting 附 waitingFor；同名多筆取最新一筆；比對不到為離線', () => {
    expect(laneSessionStatus(sessions, 's-1')).toBe('waiting：input needed')
    expect(laneSessionStatus(sessions, 's-2')).toBe('busy')
    expect(laneSessionStatus(sessions, 's-9')).toBe('離線')
    expect(laneSessionStatus(sessions, null)).toBe('')
  })
})

/**
 * 取自本機真實 session（2026-10-19，CC 2.1.303，本機時區 CST +08:00）：
 * 狀態檔 procStart 與 `TZ=UTC ps -p <pid> -o lstart=` 逐字相同（ps 輸出另帶行尾空白），
 * 不帶 TZ 的 ps 輸出為本機時間，晚 8 小時。
 */
const REAL_PROC_START = 'Mon Oct 19 09:09:02 2026'
const REAL_LSTART_UTC = 'Mon Oct 19 09:09:02 2026    \n'
const REAL_LSTART_LOCAL = 'Mon Oct 19 17:09:02 2026    \n'

describe('normalizeProcStart', () => {
  test('去頭尾空白、壓縮連續空白（個位數日期的補位空白）；不符 lstart 格式時為 null', () => {
    expect(normalizeProcStart(REAL_LSTART_UTC)).toBe(REAL_PROC_START)
    expect(normalizeProcStart('Mon Oct  5 09:09:02 2026')).toBe('Mon Oct 5 09:09:02 2026')
    expect(normalizeProcStart('2026-10-19T09:09:02Z')).toBeNull()
    expect(normalizeProcStart('')).toBeNull()
    expect(normalizeProcStart(null)).toBeNull()
  })
})

describe('isSessionProcessAlive', () => {
  test('真實 session：UTC 的 ps 輸出與 procStart 相同，判為存活', () => {
    expect(isSessionProcessAlive(0, REAL_LSTART_UTC, REAL_PROC_START)).toBe(true)
  })

  test('反例：pid 存在但啟動時間與 procStart 不符（pid 被重複使用），不列為存活', () => {
    expect(isSessionProcessAlive(0, 'Mon Oct 19 11:30:00 2026\n', REAL_PROC_START)).toBe(false)
  })

  test('對照：同一行程的本機時區輸出與 procStart 差 8 小時，比對不符；看板因此以 TZ=UTC 執行 ps', () => {
    expect(isSessionProcessAlive(0, REAL_LSTART_LOCAL, REAL_PROC_START)).toBe(false)
  })

  test('ps exit 不為 0 時為已結束，與 procStart 無關', () => {
    expect(isSessionProcessAlive(1, '', REAL_PROC_START)).toBe(false)
    expect(isSessionProcessAlive(1, '', null)).toBe(false)
  })

  test('無從比對（procStart 缺少或格式不符、ps 無輸出）時退回只看 exit code', () => {
    expect(isSessionProcessAlive(0, REAL_LSTART_UTC, null)).toBe(true)
    expect(isSessionProcessAlive(0, REAL_LSTART_UTC, '2026-10-19T09:09:02Z')).toBe(true)
    expect(isSessionProcessAlive(0, '', REAL_PROC_START)).toBe(true)
  })
})

describe('formatAge', () => {
  test('秒、分、小時、天；未來時間為 0 秒；缺少時間為時間不明', () => {
    expect(formatAge(59_000, 0)).toBe('59 秒前')
    expect(formatAge(60_000, 0)).toBe('1 分前')
    expect(formatAge(3 * 3_600_000, 0)).toBe('3 小時前')
    expect(formatAge(2 * 86_400_000, 0)).toBe('2 天前')
    expect(formatAge(0, 5_000)).toBe('0 秒前')
    expect(formatAge(0, null)).toBe('時間不明')
  })
})

describe('parseLanes', () => {
  test('同一條線有多行時只取最後一行；歷史行與舊格式行的票號不進結果', () => {
    const lanes = parseLanes(TICKET_349)
    expect(lanes.map(lane => lane.lane)).toEqual([7, 9, 13])
    expect(laneTicketIds(lanes)).toEqual([
      '0.5.0-W1-351',
      '0.5.0-W1-145',
      '0.5.0-W1-356',
      '0.5.0-W1-353.1',
      '0.5.0-W1-341.2.1',
      '0.5.0-W1-284',
      '0.5.0-W1-337.1',
      '0.5.0-W1-337.3',
      '0.5.0-W1-337.2.1',
    ])
    const ids = laneTicketIds(lanes)
    for (const historical of ['328.1', '348', '341.1', '343', '257', '350', '328', '900']) {
      expect(ids.includes(`0.5.0-W1-${historical}`)).toBe(false)
    }
  })

  test('最後一行票序為（無）的線不顯示；session 名稱原樣保留，改派時取最後一行的名稱', () => {
    const lanes = parseLanes(TICKET_349)
    expect(lanes.some(lane => lane.lane === 11)).toBe(false)
    expect(lanes.map(lane => lane.session)).toEqual([
      'graph-project-docs-manager-f9',
      'graph-project-docs-manager-3e',
      'graph-project-docs-manager-1b',
    ])
  })

  test('反例：格式說明行（反引號引用範本）與行首範本（n 非數字）都不算一條線', () => {
    expect(parseLanes(`## Solution\n${TEMPLATE_NOTE}\n${TEMPLATE_AT_LINE_START}\n`)).toEqual([])
  })

  test('只比對行首：清單項的舊格式行不算一條線', () => {
    expect(parseLanes('## Solution\n- **L7 現行佇列**（s）：257\n  **L8 現行佇列**（s）：258\n')).toEqual([])
  })

  test('只掃 Solution：其他二級段落的現行佇列行不列入', () => {
    expect(parseLanes(TICKET_349).some(lane => lane.lane === 20 || lane.lane === 30)).toBe(false)
  })

  test('沒有任何現行佇列行（含沒有 Solution）時回傳空陣列', () => {
    expect(parseLanes('---\nstatus: pending\n---\n## Solution\n### 分派\n佇列：341.1\n')).toEqual([])
    expect(parseLanes('')).toEqual([])
  })

  test('行內沒寫 session 名稱時為 null；沒有目標行時 goal 為 null', () => {
    expect(parseLanes('## Solution\n**L5 現行佇列**：100\n')).toEqual([
      { lane: 5, session: null, goal: null, tokens: [{ kind: 'ticket', serial: '100', id: '0.5.0-W1-100', note: '' }] },
    ])
  })

  test('線目標：取該線最後一行目標行；沒有目標行的線為 null（E1 對照）', () => {
    const withGoals = parseLanes(TICKET_349_GOALS)
    const without = parseLanes(TICKET_349)
    expect(withGoals.map(lane => lane.goal)).not.toEqual(without.map(lane => lane.goal))
    expect(without.map(lane => lane.goal)).toEqual([null, null, null])
    expect(withGoals.find(lane => lane.lane === 13)?.goal).toBe('顯示各線目標與派發中代理人')
  })

  test('parseLaneGoals：不依賴現行佇列行，只回傳最後一行仍有目標的線', () => {
    expect([...parseLaneGoals(TICKET_349_GOALS)]).toEqual([[13, '顯示各線目標與派發中代理人']])
    expect([...parseLaneGoals('## Solution\n**L2 目標**：乙\n**L3 目標**：\n')]).toEqual([[2, '乙']])
  })

  test('線目標：最後一行寫（無）時清除較早的目標', () => {
    expect(parseLanes(TICKET_349_GOALS).find(lane => lane.lane === 7)?.goal).toBeNull()
    expect(parseLanes('## Solution\n**L5 現行佇列**：100\n**L5 目標**：甲\n').map(lane => lane.goal)).toEqual(['甲'])
    expect(parseLanes('## Solution\n**L5 現行佇列**：100\n**L5 目標**：甲\n**L5 目標**：（無）\n').map(lane => lane.goal)).toEqual([
      null,
    ])
  })

  test('線目標：寫（無）清除後再寫目標即恢復，取最後一行', () => {
    const text = '## Solution\n**L5 現行佇列**：100\n**L5 目標**：甲\n**L5 目標**：（無）\n**L5 目標**：乙\n'
    expect(parseLanes(text).map(lane => lane.goal)).toEqual(['乙'])
  })

  test('反例：清單項、表格內、反引號範本與 Solution 之外的目標行不被採用（E2）', () => {
    expect(parseLanes(TICKET_349_GOALS).find(lane => lane.lane === 9)?.goal).toBeNull()
    for (const line of [
      '- **L5 目標**：清單項',
      '| **L5 目標**：表格 | x |',
      '說明：`**L5 目標**：範本`',
      '`**L5 目標**：整行反引號`',
      '  **L5 目標**：縮排',
    ]) {
      expect(parseLanes(`## Solution\n**L5 現行佇列**：100\n${line}\n`).map(lane => lane.goal)).toEqual([null])
    }
    // 對照：同一段文字寫在行首即被採用，確認上列輸入是被判定排除，不是解析本身失效
    expect(parseLanes('## Solution\n**L5 現行佇列**：100\n**L5 目標**：行首\n').map(lane => lane.goal)).toEqual(['行首'])
  })
})

describe('parseQueue', () => {
  test('保留 → 與 ∥ 的順序結構，子序號可多層，票號後的註記另存', () => {
    expect(parseQueue('337.1（待用戶實機驗證）→ 353.1 ∥ 341.2.1')).toEqual([
      { kind: 'ticket', serial: '337.1', id: '0.5.0-W1-337.1', note: '（待用戶實機驗證）' },
      { kind: 'sep', text: '→' },
      { kind: 'ticket', serial: '353.1', id: '0.5.0-W1-353.1', note: '' },
      { kind: 'sep', text: '∥' },
      { kind: 'ticket', serial: '341.2.1', id: '0.5.0-W1-341.2.1', note: '' },
    ])
  })

  test('不以票號開頭的一步保留為文字', () => {
    expect(parseQueue('待定 → 100')).toEqual([
      { kind: 'text', text: '待定' },
      { kind: 'sep', text: '→' },
      { kind: 'ticket', serial: '100', id: '0.5.0-W1-100', note: '' },
    ])
  })
})

describe('formatQueue', () => {
  test('票號旁標狀態、註記接在狀態後、查不到狀態只顯示票號', () => {
    const tokens = parseQueue('337.1（待驗證）→ 353.1 ∥ 999')
    const text = formatQueue(tokens, [
      { id: '0.5.0-W1-337.1', status: 'in_progress' },
      { id: '0.5.0-W1-353.1', status: 'pending' },
    ])
    expect(text).toBe('337.1〔in_progress〕（待驗證） → 353.1〔pending〕 ∥ 999')
  })
})

describe('parseFrontmatterStatus', () => {
  test('讀 frontmatter 內的 status，不讀本文', () => {
    expect(parseFrontmatterStatus(ticketFile('in_progress'))).toBe('in_progress')
    expect(parseFrontmatterStatus("---\nstatus: 'completed'\n---\n")).toBe('completed')
  })

  test('沒有 frontmatter 或沒有 status 欄時回傳 null', () => {
    expect(parseFrontmatterStatus('status: pending\n')).toBeNull()
    expect(parseFrontmatterStatus('---\nid: x\n---\nstatus: pending\n')).toBeNull()
  })
})

describe('mergeGateLines', () => {
  test('只保留 [合併閘門] 的開始與結束行；預檢、驗收、測試行濾掉', () => {
    const lines = mergeGateLines(MERGE_LOG, 8)
    expect(lines.length).toBe(2)
    expect(lines[0]).toContain('[合併閘門] 開始')
    expect(lines[1]).toContain('[合併閘門] 結束')
    expect(lines.some(line => line.includes('預檢'))).toBe(false)
    expect(lines.some(line => line.includes('[合併前測試]'))).toBe(false)
    expect(lines.some(line => line.includes('[合併前驗收]'))).toBe(false)
  })

  test('篩選後取最後 n 行', () => {
    expect(mergeGateLines(MERGE_LOG, 1)).toEqual([
      '2026-10-19T16:11:45 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-328｜commit a9dc3b442c24｜結果 寫入',
    ])
  })
})

describe('parseMergeGateLine', () => {
  test('開始行取時間（HH:MM:SS）與分支；結束行另取結果', () => {
    expect(
      parseMergeGateLine('2026-10-19T16:04:26 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-328｜commit ee5e80e6b9a4'),
    ).toEqual({ kind: 'start', time: '16:04:26', branch: 'feat/0.5.0-W1-328' })
    expect(
      parseMergeGateLine(
        '2026-10-19T16:11:45 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-328｜commit a9dc3b442c24｜結果 寫入',
      ),
    ).toEqual({ kind: 'end', time: '16:11:45', branch: 'feat/0.5.0-W1-328', result: '寫入' })
  })

  test('反例：格式不符的行原樣保留為 raw，不丟棄、不拋錯', () => {
    for (const line of MALFORMED_GATE_LINES) {
      expect(parseMergeGateLine(line)).toEqual({ kind: 'raw', text: line })
    }
  })

  test('格式不符的行仍在 mergeGateEntries 結果中，順序不變', () => {
    const text = [MERGE_LOG, ...MALFORMED_GATE_LINES].join('\n')
    expect(mergeGateEntries(text).map(entry => entry.kind)).toEqual(['start', 'end', 'raw', 'raw', 'raw'])
  })
})

describe('shortBranch', () => {
  test('worktree-agent-<id> 縮成 agent-<前 6 碼>，feat/<票號> 縮成票號，其他分支原樣', () => {
    expect(shortBranch('worktree-agent-a352c31d77c3daa98')).toBe('agent-a352c3')
    expect(shortBranch('feat/0.5.0-W1-351')).toBe('0.5.0-W1-351')
    expect(shortBranch('worktree-e-batch-306')).toBe('worktree-e-batch-306')
  })
})

describe('formatMergeGateEntry', () => {
  test('開始行為 時間｜開始｜短分支，結束行另接結果；raw 為原文', () => {
    const [start, end] = mergeGateEntries(MERGE_LOG)
    expect(start === undefined ? '' : formatMergeGateEntry(start)).toBe('16:04:26｜開始｜0.5.0-W1-328')
    expect(end === undefined ? '' : formatMergeGateEntry(end)).toBe('16:11:45｜結束｜0.5.0-W1-328｜寫入')
    expect(formatMergeGateEntry({ kind: 'raw', text: 'x [合併閘門] 開始' })).toBe('x [合併閘門] 開始')
  })
})

describe('mergeGateResultColor', () => {
  test('寫入綠、中止黃、拒絕與紅燈紅，其他結果不上色', () => {
    expect(mergeGateResultColor('寫入')).toBe('green')
    expect(mergeGateResultColor('中止')).toBe('yellow')
    expect(mergeGateResultColor('拒絕')).toBe('red')
    expect(mergeGateResultColor('紅燈')).toBe('red')
    expect(mergeGateResultColor('其他')).toBeUndefined()
  })
})

/** MERGE_LOG_OVERLAP 中時間戳不晚於 time（`HH:MM:SS`）的行，模擬看板在該時刻讀到的紀錄。 */
function overlapLogUntil(time: string): string {
  return MERGE_LOG_OVERLAP.split('\n')
    .filter(line => line.slice(11, 19) <= time)
    .join('\n')
}

describe('mergeGateHolders', () => {
  test('重疊的合併：16:21 之後至 16:31:50 前 a352 仍列為持有者；預檢行不當成結束', () => {
    const a352 = { branch: 'worktree-agent-a352c31d77c3daa98', since: '16:19:45' }
    const a748 = { branch: 'worktree-agent-a74808594aa6f7e6f', since: '16:21:08' }
    // 16:19:46 的預檢行帶分支與結果欄，若被當成結束，a352 在此就會消失
    expect(mergeGateHolders(mergeGateEntries(overlapLogUntil('16:19:46')))).toEqual([a352])
    expect(mergeGateHolders(mergeGateEntries(overlapLogUntil('16:21:08')))).toEqual([a352, a748])
    expect(mergeGateHolders(mergeGateEntries(overlapLogUntil('16:21:11')))).toEqual([a352])
    expect(mergeGateHolders(mergeGateEntries(overlapLogUntil('16:31:49')))).toEqual([a352])
    expect(formatMergeGateHolders([a352, a748])).toEqual([
      '閘門使用中：agent-a352c3（自 16:19:45）',
      '閘門使用中：agent-a74808（自 16:21:08）',
    ])
  })

  test('對照：所有開始都有同分支的結束時回傳空陣列，不顯示任何持有者', () => {
    expect(mergeGateHolders(mergeGateEntries(MERGE_LOG_OVERLAP))).toEqual([])
    expect(mergeGateHolders(mergeGateEntries(MERGE_LOG))).toEqual([])
    expect(mergeGateHolders([])).toEqual([])
    expect(formatMergeGateHolders([])).toEqual([])
  })

  test('開始與結束交錯時，只列出尚未結束的分支', () => {
    const holders = mergeGateHolders(mergeGateEntries(MERGE_LOG_HOLDING))
    expect(holders).toEqual([{ branch: 'feat/0.5.0-W1-351', since: '16:41:49' }])
    expect(formatMergeGateHolders(holders)).toEqual(['閘門使用中：0.5.0-W1-351（自 16:41:49）'])
  })

  test('同分支先前已結束、重新開始後尚未結束時，仍視為持有', () => {
    const text = [MERGE_LOG, '2026-10-19T17:00:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-328｜commit 1'].join('\n')
    expect(mergeGateHolders(mergeGateEntries(text))).toEqual([{ branch: 'feat/0.5.0-W1-328', since: '17:00:00' }])
  })

  test('同分支連續兩筆開始而無結束時只列一次，取較晚的開始時間', () => {
    const text = [
      '2026-10-19T17:00:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-500｜commit 1',
      '2026-10-19T17:01:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-501｜commit 2',
      '2026-10-19T17:02:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-500｜commit 3',
    ].join('\n')
    expect(mergeGateHolders(mergeGateEntries(text))).toEqual([
      { branch: 'feat/0.5.0-W1-501', since: '17:01:00' },
      { branch: 'feat/0.5.0-W1-500', since: '17:02:00' },
    ])
  })

  test('其他分支的結束行不算對應結束', () => {
    const text = [
      '2026-10-19T17:00:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-500｜commit 1',
      '2026-10-19T17:00:05 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-499｜commit 2｜結果 寫入',
    ].join('\n')
    expect(mergeGateHolders(mergeGateEntries(text))).toEqual([{ branch: 'feat/0.5.0-W1-500', since: '17:00:00' }])
  })
})

/** 仿 `.claude/dispatch-active.json` 的一筆 dispatches：欄位名與真實檔相同（2026-10-20 對照），預設為未結束、無票號。 */
const dispatchJson = (fields: Record<string, unknown>) => ({
  agent_description: '描述',
  tool_use_id: 'toolu_x',
  agent_id: 'a000000000000000',
  ticket_id: '',
  files: [],
  branch_name: '',
  dispatched_at: '2026-10-19T07:57:00.000000+00:00',
  session_id: 'sid-x',
  name: 'general-purpose',
  agent_handle: '',
  work_checkout: '',
  turn_ended_at: null,
  ...fields,
})

const dispatch = (fields: Partial<DispatchRecord> = {}): DispatchRecord => ({
  agentId: 'a1',
  name: 'general-purpose',
  sessionId: 'sid-1',
  ticketId: null,
  description: '描述',
  dispatchedAt: null,
  turnEndedAt: null,
  ...fields,
})

describe('parseDispatchFile', () => {
  test('取 dispatches 各筆的代理人、session、票號、描述與時間；空字串票號為 null，tombstones 不讀', () => {
    const text = JSON.stringify({
      dispatches: [
        dispatchJson({ agent_id: 'a1', session_id: 's1', name: 'linux', agent_description: '審查 337.8' }),
        dispatchJson({
          agent_id: 'a2',
          session_id: 's2',
          ticket_id: '0.5.0-W1-337.9',
          turn_ended_at: '2026-10-19T07:58:00+00:00',
        }),
      ],
      tombstones: [{ agent_id: 'a3', created_at: '2026-10-19T07:00:00+00:00' }],
    })
    expect(parseDispatchFile(text)).toEqual([
      {
        agentId: 'a1',
        name: 'linux',
        sessionId: 's1',
        ticketId: null,
        description: '審查 337.8',
        dispatchedAt: '2026-10-19T07:57:00.000000+00:00',
        turnEndedAt: null,
      },
      {
        agentId: 'a2',
        name: 'general-purpose',
        sessionId: 's2',
        ticketId: '0.5.0-W1-337.9',
        description: '描述',
        dispatchedAt: '2026-10-19T07:57:00.000000+00:00',
        turnEndedAt: '2026-10-19T07:58:00+00:00',
      },
    ])
  })

  test('反例：JSON 無效、不是物件或 dispatches 不是陣列時回傳 null', () => {
    expect(parseDispatchFile('{"dispatches": [')).toBeNull()
    expect(parseDispatchFile('null')).toBeNull()
    expect(parseDispatchFile('{"dispatches": {}}')).toBeNull()
    expect(parseDispatchFile('{}')).toBeNull()
    // 對照：空陣列是合法的「沒有派發」，不是格式錯誤
    expect(parseDispatchFile('{"dispatches": []}')).toEqual([])
  })

  test('缺少 agent_id、session_id 或 name 的條目略過，其餘照常', () => {
    const text = JSON.stringify({
      dispatches: [
        dispatchJson({ agent_id: undefined }),
        dispatchJson({ session_id: 7 }),
        dispatchJson({ name: '' }),
        'not-an-object',
        dispatchJson({ agent_id: 'ok' }),
      ],
    })
    expect(parseDispatchFile(text)?.map(record => record.agentId)).toEqual(['ok'])
  })
})

describe('parseIsoMs', () => {
  test('帶微秒與時區位移的 ISO 時間取到毫秒；格式不符或 null 為 null', () => {
    expect(parseIsoMs('2026-10-19T07:57:00.123456+00:00')).toBe(Date.UTC(2026, 9, 19, 7, 57, 0, 123))
    expect(parseIsoMs('2026-10-19T15:57:00+08:00')).toBe(Date.UTC(2026, 9, 19, 7, 57, 0))
    expect(parseIsoMs('昨天')).toBeNull()
    expect(parseIsoMs(null)).toBeNull()
  })
})

describe('dispatchStage', () => {
  const ENDED = '2026-10-19T07:58:00+00:00'

  test('未結束的實作代理人為「實作」', () => {
    expect(dispatchStage(dispatch({ ticketId: '0.5.0-W1-337.9' }), 'in_progress', [])).toBe('實作')
    expect(dispatchStage(dispatch(), undefined, [])).toBe('實作')
  })

  test('未結束的審查類代理人為「審查」；對照：同一條目換成實作代理人即為「實作」', () => {
    for (const name of ['linux', 'basil-writing-critic', 'acceptance-auditor']) {
      expect(dispatchStage(dispatch({ name }), undefined, [])).toBe('審查')
    }
    expect(dispatchStage(dispatch({ name: 'general-purpose' }), undefined, [])).toBe('實作')
  })

  test('未結束的 incident-responder 為「事故分析」', () => {
    expect(dispatchStage(dispatch({ name: 'incident-responder' }), undefined, [])).toBe('事故分析')
  })

  test('分支 worktree-agent-<agent_id> 在閘門持有者中為「閘門」，已結束亦同；對照：不在持有者中時依原規則', () => {
    const running = dispatch({ agentId: 'a352c31d77c3daa98', ticketId: '0.5.0-W1-351' })
    const ended = { ...running, turnEndedAt: ENDED }
    const holders = ['worktree-agent-a352c31d77c3daa98']
    expect(dispatchStage(running, 'in_progress', holders)).toBe('閘門')
    expect(dispatchStage(ended, 'in_progress', holders)).toBe('閘門')
    expect(dispatchStage(running, 'in_progress', ['worktree-agent-other'])).toBe('實作')
    expect(dispatchStage(ended, 'in_progress', [])).toBe('收尾')
  })

  test('已結束且票未 completed 為「收尾」（票狀態讀不到亦同）；對照：票已 completed 時不列', () => {
    const ended = dispatch({ ticketId: '0.5.0-W1-345', turnEndedAt: ENDED })
    expect(dispatchStage(ended, 'pending', [])).toBe('收尾')
    expect(dispatchStage(ended, 'unknown', [])).toBe('收尾')
    expect(dispatchStage(ended, undefined, [])).toBe('收尾')
    expect(dispatchStage(ended, 'completed', [])).toBeNull()
  })

  test('票已 completed 時不列，代理人未結束亦同', () => {
    expect(dispatchStage(dispatch({ ticketId: '0.5.0-W1-337.1' }), 'completed', [])).toBeNull()
  })

  test('已結束且沒有票號的條目不列（沒有票可收尾）；對照：未結束時照常列出', () => {
    expect(dispatchStage(dispatch({ name: 'linux', turnEndedAt: ENDED }), undefined, [])).toBeNull()
    expect(dispatchStage(dispatch({ name: 'linux' }), undefined, [])).toBe('審查')
  })
})

describe('dispatchRows', () => {
  const sessions = [
    session({ name: 's-l13', status: 'busy', sessionId: 'sid-13' }),
    session({ name: 's-l7', status: 'idle', sessionId: 'sid-7' }),
    session({ name: 's-free', status: 'idle', sessionId: 'sid-free' }),
  ]
  const lanes = parseLanes('## Solution\n**L13 現行佇列**（s-l13）：337.9\n\n**L7 現行佇列**（s-l7）：351\n')
  const context = { sessions, lanes, tickets: [{ id: '0.5.0-W1-337.1', status: 'completed' }], holders: [] }

  test('session_id 對到存活 session，以其名稱對到線；對不到線的歸其他（null）；依線號排序、其他最後；票號顯示短票號', () => {
    const rows = dispatchRows(
      [
        dispatch({ agentId: 'a-free', sessionId: 'sid-free', description: '其他線的派發' }),
        dispatch({ agentId: 'a-13', sessionId: 'sid-13', ticketId: '0.5.0-W1-337.9' }),
        dispatch({ agentId: 'a-7', sessionId: 'sid-7', name: 'linux', description: '審查 351' }),
      ],
      context,
    )
    expect(rows.map(row => [row.lane, row.name, row.task, row.stage])).toEqual([
      [7, 'linux', '審查 351', '審查'],
      [13, 'general-purpose', '337.9', '實作'],
      [null, 'general-purpose', '其他線的派發', '實作'],
    ])
  })

  test('E2：session 不存活或票已 completed 的舊條目不列；對照：同一條目在 session 存活且票未完成時列出', () => {
    const deadSession = dispatch({ agentId: 'a-dead', sessionId: 'sid-gone' })
    const completed = dispatch({ agentId: 'a-done', sessionId: 'sid-13', ticketId: '0.5.0-W1-337.1' })
    expect(dispatchRows([deadSession, completed], context)).toEqual([])
    const alive = { ...deadSession, sessionId: 'sid-13' }
    const pending = { ...completed, ticketId: '0.5.0-W1-337.9' }
    expect(dispatchRows([alive, pending], context).map(row => row.stage)).toEqual(['實作', '實作'])
  })

  test('dispatchTicketIds：有票號的條目的完整票號，去重並保留順序', () => {
    expect(
      dispatchTicketIds([
        dispatch({ ticketId: '0.5.0-W1-351' }),
        dispatch(),
        dispatch({ ticketId: '0.5.0-W1-337.9' }),
        dispatch({ ticketId: '0.5.0-W1-351' }),
      ]),
    ).toEqual(['0.5.0-W1-351', '0.5.0-W1-337.9'])
  })
})

describe('formatDispatchRow', () => {
  test('`L<n> 代理人｜任務｜階段｜距派發時間`；對不到線為「其他」，缺派發時間為時間不明', () => {
    const nowMs = Date.UTC(2026, 9, 19, 8, 0, 0)
    const row = { lane: 13, name: 'general-purpose', task: '337.9', stage: '實作' as const, dispatchedAt: '2026-10-19T07:57:00.5+00:00' }
    expect(formatDispatchRow(row, nowMs)).toBe('L13 general-purpose｜337.9｜實作｜2 分前')
    expect(formatDispatchRow({ ...row, lane: null, dispatchedAt: null }, nowMs)).toBe('其他 general-purpose｜337.9｜實作｜時間不明')
  })
})

describe('Pane', () => {
  /** 家目錄與 session 狀態檔目錄（測試用的固定值）。 */
  const HOME = '/home/u'
  const SESSIONS = `${HOME}/${SESSIONS_DIR}`
  /** 讀取當下的時間：2026-10-19 08:00:00 UTC（epoch 毫秒）。 */
  const NOW_MS = Date.UTC(2026, 9, 19, 8, 0, 0)

  type Stub = {
    files: Record<string, string>
    /** `~/.claude/sessions/` 內的檔名；undefined 表示該目錄無法列出。 */
    sessionEntries?: string[]
    /** `ps -p` 回報已結束的 pid。 */
    deadPids?: number[]
    /** `ps -p <pid> -o lstart=` 對各 pid 的輸出；未列者輸出為空（看板退回只看 exit code）。 */
    lstart?: Record<number, string>
  }

  /**
   * 以 test 端 hook 代替 engine：看板 session 在 worktree `/wt` 內啟動（session root 為 `/wt`），
   * git 列出主 checkout `/repo` 與 `/wt`。$ 呼叫的 hook 回 `{ value }` 或 `{ deny }`（deny 即 reject，代表檔案不存在）。
   * 回傳 fs.read 被呼叫過的所有路徑，供斷言 `.key` 從未被讀取。
   */
  function stubRepo(on: On, stub: Stub): { readPaths: string[]; psCalls: { argv: readonly string[]; env: unknown }[] } {
    const readPaths: string[] = []
    const psCalls: { argv: readonly string[]; env: unknown }[] = []
    mock.env(on, { HOME })
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('session.root', () => ({ value: '/wt' }))
    on('process.run', (_$, e) => {
      const isPs = e.argv[0] === 'ps'
      const pid = Number(e.argv[2])
      if (isPs) psCalls.push({ argv: e.argv, env: e.init?.env })
      const isDead = isPs && (stub.deadPids ?? []).includes(pid)
      return {
        value: {
          exitCode: isDead ? 1 : 0,
          stdout: isPs ? (isDead ? '' : (stub.lstart?.[pid] ?? '')) : 'worktree /repo\nHEAD a\nbranch refs/heads/main\n\nworktree /wt\nHEAD b\nbranch refs/heads/feat\n',
          stderr: '',
          isStdoutTruncated: false,
          isStderrTruncated: false,
        },
      }
    })
    on('fs.list', (_$, e) => {
      if (e.path !== SESSIONS || stub.sessionEntries === undefined) return { deny: `ENOENT: ${e.path}` }
      return { value: stub.sessionEntries.map(name => ({ name, kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false })) }
    })
    on('fs.read', (_$, e) => {
      readPaths.push(e.path)
      const text = stub.files[e.path]
      return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
    })
    on('command.register', (_$, e) => ({ value: { command: e.name } }))
    on('ui.open', () => ({ value: { isPlaced: true } }))
    on('ui.log', () => ({ value: undefined }))
    return { readPaths, psCalls }
  }

  const PANE = {
    component: 'Pane',
    requestId: 'line-board',
    props: {
      title: '多線看板',
      isFocused: false,
      bodyColumns: 100,
      placement: 'dock',
      scroll: { offset: 0, bodyRows: 40 },
      view: {},
    },
  } as const

  /** bodyColumns：面板內容寬（欄），預設 100；停靠在側邊的窄面板以 60 測。 */
  async function startBoard($: Engine, on: On, stub: Stub, bodyColumns: number = PANE.props.bodyColumns) {
    const clock = mock.clock(on, { now: NOW_MS })
    const { readPaths, psCalls } = stubRepo(on, stub)
    await $.session.start({ cwd: '/wt', surface: 'terminal', isInteractive: true })
    await clock.advance(1)
    const ui = await $.ui.mount({
      plugin: 'line-board',
      surface: 'terminal',
      ...PANE,
      props: { ...PANE.props, bodyColumns },
    })
    return { ui, readPaths, psCalls, clock }
  }

  /**
   * 一組 session 狀態檔：本 repo 主 checkout 的 waiting／busy／idle／未知狀態、worktree 內的一個、
   * 其他專案的一個、pid 已結束的一個；每個 .json 旁都有 .key（內容故意放 JSON，讀到也能被解析，才分辨得出有沒有被讀）。
   */
  const SESSION_FILES: Record<string, Record<string, unknown>> = {
    '101': { pid: 101, name: 'graph-project-docs-manager-f9', cwd: '/repo', status: 'busy', statusUpdatedAt: NOW_MS - 90_000 },
    '102': {
      pid: 102,
      name: 'graph-project-docs-manager-1b',
      cwd: '/repo',
      status: 'waiting',
      waitingFor: 'input needed',
      statusUpdatedAt: NOW_MS - 12_000,
    },
    '103': { pid: 103, name: 'graph-project-docs-manager-d7', cwd: '/repo', status: 'idle', statusUpdatedAt: NOW_MS - 7_200_000 },
    '104': { pid: 104, name: 'graph-project-docs-manager-q1', cwd: '/wt/lib', status: 'compacting', statusUpdatedAt: NOW_MS },
    '105': { pid: 105, name: 'blog-ea', cwd: '/home/u/blog', status: 'waiting', statusUpdatedAt: NOW_MS },
    '106': { pid: 106, name: 'graph-project-docs-manager-3e', cwd: '/repo', status: 'busy', statusUpdatedAt: NOW_MS },
    '107': { pid: 107, name: 'graph-project-docs-manager-a2', cwd: '/repo', status: 'shell', statusUpdatedAt: NOW_MS - 30_000 },
  }

  /** SESSION_FILES 各狀態檔的 sessionId 為 `sid-<pid>`，派發紀錄的 session_id 以此對應。 */
  const sessionStub = (files: Record<string, string>): Stub => {
    const all = { ...files }
    const entries: string[] = []
    for (const [pid, fields] of Object.entries(SESSION_FILES)) {
      all[`${SESSIONS}/${pid}.json`] = sessionJson({ sessionId: `sid-${pid}`, ...fields })
      all[`${SESSIONS}/${pid}.deadbeef.key`] = sessionJson({ ...fields, name: `KEY-${pid}`, status: 'waiting' })
      entries.push(`${pid}.json`, `${pid}.deadbeef.key`)
    }
    return { files: all, sessionEntries: entries, deadPids: [106] }
  }

  test('各 session：只列本 repo（含 worktree）且 pid 存活者，waiting 最前，shell 與 busy 同組並顯示原值，未知狀態原樣；.key 從未被讀取', async ($, on) => {
    const { ui, readPaths } = await startBoard($, on, sessionStub({ [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 }))
    const rows = await ui.findAll({ type: 'Text', text: /^(graph-project-docs-manager|blog|KEY)-/ })
    expect(rows.map(row => row.text)).toEqual([
      'graph-project-docs-manager-1b｜waiting：input needed｜12 秒前',
      'graph-project-docs-manager-a2｜shell｜30 秒前',
      'graph-project-docs-manager-f9｜busy｜1 分前',
      'graph-project-docs-manager-d7｜idle｜2 小時前',
      'graph-project-docs-manager-q1｜compacting｜0 秒前',
    ])
    expect(await ui.find({ type: 'Text', text: /^另有 1 個狀態檔的 pid 已結束/ })).toBeDefined()
    expect(readPaths.some(path => path.endsWith('.key'))).toBe(false)
    expect(readPaths.filter(path => path.startsWith(SESSIONS)).length).toBe(7)
    await ui.unmount()
  })

  test('反例：pid 存在但 ps 的啟動時間與 procStart 不符時不列出、計入已結束；ps 以 TZ=UTC 執行', async ($, on) => {
    const reused = { pid: 201, name: 'graph-project-docs-manager-old', cwd: '/repo', status: 'busy', procStart: REAL_PROC_START }
    const same = { pid: 202, name: 'graph-project-docs-manager-live', cwd: '/repo', status: 'idle', procStart: REAL_PROC_START }
    const { ui, psCalls } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
        [`${SESSIONS}/201.json`]: sessionJson(reused),
        [`${SESSIONS}/202.json`]: sessionJson(same),
      },
      sessionEntries: ['201.json', '202.json'],
      lstart: { 201: 'Mon Oct 19 11:30:00 2026    \n', 202: REAL_LSTART_UTC },
    })
    const rows = await ui.findAll({ type: 'Text', text: /^graph-project-docs-manager-/ })
    expect(rows.map(row => row.text)).toEqual(['graph-project-docs-manager-live｜idle｜時間不明'])
    expect(await ui.find({ type: 'Text', text: /^另有 1 個狀態檔的 pid 已結束/ })).toBeDefined()
    const call = psCalls.find(item => item.argv[2] === '201')
    expect(call?.argv).toEqual(['ps', '-p', '201', '-o', 'lstart='])
    expect(call?.env).toEqual({ TZ: 'UTC', LC_ALL: 'C' })
    await ui.unmount()
  })

  test('線列 session 旁標狀態：存活者取其 status，pid 已結束或找不到的為離線', async ($, on) => {
    const { ui } = await startBoard($, on, sessionStub({ [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 }))
    expect(await ui.find({ type: 'Text', text: /^L7｜graph-project-docs-manager-f9［busy］｜351/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L13｜graph-project-docs-manager-1b［waiting：input needed］｜/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L9｜graph-project-docs-manager-3e［離線］｜/ })).toBeDefined()
    await ui.unmount()
  })

  test('線列顯示目標：有目標行的線在票序後接「｜目標：<文字>」，寫（無）或沒有可採用目標行的線不顯示', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349_GOALS } })
    expect(await ui.find({ type: 'Text', text: /^L13｜.*｜目標：顯示各線目標與派發中代理人$/ })).toBeDefined()
    const l7 = await ui.find({ type: 'Text', text: /^L7｜/ })
    const l9 = await ui.find({ type: 'Text', text: /^L9｜/ })
    expect(l7?.text).toBeDefined()
    expect(l9?.text).toBeDefined()
    expect(l7?.text).not.toContain('目標')
    expect(l9?.text).not.toContain('目標')
    for (const ignored of ['舊目標', '清單項的目標', '表格內的目標', '反引號範本的目標', '會被清除的目標', 'Solution 之外的目標']) {
      expect(await ui.find({ type: 'Text', text: new RegExp(ignored) })).toBeUndefined()
    }
    await ui.unmount()
  })

  test('對照：349 沒有任何目標行時，所有線列都不顯示目標', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 } })
    const rows = await ui.findAll({ type: 'Text', text: /^L\d+｜/ })
    expect(rows.length).toBe(3)
    for (const row of rows) expect(row.text).not.toContain('目標')
    await ui.unmount()
  })

  test('sessions 目錄無法列出時，各 session 區塊顯示讀取失敗，線列標狀態不明', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 } })
    expect(await ui.find({ type: 'Text', text: /^讀取 ~\/\.claude\/sessions 失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L7｜graph-project-docs-manager-f9［狀態不明］｜/ })).toBeDefined()
    await ui.unmount()
  })

  test('每條線一列（線號、session、票號與 main 的狀態），歷史票號不出現；閘門區只有開始與結束', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
        [`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('in_progress'),
        [`/wt/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('pending'),
        [`/repo/${TICKETS_DIR}/0.5.0-W1-337.1.md`]: ticketFile('completed'),
        [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG,
      },
    })
    const l7 = await ui.find({ type: 'Text', text: /^L7｜graph-project-docs-manager-f9［[^］]*］｜/ })
    expect(l7).toBeDefined()
    expect(JSON.stringify(l7)).toContain('351〔in_progress〕 → 145〔unknown〕')
    expect(
      await ui.find({
        type: 'Text',
        text: /^L13｜graph-project-docs-manager-1b［[^］]*］｜337\.1〔completed〕（待用戶實機驗證） → 337\.3/,
      }),
    ).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L9｜/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L11｜/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /328\.1|348〔/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^16:04:26｜開始｜0\.5\.0-W1-328$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^16:11:45｜結束｜0\.5\.0-W1-328｜寫入$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^閘門使用中/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /預檢/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /\[合併前測試\]/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^更新 \d{4}-\d{2}-\d{2} / })).toBeDefined()
    await ui.unmount()
  })

  test('面板寬 60 欄：閘門每行精簡為時間｜開始或結束｜短分支｜結果，整行放得下，持有者列在區塊最上方', async ($, on) => {
    const { ui } = await startBoard(
      $,
      on,
      { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349, [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG_HOLDING } },
      60,
    )
    const heading = await ui.find({ type: 'Text', text: /^合併閘門最近紀錄$/ })
    const holders = await ui.findAll({ type: 'Text', text: /^閘門使用中：/ })
    expect(holders.map(row => row.text)).toEqual(['閘門使用中：0.5.0-W1-351（自 16:41:49）'])
    const holder = holders[0]
    const rows = await ui.findAll({ type: 'Text', text: /^\d{2}:\d{2}:\d{2}｜(開始|結束)｜/ })
    expect(rows.map(row => row.text)).toEqual([
      '16:19:45｜開始｜agent-a352c3',
      '16:21:08｜開始｜agent-a74808',
      '16:21:11｜結束｜agent-a74808｜寫入',
      '16:31:50｜結束｜agent-a352c3｜寫入',
      '22:15:13｜結束｜worktree-doc-split-338-2-5｜中止',
      '16:41:49｜開始｜0.5.0-W1-351',
    ])
    for (const row of rows) expect(displayWidth(row.text)).toBeLessThanOrEqual(60)
    expect(rows.map(row => row.props.color)).toEqual([undefined, undefined, 'green', 'green', 'yellow', undefined])
    expect(await ui.find({ type: 'Text', text: /worktree-agent-/ })).toBeUndefined()
    // 持有者提示排在標題之後、第一行紀錄之前
    const drawn = JSON.stringify(await ui.drawn())
    const order = [heading?.text, holder?.text, rows[0]?.text].map(text => drawn.indexOf(text ?? '\u0000'))
    expect(order.every(index => index >= 0)).toBe(true)
    expect(order).toEqual([...order].sort((a, b) => a - b))
    await ui.unmount()
  })

  test('重疊的合併：兩個分支同時持有閘門時各列一行，依開始順序；預檢行不顯示', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
        [`/repo/${MERGE_LOG_PATH}`]: overlapLogUntil('16:21:09'),
      },
    })
    const holders = await ui.findAll({ type: 'Text', text: /^閘門使用中：/ })
    expect(holders.map(row => row.text)).toEqual([
      '閘門使用中：agent-a352c3（自 16:19:45）',
      '閘門使用中：agent-a74808（自 16:21:08）',
    ])
    expect(holders.map(row => row.props.color)).toEqual(['yellow', 'yellow'])
    expect(await ui.find({ type: 'Text', text: /預檢/ })).toBeUndefined()
    await ui.unmount()
  })

  test('反例：格式不符的閘門行原樣顯示，其他行照常精簡', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
        [`/repo/${MERGE_LOG_PATH}`]: [MERGE_LOG, ...MALFORMED_GATE_LINES].join('\n'),
      },
    })
    for (const line of MALFORMED_GATE_LINES) {
      expect((await ui.find({ type: 'Text', text: line }))?.text).toBe(line)
    }
    expect(await ui.find({ type: 'Text', text: /^16:11:45｜結束｜0\.5\.0-W1-328｜寫入$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: `讀取 ${MERGE_LOG_PATH} 失敗` })).toBeUndefined()
    await ui.unmount()
  })

  test('349 讀得到但沒有任何現行佇列行時顯示「349 尚無現行佇列行」', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: `---\nstatus: pending\n---\n## Solution\n${TEMPLATE_NOTE}\n`,
        [`/repo/${MERGE_LOG_PATH}`]: '',
      },
      sessionEntries: [],
    })
    expect(await ui.find({ type: 'Text', text: /^349 尚無現行佇列行$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^（本 repo 沒有執行中的 session）$/ })).toBeDefined()
    await ui.unmount()
  })

  test('對照：349 票檔讀不到時顯示「解析失敗」而非「尚無現行佇列行」', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/wt/${DISPATCH_TICKET_PATH}`]: TICKET_349 } })
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /尚無現行佇列行/ })).toBeUndefined()
    await ui.unmount()
  })

  /**
   * 派發紀錄：各階段一筆（session 依 sessionStub：sid-101 為 L7 的 f9、sid-102 為 L13 的 1b、sid-103 為不在任何線的 d7），
   * 加上不應列出的舊條目——票已 completed、session 的 pid 已結束（sid-106）、session 狀態檔不存在、已結束且無票號。
   * a352c31d77c3daa98 的分支在閘門紀錄中仍持有閘門。
   */
  const DISPATCH_ACTIVE = JSON.stringify({
    dispatches: [
      dispatchJson({ agent_id: 'aimpl', session_id: 'sid-102', ticket_id: '0.5.0-W1-337.9' }),
      dispatchJson({ agent_id: 'areview', session_id: 'sid-101', name: 'linux', agent_description: 'Readonly review of 337.8' }),
      dispatchJson({ agent_id: 'aincident', session_id: 'sid-101', name: 'incident-responder', agent_description: '分析 354.1 閘門紅燈' }),
      dispatchJson({
        agent_id: 'a352c31d77c3daa98',
        session_id: 'sid-102',
        ticket_id: '0.5.0-W1-351',
        turn_ended_at: '2026-10-19T07:58:00.000000+00:00',
      }),
      dispatchJson({ agent_id: 'awrapup', session_id: 'sid-103', ticket_id: '0.5.0-W1-345', turn_ended_at: '2026-10-19T07:59:00+00:00' }),
      dispatchJson({ agent_id: 'adone', session_id: 'sid-102', ticket_id: '0.5.0-W1-337.1', turn_ended_at: '2026-10-19T07:58:00+00:00' }),
      dispatchJson({ agent_id: 'adone2', session_id: 'sid-101', ticket_id: '0.5.0-W1-337.1' }),
      dispatchJson({ agent_id: 'adead', session_id: 'sid-106', agent_description: 'STALE 已結束 pid 的派發' }),
      dispatchJson({ agent_id: 'agone', session_id: 'sid-gone', name: 'linux', agent_description: 'STALE 不存在的 session' }),
      dispatchJson({
        agent_id: 'aold',
        session_id: 'sid-101',
        name: 'linux',
        agent_description: 'STALE 已結束的審查',
        turn_ended_at: '2026-10-19T07:58:00+00:00',
      }),
    ],
    tombstones: [{ agent_id: 'atomb', created_at: '2026-10-19T07:00:00+00:00' }],
  })

  /** 派發區塊的列：`L<n> ` 或 `其他 ` 開頭（線列為 `L<n>｜`，以此區分）。 */
  const DISPATCH_ROW = /^(L\d+|其他) /

  const dispatchFiles = (dispatchText: string) =>
    sessionStub({
      [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
      [`/repo/${DISPATCH_ACTIVE_PATH}`]: dispatchText,
      [`/wt/${DISPATCH_ACTIVE_PATH}`]: JSON.stringify({ dispatches: [dispatchJson({ session_id: 'sid-102', agent_description: 'WORKTREE 副本' })] }),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-337.9.md`]: ticketFile('in_progress'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('in_progress'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-345.md`]: ticketFile('pending'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-337.1.md`]: ticketFile('completed'),
      [`/repo/${MERGE_LOG_PATH}`]: overlapLogUntil('16:19:46'),
    })

  test('派發中代理人：依線分組，各列為代理人｜票號或描述｜流程階段｜距派發時間；只讀主 checkout 的派發紀錄', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(DISPATCH_ACTIVE))
    expect(await ui.find({ type: 'Text', text: /^派發中代理人$/ })).toBeDefined()
    const rows = await ui.findAll({ type: 'Text', text: DISPATCH_ROW })
    expect(rows.map(row => row.text)).toEqual([
      'L7 linux｜Readonly review of 337.8｜審查｜3 分前',
      'L7 incident-responder｜分析 354.1 閘門紅燈｜事故分析｜3 分前',
      'L13 general-purpose｜337.9｜實作｜3 分前',
      'L13 general-purpose｜351｜閘門｜3 分前',
      '其他 general-purpose｜345｜收尾｜3 分前',
    ])
    expect(await ui.find({ type: 'Text', text: /讀取 \.claude\/dispatch-active\.json 失敗/ })).toBeUndefined()
    await ui.unmount()
  })

  test('E2：票已 completed、session 不存活（pid 已結束或狀態檔不存在）、已結束且無票號的舊條目不列出', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(DISPATCH_ACTIVE))
    const rows = (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => row.text)
    expect(rows.length).toBe(5)
    expect(rows.some(text => text.includes('337.1'))).toBe(false)
    expect(rows.some(text => text.includes('STALE'))).toBe(false)
    expect(rows.some(text => text.includes('WORKTREE'))).toBe(false)
    await ui.unmount()
  })

  test('沒有任何應列出的派發時顯示「（目前沒有派發中的代理人）」', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(JSON.stringify({ dispatches: [] })))
    expect(await ui.find({ type: 'Text', text: /^（目前沒有派發中的代理人）$/ })).toBeDefined()
    expect(await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).toEqual([])
    await ui.unmount()
  })

  /** 派發區塊失敗時，其餘區塊（線列、各 session、閘門紀錄）照常顯示。 */
  async function expectOtherBlocksIntact(ui: Awaited<ReturnType<typeof startBoard>>['ui']) {
    expect(await ui.find({ type: 'Text', text: /^L7｜graph-project-docs-manager-f9［busy］｜351〔in_progress〕/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^graph-project-docs-manager-1b｜waiting：input needed｜/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^閘門使用中：agent-a352c3（自 16:19:45）$/ })).toBeDefined()
    expect(await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).toEqual([])
  }

  test('派發紀錄檔讀不到時，派發區塊顯示讀取失敗，其餘區塊照常', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    delete stub.files[`/repo/${DISPATCH_ACTIVE_PATH}`]
    const { ui } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await expectOtherBlocksIntact(ui)
    await ui.unmount()
  })

  test('派發紀錄格式錯誤（JSON 無效）時，派發區塊顯示讀取失敗，其餘區塊照常', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles('{"dispatches": ['))
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await expectOtherBlocksIntact(ui)
    await ui.unmount()
  })

  test('派發紀錄格式錯誤（dispatches 不是陣列）時，派發區塊顯示讀取失敗', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles('{"dispatches": {}}'))
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await ui.unmount()
  })

  /** 下一輪定時讀取：時鐘前進一個更新間隔（30 秒），看板依 stub 的現況重讀。 */
  const REFRESH_MS = 30_000

  /** 派發列去掉末尾的時間欄（重讀後時間會前進），只比對線、代理人、任務與階段。 */
  const withoutAge = (text: string) => text.replace(/｜[^｜]*$/, '')

  test('349 讀不到時，派發條目照常列出並全歸「其他」；對照：同一份 fixture 讀得到 349 後歸到對應的線', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    const ticket349 = stub.files[`/repo/${DISPATCH_TICKET_PATH}`] ?? ''
    delete stub.files[`/repo/${DISPATCH_TICKET_PATH}`]
    const { ui, clock } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    const missing = (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => withoutAge(row.text))
    expect(missing).toEqual([
      '其他 general-purpose｜337.9｜實作',
      '其他 linux｜Readonly review of 337.8｜審查',
      '其他 incident-responder｜分析 354.1 閘門紅燈｜事故分析',
      '其他 general-purpose｜351｜閘門',
      '其他 general-purpose｜345｜收尾',
    ])
    // 正向對照：補回 349 後重讀，同一批條目歸到 session 所在的線
    stub.files[`/repo/${DISPATCH_TICKET_PATH}`] = ticket349
    await clock.advance(REFRESH_MS)
    const present = (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => withoutAge(row.text))
    expect(present).toEqual([
      'L7 linux｜Readonly review of 337.8｜審查',
      'L7 incident-responder｜分析 354.1 閘門紅燈｜事故分析',
      'L13 general-purpose｜337.9｜實作',
      'L13 general-purpose｜351｜閘門',
      '其他 general-purpose｜345｜收尾',
    ])
    await ui.unmount()
  })

  test('閘門紀錄讀不到時，派發條目照常列出且沒有任何一列為「閘門」；對照：同一份 fixture 讀得到閘門紀錄後標為閘門', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    const mergeLog = stub.files[`/repo/${MERGE_LOG_PATH}`] ?? ''
    delete stub.files[`/repo/${MERGE_LOG_PATH}`]
    const { ui, clock } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/logs\/worktree-merge\.log 失敗/ })).toBeDefined()
    const missing = (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => withoutAge(row.text))
    expect(missing.length).toBe(5)
    expect(missing.some(text => text.endsWith('｜閘門'))).toBe(false)
    // 持有閘門的 a352 已結束且票未完成，閘門紀錄讀不到時落回「收尾」
    expect(missing).toContain('L13 general-purpose｜351｜收尾')
    // 正向對照：補回閘門紀錄後重讀，同一條目標為閘門
    stub.files[`/repo/${MERGE_LOG_PATH}`] = mergeLog
    await clock.advance(REFRESH_MS)
    const present = (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => withoutAge(row.text))
    expect(present).toContain('L13 general-purpose｜351｜閘門')
    expect(present.filter(text => text.endsWith('｜閘門')).length).toBe(1)
    await ui.unmount()
  })

  test('sessions 目錄無法列出時，派發區塊不列條目，標明無法判定', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349, [`/repo/${DISPATCH_ACTIVE_PATH}`]: DISPATCH_ACTIVE },
    })
    expect(await ui.find({ type: 'Text', text: /^（session 狀態讀取失敗，無法判定派發中的代理人）$/ })).toBeDefined()
    expect(await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).toEqual([])
    await ui.unmount()
  })
})
