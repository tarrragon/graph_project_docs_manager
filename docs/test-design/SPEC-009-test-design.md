---
id: SPEC-009-test-design
title: "SPEC-009 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-009
spec_version: "1.1"
ticket: 1.0.0-W3-553.4
created: "2026-11-10"
updated: "2026-11-10"
---

# SPEC-009 Phase 2 紅燈測試規格

本文件是 SPEC-009 v1.1（編輯能力：寫入路徑、寫入前閘門與寫入結果）的紅燈測試規格，對應 version-bootstrap Step 5 的 edit 部分，供 edit domain 的實作票以 TDD 開工。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-009；本文件與其衝突時以 SPEC-009 為準，衝突本身記入承接票的 NeedsContext。

編輯狀態的畫面形式（SPEC-001 狀態矩陣、SPEC-003 互動反應）由 `1.0.0-W3-553.3` 定義。本文件只斷言畫面狀態層取得的狀態值，不斷言 widget 錨點；錨點案例在 553.3 定稿後由畫面票補上（§6）。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-E1～IT-E6：真實 git 的 fixture repo 與真實 doc CLI | 驗證 git 指令選項、`.gitattributes`、子目錄工作區、symlink、權限位元在真實檔案系統與真實 git 上的行為；PROP-005 §1.0 整合測試 | fake port 與真實 git、真實檔案系統、真實驗證器的行為分歧 |
| 5b 內圈 | `test/unit/edit/` 逐群組 domain unit；兩個靜態守衛；畫面狀態層的狀態斷言 | SPEC-009 FR-01～FR-09、NFR-01 的驗收條件，以及 edit domain-map §3〈Bundle 不變式清單〉逐條斷言 | 單一規則被打破，可直接定位 |

內圈不啟動真實 git 與 doc CLI。凡是要靠真實 git 或真實檔案系統行為才能斷言的條件（換行轉換、`show HEAD:./`、symlink 解析、權限位元、index／stash／reflog 不變），一律放外圈。FR-04 的路徑型別例外：它依賴真實的 `resolveSymbolicLinks` 與 `FileSystemEntity.type`，但只需本機暫存目錄，不需 git，所以放內圈並使用真實暫存目錄（P 群組）。

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 三平面判定、閘門步驟順序、讀取失敗分類（FR-01） | domain unit | 檔案系統以 `EditFilePort` 注入（fake 記憶體實作，可在指定步驟之後改動目標檔、或讓指定操作失敗）；git 以 fake git port 注入 |
| 快照指令組裝、快照失敗（FR-02） | domain unit | fake git port：依引數清單回傳結束碼、stdout 位元組、stderr，或拋出「無法啟動」；記錄每次呼叫的引數、標準輸入位元組、環境變數 |
| 局部改寫、改寫隔離檢查（FR-03） | domain unit（純函式為主） | 解析層使用真實的 Corpus 公開函式 `classifyFrontmatter`（Sociable，不 mock）；時鐘注入固定日期 `2026-11-10` |
| 暫存檔與 `rename` 順序（FR-03） | domain unit | `EditFilePort` fake 記錄操作序列（寫入、fsync、rename、刪除、chmod） |
| 路徑界內型別（FR-04） | domain unit，使用真實暫存目錄 | 不 mock 檔案系統：symlink 與父目錄解析需真實行為 |
| 寫入結果、三個可觀測時刻、baseline 差集（FR-05） | domain unit | 驗證器以 fake validator port 注入：依 CLI 名稱與引數回傳結束碼與 stdout 文字，或回報「無法執行」；可設為永不完成，用來測不阻擋 |
| 外部改動預警（FR-06） | domain unit（application 層，Riverpod `ProviderContainer`） | 監看事件沿用 `test/helpers/fake_watch_source.dart` |
| 日誌事件（FR-07） | domain unit | 注入記錄用 `LogSink<EditLogEvent>`（沿用 SPEC-010 的 sink 契約），斷言事件碼、等級、`error_source`、fields |
| session 寫入清單（FR-08） | domain unit（application 層） | 同 FR-06 |
| 欄位 → 輸入元件對照（FR-09） | 畫面狀態層 unit（對照函式）；widget 待 553.3 | 值域來源以 fake 注入 |
| 寫入函式只收路徑型別（FR-04） | 契約（靜態守衛，放 `test/` 根目錄，比照 `entitlements_contract_test.dart`） | 不 mock：對 fixture 跑 `fvm dart analyze` |
| IT-E1～IT-E6 | integration（`integration_test/`） | 不 mock git、檔案系統與 doc CLI：在暫存目錄依 §1.5 建 fixture repo |

Mock 只替換外部世界（檔案系統、git、doc CLI、監看來源、時鐘、log sink）。Corpus 的解析函式與 Schema 一律使用真實物件。

### 1.3 依賴方向與測試隔離

依 edit domain-map §2（Edit → Workspace、Schema、Corpus、Observability）：

- `test/unit/edit/` 可 import `lib/edit/`、`lib/workspace/`（僅工作區根路徑型別）、`lib/schema/`、`lib/corpus/`（僅公開解析函式與其結果型別）、`lib/observability/`
- 不得 import `lib/history/`、`lib/graph/`、`lib/diagnostics/`、`lib/layout/`、`lib/screens/`
- `lib/corpus/` 不得 import `lib/edit/`（domain-map §2「Corpus 不依賴本 domain」）。由 E-DEP-1 守衛
- 判準同 SPEC-007-test-design §1.3：`package:` 與相對路徑的 `import`、`export` 皆計入，差集為零

**E-DEP-1（守衛，靜態）**：掃描 `lib/corpus/` 全部 `.dart` 檔的 import 與 export，結果不得含 `lib/edit/` 的路徑。另以記憶體中含一行 `import 'package:…/edit/…'` 的樣本，驗證掃描函式會判紅（正向對照）。

### 1.4 共用測資

