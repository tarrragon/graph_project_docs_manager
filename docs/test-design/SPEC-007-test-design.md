---
id: SPEC-007-test-design
title: "SPEC-007 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-007
spec_version: "1.2"
ticket: 0.4.0-W1-059
created: "2026-09-30"
updated: "2026-10-08"
---

# SPEC-007 Phase 2 紅燈測試規格

本文件是 SPEC-007 v1.2（建圖：輕節點、邊的聯集與圖結構破洞）的紅燈測試規格，供
version-bootstrap Step 6 建實作票。只描述測資、流程與斷言，不含測試程式碼。規則權威在
SPEC-007；本文件與其衝突時以 SPEC-007 為準，衝突本身記入承接票的 NeedsContext。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-1、IT-2、IT-3 三項整合測試 | 版本契約（PROP-005 §0.4）的驗收終點 | 與獨立參照實作的行為分歧，或 Corpus→Graph 交界斷裂 |
| 5b 內圈 | 逐 bundle 的 domain unit 測試 | SPEC-007 每條驗收條件與各 domain map §3〈Bundle 不變式清單〉 | 單一規則被打破，可直接定位 |

外圈綠而內圈紅、或反之，都代表測資沒有涵蓋到對應形態，須補測資而非放寬斷言。

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| Schema 邊型解碼（FR-01） | domain unit（純函式） | 型別表 JSON 以測試內建的最小表注入；內建表以真實 asset 讀取 |
| Graph 輕節點、抽取分類、建邊、聯集、計數、鄰接查詢（FR-02～06、08） | domain unit | 輸入直接構造 `rawNode` 值物件（Corpus 的 EVT-CORPUS-001 型別）；邊型表用真實 Schema 解碼結果（Sociable），不 mock Schema |
| TicketDetail（FR-07） | domain unit | 輸入直接構造 `rawNode` |
| Diagnostics 圖結構破洞（FR-09） | domain unit | 輸入直接構造 EVT-GRAPH-001 值物件與「建圖不可用」狀態 |
| 日誌事件（版本契約第 5 欄） | domain unit | 以注入的 log sink 記錄（沿用 `WorkspaceRepository` 的 `logSink` 接縫形態），生產預設轉呼 `developer.log` |
| IT-1～3 | integration（`test/integration/`） | 不 mock：暫存目錄真實檔案、真實 Corpus 掃描、真實 Schema、Graph、TicketDetail、Diagnostics |

Mock 只替換外部世界（檔案系統、log 輸出）；Schema、Corpus、Graph、TicketDetail、Diagnostics
之間一律用真實物件。

### 1.3 依賴方向與測試隔離

依系統層 §2（Graph → Corpus → Schema；Diagnostics 收 Graph 事件）：

- `test/unit/schema/` 不得 import `lib/graph/`、`lib/ticket_detail/`、`lib/corpus/`、`lib/diagnostics/`
- `test/unit/graph/` 可 import `lib/graph/`、`lib/schema/`、`lib/corpus/`（僅事件型別）；不得 import `lib/diagnostics/`、`lib/ticket_detail/`
- `test/unit/ticket_detail/` 可 import `lib/ticket_detail/`、`lib/corpus/`（僅事件型別）；不得 import `lib/graph/`、`lib/diagnostics/`
- `test/unit/diagnostics/` 可 import `lib/diagnostics/`、`lib/graph/`（僅事件型別）、`lib/corpus/`（僅事件型別）；不得 import `lib/schema/`
- 只有 `test/integration/graph_it*_test.dart` 可同時 import 全部

各實作票驗收含上述 import 方向檢查（grep `^import` 差集為零）。

### 1.4 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 |
|--------|------|------|---------|
| 邊型表建構器 | `test/helpers/spec007/edge_table_builder.dart` | 以宣告方式建出含指定邊型（鍵名、class、正反向欄位、基數、layer、direction）與版本的型別表 JSON | S6、G1～G9 |
| rawNode 建構器 | `test/helpers/spec007/raw_node_builder.dart` | 以 `id`、型別、路徑與 frontmatter map 建 `rawNode` | G1～G9、T1、D3 |
| 分布已知 fixture | `test/helpers/spec007/known_distribution_fixture.dart` | 一組 rawNodes 與其手算的全部計數（計數的權威位置是 fixture 檔內的常數，本文件不另列表：`0.4.0-W2-003` 建立節點數、`duplicateId`、引用值三類；`0.4.0-W2-004` 擴充各邊型邊數、宣告來源五組、`multiSource`），供 G3-8、G6-1、NFR 基準共用 | G3、G6、G9 |
| log 記錄器 | `test/helpers/spec007/log_recorder.dart` | 實作 log sink，可查詢事件名與負載 | L1～L3 |
| manifest 實體化器 | `test/helpers/spec007/graph_manifest_materializer.dart` | 依 IT manifest 在暫存目錄寫最小 frontmatter 檔案樹 | IT-1～3 |

各群組只透過 helper 取得 fixture，不共享 mutable 狀態；每個群組可單獨執行。

## 2. 5a 外圈

### 2.1 凍結測資總覽

**目錄**：`test/fixtures/spec007/`

