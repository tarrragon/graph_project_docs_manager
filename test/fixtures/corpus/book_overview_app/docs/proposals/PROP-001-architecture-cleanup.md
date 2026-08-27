---
id: PROP-001
title: "架構清理 — 合併重複目錄"
status: approved
source: "tech-debt"
proposed_by: "Legacy Code 步驟 1/2 盤點"
proposed_date: "2026-03-31"
confirmed_date: null
target_version: null
priority: P1

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: []
supersedes: null
---

# PROP-001: 架構清理 — 合併重複目錄

## 需求來源

Legacy Code 步驟 1/2 盤點過程中，發現 `lib/` 目錄存在多組重複或殘留的目錄結構，屬於歷史開發遺留的技術債。

## 問題描述

`lib/` 下有 6 組重複或不一致的目錄：

| 重複組 | 目錄 A | 目錄 B | 說明 |
|--------|--------|--------|------|
| Domain 層 | `domain/`（18 檔案） | `domains/`（366 檔案） | 主體在 `domains/`，`domain/` 為殘留 |
| 資料層 | `data/`（2 檔案） | `infrastructure/`（106 檔案） | 主體在 `infrastructure/`，`data/` 為殘留 |
| Use Case 層 | `use_cases/` | `usecases/` | 命名不一致 |
| Application 層 | `app/`（3 檔案） | `application/`（3 子目錄） | 職責重疊，需確認歸屬 |
| Features | `features/`（1 檔案） | -- | 疑似廢棄目錄 |

這些重複目錄導致：
- 開發者不確定新程式碼應放在哪個目錄
- import 路徑不一致，增加維護負擔
- 靜態分析和搜尋結果出現雜訊

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | domain/, domains/, data/, infrastructure/, use_cases/, usecases/, features/ |
| 檔案 | 涉及 import 路徑調整的所有檔案 |
| 用例 | 跨所有用例（目錄結構為全域影響） |

## 範圍界定

### 本提案要做的（In Scope）

- 將 `domain/export/` 內容合併至 `domains/export/`，刪除 `domain/` 目錄
- 將 `data/` 內的 2 個檔案遷移至 `infrastructure/` 對應位置，刪除 `data/` 目錄
- 統一 `use_cases/` 與 `usecases/` 命名（選擇其一作為標準）
- 確認 `app/` 和 `application/` 的職責劃分，合併或明確分工
- 評估並清理 `features/` 目錄（1 個檔案）
- 更新所有受影響的 import 路徑
- 同步更新受影響的測試檔案 import 路徑

### 本提案不做的（Out of Scope）

- 目錄內部的程式碼重構 → 屬各 UC 各自的開發範疇
- 架構層級的重新設計 → 目前架構層級已穩定，僅處理重複問題

## 提案方案

### 建議方案

逐步合併，每組目錄獨立處理並驗證：

1. `domain/` → `domains/`：將 `domain/export/` 內容移入 `domains/export/`
2. `data/` → `infrastructure/`：將 2 個檔案移入對應子目錄
3. `use_cases/` + `usecases/`：統一為 `use_cases/`（符合 Dart 命名慣例 snake_case）
4. `app/` + `application/`：確認職責後合併或明確分工
5. `features/`：確認唯一檔案用途後決定遷移目標或刪除

每步完成後執行 `dart analyze` 和 `flutter test`，確保 import 路徑和測試全部正確。

## 驗收條件

- [ ] `lib/` 下不存在 `domain/` 目錄（已合併至 `domains/`）
- [ ] `lib/` 下不存在 `data/` 目錄（已遷移至 `infrastructure/`）
- [ ] Use Case 層目錄命名統一（只有一個目錄）
- [ ] `app/` 和 `application/` 的職責已明確（合併或分工）
- [ ] `lib/` 下不存在 `features/` 目錄（已清理）
- [ ] 所有 import 路徑已更新（含測試檔案），`dart analyze` 無錯誤
- [ ] 全量測試通過率不低於修改前

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 大量 import 路徑變更導致遺漏 | 編譯失敗 | 使用 IDE 重構工具 + `dart analyze` 全量檢查 |
| 合併時檔案名稱衝突 | 覆蓋風險 | 逐檔比對內容再合併 |

## 討論記錄

### 2026-03-31

由 Legacy Code 步驟 1/2 盤點提出，尚待確認優先順序和排期。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | -- | -- | pending |
