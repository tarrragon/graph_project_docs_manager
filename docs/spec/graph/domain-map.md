---
id: DOMAIN-MAP-graph
domain: "graph"
source_specs: [SPEC-007]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05]
depends_on_bundles: [DOMAIN-MAP-corpus, DOMAIN-MAP-schema]
path_patterns: [lib/graph/]
created: "2026-08-26"
updated: "2026-10-21"
---

# Domain Map — Graph

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Graph domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Graph domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：圖語意改變（如 symmetric union 規則）

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Corpus（`DOMAIN-MAP-corpus`） | 圖建自解析產物 |
| 出邊 | Schema（`DOMAIN-MAP-schema`） | 建邊依 Schema 的邊型表（正向欄位、反向欄位、正向基數、方向；SPEC-007 FR-01）；`lib/graph/graph_builder.dart` 等五檔 import `lib/schema/`。2026-10-21 補記（`0.5.0-W1-460`），原本漏列 |
| 入邊 | Layout | 布局的輸入是圖 |
| 入邊 | Diagnostics | 經 EVT-GRAPH-001 取 `graphDefects` 與 flow 子圖產生破洞（SPEC-007 FR-09、SPEC-003 §3.5） |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Graph | 否 | 索引與遍歷為內部計算，無對外呈現面 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Graph** | 圖語意改變（如 symmetric union 規則） | 輕節點、邊、**鄰接查詢**（SPEC-007 FR-08）、**貫穿數**（domain × UC，依 FlowStep `traverses` 聚合）、**domain × UC 關係與依賴路徑**（延伸貫穿數：直接貫穿／間接依賴／無關三值，間接依賴另帶依賴路徑；SPEC-007 FR-12，`0.5.0-W1-114` 用戶裁決 O1——畫面只顯示，規則不落 Layout 或畫面層）、**DomainBundle 分層與層內排序**（1a max+1、2b code point；Layout 泳道列序與 FR-12 依賴路徑排序共用；SPEC-007 FR-13，`0.5.0-W1-114.2` 用戶裁決 R1）、**路徑→domain 查詢**（對照表由 Graph 持有，表內容待建，見 0.1.0-W3-352） | 索引結構、遍歷演算法 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test，不靠「剛好出現在某個 UC 場景」被動覆蓋。規則權威在 SPEC-007，本表只列可獨立斷言的不變式，目標路徑為 `lib/graph/`。SPEC-007 歸屬其他 bundle 的條款各在其 map：FR-01 在 Schema，FR-07 在 TicketDetail，FR-09 在 Diagnostics（§7）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC 條款 |
|---|---|---|
| Graph | 輕節點的欄位恰為 `id`、節點型別、`status`、`title`、相對路徑五項，與 frontmatter map 無共用引用；`status`、`title` 不是字串時為 null，不中止建圖 | SPEC-007 FR-02 |
| Graph | 同一 `id` 出現在兩個以上 `rawNode` 時兩者都不建節點，回報一筆帶全部路徑的 `duplicateId`；這些節點的欄位不抽取引用值，也不計入引用值總數 | SPEC-007 FR-02 |
| Graph | 欄位缺席、null、空字串、空清單不產生引用值；清單內的 null 項跳過不計 | SPEC-007 FR-03〈抽取〉 |
| Graph | 反向欄位的值是 map 時，依值的形狀逐子鍵展開，不依欄位名；子鍵值不是清單時該子鍵計一個格式錯誤 | SPEC-007 FR-03〈抽取〉 |
| Graph | 每個引用值依序落入第一個成立的類別：格式錯誤（形狀不合法，或原樣比對不符任何 `id_pattern`，不去除空白）→ 格式錯誤 `selfReference` → 斷邊（`targetMissing`／`targetDuplicated`）→ 解析成功 | SPEC-007 FR-03〈分類〉 |
| Graph | 守恆式：引用值總數＝解析成功數＋斷邊數＋格式錯誤數 | SPEC-007 FR-03 |
| Graph | 同一條邊（邊型、起點、終點相同；無向邊為兩端集合相同）只建一次，宣告來源取各次宣告的聯集 | SPEC-007 FR-04 |
| Graph | 有反向欄位的邊型：起點的正向欄位列出終點，或終點的反向欄位列出起點，任一成立即建邊 | SPEC-007 FR-04 |
| Graph | 正向基數為 `one` 的邊型，一個起點指向兩個以上解析成功的終點時全部照建，另回報一筆 `multiSource`；斷邊的終點不參與此判定 | SPEC-007 FR-04 |
| Graph | 是否無向只讀邊型條目的 `direction`，不依鍵名或 `class` | SPEC-007 FR-05 |
| Graph | 無向邊型 A 列出 B 或 B 列出 A，都建同一條 {A, B}，宣告來源為列出對方的端點集合 | SPEC-007 FR-05 |
| Graph | `rawNodes` 為空時照常發出 EVT-GRAPH-001，所有計數為 0，`graphDefects` 為空 | SPEC-007 FR-06 |
| Graph | `graphDefects` 筆數＝斷邊數＋格式錯誤數＋`duplicateId` 數＋`multiSource` 數＋flow 各子類缺陷數＋domain 重複宣告數 | SPEC-007 FR-06 |
| Graph | `edgeCount` 只計主圖的邊：flow 子圖的連線不進邊集合 | SPEC-007 FR-06、FR-10 |
| Graph | 鄰接查詢：節點不在圖上回傳空清單；建圖不可用或尚未完成時回傳「圖不可用」，不回傳空清單 | SPEC-007 FR-08 |
| Graph | 鄰接查詢：無向邊在任何方向篩選下都回傳，方向標為無向；每項的 `layer` 取自型別表，不依鍵名 | SPEC-007 FR-08 |
| Graph | 建圖不可用時，`flowOf`、domain × UC 關係、分層排序三個查詢皆回傳「圖不可用」，並寫與鄰接查詢同形的日誌事件 | SPEC-007 FR-10、FR-12、FR-13 |
| Graph | `flowOf` 主線取 `branch_from` 為空的步驟，依清單順序，不沿 `next` 推導；主線 `next` 解析不到時只標於解析結果，不產生缺陷 | SPEC-007 FR-10 |
| Graph | `branch_from`、`return_to`、分支步 `next` 只在同一 UC 的步驟 id 內解析；解析不到時步驟留在子圖內、參照標為未解析，每個參照報一筆「flow 參照未解析」 | SPEC-007 FR-10 |
| Graph | 同一 UC 內 step id 重複時全部步驟保留，報一筆「UC 內 step id 重複」，指向該 id 的參照全部標為未解析並各報一筆；不同 UC 的 step id 相同不是缺陷 | SPEC-007 FR-10 |
| Graph | 分支步 `next` 逐元素解析，純量視同單元素清單，`[]` 不報缺陷；step id 與參照值為非空非字串時轉字串比對，不報缺陷 | SPEC-007 FR-10 |
| Graph | UC ID 不在圖上或不是 UC 時回傳「不存在」；步驟清單為空時回傳空子圖，兩者區分 | SPEC-007 FR-10 |
| Graph | `emits`／`consumes` 的元素不在事件節點 id 集合中時，各報一筆「事件引用未解析」。id 集合取 Corpus `rawNodes` 中型別為 EVT 者，含重複 id 的檔；同一步驟同一欄位內同一值只報一筆 | SPEC-007 FR-10〈事件引用〉 |
| Graph | 名稱索引以 DomainBundle 的 `domain` 精確比對，區分大小寫、不去除空白；不以 ID 字串拼接代替索引 | SPEC-007 FR-11 |
| Graph | `traverses` 的未宣告值以（步驟, 值）去重，各報一筆；同一步驟的已宣告值照常解析 | SPEC-007 FR-11 |
| Graph | 步驟缺 `traverses` 鍵時報一筆「`traverses` 鍵缺席」（欄位 `traverses`、原始值 `null`），不視同 `[]`；鍵存在而值為 `null` 時視同 `[]`，不報缺陷 | SPEC-007 FR-11 |
| Graph | 兩個以上 DomainBundle 宣告同一 `domain` 時全部不進名稱索引，引用該名稱的值報未宣告，另報一筆 domain 重複宣告 {domain, 衝突的 DomainBundle ID 清單}；這些 bundle 仍是節點 | SPEC-007 FR-11 |
| Graph | domain × UC 關係只把 FR-11 解析成功的值算作直接貫穿；直接貫穿與無關的依賴路徑為空；DomainBundle 或 UC 不在圖上時回傳無關且路徑為空 | SPEC-007 FR-12 |
| Graph | 間接依賴路徑：對每個來源，先排除中間節點為直接 domain 的路徑，再取最短路徑，同長全列；排序先比長度，再比來源在分層排序中的先後，再比中間節點的先後 | SPEC-007 FR-12 |
| Graph | 分層：沒有 `bundle_dependency` 出邊者為 L0，其餘為所依賴 bundle 的最大層加 1；任一所依賴 bundle 推不出層時，本身也推不出層 | SPEC-007 FR-13 |
| Graph | 同層依 `domain` 字面的 Unicode code point 遞增排序，不依 locale | SPEC-007 FR-13 |
| Graph | 推不出層的 bundle（依賴循環、`depends_on_bundles` 指向自己、依賴指向非 DomainBundle 或不存在者）不消失，依 code point 序接在最後，層號為 null | SPEC-007 FR-13 |
| Graph | `domain` 無效（非字串、`null`、缺鍵、空字串）不影響層號，也不影響依賴它的 bundle；同層排在 `domain` 有效者之後，彼此依 DomainBundle ID 的 code point 序 | SPEC-007 FR-13 |

