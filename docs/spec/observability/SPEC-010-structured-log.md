---
id: SPEC-010
title: "Structured log 與錯誤來源分類"
status: draft
source_proposal: null            # 來源非提案：由 1.0.0-W3-553 子決策 3 與 1.0.0-W3-553.2 八項裁定新建
created: "2026-11-10"
updated: "2026-11-10"
version: "1.1"
owner: star-anise-system-designer
has_functional_requirements: true

domain: "observability"
subdomain: null

related_usecases: []
related_specs: [SPEC-001, SPEC-003, SPEC-005, SPEC-006, SPEC-007, SPEC-008]
implements_requirements: []
depends_on_domains: []
---

# Structured log 與錯誤來源分類

## 概述

本規格定義 App 的 structured log：一筆記錄長什麼樣、錯誤依什麼分類、記錄寫到哪裡、保留多少，以及哪些值可以進入記錄。各 domain 自有的事件碼仍定義在各自的 SPEC，本規格只定共用的記錄信封、分類與寫入規則。

決策來源：`docs/tech-decisions.md`〈補記：2026-11-10 — 1.0 編輯能力四項架構決策定案〉子決策 3，與〈補記：2026-11-10 — structured log 設計八項裁定〉。

**不變的前提**（〈2026-08-27：執行期 log 的裁決（W1-013）〉裁決二、三、四）：

| 前提 | 與本規格的關係 |
|---|---|
| 全域錯誤攔截三層 | 不變。三層的單一出口另外寫一筆記錄（FR-07） |
| 錯誤的載體是畫面 | 不變。structured log 是畫面之外新增的記錄載體，不取代畫面錯誤態 |
| catch 不得靜默 | 不變。寫一筆 structured log 滿足「不靜默」；需要使用者知道的失敗仍要轉為畫面錯誤態 |

## 功能需求

### FR-01: 記錄信封

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553.2 裁定 Q1（JSON Lines） |
| 對應用例 | — |

**描述**：每筆記錄是一行 JSON 物件（JSON Lines），以換行字元結尾。欄位如下：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `ts` | string | 是 | UTC 時間，ISO 8601，精度到毫秒（`2026-11-10T13:52:06.123Z`） |
| `level` | string | 是 | `debug`／`info`／`warning`／`error` 四值之一 |
| `domain` | string | 是 | 發出記錄的 bundle，取 DomainBundle 的 `domain` 原值；App 層（components、app、screens、組裝根）記 `presentation` |
| `event` | string | 是 | 事件碼：發出端事件 enum 的值名稱，原樣不轉換（例：`buildCompleted`） |
| `fields` | object | 是 | 事件負載；值只能是 FR-03 白名單型別的序列化結果。無負載時為 `{}` |
| `error_source` | string | 否 | FR-02 分類表的值之一。只在記錄一次失敗時出現 |
| `error_type` | string | 否 | 例外物件的 `runtimeType` 名稱。只在帶有例外物件時出現 |

**約束條件**：

- 一筆記錄只占一行；`fields` 內的值不得含未跳脫的換行字元（JSON 編碼自動保證）。
- `domain` 與 `event` 合起來在全 App 唯一；同一 domain 內的事件名稱由該 domain 的 enum 保證不重複。
- 信封不得新增可承載自由文字的欄位（例如 `message`）。除錯文案只走 `developer.log`（FR-06）。

**驗收標準**：

- [ ] 每一行都能被 JSON 解碼，且各欄位的型別與上表一致
- [ ] 缺少任一必填欄位的記錄不會被寫出

---

### FR-02: 錯誤來源分類

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553.2 裁定 Q2（依來源） |
| 對應用例 | — |

**描述**：一次失敗依「失敗從哪裡來」歸入下表其中一類，記在 `error_source`：

| 值 | 定義 | 例 |
|---|---|---|
| `platform_io` | 作業系統層的檔案、目錄、權限、通知等呼叫失敗 | `FileSystemException`、通知授權查詢失敗、監看來源中斷 |
| `external_process` | App 啟動的外部程式失敗或回傳非預期結果 | `git` 結束碼非 0、`doc` CLI 不存在或輸出無法解析 |
| `parse` | App 自己的解析器判定輸入格式不符 | frontmatter 無法解析、flow 區塊格式錯誤、git 輸出流失步 |
| `gate_blocked` | App 自己的前置閘門依規則拒絕繼續 | edit domain 的寫入前閘門判定外部已改、型別表缺席的顯式關卡 |
| `internal` | 不屬本表其他各類的未預期例外，代表 App 自身缺陷 | 全域攔截三層收到的例外、斷言失敗 |

