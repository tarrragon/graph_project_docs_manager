// Pane 的端到端繪製：派發中代理人區塊（依線分組、流程階段、舊條目不列、各種讀取失敗下的行為）。
// 其餘區塊在 board.test.ts；派發的純函式在 dispatch.test.ts。

import { describe, expect, test } from 'claude-code/testing'

import { DISPATCH_ACTIVE_PATH } from './dispatch'
import { TICKET_349, dispatchJson, overlapLogUntil, ticketFile } from './fixtures'
import { DISPATCH_TICKET_PATH } from './lanes'
import { MERGE_LOG_PATH } from './mergeGate'
import { sessionStub, startBoard } from './paneHarness'
import { TICKETS_DIR } from './shared'

describe('Pane', () => {
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
