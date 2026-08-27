---
# 提案（Proposal）

id: PROP-016
title: "元件庫統一化——補完 core/ui/components 元件層並收斂散落自製元件"
status: confirmed
source: tech-debt
proposed_by: "用戶（v0.37.0 參數集中工作後的進階評估）"
proposed_date: "2026-07-08"
confirmed_date: "2026-07-08"
target_version: v0.38.0
priority: P1
evaluation_level: standard       # 單版本功能範圍（元件補完 + 存量遷移 + hook 執法）

# 轉化產出追蹤
outputs:
  spec_refs: []                  # 預計：design-system-spec.md 增補元件庫章節
  usecase_refs: []
  ticket_refs: []

# 關聯
related_proposals: [PROP-007, PROP-017]    # PROP-007 跨專案對齊前例；PROP-017 回饋類元件（本提案探問衍生）；v1 端 sibling：book_overview_v1/docs/proposals/PROP-013
supersedes: null
---

# PROP-016: 元件庫統一化——補完 core/ui/components 元件層並收斂散落自製元件

## 需求來源

v0.37.0 前期 tickets 完成了 design token 參數集中（`lib/core/design_system/` 9 個類別）與規格文件對齊（`docs/spec/design-system-spec.md`）。用戶在此基礎上提出進階評估：能否統一建立元件庫（表格隔線、一般分隔線、按鈕等），其他地方統一使用元件庫元件，禁止在程式碼中散落自製元件。

## 問題描述

Token 層已收斂，但元件層只完成一半。`lib/core/ui/components/` 已有 7 個元件（AppButton、AppCard、AppDialog、AppTextField、AppBadge、AppHeader、AppPageScaffold），presentation 層卻仍大量直接建構原生 Material 元件與手工邊框。後果：

1. **樣式漂移**：同一語意的 UI（分隔、邊框、按鈕）在不同頁面外觀不一致，design token 的統一效果被原生元件的預設樣式稀釋。
2. **規格違規已存在**：spec §8.2 明文「分割陰影取代分隔線」（`UIShadows.dividerSubtle/Normal/Strong`），但 presentation 仍有 7 處直接使用 Material `Divider(`。
3. **無防線**：目前僅靠文件約束，AI agent 無跨 session 記憶，43 處 `Border.all(` 散落即是只靠文件約束的實證結果。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `lib/core/ui/components/`（新增元件）、`lib/presentation/` 全域（存量遷移，共 127 個 dart 檔） |
| 檔案 | 原生元件直用點（結構類，本提案範圍）：TextButton 15 處、IconButton 26 處、Card 11 處、AlertDialog 9 處、showDialog 入口 14 處、Divider 7 處、ElevatedButton 3 處、Border.all 43 處、BorderSide 8 處、Chip 類 14 處。回饋類（探問發現，另案處理）：ProgressIndicator 36 處、SnackBar 32 處、空狀態元件不存在 |
| 測試 | Widget 測試斷言連動（`find.byType(TextButton)` → `find.byType(AppButton)` 等，CLAUDE.md 7.5 已有規範前例） |
| 規格 | `docs/spec/design-system-spec.md` 需增補「元件庫」章節（元件清單、使用規範、禁止直用清單） |
| Hook | style-guardian 需新增規則：偵測 `lib/presentation/` 直接建構被元件庫涵蓋的原生 Material 元件 |

## 範圍界定

> **核心原則**：一個提案 = 一個版本的明確功能範圍。

### 本提案要做的（In Scope）

1. **補缺元件**：新增 `AppDivider`（依 spec §8.2 以分割陰影實作，含 subtle/normal/strong 三變體，涵蓋一般分隔線與表格隔線場景）；收斂 `AlertDialog` 直用至既有 `AppDialog`。
2. **Border.all 語意分類**：43 處逐一分類（表格隔線 / 卡片邊框 / 輸入框邊框 / 其他），可收斂者分別導入 AppDivider / AppCard / AppTextField，不可收斂者記錄豁免理由。
3. **存量遷移**：TextButton、ElevatedButton → AppButton；Card → AppCard；AlertDialog → AppDialog（含 14 處 showDialog 呼叫入口統一，如 `AppDialog.show()`）；Divider → AppDivider；Chip 類 14 處與 Border.all 一併語意分類（與 AppBadge 語意重疊者收斂，互動型 FilterChip 個案判讀）；對應 Widget 測試斷言同步修正。新元件遵循 spec §12 響應式約束（APP 端使用 rsp 響應式單位）。
4. **IconButton 包裝評估**：26 處直用，於 spec 增補階段評估包裝收益（樣式自由度低，可能結論為「豁免直用」並列入 hook 白名單）。
5. **spec 增補**：design-system-spec.md 新增元件庫章節——元件清單、對應原生元件禁用對照表、豁免清單，以及**跨平台元件對照表**（元件語意名、variant/size 命名、引用 token 的雙端對照；作為 v1 端 sibling 提案的命名契約，延續 spec §12 token 對齊模式擴展到元件層）。
6. **hook 執法**：style-guardian 新增「原生元件直用偵測」規則（依 spec 禁用對照表），讓禁令由工具預設行為承載而非文件提醒。

