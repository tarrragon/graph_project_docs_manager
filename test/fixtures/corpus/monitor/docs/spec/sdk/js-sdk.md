---
id: SPEC-009
title: "JS/TS SDK"
status: draft
source_proposal: PROP-003
created: "2026-06-22"
updated: "2026-06-22"
version: "1.1"
owner: ""

domain: sdk
subdomain: js

related_usecases: [UC-01, UC-05]
related_specs: [SPEC-001, SPEC-002, SPEC-006, SPEC-008]
implements_requirements: []
depends_on_domains: [core]
---

# JS/TS SDK

## 概述

JavaScript/TypeScript 監控 SDK，提供事件上報、攢批送出、離線容錯、自動錯誤攔截和瀏覽器頁面生命週期整合。處理瀏覽器特有的 CORS 限制和 `sendBeacon` 送出策略。

教學依據：
- [模組三：SDK 公開 API](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/public-api.md)
- [模組三：攢批送出策略](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)
- [模組三：離線 buffer 與重試](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/offline-buffer.md)
- [模組三：自動攔截機制](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/auto-intercept.md)
- [模組五：JS/TS 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/js-ts-platform.md)
- [模組五：跨平台 timestamp 一致性](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/cross-platform-timestamp.md)

## 功能需求

### FR-01: 六個公開 API

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-01, UC-05 |

**描述**：

| 方法 | 用途 | 行為 |
|------|------|------|
| `Monitor.init(config: MonitorConfig)` | 初始化 | 建立 session、啟動 flush setInterval、註冊 error handler、記錄 `lifecycle.session.start` |
| `Monitor.event(name: string, data?: Record<string, unknown>)` | 記錄行為事件 | 非阻塞，事件進 buffer |
| `Monitor.error(error: Error \| string, data?: Record<string, unknown>)` | 記錄錯誤 | 自動附加 stack trace、錯誤類型。接受 Error 物件或字串 |
| `Monitor.metric(name: string, value: number, data?: Record<string, unknown>)` | 記錄數值指標 | 非阻塞，指標事件進 buffer |
| `Monitor.flush(): Promise<void>` | 強制送出 buffer | async，等待 HTTP 回應完成 |
| `Monitor.close(): Promise<void>` | 資源釋放 | flush 剩餘事件、停止 timer、移除 event listener、記錄 `lifecycle.session.end` |

**Model — MonitorConfig**：

```typescript
interface MonitorConfig {
  /** Collector endpoint URL（必填） */
  endpoint: string;

  /** 應用程式名稱（必填） */
  app: string;

  /** 應用程式版本（必填） */
  version: string;

  /** 自動 flush 間隔毫秒（預設 30000） */
  flushInterval?: number;

  /** Buffer 滿時觸發 flush 的筆數（預設 100） */
  bufferSize?: number;

  /** 離線 buffer 上限（預設 300） */
  maxBufferSize?: number;

  /** Flush 失敗重試上限（預設 3） */
  maxRetries?: number;

  /** 啟用自動錯誤攔截（預設 true） */
  enableAutoIntercept?: boolean;

  /** Heartbeat 間隔毫秒（預設 300000 = 5 分鐘，設為 0 停用） */
  heartbeatInterval?: number;
}
```

**約束條件**：

- `init()` 前呼叫其他方法拋出 `MonitorNotInitializedError`
- `close()` 後呼叫 `event()` / `error()` / `metric()` 靜默忽略
- 所有上報方法非阻塞（進 buffer 立即返回）
- 連線驗證策略：lazy — init 不驗證 collector 是否可達
- 單例模式 — `Monitor` 為 module-level 單例

**Error Model**：

```typescript
class MonitorNotInitializedError extends Error {
  constructor() {
    super('Monitor.init() must be called before using the SDK');
    this.name = 'MonitorNotInitializedError';
  }
}
```

**驗收標準**：

- [ ] 六個 API 皆可呼叫且行為符合描述
- [ ] init 前呼叫 event 拋出 `MonitorNotInitializedError`
- [ ] close 後呼叫 event 不拋錯
- [ ] metric 記錄的事件 type 為 `"metric"`
- [ ] TypeScript 型別定義完整（d.ts 匯出）

### FR-02: 攢批送出

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-01 |

**描述**：事件進入內部 buffer，滿足以下任一條件時 flush：

| 條件 | 預設值 | 對應 MonitorConfig 參數 |
|------|--------|----------------------|
| 時間間隔 | 30 秒 | `flushInterval` |
| 累積筆數 | 100 筆 | `bufferSize` |
| 手動呼叫 | `flush()` | - |
| 頁面隱藏 | visibilitychange: hidden | - |
| 頁面關閉 | beforeunload | - |
| SDK 關閉 | `close()` | - |

