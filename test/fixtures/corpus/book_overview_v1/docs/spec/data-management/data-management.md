---
id: SPEC-004
title: "資料管理規格"
status: approved
source_proposal: PROP-002
created: "2026-03-30"
updated: "2026-04-03"
version: "1.1"
owner: ""

domain: data-management
subdomain: null

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07]
related_specs: [SPEC-001, SPEC-005]
implements_requirements: []
depends_on_domains: [core]
---

# 資料管理規格

## 概述

Data Management domain 負責資料儲存、匯入匯出、同步和品質管理。涵蓋 Chrome Storage 適配、匯出格式處理和跨設備同步準備。

## 功能需求

### FR-01: 儲存管理

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：Chrome Storage API 和 LocalStorage 的統一儲存介面。

**已實作元件**：

- [x] ChromeStorageAdapter（Chrome Storage API 整合、配額管理）
- [x] LocalStorageAdapter（備選儲存）
- [x] StorageLoadHandler / StorageSaveHandler / StorageCompletionHandler

**關鍵檔案**：`src/storage/`

---

### FR-02: 匯出系統

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：事件驅動的多格式匯出（JSON / CSV / Excel）。

**已實作元件**：

- [x] ExportManager 匯出流程協調
- [x] BookDataExporter 資料匯出邏輯
- [x] JsonExportHandler / CsvExportHandler / ExcelExportHandler
- [x] ProgressHandler 進度追蹤
- [x] HandlerRegistry 格式動態註冊

**關鍵檔案**：`src/export/`

---

### FR-03: 資料驗證與品質

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：資料驗證規則管理和品質分析。

**已實作元件**：

- [x] DataValidationService / ValidationEngine / ValidationBatchProcessor
- [x] DataQualityAnalyzer / QualityAssessmentService
- [x] DataNormalizationService
- [x] ValidationRuleManager / PlatformRuleManager

**關鍵檔案**：`src/background/domains/data-management/`, `src/data-management/`

---

### FR-04: Schema 遷移

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：資料庫結構版本管理和遷移執行。

**已實作元件**：

- [x] SchemaMigrationService

**關鍵檔案**：`src/data-management/`

---

### FR-05: 衝突偵測與解決

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：資料衝突偵測和解決策略。

**已實作元件**：

- [x] ConflictDetectionService（867 行）
- [x] SyncConflictResolver（434 行）

**關鍵檔案**：`src/background/domains/data-management/`

---

### FR-06: 跨設備同步

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | 部分實作 |

**描述**：多裝置資料同步協調。

**已實作元件**：

- [x] CrossDeviceSyncService（474 行）
- [x] SyncProgressTracker（463 行）
- [x] SynchronizationOrchestrator（596 行）
- [x] CacheManagementService（600 行）
- [ ] SyncStrategyProcessor（簡化版，201 行）
- [ ] RetryCoordinator（基本版，290 行）

**備註**：同步功能有基本架構，但策略處理和重試機制較簡化，需進一步評估是否滿足需求。相關 Ticket: 0.16.2-W1-001。

---

### FR-07: 備份恢復

| 項目 | 值 |
|------|-----|
| 優先級 | P2 |
| 狀態 | [ ] 未實作 |

**描述**：資料備份和災難恢復機制。

**現況**：協調器中標記但未實作 BackupRecoveryService。

---

---

## Book Schema v2 規格（v0.17.0 — PROP-007）

### 概述

Book Schema v2 是 PROP-007 tag-based model 對齊的核心變更。主要改動：
1. 閱讀狀態從 `isNew`/`isFinished` 布林改為 `readingStatus` 列舉（6 種）
2. 新增 `tagIds` 欄位（tag 引用陣列）
3. Schema 版本從 `2.0.0` 升級為 `3.0.0`
4. 新增 `tag_categories` 和 `tags` 獨立資料結構

### Schema v1 → v2 變更對照

| 欄位 | v1（Schema 2.0.0） | v2（Schema 3.0.0） | 變更類型 |
|------|-------------------|-------------------|---------|
| `isNew` | boolean, optional | **移除** | 刪除 |
| `isFinished` | boolean, optional | **移除** | 刪除 |
| `readingStatus` | string（4 種，僅 normalized） | string（6 種，必填） | 升級 |
| `tagIds` | 不存在 | array of string, optional | 新增 |
| `isManualStatus` | 不存在 | boolean, optional, default false | 新增 |
| `updatedAt` | 不存在 | ISO string, auto | 新增 |
| 其他欄位 | 不變 | 不變 | — |

