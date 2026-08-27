---
id: PROP-011
title: 自動導航書庫頁 + 自動滾動蒐集完整書目
status: confirmed
target_version: v1.1
created: 2026-04-20
approved: null
priority: P2
category: feature
related: [UC-09, UC-01, UC-02, PROP-005]
reference: /Users/mac-eric/project/readmoo-tracker_20260418（同類擴充功能實作借鑑來源）
evaluation_level: standard
---

# PROP-011: 自動導航書庫頁 + 自動滾動蒐集完整書目

## 動機

### 現況落差

| UC | 既有設計假設 | 實際使用者痛點 |
|----|-------------|---------------|
| UC-01 首次安裝 | 「使用者訪問 Readmoo 書庫頁面」 | 未定義「到達方式」，使用者需自行找到書庫 URL |
| UC-01 主要流程 4-5 | 「點擊按鈕 → 掃描頁面提取所有可見書籍」 | Readmoo 書庫頁是無限滾動，未滾到底的書籍不在 DOM 中，永遠抓不到 |
| UC-02 日常提取 | 同 UC-01 流程 | 使用者每次要手動滾動到底才能跑完整掃描 |

**關鍵結構問題**：目前系統假設「使用者會把 DOM 準備好再點掃描」，但沒有任何機制驗證或協助使用者準備 DOM。Readmoo 書庫 SPA 的分頁式延遲載入讓「可見書籍 ≠ 全部書籍」，這個落差從未被正式記錄。

### 借鑑來源

網友擴充功能 `/Users/mac-eric/project/readmoo-tracker_20260418`（讀墨小幫手 v1.5）針對**訂單頁分頁場景**實作了完整自動翻頁機制。其設計值得借鑑，但訂單頁的 Bootstrap pagination 與書庫頁的 infinite scroll 演算法不同，需調整。

**Tracker 關鍵設計（`content.js:128-166`）**：

```
scrapeAllPages(onProgress):
  await waitForTable()
  while not last page:
    scrapeCurrentPage()
    onProgress(current, total, collected)
    clickNextPage()
    await waitForPageChange(expected, 10s timeout)
  safetyBreak > 100 防無限迴圈
```

**值得借鑑的三個設計**：

1. **雙條件等待**（`content.js:83-113`）：等「頁碼變了」+「DOM 有內容」同時成立，再多等 80ms 讓 React commit，避免拿到殘影資料
2. **MutationObserver + timeout 雙保險**（`content.js:116-125`）：DOM ready 檢測不阻塞也不 race
3. **漸進式 UX**（`content.js:451-467`）：先顯示快取舊資料 → 再開始掃描 → 最後覆蓋，使用者零等待感

**Tracker 沒做、我們應補的**：

| 缺口 | Tracker 現況 | 影響 |
|------|-------------|------|
| 使用者中斷 | 無，只能關分頁 | Promise 鏈繼續執行，資料可能半寫入 |
| 錯誤恢復重試 | `waitForPageChange` timeout 直接 break | 網路慢或 DOM 抖動就中斷，大資料成功率低 |
| 儲存容量預警 | 無，撞 `chrome.storage.local` 5MB 上限才爆 | 書庫通常大於訂單記錄，更易撞牆 |
| 程式化導航 | 靜態 `<a href>` 需使用者手動點 | 多一步摩擦；但優點是簡單 |

## 目標

**提供一鍵式「程式化導航 → 自動滾動到底 → 蒐集完整書庫 → 可中斷與恢復」的提取流程，降低使用者摩擦並提升大書庫蒐集成功率。**

具體可衡量目標：

| 目標 | 量化指標 |
|------|---------|
| 降低使用者摩擦 | 從「當前頁非書庫時提取失敗」→「點一次按鈕完成提取」，使用者互動步驟由 3-4 降至 1 |
| 提升大書庫成功率 | > 500 本書庫掃描成功率 > 95%（有錯誤恢復） |
| 可中斷 | 使用者中斷後系統狀態一致（已蒐集資料可保留，未蒐集不卡在 pending 狀態） |
| 儲存安全 | 接近 5MB 時警告並提供匯出/切換儲存後端選項 |

