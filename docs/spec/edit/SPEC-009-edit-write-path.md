---
id: SPEC-009
title: "編輯能力：寫入路徑、寫入前閘門與寫入結果"
status: draft
source_proposal: PROP-007
created: "2026-11-10"
updated: "2026-11-10"
version: "1.0"
owner: L54-main
has_functional_requirements: true

domain: "edit"
subdomain: null

related_usecases: []
related_specs: [SPEC-001, SPEC-003, SPEC-004, SPEC-006, SPEC-010]
implements_requirements: []
depends_on_domains: [workspace, schema, corpus, observability]
---

# 編輯能力：寫入路徑、寫入前閘門與寫入結果

## 概述

本規格定義 App 寫入使用者檔案的路徑。涵蓋九項：寫入前閘門、快照、原子寫入與局部改寫、路徑界內、寫入結果與驗證狀態、外部改動的發現時點、記錄的界線、變更記錄、各欄位的輸入元件。範圍與 minor 切分見 PROP-007。

**1.0 的寫入對象**只有文件節點（PROP、SPEC、UC、EVT、DomainBundle）的純量欄位，也就是非邊的單值欄位（PROP-007〈1.x minor 清單〉）。關係邊（1.1）、ticket（1.2）、內文（1.3）、結構化區塊（1.4）、檔案層級操作（1.5）在各自的 minor 規劃波補進本規格；FR-09 的對照表已涵蓋全部欄位，標明各欄自哪個 minor 起可編輯。

**1.0 不提交**：App 不建立 commit，也不動使用者的 index、refs 與 stash。App 內提交在 1.1 候選池（用戶裁定）。

**決策來源**：

| 來源 | 本規格承接的內容 |
|---|---|
| `docs/tech-decisions.md`〈2026-09-10：加入編輯能力 tripwire 的重評〉 | A 組寫入前閘門（A-1 可復原性、A-2 外部改動、A-3 路徑界內）、B 組變更記錄、C 組橫切約束、原子寫入、批次中途失敗 |
| 同檔〈補記：2026-11-10 — 1.0 編輯能力四項架構決策定案〉 | 三平面單一判準（取代 A-1 依 git 狀態分列的表）、1.0 不允許樂觀更新、三個可觀測時刻與寫入結果型別、監看活躍後的發現時點 |
| 同檔〈補記：2026-11-10 — structured log 設計八項裁定〉與 SPEC-010 | 日誌事件的信封、錯誤來源分類、欄位值白名單 |
| `1.0.0-W1-104` Solution | 逐欄位輸入元件的盤點與 WRAP |
| PROP-005〈1.0 — 編輯〉 | 寫入後呼叫唯讀驗證器的整合測試，與 `uc verify` 誤報的緩解 |

**不在本規格**：編輯狀態與唯讀降級徽章的畫面形式（SPEC-001 狀態矩陣、SPEC-003 互動反應）、表單元件的元件契約（SPEC-004，走 component-contract-design）、樂觀更新政策列（留在 SPEC-004 §2，本規格只定義該列引用的寫入結果與驗證狀態）。

## 功能需求

### FR-01: 寫入前閘門（三平面單一判準）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈補記：2026-11-10〉寫入前閘門；〈2026-09-10〉A-1、A-2 |
| 對應用例 | — |

**描述**：同一個檔案有三個平面：開始編輯時讀入的內容 M、寫入前重新讀取的磁碟內容 W、HEAD 中的內容 H。判準如下：

| 比較 | 判定 | 處置 |
|---|---|---|
| W ≠ M | 外部已改 | 不寫入，回傳閘門阻擋 `externallyModified`，要求放棄並重讀 |
| W = M，且 W ≠ H（含檔案未追蹤、H 不存在、H 無法判定） | 本次寫入會失去 HEAD 沒有的位元組 | 先快照 W（FR-02），成功才寫入；快照失敗回傳閘門阻擋 `snapshotFailed` |
| W = M = H | 寫入不會失去 git 救不回的位元組 | 直接寫入 |

一次寫入依下列順序執行，任一步不通過即停止，目標檔不變：

| 步驟 | 動作 | 不通過時 |
|---|---|---|
| 1 | 讀 W，與 M 逐位元組比較 | `blocked(externallyModified)` |
| 2 | 局部改寫並做改寫隔離檢查（FR-03） | `blocked(rewriteNotIsolated)` |
| 3 | 取 H；W ≠ H 時以步驟 1 讀到的 W 位元組快照（FR-02） | `blocked(snapshotFailed)` |
| 4 | 寫暫存檔並 fsync（FR-03） | `ioFailed` |
| 5 | 緊鄰 `rename` 前再讀一次磁碟內容，與 W 比較 | `blocked(externallyModified)`，刪除暫存檔 |
| 6 | `rename` 暫存檔取代目標檔 | `ioFailed`，刪除暫存檔 |

