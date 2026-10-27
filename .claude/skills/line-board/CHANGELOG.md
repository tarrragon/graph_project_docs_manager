# line-board 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 0.2.0（2026-10-28）— 跨專案行為變更：所有 consumer 專案 sync 後，session 啟動多一個看板 plugin（`defaultEnabled: true`，skills 目錄自動載入，須接受 workspace trust）。看板只在專案設定檔 `.claude/project-integration/multi-session.json` 的 `coordinationTicket` 成立時自動開 Pane 並定時讀取；沒有設定檔或設定不成立時不自動開 Pane、不定時讀取，輸入 `/board` 才顯示設定提示（原因、設定檔路徑、格式）。不要看板的專案在 `enabledPlugins` 設 `"line-board@skills-dir": false`。`SKILL.md` 補齊啟用與關閉、設定檔格式、無設定行為、合併閘門套件範例；原 `README.md` 的畫面規格移入 `references/board-screens.md`（skill 不帶 README）。起因：用戶裁定看板所有專案預設開啟（2026-10-21）。

**Version**: 0.1.0 — 從專案工具目錄搬入 `.claude/skills/line-board/`，成為 skill 形態的 plugin；`SKILL.md` 為佔位。
