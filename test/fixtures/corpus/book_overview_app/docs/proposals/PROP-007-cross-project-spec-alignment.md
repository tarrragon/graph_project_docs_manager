---
id: PROP-007
title: Chrome Extension 與 Flutter App 跨專案 Spec 對齊
status: confirmed
evaluation_level: heavy
---

# PROP-007: Chrome Extension 與 Flutter App 跨專案 Spec 對齊

## 基本資訊

| 項目 | 值 |
|------|------|
| 提案 ID | PROP-007 |
| 狀態 | draft |
| 優先級 | P1 |
| 建立日期 | 2026-04-02 |
| 關聯 UC | UC-01（匯入）、UC-02（匯出）、UC-07（跨平台同步） |

---

## 1. 背景

兩個專案共用同一份原始 spec（`app-requirements-spec.md` 和 `app-use-cases.md`），最初放在 Chrome Extension 專案（`~/project/book_overview_v1`），後來 Flutter App 專案（`~/project/book_overview_app`）複製了一份。

經過數月獨立開發，兩邊的實作已各自演化：
- Chrome Extension 側重 Readmoo DOM 提取、Chrome Storage、事件驅動架構
- Flutter App 側重 DDD 領域建模、SQLite、Rich UI 元件

設計哲學差異：
- **Extension**：偏重「資料提取和正規化」— 多平台 adapter、dataFingerprint、多尺寸封面
- **App**：偏重「領域建模和管理」— DDD Value Objects、狀態機、借閱/版本管理

現在 Chrome Extension 進入同步 Use Case 開發（v0.18.1），需要重新對齊兩邊的 spec，確保互操作性。

---

## 2. 同步策略與版本規劃

### 2.1 同步手段分層

| 手段 | 定位 | 版本 | 說明 |
|------|------|------|------|
| **Google Drive API** | 主要同步方式 | v2.0 | 使用者資料存在自己的 Drive，零伺服器成本 |
| **JSON 匯出/匯入** | 離線備援方案 | v1.0 | 手動操作，用於測試和無網路環境 |

### 2.2 Google Drive 同步方案（v2.0）

**核心決策**：

| 決策 | 選擇 | 原因 |
|------|------|------|
| OAuth scope | `drive.file` | 最小權限且支援跨平台共享，不觸發 Google 敏感權限審查 |
| 共享方式 | 命名資料夾慣例（`BookOverviewSync`） | 兩端透過資料夾名稱找到彼此 |
| Cloud 專案 | 單一 Google Cloud Project | `drive.file` 允許同專案下不同 Client 互相存取檔案 |
| 使用者操作 | 每平台 OAuth 一次，之後全自動 | Token 自動快取和刷新 |

**不可使用 `drive.appdata`**：appdata 資料夾按 Client ID 隔離，Extension 和 App 各自看不到對方的資料。

**使用者體驗流程**：

```
Chrome Extension                    Google Drive                    Flutter App
     |                                  |                               |
     |-- OAuth 一次 ------------------>|                               |
     |-- 建立 BookOverviewSync/ ------>|                               |
     |-- 寫入 sync-data.json -------->|                               |
     |                                  |                               |
     |                                  |<---- OAuth 一次 -------------|
     |                                  |<---- 搜尋 BookOverviewSync/ -|
     |                                  |---- 回傳 sync-data.json ---->|
     |                                  |                               |
     |       [之後全自動，零操作]        |                               |
```

**各平台技術實作**：

| 平台 | OAuth 方式 | Client 類型 | 套件 |
|------|-----------|------------|------|
| Chrome Extension | `chrome.identity.getAuthToken()` | Chrome App | 內建 API |
| Flutter Android | `google_sign_in` | Android（需 SHA-1） | googleapis |
| Flutter iOS | `google_sign_in` | iOS（需 bundle ID） | googleapis |

### 2.3 版本規劃

**v1.0 — JSON 離線同步（優先開發）**：
- 統一交換格式（Interchange Format v1）
- Extension 匯出新格式 + App 匯入新格式（向下相容舊格式）
- 雙向匯入匯出端到端測試
- 用途：測試同步邏輯、離線場景、無 Google 帳號使用者

**v2.0 — Google Drive 線上同步**：
- OAuth 整合（Extension: chrome.identity / App: google_sign_in）
- 自動同步排程（背景定期同步）
- 增量同步（只傳差異）
- 衝突解決 UI

---

## 3. Book Model 重新設計

### 3.1 設計哲學

傳統 model 把作者、出版社、平台等當成固定欄位（單值字串），但實際上：
- 同一本書可能有中文版、日文版、英文版（不同作者譯名、不同出版社、不同 ISBN）
- 同一本書可能在多個平台購買（Readmoo + Kindle + 實體）
- 出版社會因版權易手而改變
- 書名在不同版本間也會變動

因此，大多數書籍 metadata 應該是**多值的 tag**，而非單值字串欄位。

### 3.2 固定欄位（不可多值，每本書一個）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | string | 是 | 唯一編號 |
| `title` | string | 是 | 主書名（第一次登錄的書名，可由使用者切換） |
| `cover` | object | 否 | 主要封面（支援多尺寸：thumbnail/medium/original） |
| `cross_platform_id` | string | 否 | 跨平台統一 ID（同步去重用） |
| `data_fingerprint` | string | 否 | 資料指紋（重複檢測用） |
| `created_at` | string | 是 | 建立時間（ISO 8601） |
| `updated_at` | string | 是 | 更新時間（ISO 8601） |

### 3.3 系統 Tag 分類（固定類別，可多值）

系統預設的 tag 類別，使用者不能新增或刪除類別本身，但可以在類別下新增 tag 項目：

