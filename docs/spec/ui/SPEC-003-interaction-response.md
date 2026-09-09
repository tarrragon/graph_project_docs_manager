---
id: SPEC-003
title: "互動反應規格：七畫面的反應、動畫、導航與生命週期"
status: draft
source_proposal: PROP-004
created: "2026-09-01"
updated: "2026-09-09"
version: "1.13"
owner: star-anise-system-designer

domain: "ui"
subdomain: null

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06]
related_specs: [SPEC-001, SPEC-002]
implements_requirements: []
depends_on_domains: [workspace, schema, corpus, graph, ticketdetail, layout, diagnostics]
---

# 互動反應規格：七畫面的反應、動畫、導航與生命週期

## 概述

SPEC-001 界定七個畫面的 31 個狀態「是什麼、怎麼進、怎麼出」；本規格界定
**使用者做了動作之後系統怎麼反應**，涵蓋四類行為：

| 類別 | 界定什麼 |
|------|---------|
| 互動反應 | 每個可點、可捲、可拖的元素，觸發後的可觀察結果 |
| 動畫提示 | 狀態之間的轉場形式與時間值、等待期間的指示形式 |
| 導航跳轉與退出 | SPEC-001 每個退出路徑對應的導航動作、來源記錄與返回目標 |
| 生命週期 | 畫面建構時機、狀態保留與重置、進行中任務的存續 |

### 撰寫判準：條件欄與可觀察結果欄皆為斷言

本規格各表格的「條件」欄與「可觀察結果」欄（含同義欄名，如「觸發」「退出動作 →
目標」）一律寫成「**明確條件 + 可觀察結果**」，使整合測試可直接引用而不需再次
判讀。凡是無法指出斷言對象的措辭（適當、流暢、合理、良好體驗）皆不出現於這兩類
欄位。

**適用範圍不含依據／理由欄**：「依據」「理由」「不採／採用理由」等說明性欄位
（例如 §2.1 時間 token 表的依據欄、§5 判讀註記表）記錄的是決策脈絡而非斷言
對象，不受本判準約束，得使用一般論述語言。

可觀察結果取以下四種形式，涵蓋本規格全部驗收（FR-01～FR-15）：

| 形式 | 範例 |
|------|------|
| 元件樹結構 | 存在性：`find.byKey(Key('state-domain-unset'))` 為 `findsOneWidget`；屬性：該按鈕的 `enabled` 為 `false`、該文字為 `l10n.cancelLoadingAction`；幾何關係：該泳道列的 rect 與 viewport rect 有交集 |
| 狀態容器值 | `ref.read(returnToProvider)` 的值等於 `AppDestination.ucFlow`（見 §2.3） |
| 靜態原始碼掃描 | `lib/`（`lib/tokens/` 除外）不出現 `Duration(milliseconds:` 或 `Duration(seconds:` 後接字面數字（FR-05，見 §2.1 硬規則） |
| 外部程序呼叫 | 開啟系統資料夾選擇器 / 開啟原始檔 / 開啟 docs 目錄等外部程序已被呼叫一次，以 fake 呼叫紀錄斷言，不驗證外部程式本身行為（FR-06） |

### 邊界：不涉視覺樣式

顏色、字級、間距、圓角屬 SPEC-002 的 token 層（已由 `0.1.0-W1-004` 定案），
本規格一律不述。本規格定義的**時間值**不屬視覺樣式——它是互動契約的一部分
（「按下取消後多久內抵達目標態」是行為，不是外觀），但仍須依 SPEC-002 的
唯一硬規則具名，見 §2.1。

---

## 1. 全域互動盤點

PROP-004 §首個整合測試的契約 要求斷言「應可捲動處能捲動、應可換頁處能換頁、
應可拖拉處能拖拉」。該句的三個「處」在本節窮舉——**清單之外沒有第四處**，
整合測試依此枚舉即為完整覆蓋。

### 1.1 捲動處（11 個）

| # | 位置 | 錨點 | 軸 | 備註 |
|---|------|------|----|------|
| 1 | Domain 視圖 · 矩陣 | `scroll-domain-matrix` | 水平 + 垂直 | 二維捲動，委派 `two_dimensional_scrollables` |
| 2 | Domain 視圖 · 泳道 | `scroll-domain-swimlane` | 水平 + 垂直 | 與 #10 的拖曳作用於同一內容 |
| 3 | UC Flow · 正常 | `scroll-ucFlow-steps` | 垂直 | 垂直步驟表 |
| 4 | 追溯視圖 | `scroll-traceability-tree` | 垂直 | 樹狀展開後可能超出視高 |
| 5 | Ticket 清單 · 列表 | `scroll-tickets-list` | 垂直 | 虛擬捲動 |
| 6 | Ticket 清單 · 主題 | `scroll-tickets-topics` | 垂直 | 主題節 + 未歸屬節 |
| 7 | 破洞報告 | `scroll-gaps-sections` | 垂直 | 依類別分節 |
| 8 | 節點詳情 · 主欄 | `scroll-nodeDetail-content` | 垂直 | 與 #9 各自獨立 |
| 9 | 節點詳情 · 關聯右欄 | `scroll-nodeDetail-relations` | 垂直 | 不與主欄連動 |
| 10 | 專案切換浮層 | `scroll-switcher-recent` | 垂直 | 最近專案清單 |
| 11 | Domain 視圖 · 矩陣右欄格詳情卡 | `scroll-domain-cell-detail` | 垂直 | 與 #1 各自獨立；步驟清單為異常長內容時的承載處 |

**斷言形式**：對錨點執行 `tester.drag(finder, Offset(dx, dy))` 後
`pumpAndSettle()`，該容器的 `ScrollController.offset` 與拖曳前不相等；
內容不足一屏時 offset 維持 0 且不得拋出 framework 錯誤。

**捲動連動禁令**：#8 與 #9 是兩個獨立 `ScrollController`。捲動主欄時右欄
offset 不變，反之亦然。#1 與 #11 同此禁令：捲動矩陣時格詳情卡 offset 不變，
反之亦然。

### 1.2 換頁處（3 類）

| 類別 | 錨點 | 可觀察結果 |
|------|------|-----------|
| 六項導覽切換 | `nav-item-<destination>`（既有，`AppDestination.name`） | `nav-page-<destination>` 成為 `IndexedStack` 的可見頁 |
| Domain 視圖雙模式 | `mode-domain-matrix` / `mode-domain-swimlane` | `state-domain-matrix` 與 `state-domain-swimlane` 互斥存在 |
| Ticket 清單雙模式 | `mode-tickets-list` / `mode-tickets-topic` | `state-tickets-list` 與 `state-tickets-topic` 互斥存在 |

樹狀節點的展開收合、schema 詳情面板的展開收合**不是換頁**——它們不改變
`IndexedStack` 索引也不改變狀態錨點，歸入 §1.4 的同畫面內展開。

### 1.3 拖拉處（1 個）

**全 App 唯一的拖曳互動是 Domain 視圖泳道模式的畫布平移**，錨點
`drag-domain-swimlane`。

| 項目 | 規格 |
|------|------|
| 觸發 | 於畫布區域按下並移動（`tester.drag`） |
| 反應 | 內容平移量等於拖曳位移，比例 1:1，無額外縮放係數 |
| 邊界 | 平移至內容邊界時停止，不做橡皮筋回彈——此為自訂拖曳手勢（非原生 `NSScrollView`）；macOS 原生捲動元件雖預設具彈性回彈，但本規格明示採生硬停止，理由是彈性動畫的中間態難以用固定幀斷言驗證（見 §撰寫判準），屬本規格的明示決定，非沿用平台慣例 |
| 與捲動的關係 | 拖曳與捲軸作用於同一個 offset；拖曳後捲軸位置同步改變 |
| 慣性 | 0.1 不做拋擲慣性；放開手指即停止 |

節點卡、矩陣格、樹節點、ticket 列皆**不可拖曳**（0.1 無排序與重新配置功能）。
對這些元素執行 drag 的預期結果是「觸發所在容器的捲動」，不是元素本身移動。

### 1.4 同畫面內展開（3 個）

| 位置 | 錨點 | 展開後 | 收合方式 |
|------|------|--------|---------|
| 追溯樹節點 | `expander-traceability-<nodeId>` | 子層節點出現於樹中 | 再次點擊同一錨點 |
| schema 不相容詳情 | `action-domain-schema-detail` → `panel-domain-schema-detail` | 面板出現於同一狀態根節點內 | 再次點擊、或按 Esc |
| 篩選下拉選單 | `action-tickets-filter-<key>` → `menu-tickets-filter-<key>` | 選單以覆蓋層出現於觸發器正下方，不擠壓版面（§3.4 F4） | 選取選項、再次點擊觸發器、Esc、Tab、點選單外部（§3.4 篩選各列） |

展開收合不改變狀態錨點，也不改變 `returnTo`（§2.4）。

---

## 2. 通用機制

以下機制先在此定義一次，§3 各畫面直接引用，不重複敘述。

### 2.1 時間 token

SPEC-002 的唯一硬規則要求所有值先具名。時間值同樣適用，落點
`lib/tokens/motion.dart`，類名 `Motion`，型別 `Duration`。

| token | 值 | 類別 | 用途 | 依據 |
|-------|-----|------|------|------|
| `Motion.feedback` | 100 ms | 契約 | 點擊確認的出現上限 | 100 ms 為知覺「操作立即生效」的上限，同時是「幾乎即時帶」（100–400 ms，見下）下界；本規格以此訂為點擊回饋必須可見的時限 |
| `Motion.transition` | 150 ms | 動畫 | 狀態之間的 cross-fade | 落在「幾乎即時帶」（100–400 ms）內，以動畫掩蓋切換 |
| `Motion.overlay` | 200 ms | 動畫 | 浮層展開與收合 | 同上，浮層位移距離大於狀態淡入故取較長值 |
| `Motion.spinnerMinVisible` | 300 ms | 契約 | 指示一旦顯示的最短停留 | 避免載入極快時指示器一閃即逝造成視覺跳動，訂為固定下限（本規格決定，非引用外部研究值） |
| `Motion.cancelDeadline` | 500 ms | 契約 | 按下取消後抵達目標態的上限 | 訂於 400 ms–1 s 之間，權衡「系統過慢打斷操作連續感」與「等待過久使用者失去專注」兩種風險；具體數值為本規格權衡後的決定，非引用特定研究值 |
| `Motion.progressTick` | 200 ms | 契約 | 進度計數文字的最小更新間隔 | 高於此頻率的數字跳動不可讀 |
| `Motion.skeletonCycle` | 1200 ms | 動畫 | 骨架 shimmer 的循環週期 | 一屏內可辨識為「持續進行」而不干擾閱讀 |
| `Motion.snackBar` | 4 s | 契約 | 純告知型 SnackBar 停留 | Flutter Material `SnackBar` 元件的預設顯示時長（4000 ms），本規格沿用不覆寫 |
| `Motion.snackBarWithAction` | 8 s | 契約 | 帶動作 SnackBar 停留 | 需讀完再決定是否按，較純告知型加倍 |
| `Motion.searchDebounce` | 300 ms | 契約 | 搜尋輸入停止後至觸發過濾的等待 | 避免逐字元觸發造成的畫面閃爍與重複運算，訂為輸入停頓後的防抖動延遲 |

**硬規則**：`lib/` 之下（`lib/tokens/` 除外）不得出現 `Duration(milliseconds: <字面數字>)`
或 `Duration(seconds: <字面數字>)`。此檢查可機械化，與 SPEC-002 FR-01 同一條 CI 規則擴充。

**減少動態效果（依類別判定，非逐一枚舉）**：`MediaQuery.disableAnimationsOf(context)`
為 `true` 時，類別為「動畫」的 token（`Motion.transition`、`Motion.overlay`、
`Motion.skeletonCycle`）一律視為 `Duration.zero`，shimmer 改為靜態灰塊；類別為
「契約」的 token 恆不歸零——它們是行為時限承諾（多久內必須抵達、最短停留多久、
輸入後多久觸發過濾），與視覺呈現無關，使用者選擇減少動態效果不代表放棄這些
行為保證。新增 token 時只需歸類「動畫」或「契約」，disableAnimations 下的行為
即由本段規則推導，不需逐一列舉例外。

### 2.2 三層回饋的落地

| 層 | 承擔者 | 本 App 的落地 | 斷言 |
|----|--------|--------------|------|
| 點擊確認 | 互動元件自身 | 一律使用 Material `InkWell` / `Button` 的內建 pressed 態，不自繪 | 元件樹中該互動元素被 `InkWell` 或 `ButtonStyleButton` 包覆 |
| 等待指示 | 服務（受理與處理中） | 畫面級載入態（§2.6），不使用按鈕內 spinner | 對應 `state-*-loading` / `state-gaps-scanning` 錨點存在 |
| 結果通知 | event 處理路徑（狀態轉換與結果回饋） | 狀態轉換本身為主；狀態不變的動作（外部開啟、重新整理無變化）用 SnackBar | SnackBar 文字等於指定 i18n key 的值 |

**承擔者欄的用途**：本表原本只回答「三層各是什麼形式」，不回答「誰保證它出現」。
形式與承擔者是兩個軸，缺了後者就無法判斷某一層失落時該追究哪一層。§2.12 的政策
對照表以服務類型為自變數，逐類型指定三層各給什麼——兩表以本欄對接：本表定承擔
者，§2.12 定各承擔者在各服務類型下的具體政策。

**第一層不因服務狀態而免除。** 點擊確認由互動元件自身承擔，其觸發條件不得包含
任何服務狀態——服務不可用、服務未受理、或呼叫被防抖／節流／冪等丟棄，皆不構成
不出現 pressed 態的理由。此即 §2.12 的不變式 INV-FEEDBACK-001。

**禁止**：任何可點元素在 0.1 以「無回饋佔位 handler」上線。未接線的動作只有
兩種合法形態——(a) 不渲染該元素；(b) 渲染為 `enabled: false` 並在同一列以
常駐文字（非 tooltip）說明原因。見 FR-06。

#### 外部開啟契約（`0.1.0-W1-036` 定案：0.1 落地）

§3.1 開啟 docs 目錄、§3.2 與 §3.6 開啟原始檔、§3.5 破洞項四處的外部開啟動作
在 0.1 **落地**，共用同一個可注入的抽象；四處的互動反應表只引用結果值，不各自
描述實作。實作票 `0.1.0-W1-068`。

| 項目 | 契約 |
|------|------|
| 介面 | `abstract class ExternalOpener { Future<ExternalOpenResult> open(String path); }`；`enum ExternalOpenResult { opened, notFound, failed }`。檔案與目錄走同一入口 |
| 前置檢查 | 呼叫端傳入絕對路徑；實作先以 `FileSystemEntity.type(path)` 判定，`notFound` 時**不呼叫外部程序**即回傳（不依賴外部程序的錯誤文字判別檔案不存在） |
| 實作（macOS） | `Process.run('/usr/bin/open', [path])`；`exitCode == 0` → `opened`，否則 `failed`（含「無應用程式能開啟」`kLSApplicationNotFoundErr` 與其他失敗）。不新增第三方依賴：`url_launcher_macos` 等價於 `NSWorkspace.open(URL)`，回傳同為成功／失敗二值，無額外資訊 |
| 失敗可觀測 | `failed` 時以 `developer.log`（warning 等級）記錄 stderr 與路徑（observability 規則 5），畫面以 SnackBar `externalOpenFailedMessage` 回饋，不阻擋、不轉狀態 |
| 等待指示 | 呼叫期間**不顯示**等待指示：實測回傳在 600 ms 內（本機 200–550 ms），點擊確認由 `InkWell` pressed 態承載；§2.6「0.1 無非狀態級短暫等待」的結論不變。SnackBar 於結果返回後出現 |
| 行號定位 | 0.1 **不定位至行號**：`open` 無行號參數，定位需依使用者編輯器的專屬 URL scheme（如 `vscode://file/<path>:<line>`），涉及編輯器偵測，追蹤票 `0.1.0-W1-070` |
| 測試斷言 | 整合測試注入 fake（記錄 `calls: List<String>`），斷言路徑與呼叫次數恰一次（概述表「外部程序呼叫」列）；`opened` / `notFound` / `failed` 三個結果由 fake 指定回傳值，逐一斷言對應的 SnackBar 或狀態轉換 |
| i18n | 既有：`openedExternallyMessage`、`sourceFileNotFoundSnackbarMessage`、`refreshAction`、`rescanAction`；新增：`externalOpenFailedMessage`（zh「無法以系統預設方式開啟」/ en「Could not open with the default application」），補齊票 `0.1.0-W1-069` |

實測依據（macOS 26.5 / Flutter 3.47.1 / 沙盒關閉）：`open <file>`、`open <dir>` 皆
`exit=0`；不存在路徑 `exit=1`（stderr「does not exist」）；無應用程式對應的副檔名
`exit=1`（stderr `kLSApplicationNotFoundErr`）。完整紀錄見 `0.1.0-W1-036` 重現實驗結果。

#### 系統層通知（`0.1.0-W3-063` 定案：0.1 落地，用戶簽核 2026-09-08）

結果通知層的第三種載體。§2.2 表「結果通知」列的兩種形式（狀態轉換本身、SnackBar）
都以**視窗在前景且觸發畫面可見**為前提；破洞掃描（§3.5）是 0.1 唯一會在使用者離開
畫面後仍持續並自行完成的長時操作（§2.8 L1），其完成時使用者可能已切至其他導覽項或
切到別的應用程式，App 內任何通道都不在視線範圍，故升級為 macOS 系統通知——這是
唯一能跨越 App 視窗邊界的結果通知通道。判準來源：ux-design-evaluation
〈結果通知的形式選擇〉「操作成功、結果不在視線範圍」列，與〈gate-fallback〉權限
gate 的成功／失敗／不確定三問。SPEC-004 §1 回饋通道子表 state-change 列引用本節。

**適用範圍**：0.1 僅破洞掃描完成一處。Domain 視圖載入與 Ticket 載入不升級：兩者
的完成落點就是使用者觸發時停留的畫面，離開後回來即見結果，且 SPEC-001 未定義
其完成需喚回使用者。擴充至其他事件須另經用戶簽核，不由實作票自行擴充。

