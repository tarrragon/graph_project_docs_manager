# ConflictResolutionWidget 介面規格（TDD Phase 1）

| 項目 | 值 |
|------|------|
| 規格 ID | spec/search/conflict-resolution-widget |
| 來源 Ticket | 0.31.1-W8-026.4 |
| TDD Phase | Phase 1（介面規格，非實作） |
| 層級 | presentation/search/widgets |
| 宿主頁面 | BookSupplementPage（W8-026.2 定義宿主邊界） |
| 消費 Domain | `InformationConflictDetector` / `ConflictResolutionAnalyzer`（禁止重做衝突邏輯） |

---

## 1. Purpose

`ConflictResolutionWidget` 是 UC-04（書籍資訊補充）替代流程 5b「選擇的書籍資訊有衝突」的 UI 元件。

當用戶在補充流程中選擇一筆候選書籍，系統偵測到既有書籍欄位（作者、出版商等）與候選新值不一致時，本 widget 負責：

1. 以**比較表**將每個衝突欄位的「原值 vs 候選新值」逐欄並列呈現。
2. 顯示 domain 分析器產出的**智慧建議**（取自 `recommendation.reason`，文字由 domain 決定，如「標題差異過大，可能是不同書籍」）。
3. 讓用戶**逐欄選擇**採用新值或保留原值（field-level resolution）。
4. 用戶確認後，**回傳欄位級選擇結果**給宿主頁面執行部分更新。

設計目標：可重用、無狀態外洩、不直接依賴 BuildContext 以外的宿主資源——透過明確的輸入 / 輸出契約與 BookSupplementPage 解耦。

---

## 2. 資料契約（與既有 Domain 對齊）

本 widget **消費**既有 domain 衝突資料結構，**不**新增衝突偵測或策略分析邏輯。

### 2.1 輸入

| 輸入參數 | 型別 | 來源 | 用途 |
|---------|------|------|------|
| `conflicts` | `List<InformationConflict>` | `InformationConflictDetector.detectConflicts()` | 渲染比較表的逐欄資料 |
| `analysis` | `ConflictResolutionAnalysis`（選填） | `ConflictResolutionAnalyzer.analyzeStrategies()` | 顯示智慧建議文字（取自 `recommendation.reason`，由 domain 決定，如「標題差異過大，可能是不同書籍」） |
| `onConfirm` | `void Function(Map<String, FieldChoice>)` | 宿主回呼 | 用戶確認後回傳選擇結果 |

`InformationConflict` 既有欄位（`lib/domains/search/services/information_conflict_detector.dart`）：

| 欄位 | 型別 | widget 使用方式 |
|------|------|---------------|
| `type` | `ConflictType` | domain 衝突分類；比較表實際顯示文字取自 `description` 欄位（由 domain 決定，如 authorMismatch → 「作者資訊不匹配」、publisherMismatch → 「出版商資訊不匹配」） |
| `field` | `String` | 比較表 row 的識別 key、輸出 Map 的 key |
| `existingValue` | `String` | 比較表「原值」欄 |
| `newValue` | `String` | 比較表「候選新值」欄 |
| `severity` | `double` | 視覺強調（高 severity 可加重底色，非必要） |
| `description` | `String` | 比較表該列實際顯示的衝突描述文字（widget 直接渲染此欄，非固定標籤；文字由 domain 決定） |

`ConflictResolutionAnalysis.recommendations[].reason` 提供智慧建議文字，實際內容由 domain analyzer 依輸入決定（如「標題差異過大，可能是不同書籍」「Google Books 出版商資訊通常更準確」）；測試應以語義斷言「顯示 domain recommendation.reason」而非硬比對固定字串。

### 2.2 輸出

逐欄選擇結果以 `Map<String, FieldChoice>` 回傳，key = `InformationConflict.field`：

```text
FieldChoice（介面層列舉，僅描述意圖，非 domain 物件）
  useNew      -> 採用候選新值（select_new_*）
  keepOriginal-> 保留既有原值（keep_original_*）
```

宿主頁面（BookSupplementPage）依此 Map 決定哪些欄位寫入新值、哪些保留，組成部分更新請求。本 widget 不直接寫資料庫。

> 註：`FieldChoice` 是 presentation 層為承載「逐欄選擇意圖」而定義的最小列舉，與 domain 的 `ResolutionStrategy` 正交（後者描述整體解決策略，前者描述單欄用戶決定）。

---

## 3. Widget Key 命名表（與測試假設字面一致）

字面來源：`test/integration/uc04_to_uc08_integration_tests.dart`（5b 衝突解決，line 395-407）。

