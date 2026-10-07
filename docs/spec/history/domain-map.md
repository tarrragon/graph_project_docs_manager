---
id: DOMAIN-MAP-history
domain: "history"
source_specs: []
related_usecases: []
depends_on_bundles: [DOMAIN-MAP-workspace]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — History

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 History domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 History domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：git 查詢方式或歷史語意改變

## 2. 分層與依賴方向

層級：L2（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Workspace（`DOMAIN-MAP-workspace`） | 取得專案根路徑後直接查 git 物件庫，不經 Corpus（見系統層 §4.3） |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| History | 否 | 依視圖惰性載入（§4.3），由使用者開啟歷史視圖觸發（等待型），結果在同一畫面內呈現 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **History** | git 查詢方式或歷史語意改變 | 節點與邊的變更事件序列 | `git log -p` 掃描、diff 解析、降級判定 |

## 4. 邊界決策

### 4.1 邊層級歷史的實測成本與載入策略

> 為何 History 不併入 Corpus 的決策見系統層 §4.3；本節是該決策附帶的成本實測。

實測成本（票 `0.0.3-W1-003`，flutter_balance 9409 commits）：

| 做法 | 耗時 |
|------|------|
| 文件層級（`git log --name-only` 單次） | 1.04 秒 |
| 邊層級（逐 commit `git show`，天真實作） | 18.3 分鐘 |
| **邊層級（單次 `git log -p` + 解析）** | **2.28 秒** |

採用邊層級。載入策略沿用依視圖惰性——開啟歷史視圖才掃描。全量重掃已足夠快，
不實作增量更新：增量需維護狀態且正確性風險高，省下的時間有限。

## 7. FR → Bundle 覆蓋對照

本 domain 在 SPEC-006、SPEC-007 無 FR 歸屬。SPEC-003 逐 FR 的跨 domain 對照見系統層 §8。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
