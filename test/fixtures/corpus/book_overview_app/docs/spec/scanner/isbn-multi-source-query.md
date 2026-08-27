---
id: SPEC-010
title: "ISBN 多來源查詢規格"
status: draft
source_proposal: PROP-015
created: "2026-06-18"
updated: "2026-06-18"
version: "1.0"
owner: ""

domain: scanner
subdomain: multi-source-query

related_usecases: [UC-03, UC-04]
related_specs: [SPEC-004, SPEC-005]
implements_requirements: []
depends_on_domains: [book_info]
---

# ISBN 多來源查詢規格

## 概述

定義 ISBN 查詢的多 API 來源整合策略，包含 Open Library API、台灣國家圖書館 API、ISBN prefix 地區路由、以及多來源降級機制。

本規格擴充現有 `UnifiedBookInfoService` 架構，新增 API 來源不修改 domain 層介面。

## 功能需求 (FR)

### FR-1: Open Library API 整合

| 項目 | 說明 |
|------|------|
| 端點 | `GET https://openlibrary.org/isbn/{isbn}.json` |
| 搜尋端點 | `GET https://openlibrary.org/search.json?q={query}` |
| 封面圖片 | `https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg` |
| 認證 | 無需 API key |
| 回傳格式 | JSON |

**欄位對應**：

| Open Library 欄位 | BookEnrichmentData 欄位 | 說明 |
|-------------------|------------------------|------|
| `title` | `title` | 書名 |
| `authors[].name` | `authors` | 需額外查 `/authors/{key}.json` |
| `publishers[0]` | `publisher` | 出版社 |
| `publish_date` | `publishedDate` | 出版日期（格式不固定，需解析） |
| `number_of_pages` | `pageCount` | 頁數 |
| `isbn_13[0]` / `isbn_10[0]` | `isbn` | ISBN |
| covers endpoint | `thumbnailUrl` | 封面圖片 URL |
| `description.value` 或 `description` | `description` | 描述（可能是 string 或 object） |

**注意事項**：
- Open Library 的 `/isbn/{isbn}.json` 回傳的是 Edition 資料，作者欄位是 key reference（如 `/authors/OL1234A`），需額外查詢
- `publish_date` 格式不一致（可能是 "2020"、"January 1, 2020"、"2020-01-01"），需要寬容解析
- `description` 可能是純字串或 `{"type": "/type/text", "value": "..."}`

### FR-2: NBINet 聯合目錄整合（取代原國圖 API 方案）

> **W3-001 驗證結論**：國圖 6 個 API 端點全部不可用（HTTP 500 / 連線失敗）。NBINet 聯合目錄為唯一可用的台灣書目查詢來源（3/3 ISBN 命中，含小出版社）。

| 項目 | 說明 |
|------|------|
| 服務 | NBINet 全國圖書書目資訊網 |
| 端點 | `https://nbinet3.ncl.edu.tw/search~S1*cht/?searchtype=i&searcharg={ISBN}` |
| 認證 | 無需帳號或 API key（公開存取） |
| 回傳格式 | HTML（需 scraping 解析） |
| 限流 | 無官方文件，建議自限 30 req/min |

**HTML scraping 欄位對應**：

| HTML 元素 | BookEnrichmentData 欄位 | 說明 |
|-----------|------------------------|------|
| 書目記錄「題名」欄 | `title` | 書名（含副標題） |
| 書目記錄「著者」欄 | `authors` | 作者（需解析分隔符） |
| 書目記錄「出版項」欄 | `publisher` + `publishedDate` | 出版社和出版年（需拆分） |
| 書目記錄「ISBN」欄 | `isbn` | ISBN 確認 |
| — | `thumbnailUrl` | NBINet 不提供封面，需從 Google Books 補充 |
| — | `description` | NBINet 不提供描述，需從 Google Books 補充 |

**scraping 降級策略**：

| 情境 | 行為 |
|------|------|
| DOM 結構變更導致解析失敗 | 記錄 warning，fallback 到 Google Books |
| HTTP 連線失敗 | 標記 NBINet 暫時降級，fallback 到 Google Books |
| 回傳頁面無書目記錄 | 正常無結果，嘗試 Google Books |

### FR-3: ISBN Prefix 地區路由

根據 ISBN-13 的 Registration Group Element 自動選擇最佳 API 查詢順序。

**ISBN-13 結構**：`{EAN Prefix}-{Registration Group}-{Registrant}-{Publication}-{Check Digit}`

**路由規則**：

| Registration Group | 地區 | API 優先順序 |
|-------------------|------|-------------|
| 957, 986, 626 | 台灣 | NBINet scraping -> Google Books |
| 962, 988 | 香港 | Google Books -> Open Library |
| 7 | 中國大陸 | Google Books -> Open Library |
| 4 | 日本 | Google Books -> Open Library |
| 0, 1 | 英語系國家 | Google Books -> Open Library |
| 其他 | 其他地區 | Google Books -> Open Library |

**路由邏輯**：

1. 從 ISBN-13 提取 Registration Group（第 4 位開始，長度 1-5 位不等）
2. 查表取得優先 API 順序
3. 依序嘗試，第一個成功回傳即停止
4. 所有 API 都失敗時返回查無結果