**約束條件**：

- M 由「開始編輯」記下：開始編輯時本 domain 自己讀取目標檔的位元組，不取 Corpus 解析時的內容。理由：Corpus 的解析結果可能早於使用者開始編輯，以它當基準會把兩者之間的外部改動誤判為未改。開始編輯時讀取失敗，回傳讀取失敗結果，不進入編輯。
- 步驟 1 或步驟 5 讀不到檔案時：檔案已不存在視為 W ≠ M（外部已改，檔案被刪或改名）；其他讀取失敗（權限等）回傳 `ioFailed`。
- 比較用位元組內容本身，不用雜湊（〈2026-09-10〉A-2：單檔 KB 級、短生命週期比對）。
- H 以 `git -C <工作區根> show HEAD:./<工作區相對路徑>` 取得。`./` 前綴使路徑相對於 `-C` 指定的目錄解析，工作區可以是 repo 的子目錄。stdout 以位元組讀取，不經字元解碼。結束碼 0 為 H 存在；結束碼 128 且 stderr 指出路徑不在 HEAD 中，為 H 不存在；其他情況為 H 無法判定。後兩者都走快照分支。
- 步驟 5 的重比把外部寫入的時窗縮到步驟 5 與步驟 6 之間。該殘餘時窗內的外部寫入會被覆蓋，為已知限制：不採檔案鎖與 `xattr` 標記（〈2026-09-10〉A-2：對不參與協定的外部編輯器無強制力）。
- **唯讀降級不進本閘門**：由本 domain 在工作區開啟時判定（以工作區根探測 `git`）。可寫或唯讀是本 domain 的狀態，不放進 Workspace：Workspace 的變更理由是資料夾存取方式，放進去會讓它知道編輯的存在（2026-11-10 主控裁定）。工作區不是 git repo，或 `git` 無法執行時，整個工作區進入唯讀降級並常駐降級徽章，編輯控制項不可用。理由：快照與 H 都需要 `git`，缺席時每次寫入都只會落入 `snapshotFailed`；在開啟時降級，與 A-1「依賴缺席 → 降級並常駐徽章」的先例一致（〈2026-09-10〉A-1 末段；`git` 缺席部分為 2026-11-10 主控裁定）。本 domain 不在每次寫入時重判；編輯期間 `git` 變為不可用時，由步驟 3 回傳 `snapshotFailed`，不靜默放行。

**驗收標準**：

- [ ] 三種判定（外部已改、需快照、直接寫入）各有 fixture repo 驗證（PROP-007 驗收第 2 條）
- [ ] 未追蹤檔與 H 無法判定時落入快照分支
- [ ] 快照失敗時目標檔內容不變，回傳 `snapshotFailed`
- [ ] 步驟 4 之後、步驟 6 之前改動目標檔（以注入模擬），回傳 `externallyModified` 且暫存檔已刪除
- [ ] 工作區為 repo 子目錄時，H 取得正確
- [ ] 非 git 工作區、`git` 無法執行時，無任何寫入路徑可達

---

### FR-02: 快照

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈2026-09-10〉A-1「快照後放行，不阻擋」 |
| 對應用例 | — |

**描述**：快照以 `git hash-object -w --stdin` 把 FR-01 步驟 1 讀到的 W 位元組寫入使用者自己的 git object database，App 只保留回傳的 blob SHA。以標準輸入餵入，不傳路徑：傳路徑時 git 會套用 `.gitattributes` 的過濾與換行轉換，存入的 blob 會與 W 不同；`--stdin` 未加 `--path` 時不套用過濾。

**約束條件**：

- 不動 index、HEAD、refs、stash，不增加 reflog 項目（〈2026-09-10〉A-1 實測）。
- 快照是 session 內的復原手段，不是備份：blob 為 unreachable object，受 `gc.pruneExpire` 管轄（預設兩週）。規格、文案與日誌不得使用「備份」一詞而不寫明期限。
- 快照 SHA 寫進 structured log（FR-07 `snapshotTaken`），供事後追溯（FR-08）。
- 快照發生時必須有可見回饋，並附取回說明。畫面形式由 SPEC-001／003 的編輯狀態承接。1.0 不提供 App 內的還原動作；取回由使用者依說明執行。
- 取回說明依本次寫入是否走快照分兩種：

