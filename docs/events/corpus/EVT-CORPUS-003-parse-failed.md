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

`path: String`、`reason: String`、`line: int?`、
`salvagedFields: List<String>`、`lostFields: List<String>`、
`severity: edgeAffecting | detailOnly`

> 具體型別待 SPEC 產出後定案。

## 設計註記

**單檔失敗不中止整輪解析，且失敗是部分的而非全毀。**

實測 flutter_balance 的 130 個損壞 ticket：100% 可部分救回，平均救回 20.3 個
欄位，`id` / `title` / `status` / `type` 損失率為 0%，`acceptance` 損失率 100%。
損壞自斷點向後蔓延，斷點之前完好。

因此本事件的語意不是「這個檔案沒了」，而是「這個檔案救回了哪些、損失了哪些」。
`severity` 區分兩級：`edgeAffecting`（損失的欄位含邊，影響圖結構）與
`detailOnly`（僅影響詳情內容），對應 UI 上兩種不同強度的標記。

失敗的檔案成為破洞報告的一項，且報告需帶足夠資訊供使用者直接修復原始檔——
**壞資料是專案的缺陷，本 App 的職責是讓它被看見，不是替它掩蓋。**

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
