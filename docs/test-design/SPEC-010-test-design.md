---
id: SPEC-010-test-design
title: "SPEC-010 Phase 2 紅燈測試規格"
type: test-design
status: draft
source_spec: SPEC-010
spec_version: "1.2"
ticket: 1.0.0-W3-553.2.5
created: "2026-11-10"
updated: "2026-11-13"
---

# SPEC-010 Phase 2 紅燈測試規格

本文件是 SPEC-010 v1.1（Structured log 與錯誤來源分類）的紅燈測試規格，對應 version-bootstrap Step 5 的 observability 部分，供 `1.0.0-W3-553.2.2`～`.2.4` 以 TDD 開工。只描述測資、流程與斷言，不含測試程式碼。規則權威在 SPEC-010；本文件與其衝突時以 SPEC-010 為準，衝突本身記入承接票的 NeedsContext。

## 1. 測試策略

### 1.1 雙圈結構

| 圈 | 內容 | 目的 | 失敗時代表 |
|----|------|------|----------|
| 5a 外圈 | IT-1：真實暫存目錄寫入與輪替 | 檔案系統上的實際落地行為 | 輪替或寫入順序在真實 IO 下與 fake port 分歧 |
| 5b 內圈 | `lib/observability/` 的 domain unit；靜態守衛；各 domain 的遷移斷言 | domain-map §3〈Bundle 不變式清單〉逐條斷言 | 單一不變式被打破，可直接定位 |

### 1.2 分層決策與 Mock 策略

| 對象 | 層 | Mock 策略 |
|------|----|----------|
| 記錄信封編碼、錯誤來源序列化 | domain unit（純函式） | 時鐘以固定 `DateTime.utc` 注入 |
| 白名單包裝型別建構 | domain unit（純函式） | 無 |
| writer：寫入門檻、輪替、並寫、失敗降級 | domain unit | 檔案系統以 port 注入（fake 記憶體實作）；`developer.log` 以注入的轉呼函式取代，測試記錄每次呼叫的參數 |
| 白名單的編譯期強制、sink 與 `developer.log` 的單一出口 | 契約（靜態守衛，放 `test/` 根目錄，比照 `entitlements_contract_test.dart`） | 不 mock：讀 `lib/` 原始碼或對 fixture 跑 `fvm dart analyze` |
| 全域攔截出口 | unit（`test/unit/app/`，與既有 `global_error_handling_test.dart` 同處） | writer 以 fake 注入 |
| 各 domain 的 sink 遷移與高頻事件 | 各 domain 的 unit | 注入記錄用 sink，斷言事件碼與等級 |
| IT-1 | integration（`test/integration/`） | 不 mock：真實暫存目錄 |

Mock 只替換外部世界（檔案系統、`developer.log`、時鐘）。

### 1.3 依賴方向與測試隔離

依系統層 §2（Observability 為 L0、無出邊）：`test/unit/observability/` 只 import `lib/observability/`，不得 import 任何其他 domain 目錄。違反即代表規格〈設計約束〉「本 domain 無出邊」被打破。

### 1.4 共用測資

| helper | 用途 |
|---|---|
| `fixedClock` | 回傳 `DateTime.utc(2026, 11, 10, 13, 52, 6, 123)` |
| `FakeLogFilePort` | 記憶體中的檔案集合，可設定「建立目錄失敗」「寫入失敗」「改名失敗」 |
| `RecordingDevLog` | 記錄每次轉呼 `developer.log` 的 `name`、`level`、`message`、`error` |
| `secretMarker` | 字串 `SECRET-CONTENT-7f3a`，放進例外訊息，作為 C-2 正向對照的標記 |
| `TestEvent` | 測試專用事件 enum，值 `sampleCompleted`、`sampleFailed` |

## 2. 5a 外圈

### 2.1 IT-1 真實目錄的寫入與輪替（FR-05）