**Heartbeat 整合**：flush timer 觸發時，若 buffer 為空且距上次 heartbeat 超過 `heartbeatInterval`，自動注入一筆 `lifecycle` 類型的 `sdk.heartbeat` 事件後送出。

**驗收標準**：

- [ ] 累積 bufferSize 筆後自動 flush
- [ ] flushInterval 到時自動 flush
- [ ] `flush()` 立即送出
- [ ] buffer 為空且超過 heartbeatInterval 時送出 heartbeat

### FR-03: 離線容錯

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-05 |

**描述**：collector 不可達時，事件保留在記憶體 buffer。Buffer 上限 `maxBufferSize`（預設 300 筆），超過時丟棄最舊事件（FIFO）。恢復後下次 flush 重試。

可選：監聽 `navigator.onLine` 事件，上線時立即觸發 flush。

**驗收標準**：

- [ ] collector 不可達時事件不丟失（buffer 內）
- [ ] buffer 超過 maxBufferSize 時丟棄最舊
- [ ] collector 恢復後事件成功送出

### FR-04: 自動錯誤攔截

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-05 |

**描述**：SDK 在 init 時註冊兩個全域錯誤攔截：

| 攔截點 | 機制 | 攔截對象 |
|--------|------|---------|
| 同步例外 | `window.onerror` | 未捕獲的同步錯誤（收到 message、source URL、行號、列號、Error 物件） |
| Promise rejection | `window.onunhandledrejection` | 未處理的 Promise rejection |

攔截後：保存原有 handler → 記錄 error 事件 → 呼叫原有 handler。`data` 欄位包含 `source: "auto"` 標記自動攔截。

**Error 事件格式**：

```json
{
  "type": "error",
  "name": "error.TypeError",
  "data": {
    "message": "Cannot read properties of undefined",
    "stack": "TypeError: Cannot read properties...\n    at ...",
    "error_type": "TypeError",
    "source": "auto",
    "url": "https://example.com/app.js",
    "line": 42,
    "column": 15
  }
}
```

**跨域限制**：`window.onerror` 對跨域腳本只收到 `Script error.` 無 stack trace。需要 `<script crossorigin>` + server CORS header。SDK 文件需明確指引此限制和解法。

**約束**：`enableAutoIntercept: false` 時不註冊攔截器。

**驗收標準**：

- [ ] 同步未捕獲例外被記錄為 error 事件
- [ ] 未處理 Promise rejection 被記錄
- [ ] 原有的 onerror / onunhandledrejection handler 仍被呼叫
- [ ] enableAutoIntercept: false 時不攔截

### FR-05: 瀏覽器平台適配

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-05 |

**描述**：

**頁面生命週期整合**：

| 事件 | SDK 行為 | 理由 |
|------|---------|------|
| `visibilitychange: hidden` | 觸發 flush（用 fetch） | 頁面切到背景，可能被關閉 |
| `beforeunload` | 觸發 sendBeacon flush | 最後機會送出事件；sendBeacon 不受頁面關閉影響 |

```typescript
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    Monitor.flush();  // 用 fetch，可讀回應
  }
});

window.addEventListener('beforeunload', () => {
  // sendBeacon：不受頁面關閉影響，但無法讀回應
  const payload = JSON.stringify({ batch_id: generateBatchId(), events: buffer });
  navigator.sendBeacon(config.endpoint, payload);
});
```

**CORS 處理**：

| 送出方式 | CORS 行為 | 適用場景 |
|---------|----------|---------|
| `navigator.sendBeacon()` | 不做 preflight | beforeunload flush（無法讀回應） |
| `fetch()` | 需要 CORS header | 一般 flush（可讀回應、處理 status code） |

fetch 請求加 `cache: 'no-store'` 防止 Service Worker 快取監控請求。

Collector 端需設定 CORS header（SPEC-002 擴充）：
- `Access-Control-Allow-Origin: *`（或特定 origin）
- `Access-Control-Allow-Methods: POST`
- `Access-Control-Allow-Headers: Content-Type`

**Source 欄位**：

```json
{
  "source": {
    "sdk": "js",
    "platform": "web",
    "app": "my_web_app",
    "version": "1.0.0"
  }
}
```

**驗收標準**：

- [ ] visibilitychange: hidden 時自動 flush
- [ ] beforeunload 時 sendBeacon 送出
- [ ] fetch 請求帶 `cache: 'no-store'`
- [ ] source.sdk = "js"、source.platform = "web"

### FR-06: Timestamp 格式

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-003 |
| 對應用例 | UC-01 |

**描述**：所有事件的 `timestamp` 欄位使用 ISO 8601 + 時區偏移格式。