| 類別 ID | 類別名稱 | 允許巢狀 | 說明 | 範例 |
|---------|---------|---------|------|------|
| `author` | 作者 | 否 | 支援多語言作者名 | "村上春樹", "Haruki Murakami" |
| `publisher` | 出版社 | 否 | 不同版本可能不同出版社 | "時報出版", "講談社" |
| `platform` | 來源平台 | 否 | 同一本書可能在多平台購買 | "readmoo", "kindle", "實體書" |
| `language` | 語言 | 否 | 書籍語言版本 | "中文", "日文", "英文" |
| `isbn` | ISBN | 否 | 不同版本有不同 ISBN | "9784003101063", "9789571234567" |
| `alias` | 別名 | 否 | 其他版本的書名 | "ノルウェイの森", "Norwegian Wood" |
| `reading_status` | 閱讀狀態 | 否 | 單選，6 種統一狀態 | "閱讀中" |
| `importance` | 重要程度 | 否 | 單選，7 級分類 | "推薦分享" |
| `series` | 叢書系列 | 否 | 系列名稱和冊數 | "哈利波特 #3" |
| `description` | 書籍描述 | 否 | API 豐富化或手動輸入 | 書籍介紹文字 |

**閱讀狀態**（6 種統一 enum，單選）：

| 狀態 | 說明 |
|------|------|
| `not_started` | 未開始 |
| `queued` | 排隊等待 |
| `reading` | 閱讀中 |
| `finished` | 已完成 |
| `abandoned` | 已放棄 |
| `reference` | 參考書（隨時查閱） |

**重要程度**（7 級分類，單選）：

| 等級 | 名稱 | 說明 |
|------|------|------|
| 1 | 參考書 | 要常拿起來查看的工具書 |
| 2 | 重讀收藏 | 因為喜愛而想重複閱讀 |
| 3 | 文獻保存 | 具重要學術或文獻價值 |
| 4 | 推薦分享 | 想推薦給他人的優質書籍 |
| 5 | 收藏價值 | 基於收藏目的擁有 |
| 6 | 裝飾展示 | 主要用於家居裝飾展示 |
| 7 | 可清理 | 可考慮清理或轉讓 |

**閱讀進度**（附加在書籍上，非 tag）：

```json
{
  "progress": {
    "percentage": 45.5,
    "current_page": 120,
    "total_pages": 265,
    "last_read_at": "2026-03-20T14:22:00Z"
  }
}
```

### 3.4 標準分類（中文圖書分類法，獨立欄位）

中文圖書分類法作為**獨立的標準分類欄位**，和使用者自訂 tag 分開：
- 使用 tag tree 結構儲存，但 `is_locked: true`，使用者不可修改分類項目
- 三層結構（10 大類 → 100 細分 → 1000 小類），預裝 ~1000 個節點
- UI 為三步驟彈窗，每層 10 個選項，使用者可只選到任一層停止

```
使用者按「依圖書分類法歸類」
  → [第一層] 選大類（10 選項）→ 800 語言文學
  → [第二層] 選細分（10 選項）→ 850 西洋文學
  → [第三層] 選小類（10 選項）→ 857 美國文學
```

### 3.5 自定義 Tag（使用者完全自訂）

使用者可建立自己的 tag tree，類別 ID 為 `custom`：
- 支援巢狀結構（無深度限制）
- 無數量限制
- 使用者自行管理（新增、重命名、移動、合併、刪除）

```
自定義/
  2026必讀/
  送禮清單/
    給同事/
    給家人/
  讀書會/
    第一季/
    第二季/
```

### 3.6 書籍合併功能

使用者可能從不同平台登錄同一本書的不同版本。系統提供合併功能：

| 步驟 | 說明 |
|------|------|
| 1. 選擇多本書 | 使用者辨識為同一本書 |
| 2. 合併 tag | 所有版本的 tag 合併到一本書上 |
| 3. 選擇主要值 | 書名、封面等唯一欄位由使用者選擇要用哪個版本 |
| 4. 保留所有 ISBN | 不同版本的 ISBN 全部保留為多值 tag |
| 5. 保留所有別名 | 不同版本的書名保留在 alias 分類中 |

### 3.7 資料庫結構

