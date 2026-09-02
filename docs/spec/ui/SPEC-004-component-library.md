---
id: SPEC-004
title: "元件庫規格：元件目錄、逐元件契約與容器排列不變式"
status: draft
source_proposal: PROP-004
created: "2026-09-02"
updated: "2026-09-02"
version: "0.1"
owner: lavender-interface-designer

domain: "ui"
subdomain: component-library

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06]
related_specs: [SPEC-001, SPEC-002, SPEC-003]
implements_requirements: []
depends_on_domains: [layout]
---

# 元件庫規格（L3 元件庫章節）

**版本**: 0.1（第 1-3 章定案候選；第 4-9 章為骨架，由後續票填寫）
**來源**: PROP-004
**依賴**: SPEC-002（token 來源，`lib/tokens/`）、SPEC-003（互動反應來源）、SPEC-001（狀態表，元件候選的書面來源）

> **層級定位**（component-library 方法論）：L1 通用原則（方法論）、L2 框架實作規範、
> L3 專案元件庫章節（本檔）。本檔為 L3，承載元件清單、逐元件契約（十一欄位）、容器元件與排列不變式、
> 原生禁用對照、豁免清單、形態因素矩陣、狀態綁定決策。
>
> **與 SPEC-002 的分工**：SPEC-002 是 token 規格（顏色、間距、字級、圓角的命名與離散尺度），
> 其〈元件庫的範圍〉一節的清單自本檔建立起改為指向本檔第 3 章，清單不雙份維護。
> 本檔引用 token 一律寫 `lib/tokens/` 的常數名（`AppColors.*`、`Space.*`、`Radius.*`、`AppFontSize.*`），
> 不出現裸值；視窗尺寸引用 `lib/main.dart` 的 `kDesignSize` 與 `kMinWindowSize`。
>
> **推導程序**：依 `component-contract-design` skill，本專案起點判定為「有畫布、有規格、頁面尚未呼叫任何元件」，
> 走模式 B（畫布拆解四步）再進模式 A 自存在必要性起的步驟。第 3 章保留推導記錄（3.2–3.5），
> 使合併與不合併的結論可被核定；核定後可刪推導記錄只留總表。
>
> **標記慣例**：「提案」= 執行者的結論，待 PM 於本規格票驗收核定；「待核定」= 需 PM 或用戶簽核的決策
> （版型拆分屬用戶簽核）；「待決」= 缺答案且來源不可得，該欄位視同空白，元件不得被畫面票引用。

---

## 1. 形態因素矩陣（Form Factor，先決）

> 形態由使用者的操作方式定義，不由顯示空間定義（方法論〈形態因素先決〉）；每個支援的形態各自設計容器版型，
> 同一形態內的尺寸差異由第 5 章排列不變式承載。支援幾個形態屬用戶簽核決策，PM 不得自行拍板。
>
> **本節狀態：已核定（2026-09-02，版型策略與文字縮放為用戶簽核，其餘 PM 核定）。** SPEC-001 / SPEC-002
> 皆無形態因素明文；下表依 CLAUDE.md §6 的視窗尺寸決策與 PROP-004〈版型定案〉填寫，理由欄註明來源。
> 第 4 章尺寸契約與測試點的「每種尺寸」以本表兩種測試尺寸為準。

| 維度 | 結論（提案） | 理由 |
|------|------|------|
| 螢幕尺寸範圍 | 桌機單視窗，macOS 12.0+；視窗可縮放，下界為 `kMinWindowSize`（macOS `minSize`），設計基準為 `kDesignSize`（預設視窗尺寸），無上界（可最大化） | CLAUDE.md §1 目標平台「僅 macOS」、§6「防跑版主力 = macOS minSize + 約束式佈局」；PROP-004〈版型定案〉的設計基準與 macOS 系統字（數值以 `lib/main.dart` 常數為準，本檔不複述） |
| 縮放策略 | `flutter_screenutil` 以 `kDesignSize` 為基準等比縮放；縮放**不**取代約束式佈局，元件的尺寸契約須在 `kMinWindowSize` 下不溢位 | CLAUDE.md §6「ScreenUtil 只做等比縮放，不阻止 overflow」 |
| 測試尺寸集合 | 兩種：`kMinWindowSize`、`kDesignSize`。不加入第三種「大於設計基準」尺寸（PM 核定 2026-09-02）：填滿父容器的元件以最大尺寸契約承載拉伸上限；W1-005 實測若發現需要再由該票 spawn | 兩種尺寸皆有具名常數可引用；第三種尺寸無專案決策來源，不自行發明數值 |
| 輸入模態 | 指標（滑鼠／觸控板）+ 鍵盤；不支援觸控。元件狀態集含 hover / focused；命中區尺寸依指標慣例 | 桌機平台；SPEC-003 §2.10 定焦點與鍵盤的 0.1 下界（Esc 收合浮層、焦點回到入口） |
| 方向支援 | 不適用（桌機視窗無直橫持切換）；視窗尺寸變更不重置任何狀態 | SPEC-003 §2.8「視窗尺寸變更：不重置、不重新載入」 |
| 特殊表面 | 無（0.1 無桌面 widget、懸浮視窗、畫中畫）；唯一的覆蓋層是專案切換浮層，屬 App 內 overlay 非系統表面 | PROP-004〈範圍界定〉專案切換收為側欄浮層 |
| 文字縮放適應 | 0.1 不承諾 a11y 動態字級（用戶簽核 2026-09-02），`textScaler` 固定；元件高度以字級 token 推算的固定值。重評綁定後續版本的提案票（見 §3.7） | 無任何規格提及動態字級；若承諾則所有固定高度列（表格列、導覽項）須改為彈性高度，影響第 4 章尺寸契約全部條目 |
| 同形態內的尺寸適應策略 | 形式 (a)：以 `kMinWindowSize` 約束視窗下界使常駐側欄版型不需切換，其餘差異由各容器的排列不變式（換行／捲動／收合）承載；不提供使用者可選版型；不以視窗寬度切換版型，元件內不硬編碼尺寸門檻 | 同一形態（桌機）內的視窗縮放不改變操作方式；CLAUDE.md §6「防跑版主力 = minSize + 約束式佈局」；SPEC-001〈設計約束〉「0.1 的斷言是畫得出來、不溢位、能捲能拖」 |
| 覆蓋表面對映 | 桌機：專案切換用自入口向下展開的彈出面板（`SwitcherOverlay`）、阻擋狀態的版本詳情用面板內展開（`BlockedState.withDetail`）、暫時訊息用 SnackBar；無 bottom sheet、無抽屜 | 指標加鍵盤形態的慣例；SPEC-003 §2.7 浮層可用性與 Esc 收合 |
| 回饋通道 | 視覺（hover、pressed 狀態與 SPEC-003 §2.2 的回饋層級）；無觸覺、無聲音 | 桌機指標不遮住元件，視覺回饋可見；方法論〈形態因素先決〉回饋通道列 |
| 最小命中區 | `LayoutSize.hitTargetMin`（28px，`lib/tokens/layout.dart`），可點元件的最小尺寸不得小於之 | 桌機命中區可小於手機下限，但仍需具名以供尺寸契約引用 |
| 禁放區與安全區 | 無禁放區（視窗四角無觸控不靈敏問題）；無 SafeArea 需求（macOS 視窗無瀏海與手勢區），框架容器 `AppShell` 以視窗邊緣內距 token 承載留白 | 桌機視窗；`AppShell` 為根框架容器 |
| 支援的形態 | **單一形態：桌機（指標 + 鍵盤、多視窗、長時工作）**（用戶簽核 2026-09-02）；不支援平板與手機形態 | 形態依操作方式界定（方法論〈形態因素先決〉）；本專案目標平台僅 macOS，唯一操作方式是指標加鍵盤，無第二形態 |

---

## 2. 狀態綁定模式（L2 決策）

> 狀態管理方案在元件庫設計時決定，不留給實作各自選擇。
> 本節依 `docs/tech-decisions.md` 補記「2026-08-26：Stage 4 技術維度定案」（狀態管理定為 Riverpod）
> 與 `.claude/skills/dart-provider-architecture/SKILL.md` 填寫；標「提案」者為本檔新增的 L2 條文，待 PM 核定。

