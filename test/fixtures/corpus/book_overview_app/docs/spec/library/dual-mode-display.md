---
id: SPEC-006
title: "雙模式書庫展示規格"
status: draft
source_proposal: null
created: "2026-03-30"
updated: "2026-06-20"
version: "3.0"
owner: ""

domain: library
subdomain: null

related_usecases: [UC-05]
related_specs: [SPEC-007]
implements_requirements: [UC-03]
depends_on_domains: [search, version_management]
---

# 雙模式書庫展示規格

## 概述

定義書庫的雙模式展示系統：簡潔模式（預設）提供快速瀏覽，管理模式提供完整資訊與進階操作。系統基於 `DisplayMode` 列舉切換，透過 `Book.getViewForMode()` 產生模式專屬的 `BookView` 投影，確保 UI 層只接收當前模式需要的資料。

## 功能需求 (FR)

### FR-1: 書籍資料模型

Book 為書庫聚合根（`lib/domains/library/entities/book.dart`），採不可變物件模式（Equatable），所有狀態變更透過 `copyWith()` 返回新實例。

#### FR-1.1: 固定欄位

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| id | `BookId` (Value Object) | 是 | 唯一識別，支援 Chrome Extension 相容 |
| title | `BookTitle` (Value Object) | 是 | 書名，含驗證（不可空、最大 500 字元） |
| status | `BookStatus` (Enum) | 是 | 狀態機（預設 `initial`） |
| publishDate | `DateTime?` | 否 | 出版日期（ISO 8601） |
| description | `String?` | 否 | 描述（最大 5000 字元） |
| coverImageUrl | `String?` | 否 | 封面圖片 URL |
| rating | `double?` | 否 | 評分（0.0-5.0） |
| addedDate | `DateTime` | 是 | 加入書庫日期（建立時自動設定） |
| apiEnriched | `bool` | 是 | 是否已透過 API 補充（預設 `false`） |
| activeLoan | `BookLoan?` | 否 | 當前借閱記錄（見 SPEC-007） |
| cover | `BookCover?` | 否 | 多尺寸封面（thumbnail/medium/original） |
| progress | `BookProgress?` | 否 | 閱讀進度（percentage + currentPage/totalPages/lastReadAt） |
| crossPlatformId | `String?` | 否 | 跨平台識別碼（同步去重） |
| dataFingerprint | `String?` | 否 | 資料指紋（重複偵測） |
| bookTags | `List<BookTag>` | 是 | Tag-based metadata 集合（預設空列表） |
| extensions | `Map<String, dynamic>?` | 否 | 跨工具擴充欄位（round-trip 保留） |
| passthrough | `Map<String, dynamic>?` | 否 | 未解析原始欄位透傳 |

#### FR-1.2: Tag-based Metadata（PROP-007 模式）

以 `BookTag`（categoryId + value + isPrimary）儲存，取代傳統固定欄位。

| 系統 Tag 分類（categoryId） | 語意 | 多值/單值 | 範例值 |
|---------------------------|------|----------|--------|
| `author` | 作者 | 多值 | `"村上春樹"` |
| `publisher` | 出版社 | 單值 | `"時報出版"` |
| `platform` | 電子書平台 | 單值 | `"readmoo"` |
| `language` | 語言 | 單值 | `"zh-TW"` |
| `isbn` | ISBN | 單值 | `"9780123456789"` |
| `alias` | 別名 | 多值 | `"Norwegian Wood"` |
| `reading_status` | 閱讀狀態 | 單值 | `"reading"` |
| `importance` | 重要程度 | 單值 | `"5"` |
| `series` | 系列叢書 | 單值 | `"哈利波特系列"` |
| `description` | 書籍描述 | 單值 | （文字） |
| `ccl` | 中文圖書分類法 | 多值 | `"語言文學/東方文學"` |
| `source_type` | 來源類型 | 單值 | `"digital"` |
| `custom` | 使用者自定義 | 多值 | `"技術書"` |

