# test/fixtures/corpus

真實 repo 快照的測試 fixture，SPEC-001 設計約束已定案：假資料採真實 repo
快照而非生成器（生成器產的損壞形態是想像的，0.0.3 審查證明想像的損壞形態
可能整批是假的）。快照帶進來的是實際存在的形態。

抽取範圍：docs/proposals/、docs/spec/（含各 domain 的 domain-map.md）、
docs/usecases/、docs/proposals-tracking.yaml。**不含 docs/work-logs/**
（ticket 節點檔另案評估規模處置，見本票 Solution）。抽取來源專案的
git 歷史、`.claude/` 框架本體、其餘文件目錄一律不納入。

## 四種極端與對應來源

| 極端 | 來源 | 說明 |
|------|------|------|
| 真實規模 | screen_clock | 乾淨、規模適中、無已知缺陷的正常樣本 |
| 空狀態 | empty_state（現造） | 四個節點目錄皆存在但為空，非任何專案的快照 |
| 異常長內容 | book_overview_v1 | `docs/spec/extraction/e2e-contract.md`（1673 行） |
| 損壞資料 | book_overview_app、book_overview_v1 | 多個 carrier 缺 frontmatter，`parse_frontmatter` 回傳 `None` |
| 舊框架版本 | monitor、screen_clock | `.claude/VERSION` 分別為 2.22.1／2.24.0，monitor 的 `tracking_schema.py` 僅 78 行、無型別表 |

各專案詳細清單、框架版本與樣本檔案位置見各自目錄下 `meta.yaml`。

## Ticket 節點檔切片

`docs/proposals/`、`docs/spec/`、`docs/usecases/`、`docs/proposals-tracking.yaml`
之外，Ticket 節點檔（`docs/work-logs/**/tickets/*.md`）另以版本切片方式
補入 `book_overview_app/docs/work-logs/`（v0.25 + v0.31 兩個版本目錄），
涵蓋 `status` 多值（pending/in_progress/completed/closed 等）、四型語意邊
（`spawned_tickets`/`children`/`blockedBy`/`relatedTo`）與已知的
「缺 frontmatter carrier」損壞樣本。完整切片標準見
`book_overview_app/docs/work-logs/README.md`。

## 已知落差（描述 vs 實測）

本票 `how` 欄位原描述「book_overview_app 帶 1 個真實 YAML 錯誤」與
「book_overview_v1 帶 22 個 carrier 內無 frontmatter」。實際以框架
`frontmatter_parser.parse_frontmatter_text` 逐檔驗證節點範圍（不含
work-logs）後：

- book_overview_app 節點範圍內找不到會使 `parse_frontmatter_text`
  回傳 `None`（起始為 `---` 但解析失敗）的真實壞 YAML；唯一比對到的
  壞 YAML 樣本落在來源專案 `docs/work-logs/` 下某個 Ticket carrier
  <!-- rule8-exempt: testdata:引用來源語料專案內既有 ticket 檔作為排除範圍說明，非本框架 ticket -->
  ——屬 Ticket 節點的 carrier，依 ticket 範圍界定（不含 work-logs）不納入
  本次 fixture。
- book_overview_v1 節點範圍內找到 8 個（非 22 個）缺 frontmatter 的
  carrier（含 1 個真實 SPEC-ID 檔案 `SPEC-009-qr-frame-format.md`，其餘
  7 個為無 ID 的支援文件）。

判定為 ticket 描述草稿與本機實測的落差（非 prompt 與正本衝突），已依
claim 檢查清單「獨立驗證 Ticket 描述的數量/範圍」自行覆核並如實記錄，
不影響 acceptance 第 2 項（涵蓋四種極端）的達成——缺 frontmatter 與壞
YAML 皆使 `parse_frontmatter` 回傳 `None`，屬同一失敗模式的「損壞資料」
樣本。
