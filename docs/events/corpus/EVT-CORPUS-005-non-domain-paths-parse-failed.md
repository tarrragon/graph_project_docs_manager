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
例外：子原因 `elementNotString` 時只略過該元素，非 domain 側其餘元素照常生效。

## 負載結構

`path: String`、`reason: NonDomainPathsMalformedReason`（同 EVT-CORPUS-004 的 path／reason 形狀）

- `path`：非 domain 路徑清單檔的相對路徑（位置取自專案型別表 `non_domain_paths_file`，缺欄時取內建表值）
- `reason`：格式錯誤子原因，列舉 `NonDomainPathsMalformedReason { yamlInvalid, keyMissing, notList, elementNotString }`，
  分別對應 YAML 解析失敗、缺該鍵、該鍵的值不是清單（SPEC-006 FR-10 規則 2）、清單內有非字串元素（FR-10 規則 2a，
  `0.5.0-W1-096.7` 用戶裁決第二批 #1，與上游 `doc validate-paths` 逐元素回報同形）
- Diagnostics 據此產生的 `parseFailure` 破洞原因碼為 `nonDomainPathsMalformed`（`0.5.0-W1-096.7` PM 處置識別名）
- `yamlInvalid`／`keyMissing`／`notList` 一輪掃描最多發出一筆；`elementNotString` 的筆數（每個非字串元素一筆或每輪一筆）未裁決，見 `0.5.0-W1-114.3` NeedsContext

> 判定與取值規則依 SPEC-006 FR-10。

## 設計註記

與 EVT-CORPUS-003 分立：003 的事實是「該文件未進入圖譜」，負載以文件節點為中心
（節點型別、候選型別、救回欄位），且只對命中 carrier 的失敗檔發出；非 domain 路徑清單檔
不是 carrier、沒有 frontmatter 與型別，該負載大半不適用。比照 EVT-CORPUS-004 的先例，
語意不同時另立事件（`0.5.0-W1-096.7` 用戶裁決 NC-1 (i) I-b，2026-10-08）。

**發送條件**：清單檔存在，且 YAML 解析失敗、缺該鍵、或該鍵的值不是清單，三者任一成立；
或清單內有非字串元素（`elementNotString`：該元素略過，其餘元素照常生效，非 domain 側不視為未宣告）。
清單檔不存在時不發出（屬未宣告，不是格式錯誤）。

Diagnostics 收到後產生一筆 `parseFailure` 破洞（SPEC-006 FR-08），不依賴 FR-06 路徑模式查詢，
查詢不可用時照常產生（`0.5.0-W1-114.1` PM 處置 NC-e）。路徑分類不因本事件
新增顯示狀態：非 domain 側照「清單缺席」處理，報告頁宣告狀態行另標「格式錯誤」（NC-1 (ii) II-a，
UC-02）。

## 來源

`0.5.0-W1-096.7` 用戶裁決（NC-1，2026-10-08）。

## 變更歷史

| 日期 | 變更 |
|------|------|
| 2026-10-08 | `0.5.0-W1-114.3`（`0.5.0-W1-096.7` 用戶裁決第二批 #1，1C）：子原因列舉新增 `elementNotString`，發送條件補非字串元素（略過該元素、其餘生效）；`elementNotString` 筆數未裁決 |
| 2026-10-08 | `0.5.0-W1-114.1` 第二小輪：負載 `reason` 改為子原因列舉 `NonDomainPathsMalformedReason { yamlInvalid, keyMissing, notList }`，破洞原因碼記為 `nonDomainPathsMalformed`（`0.5.0-W1-096.7` PM 處置）；補「不依賴路徑查詢」（NC-e） |
| 2026-10-08 | 建立（`0.5.0-W1-096.7` 用戶裁決 NC-1） |
