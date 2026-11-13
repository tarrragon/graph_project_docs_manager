---
id: UC-08
title: "在 App 內修正文件欄位"
status: draft
source_proposal: PROP-007
created: "2026-11-10"
updated: "2026-11-13"
version: "1.4"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001, SPEC-003, SPEC-004, SPEC-009]
related_usecases: [UC-06]
ticket_refs: [1.0.0-W3-553.8, 1.0.0-W3-553.9, 1.0.0-W3-553.10, 1.0.0-W3-553.11, 1.0.0-W3-553.12, 1.0.0-W3-553.13, 1.0.0-W3-553.14, 1.0.0-W3-553.15, 1.0.0-W3-553.16, 1.0.0-W3-553.17]
---

# UC-08: 在 App 內修正文件欄位

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-08 |
| 用例名稱 | 在 App 內修正文件欄位 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：看到錯誤的欄位值或破洞時，想直接在 App 內改掉，不必切到外部編輯器找位置、記合法值，也不能因此弄壞檔案或失去 git 救不回的內容 |
| 前置條件 | 已開啟專案，專案位於 git 工作樹內，且 `git` 可執行（否則整個工作區唯讀，見例外場景〈唯讀降級〉） |
| 成功保證 | 目標檔只有該欄位的值與已存在的 `updated` 被改變；寫入前若有 HEAD 沒有的內容，已留下快照與取回說明；使用者看得到寫入結果與驗證狀態 |

1.0 的寫入對象只有文件節點（PROP、SPEC、UC、EVT、DomainBundle）的純量欄位（SPEC-009〈概述〉）。1.1 起加入文件節點的關係邊，以本 UC 的替代場景〈修正關係邊〉與例外場景〈多檔寫入只成功一部分〉承載（`1.1.0-W1-111`）。ticket、內文、結構化區塊、檔案層級操作在 1.2～1.5 加入，屆時本 UC 擴充分支或另立 UC。

## 主要成功場景

1. **開始編輯**
   - 使用者在節點詳情選一個 1.0 可編輯的欄位，開始編輯（SPEC-009 FR-09 決定該欄位的輸入元件）
   - 系統記下目標檔此刻的內容，作為判定外部改動的基準，並對該檔跑一次驗證器作為 baseline（SPEC-009 FR-01、FR-05）
2. **修正欄位值**
   - 使用者輸入新值並送出
   - 系統依序檢查：目標檔是否被外部改過、局部改寫是否只動到該欄位、寫入前是否有 HEAD 沒有的內容需要先快照；全部通過才以暫存檔加 rename 寫入（SPEC-009 FR-01～FR-04）
3. **看到寫入結果**
   - 寫入受理為成功後，畫面才顯示新值（1.0 不做樂觀更新）；檔案監看偵測到變動後重新解析，圖譜隨之更新（SPEC-009 FR-05；SPEC-006 FR-11）
4. **看到驗證狀態**
   - 系統只對本次寫入的檔跑驗證器；與 baseline 相比沒有新問題時為通過（SPEC-009 FR-05）
   - 本 session 寫過的檔案與欄位列在寫入清單上，每列帶該次的驗證狀態（SPEC-009 FR-08）

## 替代場景

### 從破洞報告開始編輯

使用者在破洞報告點選一個指向圖節點的破洞項，選擇在 App 內修正。系統以該節點進入與步驟 1 相同的編輯，之後同主要場景。

**1.0 的適用集合為空**：1.0 只開放文件節點的純量欄位，而破洞的成因全在 1.0 不可編輯的欄位上：邊欄位（1.1）、id 與 domain 名（唯讀）、flow 區塊（1.4）、ticket 的 `where.files`（1.2）、解析失敗（沒有節點）、舊版缺欄位（要新增鍵，SPEC-009 FR-03 改寫隔離不允許）。1.0 不渲染此入口，本場景自 1.1 開放邊欄位起適用；各破洞類別的適用表見 SPEC-001 §5〈破洞報告的編輯入口〉（用戶裁定 2026-11-11，`1.0.0-W3-553.3`）。

**1.1 起以破洞項判定**：入口是否出現，逐一看每個破洞項：要能定出要編輯的文件節點與目標欄位，且目標欄位在當下 minor 可直接編輯（PROP 的 `outputs` 只作為反向檔改寫，不算）。同一類別裡，成因是 ticket 欄位的項目到 1.2 才出現入口（SPEC-001 §5〈逐項判定規則〉，`1.1.0-W1-111`）。

### 修正關係邊（1.1）

