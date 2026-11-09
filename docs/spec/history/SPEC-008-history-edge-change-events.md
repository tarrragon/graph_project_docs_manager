---
id: SPEC-008
title: "History：主線邊事件的掃描、解析與降級"
status: draft
source_proposal: PROP-006
created: "2026-11-09"
updated: "2026-11-09"
version: "1.1"
owner: "主線程（PM）"
has_functional_requirements: true

domain: "history"
subdomain: null

related_usecases: [UC-07]
related_specs: [SPEC-007, SPEC-001]
implements_requirements: []
depends_on_domains: [workspace, schema]
---

# History：主線邊事件的掃描、解析與降級

## 概述

本規格定義 0.7.0（History）的資料管線：以單次 `git log -p` 讀取工作區的主線歷史，把 frontmatter 的
變更解析為**邊事件**（某條邊在某個主線 commit 新增或移除），供第七畫面「變更記錄」（SPEC-001 §10）依期間呈現。
產品面裁決見 PROP-006；架構定案（邊層級、單次 `git log -p`、依視圖惰性載入、不做增量、三種降級）見
`docs/tech-decisions.md`〈git 變更記錄：邊層級〉與 `docs/spec/history/domain-map.md` §4.1，本規格不重議。

| Domain | 本規格內的職責 | 對應 FR |
|--------|--------------|--------|
| **Workspace** | 提供工作區根路徑 | FR-01 |
| **Schema** | 提供邊型表（正向欄位、反向欄位、方向、層級）與節點型別的 `id_pattern`；型別表缺席時的內建表降級沿用 Schema 既有行為 | FR-03、FR-05 |
| **History** | 前置檢查、掃描、檔案狀態追蹤、邊事件產生、版本 tag 與期間、篩選、降級與快取 | FR-01～FR-10 |

版本契約（PROP-005 §0.7）為兩項整合測試，本規格的 FR 以它們為驗收終點：

| 整合測試 | 驗收的 FR | 斷言 |
|---------|----------|------|
| IT-H1 成本量級 | FR-01、FR-02、FR-10 | 對 flutter_balance 與本專案各執行一次完整掃描，記錄 commit 數、輸出位元組數、git 耗時、解析耗時與尖峰追蹤文字量。量級與定案參考值（9409 commits、31.2 MB、2.28 秒）可比較；狀態失步計數（FR-02 規則 8）為 0 |
| IT-H2 三種降級可辨識 | FR-08 | 非 git 目錄、git 不在 PATH、淺層 clone 三個 fixture 各得到不同的結果型別；三者皆不落在「讀取失敗」 |

History 無主動推送的呈現面：掃描由使用者進入第七畫面觸發（等待型），結果在同一畫面內呈現，不佔用使用者呈現焦點通道
（`docs/spec/history/domain-map.md` §2.5）。

## 用詞

| 詞 | 定義 |
|----|------|
| 主線 | 自 HEAD 沿第一個父 commit 回溯所得的 commit 序列（`--first-parent`） |
| 主線 commit | 主線上的一個 commit。分支上完成的工作，在主線上表現為一個 merge commit，其變更為該 merge 相對第一個父 commit 的差異 |
| 主線序號 | 主線 commit 自根起算的位置（根為 0），由 FR-01 規則 2 的主線清單決定 |
| 使用中邊型 | 與 SPEC-007〈用詞〉同義：型別表中 `layer` 為 `established` 的邊型，加上 `proposed` 層的 `bundle_dependency` 與 `closed_by` |
| 宣告 | 某路徑上的 frontmatter，其某個邊型欄位（正向或反向）列出的一個字串值，記為（路徑、欄位、值），即 SPEC-007 的「引用值」 |
| 邊鍵 | 一條邊的身分：（邊型、起點、終點）。有向邊由宣告側換算（FR-04 規則 1）；無向邊的兩端依 ID 字典序排列 |
| 邊事件 | 某個邊鍵在某個主線 commit 由「無任何宣告」變為「至少一個宣告」（新增），或反過來（移除） |
| ticket 建檔事件 | 一筆新增事件，且該 commit 新建了某個 ticket 節點的檔案，該節點是此邊的宣告者之一（FR-05） |
| 版本 tag | 名稱符合 `^v?[0-9]+\.[0-9]+\.[0-9]+$` 的 tag（FR-06） |

