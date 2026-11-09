---
id: SPEC-008-test-design
title: "SPEC-008 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-008
spec_version: "1.1"
ticket: 0.7.0-W1-012.3
created: "2026-11-09"
updated: "2026-11-09"
---

# SPEC-008 Phase 2 紅燈測試規格

本文件是 SPEC-008 v1.1（History：主線邊事件的掃描、解析與降級）的紅燈測試規格，供 `0.7.0-W1-012` 建票表中的
History 實作票（012.5～012.9、012.13）落地。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-008；
本文件與其衝突時以 SPEC-008 為準，衝突本身記入承接票的 NeedsContext。第七畫面（SPEC-001 §10、UC-07 畫面流程）
的測試不在本文件，由 `0.7.0-W1-012.4` 承擔。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-H1、IT-H2（PROP-005 §0.7 版本契約）與真實 git 行為案例 RG | 版本契約驗收終點；驗證 git 選項對使用者設定與 repo 形態的實際效果 | 掃描指令選項與真實 git 行為分歧，或 port→解析→事件交界斷裂 |
| 5b 內圈 | `test/unit/history/` 逐功能群組 | SPEC-008 FR-01～FR-10 驗收條件與 history domain-map〈Bundle 不變式清單〉 | 單一規則被打破，可直接定位 |

內圈只用合成的 `git log -p` 輸出與 fake 程序執行器，不啟動真實 git；凡須依賴真實 git 行為才能斷言的條件
（`--relative`、`--no-renames`、使用者 git 設定覆蓋、語系無關）放外圈 RG。

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 前置檢查分類、掃描指令組裝、降級判定、取消（FR-01、FR-08、FR-10 規則 3） | domain unit（driven port 的 adapter 邏輯） | git 程序以 fake 程序執行器替換：依呼叫的引數清單回傳預設的 stdout 位元組、stderr、結束碼，或拋出「無法啟動」例外；記錄每次呼叫的引數、環境變數、工作目錄與 kill 呼叫 |
| 串流解析與檔案狀態追蹤（FR-02） | domain unit（純函式） | 輸入為合成掃描輸出的行序列（位元組），不經程序執行器 |
| 宣告抽取、邊鍵、事件、ticket 建檔（FR-03～FR-05） | domain unit | 邊型表與 `id_pattern` 取自真實 Schema 解碼結果（Sociable）；型別表 JSON 以測試內建最小表注入 |
| 版本 tag、預設期間、查詢（FR-06、FR-07） | domain unit | 時鐘注入固定值 `2026-11-09T00:00:00Z`（D3）；tag 清單與主線清單以值物件直接構造 |
| 快取、惰性載入、取消、provider 接線（FR-09） | domain unit（application 層，Riverpod `ProviderContainer`） | fake 程序執行器；HEAD 由 fake 的 `rev-parse` 回應控制 |
| 日誌 | domain unit | 注入 log sink（沿用 `WorkspaceRepository` 的 `logSink` 接縫形態），生產預設轉呼 `developer.log` |
| IT-H1、IT-H2、RG | integration（`integration_test/`） | 不 mock git：暫存目錄以真實 git 建 fixture repo；IT-H2 的「git 不在 PATH」以注入不含 git 的 PATH 環境達成 |

Mock 只替換外部世界（git 程序、log、時鐘）；Schema 與 History 內部各元件一律用真實物件。

### 1.3 依賴方向與測試隔離

依 history domain-map §2 與 §5（History → Workspace、Schema；不得依賴 Corpus、Graph，SPEC-008 H3）：

- `test/unit/history/` 可 import `lib/history/`、`lib/schema/`、`lib/workspace/`（僅根路徑型別）；不得 import `lib/corpus/`、`lib/graph/`、`lib/diagnostics/`
- 只有 `integration_test/history_*` 可同時 import History 與畫面以外的組裝根
- 各實作票驗收含 import 方向檢查（`package:` 與相對路徑的 `import`、`export` 皆計入，差集為零；判準同 SPEC-007-test-design §1.3）

### 1.4 共用測資 helper（拆分友善）

