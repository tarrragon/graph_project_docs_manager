// line-board 的測試：parse.ts 純函式（checkout 判定、現行佇列行解析、佇列格式化、session 狀態檔、閘門紀錄篩選）
// 與 Pane 的端到端繪製。

import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import type { SessionState } from '../types'
import {
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  SESSIONS_DIR,
  TICKETS_DIR,
  formatAge,
  formatMergeGateEntry,
  formatMergeGateHolder,
  formatQueue,
  isInRepo,
  isSessionProcessAlive,
  laneSessionStatus,
  laneTicketIds,
  mergeGateEntries,
  mergeGateHolder,
  mergeGateLines,
  mergeGateResultColor,
  normalizeProcStart,
  parseFrontmatterStatus,
  parseMergeGateLine,
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
  test('取 pid、name、cwd、status、waitingFor、statusUpdatedAt，其他欄位不保存', () => {
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
    })
  })

  test('沒有 waitingFor、statusUpdatedAt 或 procStart 時為 null；未知 status 原樣保存', () => {
    expect(parseSessionFile(sessionJson({ pid: 7, name: 's', cwd: '/r', status: 'compacting' }))).toEqual({
      pid: 7,
      name: 's',
      cwd: '/r',
      status: 'compacting',
      waitingFor: null,
      statusUpdatedAt: null,
      procStart: null,
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

  test('行內沒寫 session 名稱時為 null', () => {
    expect(parseLanes('## Solution\n**L5 現行佇列**：100\n')).toEqual([
      { lane: 5, session: null, tokens: [{ kind: 'ticket', serial: '100', id: '0.5.0-W1-100', note: '' }] },
    ])
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

describe('mergeGateHolder', () => {
  test('最後一筆開始沒有對應結束時，回傳該分支與開始時間；開始與結束交錯不影響判定', () => {
    const holder = mergeGateHolder(mergeGateEntries(MERGE_LOG_HOLDING))
    expect(holder).toEqual({ branch: 'feat/0.5.0-W1-351', since: '16:41:49' })
    expect(holder === null ? '' : formatMergeGateHolder(holder)).toBe('閘門使用中：0.5.0-W1-351（自 16:41:49）')
  })

  test('對照：最後一筆開始已有同分支的結束時回傳 null', () => {
    expect(mergeGateHolder(mergeGateEntries(MERGE_LOG))).toBeNull()
  })

  test('同分支先前已結束、重新開始後尚未結束時，仍視為持有', () => {
    const text = [MERGE_LOG, '2026-10-19T17:00:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-328｜commit 1'].join('\n')
    expect(mergeGateHolder(mergeGateEntries(text))).toEqual({ branch: 'feat/0.5.0-W1-328', since: '17:00:00' })
  })

  test('其他分支的結束行不算對應結束；沒有任何開始行時回傳 null', () => {
    const text = [
      '2026-10-19T17:00:00 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-500｜commit 1',
      '2026-10-19T17:00:05 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-499｜commit 2｜結果 寫入',
    ].join('\n')
    expect(mergeGateHolder(mergeGateEntries(text))).toEqual({ branch: 'feat/0.5.0-W1-500', since: '17:00:00' })
    expect(mergeGateHolder([])).toBeNull()
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
    return { ui, readPaths, psCalls }
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

  const sessionStub = (files: Record<string, string>): Stub => {
    const all = { ...files }
    const entries: string[] = []
    for (const [pid, fields] of Object.entries(SESSION_FILES)) {
      all[`${SESSIONS}/${pid}.json`] = sessionJson(fields)
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
    const holder = await ui.find({ type: 'Text', text: /^閘門使用中：/ })
    expect(holder?.text).toBe('閘門使用中：0.5.0-W1-351（自 16:41:49）')
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
})