使用者在步驟 1 選的是文件節點的邊欄位，例如 UC 的 `related_specs`、SPEC 的 `source_proposal`，輸入元件依 SPEC-009 FR-09。沒有反向欄位的邊，寫入方式同步驟 2。SPEC、UC、EVT 的 `source_proposal` 有反向欄位：每次加入或移除一個 PROP，系統把該 PROP 的 `outputs` 一起改寫（加入寫進依型別決定的清單，移除刪掉所有清單中的該 id），所有檔都通過寫入前檢查才寫入；先寫 PROP，最後寫正向檔（SPEC-009 FR-03〈多檔寫入（1.1）〉，v1.11）。移除的值指向不存在的 PROP（斷邊）時，略過該 PROP，只寫正向檔。之後同主要場景步驟 3。

### 寫入前已有未提交的變更

目標檔與 HEAD 不同（含未追蹤檔）時，系統先把寫入前的內容快照到使用者自己的 git object database 再寫入，並在寫入結果中顯示快照回饋與取回說明；說明會寫明快照受 git gc 期限限制，不稱為備份（SPEC-009 FR-02）。之後同主要場景步驟 3。

### 編輯中收到外部改動預警

使用者編輯期間，檔案監看偵測到變動，Corpus 重新解析後發出 CorpusParsed（EVT-CORPUS-001）。Edit 收到後重讀正在編輯的檔案並與開始編輯時的內容比較，不同即轉為外部已改預警，未送出的值保留；使用者仍可送出，由步驟 2 的檢查判定（SPEC-009 FR-06）。EVT-CORPUS-002 是 Corpus 內部的觸發訊號，不跨界，Edit 不消費它。

### 驗證發現新問題

寫入後驗證器回報 baseline 沒有的問題。驗證狀態顯示新增問題數與取回說明，檔案不會被自動改回；使用者可再修正欄位值，回到步驟 2（SPEC-009 FR-05）。

### 無法驗證

