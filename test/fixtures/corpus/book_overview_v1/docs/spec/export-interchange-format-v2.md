---
id: SPEC-EXPORT-V2
title: "Interchange Format v2 匯出規格"
status: approved
source_proposal: PROP-007
created: "2026-04-05"
updated: "2026-04-05"
version: "2.0.0"
owner: ""
domain: data-management
subdomain: export
related_usecases: [UC-02]
related_specs: []
---

# Interchange Format v2 匯出規格

**版本**: 2.0.0
**建立日期**: 2026-04-05
**來源**: PROP-007 tag-based model 對齊
**Ticket**: 0.17.2-W1-001

> **[SUPERSEDED 為跨專案 SSOT] 2026-06-02（W4-031.3）**：跨專案匯入匯出的單一權威格式（SSOT）已升級為 `docs/spec/book-interchange-v1.md`（**v3.0.0，everything-as-tags**）。本規格降為**本專案內部 v2 格式**：detector 仍辨識本格式（book-interchange-v1 §8 優先序 2）以相容既有匯出檔，但**新的跨專案匯出改用 book-interchange-v1 canonical**。本專案 adapter（W4-031.2）負責 book-interchange-v1 ↔ 內部 v2 model 雙向轉換（固定欄位↔tag）。
>
> **Why**：W4-031.3 reconciliation 確認 APP v0.32.0 確定走 everything-as-tags（已 ticket 化），canonical 採方案 A（everything-as-tags，對兩端無損）統一。本格式內部欄位定義仍有效，供本專案 v2 model 與 adapter 參考。

---

## 1. 概述

Interchange Format v2 是 PROP-007 tag-based book model 重構後的匯出/匯入資料交換格式。v2 新增 tag 結構、6 種閱讀狀態、以及版本元資料，同時維持對 v1 格式的匯入相容性。

**適用格式**: JSON、CSV
**適用場景**: UC-03（匯出備份）、UC-04（匯入恢復）、UC-05（跨設備同步）
**Schema Version**: 3.0.0（對應 `BookSchemaV2.SCHEMA_VERSION`）

---

## 2. 版本偵測機制

### 2.1 JSON 版本偵測

匯入時依以下順序判斷格式版本：

| 優先序 | 偵測條件 | 判定版本 |
|--------|---------|---------|
| 1 | 根物件含 `metadata.formatVersion` 且值以 `"2."` 開頭 | v2 |
| 2 | 根物件含 `metadata` 屬性且 books 陣列中任一物件含 `readingStatus` 欄位 | v2 |
| 3 | 根物件是陣列（無 metadata 包裝） | v1 |
| 4 | 根物件含 `books` 屬性但無 `metadata.formatVersion` | v1（含 metadata 的舊格式） |

**偵測實作虛擬碼**：

```javascript
function detectFormatVersion(data) {
  // v2: 明確的 formatVersion
  if (data?.metadata?.formatVersion?.startsWith('2.')) return 'v2'
  // v2: 有 metadata 且書籍含 readingStatus
  if (data?.metadata && Array.isArray(data.books) &&
      data.books.some(b => 'readingStatus' in b)) return 'v2'
  // v1: 純陣列
  if (Array.isArray(data)) return 'v1'
  // v1: 有 books 但無 formatVersion
  if (Array.isArray(data?.books)) return 'v1'
  // 無法辨識
  return null
}
```

### 2.2 CSV 版本偵測

| 偵測條件 | 判定版本 |
|---------|---------|
| 標題行含 `readingStatus` 欄位 | v2 |
| 標題行含 `isNew` 或 `isFinished` 欄位 | v1 |
| 兩者皆無 | v1（降級處理） |

### 2.3 v2 格式驗證

v2 格式匯入時的驗證清單：

