---
id: SPEC-002
title: "Chrome Extension 匯入規格"
status: draft
source_proposal: PROP-007
created: "2026-03-30"
updated: "2026-06-20"
version: "2.0"
owner: ""

domain: import
subdomain: null

related_usecases: [UC-01]
related_specs: [SPEC-003, SPEC-008]
implements_requirements: []
depends_on_domains: []
---

# Chrome Extension 匯入規格

## 概述

定義從 Chrome Extension（readmoo-book-extractor）匯入書庫資料的流程、格式辨識、資料轉換與 id 保留規則。

跨專案交換格式以 canonical SSOT 為準：`book_overview_v1/docs/spec/book-interchange-v1.md`（book-interchange-v1 v3.0.0）。

---

## 功能需求 (FR)

### FR-1：格式辨識（detector 四來源）

匯入端依下列優先序辨識來源格式（高 → 低），對應 canonical §8：

| 優先序 | 條件 | 判定 |
|--------|------|------|
| 1 | `format === "book-interchange-v1"` | canonical v3.x（讀 `formatVersion` 決定分支）|
| 2 | `metadata.formatVersion` 以 `2.` 開頭（無 `format` 欄位）| V1 舊內部 v2 格式（相容讀）|
| 3 | 含 `backup_info`/`export_info` wrapper 且有 `books[]` | APP legacy fixed-field（v0.31.x，經 legacy adapter）|
| 4 | 純陣列 或 `{books:[]}` 無版本標記 | flat v1（legacy converter）|

所有四類來源均可匯入；不符合任一條件時回報格式錯誤，禁止靜默失敗。

### FR-2：id 保留（canonical C4）

匯入所有來源時，書籍原始 `id` 必須原樣保留，禁止重生新 id。

Extension 產生的 readmoo stable id（如 `"210327003000101"`）與 APP 自建書 id（如 `"book_{timestamp}"`）皆遵循此規則。

### FR-3：pass-through 保留（canonical §9）

匯入端對未知欄位必須原樣保留，禁止 strip：

- `extensions` 物件：對方平台的已知專屬欄位（如 `extensions.readmoo-book-extractor.extractedAt`）保留不修改。
- `_passthrough` 物件：完全未知的頂層欄位，原樣寫入 `_passthrough`，下次匯出時平鋪回頂層。

### FR-4：readingStatus 正規化（canonical §7）

匯入時依下表正規化 `tags.readingStatus`：

| canonical name | Extension v2 原值 | 說明 |
|----------------|-------------------|------|
| not_started | unread | 對應轉換 |
| queued | queued | 直通 |
| reading | reading | 直通 |
| finished | finished | 直通 |
| abandoned | abandoned | 直通 |
| reference | reference | 直通 |

無對應態時，記入 `_passthrough.readingStatusRaw` 保留原值（C1 無損）。

**實作補充**：ViewModel 層另有 Chrome legacy 詞彙對照表（`_chromeLegacyStatusMap`），將 `completed` → `finished`、`paused` → `queued`、`unread` → `notStarted` 後委託 `ReadingStatusExtension.fromString` 統一解析。

### FR-5：tagTree 重建（canonical §6）

匯入資料含 `tagTree` 時，依其 `ccl`/`custom` 節點陣列重建對方的 tag 樹結構。節點欄位：`{id, name, parentId, locked}`。

### FR-6：檔案選擇與驗證

| 步驟 | 說明 |
|------|------|
| 選擇檔案 | 透過系統檔案選擇器（`FileService.pickJsonFile()`）選擇 `.json` 檔案 |
| 格式驗證 | `ChromeExtensionValidationService.validateChromeExtensionFormat()` 驗證結構 |
| 驗證規則 | 必填欄位 `title`、`author`；選填 `isbn`（ISBN-10/13 checksum 驗證）、`publishDate`（ISO 8601）、`rating`（0-5）|
| 品質門檻 | 無效書籍超過有效書籍數量時，拒絕整個檔案 |

### FR-7：重複書籍偵測與處理

**偵測邏輯**（`_findDuplicate` / `_findExistingBook`）：

| 優先序 | 比對方式 | 說明 |
|--------|---------|------|
| 1 | ISBN 完全一致 | `BookService.getBookByIsbn()` 或 tag 比對 |
| 2 | 標題 + 作者（case-insensitive） | 全量 `getAllBooks()` 逐一比對 |

**處理策略**（`DuplicateHandlingStrategy`）：

