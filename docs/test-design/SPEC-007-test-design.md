---
id: SPEC-007-test-design
title: "SPEC-007 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-007
spec_version: "1.2"
delta_spec_version: "1.18"
ticket: 0.4.0-W1-059
delta_ticket: 0.5.0-W1-114.4
created: "2026-09-30"
updated: "2026-10-08"
---

# SPEC-007 Phase 2 紅燈測試規格

本文件是 SPEC-007 v1.2（建圖：輕節點、邊的聯集與圖結構破洞）的紅燈測試規格，供
version-bootstrap Step 6 建實作票。只描述測資、流程與斷言，不含測試程式碼。規則權威在
SPEC-007；本文件與其衝突時以 SPEC-007 為準，衝突本身記入承接票的 NeedsContext。

**版本依據**：全文依據 v1.2，個別案例已標註其後版本（v1.3、v1.5、v1.8、v1.13）。`0.5.0-W1-113`
只增改受 v1.11～v1.15 影響的案例：FR-01 `direction` 補值與使用中邊型納入 `bundle_dependency`
（S6-2、S6-9、S6-12 改寫，S6-14～S6-17）、FR-05 無向判定（S6-13 既有，不改）、FR-08 回傳項帶
`layer`（G7-1 改寫，G7-8～G7-10）、FR-09 flow 三子類（D4）、FR-10 `flowOf`（G10）、FR-11 名稱解析（G11）。
案例與實作票對照見 §7。

**v1.16～v1.17 差異（`0.5.0-W1-114.2`，前一輪 `delta_ticket` 為 `0.5.0-W1-113`）**：FR-01 內建表也沒有的邊型
回報來源值「預設（有向）」（S6-15 改寫，N-B）；FR-06 `graphDefects` 筆數含 flow 子類（G6-3 改寫、G6-5、G6-6，
N-A）；FR-09 flow 第四子類「`traverses` 鍵缺席」與「domain 重複宣告」子類（D4 改寫為四子類、D4-6、D5）；
FR-11 去重、缺鍵、部分已宣告、重複 domain 宣告（G11-11～G11-18，N-D／N-E）；新增 FR-12 domain × UC
關係與依賴路徑（G12，承接原 `docs/test-design/SPEC-001-test-design.md` V1、V2）。IT 凍結值與 G9 不變（IT-INV-5）。

**v1.18 差異（`0.5.0-W1-114.4`，前一輪 `delta_ticket` 為 `0.5.0-W1-114.2`）**：依 `0.5.0-W1-114.2` 用戶裁決 R1，
新增 FR-13 DomainBundle 分層（1a，max+1）與層內排序（2b，code point），推不出層者接在最後（G13）；原
`docs/test-design/SPEC-001-test-design.md` L1-1～L1-3、L2-1～L2-4 的列序推導規則隨裁決改歸 Graph，於 G13 承接。
FR-12 依賴路徑排序改依 FR-13（G12-7、G12-9 排序來源改寫，NC-6 已處置；G13-13 為 E1 對照）。IT 凍結值不變
（FR-13 是查詢，IT 不呼叫；IT-INV-5 (c) 同理延伸）。

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

各實作票驗收含上述 import 方向檢查（`package:` 與相對路徑的 `import`、以及 `export` 皆計入，差集為零；判準同 SPEC-001-test-design §1.4，`0.5.0-W1-114.9` 雙審回報，PM 處置 2026-10-09）。

### 1.4 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 |
|--------|------|------|---------|
| 邊型表建構器 | `test/helpers/spec007/edge_table_builder.dart` | 以宣告方式建出含指定邊型（鍵名、class、正反向欄位、基數、layer、direction，`direction` 可指定為缺席）與版本的型別表 JSON | S6、G1～G11 |
| rawNode 建構器 | `test/helpers/spec007/raw_node_builder.dart` | 以 `id`、型別、路徑與 frontmatter map 建 `rawNode`；UC 另可附掛步驟清單（SPEC-006 FR-09 的形狀：每步一個原樣 map） | G1～G11、T1、D3 |
| DomainBundle 建構器 | `test/helpers/spec007/domain_bundle_builder.dart` | 以 `id`、`domain`、`depends_on_bundles` 建 DomainBundle `rawNode`，`id` 可不符 `DOMAIN-MAP-<domain>` 慣例 | G7-8～G7-10、G11 |
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

### 2.7 v1.11～v1.15 變更對 IT 與 G9 的影響：凍結值與計數不變（`0.5.0-W1-113`）

| 斷言 | 內容 | 依據 |
|------|------|------|
| IT-INV-1 | `test/fixtures/spec007/` 下全部凍結檔（`type_table.json`、`graph_manifest.json`、`ticket_detail_samples.json`、三份 `expected_*.json`、README）本輪**一律不改**；IT1-A1～A6、IT2-A1～A6、IT3-A1～A6 斷言文字不改 | 下列三點 |
| IT-INV-2 | 使用中邊型加入 `bundle_dependency` 不改變凍結邊集合：manifest 無任何列帶 `depends_on_bundles`（凍結檔實測 0 筆），實體化樹不產生該邊型的引用值 | FR-01、D6 |
| IT-INV-3 | `direction` 補值不改變凍結邊集合：凍結 `type_table.json` 的邊型條目不帶 `direction`、產生版本 2.60.13 不高於內建 2.77.0，依 FR-01 自內建表補值，`association` 仍為無向。IT1-A1、IT1-A2 因此兼為補值規則的端到端正向對照：若實作把缺欄當 `directed`，IT1-A2 翻紅 | FR-01（v1.14）、FR-05 |
| IT-INV-4 | flow 子圖與名稱解析不改變凍結值：實體化器只寫最小 frontmatter、不寫 UC 本文，各 UC 步驟清單為空，`flowOf` 無缺陷；FR-10 子圖不進 EVT-GRAPH-001 邊集合，`expected_edges.json`、`expected_defects.json`、`expected_counts.json` 不變 | FR-10、FR-11 |
| G9-INV | G9-1（`test/performance/graph_build_scaling_test.dart`）的案例數、合成語料、操作計數斷言不改：flow 子圖與名稱解析不屬 NFR-02 的「引用值」範圍；名稱解析的線性性本輪不另立量測案例 | NFR-02 |
| IT-INV-5（v1.16／v1.17） | 凍結檔與 IT1～IT3 斷言文字本輪仍**一律不改**，G9-INV 照舊成立：(a) 實體化樹無 UC 本文，flow 四子類缺陷恆為 0 筆，FR-06 筆數公式新增的 flow 項為 0，`expected_defects.json`／`expected_counts.json` 不變；(b) manifest 的兩個 DomainBundle `id` 相異且皆無 `domain` 欄，名稱索引為空，不產生「domain 重複宣告」缺陷；(c) FR-12 是查詢、不改 EVT-GRAPH-001 負載，IT 不呼叫；(d) S6-15 的來源值只在專案表有內建表沒有的邊型時出現，凍結 `type_table.json` 的邊型皆在內建表內 | FR-01、FR-06、FR-09、FR-11、FR-12 |