| helper | 路徑 | 用途 | 使用群組 |
|---|---|---|---|
| `FakeEditFilePort` | `test/helpers/spec009/fake_edit_file_port.dart` | 記憶體檔案集合；記錄操作序列；可設定「第 n 次讀取回傳指定位元組」「指定操作失敗並帶 `osError.errorCode`」「在指定操作完成後改動目標檔」 | G、R、V、X、C、L |
| `FakeEditGitPort` | `test/helpers/spec009/fake_edit_git_port.dart` | 依引數回應；以位元組回傳 stdout；記錄引數、標準輸入、環境變數；可設定拋出「無法啟動」 | G、S、L |
| `FakeValidatorPort` | `test/helpers/spec009/fake_validator_port.dart` | 依 CLI 名稱與目標回傳 `(結束碼, stdout)`；可設定「無法執行」與「永不完成」；記錄呼叫 | V、X、C、N |
| `frontmatterFixture` | `test/helpers/spec009/frontmatter_fixtures.dart` | §1.6 的文件位元組樣本 | G、R、V、L |
| `unregisteredUc`、`unregisteredUc2` | 同上 | 兩個不在 `docs/app-use-cases.md` 白名單中、彼此不同的 UC 編號，由承接票選定具體值。本文件以常數名指稱它們，不寫字面值，否則本文件自己會被 `doc uc verify` 判為違規（上游 tarrragon/claude#98：驗證器分不出提及與使用） | V、IT-E6 |
| `secretMarker` | 沿用 SPEC-010-test-design §1.4 | 字串 `SECRET-CONTENT-7f3a`，作為 C-2 正向對照的標記 | L、C |
| `RecordingEditLogSink` | `test/helpers/spec009/recording_edit_log_sink.dart` | 記錄每一筆事件，並提供序列化後的文字，供 C-2 斷言 | L、C |
| `fixedEditDate` | 同 `frontmatter_fixtures.dart` | `DateTime.utc(2026, 11, 10)`，`updated` 的預期值為 `2026-11-10` | R |
| fixture repo 建構器 | `integration_test/helpers/edit_fixture_repo.dart` | 依 §1.5 建立 repo 變體 | IT-E1～IT-E6 |

各群組只透過 helper 取得 fixture，不共享可變狀態；每個群組可以單獨執行。

### 1.5 fixture repo 建置規格

**共同設定**（每個變體都套用）：

| 項目 | 值 | 理由 |
|---|---|---|
| 位置 | 系統暫存目錄下新建的空目錄，測試結束刪除 | 不碰使用者的 repo |
| 使用者設定隔離 | 環境變數 `GIT_CONFIG_GLOBAL=/dev/null`、`GIT_CONFIG_NOSYSTEM=1`、`HOME=<暫存目錄>` | 本機的 `core.autocrlf`、`commit.gpgsign`、hooks 不得影響結果 |
| repo 層設定 | `user.name`、`user.email` 為固定值；`commit.gpgsign false`；`core.autocrlf false`（R4 另設） | commit 可重現 |
| 語系 | 建置時 `LC_ALL=C` | 建置過程的輸出可比對 |
| 基準文件 | `docs/spec/x/SPEC-900.md`，內容為 §1.6 的 `doc_plain` | 所有變體共用同一份起點 |

**變體**（「W ↔ H」欄是開始編輯當下的關係）：

| 變體 | 建置 | W ↔ H | 用於 |
|---|---|---|---|
| R0 乾淨 | 工作區根 = repo 根；commit 基準文件 | W = H | IT-E1-3、IT-E2-1 |
| R1 已追蹤且已改 | R0 之後改動 `title` 值，不 commit | W ≠ H | IT-E1-2、IT-E2-2 |
| R2 未追蹤檔 | R0 之後新增 `docs/spec/x/SPEC-901.md`，不 `git add` | H 不存在 | IT-E1-4 |
| R3 子目錄工作區 | repo 根為 `repo/`，工作區根為 `repo/proj/`；commit `proj/docs/spec/x/SPEC-900.md`。**對照檔**：另在 repo 根 commit `docs/spec/x/SPEC-900.md`，`title` 值不同 | W = H（以 `proj/` 為基準） | IT-E3 |
| R4 換行轉換 | `.gitattributes` 為 `*.md text eol=crlf` 並 commit；基準文件以 CRLF 位元組寫入、commit；之後改動一個值、仍為 CRLF，不 commit | W ≠ H | IT-E2-3 |
| R4b autocrlf | 同 R4，但不設 `.gitattributes`，改設 repo 層 `core.autocrlf true` | W ≠ H | IT-E2-3 |
| R5 symlink | 工作區根之外的同層目錄 `outside/` 內有 `a.md`。工作區內建 `docs/link.md` → `outside/a.md`（檔名 symlink），以及 `docs/linkdir` → `outside/`（父目錄 symlink） | — | IT-E4 |
| R6 非 git | 純目錄，含基準文件，不 `git init` | — | IT-E5-1 |
| R7 `git` 缺席 | 同 R0，但測試啟動 App 端 git 呼叫時注入不含 `git` 的 `PATH` | — | IT-E5-2 |
| R8 他人狀態 | R1 之上：另一檔 `docs/other.md` 已 `git add`（staged）；另有一筆 `git stash` 項目 | W ≠ H | IT-E2-2、IT-E6 |
| R9 尚無 commit | `git init` 後新增基準文件，不 commit（HEAD unborn） | H 無法判定 | IT-E1-5 |
| R10 權限 | R0 之上，基準文件 `chmod 0640` | W = H | IT-E2-4 |

**未追蹤檔**由 R2 涵蓋（FR-01 驗收第 2 條）。R9 的 `git show HEAD:./…` 回傳 128，但 stderr 指向 HEAD 本身而不是路徑，所以落入「H 無法判定」。R2 則落入「H 不存在」，兩者分支不同。兩者都走快照（FR-01 判準表第二列）。

### 1.6 文件位元組樣本（`frontmatter_fixtures.dart`）

| 名稱 | 內容要點 | 用途 |
|---|---|---|
| `doc_plain` | PROP 型 frontmatter：`id`、`title`（雙引號）、`status`、`priority`、`created`、`updated`、一行註解 `# note`、欄位間有非標準空白；內文兩段；結尾無換行 | 基準 |
| `doc_no_updated` | 同上，但不含 `updated` | R-4 |
| `doc_crlf` | `doc_plain` 的 CRLF 版本 | R-2、IT-E2-3 |
| `doc_anchor` | `title: &t "x"`，另一欄 `subtitle: *t` | R-5 |
| `doc_block_scalar` | `title: |` 與 `title: >` 兩個變體 | R-5 |
| `doc_uc_mention` | 內文含 `unregisteredUc` 兩次 | V-4、V-5 |
| `doc_nonutf8` | 內文含一個不是合法 UTF-8 的位元組 | G-6 |

