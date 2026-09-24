---
id: EVT-CORPUS-003
name: "ParseFailed"
canonical_name: "Corpus.Document.Rejected"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-09-24"

payload: null

producers: ['Corpus']
consumers: ['Diagnostics']
---

# EVT-CORPUS-003: ParseFailed

## 事實

單一文件解析失敗，該文件未進入圖譜。

## 負載結構

`path: String`、`reason: String`、`line: int?`、
`nodeType: String?`、`candidateTypes: List<String>`、`schemaAmbiguous: bool`、
`salvagedFields: List<String>`、`lostFields: List<String>`、
`severity: edgeAffecting | detailOnly`

- `reason` 值域：無 frontmatter／frontmatter 未閉合／frontmatter 為空或非 map／YAML 語法錯誤／無法讀取（SPEC-006 FR-01、FR-05）
- `nodeType`：「路徑對型別」查詢命中一型時為該型；平手時為 null，`candidateTypes` 列出全部候選，`schemaAmbiguous` 為 true
- 0.3.0 的 `salvagedFields` 恆為空清單，`severity` 恆為 `edgeAffecting`（SPEC-006 FR-04）

> 具體型別待 SPEC 產出後定案。

## 設計註記

本事件的設計目標是回報**這個檔案救回了哪些欄位、損失了哪些**，而不是「這個檔案沒了」。
0.3.0 尚未實作部分救回（語料中沒有足夠樣本校準），因此救回清單恆為空，損失清單為該型別的完整性集合。
單檔失敗不中止整輪解析。

`lostFields` 的算法（2026-09-24 依 `tarrragon/claude#99` 第三項裁決）：
該節點型別在 `tracking_schema.json` 的完整性集合，減去實際寫出的鍵。
值為 `null` 或空清單的鍵算「已寫出」（代表明確沒有），不列入 `lostFields`。
型別沒有集合時（Ticket 的權威在 ticket skill），`lostFields` 為空清單。
集合匯出到 JSON 之前不實作（`0.3.0-W1-079`）。

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

**真正的高頻形態是「無 frontmatter」**（2026-08-27 量測：1290 / 7106），其中
1243 個是 README、工作日誌等合法非節點檔。不做區分，破洞報告會有 96% 是雜訊。

**發送條件**（2026-09-24 依 SPEC-006 v1.2 改寫）：檔案沒拿到可用 frontmatter
（無 frontmatter、未閉合、空或非 map、YAML 語法錯誤、無法讀取五種之一），**且**
其路徑經 Schema 的「路徑對型別」查詢命中某個節點型別的 carrier，Corpus 才發出本事件。
路徑模式取自型別表的機器可比對欄位（專案 JSON 缺此欄位、版本不高於內建版本時由 App
內建表補），不解析人讀的 `carrier` 描述文字。負載另帶歸屬型別；`severity` 在
0.3.0 一律為 `edgeAffecting`。詳見 SPEC-006 FR-04、FR-06。上方數字是舊量測，
0.3.0 的整合測試改用重新量測並凍結的測資。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