## 非目標

- **不改變** DOM 選擇器與書籍 parser（沿用既有 `BookDataExtractor` / `ReadmooAdapter`）
- **不改變** 書籍資料結構（Tag-based Model 由 PROP-007 處理）
- **不做** 多書城平台適配（PROP-001 範疇）
- **不做** 跨裝置同步（PROP-002 / PROP-007 範疇）
- **不做** Overview 頁 UI 改版（僅 popup 和進度 UI 調整）

## 候選方案評估

本提案包含四個子決策，每項獨立評估。

### 子決策 A：自動導航的實作方式

#### 方案 A1：popup 程式化 `chrome.tabs.update`（MVP 推薦）

| 指標 | 評估 |
|------|------|
| 可行性 | 高（Manifest V3 標準 API） |
| 複雜度 | 低（popup 既有 `chrome.tabs.query` 只需補 `update`） |
| 使用者摩擦 | 極低（一鍵完成） |
| 實作點 | popup.js 新增跳轉按鈕 + 注入 session flag `{autoStart: true}` |
| 風險 | 需處理「使用者未登入 Readmoo」情境（導向 login 再彈回） |

**流程**：

```
使用者點 popup「一鍵提取全部書目」
  → chrome.storage.session.set({ autoStartExtraction: true })
  → chrome.tabs.update(activeTab, { url: 'https://read.readmoo.com/#/library' })
  → 到達後 content script init 讀取 flag → 自動 waitForDom → 自動 scroll → 自動 scrape
  → 完成後 clear flag + 顯示結果
```

**決策**：納入 Phase 1。

#### 方案 A2：content script 注入 `<a href>` 連結（Tracker 風格）

| 指標 | 評估 |
|------|------|
| 可行性 | 極高 |
| 複雜度 | 極低 |
| 使用者摩擦 | 中（使用者要手動點連結） |
| 實作點 | content script 在非書庫頁注入浮動提示含 `<a>` |
| 風險 | 需 MutationObserver 監聽 SPA URL 變化 |

**決策**：**不納入**。A1 已涵蓋此情境且摩擦更低。

#### 方案 A3：兩者都提供（備用）

popup 主按鈕走 A1；若使用者已在 Readmoo 站內但非書庫頁，content script 額外浮動提示。

**決策**：Phase 2 考慮，Phase 1 先驗證 A1 單一路徑。

### 子決策 B：自動滾動演算法

#### 方案 B1：scrollTo + 穩定偵測（MVP 推薦）

```
async function scrollUntilStable(onProgress):
  previousHeight = 0
  stableCount = 0
  safetyBreak = 0

  while safetyBreak < 100:
    window.scrollTo(0, document.body.scrollHeight)
    await waitForScrollSettled(2s)     // 等新內容載入
    currentHeight = document.body.scrollHeight

    if currentHeight === previousHeight:
      stableCount++
      if stableCount >= 2: break        // 連續兩次無變化 → 真到底
    else:
      stableCount = 0

    previousHeight = currentHeight
    onProgress(scrollCount, document.querySelectorAll('[data-book-id]').length)
    safetyBreak++
```

**決策**：納入 Phase 1。

#### 方案 B2：IntersectionObserver 觀察 loading sentinel

當頁面底部出現 loading spinner 時觸發載入，觀察元件消失代表載入完成。

| 指標 | 評估 |
|------|------|
| 優點 | 比 polling 精確，不浪費 CPU |
| 缺點 | 依賴 Readmoo 特定 DOM 元件存在（loading sentinel 的特徵選擇器） |
| 風險 | Readmoo 改版即壞；難以維護 |

**決策**：不納入 Phase 1，降為 Phase 3 條件性方案。

**詳細論據（2026-04-20 評估補強）**：

B1 和 B2 都吃 DOM 依賴風險，但**耦合對象不同**：

