# SPEC-007 凍結測資（IT-1、IT-2、IT-3）

本目錄是 `docs/spec/graph/SPEC-007-graph-building.md` D5、`docs/test-design/SPEC-007-test-design.md`
§2.1～§2.3 要求的三項整合測試的凍結測資。預期值由 `tool/spec007_reference.py`（獨立的 Python
參照實作）依規格產生，凍結時離線執行，CI 不執行。凍結票：`0.4.0-W2-008`。

## 參照實作版本與規格對應

`tool/spec007_reference.py` 1.2.0 對應 SPEC-007 v1.40，於 2026-11-05 重凍結（`0.6.0-W1-171`），
凍結檔 header 的 `reference_version` 為 1.2.0。版本沿革：

- 1.0.0：首次凍結（`0.4.0-W2-008`）。
- 1.1.0（SPEC-007 v1.21）：使用中邊型為 established 扣 `domain_dependency` 加 proposed 的
  `bundle_dependency`（FR-01、D6）；無向改讀型別表 `direction` 欄，缺欄依鍵名取內建表
  `assets/schema/builtin_tracking_schema.json`、內建表也沒有則 `directed`（FR-01、FR-05）。
- 1.2.0（SPEC-007 v1.40）：`closed_by`（proposed 層）成為使用中邊型（D6 第三處鍵名例外）。FR-03〈closed_by 的略過規則〉：
  字串值不符合任何主圖節點型別 `id_pattern`（排除 FlowStep）者略過，不建邊、不計缺陷、不計入引用值總數，
  略過數另計為 `closed_by_skipped_count`；符合 `id_pattern` 但不存在仍是 `danglingRef`，自指為 `selfReference`，
  形狀不合法為 `invalidShape`。`expected_counts.json` 新增 `closed_by_field_value_total`（欄位值總數，獨立計數）、
  `closed_by_reference_count`、`closed_by_skipped_count`，凍結與 `compute` 皆 assert 前者等於後兩者之和。
  `uc_ticket_refs` 為 established 邊型，由型別表自動納入，無須改程式。

凍結的 `type_table.json` 取自現行 `tracking_schema.json`（19 邊型，含 `closed_by`、`uc_ticket_refs`、`direction`）。
`compute` 只比對 `corpora` 值，不比對 header。

仍未涵蓋的條文：flow、名稱解析、`domain_dependency` 建邊（v1.38）、FR-12、FR-13；
`isolatedNode`／`missingRequiredEdge`（FR-09，v1.39）的凍結值為零，參照實作不產生，由 IT2-A1 斷言 App 端也為零。

## 檔案

| 檔案 | 內容 |
|------|------|
| `type_table.json` | 凍結時的型別表（`tracking_schema.json` 原檔副本，含 `node_types`、`edge_types` 與正向基數） |
| `graph_manifest.json` | 每個節點一列（`corpus`、`path`、`id`、`node_type`、`status`、`title`、`edge_fields`、`synthetic`、`covers`；合成列另有 `synthetic_host`），header 記凍結資訊 |
| `ticket_detail_samples.json` | IT-3 樣本：完整 frontmatter 原樣 map，皆為 manifest 既有列 |
| `expected_edges.json` | 每語料的邊：`{edge_type, from, to, declared_by}`，無向邊 `from`／`to` 依 ID codepoint 序 |
| `expected_defects.json` | 每語料的缺陷：`danglingRef`／`malformedRef`／`duplicateId`／`multiSource`（欄位見下） |
| `expected_counts.json` | 每語料的計數；`real_only` 子區塊是不含合成列的計數（與版本契約第 2 欄對照用） |

兩語料 ID 空間重疊，`expected_*` 一律以語料分組；合成列掛在 `graph_project_docs_manager`
（`synthetic_host`），故該組計數含合成列，`real_only` 不含。

## 產生指令與獨立性

```
python3 tool/spec007_reference.py selftest
python3 tool/spec007_reference.py freeze     # 讀兩語料，寫本目錄全部檔案
python3 tool/spec007_reference.py compute    # 只讀 manifest 與 type_table.json，與本目錄 expected_* 比對（rc=0 為一致）
```

- `freeze` 預設語料路徑：本專案為 repo 根，flutter_balance 為 `~/project/flutter_balance`（`--fb-root` 可改）。
- 不 import、不執行、不讀取任何 Dart 實作或其產物。Corpus 判型借用同為 Python 的
  `tool/spec006_reference.py`（`SchemaTypeTable.match_id`、`classify_text`、`scan_markdown_files`）。
- `id_pattern` 依型別表 `id_pattern_dialect`（`python-re`）比對；全部節點型別（含 layer 為 proposed 的
  `FlowStep`）都參與「值是否符合任何節點型別的 `id_pattern`」判定。