```sql
-- books 表（固定欄位）
-- 固定欄位收錄「非分類屬性」：時間戳、數值量化指標、系統內部旗標、自由長文。
-- 這些屬性不適合 tag model（tag 為短字串分類標籤），故保留為 books 表固定欄位。
CREATE TABLE books (
  id                  TEXT PRIMARY KEY,
  title               TEXT NOT NULL,           -- 主書名
  description         TEXT,                    -- 書籍描述（自由長文，FTS5 全文索引；非分類屬性，保留固定欄位）
  rating              REAL,                    -- 評分 0-5（數值量化指標；非分類屬性，保留固定欄位）
  api_enriched        INTEGER NOT NULL DEFAULT 0,  -- API 充實狀態旗標（系統內部狀態；非分類屬性，保留固定欄位）
  cover_thumbnail     TEXT,                    -- 縮圖 URL
  cover_medium        TEXT,                    -- 中等尺寸 URL
  cover_original      TEXT,                    -- 原始尺寸 URL
  cross_platform_id   TEXT,                    -- 跨平台統一 ID
  data_fingerprint    TEXT,                    -- 資料指紋
  progress_percentage REAL,                    -- 閱讀進度百分比
  progress_current    INTEGER,                 -- 當前頁數
  progress_total      INTEGER,                 -- 總頁數
  progress_last_read  INTEGER,                 -- 最後閱讀時間
  created_at          INTEGER NOT NULL,        -- 書籍登錄時間戳（承載舊 model 的 added_date 語意，rename 而非新增）
  updated_at          INTEGER NOT NULL
);

-- 欄位對映說明：舊 model 的 added_date（時間戳，預設排序鍵）由本表 created_at 承載。
-- added_date 不是被本 schema 遺漏，而是已用 created_at 名稱保留；
-- 時間戳是書籍元資料的基本屬性，非分類屬性，不遷入 tag。

-- tag_categories 表（分類類別）
CREATE TABLE tag_categories (
  id          TEXT PRIMARY KEY,                -- 'author', 'publisher', ...
  name        TEXT NOT NULL,                   -- '作者', '出版社', ...
  is_system   INTEGER NOT NULL DEFAULT 1,      -- 1=系統固定, 0=自定義
  allow_tree  INTEGER NOT NULL DEFAULT 0,      -- 1=允許巢狀
  created_at  INTEGER NOT NULL
);

-- 預裝類別：
-- author, publisher, platform, language, isbn, alias,
-- reading_status, importance, series, description,
-- ccl (中文圖書分類法), custom (自定義)

-- tags 表（tag 項目）
CREATE TABLE tags (
  id          TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,                   -- 所屬分類
  name        TEXT NOT NULL,
  parent_id   TEXT,                            -- 巢狀用（NULL = 頂層）
  is_locked   INTEGER NOT NULL DEFAULT 0,      -- 1=不可修改（中文圖書分類法）
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  FOREIGN KEY (category_id) REFERENCES tag_categories (id),
  FOREIGN KEY (parent_id) REFERENCES tags (id)
);

-- book_tags 表（書籍與 tag 的關聯）
CREATE TABLE book_tags (
  book_id     TEXT NOT NULL,
  tag_id      TEXT NOT NULL,
  is_primary  INTEGER NOT NULL DEFAULT 0,      -- 用於需要「選一個」的場景
  created_at  INTEGER NOT NULL,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE,
  UNIQUE(book_id, tag_id)
);

-- book_loans 表（借閱記錄，UC-06）
CREATE TABLE book_loans (
  id          TEXT PRIMARY KEY,
  book_id     TEXT NOT NULL,
  loan_type   TEXT NOT NULL,                   -- 'borrowed_from' | 'lent_to'
  source_name TEXT NOT NULL,
  loan_date   INTEGER NOT NULL,
  due_date    INTEGER NOT NULL,
  returned_date INTEGER,
  notes       TEXT,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
);
```

### 3.8 廢除的欄位

以下舊 model 欄位（皆為分類屬性）改由 tag 系統取代：

| 舊欄位 | 替代方案 |
|-------|---------|
| `author` (string) | tag 分類 `author`（多值） |
| `publisher` (string) | tag 分類 `publisher`（多值） |
| `isbn` (string) | tag 分類 `isbn`（多值） |
| `genre` (string) | 廢除，由 tag 分類和中文圖書分類法取代 |
| `source` / `platform_id` (string) | tag 分類 `platform`（多值） |
| `readingStatus` (enum) | tag 分類 `reading_status`（單選） |
| `importanceLevel` (number) | tag 分類 `importance`（單選） |
| `tags` (string[]) | tag 分類 `custom`（自定義 tag tree） |

`description` 不在廢除清單：它是自由長文（非分類屬性），且 FTS5 全文索引直接依賴此欄位，故保留為 §3.7 books 表固定欄位（見 §3.7 欄位說明）。tag_categories 雖預裝 `description` 分類供未來 tag 化描述片段使用，但 books.description 固定欄位仍是主要儲存。

### 3.9 閱讀進度統一方案

Extension 有精確進度，App 沒有。建議 App 加入：

```json
{
  "progress": {
    "percentage": 45.5,
    "current_page": 120,
    "total_pages": 265,
    "last_read_at": "2026-03-20T14:22:00Z"
  }
}
```

App 端加入 `ReadingProgress` Value Object，Extension 端已有。

---

## 4. 功能差異與對齊

### 4.1 功能覆蓋對比

| 功能 | Extension | App | 對齊方向 |
|------|----------|-----|---------|
| 搜尋 | 模糊 + 加權 + 索引 | FTS5 全文搜尋 | 各自最佳化，不需統一 |
| 排序 | title/progress/source | 多欄位 + 複合索引 | App 更豐富，Extension 逐步補齊 |
| 篩選 | 搜尋詞動態篩選 | 按 status/tag/rating | App 更豐富，Extension 逐步補齊 |
| 閱讀進度 | percentage/pages/locations | readingStatus（無百分比） | App 需加入百分比進度 |
| 標籤管理 | 扁平 string[] | 扁平 List\<Tag\> max 10 | 兩邊改為樹狀 tag，無限制，支援巢狀分類 |
| 借閱管理 | 無 | UC-06 完整實作 | Extension 顯示同步來的借閱資訊 |
| 版本管理 | 無 | UC-08 MasterBook/Edition | App 獨有，Extension 不需要 |
| 多平台支援 | 5 平台 | 8 平台 | 統一平台列表 |
| 同步衝突 | 4 種策略（已實作） | 設計就緒未驗證 | Extension 領先，App 需對齊 |
| 匯出 | JSON/CSV/Excel | 開發中 | Extension 領先，App 需補齊 |
| 多尺寸封面 | 5 種尺寸 | 單一 URL | App 建議加入 |
| 跨平台 ID | crossPlatformId + fingerprint | 無 | App 需加入 |
| ISBN 掃描 | 無 | UC-03 camera + ML Kit | App 獨有 |

### 4.2 功能對齊優先級

**v1.0 必須對齊**（JSON 同步能正確運作）：

| 項目 | 負責方 | 說明 |
|------|-------|------|
| Book Model 重新設計 | 雙方 | 固定欄位 + tag-based metadata（見第 3 章） |
| 統一交換格式 | 雙方 | Interchange Format v2（tag-based） |
| Tag 系統（tag_categories + tags + book_tags） | 雙方 | 12 個系統類別 + 自定義 |
| 廢除舊固定欄位 | 雙方 | author/publisher/isbn/genre 等改為 tag |
| 內建中文圖書分類法 | 雙方 | 預裝 ~1000 節點，is_locked，獨立於自定義 tag |
| 書籍合併功能 | 雙方 | 多版本合併、主書名選擇 |
| 統一閱讀狀態 | Extension 加入 3 種新狀態 | 6 種統一 enum |
| 閱讀進度欄位 | 雙方 | percentage/current_page/total_pages |