## 前置依賴

| 依賴 | 擋住 | 承接 |
|------|------|------|
| Schema 公開面提供邊型表與節點型別 `id_pattern` | FR-03、FR-05 | 既有（SPEC-007 FR-01、SPEC-006 FR-03 已消費同一公開面） |
| domain-map 補 History → Schema 出邊 | 依賴方向底線 | 已同批（`docs/spec/history/domain-map.md` frontmatter、`docs/system-layer.md` §2） |

## 功能需求

### FR-01：前置檢查與掃描指令

**描述**：History 先以少數輕量 git 呼叫判定工作區狀態並取得主線與版本 tag，再以單次 `git log -p` 讀取主線歷史。

**規則**：
1. 工作區根路徑取自 Workspace。所有 git 呼叫皆以 `git -C <工作區根>` 執行，環境變數 `LC_ALL=C`，不改變行程的工作目錄
2. **前置檢查**依序取得，全部以結構化輸出判定，不解析錯誤文字：
   - git 版本（`git --version`）：低於 2.31 時結果為「讀取失敗」，原因碼「git 版本過舊」
   - 工作樹狀態：是否在 git 工作樹內、是否為淺層 clone、HEAD 是否存在（例：`git rev-parse --is-inside-work-tree --is-shallow-repository` 與 `git rev-parse --verify -q HEAD` 的輸出與結束碼）
   - 主線清單（`git rev-list --first-parent HEAD`）：決定主線序號
   - tag 清單（`git for-each-ref refs/tags`，含 annotated tag 指向的 commit）：供 FR-06 使用
   結果分四類：不是 git 工作樹、git 無法啟動、工作樹存在但沒有任何 commit、正常（含淺層與否）。前三類直接落到 FR-08 對應結果，不執行掃描
3. **掃描指令**語意上等同：
   `git -C <工作區根> -c core.quotePath=false log -p --reverse --first-parent --diff-merges=first-parent --no-renames --no-color --no-ext-diff --no-textconv --no-show-signature --src-prefix=a/ --dst-prefix=b/ --relative --format=<FR-02 規則 1 的標頭> -- docs/`
   - `--first-parent --diff-merges=first-parent`：用戶裁定的主線歸屬（PROP-006）。後者在 2.31 以上已由前者隱含，保留作明示
   - `--reverse`：由舊到新，供 FR-02 線性重放；`--reverse` 在 commit 選取之後才套用，與 `--first-parent` 不衝突
   - `--no-renames`：改名表現為刪除加新增；事件以 commit 為單位計算（FR-04 規則 2），改名不會產生假事件
   - `--relative` 加 `-- docs/`：工作區根不是 repo 頂層時，路徑仍相對於工作區根，範圍與 Corpus 一致（SPEC-006 FR-02）
   - `--no-show-signature`、`--src-prefix`、`--dst-prefix`：覆蓋使用者 git 設定（`log.showSignature`、`diff.noprefix`、`diff.mnemonicPrefix`），使輸出格式固定
4. 只處理路徑以小寫 `.md` 結尾的檔案差異，其餘（含二進位）略過，與 SPEC-006 FR-02 一致

**驗收條件**：
- [ ] Given 工作區根是某 repo 的子目錄，且 repo 頂層另有 `docs/` 之外的 `.md` 變更，Then 事件只來自工作區根下的 `docs/**/*.md`，路徑相對於工作區根
- [ ] Given 一個 commit 只改名某節點檔案、內容不變，Then 該 commit 不產生任何事件
- [ ] Given 前置檢查判定為三種非正常類之一，Then 不啟動掃描程序（以 fake 程序執行器斷言呼叫次數）
- [ ] Given fixture repo 設定 `diff.noprefix=true` 與 `log.showSignature=true`，Then 事件與未設定時相同

### FR-02：串流解析與檔案狀態追蹤

**描述**：History 逐行讀取掃描輸出，為每個 `.md` 路徑維護目前的全文，於每個主線 commit 結束時取得該 commit 前後的宣告集合。

