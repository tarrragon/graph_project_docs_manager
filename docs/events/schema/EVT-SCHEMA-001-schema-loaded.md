---
id: EVT-SCHEMA-001
name: "SchemaLoaded"
canonical_name: "Schema.TypeTable.Loaded"
category: domain_event
status: draft
source_proposal: PROP-002
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['Schema']
consumers: ['Corpus', 'Graph']
---

# EVT-SCHEMA-001: SchemaLoaded

## 事實

已自使用者專案載入圖譜型別表。

## 負載結構

`nodeTypes`、`edgeTypes`、`schemaGeneratedAtFrameworkVersion: String`

> 具體型別待 SPEC 產出後定案。

## 設計註記

型別表來自使用者的 `.claude/`，版本隨其框架而非本 App 的 build。Corpus 依 `carrier` 決定掃描路徑，Graph 依 `class` 與 `forward_field` / `reverse_field` 建邊。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/domain-map.md`。
