---
id: SPEC-006-test-design
title: "SPEC-006 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-006
spec_version: "1.8"
delta_spec_version: "1.23"
ticket: 0.3.0-W1-084
delta_ticket: 0.5.0-W1-130
created: "2026-09-24"
updated: "2026-10-09"
---

# SPEC-006 Phase 2 紅燈測試規格

本文件是 SPEC-006 v1.8（Corpus 解析與破洞判定）的紅燈測試規格，供 version-bootstrap
Step 6 建實作票。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-006；本文件
與其衝突時以 SPEC-006 為準，衝突本身記入承接票的 NeedsContext。

**版本依據**：全文依據 v1.8（v1.5～v1.8 逐版覆核見 §8，`0.5.0-W1-113.2`）；`0.5.0-W1-113` 另增改受
v1.15 影響的三處——FR-07 新計數項（C10-6～C10-8）、FR-08 收 EVT-CORPUS-004（D1-3 改寫、D1-5、
D1-6）、FR-09 UC flow 區塊解析（C12、C13），對照表見 §7。`spec_version` 記全文覆核到的版本，
`delta_spec_version` 記只覆核局部變更的版本，兩者分開。

**v1.16～v1.17 差異（`0.5.0-W1-114.2`）**：FR-08 破洞數改為三項公式、EVT-CORPUS-004 破洞帶型別 UC 且
不依賴路徑查詢（`0.5.0-W1-113` N4／N5）、收 EVT-CORPUS-005（D1-3 改寫、D1-5 改寫、D1-7～D1-9、
D2-5～D2-7）；FR-10 非 domain 路徑清單檔格式錯誤（C14）；原因碼識別名 `flowBlockMalformed`、
`nonDomainPathsMalformed` 與子原因 `NonDomainPathsMalformedReason` 落地（C13-8 改寫）。IT 凍結值不變（IT-INV-4）。
前一輪 `delta_ticket` 為 `0.5.0-W1-113`。

**v1.18～v1.19 差異（`0.5.0-W1-114.4`，前一輪 `delta_ticket` 為 `0.5.0-W1-114.2`）**：FR-10 依 `0.5.0-W1-096.7` 用戶裁決
第二批 1C／2A 與 `0.5.0-W1-114.3` 用戶裁決 A3／C3′：規則 1 位置欄位空字串視為缺欄回落內建表（C15-1、C15-2）；規則 2a
非字串元素略過、其餘生效、一輪一筆 `elementNotString` 帶 `nonStringElementCount`、非 domain 側不視為未宣告（C15-3～C15-6、
C15-9～C15-11）；規則 2b 字串元素不檢查格式（C15-7、C15-8）；EVT-CORPUS-005 負載新增 `nonStringElementCount`（C14-7 改寫）；
Diagnostics 消費 `elementNotString`（D1-10）。程式修正承接 `0.5.0-W1-123`（main 現為轉字串照收與空字串照收）。IT 凍結值不變
（IT-INV-4：實體化樹無清單檔）。

**v1.22～v1.23 差異（`0.5.0-W1-130`，前一輪 `delta_ticket` 為 `0.5.0-W1-114.4`）**：只覆核 FR-09 規則 3c、3d 與
EVT-CORPUS-004 `reason` 形態。規則 3c 非 map 項目略過、發一筆 004（C13-12～C13-14），範圍為任一 flow 區塊（C13-17，未實作）；
規則 3d 未閉合圍欄（C13-15、C13-15b、C13-16）；`reason` 以原因碼開頭、可附說明，比對改前綴（C13-8 改寫）；實作補強 L1。
編號與描述以 `0.5.0-W1-001.3` 已合併的測試檔為準回填。v1.20（FR-08／FR-10）與 v1.21（FR-10 規則 3）不在本輪覆核範圍，
見 `0.5.0-W1-130` NeedsContext。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-1、IT-2 兩項整合測試 | 版本契約（PROP-005 §0.3）的驗收終點 | 與框架或參照實作的行為分歧 |
| 5b 內圈 | 逐 bundle 的 domain unit 測試 | 各 domain map §3〈Bundle 不變式清單〉逐條斷言 | 單一不變式被打破，可直接定位 |

外圈綠而內圈紅、或反之，都代表測資沒有涵蓋到對應形態，須補測資而非放寬斷言。

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| Schema 路徑對型別查詢、型別表來源判定 | domain unit（純函式） | 型別表以測試內建的最小表物件注入，不讀 asset |
| Corpus 切分、分類、判型、事件組裝、lostFields、守恆計數 | domain unit | 使用真實 Schema 查詢物件（Sociable），不 mock Schema |
| Corpus 掃描（FR-02、FR-05、NFR-01） | unit | 檔案系統以 port 注入（Corpus domain map §7 FR-02 列）；FR-05 權限與消失兩個子原因用 fake port，編碼用真實位元組 |
| Diagnostics 破洞產生 | domain unit | 輸入直接構造 EVT-CORPUS-003 值物件與「查詢可用性」狀態 |
| IT-1、IT-2 | integration（`test/integration/`） | 不 mock：讀真實檔案、真實 Schema 查詢、真實 Diagnostics |

Mock 只替換外部世界（檔案系統 port、asset 讀取）；Schema、Corpus、Diagnostics 三個 bundle
之間一律用真實物件，重構內部結構時測試不需改動。

### 1.3 依賴方向與測試隔離

依系統層 §2 與 §7：

- `test/unit/schema/` 不得 import `lib/corpus/`、`lib/diagnostics/`
- `test/unit/corpus/` 可 import `lib/schema/`，不得 import `lib/diagnostics/`
- `test/unit/diagnostics/` 只 import `lib/diagnostics/` 與 `lib/corpus/`（事件型別），不得 import `lib/schema/`（Diagnostics → Schema 邊已刪除）
- 只有 `test/integration/` 的兩項 IT 可同時 import 三者

上列「import」涵蓋 `package:` 與相對路徑寫法，以及 `export`；判準同 SPEC-001-test-design §1.4（`0.5.0-W1-114.9` 雙審回報，PM 處置 2026-10-09）。

### 1.4 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 |
|--------|------|------|---------|
| 最小型別表建構器 | `test/helpers/spec006/type_table_builder.dart` | 以宣告方式建出含指定路徑模式、具體度、完整性集合、版本的型別表 | S1～S5、C3、C5、C6 |
| 真實型別表 fixture | `test/helpers/spec006/real_type_table.dart` | 讀取 `.claude/skills/doc/doc_system/core/tracking_schema.json` 的真實型別表 | S1、S2、K2、K3 |
| 記憶體檔案系統 fake | `test/helpers/spec006/fake_docs_fs.dart` | 實作掃描用的檔案系統 port，可指定每個路徑的位元組、權限拒絕、列出後消失，以及指定目錄「無法列出」 | C1、C8、C9、C10 |
| 暫存目錄實體化器 | `test/helpers/spec006/manifest_materializer.dart` | 依 IT-2 manifest 在暫存目錄寫出真實檔案 | IT-2、C9 |
| UC 本文建構器 | `test/helpers/spec006/uc_body_builder.dart` | 以宣告方式組出「合法 UC frontmatter＋本文」位元組：依序放入任意個 fenced yaml 區塊，每個區塊指定為合法 flow、壞掉的 flow（頂層 `flow:` 行＋YAML 語法錯誤）、`flow:` 行被縮排的壞區塊、無 `flow` 鍵的 yaml、`flow` 為空清單或非清單 | C10-6、C10-7、C12、C13 |

各群組只透過 helper 取得 fixture，不共享 mutable 狀態，可分派給不同代理人獨立實作。

## 2. 5a 外圈

### 2.1 IT-1 解析語意（FR-01；traceability 第三軸契約 K1）

**測試檔**：`test/integration/corpus_it1_frontmatter_equivalence_test.dart`

**測資目錄**：`test/fixtures/spec006/it1/`

| 內容 | 路徑 | 形態 |
|------|------|------|
| 樣本檔 | `test/fixtures/spec006/it1/samples/<name>.md` | 原樣入庫，位元組不改動（含 BOM、`\r\n`） |
| 框架函式凍結輸出 | `test/fixtures/spec006/it1/expected.json` | 每個樣本一筆：`name`、`source`（`corpus:<專案>/<相對路徑>` 或 `synthetic`）、`framework_result`（`split` 或 `none`）、`frontmatter_text`（切出的原始 YAML 文字，`none` 時為 null）、`keys`（排序後鍵清單，`none` 時為 null）、`naive_key_count`（天真語意的鍵數，YAML 錯誤時為 null）、`naive_yaml_error`（bool）、`expected_result`（SPEC-006 FR-01 五類之一） |
| 凍結說明 | `test/fixtures/spec006/it1/README.md` | 凍結日期、框架 `.claude/VERSION`、凍結指令、排除規則 |

**樣本組成**（SPEC-006 D3「IT-1 樣本」）：

| 編號 | 樣本 | 來源 | expected_result |
|------|------|------|----------------|
| IT1-R | 至少一份 frontmatter 含引號字串 `"|---|---|"` 的真實 ticket，天真語意會截斷 | 真實語料（凍結時從 `~/project` 選取） | 可用 |
| IT1-S1 | 帶 BOM 且 frontmatter 合法 | 合成 | 可用 |
| IT1-S2 | 只有開頭 `---` | 合成 | 未閉合 |
| IT1-S3 | `---` 後緊接 `---` | 合成 | 空或非 map |
| IT1-S4 | 只含註解 | 合成 | 空或非 map |
| IT1-S5 | 內容為 `{}` | 合成 | 空或非 map |
| IT1-S6 | YAML 結果為清單 | 合成 | 空或非 map |
| IT1-S7 | 第一行不是 `---` | 合成 | 無 frontmatter |
| IT1-S8 | `\r\n` 行尾且 frontmatter 合法 | 合成 | 可用 |

