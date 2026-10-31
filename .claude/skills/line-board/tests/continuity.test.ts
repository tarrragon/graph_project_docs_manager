// continuity.ts 的測試：來源紀錄解析、四種接續狀態與來源不明、三種過期偵測（各含 E2 正向對照）、輸出文字。

import { describe, expect, test } from 'claude-code/testing'

import { session } from './fixtures'
import { continuityTicketIds, formatLineStatus, lastSourceOf, lineStatusReport, parseSourceLog } from '../hooks/continuity'
import { endedForm, parseLaneLines, parseLanes } from '../hooks/lanes'
import type { LaneLine, SessionState, SourceLogEntry, TicketStatus } from '../types'

const PREFIX = '0.5.0-W1-'

/** 存活的 session：名稱與完整 sessionId（前 8 碼對應來源紀錄）。 */
const live = (name: string, sessionId: string | null, pid = 100): SessionState =>
  session({ name, status: 'idle', pid, cwd: '/repo', sessionId })

const entry = (time: string, source: string, sessionPrefix: string): SourceLogEntry => ({ time, source, sessionPrefix })

const lane = (n: number, sessionName: string | null, queue: string): LaneLine => ({ lane: n, session: sessionName, queue })

const report = (input: { lanes: LaneLine[]; sessions?: SessionState[]; log?: SourceLogEntry[]; tickets?: TicketStatus[] }) =>
  lineStatusReport({ sessions: [], log: [], tickets: [], prefix: PREFIX, ...input })

describe('parseSourceLog', () => {
  test('取時間、source、sessionId 前 8 碼；不符格式的行略過', () => {
    const text = [
      '[2026-10-31T15:13:07] source=clear session_id=f3450a54',
      '手動註記',
      '[2026-10-31T15:14:45] source=startup session_id=1aab01de',
      '',
    ].join('\n')
    expect(parseSourceLog(text)).toEqual([
      entry('2026-10-31T15:13:07', 'clear', 'f3450a54'),
      entry('2026-10-31T15:14:45', 'startup', '1aab01de'),
    ])
  })
})

describe('lastSourceOf', () => {
  test('同一 id 取時間最晚的一筆（多個 checkout 的紀錄合併後不依檔序）', () => {
    const log = [entry('2026-10-31T15:00:00', 'compact', 'aaaaaaaa'), entry('2026-10-31T09:00:00', 'startup', 'aaaaaaaa')]
    expect(lastSourceOf(log, 'aaaaaaaa-1111')?.source).toBe('compact')
  })

  test('查無此 id 為 undefined', () => {
    expect(lastSourceOf([entry('t', 'clear', 'bbbbbbbb')], 'aaaaaaaa-1111')).toBeUndefined()
  })
})