### Book Schema v2 欄位定義

#### READMOO 平台 Schema（version: 3.0.0）

```javascript
READMOO: {
  version: '3.0.0',
  platform: 'READMOO',
  fields: {
    // === 必填欄位 ===
    id:            { type: 'string',  required: true },
    title:         { type: 'string',  required: true },
    readingStatus: { type: 'string',  required: true, enum: READING_STATUS_VALUES, default: 'unread' },

    // === 選填欄位 ===
    authors:       { type: 'array',   required: false, default: [] },
    publisher:     { type: 'string',  required: false, default: '' },
    progress:      { type: 'number',  required: false, min: 0, max: 100, default: 0 },
    type:          { type: 'string',  required: false, default: '' },
    cover:         { type: 'string',  required: false, default: '' },
    tagIds:        { type: 'array',   required: false, default: [], items: 'string' },
    isManualStatus:{ type: 'boolean', required: false, default: false },

    // === 自動欄位 ===
    extractedAt:   { type: 'string',  required: false, auto: true },
    updatedAt:     { type: 'string',  required: false, auto: true },
    source:        { type: 'string',  required: false, auto: true, default: 'readmoo' }
  }
}
```

#### 其他平台 Schema 變更

| 平台 | 變更 |
|------|------|
| KINDLE | 移除 `reading_progress` 物件 → 改用 `progress` number + `readingStatus` |
| KOBO | `reading_percentage` 改名為 `progress`，新增 `readingStatus` |
| BOOKWALKER | 新增 `readingStatus`、`tagIds` |
| BOOKS_COM | 新增 `readingStatus`、`tagIds` |

### 閱讀狀態列舉（ReadingStatus）

```javascript
const READING_STATUS = {
  UNREAD:    'unread',     // 未開始：已購買但未閱讀
  READING:   'reading',    // 閱讀中：progress > 0 且未完成
  FINISHED:  'finished',   // 已完成：閱讀完畢
  QUEUED:    'queued',     // 待讀：使用者標記的待讀清單
  ABANDONED: 'abandoned',  // 已放棄：使用者決定不再閱讀
  REFERENCE: 'reference'   // 參考用：非通讀型，作為參考保留
};

const READING_STATUS_VALUES = Object.values(READING_STATUS);
```

#### 狀態轉換規則

**追蹤機制**：`isManualStatus` 布林欄位（預設 false）用於區分手動和自動設定的狀態。

| 轉換類型 | 規則 | isManualStatus 變化 |
|---------|------|-------------------|
| 自動：unread → reading | progress 從 0 變為 > 0，且 `isManualStatus === false` | 不變（保持 false） |
| 自動：reading → finished | progress 達到 100，且 `isManualStatus === false` | 不變（保持 false） |
| 手動：任何 → queued | 使用者手動設定 | 設為 **true** |
| 手動：任何 → abandoned | 使用者手動設定 | 設為 **true** |
| 手動：任何 → reference | 使用者手動設定 | 設為 **true** |
| 手動：任何 → unread/reading/finished | 使用者手動重設為自動狀態 | 設為 **false**（恢復自動追蹤） |

**關鍵規則**：
- 當 `isManualStatus === true` 時，自動轉換**不觸發**，即使 progress 改變
- 使用者手動設定 queued/abandoned/reference → `isManualStatus` 設為 true
- 使用者手動重設為 unread/reading/finished → `isManualStatus` 設為 false（恢復自動追蹤）
- progress 欄位在任何狀態下都可更新（abandoned 的書仍可記錄 progress 變化）

#### v1 → v2 狀態對映

| v1 狀態 | v2 狀態 | 對映邏輯 |
|---------|---------|---------|
| isNew=true, isFinished=false | unread | 新書未讀 |
| isNew=false, isFinished=false, progress=0 | unread | 非新書但未開始 |
| isNew=false, isFinished=false, progress>0 | reading | 有進度但未完成 |
| isFinished=true | finished | 已完成 |
| isNew=true, isFinished=true | finished | 異常組合，以 finished 為準 |
| 兩者皆 undefined/null | unread | 缺失值預設為 unread |

### Tag 資料結構

#### tag_categories（標籤類別）