| 項目 | 契約 |
|------|------|
| 觸發條件 | `state-gaps-scanning` 轉換至 `state-gaps-none` 或 `state-gaps-found` 的當下，**且**下列任一成立：(a) 視窗非前景——`AppLifecycleState` 不為 `resumed`；(b) 目前可見頁不是 `nav-page-gaps`——`selectedDestinationProvider` 的值不為 `AppDestination.gaps`。兩者皆不成立（使用者正看著破洞報告）時**不發送**，狀態轉換本身即結果 |
| 不發送 | 掃描被取消（§2.5 C5：取消完成不通知）；切換專案中止掃描（§2.8 L2）；掃描未抵達完成態；同一次掃描結果已發送過（見「不重複發送」列） |
| 通知內容 | 標題 `scanCompleteNotificationTitle`；內文依結果二擇一：`state-gaps-found` → `scanCompleteNotificationBody`（placeholder `count`，型別 `int`，值為破洞總數）、`state-gaps-none` → `scanCompleteNoGapsNotificationBody`。不含檔案路徑、不含逐項明細（明細由畫面承載；含關鍵資訊的結果不走自動消失的通道）；不附通知動作按鈕，唯一互動是點擊通知本體 |
| 點擊通知的導向 | 系統將 App 帶到前景後，App 執行 rail 語意切換至 `nav-page-gaps`（`returnTo` 設為 `null`，§2.3 規則 1），並依 SPEC-004 §1 回饋通道子表 locate 列定位：`state-gaps-found` → `scroll-gaps-sections` scroll-into-view 至第一個分節的第一個 `card-gaps-<itemId>` 並短暫高亮、焦點移入該項（高亮 token 與時長由 SPEC-004 第 4 章對應容器條目定義）；`state-gaps-none` → 焦點移入 `state-gaps-none` 根節點，不高亮。點擊時若已進入新一輪 `state-gaps-scanning`，只切頁、顯示當時進度、不定位；若專案已切換（結果已清空），只切頁、不定位 |
| 不重複發送 | 每一次掃描完成至多發送一則；同一結果不因視窗前景／背景往返而再發。以下事件由 App 撤回尚未被點擊的通知：使用者自行回到 `nav-page-gaps`（結果已被看見）、新一輪掃描開始（舊結果已判定待汰換，與 §3.5「重新掃描」列同一理由）、切換專案（§2.8 L2）。撤回失敗不阻擋、不轉狀態，只記 log |
| 權限 gate | 見下方三路徑表。授權狀態於**每次**觸發條件成立時重新查詢（使用者可在系統設定隨時改動，不快取上一次結果） |
| 等待指示 | 發送與撤回期間不顯示任何等待指示：兩者皆為非同步旁路動作，不改變畫面狀態，畫面已依 §3.5 完成掃描中 → 結果的 cross-fade |
| 可觀測性 | 授權查詢入口與結果、授權請求入口與結果、發送與撤回的入口與成功／失敗，皆以 `developer.log`（info；失敗為 warning）記錄，含破洞總數與觸發原因（非前景／已離開頁）（observability 規則 5：權限 check／request 與平台 API 呼叫逐點記錄） |

**權限 gate 三路徑**（gate-fallback：每道 gate 必答成功／失敗／不確定）：

| 授權狀態 | 分類 | App 行為 | fallback |
|---------|------|---------|----------|
| `granted` | 成功 | 發送系統通知 | 不適用 |
| `denied`（使用者拒絕請求，或事後於系統設定關閉） | 失敗 | 不發送、**不再請求**（系統不會再彈對話框）；0.1 **不引導至系統設定**——App 無設定畫面可承載入口，SPEC-001 亦無對應狀態 | App 內 SnackBar `AppSnackBar.withAction`：文字 `scanCompleteSnackbarMessage`（placeholder `count`；無破洞時 `scanCompleteNoGapsSnackbarMessage`），動作 `viewGapsAction`，停留 `Motion.snackBarWithAction`；動作觸發等同「點擊通知的導向」列。顯示時機：視窗在前景且可見頁不是 `nav-page-gaps` → 立即；視窗非前景 → **延後至視窗下一次回到 `resumed`** 時顯示（SnackBar 會自動消失，背景時顯示等於沒顯示）；回到前景前使用者已自行進入 `nav-page-gaps` → 不顯示。持續性的 App 內指示（Banner、導覽項徽章）0.1 **不提供**：SPEC-004 元件庫無 Banner、`NavItem` 無徽章 slot，依元件庫優先原則不就地發明；是否補元件由 `0.1.0-W3-063` spawn request 交 PM 核定 |
| `notDetermined` | 不確定（尚未詢問） | 於**首次**觸發條件成立的當下請求授權（功能使用時即時請求，使用者剛經歷一次「離開後掃描才完成」的情境，理解為何需要）；**不**於 App 啟動時請求、不於掃描開始時請求。請求回覆 `granted` → 立即補發本次通知；回覆 `denied` → 本次即走 `denied` 列的 fallback | 請求對話框由系統呈現，App 不另加前置說明畫面（0.1 唯一權限，且請求時機已在操作 context 內） |
| 其他（`provisional`、查詢或請求逾時／拋錯、API 不可用） | 不確定（結果未知） | 一律**視為 `denied`** 處理，記 warning log；不重試、不阻塞掃描結果的渲染 | 同 `denied` 列 |

**介面（供實作票與測試注入）**：

```dart
enum NotificationAuthorization { notDetermined, granted, denied }

class ScanCompleteNotification {
  const ScanCompleteNotification({required this.gapCount});
  final int gapCount; // 0 表示無破洞，對應 scanCompleteNoGapsNotificationBody
}

abstract class ScanNotifier {
  Future<NotificationAuthorization> authorizationStatus();
  Future<NotificationAuthorization> requestAuthorization();
  Future<void> show(ScanCompleteNotification notification);
  Future<void> withdraw();                 // 撤回尚未被點擊的通知；無通知時為 no-op
  Stream<void> get activated;              // 使用者點擊通知
}
```

查詢、請求、發送、撤回四個動作由同一個可注入的抽象承擔，畫面層只消費
`activated` 串流執行「點擊通知的導向」列；三個授權值以外的平台結果（`provisional`、
錯誤）由實作端在抽象邊界內收斂為 `denied`，不外洩至畫面層。

**測試斷言**（整合測試注入 fake，記錄各方法呼叫次數與參數，概述表「外部程序呼叫」
形式；系統通知本身不在測試中驗證）：

| 情境 | 斷言 |
|------|------|
| 掃描完成時視窗前景且 `nav-page-gaps` 可見 | `show` 呼叫次數為 0；`find.byType(SnackBar)` 為 `findsNothing` |
| 掃描完成時已切至 `nav-page-tickets`，fake 回 `granted` | `show` 恰一次，`gapCount` 等於假資料破洞數；`authorizationStatus` 在 `show` 之前被呼叫 |
| 上一情境後視窗背景 → 前景往返兩次 | `show` 仍為一次 |
| 上一情境後點 `nav-item-gaps` | `withdraw` 恰一次 |
| 上一情境後點 `action-gaps-rescan` | `withdraw` 恰一次；新一輪完成且條件成立時 `show` 累計兩次 |
| fake 回 `denied`，視窗前景、可見頁為 `nav-page-tickets` | `show` 為 0、`requestAuthorization` 為 0；SnackBar 文字等於 `scanCompleteSnackbarMessage` 帶入破洞數的值，動作文字等於 `viewGapsAction` |
| fake 回 `denied`，視窗非前景 | 完成當下 `findsNothing`；模擬 `resumed` 後 SnackBar 出現 |
| fake 回 `denied`，視窗非前景，`resumed` 前已點 `nav-item-gaps` | `resumed` 後仍 `findsNothing` |
| fake 回 `notDetermined`，請求回 `granted` | `requestAuthorization` 恰一次且在 `show` 之前；`show` 恰一次 |
| fake 回 `notDetermined`，請求回 `denied` | `requestAuthorization` 恰一次；`show` 為 0；SnackBar 依 `denied` 列出現 |
| fake 於 `activated` 發事件（`state-gaps-found`） | `selectedDestinationProvider` 等於 `AppDestination.gaps`、`returnToProvider` 為 `null`；第一個 `card-gaps-<itemId>` 的 rect 與 `scroll-gaps-sections` viewport rect 有交集且 `Focus.hasFocus` 為 `true` |
| 掃描中按 `action-gaps-cancel-scan` | `show` 為 0、`requestAuthorization` 為 0 |

**i18n**（實作票補齊 ARB，key 命名沿用既有 `*Message` / `*Action` 慣例）：

| key | zh | en |
|-----|----|----|
| `scanCompleteNotificationTitle` | 破洞掃描完成 | Gap scan complete |
| `scanCompleteNotificationBody` | 偵測到 {count} 個破洞 | {count} gaps detected |
| `scanCompleteNoGapsNotificationBody` | 未偵測到破洞 | No gaps detected |
| `scanCompleteSnackbarMessage` | 掃描完成，偵測到 {count} 個破洞 | Scan complete: {count} gaps detected |
| `scanCompleteNoGapsSnackbarMessage` | 掃描完成，未偵測到破洞 | Scan complete: no gaps detected |
| `viewGapsAction` | 檢視 | View |

**實作票驗證**（本節只寫規格，下列平台事實由實作票以實機確認並回填本節，不得
以規格文字取代實測）：`UNUserNotificationCenter` 在沙盒關閉（PROP-001）與
Developer ID 簽章下的可用性，以及 debug build 未簽章時授權請求是否直接回錯；
Flutter 端載體（原生 channel 或第三方套件）的選擇；macOS 上 `AppLifecycleState`
的 `inactive` / `hidden` 對應視窗失焦與最小化的實際行為；撤回已送達通知的 API 與
其對「通知中心已收合」狀態的效果。

#### 兩個 port 的三時刻覆蓋（`0.1.0-W3-139` 裁定：ScanNotifier 與 ExternalOpener 留在本節）

上述「外部開啟契約」與「系統層通知」定義的 `ExternalOpener` 與 `ScanNotifier`
是本 App 的兩個 driven port（服務向外呼叫的接縫）。本子節補上兩者的三時刻
覆蓋——各時刻由什麼承載、哪些時刻不適用及其理由。三時刻（呼叫發出／受理／
結果）的定義、`INV-PORT-OBSERVE-001`、以及「不互相抵扣規則」屬跨專案通則，
見 `.claude/methodologies/clean-architecture-implementation-methodology.md`
的〈Port 回饋契約〉，本節不重述，只寫本專案這兩個 port 的事實與義務。
workspace domain 的三個 driven port 不在本節，見 `docs/spec/workspace/`。

**回饋消費者三欄中的監控追蹤欄**：兩個 port 皆依 `docs/tech-decisions.md`
補記段「2026-08-27：執行期 log 的裁決」，structured log 於 0.1 **維持延後**，
重評條件為「出現無法由破洞報告解釋的故障」，tripwire 總表對應列指向該重評。
此欄不寫 N/A——延後是已定策略、有觸發條件，與「不適用」的決策語意不同。
以下兩表因此只列呼叫端與日誌兩個消費者。

**`ScanNotifier` 四個方法**（實作 `lib/services/macos_scan_notifier.dart`）：

| 方法 | 呼叫發出 | 受理 | 結果（呼叫端） | 結果（日誌） |
|------|---------|------|---------------|-------------|
| `authorizationStatus()` | 入口 info log（`查詢授權狀態`） | 不適用：MethodChannel 為 fire-and-wait，平台端不回中間 acknowledge | `NotificationAuthorization` 三值；`provisional`／逾時／拋錯／API 不可用於抽象邊界內收斂為 `denied`（權限 gate「其他」列） | 成功記結果值 info；`PlatformException` 與 `MissingPluginException` 各記 warning 並標明「視為 denied」 |
| `requestAuthorization()` | 入口 info log（`請求授權`） | 同上 | 同上 | 同上 |
| `show(notification)` | 入口 info log，**含 `gapCount`** | 同上 | `Future<void>`——呼叫端不被告知成敗（見下方設計選擇） | 成功不另記（入口 log 已足以定位）；兩類例外各記 warning，含 `code` 與 `message` |
| `withdraw()` | 入口 info log（`撤回通知`） | 同上 | `Future<void>`——同上 | 同上，warning 文字須標明「不阻擋、不轉狀態」 |

**`show` 與 `withdraw` 回傳 `void` 是設計選擇，不是遺漏的回傳值。** 兩者是
非同步旁路動作：畫面在掃描完成當下已依 §3.5 走完「掃描中 → 結果」的
cross-fade，通知送不送得出去都不改變該狀態，「等待指示」列因此規定發送與
撤回期間不顯示任何等待指示，「不重複發送」列亦規定撤回失敗不阻擋、不轉狀態。
呼叫端拿到結果也沒有任何分支可走，故刻意不回傳——**此處是呼叫端消費者被刻意
排除，非以日誌抵扣呼叫端**（前者是需求上不需要，後者是把兩個獨立消費者混為
一談）。相對地 `authorizationStatus` 與 `requestAuthorization` 的結果決定
走 `granted` 發送或 `denied` fallback（權限 gate 三路徑），呼叫端必須被告知，
故回傳 enum。往後若出現「通知送出失敗須改走 SnackBar fallback」的需求，
此設計選擇即失效，須連同本段一併修訂。

**`ExternalOpener` 三時刻**（介面見「外部開啟契約」列；實作票 `0.1.0-W1-068`）：

| 時刻 | 承載 | 義務 |
|------|------|------|
| 呼叫發出 | 日誌（本次新增的契約義務，見下表）；呼叫端為 `open(path)` 的呼叫本身 | 見下方「呼叫發出日誌」表 |
| 受理 | 不適用：`Process.run` 為 fire-and-wait，外部程序不回中間 acknowledge | — |
| 結果 | 呼叫端收 `ExternalOpenResult` 三值（`opened` / `notFound` / `failed`）；日誌見下 | `failed` 依「失敗可觀測」列記 warning（stderr 與路徑）；`notFound` 記 warning（路徑）；`opened` 記 info（路徑） |

**呼叫發出日誌**（可驗收形態，`0.1.0-W1-068` 依此實作，測試依此斷言）：

| 項目 | 要求 |
|------|------|
| 記錄時機 | 進入 `open(path)` 之後、執行「前置檢查」列的 `FileSystemEntity.type(path)` **之前**。前置檢查與外部程序呼叫皆在此之後，故無論走哪條結果分支，該次呼叫都已產生一筆記錄 |
| 手段 | `developer.log`，`name` 為 `ExternalOpener` 實作的 `_tag` |
| 等級 | info（`developer.log` 預設 level，不帶 `level:` 參數） |
| 欄位 | 傳入的絕對路徑一項（`path` 原值，不截斷、不改寫） |
| 為何不可省 | `INV-PORT-OBSERVE-001`：每次呼叫必須產生可觀測事件，且該事件不得依賴外部系統是否回應。外部程序掛住不回時，只有結果分支的日誌等於整次呼叫零記錄——診斷者無法區分「呼叫了但沒回來」與「根本沒呼叫」 |
| 驗收 | `0.1.0-W1-068` 的實作中，`open` 方法體的第一個語句為此 `developer.log`，且其位置在任何 `return` 與任何 `FileSystemEntity` / `Process` 呼叫之前（靜態可讀出，不需執行） |

上表對現行臨時實作的關係：`lib/screens/gap_report/gap_report_screen.dart`
的 `_runOpen` 已有入口 log（`外部開啟：$path`），但該 log 在 `_openItem` 的
`File(...).existsSync()` 前置檢查**之後**——`notFound` 分支提早返回，走該分支
的呼叫不會留下任何入口記錄。`0.1.0-W1-068` 以正式 `ExternalOpener` 取代此
臨時接縫時，須依上表把記錄時機移到前置檢查之前。

### 2.3 導航模型：六項平行 + 單槽來源記錄

現行 `lib/app/router.dart` 以 `selectedDestinationProvider` 加 `IndexedStack`
實作六項平行導覽，**沒有 history stack**。SPEC-001 有四個退出路徑需要「回到
來源」語意（§2 flow 未結構化的返回、§4 未載入的返回上一畫面、§5 掃描中的取消返回、
§6 節點詳情的返回來源畫面），因此需要來源記錄。

**採單槽而非堆疊。** 六項導覽項恆常可見於側欄（§2.8 生命週期契約：切換導覽項
不 dispose 來源頁），使用者要回到任一畫面可直接點擊對應 `nav-item-<d>`，逐層
回退的深層返回鏈相對於「直接點擊目標分頁」不提供額外使用者價值。單槽記錄
「最近一次跳轉從哪來」，測試與實作只需斷言單一值，不需追蹤任意深度的堆疊狀態，
可驗證成本更低。

| 概念 | 定義 |
|------|------|
| `NavIntent.rail` | 使用者點擊 `nav-item-<d>` 造成的切換 |
| `NavIntent.jump` | 畫面內元素（空狀態的前進動作、徽章、節點卡、關聯項）造成的切換 |
| `returnToProvider` | `AppDestination?`，單槽 |

**四條規則**：

1. `rail` 切換 → `returnTo` 設為 `null`（切換工作區語意，等同 `go`）
2. `jump` 切換 → `returnTo` 設為跳轉前的 destination（暫時離開語意，等同 `push`）
3. 連續 `jump`（A→B→C）→ `returnTo` 為 B，C 的返回回到 B。此為明確定義，非未定義行為
4. 觸發「返回」時 → 切至 `returnTo`，隨即將 `returnTo` 設為 `null`；`returnTo`
   為 `null` 時「返回」按鈕**不渲染**（不是 disabled——沒有來源時「返回」不是一個
   有意義的動作）

**並非所有 jump 目標畫面都渲染規則 4 的返回錨點**：SPEC-001 §1（Domain 視圖）、
§3（追溯視圖）、§5（破洞報告正常態）的退出路徑欄未列「返回」，這三個畫面依
§2.2「未接線動作須可見或不渲染」不渲染 `action-<screen>-back`（見 §2.4 返回類別
說明）。這不代表這些畫面到達時寫入的 `returnTo` 值成為孤兒——規則 1 對**任一**
畫面的下一次 rail 切換一律將 `returnTo` 設為 `null`，是這些畫面的通用消費者；
規則 1 與規則 4 是同一個 `returnTo` 變數的兩種合法消費路徑，非互斥亦非矛盾。

**斷言形式**：`ref.read(returnToProvider)` 的值；以及返回按鈕錨點
`action-<screen>-back` 的存在性。

### 2.4 退出路徑的四種導航反應

SPEC-001 退出路徑欄的所有措辭，歸為四類反應，不存在第五類：

