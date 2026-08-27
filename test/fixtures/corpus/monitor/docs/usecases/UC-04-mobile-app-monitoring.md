---
id: UC-04
title: "Mobile App 生命週期監控"
status: draft
source_proposal: PROP-002
created: "2026-06-22"
updated: "2026-06-22"
version: "1.0"

primary_actor: "行動 app 開發者"
secondary_actors: ["SDK (Flutter)", "Collector (Go)"]

platform: "mobile"
extension_status: "not-applicable"

related_specs: [SPEC-001, SPEC-002, SPEC-008]
related_usecases: [UC-01]
ticket_refs: []
---

# UC-04: Mobile App 生命週期監控

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-04 |
| 用例名稱 | Mobile App 生命週期監控 |
| 主要行為者 | 行動 app 開發者 |
| 利益關係人 | 開發者（掌握 app crash、使用者行為、效能指標） |
| 前置條件 | collector 已啟動、Flutter SDK 已安裝（`pubspec.yaml` 加入依賴） |
| 成功保證 | App 生命週期事件（session start/end、app paused/resumed）和 crash 自動攔截事件可在 query API 查到 |

## 主要成功場景

1. **SDK 初始化**
   - 開發者在 `main.dart` 呼叫 `Monitor.init(MonitorConfig(endpoint: ..., app: "my_app", version: "1.0.0"))`
   - SDK 建立 session、記錄 `lifecycle.session.start`、啟動 flush timer、註冊 `WidgetsBindingObserver`、註冊 `FlutterError.onError` 和 `PlatformDispatcher.instance.onError`

2. **使用者操作產生事件**
   - 使用者在 app 中操作，開發者已在關鍵操作埋點 `Monitor.event("screen.view", data: {"screen": "HomeScreen"})`
   - 事件進入 buffer，非阻塞

3. **自動攔截 Widget 錯誤**
   - App 某 Widget build 過程拋出 `RenderFlex overflowed` 例外
   - SDK 透過 `FlutterError.onError` 自動捕獲，記錄 error 事件（含 stack trace、`source: "auto"`）
   - 原有的 FlutterError handler 仍被呼叫（不覆蓋）

4. **flush 送出**
   - flush timer 到時或 buffer 滿，SDK 將 buffer 中事件包裝為 batch，POST 到 collector
   - Collector 回傳 200，SDK 清除 buffer

5. **查詢驗證**
   - 開發者呼叫 `GET /v1/events?type=error` 查到自動攔截的 error 事件
   - 開發者呼叫 `GET /v1/events?type=lifecycle` 查到 session start 事件

## 替代場景

### 04a: App 進入背景

| 步驟 | 行為 |
|------|------|
| 1 | 使用者切換到其他 app（或按 Home 鍵） |
| 2 | Flutter 觸發 `AppLifecycleState.paused` |
| 3 | SDK 記錄 `lifecycle` 事件 `app.lifecycle.changed`（state: paused） |
| 4 | SDK 立即觸發 flush（iOS 約 5 秒後 suspend） |

### 04b: App 回到前景

| 步驟 | 行為 |
|------|------|
| 1 | 使用者切回 app |
| 2 | Flutter 觸發 `AppLifecycleState.resumed` |
| 3 | SDK 記錄 lifecycle 事件 |
| 4 | SDK 檢查上次 flush 是否失敗，失敗則重試 |

### 04c: 效能指標量測

| 步驟 | 行為 |
|------|------|
| 1 | 開發者在關鍵操作前後量測時間 |
| 2 | 呼叫 `Monitor.metric('api.latency_ms', 320, data: {'endpoint': '/users'})` |
| 3 | Metric 事件進入 buffer，type 為 `"metric"` |
| 4 | 正常 flush 流程送出 |

### 04d: 子 Isolate 產生事件

| 步驟 | 行為 |
|------|------|
| 1 | App 在子 isolate 中執行 compute 任務 |
| 2 | 子 isolate 透過 `Monitor.sendPort` 取得 port，送事件到 main isolate |
| 3 | Main isolate 的 ReceivePort 收到事件，加入 buffer |
| 4 | 正常 flush 流程送出 |

## 例外情境

### EX-04-01: Collector 不可達

| 步驟 | 行為 |
|------|------|
| 1 | Flush 時 HTTP POST 失敗（network error / timeout） |
| 2 | SDK 保留 buffer 中事件，下次 flush 重試 |
| 3 | Buffer 超過 maxBufferSize 時 FIFO 丟棄最舊事件 |
| 4 | Collector 恢復後下次 flush 送出成功 |

### EX-04-02: App 被系統強制終止（SIGKILL）

| 步驟 | 行為 |
|------|------|
| 1 | 系統因記憶體壓力強制終止 app |
| 2 | `detached` 回呼可能不被執行（SIGKILL） |
| 3 | Buffer 中未送出的事件遺失 |
| 4 | 接受遺失 — 強制終止是極端情境 |

### EX-04-03: Init 前呼叫 API

| 步驟 | 行為 |
|------|------|
| 1 | 開發者在 init 前呼叫 `Monitor.event(...)` |
| 2 | SDK 拋出 `MonitorNotInitializedError` |
| 3 | 開發者修正呼叫順序 |