- 引用值總數（`reference_value_total`）由 `count_reference_values` 遍歷 manifest 各列 `edge_fields`
  獨立計數，不由三類加總；`freeze` 與 `compute` 皆 assert 兩者相等，`selftest` 另含對應案例與少 1 的正向對照。
- 凍結期間語料若被改動即中止：`freeze` 前後各取一次 docs 下全部 `.md` 的（路徑、mtime）簽章，不同則報錯重跑。

## 量測環境（reference-stability 規則 9：實測記錄）

| 項目 | 值 |
|------|-----|
| 凍結日期 | 2026-11-05（重凍結，`0.6.0-W1-171`；首次凍結 2026-09-30） |
| Python／PyYAML | 3.14.6／6.0.3（`python3.14`；PATH 上的 `python3` 無 PyYAML 時改用之） |
| OS | macOS 26.5 |
| 框架版本 | `.claude/VERSION` = 2.87.0；`schema_generated_at_framework_version` = 2.84.0 |
| graph_project_docs_manager | commit `7d045e52fcb64e50a4f5e97c9c3355635a9f6e2c`，docs 工作區無未提交變更；docs 下 `.md` 2617 檔，簽章 sha256 `14bcd93f...e472861` |
| flutter_balance | HEAD `ffcaba4b41257de61ac63c868967ee4f214a0a4d`；docs 下 `.md` 1898 檔，簽章 sha256 `f088a134...9ce62` |

flutter_balance 是進行中的專案，其 docs 工作區可能含未提交檔案，故上列 HEAD 不足以重現本語料；
可重現的識別是簽章與檔案數。`freeze` 的簽章檢查用來擋住凍結期間語料被改動。header 另存於 `graph_manifest.json`。

## 覆蓋（§2.2.1）

manifest 每一類至少一列（`coverage_gaps` 於 `freeze` 時 assert 為空）。真實列不足才用合成列補；
語料中已有的類別不以合成取代（`freeze` 對合成專屬類別逐項 assert 真實語料出現數為 0）。

| `covers` | 真實列 | 合成列 | 標在哪一列 |
|----------|-------|-------|-----------|
| `related_one_side` | 424 | 0 | 列出對方的一端（未宣告端由 `expected_edges` 查得） |
| `related_both_sides` | 55 | 0 | 兩側互列之邊的兩端（去重後列數，同一節點可屬多條邊） |
| `spawn_reverse_only` | 126 | 0 | 子票（邊的起點） |
| `spawn_multi_source` | 18 | 0 | 子票（`multiSource` 的起點） |
| `provenance_multi_source` | 1 | 0 | 本專案 UC-01（兩條 `provenance` 邊，宣告來源皆為兩端） |
| `dangling` | 5 | 0 | 來源節點（僅計 `targetMissing`） |
| `malformed_pattern` | 5 | 0 | 來源節點 |
| `duplicate_id` | 0 | 2（1 對） | `9.9.9-W9-001` 兩路徑 |
| `self_reference` | 5 | 0 | 來源節點（本專案 `0.5.0-W1-539`、`-574`～`-577` 的 `closed_by` 指向自己；原合成列 `9.9.9-W9-003` 因真實語料已有此類而於 1.2.0 移除） |
| `invalid_shape` | 0 | 1 | `9.9.9-W9-004`（數字、布林、map、清單內清單） |
| `target_duplicated` | 0 | 1 | `9.9.9-W9-002` 引用重複 ID |
| `outputs_non_list_subkey` | 0 | 1 | `PROP-901`（`outputs.notes` 為字串） |
| `null_in_list` | 0 | 1 | `9.9.9-W9-005` |
| `non_string_status_title` | 0 | 1 | `9.9.9-W9-006`（`status: 3`、`title: [a]`） |

合成列共 7 列（含重複 ID 那一對），ID 空間 `9.9.9-W9-*`／`PROP-901`，路徑在
`docs/work-logs/v9/...`／`docs/proposals/`，`freeze` 檢查不與真實列 ID 重疊。

## IT-3 樣本

9 張，每個語料、每種字串 `status` 值取路徑字典序第一張；全為 manifest 既有列，`freeze` 時 assert
樣本的 `id`、`status`、`title` 與全部使用中邊型欄位原值等於 manifest 同 `path` 的列。兩語料真實 ticket
皆有字串 `status`（無缺席）。合成列 `9.9.9-W9-006`（`status: 3`）不入樣本。

| 語料 | status 值集合（各值的 ticket 張數；每值選 1 張） |
|------|------|
| graph_project_docs_manager | blocked 3、closed 435、completed 2058、in_progress 2、pending 45（5 張） |
| flutter_balance | closed 348、completed 1492、in_progress 2、pending 6（4 張） |

