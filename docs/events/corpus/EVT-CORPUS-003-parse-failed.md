---
id: EVT-CORPUS-003
name: "ParseFailed"
canonical_name: "Corpus.Document.Rejected"
category: domain_event
status: draft
created: "2026-08-26"
updated: "2026-08-26"

payload: null

producers: ['Corpus']
consumers: ['Diagnostics']
---

# EVT-CORPUS-003: ParseFailed

## 事實

單一文件解析失敗，該文件未進入圖譜。

## 負載結構

`path: String`、`reason: String`、`line: int?`

> 具體型別待 SPEC 產出後定案。

## 設計註記

**單檔失敗不中止整輪解析**。舊框架版本的專案（如 book_overview_v1）文件殘缺是常態而非例外，全有全無會讓整個專案無法檢視。失敗的檔案成為破洞報告的一項。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
