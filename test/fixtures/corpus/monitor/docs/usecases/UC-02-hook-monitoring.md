---
id: UC-02
title: "Hook 執行監控"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.0"

primary_actor: "框架開發者"
secondary_actors: ["Claude Code Hook 系統", "SDK (Python)", "Collector"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-001, SPEC-002, SPEC-003, SPEC-004, SPEC-005, SPEC-006, SPEC-007]
related_usecases: [UC-01, UC-03]
ticket_refs: []
---

# UC-02: Hook 執行監控

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-02 |
| 用例名稱 | Hook 執行監控 |
| 主要行為者 | 框架開發者 |
| 利益關係人 | 框架開發者（追蹤 90+ Hook 的執行狀況） |
| 前置條件 | collector 已啟動、sdk-python 已安裝在 Hook 環境 |
| 成功保證 | Hook 執行事件被 collector 收集，可查詢成功/失敗/耗時 |

## 主要成功場景

1. **Hook 開始執行**
   - Claude Code 觸發 Hook（如 SessionStart）
   - Hook 腳本開頭 `Monitor.init(...)` + `Monitor.event("hook.start", {"hook": "branch-status-reminder", "event": "SessionStart"})`

2. **Hook 執行完成**
   - Hook 正常結束
   - `Monitor.event("hook.complete", {"hook": "branch-status-reminder", "duration_ms": 42, "exit_code": 0})`
   - `Monitor.close()` 觸發 flush + session end

3. **查詢 Hook 執行狀況**
   - `GET /v1/events?name=hook.*` 列出所有 Hook 事件
   - 按 hook name 篩選特定 Hook 的歷史

4. **Rule 觸發告警**
   - 過去 1 小時 Hook error 超過 10 筆
   - Rule engine 產生 `.alert` 檔案

## 替代場景

### 02a: Hook 執行失敗

**觸發條件**：Hook 腳本拋出未捕獲的 Exception

1. Hook 的 `except` 區塊捕獲錯誤
2. `Monitor.error(e, {"hook": "branch-status-reminder", "step": "validation"})`
3. `Monitor.close()` 確保 error 事件被 flush
4. Collector 收到 error 類型事件

### 02b: Hook 生命週期過短（< 1 秒）

**觸發條件**：Hook 腳本快速完成，flush 計時器尚未觸發

1. `Monitor.close()` 內的 `flush()` 強制送出
2. `atexit` 作為備份保險
3. 所有 buffer 中的事件送出

## 例外場景

### EX-02-01: Collector 不可達

| 項目 | 值 |
|------|-----|
| 觸發條件 | collector 未啟動或網路不通 |
| 處理方式 | SDK buffer 保留事件，Hook 正常結束（監控不影響 Hook 功能） |
| 恢復策略 | 下次 Hook 執行時若 collector 可達，新事件正常送出（歷史 buffer 已隨程式結束丟失） |

### EX-02-02: Hook 被 SIGKILL

| 項目 | 值 |
|------|-----|
| 觸發條件 | Claude Code timeout 強制終止 Hook |
| 處理方式 | `atexit` 不保證執行，buffer 中事件丟失 |
| 恢復策略 | 接受事件丟失（Hook timeout 是異常情況） |

## 驗收條件

### 功能驗收

- [ ] Hook 腳本可正常使用 Monitor SDK（init/event/error/close）
- [ ] Hook 完成後事件出現在 collector query 結果
- [ ] Hook 失敗時 error 事件包含 stack trace
- [ ] Hook 生命週期 < 1 秒時事件仍成功送出

### 邊界條件

- [ ] collector 不可達時 Hook 不受影響（正常結束）
- [ ] 多個 Hook 並行執行時各自的事件獨立（不串流）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