**測試檔**：`test/integration/observability_log_rotation_test.dart`
**測資**：系統暫存目錄下新建的空目錄作為 log 目錄；writer 以建構參數注入輪替門檻 4 KiB（SPEC-010 FR-05 約束），單筆記錄約 1 KiB。5 MiB 這個生產數值由 O5-3、O5-4 驗證，IT-1 只驗真實檔案系統上的改名與刪除順序。

| # | Given | When | Then |
|---|-------|------|------|
| IT-1-1 | 空目錄 | 寫入使總量超過門檻的記錄數，再多寫 1 筆 | 目錄內有 `app.jsonl` 與 `app.1.jsonl`；`app.jsonl` 每一行都可 JSON 解碼 |
| IT-1-2 | 接 IT-1-1 | 持續寫入至輪替第 6 次 | 目錄內恰為 `app.jsonl`、`app.1.jsonl`～`app.4.jsonl`；最早寫入的記錄不存在於任何檔案（正向對照：最後一筆記錄存在於 `app.jsonl`） |

## 3. 5b 內圈：測試案例

### O1 記錄信封（FR-01）

**測試檔**：`test/unit/observability/log_record_encoder_test.dart`，group `記錄信封`

| # | Given | When | Then |
|---|-------|------|------|
| O1-1 | `domain: graph`、`event: TestEvent.sampleCompleted`、`level: info`、fields 含一個整數 | 編碼 | 輸出恰為一行、以 `\n` 結尾；JSON 解碼後含 `ts`、`level`、`domain`、`event`、`fields`，型別皆為 string 或 object |
| O1-2 | fields 為空 | 編碼 | `fields` 為 `{}`，不省略 |
| O1-3 | 無例外、無 `ErrorSource` | 編碼 | 解碼結果不含 `error_source`、`error_type` 鍵 |
| O1-4 | `fixedClock`；另一案以非 UTC 的本地時間輸入 | 編碼 | `ts` 為 `2026-11-10T13:52:06.123Z`；本地時間輸入轉為 UTC 後同格式 |
| O1-5 | `TestEvent.sampleCompleted` | 編碼 | `event` 為 `sampleCompleted`（enum 值名稱原樣） |
| O1-6（守衛） | `domain` 為空字串 | 交給 writer | 不寫出任何一行，`RecordingDevLog` 有一筆 warning（正向對照：O1-1 同輸入但 `domain` 非空時寫出一行） |

### O2 錯誤來源分類（FR-02）

**測試檔**：同上，group `錯誤來源`

| # | Given | Then |
|---|-------|------|
| O2-1 | `ErrorSource` 每一個值 | 序列化分別為 `platform_io`、`external_process`、`parse`、`gate_blocked`、`internal`；值的集合與 SPEC-010 FR-02 分類表一致（表增減成員時本案紅燈） |
| O2-2 | `ErrorSource.parse` 加一個例外物件 | `error_source` 為 `parse`、`error_type` 為例外的 `runtimeType` 名稱 |

FR-02 第一條驗收「帶 `error_source` 的事件在發出端事件表寫明分類」是文件檢查，不是測試案例，由 `.2.3` 的 Solution 逐事件列表承接（見 §6）。第二條驗收由 O7-1 覆蓋。

### O3 欄位值白名單（FR-03）

**測試檔**：`test/unit/observability/log_values_test.dart`；O3-1 為 `test/observability_contract_test.dart`；O3-8 為 `test/unit/observability/log_writer_test.dart`

