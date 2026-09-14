---
id: UC-02
title: "依 domain 盤點變更影響面"
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-09-15"
version: "1.3"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001]
related_usecases: []
ticket_refs: []
---

# UC-02: 依 domain 盤點變更影響面

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-02 |
| 用例名稱 | 依 domain 盤點變更影響面 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案且 Domain 視圖可用 |
| 成功保證 | 使用者得知該 domain 被哪些 UC flow 貫穿，以及各自貫穿的步驟 |

> 「貫穿」＝一條 UC flow 經過某個 domain，是圖上的水平關係、可計數。
> 與「穿透」（兩視圖間的雙向導覽操作）不同，定義見 `docs/domain-map.md` §2.5。

## 主要成功場景

1. **定位 domain**
   - 使用者在矩陣中找到要變更的 domain 列

2. **讀取貫穿數**
   - 該列的小計欄顯示被幾條 UC flow 直接貫穿

3. **切換至泳道**
   - 點選交叉格顯示格詳情；點選「在泳道中檢視」後系統切換至泳道模式並定位至該 domain 與該 UC

4. **檢視步驟**
   - 泳道呈現該 flow 的步驟序列，貫穿該 domain 的步驟高亮

## 替代場景

### 僅檢視全貌

使用者停留在矩陣模式比較各 domain 的貫穿數，不進入泳道

### 由 ticket 切入

使用者自 ticket 的 where.files 反查所屬 domain，系統高亮該列

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "locate-domain"
    name: "定位 domain"
    next: ["read-traversal-count"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "read-traversal-count"
    name: "讀取貫穿數"
    next: ["switch-to-swimlane"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["Graph"]
  - id: "switch-to-swimlane"
    name: "切換至泳道"
    next: ["inspect-steps"]
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-LAYOUT-001"]
    traverses: ["Layout"]
  - id: "inspect-steps"
    name: "檢視步驟"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "matrix-overview-only"
    name: "僅檢視全貌"
    next: []
    branch_from: "read-traversal-count"
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "enter-from-ticket"
    name: "由 ticket 切入"
    next: ["read-traversal-count"]
    branch_from: "locate-domain"
    return_to: null
    emits: []
    consumes: []
    traverses: ["Graph", "TicketDetail"]
  - id: "flow-not-structured"
    name: "flow 未結構化"
    next: []
    branch_from: "switch-to-swimlane"
    return_to: "locate-domain"
    emits: []
    consumes: []
    traverses: ["Corpus"]
    implements: ["FR-06"]
```

## 例外場景

### flow 未結構化

該 UC 無 FlowStep 時，泳道無法呈現步驟；顯示說明並提供開啟原始檔的動作

### ticket 無法定位

where.files 無法對應到任何 domain 時標記為無法定位，並列入破洞報告

## 驗收條件

> **前提部分未滿足，本 UC 的第 1、4 條驗收目前不可實作。** 矩陣的格
> （step → domain）已定案為 `FlowStep.traverses`（`docs/domain-map.md` §2.5，
> 2026-09-14）。仍未滿足兩項：矩陣的列（domain 清單）無資料來源——個別 domain
> 不是圖節點；「路徑模式 → domain」對照表歸屬已定（Graph）但內容未建
> （`0.1.0-W3-352`）。兩項皆列於 `docs/domain-map.md` §9。排版本順序時，
> 這些前置必須先綠燈。

- [ ] 矩陣的每一格明確區分直接貫穿、間接依賴、無關三種狀態
      （「直接貫穿」判定式為 `FlowStep.traverses` 包含（`0.1.0-W3-345`）；
      「間接依賴」判定式未定義，見 §9）
- [ ] 點選交叉格後泳道定位至正確的 domain 與 UC，不需使用者再次搜尋
- [ ] UC 無結構化 flow 時顯示選定 UC 標題與說明，而非空白或錯誤
- [ ] ticket 的 `where.files` 對應不到任何 domain 時標記為無法定位，
      並列入破洞報告的 `unlocatable` 類（見 `EVT-DIAGNOSTICS-001`）

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.3 | 2026-09-15 | 追修門檻外矛盾（`0.1.0-W3-335.68`，依 `0.1.0-W3-335.65` WRAP 裁決 K2 可同步部分）：驗收條件第 1 條括號註「『直接貫穿』與『間接依賴』的判定式皆未定義」已過時，改「『直接貫穿』判定式為 `FlowStep.traverses` 包含（`0.1.0-W3-345`）；『間接依賴』判定式未定義，見 §9」；「間接依賴」判定式本身屬 CLAUDE.md §6 待決，本輪不裁 |
| 1.2 | 2026-09-14 | 追修 spec 間矛盾（`0.1.0-W3-335.37` R5、R1）：步驟 3 改為「點選交叉格顯示格詳情；點『在泳道中檢視』切至泳道」（.36 #12）；驗收條件第 3 條「UC 基本資訊」改「選定 UC 標題」（.36 #6） |
| 1.1 | 2026-09-14 | 驗收前提更新：格的來源已定案為 `FlowStep.traverses`，列的來源與路徑對照表內容仍未滿足（`0.1.0-W3-345` SR-2） |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
