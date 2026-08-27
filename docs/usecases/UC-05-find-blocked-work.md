---
id: UC-05
title: "找出被阻擋的工作"
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

# UC-05: 找出被阻擋的工作

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-05 |
| 用例名稱 | 找出被阻擋的工作 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案 |
| 成功保證 | 使用者得知哪些 ticket 被阻擋、被誰阻擋，以及各主題的進度分佈 |

## 主要成功場景

1. **進入 ticket 清單**
   - 使用者導覽至 Ticket 清單；首次進入時顯示載入提示與預估耗時

2. **觸發載入**
   - 使用者確認載入，系統解析全部 ticket 並顯示進度

3. **切換至主題模式**
   - 使用者切換分組軸，系統依主題呈現各節與未歸屬節

4. **定位阻擋**
   - 使用者展開主題，檢視各票的 status 與 blockedBy

## 替代場景

### 列表模式篩選

使用者停留在列表模式，以搜尋與篩選定位特定票

### 自破洞報告切入

使用者自破洞報告的損壞票項跳轉至該票

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "enter-ticket-list"
    name: "進入 ticket 清單"
    next: ["trigger-load"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    implements: ["FR-02"]
  - id: "trigger-load"
    name: "觸發載入"
    next: ["switch-to-topic"]
    branch_from: null
    return_to: null
    emits: ["EVT-CORPUS-001"]
    consumes: []
  - id: "switch-to-topic"
    name: "切換至主題模式"
    next: ["locate-blocked"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "locate-blocked"
    name: "定位阻擋"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "filter-in-list-mode"
    name: "列表模式篩選"
    next: []
    branch_from: "switch-to-topic"
    return_to: "switch-to-topic"
    emits: []
    consumes: []
  - id: "cancel-loading"
    name: "載入期間離開"
    next: []
    branch_from: "trigger-load"
    return_to: "enter-ticket-list"
    emits: []
    consumes: []
    implements: ["FR-02"]
  - id: "damaged-tickets"
    name: "含損壞票"
    next: []
    branch_from: "trigger-load"
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-003"]
    implements: ["FR-05"]
```

## 例外場景

### 載入期間離開

使用者於載入期間取消或切換畫面，系統中止載入並保持可操作

### 含損壞票

解析失敗的票以徽章標示，其可讀欄位仍呈現，損失欄位標示無法讀取

## 驗收條件

- [ ] 首次進入不自動載入，且載入提示標明筆數與預估耗時
- [ ] 載入期間取消操作可用，取消後回到未載入狀態
- [ ] 主題節標題呈現票數與最高優先級，排序為最高優先級後接票數降冪；
      **無有效 `priority` 的主題排最後**（tie-break，規格見 PROP-004 §分組軸）
- [ ] 主題歸屬讀自 `docs/work-logs/topic-assignments.txt` 與
      `topics-registry.txt` 兩檔，**非 ticket frontmatter**（格式與不變式
      見 PROP-004 §對 Corpus domain 的影響）
- [ ] 未歸屬票獨立成節置於全部主題節之後，不與任一主題混列

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
