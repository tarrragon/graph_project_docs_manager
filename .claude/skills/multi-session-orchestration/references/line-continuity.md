# 各線的接續狀態與主控自我接續

本檔說明兩件事：

- 主控 PM 怎麼判斷每條線目前的接續狀態：已收線、`/clear` 後繼續、`/compact` 後繼續，或由新 session 接手。
- 主控自己 `/clear` 或 `/compact` 之後，怎麼在不靠用戶提示的情況下接回協調工作。

內容包括：判讀用的資料來源、四種狀態的判讀依據與接續動作、主控自我接續的步驟。

**為何要有本檔**：

- 線執行 `/clear` 之後，對話 context 全部消失；執行 `/compact` 之後，只剩摘要；換成新 session 時，從零開始。三種情況的接續動作不同。
- 但從 `ListAgents` 看，三種情況都只是「一個名稱，閒置中」。主控如果只看名稱與啟動時間，就會判斷錯誤。
- 實例：一個 session 在 13 小時前啟動，主控判斷它是「舊 session、尚未換手」。實際上它 13 秒前才做過 `/clear`，已經只能讀票面接手。

**量測版本**：Claude Code 2.1.314（2026-10-31，macOS）。session 檔與 SessionStart 的 `source` 欄位都是 Claude Code 的內部行為，沒有相容承諾。升版後先依 §6 重新核對。

---

## 1. 資料來源

| 來源 | 讀什麼 | 用途 |
|------|--------|------|
| 協調票 `## Solution` 段 | 每條線最後一行現行佇列行：線號、session 名稱、票序 | 線的佇列與持有者。格式見 `session-naming.md`〈用語〉 |
| `ListAgents` | 同儕 session 的名稱與閒置狀態；第一行是本 session 的自稱 | 哪些名稱目前可以定址；主控確認自己的名稱 |
| `~/.claude/sessions/<pid>.json` | `name`、`sessionId`、`cwd`、`status`、`pid`、`procStart` | 名稱對應到現行 `sessionId`；存活判定見 `shared-resources.md` §6。只讀 `*.json`，不讀 `*.key` |
| `.claude/hook-logs/session-source-diagnostic/diagnostic.log` | 每行 `[<時間>] source=<值> session_id=<前 8 碼>` | 某個 `sessionId` 最近一次 SessionStart 的來源：`startup`、`resume`、`clear`、`compact` |

**`sessionId` 的變化規則**：

- `/clear`：pid 和名稱不變，`sessionId` 換新，log 記錄的是新的 id。實測：兩個 session 各執行一次 `/clear`，log 都寫 `source=clear`，id 也都等於 session 檔中的新 `sessionId`。
- `/compact`：`sessionId` 不變。實測：同一個 id 在 log 中出現兩次 `source=compact`。
- 新開的 session：pid 是新的，log 記一筆 `source=startup`。這一點是依 SessionStart 欄位的定義推得，本次量測沒有觀察到新開 session 的實例。
- 不能用 `startedAt` 判斷 `/clear`：實測 `/clear` 之後，`startedAt` 沒有更新成 `/clear` 的時間。

**限制**：

- log 由本專案的 SessionStart hook 寫入，只記錄在本 repo 啟動的 session。
- log 在 gitignore 範圍內，只存在本機。
- 在 worktree 內啟動的 session，會寫入 worktree 自己的 `.claude/hook-logs/`。
- 讀不到某個 id 的紀錄時，判為「來源不明」，不要猜測。

---

## 2. 四種接續狀態

| 狀態 | 判讀依據 | 該線剩下的 context | 主控的接續動作 |
|------|---------|-------------------|---------------|
| 已收線 | 該線最後一行現行佇列行的票序是 `（無）` 或 `（結束）` | 不需要 | 不再派票。session 若仍在 `ListAgents` 中，請用戶關閉，否則它可能被誤選為傳訊對象（`session-naming.md` §4） |
| `/clear` 後繼續 | pid 和名稱不變；session 檔的 `sessionId` 在 log 中最後一筆是 `source=clear`，時間晚於主控上次核對 | 對話全部清空，只剩票面 | 確認該線的接手點已寫進票面（〈階段收尾狀態〉或接續點段落）。若沒有寫，舊對話已經清空，無法再請該線補寫，改由主控依 git log 與票面重建接手點並寫入。傳訊時寫明票號和段落名稱，指出接手位置。名稱沒變，所以現行佇列行不用改 |
| `/compact` 後繼續 | `sessionId` 不變，log 中同一個 id 最後一筆是 `source=compact`，時間晚於主控上次核對 | 只剩摘要，細節可能遺失 | 不需要重新指派。該線下一次寫協調票時，主控核對寫法。壓縮後最常見的錯誤是把佇列行改寫成條列文字，見 SKILL.md〈佇列變動時同一步寫現行佇列行〉 |
| 新 session 接手 | `ListAgents` 出現新名稱，pid 是新的，log 最後一筆是 `source=startup` | 從零開始 | 以 `ListAgents` 中的實際名稱寫目標行和現行佇列行，再傳訊指派（`session-naming.md` §4）。如果接手的是舊線，而舊 session 還在，請用戶關閉舊 session |

