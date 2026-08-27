---
id: SPEC-014
title: "library 資料契約（books / tag_categories / tags / book_tags）"
status: review
source_proposal: PROP-007
created: "2026-07-25"
updated: "2026-07-26"
version: "1.2"
owner: "rosemary-project-manager"

domain: library
subdomain: "data-contract"

related_specs: [SPEC-011, SPEC-013, SPEC-015, SPEC-016]
---

# library 資料契約（books / tag_categories / tags / book_tags）

## 概述

本文件涵蓋 library domain 核心四表：`books`（書籍主表）、`tag_categories`（標籤分類
類別）、`tags`（標籤項目，含 CCL 自關聯樹）、`book_tags`（書籍-標籤多對多關聯），
承載 `DatabaseSchema`（`lib/infrastructure/database/database_schema.dart`）DDL 表達
不了的設計意圖：欄位語意（含時間戳單位現況）、狀態責任分層、不變式、交易邊界、錯誤
語意契約、恢復模型。可攜性邊界原則的適用方式：A 區（邏輯契約）在資料庫換引擎後仍
成立，照搬即可；B 區（實作綁定）綁定 SQLite/sqflite，換引擎需依新引擎重寫。

本文件只陳述 schema 與 repository 實作現況及既有設計決策（PROP-007 §3.7 tag-based
終態、W2-023 ADR-4 drop+rebuild），不新增任何未存在的約束。原標註的現況缺口
（CHECK=0、UNIQUE 候選未決）已由 DDL 約束補強評估結案：0.38.1-W10-007 逐候選判定、
0.38.1-W10-008 落地（7 條 enum 值域 CHECK + master_books.primary_edition_id FK，
皆非本契約四表；本契約四表 UNIQUE 候選判定不採，見 A.1 / A.3 / B.2 各節回填）。

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

**與 SPEC-011 分工**：SPEC-011（book-repository-contract）聚焦 repository 介面的
行為契約（方法語意、觀測出口）；本節聚焦「欄位的值域/格式/單位/命名邊界約束」。
兩者互相引用同一組欄位，不重複描述功能用途。

#### 時間戳單位跨表現況

四表時間戳欄位單位**並非統一**，且同一欄位在不同寫入路徑單位不同。下表為逐欄實證
現況（schema DDL + repository 寫入點交叉比對，0.38.1-W10-001 重現實驗）：

| 欄位 | DDL DEFAULT | Repository 寫入路徑 | Seed 寫入路徑 | 有效單位 |
|------|------------|--------------------|--------------|---------|
| books.created_at | 秒（`strftime('%s','now')`） | **毫秒**（`_bookToMap` 顯式寫 `addedDate.millisecondsSinceEpoch`，覆蓋 DEFAULT；read-path `fromMillisecondsSinceEpoch` 還原） | — | 毫秒（repository 為唯一寫入路徑，DEFAULT 實際不觸發） |
| books.updated_at | 秒 | 不寫入（`_bookToMap` 無此欄）→ INSERT 走 DEFAULT；UPDATE 走 trigger（秒，見 B.2） | — | 秒 |
| books.updated_date | 無 DEFAULT | 毫秒（`DateTime.now().millisecondsSinceEpoch`） | — | 毫秒 |
| books.progress_last_read_at / publish_date | 無 DEFAULT | 毫秒 | — | 毫秒 |
| tag_categories.created_at | 無 DEFAULT | 毫秒（`_ensureCategory`、custom 類別建立） | **秒**（13 系統類別 seed `strftime('%s','now')`） | 混用（seed 列秒、執行期列毫秒） |
| tags.created_at / updated_at | 無 DEFAULT | 毫秒（`sqlite_tag_repository` / `sqlite_book_repository` free-tag 路徑） | **秒**（CCL seed `strftime('%s','now')`） | 混用（CCL seed 列秒、執行期列毫秒） |
| book_tags.created_at | 無 DEFAULT | 毫秒 | — | 毫秒 |

> 本表陳述現況，不做收斂決策。DDL 約束補強評估已結案（0.38.1-W10-007 時間戳候選
> 判定）：時間戳正值 CHECK 不採——弱不變式（秒級與毫秒級值皆 > 0）攔不住真正風險（單位混用）；
> 單位收斂屬行為變更（涉及 seed、trigger、讀取路徑改寫）非 DDL 約束補強範圍，
> 本表維持為契約事實承載（最終現況，非延後）。讀取端目前僅 `books.created_at`（還原
> `addedDate`）與 `tags.created_at/updated_at`（`fromMillisecondsSinceEpoch`）參與
> entity 還原，seed 列的秒級值若進入這些讀取路徑會被誤解為 1970 年附近的毫秒值——
> 現況 CCL tag 的 createdAt/updatedAt 不參與業務計算，故未爆發，但屬已知單位不一致風險。