`uv` 或 doc CLI 無法執行、或輸出無法解析時，驗證狀態顯示無法驗證，不視為通過。寫入結果不受影響，使用者可繼續編輯（SPEC-009 FR-05）。

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "begin-editing"
    name: "開始編輯"
    next: ["revise-field"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "revise-field"
    name: "修正欄位值"
    next: ["see-write-result"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["edit", "schema", "corpus"]
  - id: "see-write-result"
    name: "看到寫入結果"
    next: ["see-validation-status"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["edit", "corpus", "graph"]
  - id: "see-validation-status"
    name: "看到驗證狀態"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "begin-from-gap-report"
    name: "從破洞報告開始編輯"
    next: []
    branch_from: "begin-editing"
    return_to: "revise-field"
    emits: []
    consumes: []
    traverses: ["diagnostics", "edit"]
  - id: "snapshot-before-write"
    name: "寫入前已有未提交的變更"
    next: []
    branch_from: "revise-field"
    return_to: "see-write-result"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "external-change-warning"
    name: "編輯中收到外部改動預警"
    next: []
    branch_from: "revise-field"
    return_to: "revise-field"
    emits: []
    consumes: ["EVT-CORPUS-001"]
    traverses: ["corpus", "edit"]
  - id: "validation-found-issues"
    name: "驗證發現新問題"
    next: []
    branch_from: "see-validation-status"
    return_to: "revise-field"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "validation-unavailable"
    name: "無法驗證"
    next: []
    branch_from: "see-validation-status"
    return_to: "revise-field"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "externally-modified"
    name: "外部已改，放棄並重讀"
    next: []
    branch_from: "revise-field"
    return_to: "begin-editing"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "write-not-completed"
    name: "寫入未完成"
    next: []
    branch_from: "revise-field"
    return_to: "revise-field"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "revise-relation"
    name: "修正關係邊"
    next: []
    branch_from: "revise-field"
    return_to: "see-write-result"
    emits: []
    consumes: []
    traverses: ["edit", "schema", "corpus"]
  - id: "partially-written"
    name: "多檔寫入只成功一部分"
    next: []
    branch_from: "revise-relation"
    return_to: "revise-field"
    emits: []
    consumes: []
    traverses: ["edit"]
  - id: "read-only-workspace"
    name: "唯讀降級"
    next: []
    branch_from: "begin-editing"
    return_to: null
    emits: []
    consumes: []
    traverses: ["workspace", "edit"]
```

`traverses` 不列 `observability`，慣例見 `docs/system-layer.md` §1.4「貫穿」。

`ticket_refs` 目前為空：edit 的實作票由 `1.0.0-W3-553.7`（version-bootstrap 匯總建票）建立並回填。回填前，本 UC 會因缺 `uc_ticket_refs` 必要邊而出現在破洞報告，這是已知狀態。

## 例外場景

### 外部已改，放棄並重讀

步驟 2 檢查時目標檔已被外部改過（含寫入前最後一刻的重讀），寫入結果為閘門阻擋（外部已改），檔案不動。使用者選擇放棄並重讀，系統以磁碟上的內容重新開始編輯並重跑驗證 baseline，回到步驟 1（SPEC-009 FR-01、FR-06）。

### 寫入未完成

快照失敗、局部改寫無法隔離（例如欄位值使用 anchor 或 block scalar），或讀寫 IO 失敗時，寫入結果分別為閘門阻擋（快照失敗）、閘門阻擋（改寫不隔離）與 IO 失敗，目標檔維持原內容，不殘留暫存檔。畫面說明檔案未改；改寫不隔離時提示改用外部編輯器（SPEC-009〈錯誤處理〉）。使用者可調整後再送出，回到步驟 2。

### 多檔寫入只成功一部分（1.1）

修正關係邊時，寫入集合中有些檔已經寫入、後面的檔寫入失敗。系統依相反順序把已寫入的檔還原為寫入前的內容。全部還原成功時，畫面說明這次寫入未完成，所有檔維持原內容，同〈寫入未完成〉。有檔還原失敗時，寫入結果為只成功一部分：畫面列出已改動且未還原的檔案，每個檔附取回說明，使用者依說明在 App 外還原（SPEC-009 FR-03、FR-05）。使用者可回到步驟 2 再送出。

### 唯讀降級

工作區不是 git repo，或 `git` 無法執行時，系統在開啟工作區時就判定整個工作區唯讀，常駐降級徽章，編輯控制項不可用，任何寫入路徑都不可達（SPEC-009 FR-01）。

## 驗收條件

- [ ] 節點詳情入口能進入編輯流程；破洞報告入口 1.0 適用集合為空、不渲染，1.1 啟用後兩個入口進入同一個編輯流程
- [ ] 寫入結果三種（成功、閘門阻擋、IO 失敗）由畫面區分，失敗時目標檔不變
- [ ] 寫入成功後才顯示新值；驗證狀態與寫入結果分開呈現，驗證失敗不改回檔案
- [ ] 編輯中外部改動會出現預警，送出時仍由寫入前檢查判定
- [ ] 非 git 工作區或 `git` 無法執行時整個工作區唯讀並常駐徽章
- [ ] 本 session 的寫入清單每列帶驗證狀態，且不含欄位值
- [ ] 1.1：對 SPEC、UC、EVT 的 `source_proposal` 加入或移除一個 PROP 後，該 PROP 的 `outputs` 與新值一致（移除時所有子鍵都不再含該 id）；多檔寫入中途失敗時，所有檔還原為原內容，或回傳只成功一部分並附各檔取回說明
- [ ] 1.1：破洞報告入口只出現在能定出目標欄位、且該欄位在當下 minor 可直接編輯的破洞項上（SPEC-001 §5〈逐項判定規則〉條件 3）

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-11-10 | 初版（`1.0.0-W3-553.5`，version-bootstrap Step 4，PROP-007、SPEC-009） |
| 1.1 | 2026-11-11 | `1.0.0-W3-553.3`（用戶裁定 2026-11-11）：〈從破洞報告開始編輯〉與對應驗收標明 1.0 適用集合為空、入口不渲染，1.1 啟用；適用表見 SPEC-001 §5 |
| 1.2 | 2026-11-11 | `1.0.0-W3-553.7`：回填 `ticket_refs`，填入 edit 實作票 553.8–553.14 與畫面票 553.15–553.17，消除 uc_ticket_refs 缺口（同 UC-07 v1.2） |
| 1.3 | 2026-11-12 | `1.1.0-W1-111`（1.1 規劃波 Step 4）：新增替代場景〈修正關係邊（1.1）〉與例外場景〈多檔寫入只成功一部分（1.1）〉，flow 補 `revise-relation`、`partially-written` 兩步；〈從破洞報告開始編輯〉補上 1.1 以破洞項判定；驗收補 2 條。`ticket_refs` 由 Step 6 建票後回填 |
| 1.4 | 2026-11-13 | `1.1.0-W1-111`（對齊 SPEC-009 v1.11，用戶裁定 2026-11-13）：〈修正關係邊（1.1）〉與對應驗收的反向欄位由 SPEC 擴及 UC、EVT 的 `source_proposal`，改為以單次加入或移除描述，移除時刪除 `outputs` 所有子鍵中的該 id。〈從破洞報告開始編輯〉與對應驗收的判定改為「目標欄位可直接編輯」，對齊 SPEC-001 v1.93 條件 3 |
