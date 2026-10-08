---
id: DOMAIN-MAP-ticketdetail
domain: "ticketdetail"
source_specs: [SPEC-007]
related_usecases: [UC-02, UC-04]
depends_on_bundles: [DOMAIN-MAP-corpus]
path_patterns: [lib/ticket_detail/]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — TicketDetail

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 TicketDetail domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 TicketDetail domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：ticket 的 5W1H 結構語意改變

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Corpus（`DOMAIN-MAP-corpus`） | 詳情取自同一份解析產物 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| TicketDetail | 否 | 全文查看由使用者操作觸發（等待型），結果在同一畫面內呈現，不另佔用呈現焦點通道 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **TicketDetail** | ticket 的 5W1H 結構語意改變 | 單張 ticket 全文與生命週期欄位 | 欄位解讀、佔位值處理 |

## 4. 邊界決策

### 4.1 Commodity check（本專案的退化形式）

本 App 無後端，領域層的「買 vs 建」退化成「用套件 vs 自己寫」：

| 能力 | 判定 | 依據 |
|------|------|------|
| Markdown 渲染 | 用套件 | 同上 |

> 「接縫」段（套件失敗語意由 Layout domain 承擔並轉譯）見 `docs/spec/layout/domain-map.md` §4.1。

## 7. FR → Bundle 覆蓋對照

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-07 | TicketDetail 以 ID 查詢全文 | TicketDetail（讀 Corpus `rawNodes`） | domain unit；IT-3 |

> SPEC-007 全表的權威在 `docs/spec/graph/domain-map.md` §7；此處僅列歸屬本 domain 的列。Graph 與 TicketDetail 都只讀 Corpus 產物、彼此不依賴（系統層 §4.1）。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
