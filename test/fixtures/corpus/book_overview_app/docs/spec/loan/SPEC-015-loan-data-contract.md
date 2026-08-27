---
id: SPEC-015
title: "loan 資料契約（book_loans）"
status: review
source_proposal: null
created: "2026-07-25"
updated: "2026-07-26"
version: "1.2"
owner: "rosemary-project-manager"

domain: loan
subdomain: "data-contract"

related_specs: [SPEC-007, SPEC-014]
---

# loan 資料契約（book_loans）

## 概述

本文件涵蓋 loan domain 的持久化表 `book_loans`（借閱歷史紀錄），承載 `DatabaseSchema`
（`lib/infrastructure/database/database_schema.dart`）DDL 表達不了的設計意圖：毫秒
時間戳語意（本表為全庫唯一 DEFAULT 即毫秒的表）、loan_type 值域與讀取端 fallback
行為、與 `books.active_loan`（SPEC-014）的雙載體分工、交易邊界與錯誤語意現況。
可攜性邊界原則的適用方式：A 區（邏輯契約）在資料庫換引擎後仍成立，照搬即可；
B 區（實作綁定）綁定 SQLite/sqflite，換引擎需依新引擎重寫。

本文件只陳述 schema 與 repository 實作現況及既有設計決策（W5-001 啟用 book_loans
持久化、0.38.1-W10-008 loan_type CHECK），不新增任何未存在的約束。

## 可攜性邊界原則

本文件依「資料庫遷移後是否仍成立」分兩區。判準來源：port/adapter 邊界（repository
介面跨引擎成立的部分歸 A 區，引擎專屬實作歸 B 區）。

| 區塊 | 判準 | 資料庫遷移後 |
|------|------|-------------|
| A 區：邏輯契約 | DB-agnostic，描述業務語意與不變式 | 仍成立，照搬 |
| B 區：實作綁定 | DB-specific，描述特定引擎的實現機制 | 需依新引擎重寫 |

---

## A 區：邏輯契約（DB-agnostic）

### A.1 表/欄位語意

**與 SPEC-007 分工**：SPEC-007（loan-management）聚焦借閱功能行為（建立/歸還/延期/
備註的業務規則）；本節聚焦「欄位的值域/格式/單位/命名邊界約束」。兩者互相引用
同一組欄位，不重複描述功能用途。

#### 毫秒時間戳語意（全庫唯一 DEFAULT 即毫秒的表）

`book_loans` 是全庫 12 表中唯一「DDL DEFAULT 即毫秒」的表（`strftime('%s','now')
* 1000`；其餘表 DEFAULT 為秒，0.38.1-W10-001 重現實驗）。全表時間欄位單位統一為
毫秒 epoch：

| 欄位 | DDL DEFAULT | Repository 寫入路徑 | 有效單位 |
|------|------------|--------------------|---------|
| loan_date / due_date | 無 DEFAULT | 毫秒（`BookLoan.toJson` 約束：所有欄位 `millisecondsSinceEpoch` 以相容 SQLite） | 毫秒 |
| returned_date | 無 DEFAULT | 毫秒（`updateReturnedDate`） | 毫秒 |
| created_at / updated_at | **毫秒**（`strftime('%s','now') * 1000`） | 毫秒（`insertLoan` / `updateReturnedDate` 顯式寫 `DateTime.now().millisecondsSinceEpoch`） | 毫秒（repository 為唯一寫入路徑，DEFAULT 實際不觸發，但 DEFAULT 與寫入路徑單位一致——與 books / master_books 的「DEFAULT 秒、寫入毫秒」漂移形態不同） |