#### books

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | 應用層產生字串 | 非空，PK 唯一 | 書籍唯一識別碼 |
| title | TEXT | 自由字串 | NOT NULL | 唯一保留的非 tag-backed 內容欄位之一（PROP-007 §3.7：author/isbn/publisher/reading_status 已移除，改由 book_tags 承載） |
| cover_thumbnail / cover_medium / cover_original | TEXT，nullable | URL 字串 | 無約束 | 多尺寸封面（§3.7 終態欄位） |
| cross_platform_id | TEXT，nullable | 字串 | 無 UNIQUE 約束（最終決策，0.38.1-W10-007） | 跨平台 ID。domain 唯一性語意未定義（無 UC/spec 去重需求）；補 UNIQUE 與現行衝突處理策略的互動論證見 B.2「books upsert」列。若日後出現去重需求，該需求票自帶「先改寫衝突處理策略再議約束」的完整範疇 |
| data_fingerprint | TEXT，nullable | 字串 | 無 UNIQUE 約束（最終決策，0.38.1-W10-007） | 資料指紋。判定與理由同 cross_platform_id |
| progress_percentage | REAL，nullable | 百分比數值 | 無 DDL 值域約束 | 閱讀進度 |
| progress_current_page / progress_total_pages | INTEGER，nullable | 頁數 | 無 DDL 值域約束 | — |
| progress_last_read_at | INTEGER，nullable | 毫秒 epoch | — | — |
| publish_date | INTEGER，nullable | 毫秒 epoch | — | 過渡欄位：entity 欄位仍存在且無對應 tag，其移除與 entity 欄位移除同批處理（schema 註解明載） |
| description / cover_image_url | TEXT，nullable | 自由字串 / URL | 無約束 | 過渡欄位（同上） |
| rating | REAL，nullable | 數值 | 無 DDL 值域約束 | 過渡欄位（同上） |
| updated_date | INTEGER | 毫秒 epoch | NOT NULL | repository 每次寫入更新；`getRecentBooks` 排序依據 |
| api_enriched | INTEGER | 布林（0/1） | `{0,1}`（應用層寫入 `? 1 : 0`，無 DDL CHECK） | API 補充資料旗標 |
| created_at | INTEGER | 毫秒 epoch（repository 路徑） | NOT NULL | 承載 entity `addedDate`（書籍加入時間，0.32.0-W5-007：`added_date` 欄位移除後由本欄承載） |
| updated_at | INTEGER | 秒 epoch | NOT NULL | 審計欄位，trigger 維護（B.2），不參與 entity 還原 |
| active_loan | TEXT，nullable | JSON 字串（`BookLoan.toJson()`） | 合法 JSON 或 NULL | 未借閱為 NULL；read-path `BookLoan.fromJson` 還原（0.32.0-W2-035） |
| extensions / passthrough | TEXT，nullable | JSON 字串（`jsonEncode` 的 `Map<String,dynamic>`） | 合法 JSON 或 NULL | interchange 透傳資料 forward-compat 保存（0.32.0-W2-040）；原始 JSON 無對應鍵為 NULL |

#### tag_categories

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | snake_case 字串 | 非空，PK 唯一 | 13 個系統類別 id 必須與 `TagCategoryIds.allCategoryIds` 逐字一致（INV-01） |
| name | TEXT | 顯示名稱 | NOT NULL | 系統類別 seed 為中文名；`_ensureCategory` fallback 路徑以 id 充當 name |
| is_system | INTEGER | 布林（0/1） | DEFAULT 1 | 系統類別標記 |
| allow_tree | INTEGER | 布林（0/1） | DEFAULT 0 | 允許巢狀（現況僅 `ccl` / `custom` 為 1） |
| created_at | INTEGER | 混用（見時間戳現況表） | NOT NULL | — |

#### tags

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | 應用層字串；CCL 節點採 `ccl_0` / `ccl_00` / `ccl_000` 三層方案 | 非空，PK 唯一 | — |
| category_id | TEXT | 同 tag_categories.id | NOT NULL，FK -> tag_categories(id) | 無 ON DELETE 設定（NO ACTION，見 B.2） |
| name | TEXT | 顯示名稱 | NOT NULL | — |
| parent_id | TEXT，nullable | 同 tags.id | FK -> tags(id) 自關聯 | NULL = 頂層；CCL parent 鏈 `ccl_123 -> ccl_12 -> ccl_1 -> NULL`（INV-02） |
| path | TEXT，nullable | CCL path 格式 `0` / `0/01` / `0/01/012` | 無 DDL 約束 | 樹路徑快取 |
| is_locked | INTEGER | 布林（0/1） | DEFAULT 0 | 1 = 不可修改的系統標籤；CCL 全節點為 1（INV-02） |
| created_at / updated_at | INTEGER | 混用（見時間戳現況表） | NOT NULL | — |

