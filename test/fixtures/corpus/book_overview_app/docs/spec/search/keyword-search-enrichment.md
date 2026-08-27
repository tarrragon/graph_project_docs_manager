---
id: SPEC-005
title: "關鍵字搜尋與資訊補充規格"
status: draft
source_proposal: null
created: "2026-03-30"
updated: "2026-06-20"
version: "3.0"
owner: ""

domain: search
subdomain: null

related_usecases: [UC-04]
related_specs: [SPEC-012]
implements_requirements: []
depends_on_domains: [library, enrichment]
---

# 關鍵字搜尋與資訊補充規格

## 概述

定義關鍵字搜尋書籍資訊與自動補充（enrichment）的查詢策略、資料來源、候選比對與合併規則。系統透過 Google Books API 搜尋外部書目，以相似度演算法比對候選結果，並提供三種資料合併策略讓使用者選擇如何更新既有書籍資訊。

## 功能需求 (FR)

### FR-1: 搜尋 Session 管理

`SearchSession` 管理搜尋生命週期：

| 欄位 | 型別 | 說明 |
|------|------|------|
| sessionId | SearchSessionId | 唯一識別 |
| bookId | BookId | 目標書籍 |
| initialKeyword | String | 初始搜尋關鍵字 |
| modifiedKeyword | String? | 使用者修改後的關鍵字 |
| status | SearchStatus | 狀態機 |
| createdAt / completedAt | DateTime | 時間戳記 |

狀態機：`pending → executing → completed / cancelled`

方法：

| 方法 | 簽章 | 說明 |
|------|------|------|
| getActiveKeyword | `String getActiveKeyword()` | 回傳 modifiedKeyword ?? initialKeyword |
| start | `SearchSession start()` | 切換至 executing 狀態 |
| addCandidates | `SearchSession addCandidates(...)` | 加入候選結果 |
| selectCandidate | `SearchSession selectCandidate(...)` | 使用者選取候選 |
| complete | `SearchSession complete()` | 切換至 completed 狀態 |
| cancel | `SearchSession cancel()` | 切換至 cancelled 狀態 |
| copyWith | `SearchSession copyWith({...})` | 不可變更新 |

#### 入口與會話生命週期

搜尋會話由書籍資訊 bottom sheet 內的「補充書籍資料」文字按鈕觸發（原書卡 IconButton 入口與獨立整頁確認流程 `BookSupplementPage` 已廢棄，見文末「相關規格」標註）。使用者點擊按鈕後，系統以現有書名為 `initialKeyword` 自動呼叫 `start()`，不經使用者關鍵字確認或修改步驟即進入 `executing` 狀態。

查詢完成後依候選數量分流：

| 候選數量 | 行為 |
|---------|------|
| 1 筆 | 系統自動呼叫 `selectCandidate()` 與 `complete()`，無需使用者介入 |
| 2 筆以上 | 開啟 dialog 展示候選清單供使用者選擇；使用者選定後呼叫 `selectCandidate()` 與 `complete()` |

會話狀態綁定觸發載體（bottom sheet 按鈕 -> dialog）的生命週期：dialog 開啟時會話須從乾淨狀態開始；dialog 關閉（含使用者取消、barrier dismiss、系統返回鍵、或錯誤畫面內的取消動作）一律呼叫 `cancel()` 並重置狀態，確保重新開啟不殘留前次錯誤或候選資料。

### FR-2: 搜尋查詢

`IGoogleBooksRepository` 定義搜尋介面：

| 方法 | 簽章 | 說明 |
|------|------|------|
| searchByTitle | `Future<OperationResult<List<ExternalBookInfo>>> searchByTitle(String keyword, {int maxResults = 10})` | 依書名搜尋 |
| searchByAuthor | `Future<OperationResult<List<ExternalBookInfo>>> searchByAuthor(String author, {int maxResults = 10})` | 依作者搜尋 |
| searchByIsbn | `Future<OperationResult<List<ExternalBookInfo>>> searchByIsbn(String isbn)` | 依 ISBN 搜尋 |

約束條件：

| 項目 | 值 |
|------|------|
| 搜尋關鍵字最短長度 | 2 字元（`ValidateSearchCriteriaUseCase.minKeywordLength`） |
| API 速率限制 | 5 req/s |
| 請求逾時 | 10 秒 |
| 預設結果數上限 | 10 筆 |
| maxResults 範圍 | 1-40 |

