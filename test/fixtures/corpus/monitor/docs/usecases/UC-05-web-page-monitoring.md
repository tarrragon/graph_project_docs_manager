---
id: UC-05
title: "Web 頁面使用者行為監控"
status: draft
source_proposal: PROP-003
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"

primary_actor: "Web 前端開發者"
secondary_actors: ["SDK (JS/TS)", "Collector (Go)"]

platform: "web"
extension_status: "not-applicable"

related_specs: [SPEC-001, SPEC-002, SPEC-009]
related_usecases: [UC-01]
ticket_refs: []
---

# UC-05: Web 頁面使用者行為監控

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-05 |
| 用例名稱 | Web 頁面使用者行為監控 |
| 主要行為者 | Web 前端開發者 |
| 利益關係人 | 開發者（掌握 JS 錯誤、使用者操作流程、頁面效能） |
| 前置條件 | collector 已啟動並設定 CORS header、JS SDK 已引入頁面 |
| 成功保證 | JS 錯誤自動攔截、使用者操作事件和頁面生命週期事件可在 query API 查到 |

## 主要成功場景

1. **SDK 引入和初始化**
   - 開發者在 HTML 中引入 SDK（ESM import 或 `<script>` tag）
   - 呼叫 `Monitor.init({ endpoint: "http://localhost:9090/v1/events", app: "my_site", version: "1.0.0" })`
   - SDK 建立 session、記錄 `lifecycle.session.start`、啟動 flush timer、註冊 `window.onerror` 和 `window.onunhandledrejection`

2. **使用者操作產生事件**
   - 開發者在按鈕點擊 handler 中埋點 `Monitor.event("button.click", { button: "checkout" })`
   - 事件進入 buffer，非阻塞

3. **自動攔截 JS 錯誤**
   - 頁面中某段程式碼拋出 `TypeError: Cannot read properties of undefined`
   - SDK 透過 `window.onerror` 自動捕獲，記錄 error 事件（含 stack trace、行號、source URL、`source: "auto"`）
   - 原有的 onerror handler 仍被呼叫

4. **flush 送出**
   - flush timer 到時或 buffer 滿，SDK 用 `fetch` POST 到 collector
   - fetch 帶 `cache: 'no-store'` 防止 Service Worker 快取
   - Collector 回傳 200，SDK 清除 buffer

5. **查詢驗證**
   - 開發者呼叫 `GET /v1/events?type=error&source.sdk=js` 查到自動攔截的 error
   - 開發者呼叫 `GET /v1/events?name=button.click` 查到使用者操作事件

## 替代場景

### 05a: 頁面切到背景

| 步驟 | 行為 |
|------|------|
| 1 | 使用者切換 tab 或最小化瀏覽器 |
| 2 | `visibilitychange` 事件觸發，`document.visibilityState` 變為 `"hidden"` |
| 3 | SDK 用 fetch 觸發 flush |

### 05b: 頁面關閉

| 步驟 | 行為 |
|------|------|
| 1 | 使用者關閉 tab 或瀏覽器 |
| 2 | `beforeunload` 事件觸發 |
| 3 | SDK 用 `navigator.sendBeacon` 送出剩餘事件（fire-and-forget） |
| 4 | sendBeacon 不受頁面關閉影響，事件被可靠送出 |

### 05c: 未處理 Promise rejection

| 步驟 | 行為 |
|------|------|
| 1 | 程式碼中 `fetch('/api/data')` 返回的 Promise reject 未被 catch |
| 2 | `window.onunhandledrejection` 觸發 |
| 3 | SDK 記錄 error 事件，含 rejection reason |

### 05d: Script tag 引入（非 ESM）

| 步驟 | 行為 |
|------|------|
| 1 | 開發者用 `<script src="monitor.umd.js"></script>` 引入 SDK |
| 2 | `Monitor` 物件掛載到 `window.Monitor` |
| 3 | 後續呼叫方式和 ESM 相同 |

## 例外情境

### EX-05-01: CORS 被攔截

| 步驟 | 行為 |
|------|------|
| 1 | Collector 未設定 CORS header |
| 2 | fetch POST 被瀏覽器攔截（preflight 失敗） |
| 3 | SDK 保留 buffer，下次 flush 重試（仍會失敗） |
| 4 | 開發者需在 collector 端加 CORS header 解決 |

### EX-05-02: 跨域 Script error

| 步驟 | 行為 |
|------|------|
| 1 | 頁面載入的外部 JS 檔案拋出錯誤 |
| 2 | `window.onerror` 只收到 `"Script error."` 無 stack trace |
| 3 | SDK 記錄有限資訊的 error 事件 |
| 4 | 開發者需在 `<script>` 加 `crossorigin` attribute 解決 |

### EX-05-03: Collector 不可達

| 步驟 | 行為 |
|------|------|
| 1 | Flush 時 fetch 失敗（network error） |
| 2 | SDK 保留 buffer，下次 flush 重試 |
| 3 | Buffer 超過 maxBufferSize 時 FIFO 丟棄最舊事件 |
| 4 | Collector 恢復後下次 flush 送出成功 |

### EX-05-04: Init 前呼叫 API

| 步驟 | 行為 |
|------|------|
| 1 | 開發者在 init 前呼叫 `Monitor.event(...)` |
| 2 | SDK 拋出 `MonitorNotInitializedError` |
| 3 | 開發者修正呼叫順序 |
