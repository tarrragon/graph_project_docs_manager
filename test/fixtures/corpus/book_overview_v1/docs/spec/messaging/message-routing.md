---
id: SPEC-005
title: "通訊管理規格"
status: approved
source_proposal: null
created: "2026-03-30"
updated: "2026-03-30"
version: "1.0"
owner: ""

domain: messaging
subdomain: null

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07, UC-08]
related_specs: [SPEC-001]
implements_requirements: []
depends_on_domains: [core]
---

# 通訊管理規格

## 概述

Messaging domain 處理 Chrome Extension 各 context（Background / Content Script / Popup）間的訊息路由、驗證、會話管理和連線監控。

## 功能需求

### FR-01: 訊息路由與通訊

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：跨 context 的訊息分發和路由。

**已實作元件**：

- [x] MessagingDomainCoordinator
- [x] MessageRoutingService（747 行）
- [x] MessageValidationService（835 行）
- [x] SessionManagementService（565 行）
- [x] ConnectionMonitoringService（663 行）
- [x] QueueManagementService（879 行，含優先級處理）
- [x] ChromeEventBridge（Content Script 側跨 context 通訊）
- [x] ContentEventBus（Content Script 側本地事件管理）

**關鍵檔案**：`src/background/domains/messaging/`, `src/content/bridge/`, `src/content/core/`

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-03-30 | 從 app-requirements-spec.md 遷移，盤點實作狀態 |
