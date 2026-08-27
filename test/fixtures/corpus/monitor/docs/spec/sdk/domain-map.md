---
id: DOMAIN-MAP-SDK
domain: "sdk"
source_specs: [SPEC-006, SPEC-008, SPEC-009]
related_usecases: [UC-01, UC-02, UC-04, UC-05]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — SDK

> 產出來源：ticket 0.5.0-W1-002（版本-Wave-序號，追蹤於 `docs/work-logs/`）。本文件告訴開發者每個概念該落在哪個模組、依賴能指向誰。
> 與 `docs/usecases/traceability.yaml`（UC↔測試）、`docs/spec/sdk/` 各 SPEC（FR 清單）交叉引用。

**術語對照**：SPEC = 功能規格（`docs/spec/` 下各檔）；FR = Functional Requirement；UC = Use Case（`docs/usecases/`）；VO = Value Object。「教學」指配套 blog monitoring 系列（`~/project/blog/content/monitoring/`，見 CLAUDE.md §3）。

## 1. 目的與 UC / DDD 正交關係

三個 SDK（Python/Flutter/JS）共享同一組 domain 概念（MonitorClient 狀態機 + EventBuffer 攢批策略），但各自獨立實作——本文件統一這些 bundle 的邊界定義，確保三端語意一致。UC 是垂直視角（一條使用者劇本貫穿 init→event→flush→close），本文件是水平視角（按業務知識切模組邊界），兩者正交。

**核心準則**：domain 對 fetch、sendBeacon、urllib 等 transport 細節保持不知情——MonitorClient 只呼叫注入的 callback，使 buffer 邏輯可在不啟動 HTTP 的前提下純函式驗證。

## 2. 分層與依賴方向

**分類詞 legend**：aggregate root = 需持久化的核心實體；supporting VO = 自足值物件 + 純函式；domain service = 無狀態協調邏輯；shared kernel = 跨 domain 共用定義。

MonitorClient 是唯一有狀態的實體（單 aggregate 形態），domain 層薄、platform 適配層厚。

```
platform adaptation (ErrorInterceptor, LifecycleObserver)
        |
MonitorClient (aggregate root: SDK state machine)
        |
EventBuffer (domain service: buffer + flush trigger)
        |
EventBuilder (supporting VO: event construction)
        ^
        |
core/EventSchema (cross-domain shared kernel)
        ^
        |
Transport (data: HTTP client, batch serialization, response handling)
```

**依賴方向底線（不可違反）**：

- domain（MonitorClient、EventBuffer、EventBuilder）不得 import transport / platform API / HTTP 框架。違反則測試被迫 mock HTTP 和平台環境。
- EventBuffer 不依賴具體 transport 實作——flush 時呼叫注入的 transport function/interface，不直接呼叫 fetch/urllib。這確保 buffer 邏輯的 unit test 不需 mock HTTP 層。
- platform adaptation（ErrorInterceptor、LifecycleObserver）依賴 MonitorClient 的公開 API（event/error/flush/close），不直接操作 EventBuffer。若破壞此邊界，平台層的錯誤攔截邏輯變更會擴散到 buffer 內部。
- Transport 實作 domain 定義的 transport interface/callback，domain 不反向依賴 transport。這使得跨平台 transport 替換（fetch vs sendBeacon vs urllib）只需換注入的實作，domain 程式碼不動。

## 3. Bundle 界定表

