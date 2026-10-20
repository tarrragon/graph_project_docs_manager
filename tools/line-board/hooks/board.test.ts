// Pane 的端到端繪製：線群組的標題列（session 狀態、目標）與票序、佇列細節、可折疊的各 session 與合併閘門兩區塊、349 的兩種空狀態。
// 群組的派發列、活動計數、預設展開與手動切換在 boardDispatch.test.ts；各 domain 的純函式在同名的 *.test.ts。

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
import { GROUP_BORDER_COLUMNS, groupTitleKey, laneDetailId } from './lanesView'
import { GROUP_INDENT, MERGE_GATE_GROUP_ID, SESSIONS_GROUP_ID, groupBodyKey, groupToggleKey, laneGroupId } from './layout'
import { MERGE_LOG_PATH } from './mergeGate'
import { SESSIONS, sessionStub, startBoard } from './paneHarness'
import { TICKETS_DIR } from './shared'

type Ui = Awaited<ReturnType<typeof startBoard>>['ui']

/** 群組標題的各行：標題列（Button）的文字，其後為標題 Box 內各 Text 的文字（目標、活動計數）；群組未畫出時為 undefined。 */
async function titleOf(ui: Ui, id: string): Promise<string[] | undefined> {
  const header = await ui.find({ type: 'Button', key: groupToggleKey(id) })
  const title = await ui.find({ type: 'Box', key: groupTitleKey(id) })
  return header === undefined || title === undefined ? undefined : [header.text, ...textLines(title.children)]
}

