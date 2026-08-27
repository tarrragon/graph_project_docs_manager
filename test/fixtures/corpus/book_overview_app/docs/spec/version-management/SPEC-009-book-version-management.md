---
id: SPEC-009
title: "書籍版本管理規格"
status: draft
source_proposal: null
created: "2026-03-30"
updated: "2026-07-26"
version: "3.1"
owner: ""

domain: version-management
subdomain: null

related_usecases: [UC-08]
related_specs: [SPEC-006]
implements_requirements: [FR-VM-01, FR-VM-02, FR-VM-03, FR-VM-04, FR-VM-05]
depends_on_domains: [library]
---

# 書籍版本管理規格

## 概述

定義同一本書不同版本（翻譯版、修訂版、不同出版社版本）的自動識別、關聯管理與合併/分離功能。系統以 `MasterBook` 統一管理多個 `BookEdition`，透過相似度計算自動建議版本關聯，使用者可手動調整。

## 功能需求 (FR)

### FR-1: MasterBook 實體（主書籍）

**位置**：`lib/domains/version_management/entities/master_book.dart`

代表一本書的概念，包含多個版本。繼承 `Equatable`（基於所有欄位比較相等性）。

#### 資料欄位

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| masterBookId | String | 是 | 唯一識別（前綴 `mb_`，格式 `mb_{timestamp}_{random}`） |
| originalTitle | String | 是 | 原文書名（上限 500 字元） |
| originalIsbn | String? | 否 | 原文 ISBN（ISBN-10 或 ISBN-13） |
| originalAuthors | List\<String\> | 是 | 原文作者群（至少 1 人，每人上限 200 字元） |
| originalLanguage | String? | 否 | 原文語言（ISO 639-1 或 BCP 47） |
| firstPublishedDate | DateTime? | 否 | 首次出版日期（不可為未來日期） |
| editions | List\<BookEdition\> | 否 | 版本清單（預設空列表） |
| primaryEditionId | String | 是 | 主要顯示版本 ID |
| createdAt | DateTime | 是 | 建立時間 |
| updatedAt | DateTime | 是 | 更新時間 |

#### 建構函式與工廠方法

| 方法 | 簽名 | 說明 |
|------|------|------|
| 建構函式 | `MasterBook({required masterBookId, required originalTitle, required originalAuthors, required primaryEditionId, originalIsbn, originalLanguage, firstPublishedDate, editions, required createdAt, required updatedAt})` | 所有欄位直接賦值 |
| create | `factory MasterBook.create({required String masterBookId, required String originalTitle, required List<String> originalAuthors, required String primaryEditionId, String? originalIsbn, String? originalLanguage, DateTime? firstPublishedDate, List<BookEdition>? editions, DateTime? createdAt, DateTime? updatedAt})` | 建立實體，createdAt/updatedAt 預設 `DateTime.now()` |
| fromEdition | `factory MasterBook.fromEdition({required String masterBookId, required BookEdition edition})` | 從單一版本建立，自動推導 originalTitle/originalAuthors/originalIsbn/originalLanguage/firstPublishedDate |

#### 查詢方法

| 方法 | 簽名 | 回傳 | 說明 |
|------|------|------|------|
| primaryEdition | `BookEdition? get primaryEdition` | BookEdition? | 依 primaryEditionId 從 editions 查找；找不到時 fallback 為第一個 edition；editions 為空回傳 null |
| translationEditions | `List<BookEdition> get translationEditions` | List\<BookEdition\> | 篩選 `isTranslation == true` 的版本 |
| originalEditions | `List<BookEdition> get originalEditions` | List\<BookEdition\> | 篩選 `isTranslation == false` 的版本 |
| getEditionsByLanguage | `List<BookEdition> getEditionsByLanguage(String language)` | List\<BookEdition\> | 依語言篩選（大小寫不敏感） |
| hasMultipleEditions | `bool get hasMultipleEditions` | bool | `editions.length > 1` |
| hasTranslations | `bool get hasTranslations` | bool | `translationEditions.isNotEmpty` |
| displayAuthors | `String get displayAuthors` | String | `originalAuthors.join(', ')` |
| editionCount | `int get editionCount` | int | `editions.length` |

#### 變更方法（回傳新實例，不可變）

| 方法 | 簽名 | 說明 |
|------|------|------|
| addEdition | `MasterBook addEdition(BookEdition edition)` | 新增版本（已存在同 editionId 則跳過），自動更新 updatedAt |
| removeEdition | `MasterBook removeEdition(String editionId)` | 移除版本；若移除的是 primaryEditionId，自動改為剩餘第一個 |
| setPrimaryEdition | `MasterBook setPrimaryEdition(String editionId)` | 設定主要顯示版本，自動更新 updatedAt |
| copyWith | `MasterBook copyWith({...all fields except createdAt...})` | 複製並修改指定欄位（createdAt 不可變） |

