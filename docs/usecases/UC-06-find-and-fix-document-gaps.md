---
id: UC-06
title: "找出並修復文件破洞"
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
   - 使用者點選任一項，系統顯示檔案路徑與行號

4. **開啟原始檔**
   - 系統以外部編輯器開啟該檔並定位至該行

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
  - id: "view-categories"
    name: "檢視分類"
    next: ["locate-item"]
    branch_from: null
    return_to: null
    emits: ["EVT-DIAGNOSTICS-001"]
    consumes: []
  - id: "locate-item"
    name: "定位單項"
    next: ["open-source-file"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "open-source-file"
    name: "開啟原始檔"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
  - id: "rescan"
    name: "重新掃描"
    next: ["view-categories"]
    branch_from: "open-source-file"
    return_to: "view-categories"
    emits: ["EVT-CORPUS-002"]
    consumes: []
  - id: "no-gaps"
    name: "無破洞"
    next: []
    branch_from: "view-categories"
    return_to: null
    emits: []
    consumes: []
```

## 例外場景

### 無破洞

顯示未偵測到破洞，並說明掃描涵蓋範圍

### 原始檔已消失

顯示最後已知路徑並提供重新整理的動作

## 驗收條件

- [ ] 每一項破洞附帶足以定位的資訊：檔案路徑，以及解析失敗時的行號
- [ ] 破洞依類別分節，不將解析失敗與追溯缺口混列
- [ ] 無破洞時說明掃描涵蓋範圍，而非僅顯示空白

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
