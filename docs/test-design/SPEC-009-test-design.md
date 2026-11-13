---
id: SPEC-009-test-design
title: "SPEC-009 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-009
spec_version: "1.13"
ticket: 1.0.0-W3-553.4
created: "2026-11-10"
updated: "2026-11-13"
---

# SPEC-009 Phase 2 紅燈測試規格

本文件是 SPEC-009（編輯能力：寫入路徑、寫入前閘門與寫入結果）的紅燈測試規格，初稿對應 v1.1，0.2 版補上 v1.3 的 FR-01〈M 的更新〉與 FR-06 觸發來源；同版併入 v1.2 的逾時規定；0.3 版補上 v1.4 的 FR-03〈清空〉與 FR-09〈可否清空〉，對應 version-bootstrap Step 5 的 edit 部分，供 edit domain 的實作票以 TDD 開工。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-009；本文件與其衝突時以 SPEC-009 為準，衝突本身記入承接票的 NeedsContext。

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
| 外部改動預警（FR-06） | domain unit（application 層，Riverpod `ProviderContainer`） | 觸發來源為 EVT-CORPUS-001（SPEC-009 v1.3）：以 `FakeCorpusParsedSource` 送出「一輪解析完成」，不經監看來源；重讀以 `FakeEditFilePort` 回應。不沿用 `fake_watch_source.dart`：Edit 不消費監看事件與 EVT-CORPUS-002 |
| 日誌事件（FR-07） | domain unit | 注入記錄用 `LogSink<EditLogEvent>`（沿用 SPEC-010 的 sink 契約），斷言事件碼、等級、`error_source`、fields |
| session 寫入清單（FR-08） | domain unit（application 層） | 同 FR-06 |
| 欄位 → 輸入元件對照（FR-09） | 畫面狀態層 unit（對照函式）；widget 待 553.3 | 值域來源以 fake 注入 |
| 寫入函式只收路徑型別（FR-04） | 契約（靜態守衛，放 `test/` 根目錄，比照 `entitlements_contract_test.dart`） | 不 mock：對 fixture 跑 `fvm dart analyze` |
| IT-E1～IT-E6 | integration（`integration_test/`） | 不 mock git、檔案系統與 doc CLI：在暫存目錄依 §1.5 建 fixture repo |

Mock 只替換外部世界（檔案系統、git、doc CLI、Corpus 的解析完成通知、時鐘、log sink）。Corpus 的解析函式與 Schema 一律使用真實物件。

### 1.3 依賴方向與測試隔離

依 edit domain-map §2（Edit → Workspace、Schema、Corpus、Observability）：

- `test/unit/edit/` 可 import `lib/edit/`、`lib/workspace/`（僅工作區根路徑型別）、`lib/schema/`、`lib/corpus/`（僅公開解析函式與其結果型別）、`lib/observability/`
- 不得 import `lib/history/`、`lib/graph/`、`lib/diagnostics/`、`lib/layout/`、`lib/screens/`
- `lib/corpus/` 不得 import `lib/edit/`（domain-map §2「Corpus 不依賴本 domain」）。由 E-DEP-1 守衛
- 判準同 SPEC-007-test-design §1.3：`package:` 與相對路徑的 `import`、`export` 皆計入，差集為零

**E-DEP-1（守衛，靜態）**：掃描 `lib/corpus/` 全部 `.dart` 檔的 import 與 export，結果不得含 `lib/edit/` 的路徑。另以記憶體中含一行 `import 'package:…/edit/…'` 的樣本，驗證掃描函式會判紅（正向對照）。

**E-DEP-2（守衛，靜態，1.1）**：掃描 `lib/edit/` 全部 `.dart` 檔的 import 與 export，結果不得含 `lib/graph/`、`lib/history/` 的路徑（多檔寫入以 id 找反向檔時讀 Corpus 原始節點，不讀 Graph，edit domain-map §3）。正向對照：記憶體中含一行 `import 'package:…/graph/…'` 的樣本判紅，另一個含 `import 'package:…/history/…'` 的樣本也判紅。

### 1.4 共用測資

| helper | 路徑 | 用途 | 使用群組 |
|---|---|---|---|
| `FakeEditFilePort` | `test/helpers/spec009/fake_edit_file_port.dart` | 記憶體檔案集合；記錄操作序列；可設定「第 n 次讀取回傳指定位元組」「指定操作失敗並帶 `osError.errorCode`」「在指定操作完成後改動目標檔」 | G、R、V、X、C、L |
| `FakeEditGitPort` | `test/helpers/spec009/fake_edit_git_port.dart` | 依引數回應；以位元組回傳 stdout；記錄引數、標準輸入、環境變數；可設定拋出「無法啟動」；可設定「永不完成」並記錄子行程被終止 | G、S、L |
| `FakeCorpusParsedSource` | `test/helpers/spec009/fake_corpus_parsed_source.dart` | 送出 EVT-CORPUS-001 到達的通知，負載可為空的 `CorpusScanResult`，或刻意不含正在編輯的檔案；Edit 不讀負載，只以此為重讀時機（SPEC-009 FR-06） | X |
| `FakeValidatorPort` | `test/helpers/spec009/fake_validator_port.dart` | 依 CLI 名稱與目標回傳 `(結束碼, stdout)`；可設定「無法執行」、「永不完成」與「於指定虛擬時間完成」；記錄呼叫與子行程被終止 | V、X、C、N |
| `frontmatterFixture` | `test/helpers/spec009/frontmatter_fixtures.dart` | §1.6 的文件位元組樣本 | G、R、V、L |
| `unregisteredUc`、`unregisteredUc2` | 同上 | 兩個不在 `docs/app-use-cases.md` 白名單中、彼此不同的 UC 編號，由承接票選定具體值。本文件以常數名指稱它們，不寫字面值，否則本文件自己會被 `doc uc verify` 判為違規（上游 tarrragon/claude#98：驗證器分不出提及與使用） | V、IT-E6 |
| `secretMarker` | 沿用 SPEC-010-test-design §1.4 | 字串 `SECRET-CONTENT-7f3a`，作為 C-2 正向對照的標記 | L、C |
| `RecordingEditLogSink` | `test/helpers/spec009/recording_edit_log_sink.dart` | 記錄每一筆事件，並提供序列化後的文字，供 C-2 斷言 | L、C |
| 逾時計時器 | 由實作票決定注入方式（例：Edit 建構時注入的計時器工廠） | 以虛擬時間觸發 git 子行程 5 秒、驗證子行程 30 秒的逾時；測試不以真實時間等待。本文件只要求：逾時值由測試可推進的時間來源判定，而不是 `Future.timeout` 綁真實時鐘 | G、S、V、L |
| `fixedEditDate` | 同 `frontmatter_fixtures.dart` | `DateTime.utc(2026, 11, 10)`，`updated` 的預期值為 `2026-11-10` | R |
| fixture repo 建構器 | `integration_test/helpers/edit_fixture_repo.dart` | 依 §1.5 建立 repo 變體 | IT-E1～IT-E7 |
| `FakeCorpusNodeIndex`（1.1） | `test/helpers/spec009/fake_corpus_node_index.dart` | 以節點 id 回傳 Corpus 原始節點的工作區相對路徑，或「查不到」；替代 Corpus 公開面的原始節點查詢（SPEC-009 v1.8 〈寫入集合〉、edit domain-map §3）。不提供 Graph 的任何型別 | M、W、C |
| `FakeEditFilePort` 的多檔注入（1.1） | 同 `FakeEditFilePort` | 在既有能力上加：以「（路徑, 操作種類, 第 n 次）」指定失敗，操作種類含步驟 1 讀取、寫暫存檔、fsync、步驟 5 重讀、`rename`、還原用的寫暫存檔、還原時的 fsync 與還原 `rename`；可在指定操作完成後改動指定路徑的檔案；操作序列記錄帶路徑 | W、L、C |
| `provenanceFixture`（1.1） | `test/helpers/spec009/provenance_fixtures.dart` | §1.6.1 的正向檔與反向檔位元組樣本 | M、W、L、C、V |

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
| R11 provenance（1.1） | R0 之上，另 commit `docs/proposals/PROP-900-a.md`（`outputs.spec_refs: [SPEC-900]`、`outputs.design_refs: [SPEC-900]`）與 `docs/proposals/PROP-901-b.md`（`outputs.spec_refs: []`）；SPEC-900 的 `source_proposal: PROP-900`。PROP-900 權限 `0640` | W = H（三個檔） | IT-E7 |
| R11b provenance 已改（1.1） | R11 之上，PROP-901 的 `title` 改動、不 commit；另有一檔 `docs/other.md` 已 staged 與一筆 stash | PROP-901：W ≠ H | IT-E7-2 |

**未追蹤檔**由 R2 涵蓋（FR-01 驗收第 2 條）。R9 的 `git show HEAD:./…` 回傳 128，但 stderr 指向 HEAD 本身而不是路徑，所以落入「H 無法判定」。R2 則落入「H 不存在」，兩者分支不同。兩者都走快照（FR-01 判準表第二列）。

### 1.6 文件位元組樣本（`frontmatter_fixtures.dart`）

| 名稱 | 內容要點 | 用途 |
|---|---|---|
| `doc_plain` | PROP 型 frontmatter：`id`、`title`（雙引號）、`status`、`priority`、`target_version: "1.0.0"`（0.3 新增）、`created`、`updated`、一行註解 `# note`、欄位間有非標準空白；內文兩段；結尾無換行 | 基準；R-13 |
| `doc_no_updated` | 同上，但不含 `updated` | R-4 |
| `doc_crlf` | `doc_plain` 的 CRLF 版本 | R-2、IT-E2-3 |
| `doc_anchor` | `title: &t "x"`，另一欄 `subtitle: *t` | R-5 |
| `doc_block_scalar` | `title: |` 與 `title: >` 兩個變體 | R-5 |
| `doc_uc_mention` | 內文含 `unregisteredUc` 兩次 | V-4、V-5 |
| `doc_nonutf8` | 內文含一個不是合法 UTF-8 的位元組 | G-6、G-24 |

#### 1.6.1 provenance 與多值欄位樣本（1.1，`provenance_fixtures.dart`）

正向檔皆以 SPEC-900 為基礎（UC、EVT 變體另以 `UC-900`、`EVT-900` 為 id，欄位相同）。反向檔皆為 PROP，含 `updated`（`prop_no_updated` 除外）與一個不在任何寫入集合內的子鍵 `ticket_refs: [T-1]`，作為「其他子鍵逐位元組不變」的觀察點。

| 名稱 | 內容要點 | 用途 |
|---|---|---|
| `spec_sp_null` | `source_proposal: null` | M-6、W-3b、W-6、W-7、W-8、W-10～W-12、W-14、W-17、W-20～W-28 |
| `spec_sp_scalar` | `source_proposal: PROP-A` | M-5、M-8、M-12b、W-1、W-5、W-8、W-9、W-12、W-15、W-16、W-19、V-22、L-16、C-8 |
| `spec_sp_flow` | `source_proposal: [PROP-C, PROP-A]` | 備用（M-7、W-1 的 Given 另寫明其值，不引用本樣本） |
| `spec_sp_dup` | `source_proposal: [PROP-C, PROP-A, PROP-A]` | M-9 |
| `spec_related_flow` | `related_specs: [SPEC-1, SPEC-2, SPEC-3]` | M-1、M-2 |
| `spec_related_empty` | `related_specs: []` | M-3 |
| `spec_related_dup` | `related_specs: [SPEC-1, SPEC-2, SPEC-2]` | M-9 |
| `spec_unsupported` | `related_specs` 分別為 block 序列、跨兩行的 flow 序列、flow 序列內含註解、anchor、alias、項為巢狀清單、項為 map，共七個變體 | M-10 |
| `prop_std` | `outputs: {spec_refs: [SPEC-1, SPEC-900], usecase_refs: [UC-1], event_refs: [EVT-1], ticket_refs: [T-1]}`（以 block map 寫，各子鍵值為 flow 序列） | W-1、W-2、W-15、W-16 的基底、W-18、W-19、L-16 |
| `prop_empty_refs` | 同 `prop_std`，但 `spec_refs: []`、`usecase_refs: []`、`event_refs: []` | W-1（加入端）、W-2、W-4、W-7 對照、W-13、W-17、W-20～W-28、V-22、C-8 |
| `prop_design` | `spec_refs: [SPEC-900]`、`design_refs: [SPEC-900]` | W-5、M 群組加入案 |
| `prop_design_only` | `spec_refs: []`、`design_refs: [SPEC-900]` | W-6 |
| `prop_dup` | `spec_refs: [SPEC-900, SPEC-1, SPEC-900]` | W-15 |
| `prop_scalar_subkey` | `spec_refs: [SPEC-900]`、`ticket_refs: SPEC-900`（純量子鍵） | W-16 |
| `prop_missing_key` | 以 `prop_empty_refs` 為底，三個變體各缺一個子鍵：缺 `usecase_refs`（`spec_refs: []` 保留）、缺 `event_refs`、缺 `spec_refs` | W-3、W-4、W-3b |
| `prop_shape` | `spec_refs` 分別為 `null`、純量 `SPEC-X`、純量 `SPEC-900`、block 序列含 `SPEC-900`、block 序列不含 `SPEC-900` | W-7～W-11 |
| `prop_outputs_nonmap` | `outputs` 分別為 `[SPEC-900]`、`[SPEC-1]`、`SPEC-900`、`null`、缺鍵、`3`、`true` | W-12 |
| `prop_no_updated` | 同 `prop_empty_refs`，但無 `updated` | W-17 |

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
| IT-E2-1 | R0 | 寫入前後各取一次 `git status --porcelain`、`git stash list`、`git reflog`、`git log --format=%H` | `git stash list`、`git reflog`、`git log --format=%H` 三者逐字相同；`git status --porcelain` 寫入後只有目標檔一列，且該列只有工作區欄標示已修改、index 欄為空（無 staged 項目）。R0 寫入前乾淨，寫入後必然出現目標檔的修改列，所以 status 不比逐字（v0.4） | FR-02 #1；FR-08 #1 |
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