**BookTag Value Object**（`lib/domains/library/value_objects/book_tag.dart`）：

```dart
class BookTag extends Equatable {
  final String categoryId;
  final String value;
  final bool isPrimary;  // 同分類多值時標記首選
  final String? id;      // DB tag id（可選）
  final String? path;    // 巢狀路徑（ccl/custom 用）
}
```

工廠方法：

| 方法 | 簽名 | 說明 |
|------|------|------|
| primary | `factory BookTag.primary({required String categoryId, required String value, ...})` | 建立主要 tag（isPrimary = true） |
| validated | `factory BookTag.validated({required String categoryId, required String value, ...})` | 建立經領域驗證的 tag（非法值拋 ValidationException） |
| fromJson | `factory BookTag.fromJson(String categoryId, Map<String, dynamic> json)` | 從交換格式反序列化 |

**Tag 存取 API**（Book entity 方法）：

| 方法 | 簽名 | 說明 |
|------|------|------|
| getTagsByCategory | `List<BookTag> getTagsByCategory(String categoryId)` | 取得指定分類所有 tag |
| getPrimaryTag | `BookTag? getPrimaryTag(String categoryId)` | 取得指定分類的主要 tag |

**VO 行為橋接 Helper**（Book entity 衍生屬性，從 bookTags 即時推導）：

| 屬性 | 型別 | 推導來源 | 說明 |
|------|------|---------|------|
| sourceType | `SourceType` | `source_type` tag | 容錯回 `physical` |
| sourcePlatform | `Platform?` | `platform` tag | 無 tag 回 `null` |
| sourceDisplayName | `String` | platform?.displayName ?? type.displayName | 來源顯示名 |
| isDigitalSource | `bool` | sourceType | 是否電子書 |
| isPhysicalSource | `bool` | sourceType | 是否實體書 |
| isBorrowedSource | `bool` | sourceType | 是否借閱 |
| importanceValue | `int?` | `importance` tag | 無 tag 或非數字回 `null` |
| importanceTier | `ImportanceTier?` | importanceValue | 非 1-7 回 `null` |
| readingStatus | `ReadingStatus` | `reading_status` tag | 無 tag 回 `notStarted` |
| authorDisplay | `String` | `author` tag(s) | 多作者逗號合併，空回 `'Unknown Author'` |
| primaryAuthor | `String` | author tags 第一個 | 空回 `'Unknown Author'` |
| allAuthors | `List<String>` | author tags | 不可變列表 |
| authorTranslator | `String?` | 解析 `(XXX 譯)` 括號 | 無譯者回 `null` |
| hasTranslator | `bool` | authorTranslator | 是否有譯者 |
| hasMultipleAuthors | `bool` | _rawAuthorSegments | 是否多作者 |
| authorCount | `int` | _rawAuthorSegments | 作者數（空回 1） |
| tags | `List<Tag>` | `custom` 分類 BookTag | 向後相容衍生 |

### FR-2: 雙模式展示

#### FR-2.1: 模式定義

`DisplayMode`（`lib/domains/library/enums/display_mode.dart`）：

```dart
enum DisplayMode {
  simple,     // 簡潔模式（預設）
  management; // 管理模式
}
```

**每個模式的屬性**：

| 屬性 | 型別 | 說明 |
|------|------|------|
| displayName | `String` | 中文名稱（`'簡潔模式'` / `'管理模式'`） |
| description | `String` | 模式描述文字 |
| visibleFields | `List<String>` | 該模式下可見欄位名稱列表 |
| shouldShowField(String) | `bool` | 檢查指定欄位是否在可見列表中 |

#### FR-2.2: 各模式顯示欄位

| 模式 | 顯示欄位 | 適用場景 |
|------|---------|---------|
| `simple` | cover, title, source（共 3 欄位） | 快速瀏覽、日常使用 |
| `management` | cover, title, author, source, status, importanceLevel, readingProgress, tags, loanInfo, createdAt, updatedAt, notes（共 12 欄位） | 詳細管理、編輯操作 |

