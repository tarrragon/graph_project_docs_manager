---
id: DOMAIN-MAP-version-management
domain: "version-management"
source_specs: [SPEC-009]
related_usecases: [UC-08]
created: "2026-07-23"
updated: "2026-07-26"
---

# Domain Map — version-management

> 產出來源：0.38.1-W5-002。

## 1. 目的與 UC / DDD 正交關係

version-management domain 管理同一本書的不同版本（翻譯版、修訂版、不同出版社版本）：以 MasterBook 統一管理多個 BookEdition，透過相似度計算自動建議版本關聯。依賴 library（Book）和 `lib/core/`（errors，應用核心層）。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：多 aggregate（MasterBook + BookEdition）

```
presentation (VersionManagementViewModel)
        │
read-model（版本比較視圖）
        │
domain service（版本相似度計算 / 版本關聯建議）
        │
   +------------+
   │            │
MasterBook    BookEdition（by-id 參照 via masterBookId + editionId）
   ▲
   │
 data（MasterBookRepository impl）
```

**依賴方向底線**：
- version_management → library（Book）：合法，BookEdition 與 Book 關聯。
- version_management → `lib/core/`（errors）：合法，應用核心層依賴（非 domain-to-domain）。
- version_management 不 import 其他 domain。已驗證。
- library → version_management：已驗證存在反向依賴。此為雙向依賴，需關注是否應透過介面隔離。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| MasterBook | aggregate root | MasterBook 聚合根（masterBookId/originalTitle/originalAuthors/editions/primaryEditionId）+ 查詢方法（primaryEdition/translationEditions/getEditionsByLanguage）+ 變更方法（addEdition/removeEdition/setPrimaryEdition） | 版本相似度計算 | `lib/domains/version_management/entities/` | unit：addEdition 冪等、removeEdition 自動切換 primaryEditionId、不可變性 | 已實作 | N/A |
| BookEdition | supporting VO | BookEdition（editionId/masterBookId/title/isTranslation/relationshipType/translationMetadata/metadata）+ VersionRelationshipType 列舉 | 持久化 | `lib/domains/version_management/entities/` | unit：欄位正確性、Equatable 行為 | 已實作 | N/A |
| TranslationMetadata | supporting VO | TranslationMetadata（translator/translationLanguage/translationPublisher/translationDate）| UI 顯示 | `lib/domains/version_management/value_objects/` | unit：欄位驗證 | 已實作 | N/A |
| BookEditionMetadata | supporting VO | BookEditionMetadata（publisher/publishDate/isbn/language/pageCount/format/coverUrl）| UI 顯示 | `lib/domains/version_management/value_objects/` | unit：欄位完整性 | 已實作（定義於 entities/book_edition.dart 內） | N/A |
| VersionRelationshipType | supporting VO | 列舉 5 值（originalWork / translationVariant / revisedEdition / adaptation / formatVariant），對應 DB code `ORIGINAL_WORK` / `TRANSLATION_VARIANT` / `REVISED_EDITION` / `ADAPTATION` / `FORMAT_VARIANT` | 關係建立邏輯 | `lib/domains/version_management/enums/` | unit：列舉完整性（5 值皆有 code 與 displayName；`fromCode` 未知值 fallback 為 originalWork） | 已實作（實際位於 value_objects/version_relationship_type.dart，非 enums/） | N/A |
| VersionSimilarity | domain kernel（共享） | 版本相似度計算（書名/作者/ISBN 比對）+ 自動建議關聯 | UI 建議顯示 | `lib/domains/version_management/services/` | unit：相似度計算正確性 | 已實作 | N/A |

> 資料契約文件引用：本表無 data/infrastructure 列（MasterBookRepository 持久化屬 §2 data 層，未列 bundle）；契約分冊為 `docs/spec/version-management/SPEC-016-version-management-data-contract.md`（0.38.1-W10-003，涵蓋 master_books / book_editions）。

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| MasterBook | masterBookId 由建立路徑產生，格式 `master_{毫秒}_{primaryEditionId.hashCode}`（見下方註 1）；addEdition 同 editionId 時跳過（冪等）；removeEdition 移除 primaryEditionId 時自動改為剩餘第一個；createdAt 建立後不可變 |
| BookEdition | editionId 唯一且不可變；isTranslation = true **不保證** translationMetadata 非 null（見下方註 2） |
| TranslationMetadata | translationLanguage 為 ISO 639-1 或 BCP 47 格式 |

