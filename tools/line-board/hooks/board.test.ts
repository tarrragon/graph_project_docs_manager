// line-board 的測試：parse.ts 純函式（主 checkout 判定、現行佇列行解析、佇列格式化、閘門紀錄篩選）與 Pane 的端到端繪製。

import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import {
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  TICKETS_DIR,
  formatQueue,
  laneTicketIds,
  mergeGateLines,
  parseFrontmatterStatus,
  parseLanes,
  parseMainCheckout,
  parseQueue,
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

const ticketFile = (status: string) => `---\nid: x\nstatus: ${status}\nwho: y\n---\n# body\nstatus: ignored\n`

describe('parseMainCheckout', () => {
  test('取 git worktree list 的第一筆為主 checkout', () => {
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
    expect(parseMainCheckout(porcelain)).toBe('/repo')
  })

  test('空輸出回傳 null', () => {
    expect(parseMainCheckout('')).toBeNull()
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

describe('Pane', () => {
  /**
   * 以 test 端 hook 代替 engine：看板 session 在 worktree `/wt` 內啟動（session root 為 `/wt`），
   * git 列出主 checkout `/repo` 與 `/wt`。$ 呼叫的 hook 回 `{ value }` 或 `{ deny }`（deny 即 reject，代表檔案不存在）。
   */
  function stubRepo(on: On, files: Record<string, string>) {
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('session.root', () => ({ value: '/wt' }))
    on('process.run', () => ({
      value: {
        exitCode: 0,
        stdout: 'worktree /repo\nHEAD a\nbranch refs/heads/main\n\nworktree /wt\nHEAD b\nbranch refs/heads/feat\n',
        stderr: '',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }))
    on('fs.read', (_$, e) => {
      const text = files[e.path]
      return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
    })
    on('command.register', (_$, e) => ({ value: { command: e.name } }))
    on('ui.open', () => ({ value: { isPlaced: true } }))
    on('ui.log', () => ({ value: undefined }))
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

  async function startBoard($: Engine, on: On, files: Record<string, string>) {
    const clock = mock.clock(on)
    stubRepo(on, files)
    await $.session.start({ cwd: '/wt', surface: 'terminal', isInteractive: true })
    await clock.advance(1)
    return $.ui.mount({ plugin: 'line-board', surface: 'terminal', ...PANE })
  }

  test('每條線一列（線號、session、票號與 main 的狀態），歷史票號不出現；閘門區只有開始與結束', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
      [`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('in_progress'),
      [`/wt/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('pending'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-337.1.md`]: ticketFile('completed'),
      [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG,
    })
    const l7 = await ui.find({ type: 'Text', text: /^L7｜graph-project-docs-manager-f9｜/ })
    expect(l7).toBeDefined()
    expect(JSON.stringify(l7)).toContain('351〔in_progress〕 → 145〔unknown〕')
    expect(
      await ui.find({ type: 'Text', text: /^L13｜graph-project-docs-manager-1b｜337\.1〔completed〕（待用戶實機驗證） → 337\.3/ }),
    ).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L9｜/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^L11｜/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /328\.1|348〔/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /\[合併閘門\] 開始/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /\[合併閘門\] 結束/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /預檢/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /\[合併前測試\]/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^更新 \d{4}-\d{2}-\d{2} / })).toBeDefined()
    await ui.unmount()
  })

  test('349 讀得到但沒有任何現行佇列行時顯示「349 尚無現行佇列行」', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: `---\nstatus: pending\n---\n## Solution\n${TEMPLATE_NOTE}\n`,
      [`/repo/${MERGE_LOG_PATH}`]: '',
    })
    expect(await ui.find({ type: 'Text', text: /^349 尚無現行佇列行$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeUndefined()
    await ui.unmount()
  })

  test('對照：349 票檔讀不到時顯示「解析失敗」而非「尚無現行佇列行」', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/wt/${DISPATCH_TICKET_PATH}`]: TICKET_349,
    })
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /尚無現行佇列行/ })).toBeUndefined()
    await ui.unmount()
  })
})
