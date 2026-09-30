---
id: SPEC-007
title: "建圖：輕節點、邊的聯集與圖結構破洞"
status: draft
source_proposal: PROP-005
created: "2026-09-30"
updated: "2026-09-30"
version: "1.0"
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
建成圖。依賴方向照 `docs/domain-map.md` §2（Graph → Corpus），跨四個 domain：

| Domain | 本規格內的職責 | 對應 FR |
|--------|--------------|--------|
| **Schema** | 提供邊型表（正向欄位、反向欄位、類別、層級） | FR-01 |
| **Graph** | 建輕節點；抽取引用值並分類；建邊（反向欄位取兩側聯集、`relatedTo` 對稱聯集）；鄰接查詢 | FR-02～FR-06、FR-08 |
| **TicketDetail** | 持有 ticket 的 5W1H 全文與生命週期欄位，以 ID 查詢 | FR-07 |
| **Diagnostics** | 由 Graph 回報的引用缺陷產生 `graphDefect` 破洞 | FR-09 |

版本契約（PROP-005 §0.4）為三項整合測試，本規格的 FR 以它們為驗收終點：

| 整合測試 | 驗收的 FR | 斷言 |
|---------|----------|------|
| IT-1 對稱聯集 | FR-04、FR-05、FR-08 | 由凍結 manifest 實體化的語料建圖，邊集合與凍結的參照實作輸出一致；對每一筆單側儲存的 `relatedTo`，被指向的一端做鄰接查詢時也查得到對方（只讀單向時查不到，證明測資有鑑別力） |
| IT-2 斷邊交給 Diagnostics | FR-03、FR-09 | 同一份語料，每一筆斷邊與格式錯誤引用都產生破洞，破洞集合與凍結的參照實作輸出一致，沒有被靜默丟棄的引用值（FR-03 守恆式成立） |
| IT-3 輕節點與全文分離 | FR-02、FR-07 | 圖上每個節點只帶輕節點欄位；ticket 的 5W1H 全文只能經 TicketDetail 以 ID 取得 |

斷言來源：`EVT-GRAPH-001`、`docs/domain-map.md` §4.1、`docs/tech-decisions.md` 2026-09-30 補記（反向邊讀取規則）。

## 前置依賴

| 依賴 | 擋住 | 承接 |
|------|------|------|
| PROP→SPEC 的反向資料與正向一致（聯集規則下反向資料錯誤會成為錯邊） | IT-1 的凍結測資 | `0.4.0-W1-045` |
| 上游 #98 第二項（`spec_refs` 存或推導） | 無：本規格的聯集規則不依賴其結果（tech-decisions 2026-09-30） | — |

## 本版範圍外

| 項目 | 不在本版的理由 | 承接 |
|------|--------------|------|
| `depends_on_domains`（`domain_dependency` 邊） | 值是 domain 名稱而非節點 ID（兩語料實測），個別 domain 不是圖節點；與 0.5「矩陣的列無來源」是同一個問題（用戶裁決 2026-09-30） | `0.5.0-W1-001` |
| B 層 4 條邊（`emits`／`consumes`／`branch_from`／`return_to`）與 FlowStep 節點 | 欄位在 UC 的結構化 flow 區塊內，不在 frontmatter，Corpus 未解析；layer 為 proposed（用戶裁決 2026-09-30） | `0.5.0-W1-001` |
| 破洞「孤島」「缺必要邊」 | 「必要邊」未定義（哪種節點必須有哪種邊）；本版只做有判準的子類：用戶裁決的斷邊、格式錯誤、多來源衝突（2026-09-30），加上 FR-02 的重複 ID | `0.6.0-W1-072` |
| 貫穿數、路徑→domain 查詢 | 依賴 FlowStep `traverses` 與路徑對照表，屬 0.5 | PROP-005 §0.5 |
| 語料變動後的增量重建（EVT-CORPUS-002） | 本版只做單輪完整建圖；重掃屬畫面接真資料的互動 | PROP-005 §0.6 |
| 引用值的部分救回（例：從 `0.2.1-W3-1057 驗收` 抽出 ID） | 與 SPEC-006「不部分救回」一致；救回規則會猜錯（兩個 ID 寫在同一字串） | 本版只回報（FR-03） |

## 功能需求

### FR-01：邊型表（Schema 公開面）

**描述**：Schema 從型別表 JSON 的 `edge_types` 解碼邊型，供 Graph 查詢。與節點型別同一份來源、同一套版本判定（SPEC-006 FR-06 規則 7）。

