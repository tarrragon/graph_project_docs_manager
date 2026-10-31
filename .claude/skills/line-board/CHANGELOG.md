# line-board 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 0.5.0（2026-10-31）— 跨專案行為變更：看板最上方新增「用戶待辦（N）」群組，集中列出要用戶處理的事項，預設展開；沒有任何一項時只顯示一行「用戶待辦：無」。

- 兩種來源，都從票面讀出：U1 協調票 Solution 段的待辦行 `**用戶待辦**（<鍵>）：<事項>`，以同鍵的完成行 `**用戶待辦完成**（<鍵>）：` 解除（不帶鍵的行以事項全文配對）；U2 各線等用戶，判定同 `line_status` 的等用戶段。格式權威是 multi-session-orchestration 的 `references/line-continuity.md` §2〈用戶待辦〉。
- 每項一行：U1 為 `<事項>｜<鍵>`（不帶鍵寫「主控」），U2 為 `<事項>｜L<n> <短票號>（S#）`；S2 洋紅粗體。
- 帶鍵與不帶鍵的項目分開配對；空括號的行略過；session 狀態讀不到且沒有任何一項時寫「用戶待辦：無（session 狀態讀不到，S2 未判）」。
- 新增 `hooks/userTodos.ts`（`parseUserTodos`、`userTodoRows`）與 `hooks/userTodosView.tsx`；`lanes.ts` 新增 `unfencedSolutionLines`，S1 標記與待辦行共用 fence 過濾；`continuity.ts` 匯出 `lanesWaiting`，`lineStatusReport` 的等用戶段改為直接呼叫它；`readers.ts` 的 `readLanes` 另帶出現行佇列行原文（`lines`）與待辦（`todos`）；`types/index.d.ts` 新增 `UserTodo`、`UserTodoRow`，`LanesResult` 加兩欄。
- `line_status` 的輸出不變。

起因：用戶回報主控要用戶處理的事項散在回覆裡，被 Stop hook 回應與各線訊息淹沒，找不到（2026-10-31）。

**Version**: 0.4.0（2026-10-31）— 跨專案行為變更：`line_status` 輸出多一段「等用戶（N）」，列出停在等用戶的線，每項一行 `L<n>（名稱）<票號>：<事項>（S1／S2／S3）`；沒有任何一項時寫「等用戶：無」。這一段與過期項分列。

- 三種訊號：S1 佇列中未 completed 的票，其 Solution 段最後一行等用戶標記（`**等用戶**：`，`**等用戶解除**：` 解除）；S2 該線 session 的 `status` 為 `waiting`；S3 現行佇列行的票註記或文字含「等用戶」。已收線的線不判。訊號定義的權威是 multi-session-orchestration 的 `references/line-continuity.md` §2〈等用戶〉。
- S1 標記只認嚴格行首、不在 fenced code block 內的行；冒號後沒寫事項照樣列出（`標記未附事項`），只有解除行能清除。
- `continuity.ts` 新增 `parseWaitingMark`、`ticketStatusOf`（票檔原文組成 status、title、waiting，`readers.ts` 的 `readTicketStatus` 讀到票檔後一律經此）與等用戶判定；`lanes.ts` 匯出 `solutionLines`；`types/index.d.ts` 新增 `WaitingSource`、`WaitingItem`，`LineStatusReport` 加 `waiting`，`TicketStatus` 加選填的 `waiting`。
- 看板畫面不變。

起因：一條線把待用戶實測的事項寫在票面卻沒有傳訊，主控沒讀到，直到用戶問起才發現；用戶裁定加入偵測（2026-10-31）。

**Version**: 0.3.1（2026-10-31）— 文件：`references/board-screens.md` 新增〈實機驗證時的載入時機〉，記錄 `/clear` 不重新觸發 plugin 的 `session.start`，以及 plugin 檔案變動時既有 session 可能熱重載（實測時間點不一）；`SKILL.md` 按需讀取表加路由。起因：`line_status` 合併後實測，有一個 session 晚數分鐘才看到工具（2026-10-31）。

**Version**: 0.3.0（2026-10-31）— 跨專案行為變更：plugin 載入的 session（含代理人 session）多一個模型可呼叫的唯讀工具 `mcp__line-board__line_status`，位於 ToolSearch 後面。

- 輸出每條未收線的線的接續狀態（/clear 後繼續、/compact 後繼續、新 session 接手、無人持有、來源不明）與判讀依據，已收線合併一行。
- 列出過期項：票序以收線記號開頭但後面還有文字、名稱不在存活 session 中但仍有佇列、佇列的票全部 completed 但還沒收線。
- 判讀規則只在新的 `hooks/continuity.ts` 實作一份；`lanes.ts` 新增 `parseLaneLines`（保留收線的線的原文），`parseLanes` 改由它濾出。
- 看板行為變更：收線判定改由 `lanes.ts` 的 `endedForm` 決定（看板與工具共用），票序整段為 `（結束）` 的線也不再顯示，原本只認 `（無）`，與 multi-session-orchestration 的收線定義不一致。
- `types/index.d.ts` 補 `McpToolInputs` 宣告，否則手動型別檢查擋下 `tool.call` 的過濾名稱。

起因：主控換 session 後要靠用戶提示接續，且附說明的收線寫法使收線的線一直顯示離線；用戶依 WRAP 裁定由看板提供判讀工具（2026-10-31）。

**Version**: 0.2.0（2026-10-28）— 跨專案行為變更：所有 consumer 專案 sync 後，session 啟動多一個看板 plugin（`defaultEnabled: true`，skills 目錄自動載入，須接受 workspace trust）。看板只在專案設定檔 `.claude/project-integration/multi-session.json` 的 `coordinationTicket` 成立時自動開 Pane 並定時讀取；沒有設定檔或設定不成立時不自動開 Pane、不定時讀取，輸入 `/board` 才顯示設定提示（原因、設定檔路徑、格式）。不要看板的專案在 `enabledPlugins` 設 `"line-board@skills-dir": false`。`SKILL.md` 補齊啟用與關閉、設定檔格式、無設定行為、合併閘門套件範例；原 `README.md` 的畫面規格移入 `references/board-screens.md`（skill 不帶 README）。起因：用戶裁定看板所有專案預設開啟（2026-10-21）。

**Version**: 0.1.0 — 從專案工具目錄搬入 `.claude/skills/line-board/`，成為 skill 形態的 plugin；`SKILL.md` 為佔位。
