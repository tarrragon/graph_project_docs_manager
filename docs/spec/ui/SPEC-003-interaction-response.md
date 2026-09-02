---
id: SPEC-003
title: "互動反應規格：七畫面的反應、動畫、導航與生命週期"
status: draft
source_proposal: PROP-004
created: "2026-09-01"
updated: "2026-09-02"
version: "1.2"
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

可觀察結果取以下四種形式，涵蓋本規格全部驗收（FR-01～FR-10）：

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
| 邊界 | 平移至內容邊界時停止，不做橡皮筋回彈（桌面慣例） |
| 與捲動的關係 | 拖曳與捲軸作用於同一個 offset；拖曳後捲軸位置同步改變 |
| 慣性 | 0.1 不做拋擲慣性；放開手指即停止 |

節點卡、矩陣格、樹節點、ticket 列皆**不可拖曳**（0.1 無排序與重新配置功能）。
對這些元素執行 drag 的預期結果是「觸發所在容器的捲動」，不是元素本身移動。

### 1.4 同畫面內展開（2 個）

| 位置 | 錨點 | 展開後 | 收合方式 |
|------|------|--------|---------|
| 追溯樹節點 | `expander-traceability-<nodeId>` | 子層節點出現於樹中 | 再次點擊同一錨點 |
| schema 不相容詳情 | `action-domain-schema-detail` → `panel-domain-schema-detail` | 面板出現於同一狀態根節點內 | 再次點擊、或按 Esc |

展開收合不改變狀態錨點，也不改變 `returnTo`（§2.4）。

---

## 2. 通用機制

以下機制先在此定義一次，§3 各畫面直接引用，不重複敘述。

### 2.1 時間 token

SPEC-002 的唯一硬規則要求所有值先具名。時間值同樣適用，落點
`lib/tokens/motion.dart`，類名 `Motion`，型別 `Duration`。

| token | 值 | 用途 | 依據 |
|-------|-----|------|------|
| `Motion.feedback` | 100 ms | 點擊確認的出現上限 | Nielsen 100 ms 感知門檻 |
| `Motion.transition` | 150 ms | 狀態之間的 cross-fade | 落在 100–400 ms「幾乎即時」帶，以動畫掩蓋切換 |
| `Motion.overlay` | 200 ms | 浮層展開與收合 | 同上，浮層位移距離大於狀態淡入故取較長值 |
| `Motion.spinnerMinVisible` | 300 ms | 指示一旦顯示的最短停留 | 消除閃爍的業界慣例值 |
| `Motion.spinnerDelay` | 400 ms | 延遲顯示門檻（僅 §2.6 限定情境） | Doherty 生產力門檻 |
| `Motion.cancelDeadline` | 500 ms | 按下取消後抵達目標態的上限 | 介於 400 ms 生產力門檻與 1 s 注意力門檻之間 |
| `Motion.progressTick` | 200 ms | 進度計數文字的最小更新間隔 | 高於此頻率的數字跳動不可讀 |
| `Motion.skeletonCycle` | 1200 ms | 骨架 shimmer 的循環週期 | 一屏內可辨識為「持續進行」而不干擾閱讀 |
| `Motion.snackBar` | 4 s | 純告知型 SnackBar 停留 | Material 慣例 |
| `Motion.snackBarWithAction` | 8 s | 帶動作 SnackBar 停留 | 需讀完再決定是否按 |

**硬規則**：`lib/` 之下（`lib/tokens/` 除外）不得出現 `Duration(milliseconds: <字面數字>)`
或 `Duration(seconds: <字面數字>)`。此檢查可機械化，與 SPEC-002 FR-01 同一條 CI 規則擴充。