**規則**：
- 每個邊型帶：鍵名（如 `association`、`spawn`）、`class`、`forward_field`、`reverse_field`（可為 null）、`layer`
- Graph 只使用 `layer` 為 `established` 的邊型，並排除〈本版範圍外〉所列的 `domain_dependency`；其餘邊型由型別表決定，不在程式內寫死欄位名
- 型別表缺 `edge_types` 時，比照節點型別：版本在 App 已知範圍內則從內建表補；否則建圖不可用，回報原因碼（與 SPEC-006 FR-08 同一套「無法判定」原因）

**驗收條件**：
- [ ] Given 內建型別表，Then 解碼出 16 個邊型，其中 established 12 個，Graph 實際使用 11 個（排除 `domain_dependency`）
- [ ] Given 測試用型別表把某 established 邊型的 `forward_field` 改名，Then Graph 依新欄位名抽取，不讀舊欄位名
- [ ] Given 專案型別表缺 `edge_types` 且版本在已知範圍內，Then 從內建表補，建圖照常

### FR-02：輕節點

**描述**：Graph 為每個 `rawNode` 建一個輕節點。輕節點只帶圖需要的欄位（`docs/domain-map.md` §4.1）。

**輕節點欄位**：`id`、節點型別、`status`（缺席為 null）、`title`（缺席為 null）、相對路徑。不帶 frontmatter map 的其他欄位，也不保留對它的引用。

**規則**：
- 同一個 `id` 出現在兩個以上的 `rawNode`（兩語料實測為 0）：兩者都不建節點，產生一筆 `graphDefect`（子類 `duplicateId`，帶全部路徑）；指向該 ID 的引用值視為斷邊
- `status`、`title` 不是字串時視為缺席（null），不中止建圖

**驗收條件**：
- [ ] Given 任一 ticket 的 `rawNode`，Then 對應輕節點的欄位集合恰為上列五項，且與 frontmatter map 無共用引用
- [ ] Given 兩份檔案的 frontmatter `id` 相同，Then 兩者都不在圖上，產生一筆 `duplicateId` 破洞帶兩個路徑

### FR-03：引用值抽取與分類

**描述**：Graph 對每個節點、每個使用中的邊型，讀取正向欄位與（若有）反向欄位的值，逐一分類。

**值的形狀**：
- 純量或清單：清單逐項處理；null、空字串、空清單不產生任何值
- 反向欄位 `outputs`（PROP）是 map：子鍵 `spec_refs`、`usecase_refs`、`event_refs`、`ticket_refs` 的清單值都屬 `provenance` 的反向宣告；子鍵只是分組，不檢查目標型別
- 其他形狀（數字、巢狀 map、清單內的非字串）：該項為格式錯誤

**分類**（每個值恰好落入一類）：

| 類別 | 條件 | 處置 |
|------|------|------|
| 解析成功 | 值等於圖上某個節點的 `id` | 參與建邊（FR-04、FR-05） |
| 斷邊 | 值符合某個節點型別的 `id_pattern`，但圖上沒有該 ID 的節點 | 不建邊，回報 `danglingRef` |
| 格式錯誤 | 值不符合任何節點型別的 `id_pattern`，或形狀不合法 | 不建邊，不救回，回報 `malformedRef` |

**守恆式**：抽取的值總數 = 解析成功數 + 斷邊數 + 格式錯誤數。

**規則**：值指向自己（自我引用，兩語料實測為 0）：不建邊，回報 `malformedRef`（原因碼 `selfReference`）。

**驗收條件**：
- [ ] Given `source_ticket: 0.1.0-W3-181` 且圖上沒有該節點，Then 回報一筆 `danglingRef`，不建邊
- [ ] Given `relatedTo: ["0.1.0-W1-072 0.1.0-W1-073"]` 與 `discovered_during: "0.2.1-W3-1057 驗收"` 與 `spawned_tickets: [PENDING]`，Then 三者皆為 `malformedRef`，不建邊，不抽出其中的 ID
- [ ] Given 一份分布已知的 fixture，Then 三類計數等於已知值，守恆式成立

### FR-04：有反向欄位的邊：兩側聯集

**描述**：`reverse_field` 非 null 的邊型（本版為 `provenance`、`blood`、`spawn`），任一側宣告即建邊，邊上記錄宣告來源（`docs/tech-decisions.md` 2026-09-30 補記）。

**規則**：
- 方向：邊由持有正向欄位的一端指向其值。節點 H 的正向欄位值為 T，或節點 T 的反向欄位列出 H，都代表同一條邊 H→T
- 同一條邊（邊型、起點、終點相同）只建一次；宣告來源為 `forward`、`reverse` 或 `both`
- 多來源衝突：正向欄位語意為單值的邊型，一個節點經聯集後指向兩個以上不同終點時，全部邊照建，另回報一筆 `multiSource`（帶節點與全部終點及各自的宣告來源）
- 正向欄位語意為單值，指的是型別表中該 `forward_field` 在節點 frontmatter 為純量；本版三個邊型皆是