| helper | 路徑 | 用途 | 使用群組 | 建立票 |
|--------|------|------|---------|-------|
| fake 程序執行器 | `test/helpers/spec008/fake_process_runner.dart` | 依引數樣式回應；可設「無法啟動」例外、結束碼、分段 stdout（可在指定位元組後暫停以測取消）；記錄呼叫、環境變數、kill | P、F、C、L | 012.5 |
| 合成 log 建構器 | `test/helpers/spec008/synthetic_log_builder.dart` | 以宣告方式組出 `git log -p` 輸出：commit 標頭（U+001E 開頭、U+0000 分隔：id、父清單、時間、作者、首行）、檔案條目（新增／刪除／修改／只改 mode／二進位）、hunk（自動算 `@@` 行數，或指定錯誤行數）、`\ No newline` 行、C-style 引號路徑、CRLF、任意位元組 | S、E、K、T、Q | 012.6 |
| 邊型表建構器 | 沿用 `test/helpers/spec007/edge_table_builder.dart` | 含 `blood`（`parent_id`／`children`）、`spawn`（`spawned_tickets`）、`blocked`（`blockedBy`）、`relatedTo`（無向）、`closed_by`、`domain_dependency` 與一個 fixture 專用 established 邊型；ticket `id_pattern` 為 `^\d+\.\d+\.\d+-W\d+-\d+(\.\d+)*$` | E、K、T | 既有 |
| frontmatter 檔案內容建構器 | `test/helpers/spec008/frontmatter_text_builder.dart` | 由 map 產生檔案全文行序列（block 清單形式），供 synthetic log 建構器計算 hunk | S、E、K、T | 012.6 |
| log 記錄器 | 沿用 `test/helpers/spec007/log_recorder.dart` | 查詢事件名、級別、負載 | L | 既有 |
| fixture repo 建構器 | `integration_test/helpers/history_fixture_repo.dart` | 在暫存目錄以真實 git 建 repo：commit、merge、tag、改名、`git clone --depth`、`git config` | IT-H2、RG | 012.13 |

各群組只透過 helper 取得 fixture，不共享 mutable 狀態；每個群組可單獨執行。

## 2. 5a 外圈

### 2.1 IT-H1 成本量級（FR-01、FR-02、FR-10、NFR-01）

**測試檔**：`integration_test/history_it_h1_cost_test.dart`（承接 012.13）

**fixture**：真實 repo，不凍結副本。兩個目標：本專案（測試以自身 repo 根為工作區根）、flutter_balance（路徑由環境變數 `HISTORY_IT_FLUTTER_BALANCE_ROOT` 提供）。
flutter_balance 不在 CI 與一般機器上，依 test-assertion-design D2 標 `@Tags(['live'])` 並以 `dart_test.yaml` 的 `skip` 排除預設執行，
由 `fvm flutter test integration_test/history_it_h1_cost_test.dart -t live --run-skipped -d macos` 顯式觸發；環境變數缺席時該目標 skip 並註明原因，不算通過。

**流程**：對每個目標經完整管線（前置檢查 → 掃描 → 解析 → 事件）執行一次，結束後把量測值寫到 `build/history_it_h1_report.json`。

| 斷言（pass-fail） | 記錄（不作門檻，依 D1） |
|------------------|----------------------|
| A1 結果型別為「完成」 | commit 數、輸出位元組數、git 耗時、解析耗時、事件數、尖峰追蹤文字量 |
| A2 狀態失步計數為 0（FR-02 規則 8） | FR-02、FR-03 各項計數（無法解碼行、無法解析的版本、無 ID 檔案、非字串值） |
| A3 掃描結束日誌含上欄全部欄位（FR-10 規則 1） | 與定案參考值（9409 commits、31.2 MB、2.28 秒；本專案 26212 commits、82 MB、5.6 秒）的比值 |

**NFR-01 的停手條件**：報告中解析耗時使總耗時超過 git 耗時兩倍時，012.13 停手回報，不自行修改掃描架構；測試本身不以此為紅燈。
量測環境依 reference-stability 規則 9 寫入報告（機器、OS、git 版本、日期）。

### 2.2 IT-H2 三種降級可辨識（FR-08）

**測試檔**：`integration_test/history_it_h2_degradations_test.dart`（承接 012.13）

| # | fixture 建置 | Then |
|---|------------|------|
| H2-1 | 暫存目錄，不執行 `git init`，內含 `docs/a.md` | 結果「非 git 專案」 |
| H2-2 | 已 `git init` 且有 commit 的 repo；以 PATH 只含一個不含 `git` 的空暫存目錄啟動 History | 結果「找不到 git」 |
| H2-3 | 以 fixture repo 建構器建 3 個 commit 的來源 repo，`git clone --depth 1 file://<來源>` | 結果「完成」且帶淺層資訊，邊界時間等於來源 HEAD 的 committer 時間；事件為空 |
| H2-4（綜合斷言） | H2-1～H2-3 | 三者結果型別兩兩不同，且皆不是「讀取失敗」 |
| H2-5（正向對照，E2） | fake 掉 git 版本為 `git version 2.30.0` 的包裝腳本置於 PATH | 結果「讀取失敗」，原因碼「git 版本過舊」——證明「讀取失敗」型別在此管線可達，H2-4 的「皆不是」具鑑別力 |

### 2.3 RG 真實 git 行為（FR-01、FR-08 規則 1 語系）

**測試檔**：`integration_test/history_real_git_scan_test.dart`（承接 012.13）

