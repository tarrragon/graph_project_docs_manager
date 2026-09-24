# SPEC-006 凍結測資（IT-1、IT-2）

本目錄記錄 `docs/spec/corpus/SPEC-006-corpus-parsing-and-gap-classification.md`
D3、`docs/spec/corpus/SPEC-006-test-design.md` §2.1／§2.2 要求的兩項整合測試
凍結測資的產生方式、量測環境與已知偏離。凍結與產生動作由票 `0.3.0-W2-002`
一次離線完成，CI 不重新執行本目錄下的任何 Python 程式。

**PROP-005 §0.3 契約**：「五個語料專案全部文件分類正確」。本版（第二版，
2026-09-24 修正）manifest 與 expected.json 皆以五個語料的**全量掃描**為主體，
合成列只補語料中缺席的類型。第一版（同日稍早）誤以 19 列（17 列合成）代表
整個契約，經 PM 覆核退回修正，詳見〈與第一版的差異〉。

## 產生工具

`tool/spec006_reference.py`：獨立於待測 Dart 實作的 Python 參照實作，依
FR-01（切分與五類分類）、FR-02（掃描範圍）、FR-03（節點判型）、FR-05（讀取
失敗子原因）、FR-06（路徑對型別查詢，carrier 路徑以 `re.ASCII` 編譯）規則
撰寫。三個子命令：

| 子命令 | 用途 |
|--------|------|
| `selftest` | 內嵌單元測試，涵蓋 FR-01/02/03/05/06 各分支 |
| `freeze-it2` | 全量掃描五個語料專案，凍結 `test/fixtures/spec006/it2/manifest.json` |
| `freeze-it1` | 掃描五個語料專案的全部可用檔案，凍結 `test/fixtures/spec006/it1/expected.json` |

`scan` 子命令（單一 workspace、輸出到 stdout）供互動式查驗，非凍結流程本體。

## 量測環境

| 項目 | 值 |
|------|-----|
| 量測日期 | 2026-09-24 |
| Python | 3.14.6 |
| PyYAML | 6.0.3 |
| OS | macOS 26.5（BuildVersion 25F71） |
| 框架版本 | `.claude/VERSION` = 2.60.13（`schema_generated_at_framework_version` 亦為 2.60.13） |
| 語料來源 | 本機 `~/project/` 下五個框架專案：flutter_balance、book_overview_app、book_overview_v1、monitor、screen_clock（與 `docs/domain-map.md` §7 量測範圍一致） |

## 兩組重新量測的數字

### FR-07 全量分類計數（`freeze-it2` 產出，真實列，不含 5 筆合成補充）

| 指標 | 2026-08-27（domain-map §7，舊語意：可解析/YAML錯誤/無frontmatter） | 2026-09-24（本次，FR-01/FR-06 語意：node/non_node/gap/unmatched） |
|------|------|------|
| 檔案總數 | 7106 | 7466 |
| 可解析（舊）／node+non_node（新） | 5815 | 6174（node 4676 + non_node 1498，含 1 筆合成，真實 1497） |
| YAML 錯誤 | 1 | 1（真實，book_overview_app 語料中唯一一筆，路徑不變） |
| 無 frontmatter（舊）／failure 總數（新） | 1290 | 1292（no_frontmatter，僅真實列） |

差異來源：語料已演進（新增 360 份文件，五專案持續開發），非量測方法變更。
2026-08-27 的三分類（可解析／YAML錯誤／無frontmatter）不區分「命中 carrier
的破洞」與「未命中的雜訊」，本次依 FR-06 進一步拆分：

| FR-06 分類（真實列） | 數量 |
|------|-----|
| gap（命中 carrier，構成真破洞） | 41（Ticket 38、SPEC 3） |
| failure_unmatched（未命中，不構成破洞） | 1252 |
| failure_unjudged（查詢不可用） | 0 |

真破洞的原因分布（真實）：`no_frontmatter` 40、`yaml_error` 1。語料中未出現
`unclosed`、`empty_or_non_map`、`unreadable_encoding`（命中 carrier 者）、
`schema_ambiguous`（平手或 id 衝突）之真實案例，此五類以 5 筆合成列補齊
（見下表）。無法讀取（編碼）之真實案例僅 1 筆，命中於 carrier 外（未命中）。

### IT-1 判別樣本數 N（`freeze-it1` 產出）

| 指標 | 2026-08-27（domain-map §7「先前版本」，已作廢的 130 個舊統計） | 2026-09-24（本次） |
|------|------|------|
| 判別樣本數（真實檔案，天真切分與逐行語意結果不同） | 130（domain-map §7 記載為量測腳本產物，已於 2026-08-27 全面改寫作廢，非本規格採用的基準） | **176** |
| 掃描的可用（usable）檔案總數 | 未於 domain-map 記載 | 6173 |
| 排除字元命中數（切分規則 2 排除清單） | — | 0 |

