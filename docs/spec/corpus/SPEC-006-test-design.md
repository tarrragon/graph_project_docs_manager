---
id: SPEC-006-test-design
title: "SPEC-006 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-006
spec_version: "1.4"
ticket: 0.3.0-W1-084
created: "2026-09-24"
updated: "2026-09-24"
---

# SPEC-006 Phase 2 紅燈測試規格

本文件是 SPEC-006 v1.4（Corpus 解析與破洞判定）的紅燈測試規格，供 version-bootstrap
Step 6 建實作票。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-006；本文件
與其衝突時以 SPEC-006 為準，衝突本身記入承接票的 NeedsContext。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-1、IT-2 兩項整合測試 | 版本契約（PROP-005 §0.3）的驗收終點 | 與框架或參照實作的行為分歧 |
| 5b 內圈 | 逐 bundle 的 domain unit 測試 | domain-map §3〈Bundle 不變式清單〉逐條斷言 | 單一不變式被打破，可直接定位 |

外圈綠而內圈紅、或反之，都代表測資沒有涵蓋到對應形態，須補測資而非放寬斷言。

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| Schema 路徑對型別查詢、型別表來源判定 | domain unit（純函式） | 型別表以測試內建的最小表物件注入，不讀 asset |
| Corpus 切分、分類、判型、事件組裝、lostFields、守恆計數 | domain unit | 使用真實 Schema 查詢物件（Sociable），不 mock Schema |
| Corpus 掃描（FR-02、FR-05、NFR-01） | unit | 檔案系統以 port 注入（domain-map §8 FR-02 列）；FR-05 權限與消失兩個子原因用 fake port，編碼用真實位元組 |
| Diagnostics 破洞產生 | domain unit | 輸入直接構造 EVT-CORPUS-003 值物件與「查詢可用性」狀態 |
| IT-1、IT-2 | integration（`test/integration/`） | 不 mock：讀真實檔案、真實 Schema 查詢、真實 Diagnostics |

Mock 只替換外部世界（檔案系統 port、asset 讀取）；Schema、Corpus、Diagnostics 三個 bundle
之間一律用真實物件，重構內部結構時測試不需改動。

### 1.3 依賴方向與測試隔離

依 domain-map §2 與 §5：

- `test/unit/schema/` 不得 import `lib/corpus/`、`lib/diagnostics/`
- `test/unit/corpus/` 可 import `lib/schema/`，不得 import `lib/diagnostics/`
- `test/unit/diagnostics/` 只 import `lib/diagnostics/` 與 `lib/corpus/`（事件型別），不得 import `lib/schema/`（Diagnostics → Schema 邊已刪除）
- 只有 `test/integration/` 的兩項 IT 可同時 import 三者

### 1.4 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 |
|--------|------|------|---------|
| 最小型別表建構器 | `test/helpers/spec006/type_table_builder.dart` | 以宣告方式建出含指定路徑模式、具體度、完整性集合、版本的型別表 | S1～S5、C3、C5、C6 |
| 真實型別表 fixture | `test/helpers/spec006/real_type_table.dart` | 讀取 `.claude/skills/doc/doc_system/core/tracking_schema.json` 的真實型別表 | S1、S2、K2、K3 |
| 記憶體檔案系統 fake | `test/helpers/spec006/fake_docs_fs.dart` | 實作掃描用的檔案系統 port，可指定每個路徑的位元組、權限拒絕、列出後消失 | C1、C8、C9、C10 |
| 暫存目錄實體化器 | `test/helpers/spec006/manifest_materializer.dart` | 依 IT-2 manifest 在暫存目錄寫出真實檔案 | IT-2、C9 |

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
| C4-6 | 可用檔位於某 carrier 路徑但 `id` 屬另一型 | 依 `id_pattern` 判型，不依路徑（domain-map §7） |

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

#### C11 失敗隔離（NFR-01）

**測試檔**：同上，group `失敗隔離`

| # | Given | Then |
|---|-------|------|
| C11-1 | 基準 fixture 一輪結果 R0 | —（基準） |
| C11-2 | 基準 fixture 另插入〈錯誤處理〉表每種單檔失敗各一（編碼、未閉合、空或非 map、YAML 錯誤、權限、消失） | 掃描完成；原有檔案的結果與 R0 逐項相同；新增檔各得對應結果 |
| C11-3 | 失敗檔排在列舉順序最前與最後兩種排列 | 結果相同（不受順序影響） |
| C11-4（E1 鑑別） | 以會拋例外的 fake 讀取（非預期例外類型）插入一檔 | 該檔歸入無法讀取或以明確錯誤記錄，其他檔案結果仍與 R0 相同；斷言不是整輪中止 |

### 3.3 Diagnostics bundle

#### D1 一事件一破洞（FR-08）

**測試檔**：`test/unit/diagnostics/parse_failure_gap_test.dart`

| # | Given | Then |
|---|-------|------|
| D1-1 | 三筆 EVT-CORPUS-003（一型、一型、平手） | 三筆 `parseFailure` 破洞，路徑、歸屬型別、原因與事件一致；平手者帶候選型別與歧義標記 |
| D1-2 | 零筆事件 | 零筆破洞，非「無法判定」 |
| D1-3 | 破洞數 | 等於輸入事件數，等於掃描摘要的命中 carrier 數（以同一構造的摘要比對） |
| D1-4 | 破洞類別 | 本版只產生 `parseFailure`，不產生 `graphDefect`／`traceGap`／`unlocatable` |

