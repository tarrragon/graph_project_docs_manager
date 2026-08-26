---
id: UC-01
title: "開啟專案並抵達可用狀態"
status: draft
source_proposal: PROP-003
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

# UC-01: 開啟專案並抵達可用狀態

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-01 |
| 用例名稱 | 開啟專案並抵達可用狀態 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | App 已安裝；使用者的機器上有至少一個使用本框架的專案 |
| 成功保證 | Domain 視圖顯示該專案的圖譜，或明確說明為何無法顯示 |

## 主要成功場景

1. **選擇資料夾**
   - 使用者自側欄浮層選擇專案資料夾，系統確認其存在且可讀

2. **載入型別表**
   - 系統自該專案的 .claude/ 讀取 tracking_schema.json 與 VERSION

3. **解析節點**
   - 系統掃描 docs/ 下的圖譜節點檔並解析 frontmatter

4. **抵達 Domain 視圖**
   - 系統以矩陣模式呈現 domain × UC 交叉表

## 替代場景

### 資料夾不可用

選取的資料夾不存在或無法讀取時，浮層標示該項不可用並附原因，其餘項仍可選

### 空專案

解析成功但無任何圖譜節點時，顯示說明並提供開啟 docs/ 目錄與切換專案的動作

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "select-folder"
    name: "選擇資料夾"
    next: ["load-schema"]
    branch_from: null
    return_to: null
    emits: ["EVT-WORKSPACE-001"]
  - id: "load-schema"
    name: "載入型別表"
    next: ["parse-nodes"]
    branch_from: null
    return_to: null
    emits: ["EVT-SCHEMA-001"]
    consumes: ["EVT-WORKSPACE-001"]
  - id: "parse-nodes"
    name: "解析節點"
    next: ["reach-domain-view"]
    branch_from: null
    return_to: null
    emits: ["EVT-CORPUS-001"]
    consumes: ["EVT-SCHEMA-001"]
  - id: "reach-domain-view"
    name: "抵達 Domain 視圖"
    next: []
    branch_from: null
    return_to: null
    consumes: ["EVT-CORPUS-001"]
  - id: "folder-unavailable"
    name: "資料夾不可用"
    next: []
    branch_from: "select-folder"
    return_to: "select-folder"
  - id: "empty-graph"
    name: "空專案"
    next: []
    branch_from: "parse-nodes"
    return_to: null
  - id: "schema-rejected"
    name: "版本不符拒絕渲染"
    next: []
    branch_from: "load-schema"
    return_to: "select-folder"
    implements: ["FR-04"]
    emits: ["EVT-SCHEMA-002"]
```

## 例外場景

### schema 版本超出已知範圍

顯示兩個版本值與說明，不繪製圖譜；切換專案浮層維持可用

### 部分檔案解析失敗

不中止整輪解析；失敗檔案列入破洞報告，圖譜以可解析部分呈現

## 驗收條件

- [ ] 選定資料夾後，Domain 視圖在節點數 20 以內時於 1 秒內可用
- [ ] 資料夾不可用時，錯誤訊息指出具體原因而非泛用失敗
- [ ] schema 版本不符時不繪製任何圖譜元素
- [ ] 解析失敗的檔案數量顯示於破洞報告，且不影響其餘節點的呈現

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
