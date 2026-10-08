---
id: UC-02
title: "依 domain 盤點變更影響面"
status: draft
source_proposal: PROP-004
created: "2026-08-26"
updated: "2026-10-08"
version: "1.5"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001]
related_usecases: []
ticket_refs: []
---

# UC-02: 依 domain 盤點變更影響面

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-02 |
| 用例名稱 | 依 domain 盤點變更影響面 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | 已開啟專案且 Domain 視圖可用 |
| 成功保證 | 使用者得知該 domain 被哪些 UC flow 貫穿，以及各自貫穿的步驟 |

> 「貫穿」＝一條 UC flow 經過某個 domain，是圖上的水平關係、可計數。
> 與「穿透」（兩視圖間的雙向導覽操作）不同，定義見 `docs/system-layer.md` §1.4。

## 主要成功場景

1. **定位 domain**
   - 使用者在矩陣中找到要變更的 domain 列

2. **讀取貫穿數**
   - 該列的小計欄顯示被幾條 UC flow 直接貫穿

3. **切換至泳道**
   - 點選交叉格顯示格詳情；點選「在泳道中檢視」後系統切換至泳道模式並定位至該 domain 與該 UC

4. **檢視步驟**
   - 泳道呈現該 flow 的步驟序列，貫穿該 domain 的步驟高亮

## 替代場景

### 僅檢視全貌

使用者停留在矩陣模式比較各 domain 的貫穿數，不進入泳道

### 由 ticket 切入

