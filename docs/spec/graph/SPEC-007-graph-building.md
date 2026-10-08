---
id: SPEC-007
title: "建圖：輕節點、邊的聯集與圖結構破洞"
status: draft
source_proposal: PROP-005
created: "2026-09-30"
updated: "2026-10-08"
version: "1.11"
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
| **Graph** | 建輕節點；抽取引用值並分類；建邊；鄰接查詢；UC flow 子圖；domain 名稱解析 | FR-02～FR-06、FR-08、FR-10、FR-11 |
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
| 使用中邊型 | 型別表中 `layer` 為 `established` 的邊型，扣除 `domain_dependency`（FR-01） |
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
| 貫穿數、路徑→domain 查詢 | 依賴 FlowStep `traverses` 與路徑對照表，屬 0.5。`traverses` 的名稱解析已由 FR-11 定義；聚合為貫穿數與路徑→domain 查詢不在本規格 | PROP-005 §0.5 |
| 語料變動後的增量重建（EVT-CORPUS-002） | 本版只做單輪完整建圖；重掃屬畫面接真資料的互動 | PROP-005 §0.6 |
| 引用值的部分救回（例：從 `0.2.1-W3-1057 驗收` 抽出 ID） | 與 SPEC-006「不部分救回」一致；救回規則會猜錯（兩個 ID 寫在同一字串） | 本版只回報（FR-03） |

## 功能需求

### FR-01：邊型表（Schema 公開面）

**描述**：Schema 從型別表 JSON 的 `edge_types` 解碼邊型，供 Graph 查詢。與節點型別同一份來源、同一套版本判定（SPEC-006 FR-06 規則 7）。

**規則**：
- 每個邊型帶：鍵名（如 `association`、`spawn`）、`class`、`forward_field`、`reverse_field`（可為 null）、正向基數（`one`／`many`）、`layer`
- 使用中邊型見〈用詞〉。欄位名、基數、是否有反向欄位一律取自型別表，不在程式內寫死。本版以鍵名寫死的只有兩處（設計約束 D6）：排除 `domain_dependency`，以及把 `association` 認定為無向邊（FR-05）
- 專案型別表缺 `edge_types`，或其中缺正向基數欄位：版本在 App 已知範圍內則從內建表補；否則建圖不可用，回報原因碼（與 SPEC-006 FR-08 同一套「無法判定」原因）
- 單一邊型條目不合法（值不是 map；`class`、`forward_field`、`layer` 缺席或不是字串；`reverse_field` 存在但不是字串，null 合法）：該條目整筆拒收並寫日誌，視同該邊型缺席，依缺欄位的規則處置——版本在 App 已知範圍內時該邊型取內建表的定義；否則建圖不可用，原因碼為「邊型條目不合法」（與缺 `edge_types`、缺正向基數各自獨立的第三個值，日誌據此區分）。同一張表同時有不合法條目與缺正向基數的條目時，只回報「邊型條目不合法」：不合法條目在解碼階段就被拒收，先於基數補值判定。版本在已知範圍內、但內建表也沒有該鍵名時（上游已刪除該邊型，舊專案表仍留著且條目不合法），該邊型不建邊，只寫拒收日誌，建圖仍可用：兩張表都沒有可讀的定義，而內建表是已知範圍內的權威，不認得的邊型不屬於 App 所知的圖。`edge_types` 本身不是 map 時視同缺 `edge_types`。邊型條目的問題只影響 Graph，不得中斷 Corpus 對同一型別表 `node_types` 的解碼
- 專案型別表整份缺席（`tracking_schema.json` 不存在）：建圖不可用，回報版本不在已知範圍的原因碼。這是 SPEC-001 §1「無可消費的型別表」的顯式關卡，Graph 不自動降級；使用者選「以 App 內建型別表檢視」後，呼叫端以內建表作為專案型別表傳入，建圖可用，使用中邊型取自內建表（`docs/tech-decisions.md` 2026-09-03「型別表缺席時降級而非拒絕」）。呼叫端的接線屬 PROP-005 §0.6 畫面接真資料

