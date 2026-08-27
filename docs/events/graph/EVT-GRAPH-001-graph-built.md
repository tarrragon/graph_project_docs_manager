---
id: EVT-GRAPH-001
name: "GraphBuilt"
canonical_name: "Graph.Model.Built"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Graph']
consumers: ['Layout', 'Diagnostics']
---

# EVT-GRAPH-001: GraphBuilt

## 事實

圖模型已建立，邊已完成 symmetric union。

## 負載結構

`nodeCount: int`、`edgeCount: int`、`danglingEdges: List<EdgeRef>`

> 具體型別待 SPEC 產出後定案。

## 設計註記

`relatedTo` 語意對稱但儲存單向（`reverse_field` 為 `null`），因此建圖時必須做 1-hop symmetric union，只讀單向會漏掉一半的邊。斷邊（指向不存在節點）不丟棄，交給 Diagnostics。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