| 反應 | 觸發錨點 | 可觀察結果 |
|------|---------|-----------|
| 導覽切換（rail） | `nav-item-<d>` | `IndexedStack` 可見頁改變；`returnTo` 為 `null`；來源頁狀態保留（§2.8） |
| 內容跳轉（jump） | 各狀態內的具名動作錨點 | 可見頁改變；`returnTo` 等於跳轉前 destination |
| 返回（consume） | `action-<screen>-back`（§2.9 命名規範；行為依 §2.3 規則 4） | 可見頁改變為 `returnTo`；`returnTo` 隨即設為 `null`；`returnTo` 為 `null` 時此錨點不渲染 |
| 同畫面狀態轉換 | 各狀態內的具名動作錨點 | 可見頁不變；狀態根錨點由 X 換為 Y |

「切換專案」不屬於上述四類，它開啟浮層（§3.7），是**覆蓋層**而非導航。

**返回（consume）先前未被承認為獨立類別**：它不是 rail（觸發錨點是頁面內按鈕，
非導覽項）、不是 jump（`returnTo` 被清空而非改指向新來源）、也不是同畫面狀態
轉換（可見頁確實改變）。既有三個類別皆無法準確描述它，故獨立列為第四類；
其對 `returnTo` 為 `null` 時「無消費目標可回」的處理見 §2.3 規則 4。

**渲染位置統一，不由各畫面各自決定**：`action-<screen>-back` 一律置於該畫面
`PageColumn` 根堆疊的 `SplitRow.header` 右側 `ButtonRow`（與重新整理、重新掃描
等頁面級動作同一區塊），由 `AppShell` 之下的頁面框架容器單一渲染；六個畫面
不各自決定返回鍵的擺放方式或樣式，與 SPEC-004 §3.7 第 17、18 項一致。

### 2.5 取消契約（FR-02 的行為定義）

適用三處載入態：`state-domain-loading`、`state-tickets-loading`、`state-gaps-scanning`。

**C1 併入原 C2**：兩者皆描述「取消錨點在使用者尚未按下取消前恆可用」，差異
只在觀察時間點（第一幀 / 任何進度），無獨立驗收價值，故合併為單一條件並限定
適用範圍為「尚未按下取消」。

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| C1 | 載入進行中且尚未按下取消的任一時刻（含渲染的第一幀） | 取消錨點存在且 `enabled` 恆為 `true`；不存在「收尾中所以不能取消」的時間窗 |
| C2 | 按下取消後 `Motion.feedback` 內 | 取消錨點 `enabled` 轉為 `false`；其文字改為取消中的 i18n 值 |
| C3 | 按下取消後至抵達目標態之間 | 畫面維持載入態版面（骨架與版位不變）；進度指示改為 indeterminate；計數文字凍結於最後值；不得閃現空白、不得出現錯誤文字（可執行斷言見下方「C3 的斷言方式」） |
| C4 | 按下取消後 `Motion.cancelDeadline` 內 | 目標狀態錨點存在，載入態錨點不存在 |
| C5 | 取消完成後 | 不出現任何 SnackBar、Dialog 或錯誤標記（取消是使用者意圖，不是失敗） |
| C6 | 取消完成後 | 已解析的部分結果全數丟棄；不存在「半渲染」的矩陣或清單 |
| C7 | 取消完成後再次觸發載入 | 進度自 0 起算，不續傳 |
| C8 | 連續按下取消 N 次 | 狀態轉換只發生一次（冪等） |

**載入期間切換導覽項／切換專案的行為（原 C10／C11）已移至 §2.8 生命週期契約，
改編為 L1／L2**——兩者描述的是「離開本畫面」而非「按下取消」，屬生命週期事件
而非取消契約，收斂時一併移出。§2.11 與 FR-02 的條數引用已同步（見各節）。

**C3 的斷言方式（強制）**：自按下取消起，以固定幀距
（`tester.pump(const Duration(milliseconds: 16))`）逐幀推進至
`Motion.cancelDeadline`；每一幀皆斷言載入態骨架根錨點（`state-domain-loading` /
`state-tickets-loading` / `state-gaps-scanning` 之一）存在（`findsOneWidget`）——
任一幀不存在即為「閃現空白」，斷言失敗。同一區間內 `find.byType(SnackBar)` 與
`find.byType(Dialog)` 皆為 `findsNothing`，此即「不得出現錯誤文字」的可驗形式。

**目標態對照**：

| 來源狀態 | 目標狀態 | 依據 |
|---------|---------|------|
| `state-domain-loading` | `state-domain-unset` | SPEC-001 §1「取消 → 未選專案」 |
| `state-tickets-loading` | `state-tickets-unloaded` | SPEC-001 §4「取消 → 未載入」 |
| `state-gaps-scanning` | `returnTo` 指定的畫面；`returnTo` 為 `null` 時為 `nav-page-domain` | SPEC-001 §5「取消 → 返回」（「返回」的目標由本規格定義，見 §5 註記） |

**C4 的斷言方式（強制）**：以 `await tester.tap(...)` 後
`await tester.pump(Motion.cancelDeadline)` 推進假時鐘，再斷言目標態錨點存在。
**禁止**以 `Stopwatch` 加 `lessThan` 量測真實耗時作為 pass-fail 條件——該類斷言
的結果依賴機器負載而非程式正確性。

**C4 的實作約束**：解析與掃描迴圈須以批次進行，每批之間檢查取消旗標，
且單一批次的處理量須使「檢查點之間的間隔」不超過 `Motion.cancelDeadline`。
批次大小是實作參數，本規格只約束其後果。

### 2.6 等待指示的形式

| 狀態 | 形式 | 進度型別 | 理由 |
|------|------|---------|------|
| `state-domain-loading` | 骨架（矩陣版位） | indeterminate + 已處理節點計數文字 | 結果形狀已知（矩陣），節點總數在解析完成前未知 |
| `state-tickets-loading` | 進度條 + 已解析筆數 | determinate | 總數 N 已於未載入態顯示，分母存在 |
| `state-gaps-scanning` | 骨架（分節版位） | indeterminate + 已掃描項目計數文字 | 結果形狀已知（依類別分節），破洞總數掃完才知 |

**誠實性硬規則**：分母未知時**不得**顯示百分比、不得顯示預估剩餘時間、不得
使用會自行推進的假進度。斷言：indeterminate 情境下畫面中不存在 `%` 字元，
且不存在 `LinearProgressIndicator(value: <非 null>)`。

**計數文字更新頻率**：兩次更新之間至少間隔 `Motion.progressTick`。

**延遲顯示不適用於上述三者。** 它們是 SPEC-001 明列的一級狀態、由使用者主動
觸發、且是整個畫面的內容，必須立即渲染。0.1 無「非狀態級短暫等待需要延遲
顯示」的情境，故不定義對應 token；此類情境出現時應另行評估並新增 token，
不得沿用本節既有值。

**最短顯示時間適用**：載入態一旦渲染，至少存續 `Motion.spinnerMinVisible`，
即使解析在更短時間內完成。斷言：以極小假資料觸發載入，`pump(Motion.feedback)`
後載入態錨點仍存在。

### 2.7 空狀態與阻擋狀態的動線

SPEC-002 已定「空狀態與阻擋狀態必須是兩個元件」。本規格定其行為差異：

| 面向 | 空狀態元件 | 阻擋狀態元件 |
|------|-----------|-------------|
| 語意 | 這裡目前沒有東西 | 這個專案不適用本 App |
| 覆蓋狀態 | 空圖、無 UC、無提案、無 ticket、無破洞、無最近專案 | 不是框架專案、無可消費的型別表、schema 不相容 |
| 必備動作 | 至少一個非「返回」的前進動作（SPEC-001 FR-03） | 至少一個出口（切換專案），且該出口恆可用 |
| 動作觸發後 | 內容跳轉（jump），設定 `returnTo` | 開啟專案切換浮層，不改變 `IndexedStack` 索引 |
| 是否顯示版本值 | 否 | 是（SPEC-001 FR-04 / FR-07） |

**阻擋狀態的浮層可用性斷言**：三個阻擋狀態任一渲染時，
`find.byKey(AppShell.projectSwitcherEntryKey)` 為 `findsOneWidget` 且
`enabled` 為 `true`。這是 SPEC-001「浮層維持可用」的可驗形式。

### 2.8 生命週期契約

| 事件 | 規格 |
|------|------|
| App 啟動 | 落地於 `nav-page-domain`（`selectedDestinationProvider` 預設值）；`returnTo` 為 `null` |
| 六頁建構時機 | `IndexedStack` 一次建構全部六頁。因此「依視圖惰性」**不得**以首次建構作為觸發訊號，須以**首次可見**（成為 `IndexedStack` 的 index）觸發 |
| 切換導覽項 | 來源頁不 dispose：捲動位置、雙模式選擇、搜尋詞、篩選條件、樹展開狀態全部保留 |
| 切換導覽項與進行中任務（L1） | 任務繼續（離開畫面不等於取消）；回到該畫面時顯示當時進度 |
| 切換專案（L2） | 六頁狀態全部重置為各自初始狀態；全部進行中任務中止，且在 `Motion.cancelDeadline` 內完成中止、不留背景任務；`returnTo` 設為 `null` |
| 視窗尺寸變更 | 不重置任何狀態、不重新載入；捲動容器以「當前 offset 夾在新的可捲範圍內」處理，不歸零 |
| 視窗失焦 / 前景切換 | 不觸發任何重新載入（0.1 無檔案監看） |
| 語系 | 0.1 由啟動參數決定，執行期不切換；本規格不定義執行期語系切換行為 |

**斷言形式（狀態保留）**：於 Ticket 清單捲動至 offset X → 點 `nav-item-gaps`
→ 點 `nav-item-tickets` → `scroll-tickets-list` 的 offset 仍為 X。

**斷言形式（首次可見）**：App 啟動並 `pumpAndSettle` 後，
`state-tickets-unloaded` 存在但**尚未**觸發解析（以假的解析計數器為 0 斷言）；
點 `nav-item-tickets` 後仍為 `state-tickets-unloaded`（Ticket 清單的載入需使用者
按下「開始載入」，見 §3.4）。

### 2.9 測試錨點命名規範

| 類別 | 格式 | 例 |
|------|------|-----|
| 導覽項（既有，沿用不改） | `nav-item-<destination>` | `nav-item-ucFlow` |
| 導覽頁（既有，沿用不改） | `nav-page-<destination>` | `nav-page-ucFlow` |
| 狀態根節點 | `state-<screen>-<state>` | `state-domain-loading` |
| 動作 | `action-<screen>-<action>` | `action-tickets-start-load` |
| 換頁控制 | `mode-<screen>-<mode>` | `mode-tickets-topic` |
| 捲動容器 | `scroll-<screen>-<area>` | `scroll-gaps-sections` |
| 拖曳畫布 | `drag-<screen>-<area>` | `drag-domain-swimlane` |
| 徽章 | `badge-<screen>-<kind>` | `badge-tickets-corrupted` |
| 面板 | `panel-<screen>-<kind>` | `panel-domain-schema-detail` |
| 選單（覆蓋層根節點） | `menu-<screen>-<kind>` | `menu-tickets-filter-status` |
| 選單項 | `option-<screen>-<kind>-<value>` | `option-tickets-filter-status-all` |

`<screen>` 一律取 `AppDestination` 的 `name`（camelCase，如 `ucFlow`、
`nodeDetail`），與既有 `nav-item-` / `nav-page-` 同源，不另創 kebab 拼法。
浮層不在 `AppDestination` 中，`<screen>` 取 `switcher`。

### 2.10 焦點與鍵盤（0.1 下界）

| 條件 | 可觀察結果 |
|------|-----------|
| 按 Tab | 焦點依序走過三個區段：專案切換入口 → 六個導覽項 → 內容區（可用動作與捲動容器）；同一區段內的順序見下方「Tab 內容區順序」斷言方式 |
| 任一元素取得焦點 | 具可見焦點指示（WCAG SC 2.4.7）；斷言為該元素的 `Focus.hasFocus` 為 `true`，且渲染出焦點裝飾（可執行斷言見下方「焦點裝飾」斷言方式） |
| 浮層展開時按 Esc | 浮層收合，焦點回到 `project-switcher-entry` |
| `panel-domain-schema-detail` 展開時按 Esc | 面板收合，其餘狀態不變 |
| 矩陣已選格（`panel-domain-cell-detail` 存在）時按 Esc | 選取清除，右欄回到 `panel-domain-cell-detail-empty`；焦點停在原格，矩陣 offset 不變 |
| 浮層展開時 | 焦點被限制在浮層內（Tab 不會跑到背景的導覽列） |
| 篩選選單（`menu-tickets-filter-<key>`）展開時按 Esc | 選單收合；`onChanged` 不被呼叫；焦點回到 `action-tickets-filter-<key>` |
| 篩選選單展開時 | 焦點以 ↑／↓／Home／End 在選項間移動（§3.4 走選項列）；按 Tab 或 Shift+Tab 選單收合且焦點依本節順序離開觸發器——選單**不**限制焦點，與浮層不同（選單沒有必須完成的交易，離開即等於取消） |

**Tab 內容區順序（斷言方式）**：三個區段（專案切換入口、六個導覽項、內容區）須
依序窮盡——同一區段內的可用動作與捲動容器全部走完才進入下一區段。區段內的相對
順序依 Flutter 預設 `ReadingOrderTraversalPolicy`（畫面視覺由上到下、由左到右），
不另訂逐一具名的順序清單。斷言：連續按 Tab 產生的焦點序列中，同一區段內後一個
取得焦點元件的位置（`renderBox.localToGlobal(Offset.zero)`）其 `dy` 不小於前一個
取得焦點的元件；`dy` 相同時 `dx` 不小於前一個。

**焦點裝飾（斷言方式）**：取得焦點的元件祖先鏈中，存在至少一個 `decoration`
屬性非 `null` 的 `Container` 或 `DecoratedBox`（
`find.ancestor(of: <該元素 finder>, matching: find.byWidgetPredicate((w) => (w is Container && w.decoration != null) || (w is DecoratedBox && w.decoration != null)))`
為 `findsAtLeastNWidgets(1)`）。本規格不規定裝飾的顏色、形狀或元件名稱，僅要求
裝飾存在。

方向鍵捲動、快捷鍵切換導覽項不列入 0.1 下界，亦不得以無回饋的方式部分實作。
篩選選單內以方向鍵走選項是選單元件的固有行為（§3.4 走選項列），不在此排除範圍。

### 2.11 元件庫對應

各類行為的實作落點，供 SPEC-002 元件庫直接引用：

| SPEC-002 元件 | 承擔本規格的哪一節 |
|--------------|------------------|
| 載入態（骨架 + 進度 + 取消） | §2.5 取消契約 C1–C8、§2.8 生命週期 L1–L2、§2.6 等待指示、§2.12 長時操作的第二層回饋與「阻擋頁面內容」 |
| 空狀態（訊息 + 前進動作） | §2.7 空狀態欄、§2.4 內容跳轉 |
| 阻擋狀態（訊息 + 版本值 + 出口） | §2.7 阻擋狀態欄、浮層可用性斷言 |
| 導覽項 | §2.3 `rail` intent、§2.8 狀態保留 |
| 專案切換浮層 | §3.7 全節、§2.10 焦點限制 |
| 節點卡 | §1.3 不可拖曳、§2.4 內容跳轉 |
| 損壞標記（兩級） | §3.4 含損壞、§3.6 部分損壞的跳轉行為 |
| 徽章 | §3.4 損壞徽章的可點性 |
| 篩選下拉（SPEC-004 4.13 `FilterDropdown`） | §3.4 篩選七列與元件級契約 F1–F7、§2.10 選單 Esc／Tab 兩列、§1.4 第 3 列 |
| 表格欄首（SPEC-004 4.14 `TableColumnHeader.sortable`） | §3.4 排序兩列與元件級契約 S1–S7 |
| SnackBar（SPEC-004 4.26 `AppSnackBar.withAction`） | §2.2「系統層通知」權限 `denied` 列的 App 內 fallback、§2.12 短暫非同步的第三層回饋 |

**取消契約由載入態元件單一承擔，不由三個畫面各自實作。** 三處載入態的差異只有
「目標態」與「進度型別」兩個參數，其餘行為（§2.5 的 C1–C8 與 §2.8 的 L1–L2，
共 10 條）完全相同。

### 2.12 服務類型與等待期政策

§2.2 定的是「怎麼告知使用者」；本節定的是「使用者觸發之後、結果抵達之前，系統
怎麼保護使用者與自己」。三項政策——回饋形式、輸入阻擋範圍、重複觸發防護——共用
同一個自變數：**被觸發的服務屬於哪一類**。分開設計會得出互相矛盾的規則，故三者
在同一張對照表內逐類型定案。來源 `0.1.0-W3-105`（用戶裁示 2026-09-08）。

#### 服務類型分類

分類軸為「使用者感知的等待長度」與「失敗形態」兩項。**同步／非同步不作為分類軸**
——它是實作細節，使用者感知不到。切分依據是「政策確實不同」：三項政策全同的兩類
應合併，故每一類都須指出它與相鄰類的政策差異點。

| 類型 | 使用者感知的等待 | 失敗形態 | 0.1 實例 |
|------|----------------|---------|---------|
| 本地即時 | 零（同一幀內完成） | 不可能失敗（純本地狀態操作） | 導覽切換、模式切換、樹展開收合、篩選選取、返回、Esc 收合 |
| 延遲觸發 | 使用者持續輸入中、停頓後才觸發；感知為「輸入 → 結果更新」之間的延遲 | 不可能失敗（本地過濾運算） | 搜尋輸入防抖後觸發過濾（`input-tickets-search`） |
| 短暫非同步 | 亞秒（可感知短暫等待，但不需要進度指示） | 可能失敗（外部程序不存在、執行失敗、平台 API 拒絕） | 外部開啟（§2.2 外部開啟契約）、系統通知發送與撤回、通知授權查詢與請求（§2.2 系統層通知） |
| 長時操作 | 秒至分鐘（明確感知等待，需要進度指示與取消能力） | 可能失敗（解析錯誤、平台錯誤、資料損壞） | Domain 載入、Ticket 載入、破洞掃描 |

**各類的切分理由**（「它的政策哪裡與相鄰類不同」）：

| 相鄰對 | 政策差異點 |
|--------|-----------|
| 本地即時 vs 延遲觸發 | 本地即時不經任何服務呼叫，三項政策全為「無」。延遲觸發的結果雖然同為本地運算，但觸發與結果之間有可感知的延遲（`Motion.searchDebounce`），且需要防抖機制避免逐字元觸發——這兩點在本地即時不存在 |
| 延遲觸發 vs 短暫非同步 | 延遲觸發的結果必然成功，無需結果回饋元件；短暫非同步可能失敗，需要第三層結果回饋（`AppSnackBar`）。防護機制亦不同：前者是防抖（延後執行），後者是冪等（重複開啟同一檔案是合法操作，不須延後也不須阻擋） |
| 短暫非同步 vs 長時操作 | 短暫非同步等待亞秒，pressed 態已覆蓋等待感知，故不提供第二層回饋、不阻擋輸入；長時操作等待秒至分鐘，需要第二層受理回饋（載入態與進度）、需要阻擋頁面內容、且須提供取消 |

