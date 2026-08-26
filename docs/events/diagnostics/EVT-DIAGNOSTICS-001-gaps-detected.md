---
id: EVT-DIAGNOSTICS-001
name: "GapsDetected"
canonical_name: "Diagnostics.Gaps.Detected"
category: domain_event
status: draft
created: "2026-08-26"
updated: "2026-08-26"

payload: null

producers: ['Diagnostics']
consumers: ['Presentation']
---

# EVT-DIAGNOSTICS-001: GapsDetected

## 事實

一輪破洞偵測完成。

## 負載結構

`gaps: List<Gap>`（各帶 `category`、`severity`、`target`）

> 具體型別待 SPEC 產出後定案。

## 設計註記

破洞來源有三：解析失敗（ParseFailed）、圖結構缺陷（斷邊、孤島、缺必要邊）、追溯缺口（無 SPEC 的 PROP、無測試的 UC）。分類清單尚未列舉，見 domain-map §8。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
