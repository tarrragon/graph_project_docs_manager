---
id: DOMAIN-MAP-COLLECTOR
domain: "collector"
source_specs: [SPEC-002, SPEC-003, SPEC-004, SPEC-005, SPEC-007, SPEC-010, SPEC-011, SPEC-012, SPEC-013, SPEC-014, SPEC-015]
related_usecases: [UC-01, UC-02, UC-03, UC-06, UC-07, UC-08, UC-09]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — Collector

> 產出來源：ticket 0.5.0-W1-002（版本-Wave-序號，追蹤於 `docs/work-logs/`）。本文件告訴開發者每個概念該落在哪個 package、依賴能指向誰。
> 與 `docs/usecases/traceability.yaml`（UC↔測試）、`docs/spec/collector/` 各 SPEC（FR 清單）交叉引用。

**術語對照**：SPEC = 功能規格（`docs/spec/` 下各檔）；FR = Functional Requirement；NFR = Non-Functional Requirement；UC = Use Case（`docs/usecases/`）；VO = Value Object。「教學」指配套 blog monitoring 系列（`~/project/blog/content/monitoring/`，見 CLAUDE.md §3）。

## 1. 目的與 UC / DDD 正交關係

本文件界定 collector 的 DDD bundle 邊界——每個 struct、函式該放哪個 package，以及 package 間允許的依賴方向。UC 是垂直視角（一條使用者劇本貫穿 HTTP 請求→驗證→儲存→查詢），本文件是水平視角（按業務知識切 package 邊界），兩者正交。

**核心準則**：domain 層保持純——無 I/O、無 HTTP 框架、對 SQLite/PostgreSQL 一無所知。這確保 domain 邏輯可用純函式 unit test 驗證，不需啟動真實 DB 或 HTTP server。

## 2. 分層與依賴方向

**分類詞 legend**（§3 表格「分類」欄使用以下標籤）：

| 標籤 | 定義 |
|------|------|
| aggregate root | 需持久化的核心實體，持有業務不變式 |
| supporting VO | 自足值物件 + 純函式，零依賴或被單向依賴 |
| read-model | 從 aggregate 讀取後衍生計算（趨勢/比率/配置） |
| domain service | 無狀態跨 aggregate 協調邏輯 |
| policy | 事件驅動的路由/反應決策 |
| shared kernel | 跨 domain 共用的核心定義（本專案為 core/EventSchema） |

Collector 為**多 aggregate 形態**——Event 和 ErrorGroup 有獨立一致性邊界，Pipeline domain service 負責跨 aggregate 寫入協調。

> **目標邊界，非現況**：以下 DAG 和 §3 的「目標路徑」欄描述預期的 package 結構。現況中部分 bundle 尚未分離到獨立 package（見 §6 技術債追蹤）。

```
presentation (HTTP handlers: ingest, query, health, CORS, metrics)
        |
read-model (EventQuery, ErrorAnalysis, Analytics)
        |
domain service (Pipeline, FlowControl, Retention, RuleEngine)
  policy (ErrorFastTrack)
        |
   +---------+
   |         |
Event     ErrorGroup    (aggregate roots, by-id: fingerprint linking)
   |
Fingerprint  QueryFilter  (supporting VOs)
   ^
   |
core/EventSchema  (cross-domain shared kernel)
   ^
   |
data (SQLite impl, PostgreSQL impl, BasicStorage/AnalyticsStorage interface)
```

**依賴方向底線（不可違反）**：

- domain 不得 import data / presentation / HTTP 框架 / SQLite / PostgreSQL。違反則喪失純函式可測性。
- read-model 依賴 aggregate + supporting VO，彼此不成環。這確保每個 read-model 可獨立修改和測試，概念改動不沿耦合鏈擴散。
- Event 和 ErrorGroup 間僅 by-id 參照（ErrorGroup.fingerprint 是 Event 衍生欄位），不直接嵌入。違反則破壞交易一致性邊界，兩 aggregate 的生命週期被強制耦合。
- domain service（Pipeline、FlowControl、Retention、RuleEngine）透過 DI 依賴 storage interface，不持有自身狀態。這使得 unit test 可注入 mock storage，不需啟動真實 DB。
- ErrorFastTrack policy 透過 channel 分流間接影響 Pipeline，不直接 import aggregate。若破壞此邊界，路由邏輯變更會擴散到 aggregate 程式碼。