domain-map §7 記載「先前版本宣稱 130 個 YAML 錯誤」一節本身已被該檔案標記
為量測腳本瑕疵（成因為未閉合單引號字串的誤判），與本規格 FR-01 的「天真
切分 vs 逐行語意」判別完全是兩套不同的量測方法，此處僅並列供對照，不代表
兩者可直接比較或本次數字延續舊統計。N=176 為本票以
`spec006_reference.classify_text` 與 `naive_split_classify` 對全部 6173 筆
usable 檔案逐一比對後的獨立量測結果。

## test/fixtures/spec006/it1/expected.json（IT-1 解析語意）

**產生指令**：`python3 tool/spec006_reference.py freeze-it1`（見
`_cmd_freeze_it1`，邏輯步驟如下）：

1. 對五個語料專案的 `docs/**/*.md` 逐檔：讀取、以 `classify_text` 判定是否為
   `usable`（跳過非 usable 檔案）；對 usable 檔案以
   `contains_excluded_line_separator` 排除含切分規則 2 排除字元者（本次掃描
   結果為 0 筆，故無排除）；以 `naive_split_classify` 計算天真語意結果，與
   `classify_text` 的鍵集合比對，篩出「天真語意鍵數不同或天真語意 YAML 錯誤」
   的判別樣本，共 176 筆（`discriminating_real_files_n`）。
2. 每筆判別樣本以 `_frontmatter_prefix_text` **截斷至閉合 `---` 行為止**
   （含該行），僅保留 frontmatter 段，捨棄本文。截斷理由：天真語意
   `split("---")` 的 `parts[1]` 由文字中前兩次出現的 `"---"` 界定，兩次出現
   皆落於被保留的字首內，截斷本文不改變 `parts[1]`；框架
   `_find_closing_delimiter` 同樣只依賴到閉合行為止的內容。故截斷後的
   天真語意與逐行語意比對結果與截斷前相同——已於程式內對每筆樣本重新以
   截斷後文字執行 `classify_text`／`naive_split_classify` 交叉核對一致。
3. 對每筆樣本（截斷後）以框架 `frontmatter_parser.parse_frontmatter`（真實
   暫存檔路徑、`utf-8-sig` 解碼）取得 `framework_result`／`keys`。
4. 另加 IT1-S1～S8 八個合成邊界樣本（未截斷），共 184 筆。

**欄位**：`name`（`IT1-REAL-NNN` 或 `IT1-SN`）、`source`
（`corpus:<專案>/<相對路徑>` 或 `synthetic`）、`content_base64`、`sha256`、
`framework_result`（`split`／`none`）、`frontmatter_text`、`keys`（排序後
鍵清單）、`naive_key_count`、`naive_yaml_error`、`expected_result`、
`truncated_to_frontmatter_only`（bool，標示是否經體積控制截斷）。

**檔頭欄位**：`frozen_date`、`framework_version_file`、`corpus_projects`、
`usable_files_scanned`（6173）、`excluded_line_separator_count`（0）、
`discriminating_real_files_n`（176）、`note`（截斷理由，英文避免自動載入
中文 attention pool 污染，見規則檔慣例）。

## test/fixtures/spec006/it2/manifest.json（IT-2 破洞分類）

**產生指令**：`python3 tool/spec006_reference.py freeze-it2`（見
`_cmd_freeze_it2`）：對五個語料專案以 `scan_markdown_files` 全量掃描，逐檔以
`classify_file`（依附加測試專用合成型別 `SyntheticTie`／`ClashB` 的型別表，
兩者模式皆只命中特定合成路徑／id，不影響真實語料分類）分類，`path` 欄位帶
`<專案>/<相對路徑>` 前綴、`project` 欄位記來源專案，`synthetic: false`；再
以 `_synthetic_it2_rows()` 附加 5 筆合成補充列（`synthetic: true`），補齊
語料中缺席的類別。

**列數**：7471（真實 7466 + 合成 5）。

**合成補充列涵蓋的缺席類別**（語料全量掃描後確認缺席，見上節「差異來源」）：

| 缺席類別 | 補充列 |
|---------|--------|
| 命中 carrier 的 `unclosed` | `docs/work-logs/v0/v0.1/tickets/0.1.0-W1-999.md` → Ticket |
| 命中 carrier 的 `empty_or_non_map` | `docs/proposals/PROP-999-synthetic.md` → PROP |
| 命中 carrier 的 `unreadable_encoding` | `docs/usecases/UC-99-synthetic.md` → UC |
| 多型別衝突（平手，`gap`） | `docs/proposals/PROP-998-tie.md`，PROP 與 SyntheticTie 具體度打平 |
| `id_pattern` 互斥被打破（`non_node`） | `docs/spec/corpus/id-clash-synthetic.md`，`id: SPEC-999` 同時命中 SPEC 與 ClashB |

