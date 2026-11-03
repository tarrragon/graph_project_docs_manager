---
id: EVT-CORPUS-006
name: "TopicFilesParseFailed"
canonical_name: "Corpus.TopicFiles.Rejected"
category: domain_event
status: draft
source_proposal: PROP-004
created: "2026-11-02"
updated: "2026-11-02"

payload: null

producers: ['corpus']
consumers: ['diagnostics']
---

# EVT-CORPUS-006: TopicFilesParseFailed

## 事實

被觀測專案的主題檔（指派檔 `docs/work-logs/topic-assignments.txt` 或主題清單
`docs/work-logs/topics-registry.txt`）存在但無法讀取，或指派檔中有主題名不在主題清單。
映射照常產出；無法讀取的檔視為無資料（SPEC-006 FR-12 規則 7、8）。

## 負載結構

`path: String`、`reason: TopicFilesMalformedReason`、`unregisteredTopicCount: int?`（path／reason 同 EVT-CORPUS-005 的形狀）

- `path`：觸發本事件的主題檔相對路徑（位置固定，見 SPEC-006 FR-12 規則 1）。子原因 `registryMismatch` 時為指派檔路徑
- `reason`：子原因，列舉 `TopicFilesMalformedReason { unreadable, registryMismatch }`，
  分別對應該檔存在但 I/O 錯誤或非 UTF-8（FR-12 規則 8）、指派檔中有主題名不在主題清單（FR-12 規則 7）
- `unregisteredTopicCount: int?`：不在主題清單的相異主題名數，只在 `reason` 為 `registryMismatch` 時有值且必為 1 以上；`unreadable` 時為 null
- Diagnostics 據此產生的 `parseFailure` 破洞原因碼為 `topicFilesMalformed`

> 判定與取值規則依 SPEC-006 FR-12。

## 設計註記

命名比照 EVT-CORPUS-005：事件名 `…ParseFailed`、canonical 名 `Corpus.<對象>.Rejected`、
子原因列舉 `<對象>MalformedReason`、破洞原因碼 `<對象>Malformed`、計數欄位 `<計數對象>Count`
（`0.6.0-W1-112` PM 裁定：命名由本票依既有慣例定案）。

與 EVT-CORPUS-005 分立：005 的對象是型別表指名的非 domain 路徑清單檔，本事件的對象是框架
ticket 系統寫入的兩個純文字檔，位置不取自型別表、子原因集合也不同。不併入 EVT-CORPUS-003，
理由同 005（主題檔不是 carrier、沒有 frontmatter 與型別）。

**一致性檢查的範圍**：檢查指派檔**全部行**，含被 FR-12 規則 5 後行覆蓋的舊行，不只看有效映射
（`0.6.0-W1-112` PM 裁定）。理由：框架寫入路徑先註冊主題名再追加指派，舊行同樣受 PROP-004
〈不變式〉約束；只看有效映射會放過歷史上的不一致。FR-12 規則 4 跳過的行不參與檢查。

**發送條件**：

| 子原因 | 條件 | 筆數 |
|------|------|------|
| `unreadable` | 指派檔或主題清單存在但無法讀取 | 每檔至多一筆 |
| `registryMismatch` | 兩檔都存在且皆可讀，指派檔任一行的主題名不在主題清單 | 一輪至多一筆，以 `unregisteredTopicCount` 帶數量 |

一輪至多三筆。任一檔不存在時不發出：缺檔是舊框架版本的常態，不是錯誤（FR-12 規則 6）。

Diagnostics 收到後產生一筆 `parseFailure` 破洞（SPEC-006 FR-08），不依賴 FR-06 路徑模式查詢。
本事件不影響語料結果與守恆式（FR-12 規則 9），也不計入 Ticket 清單的「含損壞」（SPEC-001 §4
〈主題模式的資料來源與缺檔呈現〉）。

## 來源

`0.6.0-W1-105.3` 用戶裁定 G-T4 選 A（2026-11-02）；SPEC-006 FR-12（`0.6.0-W1-105.3.1`）；
識別名與一致性檢查範圍由 `0.6.0-W1-112` 定案。

## 變更歷史

| 日期 | 變更 |
|------|------|
| 2026-11-02 | 建立（`0.6.0-W1-112`） |
