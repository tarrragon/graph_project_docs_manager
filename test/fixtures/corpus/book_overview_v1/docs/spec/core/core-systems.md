---
id: SPEC-001
title: "核心系統規格"
status: approved
source_proposal: null
created: "2026-03-30"
updated: "2026-03-30"
version: "1.0"
owner: ""

domain: core
subdomain: null

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07, UC-08]
related_specs: []
implements_requirements: []
depends_on_domains: []
---

# 核心系統規格

## 概述

Core domain 是所有其他 domain 的基礎依賴，提供錯誤處理、事件系統、日誌、訊息管理和效能監控。

## 功能需求

### FR-01: 錯誤處理系統

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：分層錯誤處理，基於 ErrorCodes 常數和專用錯誤類別。

**已實作元件**：

- [x] ErrorCodes 統一常數管理（11 個領域分類）
- [x] StandardError 基礎錯誤類別
- [x] NetworkError 網路相關錯誤
- [x] BookValidationError 書籍資料驗證錯誤
- [x] ErrorHelper 統一錯誤處理工具
- [x] OperationResult 統一操作結果結構
- [x] UC01-UC07 ErrorAdapter/ErrorFactory 用例特定錯誤適配

**關鍵檔案**：`src/core/errors/`, `src/core/errors/codes/`

---

### FR-02: 事件系統

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 狀態 | [x] 已實作 |

**描述**：統一事件匯流排，支援事件優先級管理和跨模組通訊。

**已實作元件**：

- [x] EventBus 核心事件匯流排
- [x] EventHandler 事件處理器
- [x] EventSystemUnifier 事件系統統一器
- [x] 事件命名系統和優先級管理

**關鍵檔案**：`src/core/events/`, `src/core/`

---

### FR-03: 日誌系統

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：支援多環境（瀏覽器/Node.js）的日誌系統，含日誌等級過濾。

**已實作元件**：

- [x] Logger 類別（多環境支援）
- [x] 日誌等級過濾
- [x] MessageDictionary 整合

**關鍵檔案**：`src/core/logging/`

---

### FR-04: 訊息字典

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：統一訊息管理，支援訊息鍵值和參數替換。

**已實作元件**：

- [x] MessageDictionary 統一訊息管理
- [x] 訊息鍵值查詢
- [x] 參數替換

**關鍵檔案**：`src/core/messages/`

---

### FR-05: Enum 系統

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：型別安全的列舉值和驗證工具。

**已實作元件**：

- [x] OperationStatus
- [x] ErrorTypes
- [x] MessageTypes
- [x] LogLevel
- [x] 驗證工具函數

**關鍵檔案**：`src/core/enums/`

---

### FR-06: 效能監控

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：效能指標收集和異常偵測。

**已實作元件**：

- [x] MetricsCollector 指標收集器
- [x] PerformanceAssessment 效能評估
- [x] 異常偵測機制

**關鍵檔案**：`src/core/performance/`

---

### FR-07: 資料遷移

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 狀態 | [x] 已實作 |

**描述**：自動遷移和驗證機制，支援進度追蹤。

**已實作元件**：

- [x] AutoMigrationConverter
- [x] MigrationValidator
- [x] StandardErrorWrapper
- [x] 遷移進度追蹤

**關鍵檔案**：`src/core/migration/`

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-03-30 | 從 app-requirements-spec.md 遷移，盤點實作狀態 |
