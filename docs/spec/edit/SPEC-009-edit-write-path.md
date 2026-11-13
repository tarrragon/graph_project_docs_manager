---
id: SPEC-009
title: "編輯能力：寫入路徑、寫入前閘門與寫入結果"
status: draft
source_proposal: PROP-007
created: "2026-11-10"
updated: "2026-11-13"
version: "1.13"
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
- **M 的更新**：寫入受理為 `written` 之後，M 改為本次寫入落檔的位元組（步驟 6 `rename` 的暫存檔內容），下一次寫入以它為基準；寫法對齊 FR-05「每次寫入成功後，該次寫入後的問題集合成為下一次寫入的 baseline」。結果為 `blocked`（三種原因）或 `ioFailed` 時目標檔未動，M 不變。M 只在三個時點設定：開始編輯、`written` 受理、放棄並重讀（FR-06）。理由：同一次編輯可以連續寫入多個欄位；M 若停在開始編輯的內容，第一次寫入之後每次寫入都會在步驟 1 判 W ≠ M 而被擋。`blocked(externallyModified)` 之後 M 雖不變，但已與磁碟不符，之後的寫入都會被擋，要先放棄並重讀（FR-06）（`1.0.0-W3-683`）。
- 步驟 1 或步驟 5 讀不到檔案時：檔案已不存在視為 W ≠ M（外部已改，檔案被刪或改名）；其他讀取失敗（權限等）回傳 `ioFailed`。
- 比較用位元組內容本身，不用雜湊（〈2026-09-10〉A-2：單檔 KB 級、短生命週期比對）。
- H 以 `git -C <工作區根> show HEAD:./<工作區相對路徑>` 取得。`./` 前綴使路徑相對於 `-C` 指定的目錄解析，工作區可以是 repo 的子目錄。stdout 以位元組讀取，不經字元解碼。結束碼 0 為 H 存在；結束碼 128 且 stderr 指出路徑不在 HEAD 中，為 H 不存在；其他情況為 H 無法判定。後兩者都走快照分支。
- App 發出的 `git` 呼叫一律在環境中設 `LC_ALL=C`（比照 SPEC-008 FR-01 規則 1）。理由：上一條以 stderr 內容區分「H 不存在」與「H 無法判定」，而 `git` 的 stderr 會依 `LANG`／`LC_MESSAGES` 翻譯，不固定語系時判定結果會隨使用者的語系設定改變。
- **`git` 子行程逾時 5 秒**（用戶裁定 2026-11-11，`1.0.0-W3-676`）：本規格發出的 `git` 子行程（步驟 3 的 `git show`、FR-02 的 `hash-object`）各自計時，自子行程啟動起算，超過 5 秒即終止該子行程。逾時歸入既有結果，不新增 `WriteResult` 型別：`git show` 逾時視同 H 無法判定，走快照分支；`hash-object` 逾時歸 `blocked(snapshotFailed)`（FR-02）。
  - 理由：兩者都在步驟 4 之前，逾時時目標檔與暫存檔都還沒動，「`blocked` 時檔案未動」的保證不變。步驟 6 的 `rename` 一旦執行就無法撤回，逾時若落在其後，回報「檔案未動」就是錯的，因此不對整次寫入計時。
  - 5 秒的依據：兩個呼叫只讀 HEAD 或寫一個 blob，正常為毫秒級；與 SPEC-006 FR-11 規則 10 監看就緒逾時同值（同屬外部程序可能卡住）。誤判的代價是一次 `snapshotFailed`，使用者重送即可。
- **本地檔案 IO 不設逾時**：步驟 1、4、5、6 與開始編輯時的讀取為本地檔案操作，不設逾時。比照 SPEC-005 §2.5（`dart:io` 無取消介面）與 SPEC-003 §3.6（重新整理不存在逾時結果）。檔案系統卡住時寫入停在「發出」之後、沒有受理，此為已知限制。
- 步驟 5 的重比把外部寫入的時窗縮到步驟 5 與步驟 6 之間。該殘餘時窗內的外部寫入會被覆蓋，為已知限制：不採檔案鎖與 `xattr` 標記（〈2026-09-10〉A-2：對不參與協定的外部編輯器無強制力）。
- **唯讀降級不進本閘門**：由本 domain 在工作區開啟時判定（以工作區根探測 `git`）。可寫或唯讀是本 domain 的狀態，不放進 Workspace：Workspace 的變更理由是資料夾存取方式，放進去會讓它知道編輯的存在（2026-11-10 主控裁定）。工作區不是 git repo，或 `git` 無法執行時，整個工作區進入唯讀降級並常駐降級徽章，編輯控制項不可用。理由：快照與 H 都需要 `git`，缺席時每次寫入都只會落入 `snapshotFailed`；在開啟時降級，與 A-1「依賴缺席 → 降級並常駐徽章」的先例一致（〈2026-09-10〉A-1 末段；`git` 缺席部分為 2026-11-10 主控裁定）。本 domain 不在每次寫入時重判；編輯期間 `git` 變為不可用時，由步驟 3 回傳 `snapshotFailed`，不靜默放行。

**驗收標準**：

- [ ] 三種判定（外部已改、需快照、直接寫入）各有 fixture repo 驗證（PROP-007 驗收第 2 條）
- [ ] 同一次編輯連續兩次寫入（不同欄位），第二次不因 W ≠ M 被擋；第一次結果為 `blocked` 或 `ioFailed` 時，M 仍為開始編輯時的內容
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
- `hash-object` 呼叫同樣設 `LC_ALL=C`（FR-01 約束）。
- 快照是 session 內的復原手段，不是備份：blob 為 unreachable object，受 `gc.pruneExpire` 管轄（預設兩週）。規格、文案與日誌不得使用「備份」一詞而不寫明期限。
- 快照 SHA 寫進 structured log（FR-07 `snapshotTaken`），供事後追溯（FR-08）。
- 快照發生時必須有可見回饋，並附取回說明。畫面形式由 SPEC-001／003 的編輯狀態承接。1.0 不提供 App 內的還原動作；取回由使用者依說明執行。
- 取回說明依本次寫入是否走快照分兩種：

| 情況 | 取回說明 |
|---|---|
| 有快照（W ≠ H） | `git cat-file -p <sha> > <路徑>` |
| 無快照（W = H） | `git checkout HEAD -- <路徑>` |

- 快照失敗（權限、repo 損壞、`git` 無法執行、`hash-object` 逾時）一律退回阻擋，不得靜默放行。逾時值與終止方式見 FR-01〈`git` 子行程逾時 5 秒〉。

**驗收標準**：

- [ ] 快照前後 `git status --porcelain`、`git stash list`、`git reflog` 輸出不變
- [ ] 寫入結果攜帶快照 SHA，且以 `git cat-file -p <sha>` 取回的內容逐位元組等於 W
- [ ] fixture repo 設有換行轉換的 `.gitattributes` 時，取回內容仍逐位元組等於 W
- [ ] `git` 無法執行時回傳 `snapshotFailed`
- [ ] `hash-object` 超過 5 秒（以注入模擬）時，子行程被終止、回傳 `snapshotFailed`，目標檔內容不變且無暫存檔
- [ ] `git show` 超過 5 秒（以注入模擬）時，子行程被終止、走快照分支

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
- **非 UTF-8 內容**（執行期澄清，用戶裁定 2026-11-12，`1.0.0-W3-553.10`）：檔案內容不是合法 UTF-8 時，一律回傳 `blocked(rewriteNotIsolated)`，不寫入。
  - 理由：解析層使用的 Corpus 公開解析函式以嚴格 UTF-8 解碼整個檔案。內容含非法位元組時，改寫前就沒有可用的解析結果，隔離無從證明。
  - 這個判定發生在閘門第 2 步（FR-01 表），目標檔不變。第 1 步的 W 與 M 比較仍逐位元組進行，不經字元解碼。
- **改寫隔離檢查**有兩道，都通過才寫入：
  1. 解析層：以 Corpus 的公開解析函式（位元組 → 解析結果，見 `docs/spec/corpus/domain-map.md` §3）分別解析改寫前與改寫後的位元組。改寫後須為可用結果，且與改寫前相比只有允許變更集合內的鍵的值改變。
  2. 位元組層：改寫前後，允許變更集合的值所在範圍以外的位元組逐位元組相同。
  理由：局部改寫的欄位定位等於一個小型的第二套解析；兩道檢查把它與 Corpus 的分歧擋在寫入前，不讓它寫壞檔案。