**測試檔**：`integration_test/edit_validation_real_cli_test.dart`。

**前置條件**（v0.5，缺任一項時以說明訊息判為失敗，不跳過，同 SPEC-010-test-design §6 對 fvm 的處置）：
- PATH 上有 `doc` 與 `uv`。
- fixture repo 內有指向 `.claude/skills/doc` 的符號連結，以及只登記基準文件 UC 編號的 UC 白名單。
- 基準文件為 UC 型（如 `UC-900-*.md`），不是 SPEC 型：`doc validate` 依檔名前綴取 ID。

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E6-1 | R0，基準文件為 UC 型，內文不含 UC 提及 | 等 baseline 量測完成後，修正 `primary_actor`，值含 `unregisteredUc2` | `written`；驗證狀態為 `failed`，新增問題數 1；目標檔內容含新值（未被改回）。先等 baseline 完成，本案才是在測差集判定，而不是 V-19 的競態（v0.5） | FR-05 #2 |
| IT-E6-2 | R0，內文已含兩次未登記的 UC 提及 | 修正 `title`（不含 UC 提及） | 驗證狀態為 `passed` | FR-05 #3 |
| IT-E6-3（正向對照） | IT-E6-1 的 fixture | 修正 `title`（值不含 UC 提及） | 驗證狀態為 `passed`，證明 IT-E6-1 的 `failed` 來自新值 | — |

### 2.7 IT-E7 provenance 多檔寫入在真實 repo 上（FR-03〈多檔寫入（1.1）〉）

**測試檔**：`integration_test/edit_multi_file_real_git_test.dart`。可 import `lib/graph/` 重建圖（integration 層不受 §1.3 的 `test/unit/edit/` 隔離限制）；內圈只用 `FakeCorpusNodeIndex`，不碰 Graph。

| # | fixture | When | Then | 對應驗收 |
|---|---|---|---|---|
| IT-E7-1 | R11 | 對 SPEC-900 `source_proposal` 移除 PROP-900；再加入 PROP-901 | 兩次 `written`。第一次後：PROP-900 的 `spec_refs` 與 `design_refs` 都不含 SPEC-900，SPEC-900 的 `source_proposal` 為 `null`。第二次後：PROP-901 的 `spec_refs` 為 `[SPEC-900]`，SPEC-900 的 `source_proposal` 為 `PROP-901`。每次寫入的兩個檔除各自允許變更集合外逐位元組相同。以真實 Corpus 與 Graph 重建：SPEC-900→PROP-900 的 provenance 邊不存在，SPEC-900→PROP-901 存在。**正向對照**：在同 fixture 的複本上手動把 SPEC-900 的 `source_proposal` 改為 `null`、只刪 PROP-900 的 `spec_refs` 項（`design_refs` 保留），重建後 SPEC-900→PROP-900 邊仍存在，證明本案的「邊不存在」來自 `design_refs` 也被刪 | FR-03 #9、#28 |
| IT-E7-2 | R11b | 對 SPEC-900 加入 PROP-901 | `written`；只有 PROP-901 帶快照 SHA（W ≠ H），`git cat-file -p <sha>` 逐位元組等於 PROP-901 寫入前的 W；SPEC-900 不帶 SHA。`git stash list`、`git reflog`、`git log --format=%H`、`git diff --cached --name-only` 寫入前後逐字相同 | FR-02 #1（多檔）；FR-08 #1 |
| IT-E7-3 | R11 | 對 SPEC-900 移除 PROP-900 | PROP-900 權限仍為 `0640` | FR-03 #6（反向檔） |

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
| G-19 | W = M = H；第一次修正 `title` 得 `written` | 第二次修正 `status`（同一次編輯） | 第二次不判 `externallyModified`：步驟 1 讀到的 W 等於第一次寫入落檔的位元組，即更新後的 M；結果 `written`（SPEC-009 FR-01〈M 的更新〉） |
| G-20（對照） | 第一次修正得 `blocked(rewriteNotIsolated)`；另一案得 `ioFailed`（步驟 4 失敗）；另一案得 `blocked(snapshotFailed)` | 第二次修正另一欄位 | 三案的 M 都仍為 `beginEditing` 讀到的位元組；磁碟未動，第二次的步驟 1 判 W = M、結果 `written`。正向對照為 G-19：只有 `written` 會更新 M |
| G-21（守衛） | 第一次修正得 `written`；Edit 實作若未更新 M（以「M 停在開始編輯時」的錯誤實作作正向對照輸入） | 第二次修正 | 測試對該錯誤實作判紅：第二次得 `blocked(externallyModified)` 時本案失敗，證明 G-19 能鑑別 M 是否更新 |
| G-22 | W = M；`show` 設為永不完成 | 修正，虛擬時間推進 5 秒 | `show` 子行程被終止；視同 H 無法判定、走快照分支（接著呼叫 `hash-object`）；`written` 帶 SHA（SPEC-009 FR-01〈`git` 子行程逾時 5 秒〉、FR-02 驗收 #6） |
| G-23 | W = M；`FakeEditFilePort` 的步驟 1 讀取於虛擬時間 60 秒後才完成 | 修正 | 不產生任何逾時結果，讀取完成後照常判定（本地檔案 IO 不設逾時，SPEC-009 FR-01） |
| G-24 | W = M = `doc_nonutf8`；使用真實局部改寫與隔離檢查（不注入替身改寫器） | 修正 `title` | 第 2 步回傳 `blocked(rewriteNotIsolated)`；`FakeEditFilePort` 操作序列中沒有暫存檔寫入與 rename；目標檔不變（SPEC-009 v1.5 FR-03〈非 UTF-8 內容〉、驗收 #8）。與 G-6 的分工：G-6 以替身改寫器驗第 1 步逐位元組比較，本案驗真實流程在第 2 步擋下 |

### S 快照（FR-02）