使用者自 ticket 的 where.files 反查所屬 domain，系統高亮該列

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "locate-domain"
    name: "定位 domain"
    next: ["read-traversal-count"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "read-traversal-count"
    name: "讀取貫穿數"
    next: ["switch-to-swimlane"]
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph"]
  - id: "switch-to-swimlane"
    name: "切換至泳道"
    next: ["inspect-steps"]
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-LAYOUT-001"]
    traverses: ["layout"]
  - id: "inspect-steps"
    name: "檢視步驟"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "matrix-overview-only"
    name: "僅檢視全貌"
    next: []
    branch_from: "read-traversal-count"
    return_to: null
    emits: []
    consumes: []
    traverses: []
  - id: "enter-from-ticket"
    name: "由 ticket 切入"
    next: ["read-traversal-count"]
    branch_from: "locate-domain"
    return_to: null
    emits: []
    consumes: []
    traverses: ["graph", "ticketdetail"]
  - id: "flow-not-structured"
    name: "flow 未結構化"
    next: []
    branch_from: "switch-to-swimlane"
    return_to: "locate-domain"
    emits: []
    consumes: []
    traverses: ["corpus"]
    implements: ["FR-06"]
```

## 例外場景

### flow 未結構化

該 UC 無 FlowStep 時，泳道無法呈現步驟；顯示說明並提供開啟原始檔的動作

### ticket 定位的五種狀態與整體未宣告

ticket 的 `where.files` 逐路徑比對兩個宣告載體（2026-10-07 用戶裁決 P2+、2026-10-08 用戶裁決 S2 與半套宣告，`0.5.0-W1-096`／`0.5.0-W1-096.1`）：

- domain 側：各 DomainBundle frontmatter 的選填 `path_patterns`（`0.5.0-W1-096.2`）
- 非 domain 側：專案根目錄的獨立設定檔 `docs/non-domain-paths.yaml`，鍵 `non_domain_path_patterns`（`0.5.0-W1-096.6`；App 由 `tracking_schema.json` 的 `non_domain_paths_file`／`non_domain_paths_key` 取得位置，不寫死）。不寫入 `docs/system-layer.md` frontmatter

比對語意沿用上游定義：字面前綴、目錄以 `/` 結尾、相對專案根，最長前綴命中決定歸屬。依兩側宣告狀況，路徑歸入下表其中一種：

| 宣告狀況 | 命中 `path_patterns` | 命中非 domain 清單 | 兩者皆未命中 |
|---|---|---|---|
| 兩者皆有 | 命中 domain | 非 domain 層 | 無法定位 |
| 只有 `path_patterns` | 命中 domain | — | 非 domain 未宣告 |
| 只有非 domain 清單 | — | 非 domain 層 | domain 未宣告 |
| 兩者皆無 | — | — | 不逐張判定；專案整體顯示「未宣告路徑」 |
| 非 domain 清單有、`path_patterns` 只有部分 bundle 宣告 | 命中 domain | 非 domain 層 | domain 未宣告 |

**部分宣告逐 bundle 判定**（2026-10-08 用戶裁決 5c，`0.5.0-W1-096.3`）：`path_patterns` 以 bundle 為單位判定是否已宣告（欄位缺席為未宣告，`[]` 為已宣告且不收任何路徑，`0.5.0-W1-096.2`）。已宣告的 bundle 照常比對；只要仍有 bundle 未宣告，兩者皆未命中的路徑標「domain 未宣告」（可能屬於未宣告的 bundle），不算「無法定位」。所有 bundle 都宣告後才回到「兩者皆有」那一列。上表最後一列只寫非 domain 清單已宣告的情形；非 domain 清單也缺席時的標示見 `0.5.0-W1-096.9` NeedsContext。

**逐路徑顯示，不做整票歸類**（2026-10-08 用戶裁決 6a）：一張票的 `where.files` 分屬不同狀態時，每條路徑各自顯示其狀態，不把整張票歸成單一狀態。

- 矩陣高亮：取該票各路徑命中 domain 的聯集，高亮聯集內每一個 domain 的列；未命中 domain 的路徑不影響高亮
- 票列表摘要：票列表若需要整票的摘要欄，規則為「任一路徑命中 domain 即可定位」；摘要只用於列表，不取代逐路徑狀態

**破洞報告**（2026-10-08 用戶裁決 7a）：

- 「無法定位」只出現在兩側皆已宣告時，列入破洞報告的 `unlocatable` 類（`EVT-DIAGNOSTICS-001`）
- 「domain 未宣告」「非 domain 未宣告」是宣告缺口，不是資料問題，與「無法定位」分開，不計入 `unlocatable`，**不進破洞報告**；矩陣與票列表照常標示這兩種狀態
- 破洞報告頁另顯示一行專案層級的宣告狀態，畫面需求見 SPEC-001；該行列出哪些項目、以何種文字呈現未在裁決內，見 `0.5.0-W1-096.9` NeedsContext
- 「未宣告路徑」是語料層的整體狀態，不產生逐票破洞
- `lib/app/degraded_schema.dart` 與 `lib/services/scan_notifier*` 歸非 domain 層（2026-10-07 用戶裁決）；不以「試 `lib/<domain>/`」之類的預設規則代替宣告

## 驗收條件

> **前提部分未滿足，本 UC 的第 1、4 條驗收目前不可實作。** 矩陣的格
> （step → domain）已定案為 `FlowStep.traverses`（`docs/system-layer.md` §1.4，
> 2026-09-14）。仍未滿足兩項：矩陣的列（domain 清單）無資料來源——個別 domain
> 不是圖節點；「路徑模式 → domain」對照表歸屬已定（Graph）但內容未建
> （`0.1.0-W3-352`）。兩項皆列於 `docs/system-layer.md` §6。排版本順序時，
> 這些前置必須先綠燈。
> （2026-10-08 補記：列已取 `DomainBundle` 節點；對照表已改由被觀測專案宣告——
> DomainBundle `path_patterns` 與 `docs/non-domain-paths.yaml`，見〈ticket 定位的
> 五種狀態與整體未宣告〉，App 讀取由 `0.5.0-W1-096.7` 承接。）

- [ ] 矩陣的每一格明確區分直接貫穿、間接依賴、無關三種狀態
      （「直接貫穿」判定式為 `FlowStep.traverses` 包含（`0.1.0-W3-345`）；
      「間接依賴」判定式未定義，見 §9）
- [ ] 點選交叉格後泳道定位至正確的 domain 與 UC，不需使用者再次搜尋
- [ ] UC 無結構化 flow 時顯示選定 UC 標題與說明，而非空白或錯誤
- [ ] ticket 的 `where.files` 依〈ticket 定位的五種狀態與整體未宣告〉分類：
      兩側皆宣告時分為命中 domain、非 domain 層、無法定位三種，只有「無法定位」
      列入破洞報告的 `unlocatable` 類（見 `EVT-DIAGNOSTICS-001`）；只宣告一側時，
      兩者皆未命中的路徑標為缺席那一側的「未宣告」（「非 domain 未宣告」或
      「domain 未宣告」），不計入 `unlocatable`；兩側皆未宣告時專案整體顯示
      「未宣告路徑」，不逐張判定；`path_patterns` 只有部分 bundle 宣告時逐 bundle
      判定，未命中路徑標「domain 未宣告」；兩種「未宣告」不進破洞報告，報告頁顯示
      一行專案層級宣告狀態
- [ ] 一張票的 `where.files` 分屬不同狀態時逐路徑顯示，不做整票歸類；矩陣高亮
      各路徑命中 domain 的聯集；票列表摘要以「任一路徑命中 domain 即可定位」為規則

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.5 | 2026-10-08 | 落地 `0.5.0-W1-096.3` NeedsContext 用戶裁決（`0.5.0-W1-096.9`）：〈ticket 定位〉新增部分宣告逐 bundle 判定（5c）、逐路徑顯示與矩陣高亮聯集、票列表摘要規則（6a）、兩種未宣告不進破洞報告與報告頁專案層級宣告狀態一行（7a）；驗收第 4 條補述、新增第 5 條。部分宣告且非 domain 清單缺席時的標示與宣告狀態一行的內容未裁決，見該票 NeedsContext |
| 1.4 | 2026-10-08 | 例外場景「ticket 無法定位」改寫為五種狀態與整體未宣告，驗收第 4 條同步（`0.5.0-W1-096.3`，依 `0.5.0-W1-096` 用戶裁決 P2+ 與 `0.5.0-W1-096.1` 用戶裁決 S2、半套宣告）：載體為 DomainBundle `path_patterns` 與 `docs/non-domain-paths.yaml`；「無法定位」限兩側皆宣告時，半套宣告標缺席側「未宣告」，兩側皆無時整體顯示「未宣告路徑」 |
| 1.3 | 2026-09-15 | 追修門檻外矛盾（`0.1.0-W3-335.68`，依 `0.1.0-W3-335.65` WRAP 裁決 K2 可同步部分）：驗收條件第 1 條括號註「『直接貫穿』與『間接依賴』的判定式皆未定義」已過時，改「『直接貫穿』判定式為 `FlowStep.traverses` 包含（`0.1.0-W3-345`）；『間接依賴』判定式未定義，見 §9」；「間接依賴」判定式本身屬 CLAUDE.md §6 待決，本輪不裁 |
| 1.2 | 2026-09-14 | 追修 spec 間矛盾（`0.1.0-W3-335.37` R5、R1）：步驟 3 改為「點選交叉格顯示格詳情；點『在泳道中檢視』切至泳道」（.36 #12）；驗收條件第 3 條「UC 基本資訊」改「選定 UC 標題」（.36 #6） |
| 1.1 | 2026-09-14 | 驗收前提更新：格的來源已定案為 `FlowStep.traverses`，列的來源與路徑對照表內容仍未滿足（`0.1.0-W3-345` SR-2） |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
