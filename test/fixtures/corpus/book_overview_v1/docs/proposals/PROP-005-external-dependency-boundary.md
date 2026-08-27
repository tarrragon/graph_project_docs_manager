---
id: PROP-005
title: "外部依賴邊界防護驗證"
status: confirmed
source: "development"
proposed_by: "UC 測試驗證延伸"
proposed_date: "2026-03-30"
confirmed_date: null
target_version: "v0.16.2"
priority: P1

outputs:
  spec_refs: []
  usecase_refs: [UC-01, UC-02, UC-05, UC-08]
  ticket_refs:
    - "0.16.2-W2-002"

related_proposals: [PROP-004]
supersedes: null
evaluation_level: standard
---

# PROP-005: 外部依賴邊界防護驗證

## 需求來源

UC 測試驗證過程中發現：有些關鍵步驟依賴外部系統（Readmoo DOM、Chrome API、使用者環境），這些是我們無法控制且隨時可能變動的部分。不需要完美容錯，但必須在邊界點設定 exception 處理並拋出明確錯誤。

## 問題描述

> **核心原則**：不要求內部程式完美應對各種外部狀況，但外部依賴邊界必須有明確的 exception 處理和錯誤拋出。當外部改變時，我們能正確偵測並報錯，而非靜默失敗。

## 範圍界定

### 本提案要做的（In Scope）

- 盤點所有外部依賴邊界點
- 驗證每個邊界點是否有 exception 處理
- 確認整合測試覆蓋外部依賴變動場景
- 為缺失的邊界防護建立修復 ticket

### 本提案不做的（Out of Scope）

- 增加內部程式的容錯複雜度 → 不需要
- 處理所有可能的外部異常 → 只需偵測並報錯

## 外部依賴邊界盤點

### 類別 1: Readmoo 書城 DOM 結構

**風險**：Readmoo 改版會導致 DOM 選擇器失效

| 邊界點 | 檔案 | 防護狀態 |
|--------|------|---------|
| DOM 書籍元素查詢 | readmoo-adapter.js | [x] try/catch + 日誌 |
| 書籍 ID 提取 | readmoo-adapter.js:extractBookIdFromPrivacy | [x] try/catch + fallback |
| 書籍資料解析 | readmoo-adapter.js:parseBookElement | [x] try/catch + 日誌 |
| 批次提取錯誤 | readmoo-adapter.js:extractBooks | [x] per-element try/catch + stats |
| URL 驗證 | readmoo-adapter.js:validatePage | [x] try/catch |
| 進度條提取 | readmoo-adapter.js:extractProgressFromContainer | [x] try/catch + fallback |
| 通用容錯方法 | readmoo-adapter.js:handleWithFallback | [x] try/catch + logError |
| DOM 工具 | dom-utils.js | 待確認 |

**整合測試覆蓋**：
- [x] content-script-extractor.test.js — Content Script 提取整合
- [x] uc01-complete-extraction-workflow — 完整提取流程
- [ ] DOM 結構變更偵測測試（模擬 Readmoo 改版）

### 類別 2: Chrome Extension API

**風險**：Chrome API 行為變更、權限問題

| 邊界點 | 檔案 | 防護狀態 |
|--------|------|---------|
| chrome.storage.local | chrome-storage-adapter.js | [x] 23 處 try/catch（完善） |
| chrome.runtime.sendMessage | chrome-event-bridge.js | [x] 9 處 try/catch |
| chrome.tabs API | tab-state-tracking-service.js | 待確認 |
| chrome.permissions | permission-management-service.js | 待確認 |
| Manifest V3 合規 | background.js | [x] 已測試 |

**整合測試覆蓋**：
- [x] storage-api-integration.test.js — Storage API 整合
- [x] runtime-messaging-integration.test.js — Runtime 訊息整合
- [x] content-script-injection.test.js — Content Script 注入
- [x] manifest.test.js — Manifest 驗證
- [x] chrome-store-readiness.test.js — 上架合規

### 類別 3: 使用者環境

**風險**：記憶體不足、效能問題、網路不穩

| 邊界點 | 檔案 | 防護狀態 |
|--------|------|---------|
| 記憶體監控 | MetricsCollector.js, memory-utils.js | [x] 效能監控 |
| 大量資料處理 | readmoo-adapter.js:extractBooks | [x] 批次處理 + stats |
| 網路狀態 | connection-monitoring-service.js | [x] 連線監控 |
| Chrome Storage 配額 | chrome-storage-adapter.js | [x] 配額管理 |

**整合測試覆蓋**：
- [x] benchmark-tests.test.js — 效能基準
- [x] baseline-performance.test.js — 效能基線
- [x] performance-monitoring-integration.test.js — 效能監控整合

## 分析結論

### 現有防護評估

| 類別 | 防護完善度 | 整合測試覆蓋 | 評估 |
|------|-----------|-------------|------|
| Readmoo DOM | 高（每個操作都有 try/catch） | 良好（缺 DOM 變更偵測） | 差距小 |
| Chrome API | 高（storage 尤其完善） | 優秀 | 無明顯差距 |
| 使用者環境 | 中（有監控但缺主動防護） | 良好 | 差距小 |

