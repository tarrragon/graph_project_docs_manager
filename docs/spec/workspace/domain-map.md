---
id: DOMAIN-MAP-workspace
domain: "workspace"
source_specs: [SPEC-005]
related_usecases: [UC-01, UC-06]
depends_on_bundles: [DOMAIN-MAP-observability]
path_patterns: [lib/workspace/]
created: "2026-08-26"
updated: "2026-11-03"
---

# Domain Map — Workspace

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Workspace domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Workspace domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：資料夾存取方式改變

## 2. 分層與依賴方向

層級：L1（層級圖與完整依賴邊見系統層 §2）。2026-11-10 加入 Observability 出邊後，由 L0 推導為 L1（`1.0.0-W3-553.2.1`）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Observability（`DOMAIN-MAP-observability`） | driven port 的日誌以 `LogSink<E>` 與白名單型別發出（SPEC-010 FR-03、FR-04）；2026-11-10 新增（`1.0.0-W3-553.2.1`，用戶裁定依賴邊照實登記） |
| 入邊 | Corpus | 取得專案根路徑 |
| 入邊 | History | 取得專案根路徑後直接查 git 物件庫，不經 Corpus（見系統層 §4.3） |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Workspace | 是 | 公開面含「可用性狀態」；資料夾不可用與開啟原始檔結果（`opened`／`notFound`／`failed`，SPEC-003 §2.2〈外部開啟契約〉）皆佔用使用者呈現焦點 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Workspace** | 資料夾存取方式改變 | 目前路徑、可用性狀態、開啟原始檔、最近專案清單、健康計數（持久化快照：每輪掃描完成寫入最近專案清單對應項，問題數＝破洞報告總項數，SPEC-005 §2.4〈計數快照〉） | 路徑持久化、可用性探測、清單持久化 |

## 7. 驗收條文 → Bundle 覆蓋對照

### SPEC-005（整份 spec 以 workspace 為主體，無 FR 編號）

| 驗收條文 | 覆蓋 | 備註 |
|---|---|---|
| SPEC-005 全文 | Workspace | 整份 spec 以本 domain 為主體 |

本 domain 在 SPEC-006、SPEC-007 無 FR 歸屬。SPEC-003 逐 FR 的跨 domain 對照見系統層 §8。

---

**Last Updated**: 2026-11-05（`0.6.0-W1-175.1`：§7 擴充為驗收條文對照並補 SPEC-005 列）；前次 2026-11-03 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）；健康計數來源定案（0.6.0-W1-018.1）
