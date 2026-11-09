---
id: SPEC-001-history-screen-test-design
title: "SPEC-001 §10 變更記錄畫面 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-001
spec_version: "1.80"
related_specs: [SPEC-003, SPEC-004, SPEC-008]
usecase: UC-07
ticket: 0.7.0-W1-012.4
created: "2026-11-09"
updated: "2026-11-09"
---

# SPEC-001 §10 變更記錄畫面 Phase 2 紅燈測試規格

本文件是第七畫面「變更記錄」的紅燈測試規格：SPEC-001 v1.80 §10 八狀態、SPEC-003 v1.83 §3.9 互動錨點、
SPEC-004 v1.131 元件與 i18n key，以及 UC-07 v1.2 的外圈驗收。供 `0.7.0-W1-012.11`（導覽項與八狀態）與
`0.7.0-W1-012.12`（篩選列、事件清單、跳轉）落地。只描述測資、流程與斷言，不含測試程式碼。

規則權威依序為 SPEC-001 §10（狀態與退出路徑）、SPEC-003 §3.9（錨點與可觀察結果）、SPEC-004（元件與文案 key）；
本文件與其衝突時以規格為準，衝突記入承接票的 NeedsContext。資料管線（掃描、解析、事件、查詢、快取）的單元測試
在 `docs/test-design/SPEC-008-test-design.md`，本文件不重複，只在畫面層驗證其可觀察結果。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | `integration_test/uc07_history_test.dart`：UC-07 主線與六個替代／例外分支（AT-*） | UC-07 驗收終點；pump 真實 app root，只替換 git 程序 | 畫面、notifier、app root 接線、導覽之間的交界斷裂 |
| 5b 內圈 | `test/widget/screens/history/`：八狀態渲染（ST-*）、退出路徑（EX-*）、篩選與事件列（FL-*、EV-*）、跳轉（JP-*）、疊加標示（OV-*）、生命週期（LC-*）、版面（LY-*）、接線（WR-*） | SPEC-001 §10 逐列、SPEC-003 §3.9 逐錨點 | 單一狀態或錨點的規則被打破，可直接定位 |

外圈開發期以 `@Tags(['wip-acceptance'])` 隔離（`dart_test.yaml` skip，`-t wip-acceptance --run-skipped` 觀察紅燈），
012.12 完成時移除 tag，移除 commit 附執行輸出（`.claude/skills/tdd/references/phase2/rules.md`〈外圈紅燈與 100% 綠 gate 的共存〉）。

### 1.2 狀態對應（以 main 上的程式為準）

畫面狀態由 `historyProvider`（`lib/app/history_providers.dart`）的 `HistoryViewState`（`lib/history/application/history_state.dart`）
加上 Domain 視圖就緒度與目前查詢結果衍生：

| SPEC-001 §10 狀態 | 狀態根錨點 | 來源條件 |
|------------------|-----------|---------|
| 專案未就緒 | `state-history-project-unready` | Domain 視圖處於未選專案、載入中、載入失敗或三個阻擋狀態之一（共用定義）；`HistorySchemaBlocked` 亦渲染此狀態（SPEC-008 FR-08 規則 6） |
| 讀取中 | `state-history-loading` | `HistoryLoading` |
| 正常 | `state-history-normal` | `HistoryLoaded`，目前篩選下 `HistoryQuery.run` 結果非空 |
| 期間內無事件 | `state-history-empty` | `HistoryLoaded`，結果為空；`snapshot.hasNoCommit` 為真時為「尚無 commit」變體 |
| 非 git 專案 | `state-history-not-git` | `HistoryNotGitRepo` |
| 找不到 git | `state-history-git-missing` | `HistoryGitNotFound` |
| 讀取失敗 | `state-history-load-failed` | `HistoryFailed` |
| 已取消 | `state-history-cancelled` | `HistoryCancelled` |

`HistoryIdle` 不是畫面狀態：表示尚未進入第七畫面；畫面首次可見時呼叫 `enter()` 使其離開 Idle（LC-1）。