```javascript
// Chrome Storage key: 'tag_categories'
{
  "tag_categories": [
    {
      "id": "cat_001",                    // 唯一 ID，格式: cat_{timestamp}（系統預設用語義名稱如 cat_system_type）
      "name": "類別",                      // 顯示名稱
      "description": "書籍主題分類",        // 選填說明
      "color": "#4A90D9",                  // 顯示顏色（hex）
      "isSystem": true,                    // 系統預設 vs 使用者自訂
      "sortOrder": 0,                      // 排序順序
      "createdAt": "2026-04-03T00:00:00Z",
      "updatedAt": "2026-04-03T00:00:00Z"
    }
  ]
}
```

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| id | string | 是 | auto | 格式: `cat_{timestamp}` |
| name | string | 是 | — | 唯一，最大 50 字元 |
| description | string | 否 | '' | 最大 200 字元 |
| color | string | 否 | '#808080' | hex 色碼 |
| isSystem | boolean | 否 | false | 系統預設不可刪除 |
| sortOrder | number | 否 | 0 | 顯示排序 |
| createdAt | string | 是 | auto | ISO 8601 |
| updatedAt | string | 是 | auto | ISO 8601 |

#### tags（標籤）

```javascript
// Chrome Storage key: 'tags'
{
  "tags": [
    {
      "id": "tag_001",                     // 唯一 ID，格式: tag_{timestamp}（系統預設用語義名稱如 tag_novel）
      "name": "小說",                       // 顯示名稱
      "categoryId": "cat_001",             // 所屬類別 ID
      "isSystem": true,                    // 系統預設 vs 使用者自訂
      "sortOrder": 0,
      "createdAt": "2026-04-03T00:00:00Z",
      "updatedAt": "2026-04-03T00:00:00Z"
    }
  ]
}
```

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| id | string | 是 | auto | 格式: `tag_{timestamp}` |
| name | string | 是 | — | 同一 category 內唯一（大小寫不敏感），最大 50 字元 |
| categoryId | string | 是 | — | 引用 tag_categories.id |
| isSystem | boolean | 否 | false | 系統預設不可刪除 |
| sortOrder | number | 否 | 0 | 顯示排序 |
| createdAt | string | 是 | auto | ISO 8601 |
| updatedAt | string | 是 | auto | ISO 8601 |

> **設計決策**：v1.0 採用扁平 tag 結構（無 parentId）。樹狀 tag 需求（如中文圖書分類法的層級結構）延至 v0.20.0 再評估。加一個欄位永遠比移除容易。

#### Book ↔ Tag 關聯

書籍透過 `tagIds` 陣列引用 tag：

```javascript
// book.tagIds = ["tag_001", "tag_005", "tag_012"]
```

**關聯規則**：
- 一本書可有 0~N 個 tag（上限 100 個）
- 一個 tag 可被 0~N 本書引用
- 刪除 tag 時，自動從所有書籍的 tagIds 中移除
- 刪除 tag_category 時，其下所有 tag 一併刪除（cascade）

### 匯出欄位集更新

```javascript
FIELDS: {
  BASIC:      ['id', 'title', 'author', 'publisher'],
  EXTENDED:   ['id', 'title', 'author', 'publisher', 'publishDate', 'category', 'progress', 'readingStatus'],
  COMPLETE:   ['id', 'title', 'author', 'publisher', 'publishDate', 'category', 'progress', 'readingStatus', 'isbn', 'rating', 'tagIds', 'tags', 'notes', 'readingTime', 'price'],
  READING:    ['title', 'author', 'progress', 'readingStatus', 'rating', 'notes'],
  STATISTICS: ['category', 'readingStatus', 'progress', 'rating', 'readingTime']
}
```

變更：所有欄位集中的 `status` 改為 `readingStatus`，COMPLETE 中的 `tags` 保留（序列化為 tag 名稱陣列），新增 `tagIds`（原始 ID 陣列）。

### 與 Flutter App Schema 對應表