#### book_loans

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | `{book_id}_{插入時毫秒}`（`insertLoan` 產生） | 非空，PK 唯一 | 寫入後不參與讀取還原（`_rowToBookLoan` 不映射 id）；同書同毫秒重複插入才會 PK 衝突，應用層活躍借閱守門（INV-L01）使此情境不發生 |
| book_id | TEXT | 同 books.id | NOT NULL，FK -> books(id) ON DELETE CASCADE | — |
| loan_type | TEXT | `LoanType.name` 字面 | `{'borrowedFrom','lentTo'}`，DDL CHECK（0.38.1-W10-008） | 讀取端 `BookLoan.fromJson` `orElse` 對非法值靜默 fallback 為 `borrowedFrom`（語意翻轉）；CHECK 使非法值在寫入時即顯性失敗（enum 值域 CHECK 採用判定，0.38.1-W10-007） |
| source_name | TEXT | 自由字串（trim 後） | NOT NULL；應用層要求非空白（`BookLoan.create` 驗證） | 借出方或借入方名稱，語意隨 loan_type 翻轉 |
| loan_date | INTEGER | 毫秒 epoch | NOT NULL | 借出日期 |
| due_date | INTEGER | 毫秒 epoch | NOT NULL；建立時 >= loan_date（VO 驗證，INV-L03） | 到期日期。**過時性警示**：延期（`extendDueDate`）只更新 `books.active_loan`，不回寫本欄（A.2 雙載體分工） |
| returned_date | INTEGER，nullable | 毫秒 epoch | NULL = 活躍借閱；非 NULL 時 >= loan_date（VO 驗證） | 歸還日期；`getReturnedLoans` 以 `IS NOT NULL` 篩選 |
| notes | TEXT，nullable | 自由字串 | 無約束 | 備註。**過時性警示**：備註更新（`updateNotes`）不回寫本欄（同 due_date） |
| created_at / updated_at | INTEGER | 毫秒 epoch | NOT NULL | 審計欄位，不參與 entity 還原（`_rowToBookLoan` 不映射）；無 trigger（與 books.updated_at 不同），repository 顯式維護 |

### A.2 狀態責任分層

三類：canonical（正式狀態，唯一寫入來源）／derived（衍生，只能 rebuild、不能反向
修正 canonical）／追蹤欄位（審計用，不參與業務計算）。同一筆資料只能有一個
canonical 來源。

借閱狀態採**雙載體設計**（`books.active_loan` JSON + `book_loans` 歷史表），分工
如下（事實來源：`lending_service_impl.dart` 寫入路徑逐一比對）：

| 欄位/表 | 分層 | 說明 |
|--------|------|------|
| books.active_loan | canonical（當前活躍借閱） | **分層判定歸 SPEC-014 A.2**（`books` 屬 library domain）；本列為 loan 側的分工細節展開。延期（`extendDueDate`）、備註更新（`updateNotes`）**只**寫入此載體；活躍借閱的當前 due_date / notes 唯一權威。查詢活躍借閱（`getActiveLoansByBook`）亦只讀此載體 |
| book_loans（活躍列，returned_date IS NULL） | 追蹤欄位（建立時點快照） | `insertLoan` 於建立時寫入；loan_type / source_name / loan_date 與 canonical 一致，due_date / notes 為插入時點值、延期或備註更新後即過時（現況事實，非缺陷宣告——歷史表定位即建立時點紀錄） |
| book_loans（已歸還列，returned_date IS NOT NULL） | canonical（歸還歷史） | `books.active_loan` 於歸還時清空，歷史查詢（`getReturnedLoans` / `getLoansByBookId`）唯一來源即本表 |

> **讀取警示**：`getLoansByBookId` 回傳的活躍列（若有）due_date / notes 可能過時；
> 需要當前值時應以 `books.active_loan` 為準。此分工僅存於寫入路徑程式碼，本表為
> 首個顯性載體。

### A.3 不變式清單

陳述本身（不含由哪一層保證——歸屬決策見 B.1）。供 `docs/spec/loan/domain-map.md`
「Bundle 不變式清單」小節互相引用（domain-map 補欄由 0.38.1-W10-006 並行處理，
本文件不改 domain-map）。

| 編號 | 不變式 | 對應 domain-map 條目 |
|------|--------|----------------------|
| INV-L01 | 每本書至多一筆活躍借閱（同 book_id 的 returned_date IS NULL 列至多一列）。**邊界**：跨載體失步時不成立——守門讀的是 `books.active_loan`（見 B.1），A.4 已載明雙載體無交易包裹 | `docs/spec/library/domain-map.md` §3 LendingService「一本書同時最多一筆活躍借閱」（本文件補 book_loans 表層的陳述與失步邊界） |
| INV-L02 | loan_type 值域 = `LoanType` enum names（'borrowedFrom' / 'lentTo'），與 enum 定義逐字一致 | 本文件新增（DDL CHECK 承載，0.38.1-W10-008） |
| INV-L03 | 建立時 due_date >= loan_date；歸還時 returned_date >= loan_date | `docs/spec/library/domain-map.md` §3 BookLoan「dueDate 不得早於 loanDate（允許同日）」（該條已於 0.38.1-W11-004 校正為含等於，與本文件 `>=` 及實作 `if (dueDate.isBefore(loanDate)) throw` 三方一致） |
| INV-L04 | 全表時間欄位一律毫秒 epoch（含 DDL DEFAULT `* 1000`） | 本文件新增（schema 註解 + `toJson` 約束註解承載） |
| INV-L05 | returned_date 由 NULL 轉非 NULL 後不可逆（歸還後不可再變更狀態） | `docs/spec/library/domain-map.md` §3 BookLoan「不可重複歸還（StateError）」（本文件補 DB 層無承載的事實） |
| INV-L06 | 雙載體一致性：活躍借閱期間 books.active_loan 為當前狀態唯一權威；book_loans 活躍列僅保證 loan_type / source_name / loan_date 與建立時一致 | 本文件新增（A.2 分工的規範化陳述） |

