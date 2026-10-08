---
id: SPEC-001-test-design
title: "SPEC-001 v1.38／SPEC-004 v1.77／UC-02 v1.8 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-001
spec_version: "1.35"
delta_spec_version: "1.38"
related_specs: [SPEC-004, UC-02, SPEC-007]
ticket: 0.5.0-W1-114
delta_ticket: 0.5.0-W1-114.4
created: "2026-10-08"
updated: "2026-10-08"
---

# SPEC-001 v1.38／SPEC-004 v1.77／UC-02 v1.8 Phase 2 紅燈測試規格

**v1.38 差異（`0.5.0-W1-114.4`）**：依 `0.5.0-W1-114.2` 用戶裁決 R1／J2。R1：列序規則改歸 Graph（SPEC-007 FR-13），
L1-1～L1-3、L2-1～L2-4 移至 `docs/test-design/SPEC-007-test-design.md` G13，Layout 改測「向 Graph 取列序、不自行推導」（L8）。
J2：跳轉目標由 Layout 公開面「給定一列，回傳欄號最小的節點」查詢取得（L9），畫面以 FR-12 第一條路徑的來源呼叫（V3 改寫），
NC-1、NC-2 已處置。UC-02 v1.8 比對語意兩條（C3′ 不以 `/` 結尾的值精確比對、T1 同字串歸 domain）落為 P4。

**v1.36～v1.37 差異（`0.5.0-W1-114.2`）**：依 `0.5.0-W1-114` 用戶裁決 T1／O1／F1、`0.5.0-W1-113` D-3、
`0.5.0-W1-096.7` NC-1 與 `0.5.0-W1-114.1` PM 處置 NC-a～NC-g 增改：「未定位」列（L7、ITD2-A5 改寫、
L1-4／L4-3／K2-4 改寫、K2-5）、flow 區塊解析失敗的泳道與 UC Flow 呈現（F1）、宣告狀態行「格式錯誤」
（P1-7、R1-9、R1-10、ITD4-A5）、proposed 邊外圈驗收（ITD3-A5）。原 V1、V2（間接依賴判定與依賴路徑）
改歸 Graph FR-12，移至 `docs/test-design/SPEC-007-test-design.md` G12；V3 的歸屬見 §6.1 NC-2。
`spec_version` 記全文覆核版本，`delta_spec_version` 記本輪局部覆核版本。

本文件是 0.5.0 規劃波 version-bootstrap Step 5 的紅燈測試規格，涵蓋：

- SPEC-001 v1.35 §1〈泳道布局規則〉〈間接依賴判定式〉〈間接依賴格的詳情卡：依賴路徑〉〈間接依賴格的「在泳道中檢視」跳轉目標〉
- SPEC-001 v1.35 §5〈專案層級宣告狀態一行不是新狀態〉
- UC-02 v1.6〈ticket 定位的五種狀態與整體未宣告〉
- SPEC-004 v1.75 4.37 `MatrixGrid` 列首原值、4.38 `SwimlaneGrid` `lanes`／`edges`、4.19 `RelationItem` `isProposed`、§4.0.6 宣告狀態行四個 key

只描述測資、流程與斷言，不含測試程式碼。規則權威在上列規格；本文件與規格衝突時以規格為準，
衝突本身記入承接票的 NeedsContext。決策背景見 `docs/tech-decisions.md` 2026-10-07、2026-10-08 各補記。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-D1～IT-D4 四項 `integration_test/` 驗收（UC-02 `runtime_surface: "yes"`） | 版本契約的驗收終點：真實語料驅動 App，畫面上看得到判定結果 | 各單元正確但接線、資料來源或畫面消費有分歧 |
| 5b 內圈 | Layout、domain_view、路徑定位、Diagnostics／報告頁、元件五個實作單元的 unit／widget 測試 | 各判定式逐條斷言 | 單一規則被打破，可直接定位 |

外圈綠而內圈紅、或反之，都代表測資沒有涵蓋到對應形態，須補測資而非放寬斷言。

### 1.2 斷言錨點：兩份真實語料

| 語料 | 用途 | 已知分布（本版資料） |
|------|------|-------------------|
| 本專案（graph_project_docs_manager） | 主語料 | 矩陣 48 格：直接 19／間接 10／無關 19；泳道 9 列；層序 L0 `schema`、`workspace`／L1 `corpus`、`history`／L2 `diagnostics`、`graph`、`ticketdetail`／L3 `layout`；UC-02 欄序 7 欄（SPEC-001 §1〈泳道布局規則〉期望值欄） |
| flutter_balance | 第二語料（對照） | 1 個 DomainBundle（`balance-sheet`）、0 條 `bundle_dependency`；1 個 UC（UC-01）、9 步、4 個分支步（皆帶 `return_to`）；無 `path_patterns`、無非 domain 清單 |

兩份語料皆以**凍結快照**入庫（`test/fixtures/spec001/corpus_snapshot/<語料名>/`），只收測試需要的檔：
各 domain map frontmatter、各 UC 的 flow 區塊、型別表。快照檔頭記凍結日期與來源 commit。
依 SPEC-001「依賴邊或 `traverses` 變動後期望值隨之改變，測試以當時資料重算」，期望值綁快照，
不綁即時 repo（N1 已處置：預期值取凍結快照，見 §6.1）。

flutter_balance 的 flow 推導期望值（依 SPEC-001〈泳道布局規則〉欄序條手算）：

| 欄 | 步驟 | `branch_from` | 對 SPEC 規則的作用 |
|----|------|---------------|-------------------|
| 0 | create-accounts | — | 主線 |
| 1 | backup-restore | create-accounts | 分支插在起點後 |
| 2 | first-inventory | — | 主線 |
| 3 | reject-invalid-input | first-inventory | 分支 |
| 4 | view-net-worth | — | 主線 |
| 5 | currency-switch | view-net-worth | 同起點多分支依檔內順序 |
| 6 | cashflow-runway | view-net-worth | 同上 |
| 7 | assess-leverage | — | 主線 |
| 8 | periodic-inventory | — | 主線 |

邊：`return_to` 四條皆為弧線（1→0、3→2、5→4、6→4）；`branch_from` 四條皆為直線（0→1、2→3、4→5、4→6）；主線 `next` 四條直線。
列：選定 UC-01 時 3 列（「畫面」、`balance-sheet`、「未定位」），`balance-sheet` 為 L0（無出邊）。九步皆無
`traverses` 鍵，依 SPEC-001 §1〈泳道布局規則〉「`traverses` 異常的步驟」全數置於「未定位」列、欄號 0～8
依上表，`balance-sheet` 與「畫面」列皆為空列；Graph 另回報九筆「`traverses` 鍵缺席」缺陷（SPEC-007 FR-11）。
欄序與邊不受此影響（欄序依清單順序，與節點落哪一列無關）。

