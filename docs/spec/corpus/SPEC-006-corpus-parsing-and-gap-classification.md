---
id: SPEC-006
title: "Corpus 解析與破洞判定"
status: draft
source_proposal: PROP-005
created: "2026-09-24"
updated: "2026-09-24"
version: "1.1"
owner: "主線程（PM）"

domain: "corpus"
subdomain: null

related_usecases: [UC-01, UC-05, UC-06]
related_specs: [SPEC-001, SPEC-005]
implements_requirements: []
depends_on_domains: [schema, workspace]
---

# Corpus 解析與破洞判定

## 概述

本規格定義 0.3.0（Corpus）的兩段資料管線。**Corpus** 把工作區內的 markdown
語料解析為原始節點；凡是沒拿到可用 frontmatter 的檔案，一律記下原因。
**Diagnostics** 依 Schema 的 carrier 路徑模式，把這些檔案分成真破洞與合法
非節點。分工依 `docs/domain-map.md` §2 的依賴邊：Corpus 是唯一的解析者；
「這算不算破洞」要同時看解析結果與 carrier，因此歸 Diagnostics。

版本契約（PROP-005 §0.3）為兩項整合測試，本規格的 FR 以它們為驗收終點：

| 整合測試 | 驗收的 FR | 斷言 |
|---------|----------|------|
| IT-1 解析語意 | FR-01 | 待測實作與框架解析函式逐檔比對，切分結果與鍵集合一致；判別樣本在天真語意（`split("---")`）下會截斷，在待測實作下不會 |
| IT-2 破洞分類 | FR-01、FR-05、FR-06 | 由凍結 manifest 實體化的檔案樹，逐列分類結果與參照實作一致 |

兩項的預期值取自重新量測並凍結的測資（見〈設計約束〉D3）。PROP-005 §0.3 記載的
是 2026-08-27 的即時語料數字，之後語料已變動，本規格不沿用。

## 前置依賴

| 依賴 | 擋住 | 承接 |
|------|------|------|
| 上游 schema 提供機器可比對的 carrier 路徑模式與具體度算法 | FR-06、IT-2 | `0.3.0-W1-080` |
| App 內建型別表：專案沒有可用的 `tracking_schema.json` 時，破洞分類改用內建副本。五個語料專案多數屬於這種情況，所以 IT-2 實際上依賴它 | FR-06、IT-2 | `0.3.0-W2-001` |
| 上游 schema 匯出完整性集合 | FR-04 的 `lostFields`（不擋 IT） | `0.3.0-W1-079`（已完成） |

## 本版範圍外

| 項目 | 不在本版的理由 | 承接 |
|------|--------------|------|
| 原始邊（`rawEdges`）的抽取 | 建圖屬 0.4（Graph），兩項整合測試都不需要邊 | PROP-005 §0.4 |
| 破洞類別 `graphDefect`／`traceGap`／`unlocatable` | 需要圖或追溯資料；本版只實作 `parseFailure` | EVT-DIAGNOSTICS-001、PROP-005 §0.4／§0.6+ |
| frontmatter 可用、位於 carrier 路徑內，但 `id` 缺席或不符合任何型別的 `id_pattern` | 歸哪一類破洞仍待決（`docs/domain-map.md` §9） | `0.3.0-W1-081` |
| YAML 損壞檔的部分欄位救回 | 語料中 YAML 錯誤僅 1 件（`docs/domain-map.md` §7，2026-08-27 對五個語料專案 7106 份文件量測），部分救回的演算法沒有樣本可以校準 | 本版只回報、不救回（FR-04） |

## 功能需求

### FR-01：frontmatter 切分與失敗分類

**描述**：Corpus 以逐行語意切出 frontmatter。切分方式與框架既有函式
（`.claude/skills/doc/doc_system/core/frontmatter_parser.py` 的 `_find_closing_delimiter`）相同。
失敗分類另外定義：框架函式把所有失敗都回傳 None，本規格要把失敗原因交給使用者去修，
所以分成五種。

**切分規則**：

| # | 規則 |
|---|------|
| 1 | 檔案開頭的 UTF-8 BOM 先移除 |
| 2 | 行分隔只認 `\n` 與 `\r\n`（不採用 Python `splitlines()` 認得的其他分隔字元，兩種語言在這點不一致） |
| 3 | 第一行去除前後空白後必須等於 `---`，否則歸「無 frontmatter」 |
| 4 | 從第二行往下找**第一個**去除前後空白後等於 `---` 的行作為結尾 |
| 5 | 兩者之間的內容以 YAML 解析 |
| 6 | 禁止以字串切分（`split("---")`）取 frontmatter：frontmatter 內被引號包住的 markdown 表格分隔線（`|---|`）會使其提前截斷 |

