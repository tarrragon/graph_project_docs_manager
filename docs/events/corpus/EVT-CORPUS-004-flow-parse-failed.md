---
id: EVT-CORPUS-004
name: "FlowParseFailed"
canonical_name: "Corpus.FlowBlock.Rejected"
category: domain_event
status: draft
source_proposal: PROP-005
created: "2026-10-08"
updated: "2026-10-08"

payload: null

producers: ['corpus']
consumers: ['diagnostics']
---

# EVT-CORPUS-004: FlowParseFailed

## 事實

一份 UC 本文中至少一個 flow 區塊 YAML 解析失敗；該 UC 仍是圖譜節點。

## 負載結構

`path: String`、`reason: String`

- `path`：該 UC 的相對路徑
- `reason`：固定為「flow 區塊解析失敗」原因碼（SPEC-006 FR-09 規則 3a）；程式識別名由實作票定
- 一份 UC 不論有幾個解析失敗的 flow 區塊，只發出一筆

> 判定與取值規則依 SPEC-006 FR-09 規則 3a、3b。

## 設計註記

與 EVT-CORPUS-003 分立：003 的事實是「該文件未進入圖譜」，本事件的 UC 已是節點，
只有 flow 區塊壞掉。兩者共用一個事件會讓 003 的事實語意變寬
（`0.5.0-W1-001.8` 用戶裁決 CD1，2026-10-08）。

**發送條件**：判為 UC 的可用檔案，本文中有 fenced yaml 區塊含頂層 `flow:` 行
（文字層判定，不需解析），且其中任一此類區塊 YAML 解析失敗。即使其後另有合法 flow
區塊（步驟仍取第一個合法區塊），本事件照常發出（用戶裁決 AB1）。

Diagnostics 收到後產生一筆 `parseFailure` 破洞（SPEC-006 FR-08）。

## 來源

`0.5.0-W1-001.8` 用戶裁決（第二輪，2026-10-08）。
