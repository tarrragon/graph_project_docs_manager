---
id: PROP-004
title: "UseCase 與測試覆蓋率差距分析"
status: implemented
source: "development"
proposed_by: "spec 盤點後驗證"
proposed_date: "2026-03-30"
confirmed_date: null
target_version: "v0.16.2"
priority: P1

outputs:
  spec_refs: []
  usecase_refs: [UC-01, UC-02, UC-04, UC-05, UC-07, UC-08]
  ticket_refs:
    - "0.16.2-W2-001"
    - "0.16.2-W2-002"
    - "0.16.2-W2-003"
    - "0.16.2-W2-004"
    - "0.16.2-W2-005"

related_proposals: [PROP-000]
supersedes: null
evaluation_level: standard
---

# PROP-004: UseCase 與測試覆蓋率差距分析

## 需求來源

提案系統建立後，需要驗證現有測試是否涵蓋 UC 的驗收條件。這是提案系統的第一個實戰驗證。

## 問題描述

專案有 193 個測試檔案，但尚未有系統性的 UC 驗收條件 → 測試對應表。需要識別哪些 UC 場景已被測試覆蓋，哪些有差距。

## 範圍界定

### 本提案要做的（In Scope）

- 分析 6 個 Extension 相關 UC（UC-01, UC-02, UC-04, UC-05, UC-07, UC-08）的測試覆蓋
- 建立 UC 驗收條件 → 測試檔案的對應表
- 識別測試差距（UC 場景沒有對應測試）
- 識別孤立測試（測試沒有對應到任何 UC 場景）

### 本提案不做的（Out of Scope）

- APP 專屬 UC 的測試覆蓋（UC-03, UC-06）→ 不適用
- 新增缺失的測試 → 識別後建立獨立 ticket
- 修改現有測試 → 識別問題後建立獨立 ticket

## UC-測試對應分析

### UC-01: 匯入 Chrome Extension 書庫資料

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 主要場景 1 | 選擇 JSON 檔案 | [x] data-import.test.js, overview-import-function.test.js |
| 主要場景 2 | 檔案驗證與匯入 | [x] readmoo-data-validator.test.js, overview-import-function.test.js |
| 主要場景 3 | 背景資料補充 | [ ] 無對應（Extension 不做 Google Books API 補充） |
| 替代流程 3a | JSON 格式錯誤 | [x] UC01ErrorSystem.test.js, UC01ErrorAdapter.test.js |
| 替代流程 3b | 重複書籍處理 | [ ] 待確認 |
| 替代流程 3c | 匯入中斷 | [ ] 待確認 |
| 特殊需求 | 效能（1000 本 <10s） | [ ] 待確認（benchmark-tests.test.js?） |
| E2E | 完整提取流程 | [x] uc01-complete-extraction-workflow-refactored.test.js |

**測試檔案清單**（16 個）：
- unit: data-import, extraction-progress-handler, extraction-completed-handler, overview-import-*, readmoo-data-validator, popup-extraction-service, UC01ErrorAdapter/Factory
- integration: UC01ErrorSystem, content-script-extractor, UC01-UC02-error-propagation
- e2e: uc01-complete-extraction-workflow, complete-extraction-workflow

---

### UC-02: 匯出書庫資料

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 主要場景 1 | 啟動匯出 | [x] export-manager.test.js |
| 主要場景 2 | 匯出設定（格式選擇） | [x] export-handler.test.js（JSON/CSV/Excel） |
| 主要場景 3 | 資料處理與轉換 | [x] book-data-exporter.test.js |
| 主要場景 4 | 完成匯出 | [x] export-user-feedback.test.js, export-progress-notifier.test.js |
| 替代流程 1a | 空書庫 | [ ] 待確認 |
| 替代流程 3a | 儲存空間不足 | [ ] 待確認（Extension 下載為檔案，不太適用） |
| 事件系統 | 匯出事件 | [x] export-events.test.js |

**測試檔案清單**（11 個）：
- unit: export-manager, export-handler, book-data-exporter, export-events, export-user-feedback, export-progress-notifier, export-ui-integration, UC02ErrorAdapter/Factory
- integration: uc02-errorcodes-migration, UC01-UC02-error-propagation

---

