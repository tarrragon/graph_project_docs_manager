---
id: PROP-001
title: "Monitor MVP — 端到端事件收集與查詢"
status: draft
source: development
proposed_by: "saas-tech-selection + blog 教學規劃"
proposed_date: "2026-06-21"
confirmed_date: null
target_version: v0.1.0
priority: P0
evaluation_level: standard

outputs:
  spec_refs:
    - spec/core/event-schema.md
    - spec/collector/ingestion.md
    - spec/collector/query.md
    - spec/collector/storage.md
    - spec/collector/rule-engine.md
    - spec/collector/internal-architecture.md
    - spec/sdk/python-sdk.md
  usecase_refs: [UC-01, UC-02, UC-03]
  ticket_refs: []

related_proposals: []
supersedes: null
---

# PROP-001: Monitor MVP — 端到端事件收集與查詢

## 需求來源

本提案源自 [blog monitoring 教學系列](https://github.com/tarrragon/blog/blob/main/content/monitoring/) 的實作驗證需求。教學建立了理論框架（四類事件、log schema、transport 規格），需要 monitor repo 作為驗證場——實作過程的撞牆經驗回補教學章節，形成教學 × 實作互補循環。

既有產出：
- `schema/event.schema.json` — 事件格式契約（v1）
- `docs/transport.md` — SDK ↔ collector 通訊規格
- blog 教學模組一~八 — 理論框架與設計原則

## 問題描述

目前有完整的理論框架和 schema 定義，但缺少可運行的實作來驗證理論假設。需要一個最小可行的端到端路徑：SDK 埋點 → collector 收集 → 儲存 → 查詢，以此驗證 schema 設計的實用性、transport 規格的可行性、以及 SQLite 作為儲存後端的效能邊界。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | collector（Go）、sdk-python（Python）、schema |
| 檔案 | collector/ 全新建、sdk-python/ 全新建、schema/ 可能微調 |
| 用例 | 本機腳本監控（Hook 事件收集）、端到端事件流驗證 |

## 範圍界定

> 一個提案 = 一個版本的明確功能範圍。

### 本提案要做的（In Scope）

**Collector 核心（5 項）**：

1. `POST /v1/events` — 接收 JSON 事件、依 `schema/event.schema.json` 驗證、寫入 SQLite
2. `GET /v1/events` — 按 type / name / time range 查詢事件
3. `GET /health` — 回傳 collector 狀態（uptime、事件計數、儲存大小）
4. 分層保留 — Downsample（超過 N 天的事件降採樣）+ Purge（超過 M 天刪除）定期執行
5. 至少一條 rule — error count > N 時寫檔案通知（rule engine 最小驗證）

**SDK（1 個語言 — Python）**：

6. 五個公開 API — `init()` / `event()` / `error()` / `flush()` / `close()`
7. 攢批送出 — buffer + flush interval（預設每 5 秒或累積 10 筆）
8. 離線容錯 — collector 不可達時 buffer 在記憶體（FIFO，上限 100 筆），恢復後重試

**Dashboard（最小視圖）**：

9. Error 列表 — 最近 N 筆 error，按 name 分群
10. 事件時間軸 — 按時間排序的事件流

### 本提案不做的（Out of Scope）

- PostgreSQL backend → 規模超過 SQLite 邊界時另建提案
- 水平擴展 / HA → 單機零依賴是刻意的設計選擇
- sdk-flutter / sdk-js → 依開發優先序（CLAUDE.md §4），collector + sdk-python 先行
- Funnel / cohort / A/B test 分析 → 教學模組八範疇，超出 MVP
- TUI dashboard → CLI 查詢足夠驗證
- Container image 發佈 → 部署議題，非 MVP
- Transport 加密（HTTPS / TLS）→ 教學模組七範疇，MVP 先用 plain HTTP
- SDK redaction API → 教學模組七範疇，MVP 不含去識別化

## 提案方案

### 架構概要

```
SDK (Python)                    Collector (Go)
    |                               |
    | POST /v1/events (JSON)        |
    |-----------------------------> |
    |                               |-> Schema 驗證
    |         200/400/207           |     |
    | <---------------------------- |-> SQLite 寫入
    |                               |     |
    |                               |-> Rule Engine 評估
    |                               |
    | GET /v1/events?type=error      |
    |-----------------------------> |
    |         JSON response         |
    | <---------------------------- |
```

### 技術選型

| 決策 | 選擇 | 理由 |
|------|------|------|
| Collector 語言 | Go | 單一 binary、零外部依賴、跨平台編譯 |
| 儲存後端 | SQLite（嵌入式） | 零部署成本、WAL 模式支援併發讀寫、自用場景足夠 |
| SDK 首選語言 | Python | 框架 Hook 監控可立即用、驗證 schema 設計最快 |
| Transport | HTTP POST JSON | 比 gRPC/OTLP 簡單、無依賴、適合小規模 |
| Dashboard | Query API + CLI | 零前端依賴、grep 友好 |

### 教學模組對應

| MVP 項目 | 對應教學模組 |
|---------|-------------|
| 事件格式驗證 | 模組二：Log Schema |
| SDK 五個 API | 模組三：SDK 設計 |
| Collector 職責鏈 | 模組四：Collector 設計 |
| Python 平台特性 | 模組五：平台適配 |

### SQLite 效能預期

教學模組四的 SQLite 效能基準提供預期範圍，MVP 實作後需實機驗證：

| 指標 | 教學預期 | 實測目標 |
|------|---------|---------|
| 寫入吞吐 | Mac SSD 約 5,000 inserts/sec | 實測確認，偏差 > 2 倍回補教學 |
| 有索引查詢（10 萬筆） | < 100ms | 用真實事件資料驗證 |
| Downsample job 鎖定時間 | 數秒內 | 確認不阻塞 ingestion |

## 驗收條件

> 對應「要做的」清單，每項至少一個可驗證條件。

- [ ] `POST /v1/events` 接受單筆和批次事件，依 schema 驗證，回傳 200/400/207
- [ ] `GET /v1/events` 支援 type / name / time range 篩選，回傳 JSON 陣列
- [ ] `GET /health` 回傳 uptime、事件計數、儲存大小
- [ ] Downsample + Purge 定期執行且不阻塞寫入超過 1 秒
- [ ] 至少一條 rule（error count > N → 寫檔案）可觸發
- [ ] Python SDK `init/event/error/flush/close` 五個 API 可用
- [ ] SDK 攢批送出：buffer 滿或 interval 到時 flush
- [ ] SDK 離線容錯：collector 不可達時 buffer 保持，恢復後重試
- [ ] Query API 可列出最近 N 筆 error 並按 name 分群
- [ ] Query API 可按時間排序列出事件流
- [ ] **端到端驗收**：啟動 collector → SDK init → SDK 送 3 筆事件（1 event + 1 error + 1 lifecycle）→ query API 查到這 3 筆

## Reality Test / 觸發案例實證

### 觸發案例

1. blog 教學系列完成 8 個模組的理論框架後，缺少實作驗證場——理論假設（schema 可用性、SQLite 效能邊界、SDK API 一致性）需要程式碼證明
2. 框架 Hook 系統（`.claude/hooks/`）已有 90+ 個 Python Hook，是 sdk-python 的天然驗證場景——Hook 執行結果可直接作為監控事件送出
3. `schema/event.schema.json` 和 `docs/transport.md` 已定義但從未被程式碼消費過

### 假設列舉

- 假設 1：JSON Schema 驗證在 Go 端效能足夠（每筆 < 1ms）
- 假設 2：SQLite WAL 模式在單機場景下不會頻繁 `database is locked`
- 假設 3：Python SDK 的攢批機制在 Hook 短生命週期中仍能可靠 flush

### 實驗驗證

| 假設 | 驗證方式 | 執行的實驗/觀察 | 結果 |
|------|---------|----------------|------|
| 假設 1 | collector 實作後 benchmark | 待實測 | 待定 |
| 假設 2 | 多 SDK 同時 flush 壓測 | 待實測 | 待定 |
| 假設 3 | Hook 場景集成測試 | 待實測 | 待定 |

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | schema 設計（blog 理論審查）、transport 規格（blog 設計原則）、四類事件分類（blog 模組一） |
| 未驗證 | SQLite 實機效能、SDK 短生命週期 flush 可靠性、rule engine 觸發延遲 |

---

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| SQLite 寫入瓶頸比預期低 | 自用場景仍可能遇到 lock | 實測後決定是否提前引入 write buffer |
| Python SDK 在 Hook 場景 flush 不完整 | 事件丟失 | `atexit` + `close()` 雙保險；撞牆記錄到 `docs/challenges/` |
| schema v1 在實作中發現欄位不足 | 需改 schema 並同步所有消費端 | MVP 只有 collector + sdk-python 兩端，同步成本低 |

## 討論記錄

### 2026-06-21

- 從 blog 教學規劃萃取 MVP 範圍
- 確認開發優先序：collector → sdk-python（CLAUDE.md §4）
- 確認教學 × 實作互補循環：撞牆記錄 → 回補教學、疑慮 → 回顧教學確認方向

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | spec/core/event-schema.md | 2026-06-21 | created |
| 規格 | spec/collector/ingestion.md | 2026-06-21 | created |
| 規格 | spec/collector/query.md | 2026-06-21 | created |
| 規格 | spec/collector/storage.md | 2026-06-21 | created |
| 規格 | spec/collector/rule-engine.md | 2026-06-21 | created |
| 規格 | spec/sdk/python-sdk.md | 2026-06-21 | created |
| 用例 | usecases/UC-01-e2e-event-flow.md | 2026-06-21 | created |
| 用例 | usecases/UC-02-hook-monitoring.md | 2026-06-21 | created |
| 用例 | usecases/UC-03-error-investigation.md | 2026-06-21 | created |
