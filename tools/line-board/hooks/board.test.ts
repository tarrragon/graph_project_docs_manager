// Pane 的端到端繪製：線列（佇列、session 狀態、目標）、各 session 區塊、合併閘門區塊與 349 的兩種空狀態。
// 派發中代理人區塊在 boardDispatch.test.ts；各 domain 的純函式在同名的 *.test.ts。

import { describe, expect, test } from 'claude-code/testing'

import {
  MALFORMED_GATE_LINES,
  MERGE_LOG,
  MERGE_LOG_HOLDING,
  REAL_LSTART_UTC,
  REAL_PROC_START,
  TEMPLATE_NOTE,
  TICKET_349,
  TICKET_349_GOALS,
  overlapLogUntil,
  sessionJson,
  ticketFile,
} from './fixtures'
import { DISPATCH_TICKET_PATH } from './lanes'
import { MERGE_LOG_PATH } from './mergeGate'
import { SESSIONS, sessionStub, startBoard } from './paneHarness'
import { TICKETS_DIR } from './shared'

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

describe('Pane', () => {
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
})
