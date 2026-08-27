---
id: SPEC-003
title: "書庫匯出規格"
status: draft
source_proposal: PROP-007
created: "2026-03-30"
updated: "2026-06-20"
version: "2.0"
owner: ""

domain: export
subdomain: null

related_usecases: [UC-02]
related_specs: [SPEC-002, SPEC-008]
implements_requirements: [FR-1, FR-2, FR-3, FR-4, FR-5]
depends_on_domains: [book, tag]
---

# 書庫匯出規格

## 概述

定義書庫資料匯出功能的支援格式、匯出流程與資料完整性保證。

跨專案 JSON 交換格式以 canonical SSOT 為準：`book_overview_v1/docs/spec/book-interchange-v1.md`（book-interchange-v1 v3.0.0）。CSV 為各專案人類可讀匯出，不跨專案 round-trip（canonical §10）。

---

## 功能需求 (FR)

### FR-1：JSON 匯出採 canonical book-interchange-v1 v3.0.0

匯出 JSON 時，root 結構與欄位命名嚴格遵循 canonical v3.0.0（`book_overview_v1/docs/spec/book-interchange-v1.md`）：

```json
{
  "format": "book-interchange-v1",
  "formatVersion": "3.0.0",
  "metadata": {
    "exportedAt": "<ISO8601>",
    "sourceApp": "book_overview_app",
    "totalBooks": "<count>"
  },
  "books": [],
  "tagTree": { "ccl": [], "custom": [] }
}
```

`sourceApp` 固定為枚舉值 `"book_overview_app"`。`totalBooks` 須與 `books` 陣列長度一致（交叉驗證）。

### FR-2：everything-as-tags 書籍物件（canonical §4）

每本書匯出為 canonical Book 物件，核心欄位：

- 固定欄位：`id`（原樣保留）、`title`、`cover`（多尺寸物件）、`crossPlatformId`、`dataFingerprint`、`progress`、`createdAt`、`updatedAt`、`activeLoan`、`extensions`、`_passthrough`
- `tags` 物件（everything-as-tags 核心）：按類別分組，含 `author`/`publisher`/`platform`/`language`/`isbn`/`alias`/`readingStatus`/`importance`/`series`/`description`/`ccl`/`custom`

每個 tag node 結構：`{id, name, path?}`（path 僅 ccl/custom 等樹狀類別）。

### FR-3：pass-through 保留（canonical §9）

匯出時 `_passthrough` 內容平鋪回頂層，`extensions` 物件原樣輸出。對方 pass-through 進來的欄位不可在匯出時 strip。

### FR-4：tagTree 隨本體匯出（canonical §6）

匯出時 root `tagTree` 包含所有需同步的 tag 樹節點（ccl 系統樹 + custom 自訂樹），節點欄位：`{id, name, parentId, locked}`。

### FR-5：CSV 為人類可讀，不跨專案 round-trip（canonical §10）

CSV 匯出定位為「給想自行整理書目而不透過配套 APP 的用戶」，匯入 spreadsheet 用。CSV 欄位刻意單純，不含自訂 tag 樹等複雜結構。

- CSV 不保證跨專案（APP <-> V1）無損互通；雙向無損同步一律走 JSON canonical。
- APP 自身的 CSV 匯出 -> 自身匯入（id-based round-trip）仍支援，服務本地 spreadsheet 工作流。
- tags 分隔符為 `; `（分號 + 空格）。

### FR-6：匯出範圍選擇

使用者可選擇匯出範圍：

| 範圍類型 | 說明 | 對應實作 |
|---------|------|---------|
| 全部書籍 | 匯出書庫中所有書籍 | `AllBooksScope` |
| 依來源篩選 | 依書籍來源平台篩選（如 readmoo、kobo） | `BySourceScope(sources: Set<String>)` |
| 依標籤篩選 | 依指定標籤篩選 | `ByTagsScope(tags: Set<String>)` |
| 依日期範圍 | 依建立/更新日期範圍篩選 | `ByDateRangeScope(startDate, endDate)` |