### 1.3 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 泳道列序、欄序、節點所屬列、邊 | domain unit（Layout，純函式） | 輸入為 Graph 公開面的 flow 子圖與 DomainBundle 依賴邊值物件，測試內直接構造；不 mock Graph 內部 |
| 矩陣三值、依賴路徑 | Graph unit（FR-12，移至 SPEC-007-test-design G12） | — |
| 跳轉目標 | 歸屬待定（§6.1 NC-2）；暫為 domain_view 組合 Graph FR-12 回傳與 Layout 欄序 | 輸入為 FR-12 回傳值與 Layout 欄序值物件 |
| flow 區塊解析失敗呈現 | widget（Domain 視圖泳道、UC Flow 視圖） | 選定 UC 的步驟清單與 EVT-CORPUS-004 破洞以 provider override 注入；i18n 用真實 ARB |
| ticket 路徑五狀態 | domain unit（Graph 路徑比對器） | 輸入為 `path_patterns`（逐 bundle，含「欄位缺席」與 `[]` 兩種）、非 domain 清單（有／無）、路徑清單 |
| 宣告狀態行 | widget（破洞報告頁） | 比對器結果以 provider override 注入；i18n 用真實 ARB |
| 元件 | widget（`test/unit/components/`） | 無 mock，直接給 slot 值 |
| IT-D1～IT-D4 | integration（`integration_test/`） | 不 mock 解析與建圖：讀凍結快照實體化的工作區；只替換資料夾選擇器（沿用既有 stub 選取路徑的做法） |

Mock 只替換外部世界（資料夾選擇、檔案系統 port）；Graph、Layout、domain_view 之間用真實物件。

### 1.4 依賴方向與測試隔離

依系統層 §2：Layout 只依賴 Graph。

- `test/unit/layout/` 只 import `lib/layout/` 與 `lib/graph/` 的公開值型別；不得 import `lib/corpus/`（SPEC-001〈Graph 須提供的分支欄位〉：不得改為直讀 Corpus）
- 路徑比對器測試放 `test/unit/graph/`，不 import `lib/diagnostics/`（受影響路徑數由 Graph 持有，SPEC-001 §5 宣告狀態行表「受影響路徑數來源」列）
- 宣告狀態行 widget 測試不 import `lib/diagnostics/` 的破洞計數，只消費比對器結果

### 1.5 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 |
|--------|------|------|---------|
| flow 子圖建構器 | `test/helpers/spec001/flow_builder.dart` | 以 `(id, next, branch_from, return_to, traverses)` 列宣告出 flow 子圖值物件，保留檔內順序；`traverses` 可宣告為「鍵缺席」，並帶 Graph 名稱解析結果（已宣告值集合） | L3～L7、V3 |
| bundle 依賴建構器 | `test/helpers/spec001/bundle_graph_builder.dart` | 以 `domain → depends_on_bundles` 宣告出依賴邊集合 | L1、L2、L7 |
| 真實語料快照載入器 | `test/helpers/spec001/corpus_snapshot.dart` | 讀凍結快照、交出 flow 子圖與依賴邊（經真實 Corpus＋Graph） | L1-1、L4-1、L7-8、IT-D1～IT-D3 |
| 路徑宣告建構器 | `test/helpers/spec001/path_declaration_builder.dart` | 宣告各 bundle 的 `path_patterns`（缺席／`[]`／清單）與非 domain 清單狀態（有／無／格式錯誤） | P1～P3、R1 |

各群組只透過 helper 取得 fixture，不共享 mutable 狀態，可分派給不同代理人獨立實作。

## 2. 5a 外圈（先於內圈）

外圈共用測資：`test/fixtures/spec001/corpus_snapshot/` 兩份快照，由測試在暫存目錄實體化為工作區根，
經 App 正常開啟流程進入 Domain 視圖。測試檔：`integration_test/domain_view_v050_test.dart`
（IT-D1～IT-D3）、`integration_test/gap_report_declaration_line_test.dart`（IT-D4）。

### 2.1 IT-D1 矩陣三值分布（UC-02 主流程 locate-domain、read-traversal-count）

| # | Given | When | Then |
|---|-------|------|------|
| ITD1-A1 | 本專案快照 | 進入 Domain 視圖矩陣 | 48 格中直接貫穿 19、間接依賴 10、無關 19（以格的 testKey 與變體計數） |
| ITD1-A2 | 同上 | 讀間接格集合 | 恰為 UC-02、UC-03、UC-05 各 {`schema`, `workspace`}；UC-04 {`corpus`, `schema`, `workspace`}；UC-06 {`schema`}；`history` 列 6 格皆無關 |
| ITD1-A3 | 同上 | 讀列首 | 8 列列首文字逐字等於 `DomainBundle.domain` 原值（`ticketdetail` 不轉譯），切 en locale 後不變 |
| ITD1-A4（E1 對照） | flutter_balance 快照 | 進入矩陣 | 間接依賴 0 格（0 條依賴邊）；與 A1 同一流程、同一斷言器得到不同分布，證明間接格來自依賴邊而非常數 |

### 2.2 IT-D2 泳道布局（UC-02 主流程 switch-to-swimlane、inspect-steps）

| # | Given | When | Then |
|---|-------|------|------|
| ITD2-A1 | 本專案快照，選定 UC-02 | 切到泳道 | 9 列，列序為「畫面」、`schema`、`workspace`、`corpus`、`history`、`diagnostics`、`graph`、`ticketdetail`、`layout` |
| ITD2-A2 | 同上 | 讀節點 | 欄序 0～6 依 SPEC-001 期望值；enter-from-ticket 在 `graph`、`ticketdetail` 兩列欄 1；locate-domain 在「畫面」列欄 0；`schema`、`workspace`、`history`、`diagnostics` 為空列 |
| ITD2-A3 | 同上 | 讀邊 | flow-not-structured（5）→ locate-domain（0）為弧線；enter-from-ticket（1）→ read-traversal-count（2）為直線 |
| ITD2-A4 | 同上 | 改選 UC-04 再切泳道 | 列序與 A1 相同（換 UC 列序不變） |
| ITD2-A5（E1 對照，v1.37 改寫） | flutter_balance 快照，選定 UC-01 | 切到泳道 | 3 列，依序「畫面」、`balance-sheet`、「未定位」（列首 `swimlaneUnplacedLaneName`）；九個節點全在「未定位」列、欄號依 §1.2 表，另兩列為空；4 條弧線、8 條直線。與 A1 為同一斷言器、不同語料：A1 無「未定位」列、本案有，證明列數與「未定位」列的出現非寫死 |

### 2.3 IT-D3 間接格詳情卡與跳轉（UC-02 alt enter-from-ticket 的對面：矩陣點格）

| # | Given | When | Then |
|---|-------|------|------|
| ITD3-A1 | 本專案快照 | 點 UC-04 × `schema` | 詳情卡關係種類為間接依賴，依賴路徑恰兩行，依序 `graph → corpus → schema`、`ticketdetail → corpus → schema` |
| ITD3-A2 | 同上 | 點 UC-06 × `schema` | 依賴路徑恰一行 `corpus → schema` |
| ITD3-A3 | 同上 | UC-04 × `schema` 按「在泳道中檢視」 | 泳道選定 UC-04，定位到 `graph` 列中欄號最小且 `traverses` 含 `graph` 的節點 |
| ITD3-A4（E1 對照） | 同上 | 點 UC-04 × `graph`（直接貫穿）與 UC-04 × `history`（無關） | 兩者皆無依賴路徑區塊；直接貫穿格跳轉落在 `graph` 列（既有行為） |
| ITD3-A5（E1 對照，v1.37 新增） | 同上 | 開啟一個帶 `depends_on_bundles` 的 DomainBundle 節點詳情（如 `layout` 的 domain map），讀關聯右欄 | `bundle_dependency` 關聯項尾端有 `Badge.category`（tone `warning`，文字「暫定」）；同一詳情中 established 邊型的關聯項無此 badge。兩類關聯項渲染結果不同，證明標記依 `layer` 而非一律顯示（`0.5.0-W1-114` PM 處置 N3 附帶題；SPEC-001 §6〈關聯右欄標示 proposed 邊〉） |

### 2.4 IT-D4 破洞報告的宣告狀態行（UC-02 v1.6、SPEC-001 §5）

