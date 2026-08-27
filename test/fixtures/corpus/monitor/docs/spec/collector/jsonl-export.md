---
id: SPEC-011
title: "JSONL 匯出與備份"
status: draft
source_proposal: PROP-005
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"
owner: ""

domain: collector
subdomain: export

related_usecases: [UC-07]
related_specs: [SPEC-007, SPEC-003, SPEC-004]
implements_requirements: []
depends_on_domains: [core]
---

# JSONL 匯出與備份

## 概述

Collector 提供 JSONL（JSON Lines）格式的事件匯出和匯入功能。JSONL 作為人類可讀的匯出格式，支援 grep/jq 臨時查詢、SQLite 損壞時的資料重建、未來 PostgreSQL 遷移的中介格式。另提供 `--jsonl-mirror` 啟動參數做即時備份寫入。

教學依據：[模組四：JSONL 匯出與備份格式](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/jsonl-storage.md)

## 功能需求

### FR-01: Export — 從 SQLite 匯出 JSONL

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-005 |
| 對應用例 | - |

**描述**：`collector export` 從當前 storage backend 逐筆讀取事件，以 JSONL 格式（每行一個 JSON 物件）輸出。Streaming 實作——逐筆讀取寫出，記憶體使用與事件總量無關。

**CLI 介面**：

```
collector export [flags]

Flags:
  --format=FORMAT    輸出格式（預設 jsonl，目前唯一支援值）
  --since=DATETIME   起始時間過濾（RFC3339 或 YYYY-MM-DD，預設無下限）
  --until=DATETIME   結束時間過濾（RFC3339 或 YYYY-MM-DD，預設無上限）
  --type=TYPE        事件類型過濾（event / error / metric / lifecycle）
  --output=PATH      輸出檔案路徑（預設 stdout）
  --config=PATH      設定檔路徑（讀取 storage 連線資訊）
```

**JSONL 格式**：

每行一個 JSON 物件，欄位順序與 `event.schema.json` 一致。每行以 `\n` 結尾（Unix line ending）。

```jsonl
{"v":1,"type":"event","timestamp":"2026-06-22T10:00:00Z","source":{"sdk":"monitor-python","platform":"linux"},"name":"page_view","data":{"url":"/home"}}
{"v":1,"type":"error","timestamp":"2026-06-22T10:00:01Z","source":{"sdk":"monitor-flutter","platform":"ios"},"name":"network_error","error":{"message":"timeout","type":"NetworkException"}}
```

**Streaming 實作**：

使用 `storage.Query()` 搭配 `LIMIT` + `OFFSET` 分頁（每頁 1000 筆），逐頁讀取逐行寫出。或使用 cursor-based iteration（若 storage interface 支援）。記憶體使用上限 = 單頁事件的記憶體（約 1000 筆 x 400 bytes = 400KB）。

**驗收標準**：

- [ ] `collector export --format=jsonl` 輸出所有事件到 stdout
- [ ] `collector export --since=2026-06-20 --type=error` 過濾匯出
- [ ] `collector export --output=events.jsonl` 寫入檔案
- [ ] 10 萬筆事件匯出時記憶體使用 < 50MB
- [ ] 輸出的每行可被 `jq .` 正確解析
- [ ] 空資料庫時輸出 0 行（不報錯）

### FR-02: Import — 從 JSONL 匯入到 Storage

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-005 |
| 對應用例 | - |

**描述**：`collector import` 從 JSONL 檔案逐行讀取事件，批次寫入當前 storage backend。支援去重（基於 timestamp + session_id + name 組合）。

**CLI 介面**：

```
collector import [flags]

Flags:
  --file=PATH      JSONL 檔案路徑（必填）
  --batch=N        每批寫入筆數（預設 100）
  --config=PATH    設定檔路徑（讀取 storage 連線資訊）
```

**去重策略**：

匯入前查詢 storage 是否已存在相同 `(timestamp, session_id, name)` 組合的事件。匹配則跳過，不匹配則寫入。去重在每個 batch 內執行（batch 內先查詢再寫入）。

**錯誤處理**：

| 情境 | 行為 |
|------|------|
| 某行 JSON 格式不合法 | 跳過該行，stderr 輸出行號 + 錯誤訊息，繼續處理 |
| 某行通過 JSON 但不通過 schema 驗證 | 跳過該行，stderr 輸出行號 + 驗證錯誤 |
| Storage 寫入失敗 | 中止匯入，輸出已匯入筆數 + 失敗位置 |
| 檔案不存在 | 回傳 error + 提示訊息 |

**輸出格式**：

