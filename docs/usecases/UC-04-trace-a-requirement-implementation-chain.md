---
id: UC-04
title: "追溯一項需求的實現鏈"
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-08-26"
version: "1.0"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001]
related_usecases: []
ticket_refs: []
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

1. **選定提案**
   - 使用者在追溯視圖選擇一個 PROP

2. **展開下游**
   - 系統以樹狀呈現 PROP → SPEC → UC → Ticket

3. **檢視狀態**
   - 各層節點顯示其 status，缺口層以虛線框標示

4. **跳轉細節**
   - 使用者點選任一節點開啟詳情

## 替代場景

### 反向追溯

使用者自 Ticket 出發，沿 source_ticket 與 implements_requirements 往上追溯至來源提案

## 流程拓撲（結構化 Flow 區塊）

> 本 flow 全程不發送也不消費事件——它是純檢視操作。`emits` / `consumes`
> 依 `FLOWSTEP_REQUIRED_FIELDS` 為必填，故逐步填空陣列。

```yaml
flow:
  - id: "select-proposal"
    name: "選定提案"
    next: ["expand-downstream"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "expand-downstream"
    name: "展開下游"
    next: ["inspect-status"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "inspect-status"
    name: "檢視狀態"
    next: ["jump-to-detail"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "jump-to-detail"
    name: "跳轉細節"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "reverse-trace"
    name: "反向追溯"
    next: ["inspect-status"]
    branch_from: "select-proposal"
    return_to: null
    emits: []
    consumes: []
  - id: "chain-broken"
    name: "鏈路中斷"
    next: []
    branch_from: "expand-downstream"
    return_to: "expand-downstream"
    emits: []
    consumes: []
```

## 例外場景

### 鏈路中斷

某層無下游節點時以虛線框標示該缺口，並提供跳轉破洞報告的動作

### 專案無提案

顯示說明並提供導覽至破洞報告的動作

## 驗收條件

> **前提未滿足。** 第三跳（UC → Ticket）在上游 16 條語意邊中無對應邊；
> 第二跳（PROP → SPEC → UC）走 `SPEC.related_usecases` 或 `UC.source_proposal`
> 會得到不同的樹，欄位未明訂。兩項皆列於 `docs/domain-map.md` §9。
> 本批文件自身即是反例：UC-01 自報來自 PROP-003，但經 SPEC-001 展開會
> 出現在 PROP-004 底下。

- [ ] 樹狀結構完整呈現四層，缺口層以視覺差異標示而非省略
      （第三跳無邊、第二跳欄位未定，見 §9）
- [ ] 反向追溯可自任一層出發，不限於自 PROP 開始
      （各層的「向上」欄位對照表尚未建立）
- [ ] 點選節點開啟的詳情與該節點一致，且部分損壞的節點仍能開啟

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