**v2.0 建議對齊**（Google Drive 同步後）：

| 項目 | 負責方 | 說明 |
|------|-------|------|
| Extension 顯示借閱資訊 | Extension | 同步來的 activeLoan 簡化顯示 |
| Extension 顯示重要程度 | Extension | importanceLevel |
| Extension 顯示描述 | Extension | description |
| App 加入多尺寸封面 | App | 效能最佳化 |
| App 加入 series/volume | App | 叢書系列 |
| 統一衝突解決策略 | 雙方 | 欄位級合併 + 手動確認 |

---

## 5. 交換格式定義（對齊 book-interchange-v1 v3.0.0）

> canonical SSOT = `book_overview_v1/docs/spec/book-interchange-v1.md`
>
> 本節依 canonical v3.0.0 定義跨專案交換格式。APP 內部 DB 欄位使用 snake_case（如 `cross_platform_id`、`created_at`）；**交換格式 wire format 欄位使用 camelCase**（如 `crossPlatformId`、`createdAt`），兩者不可混淆。

### 5.1 Root 結構（Wire Format）

```json
{
  "format": "book-interchange-v1",
  "formatVersion": "3.0.0",
  "metadata": {
    "exportedAt": "2026-04-02T09:00:00.000Z",
    "sourceApp": "book_overview_app",
    "totalBooks": 150
  },
  "books": [
    {
      "id": "210327003000101",
      "title": "挪威的森林",
      "cover": {
        "thumbnail": "https://...210x315.jpg",
        "medium": "https://...420x630.jpg",
        "original": "https://...full.jpg"
      },
      "crossPlatformId": "cpid_a1b2c3d4",
      "dataFingerprint": "fp_x7y8z9",
      "progress": {
        "percentage": 45.5,
        "currentPage": 120,
        "totalPages": 265,
        "lastReadAt": "2026-03-20T14:22:00.000Z"
      },
      "createdAt": "2026-01-15T08:30:00.000Z",
      "updatedAt": "2026-03-20T14:22:00.000Z",
      "tags": {
        "author":         [{ "id": "a1", "name": "村上春樹" },
                           { "id": "a2", "name": "Haruki Murakami" }],
        "publisher":      [{ "id": "p1", "name": "時報出版" }],
        "platform":       [{ "id": "pl1", "name": "readmoo" },
                           { "id": "pl2", "name": "實體書" }],
        "language":       [{ "id": "l1", "name": "中文" }],
        "isbn":           [{ "id": "i1", "name": "9789571234567" }],
        "alias":          [{ "id": "al1", "name": "ノルウェイの森" },
                           { "id": "al2", "name": "Norwegian Wood" }],
        "readingStatus":  [{ "id": "rs-reading", "name": "reading" }],
        "importance":     [{ "id": "imp-4", "name": "推薦分享" }],
        "series":         [],
        "description":    [{ "id": "d1", "name": "一本關於青春與失落的經典小說..." }],
        "ccl":            [{ "id": "ccl-861", "name": "日本文學",
                             "path": "語言文學/東方文學/日本文學" }],
        "custom":         [{ "id": "c1", "name": "2026必讀", "path": "2026必讀" },
                           { "id": "c2", "name": "送同事", "path": "送禮清單/送同事" }]
      },
      "activeLoan": null,
      "extensions": {
        "readmoo-book-extractor": { "extractedAt": "2026-01-15T08:30:00.000Z" },
        "book_overview_app": { "apiEnriched": true }
      },
      "_passthrough": {}
    }
  ],
  "tagTree": {
    "ccl": [
      { "id": "ccl-800", "name": "語言文學", "parentId": null, "locked": true },
      { "id": "ccl-840", "name": "東方文學", "parentId": "ccl-800", "locked": true },
      { "id": "ccl-861", "name": "日本文學", "parentId": "ccl-840", "locked": true }
    ],
    "custom": [
      { "id": "c0", "name": "2026必讀", "parentId": null },
      { "id": "c-gift", "name": "送禮清單", "parentId": null },
      { "id": "c2", "name": "送同事", "parentId": "c-gift" }
    ]
  }
}
```

### 5.2 書籍固定欄位（camelCase wire format）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | string | 是 | 唯一識別符（匯入保留，禁重生） |
| `title` | string | 是 | 主書名 |
| `cover` | object\|string | 否 | 封面（`{thumbnail?, medium?, original?}`；相容單字串 → `original`） |
| `crossPlatformId` | string\|null | 否 | 跨平台統一 ID（dedup 軟連結） |
| `dataFingerprint` | string\|null | 否 | 資料指紋（dedup 輔助） |
| `progress` | object | 否 | 閱讀進度（`percentage?`, `currentPage?`, `totalPages?`, `lastReadAt?`） |
| `activeLoan` | object\|null | 否 | 活躍借閱記錄（APP-only，Extension carry+pass-through） |
| `createdAt` | string\|null | 否 | 建立時間（ISO 8601） |
| `updatedAt` | string\|null | 否 | 更新時間（ISO 8601，衝突解決比較用） |
| `tags` | object | 是 | 按類別分組的 tag（見 §5.3） |
| `extensions` | object | 否 | 平台專屬欄位（對方保留不認識的）：`{readmoo-book-extractor:{...}, book_overview_app:{...}}` |
| `_passthrough` | object | 否 | 未知欄位保留袋（round-trip 不丟） |

### 5.3 書籍 Tag 欄位（tags 物件內）