```
Importing from events.jsonl ...
  Processed: 100000 lines
  Imported:  98500
  Skipped:   1200 (duplicates)
  Errors:    300 (invalid)
Done in 8.5s
```

**驗收標準**：

- [ ] `collector import --file=events.jsonl` 匯入成功
- [ ] 匯入後的事件可透過 query API 查到
- [ ] 重複匯入相同檔案不產生重複事件
- [ ] 不合法行被跳過，不影響後續行的匯入
- [ ] **往返驗證**：export → import → export，兩次 export 的內容一致

### FR-03: JSONL Mirror — 即時備份寫入

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-005 |
| 對應用例 | - |

**描述**：`collector serve --jsonl-mirror=/path/to/events/` 啟動參數，事件寫入 SQLite 的同時 append 到 JSONL 檔案。實作為 storage 層的 decorator：寫入 SQLite 成功後再 append 到 JSONL 檔案。

**一天一檔**：

- 檔案命名：`events-YYYY-MM-DD.jsonl`（如 `events-2026-06-22.jsonl`）
- UTC 日期變更時切換到新檔案
- 當天檔案保持未壓縮（支援 `tail -f` 和 append）
- 歷史檔案（非當天）在日期切換時自動 gzip 壓縮為 `events-YYYY-MM-DD.jsonl.gz`

**保留策略**：

```yaml
# collector.yaml — 需擴充 SPEC-007 Config（FR-04）
jsonl:
  mirror_path: "/data/events/"  # 空字串 = 不啟用
  retention_days: 30            # 預設 30 天
  compress: true                # 歷史檔案 gzip 壓縮
```

超過 `retention_days` 的壓縮檔在日期切換時自動清理。

**錯誤處理**：

| 情境 | 行為 |
|------|------|
| JSONL 寫入失敗（磁碟滿） | 記錄 warning 日誌，SQLite 寫入不受影響 |
| Mirror 目錄不存在 | 啟動時自動建立 |
| 壓縮失敗 | 記錄 warning 日誌，保留未壓縮檔案 |

**驗收標準**：

- [ ] `--jsonl-mirror` 啟動後，POST 事件同時寫入 SQLite 和 JSONL
- [ ] JSONL 檔案為一天一檔格式
- [ ] UTC 日期切換時自動壓縮前一天檔案
- [ ] 超過保留天數的檔案自動清理
- [ ] JSONL 寫入失敗不影響 SQLite 主路徑

## 非功能需求

### NFR-01: Streaming 記憶體使用

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | 匯出 10 萬筆事件記憶體 < 50MB |

**描述**：Export 和 import 均使用 streaming 實作。記憶體使用與事件總量無關，僅與單頁/單批大小正比。

### NFR-02: Export 不阻塞寫入

| 項目 | 值 |
|------|-----|
| 類型 | 可用性 |
| 指標 | Export 期間 ingestion 延遲增幅 < 20% |

**描述**：SQLite WAL mode 支援讀寫分離。Export 使用 read transaction，不取得 write lock，不阻塞 ingestion 寫入。

## 介面規格

### CLI 子命令結構

```
collector export  [--format=jsonl] [--since=DATETIME] [--until=DATETIME]
                  [--type=TYPE] [--output=PATH] [--config=PATH]

collector import  --file=PATH [--batch=N] [--config=PATH]
```

### Serve 啟動參數擴充

```
collector serve [既有 flags] [--jsonl-mirror=PATH]
```

`--jsonl-mirror` 對應 `collector.yaml` 的 `jsonl.mirror_path`。CLI flag 覆蓋設定檔。

### JSONL 行格式

每行為一個完整的 JSON 物件，欄位與 `event.schema.json` 一致。欄位中的 `\n` 必須 escape 為 `\\n`（JSON 標準要求）。行以 `\n` 結尾。

不完整的最後一行（程序崩潰時可能產生）在 import 時視為不合法行，跳過處理。

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| JSONL 為匯出/備份格式 | 非主要 storage backend | 不實作 JSONL 查詢引擎 |
| Streaming 實作 | 記憶體使用與總量無關 | 大量匯出不 OOM |
| Mirror 為 best-effort | SQLite 寫入成功 > JSONL 寫入成功 | JSONL 失敗只記 warning |
| `--jsonl-mirror` 需擴充 SPEC-007 Config | `collector.yaml` 新增 `jsonl` 區段 | SPEC-007 FR-04 Config 結構需同步更新 |
| 去重為 application-level | 非 unique constraint | 效能可接受但非 100% 防重（併發匯入可能漏） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本，從 PROP-005 + 教學 jsonl-storage.md 萃取 |