### 1.3 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 八狀態渲染、退出路徑、篩選、事件列、疊加標示（ST、EX、FL、EV、OV、LY） | widget（`test/widget/screens/history/`） | 狀態注入：以 `historyProvider` override 為固定狀態的 fake notifier（記錄 `enter`／`refresh`／`cancel` 呼叫次數），或沿用 `test/widget/harness` 的狀態注入形態；`HistoryScanSnapshot` 以真實值物件構造（Sociable），事件以真實 `EdgeEvent` 構造 |
| 生命週期（LC：首次可見、再次可見、導覽離開、切換專案） | widget，真實 `HistoryNotifier` | git 程序以 `test/helpers/history/fake_process_runner.dart` 經 `historyProcessRunnerProvider` override；`historyScanInputsProvider` 以測試值 override；HEAD 由 fake 的 `rev-parse` 回應控制 |
| 跳轉（JP） | widget，真實 `AppShell` 導覽 | 同上狀態注入；節點詳情以既有 Domain 視圖 fixture 提供圖 |
| app root 接線（WR） | widget，pump 真實 app root（`DocsManagerApp`） | 只替換 git 程序與工作區 repository；**不** override `historyScanInputsProvider` |
| UC-07 外圈（AT） | integration，真實 app root | git 程序以 fake 程序執行器回應（不依賴本機 git 版本）；不 override `historyScanInputsProvider` |

Mock 只替換外部世界（git 程序、時鐘、工作區選取）；History、Schema 值物件與畫面元件一律用真實物件。
時鐘固定為 `2026-11-09T00:00:00Z`（規則 D3），透過查詢的 `clock` 注入。

### 1.4 共用測資

| helper | 路徑 | 用途 | 使用群組 | 建立票 |
|--------|------|------|---------|-------|
| fake 程序執行器 | 沿用 `test/helpers/history/fake_process_runner.dart` | 前置檢查與掃描的回應、暫停、kill 記錄 | LC、WR、AT | 既有（012.5） |
| 合成 git log | 沿用 `test/helpers/history/synthetic_git_log.dart` | 外圈掃描輸出 | AT | 既有（012.6） |
| History 畫面 fixture | `test/helpers/history/history_screen_fixtures.dart` | 下列具名 snapshot 與 fake notifier；只回傳新物件，不共享 mutable 狀態 | ST、EX、FL、EV、OV、JP、LY | 012.11（012.12 擴充事件 fixture） |

**具名 snapshot（`history_screen_fixtures.dart`）**：

| 名稱 | 內容 |
|------|------|
| `snapTagged` | tag `v0.6.0` 指向主線第 3 個 commit；HEAD 之後 2 個 commit；預設期間內 3 筆事件：E0 新增 `uc_ticket_refs`（`UC-07` → `0.7.0-W1-012.11`）、E1 移除 `blockedBy`（`0.7.0-W1-012.11` → `0.7.0-W1-012.9`）、E2 新增 `domain_dependency`（宣告端 `history`，對端 domain 名稱 `schema`）；期間外（tag 之前）1 筆 E3；另含 1 筆 ticket 建檔事件 E4（`isTicketCreation` 為真，期間內） |
| `snapNoTag` | 無 tag；最近 30 天內 1 筆事件、30 天前 1 筆 |
| `snapEmptyDefault` | 有 tag；預設期間內 0 筆、tag 之前 2 筆 |
| `snapAllEmpty` | 有 commit 但全歷史 0 筆事件 |
| `snapNoCommit` | `HistoryScanSnapshot.noCommit` |
| `snapShallow` | 同 `snapTagged`，`isShallow` 為真，邊界 commit 日期 `2026-10-01` |
| `snapDegraded` | 同 `snapTagged`，`isBuiltinTableDegraded` 為真 |
| `snapAbsentNode` | 1 筆移除事件，對端 `0.1.0-W9-999` 不在目前的圖上 |