| # | Given | When | Then |
|---|-------|------|------|
| ITD4-A1 | flutter_balance 快照（兩側皆無宣告） | 進入破洞報告、掃描完成 | 頁首出現一行 `pathDeclarationNoneLine`（zh「本專案未宣告路徑」），不含路徑數 |
| ITD4-A2 | 本專案快照＋測試內補上 8 個 bundle 中 5 個的 `path_patterns`、無非 domain 清單 | 同上 | 一行 `pathDeclarationIncompleteLine`，`{detail}` 為「已宣告 5／8 個 domain、缺非 domain 路徑清單」，`{count}` 等於比對器回報的受影響路徑數 |
| ITD4-A3（E1 對照） | A2 的工作區再補齊全部宣告與非 domain 清單 | 同上 | 宣告狀態行不出現；破洞數與 A2 相同（宣告缺口不計入破洞數） |
| ITD4-A4 | A1 工作區 | 掃描中 | 宣告狀態行不出現 |
| ITD4-A5（E1 對照，v1.37 新增） | A3 的工作區，僅把非 domain 路徑清單檔改為 YAML 語法錯誤 | 進入破洞報告、掃描完成 | 宣告狀態行出現，`{detail}` 含 `pathDeclarationNonDomainMalformed`（zh「非 domain 路徑清單格式錯誤」）而非 `pathDeclarationNonDomainMissing`；破洞報告多一筆 `parseFailure`（原因碼 `nonDomainPathsMalformed`），破洞數比 A3 多 1。與 A3（不出現、破洞數不變）及「刪除該檔」（`{detail}` 為 Missing、破洞數同 A3）兩組對照皆不同（UC-02 v1.7 驗收；SPEC-006 FR-10 規則 4） |

## 3. 5b 內圈：逐單元測試案例

案例編號：`L`＝Layout、`V`＝domain_view、`P`＝路徑定位、`R`＝報告頁宣告狀態行、`K`＝元件。
「守衛」標記代表對象是判定或攔截邏輯，已附正向對照輸入（E2）。

### 3.1 Layout：泳道布局規則

> **v1.38 移轉（R1）**：列序規則權威改為 SPEC-007 FR-13。L1-1～L1-3、L2-1～L2-4 與 L2-5 的排序部分移至
> `docs/test-design/SPEC-007-test-design.md` G13（對照：L1-1→G13-1、L1-2→G13-2、L1-3→G13-3、L2-1→G13-4、
> L2-2→G13-5、L2-3→G13-7、L2-4→G13-8、L2-5 排序→G13-9），Layout 實作不再承擔這些案例，下表保留原文供追溯，
> 標「已移」者不在本檔實作。Layout 留下 L1-4、L2-5 的畫邊部分、L2-6，另加 L8（列序來源）。

#### L1 列序：層推導 max+1（SPEC-001〈泳道布局規則〉列集合與列序；domain map §6 1c／1a）

**測試檔**：`test/unit/layout/lane_order_test.dart`，group `層推導`（L1-1～L1-3 已移，僅 L1-4 留在本檔）

| # | Given | Then |
|---|-------|------|
| L1-1 | 本專案依賴邊（快照） | 層：`schema`、`workspace`=0；`corpus`、`history`=1；`diagnostics`、`graph`、`ticketdetail`=2；`layout`=3 |
| L1-2（E1：max 對 min） | A→{B, C}、C→B、B 無出邊 | A 為 L2（max+1）而非 L1；最長路徑公式與最短路徑公式在此輸入下結果不同 |
| L1-3 | `history` 只依賴 `workspace` | `history`=L1（2026-10-08 裁決第 1 項的回歸點） |
| L1-4（v1.37 改寫） | 單一 bundle、無邊（flutter_balance） | 唯一 bundle 為 L0；選定 UC 無 `traverses` 異常步驟時總列數 2（DomainBundle 數＋1），有時 3（＋2，見 L7-4） |

#### L2 列序：同層 code point 排序與推不出層者

**測試檔**：同上，group `同層排序與結構異常`（L2-1～L2-4 已移；L2-5 只留「不產生 `ghost` 列、指向 `ghost` 的邊不畫」；L2-6 留）

| # | Given | Then |
|---|-------|------|
| L2-1 | 同層 `graph`、`diagnostics`、`ticketdetail` | 序為 `diagnostics`、`graph`、`ticketdetail` |
| L2-2（E1：code point 對 locale） | 同層 `b`、`B`、`a-z`、`a_z` | 依 Unicode code point：`B`、`a-z`、`a_z`、`b`；locale 排序會把 `B` 排在 `a-z` 之後，斷言結果與 locale 序不同 |
| L2-3 | 同上輸入，App locale 切 zh 與 en 各跑一次 | 兩次結果逐值相同 |
| L2-4（守衛） | X→Y、Y→X 成環，另有正常 bundle Z | Z 依層排序；X、Y 不消失，依 code point 接在最後；正向對照為 L1-1（無環時無 bundle 接在最後） |
| L2-5（守衛） | X 的 `depends_on_bundles` 含未宣告的 `ghost` | X 接在最後；不產生 `ghost` 列；指向 `ghost` 的邊不畫 |
| L2-6 | 列序與選定 UC | 對本專案 6 個 UC 各算一次列序，6 次結果相同 |

#### L3 主線與欄序（SPEC-001 主線、欄序條）

**測試檔**：`test/unit/layout/column_order_test.dart`

| # | Given | Then |
|---|-------|------|
| L3-1 | UC-02 快照 | 欄序 0 locate-domain … 6 inspect-steps（SPEC-001 期望值欄） |
| L3-2 | flutter_balance UC-01 | 欄序依 §1.2 表 |
| L3-3（E1：清單順序對 `next` 鏈） | 主線步 A、B、C 檔內順序為 A、C、B，但 `next` 鏈為 A→B→C | 欄序依檔內順序 A、C、B；沿 `next` 推導會得 A、B、C，斷言兩者不同 |
| L3-4 | 巢狀分支：B 的 `branch_from`=M，B2 的 `branch_from`=B，另有 B3 的 `branch_from`=M | M、B、B2、B3（B2 緊接 B 之後，再輸出 B3） |
| L3-5 | 每步驟恰一欄 | 欄號集合為 0..n-1、無重複、無缺號 |

#### L4 節點所屬列與「畫面」列

**測試檔**：`test/unit/layout/node_placement_test.dart`

| # | Given | Then |
|---|-------|------|
| L4-1 | UC-02 enter-from-ticket `traverses: [graph, ticketdetail]` | `graph`、`ticketdetail` 兩列欄 1 各一節點 |
| L4-2 | `traverses: []` | 只在「畫面」列一個節點 |
| L4-3（E1：精確比對，v1.37 改寫） | `traverses: ["Graph"]`，列鍵為 `graph`；對照組 `traverses: ["graph"]` | 前者不落 `graph` 列（不做大小寫轉換），因值全部未宣告而落「未定位」列（L7-1）；後者落 `graph` 列、無「未定位」列。兩組節點所在列不同（原 N2 已由 `0.5.0-W1-114` T1 裁決） |
| L4-4 | 「畫面」列 | 恆在最上；`kind: screen` 僅一列 |

#### L5 邊的來源與形狀

**測試檔**：`test/unit/layout/edge_shape_test.dart`