describe('接續狀態', () => {
  test('已收線：票序為（無）或（結束）', () => {
    const result = report({ lanes: [lane(1, 'a', '（無）'), lane(2, null, '（結束）')] })
    expect(result.lanes.map(l => l.state)).toEqual(['ended', 'ended'])
    expect(result.stale).toEqual([])
  })

  test('/clear 後繼續：存活 session 的 sessionId 最後一筆為 source=clear', () => {
    const result = report({
      lanes: [lane(3, '看板工具', '571.2 → 571.1')],
      sessions: [live('看板工具', 'c1c1c1c1-0000')],
      log: [entry('2026-10-31T10:00:00', 'startup', 'c1c1c1c1'), entry('2026-10-31T15:00:00', 'clear', 'c1c1c1c1')],
    })
    expect(result.lanes[0]).toEqual({
      lane: 3,
      session: '看板工具',
      state: 'clear',
      evidence: 'sessionId c1c1c1c1，log 2026-10-31T15:00:00 source=clear',
    })
  })

  test('/compact 後繼續：最後一筆為 source=compact', () => {
    const result = report({
      lanes: [lane(4, 'b', '100')],
      sessions: [live('b', 'd2d2d2d2-0000')],
      log: [entry('2026-10-31T11:00:00', 'compact', 'd2d2d2d2')],
    })
    expect(result.lanes[0]?.state).toBe('compact')
  })

  test('新 session 接手：最後一筆為 source=startup', () => {
    const result = report({
      lanes: [lane(5, 'c', '100')],
      sessions: [live('c', 'e3e3e3e3-0000')],
      log: [entry('2026-10-31T12:00:00', 'startup', 'e3e3e3e3')],
    })
    expect(result.lanes[0]?.state).toBe('startup')
  })

  test('來源不明：來源紀錄查無此 id、source 不在判讀表（resume）、session 檔沒有 sessionId、佇列行未寫名稱', () => {
    const result = report({
      lanes: [lane(6, 'd', '100'), lane(7, 'e', '100'), lane(8, 'f', '100'), lane(9, null, '100')],
      sessions: [live('d', 'f4f4f4f4-0000', 1), live('e', 'a5a5a5a5-0000', 2), live('f', null, 3)],
      log: [entry('2026-10-31T12:00:00', 'resume', 'a5a5a5a5')],
    })
    expect(result.lanes.map(l => l.state)).toEqual(['unknown', 'unknown', 'unknown', 'unknown'])
    expect(result.lanes.map(l => l.evidence)).toEqual([
      'sessionId f4f4f4f4，來源紀錄查無此 id',
      'sessionId a5a5a5a5，log 2026-10-31T12:00:00 source=resume',
      'pid 3 的 session 檔沒有 sessionId',
      '現行佇列行未寫 session 名稱',
    ])
  })
})

describe('過期偵測：收線寫法', () => {
  test('E2 正向對照：「（無）— 說明」判為已收線，並列為收線寫法過期項', () => {
    const result = report({ lanes: [lane(35, '整合測試卡住', '（無）— 移交 L40，見 564')] })
    expect(result.lanes[0]?.state).toBe('ended')
    expect(result.stale.map(s => [s.lane, s.kind])).toEqual([[35, 'ended-with-note']])
  })

  test('E2 正向對照：「無（說明）」（收線記號沒有括號）同樣列為過期項', () => {
    expect(report({ lanes: [lane(22, '框架線', '無（482.2 等 508.8）')] }).stale.map(s => s.kind)).toEqual(['ended-with-note'])
  })

  test('對照：只寫（無）不列過期項；票序中段出現（無）不算收線', () => {
    expect(endedForm('（無）')).toBe('exact')
    expect(endedForm('100（無）')).toBeNull()
    expect(endedForm('100 → 200')).toBeNull()
  })

  test('看板與 line_status 收線定義一致：（無）與（結束）看板都不顯示；附說明的寫法看板仍顯示、line_status 列過期項', () => {
    const text = '## Solution\n**L1 現行佇列**：（無）\n**L2 現行佇列**：（結束）\n**L3 現行佇列**：（無）— 說明\n'
    expect(parseLanes(text, PREFIX).map(l => l.lane)).toEqual([3])
    const result = report({ lanes: parseLaneLines(text) })
    expect(result.lanes.map(l => l.state)).toEqual(['ended', 'ended', 'ended'])
    expect(result.stale.map(s => s.lane)).toEqual([3])
  })

  test('協調票原文經 parseLaneLines 後仍保留收線的線，L35 的寫法可被偵測', () => {
    const text = '## Solution\n**L35 現行佇列**（整合測試卡住）：（無）— 說明\n**L36 現行佇列**（UX實驗）：（無）\n'
    const result = report({ lanes: parseLaneLines(text) })
    expect(result.lanes.map(l => [l.lane, l.state])).toEqual([
      [35, 'ended'],
      [36, 'ended'],
    ])
    expect(result.stale.map(s => s.lane)).toEqual([35])
  })
})