### FR-7：匯出格式選擇

| 格式 | 副檔名 | 已實作 | 說明 |
|------|--------|-------|------|
| JSON | `.json` | 是 | 主要匯出格式，遵循 canonical v3.0.0 |
| CSV | `.csv` | 是 | 人類可讀格式，spreadsheet 匯入用 |
| PDF | `.pdf` | 否 | 規劃中，尚未實作 |

### FR-8：匯出進度回饋

匯出過程中提供即時進度回饋：

- 進度百分比（`percentage`）
- 已處理/總計書籍數（`processedItems`/`totalItems`）
- 預估剩餘時間（`estimatedTimeRemaining`）
- 進度每 100-200ms 更新一次

#### 按鈕層級三層回饋

匯出觸發按鈕必須提供完整的三層回饋（依據 `.claude/skills/ux-design-evaluation/references/interaction-feedback.md` 三層模型與時間門檻 100ms / 400ms / 1s）：

| 層次 | 時機 | 要求 |
|------|------|------|
| 1. 點擊確認 | 按下後 0-100ms | 按下即時視覺回饋（視覺狀態變化 / ripple / 觸覺） |
| 2. 等待指示 | 處理中（> 100ms） | 顯示 loading 指示（spinner / 按鈕 loading 狀態），且按鈕禁用防重複提交 |
| 3. 結果通知 | 處理完成 | 成功訊息含檔案產出確認（檔案名稱或路徑）；失敗訊息含失敗原因與重試入口 |

### FR-9：匯出歷史紀錄

系統記錄每次匯出操作的歷史，供使用者回顧：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | `String` | 紀錄唯一識別碼 |
| `timestamp` | `DateTime` | 匯出時間 |
| `fileName` | `String` | 匯出檔案名稱 |
| `format` | `String` | 匯出格式（json/csv） |
| `range` | `String` | 匯出範圍 |
| `selectedSources` | `List<String>` | 選定來源 |
| `exportedBookCount` | `int` | 匯出書籍數量 |
| `fileSize` | `int` | 檔案大小（bytes） |
| `filePath` | `String` | 檔案儲存路徑 |

### FR-10：匯出完成後操作

匯出成功後提供：

- 分享檔案（`shareExportedFile`）
- 查看檔案位置（`viewFileLocation`）
- 重新匯出（`retryExport`）

---

## 業務規則 (BR)

### BR-1：空書庫禁止匯出

匯出前檢查書庫是否為空。若查詢結果為零筆書籍，回傳錯誤「沒有符合條件的書籍可匯出」，禁止產生空白匯出檔案。

### BR-2：totalBooks 交叉驗證

JSON 匯出的 `metadata.totalBooks` 必須與 `books` 陣列長度一致。不一致時禁止靜默匯出，回報錯誤。

### BR-3：id 原樣保留

匯出書籍 `id` 原樣輸出，禁止在匯出過程中重新生成 id。

### BR-4：pass-through 無損

匯入時保留的 `_passthrough` 與 `extensions` 欄位，在匯出時必須一同帶出，不可 strip。

### BR-5：預設檔案名稱格式

預設檔案名稱為 `我的書庫_YYYYMMDD.{ext}`，其中 `{ext}` 依格式為 `json` 或 `csv`。

### BR-6：CSV 欄位配置

CSV 匯出支援：

- 欄位選擇（`selectedFields`）：使用者可選擇要匯出的欄位
- 表頭語言（`useChineseHeader`）：支援中文表頭切換
- 分隔符（`delimiter`）：預設為逗號
- 編碼（`encoding`）：預設 UTF-8

### BR-7：匯出失敗清理

匯出過程中發生錯誤時，系統應嘗試刪除不完整的匯出檔案，避免殘留無效檔案。