#### FR-2.3: BookView 投影

`BookView`（`lib/domains/library/value_objects/book_view.dart`）：

```dart
class BookView extends Equatable {
  final Map<String, dynamic> fields;
  final String mode;

  factory BookView.create({required Book book, required DisplayMode mode});
  factory BookView.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

**投影欄位對照表**：

| 模式 | 投影鍵 | 來源 |
|------|--------|------|
| simple | `cover` | `book.coverImageUrl` |
| simple | `title` | `book.title.toString()` |
| simple | `source` | `book.sourceDisplayName` |
| management | `id` | `book.id.toString()` |
| management | `title` | `book.title.toString()` |
| management | `author` | `book.authorDisplay` |
| management | `isbn` | `book.getPrimaryTag(TagCategoryIds.isbn)?.value` |
| management | `publisher` | `book.getPrimaryTag(TagCategoryIds.publisher)?.value` |
| management | `publishDate` | `book.publishDate?.toIso8601String()` |
| management | `description` | `book.description` |
| management | `coverImageUrl` | `book.coverImageUrl` |
| management | `rating` | `book.rating` |
| management | `tags` | `book.tags.map((t) => t.name).toList()` |
| management | `readingStatus` | `book.readingStatus.name` |
| management | `source` | `book.sourceDisplayName` |
| management | `status` | `book.status.name` |
| management | `importanceLevel` | `book.importanceValue` |
| management | `addedDate` | `book.addedDate.toIso8601String()` |
| management | `readingProgress` | `book.readingStatus.name` |

**Book entity 入口方法**：

```dart
BookView getViewForMode(DisplayMode mode) => BookView.create(book: this, mode: mode);
```

#### FR-2.4: UI 模式管理

模式切換由 `LibraryDisplayViewModel`（`lib/presentation/library/library_viewmodel.dart`）管理：

| 方法/屬性 | 簽名 | 說明 |
|----------|------|------|
| toggleDisplayMode | `void toggleDisplayMode()` | 在 simple/management 間切換 |
| setDisplayMode | `void setDisplayMode(DisplayMode mode)` | 直接設定模式 |
| isManagementMode | `bool` (getter) | 是否為管理模式 |
| loadPreference | `Future<void> loadPreference()` | 載入已儲存偏好 |
| build | `LibraryDisplayState` | 初始化並載入偏好 |

**LibraryDisplayState**：

| 欄位 | 型別 | 說明 |
|------|------|------|
| displayMode | `DisplayMode` | 當前顯示模式 |
| books | `List<Book>` | 書籍列表 |
| selectedBookIds | `Set<String>` | 已選書籍 ID |
| isLoading | `bool` | 載入中 |
| errorMessage | `String?` | 錯誤訊息 |
| currentFilter | `LibraryFilter` | 篩選條件（all/digital/physical/borrowed） |
| isPreferenceLoaded | `bool` | 偏好是否已載入 |

**Riverpod Providers**：

| Provider | 說明 |
|----------|------|
| libraryDisplayViewModelProvider | 主 ViewModel（NotifierProvider） |
| libraryDisplayModeProvider | 當前模式（derived） |
| libraryFilteredBooksProvider | 篩選後書籍（derived） |
| librarySelectedBooksProvider | 已選書籍（derived） |
| librarySelectionStatsProvider | 選取統計（derived） |

**切換 UI 元件**：`DisplayModeToggleButton`（`lib/presentation/library/widgets/display_mode_toggle_button.dart`）

| 屬性 | 型別 | 說明 |
|------|------|------|
| currentMode | `DisplayMode` | 當前模式 |
| onToggle | `VoidCallback` | 切換回調 |

- 簡潔模式圖標：`Icons.view_list`
- 管理模式圖標：`Icons.grid_view`
- 含 Tooltip（l10n）和 Semantics（無障礙標籤）

### FR-3: 重要程度分類

`ImportanceTier`（`lib/domains/library/value_objects/importance_tier.dart`）：

| 等級 | 語意 | isHigh | isMedium | isLow | colorCode |
|------|------|--------|----------|-------|-----------|
| 1 | 低重要性 | false | false | true | `#4CAF50`（綠） |
| 2 | 低重要性 | false | false | true | `#4CAF50`（綠） |
| 3 | 中等重要性 | false | true | false | `#FF9800`（橙） |
| 4 | 中等重要性 | false | true | false | `#FF9800`（橙） |
| 5 | 高重要性 | true | false | false | `#F44336`（紅） |
| 6 | 高重要性 | true | false | false | `#F44336`（紅） |
| 7 | 最高重要性 | true | false | false | `#9C27B0`（紫） |