#### book_tags

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| book_id | TEXT | 同 books.id | NOT NULL，FK -> books(id) ON DELETE CASCADE | — |
| tag_id | TEXT | 同 tags.id | NOT NULL，FK -> tags(id) ON DELETE CASCADE | — |
| is_primary | INTEGER | 布林（0/1） | DEFAULT 0 | 「選一個」場景標記（如主要作者）；同書同分類至多一個 primary 為 domain 不變式（INV-06），無 DDL 承載 |
| created_at | INTEGER | 毫秒 epoch | NOT NULL | — |
| （無獨立 PK） | — | — | UNIQUE(book_id, tag_id) | 邏輯鍵由 UNIQUE 承載（INV-03），實體鍵為 SQLite rowid |

### A.2 狀態責任分層

三類：canonical（正式狀態，唯一寫入來源）／derived（衍生，只能 rebuild、不能反向
修正 canonical）／追蹤欄位（審計用，不參與業務計算）。同一筆資料只能有一個
canonical 來源。

| 欄位/表 | 分層 | 說明 |
|--------|------|------|
| books 表（tag-backed 欄位以外） | canonical | 寫入路徑（`sqlite_book_repository.dart`）：`saveBook` / `updateBook` 為單本 canonical 路徑；`addBooks`（批次 replace）、`importInterchange`（匯入）、`markAsEnriched` / `markBooksAsEnriched`（旗標回寫）亦寫入本表，交易語意見 A.4 |
| Book entity 的 author/isbn/publisher/readingStatus 等固定欄位 | derived | **表內無對應欄位**（§3.7 已移除）；read-path 由 book_tags JOIN 還原（`_mapToBook` / `_assembleBooksWithTags`），固定欄位值來自 tag（INV-08，防 PC-165 假綠）。rebuild 方式：重讀 book_tags |
| tag_categories 表 | canonical | 13 系統類別由 seed 寫入（`_onCreate`）；custom / 匯入類別由 repository `_ensureCategory` 等路徑寫入 |
| tags 表 | canonical | tag 樹唯一正式來源；CCL 子樹（約 990 節點）由 seed 寫入且 `is_locked=1` 不可修改 |
| book_tags 表 | canonical | 書籍-標籤關聯唯一正式來源；`saveBook`/`updateBook` 以整組重寫（clear + insert）維護 |
| books.updated_at | 追蹤欄位 | trigger 維護（B.2），repository 不寫不讀，不參與 entity 還原 |
| books.active_loan | canonical（當前活躍借閱） | `Book.activeLoan` VO 的 JSON 持久化形態，與 entity 同源同寫入路徑。本欄與 `book_loans`（SPEC-015）構成借閱狀態的雙載體：延期與備註更新只寫本欄，`book_loans` 活躍列為建立時點快照。分工全貌與過時性警示見 SPEC-015 A.2（該分工的判定歸屬本冊——`books` 屬 library domain——SPEC-015 A.2 為分工細節的展開載體） |
| books.extensions / passthrough | 追蹤欄位（透傳保存） | interchange forward-compat 原樣保存，不參與業務計算，import -> DB -> export round-trip 專用 |

### A.3 不變式清單

陳述本身（不含由哪一層保證——歸屬決策見 B.1）。供 `docs/spec/library/domain-map.md`
「Bundle 不變式清單」小節互相引用。

**編號唯一性**：本冊用無前綴 `INV-NN`，SPEC-015 用 `INV-LNN`、SPEC-016 用 `INV-VNN`，
前綴制不一致。跨冊唯一性現況依賴 `docs/traceability.yaml` 條目的 `spec` 欄消歧，
非依賴編號本身；新增契約冊沿用無前綴 `INV-NN` 會與本冊撞名，須改用 domain 前綴。