| Chrome Extension（v2） | Flutter App（v0.32.0） | 說明 |
|------------------------|----------------------|------|
| `id` (string) | `id` (String) | 相同 |
| `title` (string) | `title` (String) | 相同 |
| `authors` (array) | `authors` (List&lt;String&gt;) | 相同 |
| `readingStatus` (string enum) | `readingStatus` (ReadingStatus enum) | 值相同，型別不同 |
| `progress` (number 0-100) | `readingProgress` (double 0.0-1.0) | 需轉換：Extension / 100 = App |
| `tagIds` (array of string) | `tagIds` (List&lt;String&gt;) | 相同 |
| `isManualStatus` (boolean) | `isManualStatus` (bool) | 相同 |
| `cover` (string URL) | `coverUrl` (String) | 欄位名不同 |
| `publisher` (string) | `publisher` (String) | 相同 |
| `extractedAt` (ISO string) | `createdAt` (DateTime) | 欄位名不同 |
| `updatedAt` (ISO string) | `updatedAt` (DateTime) | 相同 |
| `source` (string) | `platform` (Platform enum) | 欄位名不同 |

**Interchange Format v2 轉換**：匯出時統一使用 Flutter App 的欄位名稱，匯入時自動轉換回 Extension 欄位名稱。完整轉換規則待定義於匯出規格章節。

---

## Chrome Storage 資料結構 v2 規格（v0.17.0 — PROP-007）

### 概述

Chrome Storage v2 將現有的單一 key 架構擴展為多 key 架構，新增 tag_categories 和 tags 獨立儲存，並修正配額設定。

### Storage Key 結構

#### v1（現有）

| Key | 內容 | 估計大小 |
|-----|------|---------|
| `readmoo_books` | `{books: [...], extractionTimestamp, extractionCount, extractionDuration, source}` | 依書籍數量 |
| `extraction_history` | 提取歷史 | 小 |
| `last_extraction` | 最後提取時間 | 極小 |
| `version_info` / `system_state` / ... | 系統狀態 | 極小 |

#### v2（新增）

| Key | 內容 | 估計大小 | 變更類型 |
|-----|------|---------|---------|
| `readmoo_books` | `{books: [...], ...}`（書籍欄位已更新為 Schema v2） | 依書籍數量 | **修改** |
| `tag_categories` | `[{id, name, description, color, isSystem, sortOrder, ...}]` | ~1KB（預估 20 個類別） | **新增** |
| `tags` | `[{id, name, categoryId, isSystem, sortOrder, ...}]` | ~5KB（預估 200 個標籤） | **新增** |
| `schema_version` | `"3.0.0"` | 極小 | **新增** |
| 其他既有 key | 不變 | — | 不變 |

### STORAGE_KEYS 常數更新

```javascript
const STORAGE_KEYS = {
  // === 資料儲存 ===
  READMOO_BOOKS: 'readmoo_books',
  TAG_CATEGORIES: 'tag_categories',       // v2 新增
  TAGS: 'tags',                           // v2 新增
  EXTRACTION_HISTORY: 'extraction_history',
  LAST_EXTRACTION: 'last_extraction',

  // === 版本管理 ===
  SCHEMA_VERSION: 'schema_version',       // v2 新增
  VERSION_INFO: 'version_info',
  VERSION_HISTORY: 'version_history',

  // === 系統狀態（不變）===
  SYSTEM_STATE: 'system_state',
  INSTALLATION_INFO: 'installation_info',
  SYSTEM_CONFIG: 'system_config',
  SYSTEM_SHUTDOWN_STATE: 'system_shutdown_state',
  LAST_SHUTDOWN_TIME: 'last_shutdown_time',
  STARTUP_FAILURE_REPORT: 'startup_failure_report'
};
```

### books 陣列內書籍物件變更

```javascript
// v1 書籍物件
{
  id: "...",
  title: "...",
  isNew: true,          // v2 移除
  isFinished: false,    // v2 移除
  progress: 50,
  ...
}

// v2 書籍物件
{
  id: "...",
  title: "...",
  readingStatus: "reading",   // v2 新增（取代 isNew/isFinished）
  progress: 50,
  tagIds: ["tag_001"],        // v2 新增
  updatedAt: "2026-04-03T00:00:00Z",  // v2 新增
  ...
}
```

### CRUD 操作介面

#### Tag Categories CRUD

| 操作 | 方法 | 說明 |
|------|------|------|
| 建立 | `createTagCategory({name, description?, color?})` | 自動生成 id（`cat_{timestamp}`），name 唯一性檢查 |
| 讀取全部 | `getAllTagCategories()` | 回傳完整陣列 |
| 讀取單一 | `getTagCategory(categoryId)` | 依 id 查詢 |
| 更新 | `updateTagCategory(categoryId, updates)` | 不可修改 id 和 isSystem |
| 刪除 | `deleteTagCategory(categoryId)` | isSystem=true 不可刪除，cascade 刪除所屬 tags |

