// lanes.ts 的測試：349 現行佇列行與線目標行解析、票序拆分與格式化。

import { describe, expect, test } from 'claude-code/testing'

import { TEMPLATE_AT_LINE_START, TEMPLATE_NOTE, TICKET_349, TICKET_349_GOALS } from './fixtures'
import { formatQueue, laneTicketIds, parseLaneGoals, parseLanes, parseQueue } from './lanes'

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
