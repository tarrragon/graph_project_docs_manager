---
id: DOMAIN-MAP-data-management
domain: "data-management"
source_specs: [SPEC-004, SPEC-STORAGE-ISOLATION, SPEC-010]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — data-management

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-004 / SPEC-STORAGE-ISOLATION / SPEC-010（FR 清單）交叉引用。

## 1. 目的

data-management domain 負責書目資料的儲存、匯入匯出、驗證、品質管理、Schema 遷移和衝突解決。涵蓋兩個獨立 aggregate（Book 和 Tag），多書城 storage 隔離，以及跨裝置同步準備。

## 2. 分層與依賴方向

**多 aggregate 形態**（Book + Tag 兩個獨立 aggregate）：
```
presentation (popup / overview — 歸 user-experience)
        │
read-model（資料品質分析、統計）
        │
domain service（驗證、衝突偵測、遷移）
        │
   +---------+---------+
   │                   │
Book aggregate    Tag aggregate（by-id 參照：Book.tagIds 引用 Tag.id）
   ▲                   ▲
   │                   │
 data（ChromeStorageAdapter、ExportManager）
        │ 外部依賴
        ▼
 core（ErrorCodes, EventBus）+ messaging（跨 context 通訊）
```

**依賴方向底線（不可違反）**：

- domain 不得 import data / presentation / UI 框架 / Chrome Storage API。違反則喪失純函式可測性。
- Book aggregate 與 Tag aggregate 間僅允許 by-id 參照（Book.tagIds 陣列持有 Tag.id），禁直接嵌入。違反則破壞交易一致性邊界。
- read-model 依賴 aggregate，不反向依賴。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Book Aggregate | aggregate root | BookSchemaV2（欄位定義、SCHEMA_VERSION）、ReadingStatus 列舉（6 種）、isManualStatus 狀態追蹤、Book 欄位驗證 | Tag 結構、Storage 適配器 | `src/data-management/BookSchemaV2.js` | unit：schema 驗證、狀態轉換規則 | 已實作 |
| Tag Aggregate | aggregate root | TagSchema（TagCategory + Tag）、唯一鍵語意（parentId+name scoped）、TAG_TREE_MAX_DEPTH、makeCategoryKey | Book 關聯、Storage 適配器 | `src/data-management/TagSchema.js` | unit：schema 驗證、樹狀結構不變式 | 已實作 |
| Validation & Quality | domain service | DataValidationService、ValidationEngine、DataQualityAnalyzer、DataNormalizationService、PlatformRuleManager | Storage I/O | `src/background/domains/data-management/services/` | unit + integration：驗證規則、品質評估 | 已實作 |
| Schema Migration | domain service | SchemaMigrationService、cover-to-reader migration、v1-to-v2 migration | 具體 Storage 寫入 | `src/data-management/migration/` | unit：遷移規則、冪等性、回滾 | 已實作 |
| Conflict Detection | domain service | ConflictDetectionService、SyncConflictResolver | 網路 I/O | `src/background/domains/data-management/services/` | unit：衝突偵測規則、LWW 解決策略 | 已實作 |
| Sync Coordination | saga / process manager | CrossDeviceSyncService、SyncProgressTracker、SynchronizationOrchestrator、CacheManagementService | 網路傳輸實作 | `src/background/domains/data-management/services/` | unit（狀態機）+ integration：同步流程、重試 | 已實作 |
| Tag Presets | supporting VO | 賴永祥分類法預裝資料（chinese-classification.json）、DEFAULT_TAG_CATEGORIES | 載入機制（歸 infra） | `src/data-management/presets/` | unit：預裝資料完整性 | 已實作 |
| Storage Adapter | 非 domain（infra） | ChromeStorageAdapter、LocalStorageAdapter、tag-storage-adapter、platformBooksKey、saveBooksWrapper、雙形態容錯 | domain 計算 | `src/storage/` | repository test：讀寫正確性、配額管理 | 已實作 |
| Export System | 非 domain（infra） | ExportManager、BookDataExporter、JsonExportHandler、CsvExportHandler、ExcelExportHandler、HandlerRegistry | domain 計算 | `src/export/` | integration：多格式匯出正確性 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Book Aggregate | readingStatus 必為 6 種列舉值之一；isManualStatus=true 時自動轉換不觸發；progress 範圍 0-100；id 必填 | 已實作 |
| Tag Aggregate | 同一 parentId 下 name 唯一（scoped uniqueness）；樹深度 <= TAG_TREE_MAX_DEPTH；無循環引用；isSystem=true 不可刪除 | 已實作 |
| Validation & Quality | 驗證規則集 required/format/range 覆蓋所有必填欄位；品質分數 0-100 | 已實作 |
| Schema Migration | 遷移冪等（重複執行結果相同）；失敗時 backup 保留供回滾；schema_version 單調遞增 | 已實作 |
| Conflict Detection | LWW 以 updatedAt 裁決；同 id 衝突必須產出解決方案 | 已實作 |
| Sync Coordination | 同步狀態機轉換有效；重試次數不超過上限；進度 0-100% 單調遞增 | 已實作 |
| Tag Presets | 預裝約 110 節點全部 isSystem=true；確定性 ID 前綴 sys_cat_ | 已實作 |
| Storage Adapter | 雙形態（Object/Array）容錯讀取正確；配額 > 95% 時阻擋寫入；saveBooksWrapper 保留原始容器結構 | 已實作 |
| Export System | 所有匯出格式（JSON/CSV/Excel）含必要欄位；進度追蹤 0-100% | 已實作 |