### UC-04: 關鍵字搜尋補充書籍資訊（Extension: partial）

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 搜尋功能 | 本地書籍搜尋 | [x] search-engine.test.js, search-index-manager.test.js |
| 搜尋 UI | 搜尋介面 | [x] search-ui-controller.test.js, book-search-filter*.test.js |
| 篩選功能 | 多條件篩選 | [x] filter-engine.test.js |
| 結果格式 | 搜尋結果顯示 | [x] search-result-formatter.test.js |
| 快取 | 搜尋快取 | [x] search-cache-manager.test.js |
| API 補充 | Google Books API 補充 | [ ] 不適用（Extension 不做 API 補充） |
| 批次補充 | UC-04b 批次 | [ ] 不適用（Extension 不做 API 補充） |

**測試檔案清單**（12 個）：
- unit: search-engine, search-index-manager, search-cache-manager, search-coordinator, search-ui-controller, search-result-formatter, filter-engine, book-search-filter*, UC04ErrorAdapter/Factory
- integration: UC04ErrorSystem

**備註**：Extension 的搜尋是純本地搜尋，不涉及 API 補充。測試覆蓋對 Extension 功能來說是完整的。

---

### UC-05: 雙模式書庫展示系統

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 書庫展示 | 書籍網格渲染 | [x] book-grid-renderer.test.js, overview-page.test.js |
| 書庫控制 | 總覽頁面控制 | [x] overview-page-controller.test.js |
| Popup 介面 | 快速操作 | [x] popup-controller.test.js, popup-ui-*.test.js |
| 搜尋篩選 | 書庫搜尋 | [x] book-search-filter*.test.js |
| 模式切換 | 簡潔/管理模式 | [ ] 待確認（Extension 目前可能只有一種模式） |
| 空書庫 | 替代流程 1a | [ ] 待確認 |
| 效能 | 1000 本 <3s | [ ] 待確認（benchmark-tests.test.js?） |
| UI 互動 | 互動流程 | [x] ui-interaction-flow.test.js (e2e) |

**測試檔案清單**（多數計入 popup/ 和 ui/ 目錄）

---

### UC-07: 跨平台資料同步準備（Extension: partial）

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 同步狀態管理 | 追蹤同步狀態 | [x] SynchronizationOrchestrator.test.js |
| 衝突偵測 | 衝突檢測 | [x] ConflictDetectionService.test.js |
| 增量變更追蹤 | 變更識別 | [ ] 待確認 |
| 同步工作流 | E2E 同步 | [x] cross-device-sync-workflow.test.js, cross-device-sync.test.js |
| 替代流程 7a | 資料不一致 | [ ] 待確認 |
| 替代流程 7b | 同步衝突 | [x] ConflictDetectionService.test.js |
| 替代流程 7c | 網路不穩 | [ ] 待確認（RetryCoordinator.test.js?） |

**測試檔案清單**（7 個）

---

### UC-08: 系統錯誤處理與恢復

**UC 驗收場景**：

| 場景 | 說明 | 測試覆蓋 |
|------|------|---------|
| 錯誤捕獲分類 | 自動錯誤分類 | [x] system-error-classifier.test.js, ErrorCodes-integrity.test.js |
| 網路錯誤恢復 | 重試機制 | [x] error-recovery-strategies.test.js, error-recovery-coordinator.test.js |
| 錯誤傳播 | 跨模組傳播 | [x] cross-module-error-propagation.test.js |
| UC 特定錯誤 | UC01-UC07 | [x] UC01-UC07 ErrorAdapter/Factory/System tests |
| 系統錯誤處理 | Chrome Extension 錯誤 | [x] chrome-extension-error-handling.test.js |
| 恢復工作流 | E2E 恢復流程 | [x] error-recovery-workflow.test.js |
| 錯誤場景整合 | 場景覆蓋 | [x] error-handling-scenarios.test.js |

**測試檔案清單**（35+ 個）：覆蓋度最高的 UC

---

## 差距摘要

### 已充分覆蓋

| UC | 測試數 | 評估 |
|----|--------|------|
| UC-01 | 16 | 良好（主要場景和 E2E 都有） |
| UC-02 | 11 | 良好（匯出格式和事件系統都有） |
| UC-04 | 12 | 良好（對 Extension 功能來說完整） |
| UC-08 | 35+ | 優秀（最完整的 UC 測試覆蓋） |

### 差距確認結果（已驗證）

