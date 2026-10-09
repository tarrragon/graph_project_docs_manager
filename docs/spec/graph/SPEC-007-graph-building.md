---
id: SPEC-007
title: "建圖：輕節點、邊的聯集與圖結構破洞"
status: draft
source_proposal: PROP-005
created: "2026-09-30"
updated: "2026-10-08"
version: "1.26"
owner: "主線程（PM）"

domain: "graph"
subdomain: null

related_usecases: []
related_specs: [SPEC-006]
implements_requirements: []
depends_on_domains: [schema, corpus, diagnostics]
---

# 建圖：輕節點、邊的聯集與圖結構破洞

## 概述

本規格定義 0.4.0（Graph）的資料管線：把 Corpus 產出的節點（SPEC-006 FR-07 的 `rawNodes`）
建成圖。依賴方向照 `docs/system-layer.md` §2（Graph → Corpus）。涉及的 domain 與職責：

| Domain | 本規格內的職責 | 對應 FR |
|--------|--------------|--------|
| **Schema** | 提供邊型表（正向欄位、反向欄位、正向基數、類別、層級） | FR-01 |
| **Graph** | 建輕節點；抽取引用值並分類；建邊；鄰接查詢；UC flow 子圖；domain 名稱解析；domain × UC 關係與依賴路徑；DomainBundle 分層與層內排序 | FR-02～FR-06、FR-08、FR-10～FR-13 |
| **TicketDetail** | 持有 ticket 的 frontmatter 全文，以 ID 查詢（`docs/system-layer.md` §4.1 界定，本規格首次定義其公開面） | FR-07 |
| **Diagnostics** | 由 Graph 回報的缺陷產生 `graphDefect` 破洞 | FR-09 |

版本契約（PROP-005 §0.4）為三項整合測試，本規格的 FR 以它們為驗收終點：

| 整合測試 | 驗收的 FR | 斷言 |
|---------|----------|------|
| IT-1 聯集 | FR-04、FR-05、FR-08 | 由凍結 manifest 實體化的語料建圖，邊集合與凍結的參照實作輸出一致。比對鍵為（邊型、起點、終點、宣告來源）；無向邊的兩端依 ID 字典序排列。另斷言：對每一筆只由一端宣告的 `relatedTo`，未宣告的一端做鄰接查詢也查得到對方（只讀單向時查不到，證明測資有鑑別力） |
| IT-2 缺陷交給 Diagnostics | FR-03、FR-09 | 同一份語料，破洞集合與凍結的參照實作輸出一致。另斷言：解析成功、斷邊、格式錯誤三類計數的總和，等於參照實作從 manifest 獨立算出並凍結的引用值總數（總數不由待測實作自己計算，否則靜默丟值時守恆式仍成立） |
| IT-3 輕節點與全文分離 | FR-02、FR-07 | 圖上每個節點只帶輕節點欄位；ticket 的 frontmatter 全文只能經 TicketDetail 以 ID 取得 |

EVT-GRAPH-001 是 domain 之間的資料事件（Graph→Diagnostics／Layout），不佔使用者呈現通道：Graph 無對外呈現面（`docs/system-layer.md` §3.2）。佔用使用者注意力的是 Diagnostics 其後的掃描完成通知，已由 SPEC-003 FR-11 標定。

斷言來源：`EVT-GRAPH-001`、`docs/system-layer.md` §4.1、`docs/tech-decisions.md` 2026-09-30 兩則補記（反向邊讀取規則、來源邊多值）。

## 用詞

| 詞 | 定義 |
|----|------|
| 使用中邊型 | 型別表中 `layer` 為 `established` 的邊型，扣除 `domain_dependency`，加上 `layer` 為 `proposed` 的 `bundle_dependency`（FR-01、D6） |
| 無向邊 | 型別表 `direction` 欄為 `undirected` 的邊型（FR-05）；`directed` 為有向 |
| 引用值 | 單一節點、單一欄位中的單一項。純量欄位是一個引用值；清單欄位每一項各是一個引用值；反向欄位的值是 map 時（如 `outputs`），每個子鍵的清單每一項各是一個引用值 |
| 宣告來源 | 一條邊由哪些端點宣告，型別為端點 ID 的集合。有向邊：起點宣告＝起點的正向欄位列出終點；終點宣告＝終點的反向欄位列出起點。無向邊：列出對方的那一端 |
| 正向基數 | 型別表為每個邊型宣告的值：`one` 表示一個節點的正向欄位最多指向一個終點，`many` 表示可指向多個（FR-01） |
| 缺陷 | Graph 回報的一筆問題（FR-02、FR-03、FR-04），收在 EVT-GRAPH-001 的 `graphDefects` |
| 破洞 | Diagnostics 由一筆缺陷產出的一筆 `graphDefect`（FR-09） |

## 前置依賴

| 依賴 | 擋住 | 承接 |
|------|------|------|
| 上游 schema 的邊型表帶正向基數欄位 | FR-01、FR-04 | `0.4.0-W1-056` |
| App 內建型別表副本含正向基數；UC-01 的 `source_proposal` 改為兩個來源 | FR-01 的內建補值、IT-1 的凍結測資 | `0.4.0-W2-001` |
| PROP→SPEC 的反向資料與正向一致 | IT-1 的凍結測資 | `0.4.0-W1-045`（已完成） |
| 上游 #98 第二項（`spec_refs` 存或推導） | 無：聯集規則不依賴其結果（tech-decisions 2026-09-30） | — |

## 本版範圍外

| 項目 | 不在本版的理由 | 承接 |
|------|--------------|------|
| `depends_on_domains`（`domain_dependency` 邊） | 值是 domain 名稱而非節點 ID（兩語料實測），個別 domain 不是圖節點；與 0.5「矩陣的列無來源」是同一個問題（用戶裁決 2026-09-30） | `0.5.0-W1-001` |
| B 層邊（`emits`／`consumes`／`branch_from`／`return_to`）與 FlowStep 主圖節點 | 已裁決（`0.5.0-W1-001` 裁決 C，2026-10-07）：FlowStep 不進主圖，`branch_from`／`return_to` 以 UC flow 子圖提供（FR-10），不建邊；`emits`／`consumes` 不在 0.5.0 子圖的解析範圍。升級為主圖節點屬加法變更，本版不做 | FR-10 |
| 破洞「孤島」「缺必要邊」 | 「必要邊」未定義（哪種節點必須有哪種邊）；本版的缺陷子類以 FR-09 所列為準（用戶裁決 2026-09-30） | `0.6.0-W1-072` |
| 貫穿數、路徑→domain 查詢 | 依賴 FlowStep `traverses` 與路徑對照表，屬 0.5。`traverses` 的名稱解析已由 FR-11 定義；聚合為貫穿數與路徑→domain 查詢不在本規格。例外：domain × UC 關係（直接／間接／無關）與依賴路徑的判定歸 Graph，已由 FR-12 定義（`0.5.0-W1-114` 用戶裁決 O1） | PROP-005 §0.5 |
| 語料變動後的增量重建（EVT-CORPUS-002） | 本版只做單輪完整建圖；重掃屬畫面接真資料的互動 | PROP-005 §0.6 |
| 引用值的部分救回（例：從 `0.2.1-W3-1057 驗收` 抽出 ID） | 與 SPEC-006「不部分救回」一致；救回規則會猜錯（兩個 ID 寫在同一字串） | 本版只回報（FR-03） |

## 功能需求

### FR-01：邊型表（Schema 公開面）

**描述**：Schema 從型別表 JSON 的 `edge_types` 解碼邊型，供 Graph 查詢。與節點型別同一份來源、同一套版本判定（SPEC-006 FR-06 規則 7）。

