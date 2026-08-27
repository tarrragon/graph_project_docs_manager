---
id: PROP-009
title: "Error Fingerprint 與去重分群"
status: draft
source: development
proposed_by: "error 調查效率提升"
proposed_date: "2026-06-24"
confirmed_date: null
target_version: v0.3.0
priority: P2
evaluation_level: standard

outputs:
  spec_refs:
    - spec/collector/error-fingerprint.md
  usecase_refs: [UC-09]
  ticket_refs: []

related_proposals: [PROP-001, PROP-007]
supersedes: null
---

# PROP-009: Error Fingerprint 與去重分群

## 需求來源

教學模組四 [Error Fingerprint 與去重分群](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/error-fingerprint.md) 定義了 error 去重分群機制。PROP-001 的 dashboard Error 列表用 `GROUP BY name`，同名但不同根因的 error 混在一起、不同名但同因的 error 分開顯示。Fingerprint 提供比 name 更精確的分群。

教學依據：
- [模組四：Error Fingerprint 與去重分群](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/error-fingerprint.md) — fingerprint 演算法、message normalization、error_groups 表設計
- [模組二：event.schema.json 完整欄位解說](https://github.com/tarrragon/blog/blob/main/content/monitoring/02-log-schema/event-schema-fields.md) — `_fingerprint` collector 附加欄位定義

## 問題描述

Dashboard Error 列表的 `GROUP BY name` 在以下情境失效：同一個 name 對應多個不同 root cause（`app.exception` 的 stack trace 指向不同位置）；不同 name 其實是同一個 root cause（`ws.connect.failed` 和 `ws.reconnect.failed` 都是 server 下線）。

## 範圍界定

### 本提案要做的（In Scope）

**Fingerprint 計算**：

1. 基礎版：`SHA256(error_type + ":" + normalizeMessage(error_message))` hex 前 16 字元
   - 進階版（事件帶 stack trace 時）：`SHA256(error_type + ":" + top_3_frames)`
   - SDK 端可用 `data.fingerprint` 覆蓋自動計算

**Message normalization**：

2. 基礎規則（day-one）：
   - UUID → `{uuid}`
   - Email → `{email}`
   - IPv4 → `{ip}`
   - 3+ 位數字 → `{N}`
   - 20+ 字元引號字串 → `{string}`
   - HTTP status code 等已知語意數字用具名 pattern 保留（在 `\d{3,}` 之前匹配）
3. 進階規則（按需追加）：
   - ISO 8601 timestamp → `{ts}`
   - 使用者路徑（`/Users/*/`、`/home/*/`）→ `{path}`

**Storage 擴充**：

4. Events 表加 `fingerprint TEXT` 欄位 + index

```sql
ALTER TABLE events ADD COLUMN fingerprint TEXT;
CREATE INDEX idx_fingerprint ON events(fingerprint);
```

5. 新建 `error_groups` 表

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

6. Status 支援 `open` / `resolved` / `ignored`；resolved 的 group 收到新事件時自動 reopen

**寫入 pipeline 擴充**：

7. Schema validation 之後、storage 寫入之前加 fingerprint 計算步驟
   - Pipeline：`HTTP → Schema validation → Fingerprint 計算 → Events INSERT → error_groups UPSERT`
   - UPSERT：count+1、更新 last_seen、resolved → reopen

**Dashboard Error 列表升級**：

8. 從 `GROUP BY name` 改為查 error_groups 表
   - Group 詳情：最近 N 筆事件的 stack trace、受影響 version / platform 分佈

### 本提案不做的（Out of Scope）

- Source map 反解（minified JS → 原始碼行號）
- ProGuard / R8 mapping 反混淆
- ML-based grouping
- 進階 issue 管理（assign / merge / snooze / trend）

## 驗收條件

- [ ] 同 error_type + 同 message 的事件歸為同一 fingerprint group
- [ ] Message 中的動態值（數字 / UUID / IP）被 normalize 後歸同組
- [ ] SDK 端指定 `data.fingerprint` 時覆蓋自動計算
- [ ] error_groups 表 count 遞增、first_seen / last_seen 正確
- [ ] Resolved 的 group 收到新事件時自動 reopen
- [ ] Dashboard Error 列表用 fingerprint 分群、非 name 分群
- [ ] 已有的 Error 列表 SQL（`GROUP BY name`）被替換為 error_groups 查詢

## 風險與權衡

| 風險                         | 影響                   | 緩解措施                                                   |
| ---------------------------- | ---------------------- | ---------------------------------------------------------- |
| Normalization 過度           | 不同 error 歸同組      | HTTP status code 等語意數字用具名 pattern 保留             |
| Normalization 不足           | 同因 error 分裂        | 根據分裂狀況逐步補 normalize 規則                          |
| session_count 子查詢效能     | 高寫入量下 UPSERT 慢   | 改為定期 job 重新計算（每小時）                             |
| fingerprint collision        | 不同 error 碰撞        | SHA256 前 16 hex = 64 bits，自架場景 error 種類遠低於閾值  |
