// line-board 的測試：status.ts 純函式（段落擷取、票號抽取、狀態合併）與 Pane 的端到端繪製。

import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'

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

/** 仿 349 票檔結構：〈分派〉之後有同層的〈協調規則〉與調整段，最後接 `## Test Results`。 */
const TICKET_349 = [
  '---',
  'id: 0.5.0-W1-349',
  'status: in_progress',
  '---',
  '## Solution',
  '### 0.5.0 任務線盤點（2026-10-19）',
  '- 盤點內容，不屬於分派 301',
  '### 分派（用戶裁定 2026-10-19，AskUserQuestion 選「L9 + L7」）',
  '',
  '**`session-3e`：L9 提交／寫入守衛**',
  '',
  '佇列：341.1 → 343 → 284 收尾',
  '',
  '- 343 宣告整個 `.claude/hooks/`（commit c4cb324f7，日期 2026-10-19）',
  '- 328 原列於 L8 佇列，改歸 L7',
  '### 協調規則',
  '- 需用戶裁決的事（240 推非 main 分支）回報主控 session',
  '### L7 佇列調整（2026-10-19，主控查證 257／350 皆 in_progress）',
  '- **L7 現行佇列**：257 ∥ 350 → 341.1（338.3 等 257 落地後 complete）',
  '## Test Results',
  '- 不屬於段落 999',
].join('\n')

const ticketFile = (status: string) => `---\nid: x\nstatus: ${status}\nwho: y\n---\n# body\nstatus: ignored\n`

describe('extractDispatchSection', () => {
  test('從〈分派〉標題擷取到下一個二級標題，含其後的三級段落', () => {
    const result = extractDispatchSection(TICKET_349)
    expect(result.kind).toBe('ok')
    if (result.kind !== 'ok') return
    expect(result.markdown.startsWith('### 分派（用戶裁定')).toBe(true)
    expect(result.markdown).toContain('### 協調規則')
    expect(result.markdown).toContain('L7 現行佇列')
    expect(result.markdown.includes('不屬於段落 999')).toBe(false)
    expect(result.markdown.includes('盤點內容')).toBe(false)
  })

  test('段落標題不存在時回傳 missing（與讀檔失敗的 error 可分辨）', () => {
    const result = extractDispatchSection('---\nstatus: pending\n---\n## Solution\n### 其他段落\n佇列：341.1\n')
    expect(result).toEqual({ kind: 'missing', heading: '### 分派' })
  })

  test('空字串也回傳 missing', () => {
    expect(extractDispatchSection('').kind).toBe('missing')
  })

  test('〈分派〉之後沒有二級標題時擷取到檔尾', () => {
    const result = extractDispatchSection('### 分派\n佇列：100')
    expect(result).toEqual({ kind: 'ok', markdown: '### 分派\n佇列：100' })
  })
})

describe('extractQueueIds', () => {
  test('只從佇列行抽票號，保留順序、去重，含子序號', () => {
    const section = extractDispatchSection(TICKET_349)
    if (section.kind !== 'ok') throw new Error('fixture 應可擷取')
    expect(extractQueueIds(section.markdown)).toEqual([
      '0.5.0-W1-341.1',
      '0.5.0-W1-343',
      '0.5.0-W1-284',
      '0.5.0-W1-257',
      '0.5.0-W1-350',
      '0.5.0-W1-338.3',
    ])
  })

  test('非佇列行的數字（日期、commit hash、說明中的票號）不列入', () => {
    const ids = extractQueueIds('- 343 宣告 commit c4cb324f7 2026-10-19\n- 328 原列於 L8 佇列，改歸 L7')
    expect(ids).toEqual([])
  })
})

