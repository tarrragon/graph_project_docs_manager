---
id: SPEC-004
title: "元件庫規格：元件目錄、逐元件契約與容器排列不變式"
status: draft
source_proposal: PROP-004
created: "2026-09-02"
updated: "2026-09-02"
version: "1.8"
owner: lavender-interface-designer

domain: "ui"
subdomain: component-library

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06]
related_specs: [SPEC-001, SPEC-002, SPEC-003]
implements_requirements: []
depends_on_domains: [layout]
---

# 元件庫規格（L3 元件庫章節）

**版本**: 1.9（第 1-3 章已核定；第 4-5 章逐元件契約與容器不變式由 `0.1.0-W1-044.2` 填寫；第 6-7 章依 §3.7 第 7 項填最小集，標提案；對比核定依 §3.7 第 25 項回填）
**來源**: PROP-004
**依賴**: SPEC-002（token 來源，`lib/tokens/`）、SPEC-003（互動反應來源）、SPEC-001（狀態表，元件候選的書面來源）

> **層級定位**（component-library 方法論）：L1 通用原則（方法論）、L2 框架實作規範、
> L3 專案元件庫章節（本檔）。本檔為 L3，承載元件清單、逐元件契約（十一欄位）、容器元件與排列不變式、
> 原生禁用對照、豁免清單、形態因素矩陣、狀態綁定決策。
>
> **與 SPEC-002 的分工**：SPEC-002 是 token 規格（顏色、間距、字級、圓角的命名與離散尺度），
> 其〈元件庫的範圍〉一節的清單自本檔建立起改為指向本檔第 3 章，清單不雙份維護。
> 本檔引用 token 一律寫 `lib/tokens/` 的常數名（`AppColors.*`、`Space.*`、`Radius.*`、`AppFontSize.*`、
> `LayoutSize.*`、`Motion.*`），不出現裸值；視窗尺寸引用 `lib/main.dart` 的 `kDesignSize` 與 `kMinWindowSize`。
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
| `AppButton`（按鈕） | 元件 | L2 | SPEC-001「可用操作」欄所有有視覺承載的動作：開始載入、取消、重新掃描、重新整理、返回、開啟原始檔、檢視關聯、返回 Domain 視圖、前往破洞報告、開啟 docs 目錄、檢視詳情、選擇資料夾、選擇其他、在泳道中檢視、關閉詳情卡 | §1–§7 | `primary`（前進／主要動作）/ `secondary`（取消、返回、重新整理）/ `text`（低強調、可帶 leading icon，如浮層底部「選擇其他資料夾…」）；三變體已核定（§3.7 第 9 項） |
| `Badge`（徽章） | 元件 | L2 | 非互動的標籤／數值標記 | §1–§7 | `count`（計數）/ `status`（draft／pending／completed／confirmed／approved 等）/ `type`（PROP／SPEC／UC／Ticket）/ `category`（破洞類別）/ `event`（emits X／consumes X）/ `tag`（domain: schema、N 個 FR）/ `legend`（圖例：符號 + 說明）/ `health`（專案健康計數）；顏色以語意 `tone` 參數取 token（§4.5）；chip 底／純文字不設第二變體軸，由所在容器格位決定（§3.7 第 5 項） |
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
| `StepNumber`（步驟序號） | 元件 | L3 | 步驟列與詳情卡步驟清單的序號 | §1（詳情卡）、§2 | `default`；統一圓形（§3.7 第 11 項）；直徑 `LayoutSize.stepNumberSize`（24） |
| `ExpanderIcon`（展開收合） | 元件 | L2 | 樹節點、主題節、破洞分節的展開觸發器，`expander-*` | §3、§4、§5 | `default`；狀態 expanded / collapsed / leaf（無子層時不渲染箭頭但保留寬度） |
| `RelationItem`（關聯項） | 元件 | L3 | 節點詳情右欄的關聯節點 ID，等寬字、chip 底、可點擊替換主欄，`card-nodeDetail-relation-<nodeId>` | §6 | `default`；狀態 default / hover / damaged（邊損壞時套 `IssueMarker.damagedEdge`） |
| `DocumentBody`（文件內文） | 元件 | L3 | 節點詳情主欄的 markdown 渲染內容（段落、行內 code、FR 引用區塊）；由 0.0.3 選定的 `flutter_markdown_plus` 承載，渲染器內部 widget 列第 7 章豁免 | §6 | `default`；屬元件庫（§3.7 第 7 項） |
| `EmptyState`（空狀態） | 元件 | L3 | 「這裡目前沒有內容」+ 至少一個非返回的前進動作（FR-03）；訊息、說明、動作為 slot | §1（未選專案、空圖、未選格右欄）、§2（無 UC、flow 未結構化）、§3（無提案）、§4（無 ticket）、§5（無破洞）、§6（未選節點） | `page`（全頁）/ `section`（區塊內：與 UC 基本資訊並列、未選格右欄）；`missing` 改為獨立元件 `MissingSourceState`、`compact` 刪除（§3.7 第 3 項） |
| `MissingSourceState`（原始檔已消失） | 元件 | L3 | 「原始檔已不存在」+ 最後已知路徑 + 重新整理／返回；退出留在畫面內（重新整理三分支，SPEC-003 §3.6），與 `EmptyState.page` 的跳轉層級不同故獨立 | §6（原始檔已消失） | `default` |
| `BlockedState`（阻擋狀態） | 元件 | L3 | 「這個專案不適用本 App」+ 版本值 + 說明 + 切換專案出口（恆可用，FR-07）；0.1 不渲染「以純檔案模式檢視」（SPEC-003 §3.1） | §1（不是框架專案、無可消費的型別表、schema 不相容） | `plain` / `withDetail`（附「檢視詳情」展開 `panel-domain-schema-detail`，內容為兩個版本值的 `Section`） |
| `LoadingState`（載入態） | 元件 | L3 | 骨架或進度 + 計數文字 + 取消；取消契約 11 條（SPEC-003 §2.5）由本元件單一承擔 | §1（載入中）、§4（載入中）、§5（掃描中） | `skeleton`（indeterminate + 計數文字；骨架版位 slot：`matrix` / `sections`）/ `progressBar`（determinate + 已解析筆數／總數 N） |
| `LoadPrompt`（待載入提示） | 元件 | L3 | 「載入 N 張 ticket」+ 開始載入 + 返回（`returnTo` 為 null 時不渲染）；不顯示預估耗時（SPEC-003 §3.4） | §4（未載入） | `default`；獨立元件為提案（3.3 第 4 項） |
| `AppSnackBar`（即時訊息） | 元件 | L2 | 「已在外部開啟」「找不到檔案」類的暫時訊息，Material 預設動畫不覆寫 | §1、§2、§5、§6 | `plain`（停留 `Motion.snackBar`）/ `withAction`（帶一個動作，停留 `Motion.snackBarWithAction`）；封裝為元件（§3.7 第 8 項） |

#### 容器

| 元件 | 種類 | 層級 | 用途 | 出現畫面 | 變體（variant） |
|------|------|------|------|---------|----------------|
| `AppShell`（根框架） | 容器 | L3 | 根：無父容器。標題列（`AppText.title` 應用名）/ 側欄（`ProjectSwitcherEntry` + `NavItem` × 6，垂直）/ 主區（`PageColumn`）三格；側欄固定寬、主區填滿 | 殼 | `default`；既有 `lib/app/shell.dart` 為其實作雛形（見 3.5 漂移） |
| `PageColumn`（頁面區塊堆疊） | 容器 | L3 | 每頁根堆疊：`SplitRow.header` + 內容（`Panel` 或 `TwoColumnLayout` 或狀態元件）垂直；內容區內距 `Space.xl` | §1–§6 | `default` |
| `SplitRow`（左右分列） | 容器 | L2 | 左右兩端對齊的水平列：頁首（`PageTitle` + `SegmentedControl`）、Ticket 清單摘要底列（`AppText` + `AppText`） | §1–§6（頁首）、§4（底列） | `header`（固定高、底邊框 `AppColors.border`、底 `AppColors.surfaceBase`）/ `footer`（頂邊框）；合併為提案（3.3 第 13 項） |
| `Panel`（面板） | 容器 | L2 | 白底（`AppColors.surfaceBase`）、邊框 `AppColors.border`、圓角 `Radius.lg`、內距 `Space.md` 的垂直堆疊；子件為具名清單（`Toolbar` / `TableRow.header` / `DataTable` / `MatrixGrid` / `SwimlaneGrid` / `Tree` / `Section` / `BadgeRow` / `Divider` / `AppText` / `DocumentBody` / `ListRow`） | §1–§6 | `default` / `scrollable`（主體可垂直捲動，承載 `scroll-traceability-tree`、`scroll-gaps-sections`、`scroll-nodeDetail-*`） |
| `TwoColumnLayout`（主副雙欄） | 容器 | L3 | 主欄 `Panel`（填滿）+ 右欄 `Panel.scrollable`（固定寬 `LayoutSize.detailPaneWidth`）水平並排，間距 `Space.md`；兩欄各自獨立捲動（SPEC-003 FR-10、§1.1 連動禁令） | §1（正常·矩陣、已選格）、§6（正常、部分損壞） | `default`（§3.7 第 16、21 項） |
| `Toolbar`（工具列） | 容器 | L2 | `SearchField`（填滿）+ `FilterDropdown` × N + `IssueMarker.damagedDetail`（可點錨點 `badge-tickets-corrupted`，§3.7 第 14 項）水平，底邊框 | §4 | `default` |
| `BadgeRow`（徽章列） | 容器 | L2 | `Badge` × N 水平、間距 `Space.xs`，空間不足換行；承載節點詳情標籤列、矩陣與泳道圖例列、事件標籤 | §1、§2、§6 | `default` / `legend`（頂邊框，面板底部；間距同 `Space.xs`，§3.7 第 12 項） |
| `ButtonRow`（按鈕列） | 容器 | L2 | `AppButton` × N 水平；承載狀態元件的動作區（開始載入 + 返回；重新整理 + 返回；開啟原始檔 + 檢視關聯 + 返回 Domain）、頁首右側頁面級動作區（§3.7 第 17、18 項）、格詳情卡動作區 | §1–§6 | `default`；子件上限 3（0.1 最多三動作） |
| `TableRow`（表格列） | 容器 | L2 | 欄寬對齊表頭的水平格線列；子件 ∈ {`TableColumnHeader`, `AppText`, `Badge`, `StepNumber`, `BadgeRow`, `IssueMarker`, `RelationItem`（步驟列 domain 欄，可點）} | §2、§4 | `header`（`TableColumnHeader` × N）/ `ticket`（ID mono、標題、狀態徽章、優先、損壞標記；列表與主題模式共用同一欄序，§3.7 第 15 項）/ `step`（序號、步驟名、domain 標籤、事件徽章列） |
| `DataTable`（資料表） | 容器 | L2（資料視圖） | `TableRow.header` + `TableRow` × N 垂直；Ticket 清單為虛擬捲動（`scroll-tickets-list`），UC Flow 為一般捲動（`scroll-ucFlow-steps`） | §2、§4 | `virtual` / `plain` |
| `MatrixGrid`（矩陣） | 容器 | L3（資料視圖） | domain × UC 二維格線：欄首 `TableColumnHeader.twoLine`、列首 `AppText`、格 `MatrixCell`、小計 `AppText.caption`；欄首與列首釘選、二維捲動（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`） | §1 | `default` |
| `SwimlaneGrid`（泳道） | 容器 | L3（資料視圖） | 泳道列（`AppText` 泳道名 + `SwimlaneNode` 置於步驟欄）× N 垂直、列間虛線；底部步驟箭頭列；0.1 以寫死座標的假資料靜態排版（SPEC-001 設計約束），二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`） | §1 | `default` |
| `Tree`（樹） | 容器 | L3（資料視圖） | `ListRow.tree` × N 垂直，依深度縮排；展開收合改變列集合（`scroll-traceability-tree`） | §3 | `default` |
| `ListRow`（通用列） | 容器 | L2 | leading（`ExpanderIcon` / `AppIcon` / `Badge` / `StepNumber`，可選）+ 主文字 `AppText`（填滿）+ 次文字 `AppText.secondary`（可選，堆疊於主文字下）+ trailing（`Badge` / `AppIcon` / `AppText.caption`，可選）水平 | §1（詳情卡步驟）、§3（樹節點）、§4（主題節首）、§5（分節首、破洞項）、§6（節點 meta 列） | `tree`（展開 + 標題 + 狀態徽章）/ `sectionHeader`（展開或類別徽章 + 名稱 + 計數）/ `item`（標題 + 說明 + 外開箭頭）/ `meta`（型別徽章 + 路徑 mono）/ `numbered`（序號 + 文字）；合併為提案（3.3 第 12 項） |
| `Section`（分節） | 容器 | L2 | 節首 + 項目垂直堆疊：主題節（`ListRow.sectionHeader` + `TableRow.ticket` × N）、破洞類別節（`ListRow.sectionHeader` + `ListRow.item` × N）、關聯群（`AppText.caption` + `RelationItem` × N）、schema 詳情面板（`AppText.caption` + `AppText.mono` × 2） | §1（詳情面板）、§4、§5、§6 | `collapsible`（節首含 `ExpanderIcon`，`expander-*`）/ `static`；「未歸屬」節以頂部虛線分隔為修飾參數（§3.7 第 4 項核定 3.3 第 14 項） |
| `SwitcherOverlay`（專案切換浮層） | 容器 | L3 | 覆蓋層：`AppText.caption` 標題 + `RecentProjectItem` × N（垂直捲動 `scroll-switcher-recent`）+ `Divider` + `AppButton.text`（選擇其他資料夾）；自入口向下展開，Esc／點外部收合，焦點限制於浮層內 | §7（展開、無最近專案） | `default`；`RecentProjectItem` 數量無上限 → 空間不足策略為捲動 |

**定案數（§3.7 核定後）**：元件 26（原 25 加 `MissingSourceState`）、容器 16（其中資料視圖 4：`DataTable`、`MatrixGrid`、`SwimlaneGrid`、`Tree`；0.1 版原記「17」為計數誤差，本表實列 16）。
非資料視圖的容器 12 個，超過 skill〈Troubleshooting〉的十個門檻；3.5 記錄已做的歸併與未再歸併的理由，
再往下歸併須把 slot 子件清單寫成「任意元件」，skill 明文視同原生佈局，§3.7 第 10 項核定接受此數。

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
| §1 泳道 | 二維：泳道列 × 6 垂直（虛線分隔）；列內水平：泳道名 / 步驟欄 × 6，節點置中於欄 | 列高 `LayoutSize.laneRowHeight`、泳道名欄 `LayoutSize.laneLabelWidth`（W1-047 已建） | `SwimlaneGrid` |
| §4 列表 | 工具列水平：搜尋（填滿）/ 下拉 × 2 | `Space.sm` | `Toolbar` |
| §2、§4 | 表頭水平格線：欄首 × N | 欄間 `Space.md` | `TableRow.header` |
| §2、§4 | 資料列水平格線：格 × N，欄寬對齊表頭 | 欄間 `Space.md`；列高 `LayoutSize.rowHeightRelaxed`（W1-047 已建）；固定寬欄 token（`ticketIdColumnWidth` 等，`0.1.0-W1-055` 已建） | `TableRow.ticket` / `TableRow.step` |
| §2、§4 | 表格垂直：表頭 / 列 × N | 列間以 `AppColors.border` 底邊分隔 | `DataTable` |
| §4 列表 | 底列水平：摘要 / 說明 | 兩端對齊 | `SplitRow.footer` |
| §4 主題 | 節垂直：節首 / 票列 × N；節之間垂直 | 節內 `Space.xxs`、節間 `Space.sm`；未歸屬節頂部虛線 | `Section.collapsible` |
| §4 主題、§5 | 節首水平：展開或類別徽章 / 名稱 / 計數 | `Space.sm` | `ListRow.sectionHeader` |
| §5 | 節垂直：節首 / 破洞項 × N；節間垂直 | 節間 `Space.lg`；項以頂邊框分隔 | `Section.collapsible` |
| §5 | 破洞項水平：標題與說明堆疊 / 外開箭頭 | `Space.sm`；標題與說明 `Space.xxs` | `ListRow.item` |
| §3 | 樹垂直：列 × N，依深度縮排；列水平：展開 / 名稱 / 狀態 | 列高 `LayoutSize.rowHeightDense`；列內 `Space.sm`；每層縮排 `LayoutSize.treeIndent`（24，`0.1.0-W1-055` 已建） | `Tree` + `ListRow.tree` |
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
| `design/Main.dc.html` 矩陣模式頁首副標「點格子切換至泳道」，SPEC-003 §3.1 採方案 B 後單擊為選格 | 行為類（規格為準） | 副標改為「點格子檢視詳情」；畫布不回改，畫面票的副標文案依 SPEC-003（W1-048 消費結果） |
| 畫布無 hover / focused / pressed 任何樣式，無格詳情卡關閉鈕、無矩陣格選中態 | 畫布不可得 | 互動瞬態視覺依 §4.0.1 通用約定（Material 內建 overlay，不自繪，標提案）；選中態依 §4.15 成對設計 |
| 畫布頂端標題列高 36、票表固定寬欄 132 / 84 / 40 / 22、步驟表 26 / 118、樹縮排每層 24、步驟序號 16 與 24 兩值 | 視覺值，token 缺 | `0.1.0-W1-055` 已建對應 token；§4.0.9 待決清單去標 |

### 3.6 SPEC-001 31 列與 SPEC-002 八類的歸屬對照

**SPEC-002〈元件庫的範圍〉八類 → 本檔**：

| SPEC-002 元件 | 本檔歸屬 | 變動 |
|------|------|------|
| 空狀態（訊息 + 前進動作） | `EmptyState` + `MissingSourceState` | 變體 `page` / `section`；原始檔已消失拆為獨立元件（§3.7 第 3 項） |
| 阻擋狀態（訊息 + 版本值 + 出口） | `BlockedState` | 增 `withDetail` 變體 |
| 載入態（骨架 + 進度 + 取消） | `LoadingState` | 變體依進度型別 |
| 損壞標記（兩級） | `IssueMarker` | 更名，增 `gap` 變體（提案） |
| 導覽項 | `NavItem` | 無 |
| 專案切換浮層 | `ProjectSwitcherEntry` + `SwitcherOverlay` + `RecentProjectItem` | 拆為入口、浮層容器、項（提案） |
| 節點卡 | `MatrixCell` / `SwimlaneNode` / `ListRow.tree` / `ListRow.item` | 拆分（提案，3.3 第 11 項） |
| 徽章（計數／狀態／健康） | `Badge` | 變體擴為八個 |

**SPEC-001 31 列顯示欄 → 本檔**（狀態元件內部的訊息／說明／動作皆為該元件的 slot，不另列；SPEC-001 v1.4 狀態總數 31，第 31 列為 §1「已選格」）：

| § | 狀態 | 顯示欄單元 | 歸屬 |
|---|------|------|------|
| §1 | 未選專案 | 空畫面 + 選擇資料夾引導 | `EmptyState.page`（動作 `AppButton.primary` 選擇資料夾） |
| §1 | 載入中 | 骨架版面 + 進度 + 取消 | `LoadingState.skeleton`（版位 `matrix`） |
| §1 | 正常 · 矩陣 | domain × UC 交叉表 + 右欄格詳情卡區（未選格常駐提示） | `PageColumn`[`SplitRow.header`[`PageTitle`, `SegmentedControl`], `TwoColumnLayout`[`Panel`[`MatrixGrid`, `BadgeRow.legend`], `Panel.scrollable`[`EmptyState.section`（`panel-domain-cell-detail-empty`，訊息 `cellDetailPrompt`，無動作）]]] |
| §1 | 已選格（疊加於正常 · 矩陣） | 右欄格詳情卡：標題、關係種類、說明、編號步驟、事件標籤、在泳道中檢視、關閉 | 底層同上 + 右欄 `Panel.scrollable`[`SplitRow.header`[`AppText.subtitle`, `AppButton.text`（關閉，`action-domain-cell-clear`）], `AppText.caption`（關係種類）, `AppText.body`（說明，可缺）, `ListRow.numbered` × N（可缺）, `BadgeRow`[`Badge.event` × N]（可缺）, `ButtonRow`[`AppButton.secondary`（在泳道中檢視，`action-domain-cell-goto-swimlane`）]]（`panel-domain-cell-detail`，`scroll-domain-cell-detail`）；`MatrixCell` 呈 `selected` |
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
| §4 | 含損壞（疊加態） | 正常視圖 + 損壞徽章與計數 | 底層正常態 + `Toolbar` 右側 `IssueMarker.damagedDetail`（可點 `badge-tickets-corrupted`，§3.7 第 14 項）+ 各損壞列末欄 `IssueMarker.damagedDetail`（圖示） |
| §5 | 掃描中 | 骨架 + 進度 + 取消 | `LoadingState.skeleton`（版位 `sections`） |
| §5 | 無破洞 | 訊息 + 掃描範圍說明 + 重新掃描 | `EmptyState.page`（說明 slot；動作 `AppButton` 重新掃描） |
| §5 | 有破洞 | 依類別分節，各項帶檔案與行號 + 重新掃描 | `Panel.scrollable`[`Section.collapsible`[`ListRow.sectionHeader`, `ListRow.item` × N] × N]；重新掃描 `AppButton.secondary` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 18 項） |
| §6 | 未選節點 | 空狀態元件 + 「尚未選取節點」 | `EmptyState.page`（動作前往追溯視圖） |
| §6 | 正常 | 全頁內容 + 關聯右欄 + 開啟原始檔／返回 | `TwoColumnLayout`[`Panel.scrollable`[`ListRow.meta`, `AppText.title`, `BadgeRow`, `Divider`, `DocumentBody`], `Panel.scrollable`[`Section.static` × N]]；返回與開啟原始檔的 `AppButton` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 17 項；返回鍵由 `AppShell` 之下的頁面框架單一渲染，SPEC-003 §2.4） |
| §6 | 部分損壞 | 可讀欄位 + 損失欄位標示 + 跳轉破洞報告 | 同上 + 欄位級 `IssueMarker.damagedDetail`（說明文字 slot） |
| §6 | 原始檔已消失 | 訊息 + 最後已知路徑 + 重新整理／返回 | `MissingSourceState`（`ButtonRow`[`AppButton.primary` 重新整理, `AppButton.secondary` 返回]） |
| §7 | 收合 | 側欄頂端顯示目前專案名 | `ProjectSwitcherEntry` |
| §7 | 展開 | 最近專案清單 + 健康徽章 + 選擇其他 | `SwitcherOverlay`[`AppText.caption`, `RecentProjectItem`（`Badge.health`）× N, `Divider`, `AppButton.text`] |
| §7 | 無最近專案 | 僅「選擇資料夾…」 | `SwitcherOverlay` 零項 + `AppButton.text`（訊息文案 `switcherChooseFolderPrompt`；不用 `EmptyState`，§3.7 第 3 項） |

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
| 23 | `two_dimensional_scrollables` 未在 pubspec | 已由 W1-038 加入（^0.5.4） | 依賴屬實作票 acceptance |
| 24 | `LayoutSize.matrixColumnWidth` 提案值 122 | 核定 | 畫布為 `repeat(5,1fr)` 無固定值；122 由 Main 版面尺寸鏈（矩陣首欄 + 小計欄 + 五個 UC 欄 = 主區寬）反推，與既有 token 加總一致；`two_dimensional_scrollables` 需固定欄寬 |
| 25 | `textSecondary` 對比未達 WCAG AA（`0.1.0-W1-058`） | 方案 C（用戶經 WRAP 重評裁決）：`textSecondary` 調深 `#8A9694` → `#6A7674`（對 `surfaceBase` 4.71:1）；新增 `textDisabled` = `#8A9694` 供停用態與純裝飾箭頭圖示；`surfaceSegmentTrack` 調淺 `#DCE4E2` → `#DEE6E4`（對 `textPrimary` 4.56:1）；三案共通項：`Badge` 刪 `secondary` tone、帶色表面上的次要文字改 `textPrimary`。token 由 `0.1.0-W1-059` 落地，本檔由 `0.1.0-W1-060` 回填 | AA 一般字級是硬門檻，11 個文字條目全為 10～12px 無大字級可套用；原 token 兼任停用色，僅調深會使停用態與作用中次要文字同色，故以新 token 分離兩種語意，並讓 SC 1.4.3 非作用中元件豁免有明確 token 對應；畫布偏離面積最小（116 處文字調深，約 10 處箭頭／停用維持原色）。失敗警訊：實機主次層級不可辨，回退為主色再調深 |

---

## 4. 逐元件規格

> 每個元件依下列結構定義。目標：實作者不需猜測任何行為。十一欄位對應的子節（對應表見檔頭註解）缺任一即契約不完整，
> 元件票不得驗收、畫面票不得引用（方法論〈元件契約判準〉）。容器元件另填第 5 章的排列不變式。
>
> **本章狀態：已填（`0.1.0-W1-044.2`，2026-09-02）。** 元件 26 條（4.1–4.26）、容器 16 條（4.27–4.42）；容器另於第 5 章填子件契約與排列不變式。
> 每條目十三個子節，對應十一欄位（語意與內容角色＝條目標頭；狀態集＝狀態矩陣；測試契約＝測試點）加上互動反應與 design token 兩個實作契約。
> 跨元件相同的值集中於 §4.0，條目內以「依 §4.0.x」引用，引用即視為該欄已填。

### 4.0 本章通用約定

#### 4.0.1 互動瞬態（hover / pressed / focused）與 disabled 的視覺

| 瞬態 | 值 | 來源 |
|------|-----|------|
| pressed | Material `InkWell` / `ButtonStyleButton` 內建 pressed 態，不自繪 | SPEC-003 §2.2（抄錄） |
| hover | 同上，Material `InkWell` 內建 hover overlay（`hoverColor` 取 `ThemeData` 預設），不自繪；畫布無 hover 樣式 | 提案：延伸 SPEC-003 §2.2「不自繪」慣例 |
| focused | 元件祖先鏈存在 `decoration` 非 `null` 的 `DecoratedBox`（SPEC-003 §2.10 焦點裝飾斷言）；裝飾為 `AppColors.accent` 外框、圓角同元件 | 存在性抄錄 SPEC-003 §2.10；顏色為提案 |
| disabled | `enabled` 為 `false`；文字與圖示改 `AppColors.textDisabled`（停用態專用 token，§3.7 第 25 項；SC 1.4.3 對非作用中元件豁免），無 hover overlay；同列以常駐文字（非 tooltip，`AppText.caption`，`textSecondary`）說明原因（SPEC-003 §2.2、FR-06） | SPEC-003（抄錄）；token 名依 `0.1.0-W1-058` 方案 C |

狀態矩陣中 hover / pressed / focused 三列為「互動瞬態」，不改變元件語意狀態，退出路徑恆為「指標離開／放開／焦點移走」，各條目不重複填此三列，以「依 §4.0.1」一列代之。

#### 4.0.2 對比約定（WCAG 2.1 SC 1.4.3，AA：一般字 4.5:1、大字 3:1）

依 `lib/tokens/colors.dart` 的 token 值計算（量測對象為 token，非畫布；相對亮度公式，保留兩位小數）。`0.1.0-W1-058` 核定方案 C（§3.7 第 25 項），`0.1.0-W1-059` 落地：`textSecondary` 調深為 `#6A7674`、新增 `textDisabled`（原畫布次要文字色 `#8A9694`）、`surfaceSegmentTrack` 調淺為 `#DEE6E4`。

**表 1：文字對比（SC 1.4.3，一般字 4.5:1）**

| 前景 / 底色 | 對比 | AA 一般字 | 備註 |
|------|------|------|------|
| `textPrimary` / `surfaceBase` | 5.79:1 | 通過 | |
| `textPrimary` / `surfaceSidebar` | 5.33:1 | 通過 | |
| `textPrimary` / `surfaceChip` | 4.94:1 | 通過 | 徽章 `neutral` tone、`RelationItem`、`SwimlaneNode` |
| `textPrimary` / `surfaceIconTint` | 4.89:1 | 通過 | `RecentProjectItem` selected 摘要 |
| `textPrimary` / `surfaceSegmentTrack` | 4.56:1 | 通過 | 調淺後；原畫布值 `#DCE4E2` 為 4.48:1 未達 |
| `textTitle` / `surfaceBase`、`textTitle` / `surfaceSidebar`、`textTitle` / `surfaceIconTint` | 14.5～17.2:1 | 通過 | |
| `textSecondary` / `surfaceBase` | 4.71:1 | 通過 | 調深後；原畫布值 `#8A9694` 為 3.06:1 未達 |
| `textSecondary` / `surfaceSidebar` | 4.34:1 | **未達** | 見帶色表面規則 |
| `textSecondary` / `surfaceChip` | 4.02:1 | **未達** | 同上 |
| `textSecondary` / `surfaceIconTint` | 3.98:1 | **未達** | 同上 |
| `accentStrong` / `surfaceIconTint`、`accentStrong` / `surfaceChip`、`accentStrong` / `surfaceBase` | 8.4～9.9:1 | 通過 | |
| `surfaceBase` / `accent` | 5.84:1 | 通過 | 選中態、`primary` 按鈕 |
| `success` / `surfaceBase`、`success` / `surfaceChip` | 5.18～6.07:1 | 通過 | |
| `warning` / `warningSurface`、`error` / `errorSurface`、`error` / `surfaceBase` | 5.29～6.54:1 | 通過 | |

**表 2：停用態與純裝飾圖示（`textDisabled`，SC 1.4.3 對非作用中元件豁免；SC 1.4.11 非文字 3:1）**

| 前景 / 底色 | 對比 | 判定 | 允許用途 |
|------|------|------|------|
| `textDisabled` / `surfaceBase` | 3.06:1 | 未達一般字；達非文字 3:1 | 停用態文字與圖示（§4.0.1）、純裝飾箭頭圖示 |
| `textDisabled` / `surfaceSidebar` | 2.82:1 | 未達 3:1 | 僅純裝飾（排除於語意樹）：`ProjectSwitcherEntry` 展開箭頭 |
| `textDisabled` / `surfaceChip`、`textDisabled` / `surfaceIconTint` | 2.58～2.61:1 | 未達 3:1 | 不得使用 |

**帶色表面規則**：`textSecondary` 只承諾於 `surfaceBase` 達 AA；`surfaceSidebar` / `surfaceChip` / `surfaceIconTint` / `surfaceSegmentTrack` 上的可讀文字一律取 `textPrimary` 或語意色（`accentStrong` / `success` / `warning` / `error`），不得置 `textSecondary`。依此規則改寫的條目：4.5 `Badge` 刪 `secondary` tone、4.6 `IssueMarker.damagedEdge` child 文字改 `textPrimary`、4.9 `RecentProjectItem` selected 摘要改 `textPrimary`。

