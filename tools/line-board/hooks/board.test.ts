// line-board 的測試：parse.ts 純函式（主 checkout 判定、段落擷取、票號抽取與標示）與 Pane 的端到端繪製。

import type { On } from 'claude-code'
import { describe, expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import {
  DISPATCH_TICKET_PATH,
  MERGE_LOG_PATH,
  TICKETS_DIR,
  annotateQueue,
  extractDispatchSection,
  extractQueueIds,
  parseFrontmatterStatus,
  parseMainCheckout,
  tailLines,
} from './parse'

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
  test('佇列行票號旁標狀態，非佇列行不變，未知票號原樣保留', () => {
    const markdown = '佇列：341.1 → 343 → 999\n- 343 說明'
    const annotated = annotateQueue(markdown, [
      { id: '0.5.0-W1-341.1', status: 'in_progress' },
      { id: '0.5.0-W1-343', status: 'pending' },
    ])
    expect(annotated).toBe('佇列：341.1〔in_progress〕 → 343〔pending〕 → 999\n- 343 說明')
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

describe('tailLines', () => {
  test('取最後 n 個非空行', () => {
    expect(tailLines('a\nb\n\nc\nd\n', 2)).toEqual(['c', 'd'])
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

  test('worktree 票檔與 main 不同時，仍顯示 main 的值；並畫出合併閘門紀錄與更新時間', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
      [`/repo/${TICKETS_DIR}/0.5.0-W1-341.1.md`]: ticketFile('in_progress'),
      [`/wt/${TICKETS_DIR}/0.5.0-W1-341.1.md`]: ticketFile('pending'),
      [`/repo/${TICKETS_DIR}/0.5.0-W1-343.md`]: ticketFile('completed'),
      [`/wt/${TICKETS_DIR}/0.5.0-W1-343.md`]: ticketFile('in_progress'),
      [`/repo/${MERGE_LOG_PATH}`]: 'old line\n2026-10-19T15:16:33 [合併閘門] 開始\n',
    })
    const markdown = JSON.stringify(await ui.find({ type: 'Markdown' }))
    expect(markdown).toContain('341.1〔in_progress〕')
    expect(markdown).toContain('343〔completed〕')
    expect(markdown.includes('〔pending〕')).toBe(false)
    expect(markdown).toContain('284〔unknown〕')
    expect(await ui.find({ type: 'Text', text: /\[合併閘門\] 開始/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^更新 \d{4}-\d{2}-\d{2} / })).toBeDefined()
    await ui.unmount()
  })

  test('段落標題不存在時顯示「沒有資料」', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/repo/${DISPATCH_TICKET_PATH}`]: '---\nstatus: pending\n---\n## Solution\n',
      [`/repo/${MERGE_LOG_PATH}`]: '',
    })
    expect(await ui.find({ type: 'Text', text: /^沒有資料：/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeUndefined()
    await ui.unmount()
  })

  test('對照：349 票檔讀不到時顯示「解析失敗」而非「沒有資料」', async ($, on) => {
    const ui = await startBoard($, on, {
      [`/wt/${DISPATCH_TICKET_PATH}`]: TICKET_349,
    })
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^沒有資料：/ })).toBeUndefined()
    await ui.unmount()
  })
})