**測試檔**：`test/unit/edit/snapshot_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| S-1 | W ≠ H | 快照 | git 引數恰為 `hash-object -w --stdin`，不含 `--path` 與檔案路徑；標準輸入位元組逐位元組等於步驟 1 的 W |
| S-2 | `hash-object` 回傳 40 字元 SHA | 快照 | `written` 帶該 SHA |
| S-3（守衛） | `FakeEditGitPort` 對 `hash-object` 拋出無法啟動 | 修正 | `blocked(snapshotFailed)`；目標檔不變（正向對照：S-2） |
| S-4 | 有快照、無快照各一次寫入 | 取取回說明 | 有快照為 `git cat-file -p <sha> > <路徑>`；無快照為 `git checkout HEAD -- <路徑>`；兩者的路徑皆為工作區相對路徑 |
| S-5 | 快照 | 快照 | git 呼叫中沒有 `add`、`stash`、`update-ref`、`commit`、`reset`、`checkout` |
| S-6（守衛） | W = M ≠ H；`hash-object` 設為永不完成 | 修正，虛擬時間推進 5 秒 | `hash-object` 子行程被終止；`blocked(snapshotFailed)`；目標檔不變；沒有寫入暫存檔（SPEC-009 FR-02 驗收 #5；正向對照：S-7） |
| S-7（對照） | W = M ≠ H；`hash-object` 於虛擬時間 4.9 秒時回傳 SHA | 修正 | 子行程未被終止；`written` 帶 SHA（逾時以 5 秒為界，不提前終止） |

### R 局部改寫與原子寫入（FR-03）

**測試檔**：`test/unit/edit/field_rewrite_test.dart`（R-1～R-8、R-13、R-14）、`test/unit/edit/atomic_write_test.dart`（R-9～R-12）

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
| R-13 | `doc_plain` | 清空 `target_version` | 以 `classifyFrontmatter` 解析：`target_version` 鍵仍存在、值為 `null`；改寫後與改寫前相比，只有 `target_version` 值與 `updated` 值所在的位元組範圍不同（v1.4 FR-03〈清空〉、驗收 #7） |
| R-14（守衛，隔離檢查函式） | 改寫前 `doc_plain`；改寫後刪去 `target_version` 整行 | 對兩份位元組呼叫隔離檢查，允許集合 {target_version, updated} | 解析層不通過（少一個鍵）。正向對照：R-13 的改寫後位元組通過。證明清空不能以移除鍵實作 |
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

**測試檔**：`test/unit/edit/write_result_test.dart`（V-1～V-3）、`test/unit/edit/validation_baseline_test.dart`（V-4～V-14、V-19～V-21）

`doc uc verify` 的 stdout 樣本形式為逐行 `<路徑>:<行號>:<UC 編號>`，結束碼 1 表示有違規（2026-11-10 以 doc CLI 實測取得）。`doc validate` 失敗輸出的樣本由承接票以真實 CLI 取得，並標註實測日期（test-assertion-design D5）。

| # | Given | When | Then |
|---|---|---|---|
| V-1 | W = M = H；驗證器設為永不完成 | 修正並觀測狀態序列 | 依序為「寫入進行中」、受理 `written`、驗證 `running`；三者可由型別區分 |
| V-2 | W ≠ M | 修正並觀測 | 只有受理 `blocked(externallyModified)`；沒有「寫入進行中」，也沒有驗證狀態 |
| V-3 | `blocked`、`ioFailed`、`written` 三種結果 | 以窮舉 switch 讀取 | 型別為封閉型別；`blocked` 攜帶三種原因之一 |
| V-3b（1.1） | SPEC-009 FR-05 `WriteResult` 表列出的每一種結果 | 以窮舉 switch 讀取 | 封閉型別的成員恰等於該表列出的值；表增減成員時本案紅燈。`partiallyWritten` 攜帶未還原路徑清單（各附取回說明）與觸發失敗的路徑及原因。V-3 的 1.0 窮舉在 1.1 由本案承擔 |
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
| V-15（守衛） | baseline 已完成；寫入得 `written`；寫入後的 `doc validate` 設為永不完成 | 虛擬時間推進 30 秒 | 該子行程被終止；驗證為 `unavailable(timedOut)`；寫入結果仍為 `written`；`FakeEditFilePort` 在驗證開始後沒有寫入與 rename（SPEC-009 FR-05 驗收 #7；正向對照：V-17） |
| V-16 | baseline 的 `doc uc verify` 設為永不完成 | 虛擬時間推進 30 秒後寫入兩次；之後 `discardAndReload` 並讓驗證器正常回應 | 兩次寫入的驗證都是 `unavailable`；`discardAndReload` 後重跑 baseline，下一次寫入的驗證可為 `passed` |
| V-17（對照） | 寫入後的 `doc validate` 於虛擬時間 29.9 秒完成、結束碼 0 | 驗證 | 子行程未被終止；`passed` |
| V-18 | 寫入後的 `doc validate` 於 20 秒完成、`doc uc verify` 於其後 20 秒完成，皆結束碼 0 | 驗證 | `passed`：逾時對每個子行程各自計時，合計 40 秒不構成逾時 |
| V-19（守衛） | baseline 的 `doc uc verify` 設為延遲完成（尚未完成），完成時回報零個問題；寫入後的 `doc uc verify` 回報 `unregisteredUc` 一次 | 在 baseline 完成前修正並寫入；讓延遲的 baseline 在第一次寫入的驗證完成後、第二次寫入前完成；之後再修正 `title` 一次（寫入後問題集合不變） | 第一次：`written`；驗證為 `unavailable(baselineNotReady)`，不是 `passed`。延遲的 baseline 完成後不改變 baseline。第二次：以第一次寫入後的問題集合為 baseline，驗證為 `passed`（新增 0）。若延遲的 baseline（零個問題）被錯誤採用，第二次會是 `failed`、新增 1，本案因此能分辨 baseline 是否被丟棄（SPEC-009 v1.7 FR-05〈baseline 與寫入的先後〉；正向對照：V-14 的 baseline 已完成時同一新值得 `failed`） |
| V-20 | baseline 已完成，`unregisteredUc` 零次；第一次寫入後的 `doc validate` 逾時（`unavailable(timedOut)`） | 第二次修正，寫入後 `doc uc verify` 回報 `unregisteredUc` 一次 | 第二次驗證為 `failed`、新增 1：第一次驗證 `unavailable` 時保留原 baseline，不以該次寫入取代（SPEC-009 v1.7 FR-05） |
| V-21 | baseline 延遲完成（尚未完成），在第二次寫入前完成並回報零個問題；第一次寫入後的 `doc validate` 逾時；第二次寫入後的 `doc uc verify` 回報 `unregisteredUc` 一次 | 在 baseline 完成前寫入第一次；之後寫入第二次與第三次（第三次修正 `title`，問題集合不變） | 第一次：`unavailable(baselineNotReady)`（沒有可用 baseline，也沒有可保留的舊 baseline）。第二次：仍沒有可用 baseline，驗證為 `unavailable(baselineNotReady)`。第三次：以第二次寫入後取得的問題集合為 baseline，驗證為 `passed`（新增 0）（SPEC-009 v1.7 FR-05〈沒有可用 baseline 時〉） |
| V-22（1.1） | `spec_sp_scalar` 與 `prop_empty_refs`（PROP-B）；`FakeValidatorPort` 記錄全部呼叫 | `beginEditing` SPEC-900，對 `source_proposal` 加入 PROP-B 得 `written` | baseline 與寫入後驗證的呼叫目標都只有 SPEC-900（`doc validate SPEC-900`、`doc uc verify <SPEC-900 路徑>`）；沒有任何以 PROP-B 的 id 或路徑為目標的呼叫；驗證狀態只有一個（SPEC-009 FR-03〈寫入後驗證〉） |

FR-05 驗收第 1 條由 V-1～V-3（1.1 起含 V-3b）涵蓋；第 2 條由 V-5、V-12 與 IT-E6-1 涵蓋；第 3 條由 V-4 與 IT-E6-2 涵蓋；第 4 條由 V-6 涵蓋；第 5 條由 V-7、V-8 涵蓋；第 6 條由 V-9、V-10、V-16 涵蓋；第 7 條（驗證子行程逾時，v1.2）由 V-15、V-17、V-18 涵蓋。V-22 的測試檔為 `test/unit/edit/multi_file_write_test.dart`（與 W 群組同檔，1.1）。

### X 外部改動的發現時點（FR-06）

**測試檔**：`test/unit/edit/external_change_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| X-1 | 編輯 SPEC-900 中，有未寫入值；`FakeEditFilePort` 的 SPEC-900 已改一個位元組 | `FakeCorpusParsedSource` 送出一輪 EVT-CORPUS-001 | Edit 重讀 SPEC-900（`FakeEditFilePort` 記錄一次讀取）；編輯狀態轉為外部已改預警；未寫入值仍保留 |
| X-2（對照） | 編輯 SPEC-900 中；SPEC-900 磁碟內容與 M 相同（本輪是其他檔案被改） | 送出一輪 EVT-CORPUS-001 | Edit 重讀 SPEC-900；內容與 M 相同，編輯狀態不變（FR-06 驗收：內容與 M 相同時狀態不變） |
| X-3 | X-1 之後；磁碟內容確實已變 | 修正 | `blocked(externallyModified)`（預警不阻擋嘗試，判定仍由閘門） |
| X-4 | X-1 之後；磁碟內容又改回與 M 相同 | 修正 | `written`（預警不是阻擋，判定仍由閘門） |
| X-5 | 外部改動磁碟內容，但不送 EVT-CORPUS-001 | 修正 | `blocked(externallyModified)` |
| X-6 | X-1 之後 | `discardAndReload` | M 為新的磁碟內容；驗證器再次以該檔被呼叫（重跑 baseline）；之後修正可 `written` |
| X-7 | X-1 | 預警期間 | 沒有對使用者呈現焦點通道發出請求（記錄用仲裁器零請求） |
| X-8 | 編輯 SPEC-900 中；SPEC-900 已被外部刪除或改名（`FakeEditFilePort` 讀取回報不存在） | 送出一輪 EVT-CORPUS-001 | 編輯狀態轉為外部已改預警（檔案不存在視為 W ≠ M，SPEC-009 FR-01 約束、FR-06 發現點表） |
| X-9（守衛） | 編輯 SPEC-900 中；SPEC-900 磁碟內容已變；EVT-CORPUS-001 的負載不含 SPEC-900 | 送出一輪 EVT-CORPUS-001 | 仍轉為外部已改預警：判定來自重讀，不讀負載（正向對照：X-2 磁碟未變時不轉） |
| X-10 | 已處於外部已改預警 | 再送一輪 EVT-CORPUS-001 | 狀態維持預警，不重複發出任何請求 |

FR-06 驗收第 1 條（EVT-CORPUS-001 到達且內容與 M 不同 → 預警）由 X-1、X-8、X-9 涵蓋；第 2 條（內容與 M 相同時狀態不變）由 X-2 涵蓋；第 3 條（EVT-CORPUS-001 未到達仍判 `externallyModified`）由 X-5 涵蓋。

### L 日誌事件與只記識別（FR-07）

**測試檔**：`test/unit/edit/edit_log_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| L-1 | `EditLogEvent` 的全部值 | 列出值名稱 | 集合恰等於 SPEC-009 FR-07 事件表的成員；表增減成員時本案紅燈 |
| L-2 | W = M = H | 修正 | 依序記 `writeIssued`、`writeAccepted`，皆 info、無 `error_source`，fields 為路徑與欄位名 |
| L-3 | W ≠ H | 修正 | 另記 `snapshotTaken`（info），`blob_sha` 為 40 字元小寫十六進位 |
| L-4 | 外部已改；改寫不隔離 | 修正 | 各記一筆 `writeBlocked`，warning、`gate_blocked`，fields 帶原因 |
| L-5 | `hash-object` 回傳 128；另一案無法啟動 | 修正 | 各記一筆 `writeBlocked`，error、`external_process`；前者帶結束碼 128、不帶 `executableMissing`，後者相反（結束碼、`executableMissing`、`timedOut` 三者恰一，`timedOut` 見 L-11）；沒有另外的失敗事件（一次失敗一筆） |
| L-6 | 讀取失敗、寫入失敗各一，`osError.errorCode` 13 | 修正 | `readIoFailed` 或 `writeIoFailed`，error、`platform_io`，帶 errorCode 13 |
| L-7 | 寫入失敗且 `osError` 為 null | 修正 | `writeIoFailed` 不含 errorCode 欄位 |
| L-8 | 驗證為 `passed`、`failed`（新增 1）、`unavailable`（結束碼 3） | 驗證完成 | `validationCompleted`：`passed` 為 info；`failed` 為 warning、無 `error_source`、帶新增問題數；`unavailable` 為 warning、`external_process`、帶結束碼 |
| L-9（守衛，C-2） | 欄位新值含 `secretMarker`；依序讓寫入以 `externallyModified`、`rewriteNotIsolated`、`snapshotFailed`、`ioFailed` 失敗 | 每案修正 | `RecordingEditLogSink` 的序列化文字、`WriteResult` 的 `toString()`、`blocked` 原因與 IO 失敗分類的 `toString()`，都不含 `secretMarker`。**正向對照**：同一新值寫入成功時，`FakeEditFilePort` 中目標檔內容含 `secretMarker`，證明標記確實送進了寫入層 |
| L-10（守衛，C-2） | 讀取失敗的例外訊息含 `secretMarker` | 修正 | 日誌序列化文字與 `ioFailed` 的 `toString()` 不含標記 |
| L-11 | `hash-object` 逾時（同 S-6） | 修正 | 一筆 `writeBlocked`，error、`external_process`，fields 帶 `timedOut`，不帶結束碼與 `executableMissing`；`show` 逾時（同 G-22）不記失敗事件，因為它走快照分支而非失敗 |
| L-12 | 驗證逾時（同 V-15） | 驗證完成 | `validationCompleted`：warning、`external_process`，帶原因 enum `timedOut`，不帶 CLI 結束碼（二擇一） |
| L-13（1.1） | 同 W-24 的兩案（正向檔 `rename` 失敗、正向檔步驟 5 重讀不同），還原皆成功 | 修正 | 每案恰兩筆失敗相關事件：觸發檔的原事件（前案 `writeIoFailed`、後案 `writeBlocked(externallyModified)`），加一筆 `writeRolledBack`。`writeRolledBack` 為 warning、無 `error_source`，fields 為觸發失敗的路徑與已還原路徑數 1 |
| L-14（1.1，守衛） | 同 W-25（還原失敗，`osError.errorCode` 5） | 修正 | 恰一筆 `writePartiallyWritten`：error、`platform_io`，fields 含觸發失敗的路徑、未還原路徑清單 `[PROP-B 路徑]`、errorCode 5；**沒有** `writeIoFailed`、`writeBlocked`、`writeRolledBack`（一次失敗只記一筆）。正向對照：L-13 還原成功時有原事件與 `writeRolledBack` |
| L-15（1.1） | `EditLogEvent` 的全部值 | 列出值名稱 | 含 `writeRolledBack`、`writePartiallyWritten`；集合與 SPEC-009 FR-07 表的事件逐一相等（與 L-1 同一判準） |
| L-16（1.1） | `spec_sp_scalar` 與 `prop_std`；W ≠ H 的只有 PROP-A | 移除 PROP-A 得 `written` | 一筆 `writeAccepted`；一筆 `snapshotTaken`，路徑為 PROP-A、`blob_sha` 等於 `written` 中 PROP-A 的 SHA；SPEC-900 沒有 `snapshotTaken` |
| L-17（1.1） | 同 W-20（加入 PROP-B，兩檔） | 修正得 `written` | `writeIssued` 恰一筆，路徑只記正向檔 SPEC-900；`writeAccepted` 恰一筆（不是兩筆），路徑欄為清單，列出 SPEC-900 與 PROP-B 兩個路徑。對照：單檔寫入（L-2）的 `writeAccepted` 路徑只有一個（SPEC-009 FR-07 多檔寫入整批記一筆） |
| L-18（1.1，守衛） | 同 W-21 (b)（PROP-B 改寫不隔離，整批被閘門擋下） | 修正得 `blocked(rewriteNotIsolated)` | 恰一筆 `writeBlocked`（帶 PROP-B 路徑）；沒有 `writeIssued`、沒有 `writeAccepted`（整批被閘門擋下時不記 `writeIssued`，SPEC-009 FR-07）。正向對照：L-17 閘門通過時有一筆 `writeIssued` |

FR-07 驗收第 1 條「每個帶 `error_source` 的事件在上表寫明分類」由 L-1 把事件集合與規格表綁住，L-4～L-8 逐一驗證分類。驗收第 2 條由 L-9、L-10 涵蓋。v1.2 新增的 `timedOut` 欄位由 L-11、L-12 涵蓋。1.1 的多檔失敗記錄方式由 L-13、L-14 涵蓋，事件集合由 L-15 涵蓋，整批一筆由 L-16、L-17 涵蓋，整批被擋時不記 `writeIssued` 由 L-18 涵蓋；L-13～L-18 的測試檔為 `test/unit/edit/multi_file_write_log_test.dart`。

### C session 寫入清單與事後追溯（FR-08）

**測試檔**：`test/unit/edit/session_write_list_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| C-1 | 兩次寫入：SPEC-900 的 `title`、PROP-900 的 `priority` | 讀取 session 寫入清單 | 兩列，每列含路徑、欄位名、節點 ID、驗證狀態；有快照者帶快照 SHA |
| C-2（守衛，C-2） | 寫入值含 `secretMarker` | 讀取清單並序列化 | 不含 `secretMarker`（正向對照：L-9 的正向對照） |
| C-3 | 修正 SPEC-900，驗證器設為延後完成；之後對 PROP-900 開始編輯 | SPEC-900 的驗證以 `failed` 完成 | 清單中 SPEC-900 那一列的狀態由 `running` 變為 `failed`；PROP-900 的編輯 session 不受影響 |
| C-4 | W ≠ H 的寫入一次、W = H 的寫入一次 | 讀日誌 | 前者有 `snapshotTaken`，且其 `blob_sha` 等於清單該列的 SHA；後者沒有（正向對照） |
| C-5 | 任一次寫入 | 寫入 | `FakeEditGitPort` 沒有 `commit`、`add`、`stash` 呼叫 |
| C-6（SPEC-009 v1.12） | 同一 fixture 依序發出 `written`、`ioFailed`、`blocked` 三次寫入；另各發一次 `blocked(externallyModified)`、`blocked(snapshotFailed)`、`blocked(rewriteNotIsolated)`；另一次寫入在受理前讀取清單 | 讀取 session 寫入清單 | 每次發出各成一列（對照：v1.11 以前的實作只有 `written` 成列，三次得一列）；受理前該列為寫入中（結果為空），受理後原地更新同一列，不新增列。對照：呼叫端未發出的寫入（必填欄位送出空白）不進寫入路徑，不成列 |
| C-7（SPEC-009 v1.12） | 兩個專案各發出一次寫入 | 讀取清單；切換專案後再讀取 | 每列附所屬專案；切換專案後兩列都保留，非目前專案的列路徑不可點（畫面層，SPEC-001 §12〈切換專案〉） |
| C-8（1.1） | `spec_sp_scalar`、`prop_empty_refs`（PROP-B）；PROP-B 為 W ≠ H | 對 `source_proposal` 加入 PROP-B 得 `written`，驗證以 `passed` 完成 | 清單恰一列（不是兩列）；列內附 SPEC-900 與 PROP-B 兩個路徑，PROP-B 的取回說明為 `git cat-file -p <sha> > <路徑>`，SPEC-900 的為 `git checkout HEAD -- <路徑>`；驗證狀態只有一個且屬 SPEC-900（SPEC-009 FR-08〈多檔寫入的列法（1.1）〉） |
| C-9（1.1） | 同 W-25（`partiallyWritten`） | 讀取清單 | 該列結局為 `partiallyWritten`，列內只附未還原的檔（PROP-B）與其取回說明，沒有驗證狀態 |
| C-10（1.1） | 移除 PROP-A 後再加入 PROP-B（兩次寫入） | 讀取清單 | 兩列，各自結局 `written`（操作單位：改成另一值是兩次寫入，FR-03〈多值欄位的加入與移除（1.1）〉） |
| C-11（1.1） | `spec_related_flow`；呼叫端對 `related_specs` 加入已在清單中的 `SPEC-2` | 讀取清單 | 清單無新列（FR-08 驗收 #4 的 1.1 同類情形；呼叫端不發出寫入，見 M-12） |