#### Tags CRUD

| 操作 | 方法 | 說明 |
|------|------|------|
| 建立 | `createTag({name, categoryId})` | 自動生成 id（`tag_{timestamp}`），同 category 內 name 唯一 |
| 讀取全部 | `getAllTags()` | 回傳完整陣列 |
| 依類別讀取 | `getTagsByCategory(categoryId)` | 篩選特定類別的 tags |
| 依書籍讀取 | `getTagsForBook(bookId)` | 依書籍的 tagIds 解析完整 tag 物件 |
| 更新 | `updateTag(tagId, updates)` | 不可修改 id 和 isSystem |
| 刪除 | `deleteTag(tagId)` | isSystem=true 不可刪除，自動從所有書籍 tagIds 移除 |

#### Book-Tag 關聯操作

| 操作 | 方法 | 說明 |
|------|------|------|
| 新增 tag | `addTagToBook(bookId, tagId)` | tagId 加入書籍 tagIds（去重） |
| 移除 tag | `removeTagFromBook(bookId, tagId)` | 從書籍 tagIds 移除 |
| 批量設定 | `setBookTags(bookId, tagIds)` | 替換書籍所有 tagIds |
| 查詢書籍 | `getBooksByTag(tagId)` | 查詢含特定 tag 的所有書籍 |

### 配額管理更新

#### 配額設定修正

| 項目 | v1 | v2 | 說明 |
|------|----|----|------|
| maxSize | 10MB | **5MB**（5,242,880 bytes） | 修正為 Chrome Manifest V3 實際限制 |
| quotaWarningThreshold | 90% | **80%**（4MB） | tag 資料增加後提前預警 |
| compressionThreshold | 1KB | 1KB | 不變 |

#### 配額預估

| 資料類型 | 每筆大小 | 預估數量 | 預估總大小 |
|---------|---------|---------|-----------|
| 書籍（含 tagIds） | ~500 bytes | 1000 本 | ~500KB |
| 書籍（壓縮後） | ~250 bytes | 1000 本 | ~250KB |
| tag_categories | ~200 bytes | 20 個 | ~4KB |
| tags | ~150 bytes | 200 個 | ~30KB |
| 系統狀態等 | — | — | ~50KB |
| **總計（壓縮後）** | | | **~334KB** |

**結論**：5MB 限制下，即使 2000 本書 + 500 個 tag，壓縮後仍在 1MB 以內。配額風險低。

#### 配額超限處理策略

| 使用率 | 動作 |
|--------|------|
| < 80% | 正常運作 |
| 80% ~ 90% | 顯示配額警告，建議匯出備份 |
| 90% ~ 95% | 觸發自動清理（清理 extraction_history 等非核心資料） |
| > 95% | 阻止新增操作，強制要求清理或匯出 |

### 資料一致性保證

#### 原子操作

Tag 相關操作涉及多個 key，需確保一致性：

| 操作 | 涉及 key | 一致性要求 |
|------|---------|-----------|
| 刪除 tag | `tags` + `readmoo_books` | 先從所有書籍 tagIds 移除，再刪除 tag |
| 刪除 category | `tag_categories` + `tags` + `readmoo_books` | 先移除書籍引用，再刪除 tags，最後刪除 category |
| 匯入資料 | `readmoo_books` + `tag_categories` + `tags` | 先寫入 categories/tags，再寫入書籍 |

**失敗處理**：任一步驟失敗時，回滾已完成的步驟。使用事務日誌（暫存在 memory）記錄操作步驟，失敗時反向執行。

#### 引用完整性檢查

啟動時和匯入後執行引用完整性檢查：

| 檢查項 | 修復動作 |
|--------|---------|
| 書籍 tagIds 引用不存在的 tag | 移除無效 tagId |
| tag categoryId 引用不存在的 category | 移至預設 category 或刪除 tag |
| 孤立 tag（無任何書籍引用） | 保留（不自動刪除，使用者可能稍後使用） |

---

## 資料遷移規格 v1→v2（v0.17.0 — PROP-007）

### 概述