**減少動態效果**：`MediaQuery.disableAnimationsOf(context)` 為 `true` 時，
`Motion.transition` / `Motion.overlay` / `Motion.skeletonCycle` 一律視為
`Duration.zero`，shimmer 改為靜態灰塊。`Motion.cancelDeadline`、
`Motion.spinnerMinVisible`、`Motion.snackBar` **不歸零**——它們是行為契約
（多久內必須抵達、最短停留多久）而非動畫。

### 2.2 三層回饋的落地

| 層 | 本 App 的落地 | 斷言 |
|----|--------------|------|
| 點擊確認 | 一律使用 Material `InkWell` / `Button` 的內建 pressed 態，不自繪 | 元件樹中該互動元素被 `InkWell` 或 `ButtonStyleButton` 包覆 |
| 等待指示 | 畫面級載入態（§2.6），不使用按鈕內 spinner | 對應 `state-*-loading` / `state-gaps-scanning` 錨點存在 |
| 結果通知 | 狀態轉換本身為主；狀態不變的動作（外部開啟、重新整理無變化）用 SnackBar | SnackBar 文字等於指定 i18n key 的值 |

**禁止**：任何可點元素在 0.1 以「無回饋佔位 handler」上線。未接線的動作只有
兩種合法形態——(a) 不渲染該元素；(b) 渲染為 `enabled: false` 並在同一列以
常駐文字（非 tooltip）說明原因。見 FR-06。

### 2.3 導航模型：六項平行 + 單槽來源記錄

現行 `lib/app/router.dart` 以 `selectedDestinationProvider` 加 `IndexedStack`
實作六項平行導覽，**沒有 history stack**。SPEC-001 有四個退出路徑需要「回到
來源」語意（§2 flow 未結構化的返回、§4 未載入的返回上一畫面、§5 掃描中的取消返回、
§6 節點詳情的返回來源畫面），因此需要來源記錄。

**採單槽而非堆疊。** 六項導覽是平行關係不是層級關係，堆疊會產生「回到哪一層」
的歧義（A→B→C→A 之後按返回應回哪裡無唯一答案）；單槽記錄「最近一次跳轉從哪來」
語意單一且可斷言。

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

**斷言形式**：`ref.read(returnToProvider)` 的值；以及返回按鈕錨點
`action-<screen>-back` 的存在性。

### 2.4 退出路徑的三種導航反應

SPEC-001 退出路徑欄的所有措辭，歸為三類反應，不存在第四類：

| 反應 | 觸發錨點 | 可觀察結果 |
|------|---------|-----------|
| 導覽切換（rail） | `nav-item-<d>` | `IndexedStack` 可見頁改變；`returnTo` 為 `null`；來源頁狀態保留（§2.8） |
| 內容跳轉（jump） | 各狀態內的具名動作錨點 | 可見頁改變；`returnTo` 等於跳轉前 destination |
| 同畫面狀態轉換 | 各狀態內的具名動作錨點 | 可見頁不變；狀態根錨點由 X 換為 Y |

「切換專案」不屬於上述三類，它開啟浮層（§3.7），是**覆蓋層**而非導航。

### 2.5 取消契約（FR-02 的行為定義）

適用三處載入態：`state-domain-loading`、`state-tickets-loading`、`state-gaps-scanning`。

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| C1 | 載入態渲染的第一幀 | 取消錨點存在且 `enabled` 為 `true` |
| C2 | 載入進行至任何進度 | 取消錨點的 `enabled` 恆為 `true`；不存在「收尾中所以不能取消」的時間窗 |
| C3 | 按下取消後 `Motion.feedback` 內 | 取消錨點 `enabled` 轉為 `false`；其文字改為取消中的 i18n 值 |
| C4 | 按下取消後至抵達目標態之間 | 畫面維持載入態版面（骨架與版位不變）；進度指示改為 indeterminate；計數文字凍結於最後值；不得閃現空白、不得出現錯誤文字（可執行斷言見下方「C4 的斷言方式」） |
| C5 | 按下取消後 `Motion.cancelDeadline` 內 | 目標狀態錨點存在，載入態錨點不存在 |
| C6 | 取消完成後 | 不出現任何 SnackBar、Dialog 或錯誤標記（取消是使用者意圖，不是失敗） |
| C7 | 取消完成後 | 已解析的部分結果全數丟棄；不存在「半渲染」的矩陣或清單 |
| C8 | 取消完成後再次觸發載入 | 進度自 0 起算，不續傳 |
| C9 | 連續按下取消 N 次 | 狀態轉換只發生一次（冪等） |
| C10 | 載入期間切換導覽項 | 載入**繼續**（離開畫面不等於取消）；回到該畫面時顯示當時進度 |
| C11 | 載入期間切換專案 | 載入中止，且在 `Motion.cancelDeadline` 內完成中止，不留背景任務 |