**排除規則**（寫入 README 並由測試自我驗證）：樣本不得含 `\x0b`、`\x0c`、`\x1c`～`\x1e`、`\x85`、U+2028、U+2029；樣本必須是合法 UTF-8。

**凍結流程**（離線一次，CI 不執行）：

1. 選出 IT1-R，複製原檔位元組到 `samples/`；合成樣本以位元組寫入
2. 在凍結機器上對每個樣本呼叫框架 `frontmatter_parser.py` 的切分函式（`_find_closing_delimiter` 所在路徑），記錄 `frontmatter_text` 與 `keys`
3. 對每個樣本以 `split("---")` 天真語意取第二段並 YAML 解析，記錄 `naive_key_count` 或 `naive_yaml_error`
4. 寫入 `expected.json` 與 README，一次 commit

**斷言**：

| # | Given | When | Then |
|---|-------|------|------|
| IT1-A1 | `expected.json` 所列每個樣本 | 以待測實作解析 | 結果分類等於 `expected_result` |
| IT1-A2 | `framework_result` 為 `split` 的樣本 | 以待測實作切分 | 切出的 frontmatter 文字等於 `frontmatter_text`；鍵集合等於 `keys`（不比值） |
| IT1-A3 | IT1-R | 讀 `expected.json` 的天真語意紀錄 | `naive_yaml_error` 為 true，或 `naive_key_count` 小於待測實作鍵數（判別樣本有鑑別力） |
| IT1-A4（守衛，E2） | 全部樣本 | 掃描位元組 | 不含排除字元且為合法 UTF-8；另以一個測試內建的含 U+2028 的字串作正向對照輸入，斷言排除檢查會攔下它 |
| IT1-A5（守衛，E2） | 全部樣本 | 對 `expected.json` 做完整性檢查 | 每個 `samples/` 檔案恰有一筆紀錄、反之亦然；另以測試內建的「少一筆」清單作正向對照，斷言完整性檢查會回報缺漏 |
| IT1-A6 | 樣本集合 | 統計 `source` | 至少一筆 `corpus:` 來源且 IT1-A3 對它成立；IT1-S1～S7 七類合成樣本各至少一筆 |

IT1-A3 本身即為 FR-01 規則 6 的正向對照：若判別樣本在天真語意下不會截斷，此測試不具鑑別力，須換樣本。

### 2.2 IT-2 破洞分類（FR-01、FR-05、FR-06、FR-08）

**測試檔**：`test/integration/corpus_it2_gap_classification_test.dart`

**測資**：`test/fixtures/spec006/it2/manifest.yaml`（凍結）+ `test/fixtures/spec006/it2/README.md`

**manifest 列欄位**（SPEC-006 D3「manifest 欄位」，補上實體化所需欄位）：

| 欄位 | 值域 | 說明 |
|------|------|------|
| `path` | 相對路徑，`/` 分隔，位於 `docs/` 下 | 實體化目標 |
| `shape` | `usable`／`no_frontmatter`／`unclosed`／`empty_or_non_map`／`yaml_error`／`unreadable_encoding` | 檔案形態；只供實體化器使用 |
| `id` | 字串或 null | `shape: usable` 時寫入的 `id`；null 表示不寫 `id` 鍵 |
| `expected.kind` | `node`／`non_node`／`gap`／`failure_unmatched` | 預期結果大類 |
| `expected.node_type` | 型別名或 null | `node` 時的型別；`gap` 命中一型時的歸屬型別 |
| `expected.candidate_types` | 型別名清單 | `gap` 平手時的候選 |
| `expected.schema_ambiguous` | bool | 平手時 true |
| `expected.reason` | FR-01 四類或「無法讀取」 | 失敗檔的原因 |
| `synthetic` | bool | 語料中沒有、以合成補上的列為 true |
| `source` | 字串 | 真實列的來源專案與原路徑 |

manifest 檔頭另記：凍結日期、參照實作版本、所用型別表的 `schema_generated_at_framework_version`、
以及凍結時的預期計數（FR-07 全部計數項）。

**IT-2 型別表**：凍結時所用的型別表 JSON 一併入庫為 `test/fixtures/spec006/it2/type_table.json`，
測試以它注入 Schema，不讀 App 內建表或 `.claude/` 的即時檔（避免上游改動使凍結預期失效）。
平手列需要多型別衝突，但真實型別表的兩兩具體度經設計不打平；因此型別表另加一個合成型別
（標記 `synthetic: true`），其模式與某既有型別對一條合成路徑具體度相同。

**樣本覆蓋**（SPEC-006 D3「樣本覆蓋」四類，加上 FR-07 各計數項）：

| 類 | 最少列數 | 範例 |
|----|---------|------|
| 命中 carrier 一型的失敗檔 | 每種失敗形態（五種）各 1 | `docs/domain-map.md` 無 frontmatter → DomainBundle |
| 未命中的失敗檔 | 2 | `docs/work-logs/<v>/<note>.md` 的 YAML 錯誤；`docs/spec/<d>/README.md` 無 frontmatter |
| 多型別衝突（平手）的失敗檔 | 1 | 合成型別與既有型別打平的合成路徑 |
| 多型別命中、具體度可分出者 | 1 | `docs/spec/<d>/domain-map.md` 無 frontmatter → DomainBundle（不是 SPEC） |
| 無法讀取（編碼） | carrier 內 1、carrier 外 1 | 無效 UTF-8 位元組 |
| 可用且判為節點 | 每個具路徑模式的型別各 1 | `id: SPEC-001` 等 |
| 可用但非節點 | 2 | 無 `id`；`id: v0.1.0-note` |

**實體化流程**（SPEC-006 D3「實體化」）：

1. 建立暫存目錄作為工作區根，於其下依 `path` 建目錄
2. 依 `shape` 寫檔：`usable` 寫最小 frontmatter（`id` 與該型別完整性集合全部鍵）；`no_frontmatter` 寫純 markdown；`unclosed` 只寫開頭 `---` 與內容；`empty_or_non_map` 寫 `---\n---`；`yaml_error` 寫不合法 YAML；`unreadable_encoding` 寫無效 UTF-8 位元組（例如單一 `0xFF`）
3. 經 Workspace 的根路徑來源與真實檔案系統 port 執行一輪完整掃描；掃描器不得讀 manifest

**斷言**：

| # | 斷言 |
|---|------|
| IT2-A1 | 對每一列，實際分類（節點型別／非節點／破洞歸屬／未命中失敗）等於 `expected` |
| IT2-A2 | 破洞集合與 `kind: gap` 的列一一對應：每筆破洞的路徑、歸屬型別（或候選型別與歧義標記）、原因與 manifest 一致，且無多出或缺少 |
| IT2-A3 | FR-07 全部計數項等於 manifest 檔頭的凍結計數；兩條守恆式成立 |
| IT2-A4（守衛，E2） | 實體化器對每一列都有寫檔規則：以一個測試內建、`shape` 為未知值的列作正向對照，斷言實體化器拒絕而不是略過 |
| IT2-A5（守衛，E2） | manifest 覆蓋檢查：上表每一類至少一列；以測試內建、缺平手列的 manifest 作正向對照，斷言覆蓋檢查回報缺漏 |
| IT2-A6（鑑別對照，E1） | 同一實體化樹以「路徑模式取不到」的型別表再掃一次，斷言結果與正常型別表不同：破洞數為 0、全部失敗檔計入未判定、並回報無法判定 |

**預期值來源**：獨立 Python 參照實作依 FR-06 規則產生、離線執行（SPEC-006 D3）。
該參照實作與凍結動作不在本票範圍，見 §6 的 Spawn Request。

### 2.3 v1.15 變更對 IT 的影響：凍結值不變（`0.5.0-W1-113`）

| 斷言 | 內容 | 依據 |
|------|------|------|
| IT-INV-1 | IT-1 的 `samples/`、`expected.json`，IT-2 的 `manifest.yaml`、`type_table.json` 與檔頭凍結計數，本輪**一律不改**；IT1-A1～A6、IT2-A1～A6 斷言文字不改 | FR-09 只作用於「判為 UC 的可用檔案」的本文；IT-2 實體化器對 `usable` 只寫最小 frontmatter、不寫本文，IT-1 只比切分語意 |
| IT-INV-2 | IT-2 實體化樹中「flow 區塊解析失敗的 UC 數」恆為 0，故 FR-08 新公式的破洞數＝命中 carrier 數，與凍結值相同；IT2-A2 的破洞集合不變 | FR-08 破洞數公式（v1.13） |
| IT-INV-3 | FR-07 新計數項不寫入 IT-2 manifest 檔頭、IT2-A3 不比對它；該計數項的覆蓋由 C10-6～C10-8 承擔 | 守恆式不變（FR-07） |
| IT-INV-4（v1.16／v1.17） | IT-2 實體化樹不含非 domain 路徑清單檔（檔案不存在不是格式錯誤，FR-10 規則 3），EVT-CORPUS-005 恆為 0 筆；FR-08 三項公式的第二、三項皆為 0，破洞數仍等於命中 carrier 數，IT2-A2 的破洞集合與凍結值不變；IT-1 只比切分語意，不受 FR-10 影響 | FR-08（v1.16）、FR-10 |