C-6、C-7 的測試檔：`test/unit/edit/session_write_list_issued_test.dart`（C-6 全部、C-7 的資料層）、`test/widget/screens/write_log_panel_test.dart`（C-6 的寫入中與失敗列呈現、C-7 的畫面層）、`test/widget/app/shell_test.dart`（失敗計數徽章計入 `blocked`、`ioFailed`），皆由 `1.0.0-W3-553.17.1` 建立；C-6 的「未發出不成列」對照由 `1.0.0-W3-553.15` 的 `test/unit/screens/node_detail/node_detail_edit_test.dart`（必填空白不發出寫入）涵蓋。

FR-08 驗收第 1 條由 C-5 與 IT-E2-1、IT-E2-2 涵蓋；第 2 條由 C-2 與 L-9 涵蓋；第 3 條由 C-3 涵蓋；第 4 條（v1.12）由 C-6 涵蓋；第 5 條（v1.12）由 C-7 涵蓋；第 6 條由 C-4 涵蓋（編號依 v1.12 條目順序）。〈多檔寫入的列法（1.1）〉由 C-8～C-10 涵蓋，第 4 條的 1.1 同類情形由 C-11 涵蓋；C-8～C-10 的測試檔為 `test/unit/edit/session_write_list_multi_file_test.dart`；C-11 是呼叫端案例，放 `test/unit/screens/node_detail/node_detail_edit_test.dart`（同 M-12）。

### F 逐欄位輸入元件（FR-09）

**測試檔**：`test/unit/screens/node_detail/field_input_mapping_test.dart`（落點以畫面票為準）

| # | Given | When | Then |
|---|---|---|---|
| F-1 | FR-09 兩張表中「自」為 1.0 的每一列 | 以（節點型別、欄位）查對照函式 | 回傳該列的「現行元件」；全部列逐一列舉，表增減時本案紅燈 |
| F-2（守衛） | 值域來源 fake 對 SPEC `status` 回傳「無機器定義」 | 查對照 | 單行文字（正向對照：對 PROP `status` 回傳機器定義的列舉時為下拉） |
| F-3（守衛） | 值域來源 fake 對所有欄位都回傳「無機器定義」 | 查全部 1.0 欄位 | 沒有任何欄位為下拉或單選鈕組。這證明 App 沒有內建值域表：若有，值域來源回傳「無」時仍會產生下拉 |
| F-4 | 「自」晚於當前 build 所屬 minor 的欄位，或「自」為 `—` 的欄位 | 查對照 | 回傳「不可編輯」（1.1 build 的實例見 F-10；「自」等於或早於當前 minor 的欄位可編輯，見 F-8） |
| F-5 | 可清空欄位（PROP proposed_by、EVT payload）；草稿為 `""`、`"   "`；另一案草稿為 `"  x "` | 判定送出內容 | 前兩案寫入值為 `null`；第三案寫入值逐字為 `"  x "`（非空值不修剪）（v1.4 FR-09〈可否清空〉） |
| F-6（守衛） | 必填欄位（PROP title、EVT name），草稿 trim 後為空 | 判定送出內容 | 不發出寫入；提示為 `fieldRequiredEmpty`；`FakeEditFilePort` 零寫入。正向對照：F-5 的可清空欄位同樣輸入時發出寫入 |
| F-7（守衛） | 值域來源 fake 的 `completeness_fields` 對 PROP 只列 `id`、`status`（拿掉 `title`） | 以 PROP title、草稿 `""` 判定送出內容 | 寫入值為 `null`（title 改判可清空）。證明必填集合讀自 `tracking_schema.json`，App 沒有內建清單。正向對照：F-6 |
| F-8（1.1） | FR-09 各型別特有欄位表中「自」為 1.1 的每一列：PROP related_proposals、supersedes；SPEC source_proposal、related_usecases、related_specs、implements_requirements、depends_on_domains；UC source_proposal、related_specs、related_usecases、ticket_refs；DomainBundle source_specs、related_usecases、depends_on_bundles；EVT source_proposal、producers、consumers | 以（節點型別、欄位）查對照函式 | 回傳該列的「目標元件」（1.1 新開欄位沒有「現行元件」，以目標元件為準）：chips 加搜尋、核取清單或可搜尋下拉（可空）；全部列逐一列舉，表增減時本案紅燈 |
| F-9（1.1，守衛） | PROP `outputs` | 查對照 | 回傳「不可編輯」：1.1 只作為多檔寫入的反向檔，不提供直接編輯（FR-09 PROP outputs 列）。正向對照：F-8 的 SPEC `source_proposal` 可編輯 |
| F-10（1.1） | 「自」為 1.2 以後或為 `—` 的欄位（例：UC secondary_actors、DomainBundle path_patterns、UC flow 區塊、PROP proposed_date） | 查對照 | 回傳「不可編輯」（F-4 在 1.1 build 的實例） |

F-5～F-10 的落點與 F-1～F-4 相同（`field_input_mapping_test.dart`）；判定在畫面狀態層，不經元件（SPEC-004 4.44 `onSubmitted` 對空白照常呼叫，元件不判斷必填）。

### N 寫入不阻擋操作（NFR-01）

**測試檔**：`test/unit/edit/non_blocking_test.dart`

| # | Given | When | Then |
|---|---|---|---|
| N-1 | 驗證器永不完成 | 修正 | `WriteResult` 在驗證完成前即可取得 |
| N-2 | N-1 之後，驗證仍為 `running` | 對同一檔的另一欄位修正 | 可受理並 `written`；不等待前一次驗證 |

NFR-01 的指標「寫入受理延遲」以量測填入規格，不作為 pass／fail 斷言（test-assertion-design D1）。量測腳本放 `integration_test/perf/edit_write_latency.dart`，對 R0 與 R1 各寫入 20 次，輸出中位數與最大值，由承接票記入 SPEC-009 NFR-01。

### M 多值欄位的加入與移除（FR-03〈多值欄位的加入與移除（1.1）〉）

**測試檔**：`test/unit/edit/multi_value_rewrite_test.dart`（M-12 除外）；M-12 為呼叫端案例，屬畫面狀態層，放 `test/unit/screens/node_detail/node_detail_edit_test.dart`（與 1.0 必填空白案例同檔；§1.3 禁止 `test/unit/edit/` import `lib/screens/`）。本群組只看正向檔本身的值改寫；`source_proposal` 案例依操作分開設定，使寫入集合只剩正向檔，把多檔判定隔離在 W 群組：移除案（M-7、M-8、M-9）的 `FakeCorpusNodeIndex` 對被移除的 PROP 回傳「查不到」（移出端查不到即略過）；加入案（M-5、M-6）的 `FakeCorpusNodeIndex` 對被加入的 PROP 回傳 `prop_design` 的路徑（已含該 SPEC，不列入；加入端查不到會整批阻擋，不能用）。「位元組比對」皆指改寫前後除允許變更集合（目標欄位值範圍、`updated`）以外逐位元組相同。

| # | Given | When | Then |
|---|---|---|---|
| M-1 | `spec_related_flow` | 對 `related_specs` 加入 `SPEC-4` | 值為 `[SPEC-1, SPEC-2, SPEC-3, SPEC-4]`（附加於末尾、分隔為 `, `）；位元組比對通過；`updated` 為 `2026-11-10` |
| M-2 | `spec_related_flow` | 分三案移除 `SPEC-1`、`SPEC-2`、`SPEC-3` | 依序得 `[SPEC-2, SPEC-3]`、`[SPEC-1, SPEC-3]`、`[SPEC-1, SPEC-2]`：只刪該項與其一個分隔，不留 `, ,`、前導或尾隨分隔；位元組比對通過 |
| M-3 | `spec_related_empty` | 加入 `SPEC-1` | `[SPEC-1]` |
| M-4 | `related_specs: [SPEC-1, SPEC-2]` | 移除 `SPEC-2`；再移除 `SPEC-1` | 依序得 `[SPEC-1]`、`[]`（其他欄位不轉純量、不轉 `null`；與 M-7、M-8 對照） |
| M-5 | `spec_sp_scalar`（`PROP-A`） | 加入 `PROP-B` | `[PROP-A, PROP-B]`（純量轉 flow 序列） |
| M-6（F1） | `spec_sp_null` | 加入 `PROP-B` | 純量 `PROP-B`，不是 `[PROP-B]`。對照：M-3 的其他欄位由 `[]` 加入得 `[v]` |
| M-7（F2） | `source_proposal: [PROP-A, PROP-B]` | 移除 `PROP-B` | 純量 `PROP-A`，不是 `[PROP-A]`。對照：M-4 的其他欄位得 `[SPEC-1]` |
| M-8（F3） | `spec_sp_scalar` | 移除 `PROP-A` | 以 `classifyFrontmatter` 解析：`source_proposal` 鍵仍存在、值為 `null`；位元組比對通過。對照：M-4 的其他欄位得 `[]` |
| M-9（F4） | `spec_sp_dup`；另一案 `spec_related_dup` | 前者移除 `PROP-A`；後者移除 `SPEC-2` | 前者得純量 `PROP-C`；後者得 `[SPEC-1]`。兩案改寫後的值都不含被移除值的任何出現（只刪一筆的實作會留下一筆，本案因此紅燈） |
| M-10（守衛） | `spec_unsupported` 七個變體 | 各加入 `SPEC-9` 與移除 `SPEC-1`（變體中存在的項） | 十四案皆 `blocked(rewriteNotIsolated)`；`FakeEditFilePort` 無暫存檔寫入與 rename；目標檔不變。正向對照：M-1、M-2 |
| M-11（守衛） | `spec_related_flow` | 加入值 `a,b`、`x:y`、`p#q`、`[z]`、` lead`（前導空白）、`trail `（後置空白） | 六案皆 `blocked(rewriteNotIsolated)`，目標檔不變。正向對照：M-1 的 `SPEC-4` |
| M-12（畫面狀態層） | `spec_related_flow`；呼叫端（編輯狀態）對 `related_specs` 加入已在清單中的 `SPEC-2`；另案加入不在清單中的 `SPEC-4` | 送出 | 前案不發出寫入：寫入層零呼叫，因此沒有 `WriteResult`；`FakeEditFilePort` 零寫入、零 rename；`FakeEditGitPort` 零 `hash-object`；`RecordingEditLogSink` 零事件；session 清單不新增列（C-11）；目標檔不變（v1.13 FR-03，比照 F-6 的必填空白）。**正向對照（E2）**：後案同一呼叫端恰好發出一次寫入（寫入層記錄一次呼叫，操作為加入 `SPEC-4`） |
| M-12b（守衛） | `spec_related_flow`；繞過呼叫端，寫入層直接收到「加入 `SPEC-2`」；另案 `spec_sp_scalar`（`source_proposal: PROP-A`），寫入層直接收到「加入 `PROP-A`」 | 修正（debug build） | 兩案前置條件 assert 失敗（`throwsA(isA<AssertionError>())`），檔案不變（純量視為單項清單，`PROP-A` 已在其中）。正向對照：M-1 加入不在清單中的 `SPEC-4` 時不觸發 assert；純量樣本的正向對照為 M-5（純量 `PROP-A` 加入不同值 `PROP-B` 時不觸發 assert） |
| M-13 | `spec_related_flow` | 呼叫端把 `SPEC-1` 改成 `SPEC-9`：移除 `SPEC-1`、再加入 `SPEC-9` | 兩次各自經過閘門（`FakeEditFilePort` 記錄兩輪步驟 1 讀取與兩次 rename）；最終值為 `[SPEC-2, SPEC-3, SPEC-9]`。寫入 API 只接受單一加入或單一移除，沒有「取代」操作（以型別判定：操作參數為二值封閉型別） |

