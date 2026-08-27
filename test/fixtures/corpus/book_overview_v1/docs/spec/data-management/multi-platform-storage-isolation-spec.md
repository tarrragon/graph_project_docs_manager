---
id: SPEC-STORAGE-ISOLATION
title: "多書城 Storage 隔離規格"
status: draft
source_ticket: 1.6.0-W2-003
created: "2026-07-14"
version: "1.0"
domain: data-management
related_specs: [SPEC-003]
---

# 多書城 Storage 隔離規格

## 問題

現有 `STORAGE_KEYS.READMOO_BOOKS = 'readmoo_books'` 為唯一書目 storage key，多書城場景下後提取的書城資料覆蓋前一個。

## 設計決策

### D1: Storage Key 命名規範

| 書城 | platformId | storage key |
|------|-----------|-------------|
| Readmoo | readmoo | `readmoo_books` |
| 博客來 | books_com_tw | `books_com_tw_books` |
| Kobo | kobo | `kobo_books` |
| BookWalker | bookwalker | `bookwalker_books` |
| Kindle | kindle | `kindle_books` |

命名規則：`{platformId}_books`，其中 `platformId` 為小寫 snake_case。

### D2: 常數定義（SSOT: module-constants.js）

```javascript
const PLATFORM_IDS = {
  READMOO: 'readmoo',
  BOOKS_COM_TW: 'books_com_tw',
  KOBO: 'kobo',
  BOOKWALKER: 'bookwalker',
  KINDLE: 'kindle'
}

function platformBooksKey(platformId) {
  return `${platformId}_books`
}
```

`STORAGE_KEYS.READMOO_BOOKS` 保留不刪（向後相容 + 遷移基線），但所有新寫入改用 `platformBooksKey(platformId)`。

### D3: 讀取合併策略

Overview 和匯出需合併所有書城資料：

```javascript
async function loadAllPlatformBooks() {
  const allKeys = Object.values(PLATFORM_IDS).map(platformBooksKey)
  const result = await chrome.storage.local.get(allKeys)
  const merged = []
  for (const key of allKeys) {
    if (result[key]?.books) {
      merged.push(...result[key].books)
    }
  }
  return merged
}
```

### D4: 匯出變更

CSV 匯出新增 `source` 欄位，值為 `platformId`（如 `readmoo`、`kobo`）。每本書的 `source` 在提取時寫入 book model。

### D5: 現有資料相容

- 已存在的 `readmoo_books` key 不需遷移（Readmoo 的 platformId 就是 `readmoo`，key 不變）
- 其他書城是新增 key，無舊資料需遷移

## 影響範圍

### 寫入路徑（需改為 platform-aware）

| 檔案 | 改動 |
|------|------|
| `event-coordinator.js:586` | `readmoo_books` → `platformBooksKey(platform)` |
| `data-processing-service.js:196` | 處理器 key 改為動態 |

### 讀取路徑（需改為合併讀取）

| 檔案 | 改動 |
|------|------|
| `popup-message-handler.js:385` | 改讀所有平台 key 合併 |
| `popup-message-handler.js:750` | 匯出改讀合併 |
| `popup.js:1100` | storage 變更監聽改為匹配 `*_books` 模式 |
| `sync-panel.js:101` | 改讀合併 |
| `tag-storage-adapter.js:260-272` | 改讀寫指定平台 |

### 清除路徑

| 檔案 | 改動 |
|------|------|
| `popup-message-handler.js:812` | 清除改為移除所有 `*_books` key |
| `install-handler.js:322` | 初始化所有平台 key |

### 匯出路徑

| 檔案 | 改動 |
|------|------|
| `export-service.js:186` | 檔名前綴改為通用或含平台名 |

## 驗收條件

1. 不同書城提取的書目資料儲存在各自獨立的 storage key
2. Overview 頁面合併顯示所有書城的書目
3. CSV 匯出包含所有書城的書目（含 source 欄位區分來源）
4. 提取一個書城不影響其他書城已儲存的資料

## 不做

- 不啟用完整 `PlatformIsolationService`（過度設計，1,308 行容器/沙箱系統）
- 不做資料遷移（Readmoo key 不變，新平台無舊資料）
- 不改 `chrome-storage-adapter.js` 的 `keyPrefix`（那是 adapter 層級，與 book 無關）
