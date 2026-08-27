---
id: UC-10
title: "多書城偵測與切換"
status: draft
source_proposal: null
created: "2026-07-14"
updated: "2026-07-16"
version: "1.1"

primary_actor: "使用者"
secondary_actors: ["系統（PlatformRegistry）"]

platform: chrome-extension
extension_status: planned

related_specs: [SPEC-STORAGE-ISOLATION]
related_usecases: [UC-01, UC-02, UC-09]
ticket_refs: [1.6.0-W2-004, 1.6.0-W3-003, 1.6.0-W3-006]
---

> 本 UC 描述 Extension 如何自動偵測使用者所在的書城網站、載入對應的 adapter、以及在多書城間切換時的 UX 行為。v1.5.0+ 新增，是多書城架構的入口流程。

## UC-10: 多書城偵測與切換

### 基本資訊

- **用例 ID**: UC-10
- **用例名稱**: 多書城偵測與切換
- **主要行為者**: 使用者（瀏覽書城網站）+ 系統（自動偵測與切換）
- **利益關係人**: 使用者（在多個書城間無縫使用 Extension）
- **前置條件**:
  - Extension 已安裝且已授予目標書城的 host 權限（manifest `host_permissions`）
  - 使用者已在目標書城登入
- **成功保證**: Extension 自動偵測當前書城並載入正確的 adapter，無需使用者手動選擇

### 主要成功場景

#### 10A. 書城自動偵測

1. **URL 偵測**
   - 使用者導航到支援的書城頁面（如 `read.readmoo.com`、`www.kobo.com`）
   - Content Script 啟動，呼叫 `PlatformRegistry.detect(currentUrl)`
   - PlatformRegistry 比對 hostname 找到對應的 PlatformConfig

2. **Adapter 載入**
   - 系統依 PlatformConfig 的 `adapterFactory` 建立書城專屬 adapter 實例
   - Adapter 初始化完成，準備接收提取指令

3. **Popup 書城識別**
   - 使用者點擊 Extension 圖示開啟 Popup
   - Popup 顯示當前偵測到的書城名稱和圖示（如「Kobo 書庫」）
   - 「提取書籍資料」按鈕可用

#### 10B. 首次造訪新書城

1. **新書城偵測**
   - 使用者首次造訪新支援的書城（如已有 Readmoo 資料，首次訪問 Kobo）
   - PlatformRegistry 偵測到新書城，系統檢查 `{platformId}_books` key 不存在

2. **引導提示**
   - Popup 顯示引導訊息「已偵測到 Kobo 書庫，點擊提取開始蒐集書籍資料」
   - 使用者點擊提取，系統自動建立 `kobo_books` storage key 並寫入提取結果

3. **Storage 初始化**
   - 首次提取成功後，`kobo_books` key 與 `readmoo_books` key 並存於 `chrome.storage.local`
   - 兩個書城的資料完全隔離

#### 10C. 書城間分頁切換

1. **多分頁場景**
   - 使用者同時開啟 Readmoo 和 Kobo 的分頁
   - 切換分頁時，Popup 自動偵測當前活動分頁的書城

2. **Popup 狀態更新**
   - 切換到 Readmoo 分頁 → Popup 顯示「Readmoo 書庫：共 X 本」
   - 切換到 Kobo 分頁 → Popup 顯示「Kobo 書庫：共 Y 本」
   - 書城識別即時反映，無需重新開啟 Popup

3. **提取歸屬正確**
   - 在 Kobo 分頁點擊「提取」→ 結果歸屬 `kobo_books`
   - 在 Readmoo 分頁點擊「提取」→ 結果歸屬 `readmoo_books`

### 替代流程

#### 10D. 不支援的書城

- **觸發**: 使用者訪問未在 PlatformRegistry 註冊的書城網站
- **系統行為**: Content Script 不啟動（`PlatformRegistry.detect()` 回傳 null），Popup 顯示「此網站暫不支援」
- **使用者操作**: 無需動作。不影響其他已支援書城的功能

