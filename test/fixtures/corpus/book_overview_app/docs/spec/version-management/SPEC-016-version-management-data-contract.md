---
id: SPEC-016
title: "version-management 資料契約（master_books / book_editions）"
status: review
source_proposal: null
created: "2026-07-25"
updated: "2026-07-26"
version: "1.3"
owner: "rosemary-project-manager"

domain: version-management
subdomain: "data-contract"

# SPEC-009 = docs/spec/version-management/SPEC-009-book-version-management.md。
# 重複編號已於 0.38.1-W11-004 治理：原同號的 QR frame 格式規格改為 SPEC-017，
# 兩份規格檔名改為 ID 前綴式，SPEC-009 現可唯一解析。
related_specs: [SPEC-009, SPEC-014]
---

# version-management 資料契約（master_books / book_editions）

## 概述

本文件涵蓋 version-management domain 兩表：`master_books`（主書籍，版本群概念
層級）、`book_editions`（書籍版本列）。承載 `DatabaseSchema`
（`lib/infrastructure/database/database_schema.dart`）DDL 表達不了的設計意圖：
primary_edition_id FK 語意與 referent 保證流程（0.38.1-W10-008 主落地項）、
relationship_type 值域、循環引用的建構順序、時間戳單位跨表不一致現況、接線
現況（本 domain 持久化層在 `lib/` 內無 DI 接線，僅測試使用——0.38.1-W10-007
已載明此 dormant 狀態並綁定接線時的重新評估條件）。可攜性邊界原則的適用方式：A 區（邏輯契約）
在資料庫換引擎後仍成立，照搬即可；B 區（實作綁定）綁定 SQLite/sqflite，換引擎
需依新引擎重寫。

本文件只陳述 schema 與 repository / service 實作現況及既有設計決策（UC-08、
0.38.1-W10-007 判定、0.38.1-W10-008 落地），不新增任何未存在的約束。

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

**與 SPEC-009 分工**：SPEC-009（book-version-management）聚焦版本合併/分離/主版本
切換的功能行為；本節聚焦「欄位的值域/格式/單位/命名邊界約束」。兩者互相引用同一
組欄位，不重複描述功能用途。

#### 時間戳單位現況（兩表不一致）

| 欄位 | DDL DEFAULT | Repository 寫入路徑 | 有效單位 |
|------|------------|--------------------|---------|
| master_books.created_at / updated_at | 秒（`strftime('%s','now')`） | **毫秒**（`_masterBookToMap` 顯式寫入；`update` / `setPrimaryEdition` 亦寫毫秒）；讀取端 `fromMillisecondsSinceEpoch` 還原 | 毫秒（repository 為唯一寫入路徑，DEFAULT 秒不觸發——與 books.created_at 同型態的「DEFAULT 秒、實際毫秒」漂移，SPEC-014 A.1 已載明該型態） |
| master_books.first_published_date | 無 DEFAULT | 毫秒 | 毫秒 |
| book_editions.created_at / updated_at | 秒 | **不寫入**（`_bookEditionToMap` 無此二欄）→ INSERT 走 DEFAULT；`update` 不觸及 → updated_at 停留在插入時秒值 | **秒**（DEFAULT 為唯一寫入路徑；讀取端不讀此二欄，不參與 entity 還原） |
| book_editions.linked_at | 無 DEFAULT | 毫秒（`linkToMasterBook`）；`unlinkFromMasterBook` 清 NULL | 毫秒 |
| book_editions.translation_published_date | 無 DEFAULT | 毫秒 | 毫秒 |

> 本表陳述現況，不做收斂決策（DDL 約束補強評估判定：單位收斂屬行為變更非 DDL 約束
> 補強範圍，0.38.1-W10-007）。同 domain 兩表 created_at 單位不同（master 毫秒、
> edition 秒）為已知單位不一致風險；現況 book_editions.created_at/updated_at 不參與任何
> 讀取路徑，故未爆發。