| 驗證項目 | 條件 | 失敗處理 |
|---------|------|---------|
| `metadata.formatVersion` | 必須以 `"2."` 開頭 | 降級為 v1 偵測 |
| `metadata.schemaVersion` | 必須為有效 semver | 記錄警告，嘗試載入 |
| `books` | 必須為陣列 | 拒絕匯入 |
| `metadata.totalBooks` | 應等於 `books.length` | 記錄警告，以實際 `books.length` 為準 |
| `tagCategories` | 必須為陣列 | 初始化為空陣列 |
| `tags` | 必須為陣列 | 初始化為空陣列 |
| 每本書的 `readingStatus` | 必須為 6 種有效值之一 | 降級為 `"unread"` |
| 每本書的 `tagIds` | 必須為字串陣列 | 初始化為 `[]` |

---

## 3. v2 JSON Schema

### 3.1 根結構

```json
{
  "metadata": {
    "formatVersion": "2.0.0",
    "exportDate": "2026-04-05T12:00:00.000Z",
    "source": "book-overview",
    "schemaVersion": "3.0.0",
    "totalBooks": 150,
    "totalTags": 42,
    "totalTagCategories": 5
  },
  "tagCategories": [ ... ],
  "tags": [ ... ],
  "books": [ ... ]
}
```

### 3.2 metadata 欄位定義

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| formatVersion | string | 是 | 固定 `"2.0.0"` |
| exportDate | string (ISO 8601) | 是 | 匯出時間 |
| source | string | 是 | 固定 `"book-overview"` |
| schemaVersion | string | 是 | BookSchema 版本，目前 `"3.0.0"` |
| totalBooks | number | 是 | 書籍總數（匯入時與 `books.length` 交叉驗證） |
| totalTags | number | 是 | tag 總數 |
| totalTagCategories | number | 是 | tag category 總數 |

### 3.3 tagCategories 陣列

每個元素對應 `TagSchema.TAG_CATEGORY_SCHEMA`：

```json
{
  "id": "cat_system_type",
  "name": "書籍類型",
  "description": "依書籍主題分類",
  "color": "#4A90D9",
  "isSystem": true,
  "sortOrder": 0,
  "createdAt": "2026-03-01T00:00:00.000Z",
  "updatedAt": "2026-04-01T00:00:00.000Z"
}
```

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| id | string | 是 | - | 唯一識別碼（格式：`cat_` 前綴） |
| name | string | 是 | - | 名稱（上限 50 字元） |
| description | string | 否 | `""` | 說明（上限 200 字元） |
| color | string | 否 | `"#808080"` | Hex 色碼（`#RRGGBB` 格式） |
| isSystem | boolean | 否 | `false` | 是否為系統內建 |
| sortOrder | number | 否 | `0` | 排序權重 |
| createdAt | string (ISO 8601) | 是 | - | 建立時間 |
| updatedAt | string (ISO 8601) | 是 | - | 更新時間 |

### 3.4 tags 陣列

每個元素對應 `TagSchema.TAG_SCHEMA`：

```json
{
  "id": "tag_1712000000-abc123",
  "name": "科幻",
  "categoryId": "cat_user_custom",
  "isSystem": false,
  "sortOrder": 0,
  "createdAt": "2026-03-01T00:00:00.000Z",
  "updatedAt": "2026-04-01T00:00:00.000Z"
}
```

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| id | string | 是 | - | 唯一識別碼（格式：`tag_` 前綴） |
| name | string | 是 | - | 名稱（上限 50 字元） |
| categoryId | string | 是 | - | 所屬 TagCategory 的 id |
| isSystem | boolean | 否 | `false` | 是否為系統內建 |
| sortOrder | number | 否 | `0` | 排序權重 |
| createdAt | string (ISO 8601) | 是 | - | 建立時間 |
| updatedAt | string (ISO 8601) | 是 | - | 更新時間 |

### 3.5 books 陣列

每個元素對應 `BookSchemaV2.BOOK_SCHEMA_V2`：

