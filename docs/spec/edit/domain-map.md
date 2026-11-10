---
id: DOMAIN-MAP-edit
domain: "edit"
source_specs: [SPEC-009]
related_usecases: []
depends_on_bundles: [DOMAIN-MAP-workspace, DOMAIN-MAP-schema, DOMAIN-MAP-corpus, DOMAIN-MAP-observability]
path_patterns: []               # lib/edit/ 由 1.0 實作票建立後補上（validate 要求路徑存在）
created: "2026-11-10"
updated: "2026-11-10"
---

# Domain Map — Edit

> 產出來源：1.0.0-W3-553.1（依 `docs/tech-decisions.md`〈補記：2026-11-10 — 1.0 編輯能力四項架構決策定案〉子決策 1 新建）。本文件界定 Edit domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Edit domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：寫入使用者檔案的安全政策（三平面閘門、快照、原子寫入、路徑界內）、與 git 和 doc CLI 的寫入期互動，或寫入結果的呈現契約改變。

**新建依據**：對最近鄰 Corpus 跑 SRP 三問與共現檢查，結論是兩者變更理由不同、共現資料無「永遠一起改」的訊號，因此新建（檢查出處 `1.0.0-W3-553` Solution；判準見 `docs/tech-decisions.md`〈domain 數量：只觸發檢查，不是上限〉）。兩者的分工：

| 面向 | Corpus | Edit |
|---|---|---|
| 變更理由 | 文件格式與解析寬容度 | 寫入安全政策、git 與 CLI 的寫入期互動 |
| 「文件」指什麼 | 解析後的節點與破洞 | 磁碟上的位元組與三個平面（HEAD、工作目錄、App 讀入時的內容） |
| 依賴 git、doc CLI | 否 | 是 |

**範圍**：1.0 只寫文件節點的純量欄位（PROP-007〈1.x minor 清單〉）。關係邊、ticket、內文、結構化區塊、檔案層級操作依 1.1～1.5 逐步加入，每加一種對象回本檔更新 §3 的 command 清單。

## 2. 分層與依賴方向

層級：由 `bundle_dependency` 推導（系統層 §2），推導結果見系統層 §2 分層圖。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Workspace | 取得工作區根路徑。「可寫／唯讀降級」是本 domain 的狀態：工作區開啟時由本 domain 以工作區根探測 `git`，不是 git repo 或 `git` 無法執行即唯讀降級，寫入時不再重判（SPEC-009 FR-01） |
| 出邊 | Schema | 欄位值域與邊型（反向欄位，1.1 起）取自型別表；`id_pattern` 判定寫入對象的節點型別 |
| 出邊 | Corpus | 以 Corpus 的公開解析函式（位元組 → 解析結果）做改寫隔離檢查，避免兩套解析器的容錯規則分歧（系統層 §2「Corpus 是唯一的解析者」）。本 domain 只做保留原文的局部改寫，欄位定位自取節點 span，由隔離檢查擋下與 Corpus 的分歧（SPEC-009 FR-03） |
| 出邊 | Observability | 以 `LogSink<E>` 與白名單型別發出日誌（SPEC-010 FR-03、FR-04） |
| 入邊 | 無 domain | 呼叫端是畫面狀態層（節點詳情、破洞報告的編輯入口） |

**Corpus 不依賴本 domain**：寫入完成後，Corpus 經檔案監看事件重掃（SPEC-006 FR-11），本 domain 不直接呼叫 Corpus 的重掃。反向邊會形成循環。

**外部依賴**：`git`（快照、HEAD 比對）與 doc CLI（寫入後驗證）是外部程式，不是 domain，失敗歸 `external_process`（SPEC-010 FR-02）。

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Edit | 否 | 閘門阻擋、寫入結果、快照回饋與驗證狀態皆由使用者按下寫入觸發（等待型），結果在同一畫面的編輯狀態內呈現。編輯中由監看事件發現的外部改動也以編輯狀態承載，不發暫態提示（SPEC-009 FR-06） |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Edit** | 寫入安全政策、git 與 CLI 的寫入期互動、寫入結果的呈現契約 | 下表 command；`WriteResult`、`ValidationStatus`、`WorkspaceRelativePath`、`EditLogEvent` | 三平面比較、快照、原子寫入、局部改寫、驗證器呼叫與 baseline 差集 |