是否重凍結 IT 測資以覆蓋 flow 區塊（含 FR-09 驗收第一條「兩語料步驟數 40、9」）由 `0.5.0-W1-001.6`
分析，本規格不預先改動凍結值。

## 3. 5b 內圈：逐 bundle 測試案例

案例編號：`S`＝Schema、`C`＝Corpus、`D`＝Diagnostics。每個群組對應單一功能職責，
可獨立分派。「守衛」標記代表該案例的對象是判定或攔截邏輯，已附正向對照輸入（E2）。

### 3.1 Schema bundle

#### S1 路徑比對：完整路徑與大小寫（FR-06 規則 1、4）

**測試檔**：`test/unit/schema/carrier_path_lookup_test.dart`，group `完整路徑與大小寫`
**型別表**：真實型別表 fixture

| # | Given | When | Then |
|---|-------|------|------|
| S1-1（守衛） | `docs/spec/ui/README.md` | 查詢 | 未命中（正向對照見 S1-2） |
| S1-2 | `docs/spec/ui/SPEC-001-x.md` | 查詢 | 命中 SPEC（證明 S1-1 的未命中來自 README 排除而非目錄不匹配） |
| S1-3 | `docs/work-logs/v0/note.md` | 查詢 | 未命中 |
| S1-4 | `docs/work-logs/v0/v0.1/tickets/0.1.0-W1-001.md` | 查詢 | 命中 Ticket（S1-3 的正向對照） |
| S1-5 | `docs/Spec/ui/SPEC-001-x.md`、`docs/usecases/uc-01-x.md` | 查詢 | 皆未命中（區分大小寫；正向對照為 S1-2 與同名正確大小寫的 UC 路徑） |
| S1-6 | `docs/usecases/UC-01-x.md` | 查詢 | 命中 UC |
| S1-7 | 測試型別表中某型模式只寫目錄前綴可匹配的樣式，路徑為該目錄下的非 `.md` 同名檔 | 查詢 | 未命中（比對含檔名） |

#### S2 具體度二層比較（FR-06 規則 6）

**測試檔**：同上，group `具體度`

| # | Given | Then |
|---|-------|------|
| S2-1 | 真實型別表，`docs/spec/corpus/domain-map.md` | 回傳 DomainBundle（字面段 3 > SPEC 的 2） |
| S2-2 | 測試型別表 A `[3,1]`、B `[2,0]` 同時命中 | 回傳 A（字面段多者優先，即使跨段萬用較多） |
| S2-3 | 測試型別表 A `[2,1]`、B `[2,0]` 同時命中 | 回傳 B（字面段相同，跨段萬用少者優先） |
| S2-4 | 同一型別有兩個模式元素（如 DomainBundle 巢狀與根層）且都可能命中 | 以該型命中元素中最高的具體度參與比較 |

`specificity` 的計算由上游匯出（`tracking_schema.py` 註解），App 讀取不重算；S2 驗的是比較規則。
若實作選擇自行由樣板重算，另補「字面段只計整段固定文字」的案例（`{slug}.md` 與 `SPEC-*.md` 段不計）。

#### S3 平手（FR-06 規則 5、6）

**測試檔**：同上，group `平手`

| # | Given | Then |
|---|-------|------|
| S3-1 | 測試型別表 A、B 對同一路徑具體度皆 `[2,0]` | 回傳平手，候選為 {A, B}，schema 歧義為 true，不回傳單一型 |
| S3-2 | 三型打平 | 候選列出全部三型 |
| S3-3 | S3-1 的型別表把 B 改為 `[3,0]` | 回傳 B（S3-1 的鑑別對照：平手判定只在打平時觸發） |
| S3-4 | 回傳值型別 | 三種結果（未命中、一型、平手）可被窮舉區分，無第四種 |

#### S4 無路徑模式的型別不參與（FR-06 規則 3）

**測試檔**：同上，group `FlowStep`

排除依據為型別表中是否帶 `carrier_path_patterns` 欄位，不依型別名（SPEC-006 D9，用戶裁決 N2）。

| # | Given | Then |
|---|-------|------|
| S4-1（守衛） | 測試型別表：FlowStep 條目**不帶** `carrier_path_patterns`，UC 條目正常；查詢 `docs/usecases/UC-01-x.md` | 回傳 UC，候選中沒有 FlowStep |
| S4-2 | 測試型別表：新增一個名為 `Widget` 的測試型別，不帶 `carrier_path_patterns`；查詢任一路徑 | 該型別從不出現在結果中（證明排除依欄位而非型別名） |
| S4-3（正向對照） | 同一個名為 `FlowStep` 的條目，改為**帶**一個會命中 `docs/usecases/UC-01-x.md` 的模式 | 會命中並與 UC 形成候選（證明 S4-1 的結果來自欄位缺席，而不是寫死排除型別名） |

#### S5 型別表來源三分（FR-06 規則 7；契約 K4）

**測試檔**：`test/unit/schema/schema_source_resolution_test.dart`

| # | Given | Then |
|---|-------|------|
| S5-1 | 專案 JSON 有路徑模式欄位 | 查詢以 JSON 的模式執行；模式來源回報為專案 JSON |
| S5-2 | 專案 JSON 缺欄位，JSON 版本等於內建版本 | 路徑模式取自內建表，其餘（`id_pattern`、完整性集合）仍取自專案 JSON；模式來源回報為內建表 |
| S5-3 | 專案 JSON 缺欄位，JSON 版本低於內建版本 | 同 S5-2 |
| S5-4（守衛） | 專案 JSON 缺欄位，JSON 版本高於內建版本 | 查詢不可用（S5-2 為正向對照：同一 JSON 版本改為等於內建即可用） |
| S5-5 | 專案 JSON 與內建表都沒有路徑模式 | 查詢不可用 |
| S5-6（E1 鑑別） | S5-2 的型別表，專案 JSON `id_pattern` 刻意與內建表不同 | 判型用專案 JSON 的 `id_pattern`（證明只補路徑模式，非整表替換） |
| S5-7 | 版本比較 | `2.40.3` 對 `2.40.10` 判為低於（數值逐段比較，非字串比較） |
| S5-8（v1.7，守衛） | 專案 JSON 缺路徑模式欄位，且 JSON **沒有版本欄位** | 查詢不可用，原因碼為「版本不在 App 已知範圍」（正向對照：S5-2 補上等於內建的版本即可用） |
| S5-9（v1.7，守衛） | 專案 JSON 缺路徑模式欄位，版本欄位為無法解析的值（例如 `abc`、空字串） | 同 S5-8；不拋例外、不當作低於內建 |

S5-4、S5-8、S5-9 三者原因碼相同（v1.7「不在已知範圍」涵蓋高於、缺席、無法解析）；S5-5 的原因碼為
「型別表沒有路徑模式」，與前三者不同。判定式與 SPEC-001 schema 不相容關卡相同，本規格只在 Schema
層測判定結果，不測關卡畫面。

### 3.2 Corpus bundle

#### C1 結果分類恰好一種（FR-01、FR-05）

**測試檔**：`test/unit/corpus/frontmatter_classifier_test.dart`，group `結果分類`

| # | Given（位元組） | Then |
|---|----------------|------|
| C1-1 | 合法 frontmatter | 可用 |
| C1-2 | 第一行 `# title` | 無 frontmatter |
| C1-3 | 第一行 ` --- `（前後空白） | 不是無 frontmatter（規則 3 去空白後比對） |
| C1-4 | 只有開頭 `---` | 未閉合 |
| C1-5 | YAML 語法錯誤（例如未閉合的引號） | YAML 語法錯誤，帶行號（解析器提供時） |
| C1-6 | 無效 UTF-8 | 無法讀取，子原因編碼（不做寬鬆解碼：斷言沒有 U+FFFD 進入任何輸出） |
| C1-7 | 帶 BOM 的合法 frontmatter | 可用，第一個鍵名不含 BOM |
| C1-8 | 單一 `\r\n` 檔 | 與同內容 `\n` 檔結果相同 |
| C1-9 | 行內含 `\x0c` 或 U+2028 | 不作為行分隔（該字元所在行不被切開；對照 C1-8） |
| C1-10 | C1-1～C1-6 全部輸入 | 每個輸入恰得一種結果；結果型別為封閉枚舉（六種） |

#### C2 結尾定位與 `|---|`（FR-01 規則 4、6）

**測試檔**：同上，group `結尾定位`

| # | Given | Then |
|---|-------|------|
| C2-1 | frontmatter 內 `title: "|---|---|"`，之後正常結尾，正文另有 `---` | 可用；鍵集合含 `title` 與其後所有鍵；正文的 `---` 不影響 |
| C2-2 | 兩個獨立 `---` 行在第二行之後 | 取第一個作結尾 |
| C2-3（E1 鑑別） | C2-1 的輸入 | 測試內以 `split("---")` 天真語意取鍵數，斷言與 C2-1 的鍵數不同，證明輸入有鑑別力 |

#### C3 可用的非空 map 判定（FR-01）

**測試檔**：同上，group `空或非 map`

| # | Given frontmatter 內容 | Then |
|---|----------------------|------|
| C3-1 | 空 | 空或非 map |
| C3-2 | 只有註解 | 空或非 map |
| C3-3 | `{}` | 空或非 map |
| C3-4 | `- a\n- b` | 空或非 map |
| C3-5 | `hello`（純量） | 空或非 map |
| C3-6（正向對照） | `a: 1` | 可用 |

#### C4 節點判型（FR-03）

**測試檔**：`test/unit/corpus/node_typing_test.dart`
**型別表**：真實型別表 fixture（C4-1～C4-4）、測試型別表（C4-5）