| # | Given | Then |
|---|-------|------|
| L5-1 | UC-02 flow-not-structured（同時帶 `next` 與 `return_to`） | 產生 switch-to-swimlane → flow-not-structured 與 flow-not-structured → locate-domain 兩條 |
| L5-2 | 目標欄 > 來源欄 | 直線 |
| L5-3（E1：形狀由欄號決定，不由欄位名） | `return_to` 指向欄號更大的步驟 | 直線；另一筆 `next` 指向欄號較小的步驟 → 弧線 |
| L5-4 | 目標欄 = 來源欄（自指） | 弧線（≤ 條件的邊界值） |
| L5-5 | 多列節點的步驟 | 邊端點為其最上方節點所在列 |
| L5-6 | flutter_balance | 4 弧線、8 直線（§1.2） |

#### L6 欄序無法輸出的步驟（結構異常接在最後）

**測試檔**：`test/unit/layout/column_order_test.dart`，group `結構異常`

| # | Given | Then |
|---|-------|------|
| L6-1（守衛） | 步驟 X 的 `branch_from` 指向不存在的 id | X 不消失，接在最後一欄之後；不畫 X 的 `branch_from` 邊；正向對照為 L3-1（無懸空時最後一欄為正常步驟） |
| L6-2（守衛） | Y、Z 互為 `branch_from` | 兩者依檔內順序接在最後；`branch_from` 邊照畫、形狀依欄號 |
| L6-3 | 懸空 X 與循環 Y、Z 同時存在 | 三者依檔內順序共同接在最後 |
| L6-4 | 步驟總數守恆 | 輸出欄數 = 輸入步驟數（L6-1～L6-3 各驗一次） |

#### L7 `traverses` 異常的步驟與「未定位」列（SPEC-001 v1.36／v1.37〈泳道布局規則〉；`0.5.0-W1-114` T1、`0.5.0-W1-114.1` NC-a；v1.37 新增）

**測試檔**：`test/unit/layout/node_placement_test.dart`，group `未定位列`
**輸入**：flow 子圖建構器的步驟帶 `traverses` 原值與 Graph 名稱解析結果（已宣告值集合）；Layout 只消費解析結果，不自行比對名稱、不讀缺陷清單

| # | Given | Then |
|---|-------|------|
| L7-1（守衛） | 步驟 S 的 `traverses: ["nope"]`、解析結果為空 | S 的節點只在「未定位」列（`kind: unplaced`）一個，不在任何 domain 列與「畫面」列；正向對照為 L4-1（全部已宣告時無「未定位」列） |
| L7-2（E1：缺鍵對 `[]`） | 步驟 S1 沒有 `traverses` 鍵；步驟 S2 `traverses: []` | S1 在「未定位」列、S2 在「畫面」列；兩者所在列不同（缺鍵不視同 `[]`） |
| L7-3 | 步驟 `traverses: ["graph", "nope"]`、解析結果 {`graph`} | 只在 `graph` 列一個節點；無「未定位」列；未宣告值不另放節點 |
| L7-4（E1：列只在有異常步驟時出現） | 同一組 bundle（N 個），UC-A 全部步驟已宣告、UC-B 有一步缺鍵 | UC-A 列數 N＋1、UC-B 列數 N＋2；兩次列集合除「未定位」列外逐值相同 |
| L7-5 | L2-4 的成環 bundle X、Y 與 L7-1 的步驟並存 | 列序為「畫面」、正常分層列、X、Y（推不出層者）、「未定位」；「未定位」恆為最末列 |
| L7-6（E1：欄號依清單順序，不接在最後） | 清單順序 a、u、b，u 缺鍵；對照組為 L6-1 的懸空步驟 | u 欄號 1（依清單順序），a、b 欄號 0、2；懸空步驟依 L6-1 接在最後一欄之後。兩類異常的欄號規則不同 |
| L7-7 | 兩個 DomainBundle `id` 不同、`domain` 皆為 `corpus`（解析器排除，解析結果為空）；步驟 `traverses: ["corpus"]` | 步驟落「未定位」列；兩個 DomainBundle 各自成列（列數不因重複而減少），兩列皆無節點（SPEC-007 FR-11〈重複 domain 宣告〉） |
| L7-8 | flutter_balance UC-01 快照 | 九個節點全在「未定位」列、欄號 0～8 依 §1.2 表；邊與 L5-6 相同（4 弧線、8 直線） |
| L7-9 | 步驟總數守恆 | 輸出節點所在步驟集合等於輸入步驟集合（L7-1～L7-8 各驗一次，異常步驟不消失） |

#### L8 列序來源：向 Graph 取、不自行推導（SPEC-001 v1.38〈泳道布局規則〉列集合與列序；`0.5.0-W1-114.2` R1；v1.38 新增）

**層**：domain unit（Layout）。**測試檔**：`test/unit/layout/lane_order_test.dart`，group `列序來源`
**輸入**：以 provider override／建構子注入 Graph FR-13 查詢的替身，回傳指定的 DomainBundle 排序
**承接票**：Layout 列序票（§6.2 L1、L2、L8 列）

| # | Given | Then |
|---|-------|------|
| L8-1 | Graph 替身回傳本專案快照排序（G13-1 的期望值） | 列序為「畫面」、`schema`、`workspace`、`corpus`、`history`、`diagnostics`、`graph`、`ticketdetail`、`layout`，共 9 列 |
| L8-2（E1：取自 Graph 而非自行推導） | 同一組 DomainBundle 與依賴邊，Graph 替身回傳一個刻意與分層＋code point 推導不同的排序（例：`layout`、`schema`、其餘依原序） | Layout 的 DomainBundle 列序逐值等於替身回傳的排序；與 L8-1 的列序不同。若 Layout 自行推導，兩次結果會相同，斷言因此翻紅 |
| L8-3 | L8-1 的輸入另有一個 `traverses` 缺鍵的步驟 | 列序為「畫面」、Graph 排序、「未定位」；Graph 排序段不插入、不移除任何列（與 L7-5 的末列規則一致） |
| L8-4（E1：推不出層者的位置由 Graph 決定） | Graph 替身回傳的排序末兩個為成環的 X、Y | Layout 依原樣放在 Graph 排序段末尾、「未定位」之前；Layout 不另外判斷環，替換替身使 X、Y 排在前段時 Layout 跟著改 |

L8 只驗「列序來自 FR-13 回傳值」。分層與 code point 的規則本身由 SPEC-007 G13 承擔，兩者不重複斷言同一規則。

#### L9 「給定一列，回傳欄號最小的節點」查詢（`docs/spec/layout/domain-map.md` §3；SPEC-001 v1.38〈「在泳道中檢視」跳轉目標〉；`0.5.0-W1-114.2` J2；v1.38 新增）

**層**：domain unit（Layout 公開面）。**測試檔**：`test/unit/layout/lane_first_node_test.dart`
**輸入**：選定 UC 的 flow 子圖與 Graph 名稱解析結果（同 L3～L7）
**承接票**：Layout 欄序與節點票（§6.2 L3～L7、L9 列）

| # | Given | Then |
|---|-------|------|
| L9-1 | UC-04 快照，列 `graph` | 回傳 UC-04 欄號最小且 `traverses` 含 `graph` 的步驟所在節點（原 V3-1 的期望值，改由 Layout 承擔） |
| L9-2（E1：欄號對清單順序，原 V3-2） | 列 X 有兩個步驟節點，檔內順序在後者因分支插欄而欄號較小（L3-4 的形態） | 回傳欄號較小者；取清單順序第一步會得另一個節點，斷言兩者不同 |
| L9-3 | 一個步驟 `traverses: [graph, corpus]`（多列節點），另一步只含 `corpus` 且欄號較大 | 列 `corpus` 回傳前者在 `corpus` 列的節點；回傳的是指定列上的節點，不是該步驟最上方節點（L5-5 的邊端點規則不適用於此查詢） |
| L9-4 | 列 X 存在但無節點（L2-6 的空列，或 L7-7 的重複宣告列） | 回傳值可與「有節點」區分（回傳形態見 §6.1 NC-4） |