### Command 清單

以業務操作命名，不以 Create／Update／Delete 命名。理由：出現 CRUD 動詞是本 domain 退化成資料表管理者的早期訊號（`1.0.0-W3-553` P 失敗預想）。1.0 不提供 App 內提交（用戶裁定，移入 1.1 候選池），清單不含提交動作。

| Command | 業務語意 | 自 | 規格 |
|---|---|---|---|
| 開始編輯（`beginEditing`） | 記下目標檔此刻的內容 M，作為之後判定外部已改的基準；同時記下驗證 baseline | 1.0 | SPEC-009 FR-01、FR-05 |
| 修正欄位值（`reviseFieldValue`） | 改寫一個文件節點的純量欄位，經閘門、必要時快照、原子寫入、寫入後驗證 | 1.0 | SPEC-009 FR-01～FR-05 |
| 放棄並重讀（`discardAndReload`） | 外部已改時捨棄 App 內的未寫入值，以磁碟內容重新開始編輯 | 1.0 | SPEC-009 FR-06 |

### Bundle 不變式清單

目標路徑為 `lib/edit/`（此為目標邊界，非現況：2026-11-10 規劃時該目錄尚不存在）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC 條款 |
|---|---|---|
| Edit | W ≠ M 時不寫入，回傳閘門阻擋（外部已改） | SPEC-009 FR-01 |
| Edit | `rename` 前緊鄰的重讀與 W 不同時不寫入，回傳閘門阻擋（外部已改）並刪除暫存檔 | SPEC-009 FR-01 |
| Edit | W = M 且 W ≠ H（含未追蹤）時，先快照成功才寫入；快照失敗回傳閘門阻擋 | SPEC-009 FR-01、FR-02 |
| Edit | W = M = H 時直接寫入，不呼叫快照 | SPEC-009 FR-01 |
| Edit | 寫入函式只接受 `WorkspaceRelativePath`；工作區外路徑無法建構 | SPEC-009 FR-04 |
| Edit | 寫入中途失敗時，目標檔維持寫入前內容（temp 加 rename） | SPEC-009 FR-03 |
| Edit | 只改目標欄位與已存在的 `updated` 的位元組，其餘位元組不變；`updated` 缺席時不新增 | SPEC-009 FR-03 |
| Edit | 改寫後經 Corpus 解析，允許變更集合以外的鍵有變動時不寫入（改寫不隔離） | SPEC-009 FR-03 |
| Edit | 驗證失敗不改動已寫入的檔案 | SPEC-009 FR-05 |
| Edit | 只有寫入後問題集合減去 baseline 非空時，驗證狀態為失敗 | SPEC-009 FR-05 |
| Edit | 寫入前後使用者的 index、refs、stash 不變；App 不建立 commit | SPEC-009 FR-02、FR-08 |
| Edit | 錯誤型別與日誌欄位不含欄位值與檔案內容 | SPEC-009 FR-07 |

## 6. 待決事項

- 無本 domain 專屬的待決事項。值域來源的過渡做法（無機器定義的列舉以單行文字輸入）由 SPEC-009 FR-09 承載；上游補上值域後，該欄改用 FR-09 表的「目標元件」。

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-009（1.0.0 Edit：寫入路徑）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | 寫入前閘門（三平面判準） | Edit | domain unit（fixture repo） |
| FR-02 | 快照 | Edit | domain unit（fixture repo） |
| FR-03 | 原子寫入與局部改寫 | Edit | domain unit |
| FR-04 | 路徑界內型別 | Edit | domain unit |
| FR-05 | 寫入結果型別、三個可觀測時刻與 CLI 驗證狀態 | Edit；畫面狀態層（呈現） | domain unit；widget |
| FR-06 | 外部改動的發現時點 | Edit；畫面狀態層（呈現） | domain unit；widget |
| FR-07 | 只記識別與日誌事件 | Edit | domain unit |
| FR-08 | 變更記錄 | Edit；畫面狀態層（session 內清單） | domain unit；widget |
| FR-09 | 逐欄位輸入元件對照 | 畫面狀態層 | widget |

---

**Last Updated**: 2026-11-10 | **Source**: 1.0.0-W3-553.1
