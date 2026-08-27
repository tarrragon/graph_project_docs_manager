---
id: PROP-003
title: "UC-05/07 測試覆蓋補強"
status: superseded
source: "tech-debt"
proposed_by: "Legacy Code 步驟 1/2 盤點"
proposed_date: "2026-03-31"
confirmed_date: null
target_version: null
priority: P2

outputs:
  spec_refs: [spec/library/dual-mode-display.md, spec/synchronization/cross-platform-sync.md]
  usecase_refs: [usecases/UC-05-dual-mode-library-display.md, usecases/UC-07-cross-platform-sync.md]
  ticket_refs: []

related_proposals: [PROP-004]
superseded_by: PROP-004
---

# PROP-003: UC-05/07 測試覆蓋補強

## 需求來源

Legacy Code 步驟 1/2 盤點過程中，發現 UC-05（雙模式書庫展示）和 UC-07（跨平台同步）的測試覆蓋率顯著不足，程式碼量與測試量嚴重不成比例。

## 問題描述

| 用例 | 程式碼檔案數 | 測試檔案數 | 測試比例 |
|------|------------|-----------|---------|
| UC-05 書庫展示 | 133+ | 9 | 約 6.8% |
| UC-07 跨平台同步 | 87+ | 6 | 約 6.9% |

這兩個用例的程式碼量在專案中佔比較高，但測試覆蓋嚴重不足，存在較大的回歸風險。相比之下，其他用例的測試比例普遍在 20% 以上。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | UC-05 相關模組（`presentation/library/`、`domains/library/`）、UC-07 相關模組（`domains/sync/`、`infrastructure/sync/`） |
| 檔案 | 需新增大量測試檔案 |
| 用例 | UC-05 雙模式書庫展示、UC-07 跨平台資料同步 |

## 範圍界定

### 本提案要做的（In Scope）

- 盤點 UC-05 關鍵邏輯路徑，補充單元測試和 Widget 測試
- 盤點 UC-07 關鍵邏輯路徑，補充單元測試
- 以測試金字塔設計為基準，優先補強底層單元測試
- 目標：將兩個 UC 的測試比例提升至 20% 以上

### 前置條件（必須先完成）

- PROP-004 中 UC-05 和 UC-07 的失敗測試必須先修復，才能開始補強覆蓋率（避免混淆新舊失敗）

### 本提案不做的（Out of Scope）

- 程式碼重構 → 純補測試，不改變現有邏輯
- 整合測試和 E2E 測試 → 優先補強單元測試層
- 其他 UC 的測試補強 → 各自獨立評估
- 修復現有失敗測試 → 屬 PROP-004 範疇

## 提案方案

### 建議方案

分兩階段進行：

**階段一：盤點與規劃**
- 分析每個 UC 的程式碼結構，識別關鍵邏輯路徑
- 依照測試金字塔設計（`docs/test-pyramid-design.md`）規劃測試案例
- 產出測試清單和優先順序

**階段二：測試實作**
- 依優先順序逐步補充測試
- 每批測試完成後驗證通過率

## 驗收條件

- [ ] UC-05 測試檔案數達到程式碼檔案數的 20% 以上
- [ ] UC-07 測試檔案數達到程式碼檔案數的 20% 以上
- [ ] 所有新增測試通過（100% 通過率）
- [ ] 關鍵邏輯路徑（Domain Service、ViewModel）有對應測試

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 現有程式碼可測試性差 | 需先重構才能寫測試 | 評估後視需要拆為獨立重構 Ticket |
| 測試數量大，耗時長 | 排程壓力 | 分批次交付，優先覆蓋核心邏輯 |

## 討論記錄

### 2026-03-31

由 Legacy Code 步驟 1/2 盤點提出。**前置依賴**：PROP-004 必須先完成 UC-05/07 的失敗測試修復，再執行本提案。在失敗測試未清零前補強覆蓋率會混淆新舊失敗。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | -- | -- | pending |