| 情況 | 取回說明 |
|---|---|
| 有快照（W ≠ H） | `git cat-file -p <sha> > <路徑>` |
| 無快照（W = H） | `git checkout HEAD -- <路徑>` |

- 快照失敗（權限、repo 損壞、`git` 無法執行）一律退回阻擋，不得靜默放行。

**驗收標準**：

- [ ] 快照前後 `git status --porcelain`、`git stash list`、`git reflog` 輸出不變
- [ ] 寫入結果攜帶快照 SHA，且以 `git cat-file -p <sha>` 取回的內容逐位元組等於 W
- [ ] fixture repo 設有換行轉換的 `.gitattributes` 時，取回內容仍逐位元組等於 W
- [ ] `git` 無法執行時回傳 `snapshotFailed`

---

### FR-03: 原子寫入與局部改寫

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈2026-09-10〉〈兩項首版缺席的約束〉原子寫入；系統層 §2 Edit → Corpus 列（改寫隔離檢查） |
| 對應用例 | — |

**描述**：寫入內容由局部改寫產生：只換掉目標欄位的值所在的位元組範圍，其餘位元組（註解、欄位順序、引號、空白、內文）原樣保留。寫入以暫存檔加 `rename` 完成。

**允許變更集合**：一次欄位寫入只允許改變目標欄位與 `updated` 兩個欄位。`updated` 只在改寫前已存在時設為當天日期；缺席時不新增（2026-11-10 主控裁定）。理由：新增欄位會讓解析結果多一個鍵，與隔離檢查衝突。`id`、`created`、`version` 不由欄位寫入改動；`version` 的遞增屬內容語意，由作者決定，App 不代決。

**約束條件**：

- **欄位定位**：目標欄位與 `updated` 的值所在位元組範圍，由本 domain 以 `yaml` 套件的 `loadYamlNode` 取得節點 span。值為 anchor、alias 或 block scalar（`|`、`>`）時不嘗試改寫，直接回傳 `blocked(rewriteNotIsolated)`。
- **改寫隔離檢查**有兩道，都通過才寫入：
  1. 解析層：以 Corpus 的公開解析函式（位元組 → 解析結果，見 `docs/spec/corpus/domain-map.md` §3）分別解析改寫前與改寫後的位元組。改寫後須為可用結果，且與改寫前相比只有允許變更集合內的鍵的值改變。
  2. 位元組層：改寫前後，允許變更集合的值所在範圍以外的位元組逐位元組相同。
  理由：局部改寫的欄位定位等於一個小型的第二套解析；兩道檢查把它與 Corpus 的分歧擋在寫入前，不讓它寫壞檔案。
- **暫存檔**：放在目標檔同目錄，確保 `rename` 不跨檔案系統。檔名以 `.` 開頭、帶行程 ID 與隨機尾碼、不以 `.md` 結尾，使檔案監看與 Corpus 掃描不把它當文件。寫入後 fsync 再 `rename`；權限位元沿用原檔。任何一步失敗時刪除暫存檔。
- **1.0 一次寫入只寫一個檔**，不存在批次中途失敗。1.1 的兩檔寫入（反向欄位）在 1.1 規劃波補進本規格：寫入順序、閘門是整批判定或逐檔判定，以及第二檔失敗時的回復（〈2026-09-10〉批次中途失敗；PROP-007〈失敗防護〉第 3 列）。

**驗收標準**：

- [ ] 寫入中途中斷（以注入失敗模擬）後，目標檔內容等於寫入前，同目錄不殘留暫存檔
- [ ] 改寫一個欄位後，檔案除該值與 `updated` 外逐位元組相同
- [ ] `updated` 缺席的檔案，改寫後仍無 `updated`
- [ ] 目標欄位值為 anchor、alias 或 block scalar 時，回傳 `rewriteNotIsolated` 且目標檔不變
- [ ] 以 fixture 構造改寫後解析結果多變一個欄位的情境，回傳 `rewriteNotIsolated` 且目標檔不變
- [ ] 寫入後目標檔的權限位元與寫入前相同

---

### FR-04: 路徑界內型別

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈2026-09-10〉A-3 |
| 對應用例 | — |

**描述**：寫入函式只接受工作區相對路徑型別 `WorkspaceRelativePath`。該型別只有一個建構子，負責正規化與界內驗證，失敗回傳空值；所有來自文件欄位或畫面的路徑一律先過建構子。之後「每次寫入前驗證路徑」不需要有人記得做，違反它的程式碼寫不出來。

**約束條件**：

