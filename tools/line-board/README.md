# line-board：多線開發看板（Claude Code mod）

在 Claude Code 終端機內開一個 Pane，顯示多 session 並行開發的現況：

| 區塊 | 資料來源（相對 repo root，另註明者除外） |
|------|---------------------------|
| 線與佇列 | `docs/work-logs/v0/v0.5/v0.5.0/tickets/0.5.0-W1-349.md` 的 Solution 段落（自 `## Solution` 起到下一個 `## ` 標題前）中的現行佇列行，每條線一列，依線號排序：`L<n>｜<session 名稱>［<session 狀態>］｜<票序>` |
| 佇列票即時狀態 | 票序中每個票號旁標 `〔status〕`，`→`（依序）與 `∥`（並行）原樣保留，票號後的註記接在狀態後；狀態只讀主 checkout（`git worktree list` 第一筆）的票檔 frontmatter，讀不到時標 `unknown`。不讀各 worktree 的票檔：ticket CLI 在 worktree 中也把票務寫回主 repo，worktree 內的票檔是分支開出當下的舊副本 |
| 各 session | `~/.claude/sessions/*.json`（家目錄取自 `HOME`），見下節 |
| 合併閘門 | `.claude/logs/worktree-merge.log` 中 `[合併閘門] 開始` 與 `[合併閘門] 結束` 行的最後 8 行；預檢、合併前驗收、合併前測試等其他行不顯示 |
| 更新時間 | 每 30 秒重讀一次，Pane 頂端顯示最近一次讀取的本機時間 |

## 各 session 狀態（`~/.claude/sessions/*.json`）

Claude Code 為每個執行中的 session 寫一個 `<pid>.json`，含 `name`、`cwd`、`status`（`busy`／`idle`，停下來等用戶時為 `waiting` 並附 `waitingFor`）與 `statusUpdatedAt`（epoch 毫秒）。

- **只讀副檔名為 `.json` 的檔案**。同目錄的 `<pid>.<hash>.key` 是金鑰，看板任何情況下都不讀（測試以放了 `.key` 的目錄斷言這一點）
- 只列 cwd 等於主 checkout 或位於 `git worktree list` 任一路徑之下的 session；其他專案的 session 不列出
- 以 `ps -p <pid>` 確認存活，exit 不為 0 者不列出，只在區塊末尾顯示「另有 N 個狀態檔的 pid 已結束」；`ps` 本身無法執行時視為存活
- 排序：`waiting`、`busy`、`idle`，其他狀態值排最後並原樣顯示（實測 2.1.303 另有 `shell`）。`waiting` 以黃色粗體顯示
- 每列：`<name>｜<status>[：<waitingFor>]｜<距 statusUpdatedAt 的時間>`，時間以最近一次讀取的時刻計
- 線列的 `［狀態］`：以 349 現行佇列行括號內的 session 名稱比對存活 session 的 `name`（同名多筆取最新一筆），比對不到標 `離線`；sessions 目錄讀不到時標 `狀態不明`

這是 Claude Code 的內部檔案，官方沒有文件承諾格式。Claude Code 升版後除了下方驗證指令，還要以真實的 sessions 目錄對照一次（檔案欄位、status 值）。

## 349 現行佇列行的格式（349〈看板讀取約定〉）

```text
**L<n> 現行佇列**（<session 名稱>）：<短票號，以 → 與 ∥ 分隔>
```

- 行首即 `**L`，n 必須是數字；清單項（`- **L7 …`）、表格內、以反引號引用範本的說明行都不算
- 同一條線有多行時只取最後一行，較早的行是歷史，其票號不出現在看板
- 最後一行的票序寫 `（無）` 表示這條線結束，看板不顯示該線
- 括號內的 session 名稱原樣顯示；行內沒寫時顯示「（未標 session）」

畫面能分辨兩種空狀態：「349 尚無現行佇列行」（票檔讀得到但 Solution 內沒有任何現行佇列行）與「解析失敗」（票檔讀不到）。

## 啟動

在 repo root 開一個專用的看板 session：

```bash
claude --plugin-dir tools/line-board
```

- session 啟動時自動開 Pane；關掉後輸入 `/board` 可再開
- 終端寬度不足時 Pane 嵌在 prompt 上方；fullscreen 且夠寬時停靠在側邊（門檻依 CC 版本而定，以實測為準）
- 本 mod 不改任何設定，只在帶 `--plugin-dir` 的 session 載入；不讀網路、不上傳，只讀本機檔案並執行 `git worktree list` 與 `ps -p <pid>`

## 結構

| 檔案 | 職責 |
|------|------|
| `.claude-plugin/plugin.json` | manifest，`types` 指向契約 |
| `hooks/hooks.json` | 指向 hooks module |
| `hooks/register.tsx` | 註冊 `/board`、定時讀取、繪製 Pane；讀檔與命令一律經 `$` |
| `hooks/parse.ts` | 純函式：checkout 路徑判定、現行佇列行解析（每線取最後一行）、票序拆分與格式化、frontmatter 解析、session 狀態檔篩選／解析／排序、合併閘門紀錄篩選 |
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
