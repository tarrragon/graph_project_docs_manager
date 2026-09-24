# SPEC-006 凍結測資（IT-1、IT-2）

本目錄記錄 `docs/spec/corpus/SPEC-006-corpus-parsing-and-gap-classification.md`
D3、`docs/spec/corpus/SPEC-006-test-design.md` §2.1／§2.2 要求的兩項整合測試
凍結測資的產生方式、量測環境與已知偏離。凍結與產生動作由票 `0.3.0-W2-002`
一次離線完成，CI 不重新執行本目錄下的任何 Python 程式。

## 產生工具

`tool/spec006_reference.py`：獨立於待測 Dart 實作的 Python 參照實作，依
FR-01（切分與五類分類）、FR-02（掃描範圍）、FR-03（節點判型）、FR-05（讀取
失敗子原因）、FR-06（路徑對型別查詢，carrier 路徑以 `re.ASCII` 編譯）規則
撰寫。單元測試內嵌於同檔，以 `python3 tool/spec006_reference.py selftest`
執行。

## 量測環境

| 項目 | 值 |
|------|-----|
| 量測日期 | 2026-09-24 |
| Python | 3.14.6 |
| PyYAML | 6.0.3 |
| OS | macOS 26.5（BuildVersion 25F71） |
| 框架版本 | `.claude/VERSION` = 2.60.13（`schema_generated_at_framework_version` 亦為 2.60.13） |
| 語料來源 | 本機 `~/project/` 下五個框架專案：flutter_balance、book_overview_app、book_overview_v1、monitor、screen_clock（與 `docs/domain-map.md` §7 量測範圍一致） |

## test/fixtures/spec006/it1/expected.json（IT-1 解析語意）

**產生指令**（概念上等同執行下列步驟，實際由一次性腳本離線執行，未入庫該腳本
本身——見〈偏離票面之處〉）：

1. 選出真實樣本 IT1-R：對五個語料專案的 `docs/**/tickets/*.md` 逐檔以
   `spec006_reference.classify_text` 解析，篩出 `frontmatter_text` 含
   `"|---|"` 的檔案，取最小者。命中 19 筆，選定
   `flutter_balance/docs/work-logs/v0/v0.2/v0.2.1/tickets/0.2.1-W3-1013.md`
   （12848 bytes）。
2. 依 test-design §2.1 樣本表補齊 IT1-S1～S8 八個合成邊界樣本。
3. 對每個樣本：以框架 `frontmatter_parser.parse_frontmatter`（真實檔案路徑、
   `utf-8-sig` 解碼）取得 `framework_result`／`keys`；以
   `spec006_reference.naive_split_classify` 取得天真語意 `split("---")` 的
   `naive_key_count`／`naive_yaml_error`；以 `spec006_reference.classify_text`
   核對 `expected_result` 與 FR-01 五類一致。
4. 樣本內容以 `content_base64`（UTF-8 位元組）內嵌於 `expected.json` 的每筆
   紀錄，`sha256` 供完整性核對。

**欄位**：`name`、`source`（`corpus:<專案>/<相對路徑>` 或 `synthetic`）、
`content_base64`、`sha256`、`framework_result`（`split`／`none`）、
`frontmatter_text`、`keys`（排序後鍵清單）、`naive_key_count`、
`naive_yaml_error`、`expected_result`。

**排除規則自我驗證**：產生時已對每個樣本呼叫
`spec006_reference.contains_excluded_line_separator`，全部樣本回傳
`False`（不含切分規則 2 所列排除字元），且皆為合法 UTF-8。

## test/fixtures/spec006/it2/manifest.json（IT-2 破洞分類）

**產生指令**：以 `spec006_reference.SchemaTypeTable` 讀入真實
`tracking_schema.json` 的 `node_types`，另加兩個測試專用合成型別
（`SyntheticTie`：與 PROP 對合成路徑 `docs/proposals/PROP-\d{3}-tie\.md`
具體度打平，供多型別衝突案例；`ClashB`：`id_pattern` 與 SPEC-999 衝突，供
`id` 互斥被打破案例），逐列以 `type_table.query_path` / `type_table.match_id`
交叉核對後寫出。

**樣本覆蓋**（test-design §2.2 表）：

