# test/fixtures/corpus/book_overview_app/docs/work-logs

Ticket 節點檔的版本切片 fixture，承接同語料目錄下 `../README.md`
所述之「Ticket 節點檔另案評估規模處置」——版本切片入庫（相對於整份
入庫或本機路徑跳過 CI），由本目錄補做落地。

## 來源

| 項目 | 值 |
|------|------|
| 來源專案 | `~/project/book_overview_app` |
| 來源路徑 | `docs/work-logs/v0/v0.25/`、`docs/work-logs/v0/v0.31/` |
| snapshot 日期 | 2026-09-03 |
| claude_framework_version | 2.27.8（與同專案下 `../meta.yaml` 一致） |
| 抽取方式 | `rsync -a --prune-empty-dirs --include='*/' --include='tickets/*.md' --exclude='*'`（只取 `tickets/*.md`，不含 `acceptance-reports/` 等同版本目錄下其他子目錄） |
| 完整性驗證 | 逐檔 `cmp`／`diff -rq` 對照來源，773 個檔案位元組相同，無轉碼、無截斷 |

## 切片標準

以框架自身的 `frontmatter_parser.parse_frontmatter_text`（逐行語意，非
`str.split("---")` 天真語意，理由見 `docs/tech-decisions.md` 「130 個
YAML 錯誤不存在」段）對來源專案 `docs/work-logs/v0/` 下每個版本目錄的
`tickets/*.md` 逐檔分類，選出同時滿足以下條件的版本目錄組合：

1. **涵蓋 `status` 多值**（pending / in_progress / completed / closed，
   越多越好）
2. **涵蓋既有語意邊欄位**（`spawned_tickets` / `children` / `blockedBy`
   / `relatedTo`，四型皆需出現至少 1 例）
3. **涵蓋已知的損壞形態**（`parse_frontmatter_text` 回傳 `None` 的
   carrier，即「缺 frontmatter」樣本）
4. 總體積落在「數百 KB 至數 MB」區間，不追求單一版本涵蓋全部條件

單一版本目錄不足以同時滿足全部條件（v0.25 有 pending/in_progress 但無
edges 與 closed；v0.31 有 closed/accepted/edges/缺 frontmatter 樣本但無
pending/in_progress），故取兩個版本目錄的聯集：

| 版本目錄 | 檔案數 | 貢獻 |
|---------|-------|------|
| `v0/v0.25/`（v0.25.0 + v0.25.1） | 58 | `pending`(31) / `in_progress`(2) / `completed`(21)；4 個缺 frontmatter 樣本 |
| `v0/v0.31/`（v0.31.0 + v0.31.1） | 715 | `completed`(694) / `accepted`(1) / `closed`(6) / 4 筆非標準值；`spawned_tickets`/`children`/`blockedBy`/`relatedTo` 四型邊皆有實例；10 個缺 frontmatter 樣本 |

合計 773 個檔案，約 5.4 MB。

## 已知落差（描述 vs 實測）

原任務描述期待涵蓋「YAML 解析失敗（`how.strategy` 斷行）」型損壞樣本。
以框架自身逐行語意解析驗證後，**book_overview_app 全部 773 個切片檔案
中無此類樣本**——`docs/tech-decisions.md`「2026-08-27：撤回——『130 個
YAML 錯誤』不存在，是量測 artifact」已定案：此損壞形態出自天真 parser
（`str.split("---")`）誤判 frontmatter 內 markdown 表格分隔線
（`|---|---|`）為區塊邊界，框架自身逐行語意解析對本專案全量 ticket
的真實錯誤數為 0。

本切片實際涵蓋的損壞形態是**缺 frontmatter carrier**
（`parse_frontmatter_text` 因首行非 `---` 或找不到結束定界而回傳
`None`）——與同語料目錄下 PROP/SPEC/UC 三型別的處置一致，屬同一失敗
模式（parser 回傳 `None`），且是本專案語料中唯一真實出現的 Ticket
carrier 損壞形態。14 個缺 frontmatter 樣本清單見下節。

## 缺 frontmatter 樣本清單（14 個）

驗證指令：`doc_system.core.frontmatter_parser.parse_frontmatter_text`
逐檔解析，回傳 `None` 者列於下（相對本目錄路徑）：

```
v0/v0.25/v0.25.0/tickets/0.25.0-W1-010.md
v0/v0.25/v0.25.0/tickets/W2-003-KEY-FINDINGS.md
v0/v0.25/v0.25.0/tickets/W2-003-unit-test-failure-analysis.md
v0/v0.25/v0.25.0/tickets/W3-003-DESIGN-DECISIONS-NEEDED.md
v0/v0.31/v0.31.0/tickets/0.31.0-W22-001.1-phase2-summary.md
v0/v0.31/v0.31.0/tickets/0.31.0-W27-001-integration-eval-catalog.md
v0/v0.31/v0.31.0/tickets/0.31.0-W3-002.2-completion-summary.md
v0/v0.31/v0.31.0/tickets/0.31.0-W4-036-FEASIBILITY-REPORT.md
v0/v0.31/v0.31.0/tickets/0.31.0-W4-036.9-COMPLETION.md
v0/v0.31/v0.31.0/tickets/0.31.0-W4-037.4-SUMMARY.md
v0/v0.31/v0.31.0/tickets/0.31.0-W4-054.md
v0/v0.31/v0.31.0/tickets/0.31.0-W8-003-phase3a-strategy.md
v0/v0.31/v0.31.0/tickets/0.31.0-W8-003-test-design.md
v0/v0.31/v0.31.0/tickets/phase4-refactor-assessment.md
```

這些是同版本工作日誌目錄下的伴隨文件（設計決策記錄、完成摘要、可行性
報告等），非 Ticket 節點本身，但沿用 `tickets/` 目錄慣例被 glob
`tickets/*.md` 一併收入，恰好構成「缺 frontmatter carrier」的真實樣本。

## Status 與邊分佈統計

以 `parse_frontmatter_text` 對 759 個可解析檔案統計：

| 欄位 | 統計 |
|------|------|
| `status` | pending 31 / completed 715 / in_progress 2 / accepted 1 / closed 6 / 其他非標準值 4 |
| `spawned_tickets` 非空 | 37 |
| `children` 非空 | 56 |
| `blockedBy` 非空 | 142 |
| `relatedTo` 非空 | 40 |

驗證方式：`python3` + `doc_system.core.frontmatter_parser`
（框架自身模組，非重新實作解析邏輯）逐檔統計，統計腳本邏輯與
本專案抽取節點檔案時採用的驗證方式一致（框架語意 vs 樣本）。