## 2. 5a 外圈

外圈的測試檔都放在 `integration_test/`，fixture 依 §1.5 建立。

### 2.1 IT-E1 三種判定在真實 repo 上（FR-01）

**測試檔**：`integration_test/edit_gate_real_git_test.dart`

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E1-1 | R0；開始編輯後，以外部寫入改動目標檔 | 修正 `title` | `blocked(externallyModified)`；目標檔等於外部寫入的內容 | FR-01 #1（外部已改） |
| IT-E1-2 | R1 | 修正 `priority` | `written`，帶快照 SHA；`git cat-file -p <sha>` 等於開始編輯時的位元組 | FR-01 #1（需快照） |
| IT-E1-3 | R0 | 修正 `title` | `written`，不帶快照 SHA；以包裝 runner 記錄，全程沒有 `hash-object` 呼叫 | FR-01 #1（直接寫入） |
| IT-E1-4 | R2（目標為未追蹤的 SPEC-901） | 修正 `title` | `written`，帶快照 SHA | FR-01 #2 |
| IT-E1-5 | R9 | 修正 `title` | `written`，帶快照 SHA（H 無法判定也走快照） | FR-01 #2 |
| IT-E1-6 | R2；啟動環境設 `LANG=zh_TW.UTF-8`、`LC_MESSAGES=zh_TW.UTF-8` | 對未追蹤的 SPEC-901 修正 `title` | 以包裝 runner 記錄：每一次實際的 git 呼叫（`show`、`hash-object`）環境都含 `LC_ALL=C`；判定與 IT-E1-4 相同（比照 SPEC-008-test-design RG-4） | FR-01 約束（`LC_ALL=C`） |

### 2.2 IT-E2 快照與不動使用者狀態（FR-02、FR-03、FR-08）

**測試檔**：`integration_test/edit_snapshot_real_git_test.dart`

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E2-1 | R0 | 寫入前後各取一次 `git status --porcelain`、`git stash list`、`git reflog`、`git log --format=%H` | 四者逐字相同 | FR-02 #1；FR-08 #1 |
| IT-E2-2 | R8 | 同 IT-E2-1；另取 `git diff --cached --name-only` | 五者逐字相同（`docs/other.md` 仍在 index，stash 仍有一筆）。正向對照：寫入後 `git status --porcelain` 的工作區欄對目標檔仍為已修改，證明寫入確實發生 | FR-02 #1；FR-08 #1 |
| IT-E2-3 | R4、R4b 各跑一次 | 修正 `title`，取回快照 | `git cat-file -p <sha>` 逐位元組等於 W（含 CRLF）。**正向對照**：同一份 W 以 `git hash-object <路徑>`（帶路徑、會套用過濾的形式）計算的 SHA 與 `<sha>` 不同。這證明 fixture 確實觸發了換行轉換，綠燈不是因為轉換沒發生 | FR-02 #3 |
| IT-E2-4 | R10 | 修正 `title` | 寫入後目標檔權限仍為 `0640` | FR-03 #6 |

### 2.3 IT-E3 子目錄工作區（FR-01）

**測試檔**：同 IT-E1

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E3-1 | R3，工作區根 `repo/proj/` | 修正 `proj/` 下 SPEC-900 的 `title` | `written`，不帶快照 SHA（W = H）。若實作改以 repo 根解析 `HEAD:` 路徑，取到的會是對照檔，W ≠ H 而走快照，本案因此紅燈 | FR-01 #5 |
| IT-E3-2 | R3；開始編輯後改動 `proj/` 下的檔案但不 commit | 再開始編輯並修正 | `written`，帶快照 SHA；`git cat-file -p <sha>` 不等於對照檔內容 | FR-01 #5 |

### 2.4 IT-E4 symlink（FR-04）

**測試檔**：`integration_test/edit_path_symlink_test.dart`

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E4-1 | R5 | 以 `docs/link.md` 建構 `WorkspaceRelativePath` | 失敗；`outside/a.md` 內容不變 | FR-04 #2 |
| IT-E4-2 | R5 | 以 `docs/linkdir/a.md` 建構 | 失敗 | FR-04 #1 |
| IT-E4-3（正向對照） | R5 | 以 `docs/spec/x/SPEC-900.md` 建構並修正 `title` | 成功並 `written` | — |

### 2.5 IT-E5 唯讀降級（FR-01）

**測試檔**：`integration_test/edit_readonly_degrade_test.dart`

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E5-1 | R6 | 開啟工作區 | edit 狀態為唯讀降級；`beginEditing` 回傳唯讀結果；檔案修改時間與內容不變 | FR-01 #6 |
| IT-E5-2 | R7 | 開啟工作區 | 同 IT-E5-1 | FR-01 #6 |
| IT-E5-3（正向對照） | R0 | 開啟工作區 | 狀態為可寫 | — |

### 2.6 IT-E6 真實驗證器（FR-05，PROP-005 §1.0 整合測試）

**測試檔**：`integration_test/edit_validation_real_cli_test.dart`。需要 `uv` 與 doc CLI；找不到時以說明訊息判為失敗，不跳過（同 SPEC-010-test-design §6 對 fvm 的處置）。

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E6-1 | R0，基準文件為 UC 型，內文不含 UC 提及 | 修正 `primary_actor`，值含 `unregisteredUc2` | `written`；驗證狀態為 `failed`，新增問題數 1；目標檔內容含新值（未被改回） | FR-05 #2 |
| IT-E6-2 | R0，內文已含兩次未登記的 UC 提及 | 修正 `title`（不含 UC 提及） | 驗證狀態為 `passed` | FR-05 #3 |
| IT-E6-3（正向對照） | IT-E6-1 的 fixture | 修正 `title`（值不含 UC 提及） | 驗證狀態為 `passed`，證明 IT-E6-1 的 `failed` 來自新值 | — |

## 3. 5b 內圈：測試案例

### G 寫入前閘門（FR-01）