#### master_books

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | `master_{毫秒}_{primaryEditionId.hashCode}`（`_createNewMasterBook` 產生） | 非空，PK 唯一 | 主書籍唯一識別碼。**與 domain-map 條目衝突**：`docs/spec/version-management/domain-map.md` §3 載「masterBookId 以 `mb_` 為前綴」，該前綴僅存於 `master_book_constants.dart` 常數，建立路徑未使用；本欄為實證現況，domain-map 條目待校正（0.38.1-W11-003 追蹤） |
| original_title | TEXT | 自由字串 | NOT NULL | `_createNewMasterBook` 預設 '未定名書籍' |
| original_isbn | TEXT，nullable | ISBN 字串 | 無約束 | `findByOriginalIsbn` 精確比對查詢鍵 |
| original_authors | TEXT | JSON array（`DatabaseJsonUtils.encodeJsonList`） | NOT NULL | 讀取端 `parseJsonList` 還原 |
| original_language | TEXT，nullable | 語言代碼字串 | 無約束 | — |
| first_published_date | INTEGER，nullable | 毫秒 epoch | — | — |
| primary_edition_id | TEXT | 同 book_editions.id | DDL nullable；FK -> book_editions(id)（0.38.1-W10-008，ON DELETE NO ACTION） | 主要版本指標。**有效語意為非 NULL**：entity `primaryEditionId` 非空 + 讀取端非空 cast（`as String`）——NULL 列會在讀取時 cast 失敗（W10-008 因此不用 SET NULL：會把 FK 保護轉為讀取期 crash）。referent 保證見 A.3 INV-V01 |
| created_at / updated_at | INTEGER | 毫秒 epoch（repository 路徑） | NOT NULL | `update` 以 entity createdAt 重寫 created_at、updated_at 固定重寫為 now 毫秒 |

#### book_editions

| 欄位 | 型別 | 單位/格式 | 值域 | 說明 |
|------|------|----------|------|------|
| id | TEXT | 同 books.id（UC-08 設計：edition id 與 books.id 相同） | 非空，PK 唯一 | `findByBookId` 以 `id = ?` 查詢即依此設計 |
| book_id | TEXT | 同 books.id | NOT NULL，FK -> books(id) ON DELETE CASCADE | `_bookEditionToMap` 寫入 `book_id = editionId`（與 id 同值，INV-V03） |
| master_book_id | TEXT，nullable | 同 master_books.id | FK -> master_books(id) ON DELETE SET NULL | NULL = 未關聯主書籍（獨立書籍）；`linkToMasterBook` / `unlinkFromMasterBook` 維護 |
| relationship_type | TEXT | `VersionRelationshipType.code` 字面 | `{'ORIGINAL_WORK','TRANSLATION_VARIANT','REVISED_EDITION','ADAPTATION','FORMAT_VARIANT'}`，DDL CHECK + DEFAULT 'ORIGINAL_WORK'（0.38.1-W10-008；值集與 enum codes 逐字一致） | 讀取端 `fromCode` 對非法/缺值靜默 fallback 為 originalWork（語意翻轉）；CHECK 使非法值在寫入時即顯性失敗（enum 值域 CHECK 採用判定，0.38.1-W10-007）。**還原路徑分歧**：本欄僅在 `SqliteBookEditionRepository` 讀取路徑被還原，`SqliteMasterBookRepository.getEditions` 路徑不讀本欄（見 A.3 殘留分歧段） |
| original_title / original_isbn / original_language | TEXT，nullable | 自由字串 | 無約束 | referent 保證補建的初始列（`_createInitialEdition`）此三欄為 NULL |
| is_translation | INTEGER | 布林（0/1） | NOT NULL DEFAULT 0（無 CHECK——布林 0/1 家族判定不採，0.38.1-W10-007） | 翻譯版旗標；決定 TranslationMetadata 還原路徑（INV-V08，僅 `SqliteBookEditionRepository` 路徑成立，見 A.3 殘留分歧段） |
| translators | TEXT，nullable | JSON array | 無約束 | — |
| target_language / source_language / translation_version | TEXT，nullable | 字串 | 無約束 | — |
| translation_published_date | INTEGER，nullable | 毫秒 epoch | — | — |
| parent_edition_id | TEXT，nullable | 同 book_editions.id | FK -> book_editions(id) ON DELETE SET NULL 自關聯 | **預留欄位（無寫入路徑）**：`_bookEditionToMap` 不含此欄，`lib/` 內無任何寫入點，現況恆 NULL |
| linked_at | INTEGER，nullable | 毫秒 epoch | — | 關聯時點；`unlinkFromMasterBook` 清 NULL |
| created_at / updated_at | INTEGER | 秒 epoch（DEFAULT 路徑，見時間戳現況表） | NOT NULL | 審計欄位，不參與 entity 還原；`update` 不維護 updated_at |