| Tag 類別 | 多值 | 說明 |
|---------|------|------|
| `author` | 是 | 作者（多語言） |
| `publisher` | 是 | 出版社 |
| `platform` | 是 | 來源平台 |
| `language` | 是 | 語言版本 |
| `isbn` | 是 | ISBN（多版本） |
| `alias` | 是 | 書名別名 |
| `readingStatus` | 單選 | 閱讀狀態（6 態，見 §5.5） |
| `importance` | 單選 | 重要程度（7 級，imp-1 ~ imp-7） |
| `series` | 是 | 叢書系列 |
| `description` | 單值 | 書籍描述 |
| `ccl` | 單選 | 中文圖書分類法（含 path，is_locked 樹） |
| `custom` | 是 | 使用者自定義 tag（含 path，巢狀） |

### 5.4 Root 欄位（檔案級）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `format` | string | 是 | 固定字面 `"book-interchange-v1"`（detector 辨識） |
| `formatVersion` | string | 是 | semver，當前 `"3.0.0"` |
| `metadata.exportedAt` | string(ISO8601) | 是 | 匯出時間 |
| `metadata.sourceApp` | string | 是 | 枚舉：`readmoo-book-extractor` / `book_overview_app` |
| `metadata.totalBooks` | number | 是 | books 數量（交叉驗證） |
| `books` | array | 是 | 書籍陣列 |
| `tagTree` | object | 否 | 需同步的階層 tag 樹（ccl + custom），匯入端重建對方 tag 樹 |

### 5.5 readingStatus 6 態正規化

`tags.readingStatus` 為單選 tag，canonical name 採以下 6 態：

| canonical name | APP 內部 ReadingStatus | 說明 |
|----------------|----------------------|------|
| `not_started` | `notStarted` | 未開始 |
| `queued` | `queued` | 排隊等待 |
| `reading` | `reading` | 閱讀中 |
| `finished` | `finished` | 已完成 |
| `abandoned` | `abandoned` | 已放棄 |
| `reference` | （pass-through 原值）| 參考書（隨時查閱） |

> APP adapter：DB 內部 `reading_status` tag ↔ 交換格式 `tags.readingStatus` camelCase 欄位名（wire）。

### 5.6 detector 五來源（匯入優先序）

匯入 detector 辨識來源，高優先序優先：

| 優先序 | 條件 | 判定 |
|--------|------|------|
| 1 | `format === "book-interchange-v1"` | 本 canonical v3.x（讀 formatVersion 分流） |
| 2 | `metadata.formatVersion` 以 `2.` 開頭（無 `format`）| V1 舊內部 v2 格式（相容讀） |
| 3 | 含 `backup_info`/`export_info` wrapper + `books[]` | APP legacy fixed-field（v0.31.x）|
| 4 | `extractionTimestamp` 存在 + `books[]` + 無 `format` | Extension 原生格式（readmoo-book-extractor 直接匯出） |
| 5 | 純陣列 或 `{books:[]}` 無版本標記 | flat v1（legacy converter） |

> **判定優先序說明**：來源 4（Extension 原生）排在來源 5（flat v1）之前，因 Extension 原生格式同時具備 `books[]` 與 `extractionTimestamp` 兩個結構標記，比 flat v1 的「無版本標記」更明確；先匹配來源 4 可避免 Extension 原生檔誤落入 flat v1 的寬鬆 fallback。來源 4 排在來源 1-3 之後，因來源 1-3 各有更強的格式宣告（`format` 字面、`metadata.formatVersion`、wrapper），優先匹配確保 canonical 與既有格式不被 Extension 原生規則攔截。

**Extension 原生格式根欄位**（detector 來源 4 判定依據）：

| 欄位 | 必備 | 說明 |
|------|------|------|
| `books` | 是 | 書籍陣列（Extension 直接輸出，無 `format` 包裝） |
| `extractionTimestamp` | 是 | 抓取時間戳（detector 辨識的關鍵標記） |
| `extractionCount` | 否 | 抓取書籍數（交叉驗證） |
| `extractionDuration` | 否 | 抓取耗時 |
| `source` | 否 | 來源平台（如 `readmoo`） |

**ChromeExtensionBookData DTO 擴充欄位**（路線 B 落地：從 5 欄位擴充以承載 Extension 原生 book 結構）：

| DTO 欄位 | Extension 原生 book 欄位 | App domain 映射 | 說明 |
|---------|------------------------|----------------|------|
| `readingStatus` | `readingStatus` | `tags.readingStatus`（6 態正規化，見 §5.5） | 閱讀狀態 |
| `progress` | `progress` / `progressInfo` | `progress`（§5.2） | 閱讀進度 |
| `tags` | `tags` / `tagIds` | `tags`（§5.3 分類化） | 標籤 |
| `url` | `url` | `extensions.readmoo-book-extractor.url` | 書籍來源連結（pass-through） |
| `authors` | `authors` | `tags.author`（§5.3） | 作者 |
| `source` | `source` | `tags.platform`（§5.3） | 來源平台 |

> DTO 擴充以最小集合（6 欄位）承載 Extension 原生 book 的核心語意，其餘原生欄位（`coverInfo`、`identifiers`、`schemaVersion` 等）視需求逐步加入或以 `_passthrough` 保留。實作 ticket：W2-004（detector 第 5 來源規則 + DTO 擴充 + mapper 調整）。

### 5.7 向下相容（舊格式匯入）

Flutter App 的 UC-01 匯入支援五種輸入，由 detector（§5.6）自動辨識：
- **canonical**：`{format:"book-interchange-v1", formatVersion, books:[...]}`（當前格式）
- **V1 舊內部 v2**：`{metadata.formatVersion:"2.x", books:[]}`
- **APP legacy**：含 `backup_info`/`export_info` wrapper
- **Extension 原生**：`{books:[...], extractionTimestamp, ...}`（readmoo-book-extractor 直接匯出，無 `format` 包裝；路線 B 落地）
- **flat v1**：`[{id, title, cover}]`（Chrome Extension v0.9.x）

### 5.8 統一平台列表

合併兩邊支援的平台：