## 2. 5a 外圈：UC-07（`integration_test/uc07_history_test.dart`）

共同 Given：真實 app root；工作區為 fixture 專案且 Domain 視圖已到達正常；fake 程序執行器回應 git 2.40、
主線 5 個 commit、tag `v0.6.0`、HEAD `h5`，掃描輸出由合成 git log 產生 `snapTagged` 等價事件。

| # | 對應 flow | Given | When | Then |
|---|----------|-------|------|------|
| AT-1 | 主線 enter-history → read-history → review-default-period → open-node | 共同 Given | 點 `nav-item-history`；等待讀取完成；點 `action-history-open-0-declarer` | 先出現 `state-history-loading` 且計數文字可見；之後 `state-history-normal`，期間描述為 `v0.6.0 之後`（zh），事件數 3（不含 E4），列序 E0、E1、E2；點擊後可見頁為 `nav-page-nodeDetail`、主欄為 `UC-07`；返回後回到 `state-history-normal` 且篩選值未變 |
| AT-2 | 主線（快取） | AT-1 完成後導覽到 Domain 視圖再回來，HEAD 不變 | 點 `nav-item-history` | 不出現 `state-history-loading`；fake 記錄掃描程序啟動總數為 1（前置檢查 2 次） |
| AT-3 | change-period | 共同 Given，已在 `state-history-normal` | 點 `option-history-period-all`，再點 `option-history-period-recent30` | 選 all 後事件數 4（含 E3）；選 recent30 後事件數依時鐘計算；整段掃描程序啟動數仍為 1 |
| AT-4 | include-ticket-creation | 同上 | 點 `action-history-include-ticket-created` | 事件數 4，E4 可見；掃描程序啟動數仍為 1 |
| AT-5 | empty-period | fake 掃描輸出等價 `snapEmptyDefault` | 進入第七畫面，讀取完成後點 `action-history-show-all` | 先見 `state-history-empty` 含 `historyEmptyMessage` 與 `action-history-show-all`；點擊後 `option-history-period-all` 為選取、出現 `state-history-normal` 事件數 2 |
| AT-6 | cancel-reading（無結果） | fake 掃描於輸出中段暫停 | 進入第七畫面，`state-history-loading` 時點 `action-history-cancel`，再點 `action-history-reload` | 取消後 fake 記錄 kill 1 次、出現 `state-history-cancelled`、無任何事件列；重新讀取後 `state-history-loading` 出現且計數自 0 起算，完成後 `state-history-normal` |
| AT-7 | cancel-reading（有結果） | AT-1 完成後 HEAD 改為 `h6`、掃描暫停 | 再次進入，`state-history-loading` 時取消 | 回到 `state-history-normal`，事件同 AT-1 結果 |
| AT-8 | history-unavailable（三種） | 三個子案例：fake 前置檢查回「不是工作樹」／「無法啟動」／掃描非 0 結束（stderr `fatal: bad object`） | 進入第七畫面 | 分別出現 `state-history-not-git`、`state-history-git-missing`、`state-history-load-failed`；三者狀態根互異；前兩者有 `action-history-recheck`、第三者有 `action-history-retry` 且顯示 stderr 摘要原文；點出口後出現 `state-history-loading` |
| AT-9 | shallow-clone | fake 前置檢查回淺層、邊界 commit 日期 `2026-10-01` | 進入第七畫面 | `state-history-normal` 內 `badge-history-shallow-clone` 可見，文字含 `2026-10-01`；事件照常列出 |
| AT-10 | 讀取中導覽離開（UC-07 例外場景〈讀取期間取消〉末句） | 掃描暫停 | `state-history-loading` 時點 `nav-item-domain`，解除暫停，再點 `nav-item-history` | fake kill 0 次；回來即見 `state-history-normal`；不出現 SnackBar |