| # | fixture 建置 | Then | 對應驗收 |
|---|------------|------|---------|
| RG-1 | repo 頂層 `notes.md` 與 `other/x.md` 有變更；工作區根為 `proj/`，`proj/docs/a.md` 有帶 `parent_id` 的變更 | 事件只來自 `proj/docs/**/*.md`；事件與計數中出現的路徑皆以 `docs/` 開頭（相對於工作區根）；`notes.md` 的宣告不產生事件 | FR-01 #1 |
| RG-2 | commit 1 新增帶 `parent_id` 的 `docs/a/x.md`；commit 2 `git mv` 至 `docs/b/x.md`，內容不變 | commit 2 無事件；commit 1 一筆新增（正向對照） | FR-01 #2 |
| RG-3 | 同一 repo 跑兩次：未設定、以及 repo 層 `git config diff.noprefix true`、`log.showSignature true`、`diff.mnemonicPrefix true` | 兩次事件清單逐筆相同，且皆非空 | FR-01 #4 |
| RG-4 | 非 git 目錄，啟動環境 `LANG=zh_TW.UTF-8`、`LC_MESSAGES=zh_TW.UTF-8` | 結果「非 git 專案」；實際 git 呼叫的環境含 `LC_ALL=C`（以包裝 runner 記錄） | FR-08 #3 |
| RG-5 | 主線 commit M 為 merge，分支上 2 個 commit 分別加 `relatedTo` 與 `blockedBy` | 兩筆新增事件的 commit id 皆為 M；分支 commit 不出現在事件中 | H2 主線歸屬 |

## 3. 5b 內圈：逐群組測試案例

測試案例以群組前綴標示，群組與承接票的對照見 §6。案例中「ticket A」指符合 ticket `id_pattern` 的 ID（例 `0.1.0-W1-001`）。

### 3.1 P 前置檢查與掃描指令（FR-01，承接 012.5）

**測試檔**：`test/unit/history/git_preflight_test.dart`

| # | Given | Then |
|---|-------|------|
| P-1 | fake 回應正常（版本 2.43、在工作樹、非淺層、HEAD 存在） | 呼叫順序為版本 → 工作樹狀態 → HEAD → 主線清單 → tag 清單 → 掃描；每次呼叫的引數以 `-C <根>` 開頭，環境含 `LC_ALL=C`，未改變行程工作目錄 |
| P-2 | 同 P-1 | 掃描引數集合包含 FR-01 規則 3 列出的全部選項與 `-- docs/`，`--format` 為 FR-02 規則 1 的標頭格式 |
| P-3 | `rev-parse --is-inside-work-tree` 結束碼非 0（不在工作樹） | 分類「不是 git 工作樹」；掃描啟動 0 次 |
| P-4 | 啟動拋出「無法執行」例外 | 分類「git 無法啟動」；掃描啟動 0 次 |
| P-5 | `rev-parse --verify -q HEAD` 結束碼 1 | 分類「沒有任何 commit」；掃描啟動 0 次 |
| P-6（E2 正向對照） | P-1 的正常回應 | 掃描啟動恰 1 次——證明 P-3～P-5 的「0 次」不是因為掃描從未接線 |
| P-7 | `git --version` 回 `git version 2.30.9` | 「讀取失敗」，原因碼「git 版本過舊」；掃描 0 次 |
| P-8 | `git --version` 回 `git version 2.31.0` 與 `git version 2.39.3 (Apple Git-145)` | 皆通過版本檢查（邊界與廠商後綴） |
| P-9 | P-3 的 stderr 為中文錯誤訊息、P-1 的 stderr 含英文 `fatal:` 字樣但結束碼 0 | 分類只依結束碼與結構化輸出：前者仍為「不是 git 工作樹」，後者仍為正常 |
| P-10 | 掃描輸出含一個 `docs/img.png` 二進位條目與 `docs/README.MD`（大寫副檔名） | 兩者皆不建立狀態（FR-01 規則 4，小寫 `.md` 限定） |

### 3.2 S 串流解析與狀態追蹤（FR-02，承接 012.6）

**測試檔**：`test/unit/history/scan_stream_parser_test.dart`