| 策略 | 行為 |
|------|------|
| `skip` | 跳過重複書籍，僅匯入新書 |
| `overwrite` | 以匯入資料完整覆蓋既有書籍（保留 existing.id） |
| `merge` | 智慧合併：existing 優先，imported 補缺值（isbn/publisher/description/coverImageUrl/rating/custom tags） |
| `cancel` | 取消整個匯入 |

**批次重複預警**（FR-7a）：匯入前偵測檔案內部重複 id（`_countBulkDuplicatePatterns()`），預先警告使用者。

### FR-8：匯入取消與回滾

| 階段 | 行為 |
|------|------|
| 處理階段（Phase 1） | 逐筆建立匯入計畫（`_BookImportAction`），不寫入資料庫；使用者可隨時取消，無殘留 |
| 提交階段（Phase 2） | 依計畫批次寫入資料庫 |
| 取消流程 | `requestCancelImport()` → 顯示確認對話框 → `confirmCancelImport()` 設定旗標 → 下一筆前中止 → `_rollbackImportedBooks()` 逐一刪除已寫入書籍 |
| 系統錯誤恢復 | 自動回滾 + 顯示錯誤恢復選項（重試 `retryImport()` / 回報 `reportError()`） |

### FR-9：匯入結果統計

匯入完成後提供統計：

| 指標 | 說明 |
|------|------|
| `importedBooks` | 成功匯入（含新增和覆蓋/合併）數量 |
| `skippedBooks` | 因重複策略跳過的數量 |
| `failedBooks` | 解析失敗的書籍數量 |
| `errors` | 失敗書籍的錯誤訊息列表（限 5 則） |

---

## 業務規則 (BR)

### BR-1：JSON 解析策略

| 條件 | 解析方式 |
|------|---------|
| 輸入為 `List` | 直接視為書籍陣列 |
| 輸入為 `Map`，含 `books` / `data` / `items` 鍵 | 取該鍵的陣列值 |
| 其他 | 回傳空列表 |

### BR-2：書籍建立規則

| 欄位 | 來源 | 預設值 |
|------|------|--------|
| `id` | `data['id']` | `''`（空字串） |
| `title` | `data['title']` | `'Unknown Title'` |
| `author` | `data['author']` | `'Unknown Author'` |
| `sourceType` | 固定 | `SourceType.physical`（等價舊 imported） |
| `readingStatus` | `data['readingStatus']` 經 `_parseImportReadingStatus()` | `ReadingStatus.notStarted` |
| `tags` | `data['tags']` | `[]` |

### BR-3：合併策略詳細規則

合併時（`_mergeBooks()`）以 existing 為基底，imported 補缺值：

| 欄位 | 合併規則 |
|------|---------|
| `publishDate` | imported 有值時覆蓋 |
| `description` | imported 更長時覆蓋 |
| `coverImageUrl` | imported 有值時覆蓋 |
| `rating` | imported 有值時覆蓋 |
| `isbn` tag | existing 無值、imported 有值時補入 |
| `publisher` tag | existing 無值、imported 有值時補入 |
| custom tags | 去重合併（case-insensitive，imported 覆蓋同名 tag） |
| non-custom tags | 保留 existing |

### BR-4：錯誤分類

| 錯誤類型 (`JsonErrorType`) | 觸發條件 | 使用者訊息 |
|---------------------------|---------|-----------|
| `syntax` | `FormatException`（非 encoding） | "檔案格式不正確，請確認為Chrome Extension匯出的JSON檔案" |
| `structure` | 驗證失敗（缺必填欄位、品質門檻不過） | "缺少必要欄位，請檢查檔案格式" |
| `encoding` | encoding/utf/codec/charset/bom 關鍵字或 `UnicodeException` 等 | "檔案編碼問題，請確認檔案使用 UTF-8 編碼" |

### BR-5：更新資訊判定（`_hasNewerInfo()`）

imported 滿足以下任一條件時判定為「有更新資訊」：

- imported 有 ISBN 而 existing 無
- imported 有 publisher 而 existing 無
- imported description 長度 > existing description 長度

---

## 介面契約 (API)

### Presentation 層

#### ChromeExtensionImportViewModel

```dart
class ChromeExtensionImportViewModel extends Notifier<ChromeExtensionImportState> {
  // 公開方法
  Future<void> selectFile();
  Future<void> startImport();
  Future<void> handleDuplicateStrategy(DuplicateHandlingStrategy strategy);
  Future<void> handleBulkDuplicateStrategy(DuplicateHandlingStrategy strategy);
  void requestCancelImport();
  void dismissCancelDialog();
  void confirmCancelImport();
  void reset();
  Future<void> retry();
  Future<void> retryImport();
  void reportError();
  void clearSelectedFile();
}
```

