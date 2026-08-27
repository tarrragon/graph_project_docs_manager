---
id: PROP-008
title: "PostgreSQL Storage Backend — 可插拔儲存架構"
status: draft
source: development
proposed_by: "規模演進需求"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.4.0
priority: P2
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: [PROP-001, PROP-005]
supersedes: null
---

# PROP-008: PostgreSQL Storage Backend — 可插拔儲存架構

## 需求來源

教學模組四 [規模演進](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md) 定義了可插拔 Storage Backend 架構。SQLite 是 day-one 預設，PostgreSQL 在觀察到寫入爭搶或聚合效能不足時切換。切換是 config change 而非程式碼重寫——Storage interface 保證 ingestion、query、rule engine 不需改動。

教學依據：
- [模組四：規模演進](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md) — BasicStorage / AnalyticsStorage interface、SQLite → PostgreSQL 切換流程、觸發條件
- [模組四：功能分層與 Backend 選擇](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/feature-tier-boundary.md) — SQLite 層 vs PostgreSQL 層能力差異
- [模組四：JSONL 匯出](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/jsonl-storage.md) — 遷移中介格式

## 問題描述

PROP-001 的 collector 直接依賴 SQLite 實作。Storage 層未抽象為 interface，無法在不改動業務邏輯的情況下切換 backend。本提案分兩步：(1) 重構 Storage 為 interface，(2) 實作 PostgreSQL backend。

## 範圍界定

### 本提案要做的（In Scope）

**Storage Interface 抽象**：

1. 定義 `BasicStorage` interface（教學定義）

```go
type BasicStorage interface {
    Store(event Event) error
    Query(filter QueryFilter) ([]Event, error)
    Close() error
    Downsample() error
    Purge() error
}
```

2. 定義 `AnalyticsStorage` interface（PostgreSQL 層新增）

```go
type AnalyticsStorage interface {
    BasicStorage
    Aggregate(spec AggregateSpec) (AggregateResult, error)
    Funnel(steps []string, timeWindow time.Duration) (FunnelResult, error)
    Cohort(groupBy string, metric string) (CohortResult, error)
}
```

3. 重構現有 SQLite 程式碼為 `BasicStorage` implementation

**PostgreSQL Implementation**：

4. 實作 `AnalyticsStorage` interface
   - Events 表 DDL（`data` 欄位改用 JSONB）
   - 並行寫入（連線池，無 single-writer 限制）
   - JSONB 索引（`CREATE INDEX ON events ((data->>'name'))`）
   - Downsample + Purge（與 SQLite 相同邏輯，SQL 語法適配）

**啟動參數**：

5. `--storage=sqlite`（預設）/ `--storage=postgres --dsn=postgres://...`

### 本提案不做的（Out of Scope）

- 時間序列 DB backend（TimescaleDB，教學標為長期演進）
- Read replica 設定（PostgreSQL 進階部署）
- 自動切換（觀察到瓶頸時手動切換）
- SQLite → PostgreSQL 資料遷移工具（兩者為獨立部署模式，使用者選一個即可。舊資料留在 SQLite 自然過期，真有需求再建提案）
- Dashboard 的 Funnel / Cohort 視圖（依賴 AnalyticsStorage，但 UI 另建提案）

## 驗收條件

- [ ] `BasicStorage` interface 定義，SQLite 和 PostgreSQL 皆實作
- [ ] `AnalyticsStorage` interface 定義，PostgreSQL 實作 Aggregate / Funnel / Cohort
- [ ] `--storage=sqlite` 啟動行為與重構前一致（不破壞 PROP-001）
- [ ] `--storage=postgres --dsn=...` 啟動成功，ingestion + query 正常
- [ ] PostgreSQL 下多連線同時寫入不 lock
- [ ] JSONB `data` 欄位可用 `data->>'key'` 查詢
- [ ] Dashboard 能力偵測：SQLite 下 funnel/cohort 不顯示；PostgreSQL 下顯示

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Interface 抽象過度 | 開發複雜度增加 | 教學已定義最小 interface，不過度泛化 |
| PostgreSQL 運維成本 | 使用者需管理外部 DB | 文件明確指引；SQLite 仍是推薦起點 |

## 討論記錄

### 2026-06-22

- 教學明確指出「按觀察到的瓶頸切換，不按預測行動」
- 本提案版本排在 v0.4.0（需 PROP-001 collector 穩定 + PROP-005 JSONL 匯出 + PROP-007 背壓）
- Storage interface 設計依教學定義的 BasicStorage + AnalyticsStorage 二層