| # | Given（合成輸出） | Then |
|---|----------------|------|
| S-1 | 檔案含 block 清單 `spawned_tickets:` 下 3 列；某 commit 只在第 2、3 列間加一列，hunk 上下文只含清單項、不含欄位名 | 該 commit 後該路徑宣告集合多一個 `spawned_tickets` 值（交 E 群組產生事件，見 E-1） |
| S-2 | 某 commit 刪除 frontmatter 結尾 `---`，hunk 中該行輸出為 `----` | `----` 被當作刪除行消耗，不視為檔頭；frontmatter 範圍依全文重算（原結尾消失後找下一個 `---` 或判為無 frontmatter）；失步 0 |
| S-3 | hunk 內容行恰為 `--- a/docs/x.md` 與 `+++ b/docs/y.md`（以 ` `、`-`、`+` 前綴落在行數內） | 皆視為內容，不切換目前路徑；路徑 y 不建立狀態 |
| S-4 | 既有檔無 frontmatter，某 commit 在第 1 行插入 `---`、`parent_id: A`、`---` | 該路徑宣告含 `parent_id: A`；失步 0 |
| S-5 | CRLF 檔案（每行尾 `\r`） | frontmatter 照常辨識，宣告正確 |
| S-6 | commit 1 新增空檔（無 hunk）；commit 2 寫入帶 `id` 與 `parent_id` 的內容 | commit 1 後狀態存在且為空；commit 2 後宣告含 `parent_id`；失步 0 |
| S-7 | 檔尾無換行的修改（含 `\ No newline at end of file` 於舊側與新側） | `\` 行不佔行數；重建全文與預期逐行相同；失步 0 |
| S-8 | commit 1 把 frontmatter 改成無法解析的 YAML；commit 2 修好且邊集合與壞掉前相同 | commit 1 後宣告等於壞掉前的版本；commit 2 後宣告不變；「無法解析的版本」計數 1；debug 日誌 1 筆 |
| S-9 | commit 只改 frontmatter 之後的內文（hunk 舊側起點大於 frontmatter 結束行） | 該路徑 YAML 解析次數不增加（解析器以可計數的 spy 注入）；宣告不變 |
| S-10（E2 正向對照） | S-9 的檔案，改為 hunk 落在 frontmatter 內 | 解析次數加 1——證明 S-9 的「不增加」具鑑別力 |
| S-11 | hunk 舊側 ` ` 行內容與追蹤全文不符 | 失步計數 1；warning 日誌含路徑與 commit id；該路徑之後 commit 的變更不改變其宣告 |
| S-12（E2 正向對照） | S-11 同結構，舊側內容相符 | 失步 0、warning 0——證明 S-11 的偵測不是一律觸發 |
| S-13 | 一行內文含位元組 `0xFF 0xFE` | 掃描完成；「無法解碼行」計數 1；該行以替換字元代入 |
| S-14 | 路徑含中文與空白，以 C-style 引號 `"docs/\346\226\207 x.md"` 輸出 | 狀態鍵還原為 `docs/文 x.md` |
| S-15 | 新增檔 `--- /dev/null`、刪除檔 `+++ /dev/null` | 新增建立狀態、刪除移除狀態；`/dev/null` 不成為狀態鍵 |
| S-16 | 只改 mode（`old mode`／`new mode`，無 hunk）的條目 | 狀態不變 |
| S-17 | 一份 500 commit 的合成輸出以分段 stream 餵入（每段 64 KiB，段界切在多位元組字元與行中間） | 結果與一次餵入完全相同（串流且不依賴整份讀入；段界不影響解碼） |
| S-18 | commit 標頭的父清單為兩個 id（merge） | commit 值物件的父清單為兩項；commit id、時間、作者、首行欄位正確分隔 |

### 3.3 E 宣告抽取（FR-03，承接 012.7）

**測試檔**：`test/unit/history/declaration_extraction_test.dart`

| # | Given（frontmatter） | Then |
|---|------------------|------|
| E-1 | S-1 的前後兩版 | 新增一筆 `spawn` 宣告，起點為宣告者 `id`、終點為新列值 |
| E-2 | fixture 表新增 established 邊型 `fixture_link`（欄位 `fixture_refs`）；frontmatter 帶 `fixture_refs: [B]` | 產生宣告（不改程式） |
| E-3（E1 對照） | E-2 同一 frontmatter，型別表不含 `fixture_link` | 不產生宣告——證明 E-2 的宣告來自型別表 |
| E-4 | `closed_by: tarrragon/claude#60` | 不產生宣告 |
| E-5（E2 正向對照） | `closed_by: 0.1.0-W1-002` | 產生宣告 |
| E-6 | 純量、清單、反向欄位 map（子鍵清單）各一 | 宣告數等於值數；`null`、`[]` 無宣告 |
| E-7 | `relatedTo: [3, true, B]` | 只有 `B` 一筆；「非字串值」計數 2 |
| E-8 | 無 `id` 欄的檔案帶 `parent_id: A` | 無宣告；「無 ID 檔案」計數 1 |
| E-9 | `parent_id: NOT-EXIST`（不存在的節點） | 仍產生宣告（不判斷斷邊） |
| E-10 | `domain_dependency: [schema]` | 產生宣告，對端標記為名稱值 |
| E-11 | proposed 層、非 `bundle_dependency`／`closed_by` 的邊型欄位 | 不產生宣告（使用中邊型範圍） |

### 3.4 K 邊鍵與事件（FR-04，承接 012.7）

**測試檔**：`test/unit/history/edge_event_test.dart`

