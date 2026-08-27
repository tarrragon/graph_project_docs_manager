---
id: PROP-003
title: "JS/TS SDK — Web 頁面事件收集"
status: draft
source: development
proposed_by: "sdk-design 規劃"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.3.0
priority: P2
evaluation_level: standard

outputs:
  spec_refs:
    - spec/sdk/js-sdk.md
  usecase_refs: [UC-01, UC-05]
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-003: JS/TS SDK — Web 頁面事件收集

## 需求來源

PROP-001 (v0.1.0) 完成 collector + Python SDK，PROP-002 (v0.2.0) 完成 Flutter SDK 後，JS/TS SDK 是開發優先序第四（CLAUDE.md §4）。教學模組三定義了跨平台共用的六個 API 介面，模組五定義了瀏覽器環境的特殊限制（CORS、Service Worker、SPA 路由偵測）。

既有產出：
- collector (v0.1.0) — 已有事件接收、儲存、查詢能力
- `schema/event.schema.json` — 事件格式契約
- `docs/transport.md` — SDK ↔ collector 通訊規格
- SPEC-006 Python SDK、SPEC-008 Flutter SDK — API 設計模式參考

## 問題描述

Web 頁面需要監控能力：JavaScript 錯誤捕獲、使用者行為追蹤、效能指標量測（Core Web Vitals）。瀏覽器環境有 CORS 限制、頁面生命週期（unload、visibilitychange）和 SPA 路由偵測等平台特有問題。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | sdk-js（TypeScript）|
| 檔案 | sdk-js/ 全新建 |
| 依賴 | collector (v0.1.0)、schema/event.schema.json、docs/transport.md |
| 用例 | Web 頁面使用者行為追蹤、JS 錯誤回報、Core Web Vitals 量測 |

## 範圍界定

### 本提案要做的（In Scope）

**六個公開 API**（教學依據：[模組三 SDK 公開 API](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/public-api.md)）：

1. `init()` — 初始化 SDK、建立 session、啟動 flush 計時器
2. `event()` — 記錄行為事件（非阻塞）
3. `error()` — 記錄錯誤事件（自動附加 stack trace）
4. `metric()` — 記錄數值指標
5. `flush()` — 強制送出 buffer（async）
6. `close()` — 資源釋放、最後一次 flush

**攢批送出**（教學依據：[攢批送出策略](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)）：

7. Buffer + flush interval + buffer size 三條件觸發
8. Heartbeat 整合（buffer 為空時注入 `sdk.heartbeat`）

**離線容錯**（教學依據：[離線 buffer 與重試](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/offline-buffer.md)）：

9. 記憶體 FIFO buffer（MVP 策略）
10. Collector 不可達時保留 buffer、恢復後重試

**自動攔截**（教學依據：[自動攔截機制](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/auto-intercept.md)）：

11. `window.onerror` — 同步未處理例外
12. `window.onunhandledrejection` — 未處理 Promise rejection

**JS/TS 平台適配**（教學依據：[JS/TS 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/js-ts-platform.md)）：

13. CORS 處理 — `navigator.sendBeacon` 用於 close flush，`fetch` 用於一般 flush
14. 頁面生命週期 — `visibilitychange` 時 flush、`beforeunload` 時 sendBeacon
15. `source.sdk = "js"`、`source.platform = "web"`

**Timestamp**（教學依據：[跨平台 timestamp 一致性](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/cross-platform-timestamp.md)）：

16. ISO 8601 + 時區偏移（`Intl.DateTimeFormat` 或手動計算）

### 本提案不做的（Out of Scope）

- SPA 路由偵測（History API monkey-patch，標為第二階段）
- Service Worker 模組（Service Worker 內攔截 error）
- 本地 persistence（localStorage / IndexedDB，第二階段）
- 前端感測器（click tracking、PerformanceObserver、Core Web Vitals，第二階段）
- Source map 上傳和 stack trace 解析
- SDK config collector 下發
- 框架整合套件（React / Vue / Angular plugin）

## 提案方案

### 架構概要