## 3. Bundle 界定表

### 真 domain

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| Event | aggregate root | Event struct（EventSource, EventSession, EventError 子結構）、schema validation invariants（SPEC-007 FR-02） | 持久化細節、HTTP 序列化 | `collector/internal/event/` | unit：schema 合規斷言、必填欄位、type enum |
| ErrorGroup | aggregate root | error_groups entity、status 轉換邏輯、fingerprint uniqueness（概念來源：SPEC-015；實作歸屬見 S7） | dashboard 查詢、SQL DDL | `collector/internal/errorgroup/` | unit：status 轉換（open->resolved->open）、count 遞增、UPSERT 語意 |
| Fingerprint | supporting VO | SHA256 fingerprint 計算、message normalization 純函式（SPEC-015 FR-01, FR-02） | storage 寫入、pipeline 串接 | `collector/internal/fingerprint/` | unit：同 message 同 fingerprint、normalization 規則（UUID/email/IP/數字替換）、SDK 覆蓋優先 |
| QueryFilter | supporting VO | QueryFilter struct、name 萬用字元轉換（SPEC-007 FR-03） | SQL 查詢實作 | `collector/internal/storage/` | unit：萬用字元轉換、預設值填充 |
| Pipeline | domain service | 五段處理鏈路串接、channel send 協調、Event+ErrorGroup 跨 aggregate 寫入（SPEC-007 FR-05, SPEC-013 FR-01） | HTTP handler、具體 storage 實作 | `collector/cmd/collector/` + `collector/internal/handler/` | unit + integration：pipeline 順序驗證、channel 滿時 429、graceful shutdown drain |
| FlowControl | domain service | per-SDK token bucket rate limiting、channel backpressure（SPEC-013 FR-01, FR-02） | HTTP response 格式 | `collector/internal/ratelimit/` | unit：per-app 隔離、_unknown fallback、token 補充速率 |
| ErrorFastTrack | policy | error 事件繞過 rate limit 走獨立 channel（SPEC-013 FR-03） | rate limiter 實作 | `collector/internal/handler/` | unit：error 事件不觸發 rate limit、混合批次分流 |
| Retention | domain service | Downsample（hourly_summary 聚合）、Purge（三層清除策略）（SPEC-004 FR-02, FR-03） | SQL DDL、SQLite/PostgreSQL 差異 | `collector/internal/retention/` | unit + integration：downsample 幂等性、purge 保留期限、purge 單批 < 1s |
| RuleEngine | domain service | count-based rule 評估、批次掃描觸發（SPEC-005 FR-01） | alert 檔案寫入、config 載入 | `collector/internal/rule/` | unit：threshold 觸發、時間窗口、alert 內容格式 |
| EventQuery | read-model | 基本篩選查詢、事件時間軸（SPEC-003 FR-01, FR-03） | SQL 實作、HTTP handler | `collector/internal/storage/` | unit：filter 組合、排序、分頁、預設值 |
| ErrorAnalysis | read-model | error_groups 分群查詢、group 詳情查詢（SPEC-015 FR-05, SPEC-003 FR-02） | SQL DDL、fingerprint 計算 | `collector/internal/storage/` | unit：按 last_seen 排序、ignored 過濾、group 詳情限制 20 筆 |
| Analytics | read-model | Aggregate/Funnel/Cohort 查詢語意（SPEC-014 FR-05）——僅 PostgreSQL backend | JSONB 索引、SQL DDL | `collector/internal/storage/postgres/` | unit + integration：GroupBy 白名單、Funnel 嚴格遞減、Cohort 週分桶 |

### 非 domain

