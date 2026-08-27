---
id: SPEC-013
title: "Collector 背壓與 Rate Limiting（Backpressure）"
status: draft
source_proposal: PROP-007
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"
owner: ""

domain: collector
subdomain: ingestion

related_usecases: [UC-01]
related_specs: [SPEC-002, SPEC-007]
implements_requirements: []
depends_on_domains: [core]
---

# Collector 背壓與 Rate Limiting（Backpressure）

## 概述

定義 collector ingestion 端的流量保護機制：寫入 channel pattern（背壓）、per-SDK rate limiting、error 快通道、429 回應格式。本 Spec 實作教學四層防線的第二層，取代 SPEC-002 NFR-01 的 MVP busy timeout 策略。

教學依據：[模組四：Ingestion Scaling](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/ingestion-scaling.md)

## 功能需求

### FR-01: 寫入 Channel Pattern

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-007 |
| 對應用例 | UC-01 |

**描述**：HTTP handler 不直接寫入 SQLite，改經 Go channel 傳遞給 single-writer goroutine。Single-writer goroutine 從 channel 讀取事件並呼叫 `BasicStorage.Store()`，消除 SQLite write lock 競爭。

**處理鏈路變更**：

```
v0.2.0: HTTP handler → Schema 驗證 → SQLite（直接寫入）
v0.3.0: HTTP handler → Schema 驗證 → writeCh → single-writer goroutine → SQLite
```

**Channel 設定**：

| 參數 | 預設值 | 說明 |
|------|--------|------|
| `ingestion.channel_size` | 10000 | 主寫入 channel 容量 |
| `ingestion.error_channel_size` | 1000 | Error 快通道 channel 容量 |

**Channel 滿時行為**：HTTP handler 使用 `select` 非阻塞送入。Channel 滿時立即回 429，不等待。

```go
select {
case writeCh <- events:
    // 成功送入 channel，回 202 Accepted
default:
    // channel 滿，回 429
}
```

**記憶體預算**：10,000 筆 x ~1KB/筆 = ~10MB。可透過設定調整 `channel_size`。

**驗收標準**：

- [ ] HTTP handler 不直接呼叫 `BasicStorage.Store()`
- [ ] 事件經 Go channel 傳遞給 single-writer goroutine
- [ ] Channel 滿時回 429（非阻塞）
- [ ] 同時 5 個 SDK flush 不出現 `database is locked`

### FR-02: Per-SDK Rate Limiting

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-007 |
| 對應用例 | UC-01 |

**描述**：按 `source.app` 欄位限制每個 SDK 實例的事件速率。防止單一 SDK 的 bug（無限迴圈送事件）耗盡 collector 資源。Rate limiter 在 channel 送入之前檢查。

**處理順序**：

```
HTTP request → Schema 驗證 → Rate limit 檢查 → Channel 送入 → Single-writer → SQLite
```

**Rate limit 設定**：

| 參數 | 預設值 | 說明 |
|------|--------|------|
| `rate_limit.default_rate` | 100 | 每個 source.app 的預設速率（events/sec） |
| `rate_limit.per_app` | {} | 個別 app 覆蓋設定 |

**Config 範例**：

```yaml
rate_limit:
  default_rate: 100          # events/sec per app
  per_app:
    "debug-tool": 500        # 放寬 debug 工具的限制
    "load-test": 10          # 限制測試工具
```

**Rate limiter 實作**：每個 `source.app` 維護一個 token bucket rate limiter。首次見到的 app 自動建立 limiter（使用 `default_rate`）。

**source.app 為空時**：使用固定 key `"_unknown"` 共用一個 limiter，套用 `default_rate`。

**超過速率時**：回 429 + `Retry-After` header。

**驗收標準**：

- [ ] 單一 app 超過設定速率時回 429
- [ ] 不同 app 的 rate limit 獨立計算
- [ ] `per_app` 覆蓋生效
- [ ] source.app 為空時歸入 `_unknown` limiter

### FR-03: Error 快通道

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-007 |
| 對應用例 | UC-01 |

**描述**：`type: "error"` 的事件不經 rate limit 檢查，且使用獨立的 error channel。Error 事件的 debug 價值最高，error storm 時更需要記錄。

**處理順序**：

```
HTTP request → Schema 驗證 → type == "error"?
    是 → errorCh（獨立 channel）→ single-writer → SQLite
    否 → Rate limit 檢查 → writeCh → single-writer → SQLite
```

**批次事件中混合 error 和非 error**：逐筆分流。Error 事件走 errorCh，非 error 事件走 rate limit + writeCh。同一批次可能部分成功部分失敗（error 事件送入成功但非 error 事件被 rate limit 擋住）。

**Error channel 滿時**：Error 也回 429。極端 error storm 時 collector 仍需保護自己。

**驗收標準**：

- [ ] `type: "error"` 事件不受 per-SDK rate limit 限制
- [ ] Error 事件使用獨立 channel
- [ ] 非 error 事件被 rate limit 時，同批次的 error 事件仍被接收
- [ ] Error channel 滿時回 429