| # | Given frontmatter | Then |
|---|------------------|------|
| C4-1 | `id: SPEC-001` | 節點，SPEC |
| C4-2 | `id: DOMAIN-MAP-docs-graph` | 節點，DomainBundle |
| C4-3 | 無 `id` 鍵 | 有 frontmatter 的非節點；無節點、無破洞、無 EVT-CORPUS-003 |
| C4-4 | `id: v0.1.0-note` | 同 C4-3 |
| C4-5（守衛） | 測試型別表兩型 `id_pattern` 都命中 `X-1` | 非節點，標記 schema 歧義；不產生節點（對照：只留一型時判為該型） |
| C4-6 | 可用檔位於某 carrier 路徑但 `id` 屬另一型 | 依 `id_pattern` 判型，不依路徑（系統層 §5） |
| C4-7（v1.6，E1 鑑別） | C4-5 的檔案（路徑 `docs/x/X-1.md`）經掃描 | 掃描結果的「schema 歧義非節點」清單含一筆：相對路徑 `docs/x/X-1.md`、候選型別 {兩型}。對照組為同一檔案改成 `id: Y-1`（無型命中）：歧義清單為空、非節點計數相同。兩組產物不同，證明歧義檔被保留而非只計數後丟棄 |

#### C5 EVT-CORPUS-003 發出條件（FR-04、D6、D7）

**測試檔**：`test/unit/corpus/parse_failure_event_test.dart`

| # | Given | Then |
|---|-------|------|
| C5-1 | `docs/domain-map.md` 無 frontmatter | 記入 `parseErrors`；發 EVT-CORPUS-003：`nodeType` DomainBundle、`candidateTypes` [DomainBundle]（或依負載約定）、`schemaAmbiguous` false、原因無 frontmatter |
| C5-2（守衛） | `docs/work-logs/v0/note.md` YAML 錯誤 | 記入 `parseErrors`；不發事件（C5-1 為正向對照） |
| C5-3 | 平手路徑的失敗檔（測試型別表） | 發事件：`nodeType` null、`candidateTypes` 列全部、`schemaAmbiguous` true |
| C5-4 | carrier 內 YAML 語法錯誤 | 發事件（D6：YAML 錯誤也走 carrier 分流） |
| C5-5 | carrier 內五種失敗原因各一 | 各發一筆，`reason` 值等於 EVT-CORPUS-003〈負載結構〉值域 |
| C5-6 | 查詢不可用（S5-4 的型別表） | 記入 `parseErrors`，不發事件，計入未判定 |
| C5-7 | 可用檔 | 不發事件（事件只對失敗檔） |

#### C6 lostFields 算法（FR-04、D5；契約 K3）

**測試檔**：`test/unit/corpus/lost_fields_test.dart`

lostFields 以純函式測（輸入：完整性集合、實際寫出的鍵與值、是否平手），因為 0.3.0 的失敗檔
沒有可用 frontmatter，經掃描流程取得的「實際寫出的鍵」恆為空，null／`[]` 算寫出的語意
無法經流程觸及；見 §6 NeedsContext N1。

| # | Given | Then |
|---|-------|------|
| C6-1 | DomainBundle 失敗檔（無寫出鍵） | `lostFields` = `{id, domain}` |
| C6-2（E1 鑑別，守衛） | 集合 `{id, title, status}`，寫出 `{id: X, title: null, status: []}` | `lostFields` 為空。對照輸入：寫出 `{id: X}`，`lostFields` = `{title, status}`；兩者結果必須不同，證明以鍵存在而非真值判斷 |
| C6-3 | 平手 | 空清單 |
| C6-4 | Ticket（無完整性集合） | 空清單 |
| C6-5 | 型別表無 `completeness_fields` 鍵（W1-079 之前的 JSON） | 空清單 |
| C6-6 | 集合順序 | 結果為集合語意，順序不影響相等判斷 |

#### C7 0.3.0 固定值（FR-04）

**測試檔**：同 C5，group `固定欄位`

| # | Given | Then |
|---|-------|------|
| C7-1 | C5-5 的五筆事件 | 每筆 `salvagedFields` 為 `[]`，`severity` 為 `edgeAffecting` |
| C7-2 | 失敗原因為 YAML 語法錯誤（即使部分鍵在錯誤行之前可讀） | `salvagedFields` 仍為 `[]`（不救回） |

#### C8 掃描範圍（FR-02）

**測試檔**：`test/unit/corpus/corpus_scanner_test.dart`，group `掃描範圍`
**檔案系統**：記憶體 fake

| # | Given | Then |
|---|-------|------|
| C8-1 | 無 `docs/` | 掃描完成，全部計數 0，無錯誤 |
| C8-2 | `docs/a/b/c/x.md` 多層 | 進入結果 |
| C8-3（守衛） | `docs/X.MD`、`README.md`（根層，`docs/` 外）、`docs/x.txt` | 皆不進入；同目錄的 `docs/x.md` 進入（正向對照） |
| C8-4（守衛） | `docs/link` 為指向 `docs/spec` 的符號連結 | 不經連結重複列出；`docs/spec/` 下的檔案只出現一次 |
| C8-5 | 回傳路徑 | 皆相對於工作區根、以 `/` 分隔、不含前導 `./` |
| C8-6 | 工作區根 | 取自 Workspace 的公開面（以 fake Workspace 提供），不自行推導 |
| C8-7（v1.6） | `docs/locked/` 無法列出（fake port 回報權限錯誤），`docs/a.md`、`docs/b/c.md` 正常 | 掃描完成；「無法列出的目錄」清單恰為 [`docs/locked`]（相對路徑）；掃描檔案總數為 2；兩條守恆式成立；寫一筆 warning 日誌 |
| C8-8（v1.6，E1 鑑別） | C8-7 的樹，對照組為 `docs/locked/` 可列出且含一檔 | 對照組「無法列出的目錄」為空、檔案總數 3；兩組產物不同，且 C8-7 的總數不含 `docs/locked/` 內任何檔案（證明無法列出的目錄不進守恆式，而非被當作 0 檔目錄） |

#### C9 讀取失敗子原因（FR-05）

**測試檔**：同上，group `讀取失敗`

| # | Given | Then |
|---|-------|------|
| C9-1 | carrier 內非 UTF-8 | 無法讀取／編碼；發事件；最終成為破洞（經 IT-2 覆蓋） |
| C9-2 | carrier 外非 UTF-8 | 記入 `parseErrors`，不發事件；掃描完成 |
| C9-3 | carrier 內權限拒絕（fake port 回報權限錯誤） | 無法讀取／權限 |
| C9-4 | 列出後、讀取前消失（fake port 回報不存在） | 無法讀取／檔案消失；掃描完成 |
| C9-5（實機補強，選做） | 暫存目錄中 `chmod 000` 的真實檔案 | 同 C9-3；以 root 執行時自動 skip 並說明 |

#### C10 守恆與計數（FR-07）

**測試檔**：同上，group `計數與守恆`

| # | Given | Then |
|---|-------|------|
| C10-1 | 分布已知的 fixture：節點、非節點、五種失敗原因、命中一型、平手、未命中各至少一檔 | 各計數項等於已知值；兩條守恆式成立 |
| C10-2 | 平手的失敗檔 | 計入命中 carrier 數 |
| C10-3 | 查詢不可用的型別表跑 C10-1 的 fixture | 失敗檔全部計入未判定；第二條守恆式仍成立；命中與未命中為 0 |
| C10-4（守衛） | 守恆檢查器 | 以一組刻意少算一檔的計數作正向對照，斷言守恆檢查回報失敗 |
| C10-5 | EVT-CORPUS-001 | `rawNodes` 每筆帶完整 frontmatter map、相對路徑、判定型別；不含邊 |
| C10-6（v1.15） | C10-1 的 fixture 另加 UC 兩份：U1 本文只有一個壞掉的 flow 區塊、U2 本文有兩個壞掉的 flow 區塊 | 「flow 區塊解析失敗的 UC 數」為 2（以 UC 計，不以區塊計）；U1、U2 計入節點數；兩條守恆式以 C10-1 的已知值加兩個節點後仍成立 |
| C10-7（v1.15，E1 鑑別） | C10-6 的 fixture，僅把 U1 的壞區塊修成合法 flow 區塊 | 「flow 區塊解析失敗的 UC 數」由 2 變 1；節點數、非節點數、各失敗原因數、命中／未命中／未判定數全部與 C10-6 相同。兩份產物必須不同，且差異只在該計數項（證明它獨立計數、不進守恆式） |
| C10-8（v1.15，守衛） | 守恆檢查器 | 以「把 flow 失敗 UC 數加進失敗原因總和」的錯誤計數作正向對照，斷言守恆檢查回報失敗（第一條守恆式不收此項） |

#### C11 失敗隔離（NFR-01）

**測試檔**：同上，group `失敗隔離`

| # | Given | Then |
|---|-------|------|
| C11-1 | 基準 fixture 一輪結果 R0 | —（基準） |
| C11-2 | 基準 fixture 另插入〈錯誤處理〉表每種單檔失敗各一（編碼、未閉合、空或非 map、YAML 錯誤、權限、消失） | 掃描完成；原有檔案的結果與 R0 逐項相同；新增檔各得對應結果 |
| C11-3 | 失敗檔排在列舉順序最前與最後兩種排列 | 結果相同（不受順序影響） |
| C11-4（E1 鑑別） | 以會拋例外的 fake 讀取（非預期例外類型）插入一檔 | 該檔歸入無法讀取或以明確錯誤記錄，其他檔案結果仍與 R0 相同；斷言不是整輪中止 |