**測試檔**：`test/unit/edit/write_gate_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| G-1（守衛） | M = `doc_plain`；步驟 1 讀到的 W 改一個位元組 | 修正 `title` | `blocked(externallyModified)`；`FakeEditFilePort` 操作序列中沒有寫入與 rename；`FakeEditGitPort` 零呼叫（正向對照：G-3 同輸入但 W = M 時寫入） |
| G-2 | W = M；H 與 W 不同 | 修正 | 先快照再寫入：git 呼叫依序為 `show`、`hash-object`；`written` 帶 SHA |
| G-3 | W = M = H | 修正 | `written`、不帶 SHA；git 呼叫只有 `show`，沒有 `hash-object` |
| G-4 | W = M；`show` 回傳 128，stderr 為路徑不在 HEAD 的訊息 | 修正 | 走快照分支（H 不存在） |
| G-5 | W = M；`show` 回傳 128，stderr 為其他訊息；另一案回傳 1 | 修正 | 兩案都走快照分支（H 無法判定） |
| G-6 | W = M = `doc_nonutf8`；H 的 stdout 位元組與 W 相同 | 修正 | 判為 W = H，不快照（證明比較的是位元組，沒有經過字元解碼） |
| G-7（守衛） | W = M ≠ H；`hash-object` 回傳 128 | 修正 | `blocked(snapshotFailed)`；目標檔不變；沒有寫入暫存檔（正向對照：G-2） |
| G-8（守衛） | W = M = H；`FakeEditFilePort` 在暫存檔 fsync 完成後改動目標檔 | 修正 | `blocked(externallyModified)`；暫存檔已刪除；目標檔等於被改動後的內容（正向對照：G-3） |
| G-9 | 步驟 1 讀取時檔案不存在 | 修正 | `blocked(externallyModified)` |
| G-10 | 步驟 1 讀取失敗，`osError.errorCode` 13 | 修正 | `ioFailed` |
| G-11 | 步驟 5 重讀時檔案不存在 | 修正 | `blocked(externallyModified)`；暫存檔已刪除 |
| G-12 | 改寫隔離失敗（目標欄位為 anchor） | 修正 | `blocked(rewriteNotIsolated)`；git 零 `hash-object` 呼叫（步驟 2 先於步驟 3） |
| G-13 | `show` 引數 | 修正 | 引數恰為 `-C <工作區根> show HEAD:./<工作區相對路徑>` |
| G-14 | 開始編輯時讀取失敗 | `beginEditing` | 回傳讀取失敗結果；不產生編輯 session |
| G-15 | M 由 `beginEditing` 讀取；Corpus 的解析快照為較舊的內容 | 修正 | 以 `beginEditing` 讀到的位元組作 M：W 等於該位元組時不判為外部已改 |
| G-16（守衛） | 工作區開啟時 git 探測回報「不是 git repo」；另一案回報「無法啟動」 | 開啟工作區後呼叫 `beginEditing` | 兩案都是唯讀降級；`beginEditing` 回傳唯讀結果；`FakeEditFilePort` 零寫入（正向對照：探測回報為 repo 時可寫） |
| G-17 | 可寫工作區；編輯中 git 變為無法啟動；W = M ≠ H | 修正 | `blocked(snapshotFailed)`（寫入時不重判唯讀，也不放行） |
| G-18 | W = M ≠ H；工作區開啟時也做一次 git 探測 | 開啟工作區並修正 | `FakeEditGitPort` 記錄的每一次呼叫（探測、`show`、`hash-object`），環境都含 `LC_ALL=C` |

### S 快照（FR-02）

**測試檔**：`test/unit/edit/snapshot_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| S-1 | W ≠ H | 快照 | git 引數恰為 `hash-object -w --stdin`，不含 `--path` 與檔案路徑；標準輸入位元組逐位元組等於步驟 1 的 W |
| S-2 | `hash-object` 回傳 40 字元 SHA | 快照 | `written` 帶該 SHA |
| S-3（守衛） | `FakeEditGitPort` 對 `hash-object` 拋出無法啟動 | 修正 | `blocked(snapshotFailed)`；目標檔不變（正向對照：S-2） |
| S-4 | 有快照、無快照各一次寫入 | 取取回說明 | 有快照為 `git cat-file -p <sha> > <路徑>`；無快照為 `git checkout HEAD -- <路徑>`；兩者的路徑皆為工作區相對路徑 |
| S-5 | 快照 | 快照 | git 呼叫中沒有 `add`、`stash`、`update-ref`、`commit`、`reset`、`checkout` |

### R 局部改寫與原子寫入（FR-03）

**測試檔**：`test/unit/edit/field_rewrite_test.dart`（R-1～R-8）、`test/unit/edit/atomic_write_test.dart`（R-9～R-12）

| # | Given | When | Then |
|---|---|---|---|
| R-1 | `doc_plain`，`updated` 存在 | 修正 `title` 為新值 | 改寫後與改寫前相比，只有 `title` 值與 `updated` 值所在的位元組範圍不同；註解、引號、空白、欄位順序、內文、檔尾無換行都相同；`updated` 為 `2026-11-10` |
| R-2 | `doc_crlf` | 同 R-1 | 同 R-1；改寫後所有行尾仍為 CRLF |
| R-3 | `doc_plain` | 修正 `title` | `id`、`created`、`version` 的位元組不變 |
| R-4 | `doc_no_updated` | 修正 `title` | 改寫後仍無 `updated` 鍵 |
| R-5（守衛） | `doc_anchor`；`doc_block_scalar` 的兩個變體 | 修正 `title` | 三案都是 `blocked(rewriteNotIsolated)`；目標檔不變（正向對照：R-1） |
| R-6（守衛，隔離檢查函式） | 改寫前 `doc_plain`；改寫後另加一個鍵 `extra: 1` | 對兩份位元組呼叫隔離檢查，允許集合 {title, updated} | 解析層不通過（正向對照：只改 `title` 值時通過） |
| R-7（守衛，隔離檢查函式） | 改寫後只改了 `# note` 註解的一個字元，解析結果與改寫前相同 | 同 R-6 | 位元組層不通過（解析層通過）。證明兩道檢查缺一不可 |
| R-8 | `doc_plain` | 修正 `title` 為 `"x\nstatus: hacked"` | 結果為 `written` 時，以 `classifyFrontmatter` 解析：`status` 值不變，`title` 值逐字等於輸入字串；結果為 `blocked(rewriteNotIsolated)` 時，目標檔不變。兩者擇一，不得出現 `status` 改變 |
| R-9 | W = M = H | 修正 | `FakeEditFilePort` 操作序列為：寫暫存檔、fsync 暫存檔、讀目標檔（步驟 5）、rename；暫存檔與目標檔同目錄；檔名以 `.` 開頭、含行程 ID、不以 `.md` 結尾 |
| R-10（守衛） | rename 失敗 | 修正 | `ioFailed`；目標檔不變；同目錄無暫存檔（正向對照：R-9） |
| R-11 | 暫存檔寫入失敗；另一案 fsync 失敗 | 修正 | 兩案都是 `ioFailed`、目標檔不變、無殘留暫存檔 |
| R-12 | 原檔權限位元記錄為 `0640` | 修正 | 暫存檔在 rename 前已設為 `0640`（真實檔案系統上的驗證見 IT-E2-4） |