**`textDisabled` 對應**：4.0.1 disabled 列（4.4 `AppButton`、4.9 `RecentProjectItem`、4.24 `LoadingState` 取消鈕經 4.4）、4.8 `ProjectSwitcherEntry` 展開箭頭、4.12 `SearchField` 搜尋圖示、4.13 `FilterDropdown` 箭頭、4.18 `ExpanderIcon` 箭頭、4.38 `SwimlaneGrid` 底部箭頭列（皆為非文字且非唯一訊號，語意另由旗標或文案承載）。語意符號（4.15 `MatrixCell.indirect` ○、4.5 `Badge.legend` 符號）與可讀文字維持 `textSecondary`。

各條目無障礙子節的「對比」列引用本表值，不另重算。

#### 4.0.3 尺寸推算約定

| 項目 | 值 |
|------|-----|
| 文字行高 | 字級 token × Flutter `TextStyle.height` 預設值（不指定 `height`）；行高不入 token |
| chip 類固有高（`Badge`、`SwimlaneNode`、`RelationItem`） | `AppFontSize.caption`（或 `body`）行高 + 2 × `Space.xxs` |
| 可點元件最小高 | `LayoutSize.hitTargetMin`（§1 最小命中區）；固有高小於之者以透明命中區補足，不放大視覺 |
| 列高 | 結構性列 `LayoutSize.rowHeightDense`；扁平內容列 `LayoutSize.rowHeightRelaxed`（`lib/tokens/layout.dart` 歸併表） |
| 邊框線寬 | Flutter `Divider.thickness` / `BorderSide.width` 預設值（1 邏輯像素），不另建 token（既有 `lib/app/shell.dart` 慣例；提案） |
| 「每種尺寸下的行為」 | 兩種測試尺寸 `kMinWindowSize`、`kDesignSize`（§1）；元件本身不感知視窗尺寸，行為差異全部來自所在容器給的約束，故條目內寫「維持（約束由容器決定）」即為落成值 |

#### 4.0.4 測試文案常數（`TestCopy`，供測試契約引用）

ARB 只有 zh / en 兩語系（少於三種），依 skill 每個文字 slot 另加一條人工長文案。常數定義於測試基座（W1-034），值如下：

| 常數 | 值 | 來源 |
|------|-----|------|
| `TestCopy.longZh` | 這是一段用於溢位測試的人工長文案，長度刻意超過任何畫面可容納的單行寬度，且除句號外不含任何空白或斷行機會，用來驗證截斷與換行處置是否依契約執行。 | 人工 |
| `TestCopy.longEn` | This is an artificially long test copy whose length deliberately exceeds any single-line width the layout can hold, used to verify that truncation and wrapping behave exactly as the content policy states. | 人工 |
| `TestCopy.longToken` | `Pneumonoultramicroscopicsilicovolcanoconiosis-supercalifragilisticexpialidocious-longest-unbreakable-token-for-ellipsis` | 人工（無斷字機會） |
| `TestCopy.nodeTitle` | 元件庫統一化（Extension 端）——ui-factory 升級為核心元件庫並對齊 APP 命名契約 | `test/fixtures/corpus/book_overview_app` PROP-016 title |
| `TestCopy.nodeId` | `DOMAIN-MAP-version-management` | 同上語料最長 id |
| `TestCopy.filePath` | `docs/spec/version-management/SPEC-016-version-management-data-contract.md` | 同上語料最長路徑（專案相對） |
| `TestCopy.status` | `implemented` | 語料 status 值中最長 |
| `TestCopy.domainName` | `version-management` | 語料 DOMAIN-MAP id 的 domain 段 |
| `TestCopy.ucName` | UC-09: Error Fingerprint 分群與調查 | `book_overview_app` 語料 UC 標題 |
| `TestCopy.stepName` | 版本不符拒絕渲染 | `docs/usecases/` 本專案 flow 步驟名最長 |
| `TestCopy.eventLabel` | consumes EVT-DIAGNOSTICS-001 | 本專案事件 ID 最長 + 前綴 |
| `TestCopy.projectName` / `TestCopy.projectSummary` | `book_overview_app` / 237 節點 · 2419 票 | `design/ProjectPickerD.dc.html` |
| `TestCopy.topicName` | markdown 顯示與編輯 | `docs/work-logs/topics-registry.txt` 最長 |
| `TestCopy.gapTitle` / `TestCopy.gapDescription` | 130 張 ticket 的 frontmatter 未閉合引號 / acceptance 欄位全數無法讀取 | `design/GapReportA.dc.html` |

ARB 值的「最長」以 zh 與 en 中字元數較多者為準，條目內直接寫 key 名並註明語系。

#### 4.0.5 測試形態與測試基座（L2 條文，提案）

測試形態為 widget test（`flutter test`），不做 golden；理由：golden 對 macOS 字型渲染敏感，CI 與本機差異會使紅燈失去診斷價值。每個元件一支測試檔，依條目「測試點」逐項斷言；視窗尺寸以 `tester.view.physicalSize` 設為 `kMinWindowSize` 與 `kDesignSize` 各跑一次。測試基座（尺寸切換、`TestCopy`、`ProviderScope` 包裝）由 `0.1.0-W1-034` 承接，為所有元件票的 blockedBy。

#### 4.0.6 i18n 標記約定與新 key 總表

下表為本檔宣告的新 key（原標「新 key」，已由 `0.1.0-W1-056` 建於 `lib/l10n/app_zh.arb`、`app_en.arb` 並重新產生 `app_localizations*.dart`，狀態改為已建）。條目 i18n 表中不再逐一標記「新 key」，既有 key 直接寫 key 名。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `expanderLabel` | 展開或收合 | Expand or collapse | — | 4.18 |
| `searchPlaceholder` | 搜尋 | Search | — | 4.12 |
| `searchClearAction` | 清除搜尋 | Clear search | — | 4.12 |
| `filterAllOption` | 全部 | All | — | 4.13 |
| `filterA11yLabel` | {label} 篩選，目前：{value} | {label} filter, current: {value} | label, value | 4.13 |
| `filterStatusLabel` / `filterPriorityLabel` | 狀態 / 優先 | Status / Priority | — | §4 畫面（4.13 呼叫端） |
| `sortA11yLabel` | {label}，可排序，目前：{order} | {label}, sortable, current: {order} | label, order | 4.14 |
| `sortNone` / `sortAscending` / `sortDescending` | 未排序 / 遞增 / 遞減 | Unsorted / Ascending / Descending | — | 4.14 |
| `columnId` / `columnTitle` / `columnStatus` / `columnPriority` / `columnStep` / `columnDomain` / `columnEvents` | ID / 標題 / 狀態 / 優先 / 步驟 / Domain / 發送事件 | ID / Title / Status / Priority / Step / Domain / Events | — | §2、§4 畫面（4.14 呼叫端） |
| `matrixCellA11yLabel` | {domain} × {uc}：{relation} | {domain} × {uc}: {relation} | domain, uc, relation | 4.15 |
| `legendDirect` / `legendIndirect` / `legendNone` | 直接貫穿 / 間接依賴 / 無關 | Direct / Indirect / None | — | 4.5（legend）、4.15、§1 畫面（W1-048） |
| `matrixSubtotalA11yLabel` | 小計 {count} | Subtotal {count} | count | 4.37 |
| `laneA11yLabel` | 泳道 {name} | Lane {name} | name | 4.38 |
| `laneNodeActive` / `laneNodeInactive` | 作用中 / 非作用中 | Active / Inactive | — | 4.16 |
| `stepNumberA11yLabel` | 步驟 {number} | Step {number} | number | 4.17 |
| `gapMarkerLabel` | 缺口 | Gap | — | 4.6（可見文字） |
| `damagedEdgeMarkerLabel` / `damagedDetailMarkerLabel` | 邊損壞 / 詳情損壞 | Edge damaged / Detail damaged | — | 4.6（朗讀） |
| `relationItemA11yLabel` | 關聯節點 {id} | Related node {id} | id | 4.19 |
| `currentProjectA11yLabel` | 目前專案 | Current project | — | 4.9 |
| `projectSummaryLabel` | {nodes} 節點 · {tickets} 票 | {nodes} nodes · {tickets} tickets | nodes, tickets | 4.9 |
| `healthBadgeA11yLabel` | {count} 個問題 | {count} issues | count | 4.5（health） |
| `switcherTitle` | 切換專案 | Switch project | — | 4.42 |
| `schemaAppVersionLabel` / `schemaProjectVersionLabel` | App 支援版本 / 專案版本 | Supported schema version / Project version | — | 4.23 |
| `treeDepthA11yLabel` | 第 {depth} 層 | Level {depth} | depth | 4.39 |
| `openExternallyA11yLabel` | 在外部開啟 | Opens externally | — | 4.40（`item`） |
| `loadingSkeletonA11yLabel` | 載入中 | Loading | — | 4.24 |
| `progressA11yLabel` | 進度 {parsed} / {total} | Progress {parsed} of {total} | parsed, total | 4.24 |
| `cellDetailPrompt` | 點選一格檢視詳情 | Select a cell to view details | — | §1 畫面（4.21 `section` 呼叫端；SPEC-003 §3.1） |
| `cellDetailNotInvolved` | 此 domain 不參與此 UC | This domain is not involved in this UC | — | §1 畫面（SPEC-003 §3.1） |
| `cellDetailCloseAction` | 關閉 | Close | — | §1 畫面（4.4 `text` 呼叫端） |
| `cellDetailViewInSwimlaneAction` | 在泳道中檢視 | View in swimlane | — | §1 畫面（4.4 `secondary` 呼叫端） |
| `modeMatrixLabel` / `modeSwimlaneLabel` / `modeListLabel` / `modeTopicLabel` | 矩陣 / 泳道 / 列表 / 主題 | Matrix / Swimlane / List / Topic | — | §1、§4 畫面（4.10 可見標籤；朗讀用既有 `*SwitchTo*Action`） |
| `ticketsSummaryLabel` | 顯示 {from}–{to} / 共 {total} | Showing {from}–{to} of {total} | from, to, total | §4 畫面（4.29 `footer` 呼叫端） |
| `ticketsVirtualScrollNote` | 虛擬捲動，不分頁 | Virtual scrolling, no pagination | — | §4 畫面 |
| `topicSectionSummary` | ({count} tasks, 最高優先級={priority}) | ({count} tasks, top priority={priority}) | count, priority | §4 畫面（4.40 `sectionHeader` 呼叫端） |
| `gapSectionCount` | {count} 項 | {count} items | count | §5 畫面（4.40 `sectionHeader` 呼叫端） |

畫面票另需的頁面副標等文案由畫面票自行宣告，不列於此。

#### 4.0.7 操作機制通用列（單一形態：桌機，§1）

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機（指標 + 鍵盤） | 點選（指標單擊；鍵盤 Tab 走到後 Space / Enter 觸發） | 命中一個不小於 `LayoutSize.hitTargetMin` 的目標 | 足夠 | 無（鍵盤路徑即替代） | 視覺（§1 回饋通道列；§4.0.1） |

「點選類」元件（按鈕、導覽項、格、列、展開器、分段控制、關聯項、專案項）的操作機制子節以「依 §4.0.7 點選列」一列代之；輸入類（搜尋框）、捲動與拖曳類（資料視圖容器）各自填寫。純顯示且無互動的元件填「不適用」並附理由。

#### 4.0.8 組合規則通用值

| 項目 | 值 |
|------|-----|
| 禁放區 | 無（§1 禁放區與安全區列；桌機視窗四角無觸控不靈敏問題） |
| 「可放入的容器」 | 只列本檔第 5 章的具名容器；不得直接放入頁面原生佈局（`Row` / `Column` / `Wrap` / `Flex` / `Stack`） |
| 對齊基準 | 水平列內預設「置中」（`CrossAxisAlignment.center`）；含多行文字的列以「文字基線」；條目只寫例外 |

#### 4.0.9 待決清單（元件封鎖表）

下列元件含「待決」欄位，依 skill〈契約齊全的定義〉不得被畫面票引用，決策票／前置票為其元件票的 blockedBy；票完成後由該票或後續 DOC 票去標。

| 條目 | 待決欄位 | 缺什麼 | 票 |
|------|---------|--------|-----|
| 4.13 `FilterDropdown` | 互動反應（選單開合、鍵盤）、狀態矩陣 `open` 列的退出路徑、無障礙播報 | SPEC-003 §3.4 未涵蓋 | `0.1.0-W1-057` |
| 4.14 `TableColumnHeader`（`sortable` 變體） | 互動反應（排序循環）、無障礙播報值 | SPEC-003 §3.4 未涵蓋 | `0.1.0-W1-057` |

其餘 40 條目無待決欄位，可被畫面票引用（含新 key 者以 `0.1.0-W1-056` 為元件票 blockedBy，已建，不構成待決）；`0.1.0-W1-055` 已建齊 6 項尺寸 token，原 6 條目自本清單去標（`matrixColumnWidth` 值已於 §3.7 第 24 項核定為 122）。

### 4.1 AppText

**用途**：所有可見文字的唯一載體，依字級 token 與語意角色渲染；容器的子件清單以此具名。
**內容角色**：標題（`title` / `subtitle`）、內文（`body`）、標籤（`caption`）、數值（`mono`）——每個變體恰一個文字 slot。
**何時不用**：文字需要可點（用 `AppButton.text` / `RelationItem` / `NavItem`）；文字是狀態或分類標記（用 `Badge`）；文字是 markdown 內文（用 `DocumentBody`）。
**出現畫面**：全部。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `title` | `AppFontSize.title`、`AppColors.textTitle`、粗體 | 單行 | 頁面標題、節點詳情主標 |
| `subtitle` | `AppFontSize.subtitle`、`AppColors.textTitle`、半粗 | 單行 | 面板標題、格詳情卡標題、泳道面板標題 |
| `body` | `AppFontSize.body`、`AppColors.textPrimary` | 可多行（`maxLines` 由呼叫端傳入，預設無上限） | 說明、內文、列主文字 |
| `caption` | `AppFontSize.caption`、`AppColors.textSecondary` | 單行 | 副標、欄首、小計、群組小標、次文字 |
| `mono` | `AppFontSize.body`、等寬字型、`AppColors.textPrimary` | 單行 | ID、路徑、版本值 |

修飾參數（非變體）：`emphasis`（粗體）、`secondary`（顏色改 `AppColors.textSecondary`）。等寬字型由 `ThemeData` 的 `fontFamily` 提供，元件內不寫死字型名（提案）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依變體渲染 | 無（純顯示） | 建構 | 不適用：無自身狀態集（純顯示元件，狀態只有 enabled） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 純顯示；0.1 不提供文字選取（`SelectableText`），避免與所在列的點擊競爭手勢（提案） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無任何互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（依文字內容）；置於容器的填滿格位時寬填滿父格位、高固有 |
| 最小尺寸 | 寬：一個字元 + 省略號可見；高：一行（§4.0.3 行高） |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | 寬無上限（由父格位夾住）；高：`body` 依 `maxLines`，其餘一行 |
| `kMinWindowSize` 下的行為 | 維持（約束由容器決定，§4.0.3） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `text`（`title`） | 否 | 1 | 截斷 | `TestCopy.nodeTitle`；`TestCopy.longToken` |
| `text`（`subtitle`） | 否 | 1 | 截斷 | `TestCopy.ucName`；`TestCopy.longZh` |
| `text`（`body`） | 是 | `maxLines`（預設無上限） | 換行；有 `maxLines` 時末行截斷 | `notFrameworkProjectExplanation`（zh 較長）；`TestCopy.longEn` |
| `text`（`caption`） | 否 | 1 | 截斷 | `noGapsScanScope`（en 較長）；`TestCopy.longZh` |
| `text`（`mono`） | 否 | 1 | 截斷 | `TestCopy.filePath`；`TestCopy.longToken` |

呼叫端不得傳入比本表更寬鬆的處置（`softWrap` / `overflow` 不開放為參數）；`body` 只開放 `maxLines`。

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `text` | `String` | 是 | 呼叫端（i18n key 取值，或資料文字） |
| `maxLines` | `int?`（僅 `body`） | 否 | 不適用 |
| `emphasis` / `secondary` | `bool` | 否 | 不適用 |
| `textAlign` | `TextAlign`（`start` / `end` / `center`） | 否 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textTitle` / `textPrimary` / `textSecondary` |
| 間距 | 無（內距由容器承載） |
| 字體 | `AppFontSize.title` / `subtitle` / `body` / `caption` |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| `text` | 呼叫端傳入；本元件無自有 key |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | 全部第 5 章容器 |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 依 §4.0.8；`textAlign` 只影響格位內的水平對齊 |
| 作為表格或列表的一欄時 | 欄寬由所在 `TableRow` 的欄規格決定（填滿欄或固定寬欄）；內距由該容器承載，本元件無內距 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 唸出 `text` 全文（截斷不影響朗讀）；`title` / `subtitle` 標記為 header（`Semantics.header`） |
| 狀態變化播報 | 文字更新時不主動播報；需要即時播報的呼叫端（載入計數，4.24）以 `liveRegion` 包裝 |
| 非視覺替代訊號 | `secondary` 修飾只弱化外觀、不承載語意，故無需替代訊號；語意由呼叫端的文案本身承載 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（非互動）；輔助技術依閱讀順序讀到 |
| 對比 | 依 §4.0.2 表 1：`textTitle` / `textPrimary` / `textSecondary` 對 `surfaceBase` 分別 17.20 / 5.79 / 4.71:1，皆通過；`caption` 與 `secondary` 修飾只得置於 `surfaceBase`（帶色表面規則），呼叫端置於帶色表面時改用預設字色 |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染五個變體 × `emphasis` / `secondary` 修飾
- [ ] `kMinWindowSize` 與 `kDesignSize` 下皆不溢位（置於寬度受限的父格位）
- [ ] 每個變體以本條目最長測試文案渲染，單行變體出現省略號、`body` 換行
- [ ] zh / en 兩語系值皆不溢位
- [ ] `title` / `subtitle` 的 `Semantics.header` 為 `true`
- [ ] 字級與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 可點的文字連結 | `AppButton.text` / `RelationItem` |
| 狀態、類別、計數標記 | `Badge` |
| 節點詳情的 markdown 內文 | `DocumentBody` |
| 表格欄首 | `TableColumnHeader` |

### 4.2 AppIcon

**用途**：語意圖示（資料夾、六個導覽圖示、展開箭頭、外開箭頭、損壞、搜尋、關閉）；尺寸只取具名階。
**內容角色**：標籤（圖形化）。
**何時不用**：圖示本身可點（包進 `AppButton.text` 或所屬元件）；圖示承載展開狀態（用 `ExpanderIcon`）；圖示承載問題標記（用 `IssueMarker`）。
**出現畫面**：殼、§3、§4、§5、§6、§7。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| 不適用 | 尺寸階（`sm` / `md` / `lg`）與顏色為參數，非變體（原子元件，同一語意無行為差異） | | |

圖示來源：Material Icons（`IconData`；沿用 `lib/app/shell.dart` 既有慣例；畫布內聯 SVG 為產生器輸出，不視為圖示集決策，提案）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依 `icon` / `size` / `color` 渲染 | 無 | 建構 | 不適用：純顯示元件，無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 純顯示；可點需求由所屬元件承載 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無任何互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（正方形） |
| 最小尺寸 | `LayoutSize.iconSm` × `LayoutSize.iconSm` |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | `LayoutSize.iconLg` × `LayoutSize.iconLg` |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `icon` | `IconData` | 是 | 不適用 |
| `size` | `IconSize { sm, md, lg }` → `LayoutSize.icon*` | 否（預設 `md`） | 不適用 |
| `color` | `Color`（限 `AppColors.*`） | 否（預設 `AppColors.textPrimary`） | 不適用 |
| `semanticLabel` | `String?` | 否；`null` 即裝飾性，排除於語意樹 | 呼叫端（i18n key 取值） |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textPrimary` / `textSecondary` / `textDisabled`（停用態與純裝飾箭頭，§4.0.2 表 2）/ `accent` / `accentStrong` / `error` |
| 間距 | 無 |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| `semanticLabel` | 呼叫端傳入；本元件無自有 key |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `ListRow`（leading / trailing）、`Toolbar`、`SplitRow`；作為 `NavItem` / `ProjectSwitcherEntry` / `RecentProjectItem` / `AppButton.text` / `SearchField` / `IssueMarker` 的內部 slot |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於所在列 |
| 作為表格或列表的一欄時 | 固定寬 = 尺寸階；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `semanticLabel` 非 `null` 時唸出該值；`null` 時排除於語意樹（裝飾性） |
| 狀態變化播報 | 不播報（無狀態） |
| 非視覺替代訊號 | 圖示不得為唯一訊號：帶語意的圖示旁必有文字（同一元件的文字 slot）或 `semanticLabel` |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序 |
| 對比 | 依 §4.0.2（圖示色與底色組合同文字） |

#### 測試點（widget test）

- [ ] 一支測試渲染三個尺寸階 × 主要顏色
- [ ] 兩種視窗尺寸下尺寸不變（不隨視窗縮放）
- [ ] 無文字 slot（本項不適用）
- [ ] `semanticLabel` 為 `null` 時語意樹無節點，非 `null` 時節點 label 等於該值
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 可點的圖示按鈕 | `AppButton.text`（帶 leading icon，label 必填） |
| 樹或分節的展開箭頭 | `ExpanderIcon` |
| 損壞或缺口標記 | `IssueMarker` |

### 4.3 Divider

**用途**：區隔垂直堆疊中的群組（節點詳情主欄標籤列與內文之間、浮層清單與「選擇其他」之間）。
**內容角色**：容器修飾（無內容角色）。
**何時不用**：分節之間的分隔（由 `Section` 的節間距或頂部虛線修飾承載）；表格列之間（由 `TableRow` 底邊框承載）；側欄與主區之間（`AppShell` 內部）。
**出現畫面**：§6、§7。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| 不適用 | 原子元件，單一外觀（實線 `AppColors.border`） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 水平實線 | 無 | 建構 | 不適用：純顯示，無狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 無互動 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無任何互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固有 |
| 最小尺寸 | 寬 0（隨父）× 高 = 線寬（§4.0.3 邊框線寬） |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬無上限 × 高 = 線寬 |
| `kMinWindowSize` 下的行為 | 維持（寬隨父） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| 不適用 | 無 slot（原子元件） | | |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border` |
| 間距 | 無（上下留白由所在容器的最小間距承載） |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel`、`SwitcherOverlay` |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 填滿寬，垂直置於容器最小間距之中 |
| 作為表格或列表的一欄時 | 不適用（不作欄） |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 排除於語意樹（`ExcludeSemantics`），裝飾性 |
| 狀態變化播報 | 不播報（無狀態） |
| 非視覺替代訊號 | 群組分隔另由群組小標（`AppText.caption`）或 header 語意承載，分隔線非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序 |
| 對比 | 裝飾性元素，不受 SC 1.4.3 約束（依 §4.0.2 不計） |

#### 測試點（widget test）

- [ ] 一支測試渲染單一狀態（無變體）
- [ ] 兩種視窗尺寸下寬等於父寬、高等於線寬
- [ ] 無文字 slot（本項不適用）
- [ ] 語意樹無節點
- [ ] 顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「未歸屬」節的頂部虛線 | `Section` 的虛線修飾參數 |
| 表格列分隔 | `TableRow` 底邊框（容器承載） |
| 側欄／主區分隔 | `AppShell` 內部邊框 |

### 4.4 AppButton

**用途**：SPEC-001「可用操作」欄所有有視覺承載的動作（十四種 + 格詳情卡兩種）。
**內容角色**：動作（一個 label slot，`text` 變體另有可選 leading icon）。
**何時不用**：切換工作區（`NavItem`）；開啟關聯節點（`RelationItem`）；雙模式切換（`SegmentedControl`）；非互動標記（`Badge`）；可點的問題標記（`IssueMarker`）。
**出現畫面**：§1–§7。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `primary` | 底 `AppColors.accent`、字 `AppColors.surfaceBase` | 無 | 前進／主要動作：選擇資料夾、開始載入、重新整理（`MissingSourceState`）、前往破洞報告、前往追溯視圖 |
| `secondary` | 底 `AppColors.surfaceBase`、邊框 `AppColors.borderStrong`、字 `AppColors.textPrimary` | 無 | 取消、返回、返回 Domain 視圖、重新掃描、開啟原始檔、檢視關聯、檢視詳情、在泳道中檢視、開啟 docs 目錄 |
| `text` | 無底無框、字 `AppColors.accent`；可帶 leading `AppIcon` | 無 | 低強調：浮層「選擇其他」、格詳情卡「關閉」 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| enabled | 依變體 | 點選（指標 / Space / Enter） | `enabled` 為 `true` | 呼叫端改 `enabled` → disabled |
| hover / pressed / focused | 依 §4.0.1 | 同上 | 指標進入 / 按下 / 取得焦點 | 指標離開 / 放開 / 焦點移走 |
| disabled | 依 §4.0.1；`disabledReason` 以 `AppText.caption` 顯示於 label 右側（同列常駐文字，SPEC-003 §2.2） | 無 | `enabled` 為 `false`（此時 `disabledReason` 必填） | 呼叫端改 `enabled` → enabled |

無 loading 狀態：等待指示為畫面級（SPEC-003 §2.2），按鈕內不放 spinner。取消鈕按下後的「取消中」由 4.24 `LoadingState` 以 `enabled=false` + label 換文案承載，不是本元件的狀態。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選（enabled） | 呼叫 `onPressed` 一次；pressed 態可見 | Material 內建 ripple（§4.0.1） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2） |
| 點選（disabled） | 無反應、無 SnackBar（SPEC-003 FR-06 的合法形態 b） | — | — |
| 鍵盤 Space / Enter（focused） | 同點選 | — | 同上 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（label 寬 + 水平內距 2 × `Space.md`；`text` 變體帶圖示時加 `LayoutSize.iconMd` + `Space.xs`） |
| 最小尺寸 | 寬：`LayoutSize.hitTargetMin`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（高恆等於之；寬不小於之） |
| 最大尺寸 | 寬：父格位寬（超出時 label 截斷）；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（約束由 `ButtonRow` 決定，空間不足時由容器換行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `gotoTraceabilityAction`（en「Go to Traceability View」）；`TestCopy.longToken` |
| `disabledReason` | 否 | 1 | 截斷 | `projectUnavailableReasonLabel`（reason 代入 `probeTimeoutReason`，zh 較長）；`TestCopy.longZh` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是（禁止 icon-only） | 呼叫端（i18n key 取值） |
| `leading` | `AppIcon?`（僅 `text` 變體） | 否 | 不適用 |
| `onPressed` | `VoidCallback` | 是 | 不適用 |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `disabledReason` | `String?` | `enabled` 為 `false` 時必填 | 呼叫端（i18n key 取值） |
| `testKey` | `Key` | 是（SPEC-003 §2.9 `action-<screen>-<action>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.accent` / `surfaceBase` / `borderStrong` / `textPrimary` / `textDisabled`（disabled 的 label 與 icon，§4.0.1）/ `textSecondary`（`disabledReason` 經 `AppText.caption`） |
| 間距 | 內距 `Space.md`（水平）× `Space.sm`（垂直）；圖示與 label 間 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`（pressed 可見上限） |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | 呼叫端傳入（既有：`chooseWorkspaceFolder`、`cancelLoadingAction`、`cancelScanAction`、`cancelInProgressAction`、`startLoadAction`、`backAction`、`backToDomainAction`、`refreshAction`、`rescanAction`、`openSourceFileAction`、`openDocsFolderAction`、`viewRelationsAction`、`viewSchemaDetailAction`、`gotoGapsReportAction`、`gotoTraceabilityAction`、`switcherChooseOtherFolder`；`cellDetailCloseAction`、`cellDetailViewInSwimlaneAction`） |
| `disabledReason` | 呼叫端傳入 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `ButtonRow`、`SwitcherOverlay`（`text` 變體，末格）、`SplitRow.header` 右格（經 `ButtonRow`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於所在列 |
| 作為表格或列表的一欄時 | 不適用（0.1 無表格內按鈕） |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button` 為 `true`，label 等於 `label` 值；`text` 變體的 leading icon 排除於語意樹 |
| 狀態變化播報 | `enabled` 改變時語意樹 `enabled` 旗標同步；`disabledReason` 以 `Semantics.hint` 附於同一節點 |
| 非視覺替代訊號 | 變體差異不承載語意（皆為動作），故顏色非唯一訊號；disabled 由 `enabled` 旗標與常駐文字承載 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（SPEC-003 §2.10 內容區段）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2：`primary` 字 `surfaceBase` / `accent` 5.84:1、`secondary` 與 `text` 字 `textPrimary` / `surfaceBase` 5.79:1、`disabledReason` `textSecondary` / `surfaceBase` 4.71:1，皆通過；disabled 的 label 與 icon `textDisabled` 3.06:1 屬非作用中元件豁免（表 2） |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染三個變體 × enabled / disabled（disabled 含 `disabledReason`）
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案：label 截斷、`disabledReason` 截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] enabled 點擊呼叫 `onPressed` 恰一次；disabled 點擊零次且無 SnackBar；Space / Enter 等價
- [ ] 元件樹中被 `ButtonStyleButton` 或 `InkWell` 包覆（SPEC-003 §2.2 斷言）
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 圖示按鈕（無文字） | 禁止；`text` 變體帶 leading icon 且 label 必填 |
| 切換畫面的導覽 | `NavItem` |
| 雙模式切換 | `SegmentedControl` |
| 可點的損壞計數 | `IssueMarker.damagedDetail` |

### 4.5 Badge

**用途**：非互動的標籤／數值標記（計數、狀態、型別、類別、事件、標籤、圖例、健康計數）。
**內容角色**：標籤（`label` slot）；`count` / `health` 為數值（`count` slot）；`legend` 另有符號 slot。
**何時不用**：標記可點（`IssueMarker`）；可執行動作（`AppButton`）；一般文字（`AppText`）；泳道格內的動作標籤（`SwimlaneNode`）。
**出現畫面**：§1–§7。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `count` | 數字；預設 tone `negative` | 無 | 損壞計數（作為 `IssueMarker.damagedDetail` 的內部 slot） |
| `status` | 文字；tone 依狀態值對映（下表） | 無 | 票列狀態、節點 draft chip、樹列狀態 |
| `type` | 文字；tone `neutral` | 無 | PROP / SPEC / UC / Ticket 型別 |
| `category` | 文字；tone 由呼叫端指定 | 無 | 破洞類別（畫布：資料損壞 `negative`、追溯缺口 `warning`、圖結構 `neutral`） |
| `event` | 文字（含 `emits` / `consumes` 前綴）；tone 預設 `accent`，呼叫端可改 `negative` | 無 | 事件標籤 |
| `tag` | 文字；tone `neutral` | 無 | domain: schema、N 個 FR |
| `legend` | 符號 slot + 文字，無底色；符號色依關係種類 | 無 | 矩陣與泳道圖例 |
| `health` | 數字；tone `negative` | 無 | 專案健康計數（`badge-switcher-health-<index>`） |