UC-07 驗收條件 ↔ AT：首次才讀取＝AT-1、AT-2；預設期間與標明＝AT-1、FL-3；ticket 建檔切換＝AT-4；
移除事件含兩端不在圖上＝EV-3、JP-3；取消與三種呈現＝AT-6、AT-8、AT-9。

## 3. 5b 內圈：逐群組測試案例

### 3.1 ST 八狀態渲染（承接 012.11）

**測試檔**：`test/widget/screens/history/history_states_test.dart`

| # | Given（注入） | Then |
|---|-------------|------|
| ST-1 | Domain 視圖未選專案（四原因各一子案例） | `state-history-project-unready` 可見；訊息為對應 `projectUnreadyReason*`；`action-history-goto-domain` 可見；篩選列、`action-history-refresh` 不存在 |
| ST-2 | Domain 視圖正常、`historyProvider` 為 `HistorySchemaBlocked` | 渲染 `state-history-project-unready`（型別表阻擋屬此列）；fake 程序執行器呼叫 0 次 |
| ST-3 | `HistoryLoading` | `state-history-loading`；`historyLoading` 文字、`historyLoadingProcessedCount` 計數文字、`action-history-cancel` 可見；篩選列（`option-history-period-*`、`action-history-include-ticket-created`）不存在；進度為 indeterminate（無百分比文字） |
| ST-4 | `HistoryLoaded(snapTagged)` | `state-history-normal`；三個 `option-history-period-*`、`action-history-include-ticket-created`、期間描述、事件數 `3`、`scroll-history-events`、`action-history-refresh` 可見 |
| ST-5 | `HistoryLoaded(snapEmptyDefault)` | `state-history-empty`；`panel-history-empty` 內 `historyEmptyMessage`；`action-history-show-all` 可見；篩選列與 `action-history-refresh` 可見 |
| ST-6 | `HistoryLoaded(snapNoCommit)` | `state-history-empty`；訊息為 `historyNoCommitsMessage`；`action-history-show-all` 不存在；`option-history-period-*` 與 `action-history-include-ticket-created` 不存在；`action-history-refresh` 可見 |
| ST-7 | `HistoryNotGitRepo` | `state-history-not-git`；`historyNotGitMessage`；`action-history-recheck` |
| ST-8 | `HistoryGitNotFound` | `state-history-git-missing`；`historyGitMissingMessage` 與 `historyGitMissingExplanation`；`action-history-recheck` |
| ST-9 | `HistoryFailed`（stderr 摘要 `fatal: bad object h3`） | `state-history-load-failed`；`historyLoadFailedMessage`；說明文字含 `fatal: bad object h3` 原文；`action-history-retry` |
| ST-10 | `HistoryCancelled` | `state-history-cancelled`；`historyCancelledMessage`；`action-history-reload` |
| ST-11（互斥） | 依序注入上列每一狀態 | 每次恰有一個 `state-history-*` 根存在；頁首 `PageTitle` 為 `navHistory` 於八態皆存在；`action-history-refresh` 只在 ST-4、ST-5、ST-6 存在 |
| ST-12（三種降級互異，E2 對照） | ST-7、ST-8、ST-9 的根 | 三者的狀態根 key 互異，且 ST-7、ST-8 皆不出現 `historyLoadFailedMessage` |

### 3.2 EX 退出路徑（FR-01、FR-02，承接 012.11）

