---
id: SPEC-007
title: "Collector 內部架構（Internal Architecture）"
status: draft
source_proposal: PROP-001
created: "2026-06-22"
updated: "2026-07-03"
version: "1.3"
owner: ""

domain: collector
subdomain: architecture

related_usecases: [UC-01, UC-02, UC-03]
related_specs: [SPEC-002, SPEC-003, SPEC-004, SPEC-005]
implements_requirements: []
depends_on_domains: [core]
---

# Collector 內部架構（Internal Architecture）

## 概述

定義 collector 的內部模組結構、Go interface 設計、啟動設定和 CLI 介面。本 Spec 不定義各模組的功能細節（由 SPEC-002~005 負責），而是定義模組間的銜接契約。

教學依據：[Collector 架構](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/architecture.md)、[功能分層與 Backend 選擇](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/feature-tier-boundary.md)、[規模演進](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md)

## 功能需求

### FR-01: Storage Interface（可插拔 Backend）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：定義 `BasicStorage` interface，MVP 只實作 SQLite backend。interface 設計 day-one 確定，後續擴充 PostgreSQL 時不需改動消費端。

```go
type BasicStorage interface {
    Store(events []Event) error  // 批次寫入（單筆時 len=1）
    Query(filter QueryFilter) ([]Event, error)
    Count(filter QueryFilter) (int, error)
    Downsample(before time.Time) error
    Purge(eventsBefore, summaryBefore time.Time) error
    Close() error
}

// AnalyticsStorage — PostgreSQL 層新增（PROP-008，v0.4.0）
// MVP 不實作但 interface 設計 day-one 確定。
type AnalyticsStorage interface {
    BasicStorage
    Aggregate(spec AggregateSpec) (AggregateResult, error)
    Funnel(steps []string, timeWindow time.Duration) (FunnelResult, error)
    Cohort(groupBy string, metric string) (CohortResult, error)
}
```

`Store(events []Event)` 使用 slice 參數支援批次寫入——SDK 的 flush batch 天然是多筆，單筆場景傳 `[]Event{event}` 即可。教學的 scaling-evolution.md 部分範例用 `Store(event Event)` 單數形式，本 Spec 統一為批次簽名。

**v1.1 變更說明（0.4.0-W2-001）**：`Downsample` / `Purge` 補上 `time.Time` 參數、新增 `Count(filter QueryFilter) (int, error)`，同步 sqlite（`collector/internal/storage/sqlite/sqlite.go`）與 postgres 存根（`collector/internal/storage/postgres/postgres.go`）既有實作簽名——v1.0 的無參數簽名為文件落後實作，本次回補使 SPEC 與程式碼一致。共用 interface 與型別已於 `collector/internal/storage/storage.go` 落地。

**驗收標準**：

- [ ] BasicStorage interface 定義存在
- [ ] SQLite backend 實作 BasicStorage 所有方法
- [ ] 切換 backend 只需改啟動參數，不改業務邏輯

### FR-02: Event 內部表示

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：定義 `Event` struct 作為 ingestion、storage、query、rule engine 四段共用的內部表示。從 `schema/event.schema.json` 映射。

```go
type Event struct {
    V         int               `json:"v"`
    Type      string            `json:"type"`
    Name      string            `json:"name"`
    Timestamp string            `json:"timestamp"`
    Source    EventSource        `json:"source"`
    Session   *EventSession     `json:"session,omitempty"`
    Level     string            `json:"level,omitempty"`
    Data      map[string]any    `json:"data,omitempty"`
    Error     *EventError       `json:"error,omitempty"`
    BatchID   string            `json:"batch_id,omitempty"`
}

type EventSession struct {
    ID      string `json:"id,omitempty"`
    Started string `json:"started,omitempty"`
}

type EventSource struct {
    SDK      string `json:"sdk"`
    Platform string `json:"platform"`
    App      string `json:"app,omitempty"`
    Version  string `json:"version,omitempty"`
    OS       string `json:"os,omitempty"`
}

type EventError struct {
    Message string `json:"message,omitempty"`
    Stack   string `json:"stack,omitempty"`
    Type    string `json:"type,omitempty"`
}
```

**Event struct ↔ DDL 映射**：Event struct 欄位名用 JSON tag（`Timestamp`），DDL column 名用 SQL 慣例（`ts`）。Store() 負責 struct→column 映射，Query() 負責 column→struct 映射。`BatchID` 不存為獨立 column（存在 `raw` JSON 中）。`Session.ID` 映射到 DDL 的 `session_id` 獨立 column（建索引查詢需要）。`Session.Started` 映射到 `session_started`。`Source.OS` 映射到 `source_os`。

**驗收標準**：

- [ ] Event struct 覆蓋 event.schema.json 所有欄位
- [ ] JSON 反序列化（`json.Unmarshal`）能正確解析 schema 範例事件