實測記錄：凍結檔中 `"direction"` 出現 0 次、`depends_on_bundles` 出現 0 次、`schema_generated_at_framework_version` 為 2.60.13；內建 `builtin_schema_version.json` 為 2.77.0（2026-10-08，本 worktree 讀取）。
`graph_manifest.json` 中 `"domain"` 鍵出現 0 次、DomainBundle ID 為 `DOMAIN-MAP-balance-sheet`、`DOMAIN-MAP-docs-graph` 各 1；凍結 `type_table.json` 的 16 個邊型鍵皆在內建 `builtin_tracking_schema.json` 的 17 個鍵內，差集為空（2026-10-08，`0.5.0-W1-114.2` worktree 讀取）。
重凍結以覆蓋 flow 子圖、名稱解析、`bundle_dependency` 由 `0.5.0-W1-001.6` 分析。

## 3. 5b 內圈：逐 bundle 測試案例

案例編號：`S`＝Schema、`G`＝Graph、`T`＝TicketDetail、`D`＝Diagnostics、`L`＝日誌事件、`N`＝NFR。
「守衛」代表對象是判定或攔截邏輯，已附正向對照輸入（E2）。

### 3.1 Schema bundle

#### S6 邊型解碼（FR-01）

**測試檔**：`test/unit/schema/edge_type_decoding_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| S6-1 | 真實內建型別表 asset | 解碼 | 邊型鍵集合等於 asset `edge_types` 鍵集合；每個邊型帶鍵名、class、`forward_field`、`reverse_field`、正向基數、layer |
| S6-2（v1.13 改寫） | 同上 | 取使用中邊型 | 等於 established 邊型集合扣除 `domain_dependency`、加上 `bundle_dependency`（集合以 asset 計算，不寫死數字） |
| S6-3 | 測試型別表新增 established 邊型 `testEdge`（欄位 `test_refs`） | 取使用中邊型 | 含 `testEdge`；另於 G2-9 驗 Graph 依其欄位抽取 |
| S6-4 | 測試型別表把某使用中邊型 `forward_field` 改名 | 解碼 | 邊型帶新欄位名；另於 G2-10 驗 Graph 不讀舊欄位名 |
| S6-5 | 專案型別表缺 `edge_types`，版本等於內建 | 解碼 | 邊型集合與內建表相同，建圖可用 |
| S6-6 | 專案型別表缺 `edge_types`，版本低於內建 | 解碼 | 同 S6-5 |
| S6-7（守衛） | 專案型別表缺 `edge_types`，版本高於內建 | 解碼 | 建圖不可用，帶原因碼（與 SPEC-006 FR-08 同一套）；正向對照為 S6-5 |
| S6-8（守衛） | 專案型別表有 `edge_types` 但某邊型缺正向基數，版本高於內建 | 解碼 | 建圖不可用；同一表版本改為等於內建時，基數由內建補值、可用（正向對照） |
| S6-9（v1.13 改寫，守衛） | 內建 asset 中 layer 為 proposed、鍵名不是 `bundle_dependency` 的邊型 | 取使用中邊型 | 全部不在其中；正向對照為 S6-16 |
| S6-10 | 既有 `node_types` 解碼 | 解碼含 `edge_types` 的表 | 節點型別解碼結果與未含 `edge_types` 時相同（版本契約第 2 欄「既有 node_types 解碼測試不變」） |
| S6-11（守衛） | 專案型別表整份缺席（`projectSchemaJson` 為 null） | 解碼 | 建圖不可用，原因碼為版本不在已知範圍；正向對照為 S6-12（SPEC-007 v1.3） |
| S6-12（v1.13 改寫） | 降級模式：內建表 asset 作為專案型別表傳入 | 解碼 | 建圖可用；使用中邊型等於 asset 的 established 邊型扣除 `domain_dependency`、加上 `bundle_dependency`（SPEC-007 v1.3、v1.13） |
| S6-13（守衛） | 真實內建型別表 asset；另以邊型表建構器建一份與 asset 相同、僅改指定邊型 `direction` 的測試用型別表 | 讀 `edge_types`；以同一 fixture（A 的 `relatedTo` 列出 B，B 未列 A）建圖 | asset 中 `direction` 為 `undirected` 的邊型集合等於 Graph 認定為無向的邊型集合（目前為 {`association`}）；`spec_association`、`uc_association`、`proposal_association` 的 `direction` 為 `directed`，Graph 照有向處理；`association` 的 `forward_field` 為 `relatedTo`、`reverse_field` 為 null，A 與 B 的鄰接均含對方（對稱聯集）。正向對照（守衛）：測試用型別表把某個 see-also 邊型（如 `spec_association`）的 `direction` 改為 `undirected`，該邊型即做對稱聯集，證明判定依欄位而非鍵名。E1 對照：同一 fixture 下僅把 `association` 的 `direction` 改為 `directed`，建出有向邊 A→B，查 B 的方向為入而非無向，結果與改動前不同；兩份型別表的產物必須不同（SPEC-007 v1.13 FR-05、D6：無向由 `direction` 判定，已無 `association` 鍵名例外）。測試檔放 `test/unit/graph/undirected_edge_contract_test.dart`：需讀 Graph 的無向認定，§1.3 不允許 schema 測試 import graph |
| S6-14（v1.14，守衛） | 專案型別表＝內建 asset 移除全部邊型的 `direction` 欄，版本等於內建；fixture：A 的 `relatedTo` 列出 B，B 未列 A | 解碼；建圖；查 A、B 鄰接 | `association` 的 `direction` 為 `undirected`、來源回報為內建表；A、B 鄰接均含對方（缺欄不得當 `directed`）。E1 對照：同一 fixture 以帶 `direction` 的原表解碼，`direction` 值相同而來源回報為專案表——兩份產物的來源欄必須不同，證明補值確實發生而非剛好相同。鄰接部分放 `test/unit/graph/undirected_edge_contract_test.dart`（§1.3） |
| S6-15（v1.16 改寫，E1） | 專案型別表在 S6-14 的表上另加內建表沒有的邊型 `testEdge`（缺 `direction`），版本等於內建 | 解碼 | `testEdge` 的 `direction` 為 `directed`，來源值為「預設（有向）」（以實作提供的具名常數比對）；同一張表中 S6-14 的 `association` 來源值為「內建表」。兩者不同，證明第三個來源值確實存在、不與內建表同值（N-B 已由 `0.5.0-W1-113` PM 處置定案） |
| S6-16（v1.13，正向對照） | 內建 asset | 取使用中邊型 | 含 `bundle_dependency`，其 `layer` 為 `proposed`（取自表） |
| S6-17（v1.13，E1 鑑別） | 測試型別表：在內建 asset 上把 `bundle_dependency` 鍵名改為 `bundle_dependency_x`（其他欄不變） | 取使用中邊型 | 不含 `bundle_dependency_x`；與 S6-16 結果不同，證明納入依 D6 的鍵名允許清單，而非「所有 proposed 皆納入」 |

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
| G6-3（v1.16 改寫） | 建圖完成，fixture 含主圖四類缺陷各一、flow 四子類缺陷各一，無重複 domain 宣告 | 恰一筆 EVT-GRAPH-001；`graphDefects` 筆數等於斷邊＋格式錯誤＋`duplicateId`＋`multiSource`＋FR-09 各 flow 子類缺陷數（此例 8 筆）。「domain 重複宣告」是否計入此公式見 §6.3 NC-4，本案例不含 |
| G6-4 | 同一邊多次宣告 | `edgeCount` 只計一次 |
| G6-5（v1.16，守衛：E2 正向對照） | 主圖無缺陷；某 UC 一個步驟 `traverses: ["nope"]`、`nope` 未宣告 | `graphDefects` 筆數為 1；只計主圖四類的實作在此為 0（FR-06 驗收新增條） |
| G6-6（v1.16，E1） | G6-5 的 fixture；對照組把 `nope` 改為已宣告的名稱 | 筆數 1 對 0；`nodeCount`、`edgeCount` 兩組相同 |

#### G7 鄰接查詢（FR-08）

**測試檔**：`test/unit/graph/adjacency_query_test.dart`

| # | Given | Then |
|---|-------|------|
| G7-1（v1.13 改寫） | 子票 `source_ticket` 指向父票 | 查子（出）得父；查父（入）得子；每項帶邊型、另一端、方向、宣告來源、`layer`（此例為 `established`） |
| G7-2（守衛） | 篩選只含 `blocking`，節點同時有 `blocking` 與 `spawn` 邊 | 只回傳 `blocking`；正向對照：不篩選時兩者皆回傳 |
| G7-3 | 無向邊，方向篩選為出、入、兩者 | 三種都回傳該邊，方向標為無向 |
| G7-4 | 不存在的 ID | 空清單 |
| G7-5（守衛） | 建圖不可用（S6-7 的型別表） | 任何查詢回傳「圖不可用」，不是空清單；正向對照：可用圖上查無鄰居的節點回傳空清單。兩者型別可窮舉區分 |
| G7-6 | 尚未完成建圖 | 回傳「圖不可用」 |
| G7-7 | 預設參數 | 邊型預設為全部使用中邊型（含 `bundle_dependency`）、方向預設兩者 |
| G7-8（v1.13） | DomainBundle A 的 `depends_on_bundles: [B 的 id]`，另有子票以 `source_ticket` 指向父票；內建 asset | 查 A（出）得 B，邊型 `bundle_dependency`、`layer` 為 `proposed`；查子票（出）回傳項 `layer` 為 `established`（對照） |
| G7-9（v1.13，E1 鑑別） | G7-8 的 fixture，測試型別表把 `bundle_dependency` 的 `layer` 改為 `established` | 查 A 的回傳項 `layer` 為 `established`；與 G7-8 不同，證明 `layer` 取自型別表、不以鍵名判定 |
| G7-10（v1.13，守衛） | A 的 `depends_on_bundles: [DOMAIN-MAP-nope]`，圖上無此節點 | 一筆 `danglingRef`（`targetMissing`），邊型 `bundle_dependency`，不建邊；正向對照為 G7-8（值走 FR-03 ID 解析，不經 FR-11 名稱解析器） |

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

#### G10 UC flow 子圖 `flowOf`（FR-10；v1.11～v1.12 新增）

**測試檔**：`test/unit/graph/flow_of_test.dart`
**測資**：rawNode 建構器（UC 附掛步驟清單）；步驟 map 原樣構造，不經 Corpus

| # | Given（單一 UC 的步驟清單，依清單順序） | Then |
|---|------------------------------------|------|
| G10-1 | s1、s2（`branch_from` 缺席）、s3（`branch_from: null`）、s4（`branch_from: ""`）、b1（`branch_from: s1`） | 主線為 s1、s2、s3、s4（三種空值皆判主線，依清單順序）；分支為 b1 並帶指向 s1 |
| G10-2 | 主線 a（`next: c`）、b、c，清單順序 a、b、c | 主線順序 a、b、c；不產生缺陷（主線 `next` 不解析） |
| G10-3（E1 鑑別） | G10-2 再加一個主線步驟 m（`next: zzz`，不存在）；對照組：分支步 b2（`branch_from: a`、`next: zzz`） | 前者無缺陷，後者一筆「flow 參照未解析」（欄位 `next`）。兩組同一原始值、結果不同，證明 `next` 只在分支步解析 |
| G10-4（守衛） | b1 的 `branch_from: ghost`（同 UC 無此 id） | b1 仍在子圖內、該參照標未解析；一筆「flow 參照未解析」，負載 {UC ID, `b1`, `branch_from`, `ghost`}；正向對照為 G10-1 的 b1（已解析、無缺陷） |
| G10-5（守衛） | 分支步 b1 的 `return_to: ghost`；另一分支步 b2 的 `next: ghost2` | 各一筆「flow 參照未解析」，欄位分別為 `return_to`、`next`；b1、b2 仍在子圖內 |
| G10-6 | `return_to: s2`（存在） | 回指項帶 b1 指向 s2；無缺陷 |
| G10-7（守衛） | 兩步 id 皆為 `x`（一在主線、一為分支） | 兩步都在子圖內、各依自身 `branch_from` 落位；恰一筆「UC 內 step id 重複」，欄位 `id`、原始值 `x`；正向對照：id 改為 `x`、`y` 時零缺陷 |
| G10-8 | G10-7 再加分支步 r（`return_to: x`） | 該參照標未解析；缺陷共兩筆：一筆「UC 內 step id 重複」、一筆「flow 參照未解析」（r，`return_to`，`x`） |
| G10-9 | UC-A、UC-B 各有一步 id 為 `rescan` | 零缺陷；`flowOf(UC-A)` 與 `flowOf(UC-B)` 各含自己的 `rescan` |
| G10-10（守衛） | UC-A 的 b1 `branch_from: only_in_b`，該 id 只存在於 UC-B | b1 的參照標未解析、一筆缺陷（不跨 UC 解析）；正向對照為 G10-9 |
| G10-11 | 步驟屬性 | 每步帶 `id`、`name`、`next`、`emits`、`consumes`、`traverses` 原值與 `traverses` 解析結果；原值不修剪、不轉型 |
| G10-12 | 步驟清單為空的 UC；不在圖上的 ID；SPEC 節點的 ID | 前者回傳空子圖（主線、分支、回指皆空）；後兩者回傳「不存在」。三種回傳可窮舉區分 |
| G10-13（守衛） | 建圖不可用（S6-7 的型別表）；建圖尚未完成 | 皆回傳「圖不可用」，不是空子圖、不是「不存在」；正向對照為 G10-12 的空子圖 |
| G10-14（E1 鑑別） | 同一組 rawNodes，一份 UC 附掛含缺陷的步驟清單（G10-4、G10-7 的形態），另一份同 rawNodes 但步驟清單全空 | 兩次建圖的 `edgeCount`、各邊型邊數、FR-03 三類計數完全相同；`graphDefects` 只差 flow 缺陷。證明子圖不進邊集合也不汙染主圖計數 |
| G10-15 | G10-4、G10-5、G10-7 的缺陷 | 負載鍵集合恰為 {UC ID, step id, 欄位, 原始值}，不含邊型 |

缺陷子類的程式識別名：前三種 flow 子類由 `0.5.0-W1-001.8` NeedsContext 上報；第四種 flow 子類與「domain 重複宣告」由實作票命名（SPEC-007 v1.17 FR-09，`0.5.0-W1-114.1` NC-c）。測試一律以實作提供的具名常數比對，命名前不得以字面寫入。

#### G11 `traverses` 名稱解析（FR-11；v1.11 新增）

**測試檔**：`test/unit/graph/traverses_resolution_test.dart`
**測資**：DomainBundle 建構器＋rawNode 建構器

| # | Given | Then |
|---|-------|------|
| G11-1 | DomainBundle `id: DOMAIN-MAP-corpus`、`domain: corpus`；步驟 `traverses: [corpus]` | 解析到該 DomainBundle 的節點 ID；無缺陷 |
| G11-2（守衛） | `traverses: [nope]`，無 bundle 宣告 `nope` | 一筆「`traverses` 名稱未宣告」，負載 {UC ID, step id, `traverses`, `nope`}；正向對照為 G11-1 |
| G11-3（守衛） | 宣告為 `corpus`；`traverses: [Corpus]`、`[" corpus"]` 各一步 | 各一筆缺陷（區分大小寫、不去空白）；正向對照為 G11-1 |
| G11-4（E1 鑑別） | bundle P：`id: DOMAIN-MAP-alpha`、`domain: beta`；`traverses: [beta]` 與 `traverses: [alpha]` 各一步 | `beta` 解析到 P；`alpha` 為缺陷。兩者結果不同，證明以 `domain` 欄索引而非由 ID 拼接或拆解 |
| G11-5 | bundle `id` 不符 `DOMAIN-MAP-<domain>` 慣例（例如 `BUNDLE-x`）、`domain: x`；`traverses: [x]` | 解析成功 |
| G11-6 | `traverses: []` | 無解析結果、無缺陷 |
| G11-7 | 同一步 `traverses: [corpus, nope, nope2]` | `corpus` 解析成功；兩筆缺陷（逐值各一） |
| G11-8 | SPEC 帶 `depends_on_domains: [corpus]` | 不建邊、不產生缺陷、使用中邊型不含 `domain_dependency` |
| G11-9 | 解析器公開面 | 輸入名稱字串，輸出 DomainBundle 節點 ID 或「未宣告」；不需 FlowStep 物件即可呼叫 |
| G11-10 | `bundle_dependency` 的值 `DOMAIN-MAP-corpus` | 走 FR-03 ID 解析（見 G7-8），解析器不被呼叫（以注入計數或 spy 驗證呼叫次數為 0） |
| G11-11（v1.16，E1：去重） | 一步 `traverses: ["nope", "nope"]`；對照組 `traverses: ["nope", "nope2"]`（皆未宣告） | 前者一筆缺陷、後者兩筆（以（步驟, 值）去重，N-E 已由 `0.5.0-W1-113` PM 處置定案） |
| G11-12 | 步驟 A、B 各有 `traverses: ["nope"]` | 兩筆缺陷（去重以步驟為單位，不跨步驟合併） |
| G11-13（v1.16，守衛＋E1：缺鍵對 `[]`） | 步驟 S1 沒有 `traverses` 鍵；步驟 S2 `traverses: []` | S1 一筆「`traverses` 鍵缺席」缺陷，負載 {UC ID, `S1`, `traverses`, `null`}（原始值為 null，不是空字串或空清單）；S2 零缺陷。兩者解析結果皆為空，缺陷輸出不同（不得把缺鍵當 `[]`） |
| G11-14（v1.16） | 一步 `traverses: ["graph", "nope"]`，`graph` 已宣告 | 解析結果只含 `graph` 的 DomainBundle；一筆 `nope` 的「`traverses` 名稱未宣告」 |
| G11-15（v1.16／v1.17，守衛＋E1：重複 domain） | DomainBundle P1（`id: DOMAIN-MAP-corpus`）、P2（`id: BUNDLE-corpus-2`）皆 `domain: corpus`；步驟 `traverses: ["corpus"]`。對照組把 P2 的 `domain` 改為 `corpus2` | 前者：`corpus` 解析為未宣告（一筆「`traverses` 名稱未宣告」）＋一筆「domain 重複宣告」，負載 `domain` 為 `corpus`、衝突 ID 清單的集合為 {P1, P2}（不斷言清單順序）；P1、P2 仍是圖節點，皆出現在 DomainBundle 節點集合中。對照組：`corpus` 解析到 P1、零缺陷。兩組結果不同，證明不取其一解析成功（D-3） |
| G11-16（v1.17） | P1、P2、P3 三者皆 `domain: corpus` | 恰一筆「domain 重複宣告」（每個重複的 `domain` 值一筆），衝突 ID 清單集合為 {P1, P2, P3} |
| G11-17（v1.17） | P1、P2 皆 `domain: corpus`；P3、P4 皆 `domain: graph` | 兩筆「domain 重複宣告」，`domain` 分別為 `corpus`、`graph` |
| G11-18（v1.16） | G11-15 前者的 bundle，UC 有兩步各 `traverses: ["corpus"]` | 兩筆「`traverses` 名稱未宣告」（每步一筆）；「domain 重複宣告」仍只一筆（與引用次數無關） |

#### G12 domain × UC 關係與依賴路徑（FR-12；v1.16 新增，承接原 SPEC-001-test-design V1、V2）

**測試檔**：`test/unit/graph/domain_uc_relation_test.dart`（group `三值判定`：G12-1～G12-6；group `依賴路徑`：G12-7～G12-12；group `邊界`：G12-13～G12-15）
**測資**：DomainBundle 建構器＋rawNode 建構器（UC 附掛步驟清單），本專案語料取凍結快照（`0.5.0-W1-114` PM 處置 N1，快照凍結為 Step 6 一張票）
**判定式權威**：SPEC-001 §1〈間接依賴判定式〉〈間接依賴格的詳情卡：依賴路徑〉；本群組斷言 Graph 回傳值，畫面只顯示（SPEC-001-test-design ITD1、ITD3 為外圈）

| # | 原編號 | Given | Then |
|---|-------|-------|------|
| G12-1 | V1-1 | 本專案快照 | 48 格中直接貫穿 19、間接依賴 10、無關 19；間接 10 格為 UC-02、UC-03、UC-05 各 {`schema`, `workspace`}，UC-04 {`corpus`, `schema`, `workspace`}，UC-06 {`schema`} |
| G12-2 | V1-2 | 直接優先：UC 直接貫穿 Y 且 Y 亦自 X 可達 | 直接貫穿 |
| G12-3（E1：方向） | V1-3 | UC 貫穿 X，Y 依賴 X（Y 為上游） | 無關；把邊反向後同格變為間接，兩次結果不同 |
| G12-4 | V1-4 | 3 跳可達（X→A→B→Y） | 間接（不限跳數） |
| G12-5 | V1-5 | UC 貫穿 X1、X2，兩者皆可達 Y | (Y, UC) 一個間接結果（不重複計格） |
| G12-6 | V1-6 | flutter_balance 快照 | 間接 0 格 |
| G12-7 | V2-1 | UC-04 × `schema` | 間接依賴，兩條路徑，依序 `graph → corpus → schema`、`ticketdetail → corpus → schema`（v1.18：同長依來源在 FR-13 排序中的先後，`graph` 先於 `ticketdetail`；NC-6 已處置） |
| G12-8（E1：排除經直接 domain） | V2-2 | UC-06 × `schema` | 一條路徑 `corpus → schema`；不含 `diagnostics → corpus → schema`（未套排除規則時會多出此條） |
| G12-9 | V2-3 | 同來源兩條同長最短路徑 | 兩條皆列，依中間節點在 FR-13 排序中的先後（v1.18） |
| G12-10 | V2-4 | 不同長度 | 短的在前 |
| G12-11 | V2-5 | 直接貫穿格、無關格 | 依賴路徑為空 |
| G12-12 | V2-6 改寫 | 路徑元素 | 每條路徑為 DomainBundle 序列，元素可取回 `domain` 原值；Graph 不產生顯示字串（「→」連接與 i18n 不變屬畫面，由 ITD3-A1 外圈承擔） |
| G12-13（v1.16，E1：只計解析成功值） | — | 步驟 `traverses: ["graph"]`；對照組把 `graph` 改為重複宣告（G11-15 形態）或步驟缺 `traverses` 鍵 | 前者 (graph, UC) 為直接貫穿；對照組兩種皆非直接貫穿（未宣告、缺鍵、重複宣告被排除的名稱不構成直接貫穿） |
| G12-14（守衛） | — | 建圖不可用（S6-7 的型別表）；建圖尚未完成 | 皆回傳「圖不可用」，不是「無關」；正向對照為 G12-11 的無關格（可用圖） |
| G12-15 | — | 不在圖上的 DomainBundle ID 或 UC ID | 回傳值可與三值、「圖不可用」區分（回傳形態由實作票定；介面識別名交 Step 6 的 Graph 間接依賴實作票，`0.5.0-W1-114.1` NC-c） |

G12-15 的「不存在」回傳形態 SPEC-007 FR-12 未定義，見 §6.3 NC-5。

#### G13 DomainBundle 分層與層內排序（FR-13；v1.18 新增，承接原 SPEC-001-test-design L1-1～L1-3、L2-1～L2-4）

**層**：全部為 domain unit（Graph bundle，Graph 公開面查詢，不經畫面、不依賴 Layout）。
**測試檔**：`test/unit/graph/bundle_layer_order_test.dart`（group `分層`：G13-1～G13-3；group `層內排序`：G13-4～G13-7；
group `推不出層與邊界`：G13-8～G13-12；group `FR-12 共用排序`：G13-13）
**測資**：DomainBundle 清單與 `bundle_dependency` 邊以建構器宣告；G13-1 取本專案凍結快照
**承接票**：Graph 間接依賴實作票（與 G12 同票，見 §7；介面識別名由該票定，FR-13 規則末條）
**功能職責歸屬**：本群組只依賴建圖結果（DomainBundle 節點與 `bundle_dependency` 邊），不依賴 G12；G13-13 讀 G12 的回傳，
是唯一跨群組案例，可由 G12 的實作者一併承擔

| # | 原編號 | Given | Then |
|---|-------|-------|------|
| G13-1 | L1-1 | 本專案快照 | 排序結果 `schema`、`workspace`、`corpus`、`history`、`diagnostics`、`graph`、`ticketdetail`、`layout`；層 L0 {`schema`, `workspace`}、L1 {`corpus`, `history`}、L2 {`diagnostics`, `graph`, `ticketdetail`}、L3 {`layout`}（FR-13 驗收 #1） |
| G13-2（E1：max 對 min） | L1-2 | A→{B, C}、C→B、B 無出邊 | A 為 L2（所依賴 bundle 最大層＋1）；以最小層＋1 計算會得 L1，斷言結果與後者不同 |
| G13-3 | L1-3 | `history` 只依賴 `workspace` | `history` 為 L1（2026-10-08 裁決第 1 項的回歸點） |
| G13-4 | L2-1 | 同層 `graph`、`diagnostics`、`ticketdetail` | 序為 `diagnostics`、`graph`、`ticketdetail` |
| G13-5（E1：code point 對 locale） | L2-2 | 同層 `b`、`B`、`a-z`、`a_z` | 依 Unicode code point：`B`、`a-z`、`a_z`、`b`；locale 排序會把 `B` 排在 `a-z` 之後，斷言結果與 locale 序不同 |
| G13-6（E1：標點的 code point） | — | 同層 `ab`、`a-c` | 序為 `a-c`、`ab`（連字號 U+002D 小於 `b` U+0062）；忽略標點的 locale 排序會把 `a-c` 當 `ac` 而得 `ab`、`a-c`，斷言結果與後者相反 |
| G13-7 | L2-3 | G13-5、G13-6 的輸入，執行環境 locale 切 zh 與 en 各跑一次 | 兩次結果逐值相同 |
| G13-8（守衛） | L2-4 | X→Y、Y→X 成環，另有正常 bundle Z | Z 依層排序；X、Y 不消失，依 code point 接在全部可分層 bundle 之後（FR-13 驗收 #2）；正向對照為 G13-1（無環時無 bundle 接在最後） |
| G13-9（守衛） | L2-5 前半 | X 的依賴指向未宣告的 `ghost`，另有正常 bundle Z | X 接在最後；排序結果不含 `ghost`；正向對照為 G13-1。「指向 `ghost` 的邊不畫」屬 Layout，留在 SPEC-001-test-design L2-5 |
| G13-10 | — | G13-8 的成環 X、Y 與 G13-9 的 X′（指向未宣告）並存 | 三者一起接在最後，彼此依 code point 序（兩種推不出層的原因不分組） |
| G13-11（E1：不寫死 domain 名） | — | 本專案快照的 8 個 `domain` 全部換成另一組名稱，依賴邊不變 | 層歸屬與快照逐位相同；層內順序依新名稱的 code point 重排，結果與 G13-1 的名稱序不同 |
| G13-12（守衛） | — | 建圖不可用（S6-7 的型別表）；建圖尚未完成 | 皆回傳「圖不可用」，不是空排序；正向對照為 G13-1 |
| G13-13（E1：FR-12 路徑排序依 FR-13 而非純 code point） | — | `y` 為 L0；`m`→`y`、`k`→{`y`, `m`}、`zeta`→`m`、`alpha`→`k`；UC 只貫穿 `zeta`、`alpha` | FR-13 序中 `zeta`（L2）先於 `alpha`（L3）；FR-12 回傳 UC × `y` 的兩條同長路徑依序 `zeta → m → y`、`alpha → k → y`。純 code point 排序會把 `alpha` 排前，斷言結果與後者相反（FR-13 驗收 #3；`0.5.0-W1-114.2` 被放棄選項「改純 code point 排序」） |

L2-6（換 UC 列序不變）與 L1-4（單一 bundle 的總列數）屬 Layout 的列組裝，不移入本群組。FR-13 本身不接受 UC 參數，
「與 UC 無關」在 Graph 側由介面形態保證，不另立案例。

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

#### D4 flow 四子類（FR-09；v1.12 新增，v1.16 改為四子類）

**測試檔**：`test/unit/diagnostics/flow_defect_gap_test.dart`

| # | Given | Then |
|---|-------|------|
| D4-1（v1.16 改寫） | EVT-GRAPH-001 含 flow 四子類各一（含「`traverses` 鍵缺席」） | 四筆 `graphDefect`，子類各自相符，負載 {UC ID, step id, 欄位, 原始值} 與缺陷逐一相符，不含邊型 |
| D4-2（v1.16 改寫，E1） | 同時含主圖四子類各一與 flow 四子類各一 | 八筆破洞；報告分組為主圖組四筆、「flow」小組四筆；破洞大類列舉不增加（皆為 `graphDefect`） |
| D4-3 | flow 缺陷原始值為帶前後空白的字串 | 原樣保存，不修剪 |
| D4-4（守衛） | 建圖不可用狀態 | 零筆 flow 破洞，回報無法判定；正向對照為 D4-1 |
| D4-5 | 破洞負載 | 不含在地化字串 |
| D4-6（v1.17，E1） | 「`traverses` 鍵缺席」缺陷（原始值 null）；對照組為 `traverses` 值為空字串 `""` 的「名稱未宣告」缺陷 | 前者破洞原始值為 null，後者為 `""`；兩筆子類與原始值皆不同（null 不被轉成空字串） |

#### D5 domain 重複宣告（FR-09、FR-11；v1.17 新增）

**測試檔**：同上，group `domain 重複宣告`

| # | Given | Then |
|---|-------|------|
| D5-1 | EVT-GRAPH-001 含一筆「domain 重複宣告」，負載 {`corpus`, [P1, P2]} | 一筆 `graphDefect`，子類相符，負載 `domain` 與衝突 ID 清單原樣保存 |
| D5-2（E1：分組） | 同時含 D5-1 的缺陷與 flow 四子類各一、主圖四子類各一 | 九筆破洞；「domain 重複宣告」在主圖組（主圖組五筆），「flow」小組仍為四筆（`0.5.0-W1-114.1` PM 第二小輪 NC-2：屬 DomainBundle 節點而非 flow） |
| D5-3 | 破洞負載 | 不含在地化字串；不含 UC ID、step id 欄 |

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
| FR-01 | 12 | IT2-A5；IT1-A1、A2（IT-INV-3） | S6-1～S6-17、G2-9、G2-10 | L2 |
| FR-02 | 3 | IT-3（A1、A3）；IT-1 合成 `duplicate_id` 列 | G1-1～G1-6 | — |
| FR-03 | 8 | IT-2（A1～A4） | G2-1～G2-8、G3-1～G3-9 | L1 |
| FR-04 | 6 | IT-1（A1、A3、A4） | G4-1～G4-9 | — |
| FR-05 | 4 | IT-1（A1、A2） | G5-1～G5-3、S6-13 | — |
| FR-06 | 4 | IT-2（A3；IT-INV-5） | G6-1～G6-6 | L1 |
| FR-07 | 2 | IT-3（A2、A5） | T1-1～T1-5 | — |
| FR-08 | 5 | IT-1（A2、A3） | G7-1～G7-10 | L3 |
| FR-09 | 3 | IT-2（A1、A5、A6） | D3-1～D3-5、D4-1～D4-6、D5-1～D5-3 | L2 |
| FR-10 | 10 | —（IT-INV-4） | G10-1～G10-15 | — |
| FR-11 | 10 | —（IT-INV-4、IT-INV-5） | G11-1～G11-18 | — |
| FR-12 | 4 | —（IT-INV-5；外圈由 SPEC-001-test-design ITD1、ITD3 承擔） | G12-1～G12-15、G13-13 | — |
| FR-13 | 3 | —（查詢，IT 不呼叫；外圈由 SPEC-001-test-design ITD2-A1、A4 的列序承擔） | G13-1～G13-13 | — |
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
| FR-01 其餘 proposed 不是使用中邊型 | S6-9、S6-16、S6-17 |
| FR-01 邊型值為字串（版本已知／較高） | 既有 L2-4 與 `0.4.0-W4-016` 系列案例，本輪未複核 |
| FR-01 全部缺 `direction`、版本已知 | S6-14 |
| FR-01 內建表也沒有的邊型缺 `direction` | S6-15 |
| FR-05 see-also 改 `undirected`／`association` 改 `directed` | S6-13 |
| FR-08 `bundle_dependency` 的 `layer` 為 proposed | G7-8、G7-9 |
| FR-10 #1 兩語料逐項一致 | 無單元案例；需語料或重凍結（`0.5.0-W1-001.6`） |
| FR-10 #2～#10 | G10-2、G10-4、G10-5、G10-7、G10-8、G10-15＋D4-2、G10-9、G10-12、G10-14 |
| FR-11 #1 兩語料全部解析 | 無單元案例；需語料或重凍結（`0.5.0-W1-001.6`） |
| FR-11 #2～#5 | G11-2、G11-3、G11-5、G11-8 |
| FR-11 #6 同一步驟重複未宣告名稱只報一筆 | G11-11 |
| FR-11 #7 缺 `traverses` 鍵回報缺陷、`[]` 不回報 | G11-13 |
| FR-11 #8 部分已宣告 | G11-14 |
| FR-11 #9 重複 domain 宣告（含兩者仍為節點） | G11-15、D5-1 |
| FR-11 #10 缺鍵缺陷負載欄位 `traverses`、原始值 null | G11-13、D4-6 |
| FR-06 #4 主圖無缺陷、一個未宣告名稱時筆數為 1 | G6-5、G6-6 |
| FR-12 #1 本專案快照 19／10／19 | G12-1 |
| FR-12 #2 UC-04 × `schema` 兩條路徑 | G12-7 |
| FR-12 #3 UC-06 × `schema` 排除經直接 domain | G12-8 |
| FR-12 #4 直接貫穿格路徑為空 | G12-11 |
| FR-13 #1 本專案快照排序 | G13-1 |
| FR-13 #2 互相依賴接在最後、依 code point | G13-8 |
| FR-13 #3 FR-12 同長路徑先後與 FR-13 一致 | G12-7、G13-13 |
| FR-01 內建表也沒有的邊型來源值「預設（有向）」 | S6-15 |
| FR-02 #1 五欄、無共用引用 | G1-1、IT3-A1 |
| FR-02 #2 重複 ID | G1-4 |
| FR-02 #3 指向重複 ID | G1-5 |
| FR-03 #1～#8 | G3-1、G3-2～G3-4、G3-5、G3-6、G2-2、G2-5、G2-7、G3-8 |
| FR-04 #1～#6 | G4-1～G4-6 |
| FR-05 #1、#2 | G5-1、G5-2 |
| FR-06 #1～#3 | G6-1、G6-2、G6-3（v1.16 改寫） |
| FR-07 #1、#2 | T1-1、T1-2 |
| FR-08 #1～#5 | G7-1、G7-2、G7-8、G7-4、G7-5 |
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
| Diagnostics | 「什麼算破洞」 | D3、D4、D5、IT2-A1 |
| Graph | domain × UC 關係與依賴路徑由 Graph 判定，畫面只顯示 | G12 |
| Graph | DomainBundle 分層與層內排序只有一份，泳道列序與依賴路徑排序共用（v1.18） | G13 |

## 5. 測試案例統計

| Bundle／圈 | 群組 | 案例數 |
|-----------|------|-------|
| 5a 外圈 | IT-1、IT-2、IT-3 | 18（v1.15 不增減） |
| Schema | S6 | 17（S6-1～S6-17） |
| Graph | G1～G13 | 118（v1.2 的 52，加 G7-8～G7-10、G10 十五案、G11 十案；v1.16／v1.17 加 G6-5、G6-6、G11-11～G11-18、G12 十五案，G6-3 改寫不計增；v1.18 加 G13 十三案，其中七案自 SPEC-001-test-design 移入，G12-7、G12-9 改寫不計增） |
| TicketDetail | T1 | 5 |
| Diagnostics | D3、D4、D5 | 14（v1.16／v1.17 加 D4-6、D5 三案；D4-1、D4-2 改寫不計增） |
| 日誌 | L1～L3 | 9 |
| 合計 | | 181 |

前版統計 100 漏計 S6-13 與 L2-4（兩者為後續版本追加時未同步本表），本輪一併以實際列數更正。

守衛型案例與正向對照：IT1-A5、IT1-A6、IT2-A4、IT3-A4、IT3-A6、S6-7、S6-8、S6-9、S6-11、S6-13、S6-14、G1-4、G3-5、G3-6、G3-9、G4-4、
G7-2、G7-5、G7-10、G10-4、G10-5、G10-7、G10-10、G10-13、G11-2、G11-3、G11-13、G11-15、G6-5、G12-14、G13-8、G13-9、G13-12、T1-3、D3-4、D4-4、L2-3、L3-2，均已附正向對照輸入。
E1 鑑別對照：IT1-A2、IT2-A5、IT2-A6、G2-9、G2-10、G4-8、G5-1、L1-2；v1.15 變更 FR 新增 S6-14、S6-17（FR-01）、
S6-13（FR-05，既有）、G7-9（FR-08）、G10-3、G10-14（FR-10）、G11-4（FR-11）、D4-2（FR-09，主圖與 flow 兩組對照）；
v1.16／v1.17 新增 S6-15（FR-01）、G6-6（FR-06）、G11-11、G11-13、G11-15（FR-11）、G12-3、G12-8、G12-13（FR-12）、D4-6、D5-2（FR-09）；
v1.18 新增 G13-2、G13-5、G13-6、G13-11、G13-13（FR-13）。

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

### 6.3 v1.15 輪的 NeedsContext（`0.5.0-W1-113`，寫入票面）

- **N-A（已處置，SPEC-007 v1.16）**：筆數含 flow 子類。落點 G6-3 改寫、G6-5、G6-6。
- **N-B（已處置，同上）**：來源值「預設（有向）」。落點 S6-15 改寫。
- **N-C（部分處置，SPEC-007 v1.17 FR-09）**：前三種 flow 子類識別名仍由 `0.5.0-W1-001.8` 上報；第四子類與「domain 重複宣告」由實作票命名（`0.5.0-W1-001.4` 或 `0.5.0-W1-001.5`，NC-c）。測試以具名常數比對的原則不變。
- **N-D（已處置，`0.5.0-W1-113` D-3、`0.5.0-W1-114.1` NC-d）**：落點 G11-15～G11-18、D5。
- **N-E（已處置，`0.5.0-W1-113` PM 處置）**：（步驟, 值）去重。落點 G11-11、G11-12。

本輪新增（`0.5.0-W1-114.2`，未在裁決內，不自行填補）：

- **NC-4**：FR-06 驗收的 `graphDefects` 筆數公式寫「主圖四類＋FR-09 各 flow 子類」，未列「domain 重複宣告」；FR-09 將其列為 `graphDefect` 子類、D5 依 W1-119 驗收歸報告主圖組，但它是否經 EVT-GRAPH-001 的 `graphDefects` 傳遞、是否計入 FR-06 筆數未明寫。G6-3 本輪不含此子類。
- **NC-5**：FR-12 對「不在圖上的 DomainBundle 或 UC ID」的回傳未定義（FR-08、FR-10 皆有「不存在」回傳）。G12-15 只斷言可與三值、「圖不可用」區分，回傳形態未定。
- **NC-6（已處置，`0.5.0-W1-114.2` 用戶裁決 R1，SPEC-007 v1.18 FR-13）**：分層與層內排序歸 Graph，FR-12 依 FR-13 排序。落點 G12-7、G12-9 改寫、G13。

本輪新增（`0.5.0-W1-114.4`，未在裁決內，不自行填補）：

- **NC-8**：FR-13「推不出層」只列「依賴循環」與「依賴指向未宣告的 bundle」兩種原因，未寫依賴於推不出層者的 bundle（例：W→X，X 在環中，W 本身不在環內）是否同樣推不出層。依 1a 的「所依賴 bundle 的最大層＋1」，X 無層時 W 的層無法計算，但條文未明寫 W 接在最後。G13 本輪不設此組合；SPEC-001 §1 摘錄同此缺口。
- **NC-9**：FR-13 未寫 Graph 公開面是否回傳每個 bundle 的層號，或只回傳排序結果。G13-2、G13-3 的「A 為 L2」「`history` 為 L1」以層號斷言；若公開面只回傳排序，這兩案須改為以排序位置間接驗證（G13-2 改為 A 排在 C 之後且 C 排在 B 之後的結構）。由承接實作票決定介面時一併確認。
- **NC-7**：第四 flow 子類與「domain 重複宣告」的命名承接票為 `0.5.0-W1-001.4` 或 `0.5.0-W1-001.5`（NC-c 擇一未定），影響 G11-13、G11-15～G11-17 的承接票。

## 7. 案例 ↔ 實作票對照（v1.15～v1.18 輪）

| 案例 | 實作票 | 備註 |
|------|-------|------|
| S6-14、S6-15（v1.16 改寫） | `0.5.0-W1-001.7` | 該票 what 含解碼 `direction`、`EdgeTypeEntry` 參數必填；缺欄補值（v1.14）與來源值「預設（有向）」（v1.16）晚於該票建立，Step 6 須確認是否併入或另立 |
| S6-13（既有，不改） | `0.5.0-W1-001.7` | 該票 what 已指名改 S6-13 斷言欄位 |
| S6-2、S6-9、S6-12（改寫）、S6-16、S6-17 | `0.5.0-W1-103.2` | 含 K5 契約改寫（`bundle_dependency` 不在使用中 → 在使用中） |
| G7-1（改寫）、G7-7（改寫）、G7-8～G7-10 | `0.5.0-W1-103.2` | 該票 what 含 proposed 標記與「指向未宣告 bundle 的值須成破洞」 |
| G10-1～G10-15 | `0.5.0-W1-001.4` | |
| G11-1～G11-10 | `0.5.0-W1-001.5` | |
| G11-11、G11-12、G11-14、G11-18 | `0.5.0-W1-001.5` | 名稱解析器的去重、部分已宣告、逐步回報 |
| G11-13、G11-15～G11-17 | `0.5.0-W1-001.5`（暫）／`0.5.0-W1-001.4` | 第四子類與「domain 重複宣告」的命名承接票擇一未定（NC-7）；解析行為屬名稱解析器，暫列 001.5 |
| D4-1～D4-6、D5-1～D5-3 | `0.5.0-W1-119` | 該票驗收「flow 子類報告分組」「重複 domain 宣告子類歸報告主圖組」 |
| G6-3（改寫）、G6-5、G6-6 | 待 Step 6 建票 | Graph 建圖結果（FR-06）；flow 缺陷由 001.4／001.5 產生，彙入 `graphDefects` 的計數屬建圖結果單元 |
| G12-1～G12-15 | 待 Step 6 建票 | Graph 間接依賴（FR-12）；介面識別名由該票定（NC-c）；依賴 `0.5.0-W1-001.5`、`0.5.0-W1-103.2`、快照凍結票 |
| G13-1～G13-13（v1.18） | 待 Step 6 建票（併 G12 同票） | Graph 分層與層內排序（FR-13）；G12-7、G12-9、G13-13 依賴本群組，同票實作免跨票等待；依賴 `0.5.0-W1-103.2`（`bundle_dependency` 進主圖）、快照凍結票（G13-1）。Layout 列序票改向本群組取列序（SPEC-001-test-design L8） |
| IT-INV-1～5、G9-INV | `0.5.0-W1-001.6` | 重凍結分析；未重凍結前斷言即為「不改」 |
| FR-10 #1、FR-11 #1（兩語料） | `0.5.0-W1-001.6` | |

**Step 6 建議分組**（本檔待建票者，依實作單元分組）：

1. Graph 建圖結果計數：G6-3、G6-5、G6-6（可併入下一組或 001.4／001.5 其一，由 Step 6 決定）
2. Graph 間接依賴與分層排序（FR-12、FR-13）：G12、G13 全部（與 SPEC-001-test-design §6.2 第 2 組為同一張票）。
   功能職責數為 2，若超過 3b 派發閾值可拆為 G13（先）與 G12（後）兩張，G12-7、G12-9、G13-13 歸後者

`0.5.0-W1-001.3` 屬 SPEC-006（見該檔 §7）；`0.5.0-W1-096.5`、`0.5.0-W1-096.7` 本檔無對應案例（屬 SPEC-001 路徑比對器與 SPEC-006 FR-10）。