**另一種情況：線還有佇列，但持有它的 session 已經不在**。判讀依據是：現行佇列行上的名稱不在 `ListAgents` 中，或 session 檔的存活判定不符。這條線目前沒有任何 session 持有，不要對它傳訊。處理方式二選一：請用戶開新 session 接手，或依 SKILL.md〈線空出時移票〉把票移給其他線。

---

## 3. 判讀步驟

以下三種時機都要依序執行：每一輪佇列更新前、主控自己接續時、用戶提到某條線換過 session 時。

1. 讀 `.claude/project-integration/multi-session.json` 的 `coordinationTicket`，再以 `ticket track full <協調票>` 取得 `## Solution` 段。每條線以這一段中最後一行現行佇列行為準。Completion Info 中若有舊的佇列行，不要當作現況。
2. 執行 `ListAgents`，記下每個同儕的名稱和本 session 的自稱。
3. 讀 `~/.claude/sessions/*.json`，以 `cwd` 篩出本 repo 的 session，取得每個名稱對應的 `pid` 和 `sessionId`。
4. 以每個 `sessionId` 的前 8 碼 grep `diagnostic.log`，取最後一筆的 `source` 和時間。
5. 以協調票上主控最後一次核對的時間為基準，依 §2 判斷每條線的狀態。
6. 只要有一條線的狀態和協調票上的記錄不同，就在協調票追加一段〈各線接續狀態核對（<日期 時間>）〉。這一段逐線寫出狀態和判讀依據（`sessionId` 前 8 碼和 log 時間），並更正先前的誤判。

步驟 3、4 可用以下唯讀查詢（只讀 `*.json`），在 repo 根目錄執行：

```bash
python3 - <<'EOF'
import json, glob, os
repo = os.getcwd()
log = open('.claude/hook-logs/session-source-diagnostic/diagnostic.log').read().splitlines()
for f in glob.glob(os.path.expanduser('~/.claude/sessions/*.json')):
    d = json.load(open(f))
    if d.get('cwd') != repo:
        continue
    sid = d['sessionId'][:8]
    last = [l for l in log if f'session_id={sid}' in l][-1:]
    print(d.get('name'), d['pid'], sid, d.get('status'), last or '來源不明')
EOF
```

---

## 4. 主控自身 `/clear` 或 `/compact` 後的自我接續

**觸發條件**：主控 session 在 `/clear` 或 `/compact` 之後收到第一則訊息時，不論訊息內容是什麼，都先完成以下步驟，再處理訊息。不需要等用戶指出協調票或接續點。

**判斷自己是不是主控**：名稱是「主控」的 session 就是主控線（用戶裁定，2026-10-31）。以 `ListAgents` 第一行列出的本 session 自稱為準。

| 情況 | 做法 |
|------|------|
| 本 session 名為「主控」 | 本 session 就是主控，依下方步驟接續 |
| 本 session 不叫「主控」，而 `ListAgents` 中有其他 session 叫「主控」 | 本 session 是一般的線，不執行主控接續 |
| 沒有任何 session 叫「主控」 | 不要自行決定由誰擔任主控。列出目前的 session 和各自持有的線，請用戶指定其中一個 session 擔任主控，並請用戶在那個 session 輸入 `/rename 主控` |

**步驟**：

1. 依 §3 步驟 1 找到協調票，讀 `## Solution` 段最後幾段，找出前一個主控最後處理的事項和各線的現行佇列。
2. 依 §3 步驟 2 到 5 判讀每條線的接續狀態。用戶常常在清除主控的同時，也清除其他線，所以不能沿用前一個主控的判斷。
3. 在協調票追加〈主控接續（<clear 或 compact>，<日期 時間>）〉段，內容包括：
   - 各線狀態（格式同 §3 步驟 6）
   - 前一個主控留下的待辦
   - 需要更正的地方