### P 路徑界內型別（FR-04）

**測試檔**：`test/unit/edit/workspace_relative_path_test.dart`（真實暫存目錄）；P-9 為 `test/edit_contract_test.dart`

工作區根為暫存目錄下的 `work/`，同層另建 `workspace/` 與 `outside/`。

| # | Given | When | Then |
|---|---|---|---|
| P-1 | `docs/spec/a.md`，父目錄存在、檔案存在 | 建構 | 成功 |
| P-2 | `docs/new.md`，父目錄存在、檔案不存在 | 建構 | 成功 |
| P-3（守衛） | `../outside/a.md`、`docs/../../outside/a.md` | 建構 | 皆失敗（正向對照：P-1） |
| P-4（守衛） | `./docs/a.md`、`docs/./a.md`、`docs//a.md`、含 NUL 的路徑 | 建構 | 皆失敗（正向對照：P-1） |
| P-5（守衛） | 絕對路徑 `<work>/docs/a.md` | 建構 | 失敗（即使在界內） |
| P-6（守衛） | 工作區根為 `work/`；`work` 下建 symlink `ws` → 同層的 `workspace/`，輸入 `ws/a.md` | 建構 | 失敗（解析後為 `workspace/a.md`，以「根加分隔符」為前綴比對時不在界內）。正向對照：根為 `workspace/` 時 `a.md` 成功 |
| P-7（守衛） | `docs/link.md` 為 symlink，指向 `work/docs/real.md`（界內） | 建構 | 失敗（檔名為 symlink 一律拒絕，即使目標在界內） |
| P-8 | 工作區根本身經過 symlink（例如以 `/tmp/...` 提供，實際為 `/private/tmp/...`） | 以 `docs/spec/a.md` 建構 | 成功（根與路徑以同一方式解析） |
| P-9（守衛，靜態） | fixture `test/fixtures/edit/path_type/negative.dart` 以 `String` 呼叫寫入函式；`positive.dart` 以 `WorkspaceRelativePath` 呼叫 | 對兩者各跑 `fvm dart analyze` | `negative.dart` 至少一個 error，位置在該呼叫行；`positive.dart` 零 error |
| P-10 | 工作區根所在磁碟區大小寫不敏感；`work/Docs/a.md` 存在；輸入 `docs/a.md` | 建構 | 依解析結果逐位元組比對，不做大小寫折疊：解析結果的前綴若不等於「根加分隔符」即失敗；不得以忽略大小寫的比較判為界內 |

`/work` 與 `/workspace` 的前綴案（FR-04 驗收第 3 條）由 P-6 涵蓋；父目錄 symlink 指向界外（驗收第 1 條）由 P-6 與 IT-E4-2 涵蓋。

### V 寫入結果、三個可觀測時刻與驗證狀態（FR-05）

**測試檔**：`test/unit/edit/write_result_test.dart`（V-1～V-3）、`test/unit/edit/validation_baseline_test.dart`（V-4～V-14）

`doc uc verify` 的 stdout 樣本形式為逐行 `<路徑>:<行號>:<UC 編號>`，結束碼 1 表示有違規（2026-11-10 以 doc CLI 實測取得）。`doc validate` 失敗輸出的樣本由承接票以真實 CLI 取得，並標註實測日期（test-assertion-design D5）。

| # | Given | When | Then |
|---|---|---|---|
| V-1 | W = M = H；驗證器設為永不完成 | 修正並觀測狀態序列 | 依序為「寫入進行中」、受理 `written`、驗證 `running`；三者可由型別區分 |
| V-2 | W ≠ M | 修正並觀測 | 只有受理 `blocked(externallyModified)`；沒有「寫入進行中」，也沒有驗證狀態 |
| V-3 | `blocked`、`ioFailed`、`written` 三種結果 | 以窮舉 switch 讀取 | 型別為封閉型別；`blocked` 攜帶三種原因之一 |
| V-4 | baseline：`uc verify` 回報 `unregisteredUc` 兩次 | 寫入後回報 `unregisteredUc` 兩次 | `passed` |
| V-5（守衛） | baseline 同 V-4 | 寫入後回報 `unregisteredUc` 三次 | `failed`，新增問題數 1（正向對照：V-4） |
| V-6 | baseline 同 V-4，行號 4 | 寫入後回報同樣的兩次，行號變為 5 | `passed`（比對鍵不含行號） |
| V-7 | baseline 結束碼 2 | 寫入後結束碼 2 | 不判 `failed` |
| V-8（守衛） | baseline 結束碼 0 | 寫入後結束碼 2 | `failed`（正向對照：V-7） |
| V-9 | baseline 為 `unavailable`（`uv` 無法執行） | 寫入兩次，第二次時驗證器已可執行 | 兩次都是 `unavailable` |
| V-10 | 驗證器結束碼 3；另一案 stdout 無法解析 | 寫入後驗證 | 兩案都是 `unavailable`，不是 `passed` |
| V-11 | 寫入一次後驗證回報 `unregisteredUc` 一次 | 第二次寫入後也回報一次 | 第二次為 `passed`（第一次寫入後的結果成為新 baseline） |
| V-12 | V-5 的情境 | 驗證判為 `failed` 之後 | `FakeEditFilePort` 在驗證開始後沒有任何寫入與 rename（不回滾） |
| V-13 | 修正 SPEC-900 | 驗證 | 驗證器呼叫恰為 `doc validate SPEC-900` 與 `doc uc verify <該檔路徑>`；沒有不帶目標的全專案呼叫 |
| V-14 | baseline 結束碼 1，`unregisteredUc` 一次 | 寫入後結束碼 0 | `passed` |

