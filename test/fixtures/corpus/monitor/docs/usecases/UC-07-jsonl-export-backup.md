---
id: UC-07
title: "JSONL 匯出與備份"
status: draft
source_proposal: PROP-005
created: "2026-06-23"
updated: "2026-06-23"
version: "1.0"

primary_actor: "運維 / Collector 開發者"
secondary_actors: ["SQLite Storage (Go)", "檔案系統"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-011, SPEC-007]
related_usecases: [UC-01]
ticket_refs: [0.2.0-W1-003.2, 0.2.0-W3-002, 0.2.0-W3-004]
---

# UC-07: JSONL 匯出與備份

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-07 |
| 用例名稱 | JSONL 匯出與備份 |
| 主要行為者 | 運維 / Collector 開發者 |
| 利益關係人 | 運維（人類可讀備份、SQLite 損壞時的重建來源）；未來遷移者（JSONL 作 SQLite → PostgreSQL 中介格式） |
| 前置條件 | collector 已啟動且 SQLite 內有事件資料 |
| 成功保證 | 事件可匯出為逐行 JSON（jq 可解析），可重新匯入且去重，往返匯出內容一致；啟用 mirror 時事件即時 append 到一天一檔的 JSONL |

## 主要成功場景

1. **匯出（export）**
   - 運維執行 `collector export --format=jsonl --output=events.jsonl`
   - 系統以 streaming（分頁 1000 筆）逐筆讀出逐行寫出，記憶體與事件總量無關，每行為一個完整 JSON 物件

2. **過濾匯出**
   - 運維執行 `collector export --since=2026-06-20 --type=error`
   - 系統只輸出符合時間與類型的事件

3. **匯入（import）**
   - 運維執行 `collector import --file=events.jsonl --batch=100`
   - 系統逐行讀取、批次寫入，依 `(timestamp, session_id, name)` 去重，輸出 Processed/Imported/Skipped/Errors 計數

4. **往返一致驗證**
   - 運維對同一批資料執行 export → import → export
   - 兩次 export 內容一致（FR-02 往返驗證）

## 替代場景

### 07a: 即時備份（jsonl-mirror）

| 步驟 | 行為 |
|------|------|
| 1 | 運維以 `collector serve --jsonl-mirror=/data/events/` 啟動 |
| 2 | 每筆事件寫入 SQLite 成功後 append 到 `events-YYYY-MM-DD.jsonl` |
| 3 | UTC 日期切換時，前一天檔案自動 gzip 為 `.gz`，當天檔保持未壓縮（支援 tail -f） |
| 4 | 超過 `retention_days` 的壓縮檔在日期切換時自動清理 |

### 07b: 空資料庫匯出

| 步驟 | 行為 |
|------|------|
| 1 | 運維對空 DB 執行 export |
| 2 | 系統輸出 0 行且不報錯 |

## 例外場景

### EX-07-01: 匯入檔含不合法行

| 項目 | 值 |
|------|-----|
| 觸發條件 | 某行 JSON 格式不合法，或通過 JSON 但不通過 schema 驗證 |
| 處理方式 | 跳過該行，stderr 輸出行號 + 錯誤訊息，繼續處理後續行 |
| 使用者提示 | 結束時 Errors 計數反映被跳過行數 |
| 恢復策略 | 運維檢視 stderr 修正來源檔後重匯（去重保證不重複） |

### EX-07-02: Mirror 寫入失敗（磁碟滿）

| 項目 | 值 |
|------|-----|
| 觸發條件 | mirror 啟用下 JSONL append 失敗（磁碟滿 / 權限） |
| 處理方式 | best-effort——記錄 warning 日誌，SQLite 主路徑寫入不受影響 |
| 使用者提示 | warning 日誌含失敗原因 |
| 恢復策略 | 運維釋放磁碟空間；SQLite 資料完整，可事後 export 補備份 |

### EX-07-03: 程序崩潰產生的不完整末行

| 項目 | 值 |
|------|-----|
| 觸發條件 | mirror 過程程序崩潰，JSONL 末行不完整 |
| 處理方式 | import 時不完整末行視為不合法行，跳過 |
| 使用者提示 | Errors 計數 +1 |
| 恢復策略 | 無需手動處理，其餘行正常匯入 |

## 驗收條件

### 功能驗收

- [ ] export 主場景輸出所有事件，每行可被 `jq .` 解析
- [ ] import 去重正確，重複匯入同檔不產生重複事件
- [ ] export → import → export 往返內容一致

### 邊界條件

- [ ] 空資料庫 export 輸出 0 行不報錯
- [ ] 不合法行被跳過，不影響後續行匯入
- [ ] mirror 寫入失敗不影響 SQLite 主路徑

### 資訊鏈整合測試（核心要求）

| 資訊鏈 | 整合測試 |
|--------|---------|
| 變更偵測 → export 匯出 → import 匯入 → 去重 → 往返一致性驗證 | IT-07-01（待建，Phase 2 BDD 整合測試 ticket） |

### 效能要求

| 指標 | 目標值 |
|------|--------|
| 匯出 10 萬筆記憶體使用 | < 50MB（streaming，與總量無關） |
| Export 期間 ingestion 延遲增幅 | < 20%（WAL 讀寫分離，不取 write lock） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-23 | 初始版本，從 SPEC-011 + PROP-005 + 教學 jsonl-storage.md 萃取（v0.1.0 BDD 模式對齊，0.2.0-W1-006） |
