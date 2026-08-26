---
id: UC-02
title: "依 domain 盤點變更影響面"
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

## 主要成功場景

1. **定位 domain**
   - 使用者在矩陣中找到要變更的 domain 列

2. **讀取貫穿數**
   - 該列的小計欄顯示被幾條 UC flow 直接貫穿

3. **切換至泳道**
   - 點選交叉格，系統切換至泳道模式並定位至該 domain 與該 UC

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
  - id: "read-traversal-count"
    name: "讀取貫穿數"
    next: ["switch-to-swimlane"]
    branch_from: null
    return_to: null
  - id: "switch-to-swimlane"
    name: "切換至泳道"
    next: ["inspect-steps"]
    branch_from: null
    return_to: null
    consumes: ["EVT-LAYOUT-001"]
  - id: "inspect-steps"
    name: "檢視步驟"
    next: []
    branch_from: null
    return_to: null
  - id: "matrix-overview-only"
    name: "僅檢視全貌"
    next: []
    branch_from: "read-traversal-count"
    return_to: null
  - id: "enter-from-ticket"
    name: "由 ticket 切入"
    next: ["read-traversal-count"]
    branch_from: "locate-domain"
    return_to: null
  - id: "flow-not-structured"
    name: "flow 未結構化"
    next: []
    branch_from: "switch-to-swimlane"
    return_to: "locate-domain"
    implements: ["FR-06"]
```

## 例外場景

### flow 未結構化

該 UC 無 FlowStep 時，泳道無法呈現步驟；顯示說明並提供開啟原始檔的動作

### ticket 無法定位

where.files 無法對應到任何 domain 時標記為無法定位，並列入破洞報告

## 驗收條件

- [ ] 矩陣的每一格明確區分直接貫穿、間接依賴、無關三種狀態
- [ ] 點選交叉格後泳道定位至正確的 domain 與 UC，不需使用者再次搜尋
- [ ] UC 無結構化 flow 時顯示 UC 基本資訊與說明，而非空白或錯誤

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