驗證規則（`GoogleBooksRepositoryFactory`）：
- `isValidSearchKeyword(String)`: 關鍵字至少 2 字元
- `isValidIsbn(String)`: 支援 ISBN-10 / ISBN-13，自動清理連字號和空格

錯誤處理：

| 錯誤情境 | 回傳 |
|---------|------|
| 網路錯誤 | `OperationResult.failure(NetworkException.timeout)` |
| API 錯誤 | `OperationResult.failure(NetworkException.apiError)` |
| 資料解析錯誤 | `OperationResult.failure(ValidationException.invalidData)` |
| 無效 ISBN 格式 | `OperationResult.failure(ValidationException.invalidFormat('isbn'))` |
| 無結果 | `OperationResult.success([])` — 空列表而非 null |

查詢建構由 `GoogleBooksQueryBuilder` 處理：
- `build(...)`: 建構基本查詢（含中文語系處理 `_processLanguageCode`）
- `buildAdvanced(_AdvancedSearchCriteria)`: 建構進階查詢（支援 title/author/isbn/subject 組合）

回應解析由 `GoogleBooksResponseParser` 處理：
- `parse(String)`: 解析 JSON 回應為 `List<GoogleBooksSearchResult>`
- `parseBookDetail(String)`: 解析單筆書籍詳情
- `getTotalItems(String)`: 取得搜尋結果總數
- `isValidResponse(String)`: 驗證回應格式

### FR-3: 搜尋結果

`GoogleBooksSearchResult` 封裝 API 回傳：

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | String | Google Books ID（required） |
| title | String | 書名（required） |
| authors | List\<String\> | 作者群（預設空列表） |
| publisher | String? | 出版社 |
| publishedDate | String? | 出版日期 |
| description | String? | 描述 |
| thumbnailUrl | String? | 封面縮圖 |
| isbn13 | String? | ISBN-13 |
| isbn10 | String? | ISBN-10 |

建構方式：
- `const GoogleBooksSearchResult({required id, required title, ...})`: 直接建構
- `GoogleBooksSearchResult.fromJson(Map<String, dynamic>)`: 從 Google Books API JSON 解析，自動處理 `volumeInfo` 結構、`industryIdentifiers` ISBN 提取、`imageLinks` 封面提取

相等性：以 `id` 為判斷依據。

### FR-4: 候選比對

`SearchCandidate` 代表搜尋候選結果：

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | String | 候選識別碼 |
| sessionId | SearchSessionId | 所屬 Session |
| title | String? | 書名 |
| author | String? | 作者（多位以逗號分隔） |
| publisher | String? | 出版社 |
| isbn | String? | ISBN |
| thumbnailUrl | String? | 封面縮圖 |
| isSelected | bool | 使用者是否選取 |

方法：`create()`、`select()`、`deselect()`、`copyWith()`。

`BookSimilarityCalculator` 計算多維相似度（`SimilarityScore`）：

| 維度 | 欄位 | 說明 |
|------|------|------|
| overall | double | 綜合加權分數 |
| titleSimilarity | double | 書名相似度 |
| authorSimilarity | double | 作者相似度 |
| publisherSimilarity | double | 出版社相似度 |
| isbnSimilarity | double | ISBN 相似度 |

相似度等級（`SimilarityLevel`）：

| 等級 | 條件 | 列舉值 |
|------|------|--------|
| 極高 | >= 0.9 | `excellent` |
| 高 | >= 0.8 | `good` |
| 中 | >= 0.6 | `fair` |
| 低 | >= 0.4 | `low` |
| 極低 | < 0.4 | `veryLow` |

計算特性：
- 書名相似度含包含關係檢測（`_checkTitleContainment`）與詞基相似度（`_calculateWordBasedSimilarity`）
- 作者欄位空值處理：搜尋結果無作者 → `noAuthorSimilarityScore`；臨時作者 → `temporaryAuthorSimilarityScore`
- 書名權重（`titleWeight`）> 作者權重（`authorWeight`），配置由 `_SimilarityConfiguration` 管理

判斷方法：`isHighSimilarity(SimilarityScore)`、`isMediumSimilarity(SimilarityScore)`、`isLowSimilarity(SimilarityScore)`。

比對處理器：

