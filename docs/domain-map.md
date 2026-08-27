---
id: DOMAIN-MAP-docs-graph
domain: "docs-graph"
source_specs: [SPEC-001]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06]
created: "2026-08-26"
updated: "2026-08-27"
---

# Domain Map — graph_project_docs_manager

> 產出來源：`saas-tech-selection` Stage 2（DDD 切分）。
> 依 SRP（一個 domain 一個變更理由）與 OCP（區分公開面與內部面）切分。
> LSP / ISP / DIP 留待實作階段。
>
> **狀態**：SPEC-001 與 UC-01~06 已建立，`source_specs`、`related_usecases`
> 已回填。§8（FR → Bundle 覆蓋對照）仍待填。

## 1. 目的與 UC / DDD 正交關係

本文件界定本 App **自身**的 domain 邊界（水平視角）。

**一個必須先講清楚的區別**：本 App 觀察的對象是框架的文件圖譜（7 節點 / 16 邊），
但那是「被觀察物的結構」，不是本 App 的責任邊界。把上游 schema 的節點型別
直接當成 domain，會切出 `PropManager` / `SpecManager` 這類以資料表為單位的
偽領域 —— 它們的責任是一種節點，不是一段業務。

本文件的切分依據是**變更理由的來源**：上游改 schema 格式、專案文件寫壞、
圖語意規則改變，這三者的來源完全不同，因此是三個 domain。

## 2. 分層與依賴方向

依賴單向向下，上層可依賴下層，反向禁止。

```
L4   畫面狀態（layer，非 domain）
L3   Layout
L2   Graph      Diagnostics      TicketDetail      History
L1   Corpus
L0   Schema     Workspace
```

**依賴邊（完整列舉，共 8 條）**：

| 來源 | 目標 | 為什麼 |
|------|------|--------|
| Layout | Graph | 布局的輸入是圖 |
| Graph | Corpus | 圖建自解析產物 |
| TicketDetail | Corpus | 詳情取自同一份解析產物 |
| Diagnostics | Corpus | 取解析錯誤清單 |
| **Diagnostics** | **Schema** | 依 `carrier` 判定「這個沒有 frontmatter 的檔案是否應為節點」（見 §7） |
| Corpus | Schema | 依 `carrier` 決定掃描哪些路徑（見 §4.2） |
| Corpus | Workspace | 取得專案根路徑 |
| History | Workspace | 取得專案根路徑後直接查 git 物件庫，不經 Corpus（見 §4.3） |

Corpus 是唯一的解析者，Graph、TicketDetail、Diagnostics 各自投影其產出——
若讓三者各自解析同一份檔案，容錯規則會分歧。

**Diagnostics 同時依賴 Corpus 與 Schema**，這是本圖唯一一個依賴兩個下層
domain 的節點：它要回答「這算不算破洞」，而該判斷需要解析結果（Corpus）
與節點型別的 carrier 定義（Schema）兩者才成立。單靠 Corpus 會把 1243 個
合法的非節點檔誤報為破洞（§7）。

## 2.5 三個易混淆詞的定義

「貫穿」與「穿透」差一個字、語意不同，且原本全批皆無定義。此處定為權威：

| 詞 | 語意 | 用在哪 |
|----|------|--------|
| **貫穿**（traverse） | 一條 UC flow **經過**某個 domain。是圖上的水平關係，可計數（「這個 domain 被 3 條 flow 貫穿」） | Domain 視圖矩陣的格、UC-02、UC-03 |
| **穿透**（drill-through） | 使用者在兩個視圖之間**雙向導覽**的操作行為（domain → UC、UC → domain） | PROP-004 §核心場景、`tech-decisions.md` §3.1 |
| **鄰接查詢** | Graph domain 的公開 API，沿邊取相鄰節點。**簽章待定**——本批未定義它吃什麼、回什麼 | §3 Graph 的公開面 |

第三項原名「穿透查詢」，與「穿透」（操作行為）同名但實為 API，已改名。
另有一個同義動詞「橫向穿過」出現在 SPEC-001 §1 與 PROP-004 §版型定案，
語意等同「貫穿」。

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Workspace** | 資料夾存取方式改變 | 目前路徑、可用性狀態、開啟原始檔 | 路徑持久化、可用性探測 |
| **Schema** | 上游 schema 格式或版本語意改變 | 型別表（節點／邊定義）、版本相容判定 | JSON 解析、`.claude/VERSION` 讀取 |
| **Corpus** | 文件格式或解析寬容度改變 | 原始節點與邊、解析錯誤清單 | 掃描策略、YAML 容錯、檔案監看 |
| **Graph** | 圖語意改變（如 symmetric union 規則） | 輕節點、邊、**鄰接查詢**（簽章待定） | 索引結構、遍歷演算法 |
| **TicketDetail** | ticket 的 5W1H 結構語意改變 | 單張 ticket 全文與生命週期欄位 | 欄位解讀、佔位值處理 |
| **Layout** | 布局演算法或版型規則改變 | 泳道／矩陣的座標與尺寸 | 排列演算法、碰撞處理 |
| **Diagnostics** | 「什麼算破洞」的定義改變 | 破洞清單（分類、嚴重度、跳轉目標） | 各類偵測規則 |
| **History** | git 查詢方式或歷史語意改變 | 節點與邊的變更事件序列 | `git log -p` 掃描、diff 解析、降級判定 |