frontmatter 中 YAML 的 date 型別會轉為 ISO 字串（Dart 的 yaml 套件不解析時間戳）；本次轉換數為 0。

## 實測值與版本契約第 2 欄的對照

預期數值出自 `docs/todolist.yaml` 0.4.0 版本契約第 2 欄（2026-09-30 規劃量測）。下表「實測」為
2026-11-05 重凍結後 `expected_counts.json` 各語料的 `real_only`（不含合成列）；未調整實作去貼合預期數值。
預期值是 2026-09-30 的快照，語料此後大幅增長（節點約 +1380／+110），逐項不再相符屬預期，不是缺陷；
首次凍結的實測值（節點 1202／1748、斷邊 3／0、格式錯誤 1／4、邊數 1719／2246）可由 git 歷史查得。

| 項目 | 預期（本專案／flutter_balance） | 實測（本專案／flutter_balance） | 說明 |
|------|------|------|------|
| 節點數 | 1179／1690 | 2581／1862 | 語料增長 |
| 斷邊 | 3／0 | 4／1 | 本專案多 `0.1.0-W3-437.2` 的 `closed_by: 0.1.0-W3-417`（符合格式但語料內不存在）；flutter_balance 多 `0.3.0-W4-013` 的 `discovered_during: 0.2.3-W5-001` |
| 格式錯誤 | 1／4 | 6／4 | 本專案多 5 筆 `closed_by` 自指（`0.5.0-W1-539`、`-574`～`-577`，`selfReference`） |
| `spawn` 只在反向 | 38／52 | 72／55 | 含全部真實列（合成列不帶 `spawn`） |
| `spawn` `multiSource` | 7／9 | 9／9 | 本專案較首次凍結多 `0.5.0-W3-008` |
| `provenance` `multiSource` | 0／0 | 0／0 | UC-01 為兩條 `provenance` 邊，宣告來源皆為兩端，基數 many 不回報 |
| 重複 ID、自我引用 | 0／0 | 0（重複 ID）、5／0（自我引用） | 重複 ID 以合成列覆蓋；自我引用本專案 5 筆為真實列 |

其他實測（`real_only`）：

| 項目 | 本專案 | flutter_balance |
|------|------|------|
| 引用值總數（獨立計數，不含 `closed_by` 略過值） | 5912 | 3867 |
| 解析成功／斷邊／格式錯誤 | 5902／4／6 | 3862／1／4 |
| 邊數 | 3781 | 2496 |
| 其中 `closed_by` 邊／`uc_ticket_refs` 邊 | 113／100 | 93／1 |
| `closed_by` 欄位值總數＝引用值＋略過數 | 435＝119＋316 | 348＝93＋255 |
| `graphDefect` 總數（斷邊＋格式錯誤＋`duplicateId`＋`multiSource`） | 19 | 14 |

含合成列的組（本專案）：節點 2586、`duplicateId` 1、引用值總數 5921、`graphDefect` 26。

## 規格未定義處與採用的解釋（不影響規格、供實作票比對）

| 項目 | 採用的解釋 |
|------|-----------|
| 「僅起點／僅終點／兩端」對無向邊 | 規格 FR-06 未定義無向邊的起終點。`declaration_shapes` 分 `directed`（`from_only`／`to_only`／`both`）與 `undirected`（`one_end`／`both`）兩組計數；IT1-A4 實作票須據此比對，或回頭請規格補定義 |
| 清單內的空字串項 | 視為一個引用值，`patternMismatch`（規格只寫「空字串」欄位值不產生引用值） |
| `outputs` 子鍵值為 null 或空字串 | 不產生引用值；其他非清單值（含字串）計為一個 `invalidShape` |
| `outputs` 缺陷的 `field` | 記 `outputs`，不記子鍵名；`raw_value` 為清單項或子鍵值原樣 |
| 反向欄位 `outputs` 的來源型別 | 不限節點型別（語料中只有 PROP 帶 `outputs`，本專案 5、flutter_balance 3） |
| `association` 的宣告來源 | 列出對方的端點 ID 集合；`from`／`to` 依 codepoint 排序不代表方向 |
| 輕節點 | 參照實作只輸出計數與邊；`light_node`（五欄位、非字串 `status`／`title` 為 null）只在 `selftest` 驗證 |

## 缺陷欄位

| `kind` | 欄位 |
|--------|------|
| `danglingRef`、`malformedRef` | `source_id`、`path`、`field`、`raw_value`（原樣）、`edge_type`、`reason`（`targetMissing`／`targetDuplicated`／`invalidShape`／`patternMismatch`／`selfReference`） |
| `duplicateId` | `id`、`paths`（排序） |
| `multiSource` | `from`、`edge_type`、`targets`（`[{to, declared_by}]`，依 `to` 排序） |