```json
{
  "id": "book-001",
  "title": "三體",
  "readingStatus": "finished",
  "authors": ["劉慈欣"],
  "publisher": "貓頭鷹出版社",
  "progress": 100,
  "type": "epub",
  "cover": "https://readmoo.com/cover/book-001.jpg",
  "tagIds": ["tag_1712000000-abc123", "tag_1712000000-def456"],
  "isManualStatus": false,
  "extractedAt": "2026-01-15T10:30:00.000Z",
  "updatedAt": "2026-04-01T08:00:00.000Z",
  "source": "readmoo"
}
```

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|------|------|------|--------|------|
| id | string | 是 | - | 書籍唯一識別碼（Readmoo 書籍 ID） |
| title | string | 是 | - | 書名 |
| readingStatus | string (enum) | 是 | `"unread"` | 閱讀狀態（見 3.6） |
| authors | string[] | 否 | `[]` | 作者陣列 |
| publisher | string | 否 | `""` | 出版社 |
| progress | number (0-100) | 否 | `0` | 閱讀進度百分比 |
| type | string | 否 | `""` | 書籍類型 |
| cover | string | 否 | `""` | 封面圖片 URL |
| tagIds | string[] | 否 | `[]` | 關聯的 tag id 陣列 |
| isManualStatus | boolean | 否 | `false` | 狀態是否為使用者手動設定 |
| extractedAt | string (ISO 8601) | 否 | - | 首次提取時間（自動欄位） |
| updatedAt | string (ISO 8601) | 否 | - | 最後更新時間（自動欄位） |
| source | string | 否 | `"readmoo"` | 資料來源平台（自動欄位） |

**強制規範**：書籍無 tag 時，`tagIds` 匯出為空陣列 `[]`，不可省略欄位。

### 3.6 readingStatus 映射表

6 種閱讀狀態，對應 `BookSchemaV2.READING_STATUS`：

| 值 | 中文 | 說明 | 狀態類型 | v1 對映來源 |
|----|------|------|---------|-----------|
| `unread` | 未開始 | 已購買但未開始閱讀 | 自動追蹤 | `isFinished=false` 且 `progress=0` |
| `reading` | 閱讀中 | 正在閱讀 | 自動追蹤 | `isFinished=false` 且 `progress>0` |
| `finished` | 已完成 | 閱讀完畢 | 自動追蹤 | `isFinished=true` 或 `progress>=100` |
| `queued` | 待讀 | 使用者標記待讀 | 手動專用 | 無（v2 新增，v1 匯入不會產生） |
| `abandoned` | 已放棄 | 使用者決定不再閱讀 | 手動專用 | 無（v2 新增） |
| `reference` | 參考用 | 參考資料，非通讀型 | 手動專用 | 無（v2 新增） |

**狀態類型說明**：

- 自動追蹤（`isManualStatus=false`）：系統可根據 progress 變化自動轉換狀態
- 手動專用（`isManualStatus=true`）：僅由使用者手動設定，不受 progress 影響

**v1 -> v2 轉換優先順序**（與 `BookSchemaV2.mapV1StatusToV2` 一致）：

1. `isFinished === true` -> `finished`
2. `progress >= 100` -> `finished`
3. `progress > 0` -> `reading`
4. 其餘 -> `unread`

**異常組合處理**：`isNew=true` + `isFinished=true` -> `finished`（isFinished 優先）

### 3.7 完整 JSON 範例