- 輸入的相對路徑含 `.`、`..`、空段或 NUL 字元時，建構失敗。絕對路徑建構失敗。
- 正規化分兩段：對已存在的父目錄做 symlink 解析（`resolveSymbolicLinks`，處理 `/tmp` → `/private/tmp` 這類展開）；對檔名部分做純字串處理。兩段組合後，與同樣解析過的工作區根比對。
- 界內比對以「工作區根加路徑分隔符」為前綴，不以工作區根字串本身為前綴。理由：根為 `/work` 時，`/workspace/x` 以字串前綴比對會被誤判為界內。
- 目標檔已存在時，以不跟隨連結的方式查詢其型別（`FileSystemEntity.type(path, followLinks: false)`）；為 symlink 即建構失敗。理由：父目錄解析不涵蓋檔名本身，檔名為指向工作區外的 symlink 時，`rename` 會取代連結本身，寫入意圖與結果不一致。
- 不做大小寫折疊比較，一律以解析後的結果逐位元組比對（工作區可能位於大小寫敏感的磁碟區）。
- 解析基準是使用者選定的工作區根，不是行程的工作目錄（〈2026-09-10〉A-3 現況實證：相對路徑基準錯置）。
- 與 SPEC-010 FR-03 的工作區相對路徑包裝型別是兩個型別：本型別是寫入授權，SPEC-010 的型別是日誌識別。寫入授權的路徑可轉為日誌型別，反向不行。

**驗收標準**：

- [ ] `../` 穿越、`.` 與空段、NUL、絕對路徑、指向工作區外的父目錄 symlink 皆無法建構
- [ ] 檔名本身為 symlink 時無法建構
- [ ] 根為 `/work`、目標在 `/workspace` 下時無法建構
- [ ] 目標檔尚不存在、父目錄存在時可以建構
- [ ] 寫入函式的參數型別不接受 `String`

---

### FR-05: 寫入結果型別、三個可觀測時刻與 CLI 驗證狀態

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈補記：2026-11-10〉樂觀更新：1.0 不允許；PROP-005〈1.0 — 編輯〉整合測試與 `uc verify` 緩解 |
| 對應用例 | — |

**描述**：一次寫入有三個可觀測時刻，呼叫端可分別觀測：

| 時刻 | 定義 | 呼叫端可得 |
|---|---|---|
| 發出 | 閘門通過、寫入呼叫發出 | 寫入進行中 |
| 受理 | 寫入呼叫回傳 | `WriteResult` |
| 結果 | 寫入後驗證判定 | `ValidationStatus` |

`WriteResult` 為封閉型別：

| 值 | 意義 | 攜帶 |
|---|---|---|
| `written` | 位元組已落檔 | 快照 SHA（有快照時） |
| `blocked` | 閘門阻擋，檔案未動 | 原因：`externallyModified`／`snapshotFailed`／`rewriteNotIsolated` |
| `ioFailed` | 讀取、寫入或 `rename` 失敗，檔案未動 | IO 失敗分類（不含路徑以外的訊息） |

`ValidationStatus`：`running` → `passed`／`failed`（攜帶新增問題數）／`unavailable`（攜帶原因）。

**約束條件**：

- **不允許樂觀更新**：受理為 `written` 之後畫面才顯示新值（SPEC-004 §2 樂觀更新政策列）。
- 驗證狀態與寫入結果分開呈現。驗證失敗**不自動回滾**檔案；使用者依 FR-02 的取回說明還原。理由：驗證失敗代表索引不同步，是 PROP-005 §1.0 整合測試要讓它成為可見紅燈的對象，自動回滾會把它藏起來。
- 呼叫端據型別區分成功與失敗，不以日誌抵扣（PROP-007 驗收第 3 條）。
- **驗證範圍只限本次寫入的檔案**：`doc validate <id>` 與 `doc uc verify <path>`，不做全專案掃描（PROP-005〈1.0 — 編輯〉緩解）。
- **以 baseline 差集判定 `failed`**：開始編輯時，對目標檔跑一次兩個驗證器，記下的問題集合為 baseline。寫入後的問題集合減去 baseline，非空即為 `failed`，新增問題數為差集大小；baseline 已有的問題標為既有提示，不算驗證失敗。
  - 前提：FR-01 保證寫入前的磁碟內容等於 M，因此 baseline 對應的正是被改寫的那份內容。
  - 問題的比對鍵為驗證器回報的識別值（UC 編號等）加出現次數，不用行號或路徑：改寫會使行號位移。
  - 每次寫入成功後，該次寫入後的問題集合成為下一次寫入的 baseline；放棄並重讀時重跑 baseline。
  - baseline 為 `unavailable` 時，該次編輯期間所有寫入的驗證結果皆為 `unavailable`。
  - 理由：`uc verify` 分不出提及與使用（上游 tarrragon/claude#98），寫入檔本身的提及會讓每次寫入都報錯。上游修正後 baseline 不再含這類誤報，差集判定照樣成立，條文不需改。