**測試檔**：`test/widget/screens/history/history_exit_paths_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| EX-1（FR-01 窮舉） | 八狀態各一 | 列舉 SPEC-003 §3.9〈導航跳轉與退出〉該列的錨點 | 每一錨點存在且可點（enabled）；另 `nav-item-<d>` 與 `project-switcher-entry` 於八態皆存在；每態可用出口數 ≥ 1 |
| EX-2 | 專案未就緒 | 點 `action-history-goto-domain` | 可見頁為 `nav-page-domain`；`returnTo` 為 `history` |
| EX-3（FR-02） | `HistoryLoading`，fake notifier | 點 `action-history-cancel` | `cancel()` 呼叫 1 次；可見頁不變；不出現 SnackBar |
| EX-4 | 正常 | 點 `action-history-refresh` | `refresh()` 呼叫 1 次 |
| EX-5 | 非 git 專案、找不到 git（兩子案例） | 點 `action-history-recheck` | `enter()` 或 `refresh()` 呼叫 1 次（承接票擇一並於 Solution 記錄；斷言為「重新自前置檢查開始」：真實 notifier 下 fake 前置檢查呼叫數 +1） |
| EX-6 | 讀取失敗 | 點 `action-history-retry` | 同 EX-5 |
| EX-7 | 已取消 | 點 `action-history-reload` | 同 EX-5；之後 `state-history-loading` 的計數文字為 0 |
| EX-8（取消目標態） | 真實 notifier；(a) 無先前結果；(b) 先前結果 `snapTagged` 後 HEAD 改變觸發重掃 | 讀取中點 `action-history-cancel` | (a) `state-history-cancelled`；(b) `state-history-normal` 且事件同先前結果 |

### 3.3 FL 篩選列與期間描述（承接 012.12）

**測試檔**：`test/widget/screens/history/history_filter_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| FL-1 | 正常 `snapTagged` | 初始 | `option-history-period-default` 為選取；`action-history-include-ticket-created` 為 unchecked |
| FL-2 | 同上，真實 notifier（fake 程序記錄） | 依序點 `option-history-period-all`、`-recent30`、`-default`、`action-history-include-ticket-created` | 每次點擊後事件數依查詢結果更新（4、依時鐘、3、4）；掃描程序啟動數不增加 |
| FL-3 | `snapTagged`（zh／en 兩子案例） | 初始 | 期間描述 zh 為 `v0.6.0 之後 · 3 筆事件`，en 為 `Since v0.6.0 · 3 events`；**不**出現 `HistoryPeriod.description` 的中文字面於 en |
| FL-4 | `snapNoTag` | 初始 | 期間描述為 `historyPeriodRecent30Label` 組字 |
| FL-5 | `snapTagged` | 點 `option-history-period-all` | 期間描述為 `historyPeriodAllLabel` 組字 |
| FL-6（E1 對照） | `snapTagged` | 比較切換前後 | include 關閉時列中無 E4、開啟時有 E4；兩次結果不同 |
| FL-7 | 正常 → 篩選後結果空 | `snapTagged`，選 recent30 且時鐘使所有事件落在 30 天外 | 狀態根由 `state-history-normal` 轉為 `state-history-empty`；篩選列仍在 |
| FL-8 | 期間內無事件 `snapEmptyDefault` | 點 `action-history-show-all` | `option-history-period-all` 為選取；`state-history-normal` 事件數 2 |
| FL-9 | `snapAllEmpty` | 點 `action-history-show-all` | 維持 `state-history-empty`；`action-history-show-all` 仍可見 |
| FL-10 | 正常，`scroll-history-events` 已捲動 | 變更期間 | offset 歸零 |
| FL-11 | 正常，篩選已改為 all + include | 點 `action-history-refresh` 至完成 | 完成後篩選值仍為 all + include |

### 3.4 EV 事件列（承接 012.12）

**測試檔**：`test/widget/screens/history/history_event_row_test.dart`

| # | Given | Then |
|---|-------|------|
| EV-1 | `snapTagged` | 表頭七欄 `columnChange`…`columnAuthorMessage`；列 0 為 E0：變動 `historyEventAdded`（tone positive）、邊型原值 `uc_ticket_refs`、宣告端 `UC-07`、對端 `0.7.0-W1-012.11`、commit 短 hash、日期 `yyyy-MM-dd`、`historyEventAuthorMessage` 組字 |
| EV-2 | 同上 | 列序依主線新到舊：E0、E1、E2；`<index>` 自 0 起算 |
| EV-3 | 同上，列 1 | 變動為 `historyEventRemoved`（tone negative）；`action-history-open-1-declarer` 與 `-counterpart` 皆存在 |
| EV-4（domain_dependency 對端不可點） | 同上，列 2 | `action-history-open-2-declarer` 存在；`action-history-open-2-counterpart` **不存在**；對端格顯示純文字 `schema` |
| EV-5（E2 對照） | 同上 | 列 0、列 1 的 counterpart 錨點存在（證明 EV-4 的不存在不是整欄皆無錨點） |
| EV-6 | 同上 | 每列 Semantics label 為 `historyEventA11yLabel` 組字，含完整值 |
| EV-7 | 篩選改為 include | `<index>` 重新編號：新增的 E4 依主線位置插入，後續列 index 位移 |