| 方案 | 耦合對象 | 改版敏感度 |
|------|---------|-----------|
| B1 | 書籍卡片選擇器（`[data-book-id]` 或同等） | 低：書籍資料本身就是提取器的必要依賴（UC-01/02 既有），不是新增耦合 |
| B2 | loading sentinel 選擇器 + spinner 生命週期 | 高：是「為了觸發載入而依賴的元件」，若 Readmoo 改成 SSR 或改變載入時機，sentinel 可能不存在 |

B1 的 DOM 依賴是**本來就要付的成本**，B2 是**新增耦合**。Phase 1 選擇不增加新耦合，若 B1 實測有效能瓶頸（CPU、延遲）再評估 B2。

**Phase 3 啟動條件**：Phase 1 實測結果呈現以下**任一**：
- 大書庫（> 500 本）蒐集時間 > 120 秒
- 滾動 polling CPU 使用率持續 > 30%
- 使用者反映頁面不回應

### 子決策 C：使用者中斷機制（AbortController）

```js
const abortController = new AbortController();

async function scrapeAllBooks({ signal }) {
  while (條件) {
    if (signal.aborted) throw new DOMException('使用者中斷', 'AbortError');
    // ...
  }
}

// popup 中斷按鈕
document.getElementById('cancelBtn').addEventListener('click', () => {
  chrome.tabs.sendMessage(tabId, { action: 'abortExtraction' });
});

// content script
chrome.runtime.onMessage.addListener((req) => {
  if (req.action === 'abortExtraction') abortController.abort();
});
```

**狀態一致性設計**：

| 中斷時機 | 已蒐集資料處理 | UI 狀態 |
|---------|--------------|--------|
| 中斷時已蒐集 N 本 | 寫入 storage + 標記為「部分蒐集」 | popup 顯示「已蒐集 N 本（未完成）」 |
| 下次開啟 | 提示「上次提取未完成，繼續？」 | 提供「從中斷點繼續」/「重新開始」選項 |

**決策**：納入 Phase 1。

### 子決策 D：錯誤恢復重試

**情境**：`waitForScrollSettled` timeout（網路慢、頁面卡住）不應直接 break，應重試 N 次。

```js
async function waitForScrollSettledWithRetry(maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await waitForScrollSettled(2000);
    } catch (e) {
      if (e.name === 'TimeoutError') {
        await delay(1000 * (i + 1));  // 漸進退避 1s, 2s, 3s
        continue;
      }
      throw e;
    }
  }
  throw new Error('滾動穩定檢測連續失敗 3 次');
}
```

**決策**：納入 Phase 1。

### 子決策 E：儲存容量預警

```js
async function checkStorageQuota() {
  const { bytesInUse } = await chrome.storage.local.getBytesInUse();
  const QUOTA_LIMIT = 5 * 1024 * 1024;  // 5MB Chrome 預設
  const WARNING_THRESHOLD = 0.8;         // 80%

  if (bytesInUse / QUOTA_LIMIT > WARNING_THRESHOLD) {
    return {
      warn: true,
      usage: bytesInUse,
      percent: Math.round(bytesInUse / QUOTA_LIMIT * 100),
      suggestion: '建議匯出備份或切換至 IndexedDB'
    };
  }
  return { warn: false };
}
```

**觸發時機**：每次 `scrapeAllBooks` 寫入前。

**UX**：

- 80%：popup 顯示 INFO 提示「儲存使用 X%」
- 90%：WARN 提示 + 建議匯出
- 95%：BLOCK 寫入並強制使用者匯出/清除

**決策**：納入 Phase 1。

## 最小可行組合（Phase 1 MVP — 已收斂）

> **收斂決策（2026-04-20）**：原 MVP 含 A1+B1+C+D+E 五項，經評估後收斂至核心兩項，進階機制推至 Phase 1.5。

**Phase 1 組合**：A1（程式化導航）+ B1（scrollTo + 穩定偵測）

| 投入 | 項目 | 估計規模 |
|------|------|---------|
| popup 改造 | 新增「一鍵提取全部書目」按鈕 + 進度顯示 | 中 |
| content script 改造 | autoStart flag 讀取 + scrollUntilStable 核心演算法 | 中 |
| 測試 | E2E scroll 蒐集（正常路徑） | 中 |

