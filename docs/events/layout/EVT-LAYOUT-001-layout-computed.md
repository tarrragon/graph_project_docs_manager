---
id: EVT-LAYOUT-001
name: "LayoutComputed"
canonical_name: "Layout.Geometry.Computed"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Layout']
consumers: ['Presentation']
---

# EVT-LAYOUT-001: LayoutComputed

## 事實

指定視圖模式的座標與尺寸已計算完成。

## 負載結構

`mode: matrix | swimlane`、`geometry`、`overflowHints`

> 具體型別待 SPEC 產出後定案。

## 設計註記

矩陣模式委派 `two_dimensional_scrollables`（flutter.dev 官方），泳道模式自建。套件的失敗語意由本 domain 轉譯，不讓套件例外洩漏到畫面狀態層。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