### 真 domain

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| MonitorClient | aggregate root | SDK 狀態機（uninitialized -> running -> closed）、session 管理（session.id UUID v7 建立）、init/close 生命週期（SPEC-006 FR-01, SPEC-008 FR-01, SPEC-009 FR-01） | HTTP transport、platform 錯誤攔截 | `sdk-{lang}/lib/` 或 `sdk-{lang}/src/` | unit：狀態轉換（init 前拋 MonitorNotInitializedError、close 後靜默忽略、Flutter double-init 拋 StateError）、session ID 格式 |
| EventBuffer | domain service | buffer 累積、flush 觸發條件評估（時間/筆數/手動/lifecycle）、FIFO 溢出淘汰、重試計數與丟棄（SPEC-006 FR-02~03, SPEC-008 FR-02~03, SPEC-009 FR-02~03）、heartbeat 注入邏輯（SPEC-008 FR-02, SPEC-009 FR-02） | HTTP 送出實作、平台 timer 機制 | `sdk-{lang}/lib/` 或 `sdk-{lang}/src/` | unit：buffer 滿時 FIFO 淘汰、flush 觸發判斷、重試上限後丟棄、heartbeat 間隔判斷 |
| EventBuilder | supporting VO | event 物件建構（timestamp ISO 8601 + 時區偏移、source 欄位填充、batch_id UUID v7 產生）（SPEC-006 FR-01, SPEC-008 FR-06, SPEC-009 FR-06） | 序列化格式（JSON stringify） | `sdk-{lang}/lib/` 或 `sdk-{lang}/src/` | unit：timestamp 格式含時區偏移、source.sdk 正確（python/flutter/js）、batch_id 為 UUID v7 |

### 非 domain

| Bundle | 分類 | 納入概念 | 來源 FR | 目標路徑 | 測試層 |
|---|---|---|---|---|---|
| ErrorInterceptor | cross-cutting（platform） | Python: 無自動攔截（手動 try/except）；Flutter: FlutterError.onError + PlatformDispatcher.onError + 去重；JS: window.onerror + onunhandledrejection | SPEC-008 FR-04, SPEC-009 FR-04 | `sdk-{lang}/lib/` | unit + integration：攔截觸發、原有 handler 保留、去重 |
| LifecycleObserver | cross-cutting（platform） | Python: atexit 註冊 close；Flutter: WidgetsBindingObserver（paused/resumed/detached）；JS: visibilitychange + beforeunload | SPEC-006 FR-04, SPEC-008 FR-05, SPEC-009 FR-05 | `sdk-{lang}/lib/` | integration：lifecycle 事件觸發 flush/close |
| Transport | data | HTTP 送出（Python: urllib、Flutter: dart:io HttpClient、JS: fetch + sendBeacon）、batch JSON 序列化、collector response 處理（線格式與 response 語意見 `docs/transport.md`） | SPEC-006 Transport, SPEC-008 Transport, SPEC-009 Transport | `sdk-{lang}/lib/` | unit + integration：response 狀態處理、sendBeacon fallback |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| MonitorClient | 狀態轉換嚴格：uninitialized -> running（init） -> closed（close）；init 前呼叫 event/error/metric 拋 MonitorNotInitializedError；close 後呼叫 event/error/metric 靜默忽略不拋錯；init 建立 session.id（UUID v7）和 session.started；Flutter: running 狀態再 init 拋 StateError；init 記錄 lifecycle.session.start、close 記錄 lifecycle.session.end |
| EventBuffer | buffer 不超過 maxBufferSize（Python 100、Flutter/JS 300）；超過時 FIFO 淘汰最舊事件；flush 觸發條件任一成立即 flush：計時器到、累積達 bufferSize、手動呼叫、lifecycle 事件；retry 超過 maxRetries 次後丟棄 buffer（Python 3 次、Flutter/JS maxRetries）；207/400 清除 buffer（schema 問題重試也不會過）；503/429 保留 buffer 等 retry_after；heartbeat：buffer 為空且距上次 heartbeat > heartbeatInterval 時注入 sdk.heartbeat 事件 |
| EventBuilder | timestamp 格式：ISO 8601 + 時區偏移（如 +08:00），毫秒精度；source.sdk 對應 SDK 類型（python/flutter/js——go SDK 不在本 map 範圍，歸 collector domain）；source.platform 自動偵測（Python: sys.platform、Flutter: Platform.isX、JS: "web"）；batch_id 為 UUID v7，每次 flush 產生一個，同一 flush 內所有事件的 batch_id 必須相同 |