### A.4 交易邊界

哪些寫入必須一起成立（原子性要求）。不含 isolation level（屬 B 區）。

| 交易邊界 | 涵蓋寫入 | 說明 |
|---------|---------|------|
| 借閱建立 | books.active_loan（`updateBook`）+ book_loans 一列（`insertLoan`） | **現況為兩次獨立 DB 呼叫循序 await，無交易包裹**（`lending_service_impl.dart` `createLoan`）；第二步前中斷會留下「有 active_loan 無歷史列」的不一致（現況事實陳述，非本文件新增約束） |
| 借閱歸還 | books.active_loan 更新 + book_loans 活躍列 returned_date 回填 | 同上，`markAsReturned` 兩次獨立呼叫無交易包裹 |
| 延期 / 備註更新 | 僅 books.active_loan | 單載體單列更新，天然原子；book_loans 不參與（A.2） |
| 歷史列單列操作 | book_loans 單列 | `insertLoan` / `updateReturnedDate` 單語句天然原子 |

### A.5 錯誤語意契約

唯一鍵衝突／外鍵違反／驗證失敗對應哪個 domain 例外，跨資料庫引擎成立（error
translation 邊界）。

| 資料庫錯誤類型 | 對應 domain 例外 | 觸發情境 |
|--------------|------------------|---------|
| PK 衝突（book_loans.id） | **無型別化轉譯**：sqflite `DatabaseException` 原生上拋（`SqliteBookLoanRepository` 全方法無 try-catch 包裝，與 library / version-management repository 的 `StorageException` 包裝模式不同——現況事實） | 同書同毫秒重複插入（INV-L01 守門下不發生） |
| CHECK 違反（loan_type） | 同上，原生 `DatabaseException` 上拋 | 非 enum 值寫入（0.38.1-W10-008 後寫入時即失敗） |
| FK violation（book_id） | 同上 | 書籍不存在時插入借閱 |
| 更新目標不存在（歸還時無活躍列） | **不拋例外**：`updateReturnedDate` 對 0 列更新僅記 `AppLogger.warningStatic` 後靜默返回 | 重複歸還、或 active_loan 與歷史表不一致時 |
| 業務驗證失敗 | `BusinessException.notFound('Book')`（書不存在）／`BusinessException(activeLoanExists)`（已有活躍借閱）／`BusinessException(loanNotFound)`（依 loanId 找不到活躍借閱） | `lending_service_impl.dart` 前置守門，先於任何 DB 寫入 |
| VO 驗證失敗 | `ArgumentError`（名稱空白、日期倒置）／`StateError`（已歸還再操作） | `BookLoan` 工廠與轉換方法 |

### A.6 恢復模型

備份還原後的資料驗證方式。

| 情境 | 驗證方式 |
|------|---------|
| 備份/還原 | 檔案層級複製（整份 DB 檔），非逐表匯出（全庫共用機制，詳述見 SPEC-014 A.6） |
| 完整性驗證 | `DatabaseSchema.integrityChecks` 於 `_onOpen` 執行：`PRAGMA integrity_check` + `PRAGMA foreign_key_check` + `SELECT COUNT(*) FROM book_loans`。**語句會執行但結果未被檢視**，現況無任何違反出口；觸發條件為非測試環境（機制詳述見 SPEC-014 A.6，全庫共用同一實作）。**亦不含**雙載體一致性檢查（books.active_loan 與 book_loans 活躍列的交叉驗證無任何機制承載，現況事實） |
| Seed | 本表無 seed 資料 |

---

## B 區：實作綁定（DB-specific）

> 本區內容綁定 SQLite/sqflite。資料庫遷移時需依新引擎重寫本區，A 區不受影響。

### B.1 保證層歸屬

每條不變式的保證層。本表實際使用三種歸屬：DB 約束 + 應用層／應用層／應用層 +
DDL DEFAULT。歸屬本身是綁定決策，A 區不變式陳述不因換 DB 而變。