#### C12 UC flow 區塊取步驟（FR-09 規則 1～6；v1.15 新增）

**測試檔**：`test/unit/corpus/uc_flow_block_test.dart`，group `取步驟`
**測資**：UC 本文建構器；型別表用真實型別表 fixture（UC 判型依 `id_pattern`）

| # | Given（UC 本文的 yaml 區塊，依出現順序） | Then |
|---|------------------------------------|------|
| C12-1 | 無 `flow` 鍵的 yaml、合法 flow（步驟 s1、s2） | 步驟清單為 [s1, s2]（取第二個區塊，規則 2 略過第一個） |
| C12-2 | 合法 flow（s1）、合法 flow（t1、t2） | 步驟清單為 [s1]（同文件多個合法區塊取第一個） |
| C12-3 | `flow: []`、`flow: x`（純量）、yaml 結果為清單、合法 flow（s1） | 前三者皆略過，步驟清單為 [s1] |
| C12-4 | 合法 flow，步驟 id 順序 a、c、b，另有兩步 id 皆為 d | 清單為 a、c、b、d、d：原始順序、不排序、不去重（重複判定屬 SPEC-007 FR-10） |
| C12-5 | 合法 flow，某步含上游八欄以外的鍵 `extra: 1`，另一步缺 `name` | 兩步各保存區塊中的完整 map（含 `extra`、缺 `name` 照缺）；不報錯、不補值 |
| C12-6（守衛） | SPEC 節點本文含合法 flow 區塊 | 該 `rawNode` 不帶步驟清單；正向對照：同一本文改為 UC frontmatter 時帶步驟 |
| C12-7 | UC 本文沒有 yaml 區塊 | 步驟清單為空清單；UC 是節點；不發 EVT-CORPUS-004 |
| C12-8 | UC 本文只有無 `flow` 鍵的合法 yaml | 同 C12-7（無區塊，不產生破洞） |

#### C13 flow 區塊損壞的判定與 EVT-CORPUS-004（FR-09 規則 3a、3b；v1.15 新增；規則 3c、3d 於 v1.22／v1.23 加入）

**測試檔**：同上，group `區塊損壞`

| # | Given（UC 本文的 yaml 區塊，依出現順序） | Then |
|---|------------------------------------|------|
| C13-1（守衛，正向對照） | 唯一區塊含頂層 `flow:` 行且 YAML 語法錯誤 | 步驟清單為空；UC 仍是節點；恰一筆 EVT-CORPUS-004；無 EVT-CORPUS-003；掃描完成 |
| C13-2 | 壞 flow 區塊、合法 flow（s1） | 步驟清單為 [s1]，且仍恰一筆 EVT-CORPUS-004（規則 3b (b)：壞區塊不被後方合法區塊遮住） |
| C13-3 | 兩個壞 flow 區塊 | 恰一筆 EVT-CORPUS-004（以 UC 計，不以區塊計） |
| C13-4（負向對照） | 唯一區塊 YAML 語法錯誤、但沒有頂層 `flow:` 行（例如 `steps:` 開頭） | 不發 EVT-CORPUS-004；步驟清單為空 |
| C13-5（E1 鑑別） | C13-1 與 C12-7 兩份 UC | 兩者步驟清單相同（皆空）；事件輸出不同（前者一筆 004、後者零筆）。斷言兩份產物不同，證明「無區塊」與「區塊壞掉」可分辨 |
| C13-6 | 頂層 `flow:` 行在，其下步驟項縮排錯誤致 YAML 語法錯誤 | 發一筆 EVT-CORPUS-004（已知限制的可判定側） |
| C13-7（已知限制釘住） | 與 C13-6 相同內容，但 `flow:` 行本身縮排兩格 | 不發 EVT-CORPUS-004、不產生破洞、步驟清單為空。與 C13-6 對照：兩者只差 `flow:` 行縮排，結果不同（規則 3b 已知限制；若實作改為也能偵測，本案例須隨規格修訂，不得單方改斷言） |
| C13-8（v1.17 改寫；v1.23 比對方式改寫） | C13-1 的事件負載 | 鍵集合恰為 {`path`, `reason`}；`path` 為 UC 相對路徑（`/` 分隔、無前導 `./`）；`reason` 以原因碼 `flowBlockMalformed` 開頭（前綴比對，以實作提供的具名常數比對；EVT-CORPUS-004 v1.23 起 reason 可附說明，不得全等比對）；無行號欄位（規則 3b (e)）。說明部分可含行號，不斷言其文字內容 |
| C13-9（守衛） | SPEC 節點本文含壞 flow 區塊 | 不發 EVT-CORPUS-004（規則 6）；正向對照為 C13-1 |
| C13-10 | UC 路徑上的檔案 frontmatter 未閉合（不是可用檔），本文另有壞 flow 區塊 | 依 FR-04 發 EVT-CORPUS-003；不發 EVT-CORPUS-004（FR-09 只對判為 UC 的可用檔案） |
| C13-11 | C13-1 的 UC 與 C10-1 fixture 同輪掃描 | 其他檔案的結果與未加入 C13-1 時逐項相同（NFR-01 失敗隔離延伸至 flow 區塊） |
| C13-12（v1.22，E1 鑑別） | 唯一區塊為 `flow: ["a"]`（清單全為非 map） | 步驟清單為空；恰一筆 EVT-CORPUS-004，`reason` 以原因碼開頭且含非 map 項目說明（實作具名常數）；無 EVT-CORPUS-003。對照：無區塊的 UC 步驟清單同為空、零筆 004（規則 3c） |
| C13-13（v1.22） | 唯一區塊 `flow` 清單為 [map a, "x", 42, map b] | 步驟清單為 a、b；恰一筆 004（不論非 map 項目數），`reason` 含非 map 項目說明（規則 3c，E2：不得靜默丟棄） |
| C13-14（v1.22） | 壞 flow 區塊（3b）、再一個含 [map a, "x"] 的 flow 區塊（3c） | 步驟清單為 [a]；恰一筆 004；FR-07 計數 `flowBlockMalformedUcCount` 為 1（3b 與 3c 共用每 UC 一筆上限） |
| C13-15（v1.22） | 本文結尾未閉合的 yaml 圍欄，內含合法 flow（s1、s2）、有頂層 `flow:` 行 | 步驟清單為空（不採用未閉合圍欄的步驟）；恰一筆 004，`reason` 為原因碼；無 EVT-CORPUS-003（規則 3d） |
| C13-15b（v1.22） | 合法 flow 區塊（s1）、其後本文結尾未閉合圍欄含頂層 `flow:` 行（t1、t2） | 步驟清單為 [s1]；恰一筆 004（規則 3d 與 3b(b)：未閉合圍欄不被前方合法區塊遮住，也不覆蓋前方區塊） |
| C13-16（v1.22，負向對照） | 本文結尾未閉合圍欄，內容無 `flow` 鍵；另一份內容為縮排的 `  flow:` 行 | 兩者皆不發 004；前者步驟清單為空（規則 3d「沒有頂層 `flow:` 行時略過」） |
| C13-17（v1.23，未實作） | 合法 flow 區塊（s1）為被採用者，其後另一個 flow 區塊含非 map 項目 | 步驟清單為 [s1]；恰一筆 004（規則 3c 適用任一 flow 區塊，不限被採用者；N3）。001.3 測試檔無對應案例，承接見 §7 |
| L1（實作補強） | 注入的 flow 擷取函式對某 UC 拋出非 YamlException（例：StateError），另有一份正常 UC | 該 UC 仍是節點、步驟清單為空、不發 004；另一份 UC 照常；掃描完成且 `checkScanSummaryConservation` 成立（失敗隔離，NFR-01 延伸；SPEC-006 無對應條文，屬實作防禦性行為的釘住） |

原因碼程式識別名為 `flowBlockMalformed`（v1.17，`0.5.0-W1-001.3` PM 決定）；測試以實作提供的具名常數比對，不寫字串字面。

#### C14 非 domain 路徑清單檔格式錯誤與 EVT-CORPUS-005（FR-10；v1.16／v1.17 新增）

**測試檔**：`test/unit/corpus/non_domain_paths_file_test.dart`
**測資**：fake Workspace 檔案樹；型別表建構器可設定 `non_domain_paths_file`／`non_domain_paths_key` 兩欄有或無；
清單檔內容以字串直接構造