/** 描述節點內所有 Text 的文字，依文件順序（Text 包在縮排的 Box 內時往下找）；Button 的文字不在其中。 */
function textLines(nodes: readonly unknown[]): string[] {
  const texts: string[] = []
  for (const node of nodes) {
    if (typeof node !== 'object' || node === null) continue
    const element = node as { type?: unknown; children?: unknown; props?: { children?: unknown } }
    const children = Array.isArray(element.children) ? element.children : Array.isArray(element.props?.children) ? element.props.children : []
    if (element.type === 'Text') texts.push(children.filter((child): child is string => typeof child === 'string').join(''))
    else if (element.type !== 'Button') texts.push(...textLines(children))
  }
  return texts
}

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

  test('各 session：waiting 以洋紅粗體顯示（要人處理），其他狀態不上色', async ($, on) => {
    const { ui } = await startBoard($, on, sessionStub({ [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 }))
    const rows = await ui.findAll({ type: 'Text', text: /^graph-project-docs-manager-/ })
    expect(rows.map(row => [row.text.split('｜')[1], row.props.color, row.props.bold ?? false])).toEqual([
      ['waiting：input needed', 'magenta', true],
      ['shell', undefined, false],
      ['busy', undefined, false],
      ['idle', undefined, false],
      ['compacting', undefined, false],
    ])
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

  test('線標題列 session 旁標狀態：存活者取其 status，pid 已結束或找不到的為離線', async ($, on) => {
    const { ui } = await startBoard($, on, sessionStub({ [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 }))
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L7 graph-project-docs-manager-f9［busy］$/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L13 graph-project-docs-manager-1b［waiting：input needed］$/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L9 graph-project-docs-manager-3e［離線］$/ })).toBeDefined()
    await ui.unmount()
  })

  test('線標題顯示目標：有目標行的線在標題列下一行顯示「目標：<文字>」、再下一行為活動計數，寫（無）或沒有可採用目標行的線省略目標行', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349_GOALS } })
    const l13 = await titleOf(ui, laneGroupId(13))
    expect(l13?.length).toBe(3)
    expect(l13?.[0]).toMatch(/^[▸▾] L13 /)
    expect(l13?.slice(1)).toEqual(['目標：顯示各線目標與派發中代理人', expect.stringMatching(/^\d+ 排隊$/)])
    const l7 = await titleOf(ui, laneGroupId(7))
    const l9 = await titleOf(ui, laneGroupId(9))
    expect(l7?.length).toBe(2)
    expect(l9?.length).toBe(2)
    expect(l7?.join('\n')).not.toContain('目標')
    expect(l9?.join('\n')).not.toContain('目標')
    for (const ignored of ['舊目標', '清單項的目標', '表格內的目標', '反引號範本的目標', '會被清除的目標', 'Solution 之外的目標']) {
      expect(await ui.find({ text: new RegExp(ignored) })).toBeUndefined()
    }
    await ui.unmount()
  })

  test('對照：349 沒有任何目標行時，所有線標題都沒有目標行', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 } })
    const rows = await ui.findAll({ type: 'Button', text: /^[▸▾] L\d+ / })
    expect(rows.length).toBe(3)
    for (const row of rows) expect(row.text).not.toContain('目標')
    expect(await ui.find({ type: 'Text', text: /^目標：/ })).toBeUndefined()
    await ui.unmount()
  })

  test('sessions 目錄無法列出時，各 session 區塊顯示讀取失敗，線標題列標狀態不明', async ($, on) => {
    const { ui } = await startBoard($, on, { files: { [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349 } })
    expect(await ui.find({ type: 'Text', text: /^讀取 ~\/\.claude\/sessions 失敗/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L7 graph-project-docs-manager-f9［狀態不明］$/ })).toBeDefined()
    await ui.unmount()
  })

  test('「各 session」與「合併閘門最近紀錄」預設展開，按標題列收合後只剩標題列，再按一次展開', async ($, on) => {
    const { ui } = await startBoard(
      $,
      on,
      sessionStub({ [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349, [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG }),
    )
    const sessionRow = { type: 'Text', text: /^graph-project-docs-manager-1b｜waiting/ }
    const gateRow = { type: 'Text', text: /^16:11:45｜結束｜/ }
    expect((await ui.find({ type: 'Button', key: groupToggleKey(SESSIONS_GROUP_ID) }))?.text).toBe('▾ 各 session')
    expect((await ui.find({ type: 'Button', key: groupToggleKey(MERGE_GATE_GROUP_ID) }))?.text).toBe('▾ 合併閘門最近紀錄')
    expect(await ui.find(sessionRow)).toBeDefined()
    expect(await ui.find(gateRow)).toBeDefined()
    await ui.press({ key: groupToggleKey(SESSIONS_GROUP_ID) })
    await ui.press({ key: groupToggleKey(MERGE_GATE_GROUP_ID) })
    expect((await ui.find({ type: 'Button', key: groupToggleKey(SESSIONS_GROUP_ID) }))?.text).toBe('▸ 各 session')
    expect((await ui.find({ type: 'Button', key: groupToggleKey(MERGE_GATE_GROUP_ID) }))?.text).toBe('▸ 合併閘門最近紀錄')
    expect(await ui.find(sessionRow)).toBeUndefined()
    expect(await ui.find(gateRow)).toBeUndefined()
    await ui.press({ key: groupToggleKey(SESSIONS_GROUP_ID) })
    expect(await ui.find(sessionRow)).toBeDefined()
    expect(await ui.find(gateRow)).toBeUndefined()
    await ui.unmount()
  })

  test('每條線一個群組（線號、session、票號與 main 的狀態），歷史票號不出現；收合的線按標題列後才列出票序；閘門區只有開始與結束', async ($, on) => {
    const { ui } = await startBoard($, on, {
      files: {
        [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
        [`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('in_progress'),
        [`/wt/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('pending'),
        [`/repo/${TICKETS_DIR}/0.5.0-W1-337.1.md`]: ticketFile('completed'),
        [`/repo/${MERGE_LOG_PATH}`]: MERGE_LOG,
      },
    })
    expect(await titleOf(ui, laneGroupId(7))).toEqual([expect.stringMatching(/^▸ L7 graph-project-docs-manager-f9［[^］]*］$/), '2 排隊'])
    expect(await ui.find({ type: 'Text', text: /^排隊：351/ })).toBeUndefined()
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    await ui.press({ key: groupToggleKey(laneGroupId(13)) })
    expect(await ui.find({ type: 'Text', text: /^排隊：351〔in_progress〕 → 145〔unknown〕$/ })).toBeDefined()
    // 337.1 在 main 已 completed，不在佇列列中
    expect(await ui.find({ type: 'Text', text: /^排隊：337\.3〔unknown〕 → 337\.2\.1〔unknown〕$/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /337\.1〔/ })).toBeUndefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L13 graph-project-docs-manager-1b［[^］]*］$/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L9 / })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /^[▸▾] L11 / })).toBeUndefined()
    expect(await ui.find({ text: /328\.1|348〔/ })).toBeUndefined()
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
    const heading = await ui.find({ type: 'Button', key: groupToggleKey(MERGE_GATE_GROUP_ID) })
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
    // 群組外框的左右框線占 GROUP_BORDER_COLUMNS 欄、內容再縮排 GROUP_INDENT 欄，每行可用的寬度為兩者之外的部分
    for (const row of rows) expect(displayWidth(row.text)).toBeLessThanOrEqual(60 - GROUP_BORDER_COLUMNS - GROUP_INDENT)
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

  /**
   * 佇列細節的票檔：L7 的 351 在 main 為 in_progress 並有 title（worktree 副本的 title 不同）、145 沒有票檔；
   * L13 的 337.1 已完成、337.3 為 pending 並有 title、337.2.1 沒有票檔。
   */
  const detailFiles = (): Record<string, string> => ({
    [`/repo/${DISPATCH_TICKET_PATH}`]: TICKET_349,
    [`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('in_progress', '實作看板細節'),
    [`/wt/${TICKETS_DIR}/0.5.0-W1-351.md`]: ticketFile('pending', 'WORKTREE 舊副本的 title'),
    [`/repo/${TICKETS_DIR}/0.5.0-W1-337.1.md`]: ticketFile('completed', '已完成的票'),
    [`/repo/${TICKETS_DIR}/0.5.0-W1-337.3.md`]: ticketFile('pending', "'等待排程的票'"),
  })

  /** 線群組的佇列細節各行；細節收合（未畫出）時為 undefined。 */
  async function detailOf(ui: Ui, laneId: string): Promise<string[] | undefined> {
    const box = await ui.find({ type: 'Box', key: groupBodyKey(laneDetailId(laneId)) })
    return box === undefined ? undefined : textLines(box.children)
  }

  test('佇列細節：有佇列列的線群組各有一個細節按鍵，預設收合；按下後逐張列出未完成佇列票的短票號、狀態與 title，title 只讀主 checkout、讀不到時標明', async ($, on) => {
    const { ui } = await startBoard($, on, { files: detailFiles() })
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    await ui.press({ key: groupToggleKey(laneGroupId(13)) })
    for (const id of [laneGroupId(7), laneGroupId(13)]) {
      expect((await ui.find({ type: 'Button', key: groupToggleKey(laneDetailId(id)) }))?.text).toBe('▸ 佇列細節')
      expect(await detailOf(ui, id)).toBeUndefined()
    }
    // 佇列列維持一行
    expect(await ui.find({ type: 'Text', text: /^排隊：351〔in_progress〕 → 145〔unknown〕$/ })).toBeDefined()
    await ui.press({ key: groupToggleKey(laneDetailId(laneGroupId(7))) })
    await ui.press({ key: groupToggleKey(laneDetailId(laneGroupId(13))) })
    expect((await ui.find({ type: 'Button', key: groupToggleKey(laneDetailId(laneGroupId(7))) }))?.text).toBe('▾ 佇列細節')
    expect(await detailOf(ui, laneGroupId(7))).toEqual(['351｜in_progress｜實作看板細節', '145｜unknown｜（讀不到 title）'])
    // 337.1 已 completed，不列
    expect(await detailOf(ui, laneGroupId(13))).toEqual(['337.3｜pending｜等待排程的票', '337.2.1｜unknown｜（讀不到 title）'])
    expect(await ui.find({ text: /已完成的票|WORKTREE/ })).toBeUndefined()
    await ui.unmount()
  })

  test('佇列細節：各行依佇列票的五色狀態上色、以 truncate-end 截斷', async ($, on) => {
    const { ui } = await startBoard($, on, { files: detailFiles() })
    for (const id of [laneGroupId(7), laneGroupId(13)]) {
      await ui.press({ key: groupToggleKey(id) })
      await ui.press({ key: groupToggleKey(laneDetailId(id)) })
    }
    const rows = await ui.findAll({ type: 'Text', text: /^\d{3}[\d.]*｜/ })
    expect(rows.map(row => [row.text.split('｜')[0], row.props.color, row.props.wrap])).toEqual([
      ['351', 'green', 'truncate-end'],
      ['145', undefined, 'truncate-end'],
      ['337.3', 'gray', 'truncate-end'],
      ['337.2.1', undefined, 'truncate-end'],
    ])
    await ui.unmount()
  })

  test('佇列細節：手動展開不被 30 秒刷新覆寫，收合群組再展開後仍維持；再按一次細節按鍵收合', async ($, on) => {
    const { ui, clock } = await startBoard($, on, { files: detailFiles() })
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    await ui.press({ key: groupToggleKey(laneDetailId(laneGroupId(7))) })
    await clock.advance(30_000)
    expect(await detailOf(ui, laneGroupId(7))).toEqual(['351｜in_progress｜實作看板細節', '145｜unknown｜（讀不到 title）'])
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    expect(await detailOf(ui, laneGroupId(7))).toBeUndefined()
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    expect(await detailOf(ui, laneGroupId(7))).toBeDefined()
    await ui.press({ key: groupToggleKey(laneDetailId(laneGroupId(7))) })
    expect(await detailOf(ui, laneGroupId(7))).toBeUndefined()
    expect((await ui.find({ type: 'Button', key: groupToggleKey(laneDetailId(laneGroupId(7))) }))?.text).toBe('▸ 佇列細節')
    await ui.unmount()
  })

  test('對照：佇列票全部完成的線沒有佇列列，也沒有細節按鍵', async ($, on) => {
    const files = detailFiles()
    files[`/repo/${TICKETS_DIR}/0.5.0-W1-351.md`] = ticketFile('completed', '實作看板細節')
    files[`/repo/${TICKETS_DIR}/0.5.0-W1-145.md`] = ticketFile('completed')
    const { ui } = await startBoard($, on, { files })
    await ui.press({ key: groupToggleKey(laneGroupId(7)) })
    await ui.press({ key: groupToggleKey(laneGroupId(13)) })
    expect(await ui.find({ type: 'Button', key: groupToggleKey(laneDetailId(laneGroupId(7))) })).toBeUndefined()
    expect(await ui.find({ type: 'Button', key: groupToggleKey(laneDetailId(laneGroupId(13))) })).toBeDefined()
    await ui.unmount()
  })
})
