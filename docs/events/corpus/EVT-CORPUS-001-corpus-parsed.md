---
id: EVT-CORPUS-001
name: "CorpusParsed"
canonical_name: "Corpus.Scan.Completed"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Corpus']
consumers: ['Graph', 'TicketDetail', 'Diagnostics']
---

# EVT-CORPUS-001: CorpusParsed

## 事實

專案資料夾內的文件已完成一輪解析。

## 負載結構

`rawNodes`、`rawEdges`、`parseErrors`

> 具體型別待 SPEC 產出後定案。

## 設計註記

Corpus 是唯一的解析者，三個消費方各自投影：Graph 取輕節點與邊，TicketDetail 取 5W1H 全文，Diagnostics 取錯誤清單。若讓消費方各自解析，容錯規則會分歧。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