FR-03 驗收 #10 由 M-1～M-4 涵蓋；#11 由 M-5；#12～#15 分別由 M-6～M-9（F1～F4）；#16 由 M-10、M-11；#17 由 M-12、M-12b、C-11。

### W provenance 多檔寫入（FR-03〈多檔寫入（1.1）〉）

**測試檔**：`test/unit/edit/provenance_write_set_test.dart`（W-1～W-19，寫入集合、反向清單鍵、子鍵形狀與允許變更集合）、`test/unit/edit/multi_file_write_test.dart`（W-20～W-28，整批閘門、`rename` 順序、回復）。

共同 Given：正向檔 SPEC-900（UC、EVT 案例另註）；`FakeCorpusNodeIndex` 對 PROP-A、PROP-B 回傳各自路徑，對 PROP-Z 回傳查不到；W = M = H（另註者除外）。「所有檔不變」指寫入集合每個檔逐位元組等於寫入前，且同目錄無暫存檔、`FakeEditFilePort` 零 rename。

**寫入集合與反向清單鍵**

| # | Given | When | Then |
|---|---|---|---|
| W-1 | 正向 `spec_sp_scalar`；PROP-A 為 `prop_std`；PROP-B 為 `prop_empty_refs` | 移除 PROP-A；再加入 PROP-B | 第一次寫入集合恰為 {SPEC-900, PROP-A}：PROP-A 的 `spec_refs` 為 `[SPEC-1]`，SPEC-900 的 `source_proposal` 為 `null`。第二次寫入集合恰為 {SPEC-900, PROP-B}：PROP-B 的 `spec_refs` 為 `[SPEC-900]`，SPEC-900 為 `PROP-B`。每次兩個檔各自除允許變更集合外逐位元組相同（PROP 的 `usecase_refs`、`event_refs`、`ticket_refs` 不變） |
| W-2 | 正向 UC-900（`source_proposal: PROP-A`）；PROP-A 為 `prop_std` 加 `usecase_refs: [UC-900]`；PROP-B 為 `prop_empty_refs` | 加入 PROP-B；另案移除 PROP-A | 加入：PROP-B 的 `usecase_refs` 為 `[UC-900]`，`spec_refs` 與其他子鍵逐位元組不變。移除：PROP-A 的 `usecase_refs` 不含 UC-900 |
| W-3（守衛） | 正向 UC-900；PROP-B 為 `prop_missing_key`（缺 `usecase_refs`，有 `spec_refs: []`） | 加入 PROP-B | 整批 `blocked(rewriteNotIsolated)`，帶 PROP-B 路徑；所有檔不變。`spec_refs` 存在不影響判定（不會改寫進 `spec_refs`）。正向對照：W-2 加入 |
| W-3b（守衛） | 正向 `spec_sp_null`（SPEC-900）；PROP-B 為 `prop_missing_key` 缺 `spec_refs` 的變體（有 `usecase_refs: []`、`event_refs: []`） | 加入 PROP-B | 整批 `blocked(rewriteNotIsolated)`，帶 PROP-B 路徑；所有檔不變（不改寫進其他子鍵、不新增 `spec_refs`）。正向對照：W-1 第二次加入 `prop_empty_refs`（有 `spec_refs: []`）時 `written` |
| W-4（守衛） | 正向 EVT-900；PROP-B 為 `prop_empty_refs`；另案 PROP-B 缺 `event_refs` | 加入 PROP-B | 前案：PROP-B 的 `event_refs` 為 `[EVT-900]`，`spec_refs`、`usecase_refs` 逐位元組不變（仍為 `[]`）。後案：整批 `blocked(rewriteNotIsolated)`，所有檔不變，`spec_refs`、`usecase_refs` 也未被寫入 |
| W-5 | 正向 `spec_sp_scalar`；PROP-A 為 `prop_design` | 移除 PROP-A | 寫入集合恰為 {SPEC-900, PROP-A}；寫入後 `spec_refs` 與 `design_refs` 皆為 `[]`。只刪 `spec_refs` 的實作會留下 `design_refs: [SPEC-900]`，本案因此紅燈（圖上邊的斷言見 IT-E7-1） |
| W-6 | 正向 `spec_sp_null`；PROP-B 為 `prop_design_only`（`spec_refs: []`、`design_refs: [SPEC-900]`） | 加入 PROP-B | 寫入集合恰為 {SPEC-900}；PROP-B 零寫入，`spec_refs` 仍為 `[]`。只看 `spec_refs` 的實作會把 PROP-B 列入並寫成 `[SPEC-900]`，本案因此紅燈 |
| W-7（守衛） | 正向 `spec_sp_null`；PROP-B 的 `spec_refs` 為 `null`；另案為純量 `SPEC-X` | 加入 PROP-B | 兩案整批 `blocked(rewriteNotIsolated)`，所有檔不變。正向對照：`spec_refs: []`（`prop_empty_refs`）時 `written`，得 `[SPEC-900]` |
| W-8 | 正向 `spec_sp_scalar`；PROP-A 的 `spec_refs` 為純量 `SPEC-900`，其他子鍵不含 SPEC-900 | 移除 PROP-A；另案對 `spec_sp_null` 加入 PROP-A | 移除：寫入集合恰為 {SPEC-900}，PROP-A 零寫入。加入：整批 `blocked(rewriteNotIsolated)`。對照：`spec_refs: [SPEC-900]` 時移除列入並改寫為 `[]` |
| W-9（守衛） | 正向 `spec_sp_scalar`；PROP-A 的 `spec_refs` 為 block 序列含 SPEC-900 | 移除 PROP-A | 整批 `blocked(rewriteNotIsolated)`，所有檔不變。正向對照：同內容改寫為 flow 序列時 `written` |
| W-10（守衛） | 正向 `spec_sp_null`；PROP-B 的 `spec_refs` 為 block 序列不含 SPEC-900 | 加入 PROP-B | PROP-B 列入；整批 `blocked(rewriteNotIsolated)`，所有檔不變。對照：W-11 |
| W-11 | 正向 `spec_sp_null`；PROP-B 的 `spec_refs` 為 block 序列含 SPEC-900 | 加入 PROP-B | 寫入集合恰為 {SPEC-900}（先判寫入集合、後套形狀表）；`written` |
| W-12 | 正向 `spec_sp_scalar`（移除案）或 `spec_sp_null`（加入案）；PROP 為 `prop_outputs_nonmap` 七個變體 | 各移除與加入 | 依 SPEC-009〈`outputs` 本身不是 map〉表。移除：`[SPEC-900]`、純量 `SPEC-900` 兩變體算「含」，PROP 列入，整批 `blocked(rewriteNotIsolated)`，所有檔不變；`[SPEC-1]`、`null`、缺鍵、`3`、`true` 五變體算「不含」，寫入集合恰為 {SPEC-900}，`written`。加入：`[SPEC-900]`、純量 `SPEC-900` 兩變體已「含」，PROP 不列入，寫入集合恰為 {SPEC-900}，`written`，PROP 零寫入；`[SPEC-1]`（清單、不含）、`null`、缺鍵、`3`、`true` 五變體 PROP 列入，整批 `blocked(rewriteNotIsolated)`，所有檔不變。`[SPEC-900]` 變體的兩案證明「沒有子鍵」不被推得「不含」；`[SPEC-1]` 變體承擔清單形態下加入的阻擋 |
| W-13 | 正向 `source_proposal: PROP-Z`（PROP-Z 查不到，即 `danglingRef`）；PROP-B 為 `prop_empty_refs` | 移除 PROP-Z；再加入 PROP-B | 第一次寫入集合恰為 {SPEC-900}，`source_proposal` 為 `null`。第二次寫入集合為 {SPEC-900, PROP-B}，PROP-B 的 `spec_refs` 為 `[SPEC-900]` |
| W-14（守衛） | 正向 `spec_sp_null` | 加入 PROP-Z（查不到） | 整批 `blocked(rewriteNotIsolated)`，所有檔不變。正向對照：W-1 第二次加入 PROP-B |
| W-15 | 正向 `spec_sp_scalar`；PROP-A 為 `prop_dup` | 移除 PROP-A | PROP-A 的 `spec_refs` 為 `[SPEC-1]`：SPEC-900 的兩筆出現全部刪除（Q1） |
| W-16 | 正向 `spec_sp_scalar`；PROP-A 為 `prop_scalar_subkey` | 移除 PROP-A | `spec_refs` 為 `[]`；`ticket_refs: SPEC-900`（純量子鍵）逐位元組不變 |

**反向檔的允許變更集合**

| # | Given | When | Then |
|---|---|---|---|
| W-17 | 正向 `spec_sp_null`；PROP-B 為 `prop_no_updated`；另案為 `prop_empty_refs`（有 `updated`） | 加入 PROP-B | 前案 PROP-B 改寫後仍無 `updated` 鍵；後案 `updated` 為 `2026-11-10`。兩案 PROP-B 除 `spec_refs` 值範圍與（後案的）`updated` 值範圍外逐位元組相同 |
| W-18（守衛，隔離檢查函式） | 改寫前 `prop_std`；改寫後除 `spec_refs` 外，`ticket_refs` 也多一項 | 以允許集合 {`outputs.spec_refs`, `updated`} 呼叫隔離檢查 | 解析層不通過。另案改寫後只改 `outputs` 區塊內一行註解：位元組層不通過。正向對照：只改 `spec_refs` 值時兩道皆通過 |
| W-19 | 正向 `spec_sp_scalar`；PROP-A 為 `prop_std`；`FakeCorpusNodeIndex` 記錄查詢 | 移除 PROP-A | 反向檔路徑來自 `FakeCorpusNodeIndex` 對 `PROP-A` 的查詢（查詢記錄一筆）；寫入的路徑等於該回傳值（依賴方向見 E-DEP-2） |

FR-03 驗收 #9 由 W-1；#18 由 W-3b（W-3、W-4 為 UC、EVT 的同型）；#23 由 W-13；#24 由 W-14；#25 由 W-2；#26 由 W-3；#27 由 W-4；#28 由 W-5 與 IT-E7-1；#29 由 W-6；#30 由 W-7；#31 由 W-8；#32 由 W-9；#33 由 W-10；#34 由 W-11；#35 由 W-12 涵蓋。