**規則**：
- 每個邊型帶：鍵名（如 `association`、`spawn`）、`class`、`forward_field`、`reverse_field`（可為 null）、正向基數（`one`／`many`）、`direction`（`directed`／`undirected`）、`layer`
- 使用中邊型見〈用詞〉。欄位名、基數、是否有反向欄位、方向性一律取自型別表，不在程式內寫死。本版以鍵名寫死的只有兩處（設計約束 D6）：排除 `domain_dependency`，以及納入 `proposed` 層的 `bundle_dependency`
- 專案型別表的邊型條目缺 `direction` 欄（舊框架匯出的 JSON，例如 2.40.3 版 17 條皆缺）：版本在 App 已知範圍內時，依該邊型鍵名從內建表補 `direction`，並回報 `direction` 來源為內建表；內建表也沒有該鍵名時照 `directed` 處理，回報的來源值為「預設（有向）」（`0.5.0-W1-103.1` 用戶裁決 H1，2026-10-08，沿用 SPEC-006 D8 前例；來源值依 `0.5.0-W1-113` PM 處置 N-B）。查的是內建表的資料，不是程式內的鍵名例外，D6 的鍵名例外不因此增加。不可把缺欄一律當 `directed`：`association` 會變成單向，違反 `relatedTo` 語意對稱的約定。版本不在已知範圍時已由既有規則涵蓋，不另定：該專案 JSON 走 SPEC-001 §1「schema 不相容」關卡、不被消費；使用者改以內建型別表檢視時，內建表本身帶 `direction`（`0.5.0-W1-103.1` PM 處置，2026-10-08）。繞過關卡的呼叫路徑上，邊型解碼對「版本不在已知範圍且缺 `direction`」回報建圖不可用，與缺正向基數一致，不得當 `directed`（`0.5.0-W1-001.7` 審查回報 D2，PM 處置 2026-10-09，FR-01「不可一律當 directed」的直接推論）；原因碼為獨立的 `missingDirection`（`EdgeTypeUnavailableReason` 新增值，依缺漏欄位命名，與 `missingForwardCardinality` 並列；不重用 `projectVersionOutOfKnownRange`——該值的成因是缺 `edge_types`，不同成因各用一個原因碼，日誌據此區分，同下方「邊型條目不合法」第三個值的原則；識別名為 PM 決定）。同一張表同時缺正向基數與缺 `direction` 時回報 `missingForwardCardinality`（原因碼優先序：`invalidEdgeTypeEntry` ＞ `missingForwardCardinality` ＞ `missingDirection`；Diagnostics 對三者投影同一顯示值，優先序只影響日誌，PM 處置 2026-10-09）
- 專案型別表缺 `edge_types`，或其中缺正向基數欄位：版本在 App 已知範圍內則從內建表補；否則建圖不可用，回報原因碼（與 SPEC-006 FR-08 同一套「無法判定」原因）
- 單一邊型條目不合法（值不是 map；`class`、`forward_field`、`layer` 缺席或不是字串；`reverse_field` 存在但不是字串，null 合法；`direction` 存在但不是字串（含明寫 `null`；與 `reverse_field` 不同，`direction` 沒有 null 的合法語意）、或不是 `directed`／`undirected` 之一——`direction` 缺席不屬此列，依上方缺欄規則，`0.5.0-W1-001.7` 用戶裁決 Q1，2026-10-09）：該條目整筆拒收並寫日誌，視同該邊型缺席，依缺欄位的規則處置——版本在 App 已知範圍內時該邊型取內建表的定義；否則建圖不可用，原因碼為「邊型條目不合法」（與缺 `edge_types`、缺正向基數各自獨立的第三個值，日誌據此區分）。同一張表同時有不合法條目與缺正向基數的條目時，只回報「邊型條目不合法」：不合法條目在解碼階段就被拒收，先於基數補值判定。版本在已知範圍內、但內建表也沒有該鍵名時（上游已刪除該邊型，舊專案表仍留著且條目不合法），該邊型不建邊，只寫拒收日誌，建圖仍可用：兩張表都沒有可讀的定義，而內建表是已知範圍內的權威，不認得的邊型不屬於 App 所知的圖。`edge_types` 本身不是 map 時視同缺 `edge_types`。邊型條目的問題只影響 Graph，不得中斷 Corpus 對同一型別表 `node_types` 的解碼
- 專案型別表整份缺席（`tracking_schema.json` 不存在）：建圖不可用，回報版本不在已知範圍的原因碼。這是 SPEC-001 §1「無可消費的型別表」的顯式關卡，Graph 不自動降級；使用者選「以 App 內建型別表檢視」後，呼叫端以內建表作為專案型別表傳入，建圖可用，使用中邊型取自內建表（`docs/tech-decisions.md` 2026-09-03「型別表缺席時降級而非拒絕」）。呼叫端的接線屬 PROP-005 §0.6 畫面接真資料

**驗收條件**：
- [ ] Given 內建型別表，Then 解碼出的邊型集合與內建表 `edge_types` 的鍵集合相同，使用中邊型等於 established 邊型扣除 `domain_dependency`、加上 `bundle_dependency`
- [ ] Given 內建型別表，Then 其餘 proposed 邊型（`bundle_dependency` 以外）不是使用中邊型（E2 正向對照）
- [ ] Given 測試用型別表新增一個 established 邊型，Then 該邊型自動成為使用中邊型，Graph 依其欄位抽取
- [ ] Given 測試用型別表把某使用中邊型的 `forward_field` 改名，Then Graph 依新欄位名抽取，不讀舊欄位名
- [ ] Given 專案型別表缺 `edge_types` 且版本在已知範圍內，Then 解碼出的邊型集合與內建表相同，建圖可用
- [ ] Given 專案型別表缺 `edge_types` 且版本高於內建版本，Then 建圖不可用，回報原因碼，不產生 `graphDefect`
- [ ] Given 專案型別表整份缺席，Then 建圖不可用，回報版本不在已知範圍的原因碼
- [ ] Given 專案型別表某邊型的值是字串、版本在已知範圍內，Then 不拋例外，該邊型取內建表定義，建圖可用，`node_types` 解碼結果與該條目正常時相同
- [ ] Given 同上但版本高於內建版本，Then 建圖不可用，Corpus 掃描照常完成
- [ ] Given 降級模式（內建表作為專案型別表傳入），Then 建圖可用，使用中邊型等於內建表 established 邊型扣除 `domain_dependency`、加上 `bundle_dependency`
- [ ] Given 專案型別表全部邊型條目缺 `direction`、版本在已知範圍內，Then `association` 的 `direction` 取自內建表為 `undirected`，A 列出 B 時查 A、B 都得到該關聯（E2 正向對照：缺欄不得當 `directed`），並回報 `direction` 來源為內建表
- [ ] Given 專案型別表有一個內建表沒有的邊型且缺 `direction`、版本在已知範圍內，Then 該邊型照 `directed` 處理，回報的 `direction` 來源值為「預設（有向）」（不是「內建表」）
- [ ] Given 版本在已知範圍內、某邊型 `direction` 為 `"undirect"`（或非字串），Then 該條目整筆拒收並寫日誌，該邊型取內建表定義（E2：不得只補 `direction` 而沿用條目其餘欄位）
- [ ] Given 版本不在已知範圍、邊型條目缺 `direction`（繞過關卡呼叫），Then 建圖不可用（E2：不得當 `directed`）

### FR-02：輕節點

**描述**：Graph 為每個 `rawNode` 建一個輕節點。輕節點只帶圖需要的欄位（`docs/system-layer.md` §4.1）。

**輕節點欄位**：`id`、節點型別、`status`（缺席為 null）、`title`（缺席為 null）、相對路徑。不帶 frontmatter map 的其他欄位，也不保留對它的引用。

**規則**：
- 同一個 `id` 出現在兩個以上的 `rawNode`（兩語料實測為 0）：兩者都不建節點，回報一筆 `duplicateId`（帶全部路徑）。這些節點自己的欄位不抽取引用值，也不計入引用值總數；別的節點指向該 ID 的引用值依 FR-03 歸為斷邊
- `status`、`title` 不是字串時視為缺席（null），不中止建圖

**驗收條件**：
- [ ] Given 任一 ticket 的 `rawNode`，Then 對應輕節點的欄位集合恰為上列五項，且與 frontmatter map 無共用引用
- [ ] Given 兩份檔案的 frontmatter `id` 相同，Then 兩者都不在圖上，回報一筆 `duplicateId` 帶兩個路徑，兩者欄位中的引用值不出現在任何分類計數中
- [ ] Given 第三個節點的 `relatedTo` 列出該重複 ID，Then 該引用值為斷邊，原因碼為 `targetDuplicated`

### FR-03：引用值抽取與分類

**描述**：Graph 對每個節點、每個使用中邊型，讀取正向欄位與（若有）反向欄位，逐一抽取引用值並分類。本版所有邊型都不檢查終點的節點型別。

**抽取**：
- 欄位缺席、值為 null、空字串、空清單：不產生引用值
- 清單內的 null 項：跳過，不計為引用值
- 反向欄位的值是 map 時（兩語料中只有 PROP 的 `outputs`）：每個子鍵的清單每一項各是該邊型的一個反向引用值。判定依值的形狀，不依欄位名（設計約束 D6）；子鍵名稱只是分組，規格不列舉，新子鍵自動納入；子鍵值不是清單時，該子鍵計為一個引用值，歸格式錯誤
- 形狀不合法（欄位值為數字或布林；正向欄位的值為 map；清單項不是字串）：每個清單項（純量欄位則為整個欄位）計為一個引用值，歸格式錯誤

**分類**：依下列順序判定，每個引用值落入第一個成立的類別：

| 順序 | 類別 | 條件 | 處置 |
|------|------|------|------|
| 1 | 格式錯誤 | 形狀不合法，或值不符合任何節點型別的 `id_pattern`（值原樣比對，不去除前後空白） | 不建邊，不救回，回報 `malformedRef`（原因碼 `invalidShape`／`patternMismatch`） |
| 2 | 格式錯誤 | 值等於來源節點自己的 `id` | 不建邊，回報 `malformedRef`（原因碼 `selfReference`） |
| 3 | 斷邊 | 圖上沒有該 `id` 的節點（含 FR-02 排除的重複 ID） | 不建邊，回報 `danglingRef`（原因碼 `targetMissing`／`targetDuplicated`） |
| 4 | 解析成功 | 其餘 | 參與建邊（FR-04、FR-05） |