**約束條件**：

- 分類在攔下失敗的那一層決定，也就是最接近失敗發生點、且知道失敗來源的 driven port 或解析器。全域攔截層不做來源判斷，一律記 `internal`。
- 一次失敗只歸一類、只記一筆。向上傳遞時，上層不得用另一個分類重記同一次失敗。
- **與 Diagnostics 的界線**：文件內容造成的解析失敗是破洞，由 Diagnostics 產生；log 只記一筆 `parse` 加識別（路徑、事件碼），不記判定內容。解析器本身拋出的未預期例外記 `internal`。同一個解析失敗若在兩邊各有一套判定，即為職責重疊。

**驗收標準**：

- [ ] 每個帶 `error_source` 的事件，在發出端的事件表中都寫明其分類
- [ ] 全域攔截層發出的記錄，`error_source` 恆為 `internal`

---

### FR-03: 欄位值白名單（C-2 的型別層強制）

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553.2 裁定 Q5（C-A）；〈2026-09-10〉C-2 |
| 對應用例 | — |

**描述**：`fields` 的值只接受下列包裝型別。不接受任意 `String`，使用者內容在編譯期就無法進入記錄。

| 型別 | 序列化 | 用途 |
|---|---|---|
| enum 值 | 值名稱字串 | 原因碼、狀態、子類 |
| 整數 | JSON number | 計數、行號、結束碼、`osError.errorCode`、耗時毫秒 |
| 布林 | JSON boolean | 旗標 |
| 工作區相對路徑 | 以 `/` 分隔的相對路徑字串 | 檔案識別 |
| 欄位名 | 字串 | frontmatter 欄位名、邊型名 |
| 節點 ID | 字串 | `SPEC-007`、`UC-03`、ticket ID |
| commit SHA | 40 字元小寫十六進位字串（`0-9a-f`） | git 物件識別 |

**約束條件**：

- **路徑一律記工作區相對路徑**。絕對路徑含 `/Users/<name>/`，使用者貼出 log 求助時會外洩帳號名稱。工作區外的路徑（例如 App 自己的設定檔、`git` 執行檔位置）不記路徑字串，只記一個 enum 說明是哪一類位置。
- 工作區相對路徑由呼叫端以「工作區根路徑 + 絕對路徑」建構；建構時路徑不在根之下即建構失敗，改記 `LogLocation` 的值。本規格不依賴 Workspace domain，根路徑以純值傳入。
- 欄位名與節點 ID 是唯二收字串的包裝型別，建構時以本規格寫明的字元集驗證，不符者建構失敗，改記 `LogIdentityRejected` 的值。字元集寫在本規格、不引用 Schema 的 `id_pattern` 或其他 domain 的定義：引用即成為 Observability 對該 domain 的依賴，而該 domain 已依賴 Observability，會形成循環（domain-map §2〈無出邊是不變式〉）。

| 包裝型別 | 允許字元 | 長度 |
|---|---|---|
| 欄位名 | ASCII 英文字母、數字、`_`、`-`；首字元為英文字母 | 1～64 |
| 節點 ID | ASCII 英文字母、數字、`-`、`_`、`.` | 1～64 |

  字元集只防「任意字串」，不判斷 ID 是否合法；ID 是否符合 `id_pattern` 由 Schema 與 Corpus 判定，與日誌無關。

- commit SHA 只收小寫，大寫建構失敗，不轉小寫。git 輸出一律小寫；出現大寫代表上游有缺陷，應建構失敗使其浮上來，不由正規化吸收（2026-11-10 主控裁定，`1.0.0-W3-553.2.5`）。

- 兩個建構失敗時的替代值，值域由本規格固定，各 domain 不另訂：