**整批閘門、`rename` 順序與回復**

以下 Given 皆為：正向 `spec_sp_null`，對 `source_proposal` 加入 PROP-B（`prop_empty_refs`），寫入集合 {SPEC-900, PROP-B}。中途失敗一律以 `FakeEditFilePort` 的多檔注入模擬（edit domain-map §4 FR-03 列）。

| # | Given | When | Then |
|---|---|---|---|
| W-20 | 無注入 | 修正 | 操作序列：兩個檔都完成步驟 1～4（讀 W、改寫、快照判定、寫暫存檔並 fsync）之後，才出現第一個 rename；rename 依序為 PROP-B（先，含其前一筆步驟 5 重讀）、SPEC-900（最後，含其前一筆步驟 5 重讀）。另案寫入集合含兩個以上反向檔的情形不會發生（操作單位），不設案 |
| W-21（守衛） | 四案注入：(a) SPEC-900 步驟 1 讀到 W ≠ M；(b) PROP-B 改寫不隔離（`spec_refs` 為 block 序列）；(c) PROP-B 為 W ≠ H 且 `hash-object` 回傳 128；(d) 無注入那次（W-20）操作序列中步驟 4 較晚的那一個檔，其暫存檔 fsync 失敗；注入前先斷言另一個檔的暫存檔已存在（FR-03 只規定依序，未規定檔案順序，所以不寫死檔名） | 修正 | 依序得 `blocked(externallyModified)`、`blocked(rewriteNotIsolated)`、`blocked(snapshotFailed)`、`ioFailed`，各帶觸發檔路徑；四案皆所有檔不變、零 rename、所有已寫暫存檔已刪。正向對照：W-20 |
| W-22 | PROP-B 為 W ≠ H，SPEC-900 為 W = H | 修正 | git 只有 PROP-B 一次 `hash-object`，標準輸入等於 PROP-B 的 W；`written` 攜帶兩個路徑，只有 PROP-B 帶 SHA |
| W-23 | PROP-B 在 `beginEditing` 之後、送出之前被外部改動（`ticket_refs` 多一項）；另案在 PROP-B 步驟 4 完成後被改動 | 修正 | 前案 `written`：反向檔的 M 取送出當下步驟 1 讀到的內容，外部改動保留在寫入結果中（`ticket_refs` 多的那項仍在）。後案：PROP-B 步驟 5 重讀不同 → `blocked(externallyModified)`，帶 PROP-B 路徑，所有檔不變（PROP-B 是第一個 rename，無需還原） |
| W-24 | 注入兩案：(a) SPEC-900 的 rename 失敗；(b) SPEC-900 步驟 5 重讀不同（PROP-B rename 完成後改動 SPEC-900） | 修正 | (a) 回傳 `ioFailed`、(b) 回傳 `blocked(externallyModified)`，皆帶 SPEC-900 路徑。PROP-B 逐位元組還原為其步驟 1 的 W；SPEC-900 的暫存檔已刪；還原走「寫暫存檔、fsync、rename」，且還原期間沒有步驟 5 重讀與隔離檢查（W-26）；同目錄無暫存檔 |
| W-25（守衛） | W-24 (a)，另注入 PROP-B 還原的 rename 失敗（`osError.errorCode` 5）；PROP-B 為 W ≠ H 帶快照 | 修正 | 回傳 `partiallyWritten`，不是 `written`、`ioFailed` 或 `blocked`：未還原清單恰為 [PROP-B]，附取回說明 `git cat-file -p <sha> > <PROP-B 路徑>`；觸發失敗為 SPEC-900 路徑與 rename 失敗。另案 PROP-B 為 W = H 無快照：取回說明為 `git checkout HEAD -- <PROP-B 路徑>`。正向對照：W-24 (a) 還原成功時回傳 `ioFailed` |
| W-26 | W-24 (a) | 修正 | 還原 PROP-B 的過程中，`FakeEditFilePort` 沒有對 PROP-B 的讀取（不重比磁碟），`classifyFrontmatter` 沒有被呼叫於還原內容（以 spy 包住解析入口計數） |
| W-27 | W-20 得 `written` | 對 SPEC-900 再移除 PROP-B（同一次編輯） | 第二次不判 `externallyModified`（正向檔 M 已更新為第一次落檔的位元組）；PROP-B 第二次的 M 取第二次送出時讀到的內容，即第一次寫入後的位元組；結果 `written`，PROP-B 的 `spec_refs` 回到 `[]` |
| W-28（守衛，窮舉） | 注入位置與 SPEC-009 FR-03 一一對應：〈閘門整批判定〉對兩個檔各自的步驟 1 讀取 W、步驟 2 改寫（以不隔離的改寫結果注入）、步驟 3 快照（PROP-B 設為 W ≠ H，`hash-object` 失敗由 `FakeEditGitPort` 注入，屬 git port）、步驟 4 的寫暫存檔與 fsync；步驟 5 重讀與步驟 6 `rename`（兩個檔各一）；〈中途失敗的回復〉第 2 步對已 rename 的檔的還原寫暫存檔、還原 fsync、還原 rename。另含無注入的一次 | 修正 | 無注入那次與每一個注入案都計入結局集合。每一案的結局恰為三者之一：(1) 結果 `written` 且兩檔皆為新內容；(2) 結果為 `blocked` 或 `ioFailed`，兩檔皆逐位元組等於寫入前，且同目錄沒有暫存檔（FR-03 #19）；(3) 結果 `partiallyWritten` 且其未還原清單恰為磁碟上不等於寫入前的檔案集合。任一案落在三者之外即紅燈。三種結局在集合中都至少出現一次（證明窮舉確實觸發了每一種結局） |

FR-03 驗收 #19 由 W-21、W-28；#20 由 W-24；#21 由 W-25；#22 由 W-20 涵蓋。FR-05 `partiallyWritten` 與多檔時 `written`／`blocked`／`ioFailed` 攜帶的內容由 W-21、W-22、W-25 涵蓋。

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 5a | 5b |
|----|----|----|
| FR-01 | IT-E1、IT-E3、IT-E5 | G |
| FR-02 | IT-E1-2、IT-E2 | S；G-7 |
| FR-03 | IT-E2-4；IT-E7（1.1） | R；M、W（1.1） |
| FR-04 | IT-E4 | P |
| FR-05 | IT-E6 | V；W-21、W-22、W-25、V-22（1.1） |
| FR-06 | — | X |
| FR-07 | — | L（1.1：L-13～L-18） |
| FR-08 | IT-E2-1、IT-E2-2；IT-E7-2（1.1） | C（1.1：C-8～C-11） |
| FR-09 | — | F（1.1：F-8～F-10） |
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
| FR-01 | #7 同一次編輯連續兩次寫入不因 W ≠ M 被擋；`blocked`、`ioFailed` 後 M 不變（v1.3） | G-19、G-20、G-21 | domain unit |
| FR-01 | 約束：git 呼叫設 `LC_ALL=C`（v1.1，非驗收條目） | IT-E1-6；G-18 | integration；domain unit |
| FR-01 | 約束：`git` 子行程逾時 5 秒、本地檔案 IO 不設逾時（v1.2，非驗收條目） | G-22、G-23、S-6、S-7 | domain unit |
| FR-02 | #1 status、stash、reflog 不變 | IT-E2-1、IT-E2-2；S-5 | integration；domain unit |
| FR-02 | #2 寫入結果帶 SHA，取回逐位元組等於 W | IT-E1-2；S-1、S-2 | integration；domain unit |
| FR-02 | #3 `.gitattributes` 換行轉換下取回仍等於 W | IT-E2-3 | integration |
| FR-02 | #4 `git` 無法執行 → `snapshotFailed` | S-3 | domain unit |
| FR-02 | #5 `hash-object` 逾時 → 終止、`snapshotFailed`、目標檔不變且無暫存檔（v1.2） | S-6、S-7 | domain unit |
| FR-02 | #6 `git show` 逾時 → 終止、走快照分支（v1.2） | G-22 | domain unit |
| FR-03 | #1 中途中斷後目標檔不變、無暫存檔 | R-10、R-11 | domain unit |
| FR-03 | #2 只有該值與 `updated` 不同 | R-1、R-2、R-3 | domain unit |
| FR-03 | #3 `updated` 缺席時改寫後仍無 | R-4 | domain unit |
| FR-03 | #4 anchor、alias、block scalar → `rewriteNotIsolated` | R-5；G-12 | domain unit |
| FR-03 | #5 解析結果多變一欄 → `rewriteNotIsolated` | R-6、R-8 | domain unit |
| FR-03 | #6 權限位元不變 | IT-E2-4；R-12 | integration；domain unit |
| FR-03 | #7 清空 target_version 後鍵仍在、值為 `null`、其餘位元組不變（v1.4） | R-13、R-14 | domain unit |
| FR-03 | #8 非 UTF-8 內容 → `rewriteNotIsolated`、目標檔不變（v1.5） | G-24 | domain unit |
| FR-03 | #9 SPEC 移除 PROP-A、再加入 PROP-B，兩檔除允許變更集合外逐位元組相同（v1.10） | W-1；IT-E7-1 | domain unit；integration |
| FR-03 | #10 flow 序列加入附加末尾、移除只刪該項與分隔；`[]` 加入；其他欄位移除到零項得 `[]`（v1.10） | M-1～M-4 | domain unit |
| FR-03 | #11 `source_proposal` 純量加入得 `[a, v]`（v1.10） | M-5 | domain unit |
| FR-03 | #12 F1：`null` 加入得純量 | M-6 | domain unit |
| FR-03 | #13 F2：剩一項寫回純量 | M-7 | domain unit |
| FR-03 | #14 F3：剩零項得 `null`、鍵仍在 | M-8 | domain unit |
| FR-03 | #15 F4：重複值全部移除（正向檔與其他欄位） | M-9 | domain unit |
| FR-03 | #16 block 序列、跨多行 flow 序列 → `rewriteNotIsolated`（v1.10） | M-10、M-11 | domain unit |
| FR-03 | #17 加入已在清單中的值：呼叫端不發出寫入，不改檔、不成列、不記事件；寫入層 debug assert（v1.10，v1.13 定案判定點） | M-12、M-12b、C-11 | domain unit（M-12b）；畫面狀態層 unit（M-12、C-11：`test/unit/screens/node_detail/node_detail_edit_test.dart`） |
| FR-03 | #18 加入時反向檔缺 `outputs.spec_refs` → 整批 `rewriteNotIsolated`（v1.6；v1.11 限加入） | W-3b | domain unit |
| FR-03 | #19 任一檔步驟 1～4 不通過 → 所有檔不變、無暫存檔（v1.6） | W-21、W-28 | domain unit |
| FR-03 | #20 第 2 個檔 `rename` 失敗、還原成功 → 原結果、已 rename 者還原（v1.6） | W-24 | domain unit（注入） |
| FR-03 | #21 還原也失敗 → `partiallyWritten`，帶未還原清單與取回說明（v1.6） | W-25 | domain unit（注入） |
| FR-03 | #22 `rename` 順序：反向檔在前、正向檔最後（v1.6） | W-20 | domain unit |
| FR-03 | #23 修正 `danglingRef`：先移除只寫 SPEC、再加入寫兩檔（v1.6；v1.11） | W-13 | domain unit |
| FR-03 | #24 新值指向不存在的 PROP → 整批 `rewriteNotIsolated`（v1.6） | W-14 | domain unit |
| FR-03 | #25 UC 加入寫 `usecase_refs`、其他子鍵不變；移除刪 `usecase_refs`（v1.11） | W-2 | domain unit |
| FR-03 | #26 UC 加入時缺 `usecase_refs` → 整批阻擋；`spec_refs` 不影響（v1.11） | W-3 | domain unit |
| FR-03 | #27 EVT 加入寫 `event_refs`；缺鍵整批阻擋（v1.11） | W-4 | domain unit |
| FR-03 | #28 移除時 `spec_refs`、`design_refs` 皆刪；重建圖後邊不存在（v1.11） | W-5；IT-E7-1 | domain unit；integration |
| FR-03 | #29 加入端 `design_refs` 已含 → PROP 不列入（v1.11） | W-6 | domain unit |
| FR-03 | #30 加入時目標子鍵為 `null` 或其他 id 的純量 → 整批阻擋（v1.11） | W-7 | domain unit |
| FR-03 | #31 目標子鍵為等於該 id 的純量：移除不列入、加入阻擋（v1.11） | W-8 | domain unit |
| FR-03 | #32 移除時含該 id 的子鍵為 block 序列 → 整批阻擋（v1.11） | W-9 | domain unit |
| FR-03 | #33 加入時目標子鍵為 block 序列且不含 → 整批阻擋（v1.11） | W-10 | domain unit |
| FR-03 | #34 加入時目標子鍵為 block 序列且已含 → 不列入（v1.11） | W-11 | domain unit |
| FR-03 | #35 `outputs` 非 map：清單移除阻擋；`null` 移除只寫 SPEC、加入阻擋（v1.11） | W-12 | domain unit |
| FR-03 | 約束：寫入後驗證只套正向檔（1.1，非驗收條目） | V-22 | domain unit |
| FR-03 | 約束：反向檔的 M 取送出時步驟 1 的內容；只有正向檔的 M 更新（1.1，非驗收條目） | W-23、W-27 | domain unit |
| FR-03 | 約束：反向檔路徑讀 Corpus 原始節點、不讀 Graph（v1.8，非驗收條目） | W-19；E-DEP-2 | domain unit；契約（靜態） |
| FR-04 | #1 穿越、`.`、空段、NUL、絕對、父目錄 symlink | P-3～P-6；IT-E4-2 | domain unit；integration |
| FR-04 | #2 檔名 symlink | P-7；IT-E4-1 | domain unit；integration |
| FR-04 | #3 `/work` 與 `/workspace` | P-6 | domain unit |
| FR-04 | #4 目標不存在、父目錄存在可建構 | P-2 | domain unit |
| FR-04 | #5 寫入函式不收 `String` | P-9 | 契約（靜態） |
| FR-05 | #1～#7（#7 為 v1.2 驗證逾時） | 見 V 群組末段 | domain unit；integration |
| FR-05 | 〈baseline 與寫入的先後〉：baseline 未完成即寫入 → `unavailable(baselineNotReady)`，該次寫入後的問題集合成為下一次 baseline；寫入後驗證 `unavailable` 時保留原 baseline；沒有可用 baseline 時以第一個取得的寫入後問題集合為下一次 baseline（v1.7） | V-19、V-20、V-21；IT-E6-1 改為先等 baseline | domain unit；integration |
| FR-06 | #1 EVT-CORPUS-001 到達、重讀內容與 M 不同 → 外部已改預警（含重讀得 `notFound`，v1.3） | X-1、X-8、X-9 | domain unit（application 層）；widget（畫面層預警橫幅與轉換，`1.0.0-W3-553.16`：`test/unit/screens/node_detail/node_detail_edit_test.dart`） |
| FR-06 | #2 EVT-CORPUS-001 到達、內容與 M 相同時狀態不變（v1.3） | X-2 | domain unit（application 層）；widget（同上檔） |
| FR-06 | #3 EVT-CORPUS-001 未到達仍判 `externallyModified` | X-5 | domain unit |
| FR-07 | #1、#2；`timedOut` 欄位（v1.2） | 見 L 群組末段；L-11、L-12 | domain unit |
| FR-07 | 約束：多檔中途失敗依結局記錄（還原成功：原事件加 `writeRolledBack`；還原失敗：只記 `writePartiallyWritten`）（1.1，非驗收條目） | L-13、L-14、L-15 | domain unit |
| FR-07 | 約束：多檔寫入 `writeIssued` 一筆、路徑只記正向檔；`writeAccepted` 整批一筆、路徑為清單；整批被閘門擋下時不記 `writeIssued`；`snapshotTaken` 逐檔（非驗收條目） | L-16、L-17、L-18 | domain unit |
| FR-08 | #1～#3、#6 | 見 C 群組末段 | domain unit；integration；widget（寫入清單面板與側欄項，`1.0.0-W3-553.17`：`test/widget/screens/write_log_panel_test.dart`、`test/widget/app/shell_test.dart`、`test/unit/app/write_list_providers_test.dart`） |
| FR-08 | #4 每次發出的寫入都成列（寫入中、`written`、`blocked` 三種原因、`ioFailed`），結局更新同一列；未發出不成列（v1.12） | C-6 | domain unit（`test/unit/edit/session_write_list_issued_test.dart`）；widget（`test/widget/screens/write_log_panel_test.dart`、`test/widget/app/shell_test.dart`，`1.0.0-W3-553.17.1`）；對照：`test/unit/screens/node_detail/node_detail_edit_test.dart`（`1.0.0-W3-553.15`） |
| FR-08 | 〈多檔寫入的列法（1.1）〉：一列、附各檔路徑與取回說明、只顯示正向檔驗證狀態；`partiallyWritten` 列附未還原檔（非驗收條目） | C-8、C-9、C-10 | domain unit |
| FR-08 | #5 每列附所屬專案；切換專案後清單保留（v1.12） | C-7 | domain unit（`test/unit/edit/session_write_list_issued_test.dart`）；widget（`test/widget/screens/write_log_panel_test.dart`，`1.0.0-W3-553.17.1`） |
| FR-09 | #1 1.0 欄位都有元件與值域來源 | F-1 | 畫面狀態層 unit |
| FR-09 | #2 無機器定義的列舉以單行呈現 | F-2、F-3 | 畫面狀態層 unit |
| FR-09 | 1.1 列：「自」為 1.1 的欄位回傳目標元件；PROP `outputs` 不可直接編輯；「自」為 1.2 以後者不可編輯（1.1，FR-09 無 1.1 驗收條目） | F-8、F-9、F-10 | 畫面狀態層 unit |
| FR-09 | 約束：〈可否清空〉三類、trim 判定、非空不修剪、必填集合讀 `completeness_fields`（v1.4，非驗收條目） | F-5、F-6、F-7 | 畫面狀態層 unit；F-5、F-6 的畫面承載另有 widget 案例（`test/unit/screens/node_detail/node_detail_edit_test.dart`：非必填空白寫 `null`、必填空白不發出寫入且提示格為 `fieldRequiredEmpty`） |
| NFR-01 | 驗證不阻擋下一次編輯 | N-1、N-2 | domain unit |