```json
{
  "metadata": {
    "formatVersion": "2.0.0",
    "exportDate": "2026-04-05T12:00:00.000Z",
    "source": "book-overview",
    "schemaVersion": "3.0.0",
    "totalBooks": 2,
    "totalTags": 1,
    "totalTagCategories": 2
  },
  "tagCategories": [
    {
      "id": "cat_system_type",
      "name": "書籍類型",
      "description": "",
      "color": "#808080",
      "isSystem": true,
      "sortOrder": 0,
      "createdAt": "2026-04-01T00:00:00.000Z",
      "updatedAt": "2026-04-01T00:00:00.000Z"
    },
    {
      "id": "cat_user_custom",
      "name": "自訂標籤",
      "description": "",
      "color": "#808080",
      "isSystem": false,
      "sortOrder": 1,
      "createdAt": "2026-04-01T00:00:00.000Z",
      "updatedAt": "2026-04-01T00:00:00.000Z"
    }
  ],
  "tags": [
    {
      "id": "tag_1712000000-abc123",
      "name": "科幻",
      "categoryId": "cat_user_custom",
      "isSystem": false,
      "sortOrder": 0,
      "createdAt": "2026-04-02T00:00:00.000Z",
      "updatedAt": "2026-04-02T00:00:00.000Z"
    }
  ],
  "books": [
    {
      "id": "book-001",
      "title": "三體",
      "readingStatus": "finished",
      "authors": ["劉慈欣"],
      "publisher": "貓頭鷹出版社",
      "progress": 100,
      "type": "電子書",
      "cover": "https://readmoo.com/cover/book-001.jpg",
      "tagIds": ["tag_1712000000-abc123"],
      "isManualStatus": false,
      "extractedAt": "2026-03-01T08:00:00.000Z",
      "updatedAt": "2026-04-01T10:00:00.000Z",
      "source": "readmoo"
    },
    {
      "id": "book-002",
      "title": "原子習慣",
      "readingStatus": "queued",
      "authors": ["James Clear"],
      "publisher": "方智出版社",
      "progress": 0,
      "type": "電子書",
      "cover": "",
      "tagIds": [],
      "isManualStatus": true,
      "extractedAt": "2026-03-15T09:00:00.000Z",
      "updatedAt": "2026-04-02T11:00:00.000Z",
      "source": "readmoo"
    }
  ]
}
```

---

## 4. tag_tree 序列化格式

### 4.1 JSON 格式：扁平化三陣列

JSON 匯出採用**扁平化三陣列**結構（`tagCategories`、`tags`、`books[].tagIds`），不使用巢狀樹結構。

**設計理由**：
- 資料正規化，避免冗餘
- 與 Chrome Storage 儲存結構一致（`tag_categories`、`tags`、`readmoo_books` 三個獨立 key），匯入時無需轉換
- 書籍的 `tagIds` 是 tag id 的參考，透過 `tags` 和 `tagCategories` 陣列可重建完整關係

**重建 tag 關係的方式**（消費端邏輯）：

```
tagCategories -> 每個 category 下的 tags（透過 tag.categoryId 關聯）
books -> 每本書的 tagIds -> 對應 tags -> 對應 tagCategories
```

### 4.2 CSV 格式：分號分隔扁平字串

CSV 無法表達巢狀結構，tag 資訊序列化為衍生欄位：

| CSV 欄位名 | 格式 | 範例 |
|-----------|------|------|
| `tagNames` | tag 名稱以 `; ` 分隔 | `科幻; 中國文學; 必讀` |
| `tagCategories` | 對應的 category 名稱，與 tagNames 順序一致 | `自訂標籤; 自訂標籤; 閱讀清單` |

**設計決策**：
- CSV 使用名稱而非 id，因 CSV 主要用於人工閱讀和試算表處理
- 分隔符為 `; `（分號加空格），避免與書名中的逗號衝突
- 書籍無 tag 時輸出空字串 `""`
- CSV 不包含完整 `tagCategories`/`tags` 定義（僅透過衍生欄位呈現）

---

## 5. v2 CSV 欄位對照表

### 5.1 完整欄位對照

| CSV 欄位名 | 對應 JSON 路徑 | 型別 | 序列化方式 | 說明 |
|-----------|--------------|------|-----------|------|
| `id` | `books[].id` | string | 原值 | 書籍 ID |
| `title` | `books[].title` | string | 原值 | 書名 |
| `authors` | `books[].authors` | string | `; ` 分隔 | 作者（多位以 `; ` 分隔） |
| `publisher` | `books[].publisher` | string | 原值 | 出版社 |
| `progress` | `books[].progress` | number | 原值 | 閱讀進度（0-100） |
| `readingStatus` | `books[].readingStatus` | string | 原值 | 閱讀狀態（6 種之一） |
| `type` | `books[].type` | string | 原值 | 書籍類型 |
| `cover` | `books[].cover` | string | 原值 | 封面 URL |
| `tagIds` | `books[].tagIds` | string | `; ` 分隔 | tag id 列表 |
| `tagNames` | 衍生自 `tagIds` | string | `; ` 分隔 | tag 名稱（衍生欄位） |
| `tagCategories` | 衍生自 tag 的 categoryId | string | `; ` 分隔 | category 名稱（衍生欄位） |
| `isManualStatus` | `books[].isManualStatus` | string | `true`/`false` | 是否手動設定 |
| `extractedAt` | `books[].extractedAt` | string | ISO 8601 | 首次提取時間 |
| `updatedAt` | `books[].updatedAt` | string | ISO 8601 | 最後更新時間 |
| `source` | `books[].source` | string | 原值 | 資料來源 |

