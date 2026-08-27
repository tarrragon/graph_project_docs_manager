---
id: SPEC-010
title: "Benchmark CLI — SQLite 效能基準實測"
status: draft
source_proposal: PROP-004
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"
owner: ""

domain: collector
subdomain: benchmark

related_usecases: [UC-06]
related_specs: [SPEC-007, SPEC-003]
implements_requirements: []
depends_on_domains: [core]
---

# Benchmark CLI — SQLite 效能基準實測

## 概述

Collector 內建 benchmark 子命令，讓使用者在自己的環境實測 SQLite 寫入吞吐、查詢延遲和資源消耗。三個子命令：`collector benchmark seed`（灌入測試資料）、`collector benchmark write`（寫入吞吐測試）、`collector benchmark query`（查詢延遲測試）。

教學依據：[模組四：SQLite Backend 效能基準](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/sqlite-performance-baseline.md)

## 功能需求

### FR-01: Seed — 灌入測試資料

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-004 |
| 對應用例 | - |

**描述**：`collector benchmark seed` 灌入指定數量的測試事件到 storage backend。事件按四類分佈產生，覆蓋 `event.schema.json` 的所有欄位。Seed 使用獨立的臨時 DB 檔案（`--db-path` 指定，預設 `./benchmark.db`），不影響 production 資料。

**測試資料分佈**：

| 事件類型 | 比例 | 說明 |
|---------|------|------|
| event | 60% | 一般業務事件（頁面瀏覽、按鈕點擊） |
| error | 15% | 錯誤事件（含 stack trace） |
| metric | 15% | 效能指標（API latency、記憶體使用） |
| lifecycle | 10% | 生命週期事件（app 啟動、背景切換） |

**CLI 介面**：

```
collector benchmark seed [flags]

Flags:
  --events=N       總筆數（預設 100000）
  --db-path=PATH   SQLite 檔案路徑（預設 ./benchmark.db）
```

**輸出格式**：

```
Seeding 100000 events to ./benchmark.db ...
  event:     60000 (60%)
  error:     15000 (15%)
  metric:    15000 (15%)
  lifecycle: 10000 (10%)
Done in 3.2s (31250 events/sec)
```

**驗收標準**：

- [ ] `collector benchmark seed --events=100000` 灌入 10 萬筆測試資料
- [ ] 灌入的事件覆蓋四種 type 且比例符合定義
- [ ] 灌入的事件通過 `event.schema.json` 驗證
- [ ] 使用獨立 DB 檔案，不影響 production 資料

### FR-02: Write — 寫入吞吐測試

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-004 |
| 對應用例 | - |

**描述**：`collector benchmark write` 測量 Storage.Store() 的寫入吞吐和延遲。支援單筆和批次兩種模式。測試在空 DB 上進行（每次執行前建立新的臨時 DB）。

**CLI 介面**：

```
collector benchmark write [flags]

Flags:
  --events=N    總筆數（預設 10000）
  --batch=N     每批筆數（預設 1，即單筆模式；設 100 為批次模式）
  --db-path=PATH  SQLite 檔案路徑（預設 ./benchmark-write.db）
```

**輸出格式**：

```
Benchmark write: 10000 events, batch=100
  Total duration:  0.52s
  Throughput:      19230 events/sec
  Latency per event:
    p50:  48µs
    p95:  120µs
    p99:  350µs
```

**延遲計算方式**：每筆事件的延遲 = 該批次的 Store() 呼叫耗時 / 批次筆數。收集所有事件延遲後計算百分位。

**驗收標準**：

- [ ] `collector benchmark write --events=10000 --batch=1` 完成並輸出 events/sec + latency 百分位
- [ ] `collector benchmark write --events=10000 --batch=100` 完成，吞吐高於單筆模式
- [ ] 輸出格式 human-readable 且可被 grep 擷取（如 `grep "Throughput"` 取得數字）
- [ ] 每次測試使用乾淨 DB（建立新臨時檔案）

### FR-03: Query — 查詢延遲測試

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-004 |
| 對應用例 | - |

**描述**：`collector benchmark query` 測量 Storage.Query() 的查詢延遲。需要先用 `benchmark seed` 灌入測試資料。支援多種查詢模式。

