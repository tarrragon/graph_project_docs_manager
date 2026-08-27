---
id: PROP-002
title: "UC-06 借閱管理 Presentation 層補齊"
status: revised
source: "development"
proposed_by: "Legacy Code 步驟 1/2 盤點"
proposed_date: "2026-03-31"
confirmed_date: null
target_version: null
priority: P2

outputs:
  spec_refs: [spec/loan/loan-management.md]
  usecase_refs: [usecases/UC-06-loan-management.md]
  ticket_refs: []

related_proposals: [PROP-005]
supersedes: null
evaluation_level: standard
---

# PROP-002: UC-06 借閱管理 Presentation 層補齊

## 需求來源

Legacy Code 步驟 1/2 盤點過程中，發現 UC-06（借閱管理）僅有 Service 層實作，缺少 Presentation 層（UI 介面），功能無法對使用者展示。

## 問題描述

> **2026-06-20 修訂**：原描述「Presentation 層 0 檔案」已過時。經 PROP-005 spec 充實後確認，Presentation 層已有完整實作（5 檔案、54 測試全通過）。本提案目標從「從零建立 UI」修訂為「修復 spec 差距分析發現的具體缺陷」。

UC-06 借閱管理目前的實作狀態：

| 層級 | 狀態 | 檔案數 |
|------|------|--------|
| Service 層 | 已實作 | 5 檔案（`domains/library/services/`） |
| Presentation 層 | 已實作 | 5 檔案（lending_list_page, lending_viewmodel, loan_form_sheet, loan_info_card, loan_status_indicator） |
| 測試 | 已實作 | 54 個測試全通過（ViewModel + Widget 測試） |

### 已識別的 spec 差距（來源：PROP-005 W2-001 loan spec v3.0）

| 差距 | 性質 | 優先級 |
|------|------|--------|
| ViewModel `_fetchAllLoans()` 只取 overdue+dueSoon，LoanFilter.all/returned 無資料 | Bug | P1 |
| `Book.createLoan` 接收 String 而非 LoanType enum | 型別安全 | P1 |
| DB 6 欄位 vs Dart 7 欄位（loanDate/notes 未持久化） | 資料持久化 | P1 |
| `_findBookByLoanId` 用 toString() 字串比對 | 效能/正確性 | P2 |
| 交換格式不承載 loanType/returnedDate/notes | 同步完整性 | P2 |
| UC-06 替代流程（智慧預填、聯絡整合等 4 項） | 新功能 | P3 |

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `lib/domains/library/`、`lib/presentation/library/`、DB schema |
| 檔案 | 修改既有 ViewModel、Service、Entity、DB migration |
| 用例 | UC-06 借閱管理 |

## 範圍界定

### 本提案要做的（In Scope）

- 修復 ViewModel 篩選缺陷（LoanFilter.all/returned 無資料）
- 修復 `Book.createLoan` 型別安全（String → LoanType enum）
- 補齊 DB schema（loanDate/notes 持久化）
- 修復 `_findBookByLoanId` 查找機制
- 補齊交換格式欄位（loanType/returnedDate/notes）

### 本提案不做的（Out of Scope）

- UC-06 替代流程新功能（智慧預填、聯絡整合） → 屬進階功能，另行提案
- 借閱統計或報表功能 → 屬進階功能，另行提案
- 推播通知（到期提醒） → 屬進階功能，另行提案

## 提案方案

### 建議方案

依循專案 MVVM + Riverpod 模式，新增以下元件：

1. `LendingViewModel` — 將 Service 層資料轉換為 UI 狀態
2. `LendingListPage` — 借閱記錄列表
3. `LendingActionWidget` — 借出/歸還操作元件
4. 對應的 Riverpod Provider 定義

遵循 TDD 流程開發，確保 Widget 測試覆蓋。

## 驗收條件

- [ ] LoanFilter.all 和 LoanFilter.returned 可正確篩選借閱記錄
- [ ] `Book.createLoan` 接收 LoanType enum（非 String）
- [ ] DB schema 包含 loanDate 和 notes 欄位且正確持久化
- [ ] `_findBookByLoanId` 使用高效查找機制（非 toString() 比對）
- [ ] 交換格式承載 loanType/returnedDate/notes
- [ ] 所有既有 54 個測試通過（無回歸）
- [ ] 新增修復對應的測試

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Service 層 API 不符合 UI 需求 | 需調整 Service 介面 | Phase 1 設計時確認介面契約 |
| 借閱流程的 UX 設計未定義 | 開發方向不明確 | 先完成 spec 充實（PROP-005）再開始 |

## 討論記錄

### 2026-03-31

由 Legacy Code 步驟 1/2 盤點提出。建議待 PROP-006（Domain Spec 充實）完成借閱管理 spec 後再開始實作。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | spec/loan/loan-management.md | -- | pending |
| 用例 | usecases/UC-06-loan-management.md | -- | pending |
| Ticket | -- | -- | pending |
