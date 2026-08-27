---
id: PROP-001
title: "多平台隔離與跨平台路由"
status: draft
source: "spec"
proposed_by: "spec 盤點"
proposed_date: "2026-03-30"
confirmed_date: null
target_version: "v2.0+"
priority: P2

outputs:
  spec_refs: [spec/platform/platform-management.md]
  usecase_refs: []
  ticket_refs: []

related_proposals: []
supersedes: null
evaluation_level: heavy  # PROP-001 跨版本/架構級（v2.0+ 多平台路由），W10-099 仲裁結論落地（IMP-B）
promotion_review_required: true
---

# PROP-001: 多平台隔離與跨平台路由

## 需求來源

Spec 盤點發現 platform domain 中 PlatformIsolationService 已寫好（1,308 行）但標記為 v1.0 暫置，CrossPlatformRouter 介面預留但未實作。

## 問題描述

當前 Chrome Extension 專注 Readmoo 單一平台。未來要支援 Kindle、Kobo、博客來等多平台時，需要啟用平台間的資料和狀態隔離，以及跨平台路由機制。

## 範圍界定

### 本提案要做的（In Scope）

- 啟用並驗證已有的 PlatformIsolationService
- 實作 CrossPlatformRouter
- 多平台間的資料隔離驗證
- 至少新增一個非 Readmoo 平台的適配器

### 本提案不做的（Out of Scope）

- 所有平台的完整適配器 → 各平台應有獨立提案
- 跨平台資料合併/同步 → 獨立提案處理
- 多平台 UI 切換設計 → UX domain 獨立提案

## 驗收條件

- [ ] PlatformIsolationService 啟用並通過測試
- [ ] CrossPlatformRouter 實作並通過測試
- [ ] 至少一個新平台適配器可運作
- [ ] 多平台間資料完全隔離驗證通過