### BR-8：儲存空間不足處理

匯出前或匯出中偵測到儲存空間不足時：

- 計算所需空間大小與可用空間對比
- 提供清理快取、選擇其他儲存位置、分批匯出等解決方案
- 分類為 `ExportErrorType.storageInsufficient`

### BR-9：interchangeJson 格式選擇

`InterchangeExportService` 支援兩種 JSON 匯出格式：

| 格式 | 說明 | 用途 |
|------|------|------|
| `canonicalV3`（預設） | canonical book-interchange-v1 v3.0.0 | 跨專案標準交換 |
| `legacyArray` | 純書籍陣列 | 向後相容舊版 Chrome Extension |

### BR-10：衍生統計 reactive 一致性

資料管理頁的衍生統計顯示（書籍統計、書庫狀態，對應 `DataManagementState` 的 `totalBooks`、`isEmpty`、`lastUpdate`、`storageSize` 等欄位）必須響應底層書庫資料變更自動更新（透過 Riverpod `ref.watch` reactive 監聽），不得依賴頁面重進或手動刷新才反映最新狀態。

- 使用者從資料管理頁進入新增流程加書後返回，統計數字必須立即更新，不需回首頁再進入即可看到最新資料。
- `refreshLibraryStatus` 作為手動重新整理入口保留，但不得成為統計更新的唯一途徑。
- 本規則為 App-wide「衍生視圖必須 reactive」通則在匯出 domain 的實例：canonical 依據見 `docs/event-driven-architecture-design.md`「資料變更傳播（State Propagation）」章（含禁以 domain event 作 UI 刷新訊號的職責邊界）；資料變更觀測出口契約見 `docs/spec/library/book-repository-contract.md`（SPEC-011 watchBooks 語意）。

---

## 介面契約 (API)

### Use Case 層

#### `ExportBooksUseCase`

位置：`lib/use_cases/export/export_books_usecase.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `execute` | `Future<_ExportResponse> execute(ExportRequest request)` | 執行匯出流程（查詢 -> 配置 -> CSV 匯出 -> 回傳結果） |

**ExportRequest**（輸入）：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `range` | `dynamic` | 是 | 匯出範圍（allBooks / specificSource） |
| `selectedSources` | `Set<String>` | 是 | 選定來源平台 |
| `format` | `dynamic` | 是 | 匯出格式 |
| `fileName` | `String` | 是 | 檔案名稱 |
| `outputPath` | `String` | 是 | 輸出路徑 |

**_ExportResponse**（輸出）：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `success` | `bool` | 是否成功 |
| `filePath` | `String?` | 匯出檔案路徑 |
| `fileSize` | `double?` | 檔案大小（MB） |
| `exportedBookCount` | `int?` | 匯出書籍數量 |
| `error` | `String?` | 錯誤訊息 |

### Domain 層 — 服務

#### `InterchangeExportService`

位置：`lib/domains/export/services/interchange_export_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `exportInterchangeJson` | `Future<String> exportInterchangeJson({InterchangeExportFormat format = InterchangeExportFormat.canonicalV3})` | 匯出 JSON 字串（canonical 或 legacy 格式） |

依賴：`BookRepository`（讀取全部書籍 + tagTree）

#### `BookQueryService`

位置：`lib/domains/export/services/book_query_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `queryBooks` | 依 scope 查詢書籍 | 主查詢入口 |
| `countBooks` | 計算書籍數量 | 預覽用 |

篩選方法：`_filterBooksBySource`、`_filterBooksByTags`、`_filterBooksByDateRange`

#### `DataValidationService`

位置：`lib/domains/export/services/data_validation_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `validateBook` | 驗證單本書籍資料 | 檢查必填欄位、欄位長度、日期格式、分類 |
| `validateBooks` | 批次驗證 | 驗證多本書籍 |

回傳 `ValidationResult`：`{isValid: bool, errors: List<String>}`

