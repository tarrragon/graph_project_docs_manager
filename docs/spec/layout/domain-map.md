---
id: DOMAIN-MAP-layout
domain: "layout"
source_specs: []
related_usecases: [UC-02, UC-03]
depends_on_bundles: [DOMAIN-MAP-graph]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — Layout

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Layout domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Layout domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：布局演算法或版型規則改變

## 2. 分層與依賴方向

層級：L3（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | Graph（`DOMAIN-MAP-graph`） | 布局的輸入是圖 |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Layout | 否 | 排列演算法為內部計算，無對外呈現面 |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Layout** | 布局演算法或版型規則改變 | 泳道／矩陣的座標與尺寸 | 排列演算法、碰撞處理 |

## 4. 邊界決策

### 4.1 Commodity check（本專案的退化形式）

本 App 無後端，領域層的「買 vs 建」退化成「用套件 vs 自己寫」：

| 能力 | 判定 | 依據 |
|------|------|------|
| 二維矩陣捲動 | **用套件** | `two_dimensional_scrollables`（publisher: **flutter.dev**，v0.5.3 / 2026-07），官方惰性二維捲動，正是大型矩陣所需 |
| 泳道布局 | **自己寫** | 產品差異化本身。`graphview` / `flutter_graph_view` 皆為力導向或樹狀，無泳道形態 |

**接縫**：委派給套件的部分，其失敗語意（套件拋錯、版本升級行為改變）
由 Layout domain 承擔並轉譯，不讓套件的例外洩漏到畫面狀態層。

## 5. 對實作票的切分指引

- Layout 的票分兩類：矩陣（委派套件、票薄）、泳道（自建、票厚）

## 6. 待決事項

- **泳道布局演算法的具體形態**（列序、欄序、分支步驟與空 `traverses` 處置）
  尚未設計。V4 探針第三、四輪反覆卡在 flow 順序、分支步驟、`traverses: []`
  佔欄三個問題上；候選演算法與 0.1 假資料階段／串真實資料階段的差異尚待列出。
  trigger：規劃下一個為 Domain 視圖串接真實資料的 minor 版本時，於其 PROP
  補記定案（來源票 `0.1.1-W3-377`，已收束為本項知識，未執行）

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

本 domain 在 SPEC-006、SPEC-007 無 FR 歸屬。SPEC-003 逐 FR 的跨 domain 對照見系統層 §8。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