#### 10E. 書城頁面但非書庫頁

- **觸發**: 使用者在支援的書城網站但不在書庫頁（如在結帳頁或首頁）
- **系統行為**: PlatformRegistry 偵測到書城，但 adapter 判斷當前頁面非書庫頁，Popup 顯示「請導航到 Kobo 書庫頁面再提取」
- **使用者操作**: 導航到書庫頁面

#### 10F. Adapter 載入失敗

- **觸發**: PlatformRegistry 偵測到書城，但 adapter 初始化失敗（如 DOM 結構已變更）
- **系統行為**: 顯示「Kobo adapter 載入失敗，可能是網站結構已更新」，記錄錯誤日誌
- **使用者操作**: 等待 Extension 更新或通知開發者
- **影響範圍**: 僅該書城的 adapter 不可用，其他書城不受影響

### 成功標準

| 標準 | 目標值 |
|------|--------|
| 書城 URL 偵測準確率 | 100%（依 PlatformRegistry hostname 比對） |
| Adapter 載入成功率 | > 95%（排除書城 DOM 變更導致的失敗） |
| Popup 書城識別切換延遲 | < 500ms |
| 不支援網站的靜默處理 | 100%（無錯誤、無 UI 干擾） |
| 書城間提取歸屬正確率 | 100%（寫入正確的 `{platformId}_books` key） |

### 支援的書城清單（v1.5.0+）

| 書城 | platformId | 涵蓋地區 | 狀態 | 目標版本 |
|------|-----------|---------|------|---------|
| Readmoo | readmoo | 台灣 | implemented | v1.0.0 |
| 博客來 | books-com-tw | 台灣 | implemented | v1.5.0 |
| Kobo | kobo | 全球（台灣/日本/其他，統一帳號） | implemented | v1.6.0（台灣站）、v1.6.1（多地區路徑） |
| BookWalker 台灣站 | bookwalker | 台灣 | planned | v1.7.0 |
| BookWalker 日本站 | bookwalker_jp | 日本 | planned | v1.7.1 |
| Kindle JP | kindle_jp | 日本 | planned | v1.8.0 |
| Kindle US | kindle_us | 美國 | planned | v1.9.0 |
| Google Play Books | google_play_books | 全球 | planned | v1.10.0 |
| Audible | audible | 全球 | planned | v1.11.0 |

> **v1.6.1 發現**：Kobo 已整合為全球統一平台（www.kobo.com），台灣站（/tw/zh/）和日本站（/jp/ja/）
> 共用 domain、帳號、書庫，DOM 結構完全一致。因此不需要獨立的 `kobo_jp` platformId，
> 以單一 `kobo` adapter 涵蓋所有地區。其他書城是否亦為統一平台，待各版本實測確認。

### 邊界條件

- 使用者在非書城網站時，Extension 圖示可見但功能受限（僅顯示已蒐集的書庫總覽）
- **同一書城多地區路徑**：Kobo 等全球統一平台以單一 platformId 涵蓋所有地區路徑（`/tw/zh/`、`/jp/ja/` 等），adapter 需使用語系無關的選擇器（CSS class 而非 aria-label）
- **不同書城相同名稱的地區站點**：需實測確認帳號體系是否互通。互通者共用 platformId（如 Kobo）；不互通者拆分為獨立 platformId（如 kindle_jp vs kindle_us），資料獨立儲存

### 與其他 UC 的關係

| UC | 關係 |
|-----|------|
| UC-01（docs/use-cases.md） | UC-10 的偵測流程取代 UC-01 中「使用者在 Readmoo 書庫頁面」的硬編碼前提 |
| UC-02（docs/use-cases.md） | UC-10 的 adapter 載入是 UC-02 提取流程的前置步驟 |
| UC-09（docs/usecases/） | UC-10 偵測 + UC-09 自動化 = 多書城全自動提取路徑 |