- **暫存檔**：放在目標檔同目錄，確保 `rename` 不跨檔案系統。檔名以 `.` 開頭、帶行程 ID 與隨機尾碼、不以 `.md` 結尾，使檔案監看與 Corpus 掃描不把它當文件。寫入後 fsync 再 `rename`；權限位元沿用原檔。任何一步失敗時刪除暫存檔。
- **清空**（用戶裁定 2026-11-11，`1.0.0-W3-686`）：把欄位清空，就是把值的位元組範圍改寫為 `null`。不寫空字串，也不移除鍵。可清空的欄位見 FR-09〈可否清空〉。
  - 理由：`tracking_schema` 完整性語意中，「鍵存在、值為 `null`」代表明確沒有值。既有 PROP 語料就是這樣寫 `target_version: null` 的。
  - 空字串是一個值，在可搜尋下拉與下拉中會落入 outOfDomain（SPEC-004 4.45、4.46）。
  - 隔離檢查的判定：
    - 寫 `null`：解析層只有目標鍵的值改變，位元組層只有值範圍改變，兩道都通過。
    - 移除鍵：解析結果少一個鍵，違反允許變更集合（理由同「`updated` 缺席時不新增」），回傳 `blocked(rewriteNotIsolated)`。
  - 驗證器不區分 `null`、空字串與缺鍵：`1.0.0-W3-686` 以 fixture 實測，`doc validate` 與 `doc uc verify` 對三者回傳相同結束碼。所以清空的合法性由本條與 FR-09 決定，不交給驗證器。
- **1.0 一次寫入只寫一個檔**，不存在批次中途失敗。1.1 起，改寫有反向欄位的邊時，一次寫入會寫多個檔，規則見下方〈多檔寫入（1.1）〉。

#### 多值欄位的加入與移除（1.1）

`1.1.0-W1-111`（v1.10）。F1–F4 四項格式選擇由用戶裁定（2026-11-13，經主控 AUQ），紀錄見本節末〈裁定紀錄〉。

**適用範圍**：FR-09 中元件為 chips 或核取清單、「自」為 1.1 的欄位（SPEC-004 4.52 `ReferenceChips`、4.53 `AppCheckboxGroup`）。provenance 的正向欄位（SPEC、UC、EVT 的 `source_proposal`，v1.11）也適用本節，其反向檔另依〈多檔寫入（1.1）〉。

**操作單位**：一次寫入只做一個操作——加入一個值，或移除一個值。改成另一個值是兩次寫入（先移除、再加入，或反過來），各自經過閘門、各自成列（FR-08）。理由：畫面上的操作就是這兩種（SPEC-004 4.52、4.53），一次寫入對應一次操作，寫入清單的列與使用者的動作一一對應；多檔寫入的寫入集合也因此最多兩個檔（正向檔與一個反向檔）。

**語料現況**（2026-11-13 查證，`docs/` 下各型別 frontmatter）：多值欄位皆寫成 flow 序列（`[a, b]`）或空序列（`[]`），沒有 block 序列；`source_proposal` 有純量、flow 序列與 `null` 三種寫法。`tracking_schema` 的 `forward_cardinality` 註記：many 的欄位寫成純量時，消費端視為只有一項的清單。

**值的改寫規則**：只改寫目標欄位值的位元組範圍，隔離檢查照〈約束條件〉兩道。

| 改寫前的值 | 加入 v | 移除 v |
|---|---|---|
| flow 序列 `[a, b]` | `[a, b, v]`：附加於末尾，項間分隔沿用 `, ` | 刪除 v 及其分隔；結果見下方「剩一項」「剩零項」兩列 |
| 空序列 `[]` | `[v]` | 不會發生（畫面上沒有可移除的項） |
| 純量 `a`（只有 `source_proposal`） | `[a, v]`：純量轉 flow 序列 | `a` 等於 v 時：結果見「剩零項」；`a` 不等於 v：不會發生（畫面只列現有的值） |
| `null`（只有 `source_proposal`） | 純量 `v`（F1） | 不會發生 |
| 移除後剩一項（`source_proposal`） | — | 純量 `a`（F2） |
| 移除後剩一項（其他欄位） | — | `[a]` |
| 移除後剩零項（`source_proposal`） | — | `null`（F3，同〈清空〉） |
| 移除後剩零項（其他欄位） | — | `[]` |
| block 序列、anchor、alias、跨多行的 flow 序列（含其中的註解）、項為非純量 | 不改寫，回傳 `blocked(rewriteNotIsolated)` | 同左 |

- **加入的值已在清單中**：判定點在呼叫端，發出寫入之前。呼叫端不發出寫入，畫面的選項已排除已選的值（SPEC-004 4.52）。因為沒有發出，所以沒有 `WriteResult`、不成列（FR-08 驗收中「呼叫端未發出的寫入」的對照），也不記 FR-07 事件；處理方式與必填欄位送出空白相同（FR-09〈可否清空〉）。對寫入層而言，「加入的值不在清單中」是前置條件：呼叫端保證成立，寫入層在 debug 期以 assert 檢查，不為違反前置條件的情形新增 `WriteResult`。
- **正向檔的重複值**（F4）：移除 v 時刪除 v 的全部出現。理由同〈多檔寫入（1.1）〉〈寫入集合〉的 Q1：只刪一筆時剩下的那筆仍讓邊存在，畫面上卻少了一個 chip，使用者以為已移除。
- **flow 序列的項**：以純量寫入，不加引號；值含 YAML 需要引號的字元時（`,`、`[`、`]`、`:`、`#` 與前後空白），回傳 `blocked(rewriteNotIsolated)`。節點 ID 受 `id_pattern` 約束，domain 名受 domain 名稱權威寫法約束，兩者都不含這些字元。

**裁定紀錄**（用戶裁定 2026-11-13，經主控 AUQ；F1–F3 以單一問題裁定為「跟現有資料一致」）：

| 項 | 裁定 | 未採用的選項 | 理由 |
|---|---|---|---|
| F1 `source_proposal` 由 `null` 加入 | 純量 `v` | `[v]` | 語料中單一來源皆寫純量；`tracking_schema` 視純量為單項清單，兩者語意相同，取改動最少者 |
| F2 `source_proposal` 移除後剩一項 | 純量 `a` | `[a]` | 同 F1：單值純量、多值清單，與語料一致 |
| F3 `source_proposal` 移除後剩零項 | `null` | `[]` | 同〈清空〉：鍵存在、值為 `null` 代表明確沒有值；語料中無來源的 SPEC 寫 `null` |
| F4 正向檔重複值的移除 | 刪除全部出現 | 只刪一筆 | 見上方〈正向檔的重複值〉 |

#### 多檔寫入（1.1）

用戶裁定 2026-11-12（`1.1.0-W1-111`，選項 A）。

**適用範圍**：文件節點的邊中，只有 provenance 有反向欄位：正向欄位是 `source_proposal`，反向欄位是 PROP 的 `outputs`（型別表 `forward_field`／`reverse_field`）。`outputs` 是 map，每個子鍵的清單項都是反向引用值（SPEC-007 FR-03，子鍵不列舉）。blood、spawn 也有反向欄位，但兩者都是 ticket 欄位，屬於 1.2，經 ticket CLI 寫入，不走本節。其餘 1.1 邊欄位沒有反向欄位，照單檔寫入處理。

**反向清單鍵**（v1.11）：寫入時改寫 `outputs` 的哪一個子鍵，依正向檔的型別決定：

| 正向檔型別 | 反向清單鍵 | 寫入方式 |
|---|---|---|
| SPEC | `outputs.spec_refs` | 多檔寫入（v1.6） |
| UC | `outputs.usecase_refs` | 多檔寫入（v1.11，用戶裁定 2026-11-13，經主控 AUQ） |
| EVT | `outputs.event_refs` | 多檔寫入（v1.11，用戶裁定 2026-11-13，經主控 AUQ；前提更正後重問的裁定） |

型別表沒有列舉 `outputs` 的子鍵，本表是依語料慣例寫的寫入對照，不是型別表資料（主控判定不構成 CLAUDE.md §7 的 schema 副本，2026-11-13）。本表只決定加入時寫進哪一個子鍵；邊是否存在仍由 SPEC-007 依全部子鍵判定，所以移除時不限本表的子鍵，見下方〈寫入集合〉。加入時反向檔沒有對應子鍵，不新增鍵，見下方〈反向檔的允許變更集合〉。