**守恆式**：引用值總數＝解析成功數＋斷邊數＋格式錯誤數。

**驗收條件**：
- [ ] Given `source_ticket: 0.1.0-W3-181` 且圖上沒有該節點，Then 回報一筆 `danglingRef`（`targetMissing`），不建邊
- [ ] Given `relatedTo: ["0.1.0-W1-072 0.1.0-W1-073"]`、`discovered_during: "0.2.1-W3-1057 驗收"`、`spawned_tickets: [PENDING]`，Then 三者皆為 `malformedRef`（`patternMismatch`），不建邊，不抽出其中的 ID
- [ ] Given `relatedTo: [" 0.1.0-W1-001"]`（引號內帶前導空白），Then 為 `malformedRef`（`patternMismatch`），不去除空白後重試
- [ ] Given 節點 A 的 `relatedTo` 列出 A，Then 回報 `malformedRef`（`selfReference`），不建邊
- [ ] Given `blockedBy: [0.1.0-W1-001, 42, null]`，Then 產生兩個引用值：`0.1.0-W1-001` 依存在與否分類，`42` 為 `malformedRef`（`invalidShape`）；null 不計
- [ ] Given PROP 的 `outputs` 含子鍵 `design_refs: [SPEC-001]`，Then 該項為 `provenance` 的反向引用值，照常分類
- [ ] Given PROP 的 `outputs` 含子鍵 `notes: "x"`，Then 該子鍵計為一個 `malformedRef`（`invalidShape`）
- [ ] Given 一份分布已知的 fixture，Then 三類計數等於已知值，守恆式成立

### FR-04：邊的方向與建邊來源

**描述**：每個解析成功的引用值對應一條邊的一次宣告。本節定義邊怎麼從宣告建出來。

**方向**：邊由持有正向欄位的一端（起點）指向正向欄位的值（終點）。

| 邊型種類 | 建邊來源 | 宣告來源 |
|---------|---------|---------|
| 有反向欄位（`reverse_field` 非 null） | 起點的正向欄位列出終點，或終點的反向欄位列出起點，任一成立即建邊（`docs/tech-decisions.md` 2026-09-30 補記） | 起點、終點或兩者 |
| `direction` 為 `undirected`（目前只有 `association`／`relatedTo`） | 無向邊，見 FR-05 | 列出對方的一端或兩端 |
| 其餘（`reverse_field` 為 null，`direction` 為 `directed`） | 起點的正向欄位列出終點 | 起點 |

**規則**：
- 同一條邊（邊型、起點、終點相同；無向邊為兩端集合相同）只建一次，宣告來源取各次宣告的聯集
- 多來源衝突：正向基數為 `one` 的邊型，一個起點經上表建邊後指向兩個以上不同的終點時，全部邊照建，另回報一筆 `multiSource`（帶起點、全部終點與各自的宣告來源）。只計解析成功的終點；斷邊只回報 `danglingRef`，不參與本判定
- 正向基數為 `one` 的欄位寫成多項清單時，同樣以上一條處理

**驗收條件**：
- [ ] Given 子票 `source_ticket` 為空、父票 `spawned_tickets` 列出子票，Then 建一條 `spawn` 邊（子→父），宣告來源為 {父}
- [ ] Given 父子兩側都宣告，Then 只建一條邊，宣告來源為 {子, 父}
- [ ] Given 子票 `source_ticket: A`，另一張父票 B 的 `spawned_tickets` 列出子票，Then 建兩條邊（子→A 宣告來源 {子}、子→B 宣告來源 {B}），並回報一筆 `multiSource`
- [ ] Given 子票 `source_ticket` 指向不存在的 X，父票 B 的 `spawned_tickets` 列出子票，Then 建一條邊（子→B），回報一筆 `danglingRef`，不回報 `multiSource`
- [ ] Given UC 的 `source_proposal: [PROP-003, PROP-002]`，兩個 PROP 的 `outputs.usecase_refs` 都列出該 UC，Then 建兩條 `provenance` 邊（UC→PROP-003、UC→PROP-002），宣告來源皆為兩端，不回報 `multiSource`（`provenance` 正向基數為 `many`）
- [ ] Given PROP 的 `outputs.spec_refs` 列出 SPEC-X，SPEC-X 的 `source_proposal` 為同一 PROP，Then 一條 `provenance` 邊（SPEC-X→PROP），宣告來源為兩端

### FR-05：無向邊的 1-hop 對稱聯集

**描述**：無向邊型（目前只有 `association`，欄位 `relatedTo`）語意無向、儲存單向，建圖時做 1-hop 對稱聯集。

**無向的判定**：讀型別表邊型條目的 `direction` 欄，值為 `undirected` 即為無向，不以鍵名或 `class` 推導（2026-09-30 用戶裁決：上游補欄位後改讀欄位、移除鍵名例外；上游欄位由 `0.4.0-W1-072` 落地）。`class` 相同的 see-also 邊型（`spec_association`、`uc_association`、`proposal_association`）在上游宣告為 `directed`，照有向處理。

**規則**：無向邊型的正向欄位，A 列出 B 或 B 列出 A，都建同一條無向邊 {A, B}；宣告來源為列出對方的端點集合。

**驗收條件**：
- [ ] Given 測試用型別表把某個 see-also 邊型的 `direction` 改為 `undirected`，Then 該邊型做對稱聯集（依欄位判定，非依鍵名）
- [ ] Given 測試用型別表把 `association` 的 `direction` 改為 `directed`，Then A 列出 B 時建有向邊 A→B，查 B 的方向為入而非無向（E2 正向對照：鍵名不再有特權）
- [ ] Given A 列出 B、B 未列出 A，Then 邊 {A, B} 存在，宣告來源為 {A}，且對 B 做鄰接查詢會得到 A
- [ ] Given A、B 互相列出，Then 只有一條邊，宣告來源為 {A, B}

### FR-06：建圖結果與事件

**描述**：一輪建圖完成時，Graph 產出 EVT-GRAPH-001，並提供可驗證的計數。

**計數項**：節點數、`duplicateId` 數、各邊型的邊數、各宣告來源形態的邊數（有向邊分僅起點、僅終點、兩端；無向邊沒有起點與終點之分，分一端、兩端，與有向邊分開計數）、FR-03 三類計數、`multiSource` 數。

**規則**：`rawNodes` 為空時照常建出空圖、發出 EVT-GRAPH-001，所有計數為 0，不視為錯誤（與 SPEC-006 FR-02「沒有 `docs/` 時掃描 0 檔」一致）。

**負載**：`nodeCount`、`edgeCount`、`graphDefects`（主圖四類 `danglingRef`、`malformedRef`、`duplicateId`、`multiSource`，與 FR-09 的 flow 子類，逐筆）。EVT-GRAPH-001 的負載說明已於本規格定案時同步改寫（`docs/events/graph/EVT-GRAPH-001-graph-built.md`）。

**驗收條件**：
- [ ] Given 一份分布已知的 fixture，Then 各計數項等於已知值，FR-03 守恆式成立
- [ ] Given `rawNodes` 為空，Then 發出一筆 EVT-GRAPH-001，`nodeCount`、`edgeCount` 為 0，`graphDefects` 為空
- [ ] Given 建圖完成，Then 發出一筆 EVT-GRAPH-001，`graphDefects` 筆數等於斷邊數＋格式錯誤數＋`duplicateId` 數＋`multiSource` 數＋FR-09 各 flow 子類的缺陷數＋「domain 重複宣告」數（後者經 `graphDefects` 傳遞，為子類定義的直接推論，`0.5.0-W1-114.2` PM 處置 NC-4）（原只計主圖四類，與 FR-10／FR-11 的 flow 缺陷收在同一 `graphDefects` 不一致，依 `0.5.0-W1-113` PM 處置 N-A 修正）
- [ ] Given 主圖無缺陷、某 UC 一個步驟的 `traverses` 含一個未宣告名稱，Then `graphDefects` 筆數為 1（E2 正向對照：只計主圖四類時為 0）

### FR-07：TicketDetail

**描述**：TicketDetail 持有 ticket 的 frontmatter 全文（含 5W1H 與生命週期欄位），以 `id` 查詢。Graph 不持有這些欄位（`docs/system-layer.md` §4.1）。

**規則**：
- 查詢來源為同一輪 Corpus 的 `rawNodes`；只收節點型別為 Ticket 者
- 查無該 ID（含 FR-02 排除的重複 ID）時回傳「不存在」，不拋例外
- 本版只提供查詢，不涉及畫面（節點詳情接真資料屬 0.6）

**驗收條件**：
- [ ] Given 一張 ticket 的 `id`，Then TicketDetail 回傳的 map 與該 ticket `rawNode` 的 frontmatter 逐鍵相等（含 `who`／`what`／`when`／`where`／`why`／`how`）
- [ ] Given 不存在的 ID，Then 回傳「不存在」

### FR-08：鄰接查詢（Graph 公開面）

**描述**：給一個節點 ID，回傳 1 hop 內相鄰的節點。解決 `docs/system-layer.md` §1.4「鄰接查詢簽章」。