#### ChromeExtensionImportState

```dart
class ChromeExtensionImportState extends Equatable {
  final ChromeExtensionImportStatus status;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? errorMessage;
  final JsonErrorType? errorType;
  final int totalBooks;
  final int processedBooks;
  final int importedBooks;
  final int skippedBooks;
  final int failedBooks;
  final String? currentBookTitle;
  final List<String>? errors;
  final List<DuplicateBookInfo>? detectedDuplicates;
  final DuplicateHandlingStrategy? selectedStrategy;
  final bool showDuplicateDialog;
  final bool showBulkDuplicateWarning;
  final int bulkDuplicatePatternCount;
  final bool showCancelDialog;
  final bool isCancelled;
  final bool showErrorRecovery;

  // 計算屬性
  bool get hasSelectedFile;
  bool get isValidating;
  bool get hasValidationError;
  bool get isImporting;
  bool get isCompleted;
  bool get hasError;
  bool get canSelectFile;
  bool get canStartImport;
  bool get canRetry;
  bool get showProgress;
  bool get showResult;
  double? get importProgress;       // 0.0 ~ 1.0
  Map<String, int>? get importStats; // {imported, skipped, failed}
}
```

#### 狀態機（ChromeExtensionImportStatus）

```
initial ──selectFile()──> fileSelected
                            |
                      _validateFile()
                           / \
                validationFailed  fileSelected
                     |               |
                  retry()       startImport()
                     |               |
                  fileSelected   importing
                                    |
                              /     |     \
                       completed  error  (cancelled->initial)
```

#### Providers

| Provider | 型別 | 說明 |
|----------|------|------|
| `chromeExtensionImportViewModelProvider` | `NotifierProvider<..., ChromeExtensionImportState>` | 主 ViewModel |
| `chromeExtensionImportStateProvider` | `Provider<ChromeExtensionImportState>` | 狀態便利存取 |
| `hasSelectedFileProvider` | `Provider<bool>` | 是否已選檔 |
| `isValidatingProvider` | `Provider<bool>` | 驗證中 |
| `hasValidationErrorProvider` | `Provider<bool>` | 驗證失敗 |
| `isImportingProvider` | `Provider<bool>` | 匯入中 |
| `isImportCompletedProvider` | `Provider<bool>` | 匯入完成 |
| `hasImportErrorProvider` | `Provider<bool>` | 匯入錯誤 |
| `selectedFileNameProvider` | `Provider<String?>` | 已選檔案名 |
| `importErrorMessageProvider` | `Provider<String?>` | 錯誤訊息 |
| `importProgressProvider` | `Provider<double?>` | 進度值 |
| `importStatsProvider` | `Provider<Map<String, int>?>` | 統計結果 |
| `canSelectFileProvider` | `Provider<bool>` | 可否選檔 |
| `canStartImportProvider` | `Provider<bool>` | 可否開始匯入 |
| `showProgressProvider` | `Provider<bool>` | 是否顯示進度 |
| `showResultProvider` | `Provider<bool>` | 是否顯示結果 |
| `errorTypeProvider` | `Provider<JsonErrorType?>` | 錯誤類型 |

### Core 層

#### FileService

```dart
class FileService {
  Future<FilePickResult?> pickJsonFile();
  Future<bool> fileExists(String path);
  Future<int> getFileSize(String path);
  Future<String> readTextFile(String path);
  Future<void> writeTextFile(String path, String content);
  Future<void> deleteFile(String path);
  String formatFileSize(int bytes);
}

class FilePickResult {
  final String path;
  final String name;
  final int size;
}
```

#### ChromeExtensionValidationService

```dart
class ChromeExtensionValidationService {
  JsonValidationResult validateChromeExtensionFormat(dynamic jsonData);
  JsonValidationResult validateJsonFormat(dynamic jsonData);
}

class JsonValidationResult {
  final bool isValid;
  final String? error;
  final Map<String, dynamic>? metadata; // {totalBooks, validBooks, invalidBooks, errors}
}
```

### Domain 層

#### ChromeExtensionParser

```dart
class ChromeExtensionParser {
  ChromeExtensionParser({required FileValidator fileValidator, required ChromeExtensionMapper mapper});
  Future<ChromeExtensionParseResult> parse({required File file, ParseProgressTracker? progressTracker});
}
```