#### 政策對照表

「回饋形式」欄依 §2.2 承擔者欄分列第二層（服務）與第三層（event 處理路徑）；
第一層（互動元件自身）不列於本表——它不隨服務類型變動，四類一律為 Material
pressed 態，見下方不變式 INV-FEEDBACK-001。

| 服務類型 | 回饋形式 | 輸入阻擋範圍 | 重複觸發防護 |
|---------|---------|-------------|-------------|
| 本地即時 | 第二層：不適用（無服務呼叫）。第三層：狀態轉換本身即結果 | 不阻擋 | 無需（本地狀態操作天然冪等） |
| 延遲觸發 | 第二層：不適用（本地運算無受理階段）。第三層：清單筆數更新，即狀態轉換本身 | 不阻擋（使用者正在輸入，不得打斷） | 防抖（`Motion.searchDebounce`） |
| 短暫非同步 | 第二層：不提供（§2.6 已定「0.1 無非狀態級短暫等待需要延遲顯示」，等待感知由 pressed 態覆蓋）。第三層：`AppSnackBar`，成功與失敗各有對應 i18n key（§2.2 外部開啟契約） | 不阻擋 | 冪等（重複觸發為合法操作）；通知授權請求另有系統級防護（`notDetermined` 只彈一次對話框，§2.2 權限 gate 三路徑） |
| 長時操作 | 第二層：畫面級載入態（§2.6：骨架或進度條 + 計數文字）。第三層：狀態轉換本身；結果不在視線範圍時升級為系統通知，`denied` 時退回 `AppSnackBar.withAction`（僅破洞掃描，§2.2 系統層通知） | 阻擋頁面內容（整頁被載入態取代），且必須同時提供取消 | 禁用觸發來源（頁面內容被載入態取代後，觸發入口不存在） |

**回饋形式全部對應既有元件，本節不新增元件。** 載入態為 SPEC-004 的 `LoadingState`、
結果通知為 `AppSnackBar`（含 `withAction` 變體）、點擊確認為 Material pressed 態、
系統通知為 §2.2 的 `ScanNotifier`。四類服務類型的回饋形式皆可由這四者承載。

#### 輸入阻擋範圍的三選一判準

| 選項 | 判準 | 0.1 適用的類型 |
|------|------|--------------|
| 不阻擋 | 操作亞秒內完成，或使用者進行中的互動（輸入文字）不應被打斷 | 本地即時、延遲觸發、短暫非同步 |
| 禁用觸發來源 | 須防止同一來源重複觸發，但使用者仍可操作畫面其他元素 | 0.1 無獨立適用者——長時操作的觸發入口已隨頁面內容被載入態取代而消失，不需另外禁用 |
| 阻擋頁面內容 | 操作耗時秒至分鐘，中間結果無法顯示於正常態版面，整頁被載入態取代 | 長時操作 |

**「阻擋頁面內容」的範圍限於內容區，不含導覽列。** 載入態佔據 SPEC-001 的整個
內容區，正常態元素不可見亦不可互動；但 `nav-item-<d>` 恆可點擊——§2.8 L1 已定
切換導覽項不取消進行中任務，使用者可離開而任務繼續。此非「整個畫面凍結」，而是
「頁面內容區被替代」。

**阻擋頁面內容者必須同時提供取消（強制）。** 否則使用者被困在一個沒有出口的畫面
內，只能等待或強制結束 App。此約束由 §2.5 承擔，不另訂條件：C1 保證取消錨點在
尚未按下前恆 `enabled`，C4 保證按下後在 `Motion.cancelDeadline` 內抵達目標態。
斷言：任一載入態錨點存在的幀，同一畫面內對應的取消錨點存在且 `enabled` 為 `true`。
**本項的驗收落在 FR-02（取消契約的十條行為全部成立），不另立功能需求條目**——
FR-14 只斷言「阻擋期間取消錨點存在」，取消本身的可用性、時限與後續行為全由 FR-02
承擔。此處明列歸屬，避免讀者因本節未列 FR 而誤以為該約束無人負責。

#### 本節的功能需求對應

本節的四項規範主張各有承載的功能需求條目，逐項對應如下；「阻擋時必須提供取消」
不在其中，理由見上段。

| §2.12 的規範主張 | 承載的條目 |
|-----------------|-----------|
| 第一層回饋的無條件性（不變式 INV-FEEDBACK-001） | FR-12 |
| 逐服務類型的回饋形式（政策對照表的回饋形式欄） | FR-13 |
| 逐服務類型的輸入阻擋範圍 | FR-14 |
| 重複觸發防護的承擔者為服務、元件不實作 | FR-15 |
| 阻擋頁面內容時必須同時提供取消 | FR-02（既有，不另立） |

#### 重複觸發防護的承擔者一律是服務

**防抖、節流、冪等的決策與執行都在服務層，元件不實作任何一種。** 元件的職責是在
每一次互動都發出第一層回饋並無條件呼叫回調；要不要真的執行由服務決定。

| 防護機制 | 服務層行為 | 元件層行為 |
|---------|-----------|-----------|
| 防抖（debounce） | 收到事件後啟動計時器；窗口內再次收到同一事件則重設計時器，窗口結束才執行 | 每次輸入都更新自身顯示（第一層），並無條件呼叫回調 |
| 節流（throttle） | 固定間隔內至多執行一次（0.1 無適用者） | 同上 |
| 冪等（idempotent） | 接受重複呼叫，相同輸入產生相同效果，不阻擋、不排隊 | 每次點擊都有 pressed 態（第一層），並無條件呼叫回調 |
| 禁用觸發來源 | 開始長時操作時通知畫面層進入載入態 | 載入態取代頁面內容，觸發入口不存在 |

**`Motion.searchDebounce` 的落點**：搜尋輸入的防抖由消費 `onChanged` 的 provider
承擔；`SearchField` 每次非組字文字變更即無條件呼叫一次 `onChanged`，元件本身不
持有計時器（歸屬修正見 `0.1.0-W3-110`）。§2.1 的 token 定義（輸入停止後至觸發
過濾的等待）不變，變的只是誰消費它。

#### 不變式 INV-FEEDBACK-001

**元件在每一次互動都必須發出第一層回饋，即使服務因防抖、節流或冪等而丟棄該次呼叫。**

| 條件 | 可觀察結果 |
|------|-----------|
| 按下按鈕，且服務不執行該次呼叫（防抖窗口內、節流間隔內、或服務永不受理） | pressed 視覺在 `Motion.feedback` 內出現 |
| 於搜尋框輸入一個字元，防抖計時器尚未到期 | 該字元存在於輸入框的 `TextEditingValue.text` |
| 於防抖窗口內連續按下同一按鈕 N 次 | N 次按下各自有 pressed 視覺，即使服務只執行其中一次 |

**Why**：防抖若做在元件層，窗口內的按下會沒有 ripple——使用者看到的是一個沒反應
的按鈕，正是 `ARCH-GPD-001` 的形態（互動回饋掛在服務的成功路徑上），只是成因從
「服務不可用」換成「服務刻意不執行」。元件永遠回饋、服務決定是否真的執行，這個
責任分離就是 §2.2 承擔者欄第一層（互動元件自身）與第二層（服務）的分工。

**Consequence**：違反時使用者無從區分「按鈕壞了」與「服務正在防抖」，兩者的畫面
表現完全相同。且自動化測試不會發現——測試替身不做防抖，元件在測試中恆有回饋，
只有真實環境下的快速連按才暴露缺陷，而該路徑無人固定重現。

**規格層判準**（本規格管轄的部分）：

1. 第一層回饋的觸發條件不得包含任何服務狀態。以「服務正在防抖」「該次呼叫已被
   丟棄」「服務尚未受理」為由抑制 pressed 態，皆為違反。
2. `enabled: false` 的合法理由是「操作本身不可用」（例如取消已按下，§2.5 C2），
   不是「操作被防抖暫緩」。以防抖為由把元件設為 disabled 等同於抑制第一層回饋。
3. 本規格得定義防抖窗口等時間門檻（§2.1 時間 token），但**不得要求以絕對計時
   斷言驗證它**——時間相關驗收一律以假時鐘推進，與 §2.5 C4 的斷言方式同一約束
   （`.claude/rules/core/test-assertion-design-rules.md` 規則 D1）。

**機械檢查方式**：見 `.claude/skills/tdd/references/layered-test-strategy.md` 的
〈不變式 INV-FEEDBACK-001 的驗證形態〉段——該段逐一指定每種違反路徑用哪一層的
替身角色驗。**本節不重複定義檢查形態**：同一條不變式的檢查方式若在規格與測試設計
文件各寫一份，兩份會各自演進，屆時實作者依規格寫出的測試與測試設計文件要求的形態
不一致而無人察覺，因為兩邊各自讀起來都合理（`DOC-005` 跨文件原則失步）。規格側
只保留上列規格層判準，測試的具體形態屬測試設計文件管轄。

---

## 3. 逐畫面規格

### 3.1 Domain 視圖（`nav-page-domain`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 選擇資料夾 | `action-domain-choose-folder` | 點擊 | 開啟系統資料夾選擇器；選定後 `state-domain-unset` 消失、`state-domain-loading` 出現 |
| 選擇器被使用者取消 | 同上 | 於選擇器按取消 | 仍為 `state-domain-unset`；不出現 SnackBar、不出現錯誤文字；既有專案（若有）不被清除 |
| 取消載入 | `action-domain-cancel-load` | 點擊 | 依 §2.5，目標態 `state-domain-unset` |
| 切至矩陣 | `mode-domain-matrix` | 點擊 | `state-domain-swimlane` 消失、`state-domain-matrix` 出現 |
| 切至泳道 | `mode-domain-swimlane` | 點擊 | 反向；矩陣的捲動 offset 被保留，切回時還原 |
| 矩陣格子（選格） | `cell-domain-<rowId>-<colId>` | 單擊 | `Motion.feedback` 內該格呈選中態、其所在列呈列高亮（選中 domain 同步為該列）；`panel-domain-cell-detail-empty` 消失、`panel-domain-cell-detail` 出現且其標題文字等於「`<domain 名> × <UC id>`」；`state-domain-matrix` 仍存在（疊加態）；矩陣 offset 不變；`IndexedStack` 索引不變 |
| 矩陣格子（換選） | 另一個 `cell-domain-*` | 已選格下單擊 | 前一格失去選中態、新格取得；`panel-domain-cell-detail` 內容替換為新格；`scroll-domain-cell-detail` 的 offset 歸零（新格的舊 offset 無意義） |
| 矩陣格子（再點同一格） | 同一 `cell-domain-*` | 已選格下單擊 | 無狀態改變（不切換為取消選取——取消由 Esc 承擔，同一元素不得依狀態改變語意） |
| 矩陣格子（「無關」格） | 關係種類為 `none` 的 `cell-domain-*` | 單擊 | 同「選格」；`panel-domain-cell-detail` 內步驟清單與事件標籤不渲染，說明 slot 為 `l10n.cellDetailNotInvolved` 的值 |
| 在泳道中檢視 | `action-domain-cell-goto-swimlane` | 點擊（僅於 `panel-domain-cell-detail` 內渲染） | `state-domain-matrix` 消失、`state-domain-swimlane` 出現，且該格對應的泳道列 rect 與 viewport rect 有交集；選中格保留（切回矩陣時仍為已選格） |
| 清除選取 | — | 已選格下按 Esc | 依 §2.10；亦可由 `action-domain-cell-clear`（詳情卡右上關閉）觸發，兩者結果相同 |
| 選 domain（列首）與選格的關係 | `action-domain-select-<domainId>` | 已選格下點擊**另一列**的列首 | 列高亮移至該列，選格清除，右欄回 `panel-domain-cell-detail-empty`（列高亮唯一，右欄內容須與高亮列一致）；點擊**同一列**列首則選格不變 |
| 格詳情卡捲動 | `scroll-domain-cell-detail` | drag / 捲軸 | 右欄 offset 改變、矩陣 offset 不變（§1.1 連動禁令） |
| 矩陣捲動 | `scroll-domain-matrix` | 二維 drag | 水平與垂直 offset 皆改變；列首與欄首保持釘選（不隨內容捲離）；已選格隨內容捲離 viewport 時選中態與右欄內容皆不變 |
| 泳道拖曳 | `drag-domain-swimlane` | drag | 內容平移量等於位移，比例 1:1 |
| 泳道捲動 | `scroll-domain-swimlane` | drag / 捲軸 | offset 改變，與拖曳共用同一 offset |
| 選 domain | `action-domain-select-<domainId>` | 點擊 | 該 domain 於當前模式中呈選中態；不改變 `IndexedStack` 索引 |
| 開啟 docs 目錄 | `action-domain-open-docs` | 點擊 | **0.1 落地**（`0.1.0-W1-036` 定案，契約見 §2.2「外部開啟契約」）：`ExternalOpener.open(path)` 以系統預設方式開啟該目錄（Finder）；結果 `opened` → SnackBar `openedExternallyMessage`，停留 `Motion.snackBar`；畫面狀態不變 |
| 開啟 docs 目錄（渲染時目錄不存在） | 同上 | — | **該錨點不渲染**（SPEC-001 §1「僅在該目錄存在時提供」） |
| 開啟 docs 目錄（點擊時目錄已消失，或系統無法開啟） | 同上 | 點擊 | 結果 `notFound` 或 `failed` → SnackBar `externalOpenFailedMessage`，停留 `Motion.snackBar`；畫面狀態不變（目錄消失屬外部變更，由下一次重新載入承接，本畫面不設偵測點） |
| 檢視 schema 詳情 | `action-domain-schema-detail` | 點擊 | `panel-domain-schema-detail` 出現，含 App 支援版本與專案版本兩個值；再次點擊或 Esc 收合 |
| 導覽至破洞報告 | `action-domain-goto-gaps` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `domain` |
| 切換專案 | `project-switcher-entry`（既有） | 點擊 | 浮層展開（§3.7） |

**格詳情卡的內容契約**（`panel-domain-cell-detail`）：

| 區塊 | 存在條件 | 可觀察結果 |
|------|---------|-----------|
| 標題 | 恆在 | 文字為「`<domain 名> × <UC id>`」 |
| 關係種類 | 恆在 | 文字等於圖例三值之一（`l10n.legendDirect` / `legendIndirect` / `legendNone`），與該格符號一致 |
| 說明 | 該格有說明資料時 | 一段文字；無資料時該 slot 不渲染，不留空白列 |
| 編號步驟 | 該格步驟數 > 0 | 依 flow 順序的編號列；序號從 1 起連續 |
| 事件標籤 | 該格步驟的 `emits` / `consumes` 聯集非空 | 每個事件一個標籤，前綴 `emits` 或 `consumes` |
| 在泳道中檢視 | 恆在 | `action-domain-cell-goto-swimlane` 存在且 `enabled` 為 `true` |
| 關閉 | 恆在 | `action-domain-cell-clear` 存在 |

三個可缺區塊的資料來源屬 CLAUDE.md §6 待決（Domain 視圖的列與格無來源），
0.1 以假資料驅動；假資料須至少含一格「三區塊皆有」、一格「僅標題與關係種類」、
一格「步驟數足以觸發 `scroll-domain-cell-detail` 捲動」。

**未選格的右欄**（`panel-domain-cell-detail-empty`）：常駐於 `state-domain-matrix`，
內容為提示文字 `l10n.cellDetailPrompt`，無動作（前進動作即點格，在主欄）。
與 `panel-domain-cell-detail` 互斥存在。右欄常駐不隱藏的理由見 SPEC-001 §1 註記。

**選格與切泳道的關係（PM 核定 2026-09-02：採方案 B，單擊選格、詳情卡內「在泳道中檢視」切泳道；理由：可發現、有鍵盤等價、同元素語意不隨狀態變）**：畫布副標「點格子切換至泳道」與右欄詳情卡
不能同時由單擊承擔。四案比較：

| 案 | 單擊 | 切泳道由誰承擔 | 不採／採用理由 |
|----|------|--------------|--------------|
| A | 切泳道（維持現狀） | 單擊 | 詳情卡沒有觸發方式；hover 顯示不可鍵盤觸發、右欄內容隨滑鼠閃動、無穩定狀態可斷言 |
| B（**採用**） | 選格 | 詳情卡內 `action-domain-cell-goto-swimlane` 按鈕 | 兩個層級分開：選格是同畫面狀態轉換，切泳道是換頁（§1.2）；按鈕可 Tab 到、可見、可斷言，符合 §2.2 可點性辨識與 §2.10 鍵盤下界；多一次點擊是代價 |
| C | 選格 | 雙擊 | 雙擊不可發現、無鍵盤等價、與單擊在同一元素上疊兩種語意；桌面慣例但違反 §2.2「未接線動作須可見」精神 |
| D | 選格 | 再點同一格 | 同一元素依狀態改變語意，使用者不可預期；且與「換選」的點擊無法區辨 |

