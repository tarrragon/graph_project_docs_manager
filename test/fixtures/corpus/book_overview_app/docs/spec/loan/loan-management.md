---
id: SPEC-007
title: "借閱管理規格"
status: draft
source_proposal: null
created: "2026-03-30"
updated: "2026-06-20"
version: "3.0"
owner: ""

domain: loan
subdomain: null

related_usecases: [UC-06]
related_specs: [SPEC-006]
implements_requirements: [TC-42, TC-43, TC-44, TC-45, TC-49, TC-53, TC-54, TC-55, TC-60]
depends_on_domains: [library]
---

# 借閱管理規格

## 概述

定義書籍借閱與歸還的狀態管理、借閱記錄追蹤與逾期提醒機制。借閱功能以簡化設計（7 欄位）實作，作為 library domain 的子功能，透過 `BookLoan` Value Object 和 `LendingService` 管理借閱生命週期。

## 架構定位

借閱功能不是獨立 domain，而是 library domain 的子功能：

| 元件 | 位置 | 說明 |
|------|------|------|
| BookLoan | lib/domains/library/value_objects/book_loan.dart | 借閱記錄 Value Object |
| LoanType | lib/domains/library/enums/loan_type.dart | 借閱類型列舉 |
| LendingService | lib/domains/library/services/lending_service.dart | 借閱操作服務介面 |
| LendingServiceImpl | lib/domains/library/services/lending_service_impl.dart | 借閱操作服務實作 |
| LoanReminderService | lib/domains/library/services/loan_reminder_service.dart | 提醒服務 |
| Loan Events | lib/domains/library/events/book_loan_*.dart | 借閱事件（4 個） |
| LendingViewModel | lib/presentation/library/lending_viewmodel.dart | ViewModel（Riverpod Notifier） |
| LoanFormSheet | lib/presentation/library/widgets/loan_form_sheet.dart | 借閱表單（底部彈出） |
| LoanInfoCard | lib/presentation/library/widgets/loan_info_card.dart | 借閱資訊卡片 |
| LoanStatusIndicator | lib/presentation/library/widgets/loan_status_indicator.dart | 狀態指示器 |

Book 聚合根持有 `activeLoan: BookLoan?` 欄位，借閱狀態由 `BookStatus.lentOut` 表達。一本書同一時間最多只能有一筆活躍借閱。

---

## 功能需求 (FR)

### FR-1: BookLoan 資料模型（簡化設計）

7 欄位設計（notes 為選填，核心 6 欄位）：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| bookId | BookId | 是 | 關聯書籍 |
| loanType | LoanType | 是 | borrowedFrom / lentTo |
| sourceName | String | 是 | 借出/借入對象姓名（trim 後不可為空） |
| loanDate | DateTime | 是 | 借閱日期（預設為當前時間） |
| dueDate | DateTime | 是 | 到期日（必須在 loanDate 之後） |
| returnedDate | DateTime? | 否 | 歸還日期（null = 進行中） |
| notes | String? | 否 | 備註（trim 後為空則存 null） |

工廠方法：`BookLoan.create({bookId, loanType, sourceName, dueDate, loanDate?, notes?})`，驗證 sourceName 非空 + dueDate 在 loanDate 之後。

### FR-2: 借閱類型

`LoanType` 列舉（`lib/domains/library/enums/loan_type.dart`）：

| 值 | 說明 | 便利屬性 |
|------|------|------|
| borrowedFrom | 從他人借來 | isBorrowed = true |
| lentTo | 借給他人 | isLent = true |

提供 `displayName`（中文：「借來的」/「借出的」）和 `LoanTypeExtension.fromString()` 解析（支援 snake_case 和 camelCase）。

### FR-3: 借閱操作

BookLoan 為不可變物件，所有操作產生新實例：

| 方法 | 說明 | 約束 |
|------|------|------|
| markAsReturned(DateTime) | 標記歸還 | 不可對已歸還的借閱操作（StateError）；歸還日期必須在借閱日期之後（ArgumentError） |
| extendDueDate(DateTime) | 延長到期日 | 新到期日必須在現有到期日之後（ArgumentError）；不可對已歸還的借閱操作（StateError） |
| updateNotes(String) | 更新備註 | trim 後為空存 null |

### FR-4: 計算屬性

