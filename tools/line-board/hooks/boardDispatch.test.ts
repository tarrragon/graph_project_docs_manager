// Pane 的端到端繪製：以線分組的可折疊群組（派發列歸線、活動計數、預設展開、手動切換）與派發紀錄的各種讀取失敗。
// 線標題的 session 狀態與目標、各 session 與合併閘門兩區塊在 board.test.ts；群組的純函式在 layout.test.ts。

import { describe, expect, test } from 'claude-code/testing'

import { DISPATCH_ACTIVE_PATH } from './dispatch'
import { MERGE_LOG_HOLDING, TICKET_349, dispatchJson, overlapLogUntil, ticketFile } from './fixtures'
import { DISPATCH_TICKET_PATH } from './lanes'
import { OTHER_GROUP_ID, groupBodyKey, groupToggleKey, laneGroupId } from './layout'
import { MERGE_LOG_PATH } from './mergeGate'
import { sessionStub, startBoard } from './paneHarness'
import { TICKETS_DIR } from './shared'

type Ui = Awaited<ReturnType<typeof startBoard>>['ui']

/** 一個描述節點內所有 Text 的文字，依文件順序；Text 的文字為其字串子節點相接。 */
function textsOf(nodes: readonly unknown[]): string[] {
  const texts: string[] = []
  for (const node of nodes) {
    if (typeof node !== 'object' || node === null) continue
    const element = node as { type?: unknown; children?: unknown; props?: { children?: unknown } }
    const children = Array.isArray(element.children) ? element.children : Array.isArray(element.props?.children) ? element.props.children : []
    if (element.type === 'Text') texts.push(children.filter((child): child is string => typeof child === 'string').join(''))
    else texts.push(...textsOf(children))
  }
  return texts
}

/** 群組標題列（Button）的文字；群組未畫出時為 undefined。 */
async function headerOf(ui: Ui, id: string): Promise<string | undefined> {
  return (await ui.find({ type: 'Button', key: groupToggleKey(id) }))?.text
}

/** 群組展開內容的各行文字；收合（內容未畫出）時為 undefined。 */
async function bodyOf(ui: Ui, id: string): Promise<string[] | undefined> {
  const body = await ui.find({ type: 'Box', key: groupBodyKey(id) })
  return body === undefined ? undefined : textsOf(body.children)
}

/** 派發列：`<代理人>｜<任務>｜<流程階段>｜<距派發時間>`。 */
const DISPATCH_ROW = /^[^｜]+｜[^｜]+｜(實作|審查|事故分析|閘門|收尾)｜[^｜]+$/

/** 整個 Pane 畫出的派發列（收合的群組不畫內容，其派發列不在其中）。 */
async function allDispatchRows(ui: Ui): Promise<string[]> {
  return (await ui.findAll({ type: 'Text', text: DISPATCH_ROW })).map(row => row.text)
}

/** 派發列去掉末尾的時間欄（重讀後時間會前進），只比對代理人、任務與階段。 */
const withoutAge = (text: string) => text.replace(/｜[^｜]*$/, '')

/** 下一輪定時讀取：時鐘前進一個更新間隔（30 秒），看板依 stub 的現況重讀。 */
const REFRESH_MS = 30_000