歸屬理由欄採預設值 + 例外展開：預設一格帶過，僅有爭議或多層條目才展開理由。

| 不變式編號 | 保證層 | 歸屬理由 |
|-----------|--------|---------|
| INV-L01 | 應用層（間接） | 守門對象為**另一載體**：`createLoan` 檢查的 `book.hasActiveLoan` 讀 `books.active_loan`（`lending_service_impl.dart`），非 `book_loans` 表；`updateReturnedDate` 以 `book_id + returned_date IS NULL` 關閉全部活躍列。因兩載體無交易包裹（A.4），`updateReturnedDate` 失敗或走 0 列 warning 路徑後 `book_loans` 可殘留活躍列，此時 `books.active_loan` 已清空，再次借閱不會被守門攔下，即產生兩列 `returned_date IS NULL`——本表層面無任何機制阻擋。DB 層亦無承載（SQLite 部分唯一索引可表達但現況未建，與 SPEC-014 INV-06 同型態——低價值 DDL 約束不納入，0.38.1-W10-007，本文件不複決） |
| INV-L02 | DB 約束 + 應用層 | DDL CHECK（0.38.1-W10-008）攔寫入；讀取端 fromJson fallback 為殘留防線（CHECK 落地後正常路徑不再觸發） |
| INV-L03 | 應用層 | `BookLoan` VO 驗證；無 DDL 承載 |
| INV-L04 | 應用層 + DDL DEFAULT | 寫入路徑顯式毫秒；DEFAULT `* 1000` 與寫入路徑一致（dormant 但不漂移） |
| INV-L05 | 應用層 | VO `StateError`；DB 不阻止 returned_date 被 UPDATE 改回 NULL |
| INV-L06 | 應用層（流程順序） | `lending_service_impl.dart` 寫入路徑分工；無任何 DB 機制承載，亦無交易包裹（A.4） |

### B.2 邊界行為的引擎機制

| 邊界行為 | 引擎機制 | 說明 |
|---------|---------|------|
| 插入衝突處理 | 無 conflictAlgorithm（sqflite 預設 ABORT） | PK 衝突直接拋 `DatabaseException`；與 books（replace）/ tags（ignore）不同，本表無消解設計 |
| FK 刪除策略 | book_id `ON DELETE CASCADE` | 刪書連動刪除該書全部借閱歷史（含已歸還列）；`PRAGMA foreign_keys=ON`（`_onConfigure`）使 FK 生效 |
| CHECK 違反例外 | `DatabaseException` 無型別化；SQLite conflict resolution 不消解 CHECK violation（0.38.1-W10-007 實證，全庫論證見 SPEC-014 B.2） | 本表無 OR REPLACE / OR IGNORE 路徑，CHECK 一律 ABORT |
| created_at / updated_at 維護 | 無 trigger（與 books.updated_at 的 trigger 模式不同）；repository 顯式寫入毫秒 | DDL DEFAULT `strftime('%s','now') * 1000` 為毫秒，僅在繞過 repository 直接 INSERT 且未帶值時觸發 |
| 索引 | idx_book_loans_book_id / loan_type / due_date / returned_date | `getLoansByBookId`（book_id）、`getReturnedLoans`（returned_date IS NOT NULL）的查詢路徑 |

### B.3 Schema 演進策略與 Seed 資料政策

| 項目 | 決策 | 說明 |
|------|------|------|
| Schema 演進策略 | **pre-1.0 drop+rebuild**（`currentVersion=1`、`migrationScripts={}`） | 沿用全庫既定 ADR（W2-023 ADR-4；詳述見 SPEC-014 B.3，本文件不複決）。loan_type CHECK 已於窗口內落地（0.38.1-W10-008）；1.0 上架後窗口關閉，後續約束補強需 onUpgrade 12 步表重建 |
| migration 治理旗標 | 不要（合法終態，非延後） | 0.38.1-W10-001 全庫單一判定；重新評估載體為本節 |
| Seed 資料政策 | 無 seed | 本表資料全部來自執行期寫入 |

---

## 欄位 × 既有載體對照表

逐欄標「新建／引用既有」，避免與既有載體內容重複。本文件只新建既有載體缺的欄位；
其餘以引用連結取代複寫。

