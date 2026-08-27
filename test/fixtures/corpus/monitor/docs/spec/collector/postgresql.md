---
id: SPEC-014
title: "Collector PostgreSQL Storage Backend"
status: draft
source_proposal: PROP-008
created: "2026-06-22"
updated: "2026-07-03"
version: "1.4"
owner: ""

domain: collector
subdomain: storage

related_usecases: [UC-01, UC-03]
related_specs: [SPEC-001, SPEC-004, SPEC-007, SPEC-015]
implements_requirements: []
depends_on_domains: [core]
---

# Collector PostgreSQL Storage Backend

## 概述

定義 PostgreSQL 作為 collector 的 Storage Backend 實作。PostgreSQL backend 實作 `AnalyticsStorage` interface（包含 `BasicStorage` 所有方法 + Aggregate / Funnel / Cohort），提供並行寫入、JSONB 索引和進階 SQL 分析能力。

SQLite 和 PostgreSQL 為**獨立部署模式**——使用者依需求選擇其一，不需要資料遷移。

教學依據：[規模演進](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md)、[功能分層與 Backend 選擇](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/feature-tier-boundary.md)

## 功能需求

### FR-01: PostgreSQL DDL（Events 表）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-008 |
| 對應用例 | UC-01 |

**描述**：PostgreSQL 的 events 表從 SPEC-004 的 SQLite DDL 平移，核心差異為 `data` 欄位改用 JSONB 型別。欄位結構與 SQLite 版本保持一致，確保 `BasicStorage` interface 的 `Store(events []Event)` 和 `Query(filter QueryFilter)` 實作可共用相同的 struct → column 映射邏輯。

教學依據：scaling-evolution.md「PostgreSQL 版本的差異：data 改成 JSONB 型別」

```sql
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    v INTEGER NOT NULL DEFAULT 1,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    ts TIMESTAMPTZ NOT NULL,
    source_sdk TEXT,
    source_app TEXT,
    source_version TEXT,
    source_platform TEXT,
    source_os TEXT,
    session_id TEXT,
    session_started TIMESTAMPTZ,
    level TEXT,
    data JSONB,
    error_message TEXT,
    error_stack TEXT,
    error_type TEXT,
    raw JSONB,
    receive_ts TIMESTAMPTZ,
    batch_id TEXT,
    fingerprint TEXT,
    flags JSONB
);
```

**欄位對齊依據**（v1.1 補齊，對齊 `schema/event.schema.json` 全欄位 + SQLite 實作現況）：

| 欄位 | 來源 | 說明 |
|------|------|------|
| source_os | schema `source.os` | SQLite 版（SPEC-004 資料模型、實作 `constants.go`）已有，本 spec v1.0 漏列 |
| session_started | schema `session.started` | 同上；PostgreSQL 用 TIMESTAMPTZ（與 ts 一致） |
| batch_id | schema `batch_id`（0.3.6-W2-001 wire 契約收斂） | SDK 攢批送出時標記同一批（UUID v7） |
| fingerprint | SPEC-015（collector 端衍生欄位，非 schema 欄位） | Error fingerprint 去重分群；SQLite 實作已有此欄 |
| flags | schema `_flags`（PROP-010 硬耦合前置，0.4.0-W1-011 定形） | Collector 附加的可疑流量標記（`{suspicious, reason}`）；nullable，正常事件不帶值；寫入邏輯屬 v0.5.0 PROP-010，v0.4.0 僅預留欄位 |

**與 SQLite DDL（SPEC-004）的差異**：

| 項目 | SQLite (SPEC-004) | PostgreSQL (本 Spec) | 理由 |
|------|-------------------|---------------------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | BIGSERIAL PRIMARY KEY | PostgreSQL 慣例，支援大量寫入 |
| ts | TEXT (ISO 8601) | TIMESTAMPTZ | 原生時間型別，支援時區和時間運算 |
| data | TEXT (JSON string) | JSONB | 原生索引和查詢（GIN index、`->>` 運算子） |
| raw | TEXT (JSON string) | JSONB | 與 data 一致 |
| receive_ts | TEXT (ISO 8601) | TIMESTAMPTZ | 與 ts 一致 |
| session_started | TEXT (ISO 8601) | TIMESTAMPTZ | 與 ts 一致 |