**輸入**：節點 ID；可選的邊型集合（預設為全部使用中邊型）；方向（出、入、兩者，預設兩者）。

**輸出**：清單，每項帶邊型、另一端的節點 ID、方向（出、入、無向）、宣告來源、該邊型的 `layer`。無向邊在任何方向篩選下都會回傳，方向標為無向。

**proposed 標示**（2026-10-08 用戶裁決，`0.5.0-W1-103`）：使用中邊型中 `layer` 為 `proposed` 者（目前只有 `bundle_dependency`），其回傳項的 `layer` 為 `proposed`，消費端（節點詳情卡、鄰接清單）須據此標示，讓使用者分辨形狀可能變動的邊（`layer` 是穩定性承諾）。`layer` 取自型別表，不以鍵名判定；畫面標示見 SPEC-001 §6 與 SPEC-004。

**規則**：
- 節點 ID 不在圖上時回傳空清單，不拋例外
- 建圖不可用（FR-01）或尚未完成時，回傳「圖不可用」狀態而非空清單。空清單表示「查過且沒有相鄰節點」，兩者分開，畫面才不會把不可用顯示成「沒有關聯」

**驗收條件**：
- [ ] Given 一張子票以 `source_ticket` 指向父票，Then 查子票（方向：出）得到父票，查父票（方向：入）得到子票
- [ ] Given 邊型篩選只含 `blocking`，Then 回傳不含其他邊型
- [ ] Given DomainBundle A 的 `depends_on_bundles` 列出 B，Then 查 A（方向：出）得到 B，邊型 `bundle_dependency`、`layer` 為 `proposed`；查 `spawn` 邊的回傳項 `layer` 為 `established`（對照）
- [ ] Given 不存在的 ID，Then 回傳空清單
- [ ] Given 建圖不可用，Then 任何查詢都回傳「圖不可用」，不回傳空清單

### FR-09：圖結構破洞（Diagnostics）

**描述**：Diagnostics 收到 EVT-GRAPH-001 後，對 `graphDefects` 逐筆產生 EVT-DIAGNOSTICS-001 的 `graphDefect` 破洞。

**子類**：主圖四種為 `danglingRef`、`malformedRef`、`duplicateId`、`multiSource`（原因碼見 FR-02～FR-04）。flow 子圖另有四種，同屬 `graphDefect` 大類，不另立破洞類別（2026-10-08 用戶裁決 1a，`0.5.0-W1-001.2`；第四種「`traverses` 鍵缺席」依 `0.5.0-W1-114` 用戶裁決 T1 與 PM 補定）：

| flow 子類 | 來源 | 負載 |
|----------|------|------|
| flow 參照未解析 | FR-10：`branch_from`、`return_to` 或分支步 `next` 指向同 UC 不存在的 step id；或指向 UC 內重複的 step id | {UC ID, step id, 欄位, 原始值} |
| UC 內 step id 重複 | FR-10：同一 UC 內兩個以上步驟的 `id` 相同 | {UC ID, step id, 欄位, 原始值} |
| `traverses` 名稱未宣告 | FR-11：`traverses` 的值沒有 DomainBundle 以 `domain` 宣告（含因重複宣告被排除於名稱索引的名稱）；同一步驟內同一值重複出現只報一筆 | {UC ID, step id, 欄位, 原始值} |
| `traverses` 鍵缺席 | FR-11：步驟沒有 `traverses` 鍵（schema 必填欄位缺席，不視同 `[]`） | {UC ID, step id, 欄位, 原始值}（欄位為 `traverses`，原始值為 `null`；`0.5.0-W1-114.1` PM 處置 NC-b） |

另有一種非 flow 子圖的名稱索引缺陷，同屬 `graphDefect` 大類（`0.5.0-W1-114.1` PM 處置 NC-d，比照 D3）：

| 子類 | 來源 | 負載 |
|------|------|------|
| domain 重複宣告 | FR-11〈重複 domain 宣告〉：兩個以上 DomainBundle 宣告相同 `domain` 值 | {domain, 衝突的 DomainBundle ID 清單} |

前三種 flow 子類的程式識別名（camelCase 字面）由 `0.5.0-W1-001.8` NeedsContext 上報；第四種 flow 子類與 domain 重複宣告的識別名交實作票定（兩者皆由 `0.5.0-W1-001.5` 命名——皆屬名稱解析器，`0.5.0-W1-114.1` PM 處置 NC-c、`0.5.0-W1-114.2` PM 處置 NC-7）。實作票命名前，其他實作不得自行命名。

**規則**：
- 一筆缺陷對應一筆破洞。`danglingRef`、`malformedRef` 帶來源節點 ID 與路徑、欄位名、原始值（原樣，不正規化）、邊型、原因碼；`duplicateId` 帶 ID 與全部路徑；`multiSource` 帶起點、邊型、全部終點與各自的宣告來源
- flow 四子類的負載一律為 {UC ID, step id, 欄位, 原始值}，不帶邊型：flow 參照不是邊（FR-10），沿用 `danglingRef`／`duplicateId` 的帶邊型負載對不上（2026-10-08 用戶裁決 1a）。欄位為觸發缺陷的 FlowStep 欄位名（`branch_from`、`return_to`、`next`、`id`、`traverses`）；原始值原樣保存，不正規化
- 破洞報告把 flow 四子類另立「flow」小組，與主圖四子類分開列出；仍屬 `graphDefect` 大類，Diagnostics 的破洞類別列舉與報告頁大類結構不變
- 顯示文字由畫面經 l10n 投影，Diagnostics 不產生在地化字串（與 SPEC-006 FR-08 一致）
- 建圖不可用（FR-01）時不產生本類破洞，報告顯示「無法判定破洞」並說明原因
- 建圖不可用的原因碼由編排層轉成 Diagnostics 既有的無法判定原因，Diagnostics 不依賴 Schema 的原因型別：版本不在已知範圍、缺正向基數、邊型條目不合法、缺 `direction`（`missingDirection`，v1.21）四者都轉成「專案版本不在已知範圍」（依 FR-01，後三者只在版本不在已知範圍時才使建圖不可用）。四者的區分只保留在建圖不可用的日誌事件

**驗收條件**：
- [ ] Given IT-2 的實體化語料，Then 每一筆破洞的子類、欄位內容與凍結的參照實作輸出一致，沒有多出或缺少的破洞
- [ ] Given 建圖不可用，Then 不產生 `graphDefect`，並回報無法判定
- [ ] Given 建圖因缺正向基數而不可用，Then Diagnostics 回報的無法判定原因為「專案版本不在已知範圍」，日誌事件的原因碼仍為缺正向基數

### FR-10：UC flow 子圖 `flowOf(ucId)`（Graph 公開面）

**描述**：給一個 UC 的 ID，回傳該 UC 的 flow 子圖。FlowStep 不進主圖：子圖的步驟不是輕節點，子圖內的連線不進 EVT-GRAPH-001 的邊集合，也不改變使用中邊型（〈用詞〉）。泳道只消費本查詢。依據：`0.5.0-W1-001` 用戶裁決 C 與 (c)（2026-10-07，`docs/tech-decisions.md` 同日補記「FlowStep 以子圖掛在 UC、`next` 不當邊」）。

**輸入**：UC 節點 ID。來源為該 UC `rawNode` 附掛的步驟清單（SPEC-006 FR-09）。

**輸出**：

| 項 | 內容 |
|----|------|
| 主線 | `branch_from` 為空（null、缺席或空字串）的步驟，依清單順序排列（主線判定與框架 `doc validate` 的 `_find_flow_order_problems` 相同） |
| 分支 | `branch_from` 非空的步驟，各帶其 `branch_from` 指向的步驟 |
| 回指 | `return_to` 非空的步驟，各帶其 `return_to` 指向的步驟 |
| 步驟屬性 | 每步帶 `id`、`name`、`next`（原值）、`emits`、`consumes`、`traverses`（原值）與 `traverses` 的解析結果（FR-11） |

**`next` 的語意**（裁決 (c)）：`next` 不是邊型，也不建邊。主線順序取清單順序，不沿主線步驟的 `next` 推導；分支步的 `next` 作為步驟屬性提供（回接主線的位置由 Layout 使用）。主線 `next` 與清單順序的一致性由上游 `doc validate` 檢查（`0.5.0-W1-001.1`），Graph 不重複檢查。

**UC 內參照解析**：`branch_from`、`return_to` 與分支步的 `next` 的值，只在同一 UC 的步驟 id 範圍內解析，不跨 UC、不查主圖。