describe('Pane', () => {
  /**
   * 派發紀錄：各階段一筆（session 依 sessionStub：sid-101 為 L7 的 f9、sid-102 為 L13 的 1b（waiting）、sid-103 為不在任何線的 d7），
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

  test('以線分組：派發列歸到 session 所在的線、依序接著該線的佇列列；對不到線的派發在最後的「其他」；只讀主 checkout 的派發紀錄', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(DISPATCH_ACTIVE))
    expect(await bodyOf(ui, laneGroupId(7))).toEqual([
      'linux｜Readonly review of 337.8｜審查｜3 分前',
      'incident-responder｜分析 354.1 閘門紅燈｜事故分析｜3 分前',
      '排隊：351〔in_progress〕 → 145〔unknown〕',
    ])
    expect(await bodyOf(ui, laneGroupId(13))).toEqual([
      'general-purpose｜337.9｜實作｜3 分前',
      'general-purpose｜351｜閘門｜3 分前',
      '排隊：337.1〔completed〕（待用戶實機驗證） → 337.3〔unknown〕 → 337.2.1〔unknown〕',
    ])
    expect(await bodyOf(ui, OTHER_GROUP_ID)).toEqual(['general-purpose｜345｜收尾｜3 分前'])
    expect(await headerOf(ui, OTHER_GROUP_ID)).toBe('▾ 其他｜1 派發中')
    // 群組依線號排序、其他最後
    const headers = (await ui.findAll({ type: 'Button', text: /^[▸▾] (L\d+|其他)/ })).map(item => item.text.split('｜')[0])
    expect(headers).toEqual(['▾ L7', '▸ L9', '▾ L13', '▾ 其他'])
    expect(await ui.find({ type: 'Text', text: /讀取 \.claude\/dispatch-active\.json 失敗/ })).toBeUndefined()
    await ui.unmount()
  })

  test('預設展開：有派發中代理人（L7）、session 為 waiting（L13）的線展開；無活動的線（L9）收合為一行，只有標題列', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(JSON.stringify({ dispatches: [] })))
    // 沒有任何派發：L7 的 session 為 busy、無派發，收合；L13 的 session 為 waiting，展開
    expect(await headerOf(ui, laneGroupId(13))).toBe('▾ L13｜graph-project-docs-manager-1b［waiting：input needed］｜等你處理 · 2 排隊')
    expect(await bodyOf(ui, laneGroupId(13))).toEqual(['排隊：337.1〔completed〕（待用戶實機驗證） → 337.3〔unknown〕 → 337.2.1〔unknown〕'])
    expect(await headerOf(ui, laneGroupId(7))).toBe('▸ L7｜graph-project-docs-manager-f9［busy］｜2 排隊')
    expect(await bodyOf(ui, laneGroupId(7))).toBeUndefined()
    expect(await headerOf(ui, laneGroupId(9))).toBe('▸ L9｜graph-project-docs-manager-3e［離線］｜4 排隊')
    expect(await bodyOf(ui, laneGroupId(9))).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^排隊：356/ })).toBeUndefined()
    await ui.unmount()
  })

  test('對照：同一條 L7 在派發紀錄出現 L7 的派發後重讀即展開（預設依每輪資料重算）', async ($, on) => {
    const stub = dispatchFiles(JSON.stringify({ dispatches: [] }))
    const { ui, clock } = await startBoard($, on, stub)
    expect(await bodyOf(ui, laneGroupId(7))).toBeUndefined()
    stub.files[`/repo/${DISPATCH_ACTIVE_PATH}`] = DISPATCH_ACTIVE
    await clock.advance(REFRESH_MS)
    expect((await headerOf(ui, laneGroupId(7)))?.startsWith('▾ L7｜')).toBe(true)
    expect((await bodyOf(ui, laneGroupId(7)))?.length).toBe(3)
    expect(await bodyOf(ui, laneGroupId(9))).toBeUndefined()
    await ui.unmount()
  })

  test('預設展開：佇列票的 feat 分支持有閘門的線即使沒有派發也展開，內容列出閘門票；對照：同一條線在閘門結束後收合', async ($, on) => {
    const stub = { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349, [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG_HOLDING } }
    const { ui, clock } = await startBoard($, on, stub)
    expect(await headerOf(ui, laneGroupId(7))).toBe('▾ L7｜graph-project-docs-manager-f9［狀態不明］｜1 閘門 · 2 排隊')
    expect(await bodyOf(ui, laneGroupId(7))).toEqual(['閘門｜351｜自 16:41:49', '排隊：351〔unknown〕 → 145〔unknown〕'])
    expect(await bodyOf(ui, laneGroupId(9))).toBeUndefined()
    // 閘門結束（寫入結束行）後重讀：L7 沒有其他活動，回到預設收合
    stub.files[`/repo/${MERGE_LOG_PATH}`] = `${MERGE_LOG_HOLDING}2026-10-19T16:50:00 [合併閘門] 結束｜target main｜分支 feat/0.5.0-W1-351｜commit 1a2b3c4d5e6f｜結果 寫入\n`
    await clock.advance(REFRESH_MS)
    expect(await headerOf(ui, laneGroupId(7))).toBe('▸ L7｜graph-project-docs-manager-f9［狀態不明］｜2 排隊')
    expect(await bodyOf(ui, laneGroupId(7))).toBeUndefined()
    await ui.unmount()
  })

  test('標題列的活動計數與展開內容一致：派發中＝派發列數、閘門＝階段為閘門的派發列＋閘門票列、排隊＝佇列列中非 completed 的票數', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    stub.files[`/repo/${MERGE_LOG_PATH}`] = `${overlapLogUntil('16:19:46')}\n2026-10-19T16:41:49 [合併閘門] 開始｜target main｜分支 feat/0.5.0-W1-351｜commit 52477a34f0ce\n`
    const { ui } = await startBoard($, on, stub)
    await ui.press({ key: groupToggleKey(laneGroupId(9)) })
    const ids = [laneGroupId(7), laneGroupId(9), laneGroupId(13), OTHER_GROUP_ID]
    expect(await Promise.all(ids.map(id => headerOf(ui, id)))).toEqual([
      '▾ L7｜graph-project-docs-manager-f9［busy］｜2 派發中 · 1 閘門 · 2 排隊',
      '▾ L9｜graph-project-docs-manager-3e［離線］｜4 排隊',
      '▾ L13｜graph-project-docs-manager-1b［waiting：input needed］｜2 派發中 · 1 閘門 · 等你處理 · 2 排隊',
      '▾ 其他｜1 派發中',
    ])
    for (const id of ids) {
      const header = (await headerOf(ui, id)) ?? ''
      const body = (await bodyOf(ui, id)) ?? []
      const count = (label: string) => Number(new RegExp(`(\\d+) ${label}`).exec(header)?.[1] ?? 0)
      const dispatchRows = body.filter(line => DISPATCH_ROW.test(line))
      const gateRows = body.filter(line => line.startsWith('閘門｜'))
      const queueTickets = (body.find(line => line.startsWith('排隊：')) ?? '排隊：').slice('排隊：'.length).split(/ [→∥] /).filter(part => part !== '')
      expect(count('派發中')).toBe(dispatchRows.length)
      expect(count('閘門')).toBe(dispatchRows.filter(line => line.includes('｜閘門｜')).length + gateRows.length)
      expect(count('排隊')).toBe(queueTickets.filter(part => !part.includes('〔completed〕')).length)
    }
    // L7 的 351 由 feat 分支持有閘門，列為閘門票；L13 的派發列已標閘門，不另列閘門票
    expect(await bodyOf(ui, laneGroupId(7))).toContain('閘門｜351｜自 16:41:49')
    expect((await bodyOf(ui, laneGroupId(13)))?.some(line => line.startsWith('閘門｜'))).toBe(false)
    await ui.unmount()
  })

  test('手動切換優先於預設：展開預設收合的線、收合預設展開的線；資料刷新後保留，未按過的線仍依新資料的預設', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    const { ui, clock } = await startBoard($, on, stub)
    await ui.press({ key: groupToggleKey(laneGroupId(9)) })
    await ui.press({ key: groupToggleKey(laneGroupId(13)) })
    expect((await headerOf(ui, laneGroupId(9)))?.startsWith('▾ L9｜')).toBe(true)
    expect(await bodyOf(ui, laneGroupId(9))).toEqual(['排隊：356〔unknown〕 → 353.1〔unknown〕 ∥ 341.2.1〔unknown〕 → 284〔unknown〕'])
    expect((await headerOf(ui, laneGroupId(13)))?.startsWith('▸ L13｜')).toBe(true)
    expect(await bodyOf(ui, laneGroupId(13))).toBeUndefined()
    // 同一份資料重讀：手動狀態不變
    await clock.advance(REFRESH_MS)
    expect(await bodyOf(ui, laneGroupId(9))).toBeDefined()
    expect(await bodyOf(ui, laneGroupId(13))).toBeUndefined()
    expect(await bodyOf(ui, laneGroupId(7))).toBeDefined()
    // 派發全數結束後重讀：L7（未按過）依新資料回到收合；L9、L13 仍是手動狀態，L13 的 session 仍為 waiting 也不自動展開
    stub.files[`/repo/${DISPATCH_ACTIVE_PATH}`] = JSON.stringify({ dispatches: [] })
    await clock.advance(REFRESH_MS)
    expect(await bodyOf(ui, laneGroupId(7))).toBeUndefined()
    expect(await bodyOf(ui, laneGroupId(9))).toBeDefined()
    expect(await bodyOf(ui, laneGroupId(13))).toBeUndefined()
    // 再按一次 L13：回到展開
    await ui.press({ key: groupToggleKey(laneGroupId(13)) })
    expect(await bodyOf(ui, laneGroupId(13))).toEqual(['排隊：337.1〔completed〕（待用戶實機驗證） → 337.3〔unknown〕 → 337.2.1〔unknown〕'])
    await ui.unmount()
  })

  test('E2：票已 completed、session 不存活（pid 已結束或狀態檔不存在）、已結束且無票號的舊條目不列出', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(DISPATCH_ACTIVE))
    const rows = await allDispatchRows(ui)
    expect(rows.length).toBe(5)
    expect(rows.some(text => text.includes('337.1'))).toBe(false)
    expect(rows.some(text => text.includes('STALE'))).toBe(false)
    expect(rows.some(text => text.includes('WORKTREE'))).toBe(false)
    await ui.unmount()
  })

  test('沒有任何應列出的派發時顯示「（目前沒有派發中的代理人）」，不產生「其他」群組', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles(JSON.stringify({ dispatches: [] })))
    expect(await ui.find({ type: 'Text', text: /^（目前沒有派發中的代理人）$/ })).toBeDefined()
    expect(await allDispatchRows(ui)).toEqual([])
    expect(await headerOf(ui, OTHER_GROUP_ID)).toBeUndefined()
    await ui.unmount()
  })

  /** 派發紀錄失敗時，其餘內容（線群組、各 session、閘門紀錄）照常顯示。 */
  async function expectOtherBlocksIntact(ui: Ui) {
    expect(await headerOf(ui, laneGroupId(7))).toBe('▸ L7｜graph-project-docs-manager-f9［busy］｜2 排隊')
    expect(await ui.find({ type: 'Text', text: /^graph-project-docs-manager-1b｜waiting：input needed｜/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^閘門使用中：agent-a352c3（自 16:19:45）$/ })).toBeDefined()
    expect(await allDispatchRows(ui)).toEqual([])
  }

  test('派發紀錄檔讀不到時，顯示讀取失敗，其餘內容照常', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    delete stub.files[`/repo/${DISPATCH_ACTIVE_PATH}`]
    const { ui } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await expectOtherBlocksIntact(ui)
    await ui.unmount()
  })

  test('派發紀錄格式錯誤（JSON 無效）時，顯示讀取失敗，其餘內容照常', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles('{"dispatches": ['))
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await expectOtherBlocksIntact(ui)
    await ui.unmount()
  })

  test('派發紀錄格式錯誤（dispatches 不是陣列）時，顯示讀取失敗', async ($, on) => {
    const { ui } = await startBoard($, on, dispatchFiles('{"dispatches": {}}'))
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/dispatch-active\.json 失敗（/ })).toBeDefined()
    await ui.unmount()
  })

  test('349 讀不到時，派發條目照常列出並全歸「其他」；對照：同一份 fixture 讀得到 349 後歸到對應的線', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    const ticket349 = stub.files[`/repo/${DISPATCH_TICKET_PATH}`] ?? ''
    delete stub.files[`/repo/${DISPATCH_TICKET_PATH}`]
    const { ui, clock } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^解析失敗/ })).toBeDefined()
    expect((await bodyOf(ui, OTHER_GROUP_ID))?.map(withoutAge)).toEqual([
      'general-purpose｜337.9｜實作',
      'linux｜Readonly review of 337.8｜審查',
      'incident-responder｜分析 354.1 閘門紅燈｜事故分析',
      'general-purpose｜351｜閘門',
      'general-purpose｜345｜收尾',
    ])
    // 正向對照：補回 349 後重讀，同一批條目歸到 session 所在的線
    stub.files[`/repo/${DISPATCH_TICKET_PATH}`] = ticket349
    await clock.advance(REFRESH_MS)
    const dispatchesOf = async (id: string) => ((await bodyOf(ui, id)) ?? []).filter(line => DISPATCH_ROW.test(line)).map(withoutAge)
    expect(await dispatchesOf(laneGroupId(7))).toEqual(['linux｜Readonly review of 337.8｜審查', 'incident-responder｜分析 354.1 閘門紅燈｜事故分析'])
    expect(await dispatchesOf(laneGroupId(13))).toEqual(['general-purpose｜337.9｜實作', 'general-purpose｜351｜閘門'])
    expect(await dispatchesOf(OTHER_GROUP_ID)).toEqual(['general-purpose｜345｜收尾'])
    await ui.unmount()
  })

  test('閘門紀錄讀不到時，派發條目照常列出且沒有任何一列為「閘門」；對照：同一份 fixture 讀得到閘門紀錄後標為閘門', async ($, on) => {
    const stub = dispatchFiles(DISPATCH_ACTIVE)
    const mergeLog = stub.files[`/repo/${MERGE_LOG_PATH}`] ?? ''
    delete stub.files[`/repo/${MERGE_LOG_PATH}`]
    const { ui, clock } = await startBoard($, on, stub)
    expect(await ui.find({ type: 'Text', text: /^讀取 \.claude\/logs\/worktree-merge\.log 失敗/ })).toBeDefined()
    const missing = (await allDispatchRows(ui)).map(withoutAge)
    expect(missing.length).toBe(5)
    expect(missing.some(text => text.endsWith('｜閘門'))).toBe(false)
    // 持有閘門的 a352 已結束且票未完成，閘門紀錄讀不到時落回「收尾」
    expect(missing).toContain('general-purpose｜351｜收尾')
    // 正向對照：補回閘門紀錄後重讀，同一條目標為閘門
    stub.files[`/repo/${MERGE_LOG_PATH}`] = mergeLog
    await clock.advance(REFRESH_MS)
    const present = (await allDispatchRows(ui)).map(withoutAge)
    expect(present).toContain('general-purpose｜351｜閘門')
    expect(present.filter(text => text.endsWith('｜閘門')).length).toBe(1)
    await ui.unmount()
  })

  test('sessions 目錄無法列出時，不列派發條目，標明無法判定', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349, [`/repo/${DISPATCH_ACTIVE_PATH}`]: DISPATCH_ACTIVE },
    })
    expect(await ui.find({ type: 'Text', text: /^（session 狀態讀取失敗，無法判定派發中的代理人）$/ })).toBeDefined()
    expect(await allDispatchRows(ui)).toEqual([])
    await ui.unmount()
  })
})
