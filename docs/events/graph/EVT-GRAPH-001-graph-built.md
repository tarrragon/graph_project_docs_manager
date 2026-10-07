---
id: EVT-GRAPH-001
name: "GraphBuilt"
canonical_name: "Graph.Model.Built"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-09-30"

payload: null

producers: ['Graph']
consumers: ['Layout', 'Diagnostics']
---

# EVT-GRAPH-001: GraphBuilt

## 事實

圖模型已建立，邊已完成 symmetric union。

## 負載結構

`nodeCount: int`、`edgeCount: int`、`graphDefects: List<GraphDefect>`

`graphDefects` 逐筆列出 Graph 回報的缺陷，子類為 `danglingRef`（斷邊）、`malformedRef`（格式錯誤，含自我引用）、`duplicateId`、`multiSource`（單值正向欄位經兩側聯集得到多個終點）。欄位與判準以 SPEC-007 為準。

> 2026-09-30 依 SPEC-007 定案：原暫定的 `danglingEdges` 併入 `graphDefects`。

## 設計註記

`relatedTo` 語意對稱但儲存單向（`reverse_field` 為 `null`），因此建圖時必須做 1-hop symmetric union，只讀單向會漏掉一半的邊。斷邊（指向不存在節點）不丟棄，交給 Diagnostics。

有反向欄位的邊任一側宣告即建邊，邊上記錄宣告來源（`docs/tech-decisions.md` 2026-09-30 補記、SPEC-007 FR-04）。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/system-layer.md`。