| 內容 | 路徑 | 形態 |
|------|------|------|
| 型別表 | `type_table.json` | 凍結時所用的型別表（含 `edge_types` 與正向基數）；IT 以它注入 Schema，不讀即時檔 |
| 圖 manifest | `graph_manifest.json` | IT-1、IT-2 共用，見 §2.2 |
| TicketDetail 樣本 | `ticket_detail_samples.json` | IT-3 專用，見 §2.5 |
| 參照實作輸出 | `expected_edges.json`、`expected_defects.json`、`expected_counts.json` | 見 §2.3 |
| 凍結說明 | `README.md` | 凍結日期、框架 `.claude/VERSION`、`schema_generated_at_framework_version`、語料 commit、凍結指令、量測環境（依 reference-stability 規則 9 標註）、實測值與 todolist 0.4.0 版本契約第 2 欄的差異 |

### 2.2 graph manifest 欄位

**列（每個節點一列）**：

| 欄位 | 值域 | 說明 |
|------|------|------|
| `corpus` | `graph_project_docs_manager`／`flutter_balance`／`synthetic` | 來源語料 |
| `path` | 相對於該語料工作區根的路徑，以 `docs/` 開頭，`/` 分隔，不加語料前綴 | 實體化目標；寫入哪一棵樹由 `corpus` 欄（合成列為 `synthetic_host`）決定（見實體化流程第 1 步），使 Corpus 的完整相對路徑比對（SPEC-006 FR-06 規則 1）與真實語料一致 |
| `id` | 字串 | 原值 |
| `node_type` | 型別名 | 凍結時參照實作判定的型別（實體化器不使用，供斷言對照） |
| `status`、`title` | 原值或缺席 | 原值保留型別（非字串原樣保留，供 FR-02 null 化驗證） |
| `edge_fields` | map：欄位名 → 原值 | 全部使用中邊型的正向與反向欄位原值（缺席的欄位不列鍵；null、空字串、空清單、非字串、`outputs` map 皆原樣） |
| `synthetic` | bool | 合成列為 true |
| `covers` | 樣本類別清單 | 此列負責的 D5 樣本類別（§2.2.1），真實列可空 |

**檔頭**：凍結日期、參照實作版本、型別表產生版本、兩語料量測時 commit、語料節點數。

**兩語料分區**：兩語料的 ID 空間可能重疊（皆為 `0.x.y-Wn-nnn` 形態），實體化時放在同一工作區會變成人為重複 ID。
因此 IT 對每個語料**各實體化一棵樹、各跑一輪建圖**，`expected_*` 以 `corpus` 分組；合成列掛在指定語料下
（`synthetic_host` 欄，合成列必填）。

#### 2.2.1 D5 樣本覆蓋

| 類別（`covers` 值） | 最少列 | 來源 | 預期（規劃量測，凍結時重量） |
|-------------------|-------|------|------------------------|
| `related_one_side` 單側 `relatedTo` | 1 | 真實 | 見 IT1-A2 |
| `related_both_sides` 兩側 `relatedTo` | 1 對 | 真實 | 宣告來源 {A, B} |
| `spawn_reverse_only` 只在反向的 `spawn` | 1 | 真實 | 本專案 38／flutter_balance 52 |
| `spawn_multi_source` `spawn` 多來源衝突 | 1 | 真實 | `multiSource` 7／9 |
| `provenance_multi_source` 多來源 `provenance` | 1 | 真實（UC-01，W2-001 後為兩來源） | 兩條邊、`multiSource` 0 |
| `dangling` 斷邊 | 1 | 真實 | 3／0（覆蓋以全 manifest 計，本專案真實列已足） |
| `malformed_pattern` 格式錯誤（`patternMismatch`） | 1 | 真實 | 1／4 |
| `duplicate_id` 重複 ID | 1 對 | 合成 | 語料 0 |
| `self_reference` 自我引用 | 1 | 合成 | 語料 0 |
| `invalid_shape` 非法形狀（數字、布林、map 值；清單內非字串） | 1 | 合成 | 語料 0 |
| `target_duplicated` 指向重複 ID 的引用 | 1 | 合成 | 依附 `duplicate_id` |
| `outputs_non_list_subkey` `outputs` 子鍵非清單 | 1 | 合成 | — |
| `null_in_list` 清單內 null | 1 | 合成 | 不計為引用值 |
| `non_string_status_title` | 1 | 合成 | 輕節點 `status`／`title` 為 null |

語料中實際有的類別不得以合成列取代（合成列只補語料缺席者）；README 列出每個 `covers` 值實際列數與真實／合成比例。

#### 2.2.2 實體化流程

1. 每個語料建立一個暫存目錄作為工作區根；每列依 `corpus`（合成列依 `synthetic_host`）歸入其中一棵樹
2. 在該樹的根下依 `path`（本身以 `docs/` 開頭，不加前綴）建目錄，寫出最小 frontmatter：`id`、`status`／`title`（有則寫）、`edge_fields` 全部鍵，以 YAML 序列化原值（保留非字串型別、null、空字串、帶空白的字串、`outputs` map）；並寫入使 Corpus 判型成立所需的最小欄位（`id` 已足，依 SPEC-006 FR-03）
3. 經 Workspace 根路徑來源與真實檔案系統 port 執行一輪 Corpus 掃描（SPEC-006），取得 EVT-CORPUS-001 的 `rawNodes`
4. 以 `type_table.json` 注入 Schema，Graph 由 `rawNodes` 建圖；Diagnostics 收 EVT-GRAPH-001
5. 測試不得把 manifest 直接餵給 Graph；Graph、Corpus 皆不讀 manifest

### 2.3 Python 參照實作規格

**路徑**：`tool/spec007_reference.py`（與 `tool/spec006_reference.py` 同形態）