describe('過期偵測：無人持有', () => {
  test('E2 正向對照：佇列行的名稱不在存活 session 中，且佇列仍有內容', () => {
    const result = report({ lanes: [lane(18, '畫面接真資料', '508.8 → 168')], sessions: [live('其他線', 'aaaaaaaa-0')] })
    expect(result.lanes[0]?.state).toBe('orphan')
    expect(result.stale.map(s => [s.lane, s.kind])).toEqual([[18, 'orphan']])
  })

  test('E2 正向對照：佇列行未寫名稱且佇列仍有內容，同樣列為無人持有（狀態仍為來源不明）', () => {
    const result = report({ lanes: [lane(9, null, '100')] })
    expect(result.lanes[0]?.state).toBe('unknown')
    expect(result.stale.map(s => [s.lane, s.kind])).toEqual([[9, 'orphan']])
  })

  test('對照：名稱在存活 session 中時不列', () => {
    const result = report({
      lanes: [lane(18, '畫面接真資料', '508.8')],
      sessions: [live('畫面接真資料', 'aaaaaaaa-0')],
      log: [entry('t', 'startup', 'aaaaaaaa')],
    })
    expect(result.stale).toEqual([])
  })
})

describe('過期偵測：佇列已完成未收線', () => {
  const sessions = [live('a', 'aaaaaaaa-0')]
  const log = [entry('t', 'startup', 'aaaaaaaa')]

  test('E2 正向對照：佇列的票全部 completed，現行佇列行不是（無）', () => {
    const tickets = [
      { id: '0.5.0-W1-100', status: 'completed' },
      { id: '0.5.0-W1-200', status: 'completed' },
    ]
    const result = report({ lanes: [lane(1, 'a', '100 → 200')], sessions, log, tickets })
    expect(result.stale.map(s => [s.lane, s.kind])).toEqual([[1, 'all-done']])
  })

  test('對照：有一張未完成、或佇列沒有票號時不列', () => {
    const tickets = [
      { id: '0.5.0-W1-100', status: 'completed' },
      { id: '0.5.0-W1-200', status: 'in_progress' },
    ]
    expect(report({ lanes: [lane(1, 'a', '100 → 200')], sessions, log, tickets }).stale).toEqual([])
    expect(report({ lanes: [lane(1, 'a', '等主控通知')], sessions, log }).stale).toEqual([])
  })
})

describe('continuityTicketIds', () => {
  test('只取未收線的線的票號，去重', () => {
    const lanes = [lane(1, 'a', '100 → 200'), lane(2, 'b', '（無）— 300'), lane(3, 'c', '200 ∥ 400')]
    expect(continuityTicketIds(lanes, PREFIX)).toEqual(['0.5.0-W1-100', '0.5.0-W1-200', '0.5.0-W1-400'])
  })
})

describe('formatLineStatus', () => {
  test('未收線各線一行、已收線合併一行、過期項逐條、末行為判讀規則路由', () => {
    const text = formatLineStatus(
      {
        lanes: [
          { lane: 3, session: '看板工具', state: 'clear', evidence: 'sessionId c1c1c1c1，log t source=clear' },
          { lane: 35, session: 'x', state: 'ended', evidence: '票序「（無）— 說明」' },
          { lane: 36, session: 'y', state: 'ended', evidence: '票序「（無）」' },
        ],
        stale: [{ lane: 35, kind: 'ended-with-note', detail: '說明' }],
      },
      { coordinationTicket: '0.5.0-W1-349', readAt: '2026-10-31 15:30:00' },
    )
    expect(text.split('\n')).toEqual([
      '各線接續狀態（協調票 0.5.0-W1-349，讀取 2026-10-31 15:30:00）',
      'L3（看板工具）：/clear 後繼續｜sessionId c1c1c1c1，log t source=clear',
      '已收線：L35、L36',
      '過期項（1）：',
      '- L35 收線寫法：說明',
      '判讀規則與各狀態的接續動作：.claude/skills/multi-session-orchestration/references/line-continuity.md §2',
    ])
  })

  test('沒有未收線的線、沒有過期項時明寫「無」', () => {
    const text = formatLineStatus({ lanes: [], stale: [] }, { coordinationTicket: 'c', readAt: 't' })
    expect(text).toContain('未收線的線：無')
    expect(text).toContain('過期項：無')
  })
})
