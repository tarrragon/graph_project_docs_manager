# macOS FSEvents／fseventsd／檔案監看

被測物通常是以 `package:watcher` 一類套件監看目錄的桌面 App。可執行配方：`.claude/skills/verify/watch-verify.sh`。

## FS-1 監看零事件，被讀成 App 缺陷

| 欄位 | 內容 |
|------|------|
| 症狀 | 實機上操作檔案，App 與原生 FSEvents 探針都收不到即時事件；測試套件全綠 |
| 常見誤判 | 程式碼在監看第一環斷鏈，派出 incident 分析或補 log 的修正批 |
| 實際機制 | 宿主 `fseventsd` 卡住（CPU 持續約 100%），只回應歷史查詢、不推送即時事件，與 App 無關 |
| 檢查方法 | `ps -axo pcpu,comm \| grep fseventsd` 取三次樣（間隔數秒）；再跑 `.claude/skills/verify/watch-verify.sh --gate-only`（金絲雀：新建空目錄寫檔，須收到即時事件） |
| 正向對照 | 重啟 `fseventsd` 後同一份 build、同一組操作立即觸發事件；金絲雀在健康環境必須收到事件，收不到時先懷疑環境或探針 |
| 判讀標準 | 三次取樣皆低於 `WV_CPU_LIMIT`（預設 50）且金絲雀收到事件 → 進入正式驗證；任一紅 → 結論「環境不可驗證」（腳本 exit 3），不判 App 失敗 |
| 來源 | 機制：否定結果在環境與觀測工具未經正向對照前沒有鑑別力；實測依據：重啟 `fseventsd` 後同一份 build 立即收到事件 |

## FS-2 以事件總數判 PASS，被他人寫入污染成假 PASS

| 欄位 | 內容 |
|------|------|
| 症狀 | 驗證期間監看目錄收到的新增事件數達標，判 PASS |
| 常見誤判 | 事件數增加等於自己的操作被偵測到 |
| 實際機制 | 同一目錄同時有其他 session 的寫入；實測 12 筆新增事件中 9 筆來自他人票面寫入 |
| 檢查方法 | 驗證時只建立一個帶 pid 的 experiment 檔（`experiment-watch-verify-<pid>.md`），在事件 log 中只計路徑含該檔名的 add 與 remove，其他路徑的事件不計。計數：`grep -c "experiment-watch-verify-<pid>" <vm.log>`，再分別數其中的 add 與 remove 行 |
| 正向對照 | `test_watch_verify.sh` 的 E2 案例：只有他路徑事件時必須 exit 1；experiment 檔 add 加 remove 必須 exit 0 |
| 判讀標準 | experiment 檔自己的 add 與 remove 各至少一筆 → PASS；總數再多也不採計 |
| 來源 | 機制：觀測完整性，驗證通過須以自己操作的事件為準；實測依據：verify 配方首跑 12 筆新增事件中 9 筆來自他人寫入 |

## FS-3 在 worktree 內驗證，寫到 App 沒監看的目錄

| 欄位 | 內容 |
|------|------|
| 症狀 | 在 worktree 內操作檔案，App 沒有事件，判 App 失敗 |
| 常見誤判 | 監看範圍以 cwd 為準，沒事件就是 App 沒偵測到 |
| 實際機制 | App 監看的是它保存的 workspace（`flutter.workspace.path`），不是 cwd；worktree 內的檔案不在其中 |
| 檢查方法 | 先取 bundle id：讀 `macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_BUNDLE_IDENTIFIER`；再 `defaults read <bundle-id> flutter.workspace.path`，監看目錄為其值加 `/docs`；寫入 experiment 檔的路徑必須落在此目錄下 |
| 正向對照 | `test_watch_verify.sh`：讀不到 workspace.path 必須 exit 3，不得退回 cwd |
| 判讀標準 | 寫入路徑在 App 監看目錄下才有資格判 App 行為；路徑不在 → 驗證無效，不是 App 失敗 |
| 來源 | 實測依據：verify 配方對 workspace.path 的取得邏輯（見 `.claude/skills/verify/SKILL.md` 步驟 3） |

## FS-4 刪除監看根目錄，後續事件被讀成遺漏

| 欄位 | 內容 |
|------|------|
| 症狀 | 刪除整個被監看目錄後，只看到逐檔 remove，最後串流以錯誤或結束收尾 |
| 常見誤判 | 事件遺失，或串流異常屬 bug |
| 實際機制 | macOS 先逐檔送出 remove，約 0.1 s 內串流再以錯誤或結束收尾；套件在去抖窗內累積的 remove 隨監看停止而未送出，畫面維持舊結果 |
| 檢查方法 | 以 VM service 取 log 寫檔（見 `references/dart-vm-service-log.md` DV-1），讀停止監看那筆 warning 的完整訊息與其前的 remove 序列 |
| 正向對照 | 刪除一般子目錄（非根）時，監看應持續運作且後續事件照常 |
| 判讀標準 | 「逐檔 remove 加串流收尾」是根目錄被刪的預期序列，是否符合規格以規格條文判，不以事件有無判 |
| 來源 | 實測依據：刪除監看根目錄的 runtime 補驗記錄 |

## FS-5 `/private` 路徑前綴，被讀成路徑對不上

| 欄位 | 內容 |
|------|------|
| 症狀 | 事件路徑與寫入路徑字串前綴不同（`/private/var/...` 與 `/var/...`） |
| 常見誤判 | 路徑比對失敗導致事件被丟棄 |
| 實際機制 | FSEvents 回報的相對路徑與寫入路徑一致，`/private` 前綴差異不影響以相對路徑比對的結果 |
| 檢查方法 | 比對相對於監看根的路徑，不比對絕對路徑字串；`realpath <path>` 可確認同一檔案的兩種寫法 |
| 正向對照 | 金絲雀在 `/var/folders` 下的臨時目錄寫檔，事件的相對路徑與寫入的相對路徑一致 |
| 判讀標準 | 相對路徑一致即視為同一檔案；僅絕對路徑前綴不同不構成失敗證據 |
| 來源 | 實測依據：金絲雀實機驗證記錄 |
