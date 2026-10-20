---
id: EVT-GRAPH-001
name: "GraphBuilt"
canonical_name: "Graph.Model.Built"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-10-21"

payload: null

producers: ['graph']
consumers: ['layout', 'diagnostics']
---

# EVT-GRAPH-001: GraphBuilt

## 事實

圖模型已建立，邊已完成 symmetric union。

## 負載結構

負載分圖本體與缺陷兩部分，欄位與判準以 SPEC-007 FR-06 為準。

| 部分 | 欄位 | 內容 | 讀取方 |
|------|------|------|--------|
| 圖本體 | `nodes: List<LightNode>` | 輕節點（SPEC-007 FR-02） | 畫面狀態層（破洞報告、Domain 視圖的節點查詢） |
| 圖本體 | `edges: List<GraphEdge>` | 已完成 symmetric union 的邊（FR-04、FR-05） | 鄰接查詢（FR-08） |
| 圖本體 | `flowSubgraphs: Map<String, FlowSubgraph>` | UC ID 對 flow 子圖（FR-10），不進 `edges` | Layout（泳道）、Diagnostics（事件類破洞） |
| 圖本體 | `domainResolver` | domain 名稱索引（FR-11） | 貫穿數與分層查詢（FR-12、FR-13） |
| 缺陷 | `graphDefects: List<GraphDefect>` | Graph 回報的缺陷，逐筆 | Diagnostics（`graphDefect` 破洞，FR-09） |

`nodeCount`、`edgeCount` 由 `nodes`、`edges` 的筆數算出，不另存。

`graphDefects` 的子類：主圖四類 `danglingRef`（斷邊）、`malformedRef`（格式錯誤，含自我引用）、`duplicateId`、`multiSource`（單值正向欄位經兩側聯集得到多個終點）；FR-09 的 flow 子類；「domain 重複宣告」（FR-11）。

> 2026-10-21：原文只列 `nodeCount`、`edgeCount` 與主圖四類缺陷，與實作 `GraphBuiltEvent` 不符，Layout 與 Diagnostics 實際讀的 `flowSubgraphs` 沒有寫出來；依實作補齊（`0.5.0-W1-460`）。

> 2026-09-30 依 SPEC-007 定案：原暫定的 `danglingEdges` 併入 `graphDefects`。

## 設計註記

`relatedTo` 語意對稱但儲存單向（`reverse_field` 為 `null`），因此建圖時必須做 1-hop symmetric union，只讀單向會漏掉一半的邊。斷邊（指向不存在節點）不丟棄，交給 Diagnostics。

有反向欄位的邊任一側宣告即建邊，邊上記錄宣告來源（`docs/tech-decisions.md` 2026-09-30 補記、SPEC-007 FR-04）。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/system-layer.md`。