### 4.3 守衛類驗收的正向對照

| 守衛 | 應被擋下的輸入 | 案例 | 對照（應通過的輸入） |
|---|---|---|---|
| 閘門：外部已改 | 步驟 1 的 W 與 M 差一個位元組 | G-1、IT-E1-1 | G-3 |
| 閘門：外部已改（rename 前重比） | fsync 後才改動目標檔 | G-8 | G-3 |
| 閘門：需快照而快照失敗 | `hash-object` 回傳 128 或無法啟動 | G-7、S-3 | G-2 |
| 閘門：M 的更新 | M 停在開始編輯時的錯誤實作 | G-21 | G-19 |
| 預警：判定來自重讀而非負載 | 負載不含該檔但磁碟已變 | X-9 | X-2 |
| 快照逾時 | `hash-object` 永不完成 | S-6 | S-7 |
| 驗證逾時 | 驗證子行程永不完成 | V-15 | V-17、V-18 |
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
| 改寫隔離：清空不得移除鍵 | 改寫後少一個鍵 | R-14 | R-13 |
| 必填空白擋下 | 必填欄位草稿 trim 後為空 | F-6 | F-5 |
| 必填集合不內建 | `completeness_fields` 少一個鍵 | F-7 | F-6 |
| 依賴方向 | `lib/corpus/` import `lib/edit/` | E-DEP-1 | E-DEP-1 的樣本 |
| 依賴方向：Edit 不讀 Graph、History（1.1） | `lib/edit/` import `lib/graph/` 或 `lib/history/` | E-DEP-2 | E-DEP-2 的樣本 |
| 多值改寫：不支援的寫法（1.1） | block 序列、跨行、含註解、anchor、alias、非純量項 | M-10 | M-1、M-2 |
| 多值改寫：需引號的值（1.1） | `a,b`、`x:y` 等 | M-11 | M-1 |
| 多值改寫：加入已在清單中的值，寫入層前置條件（1.1，v1.13） | 寫入層直接收到「加入 `SPEC-2`」 | M-12b | M-1 |
| 多值改寫：重複值全部移除（1.1） | 只刪一筆的實作 | M-9 | — |
| 寫入集合：缺反向清單鍵（1.1） | 缺 `spec_refs`／`usecase_refs`／`event_refs` | W-3b、W-3、W-4 | W-2、W-4 前案 |
| 子鍵形狀：加入端 `null`／純量（1.1） | `spec_refs: null`、`spec_refs: SPEC-X` | W-7 | `spec_refs: []` |
| 子鍵形狀：block 序列（1.1） | 移除含該 id、加入不含該 id | W-9、W-10 | flow 序列同內容；W-11 |
| `outputs` 非 map（1.1） | 移除：清單或純量含該 id；加入：`[SPEC-1]`、`null`、缺鍵、數字、布林 | W-12 | W-12 的 `written` 變體 |
| 寫入集合：跨子鍵移除（1.1） | 只刪 `spec_refs` 的實作 | W-5、IT-E7-1 | IT-E7-1 的正向對照 |
| 加入端 PROP 查不到（1.1） | PROP-Z | W-14 | W-1 |
| 反向檔隔離檢查（1.1） | 多改一個子鍵；只改註解 | W-18 | W-18 的對照 |
| 整批閘門（1.1） | 步驟 1～4 任一檔不通過 | W-21 | W-20 |
| 還原失敗（1.1） | 還原 rename 失敗 | W-25、L-14 | W-24、L-13 |
| 三種結局（1.1） | 每個操作位置注入失敗 | W-28 | W-28 中的 `written` 案 |
| PROP `outputs` 不可直接編輯（1.1） | 查 PROP `outputs` | F-9 | F-8 |
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
| 多檔寫入：任一檔在步驟 1～4 不通過時，所有目標檔不變、不殘留暫存檔（1.1） | W-21、W-28 |
| 多檔寫入：反向檔全部 `rename` 後才 `rename` 正向檔（1.1） | W-20 |
| 多檔寫入：中途失敗依相反順序還原；任一檔還原失敗時回傳 `partiallyWritten`，不回傳 `written` 或檔案未動（1.1） | W-24、W-25、W-28 |
| 多檔寫入：反向檔只改該次改寫的 `outputs` 子鍵與已存在的 `updated`；加入時鍵不存在不新增（1.1） | W-17、W-18、W-3b、W-3、W-16 |
| 多檔寫入：移出端 PROP 查不到時略過；加入端查不到時整批阻擋（1.1） | W-13、W-14 |
| （§3 前言）以 id 找反向檔讀 Corpus 原始節點、不讀 Graph（1.1，非表列不變式） | W-19、E-DEP-2 |

不變式以 edit domain-map §3〈Bundle 不變式清單〉為準，上表逐列對應，每條至少一個 domain unit 案例。其中兩條另有外圈案例（C-5 對 IT-E2-2、P-9 對 P-3），外圈負責真實 git 上的確認，內圈負責定位。標 (1.1) 的各條全部以注入模擬在內圈斷言（domain-map §7 FR-03 列「多檔寫入的中途失敗以注入模擬」）；外圈 IT-E7 只確認真實 git 與真實圖重建上的正常路徑。

## 5. 案例群組 ↔ 實作範圍

本文件定稿時（2026-11-10），edit domain 的實作票尚未建立。下表是建議的切分，供建票時對照；每一列可作為一張實作票的測試範圍。

| 建議範圍 | 案例 | 前置 |
|---|---|---|
| 路徑型別 | P、IT-E4 | 無 |
| 局部改寫與隔離檢查 | R-1～R-8、R-13、R-14 | Corpus 公開 `classifyFrontmatter`（已存在） |
| 閘門、快照、原子寫入 | G、S、R-9～R-12、IT-E1、IT-E2、IT-E3、IT-E5、E-DEP-1 | 路徑型別；局部改寫；edit 的 git port（§6 第 2 項） |
| 驗證器與 baseline | V、N、IT-E6 | 閘門 |
| 日誌事件 | L | 閘門；SPEC-010 的 writer 與 `LogSink<E>`（`1.0.0-W3-553.2.2`、`.2.3`） |
| 外部改動預警與 session 清單 | X、C | 閘門；驗證器；Corpus 一輪解析完成的通知可供 Edit 訂閱（EVT-CORPUS-001）；畫面狀態見 SPEC-001 v1.89 §6、§12 |
| 多值欄位改寫（1.1） | M（M-12 除外） | 局部改寫與隔離檢查 |
| 呼叫端：加入已在清單中的值不發出寫入（1.1，畫面狀態層） | M-12、C-11 | 編輯狀態（畫面狀態層）；多值欄位改寫 |
| provenance 寫入集合與子鍵形狀（1.1） | W-1～W-19、E-DEP-2 | 多值欄位改寫；Corpus 公開面的原始節點查詢 |
| 多檔整批閘門與回復（1.1） | W-20～W-28、V-22、L-13～L-18、IT-E7 | 寫入集合；閘門、快照、原子寫入（1.0） |
| 多檔寫入的清單列法（1.1） | C-8～C-10 | 多檔整批閘門；畫面形式見 SPEC-004 4.51 |
| 欄位輸入元件對照與可否清空 | F-1～F-7 | 553.3；表單元件的元件契約（SPEC-004）；`tracking_schema.json` 的 `completeness_fields` 讀取 |

