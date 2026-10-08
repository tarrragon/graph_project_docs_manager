---
id: EVT-CORPUS-005
name: "NonDomainPathsParseFailed"
canonical_name: "Corpus.NonDomainPaths.Rejected"
category: domain_event
status: draft
source_proposal: PROP-005
created: "2026-10-08"
updated: "2026-10-08"

payload: null

producers: ['corpus']
consumers: ['diagnostics']
---

# EVT-CORPUS-005: NonDomainPathsParseFailed

## 事實

被觀測專案的非 domain 路徑清單檔存在但格式錯誤；該專案的非 domain 側視為未宣告。

## 負載結構

`path: String`、`reason: String`

- `path`：非 domain 路徑清單檔的相對路徑（位置取自專案型別表 `non_domain_paths_file`，缺欄時取內建表值）
- `reason`：固定為「非 domain 路徑清單格式錯誤」原因碼（SPEC-006 FR-10）；程式識別名由實作票定
- 一輪掃描最多發出一筆

> 判定與取值規則依 SPEC-006 FR-10。

## 設計註記

與 EVT-CORPUS-003 分立：003 的事實是「該文件未進入圖譜」，負載以文件節點為中心
（節點型別、候選型別、救回欄位），且只對命中 carrier 的失敗檔發出；非 domain 路徑清單檔
不是 carrier、沒有 frontmatter 與型別，該負載大半不適用。比照 EVT-CORPUS-004 的先例，
語意不同時另立事件（`0.5.0-W1-096.7` 用戶裁決 NC-1 (i) I-b，2026-10-08）。

**發送條件**：清單檔存在，且 YAML 解析失敗、缺該鍵、或該鍵的值不是清單，三者任一成立。
清單檔不存在時不發出（屬未宣告，不是格式錯誤）。

Diagnostics 收到後產生一筆 `parseFailure` 破洞（SPEC-006 FR-08）。路徑分類不因本事件
新增顯示狀態：非 domain 側照「清單缺席」處理，報告頁宣告狀態行另標「格式錯誤」（NC-1 (ii) II-a，
UC-02）。

## 來源

`0.5.0-W1-096.7` 用戶裁決（NC-1，2026-10-08）。