**tone（語意色參數，非變體）**：`neutral`（底 `AppColors.surfaceChip`、字 `textPrimary`）/ `accent`（底 `surfaceIconTint`、字 `accentStrong`）/ `positive`（底 `surfaceChip`、字 `success`；提案，畫布只有 inline 形態）/ `warning`（底 `warningSurface`、字 `warning`）/ `negative`（底 `errorSurface`、字 `error`）。
**外觀由容器格位決定（§3.7 第 5 項）**：置於 `TableRow` 格位時為 inline（無底色、只取 tone 字色）；其餘為 chip（底色 + `Radius.sm`）。
**`status` 的 tone 對映（提案；畫布：draft / pending 為 warning，completed 為 positive）**：`completed` / `confirmed` / `approved` / `implemented` / `baseline` → `positive`；`draft` / `pending` / `review` / `in_progress` → `warning`；`rejected` / `superseded` / `revised` 與未列值 → `neutral`。對映表為元件常數，呼叫端不覆寫。原 `secondary` tone（底 `surfaceChip`、字 `textSecondary`）於 `0.1.0-W1-060` 刪除：`textSecondary` / `surfaceChip` 4.02:1 未達 AA，改 `textPrimary` 後與 `neutral` 無差異（§4.0.2 帶色表面規則）；終止類狀態與未列值同以文字承載語意，不另設色。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依變體 / tone / 格位 | 無（非互動；點擊不產生反應且不呈按鈕形態，SPEC-003 §3.7） | 建構 | 不適用：純顯示元件，無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點擊 | 無反應、無 pressed 態（SPEC-003 §3.7 健康徽章斷言，全變體適用） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且明訂無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸 |
| 最小尺寸 | chip：文字寬 + 2 × `Space.sm` × （`AppFontSize.caption` 行高 + 2 × `Space.xxs`）；inline：文字固有 |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | 寬：父格位寬（超出時文字截斷）；高：一行 |
| `kMinWindowSize` 下的行為 | 維持（約束由 `BadgeRow` 換行或 `TableRow` 格位承載） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label`（`status` / `type` / `category` / `event` / `tag` / `legend`） | 否 | 1 | 截斷 | `TestCopy.eventLabel`（event）、`TestCopy.status`（status）、`legendIndirect`（zh「間接依賴」）；`TestCopy.longToken` |
| `count`（`count` / `health`） | 否 | 1 | 不截斷（數字固有寬；`corruptedTicketsBadge` 形態由呼叫端組字） | `corruptedTicketsBadge`（count 代入 2419，zh 較長）；人工值 `99999` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 非數值變體必填 | 呼叫端（i18n key 取值或資料值；`status` 的顯示文字為資料值原文） |
| `count` | `int` | `count` / `health` 必填 | 不適用（數字格式符號可內嵌） |
| `symbol` | `String`（`●` / `○` / `·`）| `legend` 必填 | 不適用（非語意排版字元） |
| `tone` | `BadgeTone` | `category` 必填；其餘有預設 | 不適用 |
| `semanticLabel` | `String?` | `count` / `health` 必填 | 呼叫端（i18n key 取值；health 用 `healthBadgeA11yLabel`） |
| `testKey` | `Key?` | health 必填（`badge-switcher-health-<index>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceChip` / `surfaceIconTint` / `warningSurface` / `errorSurface`（底）；`textPrimary` / `accentStrong` / `success` / `warning` / `error`（字，五個 tone）；legend 符號 `accent` / `textSecondary` / `borderStrong`（符號非文字，`textSecondary` / `surfaceBase` 4.71:1） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xxs`（垂直）；legend 符號與文字間 `Space.xs` |
| 字體 | `AppFontSize.caption`、半粗 |
| 圓角 | `Radius.sm` |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | 呼叫端傳入；legend 用 `legendDirect` / `legendIndirect` / `legendNone` |
| `semanticLabel`（health） | `healthBadgeA11yLabel` |
| `count` 的組字（損壞計數） | `corruptedTicketsBadge`（既有，由 `IssueMarker` 呼叫端組字） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `BadgeRow`、`TableRow`（格位）、`ListRow`（leading / trailing）、`Section`（節首經 `ListRow.sectionHeader`）；作為 `RecentProjectItem` / `IssueMarker.damagedDetail` 的內部 slot |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於所在列；inline 形態以文字基線 |
| 作為表格或列表的一欄時 | 固定寬欄（`TableRow.ticket` 狀態欄，`LayoutSize.ticketStatusColumnWidth`）；inline 形態；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 唸出 `label`（legend 唸文字不唸符號）；`count` / `health` 唸 `semanticLabel` |
| 狀態變化播報 | 不播報（值變更由所在列重建，非即時區域） |
| 非視覺替代訊號 | tone 顏色非唯一訊號：`status` 的文字即狀態值、`category` / `event` 的文字即語意、`legend` 的符號另有文字說明 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（非互動，`Semantics.button` 為 `false`） |
| 對比 | 依 §4.0.2 表 1：`neutral` `textPrimary` / `surfaceChip` 4.94:1、`accent` `accentStrong` / `surfaceIconTint` 8.38:1、`positive` `success` / `surfaceChip` 5.18:1、`warning` `warning` / `warningSurface` 5.29:1、`negative` `error` / `errorSurface` 5.58:1，皆通過；inline 形態（`TableRow` 內，底 `surfaceBase`）各字色對 `surfaceBase` 皆不低於 chip 形態 |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染八個變體 × 六種 tone × chip / inline 兩形態
- [ ] 兩種視窗尺寸下不溢位（置於寬度受限的 `BadgeRow`）
- [ ] 最長測試文案：`label` 截斷、`count` 不截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] 點擊不產生任何反應、元件樹無 `InkWell` / `ButtonStyleButton` 包覆
- [ ] `status` 對映表：每個列名值得到指定 tone，未列值為 `neutral`
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 可點的損壞計數（`badge-tickets-corrupted`） | `IssueMarker.damagedDetail` |
| 泳道格內的動作標籤 | `SwimlaneNode` |
| 篩選觸發器（「狀態：pending」） | `FilterDropdown` |
| 群組小標 | `AppText.caption` |

### 4.6 IssueMarker

**用途**：修飾既有節點或欄位的問題標記，可點擊跳轉破洞報告（SPEC-001 FR-05 兩級損壞 + 追溯缺口）。
**內容角色**：標籤 + 動作（`gap` 另有可見文字 slot；`damagedDetail` 有可選說明與計數 slot）。
**何時不用**：非互動的狀態標籤（`Badge`）；一般動作（`AppButton`）。
**出現畫面**：§3（`gap`）、§4（`damagedDetail`）、§6（`damagedEdge`、欄位級 `damagedDetail`）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `damagedEdge` | 包住 `child`：虛線框 `AppColors.error`，child 文字色維持 `AppColors.textPrimary`（規格「虛線框／降低不透明度」取虛線框，不引入不透明度值，提案；原提案改 `textSecondary` 於 `0.1.0-W1-060` 撤回：child 底為 `surfaceChip`，4.02:1 未達 AA，損壞語意已由虛線框與朗讀標籤承載） | 點擊 → jump 破洞報告 | 邊損壞（`RelationItem.damaged`） |
| `damagedDetail` | `AppIcon`（warning 圖示，`AppColors.error`）+ 可選 `Badge.count` + 可選說明 `AppText.caption` | 點擊 → jump 破洞報告（`badge-tickets-corrupted`、`action-nodeDetail-goto-gaps`）；票列末欄的圖示形態亦可點（同結果） | 詳情損壞：工具列右側計數、票列末欄圖示、節點詳情欄位級標示 |
| `gap` | 虛線框 `AppColors.error` + 文字 `gapMarkerLabel`（`AppColors.error`） | 點擊 → jump 破洞報告（`badge-traceability-broken-<layer>`） | 追溯缺口層 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依變體 | 點選 | 建構（存在即代表有問題） | 由呼叫端移除（問題消失） |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

無 disabled：跳轉破洞報告恆可用（SPEC-001 §3、§4、§6 退出路徑）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選 | 呼叫 `onTap`；呼叫端執行 jump 至 `nav-page-gaps`，`returnTo` 設為來源畫面（SPEC-003 §3.3、§3.4、§3.6） | Material 內建 pressed | `Motion.feedback` |
| 顯示 | 靜態，不做閃爍或呼吸動畫（SPEC-003 §3.3「缺口虛線框靜態」、§3.4「損壞徽章無入場動畫」） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸；`damagedEdge` 依 child |
| 最小尺寸 | `LayoutSize.hitTargetMin` × `LayoutSize.hitTargetMin`（圖示形態以透明命中區補足，§4.0.3） |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：父格位寬（說明文字截斷）；高：一行 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label`（`gap`） | 否 | 1 | 截斷 | `gapMarkerLabel`（zh「缺口」/ en「Gap」）；`TestCopy.longZh` |
| `explanation`（`damagedDetail`，欄位級） | 否 | 1 | 截斷 | `fieldCorruptedMessage`（en 較長）；`TestCopy.longEn` |
| `count`（`damagedDetail`，經 `Badge.count`） | 否 | 1 | 不截斷 | `corruptedTicketsBadge`（count 代入 2419） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `child` | `RelationItem`（`damagedEdge`） | `damagedEdge` 必填 | 不適用 |
| `count` | `int?`（`damagedDetail`） | 否 | 不適用 |
| `explanation` | `String?`（`damagedDetail`） | 否 | 呼叫端（`fieldCorruptedMessage`） |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`badge-tickets-corrupted` / `badge-traceability-broken-<layer>` / 欄位級 `action-nodeDetail-goto-gaps`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.error`（框、圖示、文字）、`errorSurface`（計數底）；`damagedEdge` child 文字色不覆寫（維持 child 自身的 `textPrimary`） |
| 間距 | 圖示與計數／說明間 `Space.xs`；框內距 `Space.xxs` |
| 字體 | `AppFontSize.caption` |
| 圓角 | `Radius.sm` |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `gap` 可見文字 | `gapMarkerLabel` |
| 朗讀標籤 | `damagedEdgeMarkerLabel` / `damagedDetailMarkerLabel` |
| 計數組字 | `corruptedTicketsBadge`（既有） |
| 欄位級說明 | `fieldCorruptedMessage`（既有，呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Toolbar`（末格）、`TableRow.ticket`（末欄）、`ListRow`（trailing；`tree` 變體的缺口列）、`Panel`（節點詳情欄位級，與被標示欄位同列經 `ListRow.meta`）、`Section.static`（關聯群內包住 `RelationItem`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於所在列 |
| 作為表格或列表的一欄時 | 固定寬欄（`TableRow.ticket` 標記欄，`LayoutSize.ticketMarkerColumnWidth`）；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button` 為 `true`；label：`damagedEdge` 為「{child 標籤}，`damagedEdgeMarkerLabel`」、`damagedDetail` 為「`damagedDetailMarkerLabel`，{count 或 explanation}」、`gap` 為 `gapMarkerLabel` |
| 狀態變化播報 | 不播報（靜態標記，出現即隨列重建） |
| 非視覺替代訊號 | 虛線框與紅色非唯一訊號：三變體皆有文字或圖示 + 朗讀標籤 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：`error` / `surfaceBase` 6.54:1、`error` / `errorSurface` 5.58:1、`damagedEdge` child `textPrimary` / `surfaceChip` 4.94:1，皆通過 |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染三個變體（`damagedDetail` 含計數 / 說明 / 純圖示三形態）
- [ ] 兩種視窗尺寸下不溢位；命中區不小於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案：`gap` 文字與 `explanation` 截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] 點擊呼叫 `onTap` 恰一次；元件樹被 `InkWell` 包覆
- [ ] 渲染後 `pump(Motion.skeletonCycle)` 期間外觀不變（靜態斷言）
- [ ] 顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 非互動的狀態標籤 | `Badge.status` |
| 「找不到檔案」的暫時提示 | `AppSnackBar` |
| 原始檔已消失的全區狀態 | `MissingSourceState` |

### 4.7 NavItem

**用途**：側欄六項導覽，`nav-item-<destination>`（既有錨點，不改名）。
**內容角色**：動作 + 標籤（icon slot + label slot）。
**何時不用**：畫面內跳轉（`AppButton` / `RelationItem`，jump 語意）；專案切換入口（`ProjectSwitcherEntry`）。
**出現畫面**：殼。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（selected / unselected 為狀態） | | 六項皆同 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| unselected | 無底色；icon 與 label `AppColors.textPrimary` | 點選 | `isSelected` 為 `false` | 點選本項 → selected |
| selected | 底 `AppColors.surfaceIconTint`、icon 與 label `AppColors.accentStrong`、label 半粗（畫布為準；`lib/app/shell.dart` 的 `surfaceChip` 屬漂移，W1-005 對齊） | 點選（無狀態改變） | `isSelected` 為 `true` | 點選他項 → unselected |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

無 disabled：六項導覽恆可用（SPEC-003 §2.3）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選 | 呼叫 `onTap`；呼叫端執行 rail 切換：`nav-page-<d>` 成為可見頁、`returnTo` 設為 `null`（SPEC-003 §1.2、§2.3 規則 1） | Material 內建 pressed；頁面切換無轉場動畫（`IndexedStack`） | `Motion.feedback` |
| 點選已選項 | 無狀態改變 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，側欄內距內）；高固有 |
| 最小尺寸 | 寬：`LayoutSize.iconLg` + `Space.sm` + 一字元；高：`LayoutSize.iconLg` + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`） |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：`LayoutSize.sidebarWidth` − 2 × `Space.sm`；高同最小 |
| `kMinWindowSize` 下的行為 | 維持（側欄寬固定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `navNodeDetail`（en「Node Detail」）/ `navTickets`（zh「Ticket 清單」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `icon` | `AppIcon`（`lg`，裝飾性，`semanticLabel` 為 `null`） | 是 | 不適用 |
| `label` | `String` | 是 | 呼叫端（`navDomain` / `navUcFlow` / `navTraceability` / `navTickets` / `navGaps` / `navNodeDetail`） |
| `isSelected` | `bool` | 是 | 不適用 |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`nav-item-<destination>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceIconTint`（selected 底）、`accentStrong`（selected 字與 icon）、`textPrimary` |
| 間距 | 內距 `Space.sm`（水平 `Space.md`）；icon 與 label 間 `Space.sm` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | 呼叫端傳入（六個 `nav*` 既有 key） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `AppShell`（側欄 slot，恰六個） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button` 為 `true`、label 等於 `label`、`selected` 等於 `isSelected` |
| 狀態變化播報 | `selected` 旗標改變即由輔助技術播報（原生旗標，不另組字） |
| 非視覺替代訊號 | 選中態同時以底色、字重與 `selected` 旗標承載，顏色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | Tab 第二區段（六項依序，SPEC-003 §2.10）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2（`accentStrong` / `surfaceIconTint` 通過；`textPrimary` / `surfaceSidebar` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染 selected / unselected 兩狀態
- [ ] 兩種視窗尺寸下不溢位；高不小於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en 六個 key 皆不溢位
- [ ] 點選呼叫 `onTap` 恰一次；`Semantics.selected` 與 `isSelected` 一致
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 畫面內的「前往破洞報告」 | `AppButton.primary`（jump，設 `returnTo`） |
| 專案切換入口 | `ProjectSwitcherEntry` |
| 雙模式切換 | `SegmentedControl` |

### 4.8 ProjectSwitcherEntry

**用途**：側欄頂端的專案切換入口：資料夾圖示 + 目前專案名（單行截斷）+ 展開箭頭；`project-switcher-entry`（既有錨點）。等於 SPEC-001 §7「收合」態。
**內容角色**：動作 + 標籤（專案名 slot）。
**何時不用**：畫面切換（`NavItem`）；浮層內的專案項（`RecentProjectItem`）。
**出現畫面**：殼。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| collapsed | 圖示 + 專案名（無專案時顯示 `projectSwitcherEntryLabel`）+ 向下箭頭 | 點選 → 展開浮層 | 浮層未展開（常態） | 點選 → expanded |
| expanded | 同上，箭頭朝上；本元件維持可見（浮層自其下方展開） | 點選 → 收合浮層 | `SwitcherOverlay` 展開中 | Esc / 點外部 / 選取專案 → collapsed（SPEC-003 §3.7） |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

無 disabled：三個阻擋狀態下 `enabled` 恆為 `true`（SPEC-003 §2.7 浮層可用性斷言）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選（collapsed） | 呼叫 `onTap`；`state-switcher-collapsed` 消失、`state-switcher-expanded` 或 `state-switcher-no-recent` 出現（SPEC-003 §3.7） | 浮層淡入 + 向下展開 `Motion.overlay`（由 `SwitcherOverlay` 承載） | pressed 態 `Motion.feedback` |
| 點選（expanded） | 浮層收合 | `Motion.overlay` | 同上 |
| Esc（浮層展開時） | 浮層收合，焦點回到本元件（SPEC-003 §2.10） | `Motion.overlay` | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，側欄內距內）；高固有 |
| 最小尺寸 | 寬：`LayoutSize.iconLg` + 2 × `Space.sm` + 一字元 + `LayoutSize.iconMd`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：`LayoutSize.sidebarWidth` − 2 × `Space.sm`；高同最小 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `projectName` | 否 | 1 | 截斷 | `TestCopy.projectName`；`TestCopy.longToken`；無專案時 `projectSwitcherEntryLabel`（en「Switch project」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `projectName` | `String?` | 否；`null` 時顯示元件預設 key | 呼叫端（資料值）／元件預設 `projectSwitcherEntryLabel`（強語意預設，參數可覆蓋） |
| `isExpanded` | `bool` | 是 | 不適用 |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`project-switcher-entry`，`AppShell.projectSwitcherEntryKey`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.accent`（資料夾圖示）、`textTitle`（專案名）、`textDisabled`（展開箭頭，純裝飾，§4.0.2 表 2）、`surfaceSidebar`（底）、`border`（框線） |
| 間距 | 內距 `Space.sm`；圖示與文字間 `Space.sm` |
| 字體 | `AppFontSize.body`、半粗 |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`、`Motion.overlay`（浮層） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 無專案時的預設文字與朗讀標籤 | `projectSwitcherEntryLabel`（既有） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `AppShell`（側欄頂端 slot，恰一個） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button` 為 `true`；label 為「`projectSwitcherEntryLabel`，{projectName}」；`expanded` 等於 `isExpanded` |
| 狀態變化播報 | `expanded` 旗標改變由輔助技術播報；專案名改變隨重建唸出 |
| 非視覺替代訊號 | 展開狀態由箭頭方向與 `expanded` 旗標承載 |
| 焦點順序與操作路徑（桌機） | Tab 第一區段（SPEC-003 §2.10）；Space / Enter 展開；浮層 Esc 後焦點回到本元件 |
| 對比 | 依 §4.0.2：`textTitle` / `surfaceSidebar` 15.85:1、`accent` / `surfaceSidebar` 5.38:1，通過；箭頭 `textDisabled` / `surfaceSidebar` 2.82:1 為純裝飾（展開狀態由 `expanded` 旗標承載，表 2 允許） |

#### 測試點（widget test）

- [ ] 一支測試渲染 collapsed / expanded × 有專案名 / 無專案名
- [ ] 兩種視窗尺寸下不溢位；高不小於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en 預設 key 值皆不溢位
- [ ] 點選呼叫 `onTap` 恰一次；`Semantics.expanded` 與 `isExpanded` 一致；`enabled` 恆為 `true`
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 阻擋狀態內的「切換專案」出口按鈕 | `AppButton.primary`（其 `onPressed` 開啟同一浮層） |
| 浮層內的專案項 | `RecentProjectItem` |

### 4.9 RecentProjectItem

**用途**：浮層內單一專案選項：圖示 + 名稱 + 摘要（節點數 · 票數）+ 健康徽章 slot + 不可用原因常駐文字；`card-switcher-recent-<index>`。
**內容角色**：動作 + 標籤（名稱）+ 內文（摘要、原因）+ 數值（健康計數，經 `Badge.health`）。
**何時不用**：側欄入口（`ProjectSwitcherEntry`）；一般清單列（`ListRow`）。
**出現畫面**：§7。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（enabled / disabled / selected 為狀態） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| enabled | 圖示 `AppColors.textSecondary`、名稱 `textTitle`、摘要 caption | 點選 → 切換至該專案 | 可用性探測成功 | 點選 → 浮層收合（本元件隨浮層消失） |
| selected（目前專案） | 底 `AppColors.surfaceIconTint`、圖示與名稱 `accentStrong`（畫布為準）、摘要 `textPrimary`（§4.0.2 帶色表面規則：`textSecondary` / `surfaceIconTint` 3.98:1 未達 AA，`0.1.0-W1-060` 改） | 點選（重載同一專案，SPEC-003 §3.7 未區分，視同選取） | 為目前開啟的專案 | 同上 |
| disabled | 依 §4.0.1；同列常駐 `reason` 文字（不用 tooltip，SPEC-003 §3.7） | 無 | 探測失敗或逾時（reason 含 `probeTimeoutReason`） | 探測結果更新 → enabled（其餘項不受本項探測影響） |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選（enabled / selected） | 呼叫 `onTap`；呼叫端執行：浮層收合 → 六頁重置 → `state-domain-loading`（SPEC-003 §3.7，兩段不重疊） | 浮層收合 `Motion.overlay`；pressed 內建 | `Motion.feedback` |
| 點選（disabled） | 無反應（FR-06 合法形態 b） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，浮層內距內）；高固有 |
| 最小尺寸 | 寬：`LayoutSize.iconLg` + `Space.sm` + 一字元；高：`AppFontSize.body` 行高 + `Space.xxs` + `AppFontSize.caption` 行高 + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`） |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：`LayoutSize.overlayWidth` − 2 × `Space.sm`；高：最小高 + `reason` 兩行 |
| `kMinWindowSize` 下的行為 | 維持（浮層寬固定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `name` | 否 | 1 | 截斷 | `TestCopy.projectName`；`TestCopy.longToken` |
| `summary` | 否 | 1 | 截斷 | `projectSummaryLabel`（nodes 237、tickets 2419；en 較長）；`TestCopy.longEn` |
| `reason`（disabled） | 是 | 2 | 末行截斷（提案：浮層寬有限，原因須可讀） | `projectUnavailableReasonLabel`（reason 代入 `probeTimeoutReason`）；`TestCopy.longZh` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `name` | `String` | 是 | 呼叫端（資料值） |
| `summary` | `String` | 是 | 呼叫端（`projectSummaryLabel` 取值） |
| `health` | `Badge.health?` | 否（問題數為 0 時不傳） | 不適用 |
| `enabled` / `isCurrent` | `bool` | 是 | 不適用 |
| `reason` | `String?` | `enabled` 為 `false` 時必填 | 呼叫端（`projectUnavailableReasonLabel` 取值） |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`card-switcher-recent-<index>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceIconTint`（selected 底）、`accentStrong`、`textTitle`、`textSecondary`（enabled 圖示、摘要、原因）、`textPrimary`（selected 摘要）、`textDisabled`（disabled 圖示與名稱，§4.0.1）、`surfaceBase` |
| 間距 | 內距 `Space.sm`（垂直）× `Space.sm`（水平）；圖示與文字間 `Space.sm`；名稱與摘要間 `Space.xxs` |
| 字體 | `AppFontSize.body`（名稱，半粗）、`caption`（摘要、原因） |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`、`Motion.overlay` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `summary` | `projectSummaryLabel`（呼叫端取值） |
| `reason` | `projectUnavailableReasonLabel` + `probeTimeoutReason`（既有） |
| 朗讀「目前專案」 | `currentProjectA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SwitcherOverlay`（清單 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 圖示與兩行文字塊垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為「{name}，{summary}」，`isCurrent` 時附 `currentProjectA11yLabel`；`selected` 等於 `isCurrent`；`enabled` 等於 `enabled`；disabled 時 `hint` 為 `reason` |
| 狀態變化播報 | `enabled` 改變（探測結果）隨重建更新旗標；不設 live region |
| 非視覺替代訊號 | 不可用由 `enabled` 旗標 + 常駐文字承載；目前專案由 `selected` 旗標承載，底色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 浮層展開時焦點限制於浮層內，Tab 依序走過各項（SPEC-003 §2.10）；Space / Enter 觸發；Esc 收合 |
| 對比 | 依 §4.0.2：enabled 摘要與 disabled 原因 `textSecondary` / `surfaceBase` 4.71:1、selected 摘要 `textPrimary` / `surfaceIconTint` 4.89:1、selected 名稱 `accentStrong` / `surfaceIconTint` 8.38:1，皆通過；disabled 圖示與名稱 `textDisabled` 3.06:1 屬非作用中元件豁免（表 2） |

#### 測試點（widget test）

- [ ] 一支測試渲染 enabled / selected / disabled（含 reason）× 有無 `health`
- [ ] 兩種視窗尺寸下不溢位（寬固定於 `LayoutSize.overlayWidth` 內）
- [ ] 最長測試文案：名稱與摘要截斷、原因兩行末截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] enabled 點選呼叫 `onTap` 恰一次；disabled 零次；`Semantics.selected` / `enabled` 與參數一致
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「選擇其他資料夾」動作 | `AppButton.text`（浮層末格） |
| 側欄的目前專案顯示 | `ProjectSwitcherEntry` |

### 4.10 SegmentedControl

**用途**：雙模式切換（矩陣／泳道、列表／主題）；每段錨點 `mode-<screen>-<mode>`。
**內容角色**：動作（每段一個 label slot）。
**何時不用**：畫面導覽（`NavItem`）；一次性動作（`AppButton`）；三段以上的切換（0.1 無此需求，上限 2）。
**出現畫面**：§1、§4。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；段數上限 2 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| segment selected | 段底 `AppColors.surfaceBase`、字 `accentStrong` 半粗；軌道底 `surfaceSegmentTrack` | 點選（無狀態改變） | `selectedIndex` 等於本段 | 點選他段 → unselected |
| segment unselected | 段透明、字 `textPrimary` | 點選 | 非選中段 | 點選本段 → selected |
| hover / pressed / focused（每段） | 依 §4.0.1 | 點選 | | |

無 disabled：雙模式切換恆可用（SPEC-001 §1、§4 可用操作）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選未選段 | 呼叫 `onChanged(index)`；呼叫端執行同畫面狀態轉換：`state-<screen>-<a>` 消失、`state-<screen>-<b>` 出現，各模式 offset 各自保留（SPEC-003 §1.2、§3.1、§3.4） | 內容 cross-fade `Motion.transition`（由畫面承載）；段的選中態切換無動畫 | `Motion.feedback` |
| 點選已選段 | 無狀態改變 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（每段各為一個 Tab 停留點；方向鍵不列入 0.1 下界，SPEC-003 §2.10） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（各段 label 寬 + 2 × `Space.md`，軌道內距 `Space.xxs`） |
| 最小尺寸 | 寬：2 × `LayoutSize.hitTargetMin`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | 每段 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：父格位寬（超出時各段 label 截斷）；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（置於 `SplitRow.header` 右格） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `segments[i].label` | 否 | 1 | 截斷 | `modeSwimlaneLabel`（en「Swimlane」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `segments` | `List<Segment{label, semanticLabel, testKey}>`，長度恰 2 | 是 | label 由呼叫端（`mode*Label`）；semanticLabel 由呼叫端（既有 `*SwitchTo*Action`） |
| `selectedIndex` | `int` | 是 | 不適用 |
| `onChanged` | `ValueChanged<int>` | 是 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceSegmentTrack`（軌道）、`surfaceBase`（選中段底）、`accentStrong`、`textPrimary` |
| 間距 | 段內距 `Space.md`（水平）× `Space.xs`（垂直）；軌道內距 `Space.xxs`；段間 `Space.xxs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md`（軌道）、`Radius.sm`（段） |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 段 label | `modeMatrixLabel` / `modeSwimlaneLabel` / `modeListLabel` / `modeTopicLabel`（呼叫端傳入） |
| 段朗讀提示 | `domainSwitchToMatrixAction` / `domainSwitchToSwimlaneAction` / `ticketsSwitchToListAction` / `ticketsSwitchToTopicAction`（既有，呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SplitRow.header`（右格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於頁首列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 每段 `Semantics.button`，label 等於段 label，`hint` 等於 `semanticLabel`（「切換至矩陣」），`selected` 等於是否選中 |
| 狀態變化播報 | `selected` 旗標改變由輔助技術播報 |
| 非視覺替代訊號 | 選中態同時以底色、字重與 `selected` 旗標承載 |
| 焦點順序與操作路徑（桌機） | Tab 內容區段，兩段依序各為停留點；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：選中段 `accentStrong` / `surfaceBase` 9.92:1、未選段 `textPrimary` / `surfaceSegmentTrack` 4.56:1（`0.1.0-W1-059` 軌道底調淺為 `#DEE6E4` 後；原畫布值 4.48:1 未達），皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染兩段 × 選中索引 0 / 1
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en 四個 label key 皆不溢位
- [ ] 點選未選段呼叫 `onChanged` 恰一次並帶正確索引；點選已選段零次
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 篩選條件的多選 | `FilterDropdown` |
| 三段以上的切換 | 0.1 無此元件；出現需求時走待決出口建元件票 |

### 4.11 PageTitle