### 本提案不做的（Out of Scope）

- 視覺風格變更（token 值、色彩、陰影參數維持 spec 現值）→ 本提案是收斂實作，不是重新設計
- theme 切換 / 暗色主題擴充 → spec §2.5 既有範圍，與元件層收斂無關
- v1 Chrome Extension 端元件庫**實作** → v1 repo sibling 提案（book_overview_v1 PROP-013）承擔；本提案只產出跨平台命名契約（spec 元件庫章節），不跨 repo 改碼
- l10n 硬編碼文字收斂 → dart-style-guardian 既有職責涵蓋（`style_checker.py scan` 以 `[i18n]` 標記回報硬編碼使用者可見文字），非本提案範圍
- 回饋類元件統一（AppLoadingIndicator 36 處、AppSnackBar 32 處、空狀態元件）→ 獨立提案（評估審查探問發現；含行為語意如 SnackBar action/duration，複雜度與結構類不同，且併入將使單版本範圍達 ~200 處違反認知負擔閾值）。本提案 confirmed 時同步建立該 sibling 提案 draft，禁止無 trigger 延後

## 提案方案

### 方案比較

| 面向 | 方案 A：補元件 + 全量遷移 + hook 執法 | 方案 B：只補元件 + hook 防新增，存量不遷移 |
|------|--------------------------------------|--------------------------------------------|
| 優點 | 一次收斂，新舊一致，hook 規則無需豁免存量 | 單版本工作量小 |
| 缺點 | 遷移量約 120 處，需拆多張 tickets 分 wave 執行 | 新舊並存期長，hook 需維護存量豁免清單，樣式漂移持續 |
| 工時 | 高（但可高度並行：按 feature 目錄拆分互不相依） | 低 |

### 建議方案

方案 A。理由：遷移屬機械性替換，適合按 feature 目錄拆分並行派發；方案 B 的存量豁免清單本身就是持續維護成本，且與「禁止散落自製元件」的提案目標矛盾。

## 驗收條件

- [ ] `AppDivider` 元件存在且依 spec §8.2 分割陰影實作，`components.dart` barrel 已 export——對應「要做」1
- [ ] 43 處 `Border.all` 完成語意分類，分類結果與豁免理由記錄於對應 ticket——對應「要做」2
- [ ] `lib/presentation/` 無 TextButton / ElevatedButton / Card / AlertDialog / Divider 直用（grep 計數為 0，豁免清單除外）；對應 Widget 測試全數通過——對應「要做」3
- [ ] IconButton 包裝與否有明確結論（包裝或豁免 + 理由）記錄於 spec——對應「要做」4
- [ ] design-system-spec.md 含元件庫章節、禁用對照表與跨平台元件對照表（v1 端可依此命名契約實作）——對應「要做」5
- [ ] style-guardian 對 presentation 新增原生元件直用能產出 WARNING/deny——對應「要做」6

## Reality Test / 觸發案例實證

### 觸發案例

2026-07-08 盤點 `lib/presentation/`（127 個 dart 檔）實測：原生元件直用合計約 120 處（統計見影響範圍表）；其中 7 處 `Divider(` 直接違反 spec §8.2「分割陰影取代分隔線」的既有設計決策。

### 假設列舉

- 假設 1：既有 design token 已足以支撐新元件實作（不需新增 token）。
- 假設 2：43 處 `Border.all` 多數可歸入表格隔線 / 卡片邊框 / 輸入框邊框三類語意。
- 假設 3：元件替換不改變既有頁面視覺（AppButton 等既有元件已依 token 實作，替換後外觀應一致或更接近 spec）。

### 實驗驗證

| 假設 | 驗證方式 | 執行的實驗/觀察 | 結果 |
|------|---------|----------------|------|
| 假設 1 | 檢查 spec §8.2 divider tokens 是否已定義 | grep design-system-spec.md 與 `lib/core/design_system/shadows.dart` | 已驗證：`UIShadows.dividerSubtle/Normal/Strong` spec 已定義 |
| 假設 2 | 逐處分類 43 個 Border.all | 未執行——列為提案內工作項 2 | 未驗證 |
| 假設 3 | 遷移後 Widget 測試 + 抽樣頁面目視比對 | 未執行——列為遷移 ticket 驗收項 | 未驗證 |

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | token 層採用率高（UISpacing 57 檔 / UIColors 53 檔）；元件層 7 元件已存在且 AppButton 29 檔使用；原生直用約 120 處；Divider 直用違反 spec §8.2 |
| 未驗證 | Border.all 語意分布（工作項 2 補驗證）；替換視覺無回歸（遷移 ticket 驗收補驗證） |