JS 的 `new Date().toISOString()` 回傳 UTC（尾綴 Z）。SDK 需產出帶本地時區偏移的格式：

```typescript
function formatTimestamp(): string {
  const now = new Date();
  const offset = -now.getTimezoneOffset();  // 分鐘，正值 = 東區
  const sign = offset >= 0 ? '+' : '-';
  const hours = String(Math.floor(Math.abs(offset) / 60)).padStart(2, '0');
  const minutes = String(Math.abs(offset) % 60).padStart(2, '0');
  // 手動組裝本地 ISO 8601
  const local = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}T${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}:${String(now.getSeconds()).padStart(2,'0')}.${String(now.getMilliseconds()).padStart(3,'0')}`;
  return `${local}${sign}${hours}:${minutes}`;
  // 產出：2026-06-22T14:30:00.123+08:00
}
```

**驗收標準**：

- [ ] timestamp 格式為 ISO 8601 + 時區偏移
- [ ] 毫秒精度

## 介面規格

```typescript
import { Monitor } from '@monitor/sdk-js';

// 初始化
Monitor.init({
  endpoint: 'http://localhost:9090/v1/events',
  app: 'my_web_app',
  version: '1.0.0',
  flushInterval: 30000,
  bufferSize: 100,
});

// 記錄事件
Monitor.event('button.click', { button: 'submit', page: '/checkout' });

// 記錄錯誤
try {
  await fetchData();
} catch (e) {
  Monitor.error(e as Error, { step: 'data-fetch' });
}

// 記錄指標
Monitor.metric('api.latency_ms', 320, { endpoint: '/api/users' });

// 手動 flush
await Monitor.flush();

// 關閉
await Monitor.close();
```

### Metric 事件格式

```json
{
  "type": "metric",
  "name": "api.latency_ms",
  "data": {
    "value": 320,
    "endpoint": "/api/users"
  }
}
```

### Script tag 引入

```html
<script src="https://cdn.example.com/monitor.umd.js" crossorigin="anonymous"></script>
<script>
  Monitor.init({
    endpoint: 'http://localhost:9090/v1/events',
    app: 'my_web_app',
    version: '1.0.0',
  });
</script>
```

`crossorigin` attribute 是必要的——沒有它，`window.onerror` 對此腳本的錯誤只收到 `"Script error."` 無 stack trace。Collector 端也需設定 CORS header（見 SPEC-002 NFR-02）。

## Transport 整合

完整 transport 規格見 `docs/transport.md`。以下為 SDK 端的關鍵行為摘要：

### Batch format

```json
{ "batch_id": "019537a0-7b2c-7def-8a2b-3c4d5e6f7890", "events": [ ... ] }
```

`batch_id` 使用 UUID v7（`crypto.randomUUID()` 作為 fallback，或 `uuid` npm package）。

### 對 Collector 回應的處理

| Status | SDK 行為 | 送出方式 |
|--------|---------|---------|
| 200 | 清除 buffer | fetch |
| 207 | 清除 buffer + console.warn | fetch |
| 400 | 清除 buffer + console.error | fetch |
| 429 | 保留 buffer，等 `Retry-After` 秒後重試 + 觸發動態取樣降速 | fetch |
| 503 | 保留 buffer，等 `retry_after` 秒後重試 | fetch |
| 其他 | 保留 buffer，下次 flush 重試（上限 maxRetries 次） | fetch |
| N/A | 無法讀回應（fire-and-forget） | sendBeacon |

教學依據：[攢批送出策略 — SDK 對 collector 回應的處理](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)

### sendBeacon 限制

| 限制 | 影響 | 對策 |
|------|------|------|
| Payload 上限約 64KB | 大 batch 可能被截斷 | flush 頻率足夠時單次 batch < 10KB |
| 無法自訂 Content-Type | Collector 需接受 `text/plain` | Collector 端 content negotiation |
| 無回應 | 無法知道是否送達 | 僅用於 beforeunload 最後手段 |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 瀏覽器環境 | 無 fs、無 process | 離線 persistence 需用 localStorage / IndexedDB |
| CORS | 跨域需 collector 配合 | Collector 需加 CORS header |
| sendBeacon 限制 | 無回應、payload 上限 | 僅用於 unload 場景 |
| 零外部依賴（核心） | 用 `fetch` + `sendBeacon` + `crypto` | 避免引入大型依賴 |
| 單例模式 | `Monitor` 為 module-level 單例 | init 呼叫一次 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本 — 六個 API + 攢批 + 離線容錯 + 自動攔截 + 頁面生命週期 + CORS |
| 1.1 | 2026-06-22 | 補 metric 事件格式範例 + script tag crossorigin 指引 + SPEC-002 交叉引用（教學一致性審查） |
