---
id: DOMAIN-MAP-CORE
domain: "core"
source_specs: [SPEC-001]
related_usecases: [UC-01, UC-02, UC-03]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — Core

> 產出來源：ticket 0.5.0-W1-002（版本-Wave-序號，追蹤於 `docs/work-logs/`）。本文件定義 core domain 的邊界——它只有一個東西：event schema。
> 與 `docs/usecases/traceability.yaml`（UC↔測試）、`docs/spec/core/event-schema.md`（SPEC-001 FR 清單）交叉引用。

**術語對照**：SPEC = 功能規格（`docs/spec/` 下各檔）；FR = Functional Requirement；UC = Use Case（`docs/usecases/`）；VO = Value Object；shared kernel = 跨 domain 共用的核心定義。

## 1. 目的與 UC / DDD 正交關係

Core domain 定義跨平台統一的事件格式契約（`schema/event.schema.json`）。所有 SDK 和 collector 都依賴此契約。Core 不含 aggregate（無持久化實體）、不含 read-model（無衍生計算），是純 supporting VO / shared kernel 層。

**核心準則**：core 是零依賴的純定義層——不依賴任何其他 domain、不含 I/O、不含框架。任何欄位變更必須先改 schema，再同步更新 collector 和所有 SDK。

## 2. 分層與依賴方向

Core 只有一個 VO（EventSchema），沒有 aggregate 也沒有 read-model——在 DDD 分類上是退化形態，只充當 collector 和 sdk 的共享依賴葉節點。

```
collector domain  ──depends on──>  core/EventSchema (shared kernel)
sdk domain       ──depends on──>  core/EventSchema (shared kernel)
```

**依賴方向底線（不可違反）**：

- core 不得依賴 collector 或 sdk 任何模組。違反則共享 kernel 被下游汙染，失去跨平台契約獨立性。
- core 不得 import 任何 I/O、HTTP、framework。schema 是純 JSON Schema 定義 + 值物件型別。
- collector 和 sdk 單向依賴 core（core 是依賴樹的葉節點）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| EventSchema | supporting VO（shared kernel） | 四類事件分類 enum（SPEC-001 FR-01）、必填欄位定義（FR-02）、自由欄位 data schema（FR-03）、錯誤詳情 error 結構（FR-04）、session 結構、source 結構 | collector 驗證邏輯實作、SDK 事件建構實作、持久化 DDL | `schema/event.schema.json` | unit：schema 驗證（四類事件各一、缺必填欄位拒絕、data 非 object 拒絕） |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| EventSchema | v 為整數，目前固定值 1；type 限 event/error/metric/lifecycle 四值 enum；name 為必填，使用 namespace.action 格式；timestamp 為 ISO 8601 date-time 格式；source 為必填 object，source.sdk 限 js/flutter/python/go enum，source.platform 為必填 string；data 若存在必為 object 型別；error 若存在含 message/stack/type 三個選填子欄位；session.id 和 batch_id 使用 UUID v7；schema 版本演進用 v 欄位、新版本新增欄位為選填（向後相容） |

## 4. 邊界決策

### 4.1 Core 為純 schema 層，不含驗證實作

定案：`schema/event.schema.json` 是 SOT，各消費端（collector/SDK）各自實作驗證邏輯。Core domain 不提供驗證函式庫。

依據：collector 用 Go JSON Schema 驗證、SDK 各自用語言原生 JSON 序列化。強制統一驗證函式庫會引入跨語言依賴，違反各 SDK 零外部依賴的設計約束。Schema 檔案本身作為契約已足夠。

### 4.2 UUID 統一 v7

session_id 和 batch_id 統一使用 UUID v7，不使用 v4。教學（配套 blog monitoring 系列，見 CLAUDE.md §3）中 v4 是針對商業產品的隱私考量（不可逆推時間），自用工具情境不適用。v7 包含時間資訊，DB B-tree 插入效能更好且可自然排序。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| schema 變更票 | core | 先改 `schema/event.schema.json`，同一票或子票同步 collector 驗證 + 各 SDK 建構 |

## 6. 觀察到的技術債（待追蹤）

- 無。Core 為純 schema 定義，目前結構健康。

## 7. FR -> Bundle 覆蓋對照

### SPEC-001（Event Schema）

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | EventSchema | 四類事件分類 enum |
| FR-02 | EventSchema | 必填欄位驗證規則 |
| FR-03 | EventSchema | data 自由欄位 schema |
| FR-04 | EventSchema | error 詳情結構 |

---

**Last Updated**: 2026-07-23 | **Source**: 0.5.0-W1-002