**結果分類**（每個檔案恰好落入一種）：

| 結果 | 條件 |
|------|------|
| 可用 | YAML 解析成功且結果是非空 map |
| 無 frontmatter | 違反切分規則 3 |
| frontmatter 未閉合 | 符合規則 3，但規則 4 找不到結尾 |
| frontmatter 為空或非 map | 開頭與結尾之間是空內容、只有註解，或解析結果不是 map |
| YAML 語法錯誤 | YAML 解析器回報錯誤 |

（第五種「無法讀取」見 FR-05，發生在切分之前。）

**等價範圍**：與框架函式比對時只比切分結果與鍵集合，不比值。PyYAML 依 YAML 1.1，
Dart `package:yaml` 依 1.2，兩者對 `yes`／`no`、日期等值的型別解讀不同。

**驗收條件**：
- [ ] Given 一份 frontmatter 內含引號字串 `"|---|---|"` 的真實 ticket，When 以本實作解析，Then 結果為「可用」，鍵集合與框架函式相同
- [ ] Given 同一份檔案，When 以天真語意解析，Then 取得的鍵數少於本實作，或產生 YAML 錯誤（證明判別樣本確實能區分兩種語意）
- [ ] Given 合成樣本：帶 BOM、只有開頭 `---`、`---` 後緊接 `---`、只含註解、YAML 結果為清單、第一行不是 `---`，Then 分別歸入「可用」「未閉合」「空或非 map」「空或非 map」「空或非 map」「無 frontmatter」

### FR-02：掃描範圍

**描述**：Corpus 掃描工作區根目錄下 `docs/` 內所有副檔名為 `.md` 的檔案（遞迴）。

**規則**：
- 範圍與 PROP-005 §0.3 量測時一致（`docs/**/*.md`）；carrier 路徑模式全部落在 `docs/` 之下
- 工作區根目錄取自 Workspace domain（`docs/domain-map.md` §2 依賴邊 Corpus → Workspace）
- 路徑一律以相對於工作區根目錄、以 `/` 分隔的形式參與後續比對

**驗收條件**：
- [ ] Given 工作區含 `docs/` 以外的 `.md`，Then 不進入掃描結果
- [ ] Given `docs/` 下多層子目錄內的 `.md`，Then 全部進入掃描結果

### FR-03：節點判型

**描述**：結果為「可用」的檔案，以其 `id` 比對 Schema 各節點型別的 `id_pattern` 判型。

**規則**：
- 型別判別以 `id_pattern` 為準，不以 carrier 為準（`docs/domain-map.md` §7）
- 各型別 `id_pattern` 兩兩互斥，由上游 conformance 測試保證，一個 `id` 至多命中一型
- `id` 缺席或不命中任何型別：計入「有 frontmatter 的非節點」，本版不產生節點，也不產生破洞（見〈本版範圍外〉第三列）

**驗收條件**：
- [ ] Given frontmatter `id: SPEC-001`，Then 判為 SPEC；Given `id: DOMAIN-MAP-docs-graph`，Then 判為 DomainBundle
- [ ] Given frontmatter 無 `id`，Then 不產生節點也不產生破洞，計入「有 frontmatter 的非節點」
- [ ] Given frontmatter `id: v0.1.0-note`（不符合任何 `id_pattern`），Then 同上

### FR-04：解析錯誤事件

**描述**：結果不是「可用」的檔案，Corpus 都記入 EVT-CORPUS-001 的 `parseErrors`；
其中經 FR-06 判為真破洞者，才發出 EVT-CORPUS-003。這與 EVT-CORPUS-003〈觸發條件〉一致：
carrier 路徑外的失敗檔（例如一千多份沒有 frontmatter 的工作日誌）不發事件，
否則破洞報告的輸入有九成以上是雜訊。

**規則**：
- 錯誤帶相對路徑、原因（FR-01 結果分類或 FR-05 的「無法讀取」）、行號（解析器提供時）
- `salvagedFields` 本版一律為空清單，不做部分救回
- `lostFields` 依 EVT-CORPUS-003〈lostFields 的算法〉：該型別完整性集合減去實際寫出的鍵。
  失敗檔沒有可用的 `id`，型別取 FR-06 依 carrier 歸出的型別；平手（schema 歧義）時為空清單
- 單檔失敗不中止整輪掃描