**介面契約**：

| 方法 | 簽名 | 說明 |
|------|------|------|
| fromValue | `static ImportanceTier? fromValue(int value)` | 由整數重建；非 1-7 回 `null` |
| compareTo | `int compareTo(ImportanceTier other)` | 依 value 比較 |
| isHigherThan | `bool isHigherThan(ImportanceTier other)` | 是否比指定等級高 |
| isLowerThan | `bool isLowerThan(ImportanceTier other)` | 是否比指定等級低 |
| description | `String` (getter) | 中文描述 |
| colorCode | `String` (getter) | 色碼字串 |

### FR-4: 閱讀狀態追蹤

#### FR-4.1: ReadingStatus 列舉

`ReadingStatus`（`lib/domains/library/enums/reading_status.dart`）：

| 狀態 | displayName | 說明 |
|------|-------------|------|
| notStarted | `'未開始'` | 預設值 |
| queued | `'排隊等待'` | 待讀清單 |
| reading | `'閱讀中'` | 正在閱讀 |
| finished | `'已完成'` | 已讀完 |
| abandoned | `'已放棄'` | 中途放棄 |
| reference | `'參考書'` | 工具書/隨時查閱 |

**解析入口**：`ReadingStatusExtension.fromString(String?)` — 唯一 `String? -> ReadingStatus` 解析方法，支援 canonical `.name` 小寫 + snake_case alias（`not_started`），null/空字串/未知值容錯回 `notStarted`。

#### FR-4.2: BookReadingInfo 值物件

`BookReadingInfo`（`lib/domains/library/value_objects/book_reading_info.dart`）：

| 欄位 | 型別 | 說明 |
|------|------|------|
| progress | `ReadingProgress` | 閱讀進度 |
| status | `ReadingStatus` | 閱讀狀態 |
| startedAt | `DateTime?` | 開始時間 |
| completedAt | `DateTime?` | 完成時間 |
| estimatedReadingTime | `Duration?` | 預估閱讀時間 |
| notes | `String?` | 閱讀筆記 |

**業務方法**：

| 方法 | 簽名 | 業務規則 |
|------|------|---------|
| notStarted | `factory BookReadingInfo.notStarted()` | 建立預設閱讀資訊 |
| create | `factory BookReadingInfo.create({...})` | 建立完整閱讀資訊（含一致性驗證） |
| startReading | `BookReadingInfo startReading()` | 狀態改 reading，自動設 startedAt |
| updateProgress | `BookReadingInfo updateProgress(ReadingProgress)` | 100% 自動改 finished；從 notStarted 自動改 reading |
| markAsCompleted | `BookReadingInfo markAsCompleted()` | 進度設 100%，狀態改 finished，自動設 completedAt |
| reset | `BookReadingInfo reset()` | 重設進度和狀態 |
| updateEstimatedTime | `BookReadingInfo updateEstimatedTime(Duration?)` | 更新預估時間 |
| updateNotes | `BookReadingInfo updateNotes(String?)` | 更新筆記（自動 trim） |
| readingSpeed | `double? readingSpeed(int? totalPages)` | 計算閱讀速度（頁/時） |
| estimatedTimeRemaining | `Duration? estimatedTimeRemaining(int? totalPages)` | 估算剩餘時間 |

