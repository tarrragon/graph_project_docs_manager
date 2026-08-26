---
id: DOMAIN-MAP-docs-graph
domain: "docs-graph"
source_specs: []
related_usecases: []
created: "2026-08-26"
updated: "2026-08-26"
---

# Domain Map — graph_project_docs_manager

> 產出來源：`saas-tech-selection` Stage 2（DDD 切分）。
> 依 SRP（一個 domain 一個變更理由）與 OCP（區分公開面與內部面）切分。
> LSP / ISP / DIP 留待實作階段。
>
> **狀態**：SPEC 與 UC 尚未建立，因此 `source_specs`、`related_usecases`
> 為空，§7（FR → Bundle 覆蓋對照）待 SPEC 產出後回填。

## 1. 目的與 UC / DDD 正交關係

本文件界定本 App **自身**的 domain 邊界（水平視角）。

**一個必須先講清楚的區別**：本 App 觀察的對象是框架的文件圖譜（7 節點 / 16 邊），
但那是「被觀察物的結構」，不是本 App 的責任邊界。把上游 schema 的節點型別
直接當成 domain，會切出 `PropManager` / `SpecManager` 這類以資料表為單位的
偽領域 —— 它們的責任是一種節點，不是一段業務。

本文件的切分依據是**變更理由的來源**：上游改 schema 格式、專案文件寫壞、
圖語意規則改變，這三者的來源完全不同，因此是三個 domain。

## 2. 分層與依賴方向

```
畫面狀態（layer，非 domain）
        │  依賴（單向）
        ▼
Layout ──────┐
        │     │
        ▼     ▼
Graph      Diagnostics      TicketDetail
        │     │                  │
        └──┬──┴──────────────────┘
           ▼
        Corpus
           │
     ┌─────┴─────┐
     ▼           ▼
  Schema     Workspace
```

依賴方向單向向下。Corpus 是唯一的解析者，Graph 與 TicketDetail 各自投影
其產出 —— 若讓兩者各自解析同一份檔案，容錯規則會分歧。

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Workspace** | 資料夾存取方式改變 | 目前路徑、可用性狀態、開啟原始檔 | 路徑持久化、可用性探測 |
| **Schema** | 上游 schema 格式或版本語意改變 | 型別表（節點／邊定義）、版本相容判定 | JSON 解析、`.claude/VERSION` 讀取 |
| **Corpus** | 文件格式或解析寬容度改變 | 原始節點與邊、解析錯誤清單 | 掃描策略、YAML 容錯、檔案監看 |
| **Graph** | 圖語意改變（如 symmetric union 規則） | 輕節點、邊、穿透查詢 | 索引結構、遍歷演算法 |
| **TicketDetail** | ticket 的 5W1H 結構語意改變 | 單張 ticket 全文與生命週期欄位 | 欄位解讀、佔位值處理 |
| **Layout** | 布局演算法或版型規則改變 | 泳道／矩陣的座標與尺寸 | 排列演算法、碰撞處理 |
| **Diagnostics** | 「什麼算破洞」的定義改變 | 破洞清單（分類、嚴重度、跳轉目標） | 各類偵測規則 |

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

### 4.3 Domain 數量檢查

七個，在協議建議上限的邊緣（3-6 常態，>8 懷疑切太細）。已檢查切太細的訊號：
沒有任何兩個 domain 會永遠出現在同一個 PR 裡。

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
| YAML / frontmatter 解析 | 用套件 | 成熟且非差異化 |
| 檔案監看 | 用套件 | 同上 |
| Markdown 渲染 | 用套件 | 同上 |

**接縫**：委派給套件的部分，其失敗語意（套件拋錯、版本升級行為改變）
由 Layout domain 承擔並轉譯，不讓套件的例外洩漏到畫面狀態層。

## 7. 容錯策略：部分資料，而非壞資料

實測五個框架專案（7000+ 份文件）後，**解析失敗是常態而非例外**：

| 專案 | 可解析 | YAML 錯誤 | 無 frontmatter |
|------|-------|----------|---------------|
| flutter_balance | 1182 | **130** | 4 |
| book_overview_app | 1566 | 1 | 150 |
| book_overview_v1 | 2456 | 0 | 200 |
| monitor | 245 | 0 | 11 |
| screen_clock | 199 | 0 | 1 |

（`無 frontmatter` 含 README 等本來就非節點的檔案，非全屬異常。）

flutter_balance 是維護最積極的專案，卻有 130 個 YAML 錯誤，且**全部同一成因**：
未閉合的單引號字串（斷點總落在 `how.strategy`），把後續內容連同結束分隔符
一併吞入。這是上游 ticket CLI 的寫入端缺陷，已回報。

### 損壞是部分的，且損失位置有規律

實測 130 個損壞檔案的可救回程度：

| 欄位 | 損失率 |
|------|--------|
| `id` / `title` / `status` / `type` | **0%** |
| `where` | 8 / 130 |
| `why` / `how` | 41 / 130 |
| `acceptance` | **130 / 130** |

**100% 可部分救回，平均救回 20.3 個欄位。** 損壞自斷點向後蔓延，
斷點之前的欄位完好。

這個分佈精準對應 §4.1 的 Ticket 兩層切分——Graph 需要的輕節點欄位
（`id` / `status` / 邊）100% 可救，TicketDetail 需要的 5W1H 才是損失部分。
該切分原本的理由是規模差，在容錯面向上同樣成立。

### 策略

依 WRAP 分析（見 `docs/tech-decisions.md` 補記）：

1. **盡力解析** —— 救回斷點前的所有欄位
2. **損壞顯性化** —— 依嚴重度分級標記：
   - 邊損壞（影響圖結構）→ 視覺差異（虛線框／降低不透明度）
   - 詳情損壞（僅影響內容）→ 小圖示 + 數量徽章
3. **破洞報告即修復清單** —— 檔案、行號、錯誤成因，資訊足以直接去修
4. **必然損失的欄位顯示「因檔案損壞而無法讀取」**，不顯示空白

核心原則：**壞資料是專案的缺陷，本 App 的職責是讓它被看見，不是替它掩蓋。**
純寬容方案會讓 130 張壞票永遠沒人發現；純嚴格方案會讓 10% 的 ticket 消失、
App 在最活躍的專案上不可用。兩者皆不可取。

診斷入口不另行設計——破洞報告即是入口，因為解析失敗與圖結構缺陷本質同類
（皆為「這個專案的文件有問題」），分成兩處會讓使用者需要記住兩個入口。

## 8. FR → Bundle 覆蓋對照

待 SPEC 產出後回填。

## 9. 待決事項

- 搜尋與全域導覽若納入，歸屬 Graph（查詢）或獨立 domain（索引）待定
- `Diagnostics` 的破洞分類清單尚未列舉
- 泳道布局演算法的具體形態（排序、泳道指派、邊繞線）尚未設計