**規則**：
- 解析不到的參照（指向同一 UC 不存在的步驟 id）：該步驟仍留在子圖內，該參照標為未解析，並回報一筆缺陷（收在 EVT-GRAPH-001 的 `graphDefects`，經 FR-09 成為 `graphDefect`）。步驟留在子圖內是為了讓泳道把懸空參照的步驟放在最後一欄（2026-10-08 用戶裁決，`docs/spec/layout/domain-map.md` §6）
- 同一 UC 內兩個以上步驟的 `id` 相同：重複的步驟**全部保留**在子圖內（主線或分支位置照清單順序與 `branch_from` 判定），回報一筆「UC 內 step id 重複」缺陷；`branch_from`、`return_to`、分支步 `next` 指向該重複 id 的參照一律標為未解析，各回報一筆「flow 參照未解析」缺陷（2026-10-08 用戶裁決 2a）。不同 UC 的 step id 相同不是缺陷（step id 只需 UC 內唯一）
- **與主圖重複 ID 處理的差異**：主圖兩份檔案同一 `id` 時兩個節點都不建（FR-02、〈錯誤處理〉），flow 子圖則兩步都保留。理由：主圖的節點以 ID 全域定位，留下任一個都會讓指向該 ID 的邊連錯；子圖只在單一 UC 內，步驟消失會使泳道缺欄，且延續 2026-10-08 結構異常不消失的裁決（3e）。參照仍標未解析，所以不會連錯
- UC ID 不在圖上、或不是 UC：回傳「不存在」，不拋例外
- UC 的步驟清單為空：回傳空子圖（主線、分支、回指皆為空），與「不存在」分開
- `next` 是步驟 id 的清單（上游 UC 模板：「後續步驟 id；場景結尾留空陣列 []」）：分支步的 `next` 逐元素在 UC 內解析，每個解析不到的元素各報一筆「flow 參照未解析」（欄位 `next`、原始值為該元素）；`[]` 表示無後續、不報缺陷；`next` 為單一純量值時視同單元素清單。不得把整個清單轉成一個字串比對（PM 處置 2026-10-09，`0.5.0-W1-001.4` 實作回報：原條文把 next 寫成純量為規格錯誤，依上游定義與 S1「與上游一致」修正）
- `branch_from`、`return_to` 為單一步驟 id（上游模板定義）；其值為清單或 map 時不逐元素解析，依下一條整體轉字串比對，必然解析不到而報一筆「flow 參照未解析」——壞資料可見（PM 處置 2026-10-09，`0.5.0-W1-001.4` 複審回報，S1 與上游定義的直接推論）
- 步驟 `id` 與參照欄（`next` 的各元素、`branch_from`、`return_to`）的值為非空、非字串（例：`id: 123`、`next: [123]`）時，一律轉成字串後比對，不報缺陷——與上游 `doc validate` 的判定一致（其以 `str()` 正規化），避免上游通過而 App 報缺陷（`0.5.0-W1-001.4` 用戶裁決 S1，2026-10-09）
- 建圖不可用（FR-01）時回傳「圖不可用」，與 FR-08 一致，含與 FR-08 同形的日誌事件（PM 處置 2026-10-09，「一致」的直接推論；事件名 `flowUnavailable`，`0.5.0-W1-001.4` 命名）；建圖完成日誌（`buildCompleted`）負載另帶 `flowDefectCount`（flow 子圖缺陷筆數，`0.5.0-W1-001.4` 實作、PM 追認）
- 缺陷程式識別名：flow 參照未解析為 `GraphDefectKind.flowUnresolvedRef`、UC 內 step id 重複為 `GraphDefectKind.flowDuplicateStepId`，負載 `{ucId, stepId, field, rawValue}`（`0.5.0-W1-001.4` 命名回填）。字串化後相同但原值不同的重複 id（例：`1` 與 `"1"`），重複缺陷的 stepId／rawValue 取清單中第一個出現者（`0.5.0-W1-001.4` 實作選擇，PM 追認）
- 主線 `next` 的值不解析、不產生缺陷（見上方 `next` 的語意）

**驗收條件**：
- [ ] Given 兩語料每份 UC，Then `flowOf` 的主線順序、分支與 `branch_from`、回指與 `return_to`、分支步 `next` 屬性與 flow 區塊逐項一致
- [ ] Given 主線步驟 a 的 `next` 寫成 c、清單順序為 a、b、c，Then 主線順序為 a、b、c，不產生缺陷
- [ ] Given 一個步驟的 `branch_from` 指向同 UC 不存在的 step id，Then 該步驟仍在子圖內、參照標為未解析，並回報一筆缺陷（E2 正向對照）
- [ ] Given 一個分支步的 `next` 或 `return_to` 指向同 UC 不存在的 step id，Then 回報一筆缺陷（E2 正向對照）
- [ ] Given 同一 UC 內兩個步驟 id 相同，Then 兩步都在子圖內，回報一筆「UC 內 step id 重複」缺陷（E2 正向對照）
- [ ] Given 同一 UC 內兩個步驟 id 為 `x`、另一步驟 `return_to: x`，Then 該參照標為未解析，並另回報一筆「flow 參照未解析」缺陷
- [ ] Given 任一 flow 缺陷，Then 破洞負載為 {UC ID, step id, 欄位, 原始值}，且報告列在「flow」小組
- [ ] Given UC-A 與 UC-B 各有一個 id 為 `rescan` 的步驟，Then 不回報缺陷，兩者各自出現在自己的子圖
- [ ] Given 步驟清單為空的 UC，Then 回傳空子圖，不是「不存在」
- [ ] Given 建圖完成，Then EVT-GRAPH-001 的 `edgeCount` 與未啟用本 FR 時相同（子圖不進邊集合）

### FR-11：domain 名稱解析（`traverses`）

**描述**：Graph 以 DomainBundle 的 `domain` 欄建名稱索引，把 FlowStep `traverses` 的每個值解析到 DomainBundle 節點。解析結果作為步驟屬性經 FR-10 提供，供矩陣格（列＝DomainBundle）聚合，不建邊。依據：`0.5.0-W1-001` 用戶裁決 D4（2026-10-07）；domain 名稱權威寫法以 DomainBundle 的 `domain` 為準（2026-10-07 用戶裁決，`0.5.0-W1-090`／`0.5.0-W1-091`）。

**規則**：
- 索引鍵為 DomainBundle 輕節點來源 frontmatter 的 `domain` 值；精確比對（區分大小寫、不去空白、不正規化）
- 不以字串拼接（如 `DOMAIN-MAP-` 加名稱）代替索引查詢：ID 慣例不是 schema 保證
- 解析不到的名稱（未宣告）：回報一筆「`traverses` 名稱未宣告」缺陷（負載見 FR-09），收在 EVT-GRAPH-001 的 `graphDefects`，經 FR-09 成為 `graphDefect`
- 同一步驟的 `traverses` 重複出現同一個未宣告名稱：以（步驟, 值）去重，只回報一筆（`0.5.0-W1-113` PM 處置 N-E）
- `traverses` 為空清單：無解析結果、無缺陷（純畫面步驟，Layout 的「畫面」列）
- 步驟缺 `traverses` 鍵：無解析結果，回報一筆「`traverses` 鍵缺席」缺陷（負載見 FR-09，欄位 `traverses`、原始值 `null`），不視同空清單、不歸「畫面」列（`0.5.0-W1-114` 用戶裁決 T1，2026-10-08）。`traverses` 是 schema 必填欄位，缺鍵是資料缺陷，與純畫面步驟在畫面上須可區分；上游 `doc validate` 不檢查缺鍵，App 端自行回報
- 步驟的 `traverses` 部分值已宣告、部分未宣告：已宣告值照常解析，未宣告值各回報缺陷；解析結果只含已宣告值（泳道放置見 SPEC-001 §1〈泳道布局規則〉「`traverses` 異常的步驟」）
- 值的正規化與上游 `doc validate` 的 `_as_name_list` 一致（比照 FR-10 用戶裁決 S1「與上游一致」，PM 追認 `0.5.0-W1-001.5` 實作選擇，2026-10-09）：`traverses` 為純量字串時視同單元素清單；鍵在而值為 `null` 時視同 `[]`（純畫面步驟，歸「畫面」列，不報缺陷——與「鍵缺席」不同，後者照上一條報缺陷）；元素為非字串時轉字串後比對，空字串與轉字串後無對應宣告者皆為「名稱未宣告」；同一步驟同名已宣告值重複時解析結果只留一筆（未宣告值的去重見上方 N-E）
- 缺陷程式識別名（`0.5.0-W1-001.5` 命名回填）：`FlowDefectKind.traversesUndeclared`／`traversesKeyAbsent`，對應 `GraphDefectKind.flowTraversesUndeclared`／`flowTraversesKeyAbsent`；重複宣告為 `GraphDefectKind.domainDuplicateDeclaration`，負載 `DomainDuplicateDeclarationGraphDefect{domain, bundleIds}`
- **重複 domain 宣告**（`0.5.0-W1-113` 用戶裁決 D-3，2026-10-08）：兩個以上 DomainBundle 宣告相同 `domain` 值時，比照主圖重複 ID（FR-02），這些 DomainBundle 全部不進名稱索引，該名稱的所有 `traverses` 引用回報為未宣告，另回報一筆重複宣告缺陷。DomainBundle 的 `id` 與 `domain` 是兩個欄位，同 `domain` 不同 `id` 時 FR-02 不會觸發，須在名稱索引另行偵測。上游 `doc validate` 另擋下重複 `domain`（`0.5.0-W1-113.1`，框架變更），未升級框架的專案由本規則保護。重複宣告缺陷為 `graphDefect` 子類「domain 重複宣告」，每個重複的 `domain` 值一筆，負載 {domain, 衝突的 DomainBundle ID 清單}（見 FR-09；`0.5.0-W1-114.1` PM 處置 NC-d）。這些 DomainBundle 仍是節點，在矩陣與泳道仍各自成列（列＝DomainBundle 節點）；因被排除於名稱索引，其列沒有任何 `traverses` 命中，並帶缺陷標記
- 解析器的輸入是名稱字串、輸出是 DomainBundle 節點 ID 或未宣告，不綁 FlowStep 型別：`depends_on_domains` 建邊時接同一解析器（`0.6.0-W1-074`），避免兩處各自比對而漂移
- 本版只解析 `traverses`；`depends_on_domains` 不解析、不建邊（D6 排除鍵維持）
- Graph 對外提供 DomainBundle `domain` 的方式以本 FR 的解析器條文為準，與 `0.5.0-W1-001.5`（名稱解析器實作）同批落地，不另行設計查詢（2026-10-08 用戶裁決，`0.5.0-W1-103`）。`bundle_dependency` 的值是 DomainBundle 節點 ID（如 `DOMAIN-MAP-corpus`），走 FR-03 的 ID 解析，不經本解析器

