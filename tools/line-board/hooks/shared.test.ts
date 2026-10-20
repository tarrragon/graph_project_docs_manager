// shared.ts 的測試：checkout 路徑判定、距今時間、票檔 frontmatter 狀態與 title 解析。

import { describe, expect, test } from 'claude-code/testing'

import { ticketFile } from './fixtures'
import { formatAge, parseFrontmatterStatus, parseFrontmatterTitle, parseWorktreePaths } from './shared'

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

describe('parseFrontmatterTitle', () => {
  test('讀 frontmatter 內的 title，不讀本文；單引號與雙引號包住的值去掉引號', () => {
    expect(parseFrontmatterTitle(ticketFile('pending', '實作 line-board 佇列票摘要'))).toBe('實作 line-board 佇列票摘要')
    expect(parseFrontmatterTitle(ticketFile('pending', "'補上 has_functional_requirements: false 宣告'"))).toBe(
      '補上 has_functional_requirements: false 宣告',
    )
    expect(parseFrontmatterTitle(ticketFile('pending', "'含 ''引號'' 的標題'"))).toBe("含 '引號' 的標題")
    expect(parseFrontmatterTitle(ticketFile('pending', '"雙引號 \\"內含\\" 的標題"'))).toBe('雙引號 "內含" 的標題')
  })

  test('沒有 frontmatter、沒有 title 欄或 title 為空時回傳 null', () => {
    expect(parseFrontmatterTitle('title: x\n')).toBeNull()
    expect(parseFrontmatterTitle(ticketFile('pending'))).toBeNull()
    expect(parseFrontmatterTitle(ticketFile('pending', "''"))).toBeNull()
  })
})