### 3.5 JP 跳轉節點詳情（承接 012.12）

**測試檔**：`test/widget/screens/history/history_jump_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| JP-1 | 正常 `snapTagged`，節點在圖上 | 點 `action-history-open-0-declarer` | 可見頁 `nav-page-nodeDetail`；jump payload 為 `UC-07`；`returnTo` 為 `history` |
| JP-2 | 同上 | 點 `action-history-open-1-counterpart` 後返回 | 主欄為 `0.7.0-W1-012.9`；返回後可見頁為 `nav-page-history`，篩選與捲動 offset 保留 |
| JP-3 | `snapAbsentNode` | 點 `action-history-open-0-counterpart` | `state-nodeDetail-node-absent` 可見 |

### 3.6 OV 疊加標示（承接 012.11）

**測試檔**：`test/widget/screens/history/history_overlay_badges_test.dart`

| # | Given | Then |
|---|-------|------|
| OV-1 | `snapShallow`，正常 | `badge-history-shallow-clone` 可見，位於篩選列上方，文字為 `historyShallowCloneBadge` 代入 `2026-10-01`；不可點（無 tap 回應） |
| OV-2 | `snapShallow`，篩選至空 | `state-history-empty` 內同一標示可見 |
| OV-3（E2 對照） | `snapTagged`（非淺層） | `badge-history-shallow-clone` 不存在 |
| OV-4 | 淺層資訊存在但狀態為讀取中、非 git、找不到 git、讀取失敗、已取消、專案未就緒 | 標示不存在 |
| OV-5 | 淺層加入不增加狀態 | OV-1 下 `state-history-*` 根恰一個且為 `state-history-normal` |
| OV-6 | `snapDegraded` | `badge-history-degraded-schema` 依 §2.4 殼層通則可見；`snapTagged` 時不存在 |

### 3.7 LC 生命週期（承接 012.11）

**測試檔**：`test/widget/screens/history/history_lifecycle_test.dart`（真實 `HistoryNotifier`，fake 程序執行器）

| # | Given | When | Then |
|---|-------|------|------|
| LC-1 | 工作區就緒，停在 Domain 視圖 | 不進入第七畫面 | fake 程序呼叫 0 次；`historyProvider` 為 `HistoryIdle` |
| LC-2 | 同上 | 點 `nav-item-history` | 自動進入 `state-history-loading`；前置檢查 1 次 |
| LC-3 | 專案未就緒 | 點 `nav-item-history`；之後 Domain 視圖到達正常 | 前者 git 0 次、`state-history-project-unready`；後者自動開始讀取 |
| LC-4 | 已有結果，前置檢查暫停 | 導覽離開後再次可見 | 前置檢查期間維持 `state-history-normal`，不出現 `state-history-loading` |
| LC-5 | 讀取中 | 導覽離開再回來 | kill 0 次；回來時顯示進度或結果；無 SnackBar、無系統通知呼叫 |
| LC-6 | 正常，篩選 all + include、已捲動 | 導覽離開再回來 | 篩選與 offset 保留 |
| LC-7 | 讀取中，篩選已改 | 切換專案 | kill 1 次；結果清除；篩選回到 default + 未勾選；新專案可見時依首次可見判定 |
| LC-8 | 正常 | 視窗回到前景（`AppLifecycleState.resumed`） | 前置檢查呼叫數不變 |

### 3.8 LY 版面與語系（承接 012.11、012.12 各自畫面部分）

**測試檔**：`test/widget/screens/history/history_layout_test.dart`

| # | Given | Then |
|---|-------|------|
| LY-1 | 八狀態 × zh／en × 視窗最小尺寸 960×640 | 無 overflow 例外（`tester.takeException()` 為 null） |
| LY-2 | 正常，事件含 `TestCopy.longToken` 作者與訊息、長邊型 | 欄寬對齊表頭、超長值截斷不溢位；完整值存在於 Semantics label |
| LY-3 | 期間 SegmentedControl en 三段 | 不溢位 |

### 3.9 WR app root 接線（承接 012.11）

**測試檔**：`test/widget/app/history_wiring_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| WR-1 | pump 真實 app root（不 override `historyScanInputsProvider`），工作區 fixture 專案已就緒、Schema 正常；git 以 fake 程序執行器 | 點 `nav-item-history` | 不拋 `UnimplementedError`（`tester.takeException()` 為 null）；出現 `state-history-loading` 或其後續狀態 |
| WR-2 | 同上，Schema 為內建型別表降級 | 進入並完成讀取 | `badge-history-degraded-schema` 可見（證明 schemaReadiness 取自實際 Schema 狀態，非固定值） |
| WR-3 | 同上，Schema 為「無可消費的型別表」阻擋 | 點 `nav-item-history` | `state-history-project-unready`；fake 程序呼叫 0 次 |
| WR-4（E2 正向對照） | 以不含 history override 的最小 `ProviderContainer` 讀 `historyScanInputsProvider` | 讀取 | 拋 `UnimplementedError`（證明 WR-1 的綠燈來自接線而非 provider 有預設值） |
| WR-5 | 導覽列 | 初始 | `NavItem` 共 7 項，`nav-item-history` 為第七項，Tab 順序依 SPEC-003 §2.10 |

