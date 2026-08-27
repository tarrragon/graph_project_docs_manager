---
id: EVT-CORPUS-003
name: "ParseFailed"
canonical_name: "Corpus.Document.Rejected"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-08-27"

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

本事件回報的是**這個檔案救回了哪些欄位、損失了哪些**，而不是「這個檔案沒了」。
單檔失敗不中止整輪解析。

`severity` 區分兩級：`edgeAffecting`（損失的欄位含邊，影響圖結構）與
`detailOnly`（僅影響詳情內容），對應 UI 上兩種不同強度的標記。

失敗的檔案成為破洞報告的一項，且報告需帶足夠資訊供使用者直接修復原始檔——
**壞資料是專案的缺陷，本 App 的職責是讓它被看見，不是替它掩蓋。**

### 觸發條件比原本設想的窄得多

實測五個框架專案 7106 份文件（2026-08-27，採逐行 frontmatter 語意）：
**YAML 解析失敗僅 1 件。** 本事件在真實語料上幾乎不發生。

> 本節先前宣稱「flutter_balance 有 130 個損壞 ticket，100% 可部分救回、
> 平均 20.3 個欄位，`acceptance` 損失率 100%」。該批損壞是量測腳本的產物
> （以 `content.split("---")` 解析 frontmatter，被引號字串內的 markdown
> 表格分隔線截斷）。`severity` 兩級的分法保留，但它現在是**設計判斷而非
> 量測結論**——支撐它的欄位損失分佈已隨該 artifact 失效。完整說明見
> `docs/domain-map.md` §7。

**真正的高頻形態是「無 frontmatter」**（1290 / 7106），但其中 1243 個是
README、工作日誌等合法非節點檔。只有落在節點 carrier 路徑下卻缺 frontmatter
的 47 個檔案才應發此事件——判定依據為 `tracking_schema.json` 的 `carrier` 欄位。
不做這個區分，破洞報告會有 96% 是雜訊。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