**Phase 1 預期時程**：1 個 Wave（估 3-4 個 Ticket）

**Phase 1.5 組合**：C（中斷）+ D（重試）+ E（容量預警）

| 投入 | 項目 | 估計規模 |
|------|------|---------|
| 中斷機制 | AbortController + popup 中斷按鈕 + 狀態持久化 | 中 |
| 錯誤恢復 | waitForScrollSettled 重試層 + 漸進退避 | 小 |
| 儲存層 | 動態 quota 讀取 + UX 分級提示 | 小 |
| 測試 | 中斷、重試、quota 場景 E2E | 中 |

**Phase 1.5 預期時程**：1 個 Wave（估 3-4 個 Ticket）

**收斂理由**：
- 先驗證核心自動化路徑實際效益（使用者反饋、大書庫成功率實測）
- 進階機制投入雖不大，但與核心有耦合風險；分階段讓 Phase 1 交付更快、問題更聚焦
- Phase 1.5 與 Phase 1 同屬 v1.1，不延後到下一版本

## 路線圖

| Phase | 範圍 | 優先級 | 目標版本 |
|-------|------|-------|---------|
| Phase 1 | A1 + B1（核心自動化 MVP） | P2 | v1.1 |
| Phase 1.5 | C + D + E（中斷 / 重試 / quota 強化） | P2 | v1.1 |
| Phase 2 | A3（content script 浮動提示備援） | P3 | v1.2+ |
| Phase 3 | B2（IntersectionObserver 精確化 — 條件性） | P3 | v2.0+ |
| Phase 4 | 從中斷點續蒐集的智慧合併 | P3 | v2.0+ |

> **版本決策**：target_version 設為 v1.1（用戶 2026-04-20 指定，內測版 v1.0 後第一個功能增強版）。流程對應新開獨立用例 UC-09（「全自動化書庫提取」），不擴充 UC-01/02；UC-01/02 維持原手動流程語意。

## 實作細節補強（2026-04-20 評估回合）

本節針對評估回合發現的兩個技術盲點補齊細節，作為拆 Ticket 時的前置依據。

### T1：SPA content script 注入時機 + autoStart flag 傳遞機制

Readmoo 是 SPA，`chrome.tabs.update({ url })` 跳轉到同 origin 新路徑時，content script 可能不會重新注入（依 manifest `run_at` 和 host_permissions 命中邏輯而定）。autoStart flag 的傳遞需防禦三種情境：

| 情境 | 描述 | 處理 |
|------|------|------|
| 情境 1：跨 origin 跳轉 | 從非 Readmoo 站跳至 `readmoo.com` | content script 會重新注入，init 時讀 `chrome.storage.session` 即可 |
| 情境 2：同 SPA 內路徑變化 | 使用者已在 readmoo 其他頁，跳轉至 library | content script 不重跑，需 MutationObserver 監聽 `location.href` 變化 + 讀 flag |
| 情境 3：跳轉前 content script 已 init | Popup 點按鈕時 content script 已存在 | Popup 透過 `chrome.tabs.sendMessage` 主動通知，不只依賴 flag |

**設計決策**：採用**雙通道**（flag + message），互為備援：

```
Popup 按鈕點擊:
  chrome.storage.session.set({ autoStartExtraction: true })  ← 通道 1：flag
  chrome.tabs.update(tabId, { url: libraryUrl })
  chrome.tabs.onUpdated listener:
    if (info.status === 'complete' && tab.url matches library):
      chrome.tabs.sendMessage(tabId, { action: 'startAutoExtraction' })  ← 通道 2：message

Content script:
  讀 flag → 若 true 則 waitForDom + startScrape + clear flag
  收到 message → 若尚未在 scraping 則 waitForDom + startScrape + clear flag
  MutationObserver 監聽 location.href 變化 → 變化後重讀 flag
```

**風險**：`chrome.storage.session` 在 service worker idle 時可能被清除（Manifest V3 行為）。補救：flag 寫入時加 timestamp，content script 讀取時驗證 timestamp < 60 秒前才接受。

