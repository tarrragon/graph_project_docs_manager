# 框架更新適應 — 狀態記錄

> 本檔由 `framework-update-adaptation` skill 維護，每個專案各一份（位於 `project-integration/`，sync 雙向排除）。Step 1 讀 last-adapted 作為起點；Step 5 在全部分類完成後更新。

## last-adapted

**3.0.1**

## 適應歷史

| 版本區間 | 紀錄票 | 結論摘要 |
|---------|-------|---------|
| 2.86.0 → 2.87.0 | 無需建票（驗證實跑紀錄見 0.6.0-W1-180 Solution） | 9 條目、18 檔。不需動作 8 條目（含 statusline_lane.py 僅權限位）；consumer 產物要重驗 1 條目（closed_by 邊），內嵌副本已同步，已完成 |
| 2.87.0 → 3.0.0 | 0.7.0-W1-002.1 | 14 條目、53 檔，無 removed／renamed。2.88.0～2.90.0 由本專案以主控方身份推送，本專案即來源。分類結果：1 本地特化 1 項（DOC-008，衝突採 upstream 1.2.0，已完成）；3 守衛需配合 1 項（首次升級 pull 帶入 .github/，本地已刪，回報上游，llm-dev 3.0.1-W1-005）；4 產物重驗 3 項（CLAUDE.md §1 兩段、§8 patch 規則與 tech-decisions 補記，0.7.0-W1-002.1.1 已完成；doc validate §7 已完成）；5 不需動作 9 項。delta 以外：孤兒稽核發現 IMP-GPD-028 只存在本地，已回報（llm-dev 3.1.0-W1-019） |
| 3.0.0 → 3.0.1 | 無需建票（分類表見 0.7.0-W1-013 Problem Analysis） | 8 條目、118 檔（removed 100，皆為發佈通道移除的 local-only 檔，本地副本不受影響）。3 守衛需配合 2 項（.skill-sync-base 與 hook-logs 的 gitignore 規則本專案已涵蓋，已完成）；5 不需動作 6 項。主線程寫入守衛放行 project-integration/，本列即由主線程寫入 |