| 編號 | 不變式 | 對應 domain-map 條目 |
|------|--------|----------------------|
| INV-01 | tag_categories 的 13 個系統類別 id 集合必須與 `TagCategoryIds.allCategoryIds`（`lib/domains/library/constants/tag_category_ids.dart`）逐字一致 | 本文件新增（schema 註解與 `tag_category_ids_test.dart` 已承載語意，domain-map 未列） |
| INV-02 | CCL seed 子樹：全節點 `category_id='ccl'`、`is_locked=1`，約 990 節點（10 大類 -> 100 中類 -> ~880 小類），id 方案 `ccl_N`/`ccl_NN`/`ccl_NNN`，parent 鏈逐層上溯至 NULL，path 為 `/` 分隔層級路徑 | 本文件新增（僅存於 `ccl_classification.dart` 檔頭註解） |
| INV-03 | 同一 `(book_id, tag_id)` 關聯唯一 | 本文件新增（schema UNIQUE 承載，domain-map 未列專條） |
| INV-04 | tags 樹形完整性：`parent_id` 必指向既有 tags 列或為 NULL（頂層） | 本文件新增（FK 自關聯承載） |
| INV-05 | books.created_at 承載 entity `addedDate`（書籍加入時間），repository 寫入毫秒、讀出毫秒（R1 單位一致） | 本文件新增（僅存於 schema 與 repository 註解） |
| INV-06 | 同一本書同一分類的 book_tags 至多一個 `is_primary=1` | `domain-map.md` §3 BookTag bundle「同分類 isPrimary 最多一個」 |
| INV-07 | Seed 冪等：13 系統類別與 CCL 子樹 seed 重複執行不影響既有列 | 本文件新增（INSERT OR IGNORE 承載） |
| INV-08 | Book entity 固定欄位（author/isbn/publisher/readingStatus）值一律由 book_tags 還原，books 表無對應欄位可回退 | 本文件新增（PROP-007 §3.7 終態，schema 註解「防 PC-165 假綠」） |
| INV-09 | active_loan / extensions / passthrough 三欄 JSON round-trip：寫入 `toJson`/`jsonEncode`，讀出 `fromJson`/`jsonDecode`，缺值為 NULL 非空字串 | 本文件新增（0.32.0-W2-035 / W2-040 決策） |

> **CHECK 約束現況**：本契約四表 DDL 無任何 CHECK——DDL 約束補強評估已結案
> （0.38.1-W10-007）：四表布林 0/1 欄位 CHECK 家族判定不採（非法值在讀取端
> 為單向降級不產生語意翻轉，納入會稀釋審查注意力），為最終決策非延後。
> 全庫層面「CHECK=0」現況已改變：0.38.1-W10-008 落地 7 條 enum 值域 CHECK
> （book_loans.loan_type / book_editions.relationship_type / sync_records.sync_status /
> sync_tasks.status / sync_tasks.network_status / conflict_resolutions.status /
> import_progress.status），皆非本契約四表。上表不變式仍無一以 CHECK 承載。

### A.4 交易邊界

哪些寫入必須一起成立（原子性要求）。不含 isolation level（屬 B 區）。

| 交易邊界 | 涵蓋寫入 | 說明 |
|---------|---------|------|
| 書籍儲存 | books 一列 + 該書全部 book_tags（含 free-tag 路徑新建 tags 列與 `_ensureCategory` 的 tag_categories 列） | `saveBook`：單一 `db.transaction()` 包裹 `_insertBookData` + `_writeAllBookTags`（clear + rebuild）。書籍與其標籤關聯必須同時成立，否則 read-path 固定欄位還原（INV-08）會取得殘缺 tag 集合 |
| 書籍更新 | books UPDATE + book_tags 整組重寫 | `updateBook`：單一 `db.transaction()` 包裹 `_updateBookData` + `_replaceBookTags`，理由同上 |
| 批次書籍新增 | 全批 books 列 + 各書全部 book_tags | `addBooks`（`sqlite_book_repository.dart`）：單一 `db.transaction()` 逐本 replace books 後 `_writeAllBookTags`。整批共用一個交易，任一本失敗全批不成立 |
| Interchange 匯入 | tag 樹全節點 + 全批 books 列 + 各書 canonical book_tags | `importInterchange`：單一 `db.transaction()` 包裹 `_syncTagTree` + `_insertBookData` + `_insertCanonicalBookTags`。本專案唯一顯式宣告「任一寫入失敗即整批 rollback、零部分寫入」的路徑（方法註解明載）。與 `addBooks` 不複用的理由：`addBooks` 走 `_writeAllBookTags` 會以 `categoryId:value` 重建 tag id，覆蓋 tag 樹同步的 canonical id 使階層 JOIN 脫節 |
| 單一標籤指派/移除 | book_tags 單列 | `assignTagToBook` / `removeTagFromBook`（`sqlite_tag_repository.dart`）：單列操作天然原子 |
| Seed 寫入 | 13 系統類別 + CCL 子樹 | `_onCreate` 逐條執行且逐條容錯（非單一交易；books 建表失敗中止、非核心語句失敗記 warning 跳過，0.38.1-W1-023），冪等性由 INSERT OR IGNORE 保證而非交易回滾 |