#### ChromeExtensionMapper

```dart
class ChromeExtensionMapper {
  static Book toDomainEntity(ChromeExtensionBookData dto);
  static List<Book> toDomainEntitiesBatch(List<ChromeExtensionBookData> dtos);
  static ChromeExtensionBookData toDto(Book book);
  static List<ChromeExtensionBookData> toDtoBatch(List<Book> books);
}
```

#### ChromeExtensionImportService

```dart
class ChromeExtensionImportService {
  ChromeExtensionImportService({
    required jsonValidator,
    required dataValidator,
    required bookRepository,
    required enrichmentService,
  });
  Future<...> importFromJson(...);
  Future<...> importFromFile(...);
}
```

#### BookService（相關方法）

```dart
class BookService {
  Future<Book?> getBookByIsbn(String isbn);
  Future<void> addBook(Book book);
  Future<List<Book>> getAllBooks();
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
}
```

#### EnrichmentProgressViewModel

```dart
class EnrichmentProgressViewModel {
  const EnrichmentProgressViewModel({required EnrichmentProgress domainModel});

  // 進度顯示
  String get displayProgress;    // "已處理/總數"
  String get percentageText;     // "XX%"
  double get progressBarValue;   // 0.0-1.0
  int get remainingCount;
  String get remainingText;      // "剩餘 X 本"
  double get percentageComplete; // 0.0-100.0

  // 狀態映射
  String get statusText;         // "準備中" / "補充中" / "已完成"
  IconData get statusIcon;       // hourglass_empty / sync / check_circle
  Color get progressColor;       // < 50% -> negative, >= 50% -> positive

  // 摘要資訊
  String get summaryText;        // "成功 X, 失敗 Y, 跳過 Z"
  String get successRateText;
  String get failureRateText;
  String get skipRateText;

  // 當前書籍
  String get currentBookTitle;
  String get currentBookAuthor;
  bool get hasCurrentBook;

  // 視覺控制
  bool get shouldShowCurrentBook;
  bool get isIdle;
  bool get isInProgress;
}
```

---

## 資料模型

### ChromeExtensionBookData（Value Object / DTO）

```dart
class ChromeExtensionBookData extends Equatable {
  final String id;       // 必填
  final String title;    // 必填
  final String? author;
  final String? publisher;
  final String? cover;   // 支援 'cover' 和 'coverUrl' 兩種 JSON 鍵名

  bool get hasValidId;
  bool get hasValidTitle;
  bool get hasCover;
  bool get isValid;      // hasValidId && hasValidTitle
}
```

### DuplicateBookInfo

```dart
class DuplicateBookInfo extends Equatable {
  final Book existingBook;
  final Book importedBook;
  final bool hasNewerInfo;
}
```

### DuplicateHandlingStrategy

```dart
enum DuplicateHandlingStrategy {
  skip,      // 跳過重複，僅匯入新書
  overwrite, // 覆蓋現有資料
  merge,     // 智慧合併
  cancel,    // 取消匯入
}
```

### JsonErrorType

```dart
enum JsonErrorType {
  syntax,    // JSON 語法錯誤
  structure, // 結構錯誤（缺少必要欄位）
  encoding,  // 檔案編碼錯誤
}
```

### ChromeExtensionImportStatus

```dart
enum ChromeExtensionImportStatus {
  initial,          // 初始狀態
  fileSelected,     // 已選擇檔案
  validating,       // 驗證中
  validationFailed, // 驗證失敗
  importing,        // 匯入中
  completed,        // 匯入完成
  error,            // 系統錯誤
}
```

---

## 需求與實作差距分析

### GAP-1：FR-1 detector 四來源 vs 實作

**spec**：detector 依四種優先序辨識格式。
**實作**（ViewModel `_parseBooks`）：僅區分 `List` / `Map` 含 `books`/`data`/`items`，未實作 `format` 欄位檢查、`metadata.formatVersion` 檢查、`backup_info`/`export_info` wrapper 檢查。
**影響**：canonical v3.x 與 legacy fixed-field 格式未被明確辨識，但不影響基本匯入（仍可解析出書籍陣列）。

### GAP-2：FR-3 pass-through 保留 vs 實作

**spec**：`extensions` 和 `_passthrough` 物件必須原樣保留。
**實作**（`_createBookFromData`）：僅取 `id`/`title`/`author`/`isbn`/`publisher`/`publishDate`/`description`/`coverImageUrl`/`rating`/`tags`/`readingStatus`，未處理 `extensions` 和 `_passthrough`。
**影響**：匯入時未知欄位會被丟棄，違反 canonical C1 無損原則。
**備註**：`Book` entity 已有 `extensions` 和 `passthrough` 欄位，但匯入時未從 JSON 映射。