| 屬性 | 型別 | 說明 |
|------|------|------|
| isReturned | bool | returnedDate != null |
| isActive | bool | !isReturned |
| isOverdue | bool | 未歸還且 DateTime.now() 已超過 dueDate |
| isDueSoon | bool | 未歸還、未逾期且 remainingDays <= 3 |
| overdueDays | int | 逾期天數（未逾期回傳 0） |
| remainingDays | int | 剩餘天數（純日期計算，忽略時間部分；已歸還或逾期回傳 0） |
| daysUntilDue | int | 距到期天數（可為負數表示逾期；正值部分天數向上取整） |
| loanDays | int | 已借天數（endDate 為 returnedDate 或 now） |
| statusDescription | String | 狀態文字：「已歸還」/「已過期 N 天」/「即將到期 (N 天)」/「借閱中 (剩餘 N 天)」 |
| borrowerName | String | 等同 sourceName |
| sourceDescription | String | 「從 {sourceName} 借來」或「借給 {sourceName}」 |

### FR-5: 借閱服務

#### 5.1 LendingService 介面（抽象類別）

| 方法 | 簽名 | 說明 |
|------|------|------|
| createLoan | `Future<BookLoan> createLoan({required String bookId, required LoanType loanType, required String sourceName, required DateTime dueDate, DateTime? loanDate, String? notes})` | 建立借閱 |
| markAsReturned | `Future<BookLoan> markAsReturned({required String loanId, DateTime? returnDate})` | 標記歸還 |
| extendDueDate | `Future<BookLoan> extendDueDate({required String loanId, required DateTime newDueDate})` | 延長到期日 |
| updateNotes | `Future<BookLoan> updateNotes({required String loanId, required String notes})` | 更新備註 |
| getActiveLoansByBook | `Future<List<BookLoan>> getActiveLoansByBook(String bookId)` | 查詢書籍進行中借閱 |
| getDueSoonLoans | `Future<List<BookLoan>> getDueSoonLoans({int daysThreshold = 3})` | 查詢即將到期借閱 |
| getOverdueLoans | `Future<List<BookLoan>> getOverdueLoans()` | 查詢逾期借閱 |

#### 5.2 LendingServiceImpl 實作

依賴注入：

| 依賴 | 型別 | 用途 |
|------|------|------|
| _bookRepository | BookRepository | 書籍 CRUD |
| _eventBus | IEventBus | 事件發佈 |

方法行為：

| 方法 | 流程 | 事件 | 異常 |
|------|------|------|------|
| createLoan | (1) findById 驗證書籍存在 (2) hasActiveLoan 檢查 (3) BookLoan.create (4) book.createLoan 更新聚合根 (5) updateBook 持久化 (6) emit LOAN.CREATED | BookLoanCreatedEvent | BusinessException.notFound / ErrorCode.activeLoanExists / ArgumentError |
| markAsReturned | (1) _findBookByLoanId (2) activeLoan.markAsReturned (3) copyWith(activeLoan: null) (4) updateBook (5) emit LOAN.RETURNED | BookLoanReturnedEvent | BusinessException(loanNotFound) / StateError |
| extendDueDate | (1) _findBookByLoanId (2) activeLoan.extendDueDate (3) copyWith(activeLoan: extended) (4) updateBook (5) emit LOAN.EXTENDED | BookLoanExtendedEvent | BusinessException(loanNotFound) / ArgumentError / StateError |
| updateNotes | (1) _findBookByLoanId (2) activeLoan.updateNotes (3) copyWith (4) updateBook (5) emit LOAN.NOTES.UPDATED | BookLoanNotesUpdatedEvent | BusinessException(loanNotFound) |
| getActiveLoansByBook | findById; activeLoan 有值則回傳 [activeLoan]，否則 [] | 無 | 無 |
| getDueSoonLoans | getAllBooks; 篩選 isActive and not isOverdue and remainingDays <= threshold and remainingDays > 0 | 無 | 無 |
| getOverdueLoans | getAllBooks; 篩選 isOverdue | 無 | 無 |

`_findBookByLoanId(String loanId)`: 遍歷所有書籍，以 `book.activeLoan.toString() == loanId` 比對。

### FR-6: 提醒服務

`LoanReminderService`（純函式服務，無狀態依賴）：

| 方法 | 簽名 | 說明 |
|------|------|------|
| shouldRemind | `bool shouldRemind(BookLoan loan)` | 逾期或即將到期時回傳 true |
| getReminderMessage | `String getReminderMessage(BookLoan loan)` | 產生提醒訊息（含 bookId 和天數） |
| getLoansNeedingReminder | `List<BookLoan> getLoansNeedingReminder(List<BookLoan> loans)` | 篩選需提醒的借閱 |
| getOverdueLoans | `List<BookLoan> getOverdueLoans(List<BookLoan> loans)` | 篩選逾期借閱 |
| getDueSoonLoans | `List<BookLoan> getDueSoonLoans(List<BookLoan> loans)` | 篩選即將到期且未逾期的借閱 |