| platform_id | 名稱 | Extension | App |
|-------------|------|----------|-----|
| `readmoo` | Readmoo | 是 | 是 |
| `kindle` | Amazon Kindle | 是 | 是 |
| `kobo` | Kobo | 是 | 是 |
| `bookwalker` | BookWalker | 是 | 是 |
| `books_com` | Books.com | 是 | 否（需加入） |
| `google_books` | Google Play Books | 否（需加入） | 是 |
| `apple_books` | Apple Books | 否（需加入） | 是 |
| `audible` | Audible | 否（需加入） | 是 |
| `spotify` | Spotify | 否（需加入） | 是 |
| `physical` | 實體書 | 否 | 是 |

---

## 6. 衝突解決策略

### 6.1 統一策略（v1.0 簡化版）

v1.0 使用 JSON 手動匯入匯出，衝突由匯入端處理：

| 情況 | 策略 | 說明 |
|------|------|------|
| 新書（對方有、本地無） | 自動加入 | 無衝突 |
| 相同書（ID 匹配、內容相同） | 跳過 | 無需處理 |
| 衝突書（ID 匹配、內容不同） | 保留較新版本 | 比較 `updated_at` |
| 本地有、對方無 | 保留本地 | 不刪除 |

### 6.2 統一策略（v2.0 完整版）

| 衝突類型 | 策略 | 說明 |
|---------|------|------|
| 只有一方修改 | 自動採用修改方 | 無衝突 |
| 雙方修改不同欄位 | 自動合併 | 欄位級合併 |
| 雙方修改相同欄位 | 標記衝突，使用者選擇 | 避免資料丟失 |
| 一方刪除 | 標記為刪除待確認 | 防誤刪 |

---

## 7. 執行計畫

> **執行策略修訂（漸進多 wave → 直接終態一次性重構）**
>
> 原 §7 v1.0 Phase 1 採「漸進多 wave 遷移」框架（facade getter + 雙 source + @Deprecated + 逐 domain 分 wave 遷移 + 漸進 DB migration），目的是維持遷移過渡期的向後相容。
>
> 本提案處於 pre-1.0 階段（無正式用戶、無 production DB、無對外運作契約：git 無 v1.0 tag、未上架、跨專案同步排在 v2.0），過渡期向後相容機制屬過度工程。**漸進多 wave 遷移框架自此廢棄，改為直接終態一次性重構**：開發 DB 採 drop + 終態 schema 直接重建，Book entity 一次刪除固定欄位 + facade getter + 舊 Value Object，全部消費端一次改完，測試全量更新。
>
> **明示保留（不受本次修訂影響）**：
> - §3.7 資料庫結構（終態 schema 設計）保持不變
> - §3.8 廢除的欄位（終態 Book model 設計）保持不變
> - §5 交換格式定義（wire format：camelCase + tags 物件）保持不變——wire format 是序列化層格式，與 DB 內部表示解耦，直接終態不影響對外對齊
>
> **修訂來源**：本策略修訂依 0.32.0-W2-023 ANA 結論落地（pre-1.0 直接終態完整影響評估，Solution 第五節執行策略修訂建議）。

### v1.0 Phase 1: 交換格式與 Model 對齊

> **執行方式**：下表步驟保留為「終態目標清單」。已完成的基礎設施步驟（步驟 3 Tag 系統、步驟 6/7 閱讀狀態與進度等）維持有效；尚未完成的「廢除舊固定欄位 + Model 重構」相關步驟（步驟 2/4）不再分 wave 漸進遷移，改由單一「直接終態一次性重構」ticket 一次完成（含 DB schema 終態 + Book entity 刪固定欄位/facade/VO + 全消費端一次遷移 + 測試全量更新）。

| 步驟 | 內容 | 負責 | 產出 |
|------|------|------|------|
| 1 | 確認 Interchange Format v1 spec | 雙方 | `docs/spec/interchange-format-v1.md` |
| 2 | Book Model 重新設計（固定欄位 + tag-based）—— 併入一次性終態重構 | 雙方 | DB 終態 schema + 程式碼重構 |
| 3 | Tag 系統實作（tag_categories + tags + book_tags） | 雙方 | 新資料表 + CRUD |
| 4 | 廢除舊固定欄位（author/publisher/isbn/genre 等）—— 併入一次性終態重構（drop + 終態 schema 重建，不漸進 migration） | 雙方 | 終態 schema |
| 5 | 內建中文圖書分類法（is_locked，獨立顯示） | 雙方 | 預裝 ~1000 節點 |
| 6 | 統一閱讀狀態（6 種 enum） | Extension | 新增 3 種狀態 |
| 7 | 閱讀進度欄位 | 雙方 | percentage/page/total |
| 8 | 書籍合併功能 | 雙方 | 多版本合併 + 主書名選擇 |
| 9 | Extension 匯出支援新格式 | Extension | UC-02 更新 |
| 10 | App 匯入支援新格式（向下相容舊格式） | App | UC-01 更新 |
| 11 | 雙向匯入匯出端到端測試 | 雙方 | 整合測試 |

### v1.0 Phase 2: Spec 文件整理

| 步驟 | 內容 | 負責 | 產出 |
|------|------|------|------|
| 8 | 兩邊 spec 加入交叉引用 | 雙方 | 文件更新 |
| 9 | 清理過時的共用 spec 內容 | 雙方 | 文件瘦身 |
| 10 | 統一平台列表（兩邊各補缺） | 雙方 | Platform enum 更新 |

### v2.0 Phase 3: Google Drive 同步

| 步驟 | 內容 | 負責 | 產出 |
|------|------|------|------|
| 11 | Google Cloud Project 設定 | 共用 | OAuth Client 配置 |
| 12 | Extension OAuth + Drive 寫入 | Extension | chrome.identity 整合 |
| 13 | App OAuth + Drive 讀取 | App | google_sign_in 整合 |
| 14 | 增量同步邏輯 | 雙方 | 差異比對 + 合併 |
| 15 | 衝突解決 UI | 雙方 | 使用者手動選擇介面 |
| 16 | 端到端同步測試 | 雙方 | 整合測試 |