### 3.2 domain_view：跳轉目標（V1、V2 已移至 SPEC-007 G12）

原 V1（三值判定式）、V2（依賴路徑）依 `0.5.0-W1-114` 用戶裁決 O1 改歸 Graph FR-12，案例內容不變、
編號改為 G12，見 `docs/test-design/SPEC-007-test-design.md` §3.2 G12。畫面層只顯示 FR-12 回傳值，
本檔僅保留畫面消費的斷言（ITD1、ITD3）與 V3。

#### V3 「在泳道中檢視」跳轉目標（v1.38 改寫：J2，NC-2 已處置）

**層**：widget（domain_view 畫面，Graph FR-12 與 Layout L9 查詢皆以替身注入）。
**測試檔**：`test/unit/screens/domain_view/indirect_dependency_test.dart`，group `跳轉目標`
**承接票**：domain_view 畫面票（§6.2 第 3 組）。「欄號最小」的規則本身由 L9 承擔，V3 只驗畫面的呼叫參數與落點，不重算欄號

| # | Given | Then |
|---|-------|------|
| V3-1（v1.38 改寫） | UC-04 × `schema` 間接依賴格；FR-12 替身回傳 `graph → corpus → schema`、`ticketdetail → corpus → schema`；L9 替身對 `graph` 回傳節點 N | 畫面以 `graph`（第一條路徑的來源）呼叫 L9 查詢恰一次，跳到 `graph` 列的節點 N |
| V3-2（E1：取第一條路徑，v1.38 改寫；原 V3-2 的欄號鑑別移至 L9-2） | 同一格，FR-12 替身改回傳 `ticketdetail → corpus → schema` 在前 | 畫面以 `ticketdetail` 呼叫 L9，落點改為 `ticketdetail` 列；與 V3-1 的落點不同（證明畫面不自行排序路徑） |
| V3-3 | 直接貫穿格 | 目標列為該格 domain（既有行為，SPEC-001 v1.38 原文「直接貫穿格維持跳到該格 domain 所在列」）；畫面不呼叫 FR-12 的依賴路徑 |
| V3-4（E1：畫面不自行組合，v1.38 新增） | V3-1 的輸入，但 L9 替身對 `graph` 回傳的節點 N′ 刻意不是欄號最小者 | 畫面落點為 N′；若畫面自行依欄號挑節點會得另一節點，斷言翻紅 |

#### F1 flow 區塊解析失敗的呈現（SPEC-001 §1〈flow 區塊解析失敗的泳道呈現〉、§2「flow 未結構化」；`0.5.0-W1-114` F1、`0.5.0-W1-114.1` NC-f／NC-g；v1.37 新增）

**測試檔**：`test/unit/screens/domain_view/swimlane_parse_failure_test.dart`（F1-1～F1-5）、
`test/unit/screens/uc_flow/flow_parse_failure_test.dart`（F1-6、F1-7）
**輸入**：選定 UC 的步驟清單（空或非空）與該 UC 是否有 EVT-CORPUS-004 破洞（原因碼 `flowBlockMalformed`），以 provider override 注入

| # | Given | Then |
|---|-------|------|
| F1-1 | 選定 UC 步驟清單非空、有一筆該 UC 的 flow 解析失敗破洞；泳道模式 | 狀態為「正常 · 泳道」；`SwimlaneGrid` 之上有一個 `AppText.caption`，文字為 `swimlaneFlowParseFailedHint`；泳道照常渲染步驟 |
| F1-2（E1） | F1-1 的同一 UC，但無解析失敗破洞 | 狀態相同、泳道相同，但無該 caption；與 F1-1 渲染結果不同，差異只在提示 |
| F1-3 | 選定 UC 步驟清單為空、有解析失敗破洞；泳道模式 | 狀態為「泳道 · flow 未結構化」；`EmptyState.section` 訊息為 `flowParseFailedMessage`，不渲染泳道列；提供「開啟原始檔」動作 |
| F1-4（E1：無區塊對區塊壞掉） | 選定 UC 步驟清單為空、無解析失敗破洞 | 同為「泳道 · flow 未結構化」，訊息為 `flowUnstructuredMessage`；與 F1-3 訊息不同、狀態相同 |
| F1-5 | F1-3 按「開啟原始檔」 | 觸發外部開啟該 UC 原始檔；畫面狀態不變（不計為退出路徑） |
| F1-6 | UC Flow 視圖，F1-3 的輸入 | 「flow 未結構化」狀態的訊息為 `flowParseFailedMessage`（與泳道同 key，NC-f） |
| F1-7（E1） | UC Flow 視圖，F1-4 的輸入 | 訊息為「尚未填寫結構化 flow」原文案；與 F1-6 不同 |

F1 不設外圈：兩份語料皆無 flow 區塊解析失敗的 UC（SPEC-006 FR-09 驗收實測），外圈無資料可驅動。
狀態總數不變由既有狀態列舉測試承擔，本群組不新增狀態。

### 3.3 路徑定位：五狀態與整體未宣告（UC-02 v1.6 表）

**測試檔**：`test/unit/graph/path_declaration_state_test.dart`（實作屬 `0.5.0-W1-096.5`）

#### P1 五種狀態

| # | 宣告狀況 | 路徑 | Then |
|---|---------|------|------|
| P1-1 | 兩者皆有 | 命中 bundle 模式 | 命中 domain |
| P1-2 | 兩者皆有 | 命中非 domain 清單 | 非 domain 層 |
| P1-3 | 兩者皆有 | 兩者皆未命中 | 無法定位（計入 `unlocatable`） |
| P1-4 | 只有 `path_patterns` | 未命中 | 非 domain 未宣告（不計入 `unlocatable`） |
| P1-5 | 只有非 domain 清單 | 未命中 | domain 未宣告 |
| P1-6 | 兩者皆無 | 任何路徑 | 不逐張判定；回報整體「未宣告路徑」 |
| P1-7（E1：格式錯誤視為缺席，v1.37 新增） | 只有 `path_patterns`，非 domain 清單狀態為「格式錯誤」；對照組為狀態「缺席」 | 未命中 | 兩組皆為非 domain 未宣告，逐路徑分類完全相同；比對器另回報的非 domain 側宣告狀態分別為「格式錯誤」與「缺席」，兩者不同（UC-02 v1.7、SPEC-006 FR-10 規則 4） |

#### P2 部分宣告逐 bundle 判定

| # | Given | Then |
|---|-------|------|
| P2-1 | 非 domain 清單有、8 個 bundle 中 7 個宣告 | 未命中路徑為 domain 未宣告，而非無法定位 |
| P2-2（E1：補齊最後一個） | 同上，第 8 個 bundle 補 `path_patterns: []` | 同一路徑改為無法定位；斷言與 P2-1 不同（`[]` 算已宣告） |
| P2-3（E1：缺席對 `[]`） | 第 8 個 bundle 欄位缺席 | 與 P2-1 同結果；與 P2-2 不同 |
| P2-4 | 非 domain 清單缺席、部分 bundle 宣告（v1.6 新增列） | 未命中路徑為 domain 未宣告（不是非 domain 未宣告） |

#### P3 逐路徑顯示與聚合

