---
id: UC-06
title: "找出並修復文件破洞"
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-09-24"
version: "1.3"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001, SPEC-003, SPEC-006]
related_usecases: []
ticket_refs: []
---

# UC-06: 找出並修復文件破洞

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-06 |
| 用例名稱 | 找出並修復文件破洞 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案且圖譜已建立 |
| 成功保證 | 使用者得知專案有哪些破洞，並能開啟原始檔逐項修復 |

## 主要成功場景

1. **進入破洞報告**
   - 使用者導覽至破洞報告，系統開始掃描

2. **檢視分類**
   - 系統依 `EVT-DIAGNOSTICS-001` 定義的類別分節呈現

3. **定位單項**
   - 系統於各項顯示檔案路徑（行號於有值時附）

4. **開啟原始檔**
   - 使用者點選一項：有指向節點者跳至對應畫面（ticket → Ticket 清單、事件類 →
     UC Flow、其他 → 節點詳情），並可經次要操作開啟原始檔；無指向者點選即開啟
     原始檔。0.1 以系統預設應用程式開啟，不定位至行號（SPEC-003 §3.5）

## 替代場景

### 重新掃描

使用者修復後觸發重新掃描，系統重新解析並更新報告

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "enter-gap-report"
    name: "進入破洞報告"
    next: ["view-categories"]
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-003"]
    traverses: ["Diagnostics"]
  - id: "view-categories"
    name: "檢視分類"
    next: ["locate-item"]
    branch_from: null
    return_to: null
    emits: ["EVT-DIAGNOSTICS-001"]
    consumes: []
    traverses: ["Diagnostics"]
  - id: "locate-item"
    name: "定位單項"
    next: ["open-source-file"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["Diagnostics"]
  - id: "open-source-file"
    name: "開啟原始檔"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["Workspace"]
  - id: "rescan"
    name: "重新掃描"
    next: ["view-categories"]
    branch_from: "open-source-file"
    return_to: "view-categories"
    emits: ["EVT-CORPUS-002"]
    consumes: []
    traverses: ["Corpus"]
  - id: "no-gaps"
    name: "無破洞"
    next: []
    branch_from: "view-categories"
    return_to: null
    emits: []
    consumes: []
    traverses: ["Diagnostics"]
  - id: "gaps-undeterminable"
    name: "無法判定破洞"
    next: []
    branch_from: "view-categories"
    return_to: null
    emits: []
    consumes: []
    traverses: ["Diagnostics"]
```

## 例外場景

### 無破洞

顯示未偵測到破洞，並說明掃描涵蓋範圍

### 無法判定破洞

專案的型別表與 App 內建型別表都取不到 carrier 路徑模式時，系統無法判斷哪些檔案
應該是節點。報告顯示「無法判定破洞」並說明原因，解析失敗類別不列出任何項目。
這個畫面必須和〈無破洞〉明顯不同：若兩者看起來一樣，使用者會把「沒辦法檢查」
誤讀成「檢查過且乾淨」（SPEC-006 FR-08）

### 破洞歸屬型別不明

一個沒有 frontmatter 的檔案同時符合兩個型別的路徑模式、且具體度相同時，該項照常
列入破洞，列出全部候選型別並標記 schema 歧義，由使用者判斷（SPEC-006 FR-06 規則 6）

### 原始檔已消失

於破洞報告開啟原始檔時檔案已不存在：暫態提示告知並提供重新掃描；經跳轉進入
節點詳情後開啟時檔案已不存在：顯示最後已知路徑並提供重新整理

## 驗收條件

- [ ] 每一項破洞附帶足以定位的資訊：檔案路徑，以及解析失敗時的行號
- [ ] 破洞依類別分節，不將解析失敗與追溯缺口混列
- [ ] 無破洞時說明掃描涵蓋範圍，而非僅顯示空白
- [ ] 無法判定破洞時的畫面與無破洞明顯不同，並說明無法判定的原因
- [ ] 只有落在節點 carrier 路徑內的失敗檔列為破洞；README、工作日誌等合法非節點檔即使沒有 frontmatter 也不列入

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.3 | 2026-09-24 | 0.3.0 規劃波 Step 4：依 SPEC-006 新增例外場景〈無法判定破洞〉（結構化 flow 補 `gaps-undeterminable` 步驟）與〈破洞歸屬型別不明〉；驗收補「無法判定與無破洞明顯不同」及「只有 carrier 內的失敗檔列為破洞」；`related_specs` 補 SPEC-006 |
| 1.2 | 2026-09-15 | 追修同步稽核裁決議題 X1／X2／P2（`0.1.0-W3-335.59` WRAP，`0.1.0-W3-335.63` 落檔）：主要成功場景步驟 3、4 改依指向型別跳轉、原始檔以次要操作或直接開啟，0.1 不定位行號（承 `0.1.0-W3-335.19` 第二輪裁示與 `0.1.0-W1-070` 決定，見 SPEC-003 §3.5）；〈原始檔已消失〉拆兩路（破洞報告內開啟 vs 節點詳情開啟）；`related_specs` 補 SPEC-003；不動結構化 flow 區塊 |
| 1.1 | 2026-09-14 | 追修 spec 間矛盾（`0.1.0-W3-335.37` R11）：主要成功場景步驟 3「系統顯示檔案路徑與行號」補「（行號於有值時顯示）」，對齊事件類破洞項行號可空 |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
