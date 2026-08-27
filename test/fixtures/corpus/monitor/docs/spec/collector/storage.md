---
id: SPEC-004
title: "Collector 儲存與保留策略（Storage）"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.4"
owner: ""

domain: collector
subdomain: storage

related_usecases: [UC-01]
related_specs: [SPEC-001, SPEC-002, SPEC-003]
implements_requirements: []
depends_on_domains: [core]
---

# Collector 儲存與保留策略（Storage）

## 概述

Collector 五段處理鏈路的第三段：將驗證通過的事件寫入 SQLite，並定期執行 Downsample（降採樣）和 Purge（清除）維持儲存健康。

教學依據：[模組四：JSONL 儲存設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/jsonl-storage.md)、[SQLite 效能基準](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/sqlite-performance-baseline.md)

## 功能需求

### FR-01: SQLite 寫入

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：事件寫入 SQLite 資料庫，WAL 模式啟用。每筆事件存為一行，核心欄位拆為獨立 column（type、name、timestamp），完整 JSON 存為 raw column。

**約束條件**：

- 使用 `modernc.org/sqlite`（pure Go，無 CGO）
- WAL 模式啟用（`_pragma=journal_mode(wal)`）
- busy timeout 設為 5 秒（`_pragma=busy_timeout(5000)`）

**驗收標準**：

- [ ] 事件寫入後可透過 query API 查到
- [ ] WAL 模式已啟用（`PRAGMA journal_mode` 回傳 wal）

### FR-02: Downsample（降採樣）

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：定期將原始事件聚合寫入 `hourly_summary` 摘要表（每小時跑一次，幂等）。聚合維度為 `(hour, type, name)`，記錄 `count` 和 `error_count`。Downsample 不修改原始 events 表——聚合後原始事件由 Purge 負責清除。

教學依據：[規模演進 — 分層保留與降採樣](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md)

**驗收標準**：

- [ ] `hourly_summary` 表含正確的 hour / type / name / count / error_count
- [ ] 重複執行 Downsample 結果幂等（INSERT OR REPLACE）
- [ ] Downsample 不刪除 events 表的原始事件

### FR-03: Purge（清除）

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：定期清除過期資料。分三層執行（每天一次）：

| 表 | 保留期限 | 清除方式 |
|----|---------|---------|
| events（原始） | 7 天 | 分批 DELETE（每批 10000 筆，避免長時間鎖定） |
| hourly_summary | 90 天 | DELETE |
| daily_summary | 365 天 | DELETE |

教學依據：[規模演進 — 分層保留與降採樣](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md)

**驗收標準**：

- [ ] 7 天前的原始事件被清除
- [ ] 90 天前的 hourly_summary 被清除
- [ ] Purge 單批執行時間 < 1 秒（不阻塞寫入）

## 非功能需求

### NFR-01: 寫入效能

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | Mac SSD 約 5,000 inserts/sec（教學預期） |

**描述**：實測確認寫入吞吐量。偏差 > 2 倍須記錄到 `docs/challenges/` 並回補教學章節。

### NFR-02: 保留策略不阻塞 ingestion

| 項目 | 值 |
|------|-----|
| 類型 | 可用性 |
| 指標 | Downsample + Purge 執行時不阻塞寫入超過 1 秒 |

**描述**：保留策略的定期 job 在執行期間持有 write lock。需確認在目標資料量下 job 的執行時間。

## 資料模型

教學依據：[規模演進 — Events 主表 DDL](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md)

### events 主表

| 欄位 | 型別 | 索引 | 說明 |
|------|------|------|------|
| id | INTEGER PRIMARY KEY | 自動 | 自增 ID |
| v | INTEGER NOT NULL | 否 | Schema 版本，預設 1 |
| type | TEXT NOT NULL | 是（複合 idx_type_ts） | 事件類型 |
| name | TEXT NOT NULL | 是（idx_name） | 事件名稱 |
| ts | TEXT NOT NULL | 是（複合 idx_type_ts） | ISO 8601 |
| source_sdk | TEXT | 否 | SDK 來源（js / flutter / python / go） |
| source_app | TEXT | 否 | 應用程式名稱 |
| source_version | TEXT | 否 | 應用程式版本 |
| source_platform | TEXT | 否 | 平台 |
| source_os | TEXT | 否 | OS 版本（如 17.4、14、25.5.0） |
| session_id | TEXT | 是（idx_session） | Session ID |
| session_started | TEXT | 否 | Session 開始時間（ISO 8601） |
| level | TEXT | 否 | 事件等級 |
| data | TEXT | 否 | 附帶結構化資料（JSON） |
| error_message | TEXT | 否 | 錯誤訊息 |
| error_stack | TEXT | 否 | 錯誤堆疊追蹤 |
| error_type | TEXT | 否 | 錯誤類型 |
| raw | TEXT | 否 | 完整 JSON（原始事件保留） |
| receive_ts | TEXT | 否 | Collector 收到時間 |
| batch_id | TEXT | 否 | 所屬批次 ID（UUID v7，對應請求 body 的 `batch_id`；單筆事件請求無值） |
| flags | TEXT | 否 | Collector 附加的可疑流量標記（JSON string，對應 schema `_flags` `{suspicious, reason}`）；nullable，正常事件無值。寫入邏輯屬 v0.5.0 PROP-010，v0.4.0 僅預留欄位（0.4.0-W1-011） |

### hourly_summary 摘要表

| 欄位 | 型別 | 說明 |
|------|------|------|
| hour | TEXT | 小時（UNIQUE 複合） |
| type | TEXT | 事件類型（UNIQUE 複合） |
| name | TEXT | 事件名稱（UNIQUE 複合） |
| count | INTEGER | 事件數 |
| error_count | INTEGER | 錯誤數 |

### daily_summary 摘要表

| 欄位 | 型別 | 說明 |
|------|------|------|
| date | TEXT | 日期（UNIQUE 複合） |
| type | TEXT | 事件類型（UNIQUE 複合） |
| name | TEXT | 事件名稱（UNIQUE 複合） |
| count | INTEGER | 事件數 |
| unique_sessions | INTEGER | 不重複 session 數 |

### 建議索引

```sql
CREATE INDEX idx_type_ts ON events(type, ts);
CREATE INDEX idx_session ON events(session_id);
CREATE INDEX idx_name ON events(name);
```

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
| 1.1 | 2026-06-22 | Downsample 修正為聚合摘要表設計；Purge 改為三層分別清除；資料模型對齊教學 DDL |
| 1.2 | 2026-06-22 | events 表補 source_sdk + error_stack 欄位（三方一致性稽核） |
| 1.3 | 2026-07-03 | events 表補 batch_id 欄位（含既有 DB 遷移路徑 ALTER TABLE）；修復 0.3.6-W2-001 只在 export wire 層補 BatchID、SQLite storage 層斷鏈的問題（0.4.0-W1-007） |
| 1.4 | 2026-07-03 | events 表補 flags TEXT nullable 欄位預留（schema `_flags` 定形，PROP-010 硬耦合前置；寫入邏輯屬 v0.5.0）（0.4.0-W1-011） |