**寫入集合**：對正向檔的 `source_proposal` 加入或移除一個 PROP 的一次寫入（操作單位見〈多值欄位的加入與移除（1.1）〉，v1.10），寫入集合包含：

- 正向檔本身，值依〈多值欄位的加入與移除（1.1）〉改寫。
- 被加入或被移除的那一個 PROP（反向檔）：
  - 移除時，從 `outputs` 每一個值為清單的子鍵刪除正向檔 id 的全部出現，不限〈反向清單鍵〉表的子鍵（v1.11）。理由：依 SPEC-007 FR-03 與 D6，任何子鍵的清單項都會建出反向邊（例：`design_refs`）；只刪一個子鍵時，邊仍由其他子鍵保留，正反向不一致殘留，與 Q1 同理。值不是清單的子鍵不建邊（SPEC-007 歸 `malformedRef`），不改寫。
  - 加入時，只把正向檔 id 附加到〈反向清單鍵〉表該型別的子鍵末尾。
  - 以上兩條以 `outputs` 是 map 為前提；`outputs` 不是 map 時，見下方〈`outputs` 本身不是 map〉。

一次寫入仍只動一個 PROP，所以寫入集合最多兩個檔；移除時改寫多個子鍵，都在同一個反向檔內。

**反向檔子鍵值的形狀**（v1.11）：「含該 id」與改寫都依子鍵值的形狀判定，與 SPEC-007 FR-03 是否建邊一致。

**判定順序**：
1. 先依〈寫入集合〉判定這份 PROP 列不列入。「含該 id」依 `outputs` 的形狀查表：`outputs` 是 map 時依下表第二欄逐子鍵判定；不是 map 時依下方〈`outputs` 本身不是 map〉表的第二欄。
2. PROP 已列入時，才依 `outputs` 的形狀查表改寫：是 map 時依下表的「移除時」「加入時」欄；不是 map 時依〈`outputs` 本身不是 map〉表的同名欄。

例：加入時目標子鍵是 block 序列且已含該 id，依第 1 步不列入，只寫正向檔，不會走到「加入時」欄的擋下。

| 子鍵值 | 算不算「含該 id」 | 移除時（PROP 已列入） | 加入時（PROP 已列入；該子鍵是〈反向清單鍵〉表的子鍵） |
|---|---|---|---|
| flow 序列、空序列（不屬下一列） | 清單項等於該 id 即算 | 依〈多值欄位的加入與移除（1.1）〉「其他欄位」列改寫（剩零項得 `[]`） | 附加於末尾 |
| 值改寫規則表「不改寫」列的形狀（〈多值欄位的加入與移除（1.1）〉，含 block 序列、anchor、alias、跨多行的 flow 序列、項為非純量） | 解析結果中有清單項等於該 id 即算 | 含該 id 的子鍵屬此列時，整批回傳 `blocked(rewriteNotIsolated)` | 整批回傳 `blocked(rewriteNotIsolated)` |
| `null` | 不算：沒有項 | 不改 | 整批回傳 `blocked(rewriteNotIsolated)` |
| 純量（含等於該 id 的字串） | 不算：SPEC-007 把非清單子鍵歸 `malformedRef`，不建邊 | 不改 | 整批回傳 `blocked(rewriteNotIsolated)` |

加入時目標子鍵的值是 `null` 或純量時不改寫。理由：F1–F3 的純量與 `null` 寫法只裁定了正向欄位 `source_proposal`，反向清單的寫法沒有裁定，所以不自行把它轉成清單。

**`outputs` 本身不是 map**（語料目前沒有這種寫法，2026-11-13 查證）。依 SPEC-007 FR-03〈抽取〉判定建不建邊：

| `outputs` 的值 | 算不算「含該 id」 | 移除時（PROP 已列入） | 加入時（PROP 已列入） |
|---|---|---|---|
| 清單（例 `[SPEC-1]`） | 清單項等於該 id 即算：每一項都是反向引用值，會建邊 | 整批回傳 `blocked(rewriteNotIsolated)`：本規格只改寫 map 的子鍵，不改寫 `outputs` 本身 | 整批回傳 `blocked(rewriteNotIsolated)`：沒有子鍵可寫 |
| 純量字串 | 等於該 id 即算：純量欄位是一個引用值 | 同上 | 同上 |
| `null`、缺鍵 | 不算 | 不列入（〈寫入集合〉移出端不含） | 整批回傳 `blocked(rewriteNotIsolated)`：不新增鍵 |
| 數字、布林 | 不算：SPEC-007 歸形狀不合法，不建邊 | 不列入 | 整批回傳 `blocked(rewriteNotIsolated)`：沒有子鍵可寫 |

**已知後果**：PROP-001、PROP-006、PROP-007 沒有 `outputs.event_refs`（2026-11-13 查證）。對 EVT 加入這三份 PROP 時，整批回傳 `blocked(rewriteNotIsolated)`，使用者需先以外部編輯器在該 PROP 補上 `event_refs: []`。UC、SPEC 對缺 `usecase_refs`、`spec_refs` 的 PROP 同理。

以下例子以 SPEC 為正向檔，UC、EVT 相同，只把加入時的子鍵換成 `usecase_refs`、`event_refs`。例如：加入 PROP-B，寫入集合是 SPEC、PROP-B 兩個檔；移除 PROP-A，寫入集合是 SPEC、PROP-A 兩個檔。把 PROP-A 改成 PROP-B 是兩次寫入，各自兩個檔（v1.9 以前把它寫成一次三個檔的寫入，v1.10 改為兩次，理由是畫面上沒有「取代」這個操作，SPEC-004 4.52）。反向檔的清單如果本來就和改寫後的正向值一致，該檔不列入寫入集合，寫入集合只剩正向檔，照單檔寫入處理：加入端的 `outputs` 已含該 SPEC id，或移出端的 `outputs` 不含該 SPEC id（不論出現幾次、在哪個子鍵，v1.11）。「含」依下方〈反向檔子鍵值的形狀〉與〈`outputs` 本身不是 map〉兩張表的「算不算含該 id」欄判定，不只看子鍵：例如 `outputs: [<該 SPEC>]` 沒有子鍵，但算含。移出端含該 id 時一律移除全部出現，理由是只移除一筆時，剩下的那筆仍指向已不再指向它的 SPEC，正反向不一致會殘留下來（Q1，PM 依規格內部一致性定案，`1.1.0-W1-111`）。反向檔的 id 在 Corpus 的原始節點中查不到對應檔案時，依方向處理：移出端查不到就略過，因為沒有反向清單可改，這正是修正 `danglingRef` 的情況；加入端查不到則整批回傳 `blocked(rewriteNotIsolated)`，因為新的正向值會成為斷邊。

**反向檔的允許變更集合**：`updated`（規則同上方〈允許變更集合〉），加上該次改寫的 `outputs` 子鍵——加入時是〈反向清單鍵〉表的那一個子鍵，移除時是含正向檔 id 的每一個子鍵（v1.11）。

- 只改寫各清單的值範圍。加入時 `outputs` 或該反向清單鍵不存在，不新增鍵，整批回傳 `blocked(rewriteNotIsolated)`，理由同「`updated` 缺席時不新增」。移除時只改寫含該 id 的子鍵，不會遇到缺鍵。
- 要改寫的子鍵值落在〈多值欄位的加入與移除（1.1）〉值改寫規則表的不改寫列（block 序列、跨多行等）時，整批回傳 `blocked(rewriteNotIsolated)`。
- 兩道改寫隔離檢查對反向檔同樣適用；位元組層比對的範圍是全部被改寫子鍵的值範圍與 `updated`。
- 除了上述移除，`outputs` 其餘子鍵（如 `ticket_refs`）的改寫，以及 `outputs` 的表格列編輯，仍自 1.4 起開放（FR-09）。

**反向檔的 M**：使用者只對正向檔開始編輯，反向檔沒有「開始編輯」時點。反向檔的 M 取送出當下、步驟 1 讀到的內容。

- 後果：反向檔的外部改動只由步驟 5 的重比把關，涵蓋步驟 1 到步驟 5 之間的改動；送出之前的外部改動會被當成基準。
- 這和直接用外部編輯器改該檔的效果相同（以磁碟現況為準），不會覆蓋使用者看不到的改動。

