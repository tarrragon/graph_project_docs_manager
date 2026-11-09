---
id: UC-04
title: "追溯一項需求的實現鏈"
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-11-09"
version: "1.6"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001, SPEC-002, SPEC-003, SPEC-004, SPEC-007]
related_usecases: []
ticket_refs: [0.1.0-W2-007, 0.1.0-W3-127, 0.1.0-W3-380, 0.1.0-W3-383, 0.3.3-W3-401]
---

# UC-04: 追溯一項需求的實現鏈

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-04 |
| 用例名稱 | 追溯一項需求的實現鏈 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案且圖譜可用 |
| 成功保證 | 使用者得知該需求展開為哪些規格、用例與 ticket，以及鏈路在哪一層中斷 |

## 主要成功場景

1. **展開提案**
   - 使用者在追溯視圖展開一個 PROP

2. **展開下游**
   - 系統以樹狀呈現 PROP → SPEC → UC → Ticket

3. **檢視狀態**
   - 各層節點顯示其 status，缺口層以虛線框標示

4. **跳轉細節**
   - 使用者點選任一節點開啟詳情

## 替代場景

### 反向追溯

使用者自 Ticket 出發，沿各跳的邊往上追溯至來源提案

**重評結論（`0.6.0-W1-110`）：資料前提已具備，畫面互動未規格化，0.6 不涵蓋。**
各層的「向上」欄位在 UC → Ticket 邊定案後皆已存在，每一跳讀的邊與追溯視圖該跳相同，只是方向相反
（SPEC-001 §3〈四層樹由掃描輪次衍生〉）：

| 向上跳 | 取法 |
|--------|------|
| Ticket → UC | 反查：`ticket_refs` 含該 ticket id 的 UC |
| UC → SPEC | 正查：UC 的 `related_specs` |
| SPEC → PROP | 正查：SPEC 的 `source_proposal` |

原寫法的 `source_ticket` 是 ticket 之間的衍生邊，`implements_requirements` 也不是
追溯視圖所取的邊，兩者都不在本場景的路徑上，已改寫。

**互動規格（v1.6）**：三跳的邊型與讀取方向、缺口判定見 SPEC-001 §3〈反向追溯〉；
互動反應與錨點見 SPEC-003 §3.3〈反向追溯〉。入口位置、反向樹的呈現形態與多 UC 分支的
展開方式尚待用戶裁決，兩份規格中以「待定」標示，下列 GWT 只寫與這些抉擇無關的可觀察結果。

| 向上跳 | 邊（`GRAPH_EDGE_TYPES` 鍵名） | 讀取方向 |
|--------|------|------|
| Ticket → UC | `uc_ticket_refs`（UC 的 `ticket_refs`） | 逆 forward 方向：找 `ticket_refs` 含該 ticket id 的 UC |
| UC → SPEC | `spec_association`（UC 的 `related_specs`） | 沿 forward 方向：讀該 UC 的 `related_specs` |
| SPEC → PROP | `provenance`（SPEC 的 `source_proposal`） | 沿 forward 方向：讀該 SPEC 的 `source_proposal` |

#### GWT

**場景 R1：完整上溯**
- Given 最後完成輪次建圖可用，ticket T 被 UC U 的 `ticket_refs` 列出，U 的 `related_specs` 含 SPEC S，S 的 `source_proposal` 含 PROP P
- When 使用者自 T 啟動反向追溯
- Then 反向樹以 T 為起點，依序呈現 U、S、P 三層，各節點帶其 status，不顯示缺口標示

**場景 R2：多 UC 指向同一票**
- Given T 同時被 UC U1、U2 的 `ticket_refs` 列出
- When 使用者自 T 啟動反向追溯
- Then U1、U2 皆作為 T 的上層節點出現，各自往上展開其 SPEC 與 PROP；同一 SPEC 或 PROP 經兩條路徑抵達時，於每條路徑下各出現一次

**場景 R3：票未被任何 UC 列出**
- Given 沒有任何 UC 的 `ticket_refs` 含 T
- When 使用者自 T 啟動反向追溯
- Then T 下方以虛線框標示缺口（缺上游），樹止於 T

**場景 R4：中間層缺上游**
- Given U 的 `related_specs` 為空，或 S 的 `source_proposal` 為 null
- When 使用者自 T 啟動反向追溯
- Then 該 UC 或 SPEC 下方以虛線框標示缺口，其餘分支照常展開；缺口標示可跳轉破洞報告

**場景 R5：指向不存在的節點**
- Given U 的 `related_specs` 只列出圖上不存在的 SPEC id
- When 使用者自 T 啟動反向追溯
- Then 該 id 不成節點，U 的缺口判定與 `related_specs` 為空相同（場景 R4）