### T2：manifest 權限變更聲明

本提案實作需變更 `manifest.json`，明示如下：

| 權限類型 | 目前狀態 | 本提案需求 | 說明 |
|---------|---------|-----------|------|
| `permissions: activeTab` | 需核對 | 必要 | `chrome.tabs.update` 基本權限 |
| `permissions: storage` | 需核對 | 必要 | `chrome.storage.session` + `local` |
| `permissions: tabs` | 不確定 | **可能新增** | 若需監聽 `chrome.tabs.onUpdated` 的所有 tab（而非僅 activeTab），需此權限。先用 `activeTab` 嘗試，不夠再升級 |
| `host_permissions: https://readmoo.com/*` | 需核對 | 必要 | content script 注入、`tabs.update` URL 目標 |
| `web_accessible_resources` | 需核對 | 視情況 | 若 content script 需動態載入 CSS/資源 |

**拆 Ticket 時前置任務**：先 `cat src/manifest.json` 確認當前權限狀態，再決定需要新增哪些項目。若需新增，視為 MVP 的一部分（ANA-A 審查）。

## 驗證標準

### 功能驗證

1. **自動導航**：在非 Readmoo 頁按 popup 按鈕 → 自動跳轉書庫頁 → 自動開始掃描
2. **自動滾動**：500 本書庫可蒐集到全部，不遺漏
3. **中斷一致性**：掃描中按中斷 → 已蒐集資料正確保存 → 重開顯示「上次未完成」提示
4. **錯誤恢復**：模擬網路延遲 3 秒，重試機制讓掃描仍成功完成
5. **容量預警**：storage 用量達 80% 時顯示提示；達 95% 時阻擋寫入

### 認知負擔評估

- popup UI 新增控制項 <= 3 個（一鍵按鈕、中斷按鈕、進度顯示）
- 使用者決策點 <= 2 個（中斷選擇 / quota 處理選擇）
- 既有 UC-01、UC-02 流程不被改變（只新增 autoStart 路徑）

### 回歸防護

- 既有手動提取流程保留（向後相容）
- autoStart flag 未設定時 content script 行為不變

## 風險與應變

| 風險 | 前兆 | 應變 |
|------|------|------|
| Readmoo 書庫 DOM 結構變更 | E2E 測試失敗；選擇器抓不到 | 集中管理選擇器於 ReadmooAdapter，並記錄 fallback 層 |
| 無限滾動 DOM 節點過多拖垮瀏覽器 | 500+ 本時滾動延遲 > 10s | 加入 virtual scroll 偵測，必要時改分批蒐集 |
| chrome.storage.session 在 SW 不活躍時遺失 | autoStart flag 抓不到 | 改用 chrome.storage.local 並加時間戳過期 |
| AbortController 未正確清理 | 中斷後仍有背景 timer 執行 | 測試覆蓋中斷後 tab 切換、tab 關閉情境 |
| 使用者導航中網路中斷 | 頁面載不出來 | chrome.tabs.onUpdated 監聽 errored status 並提示重試 |

## 與既有 UC 和 PROP 的關係

### UC-01 / UC-02 規格對齊

本提案**填補** UC-01 和 UC-02 未明確規範的兩個環節：

| 環節 | 既有規格 | 本提案新增 |
|------|---------|-----------|
| 到達書庫頁 | 假設「使用者訪問」 | 提供 popup 一鍵導航 |
| 完整蒐集 | 提到「掃描頁面所有可見書籍」 | 定義「可見」為滾動到底後的全部 |

**決策點**：這是 UC-01/UC-02 的擴充，還是獨立 UC-09「自動化完整提取」？建議作為**擴充**，避免 UC 碎片化；但補強 UC 的**替代流程**章節明示自動化路徑。

### 與其他 PROP 的關係

| PROP | 關係 |
|------|------|
| PROP-005（外部依賴邊界防護） | 本提案新增對 DOM 結構的依賴，需納入 PROP-005 的邊界防護測試 |
| PROP-007（Tag-based Model） | 不衝突；蒐集完的書籍資料仍走 Tag-based Model |
| PROP-001（多平台） | 不衝突；本提案針對 Readmoo 單站，抽象機制未來可擴展 |

