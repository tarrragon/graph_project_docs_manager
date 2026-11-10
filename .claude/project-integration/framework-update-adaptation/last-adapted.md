# 框架更新適應 — 狀態記錄

> 本檔由 `framework-update-adaptation` skill 維護，每個專案各一份（位於 `project-integration/`，sync 雙向排除）。Step 1 讀 last-adapted 作為起點；Step 5 在全部分類完成後更新。

## last-adapted

**3.1.0**

## 適應歷史

| 版本區間 | 紀錄票 | 結論摘要 |
|---------|-------|---------|
| 2.86.0 → 2.87.0 | 無需建票（驗證實跑紀錄見 0.6.0-W1-180 Solution） | 9 條目、18 檔。不需動作 8 條目（含 statusline_lane.py 僅權限位）；consumer 產物要重驗 1 條目（closed_by 邊），內嵌副本已同步，已完成 |
| 2.87.0 → 3.0.0 | 0.7.0-W1-002.1 | 14 條目、53 檔，無 removed／renamed。2.88.0～2.90.0 由本專案以主控方身份推送，本專案即來源。分類結果：1 本地特化 1 項（DOC-008，衝突採 upstream 1.2.0，已完成）；3 守衛需配合 1 項（首次升級 pull 帶入 .github/，本地已刪，回報上游，llm-dev 3.0.1-W1-005）；4 產物重驗 3 項（CLAUDE.md §1 兩段、§8 patch 規則與 tech-decisions 補記，0.7.0-W1-002.1.1 已完成；doc validate §7 已完成）；5 不需動作 9 項。delta 以外：孤兒稽核發現 IMP-GPD-028 只存在本地，已回報（llm-dev 3.1.0-W1-019） |
| 3.0.0 → 3.0.1 | 無需建票（分類表見 0.7.0-W1-013 Problem Analysis） | 8 條目、118 檔（removed 100，皆為發佈通道移除的 local-only 檔，本地副本不受影響）。3 守衛需配合 2 項（.skill-sync-base 與 hook-logs 的 gitignore 規則本專案已涵蓋，已完成）；5 不需動作 6 項。主線程寫入守衛放行 project-integration/，本列即由主線程寫入 |
| 3.0.1 → 3.0.2 | 無需建票（分類見 0.7.0-W1-010 Solution〈框架 v3.0.2 升級〉） | 6 條目、18 檔，無 removed／renamed，pull 無衝突。3 守衛需配合 1 項（巢狀名稱判定收進 lib，兩個 SessionStart hook 改呼叫它）：本專案 .gitignore 第 133 行 `.skill-sync-base` 經 `git check-ignore` 實測涵蓋 skill 目錄下的標記，3.0.1 的改寫建議未採用，已完成；5 不需動作 5 項（PC-LLM-001 與專案代號登記為純知識庫新增；component-contract-design 3.14.0 由本專案推送，pull 後與本地一致；ticket 2.48.1、doc 1.25.1 只升版號；CHANGELOG、VERSION；Known issues 的方法論與範本缺欄已由本專案回報為 llm-dev 3.1.0-W1-037，SPEC-004 依 skill 填寫） |
| 3.0.2 → 3.1.0 | 1.0.0-W1-101 | 21 條目、514 個 delta，5 個衝突（code-smell-checklist、multi-session-orchestration SKILL.md 整檔衝突，本地無獨有內容，採 upstream；error-patterns/README 與 system-misjudgment 兩邊保留，本地 GW-5 改號 GW-6）。1 本地特化 4 項（已完成）；3 守衛需配合 1 項（closed_by 值域收緊，存量清理建 1.0.0-W1-101.1）；4 產物重驗 3 項（doc 重驗通過、sync base 手動設為 28d5e1132c、CLAUDE.md §1 改引〈修復時點：版本分診〉，皆已完成）；5 不需動作 13 項。delta 以外：audit/README.md 檔名既有違規建 1.0.0-W1-102；0.7.0 期間回報的上游修正建驗證票 1.0.0-W1-103 |