### FR-7: 借閱事件

所有事件繼承 `DomainEvent`，提供 `toJson()` 和 `toString()` 方法。

| 事件類別 | eventType | 欄位 |
|---------|-----------|------|
| BookLoanCreatedEvent | LOAN.CREATED | bookId: String, loanId: String, loanType: LoanType, sourceName: String, dueDate: DateTime |
| BookLoanReturnedEvent | LOAN.RETURNED | bookId: String, loanId: String, returnDate: DateTime |
| BookLoanExtendedEvent | LOAN.EXTENDED | bookId: String, loanId: String, oldDueDate: DateTime, newDueDate: DateTime |
| BookLoanNotesUpdatedEvent | LOAN.NOTES.UPDATED | bookId: String, loanId: String, notes: String? |

所有事件繼承 `DomainEvent` 的 `occurredAt: DateTime` 和 `eventId: String`。

### FR-8: 序列化

| 方法 | 時間格式 | 用途 | 欄位 |
|------|---------|------|------|
| toJson() | millisecondsSinceEpoch | 本地 SQLite 儲存 | bookId, loanType, sourceName, loanDate, dueDate, returnedDate?, notes? |
| fromJson() | millisecondsSinceEpoch | 本地 SQLite 讀取 | 同上（loanType 預設 borrowedFrom） |
| toInterchangeJson() | ISO 8601 | 跨平台傳輸（匯出） | loanedTo (=sourceName), loanedAt (=loanDate), dueAt (=dueDate) |
| fromInterchangeJson() | ISO 8601 / millisecondsSinceEpoch / null 回退 now | 跨平台傳輸（匯入） | loanedTo 缺失回傳 null；dueAt 缺失回退 loanDate；loanType 固定 lentTo |

交換格式限制：loanType / returnedDate / notes 不進交換格式（wire 不承載）。

### FR-9: UI 元件

#### 9.1 LoanFormSheet（底部表單）

建構參數：

| 參數 | 型別 | 說明 |
|------|------|------|
| bookId | String | 書籍 ID |
| existingLoan | BookLoan? | 既有借閱（null 為新建模式） |
| onSave | Function | 儲存回呼 |
| onCancel | Function | 取消回呼 |

表單欄位：

| 欄位 | 控件 | 驗證 |
|------|------|------|
| 借閱類型 (_selectedLoanType) | Chip 選擇器 | 必選 |
| 對象姓名 (_sourceNameController) | 文字輸入 | 必填，trim 後非空 |
| 借閱日期 (_loanDate) | 日期選擇器 | 預設今天 |
| 到期日 (_dueDate) | 日期選擇器 | 必填，上限 365 天 |
| 備註 (_notesController) | 多行文字輸入 | 選填 |

支援建立和編輯模式（編輯模式預填既有值）。內部方法：`_validateForm()`, `_submitForm()`, `_selectLoanDate()`, `_selectDueDate()`。

#### 9.2 LoanInfoCard（資訊卡片）

建構參數：

| 參數 | 型別 | 說明 |
|------|------|------|
| loan | BookLoan | 借閱記錄 |
| isExpanded | bool | 是否展開 |
| onToggleExpand | Function | 展開/收起切換 |
| onExtendDueDate | Function | 延期回呼 |
| onMarkReturned | Function | 歸還回呼 |
| onEditNotes | Function | 編輯備註回呼 |

可展開式卡片：摺疊時顯示來源描述 + 到期日 + 狀態指示器；展開後顯示所有欄位和操作按鈕。

#### 9.3 LoanStatusIndicator（狀態指示器）

建構參數：

| 參數 | 型別 | 說明 |
|------|------|------|
| loan | BookLoan | 借閱記錄 |
| compact | bool | 是否精簡模式（僅圖示） |
| showLabel | bool | 是否顯示文字 |

顏色規則：

| 剩餘天數 | 顏色 | 說明 |
|---------|------|------|
| >= 7 天 | 綠色 | 安全 |
| 3-6 天 | 黃色 | 注意 |
| 1-2 天 | 橘色 | 即將到期 |
| <= 0 天 | 紅色 | 逾期 |

已歸還時隱藏。

### FR-10: Presentation 層 ViewModel