當使用者從 Schema 2.0.0（v1）升級至 Schema 3.0.0（v2）時，需自動執行資料遷移。遷移在 Extension 啟動時偵測並執行，對使用者透明。

### 遷移觸發條件

```
Extension 啟動
  → 讀取 chrome.storage.local['schema_version']
  → 值為 null 或 '2.0.0' → 觸發遷移
  → 值為 '3.0.0' → 跳過
  → 值為其他（未知版本） → 記錄 warning，嘗試遷移（視為 v1 處理）
  → 值格式無效（非 semver） → 記錄 error，重置為 null 後觸發遷移
```

### 遷移步驟（依序執行）

| 步驟 | 動作 | 涉及 key | 可回滾 |
|------|------|---------|--------|
| 0 | 備份原始資料至 `migration_backup` key | `readmoo_books` → `migration_backup` | — |
| 1 | 建立 `tag_categories` 預設資料 | `tag_categories`（新建） | 刪除 key |
| 2 | 建立 `tags` 空陣列 | `tags`（新建） | 刪除 key |
| 3 | 轉換 books 陣列中每本書的欄位 | `readmoo_books`（修改） | 從 backup 還原 |
| 4 | 寫入 `schema_version: '3.0.0'` | `schema_version`（新建） | 刪除 key |
| 5 | 刪除 `migration_backup`（遷移成功後） | `migration_backup`（刪除） | — |

### 步驟 1：預設 tag_categories

遷移時自動建立的預設類別：

```javascript
const DEFAULT_TAG_CATEGORIES = [
  { id: 'cat_system_type',   name: '書籍類型', isSystem: true, sortOrder: 0, color: '#7B68EE' },
  { id: 'cat_user_custom',   name: '自訂標籤', isSystem: false, sortOrder: 1, color: '#808080' }
];
// 設計決策：閱讀狀態由 readingStatus 欄位管理，不納入 tag 系統，避免雙重真相。
```

### 步驟 3：書籍欄位轉換規則

#### 閱讀狀態轉換（isNew/isFinished → readingStatus）

| isNew | isFinished | progress | 結果 readingStatus | 說明 |
|-------|-----------|----------|-------------------|------|
| true | false | 0 | `unread` | 新書未讀 |
| true | false | > 0 | `reading` | 新書已開始（罕見但可能） |
| false | false | 0 | `unread` | 非新但未開始 |
| false | false | > 0 | `reading` | 閱讀中 |
| false | true | 任何 | `finished` | 已完成 |
| true | true | 任何 | `finished` | 異常組合，以 finished 為準 |
| undefined | undefined | 0 | `unread` | 缺失值預設 |
| undefined | undefined | > 0 | `reading` | 缺失值依 progress 判斷 |
| undefined | undefined | 100 | `finished` | 缺失值依 progress 判斷 |

**轉換函式虛擬碼**：

```javascript
function migrateReadingStatus(book) {
  if (book.isFinished === true) return 'finished';
  if (book.progress >= 100) return 'finished';
  if (book.progress > 0) return 'reading';
  return 'unread';
}
```

#### 欄位增刪

| 操作 | 欄位 | 值 |
|------|------|-----|
| 刪除 | `isNew` | — |
| 刪除 | `isFinished` | — |
| 新增 | `readingStatus` | 由轉換函式決定 |
| 新增 | `tagIds` | `[]`（空陣列） |
| 新增 | `isManualStatus` | `false`（v1 資料都是系統自動判定的狀態） |
| 新增 | `updatedAt` | 遷移執行時間（ISO 8601） |

#### progress 值正規化

| 現有值 | 處理 |
|--------|------|
| number 0~100 | 保留 |
| object `{progress: N}` | 提取 N |
| string "50" | parseInt |
| null / undefined | 設為 0 |
| < 0 | 設為 0 |
| > 100 | 設為 100 |

### 邊界條件

| 條件 | 處理 | 說明 |
|------|------|------|
| books 陣列為空 | 正常遷移（只建立 categories/tags/version） | 新安裝或已清空 |
| books 陣列含 null 元素 | 跳過 null，記錄 warning | 資料損壞 |
| 書籍缺少 id 欄位 | 跳過該書，記錄 error | 無法識別的書籍 |
| 書籍欄位已是 v2 格式（有 readingStatus） | 跳過轉換，保留原值 | 部分遷移重入 |
| readmoo_books key 不存在 | 建立空結構並標記 v2 | 全新安裝 |
| readmoo_books 為壓縮格式 | 先解壓縮再遷移，完成後重新壓縮 | 壓縮相容 |
| 遷移過程中 Extension 被關閉 | 下次啟動時重新偵測並遷移 | 冪等設計 |

