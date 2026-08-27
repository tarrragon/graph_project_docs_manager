---
id: SPEC-008
title: "Flutter SDK"
status: draft
source_proposal: PROP-002
created: "2026-06-22"
updated: "2026-06-22"
version: "1.1"
owner: ""

domain: sdk
subdomain: flutter

related_usecases: [UC-01, UC-04]
related_specs: [SPEC-001, SPEC-002, SPEC-006]
implements_requirements: []
depends_on_domains: [core]
---

# Flutter SDK

## 概述

Flutter 監控 SDK，提供事件上報、攢批送出、離線容錯、自動錯誤攔截和 App lifecycle 整合。在 Dart 單執行緒模型上運作，處理 Isolate 安全和 Flutter 特有的生命週期管理。

教學依據：
- [模組三：SDK 公開 API](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/public-api.md)
- [模組三：攢批送出策略](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)
- [模組三：離線 buffer 與重試](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/offline-buffer.md)
- [模組三：自動攔截機制](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/auto-intercept.md)
- [模組五：Flutter 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/flutter-platform.md)
- [模組五：跨平台 timestamp 一致性](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/cross-platform-timestamp.md)

## 功能需求

### FR-01: 六個公開 API

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-01, UC-04 |

**描述**：

| 方法 | 用途 | 行為 |
|------|------|------|
| `Monitor.init(MonitorConfig config)` | 初始化 | 建立 session、啟動 flush Timer、註冊 WidgetsBindingObserver、註冊 error handler、記錄 `lifecycle.session.start` |
| `Monitor.event(String name, {Map<String, dynamic>? data})` | 記錄行為事件 | 非阻塞，事件進 buffer |
| `Monitor.error(dynamic exception, {Map<String, dynamic>? data, StackTrace? stackTrace})` | 記錄錯誤 | 自動附加 stack trace、錯誤類型。接受 Exception、Error 或 String |
| `Monitor.metric(String name, num value, {Map<String, dynamic>? data})` | 記錄數值指標 | 非阻塞，指標事件進 buffer |
| `Monitor.flush()` | 強制送出 buffer | async，等待 HTTP 回應完成 |
| `Monitor.close()` | 資源釋放 | flush 剩餘事件、停止 Timer、移除 Observer、記錄 `lifecycle.session.end` |

**Model — MonitorConfig**：

```dart
class MonitorConfig {
  /// Collector endpoint URL（必填）
  final String endpoint;

  /// 應用程式名稱（必填）
  final String app;

  /// 應用程式版本（必填）
  final String version;

  /// 自動 flush 間隔（預設 30 秒）
  final Duration flushInterval;

  /// Buffer 滿時觸發 flush 的筆數（預設 100 筆）
  final int bufferSize;

  /// 離線 buffer 上限（預設 300 筆，bufferSize 的 2-3 倍）
  final int maxBufferSize;

  /// Flush 失敗重試上限（預設 3 次）
  final int maxRetries;

  /// 啟用自動錯誤攔截（預設 true）
  final bool enableAutoIntercept;

  /// Heartbeat 間隔（預設 5 分鐘，設為 Duration.zero 停用）
  final Duration heartbeatInterval;
}
```

**約束條件**：

- `init()` 前呼叫其他方法拋出 `MonitorNotInitializedError`
- `close()` 後呼叫 `event()` / `error()` / `metric()` 靜默忽略（app 正在關閉）
- 所有上報方法非阻塞（進 buffer 立即返回）
- 連線驗證策略：lazy — init 不驗證 collector 是否可達，首次 flush 時才暴露網路問題
- 單例模式 — `Monitor` 為全域單例，init 呼叫一次
- 重複 init 行為 — `_state == running` 時再次呼叫 `init()` 拋出 `StateError('Monitor is already initialized')`（非靜默忽略，使誤用呼叫順序在開發期即暴露）。需先 `close()`（轉 `closed` 狀態）才能重新 init

**Error Model**：

```dart
/// MonitorNotInitializedError — init 前呼叫 API 時拋出
class MonitorNotInitializedError extends StateError {
  MonitorNotInitializedError()
      : super('Monitor.init() must be called before using the SDK');
}
```

**驗收標準**：

- [ ] 六個 API 皆可呼叫且行為符合描述
- [ ] init 前呼叫 event 拋出 `MonitorNotInitializedError`
- [ ] close 後呼叫 event 不拋錯
- [ ] metric 記錄的事件 type 為 `"metric"`

### FR-02: 攢批送出

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-01 |

**描述**：事件進入內部 buffer，滿足以下任一條件時 flush：