採 B 的後果：畫布副標須改為「點格子檢視詳情」（畫布漂移，記入 SPEC-004 §3.5，
由 `0.1.0-W1-044.2` 消費）；`MatrixCell` 的狀態集需增 `selected`；`TwoColumnLayout`
右欄在 §1 為 `Panel.scrollable`。PM 若改採 A 或 C，只有上表「矩陣格子（選格）」
列的觸發欄與「在泳道中檢視」列改寫，詳情卡內容契約與退出路徑不變。

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 未選專案 → 載入中 | cross-fade，`Motion.transition` |
| 載入中的骨架 | shimmer 循環 `Motion.skeletonCycle`；`disableAnimations` 時為靜態灰塊 |
| 載入中 → 正常 / 空圖 / 三個阻擋狀態 | cross-fade，`Motion.transition` |
| 矩陣首次渲染 | **不做逐格入場動畫**。真實規模下（不低於 1300 筆）逐格動畫無資訊量且成本高 |
| 矩陣 → 泳道的定位 | 以 `jumpTo` 即時定位，**不用** `animateTo`。定位是導航結果不是動畫；長泳道上的 animateTo 會產生數秒捲動且中途無法斷言 |
| 矩陣格的選取標記出現 | 點擊確認用 `InkWell` 內建 pressed 態（§2.2），選中態本身無入場動畫（持續性標記） |
| 右欄提示 ↔ 詳情卡、詳情卡內容換選 | cross-fade，`Motion.transition`；資料為本地已解析內容，切換耗時落在「幾乎即時帶」內，不顯示任何等待指示 |
| `panel-domain-schema-detail` 展開 | 高度變化 `Motion.transition` |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 未選專案 | `action-domain-choose-folder` → `state-domain-loading` |
| 載入中 | `action-domain-cancel-load` → `state-domain-unset`；解析完成 → `state-domain-matrix` 或 `state-domain-empty` |
| 正常 · 矩陣 | `nav-item-<d>` → 其他畫面（rail）；`project-switcher-entry` → 浮層；`cell-domain-*` → 已選格（同畫面疊加） |
| 已選格（疊加） | Esc / `action-domain-cell-clear` → 正常 · 矩陣（未選格）；另一 `cell-domain-*` → 已選格（換內容）；`action-domain-cell-goto-swimlane` → 正常 · 泳道；其餘繼承正常 · 矩陣 |
| 正常 · 泳道 | `mode-domain-matrix` → 矩陣；其餘同上 |
| 空圖 | `action-domain-goto-gaps` → `nav-page-gaps`（jump）；`project-switcher-entry` → 浮層 |
| 不是框架專案 | `project-switcher-entry` → 浮層（唯一出口，恆可用） |
| 無可消費的型別表 | `project-switcher-entry` → 浮層；`action-domain-degraded-view` → `state-domain-matrix` 或 `state-domain-empty`（同畫面轉換，疊加 `badge-domain-degraded-schema`，SPEC-001 v1.5 §1 註記「降級型別表」）。該動作僅在 `.claude/VERSION` 不高於 App 內建型別表產生版本時渲染；高於時不渲染，退出只剩浮層。降級旗標於切換專案時重置（§2.8）。定案來源 `0.1.0-W1-035` |
| schema 不相容 | `action-domain-schema-detail` → 同畫面展開；`project-switcher-entry` → 浮層 |

#### 生命週期

| 事件 | 規格 |
|------|------|
| App 啟動且有已存路徑 | 直接進入 `state-domain-loading` |
| App 啟動且無已存路徑 | 進入 `state-domain-unset` |
| 本畫面非惰性 | 它是預設落地頁，啟動即可見，不套用首次可見延遲 |
| 切至其他導覽項 | 載入繼續；矩陣／泳道的 offset、選中 domain、選中格與 `scroll-domain-cell-detail` 的 offset、當前模式保留 |
| 矩陣 ↔ 泳道切換 | 選中格保留；由泳道切回矩陣時 `panel-domain-cell-detail` 仍存在且內容不變 |
| 切換專案 | 中止載入；重置為 `state-domain-loading`（新專案）或 `state-domain-unset`；選中格清除 |
| 視窗尺寸變更 | 矩陣以左上角為錨定保留 offset；不重新解析 |

### 3.2 UC Flow 視圖（`nav-page-ucFlow`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 步驟列 | `card-ucFlow-step-<stepId>` | 點擊 | jump 至 `nav-page-nodeDetail`；`returnTo` 設為 `ucFlow` |
| domain 欄 | `action-ucFlow-goto-domain-<domainId>` | 點擊 | jump 至 `nav-page-domain` 且該 domain 呈選中態；`returnTo` 設為 `ucFlow` |
| 步驟捲動 | `scroll-ucFlow-steps` | drag / 捲軸 | offset 改變 |
| 開啟原始檔 | `action-ucFlow-open-source` | 點擊 | **0.1 落地**（`0.1.0-W1-036` 定案，契約見 §2.2「外部開啟契約」）：`ExternalOpener.open(path)` 以系統預設方式開啟該檔；結果 `opened` → SnackBar `openedExternallyMessage`，停留 `Motion.snackBar` |
| 開啟原始檔（檔案不存在） | 同上 | 點擊 | 結果 `notFound` → SnackBar `sourceFileNotFoundSnackbarMessage`，停留 `Motion.snackBarWithAction`，帶一個「重新整理」動作（`refreshAction`） |
| 開啟原始檔（無預設應用程式或其他開啟失敗） | 同上 | 點擊 | 結果 `failed` → SnackBar `externalOpenFailedMessage`，停留 `Motion.snackBar`；畫面狀態不變 |
| 檢視關聯 | `action-ucFlow-relations` | 點擊 | jump 至 `nav-page-nodeDetail` 並定位於關聯右欄；`returnTo` 設為 `ucFlow` |
| 導覽至破洞報告 | `action-ucFlow-goto-gaps` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `ucFlow` |
| 返回 Domain 視圖 | `action-ucFlow-back-to-domain` | 點擊 | 切至 `nav-page-domain`。**此動作固定回 Domain 視圖**（SPEC-001 §2 明訂目標），不使用 `returnTo` |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 無 UC / flow 未結構化 / 正常 三者之間 | cross-fade，`Motion.transition` |
| 步驟表首次渲染 | 不做逐列入場動畫 |
| SnackBar 進出 | 由 Material 預設，不覆寫 |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 無 UC | `action-ucFlow-goto-gaps` → `nav-page-gaps`（jump）；`nav-item-<d>` → 其他畫面；`project-switcher-entry` → 浮層 |
| flow 未結構化 | `action-ucFlow-back-to-domain` → `nav-page-domain`。`action-ucFlow-open-source` 是外部動作，**不改變畫面狀態**，不計為退出路徑（見 §5 註記） |
| 正常 | `nav-item-<d>` → 其他畫面；`card-ucFlow-step-*` / `action-ucFlow-goto-domain-*` → jump；`project-switcher-entry` → 浮層 |

#### 生命週期

| 事件 | 規格 |
|------|------|
| 首次可見 | 依已建立的圖直接判定三個狀態之一，不另有載入態（SPEC-001 §2 無載入中狀態） |
| 切至其他導覽項 | `scroll-ucFlow-steps` 的 offset、當前選定的 UC 保留 |
| 切換專案 | 重置為初始（依新專案的圖判定狀態）；當前選定的 UC 清除 |
| 圖尚未建立即被選為可見頁 | 顯示 `state-ucFlow-empty` 之外的第四種呈現屬 SPEC-001 未定義範圍；0.1 的假資料一律預先建立圖，此路徑不出現 |

### 3.3 追溯視圖（`nav-page-traceability`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 展開收合 | `expander-traceability-<nodeId>` | 點擊 | 該節點的子層出現或消失；`scroll-traceability-tree` 的 offset 不歸零 |
| 節點 | `card-traceability-<nodeId>` | 點擊 | jump 至 `nav-page-nodeDetail`；`returnTo` 設為 `traceability` |
| 樹捲動 | `scroll-traceability-tree` | drag / 捲軸 | offset 改變 |
| 跳轉破洞報告 | `action-traceability-goto-gaps` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `traceability` |
| 缺口層虛線框 | `badge-traceability-broken-<layer>` | 點擊 | 同上（缺口標示本身即為跳轉入口） |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 展開收合 | 子層高度變化 `Motion.transition`；`disableAnimations` 時瞬間展開 |
| 三個狀態之間 | cross-fade，`Motion.transition` |
| 缺口虛線框 | **靜態**，不做閃爍或呼吸動畫（持續性標記用動畫會成為長駐干擾） |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 正常 | `nav-item-<d>` → 其他畫面；`card-traceability-*` → jump 至節點詳情；`project-switcher-entry` → 浮層 |
| 鏈路斷裂 | 同正常，另加 `action-traceability-goto-gaps` / `badge-traceability-broken-*` → `nav-page-gaps`（jump） |
| 無提案 | `action-traceability-goto-gaps` → `nav-page-gaps`（jump）；`nav-item-<d>`；`project-switcher-entry` |

#### 生命週期

| 事件 | 規格 |
|------|------|
| 首次可見 | 依已建立的圖判定三個狀態之一，無載入態 |
| 切至其他導覽項 | 樹的展開集合與 offset 保留 |
| 切換專案 | 展開集合清空、offset 歸零、重新判定狀態 |

### 3.4 Ticket 清單（`nav-page-tickets`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 開始載入 | `action-tickets-start-load` | 點擊 | `state-tickets-unloaded` 消失、`state-tickets-loading` 出現 |
| 取消載入 | `action-tickets-cancel-load` | 點擊 | 依 §2.5，目標態 `state-tickets-unloaded` |
| 返回上一畫面 | `action-tickets-back` | 點擊 | 切至 `returnTo`；`returnTo` 為 `null` 時**此錨點不渲染**（§2.3 規則 4） |
| 搜尋 | `input-tickets-search` | 輸入 | 輸入停止 `Motion.searchDebounce` 後清單筆數更新（防抖動，不逐字元觸發）；清空輸入立即還原全部筆數 |
| 篩選 · 開啟 | `action-tickets-filter-<key>` | 點擊（選單收合時）；或焦點在此時按 Enter／Space／↓ | `Motion.overlay` 內 `menu-tickets-filter-<key>` 出現；觸發器 `Semantics` 的 `expanded` 為 `true`；焦點移至目前值對應的選項（`selected` 為 `null` 時為 `option-tickets-filter-<key>-all`）；`onChanged` 不被呼叫；清單筆數與 offset 不變 |
| 篩選 · 走選項 | `menu-tickets-filter-<key>` | ↑／↓／Home／End | 焦點在選項間移動：↓ 下一項、↑ 上一項、Home 首項、End 末項；首項按 ↑ 與末項按 ↓ 焦點不動（不循環）；`onChanged` 不被呼叫（焦點移動不套用篩選） |
| 篩選 · 選取 | `option-tickets-filter-<key>-<value>` | 點擊；或焦點在此時按 Enter／Space | 值與目前 `selected` **不同**時：`onChanged` 被呼叫恰一次，值為 `<value>`（`all` 傳 `null`）；選單於 `Motion.overlay` 內收合；觸發器文字改為該選項文字，`selected` 非 `null` 時該篩選呈選中態、為 `null` 時回到非選中態；清單筆數改變；offset 歸零（與排序同理，列集合改變後保留舊 offset 無意義）；焦點回到觸發器。值與目前 `selected` **相同**時：選單收合；`onChanged` 不被呼叫；清單筆數與 offset 不變 |
| 篩選 · Esc 收合 | `menu-tickets-filter-<key>` | 按 Esc | 選單收合；`onChanged` 不被呼叫；`selected` 不變；焦點回到 `action-tickets-filter-<key>`（§2.10） |
| 篩選 · 點外部收合 | — | 點擊選單與其觸發器以外任一處 | 選單收合；`onChanged` 不被呼叫；該次點擊被選單吸收、不傳遞至下層元素（斷言：點在 `card-tickets-<ticketId>` 上時選單收合且不 jump、`returnTo` 不變；點在 `action-tickets-filter-<key2>` 上時 `menu-tickets-filter-<key2>` 不出現；點在 `nav-item-<d>` 上時 `IndexedStack` 可見頁不變） |
| 篩選 · 再點觸發器 | `action-tickets-filter-<key>` | 點擊（選單展開時） | 選單收合；`onChanged` 不被呼叫；焦點停在觸發器 |
| 篩選 · Tab 離開 | `menu-tickets-filter-<key>` | 按 Tab／Shift+Tab | 選單收合；`onChanged` 不被呼叫；焦點依 §2.10 順序移至觸發器之後（Shift+Tab 為之前）的元素 |
| 排序 · 循環 | `action-tickets-sort-<key>` | 點擊；或焦點在此時按 Enter／Space | `onSort` 被呼叫恰一次；呼叫端依 `none → asc → desc → none` 推進該欄 `order`（三態循環，`desc` 之後回到 `none`，不停留於 `desc`）；`Motion.feedback` 內欄首指示與朗讀標籤更新（S4）；轉入 `asc`／`desc` 時首列與末列的內容改變；轉回 `none` 時首列與末列等於載入完成當下的首列與末列（S3）；每次轉換 offset 歸零（排序改變後保留舊 offset 無意義） |
| 排序 · 換欄 | `action-tickets-sort-<key2>` | 點擊（`<key>` 的 `order` 非 `none` 時） | `<key>` 的 `order` 回到 `none`、其指示消失；`<key2>` 的 `order` 為 `asc`（自 `none` 起算，不繼承前欄方向）；首列與末列的內容改變；offset 歸零 |
| 切至列表 | `mode-tickets-list` | 點擊 | `state-tickets-list` 出現、`state-tickets-topic` 消失 |
| 切至主題 | `mode-tickets-topic` | 點擊 | 反向；兩模式各自保留自己的 offset |
| 主題節展開收合 | `expander-tickets-topic-<name>` | 點擊 | 該節票行出現或消失 |
| 開票 | `card-tickets-<ticketId>` | 點擊 | jump 至 `nav-page-nodeDetail`；`returnTo` 設為 `tickets` |
| 清單捲動 | `scroll-tickets-list` / `scroll-tickets-topics` | drag / 捲軸 | offset 改變；虛擬捲動下捲動至末端不拋出 framework 錯誤 |
| 損壞徽章 | `badge-tickets-corrupted` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `tickets` |
| 導覽至破洞報告（無 ticket 態） | `action-tickets-goto-gaps` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `tickets` |

**「含損壞」是疊加態不是互斥態**：`badge-tickets-corrupted` 與
`state-tickets-list`（或 `state-tickets-topic`）**同時存在**。整合測試枚舉狀態時
須將其視為正常態的一個修飾，不視為第七個互斥狀態。

#### 篩選下拉的元件級契約（F1–F7）

上表篩選七列描述單次操作的反應；下列契約描述跨操作恆成立的性質，由 SPEC-004
4.13 `FilterDropdown` 單一承擔，呼叫端只提供 `options`、`selected`、`onChanged`。

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| F1 | 任一時刻 | `menu-tickets-filter-*` 至多存在一個（同時只有一個選單展開；開啟另一個下拉的第一次點擊依「點外部收合」列只收合不開啟，需再點一次） |
| F2 | 選單展開時 | 觸發器的選中態只由 `selected` 決定，不因展開改變——`open` 是疊加於 default／active 之上的修飾，不是第三個互斥狀態（判讀同「含損壞」）；斷言：`selected` 非 `null` 時展開前後觸發器皆呈選中態 |
| F3 | 選單展開時（內容契約） | 首項為 `option-tickets-filter-<key>-all`，文字等於 `l10n.filterAllOption`；其後逐項依 `options` 順序，文字等於 `options[i].label`、錨點為 `option-tickets-filter-<key>-<options[i].value>`；`options` 的 `value` 不得為 `all`（該值保留給「全部」，屬呼叫端資料值域約束） |
| F4 | 選單展開時（幾何契約） | 選單為覆蓋層：其 rect 的頂緣等於觸發器 rect 的底緣、左緣等於觸發器左緣；`scroll-tickets-list` 與工具列其餘元素的 rect 在展開前後相同（不擠壓版面）；選單以 `options` 全數展開、選單內不捲動；`kMinWindowSize` 下選單底緣仍在視窗內（元件票以 SPEC-004 4.13 最長 `options` 集代入斷言） |
| F5 | 展開／走選項／收合（任一方式） | 皆不呼叫 `onChanged`；唯一呼叫點是「選取且值改變」（上表選取列）——篩選在選取時一次套用，不在焦點移動時即時套用 |
| F6 | 選單展開時（播報契約） | 選單根節點 `Semantics` 的 `role` 為 `SemanticsRole.menu`；每個選項 `role` 為 `SemanticsRole.menuItem`、label 等於選項文字、`selected` 於目前值項為 `true` 其餘為 `false`（斷言 `tester.getSemantics(find.byKey(...))`）；觸發器 `expanded` 展開時為 `true`、收合後為 `false`；選取後觸發器重建，其 `filterA11yLabel` 的 `{value}` 為新選項文字，重建即為播報載體，不另發 `SemanticsService.announce` |
| F7 | 選單展開期間 | 點擊任何外部元素（含 `nav-item-<d>`、`project-switcher-entry`）皆依「點外部收合」列被吸收，因此選單展開期間不會發生導覽切換或專案切換，§2.8 L1／L2 對選單無額外規定 |

**F7 採吸收而非穿透的理由**：一次點擊只產生一個可斷言的結果（收合），且使用者
為收合選單而點到下層時不會誤觸開票或跳轉；代價是關閉選單後要再點一次才能
執行原本想做的動作。此為本規格的明示決定，不引用平台慣例。

#### 排序欄首的元件級契約（S1–S7）

由 SPEC-004 4.14 `TableColumnHeader.sortable` 與其呼叫端（Ticket 清單畫面）共同承擔：
元件只呈現 `order` 並回呼 `onSort`，循環推進與唯一性由呼叫端維護。

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| S1 | 任一時刻 | `order` 非 `none` 的欄首至多一個——單欄排序，各欄互斥，不存在多欄排序（0.1 明示不做）；呼叫端於 `onSort` 以「設定目標欄、其餘欄歸 `none`」實作 |
| S2 | 每次 `onSort` | 下一個 `order` 只由該欄自身的當前值決定：`none → asc`、`asc → desc`、`desc → none`；換欄一律自 `asc` 起算 |
| S3 | `order` 為 `none` 時 | 列序等於載入完成當下的列序（載入順序即「未排序」的定義，不是任意順序）；欄首無排序指示圖示；朗讀標籤 `{order}` 為 `l10n.sortNone` |
| S4 | 排序改變後（播報契約） | 欄首重建，其 `Semantics.button` 的 label 等於 `sortA11yLabel(label, order)`，`{order}` 依 `order` 為 `l10n.sortNone`／`l10n.sortAscending`／`l10n.sortDescending`（斷言 `tester.getSemantics(find.byKey(Key('action-tickets-sort-<key>'))).label`）；焦點停在該欄首，重建即為播報載體，不另發 `SemanticsService.announce`（與 F6 同一機制） |
| S5 | 排序與篩選／搜尋並存 | 三者獨立：篩選或搜尋改變後 `order` 不變、子集依現行 `order` 排列；排序改變後篩選值與搜尋詞不變 |
| S6 | 切模式 | 排序與篩選只於 `state-tickets-list` 可觸發（SPEC-001 §4 主題模式的可用操作不含之）；切至主題再切回列表，`order`、篩選值、列序皆不變（§2.8 保留） |
| S7 | `static`／`twoLine` 變體（§2 步驟表與 §1 矩陣欄首） | 非互動元素：點擊不產生任何反應且不呈現按鈕形態（同 §3.7 健康徽章的可點性辨識）；不進入 Tab 順序 |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 未載入 → 載入中 → 正常 | cross-fade，`Motion.transition` |
| 進度條推進 | determinate，值來自實際已解析筆數／總數 N；不得自行推進 |
| 已解析筆數文字 | 每 `Motion.progressTick` 更新一次 |
| 列表首次渲染 | 不做逐列入場動畫（虛擬捲動下逐列動畫會在捲動時反覆觸發） |
| 列表 ↔ 主題 | cross-fade，`Motion.transition` |
| 損壞徽章出現 | 無入場動畫（靜態標記） |
| 篩選選單展開 → 收合 | 淡入 + 自觸發器向下展開，`Motion.overlay`；收合反向（與 §3.7 浮層同一手法）；`disableAnimations` 下依 §2.1 歸零 |
| 排序指示切換 | 無動畫（圖示直接替換；三態循環每步皆為離散狀態，中間態無斷言價值） |
| 篩選或排序後的列表重繪 | 無 cross-fade（列表直接重建，理由同「列表首次渲染」列） |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 未載入 | `action-tickets-back` → `returnTo`（`null` 時不渲染，改由 `nav-item-<d>` 承擔退出）；`project-switcher-entry` → 浮層 |
| 載入中 | `action-tickets-cancel-load` → `state-tickets-unloaded`；完成 → `state-tickets-list`；載入中亦可 `nav-item-<d>` 切至其他畫面（載入繼續，見 §2.8 L1） |
| 正常 · 列表 | `nav-item-<d>`；`card-tickets-*` → jump；`project-switcher-entry` |
| 正常 · 主題 | 同上 |
| 無 ticket | `action-tickets-goto-gaps` → jump；`nav-item-<d>`；`project-switcher-entry` |
| 含損壞（疊加） | 同其底層正常態，另加 `badge-tickets-corrupted` → jump 至破洞報告 |