**規則**：
1. **commit 標頭**以 U+001E 開頭，欄位以 U+0000 分隔：commit id、父 commit id 清單（`%P`）、committer 時間（Unix 秒）、作者名、訊息首行
2. **串流與解碼**：輸出逐行處理，不先整份讀入記憶體。每行以 UTF-8 容錯解碼，無法解碼的位元組以替換字元代入，計入「無法解碼行」計數；解碼問題不使掃描失敗
3. **檔案路徑**取自 `--- a/<路徑>` 與 `+++ b/<路徑>` 行（新增檔的舊側與刪除檔的新側為 `/dev/null`），路徑帶 C-style 雙引號時依 git 規則還原；不從 `diff --git` 行切取
4. **hunk 依行數消耗**：讀到 `@@ -a,b +c,d @@` 後，依舊側 b 行、新側 d 行的剩餘數逐行消耗（` ` 行兩側各減一，`-` 行舊側減一，`+` 行新側減一），兩者都歸零之前，任何行都視為內容，不認檔頭。`\ No newline at end of file` 行不佔行數，只標記前一行沒有結尾換行
5. **狀態**：每個路徑持有全文（行序列）。新增檔不論有沒有 hunk 都建立狀態，沒有 hunk 時為空；刪除檔移除狀態；修改時依 hunk 套用；只改 mode 或二進位、沒有 hunk 的條目不改變狀態
6. **frontmatter 範圍**於每個 commit 結束時從全文重新計算：第一行為 `---`，到下一個單獨的 `---` 行為止；比對前去掉行尾的 `\r`。沒有 frontmatter 的檔案不持有宣告。效能捷徑：某路徑本 commit 的全部 hunk 舊側起點都大於上一次的 frontmatter 結束行時，不重新解析該路徑的 YAML
7. **YAML 解析失敗**：全文照常更新，只凍結宣告——該路徑沿用上一個可解析版本的宣告，不產生事件，計入「無法解析的版本」計數並寫 debug 日誌；下次可解析時再與沿用的宣告比較。理由：暫時寫壞的 YAML 不應呈現為「移除後又新增」。代價：修好之前的真實變更會歸到修好的那個 commit（已知限制，見 H7）
8. **狀態失步**：hunk 的舊側內容與追蹤中的全文不符時，該路徑停止產生事件，計入「狀態失步」計數並寫 warning 日誌（含路徑與 commit id）。主線線性重放下預期為 0，IT-H1 斷言之；此規則的價值是作為斷言，不設恢復機制

**驗收條件**：
- [ ] Given 一個 block 清單欄位（`spawned_tickets:` 下多列 `- <id>`），某 commit 只在清單中段加一列，hunk 上下文不含欄位名，Then 產生一筆新增事件，邊型為 `spawn`、端點正確
- [ ] Given 某 commit 刪除 frontmatter 的結尾 `---` 那一行（輸出為 `----`），Then 解析器不把它當作檔頭，frontmatter 範圍依全文重新計算
- [ ] Given 既有檔原本沒有 frontmatter，某 commit 在第 1 行補上帶 `parent_id` 的 frontmatter，Then 產生一筆新增事件，失步計數為 0
- [ ] Given CRLF 換行的檔案，Then frontmatter 照常辨識
- [ ] Given 先以空檔新增、下一個 commit 才寫入內容，Then 第二個 commit 依內容產生事件
- [ ] Given 檔尾無結尾換行的修改，Then 狀態正確，失步計數為 0
- [ ] Given 某 commit 把 frontmatter 改成無法解析的 YAML，下一個 commit 修好且邊集合不變，Then 兩個 commit 皆不產生事件，「無法解析的版本」計數為 1
- [ ] Given 某 commit 只改 frontmatter 之後的內文，Then 不產生事件，且不重新解析該路徑的 YAML（以解析次數斷言）
- [ ] Given 一份 hunk 舊側與追蹤內容不符的合成輸出（正向對照），Then 失步計數為 1、有 warning 日誌、該路徑之後的變更不產生事件
- [ ] Given 一行含非 UTF-8 位元組的內文，Then 掃描完成，「無法解碼行」計數為 1

### FR-03：宣告的抽取

**描述**：從一份已解析的 frontmatter 抽出該路徑的全部宣告。