**驗收條件**：
- [ ] Given 兩語料，Then 全部 `traverses` 值解析到 DomainBundle 節點
- [ ] Given `traverses: ["nope"]` 且沒有 DomainBundle 宣告 `domain: nope`，Then 回報一筆缺陷（E2 正向對照）
- [ ] Given `traverses: ["Corpus"]` 而宣告為 `corpus`，Then 回報一筆缺陷（精確比對）
- [ ] Given 一個 DomainBundle 的 ID 不符合 `DOMAIN-MAP-<domain>` 慣例，Then 其 `domain` 名仍可解析
- [ ] Given SPEC 帶 `depends_on_domains`，Then 不建邊，不回報缺陷
- [ ] Given 一個步驟 `traverses: ["nope", "nope"]` 且 `nope` 未宣告，Then 只回報一筆缺陷
- [ ] Given 一個步驟沒有 `traverses` 鍵，Then 回報一筆「`traverses` 鍵缺席」缺陷（E2 正向對照：不得當 `[]` 而無缺陷）；`traverses: []` 的步驟不回報（對照）
- [ ] Given 一個步驟 `traverses: ["graph", "nope"]`、`graph` 已宣告，Then 解析結果只含 `graph` 的 DomainBundle，並回報一筆 `nope` 未宣告缺陷
- [ ] Given 兩個 DomainBundle 的 `id` 不同、`domain` 皆為 `corpus`，Then `traverses: ["corpus"]` 回報為未宣告，並回報一筆負載為 {`corpus`, 兩個 DomainBundle ID} 的「domain 重複宣告」缺陷（E2 正向對照：不得取其一解析成功）；兩個 DomainBundle 仍各自出現在矩陣列集合中
- [ ] Given 一個步驟沒有 `traverses` 鍵，Then 「`traverses` 鍵缺席」缺陷負載的欄位為 `traverses`、原始值為 `null`

### FR-12：domain × UC 關係與依賴路徑（Graph 公開面）

**描述**：給一個 DomainBundle 與一個 UC，回傳兩者的關係種類（直接貫穿／間接依賴／無關）與依賴路徑。延伸 Graph 公開面既有的貫穿數（`docs/spec/graph/domain-map.md` §3），畫面（矩陣格、格詳情卡）只顯示回傳值，不自行計算。依據：`0.5.0-W1-114` 用戶裁決 O1（2026-10-08）。

**規則**：
- 判定式與依賴路徑集合的權威條文為 SPEC-001 §1〈間接依賴判定式〉與〈間接依賴格的詳情卡：依賴路徑〉，本 FR 不重述：直接貫穿以 FR-11 的解析結果判定（`traverses` 包含 Y）；間接依賴沿 `bundle_dependency` 邊往下游可達，跳數不限；依賴路徑取每個來源的最短路徑、同長全列、排除經直接 domain 的路徑；排序依下一條
- 回傳值：關係種類三值之一；間接依賴時另帶依賴路徑清單（每條為 DomainBundle 序列），直接貫穿與無關時路徑為空
- 依賴路徑排序：先依路徑長度遞增，同長依來源 X 在 FR-13 分層排序中的先後，再依中間節點在 FR-13 中的先後。排序依據取自 FR-13，不依賴 Layout（`0.5.0-W1-114.2` 用戶裁決 R1，2026-10-08；系統層 §2 禁止 Graph 依賴 Layout）
- 只計 FR-11 解析成功的值：未宣告名稱、缺 `traverses` 鍵、重複宣告被排除的名稱不構成直接貫穿
- DomainBundle 或 UC 的 ID 不在圖上時，比照 FR-08 回傳「無關」且路徑為空，不拋例外（`0.5.0-W1-114.2` PM 處置 NC-5）
- 建圖不可用（FR-01）時回傳「圖不可用」，與 FR-08 一致
- 介面識別名與簽章交 Step 6 的 Graph 間接依賴實作票定（`0.5.0-W1-114.1` PM 處置 NC-c）；該實作的預期值取凍結快照（PM 接受的推論）

**驗收條件**：
- [ ] Given 本專案語料的凍結快照（預期值取凍結快照，`0.5.0-W1-114` PM 處置 N1），Then 全部格的關係種類與快照一致（本版資料下為 SPEC-001 §1〈本專案期望分布〉：直接貫穿 19、間接依賴 10、無關 19）
- [ ] Given UC-04 × `schema`，Then 回傳間接依賴與兩條路徑 `graph → corpus → schema`、`ticketdetail → corpus → schema`（依此順序）
- [ ] Given UC-06 × `schema`，Then 回傳一條路徑 `corpus → schema`，不含經直接 domain 的 `diagnostics → corpus → schema`（E2 正向對照）
- [ ] Given 直接貫穿格，Then 依賴路徑為空

### FR-13：DomainBundle 分層與層內排序（Graph 公開面）

**描述**：回傳全部 DomainBundle 的分層與排序。Layout 的泳道列序（SPEC-001 §1〈泳道布局規則〉）與 FR-12 的依賴路徑排序共用這一份，Layout 向 Graph 取列序、不自行推導。依據：`0.5.0-W1-114.2` 用戶裁決 R1（2026-10-08，`docs/tech-decisions.md` 同日補記「列序規則歸 Graph」）。

**規則**：
- 分層（1a）：層由 `bundle_dependency` 邊推導。無出邊者為 L0，其餘為其所依賴 bundle 的最大層 + 1
- 層內排序（2b）：同層依 `DomainBundle.domain` 字面的 Unicode code point 逐字元遞增排序，不依 locale 排序規則
- 排序結果依層遞增（L0 在前），同層依上一條
- 推不出層的 bundle（依賴循環，或依賴指向未宣告的 bundle）不消失：依 `DomainBundle.domain` code point 序接在最後（沿用 `0.5.0-W1-092.2` 用戶裁決 3e 的既有條文，原寫於 SPEC-001 列序判定式）
- 依賴推不出層者的 bundle 同樣推不出層、接在最後：任一所依賴 bundle 無層時，「所依賴 bundle 的最大層」不存在，該 bundle 不得以其餘依賴的最大層 + 1 計層（`0.5.0-W1-114.4` PM 處置 NC-8，為分層 1a 的直接後果）
- 回傳形狀：排序後的 bundle 清單，每項附層號；推不出層者層號為 null（`0.5.0-W1-114.4` PM 處置 NC-9）
- 規則不寫死 domain 名，與 UC 無關
- 建圖不可用（FR-01）時回傳「圖不可用」，與 FR-08 一致
- 介面識別名與簽章交實作票定（比照 FR-12）；回傳形狀依上方「回傳形狀」條

**驗收條件**：
- [ ] Given 本專案語料的凍結快照，Then 排序結果為 `schema`、`workspace`、`corpus`、`history`、`diagnostics`、`graph`、`ticketdetail`、`layout`（L0 `schema`、`workspace`；L1 `corpus`、`history`；L2 `diagnostics`、`graph`、`ticketdetail`；L3 `layout`，與 SPEC-001 §1 列序期望值一致）
- [ ] Given 兩個 bundle 互相依賴，Then 兩者接在全部可分層 bundle 之後，依 code point 序
- [ ] Given bundle `c` 依賴 L0 的 `a` 與互相依賴的 `x`，Then `c` 推不出層、層號為 null，與 `x` 一起接在全部可分層 bundle 之後依 code point 序（不得算為 L1）；可分層者回傳各自層號（NC-8／NC-9）
- [ ] Given FR-12 回傳 UC-04 × `schema` 的兩條同長路徑，Then 其先後與兩條路徑來源在本 FR 排序中的先後一致

## 非功能需求

### NFR-01：缺陷隔離