| # | Given | When | Then |
|---|-------|------|------|
| O3-1（守衛，靜態） | fixture `test/fixtures/observability/whitelist/negative.dart`：以字串字面值作為 fields 的值；`positive.dart`：同一呼叫改用包裝型別 | 對兩個 fixture 各跑 `fvm dart analyze` | `negative.dart` 至少一個 error，且 error 位置在字串值那一行；`positive.dart` 0 個 error（正向對照，證明紅燈來自字串而非 fixture 本身壞掉） |
| O3-2 | 根 `/w`、路徑 `/w/docs/spec/a.md` | 建構工作區相對路徑 | 成功，序列化為 `docs/spec/a.md` |
| O3-3（守衛） | 根 `/w`、路徑 `/Users/someone/b.md` | 建構 | 失敗；呼叫端取得 `LogLocation` 的值，序列化結果不含 `/Users/`（正向對照：O3-2） |
| O3-4（守衛） | 根 `/w`；路徑 `/w2/a.md`、`/w/../x/a.md` 兩案 | 建構 | 皆失敗（前綴相同但不在根之下；正規化後逃出根）（正向對照：O3-2） |
| O3-5 | 欄位名 `blockedBy`、`spawned_tickets`、`a-b` | 建構 | 皆成功 |
| O3-6（守衛） | 欄位名 `a b`、`欄位`、空字串、`1abc`、65 個字元 | 建構 | 皆失敗，替代值為 `fieldNameRejected`（正向對照：O3-5；另含 64 個字元的邊界成功案） |
| O3-7 | 節點 ID `SPEC-007`、`UC-03`、`0.1.0-W1-001`、`1.0.0-W3-553.2.1` | 建構 | 皆成功 |
| O3-8（守衛） | 節點 ID `a/b`、含換行、65 個字元 | 建構 | 皆失敗，替代值為 `nodeIdRejected`（正向對照：O3-7） |
| O3-9（守衛） | 40 字元小寫十六進位 SHA；39 字元；含 `g`；40 字元大寫十六進位 | 建構 commit SHA | 第一案成功，其餘皆失敗；大寫不轉小寫（正向對照：第一案） |
| O3-10 | enum 值、整數、布林各一 | 編碼 | 分別為值名稱字串、JSON number、JSON boolean |
| O3-12（守衛，1.1 起，SPEC-010 v1.2） | 根 `/w`；工作區相對路徑清單依序傳入 `/w/docs/a.md`、`/Users/someone/b.md`、`/w/docs/c.md` | 建構並序列化 | 序列化為三元素字串陣列：第 1、3 個為 `docs/a.md`、`docs/c.md`，第 2 個為 `LogLocation` 的值名稱；結果不含 `/Users/`，順序與傳入相同。正向對照：三個元素都在 `/w` 之下時，三個位置皆為相對路徑。 |
| O3-11（守衛，C-2） | 例外 `FileSystemException`，訊息含 `secretMarker` | 經 writer 寫一筆 `platform_io` 記錄 | 檔案內容不含 `secretMarker`，`error_type` 為 `FileSystemException`；`RecordingDevLog` 收到的 `error` 物件含 `secretMarker`（正向對照：證明標記確實送進了 writer，檔案中缺席是剝除的結果而非沒送到） |

### O4 LogSink 契約（FR-04）

**測試檔**：`test/observability_contract_test.dart`（O4-1～O4-3）；各 domain 的 unit（O4-4、O4-5）

| # | Given | When | Then |
|---|-------|------|------|
| O4-1（守衛，靜態） | `lib/` 全部 `.dart` 檔 | 掃描 `typedef … LogSink` | 恰一處；掃描函式另以記憶體中含兩處 typedef 的樣本驗證會判紅（正向對照） |
| O4-2（守衛，靜態） | `lib/` 全部 `.dart` 檔 | 掃描 `developer.log` 呼叫 | 只出現在共用 writer 的檔案；掃描函式另以含一處違規呼叫的樣本驗證會判紅（正向對照） |
| O4-3 | 既有五個事件 enum（Workspace、AttentionArbiter、AppSnackBar、Graph、History） | 列出值名稱 | 與本文件 §7 凍結清單逐字相同（遷移不得改名） |
| O4-4 | Corpus 掃描 3 個檔案，注入記錄用 sink | 跑一輪掃描 | 逐檔事件皆為 `debug`，或整輪只有一筆 `info` 以上的聚合記錄；`info` 以上的逐檔記錄筆數為 0（正向對照：逐檔 `debug` 記錄筆數為 3，或聚合記錄的計數欄位為 3；兩者擇一成立即證明 3 個檔案都被觀測到，不限定實作採哪一種） |
| O4-5 | 監看來源連續送出 3 個檔案事件 | 處理 | 同 O4-4 的判定與正向對照 |