### 5.2 CSV 特殊值處理

| 情境 | 處理方式 |
|------|---------|
| 欄位值包含逗號 | 以雙引號包裹 |
| 欄位值包含雙引號 | 雙引號轉義（`""`） |
| 欄位值包含換行 | 以雙引號包裹 |
| 欄位值為 null/undefined | 輸出空字串 |
| authors 為空陣列 | 輸出空字串 |
| tagIds/tagNames/tagCategories 為空 | 輸出空字串 |

### 5.3 CSV 範例

```csv
id,title,authors,publisher,progress,readingStatus,type,cover,tagIds,tagNames,tagCategories,isManualStatus,extractedAt,updatedAt,source
book-001,三體,劉慈欣,貓頭鷹出版社,100,finished,電子書,https://readmoo.com/cover/book-001.jpg,tag_1712000000-abc123,科幻,自訂標籤,false,2026-03-01T08:00:00.000Z,2026-04-01T10:00:00.000Z,readmoo
book-002,原子習慣,James Clear,方智出版社,0,queued,電子書,,,,,true,2026-03-15T09:00:00.000Z,2026-04-02T11:00:00.000Z,readmoo
```

---

## 6. Field Presets v2

v2 欄位預設組更新，新增 tag 和 readingStatus 相關欄位。

### 6.1 BASIC_V2

用途：快速匯出基本書目資訊。

```javascript
BASIC_V2: ['id', 'title', 'authors', 'publisher']
```

與 v1 BASIC 差異：`author`(string) -> `authors`(array)

### 6.2 EXTENDED_V2

用途：含閱讀狀態和 tag 的標準匯出（**預設選項**）。

```javascript
EXTENDED_V2: ['id', 'title', 'authors', 'publisher', 'progress', 'readingStatus', 'type', 'tagIds']
```

與 v1 EXTENDED 差異：
- `author` -> `authors`（陣列化）
- 移除 `publishDate`（BookSchemaV2 無此欄位）
- 移除 `category`（tag-based 取代階層分類）
- `status` -> `readingStatus`（6 種列舉值）
- 新增 `type`、`tagIds`

### 6.3 COMPLETE_V2

用途：含所有欄位的完整匯出。

```javascript
COMPLETE_V2: [
  'id', 'title', 'authors', 'publisher',
  'progress', 'readingStatus', 'type', 'cover',
  'tagIds', 'isManualStatus',
  'extractedAt', 'updatedAt', 'source'
]
```

與 v1 COMPLETE 差異：
- 移除 v1 中未實作的欄位：`publishDate`、`isbn`、`rating`、`notes`、`readingTime`、`price`
- `author` -> `authors`、`category` -> `tagIds`、`status` -> `readingStatus`、`tags` -> `tagIds`
- 新增：`isManualStatus`、`extractedAt`、`updatedAt`、`source`

### 6.4 CSV 匯出的衍生欄位

CSV 匯出時，若 preset 包含 `tagIds`，自動附加衍生欄位 `tagNames` 和 `tagCategories`。

### 6.5 JSON 匯出的 Preset 行為

JSON 匯出的 field presets 僅控制 `books` 陣列中每本書包含的欄位。`metadata`、`tagCategories`、`tags` 三個頂層區段在 JSON 匯出時**始終包含**，不受 field preset 影響。

### 6.6 v1 Presets 保留