FR-05 驗收第 1 條由 V-1～V-3 涵蓋；第 2 條由 V-5、V-12 與 IT-E6-1 涵蓋；第 3 條由 V-4 與 IT-E6-2 涵蓋；第 4 條由 V-6 涵蓋；第 5 條由 V-7、V-8 涵蓋；第 6 條由 V-9、V-10 涵蓋。

### X 外部改動的發現時點（FR-06）

**測試檔**：`test/unit/edit/external_change_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| X-1 | 編輯 SPEC-900 中，有未寫入值 | 監看來源送出 SPEC-900 已改的事件 | 編輯狀態轉為外部已改預警；未寫入值仍保留 |
| X-2（對照） | 同 X-1 | 監看來源送出其他檔案已改的事件 | 編輯狀態不變 |
| X-3 | X-1 之後；磁碟內容確實已變 | 修正 | `blocked(externallyModified)`（預警不阻擋嘗試，判定仍由閘門） |
| X-4 | X-1 之後；事件為誤報，磁碟內容與 M 相同 | 修正 | `written` |
| X-5 | 外部改動磁碟內容，但不送任何監看事件 | 修正 | `blocked(externallyModified)` |
| X-6 | X-1 之後 | `discardAndReload` | M 為新的磁碟內容；驗證器再次以該檔被呼叫（重跑 baseline）；之後修正可 `written` |
| X-7 | X-1 | 預警期間 | 沒有對使用者呈現焦點通道發出請求（記錄用仲裁器零請求） |

### L 日誌事件與只記識別（FR-07）

**測試檔**：`test/unit/edit/edit_log_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| L-1 | `EditLogEvent` 的全部值 | 列出值名稱 | 集合恰為 SPEC-009 FR-07 表的 8 個事件；表增減成員時本案紅燈 |
| L-2 | W = M = H | 修正 | 依序記 `writeIssued`、`writeAccepted`，皆 info、無 `error_source`，fields 為路徑與欄位名 |
| L-3 | W ≠ H | 修正 | 另記 `snapshotTaken`（info），`blob_sha` 為 40 字元小寫十六進位 |
| L-4 | 外部已改；改寫不隔離 | 修正 | 各記一筆 `writeBlocked`，warning、`gate_blocked`，fields 帶原因 |
| L-5 | `hash-object` 回傳 128；另一案無法啟動 | 修正 | 各記一筆 `writeBlocked`，error、`external_process`；前者帶結束碼 128、不帶 `executableMissing`，後者相反（恰二擇一）；沒有另外的失敗事件（一次失敗一筆） |
| L-6 | 讀取失敗、寫入失敗各一，`osError.errorCode` 13 | 修正 | `readIoFailed` 或 `writeIoFailed`，error、`platform_io`，帶 errorCode 13 |
| L-7 | 寫入失敗且 `osError` 為 null | 修正 | `writeIoFailed` 不含 errorCode 欄位 |
| L-8 | 驗證為 `passed`、`failed`（新增 1）、`unavailable`（結束碼 3） | 驗證完成 | `validationCompleted`：`passed` 為 info；`failed` 為 warning、無 `error_source`、帶新增問題數；`unavailable` 為 warning、`external_process`、帶結束碼 |
| L-9（守衛，C-2） | 欄位新值含 `secretMarker`；依序讓寫入以 `externallyModified`、`rewriteNotIsolated`、`snapshotFailed`、`ioFailed` 失敗 | 每案修正 | `RecordingEditLogSink` 的序列化文字、`WriteResult` 的 `toString()`、`blocked` 原因與 IO 失敗分類的 `toString()`，都不含 `secretMarker`。**正向對照**：同一新值寫入成功時，`FakeEditFilePort` 中目標檔內容含 `secretMarker`，證明標記確實送進了寫入層 |
| L-10（守衛，C-2） | 讀取失敗的例外訊息含 `secretMarker` | 修正 | 日誌序列化文字與 `ioFailed` 的 `toString()` 不含標記 |

FR-07 驗收第 1 條「每個帶 `error_source` 的事件在上表寫明分類」由 L-1 把事件集合與規格表綁住，L-4～L-8 逐一驗證分類。驗收第 2 條由 L-9、L-10 涵蓋。

### C session 寫入清單與事後追溯（FR-08）

**測試檔**：`test/unit/edit/session_write_list_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| C-1 | 兩次寫入：SPEC-900 的 `title`、PROP-900 的 `priority` | 讀取 session 寫入清單 | 兩列，每列含路徑、欄位名、節點 ID、驗證狀態；有快照者帶快照 SHA |
| C-2（守衛，C-2） | 寫入值含 `secretMarker` | 讀取清單並序列化 | 不含 `secretMarker`（正向對照：L-9 的正向對照） |
| C-3 | 修正 SPEC-900，驗證器設為延後完成；之後對 PROP-900 開始編輯 | SPEC-900 的驗證以 `failed` 完成 | 清單中 SPEC-900 那一列的狀態由 `running` 變為 `failed`；PROP-900 的編輯 session 不受影響 |
| C-4 | W ≠ H 的寫入一次、W = H 的寫入一次 | 讀日誌 | 前者有 `snapshotTaken`，且其 `blob_sha` 等於清單該列的 SHA；後者沒有（正向對照） |
| C-5 | 任一次寫入 | 寫入 | `FakeEditGitPort` 沒有 `commit`、`add`、`stash` 呼叫 |

FR-08 驗收第 1 條由 C-5 與 IT-E2-1、IT-E2-2 涵蓋；第 2 條由 C-2 與 L-9 涵蓋；第 3 條由 C-3 涵蓋；第 4 條由 C-4 涵蓋。

### F 逐欄位輸入元件（FR-09）

**測試檔**：`test/unit/screens/edit/field_input_mapping_test.dart`（落點以畫面票為準）

| # | Given | When | Then |
|---|---|---|---|
| F-1 | FR-09 兩張表中「自」為 1.0 的每一列 | 以（節點型別、欄位）查對照函式 | 回傳該列的「現行元件」；全部列逐一列舉，表增減時本案紅燈 |
| F-2（守衛） | 值域來源 fake 對 SPEC `status` 回傳「無機器定義」 | 查對照 | 單行文字（正向對照：對 PROP `status` 回傳機器定義的列舉時為下拉） |
| F-3（守衛） | 值域來源 fake 對所有欄位都回傳「無機器定義」 | 查全部 1.0 欄位 | 沒有任何欄位為下拉或單選鈕組。這證明 App 沒有內建值域表：若有，值域來源回傳「無」時仍會產生下拉 |
| F-4 | 「自」為 1.1 以後或為 `—` 的欄位 | 查對照 | 回傳「不可編輯」 |

### N 寫入不阻擋操作（NFR-01）

**測試檔**：`test/unit/edit/non_blocking_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| N-1 | 驗證器永不完成 | 修正 | `WriteResult` 在驗證完成前即可取得 |
| N-2 | N-1 之後，驗證仍為 `running` | 對同一檔的另一欄位修正 | 可受理並 `written`；不等待前一次驗證 |