| Bundle | 分類 | 納入概念 | 來源 FR | 目標路徑 | 測試層 |
|---|---|---|---|---|---|
| HTTP Handlers | presentation | ingestion endpoint、query endpoint、health endpoint、CORS、Content-Type 容錯、429 response format | SPEC-002 FR-01~03/NFR-02~03, SPEC-003 FR-01~03, SPEC-013 FR-04, SPEC-014 FR-04 | `collector/internal/handler/` | integration |
| SQLite Backend | data | SQLite DDL、WAL mode、busy timeout、Store/Query 實作 | SPEC-004 FR-01, SPEC-007 FR-01 | `collector/internal/storage/sqlite/` | repository test |
| PostgreSQL Backend | data | PostgreSQL DDL、JSONB 索引、連線池、AnalyticsStorage 實作 | SPEC-014 FR-01~02 | `collector/internal/storage/postgres/` | repository test |
| Config | infra | YAML config、CLI flags、環境變數三層優先級 | SPEC-007 FR-04, SPEC-005 FR-02, SPEC-014 FR-03 | `collector/internal/config/` | unit |
| Container | infra | Dockerfile、Docker Compose、volume mount、graceful shutdown 序列 | SPEC-012 FR-01~05 | `collector/Dockerfile` + `docker-compose.yml` | integration |
| Benchmark | infra | seed/write/query CLI、測試資料產生器 | SPEC-010 FR-01~03 | `collector/cmd/collector/` | integration |
| JSONL Export/Import | infra | export streaming、import 去重、JSONL mirror | SPEC-011 FR-01~03 | `collector/cmd/collector/` | integration |
| Metrics | presentation | IncReceived/IncRejected/IncStored 等計數器、Snapshot、ChannelStats | — | `collector/internal/metrics/` | unit |
| Schema Validation | infra | event JSON Schema 驗證邏輯、constants | SPEC-007 FR-02 | `collector/internal/schema/` | unit |
| Shutdown | infra | graceful shutdown 序列（drain channel → close DB） | — | `collector/internal/shutdown/` | integration |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| Event | schema 必填欄位（v, type, name, timestamp, source）缺一即拒；type 限 event/error/metric/lifecycle enum；source.sdk 限 js/flutter/python/go enum；timestamp 必為 ISO 8601（衍生自 DOMAIN-MAP-CORE EventSchema 不變式） |
| ErrorGroup | fingerprint 全域唯一（PRIMARY KEY）；status 轉換：resolved 收到新 event 自動 reopen 為 open；ignored 收到新 event 維持 ignored、count+1；count 只增不減；first_seen <= last_seen |
| Fingerprint | 同 error_type + 同 normalized_message 產生相同 fingerprint；不同 error_type 即使 message 相同也不同 fingerprint；SDK data.fingerprint 存在時覆蓋自動計算；normalization 規則順序：UUID > email > IPv4 > HTTP status(保留) > 3+位數字 > 長字串 |
| QueryFilter | 無篩選參數時預設 from=24h 前、to=now、limit=100、offset=0；name 的 `*` 轉為 SQL `%` |
| Pipeline | 處理順序不可違反：validate -> fingerprint enrichment(error only) -> error fast-track routing -> rate limit -> channel -> write；channel 滿時非阻塞回 429；graceful shutdown 先 drain channel 再關 DB |
| FlowControl | per source.app 獨立計算；source.app 空值歸入 _unknown；token bucket 每秒補充；circuit breaker 三態：closed→open（reject count >= threshold in window）、open→half-open（cooldown 過期）、half-open→closed（一次 success）或→open（一次 reject） |
| ErrorFastTrack | type=error 事件不經 rate limit；error channel 滿時仍回 429（自我保護） |
| Retention | downsample INSERT OR REPLACE 幂等；downsample 不刪除 events 原始資料；purge 三層各自獨立保留期（events 7d / hourly 90d / daily 365d） |
| RuleEngine | 批次評估每 1 分鐘；count > threshold in window 才觸發；alert 檔含觸發時間+rule 名稱+匹配數 |
| EventQuery | 無篩選時預設 from=24h/to=now/limit=100/offset=0；排序一律 timestamp DESC；分頁 offset+limit 不超過總數時回傳正確子集 |
| ErrorAnalysis | 分群結果按 last_seen DESC 排序；ignored 狀態 group 預設過濾；group 詳情 events 限 20 筆 |
| Analytics | GroupBy 欄位限白名單（type/name/source.sdk/source.app）；Funnel 各步驟 count 嚴格遞減；Cohort 週分桶以 first_seen 為基準 |