**規則**：
1. 節點 ID 為 frontmatter 的 `id` 欄（字串）；沒有 `id` 的檔案不持有宣告，計入「無 ID 檔案」計數
2. 邊型、欄位名、反向欄位、方向一律取自 Schema 的邊型表，不在程式內寫死（同 SPEC-007 D6）；使用中邊型的範圍與 SPEC-007〈用詞〉一致。型別表取目前版本，套用到全部歷史（已知限制，見 H7）
3. 值的形狀規則同 SPEC-007 FR-03：純量為一個值，清單每一項各一個值，反向欄位的值為 map 時每個子鍵清單的每一項各一個值；`null` 與空清單沒有值
4. 只收字串值；非字串值不收，計入「非字串值」計數。History 不判斷值是否指向存在的節點（斷邊屬 Graph 與 Diagnostics 的職責），也不套用 Graph 的格式錯誤分類
5. `closed_by` 套用 SPEC-007 FR-03〈`closed_by` 的略過規則〉：不符合主圖節點型別 `id_pattern` 的值略過
6. `domain_dependency` 的值是 domain 名稱而非節點 ID；照常產生事件，對端以名稱原值呈現（FR-07 規則 4）

**驗收條件**：
- [ ] Given 型別表新增一個 established 邊型（fixture 表），Then 不改程式即對該欄位產生事件
- [ ] Given `closed_by: tarrragon/claude#60`，Then 不產生事件；Given `closed_by: <符合 ticket id_pattern 的值>`，Then 產生事件（正向對照）

### FR-04：邊身分與事件

**描述**：事件以主線 commit 為單位，比較該 commit 前後每個邊鍵的宣告來源集合。

**規則**：
1. **邊鍵換算**：有向邊的正向宣告換為（邊型、宣告者 ID、值），反向宣告換為（邊型、值、宣告者 ID）；無向邊換為（邊型、兩者依字典序）。有反向欄位的邊取兩側聯集，與 SPEC-007 D1 一致
2. **以 commit 為單位**：每個主線 commit 結束時，對該 commit 有變更的路徑，比較其宣告在 commit 前後的差異，彙整到邊鍵層級。宣告來源集合的元素是（路徑、欄位、值）；某邊鍵的來源集合由空變非空產生一筆新增事件，由非空變空產生一筆移除事件。因此只增減宣告側（例如反向欄位補上而正向欄位原本就有）、或宣告在同一 commit 內移到另一個路徑（含改名），都不產生事件
3. 事件欄位：類型（新增／移除）、邊鍵、該 commit 前後的宣告者（以節點 ID 去重後呈現）、commit id、committer 時間、作者名、訊息首行、是否為 ticket 建檔事件（FR-05）
4. 同一 commit 內事件的排序：依邊型鍵名、起點、終點的字典序，使輸出可重現
5. 節點改過 ID 時，舊 ID 的邊產生移除、新 ID 的邊產生新增；不追蹤改名（已知限制，見 H6）

**驗收條件**：
- [ ] Given 一條 `blood` 邊（`parent_id` 與 `children` 兩側），commit A 只寫入 `parent_id`、commit B 補上 `children`，Then A 產生一筆新增，B 不產生事件
- [ ] Given commit C 刪除 `parent_id`，但 `children` 仍列出，Then 不產生事件；commit D 再刪除 `children`，Then 產生一筆移除
- [ ] Given 一條 `relatedTo` 邊由兩端分別宣告，Then 邊鍵相同、只有一筆新增
- [ ] Given 某 commit 把節點檔案從 `docs/a/` 移到 `docs/b/`（`--no-renames` 下為刪除加新增），Then 不產生事件
- [ ] Given 兩個檔案共用同一個 `id` 且都宣告同一條邊，刪除其中一檔，Then 不產生事件；再刪另一檔，Then 產生一筆移除

### FR-05：ticket 建檔事件

**描述**：標記因新建 ticket 檔案而產生的新增事件，供第七畫面預設排除。

**規則**：
1. 節點是否為 ticket，依其 `id` 比對 Schema 中 ticket 節點型別的 `id_pattern` 判定（與 SPEC-006 FR-03 判型同一來源，不依路徑）
2. 一筆新增事件為 ticket 建檔事件，若且唯若：該 commit 新建的某個檔案（FR-02 規則 5 的新增檔），其節點為 ticket，且該路徑在本 commit 後的宣告屬於此邊的來源集合
3. 移除事件一律不是 ticket 建檔事件