## 後續 Ticket 建議（提案 confirm 後拆分）

### Phase 1（v1.1 MVP）

1. **ANA-A**（前置）：Readmoo 書庫頁 DOM 結構實地勘查
   - 確認 infinite scroll 觸發機制（scrollHeight 成長型 / IntersectionObserver 觸發型 / 其他）
   - 書籍卡片選擇器穩定性（`[data-book-id]` 或同等）
   - 登入頁重導行為（UC-09 9C 對應）
   - **核對 `manifest.json` 當前權限**，產出 T2 表格的實際狀態
2. **IMP-A**：popup 一鍵導航 + autoStart flag 雙通道（flag + message，含 T1 設計）
3. **IMP-B**：scrollUntilStable 核心演算法（連續 2 次穩定 + safetyBreak 100）
4. **IMP-F1**：Phase 1 E2E 測試（正常路徑，Puppeteer 模擬 50/500 本書庫）

### Phase 1.5（v1.1 增強，Phase 1 交付後再開）

5. **IMP-C**：AbortController 中斷機制 + partial status 持久化
6. **IMP-D**：錯誤恢復重試層（漸進退避 1s/2s/3s，max 3 次）
7. **IMP-E**：儲存容量預警（動態讀 quota + 80%/90%/95% 分級）
8. **IMP-F2**：Phase 1.5 E2E 測試（中斷、重試、quota 場景）

### 跨 Phase

9. **DOC-A**：UC-09 完稿 + UC-01/02 交叉引用指向 UC-09 自動化對應流程

**依賴關係**：ANA-A 先行 → IMP-A 和 IMP-B 並行（同屬 Phase 1 MVP） → IMP-F1 → [Phase 1 交付與觀察] → IMP-C / IMP-D / IMP-E 並行 → IMP-F2 → DOC-A。

## 參考

- `/Users/mac-eric/project/readmoo-tracker_20260418/content.js` — 核心借鑑來源（訂單頁分頁自動化）
- `docs/use-cases.md` UC-01 / UC-02 — 既有書庫提取用例
- `docs/chrome-extension-dev-guide.md` — Chrome Extension 限制與最佳實踐
- `.claude/references/chrome-extension-quickref.md` — 事件監聽器頂層註冊、Storage API 等關鍵限制
- MDN `chrome.tabs.update`、`AbortController`、`MutationObserver`、`IntersectionObserver`

## 替代方案

本提案的四個子決策均已在「候選方案評估」章節進行多方案比較，此處整合各決策的選擇依據摘要。

### 子決策 A：自動導航實作方式

- **已採用（A1）**：popup 程式化 `chrome.tabs.update`。Manifest V3 標準 API，摩擦最低，一鍵完成導航。
- **未採用（A2）**：content script 注入 `<a href>` 連結（Tracker 風格）。摩擦高一層，使用者需手動點連結；A1 已涵蓋此情境。
- **未採用（A3）**：A1 + A2 雙路徑並存。Phase 1 先驗證單一路徑，避免複雜度過高。

### 子決策 B：自動滾動演算法

- **已採用（B1）**：scrollTo + scrollHeight 穩定偵測。耦合對象是書籍卡片選擇器，為 UC-01/02 本來就要付的成本，無新增耦合。
- **未採用（B2）**：IntersectionObserver 觀察 loading sentinel。依賴 Readmoo 特定 DOM 元件（sentinel 選擇器），Readmoo 改版即失效，新增脆弱耦合；Phase 3 條件性評估。

### 選擇依據

Phase 1 MVP 優先降低新增耦合風險，A1 + B1 組合以最小代碼面覆蓋核心使用者需求（一鍵完整提取）。進階機制（C 中斷 / D 重試 / E 容量預警）在 Phase 1.5 補入，讓 Phase 1 交付更快且問題更聚焦。

---

## 失敗防護

本提案主要失敗情境及防護設計：

### 失敗情境 1：autoStart flag 在 Service Worker idle 時遺失

