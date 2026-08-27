---
id: SPEC-006
title: "Python SDK"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.1"
owner: ""

domain: sdk
subdomain: python

related_usecases: [UC-01, UC-02]
related_specs: [SPEC-001, SPEC-002]
implements_requirements: []
depends_on_domains: [core]
---

# Python SDK

## 概述

Python 監控 SDK，提供事件上報、攢批送出、離線容錯能力。首要驗證場景是框架 Hook 系統（`.claude/hooks/`）的執行監控。

教學依據：[模組三：SDK 公開 API](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/public-api.md)、[模組五：Python 平台適配](https://github.com/tarrragon/blog/blob/main/content/monitoring/05-platform-adaptation/python-platform.md)

## 功能需求

### FR-01: 五個公開 API

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01, UC-02 |

**描述**：

| 方法 | 用途 | 行為 |
|------|------|------|
| `init(endpoint, app, version, **kwargs)` | 初始化 | 建立 session、啟動 flush 計時器、記錄 `lifecycle.session.start` |
| `event(name, data=None)` | 記錄行為事件 | 非阻塞，事件進 buffer |
| `error(exception_or_msg, data=None)` | 記錄錯誤 | 自動附加 stack trace、錯誤類型 |
| `flush()` | 強制送出 buffer | 同步，等待 HTTP 回應 |
| `close()` | 資源釋放 | flush 剩餘事件、停止計時器、記錄 `lifecycle.session.end` |

**約束條件**：

- `init()` 前呼叫其他方法應 raise `MonitorNotInitializedError`
- `close()` 後呼叫 `event()` / `error()` 靜默忽略（app 正在關閉）
- 所有上報方法非阻塞（進 buffer 立即返回）

**驗收標準**：

- [ ] 五個 API 皆可呼叫且行為符合描述
- [ ] init 前呼叫 event 拋出明確錯誤
- [ ] close 後呼叫 event 不拋錯

### FR-02: 攢批送出

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-01 |

**描述**：事件進入內部 buffer，滿足以下任一條件時 flush：

| 條件 | 預設值 | 可設定 | 教學預設值 |
|------|--------|--------|----------|
| 時間間隔 | 5 秒 | `flush_interval` | 30 秒（自用通用值） |
| 累積筆數 | 10 筆 | `buffer_size` | 50-200 筆 |
| 手動呼叫 | `flush()` | - | - |

Python SDK 預設值低於教學通用值的理由：首要驗證場景是框架 Hook 系統（`.claude/hooks/`），Hook 腳本的生命週期極短（通常 < 1 秒），需要更積極的 flush 確保事件在腳本結束前送出。教學的 30 秒 / 100 筆適合長時間運行的 app，不適合短生命週期腳本。

**驗收標準**：

- [ ] 累積 10 筆後自動 flush
- [ ] 5 秒到時自動 flush（即使不滿 10 筆）
- [ ] `flush()` 立即送出

### FR-03: 離線容錯

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 |
| 對應用例 | UC-02 |

**描述**：collector 不可達時，事件保留在記憶體 buffer。Buffer 上限 100 筆，超過時丟棄最舊事件（FIFO）。恢復後下次 flush 重試。

**驗收標準**：

- [ ] collector 不可達時事件不丟失（buffer 內）
- [ ] buffer 超過 100 筆時丟棄最舊
- [ ] collector 恢復後事件成功送出

### FR-04: Python 平台適配

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-02 |

**描述**：

- `atexit` 註冊 `close()` 確保程式結束時 flush
- Thread-safe buffer（`threading.Lock`）
- `source.sdk = "python"`，`source.platform` 自動偵測（`sys.platform` → macos / linux / script）

**驗收標準**：

- [ ] 程式正常結束時自動 flush（atexit）
- [ ] 多 thread 同時呼叫 event 不 deadlock

## 介面規格

```python
from monitor import Monitor

# 初始化
Monitor.init(
    endpoint="http://localhost:9090/v1/events",
    app="claude-hooks",
    version="1.0.0",
    flush_interval=5,  # 秒
    buffer_size=10,
)

# 記錄事件
Monitor.event("hook.run", {"hook": "branch-status-reminder", "duration_ms": 42})

# 記錄錯誤
try:
    do_something()
except Exception as e:
    Monitor.error(e, {"step": "validation"})

# 手動 flush
Monitor.flush()

# 關閉
Monitor.close()
```

## Transport 整合

完整 transport 規格見 `docs/transport.md`。以下為 SDK 端的關鍵行為摘要：

### Batch format

```json
{ "batch_id": "019537a0-7b2c-7def-8a2b-3c4d5e6f7890", "events": [ ... ] }
```

`batch_id` 使用 UUID v7（`uuid.uuid7()`，Python 3.14+），flush 時產生。

### 對 Collector 回應的處理

| Status | SDK 行為 |
|--------|---------|
| 200 | 清除 buffer |
| 207 | 清除 buffer + warning log（schema 問題重試也不會過） |
| 400 | 清除 buffer + error log（同上） |
| 503 | 保留 buffer，等 `retry_after` 秒後重試 |
| 其他 | 保留 buffer，下次 flush 重試（上限 3 次後丟棄） |

教學依據：[攢批送出策略 — SDK 對 collector 回應的處理](https://github.com/tarrragon/blog/blob/main/content/monitoring/03-sdk-design/batch-flush.md)

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| Hook 短生命週期 | Hook 可能在 < 1 秒內結束 | `atexit` + `close()` 雙保險 flush |
| 零外部依賴 | 只用 Python 標準庫 | 無 requests，用 urllib |
| 單例模式 | `Monitor` 為 module-level 單例 | init 呼叫一次 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本 |
| 1.1 | 2026-06-22 | 新增 Transport 整合段（batch format + response handling），引用 transport.md |