| # | Given | Then |
|---|-------|------|
| C14-1（守衛，正向對照） | 清單檔 YAML 語法錯誤 | 恰一筆 EVT-CORPUS-005，`reason` 為子原因 `yamlInvalid`；Corpus 交給 Graph 的非 domain 側狀態為「格式錯誤」，分類語意同「缺席」（非 domain 側未宣告） |
| C14-2 | 清單檔為合法 YAML map，但缺型別表指定的鍵 | 恰一筆 EVT-CORPUS-005，`reason` 為 `keyMissing` |
| C14-3 | 該鍵的值為字串 | 恰一筆 EVT-CORPUS-005，`reason` 為 `notList` |
| C14-4（E1：缺席對格式錯誤） | 清單檔不存在；對照組為 C14-1 | 不發 EVT-CORPUS-005；非 domain 側狀態為「缺席」。與 C14-1 的分類語意相同、事件與狀態值不同（規則 3、4） |
| C14-5（負向對照） | 清單檔合法、該鍵的值為清單（含空清單 `[]` 一組） | 不發 EVT-CORPUS-005；非 domain 側狀態為「已宣告」，清單原樣交出（`[]` 與缺席可區分） |
| C14-6（E1：位置取自型別表） | 型別表兩欄指定自訂位置 P1、鍵 K1，壞檔放 P1；對照組型別表缺兩欄，同一壞檔仍放 P1 | 前者發 EVT-CORPUS-005（定位到 P1）；後者依內建表值定位，P1 不被讀取、不發事件（內建表位置無檔時為「缺席」）。兩組結果不同，證明位置取自型別表欄位且缺欄時回落內建表，不寫死於程式 |
| C14-7（v1.19 改寫） | C14-1 的事件負載 | 鍵集合恰為 {`path`, `reason`, `nonStringElementCount`}；`path` 為清單檔相對路徑（`/` 分隔、無前導 `./`）；`reason` 以 `NonDomainPathsMalformedReason` 具名常數比對；`nonStringElementCount` 為 null（只在 `elementNotString` 時有值，EVT-CORPUS-005 負載定義） |
| C14-8 | C14-1 的壞檔與 C10-1 fixture 同輪掃描 | 其他檔案的結果與未放壞檔時逐項相同；掃描完成（NFR-01 失敗隔離延伸至清單檔）；FR-07 各計數項與守恆式不變（清單檔不是 carrier） |
| C14-9 | C14-1～C14-3 的三份輸入 | 每份恰一筆事件（同一檔案不因多種錯誤重複發出）；三份 `reason` 兩兩不同 |

#### C15 位置欄位空字串、非字串元素與字串不檢查格式（FR-10 規則 1、2a、2b；v1.18／v1.19 新增）

**層**：domain unit（Corpus）。**測試檔**：同 C14，group `元素與位置欄位`
**測資**：同 C14（fake Workspace、型別表建構器、清單檔字串直接構造）
**承接票**：`0.5.0-W1-123`（main 現行行為為非字串元素轉字串照收、空字串位置欄位照收後判缺席；以下案例在該票修正前為紅燈屬預期）

| # | Given | Then |
|---|-------|------|
| C15-1（守衛：E2 正向對照，規則 1） | 型別表 `non_domain_paths_file` 為空字串、`non_domain_paths_key` 正常；合法清單檔放在內建表位置 | 依內建表位置讀到清單，非 domain 側為「已宣告」；不以空字串為位置（現行照收會判「缺席」，斷言翻紅）。另一組：`non_domain_paths_key` 為空字串、file 正常，同樣依內建表鍵讀取 |
| C15-2（E1：空字串與缺欄同路徑） | C15-1 的型別表；對照組 A 為兩欄缺席（C14-6 對照組）、對照組 B 為兩欄指定自訂位置 P1（壞檔放 P1） | 與 A 結果逐項相同；與 B 結果不同（B 發 EVT-CORPUS-005、本組不讀 P1） |
| C15-3（守衛：規則 2a 驗收） | 清單 `["docs/a/", null, "docs/b/"]` | 生效清單恰為 `docs/a/`、`docs/b/`，不含任何字串 `"null"`（轉字串照收的實作會多出 `"null"`，斷言翻紅）；恰一筆 EVT-CORPUS-005，`reason` 為 `elementNotString`、`nonStringElementCount` 為 1；非 domain 側狀態為「已宣告」 |
| C15-4（E1：一輪一筆，A3 驗收） | 清單 `["docs/a/", 1, true]`；對照組為 C15-3 | 兩組皆恰一筆 EVT-CORPUS-005；`nonStringElementCount` 分別為 2 與 1。每元素一筆的實作會使本組出現兩筆，斷言翻紅 |
| C15-5（E1：`elementNotString` 不視為未宣告） | C15-3；對照組為 C14-1（`yamlInvalid`） | C15-3 非 domain 側為「已宣告」、C14-1 為「格式錯誤」；兩組皆發一筆事件但 Corpus 交給 Graph 的狀態不同（規則 4 只適用三種整份錯誤） |
| C15-6 | 清單 `[1, 2]`（全部非字串） | 生效清單為空、非 domain 側為「已宣告」（同 C14-5 的 `[]`）；一筆事件，`nonStringElementCount` 為 2 |
| C15-7（E1：字串不檢查格式，C3′ 驗收） | 清單 `["", "docs/a/"]`；對照組為 C15-3 | 不發 EVT-CORPUS-005；生效清單恰為 `""`、`docs/a/` 兩值（空字串照常納入，交給比對器；不命中由 SPEC-001-test-design P4-2 承擔）。與 C15-3 對照：非字串發事件、格式違規字串不發 |
| C15-8 | 清單 `["/docs/", "./docs/", "docs/../lib/", "docs/*.md"]` | 不發 EVT-CORPUS-005；四值逐字原樣納入（不去前導 `/`、`./`，不正規化 `..`，不展開 glob） |
| C15-9 | 清單 `["", null]` | 一筆 `elementNotString`、`nonStringElementCount` 為 1；生效清單恰為 `""`（2a 與 2b 同時適用時互不干擾） |
| C15-10 | 清單 `["docs/a/", ["x"], {k: v}, 1.5]` | 三個非字串元素（清單、map、浮點）皆略過；`nonStringElementCount` 為 3；生效清單恰為 `docs/a/` |
| C15-11 | C15-4 的壞元素清單與 C10-1 fixture 同輪掃描 | 其他檔案結果與未放清單時逐項相同；FR-07 各計數項與守恆式不變（同 C14-8，延伸至 `elementNotString`） |

### 3.3 Diagnostics bundle

#### D1 一事件一破洞（FR-08）

**測試檔**：`test/unit/diagnostics/parse_failure_gap_test.dart`

| # | Given | Then |
|---|-------|------|
| D1-1 | 三筆 EVT-CORPUS-003（一型、一型、平手） | 三筆 `parseFailure` 破洞，路徑、歸屬型別、原因與事件一致；平手者帶候選型別與歧義標記 |
| D1-2 | 零筆事件 | 零筆破洞，非「無法判定」 |
| D1-3（v1.16 改寫） | 破洞數 | 等於輸入事件數（EVT-CORPUS-003、004、005 合計），等於掃描摘要的「命中 carrier 數＋flow 區塊解析失敗的 UC 數＋非 domain 路徑清單格式錯誤數」（以同一構造的摘要比對；第三項為 0 或 1） |
| D1-4 | 破洞類別 | 本版只產生 `parseFailure`，不產生 `graphDefect`／`traceGap`／`unlocatable` |
| D1-5（v1.16 改寫） | 一筆 EVT-CORPUS-004（UC 路徑 P） | 一筆 `parseFailure` 破洞，路徑為 P、歸屬型別為 UC、原因碼為 `flowBlockMalformed`；與 EVT-CORPUS-003 產生的破洞原因碼不同 |
| D1-6（v1.15，E1 鑑別） | 兩筆 EVT-CORPUS-003＋一筆 EVT-CORPUS-004，對照組為同兩筆 003、零筆 004 | 前者三筆破洞、後者兩筆；兩組結果不同，多出的一筆即 D1-5 的破洞（證明 004 確實被消費，而非只收 003） |
| D1-7（v1.16） | 一筆 EVT-CORPUS-005（清單檔路徑 Q，`reason` 為 `notList`） | 一筆 `parseFailure` 破洞，路徑為 Q、原因碼為 `nonDomainPathsMalformed`、子原因為 `notList`；原因碼與 003、004 產生者皆不同 |
| D1-8（v1.16，E1 鑑別：公式第三項） | 兩筆 003＋一筆 004＋一筆 005；對照組為同兩筆 003＋一筆 004、零筆 005 | 前者四筆破洞、後者三筆；多出的一筆即 D1-7 形態的破洞。兩組的掃描摘要只差第三項（1 對 0），破洞數差恰為 1 |
| D1-9（v1.16，E1 鑑別：型別來源） | 一筆 EVT-CORPUS-004 與一筆平手的 EVT-CORPUS-003 | 前者破洞的歸屬型別為 UC、無候選型別與歧義標記；後者帶候選型別與歧義標記。兩筆的型別欄形態不同（`0.5.0-W1-113` N5：004 的 UC 仍是節點，型別已知） |
| D1-10（v1.18／v1.19；層：domain unit，Diagnostics） | 一筆 EVT-CORPUS-005（清單檔路徑 Q，`reason` 為 `elementNotString`、`nonStringElementCount` 為 2） | 恰一筆 `parseFailure` 破洞，路徑 Q、原因碼 `nonDomainPathsMalformed`、子原因 `elementNotString`（一事件一破洞，一份清單檔最多一筆破洞）；破洞是否攜帶 `nonStringElementCount` 不斷言（見 §6.5 NC-7） |

#### D2 查詢不可用（FR-08）

**測試檔**：同上，group `無法判定`

