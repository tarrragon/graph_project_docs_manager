---
id: SPEC-001-test-design
title: "SPEC-001 v1.35／SPEC-004 v1.75／UC-02 v1.6 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-001
spec_version: "1.35"
related_specs: [SPEC-004, UC-02]
ticket: 0.5.0-W1-114
created: "2026-10-08"
updated: "2026-10-08"
---

# SPEC-001 v1.35／SPEC-004 v1.75／UC-02 v1.6 Phase 2 紅燈測試規格

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
不綁即時 repo（是否另需一條讀即時 repo 的檢查見 §6 N1）。

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
列：2 列（「畫面」＋`balance-sheet`），`balance-sheet` 為 L0（無出邊）。

### 1.3 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 泳道列序、欄序、節點所屬列、邊 | domain unit（Layout，純函式） | 輸入為 Graph 公開面的 flow 子圖與 DomainBundle 依賴邊值物件，測試內直接構造；不 mock Graph 內部 |
| 矩陣三值、依賴路徑、跳轉目標 | domain unit（domain_view 判定，純函式） | 輸入為 `traverses` 集合與依賴邊值物件 |
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
| flow 子圖建構器 | `test/helpers/spec001/flow_builder.dart` | 以 `(id, next, branch_from, return_to, traverses)` 列宣告出 flow 子圖值物件，保留檔內順序 | L3～L8、V3 |
| bundle 依賴建構器 | `test/helpers/spec001/bundle_graph_builder.dart` | 以 `domain → depends_on_bundles` 宣告出依賴邊集合 | L1、L2、V1～V3 |
| 真實語料快照載入器 | `test/helpers/spec001/corpus_snapshot.dart` | 讀凍結快照、交出 flow 子圖與依賴邊（經真實 Corpus＋Graph） | L1-1、L4-1、V1-1、IT-D1～IT-D3 |
| 路徑宣告建構器 | `test/helpers/spec001/path_declaration_builder.dart` | 宣告各 bundle 的 `path_patterns`（缺席／`[]`／清單）與非 domain 清單有無 | P1～P3、R1 |

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
| ITD2-A5（E1 對照） | flutter_balance 快照，選定 UC-01 | 切到泳道 | 2 列；欄序依 §1.2 表；4 條弧線、8 條直線。與 A1 為同一斷言器、不同語料，證明列數與欄序非寫死 |

### 2.3 IT-D3 間接格詳情卡與跳轉（UC-02 alt enter-from-ticket 的對面：矩陣點格）

| # | Given | When | Then |
|---|-------|------|------|
| ITD3-A1 | 本專案快照 | 點 UC-04 × `schema` | 詳情卡關係種類為間接依賴，依賴路徑恰兩行，依序 `graph → corpus → schema`、`ticketdetail → corpus → schema` |
| ITD3-A2 | 同上 | 點 UC-06 × `schema` | 依賴路徑恰一行 `corpus → schema` |
| ITD3-A3 | 同上 | UC-04 × `schema` 按「在泳道中檢視」 | 泳道選定 UC-04，定位到 `graph` 列中欄號最小且 `traverses` 含 `graph` 的節點 |
| ITD3-A4（E1 對照） | 同上 | 點 UC-04 × `graph`（直接貫穿）與 UC-04 × `history`（無關） | 兩者皆無依賴路徑區塊；直接貫穿格跳轉落在 `graph` 列（既有行為） |

### 2.4 IT-D4 破洞報告的宣告狀態行（UC-02 v1.6、SPEC-001 §5）

| # | Given | When | Then |
|---|-------|------|------|
| ITD4-A1 | flutter_balance 快照（兩側皆無宣告） | 進入破洞報告、掃描完成 | 頁首出現一行 `pathDeclarationNoneLine`（zh「本專案未宣告路徑」），不含路徑數 |
| ITD4-A2 | 本專案快照＋測試內補上 8 個 bundle 中 5 個的 `path_patterns`、無非 domain 清單 | 同上 | 一行 `pathDeclarationIncompleteLine`，`{detail}` 為「已宣告 5／8 個 domain、缺非 domain 路徑清單」，`{count}` 等於比對器回報的受影響路徑數 |
| ITD4-A3（E1 對照） | A2 的工作區再補齊全部宣告與非 domain 清單 | 同上 | 宣告狀態行不出現；破洞數與 A2 相同（宣告缺口不計入破洞數） |
| ITD4-A4 | A1 工作區 | 掃描中 | 宣告狀態行不出現 |