`LendingViewModel extends Notifier<LendingState>`（Riverpod 3.0）

依賴：`LendingService`（透過 `ref.watch(lendingServiceProvider)` 注入）

Provider: `lendingViewModelProvider = NotifierProvider<LendingViewModel, LendingState>(LendingViewModel.new)`

#### LendingState

| 欄位 | 型別 | 預設 | 說明 |
|------|------|------|------|
| loans | List\<BookLoan\> | [] | 借閱清單 |
| filter | LoanFilter | LoanFilter.all | 篩選條件 |
| isLoading | bool | false | 載入中狀態 |
| error | String? | null | 錯誤訊息 |

計算屬性：`filteredLoans` — 依 filter 篩選 loans（all / active / overdue / dueSoon / returned）。

`LoanFilter` 列舉：`all`, `active`, `overdue`, `dueSoon`, `returned`。

#### ViewModel 方法

| 方法 | 簽名 | 說明 |
|------|------|------|
| loadLoans | `Future<void> loadLoans()` | 載入所有借閱（目前只取 overdue + dueSoon） |
| createLoan | `Future<void> createLoan({bookId, loanType, sourceName, dueDate, loanDate?, notes?})` | 建立借閱後重新載入 |
| markAsReturned | `Future<void> markAsReturned(String loanId)` | 標記歸還後重新載入 |
| extendDueDate | `Future<void> extendDueDate({loanId, newDueDate})` | 延期後重新載入 |
| updateNotes | `Future<void> updateNotes({loanId, notes})` | 更新備註後重新載入 |
| setFilter | `void setFilter(LoanFilter filter)` | 設定篩選條件 |

### FR-11: Book 聚合根借閱方法

Book 實體提供借閱相關方法（在 `lib/domains/library/entities/book.dart`）：

| 方法/屬性 | 簽名 | 說明 |
|----------|------|------|
| activeLoan | `BookLoan?` (field) | 當前活躍借閱 |
| hasActiveLoan | `bool` (getter) | activeLoan != null |
| isBorrowed | `bool` (getter) | hasActiveLoan and loanType == borrowedFrom |
| isLentOut | `bool` (getter) | hasActiveLoan and loanType == lentTo |
| createLoan | `Book createLoan({required String loanType, required String sourceName, required DateTime dueDate, DateTime? loanDate, String? notes})` | 建立借閱並回傳新 Book（hasActiveLoan 時拋 StateError） |
| markLoanAsReturned | `Book markLoanAsReturned(DateTime returnDate)` | 標記歸還 |
| extendLoanDueDate | `Book extendLoanDueDate(DateTime newDueDate)` | 延期 |
| updateLoanNotes | `Book updateLoanNotes(String notes)` | 更新備註 |

---

## 業務規則

### BR-1: 資料驗證規則

| 規則 | 驗證時機 | 違反結果 |
|------|---------|---------|
| sourceName trim 後不可為空 | BookLoan.create | ArgumentError |
| dueDate 必須在 loanDate 之後 | BookLoan.create | ArgumentError |
| returnDate 必須在 loanDate 之後 | markAsReturned | ArgumentError |
| 不可重複歸還（isReturned == true 時） | markAsReturned | StateError |
| 延期新日期必須在現有 dueDate 之後 | extendDueDate | ArgumentError |
| 不可延期已歸還借閱 | extendDueDate | StateError |
| 一本書同時只能有一筆活躍借閱 | LendingServiceImpl.createLoan | BusinessException(activeLoanExists) |
| 建立借閱時書籍必須存在 | LendingServiceImpl.createLoan | BusinessException.notFound |

### BR-2: 狀態閾值

| 閾值 | 值 | 定義位置 |
|------|-----|---------|
| 即將到期 | <= 3 天 | BookLoan.isDueSoon |
| 最長借閱期 | 365 天 | UI 層（LoanFormSheet） |
| 逾期起算 | daysUntilDue <= 0 | BookLoan.isOverdue |

### BR-3: 不可變性

BookLoan 為 Value Object（extends Equatable），所有操作回傳新實例，不修改原始物件。

### BR-4: 資料一致性觸發器（DB 層）

| 觸發器 | 說明 |
|--------|------|
| ensure_borrowed_loan_consistency | 書籍 source_type 更新為 'borrowed' 時，自動 INSERT OR IGNORE 預設借閱記錄（loan_type='borrowed_from', source_name='UNKNOWN_SOURCE', due_date=now+7days） |
| cleanup_borrowed_source_on_loan_delete | 借閱記錄刪除時，自動將 borrowed 類型書籍 source_type 改為 digital（有 platform）或 physical（無 platform） |
| book_loans_update_timestamp | 借閱記錄更新時自動更新 updated_at |