#### `JsonSerializationService`

位置：`lib/domains/export/services/json_serialization_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `serializeBook` | 單本序列化 | Book -> JSON Map |
| `serializeBooks` | 批次序列化 | List<Book> -> JSON List |
| `deserializeBook` | 反序列化 | JSON Map -> Book |
| `deserializeBooks` | 批次反序列化 | JSON List -> List<Book> |

#### `DataTransformService`

位置：`lib/domains/export/services/data_transform_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `transformBook` | 單本轉換 | Domain -> 匯出格式 |
| `transformBooks` | 批次轉換 | 多本書籍 |
| `transformWithProgress` | 含進度回調 | 透過 `ProgressCallback` 報告進度 |

#### `FileHandlingService`

位置：`lib/domains/export/services/file_handling_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `writeFile` | 寫入檔案 | 異步 I/O |
| `readFile` | 讀取檔案 | 異步 I/O |
| `verifyFileIntegrity` | 驗證檔案完整性 | 確認寫入正確 |

#### `ProgressStatsService`

位置：`lib/domains/export/services/progress_stats_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `calculatePercentage` | 計算進度百分比 | processed / total |
| `estimateTimeRemaining` | 預估剩餘時間 | 依處理速率推算 |
| `calculateSuccessRate` | 計算成功率 | 成功 / 總計 |
| `calculateItemsPerSecond` | 計算處理速率 | items / elapsed |

### Domain 層 — CSV 服務

#### `CsvExportService`

位置：`lib/domains/export/csv/services/csv_export_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `exportToCsv` | `Future<OperationResult<CsvExportResult>> exportToCsv({required List<Book> books, required CsvExportConfiguration configuration})` | 完整 CSV 匯出流程 |
| `getExportStats` | 取得匯出統計 | |
| `validateExportSetup` | 驗證匯出配置 | |

內部流程：驗證配置 -> 映射欄位 -> 生成表頭 -> 轉換資料 -> 寫入檔案 -> 驗證檔案 -> 回傳結果

依賴服務：`CsvFieldMapper`、`CsvDataTransformer`、`CsvHeaderGenerator`、`CsvFileWriter`、`EventBus`

#### `CsvFieldMapper`

位置：`lib/domains/export/csv/services/csv_field_mapper.dart`

將 domain 欄位名稱映射為 CSV 欄位定義（`CsvFieldMapping`）。

#### `CsvHeaderGenerator`

位置：`lib/domains/export/csv/services/csv_header_generator.dart`

依 `CsvFieldMapping` 生成 CSV 標題行，支援中/英文表頭。

#### `CsvDataTransformer`

位置：`lib/domains/export/csv/services/csv_data_transformer.dart`

將 `List<Book>` 轉換為 CSV 資料行。

#### `CsvFileWriter`

位置：`lib/domains/export/csv/services/csv_file_writer.dart`

寫入 CSV 檔案並驗證寫入結果。

### Infrastructure 層

#### `DataExportService`

位置：`lib/infrastructure/export/data_export_service.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| `exportAllBooks` | `Future<String> exportAllBooks(String format, String outputDir)` | 匯出全部書籍 |
| `exportBooks` | `Future<String> exportBooks(List<String> bookIds, String format, String outputDir)` | 依 ID 匯出指定書籍 |
| `importBooks` | 匯入書籍 | |
| `createBackup` | 建立備份 | |
| `restoreFromBackup` | 從備份還原 | |
| `getSupportedFormats` | 取得支援格式清單 | |

內部透過 `DataExporter` 策略模式分派：

| 實作 | 格式 | 副檔名 |
|------|------|--------|
| `JsonDataExporter` | JSON | `.json` |
| `CsvDataExporter` | CSV | `.csv` |

#### `ExportHistoryRepository`

位置：`lib/infrastructure/export/repositories/export_history_repository.dart`

