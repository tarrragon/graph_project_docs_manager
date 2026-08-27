---
id: PROP-015
title: "ISBN 多來源查詢增強 — Open Library + 台灣國圖 + 條碼掃描 + 地區路由"
status: confirmed
source: "development"
proposed_by: "user / research-analysis"
proposed_date: "2026-06-18"
confirmed_date: "2026-06-18"
target_version: "0.37.0"
priority: P1
evaluation_level: standard

outputs:
  spec_refs: [spec/scanner/isbn-barcode-scanning.md, spec/scanner/isbn-multi-source-query.md]
  usecase_refs: [usecases/UC-03-isbn-barcode-scanning.md]
  ticket_refs: [0.37.0-W2-001, 0.37.0-W2-002, 0.37.0-W2-003, 0.37.0-W3-001, 0.37.0-W3-002]

related_proposals: []
supersedes: null
---

# PROP-015: ISBN 多來源查詢增強

## 需求來源

社群調查（2026-06-18）比較了 GitHub 上 vibe coding 書庫 APP 的 ISBN 處理方式，發現本專案在查詢策略分層和降級架構上領先社群，但有四個明確缺口：

1. **API 來源單一**：僅使用 Google Books API，對繁中書籍和冷門書覆蓋率不足
2. **無相機掃描**：UC-03 已設計但未實作 `mobile_scanner` 整合
3. **無地區路由**：ISBN prefix 未用於選擇最佳 API 來源
4. **ISBN 驗證不完整**：僅驗長度和字元，未驗 check digit

## 問題描述

Google Books API 對台灣出版書籍的覆蓋率低（尤其小出版社、學術書、獨立出版），用戶手動輸入 ISBN 後查無結果的體驗差。同時缺乏相機掃描使得新增實體書的流程比競品慢 5-10 倍。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `book_info` domain、`infrastructure/` API 層、`scanner` domain（新增） |
| 檔案 | `UnifiedBookInfoService` 實作、`BookInputValidator`、新增 API client |
| 用例 | UC-03（掃描）、UC-04（搜尋補充） |

## 範圍界定

### 本提案要做的（In Scope）

1. **NBINet 書目查詢整合**：串接 NBINet 聯合目錄（`nbinet3.ncl.edu.tw`）HTML scraping，作為繁中書籍查詢來源（W3-001 驗證：3/3 ISBN 命中，國圖無公開 API）
2. **Open Library API 整合**：新增 Open Library 作為**英文/國際書籍**的 fallback 來源（W3-002 驗證：繁中書覆蓋率僅 10%，僅適合非中文書）
3. **mobile_scanner 條碼掃描**：整合 `mobile_scanner` 套件實作 UC-03 的相機掃描流程（W3-003 驗證：^7.0.1 完全相容）
4. **ISBN prefix 地區路由**：根據 ISBN-13 prefix 自動選擇最佳 API 來源（台灣 prefix → NBINet 優先）
5. **ISBN checksum 驗證**：沿用 feat/1.1.0 分支既有 `Isbn` Value Object（已實作完整 checksum）

### 本提案不做的（Out of Scope）

- 台灣國家圖書館 API（REST/SRU/Z39.50）→ W3-001 驗證不存在，改用 NBINet
- Amazon Product Advertising API → 需商業授權，成本待評估，獨立提案
- ISBNdb 付費 API → 暫不引入
- 封面圖片辨識 → 技術不成熟，效益不明確
- NDL（日本國會圖書館）→ 目標用戶以繁中為主，日文書需求待驗證
- 批次掃描（連續掃描多本書）→ 單本掃描穩定後再考慮

## 提案方案

### 架構設計

利用現有 `UnifiedBookInfoService` 抽象介面 + DIP 架構，新增 API 來源不需修改 domain 層：