**用途**：頁首左側：畫面名 + 一行副標（模式說明或選中摘要）。
**內容角色**：標題 + 內文（title slot + subtitle slot）。
**何時不用**：面板內標題（`AppText.subtitle`）；節點詳情主標（`AppText.title`）。
**出現畫面**：§1–§6。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；副標為可選 slot | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | `AppText.subtitle`（畫面名）上、`AppText.body`（`secondary` 修飾，副標）下，間距 `Space.xxs`；無副標時只一行 | 無 | 建構 | 不適用：純顯示，無狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 純顯示 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬，`SplitRow.header` 左格）；高固有 |
| 最小尺寸 | 寬：一字元 + 省略號；高：一行 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬：父格位寬；高：兩行（不超過 `LayoutSize.headerHeight` − 2 × `Space.xs`） |
| `kMinWindowSize` 下的行為 | 維持（右側控制固有寬，本元件吸收剩餘寬並截斷） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `title` | 否 | 1 | 截斷 | `navTraceability`（en「Traceability」）/ `navTickets`（zh）；`TestCopy.longToken` |
| `subtitle` | 否 | 1 | 截斷 | 人工值「7 個 domain · 5 條 UC flow · 點格子檢視詳情」（畫布副標，依 SPEC-003 §3.1 改寫）；`TestCopy.longEn` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `title` | `String` | 是 | 呼叫端（`nav*` 既有 key） |
| `subtitle` | `String?` | 否 | 呼叫端（畫面票自行宣告 key） |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 經 `AppText`（`textTitle`、`textSecondary`） |
| 間距 | 標題與副標間 `Space.xxs` |
| 字體 | 經 `AppText`（`subtitle`、`body`） |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| `title` / `subtitle` | 呼叫端傳入；本元件無自有 key |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SplitRow.header`（左格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 兩行文字塊垂直置中於頁首列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `title` 為 `Semantics.header`；副標接續唸出 |
| 狀態變化播報 | 副標更新（選中摘要）不主動播報 |
| 非視覺替代訊號 | 不適用顏色訊號（純文字） |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序 |
| 對比 | 依 §4.0.2 表 1：畫面名 `textTitle` / `surfaceBase` 17.20:1、副標 `textSecondary` / `surfaceBase` 4.71:1，皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染有副標 / 無副標
- [ ] 兩種視窗尺寸下不溢位（置於 `SplitRow.header` 左格且右格有 `SegmentedControl`）
- [ ] 最長測試文案兩 slot 皆截斷
- [ ] zh / en 六個 `nav*` key 皆不溢位
- [ ] `Semantics.header` 為 `true`
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 面板或詳情卡的標題 | `AppText.subtitle` |
| 分節的節首 | `ListRow.sectionHeader` |

### 4.12 SearchField

**用途**：Ticket 清單工具列搜尋，`input-tickets-search`。
**內容角色**：動作（輸入）+ 標籤（placeholder）。
**何時不用**：篩選固定選項（`FilterDropdown`）；任何非搜尋的文字輸入（0.1 無）。
**出現畫面**：§4。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| empty | 搜尋圖示（`textDisabled`，純裝飾）+ placeholder（`searchPlaceholder`，`textSecondary`）；無清除鈕 | 輸入 | 值為空字串 | 輸入 → filled |
| filled | 搜尋圖示 + 值 + 清除鈕（內部 affordance，朗讀 `searchClearAction`） | 輸入、清除 | 值非空 | 清除或刪除至空 → empty |
| focused | 邊框 `AppColors.accent`（焦點裝飾，§4.0.1）；可與 empty / filled 並存 | 輸入 | 取得焦點 | 焦點移走 |
| hover | 依 §4.0.1 | | | |

無 disabled：搜尋於正常態恆可用（SPEC-001 §4）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 輸入字元 | 值即時顯示；輸入停止 `Motion.searchDebounce` 後呼叫 `onChanged(value)` 一次（防抖動，不逐字元） | 無 | `Motion.searchDebounce`（SPEC-003 §3.4） |
| 清除（清除鈕或刪至空） | 立即呼叫 `onChanged('')`，不等待防抖動（SPEC-003 §3.4「清空輸入立即還原」） | 無 | 立即 |
| IME 組字中 | 組字未確定前不觸發 `onChanged`（Flutter `TextEditingValue.composing` 非空時視為輸入進行中） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 鍵盤直接輸入（`TextInputType.text`、無送出鍵語意：即時過濾，Enter 無額外動作；IME 允許） | 字元級 | 足夠 | 無 | 視覺（值即時顯示、清單筆數更新） |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬，`Toolbar` 首格）；高固有 |
| 最小尺寸 | 寬：`LayoutSize.iconMd` + placeholder 寬 + `LayoutSize.hitTargetMin`（清除鈕）+ 2 × `Space.sm`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（欄位本身與清除鈕各自） |
| 最大尺寸 | 寬：父格位寬；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（吸收 `Toolbar` 剩餘寬，不低於最小寬） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `placeholder` | 否 | 1 | 截斷 | `searchPlaceholder`（en「Search」）；`TestCopy.longEn` |
| `value`（可編輯） | 否 | 1 | 不截斷：超出視窗時隨游標水平捲動（`TextField` 原生行為；四選一適用於顯示文字，不適用於可編輯文字） | `TestCopy.longToken`（輸入後游標處可見、無溢位錯誤） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `value` | `String` | 是（受控） | 呼叫端狀態（provider） |
| `onChanged` | `ValueChanged<String>` | 是 | 不適用 |
| `placeholder` | `String?` | 否 | 元件預設 `searchPlaceholder`（強語意預設，參數可覆蓋） |
| `testKey` | `Key` | 是（`input-tickets-search`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`（框）、`accent`（focused 框）、`textPrimary`（值、清除鈕）、`textSecondary`（placeholder）、`textDisabled`（搜尋圖示，純裝飾，§4.0.2 表 2） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直）；圖示與文字間 `Space.sm` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.searchDebounce` |

#### i18n

| 文字 | i18n key |
|------|---------|
| placeholder 與朗讀標籤 | `searchPlaceholder` |
| 清除鈕朗讀 | `searchClearAction` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Toolbar`（首格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於工具列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.textField`；label 為 `searchPlaceholder`、value 為目前值；清除鈕 `Semantics.button`，label `searchClearAction` |
| 狀態變化播報 | 值改變由 textField 語意自動播報；清單筆數變化的播報由畫面（`SplitRow.footer` 摘要）承載，本元件不播報 |
| 非視覺替代訊號 | focused 框色非唯一訊號：文字游標與 textField 語意承載焦點 |
| 焦點順序與操作路徑（桌機） | Tab 內容區段首個（工具列首格）；輸入即操作；Tab 至清除鈕（filled 時存在）；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2：值 `textPrimary` / `surfaceBase` 5.79:1、placeholder `textSecondary` / `surfaceBase` 4.71:1，通過；搜尋圖示 `textDisabled` 3.06:1 達非文字 3:1，且為純裝飾（欄位語意由 placeholder 與 `Semantics.textField` 承載） |

#### 測試點（widget test）

- [ ] 一支測試渲染 empty / filled / focused 三狀態
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案：placeholder 截斷；`TestCopy.longToken` 輸入後無溢位錯誤
- [ ] zh / en 兩語系 placeholder 皆不溢位
- [ ] 輸入後 `pump(Motion.searchDebounce)` 前 `onChanged` 零次、後恰一次；清除立即一次
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 選固定選項 | `FilterDropdown` |
| 顯示唯讀值 | `AppText` |

### 4.13 FilterDropdown

**用途**：「狀態：pending」「優先：全部」類的篩選觸發器，`action-tickets-filter-<key>`。
**內容角色**：動作 + 標籤（label slot）+ 數值（目前選項）。
**何時不用**：自由文字（`SearchField`）；雙模式切換（`SegmentedControl`）。
**出現畫面**：§4。
**層級**：L2

> **本條目含待決欄位**（§4.0.9）：選單開合、鍵盤走選項、`open` 狀態的退出路徑、播報值等 SPEC-003 §3.4 未涵蓋，標「待決」並由 `0.1.0-W1-057` 補件；本元件在補件前不得被畫面票引用。

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default（全部） | 「{label}：{filterAllOption}」+ 向下箭頭；底 `surfaceBase`、框 `border` | 點選 → open | `selected` 為 `null` | 選取非全部 → active |
| active（有篩選值） | 「{label}：{value}」；框 `accent`（提案，SPEC-003「該篩選呈選中態」的視覺落點） | 點選 → open | `selected` 非 `null` | 選取全部 → default |
| open | **待決**（`0.1.0-W1-057`：選單形式、錨定、Esc / 點外部收合） | 待決 | 點選觸發器 | 待決 |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 選取一個選項 | 呼叫 `onChanged(value)`；呼叫端執行：該篩選呈選中態、清單筆數改變（SPEC-003 §3.4） | 無 | `Motion.feedback` |
| 點選觸發器（開啟選單）、鍵盤走選項、收合 | **待決**（`0.1.0-W1-057`） | 待決 | 待決 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（觸發器）；選單內選項的鍵盤路徑待決（`0.1.0-W1-057`） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（label + value 寬 + 箭頭 + 內距） |
| 最小尺寸 | 寬：`LayoutSize.hitTargetMin` × 2；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：以最長選項 label 計的固有寬（選取不同值時寬不變，避免工具列跳動；提案）；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（`Toolbar` 不觸發空間不足，5.6） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `filterPriorityLabel`（en「Priority」）；`TestCopy.longZh` |
| `options[i].label`（觸發器內的目前值與選單項） | 否 | 1 | 截斷 | `TestCopy.status`；`filterAllOption`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是 | 呼叫端（`filterStatusLabel` / `filterPriorityLabel`） |
| `options` | `List<FilterOption{value, label}>` | 是（不含「全部」，由元件自動前置） | label 由呼叫端（資料值原文或 i18n） |
| `allOptionLabel` | `String?` | 否 | 元件預設 `filterAllOption`（強語意預設，參數可覆蓋） |
| `selected` | `String?`（`null` = 全部） | 是 | 不適用 |
| `onChanged` | `ValueChanged<String?>` | 是 | 不適用 |
| `testKey` | `Key` | 是（`action-tickets-filter-<key>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border`、`accent`（active 框）、`textPrimary`、`textDisabled`（箭頭，純裝飾，§4.0.2 表 2） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直）；文字與箭頭間 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`；選單開合動畫待決 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 「全部」 | `filterAllOption` |
| 朗讀標籤 | `filterA11yLabel` |
| `label` | `filterStatusLabel` / `filterPriorityLabel`（呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Toolbar`（第 2..N 格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於工具列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為 `filterA11yLabel`（label 與目前值代入）；`expanded` 等於是否 open |
| 狀態變化播報 | 選取後重建即唸出新值；選單內選項的播報 **待決**（`0.1.0-W1-057`） |
| 非視覺替代訊號 | active 由觸發器文字（值非「全部」）承載，框色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 觸發器進入 Tab 順序；選單內路徑 **待決** |
| 對比 | 依 §4.0.2：label 與值 `textPrimary` / `surfaceBase` 5.79:1，通過；箭頭 `textDisabled` / `surfaceBase` 3.06:1 達非文字 3:1，且為純裝飾（開合狀態由語意樹承載，表 2） |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / active（open 待補件後補）
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`；選取不同值時寬不變
- [ ] 最長測試文案截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] 選取選項呼叫 `onChanged` 恰一次；選「全部」傳 `null`
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 排序切換 | `TableColumnHeader.sortable` |
| 顯示目前篩選結果數 | `AppText`（`SplitRow.footer`） |

### 4.14 TableColumnHeader

**用途**：表格與矩陣的欄首標籤；矩陣欄首為兩行（UC ID + 名稱）。
**內容角色**：標籤（label slot；`twoLine` 另有第二行 slot）；`sortable` 加動作。
**何時不用**：資料格內容（`AppText`）；分節節首（`ListRow.sectionHeader`）。
**出現畫面**：§1（`twoLine`）、§2（`static`）、§4（`sortable`）。
**層級**：L2

> **`sortable` 變體含待決欄位**（§4.0.9）：排序循環與播報值待 `0.1.0-W1-057`；`static` 與 `twoLine` 變體不受影響，可被畫面票引用。

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `static` | 一行 caption | 無 | UC Flow 步驟表欄首 |
| `sortable` | 一行 caption + 排序指示圖示（asc / desc 時） | 點選 → 排序（循環待決） | Ticket 清單欄首（`action-tickets-sort-<key>`） |
| `twoLine` | 第一行 `AppText.mono`（UC ID）、第二行 caption（名稱） | 無 | 矩陣欄首 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default（`static` / `twoLine`） | label | 無 | 建構 | 不適用：純顯示變體無狀態集 |
| unsorted（`sortable`） | label，無指示 | 點選 | `order` 為 `none` | 點選 → asc（**循環待決**） |
| asc / desc（`sortable`） | label + 向上／向下指示（`AppIcon.sm`，`accentStrong`） | 點選 | `order` 為 `asc` / `desc` | **待決**（`0.1.0-W1-057`） |
| hover / pressed / focused（`sortable`） | 依 §4.0.1 | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選（`sortable`） | 呼叫 `onSort`；呼叫端執行：首列與末列內容改變、offset 歸零（SPEC-003 §3.4）；下一個 `order` 值 **待決** | 無 | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `sortable`：依 §4.0.7 點選列；`static` / `twoLine`：不適用（純顯示） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬，欄寬由所在 `TableRow.header` / `MatrixGrid` 欄規格決定）；高固有 |
| 最小尺寸 | 寬：一字元 + 省略號（`sortable` 另加 `LayoutSize.iconSm`）；高：一行（`twoLine` 兩行）；`sortable` 高不小於 `LayoutSize.hitTargetMin` |
| 最小命中區 | `sortable`：`LayoutSize.hitTargetMin`（以透明命中區補足）；其餘不適用 |
| 最大尺寸 | 寬：欄寬；高：`LayoutSize.rowHeightRelaxed`（`twoLine`：2 × caption 行高 + `Space.xxs` + 2 × `Space.xs`） |
| `kMinWindowSize` 下的行為 | 維持（欄寬由容器決定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `columnEvents`（zh「發送事件」）/ `columnPriority`（en「Priority」）；`TestCopy.longToken` |
| `secondLine`（`twoLine`） | 否 | 1 | 截斷 | `TestCopy.ucName`；`TestCopy.longZh` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是 | 呼叫端（`column*`；`twoLine` 第一行為 UC ID 資料值） |
| `secondLine` | `String`（`twoLine`） | `twoLine` 必填 | 呼叫端（資料值） |
| `order` | `SortOrder { none, asc, desc }`（`sortable`） | `sortable` 必填 | 不適用 |
| `onSort` | `VoidCallback`（`sortable`） | `sortable` 必填 | 不適用 |
| `testKey` | `Key`（`sortable`：`action-tickets-sort-<key>`） | `sortable` 必填 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textSecondary`（label）、`accentStrong`（排序指示）、`textPrimary`（`twoLine` 第一行） |
| 間距 | label 與指示間 `Space.xs`；`twoLine` 行間 `Space.xxs`；內距由容器承載 |
| 字體 | `AppFontSize.caption`（半粗）、`body`（`twoLine` 第一行 mono） |
| 圓角 | 無 |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | `columnId` / `columnTitle` / `columnStatus` / `columnPriority` / `columnStep` / `columnDomain` / `columnEvents`（呼叫端傳入） |
| 排序朗讀 | `sortA11yLabel` + `sortNone` / `sortAscending` / `sortDescending` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `TableRow.header`、`MatrixGrid`（欄首格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 文字 `start` 對齊（數值欄與矩陣欄首置中，由容器欄規格指定） |
| 作為表格或列表的一欄時 | 欄寬同該欄資料格；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `static` / `twoLine`：`Semantics.header`，唸出 label（`twoLine` 唸「{ID}，{名稱}」）；`sortable`：`Semantics.button`，label 為 `sortA11yLabel`（order 代入 `sortNone` / `sortAscending` / `sortDescending`） |
| 狀態變化播報 | `sortable` 點選後 order 改變的播報值 **待決**（`0.1.0-W1-057`） |
| 非視覺替代訊號 | 排序方向由朗讀標籤的 order 值承載，圖示非唯一訊號 |
| 焦點順序與操作路徑（桌機） | `sortable` 進入 Tab 順序，Space / Enter 觸發；其餘不進入 |
| 對比 | 依 §4.0.2 表 1：label `textSecondary` / `surfaceBase` 4.71:1、`twoLine` 第一行 `textPrimary` / `surfaceBase` 5.79:1、排序指示 `accentStrong` / `surfaceBase` 9.92:1，皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染三個變體 × `sortable` 三種 order
- [ ] 兩種視窗尺寸下不溢位（置於固定寬欄）
- [ ] 最長測試文案截斷（含第二行）
- [ ] zh / en 七個 `column*` key 皆不溢位
- [ ] `sortable` 點選呼叫 `onSort` 恰一次；朗讀標籤含 order 值
- [ ] 顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 資料列的格內容 | `AppText` / `Badge` |
| 群組小標（關聯群） | `AppText.caption` |

### 4.15 MatrixCell

**用途**：domain × UC 交叉格的關係符號，可點擊選格（`cell-domain-<rowId>-<colId>`）。
**內容角色**：數值（關係強度，以符號承載）+ 動作。
**何時不用**：泳道格內的動作標籤（`SwimlaneNode`）；列首與小計（`AppText`）；欄首（`TableColumnHeader.twoLine`）。
**出現畫面**：§1。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `direct` | 符號 ●，`AppColors.accent` | 無 | 直接貫穿 |
| `indirect` | 符號 ○，`AppColors.textSecondary` | 無 | 間接依賴 |
| `none` | 符號 ·，`AppColors.borderStrong` | 無（同樣可選，SPEC-001 §1「無關格亦可選」） | 無關 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 透明底 + 符號 | 點選 | 未選、所在列未高亮 | 點選 → selected；所在列被選 → rowSelected |
| rowSelected | 底 `AppColors.surfaceIconTint`（列高亮，由 `MatrixGrid` 對整列套用）+ 符號 | 點選 | 所在 domain 列為選中列（`action-domain-select-<domainId>` 或選格連動） | 他列被選 → default |
| selected | 底 `AppColors.accent`、符號 `AppColors.surfaceBase`（成對設計，對比通過 §4.0.2；與 rowSelected 可區辨） | 點選（無狀態改變）、Esc 清除 | 單擊本格（SPEC-003 §3.1「選格」） | 點其他格 → default（換選）；Esc / `action-domain-cell-clear` → rowSelected 或 default；點另一列列首 → default（選格清除） |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

無 disabled：同形的格不得一部分可點一部分不可點（SPEC-001 §1 註記）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 單擊（未選） | 呼叫 `onTap`；`Motion.feedback` 內本格 selected、所在列 rowSelected；右欄 `panel-domain-cell-detail` 出現；矩陣 offset 不變（SPEC-003 §3.1） | 選中態無入場動畫（持續性標記）；右欄 cross-fade `Motion.transition`（由畫面承載） | `Motion.feedback` |
| 單擊（已選） | 無狀態改變（取消由 Esc 承擔，SPEC-003 §3.1） | — | — |
| 單擊另一格 | 前一格失去 selected，新格取得；`scroll-domain-cell-detail` offset 歸零 | `Motion.transition`（右欄） | `Motion.feedback` |
| Esc（已選格） | 由 `MatrixGrid` 承接：選取清除，焦點停在原格，offset 不變（SPEC-003 §2.10） | `Motion.transition`（右欄） | — |
| drag | 不可拖曳；觸發 `scroll-domain-matrix` 捲動（SPEC-003 §1.3） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（`MatrixGrid` 的格；欄寬 `LayoutSize.matrixColumnWidth`，§3.7 第 24 項已核定，屬 4.37 範疇，本元件不感知） |
| 最小尺寸 | `LayoutSize.hitTargetMin` × `LayoutSize.rowHeightRelaxed` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：格寬；高：`LayoutSize.rowHeightRelaxed` |
| `kMinWindowSize` 下的行為 | 維持（矩陣二維捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無文字 slot（符號 ● ○ · 為非語意排版字元，由變體決定；朗讀文字見無障礙） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `relation` | `Relation { direct, indirect, none }` | 是 | 不適用 |
| `isSelected` / `isRowSelected` | `bool` | 是 | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端（`matrixCellA11yLabel` 取值，relation 代入 `legend*`） |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`cell-domain-<rowId>-<colId>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.accent` / `textSecondary` / `borderStrong`（符號）、`surfaceIconTint`（列高亮）、`accent` + `surfaceBase`（selected） |
| 間距 | 格內距 `Space.xs`（由 `MatrixGrid` 承載） |
| 字體 | `AppFontSize.subtitle`（符號字級） |
| 圓角 | `Radius.sm`（selected 底） |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 朗讀標籤 | `matrixCellA11yLabel` + `legendDirect` / `legendIndirect` / `legendNone`（呼叫端組字） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `MatrixGrid`（資料格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 符號置中於格 |
| 作為表格或列表的一欄時 | 欄寬 = `MatrixGrid` UC 欄寬 `LayoutSize.matrixColumnWidth`（§3.7 第 24 項已核定）；內距 `Space.xs` |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 等於 `semanticLabel`（「{domain} × {uc}：直接貫穿」）；`selected` 等於 `isSelected` |
| 狀態變化播報 | `selected` 旗標改變由輔助技術播報；右欄內容更新由詳情卡標題（header）承載 |
| 非視覺替代訊號 | 關係種類由符號形狀（● ○ ·）與朗讀文字承載，顏色非唯一訊號；選中由 `selected` 旗標承載 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（矩陣內依閱讀順序）；Space / Enter 選格；Esc 清除且焦點停留本格（SPEC-003 §2.10）；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：selected `surfaceBase` / `accent` 5.84:1、`direct` 符號 `accent` / `surfaceBase` 5.84:1、`indirect` 符號 `textSecondary` / `surfaceBase` 4.71:1（語意符號，維持 `textSecondary`），皆通過；`none` 符號 `borderStrong` 1.55:1 為刻意弱化（無關係即無資訊，朗讀標籤另承載） |

#### 測試點（widget test）

- [ ] 一支測試渲染三個變體 × default / rowSelected / selected
- [ ] 兩種視窗尺寸下不溢位；命中區不小於 `LayoutSize.hitTargetMin`
- [ ] 無文字 slot（本項不適用）
- [ ] 點選呼叫 `onTap` 恰一次；已選格再點零次；`Semantics.selected` 與 `isSelected` 一致
- [ ] selected 與 rowSelected 的底色不同（可區辨斷言）
- [ ] 顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 泳道格內的動作標籤 | `SwimlaneNode` |
| 矩陣列首（domain 名，`action-domain-select-<domainId>`） | `AppText`（列首格由 `MatrixGrid` 包成可點，見 4.37） |

### 4.16 SwimlaneNode

**用途**：泳道格內的動作標籤（掃描、解析、建圖…）；0.1 不可點、不可拖。
**內容角色**：標籤。
**何時不用**：矩陣格（`MatrixCell`）；可點的節點（0.1 無）；非泳道的標籤（`Badge`）。
**出現畫面**：§1（泳道）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `active` | 底 `AppColors.accent`、字 `surfaceBase` | 無 | 屬於選定 UC flow 的步驟 |
| `inactive` | 底 `AppColors.surfaceChip`、字 `textPrimary` | 無 | 其他步驟 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依變體 | 無（不可點、不可拖，SPEC-003 §1.3） | 建構 | 不適用：純顯示元件（active / inactive 為變體非狀態） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點擊 | 無反應、無 pressed 態（0.1 無節點動作） | — | — |
| drag | 元素不移動；觸發 `drag-domain-swimlane` 畫布平移（SPEC-003 §1.3） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且明訂無互動（0.1） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（chip） |
| 最小尺寸 | 一字元 + 2 × `Space.sm` × （`AppFontSize.body` 行高 + 2 × `Space.xs`） |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | 寬：所在步驟欄寬（超出截斷）；高：`LayoutSize.laneRowHeight` − 2 × `Space.xs` |
| `kMinWindowSize` 下的行為 | 維持（泳道二維捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `TestCopy.stepName`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是 | 呼叫端（資料值） |
| `isActive` | `bool` | 是（對映變體） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.accent`、`surfaceBase`、`surfaceChip`、`textPrimary` |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直） |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | 呼叫端傳入（資料值） |
| 朗讀狀態 | `laneNodeActive` / `laneNodeInactive` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SwimlaneGrid`（步驟欄格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於步驟欄格 |
| 作為表格或列表的一欄時 | 欄寬由 `SwimlaneGrid` 假資料座標決定（SPEC-001 設計約束）；內距 `Space.xs` |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 唸出「{label}，`laneNodeActive` / `laneNodeInactive`」 |
| 狀態變化播報 | 不播報（變體隨選定 UC 重建） |
| 非視覺替代訊號 | active 由朗讀文字承載，底色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（非互動）；輔助技術依泳道列閱讀順序讀到 |
| 對比 | 依 §4.0.2（`surfaceBase` / `accent`、`textPrimary` / `surfaceChip` 皆通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染兩個變體
- [ ] 兩種視窗尺寸下不溢位（置於固定寬步驟欄）
- [ ] 最長測試文案截斷
- [ ] zh / en 資料值皆不溢位
- [ ] 點擊無反應；drag 造成父捲動容器 offset 改變
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 事件標籤 | `Badge.event` |
| 步驟表的步驟名 | `AppText.body`（`TableRow.step`） |

### 4.17 StepNumber

**用途**：步驟列與格詳情卡步驟清單的序號（圓形，§3.7 第 11 項）。
**內容角色**：數值。
**何時不用**：計數徽章（`Badge.count`）；非序號的數字（`AppText`）。
**出現畫面**：§1（詳情卡）、§2。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（圓形，底 `AppColors.surfaceIconTint`、字 `accentStrong`；取 §2 畫布配色，主要出現處） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 圓形 + 數字 | 無 | 建構 | 不適用：純顯示，無狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 純顯示；所在列的點擊由 `TableRow.step` / `ListRow.numbered` 承載 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（正圓） |
| 最小尺寸 | 直徑 `LayoutSize.stepNumberSize`（24，圓形；收斂自畫布 16/24 兩值） |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | 同直徑 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `number` | 否 | 1 | 不截斷；直徑固定，三位數以上改 `AppFontSize.caption` 渲染（提案） | 人工值 `999`；一般值 `39`（本專案 FlowStep 總數） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `number` | `int`（自 1 起） | 是 | 不適用（數字格式符號） |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceIconTint`、`accentStrong` |
| 間距 | 無（與文字的間距由所在列承載） |
| 字體 | `AppFontSize.caption`（半粗） |
| 圓角 | 全圓（直徑 / 2；不引用 `Radius` 階） |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 朗讀標籤 | `stepNumberA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `TableRow.step`（首欄）、`ListRow.numbered`（leading） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於列 |
| 作為表格或列表的一欄時 | 固定寬欄（`TableRow.step` 序號欄，`LayoutSize.stepNumberColumnWidth`）；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `stepNumberA11yLabel`（number 代入） |
| 狀態變化播報 | 不播報 |
| 非視覺替代訊號 | 數字本身即訊號 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序 |
| 對比 | 依 §4.0.2（`accentStrong` / `surfaceIconTint` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染一位數、兩位數、三位數
- [ ] 兩種視窗尺寸下尺寸不變且不溢位
- [ ] 三位數不截斷
- [ ] 朗讀標籤含數字
- [ ] 顏色與直徑引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 損壞計數 | `Badge.count` |
| 小計數字 | `AppText.caption` |

### 4.18 ExpanderIcon

**用途**：樹節點、主題節、破洞分節的展開觸發器，`expander-*`。
**內容角色**：動作（圖形化）。
**何時不用**：純裝飾箭頭（`AppIcon`）；整列可點的開啟動作（列本身）。
**出現畫面**：§3、§4、§5。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（expanded / collapsed / leaf 為狀態） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| collapsed | 向右箭頭 `AppIcon.sm`（`textDisabled`，純裝飾箭頭，§4.0.2 表 2） | 點選 | `isExpanded` 為 `false` 且有子層 | 點選 → expanded |
| expanded | 向下箭頭 | 點選 | `isExpanded` 為 `true` | 點選 → collapsed |
| leaf | 不渲染箭頭但保留寬度（對齊） | 無 | 無子層 | 不適用：靜止（資料決定，非死胡同） |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選 | 呼叫 `onToggle`；呼叫端執行：子層出現或消失、捲動 offset 不歸零（SPEC-003 §3.3、§3.4、§3.5、§1.4） | 子層高度變化 `Motion.transition`（由 `Section` / `Tree` 承載）；箭頭切換無旋轉動畫（提案） | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（正方形） |
| 最小尺寸 | `LayoutSize.hitTargetMin` × `LayoutSize.hitTargetMin`（圖示 `LayoutSize.iconSm` 置中，透明命中區補足） |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 同最小 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `isExpanded` | `bool` | 是 | 不適用 |
| `isLeaf` | `bool` | 否（預設 `false`） | 不適用 |
| `onToggle` | `VoidCallback` | 非 leaf 必填 | 不適用 |
| `testKey` | `Key` | 是（`expander-traceability-<nodeId>` / `expander-tickets-topic-<name>` / `expander-gaps-<category>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textDisabled`（箭頭，純裝飾，§4.0.2 表 2） |
| 間距 | 無（與文字的間距由所在列承載） |
| 字體 | 無 |
| 圓角 | `Radius.sm`（焦點與 hover 區） |
| 動畫 | `Motion.feedback`、`Motion.transition`（子層，容器承載） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 朗讀標籤 | `expanderLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `ListRow`（leading：`tree` / `sectionHeader` 變體） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於列 |
| 作為表格或列表的一欄時 | 固定寬 = `LayoutSize.hitTargetMin`；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為「`expanderLabel`，{所在列主文字}」；`expanded` 等於 `isExpanded`；leaf 排除於語意樹 |
| 狀態變化播報 | `expanded` 旗標改變由輔助技術播報 |
| 非視覺替代訊號 | 展開狀態由 `expanded` 旗標承載，箭頭方向非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序；Space / Enter 切換；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 2：箭頭 `textDisabled` / `surfaceBase` 3.06:1 達非文字 3:1，且為純裝飾（展開狀態由 `expanded` 旗標承載，箭頭方向非唯一訊號） |

#### 測試點（widget test）

- [ ] 一支測試渲染 collapsed / expanded / leaf
- [ ] 兩種視窗尺寸下尺寸不變；leaf 寬等於非 leaf
- [ ] 無文字 slot（本項不適用）
- [ ] 點選呼叫 `onToggle` 恰一次；`Semantics.expanded` 與 `isExpanded` 一致；leaf 無語意節點
- [ ] 顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 專案切換入口的展開箭頭 | `ProjectSwitcherEntry` 內部 slot |
| 篩選下拉的箭頭 | `FilterDropdown` 內部 |

### 4.19 RelationItem

