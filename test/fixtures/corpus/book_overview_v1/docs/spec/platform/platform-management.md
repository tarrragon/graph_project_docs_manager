---
id: SPEC-003
title: "平台管理規格"
status: approved
source_proposal: PROP-001
created: "2026-03-30"
updated: "2026-03-30"
version: "1.0"
owner: ""

domain: platform
subdomain: null

related_usecases: [UC-01, UC-07]
related_specs: [SPEC-001, SPEC-002]
implements_requirements: []
depends_on_domains: [core]
---

# 平台管理規格

## 概述

Platform domain 管理電子書平台的偵測、註冊、切換和適配器工廠。目前專注 Readmoo 單一平台，架構已為多平台預留。

## 功能需求

### FR-01: 平台偵測與註冊

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：識別和管理 Readmoo 平台實例。

**已實作元件**：

- [x] PlatformDomainCoordinator
- [x] PlatformDetectionService（1,084 行）
- [x] PlatformRegistryService（960 行）
- [x] PlatformSwitcherService（965 行）
- [x] AdapterFactoryService（1,474 行，含資源池化）

**關鍵檔案**：`src/background/domains/platform/`

---

### FR-02: 平台資料驗證

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：Readmoo 平台特定的資料驗證和遷移驗證。

**已實作元件**：

- [x] ReadmooDataValidator
- [x] ReadmooMigrationValidator

**關鍵檔案**：`src/platform/`

---

### FR-03: 多平台隔離（v2.0+）

| 項目 | 值 |
|------|-----|
| 優先級 | P2 |
| 狀態 | 刻意暫置 |

**描述**：多平台間的資料和狀態隔離。v1.0 專注單一平台不需要啟用。

**現況**：

- [x] PlatformIsolationService 已寫好（1,308 行）但標記為 v1.0 暫置
- [ ] CrossPlatformRouter 介面預留但未實作

**備註**：需要時應建立獨立提案，綁定到具體版本。

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-03-30 | 從 app-requirements-spec.md 遷移，盤點實作狀態 |