匯出歷史紀錄持久化。

#### `FileService`

位置：`lib/infrastructure/export/services/file_service.dart`

平台層檔案操作封裝（分享、開啟位置等）。

### Presentation 層

#### `ExportViewModel`

位置：`lib/presentation/export/viewmodels/export_viewmodel.dart`

| 方法 | 說明 |
|------|------|
| `setExportRange` | 設定匯出範圍 |
| `toggleSource` | 切換來源選擇 |
| `setExportFormat` | 設定匯出格式 |
| `setFileName` | 設定檔案名稱 |
| `validateConfiguration` | 驗證配置 |
| `loadSourceBookCounts` | 載入各來源書籍數量 |
| `startExport` | 開始匯出 |
| `cancelExport` | 取消匯出 |
| `retryExport` | 重試匯出 |
| `cleanCacheAndRetry` | 清理快取後重試 |
| `chooseLocationAndRetry` | 選擇其他位置後重試 |
| `performBatchExport` | 批次匯出 |
| `shareExportedFile` | 分享匯出檔案 |
| `viewFileLocation` | 查看檔案位置 |
| `reset` | 重設狀態 |

#### `DataManagementViewModel`

位置：`lib/presentation/export/viewmodels/data_management_viewmodel.dart`

| 方法 | 說明 |
|------|------|
| `loadData` | 載入書庫狀態與匯出歷史 |
| `refreshLibraryStatus` | 重新整理書庫狀態 |
| `loadFullHistory` | 載入完整匯出歷史 |

---

## 資料模型

### Value Objects

#### `ExportConfiguration`

位置：`lib/domains/export/value_objects/export_configuration.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `format` | `ExportFormat` | 匯出格式（json/csv/pdf） |
| `scope` | `ExportScope` | 匯出範圍 |
| `exportPath` | `String` | 匯出路徑 |
| `options` | `Map<String, dynamic>` | 額外選項 |

支援 `copyWith`、`toJson`/`fromJson` 序列化。

#### `ExportScope`（sealed class hierarchy）

位置：`lib/domains/export/value_objects/export_scope.dart`

| 子類別 | 欄位 | 工廠建構子 |
|-------|------|----------|
| `AllBooksScope` | — | `ExportScope.all()` |
| `BySourceScope` | `sources: Set<String>` | `ExportScope.bySource(sources)` |
| `ByTagsScope` | `tags: Set<String>` | `ExportScope.byTags(tags)` |
| `ByDateRangeScope` | `startDate`, `endDate` | `ExportScope.byDateRange(start, end)` |

#### `ExportFormat`（enum）

位置：`lib/domains/export/value_objects/export_format.dart`

| 值 | description | fileExtension | isImplemented |
|----|------------|---------------|---------------|
| `json` | JSON 格式 | `.json` | true |
| `csv` | CSV 格式 | `.csv` | true |
| `pdf` | PDF 格式 | `.pdf` | false |

#### `ExportProgress`

位置：`lib/domains/export/value_objects/export_progress.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `percentage` | `double` | 進度百分比 (0.0-1.0) |
| `processedItems` | `int` | 已處理項目數 |
| `totalItems` | `int` | 總項目數 |
| `estimatedTimeRemaining` | `Duration?` | 預估剩餘時間 |

計算屬性：`remainingItems`、`isComplete`、`isEmpty`、`isProcessing`

#### `ExportResult`