## 3. 5b 內圈：逐單元測試案例

案例編號：`L`＝Layout、`V`＝domain_view、`P`＝路徑定位、`R`＝報告頁宣告狀態行、`K`＝元件。
「守衛」標記代表對象是判定或攔截邏輯，已附正向對照輸入（E2）。

### 3.1 Layout：泳道布局規則

#### L1 列序：層推導 max+1（SPEC-001〈泳道布局規則〉列集合與列序；domain map §6 1c／1a）

**測試檔**：`test/unit/layout/lane_order_test.dart`，group `層推導`

| # | Given | Then |
|---|-------|------|
| L1-1 | 本專案依賴邊（快照） | 層：`schema`、`workspace`=0；`corpus`、`history`=1；`diagnostics`、`graph`、`ticketdetail`=2；`layout`=3 |
| L1-2（E1：max 對 min） | A→{B, C}、C→B、B 無出邊 | A 為 L2（max+1）而非 L1；最長路徑公式與最短路徑公式在此輸入下結果不同 |
| L1-3 | `history` 只依賴 `workspace` | `history`=L1（2026-10-08 裁決第 1 項的回歸點） |
| L1-4 | 單一 bundle、無邊（flutter_balance） | 唯一 bundle 為 L0；總列數 2 |

#### L2 列序：同層 code point 排序與推不出層者

**測試檔**：同上，group `同層排序與結構異常`

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
| L4-3（E1：精確比對） | `traverses: ["Graph"]`，列鍵為 `graph` | 不落 `graph` 列（不做大小寫轉換）；處置見 §6 N2 |
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

### 3.2 domain_view：間接依賴、依賴路徑、跳轉

#### V1 三值判定式（SPEC-001〈間接依賴判定式〉）

**測試檔**：`test/unit/screens/domain_view/indirect_dependency_test.dart`

| # | Given | Then |
|---|-------|------|
| V1-1 | 本專案快照 | 19／10／19 與 ITD1-A2 的 10 格明細 |
| V1-2 | 直接優先：UC 直接貫穿 Y 且 Y 亦自 X 可達 | 直接貫穿 |
| V1-3（E1：方向） | UC 貫穿 X，Y 依賴 X（Y 為上游） | 無關；把邊反向後同格變為間接，斷言兩次結果不同 |
| V1-4 | 3 跳可達（X→A→B→Y） | 間接（不限跳數） |
| V1-5 | UC 貫穿 X1、X2，兩者皆可達 Y | (Y, UC) 為一格間接（不重複計格） |
| V1-6 | flutter_balance | 間接 0 格 |

#### V2 依賴路徑

**測試檔**：同上，group `依賴路徑`

| # | Given | Then |
|---|-------|------|
| V2-1 | UC-04 × `schema` | 兩行、順序 graph 先 ticketdetail（列序） |
| V2-2（E1：排除經直接 domain） | UC-06 × `schema` | 一行 `corpus → schema`；未套排除規則時會多出 `diagnostics → corpus → schema`，斷言該行不存在 |
| V2-3 | 同來源兩條同長最短路徑 | 兩條皆列，依中間節點列序 |
| V2-4 | 不同長度 | 短的在前 |
| V2-5 | 直接貫穿格、無關格 | 不產生依賴路徑 |
| V2-6 | 路徑文字 | domain 為原值、以「→」連接，切 en 不變 |

#### V3 「在泳道中檢視」跳轉目標

**測試檔**：同上，group `跳轉目標`

| # | Given | Then |
|---|-------|------|
| V3-1 | UC-04 × `schema` | 目標列 `graph`，目標節點為 UC-04 欄號最小且 `traverses` 含 `graph` 的步驟 |
| V3-2（E1） | 來源 X 在 UC 中有兩個步驟，檔內順序在後者欄號較小（分支插欄） | 取欄號最小者，而非檔內順序最先者 |
| V3-3 | 直接貫穿格 | 目標列為該格 domain |

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

### 3.5 元件（SPEC-004）

**測試檔**：既有 `test/unit/components/` 一比一檔（加 group，不新增檔）

