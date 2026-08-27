---
id: SPEC-012
title: "BatchSupplementPage 介面規格（批次補充頁面）"
status: draft
source_proposal: null
created: "2026-06-05"
updated: "2026-06-05"
version: "1.0"
owner: ""

domain: search
subdomain: batch-supplement
related_usecases: [UC-04]
related_specs: [SPEC-005]
implements_requirements: []
depends_on_domains: [search]
tdd_phase: 1
---

# BatchSupplementPage 介面規格（批次補充頁面）

## 1. 概述

### 1.1 目的

定義 UC-04 批次補充流程的頁面介面規格。使用者在書庫管理模式下，一次選取多本資訊不完整的書籍，啟動批次自動搜尋並補充書籍資訊，最後逐筆確認後寫回書庫。

本文件為 **TDD Phase 1 介面規格**，不含實作碼。產出供 Phase 2（Widget 測試）與 Phase 3b（實作）使用。

### 1.2 框架內建機制驗證（ARCH-010 防護）

| 步驟 | 問題 | 結論 |
|------|------|------|
| 1 | Flutter 內建機制是否已解決？ | 否——批次選取+進度+確認為多步驟業務流程，無對應單一 widget |
| 2 | 語言標準庫是否已解決？ | 否 |
| 3 | 本地狀態（StatefulWidget）是否足夠？ | 否——批次處理進度需跨頁面層級的狀態 + Domain 事件，須用既有 Riverpod ViewModel |
| 4 | 既有外部狀態管理是否已存在？ | **是**——`batch_enrich_view_model`（含 interface/state）已齊備，直接沿用，**禁止新建平行 VM** |

**最終決策**：本頁面 = 既有 `BatchEnrichViewModel` 的 UI 接線層。新增僅限「頁面 widget + 9 個 widget Key」。

### 1.3 範圍邊界

| 項目 | 在範圍 | 不在範圍 |
|------|--------|---------|
| 批次補充頁面 widget 結構 | 是 | 跨 UC 導航（`navigation_library`） |
| 9 個 widget Key 定義與接線 | 是 | 既有 ViewModel/Domain/UseCase 修改 |
| 狀態流轉描述 | 是 | 衝突解決頁面（field-level，屬其他 ticket） |
| 沿用 `batch_enrich_view_model` 接線點 | 是 | 新建 ViewModel / Provider |

---

## 2. 沿用既有資產（禁止重建）

| 資產 | 路徑 | 沿用方式 |
|------|------|---------|
| ViewModel | `lib/presentation/search/viewmodels/batch_enrich_view_model.dart` | 直接接線，呼叫 `startBatch` / `pauseBatch` / `resumeBatch` / `cancelBatch` |
| ViewModel 介面 | `lib/presentation/search/viewmodels/batch_enrich_view_model_interface.dart` | 依賴契約，勿改 |
| ViewState | `lib/presentation/search/viewmodels/batch_enrich_view_state.dart` | 讀 `state` / `progress` / `currentBookTitle` / `processedCount` / `totalCount` / `successCount` / `results` |
| Provider | `search_providers` / `book_search_providers` | `ref.watch` 取得 VM 實例 |
| 進度 widget | `lib/presentation/search/widgets/batch_progress_view.dart` | 可內嵌或參考；**Key 須對齊新命名 `batch_progress_indicator`** |
| Domain 服務 | `auto_match_processor` 等批次服務 | 經 `BatchEnrichBooksUseCase` 接線，spec 僅標明接線點 |

**ViewModel 公開方法（接線參考，來源 batch_enrich_view_model.dart）**：

| 方法 | 簽章 | UI 觸發點 |
|------|------|----------|
| `startBatch` | `Future<void> startBatch(List<BookId> bookIds)` | 點擊 `start_batch_process_button` |
| `pauseBatch` | `Future<void> pauseBatch()` | 進度頁暫停（可選，本 ticket 無對應 Key） |
| `resumeBatch` | `Future<void> resumeBatch()` | 同上 |
| `cancelBatch` | `Future<void> cancelBatch()` | 同上 |

**ViewState 狀態枚舉（來源 batch_enrich_view_state.dart）**：`idle` → `preparing` → `processing` → (`paused`) → `completed` / `error` / `cancelled`。

---

## 3. Wireframe（頁面結構描述）

頁面採三段式：**選取段（Selection）→ 進度段（Progress）→ 確認段（Confirm）**，依 ViewState 切換顯示。

### 3.1 入口（書庫管理模式，前置於本頁面）

