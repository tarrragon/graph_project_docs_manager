---
id: EVT-CORPUS-002
name: "CorpusChanged"
canonical_name: "Corpus.FileSystem.Changed"
category: domain_event
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-08-27"

payload: null

producers: ['corpus']
consumers: ['corpus']
---

# EVT-CORPUS-002: CorpusChanged

## 事實

檔案監看偵測到專案資料夾內的文件變動。

## 負載結構

`changes`：清單，每筆含相對路徑與 `kind: created | modified | deleted`；一個去抖窗合併為一筆事件，合併規則見 SPEC-006 FR-11 規則 4、5。

## 設計註記

生產者與消費者同為 Corpus——這是 domain 內部的觸發訊號，不跨界。對外只發 CorpusParsed。此設計避免消費方各自處理 debounce 與部分重解析。

## 來源

`saas-tech-selection` Stage 2 的 event catalog。切分依據見 `docs/system-layer.md`。
