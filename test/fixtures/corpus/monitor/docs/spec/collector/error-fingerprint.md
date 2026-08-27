---
id: SPEC-015
title: "Error Fingerprint 與去重分群"
status: draft
source_proposal: PROP-009
created: "2026-06-24"
updated: "2026-06-24"
version: "1.0"
owner: ""

domain: collector
subdomain: error-analysis

related_usecases: [UC-03, UC-09]
related_specs: [SPEC-002, SPEC-007]
implements_requirements: []
depends_on_domains: [core]
---

# Error Fingerprint 與去重分群

## 概述

定義 collector 端的 error fingerprint 計算、message normalization、error_groups 表設計和寫入 pipeline 擴充。取代 dashboard Error 列表的 `GROUP BY name` 分群方式，改用 fingerprint 精確分群。

教學依據：[模組四：Error Fingerprint 與去重分群](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/error-fingerprint.md)

## 功能需求

### FR-01: Fingerprint 計算

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-009 |
| 對應用例 | UC-09 |

**描述**：Collector 收到 `type: "error"` 的事件時，計算 fingerprint hash 並附加到事件。

**基礎版**：`SHA256(error_type + ":" + normalizeMessage(error_message))` hex 前 16 字元。

**進階版**（事件帶結構化 stack trace 時）：`SHA256(error_type + ":" + top_3_frames)`。Top 3 frames 取 stack trace 最頂端的函式名 + 檔案名 + 行號。N=3 是粒度 vs 穩定性的平衡——N=1 過粗（不同 bug 可能在同一函式），N=5 過細（重構後行號改變導致分裂）。

**SDK 端覆蓋**：事件 `data.fingerprint` 欄位存在時，直接使用該值作為 fingerprint，跳過自動計算。

**版本選擇邏輯**：

```text
if data.fingerprint exists → use data.fingerprint
else if structured stack trace exists → 進階版（top 3 frames）
else → 基礎版（type + normalized message）
```

**驗收標準**：

- [ ] 同 error_type + 同 normalized message 的事件產生相同 fingerprint
- [ ] 不同 error_type 的事件即使 message 相同也產生不同 fingerprint
- [ ] 帶 stack trace 的 error 用 top 3 frames 計算
- [ ] SDK 端 `data.fingerprint` 覆蓋自動計算
- [ ] Fingerprint 為 SHA256 hex 前 16 字元（64 bits）

### FR-02: Message Normalization

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-009 |
| 對應用例 | UC-09 |

**描述**：在 fingerprint 計算前，將 error message 中的動態值替換為 placeholder，防止同因 error 因動態值不同而分裂。

**基礎規則（day-one，按匹配優先序排列）**：

| 順序 | Pattern | 替換為 | 範例 |
|------|---------|--------|------|
| 1 | UUID（`[0-9a-f]{8}-...-[0-9a-f]{12}`） | `{uuid}` | `Session a1b2...7890 expired` → `Session {uuid} expired` |
| 2 | Email | `{email}` | `Invalid email foo@bar.com` → `Invalid email {email}` |
| 3 | IPv4 | `{ip}` | `Connection to 192.168.1.1 refused` → `Connection to {ip} refused` |
| 4 | HTTP status code（`\b[1-5]\d{2}\b`） | 保留不替換 | `HTTP 404` 保持原樣 |
| 5 | 3+ 位數字（`\d{3,}`） | `{N}` | `User 12345 not found` → `User {N} not found` |
| 6 | 20+ 字元引號字串 | `{string}` | `Key 'very-long-dynamic-key...' not found` → `Key {string} not found` |

**規則順序重要性**：HTTP status code pattern（順序 4）必須在通用數字 pattern（順序 5）之前匹配，否則 `404` 和 `500` 會被替換成 `{N}` 導致不同 HTTP error 混在一起。

**進階規則（按需追加）**：

| Pattern | 替換為 | 說明 |
|---------|--------|------|
| ISO 8601 timestamp | `{ts}` | `Error at 2026-06-24T14:30:00` → `Error at {ts}` |
| 使用者路徑（`/Users/*/`、`/home/*/`） | `{path}` | `/Users/john/project/app.js` → `{path}/project/app.js` |

**驗收標準**：

- [ ] UUID 被替換為 `{uuid}`
- [ ] Email 被替換為 `{email}`
- [ ] IPv4 被替換為 `{ip}`
- [ ] 3+ 位數字被替換為 `{N}`
- [ ] HTTP status code（1xx-5xx）不被替換
- [ ] 20+ 字元引號字串被替換為 `{string}`
- [ ] 規則按指定順序套用（具名 pattern 優先於通用 pattern）

### FR-03: Storage 擴充（events 表 + error_groups 表）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-009 |
| 對應用例 | UC-09 |

**描述**：

**Events 表擴充**：加 `fingerprint TEXT` 欄位和索引。

```sql
ALTER TABLE events ADD COLUMN fingerprint TEXT;
CREATE INDEX idx_fingerprint ON events(fingerprint);
```

**新建 error_groups 表**：