**驗收條件**：
- [ ] Given 一個 commit 新建 ticket 檔，帶 `parent_id` 與 `blockedBy`，Then 兩筆新增事件皆標為 ticket 建檔事件
- [ ] Given 下一個 commit 在同一 ticket 補一個 `blockedBy` 值，Then 該筆新增事件不是 ticket 建檔事件（正向對照）
- [ ] Given 一個 commit 新建 SPEC 檔，Then 其新增事件不是 ticket 建檔事件

### FR-06：版本 tag 與預設期間

**描述**：由前置檢查的 tag 清單與主線清單決定預設期間，不依賴掃描輸出中是否出現 tag 所在的 commit。

**規則**：
1. 版本 tag 取自 FR-01 規則 2 的 tag 清單，名稱符合 `^v?[0-9]+\.[0-9]+\.[0-9]+$`；annotated tag 以其指向的 commit 為準。tag commit 不在主線清單中者不採用
2. **基準 tag**：主線序號最大、且不是 HEAD 本身的版本 tag commit。HEAD 本身帶版本 tag 時（剛發版），基準取前一個，期間即為剛發佈的那一版
3. **預設期間**：有基準 tag 時，為主線序號大於基準 tag commit 的主線 commit；沒有基準 tag 時，為 committer 時間在「目前時間減 30 天」之後的主線 commit（用戶裁定 2026-11-09）。期間判定以主線序號或 committer 時間為準，與 tag commit 是否觸及 `docs/` 無關
4. 「最近 30 天」的時間判定以注入的時鐘取得「目前時間」，不直接讀系統時鐘（`test-assertion-design-rules` D3）；預設期間與 FR-07 的「最近 30 天」選項共用同一判定
5. 預設期間對畫面提供描述：有基準 tag 時為「<基準 tag> 之後」，否則為「最近 30 天」

**驗收條件**：
- [ ] Given 主線上有 `v0.5.0`、`v0.6.0` 兩個 tag 且 HEAD 在 `v0.6.0` 之後，Then 預設期間為 `v0.6.0` 之後
- [ ] Given HEAD 本身帶 `v0.6.0`，Then 預設期間為 `v0.5.0` 之後到 HEAD
- [ ] Given `v0.6.0` 打在一個只改 `pubspec.yaml`、未觸及 `docs/` 的主線 commit，Then 基準 tag 仍為 `v0.6.0`
- [ ] Given 只有名為 `release-1` 與 `v1.0.0-rc1` 的 tag，Then 視為沒有基準 tag，預設期間為最近 30 天
- [ ] Given 版本 tag 只打在分支 commit 上（不在主線），Then 不採用

### FR-07：查詢（History 公開面）

**描述**：History 對畫面提供掃描結果與篩選查詢。

**規則**：
1. 掃描結果型別：完成（含事件、預設期間、淺層資訊、計數摘要）、FR-08 所列的各降級與失敗型別、已取消
2. 篩選條件：期間（預設期間／最近 30 天／全部歷史）與「包含 ticket 建檔事件」（預設否）
3. 查詢結果依主線順序由新到舊排列；同一 commit 內依 FR-04 規則 4
4. 每筆事件提供對端與宣告端的識別：節點 ID 原值；`domain_dependency` 的對端為 domain 名稱原值，並標示「非節點」，供畫面決定是否可跳轉
5. 查詢只在記憶體中的完成結果上運算，不重新掃描

**驗收條件**：
- [ ] Given 同一份 fixture，分別以「包含 ticket 建檔事件」為否與是查詢，Then 兩次結果不同，且前者是後者的子集（E1 對照）
- [ ] Given 期間為「全部歷史」，Then 結果包含淺層邊界之後（FR-08 規則 3）的全部事件

### FR-08：降級與失敗

**描述**：三種定案降級各有獨立的結果型別，與一般失敗區分；判定只依結束碼與結構化輸出，不依錯誤文字。