**閘門整批判定**：寫入集合中每個檔依序跑 FR-01 步驟 1～4（讀 W、改寫並隔離檢查、快照、寫暫存檔並 fsync）。任一檔在任一步不通過，整批停止，刪除所有已寫的暫存檔，所有目標檔不變，回傳該檔的結果（`blocked` 或 `ioFailed`，帶路徑）。

- 理由：步驟 1～4 都不動目標檔。全部通過才進入 `rename`，能把「只成功一部分」的時窗縮到 `rename` 階段。
- 快照逐檔各自判定（W ≠ H 的檔才快照），各檔的快照 SHA 分別攜帶。

**`rename` 順序**：先反向檔（依路徑字串排序），最後正向檔。每個檔在 `rename` 前各自跑步驟 5 的重比。

- 理由：正向檔是使用者在畫面上編輯的對象。它放在最後，正向檔落檔就代表整批完成；中途失敗時，畫面上的值維持原狀，與使用者看到的「沒寫成」一致。

**中途失敗的回復**：第 k 個檔在步驟 5 或步驟 6 失敗時（k ≥ 2，前 k−1 個檔已 `rename`）：

1. 刪除其餘暫存檔。
2. 依相反順序，把已 `rename` 的檔還原為各自步驟 1 讀到的 W 位元組。還原走同一套暫存檔加 `rename`，但不跑閘門：還原的內容就是這次寫入前的內容，不需要再做改寫隔離檢查。
3. 全部還原成功：回傳第 k 個檔的原結果（`blocked(externallyModified)` 或 `ioFailed`）。所有目標檔等同未動。
4. 任一檔還原失敗：回傳 `partiallyWritten`（FR-05），攜帶已落檔且未還原的檔案清單與各檔的取回說明（FR-02 的兩種指令，依該檔是否有快照）。

已知限制：還原時不重比磁碟內容，`rename` 之後到還原之前若有外部寫入，會被還原覆蓋。這個時窗與步驟 5～6 的殘餘時窗同量級。

**寫入後驗證**：FR-05 的驗證範圍與 baseline 只套用正向檔。反向檔不跑 baseline，也不跑寫入後驗證。

- 理由：baseline 必須在寫入前對該檔跑完，對反向檔跑 baseline 等於讓每次邊寫入都多等一輪 CLI（每個檔最長 30 秒）。
- 反向檔的改寫由兩道隔離檢查把關，只動〈反向檔的允許變更集合〉內的子鍵值與 `updated`：加入時是一個子鍵，移除時是含該 id 的每一個子鍵（v1.11）。
- 正反向一致由整批判定與回復保證，不靠驗證器：`doc validate` 不檢查 provenance 的反向一致性（`.claude/skills/doc/doc_system/commands/validate.py` 不讀 `outputs`、`source_proposal`，2026-11-12 查證）。整批寫入只會有三種結局：全部落檔、全部未動、`partiallyWritten`。前兩種正反向一致，第三種以結果型別呈現，所以不一致不會只寫進日誌。

**M 的更新**：受理為 `written` 時，正向檔的 M 依 FR-01 更新。反向檔不在編輯中，沒有 M 可更新。

**驗收標準**：

- [ ] 寫入中途中斷（以注入失敗模擬）後，目標檔內容等於寫入前，同目錄不殘留暫存檔
- [ ] 改寫一個欄位後，檔案除該值與 `updated` 外逐位元組相同
- [ ] `updated` 缺席的檔案，改寫後仍無 `updated`
- [ ] 目標欄位值為 anchor、alias 或 block scalar 時，回傳 `rewriteNotIsolated` 且目標檔不變
- [ ] 以 fixture 構造改寫後解析結果多變一個欄位的情境，回傳 `rewriteNotIsolated` 且目標檔不變
- [ ] 寫入後目標檔的權限位元與寫入前相同
- [ ] 清空 PROP target_version 後，該鍵仍存在且值為 `null`；檔案除該值與 `updated` 外逐位元組相同
- [ ] 內文含非法 UTF-8 位元組的檔案，修正任一欄位時回傳 `rewriteNotIsolated` 且目標檔不變（v1.5）
- [ ] 多檔寫入（v1.10）：對 SPEC `source_proposal` 移除 PROP-A 後，PROP-A 的 `outputs.spec_refs` 不含該 SPEC；再加入 PROP-B 後，PROP-B 的含該 SPEC。每次寫入的兩個檔除各自允許變更集合外逐位元組相同
- [ ] 多值欄位（v1.10）：flow 序列加入附加於末尾、移除只刪該項與其分隔；`[]` 加入得 `[v]`；其他欄位移除到零項得 `[]`；檔案除該值與 `updated` 外逐位元組相同
- [ ] 多值欄位（v1.10）：`source_proposal` 為純量 `a` 時加入 v 得 `[a, v]`
- [ ] 多值欄位（v1.10，F1）：`source_proposal` 為 `null` 時加入 v 得純量 `v`
- [ ] 多值欄位（v1.10，F2）：`source_proposal` 為 `[a, v]` 時移除 v 得純量 `a`
- [ ] 多值欄位（v1.10，F3）：`source_proposal` 為純量 v 時移除 v 得 `null`，鍵仍存在
- [ ] 多值欄位（v1.10，F4）：正向檔 `[a, v, v]` 移除 v 得純量 `a`（`source_proposal`）；其他欄位 `[a, v, v]` 移除 v 得 `[a]`
- [ ] 多值欄位（v1.10）：值為 block 序列或跨多行的 flow 序列時，回傳 `rewriteNotIsolated`，目標檔不變
- [ ] 多值欄位（v1.10）：加入已在清單中的值時，呼叫端不發出寫入：不改檔案、不成列、不記 FR-07 事件；寫入層直接收到時，debug 期 assert 失敗（v1.13）
- [ ] 多檔寫入（v1.6；v1.11 限加入）：加入時反向檔缺 `outputs.spec_refs` 鍵，整批回傳 `rewriteNotIsolated`，所有檔不變
- [ ] 多檔寫入（v1.6）：任一檔在步驟 1～4 不通過時，所有目標檔不變，同目錄不殘留暫存檔
- [ ] 多檔寫入（v1.6）：第 2 個檔 `rename` 失敗（以注入模擬）且還原成功時，回傳原失敗結果，已 `rename` 的檔還原為寫入前的位元組
- [ ] 多檔寫入（v1.6）：還原也失敗（以注入模擬）時，回傳 `partiallyWritten`，攜帶未還原的路徑清單與各檔的取回說明
- [ ] 多檔寫入（v1.6）：`rename` 順序為反向檔在前、正向檔最後
- [ ] 多檔寫入（v1.6；v1.11 依 v1.10 操作單位改寫）：修正 `danglingRef` 的 `source_proposal`（舊值指向不存在的 PROP）分兩次寫入。先移除舊值：移出端查不到，只寫 SPEC 一個檔。再加入新 PROP：寫 SPEC 與新 PROP 兩個檔
- [ ] 多檔寫入（v1.6）：新值指向不存在的 PROP 時，整批回傳 `rewriteNotIsolated`，所有檔不變
- [ ] 多檔寫入（v1.11）：對 UC `source_proposal` 加入 PROP-B 後，PROP-B 的 `outputs.usecase_refs` 含該 UC，`outputs.spec_refs` 與其他子鍵逐位元組不變；移除 PROP-A 後，PROP-A 的 `outputs.usecase_refs` 不含該 UC
- [ ] 多檔寫入（v1.11）：UC 加入時反向檔缺 `outputs.usecase_refs` 鍵，整批回傳 `rewriteNotIsolated`，所有檔不變（E2 對照：同一 PROP 有 `spec_refs` 不影響判定）
- [ ] 多檔寫入（v1.11）：EVT `source_proposal` 加入 PROP-B 後，PROP-B 的 `outputs.event_refs` 含該 EVT；PROP-B 缺 `event_refs` 鍵時整批回傳 `rewriteNotIsolated`
- [ ] 多檔寫入（v1.11）：移除 PROP-A 時，PROP-A 的 `outputs.spec_refs` 與 `outputs.design_refs` 都列出該 SPEC，寫入後兩個子鍵都不含該 SPEC；寫入集合仍為 SPEC、PROP-A 兩個檔；重建圖後 SPEC→PROP-A 邊不存在（E2 對照：只刪 `spec_refs` 時邊仍存在）
- [ ] 多檔寫入（v1.11）：加入 PROP-B 時，PROP-B 的 `outputs.design_refs` 已列出該 SPEC，PROP-B 不列入寫入集合，只寫 SPEC 一個檔，`spec_refs` 不變
- [ ] 子鍵形狀（v1.11）：加入 PROP-B 時，PROP-B 的 `outputs.spec_refs` 為 `null`，整批回傳 `rewriteNotIsolated`；為純量 `SPEC-X`（不等於該 SPEC）時同樣回傳 `rewriteNotIsolated`。所有檔不變（E2 對照：`spec_refs: []` 時加入成功，得 `[<該 SPEC>]`）
- [ ] 子鍵形狀（v1.11）：PROP-A 的 `outputs.spec_refs` 為純量、且等於該 SPEC id，其他子鍵不含該 id。移除 PROP-A 時，PROP-A 不列入寫入集合，只寫 SPEC；加入 PROP-A 時，因目標子鍵是純量，整批回傳 `rewriteNotIsolated`（E2 對照：`spec_refs: [<該 SPEC>]` 時，移除會列入並改寫為 `[]`）
- [ ] 子鍵形狀（v1.11）：移除 PROP-A 時，含該 id 的子鍵是 block 序列，整批回傳 `rewriteNotIsolated`，所有檔不變（E2 對照：同一內容改寫為 flow 序列時移除成功）
- [ ] 子鍵形狀（v1.11）：加入 PROP-B 時，目標子鍵是 block 序列且不含該 SPEC，PROP-B 列入，整批回傳 `rewriteNotIsolated`，所有檔不變（E2 對照：已含該 SPEC 時不列入，只寫 SPEC，見下一條）
- [ ] 子鍵形狀（v1.11）：加入 PROP-B 時，目標子鍵是 block 序列且已含該 SPEC，PROP-B 不列入，只寫 SPEC（判定順序：先〈寫入集合〉、後形狀表）
- [ ] `outputs` 非 map（v1.11）：PROP-A 的 `outputs` 為清單 `[<該 SPEC>]` 時，移除 PROP-A 回傳 `rewriteNotIsolated`；`outputs: null` 時，移除只寫 SPEC，加入回傳 `rewriteNotIsolated`
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
| `partiallyWritten`（1.1） | 多檔寫入中途失敗，且有檔案還原失敗（FR-03〈多檔寫入（1.1）〉），寫入集合中有些檔已落檔、有些未動 | 已落檔且未還原的路徑清單，各附取回說明（FR-02）；觸發失敗的檔案路徑與原因 |