## 5. 對實作票的切分指引

- Graph 的票不得依賴 UI —— 遍歷與 symmetric union 皆為純函式，可獨立測試

## 6. 待決事項

- ~~**`鄰接查詢` 的簽章未定**~~（§2.5）：2026-09-30 定於 SPEC-007 FR-08，為 1 hop 查詢。
  矩陣的「間接依賴」需要多 hop，屬 0.5 規劃。2026-10-08 用戶裁決 O1（`0.5.0-W1-114`）：
  間接依賴由 Graph 判定，於公開面回傳三值與依賴路徑（SPEC-007 FR-12），不由畫面組合

> 「路徑模式 → domain」對照表由 Graph 持有（內容待建）；該待決事項本體在系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | 邊型表 | Schema | domain unit |
| FR-02 | 輕節點（含重複 ID） | Graph（讀 Corpus `rawNodes`） | domain unit；IT-3 |
| FR-03 | 引用值抽取與三類分類、守恆 | Graph | domain unit；IT-2 |
| FR-04 | 邊的方向與建邊來源：反向欄位兩側聯集、宣告來源、依正向基數判多來源衝突 | Graph | domain unit；IT-1 |
| FR-05 | `relatedTo` 1-hop 對稱聯集 | Graph | domain unit；IT-1 |
| FR-06 | 建圖結果、計數與 EVT-GRAPH-001 | Graph | domain unit |
| FR-07 | TicketDetail 以 ID 查詢全文 | TicketDetail（讀 Corpus `rawNodes`） | domain unit；IT-3 |
| FR-08 | 鄰接查詢 | Graph | domain unit；IT-1 |
| FR-09 | 由 EVT-GRAPH-001 產生 `graphDefect` 破洞 | Diagnostics | domain unit；IT-2 |
| FR-10 | `flowOf(ucId)` flow 子圖 | Graph（讀 Corpus 附掛於 UC `rawNode` 的步驟清單） | domain unit |
| FR-11 | `traverses` 名稱解析（以 DomainBundle `domain` 精確比對） | Graph | domain unit |
| FR-12 | domain × UC 關係（三值）與依賴路徑 | Graph | domain unit |
| FR-13 | DomainBundle 分層與層內排序 | Graph | domain unit |
| NFR-01 | 缺陷隔離 | Graph | domain unit |
| NFR-02 | 計算量線性 | Graph | `test/performance/`（不入主套件） |

全部 FR 皆有歸屬，無標為非 domain 者。Graph 與 TicketDetail 都只讀 Corpus 產物、彼此不依賴（§4.1）；
Diagnostics 經 EVT-GRAPH-001 接收缺陷，不依賴 Graph 的內部結構。

> 本表為 SPEC-007 全表的權威（與 spec 同目錄，供 `check_domain_coverage` 定位）；歸屬 Schema、TicketDetail、Diagnostics 的列在各自 domain map §7 另列副本。

---

**Last Updated**: 2026-10-31（`0.5.0-W1-184`：§3 新增〈Bundle 不變式清單〉，列 SPEC-007 FR-02～06、FR-08、FR-10～13）；前次 2026-10-08（`0.5.0-W1-114.3`：§3 公開面補 DomainBundle 分層與層內排序、§7 補 FR-13；前次 `0.5.0-W1-114.1`：§3 公開面補 domain × UC 關係與依賴路徑、§6 間接依賴歸屬、§7 補 FR-12） | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