| # | Given | Then |
|---|-------|------|
| P3-1 | 一張票 `where.files` 含命中 `graph`、命中非 domain、domain 未宣告各一 | 逐路徑各回報各自狀態，不做整票歸類 |
| P3-2 | 同上 | 矩陣高亮集合 = 命中 domain 的聯集 {`graph`} |
| P3-3 | 票列表摘要 | 任一路徑命中 domain 即判可定位 |
| P3-4 | 受影響路徑數 | 等於標為兩種「未宣告」的路徑數；兩側皆無時不提供路徑數 |
| P3-5 | flutter_balance | 整體「未宣告路徑」 |

#### P4 比對語意：精確比對與同字串歸屬（UC-02 v1.8〈ticket 定位〉；`0.5.0-W1-114.3` 用戶裁決 C3′、T1；v1.38 新增）

**層**：domain unit（路徑比對器）。**測試檔**：同 P1～P3，group `比對語意`
**承接票**：`0.5.0-W1-096.5`（UC-02 v1.8 兩條新驗收的承接；比對器輸入由 SPEC-006 FR-10 規則 2b 保證含格式違規字串，見 SPEC-006-test-design C15-7、C15-8）
**共通宣告**：兩側皆有宣告（P1-1 的形態），使「未命中」落在可觀測的「無法定位」

| # | Given | 路徑 | Then |
|---|-------|------|------|
| P4-1（守衛：空字串不命中，UC-02 驗收「空字串」條） | bundle `graph` 的 `path_patterns: [""]` | `lib/a.dart` | 不歸 `graph`，為無法定位；正向對照：同路徑在 `path_patterns: ["lib/"]` 時歸 `graph`。把空字串當前綴比對的實作會命中全部路徑，斷言翻紅 |
| P4-2（守衛：空字串在非 domain 側同樣不命中） | 非 domain 清單 `["", "docs/a/"]`（SPEC-006 C15-7 的清單） | `src/b.dart` | 不歸非 domain，為無法定位；`docs/a/x.md` 歸非 domain（其餘元素照常生效） |
| P4-3（守衛：`/docs/` 不命中，UC-02 驗收「`/docs/`」條） | 非 domain 清單 `["/docs/"]` | `docs/a.md` | 不歸非 domain，為無法定位；正向對照：清單 `["docs/"]` 時歸非 domain。比對前去除前導 `/` 的實作會命中，斷言翻紅 |
| P4-4（E1：不以 `/` 結尾為精確比對） | bundle `graph` 的 `path_patterns: ["lib/a.dart"]` | `lib/a.dart`、`lib/a.dart.bak`、`lib/a.dartx` | 第一條歸 `graph`；後兩條為無法定位。前綴比對會使三條皆歸 `graph`，斷言結果與後者不同 |
| P4-5（守衛：其餘上游格式違規值不命中） | 非 domain 清單 `["./docs/", "docs/../lib/", "docs/*.md"]` | `docs/a.md`、`lib/a.dart` | 兩條皆為無法定位；正向對照為 P1-2（合法值命中） |
| P4-6（T1，UC-02 驗收「同字串」條） | bundle `graph` 的 `path_patterns` 與非 domain 清單皆含 `docs/x/` | `docs/x/a.md` | 歸 `graph`；比對器不另回報衝突（衝突由 `doc validate` 回報） |
| P4-7（E1：T1 只在等長時生效） | bundle `graph` 宣告 `docs/x/`，非 domain 清單宣告 `docs/x/y/` | `docs/x/y/a.md` | 歸非 domain（最長前綴優先）；與 P4-6 的歸屬不同，證明「歸 domain」不是無條件的 domain 優先 |
| P4-8（E1：T1 的對照組） | 只有非 domain 清單含 `docs/x/`，bundle 不含 | `docs/x/a.md` | 歸非 domain；與 P4-6 的歸屬不同 |

### 3.4 報告頁宣告狀態行（SPEC-001 §5、SPEC-004 §4.0.6）

**測試檔**：`test/unit/screens/gap_report_declaration_line_test.dart`

| # | Given | Then |
|---|-------|------|
| R1-1 | 5／8 宣告、非 domain 清單有、受影響 12 條 | zh「路徑宣告不完整：已宣告 5／8 個 domain（影響 12 條路徑）」 |
| R1-2 | 8／8 宣告、非 domain 清單缺 | `{detail}` 只含 `pathDeclarationNonDomainMissing` |
| R1-3 | 5／8、清單缺 | 兩片段以「、」連接；en 以 ", " 連接 |
| R1-4 | 兩側皆無 | `pathDeclarationNoneLine`，不含數字 |
| R1-5（守衛） | 兩側完整宣告 | 不顯示；正向對照為 R1-1（有缺口即顯示） |
| R1-6 | 狀態列 × 宣告缺口 | 無破洞、有破洞、無法判定破洞三列皆顯示；掃描中與專案未就緒不顯示 |
| R1-7（E1：不計入破洞） | 同一語料，宣告缺口有與無各算一次 | 破洞數、有／無破洞判定相同；兩種未宣告不出現在任何分節 |
| R1-8 | 元件 | 為 `AppText`，位於頁首說明區 |
| R1-9（v1.37 新增） | 8／8 宣告、非 domain 清單格式錯誤 | `{detail}` 只含 `pathDeclarationNonDomainMalformed`（zh「非 domain 路徑清單格式錯誤」／en「non-domain path list is malformed」），不含 `pathDeclarationNonDomainMissing` |
| R1-10（E1：格式錯誤對缺席，v1.37 新增） | R1-9 與 R1-2 兩組輸入（只差清單狀態） | 兩行文字不同；受影響路徑數相同（分類相同，P1-7） |
| R1-11（v1.37 新增） | 5／8、清單格式錯誤 | 兩片段以「、」連接，第二片段為格式錯誤文字（同 R1-3 的連接規則） |

### 3.5 元件（SPEC-004）

**測試檔**：既有 `test/unit/components/` 一比一檔（加 group，不新增檔）

| # | 元件 | Given | Then |
|---|------|-------|------|
| K1-1 | 4.37 `MatrixGrid` | `domainName: "ticketdetail"` 與未知值 `"foo-bar"` | 列首逐字顯示原值；zh／en 皆同 |
| K1-2 | 4.37 | 同一列 | 列首不出現任何 `swimlaneScreenLaneName` 文字；矩陣無「畫面」列 |
| K2-1 | 4.38 `SwimlaneGrid` | 9 列 `lanes`、首列 `kind: screen` | 9 列依輸入順序；首列列首為 `swimlaneScreenLaneName`（zh「畫面」／en「Screen」）；domain 列為原值 |
| K2-2 | 4.38 | 「畫面」列 | 列首不可點、不受 `laneHighlight` 高亮 |
| K2-3（E1） | 4.38 `edges` | 一條 `straight`、一條 `arc` vs 空 `edges` | 前者各渲染一條且形狀可區分；後者無邊；兩者渲染結果不同 |
| K2-4（E1，v1.37 改寫） | 4.38 | `lanes` 長度 2（「畫面」＋一個 domain）與 9 各一 | 各依輸入渲染 2 列與 9 列；列數取自輸入而非寫死 9（N4 已裁決：9 為本專案期望值，slot 約束為 DomainBundle 數＋1，有未定位步驟時＋2） |
| K2-5（v1.37 新增） | 4.38 | 末列 `kind: unplaced` 帶兩個節點 | 末列列首為 `swimlaneUnplacedLaneName`（zh「未定位」／en「Unplaced」）；節點依給定欄號渲染；domain 列首仍為原值 |
| K3-1（E1） | 4.19 `RelationItem` | `isProposed: true` vs `false` | true：尾端一個 tone `warning` 的 `Badge.category`，文字 zh「暫定」／en「Proposed」，朗讀 `relationItemProposedA11yLabel`；false：無 badge、朗讀 `relationItemA11yLabel` |
| K3-2 | 4.19 | 最長測試文案的 `id` | `id` 截斷時 badge 不截斷、不換行 |
| K3-3 | 4.19 | 朗讀 | badge 併入 chip 標籤，不另朗讀 |
| K4-1 | §4.0.6 | 四個 `pathDeclaration*` key、`relationProposedLabel`、`relationItemProposedA11yLabel`、`swimlaneScreenLaneName` | zh／en ARB 皆存在且值與 §4.0.6 表逐字一致 |
| K4-2（v1.37 新增） | §4.0.6 | `pathDeclarationNonDomainMalformed`、`swimlaneFlowParseFailedHint`、`flowParseFailedMessage`、`swimlaneUnplacedLaneName` | zh／en ARB 皆存在且值與 SPEC-004 v1.77 §4.0.6 表逐字一致 |