| # | Given | Then |
|---|-------|------|
| K-1 | `blood` 邊：commit A 子節點寫 `parent_id: P`；commit B 父節點補 `children: [C]` | A 一筆新增，邊鍵（blood、C、P）：`blood` 正向欄位為 `parent_id`，依 SPEC-008 FR-04 規則 1 換為（邊型、宣告者、值）；B 無事件 |
| K-2 | 承 K-1：commit C 刪 `parent_id`（`children` 仍在）；commit D 刪 `children` | C 無事件；D 一筆移除 |
| K-3 | `relatedTo` 邊：X 寫 `relatedTo: [Y]`（commit 1）、Y 寫 `relatedTo: [X]`（commit 2），X 字典序小於 Y | commit 1 一筆新增，邊鍵（relatedTo、X、Y）；commit 2 無事件；若改由 Y 先宣告，邊鍵仍為（relatedTo、X、Y） |
| K-4 | 同一 commit 刪除 `docs/a/n.md`、新增內容相同的 `docs/b/n.md` | 無事件 |
| K-5 | 兩檔同 `id` 皆宣告同一邊；commit 1 刪一檔、commit 2 刪另一檔 | commit 1 無事件；commit 2 一筆移除 |
| K-6（E2 正向對照） | K-4 但新路徑的宣告少一個值 | 一筆移除——證明 K-4 的「無事件」不是一律不產生 |
| K-7 | 一個 commit 產生三條邊型、端點各異的新增 | 事件依邊型鍵名、起點、終點字典序排列；重跑兩次順序相同 |
| K-8 | 節點 `id` 由 X 改為 X2，宣告不變 | 舊鍵一筆移除、新鍵一筆新增 |
| K-9 | 事件欄位 | 含類型、邊鍵、前後宣告者（以節點 ID 去重：兩路徑同 `id` 只出現一次）、commit id、committer 時間、作者、首行 |

### 3.5 T ticket 建檔事件（FR-05，承接 012.7）

**測試檔**：`test/unit/history/ticket_creation_flag_test.dart`

| # | Given | Then |
|---|-------|------|
| T-1 | commit 新建 ticket A 的檔案，帶 `parent_id: P` 與 `blockedBy: [B]` | 兩筆新增皆為 ticket 建檔事件 |
| T-2（E2 正向對照） | 下一 commit 在 A 補 `blockedBy: [B, C]` | 該筆新增不是 ticket 建檔事件 |
| T-3 | commit 新建 `SPEC-009` 檔帶 `related_specs` 類邊 | 新增不是 ticket 建檔事件 |
| T-4 | 新建 ticket A 檔的同一 commit 刪除 A 的某條既有邊（由另一檔宣告） | 移除事件不是 ticket 建檔事件 |
| T-5 | 位於 `docs/proposals/` 但 `id` 符合 ticket 樣式的新檔 | 視為 ticket（依 `id_pattern`，不依路徑） |
| T-6 | commit 新建 ticket A 檔，但某邊的來源集合只含另一個既有檔的宣告（A 未宣告該邊） | 該邊新增不是 ticket 建檔事件 |

### 3.6 V 版本 tag 與預設期間（FR-06，承接 012.8）

**測試檔**：`test/unit/history/tag_period_test.dart`（時鐘固定 `2026-11-09T00:00:00Z`）

| # | Given（主線清單、tag 清單） | Then |
|---|-------------------------|------|
| V-1 | 主線 c0～c9；`v0.5.0`@c3、`v0.6.0`@c6；HEAD=c9 | 基準 `v0.6.0`；期間為 c7～c9；描述「v0.6.0 之後」 |
| V-2 | `v0.5.0`@c3、`v0.6.0`@c9（HEAD） | 基準 `v0.5.0`；期間 c4～c9 |
| V-3 | `v0.6.0` 打在未觸及 `docs/` 的 c6（掃描輸出中不出現 c6） | 基準仍為 `v0.6.0` |
| V-4 | tag 僅 `release-1`、`v1.0.0-rc1` | 無基準；期間為 committer 時間晚於 `2026-10-10T00:00:00Z` 的 commit；描述「最近 30 天」 |
| V-5（E2 正向對照） | V-4 加 `1.0.0`@c5（無 `v` 前綴） | 基準 `1.0.0`——證明 V-4 的拒絕來自樣式而非一律拒絕 |
| V-6 | `v0.7.0` 指向不在主線清單中的分支 commit | 不採用 |
| V-7 | annotated tag（tag 物件 → commit c4） | 以 c4 判定 |
| V-8 | 恰在 30 天邊界（`2026-10-10T00:00:00Z`）與早 1 秒的 commit | 依 SPEC-008「之後」判定：邊界值不含、早 1 秒不含、晚 1 秒含；三者寫成表驅動 |
| V-9（D3） | 同一輸入，時鐘改為 `2026-12-09` | 期間改變——證明判定讀注入時鐘而非系統時鐘 |

> V-8 的邊界包含與否，SPEC-008 FR-06 規則 3 的「之後」未明定是否含等號；本文件取「嚴格大於」。若 012.8 實作時判定不同，記入 NeedsContext 回 PM，不自行改規格。

### 3.7 B 淺層邊界與根 commit（FR-08 規則 3、4，承接 012.8）

**測試檔**：`test/unit/history/shallow_boundary_test.dart`