**前兆**：使用者點按鈕後跳轉書庫頁，但自動掃描未啟動。

**防護**：flag 寫入時附 timestamp；content script 讀取時驗證 timestamp < 60 秒前才接受。若 flag 失效，通道 2（`chrome.tabs.sendMessage`）作為備援，雙通道設計互為保險（詳見實作細節 T1）。

### 失敗情境 2：Readmoo 書庫 DOM 結構變更致選擇器失效

**前兆**：E2E 測試失敗；書籍數量計數為 0。

**防護**：集中管理選擇器於 `ReadmooAdapter`，新增 fallback 層（多候選選擇器依序嘗試）；ANA-A 前置勘查確認選擇器穩定性後再實作，降低初期誤判。

### 失敗情境 3：無限滾動安全閥失效致無限迴圈

**前兆**：滾動操作持續進行，`safetyBreak` 計數器未正確遞增。

**防護**：`scrollUntilStable` 內建 `safetyBreak < 100` 硬上限（借鑑 readmoo-tracker 設計）；連續兩次 `scrollHeight` 無變化即視為到底並中止，雙條件保護避免誤判。

### 失敗情境 4：新增 manifest 權限被 Chrome Web Store 審核拒絕

**前兆**：`permissions: tabs` 新增時審核週期延長或被標記。

**防護**：T2 明確列出所需權限清單，ANA-A 前置任務驗證現有 `activeTab` 是否足夠；若不夠再升級至 `tabs`，並在 Store 說明頁補充用途說明。

---

## Reality Test

### 假設驗證

**假設 1：`chrome.storage.session` 可作為 popup → content script 的可靠 flag 傳遞通道。**

尚待驗證（ANA-A 前置任務）。風險點：Manifest V3 Service Worker idle 清除行為可能在低活躍裝置上早於 60 秒觸發。防護設計（timestamp 驗證 + 雙通道備援）已納入 T1，實測若仍失效則改用 `chrome.storage.local` + 時間戳。

**假設 2：`scrollTo(0, scrollHeight)` + 2 秒等待足以觸發 Readmoo 書庫的無限滾動載入。**

尚待驗證（ANA-A 前置實地勘查）。Readmoo 書庫採用 SPA 延遲載入，若等待時間不足會造成大書庫蒐集不完整。B1 演算法的「連續 2 次穩定 = 到底」判斷依賴此假設成立；ANA-A 需以 50 本、200 本、500 本三個規模各實測一次。

**假設 3：Phase 1 MVP（A1 + B1）能涵蓋 > 95% 使用者的核心需求，無需在 Phase 1 同時交付 C/D/E。**

觸發條件（Phase 1 觀察後重評）：若 Phase 1 上線後使用者反映大書庫（> 200 本）蒐集成功率 < 90%，或中斷後資料狀態不一致問題超過 5 個回報，則 Phase 1.5 優先級升至與 Phase 1 並行處理，不等版本結束。

### 觸發案例

本提案觸發點：現有 UC-01/02 假設「使用者已在書庫頁且 DOM 已備妥」，但 Readmoo 書庫為無限滾動 SPA，「可見書籍 ≠ 全部書籍」的落差從未被正式記錄。借鑑 readmoo-tracker v1.5 分頁自動翻頁設計，驗證同類自動化機制可移植至無限滾動場景，並補強缺口（中斷機制、錯誤恢復、容量預警）。

---

**Last Updated**: 2026-04-20
**Change Log**:
- v1.0 (2026-04-20): 初稿，基於借鑑 readmoo-tracker v1.5 實作分析 + 使用者需求討論產出
- v1.1 (2026-04-20): 評估回合調整
  - K1: 新開 UC-09 獨立用例（取代原「UC-01/02 擴充」策略）
  - K2: MVP 收斂至 A1+B1，C/D/E 推至 Phase 1.5
  - K3: B2 不納入論據補強 + Phase 3 啟動條件具體化
  - T1: SPA content script 注入時機 + 雙通道 flag/message 設計補齊
  - T2: manifest 權限變更聲明納入 ANA-A 前置任務