**C4 的斷言方式（強制）**：自按下取消起，以固定幀距
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

**C5 的斷言方式（強制）**：以 `await tester.tap(...)` 後
`await tester.pump(Motion.cancelDeadline)` 推進假時鐘，再斷言目標態錨點存在。
**禁止**以 `Stopwatch` 加 `lessThan` 量測真實耗時作為 pass-fail 條件——該類斷言
的結果依賴機器負載而非程式正確性。

**C5 的實作約束**：解析與掃描迴圈須以批次進行，每批之間檢查取消旗標，
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
觸發、且是整個畫面的內容，必須立即渲染。`Motion.spinnerDelay` 保留給「非狀態級
的短暫等待」（0.1 無此類情境；token 先定義以免日後出現時又寫裸值）。

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
| 切換導覽項與進行中任務 | 任務繼續（見 §2.5 C10） |
| 切換專案 | 六頁狀態全部重置為各自初始狀態；全部進行中任務中止（C11）；`returnTo` 設為 `null` |
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

### 2.11 元件庫對應

各類行為的實作落點，供 SPEC-002 元件庫直接引用：

| SPEC-002 元件 | 承擔本規格的哪一節 |
|--------------|------------------|
| 載入態（骨架 + 進度 + 取消） | §2.5 取消契約全部 11 條、§2.6 等待指示 |
| 空狀態（訊息 + 前進動作） | §2.7 空狀態欄、§2.4 內容跳轉 |
| 阻擋狀態（訊息 + 版本值 + 出口） | §2.7 阻擋狀態欄、浮層可用性斷言 |
| 導覽項 | §2.3 `rail` intent、§2.8 狀態保留 |
| 專案切換浮層 | §3.7 全節、§2.10 焦點限制 |
| 節點卡 | §1.3 不可拖曳、§2.4 內容跳轉 |
| 損壞標記（兩級） | §3.4 含損壞、§3.6 部分損壞的跳轉行為 |
| 徽章 | §3.4 損壞徽章的可點性 |