任一缺陷都不得中止建圖，也不得改變其他引用值的分類與其他邊。
**驗收**：在正常語料中，為 FR-03 的每個原因碼、`duplicateId`、`multiSource` 各插入一筆，其餘邊集合與未插入時逐項相同。

### NFR-02：計算量

建圖的計算量與引用值總數呈線性（以 ID 索引解析，不做兩兩比對）。主套件不以計時斷言驗證（`test-assertion-design-rules` D1），如需量測放 `test/performance/`。

## 錯誤處理

| 錯誤情境 | 處理方式 | 對應 |
|---------|---------|------|
| 引用值形狀不合法或不符合任何 ID 格式 | 不建邊，不救回，`malformedRef` | FR-03 |
| 引用值指向自己 | 不建邊，`malformedRef`（`selfReference`） | FR-03 |
| 引用值指向不存在或重複的 ID | 不建邊，`danglingRef` | FR-03 |
| 兩份檔案同一 `id` | 兩者都不建節點，`duplicateId` | FR-02 |
| 正向基數為 `one` 的邊型經聯集得到多個終點 | 全部建邊，`multiSource` | FR-04 |
| 型別表缺 `edge_types` 或正向基數，且版本不在已知範圍 | 建圖不可用，回報原因碼，不產生 `graphDefect` | FR-01、FR-09 |

## 設計約束

| # | 約束 | 來源 |
|---|------|------|
| D1 | 有反向欄位的邊取兩側聯集並記錄宣告來源；單側宣告不是缺陷 | 用戶裁決 2026-09-30（WRAP）；tech-decisions 同日補記 |
| D2 | 本版建圖的邊型為使用中邊型（〈用詞〉）；proposed 層的 `bundle_dependency` 進主圖，走與其他邊型相同的目標解析（FR-03）與破洞判定（FR-09），鄰接查詢標示其 `layer`（FR-08） | 用戶裁決 2026-09-30；2026-10-08（`0.5.0-W1-103` P1） |
| D3 | 引用值分類為解析成功、斷邊、格式錯誤三類，不部分救回 | 用戶裁決 2026-09-30 |
| D4 | 主圖缺陷子類為 FR-09 所列四種，flow 子圖另四種（2026-10-08 用戶裁決 1a；第四種依 `0.5.0-W1-114` T1）；其中 `duplicateId` 與自我引用的處理為規格預設，用戶 2026-09-30 整批確認；孤島與缺必要邊延至 0.6 | 用戶裁決 2026-09-30 |
| D5 | 整合測試使用凍結測資，預期值由獨立參照實作產生並凍結 | 用戶裁決 2026-09-30；同 SPEC-006 D3 |
| D6 | 邊型的欄位名、正向基數、是否有反向欄位、方向性（`direction`）、層級取自型別表；程式內的鍵名例外只有兩處：排除 `domain_dependency`、納入 `proposed` 層的 `bundle_dependency`。`domain_dependency` 排除鍵在 0.5.0 維持（`0.5.0-W1-001` 裁決 D4，2026-10-07），建邊與移除排除鍵由 `0.6.0-W1-074` 承接。`bundle_dependency` 例外的理由：矩陣間接格與泳道分層需要「沿邊可達」，現成管線已含目標解析與破洞判定；上游升級判準要求兩個獨立專案皆有實例，目前只有本專案，不能升為 established，故以本地允許清單納入。原「以 `association` 認定無向邊」例外已移除，改讀 `direction`（FR-05） | 同 SPEC-006 D1：上游 schema 為唯一權威。`association` 例外移除依 2026-09-30 用戶裁決（上游 `0.4.0-W1-072` 已補 `direction`）；`bundle_dependency` 例外依 2026-10-08 用戶裁決（`0.5.0-W1-103` P1，WRAP） |
| D7 | 正向基數由 schema 宣告；`provenance` 為 `many`（一個節點可有多個來源提案），`spawn`、`blood` 為 `one` | 用戶裁決 2026-09-30（WRAP）；tech-decisions 同日補記 |
| D8 | FlowStep 不進主圖，Graph 以 `flowOf(ucId)` 提供單一 UC 的 flow 子圖；`next` 不當邊，主線順序取 flow 清單順序，分支步 `next` 為步驟屬性；子圖內參照只在同 UC 範圍解析 | 用戶裁決 2026-10-07（`0.5.0-W1-001` C、(c)，WRAP） |
| D9 | domain 名稱解析器以 DomainBundle 的 `domain` 欄精確比對，本版只服務 `traverses`，不建邊；解析器不綁 FlowStep 型別 | 用戶裁決 2026-10-07（`0.5.0-W1-001` D4，WRAP） |

**D5 的展開**：