| 項目 | 決定 |
|------|------|
| 狀態管理方案 | Riverpod（`flutter_riverpod`；理由為生態一致性：`dart-provider-architecture` skill、`parsley-flutter-developer` 代理人、flutter_balance 皆採 Riverpod） |
| 元件接收狀態形式 | **傳值 + callback**（提案）。元件庫元件（第 3 章「元件」種類）為純 widget：建構子接收值型參數與 `VoidCallback` / `ValueChanged`，**不**在元件內 `ref.watch`；provider 的 watch 落在頁面層或容器元件層。理由：元件的測試契約要求一支 widget test 逐一渲染全部變體與狀態，純 widget 不需 `ProviderScope.overrides` 即可渲染；同一元件被多個 provider 驅動（如載入態被三個畫面的三個 provider 驅動）時，元件不綁定任一 provider 型別 |
| 容器元件的例外 | 資料視圖容器（第 3 章標「資料視圖」的容器：矩陣、泳道、表格、樹）得為 `ConsumerWidget`，watch 其資料 provider 並以 `select` 縮小重繪範圍（提案）。理由：資料視圖的列數以真實規模（不低於 1300 筆）計，逐列傳值會使頁面層持有整份清單並在每次變更重建整棵子樹 |
| 最小重繪邊界 | 以 `Consumer` / `ConsumerWidget` 包住需要重繪的**最小子樹**，watch 時一律 `ref.watch(provider.select((s) => s.field))` 只訂閱用到的欄位；`ref.read` 只在事件回呼內使用（提案，沿用 dart-provider-architecture skill 的 `ref.read` / `ref.watch` 規則） |
| 導覽狀態 | 既有 `selectedDestinationProvider`（`StateProvider<AppDestination>`，`lib/app/router.dart`）；`AppShell` 為 `ConsumerWidget`。導覽項元件本身傳值（`isSelected` + `onTap`），不 watch |
| 頁面狀態保留 | 六頁由 `IndexedStack` 一次建構，切換導覽項不 dispose（SPEC-003 §2.8）；因此畫面級狀態（捲動 offset、雙模式選擇、搜尋詞、樹展開集合）須存於 provider 或頁面的 `State`，**不得**存於元件庫元件內部（元件庫元件為無狀態或僅持有互動瞬態如 hover） |
| 高頻場景效能檢核 | 虛擬捲動表格（Ticket 清單，`scroll-tickets-list`）與二維捲動矩陣（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`）於元件票驗收時以真實規模假資料做 Profiler 抽查（提案；量化上限不設，依方法論 L2 判準「量化上限為選配」） |

---

## 3. 元件清單總表

> 容器元件（決定多個元件如何相對排列的佈局結構：按鈕列、兩欄說明列表、帶操作欄的表格列、
> 附說明文字的區塊）一併列入，種類欄標「容器」。判別問句：畫面上任兩個元件的相對位置是誰決定的？
> 答案是「頁面本身」即缺一個容器元件。
>
> **元件／容器的判別（本檔約定）**：內部佈局不含其他元件庫元件、或只含一個固定位置的子件者為「元件」
> （如導覽項的 icon + 文字，其 icon 是元件自身的 slot 而非鄰件）；子件為兩個以上元件庫元件、且相對位置由本結構決定者為「容器」。
> 選項型元件（點擊選取的單一動作，如導覽項、最近專案項）依此為元件；資料列（欄位對齊表頭或多欄位並排）為容器。
>
> **層級欄**：L2 = 與本專案語意無關、可跨專案重用的複合元件；L3 = 承載本專案語意（domain、UC、ticket、破洞）的元件。
> **出現畫面欄**以 SPEC-001 章節號表示（§1 Domain 視圖、§2 UC Flow、§3 追溯、§4 Ticket 清單、§5 破洞報告、§6 節點詳情、§7 專案切換浮層、殼 = 六畫面共用的框架層）。
> **變體欄**為語意名，變體數量與最終命名定於第 4 章（L2 決策）；本表為候選。

### 3.1 總表

#### 元件（非容器）

| 元件 | 種類 | 層級 | 用途 | 出現畫面 | 變體（variant） |
|------|------|------|------|---------|----------------|
| `AppText`（文字） | 元件 | L2 | 所有可見文字的唯一載體，依字級 token 與語意角色渲染；容器的子件清單以此具名 | 全部 | `title` / `subtitle` / `body` / `caption` / `mono`（等寬：ID、路徑）；強調（`emphasis`）與弱化（`secondary`，`AppColors.textSecondary`）為修飾參數 |
| `AppIcon`（圖示） | 元件 | L2 | 語意圖示（資料夾、六個導覽圖示、展開箭頭、外開箭頭、損壞）；尺寸只取具名階 | 殼、§3、§4、§5、§7 | 不適用（尺寸階與顏色為參數；圖示尺寸階 token 待第 4 章向 `lib/tokens/` 補） |
| `Divider`（分隔線） | 元件 | L2 | 區隔堆疊中的群組 | §6、§7 | 不適用（原子元件） |
| `AppButton`（按鈕） | 元件 | L2 | SPEC-001「可用操作」欄所有有視覺承載的動作：開始載入、取消、重新掃描、重新整理、返回、開啟原始檔、檢視關聯、返回 Domain 視圖、前往破洞報告、開啟 docs 目錄、檢視詳情、選擇資料夾、選擇其他 | §1–§7 | `primary`（前進／主要動作）/ `secondary`（取消、返回、重新整理）/ `text`（低強調、可帶 leading icon，如浮層底部「選擇其他資料夾…」）；變體集**待核定** |
| `Badge`（徽章） | 元件 | L2 | 非互動的標籤／數值標記 | §1–§7 | `count`（計數，`AppColors.error` 底）/ `status`（draft／pending／completed／confirmed／approved，依狀態取 `AppColors.success`／`warning`／`textSecondary`）/ `type`（PROP／SPEC／UC／Ticket）/ `category`（破洞類別：資料損壞／追溯缺口／圖結構）/ `event`（emits X）/ `tag`（domain: schema、N 個 FR）/ `legend`（圖例：符號 + 說明）/ `health`（專案健康）；「chip 底」與「純文字」兩種外觀是否為變體**待核定**（見 3.3 第 8 項） |
| `IssueMarker`（問題標記） | 元件 | L3 | 修飾既有節點或欄位的問題標記，可點擊跳轉破洞報告 | §3、§4、§6 | `damagedEdge`（邊損壞：虛線框／降低不透明度，FR-05）/ `damagedDetail`（詳情損壞：圖示 + 計數徽章，`badge-tickets-corrupted`；欄位級附說明文字 slot）/ `gap`（追溯缺口：虛線框 + 「缺口」標籤，`badge-traceability-broken-<layer>`） |
| `NavItem`（導覽項） | 元件 | L3 | 側欄六項導覽，`nav-item-<destination>` | 殼 | `default`；狀態 selected / unselected / hover |
| `ProjectSwitcherEntry`（專案切換入口） | 元件 | L3 | 側欄頂端：資料夾圖示 + 目前專案名（單行截斷）+ 展開箭頭；= SPEC-001 §7 收合態，`project-switcher-entry` | 殼 | `default`；阻擋狀態下恆 enabled（SPEC-003 §2.7 浮層可用性斷言） |
| `RecentProjectItem`（最近專案項） | 元件 | L3 | 浮層內單一專案選項：圖示 + 名稱 + 摘要（節點數 · 票數）+ 健康徽章 slot + 不可用原因常駐文字，`card-switcher-recent-<index>` | §7 | `default`；狀態 enabled / disabled（附原因文字，不用 tooltip）/ selected（目前專案） |
| `SegmentedControl`（分段控制） | 元件 | L3 | 雙模式切換（矩陣／泳道、列表／主題），`mode-*` | §1、§4 | `default`；段數上限 2（0.1 只有雙模式畫面） |
| `PageTitle`（頁面標題） | 元件 | L3 | 頁首左側：畫面名 + 一行副標（模式說明或選中摘要） | §1–§6 | `default`；副標為可選 slot |
| `SearchField`（搜尋框） | 元件 | L2 | Ticket 清單工具列搜尋，`input-tickets-search` | §4 | `default`；狀態 empty / filled / focused |
| `FilterDropdown`（篩選下拉） | 元件 | L2 | 「狀態：pending」「優先：全部」類的篩選觸發器，`action-tickets-filter-<key>` | §4 | `default`；狀態 default / active（有篩選值）/ open |
| `TableColumnHeader`（表格欄首） | 元件 | L2 | 表格與矩陣的欄首標籤；矩陣欄首為兩行（UC ID + 名稱） | §1、§2、§4 | `static` / `sortable`（`action-tickets-sort-<key>`，狀態 unsorted / asc / desc）/ `twoLine`（矩陣欄首，提案併入本元件，見 3.3 第 10 項） |
| `MatrixCell`（矩陣格） | 元件 | L3 | domain × UC 交叉格的關係符號，可點擊切至泳道，`cell-domain-<rowId>-<colId>` | §1 | `direct`（● `AppColors.accent`）/ `indirect`（○ `AppColors.textSecondary`）/ `none`（· `AppColors.borderStrong`）；狀態 default / hover / rowSelected（列高亮 `AppColors.surfaceIconTint`） |
| `SwimlaneNode`（泳道節點） | 元件 | L3 | 泳道格內的動作標籤（掃描、解析、建圖…），0.1 不可點、不可拖 | §1 | `active`（`AppColors.accent` 底、白字）/ `inactive`（`AppColors.surfaceChip` 底） |
| `StepNumber`（步驟序號） | 元件 | L3 | 步驟列與詳情卡步驟清單的序號 | §1（詳情卡，待核定）、§2 | `default`；畫布圓形（§2）與方形（§1 詳情卡）不一致，形狀歸 token 或變體**待核定** |
| `ExpanderIcon`（展開收合） | 元件 | L2 | 樹節點、主題節、破洞分節的展開觸發器，`expander-*` | §3、§4、§5 | `default`；狀態 expanded / collapsed / leaf（無子層時不渲染箭頭但保留寬度） |
| `RelationItem`（關聯項） | 元件 | L3 | 節點詳情右欄的關聯節點 ID，等寬字、chip 底、可點擊替換主欄，`card-nodeDetail-relation-<nodeId>` | §6 | `default`；狀態 default / hover / damaged（邊損壞時套 `IssueMarker.damagedEdge`） |
| `DocumentBody`（文件內文） | 元件 | L3 | 節點詳情主欄的 markdown 渲染內容（段落、行內 code、FR 引用區塊）；由 0.0.3 選定的 markdown 渲染器承載 | §6 | `default`；是否屬元件庫或屬 feature 層**待核定**（見 3.3 第 15 項） |
| `EmptyState`（空狀態） | 元件 | L3 | 「這裡目前沒有內容」+ 至少一個非返回的前進動作（FR-03）；訊息、說明、動作為 slot | §1（未選專案、空圖）、§2（無 UC、flow 未結構化）、§3（無提案）、§4（無 ticket）、§5（無破洞）、§6（未選節點、原始檔已消失）、§7（無最近專案） | `page`（全頁）/ `section`（區塊內，與 UC 基本資訊並列）/ `missing`（原始檔已消失：附最後已知路徑 slot，前進動作為重新整理）/ `compact`（浮層內，僅動作無訊息）；`section` / `missing` / `compact` 為提案（3.3 第 3 項） |
| `BlockedState`（阻擋狀態） | 元件 | L3 | 「這個專案不適用本 App」+ 版本值 + 說明 + 切換專案出口（恆可用，FR-07）；0.1 不渲染「以純檔案模式檢視」（SPEC-003 §3.1） | §1（不是框架專案、無可消費的型別表、schema 不相容） | `plain` / `withDetail`（附「檢視詳情」展開 `panel-domain-schema-detail`，內容為兩個版本值的 `Section`） |
| `LoadingState`（載入態） | 元件 | L3 | 骨架或進度 + 計數文字 + 取消；取消契約 11 條（SPEC-003 §2.5）由本元件單一承擔 | §1（載入中）、§4（載入中）、§5（掃描中） | `skeleton`（indeterminate + 計數文字；骨架版位 slot：`matrix` / `sections`）/ `progressBar`（determinate + 已解析筆數／總數 N） |
| `LoadPrompt`（待載入提示） | 元件 | L3 | 「載入 N 張 ticket」+ 開始載入 + 返回（`returnTo` 為 null 時不渲染）；不顯示預估耗時（SPEC-003 §3.4） | §4（未載入） | `default`；獨立元件為提案（3.3 第 4 項） |
| `AppSnackBar`（即時訊息） | 元件 | L2 | 「已在外部開啟」「找不到檔案」類的暫時訊息，Material 預設動畫不覆寫 | §1、§2、§5、§6 | `plain`（停留 `Motion.snackBar`）/ `withAction`（帶一個動作，停留 `Motion.snackBarWithAction`）；是否進元件庫或列第 7 章豁免**待核定**（3.3 第 16 項） |

#### 容器

| 元件 | 種類 | 層級 | 用途 | 出現畫面 | 變體（variant） |
|------|------|------|------|---------|----------------|
| `AppShell`（根框架） | 容器 | L3 | 根：無父容器。標題列（`AppText.title` 應用名）/ 側欄（`ProjectSwitcherEntry` + `NavItem` × 6，垂直）/ 主區（`PageColumn`）三格；側欄固定寬、主區填滿 | 殼 | `default`；既有 `lib/app/shell.dart` 為其實作雛形（見 3.5 漂移） |
| `PageColumn`（頁面區塊堆疊） | 容器 | L3 | 每頁根堆疊：`SplitRow.header` + 內容（`Panel` 或 `TwoColumnLayout` 或狀態元件）垂直；內容區內距 `Space.xl` | §1–§6 | `default` |
| `SplitRow`（左右分列） | 容器 | L2 | 左右兩端對齊的水平列：頁首（`PageTitle` + `SegmentedControl`）、Ticket 清單摘要底列（`AppText` + `AppText`） | §1–§6（頁首）、§4（底列） | `header`（固定高、底邊框 `AppColors.border`、底 `AppColors.surfaceBase`）/ `footer`（頂邊框）；合併為提案（3.3 第 13 項） |
| `Panel`（面板） | 容器 | L2 | 白底（`AppColors.surfaceBase`）、邊框 `AppColors.border`、圓角 `Radius.lg`、內距 `Space.md` 的垂直堆疊；子件為具名清單（`Toolbar` / `TableRow.header` / `DataTable` / `MatrixGrid` / `SwimlaneGrid` / `Tree` / `Section` / `BadgeRow` / `Divider` / `AppText` / `DocumentBody` / `ListRow`） | §1–§6 | `default` / `scrollable`（主體可垂直捲動，承載 `scroll-traceability-tree`、`scroll-gaps-sections`、`scroll-nodeDetail-*`） |
| `TwoColumnLayout`（主副雙欄） | 容器 | L3 | 主欄 `Panel`（填滿）+ 右欄 `Panel`（固定寬）水平並排，間距 `Space.md`；兩欄各自獨立捲動（SPEC-003 FR-10） | §6（正常、部分損壞）、§1（矩陣格詳情卡，待核定） | `default`；右欄寬度 token 缺（見 NeedsContext） |
| `Toolbar`（工具列） | 容器 | L2 | `SearchField`（填滿）+ `FilterDropdown` × N 水平，底邊框 | §4 | `default` |
| `BadgeRow`（徽章列） | 容器 | L2 | `Badge` × N 水平、間距 `Space.xs`，空間不足換行；承載節點詳情標籤列、矩陣與泳道圖例列、事件標籤 | §1、§2、§6 | `default` / `legend`（頂邊框，面板底部） |
| `ButtonRow`（按鈕列） | 容器 | L2 | `AppButton` × N 水平；承載狀態元件的動作區（開始載入 + 返回；重新整理 + 返回；開啟原始檔 + 檢視關聯 + 返回 Domain） | §1、§2、§4、§6 | `default`；子件上限 3（0.1 最多三動作） |
| `TableRow`（表格列） | 容器 | L2 | 欄寬對齊表頭的水平格線列；子件 ∈ {`TableColumnHeader`, `AppText`, `Badge`, `StepNumber`, `BadgeRow`, `IssueMarker`, `ExpanderIcon`} | §2、§4 | `header`（`TableColumnHeader` × N）/ `ticket`（ID mono、標題、狀態徽章、優先、損壞標記）/ `step`（序號、步驟名、domain 標籤、事件徽章列）/ `ticketNested`（主題模式下的票列，欄序不同，**待核定**） |
| `DataTable`（資料表） | 容器 | L2（資料視圖） | `TableRow.header` + `TableRow` × N 垂直；Ticket 清單為虛擬捲動（`scroll-tickets-list`），UC Flow 為一般捲動（`scroll-ucFlow-steps`） | §2、§4 | `virtual` / `plain` |
| `MatrixGrid`（矩陣） | 容器 | L3（資料視圖） | domain × UC 二維格線：欄首 `TableColumnHeader.twoLine`、列首 `AppText`、格 `MatrixCell`、小計 `AppText.caption`；欄首與列首釘選、二維捲動（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`） | §1 | `default` |
| `SwimlaneGrid`（泳道） | 容器 | L3（資料視圖） | 泳道列（`AppText` 泳道名 + `SwimlaneNode` 置於步驟欄）× N 垂直、列間虛線；底部步驟箭頭列；0.1 以寫死座標的假資料靜態排版（SPEC-001 設計約束），二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`） | §1 | `default` |
| `Tree`（樹） | 容器 | L3（資料視圖） | `ListRow.tree` × N 垂直，依深度縮排；展開收合改變列集合（`scroll-traceability-tree`） | §3 | `default` |
| `ListRow`（通用列） | 容器 | L2 | leading（`ExpanderIcon` / `AppIcon` / `Badge` / `StepNumber`，可選）+ 主文字 `AppText`（填滿）+ 次文字 `AppText.secondary`（可選，堆疊於主文字下）+ trailing（`Badge` / `AppIcon` / `AppText.caption`，可選）水平 | §1（詳情卡步驟）、§3（樹節點）、§4（主題節首）、§5（分節首、破洞項）、§6（節點 meta 列） | `tree`（展開 + 標題 + 狀態徽章）/ `sectionHeader`（展開或類別徽章 + 名稱 + 計數）/ `item`（標題 + 說明 + 外開箭頭）/ `meta`（型別徽章 + 路徑 mono）/ `numbered`（序號 + 文字）；合併為提案（3.3 第 12 項） |
| `Section`（分節） | 容器 | L2 | 節首 + 項目垂直堆疊：主題節（`ListRow.sectionHeader` + `TableRow.ticketNested` × N）、破洞類別節（`ListRow.sectionHeader` + `ListRow.item` × N）、關聯群（`AppText.caption` + `RelationItem` × N）、schema 詳情面板（`AppText.caption` + `AppText` × 2） | §1（詳情面板）、§4、§5、§6 | `collapsible`（節首含 `ExpanderIcon`，`expander-*`）/ `static`；「未歸屬」節以頂部虛線分隔為修飾參數；合併為提案（3.3 第 14 項） |
| `SwitcherOverlay`（專案切換浮層） | 容器 | L3 | 覆蓋層：`AppText.caption` 標題 + `RecentProjectItem` × N（垂直捲動 `scroll-switcher-recent`）+ `Divider` + `AppButton.text`（選擇其他資料夾）；自入口向下展開，Esc／點外部收合，焦點限制於浮層內 | §7（展開、無最近專案） | `default`；`RecentProjectItem` 數量無上限 → 空間不足策略為捲動 |

**候選數**：元件 25、容器 17（其中資料視圖 4：`DataTable`、`MatrixGrid`、`SwimlaneGrid`、`Tree`）。
非資料視圖的容器 13 個，超過 skill〈Troubleshooting〉的十個門檻；3.5 記錄已做的歸併與未再歸併的理由，
再往下歸併須把 slot 子件清單寫成「任意元件」，skill 明文視同原生佈局，故停在此數送核定。

### 3.2 模式 B 步驟 1-2：視覺單元盤點與語意問句

逐 artboard（`design/` 九份，`canvas.json` 所列）框出可獨立辨識的區塊；相同外觀先各自列，語意問句
（使用者看到它預期能做什麼？承載標題／內文／標籤／數值／動作哪一種？）的答案為歸併依據。
框架層（標題列、側欄、頁首）九份皆同，只列一次。

| 畫面（artboard） | 視覺單元 | 語意問句答案 | 歸屬（3.1） |
|------|------|------|------|
| 全部（框架層） | 頂端標題列「專案文件流」 | 標題；無動作 | `AppShell` 標題列 slot（`AppText.title`） |
| 全部 | 側欄頂端：資料夾圖示 + 專案名 + 展開箭頭 | 動作（開啟切換）+ 標籤（目前專案） | `ProjectSwitcherEntry` |
| 全部 | 側欄六項：圖示 + 名稱，一項高亮底 | 動作（換頁）；selected 態 | `NavItem` × 6 |
| 全部 | 頁首：畫面名 + 灰色副標；右側（§1、§4）雙段切換 | 標題 + 內文；動作（切模式） | `SplitRow.header`[`PageTitle`, `SegmentedControl`] |
| 全部 | 白底圓角邊框面板 | 容器（無自身語意） | `Panel` |
| Main（§1 矩陣） | 欄首列：空格 + UC ID 與名稱兩行 × 5 + 小計 | 標籤 | `TableColumnHeader.twoLine` |
| Main | 資料列：domain 名 + 五個符號格 + 小計數字；一列高亮 | 標籤 + 數值（關係強度）+ 動作（點格）；selected 態 | `MatrixGrid` 內的 `AppText` + `MatrixCell` + `AppText.caption` |
| Main | 底部圖例：● 直接貫穿 ○ 間接依賴 · 無關 | 標籤（說明符號） | `BadgeRow.legend`[`Badge.legend` × 3] |
| Main | 右側詳情卡：標題「Corpus × UC-02」、說明、編號步驟 × 4、底部事件標籤 × 2 | 標題 + 內文 + 數值/內文 + 標籤 | `TwoColumnLayout` 右欄 `Panel`[`AppText.subtitle`, `AppText.body`, `ListRow.numbered` × 4, `BadgeRow`]；**SPEC-001 §1 正常·矩陣顯示欄無此單元，待核定**（3.5） |
| DomainSwimlane（§1 泳道） | 面板標題「UC-02 檢視穿透」 | 標題 | `AppText.subtitle` |
| DomainSwimlane | 泳道列 × 6：泳道名 + 動作標籤置於步驟欄；兩種底色；列間虛線 | 標籤（泳道）+ 標籤（動作名）；active / inactive | `SwimlaneGrid`[`AppText`, `SwimlaneNode`] |
| DomainSwimlane | 底部箭頭列 | 裝飾（步驟方向） | `SwimlaneGrid` 內部 |
| DomainSwimlane | 圖例 chip × 2 | 標籤 | `BadgeRow.legend`[`Badge.legend`] |
| ProjectPickerD（§7） | 浮層：標題「切換專案」、專案項 × 5（圖示 + 名稱 + 摘要 + 紅色計數）、分隔線、「選擇其他資料夾…」 | 標籤；動作（選專案）+ 標籤 + 數值 + 標籤（健康）；動作 | `SwitcherOverlay`[`AppText.caption`, `RecentProjectItem`（含 `Badge.health`）× N, `Divider`, `AppButton.text`] |
| TicketListA（§4 列表） | 工具列：搜尋框 + 兩個下拉 | 輸入；動作（篩選） | `Toolbar`[`SearchField`, `FilterDropdown` × 2] |
| TicketListA | 欄首列 ID／標題／狀態／優先／空 | 標籤（可排序） | `TableRow.header`[`TableColumnHeader.sortable`] |
| TicketListA | 票列 × 7：等寬 ID、標題（截斷）、彩色狀態文字、優先、末欄損壞圖示 | 數值 + 標題 + 標籤 + 標籤 + 標記；動作（開票） | `TableRow.ticket`[`AppText.mono`, `AppText`, `Badge.status`, `AppText.caption`, `IssueMarker.damagedDetail`] |
| TicketListA | 底列：顯示範圍／總數／損壞數 + 「虛擬捲動，不分頁」 | 內文 + 數值 | `SplitRow.footer`[`AppText`, `AppText`]；損壞計數的可點錨點 `badge-tickets-corrupted` 位置**待核定**（3.5） |
| TicketListB（§4 主題） | 主題節 × 3 + 未歸屬節（虛線頂邊）：節首（箭頭 + 主題名 + 「(3 tasks, 最高優先級=P1)」）+ 票行（圖示 + ID + [P1] + 標題 + 狀態） | 動作（展開）+ 標題 + 內文；票行同列表但欄序不同 | `Section.collapsible`[`ListRow.sectionHeader`, `TableRow.ticketNested` × N] |
| TicketListB | 底部說明文字（排序規則） | 內文 | `AppText.caption` |
| UCFlowB（§2） | 欄首：空／步驟／Domain／發送事件 | 標籤 | `TableRow.header` |
| UCFlowB | 步驟列 × 6：圓形序號 + 步驟名 + domain chip + 事件 chip 列 | 數值 + 標題 + 標籤 + 標籤；動作（開節點） | `TableRow.step`[`StepNumber`, `AppText`, `Badge.tag`, `BadgeRow`] |
| TraceA（§3） | 樹列 × 9：箭頭 + 節點名（PROP 粗體）+ 狀態文字；末列「（尚無 ticket）」+ 紅色「缺口」 | 動作（展開）+ 標題 + 標籤；缺口列為問題標記 | `Tree`[`ListRow.tree`[`ExpanderIcon`, `AppText`, `Badge.status`]]；缺口列 trailing 為 `IssueMarker.gap` |
| GapReportA（§5） | 類別節 × 3：節首（類別 chip + 「2 類」）+ 破洞項（標題 + 說明 + 外開箭頭，頂邊框） | 標籤 + 數值；標題 + 內文 + 動作（外開） | `Section.collapsible`[`ListRow.sectionHeader`[`Badge.category`, `AppText.caption`], `ListRow.item` × N] |
| NodeDetailB（§6） | 主欄：型別 chip + 路徑；大標題；標籤列（draft／domain: schema／2 個 FR）；分隔線；內文段（含行內 code）；FR 引用區塊 | 標籤 + 數值；標題；標籤；內文 | `Panel`[`ListRow.meta`, `AppText.title`, `BadgeRow`, `Divider`, `DocumentBody`] |
| NodeDetailB | 右欄：四個群（灰色小標 + 等寬 chip × N） | 標籤 + 動作（點關聯替換主欄） | `Panel.scrollable`[`Section.static`[`AppText.caption`, `RelationItem` × N] × 4] |

畫布未畫、只在 SPEC-001 顯示欄與 SPEC-003 出現的單元（規格為準，不視為缺件）：空狀態（六處 + 未選專案 + 未選節點）、
阻擋狀態（三處）、載入態（三處）、待載入提示、原始檔已消失、schema 詳情面板、SnackBar、返回鍵。歸屬見 3.6 對照表。

### 3.3 模式 A 步驟 3：存在必要性檢視（核定結果見 §3.7，本節保留提案原文與理由）

方向依 skill：先假設能併，找不到併不進去的理由才立特化元件；理由只認語意或行為差異，外觀差異不構成理由。

| # | 候選 | 結論（提案） | 理由 |
|---|------|------|------|
| 1 | 空狀態 vs 阻擋狀態 | **不合併**（維持 SPEC-002 決定） | 語氣不同（「這裡目前沒有東西」vs「這個專案不適用」）、退出層級不同（跳轉至其他畫面 vs 離開專案）、FR-03 與 FR-07 的驗收會互相污染；SPEC-003 §2.7 已依此定行為差異 |
| 2 | 未選專案（§1）併入空狀態 | **合併**為 `EmptyState.page` | SPEC-002 空狀態清單未列此狀態，但語意同為「沒有內容」，前進動作（選擇資料夾）非返回、觸發後進入載入中；與其他空狀態的差異只在動作目的地，依 skill 步驟 3「只是目的地不同者為 slot」 |
| 3 | flow 未結構化、原始檔已消失、無最近專案 併入空狀態 | **合併**為 `EmptyState` 變體 `section` / `missing` / `compact` | 三者語意皆為「此處目前沒有內容」：flow 區塊無內容（與 UC 基本資訊並列，故為區塊級）、原始檔不在了（附最後已知路徑，前進動作重新整理）、最近清單為空（僅剩選擇資料夾動作）。反面理由：`missing` 的重新整理留在畫面內，與 `page` 的跳轉層級不同——若 PM 認定退出層級差異足以拆件，`missing` 改為獨立元件，其餘結論不變 |
| 4 | 未載入（§4）併入空狀態 | **不合併**，立 `LoadPrompt` | 語意相反：空狀態說「沒有內容」，未載入說「有 N 筆內容尚未載入」；含數值角色（N）；前進動作進入載入態並由 FR-02 取消契約承接；FR-03 對它不適用。合併會讓「空狀態必有前進動作」與「未載入必顯示票數」兩條驗收互相污染 |
| 5 | 三處載入態合為一個元件 | **合併**為 `LoadingState`，變體依進度型別 | SPEC-003 §2.11「取消契約由載入態元件單一承擔」，三處差異只有目標態與進度型別（骨架 indeterminate ×2、進度條 determinate ×1）；骨架版位（矩陣／分節）為 slot 不是變體 |
| 6 | 損壞標記（兩級）+ 追溯缺口 合為一族 | **合併**為 `IssueMarker`（SPEC-002 的「損壞標記」更名） | 三者皆為修飾既有節點或欄位的問題標記、皆可點擊跳轉破洞報告（`badge-tickets-corrupted`、`badge-traceability-broken-*`）；差異在觸發原因（損壞 vs 缺口）與外觀（虛線框 vs 圖示計數），為變體 |
| 7 | 損壞計數徽章併入 `Badge` | **不合併** | `Badge` 為非互動元素（SPEC-003 §3.7 健康徽章「點擊不產生任何反應且不呈現按鈕形態」），損壞計數可點擊跳轉；行為差異足以拆件 |
| 8 | 狀態文字（票列的彩色 completed／pending）與狀態 chip（節點詳情的 draft chip）| **合併**為 `Badge.status` | 語意同為狀態標籤、非互動；chip 底與純文字為外觀差異。是否以第二軸（`chip` / `inline`）表達**待核定**：若 L2 認為外觀差異不得為變體，則以容器格位決定外觀（表格列內為 inline） |
| 9 | 圖例、事件標籤、domain 標籤、型別標籤、類別標籤 併入 `Badge` | **合併**為變體 | 皆為非互動標籤，內容角色相同；顏色依變體取 token |
| 10 | 矩陣欄首（UC ID + 名稱兩行）併入 `TableColumnHeader` | **合併**為 `twoLine` 變體 | 內容角色同為欄首標籤、皆非資料格；差異為第二行 slot 有無 |
| 11 | SPEC-002「節點卡」（矩陣格、泳道步驟、追溯樹節點、破洞項） | **拆分**為 `MatrixCell`、`SwimlaneNode`、`ListRow.tree`、`ListRow.item` | 四者內容角色不同（關係符號／動作標籤／標題 + 狀態／標題 + 說明）、行為不同（點格切泳道／不可點／開節點詳情／外開檔案）；「節點卡」一名命不出共同目的，依方法論〈命名與通用元件判準〉不應獨立存在 |
| 12 | 樹列、主題節首、破洞分節首、破洞項、節點 meta 列、詳情卡步驟 合為 `ListRow` | **合併** | 六者皆為「leading（可選）+ 主文字 + 次文字（可選）+ trailing（可選）」水平列，方向同、空間不足策略同（主文字截斷、兩端固定）；slot 子件清單仍可具名列舉（leading 四型、trailing 三型），未到「任意元件」 |
| 13 | 頁首列與 Ticket 清單摘要底列 合為 `SplitRow` | **合併** | 皆為左右兩端對齊的水平列、子件各一；差異為邊框位置與固定高，為變體 |
| 14 | 主題節、破洞類別節、關聯群、schema 詳情面板 合為 `Section` | **合併** | 皆為「節首 + 項目垂直堆疊」；可否收合為行為差異，以 `collapsible` / `static` 變體表達；項目子件型別可具名列舉 |
| 15 | `DocumentBody` 是否屬元件庫 | **待核定** | 節點詳情主欄的內文由 0.0.3 選定的 markdown 渲染器產出（含行內 code、FR 引用區塊）；若渲染器輸出直接使用原生 widget，需列第 6 章禁用對照或第 7 章豁免；本檔先列為元件占位，契約由第 4 章填 |
| 16 | `AppSnackBar` 是否屬元件庫 | **待核定** | SPEC-003 多處以 SnackBar 為反應載體且明訂「由 Material 預設，不覆寫」；封裝為元件可統一停留時間 token 與動作 slot，但也可列第 7 章豁免直用。提案：封裝（兩個變體），理由是停留時間須引用 `Motion` token，直用會散在四個畫面 |
| 17 | `AppText` 是否為元件 | **提案：是** | 容器的 slot 子件清單依 skill 須為具名元件；文字若不是元件，所有含文字的容器只能寫「Text」，等於原生 widget。`AppText` 的變體即字級 token 階，是 SPEC-002「畫面只引用語意層與元件層」的元件層落點 |
| 18 | 通用按鈕 `AppButton` | **新增**（畫布未畫） | SPEC-001「可用操作」欄有 14 種動作有視覺承載，畫布只畫了一顆（浮層底部）；依 skill 步驟 2 來源二補入 |
| 19 | `TableRow` 的票列與步驟列 | **合併**為變體 | 皆為欄寬對齊表頭的格線列；子件型別可具名列舉；主題模式票列欄序不同，是否為第三變體或屬漂移**待核定** |
| 20 | 資料視圖容器（矩陣、泳道、表格、樹） | **不合併** | 二維格線、靜態座標泳道、表頭對齊表格、深度縮排樹的排列規則各異；skill 明文各算一個 |

### 3.4 模式 B 步驟 4：排列關係盤點 → 容器候選

逐畫面記錄「哪些區塊之間有排列關係」（方向、子件）；間距值引用 `lib/tokens/spacing.dart` 的階
（依該檔 dartdoc 的吸收表對映，畫布原始值不入本檔）。「一組」指同一佈局結構下的全部子件。

| 畫面 | 排列關係（方向：子件） | 間距 token | 容器候選 |
|------|------|------|------|
| 殼 | 垂直：標題列 / 主體；主體水平：側欄 / 主區 | 側欄與主區以 `AppColors.border` 分隔線相接 | `AppShell` |
| 殼 | 側欄垂直：`ProjectSwitcherEntry` / `NavItem` × 6 | `Space.xxs`（項間）、`Space.sm`（入口下方）、側欄內距 `Space.md` × `Space.sm` | `AppShell` 側欄 slot（殼層以框架容器承載，不另立） |
| §1–§6 | 主區垂直：頁首 / 內容區 | 內容區內距 `Space.xl` | `PageColumn` |
| §1–§6 | 頁首水平：`PageTitle` / 右側控制 | 兩端對齊 | `SplitRow.header` |
| §1、§6 | 內容區水平：主 `Panel` / 右 `Panel`（固定寬） | `Space.md` | `TwoColumnLayout` |
| §1–§6 | 面板垂直：頂列 / 主體 / 底列 | `Space.sm`（子件間）、`Space.md`（內距） | `Panel` |
| §1 矩陣 | 二維格線：欄首列 / 資料列 × N；列內：列首 / 格 × N / 小計 | 列間 `Space.xxs`；格內距 `Space.xs` | `MatrixGrid` |
| §1 矩陣、§1 泳道 | 圖例水平：`Badge.legend` × N | `Space.lg`（矩陣）/ `Space.xs`（泳道）→ **同一容器兩種間距，待核定取一** | `BadgeRow.legend` |
| §1 詳情卡 | 垂直：標題 / 說明 / 步驟 × 4 / 底部標籤列；步驟水平：序號 / 文字 | `Space.sm`；步驟間 `Space.xs`；序號與文字 `Space.sm` | `Panel` + `ListRow.numbered` + `BadgeRow` |
| §1 泳道 | 二維：泳道列 × 6 垂直（虛線分隔）；列內水平：泳道名 / 步驟欄 × 6，節點置中於欄 | 列高固定（token 缺，見 NeedsContext） | `SwimlaneGrid` |
| §4 列表 | 工具列水平：搜尋（填滿）/ 下拉 × 2 | `Space.sm` | `Toolbar` |
| §2、§4 | 表頭水平格線：欄首 × N | 欄間 `Space.md` | `TableRow.header` |
| §2、§4 | 資料列水平格線：格 × N，欄寬對齊表頭 | 欄間 `Space.md`；列高固定（token 缺） | `TableRow.ticket` / `TableRow.step` |
| §2、§4 | 表格垂直：表頭 / 列 × N | 列間以 `AppColors.border` 底邊分隔 | `DataTable` |
| §4 列表 | 底列水平：摘要 / 說明 | 兩端對齊 | `SplitRow.footer` |
| §4 主題 | 節垂直：節首 / 票列 × N；節之間垂直 | 節內 `Space.xxs`、節間 `Space.sm`；未歸屬節頂部虛線 | `Section.collapsible` |
| §4 主題、§5 | 節首水平：展開或類別徽章 / 名稱 / 計數 | `Space.sm` | `ListRow.sectionHeader` |
| §5 | 節垂直：節首 / 破洞項 × N；節間垂直 | 節間 `Space.lg`；項以頂邊框分隔 | `Section.collapsible` |
| §5 | 破洞項水平：標題與說明堆疊 / 外開箭頭 | `Space.sm`；標題與說明 `Space.xxs` | `ListRow.item` |
| §3 | 樹垂直：列 × N，依深度縮排；列水平：展開 / 名稱 / 狀態 | 列高固定；列內 `Space.sm` | `Tree` + `ListRow.tree` |
| §6 主欄 | 垂直：meta 列 / 標題 / 標籤列 / 分隔線 / 內文 / 引用區塊 | `Space.sm`；面板內距 `Space.lg`（畫布主欄內距大於其他面板，是否為 `Panel` 變體**待核定**） | `Panel` + `ListRow.meta` + `BadgeRow` |
| §6 右欄 | 垂直：關聯群 × 4；群內垂直：小標 / 關聯項 × N | 群間 `Space.sm`；群內 `Space.xs` | `Panel.scrollable` + `Section.static` |
| §7 | 浮層垂直：標題 / 專案項 × N / 分隔線 / 選擇其他 | `Space.xxs`；浮層內距 `Space.sm` | `SwitcherOverlay` |
| §1、§2、§4、§6 | 狀態元件動作區水平：按鈕 × 2–3（畫布未畫，依 SPEC-001 可用操作欄） | `Space.sm`（提案） | `ButtonRow` |
| §1 schema 不相容 | 詳情面板垂直：小標 / 版本值 × 2（畫布未畫） | `Space.xs`（提案） | `Section.static` |

### 3.5 模式 A 步驟 5：同型歸併記錄與畫布漂移

**歸併鍵**：子件類型 + 排列方向，暫記空間不足策略假設；策略於第 5 章填定後二次歸併。不依畫面歸併。

| 歸併前 | 歸併後 | 依據 |
|------|------|------|
| 樹列、主題節首、破洞分節首、破洞項、節點 meta 列、詳情卡步驟（六種水平列） | `ListRow`（五變體） | 同方向、同「兩端固定 + 主文字填滿並截斷」策略 |
| 票列（列表）、步驟列、票列（主題）、表頭列 | `TableRow`（四變體） | 同為欄寬對齊表頭的格線列 |
| 主題節、破洞類別節、關聯群、schema 詳情面板 | `Section`（兩變體） | 同「節首 + 垂直項目」 |
| 頁首列、摘要底列 | `SplitRow`（兩變體） | 同「左右兩端對齊」 |
| 主題節清單、破洞分節清單、右欄關聯群堆疊 | 併入 `Panel`（`scrollable` 變體）主體 | `Panel` 本身即垂直堆疊 + 表面，分節清單無額外排列規則 |
| 側欄堆疊 | 併入 `AppShell` | skill 步驟 4「殼層以一個框架容器承載，不再往上遞迴」 |
| 矩陣列 | 併入 `MatrixGrid` | 二維格線的列不是獨立排列關係，行列皆由格線決定 |
| 表頭列、徽章列、按鈕列、工具列 | **不歸併** | 子件類型互異且空間不足策略不同：表頭對齊格線、徽章列換行、按鈕列上限 3 不換行、工具列搜尋框吸收剩餘寬度 |
| `ListRow` 與 `TableRow` | **不歸併** | 前者主文字填滿，後者欄寬由表頭決定；策略不同 |

**畫布漂移（視覺值以畫布為準；行為與狀態以規格為準，標待決送 PM）**：

| 漂移 | 類別 | 處置 |
|------|------|------|
| 矩陣模式右側有「格詳情卡」（Corpus × UC-02），SPEC-001 §1 正常·矩陣顯示欄只寫「domain × UC 交叉表」 | 畫布有、規格無（行為類） | **待核定**：納入 0.1 則 SPEC-001 §1 顯示欄與 SPEC-003 §3.1 須補「選格後右欄顯示詳情」；不納入則 `TwoColumnLayout` 只出現於 §6 |
| 導覽項在畫布有 leading 圖示，`lib/app/shell.dart` 的 `_NavItem` 無圖示 | 視覺值 | 畫布為準：`NavItem` 契約含 icon slot；shell 對齊屬元件庫實作票（W1-005）範圍，於本票 NeedsContext 記錄 |
| 側欄寬度：畫布與 `shell.dart` 的 `_kSidebarWidth` 不一致 | 視覺值 | 畫布為準；該值無 token，屬佈局尺寸 token 缺料（NeedsContext），第 4 章尺寸契約標待決 |
| 矩陣格詳情卡右欄寬與節點詳情右欄寬不同 | 視覺值 | 兩個值皆無 token；`TwoColumnLayout` 右欄寬待 token 前置票，或於核定時收斂為一個 |
| 步驟序號圓形（§2）vs 方形（§1 詳情卡） | 視覺值 | `Radius` token 兩階皆可表達；是否統一**待核定** |
| 圖例列間距矩陣 `Space.lg` vs 泳道 `Space.xs` | 視覺值 | `BadgeRow.legend` 取單一值，**待核定** |
| Ticket 清單損壞計數畫布放在摘要底列文字內，SPEC-003 要求 `badge-tickets-corrupted` 為可點錨點 | 行為類 | 規格為準：`IssueMarker.damagedDetail` 須為獨立可點元素；放於 `SplitRow.footer` 或 `Toolbar` **待核定** |
| Ticket 主題模式票列欄序（ID / 優先 / 標題 / 狀態）與列表模式（ID / 標題 / 狀態 / 優先）不同 | 視覺值 | 是否為 `TableRow` 第三變體或統一欄序**待核定** |
| 節點詳情主欄面板內距大於其他面板 | 視覺值 | `Panel` 內距是否分兩階**待核定** |
| 畫布所有面板皆無捲軸、無溢位表現 | 畫布不可得 | 空間不足策略以 SPEC-003 §1.1 十個捲動處為準（第 5 章填） |
| 畫布未畫：空狀態、阻擋狀態、載入態、待載入提示、返回鍵、SnackBar、schema 詳情面板 | 規格有、畫布無 | 規格為準，不視為缺件；其排列（icon / 訊息 / 說明 / 動作列的堆疊）於第 4 章依 SPEC-003 §2.6–§2.7 填 |

### 3.6 SPEC-001 30 列與 SPEC-002 八類的歸屬對照

**SPEC-002〈元件庫的範圍〉八類 → 本檔**：

| SPEC-002 元件 | 本檔歸屬 | 變動 |
|------|------|------|
| 空狀態（訊息 + 前進動作） | `EmptyState` | 變體擴為四個（提案） |
| 阻擋狀態（訊息 + 版本值 + 出口） | `BlockedState` | 增 `withDetail` 變體 |
| 載入態（骨架 + 進度 + 取消） | `LoadingState` | 變體依進度型別 |
| 損壞標記（兩級） | `IssueMarker` | 更名，增 `gap` 變體（提案） |
| 導覽項 | `NavItem` | 無 |
| 專案切換浮層 | `ProjectSwitcherEntry` + `SwitcherOverlay` + `RecentProjectItem` | 拆為入口、浮層容器、項（提案） |
| 節點卡 | `MatrixCell` / `SwimlaneNode` / `ListRow.tree` / `ListRow.item` | 拆分（提案，3.3 第 11 項） |
| 徽章（計數／狀態／健康） | `Badge` | 變體擴為八個 |

**SPEC-001 30 列顯示欄 → 本檔**（狀態元件內部的訊息／說明／動作皆為該元件的 slot，不另列）：

| § | 狀態 | 顯示欄單元 | 歸屬 |
|---|------|------|------|
| §1 | 未選專案 | 空畫面 + 選擇資料夾引導 | `EmptyState.page`（動作 `AppButton.primary` 選擇資料夾） |
| §1 | 載入中 | 骨架版面 + 進度 + 取消 | `LoadingState.skeleton`（版位 `matrix`） |
| §1 | 正常 · 矩陣 | domain × UC 交叉表 | `PageColumn`[`SplitRow.header`[`PageTitle`, `SegmentedControl`], `Panel`[`MatrixGrid`, `BadgeRow.legend`]]；右欄詳情卡待核定 |
| §1 | 正常 · 泳道 | flow 橫向穿過 domain 泳道 | `Panel`[`AppText.subtitle`, `SwimlaneGrid`, `BadgeRow.legend`] |
| §1 | 空圖 | 訊息 + 說明 + 開啟 docs（條件）+ 切換專案 | `EmptyState.page`（`ButtonRow`[`AppButton` 開啟 docs（目錄存在時）, `AppButton` 前往破洞報告]） |
| §1 | 不是框架專案 | 訊息 + 說明本 App 需要什麼 + 出口 | `BlockedState.plain` |
| §1 | 無可消費的型別表 | 版本值 + 訊息 + 出口 | `BlockedState.plain`（版本值 slot） |
| §1 | schema 不相容 | 版本不符說明 + 兩個版本值 + 檢視詳情 | `BlockedState.withDetail`（面板 `Section.static`[`AppText.caption`, `AppText.mono` × 2]） |
| §2 | 無 UC | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §2 | flow 未結構化 | UC 基本資訊 + 訊息 + 開啟原始檔／檢視關聯 | `Panel`[`ListRow.meta`, `AppText.title`, `EmptyState.section`（`ButtonRow` × 3 動作）] |
| §2 | 正常 | 垂直步驟表，domain 與事件成欄 | `Panel`[`DataTable.plain`[`TableRow.header`, `TableRow.step` × N]] |
| §3 | 正常 | PROP→SPEC→UC→Ticket 樹狀 | `Panel.scrollable`[`Tree`[`ListRow.tree` × N]] |
| §3 | 鏈路斷裂 | 缺口層以虛線框標示 | 同上 + 缺口列 trailing `IssueMarker.gap` |
| §3 | 無提案 | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §4 | 未載入 | 「載入 N 張 ticket」+ 開始載入 + 返回 | `LoadPrompt`（`ButtonRow`[`AppButton.primary`, `AppButton.secondary`]） |
| §4 | 載入中 | 進度條 + 已解析筆數 + 取消 | `LoadingState.progressBar` |
| §4 | 正常 · 列表 | 密集表格 + 虛擬捲動 + 搜尋／篩選／排序 | `Panel`[`Toolbar`, `DataTable.virtual`[`TableRow.header`（`sortable`）, `TableRow.ticket` × N], `SplitRow.footer`] |
| §4 | 正常 · 主題 | 主題節 + 未歸屬節 | `Panel.scrollable`[`Section.collapsible` × N（含未歸屬）, `AppText.caption`] |
| §4 | 無 ticket | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §4 | 含損壞（疊加態） | 正常視圖 + 損壞徽章與計數 | 底層正常態 + `IssueMarker.damagedDetail`（可點，位置待核定）+ 各列 `IssueMarker.damagedDetail`（圖示） |
| §5 | 掃描中 | 骨架 + 進度 + 取消 | `LoadingState.skeleton`（版位 `sections`） |
| §5 | 無破洞 | 訊息 + 掃描範圍說明 + 重新掃描 | `EmptyState.page`（說明 slot；動作 `AppButton` 重新掃描） |
| §5 | 有破洞 | 依類別分節，各項帶檔案與行號 + 重新掃描 | `Panel.scrollable`[`Section.collapsible`[`ListRow.sectionHeader`, `ListRow.item` × N] × N]；重新掃描 `AppButton` 於 `SplitRow.header` 右側（提案，畫布未畫） |
| §6 | 未選節點 | 空狀態元件 + 「尚未選取節點」 | `EmptyState.page`（動作前往追溯視圖） |
| §6 | 正常 | 全頁內容 + 關聯右欄 + 開啟原始檔／返回 | `TwoColumnLayout`[`Panel`[`ListRow.meta`, `AppText.title`, `BadgeRow`, `Divider`, `DocumentBody`], `Panel.scrollable`[`Section.static` × N]]；返回與開啟原始檔的 `AppButton` 位置**待核定**（畫布未畫） |
| §6 | 部分損壞 | 可讀欄位 + 損失欄位標示 + 跳轉破洞報告 | 同上 + 欄位級 `IssueMarker.damagedDetail`（說明文字 slot） |
| §6 | 原始檔已消失 | 訊息 + 最後已知路徑 + 重新整理／返回 | `EmptyState.missing`（`ButtonRow`[`AppButton` 重新整理, `AppButton` 返回]） |
| §7 | 收合 | 側欄頂端顯示目前專案名 | `ProjectSwitcherEntry` |
| §7 | 展開 | 最近專案清單 + 健康徽章 + 選擇其他 | `SwitcherOverlay`[`AppText.caption`, `RecentProjectItem`（`Badge.health`）× N, `Divider`, `AppButton.text`] |
| §7 | 無最近專案 | 僅「選擇資料夾…」 | `SwitcherOverlay` 零項 + `AppButton.text`（`EmptyState.compact` 不成立，見 §3.7 第 3 項） |

### 3.7 核定記錄（2026-09-02）

PM 核定 §3.3 二十項與 §1、§3.5、§3.6 的待核定項；標「用戶簽核」者由專案擁有者裁示。第 4-5 章依本表填寫；§3.1 總表中與本表不一致處以本表為準，由 044.2 回填總表。第 4 章契約欄位依方法論 1.11.0 為十一欄：用戶補充「操作機制」（每形態的操作動作與精度，本專案單一形態為指標 + 鍵盤，仍須逐元件填一列）與「無障礙」（朗讀標籤、狀態播報、非視覺替代、焦點與鍵盤操作路徑；不得填不適用）為必填。

| # | 項目 | 核定 | 理由 |
|---|------|------|------|
| 1 | §1 支援的形態 | 單一形態：桌機（指標 + 鍵盤）（用戶簽核）；同形態內尺寸差異由排列不變式承載，不設 RWD 斷點 | 形態依操作方式界定，本專案唯一操作方式是指標加鍵盤；用戶另裁示：形態不以顯示空間評估，多形態專案須依各形態操作方式各自設計容器 |
| 2 | §1 文字縮放適應 | 0.1 不承諾（用戶簽核）；重評綁後續版本提案票 | 固定高度列全部改彈性的成本不在 0.1 範圍 |
| 3 | §3.3 第 3 項 `EmptyState` 變體 | `section` 核定；`missing` **改為獨立元件 `MissingSourceState`**；`compact` **刪除** | skill 明文「退出路徑差異指離開的層級」：`missing` 的重新整理留在畫面內，`page` 跳轉離開畫面，層級不同即拆件；無最近專案態依 SPEC-001 只有一顆按鈕、無訊息，不構成空狀態元件 |
| 4 | §3.3 第 1、2、4、5、6、7、9、10、12、13、14、17、18、19、20 項 | 依提案核定 | 理由欄成立且與方法論〈命名與通用元件判準〉一致 |
| 5 | §3.3 第 8 項 `Badge` chip／inline | 不設第二變體軸；外觀由所在容器的格位決定（`TableRow` 內為 inline，其餘為 chip） | L2 原則：外觀差異不構成變體 |
| 6 | §3.3 第 11 項節點卡拆四件 | 核定拆分 | 四者內容角色與行為皆不同；「節點卡」命不出共同目的 |
| 7 | §3.3 第 15 項 `DocumentBody` | 屬元件庫；markdown 渲染器內部 widget 列第 7 章豁免（第三方套件內部，條件 1） | 內容政策（行內 code、引用區塊的換行與溢位）須由契約承載，直用渲染器無處寫 |
| 8 | §3.3 第 16 項 `AppSnackBar` | 封裝為元件，兩變體 | 停留時間須引用 `Motion` token，直用會散在四個畫面 |
| 9 | §3.1 `AppButton` 變體集 | `primary` / `secondary` / `text` 三個 | SPEC-001 十四種動作皆落入三類：主要前進、取消／返回類、低強調帶圖示 |
| 10 | §3.1 末段 13 個非資料視圖容器 | 接受 | §3.5 未歸併理由皆為子件類型或策略不同，再併即「任意元件」 |
| 11 | §3.5 `StepNumber` 圓／方 | 統一圓形（`Radius` 全圓階） | 形狀屬 token 非變體；§2 步驟表為主要出現處 |
| 12 | §3.5 `BadgeRow.legend` 間距 | 取 `Space.xs` | 與 `BadgeRow.default` 同值，圖例不另設間距階 |
| 13 | §3.5 `Panel` 內距 | 不分兩階，統一 `Space.md`；節點詳情主欄的額外留白由 `DocumentBody` 自身內距承載 | 內距分階會使 `Panel` 增加無語意的變體 |
| 14 | §3.5 損壞計數可點錨點位置 | `Toolbar` 右側 | 工具列是操作區、底列是摘要區；可點元素歸操作區 |
| 15 | §3.5 主題模式票列欄序 | 統一為列表模式欄序（ID / 標題 / 狀態 / 優先），`TableRow.ticketNested` 刪除，主題節內票列用 `TableRow.ticket` | 兩份畫布衝突，取出現次數多者；欄序不同無語意理由 |
| 16 | §3.5 矩陣格詳情卡 | **納入 0.1**（用戶簽核：規劃不足，於 0.1 補齊規劃設計）。SPEC-001 §1 顯示欄與 SPEC-003 §3.1 反應由補件票補；`TwoColumnLayout` 於 §1 與 §6 皆出現；`ListRow.numbered` 保留 | 畫布已設計，補規格的成本低於日後補畫布 |
| 17 | §3.6 §6 返回／開啟原始檔按鈕位置 | `SplitRow.header` 右側（`ButtonRow`） | 與 §5 重新掃描一致，頁首右側為頁面級動作區 |
| 18 | §3.6 §5 重新掃描按鈕位置 | `SplitRow.header` 右側 | 同上 |
| 19 | §2 傳值 + callback 與資料視圖容器例外、最小重繪邊界、高頻檢核 | 核定 | 與 dart-provider-architecture skill 一致 |
| 20 | §1 第三種測試尺寸 | 不加入 | 無決策來源的數值不發明；拉伸上限由最大尺寸契約承載 |
| 21 | 佈局尺寸 token（側欄寬、列高、右欄寬、浮層寬、圖示尺寸階等） | 建 token 前置票，設為 044.2 blockedBy | 尺寸契約與排列不變式公式需要具名值；右欄寬兩值由該票收斂為一 |
| 22 | `Motion` token | 由既有 pending 票承接，設為 044.2 blockedBy | 互動反應與動畫子節需引用 |
| 23 | `two_dimensional_scrollables` 未在 pubspec | 記入 W1-005 回填內容 | 依賴屬實作票 acceptance |

---

## 4. 逐元件規格

> 每個元件依下列結構定義。目標：實作者不需猜測任何行為。十一欄位對應的子節（對應表見檔頭註解）缺任一即契約不完整，
> 元件票不得驗收、畫面票不得引用（方法論〈元件契約判準〉）。容器元件另填第 5 章的排列不變式。
>
> **本章狀態：骨架，由 0.1.0-W1-044.2 依第 3 章總表逐元件填寫。** 第 1 章形態因素矩陣核定前，
> 尺寸契約與測試點的「每種尺寸」列標「待決」。

### 4.{N} {ComponentName}

**用途**：{一句話}
**內容角色**：{標題 / 內文 / 標籤 / 數值 / 動作 / 容器；複合角色並列（如「內文 + 動作」），每個角色對應一個 slot}
**何時不用**：{一句話；語意相近但不適用的情境}
**出現畫面**：{畫面清單}
**層級**：{L2 複合元件 / L3}

#### 變體

> 語意變體（如 positive / negative / neutral），不以外觀值命名；變體數量與命名定於 L2。

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| {default} | | | |

#### 狀態矩陣

> 每個狀態的顯示、可用操作、進入條件、退出路徑。退出路徑為空 = 死胡同（禁止）。

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | | | | |
| active / focused | | | | |
| disabled | | | | |
| loading（如適用） | | | | |
| error（如適用） | | | | |
| empty（如適用） | | | | |

#### 互動反應

> 每個互動的反應、動畫、時間門檻。反應來源為 UX 審查（本專案為 SPEC-003）。

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| {on tap} | {即時重算 / 導航 / ...} | {動畫 token} | {如 < 100ms 回饋} |
| {on change} | | | |

#### 尺寸契約

> 固有尺寸或填滿父容器擇一；形態因素矩陣列出的每種視窗或裝置尺寸各填一列。

| 項目 | 值 |
|------|-----|
| 尺寸模式 | {固有尺寸 / 填滿父容器（寬） / 填滿父容器（高）} |
| 最小尺寸 | {寬 × 高，引用 token} |
| 最大尺寸 | {寬 × 高，引用 token；無上限寫「無」} |
| `kMinWindowSize` 下的行為 | {維持 / 縮放 / 換版型} |
| `kDesignSize` 下的行為 | |

#### 內容政策

> 每個文字 slot 各一列。超出處置四選一：截斷（ellipsis）/ 淡出（fade）/ 縮放（scale）/ 換行（wrap）。
> 最長測試文案是測試契約的輸入，須為具體字串或其 i18n key。無文字 slot 的元件在表格填一列「不適用」，視同已填。

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| {title} | {是 / 否} | {1} | {截斷} | {key 或字串} |

#### slot 契約

> 使用者可見文字依方法論〈元件文字歸屬〉三層規則：由呼叫端傳入者走 i18n key；
> 強語意預設文案得由元件引用 i18n key 且參數可覆蓋；非語意排版字元可內嵌。

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| {title} | {String（i18n key 取值）} | {是} | {呼叫端 / 元件預設 key} |
| {leading} | {Widget / Icon} | {否} | 不適用 |

#### 使用 design token

> 引用 `lib/tokens/` 的 token，禁硬編碼。

| 面向 | token |
|------|-------|
| 色彩 | {`AppColors.*`} |
| 間距 | {`Space.*`} |
| 字體 | {`AppFontSize.*`} |
| 圓角 | {`Radius.*`} |
| 動畫 | {`Motion.*`} |

#### i18n

> 元件渲染的文字取自 i18n key（`lib/l10n/*.arb`），禁硬編碼。

| 文字 | i18n key |
|------|---------|
| {label} | {key} |

#### 組合規則

> 與鄰件的間距不在此定義，由所在容器的排列不變式承載（方法論〈容器亦為元件〉）。

| 項目 | 值 |
|------|-----|
| 可放入的容器 | {容器元件清單；不可直接放入頁面原生佈局} |
| 對齊基準 | {文字基線 / 上緣 / 置中} |
| 作為表格或列表的一欄時 | {欄比例 / 固定寬（引用 token）；內距（引用 token）} |

#### a11y

| 面向 | 要求 |
|------|------|
| 語意標籤 | {semantic label} |
| 對比 | {WCAG AA} |
| 鍵盤 / 焦點 | {如適用} |

#### 測試點（widget test）

> 測試形態（golden / widget test）定於 L2。

- [ ] 一支測試逐一渲染全部變體與全部狀態
- [ ] 形態因素矩陣的每種尺寸皆不溢位
- [ ] 最長測試文案依內容政策處置（截斷 / 淡出 / 縮放 / 換行）
- [ ] 中英文文字不溢位（i18n × 版面）
- [ ] {互動反應觸發}
- [ ] token 引用非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| {誤用情境} | {相鄰元件} |

---

## 5. 容器元件

> 決定多個元件如何相對排列的佈局結構皆為元件，須有第 4 章的條目；本章補容器專屬的排列不變式與子件契約。
> 頁面直接用原生佈局原語（水平 / 垂直堆疊、格線）排列元件視同自製元件。
>
> **本章狀態：骨架，由 0.1.0-W1-044.2 依第 3 章容器總表逐容器填寫。** 3.4 的排列關係表即本章的候選表，逐列核對。

### 5.{N} {ContainerName}

**對應第 4 章條目**：4.{M}

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | {元件清單} |
| 子件數量上限 | {N / 無上限} |

#### 排列不變式

> 三項皆必填。子件數量無上限者必然觸發空間不足，其策略不得留空。子件有上限且最小視窗保證放得下者，
> 策略填「不觸發：上限 N + 不重疊公式」。子件的組合規則不得另定間距。

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 子件邊界盒兩兩不相交；測試以形態因素矩陣每種尺寸 × 子件數量上限驗證 |
| 最小間距 | {引用 `Space.*`；呼叫端不得覆寫為更小值} |
| 空間不足策略 | {換行 wrap / 捲動 scroll / 收合 collapse 三選一}；觸發條件：{如寬度小於子件最小寬總和} |

---

## 6. 原生元件禁用對照表

> 禁止直接使用的原生元件，及應改用的封裝元件。（骨架，待填）

| 禁止直接使用 | 改用 | 理由 |
|-------------|------|------|
| {原生元件} | {封裝元件} | {統一性理由} |

---

## 7. 豁免清單（三條件 AND，全滿足才可豁免直用）

> 條件 1 結構性無法收斂、條件 2 記錄理由、條件 3 列入工具白名單。
> 豁免由 PM 於票驗收時核可，本清單為單一權威來源。（骨架，待填）

| 路徑 | 具體理由 | 白名單登記 |
|------|---------|-----------|
| {path} | {理由} | {是/否} |

---

## 8. 跨平台命名契約（如適用）

> 本專案單端（macOS），不適用；保留節號以對齊範本。

| 元件語意名 | variant | size | 各端對映 | 權威端 |
|-----------|---------|------|---------|-------|
| 不適用 | | | | |

---

## 9. 驗收標準

- [ ] 形態因素矩陣已定，版型策略明文
- [ ] 狀態綁定模式已決定
- [ ] 每個元件的內容角色與何時不用已填（語意與內容角色）
- [ ] 每個元件的變體以語意命名，外觀與行為差異已列
- [ ] 每個元件有完整狀態矩陣（無死胡同退出路徑）
- [ ] 每個元件的互動反應/動畫/時間門檻已定義
- [ ] 每個元件的尺寸契約涵蓋形態因素矩陣的每種尺寸
- [ ] 每個文字 slot 有內容政策（換行 / 最大行數 / 超出處置 / 最長測試文案）
- [ ] 每個元件的 slot 契約已列，文字來源符合〈元件文字歸屬〉
- [ ] 每個元件的組合規則已列，且未另定間距
- [ ] 每個元件的 token 依賴、i18n key、測試點、反例已列
- [ ] 元件清單總表中每個排列關係都有容器元件，容器的排列不變式三項齊全
- [ ] 原生禁用對照表與豁免清單完整
- [ ] 元件文字經中英文溢位測試

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.4 | 2026-09-02 | 用戶補充回饋通道、最小命中區、禁放區與安全區三維度；§1 填桌機值（視覺回饋、`hitTargetMin` 提案待 W1-047、無禁放區與 SafeArea） |
| 1.3 | 2026-09-02 | 用戶補充操作機制與無障礙為必填欄，契約欄位九改十一；§3.7 引言補說明 |
| 1.2 | 2026-09-02 | 用戶裁示形態依操作方式界定：§1「斷點策略／版型策略」兩列改為「同形態內的尺寸適應策略／支援的形態（單一形態：桌機）」，去「響應式」措辭；§3.7 第 1 項同步 |
| 1.1 | 2026-09-02 | PM 驗收 044.1：新增 §3.7 核定記錄二十三項（版型策略、文字縮放為用戶簽核；`missing` 改獨立元件 `MissingSourceState`、`compact` 刪除、`ticketNested` 刪除、格詳情卡納入 0.1）；§1 三格去待核定標；佈局 token 前置票、格詳情卡規格補件票、動態字級重評票各建一張 |
| 0.1 | 2026-09-02 | 初版骨架（0.1.0-W1-044.1）：依 component-contract-design skill 模式 B → A 推導，填第 1 章形態因素矩陣（提案，待核定）、第 2 章狀態綁定模式（Riverpod，傳值 + callback 為提案）、第 3 章元件清單總表（元件 25、容器 17）含推導記錄（3.2–3.6）；第 4–9 章保留範本骨架。SPEC-002〈元件庫的範圍〉改為指向本檔 |