---

## 介面契約

### IC-1: BookLoan（Value Object）

```dart
class BookLoan extends Equatable {
  // 建構（私有）
  const BookLoan._({required bookId, required loanType, required sourceName,
                    required loanDate, required dueDate, returnedDate, notes});

  // 工廠
  factory BookLoan.create({required BookId bookId, required LoanType loanType,
                           required String sourceName, required DateTime dueDate,
                           DateTime? loanDate, String? notes});
  factory BookLoan.fromJson(Map<String, dynamic> json);
  static BookLoan? fromInterchangeJson(BookId bookId, Map<String, dynamic> json);

  // 操作（回傳新實例）
  BookLoan markAsReturned(DateTime returnDate);
  BookLoan extendDueDate(DateTime newDueDate);
  BookLoan updateNotes(String newNotes);

  // 序列化
  Map<String, dynamic> toJson();
  Map<String, dynamic> toInterchangeJson();

  // 計算屬性
  bool get isReturned;
  bool get isActive;
  bool get isOverdue;
  bool get isDueSoon;
  int get overdueDays;
  int get remainingDays;
  int get daysUntilDue;
  int get loanDays;
  String get statusDescription;
  String get borrowerName;
  String get sourceDescription;
}
```

### IC-2: LoanType（Enum + Extension）

```dart
enum LoanType { borrowedFrom, lentTo }

extension LoanTypeExtension on LoanType {
  String get displayName;
  bool get isBorrowed;
  bool get isLent;
  static LoanType fromString(String value);
}
```

### IC-3: LendingService（抽象）

```dart
abstract class LendingService {
  Future<BookLoan> createLoan({required String bookId,
      required LoanType loanType, required String sourceName,
      required DateTime dueDate, DateTime? loanDate, String? notes});
  Future<BookLoan> markAsReturned({required String loanId,
      DateTime? returnDate});
  Future<BookLoan> extendDueDate({required String loanId,
      required DateTime newDueDate});
  Future<BookLoan> updateNotes({required String loanId,
      required String notes});
  Future<List<BookLoan>> getActiveLoansByBook(String bookId);
  Future<List<BookLoan>> getDueSoonLoans({int daysThreshold = 3});
  Future<List<BookLoan>> getOverdueLoans();
}
```

### IC-4: LendingServiceImpl

```dart
class LendingServiceImpl implements LendingService {
  LendingServiceImpl({required BookRepository bookRepository,
                      required IEventBus eventBus});
}
```

### IC-5: LoanReminderService

```dart
class LoanReminderService {
  bool shouldRemind(BookLoan loan);
  String getReminderMessage(BookLoan loan);
  List<BookLoan> getLoansNeedingReminder(List<BookLoan> loans);
  List<BookLoan> getOverdueLoans(List<BookLoan> loans);
  List<BookLoan> getDueSoonLoans(List<BookLoan> loans);
}
```

### IC-6: 事件類別

```dart
class BookLoanCreatedEvent extends DomainEvent {
  BookLoanCreatedEvent({required String bookId, required String loanId,
      required LoanType loanType, required String sourceName,
      required DateTime dueDate});
  String get eventType => 'LOAN.CREATED';
}

class BookLoanReturnedEvent extends DomainEvent {
  BookLoanReturnedEvent({required String bookId, required String loanId,
      required DateTime returnDate});
  String get eventType => 'LOAN.RETURNED';
}

class BookLoanExtendedEvent extends DomainEvent {
  BookLoanExtendedEvent({required String bookId, required String loanId,
      required DateTime oldDueDate, required DateTime newDueDate});
  String get eventType => 'LOAN.EXTENDED';
}

class BookLoanNotesUpdatedEvent extends DomainEvent {
  BookLoanNotesUpdatedEvent({required String bookId, required String loanId,
      String? notes});
  String get eventType => 'LOAN.NOTES.UPDATED';
}
```

---

## 資料模型

### DM-1: book_loans 資料表（SQLite）

```sql
CREATE TABLE book_loans (
  book_id TEXT PRIMARY KEY,
  loan_type TEXT NOT NULL CHECK(loan_type IN ('borrowed_from', 'lent_to')),
  source_name TEXT NOT NULL,
  due_date DATE NOT NULL,
  returned_date DATE,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);
```

索引：