### 失敗處理策略

#### 失敗分類

| 失敗類型 | 處理 | 使用者訊息 |
|---------|------|-----------|
| 備份失敗（步驟 0） | 中止遷移，保持 v1 | 「資料遷移準備失敗，將以相容模式運行」 |
| 單本書轉換失敗（步驟 3） | 跳過該書（保留原始欄位），繼續其他書 | 記錄失敗數量 |
| 寫入失敗（步驟 3/4） | 從 backup 還原 readmoo_books，刪除 categories/tags/version | 「資料遷移失敗，已還原至原始狀態」 |
| 配額不足 | 中止遷移，保持 v1 | 「儲存空間不足，無法完成遷移」 |

#### 回滾流程

```
遷移失敗
  → 檢查 migration_backup 是否存在
    → 存在：還原 readmoo_books，刪除 tag_categories/tags/schema_version
    → 不存在：保持現狀，標記遷移失敗狀態
  → 設定 migration_failed: true（下次啟動時重試或提示使用者）
```

#### 冪等性保證

遷移設計為冪等操作——重複執行不會產生副作用：

| 重入場景 | 行為 |
|---------|------|
| schema_version 已是 3.0.0 | 跳過全部遷移 |
| tag_categories 已存在 | 跳過步驟 1 |
| 書籍已有 readingStatus | 跳過該書的欄位轉換 |
| migration_backup 已存在（上次遷移中斷） | 先從 backup 還原再重新遷移 |

### 遷移日誌

Chrome Extension 遷移 1000 本書預估不到 500ms，不需要進度通知。僅記錄起止和錯誤：

| 事件 | 方式 | 內容 |
|------|------|------|
| 遷移開始 | console.info | 「資料遷移 v1 → v2 開始（{total} 本書）」 |
| 遷移完成 | console.info | 「資料遷移完成：{success} 成功，{skipped} 跳過，耗時 {ms}ms」 |
| 遷移失敗 | console.error | 「資料遷移失敗：{reason}，已還原」 |

### 遷移後清理

遷移成功 30 天後（或使用者手動觸發），刪除 `migration_backup` 釋放空間。

---

## 需求變更通知

> **PROP-007 確認（2026-04-02）**：跨專案規格對齊提案已確認。
> **Roadmap 重整（2026-04-03）**：核心 model 重構從 v0.20.0 提前至 v0.17.0 實施。

### 資料結構變更

Chrome Storage 資料結構將在 v0.20.0 改為 **tag-based model**，與 Flutter App 對齊。現有的書籍分類方式將從階層式改為標籤式。

### 受影響的功能需求

以下 FR 將在 v0.17.0 進行重寫以配合新資料結構：

| FR | 名稱 | 影響說明 |
|----|------|---------|
| FR-01 | 儲存管理 | Chrome Storage 資料格式改為 tag-based |
| FR-02 | 匯出系統 | 匯出格式升級為 Interchange Format v2 |
| FR-05 | 衝突偵測與解決 | 配合新資料結構調整衝突偵測邏輯 |
| FR-06 | 跨設備同步 | 同步方案變更為 Google Drive（v2.0 階段） |

### 參考提案

- PROP-007: 跨專案規格對齊（完整版在 Flutter App 專案）
- PROP-002: 跨設備同步機制完善（部分被 PROP-007 更新）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-03-30 | 從 app-requirements-spec.md 遷移，盤點實作狀態 |
| 1.1 | 2026-04-02 | 新增需求變更通知：PROP-007 確認，v0.20.0 資料結構改為 tag-based |
| 1.2 | 2026-04-03 | 新增 Book Schema v2 完整規格（0.17.0-W1-002）：閱讀狀態 6 種、tag 結構、欄位定義、Flutter App 對應表 |
| 1.3 | 2026-04-03 | 新增 Chrome Storage v2 規格（0.17.0-W1-003）：多 key 架構、CRUD 介面、配額管理、一致性保證 |
| 1.4 | 2026-04-03 | 新增資料遷移 v1→v2 規格（0.17.0-W1-004）：轉換規則、邊界條件、失敗處理、冪等性 |
