---
id: DOMAIN-MAP-history
domain: "history"
source_specs: [SPEC-008]
related_usecases: [UC-07]
depends_on_bundles: [DOMAIN-MAP-workspace, DOMAIN-MAP-schema]
path_patterns: []
created: "2026-08-26"
updated: "2026-11-09"
---

# Domain Map — History

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 History domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 History domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：git 查詢方式或歷史語意改變

## 2. 分層與依賴方向

層級：L1（層級圖與完整依賴邊見系統層 §2）。依賴 Workspace 與 Schema（皆 L0），推導為 L1；系統層 §2 已於 2026-10-08 更正，本行 2026-10-21 補同步（`0.5.0-W1-460`），2026-11-09 補 Schema 出邊（`0.7.0-W1-012`）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Workspace（`DOMAIN-MAP-workspace`） | 取得專案根路徑後直接查 git 物件庫，不經 Corpus（見系統層 §4.3） |
| 出邊 | Schema（`DOMAIN-MAP-schema`） | 邊型表判定 diff 中的邊欄位；節點型別 `id_pattern` 判定 ticket（SPEC-008 FR-03、FR-05）。由 History 直接依賴而不由呼叫端傳入：兩者都在 Schema 公開面，型別表缺席時的內建表降級也沿用 Schema；改由呼叫端傳入會把同一條依賴藏到組裝根（PROP-006〈提案方案〉第 4 點） |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| History | 否 | 依視圖惰性載入（§4.3），由使用者開啟歷史視圖觸發（等待型），結果在同一畫面內呈現；離開畫面後完成者為持久狀態，不發提示（SPEC-001 §8.1 §10 各列） |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **History** | git 查詢方式或歷史語意改變 | 掃描結果（完成／非 git 專案／找不到 git／讀取失敗／已取消，完成者含邊事件、版本 tag、淺層資訊、計數摘要）；依期間與「包含 ticket 建檔」篩選的事件查詢（SPEC-008 FR-07） | 前置檢查、`git log -p` 串流掃描、frontmatter 狀態追蹤、宣告抽取、邊鍵換算、快取 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test。規則權威在 SPEC-008，本表只列可獨立斷言的不變式，目標路徑為 `lib/history/`。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC 條款 |
|---|---|---|
| History | 一個邊鍵的宣告來源集合只在由空變非空時產生新增、由非空變空時產生移除；只增減宣告側不產生事件 | SPEC-008 FR-04 規則 2、3 |
| History | 宣告在同一 commit 內移到另一個路徑（含改名），不產生事件 | SPEC-008 FR-04 規則 2 |
| History | 有向邊的反向宣告換算為與正向宣告相同的邊鍵；無向邊兩端依字典序排列 | SPEC-008 FR-04 規則 1 |
| History | 無法解析的 frontmatter 版本沿用上一個可解析版本的宣告，不產生事件 | SPEC-008 FR-02 規則 5 |
| History | 狀態失步的路徑凍結最後已知宣告，之後不產生事件，直到該路徑被刪除或重新新增 | SPEC-008 FR-02 規則 6 |
| History | 只收字串值；`closed_by` 不符合主圖節點型別 `id_pattern` 的值略過 | SPEC-008 FR-03 規則 4、5 |
| History | ticket 建檔事件只出現在新增事件，且該 commit 新建了宣告者之一的 ticket 檔案 | SPEC-008 FR-05 |
| History | 基準 tag 不取 HEAD 本身；不符合版本 tag 樣式或不在主線上的 tag 不採用 | SPEC-008 FR-06 規則 1、2 |
| History | 淺層邊界 commit 只建立初始狀態，不產生事件 | SPEC-008 FR-08 規則 3 |
| History | 同一份結果上，「包含 ticket 建檔」為否的查詢結果是為是的子集 | SPEC-008 FR-07 |

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

補充實測（`0.7.0-W1-012`，量測環境：作者本機 macOS，2026-11-09，本專案 repo）：`git log -p -- docs/` 為 30354 commits、83 MB、6.1 秒；
主線模式（`--first-parent --diff-merges=first-parent`）為 26212 commits、82 MB、5.6 秒。block 清單的邊列項約 36%
所屬欄位名不在 hunk 上下文內，因此解析須追蹤每個檔案的 frontmatter 狀態；事件歸屬主線 commit（用戶裁定）使重放為線性。

## 5. 對實作票的切分指引

- 掃描與解析為純函式：輸入為掃描輸出的行序列與型別表，輸出為事件與計數；git 程序經 driven port 呼叫，測試以 fake 程序執行器驅動
- 行程呼叫（前置檢查、掃描、取消）與解析分票：前者屬平台互動，須自帶日誌（`observability-rules` 規則 5）
- History 的票不得 import `lib/corpus/` 與 `lib/graph/`（系統層 §4.3、SPEC-008 H3）

## 7. FR → Bundle 覆蓋對照

| SPEC-008 FR | Bundle | 備註 |
|---|---|---|
| FR-01 前置檢查與掃描指令 | History（driven port：git 程序） | 工作區根取自 Workspace |
| FR-02 串流解析與狀態追蹤 | History | 純函式 |
| FR-03 宣告的抽取 | History | 邊型表與 `id_pattern` 取自 Schema |
| FR-04 邊身分與事件 | History | 純函式 |
| FR-05 ticket 建檔事件 | History | |
| FR-06 版本 tag 與預設期間 | History | 時鐘注入 |
| FR-07 查詢 | History（公開面） | |
| FR-08 降級與失敗 | History | 型別表阻擋由 Schema 決定，畫面沿用 SPEC-001 §1 |
| FR-09 惰性載入、快取、取消 | History（application 層） | 觸發點在 L4 畫面狀態 |
| FR-10 可觀測性與 tripwire | History | |

本 domain 在 SPEC-006、SPEC-007 無 FR 歸屬。SPEC-003 逐 FR 的跨 domain 對照見系統層 §8。

---

**Last Updated**: 2026-11-09 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）；`0.7.0-W1-012`（SPEC-008、Schema 出邊、不變式清單）
