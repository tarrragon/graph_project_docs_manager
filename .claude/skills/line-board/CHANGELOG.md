# line-board 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 0.3.0（2026-10-31）— 跨專案行為變更：plugin 載入的 session（含代理人 session）多一個模型可呼叫的唯讀工具 `mcp__line-board__line_status`，位於 ToolSearch 後面。

- 輸出每條未收線的線的接續狀態（/clear 後繼續、/compact 後繼續、新 session 接手、無人持有、來源不明）與判讀依據，已收線合併一行。
- 列出過期項：票序以收線記號開頭但後面還有文字、名稱不在存活 session 中但仍有佇列、佇列的票全部 completed 但還沒收線。
- 判讀規則只在新的 `hooks/continuity.ts` 實作一份；`lanes.ts` 新增 `parseLaneLines`（保留收線的線的原文），`parseLanes` 改由它濾出。
- 看板行為變更：收線判定改由 `lanes.ts` 的 `endedForm` 決定（看板與工具共用），票序整段為 `（結束）` 的線也不再顯示，原本只認 `（無）`，與 multi-session-orchestration 的收線定義不一致。
- `types/index.d.ts` 補 `McpToolInputs` 宣告，否則手動型別檢查擋下 `tool.call` 的過濾名稱。

起因：主控換 session 後要靠用戶提示接續，且附說明的收線寫法使收線的線一直顯示離線；用戶依 WRAP 裁定由看板提供判讀工具（2026-10-31）。

**Version**: 0.2.0（2026-10-28）— 跨專案行為變更：所有 consumer 專案 sync 後，session 啟動多一個看板 plugin（`defaultEnabled: true`，skills 目錄自動載入，須接受 workspace trust）。看板只在專案設定檔 `.claude/project-integration/multi-session.json` 的 `coordinationTicket` 成立時自動開 Pane 並定時讀取；沒有設定檔或設定不成立時不自動開 Pane、不定時讀取，輸入 `/board` 才顯示設定提示（原因、設定檔路徑、格式）。不要看板的專案在 `enabledPlugins` 設 `"line-board@skills-dir": false`。`SKILL.md` 補齊啟用與關閉、設定檔格式、無設定行為、合併閘門套件範例；原 `README.md` 的畫面規格移入 `references/board-screens.md`（skill 不帶 README）。起因：用戶裁定看板所有專案預設開啟（2026-10-21）。

**Version**: 0.1.0 — 從專案工具目錄搬入 `.claude/skills/line-board/`，成為 skill 形態的 plugin；`SKILL.md` 為佔位。