| 元件 | 職責 | 關鍵方法 |
|------|------|---------|
| `AutoMatchProcessor` | 自動比對 | `processMatch()`、`processBatch()`、`getBestMatch()`、`getAutoMatches()` |
| `ManualConfirmationHandler` | 使用者確認 | `createConfirmationRequest()`、`handleConfirmation()`、`requiresManualConfirmation()` |

`AutoMatchResult` 包含：searchResult、similarity（double）、isAutoMatched（bool）、reason（String）。

`ManualConfirmationRequest` 狀態機：`pending → confirmed / rejected / cancelled`（`ConfirmationStatus` 列舉）。

### FR-5: 資料合併策略

`DataMergeStrategy` 定義三種合併策略（抽象類別 + 工廠方法）：

| 策略 | 工廠方法 | 實作類別 | 行為 |
|------|---------|---------|------|
| 只補缺失（預設） | `DataMergeStrategy.fillMissingOnly()` | `FillMissingFieldsStrategy` | 只填入 null/空欄位 |
| 覆寫全部 | `DataMergeStrategy.preferEnriched()` | `OverwriteAllFieldsStrategy` | 覆寫全部欄位（ID、source、addedDate 除外） |
| 選擇性更新 | `DataMergeStrategy.userConfirmed({required Set<String> confirmedFields})` | `SelectiveUpdateStrategy` | 僅更新使用者確認的欄位 |

合併方法簽章：`Book merge(Book existingBook, BookEnrichmentData enrichedData)`

### FR-6: 衝突偵測與解決

#### 衝突偵測

`InformationConflictDetector` 偵測欄位衝突：

| 方法 | 簽章 | 說明 |
|------|------|------|
| detectConflicts | `ConflictDetectionResult detectConflicts(...)` | 偵測所有欄位衝突 |

檢測欄位（`ConflictType` 列舉）：

| 列舉值 | 說明 |
|--------|------|
| `titleMismatch` | 書名不一致 |
| `authorMismatch` | 作者不一致 |
| `publisherMismatch` | 出版社不一致 |
| `publishedDateMismatch` | 出版日期不一致 |
| `descriptionMismatch` | 描述不一致 |
| `genreMismatch` | 分類不一致 |

`InformationConflict` 資料結構：

| 欄位 | 型別 | 說明 |
|------|------|------|
| type | ConflictType | 衝突類型 |
| field | String | 欄位名稱 |
| existingValue | String | 原值 |
| newValue | String | 新值 |
| severity | double | 嚴重程度 |
| description | String | 衝突描述文字 |

`ConflictDetectionResult` 包含：conflicts（List）、hasConflicts（bool）、severityLevel（double）、recommendations（List）。

#### 衝突解決分析

`ConflictResolutionAnalyzer` 分析解決策略：

| 方法 | 簽章 | 說明 |
|------|------|------|
| analyzeStrategies | `ConflictResolutionAnalysis analyzeStrategies(...)` | 分析衝突並推薦策略 |

`ResolutionStrategy` 列舉：`keepExisting`、`useNew`、`merge`、`manualReview`、`sourceRanking`。

`ResolutionRecommendation` 包含：strategy、reason（String，如「標題差異過大，可能是不同書籍」）、confidence（double）、metadata（Map）。

`ConflictResolutionAnalysis` 包含：recommendations（List）、primaryStrategy（ResolutionStrategy）、summary（String）、overallConfidence（double）。

#### 可靠度解決

`ReliabilityBasedResolver` 依來源可靠度排序解決衝突：

| 方法 | 說明 |
|------|------|
| `resolveConflicts(...)` | 以來源可靠度自動解決 |
| `getDataSource(...)` | 取得欄位的資料來源 |
| `evaluateSourceReliability(...)` | 評估來源可靠度 |
| `getSourcePriorityList()` | 取得來源優先級清單 |

`DataSource` 預設工廠：`DataSource.googleBooks()`、`DataSource.userInput()`、`DataSource.manual()`。

`ReliabilityLevel` 列舉：`veryHigh`、`high`、`medium`、`low`、`veryLow`。

#### 改善分析

`InformationImprovementAnalyzer` 分析欄位改善：

| 方法 | 說明 |
|------|------|
| `analyze(...)` | 分析哪些欄位可改善 |
| `calculateCompleteness(...)` | 計算資料完整度 |
| `needsImprovement(...)` | 判斷是否需要補充 |
| `generateImprovementSuggestions(...)` | 產生改善建議 |