**畫面狀態不是 domain，是 layer。** 布局演算法（有真實規則與演算法）與
畫面狀態（純 UI）分開 —— 前者可獨立測試，後者依賴 widget tree。

## 4. 邊界決策

### 4.1 Ticket 分兩層持有

Ticket 在上游 schema 中是 7 個節點型別之一，但規模上 **1295 張 vs 約 12 個
其他節點**，差兩個數量級，且有其他節點型別沒有的結構（5W1H、wave、
`tdd_phase`）。

當成「另一種節點」會讓 Graph 同時承擔圖語意與 ticket 格式兩種變更理由。
因此分兩層：

- **Graph** 持有輕節點（ID、status、邊）—— 圖需要的
- **TicketDetail** 持有 5W1H 全文與生命週期欄位 —— 詳情需要的

ticket 新增欄位只動 TicketDetail；YAML 壞掉只動 Corpus。

### 4.2 Schema 不併入 Corpus

Schema 是最薄的 domain，曾考慮併入 Corpus。否決理由：兩者變更來源完全不同
（上游改 JSON 結構 vs 專案文件寫壞），合併會讓 Corpus 承擔兩個變更理由。
Corpus 讀取 Schema 的 carrier 定義來決定掃描哪些路徑，這是依賴關係而非合併理由。

### 4.3 History 不併入 Corpus

兩者變更理由不同：Corpus 的變更來源是文件格式或解析寬容度，History 的變更
來源是 git 查詢方式或歷史語意。資料來源不同（工作目錄檔案 vs git 物件庫）、
失敗形態不同（解析失敗 vs 非 repo／git 缺失）、依賴不同。兩者不會出現在
同一個 PR 裡。

實測成本（票 `0.0.3-W1-003`，flutter_balance 9409 commits）：

| 做法 | 耗時 |
|------|------|
| 文件層級（`git log --name-only` 單次） | 1.04 秒 |
| 邊層級（逐 commit `git show`，天真實作） | 18.3 分鐘 |
| **邊層級（單次 `git log -p` + 解析）** | **2.28 秒** |

採用邊層級。載入策略沿用依視圖惰性——開啟歷史視圖才掃描。全量重掃已足夠快，
不實作增量更新：增量需維護狀態且正確性風險高，省下的時間有限。

### 4.4 編輯的寫入責任

寫入由本 App 直接改檔，CLI 僅作為驗證器。

實測（票 `0.0.3-W1-002`）顯示 CLI 寫入路徑覆蓋不足：

| 對象 | CLI 可編輯範圍 |
|------|---------------|
| 圖譜節點（PROP/SPEC/UC/EVT/DomainBundle） | 僅 `status` |
| schema 的 16 條邊 | 僅 4 條（`parent_id`／`source_ticket`／`blockedBy`／`relatedTo`，皆在 Ticket 上） |

若同時維護 CLI 與直接改檔兩套寫入路徑，兩者必然分歧，而分歧形態正是
本專案已撞到三次的索引不同步（六個框架缺陷中的三個，見
`docs/tech-decisions.md` 的缺陷補記段）。

CLI 的職責改為驗證：`doc validate`、`uc verify`、`validate-filenames`
皆為唯讀，寫入後立即呼叫，把索引不同步從靜默錯誤變成可偵測的紅燈。

此職責歸屬 Corpus（寫入）與一個新的驗證呼叫點；CLI 呼叫依賴使用者機器
裝有 `uv`——系統內建 python3 為 3.9.6，執行 doc CLI 會因 PEP 604 語法
直接 `TypeError`。

### 4.5 Domain 數量檢查

八個，觸及協議建議上限（3-6 常態，>8 懷疑切太細）。

切太細的訊號是「兩個 domain 永遠出現在同一個 PR 裡」。八個 domain 有
28 組配對，**其中三組經過實際論證**：

