---
id: EVT-CORPUS-004
name: "FlowParseFailed"
canonical_name: "Corpus.FlowBlock.Rejected"
category: domain_event
status: draft
source_proposal: PROP-005
created: "2026-10-08"
updated: "2026-10-09"

payload: null

producers: ['corpus']
consumers: ['diagnostics']
---

# EVT-CORPUS-004: FlowParseFailed

## 事實

一份 UC 本文中至少一個 flow 區塊壞掉（YAML 解析失敗、flow 清單含非 map 項目、或圍欄未閉合）；該 UC 仍是圖譜節點。

## 負載結構

`path: String`、`reason: String`

- `path`：該 UC 的相對路徑
- `reason`：以「flow 區塊解析失敗」原因碼 `flowBlockMalformed` 開頭，其後可附說明文字（失敗區塊起始行號，規則 3b(e)；非 map 項目，規則 3c；未閉合圍欄，規則 3d）。下游判定原因碼須用前綴比對，不得用全等比對（PM 處置 2026-10-09，`0.5.0-W1-001.3` 複審 N1：原「固定為原因碼」與 3b(e)／3c 的附註要求衝突）
- 一份 UC 不論有幾個壞掉的 flow 區塊、壞在哪一種，只發出一筆

> 判定與取值規則依 SPEC-006 FR-09 規則 3a、3b。

## 設計註記

與 EVT-CORPUS-003 分立：003 的事實是「該文件未進入圖譜」，本事件的 UC 已是節點，
只有 flow 區塊壞掉。兩者共用一個事件會讓 003 的事實語意變寬
（`0.5.0-W1-001.8` 用戶裁決 CD1，2026-10-08）。

**發送條件**：判為 UC 的可用檔案，本文中有 fenced yaml 區塊含頂層 `flow:` 行
（文字層判定，不需解析），且其中任一此類區塊 YAML 解析失敗、flow 清單含非 map 項目（規則 3c），
或圍欄未閉合（規則 3d）。即使其後另有合法 flow 區塊（步驟仍取第一個合法區塊），本事件照常發出
（用戶裁決 AB1；3c／3d 為 `0.5.0-W1-001.3` 用戶裁決 H2／J2，2026-10-09）。

Diagnostics 收到後產生一筆 `parseFailure` 破洞（SPEC-006 FR-08）。

## 來源

`0.5.0-W1-001.8` 用戶裁決（第二輪，2026-10-08）。

## 變更歷史

| 日期 | 變更 |
|------|------|
| 2026-10-09 | 事實與發送條件擴及非 map 項目（SPEC-006 v1.22 規則 3c）與未閉合圍欄（規則 3d）；`reason` 改為「以原因碼開頭、可附說明」，下游前綴比對（PM 處置，`0.5.0-W1-001.3` 複審 N1） |
| 2026-10-08 | 建立（`0.5.0-W1-001.8` 用戶裁決） |