| # | Widget Key 字面 | 元件角色 | 互動 | 測試行 |
|---|----------------|---------|------|--------|
| 1 | `conflict_comparison_table` | 衝突比較表容器 | 顯示逐欄「原值 vs 新值」 | 396 |
| 2 | `field_level_selection` | 欄位級選擇區容器 | 包裹各欄位的 useNew/keepOriginal 選項 | 402 |
| 3 | `select_new_title` | 「標題」欄位採用新值的選項 | tap → title 欄選 useNew | 405 |
| 4 | `keep_original_author` | 「作者」欄位保留原值的選項 | tap → author 欄選 keepOriginal | 406 |
| 5 | `confirm_selective_update` | 確認部分更新按鈕 | tap → 觸發 `onConfirm` 回傳結果 | 407 |

合計 5 Key，與 Context Bundle 列出字面完全一致。

### 3.1 命名模式延伸（供 P2/P3b 實作時對齊）

Key 3、4 是具名範例（title 採新、author 保留），實作時每個衝突欄位應產生一組對稱選項，命名模式：

| 模式 | 字面格式 | 範例 |
|------|---------|------|
| 採用新值 | `select_new_{field}` | `select_new_title`、`select_new_publisher` |
| 保留原值 | `keep_original_{field}` | `keep_original_author`、`keep_original_publisher` |

> 測試僅硬斷言 `select_new_title` 與 `keep_original_author` 兩個具名 Key；其餘欄位選項沿用同一命名模式，確保未來新增衝突欄位時 Key 可預測。

---

## 4. Wireframe（結構描述）

```text
┌─ ConflictResolutionWidget ──────────────────────────────────┐
│  「發現資訊衝突」  (標題文字，test line 395)                  │
│                                                              │
│  智慧建議：可能為不同版本… (analysis.recommendations reason)  │
│                                                              │
│  ┌─ conflict_comparison_table ─────────────────────────────┐ │
│  │ 欄位      │ 原值（existingValue） │ 候選新值（newValue） │ │
│  │──────────┼─────────────────────┼────────────────────  │ │
│  │ 標題差異  │ 原子習慣             │ 原子習慣（新版）      │ │
│  │ 作者差異  │ 原始作者             │ 不同作者             │ │
│  │ 出版商差異│ 原始出版商           │ 不同出版商           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ field_level_selection ─────────────────────────────────┐ │
│  │ 標題：  [select_new_title] 採新   [keep_original_title]   │ │
│  │ 作者：  [select_new_author] 採新  [keep_original_author]  │ │
│  │ 出版商：[select_new_publisher]    [keep_original_publisher]│ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│            [ confirm_selective_update ]  確認部分更新         │
└──────────────────────────────────────────────────────────────┘
```

佈局註記：
- 比較表 row 數 = `conflicts.length`（資料驅動，非硬編碼三列）。
- `field_level_selection` 每列對應一個衝突欄位，提供採新 / 保留二選一。
- 內容可能超過預設測試螢幕高度（800x600），須以 `SingleChildScrollView` 包裹（CLAUDE.md 7.4 佈局溢出規範）。
- 文字一律走 l10n，wireframe 中文為示意；測試以 Key 與 `textContaining` 斷言，不硬比對完整字串。
- 比較表欄標籤（標題差異 / 作者差異 / 出版商差異）與智慧建議文字（可能為不同版本…）為示意；**實際顯示文字由 domain 決定**——比較表取 `conflict.description`（如「作者資訊不匹配」「出版商資訊不匹配」），智慧建議取 `recommendation.reason`（如「標題差異過大，可能是不同書籍」），wireframe 字樣不代表 runtime 真實輸出。

---

## 5. 狀態流轉圖

```text
        宿主傳入 conflicts + analysis
                  │
                  ▼
        ┌───────────────────┐
        │  Rendered          │  渲染比較表 + 智慧建議
        │  （比較表已顯示）   │  每欄預設選擇 = useNew（或依 analysis.primaryStrategy）
        └─────────┬─────────┘
                  │ 用戶 tap select_new_* / keep_original_*
                  ▼
        ┌───────────────────┐
        │  Selecting          │  逐欄更新內部選擇狀態
        │  （部分欄位已選）    │  （StatefulWidget 本地 state，不外洩）
        └─────────┬─────────┘
                  │ 用戶 tap confirm_selective_update
                  ▼
        ┌───────────────────┐
        │  Confirmed          │  呼叫 onConfirm(Map<field, FieldChoice>)
        │                     │  控制權交還宿主，由宿主執行部分更新
        └───────────────────┘
```

