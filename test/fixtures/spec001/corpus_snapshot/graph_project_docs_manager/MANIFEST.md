# 語料快照 manifest：graph_project_docs_manager

- 凍結日期：2026-10-09
- 來源 repo：graph_project_docs_manager
- 來源 commit：4624bbd89b7670f362eeda3809cf9d5d731274de
- 用途：SPEC-001-test-design §1.2 外圈與 Graph G12／G13 預期值來源（N1）；載入器屬 0.5.0-W1-114.13，不在本快照內

## 擷取規則

- domain map：擷取檔首 YAML frontmatter，自第一行 `---` 至下一個獨立 `---` 行（含兩條界線），位元組原樣，不改寫
- UC：擷取 `flow:` 區塊，自緊鄰 `flow:` 前一行的 yaml 程式碼圍欄起至下一個圍欄止（含兩條圍欄），位元組原樣，不改寫
- 型別表：整檔位元組複製 `tracking_schema.json`，不以 `doc schema export` 重產
- 各檔保留其在來源 repo 的相對路徑

## 收錄清單

- .claude/skills/doc/doc_system/core/tracking_schema.json
- docs/spec/corpus/domain-map.md
- docs/spec/diagnostics/domain-map.md
- docs/spec/graph/domain-map.md
- docs/spec/history/domain-map.md
- docs/spec/layout/domain-map.md
- docs/spec/schema/domain-map.md
- docs/spec/ticketdetail/domain-map.md
- docs/spec/workspace/domain-map.md
- docs/usecases/UC-01-open-project-and-reach-usable-state.md
- docs/usecases/UC-02-assess-change-impact-by-domain.md
- docs/usecases/UC-03-understand-domains-traversed-by-a-flow.md
- docs/usecases/UC-04-trace-a-requirement-implementation-chain.md
- docs/usecases/UC-05-find-blocked-work.md
- docs/usecases/UC-06-find-and-fix-document-gaps.md