| 項目 | 規格 |
|------|------|
| 輸入 | `graph_manifest.json`（每語料的列集合）＋ `type_table.json` |
| 子命令 | `selftest`（內嵌單元測試，涵蓋 FR-02～FR-05 各分支）；`freeze`（讀兩語料 → 產 manifest 與三份 expected，一次寫檔）；`compute`（只讀 manifest 產 expected，供重算核對） |
| 輸出 `expected_edges.json` | 每語料一組邊，每邊為 `{edge_type, from, to, declared_by}`；比對鍵為（邊型、起點、終點、宣告來源集合排序後）；無向邊 `from`／`to` 依 ID 字典序（codepoint 比較）排列 |
| 輸出 `expected_defects.json` | 每語料一組缺陷，欄位同 SPEC-007 FR-09 各子類（`danglingRef`／`malformedRef`：來源 ID、路徑、欄位名、原始值原樣、邊型、原因碼；`duplicateId`：ID 與排序後全部路徑；`multiSource`：起點、邊型、各終點與其宣告來源） |
| 輸出 `expected_counts.json` | 每語料：引用值總數（由 manifest 依 SPEC-007〈用詞〉「引用值」獨立計數）、FR-03 三類計數、FR-06 全部計數項 |
| 獨立性 | 不 import、不執行、不讀取任何 Dart 實作或其產物；只讀 manifest、型別表、語料原始檔（`freeze` 時）。`id_pattern` 依型別表 `id_pattern_dialect` 比對；README 記錄此約束 |
| 引用值總數 | 由參照實作遍歷 manifest 各列 `edge_fields` 獨立算出，**不**由三類分類結果加總得出（否則與待測端守恆式同構，失去鑑別力）；`selftest` 含一案例斷言兩種算法在 fixture 上相等 |
| 執行時機 | 凍結時離線執行，CI 不執行 |

### 2.4 IT-1 聯集（FR-04、FR-05、FR-08）

**測試檔**：`test/integration/graph_it1_edge_union_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| IT1-A1 | 每個語料的實體化樹 | 建圖 | 邊集合（比對鍵含宣告來源）與 `expected_edges.json` 該語料組完全相等；以差集雙向列出多出與缺少 |
| IT1-A2（E1 鑑別） | `covers: related_one_side` 的每一筆，未宣告端 B | 對 B 做鄰接查詢（邊型 `association`） | 結果含宣告端 A；另以測試內「只讀 B 自己的 `relatedTo` 欄位」計算，斷言該結果不含 A（證明測資有鑑別力） |
| IT1-A3 | `covers: spawn_reverse_only` 的每一筆 | 查該子票（方向：出） | 得到父票，宣告來源 {父} |
| IT1-A4 | 各宣告來源形態 | 統計 | 有向邊的僅起點、僅終點、兩端，與無向邊的一端、兩端，五組計數等於 `expected_counts.json`（SPEC-007 v1.3 FR-06） |
| IT1-A5（守衛，E2） | manifest 覆蓋檢查器 | 檢查 §2.2.1 每類至少一列 | 通過；另以測試內建、缺 `related_one_side` 的 manifest 作正向對照，斷言檢查器回報缺漏 |
| IT1-A6（守衛，E2） | 實體化器 | 遇到無法序列化的 `edge_fields` 值型別 | 拒絕而非略過；以測試內建含未知值型別（例如 YAML 無法表示的物件標記）的列作正向對照 |

### 2.5 IT-2 缺陷交給 Diagnostics（FR-03、FR-09）

**測試檔**：`test/integration/graph_it2_defects_to_diagnostics_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| IT2-A1 | 同 IT-1 的實體化樹 | 建圖並交 Diagnostics | `graphDefect` 破洞集合與 `expected_defects.json` 一一對應（子類、各欄位內容、原始值原樣），無多出或缺少 |
| IT2-A2 | 同上 | 讀 EVT-GRAPH-001 計數 | 解析成功＋斷邊＋格式錯誤的總和，等於 `expected_counts.json` 的**引用值總數**（凍結值，非待測實作自算） |
| IT2-A3 | 同上 | 讀計數 | 三類計數、`duplicateId` 數、`multiSource` 數各自等於凍結值（守恆式成立不足以通過，須逐項相等） |
| IT2-A4（守衛，E2） | 守恆比對器 | 輸入待測計數與凍結總數 | 相等時通過；以「解析成功少 1」的測試內建計數作正向對照，斷言比對器回報失敗 |
| IT2-A5（E1 鑑別） | 同一實體化樹，改以「缺 `edge_types` 且版本高於內建」的型別表 | 建圖 | 建圖不可用；`graphDefect` 為 0 且回報無法判定；結果與 IT2-A1 不同 |
| IT2-A6（E1 鑑別） | 同一實體化樹，改以「有 `edge_types` 但某邊型缺正向基數、版本高於內建」的型別表；測試內以一個映射函式扮演編排層，把建圖不可用原因轉成 Diagnostics 的 `UndeterminedGapReason`（0.3.0 IT-2 同一前例；本檔只有 `test/integration/graph_it*` 可同時 import Graph 日誌與 Diagnostics，§1.3） | 建圖並交 Diagnostics | 日誌「建圖不可用」事件的原因碼為缺正向基數；Diagnostics 的無法判定原因為 `projectVersionOutOfKnownRange`；與 IT2-A5 比對：日誌原因碼不同、Diagnostics 原因相同（SPEC-007 v1.5 FR-09 #3） |