位置：`lib/domains/export/value_objects/export_result.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `filePath` | `String` | 匯出檔案路徑 |
| `totalItems` | `int` | 總項目數 |
| `exportedItems` | `int` | 成功匯出數 |
| `skippedItems` | `int` | 跳過項目數 |
| `fileSize` | `int` | 檔案大小（bytes） |
| `processingTime` | `Duration` | 處理時間 |
| `sourceBreakdown` | `Map<String, int>?` | 依來源分類統計 |

計算屬性：`successRate`、`isFullSuccess`、`isPartialSuccess`、`fileSizeInMB`、`itemsPerSecond`

#### `ChromeExtensionBookData`

位置：`lib/domains/export/value_objects/chrome_extension_book_data.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | `String` | 書籍 ID |
| `title` | `String` | 書名 |
| `author` | `String` | 作者 |
| `isbn` | `String?` | ISBN |
| `categories` | `List<String>` | 分類 |
| `exportDate` | `DateTime` | 匯出日期 |
| `source` | `String` | 來源 |
| `customFields` | `Map<String, dynamic>` | 自訂欄位 |

提供 `fromBook` 工廠建構子與 `toJson` 序列化。

### CSV 資料模型

#### `CsvExportConfiguration`

位置：`lib/domains/export/csv/models/csv_export_configuration.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `filePath` | `String` | 輸出檔案路徑 |
| `encoding` | `String` | 編碼（預設 UTF-8） |
| `delimiter` | `String` | 分隔符（預設逗號） |
| `selectedFields` | `List<String>` | 選定匯出欄位 |
| `includeHeader` | `bool` | 是否包含表頭 |
| `useChineseHeader` | `bool` | 是否使用中文表頭 |

提供 `validate()` 方法回傳錯誤清單。

#### `CsvExportResult`

位置：`lib/domains/export/csv/models/csv_export_result.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `filePath` | `String` | 輸出檔案路徑 |
| `exportedRows` | `int` | 成功匯出行數 |
| `skippedRows` | `int` | 跳過行數 |
| `fileSize` | `double` | 檔案大小 |
| `processingTime` | `int` | 處理時間（ms） |

計算屬性：`totalRows`、`processingRate`

#### `CsvFieldMapping`

位置：`lib/domains/export/csv/models/csv_field_mapping.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `fieldName` | `String` | 程式欄位名稱 |
| `displayName` | `String` | 顯示名稱 |
| `order` | `int` | 欄位順序 |
| `isRequired` | `bool` | 是否必填 |
| `description` | `String` | 欄位說明 |
| `dataType` | `String` | 資料型別 |

靜態欄位：`predefinedFields`（預定義可選欄位清單）、`requiredFields`（必填欄位清單）

### Presentation 狀態模型

#### `ExportState`

位置：`lib/presentation/export/viewmodels/export_state.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `range` | `ExportRange` | allBooks / specificSource |
| `selectedSources` | `Set<String>` | 選定來源 |
| `format` | `ExportFormat` | json / csv |
| `fileName` | `String` | 檔案名稱 |
| `sourceBookCounts` | `Map<String, int>` | 各來源書籍數 |
| `status` | `ExportStatus` | idle / inProgress / completed / failed |
| `progress` | `double` | 進度 (0.0-1.0) |
| `processedBooks` | `int` | 已處理書籍數 |
| `totalBooks` | `int` | 總書籍數 |
| `filePath` | `String?` | 匯出檔案路徑 |
| `fileSize` | `double?` | 檔案大小 |
| `error` | `ExportError?` | 錯誤資訊 |

#### `ExportError`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `type` | `ExportErrorType` | storageInsufficient / permissionDenied / unknown |
| `message` | `String` | 錯誤訊息 |
| `requiredStorage` | `int?` | 所需儲存空間 |
| `availableStorage` | `int?` | 可用儲存空間 |

#### `DataManagementState`