**場景 R6：點選上層節點**
- Given 反向樹已呈現
- When 使用者點選其中任一節點
- Then 開啟該節點的詳情（與主要成功場景步驟 4 相同）

## 流程拓撲（結構化 Flow 區塊）

> 本 flow 全程不發送也不消費事件——它是純檢視操作。`emits` / `consumes`
> 依 `FLOWSTEP_REQUIRED_FIELDS` 為必填，故逐步填空陣列。

```yaml
flow:
  - id: "select-proposal"
    name: "展開提案"
    next: ["expand-downstream"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "expand-downstream"
    name: "展開下游"
    next: ["inspect-status"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "inspect-status"
    name: "檢視狀態"
    next: ["jump-to-detail"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "jump-to-detail"
    name: "跳轉細節"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-001"]
    traverses: ["graph", "ticketdetail"]
  - id: "reverse-trace"
    name: "反向追溯"
    next: ["inspect-status"]
    branch_from: "select-proposal"
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "chain-broken"
    name: "鏈路中斷"
    next: []
    branch_from: "expand-downstream"
    return_to: "expand-downstream"
    emits: []
    consumes: []
    traverses: ["graph"]
```

## 例外場景

### 鏈路中斷

某層無下游節點時以虛線框標示該缺口，並提供跳轉破洞報告的動作

### 專案無提案

顯示說明並提供導覽至破洞報告的動作

## 驗收條件

> **前提未滿足。** 第三跳（UC → Ticket）在上游 16 條語意邊中無對應邊；
> 第二跳（PROP → SPEC → UC）走 `SPEC.related_usecases` 或 `UC.source_proposal`
> 會得到不同的樹，欄位未明訂。兩項皆列於 `docs/system-layer.md` §6。
> 本批文件自身即是反例：UC-01 自報來自 PROP-003，但經 SPEC-001 展開會
> 出現在 PROP-004 底下。

- [ ] 樹狀結構完整呈現四層，缺口層以視覺差異標示而非省略
      （第三跳無邊、第二跳欄位未定，見 §9）
- [ ] 反向追溯可自 Ticket 出發上溯至 PROP，三跳依〈反向追溯〉表的邊與方向，
      缺上游的節點以虛線框標示（場景 R1–R5；入口與呈現形態待用戶裁決）
- [ ] 點選節點開啟的詳情與該節點一致，且部分損壞的節點仍能開啟

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.6 | 2026-11-09 | 〈反向追溯〉補互動規格：三跳邊型（`uc_ticket_refs`／`spec_association`／`provenance`）與讀取方向表、GWT 場景 R1–R6；刪「尚未規格化」段，改指向 SPEC-001 §3、SPEC-003 §3.3 的〈反向追溯〉；入口、反向樹呈現、多 UC 分支展開方式標待定；驗收條件第二項改寫。flow 區塊不動 |
| 1.5 | 2026-11-03 | `related_specs` 對齊 SPEC 端宣告（`0.6.0-W1-116`，用戶裁定 B：UC 列出畫面所依賴的每一份 SPEC，橫切 SPEC 亦列）：補 SPEC-002、SPEC-003、SPEC-004、SPEC-007（追溯樹由建圖結果衍生）；不動正文與結構化 flow |
| 1.4 | 2026-11-03 | `0.6.0-W1-104`：`ticket_refs` 由 `[]` 回填 5 張實作票（依該票〈入選判準修訂版〉，以 lib/screens/trace/ 為對照目錄）；不動正文與結構化 flow 區塊 |
| 1.3 | 2026-11-02 | `0.6.0-W1-110`：〈反向追溯〉依 UC → Ticket 新邊重評——各層向上欄位已具備（Ticket → UC 反查 `ticket_refs`、UC → SPEC 取 `related_specs`、SPEC → PROP 取 `source_proposal`），更正原寫法的 `source_ticket`／`implements_requirements` 路徑；畫面互動未規格化，0.6 不涵蓋，排入與否由 PM 裁定。驗收條件註記同步。flow 區塊不動 |
| 1.2 | 2026-10-21 | `0.5.0-W1-458.2`（458 用戶裁定類 B）：`jump-to-detail` 補 consumes `EVT-CORPUS-001`（TicketDetail 取 5W1H 全文）；不新增步驟，EVT 宣告不動 |
| 1.1 | 2026-09-14 | 追修 spec 間矛盾（`0.1.0-W3-335.37` R8）：主要成功場景步驟 1「選定提案」改「展開提案」，flow 區塊 `select-proposal` 的 `name` 同步；替代場景〈反向追溯〉標「0.1 規格未涵蓋」並補缺的前提，重評條件綁 `0.1.0-W3-365` |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
