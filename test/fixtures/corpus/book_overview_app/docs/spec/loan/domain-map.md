---
id: DOMAIN-MAP-loan
domain: "loan"
source_specs: [SPEC-007]
related_usecases: [UC-06]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — loan

> 產出來源：0.38.1-W5-002。

## 1. 目的與 UC / DDD 正交關係

loan 在 spec 有獨立目錄（docs/spec/loan/），但程式碼實作為 library domain 的子功能（所有借閱程式碼在 `lib/domains/library/` 下）。本 domain-map 記錄此歸屬關係並指向 library domain-map 對應 bundle。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：library domain 的子功能，非獨立 domain。

借閱功能的所有程式碼位於 `lib/domains/library/`：
- BookLoan VO：`lib/domains/library/value_objects/book_loan.dart`
- LoanType 列舉：`lib/domains/library/enums/loan_type.dart`
- LendingService/Impl：`lib/domains/library/services/lending_service*.dart`
- LoanReminderService：`lib/domains/library/services/loan_reminder_service.dart`
- 借閱事件：`lib/domains/library/events/book_loan_*.dart`
- LendingViewModel：`lib/presentation/library/lending_viewmodel.dart`

**依賴方向**：
- BookLoan 為 Book aggregate 的 VO（Book.activeLoan 欄位）
- LendingServiceImpl 依賴 BookRepository + IEventBus

## 3. Bundle 界定表

見 `docs/spec/library/domain-map.md` §3 中以下 bundle（實作狀態依 library domain-map §3 該 bundle 列所載）：
- **BookLoan**（supporting VO）— 已實作
- **LendingService**（domain service）— 已實作
- **LoanReminderService**（domain service）— 已實作

**資料契約文件引用連結**：`docs/spec/loan/SPEC-015-loan-data-contract.md`（0.38.1-W10-003）。持久化為雙載體分工：`books.active_loan`（現行借閱，延期/備註僅寫此處）+ `book_loans` 歷史列（建立時點快照），語意見 SPEC-015 A.2。

### Bundle 不變式清單（per-bundle）

見 `docs/spec/library/domain-map.md` §3 不變式清單中 BookLoan / LendingService 條目。

## 4. 邊界決策

### 4.1 loan 為 library 子功能而非獨立 Domain

一本書同時最多一筆活躍借閱（一對一），BookLoan 為 Book aggregate 的內嵌 VO。不需獨立 aggregate 和 repository。借閱操作透過 Book 聚合根方法（createLoan / markLoanAsReturned）執行。

SPEC-007 depends_on_domains 標記 `[library]`，與此一致。

## 5. 對實作票的切分指引

見 `docs/spec/library/domain-map.md` §5「借閱功能修改」行（LendingService + BookLoan VO + Book.createLoan）。單一 CRUD 操作（createLoan / markAsReturned / extendDueDate）為一張 ticket。

## 6. 觀察到的技術債（待追蹤）

見 `docs/spec/library/domain-map.md` §6 第三項（library domain import book_info 和 version_management 耦合度評估）。loan 本身無獨立技術債。

## 7. FR → Bundle 覆蓋對照

全部 FR 由 library domain-map 覆蓋：

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（BookLoan 資料模型） | BookLoan VO | library domain |
| FR-2（借閱類型） | BookLoan VO（LoanType） | library domain |
| FR-3（借閱操作） | BookLoan VO | library domain |
| FR-4（計算屬性） | BookLoan VO | library domain |
| FR-5（借閱服務） | LendingService | library domain |
| FR-6（提醒服務） | LoanReminderService | library domain |
| FR-7（借閱事件） | LendingService（事件發佈） | library domain |
| FR-8（序列化） | BookLoan VO | library domain |
| FR-9（UI 元件） | presentation（非 domain） | presentation |
| FR-10（ViewModel） | presentation（非 domain） | presentation |
| FR-11（Book 聚合根方法） | Book aggregate（library） | library domain |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補資料契約文件引用（loan 無獨立持久化，W10-003 分冊產出後回填 SPEC 編號；template 2.2.0）