**用途**：可點的節點參照 chip：節點詳情右欄的關聯節點 ID（等寬字，點擊替換主欄，`card-nodeDetail-relation-<nodeId>`）與步驟表的 domain 欄（一般字，點擊 jump 至 Domain 視圖並選中該 domain，`action-ucFlow-goto-domain-<domainId>`）。兩者內容角色相同（節點參照 + 動作），只有目的地不同，依 skill「只是目的地不同者為 slot」合為一件；字型以 `isMono` 參數區分。
**內容角色**：數值（ID 或名稱）+ 動作。
**何時不用**：非互動的 ID 顯示（`AppText.mono`）；非節點參照的跨畫面動作（`AppButton`）；非互動的 domain 標籤（`Badge.tag`，節點詳情標籤列）。
**出現畫面**：§6（關聯右欄）、§2（步驟表 domain 欄）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（damaged 為狀態） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | chip 底 `AppColors.surfaceChip`、mono `textPrimary` | 點選 | 邊完整 | 呼叫端標記損壞 → damaged |
| damaged | 由 `IssueMarker.damagedEdge` 包住（虛線框；文字維持 `textPrimary`，§4.0.2 帶色表面規則） | 點選（改為跳轉破洞報告，由 `IssueMarker` 承載） | 邊損壞（FR-05） | 重新整理後邊完整 → default |
| hover / pressed / focused | 依 §4.0.1 | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選（default，關聯右欄） | 呼叫 `onTap`；呼叫端執行：主欄內容替換為該節點、主欄 offset 歸零、右欄 offset 保留、`returnTo` 不變（SPEC-003 §3.6） | 主欄 cross-fade `Motion.transition`（畫面承載） | `Motion.feedback` |
| 點選（default，步驟表 domain 欄） | 呼叫 `onTap`；呼叫端執行：jump 至 `nav-page-domain` 且該 domain 呈選中態，`returnTo` 設為 `ucFlow`（SPEC-003 §3.2） | 無（`IndexedStack` 切頁） | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，關聯群內）；高固有 |
| 最小尺寸 | 寬：一字元 + 省略號 + 2 × `Space.sm`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：`LayoutSize.detailPaneWidth` − 2 × `Space.md`；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（右欄寬固定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `id` | 否 | 1 | 截斷 | `TestCopy.nodeId`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `id` | `String` | 是 | 呼叫端（資料值：節點 ID 或 domain 名） |
| `isMono` | `bool` | 否（預設 `true`；步驟表 domain 欄傳 `false`） | 不適用 |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`card-nodeDetail-relation-<nodeId>` / `action-ucFlow-goto-domain-<domainId>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceChip`、`textPrimary`（default 與 damaged 同色，損壞由 `IssueMarker` 的虛線框承載） |
| 間距 | 內距 `Space.sm`（水平）× `Space.sm`（垂直） |
| 字體 | `AppFontSize.body`（mono） |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 朗讀標籤 | `relationItemA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Section.static`（關聯群項目）；`TableRow.step`（domain 欄，`isMono=false`）；damaged 時外包 `IssueMarker.damagedEdge` |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 關聯群內填滿寬、文字 `start`；表格欄內固有寬、置中 |
| 作為表格或列表的一欄時 | `TableRow.step` domain 欄：固定寬（`LayoutSize.stepDomainColumnWidth`）、固有寬 chip 置於欄內；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為 `relationItemA11yLabel`（id 代入） |
| 狀態變化播報 | 點選後主欄替換由主欄標題（`Semantics.header`）承載，本元件不播報 |
| 非視覺替代訊號 | damaged 由 `IssueMarker` 的朗讀標籤承載 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（右欄依群組閱讀順序）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：`textPrimary` / `surfaceChip` 4.94:1（default 與 damaged 同值），通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / damaged（外包 `IssueMarker.damagedEdge`）
- [ ] 兩種視窗尺寸下不溢位（寬固定於右欄內）
- [ ] 最長測試文案截斷
- [ ] 資料值（zh / en 無差異）不溢位
- [ ] 點選呼叫 `onTap` 恰一次；元件樹被 `InkWell` 包覆
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 主欄 meta 列的路徑 | `AppText.mono`（`ListRow.meta`） |
| 跨畫面的「前往破洞報告」 | `AppButton` |

### 4.20 DocumentBody

**用途**：節點詳情主欄的 markdown 渲染內容（段落、標題、行內 code、清單、引用區塊、程式碼區塊、表格），由 `flutter_markdown_plus` 承載；渲染器內部 widget 列第 7 章豁免（§3.7 第 7 項）。
**內容角色**：內文（一個 markdown slot）。
**何時不用**：單行或短段落文字（`AppText`）；frontmatter 欄位（`ListRow.meta` / `BadgeRow`）。
**出現畫面**：§6。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 渲染 markdown | 捲動（由 `Panel.scrollable` 承載） | 建構 | 不適用：純顯示，無狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點擊連結 | 0.1 連結渲染為一般文字（`onTapLink` 不接線即不渲染為可點，SPEC-003 FR-06 合法形態 a；外部開啟下界待 `0.1.0-W1-036`） | — | — |
| 捲動 | `scroll-nodeDetail-content` offset 改變（容器承載） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示（捲動屬所在容器） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固有（依內容，由 `Panel.scrollable` 捲動） |
| 最小尺寸 | 寬：一字元；高：一行 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬：父寬（超寬區塊各自水平捲動）；高：無上限 |
| `kMinWindowSize` 下的行為 | 維持（段落隨寬換行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot（markdown 元素） | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 段落、清單項、引用區塊（含 FR 引用區塊） | 是 | 無上限 | 換行（無斷字機會的長 token 於字元邊界換行） | `test/fixtures/corpus/book_overview_v1/docs/spec/extraction/e2e-contract.md`（1673 行，SPEC-001 異常長內容）；`TestCopy.longToken` |
| 標題（h1–h6） | 是 | 無上限 | 換行 | `TestCopy.nodeTitle` |
| 行內 code | 是（隨段落） | 無上限 | 換行 | `TestCopy.filePath` |
| 程式碼區塊 | 否 | 無上限（行數） | 水平捲動（提案：程式碼換行改變語意） | `TestCopy.longToken` 作單行 |
| 表格 | 否 | 無上限（列數） | 水平捲動（提案） | 同上語料內的寬表格 |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `markdown` | `String` | 是 | 呼叫端（檔案內容） |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textPrimary`（內文）、`textTitle`（標題）、`surfaceChip`（行內 code 底、程式碼區塊底、引用區塊底）、`border`（表格線） |
| 間距 | 段落間 `Space.sm`；區塊內距 `Space.md`；自身外距 `Space.xs`（§3.7 第 13 項：節點詳情主欄額外留白由本元件承載） |
| 字體 | `AppFontSize.body`（內文）、`subtitle`（h2–h6）、`title`（h1）、mono（code） |
| 圓角 | `Radius.md`（區塊） |
| 動畫 | 無 |

樣式表（`MarkdownStyleSheet`）為本元件唯一的樣式定義處，映射上表；渲染器預設樣式不得外漏。

#### i18n

| 文字 | i18n key |
|------|---------|
| 內容 | 檔案內容，不經 i18n |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.scrollable`（節點詳情主欄末格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 填滿寬 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 標題節點為 `Semantics.header`；段落依閱讀順序唸出；程式碼區塊唸出原文 |
| 狀態變化播報 | 內容替換（關聯項點選）不播報，由主欄標題 header 承載 |
| 非視覺替代訊號 | 引用區塊與 code 的底色非唯一訊號：markdown 結構語意由渲染器的語意樹承載 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（0.1 無可點連結）；捲動容器可聚焦（SPEC-003 §2.10 內容區段） |
| 對比 | 依 §4.0.2（`textPrimary` / `surfaceChip` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染含全部元素類型的 markdown 樣本
- [ ] 兩種視窗尺寸下段落不溢位；程式碼區塊與表格為水平捲動容器而非溢位
- [ ] 1673 行語料渲染無 framework 錯誤且可捲至末端
- [ ] zh / en 混排段落不溢位
- [ ] 連結渲染為一般文字、無 `InkWell`
- [ ] 樣式表顏色、字級、間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 格詳情卡的說明文字 | `AppText.body` |
| 顯示 frontmatter 的 status / type | `BadgeRow` / `ListRow.meta` |

### 4.21 EmptyState

**用途**：「這裡目前沒有內容」+ 至少一個非返回的前進動作（SPEC-001 FR-03）；訊息、說明、動作為 slot。
**內容角色**：內文（訊息 + 說明）+ 動作（經 `ButtonRow`）。
**何時不用**：這個專案不適用本 App（`BlockedState`）；有 N 筆內容尚未載入（`LoadPrompt`）；原始檔已消失（`MissingSourceState`）；浮層無最近專案（只有一顆 `AppButton.text`，§3.7 第 3 項）。
**出現畫面**：§1（未選專案、空圖、未選格右欄）、§2（無 UC、flow 未結構化）、§3（無提案）、§4（無 ticket）、§5（無破洞）、§6（未選節點）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `page` | 置中於內容區，訊息 `AppText.subtitle`、說明 `AppText.body`（`secondary`）、`ButtonRow` | 動作必填（FR-03）；動作觸發後 jump 並設 `returnTo`（SPEC-003 §2.7） | 全頁空狀態（八處） |
| `section` | 靠上對齊於所在區塊，訊息 `AppText.body`、說明可缺 | 動作可缺（前進動作在區塊外，如未選格右欄「前進動作即點格，在主欄」，SPEC-003 §3.1）；有動作時同 `page` | 區塊級：flow 未結構化（與 UC 基本資訊並列）、未選格右欄 `panel-domain-cell-detail-empty` |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 訊息 + 說明（可缺）+ 動作列（`page` 必有） | 動作按鈕（`page`）；`section` 無動作時無 | 呼叫端渲染本元件（畫面級進入條件由 SPEC-001 承載） | 動作 → jump 或同畫面轉換（畫面級退出路徑由 SPEC-001 承載）；`section` 無動作時退出在區塊外（點格） |

元件自身只有一個狀態；空狀態的畫面級進出（`state-<screen>-empty` 等錨點）由呼叫端承載。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 動作按鈕點選 | 經 `AppButton` 呼叫呼叫端 callback：jump 至目標畫面並設 `returnTo`（SPEC-003 §2.4、§2.7），或同畫面轉換（選擇資料夾 → `state-domain-loading`，SPEC-003 §3.1） | 狀態間 cross-fade `Motion.transition`（畫面承載） | `Motion.feedback` |
| 進入本狀態 | cross-fade 自前一狀態（SPEC-003 各 §3.x 動畫提示） | `Motion.transition` | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（動作按鈕）；無動作的 `section` 為純顯示 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | `page`：填滿父容器（寬與高），內容置中；`section`：填滿寬、高固有 |
| 最小尺寸 | 寬：`ButtonRow` 最小寬（4.34）；高：訊息一行 + `LayoutSize.hitTargetMin` + 2 × `Space.sm` |
| 最小命中區 | 動作按鈕 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 訊息與說明文字塊最大寬 = `LayoutSize.detailPaneWidth` × 2（提案：置中文字塊過寬不可讀）；高無上限（說明換行） |
| `kMinWindowSize` 下的行為 | 維持（`ButtonRow` 換行承載按鈕溢位） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 2 | 末行截斷 | `emptyGraphMessage`（en「This project has no graph nodes yet」）/ `cellDetailPrompt`；`TestCopy.longZh` |
| `explanation` | 是 | 4 | 末行截斷 | `noGapsScanScope`（en 較長）；`TestCopy.longEn` |
| 動作 label | 經 `AppButton`（4.4） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（i18n key 取值） |
| `explanation` | `String?` | 否 | 呼叫端 |
| `actions` | `List<AppButton>`（1..3） | `page` 必填且首個非 `backAction`（FR-03）；`section` 可空 | 不適用 |
| `testKey` | `Key` | 是（`state-<screen>-<state>` / `panel-domain-cell-detail-empty`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 經 `AppText`、`AppButton` |
| 間距 | 訊息與說明間 `Space.xs`；說明與動作列間 `Space.lg`；`section` 內距 `Space.md` |
| 字體 | 經 `AppText` |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `message` | 呼叫端傳入：`emptyGraphMessage` / `emptyUcMessage` / `flowUnstructuredMessage` / `emptyProposalMessage` / `emptyTicketsMessage` / `noGapsMessage` / `noNodeSelectedMessage`（既有）、`cellDetailPrompt`；未選專案的訊息由畫面票宣告 |
| `explanation` | `noGapsScanScope`（既有）等 |
| 動作 | 經 `AppButton`（`chooseWorkspaceFolder` / `gotoGapsReportAction` / `gotoTraceabilityAction` / `openDocsFolderAction` / `rescanAction` / `openSourceFileAction` / `viewRelationsAction` / `backToDomainAction`） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot，`page`）、`Panel` / `Panel.scrollable`（`section`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | `page` 置中；`section` 上緣 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息為 `Semantics.header`；說明接續；動作按鈕各自為 button |
| 狀態變化播報 | 進入本狀態時訊息以 `liveRegion` 播報一次（提案：狀態轉換是使用者操作的結果，需即時告知） |
| 非視覺替代訊號 | 純文字 + 按鈕，無顏色訊號 |
| 焦點順序與操作路徑（桌機） | 動作按鈕進入 Tab 內容區段；`section` 無動作時無停留點 |
| 對比 | 依 §4.0.2 表 1：訊息 `textTitle` / `surfaceBase` 17.20:1、說明 `textSecondary` / `surfaceBase` 4.71:1，皆通過（兩變體底皆 `surfaceBase`） |

#### 測試點（widget test）

- [ ] 一支測試渲染 `page`（一／二／三個動作）與 `section`（有／無動作、有／無說明）
- [ ] 兩種視窗尺寸下不溢位；`page` 內容置中
- [ ] 最長測試文案：訊息兩行末截斷、說明四行末截斷
- [ ] zh / en 全部既有 message key 皆不溢位
- [ ] `page` 的首個動作 label 不等於 `backAction`（FR-03 斷言）；動作點選呼叫 callback 恰一次
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「這個專案不適用本 App」 | `BlockedState` |
| 「載入 N 張 ticket」 | `LoadPrompt` |
| 「原始檔已不存在」 | `MissingSourceState` |
| 浮層無最近專案 | `SwitcherOverlay` 零項 + `AppButton.text` |

### 4.22 MissingSourceState

**用途**：「原始檔已不存在」+ 最後已知路徑 + 重新整理／返回（SPEC-001 §6 原始檔已消失）；退出留在畫面內（重新整理三分支）。
**內容角色**：內文（訊息）+ 數值（路徑）+ 動作。
**何時不用**：這裡沒有內容且前進動作跳轉離開畫面（`EmptyState.page`）；開啟原始檔時的暫時失敗提示（`AppSnackBar`）。
**出現畫面**：§6。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 訊息 `AppText.subtitle` + 路徑 `AppText.mono`（`secondary`）+ `ButtonRow`[重新整理 `primary`, 返回 `secondary`（`returnTo` 為 `null` 時不渲染）] | 重新整理、返回 | 呼叫端渲染（`state-nodeDetail-missing`） | 重新整理 → 三分支（仍不存在：維持 + SnackBar；完整 → normal；斷點 → partial）；返回 → `returnTo`（SPEC-003 §3.6） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 重新整理（`action-nodeDetail-refresh`） | 呼叫 `onRefresh`；三分支結果在 `Motion.cancelDeadline` 內抵達；仍不存在時 `AppSnackBar.plain`（`sourceFileStillMissingMessage`） | cross-fade `Motion.transition` | `Motion.cancelDeadline`（SPEC-003 §3.6） |
| 返回（`action-nodeDetail-back`） | 依 SPEC-003 §2.3 規則 4（由頁面框架渲染於 `SplitRow.header`，本元件不重複渲染；本元件的 `ButtonRow` 只放重新整理） | — | `Motion.feedback` |

> 返回鍵位置：SPEC-003 §2.4 統一置於 `SplitRow.header` 右側，由頁面框架單一渲染；SPEC-001 §6 顯示欄的「返回」由該處承載，本元件動作列只含重新整理（避免同畫面兩個返回錨點）。

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高），內容置中 |
| 最小尺寸 | 寬：`ButtonRow` 最小寬；高：訊息 + 路徑 + `LayoutSize.hitTargetMin` + 2 × `Space.sm` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 文字塊最大寬 `LayoutSize.detailPaneWidth` × 2（同 4.21）；高無上限 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 2 | 末行截斷 | `sourceFileMissingMessage`（en「Source file no longer exists」）；`TestCopy.longZh` |
| `path` | 是 | 3 | 末行截斷（路徑可於 `/` 處換行，提案） | `lastKnownPathLabel`（path 代入 `TestCopy.filePath`）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `path` | `String` | 是 | 呼叫端（資料值；標籤組字 `lastKnownPathLabel` 由元件預設引用，參數可覆蓋） |
| `onRefresh` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`state-nodeDetail-missing`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 經 `AppText`、`AppButton` |
| 間距 | 訊息與路徑間 `Space.xs`；路徑與動作列間 `Space.lg` |
| 字體 | 經 `AppText`（`subtitle`、`mono`） |
| 圓角 | 無 |
| 動畫 | `Motion.transition`、`Motion.cancelDeadline` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 | `sourceFileMissingMessage`（既有，元件預設，參數可覆蓋） |
| 路徑標籤 | `lastKnownPathLabel`（既有） |
| 重新整理 | `refreshAction`（既有） |
| 仍不存在的 SnackBar | `sourceFileStillMissingMessage`（既有，由呼叫端觸發） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息為 `Semantics.header`；路徑接續唸出全文 |
| 狀態變化播報 | 進入本狀態時訊息以 `liveRegion` 播報一次（同 4.21）；重新整理仍不存在時由 SnackBar 播報 |
| 非視覺替代訊號 | 純文字 + 按鈕 |
| 焦點順序與操作路徑（桌機） | 重新整理按鈕進入 Tab 內容區段 |
| 對比 | 依 §4.0.2 表 1：訊息 `textTitle` / `surfaceBase` 17.20:1、路徑 `textSecondary` / `surfaceBase` 4.71:1，皆通過；按鈕依 4.4 |

#### 測試點（widget test）

- [ ] 一支測試渲染單一狀態
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息兩行、路徑三行末截斷
- [ ] zh / en 三個 key 皆不溢位
- [ ] 重新整理點選呼叫 `onRefresh` 恰一次
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 開啟原始檔失敗的暫時提示（UC Flow、破洞報告） | `AppSnackBar.withAction` |
| 「尚未選取節點」 | `EmptyState.page` |

### 4.23 BlockedState

**用途**：「這個專案不適用本 App」+ 版本值 + 說明 + 切換專案出口（恆可用，SPEC-001 FR-07）；0.1 不渲染「以純檔案模式檢視」（SPEC-003 §3.1，降級策略待 `0.1.0-W1-035`）。
**內容角色**：內文（訊息 + 說明）+ 數值（版本值）+ 動作。
**何時不用**：這裡沒有內容（`EmptyState`）；暫時性錯誤提示（`AppSnackBar`）。
**出現畫面**：§1（不是框架專案、無可消費的型別表、schema 不相容）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `plain` | 訊息 + 說明（可缺）+ 版本值（可缺）+ `ButtonRow`[切換專案 `primary`] | 無展開 | 不是框架專案、無可消費的型別表 |
| `withDetail` | 加 `AppButton.secondary`「檢視詳情」（`action-domain-schema-detail`）與可展開的 `Section.static`[`AppText.caption` × 2, `AppText.mono` × 2]（`panel-domain-schema-detail`） | 展開／收合（再次點擊或 Esc） | schema 不相容 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| collapsed | 依變體，詳情面板不存在 | 切換專案；`withDetail`：檢視詳情 | 呼叫端渲染 | 切換專案 → 浮層展開（覆蓋層，不改變本狀態）；檢視詳情 → expanded |
| expanded（`withDetail`） | 詳情面板出現於同一狀態根節點內，含 App 支援版本與專案版本兩值 | 同上 + 再次點擊 / Esc 收合 | 點擊檢視詳情 | 再次點擊 / Esc → collapsed（SPEC-003 §1.4、§2.10） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 切換專案 | 呼叫 `onSwitchProject`；呼叫端開啟 `SwitcherOverlay`（不改變 `IndexedStack` 索引，SPEC-003 §2.7） | `Motion.overlay`（浮層） | `Motion.feedback` |
| 檢視詳情 | `panel-domain-schema-detail` 出現／消失（SPEC-003 §3.1） | 高度變化 `Motion.transition` | `Motion.feedback` |
| Esc（expanded） | 面板收合，其餘狀態不變（SPEC-003 §2.10） | `Motion.transition` | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高），內容置中 |
| 最小尺寸 | 寬：`ButtonRow` 最小寬；高：訊息 + `LayoutSize.hitTargetMin` + 2 × `Space.sm` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 文字塊最大寬 `LayoutSize.detailPaneWidth` × 2；高無上限（展開面板加高） |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 3 | 末行截斷 | `schemaIncompatibleMessage`（appVersion / projectVersion 代入 `2.42.1`；en 較長）；`TestCopy.longZh` |
| `explanation` | 是 | 4 | 末行截斷 | `notFrameworkProjectExplanation`（zh 較長）；`TestCopy.longEn` |
| `version`（`plain` 的版本值） | 否 | 1 | 截斷 | 人工值 `2.42.1-rc.1+build.20260902`；`TestCopy.longToken` |
| 詳情面板兩值 | 否 | 1 | 截斷 | 同上 |
| 面板兩個小標 | 否 | 1 | 截斷 | `schemaAppVersionLabel`（en「Supported schema version」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`notFrameworkProjectMessage` / `schemaUnconsumableMessage` / `schemaIncompatibleMessage`） |
| `explanation` | `String?` | 否 | 呼叫端（`notFrameworkProjectExplanation`） |
| `version` | `String?` | 無可消費的型別表時必填（FR-07 顯示框架版本值） | 呼叫端（資料值） |
| `appVersion` / `projectVersion` | `String`（`withDetail`） | `withDetail` 必填 | 呼叫端（資料值） |
| `onSwitchProject` | `VoidCallback` | 是 | 不適用 |
| `isDetailExpanded` / `onToggleDetail` | `bool` / `VoidCallback`（`withDetail`） | `withDetail` 必填（展開狀態存於頁面層，§2 頁面狀態保留） | 不適用 |
| `testKey` | `Key` | 是（`state-domain-not-framework` / `state-domain-schema-unconsumable` / `state-domain-schema-incompatible`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 經 `AppText`、`AppButton`、`Section`；訊息 `AppColors.textTitle` |
| 間距 | 訊息、說明、版本值間 `Space.xs`；與動作列間 `Space.lg`；面板內距 `Space.md` |
| 字體 | 經 `AppText`（`subtitle`、`body`、`mono`、`caption`） |
| 圓角 | 面板 `Radius.md` |
| 動畫 | `Motion.transition`、`Motion.overlay` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 / 說明 | `notFrameworkProjectMessage` / `notFrameworkProjectExplanation` / `schemaUnconsumableMessage` / `schemaIncompatibleMessage`（既有，呼叫端傳入） |
| 切換專案 | `projectSwitcherEntryLabel`（既有，元件預設，參數可覆蓋） |
| 檢視詳情 | `viewSchemaDetailAction`（既有，元件預設） |
| 面板小標 | `schemaAppVersionLabel` / `schemaProjectVersionLabel`（元件預設） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息為 `Semantics.header`；版本值接續；檢視詳情按鈕 `expanded` 等於 `isDetailExpanded` |
| 狀態變化播報 | 進入本狀態時訊息以 `liveRegion` 播報一次；面板展開由 `expanded` 旗標播報 |
| 非視覺替代訊號 | 純文字 + 按鈕 |
| 焦點順序與操作路徑（桌機） | 兩顆按鈕進入 Tab 內容區段；Esc 收合面板；切換專案入口 `project-switcher-entry` 同時恆可用（SPEC-003 §2.7 斷言） |
| 對比 | 依 §4.0.2 表 1：說明與小標 `textSecondary` / `surfaceBase` 4.71:1、詳情 mono `textPrimary` / `surfaceBase` 5.79:1，皆通過；按鈕依 4.4 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `plain`（有／無版本值、有／無說明）與 `withDetail`（collapsed / expanded）
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息三行、說明四行末截斷、版本值截斷
- [ ] zh / en 四個訊息 key 皆不溢位
- [ ] 切換專案呼叫 `onSwitchProject` 恰一次；檢視詳情切換 `panel-domain-schema-detail` 存在性；expanded 下 Esc 收合
- [ ] `find.byKey(AppShell.projectSwitcherEntryKey)` 存在且 enabled（與殼整合的畫面測試承接）
- [ ] 間距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「此專案尚無圖譜節點」 | `EmptyState.page` |
| 以純檔案模式檢視（降級） | 0.1 不渲染；待 `0.1.0-W1-035` |

### 4.24 LoadingState

**用途**：骨架或進度 + 計數文字 + 取消；取消契約 C1–C8 與生命週期 L1–L2（SPEC-003 §2.5、§2.8，共 10 條）由本元件單一承擔，三處以「目標態」與「進度型別」參數差異化。
**內容角色**：內文（訊息 + 計數）+ 數值（進度）+ 動作（取消）。
**何時不用**：非狀態級的短暫等待（0.1 無，SPEC-003 §2.6）；按鈕內 spinner（禁止，§2.2）。
**出現畫面**：§1（載入中）、§4（載入中）、§5（掃描中）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `skeleton` | 骨架版位（`matrix` / `sections` slot）shimmer + indeterminate + 計數文字 | 分母未知：不顯示百分比、不顯示預估、不自行推進（SPEC-003 §2.6 誠實性硬規則） | `state-domain-loading`（版位 `matrix`）、`state-gaps-scanning`（版位 `sections`） |
| `progressBar` | determinate 進度條 + 已解析筆數／總數 N | 進度值 = parsed / total | `state-tickets-loading` |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| loading | 依變體；取消鈕 `AppButton.secondary` enabled，label `cancelLoadingAction` / `cancelScanAction` | 取消（C1：恆可用，含第一幀） | 呼叫端渲染 | 完成 → 目標正常態（呼叫端）；取消 → cancelling |
| cancelling | 版面不變、進度改 indeterminate、計數凍結於最後值（C3）；取消鈕 `enabled=false`、label `cancelInProgressAction`（C2） | 無 | 按下取消 | `Motion.cancelDeadline` 內抵達目標態（C4：`state-domain-unset` / `state-tickets-unloaded` / `returnTo` 或 `nav-page-domain`） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 按下取消 | `Motion.feedback` 內取消鈕 `enabled=false` 且文字換為取消中（C2）；呼叫 `onCancel` 恰一次（C8 冪等，連按 N 次狀態轉換只發生一次） | 無 | `Motion.feedback` |
| 取消進行中 | 逐幀骨架根錨點存在、無 SnackBar / Dialog（C3 斷言）；目標態於 `Motion.cancelDeadline` 內出現（C4）；不出現任何 SnackBar / Dialog / 錯誤標記（C5）；部分結果全數丟棄（C6）；再次觸發載入自 0 起算（C7） | 無 | `Motion.cancelDeadline` |
| 計數文字更新 | 兩次更新間隔不小於 `Motion.progressTick`；文字以 `liveRegion` 播報 | 無 | `Motion.progressTick` |
| 骨架 | shimmer 循環 `Motion.skeletonCycle`；`disableAnimations` 時靜態灰塊 | `Motion.skeletonCycle` | — |
| 最短顯示 | 一旦渲染至少存續 `Motion.spinnerMinVisible`（極小資料亦然） | — | `Motion.spinnerMinVisible` |
| 切換導覽項 | 任務繼續（L1）；回到畫面顯示當時進度 | — | — |
| 切換專案 | 任務中止，`Motion.cancelDeadline` 內完成、不留背景任務（L2） | — | `Motion.cancelDeadline` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（取消鈕） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高）；骨架版位填滿、進度條版本內容置中 |
| 最小尺寸 | 寬：訊息一字元 + 取消鈕；高：`LayoutSize.rowHeightRelaxed` × 3（骨架至少三列）+ `LayoutSize.hitTargetMin` |
| 最小命中區 | 取消鈕 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 無上限（骨架填滿） |
| `kMinWindowSize` 下的行為 | 維持（骨架列數隨高度裁切） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 否 | 1 | 截斷 | `domainLoading`（en「Resolving graph nodes…」）/ `gapReportScanning`；`TestCopy.longZh` |
| `countText` | 否 | 1 | 截斷 | `domainLoadingProcessedCount`（count 代入 99999）/ `ticketsLoadingProgress`；`TestCopy.longEn` |
| 取消鈕 label | 經 `AppButton` | | | `cancelLoadingAction`（en「Cancel loading」）、`cancelInProgressAction`（en「Cancelling…」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`domainLoading` / `gapReportScanning`；tickets 用 `ticketsLoadingProgress` 作 countText，message 可空） |
| `countText` | `String?` | 否 | 呼叫端（`domainLoadingProcessedCount` / `gapsScanningProcessedCount` / `ticketsLoadingProgress`） |
| `progress` | `double?`（`progressBar`：parsed / total） | `progressBar` 必填 | 不適用 |
| `skeletonLayout` | `SkeletonLayout { matrix, sections }`（`skeleton`） | `skeleton` 必填 | 不適用 |
| `isCancelling` | `bool` | 是（狀態存於頁面層） | 不適用 |
| `onCancel` | `VoidCallback` | 是 | 不適用 |
| `cancelLabel` | `String?` | 否 | 元件預設 `cancelLoadingAction`（強語意預設，gaps 覆蓋為 `cancelScanAction`）；取消中固定 `cancelInProgressAction` |
| `testKey` / `cancelKey` | `Key` | 是（`state-*-loading` / `state-gaps-scanning`；`action-*-cancel-load` / `action-gaps-cancel-scan`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceChip`（骨架塊）、`border`（進度軌）、`accent`（進度值）、經 `AppText` / `AppButton` |
| 間距 | 骨架列間 `Space.xs`；訊息、計數、取消鈕間 `Space.sm` |
| 字體 | 經 `AppText`（`body`、`caption`） |
| 圓角 | `Radius.sm`（骨架塊、進度條） |
| 動畫 | `Motion.feedback`、`Motion.cancelDeadline`、`Motion.progressTick`、`Motion.skeletonCycle`、`Motion.spinnerMinVisible` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 / 計數 | `domainLoading` / `gapReportScanning` / `domainLoadingProcessedCount` / `gapsScanningProcessedCount` / `ticketsLoadingProgress`（既有） |
| 取消 | `cancelLoadingAction` / `cancelScanAction` / `cancelInProgressAction`（既有） |
| 骨架朗讀 | `loadingSkeletonA11yLabel`；進度朗讀 `progressA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 骨架填滿；進度條版本置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 骨架區 `loadingSkeletonA11yLabel`；進度條 `progressA11yLabel`（parsed / total 代入）；取消鈕經 `AppButton` |
| 狀態變化播報 | 計數文字為 `liveRegion`（更新間隔 `Motion.progressTick`）；取消中由取消鈕 label 換文案播報 |
| 非視覺替代訊號 | 進度由文字計數承載，進度條顏色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 取消鈕進入 Tab 內容區段；C1 期間恆可聚焦 |
| 對比 | 依 §4.0.2 表 1：計數文字 `textSecondary` / `surfaceBase` 4.71:1，通過；取消鈕 enabled 與 cancelling 後的 disabled 依 4.4（disabled label `textDisabled` 屬非作用中元件豁免） |

#### 測試點（widget test）

- [ ] 一支測試渲染 `skeleton`（`matrix` / `sections`）× loading / cancelling 與 `progressBar` × loading / cancelling
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息與計數截斷
- [ ] zh / en 全部 key 皆不溢位
- [ ] C1–C8 逐條：第一幀取消鈕 enabled；按下後 `pump(Motion.feedback)` 取消鈕 disabled 且文字為 `cancelInProgressAction`；逐幀 `pump(16 ms)` 至 `Motion.cancelDeadline` 根錨點恆存在、無 SnackBar / Dialog；連按取消 `onCancel` 只呼叫一次
- [ ] indeterminate 情境畫面無 `%` 字元、無 `LinearProgressIndicator(value: 非 null)`；`progressBar` 的 value 等於 parsed / total
- [ ] `pump(Motion.feedback)` 後根錨點仍存在（最短顯示）；`disableAnimations` 為 `true` 時骨架靜態
- [ ] 顏色、間距、時間值引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 按鈕內的等待指示 | 禁止（SPEC-003 §2.2） |
| 「載入 N 張 ticket」的觸發前提示 | `LoadPrompt` |
| 重新整理單檔的等待 | 不套用（SPEC-003 §3.6：`Motion.cancelDeadline` 內直接抵達分支） |

