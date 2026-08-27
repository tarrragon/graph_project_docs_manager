---
id: SPEC-002
title: "Collector 事件接收（Ingestion）"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.3"
owner: ""

domain: collector
subdomain: ingestion

related_usecases: [UC-01, UC-02]
related_specs: [SPEC-001, SPEC-003]
implements_requirements: []
depends_on_domains: [core]
---

# Collector 事件接收（Ingestion）

## 概述

Collector 五段處理鏈路的前兩段：HTTP endpoint 接收 + JSON Schema 驗證。接收 SDK 送來的單筆或批次事件，驗證後傳給儲存層。

教學依據：[模組四：Collector 架構](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/architecture.md)

## 功能需求

### FR-01: 單筆事件接收

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：`POST /v1/events` 接受單筆 JSON 事件。依 `schema/event.schema.json` 驗證，通過回傳 200，失敗回傳 400 含錯誤描述。

**驗收標準**：

- [ ] 合法單筆事件回傳 200
- [ ] 缺必填欄位回傳 400 含具體欄位名

### FR-02: 批次事件接收

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：`POST /v1/events` 接受批次格式（`{ "batch_id": "...", "events": [...] }`）。逐一驗證每筆事件，部分失敗回傳 207 含 errors 陣列。

**驗收標準**：

- [ ] 全部合法回傳 200
- [ ] 部分不合法回傳 207，body 含 errors 陣列標明哪些事件失敗
- [ ] 全部不合法回傳 400

### FR-03: Health endpoint

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：`GET /health` 回傳 collector 狀態，含 uptime、事件計數、儲存大小。

**驗收標準**：

- [ ] 回傳 JSON 含 status、uptime_seconds、total_events、storage_bytes、version
- [ ] collector 啟動後立即可查

## 非功能需求

### NFR-01: 併發寫入

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | SQLite busy timeout 5 秒內不回傳 503 |

**描述**：多個 SDK 同時 flush 時，SQLite busy timeout fallback 處理併發。超時回傳 503，SDK 端 buffer 重試。MVP 不使用 channel pattern。

### NFR-02: CORS 支援

| 項目 | 值 |
|------|-----|
| 類型 | 相容性 |
| 來源 | PROP-003（JS SDK 需求） |

**描述**：JS SDK 在瀏覽器環境透過 `fetch` 送事件到 collector。跨域請求需要 collector 回應 CORS header，否則瀏覽器攔截請求。

教學依據：[模組五：JS/TS 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/js-ts-platform.md)

**Collector 需回應的 CORS header**：

| Header | 值 | 說明 |
|--------|-----|------|
| `Access-Control-Allow-Origin` | `*`（MVP）或從 config 指定 origin | 允許跨域存取 |
| `Access-Control-Allow-Methods` | `POST, GET, OPTIONS` | 允許的 HTTP 方法 |
| `Access-Control-Allow-Headers` | `Content-Type` | 允許的請求 header |

**Preflight 處理**：收到 `OPTIONS` 請求時，回 204 + 上述 CORS header，不做任何業務處理。

**驗收標準**：

- [ ] `OPTIONS /v1/events` 回 204 + CORS header
- [ ] `POST /v1/events` response 帶 `Access-Control-Allow-Origin`
- [ ] JS SDK 的 fetch 跨域請求不被瀏覽器攔截

### NFR-03: Content-Type 容錯

| 項目 | 值 |
|------|-----|
| 類型 | 相容性 |
| 來源 | PROP-003（JS SDK sendBeacon 需求） |

**描述**：JS SDK 在頁面關閉時用 `navigator.sendBeacon` 送最後一批事件。sendBeacon 無法自訂 Content-Type header，瀏覽器固定為 `text/plain`（送 string）或 `application/x-www-form-urlencoded`（送 FormData）。Collector 需同時接受 `text/plain` 和 `application/json`，body 統一做 JSON parse。

教學依據：[模組五：JS/TS 平台適配 — sendBeacon 的限制](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/js-ts-platform.md)

**處理邏輯**：

| Content-Type | Collector 行為 |
|-------------|---------------|
| `application/json` | 直接 JSON parse（正常路徑） |
| `text/plain` | 嘗試 JSON parse（sendBeacon 路徑） |
| 其他或缺失 | 嘗試 JSON parse；失敗回 400 |

**驗收標準**：

- [ ] Content-Type: application/json 正常接收
- [ ] Content-Type: text/plain + JSON body 正常接收
- [ ] Content-Type 缺失但 body 是合法 JSON 正常接收
- [ ] Body 不是合法 JSON 回 400

## 介面規格

完整 request/response 規格見 `docs/transport.md`「POST /v1/events」段。以下為摘要：

| 端點 | 方法 | Content-Type | 說明 |
|------|------|-------------|------|
| `/v1/events` | POST | application/json 或 text/plain | 接收單筆或批次事件（text/plain 支援 sendBeacon） |
| `/v1/events` | OPTIONS | - | CORS preflight（回 204 + CORS header） |
| `/health` | GET | - | 健康檢查（response 格式見 transport.md「GET /health」段） |

### Request format

- **單筆**：直接送一個 event JSON object
- **批次**：`{ "batch_id": "...", "events": [...] }`（batch_id 由 SDK 產生，格式見 transport.md）

### Response format 摘要

| 狀態碼 | 觸發條件 | Response body |
|--------|---------|--------------|
| 200 | 單筆成功 / 批次全部成功 | `{ "accepted": N }` |
| 207 | 批次部分失敗 | `{ "accepted": N, "rejected": M, "errors": [{ "index": I, "message": "..." }] }` |
| 400 | 單筆失敗 / JSON 解析錯誤 | `{ "error": "...", "details": [{ "field": "...", "message": "..." }] }` |
| 429 | Rate limit / Channel 背壓（SPEC-013） | `{ "error": "...", "retry_after": N }` |
| 503 | Storage 不可用（SQLite busy timeout） | `{ "error": "...", "retry_after": N }` |

完整 response body JSON 範例見 transport.md。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
| 1.1 | 2026-06-22 | 介面規格段補完整 request/response format 引用（對齊 transport.md） |
| 1.2 | 2026-06-22 | 新增 NFR-02 CORS 支援 + NFR-03 Content-Type 容錯（PROP-003 JS SDK 需求） |
| 1.3 | 2026-06-22 | Response 表新增 429 狀態碼（SPEC-013 背壓），503 限縮為 Storage 不可用 |