**一致性驗證**（`create` 工廠方法）：
- `finished` 狀態必須配合 100% 進度
- 100% 進度必須配合 `finished` 狀態
- `completedAt` 不可早於 `startedAt`

### FR-5: 書籍狀態機

`BookStatus`（`lib/domains/library/enums/book_status.dart`）：

```
initial -> enriching -> enriched -> available -> reading / lentOut / completed -> archived
```

**狀態轉換規則**（`canTransitionTo()` 守衛）：

| 當前狀態 | 可轉換至 |
|---------|---------|
| initial | enriching, available |
| enriching | enriched, available |
| enriched | available |
| available | reading, lentOut, archived |
| reading | completed, available |
| completed | available, archived |
| lentOut | available |
| archived | available |

**狀態屬性**：

| 屬性 | 型別 | 說明 |
|------|------|------|
| displayName | `String` | 中文名稱 |
| isActive | `bool` | 非歸檔狀態 |
| isReadable | `bool` | available 或 reading |

**Book entity 狀態轉換方法**：

| 方法 | 簽名 | 說明 |
|------|------|------|
| startEnrichment | `Book startEnrichment()` | initial -> enriching |
| completeEnrichment | `Book completeEnrichment()` | enriching -> enriched |
| markAsAvailable | `Book markAsAvailable()` | -> available |

### FR-6: 來源與平台

**SourceType**（`lib/domains/library/enums/source_type.dart`）：

| 值 | displayName | 便利屬性 |
|----|-------------|---------|
| digital | `'Digital'` | isDigital |
| physical | `'Physical'` | isPhysical |
| borrowed | `'Borrowed'` | isBorrowed |

**Platform**（`lib/domains/library/enums/platform.dart`）：

| 值 | displayName | isDigital |
|----|-------------|-----------|
| readmoo | `'Readmoo'` | true |
| kobo | `'Kobo'` | true |
| kindle | `'Kindle'` | true |
| bookwalker | `'BookWalker'` | true |
| googleBooks | `'Google Books'` | true |
| appleBooks | `'Apple Books'` | true |
| audible | `'Audible'` | true |
| spotify | `'Spotify'` | true |
| physical | `'Physical Book'` | false |

### FR-7: 標籤系統

`TagManagementService`（`lib/domains/library/services/tag_management_service.dart`）：

| 方法 | 說明 |
|------|------|
| listTags() | 列出所有標籤 |
| createTag(...) | 建立標籤（檢查鎖定、重複、父標籤） |
| renameTag(...) | 重新命名（檢查鎖定、重複） |
| moveTag(...) | 移動至其他父標籤（檢查循環） |
| mergeTags(...) | 合併標籤 |
| deleteTag(...) | 刪除標籤（檢查鎖定） |
| findBooksByTag(...) | 依標籤查詢書籍 |

**TagRepository 介面**（`lib/domains/library/repository/tag_repository.dart`）：

| 方法 | 說明 |
|------|------|
| getTagsByCategory(String categoryId) | 依分類取 tag |
| getTagById(String id) | 依 ID 取 tag |
| getChildTags(String parentId) | 取子 tag |
| createTag(...) | 建立 |
| updateTagName(String id, String name) | 改名 |
| updateTagParent(String id, String? parentId) | 移動 |
| transferBookTags(String fromId, String toId) | 合併轉移 |
| deleteTag(String id) | 刪除 |
| deleteTagAndDescendants(String id) | 刪除含子孫 |
| reparentChildren(String id, String? newParent) | 子項重分配 |
| getDescendantTagIds(String id) | 取所有後代 ID |
| getBooksByTagIds(List\<String\> ids) | 依 tag ID 查書 |
| existsInSameScope(...) | 同範圍重複檢查 |

### FR-8: 搜尋與篩選

