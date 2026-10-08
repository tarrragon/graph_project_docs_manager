---
id: DOMAIN-MAP-diagnostics
domain: "diagnostics"
source_specs: [SPEC-006, SPEC-007]
related_usecases: [UC-05, UC-06]
depends_on_bundles: [DOMAIN-MAP-corpus]
path_patterns: [lib/diagnostics/]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — Diagnostics

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Diagnostics domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Diagnostics domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：「什麼算破洞」的定義改變

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Corpus（`DOMAIN-MAP-corpus`） | 取解析錯誤事件（EVT-CORPUS-003），由此產生破洞 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Diagnostics | 是 | 破洞掃描完成通知（SPEC-003 §2.2〈系統層通知〉），App 啟動時自動觸發，不由使用者當下操作發起 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Diagnostics** | 「什麼算破洞」的定義改變 | 破洞清單（分類、嚴重度、跳轉目標） | 各類偵測規則 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test，不靠「剛好出現在某個 UC 場景」被動覆蓋。規則權威在 SPEC-006，本表只列可獨立斷言的不變式；目標路徑為 `lib/diagnostics/`（此為目標邊界，非現況：2026-09-24 規劃時該目錄尚不存在）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC-006 |
|---|---|---|
| Diagnostics | 一筆 EVT-CORPUS-003 對應一筆 `parseFailure` 破洞；破洞數等於命中 carrier 數 | FR-08 |
| Diagnostics | 查詢不可用時不產生 `parseFailure` 破洞，回報「無法判定」 | FR-08 |

## 6. 待決事項

- `Diagnostics` 的破洞類別權威清單見 `EVT-DIAGNOSTICS-001`（本檔不複述計數），
  各類別下的具體項目與嚴重度尚未列舉。UC-06 的驗收條件依賴此清單

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-006（0.3.0 Corpus）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-08 | 由 EVT-CORPUS-003 產生破洞 | Diagnostics | domain unit；IT-2 |

> SPEC-006 全表的權威在 `docs/spec/corpus/domain-map.md` §7；此處僅列歸屬本 domain 的列。

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-09 | 由 EVT-GRAPH-001 產生 `graphDefect` 破洞 | Diagnostics | domain unit；IT-2 |

> SPEC-007 全表的權威在 `docs/spec/graph/domain-map.md` §7；此處僅列歸屬本 domain 的列。Diagnostics 經 EVT-GRAPH-001 接收缺陷，不依賴 Graph 的內部結構。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
