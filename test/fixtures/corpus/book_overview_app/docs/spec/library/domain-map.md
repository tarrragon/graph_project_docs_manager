---
id: DOMAIN-MAP-library
domain: "library"
source_specs: [SPEC-006, SPEC-011, SPEC-013]
related_usecases: [UC-02, UC-05, UC-06, UC-11]
created: "2026-07-23"
updated: "2026-07-26"
---

# Domain Map — library

> 產出來源：0.38.1-W5-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。

## 1. 目的與 UC / DDD 正交關係

library 是本專案的核心 domain，管理書籍實體（Book 聚合根）、雙模式展示、標籤系統、借閱功能、搜尋篩選、批次操作與編輯復原。所有其他業務 domain（search / scanner / export / import / synchronization / version_management）皆依賴 library 的 Book 聚合根和 BookRepository 介面。

核心準則：domain 層保持純——無 I/O、無 UI 形狀、對顯示偏好與框架一無所知。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：多 aggregate（Book + Tag 樹）+ command-side 協調

```
presentation (LibraryDisplayViewModel / LendingViewModel / TagManagement)
        │
read-model（BookView 投影、SearchCriteria、LibraryFilter）
        │
kernel（BookSearchEngine 模糊/精確搜尋）    domain service（LendingServiceImpl / TagManagementService / BookEditingService / LibraryManagementService）
        │                                          │
   +---------+                              +------+------+
   │         │                              │             │
Book aggregate  Tag aggregate（by-id 參照 via bookTags）
   ▲              ▲
   │              │
 data（SqliteBookRepository / TagRepository impl）
```