#### 生命週期

| 事件 | 規格 |
|------|------|
| 建構 | 隨 `IndexedStack` 於 App 啟動時建構，但**不觸發解析** |
| 首次可見 | 進入 `state-tickets-unloaded`；解析仍**不觸發**，須使用者按 `action-tickets-start-load`（SPEC-001 §4 的「開始載入」是使用者操作） |
| 切至其他導覽項 | 載入繼續（見 §2.8 L1）；搜尋詞、篩選、排序、模式、offset 全部保留；篩選選單展開時點導覽項只收合選單、不切換（F7），故切換發生時選單必為收合態 |
| 再次可見 | 已載入者直接顯示正常態，不重新解析 |
| 切換專案 | 中止載入；重置為 `state-tickets-unloaded`；搜尋詞與篩選清空；全部欄首 `order` 重置為 `none` |

**未載入態不顯示預估耗時。** SPEC-001 §4 顯示欄含「預估耗時」，但預估耗時的
計算依據屬 CLAUDE.md 現行待決的五項空殼判準之一，尚無定義。依 §2.6 誠實性硬規則，
無依據的時間承諾不得顯示；0.1 只顯示票數 N。此為缺料下的明確決策，非延後。

### 3.5 破洞報告（`nav-page-gaps`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 取消掃描 | `action-gaps-cancel-scan` | 點擊 | 依 §2.5，目標態為 `returnTo` 指定畫面；`returnTo` 為 `null` 時為 `nav-page-domain` |
| 重新掃描 | `action-gaps-rescan` | 點擊 | `state-gaps-none` 或 `state-gaps-found` 消失、`state-gaps-scanning` 出現 |
| 破洞項 | `card-gaps-<itemId>` | 點擊 | **0.1 落地**（`0.1.0-W1-036` 定案，契約見 §2.2「外部開啟契約」）：`ExternalOpener.open(path)` 以系統預設方式開啟該原始檔；**0.1 不定位至行號**（`/usr/bin/open` 無行號參數，定位需依編輯器專屬 URL scheme，行號已顯示於卡片上；追蹤票 `0.1.0-W1-070`）；結果 `opened` → SnackBar `openedExternallyMessage`，停留 `Motion.snackBar` |
| 破洞項（檔案不存在） | 同上 | 點擊 | 結果 `notFound` → SnackBar `sourceFileNotFoundSnackbarMessage`，帶「重新掃描」動作（`rescanAction`），停留 `Motion.snackBarWithAction` |
| 破洞項（無預設應用程式或其他開啟失敗） | 同上 | 點擊 | 結果 `failed` → SnackBar `externalOpenFailedMessage`，停留 `Motion.snackBar`；畫面狀態不變 |
| 分節捲動 | `scroll-gaps-sections` | drag / 捲軸 | offset 改變 |
| 分節收合 | `expander-gaps-<category>` | 點擊 | 該類別的項目出現或消失 |
| 系統通知本體（畫面外） | 無 widget 錨點；由 `ScanNotifier.activated` 事件承載 | 點擊 macOS 通知 | 依 §2.2「系統層通知」點擊導向列：切至 `nav-page-gaps`、`returnTo` 為 `null`，`state-gaps-found` 時定位至第一個 `card-gaps-<itemId>` |
| SnackBar「檢視」動作（權限 `denied` fallback） | `viewGapsAction` | 點擊 | 同上一列 |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 掃描中骨架 | shimmer `Motion.skeletonCycle`；`disableAnimations` 時靜態 |
| 掃描中 → 無破洞 / 有破洞 | cross-fade，`Motion.transition` |
| 重新掃描 | 現有結果立即被骨架取代（不做淡出後再淡入的兩段動畫；舊結果在重新掃描的當下即被使用者意圖判定為待汰換，保留其淡出效果會延長已失效資料的可見時間，且與其餘狀態轉換一律採單段 `Motion.transition` 的手法不一致） |
| 分節收合 | 高度變化 `Motion.transition` |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 掃描中 | `action-gaps-cancel-scan` → `returnTo` 或 `nav-page-domain`；完成 → `state-gaps-none` 或 `state-gaps-found` |
| 無破洞 | `action-gaps-rescan` → `state-gaps-scanning`；`nav-item-<d>` → 其他畫面；`project-switcher-entry` → 浮層 |
| 有破洞 | `action-gaps-rescan` → `state-gaps-scanning`；`card-gaps-*` → 外部開啟（不改變畫面狀態）；`nav-item-<d>`；`project-switcher-entry` |

#### 生命週期

| 事件 | 規格 |
|------|------|
| 首次可見且圖已建立 | 自動進入 `state-gaps-scanning`（SPEC-001 §5 進入條件） |
| 首次可見但圖未建立 | 不自動掃描；0.1 假資料一律預先建立圖，此路徑不出現 |
| 再次可見 | **不重新掃描**，顯示既有結果；要重掃須按 `action-gaps-rescan` |
| 掃描中切至其他導覽項 | 掃描繼續（見 §2.8 L1）；回來時顯示當時進度 |
| 掃描完成時視窗非前景或已離開本頁 | 依 §2.2「系統層通知」發送（權限 `denied` 時走 App 內 SnackBar fallback）；使用者回到本頁時撤回未點擊的通知 |
| 切換專案 | 中止掃描；結果清空；下次可見時重新自動掃描；撤回未點擊的系統通知 |

### 3.6 節點詳情（`nav-page-nodeDetail`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 返回來源畫面 | `action-nodeDetail-back` | 點擊 | 切至 `returnTo`，隨後 `returnTo` 設為 `null`；`returnTo` 為 `null` 時此錨點不渲染 |
| 開啟原始檔 | `action-nodeDetail-open-source` | 點擊 | **0.1 落地**（`0.1.0-W1-036` 定案，契約見 §2.2「外部開啟契約」）：`ExternalOpener.open(path)` 以系統預設方式開啟；結果 `opened` → SnackBar `openedExternallyMessage`，停留 `Motion.snackBar` |
| 開啟原始檔（檔案不存在） | 同上 | 點擊 | 結果 `notFound` → 狀態轉為 `state-nodeDetail-missing`（此為對外部變更的第一手偵測點；不出現 SnackBar，狀態轉換即回饋） |
| 開啟原始檔（無預設應用程式或其他開啟失敗） | 同上 | 點擊 | 結果 `failed` → SnackBar `externalOpenFailedMessage`，停留 `Motion.snackBar`；畫面狀態不變（檔案仍存在，不轉 `missing`） |
| 關聯項 | `card-nodeDetail-relation-<nodeId>` | 點擊 | 主欄內容替換為該節點；`returnTo` **不變**（同一畫面內的節點切換不是跨畫面跳轉） |
| 主欄捲動 | `scroll-nodeDetail-content` | drag / 捲軸 | 主欄 offset 改變、右欄 offset 不變 |
| 右欄捲動 | `scroll-nodeDetail-relations` | drag / 捲軸 | 右欄 offset 改變、主欄 offset 不變 |
| 跳轉破洞報告 | `action-nodeDetail-goto-gaps` | 點擊 | jump 至 `nav-page-gaps`；`returnTo` 設為 `nodeDetail` |
| 重新整理 | `action-nodeDetail-refresh` | 點擊 | 見下方三分支 |

**重新整理的三分支**（`state-nodeDetail-missing` 下）：

| 重新解析結果 | 可觀察結果 |
|------------|-----------|
| 檔案仍不存在 | 維持 `state-nodeDetail-missing`；SnackBar 告知仍不存在，停留 `Motion.snackBar` |
| 檔案存在且解析完整 | 轉為 `state-nodeDetail-normal` |
| 檔案存在但解析有斷點 | 轉為 `state-nodeDetail-partial` |

三分支皆須在 `Motion.cancelDeadline` 內抵達（重新整理是單檔操作，不套用批次載入態）。

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 三個狀態之間 | cross-fade，`Motion.transition` |
| 關聯項點擊造成的主欄內容替換 | cross-fade，`Motion.transition`；主欄 offset 歸零（新節點的舊 offset 無意義），右欄 offset 保留 |
| 損壞欄位標示 | 靜態，不做閃爍 |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 正常 | `action-nodeDetail-back` → `returnTo`；`card-nodeDetail-relation-*` → 同畫面替換內容；`nav-item-<d>` → 其他畫面 |
| 部分損壞 | 同正常，另加 `action-nodeDetail-goto-gaps` → jump |
| 原始檔已消失 | `action-nodeDetail-refresh` → 三分支；`action-nodeDetail-back` → `returnTo`；`nav-item-<d>` |

**經導覽列直接進入本畫面且無選定節點時**，SPEC-001 §6「未選節點」（v1.3 新增，
狀態錨點 `state-nodeDetail-unset`）承接此路徑：渲染空狀態元件，訊息為「尚未選取節點」，
前進動作為 `action-nodeDetail-goto-traceability`（jump 至追溯視圖），
`action-nodeDetail-back` 不渲染。此列已納入 §4 對照表第 30 列。

#### 生命週期

| 事件 | 規格 |
|------|------|
| 建構 | 隨 `IndexedStack` 建構，內容為空（無選定節點） |
| 由 jump 進入 | 主欄與右欄依 payload 的 nodeId 渲染 |
| 切至其他導覽項 | 選定節點、兩欄 offset 保留；`returnTo` 保留 |
| 切換專案 | 選定節點清除；`returnTo` 設為 `null` |

### 3.7 專案切換浮層（覆蓋層，非 `AppDestination`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 入口 | `project-switcher-entry`（既有） | 點擊 | `state-switcher-collapsed` 消失、`state-switcher-expanded`（或 `state-switcher-no-recent`）出現 |
| 最近專案項 | `card-switcher-recent-<index>` | 點擊 | 浮層收合；六頁狀態全部重置；Domain 視圖進入 `state-domain-loading` |
| 不可用的專案項 | 同上 | — | 該項 `enabled` 為 `false`，同列以常駐文字顯示不可用原因（**不用 tooltip**）；其餘項仍 `enabled` 為 `true` |
| 選擇其他 | `action-switcher-choose-folder` | 點擊 | 開啟系統資料夾選擇器；選定後浮層收合並載入；選擇器被取消則浮層維持展開 |
| 點浮層外部 | — | 點擊浮層外任一處 | 浮層收合；不改變當前專案 |
| 按 Esc | — | 按鍵 | 浮層收合；焦點回到 `project-switcher-entry` |
| 清單捲動 | `scroll-switcher-recent` | drag / 捲軸 | offset 改變 |
| 健康徽章 | `badge-switcher-health-<index>` | — | 非互動元素；點擊不產生任何反應且不呈現按鈕形態（§2.2 的可點性辨識） |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 收合 → 展開 | 淡入 + 自入口向下展開，`Motion.overlay` |
| 展開 → 收合 | 反向，`Motion.overlay` |
| 選取專案後的重載 | 浮層先收合（`Motion.overlay`），再由 Domain 視圖轉入載入態；兩段不重疊，使「已選取」與「開始載入」可分別斷言 |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 收合 | 靜止態，無退出路徑（SPEC-001 FR-01 唯一例外） |
| 展開 | `card-switcher-recent-*` → 收合並重載；Esc / 點外部 → 收合 |
| 無最近專案 | `action-switcher-choose-folder` → 收合並載入；Esc → 收合 |

**探測逾時的處理**（SPEC-001 gate 三問的「不確定」路徑）：資料夾可用性探測
逾時的專案項，`enabled` 為 `false`，常駐文字含「可能是磁碟未掛載」的說明。
逾時值不在本規格定義（屬 workspace domain），但**逾時期間浮層仍可操作**：
其餘項的 `enabled` 不受任一項探測未完成的影響。

#### 生命週期

| 事件 | 規格 |
|------|------|
| 展開時機 | 僅由 `project-switcher-entry` 或阻擋狀態的出口觸發，不自動展開 |
| 展開期間 | 焦點限制於浮層內（§2.10）；背景導覽項不可點 |
| 收合後 | `scroll-switcher-recent` 的 offset 不保留（下次展開自頂端） |
| 切換專案期間 | 浮層先收合再開始重載，兩者不並行 |

---

## 4. SPEC-001 全 31 狀態的導航反應對照

本表逐一列出 SPEC-001 §1–§7 的每一個狀態，**無一遺漏**，並將其退出路徑欄
對應到本規格定義的導航反應與觸發錨點。此表即 acceptance「每個狀態的退出路徑
皆對應到一個已定義的導航反應」的驗證對象。