## 4. 覆蓋矩陣

### 4.1 SPEC-001 §10 狀態 ↔ 測試

| 狀態 | 渲染 | 退出路徑 | 其他 |
|------|------|---------|------|
| 專案未就緒 | ST-1、ST-2 | EX-1、EX-2 | LC-3、WR-3 |
| 讀取中 | ST-3 | EX-1、EX-3、EX-8 | LC-2、LC-5、AT-6、AT-10 |
| 正常 | ST-4 | EX-1、EX-4、JP-1 | FL-*、EV-*、AT-1 |
| 期間內無事件 | ST-5、ST-6 | EX-1、FL-8、FL-9 | AT-5 |
| 非 git 專案 | ST-7 | EX-1、EX-5 | AT-8 |
| 找不到 git | ST-8 | EX-1、EX-5 | AT-8 |
| 讀取失敗 | ST-9 | EX-1、EX-6 | AT-8 |
| 已取消 | ST-10 | EX-1、EX-7 | AT-6 |

票面驗收「淺層標示、尚無 commit 變體、domain_dependency 對端不可點」：OV-1～OV-5、ST-6、EV-4（+EV-5 對照）。

### 4.2 UC-07 flow ↔ 外圈

| flow id | 類別 | 外圈 |
|---------|------|------|
| enter-history、read-history、review-default-period、open-node | 主線 | AT-1、AT-2 |
| change-period | 替代 | AT-3 |
| include-ticket-creation | 替代 | AT-4 |
| empty-period | 替代 | AT-5 |
| cancel-reading | 例外 | AT-6、AT-7、AT-10 |
| history-unavailable | 例外 | AT-8 |
| shallow-clone | 例外 | AT-9 |

### 4.3 SPEC-003 §3.9 錨點 ↔ 測試