| # | Given | Then |
|---|-------|------|
| B-1 | 前置檢查回報淺層；合成輸出首 commit 父欄位為空、帶 3 條邊的檔案 | 首 commit 無事件；結果帶邊界時間；後續 commit 照常產生事件 |
| B-2（E2 正向對照） | 同一輸出，前置檢查回報非淺層 | 首 commit（根）產生 3 筆新增 |
| B-3 | 淺層，邊界後某 commit 刪一條邊界時已存在的邊 | 一筆移除（初始狀態已建立） |
| B-4 | 前置檢查「沒有任何 commit」 | 結果完成、事件空、帶「尚無 commit」標記；不是失敗型別 |

### 3.8 Q 查詢（FR-07，承接 012.8）

**測試檔**：`test/unit/history/history_query_test.dart`

| # | Given | Then |
|---|-------|------|
| Q-1（E1 對照） | 含 2 筆 ticket 建檔事件與 3 筆其他事件的結果 | 「包含 ticket 建檔」否：3 筆；是：5 筆；前者為後者子集，且兩者不同 |
| Q-2 | 淺層結果，期間「全部歷史」 | 含邊界之後的全部事件 |
| Q-3 | 三個 commit 各有事件 | 依主線順序新到舊；同 commit 內沿用 K-7 排序 |
| Q-4 | `domain_dependency` 事件 | 對端為名稱原值且標「非節點」；其他事件對端標為節點 |
| Q-5 | 連續三次查詢不同期間 | fake 程序執行器掃描啟動 0 次（只在記憶體運算） |
| Q-6 | 期間「預設期間」與「最近 30 天」在有基準 tag 時 | 兩者結果依各自判定，可不同 |

### 3.9 F 降級與失敗（FR-08 規則 1、2、5～7，承接 012.5）

**測試檔**：`test/unit/history/git_degradation_test.dart`

| # | Given | Then |
|---|-------|------|
| F-1 | 掃描程序結束碼 1，stderr 2 KiB | 「讀取失敗」，帶原因碼與截斷後的 stderr 摘要；標為可重試 |
| F-2 | 掃描程序被訊號終止（結束碼負值） | 「讀取失敗」，原因碼「程序異常終止」 |
| F-3 | P-3、P-4 的分類 | 分別為「非 git 專案」「找不到 git」，皆不是「讀取失敗」 |
| F-4（E2 正向對照） | F-1 | 確實落「讀取失敗」——與 F-3 合讀具鑑別力 |
| F-5 | Schema 為「無可消費的型別表」阻擋狀態 | 不呼叫任何 git（含前置檢查）；回報「專案未就緒」對應型別 |
| F-6 | Schema 以內建型別表降級 | 照常掃描，使用內建表抽取；結果帶降級標記 |
| F-7 | 單行無法解碼（S-13 的輸出）且結束碼 0 | 「完成」，不是「讀取失敗」 |

### 3.10 C 快取、惰性載入、取消（FR-09，承接 012.9）

**測試檔**：`test/unit/history/history_cache_provider_test.dart`

| # | Given | Then |
|---|-------|------|
| C-1 | 未讀取 History provider，只建立其他畫面的 provider | git 呼叫 0 次 |
| C-2 | 已有完成結果，HEAD 不變再次進入 | 前置檢查 1 次、掃描 0 次；回傳同一結果 |
| C-3（E2 正向對照） | HEAD 改變後再次進入 | 掃描 1 次 |
| C-4 | 型別表識別改變、HEAD 不變 | 掃描 1 次 |
| C-5 | 使用者要求重新整理 | 掃描 1 次（全量） |
| C-6 | 再次進入時前置檢查進行中（fake 暫停回應） | 狀態維持先前的完成結果，不轉為載入中 |
| C-7 | 再次進入時前置檢查判定「不是 git 工作樹」 | 直接轉「非 git 專案」，掃描 0 次 |
| C-8 | 掃描進行中（fake 暫停於輸出中段）取消 | fake 記錄 kill 1 次；結果「已取消」；部分事件不外露 |
| C-9 | 已有完成結果 R，重新整理中取消 | 快取仍為 R |
| C-10 | 切換專案（工作區根改變），舊專案掃描進行中 | 舊掃描 kill；快取清空；新根的前置檢查以新根執行 |

### 3.11 L 日誌與 tripwire（FR-10，承接各群組票）

**測試檔**：`test/unit/history/history_log_events_test.dart`（L-1～L-6 由 012.5、L-7 由 012.6 寫入同檔的獨立 group）