```sql
CREATE TABLE error_groups (
    fingerprint TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    error_type TEXT,
    normalized_message TEXT,
    count INTEGER NOT NULL DEFAULT 1,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    last_event_id INTEGER REFERENCES events(id),
    session_count INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'open'
);

CREATE INDEX idx_error_groups_last_seen ON error_groups(last_seen);
CREATE INDEX idx_error_groups_count ON error_groups(count);
```

**Status 語意**：

| Status | 語意 | 收到新事件時 |
|--------|------|-------------|
| `open` | 待處理 | count+1，維持 open |
| `resolved` | 已修復 | count+1，自動 reopen 為 open |
| `ignored` | 已知、不處理 | count+1，維持 ignored |

**session_count 策略**：day-one 使用定期 job（每小時）重新計算，避免 UPSERT 子查詢在高寫入量下的效能問題。UPSERT 時 session_count 不更新。

```sql
-- 定期 job：重新計算所有 group 的 session_count
UPDATE error_groups SET session_count = (
    SELECT COUNT(DISTINCT session_id) FROM events WHERE fingerprint = error_groups.fingerprint
);
```

**驗收標準**：

- [ ] events 表有 fingerprint 欄位和索引
- [ ] error_groups 表結構符合上述 DDL
- [ ] Status 轉換邏輯正確（resolved → open on new event）
- [ ] Ignored group 收到新事件時 count 遞增但 status 不變
- [ ] session_count 定期 job 正確計算

### FR-04: 寫入 Pipeline 擴充

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-009 |
| 對應用例 | UC-09 |

**描述**：Schema validation 之後、storage 寫入之前加 fingerprint 計算步驟。只對 `type: "error"` 的事件觸發。

**Pipeline（v0.3.0 含 SPEC-013 背壓）**：

```text
HTTP → Schema validation → Rate limit 檢查 → Fingerprint 計算（error only）→ Channel 送入 → Single-writer → Events INSERT + error_groups UPSERT
```

**error_groups UPSERT 邏輯**：

```text
INSERT INTO error_groups (...) VALUES (...)
ON CONFLICT(fingerprint) DO UPDATE SET
    count = count + 1,
    last_seen = excluded.last_seen,
    last_event_id = excluded.last_event_id,
    status = CASE WHEN status = 'resolved' THEN 'open' ELSE status END
```

**與 SPEC-013 Error 快通道的整合**：Error 事件走 errorCh（跳過 rate limit），但仍經 fingerprint 計算。

**驗收標準**：

- [ ] Error 事件在 channel 送入前完成 fingerprint 計算
- [ ] 非 error 事件不觸發 fingerprint 計算
- [ ] Events INSERT 包含 fingerprint 欄位
- [ ] error_groups UPSERT 在同一 transaction 內
- [ ] Resolved group 收到新事件時 reopen

### FR-05: Dashboard Error 列表升級

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-009 |
| 對應用例 | UC-03, UC-09 |

**描述**：Dashboard Error 列表從 `GROUP BY name` 改為查 error_groups 表。

**Error 列表查詢**：

```sql
SELECT fingerprint, name, error_type, normalized_message,
       count, first_seen, last_seen, session_count, status
FROM error_groups
WHERE status != 'ignored'
ORDER BY last_seen DESC;
```

**Error Group 詳情查詢**（點擊某 group）：

```sql
SELECT * FROM events WHERE fingerprint = ? ORDER BY ts DESC LIMIT 20;
```

**Group 詳情顯示**：最近 N 筆事件的 stack trace、受影響 `source.version` 分佈、受影響 `source.platform` 分佈。

**驗收標準**：

- [ ] Error 列表用 error_groups 表查詢（非 `GROUP BY name`）
- [ ] 列表顯示 count / first_seen / last_seen / status
- [ ] 點擊 group 可查看最近 20 筆事件
- [ ] Ignored group 預設不顯示在列表中
- [ ] 已有的 `GROUP BY name` SQL 被替換

## 非功能需求

### NFR-01: Fingerprint 計算效能

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |

**描述**：Fingerprint 計算在 ingestion pipeline 中是同步步驟（channel 送入前），不應顯著影響寫入延遲。

**驗收標準**：

- [ ] 單筆 fingerprint 計算 < 1ms
- [ ] error_groups UPSERT 不阻塞主 channel 寫入

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| SHA256 前 16 hex | 64 bits collision space | 自架場景 error 種類遠低於 collision 閾值 |
| SDK 端 fingerprint 覆蓋 | `data.fingerprint` 優先於自動計算 | SDK 可在特定場景自定義分群 |
| 與 SPEC-013 背壓整合 | fingerprint 計算在 rate limit 之後、channel 送入之前 | pipeline 順序依賴 |

## 與其他 Spec 的關係

| Spec | 關係 |
|------|------|
| SPEC-002 Ingestion | events 表加欄位，寫入路徑擴充 |
| SPEC-007 Internal Architecture | Pipeline 五段鏈路在 storage 寫入前插入 fingerprint 計算步驟 |
| SPEC-013 Backpressure | Fingerprint 計算在 rate limit 之後、channel 送入之前 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-24 | 初始版本，從教學 error-fingerprint.md + PROP-009 萃取 |