**BookSearchEngine**（`lib/domains/library/services/book_search_engine.dart`）：

| 方法 | 說明 |
|------|------|
| createFromBooks(List\<Book\>) | 從書籍列表建立引擎 |
| executeSearchWithCriteria(SearchCriteria) | 執行多條件搜尋 |

**篩選維度**：title, author, sourceType, tags, importanceTier, readingProgress, completionStatus, dateRange

**搜尋策略**（`lib/domains/library/strategies/`）：

| 策略 | 演算法 |
|------|-------|
| ExactSearchStrategy | 精確比對 |
| FuzzySearchStrategy | Jaro-Winkler 模糊比對 |
| HybridSearchStrategy | 精確 + 模糊混合 |

**篩選器**（`lib/domains/library/filters/`）：FilterManager, FilterRegistry, TagFilter, DateRangeFilter, ImportanceFilter, SourceTypeFilter, ReadingStatusFilter, SearchFilter

### FR-9: 批次操作

**LibraryManagementService**（`lib/domains/library/services/library_management_service.dart`）：

| 方法 | 說明 |
|------|------|
| selectBooks(SelectionCriteria) | 依條件選取書籍 |
| performBatchOperation(BatchOperation) | 執行批次操作 |
| generateStatistics() | 產生統計 |
| getOperationHistory() | 取得操作歷史 |

**SelectionType**：all, byIds, bySearch, byConditions

**BatchOperationType**：delete, updateSourceType, updateImportanceLevel, addTags, removeTags

### FR-10: 編輯與復原

**Command 模式**（`lib/domains/library/commands/`）：

| 元件 | 職責 |
|------|------|
| EditCommand | 基底介面（execute/undo） |
| UpdateBookCommand | 更新書籍 |
| DeleteBookCommand | 刪除書籍 |
| BatchEditCommand | 批次編輯 |
| EditCommandInvoker | undo/redo 堆疊管理 |

**BookEditingService**（`lib/domains/library/services/book_editing_service.dart`）：

| 方法 | 說明 |
|------|------|
| startEditSession(...) | 開啟編輯 session |
| validateChanges(String sessionId) | 驗證變更 |
| saveChanges(String sessionId) | 儲存（含 ISBN 重複驗證） |
| cancelEditSession(String sessionId) | 取消 |
| undoLastEdit() | 復原 |
| redoNextEdit() | 重做 |
| canUndo() / canRedo() | 是否可復原/重做 |
| getEditHistory() | 取得編輯歷史 |
| clearEditHistory() | 清除歷史 |
| executeDeleteBook(...) | 刪除（含 undo） |
| executeBatchEdit(...) | 批次編輯 |

### FR-11: 書籍服務層

| 服務 | 位置 | 核心方法 |
|------|------|---------|
| LibraryService | `library_service.dart` | getAllBooks, getBookById, searchBooks, addBook, removeBook, updateBook, getLibraryStatistics |
| BookService | `book_service.dart` | searchByIsbn, getBookByIsbn, addBook, searchBooks, getAllBooks, updateBook, deleteBook, getBookStats |
| AdvancedSearchService | `advanced_search_service.dart` | searchAdvanced, getSearchHistory, saveSearchHistory, clearSearchHistory, getSearchSuggestions |
| BookMergeService | `book_merge_service.dart` | switchPrimaryTitle, 跨書籍合併標籤 |

### FR-12: Repository 介面

| 介面 | 位置 | 核心方法 |
|------|------|---------|
| BaseBookRepository | `repository/base_book_repository.dart` | addBook, findById, findByIsbn, updateBook, deleteBook, markAsEnriched |
| ExtendedBookRepository | `repository/extended_book_repository.dart` | getAllBooks, getBooks, searchBooks, getBooksByStatus, getStatistics, addBooks, getTotalCount, findUnenrichedBooks, fullTextSearch |
| BookRepository | `repository/book_repository.dart` | saveBook, getBookById, deleteBookById, importInterchange, readTagTree |
| TagRepository | `repository/tag_repository.dart` | （見 FR-7） |
| BookQueryPort | `ports/book_query_port.dart` | 查詢端口介面 |