### A.2 狀態責任分層

三類：canonical（正式狀態，唯一寫入來源）／derived（衍生，只能 rebuild、不能反向
修正 canonical）／追蹤欄位（審計用，不參與業務計算）。

| 欄位/表 | 分層 | 說明 |
|--------|------|------|
| master_books 表 | canonical | 版本群唯一正式來源；寫入路徑 `DefaultVersionManager`（mergeBooks / separateEdition / setPrimaryEdition）經 `SqliteMasterBookRepository` |
| master_books.primary_edition_id | canonical（指標） | 三條寫入路徑：建立時指定（`_createNewMasterBook` 以 book1Id 為主版本）、`setPrimaryEdition` 顯式切換、`SqliteMasterBookRepository.update` 以 `_masterBookToMap` 整列覆寫（本欄隨 entity 值一併寫回） |
| book_editions 表 | canonical | 版本列與 master 關聯的唯一正式來源 |
| book_editions.linked_at | 追蹤欄位 | 關聯時點審計；不參與業務判斷 |
| book_editions.parent_edition_id | 預留欄位 | 無寫入路徑，恆 NULL（A.1） |
| book_editions.created_at / updated_at | 追蹤欄位 | DEFAULT 秒寫入、不讀取、update 不維護 |
| BookEdition entity 的 relationshipType 等 | derived（讀取還原） | `SqliteBookEditionRepository._mapToBookEdition` 由列值還原；TranslationMetadata 還原條件見 INV-V08。**僅該路徑成立**：`SqliteMasterBookRepository._mapToBookEdition`（`getEditions` 路徑）不讀 relationship_type 亦不建 translationMetadata，還原值恆為 entity 建構子預設（見 A.3 殘留分歧段） |

### A.3 不變式清單

陳述本身（不含由哪一層保證——歸屬決策見 B.1）。供
`docs/spec/version-management/domain-map.md`「Bundle 不變式清單」小節互相引用
（domain-map 補欄由 0.38.1-W10-006 並行處理，本文件不改 domain-map）。

