---
id: PROP-002
title: "跨設備同步機制完善"
status: confirmed
source: "spec"
proposed_by: "spec 盤點"
proposed_date: "2026-03-30"
confirmed_date: null
target_version: "v0.16.2"
priority: P1
evaluation_level: heavy

outputs:
  spec_refs: [spec/data-management/data-management.md]
  usecase_refs: []
  ticket_refs:
    - "0.16.2-W1-001"

related_proposals: [PROP-003]
supersedes: null
---

# PROP-002: 跨設備同步機制完善

## 需求來源

Spec 盤點發現 data-management domain 的同步功能（FR-06）為部分實作狀態：CrossDeviceSyncService、SyncProgressTracker 等已實作，但 SyncStrategyProcessor（201 行）和 RetryCoordinator（290 行）為簡化版。

已有相關 Ticket: 0.16.2-W1-001（分析 UC-05 跨設備同步機制需求與實作規劃）。

## 問題描述

同步功能有基本架構，但策略處理和重試機制較簡化，需要進一步評估是否滿足實際跨設備使用需求。

## 範圍界定

### 本提案要做的（In Scope）

- 評估現有 SyncStrategyProcessor 是否需要增強
- 評估 RetryCoordinator 重試策略是否足夠
- 設計完整的同步流程（含衝突解決策略）
- 與 Chrome Storage Sync API 的整合方案

### 本提案不做的（Out of Scope）

- 雲端伺服器同步 → v2.0+ 獨立提案
- 跨瀏覽器同步 → 不在本版本範圍
- 備份恢復機制 → PROP-003 處理

## 驗收條件

- [ ] 完成同步機制需求分析報告（0.16.2-W1-001）
- [ ] 確定 SyncStrategyProcessor 增強方案
- [ ] 確定 RetryCoordinator 重試策略
- [ ] 同步流程設計文件完成

---

## 替代方案

### 與 PROP-007 範圍交集說明

PROP-007（跨專案規格對齊）確認本提案進階同步功能（斷點續傳、智慧合併等）延後至 v2.0。Chrome Storage Sync API 方案（v1.0）仍在本提案範圍內；Google Drive API 自動同步屬 PROP-007 新增範圍，**不與本提案衝突**。

### 候選方案

| 方案 | 說明 | 優點 | 缺點 |
|------|------|------|------|
| A（當前選定）| Chrome Storage Sync API | 原生平台支援，無需額外伺服器 | 容量限制（8KB/item，100KB 總量）|
| B | IndexedDB + 手動 JSON 匯出/匯入 | 無容量限制，與 PROP-007 Interchange Format v2 對齊 | 需用戶手動操作，非即時同步 |
| C | Firebase Realtime Database（v2.0+） | 即時同步，多裝置感知 | 需帳號系統、成本高、v1.0 不可行 |

**選定理由**：v1.0 階段方案 A 實作成本最低，且 PROP-007 已確認 v1.0 使用 JSON 匯出/匯入手動同步（方案 B）作為補充，兩者互補不衝突。v2.0 階段依 PROP-007 改採 Google Drive API。

---

## 失敗防護

### 已知失敗情境與防護

| 失敗情境 | 觸發條件 | 防護措施 |
|---------|---------|---------|
| Chrome Storage Sync 容量超限 | 書庫資料量大（> 100KB） | 分塊存儲 + 壓縮；超限時降級至 Local Storage 並提示用戶匯出備份（PROP-003 範疇）|
| 同步衝突（多裝置同時寫入） | 用戶在兩台設備近乎同時操作 | Last-Write-Wins（updatedAt 時間戳比對）；衝突詳細設計待 0.16.2-W1-001 分析 |
| RetryCoordinator 無限重試 | 網路持續不穩 | 指數退避（最多 3 次）+ 熔斷機制；達上限後靜默失敗並記錄錯誤日誌 |

### PROP-007 範圍交集的失敗防護

PROP-007 將同步方案從 Chrome Storage Sync 改為 v2.0 採 Google Drive API。v1.0 若 SyncStrategyProcessor 增強投入過多，v2.0 改架構時可能形成廢棄成本。防護方式：v1.0 僅做最小可行增強（確保 Chrome Storage Sync 穩定），不做未來 Google Drive API 相容性預設計。

---

## Reality Test

### 假設驗證

**核心假設**：Chrome Storage Sync API 容量足以支撐一般用戶的書庫規模。

**驗證方式**：

1. 實測 Readmoo 書庫資料大小：從 storage 模組提取現有書籍資料，計算序列化後體積
2. 與 Chrome Storage Sync 100KB 總量上限比對
3. 若一般用戶（< 500 本書）超限，立即升級防護方案（分塊）

**觸發案例**：

- 若 0.16.2-W1-001 需求分析顯示 SyncStrategyProcessor 需大幅重寫（> 200 行改動），應重評 v1.0 範圍——可能超出本提案預期成本
- 若 PROP-007 v2.0 時間表提前，本提案 v1.0 Chrome Storage 方案可能直接跳過，需建 ANA 重審

---

## 多視角審查

### Multi-view 審查摘要（W10-098.3 補充）

| 視角 | 評估 | 結論 |
|------|------|------|
| 架構師視角（PROP-007 交集） | PROP-002 原規劃 Chrome Storage Sync 進階功能，PROP-007 已明確將斷點續傳/智慧合併延後至 v2.0，並改採 Google Drive API | v1.0 範圍收縮：僅需確保基礎 Chrome Storage Sync 穩定性，不做進階策略 |
| 用戶體驗視角 | 手動匯出/匯入（PROP-007 v1.0 方案）對技術用戶可接受，一般用戶可能不知道要做 | v1.0 加「同步提示」UI 引導用戶主動匯出 |
| 測試可行性視角 | SyncStrategyProcessor 和 RetryCoordinator 的增強需要 E2E 測試或 mock Chrome Storage | 0.16.2-W1-001 分析時須評估測試方案，避免純手動驗證 |
| 技術債視角 | v1.0 若做 Chrome Storage Sync 加固，v2.0 改 Google Drive API 時需重構 | 建議 v1.0 SyncStrategyProcessor 增強以介面抽象設計，降低 v2.0 重構成本 |

**嚴重衝突評估**：本提案與 PROP-007 無不可調和衝突。PROP-007 縮小了 v1.0 同步功能範圍，本提案應相應縮小至「確保 Chrome Storage Sync API 基礎穩定」，不需重審 PROP-002 狀態。

---

## 機會成本

### Opportunity Cost 分析

**執行本提案的機會成本**：

在 v0.17.x（Tag-based Book Model 重構，PROP-007 主軸）進行中的情況下，提前投入 v0.16.2 的同步機制分析（0.16.2-W1-001），可能分散工程資源。

| 決策 | 說明 | 成本 |
|------|------|------|
| 立即執行 0.16.2-W1-001 分析 | 在 PROP-007 v0.17.x 完成前完成 | 分析結論可能因 PROP-007 落地而部分失效（機會成本：高）|
| 延後至 v0.17.x 完成後 | 等 Tag-based Model 穩定後再分析同步需求 | 延後期間 Chrome Storage Sync 風險持續（機會成本：中）|
| 縮小範圍，只做穩定性修復 | 不做全面分析，只修 RetryCoordinator 明顯缺陷 | 最低成本，最快可交付（目前建議方向）|

**建議**：依 PROP-007 對 PROP-002 的範圍縮小決定，v1.0 採「縮小範圍，只做穩定性修復」，0.16.2-W1-001 的分析範疇應相應調整。v2.0 Google Drive API 同步由 PROP-007 主導，屬不同提案。