### FR-2: BookEdition 實體（書籍版本）

**位置**：`lib/domains/version_management/entities/book_edition.dart`

代表一本書的具體版本。繼承 `Equatable`。不可變（immutable），無變更方法。

#### 資料欄位

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| editionId | String | 是 | — | 版本唯一識別（通常與 Book.id 相同） |
| masterBookId | String? | 否 | null | 所屬 MasterBook ID |
| title | String | 是 | — | 版本書名 |
| originalTitle | String? | 否 | null | 原文書名（翻譯版用） |
| originalIsbn | String? | 否 | null | 原文 ISBN |
| originalLanguage | String? | 否 | null | 原文語言 |
| isTranslation | bool | 否 | false | 是否為翻譯版 |
| relationshipType | VersionRelationshipType | 否 | originalWork | 關係類型 |
| translationMetadata | TranslationMetadata? | 否 | null | 翻譯元資料 |
| metadata | BookEditionMetadata | 是 | — | 版本中繼資料 |
| linkedAt | DateTime? | 否 | null | 關聯建立時間 |

#### BookEditionMetadata 值物件

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| authors | List\<String\> | 是 | 作者列表 |
| primaryISBN | String? | 否 | 主要 ISBN |
| language | String? | 否 | 語言代碼 |
| publishedDate | DateTime? | 否 | 出版日期 |

### FR-3: 版本關係類型

**位置**：`lib/domains/version_management/value_objects/version_relationship_type.dart`

`VersionRelationshipType` 列舉，每個值包含 `code`（資料庫儲存用）和 `displayName`（UI 呈現用）：

| 值 | code | displayName | 說明 |
|------|------|------|------|
| originalWork | ORIGINAL_WORK | 原著 | 最初的原文版本 |
| translationVariant | TRANSLATION_VARIANT | 翻譯版 | 不同語言的翻譯 |
| revisedEdition | REVISED_EDITION | 修訂版 | 同語言的修訂版 |
| adaptation | ADAPTATION | 改編版 | 基於原著的改編 |
| formatVariant | FORMAT_VARIANT | 格式變體 | 精裝/平裝/電子書 |

序列化方法：

| 方法 | 簽名 | 說明 |
|------|------|------|
| fromCode | `static VersionRelationshipType fromCode(String code)` | 從代碼查找，找不到預設 originalWork |
| toJson | `String toJson()` | 回傳 code 字串 |
| fromJson | `static VersionRelationshipType fromJson(String? value)` | 從 JSON 字串建立，null 預設 originalWork |

**向後相容**：`VersionRelationship`（`value_objects/version_relationship.dart`）為 `VersionRelationshipType` 的 typedef 別名，新程式碼應直接使用 `VersionRelationshipType`。

### FR-4: 版本偵測與相似度計算

#### VersionDetector 介面

**位置**：`lib/domains/version_management/services/version_detector.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| analyzeNewBook | `Future<VersionAnalysisResult> analyzeNewBook(Book book, List<Book> existingBooks)` | 分析新書與既有書籍的版本關係，回傳分析結果含候選清單 |
| findSimilarBooks | `Future<List<ScoredCandidate>> findSimilarBooks(Book targetBook, List<Book> candidates, {double minimumSimilarity = 0.60, int limit = 10})` | 尋找相似書籍，按相似度降序排列 |
| detectRelationship | `VersionRelationshipType? detectRelationship(Book book1, Book book2, SimilarityScores scores)` | 判斷關係類型，非同一本書回傳 null |

**實作**：`DefaultVersionDetector`（`services/default_version_detector.dart`）

#### SimilarityCalculator 介面

**位置**：`lib/domains/version_management/services/similarity_calculator.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| calculateScores | `SimilarityScores calculateScores(Book book1, Book book2)` | 計算四維加權綜合相似度 |
| calculateIsbnSimilarity | `double calculateIsbnSimilarity(String? isbn1, String? isbn2)` | ISBN 相似度（0.0-1.0） |
| calculateTitleSimilarity | `double calculateTitleSimilarity(String title1, String title2)` | 標題相似度（0.0-1.0） |
| calculateAuthorSimilarity | `double calculateAuthorSimilarity(String author1, String author2)` | 作者相似度（0.0-1.0） |
| calculateYearSimilarity | `double calculateYearSimilarity(DateTime? date1, DateTime? date2)` | 出版年份相似度（0.0-1.0） |

**實作**：`DefaultSimilarityCalculator`（`services/default_similarity_calculator.dart`）

#### 相似度計算規則（業務規則）

**權重**：ISBN 40% + 標題 30% + 作者 20% + 年份 10%

**ISBN 相似度規則**：