## 4. 邊界決策

### 4.1 Event 和 ErrorGroup 為獨立 aggregate

定案：Event 和 ErrorGroup 為兩個獨立 aggregate root，不合併。

依據：Event 是不可變的寫入單元（write-once），ErrorGroup 有可變狀態（status, count）和獨立生命週期。兩者的修改模式不同——Event 寫入是 append-only，ErrorGroup 的 status 轉換是獨立的業務邏輯。實務上 Pipeline domain service 在同一 DB transaction 內協調兩者的 UPSERT——這是實用主義的 aggregate 邊界軟化（避免引入 saga 的複雜度），非嚴格 DDD 獨立 aggregate。考慮過的替代方案：ErrorGroup 作為 Event 的 child entity，但 ErrorGroup 的生命週期（reopen/ignore）獨立於 Event 寫入，child 語意不適合。

### 4.2 Fingerprint 為 supporting VO 非 kernel

Fingerprint 歸類為 supporting VO——kernel 判準是「被 2+ read-model 消費的共享計算」，但 Fingerprint 計算只有一個消費者（Pipeline domain service，在 ingestion 階段呼叫）。ErrorAnalysis read-model 讀的是已存在 error_groups 表的 fingerprint 值，不重新計算。單一消費者不符 kernel 判準。

### 4.3 Analytics 為獨立 read-model（PostgreSQL only）

合併 Analytics 與 EventQuery 看似減少 bundle 數，但兩者的能力邊界截然不同：Analytics 僅在 PostgreSQL backend 可用（AnalyticsStorage type assertion），SQLite backend 完全不提供此能力。合併會使 SQLite 場景的開發者需理解不適用的概念。因此 Analytics 獨立為 read-model。

### 4.4 FlowControl 為 domain service、ErrorFastTrack 為 policy

定案：rate limiting 和 channel backpressure 合為 FlowControl domain service；error 事件繞過 rate limit 為 ErrorFastTrack policy。

依據：FlowControl 是無狀態的（per-request）流量判斷；ErrorFastTrack 的語意是事件驅動的路由決策（「收到 error 事件→繞過 rate limit→走獨立 channel」），歸類為 policy。**目標分類 vs 現況**：現況中 ErrorFastTrack 是 `handler/ingest.go` 內的同步 if-else 分支（非 event bus），尚未實作為獨立 policy module。此分類是目標架構。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| domain 票 | domain | 按 S3 拆 bundle（Event/ErrorGroup/Fingerprint/Pipeline/FlowControl/Retention/RuleEngine）；依賴方向底線見 S2 |
| data 票 | data | SQLite/PostgreSQL 實作屬 data 層，實作 BasicStorage/AnalyticsStorage interface；不混入 domain 計算 |
| presentation 票 | presentation | HTTP handler 屬 presentation，呼叫 domain service/read-model 取結果，不含業務邏輯 |
| infra 票 | infra | Config/Container/Benchmark/JSONL 屬 infra，不直接依賴 domain 層 struct（透過 interface） |

## 6. 觀察到的技術債（待追蹤）

- Event struct 和 QueryFilter 目前都在 `collector/internal/storage/storage.go`，按 domain map 應分離到各自的 package。追蹤：0.5.0-W2-001。
- Pipeline 五段串接邏輯目前在 `cmd/collector/main.go` + `handler/ingest.go`，按 domain map 應抽為獨立 domain service。追蹤：0.5.0-W2-002。
- Retention（downsample/purge）邏輯目前在 `internal/storage/sqlite/sqlite.go` 的 BasicStorage 方法內，按 domain map 應抽為獨立 domain service package。待建 ticket。
- ErrorGroup 邏輯分散在 `handler/errorgroups.go`（query）和 `sqlite/sqlite.go`（storage），按 domain map 應集中到 `internal/errorgroup/`。待建 ticket。
- CircuitBreaker（`internal/ratelimit/breaker.go`）是獨立狀態機，目前歸在 FlowControl bundle，未來可考慮分離為獨立 resilience bundle。待評估。

## 7. FR -> Bundle 覆蓋對照