| # | Given | Then | 承接 |
|---|-------|------|------|
| L-1 | P-1 | 前置檢查入口與結果類別日誌，含 git 版本 | 012.5 |
| L-2 | 掃描完成 | 開始（根、HEAD）與結束（commit 數、位元組數、git 耗時、解析耗時、事件數、FR-02／FR-03 計數）日誌；耗時欄位存在且為非負整數，不斷言數值大小（D1） | 012.5 |
| L-3 | C-8 | 取消日誌 | 012.5 |
| L-4 | F-1、P-3、P-4 | 各一筆，含結束碼與 stderr 摘要（有者） | 012.5 |
| L-5 | fake 輸出位元組數為 256 MiB + 1（以計數型 stream 產生，不實際配置） | tripwire warning 1 筆，含位元組數與 commit 數 | 012.5 |
| L-6（E2 正向對照） | 恰 256 MiB 與 1 MiB | tripwire 0 筆 | 012.5 |
| L-7 | S-11、S-8 | warning（失步）與 debug（無法解析）日誌各 1 | 012.6 |
| L-8 | 程序啟動、結束、kill | 逐點日誌（observability 規則 5） | 012.5 |

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 驗收條件數 | 5a | 5b | 日誌 |
|----|-----------|----|----|------|
| FR-01 | 4 | RG-1、RG-2、RG-3；IT-H1 | P-1～P-10 | L-1、L-8 |
| FR-02 | 10 | IT-H1 A2 | S-1～S-18 | L-7 |
| FR-03 | 2 | — | E-1～E-11 | — |
| FR-04 | 5 | RG-5 | K-1～K-9 | — |
| FR-05 | 3 | — | T-1～T-6 | — |
| FR-06 | 5 | — | V-1～V-9 | — |
| FR-07 | 2 | — | Q-1～Q-6 | — |
| FR-08 | 4 | IT-H2（H2-1～H2-5）、RG-4 | F-1～F-7、B-1～B-4 | L-4 |
| FR-09 | 2 | — | C-1～C-10 | L-3 |
| FR-10 | 1 | IT-H1 A3 | — | L-1～L-8 |
| NFR-01 | —（記錄型） | IT-H1 記錄欄 | — | — |

無空行。

### 4.2 驗收條件 ↔ 案例（逐條）

| SPEC-008 驗收條件 | 案例 |
|------------------|------|
| FR-01 #1 子目錄工作區、頂層其他 `.md` | RG-1 |
| FR-01 #2 只改名不產生事件 | RG-2、K-4 |
| FR-01 #3 非正常類不啟動掃描 | P-3、P-4、P-5，對照 P-6 |
| FR-01 #4 `diff.noprefix`／`log.showSignature` | RG-3 |
| FR-02 #1 block 清單中段加列 | S-1、E-1 |
| FR-02 #2 刪結尾 `---` 輸出為 `----` | S-2 |
| FR-02 #3 第 1 行補 frontmatter | S-4 |
| FR-02 #4 CRLF | S-5 |
| FR-02 #5 空檔新增後寫入 | S-6 |
| FR-02 #6 檔尾無換行 | S-7 |
| FR-02 #7 YAML 壞掉後修好 | S-8 |
| FR-02 #8 只改內文不重解析 | S-9，對照 S-10 |
| FR-02 #9 失步（正向對照） | S-11，對照 S-12 |
| FR-02 #10 非 UTF-8 位元組 | S-13 |
| FR-03 #1 新增 established 邊型 | E-2，對照 E-3 |
| FR-03 #2 `closed_by` 略過與正向對照 | E-4、E-5 |
| FR-04 #1 `blood` 兩側先後 | K-1 |
| FR-04 #2 刪一側再刪另一側 | K-2 |
| FR-04 #3 `relatedTo` 兩端宣告 | K-3 |
| FR-04 #4 移動路徑 | K-4，對照 K-6 |
| FR-04 #5 同 `id` 兩檔 | K-5 |
| FR-05 #1 新建 ticket 兩邊 | T-1 |
| FR-05 #2 補值不是建檔（正向對照） | T-2 |
| FR-05 #3 新建 SPEC | T-3 |
| FR-06 #1～#5 | V-1、V-2、V-3、V-4（對照 V-5）、V-6 |
| FR-07 #1 E1 對照 | Q-1 |
| FR-07 #2 全部歷史含淺層邊界之後 | Q-2 |
| FR-08 #1 三降級互異且非讀取失敗 | H2-4（對照 H2-5）、F-3、F-4 |
| FR-08 #2 淺層邊界與根 commit | B-1，對照 B-2；H2-3 |
| FR-08 #3 非英文語系 | RG-4、P-9 |
| FR-08 #4 結束碼 1 | F-1 |
| FR-09 #1 HEAD 不變 0 次、改變 1 次 | C-2、C-3 |
| FR-09 #2 取消 | C-8 |
| FR-10 #1 tripwire 與正向對照 | L-5、L-6 |

### 4.3 兩軸去重

不變式軸與驗收條件軸共用同一案例時不另立案例（例：不變式 1 與 FR-04 #1、#2 共用 K-1、K-2）。只在不變式要求而驗收未列的形態上補案例：S-3（行數歸零前不認檔頭）、K-6、E-7、T-4、T-6、B-3。