| 編號 | 不變式 | 對應 domain-map 條目 |
|------|--------|----------------------|
| INV-V01 | master_books.primary_edition_id 必指向既有 book_editions 列（referent 保證）。兩條路徑的機制不同：**mergeBooks** 在 `save(master)` 前以 `_createInitialEdition` 為尚無版本列的書補建 ORIGINAL_WORK 列（edition id = books.id，步驟 1b）；**separateEdition** 無補建呼叫，referent 由前置存在性檢查保證——`findById(editionId)` 回 null 即 `OperationResult.failure` 提前返回，能走到 `save(master)` 表示該 edition 列必已存在 | 本文件新增（DDL FK 0.38.1-W10-008 + `default_version_manager.dart` 步驟 1b / separateEdition 步驟 1 承載） |
| INV-V02 | relationship_type 值域 = `VersionRelationshipType` 5 codes，與 enum 定義逐字一致。**寫入端全域成立；讀取端還原僅 `SqliteBookEditionRepository` 路徑成立**（殘留分歧段） | 本文件新增（DDL CHECK 承載，0.38.1-W10-008） |
| INV-V03 | book_editions.id 與 books.id 同值（UC-08 設計）；book_id 欄與 id 欄同值（repository 寫入現況） | 本文件新增（僅存於 DDL 註解與 `_bookEditionToMap` 實作） |
| INV-V04 | 循環引用建構順序：edition（master_book_id NULL）→ master → `linkToMasterBook` UPDATE 回填。master_books.primary_edition_id 與 book_editions.master_book_id 互指，兩欄皆 nullable 使 immediate FK 下此順序可行，無需 DEFERRABLE | 本文件新增（schema 註解 0.38.1-W10-008 承載） |
| INV-V05 | repository 寫入路徑下 master_books.primary_edition_id 恆非 NULL（DDL nullable 僅為循環引用建構所需的型別餘地；讀取端非空 cast 依賴此不變式） | 本文件新增 |
| INV-V06 | setPrimaryEdition 目標版本必屬於該主書籍（edition.masterBookId == masterBookId 前置驗證） | 本文件新增（`default_version_manager.dart` 步驟 2 承載） |
| INV-V07 | original_authors / translators 為 JSON array round-trip（`encodeJsonList` / `parseJsonList`） | 本文件新增 |
| INV-V08 | is_translation=1 時 TranslationMetadata 還原需 target_language 與 source_language 皆非 NULL，任一缺失則靜默還原為 null（讀取端寬鬆現況，非錯誤路徑）。**僅 `SqliteBookEditionRepository` 路徑成立**（殘留分歧段） | `docs/spec/version-management/domain-map.md` §3 BookEdition「isTranslation = true 時 translationMetadata 應非 null」——**兩者語意相反**：domain-map 為 domain 端不變式，本條為讀取端寬鬆現況。domain-map 條目與實作的落差由 0.38.1-W11-003 追蹤 |

> **已修復讀取路徑地雷（0.38.1-W10-010）**：`SqliteMasterBookRepository._mapToBookEdition`
> 原讀取 `row['title']`（book_editions DDL 無 title 欄，任何非空結果列
> `null as String` cast 失敗使 `getEditions` 一律 `StorageException.readError`），
> 且 `_createDummyMetadata` 回傳 null 佔位。0.38.1-W10-010 修復：title 對齊
> `SqliteBookEditionRepository._mapToBookEdition` 同表映射語意
> （`original_title` 回退空字串），metadata 改為實際 `BookEditionMetadata`；
> 非空結果列測試見 `sqlite_master_book_repository_test.dart` TC-076f / TC-076g。

#### 殘留分歧：同表兩套讀取語意

`book_editions` 由兩個 repository 各自映射，0.38.1-W10-010 只對齊了 title 與 metadata
兩處，**relationshipType 與 translationMetadata 的分歧仍在**。逐欄現況：

| 還原欄位 | `SqliteBookEditionRepository._mapToBookEdition` | `SqliteMasterBookRepository._mapToBookEdition`（`getEditions` 路徑） |
|---------|-----------------------------------------------|--------------------------------------------------------------|
| relationshipType | 讀 `relationship_type` 欄，經 `VersionRelationshipType.fromCode` 還原（缺值 fallback `'ORIGINAL_WORK'`） | **不讀該欄**，走 entity 建構子預設 → 恆為 `originalWork` |
| translationMetadata | `is_translation == 1` 時經 `_parseTranslationMetadata` 由語言欄還原 | **不建構**，走建構子預設 → 恆為 `null` |
| title / originalTitle / metadata | `original_title` 回退空字串；`metadata` 為實際 `BookEditionMetadata` | 同左（0.38.1-W10-010 已對齊） |

**後果**：經 `getEditions(masterBookId)` 取得的 `BookEdition`，其 `relationshipType`
一律為 `originalWork`、`translationMetadata` 一律為 `null`，與資料庫實際列值無關。
凡以該路徑的回傳值判斷版本關係或翻譯資訊者，讀到的是預設值而非持久化值；
經 `SqliteBookEditionRepository`（`findById` / `findTranslations` /
`findByRelationshipType`）取得的同一列則還原正確。