O4-4、O4-5 的測試檔落在 `test/unit/corpus/` 與監看所在 domain 的目錄，由 `.2.3` 決定確切檔名。「每個呼叫點傳入的第一個參數是 enum 值」由 `LogSink<E extends Enum>` 的型別保證，O4-1 驗證只剩這一個型別即涵蓋。

### O5 落地位置與輪替（FR-05）

**測試檔**：`test/unit/observability/log_writer_test.dart`，group `落地與輪替`；檔案系統用 `FakeLogFilePort`

| # | Given | When | Then |
|---|-------|------|------|
| O5-1 | 注入 home `/h`、bundle id `x.y.z` | 取得目錄 | `/h/Library/Logs/x.y.z/`；原始碼不含 bundle id 字面值（O4-2 同一掃描函式另查 `com.example`） |
| O5-2 | 目錄不存在 | 第一次寫入 | 寫入前建立目錄 |
| O5-3 | 現行檔 5 MiB − 1 位元組 | 寫入一筆 | 不輪替，該筆附加在 `app.jsonl` |
| O5-4（守衛） | 現行檔恰 5 MiB | 寫入一筆 | 先輪替：原內容成為 `app.1.jsonl`，新的 `app.jsonl` 只含這一筆（正向對照：O5-3） |
| O5-5（守衛） | 已有 `app.1.jsonl`～`app.4.jsonl` 且現行檔達上限 | 寫入一筆 | 原 `app.4.jsonl` 的內容不存在；檔案恰為現行檔加 4 個歷史檔；原 `app.3.jsonl` 的內容在 `app.4.jsonl`（正向對照：O5-4 只有 1 個歷史檔時不刪任何檔） |
| O5-6 | `debug` 一筆、`info` 一筆 | 寫入 | 檔案只有 `info` 那一行；`RecordingDevLog` 兩筆都有 |
| O5-7 | 同時送出 100 筆 | 等待佇列清空 | 檔案恰 100 行，每行都可解碼（無交錯） |

### O6 與 `developer.log` 並寫（FR-06）

**測試檔**：同上，group `並寫`

| # | Given | Then |
|---|-------|------|
| O6-1 | `debug`、`info`、`warning`、`error` 各一筆，`domain: graph` | `RecordingDevLog` 的 `level` 依序為 500、800、900、1000；`name` 皆為 `graph` |
| O6-2 | 一筆 `info`，fields 含一個整數 | `RecordingDevLog` 的 `message` 以事件名開頭；檔案與 `developer.log` 的 `event` 相同 |
| O6-3 | 一筆帶例外與堆疊的 `error` | 例外與堆疊只出現在 `RecordingDevLog`，檔案中無堆疊文字（與 O3-11 互為對照） |

### O7 全域攔截出口（FR-07）

**測試檔**：`test/unit/app/global_error_handling_test.dart`（新增 group `structured log`）

| # | Given | When | Then |
|---|-------|------|------|
| O7-1 | 注入 fake writer | 分別以框架層、平台層、zone 三個來源呼叫攔截出口 | 各一筆：`domain: presentation`、`event: fatalUncaught`、`level: error`、`error_source: internal`；`fields.interceptor` 依序為 `framework`、`platform`、`zone` |
| O7-2（守衛，C-2） | 例外訊息含 `secretMarker` | 呼叫攔截出口 | fake writer 收到的記錄序列化後不含 `secretMarker`（正向對照：O3-11） |
| O7-3 | fake writer 呼叫即拋例外 | 呼叫攔截出口 | `fatalErrorNotifier` 仍更新為該例外；攔截出口本身不拋出 |

### N1 寫入失敗不擴散（NFR-01）

**測試檔**：`test/unit/observability/log_writer_test.dart`，group `失敗降級`