## 6. 待決與交接

1. **H 判定對語系的依賴（已補入 SPEC-009 v1.1）**：FR-01 以「結束碼 128 且 stderr 指出路徑不在 HEAD 中」區分「H 不存在」與「H 無法判定」，而 git 的 stderr 會依 `LANG`／`LC_MESSAGES` 翻譯。本文件審查時發現 v1.0 缺這一條，主控裁定補入：v1.1 規定 App 發出的 git 呼叫一律設 `LC_ALL=C`，比照 SPEC-008 FR-01 規則 1。IT-E1-6 據此斷言環境變數已設定；內圈另由 G-18 斷言。
2. **edit 的 git port 不能直接沿用 History 的 `GitProcessRunner`**：一是依賴方向，Edit 不依賴 History（edit domain-map §2）；二是型別，`GitCommandResult.stdout` 為 `String`，而 SPEC-009 要求 H 的 stdout 以位元組讀取、快照以標準輸入餵入位元組，現有介面兩者都不支援。本文件的 `FakeEditGitPort` 以位元組介面描述。是否把 git 程序 port 抽到共用層，由閘門實作票決定，本文件不代為決定。
3. **`doc validate` 失敗輸出的樣本**：V 群組的 `doc validate` 測資須由承接票以真實 CLI 取得並標註實測日期（D5）。`doc uc verify` 的樣本形式已於 2026-11-10 實測（§3 V 群組首段）。
4. **畫面錨點**：X、C、F 只斷言畫面狀態層的狀態值。編輯狀態、外部已改預警、session 寫入清單、快照回饋與取回說明的 widget 錨點案例，由 `1.0.0-W3-553.3` 定稿後的畫面票補上，並回填本文件 §4.2 的測試層欄。
5. **IT-E6 與 P-9 的環境需求**：IT-E6 需要 `uv` 與 doc CLI，P-9 需要 fvm。找不到時以說明訊息判為失敗，不跳過，不改呼叫 PATH 上的其他版本（CLAUDE.md §6）。
6. **「備份」一詞的文案約束**（FR-02 約束第 2 條）不是驗收條件，本文件不設自動測試；由寫 l10n 文案的畫面票在審查時核對。
7. **L-1 的事件數字（已解決，0.8）**：L-1 原寫死事件數量，與 FR-07 表自 v1.6 起的成員不符。0.8 改為引用 FR-07 事件表、不寫數量（主控准許改寫既有案例）。
8. **F-4 的射程（已解決，0.8）**：F-4 原寫「自為 1.1 以後」不可編輯，與 F-8 矛盾。0.8 改為「晚於當前 build 所屬 minor」，F-10 為其 1.1 實例（主控准許改寫既有案例）。
9. **加入已存在值的回傳（已解決，0.8）**：SPEC-009 v1.13 定案判定點在呼叫端，不發出寫入，沒有 `WriteResult`、不成列、不記 FR-07 事件；寫入層以 debug assert 守前置條件。M-12 改為呼叫端案例，新增 M-12b 守衛。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 0.1 | 2026-11-10 | 初稿（1.0.0-W3-553.4），對應 SPEC-009 v1.1：IT-E1-6 改為斷言 `LC_ALL=C`，新增 G-18 |
| 0.2 | 2026-11-11 | `1.0.0-W3-684`，對應 SPEC-009 v1.3：G 組新增 G-19～G-21（FR-01〈M 的更新〉，驗收 #7）；X 組觸發來源由監看事件改為 EVT-CORPUS-001 並重讀比較，改寫 X-1、X-2、X-4、X-5，新增 X-8（重讀得 `notFound`）、X-9（判定不讀負載）、X-10（預警期間再收事件）；§1.2 Mock 策略與 §1.4 新增 `FakeCorpusParsedSource`，不再沿用 `fake_watch_source.dart`；§4.2 補 FR-01 #7、FR-06 改為三條；§4.3 補兩個守衛；§5 預警列前置更新。同票併入 v1.2 逾時規定（主控裁定）：G-22、G-23，S-6、S-7，V-15～V-18，L-11、L-12，L-5 改為三者恰一；§1.4 FakeEditGitPort、FakeValidatorPort 補永不完成與終止記錄，新增逾時計時器列；§4.2 補 FR-01 逾時約束、FR-02 #5 #6、FR-05 #7、FR-07 `timedOut`；§4.3 補快照逾時、驗證逾時兩個守衛 |
| 0.3 | 2026-11-11 | `1.0.0-W3-553.7`，對應 SPEC-009 v1.4（`1.0.0-W3-686`）：<br>- §1.6 `doc_plain` 加 `target_version`。<br>- R 組新增 R-13（清空寫 `null`，FR-03 驗收 #7）、R-14（守衛：清空不得移除鍵）。<br>- F 組新增 F-5（可清空欄位空白寫 `null`、非空不修剪）、F-6（守衛：必填欄位空白擋下）、F-7（守衛：必填集合讀 `completeness_fields`，fake 少一鍵即改判）。<br>- §4.2 補 FR-03 #7 與 FR-09〈可否清空〉約束；§4.3 補三個守衛；§5 兩列同步。 |
| 0.4 | 2026-11-12 | `1.0.0-W3-553.10`，對應 SPEC-009 v1.5（執行期澄清，用戶裁定 2026-11-12）：<br>- G 組新增 G-24：真實流程下非 UTF-8 檔案在第 2 步回傳 `rewriteNotIsolated`、目標檔不變（FR-03 驗收 #8）。G-6 維持以替身改寫器驗第 1 步逐位元組比較。<br>- IT-E2-1 修訂：stash、reflog、log 逐字相同；status 只斷言目標檔一列、只有工作區欄已修改、無 staged 項目。原「四者逐字相同」在 R0（寫入前乾淨）下不可能成立。<br>- §1.6 `doc_nonutf8` 用途補 G-24；§4.2 補 FR-03 #8。 |
| 0.5 | 2026-11-12 | `1.0.0-W3-553.11.1`，對應 SPEC-009 v1.7（執行期澄清，用戶裁定 2026-11-12，經主控 AUQ）：<br>- V 組新增 V-19（守衛：baseline 未完成即寫入 → `unavailable(baselineNotReady)`，丟棄延遲的 baseline，該次寫入後的問題集合成為下一次 baseline）、V-20（寫入後驗證 `unavailable` 時保留原 baseline）、V-21（沒有可用 baseline 時，第一個取得的寫入後問題集合成為下一次 baseline）。V-19 的延遲 baseline 在兩次寫入之間完成並回報零個問題，用以分辨它是否被丟棄。<br>- IT-E6-1 改為先等 baseline 完成再寫入。<br>- §2.6 補真實 CLI 測試的前置條件（PATH 上的 `doc` 與 `uv`、doc 符號連結、UC 白名單），基準文件改為 UC 型（`doc validate` 依檔名取 ID）。<br>- §4.2 補 FR-05〈baseline 與寫入的先後〉。<br>- 原因值名稱 `baselineNotReady`（L56 提案，主控審查通過）。 |
| 0.6 | 2026-11-13 | `1.0.0-W3-553.17.1`，對應 SPEC-009 v1.12 FR-08（執行期澄清，用戶裁定 2026-11-13，經主控 AUQ）：<br>- C 組新增 C-6（每次發出的寫入都成列，含寫入中與三種 `blocked`、`ioFailed`；對照：v1.11 以前只有 `written` 成列；未發出不成列）、C-7（列附所屬專案，切換專案後保留）。<br>- §4.2 補 FR-08 #5、#6，追溯到 553.17.1 的測試檔與 553.15 的對照測試。<br>- `spec_version` 未改：v1.8～v1.11 屬 1.1 的條文，本文件尚未涵蓋，只補 v1.12 的 FR-08。 |
| 0.7 | 2026-11-13 | `1.1.0-W1-111.1`，對應 SPEC-009 v1.11 的 1.1 條文（version-bootstrap Step 5）；只增案例，不改既有案例：<br>- 新增 M 群組（M-1～M-13，多值欄位加入與移除，F1～F4）、W 群組（W-1～W-28，provenance 寫入集合、反向清單鍵、子鍵形狀、`outputs` 非 map、整批閘門、`rename` 順序、回復、`partiallyWritten`）、外圈 IT-E7（真實 git 與真實圖重建）、E-DEP-2（Edit 不 import Graph）。<br>- 既有群組追加：V-22（驗證只套正向檔）、L-13～L-16（`writeRolledBack`、`writePartiallyWritten`）、C-8～C-11（多檔一列、加入已存在值不成列）、F-8～F-10（FR-09 1.1 列）。<br>- §1.4 新增 `FakeCorpusNodeIndex`、多檔注入、`provenanceFixture`；§1.5 新增 R11、R11b；§1.6.1 新增樣本表。<br>- §4.1～§4.4、§5 補列；§6 新增第 7～9 項。`spec_version` 改為 1.12。 |
| 0.8 | 2026-11-13 | `1.1.0-W1-111.1`，對應 SPEC-009 v1.13（主控審查 0.7 回報的 NeedsContext 後裁定）：<br>- M-12 改為呼叫端案例：加入已在清單中的值時不發出寫入，沒有 `WriteResult`、零事件、不成列；新增 M-12b（守衛：寫入層直接收到時 debug assert 失敗，正向對照 M-1）。C-11、§4.2 FR-03 #17、§4.3 同步。<br>- 改寫既有案例（主控准許）：L-1 改為引用 FR-07 事件表、不寫數量，理由是成員數會隨 FR-07 增減，寫死的數字在 v1.6 已失效；F-4 改為「晚於當前 build 所屬 minor」，理由是原寫法「1.1 以後」在 1.1 build 與 F-8 矛盾，F-10 改標為其 1.1 實例。<br>- §6 第 7～9 項改為已解決 |
| 0.9 | 2026-11-13 | `1.1.0-W1-111.1` 第一輪審查修正（主控清單第 1～12、20～23 項，追加 N-1～N-3、N-5）：<br>- W-12 依〈`outputs` 本身不是 map〉表改正加入案（含的變體不列入、`written`），新增 `[SPEC-1]` 變體；新增 W-3b（SPEC 缺 `spec_refs`，FR-03 #18）；W-6 改用 `prop_design_only`；W-4 補其他子鍵不變；W-21(d) 改注入後處理的檔；W-28 注入位置對齊 FR-03 步驟、計入無注入那次、補暫存檔斷言；IT-E7-1 正向對照補 `source_proposal: null`。<br>- M 群組前言分開寫移除與加入的設定；M-11 補後置空白；M-12 補呼叫端正向對照，與 C-11 一起移到畫面狀態層；M-12b 補純量樣本。<br>- E-DEP-2 補 history 樣本；L-15 刪數字括號；新增 L-17（多檔整批各一筆 `writeIssued`、`writeAccepted`）、V-3b（封閉型別含 `partiallyWritten`）。<br>- FR-08 驗收編號對齊 v1.12 條目順序；§4.4 改引用 domain-map §3，不寫條數；§6 第 7 項不留事件數字；§1.6.1 用途欄對齊案例。 |
| 0.10 | 2026-11-13 | `1.1.0-W1-111.1` 第二輪審查修正：V-3b 改為引用 FR-05 `WriteResult` 表（規則 10）；W-21(d) 注入點改為 W-20 序列中步驟 4 較晚的檔，不寫死檔名；§1.4 多檔注入補步驟 1 讀取與還原時的 fsync；§1.6.1 用途欄補齊；§5 將 M-12、C-11 改歸畫面狀態層；M-12b 純量樣本的正向對照寫明 M-5；L-17 對齊 FR-07（`writeIssued` 只記正向檔、`writeAccepted` 路徑為清單），新增 L-18（整批被擋時無 `writeIssued`、只有 `writeBlocked`）。 |
