---
id: UC-09
title: "Error Fingerprint 分群與調查"
status: draft
source_proposal: PROP-009
created: "2026-06-24"
updated: "2026-06-24"
version: "1.0"

primary_actor: "開發者（error 調查）"
secondary_actors: ["Collector (Go)", "SDK (任何)"]

platform: "all"
extension_status: "not-applicable"

related_specs: [SPEC-002, SPEC-015]
related_usecases: [UC-01, UC-03]
ticket_refs: []
---

# UC-09: Error Fingerprint 分群與調查

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-09 |
| 用例名稱 | Error Fingerprint 分群與調查 |
| 主要行為者 | 開發者（error 調查） |
| 利益關係人 | 開發者（精確找到 error 根因，不被同名異因混淆） |
| 前置條件 | collector 已啟動且 fingerprint 功能已啟用、有 error 事件已被收集 |
| 成功保證 | 同因 error 歸為同一 group、不同因 error 各自獨立分群、開發者可查看 group 內詳情 |

## 主要成功場景

<!-- TODO: 填寫 GWT 場景 -->

1. **Error 事件被收集並自動分群**
   - Given: SDK 送出含 error_type 和 error_message 的 error 事件
   - When: Collector 收到事件後計算 fingerprint
   - Then: 事件寫入 events 表（含 fingerprint 欄位）、error_groups 表對應記錄被 UPSERT

2. **開發者查看 Error 分群列表**
   - Given: error_groups 表已有多筆 fingerprint group
   - When: 開發者呼叫 dashboard Error 列表 API
   - Then: 列表按 fingerprint group 呈現（非 GROUP BY name）、每組顯示 count / first_seen / last_seen

3. **同 error_type 不同 message 被分到不同 group**
   - Given: 兩筆 `app.exception` 事件分別指向不同 stack trace
   - When: Collector 計算 fingerprint
   - Then: 產生兩個不同的 fingerprint group

4. **動態值被 normalize 後歸同組**
   - Given: 錯誤訊息 `Connection to 192.168.1.1:3000 failed` 和 `Connection to 10.0.0.5:3000 failed`
   - When: Collector normalize message 後計算 fingerprint
   - Then: 兩筆事件歸為同一 fingerprint group

5. **SDK 端覆蓋 fingerprint**
   - Given: SDK 端在事件 `data.fingerprint` 欄位指定自定義值
   - When: Collector 收到事件
   - Then: 使用 SDK 指定的 fingerprint，不自動計算

## 替代場景

### 09a: Resolved group 收到新事件

| 步驟 | 行為 |
|------|------|
| 1 | 開發者將某 group 狀態標為 `resolved` |
| 2 | 同 fingerprint 的新 error 事件被收集 |
| 3 | Group 狀態自動 reopen 為 `open`，count 遞增 |

### 09b: Ignored group 收到新事件

| 步驟 | 行為 |
|------|------|
| 1 | 開發者將某 group 狀態標為 `ignored` |
| 2 | 同 fingerprint 的新 error 事件被收集 |
| 3 | Group count 遞增但狀態維持 `ignored` |

## 例外情境

### EX-09-01: Error message 完全相同但 error_type 不同

| 步驟 | 行為 |
|------|------|
| 1 | 兩筆事件 message 相同但 error_type 不同 |
| 2 | Fingerprint 計算含 error_type，產生不同 hash |
| 3 | 分到不同 group |

### EX-09-02: Normalization 過度導致誤合併

| 步驟 | 行為 |
|------|------|
| 1 | 兩筆不同 error 經 normalize 後 message 變相同 |
| 2 | 被歸為同一 group |
| 3 | 開發者可用 SDK 端 `data.fingerprint` 強制分開 |