| 分數 | 條件 |
|------|------|
| 1.0 | ISBN-13 完全匹配 |
| 0.95 | ISBN-10 轉 ISBN-13 後匹配 |
| 0.70 | 出版社代碼相同（ISBN-13 前 7 位） |
| 0.60 | 同系列 ISBN（ISBN-13 前 10 位相同） |
| 0.0 | 無相關性或 null |

**標題相似度計算步驟**：
1. 移除可忽略後綴（新版、修訂版、Revised Edition 等，共 30+ 個中英文詞彙）
2. 正規化：轉小寫、移除標點符號（保留漢字/字母/數字/空格）、移除多餘空格
3. 計算 Levenshtein 距離
4. 分數 = 1 - (距離 / max(len1, len2))

**作者相似度規則**：
- 1.0：正規化後完全匹配
- 0.70+：Levenshtein 相似度 > 0.8（考慮譯名差異）
- 0.0：完全不同

**出版年份相似度**：`max(0, 1.0 - (yearDiff * 0.1))`，差 10 年以上分數為 0

#### SimilarityScores 值物件

**位置**：`lib/domains/version_management/value_objects/similarity_scores.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| overall | double | 綜合相似度（0.0-1.0），加權計算並 clamp |
| isbn | double | ISBN 相似度（0.0-1.0） |
| title | double | 標題相似度（0.0-1.0） |
| author | double | 作者相似度（0.0-1.0） |
| publishYear | double | 出版年份相似度（0.0-1.0） |

| 方法 | 簽名 | 說明 |
|------|------|------|
| calculate | `factory SimilarityScores.calculate({required double isbn, title, author, publishYear})` | 計算加權 overall 並 clamp 各欄位至 0.0-1.0 |
| confidenceLevel | `ConfidenceLevel get confidenceLevel` | 依 overall 判斷信心等級 |
| shouldSuggestMerge | `bool get shouldSuggestMerge` | 高信心時建議合併 |
| needsUserConfirmation | `bool get needsUserConfirmation` | 中信心時需確認 |
| toJson / fromJson | — | JSON 序列化/反序列化 |

#### ConfidenceLevel 列舉

**位置**：`lib/domains/version_management/value_objects/confidence_level.dart`

| 值 | code | displayName | 閾值 | 行為 |
|------|------|------|------|------|
| high | HIGH | 高 | overall >= 0.80 | `shouldSuggestMerge = true` |
| medium | MEDIUM | 中 | 0.60 <= overall < 0.80 | `needsUserConfirmation = true` |
| low | LOW | 低 | overall < 0.60 | 不建議合併 |

| 方法 | 簽名 | 說明 |
|------|------|------|
| fromScore | `static ConfidenceLevel fromScore(double score)` | 依分數回傳等級 |
| toJson / fromJson | — | 序列化（以 code 字串） |

#### ScoredCandidate 值物件

**位置**：`lib/domains/version_management/value_objects/scored_candidate.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| bookId | String | 候選書籍 ID |
| scores | SimilarityScores | 相似度評分 |
| matchReasons | List\<String\> | 匹配原因說明（預設空列表） |

| 方法 | 說明 |
|------|------|
| isHighConfidence | 依 scores.confidenceLevel 判斷 |
| isMediumConfidence | 依 scores.confidenceLevel 判斷 |
| toJson / fromJson | JSON 序列化/反序列化 |

#### VersionAnalysisResult 值物件

**位置**：`lib/domains/version_management/value_objects/version_analysis_result.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| analyzedBookId | String | 被分析的書籍 ID |
| candidatesFound | List\<ScoredCandidate\> | 候選版本清單 |
| analyzedAt | DateTime | 分析時間 |
| errorOccurred | bool | 是否發生錯誤（預設 false） |
| errorMessage | String? | 錯誤訊息 |

| 方法 | 簽名 | 說明 |
|------|------|------|
| hasCandidates | `bool get hasCandidates` | 是否有候選 |
| highConfidenceCandidates | `List<ScoredCandidate> get` | 高信心候選清單 |
| mediumConfidenceCandidates | `List<ScoredCandidate> get` | 中信心候選清單 |
| bestCandidate | `ScoredCandidate? get` | overall 最高的候選 |
| candidateCount | `int get` | 候選總數 |
| toJson / fromJson | — | JSON 序列化/反序列化 |

### FR-5: 翻譯偵測

#### TranslationDetector 介面

**位置**：`lib/domains/version_management/services/translation_detector.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| analyzeBook | `TranslationAnalysisResult analyzeBook(Book book)` | 完整翻譯分析（含信心度和元資料） |
| detectTranslationIndicators | `List<TranslationIndicator> detectTranslationIndicators(Book book)` | 偵測翻譯跡象列表 |
| calculateTranslationConfidence | `double calculateTranslationConfidence(List<TranslationIndicator> indicators)` | 計算翻譯信心度（各指標權重加總，clamp 至 0.0-1.0） |
| extractTranslationMetadata | `TranslationMetadata? extractTranslationMetadata(Book book)` | 提取翻譯元資料（資訊不足回傳 null） |