```
BookQueryInput
    |
    v
QueryTypeResolver (ISBN > combined > title > author)
    |
    v
IsbnRegionRouter (新增)
    |  - 978-957/986/626 -> NBINet scraping (優先) -> Google Books (fallback)
    |  - 978-0/1 (英語系) -> Google Books (優先) -> Open Library (fallback)
    |  - 其他 -> Google Books (優先) -> Open Library (fallback)
    v
UnifiedBookInfoService 實作
    |
    v
BookEnrichmentData
```

### 各模組說明

#### 1. Open Library API Client

| 項目 | 說明 |
|------|------|
| 端點 | `https://openlibrary.org/isbn/{isbn}.json`（ISBN 查詢）、`https://openlibrary.org/search.json`（搜尋）|
| 認證 | 無需 API key |
| 限流 | 官方建議 100 req/min，實作 rate limiter |
| 回傳 | JSON，需轉換為 `BookEnrichmentData` |
| 優勢 | 舊書、冷門書覆蓋率高；完全免費 |
| 劣勢 | 回應速度較慢（1-3s）、封面圖片品質不一 |

#### 2. NBINet 聯合目錄 Scraping Client（取代原國圖 API 方案）

> W3-001 驗證結論：國圖 6 個 API 端點全部不可用（HTTP 500 / 連線失敗）。NBINet 是唯一可用的台灣書目查詢來源。

| 項目 | 說明 |
|------|------|
| 端點 | `https://nbinet3.ncl.edu.tw/search~S1*cht/?searchtype=i&searcharg={ISBN}` |
| 認證 | 無需帳號或 API key（公開存取） |
| 回傳 | HTML（需 scraping 解析） |
| 可取得欄位 | 題名、版本項、出版項、國際標準書號 |
| 優勢 | 台灣出版品覆蓋率高（W3-001 測試 3/3 命中，含小出版社） |
| 劣勢 | HTML scraping 脆弱（DOM 結構可能變更）、無封面圖片、無描述 |

#### 3. mobile_scanner 整合

| 項目 | 說明 |
|------|------|
| 套件 | `mobile_scanner` ^6.0.0 |
| 平台 | Android（CameraX + MLKit）、iOS（AVFoundation + Vision） |
| 格式 | EAN-13（ISBN-13 標準條碼格式） |
| APP 體積影響 | +3-10MB（bundled MLKit） |
| 效能 | 平均 < 1 秒辨識 |

#### 4. ISBN Prefix 地區路由

ISBN-13 結構：`978-{Registration Group}-{Registrant}-{Publication}-{Check Digit}`

| Registration Group | 地區 | 優先 API |
|-------------------|------|---------|
| 957, 986, 626 | 台灣 | NBINet scraping -> Google Books |
| 962, 988 | 香港 | Google Books -> Open Library |
| 7 | 中國大陸 | Google Books -> Open Library |
| 4 | 日本 | Google Books -> Open Library |
| 0, 1 | 英語系 | Google Books -> Open Library |
| 其他 | 其他地區 | Google Books -> Open Library |

#### 5. ISBN Checksum 驗證

**ISBN-13 check digit**：
```
sum = sum(digit[i] * weight[i])  where weight = [1,3,1,3,1,3,1,3,1,3,1,3,1]
valid if sum % 10 == 0
```

**ISBN-10 check digit**：
```
sum = sum(digit[i] * (10-i))  for i = 0..9
valid if sum % 11 == 0  (digit[9] 可為 'X' 代表 10)
```

## 驗收條件

- [ ] Open Library API 可通過 ISBN 查詢書目並轉為 `BookEnrichmentData`
- [ ] NBINet scraping 可通過 ISBN 查詢繁中書目並轉為 `BookEnrichmentData`
- [ ] `mobile_scanner` 可在 Android/iOS 掃描 EAN-13 條碼並取得 ISBN
- [ ] ISBN prefix 路由可根據 Registration Group 選擇優先 API
- [ ] Google Books 查無結果時自動 fallback 至 Open Library
- [ ] 台灣出版品（978-957/986/626）優先查詢 NBINet
- [ ] ISBN-10 和 ISBN-13 checksum 驗證正確拒絕無效 ISBN
- [ ] ISBN-10 check digit 支援 'X' 字元
- [ ] 掃描到顯示書籍 < 2 秒（UC-03 效能要求）
- [ ] 所有新增 API client 有對應的降級策略（API 掛掉時 fallback）