**規則**：
1. **不是 git 工作樹**：前置檢查判定不在工作樹內 → 結果「非 git 專案」
2. **git 無法啟動**：啟動行程拋出無法執行的例外（不在 PATH 或無執行權限）→ 結果「找不到 git」
3. **淺層 clone**：前置檢查回報淺層 → 照常掃描，結果帶淺層資訊（邊界 commit 的時間）。邊界 commit 為標頭父欄位為空、且 repo 為淺層的 commit；它只用來建立初始狀態，不產生事件（否則邊界上每條邊都會呈現為新增）。非淺層 repo 的根 commit 照常產生事件。畫面須標示「歷史不完整，早於邊界的變更不在其中」
4. **工作樹沒有任何 commit**：結果為完成且事件為空，帶「尚無 commit」標記，不是失敗
5. **讀取失敗**：git 版本過舊（FR-01 規則 2）、掃描程序非 0 結束、程序異常終止 → 結果「讀取失敗」，帶原因碼與 stderr 摘要，可重試。單行解碼問題不屬此列（FR-02 規則 2）
6. **型別表**：Schema 處於「無可消費的型別表」或版本不符等阻擋狀態時，History 不掃描，第七畫面落 SPEC-001 §10「專案未就緒」（共用 SPEC-001 §1 之後的註記）；Schema 以內建型別表降級時，History 照常掃描並使用內建表，畫面帶降級徽章（SPEC-001 §1〈降級型別表〉）
7. 三種定案降級（規則 1～3）的判定不得落入規則 5

**驗收條件**：
- [ ] Given 非 git 目錄、PATH 中沒有 git、淺層 clone 三個 fixture，Then 三者結果型別互不相同，且皆不是「讀取失敗」（IT-H2）
- [ ] Given 淺層 clone fixture，Then 邊界 commit 不產生事件，結果帶邊界時間；Given 非淺層 fixture，Then 根 commit 照常產生事件（正向對照）
- [ ] Given 系統語系為非英文的環境，Then 非 git 目錄仍判為「非 git 專案」
- [ ] Given fake 程序執行器讓掃描以結束碼 1 結束，Then 結果為「讀取失敗」並帶 stderr 摘要

### FR-09：惰性載入、快取與取消

**描述**：掃描只在需要時執行，結果在 HEAD 與型別表不變時重複使用。

**規則**：
1. 進入第七畫面且沒有可用快取時才開始前置檢查與掃描；其他畫面不觸發
2. 快取鍵為（工作區根、HEAD commit id、型別表識別）。再次進入時先做前置檢查取得 HEAD；前置檢查期間畫面維持先前結果的狀態。鍵相同則直接使用快取，不掃描；前置檢查判定為三種非正常類之一時，直接轉入對應結果
3. 鍵不同或使用者要求重新整理時，全量重掃（不做增量，架構定案）
4. 掃描可取消：取消時終止掃描程序、丟棄部分結果，結果為「已取消」；快取維持取消前的完成結果（若有）
5. 切換專案時清除快取並取消進行中的掃描
6. 記憶體：常駐為各路徑全文與事件。尖峰追蹤文字量約等於歷史中 `docs/**/*.md` 總量的最大值（本專案 HEAD 時約 40 MB，量測環境：作者本機 macOS，2026-11-09），IT-H1 記錄實測值

**驗收條件**：
- [ ] Given 已有完成結果，HEAD 未變時再次查詢，Then 掃描程序啟動 0 次；HEAD 改變後再次查詢，Then 啟動 1 次
- [ ] Given 掃描進行中取消，Then 掃描程序被終止，結果為「已取消」

### FR-10：可觀測性與 tripwire

**描述**：掃描的啟動、結束、成本與異常皆有日誌，輸出量超過閾值時留下早期警訊。

**規則**：
1. 以 `developer.log` 記錄：前置檢查的入口與結果類別（含 git 版本）；掃描開始（工作區根、HEAD）；掃描結束（commit 數、輸出位元組數、git 耗時、解析耗時、事件數、FR-02 與 FR-03 的各項計數）；取消；各降級與失敗（含結束碼與 stderr 摘要）
2. **tripwire**：輸出位元組數超過 256 MiB 時寫 warning 日誌，含位元組數與 commit 數。閾值約為本專案實測（83 MB）的三倍；緩解手段（`--since` 或路徑範圍收窄）沿用定案，本版不實作，觸發後另行評估
3. 行程啟動與結束屬平台互動，依 `observability-rules` 規則 5 逐點記錄

**驗收條件**：
- [ ] Given 以 fake 程序執行器輸出超過閾值的位元組數，Then 有一筆 tripwire warning 日誌；低於閾值時沒有（正向對照）

## 非功能需求

