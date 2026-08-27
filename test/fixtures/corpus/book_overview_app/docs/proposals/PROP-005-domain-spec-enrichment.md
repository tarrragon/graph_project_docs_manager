---
id: PROP-005
title: "Domain Spec 充實"
status: approved
source: "spec"
proposed_by: "Legacy Code 步驟 1/2 盤點"
proposed_date: "2026-03-31"
confirmed_date: null
target_version: null
priority: P2

outputs:
  spec_refs: [spec/core/error-handling.md, spec/import/chrome-extension-import.md, spec/export/library-export.md, spec/scanner/isbn-barcode-scanning.md, spec/search/keyword-search-enrichment.md, spec/library/dual-mode-display.md, spec/loan/loan-management.md, spec/synchronization/cross-platform-sync.md, spec/version-management/SPEC-009-book-version-management.md]
  usecase_refs: [usecases/UC-01-chrome-import.md, usecases/UC-02-library-export.md, usecases/UC-03-isbn-scan.md, usecases/UC-04-keyword-search.md, usecases/UC-05-dual-mode-library-display.md, usecases/UC-06-loan-management.md, usecases/UC-07-cross-platform-sync.md, usecases/UC-08-book-version-management.md, usecases/UC-09-error-handling.md]
  ticket_refs: []

related_proposals: []
supersedes: null
---

# PROP-005: Domain Spec 充實

## 需求來源

Legacy Code 步驟 1/2 盤點過程中，發現 `docs/spec/` 下的 9 個 domain spec 檔案僅有骨架和佔位內容，缺少實質的功能需求描述。

## 問題描述

在 `docs/spec/{domain}/` 目錄下已建立 9 個 spec stub 檔案，但目前僅包含佔位符內容，缺乏：

- 從 `app-requirements-spec.md` 提取的功能需求
- 從現有程式碼反推的實際行為規格
- 業務規則和約束條件
- 介面契約定義

缺少充實的 spec 文件導致：
- 新功能開發（如 PROP-002）缺乏明確的需求依據
- 測試設計（如 PROP-003）缺乏驗證基準
- 團隊成員無法快速了解各 domain 的功能範圍

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | 全部 9 個 domain 的 spec 文件 |
| 檔案 | `docs/spec/` 下的 9 個 stub 檔案 |
| 用例 | 全部 9 個用例（UC-01 至 UC-09） |

## 範圍界定

### 本提案要做的（In Scope）

- 從 `docs/app-requirements-spec.md` 提取各 domain 的功能需求
- 從現有程式碼（`lib/` 目錄）反推實際已實作的行為規格
- 為每個 spec 檔案補充：功能需求、業務規則、介面契約（method signature + 參數/回傳型別）、資料模型（Entity 欄位定義）
- 標記 spec 與程式碼之間的差距（已規劃但未實作、已實作但未規劃）

### 本提案不做的（Out of Scope）

- 新功能的需求設計 → 屬各功能的獨立提案
- 程式碼修改以符合 spec → 屬各 UC 的開發範疇
- API 文件自動產生 → 屬工具鏈改善

## 提案方案

### 建議方案

按 domain 逐一充實，優先處理有待開發需求的 domain：

**優先順序**：
1. `spec/loan/`（UC-06 待開發 Presentation 層，需求最急迫）
2. `spec/library/`（UC-05 測試覆蓋不足，需要行為基準）
3. `spec/synchronization/`（UC-07 測試覆蓋不足）
4. 其餘 6 個 domain 依序處理

**每個 spec 的充實步驟**：
1. 閱讀 `app-requirements-spec.md` 中的對應章節
2. 閱讀現有程式碼的 Domain Service 和 Entity
3. 整理為結構化的 spec 內容
4. 標記需求與實作的差距

## 驗收條件

- [ ] 9 個 spec 檔案均已充實（無佔位符內容）
- [ ] 每個 spec 包含：功能需求、業務規則、介面契約（method signature）、資料模型（Entity 欄位）
- [ ] 需求與實作的差距已標記
- [ ] spec 內容與 `app-requirements-spec.md` 一致（無遺漏）

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 程式碼已偏離原始需求 | spec 與實作不一致 | 標記差距，由 PM 決定以哪方為準 |
| 工作量大（9 個 domain） | 排程壓力 | 按優先順序分批交付 |

## 討論記錄

### 2026-03-31

由 Legacy Code 步驟 1/2 盤點提出。建議優先處理 UC-06 的 spec，以支援 PROP-002 的 Presentation 層開發。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | -- | -- | pending |