| 配對 | 結論 | 依據 |
|------|------|------|
| Schema × Corpus | 不共現 | §4.2（變更來源不同：上游改 JSON vs 專案文件寫壞） |
| History × Corpus | 不共現 | §4.3（資料來源、失敗形態、依賴皆不同） |
| Graph × TicketDetail | 不共現 | §4.1（ticket 加欄位只動 TicketDetail，YAML 壞掉只動 Corpus） |

其餘 25 組**未逐一檢查**。本節的結論因此限定為「已檢查的三組不共現」，
不宣稱全部 28 組皆然。若日後某兩個 domain 反覆在同一個 PR 內同時變更，
即為合併它們的訊號，屆時回頭補檢查。

## 5. 對實作票的切分指引

- 一張 ticket 原則上只動一個 domain。跨 domain 的需求先拆
- Corpus 的票必須帶容錯情境（舊框架版本的殘缺文件是常態，非例外）
- Graph 的票不得依賴 UI —— 遍歷與 symmetric union 皆為純函式，可獨立測試
- Layout 的票分兩類：矩陣（委派套件、票薄）、泳道（自建、票厚）

## 6. Commodity check（本專案的退化形式）

本 App 無後端，領域層的「買 vs 建」退化成「用套件 vs 自己寫」：

| 能力 | 判定 | 依據 |
|------|------|------|
| 二維矩陣捲動 | **用套件** | `two_dimensional_scrollables`（publisher: **flutter.dev**，v0.5.3 / 2026-07），官方惰性二維捲動，正是大型矩陣所需 |
| 泳道布局 | **自己寫** | 產品差異化本身。`graphview` / `flutter_graph_view` 皆為力導向或樹狀，無泳道形態 |
| YAML 值的解析 | 用套件 | 成熟且非差異化 |
| **frontmatter 的邊界判定** | **自己寫** | **不可用套件的通用切法**。`split("---")` 類做法會被引號字串內的 markdown 表格分隔線截斷，在既有語料上產生 130 個假失敗（見 §7）。邊界判定是本 App 的正確性核心，套件的寬容度不受我們控制 |
| 檔案監看 | 用套件 | 同上 |
| Markdown 渲染 | 用套件 | 同上 |

**接縫**：委派給套件的部分，其失敗語意（套件拋錯、版本升級行為改變）
由 Layout domain 承擔並轉譯，不讓套件的例外洩漏到畫面狀態層。

## 7. 容錯策略：部分資料，而非壞資料

實測五個框架專案 7106 份文件（量測於 2026-08-27，採框架自身的
frontmatter 解析語意——見下方「解析器語意是規格的一部分」）：

| 專案 | 可解析 | YAML 錯誤 | 無 frontmatter | 合計 |
|------|-------|----------|---------------|------|
| flutter_balance | 1313 | 0 | 25 | 1338 |
| book_overview_app | 1597 | **1** | 817 | 2415 |
| book_overview_v1 | 2456 | 0 | 413 | 2869 |
| monitor | 249 | 0 | 18 | 267 |
| screen_clock | 200 | 0 | 17 | 217 |
| **合計** | **5815** | **1** | **1290** | **7106** |

**YAML 損壞幾乎不存在（1 / 7106）。真正的常態是「沒有 frontmatter」。**

> **本節已於 2026-08-27 全面改寫。** 先前版本宣稱 flutter_balance 有 130 個
> YAML 錯誤、成因為未閉合的單引號字串、100% 可部分救回平均 20.3 個欄位，
> 並據此建立整套容錯策略。該數字是量測腳本的產物：以
> `content.split("---")` 取 `parts[1]` 會被 frontmatter 引號字串內的
> markdown 表格分隔線（`|---|---|`）截斷，恰好產生 130 筆假錯誤。
> 改用框架自身的逐行語意後，同一批檔案的錯誤數為 0。詳見
> `docs/tech-decisions.md` 的撤回補記。

### 解析器語意是規格的一部分

本 App 是解析文件的工具，因此**解析器的選擇本身就是正確性問題**，不是實作細節。

| 語意 | 做法 | 在 flutter_balance 1300 張 ticket 上的結果 |
|------|------|------------------------------------------|
| **逐行（採用）** | 首行為 `---`，往下找第一個 `strip() == "---"` 的行 | 0 個解析失敗 |
| 天真（禁用） | `content.split("---")` 取 `parts[1]` | **130 個假失敗** |

**Corpus domain 必須採逐行語意。** 契約測試以此為斷言：對既有語料解析失敗數
應為 0；若改用天真語意即得 130，兩者的差即為該測試的鑑別力。

### 真正的失敗形態：無 frontmatter，且多數是合法的