多檔寫入時，`written` 攜帶寫入集合中每個檔的路徑與快照 SHA（有快照的檔）；`blocked` 與 `ioFailed` 攜帶觸發停止的檔案路徑，且寫入集合中所有檔都未動。

`ValidationStatus`：`running` → `passed`／`failed`（攜帶新增問題數）／`unavailable`（攜帶原因：`executableMissing`、`unexpectedExitCode`、`unparsableOutput`、`timedOut`、`baselineNotReady`）。

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
  - **baseline 與寫入的先後**（執行期澄清，用戶裁定 2026-11-12，經主控 AUQ（`1.0.0-W3-553.11.1`））：
    - 寫入的 rename 之前 baseline 量測尚未完成時，丟棄這份 baseline；之後才完成的量測結果不採用。該次寫入的驗證結果為 `unavailable(baselineNotReady)`。
    - 該次寫入後取得的問題集合，成為下一次寫入的 baseline。
    - 寫入後的驗證為 `unavailable` 時，保留原 baseline，不以該次寫入取代。
    - baseline 因前一點被丟棄、且尚未取得任何寫入後問題集合時（例如該次寫入的驗證也是 `unavailable`），寫入的驗證為 `unavailable(baselineNotReady)`；第一個取得的寫入後問題集合，成為下一次寫入的 baseline。baseline 量測完成但結果為 `unavailable` 時，依上一條「baseline 為 `unavailable`」處理，不適用本點。
    - 理由：寫入後才完成的 baseline 量到的是已改寫的內容，差集會漏掉新問題而誤報 `passed`。丟棄它不阻擋輸入（NFR-01），也不誤報。
  - 理由：`uc verify` 分不出提及與使用（上游 tarrragon/claude#98），寫入檔本身的提及會讓每次寫入都報錯。上游修正後 baseline 不再含這類誤報，差集判定照樣成立，條文不需改。
- **CLI 結束碼對應**：0 為無問題；1 為有問題，解析輸出取得問題集合；2 為驗證器無法定位或解析目標文件。結束碼 2 同樣套用 baseline：baseline 不是 2、寫入後才出現 2，判為 `failed`；baseline 已是 2 時，寫入後的 2 屬既有問題，不判 `failed`。理由：寫入已通過 Corpus 的隔離檢查，驗證器卻變得無法解析，代表兩套解析不一致，正是要浮上來的索引不同步；而驗證器原本就無法解析的檔案，若每次寫入都判 `failed`，就與「baseline 已有的問題不算驗證失敗」矛盾。
- **`unavailable` 的情況**：`uv` 或 doc CLI 無法執行（含 shim 找不到 skill，原因 `executableMissing`）、結束碼不在上述三值（`unexpectedExitCode`）、輸出無法解析（`unparsableOutput`）、驗證子行程逾時（`timedOut`），或 baseline 尚未完成即寫入（`baselineNotReady`，見〈baseline 與寫入的先後〉）。不得視為 `passed`（系統層 §4.4：系統內建 python3 執行 doc CLI 會 `TypeError`）。
- **驗證子行程逾時 30 秒**（用戶裁定 2026-11-11，`1.0.0-W3-676`）：baseline 與寫入後驗證的每一個 CLI 子行程（`doc validate`、`doc uc verify`）各自計時，自子行程啟動起算，超過 30 秒即終止該子行程，該次驗證為 `unavailable(timedOut)`。baseline 逾時時依上一條「baseline 為 `unavailable`」規則，該次編輯期間的驗證皆為 `unavailable`；放棄並重讀時重跑 baseline。
  - 理由：CLI 本身約 0.35＋0.52 秒（NFR-01），經 `uv run` 另加行程啟動，`uv` 第一次執行可能要先建立環境，可達數秒以上。驗證不阻擋輸入（NFR-01），逾時設長的成本低；設短則第一次執行就可能誤報無法驗證，而 baseline 誤報會使整次編輯的驗證皆無法判定。
  - 驗證逾時不影響寫入結果：寫入已受理為 `written`，檔案不回滾（同驗證失敗）。

**驗收標準**：

- [ ] 寫入的三個可觀測時刻與寫入結果型別可由呼叫端區分（PROP-007 驗收第 3 條）
- [ ] 寫入後驗證器回報新問題時為 `failed`，且檔案未被改回（PROP-005 §1.0 整合測試）
- [ ] 寫入檔在寫入前已含 UC 提及時，寫入後不因該提及判為 `failed`
- [ ] 改寫使問題所在行號位移時，不因行號改變判為新增問題
- [ ] baseline 結束碼為 2 時，寫入後結束碼仍為 2 不判 `failed`；baseline 結束碼非 2、寫入後為 2 時判 `failed`
- [ ] 驗證器無法執行、或 baseline 為 `unavailable` 時為 `unavailable`
- [ ] 驗證子行程超過 30 秒（以注入模擬）時，子行程被終止，驗證狀態為 `unavailable(timedOut)`，寫入結果仍為 `written`、檔案未回滾
- [ ] baseline 量測完成前寫入時，該次驗證為 `unavailable(baselineNotReady)`、不為 `passed`；之後才完成的 baseline 不被採用，下一次寫入以該次寫入後的問題集合為 baseline（v1.7）
- [ ] 寫入後驗證為 `unavailable` 時保留原 baseline；沒有可用 baseline 時，第一個取得的寫入後問題集合成為下一次寫入的 baseline（v1.7）

---

### FR-06: 外部改動的發現時點

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 〈補記：2026-11-10〉前提變動（檔案監看已活躍，SPEC-006 FR-11）；系統層 §3.2 Edit 列；預警觸發來源經主控裁定改為 EVT-CORPUS-001（`1.0.0-W3-553.3`） |
| 對應用例 | UC-08 |

**描述**：外部改動有兩個發現點，兩者並用：

