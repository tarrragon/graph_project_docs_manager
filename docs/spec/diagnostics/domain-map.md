---
id: DOMAIN-MAP-diagnostics
domain: "diagnostics"
source_specs: [SPEC-006, SPEC-007]
related_usecases: [UC-05, UC-06]
depends_on_bundles: [DOMAIN-MAP-corpus]
path_patterns: [lib/diagnostics/]
created: "2026-08-26"
updated: "2026-10-13"
---

# Domain Map — Diagnostics

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Diagnostics domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Diagnostics domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：「什麼算破洞」的定義改變

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Corpus（`DOMAIN-MAP-corpus`） | 取解析錯誤事件（EVT-CORPUS-003、004、005），由此產生破洞 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Diagnostics | 是 | 破洞掃描完成通知（SPEC-003 §2.2〈系統層通知〉），App 啟動時自動觸發，不由使用者當下操作發起 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Diagnostics** | 「什麼算破洞」的定義改變 | 破洞清單（分類、嚴重度、跳轉目標） | 各類偵測規則 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test，不靠「剛好出現在某個 UC 場景」被動覆蓋。規則權威依破洞大類分屬三處：`parseFailure` 在 SPEC-006，`graphDefect` 在 SPEC-007，事件類（孤立事件、事件宣告與 flow 不符）的判準目前只寫在 SPEC-003 §3.5（各列的 SPEC 條款欄寫明出處）。本表只列可獨立斷言的不變式；目標路徑為 `lib/diagnostics/`（此為目標邊界，非現況：2026-09-24 規劃時該目錄尚不存在）。

`graphDefect` 的不變式落在本表而非 Graph 的 map（`0.5.0-W1-178`，判準見系統層 §8：驗收對象落在哪個 bundle 的公開面）：SPEC-007〈概述〉職責表與 `docs/spec/graph/domain-map.md` §7 皆把 SPEC-007 FR-09 單獨歸 Diagnostics，其驗收對象是破洞清單（本 bundle 公開面，§3）。缺陷的產生與 EVT-GRAPH-001 的筆數屬 Graph 的條款，不在本表重複。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC 條款 |
|---|---|---|
| Diagnostics | EVT-CORPUS-003、004、005 每一筆各對應一筆 `parseFailure` 破洞；破洞數 = 命中 carrier 數 + flow 區塊解析失敗的 UC 數 + 非 domain 路徑清單格式錯誤數（第三項為 0 或 1） | SPEC-006 FR-08 |
| Diagnostics | 查詢不可用時不產生 EVT-CORPUS-003 的 `parseFailure` 破洞，回報「無法判定」；EVT-CORPUS-004、005 的破洞不依賴路徑查詢，照常產生 | SPEC-006 FR-08 |
| Diagnostics | EVT-CORPUS-004 的破洞帶型別 UC，原因碼恆為 `flowBlockMalformed`；事件 reason 未以該原因碼開頭時寫 warning 日誌，破洞照常產生且原因碼不變 | SPEC-006 FR-08 |
| Diagnostics | EVT-CORPUS-005 的破洞不帶節點型別，原因碼為 `nonDomainPathsMalformed` 並帶子原因；與 EVT-CORPUS-003「平手」的區分載體是破洞子型別，不是節點型別欄的空值 | SPEC-006 FR-08 |
| Diagnostics | EVT-CORPUS-005 破洞的 `nonStringElementCount` 只在子原因為 `elementNotString` 時有值且為 1 以上，其餘子原因為空 | SPEC-006 FR-08 |
| Diagnostics | EVT-GRAPH-001 的 `graphDefects` 每一筆各對應一筆 `graphDefect` 破洞；破洞數 = `graphDefects` 筆數，不合併、不去重 | SPEC-007 FR-09 |
| Diagnostics | 主圖四子類的破洞負載：`danglingRef`、`malformedRef` 帶來源節點 ID 與路徑、欄位名、原始值、邊型、原因碼；`duplicateId` 帶 ID 與全部路徑；`multiSource` 帶起點、邊型、全部終點與各自的宣告來源 | SPEC-007 FR-09 |
| Diagnostics | flow 四子類的破洞負載一律為 {UC ID, step id, 欄位, 原始值}，不帶邊型；「domain 重複宣告」的負載為 {domain, 衝突的 DomainBundle ID 清單} | SPEC-007 FR-09 |
| Diagnostics | 破洞的原始值原樣保存，不正規化 | SPEC-007 FR-09 |
| Diagnostics | 建圖不可用時不產生任何 `graphDefect` 破洞，回報「無法判定」；無法判定原因取自 Diagnostics 既有列舉（編排層已轉換），Diagnostics 不依賴 Schema 的原因型別 | SPEC-007 FR-09 |
| Diagnostics | 孤立事件（`orphan-event`）每個符合判準的 EVT 一項：「有發出無消費」與「有消費無發出」兩形態各自三條件皆成立才列入；`category: process_event` 的 EVT 不列入；EVT 已宣告 `consumers`（或 `producers`）時不屬本類別 | SPEC-003 §3.5〈孤立事件判準〉 |
| Diagnostics | 事件宣告與 flow 不符（`event-declaration-mismatch`）每個未對應的宣告 domain 一項（同一 EVT 兩個 domain 未對應即兩項）；對應以 `traverses` 包含比對；`consumers` 的 `presentation` 比對 `traverses` 為空的步驟，`producers` 的 `presentation` 與未宣告值同視為未對應 | SPEC-003 §3.5〈事件宣告與 flow 不符判準〉 |
| Diagnostics | 兩類事件破洞的每一項帶 EVT id 與引用該 EVT 的 UC id 清單（任一 FlowStep `emits` 或 `consumes` 含之，依 UC id 排序）；無 UC 引用時清單為空；負載不含在地化字串 | SPEC-003 §3.5 設定入口 4、SPEC-001 §5 事件類主操作 |
| Diagnostics | 建圖不可用時不產生兩類事件破洞，回報「無法判定」 | SPEC-003 §3.5（比照 SPEC-007 FR-09 的無法判定語意） |

