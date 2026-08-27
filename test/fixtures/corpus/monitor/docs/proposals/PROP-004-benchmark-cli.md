---
id: PROP-004
title: "Benchmark CLI — SQLite 效能基準實測工具"
status: draft
source: development
proposed_by: "效能驗證需求"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.2.0
priority: P1
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: [UC-06]
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-004: Benchmark CLI — SQLite 效能基準實測工具

## 需求來源

PROP-001 的三個未驗證假設（JSON Schema 驗證效能、SQLite WAL 併發、SDK flush 可靠性）需要實測數據。教學模組四 [SQLite Backend 效能基準](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/sqlite-performance-baseline.md) 提供了預期範圍和實測方法指引，需要 collector 內建 benchmark 命令讓使用者在自己的環境實測。

教學依據：
- [模組四：SQLite Backend 效能基準](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/sqlite-performance-baseline.md) — 預期數字、實測方法、dashboard 刷新 vs 查詢延遲對照表

## 問題描述

教學中的效能數字是推導值（基於 SQLite 技術特性 + 業界基準），需要程式碼驗證。不同硬體（Mac SSD / Linux VPS / Raspberry Pi）的實際效能差異大，使用者需要一行命令就能實測自己環境的吞吐和延遲。偏差超過教學預期 2 倍的結果須回補教學。

## 範圍界定

### 本提案要做的（In Scope）

**三個子命令**：

1. `collector benchmark write` — 寫入吞吐測試
   - `--events=N` 總筆數（預設 10000）
   - `--batch=N` 每批筆數（1=單筆、100=批次）
   - 輸出：total duration、events/sec、p50/p95/p99 latency

2. `collector benchmark query` — 查詢延遲測試
   - `--type=error` / `--session-id=random` / `--group-by=name`
   - 輸出：query duration、rows scanned、rows returned

3. `collector benchmark seed` — 灌入測試資料
   - `--events=N` 總筆數（預設 100000）
   - 產生四類事件的合理分佈（event 60% / error 15% / metric 15% / lifecycle 10%）

### 本提案不做的（Out of Scope）

- PostgreSQL benchmark（需先有 PostgreSQL backend）
- 網路層 benchmark（HTTP latency，用外部工具 wrk / hey）
- 持續壓測（long-running stress test）
- 自動化效能回歸（CI 中跑 benchmark 比對基準）

## 驗收條件

- [ ] `collector benchmark write --events=10000 --batch=1` 完成並輸出 events/sec + latency 百分位
- [ ] `collector benchmark write --events=10000 --batch=100` 完成，吞吐高於單筆模式
- [ ] `collector benchmark seed --events=100000` 灌入 10 萬筆測試資料
- [ ] `collector benchmark query --type=error` 輸出 query duration
- [ ] `collector benchmark query --group-by=name` 輸出 query duration
- [ ] 輸出格式 human-readable + 可被 grep 擷取
- [ ] **實測結果 vs 教學預期**：Mac SSD 環境下批次寫入 > 10,000/sec（教學預期 ~30,000/sec，接受 1/3 即 10K 作為下限）

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Pure Go SQLite driver 效能低於教學預期 | 預期數字需修正 | 實測後回補教學，記錄到 docs/challenges/ |
| Benchmark 本身佔用資源影響結果 | 數字不準 | seed 和 benchmark 分步驟，避免同時讀寫 |