### SPEC-002（Ingestion）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | presentation（HTTP handler） | 單筆事件接收 |
| FR-02 | presentation（HTTP handler） | 批次事件接收 |
| FR-03 | presentation（HTTP handler） | Health endpoint |
| NFR-01 | data（SQLite concurrency） | busy timeout |
| NFR-02 | presentation（CORS） | CORS header |
| NFR-03 | presentation（Content-Type） | sendBeacon 容錯 |

### SPEC-003（Query）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | EventQuery + presentation | 基本篩選查詢 |
| FR-02 | ErrorAnalysis + presentation | Error 按 name 分群 |
| FR-03 | EventQuery + presentation | 事件時間軸 |
| NFR-01 | data | 查詢效能（索引） |

### SPEC-004（Storage）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | data（SQLite） | SQLite 寫入 |
| FR-02 | Retention | Downsample |
| FR-03 | Retention | Purge |
| NFR-01 | data | 寫入效能 |
| NFR-02 | data | 保留策略不阻塞 |

### SPEC-005（Rule Engine）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | RuleEngine | count-based rule |
| FR-02 | infra（Config） | Rule 設定格式 |

### SPEC-007（Internal Architecture）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | data（Storage interface） | BasicStorage/AnalyticsStorage |
| FR-02 | Event | Event struct 定義 |
| FR-03 | QueryFilter | QueryFilter struct |
| FR-04 | infra（Config） | YAML config + CLI flags |
| FR-05 | Pipeline | 五段處理鏈路 |

### SPEC-010（Benchmark）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | infra（tooling） | Seed 測試資料 |
| FR-02 | infra（tooling） | Write 吞吐測試 |
| FR-03 | infra（tooling） | Query 延遲測試 |
| NFR-01 | infra（tooling） | 隔離（不影響 production） |
| NFR-02 | infra（tooling） | 輸出可解析（CSV/JSON） |

### SPEC-011（JSONL Export）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | infra（export） | Export JSONL |
| FR-02 | infra（import） | Import JSONL |
| FR-03 | infra（mirror） | JSONL mirror |
| NFR-01 | infra（export） | Streaming 記憶體上限 |
| NFR-02 | infra（export） | 不阻塞寫入 |

### SPEC-012（Container）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | infra（deployment） | Dockerfile |
| FR-02 | infra（deployment） | Volume mount |
| FR-03 | infra（deployment） | Graceful shutdown |
| FR-04 | infra（deployment） | Docker Compose |
| FR-05 | infra（deployment） | Healthcheck |
| NFR-01 | infra（deployment） | Volume Mount 效能 |
| NFR-02 | infra（deployment） | Image 安全（non-root） |

### SPEC-013（Backpressure）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | FlowControl + Pipeline | 寫入 channel pattern |
| FR-02 | FlowControl | Per-SDK rate limiting |
| FR-03 | ErrorFastTrack | Error 快通道 |
| FR-04 | presentation（HTTP） | 429 response format |
| NFR-01 | infra（benchmark） | 壓測基準 |
| NFR-02 | Pipeline | Graceful Shutdown 不丟事件 |

### SPEC-014（PostgreSQL）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | data（PostgreSQL） | PostgreSQL DDL |
| FR-02 | data（PostgreSQL） | JSONB 索引 |
| FR-03 | infra（Config） | 啟動參數 |
| FR-04 | presentation（HTTP handler） | 能力偵測（AnalyticsStorage type assertion） |
| FR-05 | Analytics | Aggregate/Funnel/Cohort |
| NFR-01 | data（PostgreSQL） | 並行寫入效能 |
| NFR-02 | data（PostgreSQL） | 連線池管理 |
| NFR-03 | data（PostgreSQL） | 版本相容性 |

### SPEC-015（Error Fingerprint）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | Fingerprint | Fingerprint 計算 |
| FR-02 | Fingerprint | Message normalization |
| FR-03 | data（error_groups storage） | Storage 擴充 |
| FR-04 | Pipeline | 寫入 pipeline 擴充 |
| FR-05 | ErrorAnalysis + presentation | Dashboard 升級 |
| NFR-01 | Fingerprint | Fingerprint 計算效能 |

---

**Last Updated**: 2026-07-23 | **Source**: 0.5.0-W1-002