#### D2 查詢不可用（FR-08）

**測試檔**：同上，group `無法判定`

| # | Given | Then |
|---|-------|------|
| D2-1（守衛） | 掃描摘要標記查詢不可用，未判定數 3 | 零筆 `parseFailure`；回報「無法判定」並帶原因 |
| D2-2（正向對照） | 同一輸入但查詢可用、命中 3 | 三筆破洞，不回報無法判定 |

### 3.4 跨語言契約測試（traceability 第三軸）

| 編號 | 契約 | 測試檔 | 斷言 |
|------|------|-------|------|
| K1 | FR-01 切分語意 ↔ `frontmatter_parser.py` | `test/integration/corpus_it1_frontmatter_equivalence_test.dart` | IT1-A1～A6 |
| K2 | FR-06 ↔ `tracking_schema.json` 路徑模式與具體度 | `test/unit/schema/tracking_schema_contract_test.dart` | K2-1：真實 JSON 中每個非 FlowStep 型別都有 `carrier_path_patterns`，元素鍵為 `pattern`、`specificity`，`specificity` 為兩個非負整數；K2-2：每個 `pattern` 能被 Dart `RegExp` 編譯；K2-3（守衛，E2）：以測試內建的 Python 專屬語法（例如 `(?P<name>...)`）作正向對照，斷言方言檢查會攔下；K2-4：S1～S2 的關鍵路徑以真實 JSON 查詢得到預期型別；K2-5：模式含 `\d` 時，全形數字路徑不命中（Python 3 `re` 的 `\d` 預設匹配 Unicode 數字、Dart 只匹配 ASCII，兩邊差異須由此案例釘住，見 N3） |
| K3 | lostFields ↔ `completeness_fields`／`completeness_semantics` | 同上檔，group `completeness` | K3-1：真實 JSON 含 `completeness_fields`，各值為字串清單；K3-2：`completeness_semantics` 存在；K3-3：C6-2 的鑑別對照以真實 JSON 的 SPEC 集合重跑 |
| K4 | 內建型別表副本 ↔ `builtin_schema_version.json` | `test/unit/schema/builtin_schema_version_contract_test.dart` | K4-1：內建型別表 asset 的 `schema_generated_at_framework_version` 等於 `builtin_schema_version.json` 的值；K4-2（守衛，E2）：以兩個不同值的測試輸入作正向對照，斷言比對回報不一致；內建型別表 asset 由 `0.3.0-W2-001` 建立，在此之前測試為紅燈屬預期 |

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 5a | 5b | 契約 |
|----|----|----|-----|
| FR-01 | IT-1（A1～A6）；IT-2（A1） | C1、C2、C3 | K1 |
| FR-02 | IT-2（實體化樹經掃描） | C8 | — |
| FR-03 | IT-2（節點與非節點列） | C4 | — |
| FR-04 | IT-2（A2） | C5、C6、C7 | K3 |
| FR-05 | IT-2（編碼列） | C1-6、C9 | — |
| FR-06 | IT-2（A1、A6） | S1～S5 | K2、K4 |
| FR-07 | IT-2（A3） | C10 | — |
| FR-08 | IT-2（A2、A6） | D1、D2 | — |
| NFR-01 | — | C11 | — |

無空行。NFR-01 不在 IT 範圍：SPEC-006 NFR-01 的驗收是「插入前後逐項相同」的差分比較，
屬 C11 的形態；IT-2 只跑單一語料。

### 4.2 不變式 ↔ 測試（domain-map §3〈Bundle 不變式清單〉）

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
| Corpus | 兩條守恆式 | C10、IT-2 A3 |
| Corpus | 單檔失敗不中止、不影響他檔 | C11 |
| Diagnostics | 一事件一破洞，數量等於命中數 | D1、IT-2 A2 |
| Diagnostics | 查詢不可用時不產生破洞、回報無法判定 | D2、IT-2 A6 |

domain-map §3〈Bundle 不變式清單〉每一條都有對應測試。

### 4.3 UC 場景 × 不變式去重

SPEC-006 的 `related_usecases` 為 UC-01、UC-05、UC-06。本版涉及的場景是「單輪完整掃描後
取得節點與破洞」（UC-05 掃描、UC-06 破洞報告的資料面）；取消、重掃與畫面接真實資料在
SPEC-006〈本版範圍外〉。這兩個場景的資料面斷言全數由 IT-2 承擔，不另立 UC 場景測試；
與不變式重疊的部分以 5b 為權威、IT-2 只做端到端一致性，不重複斷言同一條規則的細節分支。
UC-01（選擇工作區）只提供根路徑，由 C8-6 以 fake Workspace 覆蓋。

## 5. 測試案例統計

| Bundle／圈 | 群組 | 案例數 |
|-----------|------|-------|
| 5a 外圈 | IT-1、IT-2 | 12（IT1-A1～A6、IT2-A1～A6） |
| Schema | S1～S5 | 25 |
| Corpus | C1～C11 | 60 |
| Diagnostics | D1～D2 | 6 |
| 跨語言契約 | K2～K4（K1 即 IT-1） | 10 |
| 合計 | | 113 |

守衛型案例與其正向對照：IT1-A4、IT1-A5、IT2-A4、IT2-A5、S1-1、S4-1、S5-4、C4-5、C5-2、
C6-2、C8-3、C8-4、C10-4、D2-1、K2-3、K4-2，均已附正向對照輸入。

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

各實作票驗收須含 domain-map §5 的 import 方向檢查。