### A.5 錯誤語意契約

唯一鍵衝突／外鍵違反／驗證失敗對應哪個 domain 例外，跨資料庫引擎成立（error
translation 邊界）。

| 資料庫錯誤類型 | 對應 domain 例外 | 觸發情境 |
|--------------|------------------|---------|
| PK 衝突（books.id） | 不適用（設計上以 upsert 消解） | `_insertBookData` 用 `ConflictAlgorithm.replace`，同 id 重複儲存為覆蓋非錯誤路徑（見 B.2） |
| UNIQUE 衝突（book_tags(book_id, tag_id)） | 不適用（設計上以 ignore 消解） | 一般 tag 寫入路徑用 `ConflictAlgorithm.ignore`，重複關聯靜默跳過非錯誤路徑。tag 樹同步路徑（`_syncTagTree`）用 replace，語意不同，見 B.2 |
| FK violation（book_tags -> books/tags、tags -> tag_categories/tags） | 無型別化轉譯：sqflite `DatabaseException` 由 repository 包裝為 `StorageException.databaseError`（含 operation 與表名） | `PRAGMA foreign_keys=ON`（`database_manager.dart` `_onConfigure`）使違反在寫入時被擋；free-tag 與匯入路徑以 `_ensureCategory` 先行消解 tags.category_id 的 FK 風險 |
| 更新／刪除目標不存在 | 呼叫端收到 `StorageException.databaseError(operation='updateBook' / 'deleteBook', table='books')`，**內層 userMessage 不外露** | `_updateBookData` / `_deleteBookRecord` 檢查 `rowsAffected == 0` 後拋內層 `StorageException`（userMessage「書籍不存在: {id}」）；該例外被 `executeWithErrorHandling`（`base/base_repository.dart`）收成 `OperationResult.failure`，`updateBook` / `deleteBook` 僅取 `result.message`（「更新書籍 失敗」／「刪除書籍 失敗」）重包為外層 `databaseError`。呼叫端無法據訊息區分「書籍不存在」與其他寫入失敗，只能依 operation 欄定位 |
| 查詢目標不存在 | 讀取路徑：回傳 `null`，不拋例外；寫入前置查詢：`BusinessException.notFound('Book', bookId)` | `findById` / `getBookById` / `findByIsbn` 查無結果回 `null`。`notFound` 於本 repository 僅有一處拋出：`markAsEnriched` 對不存在書籍（先 `findById` 再判空） |
| validation failure（批次上限） | `ValidationException.outOfRange` | 批次操作 bookIds 超過 50 上限（`_validateBookIdsBatchSize`） |
| 其他 DB 錯誤 | `StorageException.databaseError(operation, message, table)` | repository 各寫入/查詢路徑的統一包裝 |
| 統一包裝的破口 | 裸 `Exception('批次新增書籍失敗: $e')`，不屬 `StorageException` 家族 | `addBooks` 的 catch 區塊。呼叫端無法以 `StorageException` 型別捕捉本路徑失敗，亦取不到 errorCode / table 欄位 |

### A.6 恢復模型

備份還原後的資料驗證方式。

| 情境 | 驗證方式 |
|------|---------|
| 備份/還原 | `database_manager.dart`：檔案層級複製（整份 DB 檔），非逐表匯出 |
| 完整性驗證 | `DatabaseSchema.integrityChecks` 於 `_onOpen` 執行：`PRAGMA integrity_check` + `PRAGMA foreign_key_check` + 全 12 表逐表 `SELECT COUNT(*)`（含本契約四表）。**現況無任何違反出口**：`_performIntegrityCheck`（`database_manager.dart`）執行語句後結果全部丟棄——`integrity_check` 非 'ok' 進入空分支、`foreign_key_check` 回傳列從未檢視，無日誌無例外；僅語句本身拋出例外時記 error。**觸發條件為非測試環境**：`_isDevelopmentMode()` 實作為 `!Platform.environment.containsKey('FLUTTER_TEST')`，即 production 會執行、`flutter test` 不執行（與方法名稱字面相反）。驗證範圍為結構完整性與可讀性，**不含**值域/單位/seed 一致性逐筆檢查 |
| Seed 一致性恢復 | fresh-install 重建時 seed 冪等（INV-07）；既有 DB 的 seed 列不會被重複寫入或覆蓋 |

---

## B 區：實作綁定（DB-specific）

> 本區內容綁定 SQLite/sqflite。資料庫遷移時需依新引擎重寫本區，A 區不受影響。

### B.1 保證層歸屬