**依賴方向底線**：
- library domain 不得 import data / presentation / UI 框架。已驗證：domain 層 import 僅 `lib/core/`（errors，應用核心層）、book_info（BookEnrichmentData）、version_management（版本關聯）。library ↔ version_management 為雙向依賴，需關注是否應透過介面隔離（見 §6 技術債）。
- Book aggregate 與 Tag aggregate 透過 bookTags（List<BookTag>）by-value 嵌入，非 by-id 參照。此為設計決策：tag 是 Book 的內嵌 VO 而非獨立 aggregate（見 §4.1）。
- read-model（BookView）依賴 aggregate（Book），不反向依賴。
- domain service 透過 DI 依賴 BookRepository / TagRepository 介面。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| Book | aggregate root | Book 聚合根（不可變 Equatable）、BookId / BookTitle / BookCover / BookProgress（VO）、BookStatus 狀態機、copyWith | 衍生計算、持久化 | `lib/domains/library/entities/` + `value_objects/` | unit：狀態轉換守衛、copyWith 不可變性、tag 推導屬性 | 已實作 | N/A |
| BookTag | supporting VO | BookTag（categoryId + value + isPrimary）、TagCategoryIds 常數、系統 tag 分類定義 | tag 樹 CRUD 操作 | `lib/domains/library/value_objects/` + `constants/` | unit：validated 工廠驗證、primary 語意 | 已實作 | N/A |
| BookLoan | supporting VO | BookLoan（7 欄位借閱記錄）、LoanType 列舉、計算屬性（isOverdue/isDueSoon/remainingDays）| 借閱服務邏輯 | `lib/domains/library/value_objects/` + `enums/` | unit：日期計算、狀態判定、不可變操作 | 已實作 | N/A |
| DisplayMode | supporting VO | DisplayMode 列舉（simple/management）、visibleFields 定義 | BookView 投影實作 | `lib/domains/library/enums/` | unit：欄位清單完整性 | 已實作 | N/A |
| BookView | read-model | BookView 投影（fields Map + mode）、Book.getViewForMode 入口 | aggregate 內部狀態 | `lib/domains/library/value_objects/` | unit：各模式投影欄位正確性 | 已實作 | N/A |
| ImportanceTier | supporting VO | 7 級重要程度（1-7）、colorCode、比較方法 | UI 顏色渲染 | `lib/domains/library/value_objects/` | unit：fromValue 邊界（0/8 回 null）、比較 | 已實作 | N/A |
| ReadingStatus | supporting VO | 6 狀態列舉 + fromString 解析（含 snake_case alias）| UI 顯示文字 | `lib/domains/library/enums/` | unit：fromString 容錯（null/空/未知→notStarted） | 已實作 | N/A |
| BookReadingInfo | read-model | 閱讀進度 + 狀態一致性（100%↔finished 雙向） | 閱讀速度計算 | `lib/domains/library/value_objects/` | unit：狀態轉換一致性驗證 | 已實作 | N/A |
| SourceType + Platform | supporting VO | 來源類型（digital/physical/borrowed）+ 9 平台列舉 | 來源顯示名稱（presentation） | `lib/domains/library/enums/` | unit：isDigital/isPhysical 正確性 | 已實作 | N/A |
| BookSearchEngine | domain kernel（共享） | 搜尋引擎 + 搜尋策略（Exact/Fuzzy/Hybrid）+ FilterManager + FilterRegistry | 外部 API 搜尋 | `lib/domains/library/services/` + `strategies/` + `filters/` | unit：各策略命中率、多條件組合 | 已實作 | N/A |
| TagManagementService | domain service | listTags/createTag/renameTag/moveTag/mergeTags/deleteTag/findBooksByTag | tag 樹 UI 渲染 | `lib/domains/library/services/` | unit + integration：循環檢測、鎖定保護、同名重複 | 已實作 | N/A |
| LendingService | domain service | createLoan/markAsReturned/extendDueDate/updateNotes + 查詢方法 + 4 事件（LOAN.CREATED/RETURNED/EXTENDED/NOTES.UPDATED）| UI 表單 | `lib/domains/library/services/` | unit + integration：狀態前置條件、事件發佈 | 已實作 | N/A |
| LoanReminderService | domain service | shouldRemind/getReminderMessage/getLoansNeedingReminder | 通知推播（infra） | `lib/domains/library/services/` | unit：逾期/即將到期篩選 | 已實作 | N/A |
| BookEditingService | domain service（含 session 狀態：EditSession + undo/redo 堆疊） | Command 模式（EditCommand/UpdateBookCommand/DeleteBookCommand/BatchEditCommand）+ _activeSessions Map + EditCommandInvoker（_history + _currentIndex）| UI 編輯表單 | `lib/domains/library/services/` + `commands/` | unit：undo/redo 堆疊正確性、session 生命週期 | 已實作 | N/A |
| LibraryManagementService | domain service | 批次操作（selectBooks/performBatchOperation/generateStatistics）| UI 選取互動 | `lib/domains/library/services/` | unit + integration：批次選取邏輯 | 已實作 | N/A |
| LibraryService / BookService | domain service | 書庫層級 CRUD + 統計 + ISBN 搜尋 | 持久化細節 | `lib/domains/library/services/` | unit + integration | 已實作 | N/A |
| BookRepository | 非 domain（infrastructure） | BookRepository 介面：BaseBookRepository + ExtendedBookRepository + BookQueryPort + watchBooks 觀測出口 | 實作細節（SQLite） | `lib/domains/library/repository/` | repository test | 已實作 | `docs/spec/library/SPEC-014-library-data-contract.md` |
| TagRepository | 非 domain（infrastructure） | TagRepository 介面：tag CRUD + 樹操作介面 | 實作細節 | `lib/domains/library/repository/` | repository test | 已實作 | `docs/spec/library/SPEC-014-library-data-contract.md` |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| Book | BookId 建立後不可變更；所有狀態變更透過 copyWith 回傳新實例；markAsApiEnriched 冪等 |
| BookTag | validated 工廠對非法值拋 ValidationException；同分類 isPrimary 最多一個 |
| BookLoan | sourceName trim 後不可為空；dueDate 不得早於 loanDate（允許同日，`book_loan.dart:41` `dueDate.isBefore(actualLoanDate)` 才拋錯）；不可重複歸還（StateError）；延期新日期不得早於現有 dueDate（允許相等，`book_loan.dart:170` 同型判定） |
| BookView | simple 模式投影 3 欄位（cover/title/source）；management 模式投影含 id/title/author/isbn 等完整欄位 |
| BookReadingInfo | 100% 進度必配 finished 狀態（雙向一致性）；completedAt 不可早於 startedAt |
| BookSearchEngine | 多條件搜尋結果為各條件交集 |
| LendingService | 一本書同時最多一筆活躍借閱 |
| ImportanceTier | fromValue 非 1-7 回 null 不 throw |
| ReadingStatus | fromString null/空/未知→notStarted |
| BookStatus | 狀態轉換由 canTransitionTo 守衛；initial 可直接轉 available |

## 4. 邊界決策

### 4.1 Tag 為 Book 內嵌 VO 而非獨立 Aggregate

