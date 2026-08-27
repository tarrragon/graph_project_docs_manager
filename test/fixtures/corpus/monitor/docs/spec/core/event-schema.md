---
id: SPEC-001
title: "事件格式契約（Event Schema）"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.1"
owner: ""

domain: core
subdomain: null

related_usecases: [UC-01, UC-02, UC-03]
related_specs: [SPEC-002, SPEC-004, SPEC-007]
implements_requirements: []
depends_on_domains: []
---

# 事件格式契約（Event Schema）

## 概述

定義跨平台統一的監控事件格式。`schema/event.schema.json` 是所有 SDK 和 collector 共用的契約 SOT（Single Source of Truth）。任何欄位變更必須先改 schema，再同步更新 collector 驗證邏輯和各 SDK 的事件建構。

教學依據：[模組二：Log Schema 設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/02-log-schema/_index.md)

## 功能需求

### FR-01: 四類事件分類

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：所有事件必須歸入四類之一：`event`（行為事件）、`error`（錯誤回報）、`metric`（效能指標）、`lifecycle`（生命週期）。`type` 欄位為必填，值限定為這四個 enum。

**驗收標準**：

- [ ] collector 拒絕 `type` 不在 enum 中的事件
- [ ] 四類事件各有至少一個測試案例通過 schema 驗證

### FR-02: 必填欄位驗證

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：每筆事件必須包含 `v`、`type`、`name`、`timestamp`、`source` 五個必填欄位。`source` 內 `sdk` 和 `platform` 為必填子欄位。

**約束條件**：

- `v` 為整數，目前固定值 1
- `timestamp` 為 ISO 8601 UTC 格式
- `source.sdk` 限定為 `js` / `flutter` / `python` / `go`

**驗收標準**：

- [ ] 缺少任一必填欄位的事件被 collector 拒絕（400）
- [ ] `timestamp` 格式錯誤被拒絕

### FR-03: 自由欄位 data

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-02 |

**描述**：`data` 欄位為選填的 JSON object，內容由事件發送端定義。Schema 只驗證型別為 object，不驗證內部結構。

**驗收標準**：

- [ ] 含任意結構 `data` 的事件通過驗證
- [ ] `data` 為非 object 型別時被拒絕

### FR-04: 錯誤詳情 error 欄位

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-03 |

**描述**：`type=error` 的事件應包含 `error` 欄位，含 `message`、`stack`、`type` 三個子欄位（皆選填）。

**驗收標準**：

- [ ] error 類型事件含 error 欄位時正確儲存
- [ ] error 欄位缺少時仍接受（選填）

## 資料模型

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| v | integer | 是 | Schema 版本，固定值 1 |
| type | string (enum) | 是 | event / error / metric / lifecycle |
| timestamp | string (date-time) | 是 | ISO 8601 UTC |
| source | object | 是 | 事件來源識別 |
| source.sdk | string (enum) | 是 | js / flutter / python / go |
| source.platform | string | 是 | ios / android / web / macos / linux / script |
| source.app | string | 否 | 應用程式名稱 |
| source.version | string | 否 | 應用程式版本 |
| source.os | string | 否 | OS 版本（如 17.4、14、25.5.0） |
| name | string | **是** | 事件名稱（namespace.action 格式） |
| level | string (enum) | 否 | debug / info / warn / error / fatal（預設 info） |
| data | object | 否 | 附帶結構化資料 |
| error | object | 否 | 錯誤詳情（message / stack / type） |
| session | object | 否 | 使用者 session 識別 |
| session.id | string | 否 | Session ID（UUID v7，同次使用的事件共用） |
| session.started | string (date-time) | 否 | Session 開始時間（ISO 8601） |
| batch_id | string | 否 | 批次 ID |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Schema 是 SOT | 任何欄位變更必須先改 schema 再同步消費端 | collector + 所有 SDK |
| 版本演進用 v 欄位 | 不做 breaking change，新版本新增欄位為選填 | 向後相容性 |
| name 用 namespace.action 格式 | 查詢和 rule engine 靠 name 做過濾 | SDK 事件命名規範 |
| UUID 統一用 v7 | session_id 和 batch_id 皆用 UUID v7（Python `uuid.uuid7()`、Go `google/uuid`）。教學中 session_id 用 v4 是針對商業產品的隱私考量，自用工具場景不適用，統一 v7 簡化實作且 DB B-tree 插入效能更好 | 所有 SDK |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本，從 blog 模組二萃取 |
| 1.1 | 2026-06-22 | Schema 對齊教學：name 改必填、source 補 os、context 改為頂層 session（WRAP 決策） |
| 1.1 | 2026-06-22 | 補 context.session_id；UUID 統一用 v7（自用工具場景決策） |