## Reality Test / 觸發案例實證

### 觸發案例

2026-06-18 社群調查發現：GitHub 上 70%+ 的讀書記錄 APP 都有相機 barcode 掃描作為核心功能；本專案 UC-03 已設計完整流程但未實作。同時 Google Books API 對台灣出版品覆蓋率低是已知問題（用戶回報查詢 978-986-xxx 類 ISBN 經常無結果）。

### 假設列舉

- 假設 1：Open Library API 對 Google Books 查無結果的書有補充覆蓋
- 假設 2：台灣國家圖書館有公開可用的 ISBN 查詢 API
- 假設 3：`mobile_scanner` 套件在 Flutter 3.x 環境穩定可用
- 假設 4：ISBN prefix 可靠地對應出版地區

### 實驗驗證（W3 ANA 結果，2026-06-18）

| 假設 | 驗證方式 | 執行的實驗/觀察 | 結果 |
|------|---------|----------------|------|
| 假設 1 | 抽樣查詢（1.1.0-W3-002） | 20 本台灣出版書 ISBN 分別查 Open Library | **不成立**：命中率 10%，命中書目標題為羅馬拼音非中文，搜尋 API 不支援中文 |
| 假設 2 | API 端點測試（1.1.0-W3-001） | 測試國圖 6 個端點（X-Server/OPAC/Z39.50/metadata/catbase/opendata） | **不成立**：全部 HTTP 500 或連線失敗。NBINet 為替代方案（HTML scraping，3/3 命中） |
| 假設 3 | 版本比對（1.1.0-W3-003） | mobile_scanner ^7.0.1 vs 專案 Dart 3.10.9 / Flutter 3.38.10 | **成立**：完全相容，flutter pub get 成功無衝突 |
| 假設 4 | ISBN 標準文件 | ISBN prefix 由 International ISBN Agency 分配 | 已驗證 |

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | ISBN prefix 對應地區為國際標準；mobile_scanner 完全相容（W3-003）；Open Library 對繁中書覆蓋率極低（W3-002）；國圖無公開 API、NBINet scraping 可用（W3-001） |
| 未驗證 | Google Books 對繁中書的實際覆蓋率（W3-002 因 HTTP 429 配額超限未能完整測試，需帶 API key 重測） |

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| NBINet DOM 結構變更 | scraping 失敗 | 降級到 Google Books；DOM selector 集中管理便於維護 |
| Open Library 回應速度慢 | 用戶體驗變差 | 僅作非中文書 fallback；加快取 |
| mobile_scanner 體積增加 3-10MB | APP 下載體積增大 | 使用 unbundled MLKit（約 600KB，需 Play Services）|
| NBINet 無封面圖片和描述 | 繁中書資料不完整 | 先用 NBINet 取得標題/作者，再用 Google Books 補封面/描述 |
| 多 API fallback 增加延遲 | 最壞情況查詢時間長 | 設 timeout、平行查詢策略 |
| Google Books API 配額超限 | 無 API key 時 HTTP 429 | 申請 API key（W3-004 ticket 追蹤） |

## 失敗防護

| 失敗情境 | 偵測方式 | 回退措施 |
|---------|---------|---------|
| NBINet scraping 全面失效（DOM 大改） | HTML parser 回傳空結果 + 連續 N 次失敗 | 自動降級到 Google Books；記錄 warning 日誌 |
| Open Library API 不可用 | HTTP timeout / 5xx | 跳過 Open Library，僅用 Google Books |
| Google Books API 配額超限 | HTTP 429 回應 | 降級模式：只用本地快取 + NBINet |
| mobile_scanner 相機掃描失敗 | 條碼辨識逾時 > 5 秒 | 提供手動輸入 ISBN fallback（UC-03 FR-5） |
| ISBN prefix 路由錯誤（未知 prefix） | Registration Group 查表未命中 | fallback 到預設路由（Google Books -> Open Library） |
| 所有 API 同時不可用 | 所有來源回傳失敗 | 書籍以 ISBN 暫存入庫，加入離線佇列待恢復 |