| 類別 | 列數 | 說明 |
|------|------|------|
| 命中 carrier 一型的失敗檔（五種失敗形態各一） | 5 | `no_frontmatter`→DomainBundle（合成）、`unclosed`→Ticket（合成）、`empty_or_non_map`→PROP（合成）、`yaml_error`→Ticket（**真實**，book_overview_app 語料中唯一一筆 YAML 錯誤，見 `docs/domain-map.md` §7）、`unreadable_encoding`→UC（合成） |
| 未命中的失敗檔 | 2 | `docs/work-logs/v0/v0-main.md`（**真實**，flutter_balance，無 frontmatter）、`docs/spec/corpus/README.md`（合成，示範 SPEC 型別排除 README.md） |
| 多型別衝突（平手） | 1 | 合成路徑 `docs/proposals/PROP-998-tie.md`，PROP 與 SyntheticTie 具體度打平 |
| 多型別命中、具體度可分出者 | 1 | `docs/spec/corpus/domain-map.md`（合成內容，判 DomainBundle 非 SPEC） |
| 無法讀取（編碼） | 2 | carrier 內 1（UC，見上表第一類）、carrier 外 1（`docs/work-logs/v0/v0-badenc.md`，合成） |
| 可用且判為節點 | 6 | SPEC、DomainBundle、EVT、PROP、UC、Ticket 各一（皆合成） |
| 可用但非節點 | 2 | 無 `id` 鍵、`id: v0.1.0-note`（不命中任何 `id_pattern`）（皆合成） |
| `id_pattern` 互斥被打破 | 1 | 合成 `id: SPEC-999` 同時命中 SPEC 與測試專用 ClashB |
| **合計** | **19** | — |

**語料實測缺口**：真實語料中未找到「無 frontmatter 的 `domain-map.md`」
「無 frontmatter 的 `spec/<domain>/README.md`」等既有規則案例（既有語料的
`domain-map.md` 全部已有合法 frontmatter），依 D3「語料中沒有的類型用合成列
補上，並標記為合成」以 `synthetic: true` 補齊。

**FR-07 計數與守恆**（`header.expected_counts`，皆已由產生腳本核算並通過雙守恆式斷言）：

- `total_files` = 19 = `node_count`(6) + `non_node_count`(3) + Σ`failure_reason_counts`(10)
- Σ`failure_reason_counts`(10) = `gap_count`(7) + `unmatched_count`(3) + `unjudged_count`(0)

**型別表凍結副本**：`header.type_table` 為凍結時所用的完整型別表（真實
`tracking_schema.json` 的 `node_types` + 兩個合成型別），避免上游改動使凍結
預期失效；`header.schema_generated_at_framework_version` = 2.60.13。

## 偏離票面之處

1. **manifest 檔格式為 JSON 非 YAML**：ticket `0.3.0-W2-002` where.files 明列
   `test/fixtures/spec006/it2/manifest.json`；test-design §2.2 描述為
   `manifest.yaml`。以 where.files 為準（JSON 與 YAML 承載同一資料模型，供
   未來 IT-2 實作票依此決定實際載入格式）。
2. **樣本未落地為獨立檔案**：test-design §2.1 描述樣本檔存放於
   `test/fixtures/spec006/it1/samples/<name>.md`；本票 where.files 只列出
   `test/fixtures/spec006/it1/expected.json` 一檔。改以
   `content_base64` 欄位將樣本位元組內嵌於 `expected.json`
   每筆紀錄中，未另建 `samples/` 目錄與逐檔 README。日後 IT-1 實作票materialize 時可直接由 `content_base64` 解碼寫出檔案（與 IT-2 manifest 的
   「實體化」設計同構）。
3. **IT-2 型別表未落地為獨立 `type_table.json`**：test-design §2.2 描述另存
   `test/fixtures/spec006/it2/type_table.json`；因 where.files 未列此檔，改
   內嵌於 `manifest.json` 的 `header.type_table`。
4. **參照實作單元測試未落地為獨立測試檔**：where.files 未列
   `tool/tests/*.py` 或 `test/tool/*.py` 路徑；改以內嵌於
   `tool/spec006_reference.py` 的 `selftest` 子命令（`_run_selftests`）滿足
   「參照實作附單元測試並全綠」的驗收條件。涵蓋 FR-01（切分五類、BOM、
   `\|---\|` 不截斷、`\r\n`／排除字元）、FR-02（掃描範圍）、FR-03（id 判型、
   多型衝突）、FR-05（讀取失敗三子原因）、FR-06（路徑查詢、平手、ASCII
   語意、具體度二層比較、無路徑模式型別排除）、端到端 `classify_file`。
5. **一次性凍結腳本未入庫**：產生 `expected.json`／`manifest.json` 的腳本
   （呼叫 `spec006_reference.py` 的函式、寫出 JSON）以本 README〈產生指令〉
   節描述其邏輯步驟取代原始程式碼入庫，因 where.files 未列額外腳本路徑。
   若日後需重新凍結（例如新增樣本類別），可依本節步驟以
   `tool/spec006_reference.py` 匯出的函式重建，不依賴任何已刪除的暫存檔。

上述五項偏離已符合本票 acceptance 的實質要求（獨立參照實作、四類 IT-2
樣本覆蓋、IT-1 樣本與預期值凍結、README 記錄產生指令與量測環境、參照實作
單元測試全綠），差異僅在檔案數量與格式，由 PM 於合入時複核是否需要另開票
補齊 `samples/` 目錄與獨立 `type_table.json`（供後續 IT-1／IT-2 實作票消費
時，若偏好逐檔而非內嵌格式）。