- **CLI 結束碼對應**：0 為無問題；1 為有問題，解析輸出取得問題集合；2 為驗證器無法定位或解析目標文件。結束碼 2 同樣套用 baseline：baseline 不是 2、寫入後才出現 2，判為 `failed`；baseline 已是 2 時，寫入後的 2 屬既有問題，不判 `failed`。理由：寫入已通過 Corpus 的隔離檢查，驗證器卻變得無法解析，代表兩套解析不一致，正是要浮上來的索引不同步；而驗證器原本就無法解析的檔案，若每次寫入都判 `failed`，就與「baseline 已有的問題不算驗證失敗」矛盾。
- **`unavailable` 的情況**：`uv` 或 doc CLI 無法執行（含 shim 找不到 skill）、結束碼不在上述三值、或輸出無法解析。不得視為 `passed`（系統層 §4.4：系統內建 python3 執行 doc CLI 會 `TypeError`）。

**驗收標準**：

- [ ] 寫入的三個可觀測時刻與寫入結果型別可由呼叫端區分（PROP-007 驗收第 3 條）
- [ ] 寫入後驗證器回報新問題時為 `failed`，且檔案未被改回（PROP-005 §1.0 整合測試）
- [ ] 寫入檔在寫入前已含 UC 提及時，寫入後不因該提及判為 `failed`
- [ ] 改寫使問題所在行號位移時，不因行號改變判為新增問題
- [ ] baseline 結束碼為 2 時，寫入後結束碼仍為 2 不判 `failed`；baseline 結束碼非 2、寫入後為 2 時判 `failed`
- [ ] 驗證器無法執行、或 baseline 為 `unavailable` 時為 `unavailable`

---

### FR-06: 外部改動的發現時點

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 〈補記：2026-11-10〉前提變動（檔案監看已活躍，SPEC-006 FR-11）；系統層 §3.2 Edit 列 |
| 對應用例 | — |

**描述**：外部改動有兩個發現點，兩者並用：

| 發現點 | 作用 |
|---|---|
| 監看事件（SPEC-006 FR-11）指出正在編輯的檔案被改 | 預警：提前讓使用者知道，不必等到按下寫入 |
| 寫入前閘門（FR-01）的 W ≠ M | 保證：監看事件有延遲、也有漏事件的實例，寫入當下的比對不可省 |

**約束條件**：

- 監看預警由編輯狀態本身承載，不發暫態提示，不佔用使用者呈現焦點通道（系統層 §3.2 本 domain 判定「否」的前提）。畫面形式由 SPEC-001／003 的編輯狀態承接。
- 預警之後，使用者仍可嘗試寫入；寫入一律由 FR-01 判定。預警本身不阻擋寫入，也不自動捨棄使用者的未寫入值。
- 放棄並重讀時，以磁碟內容重新開始編輯，M 改為新讀入的內容，並重跑驗證 baseline（FR-05）。

**驗收標準**：

- [ ] 編輯中目標檔被外部改動、監看事件到達時，編輯狀態轉為外部已改預警
- [ ] 監看事件未到達時，寫入仍由 FR-01 判為 `externallyModified`

---

### FR-07: 只記識別與日誌事件

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | 〈2026-09-10〉C-1、C-2；SPEC-010 FR-02～FR-04 |
| 對應用例 | — |

**描述**：寫入路徑的錯誤型別、失敗訊息、變更記錄與日誌，只記檔案路徑、欄位名、寫入結果、失敗原因分類，不記欄位值與使用者內容。錯誤型別沒有可承載內容的欄位，約束位置在寫入層，不在全域攔截層（〈2026-09-10〉C-2）。

日誌事件 enum `EditLogEvent`（信封與白名單依 SPEC-010）。一次失敗只記一筆（SPEC-010 FR-02），`error_source` 依原因決定：

