---
id: SPEC-003
title: "Collector 查詢 API（Query）"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.2"
owner: ""

domain: collector
subdomain: query

related_usecases: [UC-01, UC-03]
related_specs: [SPEC-001, SPEC-004]
implements_requirements: []
depends_on_domains: [core]
---

# Collector 查詢 API（Query）

## 概述

Collector 五段處理鏈路的第四段：透過 HTTP endpoint 查詢已儲存的事件。MVP 提供按 type / name / time range 篩選，支援 Error 列表（按 name 分群）和事件時間軸兩種視圖。

教學依據：[模組四：查詢 API 設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/query-api.md)

## 功能需求

### FR-01: 基本篩選查詢

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01, UC-03 |

**描述**：`GET /v1/events` 支援以下查詢參數：

教學依據：[查詢 API 設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/query-api.md)

| 參數 | 型別 | 說明 | 預設值 |
|------|------|------|--------|
| type | string | 篩選事件類型（event / error / metric / lifecycle） | 全部 |
| name | string | 篩選事件名稱（支援 `*` 萬用字元，如 `hook.*`） | 全部 |
| from | string (date-time) | 時間範圍起點 | 24 小時前 |
| to | string (date-time) | 時間範圍終點 | 現在 |
| limit | integer | 回傳筆數上限 | 100 |
| offset | integer | 分頁偏移 | 0 |

`name` 的 `*` 萬用字元在 SQLite 實作中轉為 SQL `LIKE`（`*` → `%`）。

**驗收標準**：

- [ ] 按 type 篩選只回傳對應類型事件
- [ ] 按 name 萬用字元（`hook.*`）回傳所有 `hook.` 開頭的事件
- [ ] 按 time range 篩選回傳範圍內事件
- [ ] 多參數可組合篩選
- [ ] 無篩選參數時預設回傳最近 24 小時、上限 100 筆

### FR-02: Error 列表（按 name 分群）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-03 |

**描述**：`GET /v1/events/summary?type=error&group_by=name` 回傳 error 按 name 分群的摘要，含每個 name 的出現次數和最近一次發生時間。summary endpoint 支援和逐筆查詢相同的篩選參數（type、name、from、to），額外的 `group_by` 指定分群欄位。

教學依據：[查詢 API 設計 — 聚合查詢](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/query-api.md)

**驗收標準**：

- [ ] 回傳 JSON 陣列，每項含 name / count / last_seen
- [ ] 按 count 降序排列

### FR-03: 事件時間軸

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：`GET /v1/events` 不帶篩選參數時，回傳最近 24 小時內的事件（按 timestamp 降序，上限 100 筆）。等同事件時間軸視圖。

**驗收標準**：

- [ ] 無篩選參數時回傳最近 24 小時內、最多 100 筆事件
- [ ] 按 timestamp 降序排列

## 介面規格

完整 request/response 規格見 `docs/transport.md`「GET /v1/events」和「GET /v1/events/summary」段。以下為摘要：

### GET /v1/events response

```json
{
  "events": [ ... ],
  "total": 42,
  "limit": 100,
  "offset": 0
}
```

- `events`：事件陣列，按 `timestamp` 降序
- `total`：符合篩選條件的全量筆數（分頁計算用）

### GET /v1/events/summary response

```json
{
  "groups": [
    { "name": "hook.failure", "count": 15, "last_seen": "2026-06-19T08:42:00Z" }
  ],
  "total": 18,
  "from": "...",
  "to": "..."
}
```

- `groups`：按 `group_by` 分群，按 `count` 降序

## 非功能需求

### NFR-01: 查詢效能

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | 10 萬筆內有索引查詢 < 100ms |

**描述**：SQLite 建立 type + timestamp 複合索引。教學預期值為 < 100ms，實測偏差 > 2 倍須回補教學。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
| 1.1 | 2026-06-22 | 端點路徑改為 /v1/events（對齊教學）；name 萬用字元語法明確化；summary 端點泛化為 /v1/events/summary |
| 1.2 | 2026-06-22 | 新增介面規格段（response format），引用 transport.md |