**Downsample 摘要表**（與 SPEC-004 相同結構，型別適配）：

```sql
CREATE TABLE hourly_summary (
    hour TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    error_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(hour, type, name)
);

CREATE TABLE daily_summary (
    date DATE NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    unique_sessions INTEGER NOT NULL DEFAULT 0,
    UNIQUE(date, type, name)
);
```

**Downsample 實作**（PostgreSQL 語法適配）：

```sql
INSERT INTO hourly_summary (hour, type, name, count, error_count)
SELECT date_trunc('hour', ts), type, name,
       COUNT(*), COUNT(*) FILTER (WHERE type = 'error')
FROM events
WHERE ts >= NOW() - INTERVAL '1 hour'
GROUP BY 1, 2, 3
ON CONFLICT (hour, type, name)
DO UPDATE SET count = EXCLUDED.count, error_count = EXCLUDED.error_count;
```

**Purge 實作**（與 SPEC-004 相同保留期限，PostgreSQL 語法）：

```sql
DELETE FROM events WHERE ts < NOW() - INTERVAL '7 days';
DELETE FROM hourly_summary WHERE hour < NOW() - INTERVAL '90 days';
DELETE FROM daily_summary WHERE date < NOW() - INTERVAL '365 days';
```

PostgreSQL 的 DELETE 不需要 SQLite 的分批策略（`LIMIT 10000`），MVCC 機制下 DELETE 不阻塞讀取。大量刪除時可選用分批策略降低 WAL 壓力，但非 MVP 必要。

**驗收標準**：

- [ ] events 表 DDL 可在 PostgreSQL 14+ 執行成功
- [ ] events 表欄位與 `schema/event.schema.json` 全欄位對齊（含 batch_id、source_os、session_started）
- [ ] `data` 欄位為 JSONB 型別，支援 `data->>'key'` 查詢
- [ ] hourly_summary、daily_summary 表結構與 SPEC-004 功能一致
- [ ] Downsample INSERT ... ON CONFLICT 幂等執行
- [ ] Purge 清除過期資料，不阻塞讀取

### FR-02: JSONB 索引設計

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-008 |
| 對應用例 | UC-01, UC-03 |

**描述**：PostgreSQL 的索引設計分兩層——基礎索引（與 SQLite 對應）和 JSONB 索引（PostgreSQL 獨有能力）。

教學依據：scaling-evolution.md「GIN for JSONB、partial index」、「`CREATE INDEX ON events ((data->>'name'))`」

**基礎索引**（與 SPEC-004 SQLite 版本對應）：

```sql
CREATE INDEX idx_events_type_ts ON events(type, ts);
CREATE INDEX idx_events_session ON events(session_id);
CREATE INDEX idx_events_name ON events(name);
CREATE INDEX idx_events_fingerprint ON events(fingerprint);  -- SPEC-015 error 去重分群查詢
```

**JSONB 索引**：

```sql
-- data 欄位 GIN 索引（支援 @> 包含查詢）
CREATE INDEX idx_events_data_gin ON events USING GIN (data);

-- data 欄位常用 key 的 B-tree 索引（精準查詢比 GIN 快）
CREATE INDEX idx_events_data_name ON events ((data->>'name'));
CREATE INDEX idx_events_data_duration ON events ((data->>'duration_ms'))
    WHERE data->>'duration_ms' IS NOT NULL;
```

**Partial index**（降低索引大小、加速特定查詢）：

```sql
-- error 類型事件的 partial index（error 列表頁常用）
CREATE INDEX idx_events_error_ts ON events(ts DESC)
    WHERE type = 'error';
```

**索引選擇策略**：

| 查詢模式 | 使用的索引 | 說明 |
|---------|----------|------|
| `WHERE type='error' ORDER BY ts DESC` | idx_events_error_ts | Partial index 最佳匹配 |
| `WHERE data @> '{"key":"value"}'` | idx_events_data_gin | JSONB 包含查詢 |
| `WHERE data->>'name' = 'xxx'` | idx_events_data_name | 精準 key 查詢 |
| `WHERE session_id = 'xxx'` | idx_events_session | Session 回放 |
| `WHERE type = ? AND ts BETWEEN ? AND ?` | idx_events_type_ts | 時間範圍 + 類型篩選 |
| `WHERE fingerprint = 'xxx'` | idx_events_fingerprint | Error 分群回查最近實例（SPEC-015） |