```
Web Page (JS/TS)                Collector (Go)
    |                               |
    | Monitor.init()                |
    |  └─ session start event       |
    |  └─ start flush timer         |
    |  └─ register onerror          |
    |  └─ register unhandledrej.    |
    |                               |
    | Monitor.event() / error()     |
    |  └─ event → buffer            |
    |                               |
    | [flush timer / buffer full]   |
    |  └─ fetch POST /v1/events     |
    |-----------------------------> |
    |         200/207/400/503       |
    | <---------------------------- |
    |                               |
    | [visibilitychange: hidden]    |
    |  └─ flush via fetch           |
    |                               |
    | [beforeunload]                |
    |  └─ sendBeacon (last chance)  |
```

### 技術選型

| 決策 | 選擇 | 理由 |
|------|------|------|
| HTTP client | `fetch` + `navigator.sendBeacon` | fetch 用於一般 flush（可讀回應）；sendBeacon 用於 unload flush（不受頁面關閉影響）|
| 語言 | TypeScript | 型別安全、IDE 支援、編譯產出 JS + d.ts |
| 打包 | ESM + UMD | ESM 給 bundler（webpack/vite）；UMD 給 `<script>` 直接引入 |
| 套件發佈 | npm | JS 標準套件發佈 |

### 教學模組對應

| MVP 項目 | 對應教學模組 |
|---------|-------------|
| 六個公開 API | 模組三：SDK 公開 API |
| 攢批送出 | 模組三：攢批送出策略 |
| 離線容錯 | 模組三：離線 buffer 與重試 |
| 自動攔截 | 模組三：自動攔截機制 |
| CORS + 頁面生命週期 | 模組五：JS/TS 平台適配 |
| Timestamp | 模組五：跨平台 timestamp 一致性 |

## 驗收條件

- [ ] `init / event / error / metric / flush / close` 六個 API 可用
- [ ] init 前呼叫 event 拋出 `MonitorNotInitializedError`
- [ ] close 後呼叫 event 靜默忽略
- [ ] 累積 N 筆後自動 flush
- [ ] flush interval 到時自動 flush
- [ ] collector 不可達時 buffer 保留、恢復後送出
- [ ] Buffer 超過上限時 FIFO 丟棄最舊
- [ ] `window.onerror` 捕獲同步未處理例外
- [ ] `window.onunhandledrejection` 捕獲未處理 Promise rejection
- [ ] 自動攔截不覆蓋應用程式既有的 error handler
- [ ] `visibilitychange: hidden` 時自動 flush
- [ ] `beforeunload` 時 sendBeacon 送出剩餘事件
- [ ] fetch 請求帶 `cache: 'no-store'`（避免 Service Worker 快取）
- [ ] Timestamp 為 ISO 8601 + 時區偏移
- [ ] TypeScript 型別定義完整（d.ts）
- [ ] **端到端驗收**：HTML 頁面引入 SDK → init → 送事件 → collector query 查到

## Reality Test / 觸發案例實證

### 觸發案例

1. Web 頁面監控是監控基礎設施的標準場景
2. PROP-001 驗證了 collector + transport 設計可行，JS SDK 復用相同 collector

### 假設列舉

- 假設 1：sendBeacon 在主流瀏覽器的 64KB payload 限制足夠（典型 batch < 10KB）
- 假設 2：fetch + `cache: 'no-store'` 能繞過 Service Worker 快取
- 假設 3：`beforeunload` 時 sendBeacon 能可靠送出

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | schema 設計（PROP-001）、transport 規格（PROP-001）、collector 接收能力（PROP-001）|
| 未驗證 | sendBeacon 在各瀏覽器的可靠性、CORS 配置對 collector 的影響、SPA 場景下 session 定義 |

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| CORS 配置遺漏 | fetch 請求被瀏覽器攔截 | Collector 需新增 CORS header；sendBeacon 作為 fallback |
| beforeunload 不可靠 | 頁面關閉時事件遺失 | visibilitychange flush 作為提前保障 |
| 跨域 Script error | onerror 只收到 `Script error.` 無 stack trace | 文件指引加 crossorigin attribute |

## 討論記錄

### 2026-06-22

- 從 PROP-001 完成後的開發優先序規劃
- 確認六個 API（含 metric）為教學定義的完整介面
- JS/TS 平台適配參考 blog 模組五
- TypeScript 為開發語言，打包同時產出 ESM + UMD