狀態說明：

| 狀態 | 進入條件 | 可用互動 | 離開 |
|------|---------|---------|------|
| Rendered | 接收非空 `conflicts` | 點選任一欄位選項 | → Selecting |
| Selecting | 至少一次欄位選擇 | 繼續調整任意欄選擇 / 確認 | → Confirmed |
| Confirmed | tap `confirm_selective_update` | 無（回呼後由宿主接管） | 終態 |

邊界條件：

| 情境 | 行為 |
|------|------|
| `conflicts` 為空 | widget 不應被宿主渲染（無衝突無需解決）；防禦性顯示空態，不拋例外 |
| 用戶未調整任何欄位即確認 | 以各欄預設選擇（useNew）組成結果回傳 |
| `analysis` 為 null | 隱藏智慧建議區，比較表與選擇區照常運作 |

---

## 6. 與宿主（BookSupplementPage）的介面契約

| 方向 | 內容 | 對齊 ticket |
|------|------|------------|
| 宿主 → widget | 選書後由 detector 偵測出的 `List<InformationConflict>` + analyzer 的 `ConflictResolutionAnalysis` | W8-026.2 宿主邊界 |
| widget → 宿主 | `onConfirm(Map<String, FieldChoice>)`：欄位級選擇結果 | 本 spec |

責任切分：

| 責任 | 歸屬 |
|------|------|
| 偵測衝突、計算 severity、產生建議 | Domain（detector + analyzer，既有，沿用） |
| 比較表渲染、逐欄選擇 UI、收集選擇 | ConflictResolutionWidget（本 spec） |
| 觸發 detector/analyzer、接收 onConfirm 結果並寫入部分更新 | BookSupplementPage 宿主（W8-026.2） |

本 widget 不持有 ViewModel、不直接 `ref.watch`；衝突資料由宿主以建構參數注入，確保可重用與可獨立 Widget 測試（P2-3）。

---

## 7. 沿用既有資產（禁止重建）

| 資產 | 路徑 | 用途 |
|------|------|------|
| `InformationConflictDetector` | `lib/domains/search/services/information_conflict_detector.dart` | 產出 `List<InformationConflict>` |
| `InformationConflict` (VO) | 同上 | 比較表逐欄資料來源 |
| `ConflictResolutionAnalyzer` | `lib/domains/search/services/conflict_resolution_analyzer.dart` | 產出智慧建議 |
| `ResolutionRecommendation` | 同上 | 建議文字（reason） |
| `DataMergeStrategy` (4 種) | `lib/domains/search/strategies/data_merge_strategy.dart` | 宿主執行更新時策略選用（非本 widget 直接消費） |

本 widget 為**全新 UI**，但所有衝突偵測 / 策略分析邏輯由上述 domain 提供，spec 僅定義 UI 如何消費，不引入新衝突演算法。

---

## 8. 驗收標準（供 P2-3 Widget 測試設計）

| # | 驗收項 | 對應 Key / 斷言 |
|---|--------|----------------|
| A1 | 渲染後顯示「發現資訊衝突」標題 | `find.text('發現資訊衝突')` |
| A2 | 顯示衝突比較表 | `find.byKey(Key('conflict_comparison_table'))` |
| A3 | 比較表呈現各欄差異文字（取自 domain `conflict.description`） | 語義斷言：比較表顯示 domain 輸出的衝突描述文字（如 `find.textContaining('作者資訊不匹配')`、`'出版商資訊不匹配'`），不硬比對「作者差異」「出版商差異」等理想標籤 |
| A4 | 顯示智慧建議（取自 domain `recommendation.reason`） | 語義斷言：顯示 domain analyzer 的 recommendation.reason 文字（內容依輸入而異，如「標題差異過大，可能是不同書籍」），不硬比對「可能為不同版本」 |
| A5 | 顯示欄位級選擇區 | `find.byKey(Key('field_level_selection'))` |
| A6 | 可選「標題採新值」 | tap `Key('select_new_title')` |
| A7 | 可選「作者保留原值」 | tap `Key('keep_original_author')` |
| A8 | 確認後回傳選擇結果 | tap `Key('confirm_selective_update')` → onConfirm 含 `{title: useNew, author: keepOriginal}` |

---

## 9. 設計一致性驗證

見 ticket `0.31.1-W8-026.4`「重現實驗結果」章節：本 spec 的 5 個 widget Key 與 `test/integration/uc04_to_uc08_integration_tests.dart`（line 395-407）字面逐一比對一致。

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。