1290 個無 frontmatter 的檔案並非全屬異常：

| 型態 | 數量 | 判定 |
|------|------|------|
| work-logs 下的非 ticket 檔（工作日誌） | 920 | 合法非節點 |
| 其他 `docs/` 散檔 | 289 | 合法非節點 |
| README / index | 34 | 合法非節點 |
| **`tickets/` 目錄下卻無 frontmatter** | **40** | **真異常** |
| **圖譜節點目錄下卻無 frontmatter** | **7** | **真異常** |

**這才是容錯設計的真正難題**：1243 個是合法的，47 個是真破洞，兩者的
外觀完全相同（都是「沒有 frontmatter 的 .md」）。唯一的區別是**它的完整
相對路徑是否符合某個節點型別的 carrier 路徑模式**——carrier 定義來自
`tracking_schema.json` 的 `carrier` 欄位（見 §3 Schema domain 的公開面）。

> **必須比對完整路徑模式（含檔名），不是只比對所在目錄。** 實測
> `book_overview_v1`：目錄讀法報 8 項、其中 7 項是誤報
> （`docs/spec/README.md`、`docs/spec/csv-export-spec.md` 等落在 carrier
> 目錄內但不符檔名模式）；完整路徑模式讀法報 1 項。
> 本節先前寫作「所在目錄」，已於 2026-08-27 的個案實跑（frame 3-H）更正。

**carrier 重疊時取最具體者。** `DomainBundle` 的 carrier
（`docs/spec/{domain}/domain-map.md`）是 `SPEC` 的 carrier
（`docs/spec/{domain}/{slug}.md`）的真子集，一個檔可同時命中兩者。
比對順序為最長字面前綴優先，否則 per-domain 的 domain-map 會被判成
id 不合法的 SPEC——實測 `monitor` 有 3 份、`book_overview_v1` 有 5 份
會踩到這個情形。

若不做這個區分，破洞報告會一次吐出 1290 項而其中 96% 是雜訊，使用者用一次
就不會再用。

### 策略

1. **盡力解析** —— 單檔失敗不中止整輪，救回可讀的欄位
2. **依 carrier 判定是否為預期節點** —— 只有落在節點 carrier 路徑下卻缺
   frontmatter 的檔案才進破洞報告；其餘靜默略過
3. **損壞顯性化，依嚴重度分級** —— 邊損壞（影響圖結構）以視覺差異呈現
   （虛線框／降低不透明度）；詳情損壞（僅影響內容）以圖示加數量徽章呈現
4. **破洞報告即修復清單** —— 檔案、行號、錯誤成因，資訊足以直接去修
5. **無法讀取的欄位顯示「因檔案損壞而無法讀取」**，不顯示空白

> 第 3 點的兩級分法是**設計判斷，非量測結論**。它原先的實證依據
> （130 個損壞檔案的欄位損失分佈）已隨該 artifact 一併失效；目前的語料中
> 只有 1 個 YAML 錯誤，不足以支撐任何分佈性宣稱。兩級分法保留的理由是
> 語意上的——邊損壞會讓圖畫錯，詳情損壞只讓內容缺一塊，兩者對使用者的
> 意義不同。實際發生率待累積更多語料後再驗。

核心原則：**壞資料是專案的缺陷，本 App 的職責是讓它被看見，不是替它掩蓋。**
但「被看見」的前提是**不誤報**——一個會把 1243 個正常檔案報成破洞的工具，
和一個什麼都不報的工具，對使用者是同一件事。

診斷入口不另行設計——破洞報告即是入口，因為解析失敗與圖結構缺陷本質同類
（皆為「這個專案的文件有問題」），分成兩處會讓使用者需要記住兩個入口。

## 8. FR → Bundle 覆蓋對照

待 SPEC 產出後回填。

## 9. 待決事項

- 搜尋與全域導覽若納入，歸屬 Graph（查詢）或獨立 domain（索引）待定
- `Diagnostics` 的破洞類別權威清單見 `EVT-DIAGNOSTICS-001`（本檔不複述計數），
  各類別下的具體項目與嚴重度尚未列舉。UC-06 的驗收條件依賴此清單
- 泳道布局演算法的具體形態（排序、泳道指派、邊繞線）尚未設計
- 矩陣的列（domain 清單）與格（step → domain）皆無資料來源：上游 schema 中
  `DomainBundle` 的 carrier 是整份 domain-map.md，個別 domain 不是圖節點；
  `FLOWSTEP_REQUIRED_FIELDS` 亦無 `domain` 欄位
- UC → Ticket 在上游 16 條語意邊中無對應邊。追溯視圖（UC-04）第四層的
  資料來源未定