v1 的 `BASIC`、`EXTENDED`、`COMPLETE` 欄位集保留不刪除，供 v1 相容匯出選項使用。

---

## 7. v1 匯入相容策略

### 7.1 v1 書籍欄位轉換

當偵測到 v1 格式時，逐本書籍執行以下轉換：

| v1 欄位 | v2 欄位 | 轉換規則 |
|---------|---------|---------|
| `author` (string) | `authors` (string[]) | 單一字串包裝為陣列 `[author]`；空字串或 undefined 時為 `[]` |
| `isNew`, `isFinished`, `progress` | `readingStatus` | 依 `mapV1StatusToV2` 邏輯轉換（見 3.6） |
| （無） | `tagIds` | 預設 `[]` |
| （無） | `isManualStatus` | 預設 `false` |
| `category` (string) | （匯入後處理） | 自動建立同名 tag 和 category（見 7.3） |
| （無） | `updatedAt` | 設為匯入時間 |
| （無） | `source` | 預設 `"readmoo"` |
| `isNew` | （移除） | 轉換為 readingStatus 後刪除 |
| `isFinished` | （移除） | 轉換為 readingStatus 後刪除 |
| `progress` | `progress` | 保留，正規化為 0-100 數字（`normalizeV1Progress` + clamp） |

### 7.2 v1 CSV 匯入轉換

| v1 CSV 欄位 | v2 欄位 | 轉換規則 |
|------------|---------|---------|
| `author` | `authors` | 單一字串包裝為陣列 |
| `status`（中文值） | `readingStatus` | 已完成->finished, 閱讀中->reading, 未開始->unread, 其餘->unread |
| `isNew`/`isFinished` | `readingStatus` | 同 JSON 轉換邏輯 |
| `category` | `tagNames` | category 名稱映射為 tag 名稱 |
| `tags`（若存在） | `tagNames` | 與 category 合併 |

### 7.3 v1 category -> tag 自動轉換

匯入 v1 資料時，`category` 欄位自動轉換為 tag 系統：

1. 建立名為 `"匯入分類"` 的 TagCategory（若不存在）
2. 每個不重複的 category 值建立一個 Tag，歸屬於 `"匯入分類"` category
3. 對應書籍的 `tagIds` 加入該 tag 的 id
4. category 值為空字串或 `"未分類"` 時不建立 tag

### 7.4 v1 progress 正規化

使用 `BookSchemaV2.normalizeV1Progress` 處理各種輸入格式：

| 輸入值 | 正規化結果 |
|-------|-----------|
| `null` / `undefined` | `0` |
| `NaN` | `0` |
| 字串 `"75"` | `75` |
| 負數 `-10` | `0`（clamp） |
| 超過 100 `150` | `100`（clamp） |
| 物件 `{ progress: 50 }` | `50`（遞迴拆包） |

### 7.5 匯入完整流程

```
偵測為 v1 格式
    |
    v
提取書籍陣列（支援三種 v1 結構）：
    - 純陣列：data 本身
    - metadata 包裝：data.books
    - books 包裝：data.books
    |
    v
逐本轉換：
    1. author -> authors（字串包裝為陣列）
    2. isNew/isFinished + progress -> readingStatus（mapV1StatusToV2）
    3. progress -> normalizeV1Progress + clamp(0, 100)
    4. 新增 tagIds: []
    5. 新增 isManualStatus: false
    6. 新增 updatedAt: 匯入時間
    7. 新增 source: "readmoo"
    8. 移除 isNew, isFinished
    |
    v
建立預設 tag 結構：
    - tagCategories: [書籍類型(cat_system_type), 自訂標籤(cat_user_custom)]
    - tags: []
    |
    v
若有 category 欄位，執行 category -> tag 轉換（7.3）
    |
    v
以 v2 結構載入
```

---

## 8. 匯入合併策略

### 8.1 載入模式

| 模式 | 書籍處理 | tag 處理 | tagCategory 處理 |
|------|---------|---------|-----------------|
| 覆蓋 | 清空後載入 | 清空後載入 | 清空後載入 |
| 合併 | 同 id 更新，新 id 新增 | 同 name+categoryId 跳過，新建不存在的 | 同 name 跳過，新建不存在的 |