| 索引 | 欄位 |
|------|------|
| idx_book_loans_book_id | book_id |
| idx_book_loans_due_date | due_date |
| idx_book_loans_returned | returned_date |
| idx_book_loans_type | loan_type |

### DM-2: Dart BookLoan 欄位與 DB 映射

| Dart 欄位 | DB 欄位 | 格式差異 |
|-----------|---------|---------|
| bookId (BookId) | book_id (TEXT) | Dart 為 Value Object，DB 為字串 |
| loanType (LoanType enum) | loan_type (TEXT) | Dart 為 enum，DB 為 snake_case 字串 |
| sourceName (String) | source_name (TEXT) | 無 |
| loanDate (DateTime) | 無 DB 欄位 | DB schema 無 loanDate（需求簡化設計） |
| dueDate (DateTime) | due_date (DATE) | Dart millisecondsSinceEpoch，DB DATE |
| returnedDate (DateTime?) | returned_date (DATE) | 同上 |
| notes (String?) | 無 DB 欄位 | DB schema 無 notes（需求簡化設計） |

### DM-3: 交換格式（Interchange JSON）

```json
{
  "loanedTo": "string (sourceName)",
  "loanedAt": "ISO 8601 (loanDate)",
  "dueAt": "ISO 8601 (dueDate)"
}
```

限制：loanType 固定 lentTo、returnedDate / notes 不進交換格式。

---

## 非功能需求 (NFR)

### NFR-1: 不可變性

BookLoan 為 Value Object（Equatable），所有操作回傳新實例。

### NFR-2: 同步

借閱記錄支援跨裝置同步（app-requirements-spec Phase 6）。`toInterchangeJson()` / `fromInterchangeJson()` 提供標準傳輸格式。

### NFR-3: 可觀測性

LendingViewModel 中所有 catch 區塊使用 `AppLogger.errorStatic` 記錄錯誤訊息和元件名稱。

---

## 需求與實作差距

| 需求（app-requirements-spec / UC-06） | 實作狀態 | 差距說明 |
|---------------------------------------|---------|---------|
| 簡化 6 欄位設計（TC-42/43） | 已實作（7 欄位，notes 選填） | DB 為 6 欄位（無 loanDate、無 notes），Dart 為 7 欄位。loanDate 和 notes 僅存在於 Dart 層，未持久化至 DB schema |
| 借出/借來記錄（TC-42/43） | 已實作（LoanType 列舉） | 無差距 |
| 到期日追蹤（TC-44） | 已實作（dueDate + isDueSoon + isOverdue） | 無差距 |
| 歸還標記（TC-45） | 已實作（markAsReturned） | 無差距 |
| 逾期提醒（TC-60） | 已實作（LoanReminderService） | getReminderMessage 使用 bookId.toString() 而非書名，使用者可讀性待改善 |
| 借閱狀態同步（TC-53） | 已實作（InterchangeJson 格式） | 交換格式不承載 loanType / returnedDate / notes，round-trip 資訊有限 |
| 借來源需有借閱記錄（TC-54） | 已實作（DB trigger） | trigger 插入預設 source_name='UNKNOWN_SOURCE'，應用層無對應處理機制提示使用者補全 |
| 刪除借閱時自動清理 source（TC-55） | 已實作（DB trigger） | 無差距 |
| 篩選借閱狀態和到期日（TC-49） | 部分實作 | ViewModel._fetchAllLoans() 只取 overdue + dueSoon，LoanFilter.all 和 LoanFilter.returned 實際無資料支撐 |
| UC-06 6A.1a2 智慧預填常用圖書館 | 未實作 | 替代流程描述的進階功能 |
| UC-06 6B.2a3 聯絡方式整合 | 未實作 | 替代流程描述的進階功能 |
| UC-06 已賣出書籍特殊處理 | 未實作 | UC-06 特殊處理章節描述的功能 |
| UC-06 6c 資料損壞自動修復 | 未實作 | 錯誤恢復機制描述的功能 |
| loanId 查找機制 | 使用 toString() 字串比對 | LendingServiceImpl._findBookByLoanId 遍歷所有書籍，以 activeLoan.toString() 比對 loanId，效能和正確性待驗證 |
| Book.createLoan loanType 參數型別 | String（非 LoanType enum） | Book.createLoan 接收 String loanType，LendingServiceImpl 先將 LoanType enum 轉字串再傳入，存在不必要的型別轉換 |

---

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-06: 借閱管理系統

## 相關規格

- SPEC-006: 雙模式書庫展示規格（管理模式中的 loanInfo 欄位）
