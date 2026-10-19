# line-board：多線開發看板（Claude Code mod，第一階段）

在 Claude Code 終端機內開一個 Pane，顯示多 session 並行開發的現況：

| 區塊 | 資料來源（相對 repo root） |
|------|---------------------------|
| 線與佇列 | `docs/work-logs/v0/v0.5/v0.5.0/tickets/0.5.0-W1-349.md` 的〈分派〉段落（自 `### 分派` 起到下一個 `## ` 標題前），以 Markdown 原樣呈現 |
| 佇列票即時狀態 | 佇列行（含「佇列：」的行）中每個票號旁標 `〔status〕`；狀態只讀主 checkout（`git worktree list` 第一筆）的票檔 frontmatter，讀不到時標 `unknown`。不讀各 worktree 的票檔：ticket CLI 在 worktree 中也把票務寫回主 repo，worktree 內的票檔是分支開出當下的舊副本 |
| 合併閘門 | `.claude/logs/worktree-merge.log` 最後 8 行 |
| 更新時間 | 每 30 秒重讀一次，Pane 頂端顯示最近一次讀取的本機時間 |

畫面能分辨兩種空狀態：「沒有資料」（票檔讀得到但找不到〈分派〉標題）與「解析失敗」（票檔讀不到）。

## 啟動

在 repo root 開一個專用的看板 session：

```bash
claude --plugin-dir tools/line-board
```

- session 啟動時自動開 Pane；關掉後輸入 `/board` 可再開
- 終端寬度不足時 Pane 嵌在 prompt 上方；fullscreen 且夠寬時停靠在側邊（門檻依 CC 版本而定，以實測為準）
- 本 mod 不改任何設定，只在帶 `--plugin-dir` 的 session 載入；不讀網路、不上傳，只讀本機檔案並執行 `git worktree list`

## 結構

| 檔案 | 職責 |
|------|------|
| `.claude-plugin/plugin.json` | manifest，`types` 指向契約 |
| `hooks/hooks.json` | 指向 hooks module |
| `hooks/register.tsx` | 註冊 `/board`、定時讀取、繪製 Pane；讀檔與命令一律經 `$` |
| `hooks/parse.ts` | 純函式：主 checkout 判定、段落擷取、佇列票號抽取與標示、frontmatter 解析、紀錄尾端 |
| `types/index.d.ts` | `$.state` 值（`line-board.snapshot`）的型別契約 |
| `hooks/board.test.ts` | `claude plugin test` 測試 |

`.claude-plugin/types/` 與根目錄 `tsconfig.json` 由 Claude Code 載入 mod 時自動產生，不需手寫。

## 驗證（Claude Code 升版後必須重跑）

mod API 屬 early access，各版本間會變，權威是 Claude Code 寫出的型別檔。升版後依序執行：

```bash
claude plugin validate tools/line-board   # manifest 與 hooks module 靜態檢查
tsc -p tools/line-board                   # 型別檢查（需先以 --plugin-dir 啟動過一次，讓 CC 寫出 types 與 tsconfig）
claude plugin test tools/line-board       # 執行 hooks/*.test.ts
```

尚未以 `--plugin-dir` 啟動過時，`tsc` 改用 plugin-authoring skill 型別檔表頭的 `tsconfig.json`（放在 mod 資料夾外，`include` 指向該型別檔與本 mod 的 `hooks`、`types`）。
