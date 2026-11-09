---
id: UC-07
title: "回顧一段期間內的關係變動"
status: draft
source_proposal: PROP-006
created: "2026-11-09"
updated: "2026-11-09"
version: "1.0"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001, SPEC-002, SPEC-003, SPEC-004, SPEC-008]
related_usecases: []
ticket_refs: []
---

# UC-07: 回顧一段期間內的關係變動

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-07 |
| 用例名稱 | 回顧一段期間內的關係變動 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：版本收尾或回顧時，需知道這段期間新增與移除了哪些文件關係，包含現在已不存在的關係 |
| 前置條件 | 已開啟專案，且專案位於 git 工作樹內 |
| 成功保證 | 使用者看到期間內每一筆邊事件（新增或移除、邊型、兩端節點、commit、日期、作者），並可跳至任一端節點 |

## 主要成功場景

1. **進入變更記錄**
   - 使用者導覽至第七畫面「變更記錄」（SPEC-001 §10）
2. **讀取 git 歷史**
   - 沒有可用快取時，系統讀取主線歷史並顯示已處理的 commit 數（SPEC-008 FR-01、FR-02、FR-09）
3. **檢視預設期間**
   - 系統依預設期間（最近一個版本 tag 至今；無版本 tag 時最近 30 天）列出邊事件，由新到舊，預設排除 ticket 建檔事件（SPEC-008 FR-06、FR-07）
4. **前往節點**
   - 使用者點事件列上的宣告端或對端節點，前往節點詳情；節點已不在目前的圖上時，節點詳情顯示對應狀態

## 替代場景

### 變更期間

使用者改選「最近 30 天」或「全部歷史」，清單依新期間重新列出，不重新讀取

### 包含 ticket 建檔事件

使用者打開「包含 ticket 建檔」，清單加入因新建 ticket 檔案而產生的新增事件

### 期間內沒有事件

預設期間沒有任何事件時，畫面顯示空狀態，使用者按「顯示全部歷史」擴大範圍（SPEC-001 FR-03）

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "enter-history"
    name: "進入變更記錄"
    next: ["read-history"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "read-history"
    name: "讀取 git 歷史"
    next: ["review-default-period"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["history"]
  - id: "review-default-period"
    name: "檢視預設期間"
    next: ["open-node"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["history"]
  - id: "open-node"
    name: "前往節點"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "change-period"
    name: "變更期間"
    next: []
    branch_from: "review-default-period"
    return_to: "review-default-period"
    emits: []
    consumes: []
    traverses: ["history"]
  - id: "include-ticket-creation"
    name: "包含 ticket 建檔事件"
    next: []
    branch_from: "review-default-period"
    return_to: "review-default-period"
    emits: []
    consumes: []
    traverses: ["history"]
  - id: "empty-period"
    name: "期間內沒有事件"
    next: []
    branch_from: "read-history"
    return_to: "review-default-period"
    emits: []
    consumes: []
    traverses: ["history"]
    implements: ["FR-03"]
  - id: "cancel-reading"
    name: "讀取期間取消"
    next: []
    branch_from: "read-history"
    return_to: "enter-history"
    emits: []
    consumes: []
    traverses: ["history"]
    implements: ["FR-02"]
  - id: "history-unavailable"
    name: "無法讀取歷史"
    next: []
    branch_from: "read-history"
    return_to: "enter-history"
    emits: []
    consumes: []
    traverses: ["history"]
    implements: ["FR-01"]
  - id: "shallow-clone"
    name: "淺層 clone"
    next: []
    branch_from: "read-history"
    return_to: "review-default-period"
    emits: []
    consumes: []
    traverses: ["history"]
```

## 例外場景

### 讀取期間取消

使用者在讀取中按取消，系統終止讀取；沒有先前結果時顯示「已取消」並提供重新讀取，有先前結果時回到先前的畫面（SPEC-008 FR-09 規則 4）。讀取中切換到其他畫面時，讀取照常進行

### 無法讀取歷史

專案不是 git repo、找不到 git 指令、或讀取失敗時，畫面各顯示不同的說明與重新檢查／重試動作；三種定案降級不顯示為「讀取失敗」（SPEC-008 FR-08）

### 淺層 clone

專案是淺層 clone 時照常列出事件，並常駐標示「歷史不完整」與邊界日期；邊界 commit 不產生事件（SPEC-008 FR-08 規則 3）

## 驗收條件

- [ ] 首次進入時才讀取；HEAD 未變時再次進入不重新讀取
- [ ] 預設期間依版本 tag 決定，無版本 tag 時為最近 30 天，畫面標明目前期間
- [ ] 預設不含 ticket 建檔事件；打開切換後包含
- [ ] 移除事件可見，包含兩端節點現在已不在圖上的情形
- [ ] 讀取期間可取消；非 git 專案、找不到 git、淺層 clone 三種情形各有不同的呈現

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-11-09 | 初版（`0.7.0-W1-012` 規劃波，PROP-006） |