每條不變式的保證層。本表實際使用四種歸屬：DB 約束（含語句層）／應用層／seed 語句／
seed 語句 + 測試。歸屬本身是綁定決策，A 區不變式陳述不因換 DB 而變。

歸屬理由欄採預設值 + 例外展開：預設一格帶過，僅有爭議或多層條目才展開理由。

| 不變式編號 | 保證層 | 歸屬理由 |
|-----------|--------|---------|
| INV-01 | seed 語句 + 測試 | seed 字面值人工維護與 `TagCategoryIds` 對齊；`tag_category_ids_test.dart` 驗證集合一致。無 DB 層機制可表達「與 Dart 常數一致」 |
| INV-02 | seed 語句 | `CclClassification.seedStatements` 產生器單一來源保證結構；`is_locked=1` 為 seed 字面值，DB 不阻止事後 UPDATE（鎖定語意由應用層尊重 is_locked 旗標實現） |
| INV-03 | DB 約束 | `UNIQUE(book_id, tag_id)` 已於 schema 落實 |
| INV-04 | DB 約束 | FK 自關聯 + `PRAGMA foreign_keys=ON` |
| INV-05 | 應用層 | `_bookToMap` / `_mapToBook` 為唯一寫讀路徑，顯式毫秒覆蓋 DDL 秒級 DEFAULT（repository 註解明載 R1 單位一致）。DEFAULT 與寫入路徑單位不一致為已知現況（A.1 時間戳表）；DDL 約束補強評估已結案（0.38.1-W10-007）：單位收斂屬行為變更非 DDL 約束補強，應用層歸屬為最終現況 |
| INV-06 | 應用層 | domain 層 BookTag 不變式（domain-map），無 DDL 承載（SQLite 部分索引可表達但現況未建）。DDL 約束補強評估已結案（0.38.1-W10-007）：部分索引不在其採用清單（與布林 CHECK 家族同判準：低價值 DDL 約束不納入），應用層歸屬為最終現況 |
| INV-07 | DB 約束（語句層） | `INSERT OR IGNORE` 冪等語意 |
| INV-08 | 應用層 | read-path `_mapToBook` / `_assembleBooksWithTags` JOIN 還原；DDL 層的保證形態是「欄位不存在」（無可回退欄位） |
| INV-09 | 應用層 | 寫讀路徑唯一（`_bookToMap` / `_mapToBook`），非法 JSON 於解碼時拋 `FormatException` |

### B.2 邊界行為的引擎機制

| 邊界行為 | 引擎機制 | 說明 |
|---------|---------|------|
| books upsert | `ConflictAlgorithm.replace`（SQLite `INSERT OR REPLACE`） | 同 id 重複儲存為整列取代。**引擎行為警示**：`INSERT OR REPLACE` 是 DELETE + INSERT，會觸發 book_tags 的 `ON DELETE CASCADE` 清空舊關聯——現況安全，因 `saveBook` / `addBooks` / `importInterchange` 皆在同一交易內隨後重寫 book_tags（A.4），但任何繞過這些路徑直接 replace books 列的操作會靜默丟失關聯。本列亦是 A.1 cross_platform_id / data_fingerprint 不採 UNIQUE 的理由：補 UNIQUE 會使重複值寫入從「新增一列」變成「靜默 DELETE 前列整列 + CASCADE 清該書標籤」 |
| tags / book_tags 一般插入去重 | `ConflictAlgorithm.ignore`（SQLite `INSERT OR IGNORE`） | `_upsertTagAndLink`（`saveBook` / `updateBook` 的 bookTags 與 free-tag 路徑）、`_insertCanonicalBookTags`（匯入路徑的 book_tags 關聯）、`sqlite_tag_repository` 各寫入點皆用 ignore：重複關聯／重複 tag id 靜默跳過，既有列不被覆寫，非錯誤路徑 |
| tag 樹同步寫入 | `ConflictAlgorithm.replace`（SQLite `INSERT OR REPLACE`） | `_syncTagTree`（僅 `importInterchange` 路徑）對 `tags` 用 replace，使匯入的 canonical 節點覆蓋既有同 id 節點的 name / parent_id / is_locked。**引擎行為警示**：`INSERT OR REPLACE` 是 DELETE + INSERT，`book_tags.tag_id` 為 `ON DELETE CASCADE`——重寫既有 tag 會連帶清空該 tag 的**全部** book_tags 關聯（含匯入批次以外的書籍）。現況匯入批次內各書關聯隨後由 `_insertCanonicalBookTags` 於同一交易重建，但既有其他書籍指向同一 tag 的關聯不在重建範圍內 |
| FK 刪除策略 | book_tags.book_id / book_tags.tag_id 皆 `ON DELETE CASCADE`；tags.category_id / tags.parent_id 未設定（NO ACTION） | 刪書/刪 tag 自動清關聯；刪 tag_categories 列或有子節點的 tags 列會被 FK 擋下（NO ACTION + foreign_keys=ON） |
| updated_at 維護 | trigger `books_updated_at_trigger`：AFTER UPDATE 且 OLD=NEW 或 NULL 時以 `strftime('%s','now')`（秒）回填 | 呼叫端顯式帶新 updated_at 時 trigger 不覆蓋 |
| FK 檢查開關 | `_onConfigure` 執行 `PRAGMA foreign_keys=ON`（另有 WAL、synchronous NORMAL 等，W1-002 execute/rawQuery 分流） | sqflite 預設 FK 檢查關閉，本專案顯式開啟 |
| CHECK 違反例外 | 本契約四表無 CHECK（布林 0/1 家族判定不採，0.38.1-W10-007，A.3 現況框）；全庫層面 0.38.1-W10-008 已於他表落地 7 條 enum 值域 CHECK。sqflite 無型別化 CHECK 違反例外 API；SQLite conflict resolution（OR REPLACE / OR IGNORE）僅消解 UNIQUE / PK / NOT NULL 衝突，CHECK 與 FK violation 不受影響一律 ABORT（0.38.1-W10-007 實證） | CHECK violation 以 `DatabaseException` 浮出並由 repository 包裝為 `StorageException`（A.5 錯誤語意契約一致）；依 `data-layer-contract-methodology.md` §4，CHECK 僅作 defense-in-depth，主要錯誤語意仍由應用層承擔 |