`ImprovementResult` 包含：rate（double）、newFieldsCount、improvedFieldsCount、newFields（List）、improvedFields（List）、isSignificantImprovement（bool）。

### FR-7: 搜尋快取

`SearchResultCache` 提供快取機制：

| 項目 | 值 |
|------|------|
| 快取容量上限 | 100 筆（`_maxCacheSize`） |
| 淘汰策略 | LRU（Least Recently Used） |
| TTL | 時間型過期（`_defaultTtl`） |

方法：

| 方法 | 簽章 | 說明 |
|------|------|------|
| store | `void store(String query, List<GoogleBooksSearchResult> results)` | 儲存搜尋結果 |
| get | `List<GoogleBooksSearchResult>? get(String query)` | 取得快取結果 |
| contains | `bool contains(String query)` | 檢查是否有快取 |
| clear | `void clear()` | 清空快取 |
| remove | `void remove(String query)` | 移除特定快取 |
| cleanupExpired | `void cleanupExpired()` | 清理過期項目 |
| getStatistics | `CacheStatistics getStatistics()` | 取得 hit/miss 統計 |

`CacheStatistics` 包含：hitCount、missCount、totalRequests、hitRate（double）。

屬性：`size`（int）、`capacity`（int）、`isFull`（bool）。

內部正規化：`_normalizeQuery(String)` → `_generateCacheKey(String)` 確保同義查詢命中同一快取。

### FR-8: 批次補充

`BatchEnrichmentSession` 管理批次書籍資訊補充：

| 欄位 | 型別 | 說明 |
|------|------|------|
| sessionId | BatchSessionId | 批次識別碼 |
| bookIds | List\<BookId\> | 目標書籍清單（1-20 本） |
| totalCount | int | 總數 |
| processedCount | int | 已處理數 |
| successCount | int | 成功數 |
| failedCount | int | 失敗數 |
| status | BatchStatus | 狀態機 |
| createdAt / completedAt / pausedAt | DateTime | 時間戳記 |

計算屬性：`progress`（double，0.0-1.0）、`successRate`（double）。

狀態機（`BatchStatus` 列舉）：`pending → processing ⇄ paused → completed / cancelled`

方法：`create()`、`start()`、`pause()`、`resume()`、`updateProgress()`、`complete()`、`cancel()`、`copyWith()`。

`BatchEnrichBooksUseCase.execute` 簽章：

```dart
Future<OperationResult<BatchEnrichmentResult>> execute({
  required List<BookId> bookIds,
  required BatchEnrichmentOptions options,
})
```

`BatchEnrichmentOptions` 包含：
- `autoSelectBestMatch`（bool）：是否自動選取最佳匹配
- `mergeStrategy`（DataMergeStrategy）：合併策略
- `similarityThreshold`（double）：自動選取閾值

`BatchEnrichmentResult` 包含：totalCount、successCount、failedCount、processedCount、results（Map\<String, dynamic\>）。

批次約束：
- `maxBatchSize = 20`（`BatchEnrichBooksUseCase` 硬限制）
- 空列表或超出上限 → `ValidationException(invalidInput)`
- UC-04 use case 另提及最多 50 本（app-requirements-spec.md），但 Domain 層實作以 20 為硬上限

### FR-9: 搜尋條件

`SearchCriteria` Value Object 定義搜尋條件：

| 欄位 | 型別 | 說明 |
|------|------|------|
| query | String | 搜尋字串 |
| fields | List\<SearchField\> | 搜尋欄位 |
| caseSensitive | bool | 是否區分大小寫 |
| exactMatch | bool | 是否精確比對 |

`SearchField` 列舉：`title`、`author`、`isbn`、`description`、`tags`、`source`。

工廠方法：
- `SearchCriteria.simple(String query)`: 簡單搜尋（預設搜尋 title）
- `SearchCriteria.advanced({required String query, required List<SearchField> fields, ...})`: 進階搜尋

計算屬性：`displayQuery`、`isAdvanced`、`searchesTitle`、`searchesAuthor`、`searchesISBN`。

驗證：`_validate()` 確保 query 不為空且 fields 不為空。

`ValidateSearchCriteriaUseCase.execute` 簽章：

```dart
Future<OperationResult<String>> execute({required String keyword})
```

驗證規則：空值 → `ValidationException.required`；僅空白 → `ValidationException.general`；長度不足 → 中英文混合計算（`_calculateKeywordLength`），低於 `minKeywordLength` 則拒絕；通過 → 回傳正規化字串（trim + 合併連續空白）。