### 4.25 LoadPrompt

**用途**：「載入 N 張 ticket」+ 開始載入（SPEC-001 §4 未載入）；不顯示預估耗時（SPEC-003 §3.4，依據待 `0.1.0-W1-037`）；返回由頁面框架承載（SPEC-003 §2.4）。
**內容角色**：內文 + 數值（N）+ 動作。
**何時不用**：沒有內容（`EmptyState`）；載入進行中（`LoadingState`）。
**出現畫面**：§4（未載入）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 訊息 `AppText.subtitle`（`ticketsLoadPrompt`，N 代入）+ `ButtonRow`[開始載入 `primary`] | 開始載入 | 呼叫端渲染（`state-tickets-unloaded`，首次可見） | 開始載入 → `state-tickets-loading`；返回（頁面框架的 `action-tickets-back`，`returnTo` 為 `null` 時不渲染）→ `returnTo` |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 開始載入（`action-tickets-start-load`） | 呼叫 `onStart`；`state-tickets-unloaded` 消失、`state-tickets-loading` 出現（SPEC-003 §3.4） | cross-fade `Motion.transition` | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高），內容置中 |
| 最小尺寸 | 寬：`ButtonRow` 最小寬；高：訊息一行 + `LayoutSize.hitTargetMin` + 2 × `Space.sm` |
| 最小命中區 | `LayoutSize.hitTargetMin` |
| 最大尺寸 | 文字塊最大寬 `LayoutSize.detailPaneWidth` × 2；高無上限 |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 2 | 末行截斷 | `ticketsLoadPrompt`（count 代入 1313；en 較長）；`TestCopy.longZh` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `count` | `int` | 是（訊息由元件預設 key 組字，參數 `message` 可覆蓋） | 元件預設 `ticketsLoadPrompt` |
| `onStart` | `VoidCallback` | 是 | 不適用 |
| `testKey` / `startKey` | `Key` | 是（`state-tickets-unloaded` / `action-tickets-start-load`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 經 `AppText`、`AppButton` |
| 間距 | 訊息與動作列間 `Space.lg` |
| 字體 | 經 `AppText` |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 | `ticketsLoadPrompt`（既有，元件預設） |
| 開始載入 | `startLoadAction`（既有，元件預設） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息為 `Semantics.header`；按鈕經 `AppButton` |
| 狀態變化播報 | 進入本狀態時訊息以 `liveRegion` 播報一次 |
| 非視覺替代訊號 | 純文字 + 按鈕 |
| 焦點順序與操作路徑（桌機） | 開始載入按鈕進入 Tab 內容區段 |
| 對比 | 依 §4.0.2（`textTitle` / `surfaceBase` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染單一狀態（count 1 與 99999）
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案兩行末截斷
- [ ] zh / en 兩個 key 皆不溢位
- [ ] 開始載入呼叫 `onStart` 恰一次；畫面中不存在 `%`、無預估耗時文字（SPEC-003 FR-07）
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「此專案尚無 ticket」 | `EmptyState.page` |
| 顯示預估耗時 | 禁止（SPEC-003 §2.6 誠實性硬規則） |

### 4.26 AppSnackBar

**用途**：「已在外部開啟」「找不到檔案」類的暫時訊息；Material 預設進出動畫不覆寫（SPEC-003 §2.2）。
**內容角色**：內文 + 可選動作。
**何時不用**：狀態改變本身即為結果（不用 SnackBar）；取消完成（C5 禁止）；持續性錯誤標示（`IssueMarker`）。
**出現畫面**：§1、§2、§5、§6。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `plain` | 文字 | 停留 `Motion.snackBar` | 已在外部開啟、檔案仍不存在 |
| `withAction` | 文字 + 一個動作（`AppButton.text` 形態） | 停留 `Motion.snackBarWithAction` | 找不到檔案 + 重新整理／重新掃描 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| shown | 依變體 | `withAction`：動作 | 呼叫端 `show` | 停留時間到、動作觸發、新的 SnackBar 取代 → dismissed |
| dismissed | 不存在 | 無 | 上述退出 | 不適用：靜止（下一次 `show` 重新進入） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 顯示 | `find.byType(SnackBar)` 為 `findsOneWidget`，文字等於指定 key 的值（SPEC-003 §2.2） | Material 預設進出，不覆寫 | 停留 `Motion.snackBar` / `Motion.snackBarWithAction` |
| 動作點選 | 呼叫 `onAction`（重新整理 / 重新掃描），SnackBar 即時消失 | Material 預設 | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（`withAction` 的動作） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | Material `SnackBar` 預設（浮於內容區底部，寬依內容） |
| 最小尺寸 | 寬：一字元 + 內距；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | 動作 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：主區寬 − 2 × `Space.xl`；高：文字兩行 |
| `kMinWindowSize` 下的行為 | 維持（文字換行至兩行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 2 | 末行截斷 | `sourceFileStillMissingMessage`（en「File still not found」）；`TestCopy.longEn` |
| 動作 label | 否 | 1 | 截斷 | `refreshAction` / `rescanAction`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`openedExternallyMessage` / `sourceFileNotFoundSnackbarMessage` / `sourceFileStillMissingMessage`） |
| `actionLabel` / `onAction` | `String` / `VoidCallback`（`withAction`） | `withAction` 必填 | 呼叫端（`refreshAction` / `rescanAction`） |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textTitle`（底，反色）、`surfaceBase`（文字）、`accent`（動作） — 提案，SPEC-003 未定 SnackBar 配色 |
| 間距 | 內距 `Space.md`；文字與動作間 `Space.sm` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.snackBar`、`Motion.snackBarWithAction`（停留）；進出動畫 Material 預設 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 | `openedExternallyMessage` / `sourceFileNotFoundSnackbarMessage` / `sourceFileStillMissingMessage`（既有，呼叫端傳入） |
| 動作 | `refreshAction` / `rescanAction`（既有） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | 不放入任何容器：經 `ScaffoldMessenger` 顯示於 `AppShell` 主區（覆蓋層，非佈局子件） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | Material 預設（底部置中） |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息以 `liveRegion` 播報（Material `SnackBar` 內建）；動作為 button |
| 狀態變化播報 | 出現即播報一次 |
| 非視覺替代訊號 | 純文字 |
| 焦點順序與操作路徑（桌機） | `withAction` 的動作可 Tab 到（停留期間）；不搶奪焦點 |
| 對比 | 依 §4.0.2（`surfaceBase` / `textTitle` 約 14:1，通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染 `plain` / `withAction`
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息兩行末截斷、動作 label 截斷
- [ ] zh / en 五個 key 皆不溢位
- [ ] `pump(Motion.snackBar)` 後 `plain` 消失；`withAction` 於 `Motion.snackBar` 後仍存在、`Motion.snackBarWithAction` 後消失；動作點選呼叫 `onAction` 恰一次
- [ ] 停留時間引用 `Motion` token 非字面值

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 取消完成的告知 | 禁止（C5） |
| 原始檔已消失的持續狀態 | `MissingSourceState` |
| 損壞標示 | `IssueMarker` |

### 4.27 AppShell（容器）

**用途**：根框架容器：標題列 / 側欄（`ProjectSwitcherEntry` + `NavItem` × 6）/ 主區（`PageColumn` × 6 於 `IndexedStack`）三格；承載視窗邊緣內距與專案切換覆蓋層；為 `ConsumerWidget`（§2）。既有 `lib/app/shell.dart` 為其實作雛形，漂移項（側欄寬、導覽項圖示、選中底色、標題列高）由 W1-005 對齊。
**內容角色**：容器（標題列另有一個標題 slot）。
**何時不用**：頁面內的區塊排列（`PageColumn` / `Panel`）。
**出現畫面**：殼。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 三格 + 當前可見頁 | 導覽、專案切換入口、內容區 | App 啟動（落地 `nav-page-domain`，SPEC-003 §2.8） | 開啟浮層 → overlayOpen |
| overlayOpen | `SwitcherOverlay` 覆蓋於側欄入口下方；背景導覽項不可點、焦點限制於浮層（SPEC-003 §3.7、§2.10） | 浮層內操作、Esc、點外部 | `project-switcher-entry` 或阻擋狀態出口 | 收合 → default |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| Tab | 三區段依序：入口 → 六個導覽項 → 內容區（SPEC-003 §2.10；區段內依 `ReadingOrderTraversalPolicy`） | — | — |
| 返回鍵 | 讀 `returnToProvider`，非 `null` 時把 `action-<screen>-back`（`AppButton.secondary`，`backAction`）注入當前 `PageColumn` 的頁面級動作列（SPEC-003 §2.4；W1-031） | — | `Motion.feedback` |
| 首次可見訊號 | `selectedDestinationProvider` 改變時對首次成為 index 的頁發出（provider 層 visited set，W1-031） | — | — |
| 視窗尺寸變更 | 不重置任何狀態；捲動容器 offset 夾在新範圍（SPEC-003 §2.8） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：本容器自身無可點元素（互動由子件承載）；鍵盤三區段路徑見互動反應 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿視窗 |
| 最小尺寸 | `kMinWindowSize`（macOS `minSize`） |
| 最小命中區 | 不適用（容器） |
| 最大尺寸 | 無（可最大化） |
| 標題列高 | `LayoutSize.titleBarHeight`（36；`shell.dart` 現行 Material `AppBar` 預設高屬漂移，待實作票對齊） |
| 側欄寬 | `LayoutSize.sidebarWidth` |
| `kMinWindowSize` 下的行為 | 維持（側欄固定寬，主區吸收剩餘寬；不切換版型，§1） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `title`（標題列，`AppText.body` `emphasis`；畫布 12px，§3.1 原記 `AppText.title` 屬筆誤） | 否 | 1 | 截斷 | `appTitle`（zh「專案文件流」/ en「Docs Flow」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `title` | `String` | 是 | 元件預設 `appTitle`（參數可覆蓋） |
| `switcherEntry` | `ProjectSwitcherEntry` | 是（恰 1） | 不適用 |
| `navItems` | `List<NavItem>` | 是（恰 6，依 `AppDestination.values` 順序） | 不適用 |
| `pages` | `List<PageColumn>` | 是（恰 6，與 `navItems` 同序） | 不適用 |
| `overlay` | `SwitcherOverlay?` | 否（overlayOpen 時存在） | 不適用 |
| `testKey` | `Key` | 是（`app-shell`，`AppShell.shellKey`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceChip`（標題列底，畫布）、`surfaceSidebar`（側欄底）、`border`（側欄與主區分隔線、標題列底邊）、`borderStrong`（標題列底邊，畫布） |
| 間距 | 側欄內距 `Space.md`（垂直）× `Space.sm`（水平）；入口與導覽項間 `Space.sm`；標題列水平內距 `Space.md` |
| 字體 | 經 `AppText` |
| 圓角 | 無 |
| 動畫 | `Motion.overlay`（浮層，由 `SwitcherOverlay` 承載） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 標題 | `appTitle`（既有） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | 根：無父容器 |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 標題列上、側欄左、主區填滿 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 標題列為 `Semantics.header`；側欄與主區以 `Semantics(container: true)` 分組並以 `appTitle` / 當前頁名（`nav*`）為 label |
| 狀態變化播報 | 切頁時當前頁的 `PageTitle` header 承載播報；本容器不另播報 |
| 非視覺替代訊號 | 不適用顏色訊號 |
| 焦點順序與操作路徑（桌機） | 三區段 Tab 順序（SPEC-003 §2.10）；overlayOpen 時焦點限制於浮層 |
| 對比 | 依 §4.0.2（標題文字 `textPrimary` / `surfaceChip` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / overlayOpen
- [ ] `kMinWindowSize` 與 `kDesignSize` 下三格皆不溢位；側欄寬等於 `LayoutSize.sidebarWidth`
- [ ] 標題最長測試文案截斷
- [ ] zh / en `appTitle` 不溢位
- [ ] Tab 序列依三區段；overlayOpen 時 Tab 不離開浮層；`returnTo` 非 `null` 時 `action-<screen>-back` 存在、`null` 時不存在
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 頁面內的頁首與內容排列 | `PageColumn` |
| 在頁面內自畫側欄或第二層導覽 | 禁止（0.1 單層導覽） |

### 4.28 PageColumn（容器）

**用途**：每頁根堆疊：`SplitRow.header`（頁首）+ 內容（`Panel` / `TwoColumnLayout` / 狀態元件）垂直；內容區內距 `Space.xl`；為 `AppShell` 之下的頁面框架，承載頁面級動作列（返回、重新掃描、開啟原始檔）。
**內容角色**：容器。
**何時不用**：面板內的垂直堆疊（`Panel`）。
**出現畫面**：§1–§6。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 頁首 + 內容 | 由子件承載 | 建構（`IndexedStack` 一次建構六頁） | 不適用：容器無自身狀態集；畫面狀態由內容 slot 的狀態元件承載 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 內容 slot 換件（狀態轉換） | cross-fade `Motion.transition`（SPEC-003 各 §3.x 動畫提示）；`disableAnimations` 時一幀抵達 | `Motion.transition` | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（主區寬與高） |
| 最小尺寸 | 寬：`kMinWindowSize.width` − `LayoutSize.sidebarWidth`；高：`kMinWindowSize.height` − 標題列高 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無 |
| `kMinWindowSize` 下的行為 | 維持（內容 slot 吸收剩餘高） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（文字皆在子件） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `header` | `SplitRow.header` | 是（恰 1） | 不適用 |
| `content` | `Panel` \| `Panel.scrollable` \| `TwoColumnLayout` \| `EmptyState.page` \| `BlockedState` \| `LoadingState` \| `LoadPrompt` \| `MissingSourceState` | 是（恰 1） | 不適用 |
| `testKey` | `Key` | 是（`nav-page-<destination>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceSidebar`（頁面底，畫布主區底色） |
| 間距 | 內容區內距 `Space.xl` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `AppShell`（主區 `IndexedStack`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 頁首上緣、內容填滿 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics(container: true)`，label 為頁名（`nav*`）；非可見頁（`IndexedStack` 非 index）排除於語意樹 |
| 狀態變化播報 | 內容 slot 換件時由新內容的 header / liveRegion 承載 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 內容區段：頁首右側動作列先於內容（閱讀順序） |
| 對比 | 不適用（容器無文字） |

#### 測試點（widget test）

- [ ] 一支測試以八種內容 slot 各渲染一次
- [ ] 兩種視窗尺寸下不溢位；內容 slot 高等於本容器高 − 頁首高 − 2 × `Space.xl`
- [ ] 無自有文字（本項不適用）
- [ ] 內容換件後 `pump(Motion.transition)` 抵達；`disableAnimations` 時一幀抵達
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 面板內的區塊堆疊 | `Panel` |
| 頁面自畫返回鍵 | 禁止（由 `AppShell` 經本容器的頁面級動作列注入） |

### 4.29 SplitRow（容器）

**用途**：左右兩端對齊的水平列：頁首（`PageTitle` + 右側控制）、Ticket 清單摘要底列、格詳情卡標題列（標題 + 關閉）。
**內容角色**：容器。
**何時不用**：多於兩個子件的水平排列（`Toolbar` / `ButtonRow` / `BadgeRow`）；欄寬對齊的列（`TableRow`）。
**出現畫面**：§1–§6（`header`）、§4（`footer`）、§1 詳情卡（`header`）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `header` | 高 `LayoutSize.headerHeight`、底邊框 `AppColors.border`、底 `surfaceBase`；詳情卡內不套固定高與邊框（`compactHeader` 修飾參數） | 無 | 頁首、詳情卡標題列 |
| `footer` | 高 `LayoutSize.rowHeightRelaxed`、頂邊框 | 無 | Ticket 清單摘要底列 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 左格 + 右格 | 由子件承載 | 建構 | 不適用：容器無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 容器自身無互動 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定（依變體） |
| 最小尺寸 | 寬：左格最小寬（一字元 + 省略號）+ `Space.md` + 右格固有寬；高：依變體 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬無上限；高依變體 |
| `kMinWindowSize` 下的行為 | 維持（左格吸收剩餘寬並截斷） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `leading` | `PageTitle` \| `AppText`（`body` / `subtitle`） | 是（恰 1） | 不適用 |
| `trailing` | `SegmentedControl` \| `ButtonRow` \| `AppText`（`caption`）\| `AppButton.text` \| 空 | 否（恰 0..1） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border` |
| 間距 | 水平內距 `Space.xl`（頁首）/ `Space.sm`（底列、詳情卡）；左右格最小間距 `Space.md` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（頁首 slot）、`Panel`（底列、詳情卡首格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 兩格垂直置中；左格 `start`、右格 `end` |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 無自有標籤；子件依序（左先右後） |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 右格的可點子件依閱讀順序在左格文字之後 |
| 對比 | 不適用（容器無文字） |

#### 測試點（widget test）

- [ ] 一支測試渲染 `header`（右格：`SegmentedControl` / `ButtonRow` × 3 / 空）與 `footer`
- [ ] 兩種視窗尺寸下不溢位；右格固有寬不變、左格截斷
- [ ] 無自有文字（本項不適用）
- [ ] 高等於變體指定 token
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 搜尋框 + 多個下拉 | `Toolbar` |
| leading + 主文字 + trailing 的清單列 | `ListRow` |

### 4.30 Panel（容器）

**用途**：白底、邊框、圓角、內距的垂直堆疊；所有內容區塊的表面。
**內容角色**：容器。
**何時不用**：兩欄並排（`TwoColumnLayout`）；頁面根（`PageColumn`）；無表面的分節（`Section`）。
**出現畫面**：§1–§6。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 無捲動 | 子件中恰一個為填滿高的資料視圖或狀態元件，吸收剩餘高 | 矩陣、泳道、Ticket 列表、UC 步驟表 |
| `scrollable` | 主體垂直捲動（`scroll-*` 錨點） | 子件總高超過面板高時捲動 | 追溯樹、破洞分節、主題分節、節點詳情主欄與右欄、格詳情卡 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 表面 + 子件 | `scrollable`：捲動 | 建構 | 不適用：容器無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 捲動（`scrollable`） | `ScrollController.offset` 改變；內容不足一屏時 offset 維持 0 且不拋錯（SPEC-003 §1.1）；與其他捲動區不連動（FR-10、§1.1 連動禁令） | 無 | — |
| 視窗尺寸變更 | offset 夾在新範圍，不歸零（SPEC-003 §2.8） | — | — |
| 排序 / 換選 | offset 歸零由呼叫端經 controller 執行（SPEC-003 §3.4、§3.1） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `scrollable`：滾輪 / 觸控板捲動、捲軸拖曳、鍵盤（容器聚焦後 PageUp / PageDown / 方向鍵為 Flutter 預設；方向鍵不列入 0.1 下界） | 像素級（連續） | 足夠 | 捲軸 | 視覺（捲軸指示） |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬與高） |
| 最小尺寸 | 寬：2 × `Space.md` + 子件最小寬的最大值；高：2 × `Space.md` + `LayoutSize.rowHeightRelaxed` |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無 |
| `kMinWindowSize` 下的行為 | 維持（`scrollable` 捲動；`default` 資料視圖自行捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `children` | 具名清單：`Toolbar` \| `SplitRow` \| `DataTable` \| `MatrixGrid` \| `SwimlaneGrid` \| `Tree` \| `Section` \| `BadgeRow` \| `Divider` \| `AppText` \| `DocumentBody` \| `ListRow` \| `EmptyState.section` \| `ButtonRow`（順序即堆疊順序；`default` 變體中資料視圖恰 1） | 是（1..12） | 不適用 |
| `scrollKey` | `Key`（`scrollable`） | `scrollable` 必填（`scroll-<screen>-<area>`） | 不適用 |
| `panelKey` | `Key?` | 否（`panel-domain-cell-detail` / `panel-domain-cell-detail-empty`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`（底）、`border`（邊框） |
| 間距 | 內距 `Space.md`（§3.7 第 13 項統一）；子件最小間距 `Space.sm`（§3.4 三處記 `Space.sm` / `Space.lg`，收斂為 `Space.sm`，提案） |
| 字體 | 無 |
| 圓角 | `Radius.lg` |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot）、`TwoColumnLayout`（主欄 / 右欄） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件填滿寬、依序堆疊、上緣對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics(container: true)`；`scrollable` 為 scrollable 語意節點 |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | `scrollable` 容器可聚焦（SPEC-003 §2.10 內容區段含捲動容器）；子件依堆疊順序 |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `default`（含一個填滿高資料視圖）與 `scrollable`（子件總高超過與不足一屏）
- [ ] 兩種視窗尺寸下不溢位；`scrollable` 超出時 drag 後 offset 改變、不足時 offset 為 0 且無錯誤
- [ ] 無自有文字（本項不適用）
- [ ] 兩個獨立 `Panel.scrollable` 並排時捲動互不影響
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 主欄 + 右欄並排 | `TwoColumnLayout` |
| 分節（節首 + 項目） | `Section` |

### 4.31 TwoColumnLayout（容器）

**用途**：主欄 `Panel`（填滿）+ 右欄 `Panel.scrollable`（固定寬 `LayoutSize.detailPaneWidth`）水平並排；兩欄各自獨立捲動（SPEC-003 FR-10、§1.1 連動禁令）。右欄常駐不隱藏（SPEC-001 §1 註記）。
**內容角色**：容器。
**何時不用**：單一面板（`Panel`）；三欄以上（0.1 無）。
**出現畫面**：§1（正常·矩陣、已選格）、§6（正常、部分損壞）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（右欄寬單一值，§3.7 第 21 項） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 兩欄 | 由子件承載 | 建構 | 不適用：容器無自身狀態集（右欄內容的提示／詳情卡切換是右欄 `Panel` 子件換件，非本容器狀態） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 主欄捲動 | 右欄 offset 不變；反之亦然（SPEC-003 §1.1 #8/#9、#1/#11） | — | — |
| 右欄內容換件（提示 ↔ 詳情卡、換選） | cross-fade `Motion.transition`；主欄寬不變、主欄 offset 不變（SPEC-003 §3.1） | `Motion.transition` | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高） |
| 最小尺寸 | 寬：主欄最小寬 + `Space.md` + `LayoutSize.detailPaneWidth`；高：`Panel` 最小高 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無（主欄吸收；右欄固定） |
| `kMinWindowSize` 下的行為 | 維持（右欄固定寬，主欄壓縮並由其資料視圖二維捲動承受） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `main` | `Panel` \| `Panel.scrollable` | 是（恰 1） | 不適用 |
| `detail` | `Panel.scrollable`（§1 與 §6 皆為可捲動，W1-048） | 是（恰 1） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 無（表面由 `Panel` 承載） |
| 間距 | 兩欄間 `Space.md` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |
| 尺寸 | `LayoutSize.detailPaneWidth` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `PageColumn`（內容 slot） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 兩欄上緣對齊、等高 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 兩欄各為 `Semantics(container: true)`；右欄 label 由其首個 header（詳情卡標題）承載 |
| 狀態變化播報 | 右欄換件由詳情卡標題 header 播報 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 主欄先、右欄後（閱讀順序） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染單一變體（主欄含資料視圖、右欄含 `EmptyState.section` 與詳情卡兩種內容）
- [ ] 兩種視窗尺寸下不溢位；右欄寬恆等於 `LayoutSize.detailPaneWidth`
- [ ] 無自有文字（本項不適用）
- [ ] 主欄 drag 後右欄 offset 不變，反之亦然；右欄換件後主欄寬與 offset 不變
- [ ] 間距與寬度引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 選格時才出現右欄 | 禁止（SPEC-001 §1 右欄常駐） |
| 側欄 + 主區 | `AppShell` |

### 4.32 Toolbar（容器）

**用途**：`SearchField`（填滿）+ `FilterDropdown` × N + `IssueMarker.damagedDetail`（可點損壞計數，§3.7 第 14 項）水平；底邊框。
**內容角色**：容器。
**何時不用**：頁面級動作（`SplitRow.header` 右格 `ButtonRow`）；徽章列（`BadgeRow`）。
**出現畫面**：§4。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 子件一列 | 由子件承載 | 建構 | 不適用：容器無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 容器自身無互動 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定 `LayoutSize.hitTargetMin` + 2 × `Space.xs` |
| 最小尺寸 | 寬：`SearchField` 最小寬 + Σ `FilterDropdown` 固有寬 + `IssueMarker` 寬 + (N + 1) × `Space.sm` |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬無上限；高固定 |
| `kMinWindowSize` 下的行為 | 維持（`SearchField` 吸收剩餘寬；5.6 不觸發公式） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `search` | `SearchField` | 是（恰 1，首格） | 不適用 |
| `filters` | `List<FilterDropdown>` | 是（1..3） | 不適用 |
| `marker` | `IssueMarker.damagedDetail?` | 否（含損壞疊加態時存在，末格靠右） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.borderStrong`（底邊框，畫布） |
| 間距 | 子件最小間距 `Space.sm`；底部內距 `Space.sm` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel`（首格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics(container: true)`，label 由子件承載 |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 搜尋 → 篩選 × N → 損壞計數（閱讀順序） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 N = 1 / 2 / 3 × 有無 `marker`
- [ ] 兩種視窗尺寸下不溢位；`SearchField` 寬等於剩餘寬
- [ ] 無自有文字（本項不適用）
- [ ] 子件兩兩邊界盒不相交
- [ ] 間距與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 重新掃描 / 返回等頁面級按鈕 | `SplitRow.header` 右格 `ButtonRow` |
| 徽章列 | `BadgeRow` |

### 4.33 BadgeRow（容器）

**用途**：`Badge` × N 水平、空間不足換行；節點詳情標籤列、矩陣與泳道圖例列、事件標籤列、步驟表事件欄。
**內容角色**：容器。
**何時不用**：按鈕列（`ButtonRow`）；單一徽章（直接放入所在列的格位）。
**出現畫面**：§1、§2、§6。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 無邊框 | 無 | 標籤列、事件標籤 |
| `legend` | 頂邊框 `AppColors.border`、頂部內距 `Space.sm` | 無（間距同 `default`，§3.7 第 12 項） | 面板底部圖例列 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 一列或多列徽章 | 無（子件非互動） | 建構 | 不適用：容器無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 容器與子件皆無互動 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬）；高固有（列數 × 徽章高 + (列數 − 1) × `Space.xs`） |
| 最小尺寸 | 寬：最寬單一徽章的最小寬；高：一列 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬：父格位寬；高無上限（換行） |
| `kMinWindowSize` 下的行為 | 維持（換行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `children` | `List<Badge>` | 是（0..無上限；空時不渲染） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`（`legend` 頂邊） |
| 間距 | 子件最小間距 `Space.xs`（水平與列間）；`legend` 頂部內距 `Space.sm` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel`、`TableRow.step`（事件欄）、`Panel.scrollable`（詳情卡） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件 `start` 對齊、每列垂直置中 |
| 作為表格或列表的一欄時 | 填滿欄（`TableRow.step` 事件欄 flex）；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 子件依序唸出；本容器無自有標籤 |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（子件非互動） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `default` / `legend` × 0 / 1 / 20 個徽章
- [ ] 兩種視窗尺寸下不溢位；20 個徽章於受限寬度換為多列
- [ ] 無自有文字（本項不適用）
- [ ] 子件兩兩邊界盒不相交
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 一列按鈕 | `ButtonRow` |
| 篩選觸發器 | `Toolbar` |

### 4.34 ButtonRow（容器）