| 事件 | level | `error_source` | `fields` |
|---|---|---|---|
| `writeIssued` | info | — | 路徑、欄位名 |
| `writeAccepted` | info | — | 路徑、欄位名 |
| `snapshotTaken` | info | — | 路徑、`blob_sha` |
| `writeBlocked`（原因 `externallyModified`、`rewriteNotIsolated`） | warning | `gate_blocked` | 路徑、原因 |
| `writeBlocked`（原因 `snapshotFailed`） | error | `external_process` | 路徑、原因、`git` 結束碼或 `executableMissing` 二擇一 |
| `readIoFailed` | error | `platform_io` | 路徑、`osError.errorCode` |
| `writeIoFailed` | error | `platform_io` | 路徑、`osError.errorCode` |
| `validationCompleted` | `passed` 為 info；`failed`、`unavailable` 為 warning | `unavailable` 為 `external_process`；其餘無 | 路徑、節點 ID、狀態；`failed` 加新增問題數；`unavailable` 加 CLI 結束碼或原因 enum 二擇一 |

**約束條件**：

- `rewriteNotIsolated` 歸 `gate_blocked`：它是本 domain 的前置閘門依規則拒絕繼續，不是未預期例外。
- `failed` 不帶 `error_source`：驗證失敗是驗證器的判定結果，不是 App 的失敗。
- `osError` 為 null 時不帶 `osError.errorCode` 欄位。
- `blob_sha` 以 SPEC-010 FR-03 的 commit SHA 包裝型別記錄。該型別的名稱是 commit，實際記的是 blob；兩者同為 40 字元小寫十六進位，序列化結果相同。此名稱不符為已知限制，SPEC-010 新增物件 SHA 型別時改用。
- 不新增 App 自有的跨 session 內容副本（〈2026-09-10〉C-1）。射程限跨 session 存活的副本：編輯器內文字級 undo（`re_editor` 內建）與 session 內的單步復原不受限。

**驗收標準**：

- [ ] 每個帶 `error_source` 的事件在上表寫明分類（SPEC-010 FR-02 驗收）
- [ ] 以內含標記字串的欄位值寫入並使其失敗，日誌與錯誤型別中不出現該標記字串

---

### FR-08: 變更記錄

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 〈2026-09-10〉B 組；App 提交不進 1.0（用戶裁定） |
| 對應用例 | — |

**描述**：變更記錄依情境分兩個載體，兩者都只含識別（路徑、欄位名、節點 ID、快照 SHA），不含欄位值（〈2026-09-10〉C-2）：

| 情境 | 載體 |
|---|---|
| 正常流程中的即時確認 | session 內的可見回饋：本 session 寫過的檔案與欄位清單，每列附該次寫入的 `ValidationStatus`（FR-05）。理由：CLI 驗證非同步回來，使用者離開該檔後，要能在這份清單上看到失敗（`1.0.0-W3-187`，用戶裁定）。畫面形式由 SPEC-001／003 的編輯狀態承接 |
| 事後追溯（關掉 App、崩潰、隔天） | structured log：`writeAccepted` 記路徑與欄位名，`snapshotTaken` 記快照 SHA（FR-07） |

**約束條件**：

- App 不建立 commit。使用者在 App 外以自己的 git 工具提交；App 內提交在 1.1 候選池（`1.1.0-W3-675`）。
- 事後追溯的可取回期限有兩道上限：快照 blob 受 `gc.pruneExpire` 管轄（FR-02），structured log 受 SPEC-010 的保留政策管轄。兩者任一過期，該次寫入前的內容即無法由 App 留下的資訊取回。此為已知限制。

**驗收標準**：

- [ ] 寫入前後，`git log`、`git status --porcelain` 的 index 部分不變
- [ ] session 內可見回饋與 log 記錄不含欄位值
- [ ] 寫入清單每列帶該次寫入的驗證狀態，驗證結果在使用者離開該檔後回來時，清單上的狀態隨之更新
- [ ] 走快照分支的寫入，log 中可找到該次的快照 SHA

---

### FR-09: 逐欄位輸入元件對照

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | `1.0.0-W1-104` Solution（盤點與 WRAP）；PROP-007〈輸入元件依欄位功能決定〉 |
| 對應用例 | — |

**描述**：輸入元件依欄位的功能決定，不依當下的選項數；同一概念在不同型別用同一元件。

| 功能 | 元件 |
|---|---|
| 分類（互斥、值域小且固定、需並列比較） | 單選鈕組 |
| 等級（有序） | 下拉 |
| 生命週期（文件節點） | 下拉 |
| 生命週期（Ticket） | 動作按鈕（經 ticket CLI） |
| 單一引用 | 可搜尋下拉 |
| 多值引用（節點 ID） | chips 加搜尋加入 |
| 多值引用（domain） | 核取清單 |
| 自由文字 | 單行；段落為多行 |
| 內文 | `re_editor`（關閉語法高亮） |
| 字串清單 | 可增刪的字串清單 |
| 結構化區塊 | 表格列編輯 |