**追蹤**：0.38.1-W10-011（收斂兩路徑映射語意 + 雙路徑讀取一致性測試）。該 ticket 的
驗收條件之一為「同表映射語意收斂或分歧顯性記錄於 SPEC-016」——本段即該記錄。

### A.4 交易邊界

哪些寫入必須一起成立（原子性要求）。不含 isolation level（屬 B 區）。

| 交易邊界 | 涵蓋寫入 | 說明 |
|---------|---------|------|
| 版本合併（mergeBooks） | 0-2 筆 edition INSERT（referent 補建）+ 0-1 筆 master INSERT + 2 次 link UPDATE | **現況為逐步 await，無交易包裹**（`default_version_manager.dart`）；中途失敗會留下部分狀態（如 master 已建但未 link），錯誤以 `VERSION.MERGE.FAILED` 事件 + `OperationResult.failure` 浮出，無回滾（現況事實陳述，非本文件新增約束） |
| 版本分離（separateEdition） | unlink UPDATE + master INSERT + link UPDATE | 同上，無交易包裹 |
| 主版本切換（setPrimaryEdition） | master_books 單列 UPDATE | 單語句天然原子 |
| 單列 save / update / delete | 各單表單列 | 天然原子 |

### A.5 錯誤語意契約

唯一鍵衝突／外鍵違反／驗證失敗對應哪個 domain 例外，跨資料庫引擎成立（error
translation 邊界）。

| 資料庫錯誤類型 | 對應 domain 例外 | 觸發情境 |
|--------------|------------------|---------|
| PK 衝突（master_books.id / book_editions.id） | `StorageException.writeError('MasterBook'/'BookEdition')`（save 無 conflictAlgorithm，ABORT 後由 repository catch 包裝） | 同 id 重複 save；無 upsert 消解設計（與 books 的 replace 不同） |
| FK violation（primary_edition_id / book_id / master_book_id / parent_edition_id） | `StorageException.writeError` | referent 缺失寫入；`PRAGMA foreign_keys=ON` 使違反在寫入時被擋。primary_edition_id 的主要風險已由 INV-V01 referent 保證流程消解 |
| CHECK 違反（relationship_type） | `StorageException.writeError` | 非 enum code 寫入（0.38.1-W10-008 後寫入時即失敗） |
| 讀取失敗（含 cast 失敗） | `StorageException.readError('MasterBook'/'BookEdition')` | 查詢例外統一包裝（A.3 原 `row['title']` cast 失敗路徑已由 0.38.1-W10-010 修復） |
| 刪除失敗 | `StorageException.general` | delete 路徑統一包裝 |
| 更新目標不存在（linkToMasterBook / unlinkFromMasterBook / update / setPrimaryEdition） | **不拋例外**：UPDATE 0 列靜默返回（無 warning 日誌） | 目標列不存在時懸掛寫入靜默失效；mergeBooks 路徑已由 INV-V01 補建消解，repository API 單獨呼叫仍為靜默語意（現況事實） |
| 業務驗證失敗 | `BusinessException.notFound` / `BusinessException.operationFailed`，由 `OperationResult.failure` 承載不上拋；mergeBooks 失敗另發 `VERSION.MERGE.FAILED` 事件 | 同書合併、主書籍不存在、版本不屬於主書籍等前置守門 |

### A.6 恢復模型

備份還原後的資料驗證方式。

| 情境 | 驗證方式 |
|------|---------|
| 備份/還原 | 檔案層級複製（整份 DB 檔），非逐表匯出（全庫共用機制，詳述見 SPEC-014 A.6） |
| 完整性驗證 | `DatabaseSchema.integrityChecks` 於 `_onOpen` 執行：`PRAGMA integrity_check` + `PRAGMA foreign_key_check` + `SELECT COUNT(*) FROM master_books` / `book_editions`。**語句會執行但結果未被檢視**，現況無任何違反出口；觸發條件為非測試環境（機制詳述見 SPEC-014 A.6，全庫共用同一實作）。primary_edition_id 自 0.38.1-W10-008 宣告 FK 後**進入 `foreign_key_check` 的掃描範圍**，但該 PRAGMA 的回傳列現況從未被讀取，懸掛引用不會產生任何日誌或例外 |
| Seed | 兩表皆無 seed 資料 |

