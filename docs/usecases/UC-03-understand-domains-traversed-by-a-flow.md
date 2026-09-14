---
id: UC-03
title: "理解一條 flow 貫穿哪些 domain"
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

related_specs: [SPEC-001, SPEC-003]
related_usecases: []
ticket_refs: []
---

# UC-03: 理解一條 flow 貫穿哪些 domain

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-03 |
| 用例名稱 | 理解一條 flow 貫穿哪些 domain |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案，且目標 UC 具備結構化 flow 區塊 |
| 成功保證 | 使用者得知該 flow 的步驟序列、各步驟所屬 domain 與發送的事件 |

## 主要成功場景

1. **選定 UC**
   - 使用者自 UC Flow 視圖選擇一條 UC

2. **檢視步驟序列**
   - 系統以垂直步驟表呈現，domain 與發送事件各自成欄

3. **跳轉節點**
   - 使用者點選任一步驟，開啟該節點的詳情

4. **跳回 domain**
   - 使用者點選 domain 欄，切換至 Domain 視圖並定位該 domain

## 替代場景

### 檢視事件流

使用者沿發送事件欄理解該步驟發出的事件；消費資訊見事件流小表

## 流程拓撲（結構化 Flow 區塊）

> 本 flow 全程不發送也不消費事件——它是純檢視操作。`emits` / `consumes`
> 依 `FLOWSTEP_REQUIRED_FIELDS` 為必填，故逐步填空陣列。

```yaml
flow:
  - id: "select-uc"
    name: "選定 UC"
    next: ["view-steps"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "view-steps"
    name: "檢視步驟序列"
    next: ["jump-to-node"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["Layout"]
    implements: ["FR-06"]
  - id: "jump-to-node"
    name: "跳轉節點"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["Graph"]
  - id: "jump-to-domain"
    name: "跳回 domain"
    next: []
    branch_from: "view-steps"
    return_to: null
    emits: []
    consumes: []
    traverses: ["Layout"]
  - id: "inspect-event-flow"
    name: "檢視事件流"
    next: []
    branch_from: "view-steps"
    return_to: "view-steps"
    emits: []
    consumes: []
    traverses: ["Graph"]
  - id: "flow-block-absent"
    name: "UC 無結構化 flow"
    next: []
    branch_from: "select-uc"
    return_to: "select-uc"
    emits: []
    consumes: []
    traverses: ["Corpus"]
    implements: ["FR-06"]
```

## 例外場景

### UC 無結構化 flow

顯示 UC 基本資訊與明確說明，提供開啟原始檔的動作

### 專案無任何 UC

顯示說明並提供導覽至破洞報告的動作

## 驗收條件

> **前提已定案（2026-09-14）。** 步驟的 domain 來源為 `FlowStep.traverses`
> （步驟直接觸及的 domain 清單，0..n，純畫面步驟為空），定義見
> `docs/domain-map.md` §2.5；本 UC 的 flow 區塊已回填。schema 驗證由
> `0.1.0-W3-346` 提供。

- [ ] 步驟表的每一列同時呈現步驟名稱、該步驟 `traverses` 所列 domain 與發送事件
- [ ] 點選 domain 欄可跳轉至 Domain 視圖且定位正確
- [ ] 無結構化 flow 的 UC 仍可開啟，不顯示錯誤

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.3 | 2026-09-15 | 追修同步稽核裁決議題 P2（`0.1.0-W3-335.59` WRAP，`0.1.0-W3-335.63` 落檔）：`related_specs` 補 SPEC-003（內文〈檢視事件流〉引用 SPEC-003 §3.2 而 frontmatter 未列） |
| 1.2 | 2026-09-14 | 追修 spec 間矛盾（`0.1.0-W3-335.37` .36 #15）：替代場景〈檢視事件流〉改「沿發送事件欄」，消費資訊改指向事件流小表（步驟表僅有發送事件欄，消費資訊由 SPEC-003 §3.2〈事件流小表〉承載） |
| 1.1 | 2026-09-14 | 驗收前提改為已定案：步驟 domain 來源為 `FlowStep.traverses`（`0.1.0-W3-345` SR-2） |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