**值域來源**：下拉與單選的選項取自 `tracking_schema.json`。上游補上欄位值域之前，**沒有機器定義的列舉欄位以單行文字輸入**（用戶裁定；上游 tarrragon/claude#99）。理由：App 自帶值域表會成為上游 schema 的副本（CLAUDE.md §7 禁止）。

**讀表規則**：下列各表的「目標元件」為值域補上後的元件，「現行元件」為過渡期的實際元件。「自」欄為該欄位自哪個 minor 起可編輯；為空（—）表示任何 minor 都不提供直接編輯，理由寫在目標元件欄。

文件節點共通欄位：

| 欄位 | 目標元件 | 現行元件 | 值域來源 | 自 |
|---|---|---|---|---|
| id | 唯讀（改 id 屬檔案層級操作） | 唯讀 | — | 1.5 起經更名 |
| created | 唯讀 | 唯讀 | — | — |
| updated | 唯讀，寫入時若已存在則設為當天（FR-03） | 唯讀 | — | — |
| version（SPEC、UC） | 唯讀（FR-03） | 唯讀 | — | — |
| title | 單行 | 單行 | — | 1.0 |
| status（PROP） | 下拉 | 下拉 | doc CLI `VALID_STATUSES`（機器定義） | 1.0 |
| status（SPEC、UC、EVT） | 下拉 | 單行 | 只在範本註解，且 CLI 與範本矛盾 | 1.0 |
| 內文 | `re_editor` | — | — | 1.3 |

各型別特有欄位：

| 型別 | 欄位 | 目標元件 | 現行元件 | 自 |
|---|---|---|---|---|
| PROP | source | 下拉 | 單行 | 1.0 |
| PROP | priority | 下拉（等級） | 單行 | 1.0 |
| PROP | evaluation_level | 下拉 | 單行 | 1.0 |
| PROP | target_version | 可搜尋下拉（todolist 版本） | 可搜尋下拉 | 1.0 |
| PROP | proposed_by | 單行 | 單行 | 1.0 |
| PROP | proposed_date、confirmed_date | 唯讀（status 轉 confirmed 不連動填寫：一次寫入只改目標欄位，FR-03） | 唯讀 | — |
| PROP | outputs | 表格列編輯（三個清單各為 chips） | — | 1.4 |
| PROP | related_proposals | chips 加搜尋 | — | 1.1 |
| PROP | supersedes | 可搜尋下拉（可空） | — | 1.1 |
| SPEC | domain | 可搜尋下拉（已宣告 domain） | 可搜尋下拉 | 1.0 |
| SPEC | subdomain、owner | 單行 | 單行 | 1.0 |
| SPEC | has_functional_requirements | 單選鈕組（是／否） | 單選鈕組 | 1.0 |
| SPEC | source_proposal | 依邊的 forward_cardinality：one 為可搜尋下拉、many 為 chips | — | 1.1 |
| SPEC | related_usecases、related_specs、implements_requirements | chips 加搜尋 | — | 1.1 |
| SPEC | depends_on_domains | 核取清單 | — | 1.1 |
| UC | primary_actor | 單行 | 單行 | 1.0 |
| UC | secondary_actors | 字串清單 | — | 1.4 |
| UC | platform、extension_status、runtime_surface | 單選鈕組 | 單行 | 1.0 |
| UC | related_specs、related_usecases、ticket_refs | chips 加搜尋 | — | 1.1 |
| UC | flow 區塊 | 表格列編輯 | — | 1.4 |
| DomainBundle | domain | 唯讀（改名屬檔案層級操作） | 唯讀 | 1.5 起經更名 |
| DomainBundle | source_specs、related_usecases、depends_on_bundles | chips 加搜尋 | — | 1.1 |
| DomainBundle | path_patterns | 字串清單 | — | 1.4 |
| EVT | name、canonical_name | 單行 | 單行 | 1.0 |
| EVT | category | 單選鈕組 | 單選鈕組 | 1.0 |
| EVT | producers、consumers | 核取清單 | — | 1.1 |
| EVT | payload | 多行 | 多行 | 1.0 |

Ticket 欄位（1.2 起，經 ticket CLI；處於 ticket CLI 定義的終態時整張唯讀，要改須先以「還原」回到非終態）：