---

## B 區：實作綁定（DB-specific）

> 本區內容綁定 SQLite/sqflite。資料庫遷移時需依新引擎重寫本區，A 區不受影響。

### B.1 保證層歸屬

每條不變式的保證層。本表實際使用三種歸屬：雙層（DB + 應用層）／DB 約束 + 應用層／
應用層。歸屬本身是綁定決策，A 區不變式陳述不因換 DB 而變。

歸屬理由欄採預設值 + 例外展開：預設一格帶過，僅有爭議或多層條目才展開理由。

| 不變式編號 | 保證層 | 歸屬理由 |
|-----------|--------|---------|
| INV-V01 | 雙層（DB FK + 應用層流程） | FK 攔懸掛寫入（懸掛引用顯性化即 FK 的採用理由，0.38.1-W10-007）；referent 保證流程為 FK 的強制配套（0.38.1-W10-008 同票落地，兩者不可拆），mergeBooks 走 `_createInitialEdition` 補建、separateEdition 走前置存在性檢查（A.3 INV-V01） |
| INV-V02 | DB 約束 + 應用層 | DDL CHECK 攔寫入；讀取端 fromCode fallback 為殘留防線（該 fallback 僅存在於 `SqliteBookEditionRepository` 路徑，A.3 殘留分歧段） |
| INV-V03 | 應用層 | UC-08 設計約定 + `_bookEditionToMap` 字面實作；無 DB 機制可表達「與他表 PK 同值」 |
| INV-V04 | 應用層（流程順序） | immediate FK 下由呼叫順序保證；SQLite 支援 DEFERRABLE 但現況不需（schema 註解明載） |
| INV-V05 | 應用層 | 寫入路徑恆帶 primaryEditionId；DDL 保持 nullable 是 INV-V04 建構順序的前提，不可改 NOT NULL |
| INV-V06 | 應用層 | `setPrimaryEdition` 前置驗證；無 DDL 承載（跨表條件約束 SQLite 無法以 CHECK 表達） |
| INV-V07 | 應用層 | 寫讀路徑唯一（`DatabaseJsonUtils`）；非法 JSON 於解碼時浮出 |
| INV-V08 | 應用層 | `_parseTranslationMetadata` 條件還原；靜默 null 為現況設計。`SqliteMasterBookRepository` 路徑無此還原邏輯（A.3 殘留分歧段） |

### B.2 邊界行為的引擎機制

| 邊界行為 | 引擎機制 | 說明 |
|---------|---------|------|
| 插入衝突處理 | 無 conflictAlgorithm（sqflite 預設 ABORT） | 兩表皆無 OR REPLACE / OR IGNORE 消解設計；PK 衝突一律 ABORT 後包裝 |
| FK 刪除策略 | primary_edition_id：**NO ACTION**（預設，0.38.1-W10-008 決策——不用 SET NULL，因讀取端非空 cast 會把 FK 保護轉為讀取期 crash）；book_editions.book_id：CASCADE（刪書連動刪版本列）；book_editions.master_book_id：SET NULL（刪 master 使版本回獨立狀態）；parent_edition_id：SET NULL | 刪除被 primary 引用的 edition 會被 FK 擋下（NO ACTION + `PRAGMA foreign_keys=ON`）；刪 master 不受 primary_edition_id 阻擋（FK 方向為 master -> edition） |
| 循環引用建表 | SQLite 允許 CREATE TABLE 時引用尚未建立的父表（master_books 於 `allCreateStatements` 中早於 book_editions 建立），FK 於 DML 時才檢查 | schema 註解（0.38.1-W10-008）明載 |
| CHECK 違反例外 | `DatabaseException` 無型別化；SQLite conflict resolution 不消解 CHECK / FK violation（0.38.1-W10-007 實證，全庫論證見 SPEC-014 B.2） | repository 包裝為 `StorageException`（A.5 一致） |
| DEFAULT 生效路徑 | master_books 二時間欄 DEFAULT 秒 **dormant**（repository 恆顯式寫毫秒）；book_editions 二時間欄 DEFAULT 秒 **active**（repository 不寫，DEFAULT 為唯一寫入路徑） | 同 DDL 型態兩種生效狀態，A.1 時間戳現況表的機制面解釋 |
| 索引 | idx_master_books_original_title / original_isbn / primary_edition；idx_book_editions_book_id / master_book_id / relationship_type / is_translation | 查詢路徑：findByOriginalIsbn、searchByOriginalTitle（LIKE）、getEditions（master_book_id）、findTranslations、findByRelationshipType |