### NFR-01：成本量級

單次掃描（git 加解析）在本專案（約 3 萬 commits、83 MB）維持秒級。IT-H1 記錄實測值；若解析耗時使總耗時超過 git 耗時的兩倍，實作票停手回報，不自行修改掃描架構。

## 錯誤處理

| 情形 | 結果型別 | 可重試 |
|------|---------|--------|
| 不是 git 工作樹 | 非 git 專案 | 否（重新檢查會再判定一次） |
| git 無法啟動 | 找不到 git | 是（安裝後重新檢查） |
| 淺層 clone | 完成（帶淺層資訊） | — |
| 沒有任何 commit | 完成（事件為空，帶尚無 commit 標記） | — |
| git 版本過舊、掃描程序失敗 | 讀取失敗 | 是 |
| 單行無法解碼 | 完成（計入計數） | — |
| 使用者取消 | 已取消 | 是 |

## 設計約束

| 編號 | 約束 | 依據 |
|------|------|------|
| H1 | 掃描為單次 `git log -p`；前置檢查為少數輕量 git 呼叫（版本、工作樹狀態、主線清單、tag 清單） | 架構定案（`docs/tech-decisions.md`〈git 變更記錄：邊層級〉，淺層以 `git rev-parse --is-shallow-repository` 偵測）；tag 改由前置檢查取得見變更歷史 1.1 |
| H2 | 事件歸屬主線 commit | 用戶裁定 2026-11-09（PROP-006） |
| H3 | History 依賴 Workspace 與 Schema，不依賴 Corpus、Graph | `docs/system-layer.md` §4.3；Schema 出邊見 PROP-006〈提案方案〉第 4 點 |
| H4 | 邊型與節點型別取自型別表，不寫死；`closed_by` 略過規則與 SPEC-007 同 | SPEC-007 D6 |
| H5 | 不做增量掃描 | 架構定案 |
| H6 | 不追蹤節點 ID 改名 | FR-04 規則 5（已知限制） |
| H7 | 型別表取目前版本套用到全部歷史：歷史中改過名的邊欄位、或曾不在使用中範圍的邊型，其舊增減不呈現；YAML 暫時無法解析期間的真實變更歸到修好的 commit | FR-02 規則 7、FR-03 規則 2（已知限制）。依歷史版本切換型別表屬過度設計，不採用 |
| H8 | 最低 git 版本 2.31 | FR-01 規則 2（`--diff-merges` 選項） |

> **與 Graph 的重複**：FR-03 的值形狀規則與 SPEC-007 FR-03 相同，但 History 不得依賴 Graph（H3），因此兩處各自實作。
> 兩者分歧時以 SPEC-007 為準；若要收斂為共用元件，須另立提案決定放在哪一層。

## 本版範圍外

- 節點詳情的變更記錄區段、依 commit 反查、邊型與節點型別篩選、自訂日期區間（PROP-006〈本提案不做的〉）
- tripwire 觸發後的緩解手段（FR-10 規則 2）

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.1 | 2026-11-09 | 多視角審查（linux、saffron）修正：FR-02 改為追蹤每個路徑全文，frontmatter 範圍每個 commit 重新計算（原只追蹤 frontmatter，邊界移動時失準）；hunk 依行數消耗，不以前綴辨認檔頭；補 `\` 行、CRLF、空新增檔、無 hunk 條目、C-style 引號路徑、容錯解碼；失步只作斷言、不設恢復。FR-01 加 `LC_ALL=C`、`--no-show-signature`、固定前綴、最低 git 2.31，前置檢查改以結構化輸出判定並取得主線清單與 tag 清單；FR-06 版本 tag 改由 tag 清單與主線序號決定（原取自掃描輸出的 decoration，`-- docs/` 會剪掉未觸及 docs 的 tag commit）。FR-04 來源集合元素為（路徑、欄位、值）；FR-08 淺層邊界以父欄位為空辨認，型別表阻擋落 SPEC-001 §10「專案未就緒」；FR-09 前置檢查期間維持先前狀態；新增 H7、H8 |
| 1.0 | 2026-11-09 | 初版（`0.7.0-W1-012` 規劃波；用戶裁定：一列一個邊事件、期間內全專案、第七畫面、主線歸屬、預設期間為最近版本 tag 至今） |