位置：`lib/presentation/export/viewmodels/data_management_state.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `isLoading` | `bool` | 載入中 |
| `isEmpty` | `bool` | 書庫是否為空 |
| `totalBooks` | `int` | 書籍總數 |
| `lastUpdate` | `DateTime?` | 最後更新時間 |
| `storageSize` | `String` | 儲存空間大小 |
| `recentHistory` | `List<ExportHistoryItem>` | 近期匯出歷史 |

---

## 事件系統

匯出流程透過 EventBus 發布事件，Presentation 層訂閱以更新 UI。

### 通用匯出事件

| 事件 | 檔案 | 觸發時機 |
|------|------|---------|
| `ExportInitiatedEvent` | `export_initiated_event.dart` | 匯出開始 |
| `BookDataQueriedEvent` | `book_data_queried_event.dart` | 書籍資料查詢完成 |
| `DataValidatedEvent` | `data_validated_event.dart` | 資料驗證完成 |
| `DataTransformedEvent` | `data_transformed_event.dart` | 資料轉換完成 |
| `JsonSerializedEvent` | `json_serialized_event.dart` | JSON 序列化完成 |
| `FileWrittenEvent` | `file_written_event.dart` | 檔案寫入完成 |
| `ExportProgressUpdatedEvent` | `export_progress_updated_event.dart` | 進度更新 |
| `ExportStatisticsUpdatedEvent` | `export_statistics_updated_event.dart` | 統計更新 |
| `ExportCompletedEvent` | `export_completed_event.dart` | 匯出成功完成 |
| `ExportFailedEvent` | `export_failed_event.dart` | 匯出失敗 |
| `ExportCancelledEvent` | `export_cancelled_event.dart` | 匯出取消 |
| `ExportWarningEvent` | `export_warning_event.dart` | 匯出警告 |

事件目錄：`lib/domains/export/events/`

### CSV 匯出事件

| 事件 | 觸發時機 |
|------|---------|
| `CsvExportStarted` | CSV 匯出開始 |
| `CsvDataTransformationCompleted` | CSV 資料轉換完成 |
| `CsvExportCompleted` | CSV 匯出成功 |
| `CsvExportFailed` | CSV 匯出失敗 |

事件定義：`lib/domains/export/csv/events/csv_export_events.dart`

---

## Riverpod Provider 依賴鏈

位置：`lib/presentation/export/export_providers.dart`

```
exportHistoryRepositoryProvider
fileServiceProvider
csvFieldMapperProvider -----+
csvDataTransformerProvider --+
csvHeaderGeneratorProvider --+
csvFileWriterProvider -------+
                             +--> csvExportServiceProvider
                                          |
                                          v
                             exportBooksUseCaseProvider
                                          |
                                          v
                             exportViewModelProvider
                             dataManagementViewModelProvider