### 8.2 合併模式細節

**書籍合併**：
- 依 `id` 判斷是否為同一本書
- 同 id 時：以匯入資料覆蓋所有欄位，但 `tagIds` 取聯集（匯入 tagIds + 本地 tagIds，去重）
- 新 id：直接加入

**tag 合併**：
- 同一 category 內同名 tag 視為相同（大小寫不敏感，與 `TagSchema.validateTag` 一致）
- 相同 tag 保留本地版本的 id 和屬性
- 匯入書籍引用匯入 tag id 時，需重新映射到本地 tag id

**tagCategory 合併**：
- 同名 category 視為相同，保留本地版本的 id 和屬性
- 匯入 tag 的 categoryId 需重新映射到本地 category id

### 8.3 id 重新映射

合併模式下，匯入檔案的 tag/category id 可能與本地不同，需建立映射表：

```
匯入 category id -> 本地 category id（同名映射或新建）
匯入 tag id -> 本地 tag id（同 category 同名映射或新建）
匯入書籍 tagIds -> 透過上述映射轉換為本地 tag id
```

---

## 9. 邊界條件

### 9.1 匯出邊界條件

| 條件 | 處理方式 |
|------|---------|
| 書籍無 tag | `tagIds: []`，JSON 為空陣列；CSV 衍生欄位為空字串 |
| tag 的 categoryId 對應的 category 不存在 | 匯出時跳過該 tag 並記錄警告 |
| 書籍 tagIds 含不存在的 tag id | 匯出時過濾掉無效 id 並記錄警告 |
| 書籍數量為 0 | 正常匯出，books 為空陣列 |
| readingStatus 值不在 6 種之內 | 匯出時降級為 `"unread"` 並記錄警告 |

### 9.2 匯入邊界條件

| 條件 | 處理方式 |
|------|---------|
| v1 `isNew=true` + `isFinished=true` | 轉為 `finished`（isFinished 優先） |
| v2 `readingStatus` 值無效 | 降級為 `"unread"` |
| 匯入 tagCategory 在本地不存在 | 自動建立 |
| 匯入 tag 的 categoryId 在檔案內不存在 | 建立名為 `"未分類"` 的 category 並歸入 |
| 單本書 tagIds 超過 100 個 | 截斷至 100 個並記錄警告（`TagSchema.MAX_TAGS_PER_BOOK`） |
| tagCategory name 超過 50 字元 | 截斷至 50 字元（`TagSchema.TAG_CATEGORY_NAME_MAX_LENGTH`） |
| tag name 超過 50 字元 | 截斷至 50 字元（`TagSchema.TAG_NAME_MAX_LENGTH`） |
| JSON 檔案無 metadata | 視為 v1 格式 |
| CSV 欄位順序不同 | 依標題行名稱比對，不依賴欄位順序 |
| `metadata.totalBooks` 與實際 `books.length` 不符 | 記錄警告，以實際 `books.length` 為準 |
| v1 書籍缺少 `id` | 跳過該書籍，記錄警告 |
| v1 progress 為 null/undefined/NaN | 正規化為 `0` |
| color 值不符合 `#RRGGBB` 格式 | 使用預設色 `"#808080"` |

---

## 10. 匯出選項

使用者可選擇的匯出選項：

| 選項 | 型別 | 預設值 | 說明 |
|------|------|--------|------|
| `format` | string | `"json"` | 匯出格式：`"json"` 或 `"csv"` |
| `formatVersion` | string | `"2.0.0"` | 交換格式版本：`"2.0.0"`（預設）或 `"1.0"`（v1 相容） |
| `fieldPreset` | string | `"EXTENDED_V2"` | 欄位集：`"BASIC_V2"` / `"EXTENDED_V2"` / `"COMPLETE_V2"` |
| `pretty` | boolean | `true` | JSON 是否美化輸出（縮排 2 空格） |