## 業務規則 (BR)

### BR-1: 模式切換業務規則

| 規則 | 說明 |
|------|------|
| BR-1.1 | 簡潔模式為系統預設模式 |
| BR-1.2 | 模式切換為即時生效，無需重新載入資料 |
| BR-1.3 | 系統記住使用者的模式偏好（透過 LibraryDisplayViewModel 持久化） |
| BR-1.4 | 切換時保持當前篩選和排序狀態不變 |
| BR-1.5 | UI 層只使用 BookView 渲染，不直接存取 Book 聚合根 |

### BR-2: 重要程度業務規則

| 規則 | 說明 |
|------|------|
| BR-2.1 | ImportanceTier 限 1-7 七個等級，fromValue 非 1-7 回 null 不 throw |
| BR-2.2 | 透過 BookTag.validated 寫入時強制驗證範圍，非法值拋 ValidationException |
| BR-2.3 | 每本書只有一個 importance tag（單值，_upsertPrimaryTag 替換） |
| BR-2.4 | 等級變更記錄至 ModificationHistory |

### BR-3: 閱讀狀態業務規則

| 規則 | 說明 |
|------|------|
| BR-3.1 | ReadingStatus.fromString 為唯一解析入口（含 snake_case alias 支援） |
| BR-3.2 | null/空字串/未知值容錯回 notStarted |
| BR-3.3 | 100% 進度必須配合 finished 狀態（雙向一致性） |
| BR-3.4 | 從 notStarted 進入有進度狀態時自動改 reading |

### BR-4: 書籍狀態機業務規則

| 規則 | 說明 |
|------|------|
| BR-4.1 | 非法狀態轉換由 canTransitionTo() 拒絕 |
| BR-4.2 | 所有狀態轉換記錄至 ModificationHistory |
| BR-4.3 | initial 可直接轉 available（跳過 enrichment） |

### BR-5: 標籤業務規則

| 規則 | 說明 |
|------|------|
| BR-5.1 | 鎖定分類（is_locked，如 ccl）不可修改/刪除 |
| BR-5.2 | 同分類下標籤名稱不可重複 |
| BR-5.3 | 移動標籤時檢測循環依賴（guardCyclicMove） |
| BR-5.4 | custom 分類標籤以 isPrimary 區分主要標籤 |
| BR-5.5 | 書籍 custom tag 重複名稱自動忽略（addTag 冪等） |

### BR-6: 借閱業務規則

| 規則 | 說明 |
|------|------|
| BR-6.1 | 一本書同時只能有一個活躍借閱記錄 |
| BR-6.2 | 延期的新到期日不可早於原到期日 |
| BR-6.3 | 所有借閱操作記錄至 ModificationHistory |

### BR-7: 不可變物件規則

| 規則 | 說明 |
|------|------|
| BR-7.1 | Book entity 一旦建立，ID 不可變更 |
| BR-7.2 | 所有狀態變更透過 copyWith 返回新實例 |
| BR-7.3 | ModificationHistory 只能透過業務方法新增記錄 |
| BR-7.4 | markAsApiEnriched() 冪等（已標記不建立新實例） |

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 |
|------|------|
| 模式切換回應 | < 100ms（僅資料投影切換，無 API 呼叫） |
| 大量書籍載入 | 分頁（PaginatedBookList）+ ListView.builder 虛擬化 |
| 本地搜尋回應 | < 200ms |
| 首屏載入 | < 1 秒（首次 50 本） |
| 1000 本書完整載入 | < 5 秒（分頁載入） |
| 記憶體峰值 | < 200MB |
| 圖片快取 | < 50MB |
| Widget 重建 | < 16ms（維持 60 FPS） |

### NFR-2: 可觀測性