| # | 畫面 | 狀態 | 狀態錨點 | SPEC-001 退出路徑 | 導航反應（觸發錨點 → 結果） |
|---|------|------|---------|------------------|---------------------------|
| 1 | Domain | 未選專案 | `state-domain-unset` | 選擇資料夾 → 載入中 | 同畫面轉換：`action-domain-choose-folder` → `state-domain-loading` |
| 2 | Domain | 載入中 | `state-domain-loading` | 取消 → 未選專案；完成 → 正常／空圖／不是框架專案／無可消費的型別表／schema 不相容 | 同畫面轉換：`action-domain-cancel-load` → `state-domain-unset`（§2.5）；解析完成 → `state-domain-matrix`、`state-domain-empty`，或三個阻擋狀態之一（`state-domain-not-framework` / `state-domain-schema-unconsumable` / `state-domain-schema-incompatible`，三者進入條件皆發生於資料夾已選定之後，見 SPEC-001 §1 註記） |
| 3 | Domain | 正常 · 矩陣 | `state-domain-matrix` | 導覽至其他畫面、切換專案 | rail：`nav-item-<d>` → 對應頁；覆蓋層：`project-switcher-entry` → `state-switcher-expanded` |
| 4 | Domain | 正常 · 泳道 | `state-domain-swimlane` | 切回矩陣、導覽、切換專案 | 同畫面轉換：`mode-domain-matrix` → `state-domain-matrix`；rail；覆蓋層 |
| 5 | Domain | 空圖 | `state-domain-empty` | 切換專案、導覽至破洞報告 | 覆蓋層：`project-switcher-entry`；jump：`action-domain-goto-gaps` → `nav-page-gaps`，`returnTo`=domain |
| 6 | Domain | 不是框架專案 | `state-domain-not-framework` | 切換專案（浮層維持可用） | 覆蓋層：`project-switcher-entry`（`enabled` 恆為 `true`） |
| 7 | Domain | 無可消費的型別表 | `state-domain-schema-unconsumable` | 切換專案；以 App 內建型別表檢視 → 正常／空圖 | 覆蓋層：`project-switcher-entry`；同畫面轉換：`action-domain-degraded-view` → `state-domain-matrix`／`state-domain-empty` 疊加 `badge-domain-degraded-schema`（§3.1，條件式渲染） |
| 8 | Domain | schema 不相容 | `state-domain-schema-incompatible` | 切換專案（浮層維持可用） | 覆蓋層：`project-switcher-entry`；同畫面展開：`action-domain-schema-detail` → `panel-domain-schema-detail` |
| 9 | UC Flow | 無 UC | `state-ucFlow-empty` | 導覽、切換專案 | jump：`action-ucFlow-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 10 | UC Flow | flow 未結構化 | `state-ucFlow-unstructured` | 開啟原始檔、返回 Domain 視圖 | 固定目標：`action-ucFlow-back-to-domain` → `nav-page-domain`（不用 `returnTo`）。`action-ucFlow-open-source` 為外部動作，不計為導航反應 |
| 11 | UC Flow | 正常 | `state-ucFlow-normal` | 導覽、切換專案 | rail；jump：`card-ucFlow-step-*` → `nav-page-nodeDetail`、`action-ucFlow-goto-domain-*` → `nav-page-domain`；覆蓋層 |
| 12 | 追溯 | 正常 | `state-traceability-normal` | 導覽、切換專案 | rail；jump：`card-traceability-*` → `nav-page-nodeDetail`；覆蓋層 |
| 13 | 追溯 | 鏈路斷裂 | `state-traceability-broken` | 同上 | 同 #12，另加 jump：`action-traceability-goto-gaps` / `badge-traceability-broken-*` → `nav-page-gaps`（「跳轉破洞報告」在 SPEC-001 §3 屬可用操作欄而非退出路徑欄，退出路徑欄與正常態相同，皆為「導覽、切換專案」） |
| 14 | 追溯 | 無提案 | `state-traceability-empty` | 導覽、切換專案 | jump：`action-traceability-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 15 | Ticket | 未載入 | `state-tickets-unloaded` | 返回上一畫面、切換專案 | 返回：`action-tickets-back` → `returnTo`（`null` 時不渲染，退出由 rail 承擔）；覆蓋層 |
| 16 | Ticket | 載入中 | `state-tickets-loading` | 取消 → 未載入；完成 → 正常 | 同畫面轉換：`action-tickets-cancel-load` → `state-tickets-unloaded`（§2.5）；完成 → `state-tickets-list`；rail 可離開且載入繼續（見 §2.8 L1） |
| 17 | Ticket | 正常 · 列表 | `state-tickets-list` | 導覽、切換專案 | rail；jump：`card-tickets-*` → `nav-page-nodeDetail`；覆蓋層 |
| 18 | Ticket | 正常 · 主題 | `state-tickets-topic` | 同上 | 同 #17，另加同畫面轉換 `mode-tickets-list` → `state-tickets-list` |
| 19 | Ticket | 無 ticket | `state-tickets-empty` | 導覽、切換專案 | jump：`action-tickets-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 20 | Ticket | 含損壞（疊加於 #17／#18） | `badge-tickets-corrupted` | 同正常 | 繼承其底層正常態的全部退出路徑，另加 jump：`badge-tickets-corrupted` → `nav-page-gaps` |
| 21 | 破洞 | 掃描中 | `state-gaps-scanning` | 取消 → 返回；完成 → 有／無破洞 | rail 語意的返回：`action-gaps-cancel-scan` → `returnTo` 指定頁；`returnTo` 為 `null` 時 → `nav-page-domain`（「返回」的目標由本規格定義）；同畫面轉換：掃描完成 → `state-gaps-none` 或 `state-gaps-found` |
| 22 | 破洞 | 無破洞 | `state-gaps-none` | 導覽、切換專案 | 同畫面轉換：`action-gaps-rescan` → `state-gaps-scanning`；rail；覆蓋層 |
| 23 | 破洞 | 有破洞 | `state-gaps-found` | 導覽、切換專案 | 同 #22。`card-gaps-*` 為外部開啟動作，不計為導航反應 |
| 24 | 節點詳情 | 正常 | `state-nodeDetail-normal` | 返回來源畫面、點關聯跳轉 | 返回：`action-nodeDetail-back` → `returnTo`；同畫面替換：`card-nodeDetail-relation-*`；rail |
| 25 | 節點詳情 | 部分損壞 | `state-nodeDetail-partial` | 同正常 | 同 #24，另加 jump：`action-nodeDetail-goto-gaps` → `nav-page-gaps` |
| 26 | 節點詳情 | 原始檔已消失 | `state-nodeDetail-missing` | 返回、重新整理 | 返回：`action-nodeDetail-back` → `returnTo`；同畫面轉換：`action-nodeDetail-refresh` → 三分支（§3.6） |
| 27 | 浮層 | 收合 | `state-switcher-collapsed` | 靜止態（SPEC-001 FR-01 唯一例外） | 進入：`project-switcher-entry` → `state-switcher-expanded`。本列不要求退出路徑 |
| 28 | 浮層 | 展開 | `state-switcher-expanded` | 選取 → 收合並重載；Esc／點外部 → 收合 | 覆蓋層關閉：`card-switcher-recent-*` → 收合 + 全域重置 + `state-domain-loading`；Esc／點外部 → `state-switcher-collapsed` |
| 29 | 浮層 | 無最近專案 | `state-switcher-no-recent` | 選取 → 收合並載入；Esc → 收合 | 覆蓋層關閉：`action-switcher-choose-folder` → 收合 + `state-domain-loading`；Esc → `state-switcher-collapsed` |
| 30 | 節點詳情 | 未選節點 | `state-nodeDetail-unset` | 前往追溯視圖 | jump：`action-nodeDetail-goto-traceability` → `nav-page-traceability`，`returnTo`=nodeDetail；rail；`action-nodeDetail-back` 不渲染 |
| 31 | Domain | 已選格（疊加於 #3） | `panel-domain-cell-detail` | 點其他格 → 換內容；Esc → 未選格；在泳道中檢視 → 正常 · 泳道；導覽、切換專案 | 同畫面轉換：Esc / `action-domain-cell-clear` → `panel-domain-cell-detail-empty`；`cell-domain-*` → 內容替換；`action-domain-cell-goto-swimlane` → `state-domain-swimlane`；繼承 #3 的 rail 與覆蓋層 |

**覆蓋完整性**：31 列，對應 SPEC-001 §1（9）+ §2（3）+ §3（3）+ §4（6）+ §5（3）
+ §6（4）+ §7（3）= 31。每一列的導航反應欄皆非空，且皆指向一個具名錨點。
#30、#31 為 SPEC-001 v1.3／v1.4 新增，依 SPEC-001 §狀態總數 的順序編號，不重排既有列。

**同步提醒**：本節標題、本段算式、下方 FR-01 驗收、§0 概述四處皆耦合 SPEC-001
§狀態總數 的狀態數字（現為 31）。SPEC-001 日後新增或刪除狀態時，四處須同步更新，
缺一處會使對照表列數與 FR-01 驗收範圍失去覆蓋完整性保證。

---

## 5. 規格判讀註記

本節記錄本規格對 SPEC-001 措辭所做的判讀。這些判讀是實作與測試的依據，
若 SPEC-001 日後修訂與此不符，以 SPEC-001 為準並更新本節。

| SPEC-001 措辭 | 本規格的判讀 |
|--------------|-------------|
| §5 掃描中「取消 → 返回」 | 「返回」的目標未具名。判讀為 `returnTo`，`null` 時為 Domain 視圖（App 的預設落地頁） |
| §4 未載入「返回上一畫面」 | 同上判讀。`returnTo` 為 `null` 時返回錨點不渲染，退出由導覽列承擔 |
| §2 flow 未結構化「開啟原始檔、返回 Domain 視圖」 | 「開啟原始檔」是外部動作，不改變畫面狀態，嚴格說不是退出路徑。該狀態的實際導航退出為「返回 Domain 視圖」，非空 |
| §4 含損壞「同正常」 | 判讀為疊加態而非互斥態：損壞徽章與正常視圖同時渲染 |
| §1 無可消費的型別表「以 App 內建型別表檢視」（SPEC-001 v1.5 起現行文字） | 判讀為條件式渲染的同畫面轉換：`VERSION` 不高於內建表產生版本時渲染 `action-domain-degraded-view`，目標為正常／空圖並疊加 `badge-<screen>-degraded-schema`（六畫面皆常駐）；高於時不渲染（依 §2.2 形態 a），退出由「切換專案」單獨承擔。判讀沿革：v1.4 以前該欄為「（若支援降級）以純檔案模式檢視」，括號表示未定案，0.1 曾判為不渲染；`0.1.0-W1-035` 定案後改為現行判讀 |
| §4 未載入「預估耗時」 | 預估依據屬待決事項，0.1 不顯示（依 §2.6 誠實性硬規則），只顯示票數 N |
| FR-02 驗收「三處長時操作期間」（SPEC-001 v1.3 起現行文字） | 三處（Domain 視圖載入、Ticket 載入、破洞掃描）與本規格 §2.5 取消契約定義的三個目標態逐一對應，現行文字已與本規格一致；此列存留判讀沿革——SPEC-001 v1.2 以前僅列「Ticket 載入與破洞掃描」兩處，遺漏 §1 Domain 視圖載入中的取消操作，該缺口已於 SPEC-001 v1.3 補齊 |
| §6 三個狀態的進入條件 | 皆預設已有選定節點。經導覽列直接進入時的缺口已由 SPEC-001 v1.3「未選節點」補上，本規格 §3.6 與 §4 第 30 列對應之 |
| §1 已選格「點格子→已選格」 | 「點格子」判讀為單擊；切泳道改由詳情卡內按鈕承擔（§3.1 四案比較，PM 核定）。若 PM 改採他案，本規格 §3.1 兩列改寫，SPEC-001 §1 可用操作欄同步 |
| §1 三個阻擋狀態（不是框架專案／無可消費的型別表／schema 不相容） | 「阻擋狀態」是畫面狀態的一種（這個專案不適用本 App），與 §2.12 的「輸入阻擋範圍」不是同一件事——後者指等待期間畫面是否吸收使用者輸入。兩者的驗收不共用：前者落在 §2.7 與 FR-01（退出路徑錨點），後者落在 FR-14。此列存留以防讀者因用字相同而把兩者的驗收互相代入 |
| §1、§4、§5 三處載入中的「取消」 | SPEC-001 只述取消是可用操作，未述載入期間其餘輸入如何處理。判讀為 §2.12 長時操作類的「阻擋頁面內容」：內容區正常態錨點不存在、導覽列恆可點（§2.8 L1）、取消錨點存在。取消本身的行為驗收落在 FR-02，阻擋範圍的驗收落在 FR-14 |

---

## 功能需求

### FR-01: 每個狀態的退出路徑皆有具名觸發錨點

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | §4 對照表 31 列，導航反應欄皆非空且皆含一個具名錨點；整合測試對每一列執行「渲染該狀態 → 觸發錨點 → 斷言目標狀態錨點存在」；浮層收合態（#27）為唯一豁免 |

### FR-02: 取消契約的十條行為全部成立

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | 三處載入態（`state-domain-loading`／`state-tickets-loading`／`state-gaps-scanning`）各自通過 §2.5 的 C1–C8 與 §2.8 的 L1–L2（共 10 條）；C4 以 `tester.pump(Motion.cancelDeadline)` 推進假時鐘後斷言，不得使用 `Stopwatch` 加 `lessThan` |

### FR-03: 導航來源以單槽記錄，返回目標唯一

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | `rail` 切換後 `returnTo` 為 `null`；`jump` 切換後 `returnTo` 等於跳轉前 destination；連續兩次 jump 後 `returnTo` 等於最近一次來源；`returnTo` 為 `null` 時返回錨點不存在於元件樹 |

### FR-04: 惰性載入以首次可見觸發、切換導覽項保留狀態

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | App 啟動並 settle 後 Ticket 清單的解析計數為 0；切至 Ticket 清單再切走再切回，`scroll-tickets-list` 的 offset、搜尋詞、當前模式與離開前相同；切換專案後三者皆重置 |

### FR-05: 時間值皆具名，且減少動態效果時仍抵達目標態

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | `lib/`（`lib/tokens/` 除外）grep 不到 `Duration(milliseconds:` 或 `Duration(seconds:` 後方接字面數字；`disableAnimations` 為 `true` 時，每個狀態轉換在 `pump()` 一幀後即抵達目標狀態錨點 |

### FR-06: 未接線動作不得以無回饋佔位 handler 上線

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | 每個可點錨點的點擊皆產生下列之一：狀態錨點改變、`IndexedStack` 索引改變、SnackBar 出現、外部程序被呼叫。無上述任一者的錨點必須 `enabled` 為 `false` 並在同一列有常駐說明文字，或根本不渲染 |

### FR-07: 進度指示誠實

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | `state-domain-loading` 與 `state-gaps-scanning` 的畫面中不存在 `%` 字元、不存在帶非 null `value` 的進度指示；`state-tickets-loading` 的進度值等於已解析筆數除以未載入態顯示的 N；三者皆不顯示預估剩餘時間 |

### FR-08: 捲動、換頁、拖拉三類互動逐一可斷言

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | §1.1 的 11 個捲動錨點各自通過「drag 後 offset 改變」；§1.2 的三類換頁各自通過「觸發後目標錨點存在且來源錨點不存在」；§1.3 的 `drag-domain-swimlane` 通過「平移量等於位移」；對非拖曳元素 drag 的結果是其所在容器捲動 |

### FR-09: 焦點與鍵盤下界

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | Tab 可依 §2.10 順序走遍全部可用操作且每一步有可見焦點指示；浮層展開時 Tab 不離開浮層；Esc 收合浮層與 schema 詳情面板；Esc 收合篩選選單且焦點回到其觸發器，選單內 ↑／↓ 移動焦點而不呼叫 `onChanged` |

### FR-10: 兩個獨立捲動區不連動

| 項目 | 值 |
|------|-----|
| 優先級 | P2 |
| 驗收 | 節點詳情主欄捲動後右欄 offset 不變；反之亦然 |

### FR-11: 掃描完成的系統層通知

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | §2.2「系統層通知」測試斷言表十二列全部成立：觸發條件（非前景或已離開頁）成立才發送、每次掃描至多一則、回頁／重掃／切換專案撤回、權限三路徑各走對應 fallback、點擊通知切頁並定位 |

### FR-12: 第一層回饋不因服務狀態而免除（INV-FEEDBACK-001）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | 四項全部成立。(a) 對每個可點錨點，注入永不受理的服務替身後 `tap` 並 `pump(Motion.feedback)`：該元素的 pressed 視覺存在，且其回調恰被呼叫一次（替身角色的定義見 `.claude/skills/tdd/references/layered-test-strategy.md`〈不變式 INV-FEEDBACK-001 的驗證形態〉段）。(b) 於 `Motion.searchDebounce` 未推進的同一窗口內連續 `tap` 同一錨點 N 次，每次 `pump` 後 pressed 視覺各自存在，且回調累計恰 N 次——元件不代服務丟棄任何一次。(c) `input-tickets-search` 於防抖窗口內 `enabled` 恆為 `true`，且每個輸入字元在同一幀即出現於其 `TextEditingValue.text`。(d) 全畫面掃描：`enabled` 為 `false` 的元件其 `disabledReason` 皆不得表述服務側的防抖、節流或呼叫被丟棄；0.1 唯一合法的停用場景為 `LoadingState` 的取消鈕（§2.5 C2）。時間推進一律以假時鐘，禁用 `Stopwatch` 加 `lessThan`（與 FR-02 的 C4 同一約束） |

### FR-13: 每一類服務的回饋形式依 §2.12 政策對照表成立

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | 四類逐一成立。**長時操作**：三處觸發後 `pump()` 一幀內對應載入態錨點（`state-domain-loading`／`state-tickets-loading`／`state-gaps-scanning`）存在，且含 §2.6 指定的計數或進度文字。**短暫非同步**：四處外部開啟錨點（`action-domain-open-docs`、`action-ucFlow-open-source`、`card-gaps-<itemId>`、`action-nodeDetail-open-source`）× `ExternalOpener` fake 的三個結果值（`opened`／`notFound`／`failed`）共十二個組合，每一個組合的第三層回饋皆非空，且等於該畫面 §3.x 互動反應表對應列所指定的結果——SnackBar 文字等於該列具名的 i18n key 的值，或該列指定的狀態錨點改變（例如 §3.6 的 `notFound` 為轉入 `state-nodeDetail-missing` 且不出現 SnackBar）；同一組合下畫面中不存在任何載入態錨點（該類不提供第二層）。**延遲觸發**：`pump(Motion.searchDebounce)` 前後皆不存在載入態錨點，結果為清單筆數改變。**本地即時**：觸發後 `pump()` 一幀內狀態錨點改變，且不存在載入態錨點與 SnackBar |

### FR-14: 等待期的輸入阻擋範圍依服務類型成立

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | 兩組皆成立。**長時操作（阻擋頁面內容）**：三處載入態渲染期間，該畫面內容區的正常態互動錨點皆不存在於元件樹（已被載入態取代），而六個 `nav-item-<d>` 皆存在且 `enabled` 為 `true`（§2.8 L1：離開不取消任務）；同期間該畫面的取消錨點存在——取消的可用性、時限與其後續行為由 FR-02（§2.5 C1–C8 與 §2.8 L1–L2）承擔驗收，本條只斷言「阻擋期間取消錨點存在」，不重複斷言其行為。**其餘三類（不阻擋）**：本地即時、延遲觸發、短暫非同步的觸發後 `pump()`，畫面中不存在覆蓋內容區的載入態錨點，觸發當時可見的其他互動錨點仍存在且 `enabled` 為 `true`；`input-tickets-search` 於防抖窗口內可繼續接受輸入，連續輸入的字元皆進入其 `TextEditingValue.text` |

### FR-15: 重複觸發防護由服務承擔，元件不實作

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 驗收 | 四項全部成立。(a) 靜態原始碼掃描：`lib/components/` 之下不出現 `Timer(` 或 `Timer.periodic(`——防抖與節流的計時器不得位於元件層；日後元件若有非防抖用途的計時需求，須於本條列出豁免對象，不得逕自新增。(b) `SearchField` 每次非組字文字變更呼叫 `onChanged` 恰一次且不延遲：連續輸入 N 個字元、不推進假時鐘，`onChanged` 計數即為 N。(c) 防抖在服務層可驗：搜尋詞 provider 於 `pump(Motion.searchDebounce)` 之前過濾結果未更新，之後恰更新一次。(d) 短暫非同步的冪等：對同一 `ExternalOpener` fake 連續觸發 N 次，其 `calls` 長度為 N，不出現排隊、阻擋或呼叫被合併。長時操作的「禁用觸發來源」以入口不存在實現，其斷言併入 FR-14 的內容區錨點不存在一項，本條不重複 |

---

## 設計約束

- 本規格描述行為與時間，不描述視覺樣式；顏色、字級、間距、圓角以 SPEC-002 為準
- 時間值一律具名於 `lib/tokens/motion.dart`，該檔是唯一允許出現時間字面值的位置
- 取消契約由 SPEC-002 的「載入態」元件單一承擔，三個畫面以參數（目標態、進度型別）
  差異化，不各自實作
- 導航來源記錄為單槽而非堆疊；若日後導入 deep link 或多視窗，此決策須重新評估，
  屆時 §2.3 的四條規則是重評的起點
- 0.1 的互動全部以假資料驅動。假資料須使每個狀態可被單獨渲染（狀態注入而非
  等待真實解析），否則 §4 對照表的 31 列無法逐列斷言
- 泳道的拖曳是版型行為，與布局演算法無關；0.1 的泳道以寫死座標的假資料畫出，
  拖曳只驗證平移，不驗證排列品質（SPEC-001 §設計約束已定案）
- 用語決定：本規格全文統一使用「渲染」描述元件樹的產出動作，不改為「算繪」
  （`0.1.0-W1-010` 多視角審查提出的 Info 層級建議）。理由：「渲染」是本規格與
  既有 Flutter 程式碼（widget 樹建構）既定用語，全文已出現逾三十次；「算繪」
  在中文語境慣用於指涉 3D／影像運算（render farm、算繪引擎），與本規格描述的
  UI 元件樹建構不同層次，改用僅造成與既有引用（如跨檔 grep 比對）的不一致，
  無語意增益

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.13 | 2026-09-09 | §2.2 追加子節「兩個 port 的三時刻覆蓋」（`0.1.0-W3-149`，來源 `0.1.0-W3-139` SR-2）：`ScanNotifier` 與 `ExternalOpener` 是本 App 的兩個 driven port，其契約已在 §2.2 但缺三時刻的顯式覆蓋。新增內容為——`ScanNotifier` 四個方法（`authorizationStatus` / `requestAuthorization` / `show` / `withdraw`）逐一列出各時刻承載者（受理時刻不適用，MethodChannel 為 fire-and-wait）；`show` 與 `withdraw` 回傳 `void` 明寫為設計選擇（畫面已完成 cross-fade、呼叫端無分支可走，屬呼叫端消費者被刻意排除，非以日誌抵扣呼叫端）並附失效條件；`ExternalOpener` 新增**呼叫發出時刻的日誌義務**，寫為可驗收形態（記錄時機須在「前置檢查」列的 `FileSystemEntity.type` 之前、`developer.log` info 等級、欄位為傳入絕對路徑一項、驗收為 `open` 方法體第一個語句），依 `INV-PORT-OBSERVE-001`——原「失敗可觀測」列只涵蓋 `failed`，外部程序掛住不回時整次呼叫零記錄；並記錄現行臨時實作（`gap_report_screen.dart` 的 `_runOpen`）入口 log 在 `existsSync` 前置檢查之後、`notFound` 分支無記錄，`0.1.0-W1-068` 須移前。監控追蹤欄依 `docs/tech-decisions.md`「2026-08-27：執行期 log 的裁決」寫為 structured log 於 0.1 維持延後並保留重評條件，不寫 N/A。三時刻定義與 `INV-PORT-OBSERVE-001` 以標題文字引用方法論不重述。**未後移既有 §2.x 編號**（`0.1.0-W3-108` 實證 SPEC-004 有大量 `SPEC-003 §2.x` 跨檔引用）；不改 SPEC-001 與 SPEC-004；不新增時間 token、狀態與錨點類別 |
| 1.12 | 2026-09-09 | §2.12 的功能需求條目補齊（`0.1.0-W3-145`，來源 `0.1.0-W3-108` SR-1，PM 裁定新增）：v1.11 寫入 §2.12 但該章不在 FR-01～FR-11 任一條的驗收範圍內。經逐項判定 §2.12 的四項規範主張皆未被既有條目涵蓋且兩兩可獨立失效，新增四條——FR-12（第一層回饋不因服務狀態而免除，驗收含「注入永不受理的服務替身後 pressed 視覺仍存在」「防抖窗口內連按 N 次回調累計 N 次」「防抖窗口內 `input-tickets-search` 恆 `enabled`」「無元件以服務側防抖為 `disabledReason`」）、FR-13（逐服務類型的回饋形式，長時操作三處載入態錨點、短暫非同步四錨點 × 三結果值共十二組合的第三層回饋皆非空且等於 §3.x 對應列所指定者、延遲觸發與本地即時皆無載入態錨點）、FR-14（輸入阻擋範圍，長時操作期間內容區正常態錨點不存在而六個 `nav-item-<d>` 恆 `enabled`，其餘三類不阻擋）、FR-15（重複觸發防護由服務承擔，`lib/components/` 靜態掃描不出現 `Timer(`、`SearchField` 每次變更呼叫 `onChanged` 恰一次且不延遲、防抖在 provider 層可驗、外部開啟冪等）。**「阻擋頁面內容時必須同時提供取消」不另立條目**，其驗收落在既有 FR-02，於 §2.12 該段與新增的「本節的功能需求對應」表明列歸屬。編號續接以 `rg -o 'FR-[0-9]+' docs/ lib/ test/` 實查得出（排除 `test/fixtures/corpus/` 的假語料庫，其 FR-12／FR-013 屬另一專案的編號空間），既有最大號為 FR-11。概述的 FR 範圍句同步為 FR-01～FR-15；§5 判讀註記新增兩列（「阻擋狀態」與「輸入阻擋範圍」用字相同但驗收不共用；載入中的取消判讀為長時操作類阻擋政策）。不改 SPEC-001 與 SPEC-004；不新增時間 token、狀態與錨點類別 |
| 1.11 | 2026-09-09 | 服務類型與等待期政策定案（`0.1.0-W3-108`，來源 `0.1.0-W3-105` 用戶裁示 2026-09-08）：新增 §2.12「服務類型與等待期政策」——以「使用者感知的等待長度」與「失敗形態」兩軸（不以同步／非同步切）分出本地即時／延遲觸發／短暫非同步／長時操作四類，各附與相鄰類的政策差異點；政策對照表逐類型定回饋形式（依 §2.2 承擔者欄分列第二層與第三層）、輸入阻擋範圍、重複觸發防護三欄；輸入阻擋三選一判準（不阻擋／禁用觸發來源／阻擋頁面內容），阻擋範圍限內容區不含導覽列，阻擋頁面內容者必須同時提供取消（由 §2.5 C1／C4 承擔）；重複觸發防護的承擔者一律是服務，元件不實作防抖／節流／冪等，並記 `Motion.searchDebounce` 改由 provider 消費（`0.1.0-W3-110`）；不變式 INV-FEEDBACK-001（元件每一次互動都必須發出第一層回饋，即使服務丟棄該次呼叫）含三列可觀察條件、Why（`ARCH-GPD-001` 形態）、Consequence 與三條規格層判準，機械檢查方式引用 `layered-test-strategy.md`〈不變式 INV-FEEDBACK-001 的驗證形態〉段而不在本規格重複定義（`DOC-005`）。§2.2 三層回饋落地表新增「承擔者」欄（互動元件自身／服務／event 處理路徑），並明寫第一層不因服務不可用或呼叫被丟棄而免除，與 §2.12 對接。回饋形式全部對應既有元件，不新增元件；§2.11 元件庫對應的載入態與 SnackBar 兩列各補 §2.12 承擔範圍。不改 SPEC-001 與 SPEC-004；不新增時間 token、狀態、錨點類別與 FR（§2.12 是否需獨立 FR 交 PM 核定，見 `0.1.0-W3-108` spawn request） |
| 1.10 | 2026-09-08 | `0.1.0-W3-069`：§3.1 動畫提示表列名「格選中態出現」改為自足形式「矩陣格的選取標記出現」（原列名壓縮掉三個限定語——哪種格、選取標記為持續性標記、出現指狀態從無到有的時機，讀者須跨節查 §3.1 標題與元件才能還原；判準見 DOC-GPD-004）。「形式」欄內容不動。全檔其餘表格列名逐一判定後皆保留（判定表見票 `0.1.0-W3-069` Solution）：§3.3 動畫提示「缺口虛線框」、§3.4「損壞徽章出現」「已解析筆數文字」、§3.6「損壞欄位標示」、§2.2「不發送」、§2.8「六頁建構時機」、§2.10「按 Esc」等，皆在所屬子節的表頭語境內自足或為跨檔引用錨點，不改。本改動同步 SPEC-004 三處逐字引用錨點（v1.26） |
| 1.9 | 2026-09-08 | 系統層通知定案（`0.1.0-W3-063`，用戶簽核 2026-09-08：0.1 掃描完成時元件不在視野則升級 macOS 系統通知）：§2.2 新增「系統層通知」子節——適用範圍限破洞掃描完成；觸發條件為完成當下視窗非前景（`AppLifecycleState` 非 `resumed`）或可見頁非 `nav-page-gaps`，兩者皆否則不發；不發送情境（取消、切換專案、未完成、已發過）；通知內容 key（`scanCompleteNotificationTitle` / `scanCompleteNotificationBody` / `scanCompleteNoGapsNotificationBody`，不含路徑與明細、無動作按鈕）；點擊導向（切至 `nav-page-gaps`、`returnTo` 為 `null`、依 SPEC-004 §1 locate 列定位第一個 `card-gaps-<itemId>`）；不重複發送與三種撤回時機（回頁、重掃、切換專案）；權限 gate 三路徑（`granted` 發送；`denied` 不再請求、0.1 不引導系統設定、fallback 為 `AppSnackBar.withAction` `scanCompleteSnackbarMessage` + `viewGapsAction`、非前景時延後至 `resumed`；`notDetermined` 於首次觸發時即時請求；其他結果視為 `denied`）；`ScanNotifier` 抽象與 fake 斷言十二列；i18n 六個 key；實作票驗證清單（`UNUserNotificationCenter` 沙盒關閉可用性、Flutter 載體、macOS 生命週期對應、撤回 API）。持續性 App 內指示（Banner／導覽項徽章）0.1 不提供，元件庫缺件交 PM 核定。§2.11 補 `AppSnackBar.withAction` 承擔列；§3.5 互動反應補系統通知本體與 SnackBar 動作兩列、生命週期補完成時非前景列並於切換專案列補撤回；新增 FR-11；概述 FR 範圍同步為 FR-01～FR-11。不改 SPEC-001；SPEC-004 §1 state-change 列由同票改為引用本節 |
| 1.8 | 2026-09-03 | 外部開啟落地定案（`0.1.0-W1-036`）：§2.2 新增「外部開啟契約」（`ExternalOpener` 介面與 `opened` / `notFound` / `failed` 三結果、前置存在檢查、`/usr/bin/open` 實作、不新增依賴、失敗 log、無等待指示、0.1 不定位行號、fake 斷言方式、i18n key；實作票 `0.1.0-W1-068`）。§3.1 開啟 docs 目錄、§3.2 與 §3.6 開啟原始檔、§3.5 破洞項四處的既有列改為引用契約結果值，並各新增一列「無預設應用程式或其他開啟失敗」→ SnackBar `externalOpenFailedMessage`；§3.5 明示 0.1 不定位至行號（追蹤票 `0.1.0-W1-070`）；§3.6 檔案不存在列補「不出現 SnackBar」。新增 i18n key `externalOpenFailedMessage`（補齊票 `0.1.0-W1-069`）。不改其他列；不改 SPEC-001 與 SPEC-004 |
| 1.7 | 2026-09-03 | 降級策略同步（`0.1.0-W1-035`，對應 SPEC-001 v1.5）：§3.1 導航跳轉「無可消費的型別表」列由「0.1 不渲染」改為條件式渲染 `action-domain-degraded-view`（同畫面轉換至正常／空圖，疊加 `badge-domain-degraded-schema`）；§4 第 7 列同步；§5 判讀註記該列改為現行判讀並保留沿革。不新增狀態、錨點類別與時間 token。不改 SPEC-004（其 `BlockedState` 三處「0.1 不渲染」引用由後續 DOC 票同步） |
| 1.6 | 2026-09-02 | 元件級互動補件（`0.1.0-W1-057`，來源 `0.1.0-W1-044.2` NeedsContext）：§3.4 互動反應表「篩選」一列展開為開啟／走選項／選取／Esc 收合／點外部收合／再點觸發器／Tab 離開七列，「排序」一列展開為循環／換欄兩列，每列含錨點與可觀察結果；新增「篩選下拉的元件級契約 F1–F7」（同時至多一個選單、`open` 為疊加態、選單內容契約含 `all` 首項、覆蓋層幾何契約、只在選取時呼叫 `onChanged`、`SemanticsRole.menu`／`menuItem` 播報契約、點外部一律吸收）與「排序欄首的元件級契約 S1–S7」（單欄排序、`none → asc → desc → none` 三態循環、`none` 等於載入順序、`sortA11yLabel` 播報值、與篩選／搜尋獨立、只於列表模式可觸發、`static`／`twoLine` 非互動）。§2.9 新增選單 `menu-<screen>-<kind>` 與選單項 `option-<screen>-<kind>-<value>` 兩類錨點；§2.10 新增選單 Esc 與方向鍵／Tab 兩列並明示選單不限制焦點、方向鍵走選項不在 0.1 排除範圍；§1.4 同畫面內展開由 2 增為 3；§2.11 補兩個元件的承擔對應；§3.4 動畫提示補選單展開收合（`Motion.overlay`）、排序指示切換與列表重繪皆無動畫三列；§3.4 生命週期補選單展開時點導覽項不切換、切換專案重置 `order`；FR-09 驗收補選單 Esc 與方向鍵。不新增時間 token（選單沿用 `Motion.overlay`，排序沿用 `Motion.feedback`）。不改 SPEC-001 與 SPEC-004；SPEC-004 4.13／4.14 的待決標記由 W1-005 對應子票代入本版內容後去除。 |
| 1.5 | 2026-09-02 | 對照表與 SPEC-001 同步修訂（`0.1.0-W1-039.4`，父票 `0.1.0-W1-039` 十四項審查發現第 4、12、13、14 項，本票是 039 系列最後一張）：§4 對照表第 2 列補三個阻擋狀態為「載入中」完成後的可能落點（與 SPEC-001 §1 註記一致）；第 13 列移除誤植入 SPEC-001 退出路徑欄的「跳轉破洞報告」（該項在 SPEC-001 §3 屬可用操作欄，非退出路徑欄），退出路徑欄改回與正常態一致的「同上」；第 21 列補「掃描完成 → 有／無破洞」的同畫面轉換描述於導航反應欄。§4 覆蓋完整性算式後新增同步提醒，明列與狀態數字（31）耦合的四處（本節標題、本段算式、FR-01 驗收、§0 概述）。§5 判讀註記更新 FR-02 一列為現行 SPEC-001 v1.3 起文字（三處長時操作期間），原「兩處」判讀改列為判讀沿革記錄。設計約束段新增用語決定：全文統一用「渲染」不改「算繪」，並附理由（既定用語、全文逾三十次引用、避免與 3D／影像運算語境混淆）。全文檢核無指向一次性審查報告的引用（原第 626 行問題已由 `0.1.0-W1-039.1`～`.3` 與 `0.1.0-W1-048` 修訂消除）。 |
| 1.4 | 2026-09-02 | 返回語意與導覽修訂（`0.1.0-W1-039.3`）：§2.4 更名為「退出路徑的四種導航反應」，新增「返回（consume）」為獨立第四類（既有 rail／jump／同畫面狀態轉換三類皆無法準確描述它），並說明其觸發錨點 `action-<screen>-back` 統一置於該畫面 `PageColumn` 的 `SplitRow.header` 右側 `ButtonRow`，由頁面框架容器單一渲染，不由六個畫面各自決定擺放方式，與 SPEC-004 §3.7 第 17、18 項一致。§2.3 四條規則後新增說明：Domain 視圖、追溯視圖、破洞報告正常態依 SPEC-001 未列「返回」退出路徑，故不渲染 `action-<screen>-back`，但其 `returnTo` 值仍由規則 1（任一畫面下一次 rail 切換皆清空 `returnTo`）消費，與規則 1 不構成矛盾，非孤兒值。「採單槽而非堆疊」的理由改寫：移除「堆疊會產生回到哪一層的歧義」這項論證——規則 3 的 A→B→C 場景已示範單槽下返回目標明確，該論證與規則 3 自相矛盾。理由改為兩項實用主義依據：導覽列恆常可見，故深層返回鏈無額外使用者價值；單槽只需斷言單一值。 |
| 1.3 | 2026-09-02 | 時間 token 與取消契約修訂（`0.1.0-W1-039.2`）：§2.1 Motion 表新增類別欄，十個 token 逐一分類為「動畫」（transition／overlay／skeletonCycle）或「契約」（其餘七項）；減少動態效果規則改寫為依類別判定的性質陳述，不再逐一枚舉例外；`spinnerDelay` 因全域無使用情境已刪除；新增 `Motion.searchDebounce`（300 ms）承接 Ticket 清單搜尋輸入的防抖動語意，不再誤用 `progressTick`。§2.5 取消契約 C1 併入原 C2 並限定「尚未按下取消」，收斂為 C1–C8；原 C10／C11（切換導覽項／切換專案期間的行為）移至 §2.8 生命週期契約改編為 L1／L2；全文對 C10／C11 的引用同步改為指向 §2.8 L1；§2.11、FR-02 標題與驗收的條數引用同步為「C1–C8 與 L1–L2，共 10 條」。「感知即時帶」（第 640 行原文）與「即時帶」（第 456 行原文）兩個歧異用語統一為 token 表已定義的「幾乎即時帶」（100–400 ms），並修正第 640 行原本站不住腳的推論（兩段 cross-fade 300 ms 實際落在該帶內，改以「舊結果已判定待汰換、不宜維持淡出」與「手法一致性」為理由）。§1.3 泳道拖曳邊界的「桌面慣例」改寫：macOS 原生 `NSScrollView` 實際預設具彈性回彈，本規格改明示為顧及斷言可驗證性的專案決定，不再誤植為平台慣例。Motion 表六處時間值依據（`feedback`／`spinnerMinVisible`／`cancelDeadline`／`snackBar`／已刪除的 `spinnerDelay`／§1.3 桌面慣例）改為附具體出處（如 Flutter `SnackBar` 預設時長）或改寫為不引用外部權威的專案決定陳述。 |
| 1.2 | 2026-09-02 | 撰寫判準與斷言形式修訂（`0.1.0-W1-039.1`）：§撰寫判準改名為「條件欄與可觀察結果欄皆為斷言」，適用範圍收窄至條件欄與可觀察結果欄，明示依據／理由欄得用一般論述語言；可觀察形式表由三種擴充為四種（元件樹結構、狀態容器值、靜態原始碼掃描、外部程序呼叫），使 FR-05（靜態原始碼掃描）與 FR-06（外部程序呼叫）各有可用斷言形式。§2.5 C4 新增「C4 的斷言方式（強制）」段落，將「不得閃現空白」「不得出現錯誤文字」改寫為逐幀骨架錨點存在性與 SnackBar／Dialog 不存在的可執行斷言。§2.10 新增「Tab 內容區順序（斷言方式）」與「焦點裝飾（斷言方式）」兩段，將區段內順序改寫為幾何位置遞增斷言、焦點裝飾改寫為祖先鏈 decoration 存在性斷言。 |
| 1.1 | 2026-09-02 | 格詳情卡補件（`0.1.0-W1-048`）：§3.1 互動反應「矩陣格子」由單擊切泳道改為單擊選格（疊加態 `panel-domain-cell-detail`，`Motion.feedback` 內選中、`Motion.transition` cross-fade），新增換選、再點同格、無關格、在泳道中檢視（`action-domain-cell-goto-swimlane`）、清除選取（Esc／`action-domain-cell-clear`）、選 domain 與選格關係、右欄捲動八列；新增「格詳情卡的內容契約」（七區塊存在條件）、未選格右欄 `panel-domain-cell-detail-empty`、「選格與切泳道的關係」四案比較（採 B，標 PM 核定）；動畫提示、導航退出、生命週期各補已選格列；§1.1 捲動處 10 → 11（`scroll-domain-cell-detail`）並延伸連動禁令；§2.10 補已選格 Esc；FR-08 同步 11。同步 SPEC-001 v1.3／v1.4 狀態數：§0 與 §4 由 29 改 31，§4 補第 30 列「未選節點」（`state-nodeDetail-unset`）與第 31 列「已選格」，§3.6 缺口段落改為已承接，§5 判讀表更新 §6 列並補 §1 已選格列，FR-01 與設計約束同步 31 |
| 1.0 | 2026-09-01 | 初版，`0.1.0-W1-010` 產出。建立時間 token、取消契約十一條、單槽導航來源記錄、首次可見惰性載入契約、測試錨點命名規範；七畫面各自填四類行為；SPEC-001 全 29 狀態逐列對應導航反應 |
