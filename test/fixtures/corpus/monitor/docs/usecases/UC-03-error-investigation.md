---
id: UC-03
title: "錯誤調查"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.0"

primary_actor: "開發者"
secondary_actors: ["Collector"]

platform: "both"
extension_status: "not-applicable"

related_specs: [SPEC-001, SPEC-003]
related_usecases: [UC-01, UC-02]
ticket_refs: []
---

# UC-03: 錯誤調查

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-03 |
| 用例名稱 | 錯誤調查 |
| 主要行為者 | 開發者 |
| 利益關係人 | 開發者（定位並修復重複出現的錯誤） |
| 前置條件 | collector 已有累積的 error 事件 |
| 成功保證 | 開發者找到錯誤模式並定位問題根因 |

## 主要成功場景

1. **查看 Error 摘要**
   - 開發者 `GET /v1/events/summary?type=error&group_by=name`
   - 回傳 error 按 name 分群的列表，含出現次數和最近發生時間
   - 發現 `hook.failure` 出現 15 次，最近一次 10 分鐘前

2. **深入特定 Error**
   - `GET /v1/events?type=error&name=hook.failure&limit=5`
   - 回傳最近 5 筆 `hook.failure` 事件
   - 每筆含 error.message、error.stack、error.type、data（hook 名稱、觸發事件）

3. **比對時間軸**
   - `GET /v1/events?from=2026-06-21T08:00:00Z&to=2026-06-21T09:00:00Z`
   - 查看同時段所有事件，理解錯誤發生的上下文
   - 發現 `hook.failure` 都發生在 `lifecycle.session.start` 之後

4. **定位根因**
   - 開發者從 stack trace 定位到具體 Hook 和行號
   - 從 data 欄位得知觸發條件
   - 修復後重跑 Hook 確認錯誤不再出現

## 替代場景

### 03a: 錯誤已被 Downsample

**觸發條件**：查詢超過 7 天前的 error

1. 7 天前的原始事件已被 Purge 刪除，但 hourly_summary 摘要表保留每小時的 error count
2. 開發者從 hourly_summary 看到降採樣後的 error 分佈趨勢
3. 最近 7 天內的 error 仍有完整詳情（原始事件）

## 例外場景

### EX-03-01: 無 Error 事件

| 項目 | 值 |
|------|-----|
| 觸發條件 | 系統正常運行，無 error 類型事件 |
| 處理方式 | errors/summary 回傳空陣列 |
| 恢復策略 | 無需動作 |

## 驗收條件

### 功能驗收

- [ ] errors/summary 按 name 分群並含 count / last_seen
- [ ] 按 name 篩選回傳對應 error 事件
- [ ] error 事件含完整 error.message / error.stack / error.type
- [ ] 時間軸查詢可查到同時段所有類型事件

### 邊界條件

- [ ] 無 error 時 summary 回傳空陣列
- [ ] 降採樣後的 error 仍可查到（代表事件）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