| 發現點 | 作用 |
|---|---|
| Edit 收到 CorpusParsed（EVT-CORPUS-001）後重讀正在編輯的檔案，內容與 M 不同；含重讀得 `notFound`（檔案被刪或改名，比照 FR-01 視為 W ≠ M） | 預警：提前讓使用者知道，不必等到按下寫入 |
| 寫入前閘門（FR-01）的 W ≠ M | 保證：監看事件有延遲、也有漏事件的實例，寫入當下的比對不可省 |

**約束條件**：

- 預警的觸發來源是 EVT-CORPUS-001，不是監看事件本身。檔案監看（SPEC-006 FR-11）偵測到變動後由 Corpus 重新解析並發出 EVT-CORPUS-001；Edit 收到後重讀正在編輯的檔案與 M 比較，不同才轉為預警。EVT-CORPUS-002 是 Corpus 內部的觸發訊號，不跨界，Edit 不消費它。理由：EVT-CORPUS-001 是 Corpus 對外的既有事件，Edit 不必另接監看通道；重讀後比較內容，不把「有事件」直接當成「有改動」。
- 監看預警由編輯狀態本身承載，不發暫態提示，不佔用使用者呈現焦點通道（系統層 §3.2 本 domain 判定「否」的前提）。畫面形式由 SPEC-001／003 的編輯狀態承接。
- 預警之後，使用者仍可嘗試寫入；寫入一律由 FR-01 判定。預警本身不阻擋寫入，也不自動捨棄使用者的未寫入值。
- 放棄並重讀時，以磁碟內容重新開始編輯，M 改為新讀入的內容，並重跑驗證 baseline（FR-05）。

**驗收標準**：

- [ ] 編輯中目標檔被外部改動、EVT-CORPUS-001 到達時，重讀內容與 M 不同，編輯狀態轉為外部已改預警
- [ ] EVT-CORPUS-001 到達但正在編輯的檔案內容與 M 相同時，編輯狀態不變
- [ ] EVT-CORPUS-001 未到達時，寫入仍由 FR-01 判為 `externallyModified`

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
| `writeBlocked`（原因 `snapshotFailed`） | error | `external_process` | 路徑、原因、`git` 結束碼／`executableMissing`／`timedOut` 三擇一 |
| `readIoFailed` | error | `platform_io` | 路徑、`osError.errorCode` |
| `writeIoFailed` | error | `platform_io` | 路徑、`osError.errorCode` |
| `writeRolledBack`（1.1） | warning | — | 觸發失敗的路徑、已還原的路徑數 |
| `writePartiallyWritten`（1.1） | error | `platform_io` | 觸發失敗的路徑、未還原的路徑清單、還原失敗的 `osError.errorCode` |
| `validationCompleted` | `passed` 為 info；`failed`、`unavailable` 為 warning | `unavailable` 為 `external_process`；其餘無 | 路徑、節點 ID、狀態；`failed` 加新增問題數；`unavailable` 加 CLI 結束碼或原因 enum（FR-05，含 `timedOut`）二擇一 |

**約束條件**：

- `rewriteNotIsolated` 歸 `gate_blocked`：它是本 domain 的前置閘門依規則拒絕繼續，不是未預期例外。
- `failed` 不帶 `error_source`：驗證失敗是驗證器的判定結果，不是 App 的失敗。
- 多檔寫入中途失敗（1.1）的記錄方式依結局分兩種，維持一次失敗只記一筆：
  - 還原全部成功：記觸發檔的原失敗事件（`writeBlocked` 或 `writeIoFailed`），另記一筆 `writeRolledBack`。`writeRolledBack` 是回復動作，不是第二次失敗，所以不帶 `error_source`。
  - 有檔還原失敗：只記一筆 `writePartiallyWritten`，觸發失敗的路徑放在它的欄位裡，不另記原失敗事件。
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
| 正常流程中的即時確認 | session 內的可見回饋：本 session 發出過的所有寫入的清單，不只 `written`。發出即成一列（發出後到受理前為寫入中），結局回來時更新同一列，結局為 `written`、`blocked`（三種原因）或 `ioFailed`（FR-05；1.1 起另有 `partiallyWritten`，見下方〈多檔寫入的列法（1.1）〉）。每列附檔案、欄位與所屬專案；被受理的寫入另附該次的 `ValidationStatus`（FR-05），`blocked` 與 `ioFailed` 未受理，沒有驗證狀態。理由：CLI 驗證非同步回來，使用者離開該檔後，要能在這份清單上看到失敗（`1.0.0-W3-187`，用戶裁定）；退出編輯模式時已發出的寫入照常完成，結果只在這份清單上看得到，只列 `written` 會讓未受理的失敗無處可看（SPEC-001 §12）。清單屬 session、不屬專案，切換專案後保留，所以列要帶所屬專案。畫面形式由 SPEC-001 §12 承接 |
| 事後追溯（關掉 App、崩潰、隔天） | structured log：`writeAccepted` 記路徑與欄位名，`snapshotTaken` 記快照 SHA（FR-07） |

**多檔寫入的列法（1.1）**（Q2，用戶裁定 2026-11-12，經主控 AUQ，`1.1.0-W1-111`）：一次多檔寫入（FR-03〈多檔寫入（1.1）〉）在 session 寫入清單只佔一列，與單檔寫入一列對應一次修正相同。列內附寫入集合中每個檔的路徑與各自的取回說明（FR-02，依該檔是否有快照）。驗證狀態只顯示正向檔的，因為反向檔不跑寫入後驗證（FR-03）。結果為 `partiallyWritten` 時，列內改附未還原的檔案與取回說明（FR-05）。畫面形式由 SPEC-004 4.51 承接，在 1.1 規劃波 Step 4.5 補上。

**約束條件**：

- App 不建立 commit。使用者在 App 外以自己的 git 工具提交；App 內提交在 1.1 候選池（`1.1.0-W3-675`）。
- 事後追溯的可取回期限有兩道上限：快照 blob 受 `gc.pruneExpire` 管轄（FR-02），structured log 受 SPEC-010 的保留政策管轄。兩者任一過期，該次寫入前的內容即無法由 App 留下的資訊取回。此為已知限制。

**驗收標準**：

- [ ] 寫入前後，`git log`、`git status --porcelain` 的 index 部分不變
- [ ] session 內可見回饋與 log 記錄不含欄位值
- [ ] 寫入清單每列帶該次寫入的驗證狀態，驗證結果在使用者離開該檔後回來時，清單上的狀態隨之更新
- [ ] 每次發出的寫入都成列：寫入中、`written`、`blocked`（三種原因）、`ioFailed` 各自成列，結局回來時更新同一列；對照：呼叫端未發出的寫入（如必填欄位送出空白，FR-09〈可否清空〉）不成列（1.1 的同類情形：加入的值已在清單中，FR-03〈多值欄位的加入與移除（1.1）〉）
- [ ] 每列附所屬專案；切換專案後清單保留
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
| PROP | outputs | 表格列編輯（每個子鍵一列，各為 chips；子鍵不列舉，SPEC-007 FR-03，語料有 `spec_refs`、`usecase_refs`、`event_refs`、`ticket_refs`） | — | 1.4；其中 `spec_refs`、`usecase_refs`、`event_refs`（後兩者 v1.11）的加入，以及任一子鍵中正向檔 id 的移除，提前到 1.1，只作為 SPEC、UC、EVT `source_proposal` 多檔寫入的反向檔（FR-03〈多檔寫入（1.1）〉〈反向清單鍵〉），不提供直接編輯 |
| PROP | related_proposals | chips 加搜尋 | — | 1.1 |
| PROP | supersedes | 可搜尋下拉（可空） | — | 1.1 |
| SPEC | domain | 可搜尋下拉（已宣告 domain） | 可搜尋下拉 | 1.0 |
| SPEC | subdomain、owner | 單行 | 單行 | 1.0 |
| SPEC | has_functional_requirements | 單選鈕組（是／否） | 單選鈕組 | 1.0 |
| SPEC | source_proposal | chips 加搜尋（provenance 的 forward_cardinality 為 many，`tracking_schema`；加入與移除依 FR-03〈多值欄位的加入與移除（1.1）〉） | — | 1.1（多檔寫入，同批改寫 PROP `outputs.spec_refs`，FR-03〈多檔寫入（1.1）〉） |
| SPEC | related_usecases、related_specs、implements_requirements | chips 加搜尋 | — | 1.1 |
| SPEC | depends_on_domains | 核取清單 | — | 1.1 |
| UC | primary_actor | 單行 | 單行 | 1.0 |
| UC | secondary_actors | 字串清單 | — | 1.4 |
| UC | platform、extension_status、runtime_surface | 單選鈕組 | 單行 | 1.0 |
| UC | source_proposal | chips 加搜尋（同 SPEC 列） | — | 1.1（v1.11 補列；多檔寫入，同批改寫 PROP `outputs.usecase_refs`，FR-03〈多檔寫入（1.1）〉；用戶裁定 2026-11-13，經主控 AUQ） |
| UC | related_specs、related_usecases、ticket_refs | chips 加搜尋 | — | 1.1 |
| UC | flow 區塊 | 表格列編輯 | — | 1.4 |
| DomainBundle | domain | 唯讀（改名屬檔案層級操作） | 唯讀 | 1.5 起經更名 |
| DomainBundle | source_specs、related_usecases、depends_on_bundles | chips 加搜尋 | — | 1.1 |
| DomainBundle | path_patterns | 字串清單 | — | 1.4 |
| EVT | name、canonical_name | 單行 | 單行 | 1.0 |
| EVT | category | 單選鈕組 | 單選鈕組 | 1.0 |
| EVT | source_proposal | chips 加搜尋（同 SPEC 列） | — | 1.1（v1.11 補列；多檔寫入，同批改寫 PROP `outputs.event_refs`，FR-03〈多檔寫入（1.1）〉；用戶裁定 2026-11-13，經主控 AUQ） |
| EVT | producers、consumers | 核取清單 | — | 1.1 |
| EVT | payload | 多行 | 多行 | 1.0 |