| # | Given | Then |
|---|-------|------|
| D2-1（守衛） | 掃描摘要標記查詢不可用，未判定數 3 | 零筆 `parseFailure`；回報「無法判定」並帶原因 |
| D2-2（正向對照） | 同一輸入但查詢可用、命中 3 | 三筆破洞，不回報無法判定 |
| D2-3（v1.6／v1.7） | 查詢不可用，原因分別為「版本不在 App 已知範圍」與「型別表沒有路徑模式」 | 回報的原因是原因碼列舉值（以實作提供的具名常數比對）；Diagnostics 輸出不含在地化字串（不斷言任何顯示文字，顯示文字屬畫面以 l10n 投影） |
| D2-4（v1.6，E1 鑑別） | D2-3 的兩個輸入 | 兩者回報的原因碼不同；版本高於、缺席、無法解析三種來源（S5-4、S5-8、S5-9 的摘要）回報同一原因碼 |
| D2-5（v1.16） | 掃描摘要標記查詢不可用、未判定數 3、無 004、無 005 | 零筆破洞；回報「無法判定」（FR-08 驗收「語料無 flow 解析失敗」條） |
| D2-6（v1.16，守衛：E2 正向對照） | D2-5 的輸入另加一筆 EVT-CORPUS-004 | 恰一筆 `parseFailure` 破洞（原因碼 `flowBlockMalformed`、型別 UC）；EVT-CORPUS-003 來源的破洞仍為零筆，仍回報「無法判定」。與 D2-5 對照：破洞數 1 對 0（`0.5.0-W1-113` N4 前把「查詢不可用不產生破洞」套到 004 的寫法會漏報） |
| D2-7（v1.17，守衛：E2 正向對照） | D2-5 的輸入另加一筆 EVT-CORPUS-005（`reason` 為 `keyMissing`） | 恰一筆 `parseFailure` 破洞（原因碼 `nonDomainPathsMalformed`、子原因 `keyMissing`）；仍回報「無法判定」（`0.5.0-W1-114.1` NC-e） |

### 3.4 跨語言契約測試（traceability 第三軸）

| 編號 | 契約 | 測試檔 | 斷言 |
|------|------|-------|------|
| K1 | FR-01 切分語意 ↔ `frontmatter_parser.py` | `test/integration/corpus_it1_frontmatter_equivalence_test.dart` | IT1-A1～A6 |
| K2 | FR-06 ↔ `tracking_schema.json` 路徑模式與具體度 | `test/unit/schema/tracking_schema_contract_test.dart` | K2-1：真實 JSON 中每個非 FlowStep 型別都有 `carrier_path_patterns`，元素鍵為 `pattern`、`specificity`，`specificity` 為兩個非負整數；K2-2：每個 `pattern` 能被 Dart `RegExp` 編譯；K2-3（守衛，E2）：以測試內建的 Python 專屬語法（例如 `(?P<name>...)`）作正向對照，斷言方言檢查會攔下；K2-4：S1～S2 的關鍵路徑以真實 JSON 查詢得到預期型別；K2-5：模式含 `\d` 時，全形數字路徑不命中（Python 3 `re` 的 `\d` 預設匹配 Unicode 數字、Dart 只匹配 ASCII，兩邊差異須由此案例釘住，見 N3） |
| K3 | lostFields ↔ `completeness_fields`／`completeness_semantics` | K3-1、K3-2：同上檔，group `completeness`；K3-3：`test/unit/corpus/lost_fields_contract_test.dart`（K3-3 呼叫 `lib/corpus/` 的 `lostFields`，放在 schema 測試目錄會違反 §1.3，`0.4.0-W2-002` 發現後移出） | K3-1：真實 JSON 含 `completeness_fields`，各值為字串清單；K3-2：`completeness_semantics` 存在；K3-3：C6-2 的鑑別對照以真實 JSON 的 SPEC 集合重跑 |
| K4 | 內建型別表副本 ↔ `builtin_schema_version.json` | `test/unit/schema/builtin_schema_version_contract_test.dart` | K4-1：內建型別表 asset 的 `schema_generated_at_framework_version` 等於 `builtin_schema_version.json` 的值；K4-2（守衛，E2）：以兩個不同值的測試輸入作正向對照，斷言比對回報不一致；內建型別表 asset 由 `0.3.0-W2-001` 建立，在此之前測試為紅燈屬預期 |

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 5a | 5b | 契約 |
|----|----|----|-----|
| FR-01 | IT-1（A1～A6）；IT-2（A1） | C1、C2、C3 | K1 |
| FR-02 | IT-2（實體化樹經掃描） | C8（含 C8-7、C8-8） | — |
| FR-03 | IT-2（節點與非節點列） | C4（含 C4-7） | — |
| FR-04 | IT-2（A2） | C5、C6、C7 | K3 |
| FR-05 | IT-2（編碼列） | C1-6、C9 | — |
| FR-06 | IT-2（A1、A6） | S1～S5（含 S5-8、S5-9） | K2、K4 |
| FR-07 | IT-2（A3；新計數項不比對，IT-INV-3） | C10（含 C10-6～C10-8） | — |
| FR-08 | IT-2（A2、A6；IT-INV-2、IT-INV-4） | D1（含 D1-5～D1-9）、D2（含 D2-3～D2-7） | — |
| FR-09 | —（IT 不覆蓋，IT-INV-1；重凍結由 `0.5.0-W1-001.6` 分析） | C12、C13 | — |
| FR-10 | —（IT 不覆蓋，IT-INV-4） | C14、C15（v1.18／v1.19）、D1-10 | — |
| NFR-01 | — | C11、C13-11、C14-8 | — |

無空行。NFR-01 不在 IT 範圍：SPEC-006 NFR-01 的驗收是「插入前後逐項相同」的差分比較，
屬 C11 的形態；IT-2 只跑單一語料。

### 4.2 不變式 ↔ 測試（各 domain map §3〈Bundle 不變式清單〉）

| Bundle | 不變式（摘要） | 測試 |
|--------|--------------|------|
| Schema | 完整路徑、區分大小寫、README 不命中 SPEC | S1 |
| Schema | 具體度二層比較 | S2、IT-2 |
| Schema | 打平回傳平手與候選 | S3、C5-3、IT-2 |
| Schema | 不帶 `carrier_path_patterns` 的型別不參與（依欄位，不依型別名） | S4、K2-1 |
| Schema | 路徑模式以 ASCII 語意比對 | K2-5 |
| Schema | 型別表來源三分 | S5、K4 |
| Corpus | 恰好一種結果 | C1 |
| Corpus | 結尾取第一個 `---`；`|---|` 不截斷 | C2、IT-1 |
| Corpus | 可用要求非空 map | C3 |
| Corpus | `id` 至多命中一型；非節點不產生節點與破洞 | C4 |
| Corpus | 事件只對命中 carrier（含平手） | C5 |
| Corpus | lostFields 算法 | C6、K3 |
| Corpus | `salvagedFields` 恆空、`severity` 恆 `edgeAffecting` | C7 |
| Corpus | 兩條守恆式（flow 失敗 UC 數不進守恆式） | C10、C10-7、C10-8、IT-2 A3 |
| Corpus | flow 區塊取第一個合法者、原序保存、只對 UC | C12 |
| Corpus | 「無區塊」與「區塊壞掉」可分辨；每 UC 至多一筆 EVT-CORPUS-004 | C13 |
| Corpus | 單檔失敗不中止、不影響他檔 | C11 |
| Corpus | 非 domain 清單檔「缺席」與「格式錯誤」可分辨；位置取自型別表、缺欄回落內建表 | C14 |
| Corpus | 位置欄位空字串等同缺欄；非字串元素略過且一輪一筆、不使非 domain 側未宣告；字串元素不檢查格式（v1.18／v1.19） | C15 |
| Diagnostics | 一事件一破洞（003、004、005），數量等於命中數＋flow 失敗 UC 數＋清單格式錯誤數 | D1、IT-2 A2 |
| Diagnostics | 查詢不可用時不產生 003 的破洞、回報無法判定；004、005 的破洞照常產生 | D2（含 D2-5～D2-7）、IT-2 A6 |

各 domain map §3〈Bundle 不變式清單〉每一條都有對應測試。

### 4.3 UC 場景 × 不變式去重

SPEC-006 的 `related_usecases` 為 UC-01、UC-05、UC-06。本版涉及的場景是「單輪完整掃描後
取得節點與破洞」（UC-05 掃描、UC-06 破洞報告的資料面）；取消、重掃與畫面接真實資料在
SPEC-006〈本版範圍外〉。這兩個場景的資料面斷言全數由 IT-2 承擔，不另立 UC 場景測試；
與不變式重疊的部分以 5b 為權威、IT-2 只做端到端一致性，不重複斷言同一條規則的細節分支。
UC-01（選擇工作區）只提供根路徑，由 C8-6 以 fake Workspace 覆蓋。

## 5. 測試案例統計

| Bundle／圈 | 群組 | 案例數 |
|-----------|------|-------|
| 5a 外圈 | IT-1、IT-2 | 12（IT1-A1～A6、IT2-A1～A6；v1.15 不增減） |
| Schema | S1～S5 | 27（加 S5-8、S5-9） |
| Corpus | C1～C15 | 113（v1.4 的 60，加 C10-6～C10-8、C12 八案、C13 十一案；v1.6 加 C4-7、C8-7、C8-8；v1.16／v1.17 加 C14 九案，C13-8 改寫不計增；v1.18／v1.19 加 C15 十一案，C14-7 改寫不計增；v1.22／v1.23 加 C13-12～C13-17、C13-15b、L1 共八案，C13-8 改寫不計增） |
| Diagnostics | D1～D2 | 17（加 D1-5、D1-6、D2-3、D2-4；v1.16／v1.17 加 D1-7～D1-9、D2-5～D2-7；D1-3、D1-5 改寫不計增；v1.19 加 D1-10） |
| 跨語言契約 | K2～K4（K1 即 IT-1） | 10 |
| 合計 | | 179 |