**實作**：`DefaultTranslationDetector`（`services/default_translation_detector.dart`）

#### TranslationIndicator 列舉

**位置**：`lib/domains/version_management/value_objects/translation_indicator.dart`

每個值包含 `code`、`description`、`weight`：

| 值 | code | 權重 | 說明 |
|------|------|------|------|
| titleContainsTranslationMark | TITLE_TRANSLATION_MARK | 0.3 | 標題含「譯」「翻譯」「中文版」等標記 |
| authorForeignFormat | AUTHOR_FOREIGN_FORMAT | 0.2 | 作者名含點號/連字號/空格（外文格式） |
| hasTranslator | HAS_TRANSLATOR | 0.5 | 從描述或欄位提取到譯者資訊 |
| translationPublisher | TRANSLATION_PUBLISHER | 0.2 | 出版社為翻譯書專業出版社 |
| translationIsbnRange | TRANSLATION_ISBN_RANGE | 0.1 | ISBN 在台灣譯書特定區段 |
| hasOriginalTitle | HAS_ORIGINAL_TITLE | 0.4 | 書名含括號中的原文標題 |

#### TranslationAnalysisResult 值物件

**位置**：`lib/domains/version_management/value_objects/translation_analysis_result.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| isTranslation | bool | 判定為翻譯版（confidence >= 0.5） |
| confidence | double | 翻譯信心度（0.0-1.0） |
| indicators | List\<TranslationIndicator\> | 偵測到的翻譯跡象 |
| metadata | TranslationMetadata? | 提取的翻譯元資料 |
| analyzedAt | DateTime | 分析時間 |

| 方法 | 說明 |
|------|------|
| indicatorDescriptions | 各指標 description 清單 |
| confidencePercentage | 信心度百分比（0-100 整數） |
| toJson / fromJson | JSON 序列化/反序列化 |

**翻譯判定閾值**：confidence >= 0.5 即判定為翻譯版。

#### TranslationMetadata 值物件

**位置**：`lib/domains/version_management/value_objects/translation_metadata.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| translators | List\<String\> | 是 | 譯者清單 |
| targetLanguage | String | 是 | 目標語言（如 'zh-TW'） |
| sourceLanguage | String | 是 | 來源語言（如 'en'） |
| translationVersion | String? | 否 | 翻譯版本號 |
| translationPublishedDate | DateTime? | 否 | 翻譯出版日期 |

| 方法 | 簽名 | 說明 |
|------|------|------|
| isValid | `bool get isValid` | translators 非空 AND targetLanguage 非空 AND sourceLanguage 非空 AND target != source |
| translatorNames | `String get translatorNames` | 以逗號分隔的譯者名單 |
| toJson / fromJson | — | JSON 序列化/反序列化 |

### FR-6: 版本合併與分離

#### VersionManager 介面