### 2.6 IT-3 輕節點與全文分離（FR-02、FR-07）

**測試檔**：`test/integration/graph_it3_light_node_separation_test.dart`

**測資**：`ticket_detail_samples.json`：ticket 完整 frontmatter 樣本（原樣 map，含 5W1H 與生命週期欄位），
凍結時對語料中出現的每一種 `status` 值至少選一張（README 列出 status 值集合與各選中張數）。

**樣本與 manifest 的關係**：每張樣本必須是 graph manifest 既有的一列（同 `corpus`、同 `path`），不另增檔案。
實體化時先依 manifest 寫最小 frontmatter，再以樣本的完整 frontmatter 覆寫同一路徑（每個路徑最終只有一份檔案）。
凍結時斷言樣本的 `id`、`status`、`title` 與全部使用中邊型欄位原值，逐一等於該 manifest 列；因此覆寫不改變
任何引用值，參照實作的 expected 值不受樣本影響。

| # | Given | When | Then |
|---|-------|------|------|
| IT3-A1 | 實體化樹建出的圖 | 遍歷全部節點 | 每個節點的欄位集合恰為 {id、節點型別、status、title、相對路徑} |
| IT3-A2 | 每張樣本 ticket | 以 ID 查 TicketDetail | 回傳 map 與樣本 frontmatter 逐鍵、逐值相等 |
| IT3-A3 | 每張樣本 ticket | 從圖節點取值 | 圖節點不暴露 `what`／`how`／`who` 等任何非輕節點欄位 |
| IT3-A4（守衛，E2） | status 覆蓋檢查器 | 比對樣本 status 值集合與 README 記錄的語料 status 集合 | 相等時通過；以缺一種 status 的測試內建樣本集作正向對照，斷言回報缺漏 |
| IT3-A5 | 非 Ticket 節點 ID（例如 SPEC） | 查 TicketDetail | 回傳「不存在」 |
| IT3-A6（守衛，E2） | 樣本與 manifest 一致性檢查器 | 對每張樣本比對同 `path` 的 manifest 列（`id`、`status`、`title`、全部使用中邊型欄位原值），並確認該列存在 | 全部相等時通過；以測試內建、某張樣本 `relatedTo` 與 manifest 列不同的樣本集作正向對照，斷言回報不一致；另以 `path` 不在 manifest 的樣本作正向對照，斷言回報缺列 |

## 3. 5b 內圈：逐 bundle 測試案例

案例編號：`S`＝Schema、`G`＝Graph、`T`＝TicketDetail、`D`＝Diagnostics、`L`＝日誌事件、`N`＝NFR。
「守衛」代表對象是判定或攔截邏輯，已附正向對照輸入（E2）。

### 3.1 Schema bundle

#### S6 邊型解碼（FR-01）