### FR-04: 429 Response Format

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-007 |
| 對應用例 | UC-01 |

**描述**：Rate limit 和 channel 背壓觸發時，回 HTTP 429 Too Many Requests。與既有 503 Service Unavailable 區分——429 表示 client 端的請求速率問題，503 表示 server 端的 storage 問題。

**429 與 503 區分**：

| 狀態碼 | 觸發條件 | 語意 | SDK 行為 |
|--------|---------|------|---------|
| 429 Too Many Requests | Rate limit 超過 / Channel 滿 | Client 端速率過高 | 保留 buffer，等 `Retry-After` 後重試；可觸發動態取樣降速 |
| 503 Service Unavailable | SQLite busy timeout / Storage 異常 | Server 端暫時不可用 | 保留 buffer，等 `retry_after` 後重試 |

**429 Response body**：

```json
{
  "error": "rate limit exceeded",
  "retry_after": 5
}
```

**429 Response header**：

| Header | 值 | 說明 |
|--------|-----|------|
| `Retry-After` | 整數秒 | RFC 7231 標準 header |
| `X-RateLimit-Limit` | 整數 | 該 app 的速率上限（events/sec） |
| `X-RateLimit-Remaining` | 整數 | 剩餘可用額度 |

**`retry_after` 計算**：

| 觸發原因 | `retry_after` 值 |
|---------|-----------------|
| Per-SDK rate limit | 1 秒（token bucket 每秒補充） |
| 主 channel 滿 | 5 秒（等 single-writer 消化） |
| Error channel 滿 | 5 秒 |

**Channel 滿觸發的 429 body**：

```json
{
  "error": "backpressure: write channel full",
  "retry_after": 5
}
```

**驗收標準**：

- [ ] Rate limit 觸發時回 429（非 503）
- [ ] Channel 滿觸發時回 429（非 503）
- [ ] Response body 含 `error` 和 `retry_after`
- [ ] Response header 含 `Retry-After`
- [ ] Rate limit 觸發時額外含 `X-RateLimit-Limit` 和 `X-RateLimit-Remaining`

## 非功能需求

### NFR-01: 壓測基準

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | 1000 events/sec 持續 30 秒 |

**描述**：Collector 在預設設定下承受 1000 events/sec 持續 30 秒的壓測，期間：

| 指標 | 要求 |
|------|------|
| 不 crash | 進程存活 |
| 不 OOM | RSS 不超過 200MB |
| 429 正常回應 | 超過 rate limit 的請求收到 429 |
| 恢復 | 壓測結束後 10 秒內恢復正常接收 |

**壓測方式**：用 Go benchmark 或 `hey` / `vegeta` 等工具模擬多 SDK 同時 flush。

**驗收標準**：

- [ ] 1000 events/sec x 30s 不 crash
- [ ] RSS < 200MB
- [ ] 超過 rate limit 時正確回 429
- [ ] 壓測結束後 10 秒內恢復

### NFR-02: Graceful Shutdown 不丟事件

| 項目 | 值 |
|------|-----|
| 類型 | 可靠性 |

**描述**：Collector 收到 SIGTERM/SIGINT 時，先停止接收新請求，再 drain channel 中待處理事件寫入 storage 後才退出。

**驗收標準**：

- [ ] Shutdown 時 channel 中的事件全部寫入 storage
- [ ] Shutdown 後新請求回 503

## Config 擴充

本 Spec 在 SPEC-007 FR-04 的 `collector.yaml` 新增以下區塊：

```yaml
# collector.yaml（v0.3.0 擴充）
ingestion:
  channel_size: 10000        # 主寫入 channel 容量
  error_channel_size: 1000   # Error 快通道 channel 容量

rate_limit:
  default_rate: 100          # events/sec per app
  per_app: {}                # 個別 app 覆蓋（key: app name, value: rate）
```

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Single-writer goroutine | 只有一個 goroutine 寫入 SQLite | 消除 write lock 競爭，吞吐受限於單 goroutine |
| Token bucket rate limiter | 使用 `golang.org/x/time/rate` 或等效實作 | 標準 Go 生態，不引入外部依賴 |
| Error 快通道獨立 channel | Error 和一般事件分流 | Error storm 極端情況仍可能滿載 |

## 與其他 Spec 的關係

| Spec | 關係 |
|------|------|
| SPEC-002 Ingestion | 本 Spec 取代 NFR-01 的 busy timeout 策略。SPEC-002 NFR-01 降級為 fallback（channel pattern 之後 single-writer 仍保留 busy timeout 作最後防線） |
| SPEC-007 Internal Architecture | 本 Spec 擴充 FR-04 Config 結構（新增 `ingestion` 和 `rate_limit` 區塊）；FR-05 五段鏈路在 Schema 驗證和 Storage 寫入之間插入 channel 層 |
| transport.md | 新增 429 response format（見 transport.md 同步更新） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從教學 ingestion-scaling.md + PROP-007 萃取 |