### 4.4 不變式 ↔ 測試（history domain-map〈Bundle 不變式清單〉）

| 不變式（依清單順序） | 案例 |
|------------------|------|
| 1 來源集合空↔非空才產生事件；只增減宣告側不產生 | K-1、K-2 |
| 2 同 commit 移到另一路徑不產生事件 | K-4、K-6、RG-2 |
| 3 反向宣告與正向同鍵；無向依字典序 | K-1、K-3 |
| 4 hunk 依行數消耗，歸零前不認檔頭 | S-2、S-3 |
| 5 frontmatter 每 commit 重算，邊界移動不失步 | S-2、S-4、S-6 |
| 6 無法解析的版本沿用宣告，不產生事件 | S-8 |
| 7 失步路徑之後不產生事件並計數 | S-11、S-12 |
| 8 只收字串值；`closed_by` 不符 `id_pattern` 略過 | E-4、E-5、E-7 |
| 9 ticket 建檔只在新增且新建宣告者 ticket 檔 | T-1～T-6 |
| 10 基準 tag 不取 HEAD；樣式與主線限定；未觸及 docs 仍採用 | V-2、V-3、V-4、V-5、V-6 |
| 11 淺層邊界只建初始狀態；非淺層根照常 | B-1、B-2、B-3 |
| 12 ticket 建檔篩選子集 | Q-1 |

## 5. 測試案例統計

| 群組 | 案例數 | 檔案 |
|------|-------|------|
| IT-H1 | 3 斷言 + 記錄 | `integration_test/history_it_h1_cost_test.dart` |
| IT-H2 | 5 | `integration_test/history_it_h2_degradations_test.dart` |
| RG | 5 | `integration_test/history_real_git_scan_test.dart` |
| P | 10 | `test/unit/history/git_preflight_test.dart` |
| F | 7 | `test/unit/history/git_degradation_test.dart` |
| S | 18 | `test/unit/history/scan_stream_parser_test.dart` |
| E | 11 | `test/unit/history/declaration_extraction_test.dart` |
| K | 9 | `test/unit/history/edge_event_test.dart` |
| T | 6 | `test/unit/history/ticket_creation_flag_test.dart` |
| V | 9 | `test/unit/history/tag_period_test.dart` |
| B | 4 | `test/unit/history/shallow_boundary_test.dart` |
| Q | 6 | `test/unit/history/history_query_test.dart` |
| C | 10 | `test/unit/history/history_cache_provider_test.dart` |
| L | 8 | `test/unit/history/history_log_events_test.dart` |

E1 對照：E-3、Q-1。E2 正向對照：H2-5、P-6、S-10、S-12、E-5、K-6、T-2、V-5、B-2、F-4、C-3、L-6。

## 6. 案例 ↔ 實作票對照與拆分

| 承接票 | 群組 | 跨群組依賴 |
|-------|------|----------|
| 0.7.0-W1-012.5 git 程序 driven port | P、F、L-1～L-6、L-8；helper fake 程序執行器 | 無（F-5、F-6 只需 Schema 狀態值） |
| 0.7.0-W1-012.6 串流解析與狀態追蹤 | S、L-7；helper 合成 log、frontmatter 文字建構器 | 無 |
| 0.7.0-W1-012.7 宣告、邊鍵、事件、建檔標記 | E、K、T | 使用 012.6 的 helper 產生輸入；斷言只讀事件，不讀解析器內部 |
| 0.7.0-W1-012.8 tag、期間、查詢、淺層邊界 | V、B、Q | B、Q 以 012.7 的事件值物件構造輸入 |
| 0.7.0-W1-012.9 快取、惰性、取消、provider | C | 使用 012.5 的 fake 程序執行器 |
| 0.7.0-W1-012.13 整合測試 | IT-H1、IT-H2、RG；helper fixture repo 建構器 | 需 012.5、012.8 完成（建票表 blockedBy） |

每個群組的測試檔獨立，僅透過 §1.4 helper 取得 fixture；承接票只需讀本文件對應小節與 §1。

## 7. 設計判斷與待決

| # | 判斷 | 理由 |
|---|------|------|
| J-1 | FR-01 #1、#2、#4 與 FR-08 #3 放外圈 RG，內圈另以 P-2（引數存在）與 K-4（事件邏輯）覆蓋可單元化的部分 | `--relative`、`--no-renames`、設定覆蓋的效果屬 git 行為，fake 無法鑑別 |
| J-2 | IT-H1 的 flutter_balance 目標標 `live` 並 skip 預設執行 | 外部 repo 不在每台機器上（D2）；本專案目標可在預設執行中跑 |
| J-3 | V-8 取「嚴格大於」 | SPEC-008 FR-06 規則 3 未明定；見 §3.6 註記，衝突時回 PM |
| J-4 | L-5 以計數型 stream 模擬 256 MiB | 避免測試實際配置大記憶體；斷言對象是計數與日誌，不是記憶體行為 |
