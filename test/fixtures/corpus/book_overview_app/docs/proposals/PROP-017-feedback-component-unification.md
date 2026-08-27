---
# 提案（Proposal）

id: PROP-017
title: "回饋類元件統一化——載入指示、SnackBar、空狀態元件"
status: draft
source: tech-debt
proposed_by: "PROP-016 三關式審查第二關探問發現（UI/互動 + UX 維度）"
proposed_date: "2026-07-08"
confirmed_date: null
target_version: null                 # PROP-016（v0.38.0）完成後的版本再定
priority: P2
evaluation_level: standard

# 轉化產出追蹤
outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

# 關聯
related_proposals: [PROP-016]        # 結構類元件統一（本提案的前置，元件庫模式與 hook 防線由其建立）
supersedes: null
---

# PROP-017: 回饋類元件統一化——載入指示、SnackBar、空狀態元件

## 需求來源

PROP-016（結構類元件庫統一化）三關式審查中，完整性探問（「載入中、空狀態、錯誤狀態各顯示什麼」「操作完成後使用者如何知道成功」）發現回饋類元件散落，因行為語意複雜度與結構類不同、且併入將使單版本範圍超過認知負擔閾值，依一提案一版本原則拆出獨立提案。

## 問題描述

操作回饋（載入、成功/失敗提示、空資料）是跨頁面高頻出現的 UI 語意，目前全數原生直用、無統一元件：

| 散落項 | 量（2026-07-08 實測） | 問題 |
|--------|----------------------|------|
| CircularProgressIndicator / LinearProgressIndicator | 36 處（32 檔） | spec §9 已有 loadingIndicator 尺寸 token 但無元件承載，尺寸/顏色各自指定 |
| SnackBar 直用 | 32 處 | 顯示時長、action 樣式、位置各自為政；成功/失敗語意無統一視覺 |
| 空狀態元件 | 不存在 | 各清單頁自行組合圖示 + 文字，無統一空狀態模式 |

## 範圍界定（草案，評估審查時細化）

### 本提案要做的（In Scope）

1. `AppLoadingIndicator`（依 spec §9 尺寸 token，small/medium/large）
2. `AppSnackBar`（成功/失敗/資訊三語意變體，統一時長與 action 樣式）+ 存量 32 處遷移
3. `AppEmptyState`（圖示 + 主文 + 次文 + 可選 action 的統一空狀態）
4. ProgressIndicator 存量 36 處遷移
5. style-guardian hook 禁用清單擴充（沿用 PROP-016 建立的執法機制）

### 本提案不做的（Out of Scope）

- 結構類元件（按鈕/卡片/對話框/分隔線）→ PROP-016 承擔
- 全域 loading 狀態管理（ViewModel 層）→ 屬狀態管理架構，非元件層

## 驗收條件（草案）

- [ ] 三個回饋元件存在且引用既有 token，barrel 已 export
- [ ] `lib/presentation/` ProgressIndicator / SnackBar 直用 grep 計數為 0（豁免清單除外）
- [ ] hook 禁用清單含回饋類元件，WARNING 可觸發

## Reality Test / 觸發案例實證

### 觸發案例

2026-07-08 PROP-016 評估審查探問時實測（見問題描述表）。前置事實：spec §9 loadingIndicator token 已存在（token 有、元件無、散落 36 處——與 PROP-016 的 divider 情況同構）。

### 假設列舉

- 假設 1：SnackBar 32 處的行為語意（時長/action）可歸納為少數變體 → 未驗證，評估審查時分類
- 假設 2：空狀態場景數量足以支撐統一元件 → 未驗證，需盤點清單頁數量
- 假設 3：PROP-016 的 hook 執法機制可直接擴充禁用清單 → 依賴 PROP-016 完成

## 討論記錄

### 2026-07-08

隨 PROP-016 confirmed 同步建立（履行其 Out of Scope 的 trigger 綁定）。target_version 待 PROP-016（v0.38.0）完成後排定；假設 3 使本提案隱含 blockedBy PROP-016 的 hook 工作項。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | （提案確認後開立） | | pending |