**CLI 介面**：

```
collector benchmark query [flags]

Flags:
  --type=TYPE         事件類型過濾（event / error / metric / lifecycle）
  --session-id=ID     Session ID 精確查詢（ID 設為 "random" 時隨機選取一個已存在的 session_id）
  --group-by=FIELD    聚合查詢（name / type）
  --db-path=PATH      SQLite 檔案路徑（預設 ./benchmark.db）
  --repeat=N          重複次數取中位數（預設 5）
```

**輸出格式**：

```
Benchmark query: type=error (5 runs, median)
  Duration:      12ms
  Rows scanned:  15000
  Rows returned: 15000
```

```
Benchmark query: group-by=name (5 runs, median)
  Duration:      85ms
  Rows scanned:  100000
  Rows returned: 47
```

**驗收標準**：

- [ ] `collector benchmark query --type=error` 輸出 query duration + rows
- [ ] `collector benchmark query --session-id=random` 輸出 query duration + rows
- [ ] `collector benchmark query --group-by=name` 輸出 query duration + rows
- [ ] 重複執行取中位數（排除首次冷啟動影響）
- [ ] DB 不存在時輸出錯誤提示「run 'collector benchmark seed' first」

## 非功能需求

### NFR-01: Benchmark 隔離

| 項目 | 值 |
|------|-----|
| 類型 | 可靠性 |
| 指標 | Benchmark 不影響 production 資料 |

**描述**：所有 benchmark 操作使用獨立的 DB 檔案，預設路徑與 production DB 不同。`--db-path` 不可預設為 `collector.yaml` 中的 `storage.sqlite.path`。

### NFR-02: 輸出可解析

| 項目 | 值 |
|------|-----|
| 類型 | 可用性 |
| 指標 | 關鍵數值可被 grep / awk 擷取 |

**描述**：輸出格式為 human-readable 文字。每個關鍵指標獨佔一行，格式為 `Key: Value`，方便 `grep "Throughput"` 或 `awk` 擷取數值。

## 介面規格

### CLI 子命令結構

```
collector benchmark seed   [--events=N] [--db-path=PATH]
collector benchmark write  [--events=N] [--batch=N] [--db-path=PATH]
collector benchmark query  [--type=TYPE] [--session-id=ID] [--group-by=FIELD]
                           [--db-path=PATH] [--repeat=N]
```

所有子命令共用 `--db-path` flag。Seed 和 query 預設 `./benchmark.db`，write 預設 `./benchmark-write.db`（避免和 seed 資料混用）。

### 內部呼叫

Benchmark 直接呼叫 `BasicStorage` interface（FR-01 in SPEC-007），不經過 HTTP handler。測量的是 storage 層純粹的讀寫效能，排除網路和 HTTP 解析開銷。

### 測試資料產生器

Seed 命令的事件產生器需覆蓋：

| 欄位 | 產生策略 |
|------|---------|
| `v` | 固定 `1` |
| `type` | 按分佈比例隨機選取 |
| `timestamp` | 過去 7 天內隨機分佈 |
| `source.sdk` | 隨機選取 `["monitor-python", "monitor-flutter", "monitor-js"]` |
| `source.platform` | 對應 sdk 的平台 |
| `name` | 從預定義的 50 個事件名稱中隨機選取 |
| `level` | error 類型為 "error"；其餘隨機 |
| `data` | 1-5 個隨機 key-value pair |
| `error` | 僅 error 類型：含 message + type，50% 含 stack |
| `context.session_id` | 從 100 個預產生的 UUID v7 中隨機選取 |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 直接呼叫 BasicStorage | 不經 HTTP handler | 測量 storage 純效能 |
| 獨立 DB 檔案 | 不使用 production DB 路徑 | 資料隔離 |
| 百分位延遲統計 | 記錄每筆事件延遲，事後排序計算 | 記憶體使用 = O(events) |
| 測試資料確定性 | 相同 `--events` 產生相同分佈比例 | 可重複驗證 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從 PROP-004 + 教學 sqlite-performance-baseline.md 萃取 |