| # | 元件 | Given | Then |
|---|------|-------|------|
| K1-1 | 4.37 `MatrixGrid` | `domainName: "ticketdetail"` 與未知值 `"foo-bar"` | 列首逐字顯示原值；zh／en 皆同 |
| K1-2 | 4.37 | 同一列 | 列首不出現任何 `swimlaneScreenLaneName` 文字；矩陣無「畫面」列 |
| K2-1 | 4.38 `SwimlaneGrid` | 9 列 `lanes`、首列 `kind: screen` | 9 列依輸入順序；首列列首為 `swimlaneScreenLaneName`（zh「畫面」／en「Screen」）；domain 列為原值 |
| K2-2 | 4.38 | 「畫面」列 | 列首不可點、不受 `laneHighlight` 高亮 |
| K2-3（E1） | 4.38 `edges` | 一條 `straight`、一條 `arc` vs 空 `edges` | 前者各渲染一條且形狀可區分；後者無邊；兩者渲染結果不同 |
| K2-4 | 4.38 | `lanes` 長度 ≠ 9 | 依 slot 約束的處置——見 §6 N4 |
| K3-1（E1） | 4.19 `RelationItem` | `isProposed: true` vs `false` | true：尾端一個 tone `warning` 的 `Badge.category`，文字 zh「暫定」／en「Proposed」，朗讀 `relationItemProposedA11yLabel`；false：無 badge、朗讀 `relationItemA11yLabel` |
| K3-2 | 4.19 | 最長測試文案的 `id` | `id` 截斷時 badge 不截斷、不換行 |
| K3-3 | 4.19 | 朗讀 | badge 併入 chip 標籤，不另朗讀 |
| K4-1 | §4.0.6 | 四個 `pathDeclaration*` key、`relationProposedLabel`、`relationItemProposedA11yLabel`、`swimlaneScreenLaneName` | zh／en ARB 皆存在且值與 §4.0.6 表逐字一致 |

## 4. 覆蓋矩陣

### 4.1 規則 ↔ 測試

| 規則（規格位置） | 5a | 5b |
|----------------|----|----|
| 列集合與列序（SPEC-001 §1） | ITD2-A1、A4、A5 | L1、L2 |
| 列鍵比對、列首原值（SPEC-001 §1；SPEC-004 4.37／4.38） | ITD1-A3 | L4-3、K1、K2-1 |
| 主線、欄序（SPEC-001 §1） | ITD2-A2、A5 | L3 |
| 節點所屬列、「畫面」列 | ITD2-A2 | L4、K2-2 |
| 邊的來源、形狀、端點 | ITD2-A3、A5 | L5、K2-3 |
| 欄序無法輸出的步驟 | — | L6 |
| 間接依賴判定式 | ITD1-A1、A2、A4 | V1 |
| 依賴路徑 | ITD3-A1、A2、A4 | V2 |
| 跳轉目標 | ITD3-A3 | V3 |
| ticket 定位五狀態與整體未宣告（UC-02 v1.6） | ITD4-A1、A2 | P1、P2、P3 |
| 宣告狀態行（SPEC-001 §5） | ITD4 | R1、K4-1 |
| proposed 標記（SPEC-004 4.19） | — | K3、K4-1 |

L6 不在外圈：兩份語料皆無懸空與循環（SPEC-001 期望值欄），外圈無資料可驅動。K3 不在外圈：見 §6 N3。

### 4.2 Layout 不變式 ↔ 測試

| 不變式（`docs/spec/layout/domain-map.md`） | 測試 |
|------------------------------------------|------|
| 列序不寫死 domain 名、換 UC 不變 | L1-4、L2-6、ITD2-A4、A5 |
| 結構異常不消失、接在最後 | L2-4、L2-5、L6 |
| 只依賴 Graph | §1.4 import 檢查 |

## 5. 測試案例統計

| 單元／圈 | 群組 | 案例數 |
|---------|------|-------|
| 5a 外圈 | IT-D1～IT-D4 | 17 |
| Layout | L1～L6 | 29 |
| domain_view | V1～V3 | 15 |
| 路徑定位 | P1～P3 | 15 |
| 報告頁宣告狀態行 | R1 | 8 |
| 元件 | K1～K4 | 10 |
| 合計 | | 94 |

守衛型案例（已附正向對照）：L2-4、L2-5、L6-1、L6-2、R1-5。
E1 對照：ITD1-A4、ITD2-A5、ITD3-A4、ITD4-A3、L1-2、L2-2、L3-3、L4-3、L5-3、V1-3、V2-2、V3-2、P2-2、P2-3、R1-7、K2-3、K3-1。

## 6. 待決與交接