### B.3 Schema 演進策略與 Seed 資料政策

| 項目 | 決策 | 說明 |
|------|------|------|
| Schema 演進策略 | **pre-1.0 drop+rebuild**（`currentVersion=1`，`migrationScripts={}`、`reverseMigrationScripts={}` 皆清空） | 既定 ADR（W2-023 ADR-4 + PROP-007 §3.7 終態）：pre-1.0 無 production 存量資料，schema 變更直接改 `_onCreate` 語句 + 版本歸 1，不走 onUpgrade。**依賴規則**：1.0 上架後此低成本窗口關閉——屆時任何約束補強觸發 sqflite 12 步表重建（DDL 約束補強評估決議之 7 條 CHECK 與 primary_edition_id FK 已於窗口內落地，0.38.1-W10-008） + `PRAGMA foreign_keys OFF/ON` + migration 測試（方法論 §4），onUpgrade 路徑與 migrationScripts 回填成為必要 |
| migration 治理旗標 | 不要（合法終態，非延後） | W10-001 判定：version=1、migrationScripts 空、無存量資料。重新評估的載體即本節（B.3 為模板固定欄位） |
| Seed 資料政策 | 兩組 seed，皆 INSERT OR IGNORE 冪等 | (1) 13 系統 tag_categories（`createTagCategoriesSeed`，須與 `TagCategoryIds.allCategoryIds` 逐字一致，INV-01）；(2) CCL 三層分類樹約 990 節點（`CclClassification.seedStatements`，INV-02）。`_onCreate` 逐條容錯：books 建表失敗中止開啟，seed 等非核心語句失敗記 warning 跳過（0.38.1-W1-023） |

---

## 欄位 × 既有載體對照表

逐欄標「新建／引用既有」，避免與既有載體內容重複。本文件只新建既有載體缺的欄位；
其餘以引用連結取代複寫。

| 欄位/章節 | 承載狀態 | 既有載體 | 說明 |
|----------|---------|---------|------|
| 表/欄位語意（單位/值域/格式） | 部分承載，本文件補約束細節與時間戳單位現況 | `database_schema.dart` DDL 註解、SPEC-011 介面契約 | schema 註解散落各表，本文件集中為跨表對照（時間戳單位表為本文件首創） |
| 不變式陳述 | 部分承載，本文件補完整清單並附編號 | `docs/spec/library/domain-map.md` §3「Bundle 不變式清單」 | INV-06 引用 domain-map；其餘 8 條為本文件新增（原僅存於程式註解或 DDL） |
| 契約 ↔ 測試對應 | 已對應 | `docs/traceability.yaml` 第三軸 `data_contract_tests`（0.38.1-W10-005 建立） | 該軸共 23 條，逐條對應三冊 INV 編號（本文件 INV-01~09 / SPEC-015 INV-L01~L06 / SPEC-016 INV-V01~V08），以 `spec` 欄消歧同名編號。初查覆蓋分佈：covered 7 / partial 7 / gap 8 / no_test_needed 1；補測試由 0.38.1-W10-012 承接 |
| 可攜性分區（A/B 兩區結構） | 新建 | 無 | 依模板 |
| 狀態責任分層 | 新建 | 無 | 依模板 |
| 交易邊界 | 新建 | 無 | 依模板；事實來源為 repository `db.transaction()` 實作現況 |
| 錯誤語意契約 | 新建 | 無 | 依模板；事實來源為 repository 例外拋出現況 |
| 恢復模型 | 新建 | 無 | 依模板；事實來源為 `database_manager.dart` + `integrityChecks` |
| 保證層歸屬 | 新建 | 無 | 見 B.1 |
| Schema 演進策略 | 新建（引用既定 ADR） | W2-023 ADR-4、PROP-007 §3.7 | 見 B.3，本文件不複決 |