**用途**：`AppButton` × 1..3 水平；狀態元件動作區、頁首右側頁面級動作區（§3.7 第 17、18 項）、格詳情卡動作區。
**內容角色**：容器。
**何時不用**：徽章列（`BadgeRow`）；單一 `AppButton.text` 於浮層末格（直接放入 `SwitcherOverlay`）。
**出現畫面**：§1–§6。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；`alignment` 參數（`start` / `center` / `end`） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 一列或換行的按鈕 | 由子件承載 | 建構 | 不適用：容器無自身狀態集 |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 不適用 | 容器自身無互動 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（Σ 按鈕寬 + (N − 1) × `Space.sm`）；父格位寬不足時換行 |
| 最小尺寸 | 寬：最寬單一按鈕的最小寬（`LayoutSize.hitTargetMin`）；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | 不適用（子件各自） |
| 最大尺寸 | 寬：父格位寬；高：3 列 × `LayoutSize.hitTargetMin` + 2 × `Space.sm` |
| `kMinWindowSize` 下的行為 | 維持（換行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `children` | `List<AppButton>` | 是（1..3；`primary` 至多 1 且置於首位） | 不適用 |
| `alignment` | `start` / `center` / `end` | 否（預設 `start`；狀態元件內 `center`、頁首右格 `end`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 無 |
| 間距 | 子件最小間距 `Space.sm`（水平與列間） |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SplitRow.header`（右格）、`Panel.scrollable`（詳情卡末格）；作為 `EmptyState` / `BlockedState` / `LoadingState` / `LoadPrompt` / `MissingSourceState` 的內部動作區 |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 依 `alignment`；子件垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 無自有標籤；子件依序 |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 子件依閱讀順序（`primary` 先） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 N = 1 / 2 / 3 × 三種 `alignment`
- [ ] 兩種視窗尺寸下不溢位；父寬受限至單一按鈕寬時換為三列且子件兩兩不相交
- [ ] 無自有文字（本項不適用）
- [ ] 子件最長測試文案下仍不相交
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 四個以上動作 | 禁止（0.1 上限 3；出現需求走待決出口） |
| 徽章列 | `BadgeRow` |

### 4.35 TableRow（容器）

**用途**：欄寬對齊表頭的水平格線列；`header`（欄首）、`ticket`（票列，列表與主題模式共用欄序 ID / 標題 / 狀態 / 優先 / 標記，§3.7 第 15 項）、`step`（序號 / 步驟名 / domain / 事件）。
**內容角色**：容器。
**何時不用**：主文字填滿的清單列（`ListRow`）；二維格線（`MatrixGrid`）。
**出現畫面**：§2、§4。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `header` | 底邊框 `AppColors.borderStrong`；格為 `TableColumnHeader` | 無 | 表頭 |
| `ticket` | 底邊框 `AppColors.border`；格：`AppText.mono`（ID）、`AppText.body`（標題）、`Badge.status`（inline）、`AppText.caption`（優先）、`IssueMarker.damagedDetail?`（標記） | 整列可點 → 開票（`card-tickets-<ticketId>`） | Ticket 清單列表與主題模式 |
| `step` | 底邊框 `AppColors.border`；格：`StepNumber`、`AppText.body`（步驟名）、`RelationItem`（domain，`isMono=false`）、`BadgeRow`（事件） | 整列可點 → 節點詳情（`card-ucFlow-step-<stepId>`）；domain 格另有自己的點擊 | UC Flow 步驟表 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 一列格 | `ticket` / `step`：點選整列 | 建構 | 不適用：容器無自身狀態集 |
| hover / pressed / focused（`ticket` / `step`） | 依 §4.0.1（整列） | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選列（`ticket`） | 呼叫 `onTap`；jump 至 `nav-page-nodeDetail`，`returnTo` 設為 `tickets`（SPEC-003 §3.4） | 無 | `Motion.feedback` |
| 點選列（`step`） | 呼叫 `onTap`；jump 至 `nav-page-nodeDetail`，`returnTo` 設為 `ucFlow`（SPEC-003 §3.2） | 無 | `Motion.feedback` |
| 點選 domain 格（`step`） | 由 `RelationItem` 承載（4.19），不觸發列點擊 | 無 | `Motion.feedback` |
| 點選標記格（`ticket`） | 由 `IssueMarker` 承載（4.6），不觸發列點擊 | 無 | `Motion.feedback` |
| drag | 不可拖曳；觸發所在 `DataTable` 捲動（SPEC-003 §1.3） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `ticket` / `step`：依 §4.0.7 點選列（整列為一個 Tab 停留點；格內的 `RelationItem` / `IssueMarker` 另為停留點）；`header`：不適用 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定 `LayoutSize.rowHeightRelaxed` |
| 最小尺寸 | 寬：Σ 固定寬欄 + 填滿欄最小寬（一字元 + 省略號）+ (欄數 − 1) × `Space.md`；高：`LayoutSize.rowHeightRelaxed` |
| 最小命中區 | `ticket` / `step` 整列高 `LayoutSize.rowHeightRelaxed` ≥ `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬無上限；高固定 |
| 欄規格（`ticket`） | ID 固定寬 `LayoutSize.ticketIdColumnWidth`（132）、標題填滿、狀態 `LayoutSize.ticketStatusColumnWidth`（84）、優先 `LayoutSize.ticketPriorityColumnWidth`（40）、標記 `LayoutSize.ticketMarkerColumnWidth`（22） |
| 欄規格（`step`） | 序號 `LayoutSize.stepNumberColumnWidth`（26）、步驟名填滿、domain `LayoutSize.stepDomainColumnWidth`（118）、事件填滿（兩個填滿欄等分，畫布 `1fr 118px 1fr`） |
| `kMinWindowSize` 下的行為 | 維持（填滿欄截斷） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（格文字依各子件契約：ID `TestCopy.nodeId`、標題 `TestCopy.nodeTitle`、步驟名 `TestCopy.stepName`） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `columns` | `List<ColumnSpec>`（`fixed(LayoutSize.*)` / `flex(n)`），由 `DataTable` 統一傳入 | 是 | 不適用 |
| `cells` | 依變體固定型別序列（見變體表）；上限 = 欄數（`ticket` 5、`step` 4、`header` N ≤ 5） | 是 | 不適用 |
| `onTap` | `VoidCallback`（`ticket` / `step`） | 是 | 不適用 |
| `testKey` | `Key`（`card-tickets-<ticketId>` / `card-ucFlow-step-<stepId>`） | `ticket` / `step` 必填 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border` / `borderStrong`（底邊）、`surfaceBase` |
| 間距 | 欄最小間距 `Space.md`；列水平內距 `Space.sm` |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | `Motion.feedback` |
| 尺寸 | `LayoutSize.rowHeightRelaxed`；固定寬欄 token（`0.1.0-W1-055` 已建） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字（欄首文字見 4.14） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `DataTable`（`header` 恰 1 + 資料列 × N）、`Section.collapsible`（主題節內 `ticket` × N） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 格垂直置中；文字欄 `start`、優先欄 `start`、序號欄置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `ticket` / `step`：`Semantics.button`，label 為各格文字依序串接（ID，標題，狀態，優先）；`header`：各格 header |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 損壞由 `IssueMarker` 標籤承載 |
| 焦點順序與操作路徑（桌機） | 列為 Tab 停留點；列內可點格緊接其後；Space / Enter 開票 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染三個變體（`ticket` 含 / 不含標記；`step` 事件欄 0 / 5 個徽章）
- [ ] 兩種視窗尺寸下不溢位；固定寬欄寬等於 token、填滿欄截斷
- [ ] 無自有文字（本項不適用）；格子件以其最長測試文案渲染
- [ ] 列點選呼叫 `onTap` 恰一次；點 domain 格不觸發列 `onTap`
- [ ] 格兩兩邊界盒不相交
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 樹列、分節首、破洞項 | `ListRow` |
| 矩陣列 | `MatrixGrid` |

### 4.36 DataTable（容器，資料視圖）

**用途**：`TableRow.header` + `TableRow` × N 垂直；Ticket 清單為虛擬捲動（`scroll-tickets-list`），UC Flow 為一般捲動（`scroll-ucFlow-steps`）。得為 `ConsumerWidget`（§2 資料視圖例外）。
**內容角色**：容器。
**何時不用**：二維格線（`MatrixGrid`）；依深度縮排的列（`Tree`）；分節（`Section`）。
**出現畫面**：§2、§4。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `virtual` | 同 | 列以 `ListView.builder` + 固定 `itemExtent`（`LayoutSize.rowHeightRelaxed`）虛擬化；不分頁 | Ticket 清單（真實規模不低於 1300 筆） |
| `plain` | 同 | 一般 `ListView` | UC Flow 步驟表 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 表頭 + 列 | 捲動、列點選、排序（表頭） | 建構（資料由 provider `select` 訂閱） | 不適用：容器無自身狀態集（空資料由畫面改渲染 `EmptyState`，本容器不承載 empty） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 捲動 | offset 改變；`virtual` 捲至末端不拋 framework 錯誤（SPEC-003 §3.4） | 無 | — |
| 排序 / 篩選後 | offset 歸零（排序）；篩選後列集合改變、offset 保留（SPEC-003 §3.4 只對排序歸零） | 無逐列入場動畫（SPEC-003 §3.4） | — |
| 首次渲染 | 不做逐列入場動畫 | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 滾輪 / 觸控板捲動、捲軸拖曳；列點選見 4.35 | 像素級 | 足夠 | 捲軸 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高，`Panel.default` 的填滿高子件） |
| 最小尺寸 | 寬：`TableRow` 最小寬；高：表頭 + 一列 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無 |
| `kMinWindowSize` 下的行為 | 維持（垂直捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `columns` | `List<ColumnSpec>` | 是 | 不適用 |
| `header` | `TableRow.header` | 是（恰 1，釘選於頂） | 不適用 |
| `rows` | `List<TableRow>`（`ticket` 或 `step`，單一變體）或 builder | 是（0..無上限） | 不適用 |
| `scrollKey` | `Key` | 是（`scroll-tickets-list` / `scroll-ucFlow-steps`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 無（由 `TableRow` 承載） |
| 間距 | 列間 0（以 `TableRow` 底邊框分隔）；最小間距記為邊框線寬（§4.0.3） |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | 無 |
| 尺寸 | `LayoutSize.rowHeightRelaxed`（`itemExtent`） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.default` |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 表頭與列的欄邊界對齊（同一 `columns`） |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | scrollable 語意節點；表頭格 header；列為 button |
| 狀態變化播報 | 列數變化由 `SplitRow.footer` 摘要文字承載 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 表頭可排序格 → 列依序（虛擬化下焦點移至未建構列時自動捲入，Flutter `ensureVisible`） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `virtual`（1313 列假資料）與 `plain`（39 列）
- [ ] 兩種視窗尺寸下不溢位；`virtual` drag 至末端無錯誤且 offset 改變
- [ ] 無自有文字（本項不適用）
- [ ] 表頭與首列的欄邊界 x 座標相等
- [ ] 元件票驗收以真實規模假資料做 Profiler 抽查（§2 高頻檢核）
- [ ] 尺寸引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 分頁 | 禁止（SPEC-001 §4 虛擬捲動不分頁） |
| 主題模式的分節 | `Section.collapsible` |

### 4.37 MatrixGrid（容器，資料視圖）

**用途**：domain × UC 二維格線：欄首 `TableColumnHeader.twoLine`、列首 `AppText`（可點選 domain，`action-domain-select-<domainId>`）、格 `MatrixCell`、小計 `AppText.caption`；欄首與列首釘選、二維捲動（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`，依賴宣告待 `0.1.0-W1-038`）。得為 `ConsumerWidget`。
**內容角色**：容器。
**何時不用**：一維表格（`DataTable`）；泳道（`SwimlaneGrid`）。
**出現畫面**：§1。
**層級**：L3

> **UC 欄寬 `LayoutSize.matrixColumnWidth`（122）已核定**（PM 2026-09-02，見 §3.7 第 24 項；推算依據見 `lib/tokens/layout.dart` dartdoc〈MatrixGrid UC 欄寬定案〉）。dartdoc 內「待 PM 核定」字樣由 MatrixGrid 元件票代入時同步移除。

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 格線，無高亮列 | 點格、點列首、捲動 | 建構 | 點格或點列首 → rowSelected |
| rowSelected | 該列（列首 + 格 + 小計）底 `AppColors.surfaceIconTint` | 同上 + Esc（有選格時） | `selectedDomainId` 非 `null` | 點另一列列首 → 高亮移動（選格清除）；切換專案 → default |

選格（`MatrixCell.selected`）為格的狀態，與本容器 rowSelected 連動：選格時所在列高亮；列高亮唯一（SPEC-003 §3.1「右欄內容須與高亮列一致」）。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點列首 | 呼叫 `onSelectDomain`；該列高亮；已選格若在他列則清除、右欄回提示；同列則選格不變（SPEC-003 §3.1） | 無 | `Motion.feedback` |
| 點格 | 由 `MatrixCell` 承載（4.15）；本容器同步列高亮 | 無 | `Motion.feedback` |
| Esc（有選格） | 呼叫 `onClearSelection`；焦點停在原格、offset 不變（SPEC-003 §2.10） | `Motion.transition`（右欄） | — |
| 二維捲動 | 水平與垂直 offset 皆改變；列首與欄首釘選；已選格捲離 viewport 時選中態與右欄不變（SPEC-003 §3.1） | 無 | — |
| 首次渲染 | 不做逐格入場動畫（SPEC-003 §3.1） | — | — |
| 自泳道切回 | offset 還原（SPEC-003 §3.1「矩陣的捲動 offset 被保留」） | — | — |
| 視窗尺寸變更 | 以左上角為錨定保留 offset（SPEC-003 §3.1） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 二維滾輪 / 觸控板捲動、雙軸捲軸拖曳；列首點選依 §4.0.7 | 像素級 | 足夠 | 雙軸捲軸 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高） |
| 最小尺寸 | 寬：`LayoutSize.matrixLeadColumnWidth` + `LayoutSize.matrixColumnWidth`（122，§3.7 第 24 項已核定） + `LayoutSize.matrixSubtotalWidth`；高：欄首列高（`TableColumnHeader.twoLine`）+ `LayoutSize.rowHeightRelaxed` |
| 最小命中區 | 列首格高 `LayoutSize.rowHeightRelaxed` ≥ `LayoutSize.hitTargetMin` |
| 最大尺寸 | 無（內容超出即二維捲動） |
| 欄規格 | 列首 `LayoutSize.matrixLeadColumnWidth`；UC 欄 `LayoutSize.matrixColumnWidth`（122，§3.7 第 24 項已核定） × N；小計 `LayoutSize.matrixSubtotalWidth` |
| `kMinWindowSize` 下的行為 | 維持（二維捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 列首 domain 名（`AppText.body` `emphasis`） | 否 | 1 | 截斷 | `TestCopy.domainName`；`TestCopy.longToken` |
| 小計（`AppText.caption`） | 否 | 1 | 不截斷（數字） | 人工值 `999` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `columnHeaders` | `List<TableColumnHeader.twoLine>` | 是（1..無上限） | 不適用 |
| `rows` | `List<MatrixRow{domainName, cells: List<MatrixCell>, subtotal: int}>` | 是（1..無上限；每列 `cells` 長度 = 欄數） | 列首文字為資料值 |
| `selectedDomainId` / `selectedCell` | `String?` / `(rowId, colId)?` | 是（狀態存於 provider） | 不適用 |
| `onSelectDomain` / `onClearSelection` | callback | 是 | 不適用 |
| `scrollKey` | `Key` | 是（`scroll-domain-matrix`） | 不適用 |

列首格由本容器包成可點（`InkWell` + `action-domain-select-<domainId>`），為容器內部互動區，非獨立元件。

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceIconTint`（列高亮）、`border`（欄首底邊）、`surfaceBase` |
| 間距 | 列最小間距 `Space.xxs`；格內距 `Space.xs`；欄首底部內距 `Space.sm` |
| 字體 | 經子件 |
| 圓角 | `Radius.md`（高亮列） |
| 動畫 | 無（釘選與捲動無動畫） |
| 尺寸 | `LayoutSize.matrixLeadColumnWidth` / `matrixSubtotalWidth` / `rowHeightRelaxed`；UC 欄寬 `LayoutSize.matrixColumnWidth`（122，§3.7 第 24 項已核定） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 小計朗讀 | `matrixSubtotalA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.default`（主欄） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 欄首與格的欄邊界對齊；列首與格垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 二維 scrollable 語意節點；列首格 `Semantics.button`，label 為「{domain}，`matrixSubtotalA11yLabel`」，`selected` 等於是否高亮列；格見 4.15 |
| 狀態變化播報 | 列高亮由列首 `selected` 旗標播報 |
| 非視覺替代訊號 | 列高亮由 `selected` 旗標承載 |
| 焦點順序與操作路徑（桌機） | 依閱讀順序：欄首（不可焦點）→ 每列列首 → 該列各格；Esc 清除選格（SPEC-003 §2.10） |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / rowSelected × 有無選格
- [ ] 兩種視窗尺寸下不溢位；二維 drag 後兩軸 offset 改變；列首與欄首 rect 不隨 offset 改變
- [ ] 列首最長測試文案截斷
- [ ] 資料值不溢位
- [ ] 點另一列列首後選格清除；Esc 後選格清除且焦點停在原格、offset 不變
- [ ] 元件票驗收以真實規模假資料做 Profiler 抽查
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 步驟表 | `DataTable.plain` |
| 逐格入場動畫 | 禁止（SPEC-003 §3.1） |

### 4.38 SwimlaneGrid（容器，資料視圖）

**用途**：泳道列（`AppText` 泳道名 + `SwimlaneNode` 置於步驟欄）× N 垂直、列間虛線；底部步驟箭頭列（裝飾）；0.1 以寫死座標的假資料靜態排版（SPEC-001 設計約束）；二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`）。得為 `ConsumerWidget`。
**內容角色**：容器。
**何時不用**：矩陣（`MatrixGrid`）；有布局演算法的泳道（0.1 之後）。
**出現畫面**：§1（泳道）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 泳道列 + 節點 | 捲動、拖曳 | 建構（已選定一條 UC） | 不適用：容器無自身狀態集（選中 domain 的列高亮由 `laneHighlight` 參數呈現，非本容器狀態） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 拖曳（`drag-domain-swimlane`） | 內容平移量等於位移，比例 1:1；至內容邊界生硬停止（無回彈）；無慣性；與捲軸共用同一 offset（SPEC-003 §1.3） | 無 | — |
| 捲動（`scroll-domain-swimlane`） | offset 改變 | 無 | — |
| 自詳情卡「在泳道中檢視」進入 | `jumpTo` 使該格對應泳道列 rect 與 viewport 有交集（不用 `animateTo`，SPEC-003 §3.1） | 無 | — |
| 對節點 drag | 節點不移動，觸發畫布平移（SPEC-003 §1.3） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 指標按住拖曳畫布、滾輪 / 觸控板二維捲動、雙軸捲軸 | 像素級 | 足夠 | 捲軸（拖曳的等價路徑） | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高） |
| 最小尺寸 | 寬：`LayoutSize.laneLabelWidth` + 一個步驟欄寬（假資料座標）；高：`LayoutSize.laneRowHeight` |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無（二維捲動） |
| 列高 | `LayoutSize.laneRowHeight` |
| 步驟欄寬 | 由假資料座標決定（SPEC-001 設計約束「寫死座標」），不設 token |
| `kMinWindowSize` 下的行為 | 維持（二維捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 泳道名（`AppText.body`） | 否 | 1 | 截斷 | `TestCopy.domainName`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `lanes` | `List<Lane{name, nodes: List<(SwimlaneNode, column)>}>` | 是（1..無上限） | 泳道名為資料值 |
| `laneHighlight` | `String?`（選中 domain） | 否 | 不適用 |
| `scrollKey` / `dragKey` | `Key` | 是（`scroll-domain-swimlane` / `drag-domain-swimlane`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.borderStrong`（列間虛線）、`surfaceIconTint`（高亮列）、`textDisabled`（底部箭頭列，純裝飾且排除於語意樹，§4.0.2 表 2） |
| 間距 | 節點與欄邊最小間距 `Space.xs`；泳道名內距 `Space.sm` |
| 字體 | 經子件 |
| 圓角 | 無 |
| 動畫 | 無 |
| 尺寸 | `LayoutSize.laneLabelWidth` / `laneRowHeight` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 泳道朗讀 | `laneA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.default`（主欄） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 節點於步驟欄置中、於列垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 二維 scrollable 語意節點；每列 `laneA11yLabel`；箭頭列排除於語意樹 |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 節點 active 由 4.16 朗讀承載 |
| 焦點順序與操作路徑（桌機） | 容器可聚焦後以捲軸 / 滾輪捲動；節點不可焦點（0.1 無節點動作） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染單一變體（6 泳道 × 6 步驟假資料）
- [ ] 兩種視窗尺寸下不溢位；drag `Offset(dx, dy)` 後內容平移量等於位移；至邊界後再 drag 不再改變
- [ ] 泳道名最長測試文案截斷
- [ ] 資料值不溢位
- [ ] `jumpTo` 目標列 rect 與 viewport 相交
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 排序、泳道指派、邊繞線 | 0.1 不做（SPEC-001 設計約束） |
| 橡皮筋回彈 | 禁止（SPEC-003 §1.3） |

### 4.39 Tree（容器，資料視圖）

**用途**：`ListRow.tree` × N 垂直，依深度縮排；展開收合改變列集合（`scroll-traceability-tree`）。得為 `ConsumerWidget`。
**內容角色**：容器。
**何時不用**：無層級的清單（`Section` / `DataTable`）。
**出現畫面**：§3。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 可見列集合（依展開集合） | 展開收合、點節點、捲動 | 建構 | 不適用：容器無自身狀態集（展開集合存於 provider） |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 展開收合（`expander-traceability-<nodeId>`） | 子層列出現或消失；offset 不歸零（SPEC-003 §3.3） | 子層高度變化 `Motion.transition`；`disableAnimations` 時瞬間 | — |
| 點節點 | 由 `ListRow.tree` 承載：jump 至節點詳情，`returnTo` 設為 `traceability` | 無 | `Motion.feedback` |
| 缺口列 | `IssueMarker.gap` 靜態、可點跳轉破洞報告（SPEC-003 §3.3） | 無 | — |
| 切換專案 | 展開集合清空、offset 歸零（SPEC-003 §3.3） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 捲動（滾輪 / 捲軸）；列與展開器點選見 4.40 / 4.18 | 像素級 | 足夠 | 捲軸 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固有（由 `Panel.scrollable` 捲動） |
| 最小尺寸 | 寬：最深層縮排 + `ListRow.tree` 最小寬；高：一列 `LayoutSize.rowHeightDense` |
| 最小命中區 | 不適用 |
| 最大尺寸 | 無 |
| 每層縮排 | `LayoutSize.treeIndent`（24；四層：PROP / SPEC / UC / Ticket） |
| `kMinWindowSize` 下的行為 | 維持（列主文字截斷） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（列文字見 4.40） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `nodes` | 樹狀 `List<TreeNode{row: ListRow.tree, depth, children}>`，深度上限 4 | 是（1..無上限） | 不適用 |
| `expanded` | `Set<String>`（存於 provider） | 是 | 不適用 |
| `onToggle` | `ValueChanged<String>` | 是 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 無（列承載） |
| 間距 | 列最小間距 0（列高固定，以 `rowHeightDense` 承載留白）；縮排 `LayoutSize.treeIndent`（24） |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |
| 尺寸 | `LayoutSize.rowHeightDense` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 層級朗讀 | `treeDepthA11yLabel` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.scrollable` |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 列左緣依深度縮排；同層對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 每列附 `treeDepthA11yLabel`（depth 代入）；展開狀態由 4.18 承載 |
| 狀態變化播報 | 子層出現由 `expanded` 旗標播報 |
| 非視覺替代訊號 | 層級由朗讀的深度承載，縮排非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 可見列依序（展開器 → 列本體 → 缺口標記） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染四層 × 全收合 / 全展開 / 含缺口列
- [ ] 兩種視窗尺寸下不溢位；展開後 drag offset 改變；展開收合不歸零
- [ ] 無自有文字（本項不適用）
- [ ] 第 n 層列左緣 x = n × 縮排 token
- [ ] 尺寸引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 主題分節 | `Section.collapsible` |
| 缺口閃爍動畫 | 禁止（SPEC-003 §3.3） |

### 4.40 ListRow（容器）

**用途**：leading（可選）+ 主文字 `AppText`（填滿）+ 次文字 `AppText`（可選，堆疊於主文字下）+ trailing（可選）水平列。
**內容角色**：容器。
**何時不用**：欄寬對齊表頭的列（`TableRow`）；浮層專案項（`RecentProjectItem`）。
**出現畫面**：§1（詳情卡步驟）、§3（樹節點）、§4（主題節首）、§5（分節首、破洞項）、§6（節點 meta 列）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `tree` | leading `ExpanderIcon`、主文字 `AppText.body`（PROP 層 `emphasis`）、trailing `Badge.status` 或 `IssueMarker.gap`；高 `LayoutSize.rowHeightDense` | 整列可點 → 節點詳情（`card-traceability-<nodeId>`） | 追溯樹列 |
| `sectionHeader` | leading `ExpanderIcon` 或 `Badge.category`、主文字 `AppText.body`（`emphasis`，`accentStrong`）、trailing `AppText.caption`（計數 / 摘要）；高 `rowHeightDense` | 展開由 leading `ExpanderIcon` 承載；列本體不可點 | 主題節首、破洞類別節首 |
| `item` | 主文字 `AppText.body` + 次文字 `AppText.caption` 堆疊、trailing `AppIcon`（外開箭頭，`openExternallyA11yLabel`）；頂邊框；高固有（兩行） | 整列可點 → 外部開啟並定位（`card-gaps-<itemId>`） | 破洞項 |
| `meta` | leading `Badge.type`、主文字 `AppText.mono`（路徑）；高 `rowHeightDense` | 無 | 節點詳情 meta 列 |
| `numbered` | leading `StepNumber`、主文字 `AppText.body`；高 `rowHeightDense` | 無 | 格詳情卡步驟清單 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| default | 依變體 | `tree` / `item`：點選列；`sectionHeader`：展開器 | 建構 | 不適用：容器無自身狀態集 |
| hover / pressed / focused（`tree` / `item`） | 依 §4.0.1（整列） | 點選 | | |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 點選列（`tree`） | 呼叫 `onTap`；jump 至 `nav-page-nodeDetail`，`returnTo` 設為 `traceability`（SPEC-003 §3.3） | 無 | `Motion.feedback` |
| 點選列（`item`） | 呼叫 `onTap`；以系統預設方式開啟原始檔並定位；SnackBar 告知已開啟；檔案不存在時 `AppSnackBar.withAction`（重新掃描）（SPEC-003 §3.5；外部開啟下界待 `0.1.0-W1-036`） | 無 | `Motion.feedback` |
| 點 leading 展開器（`tree` / `sectionHeader`） | 由 `ExpanderIcon` 承載，不觸發列點擊 | `Motion.transition`（容器承載） | `Motion.feedback` |
| 點 trailing `IssueMarker.gap`（`tree`） | 由 `IssueMarker` 承載，不觸發列點擊 | 無 | `Motion.feedback` |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `tree` / `item`：依 §4.0.7 點選列；`sectionHeader` / `meta` / `numbered`：不適用（列本體無互動，互動在 leading / trailing 子件） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定（`rowHeightDense`）或固有（`item` 兩行 + 2 × `Space.sm`） |
| 最小尺寸 | 寬：leading 寬 + `Space.sm` + 一字元 + `Space.sm` + trailing 寬；高：`LayoutSize.rowHeightDense`（≥ `LayoutSize.hitTargetMin`） |
| 最小命中區 | `tree` / `item`：整列高 |
| 最大尺寸 | 寬無上限；高：`item` 兩行 |
| `kMinWindowSize` 下的行為 | 維持（主文字截斷，兩端固定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（主文字 / 次文字 / trailing 依 `AppText` 各變體契約：主文字 `TestCopy.nodeTitle` / `TestCopy.topicName` / `TestCopy.gapTitle`、次文字 `TestCopy.gapDescription`、trailing `topicSectionSummary` / `gapSectionCount`） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `leading` | `ExpanderIcon` \| `AppIcon` \| `Badge` \| `StepNumber` | 依變體（`tree` / `sectionHeader` / `meta` / `numbered` 必填） | 不適用 |
| `primary` | `AppText`（`body` / `mono`） | 是（恰 1，填滿） | 文字由呼叫端 |
| `secondary` | `AppText.caption` | `item` 必填，其餘不接受 | 文字由呼叫端 |
| `trailing` | `Badge` \| `AppIcon` \| `AppText.caption` \| `IssueMarker` | 否（恰 0..1） | 文字由呼叫端 |
| `onTap` | `VoidCallback`（`tree` / `item`） | 該兩變體必填 | 不適用 |
| `testKey` | `Key`（`card-traceability-<nodeId>` / `card-gaps-<itemId>`） | 該兩變體必填 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`（`item` 頂邊）、`accentStrong`（`sectionHeader` 主文字） |
| 間距 | 子件最小間距 `Space.sm`；`item` 主次文字間 `Space.xxs`、垂直內距 `Space.sm` |
| 字體 | 經 `AppText` |
| 圓角 | `Radius.sm`（hover / 焦點區） |
| 動畫 | `Motion.feedback` |
| 尺寸 | `LayoutSize.rowHeightDense` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `item` trailing 朗讀 | `openExternallyA11yLabel` |
| `sectionHeader` trailing | `topicSectionSummary` / `gapSectionCount`（呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Tree`（`tree`）、`Section`（`sectionHeader` 節首、`item` 項目）、`Panel` / `Panel.scrollable`（`meta`、`numbered`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件垂直置中；`item` 以上緣（次文字換行時） |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `tree` / `item`：`Semantics.button`，label 為主文字 + 次文字 + trailing 文字；`sectionHeader`：`Semantics.header`；`meta` / `numbered`：依序唸出子件 |
| 狀態變化播報 | 不適用（展開由 4.18 承載） |
| 非視覺替代訊號 | 由子件承載 |
| 焦點順序與操作路徑（桌機） | leading 可點子件 → 列本體（可點變體）→ trailing 可點子件 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染五個變體 × leading / trailing 有無
- [ ] 兩種視窗尺寸下不溢位；主文字截斷、兩端子件寬不變
- [ ] 無自有文字（本項不適用）；子件以最長測試文案渲染
- [ ] `tree` / `item` 列點選呼叫 `onTap` 恰一次；點 leading 展開器不觸發列 `onTap`
- [ ] 子件兩兩邊界盒不相交
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 票列（欄對齊） | `TableRow.ticket` |
| 浮層專案項 | `RecentProjectItem` |

### 4.41 Section（容器）

**用途**：節首 + 項目垂直堆疊：主題節（`ListRow.sectionHeader` + `TableRow.ticket` × N）、破洞類別節（`ListRow.sectionHeader` + `ListRow.item` × N）、關聯群（`AppText.caption` + `RelationItem` × N）、schema 詳情面板（`AppText.caption` × 2 + `AppText.mono` × 2）。
**內容角色**：容器。
**何時不用**：有層級縮排的樹（`Tree`）；帶表面的堆疊（`Panel`）。
**出現畫面**：§1（詳情面板）、§4、§5、§6。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `collapsible` | 節首為 `ListRow.sectionHeader`（含 `ExpanderIcon`） | 收合時項目不渲染（`expander-tickets-topic-<name>` / `expander-gaps-<category>`） | 主題節、破洞類別節 |
| `static` | 節首為 `AppText.caption` | 恆展開 | 關聯群、schema 詳情面板 |

修飾參數：`dashedTop`（頂部虛線 `AppColors.borderStrong`，「未歸屬」節）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| expanded | 節首 + 項目 | 收合（`collapsible`） | 預設 | 點展開器 → collapsed |
| collapsed（`collapsible`） | 只有節首 | 展開 | 點展開器 | 點展開器 → expanded |

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 展開收合 | 項目出現或消失；`scroll-tickets-topics` / `scroll-gaps-sections` offset 不歸零（SPEC-003 §3.4、§3.5） | 高度變化 `Motion.transition`；`disableAnimations` 時瞬間 | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動（展開器見 4.18） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固有 |
| 最小尺寸 | 寬：節首最小寬；高：節首一列 |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬無上限；高無上限（由 `Panel.scrollable` 捲動） |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（`static` 節首為 `AppText.caption`，文案如關聯群名 `implements`、`schemaAppVersionLabel`） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `header` | `ListRow.sectionHeader`（`collapsible`）\| `AppText.caption`（`static`） | 是（恰 1） | 文字由呼叫端 |
| `items` | `List<TableRow.ticket>` \| `List<ListRow.item>` \| `List<RelationItem>` \| `List<AppText>`（單一型別） | 是（0..無上限；0 時只渲染節首） | 不適用 |
| `isExpanded` / `onToggle` | `bool` / `VoidCallback`（`collapsible`，狀態存於 provider） | `collapsible` 必填 | 不適用 |
| `dashedTop` | `bool` | 否 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.borderStrong`（`dashedTop` 虛線） |
| 間距 | 子件最小間距 `Space.xxs`；`dashedTop` 上方內距 `Space.sm`；schema 詳情面板底 `surfaceChip`、內距 `Space.md`（4.23 承載） |
| 字體 | 無 |
| 圓角 | 無 |
| 動畫 | `Motion.transition` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 不適用 | 無自有文字（未歸屬節首文字 `ticketsUnassignedSection` 由呼叫端傳入節首） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Panel.scrollable`（節 × N，節間距由 `Panel` 的 `Space.sm` 承載）；作為 `BlockedState.withDetail` 的內部面板 |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 節首與項目左緣對齊；主題節內票列縮排 `Space.xl`（畫布 22，提案歸 `Space.xl`） |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 節首為 `Semantics.header`；項目依序 |
| 狀態變化播報 | 展開由 `ExpanderIcon` 的 `expanded` 旗標播報 |
| 非視覺替代訊號 | 「未歸屬」由節首文字承載，虛線非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 節首展開器 → 項目依序 |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `collapsible`（expanded / collapsed、0 / 50 項、`dashedTop`）與 `static`
- [ ] 兩種視窗尺寸下不溢位；50 項置於 `Panel.scrollable` 可捲至末端
- [ ] 無自有文字（本項不適用）
- [ ] 收合後項目不存在於元件樹；展開收合不改變父捲動 offset
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 四層追溯樹 | `Tree` |
| 表頭對齊的表格 | `DataTable` |

### 4.42 SwitcherOverlay（容器）

**用途**：專案切換覆蓋層：`AppText.caption` 標題 + `RecentProjectItem` × N（垂直捲動 `scroll-switcher-recent`）+ `Divider` + `AppButton.text`（選擇其他資料夾）；自入口向下展開，Esc / 點外部收合，焦點限制於浮層內。
**內容角色**：容器（另有標題 slot）。
**何時不用**：任何其他覆蓋表面（0.1 唯一 overlay，§1 覆蓋表面對映）。
**出現畫面**：§7（展開、無最近專案）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；零項時只渲染標題 + `AppButton.text`（`state-switcher-no-recent`，訊息 `switcherChooseFolderPrompt` 作為按鈕 label） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 |
|------|------|---------|---------|---------|
| expanded（`state-switcher-expanded`） | 標題 + 專案項 + 分隔線 + 選擇其他 | 選專案、選資料夾、Esc、點外部、捲動 | `project-switcher-entry` 或阻擋狀態出口 | 選取 → 收合並重載；Esc / 點外部 → 收合（SPEC-001 §7） |
| noRecent（`state-switcher-no-recent`） | 標題 + 選擇其他 | 選資料夾、Esc | 首次使用（無最近專案） | 選取 → 收合並載入；Esc → 收合 |

收合態不是本容器的狀態（本容器不存在），由 `ProjectSwitcherEntry` 承載。

#### 互動反應

| 互動 | 反應 | 動畫 | 時間門檻 |
|------|------|------|---------|
| 展開 | 淡入 + 自入口向下展開 | `Motion.overlay` | — |
| 收合 | 反向；焦點回到 `project-switcher-entry`（Esc） | `Motion.overlay` | — |
| 點外部 | 收合；不改變當前專案（SPEC-003 §3.7） | `Motion.overlay` | — |
| 選擇其他（`action-switcher-choose-folder`） | 開啟系統資料夾選擇器；選定後收合並載入；取消則維持展開（SPEC-003 §3.7） | `Motion.overlay` | `Motion.feedback` |
| 選取專案 | 先收合（`Motion.overlay`），再由 Domain 視圖轉入載入態；兩段不重疊 | `Motion.overlay` | — |
| 捲動 | offset 改變；收合後不保留（下次展開自頂端，SPEC-003 §3.7） | 無 | — |
| 展開期間 | 背景導覽項不可點；Tab 不離開浮層（SPEC-003 §2.10） | — | — |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 捲動（滾輪 / 捲軸）；項目與按鈕點選依 §4.0.7；Esc 收合 | 像素級 | 足夠 | 捲軸 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固定寬 `LayoutSize.overlayWidth`；高固有，有上限 |
| 最小尺寸 | 寬：`LayoutSize.overlayWidth`；高：標題 + `AppButton.text` + 2 × `Space.sm` |
| 最小命中區 | 不適用（子件各自） |
| 最大尺寸 | 高：入口下緣至視窗下緣 − `Space.xl`（超出即清單捲動） |
| 錨定 | 左緣 = 側欄內距 `Space.sm`（畫布 12 → `Space.md`，提案取 `Space.md`）；上緣 = 入口下緣 + `Space.xxs` |
| `kMinWindowSize` 下的行為 | 維持（清單捲動） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `title`（`AppText.caption`） | 否 | 1 | 截斷 | `switcherTitle`（en「Switch project」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `title` | `String` | 否 | 元件預設 `switcherTitle`（參數可覆蓋） |
| `items` | `List<RecentProjectItem>` | 是（0..無上限） | 不適用 |
| `chooseOther` | `AppButton.text` | 是（恰 1；label 由呼叫端：`switcherChooseOtherFolder` / 零項時 `switcherChooseFolderPrompt`） | 不適用 |
| `onDismiss` | `VoidCallback` | 是 | 不適用 |
| `testKey` / `scrollKey` | `Key` | 是（`state-switcher-expanded` / `state-switcher-no-recent`；`scroll-switcher-recent`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`（底）、`borderStrong`（邊框） |
| 間距 | 內距 `Space.sm`；子件最小間距 `Space.xxs`；標題內距 `Space.xs` × `Space.sm` |
| 字體 | 經子件 |
| 圓角 | `Radius.lg` |
| 動畫 | `Motion.overlay` |
| 尺寸 | `LayoutSize.overlayWidth` |

