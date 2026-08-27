---
id: PROP-005
title: "JSONL 匯出與備份"
status: draft
source: development
proposed_by: "資料可攜性需求"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.2.0
priority: P2
evaluation_level: standard

outputs:
  spec_refs: []
  usecase_refs: [UC-07]
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-005: JSONL 匯出與備份

## 需求來源

教學模組四 [JSONL 匯出與備份格式](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/jsonl-storage.md) 定義了 JSONL 作為匯出和備份格式的設計。JSONL 是 SQLite → PostgreSQL 遷移的中介格式，也是 SQLite 損壞時的重建來源。

教學依據：
- [模組四：JSONL 匯出與備份格式](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/jsonl-storage.md) — 一天一檔、append-only、gzip 壓縮、保留策略
- [模組四：規模演進](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/scaling-evolution.md) — JSONL 作為遷移中介格式

## 問題描述

Collector 目前只有 SQLite 儲存，缺少人類可讀的匯出格式。開發者需要 grep/jq 做臨時查詢、SQLite 損壞時需要重建來源、未來切換到 PostgreSQL 時需要遷移格式。

## 範圍界定

### 本提案要做的（In Scope）

**匯出命令**：

1. `collector export --format=jsonl` — 從 SQLite 匯出事件為 JSONL
   - `--since` / `--until` 時間範圍過濾
   - `--type` 事件類型過濾
   - Streaming 輸出（逐筆讀取寫出，記憶體使用與總量無關）
   - 輸出到 stdout 或 `--output=<file>`

**匯入命令**：

2. `collector import --file=<jsonl>` — 從 JSONL 匯入到當前 storage backend
   - 批次 INSERT（每 100 筆一個 transaction）
   - 重複事件跳過（基於 timestamp + session_id + name）

**同步寫入模式**（可選）：

3. `--jsonl-mirror=/path/to/events/` — 啟動參數，事件寫入 SQLite 的同時 append 到 JSONL 檔案
   - 一天一檔（`events-2026-06-22.jsonl`）
   - 歷史檔案自動 gzip 壓縮
   - 保留天數可設定

### 本提案不做的（Out of Scope）

- JSONL 作為主要 storage backend（教學明確定位為匯出/備份格式）
- 壓縮排程自動化（用 cron 或 collector 內建排程處理）
- 加密匯出（匯出為明文，存取控制由檔案系統處理）

## 驗收條件

- [ ] `collector export --format=jsonl` 匯出所有事件，每行一個 JSON 物件
- [ ] `collector export --since=2026-06-20 --type=error` 過濾匯出
- [ ] 10 萬筆事件匯出記憶體使用 < 50MB（streaming 驗證）
- [ ] `collector import --file=events.jsonl` 匯入成功，query API 可查到
- [ ] 重複匯入不產生重複事件
- [ ] JSONL 檔案可被 `grep` / `jq` / `tail -f` 正確處理
- [ ] **往返驗證**：export → import → export，兩次 export 的內容一致

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 大量匯出時 SQLite read lock 影響寫入 | Ingestion 延遲 | WAL mode 讀寫分離；匯出用 snapshot isolation |
| JSONL 檔案大小超預期 | 磁碟空間 | gzip 壓縮（80-90% 壓縮率）；保留天數限制 |