**可否清空**（用戶裁定 2026-11-11，`1.0.0-W3-686`；Q1–Q3 由主控依該裁定推導）：清空的寫法見 FR-03〈清空〉。1.0 可編輯欄位依現行元件與是否屬完整性集合，分成三類。必填集合由 App 讀 `tracking_schema.json` 頂層的 `completeness_fields`，不在 App 端另建清單（CLAUDE.md §7）；下表是撰寫時依該欄位投影給讀者看的，實作以 JSON 為準：

| 類別 | 欄位 | 行為 |
|---|---|---|
| 可清空 | PROP source、priority、evaluation_level、proposed_by、target_version；SPEC subdomain、owner；UC primary_actor、platform、extension_status、runtime_surface；EVT status、payload | 單行、多行送出的草稿 trim 後為空時，寫入 `null`；target_version 經 `ReferencePicker` 的 `allowEmpty` 首項寫入 `null`（SPEC-004 4.46） |
| 必填，空白擋下 | title（PROP、SPEC、UC）；status（SPEC、UC）；EVT name、canonical_name | 送出的草稿 trim 後為空時，呼叫端不發出寫入，提示格顯示 `fieldRequiredEmpty`（SPEC-004 4.48），草稿保留 |
| 元件無清空途徑 | status（PROP，下拉）；SPEC domain（`ReferencePicker`，`allowEmpty` 為 `false`）；SPEC has_functional_requirements、EVT category（單選鈕組） | 下拉與單選鈕組在 1.0 不提供清空 |

- 理由：
  - title、status 是識別與顯示最小集（`tracking_schema.py` 註解，上游 #99 第三項裁決）。App 內編輯不把它們寫成 `null`，以免節點失去顯示名與生命週期。
  - EVT name、canonical_name 另有驗證器的非空規則，寫成 `null` 會得到 `failed`（FR-05）。
  - 完整性集合本身只要求鍵存在，值可為 `null`（`completeness_semantics`）。擋下空白是 App 編輯端的附加規則，不是完整性集合的要求。