**驗收條件**：
- [ ] Given 一份 YAML 語法錯誤的檔案與其他正常檔案，Then 產生一筆原因為 YAML 語法錯誤的解析錯誤，其他檔案照常解析
- [ ] Given 落在 DomainBundle carrier 路徑內、沒有 frontmatter 的檔案，Then `salvagedFields` 為空清單，`lostFields` 等於 DomainBundle 的完整性集合
- [ ] Given 不命中任何 carrier 的失敗檔，Then 記入 `parseErrors`，但不發出 EVT-CORPUS-003

### FR-05：讀取失敗

**描述**：檔案無法以 UTF-8 解碼時（用戶裁決 D4），結果為「無法讀取」，與 FR-01 的四種失敗一起交給 FR-06 分流。

**規則**：
- 不以寬鬆解碼（取代無效位元組）繼續解析，避免亂碼進入圖譜
- 讀取失敗不中止整輪掃描

**驗收條件**：
- [ ] Given carrier 路徑內一份非 UTF-8 的 `.md`，Then 產生一筆原因為「無法讀取」的破洞
- [ ] Given carrier 路徑外一份非 UTF-8 的 `.md`，Then 不產生破洞，且掃描完成

### FR-06：破洞分類（Diagnostics）

**描述**：對結果不是「可用」的檔案（FR-01 的四種失敗與 FR-05 的無法讀取，用戶裁決 A），
以 Schema 各型別的 carrier 路徑模式判定為真破洞或合法非節點，產生 EVT-DIAGNOSTICS-001
的 `parseFailure` 類別。

**規則**：

| # | 規則 |
|---|------|
| 1 | 比對完整相對路徑（含檔名），不只比對所在目錄（`docs/domain-map.md` §7：2026-08-27 對 book_overview_v1 實測，目錄讀法報 8 項，其中 7 項誤報） |
| 2 | 路徑模式取自型別表中的機器可比對欄位（用戶裁決 D1），不解析人讀的 `carrier` 描述文字。型別表來源依〈前置依賴〉：專案 JSON，或 App 內建副本 |
| 3 | 只有 carrier 是檔案路徑的型別參與比對；FlowStep 的 carrier 是 UC 文件內的區塊，不參與 |
| 4 | 路徑比對區分大小寫 |
| 5 | 命中任一型別模式 → 真破洞；全不命中 → 合法非節點，不報 |
| 6 | 同時命中多個型別時，依具體度取一型（用戶裁決 D2、B）：先比字面段數，多者優先；再比跨多段的萬用字元數，少者優先；仍平手時，破洞列出全部候選型別並標記「schema 歧義」 |
| 7 | 每一筆破洞帶相對路徑、歸屬型別（或平手時的候選型別）、原因（FR-01 或 FR-05 的結果），資訊足以讓使用者直接去修 |

**驗收條件**：
- [ ] Given IT-2 的實體化檔案樹，When 逐檔分類，Then 每一檔的結果與參照實作一致
- [ ] Given `docs/spec/<domain>/README.md` 無 frontmatter，Then 為合法非節點（不命中 SPEC）
- [ ] Given `docs/spec/<domain>/domain-map.md` 無 frontmatter，Then 為真破洞，歸屬型別為 DomainBundle
- [ ] Given `docs/work-logs/` 下非 `tickets/` 目錄的工作日誌，frontmatter 有 YAML 語法錯誤，Then 為合法非節點，不報
- [ ] Given 兩個測試用型別的模式對某路徑平手，Then 破洞列出兩個候選型別並標記 schema 歧義

### FR-07：掃描結果摘要

**描述**：一輪掃描完成時，產出 EVT-CORPUS-001（`rawNodes`、`parseErrors`）與
EVT-DIAGNOSTICS-001（`gaps`），並提供可驗證的計數。

**計數項**：節點數、有 frontmatter 的非節點數、各種失敗原因的數量（FR-01 四種 + 無法讀取）、真破洞數、合法非節點數。

**守恆式**：
1. 掃描檔案總數 = 節點數 + 有 frontmatter 的非節點數 + 各失敗原因數量總和
2. 各失敗原因數量總和 = 真破洞數 + 合法非節點數

**規則**：`rawNodes` 攜帶該檔完整 frontmatter map、相對路徑與判定型別；邊的抽取不在本版。

**驗收條件**：
- [ ] Given 一份分布已知的 fixture（每個計數項至少一檔），Then 各計數項等於已知值，兩條守恆式成立
- [ ] Given IT-2 的實體化檔案樹與 NFR-01 插入失敗檔的語料，Then 兩條守恆式成立

## 非功能需求