4. 推送協調票的 commit。
5. 先向用戶回報各線狀態和下一步，再處理用戶的訊息。

**名稱與線不一致時，提醒用戶**：判讀各線時也要核對名稱。用戶和主控靠名稱確認「現在討論的是哪一條線」，這是唯一的依據。名稱不符時，雙方會以為在談同一條線，實際上談的是不同的線。下表中的每項提醒都要寫出具體的名稱，讓用戶可以直接照著輸入。

| 情況 | 提醒用戶 |
|------|---------|
| 某個 session 的主軸已經換成另一條線，名稱仍是舊線的主題 | 請用戶在該 session 輸入 `/rename <新線主題>`。主控在同一步追加現行佇列行，括號內填新名稱（`session-naming.md` §3） |
| 要開新 session 接線 | 先告訴用戶新 session 的名稱，例如 `claude -n 拆檔`。等名稱出現在 `ListAgents` 中，才寫目標行和現行佇列行 |
| session 的名稱是自動產生的衍生名稱（例如 `<repo>-3e`），而它持有一條線 | 請用戶改成線主題的名稱 |

**`/compact` 和 `/clear` 的差別**：`/compact` 之後主控還有摘要，但摘要可能漏掉佇列細節和前一輪的更正。所以 `/compact` 之後同樣要重讀 Solution 段最後幾段，並重新判讀各線，不能只依靠摘要。

**這套流程的前提**：主控在 `/clear` 之前，已經把只存在對話中的待辦寫進協調票（`wrap-up-and-handoff.md` §3）。沒有寫進去的事項，接續之後無法找回。

---

## 5. 用戶說「繼續工作」時：開線計畫表

**做法**：主控收到「繼續工作」這類沒有指定對象的指示時，不直接派票，依序做三件事：

1. 依 §4 完成自我接續，取得各線的現況。
2. 整理工作內容：各線現行佇列、未分派的票、等用戶裁定的事項。
3. 以下方固定格式列出開線計畫表，經用戶確認後才開線、寫佇列行、傳訊。

理由：「繼續工作」只授權推進，不代表授權開哪些線、開幾條線。主控直接派票的話，用戶要等到看見各線動作，才知道主控做了哪些安排。開線計畫表把這些安排先攤開，讓用戶在任何 session 啟動之前就能調整。

**開線計畫表格式**（每條線一列，已收線的線不列入）：

| 欄位 | 內容 |
|------|------|
| 線 | 線號，例如 `L37`。新線使用下一個未用過的號碼 |
| 動作 | 從下列五種中選一種：`新開`、`/clear 後接續`、`/compact 後接續`、`沿用`（session 正在執行，佇列沒有變動）、`改名接續`（session 不變，主軸換成這條線） |
| session 名稱 | 該線使用的名稱（線主題，主控為「主控」） |
| 用戶要做的事 | 用戶照著輸入的指令，例如 `claude -n 拆檔`、在 UX實驗 輸入 `/rename 版面斷言`。不需要用戶操作時寫 `—` |
| 目標 | 一句話寫出這條線要完成什麼。新線的目標會成為目標行 |
| 佇列 | 票序，格式同現行佇列行的票序 |
| 名額 | `heavy` 或 `light`，寫在哪一張票會用到 heavy |
| 注意 | 前置條件、等待的裁定、和其他線的衝突；沒有時寫 `—` |

表格下方另列兩項：

- **未分派的票**：這次不開線處理的票，每張附一句不開線的理由，例如「等用戶裁定」「依框架修補節奏不排線」。
- **待用戶裁定**：開線之前需要用戶回答的問題。

用戶確認後，主控依表格逐線處理：名稱出現在 `ListAgents` 中，才寫目標行與現行佇列行，然後傳訊指派。用戶修改表格的話，先更新表格，再依修改後的內容處理。

---

## 6. 升版後的確認方式

1. 在測試用的 session 執行 `/clear`。確認：
   - session 檔的 `sessionId` 已經換新，`name` 沒有變。
   - log 中有一筆 `source=clear`，id 是新的 `sessionId`。
2. 執行 `/compact`。確認 `sessionId` 沒有變，而 log 中同一個 id 多了一筆 `source=compact`。
3. 以 `claude -n <名稱>` 開一個新的 session。確認 log 中有一筆 `source=startup`。

只要有一項不符，就表示行為已經改變。先修正本檔 §1 和 §2，再繼續使用。
