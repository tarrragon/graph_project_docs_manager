---
id: SPEC-002
title: "資料提取流程規格"
status: approved
source_proposal: null
created: "2026-03-30"
updated: "2026-05-25"
version: "1.1"
owner: ""

domain: extraction
subdomain: null

related_usecases: [UC-01, UC-03, UC-04]
related_specs: [SPEC-001, SPEC-002a, SPEC-003]
implements_requirements: []
depends_on_domains: [core, platform, messaging]
---

# 資料提取流程規格

## 概述

Extraction domain 負責從 Readmoo 網頁提取書籍資料，包含資料處理、驗證、品質控制和匯出。

## 功能需求

### FR-01: 資料提取協調

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：統一協調資料處理、驗證、匯出、狀態管理和品質控制微服務。

**已實作元件**：

- [x] ExtractionDomainCoordinator
- [x] DataProcessingService（格式轉換、管道處理、快取）
- [x] ValidationService（批量驗證、規則管理、錯誤報告）
- [x] ExportService（多格式匯出、任務管理、進度追蹤）
- [x] ExtractionStateService（提取狀態追蹤）
- [x] QualityControlService（品質評估和異常檢測）

**關鍵檔案**：`src/background/domains/extraction/`

---

### FR-02: Readmoo 資料驗證

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：Readmoo 平台專屬的資料驗證規則、清理和統計追蹤。

**已實作元件**：

- [x] ReadmooDataValidator
- [x] 完整驗證規則集
- [x] 資料清理
- [x] 統計追蹤

**關鍵檔案**：`src/extractors/`

---

### FR-03: Content Script 資料提取

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：從 Readmoo 網頁 DOM 提取書籍資料。

**已實作元件**：

- [x] BookDataExtractor 提取流程管理
- [x] ReadmooAdapter 完整 DOM 操作、資料提取、安全過濾
- [x] PlatformAdapterInterface 標準適配介面

**關鍵檔案**：`src/content/extractors/`, `src/content/adapters/`

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.1 | 2026-05-25 | 補列 related_specs SPEC-002a（E2E 契約規格分檔，W5-007） |
| 1.0 | 2026-03-30 | 從 app-requirements-spec.md 遷移，盤點實作狀態 |