**位置**：`lib/domains/version_management/services/version_manager.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| mergeBooks | `Future<OperationResult<VersionMergeResult>> mergeBooks(String book1Id, String book2Id, VersionRelationshipType relationshipType)` | 合併兩本書為同一 MasterBook |
| separateEdition | `Future<OperationResult<String>> separateEdition(String editionId)` | 從 MasterBook 分離版本，回傳新 MasterBook ID |
| setPrimaryEdition | `Future<OperationResult<void>> setPrimaryEdition(String masterBookId, String newPrimaryEditionId)` | 設定主要顯示版本 |
| getVersionInfo | `Future<OperationResult<MasterBook?>> getVersionInfo(String bookId)` | 取得版本資訊，null 表示無關聯 |
| getEditions | `Future<OperationResult<List<BookEdition>>> getEditions(String masterBookId)` | 取得主書籍所有版本 |

**實作**：`DefaultVersionManager`（`services/default_version_manager.dart`），注入依賴：`MasterBookRepository`、`BookEditionRepository`、`IEventBus`

#### 合併業務規則

1. 兩本書 ID 必須不同（相同回傳 BusinessException）
2. 檢查兩本書是否已有版本記錄（BookEditionRepository.findByBookId）
3. 決定主書籍：優先使用已有 MasterBook，否則新建立
4. 關聯兩本書到主書籍
5. 發佈 `VersionMergeCompletedEvent`

#### 分離業務規則

1. 驗證版本存在且有 MasterBook 關聯
2. 解除與原 MasterBook 的關聯
3. 為分離版本建立新的獨立 MasterBook
4. 發佈 `VersionSeparationCompletedEvent`

#### VersionMergeResult 值物件

**位置**：`lib/domains/version_management/value_objects/version_merge_result.dart`

| 欄位 | 型別 | 說明 |
|------|------|------|
| masterBookId | String | 主書籍 ID |
| primaryEditionId | String | 主要版本 ID |
| mergedEditionIds | List\<String\> | 已合併的版本 ID 清單 |
| masterBookCreated | bool | 是否新建 MasterBook |
| relationshipEstablished | VersionRelationshipType | 建立的關係類型 |
| mergedAt | DateTime | 合併時間 |

| 方法 | 說明 |
|------|------|
| mergeCount | 合併版本數量 |
| isMultipleMerge | 是否合併多個版本 |
| toJson / fromJson | JSON 序列化/反序列化 |

### FR-7: Repository 介面

#### MasterBookRepository

**位置**：`lib/domains/version_management/repositories/master_book_repository.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| findById | `Future<MasterBook?> findById(String id)` | 依 ID 查找，不存在回傳 null |
| findByOriginalIsbn | `Future<MasterBook?> findByOriginalIsbn(String isbn)` | 依原文 ISBN 查找 |
| searchByOriginalTitle | `Future<List<MasterBook>> searchByOriginalTitle(String title)` | 模糊搜尋 |
| findAll | `Future<List<MasterBook>> findAll({int? limit, int? offset})` | 分頁查詢 |
| save | `Future<void> save(MasterBook masterBook)` | 儲存（StorageException） |
| update | `Future<void> update(MasterBook masterBook)` | 更新（StorageException） |
| delete | `Future<void> delete(String id)` | 刪除（StorageException） |
| getEditions | `Future<List<BookEdition>> getEditions(String masterBookId)` | 取得關聯版本 |
| setPrimaryEdition | `Future<void> setPrimaryEdition(String masterBookId, String editionId)` | 設定主要版本 |
| count | `Future<int> count()` | 統計總數 |

**SQLite 實作**：`SqliteMasterBookRepository`

#### BookEditionRepository

**位置**：`lib/domains/version_management/repositories/book_edition_repository.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| findById | `Future<BookEdition?> findById(String id)` | 依版本 ID 查找 |
| findByBookId | `Future<BookEdition?> findByBookId(String bookId)` | 依書籍 ID 查找 |
| findTranslations | `Future<List<BookEdition>> findTranslations({String? masterBookId})` | 查詢翻譯版本（可限定 MasterBook） |
| findByRelationshipType | `Future<List<BookEdition>> findByRelationshipType(VersionRelationshipType type)` | 依關係類型查詢 |
| save | `Future<void> save(BookEdition edition)` | 儲存 |
| update | `Future<void> update(BookEdition edition)` | 更新 |
| delete | `Future<void> delete(String id)` | 刪除 |
| linkToMasterBook | `Future<void> linkToMasterBook(String editionId, String masterBookId)` | 建立關聯 |
| unlinkFromMasterBook | `Future<void> unlinkFromMasterBook(String editionId)` | 解除關聯 |
| count | `Future<int> count({String? masterBookId})` | 統計（可限定 MasterBook） |

#### VersionManagementRepository

**位置**：`lib/domains/version_management/repositories/version_management_repository.dart`

**狀態**：介面已定義但尚未實作，待 Search Domain 完成後進行 TDD 開發。

### FR-8: 版本管理事件

**位置**：`lib/domains/version_management/events/version_events.dart`

所有事件繼承 `DomainEvent`（提供 `eventId`、`occurredAt`），實作 `toJson()`。

| 事件類別 | eventType | 攜帶資料 |
|---------|-----------|---------|
| VersionAnalysisStartedEvent | VERSION.ANALYSIS.STARTED | analyzedBookId, candidateCount |
| VersionAnalysisCompletedEvent | VERSION.ANALYSIS.COMPLETED | analyzedBookId, candidates: List\<ScoredCandidate\>, elapsedMilliseconds |
| VersionSuggestionCreatedEvent | VERSION.SUGGESTION.CREATED | sourceBookId, targetEditionId, scores: SimilarityScores |
| VersionMergeRequestedEvent | VERSION.MERGE.REQUESTED | masterBookId, editionIdToMerge, relationshipType |
| VersionMergeCompletedEvent | VERSION.MERGE.COMPLETED | masterBookId, primaryEditionId, mergedEditionIds, masterBookCreated |
| VersionMergeFailedEvent | VERSION.MERGE.FAILED | masterBookId, editionIdToMerge, reason |
| VersionSeparationRequestedEvent | VERSION.SEPARATION.REQUESTED | masterBookId, editionIdToSeparate |
| VersionSeparationCompletedEvent | VERSION.SEPARATION.COMPLETED | masterBookId, separatedEditionId |
| PrimaryEditionChangedEvent | VERSION.PRIMARY.CHANGED | masterBookId, oldPrimaryEditionId, newPrimaryEditionId |
| MasterBookCreatedEvent | MASTER_BOOK.CREATED | masterBookId, primaryEditionId |
| MasterBookUpdatedEvent | MASTER_BOOK.UPDATED | masterBookId, updatedFields: List\<String\> |
| MasterBookDeletedEvent | MASTER_BOOK.DELETED | masterBookId, releasedEditionIds: List\<String\> |

### FR-9: 驗證與工具

#### MasterBookFactory

**位置**：`lib/domains/version_management/factories/master_book_factory.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| create | `static OperationResult<MasterBook> create({required originalTitle, required originalAuthors, required primaryEditionId, originalIsbn?, originalLanguage?, firstPublishedDate?})` | 四階段驗證後建立實體 |
| clearGlobalCache | `static void clearGlobalCache()` | 清空唯一性快取（測試用） |
| cacheSize | `static int get cacheSize` | 快取統計（測試用） |