### B.3 Schema 演進策略與 Seed 資料政策

| 項目 | 決策 | 說明 |
|------|------|------|
| Schema 演進策略 | **pre-1.0 drop+rebuild**（`currentVersion=1`、`migrationScripts={}`） | 沿用全庫既定 ADR（W2-023 ADR-4；詳述見 SPEC-014 B.3，本文件不複決）。relationship_type CHECK 與 primary_edition_id FK 已於窗口內落地（0.38.1-W10-008）；1.0 上架後窗口關閉，後續約束補強需 onUpgrade 12 步表重建（含 `PRAGMA foreign_keys OFF/ON`） |
| migration 治理旗標 | 不要（合法終態，非延後） | 0.38.1-W10-001 全庫單一判定；重新評估載體為本節 |
| Seed 資料政策 | 無 seed | 兩表資料全部來自執行期寫入；本 domain 現況 dormant（無 DI 接線），production 存量為零 |

---

## 欄位 × 既有載體對照表

逐欄標「新建／引用既有」，避免與既有載體內容重複。本文件只新建既有載體缺的欄位；
其餘以引用連結取代複寫。

| 欄位/章節 | 承載狀態 | 既有載體 | 說明 |
|----------|---------|---------|------|
| 表/欄位語意（單位/值域/格式） | 部分承載，本文件補跨表單位對照與預留欄位標示 | `database_schema.dart` DDL 註解（0.38.1-W10-008 更新）、SPEC-009 功能行為 | 兩表 created_at 單位不一致、parent_edition_id 無寫入路徑為本文件首創 |
| primary_edition_id FK 語意與 referent 保證 | 部分承載，本文件集中為契約條目 | schema 註解 + `default_version_manager.dart` 1b 步驟註解（0.38.1-W10-008） | INV-V01 / INV-V04 / INV-V05 為註解語意的規範化 |
| 不變式陳述 | 部分承載，本文件補完整清單並附編號 | `docs/spec/version-management/domain-map.md`（補欄由 0.38.1-W10-006 並行處理） | INV-V08 引用 domain-map 對應條目並顯性標示語意落差；其餘 7 條為本文件新增。domain-map §3 另有三處與現況矛盾（`mb_` 前綴、translationMetadata 非 null、relationship_type 列舉），修正由 0.38.1-W11-003 追蹤 |
| 契約 ↔ 測試對應 | 已對應 | `docs/traceability.yaml` 第三軸 `data_contract_tests`（0.38.1-W10-005 建立） | 該軸共 23 條涵蓋三冊 INV 編號，其中 INV-V01~V08 屬本文件；以 `spec` 欄消歧同名編號。初查覆蓋分佈（全軸）：covered 7 / partial 7 / gap 8 / no_test_needed 1；補測試由 0.38.1-W10-012 承接 |
| 可攜性分區 / 狀態責任分層 / 交易邊界 / 錯誤語意 / 恢復模型 / 保證層歸屬 | 新建 | 無 | 依模板 |
| Schema 演進策略 | 引用既有 | SPEC-014 B.3（全庫 ADR 詳述） | 本文件僅載 version-management 面事實 |

## 適用判準（本文件是否需要撰寫）

依 `data-layer-contract-methodology.md` 兩正交旗標判斷：