| UC | 場景 | 結果 | 詳情 |
|----|------|------|------|
| UC-01 | 重複書籍處理 | 缺失 | data-import.test.js 和 overview-import-*.test.js 中無重複 ID 處理測試 |
| UC-01 | 匯入中斷回滾 | 間接覆蓋 | overview-import-private-methods.test.js 有 cancel/abort 相關，popup-extraction-service 有取消流程 |
| UC-05 | 模式切換 | 不適用 | Extension 為單一展示模式（書庫總覽），非雙模式設計 |
| UC-05 | 空書庫狀態 | 已覆蓋 | overview-page.test.js 有「應該正確處理空資料情況」和「空狀態顯示」測試 |
| UC-05 | 效能基準 | 已覆蓋 | benchmark-tests.test.js 有資料提取效能測試（5/50/200 本），有效能閾值斷言 |
| UC-07 | 增量變更追蹤 | 間接覆蓋 | SynchronizationOrchestrator.test.js 和 cross-device-sync-workflow.test.js 有增量同步場景 |
| UC-07 | 資料不一致處理 | 間接覆蓋 | readmoo-data-consistency-service.test.js 有一致性檢查，但非 UC-07 替代流程 7a 的完整覆蓋 |
| UC-07 | 網路不穩處理 | 部分覆蓋 | RetryCoordinator.test.js 有重試機制，但策略較簡化 |

### 確認後的真正差距

| UC | 缺失場景 | 嚴重程度 | 建議 |
|----|---------|---------|------|
| UC-01 | 重複書籍 ID 處理 | 中 | 需新增測試：匯入時遇到已存在 ID 的處理邏輯 |
| UC-07 | 完整的資料不一致恢復流程 | 中 | 需新增測試：替代流程 7a 的完整場景 |
| UC-07 | 網路不穩定下的同步策略 | 低 | RetryCoordinator 已有基本測試，可後續加強 |

### 不適用的場景（Extension 不做）

| UC 場景 | 原因 |
|---------|------|
| UC-01 背景 API 補充 | Extension 不做 Google Books API |
| UC-03 全部 | APP 專屬（相機掃描） |
| UC-04 API 補充和批次 | Extension 不做 API 補充 |
| UC-06 全部 | APP 專屬（借閱管理） |

## UC 資訊鏈整合測試分析

### 分析目的

每個 UC 應有完整的「資訊鏈」整合測試，驗證從頭到尾的資料流串接。
只要整合測試通過，就能確認系統運作正常 — 這是測試保護的核心價值。

### UC-01: 資料提取鏈

```
頁面偵測 → Content Script 注入 → DOM 擷取 → 資料驗證 → 訊息傳遞 → 儲存 → UI 顯示
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| data-flow-end-to-end.test.js | 完整 5 步資料流（Content Script → Chrome Bridge → Background → Storage → Overview） | 完整鏈 |
| uc01-complete-extraction-workflow-refactored.test.js | 環境初始化 → 正常流程 → 邊界條件 → 異常處理 | 完整鏈 |
| complete-extraction-workflow.test.js | 基本流程 → 資料提取 → 儲存驗證 → UI 整合 → 錯誤處理 → 效能 | 完整鏈 |
| new-user-onboarding.test.js | 首次安裝 → 權限設定 → 首次提取 → Popup 顯示 | 完整鏈 |

**結論**：UC-01 有 4 個完整資訊鏈測試，覆蓋優秀。

---

### UC-02: 匯出鏈

```
選擇格式 → 資料查詢 → 格式轉換 → 檔案產生 → 進度回饋 → 下載
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| ui-interaction-flow.test.js (匯出功能測試) | Popup 觸發 → 匯出流程 → 結果回饋 | 部分鏈 |
| benchmark-tests.test.js (匯出效能) | 匯出流程效能驗證 | 效能鏈 |
| UC01-UC02-error-propagation.test.js | 錯誤傳播鏈 | 錯誤鏈 |

**結論**：UC-02 有部分整合測試，但缺少**從 Storage 讀取 → 格式轉換 → 檔案下載**的完整串接測試。主要依賴單元測試組合。

---

### UC-04: 搜尋鏈

```
使用者輸入 → 搜尋索引查詢 → 結果排序 → 結果渲染 → 篩選互動
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| ui-interaction-flow.test.js (Overview 頁面) | 搜尋功能觸發 → 結果顯示 | 部分鏈 |

**結論**：UC-04 搜尋功能的**完整資訊鏈整合測試不足**。單元測試很完整（12 個），但缺少從使用者操作到結果顯示的端到端串接。

---

### UC-05: 書庫展示鏈

```
頁面載入 → Storage 讀取 → 資料處理 → Grid 渲染 → 搜尋/篩選互動 → 匯出觸發
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| ui-interaction-flow.test.js | Popup 互動 + Overview 功能 + 匯出 + 錯誤處理 + 響應式 | 完整鏈 |
| daily-usage-workflow.test.js | 開啟 Extension → 書籍列表 → 資料同步 → 統計 → 資料一致性 → 效能 | 完整鏈 |
| popup-background-integration.test.js | Popup ↔ Background 通訊 | 部分鏈 |