**驗收條件**：
- [ ] Given 子票 `source_ticket` 為空、父票 `spawned_tickets` 列出子票，Then 建一條 `spawn` 邊（子→父），宣告來源為 `reverse`
- [ ] Given 父子兩側都宣告，Then 只建一條邊，宣告來源為 `both`
- [ ] Given 子票 `source_ticket: A`，另一張父票 B 的 `spawned_tickets` 列出子票，Then 建兩條邊（→A `forward`、→B `reverse`），並回報一筆 `multiSource`
- [ ] Given PROP 的 `outputs.spec_refs` 列出 SPEC-X，SPEC-X 的 `source_proposal` 為同一 PROP，Then 一條 `provenance` 邊，宣告來源 `both`

### FR-05：`relatedTo` 的 1-hop 對稱聯集

**描述**：`association` 邊（`relatedTo`）語意無向、儲存單向，建圖時做 1-hop 對稱聯集。

**規則**：
- A 的 `relatedTo` 列出 B，或 B 的 `relatedTo` 列出 A，都建同一條無向邊 {A, B}
- 兩側都列出時只建一次；宣告來源記錄哪些端點有列出（A、B 或兩者）
- 其餘 `reverse_field` 為 null 的邊型為單向邊，只由正向欄位建立

**驗收條件**：
- [ ] Given A 列出 B、B 未列出 A，Then 邊 {A, B} 存在，且對 B 做鄰接查詢會得到 A
- [ ] Given A、B 互相列出，Then 只有一條邊

### FR-06：建圖結果與事件

**描述**：一輪建圖完成時，Graph 產出 EVT-GRAPH-001，並提供可驗證的計數。

**計數項**：節點數、`duplicateId` 數、各邊型的邊數、各宣告來源的邊數、FR-03 三類計數、`multiSource` 數。

**負載**（取代 EVT-GRAPH-001 的暫定負載）：`nodeCount`、`edgeCount`、`refDefects`（FR-03 的斷邊與格式錯誤、FR-02 的重複 ID、FR-04 的多來源衝突，逐筆）。

**驗收條件**：
- [ ] Given 一份分布已知的 fixture，Then 各計數項等於已知值，FR-03 守恆式成立
- [ ] Given 建圖完成，Then 發出一筆 EVT-GRAPH-001，`refDefects` 筆數等於各缺陷計數總和

### FR-07：TicketDetail

**描述**：TicketDetail 持有 ticket 的 frontmatter 全文（含 5W1H 與生命週期欄位），以 `id` 查詢。Graph 不持有這些欄位（`docs/domain-map.md` §4.1）。

**規則**：
- 查詢來源為同一輪 Corpus 的 `rawNodes`；只收節點型別為 Ticket 者
- 查無該 ID（含 FR-02 被排除的重複 ID）時回傳「不存在」，不拋例外
- 本版只提供查詢，不涉及畫面（節點詳情接真資料屬 0.6）

**驗收條件**：
- [ ] Given 一張 ticket 的 `id`，Then TicketDetail 回傳其 `who`／`what`／`when`／`where`／`why`／`how` 與 frontmatter 其餘欄位，內容與 `rawNode` 一致
- [ ] Given 不存在的 ID，Then 回傳「不存在」

### FR-08：鄰接查詢（Graph 公開面）

**描述**：給一個節點 ID，回傳相鄰的節點。解決 `docs/domain-map.md` §2.5「鄰接查詢簽章待定」。

**輸入**：節點 ID；可選的邊型集合（預設為全部使用中的邊型）；方向（出、入、兩者，預設兩者）。

**輸出**：清單，每項帶邊型、另一端的節點 ID、方向（出、入、無向）、宣告來源。無向邊（`association`）在任何方向篩選下都會回傳，方向標為無向。

**規則**：節點 ID 不在圖上時回傳空清單，不拋例外。

**驗收條件**：
- [ ] Given 一張子票以 `source_ticket` 指向父票，Then 查子票（方向：出）得到父票，查父票（方向：入）得到子票
- [ ] Given 邊型篩選只含 `blocking`，Then 回傳不含其他邊型
- [ ] Given 不存在的 ID，Then 回傳空清單

### FR-09：圖結構破洞（Diagnostics）

**描述**：Diagnostics 收到 EVT-GRAPH-001 後，對 `refDefects` 逐筆產生 EVT-DIAGNOSTICS-001 的 `graphDefect` 破洞。