**取消契約由載入態元件單一承擔，不由三個畫面各自實作。** 三處載入態的差異只有
「目標態」與「進度型別」兩個參數，其餘 11 條行為完全相同。

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
| 開啟 docs 目錄 | `action-domain-open-docs` | 點擊 | 以系統預設方式開啟該目錄；出現 SnackBar 告知已開啟，停留 `Motion.snackBar` |
| 開啟 docs 目錄（目錄不存在） | 同上 | — | **該錨點不渲染**（SPEC-001 §1「僅在該目錄存在時提供」） |
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
| 格選中態出現 | 點擊確認用 `InkWell` 內建 pressed 態（§2.2），選中態本身無入場動畫（持續性標記） |
| 右欄提示 ↔ 詳情卡、詳情卡內容換選 | cross-fade，`Motion.transition`；資料為本地已解析內容，落在 0–100 ms 即時帶，不顯示任何等待指示 |
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
| 無可消費的型別表 | `project-switcher-entry` → 浮層（唯一出口）。**0.1 不提供「以純檔案模式檢視」**——SPEC-001 該欄寫「（若支援降級）」，降級策略尚未定案，依 §2.2 不得以無回饋佔位 handler 上線，故不渲染該動作 |
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
| 開啟原始檔 | `action-ucFlow-open-source` | 點擊 | 以系統預設方式開啟該檔；出現 SnackBar 告知已開啟 |
| 開啟原始檔（檔案不存在） | 同上 | 點擊 | 出現 SnackBar 告知檔案不存在，停留 `Motion.snackBarWithAction`，帶一個「重新整理」動作 |
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
| 搜尋 | `input-tickets-search` | 輸入 | 輸入後 `Motion.progressTick` 內清單筆數更新；清空輸入還原全部筆數 |
| 篩選 | `action-tickets-filter-<key>` | 點擊 | 該篩選呈選中態；清單筆數改變 |
| 排序 | `action-tickets-sort-<key>` | 點擊 | 首列與末列的內容改變；offset 歸零（排序改變後保留舊 offset 無意義） |
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

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 未載入 → 載入中 → 正常 | cross-fade，`Motion.transition` |
| 進度條推進 | determinate，值來自實際已解析筆數／總數 N；不得自行推進 |
| 已解析筆數文字 | 每 `Motion.progressTick` 更新一次 |
| 列表首次渲染 | 不做逐列入場動畫（虛擬捲動下逐列動畫會在捲動時反覆觸發） |
| 列表 ↔ 主題 | cross-fade，`Motion.transition` |
| 損壞徽章出現 | 無入場動畫（靜態標記） |

#### 導航跳轉與退出

| 狀態 | 退出動作 → 目標 |
|------|----------------|
| 未載入 | `action-tickets-back` → `returnTo`（`null` 時不渲染，改由 `nav-item-<d>` 承擔退出）；`project-switcher-entry` → 浮層 |
| 載入中 | `action-tickets-cancel-load` → `state-tickets-unloaded`；完成 → `state-tickets-list`；載入中亦可 `nav-item-<d>` 切至其他畫面（載入繼續，C10） |
| 正常 · 列表 | `nav-item-<d>`；`card-tickets-*` → jump；`project-switcher-entry` |
| 正常 · 主題 | 同上 |
| 無 ticket | `action-tickets-goto-gaps` → jump；`nav-item-<d>`；`project-switcher-entry` |
| 含損壞（疊加） | 同其底層正常態，另加 `badge-tickets-corrupted` → jump 至破洞報告 |

#### 生命週期

| 事件 | 規格 |
|------|------|
| 建構 | 隨 `IndexedStack` 於 App 啟動時建構，但**不觸發解析** |
| 首次可見 | 進入 `state-tickets-unloaded`；解析仍**不觸發**，須使用者按 `action-tickets-start-load`（SPEC-001 §4 的「開始載入」是使用者操作） |
| 切至其他導覽項 | 載入繼續（C10）；搜尋詞、篩選、排序、模式、offset 全部保留 |
| 再次可見 | 已載入者直接顯示正常態，不重新解析 |
| 切換專案 | 中止載入；重置為 `state-tickets-unloaded`；搜尋詞與篩選清空 |

**未載入態不顯示預估耗時。** SPEC-001 §4 顯示欄含「預估耗時」，但預估耗時的
計算依據屬 CLAUDE.md 現行待決的五項空殼判準之一，尚無定義。依 §2.6 誠實性硬規則，
無依據的時間承諾不得顯示；0.1 只顯示票數 N。此為缺料下的明確決策，非延後。

