---
id: PROP-002
title: "Flutter SDK — Mobile App 事件收集"
status: draft
source: development
proposed_by: "sdk-design 規劃"
proposed_date: "2026-06-22"
confirmed_date: null
target_version: v0.2.0
priority: P1
evaluation_level: standard

outputs:
  spec_refs:
    - spec/sdk/flutter-sdk.md
  usecase_refs: [UC-01, UC-04]
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-002: Flutter SDK — Mobile App 事件收集

## 需求來源

PROP-001 (v0.1.0) 完成 collector + Python SDK 的端到端驗證後，Flutter SDK 是開發優先序第三（CLAUDE.md §4）。教學模組三定義了跨平台共用的六個 API 介面，模組五定義了 Flutter 平台的特殊適配需求（Isolate 安全、Platform channel 攔截、App lifecycle 事件）。

既有產出：
- collector (v0.1.0) — 已有事件接收、儲存、查詢能力
- `schema/event.schema.json` — 事件格式契約
- `docs/transport.md` — SDK ↔ collector 通訊規格
- SPEC-006 Python SDK — API 設計模式參考

## 問題描述

Mobile app 需要監控能力：crash 自動捕獲、使用者行為追蹤、效能指標量測。Flutter 的 Isolate 模型和 App lifecycle 管理與 Python/JS 不同，SDK 需要處理 Isolate 安全、背景 flush、Platform channel 攔截等平台特有問題。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | sdk-flutter（Dart）|
| 檔案 | sdk-flutter/ 全新建 |
| 依賴 | collector (v0.1.0)、schema/event.schema.json、docs/transport.md |
| 用例 | Mobile app 行為監控、crash 回報、效能追蹤 |

## 範圍界定

### 本提案要做的（In Scope）

**六個公開 API**（教學依據：[模組三 SDK 公開 API](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/public-api.md)）：

1. `init()` — 初始化 SDK、建立 session、啟動 flush 計時器
2. `event()` — 記錄行為事件（非阻塞）
3. `error()` — 記錄錯誤事件（自動附加 stack trace）
4. `metric()` — 記錄數值指標
5. `flush()` — 強制送出 buffer
6. `close()` — 資源釋放、最後一次 flush

**攢批送出**（教學依據：[攢批送出策略](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)）：

7. Buffer + flush interval + buffer size 三條件觸發
8. Heartbeat 整合（buffer 為空時注入 `sdk.heartbeat`）

**離線容錯**（教學依據：[離線 buffer 與重試](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/offline-buffer.md)）：

9. 記憶體 FIFO buffer（MVP 策略）
10. Collector 不可達時保留 buffer、恢復後重試

**自動攔截**（教學依據：[自動攔截機制](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/auto-intercept.md)）：

11. `FlutterError.onError` — Widget build/layout/paint 例外
12. `PlatformDispatcher.instance.onError` — 非同步區域未處理例外

**Flutter 平台適配**（教學依據：[Flutter 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/flutter-platform.md)）：

13. Isolate 安全 — main isolate buffer + 子 isolate event forwarding
14. App lifecycle 監聽 — paused 時 flush、resumed 時重試、detached 時 close
15. `source.sdk = "flutter"`、`source.platform` 自動偵測（ios / android / macos / linux / web）

**Timestamp**（教學依據：[跨平台 timestamp 一致性](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/cross-platform-timestamp.md)）：

16. ISO 8601 + 時區偏移（Dart 需手動附加 `DateTime.now().timeZoneOffset`）

### 本提案不做的（Out of Scope）

- Platform channel 攔截（效能影響需評估，標為第二階段）
- 本地 persistence（`getApplicationSupportDirectory()` + JSONL，第二階段）
- 感測器框架（前端感測器、NavigatorObserver 路由追蹤，第二階段）
- Obfuscation symbolication（release mode stack trace 解析）
- SDK config collector 下發（`/config` endpoint）

## 提案方案

### 架構概要