---

## 8. 風險與失敗防護

### 8.1 風險與注意事項

| 風險 | 影響 | 緩解 |
|------|------|------|
| Chrome Storage 10MB 限制 | 完整欄位後資料量增加 | 估算 ~1.5KB/本，6600 本以內安全 |
| 舊格式向下相容 | 匯入邏輯複雜度 | Array vs Object 偵測簡單 |
| 兩邊版本不同步 | 一方更新格式另一方未跟上 | `formatVersion` semver + detector 五來源向下相容（PROP-007 §5.6）|
| Google Drive API 配額 | 免費版有請求限制 | 批次操作 + 增量同步 |
| OAuth 審查 | `drive.file` 不觸發敏感權限審查 | 低風險 |
| 衝突解決策略變更 | Extension 已實作的 SyncConflictResolver 需調整 | v2.0 再重構 |

### 8.2 失敗防護（tag model 落地的失敗情境與防護）

tag model 取代固定欄位後，主要失敗情境集中在「DB 與記憶體 tag 表示不一致」與「跨平台 round-trip 失真」。以下為已識別的失敗情境與對應防護：

| 失敗情境 | 影響 | 防護措施 |
|---------|------|---------|
| bookTags 與固定欄位 stale/空（過渡期雙 source 不同步） | 消費端改讀 tag 時讀到 stale 值，行為靜默改變 | 直接終態消除雙 source（§7 修訂），固定欄位刪除後無同步問題 |
| read-path 未 JOIN book_tags 導致 bookTags 空 | 查詢結果缺 tag 資料 | read-path `_assembleBooksWithTags` JOIN book_tags 填充（已實施，見 §10.3） |
| write-path 漏寫部分 tag 類別 | round-trip 後 tag 丟失 | write-path `_insertRelationalBookTags` 寫全部 bookTags（已實施，round-trip 三值通過） |
| 交換格式單值欄位被當多值（或反之） | 跨平台對齊錯誤 | §5.3 明訂每類別多值/單選；readingStatus/importance/description/ccl 單選，其餘多值 |
| 匯入端不認識新 tag 類別 | tag 資料丟失 | `_passthrough` 保留袋 + `extensions` 平台專屬欄位 round-trip 不丟（§5.2） |

---

## 9. 驗收標準

### v1.0 驗收

- [ ] Book Model 重新設計完成（固定欄位 + tag-based metadata）
- [ ] Tag 系統實作完成（tag_categories + tags + book_tags 三表）
- [ ] 12 個系統 tag 類別已預裝
- [ ] 舊固定欄位（author/publisher/isbn/genre）已遷移為 tag
- [ ] 中文圖書分類法已內建（~1000 節點，is_locked，獨立顯示）
- [ ] 自定義 tag tree 功能可用
- [ ] 書籍合併功能可用（多版本合併、主書名選擇）
- [ ] 統一閱讀狀態（6 種 enum）兩邊已實作
- [ ] 閱讀進度欄位兩邊已實作
- [ ] canonical book-interchange-v1 v3.0.0 spec 對齊完成（PROP-007 §5，見 W5-001）
- [ ] Extension 匯出新格式通過測試（含 tagTree）
- [ ] App 匯入新格式 + 舊格式通過測試
- [ ] 雙向匯入匯出端到端測試通過
- [ ] 兩邊 spec 文件加入交叉引用

### v2.0 驗收

- [ ] Google Cloud Project 建立，OAuth Client 配置完成
- [ ] Extension OAuth + Drive 寫入功能通過測試
- [ ] App OAuth + Drive 讀取功能通過測試
- [ ] 增量同步正確（只傳差異）
- [ ] 衝突解決 UI 可用
- [ ] 端到端同步測試通過（Extension 寫 → Drive → App 讀 → 修改 → Drive → Extension 更新）

---

## 10. 提案評估記錄（heavy 級回顧式補課）

> **本章性質**：PROP-007 標 `evaluation_level: heavy`，但建立時僅含設計內容，缺 heavy 級正式評估章節（多視角審查 / 機會成本 / Reality Test）。tag model 決策已 confirmed 並完整實施，本章為回顧式整合既有評估素材的治理補課，非重啟決策。各小節明確標注素材來源 ticket（屬 §引用穩定性規則 7 允許的「來源標注」，非依賴型引用）。

### 10.1 多視角審查：多值 tag model vs 單值固定欄位

核心設計權衡——書籍 metadata 採「多值 tag」或「單值固定欄位字串」。整合 §3.1 設計哲學與 §3.8 廢除理由。

| 視角 | 單值固定欄位（傳統 model） | 多值 tag model（本提案採用） |
|------|------------------------|---------------------------|
| 資料真實性 | 假設每本書一個作者/出版社/ISBN，與現實不符 | 同一本書可有中文版/日文版/英文版，多作者譯名、多出版社、多 ISBN（§3.1）|
| 跨平台購買 | 單一 `source`/`platform_id` 無法表達多平台擁有 | `platform` tag 多值，同書可 readmoo + kindle + 實體（§3.3）|
| 出版社易手 | 欄位被覆寫，歷史版本資訊丟失 | 多值保留所有版本出版社 |
| schema 演化 | 新增分類需 ALTER TABLE 加欄位 | tag_categories 加一筆 row，schema 不動（§3.7）|
| 查詢複雜度 | 直接讀欄位，簡單 | 需 JOIN book_tags + tags，較複雜 |
| 單選語意 | 天然單值 | 需 `is_primary` / 單選約定表達（reading_status/importance 單選，§5.3）|
| 書籍合併 | 欄位衝突需人工選一個，其餘丟棄 | tag 自然合併，所有 ISBN/別名保留為多值（§3.6）|