### FR-10: Use Case 層

| Use Case | 類別 | execute 簽章 | 回傳型別 |
|----------|------|-------------|---------|
| 啟動搜尋 session | `InitiateBookSearchUseCase` | `execute({required BookId bookId})` | `OperationResult<SearchSession>` |
| 執行 Google Books 搜尋 | `SearchGoogleBooksUseCase` | `execute({required SearchSessionId sessionId, required String keyword, int maxResults = 10})` | `OperationResult<List<SearchCandidate>>` |
| 計算候選相似度 | `CalculateBookSimilarityUseCase` | `execute({required SearchSessionId sessionId, required Book originalBook, required List<SearchCandidate> candidates})` | `OperationResult<List<ScoredCandidate>>` |
| 單本資訊補充 | `EnrichBookInfoUseCase` | `execute({required BookId bookId, required BookEnrichmentData enrichmentData, required DataMergeStrategy mergeStrategy})` | `OperationResult<Book>` |
| 批次資訊補充 | `BatchEnrichBooksUseCase` | `execute({required List<BookId> bookIds, required BatchEnrichmentOptions options})` | `OperationResult<BatchEnrichmentResult>` |
| 驗證搜尋條件 | `ValidateSearchCriteriaUseCase` | `execute({required String keyword})` | `OperationResult<String>` |

`ScoredCandidate` 包含：candidate（SearchCandidate）、similarityScore（SimilarityScore）。

Use Case 依賴：

| Use Case | 依賴 |
|----------|------|
| InitiateBookSearchUseCase | `_repository`（BookRepository）、`_eventBus` |
| SearchGoogleBooksUseCase | `_repository`（IGoogleBooksRepository）、`_eventBus` |
| CalculateBookSimilarityUseCase | `_similarityCalculator`（BookSimilarityCalculator） |
| EnrichBookInfoUseCase | `_repository`（BookRepository）、`_eventBus` |
| BatchEnrichBooksUseCase | `_eventBus` |
| ValidateSearchCriteriaUseCase | 無外部依賴（`minKeywordLength` 為內部常數） |

### FR-11: 分析與追蹤

| 元件 | 關鍵方法 | 說明 |
|------|---------|------|
| `SearchAnalytics` | `recordSearchTime()`、`recordMatchAccuracy()`、`recordUserSatisfaction()`、`getMetrics()`、`generateReport()` | 搜尋行為分析（`SearchMetrics`：averageSearchTime、matchAccuracy、userSatisfaction、successRate） |
| `SearchPatternTracker` | `recordSuccessfulSearch()`、`recordFailedSearch()`、`getRecommendedPatterns()`、`analyzeSearchTrends()` | 搜尋模式追蹤（`SearchPattern`：pattern、category、frequency、successRate、lastUsed） |
| `SearchPerformanceAnalyzer` | `analyzeTimeComplexity()`、`runBatchPerformanceTest()`、`detectBottlenecks()`、`calculateStatistics()` | 效能分析（`PerformanceTestResult`、`ComplexityAnalysis`） |

`SearchResultType` 列舉：`highSimilarity`、`mediumSimilarity`、`lowSimilarity`、`noResults`。

## 業務規則 (BR)

### BR-1: 搜尋流程規則

| 規則 | 說明 | 來源 |
|------|------|------|
| BR-1.1 | 搜尋關鍵字至少 2 字元（中英文混合計算） | UC-04 步驟 2、ValidateSearchCriteriaUseCase |
| BR-1.2 | 搜尋以現有書名作為關鍵字，系統自動觸發查詢，不提供使用者手動修改關鍵字步驟（原整頁確認流程已廢棄） | UC-04 步驟 1-2 |
| BR-1.3 | 搜尋結果上限 10 筆，按相似度降序排列 | FR-2 maxResults、CalculateBookSimilarityUseCase |
| BR-1.4 | 短書名（< 2 字元）觸發警告並建議加入作者 | UC-04 替代流程 2a |
| BR-1.5 | 無結果時自動嘗試移除特殊字符重新搜尋 | UC-04 替代流程 4a |
| BR-1.6 | 查詢會話狀態綁定觸發載體（bottom sheet 按鈕 -> dialog）生命週期；dialog 關閉（含取消、barrier dismiss、系統返回鍵）即重置，避免下次開啟殘留前次錯誤或候選資料 | UC-04 步驟 4、FR-1 入口與會話生命週期 |