**測試檔**：`test/unit/schema/edge_type_decoding_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| S6-1 | 真實內建型別表 asset | 解碼 | 邊型鍵集合等於 asset `edge_types` 鍵集合；每個邊型帶鍵名、class、`forward_field`、`reverse_field`、正向基數、layer |
| S6-2 | 同上 | 取使用中邊型 | 等於 established 邊型集合扣除 `domain_dependency`（集合以 asset 計算，不寫死數字） |
| S6-3 | 測試型別表新增 established 邊型 `testEdge`（欄位 `test_refs`） | 取使用中邊型 | 含 `testEdge`；另於 G2-9 驗 Graph 依其欄位抽取 |
| S6-4 | 測試型別表把某使用中邊型 `forward_field` 改名 | 解碼 | 邊型帶新欄位名；另於 G2-10 驗 Graph 不讀舊欄位名 |
| S6-5 | 專案型別表缺 `edge_types`，版本等於內建 | 解碼 | 邊型集合與內建表相同，建圖可用 |
| S6-6 | 專案型別表缺 `edge_types`，版本低於內建 | 解碼 | 同 S6-5 |
| S6-7（守衛） | 專案型別表缺 `edge_types`，版本高於內建 | 解碼 | 建圖不可用，帶原因碼（與 SPEC-006 FR-08 同一套）；正向對照為 S6-5 |
| S6-8（守衛） | 專案型別表有 `edge_types` 但某邊型缺正向基數，版本高於內建 | 解碼 | 建圖不可用；同一表版本改為等於內建時，基數由內建補值、可用（正向對照） |
| S6-9 | layer 為 proposed 的邊型 | 取使用中邊型 | 不在其中 |
| S6-10 | 既有 `node_types` 解碼 | 解碼含 `edge_types` 的表 | 節點型別解碼結果與未含 `edge_types` 時相同（版本契約第 2 欄「既有 node_types 解碼測試不變」） |
| S6-11（守衛） | 專案型別表整份缺席（`projectSchemaJson` 為 null） | 解碼 | 建圖不可用，原因碼為版本不在已知範圍；正向對照為 S6-12（SPEC-007 v1.3） |
| S6-12 | 降級模式：內建表 asset 作為專案型別表傳入 | 解碼 | 建圖可用；使用中邊型等於 asset 的 established 邊型扣除 `domain_dependency`（SPEC-007 v1.3） |
| S6-13（守衛） | 真實內建型別表 asset；另以邊型表建構器建一份與 asset 相同、僅改指定邊型 `direction` 的測試用型別表 | 讀 `edge_types`；以同一 fixture（A 的 `relatedTo` 列出 B，B 未列 A）建圖 | asset 中 `direction` 為 `undirected` 的邊型集合等於 Graph 認定為無向的邊型集合（目前為 {`association`}）；`spec_association`、`uc_association`、`proposal_association` 的 `direction` 為 `directed`，Graph 照有向處理；`association` 的 `forward_field` 為 `relatedTo`、`reverse_field` 為 null，A 與 B 的鄰接均含對方（對稱聯集）。正向對照（守衛）：測試用型別表把某個 see-also 邊型（如 `spec_association`）的 `direction` 改為 `undirected`，該邊型即做對稱聯集，證明判定依欄位而非鍵名。E1 對照：同一 fixture 下僅把 `association` 的 `direction` 改為 `directed`，建出有向邊 A→B，查 B 的方向為入而非無向，結果與改動前不同；兩份型別表的產物必須不同（SPEC-007 v1.13 FR-05、D6：無向由 `direction` 判定，已無 `association` 鍵名例外）。測試檔放 `test/unit/graph/undirected_edge_contract_test.dart`：需讀 Graph 的無向認定，§1.3 不允許 schema 測試 import graph |

### 3.2 Graph bundle

#### G1 輕節點（FR-02）

**測試檔**：`test/unit/graph/light_node_test.dart`

| # | Given | Then |
|---|-------|------|
| G1-1 | 一張帶 5W1H 的 ticket `rawNode` | 輕節點欄位集合恰為五項；修改原 frontmatter map 後輕節點不變（無共用引用） |
| G1-2 | `status: 3`、`title: [a]` | 兩者為 null，建圖完成 |
| G1-3 | 缺 `status`、`title` | 兩者為 null |
| G1-4（守衛） | 兩份 `rawNode` 同 `id` X（兩路徑） | 兩者都不在圖上；一筆 `duplicateId` 帶兩個路徑；兩者欄位中的引用值不出現在任何分類計數。正向對照：`id` 改為不同時兩者皆在圖上 |
| G1-5 | G1-4 加第三節點 `relatedTo: [X]` | 該引用值為 `danglingRef`（`targetDuplicated`） |
| G1-6 | 三份同 `id` | 一筆 `duplicateId` 帶三個路徑 |

#### G2 引用值抽取（FR-03 抽取、FR-01 欄位來源）

**測試檔**：`test/unit/graph/reference_extraction_test.dart`

| # | Given | Then |
|---|-------|------|
| G2-1 | 欄位缺席、null、`""`、`[]` 各一 | 不產生引用值（計數 0） |
| G2-2 | `blockedBy: [0.1.0-W1-001, 42, null]` | 兩個引用值：前者依存在與否分類，`42` 為 `malformedRef`（`invalidShape`）；null 不計 |
| G2-3 | 純量欄位值為布林 | 一個引用值，`invalidShape` |
| G2-4 | 純量欄位值為 map（非 `outputs`） | 一個引用值，`invalidShape` |
| G2-5 | PROP `outputs.design_refs: [SPEC-001]` | 一個 `provenance` 反向引用值，照常分類 |
| G2-6 | PROP `outputs` 含兩個子鍵各兩項 | 四個引用值（子鍵不列舉） |
| G2-7 | PROP `outputs.notes: "x"` | 一個 `malformedRef`（`invalidShape`） |
| G2-8 | 引用值指向任意節點型別 | 不檢查終點型別（例如 `blockedBy` 指向 SPEC 照常解析成功） |
| G2-9（E1 鑑別） | 測試型別表加 `testEdge`（`test_refs`），節點帶 `test_refs: [B]` | 建出 `testEdge` 邊；同 fixture 以未加 `testEdge` 的表建圖則無此邊，兩者邊集合不同 |
| G2-10（E1 鑑別） | 測試型別表把 `blocking` 的 `forward_field` 改為 `blocks_x`，節點同時帶 `blockedBy: [B]` 與 `blocks_x: [C]` | 只建 →C 的邊；未改名的表只建 →B，兩者不同 |

#### G3 引用值分類（FR-03 分類、守恆）

**測試檔**：`test/unit/graph/reference_classification_test.dart`

| # | Given | Then |
|---|-------|------|
| G3-1 | `source_ticket: 0.1.0-W3-181`，圖上無該節點 | `danglingRef`（`targetMissing`），不建邊 |
| G3-2 | `relatedTo: ["0.1.0-W1-072 0.1.0-W1-073"]` | `malformedRef`（`patternMismatch`），不抽出其中 ID（圖上兩 ID 皆存在時仍不建邊） |
| G3-3 | `discovered_during: "0.2.1-W3-1057 驗收"` | 同上 |
| G3-4 | `spawned_tickets: [PENDING]` | 同上 |
| G3-5（守衛） | `relatedTo: [" 0.1.0-W1-001"]`，圖上有 `0.1.0-W1-001` | `patternMismatch`，不去空白重試；正向對照：無空白版本解析成功 |
| G3-6（守衛） | A 的 `relatedTo` 列出 A | `malformedRef`（`selfReference`）；正向對照：列出 B 時解析成功 |
| G3-7 | 同時符合格式錯誤與斷邊條件的值（格式錯且不存在） | 歸格式錯誤（有序判定，取第一個成立者） |
| G3-8 | 分布已知 fixture（§1.4） | 三類計數等於已知值；守恆式成立 |
| G3-9（守衛） | 守恆檢查器 | 以少算一個的計數作正向對照，斷言回報失敗 |

#### G4 建邊來源與宣告來源（FR-04）

**測試檔**：`test/unit/graph/edge_declaration_test.dart`

| # | Given | Then |
|---|-------|------|
| G4-1 | 子票 `source_ticket` 空、父票 `spawned_tickets: [子]` | 一條 `spawn`（子→父），宣告來源 {父} |
| G4-2 | 父子兩側都宣告 | 一條邊，宣告來源 {子, 父} |
| G4-3 | 子票 `source_ticket: A`，父 B `spawned_tickets: [子]` | 兩條（子→A {子}、子→B {B}），一筆 `multiSource` 帶起點、邊型、兩終點與各自宣告來源 |
| G4-4（守衛） | 子票 `source_ticket: X`（不存在），B 列出子票 | 一條（子→B），一筆 `danglingRef`，無 `multiSource`；正向對照為 G4-3 |
| G4-5 | UC `source_proposal: [PROP-003, PROP-002]`，兩 PROP 的 `outputs.usecase_refs` 皆列 UC | 兩條 `provenance`，宣告來源皆兩端，無 `multiSource`（基數 many） |
| G4-6 | PROP `outputs.spec_refs: [SPEC-X]`，SPEC-X `source_proposal` 為該 PROP | 一條 `provenance`（SPEC-X→PROP），宣告來源兩端 |
| G4-7 | 基數 one 的欄位寫成兩項清單（皆解析成功） | 兩條邊＋一筆 `multiSource` |
| G4-8（E1 鑑別） | G4-7 的 fixture，以把該邊型基數改為 many 的測試型別表建圖 | 無 `multiSource`；與 G4-7 結果不同（證明基數取自型別表） |
| G4-9 | `reverse_field` 為 null 的邊型（如 `blocking`），終點無對應欄位 | 只依起點建邊，宣告來源 {起點} |

#### G5 `relatedTo` 1-hop 對稱聯集（FR-05）

**測試檔**：`test/unit/graph/association_union_test.dart`

| # | Given | Then |
|---|-------|------|
| G5-1（E1 鑑別） | A 列出 B、B 未列出 A | 邊 {A, B} 存在，宣告來源 {A}；對 B 鄰接查詢得 A；對照：只讀 B 自身欄位得空 |
| G5-2 | A、B 互列 | 一條邊，宣告來源 {A, B} |
| G5-3 | 無向邊端點排列 | 以 (B, A) 與 (A, B) 兩種宣告順序建圖，邊的比對鍵相同（字典序） |

#### G6 建圖結果與事件（FR-06）

**測試檔**：`test/unit/graph/graph_build_result_test.dart`

| # | Given | Then |
|---|-------|------|
| G6-1 | 分布已知 fixture | 節點數、`duplicateId` 數、各邊型邊數、宣告來源形態邊數（有向三組、無向兩組）、FR-03 三類、`multiSource` 數等於已知值 |
| G6-2 | `rawNodes` 為空 | 發出一筆 EVT-GRAPH-001，`nodeCount`／`edgeCount` 0，`graphDefects` 空，非錯誤 |
| G6-3 | 建圖完成 | 恰一筆 EVT-GRAPH-001；`graphDefects` 筆數等於斷邊＋格式錯誤＋`duplicateId`＋`multiSource` |
| G6-4 | 同一邊多次宣告 | `edgeCount` 只計一次 |

#### G7 鄰接查詢（FR-08）

**測試檔**：`test/unit/graph/adjacency_query_test.dart`

| # | Given | Then |
|---|-------|------|
| G7-1 | 子票 `source_ticket` 指向父票 | 查子（出）得父；查父（入）得子；每項帶邊型、另一端、方向、宣告來源 |
| G7-2（守衛） | 篩選只含 `blocking`，節點同時有 `blocking` 與 `spawn` 邊 | 只回傳 `blocking`；正向對照：不篩選時兩者皆回傳 |
| G7-3 | 無向邊，方向篩選為出、入、兩者 | 三種都回傳該邊，方向標為無向 |
| G7-4 | 不存在的 ID | 空清單 |
| G7-5（守衛） | 建圖不可用（S6-7 的型別表） | 任何查詢回傳「圖不可用」，不是空清單；正向對照：可用圖上查無鄰居的節點回傳空清單。兩者型別可窮舉區分 |
| G7-6 | 尚未完成建圖 | 回傳「圖不可用」 |
| G7-7 | 預設參數 | 邊型預設為全部使用中邊型、方向預設兩者 |

#### G8 缺陷隔離（NFR-01）

**測試檔**：`test/unit/graph/defect_isolation_test.dart`

| # | Given | Then |
|---|-------|------|
| G8-1 | 基準 fixture 建圖結果 E0 | —（基準） |
| G8-2 | 基準另插入 `targetMissing`、`targetDuplicated`、`patternMismatch`、`invalidShape`、`selfReference`、`duplicateId`、`multiSource` 各一筆 | 建圖完成；原有邊集合與 E0 逐項相同，原有引用值分類不變；新增缺陷各得一筆 |
| G8-3 | 插入的節點排在 rawNodes 最前與最後 | 結果相同 |

#### G9 計算量（NFR-02）

**測試檔**：`test/performance/graph_build_scaling_test.dart`

| # | Given | Then |
|---|-------|------|
| G9-1 | 引用值數 N 與 10N 的合成語料 | 以操作計數（ID 索引查詢次數，經注入計數器取得）斷言與引用值總數成正比；不以牆鐘時間作 pass-fail |

G9 只斷言操作計數，結果是確定性的，不屬 D1 禁止的計時斷言，隨 `flutter test` 主套件執行（專案無 `dart_test.yaml` 排除 `test/performance/`）。NFR-02 若日後需要牆鐘時間量測，該案例須另以 tag 排除於主套件之外。

### 3.3 TicketDetail bundle

#### T1 以 ID 查全文（FR-07）

**測試檔**：`test/unit/ticket_detail/ticket_detail_query_test.dart`

| # | Given | Then |
|---|-------|------|
| T1-1 | 一張 ticket 的 `rawNode` | 以其 ID 查詢得到的 map 與 frontmatter 逐鍵相等（含 `who`／`what`／`when`／`where`／`why`／`how`） |
| T1-2 | 不存在的 ID | 回傳「不存在」，不拋例外 |
| T1-3（守衛） | 同 `rawNodes` 含 SPEC 節點 | 以 SPEC ID 查詢回傳「不存在」；正向對照為 T1-1 |
| T1-4 | 兩份同 ID 的 ticket | 回傳「不存在」 |
| T1-5 | 查詢來源 | 只由同一輪 `rawNodes` 建立（新輸入取代舊輸入後，舊輪獨有的 ID 回傳不存在） |

### 3.4 Diagnostics bundle

#### D3 圖結構破洞（FR-09）

**測試檔**：`test/unit/diagnostics/graph_defect_gap_test.dart`

| # | Given | Then |
|---|-------|------|
| D3-1 | EVT-GRAPH-001 含四子類各一 | 四筆 `graphDefect`，子類與欄位內容與缺陷逐一相符；原始值原樣（例如帶空白的字串不被修剪） |
| D3-2 | 零筆缺陷 | 零筆破洞，非「無法判定」 |
| D3-3 | 破洞負載 | 不含在地化字串（欄位為原因碼與原值，無顯示文字） |
| D3-4（守衛） | 建圖不可用狀態 | 零筆 `graphDefect`，回報無法判定並帶原因；正向對照為 D3-1 |
| D3-5 | 同時輸入 EVT-CORPUS-003 | `parseFailure` 與 `graphDefect` 各自產生，互不影響（SPEC-006 D1 不變） |

### 3.5 日誌事件（版本契約第 5 欄）

**測試檔**：`test/unit/graph/graph_log_events_test.dart`（L1、L2、L3 同檔三個 group）

| # | Given | Then |
|---|-------|------|
| L1-1 | 分布已知 fixture 建圖 | log sink 恰收到一筆「建圖完成」事件，負載的 `nodeCount`、`edgeCount`、各缺陷子類計數、FR-03 三類計數等於 G6-1 的已知值（記實際值） |
| L1-2（E1 鑑別） | 空 `rawNodes` | 「建圖完成」事件的計數全為 0；與 L1-1 的負載不同（證明記的是實際值而非常數） |
| L1-3 | 建圖流程 | 不存在只記「開始建圖」而無結果值的事件取代 L1-1 |
| L2-1 | S6-7 的型別表 | 恰一筆「建圖不可用」事件，負載帶原因碼（缺 `edge_types` 且版本不在已知範圍） |
| L2-2 | S6-8 的型別表 | 原因碼為「缺正向基數」類，與 L2-1 的原因碼不同 |
| L2-4 | 某邊型值為字串、版本高於內建 | 原因碼為「邊型條目不合法」，與 L2-1、L2-2 的原因碼皆不同（SPEC-007 v1.8） |
| L2-3（守衛） | 可用型別表建圖 | 不記「建圖不可用」；正向對照為 L2-1 |
| L3-1 | 圖不可用時連續三次鄰接查詢 | 「鄰接查詢圖不可用」事件恰記錄一次，帶原因碼 |
| L3-2（守衛） | 可用圖上查詢十次（含查無鄰居） | 不記任何鄰接查詢事件；正向對照為 L3-1 |

事件名與負載鍵由實作以具名常數定義（同 `WorkspaceLogEvent` 形態），測試以常數比對。

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 驗收條件數 | 5a | 5b | 日誌 |
|----|-----------|----|----|------|
| FR-01 | 7 | IT2-A5 | S6-1～S6-13、G2-9、G2-10 | L2 |
| FR-02 | 3 | IT-3（A1、A3）；IT-1 合成 `duplicate_id` 列 | G1-1～G1-6 | — |
| FR-03 | 8 | IT-2（A1～A4） | G2-1～G2-8、G3-1～G3-9 | L1 |
| FR-04 | 6 | IT-1（A1、A3、A4） | G4-1～G4-9 | — |
| FR-05 | 2 | IT-1（A1、A2） | G5-1～G5-3 | — |
| FR-06 | 3 | IT-2（A3） | G6-1～G6-4 | L1 |
| FR-07 | 2 | IT-3（A2、A5） | T1-1～T1-5 | — |
| FR-08 | 4 | IT-1（A2、A3） | G7-1～G7-7 | L3 |
| FR-09 | 3 | IT-2（A1、A5、A6） | D3-1～D3-5 | L2 |
| NFR-01 | 1 | — | G8-1～G8-3 | — |
| NFR-02 | —（非條件式驗收） | — | G9-1（`test/performance/`） | — |

無空行。

### 4.2 驗收條件 ↔ 案例（逐條）

| SPEC-007 驗收條件 | 案例 |
|------------------|------|
| FR-01 #1 內建表鍵集合與使用中邊型 | S6-1、S6-2 |
| FR-01 #2 新增 established 邊型 | S6-3、G2-9 |
| FR-01 #3 `forward_field` 改名 | S6-4、G2-10 |
| FR-01 #4 缺 `edge_types`、版本已知 | S6-5、S6-6 |
| FR-01 #5 缺 `edge_types`、版本較高 | S6-7、IT2-A5 |
| FR-01 #6 型別表整份缺席 | S6-11 |
| FR-01 #7 降級模式以內建表建圖 | S6-12 |
| FR-02 #1 五欄、無共用引用 | G1-1、IT3-A1 |
| FR-02 #2 重複 ID | G1-4 |
| FR-02 #3 指向重複 ID | G1-5 |
| FR-03 #1～#8 | G3-1、G3-2～G3-4、G3-5、G3-6、G2-2、G2-5、G2-7、G3-8 |
| FR-04 #1～#6 | G4-1～G4-6 |
| FR-05 #1、#2 | G5-1、G5-2 |
| FR-06 #1～#3 | G6-1、G6-2、G6-3 |
| FR-07 #1、#2 | T1-1、T1-2 |
| FR-08 #1～#4 | G7-1、G7-2、G7-4、G7-5 |
| FR-09 #1、#2 | IT2-A1、D3-4 |
| FR-09 #3 建圖不可用原因轉換（缺正向基數） | IT2-A6 |
| NFR-01 | G8-2 |

### 4.3 兩軸去重

FR 驗收（5b）與 IT（5a）交集的處理：5b 為規則分支的權威，IT 只做端到端一致性與凍結值比對，
不在 IT 中重複斷言單一規則的分支（例如「前導空白不去除」只在 G3-5，IT-2 以原始值原樣比對涵蓋，
不另立案例）。FR-09 #1 本身即以 IT-2 為驗收對象，故只在 IT2-A1 斷言，D3 不重複語料級比對。

### 4.4 不變式 ↔ 測試（各 domain map §3）

| Bundle | 不變式 | 測試 |
|--------|-------|------|
| Graph | 圖語意（symmetric union 規則）改變是唯一合法變更理由 | G5、IT1-A1、IT1-A2 |
| TicketDetail | ticket 5W1H 結構語意 | T1-1、IT3-A2 |
| Diagnostics | 「什麼算破洞」 | D3、IT2-A1 |

## 5. 測試案例統計

| Bundle／圈 | 群組 | 案例數 |
|-----------|------|-------|
| 5a 外圈 | IT-1、IT-2、IT-3 | 18 |
| Schema | S6 | 12 |
| Graph | G1～G9 | 52 |
| TicketDetail | T1 | 5 |
| Diagnostics | D3 | 5 |
| 日誌 | L1～L3 | 8 |
| 合計 | | 100 |

守衛型案例與正向對照：IT1-A5、IT1-A6、IT2-A4、IT3-A4、IT3-A6、S6-7、S6-8、S6-11、S6-13、G1-4、G3-5、G3-6、G3-9、G4-4、
G7-2、G7-5、T1-3、D3-4、L2-3、L3-2，均已附正向對照輸入。E1 鑑別對照：IT1-A2、IT2-A5、IT2-A6、G2-9、G2-10、
G4-8、G5-1、L1-2。

## 6. 待決與交接

### 6.1 設計判斷（非規格衝突，實作票依此執行）

- **兩語料各自建圖**：SPEC-007 D5 未指定兩語料實體化成一棵或兩棵樹；本規格定為各自一棵，理由是兩語料 ID 空間可能重疊，合為一棵會製造人為 `duplicateId`，使凍結值與 todolist 版本契約第 2 欄（重複 ID 0）不一致。
- **日誌接縫**：以注入 log sink 驗證（沿用既有 `logSink` 形態），不讀取 `developer.log` 輸出。

### 6.2 Step 6 切票建議

| 票 | 群組 | 依賴 | 預期紅燈 |
|----|------|------|---------|
| Schema 邊型解碼（FR-01） | S6 | `0.4.0-W2-001` | S6 新案例 10 紅；既有 schema 測試 0 紅（S6-10 驗證） |
| Graph 核心：輕節點、抽取、分類、建邊、聯集、結果（FR-02～06） | G1～G6、G8、L1、L2 | Schema 票 | 新案例全紅；既有 0 |
| Graph 鄰接查詢（FR-08） | G7、L3、G9 | Graph 核心 | 新案例全紅；既有 0 |
| TicketDetail（FR-07） | T1 | Corpus 事件型別（既有） | T1 全紅；既有 0 |
| Diagnostics 圖結構破洞（FR-09） | D3 | Graph 事件型別 | D3 全紅；既有 `parse_failure_gap_test` 0 紅 |
| 參照實作與凍結測資 | `tool/spec007_reference.py`、`test/fixtures/spec007/` | `0.4.0-W2-001`（UC-01 兩來源）、型別表含基數 | selftest 綠；不產生 Dart 紅燈 |
| IT-1～3 | IT-1、IT-2、IT-3、實體化器 helper | 以上全部 | IT 全紅，直到前五張完成 |

合計 7 張。Graph 核心涵蓋六個 FR，功能職責數超過 3b 派發閾值時再依 G1～G3（節點與引用值）與
G4～G6（建邊與結果）拆為兩張，即 8 張。各票驗收含 §1.3 import 方向檢查。