**ISBN-10 處理**：先透過既有 `Isbn.toIsbn13()` 轉換為 ISBN-13，再套用路由規則。

### FR-4: 多來源降級機制

整合現有 `fallback_decision_engine` 和 `degraded_mode_strategy`：

| 情境 | 行為 |
|------|------|
| 主要 API 回傳結果 | 直接使用，不查 fallback |
| 主要 API 查無結果（HTTP 200 但 empty） | 依序嘗試下一個 API |
| 主要 API 超時（> 5 秒） | 標記該 API 暫時降級，嘗試下一個 |
| 主要 API 錯誤（HTTP 4xx/5xx） | 記錄錯誤，嘗試下一個 |
| 所有 API 都失敗 | 返回查無結果，書籍以 ISBN 暫存 |
| 降級 API 恢復 | 下次查詢重新嘗試（circuit breaker pattern） |

### FR-5: 查詢結果合併

當多個 API 都有結果時（例如 fallback 查詢時主要 API 也延遲回傳），取最完整的結果：

| 合併策略 | 說明 |
|---------|------|
| 標題 | 取最長（含副標題）的版本 |
| 作者 | 取列出最多作者的版本 |
| 描述 | 取最長的版本 |
| 封面 | 優先 Google Books（品質最高），次 Open Library |
| 頁數 | 取非 null 的第一個 |
| 出版日期 | 取精確度最高的（日 > 月 > 年） |
| ISBN | 來源 ISBN 保持不變 |

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 | 說明 |
|------|------|------|
| 單一 API 查詢 timeout | 5 秒 | 超時即嘗試下一個 |
| 整體查詢 timeout | 15 秒 | 所有 API 嘗試加總 |
| Open Library 限流 | 100 req/min | 官方建議上限 |
| 國圖 API 限流 | 待確認 | 依 API 文件設定 |
| 快取命中 | < 10ms | 沿用現有 LRU cache |

### NFR-2: 快取策略

| 來源 | 快取 key | TTL | 說明 |
|------|---------|-----|------|
| Google Books | `gb:{isbn}` | 24h | 現有機制 |
| Open Library | `ol:{isbn}` | 24h | 新增 |
| NBINet | `nbinet:{isbn}` | 7d | NBINet 書目資料穩定度高，延長 TTL |
| 路由結果 | `route:{isbn}` | 1h | 快取路由決策避免重複解析 |

### NFR-3: 可觀測性

每次查詢必須記錄：

```dart
AppLogger.infoStatic(
  'ISBN query: $isbn, route: $selectedApi, result: $status, elapsed: ${elapsed}ms',
  'IsbnRegionRouter',
);
```

降級事件記錄：
```dart
AppLogger.warningStatic(
  'API degraded: $apiName, reason: $reason, fallback: $nextApi',
  'MultiSourceQueryService',
);
```

## 架構設計

### 新增元件

| 元件 | 層級 | 職責 |
|------|------|------|
| `IsbnRegionRouter` | Domain Service | 根據 ISBN prefix 決定 API 查詢順序 |
| `OpenLibraryApiClient` | Infrastructure | Open Library HTTP client + DTO 轉換 |
| `NbinetScrapingClient` | Infrastructure | NBINet HTML scraping + 解析 |
| `MultiSourceQueryService` | Infrastructure | 依路由順序呼叫多個 API，管理降級 |
| `OpenLibraryDto` | Infrastructure/DTO | Open Library JSON -> BookEnrichmentData |
| `NbinetHtmlParser` | Infrastructure | NBINet HTML -> BookEnrichmentData |

### 與現有元件的關係

```
QueryTypeResolver (不修改)
    |
    v  (ISBN 類型時)
IsbnRegionRouter (新增)
    |
    v  (回傳 API 優先順序)
MultiSourceQueryService (新增，實作 UnifiedBookInfoService)
    |
    +-- GoogleBooksApiClient (現有)
    +-- OpenLibraryApiClient (新增)
    +-- NbinetScrapingClient (新增)
    |
    v
FallbackDecisionEngine (現有，擴充 API 清單)
```

## 測試策略

| 測試類型 | 範圍 | 說明 |
|---------|------|------|
| Unit | `IsbnRegionRouter` | 各 prefix 路由正確性 |
| Unit | `OpenLibraryDto` | JSON 轉換、邊界格式處理 |
| Unit | `NbinetHtmlParser` | HTML scraping 解析正確性 |
| Unit | ISBN checksum | 沿用 feat/1.1.0 分支既有 15 個測試 |
| Integration | `MultiSourceQueryService` | fallback 鏈、降級恢復 |
| Widget | 掃描 UI | 沿用 feat/1.1.0 分支既有測試 |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-03: ISBN 條碼掃描新增書籍（掃描 -> 路由 -> 多來源查詢）
- UC-04: 關鍵字搜尋補充書籍資訊（搜尋時使用多來源）

## 相關規格

- SPEC-004: ISBN 條碼掃描規格（掃描硬體整合）
- SPEC-005: 關鍵字搜尋與資訊補充規格（搜尋流程）