---

## 失敗防護

| 失敗情境 | 偵測方式 | 對應防護 |
|---------|---------|---------|
| 遷移造成視覺回歸但 Widget 測試未捕捉（測試斷言只驗證元件存在，不驗證外觀） | 抽樣頁面目視比對發現差異 | 每張遷移票驗收含「遷移前後抽樣頁面目視比對」；AppDivider 等新元件先在單一頁面試點驗證後再全面遷移 |
| hook 執法規則誤報，合理場景（如第三方套件內部元件、測試檔）被錯誤阻擋 | 開發流程中 hook deny 申訴 | hook 先以 WARNING 模式上線一個版本觀察誤報率，並維護豁免清單（路徑 + 理由）；升級 deny 需誤報率實證 |
| 遷移進行中版本被迫發布，新舊元件並存狀態外流 | /version-release check 發現遷移票未全數完成 | 遷移票全數綁定 v0.38.0 同版本；發布前健康檢查以「grep 直用計數為 0」作為版本收尾驗收項，未達標不發布 |
| v1 端依 spec 對照表實作後，APP 端契約變更造成雙端漂移 | v1 PROP-013 實作時發現對照表與 APP 實際元件不符 | spec 元件庫章節變更視為契約變更，須同步通知 v1（v1 交接票 1.5.0-W5-025 已標註依賴）；對照表加版本標記 |

## 機會成本

投入本提案（一個版本的元件收斂工程）的機會成本是同期可開發的功能性需求（如 PROP-011 Google Drive 同步、W2-008 隱私政策頁）。接受此成本的理由：存量散落每多一個版本會繼續增長（本次盤點即比 PROP-008 時期多出一類回饋元件缺口），收斂成本隨時間單調上升；且 hook 防線建立後增量成本趨近於零，屬「早做便宜、晚做貴」的技術債清償。

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 遷移改動面大（~120 處），單票過載 | 代理人回合耗盡、驗收困難 | 按 feature 目錄拆 tickets（認知負擔閾值：單票修改檔案 <= 5） |
| Widget 測試斷言大量連動 | 測試紅燈阻擋整個測試套件 | 每張遷移票驗收含對應測試修正；遵循 CLAUDE.md 7.5 斷言規範 |
| IconButton 包裝收益不明 | 過度設計 | 先評估後決策，允許結論為「豁免直用」 |
| hook 規則誤報（合理豁免場景） | 開發流程被錯誤阻擋 | hook 先以 WARNING 模式上線一個版本，觀察誤報率後再升級 deny |

## 討論記錄

### 2026-07-08

用戶於 v0.37.0 參數集中工作後提出元件庫統一化評估。PM 前台盤點確認：token 層已收斂、元件層半成品、約 120 處原生直用、spec §8.2 分隔線設計決策已存在但未被遵循。用戶選定「建 PROP 提案走完整流程」。

**confirmed（同日）**：用戶確認三項決策——回饋類另建獨立提案（PROP-017 已同步建立 draft）、target_version v0.38.0、confirmed。升級閘門補齊「失敗防護」與「機會成本」章節後通過。後續：v0.38.0 版本規劃波（spec 增補 → UC → tickets）。

**三關式審查（draft → discussing）**：第一關必要性通過——無替代方案（文件約束實證失效、hook 執法以元件庫存在為前提），痛點真實（樣式漂移 + spec §8.2 違規 7 處）。第二關完整性探問（UI/互動 + UX 維度）發現回饋類元件缺口：ProgressIndicator 36 處、SnackBar 32 處散落、空狀態元件不存在，另 Chip 類 14 處、showDialog 入口 14 處未統計。處置：Chip 與 showDialog 納入工作項 3（結構類）；回饋類移 Out of Scope 並綁定「confirmed 時建 sibling 提案」trigger；工作項 1/3 補響應式（rsp 單位）約束。待用戶決策：範圍處置確認、target_version、confirmed。

同日用戶補充跨專案需求：v1 Chrome Extension 同步開發，元件庫應雙端同構、共有元件同命名同樣式。盤點 v1 現況：token 層已落地（`src/core/design-system/`，v1 PROP-008 從 APP 移植），元件層僅 popup 局部 `ui-factory.js`（createButton 等純函式工廠，variant 已用 primary/secondary/danger 語意名），popup.html 內嵌約 36 條 CSS 規則、overview.css 有 10 處 design-system 外 border 宣告。決策：依 PROP-007 / QR sibling 提案前例（APP PROP-014 ↔ v1 PROP-012），命名契約放本 repo spec（v1 PROP-008 既有 reference 方向即指向 APP），v1 端實作另建 v1 PROP-013。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | spec/design-system-spec.md（增補元件庫章節） | | pending |
| Ticket | （提案確認後開立） | | pending |