BookTag 以 List<BookTag> 嵌入 Book aggregate（PROP-007 everything-as-tags 模式）。Tag 有兩個面向：(1) 作為 Book 屬性是 VO——Book 持有 tag 值的副本，非 by-id 參照；(2) 作為 tag 樹結構，TagManagementService 透過 TagRepository 執行獨立 CRUD（createTag/renameTag/moveTag/mergeTags/deleteTag）。兩者共存：tag 樹管理有獨立持久化，但 Book 內的 tag 值遵循 Book aggregate 的交易邊界。決策保留嵌入 VO 模式，因 Book 端操作（讀取 tag、按 tag 篩選）頻率遠高於 tag 樹結構操作。

### 4.2 Loan 為 library 子功能而非獨立 Domain

BookLoan 為 Book aggregate 的 VO（activeLoan 欄位），借閱操作透過 Book 聚合根方法（createLoan/markLoanAsReturned）執行。spec loan 有獨立目錄但程式碼在 library domain 內。依據：一對一關係（一本書最多一筆活躍借閱），不需獨立 aggregate。

### 4.3 BookSearchEngine 為 domain kernel

被 LibraryManagementService（批次查詢）和 AdvancedSearchService（進階搜尋）共同消費，符合 kernel 判準（被 2+ 消費者使用的核心計算）。

### 4.4 BookEditingService 保留 domain service 分類

BookEditingService 持有 session 狀態（_activeSessions Map + EditCommandInvoker 的 undo/redo 堆疊），符合 process manager 的「有狀態長期協調」特徵。保留 domain service 分類的依據：session 狀態為執行期記憶體暫態（非持久化），不涉及跨 aggregate 補償邏輯，生命週期隨編輯 UI 開關而非跨 session 延續。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| Book 聚合根修改 | domain | 按 §3 Book bundle；狀態機變更須同步 canTransitionTo |
| Tag 系統修改 | domain | TagManagementService bundle + BookTag VO。粒度：單一 CRUD 操作（createTag / renameTag / moveTag / mergeTags / deleteTag）為一張 ticket |
| 借閱功能修改 | domain | LendingService + BookLoan VO + Book.createLoan。粒度：單一 CRUD 操作（createLoan / markAsReturned / extendDueDate）為一張 ticket |
| 搜尋篩選修改 | domain | BookSearchEngine kernel + 策略/篩選器 |
| Repository 實作 | data | 持久化細節屬 data 層，不混入 domain |
| 展示模式修改 | presentation | BookView + DisplayMode 在 domain 定義投影，UI 在 presentation 消費 |

## 6. 觀察到的技術債（待追蹤）

- BookView management 模式缺 loanInfo/notes/updatedAt 欄位（SPEC-006 GAP-1/GAP-3）
- BookView readingProgress 值為 readingStatus.name 而非進度百分比（SPEC-006 GAP-2）
- library domain import book_info 和 version_management，耦合度可評估是否透過介面隔離

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| SPEC-006 FR-1（書籍資料模型） | Book aggregate + BookTag VO | domain |
| SPEC-006 FR-2（雙模式展示） | DisplayMode + BookView | domain（VO + read-model） |
| SPEC-006 FR-3（重要程度） | ImportanceTier | domain（VO） |
| SPEC-006 FR-4（閱讀狀態） | ReadingStatus + BookReadingInfo | domain（VO + read-model） |
| SPEC-006 FR-5（書籍狀態機） | Book aggregate（BookStatus） | domain |
| SPEC-006 FR-6（來源與平台） | SourceType + Platform | domain（VO） |
| SPEC-006 FR-7（標籤系統） | TagManagementService | domain service |
| SPEC-006 FR-8（搜尋與篩選） | BookSearchEngine kernel | domain kernel |
| SPEC-006 FR-9（批次操作） | LibraryManagementService | domain service |
| SPEC-006 FR-10（編輯與復原） | BookEditingService | domain service |
| SPEC-006 FR-11（書籍服務層） | LibraryService / BookService | domain service |
| SPEC-006 FR-12（Repository 介面） | BookRepository / TagRepository | infrastructure 介面 |
| SPEC-011 BR-1~4（watchBooks 契約） | BookRepository（觀測出口） | infrastructure 介面 |
| SPEC-013 FR-013-01~19（標籤管理 UI） | presentation（非 domain） | TagManagement 頁面 |
| SPEC-007 FR-1~11（借閱管理） | BookLoan VO + LendingService + LoanReminderService | domain |

---

**Last Updated**: 2026-07-26 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（BookRepository/TagRepository 連結 SPEC-014，其餘 N/A；template 2.2.0）| 0.38.1-W11-004 校正 BookLoan 不變式 dueDate 與延期兩條為含等於（對齊 `book_loan.dart:41` / `:170` 實作）