| enum | 值 | 意義 |
|---|---|---|
| `LogLocation`（工作區外位置） | `appSupport` | App 自己的設定與狀態檔 |
| | `executable` | 外部程式的執行檔位置（`git`、`doc`） |
| | `system` | 作業系統位置（例：通知、暫存目錄） |
| | `other` | 以上皆非 |
| `LogIdentityRejected`（識別不合法） | `fieldNameRejected` | 欄位名不符字元集或長度 |
| | `nodeIdRejected` | 節點 ID 不符字元集或長度 |
- 例外物件只取 `runtimeType` 寫入 `error_type`，不呼叫 `toString()`，也不讀取 `message`。
- 解析器的診斷只記行號與欄位名，不引用原文行（〈2026-09-10〉C-2 風險來源 2）。

**驗收標準**：

- [ ] 以 `String` 作為 `fields` 值無法通過編譯
- [ ] 工作區外的絕對路徑無法建構為工作區相對路徑
- [ ] 帶例外物件的記錄，檔案內容不含例外的 `toString()` 結果（測試以內含標記字串的例外訊息作為正向對照）

---

### FR-04: LogSink 契約

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553.2 裁定 Q7（U-A）；併入 1.0.0-W3-549 |
| 對應用例 | — |

**描述**：全 App 只有一個 sink 型別：

```dart
typedef LogSink<E extends Enum> = void Function(
  E event,
  LogFields fields, {
  LogLevel level,
  ErrorSource? source,
  Object? error,
});
```

- 事件 enum 由各 domain 自行宣告並擁有，保留窮舉檢查；`event` 欄位即 enum 值名稱。
- `LogFields` 只接受 FR-03 的包裝型別。
- driven port 與解析器以建構參數注入 sink；生產預設值是共用 writer，測試注入記錄器並斷言事件碼與 fields，不斷言文案。

**約束條件**：

- 遷移時不得改名既有事件 enum 的值（測試斷言的穩定契約，見 SPEC-005、SPEC-007、SPEC-008 的日誌事件表）。
- 現有只收字串的 sink（DomainView、StaleOpen、Parse）遷移時須新增事件 enum。
- **writer 以外不得直接呼叫 `developer.log`**。現行 `lib/` 有大量直接呼叫（2026-11-10 盤點：123 處、43 檔，見 `1.0.0-W3-553.2` Problem Analysis），全數改經 sink 發出；遷移由 `1.0.0-W3-553.2.3` 承接。
- **高頻事件不得逐筆以 `info` 以上記錄**：掃描、監看等每個檔案觸發一次的事件記 `debug`（不寫檔，FR-05），或在一輪結束時聚合成一筆計數再以 `info` 記錄。理由：輪替依大小（FR-05），逐檔高頻記錄會把崩潰前的紀錄擠出保留範圍。

**驗收標準**：

- [ ] `lib/` 只剩一個 LogSink typedef
- [ ] 每個 sink 呼叫點傳入的第一個參數都是 enum 值
- [ ] `grep -rn "developer.log" lib/` 只命中共用 writer 的檔案
- [ ] 掃描與監看路徑中，逐檔觸發的事件皆為 `debug`，或以一輪一筆的聚合記錄取代

---

### FR-05: 落地位置與輪替

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553.2 裁定 Q3（L-A）、Q4（R-A） |
| 對應用例 | — |

**描述**：

| 項目 | 值 |
|---|---|
| 目錄 | `~/Library/Logs/<bundle id>/`；bundle id 於執行期取得，不寫死 |
| 現行檔 | `app.jsonl` |
| 輪替觸發 | 寫入前現行檔大小達 5 MiB |
| 輪替方式 | `app.(n).jsonl` 依序改名為 `app.(n+1).jsonl`，現行檔改名為 `app.1.jsonl`，再開新的 `app.jsonl` |
| 保留檔數 | 現行檔加 4 個歷史檔；超出者刪除。總量上限約 25 MiB |
| 寫入門檻 | `info` 以上寫檔；`debug` 只走 `developer.log` |

**約束條件**：

- 寫入在單一佇列中依序執行，避免兩筆記錄交錯成一行。
- 輪替門檻與保留檔數由 writer 的建構參數注入，生產預設值為上表數值。注入只供測試以小門檻驗證真實檔案系統上的改名與刪除順序，不提供使用者設定。
- 目錄不存在時於首次寫入前建立。
- 本目錄只放本規格的記錄檔，不放使用者內容的任何副本（〈2026-09-10〉C-1）。

**驗收標準**：