## 4. 邊界決策

### 4.1 三 SDK 共享 domain 概念、分離 platform 實作

定案：MonitorClient 狀態機、EventBuffer 策略、EventBuilder 格式為三個 SDK 共享的 domain 概念，各自用各語言實作。不提供跨語言共用程式碼。

依據：Python/Dart/TypeScript 三語言無共用 runtime，強制共享會引入編譯/發布耦合。Domain map 統一 bundle 定義確保三端語意一致，但實作獨立。

### 4.2 Python SDK 預設值低於教學通用值

Python SDK flush_interval=5s / buffer_size=10，低於教學（配套 blog monitoring 系列）的 30s/100——因為首要驗證情境是框架 Hook 系統（`.claude/hooks/`），Hook 腳本生命週期極短（< 1 秒），需要更積極的 flush。教學通用值適合長時間執行的 app，不適合短生命週期腳本。

### 4.3 ErrorInterceptor 和 LifecycleObserver 歸類為 cross-cutting、非 domain

把自動錯誤攔截混入 domain 看似方便（少一層抽象），但這些機制高度依賴平台 API（FlutterError/window.onerror/atexit），與 domain 計算無關。它們透過 MonitorClient 公開 API（event/error/flush/close）與 domain 互動，不直接操作 buffer。分離後 domain 可純函式測試，不需 mock 平台環境。因此歸 cross-cutting/platform 層。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| SDK domain 票 | domain | 按 S3 拆 bundle（MonitorClient/EventBuffer/EventBuilder）；三 SDK 分別實作，語意一致 |
| platform 適配票 | platform | ErrorInterceptor、LifecycleObserver 各 SDK 獨立實作，透過 domain 公開 API 互動 |
| transport 票 | data | HTTP 送出、response 處理屬 data 層，實作 domain 定義的 transport interface |

## 6. 觀察到的技術債（待追蹤）

- 三個 SDK 的 domain 概念目前各自實作無共享測試規格。建議建立 conformance test spec，驗證三端 MonitorClient 狀態機和 EventBuffer 策略語意一致。追蹤：0.5.0-W2-003。

## 7. FR -> Bundle 覆蓋對照

### SPEC-006（Python SDK）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | MonitorClient | 五個公開 API + 狀態機 |
| FR-02 | EventBuffer | 攢批送出（5s/10 筆） |
| FR-03 | EventBuffer | 離線容錯（buffer 100） |
| FR-04 | LifecycleObserver（platform） | atexit + thread-safe |

### SPEC-008（Flutter SDK）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | MonitorClient | 六個公開 API + 狀態機 |
| FR-02 | EventBuffer | 攢批送出（30s/100 筆）+ heartbeat |
| FR-03 | EventBuffer | 離線容錯（buffer 300） |
| FR-04 | ErrorInterceptor（platform） | FlutterError + PlatformDispatcher + 去重 |
| FR-05 | LifecycleObserver（platform） | WidgetsBindingObserver + Isolate 安全 |
| FR-06 | EventBuilder | Timestamp ISO 8601 + 時區偏移 |

### SPEC-009（JS/TS SDK）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | MonitorClient | 六個公開 API + 狀態機 |
| FR-02 | EventBuffer | 攢批送出（30s/100 筆）+ heartbeat |
| FR-03 | EventBuffer | 離線容錯（buffer 300） |
| FR-04 | ErrorInterceptor（platform） | window.onerror + onunhandledrejection |
| FR-05 | LifecycleObserver（platform） | visibilitychange + beforeunload + sendBeacon |
| FR-06 | EventBuilder | Timestamp ISO 8601 + 時區偏移 |

---

**Last Updated**: 2026-07-23 | **Source**: 0.5.0-W1-002