- **「路徑模式 → domain」對照表不存在。** PROP-004 的「以 ticket 切入」
  模式要求用 `where.files` 反查 domain，並指名對照本檔推導；但本檔全篇
  以「唯一變更理由」定義 domain，未標註任何 domain 涵蓋哪些路徑。
  該表建立前，UC-02 的「無法定位」判定與矩陣的 ticket 高亮皆不可實作
- **檔案級 carrier 的破洞判定**：§7 的判準寫成「所在目錄是否為某節點型別的
  carrier」，但 `DomainBundle` 的 carrier 是整份 `domain-map.md`
  這**一個檔案**，非目錄。碰到檔案級 carrier 時該判準無法套用
- **【最高優先】被觀察專案的框架版本只在 schema gate 是變數，其餘判準都不是。**
  這是 frame 3-H 個案實跑的收束結論，本節其餘待決項多為它的投影。

  PROP-002 把版本偏斜認定為決定性因素並據此否決建置期烘 JSON——判斷正確，
  但那個變數只被帶進**一個**地方就停住了。carrier 判定、破洞四類、
  `id_pattern` 契約、矩陣的列與格、UC 前置條件、切分指引，全部以
  「型別表存在且形狀如 2.4x」為隱含輸入。

  **實測全機 17 個有 `.claude/` 的專案，輸入形態有五類，規格只處理其中一類**：

  | 類別 | 數量 | 特徵 | 現有判準的答案 |
  |------|:---:|------|---------------|
  | 完整 | **1** | 2.42.0，`tracking_schema.json` 齊備 | 可載入 |
  | 有型別表無 JSON | 1 | 2.40.2（**本專案自己**），`.py` 318 行 | 無 |
  | 舊型別表 | 5 | 2.22.1–2.27.8，`.py` 僅 78 行，**無 `GRAPH_NODE_TYPES`／`GRAPH_EDGE_TYPES`／`carrier`** | 無 |
  | 有框架無 doc skill | 4 | 1.1.46–1.23.1，無 `tracking_schema.py` | 無 |
  | 非框架專案 | 6 | 有 `.claude/` 但無 `VERSION`、無 `docs/` | 無 |

  **可正常載入者 1/17 = 5.9%。** 判準對「版本太新」有明確答案，
  對「太舊」「沒有 doc skill」「根本不是框架專案」三類沒有答案，
  而後三者是 94% 的實際輸入。

  這不是「同一份 schema 的版本偏斜」——在 2.2x 那批上，圖譜型別表**尚未出生**。

  **可檢驗的後果**：`PROP-003` §風險點名 `book_overview_v1` 與 `monitor`
  作為「驗證解析寬容度」的語料，`SPEC-001` §設計約束要求假資料涵蓋
  「舊框架版本缺欄位」——但這兩個專案會在 UC-01 第 2 步（載入型別表）
  被 gate 擋下，第 3 步（解析節點）永遠不會執行。**規格為寬容度準備的語料，
  會在寬容度有機會作用之前就被拒絕**；唯一能通過 gate 的 `flutter_balance`
  正好是所有效能數字的量測來源，也就是唯一不需要寬容度的那一個。

  **修法方向不是補齊本節其餘待決表**（補完之後上述四類仍停在同一位置），
  而是先把「被觀察專案的框架版本」提升為貫穿全部判準的一等輸入，
  並回答三個今天沒有答案的問題：型別表缺席時 Corpus 用什麼掃描、
  `id_pattern` 隨版本變動時舊語料的不合法 id 歸哪一類破洞、
  選到非框架專案時走哪條退出路徑
- **五個節點型別沒有必填欄位定義**：schema 只為 `EVT` 與 `FlowStep` 定義了
  `*_REQUIRED_FIELDS`，`PROP` / `SPEC` / `UC` / `Ticket` / `DomainBundle`
  皆無。`EVT-CORPUS-003` 的 payload 明列 `lostFields`，但對 7 個型別中的
  5 個不可計算，`severity` 分級因此在多數情況無輸入
- **`鄰接查詢` 的簽章未定**（§2.5）：Graph 的公開面列了它，但吃什麼、回什麼、
  幾 hop 皆無。矩陣的「間接依賴」判定會落在這個 API 上
- **UC-04 四層樹的第二跳欄位未明訂**：自 PROP 展開時，走
  `SPEC.related_usecases` 或 `UC.source_proposal` 會得到不同的樹。
  本批文件自身即有實例——UC-01 自報 `source_proposal: PROP-003`，
  但其 `related_specs: [SPEC-001]` 而 SPEC-001 掛在 PROP-004 底下