### GAP-3：FR-5 tagTree 重建 vs 實作

**spec**：匯入資料含 `tagTree` 時重建 tag 樹結構。
**實作**：ViewModel `_createBookFromData` 僅處理 `tags` 陣列（字串列表），未解析 `tagTree` 結構。
**影響**：跨平台匯入時分類結構會遺失。

### GAP-4：FR-4 readingStatus 對照表不完全

**spec**：`unread` → `not_started`（canonical name）。
**實作**（`_chromeLegacyStatusMap`）：`unread` → `notStarted`（Dart enum name，無底線分隔）。此為命名格式差異而非語意差異，`ReadingStatusExtension.fromString` 以 `notstarted` 做 case-insensitive 比對可正確解析。
**影響**：無實際影響，但 spec 與 enum 命名格式不一致，需統一用語。

### GAP-5：ChromeExtensionBookData DTO 欄位不足

**spec FR-2/FR-3/FR-4**：需要 `readingStatus`、`isbn`、`publishDate`、`description`、`rating`、`extensions`、`_passthrough` 等欄位。
**實作**（`ChromeExtensionBookData`）：僅有 `id`/`title`/`author`/`publisher`/`cover` 五個欄位。
**影響**：Domain 層 parser 路徑（`ChromeExtensionParser` → `ChromeExtensionMapper`）無法傳遞完整書籍資訊。ViewModel 路徑（`_createBookFromData`）直接從原始 JSON 建立 `Book`，繞過了 DTO。

### GAP-6：兩條匯入路徑並存

**Presentation 路徑**：ViewModel 直接 `jsonDecode` → `_parseBooks` → `_createBookFromData` → `Book.create()`。
**Domain 路徑**：`ChromeExtensionParser` → `ChromeExtensionBookData.fromJson()` → `ChromeExtensionMapper.toDomainEntity()` → `Book`。
**影響**：兩條路徑的欄位映射邏輯不同步，ViewModel 路徑支援更多欄位但未經 DTO 封裝；Domain 路徑 DTO 欄位不足導致資訊遺失。需統一為單一路徑。

---

## 非功能需求 (NFR)

### NFR-1：向後相容

detector 四來源（FR-1）保證 v0.31.x legacy 與 V1 舊 v2 格式可匯入，不因格式升版而破壞現有用戶的書庫檔案。

### NFR-2：格式錯誤可見性

格式辨識失敗或必填欄位缺失（`title`/`author`）時，回報具體錯誤訊息，不允許靜默吞錯（遵循 quality-baseline.md 規則 4）。

### NFR-3：跨版本相容

匯入 canonical v3.0.0 格式時，`formatVersion` semver 版本協商（major 升版依 detector 優先序 1 內分流）；minor/patch 升版向後相容，不需額外處理。

### NFR-4：UI 非阻塞

- Domain 層 parser 使用 `compute()` 在 Isolate 中解析 JSON，避免阻塞 UI
- ViewModel 匯入迴圈每筆前讓出控制權（`Future.delayed(10ms)`），保持取消視窗可用
- 匯入過程中即時更新進度（`processedBooks` / `currentBookTitle`）

### NFR-5：事務完整性

兩階段匯入（處理 → 提交）確保取消時無殘留資料；系統錯誤時自動回滾已寫入書籍。

---

## 相關規格

- canonical SSOT：`book_overview_v1/docs/spec/book-interchange-v1.md`（格式定義、detector、pass-through）
- PROP-007：`docs/proposals/PROP-007-cross-project-spec-alignment.md`（跨專案對齊提案）
- SPEC-003：`docs/spec/export/library-export.md`（匯出端，與本匯入規格對稱）
- SPEC-008：`docs/spec/synchronization/cross-platform-sync.md`（dedup 機制）

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-01：匯入 Chrome Extension 書庫資料

---

**Last Updated**: 2026-06-20 | **Version**: 2.0 — 充實 spec：新增 FR-6~FR-9（檔案驗證、重複處理、取消回滾、結果統計）、業務規則 BR-1~BR-5、完整介面契約（ViewModel/State/Providers/Services/Parser/Mapper/DTO）、資料模型（6 型別）、需求與實作差距分析 GAP-1~GAP-6、NFR-4/NFR-5（0.35.0-W3-002）