### 3.5 破洞報告（`nav-page-gaps`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 取消掃描 | `action-gaps-cancel-scan` | 點擊 | 依 §2.5，目標態為 `returnTo` 指定畫面；`returnTo` 為 `null` 時為 `nav-page-domain` |
| 重新掃描 | `action-gaps-rescan` | 點擊 | `state-gaps-none` 或 `state-gaps-found` 消失、`state-gaps-scanning` 出現 |
| 破洞項 | `card-gaps-<itemId>` | 點擊 | 以系統預設方式開啟該原始檔並定位至行號；出現 SnackBar 告知已開啟 |
| 破洞項（檔案不存在） | 同上 | 點擊 | SnackBar 告知檔案不存在，帶「重新掃描」動作，停留 `Motion.snackBarWithAction` |
| 分節捲動 | `scroll-gaps-sections` | drag / 捲軸 | offset 改變 |
| 分節收合 | `expander-gaps-<category>` | 點擊 | 該類別的項目出現或消失 |

#### 動畫提示

| 轉換 | 形式 |
|------|------|
| 掃描中骨架 | shimmer `Motion.skeletonCycle`；`disableAnimations` 時靜態 |
| 掃描中 → 無破洞 / 有破洞 | cross-fade，`Motion.transition` |
| 重新掃描 | 現有結果立即被骨架取代（不做淡出後再淡入的兩段動畫，總時長會超出感知即時帶） |
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
| 掃描中切至其他導覽項 | 掃描繼續（C10）；回來時顯示當時進度 |
| 切換專案 | 中止掃描；結果清空；下次可見時重新自動掃描 |

### 3.6 節點詳情（`nav-page-nodeDetail`）

#### 互動反應