## 4. 覆蓋矩陣

### 4.1 規則 ↔ 測試

| 規則（規格位置） | 5a | 5b |
|----------------|----|----|
| 列集合與列序（SPEC-001 §1；v1.38 列序來源改 Graph） | ITD2-A1、A4、A5 | L1-4、L2-5（畫邊）、L2-6、L8；規則本身為 SPEC-007 G13 |
| 列鍵比對、列首原值（SPEC-001 §1；SPEC-004 4.37／4.38） | ITD1-A3 | L4-3、K1、K2-1 |
| 主線、欄序（SPEC-001 §1） | ITD2-A2、A5 | L3 |
| 節點所屬列、「畫面」列 | ITD2-A2 | L4、K2-2 |
| 邊的來源、形狀、端點 | ITD2-A3、A5 | L5、K2-3 |
| 欄序無法輸出的步驟 | — | L6 |
| `traverses` 異常的步驟與「未定位」列（v1.36／v1.37） | ITD2-A5 | L4-3、L7、K2-5 |
| 間接依賴判定式 | ITD1-A1、A2、A4 | SPEC-007 G12（原 V1） |
| 依賴路徑（v1.38 排序依 FR-13） | ITD3-A1、A2、A4 | SPEC-007 G12（原 V2）、G13-13 |
| 跳轉目標（v1.38 J2） | ITD3-A3 | L9（欄號最小節點查詢）、V3（畫面呼叫參數與落點） |
| flow 區塊解析失敗的呈現（v1.36／v1.37） | — | F1、K4-2 |
| ticket 定位五狀態與整體未宣告（UC-02 v1.7） | ITD4-A1、A2、A5 | P1（含 P1-7）、P2、P3 |
| 比對語意：精確比對與同字串歸 domain（UC-02 v1.8 C3′、T1） | —（兩份語料皆無此類宣告值） | P4 |
| 宣告狀態行（SPEC-001 §5；含格式錯誤） | ITD4（含 A5） | R1（含 R1-9～R1-11）、K4-1、K4-2 |
| proposed 標記（SPEC-004 4.19；SPEC-001 §6） | ITD3-A5 | K3、K4-1 |

L6 不在外圈：兩份語料皆無懸空與循環（SPEC-001 期望值欄），外圈無資料可驅動。L7 由 ITD2-A5
（flutter_balance 九步缺鍵）在外圈驅動。F1 不在外圈：理由見 F1 節末。

### 4.2 Layout 不變式 ↔ 測試

| 不變式（`docs/spec/layout/domain-map.md`） | 測試 |
|------------------------------------------|------|
| 列序不寫死 domain 名、換 UC 不變 | L1-4、L2-6、L8-2、ITD2-A4、A5；SPEC-007 G13-11 |
| 結構異常不消失、接在最後 | L2-5、L6、L7-1、L7-5、L7-9、L8-4；SPEC-007 G13-8～G13-10 |
| 只依賴 Graph | §1.4 import 檢查；L7 只消費 Graph 解析結果；L8 只消費 Graph 排序 |
| 公開面「給定一列，回傳欄號最小的節點」（v1.38） | L9 |

## 5. 測試案例統計

| 單元／圈 | 群組 | 案例數 |
|---------|------|-------|
| 5a 外圈 | IT-D1～IT-D4 | 19（v1.37 加 ITD3-A5、ITD4-A5；ITD2-A5 改寫不計增） |
| Layout | L1～L9 | 39（v1.37 為 38；v1.38 移出 L1-1～L1-3、L2-1～L2-4 共七案至 SPEC-007 G13，加 L8 四案、L9 四案） |
| domain_view | V3 | 4（V1、V2 共 12 案移至 SPEC-007 G12；v1.38 加 V3-4，V3-1、V3-2 改寫不計增） |
| flow 解析失敗呈現 | F1 | 7 |
| 路徑定位 | P1～P4 | 24（加 P1-7；v1.38 加 P4 八案） |
| 報告頁宣告狀態行 | R1 | 11（加 R1-9～R1-11） |
| 元件 | K1～K4 | 12（加 K2-5、K4-2；K2-4 改寫不計增） |
| 合計 | | 116 |

守衛型案例（已附正向對照）：L2-5、L6-1、L6-2、L7-1、R1-5、P4-1、P4-2、P4-3、P4-5（L2-4 已移為 SPEC-007 G13-8）。
E1 對照：ITD1-A4、ITD2-A5、ITD3-A4、ITD3-A5、ITD4-A3、ITD4-A5、L3-3、L4-3、L5-3、L7-2、L7-4、L7-6、
L8-2、L8-4、L9-2、V3-2、V3-4、F1-2、F1-4、F1-7、P1-7、P2-2、P2-3、P4-4、P4-7、P4-8、R1-7、R1-10、K2-3、K2-4、K3-1
（L1-2、L2-2 已移為 SPEC-007 G13-2、G13-5）。

## 6. 待決與交接

### 6.1 NeedsContext

前輪 N1～N6 的處置（`0.5.0-W1-114` Solution）：

| 項 | 處置 | 本檔落點 |
|----|------|---------|
| N1 | 外圈預期值取凍結快照；快照凍結為 Step 6 一張票 | §1.2 不變；§6.2「快照凍結」列 |
| N2＋N3 | T1：值全部未宣告或缺鍵者置於「未定位」列並報缺陷；外圈加 proposed 標記斷言 | L4-3、L7、ITD2-A5、ITD3-A5 |
| N4 | 9 為本專案期望值；slot 約束為 DomainBundle 數＋1（有未定位步驟時＋2） | K2-4、L1-4 |
| N5 | O1：間接依賴歸 Graph FR-12 | V1、V2 移至 SPEC-007 G12 |
| N6 | F1 | F1 |

本輪新增（`0.5.0-W1-114.2`，未在裁決內，不自行填補）：