**回退原則**：任一 API 失敗不阻塞用戶操作，最壞情況書籍以 ISBN 暫存，後續自動補充。

## 與 feat/1.1.0-W2-001-qr-scan-restore 分支的整合

另一個 worktree（`feat/1.1.0-W2-001-qr-scan-restore`，PROP-014 QR 離線同步）已有以下相關實作：

| 元件 | 狀態 | 整合策略 |
|------|------|---------|
| `mobile_scanner` ^7.0.1 依賴 | 已加入 pubspec.yaml | 直接沿用，不重複引入 |
| `Isbn` Value Object（ISBN-10/13 checksum 完整驗證） | 已實作（`lib/domains/scanner/value_objects/isbn.dart`） | 直接沿用，本提案不重建 checksum |
| `ISBNScannerService`（掃描→驗證→建書→背景補充） | 已實作（`startScanning()` 為 TODO） | 補上 `mobile_scanner` 相機整合 |
| `IsbnValidationService` | 已實作 | 直接沿用 |
| scanner domain 目錄結構（40+ 檔案） | 已建立 | PROP-015 在此基礎上擴充 |
| Open Library API | 未實作 | 本提案新增 |
| 台灣國圖 API | 未實作 | 本提案新增 |
| ISBN prefix 地區路由 | 未實作 | 本提案新增 |

**整合結論**：本提案的實際新增工作縮減為三項：(1) Open Library API client、(2) 台灣國圖 API client、(3) ISBN prefix 地區路由。mobile_scanner 整合和 checksum 驗證已由 PROP-014 分支完成，合併後直接可用。

**合併順序建議**：先合併 PROP-014 分支到 main，再基於已有 scanner domain 開發本提案的多來源查詢。

## 討論記錄

### 2026-06-18

社群調查結果驅動本提案。五個功能點（Open Library、國圖、mobile_scanner、prefix 路由、checksum）雖然獨立，但共同服務於「ISBN 書目辨認增強」這個統一目標，且共用 `book_info` domain 的查詢架構，因此合併為單一提案。

確認 `feat/1.1.0-W2-001-qr-scan-restore` 分支已實作 `mobile_scanner` ^7.0.1 + `Isbn` Value Object（含完整 ISBN-10/13 checksum），本提案的 checksum 和 mobile_scanner 項目改為「整合既有實作」而非「新建」。

### 2026-06-18（W3 ANA 驗證結果回報）

三個前置驗證 ANA ticket 全部完成，結果改變提案策略：

1. **W3-001**：國圖 6 個 API 端點全部不可用（HTTP 500）。NBINet 聯合目錄（HTML scraping）為替代方案，3/3 台灣 ISBN 命中。→ 「國圖 API client」改為「NBINet scraping client」
2. **W3-002**：Open Library 對繁中書覆蓋率僅 10%（20 本樣本），命中書目標題為羅馬拼音非中文。→ Open Library 僅作為英文/國際書籍 fallback，繁中書改用 NBINet
3. **W3-003**：mobile_scanner ^7.0.1 與 Dart 3.10.9 / Flutter 3.38.10 完全相容。→ 確認可直接使用

修訂後的多來源查詢策略：
- 台灣出版品（978-957/986/626）→ NBINet scraping -> Google Books
- 英文/國際書籍 → Google Books -> Open Library
- Open Library 不適合繁中書，僅保留作為非中文書的 fallback

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | spec/scanner/isbn-barcode-scanning.md (SPEC-004 充實) | 2026-06-18 | pending |
| 規格 | spec/scanner/isbn-multi-source-query.md (SPEC-010 新增) | 2026-06-18 | pending |
| 用例 | usecases/UC-03-isbn-barcode-scanning.md (更新) | 2026-06-18 | pending |
