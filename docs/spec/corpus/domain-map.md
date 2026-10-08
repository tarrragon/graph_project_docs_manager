---
id: DOMAIN-MAP-corpus
domain: "corpus"
source_specs: [SPEC-006]
related_usecases: [UC-01, UC-02, UC-03, UC-05, UC-06]
depends_on_bundles: [DOMAIN-MAP-schema, DOMAIN-MAP-workspace]
path_patterns: [lib/corpus/]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — Corpus

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Corpus domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Corpus domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：文件格式或解析寬容度改變

## 2. 分層與依賴方向

層級：L1（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Schema（`DOMAIN-MAP-schema`） | 以 `id_pattern` 為有 frontmatter 的檔案判型；以「路徑對型別」查詢分流沒拿到可用 frontmatter 的檔案（SPEC-006 FR-03、FR-06，見系統層 §5） |
| 出邊 | Workspace（`DOMAIN-MAP-workspace`） | 取得專案根路徑 |
| 入邊 | Graph | 圖建自解析產物 |
| 入邊 | TicketDetail | 詳情取自同一份解析產物 |
| 入邊 | Diagnostics | 取解析錯誤事件（EVT-CORPUS-003），由此產生破洞 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Corpus | 否 | 檔案監看觸發的重新解析以狀態承載呈現——下游 domain 開啟對應畫面即見最新值，不透過提示通道通知（SPEC-003 §2.2 三層表「(b1) 狀態承載」的「Domain 載入完成、Ticket 載入完成」即此模式）；解析錯誤清單是資料輸出，需先由 Diagnostics 轉譯才進入通道 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Corpus** | 文件格式或解析寬容度改變 | 原始節點與邊、解析錯誤清單 | 掃描策略、YAML 容錯、檔案監看 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test，不靠「剛好出現在某個 UC 場景」被動覆蓋。規則權威在 SPEC-006，本表只列可獨立斷言的不變式；目標路徑為 `lib/corpus/`（此為目標邊界，非現況：2026-09-24 規劃時該目錄尚不存在）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC-006 |
|---|---|---|
| Corpus | 每個檔案恰好落入一種結果：可用、無 frontmatter、未閉合、空或非 map、YAML 語法錯誤、無法讀取 | FR-01、FR-05 |
| Corpus | 結尾取第一個 `---` 行；frontmatter 引號字串內的 `|---|` 不造成截斷 | FR-01 規則 4、6 |
| Corpus | 「可用」要求解析結果是非空 map；`{}`、清單、純量、只有註解都不是 | FR-01 |
| Corpus | 可用檔的 `id` 至多命中一型；無 `id` 或不命中歸「有 frontmatter 的非節點」，不產生節點也不產生破洞 | FR-03 |
| Corpus | EVT-CORPUS-003 只對命中 carrier（含平手）的失敗檔發出；未命中者只記入 `parseErrors` | FR-04 |
| Corpus | `lostFields` = 歸屬型別完整性集合 − 實際寫出的鍵；值為 null 或 `[]` 算寫出；平手或取不到集合時為 `[]` | FR-04、EVT-CORPUS-003 |
| Corpus | 0.3.0 的 `salvagedFields` 恆為 `[]`，`severity` 恆為 `edgeAffecting` | FR-04 |
| Corpus | 守恆：總數 = 節點 + 有 frontmatter 的非節點 + 各失敗原因總和；各失敗原因總和 = 命中 + 未命中 + 未判定 | FR-07 |
| Corpus | 任一單檔失敗不中止整輪、不改變其他檔案的結果 | NFR-01 |

## 4. 邊界決策

### 4.1 Commodity check（本專案的退化形式）

本 App 無後端，領域層的「買 vs 建」退化成「用套件 vs 自己寫」：

| 能力 | 判定 | 依據 |
|------|------|------|
| YAML 值的解析 | 用套件 | 成熟且非差異化 |
| **frontmatter 的邊界判定** | **自己寫** | **不可用套件的通用切法**。`split("---")` 類做法會被引號字串內的 markdown 表格分隔線截斷，在既有語料上產生 130 個假失敗（見 §7）。邊界判定是本 App 的正確性核心，套件的寬容度不受我們控制 |
| 檔案監看 | 用套件 | 同上 |

> 「接縫」段（套件失敗語意由 Layout domain 承擔並轉譯）見 `docs/spec/layout/domain-map.md` §4.1。

### 4.2 解析器語意是規格的一部分

本 App 是解析文件的工具，因此**解析器的選擇本身就是正確性問題**，不是實作細節。

| 語意 | 做法 | 在 flutter_balance 1300 張 ticket 上的結果 |
|------|------|------------------------------------------|
| **逐行（採用）** | 首行為 `---`，往下找第一個 `strip() == "---"` 的行 | 0 個解析失敗 |
| 天真（禁用） | `content.split("---")` 取 `parts[1]` | **130 個假失敗** |

**Corpus domain 必須採逐行語意。** 契約測試以此為斷言：對既有語料解析失敗數
應為 0；若改用天真語意即得 130，兩者的差即為該測試的鑑別力。

## 5. 對實作票的切分指引

- Corpus 的票必須帶容錯情境（舊框架版本的殘缺文件是常態，非例外）

## 7. FR → Bundle 覆蓋對照

### SPEC-006（0.3.0 Corpus）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | frontmatter 切分與結果分類 | Corpus | domain unit；IT-1 |
| FR-02 | 掃描範圍 `docs/**/*.md` | Corpus（經 Workspace 取根目錄） | unit（檔案系統以 port 注入） |
| FR-03 | 以 `id_pattern` 判型 | Corpus（讀 Schema 型別表） | domain unit |
| FR-04 | 解析錯誤與 EVT-CORPUS-003 | Corpus | domain unit |
| FR-05 | 讀取失敗（非 UTF-8） | Corpus | unit；IT-2 |
| FR-06 | 路徑對型別查詢 | Schema | domain unit；IT-2 |
| FR-07 | 掃描結果摘要與守恆 | Corpus | domain unit；IT-2 |
| FR-08 | 由 EVT-CORPUS-003 產生破洞 | Diagnostics | domain unit；IT-2 |
| NFR-01 | 失敗隔離 | Corpus | domain unit |

全部 FR 皆有歸屬，無標為非 domain 者（破洞報告畫面接真實資料屬 0.6+，不在本版）。

> 本表為 SPEC-006 全表的權威（與 spec 同目錄，供 `check_domain_coverage` 定位）；歸屬 Schema、Diagnostics 的列在各自 domain map §7 另列副本。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
