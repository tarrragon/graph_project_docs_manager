---
id: DOMAIN-MAP-graph
domain: "graph"
source_specs: [SPEC-007]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05]
depends_on_bundles: [DOMAIN-MAP-corpus]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — Graph

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Graph domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Graph domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：圖語意改變（如 symmetric union 規則）

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Corpus（`DOMAIN-MAP-corpus`） | 圖建自解析產物 |
| 入邊 | Layout | 布局的輸入是圖 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Graph | 否 | 索引與遍歷為內部計算，無對外呈現面 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Graph** | 圖語意改變（如 symmetric union 規則） | 輕節點、邊、**鄰接查詢**（SPEC-007 FR-08）、**貫穿數**（domain × UC，依 FlowStep `traverses` 聚合）、**路徑→domain 查詢**（對照表由 Graph 持有，表內容待建，見 0.1.0-W3-352） | 索引結構、遍歷演算法 |

## 5. 對實作票的切分指引

- Graph 的票不得依賴 UI —— 遍歷與 symmetric union 皆為純函式，可獨立測試

## 6. 待決事項

- ~~**`鄰接查詢` 的簽章未定**~~（§2.5）：2026-09-30 定於 SPEC-007 FR-08，為 1 hop 查詢。
  矩陣的「間接依賴」需要多 hop，屬 0.5 規劃，會在此 API 之上組合

> 「路徑模式 → domain」對照表由 Graph 持有（內容待建）；該待決事項本體在系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | 邊型表 | Schema | domain unit |
| FR-02 | 輕節點（含重複 ID） | Graph（讀 Corpus `rawNodes`） | domain unit；IT-3 |
| FR-03 | 引用值抽取與三類分類、守恆 | Graph | domain unit；IT-2 |
| FR-04 | 邊的方向與建邊來源：反向欄位兩側聯集、宣告來源、依正向基數判多來源衝突 | Graph | domain unit；IT-1 |
| FR-05 | `relatedTo` 1-hop 對稱聯集 | Graph | domain unit；IT-1 |
| FR-06 | 建圖結果、計數與 EVT-GRAPH-001 | Graph | domain unit |
| FR-07 | TicketDetail 以 ID 查詢全文 | TicketDetail（讀 Corpus `rawNodes`） | domain unit；IT-3 |
| FR-08 | 鄰接查詢 | Graph | domain unit；IT-1 |
| FR-09 | 由 EVT-GRAPH-001 產生 `graphDefect` 破洞 | Diagnostics | domain unit；IT-2 |
| NFR-01 | 缺陷隔離 | Graph | domain unit |
| NFR-02 | 計算量線性 | Graph | `test/performance/`（不入主套件） |

全部 FR 皆有歸屬，無標為非 domain 者。Graph 與 TicketDetail 都只讀 Corpus 產物、彼此不依賴（§4.1）；
Diagnostics 經 EVT-GRAPH-001 接收缺陷，不依賴 Graph 的內部結構。

> 本表為 SPEC-007 全表的權威（與 spec 同目錄，供 `check_domain_coverage` 定位）；歸屬 Schema、TicketDetail、Diagnostics 的列在各自 domain map §7 另列副本。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