```

---

## 非功能需求 (NFR)

### NFR-1：匯出完整性

匯出 JSON 的 `totalBooks` 必須與 `books` 陣列長度相符；不符時禁止靜默匯出，回報錯誤。

### NFR-2：pass-through 無損

匯入時保留的 `_passthrough` 與 `extensions` 欄位，在匯出時必須一同帶出，不可 strip（canonical C1 雙向無損）。

### NFR-3：id 保留

匯出書籍 `id` 原樣輸出，禁止在匯出過程中重生 id。

### NFR-4：效能目標

| 指標 | 目標值 | 說明 |
|------|-------|------|
| UI 響應延遲 | < 100ms | 匯出啟動後 UI 立即回應 |
| 主執行緒阻塞 | < 16ms | 使用 Isolate 異步序列化 |
| JSON 序列化 | < 2s/1000本 | Stream 分批處理 |
| 檔案寫入 | < 1s | 異步 I/O |
| 1000本書籍總時間 | ~3-5s | 視設備效能 |
| 記憶體峰值 | < 100MB | Stream 分批避免完整載入 |
| 進度回饋頻率 | 100-200ms | 每次更新一次 |

### NFR-5：錯誤處理

| 錯誤類型 | 處理方式 |
|---------|---------|
| 書籍資料驗證失敗 | `ValidationException`，含欄位層級錯誤清單 |
| 匯出格式不支援 | `DataExportException` |
| 檔案寫入失敗 | `StorageException`，清理不完整檔案 |
| 空間不足 | `ExportErrorType.storageInsufficient`，附空間數據 |
| 權限不足 | `ExportErrorType.permissionDenied` |
| 一般異常 | `AppException` 統一包裝，回傳使用者友善訊息 |

---

## 需求與實作差距分析

| 差距項目 | 需求來源 | 實作現狀 | 差距說明 |
|---------|---------|---------|---------|
| PDF 匯出 | `ExportFormat.pdf`（enum 已定義） | `isImplemented = false` | enum 已預留但功能未實作 |
| CSV 欄位規格文件 | FR-5 提及「各自 CSV 規格文件（本專案無另立，待補）」 | 無獨立 CSV 欄位規格文件 | `CsvFieldMapping.predefinedFields` 已有實作但無對應規格文件 |
| ExportRequest 型別安全 | — | `range` 和 `format` 宣告為 `dynamic` | 建議改為具體型別（`ExportRange`、`ExportFormat`） |
| JSON 匯出路徑整合 | FR-1（canonical JSON） | `InterchangeExportService`（domain 層）與 `JsonDataExporter`（infrastructure 層）並存 | 兩條 JSON 匯出路徑語意重疊，前者走 canonical v3.0.0、後者走 legacy `BookExportData` 格式，尚未統一 |
| 匯出範圍與 ExportScope 對齊 | FR-6 | `ExportBooksUseCase` 使用 `ExportRequest.range`（dynamic），未使用 domain 層 `ExportScope` | Use Case 層與 Domain 層範圍抽象未對齊 |
| ChromeExtensionBookData 與 canonical 對齊 | FR-2 | `ChromeExtensionBookData` 欄位為舊 flat 結構（author/isbn/categories），非 everything-as-tags | Value Object 尚未遷移至 canonical tag 結構 |

---

## 相關規格

- canonical SSOT：`book_overview_v1/docs/spec/book-interchange-v1.md`（格式定義、tagTree、pass-through、CSV 定位）
- PROP-007：`docs/proposals/PROP-007-cross-project-spec-alignment.md`（跨專案對齊提案）
- SPEC-002：`docs/spec/import/chrome-extension-import.md`（匯入端，與本匯出規格對稱）
- SPEC-008：`docs/spec/synchronization/cross-platform-sync.md`（dedup 機制）

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-02：匯出書庫資料

---

**Last Updated**: 2026-07-17 | **Version**: 2.3.1 — FR-8 三層回饋引用路徑更新：ux-interaction-feedback skill 由升級版 ux-design-evaluation 取代，改指 `references/interaction-feedback.md`（skill 庫同步，內容契約不變）
**Version**: 2.3 — BR-10 補交叉引用：指向 event-driven-architecture-design.md「資料變更傳播」App-wide reactive 通則與 SPEC-011 book-repository-contract watchBooks 契約（0.38.1-W1-105）
**Version**: 2.2 — 新增 BR-10 衍生統計 reactive 一致性（書籍統計、書庫狀態須響應底層書庫資料變更自動更新，Riverpod ref.watch reactive 監聽，不得依賴頁面重進或手動刷新）（0.38.1-W1-094）
**Version**: 2.1 — FR-8 補按鈕層級三層回饋條款（點擊確認/等待指示/結果通知，引用 ux-interaction-feedback 時間門檻 100ms/400ms/1s）（0.38.1-W1-093）
**Version**: 2.0 — 充實 spec：新增 FR-6~10（範圍選擇、格式選擇、進度回饋、歷史紀錄、完成後操作）；新增 BR-1~9（業務規則）；新增完整介面契約（Use Case / Domain / Infrastructure / Presentation 四層 method signature 與參數型別）；新增資料模型（Value Objects + CSV 模型 + Presentation 狀態模型）；新增事件系統清單；新增 Provider 依賴鏈；NFR 補實效能目標與錯誤處理；新增需求與實作差距分析（6 項）（0.35.0-W3-003）