| 欄位 | 元件 | CLI |
|---|---|---|
| title、what、when、why | 單行／多行 | set-title、set-what、set-when、set-why |
| who | 可搜尋下拉 | set-who |
| priority | 下拉（等級） | set-priority |
| where.layer／where.files | 單行／字串清單 | set-where |
| how.task_type／how.strategy | 可搜尋下拉／多行 | set-how |
| acceptance | 勾選清單，可增刪改 | check-acceptance、set-acceptance |
| parent | 可搜尋下拉 | set-parent |
| blockedBy、relatedTo、children、spawned_tickets | chips 加搜尋 | set-blocked-by、set-related-to、add-child、add-spawned／remove-spawned |
| scope_blocker、decision_tree_path | 單行 | set-scope-blocker、set-decision-tree |
| status | 動作按鈕（認領、完成、關閉、釋放、還原） | claim、complete、close、release、restore |
| 內文章節 | 只能追加 | append-log |
| id、type、version、wave、source_ticket、discovered_during、created、started_at、completed_at | 唯讀 | 無 setter |

**約束條件**：

- 表單元件尚未在元件庫（SPEC-004）中，進 SPEC-004 前走 component-contract-design。借用 `SegmentedControl` 當表單單選會混入第二種語意，不採（`1.0.0-W1-104` WRAP 的 P）。
- 現行元件為單行的列舉欄位，寫入不合法值時，CLI 驗證也不一定攔得下（`doc validate` 不檢查 SPEC status 值）；此風險於過渡期接受（PROP-007〈失敗防護〉第 1 列）。

**驗收標準**：

- [ ] 1.0 可編輯的每個欄位（「自」為 1.0 者）都有對應的輸入元件與值域來源
- [ ] 值域無機器定義的列舉欄位以單行文字呈現，不以 App 內建值域表呈現

## 非功能需求

### NFR-01: 寫入延遲不阻擋操作

| 項目 | 值 |
|------|-----|
| 類型 | 效能 |
| 指標 | 寫入受理延遲（不含驗證）：1.0 實作時量測後填入本欄。驗證以獨立狀態呈現，不阻擋下一次編輯 |

**描述**：CLI 本身的延遲量級為 `doc validate` 0.35 秒、`doc uc verify` 0.52 秒（量測環境：作者本機 macOS，2026-11-10，經 cwd-resolving shim）。從 App 內經 `uv run` 呼叫多一層行程啟動，延遲於 1.0 實作時量測並記入本節（PROP-007〈已驗證 vs 未驗證〉）。

---

## 錯誤處理

下表把 FR-01～FR-05 的每種失敗對應到寫入結果與使用者提示；提示的畫面形式由 SPEC-001／003 的編輯狀態承接。

| 錯誤場景 | 寫入結果 | 處理方式 | 使用者提示 |
|---------|--------|---------|-----------|
| 非 git 工作區或 `git` 無法執行 | 無（不進編輯） | 工作區開啟時唯讀降級 | 常駐降級徽章 |
| 開始編輯時讀取失敗 | 無（不進編輯） | 不進入編輯 | 說明無法讀取檔案 |
| 外部已改 | `blocked(externallyModified)` | 不寫入；提供放棄並重讀 | 編輯狀態顯示外部已改 |
| 快照失敗 | `blocked(snapshotFailed)` | 不寫入 | 說明無法建立快照、檔案未改 |
| 改寫不隔離 | `blocked(rewriteNotIsolated)` | 不寫入 | 說明此檔的格式無法安全局部改寫，請以外部編輯器修改 |
| 讀取或寫入 IO 失敗 | `ioFailed` | 目標檔維持原內容，暫存檔已刪除 | 說明寫入失敗、檔案未改 |
| 驗證失敗 | `written`＋`failed` | 不回滾 | 驗證狀態顯示新增問題數與取回說明（FR-02） |
| 驗證器無法執行 | `written`＋`unavailable` | 不回滾 | 驗證狀態顯示無法驗證 |

## 設計約束

下表列出限制本規格解法空間的外部條件，以及各自落到哪一條需求。

| 約束 | 說明 | 影響 |
|------|------|------|
| App 直接改檔，CLI 只當驗證器 | 系統層 §4.4；ticket 是例外（1.2，經 ticket CLI） | 文件節點的寫入全部經本規格的路徑 |
| 沙盒關閉 | App Sandbox 關閉（PROP-001），OS 層對寫入範圍沒有邊界 | FR-04 是唯一的寫入範圍邊界 |
| 依賴 `git` 與 `uv` | 快照與 H 需要 `git`；驗證需要 `uv` | `git` 缺席時工作區開啟即唯讀降級（FR-01）；`uv` 缺席時驗證為 `unavailable`（FR-05）；皆不靜默放行 |
| Edit 依賴 Corpus，反向禁止 | edit domain-map §2 | 寫入後的重掃經監看事件，不直接呼叫 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-11-10 | 初始版本（1.0.0-W3-553.1） |