- **NC-1**：FR-12 依賴路徑的排序規則引用「泳道列序」（SPEC-001〈間接依賴格的詳情卡：依賴路徑〉排序列），而列序由 Layout 推導（分層＋code point）。依系統層 §2 Layout 依賴 Graph，Graph 不能反向取用 Layout 的列序。Graph 在 FR-12 內自行以相同公式重算列序，或排序改由畫面層以 Layout 列序重排，未裁決。影響 G12 中原 V2-1、V2-3 的排序斷言由哪個單元承擔。
- **NC-2**：V3「在泳道中檢視」跳轉目標的歸屬。SPEC-007 FR-12 只回傳關係種類與依賴路徑，不含跳轉目標；跳轉目標需要依賴路徑第一行的來源（FR-12）與該 UC 的欄號（Layout 欄序），兩者分屬兩個單元。票面寫「V1～V3 改歸 Graph FR-12」，但 FR-12 條文不涵蓋 V3。本輪 V3 留在本檔、測試檔路徑暫放 `test/unit/screens/domain_view/`，待裁決是否改歸 Graph（須擴充 FR-12）或維持畫面層組合。
v1.38 處置（`0.5.0-W1-114.2` 用戶裁決，SPEC-001 v1.38、SPEC-007 v1.18）：

- **NC-1（已處置，R1）**：分層與層內排序歸 Graph FR-13，FR-12 依其排序、Layout 向 Graph 取列序。落點 SPEC-007 G13、G12-7／G12-9 改寫、本檔 L8。
- **NC-2（已處置，J2）**：跳轉目標由 Layout 公開面「給定一列，回傳欄號最小的節點」查詢取得，畫面以 FR-12 第一條路徑的來源呼叫。落點 L9、V3 改寫。

- **NC-3**：F1-3 在路徑查詢不可用時的呈現（SPEC-006 FR-08：EVT-CORPUS-004 的破洞照常產生、同時回報「無法判定」）。泳道 F1 只以「有無解析失敗破洞」為輸入，與無法判定並存時是否仍顯示解析失敗文案未明寫；本輪 F1 不設此組合。

本輪新增（`0.5.0-W1-114.4`，未在裁決內，不自行填補）：

- **NC-4**：Layout「給定一列，回傳欄號最小的節點」在該列無節點時的回傳未定義（`docs/spec/layout/domain-map.md` §3、SPEC-001 v1.38 皆未寫）。間接依賴的來源 X 依定義被 UC 直接貫穿，正常情況下列上必有節點；但 X 為重複宣告 domain（L7-7，兩列皆無節點）或 FR-12 與 Layout 讀到不同輪掃描結果時可能為空。L9-4 只斷言可與「有節點」區分；畫面遇空結果的落點（停在列首、不跳轉、提示）未定，V3 本輪不設此組合。
- **NC-5**：Graph FR-13 回傳「圖不可用」時 Layout 列序的行為未寫。泳道畫面在建圖不可用時是否已被上游阻擋狀態攔下（不進入 Layout）未在 SPEC-001 §1 與 Layout domain map 明寫；L8 本輪不設此組合。
- **NC-6**：UC-02 v1.8 驗收「宣告值為空字串或 `/docs/` 時不命中」的括號理由寫「不得把不以 `/` 結尾的值當前綴比對」，但 `/docs/` 以 `/` 結尾，其不命中的理由是前導 `/`（相對專案根的路徑不以 `/` 開頭），不是精確比對。P4-3 依「`/docs/` 不命中」的結論寫斷言，不依括號理由；條文是否補一句由規格擁有者決定。

### 6.2 實作單元與承接票對照（Step 6）

| 案例群組 | 實作單元 | 承接票 | 依賴 |
|---------|---------|-------|------|
| L1-4、L2-5（畫邊）、L2-6、L8（v1.38） | Layout（列序組裝，向 Graph 取列序） | 待 Step 6 建票 | Graph FR-13 票（SPEC-007 G13；L8 以替身測，不阻擋開工） |
| L1-1～L1-3、L2-1～L2-4 | 已移至 SPEC-007 G13 | 見 SPEC-007-test-design §7 G13 | — |
| L3～L6 | Layout（欄序、節點、邊） | 待 Step 6 建票 | `0.5.0-W1-001.4`（flowOf） |
| L7 | Layout（節點、「未定位」列） | 待 Step 6 建票（併 L3～L6） | `0.5.0-W1-001.4`、`0.5.0-W1-001.5`（解析結果） |
| L9（v1.38） | Layout（欄號最小節點查詢） | 待 Step 6 建票（併 L3～L7，共用欄序結果） | 同 L3～L7 |
| V1、V2 | Graph FR-12 | 見 SPEC-007-test-design §7 G12 | — |
| V3（v1.38 改寫） | domain_view（畫面呼叫 FR-12 與 L9） | 待 Step 6 建票（第 3 組） | Graph FR-12 票、Layout L9 票（以替身測，不阻擋開工） |
| P4（v1.38） | 路徑比對器 | `0.5.0-W1-096.5` | `0.5.0-W1-123`（非 domain 清單照收字串，SPEC-006 C15-7） |
| F1 | domain_view／UC Flow 畫面（EVT-004 接畫面） | 待 Step 6 建票 | `0.5.0-W1-001.3`（EVT-CORPUS-004）、`0.5.0-W1-119`（`parseFailure` 破洞） |
| P1～P3（含 P1-7） | 路徑比對器 | `0.5.0-W1-096.5` | `0.5.0-W1-096.7`（非 domain 清單三態與格式錯誤狀態） |
| R1（含 R1-9～R1-11）、K4-1／K4-2 的 `pathDeclaration*` | Diagnostics／破洞報告頁 | `0.5.0-W1-119` | `0.5.0-W1-096.5`、`0.5.0-W1-096.7` |
| K1 | components（`MatrixGrid`） | 待 Step 6 建票 | 無 |
| K2（含 K2-4、K2-5）、K4-1 `swimlaneScreenLaneName`、K4-2 `swimlaneUnplacedLaneName` | components（`SwimlaneGrid`） | 待 Step 6 建票 | 無 |
| K3、K4-1 `relation*` | components（`RelationItem`） | 待 Step 6 建票（`0.5.0-W1-114` PM 處置 K3：元件改動不在 `0.5.0-W1-103.2`） | `0.5.0-W1-103.2`（`layer` 回傳） |
| K4-2 `swimlaneFlowParseFailedHint`、`flowParseFailedMessage` | 畫面 ARB | 待 Step 6 建票（併 F1） | 無 |
| IT-D1～IT-D3（含 ITD2-A5 改寫、ITD3-A5） | 外圈 | 待 Step 6 建票 | 以上 Layout、Graph FR-12、components、快照凍結 |
| IT-D4（含 ITD4-A5） | 外圈 | 待 Step 6 建票 | `0.5.0-W1-096.5`、`0.5.0-W1-096.7`、`0.5.0-W1-119` |
| 快照凍結 | 測資 | 待 Step 6 建票 | 無 |

**Step 6 建議分組**（待建票者，依實作單元分組，各組一張實作票）：

1. Layout：L1-4、L2-5、L2-6、L3～L9（可再依列序組裝 L1-4／L2-5／L2-6／L8 與欄序、節點、查詢 L3～L7／L9 拆兩張，群組間無共用 mutable 狀態）
2. Graph 間接依賴與分層排序（FR-12、FR-13）：SPEC-007 G12（原 V1、V2）、G13（原 L1-1～L1-3、L2-1～L2-4）
3. domain_view／UC Flow 畫面：V3、F1、K4-2 的兩個解析失敗 key
4. components：K1、K2、K3、K4-1 的 `swimlaneScreenLaneName` 與 `relation*`、K4-2 的 `swimlaneUnplacedLaneName`
5. 外圈與快照：快照凍結 → IT-D1～IT-D4

已有承接票者不再分組：P1～P4 → `0.5.0-W1-096.5`；R1 與 `pathDeclaration*` → `0.5.0-W1-119`。
各實作票驗收須含 §1.4 的 import 方向檢查。