| 元素 | 錨點 | 觸發 | 可觀察結果 |
|------|------|------|-----------|
| 返回來源畫面 | `action-nodeDetail-back` | 點擊 | 切至 `returnTo`，隨後 `returnTo` 設為 `null`；`returnTo` 為 `null` 時此錨點不渲染 |
| 開啟原始檔 | `action-nodeDetail-open-source` | 點擊 | 系統預設方式開啟；SnackBar 告知已開啟 |
| 開啟原始檔（檔案不存在） | 同上 | 點擊 | 狀態轉為 `state-nodeDetail-missing`（此為對外部變更的第一手偵測點） |
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
| 2 | Domain | 載入中 | `state-domain-loading` | 取消 → 未選專案；完成 → 正常／空圖 | 同畫面轉換：`action-domain-cancel-load` → `state-domain-unset`（§2.5）；解析完成 → `state-domain-matrix` 或 `state-domain-empty` |
| 3 | Domain | 正常 · 矩陣 | `state-domain-matrix` | 導覽至其他畫面、切換專案 | rail：`nav-item-<d>` → 對應頁；覆蓋層：`project-switcher-entry` → `state-switcher-expanded` |
| 4 | Domain | 正常 · 泳道 | `state-domain-swimlane` | 切回矩陣、導覽、切換專案 | 同畫面轉換：`mode-domain-matrix` → `state-domain-matrix`；rail；覆蓋層 |
| 5 | Domain | 空圖 | `state-domain-empty` | 切換專案、導覽至破洞報告 | 覆蓋層：`project-switcher-entry`；jump：`action-domain-goto-gaps` → `nav-page-gaps`，`returnTo`=domain |
| 6 | Domain | 不是框架專案 | `state-domain-not-framework` | 切換專案（浮層維持可用） | 覆蓋層：`project-switcher-entry`（`enabled` 恆為 `true`） |
| 7 | Domain | 無可消費的型別表 | `state-domain-schema-unconsumable` | 切換專案 | 覆蓋層：`project-switcher-entry`。降級檢視動作 0.1 不渲染（§3.1） |
| 8 | Domain | schema 不相容 | `state-domain-schema-incompatible` | 切換專案（浮層維持可用） | 覆蓋層：`project-switcher-entry`；同畫面展開：`action-domain-schema-detail` → `panel-domain-schema-detail` |
| 9 | UC Flow | 無 UC | `state-ucFlow-empty` | 導覽、切換專案 | jump：`action-ucFlow-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 10 | UC Flow | flow 未結構化 | `state-ucFlow-unstructured` | 開啟原始檔、返回 Domain 視圖 | 固定目標：`action-ucFlow-back-to-domain` → `nav-page-domain`（不用 `returnTo`）。`action-ucFlow-open-source` 為外部動作，不計為導航反應 |
| 11 | UC Flow | 正常 | `state-ucFlow-normal` | 導覽、切換專案 | rail；jump：`card-ucFlow-step-*` → `nav-page-nodeDetail`、`action-ucFlow-goto-domain-*` → `nav-page-domain`；覆蓋層 |
| 12 | 追溯 | 正常 | `state-traceability-normal` | 導覽、切換專案 | rail；jump：`card-traceability-*` → `nav-page-nodeDetail`；覆蓋層 |
| 13 | 追溯 | 鏈路斷裂 | `state-traceability-broken` | 同上 + 跳轉破洞報告 | 同 #12，另加 jump：`action-traceability-goto-gaps` / `badge-traceability-broken-*` → `nav-page-gaps` |
| 14 | 追溯 | 無提案 | `state-traceability-empty` | 導覽、切換專案 | jump：`action-traceability-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 15 | Ticket | 未載入 | `state-tickets-unloaded` | 返回上一畫面、切換專案 | 返回：`action-tickets-back` → `returnTo`（`null` 時不渲染，退出由 rail 承擔）；覆蓋層 |
| 16 | Ticket | 載入中 | `state-tickets-loading` | 取消 → 未載入；完成 → 正常 | 同畫面轉換：`action-tickets-cancel-load` → `state-tickets-unloaded`（§2.5）；完成 → `state-tickets-list`；rail 可離開且載入繼續（C10） |
| 17 | Ticket | 正常 · 列表 | `state-tickets-list` | 導覽、切換專案 | rail；jump：`card-tickets-*` → `nav-page-nodeDetail`；覆蓋層 |
| 18 | Ticket | 正常 · 主題 | `state-tickets-topic` | 同上 | 同 #17，另加同畫面轉換 `mode-tickets-list` → `state-tickets-list` |
| 19 | Ticket | 無 ticket | `state-tickets-empty` | 導覽、切換專案 | jump：`action-tickets-goto-gaps` → `nav-page-gaps`；rail；覆蓋層 |
| 20 | Ticket | 含損壞（疊加於 #17／#18） | `badge-tickets-corrupted` | 同正常 | 繼承其底層正常態的全部退出路徑，另加 jump：`badge-tickets-corrupted` → `nav-page-gaps` |
| 21 | 破洞 | 掃描中 | `state-gaps-scanning` | 取消 → 返回；完成 → 有／無破洞 | rail 語意的返回：`action-gaps-cancel-scan` → `returnTo` 指定頁；`returnTo` 為 `null` 時 → `nav-page-domain`（「返回」的目標由本規格定義） |
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
| §1 無可消費的型別表「（若支援降級）以純檔案模式檢視」 | 括號表示尚未定案。0.1 不渲染該動作（依 §2.2 未接線動作處理），該狀態的退出由「切換專案」單獨承擔 |
| §4 未載入「預估耗時」 | 預估依據屬待決事項，0.1 不顯示（依 §2.6 誠實性硬規則），只顯示票數 N |
| FR-02 驗收「Ticket 載入與破洞掃描期間」 | §1 Domain 視圖載入中亦列有「取消載入」操作，故本規格的取消契約覆蓋三處而非兩處 |
| §6 三個狀態的進入條件 | 皆預設已有選定節點。經導覽列直接進入時的缺口已由 SPEC-001 v1.3「未選節點」補上，本規格 §3.6 與 §4 第 30 列對應之 |
| §1 已選格「點格子→已選格」 | 「點格子」判讀為單擊；切泳道改由詳情卡內按鈕承擔（§3.1 四案比較，PM 核定）。若 PM 改採他案，本規格 §3.1 兩列改寫，SPEC-001 §1 可用操作欄同步 |