### BR-2: 候選比對規則

| 規則 | 說明 | 來源 |
|------|------|------|
| BR-2.1 | 相似度 >= 0.8 時自動標記為推薦匹配 | AutoMatchProcessor、BatchEnrichmentOptions.similarityThreshold |
| BR-2.2 | 相似度 < 0.3 時標記為低相關性警告 | UC-04 替代流程 4b（前 3 個 < 30%） |
| BR-2.3 | 書名權重 > 作者權重（配置於 _SimilarityConfiguration） | BookSimilarityCalculator |
| BR-2.4 | ISBN 精確匹配視為最高優先 | CalculateBookSimilarityUseCase._calculateIsbnSimilarity |
| BR-2.5 | 需要人工確認的候選由 ManualConfirmationHandler 管理 | FR-4 |

### BR-3: 資料合併規則

| 規則 | 說明 | 來源 |
|------|------|------|
| BR-3.1 | 預設策略為 fillMissingOnly（最保守） | FR-5、DataMergeStrategy.fillMissingOnly() |
| BR-3.2 | 覆寫策略不覆寫 ID、source、addedDate | OverwriteAllFieldsStrategy |
| BR-3.3 | 原始 source 標記更新後保持不變 | UC-04 步驟 5 |
| BR-3.4 | 更新時自動更新 updated_at 時間戳 | UC-04 步驟 5 |
| BR-3.5 | 衝突欄位允許使用者逐欄位選擇（field-level resolution） | UC-04 替代流程 5b |

### BR-4: 批次處理規則

| 規則 | 說明 | 來源 |
|------|------|------|
| BR-4.1 | 批次上限 20 本（Domain 層硬限制） | BatchEnrichBooksUseCase.maxBatchSize |
| BR-4.2 | 批次可暫停/恢復/取消 | BatchEnrichmentSession 狀態機 |
| BR-4.3 | 逐本處理並發送進度事件 | SEARCH_BATCH_PROGRESS_UPDATED |
| BR-4.4 | 單本失敗不影響整批次繼續 | BatchEnrichBooksUseCase.execute try-catch |
| BR-4.5 | 批次完成後提供成功/失敗統計 | BatchEnrichmentResult |

### BR-5: 快取規則

| 規則 | 說明 | 來源 |
|------|------|------|
| BR-5.1 | 快取容量 100 筆，超過以 LRU 淘汰 | SearchResultCache._maxCacheSize |
| BR-5.2 | 快取有 TTL 過期機制 | CacheEntry.isExpired |
| BR-5.3 | 查詢正規化後作為快取 key | SearchResultCache._normalizeQuery |

## 事件系統

搜尋 Domain 定義以下事件常量（`lib/domains/search/events/search_events.dart`）：

### 搜尋流程事件

| 事件 | 常量名 | 觸發時機 |
|------|--------|---------|
| 搜尋啟動 | `SEARCH_QUERY_INITIATED` | InitiateBookSearchUseCase.execute 成功 |
| 搜尋執行 | `SEARCH_EXECUTED` | SearchGoogleBooksUseCase.execute 開始 |
| 結果接收 | `SEARCH_RESULTS_RECEIVED` | API 回傳結果已轉換為 SearchCandidate |
| 搜尋完成 | `SEARCH_COMPLETED` | 搜尋流程結束 |
| 搜尋失敗 | `SEARCH_FAILED` | API 錯誤或未預期異常 |

### 補充流程事件

| 事件 | 常量名 | 觸發時機 |
|------|--------|---------|
| 預覽展示 | `SEARCH_PREVIEW_SHOWN` | 使用者查看更新預覽 |
| 更新確認 | `SEARCH_UPDATE_CONFIRMED` | 使用者確認更新 |
| 補充啟動 | `SEARCH_ENRICHMENT_STARTED` | EnrichBookInfoUseCase.execute 開始 |
| 補充完成 | `SEARCH_ENRICHMENT_COMPLETED` | 書籍更新成功儲存 |
| 補充失敗 | `SEARCH_ENRICHMENT_FAILED` | 書籍不存在或儲存錯誤 |

### 批次處理事件