**子類**：`danglingRef`、`malformedRef`（含 `selfReference`）、`duplicateId`、`multiSource`。

**規則**：
- 一筆缺陷對應一筆破洞，帶來源節點 ID 與路徑、欄位名、原始值（原樣，不正規化）、邊型；資訊要足以讓使用者直接去修
- 顯示文字由畫面經 l10n 投影，Diagnostics 不產生在地化字串（與 SPEC-006 FR-08 一致）
- 建圖不可用（FR-01）時不產生本類破洞，報告顯示「無法判定破洞」並說明原因

**驗收條件**：
- [ ] Given IT-2 的實體化語料，Then 每一筆破洞的子類、來源、欄位、原始值與凍結的參照實作輸出一致，沒有多出或缺少的破洞
- [ ] Given 建圖不可用，Then 不產生 `graphDefect`，並回報無法判定

## 非功能需求

### NFR-01：缺陷隔離

任一引用值的缺陷都不得中止建圖，也不得改變其他值的分類與其他邊。
**驗收**：在正常語料中，為 FR-03 三類缺陷、`duplicateId`、`multiSource` 各插入一筆，其餘邊集合與未插入時逐項相同。

### NFR-02：計算量

建圖的計算量與引用值總數呈線性（以 ID 索引解析，不做兩兩比對）。主套件不以計時斷言驗證（`test-assertion-design-rules` D1），如需量測放 `test/performance/`。

## 錯誤處理

| 錯誤情境 | 處理方式 | 對應 |
|---------|---------|------|
| 引用值指向不存在的節點 | 不建邊，`danglingRef` | FR-03 |
| 引用值不符合任何 ID 格式或形狀不合法 | 不建邊，不救回，`malformedRef` | FR-03 |
| 引用值指向自己 | 不建邊，`malformedRef`（`selfReference`） | FR-03 |
| 兩份檔案同一 `id` | 兩者都不建節點，`duplicateId` | FR-02 |
| 單值正向欄位經聯集得到多個終點 | 全部建邊，`multiSource` | FR-04 |
| 型別表缺 `edge_types` 且版本不在已知範圍 | 建圖不可用，回報原因碼，不產生 `graphDefect` | FR-01、FR-09 |

## 設計約束

| # | 約束 | 來源 |
|---|------|------|
| D1 | 有反向欄位的邊取兩側聯集並記錄宣告來源；Diagnostics 只報衝突與缺陷，單側宣告不是缺陷 | 用戶裁決 2026-09-30（WRAP）；tech-decisions 同日補記 |
| D2 | 本版邊型為 established 且值為節點 ID 的 11 條 | 用戶裁決 2026-09-30 |
| D3 | 引用值三類分類，不部分救回 | 用戶裁決 2026-09-30 |
| D4 | `graphDefect` 本版限有判準的子類；孤島與缺必要邊延至 0.6 | 用戶裁決 2026-09-30 |
| D5 | 整合測試使用凍結測資，預期值由獨立參照實作產生並凍結 | 用戶裁決 2026-09-30；同 SPEC-006 D3 |
| D6 | 邊型欄位名取自型別表，不在程式內寫死 | 同 SPEC-006 D1 的精神：上游 schema 為唯一權威 |

**D5 的展開**：

- **manifest 來源**：兩個語料專案（本專案、flutter_balance）的節點，只凍結建圖需要的欄位：`id`、型別、相對路徑、`status`、`title`、全部使用中邊型的正向與反向欄位原值。ticket 另凍結少量完整 frontmatter 樣本供 IT-3。
- **實體化**：測試執行時依 manifest 在暫存目錄寫出最小 frontmatter 檔案樹，經 Corpus 掃描後建圖，不直接把 manifest 餵給 Graph；否則 Corpus→Graph 的交界會被繞過。
- **預期值來源**：獨立的 Python 參照實作依本規格產生邊集合與缺陷清單，凍結時離線執行，CI 不執行它。
- **樣本覆蓋**：manifest 至少各含一筆單側 `relatedTo`、兩側 `relatedTo`、只在反向的 `spawn`、多來源衝突、斷邊、格式錯誤。語料中沒有的類型（重複 ID、自我引用）用合成列補上並標記為合成。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-09-30 | 初版：0.4.0 規劃波 Step 2，依 PROP-005 §0.4 與用戶裁決 D1～D5 建立。兩語料實測：本專案 1179 節點、flutter_balance 1690 節點；引用值中斷邊 3／0、格式錯誤 1／4、只在反向的 `spawn` 38／52；重複 ID 與自我引用皆 0 |