**註 1（masterBookId 前綴）**：唯一有生產呼叫端的建立路徑為 `DefaultVersionManager._createNewMasterBook`（`lib/domains/version_management/services/default_version_manager.dart:367`），產出 `master_{毫秒}_{primaryEditionId.hashCode}`，與 `docs/spec/version-management/SPEC-016-version-management-data-contract.md` A.1 `master_books.id` 欄一致。常數 `MasterBookConstants.masterBookIdPrefix = 'mb_'`（`constants/master_book_constants.dart:16`）目前僅被 `MasterBookFactory._generateMasterBookId`（`factories/master_book_factory.dart:377`）引用，而該 factory 在 `lib/` 內無呼叫端（僅測試使用），故 `mb_` 前綴不出現於持久化資料。本列先前記載的「以 `mb_` 為前綴」為 stale 敘述，已依實作校正。

**註 2（isTranslation 與 translationMetadata 的落差）**：本列原記載的「非 null」屬 domain 端期望，實作三層皆不承載，故改述為不保證：

| 層 | 現況 |
|---|---|
| entity 建構子 | `BookEdition` 的 `translationMetadata` 為可選具名參數且無 assert，`isTranslation = true` 時仍可為 null（`entities/book_edition.dart:51-53`） |
| 讀取端（`SqliteBookEditionRepository`） | `_parseTranslationMetadata` 在 `target_language` 或 `source_language` 任一為 NULL 時靜默回傳 null（`sqlite_book_edition_repository.dart:200`），即 SPEC-016 INV-V08 記載的讀取端寬鬆現況 |
| 讀取端（`SqliteMasterBookRepository`） | `_mapToBookEdition` 不建構 translationMetadata、亦不讀 `relationship_type`，`getEditions` 路徑還原值恆為建構子預設 null / originalWork（`sqlite_master_book_repository.dart:189-207`） |

「domain 端期望非 null」與「讀取端寬鬆」的落差屬已知分歧，由 0.38.1-W10-011 追蹤（同表雙映射器語意收斂）；SPEC-016 A.3 殘留分歧段記載同一事實。本列僅陳述實作現況，不預判該分歧的收斂方向。

## 4. 邊界決策

### 4.1 MasterBook 與 BookEdition 的關係

BookEdition 持有 masterBookId（by-id 參照），MasterBook 持有 editions 清單。MasterBook 是 aggregate root，BookEdition 是其內部實體。

### 4.2 library ↔ version_management 雙向依賴

library import version_management 的 VersionRelationshipType 和 BookEdition 等型別，用於書籍版本關聯顯示。此雙向依賴是技術債（見 §6），建議評估是否透過介面或事件解耦——例如 library 定義版本關聯介面、version_management 提供實作。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| MasterBook/Edition 修改 | domain | MasterBook aggregate + BookEdition。粒度：addEdition / removeEdition / setPrimaryEdition 各為一張 ticket |
| 版本相似度修改 | domain | VersionSimilarity kernel。粒度：ISBN/標題/作者/年份 各維度相似度可獨立修改 |
| 版本管理 UI | presentation | VersionManagementViewModel |

## 6. 觀察到的技術債（待追蹤）

- library ↔ version_management 雙向依賴
- IsbnUtils（version_management）與 Isbn VO（scanner）功能重疊

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（MasterBook） | MasterBook aggregate | domain |
| FR-2（BookEdition） | BookEdition VO | domain |
| FR-3（版本關係類型） | VersionRelationshipType VO | domain |
| FR-4（版本偵測與相似度計算） | VersionSimilarity kernel | domain |
| FR-5（翻譯偵測） | VersionSimilarity kernel | domain |
| FR-6（版本合併與分離） | MasterBook aggregate + domain service | domain |
| FR-7（Repository 介面） | 非 domain（infrastructure） | data |
| FR-8（版本管理事件） | MasterBook aggregate（事件發佈） | domain |
| FR-9（驗證與工具） | BookEdition VO + IsbnUtils | domain |
| FR-10（展示層） | 非 domain（presentation） | presentation |

---

**Last Updated**: 2026-07-26 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（無 data/infrastructure 列全 N/A，契約分冊待 W10-003 回填；template 2.2.0） | 0.38.1-W11-003 依實作校正 §3 三處 stale 斷言（masterBookId 前綴改 `master_{毫秒}_{hashCode}` 並註明 `mb_` 常數的未接線現況、isTranslation 與 translationMetadata 改述為不保證非 null 並標示 domain 端與讀取端落差、VersionRelationshipType 列舉改為實際 5 值與 DDL CHECK code；findings 來源 0.38.1-W11-001 R1/R2） | 0.38.1-W11-004 `source_specs` 由臨時消歧寫法 `SPEC-009-VM` 正規化為 `SPEC-009`（重複編號已治理，該號唯一指向 `SPEC-009-book-version-management.md`）