真實語料已涵蓋的類別（不需合成）：`no_frontmatter` 命中 carrier（40 筆真破洞）、
`yaml_error` 命中 carrier（1 筆）、`unreadable_encoding` 未命中（1 筆）、
`no_frontmatter` 未命中（1251 筆）、全部 7 種節點型別（DomainBundle 24、
SPEC 62、Ticket 4497、EVT 5、UC 39、PROP 48、FlowStep 1，`FlowStep` 命中
純屬其寬鬆 `id_pattern` 意外匹配某筆真實 `id`，如實記錄非本票引入的偏差）、
可用非節點（1497 筆，無 `id` 或 `id` 不命中任何型別）。

**FR-07 計數與守恆**（`header.expected_counts`，由 `freeze-it2` 內建
assert 驗證，見下方實測結果）：

```
total_files=7471, real_files=7466, synthetic_files=5
node_count=4676, non_node_count=1498
failure_reason_counts={no_frontmatter:1292, yaml_error:1, unreadable_encoding:2, unclosed:1, empty_or_non_map:1}
gap_count=45, unmatched_count=1252, unjudged_count=0
```

守恆式 1：7471 = 4676 + 1498 + (1292+1+2+1+1=1297) 。
守恆式 2：1297 = 45 + 1252 + 0 。兩者皆由程式內 `assert` 通過。

**型別表凍結副本**：`header.type_table` 為凍結時所用的完整型別表（真實
`tracking_schema.json` 的 `node_types` + 兩個合成型別），避免上游改動使凍結
預期失效；`header.schema_generated_at_framework_version` = 2.60.13。

## 體積控制的做法

`manifest.json`（3.6 MB）與 `expected.json`（2.2 MB）皆屬可入庫的文字型
fixture（非二進位），體積控制手段：

1. **IT-2**：manifest 只記路徑與分類結果（不內嵌檔案內容），實體化流程
   （由後續 IT-2 實作票依 test-design §2.2「實體化流程」在測試執行時依
   `shape` 現場寫出真實檔案）不需要 manifest 攜帶原始位元組。
2. **IT-1**：176 筆真實判別樣本原始檔案平均逾 400 行（ticket 全文），若整
   檔內嵌會使 `expected.json` 膨脹數倍；截斷至僅保留 frontmatter 段（見上
   節理由），單筆樣本自數十 KB 降至約 1-3 KB。

## 與第一版的差異（PM 退回修正紀錄）

第一版（2026-09-24 稍早）以 9 筆 IT-1 樣本（1 真實 + 8 合成）與 19 筆 IT-2
manifest（2 真實 + 17 合成）交付，理由記為「語料中找不到真實案例」。PM 以
`scan` 子命令對五個語料全量掃描後指出：真實語料含 41 個真破洞（gap），
「語料中找不到真實案例」不成立；PROP-005 §0.3 的契約是「五個語料專案全部
文件分類正確」，19 列（17 列合成）的 manifest 與 1 份真實檔案的 IT-1 樣本
皆無法驗證此契約。本版（第二版）以全量掃描（IT-2 共 7466 真實列）與全量
usable 檔案比對（IT-1 共 176 個真實判別樣本，掃描 6173 筆 usable 檔案）
取代，僅在語料中確認缺席的 5 個類別維持合成補充；一次性凍結腳本（`freeze-it1`
`freeze-it2`）已納入 `tool/spec006_reference.py`（在 where.files 內）供日後
重建。

## 偏離票面之處

1. **manifest 檔格式為 JSON 非 YAML**：ticket `0.3.0-W2-002` where.files 明列
   `test/fixtures/spec006/it2/manifest.json`；test-design §2.2 描述為
   `manifest.yaml`。以 where.files 為準（JSON 與 YAML 承載同一資料模型）。
2. **IT-1 樣本未落地為獨立 `samples/*.md` 檔案**：test-design §2.1 描述樣本
   檔存放於 `test/fixtures/spec006/it1/samples/<name>.md`；本票 where.files
   只列出 `test/fixtures/spec006/it1/expected.json` 一檔。改以
   `content_base64` 欄位內嵌樣本位元組（真實樣本已截斷至 frontmatter 段，見
   〈體積控制的做法〉）。日後 IT-1 實作票 materialize 時可直接解碼寫出檔案。
3. **IT-2 型別表未落地為獨立 `type_table.json`**：改內嵌於 `manifest.json`
   的 `header.type_table`（原因同上，where.files 未列此檔）。
4. **參照實作單元測試未落地為獨立測試檔**：改以內嵌於
   `tool/spec006_reference.py` 的 `selftest` 子命令（`_run_selftests`）。

上述四項差異僅涉及檔案數量／格式，不影響規則實質（FR-01/02/03/05/06 規則、
D3 全量凍結要求、D9 ASCII 語意）。IT-1 樣本截斷為體積控制手段，已在程式內
驗證不影響判別結果（見上節理由與交叉核對）。