describe('annotateQueue', () => {
  test('佇列行票號旁標狀態，worktree 來源加 ·wt，非佇列行不變', () => {
    const markdown = '佇列：341.1 → 343\n- 343 說明'
    const annotated = annotateQueue(markdown, [
      { id: '0.5.0-W1-341.1', status: 'in_progress', source: '/wt/a' },
      { id: '0.5.0-W1-343', status: 'pending', source: 'main' },
    ])
    expect(annotated).toBe('佇列：341.1〔in_progress·wt〕 → 343〔pending〕\n- 343 說明')
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

describe('parseWorktreeList', () => {
  test('第一筆為 main，排除 prunable 與 bare', () => {
    const porcelain = [
      'worktree /repo',
      'HEAD aaa',
      'branch refs/heads/main',
      '',
      'worktree /repo-257',
      'HEAD bbb',
      'branch refs/heads/feat/257',
      '',
      'worktree /repo-gone',
      'HEAD ccc',
      'prunable gitdir file points to non-existent location',
      '',
      'worktree /repo/.claude/worktrees/agent-x',
      'HEAD ddd',
      'branch refs/heads/worktree-agent-x',
      'locked claude agent agent-x',
      '',
    ].join('\n')
    expect(parseWorktreeList(porcelain)).toEqual({
      main: '/repo',
      worktrees: ['/repo-257', '/repo/.claude/worktrees/agent-x'],
    })
  })

  test('空輸出時 main 為 null', () => {
    expect(parseWorktreeList('')).toEqual({ main: null, worktrees: [] })
  })
})

describe('tailLines', () => {
  test('取最後 n 個非空行', () => {
    expect(tailLines('a\nb\n\nc\nd\n', 2)).toEqual(['c', 'd'])
  })
})

describe('pickStatus', () => {
  test('main 為 completed／closed 時以 main 為準，忽略 worktree', () => {
    expect(pickStatus('completed', [{ path: '/wt', status: 'in_progress' }])).toEqual({
      status: 'completed',
      source: 'main',
    })
    expect(pickStatus('closed', [{ path: '/wt', status: 'pending' }])).toEqual({ status: 'closed', source: 'main' })
  })

  test('worktree 狀態與 main 不同時以 worktree 為準，source 為其路徑', () => {
    expect(pickStatus('pending', [{ path: '/wt', status: 'in_progress' }])).toEqual({
      status: 'in_progress',
      source: '/wt',
    })
  })

  test('對照：worktree 與 main 相同或讀不到時以 main 為準', () => {
    expect(
      pickStatus('in_progress', [
        { path: '/wt-a', status: 'in_progress' },
        { path: '/wt-b', status: null },
      ]),
    ).toEqual({ status: 'in_progress', source: 'main' })
  })

  test('多個 worktree 皆不同時取推進程度最高者', () => {
    expect(
      pickStatus('pending', [
        { path: '/wt-a', status: 'blocked' },
        { path: '/wt-b', status: 'completed' },
        { path: '/wt-c', status: 'in_progress' },
      ]),
    ).toEqual({ status: 'completed', source: '/wt-b' })
  })

  test('main 讀不到票檔時取 worktree；全部讀不到為 unknown', () => {
    expect(pickStatus(null, [{ path: '/wt', status: 'pending' }])).toEqual({ status: 'pending', source: '/wt' })
    expect(pickStatus(null, [{ path: '/wt', status: null }])).toEqual({ status: 'unknown', source: 'none' })
  })
})

describe('Pane', () => {
  /**
   * 以 test 端 hook 代替 engine 回答 session.root、git、檔案讀取，模擬 main 與一個 worktree。
   * $ 呼叫的 hook 回 `{ value }` 或 `{ deny }`（deny 即該呼叫 reject，代表檔案不存在）。
   */
  function stubRepo(on: On, files: Record<string, string>) {
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('session.root', () => ({ value: '/repo' }))
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

  test('畫出標好狀態的佇列、worktree 來源與合併閘門紀錄', async ($, on) => {
    const clock = mock.clock(on)
    stubRepo(on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
      [`/repo/${TICKETS_DIR}/0.5.0-W1-341.1.md`]: ticketFile('pending'),
      [`/wt/${TICKETS_DIR}/0.5.0-W1-341.1.md`]: ticketFile('in_progress'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-343.md`]: ticketFile('completed'),
      [`/wt/${TICKETS_DIR}/0.5.0-W1-343.md`]: ticketFile('pending'),
      [`/repo/${MERGE_LOG_PATH}`]: 'old line\n2026-10-19T15:16:33 [合併閘門] 開始\n',
    })
    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    await clock.advance(1)

    const ui = await $.ui.mount({ plugin: 'line-board', surface: 'terminal', ...PANE })
    const markdown = await ui.find({ type: 'Markdown' })
    expect(markdown).toBeDefined()
    expect(JSON.stringify(markdown)).toContain('341.1〔in_progress·wt〕')
    expect(JSON.stringify(markdown)).toContain('343〔completed〕')
    expect(await ui.find({ type: 'Text', text: /0\.5\.0-W1-341\.1 in_progress ← \/wt/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /\[合併閘門\] 開始/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^更新 \d{4}-\d{2}-\d{2} / })).toBeDefined()
    await ui.unmount()
  })

  test('段落標題不存在時顯示「沒有資料」，讀檔失敗時顯示「解析失敗」', async ($, on) => {
    const clock = mock.clock(on)
    stubRepo(on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: '---\nstatus: pending\n---\n## Solution\n',
      [`/repo/${MERGE_LOG_PATH}`]: '',
    })
    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    await clock.advance(1)

    const ui = await $.ui.mount({ plugin: 'line-board', surface: 'terminal', ...PANE })
    expect(await ui.find({ type: 'Text', text: /^沒有資料：/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeUndefined()
    await ui.unmount()
  })

  test('對照：349 票檔讀不到時顯示「解析失敗」而非「沒有資料」', async ($, on) => {
    const clock = mock.clock(on)
    stubRepo(on, {})
    await $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })
    await clock.advance(1)

    const ui = await $.ui.mount({ plugin: 'line-board', surface: 'terminal', ...PANE })
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^沒有資料：/ })).toBeUndefined()
    await ui.unmount()
  })
})