### FR-03: QueryFilter 查詢參數結構

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01, UC-03 |

**描述**：定義 `QueryFilter` struct，`GET /v1/events` 和 `GET /v1/events/summary` 共用。

```go
type QueryFilter struct {
    Type    string    // event / error / metric / lifecycle
    Name    string    // 支援 * 萬用字元
    From    time.Time // 預設 24 小時前
    To      time.Time // 預設現在
    Limit   int       // 預設 100
    Offset  int       // 預設 0
    GroupBy string    // summary 用：name / type
}
```

**驗收標準**：

- [ ] QueryFilter 覆蓋 SPEC-003 定義的所有查詢參數
- [ ] Name 的 `*` 萬用字元在 SQLite 實作中轉為 LIKE

### FR-04: Config 結構與啟動參數

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：collector 啟動時從 YAML 設定檔和 CLI flag 載入設定。CLI flag 覆蓋設定檔。

```yaml
# collector.yaml
server:
  port: 9090
  bind: "localhost"

storage:
  backend: "sqlite"       # sqlite | postgres
  sqlite:
    path: "./data/monitor.db"
    busy_timeout: 5000     # ms
  postgres:
    dsn: "postgres://user:pass@localhost:5432/monitor?sslmode=disable"
    max_open_conns: 10     # 連線池最大開啟連線數
    max_idle_conns: 5      # 連線池最大閒置連線數

retention:
  raw_events: "7d"
  hourly_summary: "90d"
  daily_summary: "365d"

rules:
  config_path: "./rules.yaml"
  eval_interval: "1m"
```

CLI flag：

| Flag | 預設值 | 說明 |
|------|--------|------|
| `--port` | 9090 | HTTP 監聽 port |
| `--config` | `./collector.yaml` | 設定檔路徑 |
| `--storage` | sqlite | Storage backend（`sqlite` 或 `postgres`） |
| `--dsn` | （無） | PostgreSQL DSN（`--storage=postgres` 時必填） |
| `--db-path` | `./data/monitor.db` | SQLite 檔案路徑 |

**驗收標準**：

- [ ] YAML 設定檔可載入
- [ ] CLI flag 覆蓋設定檔同名項
- [ ] 缺少設定檔時使用預設值正常啟動

### FR-05: 五段處理鏈路串接

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：collector 的 main.go 串接五段處理鏈路：

1. HTTP endpoint → 2. Schema 驗證 → 3. Storage 寫入 → 4. Query API → 5. Rule Engine

啟動順序：載入 Config → 初始化 Storage → 啟動 Rule Engine 定期掃描 → 啟動 Downsample/Purge 定期 job → 啟動 HTTP server。

關閉順序（graceful shutdown）：停止接收新請求 → flush 待處理事件 → 停止定期 job → 關閉 Storage → 退出。

**驗收標準**：

- [ ] `./monitor-collector` 啟動後五段鏈路完整可用
- [ ] `Ctrl+C` 觸發 graceful shutdown，不丟失已接收事件

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Go 單一 binary | `go build` 產出一個可執行檔，無外部依賴 | 部署簡單 |
| Pure Go SQLite | 使用 `modernc.org/sqlite`，無 CGO | 跨平台編譯 |
| MVP 並發策略 | busy timeout fallback（非 channel pattern） | 簡單，寫入量增長後可切換 |

## 目錄結構

```
collector/
├── cmd/
│   └── collector/
│       └── main.go           # 啟動入口、五段串接
├── internal/
│   ├── config/
│   │   └── config.go         # Config struct + YAML 載入
│   ├── event/
│   │   └── event.go          # Event struct + EventSource + EventError
│   ├── storage/
│   │   ├── storage.go        # BasicStorage interface + QueryFilter
│   │   └── sqlite/
│   │       └── sqlite.go     # SQLite 實作
│   ├── handler/
│   │   ├── ingest.go         # POST /v1/events
│   │   ├── query.go          # GET /v1/events + /v1/events/summary
│   │   └── health.go         # GET /health
│   ├── schema/
│   │   └── validator.go      # JSON Schema 驗證
│   ├── rule/
│   │   └── engine.go         # Rule engine
│   └── retention/
│       └── retention.go      # Downsample + Purge
├── go.mod
├── go.sum
└── collector.yaml            # 預設設定檔
```

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從教學 architecture.md + feature-tier-boundary.md 萃取 |
| 1.1 | 2026-06-22 | Event struct 的 Context 改為 EventContext struct（含 SessionID），解決 session_id 映射問題 |
| 1.2 | 2026-06-22 | Config 結構補 `storage.postgres` 區塊（dsn/max_open_conns/max_idle_conns）；CLI flag 補 `--dsn`（SPEC-014 配合） |
| 1.3 | 2026-06-22 | Event struct 對齊教學：Context 改為 Session（頂層）、Source 補 OS、Name 改必填（WRAP 決策） |