NFR-01 的指標「寫入受理延遲」以量測填入規格，不作為 pass／fail 斷言（test-assertion-design D1）。量測腳本放 `integration_test/perf/edit_write_latency.dart`，對 R0 與 R1 各寫入 20 次，輸出中位數與最大值，由承接票記入 SPEC-009 NFR-01。

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 5a | 5b |
|----|----|----|
| FR-01 | IT-E1、IT-E3、IT-E5 | G |
| FR-02 | IT-E1-2、IT-E2 | S；G-7 |
| FR-03 | IT-E2-4 | R |
| FR-04 | IT-E4 | P |
| FR-05 | IT-E6 | V |
| FR-06 | — | X |
| FR-07 | — | L |
| FR-08 | IT-E2-1、IT-E2-2 | C |
| FR-09 | — | F |
| NFR-01 | 量測（不斷言） | N |

### 4.2 驗收條件 ↔ 案例

| FR | 驗收 | 案例 | 測試層 |
|---|---|---|---|
| FR-01 | #1 三種判定各有 fixture repo 驗證 | IT-E1-1～IT-E1-3；G-1～G-3 | integration；domain unit |
| FR-01 | #2 未追蹤與 H 無法判定落入快照 | IT-E1-4、IT-E1-5；G-4、G-5 | integration；domain unit |
| FR-01 | #3 快照失敗時目標檔不變、`snapshotFailed` | G-7、S-3 | domain unit |
| FR-01 | #4 步驟 4 後、6 前改動 → `externallyModified`、暫存檔已刪 | G-8 | domain unit |
| FR-01 | #5 子目錄工作區 H 正確 | IT-E3；G-13 | integration；domain unit |
| FR-01 | #6 非 git、`git` 無法執行時無寫入路徑可達 | IT-E5；G-16 | integration；domain unit |
| FR-01 | 約束：git 呼叫設 `LC_ALL=C`（v1.1，非驗收條目） | IT-E1-6；G-18 | integration；domain unit |
| FR-02 | #1 status、stash、reflog 不變 | IT-E2-1、IT-E2-2；S-5 | integration；domain unit |
| FR-02 | #2 寫入結果帶 SHA，取回逐位元組等於 W | IT-E1-2；S-1、S-2 | integration；domain unit |
| FR-02 | #3 `.gitattributes` 換行轉換下取回仍等於 W | IT-E2-3 | integration |
| FR-02 | #4 `git` 無法執行 → `snapshotFailed` | S-3 | domain unit |
| FR-03 | #1 中途中斷後目標檔不變、無暫存檔 | R-10、R-11 | domain unit |
| FR-03 | #2 只有該值與 `updated` 不同 | R-1、R-2、R-3 | domain unit |
| FR-03 | #3 `updated` 缺席時改寫後仍無 | R-4 | domain unit |
| FR-03 | #4 anchor、alias、block scalar → `rewriteNotIsolated` | R-5；G-12 | domain unit |
| FR-03 | #5 解析結果多變一欄 → `rewriteNotIsolated` | R-6、R-8 | domain unit |
| FR-03 | #6 權限位元不變 | IT-E2-4；R-12 | integration；domain unit |
| FR-04 | #1 穿越、`.`、空段、NUL、絕對、父目錄 symlink | P-3～P-6；IT-E4-2 | domain unit；integration |
| FR-04 | #2 檔名 symlink | P-7；IT-E4-1 | domain unit；integration |
| FR-04 | #3 `/work` 與 `/workspace` | P-6 | domain unit |
| FR-04 | #4 目標不存在、父目錄存在可建構 | P-2 | domain unit |
| FR-04 | #5 寫入函式不收 `String` | P-9 | 契約（靜態） |
| FR-05 | #1～#6 | 見 V 群組末段 | domain unit；integration |
| FR-06 | #1 監看事件 → 外部已改預警 | X-1、X-2 | domain unit（application 層） |
| FR-06 | #2 無監看事件仍判 `externallyModified` | X-5 | domain unit |
| FR-07 | #1、#2 | 見 L 群組末段 | domain unit |
| FR-08 | #1～#4 | 見 C 群組末段 | domain unit；integration |
| FR-09 | #1 1.0 欄位都有元件與值域來源 | F-1 | 畫面狀態層 unit |
| FR-09 | #2 無機器定義的列舉以單行呈現 | F-2、F-3 | 畫面狀態層 unit |
| NFR-01 | 驗證不阻擋下一次編輯 | N-1、N-2 | domain unit |

### 4.3 守衛類驗收的正向對照