| 條件 | 預設值 | 對應 MonitorConfig 參數 |
|------|--------|----------------------|
| 時間間隔 | 30 秒 | `flushInterval` |
| 累積筆數 | 100 筆 | `bufferSize` |
| 手動呼叫 | `flush()` | - |
| App 進入背景 | paused 狀態 | - |
| SDK 關閉 | `close()` | - |

**Heartbeat 整合**：flush timer 觸發時，若 buffer 為空且距上次 heartbeat 超過 `heartbeatInterval`，自動注入一筆 `lifecycle` 類型的 `sdk.heartbeat` 事件後送出。

**驗收標準**：

- [ ] 累積 bufferSize 筆後自動 flush
- [ ] flushInterval 到時自動 flush（即使不滿 bufferSize 筆）
- [ ] `flush()` 立即送出
- [ ] buffer 為空且超過 heartbeatInterval 時送出 heartbeat

### FR-03: 離線容錯

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-04 |

**描述**：collector 不可達時，事件保留在記憶體 buffer。Buffer 上限 `maxBufferSize`（預設 300 筆），超過時丟棄最舊事件（FIFO）。恢復後下次 flush 重試。

**驗收標準**：

- [ ] collector 不可達時事件不丟失（buffer 內）
- [ ] buffer 超過 maxBufferSize 時丟棄最舊
- [ ] collector 恢復後事件成功送出

### FR-04: 自動錯誤攔截

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-04 |

**描述**：SDK 在 init 時註冊兩層錯誤攔截：

| 攔截層 | 機制 | 攔截對象 |
|--------|------|---------|
| Widget 層 | `FlutterError.onError` | Widget build / layout / paint 過程中的例外 |
| 非同步層 | `PlatformDispatcher.instance.onError` | 其他非同步區域的未處理例外 |

攔截後：保存原有 handler → 記錄 error 事件（含 stack trace、error type）→ 呼叫原有 handler。`data` 欄位包含 `source: "auto"` 標記自動攔截。

**Error 事件格式**：

```dart
// 自動攔截產生的事件
{
  "type": "error",
  "name": "error.FlutterError",  // 從 error class name 推導
  "data": {
    "message": "RenderFlex overflowed by 42 pixels",
    "stack": "...",  // stack trace 字串化
    "error_type": "FlutterError",
    "source": "auto"  // 區分自動攔截 vs 手動上報
  }
}
```

**Metric 事件格式**：

```dart
// Monitor.metric('api.latency_ms', 320, data: {'endpoint': '/users'})
{
  "type": "metric",
  "name": "api.latency_ms",
  "data": {
    "value": 320,
    "endpoint": "/users"
  }
}
```

**去重邏輯**：`FlutterError.onError` 和 `PlatformDispatcher.instance.onError` 可能對同一例外各觸發一次。SDK 使用 `PlatformDispatcher.instance.onError` 作為主要攔截層（涵蓋範圍更廣），`FlutterError.onError` 僅捕獲 Widget build/layout/paint 層的例外。兩者同時觸發時，用最近 N 筆 error 的 `(error_type, message)` 做 dedup（500ms 時間窗口內相同組合視為同一例外），避免重複記錄。

教學依據：[模組三：自動攔截 — Flutter 段「需要避免同一個例外被記錄兩次」](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/auto-intercept.md)

**約束**：`enableAutoIntercept: false` 時不註冊攔截器。

**驗收標準**：

- [ ] Widget build error 被捕獲並記錄為 error 事件
- [ ] 非同步未處理例外被捕獲並記錄
- [ ] 原有的 error handler 仍被呼叫（不覆蓋）
- [ ] enableAutoIntercept: false 時不攔截

### FR-05: Flutter 平台適配

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-04 |

**描述**：

**App Lifecycle 整合**：

SDK 在 init 時透過 `WidgetsBindingObserver.didChangeAppLifecycleState` 監聽生命週期：

| 狀態 | SDK 行為 | 理由 |
|------|---------|------|
| `paused`（進入背景） | 觸發 flush | iOS 約 5 秒後 suspend，buffer 中事件可能遺失 |
| `resumed`（回到前景） | 檢查上次 flush 是否失敗，失敗則重試 | 恢復連線 |
| `detached`（即將關閉） | 呼叫 `close()` | 最後一次 flush + 資源釋放 |

每次狀態轉換記錄一筆 lifecycle 事件：

```dart
{
  "type": "lifecycle",
  "name": "app.lifecycle.changed",
  "data": {
    "state": "paused",
    "previous_state": "resumed"
  }
}
```

