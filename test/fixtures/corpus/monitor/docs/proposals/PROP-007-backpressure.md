---
id: PROP-007
title: "Ingestion 背壓與 Rate Limiting"
status: draft
source: development
proposed_by: "production 穩定性需求"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.3.0
priority: P1
evaluation_level: standard

outputs:
  spec_refs:
    - spec/collector/backpressure.md
  usecase_refs: [UC-01]
  ticket_refs: []

related_proposals: [PROP-001, PROP-002, PROP-003]
supersedes: null
---

# PROP-007: Ingestion 背壓與 Rate Limiting

## 需求來源

教學模組四 [Ingestion Scaling](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/ingestion-scaling.md) 定義了四層防線架構。當多個 SDK 同時 flush 或單一 SDK 有 bug（無限迴圈送事件）時，collector 需要保護自己不被壓垮。PROP-001 的 MVP 用 SQLite 的 `busy_timeout` 作為最小保護，本提案實作教學定義的第二層防線。

教學依據：
- [模組四：Ingestion Scaling](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/ingestion-scaling.md) — 四層防線、channel 背壓、per-SDK rate limit、error 快通道、429 回應
- [模組四：端到端資料完整性](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/data-integrity.md) — SDK 自監控指標、circuit breaker、init jitter、損失率閾值
- [模組三：攢批送出策略](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md) — SDK 對 503/429 的處理行為

## 問題描述

PROP-001 的 collector 直接從 HTTP handler 寫入 SQLite，無背壓保護。多 SDK 同時 flush 時可能觸發 `database is locked`，單一 SDK bug 送出大量事件時可能耗盡 collector 資源。

## 範圍界定

### 本提案要做的（In Scope）

**寫入 channel pattern**（教學第二層核心）：

1. HTTP handler → Go channel → single-writer goroutine → SQLite
   - Channel 容量可設定（預設 10,000）
   - Channel 滿時 HTTP handler 回 429 + `Retry-After` header
   - Single-writer 避免 SQLite write lock 競爭

**Per-SDK rate limiting**：

2. 按 `source.app` 限制每個 SDK 實例的請求速率
   - 預設 100 events/sec per app
   - 超過時回 429
   - Rate limiter 可設定（config.yaml）

**Error 快通道**：

3. `type: "error"` 的事件不經 rate limit
   - 獨立 channel 或跳過 rate limiter check
   - Error 的 debug 價值最高，error storm 時更需要記錄

**429 回應格式**：

4. SDK 端配合（SPEC-006/008/009 已定義 SDK 對 429 的行為）

```json
{
  "error": "rate limit exceeded",
  "retry_after": 5
}
```

**Circuit breaker**（教學 data-integrity「SDK bug 事件風暴」段）：

5. 某 API key 的 429 回應次數超過閾值 → 暫時拒絕該 key 所有請求（回 503）
   - 冷卻期後自動恢復
   - 閾值需高於正常 burst 的 per-key 429 頻率（5N-10N 倍校標）
   - 降低 rate limit 本身的 CPU 開銷（高頻 429 回應也有成本）

**SDK 自監控指標**（教學 data-integrity「監控損失本身的方法」段 + event-schema-fields「SDK 自監控指標」段）：

6. SDK 端指標：`sdk.events.produced/sampled/sent/dropped`、`sdk.flush.failures`、`sdk.sampling.rate`
   - 指標作為 metric 類事件，每次 flush 成功後一起送出
   - Collector 端指標：`collector.events.received/rejected/stored/backpressure`、`collector.channel.depth`
   - 透過 `/metrics` endpoint 暴露（或 health endpoint 的擴展欄位）

**Init jitter**（教學 data-integrity「部署推送」段）：

7. SDK 初始化後首次 flush 加隨機延遲（0 到 flush_interval 的均勻分佈）
   - 離線補發批次間加 jitter（1-3 秒隨機）
   - 防止多 SDK 同時啟動時的補發風暴
   - 此項為 SDK 端行為，需同步更新 SDK spec（SPEC-006/008/009）

### 本提案不做的（Out of Scope）

- SDK 端動態取樣（第一層，在 SDK 端實作，觸發訊號是 429）
- 水平擴展（第三層，需先有 PostgreSQL backend）
- Queue 解耦（第四層，Kafka/NATS）
- Per-API-key rate limiting（需先有認證系統）

## 驗收條件

- [ ] 寫入走 channel pattern：HTTP handler 不直接寫 SQLite
- [ ] Channel 滿時回 429 + Retry-After header
- [ ] 同時 5 個 SDK flush（模擬）不出現 `database is locked`
- [ ] Per-SDK rate limit：單一 app 超過 100 events/sec 時被限流
- [ ] Error 事件不被 rate limit 阻擋
- [ ] Rate limit 設定可在 config.yaml 調整
- [ ] **壓測驗證**：1000 events/sec 持續 30 秒，collector 不 crash、不 OOM、429 正常回應
- [ ] Circuit breaker：某 key 連續 50 次 429 後被暫時拒絕（回 503）、5 分鐘後自動恢復
- [ ] SDK 自監控指標：flush 成功後可在 collector 查到 `sdk.events.*` metric 事件
- [ ] Collector 完整性指標：`/metrics` endpoint 回傳 received/rejected/stored/backpressure 計數
- [ ] Init jitter：100 個模擬 SDK 同時啟動，首次 flush 在 0-30 秒內分散

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Channel buffer 記憶體 | 10K events × 1KB = 10MB | 可接受；超大事件用 max event size 限制 |
| 429 造成 SDK 事件丟失 | 部分事件未被收集 | SDK 保留 buffer + 重試；教學已定義 SDK 端行為 |
| Error 快通道被 error storm 濫用 | Error channel 也滿 | Error channel 容量獨立設定；極端情況 error 也 FIFO 丟棄 |
| Circuit breaker 誤觸 | 正常 burst 被封鎖 | 閾值設為正常 burst 的 5-10 倍 |
| Init jitter 延遲首筆事件 | 啟動後 0-30 秒才送出 | 自用場景可接受 |