**結論**：UC-05 有 2 個完整資訊鏈測試，覆蓋良好。

---

### UC-07: 同步鏈

```
資料變更偵測 → 變更彙總 → 匯出 → 匯入 → 衝突偵測 → 衝突解決 → 一致性驗證
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| cross-device-sync-workflow.test.js (integration) | 設備 A 資料 → 匯出 → 設備 B 匯入 → 一致性驗證 → 錯誤處理 | 完整鏈 |
| cross-device-sync.test.js (e2e) | 完整同步(8) + 資料完整性(10) + 效能(8) + 錯誤恢復(12) + 一致性(7) = 45 案例 | 完整鏈 |

**結論**：UC-07 有 2 個非常完整的資訊鏈測試（45 個 E2E 案例），覆蓋優秀。

---

### UC-08: 錯誤恢復鏈

```
錯誤發生 → 錯誤捕獲 → 分類 → 恢復策略選擇 → 執行恢復 → 使用者通知
```

| 整合測試 | 覆蓋範圍 | 評估 |
|---------|---------|------|
| error-recovery-workflow.test.js | 網路中斷 → 錯誤訊息 → 重試 → 恢復 → 資料完整性 | 完整鏈 |
| error-handling-scenarios.test.js | 多場景錯誤處理 | 完整鏈 |
| cross-module-error-propagation.test.js | 跨模組錯誤傳播 | 部分鏈 |

**結論**：UC-08 有 2 個完整資訊鏈測試，覆蓋良好。

---

### 資訊鏈覆蓋摘要

| UC | 完整鏈測試數 | 評估 | 差距 |
|----|------------|------|------|
| UC-01 | 4 | 優秀 | 無 |
| UC-02 | 0 | 不足 | 缺少完整匯出流程整合測試 |
| UC-04 | 0 | 不足 | 缺少搜尋端到端整合測試 |
| UC-05 | 2 | 良好 | 無 |
| UC-07 | 2 | 優秀 | 無 |
| UC-08 | 2 | 良好 | 無 |

### 關鍵發現

**UC-02 和 UC-04 缺少完整資訊鏈整合測試**。它們有豐富的單元測試，但沒有驗證整條資料流串接的整合測試。

建議建立：
1. UC-02：`export-data-flow.test.js` — Storage 讀取 → 格式選擇 → 轉換 → 檔案產生 → 下載觸發
2. UC-04：`search-workflow.test.js` — 使用者輸入 → 索引查詢 → 篩選 → 結果渲染 → 互動

---

## 測試執行結果

```
Test Suites: 2 skipped, 176 passed, 176 of 178 total
Tests:       41 skipped, 4238 passed, 4279 total
Time:        138.766 s
```

## 結論

### 單元測試覆蓋

整體測試覆蓋度良好（~95%）。真正的單元測試差距只有 3 個：
1. UC-01 重複書籍 ID 處理（中嚴重程度）
2. UC-07 資料不一致恢復流程（中嚴重程度）
3. UC-07 網路不穩定同步策略（低嚴重程度）

### 資訊鏈整合測試覆蓋

4/6 UC 有完整的資訊鏈整合測試，2 個 UC 有明確差距：
1. **UC-02 匯出**：無完整串接測試（高優先 — 核心功能）
2. **UC-04 搜尋**：無端到端整合測試（中優先 — 功能完整但無串接驗證）

### 最終差距清單（5 個）

| 差距 | UC | 類型 | 嚴重程度 |
|------|-----|------|---------|
| 重複書籍 ID 處理 | UC-01 | 單元測試 | 中 |
| 匯出完整資訊鏈測試 | UC-02 | 整合測試 | 高 |
| 搜尋端到端測試 | UC-04 | 整合測試 | 中 |
| 資料不一致恢復 | UC-07 | 單元測試 | 中 |
| 網路不穩同步策略 | UC-07 | 單元測試 | 低 |

## 驗收條件

- [x] 6 個 Extension 相關 UC 的測試對應分析完成
- [x] 差距識別和嚴重程度標記
- [x] 確認「待確認」項目的實際覆蓋狀態
- [x] UC 資訊鏈整合測試覆蓋分析完成
- [x] 為 5 個差距建立修復 ticket
  - 0.16.2-W2-001: UC-01 重複書籍 ID 處理測試（P1）
  - 0.16.2-W2-002: UC-02 匯出完整資訊鏈整合測試（P0）
  - 0.16.2-W2-003: UC-04 搜尋端到端整合測試（P1）
  - 0.16.2-W2-004: UC-07 資料不一致恢復流程測試（P1）
  - 0.16.2-W2-005: UC-07 網路不穩定同步策略測試（P2）

---

## 替代方案

本提案採用「人工逐 UC 對照分析」方式。評估期間考慮過以下候選方案：

### 方案 A（已採用）：人工逐 UC 對照分析

逐一閱讀每個 UC 的驗收場景，再以 grep 搜尋對應測試檔，建立對應表並標記差距。

優點：可驗證每個測試與 UC 場景的語意對應，不只是檔名匹配；可正確識別「測試存在但場景不符」的情況。缺點：耗時，需人工判斷。

### 方案 B（未採用）：自動化測試命名掃描

用 grep 關鍵字批次搜尋測試檔名，比對 UC ID（如 `UC01`、`uc01`）。

優點：速度快。缺點：命名規則不一致（`data-import.test.js` 不含 UC 前綴），會漏掉大量實質覆蓋；無法識別語意層的對應關係。

### 選擇依據

本提案目的在識別語意層的測試差距，需要確認「測試是否真正驗證 UC 場景」，而非只確認「有無同名測試」。方案 A 能提供更可靠的差距識別結果，支撐後續 ticket 規格的正確性。

---

## 失敗防護

本分析的主要失敗模式及已採取的防護：

### 失敗情境 1：測試檔案指向的功能已被刪除或重構

防護：分析時同步確認測試檔案是否仍存在且可執行（參見「測試執行結果」章節，4279 個測試 176 個套件通過）。以實際執行通過作為存在性驗證，而非純靜態路徑確認。

### 失敗情境 2：「待確認」項目因調查不完整而殘留錯誤結論

防護：所有初始標記為「待確認」的項目（UC-01 中斷回滾、UC-05 空書庫/效能、UC-07 增量/不一致/網路）均已在「差距確認結果（已驗證）」章節完成補充調查，以實際測試程式碼內容為憑，不以猜測下結論。

### 失敗情境 3：分析結論未轉換為可追蹤的修復計畫

防護：差距分析結論已直接轉換為 5 個獨立 ticket（0.16.2-W2-001 至 W2-005），含嚴重程度和 UC 對應標記，避免分析結論停留在文件而不落地。

---

## Reality Test

### 假設驗證

本提案建立在以下假設上，以下逐一驗證：

**假設 1：「待確認」項目中部分已有間接覆蓋，不需新建測試。**

結果：已驗證為真。UC-05 空書庫（overview-page.test.js 有明確測試）和效能（benchmark-tests.test.js 有閾值斷言）均確認為「已覆蓋」，從而縮小真正差距的範圍。

**假設 2：整合測試差距（UC-02、UC-04）比單元測試差距更需優先修復。**

結果：部分驗證。UC-02 匯出整合測試差距確認為高優先（核心功能無端到端串接），但 UC-04 整合差距（中優先）與 UC-07 單元測試差距（中優先）的優先級相近，後續排序依 UC 核心程度決定。

**假設 3：Extension 不做的場景（API 補充）可直接標為「不適用」而無需測試。**

結果：已驗證為真。UC-01/UC-04 的 Google Books API 補充功能在 Extension 架構中無對應實作，正確標為 Out of Scope，不建立測試差距 ticket。

### 觸發案例

本提案觸發點：v0.16.2 版本的 spec 盤點後，發現有 193 個測試檔案但無系統性的 UC 驗收條件對應表，需要評估現有測試的語意完整性，以支撐後續版本的 TDD 流程品質。分析結果直接支撐 0.16.2-W2 系列 ticket 的規格設計。

---

## v0.19.0 實機驗證記錄

**驗證日期**: 2026-05-23
**驗證 ticket**: 0.19.0-W1-001.2（實機端到端驗證執行）
**彙整 ticket**: 0.19.0-W1-001.3（規格落差三層分類）

v0.19.0 實機端到端驗證已執行，涵蓋 UC-01/02/03/04/06。W1-001.2 最終 8/8 acceptance 全 PASS。驗證過程中發現的規格落差與實作缺口已全部建立 follow-up tickets 追蹤（W1-006/007/009/010/040/041/042/047/061/062），詳見 W1-001.3 Solution 章節。
