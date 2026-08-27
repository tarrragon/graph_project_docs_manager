---
id: UC-06
title: "Benchmark CLI 效能基準實測"
status: draft
source_proposal: PROP-004
created: "2026-06-23"
updated: "2026-06-23"
version: "1.0"

primary_actor: "Collector 開發者 / 部署者"
secondary_actors: ["SQLite Storage (Go)"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-010, SPEC-007]
related_usecases: [UC-01]
ticket_refs: [0.2.0-W1-003.1, 0.2.0-W3-001]
---

# UC-06: Benchmark CLI 效能基準實測

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-06 |
| 用例名稱 | Benchmark CLI 效能基準實測 |
| 主要行為者 | Collector 開發者 / 部署者 |
| 利益關係人 | 部署者（在自己的硬體實測吞吐與延遲，驗證教學預期數字）；教學維護者（實測偏差 > 2 倍須回補教學） |
| 前置條件 | collector binary 已編譯；具備可寫入的暫存目錄 |
| 成功保證 | 取得本機環境的寫入吞吐（events/sec）、查詢延遲百分位（p50/p95/p99），且 benchmark 使用獨立 DB 不影響 production 資料 |

## 主要成功場景

1. **灌入測試資料（seed）**
   - 開發者執行 `collector benchmark seed --events=100000 --db-path=./bench.db`
   - 系統按四類比例（event 60% / error 15% / metric 15% / lifecycle 10%）產生事件、通過 `event.schema.json` 驗證後寫入獨立 DB，輸出各類筆數與 events/sec

2. **寫入吞吐測試（write）**
   - 開發者執行 `collector benchmark write --events=10000 --batch=100`
   - 系統在乾淨 DB 上量測 `Storage.Store()` 吞吐，輸出 `Throughput` 與 `Latency p50/p95/p99`，各指標獨佔一行可被 grep 擷取

3. **查詢延遲測試（query）**
   - 開發者執行 `collector benchmark query --type=error --repeat=5`
   - 系統重複查詢取中位數（排除冷啟動），輸出 `Duration` 與掃描/回傳列數

4. **解讀與回報**
   - 開發者比對輸出數字與教學模組四預期範圍
   - 偏差超過 2 倍時，依 CLAUDE.md §3 回補教學（docs/challenges/）

## 替代場景

### 06a: 單筆 vs 批次吞吐對照

| 步驟 | 行為 |
|------|------|
| 1 | 開發者先跑 `--batch=1`（單筆）再跑 `--batch=100`（批次） |
| 2 | 系統兩次皆輸出吞吐，批次模式吞吐高於單筆 |
| 3 | 開發者據此選擇 SDK flush 批次大小 |

### 06b: 聚合查詢延遲

| 步驟 | 行為 |
|------|------|
| 1 | 開發者執行 `collector benchmark query --group-by=name` |
| 2 | 系統掃描全表做聚合，輸出 Duration 與回傳群組數 |

## 例外場景

### EX-06-01: 查詢前未 seed（DB 不存在）

| 項目 | 值 |
|------|-----|
| 觸發條件 | `benchmark query` 指向的 `--db-path` 檔案不存在 |
| 處理方式 | 系統不建立空 DB，直接報錯 |
| 使用者提示 | `run 'collector benchmark seed' first` |
| 恢復策略 | 開發者先執行 seed 再重試 query |

### EX-06-02: benchmark 誤指向 production DB

| 項目 | 值 |
|------|-----|
| 觸發條件 | `--db-path` 等於 `collector.yaml` 的 `storage.sqlite.path` |
| 處理方式 | benchmark 預設路徑與 production 不同（NFR-01 隔離）；write 預設 `./benchmark-write.db` 避免與 seed 資料混用 |
| 使用者提示 | 文件警示 `--db-path` 不可指向 production |
| 恢復策略 | 改用獨立路徑重跑 |

## 驗收條件

### 功能驗收

- [ ] seed/write/query 三子命令主場景可正常執行
- [ ] write 同時輸出吞吐與延遲百分位，且關鍵指標可被 grep 擷取
- [ ] query 重複取中位數，DB 不存在時給出 seed 提示

### 邊界條件

- [ ] benchmark 全程使用獨立 DB，不影響 production 資料
- [ ] 相同 `--events` 產生相同四類分佈比例（確定性）

### 資訊鏈整合測試（核心要求）

| 資訊鏈 | 整合測試 |
|--------|---------|
| seed 灌資料 → write 量測寫入 → query 量測查詢 → 輸出可解析指標 | IT-06-01（待建，Phase 2 BDD 整合測試 ticket） |

### 效能要求

| 指標 | 目標值 |
|------|--------|
| benchmark 自身額外開銷 | 不顯著扭曲被測 Storage 純效能（直接呼叫 BasicStorage，不經 HTTP handler） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-23 | 初始版本，從 SPEC-010 + PROP-004 + 教學 sqlite-performance-baseline.md 萃取（v0.1.0 BDD 模式對齊，0.2.0-W1-006） |