- **manifest 來源**：兩個語料專案（本專案、flutter_balance）的節點，只凍結建圖需要的欄位：`id`、型別、相對路徑、`status`、`title`、全部使用中邊型的正向與反向欄位原值。IT-3 另凍結 ticket 的完整 frontmatter 樣本，每種 `status` 值至少一張。
- **實體化**：測試執行時依 manifest 在暫存目錄寫出最小 frontmatter 檔案樹，經 Corpus 掃描後建圖，不直接把 manifest 餵給 Graph；否則 Corpus→Graph 的交界會被繞過。
- **預期值來源**：獨立的 Python 參照實作依本規格產生邊集合、缺陷清單與引用值總數，凍結時離線執行，CI 不執行它。
- **樣本覆蓋**：manifest 至少各含一筆單側 `relatedTo`、兩側 `relatedTo`、只在反向的 `spawn`、`spawn` 多來源衝突、多來源 `provenance`、斷邊、格式錯誤。語料中沒有的類型（重複 ID、自我引用、非法形狀）用合成列補上並標記為合成。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.26 | 2026-10-09 | FR-11：traverses 值正規化與上游 `_as_name_list` 一致（純量、null、非字串元素、同名去重；PM 追認 `0.5.0-W1-001.5` 實作選擇）；回填 traverses 兩子類與 domain 重複宣告的識別名 |
| 1.25 | 2026-10-09 | FR-10：`branch_from`／`return_to` 為清單或 map 時整體轉字串、報未解析（PM 處置）；回填 `buildCompleted` 日誌的 `flowDefectCount`（`0.5.0-W1-001.4` 複審回報） |
| 1.24 | 2026-10-09 | FR-10：`next` 為步驟 id 清單、逐元素解析、`[]` 不報缺陷（PM 處置，修正原條文把 next 寫成純量的錯誤）；追認 `flowUnavailable` 日誌事件名與重複 id 取第一個原值 |
| 1.23 | 2026-10-09 | FR-10：非字串 id／參照值轉字串比對（`0.5.0-W1-001.4` 用戶裁決 S1）；圖不可用含日誌事件（PM 處置）；回填兩個 flow 缺陷識別名與負載 |
| 1.22 | 2026-10-09 | FR-09 原因碼轉換由三者改為四者，納入 `missingDirection`（`0.5.0-W1-001.7` 回報，文字同步） |
| 1.21 | 2026-10-09 | `0.5.0-W1-001.7` 審查回報：FR-01「單一邊型條目不合法」列舉加入 `direction` 存在但不合法（用戶裁決 Q1）；版本不在已知範圍且缺 `direction` 於繞過關卡路徑回報建圖不可用（PM 處置 D2）；補兩條驗收 |
| 1.20 | 2026-10-08 | 補寫 `0.5.0-W1-114.2` PM 處置（Step 6 建票前發現未落規格）：FR-06 驗收 #3 `graphDefects` 筆數含「domain 重複宣告」（NC-4）；FR-12 ID 不在圖上時回傳「無關」且路徑為空（NC-5）；FR-09 第四 flow 子類與 domain 重複宣告的識別名皆由 `0.5.0-W1-001.5` 命名（NC-7） |
| 1.19 | 2026-10-08 | `0.5.0-W1-114.5`（依 `0.5.0-W1-114.4` PM 處置 NC-8／NC-9）：FR-13 寫明依賴推不出層者的 bundle 同樣推不出層、接在最後；回傳形狀定為排序清單＋每項層號（推不出層者為 null）；補一條驗收 |
| 1.18 | 2026-10-08 | `0.5.0-W1-114.3`（依 `0.5.0-W1-114.2` 用戶裁決 R1，第二批）：新增 FR-13 DomainBundle 分層（1a max+1）與層內排序（2b code point）的 Graph 公開查詢，推不出層者沿 3e 接在最後；FR-12 依賴路徑排序改依 FR-13，不依賴 Layout；〈概述〉職責表同步。介面識別名交實作票 |
| 1.17 | 2026-10-08 | `0.5.0-W1-114.1` 第二小輪（PM 處置 NC-b／NC-c／NC-d）：FR-09「`traverses` 鍵缺席」負載原始值定為 `null`；新增 `graphDefect` 子類「domain 重複宣告」，負載 {domain, 衝突的 DomainBundle ID 清單}；第四 flow 子類、domain 重複宣告與 FR-12 的識別名改為交實作票定；FR-11 重複 domain 宣告寫明兩個 DomainBundle 仍各自成列、其列無 `traverses` 命中並帶缺陷標記，缺鍵規則補負載；補一條驗收、擴寫一條驗收。移除本票三處未裁決標記 |
| 1.16 | 2026-10-08 | `0.5.0-W1-114.1`（依 `0.5.0-W1-114` 用戶裁決 T1／O1 與 PM 補定、`0.5.0-W1-113` 用戶裁決 D-3 與 PM 處置 N-A／N-B／N-E）：FR-01 內建表也沒有的邊型回報來源值為「預設（有向）」；FR-06 負載與驗收 #3 的 `graphDefects` 筆數改含 flow 子類並補一條正向對照；FR-09 新增第四個 flow 子類「`traverses` 鍵缺席」，未宣告名稱子類註明去重與重複宣告；FR-11 新增（步驟, 值）去重、缺鍵回報、部分已宣告、重複 domain 宣告（兩者皆排除於名稱索引並報重複）四條規則與驗收；新增 FR-12 domain × UC 關係與依賴路徑（Graph 公開面，判定式引 SPEC-001 §1）；〈本版範圍外〉貫穿數列與〈概述〉職責表同步；D4 改為 flow 四子類。未裁決項（缺鍵原始值表示、第四子類與 FR-12 識別名、重複宣告缺陷子類與矩陣列）見該票 NeedsContext |
| 1.15 | 2026-10-08 | `0.5.0-W1-103.1` PM 處置：FR-01 缺 `direction` 規則補一句——版本不在已知範圍時由 SPEC-001 §1「schema 不相容」關卡涵蓋、內建表本身帶 `direction`，取代原指向 NeedsContext 的句子 |
| 1.14 | 2026-10-08 | `0.5.0-W1-103.1` 用戶裁決第二輪 H1：FR-01 寫明專案型別表缺 `direction` 欄時，版本在已知範圍內依鍵名從內建表補並回報來源、內建表也沒有的邊型照 `directed` 處理（沿用 SPEC-006 D8）；補兩條驗收。版本不在已知範圍時的處置未裁決，見該票 NeedsContext |
| 1.13 | 2026-10-08 | `0.5.0-W1-103.1`（依 `0.5.0-W1-103` 用戶裁決 P1＋proposed 標示，及 2026-09-30 無向欄位裁決）：〈用詞〉使用中邊型加入 `bundle_dependency`、新增「無向邊」詞條；FR-01 邊型帶 `direction`，鍵名例外改為排除 `domain_dependency`、納入 `bundle_dependency`；FR-04、FR-05 改由 `direction` 欄判無向，移除 `association` 鍵名例外與「匯出的 JSON 沒有這項資訊」過時敘述（上游 `0.4.0-W1-072` 已補欄位）；FR-08 回傳項帶 `layer`，proposed 邊須由消費端標示；FR-11 補 DomainBundle `domain` 對外提供方式沿用解析器條文；D2、D6 同步並寫明 `bundle_dependency` 例外理由。專案型別表缺 `direction` 時的處置未裁決，見該票 NeedsContext |
| 1.12 | 2026-10-08 | 落地 `0.5.0-W1-001.2` NeedsContext 用戶裁決（`0.5.0-W1-001.8`）：FR-09 新增 flow 三子類（flow 參照未解析、UC 內 step id 重複、`traverses` 名稱未宣告），負載 {UC ID, step id, 欄位, 原始值}，破洞報告另立 flow 小組（1a）；FR-10 重複 step id 兩步保留、指向它的參照標未解析並報缺陷，寫明與主圖重複 ID（FR-02）處理不同的理由（2a）；D4 同步。三子類的程式識別名未裁決，見 `0.5.0-W1-001.8` NeedsContext |
| 1.11 | 2026-10-08 | 新增 FR-10 UC flow 子圖 `flowOf(ucId)` 與 FR-11 `traverses` 名稱解析（`0.5.0-W1-001.2`，依 `0.5.0-W1-001` 用戶裁決 C／(c)／D4，2026-10-07）：FlowStep 不進主圖、`next` 不當邊、子圖內參照 UC 範圍解析、未解析參照與 UC 內重複 step id 成缺陷；名稱解析以 `domain` 欄精確比對、未宣告名稱成缺陷、不建邊。新增 D8、D9；D6 寫明 `domain_dependency` 排除維持並改由 `0.6.0-W1-074` 承接；〈本版範圍外〉兩列與 FR-09 子類同步，新缺陷子類識別名待裁決 |
| 1.10 | 2026-09-30 | FR-01 補邊界（`0.4.0-W4-016` 審閱時提出）：被拒收的邊型在內建表也不存在時，不建邊、只寫日誌、建圖仍可用。v1.7 要避免的是靜默丟棄內建表認得的邊型，此情況兩表皆無可讀定義，判建圖不可用會因一個過時邊型癱瘓整張圖。現行實作即此行為 |
| 1.9 | 2026-09-30 | FR-01 補原因碼優先序（`0.4.0-W4-016` 提出）：不合法條目與缺正向基數並存且版本不在已知範圍時，只回報「邊型條目不合法」 |
| 1.8 | 2026-09-30 | FR-01 被拒收邊型在版本不在已知範圍時的原因碼定為獨立的「邊型條目不合法」（`0.4.0-W4-016` 提出）：沿用缺正向基數會在 `class` 等欄位出錯時誤導日誌，沿用版本不在範圍會丟失原因；FR-09 轉換改列三者，Diagnostics 端不變 |
| 1.7 | 2026-09-30 | FR-01 補單一邊型條目不合法的處置（`0.4.0-W4-004` 提出）：整筆拒收並寫日誌，視同該邊型缺席，依缺欄位規則從內建表補或判建圖不可用；不得中斷 Corpus 的 `node_types` 解碼。依 FR-01 既有「缺欄位→內建補／不可用」原則推導，避免邊型被靜默丟棄 |
| 1.6 | 2026-09-30 | D6 補列第二個鍵名例外：以 `association` 認定無向邊（`0.4.0-W2-004` 提出，用戶經 WRAP 裁決）。FR-01、FR-05 同步；FR-05 寫明不能依 `class` 判定的理由，並由契約測試 S6-13 釘住前提；上游補欄位後由 `0.5.0-W1-001` 移除 |
| 1.5 | 2026-09-30 | FR-09 寫明建圖不可用原因的轉換（`0.4.0-W2-007` 提出）：由編排層轉成 Diagnostics 既有的「專案版本不在已知範圍」，Diagnostics 不 import Schema、不擴充原因列舉與 l10n；兩種原因的區分保留在日誌。依 FR-01「與 SPEC-006 FR-08 同一套原因」推導 |
| 1.4 | 2026-09-30 | FR-03 與〈用詞〉的 map 展開規則改為依值的形狀判定：任何值為 map 的反向欄位都展開子鍵，不再以 `outputs` 點名，對齊 D6「欄位名不寫死」；正向欄位的值為 map 仍歸格式錯誤。`0.4.0-W2-003` 與參照實作已是此行為，兩語料只有 `outputs` 是 map，IT 不受影響 |
| 1.3 | 2026-09-30 | FR-01 補專案型別表整份缺席的情境（`0.4.0-W2-002` 實作時提出）：建圖不可用，與 SPEC-001 §1「無可消費的型別表」同一顯式關卡；降級模式由呼叫端以內建表作為專案型別表傳入，建圖可用。依 2026-09-03 既有決策推導，非新裁決；補兩條驗收條件。FR-06 計數項補無向邊的宣告來源形態（一端／兩端，與有向邊分開計數；`0.4.0-W2-008` 參照實作時提出），依〈用詞〉宣告來源的無向邊定義推導 |
| 1.2 | 2026-09-30 | 依 `/spec validate`（規劃波 Step 3）的五個未回答問題補齊，全部採用預設答案（用戶確認）：空語料建空圖並發事件；引用值原樣比對不去空白；圖不可用時鄰接查詢回傳「圖不可用」而非空清單；`outputs` 子鍵不列舉，所有子鍵的清單項皆為反向引用值；寫明 EVT-GRAPH-001 不佔使用者呈現通道 |
| 1.1 | 2026-09-30 | 依技術與文字兩份審查修正，並納入用戶裁決「來源邊多值、基數由 schema 宣告」（D7）：新增〈用詞〉；FR-01 解碼正向基數、改以集合描述邊型數；FR-03 分類改為有序判定，自我引用、重複 ID、非法形狀與清單內 null 的計數單位寫定；FR-04 改為「邊的方向與建邊來源」總表，單值判準改讀正向基數，`multiSource` 只計解析成功的終點；宣告來源統一為端點集合；IT-1 比對鍵含宣告來源；IT-2 引用值總數由參照實作獨立凍結；負載欄位 `refDefects` 更名 `graphDefects`；補齊各 FR 缺漏的驗收條件 |
| 1.0 | 2026-09-30 | 初版：0.4.0 規劃波 Step 2，依 PROP-005 §0.4 與設計約束表所列用戶裁決建立。兩語料實測：本專案 1179 節點、flutter_balance 1690 節點；引用值中斷邊 3／0、格式錯誤 1／4、只在反向的 `spawn` 38／52；重複 ID 與自我引用皆 0 |
