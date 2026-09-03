# Premortem 流程的本框架落地約束

`references/premortem-workflow.md` 描述通用流程；本檔收錄該流程在本框架的具體接線位置。其他專案沿用 premortem 流程時，改寫本檔即可，流程本體不需動。

> **為何分開**：流程本體（列舉 → 並行深挖 → 綜合）不依賴任何專案的檔案佈局，而下列約束逐條指向本專案的規則與範本。兩者放在一起時，沿用者無從分辨哪些必須改、哪些照用。

---

## 派發約束

| 約束 | 本框架的權威來源 |
|------|----------------|
| subagent prompt 的三段式骨架、總行數上限 30 行 | `.claude/references/agent-dispatch-template.md`（PCB pattern） |
| 並行派發數量上限 | `.claude/error-patterns/process-compliance/` 下的並行上限記錄；該上限適用於 `.claude/` 內檔案編輯場景，premortem 產出為 worktree 外的分析檔不受此限，仍建議單批不超過 6 個 |

## 產出約束

| 約束 | 本框架的權威來源 |
|------|----------------|
| 輸出為 markdown、禁 HTML、禁 emoji | `.claude/rules/core/document-format-rules.md` 規則 1、`.claude/rules/core/language-constraints.md` 規則 3 |
| 落檔位置為 ticket Solution 章節或對應 worklog | 同上，並遵循本專案文件系統 |
| 修訂計畫標記「延後處理」時必須綁 follow-up ticket | `.claude/rules/core/decision-trigger-binding.md` |

## 相關機制

- `.claude/skills/parallel-evaluation/SKILL.md` — 審查視角並行機制，與 premortem 的分解軸不同（見流程本體的邊界表）
- `.claude/rules/core/ai-communication-rules.md` — 決策依價值與容量而非估時