| 守衛 | 應被擋下的輸入 | 案例 | 對照（應通過的輸入） |
|---|---|---|---|
| 閘門：外部已改 | 步驟 1 的 W 與 M 差一個位元組 | G-1、IT-E1-1 | G-3 |
| 閘門：外部已改（rename 前重比） | fsync 後才改動目標檔 | G-8 | G-3 |
| 閘門：需快照而快照失敗 | `hash-object` 回傳 128 或無法啟動 | G-7、S-3 | G-2 |
| 閘門：唯讀降級 | 非 git、`git` 無法啟動 | G-16、IT-E5-1、IT-E5-2 | IT-E5-3 |
| 改寫隔離：解析層 | 改寫後多一個鍵 | R-6 | R-6 的對照、R-1 |
| 改寫隔離：位元組層 | 只改註解、解析結果相同 | R-7 | R-1 |
| 改寫隔離：不支援的節點 | anchor、alias、block scalar | R-5 | R-1 |
| 改寫隔離：值注入 | `"x\nstatus: hacked"` | R-8 | R-1 |
| 路徑界內 | 穿越、`.`、空段、NUL、絕對、前綴相同的兄弟目錄、檔名 symlink | P-3～P-7、IT-E4-1、IT-E4-2 | P-1、P-2、IT-E4-3 |
| 路徑型別（編譯期） | 以 `String` 呼叫寫入函式 | P-9 negative | P-9 positive |
| C-2 | 欄位值與例外訊息中的標記字串 | L-9、L-10、C-2 | L-9 的正向對照 |
| 驗證：新增問題 | 寫入後多一次提及；結束碼由非 2 變為 2 | V-5、V-8 | V-4、V-7 |
| 值域不內建 | 值域來源全部回傳「無」 | F-3 | F-2 的對照 |
| 依賴方向 | `lib/corpus/` import `lib/edit/` | E-DEP-1 | E-DEP-1 的樣本 |
| 換行轉換 fixture 有效 | 帶路徑的 `hash-object` 算出不同 SHA | IT-E2-3 的正向對照 | — |
| 子目錄工作區 fixture 有效 | repo 根的同名對照檔 | IT-E3-1 | — |

### 4.4 不變式 ↔ 測試（edit domain-map §3〈Bundle 不變式清單〉）

| 不變式（摘要） | 測試 |
|---|---|
| W ≠ M 時不寫入，回傳外部已改 | G-1 |
| rename 前的重讀與 W 不同時不寫入，刪除暫存檔 | G-8 |
| W = M 且 W ≠ H（含未追蹤）時先快照成功才寫入；快照失敗回傳阻擋 | G-2、G-7 |
| W = M = H 時直接寫入，不呼叫快照 | G-3 |
| 寫入函式只接受 `WorkspaceRelativePath`；工作區外路徑無法建構 | P-9、P-3 |
| 寫入中途失敗時目標檔維持寫入前內容 | R-10 |
| 只改目標欄位與已存在的 `updated`；`updated` 缺席時不新增 | R-1、R-4 |
| 改寫後經 Corpus 解析，允許集合以外的鍵有變動時不寫入 | R-6 |
| 驗證失敗不改動已寫入的檔案 | V-12 |
| 只有寫入後問題集合減去 baseline 非空時才判失敗 | V-4、V-5 |
| 寫入前後 index、refs、stash 不變；App 不建立 commit | C-5、IT-E2-2 |
| 錯誤型別與日誌欄位不含欄位值與檔案內容 | L-9 |

不變式共 12 條，每條至少一個 domain unit 案例。其中兩條另有外圈案例（C-5 對 IT-E2-2、P-9 對 P-3），外圈負責真實 git 上的確認，內圈負責定位。

## 5. 案例群組 ↔ 實作範圍

本文件定稿時（2026-11-10），edit domain 的實作票尚未建立。下表是建議的切分，供建票時對照；每一列可作為一張實作票的測試範圍。

| 建議範圍 | 案例 | 前置 |
|---|---|---|
| 路徑型別 | P、IT-E4 | 無 |
| 局部改寫與隔離檢查 | R-1～R-8 | Corpus 公開 `classifyFrontmatter`（已存在） |
| 閘門、快照、原子寫入 | G、S、R-9～R-12、IT-E1、IT-E2、IT-E3、IT-E5、E-DEP-1 | 路徑型別；局部改寫；edit 的 git port（§6 第 2 項） |
| 驗證器與 baseline | V、N、IT-E6 | 閘門 |
| 日誌事件 | L | 閘門；SPEC-010 的 writer 與 `LogSink<E>`（`1.0.0-W3-553.2.2`、`.2.3`） |
| 外部改動預警與 session 清單 | X、C | 閘門；驗證器；553.3 的編輯狀態定義 |
| 欄位輸入元件對照 | F | 553.3；表單元件的元件契約（SPEC-004） |

## 6. 待決與交接

1. **H 判定對語系的依賴（已補入 SPEC-009 v1.1）**：FR-01 以「結束碼 128 且 stderr 指出路徑不在 HEAD 中」區分「H 不存在」與「H 無法判定」，而 git 的 stderr 會依 `LANG`／`LC_MESSAGES` 翻譯。本文件審查時發現 v1.0 缺這一條，主控裁定補入：v1.1 規定 App 發出的 git 呼叫一律設 `LC_ALL=C`，比照 SPEC-008 FR-01 規則 1。IT-E1-6 據此斷言環境變數已設定；內圈另由 G-18 斷言。
2. **edit 的 git port 不能直接沿用 History 的 `GitProcessRunner`**：一是依賴方向，Edit 不依賴 History（edit domain-map §2）；二是型別，`GitCommandResult.stdout` 為 `String`，而 SPEC-009 要求 H 的 stdout 以位元組讀取、快照以標準輸入餵入位元組，現有介面兩者都不支援。本文件的 `FakeEditGitPort` 以位元組介面描述。是否把 git 程序 port 抽到共用層，由閘門實作票決定，本文件不代為決定。
3. **`doc validate` 失敗輸出的樣本**：V 群組的 `doc validate` 測資須由承接票以真實 CLI 取得並標註實測日期（D5）。`doc uc verify` 的樣本形式已於 2026-11-10 實測（§3 V 群組首段）。
4. **畫面錨點**：X、C、F 只斷言畫面狀態層的狀態值。編輯狀態、外部已改預警、session 寫入清單、快照回饋與取回說明的 widget 錨點案例，由 `1.0.0-W3-553.3` 定稿後的畫面票補上，並回填本文件 §4.2 的測試層欄。
5. **IT-E6 與 P-9 的環境需求**：IT-E6 需要 `uv` 與 doc CLI，P-9 需要 fvm。找不到時以說明訊息判為失敗，不跳過，不改呼叫 PATH 上的其他版本（CLAUDE.md §6）。
6. **「備份」一詞的文案約束**（FR-02 約束第 2 條）不是驗收條件，本文件不設自動測試；由寫 l10n 文案的畫面票在審查時核對。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 0.1 | 2026-11-10 | 初稿（1.0.0-W3-553.4），對應 SPEC-009 v1.1：IT-E1-6 改為斷言 `LC_ALL=C`，新增 G-18 |