### NFR-01：失敗隔離

任一單檔失敗都不得中止整輪掃描，也不得改變其他檔案的結果。
**驗收**：在正常語料中，為〈錯誤處理〉表列出的每一種單檔失敗各插入一份，其餘檔案的解析結果與未插入時逐項相同。

## 錯誤處理

| 錯誤情境 | 處理方式 | 對應 |
|---------|---------|------|
| 檔案無法以 UTF-8 解碼 | 結果為「無法讀取」，交 FR-06 分流 | FR-05 |
| 只有開頭 `---`，找不到結尾 | 結果為「frontmatter 未閉合」，交 FR-06 分流 | FR-01 |
| frontmatter 為空、只有註解，或結果不是 map | 結果為「frontmatter 為空或非 map」，交 FR-06 分流 | FR-01 |
| frontmatter YAML 語法錯誤 | 結果為「YAML 語法錯誤」，不救回欄位，交 FR-06 分流 | FR-01、FR-04 |
| 專案 JSON 與 App 內建型別表都沒有機器可比對的 carrier 欄位 | FR-06 無法執行，否則會把全部失敗檔誤判為合法非節點。處置：不產生 `parseFailure` 破洞，破洞報告顯示「無法判定破洞」並說明原因；解析（FR-01～FR-04）照常進行。專案 JSON 缺欄位但內建表有時，依 SPEC-001 v1.5 §1 的降級路徑改用內建表，並顯示降級徽章（SPEC-003 v1.7 §3.1） | FR-06 規則 2 |

## 設計約束

| # | 約束 | 來源 |
|---|------|------|
| D1 | carrier 路徑模式由上游 schema 以機器可比對欄位提供，App 不解析描述文字 | 用戶裁決 2026-09-24；`0.3.0-W1-080` |
| D2 | 無可用 frontmatter 的檔案命中多個 carrier 時，依具體度二層比較取一型，平手標記 schema 歧義 | 用戶裁決 2026-09-24（D2、B） |
| D3 | 整合測試使用凍結測資，預期值由獨立的參照實作產生 | 用戶裁決 2026-09-24（D3、C） |
| D4 | 非 UTF-8 檔依 carrier 分流，不寬鬆解碼 | 用戶裁決 2026-09-24 |
| D5 | 完整性集合（`lostFields` 所用）的語意為「欄位必須存在，值可為 null 或空清單」 | `tarrragon/claude#99` 第三項裁決；`0.3.0-W1-078` |
| D6 | 所有沒拿到可用 frontmatter 的檔案都走 carrier 分流，包括 YAML 語法錯誤 | 用戶裁決 2026-09-24（A） |

**D3 的展開**：

- **為什麼凍結**：CI 環境讀不到本機的語料專案（`~/project`），0.2.0 的 gate manifest 測試基於同樣的理由採用凍結（`test/integration/gate_manifest_test.dart`）。
- **manifest 欄位**：相對路徑、檔案形態（可用 frontmatter／FR-01 的四種失敗／無法讀取）、預期分類與歸屬型別。
- **實體化**：測試執行時依 manifest 在暫存目錄建出檔案樹。可用的寫最小 frontmatter，各種失敗寫出對應的真實形態，無法讀取的寫入無效 UTF-8 位元組。掃描器讀取真實檔案，不直接讀 manifest 的形態欄；否則 FR-01、FR-05 會被繞過。
- **預期值來源**：一份獨立的 Python 參照實作，依 FR-06 規則產生，不用待測實作的輸出。不沿用 `docs/domain-map.md` §7 的目錄類別，因為目錄讀法與 FR-06 規則 1 衝突。
- **樣本覆蓋**：manifest 至少各含一筆真破洞、合法非節點、D2 多型別衝突、無法讀取。語料中沒有的類型用合成列補上，並標記為合成。
- **IT-1 樣本**：收錄天真語意會截斷的真實檔案，另加 FR-01 驗收條件列出的合成邊界樣本。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.1 | 2026-09-24 | 依兩份審查（文字、技術）修正：失敗分類擴為五種並統一走 carrier 分流（裁決 A）；具體度二層比較，平手標記 schema 歧義（裁決 B）；IT-2 改為實體化檔案樹，預期值由參照實作產生（裁決 C）；IT-1 改為與框架函式逐檔比對；新增〈前置依賴〉節；FR-07 加總數守恆；補齊各 FR 驗收 |
| 1.0 | 2026-09-24 | 初版：0.3.0 規劃波 Step 2，依 PROP-005 §0.3 與用戶裁決 D1～D5 建立 |