守衛型案例與其正向對照：IT1-A4、IT1-A5、IT2-A4、IT2-A5、S1-1、S4-1、S5-4、C4-5、C5-2、
C6-2、C8-3、C8-4、C10-4、C10-8、C12-6、C13-1、C13-9、C14-1、C15-1、C15-3、D2-1、D2-6、D2-7、K2-3、K4-2、S5-8、S5-9，均已附正向對照輸入。
v1.6 變更的 E1 鑑別對照：C4-7（FR-03）、C8-8（FR-02）、D2-4（FR-08）。
v1.15 變更 FR 的 E1 鑑別對照：C10-7（FR-07）、D1-6（FR-08）、C13-5、C13-7（FR-09）。
v1.16／v1.17 變更 FR 的 E1 鑑別對照：D1-8、D1-9（FR-08）、C14-4、C14-6（FR-10）。
v1.18／v1.19 變更 FR 的 E1 鑑別對照：C15-2、C15-4、C15-5、C15-7（FR-10）。
v1.22／v1.23 變更 FR 的 E1 鑑別對照：C13-12（規則 3c，與無區塊對照）、C13-15b 與 C13-16（規則 3d，有／無頂層 `flow:` 行對照）（FR-09）。

## 6. 待決與交接

### 6.1 NeedsContext（已寫入票面）

三項已於 2026-09-24 由用戶裁決：

- **N1（接受）**：lostFields 的「null／`[]` 算寫出」在 0.3.0 無法經掃描流程觸及——失敗檔沒有可用 frontmatter，寫出鍵恆為空。以純函式測（C6-2）；流程層的觸發形態待 0.4 建圖時才出現。
- **N2（以欄位判定）**：參與路徑比對的型別依型別表是否帶 `carrier_path_patterns` 判定，不依型別名（SPEC-006 FR-06 規則 3、D9）。S4 已依此改寫。
- **N3（以 ASCII 為準）**：路徑模式以 ASCII 語意比對，K2-5「全形數字不命中」維持；`0.3.0-W2-002` 的 Python 參照實作須以 `re.ASCII` 編譯。框架方言標示的缺口另由 `0.3.0-W1-086` 追蹤。

### 6.2 Spawn Request（已登記）

- IT-2 的獨立 Python 參照實作、IT-1 與 IT-2 測資的凍結動作（選樣、離線產生預期值、入庫），
  SPEC-006 D3 要求但未指派承接票。

### 6.3 實作票切分建議（Step 6）

| 票 | 群組 | 依賴 |
|----|------|------|
| Schema 查詢 | S1～S4、K2 | `0.3.0-W1-080` |
| Schema 來源判定 | S5、K4 | `0.3.0-W2-001` |
| Corpus 切分分類 | C1～C3 | 無 |
| Corpus 判型與事件 | C4～C7、K3 | Schema 查詢 |
| Corpus 掃描 | C8～C11 | 前兩張 Corpus 票 |
| Diagnostics | D1～D2 | Corpus 事件型別 |
| IT-1 | IT1 | 測資凍結票、Corpus 切分分類 |
| IT-2 | IT2 | 測資凍結票、以上全部 |

各實作票驗收須含系統層 §7 的 import 方向檢查。

### 6.4 v1.15 輪的 NeedsContext（`0.5.0-W1-113`，寫入票面）

- **N4（已處置，`0.5.0-W1-113` PM 處置，SPEC-006 v1.16）**：004 的破洞不依賴路徑查詢、照常產生。落點 D2-6；005 同理（NC-e）落點 D2-7。
- **N5（已處置，同上）**：004 的破洞帶型別 UC。落點 D1-5 改寫、D1-9。
- **N6（已處置，`0.5.0-W1-113.2`）**：v1.5～v1.8 逐版覆核結果見 §8，缺漏已補，`spec_version` 前移至 1.8。

### 6.5 v1.18～v1.19 輪的 NeedsContext（`0.5.0-W1-114.4`，未在裁決內，不自行填補）

- **NC-7**：FR-08 與 EVT-CORPUS-005 未寫 `parseFailure` 破洞是否攜帶 `nonStringElementCount`，也未寫破洞報告是否顯示該數量。D1-10 只斷言原因碼與子原因。
- **NC-8**：FR-10 規則 1 只寫「欄位值為空字串」回落，未寫只含空白的字串（例：`" "`）是否同樣視為缺欄。C15-1 不設此輸入。

## 7. 案例 ↔ 實作票對照（v1.15～v1.19 輪）

| 案例 | 實作票 | 備註 |
|------|-------|------|
| C12-1～C12-8 | `0.5.0-W1-001.3` | 該票 what 已含「第一個合法區塊、附掛於 UC RawNode、無區塊為空」 |
| C13-1～C13-11 | `0.5.0-W1-001.3` | 該票驗收已含「yaml 解析失敗時的行為依 SPEC-006 並有測試」與原因碼 `flowBlockMalformed`；`0.5.0-W1-119` why 亦記 001.3 負責 Corpus 端發出 EVT-CORPUS-004 |
| C13-12～C13-16、C13-15b、L1 | `0.5.0-W1-001.3` | 已實作於 `test/unit/corpus/uc_flow_block_test.dart`（v1.22 用戶裁決 H2／J2）；本表由 `0.5.0-W1-130` 回填 |
| C13-17 | 未承接 | v1.23 規則 3c 範圍（任一 flow 區塊）尚無測試；承接票待 PM 建立（見 `0.5.0-W1-130` NeedsContext） |
| C10-6～C10-8 | `0.5.0-W1-001.3` | FR-07 新計數項與 C13 為同一偵測結果的計數 |
| C14-1～C14-9 | `0.5.0-W1-096.7` | 該票驗收含「三態可區分」「解析失敗轉為 Diagnostics 項目並有該紅輸入測試」；C14-6 對應 PM 決定 NC-2（型別表缺兩欄回落內建表） |
| C14-7（v1.19 改寫）、C15-1～C15-11 | `0.5.0-W1-123` | 該票 what 即 1C／2A 的程式修正；A3（一輪一筆、`nonStringElementCount`）與 C3′（字串不檢查格式）晚於該票建立，Step 6 須確認併入該票驗收 |
| D1-10 | `0.5.0-W1-119` | Diagnostics 消費 `elementNotString` 子原因；依賴 `0.5.0-W1-123` 的事件形態 |
| D1-3、D1-5（改寫）、D1-6～D1-9 | `0.5.0-W1-119` | Diagnostics 消費 EVT-CORPUS-004／005 與三項公式 |
| D2-5～D2-7 | `0.5.0-W1-119` | 該票驗收「路徑查詢不可用時 004／005 破洞照報」 |
| IT-INV-1～4 | `0.5.0-W1-001.6` | 是否重凍結由該分析票決定；未重凍結前斷言即為「不改」 |
| FR-09 驗收第一條（兩語料步驟數 40、9） | `0.5.0-W1-001.6` | 需語料或凍結測資，單元層不覆蓋 |

本檔本輪無「待 Step 6 建票」項目：v1.16／v1.17 新增案例皆已有承接票。`0.5.0-W1-001.4～.7`、
`0.5.0-W1-103.2`、`0.5.0-W1-096.5` 無本檔案例（屬 SPEC-007 或 SPEC-001 路徑比對器）。v1.18／v1.19 新增案例亦皆有承接票；
C15-7、C15-8 交出的格式違規字串「不命中」由 SPEC-001-test-design P4（`0.5.0-W1-096.5`）承擔。

## 8. SPEC-006 v1.5～v1.8 覆核（`0.5.0-W1-113.2`）

| 版本 | 變更項 | 對應案例 | 結論 |
|------|-------|---------|------|
| 1.5 | FR-06 規則 3：依型別表是否帶 `carrier_path_patterns` 判定參與比對（D9） | S4-1～S4-3、K2-1 | 已覆蓋（原 v1.4 輪依 N2 裁決已寫入） |
| 1.5 | FR-06 規則 2：路徑模式以 ASCII 語意比對（D9） | K2-5 | 已覆蓋（原 v1.4 輪依 N3 裁決已寫入）；`\w` 的 ASCII 語意無獨立案例，K2-5 以 `\d` 釘住方言差異，兩者同屬 ASCII 旗標，不另補 |
| 1.6 | FR-02：無法列出的目錄另列清單、寫 warning、不進守恆式 | C8-7、C8-8（新增） | 原缺，已補 |
| 1.6 | FR-03：schema 歧義檔須出現在掃描結果（相對路徑與候選型別） | C4-7（新增）；C4-5 只斷言標記 | 原缺，已補 |
| 1.6 | FR-08：無法判定的原因為原因碼資料值，顯示文字由畫面投影 | D2-3、D2-4（新增） | 原缺（D2-1 只寫「帶原因」），已補 |
| 1.7 | FR-06 規則 7／FR-08／邊界表：「不在 App 已知範圍」涵蓋高於、缺席、無法解析 | S5-4（高於，既有）、S5-8（缺席）、S5-9（無法解析）新增；D2-4 斷言三者同一原因碼 | 原只覆蓋高於，已補 |
| 1.7 | 判定式與 SPEC-001 schema 不相容關卡相同，經關卡進入時不出現 | 無新增 | 不需：關卡屬 SPEC-001 範圍；本規格只測 Schema 層判定結果，兩處判定式共用由實作票落為同一函式，不在本檔斷言 |
| 1.8 | 〈本版範圍外〉回填：`idMissing`／`idPatternMismatch` 歸 `parseFailure`；Ticket 型 `id_pattern` 漏收子票 | 無新增 | 不需：FR-03 本文不變，歸類實作在 `1.0.0-W1-084`、pattern 修正在 `0.3.1-W1-092`，各自承接測試 |

覆核結論：v1.5～v1.8 每項變更皆有對應案例或註明不需，`spec_version` 前移至 1.8。新增案例的實作票
歸屬沿用 §6.3：C4-7 歸「Corpus 判型與事件」、C8-7／C8-8 歸「Corpus 掃描」、S5-8／S5-9 歸「Schema
來源判定」、D2-3／D2-4 歸「Diagnostics」。
