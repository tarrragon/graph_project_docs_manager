# 功能規格（Spec）

正式功能規格文件目錄。依 **Domain** 組織，每個 domain 子目錄包含該領域的所有規格。

> **設計原則**：Spec 是 domain knowledge 的載體。依 domain 組織可降低理解業務知識的心智負擔，在功能擴充或大型重構時，快速定位到正確的 domain 規格。

## Domain 地圖

| Domain | 子目錄 | 核心責任 | 依賴 |
|--------|--------|---------|------|
| core | `core/` | 資料模型、錯誤處理、事件系統 | 無（被所有 domain 依賴） |
| extraction | `extraction/` | 從網頁提取書籍資料 | core, platform, messaging |
| platform | `platform/` | 平台偵測、適配器管理 | core |
| data-management | `data-management/` | 儲存、匯入匯出、同步 | core |
| messaging | `messaging/` | 跨 context 通訊 | core |
| page | `page/` | 頁面偵測、Content Script | core, messaging |
| system | `system/` | 生命週期、健康監控 | core |
| user-experience | `user-experience/` | UI、搜尋、篩選 | core, data-management |
| analytics | `analytics/` | 閱讀統計分析（v2.0+） | core, data-management |
| security | `security/` | 資料隱私保護（v2.0+） | core |

## 使用方式

建立新規格時：

1. 確定所屬 domain
2. 從 Skill 模板複製到對應的 domain 子目錄
3. 填寫 frontmatter（特別是 `domain` 和 `subdomain` 欄位）

```bash
cp .claude/skills/doc/templates/spec-template.md docs/spec/extraction/extraction-pipeline.md
```

> 模板規範和欄位說明見 `.claude/skills/doc/references/spec.md`

### 模板核心欄位

| frontmatter 欄位 | 用途 |
|-----------------|------|
| `id` | 規格 ID（SPEC-NNN） |
| `domain` | 所屬 domain（必填） |
| `subdomain` | 子領域（如有） |
| `source_proposal` | 來源提案 ID |
| `related_usecases` | 對應的用例清單 |
| `depends_on_domains` | 依賴的其他 domain |

### 正文結構

| 章節 | 必填 | 說明 |
|------|------|------|
| 概述 | 是 | 一段話描述範圍和目的 |
| 功能需求（FR） | 是 | 各需求項，含優先級、來源、驗收標準 |
| 非功能需求（NFR） | 否 | 效能、安全性等非功能要求 |
| 資料模型 | 否 | 資料結構和欄位定義 |
| 介面規格 | 否 | API、事件等介面定義 |
| 錯誤處理 | 否 | 錯誤場景和處理方式 |
| 變更歷史 | 是 | 規格版本變更記錄 |

## Domain 與 UseCase 交叉引用

UseCase 是跨 domain 的使用場景，一個 UC 可能涉及多個 domain：

| UC | 涉及 Domain | 主要 Domain |
|----|------------|------------|
| UC-01 匯入 | extraction, data-management, platform | data-management |
| UC-02 匯出 | data-management, user-experience | data-management |
| UC-03 ISBN 掃描 | extraction, data-management | extraction |
| UC-04 搜尋補充 | extraction, data-management | extraction |
| UC-05 書庫展示 | user-experience, data-management, page | user-experience |
| UC-06 借閱管理 | data-management, user-experience | data-management |
| UC-07 跨平台同步 | data-management, platform | data-management |
| UC-08 錯誤處理 | system, core | system |

## 規格索引

| ID | Domain | 規格名稱 | 狀態 | 完成度 |
|----|--------|---------|------|--------|
| SPEC-001 | core | [核心系統](core/core-systems.md) | approved | 7/7 (100%) |
| SPEC-002 | extraction | [資料提取流程](extraction/extraction-pipeline.md) | approved | 3/3 (100%) |
| SPEC-003 | platform | [平台管理](platform/platform-management.md) | approved | 2/3 (FR-03 暫置) |
| SPEC-004 | data-management | [資料管理](data-management/data-management.md) | approved | 5/7 (FR-06 部分, FR-07 未實作) |
| SPEC-005 | messaging | [通訊管理](messaging/message-routing.md) | approved | 1/1 (100%) |
| SPEC-006 | page | [頁面管理](page/page-management.md) | approved | 1/1 (100%) |
| SPEC-007 | system | [系統管理](system/system-management.md) | approved | 2/2 (100%) |
| SPEC-008 | user-experience | [用戶體驗](user-experience/user-experience.md) | approved | 5/5 (100%) |
| SPEC-009 | synchronization | [QR Frame Format](synchronization/SPEC-009-qr-frame-format.md) | approved | 跨平台協議 |

**整體完成度**：26/29 功能需求已實作（~90%）

### Domain Map 索引

| Domain | Domain Map | Source Specs |
|--------|-----------|-------------|
| core | [domain-map](core/domain-map.md) | SPEC-001 |
| data-management | [domain-map](data-management/domain-map.md) | SPEC-004, SPEC-STORAGE-ISOLATION, SPEC-010 |
| extraction | [domain-map](extraction/domain-map.md) | SPEC-002, SPEC-002a |
| messaging | [domain-map](messaging/domain-map.md) | SPEC-005 |
| page | [domain-map](page/domain-map.md) | SPEC-006 |
| platform | [domain-map](platform/domain-map.md) | SPEC-003 |
| synchronization | [domain-map](synchronization/domain-map.md) | SPEC-009 |
| system | [domain-map](system/domain-map.md) | SPEC-007 |
| user-experience | [domain-map](user-experience/domain-map.md) | SPEC-008 |

### 未完成項目摘要

| 項目 | Domain | 狀態 | 說明 |
|------|--------|------|------|
| FR-03 多平台隔離 | platform | 刻意暫置 | 程式碼已寫但 v1.0 不啟用 |
| FR-06 跨設備同步 | data-management | 部分實作 | 策略處理和重試機制簡化 |
| FR-07 備份恢復 | data-management | 未實作 | 協調器中標記但未實作 |

## 保留項目

以下檔案為 Flutter APP 規格，暫不遷移，待獨立專案處理：

- `../app-requirements-spec.md` — Flutter APP 需求規格（含 Extension 共用部分）
- `../app-error-handling-design.md` — Flutter APP 錯誤處理設計
- `../app-use-cases.md` — Flutter APP 用例（UC-01 ~ UC-08）
