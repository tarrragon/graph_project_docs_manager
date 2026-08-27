---
id: UC-09
title: "全自動化書庫提取"
status: draft
source_proposal: PROP-011
created: "2026-04-20"
updated: "2026-04-20"
version: "1.0"

primary_actor: "使用者"
secondary_actors: ["系統（自動化）"]

platform: chrome-extension
extension_status: planned

related_specs: []
related_usecases: [UC-01, UC-02]
ticket_refs: []
---

> 本 UC 是 UC-01（首次安裝與設定）/ UC-02（日常書籍資料提取）的**自動化對應流程**。差異：UC-01/02 假設使用者已在書庫頁且手動觸發單次提取；本 UC 提供「一鍵完成從任意頁面到完整書目蒐集」的全自動化路徑。

## UC-09: 全自動化書庫提取

### 基本資訊

- **用例 ID**: UC-09
- **用例名稱**: 全自動化書庫提取（一鍵導航 + 自動滾動 + 完整蒐集）
- **主要行為者**: 使用者（觸發）+ 系統（執行）
- **利益關係人**: 使用者（零摩擦獲得完整書庫資料）
- **前置條件**:
  - Extension 已安裝且已授予 Readmoo host 權限
  - 使用者有 Readmoo 帳號並已在 Readmoo 站內登入（或可導向登入）
- **成功保證**: 使用者完成單次點擊，系統在合理時間內蒐集到完整書庫書目

### 主要成功場景（Phase 1 MVP）

#### 9A. 一鍵導航

1. **起點判定**
   - 使用者在任意頁面（Readmoo 站內或站外）點擊 Extension 圖示開啟 Popup
   - Popup 顯示「一鍵提取全部書目」按鈕
   - Popup 偵測當前 tab URL 判斷是否已在書庫頁

2. **程式化跳轉**
   - 使用者點擊按鈕
   - 系統透過 `chrome.tabs.update` 將當前 tab 導向 Readmoo 書庫頁 URL
   - 系統於 `chrome.storage.session` 寫入 `autoStartExtraction: true` 旗標
   - Popup 顯示「正在導航至書庫頁...」

3. **頁面載入與旗標傳遞**
   - Tab 跳轉完成，content script 被注入或 SPA URL 變化被 MutationObserver 偵測
   - content script 讀取 `autoStartExtraction` 旗標
   - 旗標存在 → 自動進入 9B 流程；否則維持被動（UC-01/02 既有行為）

#### 9B. 自動滾動蒐集

1. **DOM Ready 等待**
   - 系統透過 MutationObserver + timeout 雙保險確認書庫書籍容器已出現
   - 確認後顯示進度面板「已蒐集 0 本」

2. **滾動演算法**
   - 系統執行 `window.scrollTo(0, document.body.scrollHeight)`
   - 等待新內容載入（`waitForScrollSettled`）
   - 比對 `scrollHeight` 是否變化
     - 有變化：繼續下一輪滾動，重置穩定計數
     - 無變化：穩定計數 +1
   - 連續 2 次 `scrollHeight` 無變化 → 判定已到底
   - `safetyBreak > 100` 輪時強制終止（防無限迴圈）

3. **資料擷取與去重**
   - 每輪滾動後系統掃描 DOM 擷取書籍
   - 以 `bookId` 為 key 維護 `Set` 結構去重
   - 進度面板更新「已蒐集 N 本」

4. **完成寫入**
   - 系統將書目寫入 `chrome.storage.local`
   - 清除 `autoStartExtraction` 旗標
   - Popup / 面板顯示「提取完成，共 N 本」
   - 提供「查看詳細資料」跳轉至 Overview 頁

### 替代流程

#### 9C. 使用者未登入 Readmoo（例外）

- **條件**: `chrome.tabs.update` 跳轉後被重導向至 Readmoo 登入頁
- **處理**:
  1. content script 偵測到當前 URL 為 login 而非 library
  2. 保留 `autoStartExtraction` 旗標不清除
  3. Popup 顯示「請先登入 Readmoo，登入後會自動繼續」
  4. 登入完成 Readmoo 導回書庫頁 → 旗標仍在 → 自動進入 9B

#### 9D. 使用者中斷（Phase 1.5）

- **條件**: 使用者於掃描中點擊「中斷」按鈕
- **處理**:
  1. Popup 發送 `abortExtraction` 訊息至 content script
  2. content script 觸發 `AbortController.abort()` 停止滾動迴圈
  3. 已蒐集 N 本寫入 storage 並標記 `status: 'partial'`
  4. 下次 Popup 開啟顯示「上次提取未完成（已蒐集 N 本），繼續 / 重新開始？」

#### 9E. 網路延遲或 DOM 抖動（Phase 1.5）

- **條件**: `waitForScrollSettled` timeout
- **處理**:
  1. 漸進退避重試（1s / 2s / 3s）最多 3 次
  2. 3 次仍失敗 → 標記 `status: 'partial'` + 記錄失敗原因
  3. 通知使用者「蒐集中斷，已蒐集 N 本，建議稍後重試」

#### 9F. 儲存容量接近上限（Phase 1.5）

- **條件**: `chrome.storage.local.getBytesInUse()` 接近配額上限
- **處理**:
  - 使用率 80%：Popup 顯示 INFO「儲存使用 X%」
  - 使用率 90%：WARN + 建議立即匯出備份
  - 使用率 95%：BLOCK 寫入，強制使用者匯出或清除後才繼續

### 失敗結束條件

- Readmoo 書庫 DOM 結構大幅變更，選擇器完全無法匹配 → 失敗並回報「需要更新 Extension」
- 使用者拒絕授予 tab 權限 → 回退到 UC-01/02 手動流程
- `safetyBreak` 觸發（超過 100 輪滾動）→ 寫入已蒐集資料 + 警示「疑似無限滾動異常」

### 成功標準

| 指標 | 標準 |
|------|------|
| 使用者互動步驟 | 1 次點擊即完成（起點 = 任意頁面） |
| 書庫完整蒐集 | 500 本書庫蒐集成功率 > 95% |
| 端到端時間 | 500 本書庫 < 120 秒（視網路） |
| 中斷狀態一致性 | 中斷後已蒐集資料 100% 保留 |
| 儲存安全 | 使用率 > 95% 時 100% 阻擋寫入 |

### 實作需求（Phase 分期）

| Phase | 範圍 | 對應方案 |
|-------|------|---------|
| Phase 1 (v1.1 MVP) | 9A + 9B 核心流程 + 9C 登入導回 | PROP-011 方案 A1 + B1 |
| Phase 1.5 (v1.1 增強) | 9D 中斷 + 9E 重試 + 9F quota | PROP-011 方案 C + D + E |
| Phase 2+ (v2.0+) | 多書城平台自動化擴展 | 依 PROP-001 |

### 相關文件

- **提案**: PROP-011（自動導航書庫頁 + 自動滾動蒐集完整書目）
- **借鑑來源**: `/Users/mac-eric/project/readmoo-tracker_20260418/content.js`
- **互補 UC**: UC-01（首次安裝手動流程）、UC-02（日常提取手動流程）
- **下游 UC**: UC-03（匯出）、UC-06（書籍資料檢視）

---

**Last Updated**: 2026-04-20
**Change Log**:
- v1.0 (2026-04-20): 初稿，依 PROP-011 + 用戶決策「新開獨立 UC」建立
