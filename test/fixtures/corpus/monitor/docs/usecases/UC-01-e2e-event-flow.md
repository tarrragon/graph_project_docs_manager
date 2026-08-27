---
id: UC-01
title: "端到端事件流"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.0"

primary_actor: "開發者"
secondary_actors: ["SDK (Python)", "Collector (Go)"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-001, SPEC-002, SPEC-003, SPEC-004, SPEC-006, SPEC-007]
related_usecases: [UC-02, UC-03]
ticket_refs: []
---

# UC-01: 端到端事件流

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-01 |
| 用例名稱 | 端到端事件流 |
| 主要行為者 | 開發者 |
| 利益關係人 | 開發者（驗證 schema 和 transport 規格的可行性） |
| 前置條件 | collector 已啟動、SDK 已安裝 |
| 成功保證 | 3 筆事件（event + error + lifecycle）從 SDK 送出後可在 query API 查到 |

## 主要成功場景

1. **啟動 collector**
   - 開發者執行 `./monitor-collector`
   - Collector 啟動，載入 schema 和 rules 設定，監聽 `localhost:9090`
   - `GET /health` 回傳正常狀態

2. **SDK 初始化**
   - 開發者在 Python 腳本中呼叫 `Monitor.init(endpoint="http://localhost:9090/v1/events", app="test", version="1.0.0")`
   - SDK 建立 session、記錄 `lifecycle.session.start` 事件、啟動 flush 計時器

3. **送出三類事件**
   - 開發者呼叫 `Monitor.event("button.click", {"button": "connect"})`
   - 開發者呼叫 `Monitor.error("Connection timeout", {"step": "ws_connect"})`
   - SDK buffer 累積 3 筆（含 init 時的 lifecycle 事件）

4. **flush 送出**
   - 開發者呼叫 `Monitor.flush()`
   - SDK 將 buffer 中的事件以批次格式 POST 到 collector
   - Collector 驗證 schema、寫入 SQLite、回傳 200

5. **查詢驗證**
   - 開發者 `GET /v1/events?limit=10`
   - 回傳包含剛送出的 3 筆事件
   - 按 type 篩選 `GET /v1/events?type=error` 只回傳 error 事件

## 替代場景

### 01a: 批次中部分事件格式錯誤

**觸發條件**：SDK 送出的批次中有事件缺少必填欄位

1. Collector 逐一驗證事件
2. 合法事件寫入 SQLite
3. 回傳 207，body 含 errors 陣列
4. SDK 記錄 warning，不重試失敗事件

## 例外場景

### EX-01-01: Collector 未啟動

| 項目 | 值 |
|------|-----|
| 觸發條件 | SDK flush 時 collector 不可達 |
| 處理方式 | SDK 保留事件在 buffer，下次 flush 重試 |
| 恢復策略 | 啟動 collector 後事件自動送出 |

### EX-01-02: Schema 驗證全部失敗

| 項目 | 值 |
|------|-----|
| 觸發條件 | SDK 版本與 collector schema 不匹配 |
| 處理方式 | Collector 回傳 400，SDK 記錄 error |
| 恢復策略 | 升級 SDK 或更新 schema |

## 驗收條件

### 功能驗收

- [ ] Collector 啟動後 `/health` 回傳正常
- [ ] SDK init → event → error → flush → close 完整流程可執行
- [ ] flush 後 query API 查到所有送出的事件
- [ ] 按 type 篩選回傳正確結果
- [ ] 按 time range 篩選回傳正確結果

### 邊界條件

- [ ] 空 buffer flush 不報錯
- [ ] 同時送 100 筆事件（buffer 上限）成功
- [ ] collector 重啟後歷史事件仍可查（SQLite 持久化）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本，PROP-001 端到端驗收場景 |