### 關鍵差距

| 差距 | 嚴重程度 | 說明 |
|------|---------|------|
| DOM 結構變更偵測 | 中 | 缺少模擬 Readmoo 改版的整合測試（驗證選擇器失效時能正確報錯） |
| chrome.tabs/permissions 邊界防護 | 低 | 這些 service 有大量程式碼但未深入檢查 try/catch 覆蓋度 |

### 結論

**外部依賴邊界防護整體良好**。readmoo-adapter.js 有 13+ 處 try/catch 和通用 handleWithFallback 方法，chrome-storage-adapter.js 有 23 處防護。

主要的改善方向是：
1. 新增「DOM 結構變更偵測」整合測試 — 模擬選擇器失效時，系統能正確報錯
2. 這可以與 W2-002（UC-02 匯出鏈測試）或 W2-001（UC-01 測試）一起處理

## 驗收條件

- [x] 外部依賴邊界點盤點完成
- [x] 各邊界點 exception 處理狀態確認
- [x] 整合測試覆蓋評估
- [ ] DOM 結構變更偵測測試建立（可併入 W2 Ticket）

---

## 替代方案

本提案採用「邊界盤點 + 現有防護評估」方式。評估期間考慮過以下候選方案：

### 方案 A（已採用）：靜態程式碼掃描 + 邊界清單人工評估

逐一掃描各外部依賴入口（DOM 查詢、Chrome API 呼叫、環境監測），確認是否有 try/catch 包覆，建立盤點表並標記防護狀態。

優點：可全面覆蓋現有程式碼邊界；能正確識別「防護存在但不完整」的情況（如 dom-utils.js 待確認）。缺點：需要深入閱讀各 adapter 程式碼，耗費人工時間；靜態分析無法反映執行期行為。

### 方案 B（未採用）：執行期錯誤注入測試

透過 mock 強制模擬外部失敗（如 DOM 返回 null、chrome.storage 拋出異常），執行整合測試驗證錯誤是否正確冒泡。

優點：能以實際執行行為驗證防護有效性，可信度更高。缺點：需要為每個邊界點設計注入場景，建置成本高；方案 A 的靜態掃描已可識別出最高風險差距（DOM 結構變更偵測）。

### 選擇依據

本提案目的在快速盤點現有防護狀態，識別關鍵差距並建立修復 ticket。方案 A 的靜態評估成本更低，且已足以識別出優先應修復的差距（DOM 結構變更偵測測試缺失），後續可透過 W2-001/W2-002 系列 ticket 以方案 B 的錯誤注入測試補強驗證。

---

## 失敗防護

本分析的主要失敗模式及已採取的防護：

### 失敗情境 1：「待確認」邊界點（dom-utils.js、chrome.tabs、chrome.permissions）實際缺乏防護

防護：盤點表已明確標記這三個邊界點為「待確認」，而非樂觀估計為「已防護」。差距清單已識別 chrome.tabs/permissions 為低嚴重程度差距，後續 W2 系列 ticket 可優先確認，不依賴本提案的靜態推斷。

### 失敗情境 2：外部系統（Readmoo DOM）改版導致分析結論過時

防護：本提案的分析結論聚焦於「邊界防護機制是否存在」，而非 DOM 結構本身。readmoo-adapter.js 的 handleWithFallback 通用方法提供改版時的自動偵測能力，分析結論的有效性不依賴 Readmoo 保持不改版。

---

## Reality Test

### 假設驗證

本提案建立在以下假設上，以下逐一驗證：

**假設 1：readmoo-adapter.js 的 try/catch 覆蓋足以偵測 DOM 結構變更，不會靜默失敗。**

結果：部分驗證。per-element try/catch 確保單一元素失敗不影響整批提取，但缺少「DOM 選擇器整批失效」的整合測試，無法確認此情況下錯誤訊息的可見性。此差距已識別為「DOM 結構變更偵測」缺口，列入驗收條件待補。

**假設 2：chrome-storage-adapter.js 的 23 處 try/catch 已覆蓋 Chrome Storage API 的主要失敗模式。**

結果：已驗證為真。storage-api-integration.test.js 的通過結果（含 chrome.storage.local 模擬）確認防護機制在測試環境下正常運作。

**假設 3：使用者環境（記憶體、效能、網路）的監控機制可轉換為明確報錯而非靜默降級。**

結果：部分驗證。connection-monitoring-service.js 和 MetricsCollector.js 有監控機制，但本提案未深入確認監測到異常時的錯誤拋出行為。此部分可在 W2 系列 ticket 的整合測試中進一步驗證。

### 觸發案例

本提案觸發點：UC 測試驗證過程中發現，整合測試雖已覆蓋正常流程，但缺少針對外部依賴失敗的邊界測試。本提案透過系統性盤點確認現有防護狀態，識別出「DOM 結構變更偵測」為最關鍵的未覆蓋差距，直接支撐後續 W2-001/W2-002 系列 ticket 的測試補強規格。