Observer 模式提供即時進度回報（`lib/domains/library/observers/`）：

| Observer | 用途 |
|----------|------|
| BatchOperationObserver | 批次操作進度 |
| EditSessionObserver | 編輯 session 狀態 |
| SearchProgressObserver | 搜尋進度 |

關鍵流程（書籍新增、狀態轉換、批次操作）透過 `AppLogger` 記錄。

## 需求與實作差距

| 需求（app-requirements-spec / UC-05） | 實作狀態 | 差距說明 |
|--------------------------------------|---------|---------|
| 簡潔模式：封面、書名、來源圖標 | 已實作（DisplayMode.simple） | 無 |
| 簡潔模式：載入指示器 | 部分實作 | UC-05 提到背景補充中書籍顯示載入動畫，LibraryDisplayState.isLoading 存在但個別書籍載入動畫需確認 UI 層 |
| 管理模式：完整 12 欄位 | 已實作（DisplayMode.management） | 見 GAP-1, GAP-2, GAP-3 |
| 右上角模式切換按鈕 | 已實作（DisplayModeToggleButton） | 無 |
| 記住使用者偏好設定 | 已實作（LibraryDisplayViewModel） | 無 |
| 7 級重要程度 | 已實作（ImportanceTier 1-7） | 無 |
| 閱讀進度和狀態 | 已實作（BookReadingInfo + ReadingStatus） | 無 |
| 標籤系統 | 已實作（TagManagementService） | 無 |
| 批次管理操作 | 已實作（LibraryManagementService + Command 模式） | 無 |
| 借閱資訊 | 已實作（BookLoan，見 SPEC-007） | 無 |
| 詳細統計和分析 | 已實作（getLibraryStatistics） | 無 |
| UC-05 情境化建議（新使用者推薦簡潔模式） | 未實作 | UC-05 5C 提到情境化建議，現有實作僅記住偏好 |
| UC-05 功能引導（簡潔模式提示管理模式功能） | 未實作 | UC-05 5C 提到功能引導，現有實作無此機制 |

### GAP-1: BookView management 模式欄位不完整

`DisplayMode.management.visibleFields` 宣告包含 `loanInfo` 和 `notes` 欄位，但 `BookView.create()` 的 management 分支未產出這兩個鍵值。

- **visibleFields 宣告**：含 `loanInfo`, `notes`（`display_mode.dart:36-48`）
- **BookView.create 實際產出**：management 分支無 `loanInfo` 和 `notes`（`book_view.dart:35-53`）
- **影響**：UI 透過 `BookView.fields['loanInfo']` / `BookView.fields['notes']` 讀取會得到 `null`
- **建議**：在 `BookView.create` management 分支加入 `fields['loanInfo']` 和 `fields['notes']`

### GAP-2: BookView management 模式 readingProgress 值不正確

`BookView.create()` management 分支中 `readingProgress` 欄位值為 `book.readingStatus.name`（與 `readingStatus` 欄位值完全相同），而非閱讀進度數值。

- **現況**：`fields['readingProgress'] = book.readingStatus.name`（`book_view.dart:52`）
- **預期**：應為 `book.progress?.percentage` 或 `book.progress?.toJson()` 以反映閱讀進度
- **影響**：UI 顯示的「閱讀進度」實為閱讀狀態名稱（如 `"reading"`），非百分比數值

### GAP-3: BookView management 模式缺少 updatedAt

`DisplayMode.management.visibleFields` 宣告包含 `updatedAt`，但 `BookView.create()` management 分支未產出此欄位。Book entity 目前無 `updatedAt` 固定欄位（PROP-007 tag-based 模型中 `updated_at` 在 DB 層，未暴露至 entity）。

- **影響**：management 模式無法顯示最後更新時間
- **建議**：評估是否將 `updatedAt` 加入 Book entity，或從 ModificationHistory 最後一筆記錄推導

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-05: 雙模式書庫展示系統

## 相關規格

- SPEC-007: 借閱管理規格