**v1 相容匯出**：當 `formatVersion` 為 `"1.0"` 時，匯出格式回退為 v1 結構——不含 `metadata.formatVersion`、不含 `tagCategories`/`tags` 頂層區段，書籍使用 v1 field presets。

---

## 11. 與現有程式碼的整合要點

### 11.1 BookDataExporter 變更

- `CONSTANTS.FIELDS` 需新增 `BASIC_V2`、`EXTENDED_V2`、`COMPLETE_V2`
- `exportToJSON` 在 `includeMetadata` 模式下需輸出 v2 結構（含 `tagCategories`、`tags` 頂層區段和 `metadata.formatVersion`）
- `_processFieldValue` 需處理 `authors`（陣列 -> `; ` 分隔字串）、`tagNames`（解析 tagIds -> 名稱）、`tagCategories`（解析 tagIds -> category 名稱）
- v1 field presets 保留不刪除，供 v1 相容匯出使用

### 11.2 ExportManager 變更

- 匯出事件 payload 需包含 tagCategories 和 tags 資料（由呼叫端提供或從 `TagStorageAdapter` 讀取）
- 驗證邏輯不受影響（仍驗證 books 陣列）

### 11.3 匯入流程新增

- 版本偵測模組（依第 2 節規則）
- v1 -> v2 轉換模組（依第 7 節規則，複用 `BookSchemaV2.mapV1StatusToV2` 和 `normalizeV1Progress`）
- tag 自動建立模組（依 7.3 節規則）
- id 重新映射模組（依 8.3 節規則）

---

## 12. 驗收標準

### AC-1: v2 JSON 匯出完整性

- Given 系統有書籍、tags、tagCategories 資料
- When 執行 JSON 匯出
- Then 輸出包含 metadata、tagCategories、tags、books 四個頂層區段
- And `metadata.formatVersion` 為 `"2.0.0"`
- And `metadata.schemaVersion` 為 `"3.0.0"`
- And 所有書籍的 readingStatus 為 6 種合法值之一
- And 書籍無 tag 時 tagIds 為空陣列

### AC-2: v2 CSV 匯出完整性

- Given 系統有含 tag 的書籍資料
- When 執行 CSV 匯出（EXTENDED_V2 preset）
- Then 標題行包含 readingStatus 和 tagNames 欄位
- And tagNames 欄位以 `; ` 分隔多個 tag 名稱
- And 無 tag 的書籍 tagNames 為空字串

### AC-3: v1 JSON 匯入相容

- Given 使用者有 v1 格式 JSON 檔案（含 isNew/isFinished/category）
- When 執行匯入
- Then 系統自動偵測為 v1 格式
- And isNew/isFinished 正確轉換為 readingStatus
- And category 自動轉換為 tag

### AC-4: v1 CSV 匯入相容

- Given 使用者有 v1 格式 CSV 檔案（含 status 中文值）
- When 執行匯入
- Then status 中文值正確映射為 readingStatus 英文值
- And 無法辨識的 status 值降級為 `unread`

### AC-5: readingStatus round-trip

- Given 系統中有 6 種不同 readingStatus 的書籍
- When 匯出後再匯入
- Then 所有 6 種狀態完整保留，round-trip 無損

### AC-6: tag 合併策略

- Given 本地有書籍 A（tagIds: [t1, t2]），匯入檔案中書籍 A（tagIds: [t2, t3]）
- When 以合併模式匯入
- Then 書籍 A 的 tagIds 為 [t1, t2, t3]（聯集）

### AC-7: 版本偵測

- Given 三種 v1 JSON 結構（純陣列、metadata 包裝、books 包裝）和 v2 JSON 結構
- When 分別執行匯入
- Then 每種結構都被正確偵測為對應版本

---

## 變更歷史

| 版本 | 日期 | 變更說明 |
|------|------|---------|
| 2.0.0 | 2026-04-05 | 完整定義 v2 JSON/CSV 格式、tag_tree 序列化、readingStatus 6 狀態映射、v1 相容策略、Field Presets v2、合併策略、邊界條件（0.17.2-W1-001） |