- [ ] 寫超過上限時確實輪替，且歷史檔數不超過 4（正向對照：寫入量超過上限的輸入）
- [ ] `debug` 記錄不出現在檔案中

---

### FR-06: 與 `developer.log` 並寫

| 項目 | 值 |
|------|-----|
| 優先級 | P2 |
| 來源 | 1.0.0-W3-553.2 裁定 Q8（D-A） |
| 對應用例 | — |

**描述**：每筆記錄同時轉呼 `developer.log`，開發時 DevTools 照舊可見。

| 信封 | `developer.log` 參數 |
|---|---|
| `domain` | `name` |
| `level` | `level`：debug 500、info 800、warning 900、error 1000 |
| `event` + `fields` | `message`：`<event> <fields 的 JSON>` |
| 例外物件 | `error`（僅在 `developer.log`，不進檔案） |

**約束條件**：

- 例外的完整內容與堆疊只進 `developer.log`（行程內、不落檔），不進檔案。
- **本對應取代舊慣例「level 900 = error」**（`.claude/rules/core/observability-rules.md` 規則 2 的專案註記）。遷移後 900 只表示 warning、1000 表示 error；遷移期間（`1.0.0-W3-553.2.3` 完成前）DevTools 中的 900 兩種語意並存，以 `name` 是否為 SPEC-010 的 domain 值區分。

**驗收標準**：

- [ ] 一筆記錄同時出現在檔案與 `developer.log`，兩邊的 `event` 一致

---

### FR-07: 全域攔截出口寫入記錄

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | 1.0.0-W3-553 子決策 3（structured log 全面解除延後） |
| 對應用例 | — |

**描述**：全域攔截三層的單一出口（`reportFatalError`）除了照舊通知畫面，另寫一筆記錄：`domain` = `presentation`、`event` = `fatalUncaught`、`level` = `error`、`error_source` = `internal`、`error_type` = 例外的 `runtimeType`、`fields` = `{interceptor: framework | platform | zone}`。

**約束條件**：寫入失敗不得影響畫面錯誤態的通知。

**驗收標準**：

- [ ] 觸發任一層攔截後，檔案中有一筆 `fatalUncaught`，且不含例外訊息全文

---

## 非功能需求

### NFR-01: 寫入失敗不擴散

| 項目 | 值 |
|------|-----|
| 類型 | 可用性 |
| 指標 | writer 失敗時，呼叫端零例外 |

**描述**：writer 無法寫檔時（目錄無權限、磁碟滿）不得拋出到呼叫端，也不得靜默：本 session 改為只寫 `developer.log`，並以 `developer.log` 記一筆 warning（每個 session 只記一次，避免每筆記錄都重報）。

---

## 錯誤處理

| 錯誤場景 | 錯誤碼 | 處理方式 | 使用者提示 |
|---------|--------|---------|-----------|
| log 目錄無法建立或無寫入權限 | `logDirUnavailable` | 本 session 降級為只寫 `developer.log`，記一次 warning | 無（log 不是使用者功能） |
| 寫入或輪替中途 IO 失敗 | `logWriteFailed` | 同上 | 無 |
| 包裝型別建構失敗 | — | 呼叫端改記對應的 enum（工作區外位置、識別不合法），不中斷原流程 | 無 |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 沙盒關閉 | App Sandbox 關閉（CLAUDE.md §6），可直接寫 `~/Library/Logs/` | 不需 entitlement |
| 單機、無傳送 | 記錄只落在本機，App 不上傳 | 無外送管道；使用者自行決定是否附上 log 求助 |
| bundle id 為佔位值 | 現值 `com.example.graphProjectDocsManager`；正式 bundle id 由 1.1.0-W1-098 處理 | 改 bundle id 後目錄隨之改變，舊目錄不遷移 |
| 本 domain 無出邊 | 本規格的型別不依賴任何 domain；工作區根路徑以純值傳入 | 避免與依賴本 domain 的 bundle 形成循環 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.1 | 2026-11-10 | FR-03：commit SHA 限小寫，大寫建構失敗（主控裁定）；FR-05：輪替門檻與保留檔數由建構參數注入，生產預設不變（1.0.0-W3-553.2.5 測試設計審查） |
| 1.0 | 2026-11-10 | 初始版本（1.0.0-W3-553.2.1） |