**Isolate 安全**：

SDK buffer 存在於 main isolate。子 isolate 透過 `SendPort` 送事件到 main isolate：

```dart
// Main isolate — init 時建立 ReceivePort
final receivePort = ReceivePort();
receivePort.listen((message) {
  if (message is Map<String, dynamic>) {
    _addToBuffer(message);
  }
});

// 子 isolate — 透過 port 送事件
void isolateEntry(SendPort mainPort) {
  mainPort.send({
    'type': 'event',
    'name': 'compute.completed',
    'data': {'result': 42},
  });
}
```

提供 `Monitor.sendPort` getter 讓子 isolate 取得 port。

**Source 欄位**：

```dart
{
  "source": {
    "sdk": "flutter",
    "platform": "ios",     // 自動偵測：ios / android / macos / linux / web
    "app": "my_app",       // 從 MonitorConfig.app
    "version": "1.0.0"     // 從 MonitorConfig.version
  }
}
```

Platform 偵測邏輯：`Platform.isIOS` → `"ios"`、`Platform.isAndroid` → `"android"`、`kIsWeb` → `"web"` 等。

**驗收標準**：

- [ ] App paused 時自動 flush
- [ ] App resumed 時重試上次失敗的 flush
- [ ] App detached 時自動 close
- [ ] Lifecycle 狀態轉換記錄為 lifecycle 事件
- [ ] 子 isolate 透過 SendPort 送事件到 main isolate buffer
- [ ] source.sdk = "flutter"、source.platform 正確偵測

### FR-06: Timestamp 格式

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-002 |
| 對應用例 | UC-01 |

**描述**：所有事件的 `timestamp` 欄位使用 ISO 8601 + 時區偏移格式。

Dart 的 `DateTime.now().toIso8601String()` 不含時區偏移。SDK 需手動附加：

```dart
String formatTimestamp() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${now.toIso8601String()}$sign$hours:$minutes';
  // 產出：2026-06-22T14:30:00.123+08:00
}
```

**驗收標準**：

- [ ] timestamp 格式為 ISO 8601 + 時區偏移（如 `+08:00`）
- [ ] 毫秒精度

## 介面規格

```dart
import 'package:monitor/monitor.dart';

// 初始化
await Monitor.init(MonitorConfig(
  endpoint: 'http://localhost:9090/v1/events',
  app: 'my_flutter_app',
  version: '1.0.0',
  flushInterval: Duration(seconds: 30),
  bufferSize: 100,
));

// 記錄事件
Monitor.event('screen.view', data: {'screen': 'HomeScreen'});

// 記錄錯誤
try {
  await connectToServer();
} catch (e, stackTrace) {
  Monitor.error(e, data: {'step': 'connection'}, stackTrace: stackTrace);
}

// 記錄指標
Monitor.metric('api.latency_ms', 320, data: {'endpoint': '/users'});

// 手動 flush
await Monitor.flush();

// 關閉
await Monitor.close();
```

## Transport 整合

完整 transport 規格見 `docs/transport.md`。以下為 SDK 端的關鍵行為摘要：

### Batch format

```json
{ "batch_id": "019537a0-7b2c-7def-8a2b-3c4d5e6f7890", "events": [ ... ] }
```

`batch_id` 使用 UUID v7（`package:uuid` 的 `Uuid().v7()`），flush 時產生。

### 對 Collector 回應的處理

| Status | SDK 行為 |
|--------|---------|
| 200 | 清除 buffer |
| 207 | 清除 buffer + warning log（schema 問題重試也不會過） |
| 400 | 清除 buffer + error log（同上） |
| 503 | 保留 buffer，等 `retry_after` 秒後重試 |
| 其他 | 保留 buffer，下次 flush 重試（上限 maxRetries 次後丟棄） |

教學依據：[攢批送出策略 — SDK 對 collector 回應的處理](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Dart 單執行緒 | Main isolate 內 buffer 操作天然 atomic | 不需要 Lock/Mutex |
| iOS 背景限制 | paused 後約 5 秒 suspend | flush 必須在時間窗口內完成 |
| 零外部依賴（核心） | 核心用 `dart:io` + `dart:async` | `package:uuid` 是唯一外部依賴（batch_id） |
| 單例模式 | `Monitor` 為全域單例 | init 呼叫一次 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-22 | 初始版本 — 六個 API + 攢批 + 離線容錯 + 自動攔截 + lifecycle + isolate |
| 1.1 | 2026-06-22 | 補 metric 事件格式範例 + 自動攔截去重邏輯（教學一致性審查） |