```
┌─ 書庫頁面（既有，非本 spec 範圍） ──────────────┐
│                                                  │
│  [ 切換管理模式 ]  ← Key: switch_to_management_mode
│                                                  │
│  （進入管理模式後出現批次入口）                  │
│  [ 批次補充 ]      ← Key: batch_supplement_button
│       │                                          │
│       └──點擊 → 導航至 BatchSupplementPage ──────┘
```

> `switch_to_management_mode` 與 `batch_supplement_button` 為書庫管理頁的入口控制項。本 spec 定義其 Key 字面與導航語意；其宿主頁面的整體佈局屬書庫頁職責。

### 3.2 選取段（state = idle / preparing）

```
┌─ BatchSupplementPage：選取段 ─────────────────┐
│  標題：批次補充                                 │
│                                                 │
│  「發現 3 本資訊不完整的書籍」 ← 文字（系統自動篩選）
│                                                 │
│  ☐ 書籍 0   ← Key: incomplete_book_checkbox_0  │
│  ☐ 書籍 1   ← Key: incomplete_book_checkbox_1  │
│  ☐ 書籍 2   ← Key: incomplete_book_checkbox_2  │
│   …（依不完整書籍數量動態產生 checkbox_N）       │
│                                                 │
│  [ 全選 ]            ← Key: select_all_button   │
│  [ 開始批次處理 ]    ← Key: start_batch_process_button
└─────────────────────────────────────────────────┘
```

**設計要點**：

| 元素 | 說明 |
|------|------|
| 不完整書籍清單 | 系統自動篩選（`author` 等欄位為空），逐筆對應 `incomplete_book_checkbox_N`，索引 0-based |
| 全選 | 勾選全部 checkbox |
| 開始批次處理 | 收集已勾選書籍 `BookId` 清單 → 呼叫 `viewModel.startBatch(selectedIds)` → 切換至進度段 |

### 3.3 進度段（state = processing）

```
┌─ BatchSupplementPage：進度段 ─────────────────┐
│  標題：批次補充                                 │
│                                                 │
│  ▭▭▭▭▭░░░  ← Key: batch_progress_indicator     │
│            （讀 state.progress = processed/total）│
│                                                 │
│  「正在處理: 1/3」 ← 文字（state.processedCount / state.totalCount）
│   當前書名：state.currentBookTitle              │
└─────────────────────────────────────────────────┘
```

**設計要點**：

| 元素 | 說明 |
|------|------|
| `batch_progress_indicator` | 對應既有 `batch_progress_view` 的進度語意，Key 改用新命名；綁定 `state.progress`（0.0-1.0） |
| 進度文字 | 格式 `正在處理: {processedCount}/{totalCount}`，須與測試斷言 `textContaining('正在處理: 1/3')` 一致 |
| 自動推進 | VM 完成所有書籍處理後（`state == completed`）自動切換至確認段 |

### 3.4 確認段（state = completed）

```
┌─ BatchSupplementPage：確認段 ─────────────────┐
│  標題：批次處理結果   ← 文字（測試斷言 '批次處理結果'）
│                                                 │
│  （逐筆候選匹配結果，來源 state.results）         │
│  書籍 0 → 最佳匹配候選 …                          │
│  書籍 1 → 最佳匹配候選 …                          │
│  書籍 2 → 最佳匹配候選 …                          │
│                                                 │
│  [ 自動選擇最佳匹配 ] ← Key: auto_select_best_matches
│  [ 確認批次更新 ]     ← Key: confirm_batch_update │
└─────────────────────────────────────────────────┘
```

**設計要點**：

| 元素 | 說明 |
|------|------|
| `auto_select_best_matches` | 為每本書套用最高相似度候選（VM 已於 processing 階段以 `similarityThreshold=0.8` 自動標記） |
| `confirm_batch_update` | 確認寫回書庫 → 顯示結果文字 `已更新 {n} 本書籍資訊`（測試斷言 `textContaining('已更新 3 本書籍資訊')`） |

---

## 4. 狀態流轉圖

```
        進入頁面
           │
           ▼
   ┌──────────────┐  系統自動篩選不完整書籍
   │   idle       │  顯示 checkbox_0..N
   │ (選取段)     │
   └──────┬───────┘
          │ 勾選 + 點 start_batch_process_button
          │ → viewModel.startBatch(selectedIds)
          ▼
   ┌──────────────┐  驗證數量（1-20 本）
   │  preparing   │
   └──────┬───────┘
          ▼
   ┌──────────────┐  逐本搜尋 + 自動選候選 + 發進度事件
   │  processing  │  顯示 batch_progress_indicator
   │ (進度段)     │  文字「正在處理: x/total」
   └──────┬───────┘
          │ 全部完成
          ▼
   ┌──────────────┐  顯示「批次處理結果」+ results
   │  completed   │  auto_select_best_matches
   │ (確認段)     │  confirm_batch_update
   └──────┬───────┘
          │ confirm_batch_update → 寫回書庫
          ▼
     「已更新 n 本書籍資訊」

   旁支狀態（本 ticket 無對應 Key，VM 已支援）：
   processing ──pauseBatch──▶ paused ──resumeBatch──▶ processing
   processing ──cancelBatch──▶ cancelled
   任一階段失敗 ─────────────▶ error（顯示 state.errorMessage）
```