- SPEC domain 雖不屬完整性集合，但 domain 視圖依它分列，1.0 不可清空。
- trim 只用於判斷是否為空白。非空的值照原樣寫入，不修剪。

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
| `git` 子行程逾時（5 秒） | `git show`：無（走快照分支）；`hash-object`：`blocked(snapshotFailed)` | 終止子行程；`hash-object` 逾時時不寫入 | 同快照失敗 |
| 驗證子行程逾時（30 秒） | `written`＋`unavailable(timedOut)` | 終止子行程，不回滾 | 驗證狀態顯示無法驗證 |

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
| 1.1 | 2026-11-10 | FR-01 約束新增：App 發出的 `git` 呼叫一律設 `LC_ALL=C`；FR-02 註明 `hash-object` 同樣適用。出處為 `1.0.0-W3-553.4` 測試設計審查：H 的判定依賴 `git` stderr，stderr 會隨語系翻譯 |
| 1.2 | 2026-11-11 | `1.0.0-W3-676`（用戶裁定 2026-11-11）：FR-01 新增 `git` 子行程逾時 5 秒（`git show` 逾時視同 H 無法判定、`hash-object` 逾時歸 `snapshotFailed`，不新增 `WriteResult` 型別）與本地檔案 IO 不設逾時；FR-02 快照失敗原因補逾時；FR-05 `unavailable` 原因列舉化並新增 `timedOut`，驗證子行程逾時 30 秒；FR-07 日誌欄位、〈錯誤處理〉表與 FR-02、FR-05 驗收同步。出處為 `1.0.0-W3-553.6` 待裁 6：FieldBlock 的逾時段無法填寫 |
| 1.3 | 2026-11-11 | `1.0.0-W3-553.3`（主控裁定）：FR-06 預警觸發來源由監看事件改為 EVT-CORPUS-001，收到後重讀正在編輯的檔案與 M 比較；明寫 EVT-CORPUS-002 不跨界、Edit 不消費；驗收補「內容相同時狀態不變」；對應用例補 UC-08（UC-08 已照此寫）。`1.0.0-W3-683`（主控裁定，規格自相矛盾當期修）：FR-01 約束新增〈M 的更新〉——`written` 之後 M 改為寫入落檔的位元組，`blocked`、`ioFailed` 時 M 不變，M 只在開始編輯、`written` 受理、放棄並重讀三個時點設定；驗收補連續兩次寫入一條 |
| 1.4 | 2026-11-11 | `1.0.0-W3-686`。依用戶裁定 2026-11-11；Q1–Q3 由主控依該裁定推導。<br>**FR-03**<br>- 新增〈清空〉：清空就是把值的位元組範圍改寫為 `null`，不寫空字串，也不移除鍵。<br>- 寫明兩道隔離檢查對 `null` 的判定，以及移除鍵為何回傳 `rewriteNotIsolated`。<br>- 寫明驗證器不區分三種寫法（fixture 實測）。<br>- 驗收補一條：清空 target_version。<br>**FR-09**<br>- 新增〈可否清空〉，把 1.0 可編輯欄位分成三類：可清空（寫 `null`）、必填空白擋下（提示 `fieldRequiredEmpty`）、元件無清空途徑。<br>- 草稿 trim 後為空即視為空白；非空的值不修剪。<br>- SPEC domain 不可清空。 |
| 1.5 | 2026-11-12 | `1.0.0-W3-553.10`。執行期澄清，用戶裁定（2026-11-12，經主控 AUQ）。<br>**FR-03**<br>- 新增〈非 UTF-8 內容〉：檔案內容不是合法 UTF-8 時，一律回傳 `blocked(rewriteNotIsolated)`，不寫入。理由是解析層以嚴格 UTF-8 解碼整檔，改寫前就沒有可用的解析結果。<br>- 驗收補第 8 條：內文含非法 UTF-8 位元組的檔案，修正欄位時回傳 `rewriteNotIsolated` 且目標檔不變。<br>- 實作行為不變（553.10 已是此行為），本版只把它寫進規格。 |
| 1.6 | 2026-11-12 | `1.1.0-W1-111`（1.1 規劃波）。用戶裁定 2026-11-12（經主控 AUQ）：1.1 改寫 `source_proposal` 時，同批改寫 PROP `outputs.spec_refs`（選項 A）。<br>**FR-03**<br>- 新增〈多檔寫入（1.1）〉，內容包括：適用範圍（文件節點只有 provenance）、寫入集合、反向檔的允許變更集合與 M、閘門整批判定、`rename` 順序、中途失敗的回復、寫入後驗證只套正向檔。<br>- 驗收補 8 條。<br>**FR-05**<br>- `WriteResult` 新增 `partiallyWritten`，並寫明多檔寫入時各結果攜帶的內容。<br>**FR-07**<br>- 新增 `writeRolledBack`、`writePartiallyWritten`，並寫明兩種結局的記錄方式。<br>**FR-09**<br>- `source_proposal` 列註明多檔寫入；PROP `outputs` 列註明 `spec_refs` 值改寫提前到 1.1，只作為反向檔。 |
| 1.7 | 2026-11-12 | 執行期澄清，用戶裁定 2026-11-12，經主控 AUQ（`1.0.0-W3-553.11.1`）。<br>**FR-05**<br>- 新增〈baseline 與寫入的先後〉，內容包括：寫入 rename 前 baseline 尚未完成時丟棄該 baseline；新原因值 `baselineNotReady`；該次寫入後的問題集合接替成為 baseline；寫入後驗證 `unavailable` 時保留原 baseline；沒有可用 baseline 時，第一個取得的寫入後問題集合成為下一次 baseline。<br>- `ValidationStatus` 的 `unavailable` 原因與〈`unavailable` 的情況〉補 `baselineNotReady`。<br>- 驗收補 2 條。 |
| 1.8 | 2026-11-12 | `1.1.0-W1-111`（1.1 規劃波 Step 2.5）：FR-03〈多檔寫入（1.1）〉〈寫入集合〉用詞修正，「在圖上查不到」改為「在 Corpus 的原始節點中查不到」。理由：Graph 與 Edit 同在 L3，讀 Graph 會新增同層依賴；Corpus 已在 Edit 的依賴內（`docs/spec/edit/domain-map.md` §3） |
| 1.9 | 2026-11-12 | `1.1.0-W1-111`（1.1 規劃波 Step 3 的 Q1、Q2）。<br>**FR-03**<br>- Q1（PM 依規格內部一致性定案）：〈寫入集合〉移出時移除該 SPEC id 的全部出現；加入端已含該 id（不論出現幾次）就不列入寫入集合。<br>**FR-08**<br>- Q2（用戶裁定 2026-11-12，經主控 AUQ）：新增〈多檔寫入的列法（1.1）〉。整批一列，列內附各檔路徑與取回說明，驗證狀態只顯示正向檔的；`partiallyWritten` 時附未還原的檔。畫面形式由 SPEC-004 4.51 承接 |
| 1.10 | 2026-11-13 | `1.1.0-W1-111`（1.1 規劃波 Step 4.5 前置，主控審 SPEC-004 1.148 時指出的跨規格缺口）。<br>**FR-03**<br>- 新增〈多值欄位的加入與移除（1.1）〉：操作單位為一次加入或一次移除；值的改寫規則表（flow 序列附加與刪除、純量轉清單、移除到剩一項或零項）；加入已存在的值不寫入；不支援的寫法回傳 `rewriteNotIsolated`。F1–F4 四項格式選擇由用戶裁定（2026-11-13，經主控 AUQ）：F1 `null` 加入寫純量、F2 剩一項寫回純量、F3 剩零項寫 `null`、F4 正向檔重複值移除全部出現。<br>- 〈多檔寫入（1.1）〉〈寫入集合〉改為「加入、移除各一次」：寫入集合最多兩個檔；A 改 B 為兩次寫入。<br>- 驗收：原「由 PROP-A 改為 PROP-B」一條改寫，另補多值欄位各條（含 F1–F4 各一條的具體值）。<br>**FR-09**<br>- `source_proposal` 列改為 chips 加搜尋（`forward_cardinality` 為 many） |
| 1.11 | 2026-11-13 | `1.1.0-W1-111`（1.1 規劃波 Step 4.5 第 3 項衍生）。主控查證 FR-09 漏列：8 份 UC 與 12 份 EVT 都帶 `source_proposal`，FR-09 只列了 SPEC。用戶裁定（2026-11-13，經主控 AUQ）UC、EVT 的 `source_proposal` 都在 1.1 開放，兩者都比照 SPEC 做多檔寫入。EVT 原裁為單檔寫入，前提是「PROP 沒有 EVT 的反向清單」；查證後 4 份 PROP 帶 `outputs.event_refs`，主控向用戶更正後重問，改裁為多檔寫入。<br>**FR-03**<br>- 〈多值欄位的加入與移除〉適用範圍補 UC、EVT。<br>- 〈多檔寫入〉適用範圍改為一般化寫法（正向 `source_proposal`、反向 `outputs` 子鍵，依 SPEC-007 FR-03 子鍵不列舉）。<br>- 新增〈反向清單鍵〉表：SPEC→`spec_refs`、UC→`usecase_refs`、EVT→`event_refs`。註明是依語料慣例的寫入對照，不是型別表資料（主控判定不構成 schema 副本）。<br>- **改變 v1.6 起的既有寫法**（主控依 Q1 與 SPEC-007 D6 推導）：移除時，從 `outputs` 所有清單子鍵刪除該 id 的全部出現，不再只刪 `spec_refs`；加入時只寫依型別決定的子鍵，任一子鍵已含該 id 就不列入寫入集合。理由：任何子鍵的清單項都建反向邊，只刪一處時邊仍存在。寫入集合仍最多兩個檔（仍是同一份 PROP）。<br>- 反向檔允許變更集合改為「`updated` 加上該次改寫的子鍵」；缺鍵保護只適用加入。<br>- 新增〈反向檔子鍵值的形狀〉表：清單、block 或跨多行、`null`、純量四種形狀各自算不算「含該 id」，以及移除、加入時怎麼處理；加入時目標子鍵為 `null` 或純量時回傳 `rewriteNotIsolated`。形狀表前寫明判定順序：先依〈寫入集合〉判定 PROP 列不列入，已列入才套形狀表的移除與加入欄。第 2 列直接引用值改寫規則表的「不改寫」列，不另列較窄清單。新增〈`outputs` 本身不是 map〉表（清單、純量字串、`null` 或缺鍵、數字或布林）。〈寫入集合〉的「含該 id」改依兩張表的「算不算含」欄判定，判定順序第 1 步同時指向兩張表，`outputs` 不是 map 時不以「沒有子鍵」推得不含。驗收補子鍵形狀與 `outputs` 非 map 的情形，各附 E2 對照。<br>- 新增〈已知後果〉：PROP-001、006、007 沒有 `event_refs`，EVT 加入這三份時回傳 `rewriteNotIsolated`。<br>- 〈寫入後驗證〉理由句改為依允許變更集合描述。<br>- 驗收補 UC、EVT 的寫入，以及跨子鍵移除、跨子鍵已含的情形；v1.6 的 `danglingRef` 修正驗收依 v1.10 操作單位改寫為先移除、再加入。<br>**FR-09**<br>- 補 UC、EVT 的 `source_proposal` 列。<br>- PROP `outputs` 列改寫：加入限三個子鍵、移除涵蓋任一子鍵；目標元件改為「每個子鍵一列」，不寫死清單數 |
| 1.12 | 2026-11-13 | `1.0.0-W3-553.17.1`（執行期澄清，主控審）。553.17 實作時發現 SessionWriteList 只記錄 `written`，與 SPEC-001 §12「列出所有發出過的寫入，不只 `written`」不一致；用戶裁定 2026-11-13（經主控 AUQ）1.0 本版修，以 §12 為準。<br>**FR-08**<br>- 〈正常流程中的即時確認〉載體由「本 session 寫過的檔案與欄位清單」改為「本 session 發出過的所有寫入」：發出即成列（寫入中），結局（`written`、`blocked` 三種原因、`ioFailed`）回來時更新同一列；每列附所屬專案；驗證狀態只附在被受理的寫入上。補理由：退出編輯模式後未受理的失敗只在清單上看得到；清單屬 session，切換專案後保留。<br>- 驗收補兩條：各結局成列（含「未發出不成列」的對照）、列附所屬專案且切換專案後保留 |
| 1.13 | 2026-11-13 | `1.1.0-W1-111.1`（1.1 規劃波 Step 5 測試設計回報的缺口，主控依規格內部一致性定案，不經用戶）。原文「寫入層仍收到時視同無變更」沒有寫回傳哪個 `WriteResult`，也沒有寫是否記 FR-07 事件。<br>**FR-03**<br>- 〈多值欄位的加入與移除（1.1）〉的「加入的值已在清單中」：判定點定在呼叫端，發出寫入之前，比照必填欄位送出空白。不發出寫入，所以沒有 `WriteResult`、不成列、不記 FR-07 事件。寫入層把「加入的值不在清單中」當作前置條件，debug 期以 assert 檢查，不新增 `WriteResult`。理由：FR-08 驗收已把這種情形歸為「呼叫端未發出的寫入」；FR-07 事件表本來就沒有必填空白的事件 |
