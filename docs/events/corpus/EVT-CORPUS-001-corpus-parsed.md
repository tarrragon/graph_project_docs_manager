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

負載的權威條文是 SPEC-006 FR-07：本事件帶 `rawNodes`、`parseErrors` 與掃描摘要計數；邊不在負載內，由 Graph 自原始節點建立（SPEC-007 FR-03、FR-04）。實作為 `lib/corpus/corpus_scanner.dart` 的 `CorpusScanResult`。

`CorpusScanResult` 是一輪掃描的彙整結果，除了本事件的負載，也一併帶著同一輪的 EVT-CORPUS-003／004／005 與非 domain 路徑清單的讀取結果。下表分兩部分列出。

| 部分 | 欄位 | 內容 | 讀取方 |
|------|------|------|--------|
| 本事件負載 | `rawNodes: List<RawNode>` | 每個節點檔的完整 frontmatter map、相對路徑與判定型別；UC 另帶 flow 步驟清單（SPEC-006 FR-07、FR-09） | Graph（建輕節點與邊，`lib/app/scan_round.dart` 呼叫建圖）；TicketDetail（ticket 全文索引，`lib/ticket_detail/ticket_detail.dart`，SPEC-007 FR-07）；Diagnostics（事件類破洞，`detectEventGaps`）；UC Flow 畫面 |
| 本事件負載 | `parseErrors: List<ParseError>` | 本輪全部失敗檔的逐檔紀錄（SPEC-006 FR-04、FR-07）；carrier 外的失敗檔不發 003，只記在這裡 | 只有掃描器自身的完成日誌讀取筆數；其餘消費方不讀，破洞改由下方 003／004／005 產生。保留作逐檔可追溯紀錄與測試觀測點（SPEC-006 FR-07〈逐檔紀錄的用途〉，`0.5.0-W1-471` 結論） |
| 本事件負載 | `summary: ScanSummary` | FR-07 的計數項（節點數、各失敗原因數、carrier 命中與未判定數、flow 失敗 UC 數、`nonDomainPathsMalformedCount` 等）與兩條守恆式 | Diagnostics（取 `undeterminedCount`，SPEC-006 FR-08） |
| 本事件負載 | `schemaAmbiguousNodes: List<SchemaAmbiguousNode>` | `id` 互斥被打破的可用檔案，各附路徑與候選型別（SPEC-006 FR-03） | 目前沒有產品程式讀取（只有測試）；保留理由為 FR-03 要求歧義檔出現在掃描結果（SPEC-006 FR-07〈逐檔紀錄的用途〉，`0.5.0-W1-471` 結論） |
| 同輪其他事件 | `parseFailureEvents: List<ParseFailureEvent>` | EVT-CORPUS-003，未進入圖譜的檔案各一筆 | Diagnostics（`parseFailure` 破洞，SPEC-006 FR-08） |
| 同輪其他事件 | `flowParseFailedEvents: List<FlowParseFailedEvent>` | EVT-CORPUS-004，flow 區塊解析失敗的 UC 各一筆 | Diagnostics；Domain 視圖與 UC Flow 畫面（標示該 UC 的 flow 無法顯示） |
| 同輪其他事件 | `nonDomainPathsRead: NonDomainPathsReadResult` | 非 domain 路徑清單的讀取結果（缺席／已宣告／格式錯誤，SPEC-006 FR-10）；格式錯誤時由此推得 EVT-CORPUS-005（`nonDomainPathsParseFailedEvent`，至多一筆） | Graph（專案層路徑宣告彙整，`lib/graph/project_path_declaration.dart`）；Diagnostics（005 的 `parseFailure` 破洞） |

> 2026-10-21：原文列 `rawNodes`、`rawEdges`、`parseErrors` 並寫「具體型別待 SPEC 產出後定案」。SPEC-006 FR-07 早已定案，`rawEdges` 不存在（邊由 Graph 建），另有摘要、型別判定歧義節點與同輪其他事件的欄位沒有寫出；依 `CorpusScanResult` 現況補齊（`0.5.0-W1-462`）。producers／consumers 宣告不變。同日更正 `parseErrors` 列：原寫「只有測試讀取」，漏了掃描器自身的完成日誌（`0.5.0-W1-459`）。

## 設計註記

Corpus 是唯一的解析者，三個消費方各自投影：Graph 由原始節點建輕節點與邊，TicketDetail 取 5W1H 全文，Diagnostics 取原始節點判定事件類破洞（flow 步驟的 emits／consumes 對照 EVT 宣告），並取掃描摘要中無法判定型別的檔數。解析失敗不經本事件轉交，由 EVT-CORPUS-003、004、005 各自發出。若讓消費方各自解析，容錯規則會分歧。

> 2026-10-21：原文寫「Diagnostics 取錯誤清單」。解析失敗已拆為 003（未進入圖譜的檔案）、004（flow 區塊）、005（非 domain 路徑清單）三個事件，Diagnostics 從本事件讀的是原始節點與摘要計數，依現況改寫（`0.5.0-W1-458.1`）。consumers 宣告不變。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/system-layer.md`。