**驗收條件**：
- [ ] Given 內建型別表，Then 解碼出的邊型集合與內建表 `edge_types` 的鍵集合相同，使用中邊型等於 established 邊型扣除 `domain_dependency`
- [ ] Given 測試用型別表新增一個 established 邊型，Then 該邊型自動成為使用中邊型，Graph 依其欄位抽取
- [ ] Given 測試用型別表把某使用中邊型的 `forward_field` 改名，Then Graph 依新欄位名抽取，不讀舊欄位名
- [ ] Given 專案型別表缺 `edge_types` 且版本在已知範圍內，Then 解碼出的邊型集合與內建表相同，建圖可用
- [ ] Given 專案型別表缺 `edge_types` 且版本高於內建版本，Then 建圖不可用，回報原因碼，不產生 `graphDefect`
- [ ] Given 專案型別表整份缺席，Then 建圖不可用，回報版本不在已知範圍的原因碼
- [ ] Given 專案型別表某邊型的值是字串、版本在已知範圍內，Then 不拋例外，該邊型取內建表定義，建圖可用，`node_types` 解碼結果與該條目正常時相同
- [ ] Given 同上但版本高於內建版本，Then 建圖不可用，Corpus 掃描照常完成
- [ ] Given 降級模式（內建表作為專案型別表傳入），Then 建圖可用，使用中邊型等於內建表 established 邊型扣除 `domain_dependency`

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
| `association`（`relatedTo`） | 無向邊，見 FR-05 | 列出對方的一端或兩端 |
| 其餘（`reverse_field` 為 null） | 起點的正向欄位列出終點 | 起點 |

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

### FR-05：`relatedTo` 的 1-hop 對稱聯集

**描述**：`association` 邊（`relatedTo`）語意無向、儲存單向，建圖時做 1-hop 對稱聯集。

**無向的判定**：以鍵名 `association` 認定（D6 的第二個鍵名例外）。上游型別表沒有表達無向的欄位：`association` 與 `blocking` 都沒有反向欄位、基數都是 many，只差 `class`；而 `class` 為 `see-also` 的另有三種邊型，上游沒有把它們註明為無向，所以也不能依 `class` 判定。無向語意只寫在上游 `tracking_schema.py` 的程式註解，匯出的 JSON 沒有這項資訊。契約測試 S6-13 釘住這個例外的前提，上游一變動就翻紅；上游補上機器可讀的無向欄位後，由 `0.5.0-W1-001` 改為讀取欄位並移除本例外。

**規則**：A 的 `relatedTo` 列出 B，或 B 的 `relatedTo` 列出 A，都建同一條無向邊 {A, B}；宣告來源為列出對方的端點集合。

**驗收條件**：
- [ ] Given A 列出 B、B 未列出 A，Then 邊 {A, B} 存在，宣告來源為 {A}，且對 B 做鄰接查詢會得到 A
- [ ] Given A、B 互相列出，Then 只有一條邊，宣告來源為 {A, B}

### FR-06：建圖結果與事件

**描述**：一輪建圖完成時，Graph 產出 EVT-GRAPH-001，並提供可驗證的計數。

**計數項**：節點數、`duplicateId` 數、各邊型的邊數、各宣告來源形態的邊數（有向邊分僅起點、僅終點、兩端；無向邊沒有起點與終點之分，分一端、兩端，與有向邊分開計數）、FR-03 三類計數、`multiSource` 數。

**規則**：`rawNodes` 為空時照常建出空圖、發出 EVT-GRAPH-001，所有計數為 0，不視為錯誤（與 SPEC-006 FR-02「沒有 `docs/` 時掃描 0 檔」一致）。

**負載**：`nodeCount`、`edgeCount`、`graphDefects`（`danglingRef`、`malformedRef`、`duplicateId`、`multiSource`，逐筆）。EVT-GRAPH-001 的負載說明已於本規格定案時同步改寫（`docs/events/graph/EVT-GRAPH-001-graph-built.md`）。

**驗收條件**：
- [ ] Given 一份分布已知的 fixture，Then 各計數項等於已知值，FR-03 守恆式成立
- [ ] Given `rawNodes` 為空，Then 發出一筆 EVT-GRAPH-001，`nodeCount`、`edgeCount` 為 0，`graphDefects` 為空
- [ ] Given 建圖完成，Then 發出一筆 EVT-GRAPH-001，`graphDefects` 筆數等於斷邊數＋格式錯誤數＋`duplicateId` 數＋`multiSource` 數

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