| 錨點 | 測試 |
|------|------|
| `action-history-goto-domain` | EX-2 |
| `action-history-cancel` | EX-3、EX-8、AT-6、AT-7 |
| `option-history-period-<period>` | FL-1、FL-2、FL-5、AT-3 |
| `action-history-include-ticket-created` | FL-2、FL-6、AT-4 |
| `action-history-refresh` | EX-4、FL-11 |
| `action-history-show-all` | ST-5、ST-6、FL-8、FL-9、AT-5 |
| `action-history-recheck` | EX-5、AT-8 |
| `action-history-retry` | EX-6、AT-8 |
| `action-history-reload` | EX-7、AT-6 |
| `action-history-open-<index>-<side>` | EV-3、EV-4、JP-1～JP-3、AT-1 |
| `scroll-history-events` | FL-10、LC-6 |
| `badge-history-shallow-clone` | OV-1～OV-5、AT-9 |

## 5. 測試案例統計

| 群組 | 案例數 | 承接票 |
|------|-------|-------|
| AT | 10 | 012.12（移除 wip tag） |
| ST | 12 | 012.11 |
| EX | 8 | 012.11 |
| FL | 11 | 012.12 |
| EV | 7 | 012.12 |
| JP | 3 | 012.12 |
| OV | 6 | 012.11 |
| LC | 8 | 012.11 |
| LY | 3 | 012.11（八狀態）、012.12（事件列） |
| WR | 5 | 012.11 |

## 6. 案例 ↔ 實作票對照與拆分

| 承接票 | 群組 | 跨群組依賴 |
|-------|------|----------|
| 0.7.0-W1-012.11 畫面八狀態 | ST、EX、OV、LC、WR、LY-1；helper `history_screen_fixtures.dart`（snapshot 與 fake notifier） | 需 012.9 的 notifier 與 012.10 的元件；WR 為必接線 provider `historyScanInputsProvider` 的 app root wiring 驗收 |
| 0.7.0-W1-012.12 事件清單 | FL、EV、JP、LY-2、LY-3、AT；擴充 fixture 事件 | 需 012.11 的狀態根與清單容器；AT 需 012.11 的 app root 接線（WR 綠） |

每個群組的測試檔獨立，僅透過 §1.4 helper 取得 fixture；承接票只需讀本文件 §1 與對應小節。

## 7. 設計判斷與待決

| # | 判斷 | 理由 |
|---|------|------|
| J-1 | `HistorySchemaBlocked` 渲染為「專案未就緒」（ST-2、WR-3） | SPEC-001 §10 將型別表阻擋歸入專案未就緒列；main 的 notifier 另有此狀態值，畫面層合併呈現 |
| J-2 | EX-5～EX-7 的斷言以「前置檢查呼叫數 +1」表達，不指定 `enter()` 或 `refresh()` | SPEC-003 §3.9 只規定「自前置檢查重新開始」；快取在這三態已被清空，兩方法的可觀察結果相同 |
| J-3 | 外圈 git 用 fake 程序執行器 | 真實 git 行為已由 SPEC-008 RG 覆蓋；外圈目的是畫面與接線交界 |
| G-1（程式缺口） | ST-9、AT-8 需 stderr 摘要原文，但 main 的 `HistoryFailed` 只帶 `GitFailureReason`，不帶 `stderrSummary` | SPEC-001 §10、SPEC-004 `historyLoadFailedDetail` 要求原因摘要；承接票 012.11 實作時需由 012.9 範圍補欄位或另票，非規格衝突 |
| G-2（程式缺口） | OV-1、AT-9 需淺層邊界日期，但 `HistoryScanSnapshot` 只有 `isShallow` | SPEC-003 §3.9、SPEC-004 `historyShallowCloneBadge` 的 `boundaryDate` 無資料來源 |
| G-3（程式缺口） | ST-3、AT-6 需已處理 commit 數，但 `HistoryLoading` 不帶計數 | SPEC-001 §10 讀取中顯示「已處理的 commit 數」 |

G-1～G-3 為測試設計發現的實作缺口，依規則 5 由 PM 建票；本文件斷言依規格撰寫，不因缺口降級。