**驗收標準**：

- [ ] 基礎索引三支建立成功
- [ ] GIN index 支援 `data @> '{"key":"value"}'` 查詢
- [ ] `data->>'name'` B-tree 索引加速精準查詢
- [ ] Partial index 在 `type='error'` 查詢中被使用（EXPLAIN 確認）

### FR-03: 啟動參數

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-008 |
| 對應用例 | UC-01 |

**描述**：透過啟動參數選擇 PostgreSQL backend。CLI flag 和 YAML config 兩種方式皆支援，CLI flag 覆蓋 config。

教學依據：scaling-evolution.md「`--storage=postgres --dsn=postgres://...`」

**CLI flag**：

| Flag | 型別 | 預設值 | 說明 |
|------|------|--------|------|
| `--storage` | string | `sqlite` | Storage backend（sqlite / postgres） |
| `--dsn` | string | （無） | PostgreSQL 連線字串，`--storage=postgres` 時必填 |

DSN 格式：`postgres://user:password@host:port/dbname?sslmode=disable`

**YAML config**（SPEC-007 FR-04 擴充）：

```yaml
storage:
  backend: "postgres"
  sqlite:
    path: "./data/monitor.db"
    busy_timeout: 5000
  postgres:
    dsn: "postgres://monitor:password@localhost:5432/monitor?sslmode=disable"
    max_open_conns: 10
    max_idle_conns: 5
```

**連線池參數**：

| 參數 | 預設值 | 說明 |
|------|--------|------|
| max_open_conns | 10 | 最大開啟連線數 |
| max_idle_conns | 5 | 最大閒置連線數 |

**啟動驗證**：`--storage=postgres` 時，collector 啟動流程增加：

1. 驗證 `--dsn` 或 config `postgres.dsn` 已提供（未提供則 fatal error 退出）
2. 嘗試連線 PostgreSQL（`sql.Open` + `db.Ping`）
3. 連線失敗則 fatal error 退出（含錯誤訊息和 DSN host:port）
4. 檢查 events 表是否存在（不存在則自動建表 + 建索引）
5. 啟動成功，log 記錄 backend 類型和連線資訊

**驗收標準**：

- [ ] `--storage=postgres --dsn=postgres://...` 啟動成功
- [ ] `--storage=postgres` 未提供 DSN 時 fatal error 並提示
- [ ] PostgreSQL 連線失敗時 fatal error 並顯示 host:port
- [ ] 首次啟動自動建表建索引
- [ ] YAML config 的 postgres 區塊正確載入
- [ ] CLI flag `--dsn` 覆蓋 config `postgres.dsn`

### FR-04: 能力偵測

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-008 |
| 對應用例 | UC-03 |

**描述**：Dashboard 和 Query API 透過 Go type assertion 判斷 storage backend 是否支援進階分析能力。

教學依據：scaling-evolution.md「Dashboard 用 Go 的 type assertion 判斷能力 — funnel/cohort 視圖在 SQLite 模式下不顯示入口，而非顯示後報錯」

**偵測機制**：

```go
// handler 層判斷能力
func (h *QueryHandler) handleAnalytics(w http.ResponseWriter, r *http.Request) {
    as, ok := h.storage.(AnalyticsStorage)
    if !ok {
        http.Error(w, "analytics not available with current storage backend", http.StatusNotImplemented)
        return
    }
    // 使用 as.Aggregate / as.Funnel / as.Cohort
}
```

**Endpoint 路徑**（0.4.0-W3-002 裁定，沿用既有 `/v1/` 風格）：

| Endpoint | 說明 |
|----------|------|
| `GET /v1/capabilities` | 能力查詢，回傳當前 backend 能力表 |
| `GET /v1/analytics/aggregate?group_by=&metric=` | 對應 AnalyticsStorage.Aggregate |
| `GET /v1/analytics/funnel?steps=a,b,c&window=168h` | 對應 AnalyticsStorage.Funnel（window 為 Go duration 字串） |
| `GET /v1/analytics/cohort?group_by=&metric=` | 對應 AnalyticsStorage.Cohort |

三支 analytics endpoint 由同一 handler 以 `h.storage.(AnalyticsStorage)` type assertion 分流：斷言失敗（SQLite backend）回 501 JSON error body；斷言成功則轉呼叫對應方法。