| # | Given | When | Then |
|---|-------|------|------|
| N1-1 | `FakeLogFilePort` 設定建立目錄失敗 | 連續寫 3 筆 | 呼叫端零例外；`RecordingDevLog` 有 3 筆記錄本身，加恰 1 筆 warning（`logDirUnavailable`） |
| N1-2 | 第 1 筆寫入成功，第 2 筆寫入失敗 | 再寫第 3 筆 | 呼叫端零例外；warning 恰 1 筆（`logWriteFailed`）；第 3 筆只進 `developer.log`，檔案仍只有第 1 筆 |
| N1-3 | 輪替時改名失敗 | 寫入觸發輪替的那一筆 | 同 N1-2 的判定 |

## 4. 覆蓋矩陣

### 4.1 FR ↔ 測試

| FR | 5a | 5b |
|----|----|----|
| FR-01 | IT-1-1（每行可解碼） | O1 |
| FR-02 | — | O2；O7-1（全域攔截為 `internal`）；第一條驗收為文件檢查（§6） |
| FR-03 | — | O3 |
| FR-04 | — | O4 |
| FR-05 | IT-1 | O5 |
| FR-06 | — | O6 |
| FR-07 | — | O7 |
| NFR-01 | — | N1 |

### 4.2 守衛類驗收的正向對照

| 守衛 | 應被擋下的輸入 | 案例 |
|---|---|---|
| 白名單（編譯期） | 字串字面值作為 fields 值 | O3-1 |
| 白名單（建構期） | 工作區外路徑、逃出根的路徑、不合字元集的欄位名與節點 ID、路徑清單中的工作區外元素（1.1） | O3-3、O3-4、O3-6、O3-8、O3-12 |
| C-2 | 例外訊息中的標記字串 | O3-11、O7-2 |
| 輪替上限 | 已有 4 個歷史檔時再輪替 | O5-4、O5-5、IT-1-2 |
| 單一 typedef、單一 `developer.log` 出口 | 含兩處 typedef 或一處直接呼叫的樣本 | O4-1、O4-2 |
| 必填欄位 | 空 `domain` | O1-6 |

### 4.3 不變式 ↔ 測試（`docs/spec/observability/domain-map.md` §3〈Bundle 不變式清單〉）

| 不變式（摘要） | 測試 |
|---|---|
| 每筆記錄是一行可解碼的 JSON，必填欄位齊全 | O1-1 |
| 全域攔截層發出的記錄，`error_source` 恆為 `internal` | O7-1 |
| 工作區外的絕對路徑無法建構為工作區相對路徑 | O3-3 |
| 帶例外物件的記錄不含例外的 `toString()` 結果 | O3-11 |
| 現行檔達上限即輪替，歷史檔數不超過規定值 | O5-5 |
| `debug` 記錄不寫檔 | O5-6 |
| writer 失敗時呼叫端不收到例外，且 `developer.log` 有一筆 warning | N1-1 |

## 5. 案例 ↔ 實作票

| 票 | 案例 |
|---|---|
| `1.0.0-W3-553.2.2` writer | O1、O2、O3（O3-1 除外）、O5、O6、N1、IT-1 |
| `1.0.0-W3-553.2.3` LogSink 統一 | O3-1、O4 |
| `1.0.0-W3-553.2.4` 全域攔截落檔 | O7 |
| 1.1 多檔整批閘門與回復的實作票（`1.1.0-W1-111` Step 6 建立，SPEC-009-test-design §5 該列） | O3-12 |

O3-1 歸 `.2.3`：包裝型別由 `.2.2` 建立，但「沒有任何呼叫點能傳字串」要等全部 sink 遷移完才成立。

## 6. 待決與交接

- **FR-02 第一條驗收是文件檢查**：「每個帶 `error_source` 的事件，在發出端的事件表中都寫明其分類」沒有對應的自動測試。由 `.2.3` 在 Solution 逐事件列出分類，並對照各 SPEC 的事件描述。
- **SHA 大小寫**：已裁定只收小寫（SPEC-010 v1.1 FR-03），O3-9 已含大寫失敗案。
- **O3-1 的執行成本**：每次跑 `fvm dart analyze` 約需數秒。比照 `entitlements_contract_test.dart` 放 `test/` 根目錄，隨全套件執行。
- **O3-1 找不到 fvm 時**：測試失敗並在訊息中說明「找不到 fvm」，不得跳過，也不得改呼叫 PATH 上的 `dart`。PATH 上的 `dart` 是本機全域版本，不是本專案釘選的版本（CLAUDE.md §6），以它判定的 analyzer 結果不代表本專案。