| 欄位/章節 | 承載狀態 | 既有載體 | 說明 |
|----------|---------|---------|------|
| 表/欄位語意（單位/值域/格式） | 部分承載，本文件補值域與過時性警示 | `database_schema.dart` DDL 註解、SPEC-007 功能行為 | 毫秒 DEFAULT 唯一性、活躍列過時性為本文件首創 |
| 雙載體分工（active_loan vs book_loans） | 新建 | 無（僅存於 `lending_service_impl.dart` 寫入路徑程式碼） | A.2 為首個顯性載體 |
| 不變式陳述 | 部分承載，本文件補表層陳述與編號 | `docs/spec/loan/domain-map.md`（補欄由 0.38.1-W10-006 並行處理）、`docs/spec/library/domain-map.md` §3 | INV-L01 / L03 / L05 引用 library domain-map 既有條目（A.3 對應欄）；L02 / L04 / L06 為本文件新增 |
| 契約 ↔ 測試對應 | 已對應 | `docs/traceability.yaml` 第三軸 `data_contract_tests`（0.38.1-W10-005 建立） | 該軸共 23 條涵蓋三冊 INV 編號，其中 INV-L01~L06 屬本文件；以 `spec` 欄消歧同名編號。初查覆蓋分佈（全軸）：covered 7 / partial 7 / gap 8 / no_test_needed 1；補測試由 0.38.1-W10-012 承接 |
| 可攜性分區 / 狀態責任分層 / 交易邊界 / 錯誤語意 / 恢復模型 / 保證層歸屬 | 新建 | 無 | 依模板 |
| Schema 演進策略 | 引用既有 | SPEC-014 B.3（全庫 ADR 詳述） | 本文件僅載 loan 面事實 |

## 適用判準（本文件是否需要撰寫）

依 `data-layer-contract-methodology.md` 兩正交旗標判斷：

| 旗標 | 判定 | 理由 |
|------|------|------|
| 契約文件 | 要 | 0.38.1-W10-001 逐表群判定：loan_type 值域、毫秒單位（與 books 秒不同）、isOverdue 等衍生計算依賴日期語意；雙載體分工僅存於程式碼 |
| migration 治理 | 不要 | 全庫單一判定（0.38.1-W10-001）；合法終態，載體為 B.3 |
| dormant 豁免（如適用） | 不適用 | `book_loans` 有 production 觸達路徑（`SqliteBookLoanRepository` 經 `LendingServiceImpl` 於 `lib/` 內接線），不符 `data-layer-contract-methodology.md` 第 2.1 節豁免前提 |

**分冊自評**（依模板 v1.2.0 分冊判準三條）：

| 判準 | 自評 |
|------|------|
| 1. per-domain 放置 | 符合。`book_loans` 置於 `docs/spec/loan/`，與 library 四表分冊 |
| 2. `domain` 單值上限 | 符合。frontmatter `domain: loan` 單值。本文件述及 `books.active_loan` 屬跨冊引用（分層判定歸 SPEC-014 A.2），非涵蓋範圍擴張 |
| 3. 寫入者群／錯誤語意模式分異即再分冊 | 符合，單表無再分冊需求。與 library 分冊的依據即判準 3：本表錯誤語意模式與 library 明顯分異——`SqliteBookLoanRepository` 全方法無 try-catch，原生 `DatabaseException` 上拋（A.5），library 則統一 `StorageException` 包裝 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-07-25 | 初始版本（0.38.1-W10-003，book_loans 契約） |
| 1.1 | 2026-07-26 | 技術審查修正（0.38.1-W11-002，findings 來源 0.38.1-W11-001）：INV-L01 補跨載體失步邊界、B.1 INV-L01 歸屬改應用層（間接）並註明守門對象為另一載體、INV-L01/L03/L05 對應欄改引用 library domain-map（L03 標註 domain-map 條目待校正）、A.2 active_loan 分層判定改引用 SPEC-014、A.6 完整性驗證改述、對照表引用 traceability.yaml 第三軸、適用判準補 dormant 豁免列與分冊自評、B.1 補歸屬理由慣例句、子代號改可讀敘述 |
| 1.2 | 2026-07-26 | INV-L03 對應欄由「domain-map 條目待校正」改為三方一致陳述（0.38.1-W11-004 已校正 library domain-map BookLoan 條目為含等於） |

---

**Spec Updated**: 2026-07-26 | **Version**: 1.2.0 — INV-L03 對應欄同步 domain-map 校正結果（0.38.1-W11-004）
**Version**: 1.1.0 — 技術正確性與跨冊一致性修正（0.38.1-W11-002）
**Version**: 1.0.0 — book_loans 資料契約初版（毫秒時間戳語意、loan_type CHECK 值域、active_loan/book_loans 雙載體分工、無交易包裹與原生例外上拋現況）
