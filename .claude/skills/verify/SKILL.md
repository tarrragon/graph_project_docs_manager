---
name: verify
description: 檔案監看（DirectoryWatchSource／FSEvents）實機驗證配方。含 fseventsd 健康閘門與金絲雀探針，閘門紅時回報環境不可驗證而非 App 失敗。驗證監看行為、驅動 app 觀察 runtime log 時使用。
---

# verify：檔案監看實機驗證配方

## 為何有閘門

宿主機 fseventsd 卡住（CPU 持續約 100%）時，系統只回應歷史查詢、不推送即時事件，App 監看收到 0 筆事件。實測：重啟 fseventsd 後 CPU 降至 3%，同一份 build 立即收到事件。沒有閘門會把環境故障誤判為 App 缺陷。

## 用法

```bash
.claude/skills/verify/watch-verify.sh              # 完整流程，於 App 專案根目錄執行
.claude/skills/verify/watch-verify.sh --gate-only  # 只跑閘門
.claude/skills/verify/test_watch_verify.sh         # 腳本自測
node .claude/skills/verify/test_vm_log.mjs                # vm_log 截斷還原自測
```

## 流程

| 步驟 | 動作 | 判讀 |
|------|------|------|
| 0 | 閘門：fseventsd CPU 三次取樣（上限 `WV_CPU_LIMIT`，預設 50）+ 金絲雀探針（node fs.watch 寫檔須收到即時事件） | 任一紅 -> exit 3 `ENV_UNVERIFIABLE`，停止，不判 App |
| 1 | `fvm flutter run -d macos --start-paused` 背景啟動，記錄 PID | 取不到 VM service URI -> exit 4 |
| 2 | `vm_log.mjs` 訂閱 Logging 後 resume，直接寫檔（不經 grep 管線）。message 被 VM service 截斷（`valueAsStringIsTruncated`）時以 `getObject` 取全文；失敗則寫截斷值並附 `[TRUNCATED: getObject failed: ...]` 標註 | -- |
| 3 | 在 App 保存的 workspace（`defaults read com.example.graphProjectDocsManager flutter.workspace.path` 加 `/docs`，`WV_WATCH_DIR` 可覆寫，讀不到 -> exit 3）新建、追加、刪除 `experiment-watch-verify-<pid>.md` | -- |
| 4 | 以 sequenceNumber 連續判讀：有缺號或空 log -> exit 4；log 中路徑含 experiment 檔名的 add 與 remove 事件各至少一筆 -> exit 0（其他路徑事件不計）；否則 exit 1 App 失敗 | -- |
| 5 | trap 收尾：刪 experiment 檔、`kill` 啟動的 PID 及子程序 | 任何路徑皆執行 |

## 本專案的檢查命令

承接 `system-misjudgment` skill 的 FS-3 條目移出的本專案事實（依據 PC-GPD-082：專案專用內容不放進會推 canonical 的 skill）。

| 項目 | 命令或值 |
|------|---------|
| bundle id | 讀 `macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_BUNDLE_IDENTIFIER` |
| App 保存的 workspace | `defaults read <bundle-id> flutter.workspace.path` |
| 監看目錄 | workspace 路徑加 `/docs`（`WV_WATCH_DIR` 可覆寫） |
| 判讀 | experiment 檔路徑必須落在監看目錄下；讀不到 workspace -> exit 3，不退回 cwd |

## 禁止

- 收 log 不接 `| grep` 管線（多層 grep 加 Monitor 曾截斷行、漏後續事件）。
- 不用 `pkill`／`killall`（含 fseventsd）；只 `kill <PID>`。fseventsd 重啟需用戶在 Terminal.app 執行 `sudo killall fseventsd`。
- 退出碼 3 時不得回報 App 失敗。