**輸出**：清單，每項帶邊型、另一端的節點 ID、方向（出、入、無向）、宣告來源。無向邊在任何方向篩選下都會回傳，方向標為無向。

**規則**：
- 節點 ID 不在圖上時回傳空清單，不拋例外
- 建圖不可用（FR-01）或尚未完成時，回傳「圖不可用」狀態而非空清單。空清單表示「查過且沒有相鄰節點」，兩者分開，畫面才不會把不可用顯示成「沒有關聯」

**驗收條件**：
- [ ] Given 一張子票以 `source_ticket` 指向父票，Then 查子票（方向：出）得到父票，查父票（方向：入）得到子票
- [ ] Given 邊型篩選只含 `blocking`，Then 回傳不含其他邊型
- [ ] Given 不存在的 ID，Then 回傳空清單
- [ ] Given 建圖不可用，Then 任何查詢都回傳「圖不可用」，不回傳空清單

### FR-09：圖結構破洞（Diagnostics）

**描述**：Diagnostics 收到 EVT-GRAPH-001 後，對 `graphDefects` 逐筆產生 EVT-DIAGNOSTICS-001 的 `graphDefect` 破洞。

**子類**：`danglingRef`、`malformedRef`、`duplicateId`、`multiSource`（原因碼見 FR-02～FR-04）。FR-10、FR-11 新增三種缺陷（flow 參照未解析、UC 內 step id 重複、`traverses` 名稱未宣告），子類識別名、負載欄位與破洞報告的分組尚未裁決（`0.5.0-W1-001.2` NeedsContext），在裁決前不得自行命名。

**規則**：
- 一筆缺陷對應一筆破洞。`danglingRef`、`malformedRef` 帶來源節點 ID 與路徑、欄位名、原始值（原樣，不正規化）、邊型、原因碼；`duplicateId` 帶 ID 與全部路徑；`multiSource` 帶起點、邊型、全部終點與各自的宣告來源
- 顯示文字由畫面經 l10n 投影，Diagnostics 不產生在地化字串（與 SPEC-006 FR-08 一致）
- 建圖不可用（FR-01）時不產生本類破洞，報告顯示「無法判定破洞」並說明原因
- 建圖不可用的原因碼由編排層轉成 Diagnostics 既有的無法判定原因，Diagnostics 不依賴 Schema 的原因型別：版本不在已知範圍、缺正向基數、邊型條目不合法三者都轉成「專案版本不在已知範圍」（依 FR-01，後兩者只在版本不在已知範圍時才使建圖不可用）。三者的區分只保留在建圖不可用的日誌事件

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
- 同一 UC 內兩個以上步驟的 `id` 相同：回報一筆缺陷（帶 UC ID 與該 step id）。不同 UC 的 step id 相同不是缺陷（step id 只需 UC 內唯一）
- UC ID 不在圖上、或不是 UC：回傳「不存在」，不拋例外
- UC 的步驟清單為空：回傳空子圖（主線、分支、回指皆為空），與「不存在」分開
- 建圖不可用（FR-01）時回傳「圖不可用」，與 FR-08 一致
- 主線 `next` 的值不解析、不產生缺陷（見上方 `next` 的語意）

**驗收條件**：
- [ ] Given 兩語料每份 UC，Then `flowOf` 的主線順序、分支與 `branch_from`、回指與 `return_to`、分支步 `next` 屬性與 flow 區塊逐項一致
- [ ] Given 主線步驟 a 的 `next` 寫成 c、清單順序為 a、b、c，Then 主線順序為 a、b、c，不產生缺陷
- [ ] Given 一個步驟的 `branch_from` 指向同 UC 不存在的 step id，Then 該步驟仍在子圖內、參照標為未解析，並回報一筆缺陷（E2 正向對照）
- [ ] Given 一個分支步的 `next` 或 `return_to` 指向同 UC 不存在的 step id，Then 回報一筆缺陷（E2 正向對照）
- [ ] Given 同一 UC 內兩個步驟 id 相同，Then 回報一筆缺陷（E2 正向對照）
- [ ] Given UC-A 與 UC-B 各有一個 id 為 `rescan` 的步驟，Then 不回報缺陷，兩者各自出現在自己的子圖
- [ ] Given 步驟清單為空的 UC，Then 回傳空子圖，不是「不存在」
- [ ] Given 建圖完成，Then EVT-GRAPH-001 的 `edgeCount` 與未啟用本 FR 時相同（子圖不進邊集合）