### 6.1 NeedsContext（已寫入票面）

- **N1**：外圈期望值綁凍結快照或即時 repo。SPEC-001 寫「測試以當時資料重算」，未指定由誰重算。本文件暫採凍結快照；是否另加一條「即時 repo 與快照一致」的檢查未裁決。
- **N2**：`traverses` 值與列鍵不精確相符（L4-3 的 `"Graph"`）時，節點落何處未定義——消失、接在最後、或落「畫面」列皆未裁決。名稱未宣告屬 `graphDefect` 子類（2026-10-08 補記），但泳道端的放置規則不在 SPEC-001。
- **N3**：flutter_balance 的 flow 步驟**沒有 `traverses` 欄位**（實測：UC-01 flow 區塊九步皆無此鍵）。CLAUDE.md §6 寫「欄位必存在」，欄位缺席時的節點放置（視同 `[]` 進「畫面」列或另行處置）未定義；ITD2-A5 與 L3-2 的節點列斷言待此裁決，欄序與邊的斷言不受影響。另外 IT 範圍內沒有 proposed 邊的畫面驗收（詳情卡上的 `bundle_dependency` 關聯），是否需外圈案例未定。
- **N4**：4.38 `lanes` 寫「恆 9 列」，但 flutter_balance 依同一規則為 2 列。「9」應讀作本專案期望值或 slot 約束，影響 K2-4 與 ITD2-A5。
- **N5**：間接依賴判定的承擔單元（domain_view 畫面層、Graph 或 Layout）未在 domain map 指名；本文件測試檔路徑暫放 `test/unit/screens/domain_view/`。
- **N6**：flow 區塊解析失敗（EVT-CORPUS-004）的 UC 在泳道落何狀態（「flow 未結構化」或其他）未定義；SPEC-001 §1 只有「無 FlowStep」一條進入條件。

### 6.2 實作單元與承接票對照（Step 6）

| 案例群組 | 實作單元 | 承接票 | 依賴 |
|---------|---------|-------|------|
| L1、L2 | Layout（列序） | 待 Step 6 建票 | `0.5.0-W1-103.2`（`bundle_dependency` 進主圖） |
| L3～L6 | Layout（欄序、節點、邊） | 待 Step 6 建票 | `0.5.0-W1-001.4`（flowOf） |
| K2 | components（`SwimlaneGrid`） | 待 Step 6 建票 | 無 |
| K1 | components（`MatrixGrid`） | 待 Step 6 建票 | 無 |
| V1～V3 | domain_view | 待 Step 6 建票 | `0.5.0-W1-001.5`（名稱解析器）、`0.5.0-W1-103.2` |
| P1～P3 | 路徑比對器 | `0.5.0-W1-096.5` | `0.5.0-W1-096.7`（讀非 domain 清單） |
| R1、K4-1（`pathDeclaration*`） | Diagnostics／破洞報告頁 | 待 Step 6 建票 | `0.5.0-W1-096.5` |
| K3、K4-1（`relation*`） | components（`RelationItem`） | `0.5.0-W1-103.2`（SPEC-004 §4.0.6 指名其建 ARB；元件改動是否在其範圍待確認） | 無 |
| K4-1（`swimlaneScreenLaneName`） | components | 待 Step 6 建票（併 K2） | 無 |
| N6 | Corpus EVT-004 接畫面 | 待 Step 6 建票（待 N6 裁決） | `0.5.0-W1-113` 的 flow 解析案例 |
| IT-D1～IT-D3 | 外圈 | 待 Step 6 建票 | 以上 Layout、domain_view、components 全部 |
| IT-D4 | 外圈 | 待 Step 6 建票 | `0.5.0-W1-096.5`、報告頁票 |
| 快照凍結 | 測資 | 待 Step 6 建票 | 無 |

**Step 6 建議分組**（各組一張實作票）：

1. Layout：L1～L6（可再依列序／欄序拆兩張，群組間無共用 mutable 狀態）
2. domain_view：V1～V3
3. Diagnostics／報告頁：R1、K4-1 的 `pathDeclaration*` 部分
4. components：K1、K2、K4-1 的 `swimlaneScreenLaneName`（K3 若 `0.5.0-W1-103.2` 不承接則併入）
5. Corpus EVT-004 接畫面：N6 裁決後建
6. 外圈與快照：快照凍結 → IT-D1～IT-D4

各實作票驗收須含 §1.4 的 import 方向檢查。