**能力查詢 API**：

`GET /v1/capabilities` 回傳目前 storage backend 支援的能力：

```json
{
  "storage_backend": "postgres",
  "capabilities": {
    "basic_query": true,
    "aggregate": true,
    "funnel": true,
    "cohort": true
  }
}
```

| backend | basic_query | aggregate | funnel | cohort |
|---------|-------------|-----------|--------|--------|
| sqlite | true | false | false | false |
| postgres | true | true | true | true |

**Dashboard 視圖切換規則**：

| 視圖 | SQLite | PostgreSQL |
|------|--------|-----------|
| 總覽頁 | 顯示 | 顯示 |
| 事件詳情 | 顯示 | 顯示 |
| Session 回放 | 顯示 | 顯示 |
| Funnel 漏斗 | 不顯示入口 | 顯示 |
| Cohort 留存 | 不顯示入口 | 顯示 |

**驗收標準**：

- [ ] `GET /v1/capabilities` 正確回傳當前 backend 能力
- [ ] SQLite 模式下 analytics API 回傳 501 Not Implemented
- [ ] PostgreSQL 模式下 analytics API 正常回傳
- [ ] type assertion 判斷正確（SQLite = BasicStorage only, PostgreSQL = AnalyticsStorage）

### FR-05: Analytics 查詢語意（Aggregate / Funnel / Cohort）

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-008 |
| 對應用例 | UC-03 |

**描述**：Aggregate / Funnel / Cohort 三方法的查詢語意（0.4.0-W2-004 補完，v1.0 僅定義簽名）。

教學依據：`self-hosted-funnel.md`「PostgreSQL 層：Session 級 funnel」（window function 設計）、`cohort-analysis.md`「時間 cohort」。

**Aggregate**：依 `spec.GroupBy` 分組、`spec.Metric` 計量。GroupBy 欄位名稱需直接串接進 SQL（PostgreSQL 不支援欄位名稱以 bind parameter 傳遞），故僅允許固定白名單欄位（`name` / `type` / `session_id` / `source_platform` / `source_app` / `source_os` / `level`），非白名單回 `ErrUnsupportedGroupBy`。Metric 目前僅支援 `count`，非 `count` 回 `ErrUnsupportedMetric`。

**Funnel**：依教學設計——每 session 依 `ts` 排序比對 `steps` 給定順序（`array_position` 換算步驟序號），回報每步「到達至少此步」的 session 數（漏斗嚴格遞減）。`timeWindow` 定義為「查詢時間點往前回溯的區間」（對齊教學範例 `ts >= NOW() - INTERVAL '7 days'` 語意），`timeWindow<=0` 表示不限制時間範圍。空 `steps` 回 `ErrEmptyFunnelSteps`。

**Cohort**：依教學「時間 cohort」設計——以 `session_started` 週分桶（`date_trunc('week', session_started)`）為 cohort，交叉白名單 `groupBy` 欄位計算 `metric`。`metric="count"` 為事件數、`metric="sessions"` 為去重 session 數；`groupBy` 白名單與 Aggregate 相同，其餘 metric 回 `ErrUnsupportedMetric`。

**JSONB 索引適用性**：Aggregate / Funnel / Cohort 皆為固定 column 聚合（不查詢 `data` JSONB 內容），FR-02 的 GIN / partial index 不適用；三方法查詢計畫走 FR-02 已建立的 `idx_events_type_ts` / `idx_events_session` / `idx_events_name` 一般索引。

**驗收標準**：

- [ ] Aggregate 對白名單外 GroupBy / 非 count Metric 回對應 sentinel error
- [ ] Funnel 回傳的 reached 計數符合漏斗嚴格遞減語意
- [ ] Cohort 依週分桶 + groupBy 交叉回傳 cells

## 非功能需求

### NFR-01: 並行寫入效能

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | 多連線並行寫入無 lock |

**描述**：PostgreSQL 的 MVCC 機制允許多個 SDK 同時 flush 事件而不產生寫入鎖定。這是從 SQLite 切換到 PostgreSQL 的核心價值之一。

**效能基準**（預期值，實測確認）：