```
Flutter App (Dart)                Collector (Go)
    |                               |
    | Monitor.init()                |
    |  └─ session start event       |
    |  └─ start flush timer         |
    |  └─ register lifecycle obs.   |
    |  └─ register error handlers   |
    |                               |
    | Monitor.event() / error()     |
    |  └─ event → buffer            |
    |                               |
    | [flush timer / buffer full]   |
    |  └─ POST /v1/events (batch)   |
    |-----------------------------> |
    |         200/207/400/503       |
    | <---------------------------- |
    |                               |
    | [AppLifecycleState.paused]    |
    |  └─ flush buffer              |
    |                               |
    | [AppLifecycleState.detached]  |
    |  └─ Monitor.close()           |
```

### 技術選型

| 決策 | 選擇 | 理由 |
|------|------|------|
| HTTP client | `dart:io` HttpClient | 零外部依賴、支援 keep-alive |
| Buffer 同步 | Dart single-threaded（main isolate）| Dart 單執行緒模型天然 thread-safe |
| Isolate 通訊 | SendPort / ReceivePort | 標準 Dart IPC |
| Lifecycle | WidgetsBindingObserver | Flutter 官方 lifecycle 回呼 |
| Package 格式 | pub.dev package | Flutter 標準套件發佈 |

### 教學模組對應

| MVP 項目 | 對應教學模組 |
|---------|-------------|
| 六個公開 API | 模組三：SDK 公開 API |
| 攢批送出 | 模組三：攢批送出策略 |
| 離線容錯 | 模組三：離線 buffer 與重試 |
| 自動攔截 | 模組三：自動攔截機制 |
| Isolate + Lifecycle | 模組五：Flutter 平台適配 |
| Timestamp | 模組五：跨平台 timestamp 一致性 |

## 驗收條件

- [ ] `init / event / error / metric / flush / close` 六個 API 可用
- [ ] init 前呼叫 event 拋出 `MonitorNotInitializedError`
- [ ] close 後呼叫 event 靜默忽略
- [ ] 累積 N 筆後自動 flush
- [ ] flush interval 到時自動 flush
- [ ] collector 不可達時 buffer 保留、恢復後送出
- [ ] Buffer 超過上限時 FIFO 丟棄最舊
- [ ] `FlutterError.onError` 捕獲 widget build error 並記錄
- [ ] `PlatformDispatcher.instance.onError` 捕獲非同步未處理例外
- [ ] App 進入 paused 時自動 flush
- [ ] App detached 時自動 close
- [ ] 子 isolate 透過 SendPort 送事件到 main isolate buffer
- [ ] Timestamp 為 ISO 8601 + 時區偏移
- [ ] **端到端驗收**：Flutter app 啟動 → init → 送事件 → collector query 查到

## Reality Test / 觸發案例實證

### 觸發案例

1. app_tunnel 專案需要 mobile app 監控能力，Flutter SDK 是直接使用者
2. PROP-001 驗證了 collector + transport 設計可行，Flutter SDK 復用相同 collector

### 假設列舉

- 假設 1：Dart 單執行緒模型不需要 Lock（buffer 操作天然 atomic）
- 假設 2：App paused → flush 在 iOS 5 秒 suspend 窗口內能完成
- 假設 3：子 isolate 透過 port 轉發事件的延遲 < 1ms

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | schema 設計（PROP-001）、transport 規格（PROP-001）、collector 接收能力（PROP-001）|
| 未驗證 | Dart HttpClient 在 app 背景時的行為、Isolate port 轉發效能、detached 時間窗口 |

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| iOS 背景 flush 超時 | 事件遺失 | 截斷策略：送最近 N 筆，放棄較舊 |
| Release mode obfuscation | Stack trace 不可讀 | MVP 接受原始 trace，symbolication 標為第二階段 |
| Isolate 數量多時 port 開銷 | 記憶體增長 | 限制 port 數量、設 TTL |

## 討論記錄

### 2026-06-22

- 從 PROP-001 完成後的開發優先序規劃
- 確認六個 API（含 metric）為教學定義的完整介面
- Flutter 平台適配參考 blog 模組五