陰影：Material `elevation` 預設（畫布 box-shadow 不入 token，提案）。

#### i18n

| 文字 | i18n key |
|------|---------|
| 標題 | `switcherTitle` |
| 選擇其他 | `switcherChooseOtherFolder` / `switcherChooseFolderPrompt`（既有，呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `AppShell`（overlay slot，`Overlay` / `Stack` 之上；非佈局流中的子件） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件填滿寬、依序堆疊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics(container: true, scopesRoute: true)`，label 為 `switcherTitle`；標題為 header |
| 狀態變化播報 | 展開時焦點移入浮層（首個可聚焦項）並唸出標題；收合時焦點回入口 |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 焦點限制於浮層（`FocusScope` + `FocusTraversalGroup`）；Tab 依序：項目 × N → 選擇其他；Esc 收合 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染 expanded（1 / 5 / 50 項）與 noRecent
- [ ] 兩種視窗尺寸下不溢位；50 項於 `kMinWindowSize` 高度內可捲動且高不超過上限
- [ ] 標題最長測試文案截斷
- [ ] zh / en 三個 key 皆不溢位
- [ ] Esc 呼叫 `onDismiss` 且焦點回到入口；點外部呼叫 `onDismiss`；Tab 序列不含浮層外元件；收合再展開 offset 為 0
- [ ] 寬、圓角、動畫引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 以 `showDialog` / `AlertDialog` 呈現（既有 `shell.dart` 空殼） | 本容器（W1-005 對齊） |
| schema 詳情面板 | `BlockedState.withDetail` 內展開 |

---

## 5. 容器元件

> 決定多個元件如何相對排列的佈局結構皆為元件，須有第 4 章的條目；本章補容器專屬的排列不變式與子件契約。
> 頁面直接用原生佈局原語（水平 / 垂直堆疊、格線）排列元件視同自製元件。
>
> **本章狀態：已填（`0.1.0-W1-044.2`）。** §3.4 排列關係表 25 列逐列核對：每列的容器候選皆對應本章一條（殼層兩列 → 5.1；頁首 → 5.3；面板三列 → 5.4；矩陣列併入 5.11；圖例 → 5.7；詳情卡 → 5.4 + 5.14 + 5.7；泳道 → 5.12；工具列 → 5.6；表頭與資料列 → 5.9；表格 → 5.10；底列 → 5.3；主題節與破洞節 → 5.15；節首與破洞項 → 5.14；樹 → 5.13 + 5.14；主欄 → 5.4 + 5.14 + 5.7；右欄 → 5.4 + 5.15；浮層 → 5.16；動作區 → 5.8；schema 詳情面板 → 5.15）。
> 「可用寬 / 高」指所在父格位扣除父容器內距後的尺寸；公式中的最小寬 / 高引用第 4 章各元件的尺寸契約。二次歸併結論：策略填定後無兩個容器同時滿足「子件類型 + 方向 + 策略」相同，§3.5 的歸併結果維持。

### 5.1 AppShell

**對應第 4 章條目**：4.27

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 標題列：`AppText`；側欄：`ProjectSwitcherEntry`、`NavItem`；主區：`PageColumn`（`IndexedStack`，一次顯示一頁）；覆蓋層：`SwitcherOverlay` |
| 子件數量上限 | 標題列 1；側欄 1 + 6；主區 6；覆蓋層 0..1（合計上限 15） |
| 安全區 | 無 SafeArea 需求（§1 禁放區與安全區列：macOS 視窗無瀏海與手勢區）；視窗邊緣內距由本容器承載：側欄內距 `Space.md`（垂直）× `Space.sm`（水平）、標題列水平內距 `Space.md`、主區內距交由 `PageColumn`（`Space.xl`） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 標題列、側欄、主區三個區域互斥（垂直：標題列 / 主體；主體水平：側欄 / 主區）；側欄內子件垂直堆疊兩兩不相交；覆蓋層允許疊於側欄與主區之上（覆蓋層非佈局流子件）；測試以兩種尺寸 × 上限驗證 |
| 最小間距 | 側欄：入口與導覽項間 `Space.sm`，導覽項間 `Space.xxs`；側欄與主區以邊框線相接（§4.0.3 線寬）；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 7（側欄）；`LayoutSize.titleBarHeight`（36）+ 2 × `Space.md` + `ProjectSwitcherEntry` 高 + `Space.sm` + 6 × `NavItem` 高 + 5 × `Space.xxs` ≤ `kMinWindowSize.height`；主區寬 = 視窗寬 − `LayoutSize.sidebarWidth` ≥ `PageColumn` 最小寬 |

### 5.2 PageColumn

**對應第 4 章條目**：4.28

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `SplitRow.header`；內容：`Panel` \| `Panel.scrollable` \| `TwoColumnLayout` \| `EmptyState.page` \| `BlockedState` \| `LoadingState` \| `LoadPrompt` \| `MissingSourceState` |
| 子件數量上限 | 2（頁首 1 + 內容 1） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 頁首與內容垂直互斥；內容區 = 主區高 − `LayoutSize.headerHeight` − 2 × `Space.xl` |
| 最小間距 | 頁首與內容間 `Space.xl`（內容區內距）；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 2；`LayoutSize.headerHeight` + 2 × `Space.xl` + 內容最小高（`Panel` 最小高 = 2 × `Space.md` + `LayoutSize.rowHeightRelaxed`）≤ 主區高（`kMinWindowSize.height` − 標題列高） |

### 5.3 SplitRow

**對應第 4 章條目**：4.29

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | leading：`PageTitle` \| `AppText`；trailing：`SegmentedControl` \| `ButtonRow` \| `AppText.caption` \| `AppButton.text` |
| 子件數量上限 | 2（leading 1 + trailing 0..1） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | leading 填滿剩餘寬並截斷、trailing 固有寬；兩者水平互斥 |
| 最小間距 | `Space.md`；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 2；trailing 固有寬 + `Space.md` + leading 最小寬（一字元 + 省略號）≤ 可用寬；trailing 為 `ButtonRow` 時其自身以換行承載（5.8），本列高隨之增加至多 3 列 |

### 5.4 Panel

**對應第 4 章條目**：4.30

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `Toolbar`、`SplitRow`、`DataTable`、`MatrixGrid`、`SwimlaneGrid`、`Tree`、`Section`、`BadgeRow`、`Divider`、`AppText`、`DocumentBody`、`ListRow`、`EmptyState.section`、`ButtonRow` |
| 子件數量上限 | `default`：12（其中資料視圖恰 1）；`scrollable`：無上限（`Section` × N、`ListRow.numbered` × N） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 子件垂直堆疊、填滿寬，兩兩不相交；`default` 中資料視圖吸收剩餘高 |
| 最小間距 | `Space.sm`；內距 `Space.md`；呼叫端不得覆寫 |
| 空間不足策略 | `default`：不觸發：上限 12；Σ 固有高子件的高 + (n − 1) × `Space.sm` + 2 × `Space.md` + 資料視圖最小高 ≤ 可用高（資料視圖自行捲動吸收其內容）。`scrollable`：捲動（垂直，`scroll-<screen>-<area>`）；觸發條件：Σ 子件高 + (n − 1) × `Space.sm` > 可用高 − 2 × `Space.md` |

### 5.5 TwoColumnLayout

**對應第 4 章條目**：4.31

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | main：`Panel` \| `Panel.scrollable`；detail：`Panel.scrollable` |
| 子件數量上限 | 2 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 兩欄水平互斥、等高；右欄寬恆 `LayoutSize.detailPaneWidth` |
| 最小間距 | `Space.md`；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 2；`LayoutSize.detailPaneWidth` + `Space.md` + 主欄最小寬 ≤ 可用寬（= 視窗寬 − `LayoutSize.sidebarWidth` − 2 × `Space.xl`）；主欄最小寬 = 2 × `Space.md` + 其資料視圖最小寬（§6：`DocumentBody` 一字元；§1：`MatrixGrid` 最小寬，含 `matrixColumnWidth`（122，已核定），5.11） |

### 5.6 Toolbar

**對應第 4 章條目**：4.32

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `SearchField`、`FilterDropdown`、`IssueMarker.damagedDetail` |
| 子件數量上限 | 5（搜尋 1 + 篩選 1..3 + 標記 0..1） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 單列水平互斥；`SearchField` 吸收剩餘寬 |
| 最小間距 | `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 5；`SearchField` 最小寬 + Σ `FilterDropdown` 固有寬（以最長選項文案計）+ `IssueMarker` 寬 + 4 × `Space.sm` ≤ 可用寬（= `Panel` 內寬）；測試以 `TestCopy` 最長值與 `kMinWindowSize` 代入斷言 |

### 5.7 BadgeRow

**對應第 4 章條目**：4.33

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `Badge`（全變體） |
| 子件數量上限 | 無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 同列子件水平互斥、列間垂直互斥；單一徽章寬超過可用寬時自身截斷（4.5） |
| 最小間距 | `Space.xs`（水平與列間）；呼叫端不得覆寫 |
| 空間不足策略 | 換行（wrap）；觸發條件：目前列累計寬 + `Space.xs` + 下一徽章寬 > 可用寬 |

### 5.8 ButtonRow

**對應第 4 章條目**：4.34

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `AppButton`（全變體；`primary` 至多 1） |
| 子件數量上限 | 3 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 同列水平互斥、列間垂直互斥；單一按鈕寬超過可用寬時自身截斷 label（4.4） |
| 最小間距 | `Space.sm`（水平與列間）；呼叫端不得覆寫 |
| 空間不足策略 | 換行（wrap）；觸發條件：Σ 按鈕固有寬 + (n − 1) × `Space.sm` > 可用寬（右欄 `LayoutSize.detailPaneWidth` − 2 × `Space.md` 為最窄宿主，最長文案下兩顆可能觸發，故不採「不觸發」） |

### 5.9 TableRow

**對應第 4 章條目**：4.35

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `header`：`TableColumnHeader`；`ticket`：`AppText.mono`、`AppText.body`、`Badge.status`、`AppText.caption`、`IssueMarker.damagedDetail`；`step`：`StepNumber`、`AppText.body`、`RelationItem`、`BadgeRow` |
| 子件數量上限 | = 欄數：`header` 5、`ticket` 5、`step` 4 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 格依欄規格水平互斥；填滿欄子件截斷（`AppText`）或換行（`BadgeRow`，列高固定時改為單列截斷，提案：`step` 事件欄 `BadgeRow` 限一列） |
| 最小間距 | `Space.md`（欄間）；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 5；Σ 固定寬欄（`ticketIdColumnWidth` + `ticketStatusColumnWidth` + `ticketPriorityColumnWidth` + `ticketMarkerColumnWidth`；`stepNumberColumnWidth` + `stepDomainColumnWidth`）+ 填滿欄最小寬 × 填滿欄數 + (欄數 − 1) × `Space.md` + 2 × `Space.sm` ≤ 列寬（= `Panel` 內寬） |

### 5.10 DataTable

**對應第 4 章條目**：4.36

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `TableRow.header`（1）、`TableRow.ticket` 或 `TableRow.step`（單一變體） |
| 子件數量上限 | 表頭 1；資料列無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 列垂直互斥、高固定 `LayoutSize.rowHeightRelaxed`（`virtual` 以 `itemExtent` 保證）；表頭釘選於頂且不與首列相交；水平方向承 5.9 |
| 最小間距 | 列間以 `TableRow` 底邊框線寬分隔（§4.0.3）；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，`scroll-tickets-list` / `scroll-ucFlow-steps`）；觸發條件：列數 × `LayoutSize.rowHeightRelaxed` > 可用高 − 表頭高。水平方向不觸發（承 5.9 公式） |

### 5.11 MatrixGrid

**對應第 4 章條目**：4.37

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 欄首：`TableColumnHeader.twoLine`；列首：`AppText.body`（容器包成可點）；格：`MatrixCell`；小計：`AppText.caption` |
| 子件數量上限 | 欄無上限、列無上限（格數 = 列 × 欄） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 二維格線：每格寬 = 欄寬、高 = `LayoutSize.rowHeightRelaxed`，行列皆互斥；釘選的欄首列與列首欄與捲動內容以不透明底分層，不相交於可見區 |
| 最小間距 | 列間 `Space.xxs`；欄間 0（格內距 `Space.xs` 承載留白）；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（二維，`scroll-domain-matrix`）；觸發條件：`LayoutSize.matrixLeadColumnWidth` + N × `matrixColumnWidth`（122，已核定） + `LayoutSize.matrixSubtotalWidth` > 可用寬，或欄首高 + M × (`LayoutSize.rowHeightRelaxed` + `Space.xxs`) > 可用高 |

### 5.12 SwimlaneGrid

**對應第 4 章條目**：4.38

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 泳道名：`AppText.body`；節點：`SwimlaneNode` |
| 子件數量上限 | 泳道無上限；每泳道節點無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 泳道列垂直互斥（高 `LayoutSize.laneRowHeight`）；同列節點依假資料座標置於步驟欄，兩兩不相交（假資料須保證每欄至多一節點，測試斷言）；泳道名欄 `LayoutSize.laneLabelWidth` 釘選 |
| 最小間距 | 節點與欄邊 `Space.xs`；列間以虛線相接；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（二維，`scroll-domain-swimlane`；與 `drag-domain-swimlane` 共用 offset）；觸發條件：`LayoutSize.laneLabelWidth` + Σ 步驟欄寬 > 可用寬，或泳道數 × `LayoutSize.laneRowHeight` + 箭頭列高 > 可用高 |

### 5.13 Tree

**對應第 4 章條目**：4.39

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `ListRow.tree` |
| 子件數量上限 | 無上限（深度上限 4） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 列垂直互斥、高固定 `LayoutSize.rowHeightDense`；列內縮排 = 深度 × `LayoutSize.treeIndent`（24），列主文字截斷 |
| 最小間距 | 列間 0（留白由列高承載）；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，由所在 `Panel.scrollable` 的 `scroll-traceability-tree` 承載，本容器不自設捲動區）；觸發條件：可見列數 × `LayoutSize.rowHeightDense` > 面板可用高。水平：不觸發：3 × `treeIndent` + `ListRow.tree` 最小寬 ≤ 可用寬 |

### 5.14 ListRow

**對應第 4 章條目**：4.40

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | leading：`ExpanderIcon` \| `AppIcon` \| `Badge` \| `StepNumber`；primary：`AppText`；secondary：`AppText.caption`；trailing：`Badge` \| `AppIcon` \| `AppText.caption` \| `IssueMarker` |
| 子件數量上限 | 4（leading 0..1 + primary 1 + secondary 0..1 + trailing 0..1） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | leading / 文字塊 / trailing 水平互斥，兩端固有寬、文字塊填滿並截斷；secondary 堆疊於 primary 下 |
| 最小間距 | `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 4；leading 固有寬 + trailing 固有寬 + 2 × `Space.sm` + primary 最小寬（一字元 + 省略號）≤ 列寬；最窄宿主為 `Tree` 第四層（承 5.13 水平公式） |

### 5.15 Section

**對應第 4 章條目**：4.41

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | header：`ListRow.sectionHeader` \| `AppText.caption`；items：`TableRow.ticket` \| `ListRow.item` \| `RelationItem` \| `AppText.mono`（單一型別） |
| 子件數量上限 | header 1；items 無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | header 與 items 垂直互斥、依序堆疊、填滿寬 |
| 最小間距 | `Space.xxs`；`dashedTop` 上方 `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，由所在 `Panel.scrollable` 承載：`scroll-tickets-topics` / `scroll-gaps-sections` / `scroll-nodeDetail-relations`；本容器不自設捲動區）；觸發條件：Σ 節高 + 節間 `Space.sm` > 面板可用高 |

### 5.16 SwitcherOverlay

**對應第 4 章條目**：4.42

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `AppText.caption`（標題）、`RecentProjectItem`、`Divider`、`AppButton.text` |
| 子件數量上限 | 標題 1、`Divider` 1、`AppButton.text` 1；`RecentProjectItem` 無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 標題 / 清單區 / 分隔線 / 按鈕垂直互斥；清單區高 = 浮層高 − 其餘三者高 − 間距 |
| 最小間距 | `Space.xxs`；內距 `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，僅清單區，`scroll-switcher-recent`；標題、分隔線、按鈕不捲離）；觸發條件：標題高 + N × `RecentProjectItem` 高 + (N − 1) × `Space.xxs` + `Divider` 高 + `LayoutSize.hitTargetMin` + 2 × `Space.sm` > 最大高（入口下緣至視窗下緣 − `Space.xl`） |

---

## 6. 原生元件禁用對照表

> 禁止直接使用的原生元件，及應改用的封裝元件。適用範圍：元件庫統一匯出入口（`lib/components/`，W1-005 建立）之外的所有頁面層程式碼；元件庫內部實作原生 widget 屬正常。（`0.1.0-W1-044.2` 填，提案；執法 pattern 由 `dart-style-guardian` 承接，見 `0.1.0-W1-046`）

| 禁止直接使用 | 改用 | 理由 |
|-------------|------|------|
| `Text` / `RichText` / `SelectableText` | `AppText` | 字級與顏色只經 token 變體；內容政策由元件承載 |
| `Icon` | `AppIcon` | 尺寸只取具名階；語意標籤規則統一 |
| `Divider` / `VerticalDivider` | `Divider`（本檔 4.3）；側欄與主區分隔為 `AppShell` 內部 | 顏色與線寬統一 |
| `ElevatedButton` / `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton` | `AppButton` | 三變體與 disabled 常駐說明契約；禁 icon-only |
| `Chip` / `ActionChip` / `FilterChip` | `Badge`（非互動）/ `FilterDropdown`（篩選） | 徽章明訂非互動；篩選有自己的狀態集 |
| `TextField` / `TextFormField` | `SearchField` | 防抖動與清除契約 |
| `DropdownButton` / `DropdownMenu` / `PopupMenuButton` | `FilterDropdown` | 篩選狀態集與播報（待 W1-057） |
| `DataTable`（Material）/ `Table` | `DataTable`（本檔 4.36）+ `TableRow` | 虛擬捲動與欄規格 |
| `ListTile` | `ListRow` | 五變體與兩端固定策略 |
| `ExpansionTile` / `ExpansionPanel` | `Section.collapsible` + `ExpanderIcon` | 展開狀態存於 provider、offset 不歸零 |
| `ScaffoldMessenger.showSnackBar(SnackBar(...))` 直呼 | `AppSnackBar` | 停留時間引用 `Motion` token |
| `showDialog` / `AlertDialog` / `showModalBottomSheet` / `Drawer` | `SwitcherOverlay`（0.1 唯一覆蓋層） | §1 覆蓋表面對映無 dialog / sheet / drawer |
| `CircularProgressIndicator` / `LinearProgressIndicator` / `RefreshIndicator` 直用 | `LoadingState` | 取消契約與誠實性硬規則 |
| `Card` | `Panel` | 表面樣式統一 |
| `Scaffold` / `AppBar` / `NavigationRail` 於頁面層 | `AppShell` | 單一殼層 |
| `Row` / `Column` / `Wrap` / `Flex` / `Stack` / `GridView` / `ListView` 於頁面層直接包兩個以上元件庫元件 | 第 5 章對應容器 | 排列關係須有容器契約（方法論〈容器亦為元件〉） |
| `Duration(milliseconds: <字面>)` / `Duration(seconds: <字面>)` | `Motion.*` | SPEC-003 §2.1 硬規則 |

---

## 7. 豁免清單（三條件 AND，全滿足才可豁免直用）

> 條件 1 結構性無法收斂、條件 2 記錄理由、條件 3 列入工具白名單。
> 豁免由 PM 於票驗收時核可，本清單為單一權威來源。（`0.1.0-W1-044.2` 填，提案）

| 路徑 | 具體理由 | 白名單登記 |
|------|---------|-----------|
| `lib/components/document_body.dart`（`DocumentBody` 內 `flutter_markdown_plus` 渲染器輸出的原生 `Text` / `RichText` / `Table` 等） | 條件 1：第三方渲染器的輸出樹結構性無法改為元件庫元件；條件 2：理由記於 §3.7 第 7 項與本列；樣式全部經 `MarkdownStyleSheet` 映射 token（4.20） | 否（W1-005 於 `dart-style-guardian` 設定登記後改「是」） |

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
| 1.9 | 2026-09-02 | 對比核定回填（`0.1.0-W1-060`，依 `0.1.0-W1-058` 方案 C 與 `0.1.0-W1-059` 落地值）：§3.7 新增第 25 項；§4.0.1 disabled 列改 `textDisabled`；§4.0.2 重寫為表 1（文字對比，精確值）+ 表 2（`textDisabled` 停用態與純裝飾）+ 帶色表面規則 + `textDisabled` 對應清單；15 條目無障礙子節對比列填實際值去「待 W1-058」（4.1 / 4.4 / 4.5 / 4.6 / 4.9 / 4.11 / 4.12 / 4.13 / 4.14 / 4.15 / 4.18 / 4.21 / 4.22 / 4.23 / 4.24）；4.5 `Badge` 刪 `secondary` tone，`rejected` / `superseded` / `revised` 改對映 `neutral`；4.6 `damagedEdge` child 文字與 4.19 `RelationItem.damaged` 改維持 `textPrimary`；4.9 selected 摘要改 `textPrimary`；4.10 軌道底對比改 4.56:1；停用態與純裝飾箭頭圖示改引用 `textDisabled`（4.2 色彩列補 token、4.4 disabled、4.8 展開箭頭、4.9 disabled、4.12 搜尋圖示、4.13 箭頭、4.18 箭頭、4.38 底部箭頭列）；標頭版本欄自 1.5 補正（1.6–1.8 未同步更新） |
| 1.8 | 2026-09-02 | PM 核定 `matrixColumnWidth` = 122（§3.7 第 24 項），4.15 / 4.37 與 §4.0.9 去「待核定」標；§3.7 第 23 項更新為 W1-038 已加入依賴 |
| 1.7 | 2026-09-02 | 補齊第 4 章缺漏佈局尺寸 token（`0.1.0-W1-055`）：`lib/tokens/layout.dart` 新增 `titleBarHeight` / `ticketIdColumnWidth` / `ticketStatusColumnWidth` / `ticketPriorityColumnWidth` / `ticketMarkerColumnWidth` / `stepNumberColumnWidth` / `stepDomainColumnWidth` / `treeIndent` / `stepNumberSize` / `matrixColumnWidth` 十項；`stepNumberSize` 收斂採 UCFlowB 圓形值 24（依 §3.7 第 11 項）；`matrixColumnWidth` 為本票依 `Main` 版面尺寸鏈反推的提案值 122，dartdoc 與本檔皆標「待 PM 核定」。§4.0.9 待決清單去標原 6 條目（4.17 / 4.27 / 4.35 / 4.36 / 4.37 / 4.39）；4.17 / 4.27 / 4.35 尺寸契約與組合規則、4.36 / 4.37 / 4.39 的 5.10 / 5.11 / 5.13 不重疊公式改引用具名 token；§3.4 / §3.5 對應列同步 |
| 1.6 | 2026-09-02 | i18n 新 key 補齊（`0.1.0-W1-056`）：§4.0.6 新 key 總表 53 個 key 已建於 `lib/l10n/app_zh.arb`、`app_en.arb`，`app_localizations*.dart` 重新產生；§4 逐條目 i18n 表移除「新 key」標記；§4.0.6 引言與 §4.0.9 待決清單結語同步更新為已建狀態 |
| 1.5 | 2026-09-02 | 逐元件契約與容器不變式（`0.1.0-W1-044.2`）：第 4 章新增 §4.0 通用約定（互動瞬態視覺、對比表、尺寸推算、`TestCopy` 測試文案常數、測試形態 L2 條文、新 key 總表、操作機制通用列、組合規則通用值、待決清單）與 42 條目（元件 4.1–4.26、容器 4.27–4.42，每條十三子節）；第 5 章 16 條容器子件契約與排列不變式，§3.4 排列關係 25 列逐列對應；第 6 章原生禁用對照表、第 7 章豁免清單填最小集（提案）。§3 依 §3.7 核定回填：`MissingSourceState` 獨立列、`EmptyState` 變體收為 `page` / `section`、`TableRow.ticketNested` 刪除、`AppButton` 三變體與 `Badge` tone 參數、`StepNumber` 圓形、定案數元件 26 / 容器 16（原「17」為計數誤差）；§3.4 token 缺料列改引用 W1-047 已建 token；§3.5 補四則漂移（副標文案、hover 樣式、缺 token 尺寸）；§3.6 標題 30 → 31 並補「已選格」列、§6 / §7 位置依 §3.7 第 14、17、18 項。待決：`FilterDropdown` 與 `TableColumnHeader.sortable` 互動反應（`0.1.0-W1-057`）、`StepNumber` / `AppShell` / `TableRow` / `DataTable` / `MatrixGrid` / `Tree` 尺寸 token（`0.1.0-W1-055`）；新 key 由 `0.1.0-W1-056` 建立；`textSecondary` 對比未達 AA 待 `0.1.0-W1-058`。`RelationItem` 擴為節點參照 chip（含步驟表 domain 欄），`Badge` 增 tone 參數 |
| 1.4 | 2026-09-02 | 用戶補充回饋通道、最小命中區、禁放區與安全區三維度；§1 填桌機值（視覺回饋、`hitTargetMin` 提案待 W1-047、無禁放區與 SafeArea） |
| 1.3 | 2026-09-02 | 用戶補充操作機制與無障礙為必填欄，契約欄位九改十一；§3.7 引言補說明 |
| 1.2 | 2026-09-02 | 用戶裁示形態依操作方式界定：§1「斷點策略／版型策略」兩列改為「同形態內的尺寸適應策略／支援的形態（單一形態：桌機）」，去「響應式」措辭；§3.7 第 1 項同步 |
| 1.1 | 2026-09-02 | PM 驗收 044.1：新增 §3.7 核定記錄二十三項（版型策略、文字縮放為用戶簽核；`missing` 改獨立元件 `MissingSourceState`、`compact` 刪除、`ticketNested` 刪除、格詳情卡納入 0.1）；§1 三格去待核定標；佈局 token 前置票、格詳情卡規格補件票、動態字級重評票各建一張 |
| 0.1 | 2026-09-02 | 初版骨架（0.1.0-W1-044.1）：依 component-contract-design skill 模式 B → A 推導，填第 1 章形態因素矩陣（提案，待核定）、第 2 章狀態綁定模式（Riverpod，傳值 + callback 為提案）、第 3 章元件清單總表（元件 25、容器 17）含推導記錄（3.2–3.6）；第 4–9 章保留範本骨架。SPEC-002〈元件庫的範圍〉改為指向本檔 |