**四階段驗證流程**：

| 階段 | 驗證內容 | 失敗回傳 |
|------|---------|---------|
| 1. 基本欄位 | title 非空非空白（上限 500）、authors 至少 1 人（每人上限 200 且非空）、primaryEditionId 非空非空白非純特殊字元 | OperationResult.failure（含 AppException + ErrorCode.validationFailed） |
| 2. 可選欄位 | ISBN 格式（IsbnValidationService）、語言代碼（LanguageValidator）、出版日期不可為未來 | 同上 |
| 3. 業務規則 | 全域唯一性（GlobalUniquenessManager：同 title + authors 組合不可重複） | ErrorCode.duplicateBook |
| 4. 建立實體 | 生成 ID（`mb_{timestamp}_{random}`）、trim 所有字串、記錄到唯一性快取 | — |

#### IsbnUtils

**位置**：`lib/domains/version_management/utils/isbn_utils.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| normalizeIsbn | `static String normalizeIsbn(String isbn)` | 移除連字號和空格 |
| isValidIsbn10 | `static bool isValidIsbn10(String isbn)` | 驗證 ISBN-10（含 checksum） |
| isValidIsbn13 | `static bool isValidIsbn13(String isbn)` | 驗證 ISBN-13（含 checksum） |
| isbn10ToIsbn13 | `static String? isbn10ToIsbn13(String isbn10)` | 轉換（無效回傳 null） |
| isbn13ToIsbn10 | `static String? isbn13ToIsbn10(String isbn13)` | 轉換（979 前綴無法轉換回傳 null） |
| extractPublisherCode | `static String? extractPublisherCode(String isbn)` | 提取前 7 位出版社代碼 |
| isSamePublisher | `static bool isSamePublisher(String? isbn1, String? isbn2)` | 比較出版社代碼 |
| isSameSeries | `static bool isSameSeries(String? isbn1, String? isbn2)` | 比較前 10 位（同系列） |
| compareIsbn | `static double compareIsbn(String? isbn1, String? isbn2)` | 綜合比較（回傳 0.0-1.0） |

#### StringSimilarity

**位置**：`lib/domains/version_management/utils/string_similarity.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| levenshteinDistance | `static int levenshteinDistance(String s1, String s2)` | Levenshtein 距離（DP，O(m*n)） |
| normalizedSimilarity | `static double normalizedSimilarity(String s1, String s2)` | 正規化相似度（1 - distance/maxLen） |
| normalizeString | `static String normalizeString(String input)` | 轉小寫、移除標點、移除多餘空格 |
| removeSuffixes | `static String removeSuffixes(String input)` | 移除版本識別後綴（30+ 個中英文詞彙） |
| calculateSimilarity | `static double calculateSimilarity(String s1, String s2)` | 結合正規化和 Levenshtein 的綜合計算 |
| ignorableSuffixes | `static const List<String>` | 可忽略後綴清單 |

#### LanguageValidator