| 旗標 | 判定 | 理由 |
|------|------|------|
| 契約文件 | 要 | 0.38.1-W10-001 逐表群判定：relationship_type 值域、primary_edition_id FK 缺宣告的歸屬決策（循環 FK 取捨）必須顯性化——FK 已由 0.38.1-W10-008 落地，本文件承載其語意與 referent 保證流程 |
| migration 治理 | 不要 | 全庫單一判定（0.38.1-W10-001）；合法終態，載體為 B.3 |
| dormant 豁免（如適用） | 不適用（雖符合 dormant 前提仍撰寫） | 兩表確為 dormant——`lib/` 內無 `SqliteMasterBookRepository` / `SqliteBookEditionRepository` / `DefaultVersionManager` 的注入點，僅測試使用（三軸交叉驗證證據見 0.38.1-W10-007）。不走 `data-layer-contract-methodology.md` 第 2.1 節豁免的理由：本 domain 是全庫唯一具循環 FK 的表對，primary_edition_id 的 NO ACTION 取捨、建構順序約束、relationship_type CHECK 值域屬接線前即需固定的設計決策；豁免會使 0.38.1-W10-008 的 FK/CHECK 落地失去語意載體 |

**分冊自評**（依模板 v1.2.0 分冊判準三條）：

| 判準 | 自評 |
|------|------|
| 1. per-domain 放置 | 符合。兩表置於 `docs/spec/version-management/` |
| 2. `domain` 單值上限 | 符合。frontmatter `domain: version-management` 單值 |
| 3. 寫入者群／錯誤語意模式分異即再分冊 | 兩表不拆。寫入者群分為 `SqliteMasterBookRepository`（master_books）與 `SqliteBookEditionRepository`（book_editions），但兩表由循環 FK 互指且建構順序互相約束（INV-V04），拆冊會使單一建構順序的約束跨兩份契約敘述；錯誤語意模式兩表一致（皆 `StorageException.writeError` / `readError` 包裝，A.5） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-07-25 | 初始版本（0.38.1-W10-003，master_books / book_editions 契約） |
| 1.1 | 2026-07-25 | A.3 讀取路徑地雷框改為已修復（title 對齊同表映射語意 + metadata 實體化）、A.5 讀取失敗列同步（0.38.1-W10-010） |
| 1.2 | 2026-07-26 | 技術審查修正（0.38.1-W11-002，findings 來源 0.38.1-W11-001）：A.3 新增殘留分歧段（`getEditions` 路徑 relationshipType / translationMetadata 不還原，解 0.38.1-W10-011 驗收條件）、A.1/A.2/B.1 對應欄位標註分歧範圍、INV-V01 拆兩條 referent 保證機制、INV-V08 對應欄改引用 domain-map 並標語意落差、A.1 master_books.id 標示 domain-map 條目衝突、A.2 補 primary_edition_id 第三條寫入路徑、A.6 完整性驗證改述、對照表引用 traceability.yaml 第三軸、frontmatter 版本同步與 SPEC-009 重複編號註記、適用判準補 dormant 豁免列與分冊自評、子代號改可讀敘述 |

| 1.3 | 2026-07-26 | frontmatter `related_specs` 註解改述（0.38.1-W11-004）：SPEC-009 重複編號已治理（QR frame 規格改號 SPEC-017、兩份檔名改 ID 前綴式），註解由「待治理消歧」改為「SPEC-009 指向何檔」的解析說明 |

---

**Spec Updated**: 2026-07-26 | **Version**: 1.3.0 — frontmatter SPEC-009 消歧註解同步編號治理結果（0.38.1-W11-004）
**Version**: 1.2.0 — 技術正確性與跨冊一致性修正（0.38.1-W11-002）
**Version**: 1.1.0 — A.3 地雷框更新為已修復（0.38.1-W10-010）
**Version**: 1.0.0 — master_books / book_editions 資料契約初版（primary_edition_id FK 語意與 referent 保證流程、relationship_type 5 codes CHECK、循環引用建構順序、跨表時間戳單位不一致與 dormant 接線現況）