**審查結論**：多值 tag model 在「資料真實性、跨平台表達、schema 演化、書籍合併」四個維度勝出，代價是「查詢複雜度上升 + 單選語意需額外約定」。對書籍管理這個 domain（多版本、多平台、多語言是常態），真實性與可演化性的價值高於查詢簡單性。固定欄位僅保留真正每本書唯一的屬性（id/title/cover/cross_platform_id/data_fingerprint/progress/時間戳，§3.2），其餘全 tag 化（§3.8）。

> 素材來源：PROP-007 §3.1 / §3.3 / §3.6 / §3.8（設計哲學與廢除欄位理由）。

### 10.2 機會成本：直接終態一次性重構 vs 漸進多 wave 遷移

到達 tag model 終態有兩條路徑。整合 0.32.0-W2-023 ANA Solution 的完整 WRAP 評估。

| 維度 | 漸進多 wave 遷移（原 §7 框架） | 直接終態一次性重構（採用） |
|------|----------------------------|--------------------------|
| 向後相容機制 | facade getter + 固定欄位/bookTags 雙 source + @Deprecated + 漸進 migration（v6→v9）+ 消費端分 wave | 無需向後相容（pre-1.0 無 production DB） |
| 適用前提 | 成熟產品：有正式用戶、production DB、對外運作契約 | pre-1.0：git 無 v1.0 tag、未上架、跨專案同步排 v2.0 |
| 過渡期成本 | 雙寫邏輯認知負擔 + tag stale/空 bug 風險 + 長 blockedBy 依賴鏈 | 一次重構消除雙 source，無過渡期 bug 類 |
| 已做工作影響 | 全部保留 | 核心保留（三表 W1-003 / read-path W2-013 / write-path W2-020）；作廢者僅 migration scripts + 漸進遷移分析結論，無程式碼浪費 |
| ticket 影響 | 32 張 tag 遷移 ticket 互相 blockedBy | 取消 7 張（漸進框架產物）、簡化 5 張、合併 4 張為 1 張一次性重構 |

**機會成本結論**：漸進遷移是「誤套成熟產品模式」的過度工程——pre-1.0 無任何需向後相容保護的既有狀態，漸進機制解決的問題（保護既有 DB 用戶資料、降低上線風險）在 pre-1.0 都不存在。選擇漸進的機會成本是：付出雙寫認知負擔 + stale/空 bug 風險 + 長依賴鏈，換取一個不需要的向後相容保證。直接終態以「drop + 終態 schema 重建」消除這些成本，且 §5 wire format 不受影響（序列化層與 DB 內部表示解耦）。

> 素材來源：0.32.0-W2-023 ANA Solution（直接終態完整影響評估、32 ticket 分類、DB 重建策略、wire format §5 不受影響確認）。§7 執行策略已由 0.32.0-W2-024 落地此結論。

### 10.3 Reality Test：tag model 已實施並驗證

tag model 非紙上設計，已在 Flutter App 端落地並通過測試。以下為已驗證的事實（非假設）：

| 驗證對象 | 實施內容 | 驗證狀態 |
|---------|---------|---------|
| tag 三表基礎設施 | tag_categories / tags / book_tags 三表建立 + author 等固定欄位 backfill 至 tag | 已完成（0.32.0-W1-003）|
| read-path 填充 | `_assembleBooksWithTags` JOIN book_tags 填充 bookTags | 已完成（0.32.0-W2-013）|
| write-path 接線 | `_insertRelationalBookTags` 寫全部 bookTags + source_type tag | 已完成（0.32.0-W2-020）|
| round-trip 一致性 | write → read 多值 tag（author / publisher / platform 等三值）round-trip | 通過（0.32.0-W2-019 / W2-020 測試實證）|

**Reality Test 結論**：tag model 從「資料表結構 → backfill → read-path → write-path → round-trip」全鏈路已驗證可運作，§3.7 終態 schema 與 §5 wire format 對齊的可行性有實證支撐，非設計階段假設。失敗情境與防護見 §8.2。

> 素材來源：0.32.0-W1-003 / W2-013 / W2-019 / W2-020（tag 系統實施與測試 completed ticket）。

---

*Last Updated: 2026-06-16*

*變更歷史：*
*- 2026-06-16：§5.6 detector 四來源擴充為五來源（路線 B 落地），新增來源 4「Extension 原生格式」（判定條件：`books[]` + `extractionTimestamp` + 無 `format`）及判定優先序說明；新增 Extension 原生格式根欄位表與 ChromeExtensionBookData DTO 擴充欄位對應表（readingStatus/progress/tags/url/authors/source）；§5.7 向下相容同步更新為五種輸入；§7 風險表「四來源」字面同步為「五來源」。本次變更由 0.32.0-W2-027.1 執行，依 0.32.0-W2-027 路線 B 決策落地，供 W2-004/W2-006 引用。*
*- 2026-06-14：新增 §10 提案評估記錄（heavy 級回顧式補課：多視角審查 / 機會成本 / Reality Test），整合既有評估素材補回 heavy proposal 應有的正式評估章節；§8 改為「風險與失敗防護」並新增 §8.2 失敗防護小節（對齊 heavy 章節失敗情境要求）。本次變更由 0.32.0-W2-026 執行；素材來源 0.32.0-W2-023（機會成本）、W1-003/W2-013/W2-019/W2-020（Reality Test）。tag model 決策已 confirmed 並實施，本次為治理記錄補課，不變更既有決策。*
*- 2026-06-14：§7 執行策略由「漸進多 wave 遷移」修訂為「直接終態一次性重構」（pre-1.0 無向後相容需求）；§3.7/§3.8 終態設計與 §5 wire format 保持不變。本次變更由 0.32.0-W2-024 執行，依 0.32.0-W2-023 ANA 結論落地。*
*- 2026-04-02：提案建立。*
