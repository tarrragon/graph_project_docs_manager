---
id: EVT-WORKSPACE-001
name: "WorkspaceSelected"
canonical_name: "Workspace.Selection.Confirmed"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Workspace']
consumers: ['Schema', 'Corpus']
---

# EVT-WORKSPACE-001: WorkspaceSelected

## 事實

使用者選定的專案資料夾已確認存在且可讀。

## 負載結構

`path: String` — 已驗證可讀的絕對路徑

> 具體型別待 SPEC 產出後定案。

## 設計註記

資料夾可用性在發送前已確認。訂閱方不需重複檢查存在性，但仍須處理讀取期間資料夾消失的情況。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