### FR-11：domain 名稱解析（`traverses`）

**描述**：Graph 以 DomainBundle 的 `domain` 欄建名稱索引，把 FlowStep `traverses` 的每個值解析到 DomainBundle 節點。解析結果作為步驟屬性經 FR-10 提供，供矩陣格（列＝DomainBundle）聚合，不建邊。依據：`0.5.0-W1-001` 用戶裁決 D4（2026-10-07）；domain 名稱權威寫法以 DomainBundle 的 `domain` 為準（2026-10-07 用戶裁決，`0.5.0-W1-090`／`0.5.0-W1-091`）。

**規則**：
- 索引鍵為 DomainBundle 輕節點來源 frontmatter 的 `domain` 值；精確比對（區分大小寫、不去空白、不正規化）
- 不以字串拼接（如 `DOMAIN-MAP-` 加名稱）代替索引查詢：ID 慣例不是 schema 保證
- 解析不到的名稱（未宣告）：回報一筆缺陷（帶 UC ID、step id、原始值），收在 EVT-GRAPH-001 的 `graphDefects`，經 FR-09 成為 `graphDefect`
- `traverses` 為空清單：無解析結果、無缺陷（純畫面步驟，Layout 的「畫面」列）
- 解析器的輸入是名稱字串、輸出是 DomainBundle 節點 ID 或未宣告，不綁 FlowStep 型別：`depends_on_domains` 建邊時接同一解析器（`0.6.0-W1-074`），避免兩處各自比對而漂移
- 本版只解析 `traverses`；`depends_on_domains` 不解析、不建邊（D6 排除鍵維持）

**驗收條件**：
- [ ] Given 兩語料，Then 全部 `traverses` 值解析到 DomainBundle 節點
- [ ] Given `traverses: ["nope"]` 且沒有 DomainBundle 宣告 `domain: nope`，Then 回報一筆缺陷（E2 正向對照）
- [ ] Given `traverses: ["Corpus"]` 而宣告為 `corpus`，Then 回報一筆缺陷（精確比對）
- [ ] Given 一個 DomainBundle 的 ID 不符合 `DOMAIN-MAP-<domain>` 慣例，Then 其 `domain` 名仍可解析
- [ ] Given SPEC 帶 `depends_on_domains`，Then 不建邊，不回報缺陷

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
| D2 | 本版建圖的邊型為使用中邊型（〈用詞〉） | 用戶裁決 2026-09-30 |
| D3 | 引用值分類為解析成功、斷邊、格式錯誤三類，不部分救回 | 用戶裁決 2026-09-30 |
| D4 | 缺陷子類為 FR-09 所列四種；其中 `duplicateId` 與自我引用的處理為規格預設，用戶 2026-09-30 整批確認；孤島與缺必要邊延至 0.6 | 用戶裁決 2026-09-30 |
| D5 | 整合測試使用凍結測資，預期值由獨立參照實作產生並凍結 | 用戶裁決 2026-09-30；同 SPEC-006 D3 |
| D6 | 邊型的欄位名、正向基數、是否有反向欄位取自型別表；程式內的鍵名例外只有兩處：排除 `domain_dependency`、以 `association` 認定無向邊（FR-05）。`domain_dependency` 排除鍵在 0.5.0 維持（`0.5.0-W1-001` 裁決 D4，2026-10-07），建邊與移除排除鍵由 `0.6.0-W1-074` 承接；`association` 例外於上游補無向欄位後移除 | 同 SPEC-006 D1：上游 schema 為唯一權威。第二個例外起因於上游 JSON 缺無向欄位（用戶裁決 2026-09-30，WRAP） |
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