---

## 5. Widget Key 命名表（逐一對照流程段）

字面**必須**與 `test/integration/uc04_to_uc08_integration_tests.dart`（line 235-271）完全一致。

| # | Key 字面 | 流程段 | 元件型別（建議） | 接線點 |
|---|---------|--------|----------------|--------|
| 1 | `switch_to_management_mode` | 入口（書庫頁） | Button | 切換書庫管理模式 |
| 2 | `batch_supplement_button` | 入口（書庫頁） | Button | 導航至 BatchSupplementPage |
| 3 | `incomplete_book_checkbox_0` | 選取段 | Checkbox | 不完整書籍 index 0 |
| 4 | `incomplete_book_checkbox_1` | 選取段 | Checkbox | 不完整書籍 index 1 |
| 5 | `incomplete_book_checkbox_2` | 選取段 | Checkbox | 不完整書籍 index 2 |
| 6 | `select_all_button` | 選取段 | Button | 勾選全部 checkbox |
| 7 | `start_batch_process_button` | 選取段 | Button | `viewModel.startBatch(selectedIds)` |
| 8 | `batch_progress_indicator` | 進度段 | ProgressIndicator | 綁定 `state.progress` |
| 9 | `auto_select_best_matches` | 確認段 | Button | 套用最佳匹配 |
| 10 | `confirm_batch_update` | 確認段 | Button | `confirmUpdate` → 寫回書庫 |

**合計 9 個 BatchSupplementPage 待建 Key**（#3-#10 為頁面本體 8 個；#1-#2 為書庫管理頁入口 2 個，其中 #1/#2 屬入口控制項）。

> 註：checkbox 索引為 0-based，與測試固定斷言 `_0/_1/_2` 對齊（測試固定 3 本不完整書籍）。實作時 Key 須以 `incomplete_book_checkbox_$index` 動態生成，前 3 筆即落在 `_0/_1/_2`。

**不在範圍 Key**：`navigation_library`（跨 UC 導航，屬整合測試環境前置，非本頁面職責）。

---

## 6. 接線指引（Phase 3b 參考，非實作碼）

| 動作 | 接線方式 |
|------|---------|
| 取得 VM | `final viewModel = ref.watch(batchEnrichViewModelProvider.notifier)`（沿用既有 provider，名稱以 `search_providers` 實際匯出為準） |
| 讀狀態 | `final state = ref.watch(batchEnrichViewModelProvider)` → 依 `state.state` 路由三段 UI |
| 啟動批次 | 收集勾選書籍 `List<BookId>` → `await viewModel.startBatch(ids)` |
| 進度綁定 | `LinearProgressIndicator(value: state.progress, key: const Key('batch_progress_indicator'))` |
| 確認更新 | `confirm_batch_update` onTap → 透過 VM/UseCase 寫回（既有 `confirmUpdate` 鏈路） |

---

## 7. 驗收標準（供 Phase 2 測試設計）

| # | 驗收項 | 驗證方式 |
|---|--------|---------|
| AC1 | 入口可進管理模式並開啟批次補充頁 | tap `switch_to_management_mode` → tap `batch_supplement_button` |
| AC2 | 系統自動列出不完整書籍 checkbox | `incomplete_book_checkbox_0/1/2` 各 findsOneWidget |
| AC3 | 全選 + 開始可進入進度段 | tap `select_all_button` → `start_batch_process_button` → `batch_progress_indicator` findsOneWidget |
| AC4 | 進度文字格式正確 | `textContaining('正在處理: 1/3')` |
| AC5 | 完成後顯示確認段 | 文字 `批次處理結果` + `auto_select_best_matches` findsOneWidget |
| AC6 | 確認更新寫回書庫 | tap `auto_select_best_matches` → `confirm_batch_update` → `textContaining('已更新 3 本書籍資訊')` |
| AC7 | 沿用既有 ViewModel | 程式碼審查：無新建平行 VM，接線 `batch_enrich_view_model` |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。
