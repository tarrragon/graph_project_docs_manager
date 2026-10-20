---
id: EVT-CORPUS-001
name: "CorpusParsed"
canonical_name: "Corpus.Scan.Completed"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-10-21"

payload: null

producers: ['corpus']
consumers: ['graph', 'ticketdetail', 'diagnostics']
---

# EVT-CORPUS-001: CorpusParsed

## 事實

專案資料夾內的文件已完成一輪解析。

## 負載結構

`rawNodes`、`rawEdges`、`parseErrors`

> 具體型別待 SPEC 產出後定案。

## 設計註記

Corpus 是唯一的解析者，三個消費方各自投影：Graph 由原始節點建輕節點與邊，TicketDetail 取 5W1H 全文，Diagnostics 取原始節點判定事件類破洞（flow 步驟的 emits／consumes 對照 EVT 宣告），並取掃描摘要中無法判定型別的檔數。解析失敗不經本事件轉交，由 EVT-CORPUS-003、004、005 各自發出。若讓消費方各自解析，容錯規則會分歧。

> 2026-10-21：原文寫「Diagnostics 取錯誤清單」。解析失敗已拆為 003（未進入圖譜的檔案）、004（flow 區塊）、005（非 domain 路徑清單）三個事件，Diagnostics 從本事件讀的是原始節點與摘要計數，依現況改寫（`0.5.0-W1-458.1`）。consumers 宣告不變。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/system-layer.md`。