**位置**：`lib/domains/version_management/validators/language_validator.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| isValidLanguageCode | `static bool isValidLanguageCode(String languageCode)` | 支援 ISO 639-1（雙字元）和 BCP 47（如 zh-TW），73 個語言代碼 |
| normalizeLanguageCode | `static String normalizeLanguageCode(String languageCode)` | 轉小寫並 trim |
| supportedLanguageCodes | `static Set<String> get` | 取得所有支援的語言代碼 |
| isChineseLanguage | `static bool isChineseLanguage(String languageCode)` | 是否為中文 |
| isEnglishLanguage | `static bool isEnglishLanguage(String languageCode)` | 是否為英文 |
| getLanguageDisplayName | `static String getLanguageDisplayName(String languageCode)` | 取得英文顯示名稱 |

#### ValidationHelper

**位置**：`lib/domains/version_management/helpers/validation_helper.dart`

| 方法 | 簽名 | 說明 |
|------|------|------|
| wrapValidationResult | `static OperationResult<void> wrapValidationResult(bool isValid, AppException error, String successMessage)` | 統一驗證結果包裝 |
| validateNonEmpty | `static OperationResult<void> validateNonEmpty(String value, String fieldName, String customMessage, {String expectedFormat})` | 字串非空驗證 |
| validateNonEmptyAndNonWhitespace | `static OperationResult<void> validateNonEmptyAndNonWhitespace(String value, String fieldName, String emptyMessage, String whitespaceMessage)` | 字串非空且非空白 |
| validateMaxLength | `static OperationResult<void> validateMaxLength(String value, String fieldName, int maxLength, String customMessage)` | 長度限制驗證 |
| validatePattern | `static OperationResult<void> validatePattern(String value, String fieldName, RegExp pattern, String customMessage)` | 正則模式驗證 |
| wrapCreationFailure | `static OperationResult<T> wrapCreationFailure<T>(Exception error, [String? customMessage])` | 統一失敗包裝（支援 6 種 Exception 型別） |
| handleUnexpectedError | `static OperationResult<T> handleUnexpectedError<T>(dynamic exception)` | 未預期錯誤包裝 |

#### GlobalUniquenessManager

**位置**：`lib/domains/version_management/managers/global_uniqueness_manager.dart`

記憶體內快取，以 `{normalizedTitle}:{sortedNormalizedAuthors}` 為 key 判斷唯一性。

| 方法 | 簽名 | 說明 |
|------|------|------|
| isUnique | `static bool isUnique(String title, List<String> authors)` | 檢查是否已存在 |
| addToCache | `static void addToCache(String title, List<String> authors)` | 新增到快取 |
| clearCache | `static void clearCache()` | 清空快取（測試用） |
| cacheSize | `static int get cacheSize` | 快取大小（測試用） |

#### MasterBookConstants

**位置**：`lib/domains/version_management/constants/master_book_constants.dart`

| 常數 | 值 | 說明 |
|------|------|------|
| maxTitleLength | 500 | 書名上限 |
| maxAuthorNameLength | 200 | 作者名上限 |
| masterBookIdPrefix | 'mb_' | ID 前綴 |
| createSuccessMessage | 'MasterBook created successfully' | 成功訊息 |
| creationFailedPrefix | 'Creation failed: ' | 錯誤訊息前綴 |
| entityType | 'MasterBook' | 實體類型標識 |

### FR-10: 展示層

**位置**：`lib/presentation/version_management/widgets/`

| 元件 | 檔案 | 職責 |
|------|------|------|
| VersionManagementPage | version_management_page.dart | 版本管理主頁面 |
| VersionGroupCard | version_group_card.dart | 版本群組卡片（書庫中的群組展示） |
| VersionSuggestionBanner | version_suggestion_banner.dart | 版本建議橫幅（新書加入時的合併建議） |
| VersionComparisonSheet | version_comparison_sheet.dart | 版本比較表（並排比對版本差異） |
| SimilarBookSearchResultList | similar_book_search_result_list.dart | 相似書籍搜尋結果列表 |
| VersionMergeConfirmDialog | version_merge_confirm_dialog.dart | 合併確認對話框 |
| VersionExpansionPanel | version_expansion_panel.dart | 版本展開面板（多版本切換檢視） |
| VersionIndicator | version_indicator.dart | 版本指示器（右上角版本數量標記） |

## 業務規則摘要

### BR-1: 版本關聯規則

- 每個 BookEdition 只能屬於一個 MasterBook
- MasterBook 必須至少包含一個 BookEdition
- 刪除 MasterBook 最後一個版本時，自動清理 MasterBook

### BR-2: 合併規則

- 兩本書 ID 必須不同（否則 BusinessException）
- 優先使用已有 MasterBook，否則新建
- 合併操作為原子性（OperationResult 模式），失敗時回滾

### BR-3: 分離規則

- 分離操作保留原始 MasterBook（若仍有其他版本）
- 為分離的版本建立新的獨立 MasterBook

### BR-4: 顯示優先級規則

- 原文版優先於翻譯版
- 較新版本優先於舊版本
- 使用者手動設定的 primaryEdition 優先級最高

### BR-5: MasterBook 建立驗證規則

- 書名：非空、非空白、上限 500 字元
- 作者：至少 1 人、各非空、各上限 200 字元
- primaryEditionId：非空、非空白、非純特殊字元
- ISBN：須通過 ISBN-10/ISBN-13 格式驗證
- 語言代碼：須通過 ISO 639-1 / BCP 47 驗證
- 出版日期：不可為未來日期
- 全域唯一性：同 title + authors 組合不可重複（記憶體內快取）

### BR-6: 翻譯判定規則

- 翻譯信心度 >= 0.5 即判定為翻譯版
- TranslationMetadata 有效性：translators 非空 AND targetLanguage 非空 AND sourceLanguage 非空 AND target != source

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 |
|------|------|
| 相似度計算 | 單次比對 < 10ms |
| 批次分析 | 100 本書 < 5 秒 |
| MasterBook 查詢 | < 100ms |

### NFR-2: 資料完整性

合併操作為原子性（OperationResult 模式），失敗時回滾。分離操作保留原始 MasterBook（若仍有其他版本）。循環引用防護由 `GlobalUniquenessManager` 管理。

## 實作狀態

### 已實作元件

| 元件 | 狀態 | 說明 |
|------|------|------|
| MasterBook / BookEdition 實體 | 已完成 | 含完整 Equatable/copyWith/JSON |
| 所有 Value Objects（9 個） | 已完成 | SimilarityScores / ConfidenceLevel / ScoredCandidate / VersionAnalysisResult / TranslationMetadata / TranslationIndicator / TranslationAnalysisResult / VersionMergeResult / VersionRelationshipType |
| MasterBookFactory | 已完成 | 四階段驗證 |
| IsbnUtils / StringSimilarity | 已完成 | 含完整演算法 |
| LanguageValidator | 已完成 | 73 個語言代碼 |
| ValidationHelper / GlobalUniquenessManager / MasterBookConstants | 已完成 | — |
| 版本事件（12 個） | 已完成 | 繼承 DomainEvent |
| VersionDetector / SimilarityCalculator / TranslationDetector 介面 | 已完成 | — |
| DefaultVersionDetector / DefaultSimilarityCalculator / DefaultTranslationDetector | 已完成 | 介面實作 |
| VersionManager 介面 + DefaultVersionManager | 已完成 | 含合併/分離邏輯 |
| MasterBookRepository / BookEditionRepository 介面 | 已完成 | — |
| 展示層 Widget（8 個） | 已完成 | — |

### 待實作元件（Stub）

| 元件 | 狀態 | 說明 |
|------|------|------|
| VersionManagementRepository | stub | 聚合操作，待 Search Domain 完成後 TDD |
| VersionMerger | stub | 版本合併邏輯（已有 DefaultVersionManager 實作核心邏輯） |
| BookEditionMatcher | stub | 版本匹配邏輯（已有 DefaultVersionDetector 實作核心邏輯） |
| VersionSimilarityCalculator | stub | 相似度計算（已有 DefaultSimilarityCalculator 實作核心邏輯） |

## 需求與實作差距

| 需求（app-requirements-spec） | 實作狀態 | 差距 |
|------------------------------|---------|------|
| FR-VM-01: 版本識別與關聯 | 已實作（VersionDetector + SimilarityCalculator） | 無 |
| FR-VM-02: MasterBook 概念 | 已實作（MasterBook + BookEdition 實體） | 無 |
| FR-VM-03: 版本管理介面 | 已實作（8 個 Widget） | 無 |
| FR-VM-04: 翻譯書籍特殊處理 | 已實作（TranslationDetector + TranslationMetadata） | 無 |
| FR-VM-05: 使用者控制 | 已實作（mergeBooks / separateEdition / setPrimaryEdition） | 無 |
| 自動識別相似書籍 | 已實作（minSimilarity=0.60, ConfidenceLevel 三級） | 無 |
| 書庫顯示同書多版本只佔一格 | 已實作（primaryEdition 概念） | 無 |
| UC-08 8A.3 建議閾值 | 程式碼使用 high >= 0.80 / medium >= 0.60 | 無（UC-08 已修正為 >= 0.6，與 ConfidenceLevel 三級制一致） |
| VersionManagementRepository 聚合操作 | 已移除（W3-008） | 功能已由 MasterBookRepository + BookEditionRepository 覆蓋，stub 為死碼 |
| VersionMerger / BookEditionMatcher / VersionSimilarityCalculator | 已移除（W3-008） | 核心邏輯已由 Default* 實作覆蓋，stub 為死碼（零引用） |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-08: 書籍版本管理系統

## 相關規格

- SPEC-006: 雙模式書庫展示規格（版本群組在書庫中的顯示）
- SPEC-016: version-management 資料契約（`master_books` / `book_editions` DDL 與不變式）

---

**Last Updated**: 2026-07-26 | **Version**: 3.1 — 檔名改為 ID 前綴式 `SPEC-009-book-version-management.md`（0.38.1-W11-004 重複編號治理：SPEC-009 保留給本規格，QR frame 格式規格改號 SPEC-017）；規格內容未變更
**Version**: 3.0 — 見 0.35.0-W3-006