## 7. 凍結清單：既有事件 enum 的值名稱（O4-3）

2026-11-10 自 main `6a1e7fe546` 取出（以 awk 擷取各 enum 本體的值名稱）。`.2.3` 開工時若 main 已新增值，以新增後為準並更新本節；既有值不得改名或刪除。

| enum | 檔案 | 值名稱（宣告順序） |
|---|---|---|
| `WorkspaceLogEvent` | `lib/workspace/workspace_repository.dart` | `chooseFolderPanelOpening` `chooseFolderPanelUnavailable` `chooseFolderCancelled` `chooseFolderPathSelected` `persistIssuing` `persistPreferencesReady` `persistCompleted` `persistWriteReturnedFalse` `persistWriteThrew` `openPathIssuing` `restoreIssuing` `restoreOpenThrew` `restorePreferencesReady` `restoreMigrated` `restoreMigrationFailed` `restoreNoStoredPath` `restoreCompleted` `adapterProbeExistsResult` `adapterProbeReadFirstEntryResult` `adapterPreferencesOpenResult` `adapterPreferencesReadResult` `adapterPreferencesWriteResult` `recentProjectsLoadIssuing` `recentProjectsLoadOpenThrew` `recentProjectsAddIssuing` `recentProjectsAddOpenThrew` `recentProjectsAddWriteSucceeded` `recentProjectsAddWriteReturnedFalse` `recentProjectsAddWriteThrew` `recentProjectsMissing` `recentProjectsCorrupted` `recentProjectsLoaded` `recentProjectsWriteBaseCorrupted` `recentProjectCountsInvalid` `countsSaveIssuing` `countsSaveOpenThrew` `countsSaveNoMatchingProject` `countsSaveBaseCorrupted` `countsSaveWriteSucceeded` `countsSaveWriteReturnedFalse` `countsSaveWriteThrew` `inspectExistsIssuing` `inspectReadIssuing` `inspectReadFailed` `probeRecentProjectTimedOut` |
| `AttentionArbiterLogEvent` | `lib/app/attention_arbiter.dart` | `accepted` `preempted` `sameLevelReplaced` `skipped` `rejected` `deferred` `presented` `released` `expired` `releasedNonHolder` `invalidRequest` `levelClamped` |
| `AppSnackBarLogEvent` | `lib/components/app_snack_bar.dart` | `shown` `skippedUnmounted` `actionPressed` `closed` `preempted` `yielded` `clearedByProjectChange` |
| `GraphLogEvent` | `lib/graph/graph_log_event.dart` | `buildCompleted` `buildUnavailable` `adjacencyUnavailable` `flowUnavailable` `bundleOrderUnavailable` `domainUcRelationUnavailable` `requiredEdgeSkipped` `closedBySkipped` |
| `HistoryLogEvent` | `lib/history/git/history_log_event.dart` | `preflightEntered` `preflightResult` `degraded` `scanStarted` `scanFinished` `scanParseReported` `scanCancelled` `tripwire` `processStarted` `processExited` `processKilled` `processLaunchFailed` |

## 8. 變更歷史

| 日期 | 票 | 變更 |
|------|----|------|
| 2026-11-10 | `1.0.0-W3-553.2.5` | 初版，對應 SPEC-010 v1.1 |
| 2026-11-13 | `1.1.0-W1-111.1` | 對應 SPEC-010 v1.2：新增 O3-12（工作區相對路徑清單中的工作區外元素改記 `LogLocation`，其餘照常，正向對照為全部在工作區內）；§4.2 白名單（建構期）列與 §5 同步。O3-12 由 1.1 多檔整批閘門與回復的實作票承接 |