| 指標 | SQLite (SPEC-004) | PostgreSQL | 說明 |
|------|-------------------|-----------|------|
| 單連線寫入 | ~5,000 inserts/sec | ~10,000 inserts/sec | 批次 INSERT |
| 10 連線並行寫入 | N/A（single writer） | ~50,000 inserts/sec | 連線池並行 |
| 單表 SELECT（索引查詢） | < 10ms | < 10ms | 基本查詢延遲相當 |
| JSONB `data->>'key'` 查詢 | N/A | < 20ms（有索引） | JSONB B-tree 索引 |
| GIN `data @> '{}'` 查詢 | N/A | < 50ms（有索引） | JSONB 包含查詢 |
| Aggregate 查詢（10 萬筆） | 慢（無 parallel query） | < 500ms | PostgreSQL 平行查詢 |

偏差 > 2 倍須記錄到 `docs/challenges/` 並回補教學章節。

### NFR-02: 連線池管理

| 項目 | 值 |
|------|-----|
| 類型 | 可用性 |
| 指標 | 連線池耗盡時 graceful degradation |

**描述**：Go 的 `database/sql` 套件內建連線池管理。需設定合理的 `max_open_conns` 和 `max_idle_conns` 避免 PostgreSQL 連線數過多。

**行為**：
- 連線池滿時，新請求排隊等待（Go `database/sql` 預設行為）
- 連線逾時後自動重建
- collector 關閉時 graceful close 所有連線（`db.Close()`）

### NFR-03: PostgreSQL 版本相容性

| 項目 | 值 |
|------|-----|
| 類型 | 相容性 |
| 指標 | 支援 PostgreSQL 14+ |

**描述**：DDL 和 SQL 語法限制在 PostgreSQL 14+ 支援的範圍。不使用 PostgreSQL 15/16 新增語法（如 `MERGE`）。

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 獨立部署模式 | SQLite 和 PostgreSQL 為獨立部署選擇，不需要資料遷移 | 簡化切換流程，降低運維複雜度 |
| Interface 一致性 | PostgreSQL backend 實作 `AnalyticsStorage` interface（SPEC-007 FR-01 定義） | Store / Query / Downsample / Purge 方法簽名與 SQLite 一致 |
| 攤平欄位 | source_* 維持攤平為獨立 column（與 SQLite 一致），不改用 nested JSONB | 簡化跨 backend 的 struct → column 映射 |
| Go driver | 使用 `lib/pq` 或 `pgx`（pure Go PostgreSQL driver） | 無 CGO 依賴，與 SQLite 的 modernc.org/sqlite 策略一致 |

## 目錄結構（擴充 SPEC-007）

```
collector/
├── internal/
│   ├── storage/
│   │   ├── storage.go          # BasicStorage + AnalyticsStorage interface
│   │   ├── sqlite/
│   │   │   └── sqlite.go       # SQLite 實作（BasicStorage）
│   │   └── postgres/
│   │       └── postgres.go     # PostgreSQL 實作（AnalyticsStorage）
```

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從 PROP-008 + 教學 scaling-evolution.md + feature-tier-boundary.md 萃取 |
| 1.1 | 2026-07-03 | events DDL 補 batch_id（0.3.6-W2-001 契約收斂）、source_os、session_started（v1.0 漏列，SQLite 版已有）、fingerprint（SPEC-015）；基礎索引補 idx_events_fingerprint（0.4.0-W1-006） |
| 1.2 | 2026-07-03 | events DDL 補 flags JSONB nullable 欄位（schema `_flags` 定形，PROP-010 硬耦合前置；寫入邏輯屬 v0.5.0）（0.4.0-W1-011） |
| 1.3 | 2026-07-03 | 新增 FR-05：Aggregate / Funnel / Cohort 查詢語意（v1.0 僅定義簽名，本版依教學 self-hosted-funnel.md / cohort-analysis.md 補完 GroupBy 白名單、Funnel session 級語意、Cohort 週分桶語意）（0.4.0-W2-004） |
| 1.4 | 2026-07-03 | FR-04 補 analytics endpoint 路徑定義（`GET /v1/analytics/{aggregate,funnel,cohort}` + capabilities 路由，PM 裁定沿用 /v1 風格，教學回補評估見 0.4.0-W3-004）；修正 frontmatter 版本與歷史表錯位（W2-004/W3-002 各漏一半）（0.4.0-W3-002） |