| 事件 | 常量名 | 觸發時機 |
|------|--------|---------|
| 批次啟動 | `SEARCH_BATCH_INITIATED` | BatchEnrichBooksUseCase.execute 開始 |
| 書籍處理中 | `SEARCH_BATCH_BOOK_PROCESSING` | 單本開始處理 |
| 書籍處理完成 | `SEARCH_BATCH_BOOK_COMPLETED` | 單本處理結束 |
| 進度更新 | `SEARCH_BATCH_PROGRESS_UPDATED` | 每本完成後（含 processed/total/success/failed） |
| 批次完成 | `SEARCH_BATCH_COMPLETED` | 全部處理結束 |
| 批次暫停 | `SEARCH_BATCH_PAUSED` | 使用者暫停 |
| 批次恢復 | `SEARCH_BATCH_RESUMED` | 使用者恢復 |
| 批次取消 | `SEARCH_BATCH_CANCELLED` | 使用者取消 |

向後相容別名：`SEARCH_INITIATED = SEARCH_QUERY_INITIATED`。

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 | 來源 |
|------|------|------|
| API 搜尋逾時 | 5 秒（SearchBookInfoService） | UC-04 效能考量 |
| 請求逾時 | 10 秒（Repository 層） | FR-2 約束 |
| API 速率限制 | 5 req/s | FR-2 約束、ApiRequestQueue |
| 快取容量 | 100 筆，LRU 淘汰 | FR-7 |
| 批次處理速度 | ~20 本/分鐘 | UC-04 效能考量 |

### NFR-2: 離線行為

離線時 API 搜尋不可用，但本地搜尋（BookSearchEngine）和快取結果仍可使用。批次補充中斷離時暫停（paused），恢復連線後可 resume。

### NFR-3: 錯誤處理

| 例外類別 | 情境 | 來源 |
|---------|------|------|
| `ApiTimeoutException` | API 請求逾時 | IGoogleBooksRepository |
| `NetworkConnectivityException` | 無網路連線 | IGoogleBooksRepository |
| `NoSearchResultsException` | 搜尋無結果 | SearchGoogleBooksUseCase |
| `ApiRateLimitException` | 超過速率限制（含 retryAfter） | ApiRequestQueue |
| `InvalidSearchCriteriaException` | 搜尋條件無效 | ValidateSearchCriteriaUseCase |
| `BusinessException.notFound` | 書籍不存在 | InitiateBookSearchUseCase / EnrichBookInfoUseCase |
| `StorageException` | 儲存失敗 | EnrichBookInfoUseCase |
| `ValidationException` | 無效輸入（批次大小、ISBN 格式等） | 多處 |

## 需求與實作差距

| 需求 | 實作狀態 | 差距 |
|------|---------|------|
| 關鍵字搜尋書籍 | 已實作（Google Books API 整合） | 無 |
| 搜尋結果比對 | 已實作（多維相似度計算） | 無 |
| 自動資訊補充 | 已實作（三種合併策略） | 無 |
| 衝突偵測與解決 | 已實作（四個分析元件） | 無 |
| 搜尋快取 | 已實作（LRU + TTL） | 無 |
| 批次補充 | 已實作（含暫停/恢復） | [GAP-1] BatchEnrichBooksUseCase.execute 內部為模擬操作（註解「模擬補充操作」），未實際呼叫 EnrichBookInfoUseCase |
| 搜尋分析 | 已實作（三個分析元件） | 無 |
| 批次上限不一致 | UC-04 批次場景最多 50 本；app-requirements-spec.md 也提 50 本 | [GAP-2] BatchEnrichBooksUseCase.maxBatchSize = 20，與需求規格 50 本不一致 |
| 搜尋關鍵字驗證串接 | ValidateSearchCriteriaUseCase 已實作 | [GAP-3] ValidateSearchCriteriaUseCase 未在 SearchGoogleBooksUseCase 中被呼叫，驗證未串接至搜尋流程 |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-04: 關鍵字搜尋補充書籍資訊

## 相關規格

- SPEC-012: BatchSupplementPage 介面規格（批次補充頁面）
- `docs/spec/search/book-supplement-page.md`: BookSupplementPage 介面規格（單書補充頁面，**已廢棄**——整頁確認/候選清單流程改為書籍資訊 bottom sheet 文字按鈕 + dialog 消歧義，見 FR-1「入口與會話生命週期」）
- `docs/spec/search/conflict-resolution-widget.md`: ConflictResolutionWidget 介面規格