---

## 功能需求

### FR-01: 每個狀態的退出路徑皆有具名觸發錨點

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | §4 對照表 31 列，導航反應欄皆非空且皆含一個具名錨點；整合測試對每一列執行「渲染該狀態 → 觸發錨點 → 斷言目標狀態錨點存在」；浮層收合態（#27）為唯一豁免 |

### FR-02: 取消契約的十一條行為全部成立

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 驗收 | 三處載入態（`state-domain-loading`／`state-tickets-loading`／`state-gaps-scanning`）各自通過 §2.5 的 C1–C11；C5 以 `tester.pump(Motion.cancelDeadline)` 推進假時鐘後斷言，不得使用 `Stopwatch` 加 `lessThan` |

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
| 驗收 | Tab 可依 §2.10 順序走遍全部可用操作且每一步有可見焦點指示；浮層展開時 Tab 不離開浮層；Esc 收合浮層與 schema 詳情面板 |

### FR-10: 兩個獨立捲動區不連動

| 項目 | 值 |
|------|-----|
| 優先級 | P2 |
| 驗收 | 節點詳情主欄捲動後右欄 offset 不變；反之亦然 |

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

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.2 | 2026-09-02 | 撰寫判準與斷言形式修訂（`0.1.0-W1-039.1`）：§撰寫判準改名為「條件欄與可觀察結果欄皆為斷言」，適用範圍收窄至條件欄與可觀察結果欄，明示依據／理由欄得用一般論述語言；可觀察形式表由三種擴充為四種（元件樹結構、狀態容器值、靜態原始碼掃描、外部程序呼叫），使 FR-05（靜態原始碼掃描）與 FR-06（外部程序呼叫）各有可用斷言形式。§2.5 C4 新增「C4 的斷言方式（強制）」段落，將「不得閃現空白」「不得出現錯誤文字」改寫為逐幀骨架錨點存在性與 SnackBar／Dialog 不存在的可執行斷言。§2.10 新增「Tab 內容區順序（斷言方式）」與「焦點裝飾（斷言方式）」兩段，將區段內順序改寫為幾何位置遞增斷言、焦點裝飾改寫為祖先鏈 decoration 存在性斷言。 |
| 1.1 | 2026-09-02 | 格詳情卡補件（`0.1.0-W1-048`）：§3.1 互動反應「矩陣格子」由單擊切泳道改為單擊選格（疊加態 `panel-domain-cell-detail`，`Motion.feedback` 內選中、`Motion.transition` cross-fade），新增換選、再點同格、無關格、在泳道中檢視（`action-domain-cell-goto-swimlane`）、清除選取（Esc／`action-domain-cell-clear`）、選 domain 與選格關係、右欄捲動八列；新增「格詳情卡的內容契約」（七區塊存在條件）、未選格右欄 `panel-domain-cell-detail-empty`、「選格與切泳道的關係」四案比較（採 B，標 PM 核定）；動畫提示、導航退出、生命週期各補已選格列；§1.1 捲動處 10 → 11（`scroll-domain-cell-detail`）並延伸連動禁令；§2.10 補已選格 Esc；FR-08 同步 11。同步 SPEC-001 v1.3／v1.4 狀態數：§0 與 §4 由 29 改 31，§4 補第 30 列「未選節點」（`state-nodeDetail-unset`）與第 31 列「已選格」，§3.6 缺口段落改為已承接，§5 判讀表更新 §6 列並補 §1 已選格列，FR-01 與設計約束同步 31 |
| 1.0 | 2026-09-01 | 初版，`0.1.0-W1-010` 產出。建立時間 token、取消契約十一條、單槽導航來源記錄、首次可見惰性載入契約、測試錨點命名規範；七畫面各自填四類行為；SPEC-001 全 29 狀態逐列對應導航反應 |