## 適用判準（本文件是否需要撰寫）

依 `data-layer-contract-methodology.md` 兩正交旗標判斷：

| 旗標 | 判定 | 理由 |
|------|------|------|
| 契約文件 | 要 | 重度 AI 代理協作專案（ticket/agent 框架、多代理跨 session 交接）；時間戳單位混用、seed 一致性、JSON 序列化欄位等語意僅存於程式註解無契約載體（0.38.1-W10-001 判定） |
| migration 治理 | 不要 | version=1、migrationScripts={}、pre-1.0 無存量資料（drop+rebuild ADR）；合法終態決策，重新評估載體為本文件 B.3（0.38.1-W10-001 判定） |
| dormant 豁免（如適用） | 不適用 | 四表皆有 production 觸達路徑（`SqliteBookRepository` / `SqliteTagRepository` 於 `lib/` 內有 DI 接線），不符 `data-layer-contract-methodology.md` 第 2.1 節豁免前提 |

**分冊自評**（依模板 v1.2.0 分冊判準三條）：

| 判準 | 自評 |
|------|------|
| 1. per-domain 放置 | 符合。四表皆屬 library domain，置於 `docs/spec/library/` |
| 2. `domain` 單值上限 | 符合。frontmatter `domain: library` 單值，未橫跨其他 domain |
| 3. 寫入者群／錯誤語意模式分異即再分冊 | 已分異但不拆。四表寫入者群分為 `sqlite_book_repository`（books + book_tags + free-tag 路徑的 tags）、`sqlite_tag_repository`（tags + book_tags）、`_onCreate` seed（tag_categories + tags），衝突策略亦分異（books replace / 一般 tag ignore / tag 樹同步 replace）。不拆的理由：四表由 A.4「書籍儲存」與「書籍更新」兩條交易邊界共同寫入，拆冊會使單一交易的原子性要求跨兩份契約敘述，讀者無法在一處讀完保證範圍；錯誤語意模式則三表一致（統一 `StorageException` 包裝，破口見 A.5 末列） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-07-25 | 初始版本（0.38.1-W10-002，library 四表契約） |
| 1.1 | 2026-07-25 | DDL 約束補強評估結案回填（0.38.1-W10-008）：A.1 UNIQUE 候選判定不採（最終決策）、時間戳收斂註記結案、A.3/B.2 CHECK 現況框更新（全庫 7 條 CHECK 落地於他表、四表布林家族不採）、B.1 INV-05/INV-06 結案引用、B.3 窗口註記更新 |
| 1.2 | 2026-07-26 | 技術審查修正（0.38.1-W11-002，findings 來源 0.38.1-W11-001）：B.2 tag 寫入拆一般 ignore 與 tag 樹同步 replace 兩列並補 CASCADE 警示、A.5 更新／刪除失敗改述為內層訊息不外露、A.5 查詢不存在改述與 addBooks 破口列、A.4 補批次新增與匯入兩條交易邊界、A.6 完整性驗證改述為結果未檢視、A.2 補 active_loan 雙載體分工路由與 books 寫入路徑、對照表引用 traceability.yaml 第三軸、frontmatter 補 related_specs 與版本同步、適用判準補 dormant 豁免列與分冊自評、子代號改可讀敘述 |

---

**Spec Updated**: 2026-07-26 | **Version**: 1.2.0 — 技術正確性與跨冊一致性修正（0.38.1-W11-002）
**Version**: 1.1.0 — DDL 約束補強評估結案回填：未決項全數轉為最終決策或已落地事實（0.38.1-W10-007 判定 / 0.38.1-W10-008 落地）
**Version**: 1.0.0 — library 四表資料契約初版（books/tag_categories/tags/book_tags；時間戳單位現況表、9 條不變式、交易邊界與錯誤語意盤點）