## 4. 邊界決策

### 4.1 Book 與 Tag 為獨立 aggregate

Book 透過 tagIds 陣列 by-id 參照 Tag，而非直接嵌入 Tag 物件。刪除 Tag 時自動從所有 Book.tagIds 中移除（cascade by-id cleanup），由 tag-storage-adapter 執行。兩個 aggregate 各自持有獨立不變式和一致性邊界。

### 4.2 同步功能歸 data-management 而非獨立 domain

V1（Chrome Extension）的同步服務散佈在 data-management/services/ 下（與 APP 獨立 synchronization domain 不同）。此為現況邊界，非目標邊界。同步協議層面的規格由 synchronization domain spec（SPEC-009）獨立定義。

### 4.3 多書城 Storage 隔離

各書城書目資料儲存在獨立 storage key（`{platformId}_books`），讀取時合併所有平台。`STORAGE_KEYS.READMOO_BOOKS` 保留向後相容。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| Book schema 修改 | domain | 修改 BookSchemaV2.js + migration |
| Tag 樹狀功能 | domain | 修改 TagSchema.js + tag-storage-adapter |
| 匯出格式新增 | data（infra） | 在 ExportManager 加 handler，不修改 domain |
| 同步策略調整 | domain | 修改 Sync Coordination bundle |
| 新書城 storage key | data（infra） | 在 Storage Adapter 加 platformBooksKey |

## 6. 觀察到的技術債（待追蹤）

- 同步功能散佈在 data-management 而非獨立 domain（與 APP 架構不一致，spec README 已記錄）
- SyncStrategyProcessor 和 RetryCoordinator 為簡化版（SPEC-004 FR-06 備註）
- BackupRecoveryService 標記但未實作（SPEC-004 FR-07）

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 儲存管理 | Storage Adapter | 非 domain（infra） |
| FR-02 匯出系統 | Export System | 非 domain（infra） |
| FR-03 資料驗證與品質 | Validation & Quality | domain service |
| FR-04 Schema 遷移 | Schema Migration | domain service |
| FR-05 衝突偵測與解決 | Conflict Detection | domain service |
| FR-06 跨設備同步 | Sync Coordination | saga（部分實作） |
| FR-07 備份恢復 | （未實作） | 待建票追蹤 |
| SPEC-STORAGE-ISOLATION | Storage Adapter | 多書城 key 隔離 |
| SPEC-010 Tag 樹狀 Model | Tag Aggregate + Tag Presets | 樹狀 category |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