## 6. 待決事項

- `Diagnostics` 的破洞類別權威清單見 `EVT-DIAGNOSTICS-001`（本檔不複述計數），
  各類別下的具體項目與嚴重度尚未列舉。UC-06 的驗收條件依賴此清單

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-006（0.3.0 Corpus）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-08 | 由 EVT-CORPUS-003、004、005 產生 `parseFailure` 破洞 | Diagnostics | domain unit；IT-2 |

> SPEC-006 全表的權威在 `docs/spec/corpus/domain-map.md` §7；此處僅列歸屬本 domain 的列。

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-09 | 由 EVT-GRAPH-001 產生 `graphDefect` 破洞 | Diagnostics | domain unit；IT-2 |

> SPEC-007 全表的權威在 `docs/spec/graph/domain-map.md` §7；此處僅列歸屬本 domain 的列。Diagnostics 經 EVT-GRAPH-001 接收缺陷，不依賴 Graph 的內部結構。

---

**Last Updated**: 2026-10-20（`0.5.0-W1-114.22.1`：不變式清單補事件類破洞四列，判準出處 SPEC-003 §3.5；引言改為三處出處）；2026-10-13（`0.5.0-W1-176`：§2 出邊、不變式清單、§7 SPEC-006 FR-08 列對齊 EVT-CORPUS-004／005 之後的 SPEC-006 FR-08；不變式列同行寫明 SPEC id；`0.5.0-W1-178`：不變式清單引言改為兩份規格分屬並寫明 `graphDefect` 的落點依據，補 SPEC-007 FR-09 五列，欄名改「SPEC 條款」，既有五列未動） | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
