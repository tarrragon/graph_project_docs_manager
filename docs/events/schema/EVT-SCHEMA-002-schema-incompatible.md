---
id: EVT-SCHEMA-002
name: "SchemaIncompatible"
canonical_name: "Schema.Version.Rejected"
category: domain_event
status: draft
created: "2026-08-26"
updated: "2026-08-26"

payload: null

producers: ['Schema']
consumers: ['Presentation']
---

# EVT-SCHEMA-002: SchemaIncompatible

## 事實

使用者的框架版本超出本 App 已知範圍，或型別表缺少必要欄位。

## 負載結構

`frameworkVersion: String`、`reason: String`、`knownRange: String`

> 具體型別待 SPEC 產出後定案。

## 設計註記

此事件存在的理由是**拒絕靜默降級**。版本不符時渲染出可能錯誤的圖，比明確拒絕更糟——使用者無法分辨圖是對的還是壞的。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
