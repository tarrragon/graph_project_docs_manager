---
id: SPEC-004
title: "元件庫規格：元件目錄、逐元件契約與容器排列不變式"
status: draft
source_proposal: PROP-004
created: "2026-09-02"
updated: "2026-11-13"
version: "1.151"
owner: lavender-interface-designer

domain: "ui"
subdomain: component-library

related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07]
related_specs: [SPEC-001, SPEC-002, SPEC-003, SPEC-008]
implements_requirements: []
has_functional_requirements: false   # 元件庫規格以逐元件契約表達，不含 FR 為設計（0.5.0-W1-159 判定）
depends_on_domains: [layout]
---

# 元件庫規格（L3 元件庫章節）

**版本**: 1.151（1.151 依 `1.0.0-W3-698`：§4.0.6 新增 `validationUnavailableBaselineNotReady`，4.48、4.51 的驗證不可用原因由四種改為五種；1.150 依 `1.1.0-W1-111`：破洞報告的編輯入口，4.40 `item` trailing 接受 `ButtonRow`、4.34 新增 `wrap` 參數、5.14 新增〈可修正破洞項的寬度核對〉、§4.0.9 寫回 4.40 與 4.34 重驗，4.52 使用處補 UC、EVT `source_proposal`；1.149 依 `1.1.0-W1-111`：4.48 新增「部分寫入」狀態，4.51 新增〈同批檔案〉與部分寫入的呈現，4.52 待決解除，§4.0.6 六個 key，§4.0.9 寫回；1.148 依 `1.1.0-W1-111`：新增 4.52 `ReferenceChips`（5.20）、4.53 `AppCheckboxGroup`（5.21），4.43 `AppCheckbox` 增 `locked`／`enabled`，4.48 值格清單與提示優先序、§6 兩列、§4.0.6 五個 key、§4.0.9 寫回；1.147 依 `1.1.0-W1-108`：§4.0.6 新增〈規格先行標記〉；1.146 依 `1.0.0-W3-553.6`：4.46 重驗通過，§4.0.9 寫回，4.48 補「必填空白」的測試點與狀態邊；1.145 依 `1.0.0-W3-686`：4.46 `allowEmpty` 定案、4.44 空白送出、4.48 新增「必填空白」狀態，見變更歷史；1.144 依 `1.0.0-W3-553.6`：編輯相關條目重驗〈契約齊全的定義〉，§4.0.9 寫回結果，4.48–4.51 補齊重驗缺口，見變更歷史；1.143 依 `1.0.0-W3-553.3.1`：新增 4.49 `NoticeBanner`、4.50 `FieldList`、4.51 `WriteLogRow`，4.44–4.48 回填編輯狀態，側欄底部改為三項，見變更歷史；1.142 依 `1.0.0-W3-676`：4.48 `FieldBlock` 回饋契約〈等待與結果〉的逾時段與時間門檻回填（SPEC-009 v1.2），§4.0.9 封鎖項移除逾時段；1.141 依 `1.0.0-W3-673.1`：4.20 `DocumentBody` 的 `markdown` 來源改為 frontmatter 之後的本文並補〈本文來源的界線〉，§3.6 §6 正常列同步，§4.0.6 登記 `nodeDetailBodyUnavailableMessage`；1.140 依 `1.0.0-W3-553.6`：新增編輯用表單元件 4.44 `AppTextInput`、4.45 `AppDropdown`、4.46 `ReferencePicker`、4.47 `AppRadioGroup` 與容器 4.48／5.17 `FieldBlock`（提案，依賴編輯狀態者待決 1.0.0-W3-553.3）；1.139 依 `1.0.0-W3-553.1`：§2 樂觀更新政策列改為指名 SPEC-009 FR-05；1.138 依 `1.0.0-W1-110`：4.6 `IssueMarker` default 列的恢復條件票 ID 改為遷移後的 `1.1.0-W3-656`；1.137 依 `1.0.0-W3-553`：§2 樂觀更新政策列改為 0.x 與 1.0 皆不允許，1.0 寫入等落檔才顯示、CLI 驗證另以狀態呈現且失敗不自動回滾，刪除原重評條件；1.136 依 `0.7.0-W1-007.6`：4.30 `Panel.scrollable` 新增 optional `footer`〈固定底部 slot〉，偏好設定與鍵盤快捷鍵面板的關閉鈕移入；4.4 `AppButton` 新增 `autofocus`；4.7 `NavItem` 新增 `focusNode`；1.135 依 `0.7.0-W1-012.18`：4.10 尺寸契約分清段高與元件固有高，4.32 `history` 子件列高與框體高、5.6 `history` 空間不足策略改為期間選擇有界寬與段 label 截斷；1.134：4.39 `Tree` 新增 `sourceChain` 變體；1.133 依 `0.7.0-W1-007.1`：4.27 `AppShell` 新增〈側欄底部 slot〉（設定、鍵盤快捷鍵兩項），4.7 `NavItem` 增 `action` 變體，4.40 `ListRow` 增 `shortcut` 變體，§3.6 補 SPEC-001 §11 一列，§4.0.6 登記鍵盤快捷鍵面板與側欄底部項的 key；1.132 依 `0.7.0-W1-009.1`：§4.0.6 登記 `preferencesEditorAppliedMessage`、`preferencesEditorSaveFailedMessage`，4.26 `message` 呼叫端清單補兩 key；1.131 依 `0.7.0-W1-012.2`：補齊第七畫面變更記錄（SPEC-001 §10）的元件——新增 4.43 `AppCheckbox`，`SegmentedControl` 段數放寬為 2–3，`TableRow` 增 `historyEvent`、`Toolbar` 增 `history` 變體，§3.6 補八列，§4.0.6 登記新 key，側欄與 `AppShell` 改為七項；1.130 依 `0.7.0-W1-012.1`：4.27 state-change 列對 SPEC-003 §2.8 建構時機錨點的逐字引用改為「七頁建構時機」；1.129 依 `0.7.0-W1-008.1`：4.10、4.13、4.14、4.15、4.40 新增〈套用時點〉子節；1.128 依 `0.6.0-W1-202`：4.15、4.27、4.42 與 §2 改為元件傳值、訂閱在上層；1.127 依 `0.6.0-W1-193.1`：§2 刪除容器例外，4.36–4.39 改為傳值；1.126 依 `0.6.0-W1-191.2`：19 處「provider 尚未建立」補為實際 provider、§6 執法現況；1.125 依 `0.6.0-W1-191.1`：§4.0.6 等處時效型進度註記改為現況；1.124 依 `0.6.0-W1-086.1`：三處依賴型票號引用改寫為定案內容；1.123 依 `0.6.0-W1-075.2`：§4.0.6 登記 `pathDeclarationBundlesMalformed`；1.122 依 `0.6.0-W1-070.2`：§3.6 補 SPEC-001 §9 兩列、§4.0.6 登記偏好設定面板與 `openedWithoutEditor` 的四個 key；1.121 依 `0.6.0-W1-152.1`：§4.0.6 與 ARB 四個 key 文案同步並補登三個 key；1.120 依 `0.6.0-W1-019.1`：4.9 disabled 列拆分探測逾時與非逾時失敗的原因來源，逾時值引 SPEC-005 §2.5；歷次見〈變更歷史〉）
**來源**: PROP-004
**依賴**: SPEC-002（token 來源，`lib/tokens/`）、SPEC-003（互動反應來源）、SPEC-001（狀態表，元件候選的書面來源）

> **層級定位**（component-library 方法論）：L1 通用原則（方法論）、L2 框架實作規範、
> L3 專案元件庫章節（本檔）。本檔為 L3，承載元件清單、逐元件契約（欄位依方法論〈元件契約欄位表〉，含回饋契約；
> 本檔不以數字描述欄位表大小，DOC-GPD-003）、容器元件與排列不變式、原生禁用對照、豁免清單、形態因素矩陣、狀態綁定決策。
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
| 回饋通道 | 見下方〈回饋通道子表〉（提案，1.17 展開為事件 × 形態）；無觸覺、無聲音 | 桌機指標不遮住元件，視覺回饋可見；方法論〈形態因素先決〉回饋通道列（1.14.0 起展開為子表） |
| 最小命中區 | `LayoutSize.hitTargetMin`（28px，`lib/tokens/layout.dart`），可點元件的最小尺寸不得小於之 | 桌機命中區可小於手機下限，但仍需具名以供尺寸契約引用 |
| 禁放區與安全區 | 無禁放區（視窗四角無觸控不靈敏問題）；無 SafeArea 需求（macOS 視窗無瀏海與手勢區），框架容器 `AppShell` 以視窗邊緣內距 token 承載留白 | 桌機視窗；`AppShell` 為根框架容器 |
| 支援的形態 | **單一形態：桌機（指標 + 鍵盤、多視窗、長時工作）**（用戶簽核 2026-09-02）；不支援平板與手機形態 | 形態依操作方式界定（方法論〈形態因素先決〉）；本專案目標平台僅 macOS，唯一操作方式是指標加鍵盤，無第二形態 |

### 回饋通道子表（提案）

> 形態因素矩陣「回饋通道」列的展開：列＝方法論〈回饋契約〉節回饋事件表六類事件，欄＝形態，格＝可用通道集合或「不可用 + 替代」。
> 本專案為單一形態（桌機），子表僅一欄；第 4 章各元件的「回饋契約」子節之「回饋通道（桌機）」欄引用本表對應列，不各自重述通道。
> 無障礙播報（`Semantics` 標籤與狀態變化播報）是視覺障礙使用者對視覺回饋的替代通道，桌機同樣須提供（方法論〈形態因素先決〉）；
> 本專案無觸覺、無聲音通道（桌機指標不遮住元件，無需觸覺確認；聲音無專案決策來源，不自行引入）。
> **本表狀態**：提案，待 PM 於本規格票驗收核定；「狀態變更提示」列的系統通知升級已由用戶簽核（2026-09-08），規格在 SPEC-003 §2.2「系統層通知」。

| 事件 | 桌機（指標 + 鍵盤） |
|------|--------------------|
| 可互動提示 affordance | hover（§4.0.1 hover 態：Material `InkWell` 內建 hover overlay，不自繪）；指標形狀依 Flutter 預設（可點元素 `SystemMouseCursors.click`） |
| 焦點 focus | 焦點環（§4.0.1 focused 態：`AppColors.accent` 外框，兩態對照斷言依 SPEC-003 §2.10 焦點裝飾）+ 鍵盤導覽（Tab 三區段順序、Esc 收合，SPEC-003 §2.10） |
| 按下確認 press-ack | pressed（§4.0.1：Material `InkWell` / `ButtonStyleButton` 內建 pressed 態）+ Material ripple；時限 `Motion.feedback` 內（`lib/tokens/motion.dart`） |
| 定位提示 locate | 容器 scroll-into-view + 短暫高亮（適用場景：搜尋命中列、樹節點展開後的子項、跨畫面跳轉到節點——追溯視圖至節點詳情、破洞項至來源）；輔助技術：焦點移入被定位項，由第 4 章對應容器條目定義高亮 token 與時長 |
| 狀態變更提示 state-change | `Motion.*` 過渡（依 §4 各元件 token 子節）+ 無障礙狀態變化播報（第 4 章各條目無障礙子節）；升級：掃描完成 AND（視窗非前景 OR 已離開觸發頁）→ macOS 系統通知，規格見 SPEC-003 §2.2「系統層通知」（觸發條件、文案 key、點擊導向引用本表 locate 列、權限 gate 三路徑與 `denied` 時的 `AppSnackBar.withAction` fallback、不重複發送）；用戶簽核 2026-09-08。0.1 僅此一處升級，Domain 與 Ticket 載入的完成仍由畫面級狀態轉換承載 |
| 等待與結果 | SPEC-003 §2.2 三層（點擊確認＝Material pressed 態、等待指示＝畫面級載入態 §2.6、結果通知＝狀態轉換本身或 SnackBar）；不新增本檔專屬通道 |

**與第 4 章的分工**：本表定「桌機有哪些通道可用」；每個元件在六類事件上實際走哪個通道、時間門檻、動畫 token、對應狀態邊，由第 4 章逐元件「回饋契約」子節填寫（`0.1.0-W3-060.2`–`060.5`），不適用者填「不可用 + 替代」或「不適用 + 理由」，不留空。

---

## 2. 狀態綁定模式（L2 決策）

> 狀態管理方案在元件庫設計時決定，不留給實作各自選擇。
> 本節依 `docs/tech-decisions.md` 補記「2026-08-26：Stage 4 技術維度定案」（狀態管理定為 Riverpod）
> 與 `.claude/skills/dart-provider-architecture/SKILL.md` 填寫；標「提案」者為本檔新增的 L2 條文，待 PM 核定。

| 項目 | 決定 |
|------|------|
| 狀態管理方案 | Riverpod（`flutter_riverpod`；理由為生態一致性：`dart-provider-architecture` skill、`parsley-flutter-developer` 代理人、flutter_balance 皆採 Riverpod） |
| 元件接收狀態形式 | **傳值 + callback**（提案）。元件庫元件（第 3 章「元件」種類）為純 widget：建構子接收值型參數與 `VoidCallback` / `ValueChanged`，**不**在元件內 `ref.watch`；provider 的 watch 落在頁面層。資料視圖容器（第 3 章標「資料視圖」的容器：矩陣、泳道、表格、樹）同樣適用，不設例外（`0.6.0-W1-193` 裁決 D 案）。理由：元件的測試契約要求一支 widget test 逐一渲染全部變體與狀態，純 widget 不需 `ProviderScope.overrides` 即可渲染；同一元件被多個 provider 驅動（如載入態被三個畫面的三個 provider 驅動）時，元件不綁定任一 provider 型別 |
| 最小重繪邊界 | 畫面層 watch 時一律 `ref.watch(provider.select((s) => s.field))`，只訂閱傳入元件或容器所需的欄位，不 watch 整個 provider；元件與容器不 watch；`ref.read` 只在事件回呼內使用（沿用 dart-provider-architecture skill 的 `ref.read` / `ref.watch` 規則；`0.6.0-W1-193` 裁決 D 案：原「容器元件的例外」列已刪除，其前提「逐列傳值會使頁面層持有整份清單並重建整棵子樹」未經量測，三個資料視圖容器皆為虛擬捲動，重建只建可見列；真實規模下的成本由「高頻場景效能檢核」列量測） |
| 導覽狀態 | 既有 `selectedDestinationProvider`（`StateProvider<AppDestination>`，`lib/app/router.dart`）；元件庫的 `AppShell`（`lib/components/app_shell.dart`）與導覽項元件皆傳值，不 watch；訂閱由組裝層 `lib/assembly/shell.dart` 的 `AppShell` 承擔（`ref.watch` 後傳值，`NavItem` 傳 `isSelected` + `onTap`） |
| 頁面狀態保留 | 全部導覽頁由 `IndexedStack` 一次建構，切換導覽項不 dispose（SPEC-003 §2.8）；因此畫面級狀態（捲動 offset、雙模式選擇、搜尋詞、樹展開集合）須存於 provider 或頁面的 `State`，**不得**存於元件庫元件內部（元件庫元件為無狀態或僅持有互動瞬態如 hover） |
| 高頻場景效能檢核 | 虛擬捲動表格（Ticket 清單，`scroll-tickets-list`）與二維捲動矩陣（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`）於元件票驗收時以真實規模假資料做 Profiler 抽查（提案；量化上限不設，依方法論 L2 判準「量化上限為選配」） |
| 過渡提示觸發點 | **由呼叫端顯式觸發**（提案）。元件庫元件為傳值純 widget（本表「元件接收狀態形式」），不持有上一值，故「狀態變更提示」（§1 回饋通道子表 state-change 列）的過渡由持有新舊值的一方觸發：頁面層於 `ref.listen(provider.select(...), (previous, next) { ... })` 內比對新舊值後，透過元件的觸發參數或 controller 播放過渡；元件本身不比對、不自播。資料視圖容器內部子項的過渡同樣由頁面層觸發，容器只依傳入值重建（`0.6.0-W1-193` 裁決 D 案）。理由：(1) 元件 API 若須保留上一值以自播，等於元件內持有跨 build 的資料態，違反「頁面狀態保留」列「畫面級狀態不得存於元件庫元件內部」；(2) widget test 逐一渲染全部變體與狀態時，純 widget 不需先渲染舊值再切換才能驗證過渡是否播放；(3) 方法論〈L2 狀態綁定判準〉要求二擇一且同一狀態管理方案下不得混用，Riverpod 的 `ref.listen` 天然提供 `(previous, next)` 對，呼叫端觸發無額外成本。第 4 章各元件回饋契約 state-change 列的「觸發者」欄一律填「呼叫端」 |
| 樂觀更新政策 | **0.x 與 1.0 皆不允許樂觀更新**（1.0 部分依 `docs/tech-decisions.md`〈補記：2026-11-10 — 1.0 編輯能力四項架構決策定案〉，出處 `1.0.0-W3-553`）：允許清單為空；狀態矩陣「同步策略」欄只得填「本地即時」或「等確認才顯示」，不得填「樂觀更新後確認」。0.x 在實作層為唯讀：SPEC-001〈狀態總數〉所列全部狀態皆無寫回動作，狀態變更皆為本地即時（互動瞬態）或等資料層確認才顯示（資料態：載入、掃描、解析完成）。1.0 起可寫（`docs/proposals/PROP-005`〈1.0 — 編輯〉），寫入一律等確認才顯示：位元組已落檔才顯示新值；CLI 驗證的結果以獨立的驗證狀態呈現（進行中，然後通過或失敗），驗證失敗不自動回滾檔案。寫入的三個可觀測時刻、寫入結果型別與驗證狀態由 SPEC-009 FR-05 定義。回滾提示形式：不適用（無樂觀操作即無回滾） |

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
> **出現畫面欄**以 SPEC-001 章節號表示（§1 Domain 視圖、§2 UC Flow、§3 追溯、§4 Ticket 清單、§5 破洞報告、§6 節點詳情、§7 專案切換浮層、§9 偏好設定面板、§10 變更記錄、§11 鍵盤快捷鍵面板、殼 = 全部導覽頁共用的框架層）。
> **變體欄**為語意名，變體數量與最終命名定於第 4 章（L2 決策）；本表為候選。

### 3.1 總表

#### 元件（非容器）

| 元件 | 種類 | 層級 | 用途 | 出現畫面 | 變體（variant） |
|------|------|------|------|---------|----------------|
| `AppText`（文字） | 元件 | L2 | 所有可見文字的唯一載體，依字級 token 與語意角色渲染；容器的子件清單以此具名 | 全部 | `title` / `subtitle` / `body` / `caption` / `mono`（等寬：ID、路徑）/ `code`（等寬、換行、可選取：供複製執行的指令，1.143）；強調（`emphasis`）與弱化（`secondary`，`AppColors.textSecondary`）為修飾參數 |
| `AppIcon`（圖示） | 元件 | L2 | 語意圖示（資料夾、全部導覽圖示、展開箭頭、外開箭頭、損壞）；尺寸只取具名階 | 殼、§3、§4、§5、§7 | 不適用（尺寸階與顏色為參數；圖示尺寸階 token 待第 4 章向 `lib/tokens/` 補） |
| `Divider`（分隔線） | 元件 | L2 | 區隔堆疊中的群組 | §6、§7 | 不適用（原子元件） |
| `AppButton`（按鈕） | 元件 | L2 | SPEC-001「可用操作」欄所有有視覺承載的動作：開始載入、取消、重新掃描、重新整理、返回、開啟原始檔、檢視關聯、前往破洞報告、開啟 docs 目錄、檢視詳情、選擇資料夾、選擇其他、在泳道中檢視、關閉詳情卡、前往 Domain 視圖、以 App 內建型別表檢視、前往追溯視圖、前往 Ticket 清單、切換專案（阻擋狀態本體）、顯示全部歷史、重新檢查、重試、重新讀取（§10） | §1–§7、§10 | `primary`（前進／主要動作）/ `secondary`（取消、返回、重新整理）/ `text`（低強調、可帶 leading icon，如浮層底部「選擇其他資料夾…」）；三變體已核定（§3.7 第 9 項） |
| `Badge`（徽章） | 元件 | L2 | 非互動的標籤／數值標記（§10：事件列的新增／移除、淺層 clone 標示） | §1–§7、§10 | `count`（計數）/ `status`（draft／pending／completed／confirmed／approved 等）/ `type`（PROP／SPEC／UC／Ticket）/ `category`（破洞類別）/ `event`（emits X／consumes X）/ `tag`（domain: schema、N 個 FR）/ `legend`（圖例：符號 + 說明）/ `health`（專案健康計數）；顏色以語意 `tone` 參數取 token（§4.5）；chip 底／純文字不設第二變體軸，由所在容器格位決定（§3.7 第 5 項） |
| `IssueMarker`（問題標記） | 元件 | L3 | 修飾既有節點或欄位的問題標記，可點擊跳轉破洞報告 | §3、§4、§6 | `damagedEdge`（邊損壞：虛線框／降低不透明度，FR-05）/ `damagedDetail`（詳情損壞：圖示 + 計數徽章，`badge-tickets-corrupted`；欄位級附說明文字 slot）/ `gap`（追溯缺口：虛線框 + 「缺口」標籤，`badge-traceability-broken-<nodeId>`，`<nodeId>` 為缺下游的父節點，每個此類父節點一個；SPEC-001 §3、SPEC-003 §3.3，用戶簽核 2026-09-14） |
| `NavItem`（導覽項） | 元件 | L3 | 側欄全部導覽項，`nav-item-<destination>`；`action` 變體承載側欄底部三項，「寫入清單」帶失敗計數 `badge`（1.143） | 殼 | `default` / `action`；狀態 selected / unselected / hover |
| `ProjectSwitcherEntry`（專案切換入口） | 元件 | L3 | 側欄頂端：資料夾圖示 + 目前專案名（單行截斷）+ 展開箭頭；= SPEC-001 §7 收合態，`project-switcher-entry` | 殼 | `default`；阻擋狀態下恆 enabled（SPEC-003 §2.7 浮層可用性斷言） |
| `RecentProjectItem`（最近專案項） | 元件 | L3 | 浮層內單一專案選項：圖示 + 名稱 + 摘要（節點數 · 票數）+ 健康徽章 slot + 不可用原因常駐文字，`card-switcher-recent-<index>` | §7 | `default`；狀態 enabled / disabled（附原因文字，不用 tooltip）/ selected（目前專案） |
| `SegmentedControl`（分段控制） | 元件 | L3 | 互斥單選的常駐切換：雙模式切換（矩陣／泳道、列表／主題，`mode-*`）與變更記錄的期間選擇（`option-history-period-<period>`） | §1、§4、§10 | `default`；段數 2–3（三段只用於 §10 期間選擇，1.131） |
| `PageTitle`（頁面標題） | 元件 | L3 | 頁首左側：畫面名 + 一行副標（模式說明或選取摘要） | §1–§6 | `default`；副標為可選 slot |
| `SearchField`（搜尋框） | 元件 | L2 | Ticket 清單工具列搜尋，`input-tickets-search` | §4 | `default`；狀態 empty / filled / focused |
| `FilterDropdown`（篩選下拉） | 元件 | L2 | 「狀態：pending」「優先：全部」類的篩選觸發器，`action-tickets-filter-<key>` | §4 | `default`；狀態 default / active（有篩選值）/ open |
| `TableColumnHeader`（表格欄首） | 元件 | L2 | 表格與矩陣的欄首標籤；矩陣欄首為兩行（UC ID + 名稱） | §1、§2、§4 | `static` / `sortable`（`action-tickets-sort-<key>`，狀態 unsorted / asc / desc）/ `twoLine`（矩陣欄首，提案併入本元件，見 3.3 第 10 項） |
| `MatrixCell`（矩陣格） | 元件 | L3 | domain × UC 交叉格的關係符號，可點擊選格，`cell-domain-<rowId>-<colId>` | §1 | `direct`（● `AppColors.accent`）/ `indirect`（○ `AppColors.textSecondary`）/ `none`（· `AppColors.borderStrong`）；狀態 default / hover / rowSelected（列高亮 `AppColors.surfaceIconTint`）/ selected（本格選取） |
| `SwimlaneNode`（泳道節點） | 元件 | L3 | 泳道格內的動作標籤（掃描、解析、建圖…），0.1 不可點、不可拖 | §1 | `active`（`AppColors.accent` 底、白字）/ `inactive`（`AppColors.surfaceChip` 底） |
| `StepNumber`（步驟序號） | 元件 | L3 | 步驟列與詳情卡步驟清單的序號 | §1（詳情卡）、§2 | `default`；統一圓形（§3.7 第 11 項）；直徑 `LayoutSize.stepNumberSize`（24） |
| `ExpanderIcon`（展開收合） | 元件 | L2 | 樹節點、主題節、破洞分節的展開觸發器，`expander-*` | §3、§4、§5 | `default`；狀態 expanded / collapsed / leaf（無子層時不渲染箭頭但保留寬度） |
| `RelationItem`（關聯項） | 元件 | L3 | 節點詳情右欄的關聯節點 ID，等寬字、chip 底、可點擊替換主欄，`card-nodeDetail-relation-<nodeId>`；變更記錄事件列的宣告端與對端節點，`action-history-open-<index>-<side>` | §6、§2、§10 | `default`；狀態 default / hover / damaged（邊損壞時套 `IssueMarker.damagedEdge`） |
| `DocumentBody`（文件內文） | 元件 | L3 | 節點詳情主欄的 markdown 渲染內容（段落、行內 code、FR 引用區塊）；由 0.0.3 選定的 `flutter_markdown_plus` 承載，渲染器內部 widget 列第 7 章豁免 | §6 | `default`；屬元件庫（§3.7 第 7 項） |
| `EmptyState`（空狀態） | 元件 | L3 | 「這裡目前沒有內容」+ 至少一個非返回的前進動作（FR-03，`page` 列舉狀態；無破洞與 `section` 例外見 SPEC-003 §2.7）；訊息、說明、動作為 slot | §1（未選專案、空圖、未選格右欄、泳道 · 尚未選定 UC、泳道 · 投影準備中、泳道 · flow 未結構化）、§2（專案未就緒、無 UC、尚未選定 UC、flow 未結構化）、§3（專案未就緒、無提案、圖不可用）、§4（專案未就緒、無 ticket）、§5（專案未就緒、無破洞）、§6（專案未就緒、未選節點、圖不可用、節點不在目前的圖上）、§10（專案未就緒、期間內無事件、非 git 專案、找不到 git、讀取失敗、已取消） | `page`（全頁）/ `section`（區塊內：與 UC 基本資訊並列、未選格右欄、泳道 · 尚未選定 UC、泳道 · flow 未結構化、§2 尚未選定 UC）；`missing` 改為獨立元件 `MissingSourceState`、`compact` 刪除（§3.7 第 3 項） |
| `MissingSourceState`（原始檔已消失） | 元件 | L3 | 「原始檔已不存在」+ 最後已知路徑 + 重新整理／返回；退出留在畫面內（重新整理三分支，SPEC-003 §3.6），與 `EmptyState.page` 的跳轉層級不同故獨立 | §6（原始檔已消失） | `default` |
| `BlockedState`（阻擋狀態） | 元件 | L3 | 「這個專案不適用本 App」+ 版本值（不是框架專案無）+ 說明 + 切換專案出口（恆可用，FR-07）；無可消費的型別表時另提供「以 App 內建型別表檢視」條件式渲染出口（`action-domain-degraded-view`，SPEC-003 §3.1，`0.1.0-W1-035` 定案）。載入失敗不屬「不適用」，同以本元件承載但內容不同：訊息改為結果與原因（`domainLoadFailedMessage`）+ 「重新載入」（`action-domain-reload`，`onReload` 非 null 時渲染）+ 切換專案出口，無版本值、無說明（§3.6 該列，`0.5.0-W1-114.14.1`） | §1（不是框架專案、無可消費的型別表、schema 不相容、載入失敗） | `plain` / `withDetail`（附「檢視詳情」展開 `panel-domain-schema-detail`，內容為「App 已知版本範圍」一列標籤 + 值的 `Section`） |
| `LoadingState`（載入態） | 元件 | L3 | 骨架或進度 + 計數文字 + 取消；取消契約 C1–C8 與生命週期 L1–L2（共 10 條，SPEC-003 §2.5、§2.8）由本元件單一承擔 | §1（載入中）、§5（掃描中）、§10（讀取中） | `skeleton`（indeterminate + 計數文字；骨架版位 slot：`matrix` / `sections` / `rows`） |
| `AppCheckbox`（核取切換） | 元件 | L2 | 單一布林設定的常駐切換：核取框 + 文字，點擊切換值；變更記錄的「包含 ticket 建檔」，`action-history-include-ticket-created`（1.131 新增，既有元件不適用的理由見 4.43） | §10 | `default`；狀態 checked / unchecked |
| `AppTextInput`（文字輸入） | 元件 | L2 | 表單欄位的自由文字值輸入，與過渡期無值域的列舉欄位（SPEC-009 FR-09；1.140 新增，不沿用 `SearchField` 的理由見 4.44） | §6 編輯模式 | `singleLine` / `multiLine`；狀態含 locked（寫入中唯讀鎖定，1.143） |
| `AppDropdown`（下拉） | 元件 | L2 | 表單欄位的列舉值選擇（等級、文件節點生命週期；1.140 新增，不沿用 `FilterDropdown` 的理由見 4.45） | §6 編輯模式 | `default`；狀態 empty / set / outOfDomain / open / locked |
| `ReferencePicker`（可搜尋下拉） | 元件 | L2 | 表單欄位的單一引用選擇（PROP target_version、SPEC domain；1.140 新增） | §6 編輯模式 | `default`；`allowEmpty` 為參數 |
| `ReferenceChips`（chips 加搜尋） | 容器 | L2 | 表單欄位的多值引用（節點 ID）：已選值 chip（含移除鈕）× N + 加入觸發器，排不下換列；加入時展開與 4.46 同形的覆蓋層（1.148 新增，4.52） | §6 編輯模式 | `default`；chip 的找不到外觀為值對映參數 |
| `AppCheckboxGroup`（核取清單） | 容器 | L2 | 表單欄位的多值選擇，值為已宣告 domain：`AppCheckbox` × N 垂直（1.148 新增，4.53） | §6 編輯模式 | `default` |
| `AppRadioGroup`（單選鈕組） | 元件 | L2 | 表單欄位的分類值選擇（SPEC has_functional_requirements、EVT category；1.140 新增，不沿用 `SegmentedControl` 的理由見 4.47） | §6 編輯模式 | `default`；選項 2 以上、不設上限（用戶裁定 2026-11-11，`1.0.0-W3-553.6`）、恆垂直（用戶裁定，`1.0.0-W3-675`） |
| `NoticeBanner`（區塊橫幅） | 元件 | L2 | 區塊頂端的常駐說明：訊息 + 0..1 個動作，不取代下方內容；1.0 用於編輯區頂端橫幅（外部已改預警／阻擋／重讀讀取失敗，`panel-nodeDetail-edit-banner`；1.143 新增，不沿用 `BlockedState`／`AppSnackBar` 的理由見 4.49） | §6 編輯模式 | `warning` / `negative` |
| `AppSnackBar`（即時訊息） | 元件 | L2 | 「已在外部開啟」「找不到檔案」類的暫時訊息，Material 預設動畫不覆寫 | §1、§2、§4、§5、§6、§7（`denied` fallback 於任一畫面） | `plain`（停留 `Motion.snackBar`）/ `withAction`（帶一個動作，停留 `Motion.snackBarWithAction`）；封裝為元件（§3.7 第 8 項） |

#### 容器

| 元件 | 種類 | 層級 | 用途 | 出現畫面 | 變體（variant） |
|------|------|------|------|---------|----------------|
| `AppShell`（根框架） | 容器 | L3 | 根：無父容器。標題列（`AppText.title` 應用名）/ 側欄（`ProjectSwitcherEntry` + `NavItem` × 7，垂直）/ 主區（`PageColumn`）三格；側欄固定寬、主區填滿 | 殼 | `default`；元件庫 `AppShell` 傳值、不 watch；訂閱由組裝層 `lib/assembly/shell.dart` 承擔（漂移見 3.5） |
| `PageColumn`（頁面區塊堆疊） | 容器 | L3 | 每頁根堆疊：`SplitRow.header` + 內容（`Panel` 或 `TwoColumnLayout` 或狀態元件）垂直；內容區內距 `Space.xl` | §1–§6 | `default` |
| `SplitRow`（左右分列） | 容器 | L2 | 左右兩端對齊的水平列：頁首（`PageTitle` + `SegmentedControl`）、Ticket 清單摘要底列（`AppText` + `AppText`） | §1–§6（頁首）、§4（底列） | `header`（固定高、底邊框 `AppColors.border`、底 `AppColors.surfaceBase`）/ `footer`（頂邊框）；合併為提案（3.3 第 13 項） |
| `Panel`（面板） | 容器 | L2 | 白底（`AppColors.surfaceBase`）、邊框 `AppColors.border`、圓角 `Radius.lg`、內距 `Space.md` 的垂直堆疊；子件為具名清單（`Toolbar` / `TableRow.header` / `DataTable` / `MatrixGrid` / `SwimlaneGrid` / `Tree` / `Section` / `BadgeRow` / `Divider` / `AppText` / `DocumentBody` / `ListRow`） | §1–§6 | `default` / `scrollable`（主體可垂直捲動，承載 SPEC-003 §1.1〈捲動處清單〉中一維垂直捲動者） |
| `TwoColumnLayout`（主副雙欄） | 容器 | L3 | 主欄 `Panel`（填滿）+ 右欄 `Panel.scrollable`（固定寬 `LayoutSize.detailPaneWidth`）水平並排，間距 `Space.md`；兩欄各自獨立捲動（SPEC-003 FR-10、§1.1 連動禁令） | §1（正常·矩陣、已選格）、§2（尚未選定 UC、flow 未結構化、正常：右欄為 UC 選擇清單，§3.6）、§6（正常、部分損壞） | `default`（§3.7 第 16、21 項） |
| `Toolbar`（工具列） | 容器 | L2 | `SearchField`（填滿）+ `FilterDropdown` × N + `IssueMarker.damagedDetail`（可點錨點 `badge-tickets-corrupted`，§3.7 第 14 項）水平，底邊框；變更記錄篩選列：`SegmentedControl`（期間）+ `AppCheckbox`（包含 ticket 建檔）水平 | §4、§10 | `default` / `history`（1.131） |
| `BadgeRow`（徽章列） | 容器 | L2 | `Badge` × N 水平、間距 `Space.xs`，空間不足換行；承載節點詳情標籤列、矩陣與泳道圖例列、事件標籤 | §1、§2、§6 | `default` / `legend`（頂邊框，面板底部；間距同 `Space.xs`，§3.7 第 12 項） |
| `ButtonRow`（按鈕列） | 容器 | L2 | `AppButton` × N 水平；承載狀態元件的動作區（開始載入；重新整理；開啟原始檔 + 檢視關聯）、頁首右側頁面級動作區（§3.7 第 17、18 項）、格詳情卡動作區；可修正破洞項的 trailing（編輯欄位 + 開啟原始檔，`wrap: false`，1.150） | §1–§6 | `default`（`alignment`、`wrap` 參數，`wrap` 1.150）；子件上限 3（0.1 最多三動作） |
| `TableRow`（表格列） | 容器 | L2 | 欄寬對齊表頭的水平格線列；子件 ∈ {`TableColumnHeader`, `AppText`, `Badge`, `StepNumber`, `BadgeRow`, `IssueMarker`, `RelationItem`（步驟列 domain 欄，可點）} | §2、§4 | `header`（`TableColumnHeader` × N）/ `ticket`（ID mono、標題、狀態徽章、優先、blockedBy、損壞標記；列表與主題模式共用同一欄序，§3.7 第 15 項；blockedBy 欄出處 SPEC-001 §4）/ `step`（序號、步驟名、domain 標籤、事件徽章列）/ `eventFlow`（事件 ID mono、發出、消費、孤立事件標記；非互動，可被定位；SPEC-001 §2〈事件流小表〉）/ `historyEvent`（變動、邊型、宣告端、對端、commit、日期、作者與訊息；列本體非互動，節點格可點；SPEC-001 §10，1.131） |
| `DataTable`（資料表） | 容器 | L2（資料視圖） | `TableRow.header` + `TableRow` × N 垂直；Ticket 清單為虛擬捲動（`scroll-tickets-list`），UC Flow 為一般捲動（`scroll-ucFlow-steps`），變更記錄事件清單為虛擬捲動（`scroll-history-events`） | §2、§4、§10 | `virtual` / `plain` |
| `MatrixGrid`（矩陣） | 容器 | L3（資料視圖） | domain × UC 二維格線：欄首 `TableColumnHeader.twoLine`、列首 `AppText`、格 `MatrixCell`、小計 `AppText.caption`；欄首與列首釘選、二維捲動（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`） | §1 | `default` |
| `SwimlaneGrid`（泳道） | 容器 | L3（資料視圖） | 泳道列（`AppText` 泳道名 + `SwimlaneNode` 置於步驟欄）× （DomainBundle 數＋1，有未定位步驟時＋2）垂直（「畫面」列 + 每個 DomainBundle 一列，有 `traverses` 異常步驟時於全部 DomainBundle 列之後加「未定位」列，本專案 9 列）、列間虛線；步驟間邊（直線／弧線）；底部步驟箭頭列；列序、欄序、邊形狀依 SPEC-001 §1〈泳道布局規則〉（「畫面」列 + 每個 DomainBundle 一列依 `bundle_dependency` 推導層序與同層字母序、主線清單順序與分支（含巢狀）插欄、前向直線與回指弧線；0.1 為假資料靜態排版，SPEC-001 設計約束），二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`） | §1 | `default` |
| `Tree`（樹） | 容器 | L3（資料視圖） | `ListRow.tree` × N 垂直，依深度縮排；展開收合改變列集合（`scroll-traceability-tree`） | §3、§6（來源鏈） | `default` / `sourceChain`（節點詳情主欄內嵌來源鏈：全部展開、無展開器、不持有展開集合，4.39） |
| `ListRow`（通用列） | 容器 | L2 | leading（`ExpanderIcon` / `AppIcon` / `Badge` / `StepNumber`，可選）+ 主文字 `AppText`（填滿）+ 次文字 `AppText.secondary`（可選，堆疊於主文字下）+ trailing（`Badge` / `AppIcon` / `AppText.caption` / `IssueMarker` / `AppButton.text` / `ButtonRow`，可選；後兩者限 `item`，`ButtonRow` 1.150）水平 | §1（詳情卡步驟）、§2（UC 選擇清單）、§3（樹節點）、§4（主題節首）、§5（分節首、破洞項）、§6（節點 meta 列） | `tree`（展開 + 標題 + 狀態徽章）/ `sectionHeader`（展開或類別徽章 + 名稱 + 計數）/ `item`（標題 + 說明 + trailing：有指向節點者為次要操作「開啟原始檔」按鈕，可修正的破洞項另加「編輯欄位」、兩鈕以 `ButtonRow`（`wrap: false`）承載（1.150），無指向者為外開箭頭）/ `option`（UC ID + 標題，可選取，selected 態；UC-03 步驟 1）/ `meta`（型別徽章 + 路徑 mono）/ `numbered`（序號 + 文字）；合併為提案（3.3 第 12 項） |
| `Section`（分節） | 容器 | L2 | 節首 + 項目垂直堆疊：主題節（`ListRow.sectionHeader` + `TableRow.ticket` × N）、破洞類別節（`ListRow.sectionHeader` + `ListRow.item` × N）、關聯群（`AppText.caption` + `RelationItem` × N）、UC 選擇清單（`AppText.caption` + `ListRow.option` × N）、schema 詳情面板（`AppText.caption` + `AppText.mono`） | §1（詳情面板）、§2（UC 選擇清單）、§4、§5、§6 | `collapsible`（節首含 `ExpanderIcon`，`expander-*`）/ `static`；「未歸屬」節以頂部虛線分隔為修飾參數（§3.7 第 4 項核定 3.3 第 14 項） |
| `FieldBlock`（表單欄位） | 容器 | L2 | label（`AppText`）+ 值格（`AppTextInput` / `AppDropdown` / `ReferencePicker` / `AppRadioGroup` / `ReferenceChips` / `AppCheckboxGroup`（後兩者 1.148），或唯讀 `AppText`）+ 提示格（`AppText.caption`，0..1）垂直；寫入結果與驗證狀態在此呈現（1.140 新增） | §6 編輯模式 | `editable` / `readOnly` |
| `FieldList`（欄位清單） | 容器 | L3 | `NoticeBanner`（0..1）+ `FieldBlock` × N（SPEC-009 FR-09 表列序）+ 「完成」`AppButton.primary` 垂直；承載寫入期間的跨欄鎖定（1.143 新增，4.50） | §6 編輯模式（`panel-nodeDetail-field-list`） | 單一形態 |
| `WriteLogRow`（寫入清單列） | 容器 | L3 | 路徑（可點時 `AppButton.text`）+ 欄位名 + 所屬專案 + 寫入結果與驗證狀態徽章（含說明）+ 取回說明 `AppText.code` + 快照期限說明，垂直分行（1.143 新增，4.51） | §12（`card-writeLog-row-<index>`） | 單一形態；子件依列資料渲染 |
| `SwitcherOverlay`（專案切換浮層） | 容器 | L3 | 覆蓋層：`AppText.caption` 標題 + `RecentProjectItem` × N（垂直捲動 `scroll-switcher-recent`）+ `Divider` + `AppButton.text`（選擇其他資料夾）；自入口向下展開，Esc／點外部收合，焦點限制於浮層內 | §7（展開、無最近專案） | `default`；`RecentProjectItem` 數量無上限 → 空間不足策略為捲動 |

**1.140 新增（`1.0.0-W3-553.6`，PM 審查通過 2026-11-11；含待決欄位，不可被畫面票引用，見 §4.0.9）**：元件 `AppTextInput`、`AppDropdown`、`ReferencePicker`、`AppRadioGroup`（4.44–4.47），容器 `FieldBlock`（4.48、5.17）；1.140 時含待決欄位，1.143 已回填，封鎖狀態見 §4.0.9。

**1.143 新增（`1.0.0-W3-553.3.1`）**：元件 `NoticeBanner`（4.49）；容器 `FieldList`（4.50、5.18，即 1.140 記為待決的欄位堆疊）、`WriteLogRow`（4.51、5.19）；修改 `AppText`（加 `code` 變體）、`NavItem`（`action` 變體加 `badge` slot）、`Badge.count`（加寫入清單失敗計數用途）、`AppShell`（側欄底部三項、唯讀降級徽章）。寫入清單面板與 §9、§11 兩個面板同樣是組合，不另立元件（§3.6 §12 兩列）。

**定案數（§3.7 核定後）**：元件 32（原 25 加 `MissingSourceState`，1.131 加 `AppCheckbox`，1.140 加 4.44–4.47 共 4 個，1.143 加 `NoticeBanner`）、容器 19（1.140 前實列 16，1.140 加 `FieldBlock`，1.143 加 `FieldList`、`WriteLogRow`；其中資料視圖 4：`DataTable`、`MatrixGrid`、`SwimlaneGrid`、`Tree`；0.1 版原記「17」為計數誤差，與現值 17 無關）。
非資料視圖的容器 15 個（§3.7 核定時 12 個，1.140 加 `FieldBlock`、1.143 加 `FieldList` 與 `WriteLogRow`，三者的存在必要性各見其條目），超過 skill〈Troubleshooting〉的十個門檻；3.5 記錄已做的歸併與未再歸併的理由，
再往下歸併須把 slot 子件清單寫成「任意元件」，skill 明文視同原生佈局，§3.7 第 10 項核定接受此數。

### 3.2 模式 B 步驟 1-2：視覺單元盤點與語意問句

逐 artboard（`design/` 九份，`canvas.json` 所列）框出可獨立辨識的區塊；相同外觀先各自列，語意問句
（使用者看到它預期能做什麼？承載標題／內文／標籤／數值／動作哪一種？）的答案為歸併依據。
框架層（標題列、側欄、頁首）九份皆同，只列一次。

| 畫面（artboard） | 視覺單元 | 語意問句答案 | 歸屬（3.1） |
|------|------|------|------|
| 全部（框架層） | 頂端標題列「專案文件流」 | 標題；無動作 | `AppShell` 標題列 slot（`AppText.title`） |
| 全部 | 側欄頂端：資料夾圖示 + 專案名 + 展開箭頭 | 動作（開啟切換）+ 標籤（目前專案） | `ProjectSwitcherEntry` |
| 全部 | 側欄導覽項：圖示 + 名稱，一項高亮底（畫布畫六項；第七項「變更記錄」由 SPEC-001 §10 新增，畫布未更新，規格為準） | 動作（換頁）；selected 態 | `NavItem` × 7 |
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

畫布未畫、只在 SPEC-001 顯示欄與 SPEC-003 出現的單元（規格為準，不視為缺件）：空狀態（各畫面 + 未選專案 + 未選節點）、
阻擋狀態（三處）、載入態（三處）、待載入提示、原始檔已消失、schema 詳情面板、SnackBar、返回鍵。歸屬見 3.6 對照表。

### 3.3 模式 A 步驟 3：存在必要性檢視（核定結果見 §3.7，本節保留提案原文與理由）

方向依 skill：先假設能併，找不到併不進去的理由才立特化元件；理由只認語意或行為差異，外觀差異不構成理由。理由欄記錄提案當時（2026-09-02）的行為與計數，不隨上游改版回改；現行行為與計數以 §3.1 與 SPEC-001／SPEC-003 條文為準。

| # | 候選 | 結論（提案） | 理由 |
|---|------|------|------|
| 1 | 空狀態 vs 阻擋狀態 | **不合併**（維持 SPEC-002 決定） | 語氣不同（「這裡目前沒有東西」vs「這個專案不適用」）、退出層級不同（跳轉至其他畫面 vs 離開專案）、FR-03 與 FR-07 的驗收會互相污染；SPEC-003 §2.7 已依此定行為差異 |
| 2 | 未選專案（§1）併入空狀態 | **合併**為 `EmptyState.page` | SPEC-002 空狀態清單未列此狀態，但語意同為「沒有內容」，前進動作（選擇資料夾）非返回、觸發後進入載入中；與其他空狀態的差異只在動作目的地，依 skill 步驟 3「只是目的地不同者為 slot」 |
| 3 | flow 未結構化、原始檔已消失、無最近專案 併入空狀態 | **合併**為 `EmptyState` 變體 `section` / `missing` / `compact` | 三者語意皆為「此處目前沒有內容」：flow 區塊無內容（與 UC 基本資訊並列，故為區塊級）、原始檔不在了（附最後已知路徑，前進動作重新整理）、最近清單為空（僅剩選擇資料夾動作）。反面理由：`missing` 的重新整理留在畫面內，與 `page` 的跳轉層級不同——若 PM 認定退出層級差異足以拆件，`missing` 改為獨立元件，其餘結論不變 |
| 4 | 未載入（§4）併入空狀態 | **不合併**，立 `LoadPrompt`（v1.118 起元件退役，見 4.25） | 語意相反：空狀態說「沒有內容」，未載入說「有 N 筆內容尚未載入」；含數值角色（N）；前進動作進入載入態並由 FR-02 取消契約承接；FR-03 對它不適用。合併會讓「空狀態必有前進動作」與「未載入必顯示票數」兩條驗收互相污染 |
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
| 殼 | 側欄垂直：`ProjectSwitcherEntry` / `NavItem` × 7 | `Space.xxs`（項間）、`Space.sm`（入口下方）、側欄內距 `Space.md` × `Space.sm` | `AppShell` 側欄 slot（殼層以框架容器承載，不另立） |
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
| §1 schema 不相容 | 詳情面板垂直：小標 / 範圍值（不高於內建版本；畫布未畫） | `Space.xs`（提案） | `Section.static` |

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
| 導覽項在畫布有 leading 圖示，`lib/assembly/shell.dart` 的 `_NavItem` 無圖示 | 視覺值 | 畫布為準：`NavItem` 契約含 icon slot；shell 對齊屬元件庫實作票（W1-005）範圍，於本票 NeedsContext 記錄 |
| 側欄寬度：畫布與 `shell.dart` 的 `_kSidebarWidth` 不一致 | 視覺值 | 畫布為準；該值無 token，屬佈局尺寸 token 缺料（NeedsContext），第 4 章尺寸契約標待決 |
| 矩陣格詳情卡右欄寬與節點詳情右欄寬不同 | 視覺值 | 兩個值皆無 token；`TwoColumnLayout` 右欄寬待 token 前置票，或於核定時收斂為一個 |
| 步驟序號圓形（§2）vs 方形（§1 詳情卡） | 視覺值 | `Radius` token 兩階皆可表達；是否統一**待核定** |
| 圖例列間距矩陣 `Space.lg` vs 泳道 `Space.xs` | 視覺值 | `BadgeRow.legend` 取單一值，**待核定** |
| Ticket 清單損壞計數畫布放在摘要底列文字內，SPEC-003 要求 `badge-tickets-corrupted` 為可點錨點 | 行為類 | 規格為準：`IssueMarker.damagedDetail` 須為獨立可點元素；放於 `SplitRow.footer` 或 `Toolbar` **待核定** |
| Ticket 主題模式票列欄序（ID / 優先 / 標題 / 狀態）與列表模式（ID / 標題 / 狀態 / 優先）不同 | 視覺值 | 是否為 `TableRow` 第三變體或統一欄序**待核定** |
| 節點詳情主欄面板內距大於其他面板 | 視覺值 | `Panel` 內距是否分兩階**待核定** |
| 畫布所有面板皆無捲軸、無溢位表現 | 畫布不可得 | 空間不足策略以 SPEC-003 §1.1〈捲動處清單〉為準（第 5 章填） |
| 畫布未畫：空狀態、阻擋狀態、載入態、待載入提示、返回鍵、SnackBar、schema 詳情面板 | 規格有、畫布無 | 規格為準，不視為缺件；其排列（icon / 訊息 / 說明 / 動作列的堆疊）於第 4 章依 SPEC-003 §2.6–§2.7 填 |
| `design/Main.dc.html` 矩陣模式頁首副標「點格子切換至泳道」，SPEC-003 §3.1 採方案 B 後單擊為選格 | 行為類（規格為準） | 副標改為「點格子檢視詳情」；畫布不回改，畫面票的副標文案依 SPEC-003（W1-048 消費結果） |
| 畫布無 hover / focused / pressed 任何樣式，無格詳情卡關閉鈕、無矩陣格選取態 | 畫布不可得 | 互動瞬態視覺依 §4.0.1 通用約定（Material 內建 overlay，不自繪，標提案）；選取態依 §4.15 成對設計 |
| 畫布頂端標題列高 36、票表固定寬欄 132 / 84 / 40 / 22、步驟表 26 / 118、樹縮排每層 24、步驟序號 16 與 24 兩值 | 視覺值，token 缺 | 已建對應 token：`LayoutSize.titleBarHeight`（36）、`ticketIdColumnWidth`／`ticketStatusColumnWidth`／`ticketPriorityColumnWidth`／`ticketMarkerColumnWidth`（132／84／40／22）、`stepNumberColumnWidth`／`stepDomainColumnWidth`（26／118）、`treeIndent`（24）、`stepNumberSize`（16 與 24 兩值收斂為 24）（`0.1.0-W1-055`）；§4.0.9 待決清單去標 |

### 3.6 SPEC-001 狀態列與 SPEC-002 八類的歸屬對照

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

**SPEC-001 狀態列顯示欄 → 本檔**（狀態元件內部的訊息／說明／動作皆為該元件的 slot，不另列；本表列數與 SPEC-001〈狀態總數〉的加總值相同、順序依 SPEC-001 各節，數值以該節為準不在此複述）：

| § | 狀態 | 顯示欄單元 | 歸屬 |
|---|------|------|------|
| §1 | 未選專案 | 空畫面 + 選擇資料夾引導 | `EmptyState.page`（動作 `AppButton.primary` 選擇資料夾） |
| §1 | 載入中 | 骨架版面 + 進度 + 取消 | `LoadingState.skeleton`（版位 `matrix`） |
| §1 | 正常 · 矩陣 | domain × UC 交叉表 + 右欄格詳情卡區（未選格常駐提示） | `PageColumn`[`SplitRow.header`[`PageTitle`, `SegmentedControl`], `TwoColumnLayout`[`Panel`[`MatrixGrid`, `BadgeRow.legend`], `Panel.scrollable`[`EmptyState.section`（`panel-domain-cell-detail-empty`，訊息 `cellDetailPrompt`，無動作）]]] |
| §1 | 已選格（疊加於正常 · 矩陣） | 右欄格詳情卡：標題、關係種類、說明、編號步驟、事件標籤、在泳道中檢視、關閉 | 底層同上 + 右欄 `Panel.scrollable`[`SplitRow.header`[`AppText.subtitle`, `AppButton.text`（關閉，`action-domain-cell-clear`）], `AppText.caption`（關係種類）, `AppText.body`（說明，可缺）, `ListRow.numbered` × N（可缺）, `BadgeRow`[`Badge.event` × N]（可缺）, `AppText.body` × N（依賴路徑，每條一行，僅 `indirect` 格渲染；路徑集合、排序與跳轉目標見 SPEC-001 §1〈間接依賴格的詳情卡：依賴路徑〉，`0.5.0-W1-093.1`）, `ButtonRow`[`AppButton.secondary`（在泳道中檢視，`action-domain-cell-goto-swimlane`；`indirect` 格的定位目標為依賴路徑第一行來源 domain 的列）]]（`panel-domain-cell-detail`，`scroll-domain-cell-detail`）；`MatrixCell` 呈 `selected` |
| §1 | 正常 · 泳道 | flow 橫向穿過 domain 泳道；選定 UC 有 flow 區塊解析失敗但仍有合法區塊時加提示（SPEC-001 §1〈flow 區塊解析失敗的泳道呈現〉(a)） | `Panel`[`AppText.subtitle`（`swimlanePanelTitle`，`<UC id> <UC 標題>`，`0.1.0-W3-335.57` E8）, `AppText.multiLine`（`maxLines: 2`、`secondary: true`；僅解析失敗時渲染，訊息 `swimlaneFlowParseFailedHint`，置於 `SwimlaneGrid` 之上；元件與位置已定，`0.5.0-W1-114.1` PM 處置 NC-g）, `SwimlaneGrid`, `BadgeRow.legend`[`Badge.legend` × 2：`laneNodeActive` / `laneNodeInactive`，沿用 4.16 既有 key（`0.1.0-W3-335.47` D6）]] |
| §1 | 泳道 · 尚未選定 UC | domain 泳道列（不含步驟節點）+ 提示需先選定 UC 並指出選定方式；無 UC 標題 | `Panel`[`EmptyState.section`（`state-domain-swimlane-uc-unset` 內，訊息 `swimlaneUcUnsetPrompt`，無動作——SPEC-001 §1 註記：泳道內不提供 UC 選擇入口，提示指向矩陣點格與 UC Flow 視圖）, `SwimlaneGrid`（零個 `SwimlaneNode`，泳道列與列首照常渲染）]；不渲染 `BadgeRow.legend`（無節點可圖例）。提示置於泳道列之上，理由：泳道列數隨 domain 數成長，置下方時提示可能被捲出可見範圍（提案） |
| §1 | 泳道 · 投影準備中 | 面板標題為選定 UC + domain 泳道列（不含步驟節點）+ 準備中提示 | `Panel`[`AppText.subtitle`（`swimlanePanelTitle`，`<UC id> <UC 標題>`，拿不到 UC 標題時只顯示 UC id）, `EmptyState.section`（`state-domain-swimlane-projection-pending` 內，訊息 `swimlaneProjectionPendingPrompt`，無動作——該專案首次輪次完成即自動轉出，不需使用者操作）, `SwimlaneGrid`（零個 `SwimlaneNode`，泳道列與列首照常渲染）]；不渲染 `BadgeRow.legend`；提示置於泳道列之上，理由同「泳道 · 尚未選定 UC」列（SPEC-001 v1.55，`0.5.0-W1-205.1`） |
| §1 | 泳道 · flow 未結構化 | 面板標題為選定 UC + 「此 UC 尚未填寫結構化 flow」；不渲染泳道列 | `Panel`[`AppText.subtitle`（`swimlanePanelTitle`，`<UC id> <UC 標題>`，`0.1.0-W3-335.57` E8）, `EmptyState.section`（訊息 `flowUnstructuredMessage`，與 §2 同一狀態共用 key；選定 UC 的 flow 區塊皆解析失敗時改為 `flowParseFailedMessage`（SPEC-001 §1〈flow 區塊解析失敗的泳道呈現〉(b)，`0.5.0-W1-114.1` PM 處置 NC-g；§2 同一狀態同 key，NC-f）；動作 `ButtonRow`[`AppButton.secondary` 開啟原始檔 `action-domain-open-source`，既有 `openSourceFileAction`，兩種文案共用]）]；切回矩陣由頁首 `SegmentedControl` 承載不另設按鈕 |
| §1 | 圖不可用 | 頁首照常 + 建圖不可用的原因 + 重新掃描；不渲染矩陣表、右欄格詳情卡區與泳道列 | `PageColumn`[`SplitRow.header`[`PageTitle`, `SegmentedControl`（兩模式皆可選，選中值改變不離開本狀態）], `Panel`[`EmptyState.section`（`state-domain-graph-unavailable` 內，訊息 `domainGraphUnavailableMessage`（代入 `appVersion`）；動作 `ButtonRow`[`AppButton.secondary` 重新掃描 `action-domain-rescan`，既有 `rescanAction`；輪次進行中 disabled]）；掃描輪次進行期間 `EmptyState.section` 訊息換成 `domainGraphUnavailableScanning`，下方附計數文字 `gapsScanningProcessedCount`（indeterminate，不顯示百分比，SPEC-003 §2.6），輪次結束後換回 `domainGraphUnavailableMessage` 或離開本列]]；矩陣與泳道兩模式同一組成，不渲染 `MatrixGrid`、`SwimlaneGrid`、`BadgeRow.legend` 與右欄（SPEC-001 v1.57，`0.5.0-W1-486.1`） |
| §1 | 空圖 | 訊息 + 說明 + 開啟 docs（條件）+ 前往破洞報告；切換專案由殼層入口承載 | `EmptyState.page`（`ButtonRow`[`AppButton` 開啟 docs（目錄存在時）, `AppButton` 前往破洞報告]） |
| §1 | 不是框架專案 | 訊息 + 說明本 App 需要什麼 + 出口 | `BlockedState.plain` |
| §1 | 無可消費的型別表 | 版本值 + 訊息 + 降級說明（條件）+ 出口 | `BlockedState.plain`（版本值 slot；降級說明 `onDegradedView` 非 null 時渲染，`0.1.0-W3-335.57` E2） |
| §1 | schema 不相容 | 版本不符說明 + 兩個版本值 + 檢視詳情 | `BlockedState.withDetail`（面板 `Section.static`[`AppText.caption`, `AppText.mono`]，內容為 App 已知版本範圍） |
| §1 | 載入失敗 | 訊息（結果與原因）+ 重新載入 + 出口 | `BlockedState.plain`（訊息 `domainLoadFailedMessage`，無說明、無版本值；`onReload` 非 null 時渲染重新載入，`0.5.0-W1-114.14.1`） |
| §2 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（動作 `AppButton.primary` 前往 Domain 視圖，`action-ucFlow-goto-domain`） |
| §2 | 無 UC | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §2 | 尚未選定 UC | UC 選擇入口 + 「選擇一條 UC 以檢視 flow」提示；不渲染步驟表（屬正常態）與 UC 基本資訊（屬 flow 未結構化態，`0.1.0-W3-335.47` D9） | `TwoColumnLayout`[`Panel`[`EmptyState.section`（訊息 `ucUnsetPrompt`，無動作——前進動作即右欄選擇入口）], 〈UC 選擇入口〉] |
| §2 | flow 未結構化 | UC 基本資訊 + 訊息 + 選擇 UC／開啟原始檔／檢視關聯 | `TwoColumnLayout`[`Panel`[`ListRow.meta`, `AppText.title`, `EmptyState.section`（訊息 `flowUnstructuredMessage`，選定 UC 的 flow 區塊皆解析失敗時改為 `flowParseFailedMessage`，與泳道同 key，`0.5.0-W1-114.1` NC-f；`ButtonRow` 動作：開啟原始檔、檢視關聯；不含返回 Domain 視圖，退出改由選擇 UC、通用返回、導覽列承擔，`0.1.0-W3-335.37` R7）], 〈UC 選擇入口〉] |
| §2 | 正常 | 垂直步驟表，domain 與事件成欄 + 事件流小表 | `TwoColumnLayout`[`Panel`[`DataTable.plain`（步驟表，`scroll-ucFlow-steps`）[`TableRow.header`, `TableRow.step` × N, `appendix`: `DataTable.plain`（事件流小表，`panel-ucFlow-event-flow`，本 UC 無事件時不渲染；不持有捲動）[`TableRow.header`（事件／發出／消費／標記）, `TableRow.eventFlow` × N]]], 〈UC 選擇入口〉]；事件流小表以步驟表的 `appendix` slot 接在最後一列之下、共用 `scroll-ucFlow-steps`（提案：`Panel.default` 資料視圖恰 1 的組合規則因此不變；兩個獨立捲動區垂直堆疊時，下方表的可見高會被步驟列數擠壓至零）；孤立事件標記見 4.35 `eventFlow` |
| §3 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（動作 `AppButton.primary` 前往 Domain 視圖，`action-traceability-goto-domain`） |
| §3 | 正常 | PROP→SPEC→UC→Ticket 樹狀（父子取自最後完成輪次的三條邊，SPEC-001 §3〈四層樹由掃描輪次衍生〉），各節點帶 status；初始只顯示 PROP 層 | `Panel.scrollable`[`Tree`[`ListRow.tree` × N]]；展開集合初始值見 4.39（v1.112 起無「Ticket 清單未載入」常駐說明列：Ticket 層與 Ticket 清單讀同一掃描輪次，SPEC-001 §3〈Ticket 層的資料來源〉） |
| §3 | 鏈路斷裂 | 每個缺下游的父節點下方一個虛線框缺口標示；含缺口分支初始自動展開至缺口層 | 同上 + 每個缺下游的父節點之下插入一列缺口列（深度 = 父節點深度 + 1，主文字 `traceabilityNoDownstream`、trailing `IssueMarker.gap`，testKey `badge-traceability-broken-<父節點 nodeId>`） |
| §3 | 無提案 | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §3 | 圖不可用 | 說明最近一次掃描無法建立圖譜 + 前往 Domain 視圖 | `EmptyState.page`（`state-traceability-graph-unavailable`，訊息 `traceabilityGraphUnavailableMessage`（代入 `appVersion`）；動作 `AppButton.primary` 前往 Domain 視圖 `action-traceability-goto-domain`，沿用專案未就緒的動作文案；不設重新掃描，同 §6「圖不可用」，SPEC-001 v1.67，`0.6.0-W1-110`） |
| §4 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（動作 `AppButton.primary` 前往 Domain 視圖，`action-tickets-goto-domain`） |
| §4 | 正常 · 列表 | 密集表格 + 虛擬捲動 + 搜尋／篩選／排序；票列含 blockedBy 欄 | `Panel`[`Toolbar`, `DataTable.virtual`[`TableRow.header`（ID／標題／狀態／優先為 `sortable`，blockedBy 與標記欄為 `static`——SPEC-001 §4 排序列舉不含 blockedBy）, `TableRow.ticket` × N], `SplitRow.footer`]。帶目標跳入（SPEC-003 §3.4〈帶目標跳入〉）清除搜尋與篩選時：`AppSnackBar.withAction`（訊息 `ticketsFiltersClearedSnackbarMessage`、動作 `undoAction`），目標列經 §4.0.10 定位（4.36 承載捲動，4.35 `ticket` 承載高亮） |
| §4 | 正常 · 主題 | 主題節 + 未歸屬節 | `Panel.scrollable`[`Section.collapsible` × N（含未歸屬）, `AppText.caption`] |
| §4 | 無 ticket | 訊息 + 導覽至破洞報告 | `EmptyState.page` |
| §4 | 含損壞（疊加態） | 正常視圖 + 損壞徽章與計數 | 底層正常態 + `Toolbar` 右側 `IssueMarker.damagedDetail`（可點 `badge-tickets-corrupted`，§3.7 第 14 項）+ 各損壞列末欄 `IssueMarker.damagedDetail`（圖示，可點 `badge-tickets-corrupted-<ticketId>`，不觸發開票、不定位破洞項，`0.1.0-W3-335.47` D2） |
| §5 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（動作 `AppButton.primary` 前往 Domain 視圖，`action-gaps-goto-domain`） |
| §5 | 掃描中 | 骨架 + 進度 + 取消 | `LoadingState.skeleton`（版位 `sections`） |
| §5 | 無破洞 | 訊息 + 掃描範圍說明 + 重新掃描 | `EmptyState.page`（說明 slot；無動作）；重新掃描 `AppButton.secondary` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 18 項，`0.1.0-W3-335.37` R10） |
| §5 | 有破洞 | 依類別分節，各項帶檔案與行號 + 重新掃描 | `Panel.scrollable`[`Section.collapsible`[`ListRow.sectionHeader`, `ListRow.item` × N] × N]；破洞項主操作依指向節點型別（SPEC-003 §3.5），有指向者 trailing 為次要操作 `AppButton.text`（開啟原始檔，`action-gaps-open-source-<itemId>`），無指向者 trailing 為 `AppIcon` 外開箭頭（見 4.40 `item`）；1.1 起可修正的破洞項 trailing 為 `ButtonRow`（`wrap: false`）[`AppButton.text`（`editFieldsAction`，`action-gaps-edit-<itemId>`）, 開啟原始檔]（SPEC-001 §5〈破洞報告的編輯入口〉）；重新掃描 `AppButton.secondary` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 18 項） |
| §5 | 無法判定破洞 | 頁首標題 + 原因說明（三選一）+ 其餘類別分節（有項目時）+ 重新掃描 | `Panel.scrollable`[`Section.static`[`AppText.subtitle`（`gapsUndeterminableTitle`）, `AppText.body`（`gapsUndeterminableReasonVersionOutOfRange`、`gapsUndeterminableReasonNoPathPattern` 或 `gapsUndeterminableReasonScanFailed`）], 其餘類別同「有破洞」列的 `Section.collapsible` × N（解析失敗類別不渲染）]；**不使用 `EmptyState`**，與無破洞的 `EmptyState.page` 在元件層即不同（SPEC-001 §5〈無法判定破洞〉成列註記）；重新掃描 `AppButton.secondary` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 18 項）（`0.3.0-W1-082`） |
| §6 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（動作 `AppButton.primary` 前往 Domain 視圖，`action-nodeDetail-goto-domain`；優先於「未選節點」，SPEC-003 §3.6 註記） |
| §6 | 未選節點 | 空狀態元件 + 「尚未選取節點」 | `EmptyState.page`（動作前往追溯視圖） |
| §6 | 正常 | 主欄分隔線以上為 frontmatter 欄位、以下為本文（不含 frontmatter，SPEC-001 §6〈主欄分隔線上下的內容〉）+ 關聯右欄 + 開啟原始檔／返回；選定節點為 Ticket 時分隔線下方另含來源鏈區塊（SPEC-001 §6〈來源鏈〉）；本文讀取或切分失敗時 `DocumentBody` 改為 `AppText.body`（`nodeDetailBodyUnavailableMessage`，4.20〈本文來源的界線〉） | `TwoColumnLayout`[`Panel.scrollable`[`ListRow.meta`, `AppText.title`, `BadgeRow`, `ButtonRow`[`AppButton.secondary`（`editFieldsAction`，`action-nodeDetail-edit`；選定節點為 Ticket 時不渲染；唯讀降級時 disabled，`disabledReason` 為唯讀降級徽章文字）]（1.143）, `AppText.caption`（`nodeDetailEditReadFailedMessage`，`badge-nodeDetail-edit-read-failed`；僅開始編輯的讀取失敗後渲染，1.143）, `Divider`, `Section.static`（僅選定節點為 Ticket 時；小標 `sourceChainTitle`，`panel-nodeDetail-source-chain`）[`Tree.sourceChain`[`ListRow.tree` × N]], `DocumentBody`], `Panel.scrollable`[`Section.static` × N]]；來源鏈缺上游列主文字 `sourceChainNoUpstream`、trailing `IssueMarker.gap`（`badge-nodeDetail-chain-broken-<nodeId>`），見 4.39〈`sourceChain` 變體〉；返回與開啟原始檔的 `AppButton` 於 `SplitRow.header` 右側 `ButtonRow`（§3.7 第 17 項；返回鍵由 `AppShell` 之下的頁面框架單一渲染，SPEC-003 §2.4） |
| §6 | 編輯中 | 分隔線以上整區（meta 列、標題、狀態徽章）由 FieldList 取代（各欄位一個 FieldBlock，末尾「完成」）；分隔線以下與關聯右欄同正常 | 同正常，唯 `ListRow.meta`、`AppText.title`、`BadgeRow`、「編輯欄位」`ButtonRow` 與讀取失敗說明改為 `FieldList`（4.50，`panel-nodeDetail-field-list`）[`FieldBlock` × N（`card-nodeDetail-field-<fieldKey>`，SPEC-009 FR-09 表列序）, `AppButton.primary`（`editDoneAction`，`action-nodeDetail-edit-done`）]；`panelKey` `state-nodeDetail-editing`（1.143，`1.0.0-W3-553.3.1`） |
| §6 | 外部已改預警 | 同編輯中 + FieldList 頂端橫幅（外部已改 + 放棄並重讀） | 同編輯中，`FieldList` 頂端加 `NoticeBanner.warning`（`editBannerExternallyModifiedWarning`，`panel-nodeDetail-edit-banner`；動作 `AppButton.secondary` `editDiscardAndReloadAction`，`action-nodeDetail-edit-reload`）；重讀讀取失敗時改 `NoticeBanner.negative`（`editBannerReloadFailed`）；`panelKey` `state-nodeDetail-edit-warning`（1.143） |
| §6 | 外部已改阻擋 | 同編輯中 + FieldList 頂端橫幅（這次寫入未執行 + 放棄並重讀）；各欄不可送出 | 同編輯中，`FieldList` 頂端加 `NoticeBanner.negative`（`editBannerExternallyModifiedBlocked`，動作同上）；`FieldList.isBlocked` 為 `true`，各值格 disabled 並保留未送出的值；重讀讀取失敗時訊息改 `editBannerReloadFailed`；`panelKey` `state-nodeDetail-edit-blocked`（1.143） |
| §6 | 部分損壞 | 可讀欄位 + 損失欄位標示 + 跳轉破洞報告 | 同上 + 欄位級 `IssueMarker.damagedDetail`（說明文字 slot） |
| §6 | 原始檔已消失 | 訊息 + 最後已知路徑 + 重新整理／返回 | `MissingSourceState`（`ButtonRow`[`AppButton.primary` 重新整理]）；返回由頁面框架渲染（SPEC-003 §2.4） |
| §6 | 圖不可用 | 說明最近一次掃描無法建立圖譜 + 前往 Domain 視圖 | `EmptyState.page`（`state-nodeDetail-graph-unavailable`，訊息 `nodeDetailGraphUnavailableMessage`（代入 `appVersion`）；動作 `AppButton.primary` 前往 Domain 視圖 `action-nodeDetail-goto-domain`，沿用專案未就緒的動作文案；不設重新掃描，重新掃描屬 Domain 視圖「圖不可用」列，SPEC-001 v1.65，`0.6.0-W1-105.2`） |
| §6 | 節點不在目前的圖上 | 訊息 + 選定節點 id + 可能原因 + 前往追溯視圖 | `EmptyState.page`（`state-nodeDetail-node-absent`，訊息 `nodeDetailNodeAbsentMessage`（代入 `nodeId`），說明 `nodeDetailNodeAbsentHint`；動作 `AppButton.primary` 前往追溯視圖 `action-nodeDetail-goto-traceability`，沿用未選節點的動作文案）；返回由頁面框架渲染（SPEC-003 §2.4）；不用 `MissingSourceState`——本狀態沒有可重新整理的對象（SPEC-001 v1.65，`0.6.0-W1-105.2`） |
| §7 | 收合 | 側欄頂端顯示目前專案名 | `ProjectSwitcherEntry` |
| §7 | 展開 | 最近專案清單 + 健康徽章 + 選擇其他 | `SwitcherOverlay`[`AppText.caption`, `RecentProjectItem`（`Badge.health`）× N, `Divider`, `AppButton.text`] |
| §7 | 無最近專案 | 僅「選擇資料夾…」 | `SwitcherOverlay` 零項 + `AppButton.text`（訊息文案 `switcherChooseFolderPrompt`；不用 `EmptyState`，§3.7 第 3 項） |
| §9 | 編輯器清單 | 單選清單：系統預設加查得 handler 的編輯器，目前選定值標示為選取 | `Panel.scrollable`[`AppText.subtitle`（`preferencesTitle`）, `ListRow.option` × N（`option-preferences-editor-<editorId>`；首項標籤 `preferencesEditorSystemOption`，其後為編輯器名稱，產品專有名詞不進 i18n）]，`footer`: `AppButton.text`（關閉，`action-preferences-close`，`autofocus`；固定於面板底部，4.30〈固定底部 slot〉） |
| §9 | 無可選編輯器 | 單選清單只有「系統預設（不定位）」且為選取 + 說明文字 | 同上：`ListRow.option` × 1（`option-preferences-editor-system`）+ `AppText.multiLine`（`preferencesNoEditorsExplanation`，`maxLines: null`） |
| §10 | 專案未就緒 | 說明（依原因四選一）+ 前往 Domain 視圖 | `EmptyState.page`（`state-history-project-unready`；訊息依原因四選一，沿用 §2–§6 同名列的 `projectUnreadyReason*`；動作 `AppButton.primary` 前往 Domain 視圖 `action-history-goto-domain`，既有 `gotoDomainViewAction`） |
| §10 | 讀取中 | 「正在讀取 git 歷史」+ 已處理的 commit 數 + 取消；篩選列不渲染 | `LoadingState.skeleton`（版位 `rows`，`state-history-loading`；訊息 `historyLoading`、計數 `historyLoadingProcessedCount`（indeterminate，不顯示百分比，SPEC-003 §2.6）、取消 `AppButton.secondary`（`action-history-cancel`，既有 `cancelLoadingAction`，取消中 `cancelInProgressAction`）） |
| §10 | 正常 | 篩選列 + 期間描述 + 事件數 + 事件清單 + 重新整理 | `PageColumn`[`SplitRow.header`[`PageTitle`（`navHistory`）, `ButtonRow`[`AppButton.secondary` 重新整理 `action-history-refresh`，既有 `refreshAction`]], `Panel.default`（`panelKey` `state-history-normal`）[`leading`: `BadgeRow`[`Badge.category`（tone `warning`，`badge-history-shallow-clone`，`historyShallowCloneBadge`）]（僅結果帶淺層資訊時渲染，置於篩選列之上）, `Toolbar.history`[`SegmentedControl`（三段，`option-history-period-default`／`-recent30`／`-all`）, `AppCheckbox`（`action-history-include-ticket-created`，`historyIncludeTicketCreatedLabel`）], `AppText.body`（`historyPeriodSummary`：期間描述 + 事件數）；`fill`: `DataTable.virtual`（`scroll-history-events`）[`TableRow.header`（七欄欄首，見 4.35 `historyEvent`）, `TableRow.historyEvent` × N]]]；降級徽章 `badge-history-degraded-schema` 與推定版本徽章依 4.27 殼層通則 |
| §10 | 期間內無事件 | 篩選列 + 期間描述 + 空狀態「此期間沒有關係變動」+ 顯示全部歷史；尚無 commit 變體只有訊息與重新整理 | 頁首同「正常」列；`Panel.default`（`panelKey` `state-history-empty`）[`leading` 同「正常」列；`fill`: `EmptyState.section`（`panel-history-empty`，訊息 `historyEmptyMessage`；動作 `ButtonRow`[`AppButton.primary` 顯示全部歷史 `action-history-show-all`，`historyShowAllAction`]）]。「尚無 commit」變體（SPEC-008 FR-08 規則 4）：`leading` 全不渲染（無篩選列、無期間描述；無 commit 即無淺層邊界），`EmptyState.section` 訊息改為 `historyNoCommitsMessage` 且無動作，出口為頁首重新整理（SPEC-001 §10〈「尚無 commit」變體〉） |
| §10 | 非 git 專案 | 「此專案不是 git repo，無法讀取變更記錄」+ 重新檢查 | `EmptyState.page`（`state-history-not-git`，訊息 `historyNotGitMessage`；動作 `AppButton.primary` 重新檢查 `action-history-recheck`，`historyRecheckAction`） |
| §10 | 找不到 git | 「找不到 git 指令」+ 安裝或 PATH 說明 + 重新檢查 | `EmptyState.page`（`state-history-git-missing`，訊息 `historyGitMissingMessage`、說明 `historyGitMissingExplanation`；動作 `AppButton.primary` 重新檢查 `action-history-recheck`，`historyRecheckAction`） |
| §10 | 讀取失敗 | 「讀取 git 歷史失敗」+ 原因摘要 + 重試 | `EmptyState.page`（`state-history-load-failed`，訊息 `historyLoadFailedMessage`、說明 `historyLoadFailedDetail`（代入 SPEC-008 FR-08 規則 5 的 stderr 摘要原文，資料值不翻譯）；動作 `AppButton.primary` 重試 `action-history-retry`，`retryAction`）；不用 `BlockedState`：讀取失敗不阻擋專案的其他畫面，出口是同畫面重試，不需要切換專案出口（4.21〈何時不用〉的例外說明） |
| §10 | 已取消 | 「已取消讀取」+ 重新讀取 | `EmptyState.page`（`state-history-cancelled`，訊息 `historyCancelledMessage`；動作 `AppButton.primary` 重新讀取 `action-history-reload`，`historyReloadAction`） |
| §11 | 快捷鍵清單 | 面板標題 + 十列快捷鍵（按鍵、作用、作用情境）+ 關閉鈕 | `Panel.scrollable`（`panelKey` `state-shortcuts-list`，scrollKey `scroll-shortcuts-list`）[`AppText.subtitle`（`keyboardShortcutsTitle`）, `ListRow.shortcut` × 10（依 SPEC-001 §11〈清單內容〉列序；按鍵字面為資料值不進 i18n，作用 `shortcut*Action`、情境 `shortcutContext*`）]，`footer`: `AppButton.text`（關閉，`action-shortcuts-close`，沿用偏好設定面板的 `cellDetailCloseAction`，`autofocus`；固定於面板底部不隨清單捲動，4.30〈固定底部 slot〉）；面板的呈現宿主與 §9 相同（覆蓋於主視窗之上） |
| §12 | 無寫入 | 面板標題「寫入清單」+ 說明 + 關閉鈕 | `Panel.scrollable`（`panelKey` `state-writeLog-empty`，scrollKey `scroll-writeLog-list`）[`AppText.subtitle`（`writeLogTitle`）, `AppText.multiLine`（`writeLogEmptyMessage`，`maxLines: null`）]，`footer`: `AppButton.text`（關閉，`action-writeLog-close`，沿用 `cellDetailCloseAction`，`autofocus`；4.30〈固定底部 slot〉）；面板的呈現宿主與尺寸同 §9（`LayoutSize.overlayWidth`）（1.143，`1.0.0-W3-553.3.1`） |
| §12 | 寫入清單 | 面板標題 + 列表（新的在上），每列：路徑、欄位名、寫入結果、驗證狀態、取回說明 + 關閉鈕 | 同上，`panelKey` `state-writeLog-list`：[`AppText.subtitle`（`writeLogTitle`）, `WriteLogRow` × N（4.51，`card-writeLog-row-<index>`，`<index>` 為發出順序，依新到舊排列）]，`footer` 同上；面板開啟期間新列加在最上方、捲動位置不變（SPEC-003 §3.12〈列的更新〉）（1.143） |

§10 七態皆渲染頁首 `SplitRow.header`[`PageTitle`（`navHistory`）]；右格 `ButtonRow`（重新整理）只在正常與期間內無事件兩列渲染，其餘狀態的出口在內容區（SPEC-003 §3.9〈導航跳轉與退出〉）。

`SplitRow.header` 與 `SegmentedControl` 僅渲染於正常 · 矩陣、已選格、正常 · 泳道、泳道 · 尚未選定 UC、泳道 · 投影準備中、泳道 · flow 未結構化、圖不可用七列；其餘 §1 狀態（未選專案、載入中、空圖、三個阻擋狀態）不渲染頁首模式切換（SPEC-003 §2.2 形態 a，`0.1.0-W3-335.38` S-15）。

**〈UC 選擇入口〉**（UC Flow 視圖三態共用；出處 UC-03 主要成功場景步驟 1「使用者自 UC Flow 視圖選擇一條 UC」、SPEC-001 §2、SPEC-003 §3.2「選擇 UC」列）：

| 項目 | 定義 |
|------|------|
| 排位 | `TwoColumnLayout` 右欄，`Panel.scrollable`（scrollKey `scroll-ucFlow-uc-list`）[`Section.static`[`AppText.caption`（`ucSelectorTitle`）, `ListRow.option` × N]]；右欄寬 `LayoutSize.detailPaneWidth`（與 §1、§6 的右欄同一容器同一寬） |
| 選件 | `ListRow.option`（4.40）：主文字為 UC ID + 標題；目前選定 UC 呈 `selected`；testKey `action-ucFlow-select-uc-<ucId>` |
| 渲染範圍 | `state-ucFlow-uc-unset`、`state-ucFlow-unstructured`、`state-ucFlow-normal` 三態皆渲染（SPEC-003 §3.2）；`state-ucFlow-empty` 不渲染 |
| 項目數 | 專案內全部 UC 節點，無上限，依 UC ID 排序（提案）；超出右欄高時垂直捲動 |
| 為何是常駐清單而非下拉 | SPEC-003 §3.2 的錨點 `action-ucFlow-select-uc-<ucId>` 為每個 UC 一個、可在上述三態直接點擊；下拉選單的項目在 SPEC-003 §2.9 的錨點類別是 `option-<screen>-<kind>-<value>`，且選單收合時項目不在元件樹。採下拉須改上游錨點，故不採 |
| 與 §1 右欄的一致性 | 右欄在 UC Flow 視圖承載「換一條 UC」，在 §1 承載「選中格詳情」、在 §6 承載「關聯節點」，三者皆為主欄內容的導覽輔助，雙欄各自捲動（SPEC-003 FR-10） |
| 上游缺口 | 已補：SPEC-003 §1.1 捲動處清單新增 `scroll-ucFlow-uc-list`（`0.1.0-W3-335.16` SR-5 落地），本檔採用該錨點（見上「排位」列） |

### 3.7 核定記錄（2026-09-02）

PM 核定 §3.3 二十項與 §1、§3.5、§3.6 的待核定項；標「用戶簽核」者由專案擁有者裁示。第 4-5 章依本表填寫；§3.1 總表與本表核定欄不一致處以本表為準，由 044.2 回填總表；理由欄記錄核定當時（2026-09-02）的行為與計數，現行值以 §3.1 與 SPEC-001／SPEC-003 條文為準，不隨上游改版回改。第 4 章契約欄位依方法論〈元件契約欄位表〉：使用者補充「操作機制」（每形態的操作動作與精度，本專案單一形態為指標 + 鍵盤，仍須逐元件填一列）與「無障礙」（朗讀標籤、狀態播報、非視覺替代、焦點與鍵盤操作路徑；不得填不適用）為必填。
<!-- 本檔不以數字描述欄位表大小（DOC-GPD-003）；欄位集合以方法論〈元件契約欄位表〉為準 -->

| # | 項目 | 核定 | 理由 |
|---|------|------|------|
| 1 | §1 支援的形態 | 單一形態：桌機（指標 + 鍵盤）（用戶簽核）；同形態內尺寸差異由排列不變式承載，不設 RWD 斷點 | 形態依操作方式界定，本專案唯一操作方式是指標加鍵盤；使用者另裁示：形態不以顯示空間評估，多形態專案須依各形態操作方式各自設計容器 |
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
| 19 | §2 傳值 + callback 與資料視圖容器例外、最小重繪邊界、高頻檢核 | 核定 | 與 dart-provider-architecture skill 一致。2026-11-06 `0.6.0-W1-193` 裁決（D 案）：資料視圖容器例外刪除，容器一律傳值 + callback，畫面層以 `select` 訂閱；捲動 offset 由頁面層持有的 `ScrollController` 傳入容器（1.127） |
| 20 | §1 第三種測試尺寸 | 不加入 | 無決策來源的數值不發明；拉伸上限由最大尺寸契約承載 |
| 21 | 佈局尺寸 token（側欄寬、列高、右欄寬、浮層寬、圖示尺寸階等） | 建 token 前置票，設為 044.2 blockedBy | 尺寸契約與排列不變式公式需要具名值；右欄寬兩值由該票收斂為一 |
| 22 | `Motion` token | 由既有 pending 票承接，設為 044.2 blockedBy | 互動反應與動畫子節需引用 |
| 23 | `two_dimensional_scrollables` 未在 pubspec | 已由 W1-038 加入（^0.5.4） | 依賴屬實作票 acceptance |
| 24 | `LayoutSize.matrixColumnWidth` 提案值 122 | 核定 | 畫布為 `repeat(5,1fr)` 無固定值；122 由 Main 版面尺寸鏈（矩陣首欄 + 小計欄 + 五個 UC 欄 = 主區寬）反推，與既有 token 加總一致；`two_dimensional_scrollables` 需固定欄寬 |
| 25 | `textSecondary` 對比未達 WCAG AA（`0.1.0-W1-058`） | 方案 C（使用者經 WRAP 重評裁決）：`textSecondary` 調深 `#8A9694` → `#6A7674`（對 `surfaceBase` 4.71:1）；新增 `textDisabled` = `#8A9694` 供停用態與純裝飾箭頭圖示；`surfaceSegmentTrack` 調淺 `#DCE4E2` → `#DEE6E4`（對 `textPrimary` 4.56:1）；三案共通項：`Badge` 刪 `secondary` tone、帶色表面上的次要文字改 `textPrimary`。token 由 `0.1.0-W1-059` 落地，本檔由 `0.1.0-W1-060` 回填 | AA 一般字級是硬門檻，11 個文字條目全為 10～12px 無大字級可套用；原 token 兼任停用色，僅調深會使停用態與作用中次要文字同色，故以新 token 分離兩種語意，並讓 SC 1.4.3 非作用中元件豁免有明確 token 對應；畫布偏離面積最小（116 處文字調深，約 10 處箭頭／停用維持原色）。失敗警訊：實機主次層級不可辨，回退為主色再調深 |

**出處補記（`0.1.0-W3-335.16`，依 `0.1.0-W3-335.14` 稽核的無上游出處清單）**：上表 11 項的理由欄只引用本檔自身或無外部引用。下表逐項補出處；上游無對應條文者標「撰寫期決策」，並指出與其相接、已回寫的 SPEC-001／SPEC-003 章節，使讀者可驗證決策是否仍與上游一致。**本補記不改變任何核定結論。**

| # | 出處類型 | 上游出處或相接章節 |
|---|---------|------------------|
| 4 | 撰寫期決策（`component-contract-design` skill 步驟 3「先假設能併」） | 逐項相接：第 1 項 SPEC-003 §2.7 與 SPEC-001 FR-03／FR-07；第 4 項 SPEC-003 §3.4（未載入不顯示預估耗時）與 SPEC-001 §4；第 5 項 SPEC-003 §2.5 取消契約；第 6、7 項 SPEC-001 FR-05 與 SPEC-003 §3.3、§3.4；第 17 項以後為元件庫內部結構，SPEC-001／003 無相接條文 |
| 6 | 撰寫期決策（方法論〈命名與通用元件判準〉） | 四件的行為差異各有上游：`MatrixCell` 點格 SPEC-003 §3.1；`ListRow.tree` 點節點 SPEC-003 §3.3；`ListRow.item` 點破洞項 SPEC-003 §3.5（v1.27 起依指向節點型別跳轉，不再一律外開，行為差異更大，拆分結論不受影響）；`SwimlaneNode` 不可點 SPEC-001 設計約束 |
| 8 | 上游出處（事後補齊） | SPEC-003 §2.2 三層回饋（結果通知＝SnackBar）、§2.11 元件庫對應 SnackBar 列、§2.13 暫態提示載體判準；停留時間 token 見 SPEC-003 §2.1 |
| 10 | 撰寫期決策（skill〈Troubleshooting〉十個門檻） | 元件庫內部結構，SPEC-001／003 無相接條文。註：本項核定文字的「13」與 §3.1 定案數段的「12」不一致，以 §3.1 實列為準 |
| 11 | 撰寫期決策（畫布兩值衝突，形狀屬 token） | SPEC-001 §2 正常（v1.7 回寫步驟表首欄為步驟序號）；SPEC-001〈設計約束〉「不描述視覺細節」使形狀留在本檔 |
| 12 | 撰寫期決策（畫布兩值衝突） | 視覺值，SPEC-001〈設計約束〉明示不承載；SPEC-001 §1 註記「本表刻意不定的視覺值，留給 SPEC-004」 |
| 13 | 撰寫期決策（變體無語意差異不設） | 同上；SPEC-001 §6 正常只定「全頁內容 + 關聯右欄」 |
| 14 | 撰寫期決策（排位）；可點性有上游出處 | 可點性：SPEC-001 §4 含損壞「跳轉破洞報告」、SPEC-003 §3.4 `badge-tickets-corrupted`；排位（`Toolbar` 右側）無上游條文 |
| 17 | 上游出處（事後補齊） | SPEC-003 §2.4「返回（consume）」：`action-<screen>-back` 統一置於 `SplitRow.header` 右側 `ButtonRow`，由頁面框架單一渲染；SPEC-001 §6 可用操作 |
| 18 | 撰寫期決策（排位比照第 17 項） | SPEC-003 §2.4 只定返回鍵位置，未定重新掃描；本項取同一頁面級動作區。動作本身出處為 SPEC-001 §5 無破洞／有破洞可用操作「重新掃描」、SPEC-003 §3.5 `action-gaps-rescan`；涵蓋無破洞、有破洞與無法判定破洞三狀態（無法判定破洞三種原因皆顯示，SPEC-003 狀態轉換表 `action-gaps-rescan` → `state-gaps-scanning`，`0.5.0-W1-513.1.1`），無破洞的 `EmptyState.page` 因此不帶動作（`0.1.0-W3-335.37` R10） |
| 20 | 撰寫期決策（無決策來源的數值不發明） | 相接上游為 CLAUDE.md §6 尺寸系統與防跑版主力；SPEC-001／003 無相接條文 |

---

## 4. 逐元件規格

> 每個元件依下列結構定義。目標：實作者不需猜測任何行為。方法論〈元件契約欄位表〉每一欄位對應的子節（對應表見下）缺任一即契約不完整，
> 元件票不得驗收、畫面票不得引用（方法論〈元件契約判準〉）。容器元件另填第 5 章的排列不變式。
>
> **本章狀態：已填（`0.1.0-W1-044.2`，2026-09-02）。** 元件 26 條（4.1–4.26）、容器 16 條（4.27–4.42）；容器另於第 5 章填子件契約與排列不變式。
> 每條目的子節與方法論〈元件契約欄位表〉的對應如下表；design token 為本檔額外承載的實作契約，不對應方法論欄位。
> 跨元件相同的值集中於 §4.0，條目內以「依 §4.0.x」引用，引用即視為該欄已填。
>
> | 方法論欄位 | 本檔子節 |
> |-----------|---------|
> | 語意與內容角色 | 條目標頭（用途／內容角色／何時不用／出現畫面／層級） |
> | 變體 | 變體 |
> | 狀態集 | 狀態矩陣（含來源與同步策略兩欄） |
> | 操作機制 | 操作機制 |
> | 尺寸契約 | 尺寸契約 |
> | 內容政策 | 內容政策 |
> | slot 契約 | slot 契約 + i18n |
> | 組合規則 | 組合規則 |
> | 無障礙 | 無障礙 |
> | 回饋契約 | 回饋契約 |
> | 測試契約 | 測試點（widget test） |
> | 反例 | 反例 |
> | —（本檔額外） | 使用 design token |

### 4.0 本章通用約定

#### 4.0.1 互動瞬態（hover / pressed / focused）與 disabled 的視覺

| 瞬態 | 值 | 來源 |
|------|-----|------|
| pressed | Material `InkWell` / `ButtonStyleButton` 內建 pressed 態，不自繪 | SPEC-003 §2.2（抄錄） |
| hover | 同上，Material `InkWell` 內建 hover overlay（`hoverColor` 取 `ThemeData` 預設），不自繪；畫布無 hover 樣式 | 提案：延伸 SPEC-003 §2.2「不自繪」慣例 |
| focused | 焦點環為元件祖先鏈上 `DecoratedBox` 的 `BoxDecoration.border`：取得焦點時為 `AppColors.accent` 外框、圓角同元件，焦點移走後同位置無外框或外框透明；斷言採兩態對照形，依 SPEC-003 §2.10〈焦點裝飾（斷言方式，對照形）〉，本表不重述 | 斷言形式引用 SPEC-003 §2.10；顏色為提案 |
| disabled | `enabled` 為 `false`；文字與圖示改 `AppColors.textDisabled`（停用態專用 token，§3.7 第 25 項；SC 1.4.3 對非作用中元件豁免），無 hover overlay；同列以常駐文字（非 tooltip，`AppText.caption`，`textSecondary`）說明原因（SPEC-003 §2.2、FR-06） | SPEC-003（抄錄）；token 名依 `0.1.0-W1-058` 方案 C |

狀態矩陣中 hover / pressed / focused 三列為「互動瞬態」，不改變元件語意狀態，來源欄恆為「互動瞬態」、同步策略恆為「本地即時」；此三列的退出路徑恆為「指標離開／放開／焦點移走」。各條目依範本拆為 hover（僅指標形態）／pressed／focused 三列，「顯示」欄以「依 §4.0.1」代之不重述視覺。例外：互動瞬態由內嵌 `AppButton`（4.21–4.26）或子件（容器條目）承載的元件不拆列，改於狀態矩陣下以一句註明由何者承載。

本欄的用途是直接查表判定哪些狀態須存 provider（§2 頁面狀態保留）。「來源」欄的值只有三種：「互動瞬態」（輸入裝置驅動的瞬態，或元件內部 overlay 開合（含命令式 show／dismiss 開合）等不存於 provider 的本地狀態）、「資料態：{provider 名，或 §2 頁面狀態保留允許的頁面 `State`（寫明類別與欄位）}」（provider 或頁面 `State` 驅動，寫明 provider 與檔案路徑；provider 尚未建立者標由對應畫面票補填（以畫面名為鍵））、「—」（建構即渲染的預設列：值由呼叫端傳值、元件不 watch，括號內說明傳值來源）。default／enabled 這類建構即進入的列填「—」，不填「互動瞬態」（該詞保留給輸入裝置驅動的瞬態與元件內部本地狀態）。混填會使本欄失去上述直接查表功能，讀者須回讀退出路徑才能判定。

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
| `surfaceBase` / `accent` | 5.84:1 | 通過 | 選取態、`primary` 按鈕 |
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
| 一字元 | 該文字 slot 字級 token 的 1em（`AppFontSize.*` 值本身，不實測字形；CJK 全形字寬約等於 1em）；最小尺寸列的「一字元」皆依此定義，多字級元件取決定最小寬之文字 slot 的字級（`0.5.0-W1-071` 裁決） |
| 邊框線寬 | Flutter `Divider.thickness` / `BorderSide.width` 預設值（1 邏輯像素），不另建 token（既有 `lib/assembly/shell.dart` 慣例；提案） |
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

測試形態為 widget test（`flutter test`），不做 golden；理由：golden 對 macOS 字型渲染敏感，CI 與本機差異會使紅燈失去診斷價值。每個元件一支測試檔，依條目「測試點」逐項斷言；視窗尺寸以 `tester.view.physicalSize` 設為 `kMinWindowSize` 與 `kDesignSize` 各跑一次。測試基座（尺寸切換、`TestCopy`、`ProviderScope` 包裝）由 `0.1.0-W1-034` 建立。

#### 4.0.6 i18n 標記約定與新 key 總表

下表為本檔宣告的新 key（原標「新 key」，已由 `0.1.0-W1-056` 建於 `lib/l10n/app_zh.arb`、`app_en.arb` 並重新產生 `app_localizations*.dart`，狀態改為已建）。條目 i18n 表中不再逐一標記「新 key」，既有 key 直接寫 key 名。

**規格先行標記**：規劃期先改本表、實作尚未跟上的列，在該列最後一格（使用處／備註）加行內標記 `（規格先行：<落地票號>）`，全形括號與冒號，落地票號為負責讓實作追上該列的票（例 `1.1.0-W3-656` 或子票 `1.0.0-W3-553.6`）。讀本表的契約測試（`spec004_key_table_contract_test`、`gap_report_projection_test`、`gap_report_declaration_line_test`、`domain_view_load_failed_test`，以及讀 SPEC-003 章節標題的 `app_snack_bar_source_contract_test`）對帶標記的列跳過與 ARB 的比對；以正規式 `（規格先行：(\d+\.\d+\.\d+-W\d+-\d+(?:\.\d+)*)）` 辨識（`test/helpers/spec_first_marker.dart`）。標記不得置於 zh／en 文案格。**移除時點**：落地票讓實作與該列一致的同一批次，必須同批移除標記；標記與實作並存時契約測試判紅並提示移除。新增的規格先行差集一律用標記，不再往測試內的 `pendingAdditionExemptions` 清單加成員（既有成員隨 1.0 元件票逐張移除）。

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
| `laneNodeActive` / `laneNodeInactive` | 作用中 / 非作用中 | Active / Inactive | — | 4.16（朗讀）、§1 畫面正常 · 泳道圖例（`BadgeRow.legend`，沿用既有 key 不新增，`0.1.0-W3-335.47` D6） |
| `stepNumberA11yLabel` | 步驟 {number} | Step {number} | number | 4.17 |
| `gapMarkerLabel` | 缺口 | Gap | — | 4.6（可見文字） |
| `damagedEdgeMarkerLabel` / `damagedDetailMarkerLabel` | 邊損壞 / 詳情損壞 | Edge damaged / Detail damaged | — | 4.6（朗讀） |
| `relationItemA11yLabel` | 關聯節點 {id} | Related node {id} | id | 4.19 |
| `relationProposedLabel` | 暫定 | Proposed | — | 4.19（`isProposed=true` 的尾端 `Badge.category`；新 key，`0.5.0-W1-103.2`；文案依 `0.5.0-W1-103.1` 用戶裁決 I2） |
| `relationItemProposedA11yLabel` | 關聯節點 {id}，暫定邊，形狀可能變動 | Related node {id}, proposed edge, shape may change | id | 4.19（新 key，`0.5.0-W1-103.2`；朗讀文案依 `0.5.0-W1-103.1` PM 處置確認） |
| `pathDeclarationIncompleteLine` | 路徑宣告不完整：{detail}（影響 {count} 條路徑） | Path declarations incomplete: {detail} ({count} paths affected) | detail, count | SPEC-001 §5 專案層級宣告狀態一行（`AppText`；新 key，`0.5.0-W1-096.9` PM 處置） |
| `pathDeclarationBundlesPartial` | 已宣告 {declared}／{total} 個 domain | {declared} of {total} domains declared | declared, total | 同上，`{detail}` 片段；與 `pathDeclarationNonDomainMissing` 並存時以「、」／", " 連接 |
| `pathDeclarationBundlesMalformed` | {count} 個 domain 的路徑宣告格式錯誤 | path declarations of {count} domains are malformed | count | SPEC-001 §5 宣告狀態行 `{detail}` 片段；有 bundle 的 `path_patterns` 格式錯誤（G1 值不是清單、G2 含非字串元素）時出現，接在 bundle 側片段之後，以「、」／", " 連接（`0.6.0-W1-075` N1=C′，`0.6.0-W1-075.1` 提案，`0.6.0-W1-075.2` 落地） |
| `pathDeclarationNonDomainMissing` | 缺非 domain 路徑清單 | non-domain path list missing | — | 同上，`{detail}` 片段 |
| `pathDeclarationNoneLine` | 本專案未宣告路徑 | This project declares no paths | — | SPEC-001 §5 兩側皆未宣告時（不顯示路徑數） |
| `pathDeclarationNonDomainMalformed` | 非 domain 路徑清單格式錯誤 | non-domain path list is malformed | — | 同 `pathDeclarationNonDomainMissing` 的 `{detail}` 片段，清單檔存在但格式錯誤時取代「缺」（UC-02 NC-1 (ii) II-a）。key 與文案已定（`0.5.0-W1-096.7` PM 處置識別名、`0.5.0-W1-114.1` NC-g），ARB 已建（`0.5.0-W1-119.2`） |
| `pathDeclarationNoBundles` | 尚未宣告任何 domain | no domains declared | — | SPEC-001 §5 宣告狀態行 `{detail}` 的 bundle 側片段，bundle 總數為 0（專案沒有任何 DomainBundle）時取代 `pathDeclarationBundlesPartial`，不顯示「0／0」；與非 domain 側片段並存時以「、」／", " 連接（用戶裁決 2026-10-20，`0.5.0-W1-443`） |
| `gapNonDomainPathsNonStringElements` | 清單內 {count} 個非字串元素 | {count, plural, =1{1 non-string element in the list} other{{count} non-string elements in the list}} | count | SPEC-001 §5 破洞項目，`nonDomainPathsMalformed` 子原因 `elementNotString` 的項目說明；`count` 取破洞的 `nonStringElementCount`（SPEC-006 FR-08）。新 key，依 `0.5.0-W1-114.4` 用戶裁決第五批 NC-7（G1），識別名為 PM 決定；en 文案經 PM 確認（`0.5.0-W1-114.5` PM 處置） |
| `gapNonDomainPathsYamlInvalid` | 清單檔的 YAML 無法解析 | The list file's YAML could not be parsed | — | SPEC-001 §5 破洞項目，`nonDomainPathsMalformed` 子原因 `yamlInvalid` 的項目說明。key 與文案為 PM 決定（`0.5.0-W1-114.5` PM 處置 NC） |
| `gapNonDomainPathsKeyMissing` | 清單檔缺少 {key} 鍵 | The list file is missing the {key} key | key | 同上，子原因 `keyMissing`；`key` 取型別表 `non_domain_paths_key`（缺欄或空白時取內建表值，SPEC-006 FR-10 規則 1）。key 與文案為 PM 決定 |
| `gapNonDomainPathsNotList` | 清單檔中 {key} 的值不是清單 | The value of {key} in the list file is not a list | key | 同上，子原因 `notList`；`key` 取值同上。key 與文案為 PM 決定 |
| `swimlaneFlowParseFailedHint` | 此 UC 有 flow 區塊解析失敗，泳道只呈現第一個合法區塊 | Some flow blocks in this UC failed to parse; the lanes show the first valid block only | — | §3.6 §1 正常 · 泳道（`AppText.multiLine`，`maxLines: 2`、`secondary: true`；SPEC-001 §1〈flow 區塊解析失敗的泳道呈現〉(a)）。key 與文案已定（`0.5.0-W1-114.1` NC-g） |
| `flowParseFailedMessage` | 此 UC 的 flow 區塊解析失敗，請開啟來源檔修正 | This UC's flow block failed to parse. Open the source file to fix it. | — | §3.6 §1 泳道 · flow 未結構化（`EmptyState.section` 訊息；SPEC-001 §1〈flow 區塊解析失敗的泳道呈現〉(b)）；§2 UC Flow 視圖 flow 區塊皆解析失敗時同用此 key（`0.5.0-W1-114.1` NC-f）。key 與文案已定（NC-g） |
| `currentProjectA11yLabel` | 目前專案 | Current project | — | 4.9 |
| `projectSummaryLabel` | {nodes} 節點 · {tickets} 票 | {nodes} nodes · {tickets} tickets | nodes, tickets | 4.9 |
| `healthBadgeA11yLabel` | {count} 個問題 | 單複數：1 issue／{count} issues | count | 4.5（health）；計數 0 時徽章不渲染（SPEC-001 §7） |
| `switcherTitle` | 切換專案 | Switch project | — | 4.42 |
| `schemaAppVersionLabel` / `schemaProjectVersionLabel` | App 支援版本 / 專案版本 | Supported schema version / Project version | — | 原 4.23 面板小標；1.45 起面板改放 App 已知版本範圍（見〈1.45 新增〉`schemaKnownRangeLabel`／`schemaKnownRangeValue`），本二 key 不再有使用處，ARB 實檔已移除（1.56 核對：`app_zh.arb`／`app_en.arb` 皆無此二鍵） |
| `treeDepthA11yLabel` | 第 {depth} 層 | Level {depth} | depth | 4.39 |
| `openExternallyA11yLabel` | 在外部開啟 | Opens externally | — | 4.40（`item`） |
| `loadingSkeletonA11yLabel` | 載入中 | Loading | — | 4.24 |
| `cellDetailPrompt` | 點選一格檢視詳情 | Select a cell to view details | — | §1 畫面（4.21 `section` 呼叫端；SPEC-003 §3.1） |
| `cellDetailNotInvolved` | 此 domain 不參與此 UC | This domain is not involved in this UC | — | §1 畫面（SPEC-003 §3.1） |
| `cellDetailCloseAction` | 關閉 | Close | — | §1 畫面（4.4 `text` 呼叫端） |
| `cellDetailViewInSwimlaneAction` | 在泳道中檢視 | View in swimlane | — | §1 畫面（4.4 `secondary` 呼叫端） |
| `modeMatrixLabel` / `modeSwimlaneLabel` / `modeListLabel` / `modeTopicLabel` | 矩陣 / 泳道 / 列表 / 主題 | Matrix / Swimlane / List / Topic | — | §1、§4 畫面（4.10 可見標籤；朗讀用既有 `*SwitchTo*Action`） |
| `ticketsSummaryLabel` | 顯示 {from}–{to} / 共 {total} | Showing {from}–{to} of {total} | from, to, total | §4 畫面（4.29 `footer` 呼叫端） |
| `ticketsVirtualScrollNote` | 虛擬捲動，不分頁 | Virtual scrolling, no pagination | — | §4 畫面 |
| `ticketsNoTopicFilesNotice` | 此專案無主題檔 | This project has no topic files | — | §4 畫面（主題模式頂部說明列，1.117 加入；`AppText.caption`） |
| `topicSectionSummary` | ({count} tasks, 最高優先級={priority}) | ({count} tasks, top priority={priority}) | count, priority | §4 畫面（4.40 `sectionHeader` 呼叫端） |
| `gapSectionCount` | {count} 項 | {count} items | count | §5 畫面（4.40 `sectionHeader` 呼叫端） |
| `viewGapsAction` | 檢視 | View | — | 4.26 `withAction`（SPEC-003 §2.2 系統層通知 `denied` fallback 動作，SPEC-003 1.9 新增；ARB 實檔由 `0.1.0-W3-064` 加入） |

**1.35 新增（`0.1.0-W3-335.16`，對齊 SPEC-001 v1.9／SPEC-003 v1.27；ARB 已建，zh 值為本檔提案文案，M1–M5 適用者依 §4.0.12）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `ucSelectorTitle` | 選擇 UC | Select a UC | — | §2 畫面〈UC 選擇入口〉（4.41 `static` header） |
| `ucUnsetPrompt` | 選擇一條 UC 以檢視 flow | Select a UC to view its flow | — | §2 尚未選定 UC（4.21 `section` 呼叫端；SPEC-001 §2） |
| `swimlaneUcUnsetPrompt` | 尚未選定 UC：請在矩陣點選一格，或至 UC Flow 視圖選擇一條 UC | No UC selected: select a cell in the matrix, or choose a UC in UC Flow | — | §1 泳道 · 尚未選定 UC（4.21 `section` 呼叫端；SPEC-001 §1 註記「提示指向兩處設定入口」） |
| `swimlaneProjectionPendingPrompt` | 泳道投影準備中：掃描完成後即顯示此 UC 的步驟 | Preparing swimlane: this UC's steps appear when the scan completes | — | §1 泳道 · 投影準備中（4.21 `section` 呼叫端；SPEC-001 v1.55 §1，`0.5.0-W1-205.1` 新增，zh／en 為提案文案，ARB 由 `0.5.0-W1-205.2` 建立） |
| `columnEvent` / `columnEmitter` / `columnConsumer` | 事件 / 發出 / 消費 | Event / Emitted by / Consumed by | — | §2 事件流小表（4.35 `header` / `eventFlow`；SPEC-001 §2〈事件流小表〉欄位） |
| `eventFlowStepDomain` | {step} · {domain} | {step} · {domain} | step, domain | 4.35 `eventFlow` 發出／消費格（多個以「、」串接） |
| `eventOutsideUc` | 本 UC 外（{domains}） | Outside this UC ({domains}) | domains | 4.35 `eventFlow`（SPEC-003 §3.2「本 UC 外」列；`domains` 為空時仍顯示括號內空值，提案） |
| `orphanEventMarkerLabel` | 孤立事件 | Orphan event | — | 4.35 `eventFlow` 標記格朗讀 |
| `columnBlockedBy` | blockedBy | blockedBy | — | §4 畫面（4.35 `ticket`；欄名沿用欄位字面，SPEC-001 §4） |
| `traceabilityNoDownstream` | （尚無 {layer}） | (No {layer} yet) | layer | §3 缺口列主文字（4.40 `tree`；§3.2 TraceA 畫布） |
| `sourceChainTitle` | 來源鏈 | Source chain | — | §6 正常（選定節點為 Ticket）來源鏈區塊小標（4.41 `Section.static`，`panel-nodeDetail-source-chain`；新 key） |
| `sourceChainNoUpstream` | （缺上游 {layer}） | (Missing upstream {layer}) | layer | §6 來源鏈缺上游列主文字（4.39 `sourceChain`、4.40 `tree`；`layer` 代入缺的那一層型別名 UC／SPEC／PROP；新 key）。不沿用 `traceabilityNoDownstream`：該 key 指缺下游，方向相反 |
| `ticketsFiltersClearedSnackbarMessage` | 已清除搜尋與篩選以顯示目標 ticket | Search and filters cleared to show the target ticket | — | 4.26 `withAction`（SPEC-003 §3.4〈帶目標跳入〉） |
| `undoAction` | 復原 | Undo | — | 4.26 `withAction` 動作（同上） |

blockedBy 值為空時的「—」為字面符號，不經 i18n。

**1.36 新增（`0.1.0-W3-335.37` R9，`0.1.0-W3-335.40` 落地，對齊 SPEC-001 v1.11／SPEC-003 v1.30；
ARB 已建，zh 值為本檔提案文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `projectUnreadyReasonNotSelected`（原規格名 `projectUnreadyUnsetMessage`，1.56 改用 ARB 名） | 尚未選擇專案 | No project selected yet | — | §2–§6「專案未就緒」（4.21 `page` 呼叫端；Domain 視圖為未選專案時） |
| `projectUnreadyReasonLoading`（原規格名 `projectUnreadyLoadingMessage`，1.56 改用 ARB 名） | 圖譜載入中 | Graph loading | — | §2–§6「專案未就緒」（4.21 `page` 呼叫端；Domain 視圖為載入中時）。文案取 ARB 現值：SPEC-001「專案未就緒」列只寫原因「載入中」，未定字面，原規格「專案載入中」與 ARB「圖譜載入中」皆屬展開，依 ARB 現值 |
| `projectUnreadyReasonIncompatible`（原規格名 `projectUnreadyBlockedMessage`，1.56 改用 ARB 名） | 此專案不適用本 App | This project is not usable with this app | — | §2–§6「專案未就緒」（4.21 `page` 呼叫端；Domain 視圖為三個阻擋狀態之一時，訊息不重述阻擋原因細節——細節僅在 Domain 視圖本身呈現） |
| `gotoDomainViewAction`（原規格名 `gotoDomainAction`，1.59 隨 `0.3.3-W3-389` 移除舊 ARB key、統一為本 key） | 前往 Domain 視圖 | Go to Domain View | — | 4.21 `page`（`AppButton.primary` 呼叫端，`action-<screen>-goto-domain`），§2–§6「專案未就緒」共用 |

**1.37 新增（`0.1.0-W3-335.37` 附帶，對齊 SPEC-003 §3.1；ARB 已建）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `useBuiltinSchemaAction` | 以 App 內建型別表檢視 | View with the app's built-in schema | — | 4.23 `BlockedState.plain`（`AppButton.secondary` 呼叫端，`action-domain-degraded-view`） |

**1.38 新增（`0.1.0-W3-335.38` S-11／S-13／S-38／S-28／S-34／S-37，對齊 SPEC-003 §3.1／§3.4／§3.3／§3.7；ARB 已建，zh 值為本檔提案文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `ticketsTargetNotFoundMessage` | 找不到該 ticket，可能已被移除 | Ticket not found; it may have been removed | — | 4.26 `AppSnackBar.plain`（Ticket 帶目標跳入目標不在清單，SPEC-003 §3.4〈帶目標跳入〉，S-11） |
| `chooseFolderUnavailableMessage`（既有 key；原提案 `folderPickerUnavailableMessage` 與之語意完全重疊，`0.3.2-W3-368` 裁定沿用既有 key、不另立） | 無法開啟資料夾選取面板，應用程式可能安裝不完整 | Could not open the folder picker; the app may not be installed correctly | — | 4.26 `AppSnackBar.plain`（選擇器無法開啟，SPEC-003 §3.1，S-13／S-38；專案切換浮層內觸發者自 1.88 起改用 `switcherChooseFolderUnavailableReason`，不經 SnackBar，SPEC-003 §3.7）。文案為「結果陳述＋一般語言原因」，符合 §4.0.12 M1（原因非技術細節、非操作指引）；原 ARB 值「請確認應用程式安裝完整後重新啟動」屬操作指引，已依裁決改寫（用戶，2026-09-29，經 e1 以 AUQ，`0.3.3-W3-377` 候選 C）；ARB 實檔由實作票更新 |
| `workspaceUnavailable`（既有 key） | 無法存取先前的資料夾：{reason} | Cannot access the previous folder: {reason} | reason | §1 未選專案說明區的常駐文字（`EmptyState.page` 的 `explanation`，取代 `folderAccessRationale`）：App 啟動且已存路徑還原失敗時降級為 `state-domain-unset` 並顯示，選定資料夾後消失（SPEC-001 §1、SPEC-003 §3.1〈生命週期〉，`0.3.3-W3-378` 用戶裁決 B）；`reason` 取 `WorkspaceUnavailable.reason` |
| `folderUnavailableMessage` | 資料夾無法使用：{reason} | Folder unavailable: {reason} | reason | 4.26 `AppSnackBar.plain`（選定資料夾不可讀或不存在，`reason` 取 `WorkspaceUnavailable.reason`，SPEC-003 §3.1，S-13／S-38；專案切換浮層內觸發者自 1.88 起改用 `switcherFolderUnavailableReason` 或 4.9 `reason`，不經 SnackBar，SPEC-003 §3.7）。與既有 `workspaceUnavailable`（「無法存取先前的資料夾：{reason}」，啟動時還原上次資料夾的情境）語意不同——本 key 的對象是剛在選擇器選定的資料夾，不是「先前的」，`0.3.2-W3-368` 裁定保留新 key |
| `degradedSchemaShortLabel` | 內建型別表 | Built-in schema | — | 4.9 `RecentProjectItem`（`Badge.tag`，`isDegraded` 為 `true` 時，S-34） |
| `probingReason` | 檢查中… | Checking… | — | 4.9 `RecentProjectItem`（disabled 列 `reason`，探測未完成時，S-37） |

**1.41 新增（`0.1.0-W3-335.57`，依 `0.1.0-W3-335.53` WRAP 裁決 E2／E3／E8，對應 SPEC-001 v1.14／SPEC-003 v1.35；ARB 已建，zh 值為本檔提案文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `schemaUnconsumableDegradedExplanation` | 可改用 App 內建型別表（v{builtinVersion}）檢視，B 層邊不渲染 | You can view this with the app's built-in schema (v{builtinVersion}); tier-B edges will not render | builtinVersion | 4.23 `BlockedState.plain`（無可消費的型別表，`explanation` slot，`onDegradedView` 非 null 時，E2） |
| `degradedSchemaBadgeLabel` | 降級型別表（內建 {builtinVersion} / 專案 {projectVersion}） | Degraded schema (builtin {builtinVersion} / project {projectVersion}) | builtinVersion, projectVersion | 4.27 `AppShell`（`badge-<screen>-degraded-schema`，`Badge.tag`，降級旗標生效期間與返回列同一列常駐，E3） |
| `swimlanePanelTitle` | {ucId} {ucTitle} | {ucId} {ucTitle} | ucId, ucTitle | §1 正常 · 泳道、泳道 · flow 未結構化（`AppText.subtitle`，SPEC-001 §1、SPEC-003 §3.1／§2.8，E8） |

**1.121 補登（`0.6.0-W1-152.1`，用戶裁定；ARB 已有、本表原無記載，zh／en 取 ARB 現值）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `eventOutsideUcBare` | 本 UC 外 | Outside this UC | — | 事件流小表「本 UC 外」列，對側為空或無 EVT 節點時使用（SPEC-001 §2〈事件流小表〉） |
| `scanCompleteUndeterminableNotificationBody` | 無法判定破洞，原因請見破洞報告 | Gaps could not be determined. See the gap report for the reason. | — | 掃描完成系統通知內文（無法判定破洞時） |
| `scanCompleteUndeterminableSnackbarMessage` | 掃描結束，無法判定破洞 | Scan finished: gaps could not be determined | — | 掃描完成 `AppSnackBar`（無法判定破洞時） |

畫面票另需的頁面副標等文案由畫面票自行宣告，不列於此。

**1.45 新增（對齊 SPEC-001 v1.19 〈推定版本〉註記與 schema 不相容面板重評；ARB 已建，zh 值為本檔提案文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `schemaKnownRangeLabel` | App 已知版本範圍 | Supported schema version range | — | 4.23 `BlockedState.withDetail` 面板小標（`AppText.caption`），取代 `schemaAppVersionLabel`／`schemaProjectVersionLabel` |
| `schemaKnownRangeValue` | 不高於 {appVersion} | Up to {appVersion} | appVersion | 4.23 `BlockedState.withDetail` 面板值（`AppText.mono`）；`appVersion` 為 App 內建型別表產生版本，與 `message` 代入的同一值 |
| `inferredVersionBadgeLabel` | 版本推定自型別表 (v{inferredVersion}) | Version inferred from schema (v{inferredVersion}) | inferredVersion | 4.27 `AppShell`（`badge-<screen>-inferred-version`，`Badge.tag`，推定版本旗標生效期間與返回列同一列常駐，SPEC-001 §1〈推定版本〉註記） |

**1.46 新增（對齊 SPEC-001 v1.21〈路徑模式取自內建表〉註記與 §5「無法判定破洞」；ARB 已建，zh 值為本檔提案文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `builtinPathPatternBadgeLabel` | 路徑模式取自 App 內建型別表 | Path patterns from built-in schema | — | 4.27 `AppShell`（`badge-gaps-builtin-path-pattern`，`Badge.tag`，只在破洞報告、旗標 `isPathPatternFromBuiltin` 生效期間與返回列同一列常駐） |
| `gapsUndeterminableTitle` | 無法判定破洞 | Gaps cannot be determined | — | §3.6 §5 無法判定破洞列頁首標題 |
| `gapsUndeterminableReasonVersionOutOfRange` | 專案型別表版本不在 App 已知範圍內，且缺少路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出 | The project schema version is outside the range this app knows and lacks path patterns, so node files cannot be identified; parse failures are not listed | — | 同上，原因說明之一 |
| `gapsUndeterminableReasonNoPathPattern` | 專案型別表與 App 內建型別表都沒有路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出 | Neither the project schema nor the built-in one has path patterns, so node files cannot be identified; parse failures are not listed | — | 同上，原因說明之二 |
| `gapsUndeterminableReasonScanFailed` | 掃描時發生非預期錯誤，無法判斷破洞；請重新掃描 | An unexpected error occurred during the scan, so gaps cannot be determined. Try rescanning. | — | 同上，原因說明之三（1.83，SPEC-001 v1.48，`0.5.0-W1-114.15` 用戶裁決） |

**1.48 新增（對齊 SPEC-001 v1.23 §1 schema 不相容列「型別表版本無法判讀」；ARB 實檔由 `0.3.0-W3-547` 加入）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `schemaVersionUnreadableMessage` | 無法判讀此專案型別表的版本，請在該專案重新產生型別表後再開啟 | The version of this project's schema file cannot be read. Regenerate the schema in that project and open it again | — | 4.23 `BlockedState.withDetail` 本體 `message`（schema 不相容且 `projectVersion` 為 `null` 時取代 `schemaIncompatibleMessage`）；面板照舊顯示 App 已知版本範圍 |

**1.49 補登（既存 key，`0.1.0-W2-004` 起只建於 `app_zh.arb`；zh 取 ARB 現值，en 新擬，`app_en.arb` 實檔由 `0.3.2-W3-548` 加入）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapItemLineLabel` | 第 {lineNumber} 行 | Line {lineNumber} | lineNumber（int） | §5 畫面（`ListRow.item` 次文字，破洞所在行號；`lineNumber` 為 `null` 時不渲染，SPEC-001 §5） |

**1.51 補登（既存 key，zh／en 皆取 ARB 現值，`0.3.3-W3-376`）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapCategoryOrphanEvent` | 孤立事件 | Orphan Events | — | §5 畫面（4.40 `sectionHeader` 分節類別名稱，破洞類別 `orphan-event`，SPEC-001 §5） |
| `gapCategoryEventDeclarationMismatch` | 事件宣告與 flow 不符 | Event Declaration Mismatch | — | §5 畫面（4.40 `sectionHeader` 分節類別名稱，破洞類別 `event-declaration-mismatch`，SPEC-001 §5） |

**1.56 補登（lib 已使用、本檔未記載的既存 key；zh／en 皆取 ARB 現值，`0.3.3-W3-384`）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `folderAccessRationale` | 請選擇一個資料夾，App 將在其中讀取與編輯文件。此授權會被記住，下次開啟不需重選。 | Pick a folder for the app to read and edit documents in. This permission is remembered, so you won't need to select it again. | — | §1 未選專案（4.21 `page` 的 `explanation`，`state-domain-unset`） |
| `emptyUcMessage` | 此專案尚無 UC 節點 | This project has no UC nodes yet | — | §2 無 UC（4.21 `page` 的 `message`，`state-ucFlow-empty`）；1.62 起取代同文案的 `noUcNodesMessage`（該 key 已自 ARB 移除，`0.3.3-W3-395`） |
| `workspaceNotRemembered` | 已選定，但下次啟動需重新選擇 | Selected, but you will need to choose again next time | — | 4.26 `AppSnackBar.plain`（SPEC-003 §3.7 選定資料夾成功但偏好設定寫入失敗，`ChooseFolderNotRemembered`；SPEC-003 §2.13 對照表列 15、§2.14 指派表列 16） |
| `scanCompleteNotificationTitle` | 破洞掃描完成 | Gap scan complete | — | macOS 系統通知標題（非本檔元件承載，權威定義為 SPEC-003 §2.2〈系統層通知〉通知內容列；本列僅為 ARB 對照） |
| `scanCompleteWatchNotificationTitle` | 破洞報告已更新 | Gap report updated | — | macOS 系統通知標題，檔案監看輪次專用（非本檔元件承載，權威定義為 SPEC-003 §2.2〈系統層通知〉監看輪次通知內容列；本列僅為 ARB 對照，`0.6.0-W1-080`） |
| `scanCompleteWatchNotificationBody` | 檔案變動後重新掃描，目前 {count} 個破洞 | Rescanned after file changes: {count} gaps now | count | macOS 系統通知內文，檔案監看輪次專用，三態共用（同上，`0.6.0-W1-080`） |

**1.69 新增（`0.5.0-W1-106`，「畫面」列顯示名；1.71 依用戶裁決 K6 收窄；ARB 已建，zh／en 值為本檔提案文案）**：domain 列首不經 i18n，4.37 `MatrixGrid` 與 4.38 `SwimlaneGrid` 一律顯示 `DomainBundle.domain` 原值（未知 domain 亦同）；只有 App 自身詞彙 `presentation` 有 key——用於泳道「畫面」列與 SPEC-003 §3.2「本 UC 外」的 `presentation` 值，不成矩陣列（CLAUDE.md §6、`docs/tech-decisions.md` 2026-10-08 補記「domain 列首顯示原值，只有「畫面」列走 i18n」）。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `swimlaneScreenLaneName` | 畫面 | Screen | — | 4.38 「畫面」列列首（`kind: screen`）；SPEC-003 §3.2 事件流小表「本 UC 外」所列值為 `presentation` 時 |
| `swimlaneUnplacedLaneName` | 未定位 | Unplaced | — | 4.38 「未定位」列列首（`kind: unplaced`；SPEC-001 §1〈泳道布局規則〉「`traverses` 異常的步驟」列，`0.5.0-W1-114.1` PM 處置 NC-a）。key 與文案為 lavender 提案、本輪落地 |

**1.80 提案（`0.5.0-W1-114.16`，對應 SPEC-001 v1.41 §5〈破洞報告項目投影：`parseFailure` 與 `graphDefect`〉；key 識別名、zh 與 en 文案 2026-10-09 PM 確認；ARB 由 `0.5.0-W1-114.17` 建立）**：分節標籤用於 4.40 `sectionHeader`，項目說明用於 4.40 `item` 主文字；行號沿用 `gapItemLineLabel`，只有 EVT-CORPUS-003 可能帶行號。EVT-CORPUS-005 的項目說明用上方 1.78／1.79 定義的 `gapNonDomainPaths*` 四個 key（規格已定、ARB 由 `0.5.0-W1-114.17` 一併建立；原「沿用既有」措辭誤指 ARB 已存在，2026-10-11 更正），不另設。

> **已淘汰的 key**（不列入上方各表，ARB 須刪除）：`gapCategoryMissingFrontmatter`（原 zh「缺少 Frontmatter」／en「Missing Frontmatter」，0.1 分節名）——2026-10-09 用戶裁決 M1 移除該分節、併入 `gapCategoryParseFailure`（SPEC-001 v1.42 §5〈定案〉），已由 `0.5.0-W1-114.17` 自 ARB 刪除。2026-10-11 自表格移出，避免讀表比對 ARB 的測試需另設例外。

分節標籤：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapCategoryParseFailure` | 解析失敗 | Parse Failures | — | 分節 `parse-failure`（EVT-CORPUS-003） |
| `gapCategoryFlowBlockMalformed` | flow 區塊解析失敗 | Flow Block Parse Failures | — | 分節 `flow-block-malformed`（EVT-CORPUS-004） |
| `gapCategoryNonDomainPathsMalformed` | 非 domain 路徑清單格式錯誤 | Malformed Non-domain Path List | — | 分節 `non-domain-paths-malformed`（EVT-CORPUS-005） |
| `gapCategoryTopicFilesMalformed` | 主題檔無法讀取或不一致 | Unreadable or Inconsistent Topic Files | — | 分節 `topic-files-malformed`（EVT-CORPUS-006；1.116 加入表列） |
| `gapCategoryGraphDefect` | 圖結構缺陷 | Graph Defects | — | 分節 `graph-defect`（主圖四子類與 domain 重複宣告） |
| `gapCategoryGraphDefectFlow` | flow 結構缺陷 | Flow Defects | — | 分節 `graph-defect-flow`（flow 各子類，見 SPEC-007 FR-09 子類表） |

EVT-CORPUS-003 項目說明（依 EVT-CORPUS-003 `reason` 值域；原因碼識別名為 `CarrierParseFailureReason` 的 `noFrontmatter`／`frontmatterUnclosed`／`frontmatterNotMap`／`yamlInvalid`／`unreadable`，`unreadable` 的子原因為 `UnreadableReason` 的 `encoding`／`permission`／`fileDeleted`；投影依識別名查 key，不從 `reason` 字串反解）：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapParseNoFrontmatter` | 缺少 frontmatter | No frontmatter | — | reason「無 frontmatter」 |
| `gapParseFrontmatterUnclosed` | frontmatter 未閉合 | Frontmatter is not closed | — | reason「frontmatter 未閉合」 |
| `gapParseFrontmatterNotMap` | frontmatter 為空或不是鍵值對映 | Frontmatter is empty or not a map | — | reason「frontmatter 為空或非 map」 |
| `gapParseYamlInvalid` | frontmatter 的 YAML 無法解析 | The frontmatter YAML could not be parsed | — | reason「YAML 語法錯誤」 |
| `gapParseUnreadableEncoding` | 無法讀取檔案：編碼錯誤 | Could not read the file: invalid encoding | — | reason「無法讀取」，子原因編碼 |
| `gapParseUnreadablePermission` | 無法讀取檔案：沒有權限 | Could not read the file: permission denied | — | reason「無法讀取」，子原因權限 |
| `gapParseUnreadableMissing` | 無法讀取檔案：檔案已消失 | Could not read the file: it no longer exists | — | reason「無法讀取」，子原因檔案消失 |
| `gapParseTypeAmbiguous` | 歸屬型別不明，候選：{types} | Type is ambiguous; candidates: {types} | types | `schemaAmbiguous` 為 `true` 時附於原因說明之後（SPEC-001 §5〈破洞歸屬型別不明不是新狀態〉）；`types` 為 `candidateTypes` 以「、」／", " 連接 |

EVT-CORPUS-006 項目說明（1.116 加入表列；定案文案自 1.115 起，對應 SPEC-001 v1.69 §5〈主題檔破洞的項目說明〉）：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapTopicFilesUnreadable` | 無法讀取主題檔 | Could not read the topic file | — | `topicFilesMalformed` 子原因 `unreadable` |
| `gapTopicFilesUnregisteredTopics` | {count} 個主題名不在主題清單 | {count, plural, =1{1 topic name is not in the topic registry} other{{count} topic names are not in the topic registry}} | count | `topicFilesMalformed` 子原因 `registryMismatch`；`count` 取破洞的 `unregisteredTopicCount`（SPEC-006 FR-08） |

EVT-CORPUS-004 項目說明：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapFlowBlockMalformed` | flow 區塊解析失敗，請修正後重新掃描 | The flow block failed to parse; fix it and rescan | — | 原因碼 `flowBlockMalformed`（SPEC-006 FR-08） |

`graphDefect` 項目說明（`field` 為欄位名、`value` 為原始值原樣，皆不經 i18n）：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapDanglingRefTargetMissing` | {field} 指向的 {value} 不存在 | {value} in {field} does not exist | field, value | `danglingRef`，原因 `targetMissing` |
| `gapDanglingRefTargetDuplicated` | {field} 指向的 {value} 對應多個節點 | {value} in {field} matches more than one node | field, value | `danglingRef`，原因 `targetDuplicated` |
| `gapMalformedRefInvalidShape` | {field} 的值 {value} 格式不正確 | The value {value} in {field} is malformed | field, value | `malformedRef`，原因 `invalidShape` |
| `gapMalformedRefPatternMismatch` | {field} 的值 {value} 不符合 ID 格式 | The value {value} in {field} does not match the ID pattern | field, value | `malformedRef`，原因 `patternMismatch` |
| `gapMalformedRefSelfReference` | {field} 指向自己 | {field} refers to the node itself | field | `malformedRef`，原因 `selfReference` |
| `gapDuplicateId` | ID {id} 出現在 {count} 個檔案：{paths} | ID {id} appears in {count} files: {paths} | id, count, paths | `duplicateId`；`paths` 為全部路徑以「、」／", " 連接 |
| `gapMultiSource` | {edgeType} 只能指向一個終點，目前指向 {targets} | {edgeType} allows one target but points to {targets} | edgeType, targets | `multiSource`；`targets` 為全部終點 ID 以「、」／", " 連接 |
| `gapFlowRefUnresolved` | 步驟 {stepId} 的 {field} 無法解析：{value} | Step {stepId}: {field} cannot be resolved: {value} | stepId, field, value | flow 參照未解析（含指向不存在或重複的 step id） |
| `gapFlowStepIdDuplicated` | 步驟 ID {stepId} 在此 UC 內重複 | Step ID {stepId} is duplicated in this UC | stepId | UC 內 step id 重複 |
| `gapTraversesUndeclared` | 步驟 {stepId} 的 traverses 含未宣告的 domain：{value} | Step {stepId}: traverses has an undeclared domain: {value} | stepId, value | `traverses` 名稱未宣告 |
| `gapTraversesMissing` | 步驟 {stepId} 缺少 traverses 欄位 | Step {stepId} is missing the traverses field | stepId | `traverses` 鍵缺席 |
| `gapDomainDeclaredTwice` | domain {domain} 被多個 DomainBundle 宣告：{bundles} | Domain {domain} is declared by more than one DomainBundle: {bundles} | domain, bundles | domain 重複宣告；`bundles` 為衝突 DomainBundle ID 以「、」／", " 連接 |
| `gapIsolatedNode` | {nodeType} {nodeId} 沒有任何關聯 | {nodeType} {nodeId} has no relations | nodeType, nodeId | 孤島（SPEC-001 v1.77） |
| `gapMissingRequiredEdge` | {nodeType} {nodeId} 缺少必要的關聯：{edgeType} | {nodeType} {nodeId} is missing a required relation: {edgeType} | nodeType, nodeId, edgeType | 缺必要邊，單一邊型要求（UC 三列）；`edgeType` 為型別表鍵名原值 |
| `gapMissingRequiredEdgeAnyOf` | {nodeType} {nodeId} 至少需要一種關聯：{edgeTypes} | {nodeType} {nodeId} needs at least one relation: {edgeTypes} | nodeType, nodeId, edgeTypes | 缺必要邊，二擇一要求（EVT）；`edgeTypes` 依必要邊表列序以「、」／", " 連接 |

**1.86 新增（`0.5.0-W1-114.14.1`，對應 SPEC-001 v1.49 §1「載入失敗」與 §2–§6「專案未就緒」第四個原因；ARB 已建，zh／en 值為 PM 處置文案）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `domainLoadFailedMessage` | 掃描此專案時發生非預期錯誤，無法載入圖譜 | An unexpected error occurred while scanning this project, so the graph could not be loaded. | — | 4.23 `BlockedState.plain` 本體 `message`（`state-domain-load-failed`）；只寫結果與原因，操作由按鈕承載（4.26 訊息設計要求） |
| `reloadAction` | 重新載入 | Reload | — | 4.23 `BlockedState.plain`（`AppButton.secondary` 呼叫端，`action-domain-reload`，僅載入失敗時渲染） |
| `projectUnreadyReasonLoadFailed` | 圖譜載入失敗 | Graph failed to load | — | §2–§6「專案未就緒」（4.21 `page` 呼叫端；Domain 視圖為載入失敗時） |

**1.88 新增（`0.5.0-W1-156.1`，對應 SPEC-003 v1.60 §3.7〈浮層內選資料夾失敗的常駐原因文字〉，用戶裁決 2026-10-12；ARB 已建，zh／en 值沿用下列既有 SnackBar key 的現值，語意不變）**：

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `switcherChooseFolderUnavailableReason` | 無法開啟資料夾選取面板，應用程式可能安裝不完整 | Could not open the folder picker; the app may not be installed correctly | — | 4.42 `SwitcherOverlay` 的 `chooseOtherFailureReason`（浮層內「選擇其他」選擇器無法開啟）。文案同 `chooseFolderUnavailableMessage`；另立 key 的理由：兩者載體不同（浮層內常駐文字與 SnackBar），長度與換行政策各依所屬元件的內容政策，不宜由同一值同時滿足兩套上限 |
| `switcherFolderUnavailableReason` | 資料夾無法使用：{reason} | Folder unavailable: {reason} | reason | 4.42 `SwitcherOverlay` 的 `chooseOtherFailureReason`（浮層內「選擇其他」選定資料夾不可讀或不存在，`reason` 取 `WorkspaceUnavailable.reason`）。文案同 `folderUnavailableMessage`，另立 key 的理由同上一列 |

最近專案項點擊後判定不可用時不新增 key：沿用 4.9 `reason` 的既有 key `projectUnavailableReasonLabel`，`reason` 取 `WorkspaceUnavailable.reason`。

**1.94 新增（`0.5.0-W1-114.22.2`，對應 SPEC-001 v1.52 §5〈事件類項目投影〉；key 識別名、zh 與 en 文案 2026-10-20 PM 確認；ARB 由 `0.5.0-W1-114.22` 建立）**：用於 4.40 `item` 主文字；事件類項目無行號。分節標籤沿用既有 `gapCategoryOrphanEvent`、`gapCategoryEventDeclarationMismatch`（1.51 補登），不另設。`domain` 為 EVT `consumers`／`producers` 宣告值原樣（含保留字 `presentation` 與大小寫不同、未宣告的值），不經 i18n。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapOrphanEventEmittedNotConsumed` | 有步驟發出此事件，但沒有步驟消費，consumers 也未宣告 | Emitted by a step, but no step consumes it and no consumers are declared | — | `orphan-event`，形態「有發出無消費」（SPEC-003 §3.5） |
| `gapOrphanEventConsumedNotEmitted` | 有步驟消費此事件，但沒有步驟發出，producers 也未宣告 | Consumed by a step, but no step emits it and no producers are declared | — | `orphan-event`，形態「有消費無發出」 |
| `gapEventConsumerUnmatched` | consumers 宣告了 {domain}，但沒有對應的步驟消費此事件 | Declared consumer {domain} has no matching step that consumes this event | domain | `event-declaration-mismatch`，方向 `consumers`；「對應」依 SPEC-003 §3.5（`traverses` 包含該 domain，`presentation` 為 `traverses == []`） |
| `gapEventProducerUnmatched` | producers 宣告了 {domain}，但沒有對應的步驟發出此事件 | Declared producer {domain} has no matching step that emits this event | domain | `event-declaration-mismatch`，方向 `producers`；`presentation` 與未宣告值在此方向恆為未對應 |

**1.96 新增（`0.5.0-W1-458.3`，對應 SPEC-007 v1.34 FR-09 子類「事件引用未解析」與 SPEC-001 v1.54 §5 表一；key 識別名、zh 與 en 文案 2026-10-21 PM 確認，比照 1.80／1.94 先例；ARB 由 `0.5.0-W1-458.4` 建立）**：用於 4.40 `item` 主文字，列在 flow 小組（分節標籤沿用 `gapCategoryGraphDefectFlow`）；無行號。`field` 為 `emits` 或 `consumes`、`value` 為原始值原樣，皆不經 i18n。句型比照 `gapFlowRefUnresolved`，兩者並列時，「引用的事件不存在」標示事件 id 的問題，「無法解析」標示 step id 的問題。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `gapFlowEventUnresolved` | 步驟 {stepId} 的 {field} 引用的事件不存在：{value} | Step {stepId}: {field} refers to an event that does not exist: {value} | stepId, field, value | 事件引用未解析（SPEC-007 FR-10〈事件引用〉） |

**1.99 新增（`0.5.0-W1-486.1`，對應 SPEC-001 v1.57 §1「圖不可用」，`0.5.0-W1-486` 用戶裁定 B+；zh／en 為提案文案，ARB 由對應實作票建立）**：原因與載入當下的 schema 不相容阻擋態同一 reason（型別表版本不在 App 已知範圍，SPEC-007 FR-09 已把建圖不可用各原因碼統一為此原因）；後半句是重新掃描的前提而非操作指引——型別表未修正前重掃仍不可用，不暗示重掃一定恢復。動作沿用既有 `rescanAction`（重新掃描），不新增動作 key。`domainGraphUnavailableScanning` 為掃描輪次進行期間取代原因文字的訊息（1.100 依用戶裁定 2026-10-27 補），計數文字沿用既有 `gapsScanningProcessedCount`。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `domainGraphUnavailableMessage` | 此專案的型別表版本不在 App 已知範圍內（不高於 {appVersion}），最近一次掃描無法建立圖譜；型別表修正或重新產生之前，重新掃描仍會得到相同結果 | This project's schema version is outside the range this app knows (up to {appVersion}), so the latest scan could not build the graph. Until the schema is fixed or regenerated, rescanning will give the same result | appVersion | §1 圖不可用（4.21 `section` 呼叫端，`state-domain-graph-unavailable`）；`appVersion` 為 App 內建型別表產生版本，與 `schemaKnownRangeValue` 代入同一值 |
| `domainGraphUnavailableScanning` | 掃描中 | Scanning… | — | §1 圖不可用，掃描輪次進行期間取代 `domainGraphUnavailableMessage`（4.21 `section`；計數文字沿用 `gapsScanningProcessedCount`，1.100 補） |

**1.113 新增（`0.6.0-W1-105.2`，對應 SPEC-001 v1.65 §6「圖不可用」「節點不在目前的圖上」；zh／en 為提案文案，ARB 由對應實作票建立）**：`nodeDetailGraphUnavailableMessage` 的原因與 §1 `domainGraphUnavailableMessage` 同一 reason，後半句改為指出重新掃描的位置，因本畫面不設重新掃描。`nodeDetailNodeAbsentHint` 列出的三種可能原因不排序、不推斷是哪一種（SPEC-001 §6〈本狀態不跳轉破洞報告〉）。兩狀態的動作沿用既有動作文案，不新增動作 key。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `nodeDetailGraphUnavailableMessage` | 此專案的型別表版本不在 App 已知範圍內（不高於 {appVersion}），最近一次掃描無法建立圖譜，節點詳情暫無法顯示；可至 Domain 視圖重新掃描 | This project's schema version is outside the range this app knows (up to {appVersion}), so the latest scan could not build the graph and node details are unavailable. You can rescan from the Domain view | appVersion | §6 圖不可用（4.21 `page` 呼叫端，`state-nodeDetail-graph-unavailable`）；`appVersion` 與 `domainGraphUnavailableMessage` 代入同一值 |
| `nodeDetailNodeAbsentMessage` | 節點 {nodeId} 不在目前的圖上 | Node {nodeId} is not in the current graph | nodeId | §6 節點不在目前的圖上（4.21 `page` 訊息，`state-nodeDetail-node-absent`） |
| `nodeDetailNodeAbsentHint` | 可能已被刪除、改了 ID，或因 ID 重複而被排除 | It may have been deleted, renamed to another ID, or excluded because of a duplicate ID | — | 同上，4.21 `page` 說明 slot |

**1.114 新增（`0.6.0-W1-110`，對應 SPEC-001 v1.67 §3「圖不可用」；zh／en 為提案文案，ARB 由對應實作票建立）**：原因與 `nodeDetailGraphUnavailableMessage` 同一 reason，只換畫面名稱。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `traceabilityGraphUnavailableMessage` | 此專案的型別表版本不在 App 已知範圍內（不高於 {appVersion}），最近一次掃描無法建立圖譜，追溯視圖暫無法顯示；可至 Domain 視圖重新掃描 | This project's schema version is outside the range this app knows (up to {appVersion}), so the latest scan could not build the graph and the traceability view is unavailable. You can rescan from the Domain view | appVersion | §3 圖不可用（4.21 `page` 訊息，`state-traceability-graph-unavailable`） |

**1.122 新增（`0.6.0-W1-070.2`，對應 SPEC-001 v1.76 §9、SPEC-003 v1.82 §3.8 與 §3.5 破洞項開啟原始檔列；zh／en 與 ARB 同批）**：偏好設定面板的標題、系統預設選項、無可選編輯器說明，以及 `openedWithoutEditor` 的 SnackBar 文案。編輯器名稱（VS Code、VS Code Insiders、Cursor、Zed）為產品專有名詞，不進 i18n。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `openedWithoutEditorMessage` | 所選編輯器無法使用，已以系統預設方式開啟 | The selected editor is unavailable; opened with the default application | — | 4.26 `AppSnackBar.plain`（SPEC-003 §3.5 破洞項開啟原始檔，結果 `openedWithoutEditor`） |
| `preferencesTitle` | 偏好設定 | Preferences | — | SPEC-001 §9 偏好設定面板標題（`AppText.subtitle`） |
| `preferencesEditorSystemOption` | 系統預設（不定位） | System default (no line positioning) | — | SPEC-001 §9 編輯器清單首項 `option-preferences-editor-system`（`ListRow.option` 主文字） |
| `preferencesNoEditorsExplanation` | 本機未找到支援定位至行號的編輯器。支援的編輯器：VS Code、VS Code Insiders、Cursor、Zed | No editor that can jump to a line was found on this machine. Supported editors: VS Code, VS Code Insiders, Cursor, Zed | — | SPEC-001 §9 無可選編輯器說明（`AppText.multiLine`，`state-preferences-no-editors`） |
| `preferencesEditorAppliedMessage` | 已改用 {editor}，下次開啟原始檔時生效 | Now using {editor}; takes effect the next time a source file is opened | editor（String，該選項的顯示標籤） | 4.26 `AppSnackBar.plain`（SPEC-003 §3.8 編輯器選項，寫入成功；§2.13 列 20）；1.132 登記 |
| `preferencesEditorSaveFailedMessage` | 無法儲存編輯器設定 | Could not save the editor setting | — | 4.26 `AppSnackBar.plain`（SPEC-003 §3.8 編輯器選項，寫入失敗；§2.13 列 21）；1.132 登記 |


**1.133 新增（`0.7.0-W1-007.1`，對應 SPEC-001 v1.83 §9／§11、SPEC-003 v1.86 §3.8／§3.10；zh／en 為提案文案，ARB 由對應實作票建立）**：側欄底部兩項的標籤、鍵盤快捷鍵面板的標題與清單文字。按鍵字面（⌘,、Esc、Tab、Shift+Tab、Enter、Space、↓、↑、Home、End）在兩語系相同，為資料值不進 i18n（SPEC-001 §11）。macOS 主選單的標題不進 ARB，由 `.lproj` 字串檔承載（SPEC-003 §3.11）；其中「鍵盤快捷鍵」選單項與 `keyboardShortcutsTitle` 字面相同，修改時同批改。關閉鈕沿用既有 `cellDetailCloseAction`，不重登。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `sidebarSettingsLabel` | 設定 | Settings | — | 4.7 `NavItem.action`（`nav-action-preferences`，4.27〈側欄底部 slot〉） |
| `keyboardShortcutsTitle` | 鍵盤快捷鍵 | Keyboard Shortcuts | — | 4.7 `NavItem.action`（`nav-action-shortcuts`）、SPEC-001 §11 面板標題（`AppText.subtitle`） |
| `shortcutOpenPreferencesAction` | 開啟偏好設定 | Open Preferences | — | 4.40 `ListRow.shortcut` 作用（SPEC-001 §11 第 1 列） |
| `shortcutCloseSwitcherAction` | 收合專案切換浮層 | Close the project switcher | — | 同上（第 2 列） |
| `shortcutCloseSchemaDetailAction` | 收合型別表詳情面板 | Close the schema details panel | — | 同上（第 3 列） |
| `shortcutClearCellAction` | 清除矩陣的已選格 | Clear the selected matrix cell | — | 同上（第 4 列） |
| `shortcutCloseFilterMenuAction` | 收合篩選選單 | Close the filter menu | — | 同上（第 5 列） |
| `shortcutClosePanelAction` | 關閉偏好設定或鍵盤快捷鍵面板 | Close the Preferences or Keyboard Shortcuts panel | — | 同上（第 6 列） |
| `shortcutMoveFocusAction` | 依序移動焦點（Shift+Tab 反向） | Move focus in order (Shift+Tab moves back) | — | 同上（第 7 列） |
| `shortcutActivateAction` | 執行已聚焦的按鈕或項目 | Activate the focused button or item | — | 同上（第 8 列） |
| `shortcutOpenFilterMenuAction` | 展開已聚焦的篩選選單 | Open the focused filter menu | — | 同上（第 9 列） |
| `shortcutMoveInFilterMenuAction` | 在篩選選單的選項間移動 | Move between options in the filter menu | — | 同上（第 10 列） |
| `shortcutContextAnywhere` | 任何畫面 | Anywhere | — | 4.40 `ListRow.shortcut` 情境（第 1、7、8 列） |
| `shortcutContextSwitcherOpen` | 專案切換浮層展開時 | While the project switcher is open | — | 同上（第 2 列） |
| `shortcutContextSchemaDetailOpen` | Domain 視圖的型別表詳情面板展開時 | While the schema details panel is open in the Domain view | — | 同上（第 3 列） |
| `shortcutContextCellSelected` | Domain 視圖矩陣有已選格，且焦點在矩陣內時 | When a matrix cell is selected in the Domain view and focus is in the matrix | — | 同上（第 4 列） |
| `shortcutContextFilterMenuOpen` | Ticket 清單的篩選選單展開時 | While a filter menu is open in the Ticket list | — | 同上（第 5、10 列） |
| `shortcutContextPanelOpen` | 任一面板開啟時 | While either panel is open | — | 同上（第 6 列） |
| `shortcutContextFilterFocused` | Ticket 清單的篩選按鈕取得焦點時 | When a filter button in the Ticket list has focus | — | 同上（第 9 列） |
| `shortcutRowA11yLabel` | {keys}：{action}，{context} | {keys}: {action}, {context} | keys（String，按鍵字面）、action（String）、context（String） | 4.40 `ListRow.shortcut` 整列朗讀 |

**1.131 新增（`0.7.0-W1-012.2`，對應 SPEC-001 v1.80 §10、SPEC-003 v1.83 §3.9、SPEC-008 FR-06～FR-08；zh／en 為提案文案，ARB 由對應實作票建立）**：第七畫面的導覽名、狀態訊息、篩選列、事件表欄首與列文字、淺層 clone 標示。既有 key 沿用不重登：`projectUnreadyReason*`、`gotoDomainViewAction`、`refreshAction`、`cancelLoadingAction`、`cancelInProgressAction`。邊型以鍵名原值（如 `uc_ticket_refs`）、節點 ID、domain 名稱、commit hash、作者、commit 訊息首行、stderr 摘要皆為資料值，不進 i18n。日期由呼叫端格式化為 `yyyy-MM-dd` 後代入（與語系無關，避免同一欄因語系不同而寬度不同）。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `navHistory` | 變更記錄 | Change history | — | 4.7 `NavItem`（`nav-item-history`）、§10 頁首 `PageTitle` |
| `historyLoading` | 正在讀取 git 歷史 | Reading git history | — | §10 讀取中（4.24 訊息） |
| `historyLoadingProcessedCount` | 已處理 {count} 個 commit | {count, plural, =1{1 commit processed} other{{count} commits processed}} | count（int） | §10 讀取中（4.24 計數文字） |
| `historyPeriodDefaultLabel` / `historyPeriodRecent30Label` / `historyPeriodAllLabel` | 預設期間 / 最近 30 天 / 全部歷史 | Default period / Last 30 days / All history | — | 4.10 `SegmentedControl` 三段 label（`option-history-period-default`／`-recent30`／`-all`）；後兩者兼作 `historyPeriodSummary` 的期間描述 |
| `historyPeriodSelectA11yHint` | 以「{period}」篩選事件 | Filter events by {period} | period（String） | 4.10 各段 `semanticLabel`（代入該段 label） |
| `historyPeriodSinceTag` | {tag} 之後 | Since {tag} | tag（String） | `historyPeriodSummary` 的期間描述：選取預設期間且有基準 tag 時（SPEC-008 FR-06 規則 5）；無基準 tag 時改用 `historyPeriodRecent30Label` |
| `historyPeriodSummary` | {period} · {count} 筆事件 | {period} · {count, plural, =1{1 event} other{{count} events}} | period（String）、count（int） | §10 正常與期間內無事件，篩選列下方（`AppText.body`） |
| `historyIncludeTicketCreatedLabel` | 包含 ticket 建檔 | Include ticket creation | — | 4.43 `AppCheckbox` label（`action-history-include-ticket-created`） |
| `historyShallowCloneBadge` | 歷史不完整：早於 {boundaryDate} 的變更不在其中 | History incomplete: changes before {boundaryDate} are not included | boundaryDate（String，`yyyy-MM-dd`） | 4.5 `Badge.category`（`badge-history-shallow-clone`） |
| `columnChange` / `columnEdgeType` / `columnDeclarer` / `columnCounterpart` / `columnCommit` / `columnDate` / `columnAuthorMessage` | 變動 / 邊型 / 宣告端 / 對端 / Commit / 日期 / 作者與訊息 | Change / Edge type / Declarer / Counterpart / Commit / Date / Author and message | — | 4.35 `TableRow.header`（`historyEvent` 七欄欄首，4.14 呼叫端） |
| `historyEventAdded` / `historyEventRemoved` | 新增 / 移除 | Added / Removed | — | 4.35 `historyEvent` 變動欄（`Badge.category`，tone `positive` / `negative`） |
| `historyEventAuthorMessage` | {author}：{subject} | {author}: {subject} | author（String）、subject（String） | 4.35 `historyEvent` 作者與訊息欄（`AppText.body`） |
| `historyEventA11yLabel` | {change} {edgeType}，{declarer} 至 {counterpart}，commit {hash}，{date}，{author}：{subject} | {change} {edgeType}, {declarer} to {counterpart}, commit {hash}, {date}, {author}: {subject} | change、edgeType、declarer、counterpart、hash、date、author、subject（皆 String） | 4.35 `historyEvent` 列朗讀（截斷欄的完整值由此承載） |
| `historyEmptyMessage` | 此期間沒有關係變動 | No relationship changes in this period | — | §10 期間內無事件（4.21 `section` 訊息，`panel-history-empty`） |
| `historyShowAllAction` | 顯示全部歷史 | Show all history | — | §10 期間內無事件（`action-history-show-all`，4.4 `primary`） |
| `historyNoCommitsMessage` | 此專案尚無 commit | This project has no commits yet | — | §10 期間內無事件「尚無 commit」變體（4.21 `section` 訊息） |
| `historyNotGitMessage` | 此專案不是 git repo，無法讀取變更記錄 | This project is not a git repository, so its change history cannot be read | — | §10 非 git 專案（4.21 `page` 訊息） |
| `historyGitMissingMessage` | 找不到 git 指令 | The git command was not found | — | §10 找不到 git（4.21 `page` 訊息） |
| `historyGitMissingExplanation` | 請安裝 git，或確認 git 位於 PATH 中 | Install git, or make sure git is on your PATH | — | §10 找不到 git（4.21 `page` 說明） |
| `historyRecheckAction` | 重新檢查 | Check again | — | §10 非 git 專案、找不到 git（`action-history-recheck`，4.4 `primary`） |
| `historyLoadFailedMessage` | 讀取 git 歷史失敗 | Failed to read git history | — | §10 讀取失敗（4.21 `page` 訊息） |
| `historyLoadFailedDetail` | 原因：{reason} | Reason: {reason} | reason（String，stderr 摘要原文） | §10 讀取失敗（4.21 `page` 說明） |
| `retryAction` | 重試 | Retry | — | §10 讀取失敗（`action-history-retry`，4.4 `primary`） |
| `historyCancelledMessage` | 已取消讀取 | Reading was cancelled | — | §10 已取消（4.21 `page` 訊息） |
| `historyReloadAction` | 重新讀取 | Read again | — | §10 已取消（`action-history-reload`，4.4 `primary`） |

**1.140 新增（`1.0.0-W3-553.6`，對應 SPEC-009 FR-09；zh／en 為提案文案，ARB 由對應元件票建立）**：編輯用表單元件（4.44–4.48）的元件自帶文字。欄位 label、寫入與驗證訊息、唯讀原因不在本表，見下方〈1.143 新增〉。欄位值（列舉值、版本、domain）為資料值，不進 i18n。過濾框 placeholder 沿用 `searchPlaceholder`，不重登。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `fieldEmptyValue` | 未填 | Not set | — | 4.44 placeholder；4.45、4.46 空值文字 |
| `fieldValueOutOfDomain` | 目前值「{value}」不在可選值內 | Current value "{value}" is not an allowed value | value（String） | 4.48 提示格（4.45、4.46、4.47 的 outOfDomain；用戶裁定，`1.0.0-W3-675`） |
| `dropdownA11yLabel` | {label}，目前：{value} | {label}, current: {value} | label、value（String） | 4.45、4.46 觸發器朗讀 |
| `referencePickerNoMatch` | 沒有符合的項目 | No matching items | — | 4.46 無符合項 |
| `radioYes` / `radioNo` | 是 / 否 | Yes / No | — | 4.47 布林欄位選項（SPEC has_functional_requirements） |

**1.141 新增（`1.0.0-W3-673.1`，對應 SPEC-001 v1.87 §6〈主欄分隔線上下的內容〉；zh／en 為提案文案，ARB 由對應實作票建立）**：節點詳情本文讀取或切分失敗時，本文區的替代說明。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `nodeDetailBodyUnavailableMessage` | 無法顯示本文：檔案在上次掃描後已改動或無法讀取，下次掃描完成後會更新 | Cannot show the body: the file changed or became unreadable after the last scan. It will update after the next scan | — | §6 正常，本文區替代 `DocumentBody`（`AppText.body`，4.20〈本文來源的界線〉） |

**1.143 新增（`1.0.0-W3-553.3.1`，對應 SPEC-001 v1.89 §1、§6、§12 與 SPEC-003 v1.94 §3.6、§3.12；zh／en 為提案文案，ARB 由對應元件票建立）**：編輯模式、唯讀降級與寫入清單的文字。快照期限說明不使用「備份」一詞：快照會被 `git gc` 清除，稱為備份會讓使用者以為可以長期保留。欄位 label 為 frontmatter 鍵名字面值，不進 i18n（4.48 slot 契約）。寫入清單的路徑、欄位名、取回指令為資料值，不進 i18n。驗證狀態的 key 由 `FieldBlock` 提示格與 `WriteLogRow` 共用。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `editFieldsAction` | 編輯欄位 | Edit fields | — | §6 正常，`action-nodeDetail-edit`（4.4 `secondary`；唯讀降級時 disabled，`disabledReason` 為唯讀降級徽章文字）；1.1 起另用於 §5 破洞項的編輯入口，`action-gaps-edit-<itemId>`（4.4 `text`，4.40 `item` trailing） |
| `editDoneAction` | 完成 | Done | — | 4.50 `doneButton`（`action-nodeDetail-edit-done`） |
| `editDiscardAndReloadAction` | 放棄並重讀 | Discard and reload | — | 4.49 動作（`action-nodeDetail-edit-reload`） |
| `nodeDetailEditReadFailedMessage` | 無法讀取這個檔案，未進入編輯 | Could not read this file, so editing did not start | — | §6 正常，「編輯欄位」鈕下方（`badge-nodeDetail-edit-read-failed`，`AppText.caption`） |
| `readonlyWorkspaceNotGitBadge` | 此資料夾不是 git repo，無法在 App 內編輯 | This folder is not a git repository, so it cannot be edited in the app | — | 4.27 `badge-<screen>-readonly-workspace`（`Badge.tag`）；`editFieldsAction` 的 `disabledReason` |
| `readonlyWorkspaceGitMissingBadge` | 找不到 git，無法在 App 內編輯 | git was not found, so files cannot be edited in the app | — | 同上 |
| `editBannerExternallyModifiedWarning` | 這個檔案已在 App 外被修改。未送出的值仍保留，放棄並重讀可載入目前的檔案內容 | This file was changed outside the app. Unsent values are kept; discard and reload to load the current file | — | 4.49 `warning`（外部已改預警） |
| `editBannerExternallyModifiedBlocked` | 這個檔案已在 App 外被修改，這次寫入沒有執行。放棄並重讀後才能繼續編輯 | This file was changed outside the app, so this write was not performed. Discard and reload to continue editing | — | 4.49 `negative`（外部已改阻擋） |
| `editBannerReloadFailed` | 無法重新讀取這個檔案，請再按一次放棄並重讀 | Could not reload this file. Try Discard and reload again | — | 4.49 `negative`（重讀讀取失敗） |
| `fieldDraftUnsentHint` | 尚未送出（Enter 送出、Esc 還原） | Not sent yet (Enter to send, Esc to revert) | — | 4.48 提示格，`AppTextInput.singleLine` 的未送出（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 1） |
| `fieldDraftUnsentHintMultiLine` | 尚未送出（⌘Enter 送出、Esc 還原） | Not sent yet (⌘Enter to send, Esc to revert) | — | 4.48 提示格，`AppTextInput.multiLine` 的未送出（提交鍵不同，4.44 變體） |
| `fieldWriteInProgress` | 寫入中 | Writing | — | 4.48 提示格 writing；4.51 寫入結果徽章（寫入中） |
| `fieldSeeWriteLogHint` | 取回方式見寫入清單 | See the write log for how to restore | — | 4.48 提示格，`written` 且有快照時接在驗證狀態之後 |
| `fieldBlockedSnapshotFailed` | 無法建立快照，檔案未改 | Could not create a snapshot, so the file was not changed | — | 4.48 提示格；4.51 寫入結果說明 |
| `fieldBlockedRewriteNotIsolated` | 無法只改這個欄位，檔案未改。請改用外部編輯器 | This field cannot be changed on its own, so the file was not changed. Use an external editor | — | 同上 |
| `fieldIoFailed` | 讀寫失敗，檔案未改 | Reading or writing failed, so the file was not changed | — | 同上 |
| `fieldNotEditableHint` | 此欄位目前不能在 App 內編輯 | This field cannot be edited in the app yet | — | 4.48 `readOnly` 提示格 |
| `writeResultWritten` | 已寫入 | Written | — | 4.51 寫入結果徽章 |
| `writeResultBlocked` | 未寫入 | Not written | — | 4.51 寫入結果徽章（三種 `blocked` 共用） |
| `writeResultIoFailed` | 讀寫失敗 | Read or write failed | — | 4.51 寫入結果徽章 |
| `writeResultExternallyModified` | 檔案已在 App 外被修改，這次寫入沒有執行 | The file was changed outside the app, so this write was not performed | — | 4.51 寫入結果說明（`blocked(externallyModified)`） |
| `validationRunning` | 驗證中 | Validating | — | 4.48 提示格；4.51 驗證徽章 |
| `validationPassed` | 驗證通過 | Validation passed | — | 同上 |
| `validationFailed` | 發現 {count} 個新問題 | {count, plural, =1{1 new issue found} other{{count} new issues found}} | count（int） | 同上 |
| `validationUnavailable` | 無法驗證 | Could not validate | — | 同上；原因接在其後 |
| `validationUnavailableExecutableMissing` | 找不到 uv 或 doc CLI | uv or the doc CLI was not found | — | `unavailable(executableMissing)` 的原因（SPEC-009 FR-05） |
| `validationUnavailableUnexpectedExitCode` | 驗證程式以非預期的結束碼結束 | The validator exited with an unexpected code | — | `unavailable(unexpectedExitCode)` |
| `validationUnavailableUnparsableOutput` | 驗證程式的輸出無法解析 | The validator's output could not be parsed | — | `unavailable(unparsableOutput)` |
| `validationUnavailableTimedOut` | 驗證超過 30 秒，已停止 | Validation took longer than 30 seconds and was stopped | — | `unavailable(timedOut)` |
| `validationUnavailableBaselineNotReady` | 寫入前的驗證基準尚未完成 | The validation baseline was not ready before the write | — | `unavailable(baselineNotReady)`（SPEC-009 v1.7 FR-05） |
| `writeLogTitle` | 寫入清單 | Write Log | — | SPEC-001 §12 面板標題（`AppText.subtitle`）；4.7 `NavItem.action` 標籤（`nav-action-writeLog`） |
| `writeLogEmptyMessage` | 本次開啟 App 之後尚未在 App 內寫入任何檔案 | No files have been written in the app since it was opened | — | SPEC-001 §12 無寫入（`AppText.multiLine`） |
| `writeLogColumnPath` | 路徑 | Path | — | 4.51 朗讀（`writeLogRowA11yLabel` 的欄名） |
| `writeLogColumnField` | 欄位 | Field | — | 同上 |
| `writeLogColumnResult` | 寫入結果 | Write result | — | 同上 |
| `writeLogColumnValidation` | 驗證 | Validation | — | 同上 |
| `writeLogColumnRestore` | 取回方式 | How to restore | — | 4.51 取回說明上方的小標（`AppText.caption`）與朗讀 |
| `writeLogProjectLabel` | 專案：{project} | Project: {project} | project（String，寫入發出時的專案名稱） | 4.51 所屬專案 |
| `writeLogSnapshotExpiryNote` | 快照由 git 保留約兩週（gc.pruneExpire），之後可能被清除 | git keeps the snapshot for about two weeks (gc.pruneExpire); it may be removed after that | — | 4.51 快照期限說明 |
| `writeLogRowA11yLabel` | {pathLabel} {path}，{fieldLabel} {field}，{resultLabel} {result}，{validationLabel} {validation} | {pathLabel} {path}, {fieldLabel} {field}, {resultLabel} {result}, {validationLabel} {validation} | pathLabel、path、fieldLabel、field、resultLabel、result、validationLabel、validation（String；非 `written` 列 validation 傳空字串並省略該段由元件處理） | 4.51 列朗讀 |
| `writeLogNavA11yLabel` | {label}，{count} 筆失敗 | {label}, {count, plural, =1{1 failed} other{{count} failed}} | label（String）、count（int） | 4.7 `badge` 存在時的朗讀 |

**1.145 新增（`1.0.0-W3-686`，對應 SPEC-009 FR-09〈可否清空〉；zh／en 為提案文案，ARB 由對應元件票建立）**：必填欄位送出空白時的提示。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `fieldRequiredEmpty` | 此欄位必填，空白未送出 | This field is required, so the blank value was not sent | — | 4.48 提示格「必填空白」 |

**1.148 新增（`1.1.0-W1-111`，對應 SPEC-009 FR-09 的 1.1 列；zh／en 為提案文案，ARB 由落地票建立）**：多值引用與核取清單。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `referenceChipsAdd` | 加入 | Add | — | 4.52 加入觸發器（規格先行：1.1.0-W2-001） |
| `referenceChipsRemoveA11y` | 移除 {value} | Remove {value} | value（String，chip 的值） | 4.52 移除鈕朗讀（規格先行：1.1.0-W2-001） |
| `referenceChipsA11yLabel` | {label}，{count} 項 | {label}, {count, plural, =1{1 item} other{{count} items}} | label（String，欄位 label）、count（int） | 4.52 chip 列朗讀（規格先行：1.1.0-W2-001） |
| `fieldReferenceNotFound` | 「{value}」在專案中找不到，可移除 | "{value}" was not found in the project; you can remove it | value（String） | 4.48 提示格，4.52 有找不到的 chip 時；chip 朗讀（規格先行：1.1.0-W2-001） |
| `checkboxGroupNoOptions` | 專案尚未宣告任何 domain | The project has not declared any domains | — | 4.48 提示格，4.53 選項為空（規格先行：1.1.0-W2-002） |

**1.149 新增（`1.1.0-W1-111` Step 4.5 第 2 項，對應 SPEC-009 FR-05 `partiallyWritten` 與 FR-08〈多檔寫入的列法（1.1）〉；zh／en 為提案文案，ARB 由落地票建立）**：多檔寫入與部分寫入。

| key | zh | en | placeholders | 使用處 |
|-----|----|----|--------------|--------|
| `fieldPartiallyWritten` | 修正沒有完成：{count} 個相關檔案已改寫且無法自動還原。再送一次同樣的修正即可補齊 | The change was not completed: {count, plural, =1{1 related file was} other{{count} related files were}} changed and could not be restored automatically. Send the same change again to complete it | count（int，未還原的檔數） | 4.48 提示格「部分寫入」，觸發原因 `ioFailed`，接 `fieldSeeWriteLogHint`（規格先行：1.1.0-W2-003） |
| `fieldPartiallyWrittenReloadFirst` | 修正沒有完成：{count} 個相關檔案已改寫且無法自動還原。請先放棄並重讀，再送一次同樣的修正即可補齊 | The change was not completed: {count, plural, =1{1 related file was} other{{count} related files were}} changed and could not be restored automatically. Discard and reload first, then send the same change again to complete it | count（int，未還原的檔數） | 4.48 提示格「部分寫入」，觸發原因 `blocked(externallyModified)`（此時各值格 disabled，4.50），接 `fieldSeeWriteLogHint`（規格先行：1.1.0-W2-003） |
| `writeResultPartiallyWritten` | 部分寫入 | Partially written | — | 4.51 寫入結果徽章（規格先行：1.1.0-W2-003） |
| `writeLogPartiallyWrittenNote` | 這次修正沒有完成，{count} 個檔案已改寫且無法自動還原。再送一次同樣的修正可補齊，或用下方指令取回。原因： | This change was not completed. {count, plural, =1{1 file was} other{{count} files were}} changed and could not be restored automatically. Send the same change again to complete it, or use the commands below to restore. Cause: | count（int） | 4.51 寫入結果說明，其後接觸發原因（規格先行：1.1.0-W2-003） |
| `writeLogBatchFilesLabel` | 同批寫入的檔案 | Also written in this change | — | 4.51 同批檔案小標（`written`）（規格先行：1.1.0-W2-003） |
| `writeLogUnrevertedFilesLabel` | 未還原的檔案 | Files not restored | — | 4.51 同批檔案小標（`partiallyWritten`）（規格先行：1.1.0-W2-003） |

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

全部 42 條目皆無待決欄位，可被畫面票引用（含新 key 者以既有 i18n 建置票為元件票 blockedBy，已建，不構成待決）；6 項尺寸 token 已建齊，原 6 條目自本清單去標（`matrixColumnWidth` 值已於 §3.7 第 24 項核定為 122）；4.13 `FilterDropdown`、4.14 `TableColumnHeader`（`sortable` 變體）已依 SPEC-003 §3.4 補齊回饋契約與播報值，元件票實作時自本清單去標。

**1.140 新增的封鎖項**：4.44 `AppTextInput`、4.45 `AppDropdown`、4.46 `ReferencePicker`、4.47 `AppRadioGroup`、4.48 `FieldBlock`（5.17）含「待決（1.0.0-W3-553.3）」欄位（狀態矩陣 disabled／error 列、套用時點第 2、4 問、回饋契約 locate／state-change／等待與結果的寫入層、錨點、4.48 編輯狀態各列與組合規則），以及仍標「提案」的值（文字輸入的失焦提交、錨點命名、欄位堆疊的父容器，皆隨 553.3 裁定），不得被畫面票引用。解除條件：`1.0.0-W3-553.3` 定稿並回填待決欄後，回 `1.0.0-W3-553.6` 重驗〈契約齊全的定義〉。提交時點、outOfDomain 呈現、`AppRadioGroup` 方向與鍵盤四項已於 2026-11-11 由用戶裁定（`1.0.0-W3-675`），不在封鎖項內。4.48 等待與結果的逾時段已由 `1.0.0-W3-676` 補定（1.142，SPEC-009 v1.2），不在封鎖項內。

**1.143 的狀態**（`1.0.0-W3-553.3.1`）：上段所列待決欄位與提案值已全數回填或核定——失焦草稿、寫入結果時的焦點、欄位排列與 Tab 順序依用戶裁定 2026-11-11（題 1–3），寫入期間的鎖定改為唯讀鎖定（題 2 (e)），錨點改用 SPEC-003 §2.9 既有類別，欄位堆疊的父容器定為 `FieldList`。同版新增 4.49 `NoticeBanner`、4.50 `FieldList`、4.51 `WriteLogRow`，修改 4.1 `AppText`（`code`）、4.7 `NavItem`（`badge`）、4.27 `AppShell`（側欄底部三項、唯讀降級徽章）。以上編輯相關條目在 `1.0.0-W3-553.6` 重驗〈契約齊全的定義〉通過之前，仍不得被畫面票引用；重驗結果由該票回寫本段。唯一保留的待決值是 4.46 `allowEmpty` 對 PROP target_version 的預設（待決（1.0.0-W3-686）），它不屬編輯狀態，只使 4.46 維持不可被畫面票引用，不擋本組其他條目。

**1.144 的重驗結果**（`1.0.0-W3-553.6`，〈契約齊全的定義〉六條，逐條紀錄在該票）：

| 條目 | 結果 | 可否被畫面票引用 |
|------|------|----------------|
| 4.44 `AppTextInput` | 六條通過 | 可 |
| 4.45 `AppDropdown` | 六條通過（`options` 上限定為推導值 10，用戶裁定 2026-11-11） | 可 |
| 4.46 `ReferencePicker` | 六條通過（`allowEmpty` 於 1.145 定案，`1.0.0-W3-686`；1.146 重驗第 1 條，其餘五條 1.144 已通過） | 可 |
| 4.47 `AppRadioGroup` | 六條通過（`options` 不設上限、下限 2，用戶裁定 2026-11-11） | 可 |
| 4.48 `FieldBlock`（5.17） | 六條通過（操作機制改為「不適用」加理由，1.144；1.145 新增「必填空白」後重驗仍通過，1.146 補其測試點與狀態邊） | 可 |
| 4.49 `NoticeBanner` | 六條通過（對比回填、操作機制改為「不適用」加理由，1.144） | 可 |
| 4.50 `FieldList`（5.18） | 六條通過（操作機制改為「不適用」加理由，1.144） | 可 |
| 4.51 `WriteLogRow`（5.19） | 六條通過（內容政策補寫入結果說明、驗證不可用原因、取回說明小標三列，1.144） | 可 |
| 4.1 `code`、4.7 `badge`、4.27 側欄底部三項與唯讀降級徽章 | 1.143 的修改六條通過 | 可 |

**1.148 新增**（`1.1.0-W1-111` Step 4.5，〈契約齊全的定義〉六條逐條紀錄在該票）：

| 條目 | 結果 | 可否被畫面票引用 |
|------|------|----------------|
| 4.52 `ReferenceChips`（5.20） | 第 2–6 條通過；第 1 條餘兩格待決：(1) 正向檔多值欄位的加入與移除寫法（序列內附加與刪除、純量轉清單、移除到剩一筆或零筆、重複值），待 SPEC-009 v1.10；(2) 回饋契約〈等待與結果〉的 `partiallyWritten` 呈現（`1.1.0-W1-111` Step 4.5 第 2 項，落於 4.48，排在 v1.10 之後）。兩格共用同一個重驗閘 | 否，v1.10 與第 2 項皆落地後重驗第 1 條 |
| 4.53 `AppCheckboxGroup`（5.21） | 六條通過（`AppCheckboxGroup` 的欄位皆為單檔寫入，FR-09 無多檔） | 可 |
| 4.43 `AppCheckbox` 的 `locked`／`enabled`（1.148 修改） | 六條通過 | 可 |

**1.149 的重驗結果**（`1.1.0-W1-111` Step 4.5 第 2 項）：

| 條目 | 結果 | 可否被畫面票引用 |
|------|------|----------------|
| 4.52 `ReferenceChips`（5.20） | 1.148 的兩格待決已解除：正向檔多值寫法依 SPEC-009 v1.10（F1–F4 用戶裁定 2026-11-13），`partiallyWritten` 呈現落於 4.48「部分寫入」列。重驗第 1 條通過，六條通過 | 可 |
| 4.48 `FieldBlock` 的「部分寫入」（1.149 修改） | 六條通過 | 可 |
| 4.51 `WriteLogRow` 的〈同批檔案〉與部分寫入（1.149 修改） | 六條通過 | 可 |

**1.150 的重驗結果**（`1.1.0-W1-111` Step 4.5 第 3 項，破洞報告的編輯入口）：

| 條目 | 結果 | 可否被畫面票引用 |
|------|------|----------------|
| 4.40 `ListRow.item` 的 trailing 改為接受 `ButtonRow`（1.150 修改，元件契約變更） | 六條通過（條文依 `component-contract-design`〈契約齊全的定義：六條〉）。(1) 欄位表無空白、無佔位標記：變體、slot 契約、尺寸、i18n 朗讀、測試點都補了可修正破洞項的形態。(2) 破洞報告列內「列本體與兩個次要操作」的排列關係，只由 5.14 `ListRow` 承載，兩鈕之間的排列由 5.8 `ButtonRow` 承載，不分屬兩個容器。(3) 5.14 排列不變式三項齊全，此情形的空間不足策略非空（見〈可修正破洞項的寬度核對〉）。(4) 最長測試文案為具體 key：`editFieldsAction`、`openSourceFileAction`（en `Edit fields`、`Open Source File`）。(5) 無障礙：兩鈕各為一個按鈕節點，焦點路徑為列本體 → 編輯欄位 → 開啟原始檔。桌機操作機制與回饋契約由子件 4.4 承載。編輯欄位的按下確認在本地即時成立，等待與結果為 jump，屬本地即時類（成功為可見頁更換；失敗、逾時、服務不可用依兩軸判定不可能發生，同 `tree`）。開啟原始檔四段不變。(6) 關機判定一則：「不渲染入口」以缺席表示，不設 disabled 狀態，依據為 SPEC-001 §5「入口出現在修不好的項目上會誤導使用者」 | 可 |
| 4.34 `ButtonRow` 新增 `wrap` 參數與 `ListRow.item` 用法（1.150 修改） | 六條通過。(1) 變體表、狀態矩陣來源欄、slot 契約（`wrap` 列；`alignment` 補 `ListRow.item` trailing 用 `end`）、尺寸契約（含父寬小於固有寬時維持一列，以 `RenderFlex` 的 debug 期溢位回報揭露、不另做自訂回報；release 不記）、組合規則（可放入的容器）、測試點（受限父格位下傳與不傳的 E1 對照）補 `wrap: false`，無佔位。(2) 用途與總表同步；`ListRow.item` trailing 內兩鈕的排列只由本容器承載。(3) 5.8 排列不變式三項齊全；子件上限 3，`wrap: false` 的空間不足策略為「不觸發，前提由宿主保證」，核對見 5.14。(4) 無自有文字，子件文案見 4.40 列。(5) 無自有互動；朗讀與焦點依子件閱讀順序。(6) 關機判定一則：`wrap: false` 不設截斷或換行退路，依據為 5.14「換行破壞 `item` 固有兩行高」，宿主寬不足屬契約互斥 | 可 |
| 4.52 `ReferenceChips` 使用處補 UC、EVT 的 `source_proposal`（SPEC-009 v1.11） | 六條通過：兩欄位與 SPEC `source_proposal` 同為多檔寫入，回饋契約與 `partiallyWritten` 呈現沿用既有條文，不新增狀態 | 可 |

#### 4.0.10 定位提示（locate）的容器執行約定（提案）

> §1〈回饋通道子表〉locate 列把「高亮 token 與時長」交由第 4 章對應容器條目定義，SPEC-003 §2.2「系統層通知」點擊導向列引用同一列；4.18／4.21／4.23 各以「機制依 §4.0.10」回指本節（4.18 為場景 c 的容器分工，4.21 為焦點移入，4.23 為 0.1 無場景、後續版本適用）。本節定一次作法，容器條目的 locate 列只寫「依 §4.0.10」與自己的場景、目標與分工，不重述機制。

| 項目 | 值 |
|------|-----|
| 執行端 | 持有目標所在 `ScrollController` 的容器：一維捲動為 4.30 `Panel.scrollable`（0.1 定位場景涉及的 `scroll-gaps-sections` / `scroll-traceability-tree` / `scroll-tickets-topics` 等錨點的持有者）或 4.36 `DataTable`；二維為 4.37 `MatrixGrid` / 4.38 `SwimlaneGrid`。被定位的子件（4.40 `ListRow.item` 等）只依傳值渲染高亮，不捲動、不持有定位狀態（§2 頁面狀態保留） |
| 觸發者 | 頁面層（§2 過渡提示觸發點：呼叫端）於 `ref.listen` 收到定位事件後，以目標 key 呼叫容器的定位入口；0.1 事件來源為 `ScanNotifier.activated`（SPEC-003 §2.2「點擊通知的導向」列與 §3.5「系統通知本體」「SnackBar 檢視動作」兩列）與破洞項帶目標 jump（SPEC-003 §3.4〈帶目標跳入〉、§3.5 事件類列，1.35 新增）；容器不自行決定何時定位 |
| 捲動方式 | 一律即時定位（`ScrollController.jumpTo` 或 `Scrollable.ensureVisible` 帶 `Duration.zero`），不用 `animateTo`（SPEC-003 §3.1 動畫提示「矩陣 → 泳道的定位」：定位是導航結果不是動畫，長內容上的動畫捲動中途無法斷言）；對齊以目標 rect 與 viewport 有交集即止，目標已在 viewport 內則 offset 不變；虛擬化列表以列索引 × `itemExtent` 計算 offset（`ensureVisible` 對未建構列無效） |
| 高亮 token | 目標子件底色 `AppColors.surfaceIconTint`（與 4.37 列高亮、4.9 目前專案項同一 token，語意為「被指出的那一列」），圓角同子件既有 hover 區；文字色不變（`textPrimary` / `surfaceIconTint` 對比已於 §4.0.2 驗證）；無入場動畫（離散出現，與 SPEC-003 §3.1「矩陣格的選取標記出現」同理） |
| 高亮時長 | 適用範圍為場景 a、d、e（有短暫高亮者；場景 b 的高亮為 `laneHighlight` 持續性標記、場景 c 不高亮，兩者不適用本列）。機制非數值：自焦點移入被定位項起，至焦點離開該項或任一指標按下為止；不新設 `Motion` token（SPEC-003 §2.1 無對應時限；若 PM 要求數值化時長，由 UX 審查補 token 後改本列）；§1 子表與 SPEC-003 §2.2 的「短暫」於 0.1 即指此焦點綁定機制 |
| 輔助技術 | 焦點移入被定位項（§1 子表 locate 列）；該項為 `Semantics.button` 者由既有 label 朗讀，高亮本身不另播報、不另組字 |
| 定位失敗 | 目標不存在（所在分節收合中、專案已切換、結果已清空、新一輪掃描已開始）→ 只切頁、不捲動、不高亮、不拋錯（SPEC-003 §2.2 點擊導向列末兩句）；定位不得改變展開集合（收合中的分節不自動展開） |
| 減少動態效果 | 無影響：本節無動畫，`jumpTo` 本身即瞬間（SPEC-003 §2.1） |
| 0.1 場景 | (a) 系統通知點擊／`viewGapsAction` → 第一個分節的第一個 `card-gaps-<itemId>`：4.30 `Panel.scrollable` 執行捲動，目標位於 4.41 `Section.collapsible` 內，4.40 `ListRow.item` 依 `isLocated` 渲染高亮；(b) 矩陣 → 泳道 → 該格對應的泳道列：4.38 `SwimlaneGrid` 執行 `jumpTo`，高亮由 `laneHighlight`（選取 domain）承載、為持續性標記非短暫高亮；間接依賴格的目標為來源 X 列欄號最小的節點（SPEC-001 §1），4.38 以 `locateColumn` 另做水平 `jumpTo`（1.92 起，`0.5.0-W1-114.24`）；(c) 樹節點展開後的子項：4.39 `Tree` 決定目標（子層第一列）、4.30 執行最小捲動，不高亮（焦點停在展開器，SPEC-003 §3.3 未移焦點，高亮無焦點承載者）。(d) 破洞項（指向 ticket）→ Ticket 清單目標票（SPEC-003 §3.4〈帶目標跳入〉）：4.36 `DataTable.virtual` 以列索引 × `itemExtent` 捲動（主題模式為 4.30 `scroll-tickets-topics`，所在主題節收合時由頁面層先展開——此為 SPEC-003 明訂的例外，不適用本表「定位失敗」列的「不自動展開」），4.35 `TableRow.ticket` 依 `isLocated` 高亮；(e) 事件類破洞項 → UC Flow 事件流小表的事件列（SPEC-003 §3.5）：4.36 步驟表以 `scroll-ucFlow-steps` 捲動至 `appendix` 內目標列，4.35 `TableRow.eventFlow` 依 `isLocated` 高亮。(g) flow 類破洞項（flow 各子類，帶 step id）→ UC Flow 步驟表的出錯步驟列（SPEC-001 §5〈破洞項的主操作與次要操作〉flow 類，用戶裁決 J2；`0.5.0-W1-114.23`）：4.36 步驟表以 `scroll-ucFlow-steps` 捲動至目標列，4.35 `TableRow.step` 依 `isLocated` 高亮；EVT-CORPUS-004 無 step id 時不定位、不高亮。(d)(e)(g) 的高亮時長同場景 a。(f) 由 UC Flow domain 欄 jump 進入 Domain 視圖 → 該 domain 列首（SPEC-003 §3.1〈生命週期〉「由 jump 帶 domain 進入」列，`0.1.0-W3-335.38` S-20）：矩陣模式由 4.37 `MatrixGrid` 執行 `jumpTo`（列高亮持續性標記，同場景本容器既有列高亮機制，非短暫高亮）；泳道模式由 4.38 `SwimlaneGrid` 執行 `jumpTo`（`laneHighlight` 持續性標記，同場景 b）。搜尋命中列在 0.1 為子集重建（SPEC-003 §3.4 搜尋列），不是定位場景 |

#### 4.0.11 終端回饋元件的元件層回饋日誌

> 依方法論〈元件層回饋日誌（觀測對偶）〉：終端回饋元件（使用者可見的最末端載體）須在元件內部記錄顯示、靜默早退、使用者互動三類時刻，作為不變式 INV-FEEDBACK-001（SPEC-003-interaction-response.md〈不變式 INV-FEEDBACK-001〉節）的觀測面。本節承接該條款於本專案的落地狀態，不新增元件契約欄位，各元件條目「回饋契約」子節的既有欄位（反應／通道等）不因此改寫。

本專案 0.1 唯一的終端回饋元件為 4.26 `AppSnackBar`（結果通知層載體，見 §1 子表「等待與結果」列）；`0.1.0-W3-165` 已於元件內部（`lib/components/app_snack_bar.dart`）加入下列三類記錄：

| 時刻 | 本專案落地 |
|------|-----------|
| 顯示發生 | `show` 呼叫時記錄變體（`plain` / `withAction`）、`message`、停留時長、`actionLabel`（如適用）；請求識別（`showId`）、發起者（`origin`）、級別等仲裁欄位，以及 preempted／yielded／closed 事件的欄位，定義於 SPEC-003〈仲裁決策事件的七項欄位（本專案落地）〉，本節不重列 |
| 靜默早退 | `withAction` 缺 `actionLabel` 或 `onAction` 任一時的 assertion 早退路徑記錄 warning |
| 使用者互動 | `onAction` 被觸發時記錄一次 |

測試斷言以呼叫次數或結構化欄位為準，不比對中文散文字面（見 4.26 測試點子節）。日誌不取代 4.26 內容政策子節既有的版面可讀性斷言（最長測試文案、截斷處置）——兩者驗收時並行檢查，互不替代。

本節後續新增的終端回饋元件（如提示元件類型分化衍生的變體，見 `0.1.0-W3-167`）比照本節落地，不另建新節。

#### 4.0.12 暫態提示的訊息設計要求

> 適用對象：由終端回饋元件（本專案：4.26 `AppSnackBar`）承載的訊息文字，即 §1 子表「等待與結果」列第三層與「狀態變更提示」列 `denied` fallback 所顯示的內容。**本節不新增元件契約欄位**，各元件條目「回饋契約」子節的既有欄位不因此改寫；4.26 的「回饋契約」「內容政策」「i18n」三個子節於各自的引言引用本節，本節不重複列舉那些子節已填的值。
> **不適用**：持續性標示（`IssueMarker`、`Badge`）、空狀態與阻擋狀態元件（4.21／4.23）、系統通知文案（後者的 key 與內容由 SPEC-003 §2.2〈系統層通知〉「通知內容」列定，其約束來自 macOS 通知中心的呈現規則，與本節的停留時間約束不同源）。
> **哪些事件該顯示為暫態提示**不在本節：判準見 SPEC-003 §2.13。本節只回答「已判定要顯示者，那則訊息該長什麼樣」。

**設計前提**：暫態提示的停留時間是 `Motion.snackBar`（4 秒）或 `Motion.snackBarWithAction`（8 秒），到期即消失且**不可回顧**。文案必須在這段時間內被讀完並理解，讀者可能正在看畫面的其他地方、可能剛把注意力切回來。下列要求全部由此推導。

**M1 訊息成分（可機械核對）**

| 成分 | 必要性 | 內容 | 反例 |
|------|-------|------|------|
| 結果陳述 | **必要** | 已發生的事實，動詞取完成貌 | 「正在開啟…」（進行式屬第二層等待指示，不是結果通知） |
| 對象識別 | 條件必要 | 同一則訊息可能由多個對象觸發時必填，以 placeholder 帶入 | 掃描完成不指明破洞數 |
| 操作指引 | **禁止置於 `message`** | 使用者該做什麼由 `actionLabel` 承載 | 「找不到檔案，請重新掃描」（後半應為 `rescanAction`） |
| 失敗原因的技術細節 | **禁止** | 錯誤碼、stderr、堆疊——這些進 `developer.log`（SPEC-003 §2.2〈失敗可觀測〉列） | 「開啟失敗：kLSApplicationNotFoundErr」 |
| 檔案路徑、逐項明細 | **禁止** | 屬 SPEC-003 §2.13 T3 判是的內容，該事件本就不該用暫態提示 | 「已開啟 /Users/…/SPEC-004.md」 |

**核對方式**：對每個 i18n key 的每個語系值，逐項比對上表五列。「操作指引」與「技術細節」兩列為禁止項，命中即違反；「結果陳述」為必要項，缺席即違反。

**M2 長度與版面保障**

| 項目 | 要求 |
|------|------|
| 行數上限 | 2 行（4.26 內容政策子節既有值），超出末行截斷 |
| 核對對象 | 每個 key 的**全部語系**取最長值，在 `kMinWindowSize` 與 `kDesignSize` 兩種測試尺寸下皆須在 2 行內完整顯示，不觸發截斷 |
| 觸發截斷時的處置 | **改寫文案，不放寬行數上限**——上限放寬會使停留時間不足以讀完 |
| 版面保障 | 依 `ux-design-evaluation` skill 的〈按鈕級回饋〉「關鍵回饋文字要有版面保障」（以標題文字引用，不重述）。本專案的具體形態：`withAction` 變體內訊息與動作競爭同一列寬度時，**動作 label 先讓步**——4.26 內容政策子節既有的動作 label「不換行、截斷」不得使訊息被壓縮，兩者同時超長時以縮短動作 label 的文案解決 |

**為何以「全部語系的最長值」為核對對象**：截斷是 flex 寬度競爭的結果，只驗來源語系（繁中）會漏掉英文——本專案兩個語系的同一則訊息長度差可達兩倍（如 `externalOpenFailedMessage`：「無法以系統預設方式開啟」10 字 vs 「Could not open with the default application」42 字元）。

**M3 placeholder 的型別與位置**

| 項目 | 要求 |
|------|------|
| 數量上限 | 每則訊息至多 1 個 |
| 型別 | `int`（計數）或 `String`（已在 App 內顯示過的短識別，如專案名）。**禁止**檔案路徑、時間戳、錯誤碼作為 placeholder 值 |
| 位置 | 不得位於句首。句首必須是不隨資料變動的固定字，使讀者掃第一眼即知這是哪一類訊息 |
| 各語系一致性 | 同一 key 在全部語系的 placeholder 名稱與數量必須相同；語序不同不影響此項 |
| 零值處置 | 計數型 placeholder 的值可能為 0 時，須另立一個不帶 placeholder 的 key，**不得**讓訊息顯示為「偵測到 0 個破洞」 |

**零值另立 key 的既有實例**：`scanCompleteSnackbarMessage`（帶 `count`）與 `scanCompleteNoGapsSnackbarMessage`（不帶）為同一事件的兩個結局，即本項的落地形態；`scanCompleteNotificationBody` 與 `scanCompleteNoGapsNotificationBody` 同理。

**M4 失敗與成功的措辭區分**

失敗訊息與成功訊息**必須在句首即可區分**，不得依賴顏色、圖示或閱讀完整句才能判斷——本元件無變體級的成敗配色（4.26 使用 design token 子節只有單一底色），顏色不是可用的區分通道。

| 結局 | 句式 | 0.1 既有實例 |
|------|------|------------|
| 成功 | 動詞完成貌開頭，陳述已發生的事 | 「已在外部開啟」、「掃描完成，偵測到 {count} 個破洞」 |
| 失敗（找不到目標） | 以否定詞或缺席狀態開頭 | 「找不到檔案」、「檔案仍不存在」 |
| 失敗（動作無法執行） | 以「無法」開頭 | 「無法以系統預設方式開啟」 |

**兩類失敗須再分**：「找不到目標」與「動作無法執行」的後續處置不同——前者可由重新掃描或重新整理解決（故常配 `withAction`），後者是環境問題，使用者重試無效。措辭若合流為同一句式，使用者無從判斷該不該重試。

**M5 i18n key 命名**

| 規則 | 形式 | 反例 |
|------|------|------|
| 後綴 | 訊息 `*Message`、動作 `*Action`（4.0.6 既有慣例） | `snackBarText1` |
| 載體標示 | 同一語意在不同載體有不同文案時，於 key 中標示載體 | 掃描完成的 SnackBar 與系統通知共用一個 key（既有實例已分為 `scanCompleteSnackbarMessage` / `scanCompleteNotificationBody`，本規則即其固化） |
| 命名依據 | 依**事件**命名，不依觸發它的畫面或元件命名 | `gapsPageSnackbarMessage`（畫面重構後 key 名即失真） |
| 描述欄 | ARB 的 `@<key>.description` 須寫明觸發時機與所在畫面 | 描述欄留空或抄訊息本文 |

**驗收**：本節五項（M1–M5）對每個經 4.26 顯示的 i18n key 逐項成立。M1、M3、M4、M5 為靜態可讀出（讀 ARB 檔即可判定，不需執行）；M2 需渲染，其斷言併入 4.26 測試點子節既有的溢位項與最長測試文案項，**不另立測試**；覆蓋對象為**經本元件顯示的全部 key × 全部語系**，不以該子節列舉的 key 數為上界。M2 的日誌不可替代版面斷言——`0.1.0-W3-165` 落地的元件層日誌記的是「顯示了什麼」，不是「使用者讀不讀得到」（§4.0.11 同一原則）。

**新增或修改任一則暫態提示文案時，本節五項須同批核對。** 文案是 0.1 唯一沒有型別檢查也沒有編譯期徵兆的介面——ARB 值改錯不會使任何測試轉紅，除非該測試斷言的正是文案本身，而 4.26 測試點子節已明訂測試斷言以呼叫次數或結構化欄位為準、不比對中文散文字面。

### 4.1 AppText

**用途**：所有可見文字的唯一載體，依字級 token 與語意角色渲染；容器的子件清單以此具名。
**內容角色**：標題（`title` / `subtitle`）、內文（`body`）、標籤（`caption`）、數值（`mono`）、內文（`code`，供複製執行的指令）——每個變體恰一個文字 slot。
**何時不用**：文字需要可點（用 `AppButton.text` / `RelationItem` / `NavItem`）；文字是狀態或分類標記（用 `Badge`）；文字是 markdown 內文（用 `DocumentBody`）。
**出現畫面**：全部。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `title` | `AppFontSize.title`、`AppColors.textTitle`、粗體 | 單行 | 頁面標題、節點詳情主標 |
| `subtitle` | `AppFontSize.subtitle`、`AppColors.textTitle`、半粗 | 單行；恆標記 `Semantics.header`（header 語意，非副標用途） | 面板標題、格詳情卡標題、泳道面板標題、頁首畫面名（4.11）。非 header 的次要一行文字（頁首副標、選取摘要）不用本變體，改 `body` + `secondary` + `maxLines: 1` |
| `body` | `AppFontSize.body`、`AppColors.textPrimary` | 行數政策由呼叫端明示：`AppText.multiLine`（`maxLines` 必填，`null` 為無上限、真的換行）或 `AppText.singleLine`（一行省略號）；無隱含預設 | 說明、內文、列主文字；加 `secondary` 與 `maxLines: 1` 時作頁首副標（4.11） |
| `caption` | `AppFontSize.caption`、`AppColors.textSecondary` | 單行 | 欄首、小計、群組小標、次文字（頁首副標見 `body` 列，非本變體） |
| `mono` | `AppFontSize.body`、等寬字型、`AppColors.textPrimary` | 單行 | ID、路徑、版本值 |
| `code` | 同 `mono` | 換行、不截斷、可選取（內部為 `SelectableText`；可選取是本變體唯一的互動，見回饋契約）；1.143 新增（`1.0.0-W3-553.3.1`） | 使用者要複製後在終端機執行的指令（寫入清單的取回說明，SPEC-001 §12）。不用於顯示性的路徑或 ID（`mono`） |

修飾參數（非變體）：`emphasis`（粗體）、`secondary`（顏色改 `AppColors.textSecondary`）、`tone`（語意色軸，值限
`AppTextTone` 列舉——`textPrimary` / `textSecondary` / `textTitle` / `accentStrong` / `textDisabled`，一一對應同名
`AppColors` 語意色，不接受任意 `Color`）。等寬字型由 `ThemeData` 的 `fontFamily` 提供，元件內不寫死字型名（提案）。

**修飾參數優先序**：`tone` 傳入時覆蓋 `secondary` 與變體預設色；`emphasis` 與顏色軸正交、恆獨立生效。三者疊加順序：
`tone` > `secondary` > 變體預設色（`emphasis` 不參與此順序，僅另軸控制字重）。任何元件需要 `AppColors` 五個語意色以外
的文字著色時，先確認需求是否可用既有五色表達；若否，須先擴充 `AppTextTone` 列舉（同版本內同一提案一併走完，不得繞過
`AppText` 另建 `Text`）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體渲染 | 無（純顯示） | 建構 | 不適用：無自身狀態集（純顯示元件，狀態只有 enabled） | —（建構即渲染；`text` 值由呼叫端傳入，元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部；`code` 變體除外，見下列） | — | 理由：純顯示且無資料態變更——不可點、不進入 Tab 順序、狀態矩陣僅 default 一列；0.1 不提供文字選取（`SelectableText`），避免與所在列的點擊競爭手勢（提案）；文字更新需要播報時由呼叫端以 `liveRegion` 包裝（無障礙子節），非本元件的回饋事件 | — | — | 不適用（§1 子表六列皆由所屬可點元件或容器承載） | 不適用 | 規格撰寫者 |
| `code`：可互動提示、焦點、按下確認 | 使用者 | 指標形狀 `SystemMouseCursors.text`；拖曳或雙擊選取文字，選取範圍以平台選取色呈現；⌘C 複製（`SelectableText` 內建，含右鍵選單）。焦點：可取得焦點以鍵盤選取，焦點裝飾為平台游標。其餘三類（定位、狀態變更、等待與結果）不適用：選取為本地即時、無資料態變更。所在容器不得在本元件範圍內掛點擊手勢（4.51 組合規則） | 無（平台內建） | 無 | §1 子表「可互動提示」「焦點」「按下確認」三列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無任何互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（依文字內容）；置於容器的填滿格位時寬填滿父格位、高固有 |
| 最小尺寸 | 寬：一字元 + 省略號（一字元見 §4.0.3，取該變體 `text` slot 的字級：`title` 取 `AppFontSize.title`、`subtitle` 取 `AppFontSize.subtitle`、`caption` 取 `AppFontSize.caption`、`body` 與 `mono` 取 `AppFontSize.body`；`body` 未傳 `maxLines` 時超出處置為換行，不計省略號）；高：一行（§4.0.3 行高） |
| 最小命中區 | 不適用（不可點） |
| 最大尺寸 | 寬無上限（由父格位夾住）；高：`body` 依 `maxLines`，其餘一行 |
| `kMinWindowSize` 下的行為 | 維持（約束由容器決定，§4.0.3） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `text`（`title`） | 否 | 1 | 截斷 | `TestCopy.nodeTitle`；`TestCopy.longToken` |
| `text`（`subtitle`） | 否 | 1 | 截斷 | `TestCopy.ucName`；`TestCopy.longZh` |
| `text`（`body`，`multiLine`） | 是 | `maxLines`（必填；`null` 無上限） | 換行；有 `maxLines` 時末行截斷 |
| `text`（`body`，`singleLine`） | 否 | 1 | 截斷 | `notFrameworkProjectExplanation`（zh 較長）；`TestCopy.longEn` |
| `text`（`caption`） | 否 | 1 | 截斷 | `noGapsScanScope`（en 較長）；`TestCopy.longZh` |
| `text`（`mono`） | 否 | 1 | 截斷 | `TestCopy.filePath`；`TestCopy.longToken` |
| `text`（`code`） | 是 | 無上限 | 換行，不截斷（指令被截斷後複製得到的是錯的指令）；`TestCopy.longToken` 這類無斷點字串依字元斷行 | `git cat-file -p` 加 40 字 sha 加 `TestCopy.filePath` 的組合；`TestCopy.longToken` |

呼叫端不得傳入比本表更寬鬆的處置（`softWrap` / `overflow` 不開放為參數）；`body` 只開放 `maxLines`，且必須以 `AppText.multiLine` 或 `AppText.singleLine` 明示（`0.5.0-W1-508.1`）。截斷責任歸屬：由呼叫端承擔，元件不依內容自行猜測；預設建構子已於 `0.5.0-W1-508.8` 移除，未明示行數政策的呼叫在編譯期報錯；僅 `multiLine(maxLines: null)` 用 `clip` 真的換行。

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
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序（非互動）；輔助技術依閱讀順序讀到。`code` 例外：進入 Tab 順序，取得焦點後以 Shift＋方向鍵選取、⌘C 複製 |
| 對比 | 依 §4.0.2 表 1：`textTitle` / `textPrimary` / `textSecondary` 對 `surfaceBase` 分別 17.20 / 5.79 / 4.71:1，皆通過；`caption` 與 `secondary` 修飾只得置於 `surfaceBase`（帶色表面規則），呼叫端置於帶色表面時改用預設字色 |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染六個變體 × `emphasis` / `secondary` 修飾
- [ ] `code` 以 `TestCopy.longToken` 渲染於 212 寬格位：換行、無省略號、無溢位；全選後複製得到的字串等於 `text`；對照：`mono` 同文案出現省略號
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

**用途**：語意圖示（資料夾、全部導覽圖示、展開箭頭、外開箭頭、損壞、搜尋、關閉）；尺寸只取具名階。
**內容角色**：標籤（圖形化）。
**何時不用**：圖示本身可點（包進 `AppButton.text` 或所屬元件）；圖示承載展開狀態（用 `ExpanderIcon`）；圖示承載問題標記（用 `IssueMarker`）。
**出現畫面**：殼、§3、§4、§5、§6、§7。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| 不適用 | 尺寸階（`sm` / `md` / `lg`）與顏色為參數，非變體（原子元件，同一語意無行為差異） | | |

圖示來源：Material Icons（`IconData`；沿用 `lib/assembly/shell.dart` 既有慣例；畫布內聯 SVG 為產生器輸出，不視為圖示集決策，提案）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依 `icon` / `size` / `color` 渲染 | 無 | 建構 | 不適用：純顯示元件，無自身狀態集 | —（建構即渲染；三個參數由呼叫端傳值，元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且無資料態變更——原子圖示不可點、不進入 Tab 順序、無狀態集；可點需求由所屬元件（`AppButton.text` / `NavItem` / `IssueMarker` 等）承載，回饋依所屬元件的回饋契約，本元件不重述 | — | — | 不適用（由所屬元件承載） | 不適用 | 規格撰寫者 |

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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 水平實線 | 無 | 建構 | 不適用：純顯示，無狀態集 | —（建構即渲染；無 slot、無 provider） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且無資料態變更——裝飾性分隔線，排除於語意樹（`ExcludeSemantics`）、無互動、無狀態集；群組分隔的語意由群組小標或 header 承載（無障礙子節） | — | — | 不適用（無互動，無承載者） | 不適用 | 規格撰寫者 |

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
**出現畫面**：§1–§7、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `primary` | 底 `AppColors.accent`、字 `AppColors.surfaceBase` | 無 | 前進／主要動作：選擇資料夾、開始載入、重新整理（`MissingSourceState`）、前往破洞報告、前往追溯視圖 |
| `secondary` | 底 `AppColors.surfaceBase`、邊框 `AppColors.borderStrong`、字 `AppColors.textPrimary` | 無 | 取消、返回、重新掃描、開啟原始檔、檢視關聯、檢視詳情、在泳道中檢視、開啟 docs 目錄 |
| `text` | 無底無框、字 `AppColors.accent`；可帶 leading `AppIcon` | 無 | 低強調：浮層「選擇其他」、格詳情卡「關閉」 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| enabled | 依變體 | 點選（指標 / Space / Enter） | `enabled` 為 `true`（預設） | 呼叫端改 `enabled` → disabled | —（預設狀態，建構即進入；`enabled` 由呼叫端傳值，元件不 watch，§2） | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |
| disabled | 依 §4.0.1；`disabledReason` 以 `AppText.caption` 顯示於 label 右側（同列常駐文字，SPEC-003 §2.2）；`reasonShownNearby` 為 `true` 時不顯示 caption、不加間距（原因由同區常駐文案承載，見下方〈停用原因由同區文案承載〉） | 無 | `enabled` 為 `false`（此時 `disabledReason` 須為非空字串，或 `reasonShownNearby` 為 `true`） | 呼叫端改 `enabled` → enabled | 資料態：停用場景兩個——(1) 4.24 `LoadingState` 取消鈕，呼叫端 provider 的「取消進行中」欄位（SPEC-003 §2.5 C2）；(2) §3.6「圖不可用」列的重新掃描鈕 `action-domain-rescan`，`scanRoundProvider` 為 `ScanRoundRunning` 時停用（`0.5.0-W1-486.2`）。兩者皆以 `reasonShownNearby: true` 宣告原因由同區文案承載（取消鈕：鈕文案 `cancelInProgressAction`；重新掃描鈕：列內 `domainGraphUnavailableScanning`）。取消進行中的欄位：破洞掃描為 `GapReportScanning.isCancelling`（`lib/screens/gap_report/gap_report_models.dart`，由 `gapReportProvider` 持有，`lib/screens/gap_report/gap_report_provider.dart`）；Domain 視圖為 `domainViewStateProvider` 的 `DomainLoading.isCancelling`（`lib/app/domain_view_providers.dart`；取消經 `domainViewLoaderProvider` 的 `cancelLoading()`）；Ticket 清單無載入態（`TicketListState` 只有 `TicketsProjectUnready`／`TicketsEmpty`／`TicketsReady`），不渲染本列 | 本地即時（C2：按下取消後 `Motion.feedback` 內即轉 `false`，不等資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |

無 loading 狀態：等待指示為畫面級（SPEC-003 §2.2），按鈕內不放 spinner。取消鈕按下後的「取消中」由 4.24 `LoadingState` 以 `enabled=false` + label 換文案承載，不是本元件的狀態。

**停用原因由同區文案承載**（`0.5.0-W1-503` 用戶裁決 A）：停用原因已由按鈕所在區塊的其他常駐文案說明時，呼叫端傳 `reasonShownNearby: true` 取代 `disabledReason`，避免同區重複同一說明。適用條件兩項，皆須成立：

1. 承載原因的文案與按鈕同區、常駐可見（非 tooltip、非暫態提示）；
2. 該文案在朗讀順序上與按鈕相鄰（同一語意區塊內，或朗讀順序緊鄰按鈕節點）。

不適用：SPEC-003 §2.2 FR-06 合法形態 (b)「未接線動作渲染為停用」一律以 `disabledReason` 說明，不得以本旗標省略。`disabledReason` 傳空字串不合法——空字串不構成原因，且會使停用分支渲染空 caption 與空 hint；不提供原因時必須以本旗標顯式宣告。

**開啟時取得焦點**（`autofocus`，1.136）：參數 `autofocus: bool`，預設 `false`。為 `true` 時，按鈕掛載後的第一個 frame 取得焦點（`primaryFocus` 落在本按鈕、渲染 focused 態），直接交給 Flutter 按鈕內建的 `autofocus` 承載，不另建焦點管理。按鈕已掛載後把值由 `false` 改為 `true` 不會搶焦點；只有掛載當下為 `true` 才生效。

| 項目 | 值 |
|------|-----|
| 使用場景 | 面板開啟時焦點移入面板：偏好設定面板 `action-preferences-close`、鍵盤快捷鍵面板 `action-shortcuts-close`（SPEC-003 §3.8、§3.10「焦點移入面板」） |
| 呼叫端約束 | 同一個面板或浮層內最多一顆按鈕傳 `true`；頁面層按鈕不傳（SPEC-003 §2.10 App 啟動不預設焦點） |
| disabled 時 | `enabled` 為 `false` 時不取得焦點（停用按鈕不可聚焦） |
| 測試點 | 掛載含 `autofocus: true` 按鈕的面板後 pump 一個 frame，該按鈕 `Focus.hasFocus` 為 `true`；不傳時為 `false` |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時（Material 內建態隨輸入即時出現），不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` / `ButtonStyleButton` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；disabled 時無 hover overlay | 無（Material 內建，無專案 token） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused：`AppColors.accent` 外框、圓角同元件）；位於 Tab 順序的內容區段（SPEC-003 §2.10） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | enabled → focused / focused → enabled | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onPressed` 恰一次；disabled 時無反應、無 SnackBar（SPEC-003 §2.2 FR-06 合法形態 b） | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | enabled → pressed → enabled | 反應／時限：UX 審查（SPEC-003 §2.2）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載：0.1 無定位至按鈕的場景，`ButtonRow` / `SwitcherOverlay` 為非資料視圖容器，不執行 scroll-into-view | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層 `ref.listen` 比對新舊值後改 `enabled` 傳值） | 視覺依 §4.0.1 disabled（`textDisabled`、無 hover overlay）+ 同列常駐 `disabledReason`；語意樹 `enabled` 旗標同步、`Semantics.hint` 附 `disabledReason`（無障礙子節） | 無（SPEC-003 §2.5 C2 為即時轉態，不 cross-fade） | 取消鈕：按下後 `Motion.feedback` 內轉 `enabled: false`（SPEC-003 §2.5 C2）；重新掃描鈕：輪次轉為進行中時隨 `scanRoundProvider` 即時轉態，不設時限 | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用；不升級系統通知） | enabled → disabled / disabled → enabled | 反應／時限：UX 審查（SPEC-003 §2.2、§2.5 C2）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層（服務受理）與第三層（event 效果）不由本元件承載，皆委派呼叫端（4.24 `LoadingState`／4.26 `AppSnackBar`），無 loading 狀態。服務類型：本元件泛用於全部四類（本地即時／延遲觸發／短暫非同步／長時操作，依呼叫端觸發的動作而定）；第一層本身不隨服務類型變動（SPEC-003 §2.12）。成功：呼叫端依所掛服務類型呈現（如 4.24 載入完成或 4.26 成功 `AppSnackBar`；本地即時類無獨立呈現，狀態轉換本身即結果）；失敗：同（呼叫端依服務類型呈現，如 4.26 失敗 `AppSnackBar`）；逾時：同；服務不可用：同。輸入阻擋範圍：不適用於本元件——由呼叫端依所掛服務類型決定（SPEC-003 §2.12 輸入阻擋範圍表：本地即時／短暫非同步不阻擋；長時操作由 4.24 取代頁面內容使觸發入口消失，非本元件自我停用）。重複觸發防護：不適用於本元件——依不變式 INV-FEEDBACK-001，本元件每次按下皆無條件發出 pressed 態並呼叫 `onPressed`，防抖／節流／冪等的判斷與執行一律在服務層；`enabled: false` 僅用於「操作本身不可用」（如取消已按下，SPEC-003 §2.5 C2），不得以服務側防抖為由停用（SPEC-003 §2.12 規格層判準 2） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12）；通道：規格撰寫者 |

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
| `disabledReason` | `String?` | `enabled` 為 `false` 且 `reasonShownNearby` 為 `false` 時必填，須為非空字串 | 呼叫端（i18n key 取值） |
| `reasonShownNearby` | `bool` | 否（預設 `false`）；為 `true` 時須符合〈停用原因由同區文案承載〉兩項適用條件 | 不適用 |
| `semanticExpanded` | `bool?` | 否（`null` 時不附加該旗標） | 不適用 |
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
| `label` | 呼叫端傳入（既有：`chooseWorkspaceFolder`、`cancelLoadingAction`、`cancelScanAction`、`cancelInProgressAction`、`startLoadAction`、`backAction`、`refreshAction`、`rescanAction`、`openSourceFileAction`、`openDocsFolderAction`、`viewRelationsAction`、`viewSchemaDetailAction`、`gotoGapsReportAction`、`gotoTraceabilityAction`、`switcherChooseOtherFolder`、`gotoDomainViewAction`；`cellDetailCloseAction`、`cellDetailViewInSwimlaneAction`；`useBuiltinSchemaAction`（`action-domain-degraded-view`，§4.0.6 新 key 總表 1.37）、`gotoTicketsListAction`（§3 常駐說明列，§4.0.6 新 key 總表 1.38）；`backToDomainAction` 已隨 `action-ucFlow-back-to-domain` 移除，`0.1.0-W3-335.37` R7） |
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
| 狀態變化播報 | `enabled` 改變時語意樹 `enabled` 旗標同步；`disabledReason` 以 `Semantics.hint` 附於同一節點；`reasonShownNearby` 為 `true` 時不設 hint，原因由朗讀順序相鄰的同區文案節點朗讀；`semanticExpanded` 非 `null` 時附加 `expanded` 旗標於同一節點（供 4.23 `BlockedState.withDetail` 檢視詳情鈕標示展開狀態，取代呼叫端外部包裹） |
| 非視覺替代訊號 | 變體差異不承載語意（皆為動作），故顏色非唯一訊號；disabled 由 `enabled` 旗標與常駐文字承載 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（SPEC-003 §2.10 內容區段）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2：`primary` 字 `surfaceBase` / `accent` 5.84:1、`secondary` 與 `text` 字 `textPrimary` / `surfaceBase` 5.79:1、`disabledReason` `textSecondary` / `surfaceBase` 4.71:1，皆通過；disabled 的 label 與 icon `textDisabled` 3.06:1 屬非作用中元件豁免（表 2） |

#### 測試點（widget test）

- [ ] 一支測試逐一渲染三個變體 × enabled / disabled（disabled 含 `disabledReason`）
- [ ] `reasonShownNearby: true` 停用時：無 caption、無間距、無 hint；停用且 `disabledReason` 為空字串或 `null` 而未宣告旗標時 assert 觸發
- [ ] 兩個停用場景（4.24 取消鈕、`action-domain-rescan`）：承載原因的文案節點存在，且與按鈕同一語意區塊或朗讀順序相鄰
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
**出現畫面**：§1–§7、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `count` | 數字；預設 tone `negative` | 無 | 損壞計數（作為 `IssueMarker.damagedDetail` 的內部 slot）；寫入清單失敗計數（4.7 `NavItem.action` 的 `badge` slot，`badge-writeLog-failure-count`，1.143） |
| `status` | 文字；tone 依狀態值對映（下表） | 無 | 票列狀態、節點 draft chip、樹列狀態 |
| `type` | 文字；tone `neutral` | 無 | PROP / SPEC / UC / Ticket 型別 |
| `category` | 文字；tone 由呼叫端指定 | 無 | 破洞類別（畫布：資料損壞 `negative`、追溯缺口 `warning`、圖結構 `neutral`）；4.19 `RelationItem` 的 proposed 邊標記（tone `warning`，`0.5.0-W1-103.1` 裁決 I2）；§10 事件列變動欄（`historyEventAdded` tone `positive`、`historyEventRemoved` tone `negative`，4.35 `historyEvent`）；§10 淺層 clone 標示（tone `warning`，`badge-history-shallow-clone`，置於 `BadgeRow`；與 RelationItem proposed 標記同為「未定或不完整」語意，故同取 warning） |
| `event` | 文字（含 `emits` / `consumes` 前綴）；tone 預設 `accent`，呼叫端可改 `negative` | 無 | 事件標籤 |
| `tag` | 文字；tone `neutral` | 無 | domain: schema、N 個 FR |
| `legend` | 符號 slot + 文字，無底色；符號色依關係種類 | 無 | 矩陣與泳道圖例 |
| `health` | 數字；tone `negative` | 無 | 專案健康計數（`badge-switcher-health-<index>`） |

**tone（語意色參數，非變體）**：`neutral`（底 `AppColors.surfaceChip`、字 `textPrimary`）/ `accent`（底 `surfaceIconTint`、字 `accentStrong`）/ `positive`（底 `surfaceChip`、字 `success`；提案，畫布只有 inline 形態）/ `warning`（底 `warningSurface`、字 `warning`）/ `negative`（底 `errorSurface`、字 `error`）。
**外觀由容器格位決定（§3.7 第 5 項）**：置於 `TableRow` 格位時為 inline（無底色、只取 tone 字色）；其餘為 chip（底色 + `Radius.sm`）。
**`status` 的 tone 對映（提案；畫布：draft / pending 為 warning，completed 為 positive）**：`completed` / `confirmed` / `approved` / `implemented` / `baseline` → `positive`；`draft` / `pending` / `review` / `in_progress` → `warning`；`rejected` / `superseded` / `revised` 與未列值 → `neutral`。對映表為元件常數，呼叫端不覆寫。原 `secondary` tone（底 `surfaceChip`、字 `textSecondary`）於 `0.1.0-W1-060` 刪除：`textSecondary` / `surfaceChip` 4.02:1 未達 AA，改 `textPrimary` 後與 `neutral` 無差異（§4.0.2 帶色表面規則）；終止類狀態與未列值同以文字承載語意，不另設色。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體 / tone / 格位 | 無（非互動；點擊不產生反應且不呈按鈕形態，SPEC-003 §3.7） | 建構 | 不適用：純顯示元件，無自身狀態集 | —（建構即渲染；`label` / `count` / `tone` 由呼叫端傳值，值變更由所在列重建，元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且明訂無互動——點擊無反應、無 pressed 態、元件樹無 `InkWell` / `ButtonStyleButton`（SPEC-003 §3.7 健康徽章斷言，全變體適用）；`status` / `count` 值變更由所在列重建，不播報（無障礙子節），變更的回饋由所在容器或畫面級狀態轉換承載；可點的計數標記改用 `IssueMarker.damagedDetail`（反例） | — | — | 不適用（由所在列／容器承載） | 不適用 | 規格撰寫者 |

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
| `testKey` | `Key?` | health 必填（`badge-switcher-health-<index>`）；§10 淺層 clone 標示必填（`badge-history-shallow-clone`） | 不適用 |

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
| `damagedDetail` | `AppIcon`（warning 圖示，`AppColors.error`）+ 可選 `Badge.count` + 可選說明 `AppText.caption` | 點擊 → jump 破洞報告：工具列計數 `badge-tickets-corrupted`；票列末欄圖示 `badge-tickets-corrupted-<ticketId>`（不觸發開票 `card-tickets-<ticketId>`、不定位破洞項，`0.1.0-W3-335.47` D2）；節點詳情欄位級 `action-nodeDetail-goto-gaps` | 詳情損壞：工具列右側計數、票列末欄圖示、節點詳情欄位級標示 |
| `gap` | 虛線框 `AppColors.error` + 文字 `gapMarkerLabel`（`AppColors.error`） | 點擊 → jump 破洞報告（`badge-traceability-broken-<nodeId>`，`<nodeId>` 為缺下游的父節點；SPEC-003 §3.3，用戶簽核 2026-09-14） | 追溯缺口：每個缺下游的父節點一個，置於該父節點之下的缺口列 trailing（4.39） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體 | 點選 | 建構（存在即代表有問題） | 由呼叫端移除（問題消失） | 資料態：存在與否由呼叫端依所在畫面的損壞／缺口資料決定——追溯視圖（`gap`）為 `traceabilityStateProvider`（`lib/screens/trace/trace_providers.dart`）；Ticket 清單為 `ticketListStateProvider` 的 `TicketsReady.corruptedCount` 大於 0（`lib/screens/ticket_list/ticket_list_providers.dart`）；節點詳情的 `damagedDetail` / `damagedEdge` 隨 SPEC-001 §6「部分損壞」在 0.x 不可達而不渲染（恢復條件見 SPEC-001 §6，`1.1.0-W3-656`）。元件本身不 watch，只接收 `count` / `explanation` / `child` 傳值（§2） | 等確認才顯示（損壞與缺口為解析完成後的資料態，載入中不渲染本元件；§2 樂觀更新政策：0.1 無樂觀操作） |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：跳轉破洞報告恆可用（SPEC-001 §3、§4、§6 退出路徑）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；三變體皆可點，無 disabled | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；位於 Tab 順序的內容區段（SPEC-003 §2.10）；朗讀「{變體標籤}，`Semantics.button`」（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default → focused / focused → default | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行 jump 至 `nav-page-gaps`，`returnTo` 設為來源畫面（SPEC-003 §3.3、§3.4、§3.6） | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | default → pressed → default（隨後由呼叫端切頁） | 反應／時限：UX 審查（SPEC-003 §2.2）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載：本元件是跳轉的**來源**而非被定位目標；跳轉後在破洞報告的定位（scroll-into-view 至 `card-gaps-<itemId>` + 高亮）由該畫面的資料視圖容器執行（SPEC-003 §2.2「系統層通知」點擊導向列引用同一機制）。回到來源畫面（`returnTo`）時本元件不被定位，捲動 offset 由頁面狀態保留（§2、SPEC-003 §2.8） | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點；出現與消失隨所在列重建） | 靜態標記：出現不做閃爍或呼吸動畫、消失不做退場動畫（SPEC-003 §3.3「缺口虛線框靜態」、§3.4「損壞徽章無入場動畫」）；不播報（無障礙子節：靜態標記，隨列重建） | 無（SPEC-003 §3.3、§3.4 明訂靜態） | 無（SPEC-003 無對應時限；標記出現隨畫面級狀態轉換的 `Motion.transition` cross-fade 一併進入視野，本元件不另播） | §1 子表「狀態變更提示」列（`Motion.*` 過渡與播報皆不適用；畫面級轉換由所在畫面承載；不升級系統通知） | 不適用（無自身資料態邊：存在即有問題，消失即由呼叫端移除） | 反應：UX 審查（SPEC-003 §3.3、§3.4）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（本地導覽切換無服務受理階段），第三層即結果通知本身（jump 至 `nav-page-gaps` 的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（導覽切換，SPEC-003 §2.12 0.1 實例）。成功：jump 至 `nav-page-gaps`，`returnTo` 設為來源畫面，無等待指示（本地已解析內容）；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生，本地操作無外部等待）；服務不可用：同（不可能發生，跳轉為本機已建構頁面之間的切換，無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12）；通道：規格撰寫者 |

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
| `testKey` | `Key` | 是（`badge-tickets-corrupted` / `badge-tickets-corrupted-<ticketId>`（票列末欄，`0.1.0-W3-335.47` D2）/ `badge-traceability-broken-<nodeId>`（父節點 ID）/ 欄位級 `action-nodeDetail-goto-gaps`） | 不適用 |

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

**用途**：側欄全部導覽項，`nav-item-<destination>`（既有錨點，不改名）；`action` 變體另承載側欄底部三項（開啟面板，不屬 `AppDestination`，4.27〈側欄底部 slot〉）。
**內容角色**：動作 + 標籤（icon slot + label slot）。
**何時不用**：畫面內跳轉（`AppButton` / `RelationItem`，jump 語意）；專案切換入口（`ProjectSwitcherEntry`）。
**出現畫面**：殼。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | selected / unselected 為狀態 | 點選 → rail 切換 | 全部導覽項皆同 |
| `action` | 外觀同 `default` 的 unselected，恆不呈 selected（`isSelected` 固定 `false`，呼叫端不傳） | 點選 → 呼叫 `onTap` 開啟面板，不改變 `selectedDestinationProvider` 與 `returnTo`（SPEC-003 §3.10）；`Semantics.selected` 不設 | 側欄底部「設定」「鍵盤快捷鍵」「寫入清單」三項（testKey `nav-action-<kind>`，SPEC-003 §2.9）；「寫入清單」另帶 `badge`（見下方〈`badge` slot〉） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| unselected | 無底色；icon 與 label `AppColors.textPrimary` | 點選 | `isSelected` 為 `false` | 點選本項 → selected | 資料態：`selectedDestinationProvider`（`StateProvider<AppDestination>`，`lib/app/router.dart`）；`AppShell` watch 後以 `isSelected` 傳值，元件不 watch（§2 導覽狀態列） | 本地即時（rail 切換為本地導覽狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| selected | 底 `AppColors.surfaceIconTint`、icon 與 label `AppColors.accentStrong`、label 半粗（畫布為準；`lib/assembly/shell.dart` 的 `surfaceChip` 屬漂移，W1-005 對齊） | 點選（無狀態改變） | `isSelected` 為 `true` | 點選他項 → unselected | 資料態：同上 | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：全部導覽項恆可用（SPEC-003 §2.3）。

**`action` 變體的焦點節點**（`focusNode`，1.136）：參數 `focusNode: FocusNode?`，預設 `null`（元件內部自建）。呼叫端傳入時，本元件把它交給內部的可聚焦節點使用，不自行 dispose；FocusNode 由呼叫端建立、持有、dispose。用途是面板關閉後焦點回到開啟者（SPEC-003 §2.10「面板關閉後」列）：組裝層（`lib/assembly/shell.dart`）為 `nav-action-preferences`、`nav-action-shortcuts`、`nav-action-writeLog` 各持有一個 FocusNode，記下面板是由哪一項開啟的，面板關閉時對該節點 `requestFocus()`。由選單項或 ⌘, 開啟者不經本參數，焦點歸位由組裝層在開啟前記下的 `primaryFocus` 承載（SPEC-003 §2.10 同列），不屬本元件契約。`default` 變體可傳同一參數，但 0.7 無使用場景。

| 項目 | 值 |
|------|-----|
| 測試點 | 傳入 FocusNode 後對其 `requestFocus()`，pump 一個 frame，該 `NavItem` 渲染 focused 態且 `Focus.hasFocus` 為 `true`；元件 dispose 後傳入的 FocusNode 仍可使用（未被元件 dispose） |

**`badge` slot**（1.143，`1.0.0-W3-553.3.1`；SPEC-001 §12〈失敗計數徽章〉）：參數 `badge: Badge?`，預設 `null`，只接受 `Badge.count`（tone `negative`），只用於 `action` 變體的「寫入清單」項（`badge-writeLog-failure-count`）。值為 0 時呼叫端傳 `null`，元件不渲染徽章、不保留空位。

| 項目 | 值 |
|------|-----|
| 位置 | label 之後、列尾端對齊，與 label 間距 `Space.sm` |
| 寬度不足時 | label 先截斷，徽章維持固有寬；優先序為徽章 > label（徽章是失敗的唯一常駐訊號，SPEC-003 §2.14 列 25 留痕載體） |
| 高度 | 徽章高 ≤ 列內容高（`LayoutSize.iconLg`），不改變列高 |
| 朗讀 | 有徽章時列的 `Semantics.label` 為 `writeLogNavA11yLabel`（代入 `label` 與計數），取代單獨的 `label`；徽章本身 `excludeSemantics`，不另成節點 |
| 狀態變更 | 計數改變為離散替換、無動畫（SPEC-003 §3.12 失敗計數徽章列：驗證結果回來時立即更新）；不發播報，理由同 SPEC-003 §2.14 列 25「不送出暫態提示」，留痕由徽章本身與寫入清單承載 |
| 來源 | 資料態：Edit domain 的 session 寫入清單衍生值，組裝層 watch 後傳入，元件不 watch（§2） |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；已選項同樣有 hover（點選已選項無狀態改變，但仍為可點） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；位於 Tab 順序第二區段（全部導覽項，SPEC-003 §2.10）；朗讀 label + `selected` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | unselected / selected → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行 rail 切換：`nav-page-<d>` 成為可見頁、`returnTo` 設為 `null`（SPEC-003 §1.2、§2.3 規則 1）；點選已選項仍有 pressed 態但無狀態改變 | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | unselected → pressed → selected（本項）；selected → pressed → selected（已選項） | 反應／時限：UX 審查（SPEC-003 §2.2、§2.3）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`AppShell` 側欄 slot）：0.1 無定位至導覽項的場景——系統通知點擊導向（SPEC-003 §2.2）定位的是破洞報告內的項目，導覽項只隨 `selectedDestinationProvider` 轉為 selected | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：`AppShell` 依 `selectedDestinationProvider` 改 `isSelected` 傳值；含 SPEC-003 §2.2 系統通知導向、§2.4 jump 等非本項點選引起的切換） | selected 視覺切換（底色 `surfaceIconTint`、字與 icon `accentStrong`、半粗）；`selected` 旗標改變由輔助技術播報（原生旗標，不另組字，無障礙子節） | 無（SPEC-003 未定義導覽項選取過渡；頁面切換無轉場（`IndexedStack`，SPEC-003 §2.8），選取視覺與之同步瞬切；提案） | 無（本地即時；SPEC-003 無對應時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用；不升級系統通知） | unselected → selected（本項被選）/ selected → unselected（他項被選） | 反應：規格撰寫者（提案；SPEC-003 §2.3 只定 rail 語意，未定導覽項視覺過渡）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（本地導覽切換無服務受理階段），第三層即結果通知本身（rail 切換的狀態轉換：可見頁更換 + 本項轉 selected，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（導覽切換，SPEC-003 §2.12 0.1 實例）。成功：rail 切換為可見頁，`IndexedStack` 全部導覽頁已建構故無等待指示（SPEC-003 §2.8）；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，切換為本機已建構頁面之間，無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.8、§2.12）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，側欄內距內）；高固有 |
| 最小尺寸 | 寬：2 × `Space.md`（自身水平內距）+ `LayoutSize.iconLg` + `Space.sm` + 一字元 + 省略號（一字元見 §4.0.3，取 `AppFontSize.body`）；高：`LayoutSize.iconLg` + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`） |
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
| `label` | `String` | 是 | 呼叫端（`navDomain` / `navUcFlow` / `navTraceability` / `navTickets` / `navGaps` / `navNodeDetail` / `navHistory`；`action` 變體為 `sidebarSettingsLabel` / `keyboardShortcutsTitle` / `writeLogTitle`） |
| `isSelected` | `bool` | 是 | 不適用 |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `badge` | `Badge?`（限 `Badge.count`，tone `negative`） | 否（預設 `null`；只用於 `action` 變體「寫入清單」，見〈`badge` slot〉） | 不適用（數字為資料值） |
| `testKey` | `Key` | 是（`default`：`nav-item-<destination>`；`action`：`nav-action-<kind>`） | 不適用 |

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
| `label` | 呼叫端傳入（`nav*` key 之一；第七項 `navHistory` 於 1.131 登記，§4.0.6） |
| 帶徽章時的朗讀 | `writeLogNavA11yLabel`（1.143 登記，§4.0.6） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `AppShell`（`default`：側欄導覽 slot，數量與全部導覽項一致；`action`：側欄底部 slot，恰 3） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button` 為 `true`、label 等於 `label`、`selected` 等於 `isSelected` |
| 狀態變化播報 | `selected` 旗標改變即由輔助技術播報（原生旗標，不另組字） |
| 非視覺替代訊號 | 選取態同時以底色、字重與 `selected` 旗標承載，顏色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | Tab 第二區段（全部導覽項依序，SPEC-003 §2.10）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2（`accentStrong` / `surfaceIconTint` 通過；`textPrimary` / `surfaceSidebar` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染 selected / unselected 兩狀態
- [ ] 兩種視窗尺寸下不溢位；高不小於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en 全部 `nav*` key 皆不溢位
- [ ] 點選呼叫 `onTap` 恰一次；`Semantics.selected` 與 `isSelected` 一致
- [ ] `badge` 為 `Badge.count`（值 3）時徽章存在、朗讀為 `writeLogNavA11yLabel`；對照：`badge` 為 `null` 時無徽章節點、朗讀只有 label
- [ ] 側欄寬下 `TestCopy.longToken` label 加三位數徽章：label 截斷、徽章完整、不溢位
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 畫面內的「前往破洞報告」 | `AppButton.primary`（jump，設 `returnTo`） |
| 在導覽項上顯示非失敗類的計數（例如總寫入數） | 不顯示；`badge` 只承載需要使用者注意的失敗計數，總數在面板內可見 |
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| collapsed | 圖示 + 專案名（無專案時顯示 `projectSwitcherEntryLabel`）+ 向下箭頭 | 點選 → 展開浮層 | 浮層未展開（常態） | 點選 → expanded | 資料態：`switcherOpenProvider`（`StateProvider<bool>`，`lib/app/project_switcher_providers.dart`）為 `false`；專案名為 `currentProjectNameProvider`（同檔）；`AppShell` watch 兩者後以 `isExpanded` / `projectName` 傳值，元件不 watch（§2） | 本地即時（浮層開合為本地 UI 狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| expanded | 同上，箭頭朝上；本元件維持可見（浮層自其下方展開） | 點選 → 收合浮層 | `SwitcherOverlay` 展開中 | Esc / 點外部 / 選取專案 → collapsed（SPEC-003 §3.7） | 資料態：`switcherOpenProvider` 為 `true`（同上） | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：三個阻擋狀態下 `enabled` 恆為 `true`（SPEC-003 §2.7 浮層可用性斷言）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；三個阻擋狀態下同樣有 hover（`enabled` 恆為 `true`，SPEC-003 §2.7） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；位於 Tab 第一區段（SPEC-003 §2.10）；浮層 Esc 收合後焦點回到本元件（SPEC-003 §2.10「浮層展開時按 Esc」列）；朗讀「`projectSwitcherEntryLabel`，{projectName}」+ `expanded` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | collapsed / expanded → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行：collapsed 時 `state-switcher-collapsed` 消失、`state-switcher-expanded` 或 `state-switcher-no-recent` 出現，expanded 時浮層收合（SPEC-003 §3.7）；浮層的淡入 + 向下展開／反向收合由 `SwitcherOverlay` 承載，本元件不播 | Material 內建 ripple（浮層 `Motion.overlay` 由 4.42 `SwitcherOverlay` 承載） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | collapsed → pressed → expanded / expanded → pressed → collapsed | 反應／時限：UX 審查（SPEC-003 §2.2、§3.7）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`AppShell` 側欄頂端 slot）：0.1 無定位至本元件的場景——側欄常駐不捲動，阻擋狀態的出口按鈕開啟浮層時本元件維持可見不需定位；Esc 後焦點回到本元件屬焦點列，非 locate | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：`AppShell` 依 `switcherOpenProvider` 改 `isExpanded` 傳值、依 `currentProjectNameProvider` 改 `projectName` 傳值；含 Esc／點外部／選取專案等非本元件點選引起的收合，SPEC-003 §3.7） | 箭頭方向切換（向下 ↔ 朝上）與 `expanded` 旗標同步，旗標改變由輔助技術播報（原生旗標，不另組字）；專案名改變隨重建唸出（無障礙子節）；箭頭切換本身不做動畫，浮層的展開／收合動畫由 `SwitcherOverlay` 承載 | 無（箭頭為離散替換；SPEC-003 §3.7 動畫提示只定浮層的 `Motion.overlay`，未定入口箭頭；提案） | 無（本地即時，與浮層狀態同步瞬切；SPEC-003 無對應時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用；不升級系統通知） | collapsed → expanded / expanded → collapsed | 反應：規格撰寫者（提案；SPEC-003 §3.7 只定浮層轉換，未定入口視覺）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（開合浮層無服務受理階段），第三層即結果通知本身（浮層出現／收合的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（浮層開合，性質同 SPEC-003 §2.12 0.1 實例「Esc 收合」）。成功：浮層出現／收合，浮層清單為本地 fixture／已探測結果，探測逾時期間浮層仍可操作（SPEC-003 §3.7）；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生；個別專案項的探測逾時屬 4.9 `RecentProjectItem` 狀態矩陣範疇，非本元件開合動作本身）；服務不可用：同（不可能發生，開合浮層無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.7）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，側欄內距內）；高固有 |
| 最小尺寸 | 寬：2 × `Space.sm`（自身水平內距）+ `LayoutSize.iconLg` + 2 × `Space.sm`（圖示與文字、文字與展開圖示間距）+ 一字元 + 省略號（一字元見 §4.0.3，取 `AppFontSize.body`）+ `LayoutSize.iconMd`；高：`LayoutSize.iconLg` + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`） |
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| enabled | 圖示 `AppColors.textSecondary`、名稱 `textTitle`、摘要 caption | 點選 → 切換至該專案 | 可用性探測成功 | 點選 → 浮層收合（本元件隨浮層消失） | 資料態：`recentProjectsProvider`（`StateProvider<List<RecentProject>>`，`lib/app/project_switcher_providers.dart`，`WorkspaceRepository.loadRecentProjects()` 載入，SPEC-005 §2.4）提供清單項；可用性由 `switcherUnavailableProjectsProvider`（同檔，path → 原因）判定，無原因即 enabled；`SwitcherOverlay` watch 後以 `enabled` 傳值，元件不 watch（§2）。摘要與健康計數取各項的 `counts` 快照（SPEC-005 §2.4〈計數快照〉） | 等確認才顯示（可用性為探測完成後的資料態；探測未完成前不得預設為 enabled，SPEC-003 §3.7「探測逾時的處理」；§2 樂觀更新政策：0.1 無樂觀操作） |
| selected（目前專案） | 底 `AppColors.surfaceIconTint`、圖示與名稱 `accentStrong`（畫布為準）、摘要 `textPrimary`（§4.0.2 帶色表面規則：`textSecondary` / `surfaceIconTint` 3.98:1 未達 AA，`0.1.0-W1-060` 改） | 點選（重載同一專案，SPEC-003 §3.7 未區分，視同選取） | 為目前開啟的專案 | 同上 | 資料態：`currentWorkspaceStateProvider` 為 `WorkspaceReady` 且其 `path` 與本項 `path` 字串相等；`SwitcherOverlay` watch 後以 `isCurrent` 傳值。摘要與健康計數同 enabled 列讀快照，不讀即時掃描結果 | 本地即時（目前專案索引為本地狀態；切換專案的重載由 Domain 視圖載入態承載，不回寫本項） |
| disabled | 依 §4.0.1；同列常駐 `reason` 文字（不用 tooltip，SPEC-003 §3.7） | 無 | 探測逾時（每項 2 秒，SPEC-005 §2.5；reason 為 `projectUnavailableReasonLabel(probeTimeoutReason)`）；探測判定不可讀或不存在（reason 為 `projectUnavailableReasonLabel` 代入 `WorkspaceUnavailable.reason`，與點選失敗同源，SPEC-005 §2.5）；探測未完成（reason 為 `probingReason`，`0.1.0-W3-335.38` S-37）；點選後開啟該路徑判定不可讀或不存在（reason 取 `WorkspaceUnavailable.reason`，SPEC-003 §3.7「最近專案項（點擊後判定不可讀或不存在）」列，1.88，用戶裁決 2026-10-13） | 探測結果更新 → enabled（其餘項不受本項探測影響）；點選後判定失敗者於本次展開期間維持 disabled，重試須收合浮層再展開，下次展開重新探測（SPEC-003 §3.7〈浮層內選資料夾失敗的常駐原因文字〉「最近專案項失敗後的可用性」列） | 資料態：`switcherUnavailableProjectsProvider` 含本項 path（同 enabled 列） | 等確認才顯示（同 enabled 列） |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

**無計數快照**：項的 `counts` 為 `null`（SPEC-005 §2.4〈計數快照〉「無快照」列）時，呼叫端不傳 `summary` 與 `health`，本元件不渲染摘要列；`isDegraded` 徽章仍渲染於原摘要列位置（該列只剩徽章）。有快照時 `summary` 取 `projectSummaryLabel(nodeCount, ticketCount)`，`health` 依 SPEC-001 §7 健康徽章分類以 `issueCount` 取值（0 不傳）。enabled／selected／disabled 三態皆適用。

`isDegraded` 為 `true` 時，摘要列後加 `Badge.tag`（`degradedSchemaShortLabel`），enabled／selected／disabled 三態皆適用；徽章本身不影響 `enabled` / `selected` / `disabled` 判定（`0.1.0-W3-335.38` S-34）。徽章與摘要同一列、接在摘要之後，不另起一列（尺寸契約最大高未計徽章列）；寬度不足時摘要先截斷，徽章維持固有寬度（`0.5.0-W3-001` NC-2）。摘要與徽章間距為 `Space.sm`。可用寬連徽章固有寬都容納不下時，摘要縮至 0 後才截斷徽章（徽章寬上限 = 摘要列可用寬 − `Space.sm`）；優先序為名稱 > 徽章 > 摘要（`0.5.0-W1-071` 裁決）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；disabled 時無 hover overlay（§4.0.1 disabled 列） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；浮層展開時焦點限制於浮層內，Tab 依序走過各項（SPEC-003 §2.10「浮層展開時」列）；朗讀「{name}，{summary}」+ `selected` / `enabled` 旗標，disabled 時 `hint` 為 `reason`（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | enabled / selected / disabled → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行：浮層收合 → 全部導覽頁重置 → `state-domain-loading`（SPEC-003 §3.7，兩段不重疊）；開啟該路徑判定不可讀或不存在時不收合、不重置，呼叫端改傳 `enabled: false` 與 `reason`，本項轉 disabled，無 SnackBar（SPEC-003 §3.7「最近專案項失敗後的可用性」列，1.88）；disabled 時無反應、無 SnackBar（SPEC-003 §2.2 FR-06 合法形態 b） | Material 內建 ripple（浮層收合 `Motion.overlay` 由 4.42 `SwitcherOverlay` 承載） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | enabled / selected → pressed →（隨浮層消失） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.7）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`SwitcherOverlay` 清單 slot）：0.1 無定位至專案項的場景——浮層收合後 `scroll-switcher-recent` 的 offset 不保留、下次展開自頂端（SPEC-003 §3.7 生命週期），不對目前專案項執行 scroll-into-view；展開時的焦點落點屬焦點列 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：`SwitcherOverlay` 依 `switcherUnavailableProjectsProvider` 改 `enabled` / `reason` 傳值，依 `currentWorkspaceStateProvider` 的路徑改 `isCurrent` 傳值） | enabled ↔ disabled：視覺依 §4.0.1 disabled（`textDisabled`、無 hover overlay）+ 同列常駐 `reason`；語意樹 `enabled` 旗標隨重建更新，不設 live region（無障礙子節）；其餘項不受本項探測影響（SPEC-003 §3.7）。selected 切換：0.1 只在切換專案後重載時發生，重載前浮層已收合，本元件不呈現該過渡 | 無（探測結果為離散替換；SPEC-003 §3.7 無專案項過渡動畫條文；提案） | 無（探測逾時值屬 workspace domain、不在 SPEC-003 定義，且該值為探測時限非回饋時限；旗標與常駐文字隨重建瞬切；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用（旗標隨重建更新）；不升級系統通知） | disabled → enabled（探測結果更新）/ enabled → disabled（探測失敗或逾時） | 反應：UX 審查（SPEC-003 §3.7）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層（服務受理）與第三層（event 效果）不由本元件承載，皆委派 Domain 視圖畫面級載入態承載（`state-domain-loading`，4.24 `LoadingState`，SPEC-003 §2.6、§3.7）；可用性探測（決定本項 enabled/disabled）為另一獨立流程，非本事件觸發，亦不由本元件承載其等待（探測未完成的項依狀態矩陣 enabled 列「等確認才顯示」處理，浮層其餘項可操作）。服務類型：長時操作（專案切換觸發 Domain 載入，SPEC-003 §2.12 0.1 實例）。成功：Domain 視圖進入 `state-domain-loading` 後完成載入、全部導覽頁重置，結果通知即該狀態轉換本身，由 4.24 承載；失敗：由 4.24 `LoadingState` 依 SPEC-003 §2.12 長時操作類政策呈現（解析錯誤／平台錯誤／資料損壞），本元件不重述；逾時：同（由承載端呈現，本元件不另處理）；服務不可用：同。輸入阻擋範圍：不適用於本元件——由 4.24 依長時操作類政策阻擋頁面內容（SPEC-003 §2.12），本元件於呼叫 `onTap` 後隨浮層消失，不自行阻擋。重複觸發防護：不適用於本元件——依長時操作類政策，禁用觸發來源由頁面內容被載入態取代後自然消失達成（SPEC-003 §2.12），非本元件自我停用；disabled 態的成因是可用性探測失敗，與防抖無關（狀態矩陣 disabled 列） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.7）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，浮層內距內）；高固有 |
| 最小尺寸 | 寬：2 × `Space.sm`（自身水平內距）+ `LayoutSize.iconLg` + `Space.sm` + 一字元 + 省略號（一字元見 §4.0.3，由名稱列決定，取 `AppFontSize.body`）；高：`AppFontSize.body` 行高 + `Space.xxs` + `AppFontSize.caption` 行高 + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`） |
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
| 降級標籤（`isDegraded`） | 否 | 1 | 截斷 | `degradedSchemaShortLabel` 的 zh／en 實際值，於最小寬下截斷不溢位（`0.1.0-W3-335.38` S-34）。標籤文字由元件內部取 l10n、slot 只有 `isDegraded: bool`，`TestCopy` 無法注入，故不列 `TestCopy.longToken`（`0.5.0-W3-001` NC-1） |

`reason`（disabled）的取值依探測結果分兩種：逾時代入 `probeTimeoutReason`，非逾時的不可用代入 `WorkspaceUnavailable.reason`（SPEC-005 §2.5）。上表最長測試文案仍以 `probeTimeoutReason` 為準，表列不變；探測未完成的 `probingReason` 表列、ARB 與 P7 計數已由 `0.6.0-W1-019.2` 同批落地。

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `name` | `String` | 是 | 呼叫端（資料值） |
| `summary` | `String?` | 否 | 呼叫端（`projectSummaryLabel` 取值）；無計數快照時不傳（1.119） |
| `health` | `Badge.health?` | 否（問題數為 0 時不傳） | 不適用 |
| `enabled` / `isCurrent` | `bool` | 是 | 不適用 |
| `reason` | `String?` | `enabled` 為 `false` 時必填 | 呼叫端（`projectUnavailableReasonLabel` 取值） |
| `isDegraded` | `bool` | 否（預設 `false`） | 不適用（`0.1.0-W3-335.38` S-34） |
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
| `reason` | `projectUnavailableReasonLabel` + `probeTimeoutReason`（既有）；探測未完成時 `probingReason`（新增，§4.0.6，`0.1.0-W3-335.38` S-37）；點選後判定不可讀或不存在時 `projectUnavailableReasonLabel`，`reason` 取 `WorkspaceUnavailable.reason`（1.88，不新增 key） |
| 降級標籤 | `degradedSchemaShortLabel`（新增，§4.0.6，`0.1.0-W3-335.38` S-34） |
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
| 朗讀標籤 | `Semantics.button`；label 為「{name}，{summary}」（無 `summary` 時為「{name}」），`isCurrent` 時附 `currentProjectA11yLabel`；`selected` 等於 `isCurrent`；`enabled` 等於 `enabled`；disabled 時 `hint` 為 `reason` |
| 狀態變化播報 | `enabled` 改變（探測結果）隨重建更新旗標；不設 live region。點選後判定失敗而轉 disabled（已定案，狀態矩陣 disabled 列）是使用者動作的結果，其播報由 4.42 無障礙子節承載（播報方式為提案，1.88） |
| 非視覺替代訊號 | 不可用由 `enabled` 旗標 + 常駐文字承載；目前專案由 `selected` 旗標承載，底色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 浮層展開時焦點限制於浮層內，Tab 依序走過各項（SPEC-003 §2.10）；Space / Enter 觸發；Esc 收合 |
| 對比 | 依 §4.0.2：enabled 摘要與 disabled 原因 `textSecondary` / `surfaceBase` 4.71:1、selected 摘要 `textPrimary` / `surfaceIconTint` 4.89:1、selected 名稱 `accentStrong` / `surfaceIconTint` 8.38:1，皆通過；disabled 圖示與名稱 `textDisabled` 3.06:1 屬非作用中元件豁免（表 2） |

#### 測試點（widget test）

- [ ] 一支測試渲染 enabled / selected / disabled（含 reason；含探測未完成 `probingReason` 一支）× 有無 `health` × 有／無 `isDegraded`
- [ ] 兩種視窗尺寸下不溢位（寬固定於 `LayoutSize.overlayWidth` 內）
- [ ] 最長測試文案：名稱與摘要截斷、原因兩行末截斷、降級標籤截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] disabled 的 `reason` 代入 `WorkspaceUnavailable.reason` 型式的值（點選後判定失敗，1.88）時同列顯示且不溢位
- [ ] enabled 點選呼叫 `onTap` 恰一次；disabled 零次；`Semantics.selected` / `enabled` 與參數一致；`isDegraded` 為 `true` 時 `Badge.tag` 存在且不影響 `onTap` 行為
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「選擇其他資料夾」動作 | `AppButton.text`（浮層末格） |
| 側欄的目前專案顯示 | `ProjectSwitcherEntry` |

### 4.10 SegmentedControl

**用途**：互斥單選的常駐切換。雙模式切換（矩陣／泳道、列表／主題），每段錨點 `mode-<screen>-<mode>`；變更記錄的期間選擇（預設期間／最近 30 天／全部歷史），每段錨點 `option-history-period-<period>`（SPEC-003 §3.9）。錨點由呼叫端經 `segments[i].testKey` 傳入，本元件不組錨點。
**期間選擇沿用本元件而非 `FilterDropdown` 的理由**（1.131）：(1) SPEC-003 §3.9 只定義三個選項錨點、未定義觸發器錨點，且三個選項在正常與期間內無事件兩態皆可直接點擊；下拉的選項在選單收合時不在元件樹（同 §3.6〈UC 選擇入口〉「為何是常駐清單而非下拉」的理由）。(2) `FilterDropdown` 的首項固定為「全部」並回傳 `null`（SPEC-003 §3.4 F3），期間選擇沒有「不篩選」值，三值皆為具名期間。(3) 三值互斥、恆有一值選取，與本元件的單選語意相同。
**內容角色**：動作（每段一個 label slot）。
**何時不用**：畫面導覽（`NavItem`）；一次性動作（`AppButton`）；單一布林切換（`AppCheckbox`）；四段以上，或選項數隨資料增減的選擇（`FilterDropdown` 或 `ListRow.option`）。
**出現畫面**：§1、§4、§10。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；段數 2–3（三段只用於 §10 期間選擇） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| segment selected | 段底 `AppColors.surfaceBase`、字 `accentStrong` 半粗；軌道底 `surfaceSegmentTrack` | 點選（無狀態改變） | `selectedIndex` 等於本段 | 點選他段 → unselected | 資料態：所在畫面的雙模式 provider——Domain 視圖為 `domainViewStateProvider` 的 `DomainReady.mode`（`lib/app/domain_view_providers.dart`），Ticket 清單為 `ticketListStateProvider` 的 `TicketsReady.mode`（`lib/screens/ticket_list/ticket_list_providers.dart`）；頁面層 watch 後以 `selectedIndex` 傳值，元件不 watch（§2 頁面狀態保留：雙模式選擇存於 provider） | 本地即時（模式切換為本地畫面狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| segment unselected | 段透明、字 `textPrimary` | 點選 | 非選取段 | 點選本段 → selected | 資料態：同上 | 本地即時 |
| hover（僅指標形態，每段） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed（每段） | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused（每段） | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：雙模式切換恆可用（SPEC-001 §1、§4 可用操作）；期間選擇於渲染篩選列的兩態（正常、期間內無事件）恆可用，其餘狀態不渲染篩選列（SPEC-001 §10）。§10 的選取值來源：第七畫面頁面狀態持有的期間篩選值（SPEC-008 FR-07 規則 2；切換導覽項保留、切換專案回到預設，SPEC-003 §3.9〈生命週期〉），頁面層以 `selectedIndex` 傳值，同步策略本地即時（在記憶體結果上重新查詢，不重新掃描，SPEC-008 FR-07 規則 5）。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選取切換所在畫面的檢視模式，不執行命令、不開視窗 |
| 2 | 套用時點 | (a)–(e) 皆不成立：單一值；切換為本地即時（SPEC-003 §2.12）；可隨時切回；不在需儲存的表單內 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——本元件常駐於頁首列（`SplitRow.header`） |
| 4 | 生效是否當下可見 | 有——同畫面轉入另一模式視圖（`state-<screen>-<b>` 出現），回饋契約關卡二第 2 問答是 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 每段各自 hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；已選段同樣有 hover（點選已選段無狀態改變，但仍為可點） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；每段各為 Tab 內容區段的一個停留點，方向鍵不列入 0.1 下界（SPEC-003 §2.10）；朗讀段 label + `hint`（`semanticLabel`）+ `selected` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | selected / unselected → focused → 原狀態（每段） | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；點選未選段呼叫 `onChanged(index)` 恰一次，呼叫端執行同畫面狀態轉換：`state-<screen>-<a>` 消失、`state-<screen>-<b>` 出現，各模式 offset 各自保留（SPEC-003 §1.2、§3.1、§3.4）；點選已選段仍有 pressed 態但不呼叫、無狀態改變 | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | unselected → pressed → selected（本段）；selected → pressed → selected（已選段） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.1、§3.4）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`SplitRow.header` 右格）：0.1 無定位至切換段的場景——頁首列常駐不捲動，模式切換不改變本元件位置 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依模式 provider 改 `selectedIndex` 傳值；0.1 模式只由本元件點選改變，切換專案時重置為預設模式屬 SPEC-003 §2.8 L2 的畫面級重置） | 段的選取視覺切換（段底 `surfaceBase`、字 `accentStrong` 半粗）為離散替換無動畫；畫面內容的 cross-fade `Motion.transition` 由所在畫面承載（SPEC-003 §3.4〈動畫提示〉「列表 ↔ 主題」；矩陣 ↔ 泳道依 §2.1〈未列轉換的預設〉），本元件不播；`selected` 旗標改變由輔助技術播報（原生旗標，不另組字，無障礙子節） | 無（段的選取態切換無動畫；畫面內容 `Motion.transition` 由畫面承載） | 無（本地即時，段視覺與 `selectedIndex` 同步瞬切；SPEC-003 無段視覺時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡由畫面承載，本元件不適用；無障礙狀態變化播報適用；不升級系統通知） | unselected → selected（本段被選）/ selected → unselected（他段被選） | 反應：規格撰寫者（提案；SPEC-003 §2.1、§3.4 只定畫面內容 cross-fade，未定段視覺過渡）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（模式切換無服務受理階段），第三層即結果通知本身（同畫面狀態轉換：`state-<screen>-<b>` 出現 + 本段轉 selected，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（模式切換，SPEC-003 §2.12 0.1 實例）。成功：切換至新模式視圖，兩模式內容為同一份已載入資料的不同視圖，切換不觸發載入；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，模式切換無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.1、§3.4）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（每段各為一個 Tab 停留點；方向鍵不列入 0.1 下界，SPEC-003 §2.10） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（各段 label 寬 + 2 × `Space.md`，軌道內距 `Space.xxs`） |
| 最小尺寸 | 寬：2 × `LayoutSize.hitTargetMin`；高：元件固有高 `LayoutSize.hitTargetMin` + 2 × `Space.xxs`（段高 `hitTargetMin` 加軌道內距上下各 `Space.xxs`） |
| 最小命中區 | 每段 `LayoutSize.hitTargetMin`（段高；不含軌道內距） |
| 最大尺寸 | 寬：父格位寬（超出時各段 label 截斷）；高：元件固有高 `LayoutSize.hitTargetMin` + 2 × `Space.xxs` |
| `kMinWindowSize` 下的行為 | 維持（置於 `SplitRow.header` 右格） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `segments[i].label` | 否 | 1 | 截斷 | `modeSwimlaneLabel`（en「Swimlane」）；三段：`historyPeriodDefaultLabel`（en「Default period」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `segments` | `List<SegmentItem{label, semanticLabel, testKey}>`，長度 2 或 3（3 只用於 §10 期間選擇） | 是 | label 由呼叫端（`mode*Label` / `historyPeriod*Label`）；semanticLabel 由呼叫端（既有 `*SwitchTo*Action` / `historyPeriodSelectA11yHint`） |
| `selectedIndex` | `int` | 是 | 不適用 |
| `onChanged` | `ValueChanged<int>` | 是 | 不適用 |

> **實作註記**：`segments` 型別名為 `SegmentItem`（非契約原文 `Segment`）——與 `package:flutter/material.dart` 內建 `Segment<T>`（`SegmentedButton` 用）撞名，實作時改名避免同檔匯入歧義，語意不變。

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceSegmentTrack`（軌道）、`surfaceBase`（選取段底）、`accentStrong`、`textPrimary` |
| 間距 | 段內距 `Space.md`（水平）× `Space.xs`（垂直）；軌道內距 `Space.xxs`；段間 `Space.xxs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md`（軌道）、`Radius.sm`（段） |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 段 label | `modeMatrixLabel` / `modeSwimlaneLabel` / `modeListLabel` / `modeTopicLabel` / `historyPeriodDefaultLabel` / `historyPeriodRecent30Label` / `historyPeriodAllLabel`（呼叫端傳入） |
| 段朗讀提示 | `domainSwitchToMatrixAction` / `domainSwitchToSwimlaneAction` / `ticketsSwitchToListAction` / `ticketsSwitchToTopicAction`（既有）/ `historyPeriodSelectA11yHint`（§10，代入該段 label）（呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `SplitRow.header`（右格，雙模式）；`Toolbar.history`（首格，§10 期間選擇） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 置中於頁首列；`Toolbar.history` 內垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 每段 `Semantics.button`，label 等於段 label，`hint` 等於 `semanticLabel`（「切換至矩陣」），`selected` 等於是否選取 |
| 狀態變化播報 | `selected` 旗標改變由輔助技術播報 |
| 非視覺替代訊號 | 選取態同時以底色、字重與 `selected` 旗標承載 |
| 焦點順序與操作路徑（桌機） | Tab 內容區段，各段依序各為停留點（兩段或三段）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：選取段 `accentStrong` / `surfaceBase` 9.92:1、未選段 `textPrimary` / `surfaceSegmentTrack` 4.56:1（`0.1.0-W1-059` 軌道底調淺為 `#DEE6E4` 後；原畫布值 4.48:1 未達），皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染兩段 × 選取索引 0 / 1，與三段 × 選取索引 0 / 1 / 2
- [ ] `segments` 長度為 1 或 4 時建構失敗（assert），長度 2、3 皆可建構
- [ ] 每段的錨點等於呼叫端傳入的 `testKey`（`mode-*` 與 `option-history-period-*` 兩種形態）
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en 四個 label key 皆不溢位
- [ ] 點選未選段呼叫 `onChanged` 恰一次並帶正確索引；點選已選段零次
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 篩選條件的多選 | `FilterDropdown` |
| 四段以上，或選項數隨資料增減的單選 | `FilterDropdown`（篩選）或 `ListRow.option`（常駐清單） |
| 單一布林開關 | `AppCheckbox` |

### 4.11 PageTitle

**用途**：頁首左側：畫面名 + 一行副標（模式說明或選取摘要）。
**內容角色**：標題 + 內文（title slot + subtitle slot；`subtitle` 是 slot 名，其渲染變體為 `AppText.body`，非 `AppText.subtitle`——後者恆為 `Semantics.header`，而副標依本條目無障礙列不得為 header）。
**何時不用**：面板內標題（`AppText.subtitle`）；節點詳情主標（`AppText.title`）。
**出現畫面**：§1–§6、§10。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；副標為可選 slot | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | `AppText.subtitle`（畫面名）上、`AppText.body`（`secondary: true`、`maxLines: 1`，副標）下，間距 `Space.xxs`；無副標時只一行。副標著色寫法取 `secondary` 而非 `tone: textSecondary`：兩者結果同色，依 4.1 優先序 `tone` 只在需覆蓋 `secondary` 或變體預設色時才傳入，本元件無此需求，採較低優先序的 `secondary`（與 `lib/components/page_title.dart` 一致） | 無 | 建構 | 不適用：純顯示，無狀態集 | —（建構即渲染；`title` / `subtitle` 由呼叫端傳值，副標的選取摘要值變更由頁面層重建，元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且無資料態變更——不可點、不進入 Tab 順序（無障礙子節）、狀態矩陣僅 default 一列；副標更新（選取摘要）不主動播報（無障礙子節），選取的回饋由產生選取的元件（`MatrixCell` / `SwimlaneNode`）與所在畫面承載，非本元件的回饋事件 | — | — | 不適用（§1 子表六列皆由所屬可點元件或容器承載） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬，`SplitRow.header` 左格）；高固有 |
| 最小尺寸 | 寬：一字元 + 省略號（一字元見 §4.0.3，由 `title` slot 決定，取 `AppFontSize.subtitle`；`subtitle` slot 經 `AppText.body` 渲染，字級 `AppFontSize.body` 較小，不決定最小寬；`title` 與 `subtitle` 的超出處置皆為截斷，計省略號）；高：一行 |
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
| 字體 | 經 `AppText`（畫面名 `subtitle`、副標 `body`） |
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
| 朗讀標籤 | `title` 為 `Semantics.header`；副標非 header（故取 `AppText.body`），接續唸出 |
| 狀態變化播報 | 副標更新（選取摘要）不主動播報 |
| 非視覺替代訊號 | 不適用顏色訊號（純文字） |
| 焦點順序與操作路徑（桌機） | 不進入 Tab 順序 |
| 對比 | 依 §4.0.2 表 1：畫面名 `textTitle` / `surfaceBase` 17.20:1、副標 `textSecondary` / `surfaceBase` 4.71:1，皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染有副標 / 無副標
- [ ] 兩種視窗尺寸下不溢位（置於 `SplitRow.header` 左格且右格有 `SegmentedControl`）
- [ ] 最長測試文案兩 slot 皆截斷
- [ ] zh / en 全部 `nav*` key 皆不溢位
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| empty | 搜尋圖示（`textDisabled`，純裝飾）+ placeholder（`searchPlaceholder`，`textSecondary`）；無清除鈕 | 輸入 | 值為空字串 | 輸入 → filled | 資料態：受控 `value` 來自 Ticket 清單畫面的搜尋詞 provider——顯示值取 `ticketSearchInputProvider`（為 `null` 時退回 `ticketListStateProvider` 的 `TicketsReady.searchQuery`），輸入經 `ticketSearchDebouncerProvider` 防抖後才寫入 `searchQuery`（三者皆在 `lib/screens/ticket_list/ticket_list_providers.dart`）；頁面層 watch 後以 `value` 傳值，元件不 watch（§2 頁面狀態保留：搜尋詞存於 provider） | 本地即時（輸入即回顯，不等資料層；過濾結果的清單筆數更新由畫面於 `Motion.searchDebounce` 後承載，非本元件狀態；§2 樂觀更新政策：0.1 無樂觀操作） |
| filled | 搜尋圖示 + 值 + 清除鈕（內部 affordance，朗讀 `searchClearAction`） | 輸入、清除 | 值非空 | 清除或刪除至空 → empty | 資料態：同上 | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1（`TextField` 的 `InputDecoration` hover 底色取 `ThemeData` 預設；清除鈕為 Material `InkWell` 內建 overlay） | 輸入 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 不適用：`TextField` 無 pressed 態；清除鈕的 pressed 依 §4.0.1（Material 內建，由清除鈕的 `InkWell` 承載） | 清除 | 按下清除鈕 | 放開 | 互動瞬態 | 本地即時 |
| focused | 邊框 `AppColors.accent`（焦點裝飾，§4.0.1）；可與 empty / filled 並存 | 輸入 | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：搜尋於正常態恆可用（SPEC-001 §4）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 欄位：`TextField` 內建 hover（`InputDecoration` hover 底色，`ThemeData` 預設，不自繪）、指標形狀 `SystemMouseCursors.text`；清除鈕（filled 時存在）：hover 態（§4.0.1：Material `InkWell` 內建 overlay）、指標形狀 `SystemMouseCursors.click` | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（延伸 §4.0.1 提案列至 `TextField`）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 邊框 `AppColors.accent`（§4.0.1 focused）+ 文字游標；位於 Tab 內容區段首個（工具列首格），filled 時 Tab 至清除鈕（SPEC-003 §2.10）；朗讀 `Semantics.textField` 的 label（`searchPlaceholder`）與 value（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | empty / filled → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 輸入字元：值即時回顯即為確認（原生 `TextField`，無 pressed 態）；IME 組字中（`TextEditingValue.composing` 非空）值顯示為組字狀態，組字未確定前不觸發 `onChanged`；清除鈕：pressed 態 + Material ripple（§4.0.1），呼叫 `onChanged('')` 恰一次 | Material 內建 ripple（清除鈕）；輸入無動畫 | 清除鈕 pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1）；輸入回顯無時限條文（原生行為；提案） | §1 子表「按下確認」列 | filled → pressed（清除鈕）→ empty；empty / filled →（輸入）→ filled | 反應／時限：UX 審查（SPEC-003 §2.2）；輸入回顯：規格撰寫者（提案）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載：本元件是搜尋的**來源**而非被定位目標，位於 `Toolbar` 首格常駐不捲動；§1 子表 locate 列適用場景「搜尋命中列」的 scroll-into-view + 高亮由 Ticket 清單的資料視圖容器（4.36 `DataTable`）執行，本元件不參與 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依搜尋詞 provider 改 `value` 傳值；含切換專案時搜尋詞清空，SPEC-003 §3.4 生命週期） | empty ↔ filled：清除鈕出現／消失為離散替換無動畫；值改變由 `Semantics.textField` 語意自動播報，清單筆數變化的播報由畫面（`SplitRow.footer` 摘要）承載，本元件不播報（無障礙子節）；`onChanged(value)` 於每次非組字輸入即呼叫一次（元件不防抖，防抖由呼叫端搜尋詞 provider 承擔）、清除或刪至空同樣立即呼叫 `onChanged('')`（SPEC-003 §3.4 搜尋列「清空輸入立即還原」） | 無（清除鈕出現／消失無動畫；SPEC-003 §3.4 無對應動畫條文；提案） | `onChanged`：無（元件每次非組字輸入即呼叫，不等待；防抖由呼叫端搜尋詞 provider 以 `Motion.searchDebounce` 承擔，SPEC-003 §3.4、§2.1）；清除：立即；empty ↔ filled 視覺：無（本地即時；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報由 textField 語意承載；不升級系統通知） | empty → filled（輸入）/ filled → empty（清除或刪至空） | 反應／時限：UX 審查（SPEC-003 §3.4）；視覺切換：規格撰寫者（提案）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，值回顯 + 清除鈕 pressed 態）——第二層不適用（本地過濾運算無服務受理階段，防抖動期間不顯示 spinner，SPEC-003 §2.6「0.1 無非狀態級短暫等待」），第三層即結果通知本身（清單筆數更新的狀態轉換，SPEC-003 §2.2 結果通知列），由畫面承載。服務類型：延遲觸發（搜尋輸入防抖後觸發過濾，SPEC-003 §2.12 0.1 實例，即本元件 `input-tickets-search`）。成功：清單依過濾結果更新筆數，由畫面承載；失敗：依 SPEC-003 §2.12，延遲觸發類「不可能失敗（本地過濾運算）」，故本元件無失敗態需呈現；逾時：同（不可能發生，本地運算無外部等待）；服務不可用：同（不可能發生，過濾為本地已載入資料的同步運算，無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 延遲觸發類政策：使用者正在輸入，不得打斷）。重複觸發防護：防抖（`Motion.searchDebounce`，承擔者為呼叫端搜尋詞 provider，非本元件；見 state-change 列與 `0.1.0-W3-110`／`0.1.0-W3-126` 既有改動，本列與之一致） | Material 內建（清除鈕） | `Motion.feedback`（清除鈕）；`Motion.searchDebounce`（結果出現） | §1 子表「等待與結果」列 | 不適用 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.6、§2.12、§3.4）；通道：規格撰寫者 |

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
- [ ] 輸入後 `pump` 即 `onChanged` 恰一次（元件不防抖）；清除立即一次
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

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default（全部） | 「{label}：{filterAllOption}」+ 向下箭頭；底 `surfaceBase`、框 `border` | 點選 → open | `selected` 為 `null` | 選取非全部 → active | 資料態：受控 `selected` 來自 Ticket 清單畫面的篩選 provider（每個 `<key>` 一個值）——`ticketListStateProvider` 的 `TicketsReady.statusFilter`／`priorityFilter`（`lib/screens/ticket_list/ticket_list_providers.dart`）；頁面層 watch 後以 `selected` 傳值，元件不 watch（§2 頁面狀態保留：篩選值存於 provider） | 本地即時（篩選為本地已載入資料的子集運算，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| active（有篩選值） | 「{label}：{value}」；框 `accent`（SPEC-003「該篩選呈選中態」的視覺落點） | 點選 → open | `selected` 非 `null` | 選取全部 → default | 資料態：同上 | 本地即時 |
| open | 選單以覆蓋層展開（F1、F4）；觸發器選取態不受影響，`open` 是疊加於 default／active 之上的修飾非第三個互斥狀態（F2） | 走選項（↑↓Home/End）、選取（Enter/Space/點擊）、Esc、點外部、再點觸發器、Tab/Shift+Tab | 點選觸發器（收合時）或聚焦時 Enter／Space／↓ | 選取且值改變 → 收合回 active／default；選取值相同、Esc、點外部、再點觸發器、Tab 離開 → 收合回原態（`selected` 不變） | 互動瞬態（選單開合為元件內部 overlay 狀態，不存於 provider：選單展開期間不會發生導覽切換或專案切換（F7），故切換導覽項時選單必為收合態，不需依 §2 頁面狀態保留） | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Enter / Space / ↓ 展開） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選取改變該 `<key>` 的篩選值；選項不執行命令、不開視窗（選單由觸發器展開，是本元件內部的覆蓋層） |
| 2 | 套用時點 | (a)–(e) 皆不成立：每個 `<key>` 一個值；篩選作用於已載入資料，本地即時；改選「全部」即復原；不在需儲存的表單內 → 立即提交，提交點為「選取且值改變」（F5） |
| 3 | 容器何時關閉 | 是——選單只含本 `<key>` 一組單選 → 選取即收合（狀態矩陣 open 列退出路徑） |
| 4 | 生效是否當下可見 | 有——Ticket 清單在同畫面依新篩選值變化，觸發器呈 active 態，回饋契約關卡二第 2 問答是 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 選單內的逐操作反應（走選項、Esc、點外部、再點觸發器、Tab 離開）為本元件的操作路徑而非六類回饋事件，規格在 SPEC-003 §3.4 篩選各列與本條目〈選單的元件級契約〉F1–F7；下表只填六類事件在各操作上的回饋。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 觸發器 hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；選單展開時各選項各自有 hover 態（同機制） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 觸發器：焦點環（§4.0.1 focused），進入 Tab 內容區段（SPEC-003 §2.10），朗讀 `filterA11yLabel` + `expanded` 旗標（無障礙子節）。選單展開時：焦點移至目前值對應選項（`selected` 為 `null` 時為「全部」項），↑／↓／Home／End 在選項間移動不循環，`onChanged` 不被呼叫（SPEC-003 §3.4 走選項列）；Esc／選取後焦點回觸發器，Tab／Shift+Tab 收合並依 §2.10 順序離開（選單不限制焦點，與浮層不同，SPEC-003 §2.10 篩選選單兩列）；每個選項 `role` 為 `menuItem`、目前值項 `selected` 為 `true`（F6） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default / active → focused → 原狀態；open 期間焦點在選項間移動不改變 default／active（F2） | 反應：UX 審查（SPEC-003 §2.10、§3.4）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 觸發器：pressed 態 + Material ripple（§4.0.1）；收合時點選或聚焦時 Enter／Space／↓ → 選單展開（`menu-tickets-filter-<key>`，淡入 + 自觸發器向下展開），`onChanged` 不被呼叫；展開時再點觸發器 → 收合，焦點停在觸發器。選項：pressed 態 + ripple；選取且值改變 → 呼叫 `onChanged(value)` 恰一次，選單收合，焦點回觸發器；值相同 → 只收合，不呼叫（F5）。點選單與觸發器以外任一處 → 收合且該次點擊被吸收不穿透（F7）（SPEC-003 §3.4 篩選各列） | Material 內建 ripple；選單展開／收合 `Motion.overlay`（SPEC-003 §3.4 動畫提示，與 §3.7 浮層同一手法；`disableAnimations` 下依 §2.1 歸零） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1）；選單出現／收合於 `Motion.overlay` 內（SPEC-003 §3.4 篩選 · 開啟／選取列） | §1 子表「按下確認」列 | default / active → pressed → open；open → pressed（選項，值改變）→ active / default；open → pressed（選項值相同／再點觸發器／點外部）→ 原態 | 反應／時限：UX 審查（SPEC-003 §2.2、§3.4）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`Toolbar` 第 2..N 格）：本元件是篩選的**來源**而非被定位目標，工具列常駐不捲動；選單為覆蓋層、`options` 全數展開不捲動（F4），選單內無 scroll-into-view 需求；展開時焦點移至目前值對應選項屬焦點列 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依篩選 provider 改 `selected` 傳值；含切換專案時篩選清空，SPEC-003 §3.4 生命週期）；open 開合為元件自有瞬態，非本列事件 | default ↔ active：觸發器文字改為新選項文字、框色 `border` ↔ `accent` 為離散替換無動畫；重建即唸出新值（`filterA11yLabel` 的 `{value}` 為新選項文字，重建即為播報載體，不另發 `SemanticsService.announce`，F6）；清單筆數改變與 offset 歸零由畫面承載（SPEC-003 §3.4 篩選 · 選取列） | 無（觸發器視覺為離散替換；SPEC-003 §3.4 動畫提示未定觸發器過渡；提案） | 無（本地即時，觸發器文字與框色隨 `selected` 同步瞬切；SPEC-003 無對應時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用（重建唸出）；不升級系統通知） | default → active（選取非全部）/ active → default（選取全部）/ active → active（換另一非全部值） | 反應：UX 審查（SPEC-003 §3.4 F6）；視覺切換：規格撰寫者（提案）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，觸發器與選項的 pressed 態）——第二層不適用（篩選為本地已載入資料的子集運算，SPEC-003 §2.6「0.1 無非狀態級短暫等待」），第三層即結果通知本身（清單筆數改變 + offset 歸零的狀態轉換，SPEC-003 §2.2 結果通知列），由畫面承載，篩選或排序後的列表重繪無 cross-fade（SPEC-003 §3.4 動畫提示）。服務類型：本地即時（篩選選取，SPEC-003 §2.12 0.1 實例）。成功：清單依篩選結果更新筆數與 offset，由畫面承載；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，篩選為本地運算無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策；選單開合契約 F1–F7 為本元件自有的操作路徑不變式，見〈選單的元件級契約〉，屬另一層次，非重複觸發防護範疇） | Material 內建；`Motion.overlay`（選單） | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.6、§2.12、§3.4）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（觸發器）；選單內以 ↑／↓／Home／End 走選項，Enter／Space 選取，Esc 收合 | | | | |

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
| `testKey` | `Key` | 是（觸發器 `action-tickets-filter-<key>`；選單根 `menu-tickets-filter-<key>` 與選項 `option-tickets-filter-<key>-<value>`／`option-tickets-filter-<key>-all` 由元件依 `<key>` 推導，呼叫端不另傳） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border`、`accent`（active 框）、`textPrimary`、`textDisabled`（箭頭，純裝飾，§4.0.2 表 2） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直）；文字與箭頭間 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`（選取）；`Motion.overlay`（選單展開收合） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 「全部」 | `filterAllOption` |
| 朗讀標籤 | `filterA11yLabel` |
| `label` | `filterStatusLabel` / `filterPriorityLabel`（呼叫端傳入） |

#### 選單的元件級契約（跨操作恆成立，由本元件單一承擔）

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| F1 | 任一時刻 | 同時至多一個選單展開；開啟另一個下拉的第一次點擊只收合不開啟，需再點一次 |
| F2 | 選單展開時 | 觸發器選取態只由 `selected` 決定，不因展開改變 |
| F3 | 選單展開時（內容） | 首項為「全部」（文字 `filterAllOption`，錨點 `option-tickets-filter-<key>-all`），其後依 `options` 順序（文字 `options[i].label`，錨點 `option-tickets-filter-<key>-<options[i].value>`）；`options` 的 `value` 不得為 `all`（保留給「全部」）；與 SPEC-003 §3.4 F3 一致（`0.3.3-W3-403`） |
| F4 | 選單展開時（幾何） | 選單為覆蓋層：頂緣貼觸發器底緣、左緣貼觸發器左緣；工具列其餘元素 rect 展開前後不變（不擠壓版面）；`options` 全數展開不捲動；`kMinWindowSize` 下選單底緣仍在視窗內 |
| F5 | 展開／走選項／收合（任一方式） | 皆不呼叫 `onChanged`；唯一呼叫點是「選取且值改變」——篩選在選取時一次套用，不在焦點移動時即時套用 |
| F6 | 選單展開時（播報） | 選單根節點 `role` 為 `menu`；每個選項 `role` 為 `menuItem`、label 為選項文字、`selected` 於目前值項為 `true`；觸發器 `expanded` 展開時 `true`、收合後 `false` |
| F7 | 選單展開期間 | 點外部一律吸收收合，不穿透觸發下層動作（導覽切換、開票等） |

**實作註記**：F7 的模態遮罩對整個視窗吸收點擊（含觸發器自身所在座標）——再次點擊觸發器座標時實際命中遮罩而非觸發器 `onTap`，但淨行為（選單皆收合）與逐字實作「再次點觸發器：焦點停在觸發器」一致，僅觸發路徑不同；若未來需要精確依字面實作，需改用 `TapRegion`（group 內點擊視為內部）取代目前的全螢幕 barrier。

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
| 狀態變化播報 | 選取後重建即唸出新值（`filterA11yLabel` 的 `{value}` 為新選項文字，重建即為播報載體，不另發 `SemanticsService.announce`）；選單根節點 `role` 為 `menu`、選項 `role` 為 `menuItem` 並帶 `selected`（F6） |
| 非視覺替代訊號 | active 由觸發器文字（值非「全部」）承載，框色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 觸發器進入 Tab 順序；選單展開時焦點以 ↑／↓／Home／End 在選項間移動；Esc／Tab 離開／再點觸發器時焦點回觸發器或依序移動 |
| 對比 | 依 §4.0.2：label 與值 `textPrimary` / `surfaceBase` 5.79:1，通過；箭頭 `textDisabled` / `surfaceBase` 3.06:1 達非文字 3:1，且為純裝飾（開合狀態由語意樹承載，表 2） |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / active / open 三態
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`；選取不同值時寬不變
- [ ] 最長測試文案截斷
- [ ] zh / en 兩語系值皆不溢位
- [ ] 選取選項呼叫 `onChanged` 恰一次；選「全部」傳 `null`；值相同不呼叫
- [ ] 選單展開時選單根 `menu-tickets-filter-<key>`、首項 `option-tickets-filter-<key>-all`、其後各項 `option-tickets-filter-<key>-<value>` 錨點存在且順序與 `options` 一致（F3）
- [ ] F1：開啟另一個下拉時前一個先收合；F4：選單幾何（頂緣貼底緣、左緣對齊、不擠壓版面、`kMinWindowSize` 底緣在視窗內）；F6：選單根 `role=menu`、選項 `role=menuItem`、`selected` 對應目前值；F7：點外部收合且吸收點擊
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

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `static` | 一行 caption | 無 | UC Flow 步驟表欄首 |
| `sortable` | 一行 caption + 排序指示圖示（asc / desc 時） | 點選 → 排序（循環待決） | Ticket 清單欄首（`action-tickets-sort-<key>`） |
| `twoLine` | 第一行 `AppText.mono`（UC ID）、第二行 caption（名稱） | 無 | 矩陣欄首 |
| `blank` | 無文字、無圖示；佔該欄欄寬、高同列內其他欄首 | 無 | 該欄沒有標題時（Ticket 清單損壞標記欄、UC Flow 步驟表首欄與事件表末欄）；取代呼叫端自放 `SizedBox.shrink()`（`0.4.0-W3-001`，用戶裁決：不包子件的空節點不是佈局輔助，表頭空白格屬元件層缺口） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default（`static` / `twoLine`） | label | 無 | 建構 | 不適用：純顯示變體無狀態集 | —（建構即渲染；`label` / `secondLine` 由呼叫端傳值，元件不 watch 任何 provider，§2） | 本地即時 |
| unsorted（`sortable`） | label，無指示 | 點選 | `order` 為 `none` | 點選 → 呼叫 `onSort`；下一個 `order`（`asc`）由呼叫端依 SPEC-003 §3.4 S2 決定 | 資料態：受控 `order` 來自 Ticket 清單畫面的排序 provider（單欄排序，S1：`order` 非 `none` 的欄至多一個）——`ticketListStateProvider` 的 `TicketsReady.sortKey` 與 `sortOrder`，經 `orderFor(key)` 換成 `order`（`lib/screens/ticket_list/ticket_list_providers.dart`）；頁面層 watch 後以 `order` 傳值，元件不 watch（§2 頁面狀態保留：排序存於 provider） | 本地即時（排序為本地已載入資料的重排，列表直接重建，SPEC-003 §3.4 動畫提示；§2 樂觀更新政策：0.1 無樂觀操作） |
| asc / desc（`sortable`） | label + 向上／向下指示（`AppIcon.sm`，`accentStrong`） | 點選 | `order` 為 `asc` / `desc` | 點選 → 呼叫 `onSort`；下一個 `order`（`desc` / `none`）由呼叫端依 SPEC-003 §3.4 S2 決定 | 資料態：同上 | 本地即時 |
| hover（僅指標形態，`sortable`） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed（`sortable`） | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused（`sortable`） | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。只適用 `sortable` 變體；`static`／`twoLine`／`blank` 為純顯示、非選擇類，填不適用。

| # | 問句 | 答（`sortable`） |
|---|------|----|
| 1 | 設定或動作 | 設定——點選改變清單排序，不執行命令、不開視窗 |
| 2 | 套用時點 | (a)–(e) 皆不成立：單欄排序（S1）；本地即時；再點即循環回 `none`；不在需儲存的表單內 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——欄首常駐於表頭列 |
| 4 | 生效是否當下可見 | 有——清單在同畫面重排、本欄排序指示改變，回饋契約關卡二第 2 問答是 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 六列皆只適用 `sortable` 變體；`static` / `twoLine` 為非互動元素（SPEC-003 §3.4 S7：點擊不產生反應且不呈按鈕形態、不進入 Tab 順序），其回饋於各列內註明不適用，不另立整節不適用列（本元件有可互動變體，不符範本「純顯示且無資料態變更」的唯一不適用情境）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | `sortable`：hover 態（§4.0.1：Material `InkWell` 內建 overlay）、指標形狀 `SystemMouseCursors.click`；`static` / `twoLine`：無 hover、無 `InkWell`（S7） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列（`static` / `twoLine` 不適用：非互動元素） | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | `sortable`：焦點環（§4.0.1 focused），進入 Tab 內容區段（SPEC-003 §2.10），朗讀 `sortA11yLabel(label, order)`（無障礙子節）；`static` / `twoLine`：不進入 Tab 順序，`Semantics.header` 由輔助技術逐項朗讀 | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列（`static` / `twoLine` 不適用） | unsorted / asc / desc → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10、§3.4 S7）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | `sortable`：pressed 態 + Material ripple（§4.0.1）；呼叫 `onSort` 恰一次；呼叫端執行：依 SPEC-003 §3.4 S1–S2（`none → asc → desc → none`，換欄自 `asc` 起算，單欄排序）推進該欄 `order`，首列與末列內容改變、offset 歸零；`static` / `twoLine`：點擊不產生任何反應且不呈按鈕形態（S7） | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列（`static` / `twoLine` 不適用） | unsorted → pressed → asc；asc → pressed → desc；desc → pressed → unsorted（推進由呼叫端決定，本元件只回呼） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.4 S1–S2）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（`TableRow.header` / `MatrixGrid` 欄首格）：0.1 無定位至欄首的場景——表格欄首列常駐於資料視圖頂端，矩陣欄首隨 `MatrixGrid` 二維捲動固定於頂列（4.37）；排序後 offset 歸零屬結果通知，非定位 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依排序 provider 改 `order` 傳值；含換欄時前欄回 `none`（S1）與切換專案時全部欄首重置為 `none`，SPEC-003 §3.4 排序 · 換欄列與生命週期） | 排序指示圖示直接替換（出現／方向切換／消失），無動畫（SPEC-003 §3.4 動畫提示「排序指示切換」）；欄首重建後 `Semantics.button` 的 label 等於 `sortA11yLabel(label, order)`，焦點停在該欄首，重建即為播報載體，不另發 `SemanticsService.announce`（S4）；列序改變與 offset 歸零由畫面承載，篩選或排序後的列表重繪無 cross-fade | 無（SPEC-003 §3.4 明訂無動畫） | 指示與朗讀標籤於 `Motion.feedback` 內更新（SPEC-003 §3.4 排序 · 循環列） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用（重建唸出）；不升級系統通知） | unsorted → asc / asc → desc / desc → unsorted（本欄點選）；asc / desc → unsorted（他欄點選，S1） | 反應／時限：UX 審查（SPEC-003 §3.4 S3–S4、動畫提示）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | `sortable`：掛載點：第一層（互動元件層，pressed 態）——第二層不適用（排序為本地已載入資料的重排，SPEC-003 §2.6「0.1 無非狀態級短暫等待」），第三層即結果通知本身（列序改變 + 指示更新 + offset 歸零的狀態轉換，SPEC-003 §2.2 結果通知列），列序由畫面承載。服務類型：本地即時（排序為本地已載入資料的重排，性質同 SPEC-003 §2.12 0.1 實例「篩選選取」）。成功：列序依 `order` 改變，指示更新；失敗：依 SPEC-003 §2.12，本地即時類「不可能失敗（純本地狀態操作）」，故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，排序為本地運算無外部依賴）。輸入阻擋範圍：不阻擋（SPEC-003 §2.12 本地即時類政策）。重複觸發防護：無需——本地狀態操作天然冪等（SPEC-003 §2.12 本地即時類政策）；`static` / `twoLine` 不適用（非互動元素，S7） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.6、§2.12、§3.4）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `sortable`：依 §4.0.7 點選列；`static` / `twoLine`：不適用（純顯示） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父格位（寬，欄寬由所在 `TableRow.header` / `MatrixGrid` 欄規格決定）；高固有 |
| 最小尺寸 | 寬：一字元 + 省略號（一字元見 §4.0.3：`static` 與 `sortable` 取 `label` slot 的 `AppFontSize.caption`；`twoLine` 由第一行 `label` slot 決定，取 `AppFontSize.body`，第二行 `secondLine` slot 的 `AppFontSize.caption` 較小，不決定最小寬；各文字 slot 的超出處置皆為截斷，計省略號；`blank` 無文字 slot，本項不計，寬隨欄寬；`sortable` 排序中（`order` 非 `none`）另加 `Space.xs`（label 與排序指示間距）+ `LayoutSize.iconSm`，`order` 為 `none` 時不渲染指示也不留間距，兩項皆不計——實作 `table_column_header.dart` `_SortableHeaderState.build`，1.101 追認）；高：一行（`twoLine` 兩行）；`sortable` 高不小於 `LayoutSize.hitTargetMin` |
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
| `label` | `String` | `blank` 以外必填；`blank` 無此 slot | 呼叫端（`column*`；`twoLine` 第一行為 UC ID 資料值） |
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
| 朗讀標籤 | `static` / `twoLine`：`Semantics.header`，唸出 label（`twoLine` 唸「{ID}，{名稱}」）；`sortable`：`Semantics.button`，label 為 `sortA11yLabel`（order 代入 `sortNone` / `sortAscending` / `sortDescending`）；`blank`：不產生語意節點（無可朗讀內容） |
| 狀態變化播報 | `sortable` 點選後 `order` 改變時欄首重建，`Semantics.button` 的 label 等於 `sortA11yLabel(label, order)`，`{order}` 依新 `order` 取 `sortNone` / `sortAscending` / `sortDescending`（SPEC-003 §3.4 S4）；焦點停留於該欄首，重建即為播報載體，不另發 `SemanticsService.announce` |
| 非視覺替代訊號 | 排序方向由朗讀標籤的 order 值承載，圖示非唯一訊號 |
| 焦點順序與操作路徑（桌機） | `sortable` 進入 Tab 順序，Space / Enter 觸發；其餘不進入 |
| 對比 | 依 §4.0.2 表 1：label `textSecondary` / `surfaceBase` 4.71:1、`twoLine` 第一行 `textPrimary` / `surfaceBase` 5.79:1、排序指示 `accentStrong` / `surfaceBase` 9.92:1，皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染四個變體 × `sortable` 三種 order
- [ ] `blank`：不含文字與圖示、無語意節點；置於 `TableRow.header` 時該欄寬與同欄資料格相同、列高與其他欄首相同
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
| `direct` | 符號 ●，`AppColors.accent` | 無 | 直接貫穿（判定式見 SPEC-001 §1〈間接依賴判定式〉序 1） |
| `indirect` | 符號 ○，`AppColors.textSecondary` | 無 | 間接依賴（同上序 2：UC 直接貫穿的 X 沿 `bundle_dependency` 往下游可達該格 domain，跳數不限） |
| `none` | 符號 ·，`AppColors.borderStrong` | 無（同樣可選，SPEC-001 §1「無關格亦可選」） | 無關（同上序 3） |

變體由頁面層依 SPEC-001 §1〈間接依賴判定式〉計算後以 `relation` 傳入，本元件不計算；本專案期望分布 `direct` 19／`indirect` 10／`none` 19（SPEC-001 同段）。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 透明底 + 符號 | 點選 | 未選、所在列未高亮 | 點選 → selected；所在列被選 → rowSelected | 資料態：Domain 視圖的選取 provider（選取格 rowId／colId 與選取列 domainId 兩值）——`domainViewStateProvider` 的 `DomainReady.selectedCell` 與 `selectedDomainId`（`lib/app/domain_view_providers.dart`），畫面層算出 `isSelected`／`isRowSelected` 後傳入；畫面層 watch 後經 `MatrixGrid`（資料視圖容器，傳值，不 watch）以 `isSelected` / `isRowSelected` 傳值，元件不 watch（§2 頁面狀態保留：選取格與選取列存於 provider，SPEC-003 §3.1 生命週期） | 本地即時（選取為本地畫面狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| rowSelected | 底 `AppColors.surfaceIconTint`（列高亮，由 `MatrixGrid` 對整列套用）+ 符號 | 點選 | 所在 domain 列為選取列（`action-domain-select-<domainId>` 或選格連動） | 他列被選 → default | 資料態：同上（選取列 domainId 等於本格 rowId） | 本地即時 |
| selected | 底 `AppColors.accent`、符號 `AppColors.surfaceBase`（成對設計，對比通過 §4.0.2；與 rowSelected 可區辨） | 點選（無狀態改變）、Esc 清除 | 單擊本格（SPEC-003 §3.1「選格」） | 點其他格 → default（換選）；Esc / `action-domain-cell-clear` → rowSelected 或 default；點另一列列首 → default（選格清除） | 資料態：同上（選取格等於本格 rowId／colId） | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter）、Esc 清除選取 | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

無 disabled：同形的格不得一部分可點一部分不可點（SPEC-001 §1 註記）。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選格改變 Domain 視圖的選取格，詳情卡顯示於同畫面右欄，不執行命令、不開新視窗 |
| 2 | 套用時點 | (a)–(e) 皆不成立：單一選取；格資料已全數載入；可換選或 Esc 清除；不在需儲存的表單內 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——格常駐於矩陣 |
| 4 | 生效是否當下可見 | 有——右欄詳情卡出現、本格呈 selected，回饋契約關卡二第 2 問答是 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> drag 為容器操作路徑（不可拖曳，觸發 `scroll-domain-matrix` 捲動，SPEC-003 §1.3），非六類回饋事件，由 4.37 `MatrixGrid` 承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay）；指標形狀 `SystemMouseCursors.click`；三個變體（含 `none`）與三個語意狀態皆有 hover（同形的格全部可點，SPEC-001 §1 註記） | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；進入 Tab 內容區段，矩陣內依閱讀順序（SPEC-003 §2.10 `ReadingOrderTraversalPolicy`）；已選格下按 Esc 選取清除、焦點停在原格、矩陣 offset 不變（SPEC-003 §2.10 矩陣已選格列）；朗讀 `semanticLabel` + `selected` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default / rowSelected / selected → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；未選格：呼叫 `onTap` 恰一次，呼叫端執行：`Motion.feedback` 內本格 selected、所在列 rowSelected，`panel-domain-cell-detail-empty` 消失、`panel-domain-cell-detail` 出現且標題為「`<domain 名> × <UC id>`」，矩陣 offset 不變、`IndexedStack` 索引不變（SPEC-003 §3.1 選格列）；換選另一格：前一格失去 selected、新格取得，`scroll-domain-cell-detail` offset 歸零（§3.1 換選列）；已選格再點：仍有 pressed 態但無狀態改變、`onTap` 不呼叫（取消由 Esc 承擔，同一元素不得依狀態改變語意，§3.1 再點同一格列）；`none` 格同「選格」，詳情卡說明為 `cellDetailNotInvolved`（§3.1 無關格列） | Material 內建 ripple；右欄提示 ↔ 詳情卡 cross-fade `Motion.transition` 由畫面承載，本元件不播 | pressed 態出現於 `Motion.feedback` 內；選取態與列高亮於 `Motion.feedback` 內呈現（SPEC-003 §2.2、§3.1 選格列） | §1 子表「按下確認」列 | default / rowSelected → pressed → selected（選格）；selected → pressed → selected（已選格再點）；另一格 selected → default（換選，由呼叫端改傳值） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.1）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.37 `MatrixGrid` 資料格）：0.1 無定位至格的場景——已選格隨內容捲離 viewport 時選取態與右欄內容皆不變、不自動捲回（SPEC-003 §3.1 矩陣捲動列）；矩陣 → 泳道的定位對象是泳道列（`SwimlaneGrid` 以 `jumpTo` 使該列 rect 與 viewport 有交集，§3.1 動畫提示），非本元件；泳道切回矩陣時已選格保留但不執行 scroll-into-view（§3.1 生命週期）；§1 子表 locate 列的適用場景（搜尋命中列、樹節點子項、跨畫面跳轉到節點）皆不落在矩陣格 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：畫面層 watch 選取 provider 後，經 `MatrixGrid` 改 `isSelected` / `isRowSelected` 傳值；含 Esc、`action-domain-cell-clear`、點另一列列首（選格清除）、切換專案（選取格清除，SPEC-003 §3.1 生命週期）等非本格點選引起的改變） | selected 底色 `accent` + 符號 `surfaceBase`、rowSelected 底色 `surfaceIconTint` 的出現／消失為離散替換，選取態本身無入場動畫（持續性標記，SPEC-003 §3.1 動畫提示「矩陣格的選取標記出現」）；`selected` 旗標改變由輔助技術播報（原生旗標，不另組字）；右欄內容更新由詳情卡標題 header 承載（無障礙子節） | 無（SPEC-003 §3.1 明訂選取態無入場動畫；右欄 cross-fade `Motion.transition` 由畫面承載） | `Motion.feedback`（選格引起者，SPEC-003 §3.1 選格列）；清除與換選引起的 default 回復無時限條文（本地即時；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙狀態變化播報適用；不升級系統通知） | default → selected（本格被選）/ selected → default（換選、Esc、關閉、點另一列列首）/ default ↔ rowSelected（所在列被選或他列被選）/ selected → rowSelected（Esc 後所在列仍為選取列） | 反應／時限：UX 審查（SPEC-003 §3.1）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（選格為本地運算無服務受理階段），第三層即結果通知本身（本格轉 selected + `panel-domain-cell-detail` 出現的同畫面狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，詳情卡資料為本地已解析內容，切換耗時落在幾乎即時帶內；失敗形態為不可能失敗，純本地選取運算，SPEC-003 §2.12）。成功：本格轉 selected，詳情卡出現；失敗：依兩軸判定不可能發生（純本地狀態操作），故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，選格為本地運算無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.12、§3.1）；通道：規格撰寫者 |

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
| 非視覺替代訊號 | 關係種類由符號形狀（● ○ ·）與朗讀文字承載，顏色非唯一訊號；選取由 `selected` 旗標承載 |
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
| `active` | 底 `AppColors.accent`、字 `surfaceBase` | 無 | `traverses` 含選中 domain 的步驟（`0.1.0-W3-335.47` D6） |
| `inactive` | 底 `AppColors.surfaceChip`、字 `textPrimary` | 無 | 其餘步驟（未選 domain 時為全部，`0.1.0-W3-335.47` D6） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體 | 無（不可點、不可拖，SPEC-003 §1.3） | 建構 | 不適用：純顯示元件（active / inactive 為變體非狀態） | —（建構即渲染；`label` / `isActive` 由 `SwimlaneGrid`（資料視圖容器）依畫面層傳入值傳值，`isActive` 隨選中 domain 改變時由容器重建本元件（`0.1.0-W3-335.47` D6），元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且明訂無互動——0.1 不可點、不可拖，點擊無反應且無 pressed 態（SPEC-003 §1.3），不進入 Tab 順序（無障礙子節），狀態矩陣僅 default 一列；drag 使元素不移動、觸發 `drag-domain-swimlane` 畫布平移，屬 4.38 `SwimlaneGrid` 的操作路徑；active ↔ inactive 為變體隨選定 UC 重建，不播報（無障礙子節）；§1 子表 locate 列「矩陣 → 泳道」的泳道列定位（`jumpTo`，SPEC-003 §3.1 動畫提示）由 `SwimlaneGrid` 執行，本元件為被定位列內的子件 | — | — | 不適用（drag 平移與泳道列定位由 4.38 `SwimlaneGrid` 承載） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示且明訂無互動（0.1） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（chip） |
| 最小尺寸 | 一字元 + 省略號（一字元見 §4.0.3，取 `label` slot 的 `AppFontSize.body`）+ 2 × `Space.sm` × （`AppFontSize.body` 行高 + 2 × `Space.xs`） |
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 圓形 + 數字 | 無 | 建構 | 不適用：純顯示，無狀態集 | —（建構即渲染；`number` 由呼叫端傳值，元件不 watch 任何 provider，§2） | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且無資料態變更——不可點、不進入 Tab 順序、不播報（無障礙子節），狀態矩陣僅 default 一列；所在列的點擊回饋由 4.35 `TableRow.step` / 4.40 `ListRow.numbered` 承載，序號本身不是回饋事件的主體 | — | — | 不適用（§1 子表六類事件皆由所在列容器承載） | 不適用 | 規格撰寫者 |

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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| collapsed | 向右箭頭 `AppIcon.sm`（`textDisabled`，純裝飾箭頭，§4.0.2 表 2） | 點選 | `isExpanded` 為 `false` 且有子層 | 點選 → expanded | 資料態：受控 `isExpanded` 來自所在畫面的展開集合——追溯視圖為 `expandedTraceNodesProvider`（`StateProvider<Set<String>>`，`lib/screens/trace/trace_providers.dart`）是否含本節點 id；破洞報告分節為頁面 `State`（`_isExpanded`，`lib/screens/gap_report/gap_report_screen.dart`；§2 頁面狀態保留允許的第二種載體，非 provider）；Ticket 清單主題節為 `ticketListStateProvider` 的 `TicketsReady.expandedTopics`（`Set<String>`，鍵為主題或 `unassigned`，`lib/screens/ticket_list/ticket_list_providers.dart`）。容器（4.39 `Tree` / 4.41 `Section`）或頁面層持有後以 `isExpanded` 傳值，元件不 watch（§2 頁面狀態保留：樹展開集合存於 provider） | 本地即時（展開為本地畫面狀態，子層資料已載入，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| expanded | 向下箭頭 | 點選 | `isExpanded` 為 `true` | 點選 → collapsed | 資料態：同上 | 本地即時 |
| leaf | 不渲染箭頭但保留寬度（對齊） | 無 | 無子層 | 不適用：靜止（資料決定，非死胡同） | —（`isLeaf` 由呼叫端依節點資料傳值，建構即決定，非狀態切換） | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 六列皆不適用 leaf：leaf 排除於語意樹、無 `InkWell`（無障礙子節），各列不再逐一註明。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為 `LayoutSize.hitTargetMin` 正方命中區，圓角 `Radius.sm`）；指標形狀 `SystemMouseCursors.click` | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；進入 Tab 內容區段，位於所在列 leading（SPEC-003 §2.10）；朗讀「`expanderLabel`，{所在列主文字}」+ `expanded` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | collapsed / expanded → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onToggle` 恰一次；呼叫端執行：該節點子層出現或消失，所在捲動容器 offset 不歸零（SPEC-003 §3.3 展開收合列、§3.4 主題節展開收合列、§3.5 分節收合列、§1.4） | Material 內建 ripple；子層高度變化 `Motion.transition` 由 4.39 `Tree` / 4.41 `Section` 承載，本元件不播 | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | collapsed → pressed → expanded / expanded → pressed → collapsed | 反應／時限：UX 審查（SPEC-003 §2.2、§3.3、§3.4、§3.5）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.39 `Tree` / 4.41 `Section`）：§1 子表 locate 列適用場景「樹節點展開後的子項」——子項若落在 viewport 外由承載子層的容器執行捲動，機制依 §4.0.10（場景 c：最小捲動、不高亮，焦點停在展開器）；本元件只回呼 `onToggle`，不參與定位；本元件自身不是被定位目標 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：容器或頁面層依展開集合改 `isExpanded` 傳值；含切換專案時展開集合清空（SPEC-003 §3.3 生命週期）等非本元件點選引起的收合） | 箭頭向右 ↔ 向下為離散替換，無旋轉動畫（提案，沿用既有）；`expanded` 旗標改變由輔助技術播報（原生旗標，不另組字，無障礙子節）；子層出現／消失的高度變化由容器承載 | 無（箭頭無旋轉動畫；子層 `Motion.transition` 由容器承載，`disableAnimations` 時瞬間展開，SPEC-003 §3.3 動畫提示） | 無（本地即時，箭頭與 `expanded` 旗標隨 `isExpanded` 同步瞬切；SPEC-003 無箭頭時限條文；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡由容器承載，本元件不適用；無障礙狀態變化播報適用；不升級系統通知） | collapsed → expanded / expanded → collapsed | 反應：規格撰寫者（提案；SPEC-003 §3.3 只定子層高度動畫，未定箭頭過渡）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（展開收合為本地運算無服務受理階段），第三層即結果通知本身（子層出現／消失的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，子層資料已載入、展開為本地重建，SPEC-003 §2.6「0.1 無非狀態級短暫等待」；失敗形態為不可能失敗，純本地展開切換，SPEC-003 §2.12）。成功：子層出現／消失；失敗：依兩軸判定不可能發生（純本地狀態操作），故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，展開收合無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.6、§2.12）；通道：規格撰寫者 |

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
| `testKey` | `Key` | 是（`expander-traceability-<nodeId>` / `expander-tickets-topic-<name>` / `expander-tickets-unassigned` / `expander-gaps-<category>`） | 不適用 |

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

**用途**：可點的節點參照 chip：節點詳情右欄的關聯節點 ID（等寬字，點擊替換主欄，`card-nodeDetail-relation-<nodeId>`）與步驟表的 domain 欄（一般字，點擊 jump 至 Domain 視圖並選取該 domain，`action-ucFlow-goto-domain-<domainId>`）。兩者內容角色相同（節點參照 + 動作），只有目的地不同，依 skill「只是目的地不同者為 slot」合為一件；字型以 `isMono` 參數區分。
**proposed 邊標示**（`0.5.0-W1-103.1`，依 `0.5.0-W1-103` 用戶裁決 2026-10-08：使用中的 proposed 邊在詳情卡與鄰接查詢標示 proposed，`layer` 是穩定性承諾）：關聯右欄的關聯項若來自 `layer` 為 `proposed` 的邊（SPEC-007 FR-08 回傳項的 `layer`；目前只有 `bundle_dependency`），呼叫端傳 `isProposed=true`，chip 尾端加一個 `Badge.category`（tone `warning`，不新增變體，文字 `relationProposedLabel`），朗讀改用 `relationItemProposedA11yLabel`。步驟表 domain 欄不是邊，恆為 `false`。外觀與徽章文案依 `0.5.0-W1-103.1` 用戶裁決 I2（第二輪，2026-10-08）：`Badge.category` 的 warning 色，與 draft／pending 同色，語意同為「未定」；文案 zh「暫定」、en「Proposed」。原提案 `Badge.tag` tone `neutral` 與 chip 同為 `surfaceChip` 底色，區分不出來，故不採。
**內容角色**：數值（ID 或名稱）+ 動作。
**何時不用**：非互動的 ID 顯示（`AppText.mono`）；非節點參照的跨畫面動作（`AppButton`）；非互動的 domain 標籤（`Badge.tag`，節點詳情標籤列）。
**出現畫面**：§6（關聯右欄）、§2（步驟表 domain 欄）、§10（事件列的宣告端與對端欄，`isMono=true`，點擊 jump 至節點詳情並帶入該節點 ID、`returnTo` 設為 `history`，SPEC-003 §3.9）。§10 的對端為 domain 名稱者（`domain_dependency`，SPEC-008 FR-07 規則 4「非節點」）不用本元件，改為 `AppText.mono` 純文字（4.35 `historyEvent`）。§10 不傳 `isProposed`（事件列表示的是邊的增刪，不是目前圖上的邊，`layer` 標示不適用），不外包 `IssueMarker.damagedEdge`。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（damaged 為狀態） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | chip 底 `AppColors.surfaceChip`、mono `textPrimary` | 點選 | 邊完整 | 呼叫端標記損壞 → damaged | 資料態：關聯清單與邊完整性來自所在畫面的節點資料 provider——節點詳情（關聯右欄）為 `nodeDetailNodesProvider` 的 `relations[].nodeIds`／`isProposed`（`lib/screens/node_detail/node_detail_providers.dart`），損壞外觀隨 SPEC-001 §6「部分損壞」在 0.x 不渲染；UC Flow（步驟表 domain 欄）為 `ucFlowUcListProvider` 的 `steps[].domain`（`lib/screens/uc_flow/uc_flow_providers.dart`）；頁面層 watch 後以 `id` 傳值並決定是否外包 `IssueMarker.damagedEdge`，元件不 watch（§2） | 等確認才顯示（關聯清單為解析完成後的資料態，解析未完成前不渲染；§2 樂觀更新政策：0.1 無樂觀操作） |
| damaged | 由 `IssueMarker.damagedEdge` 包住（虛線框；文字維持 `textPrimary`，§4.0.2 帶色表面規則） | 點選（改為跳轉破洞報告，由 `IssueMarker` 承載） | 邊損壞（FR-05） | 重新整理後邊完整 → default | 資料態：同上（該邊的損壞旗標為 `true`；外包由頁面層決定，本元件無 `damaged` 參數） | 等確認才顯示（損壞旗標為解析結果；重新整理後的回復依 SPEC-003 §3.6 三分支於 `Motion.cancelDeadline` 內抵達） |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> damaged 下的點選回饋（跳轉破洞報告）由外包的 4.6 `IssueMarker.damagedEdge` 承載，下表各列只寫 default 下本元件自身的回饋。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為 chip 全幅、圓角 `Radius.md`）；指標形狀 `SystemMouseCursors.click`；`isMono` 兩種字型皆同 | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；進入 Tab 內容區段——關聯右欄依群組閱讀順序、步驟表依列序（SPEC-003 §2.10）；朗讀 `relationItemA11yLabel`（id 代入，無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default → focused → default | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端依目的地執行：關聯右欄——主欄內容替換為該節點、主欄 offset 歸零、右欄 offset 保留、`returnTo` 不變（SPEC-003 §3.6 關聯項列與動畫提示）；步驟表 domain 欄——jump 至 `nav-page-domain` 且該 domain 呈選取態、`returnTo` 設為 `ucFlow`（SPEC-003 §3.2 domain 欄列） | Material 內建 ripple；主欄 cross-fade `Motion.transition` 由畫面承載（關聯右欄）；跨畫面切頁無轉場（`IndexedStack`，SPEC-003 §2.8） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | default → pressed → default（本元件狀態不變；結果落在主欄或另一畫面） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.2、§3.6）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.41 `Section.static` 關聯群 / 4.35 `TableRow.step` domain 欄）：本元件是跳轉的**來源**而非被定位目標——關聯右欄點選後主欄 offset 歸零、右欄 offset 保留（SPEC-003 §3.6 動畫提示），不對本元件執行 scroll-into-view；§3.2「檢視關聯」jump 至節點詳情並「定位於關聯右欄」的對象是右欄本身（由 4.31 `TwoColumnLayout` 右欄承載），非個別關聯項；§1 子表 locate 列「跨畫面跳轉到節點」的定位對象是主欄節點，亦非本元件 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依節點資料的邊損壞旗標決定是否外包 `IssueMarker.damagedEdge`；含重新整理三分支（SPEC-003 §3.6）與關聯項點選後主欄替換引起的右欄重建） | default ↔ damaged：由呼叫端加上／拆除外包的 `IssueMarker.damagedEdge`（虛線框與朗讀標籤由 4.6 承載），本元件自身視覺與朗讀不變、不播報（無障礙子節：damaged 由 `IssueMarker` 朗讀標籤承載）；主欄替換由主欄標題 `Semantics.header` 承載，本元件不播報 | 無（損壞欄位標示靜態不閃爍，SPEC-003 §3.6 動畫提示；主欄 cross-fade 由畫面承載） | 重新整理後的回復於 `Motion.cancelDeadline` 內（SPEC-003 §3.6 三分支）；解析完成當下的標記無時限條文（隨重建瞬切；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報由 4.6 `IssueMarker` 承載；不升級系統通知） | default → damaged（解析判定邊損壞）/ damaged → default（重新整理後邊完整） | 反應／時限：UX 審查（SPEC-003 §3.6）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，pressed 態）——第二層不適用（跳轉為本地運算無服務受理階段），第三層即結果通知本身（主欄內容替換或 `IndexedStack` 可見頁更換 + 該 domain 轉選取態的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，主欄替換資料為本地已解析內容、切頁無載入，SPEC-003 §3.6 動畫提示；失敗形態為不可能失敗，純本地內容替換或頁面切換，SPEC-003 §2.12）。成功：主欄內容替換或切頁至該 domain；失敗：依兩軸判定不可能發生（純本地狀態操作），故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，本地已解析內容無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.2、§3.6）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬，關聯群內）；高固有 |
| 最小尺寸 | 寬：`isProposed=false` 為一字元 + 省略號 + 2 × `Space.sm`；`isProposed=true` 為一字元 + 省略號 + `Space.sm`（`id` 與 badge 間距）+ `Badge.category` 固有寬（4.5〈尺寸契約〉chip 形態；依〈組合規則〉內含元件列，badge 不截斷、不換行，為不可壓縮的固定部分）+ 2 × `Space.sm`（一字元見 §4.0.3，取 `id` slot 的 `AppFontSize.body`，不隨 `isMono` 改變；`id` 的超出處置為截斷，計省略號）；高：`LayoutSize.hitTargetMin` |
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
| `isProposed` | `bool` | 否（預設 `false`；關聯右欄依 SPEC-007 FR-08 回傳項 `layer == proposed` 傳 `true`，不以邊型鍵名判定） | 不適用（尾端 `Badge.category` 文字為 `relationProposedLabel`） |
| `onTap` | `VoidCallback` | 是 | 不適用 |
| `testKey` | `Key` | 是（`card-nodeDetail-relation-<nodeId>` / `action-ucFlow-goto-domain-<domainId>` / `action-history-open-<index>-<side>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceChip`、`textPrimary`（default 與 damaged 同色，損壞由 `IssueMarker` 的虛線框承載）；proposed 標記由 `Badge.category` tone `warning` 承載（`warningSurface` 底、`warning` 字） |
| 間距 | 內距 `Space.sm`（水平）× `Space.sm`（垂直） |
| 字體 | `AppFontSize.body`（mono） |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 朗讀標籤 | `relationItemA11yLabel`；`isProposed=true` 時 `relationItemProposedA11yLabel` |
| proposed 標記 | `relationProposedLabel`（尾端 `Badge.category`） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Section.static`（關聯群項目）；`TableRow.step`（domain 欄，`isMono=false`）；damaged 時外包 `IssueMarker.damagedEdge` |
| 內含元件 | `isProposed=true` 時尾端一個 `Badge.category`（tone `warning`，chip 形態，與 `id` 文字間距 `Space.sm`）；`id` 截斷時 badge 不截斷、不換行 |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 關聯群內填滿寬、文字 `start`；表格欄內固有寬、置中 |
| 作為表格或列表的一欄時 | `TableRow.step` domain 欄：固定寬（`LayoutSize.stepDomainColumnWidth`）、固有寬 chip 置於欄內；內距由容器承載 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為 `relationItemA11yLabel`（id 代入）；`isProposed=true` 時為 `relationItemProposedA11yLabel`（id 代入），尾端 badge 併入此標籤、不另朗讀 |
| 狀態變化播報 | 點選後主欄替換由主欄標題（`Semantics.header`）承載，本元件不播報 |
| 非視覺替代訊號 | damaged 由 `IssueMarker` 的朗讀標籤承載 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（右欄依群組閱讀順序）；Space / Enter 觸發；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：`textPrimary` / `surfaceChip` 4.94:1（default 與 damaged 同值），通過；proposed 標記 `warning` / `warningSurface` 5.29:1，通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / damaged（外包 `IssueMarker.damagedEdge`）
- [ ] 兩種視窗尺寸下不溢位（寬固定於右欄內）
- [ ] 最長測試文案截斷
- [ ] 資料值（zh / en 無差異）不溢位
- [ ] 點選呼叫 `onTap` 恰一次；元件樹被 `InkWell` 包覆
- [ ] `isProposed=true` 時尾端出現 tone `warning` 的 `Badge.category` 且朗讀標籤為 `relationItemProposedA11yLabel`；`isProposed=false` 時兩者皆不出現（對照）；最長測試文案下 badge 不被截斷
- [ ] `isProposed=true` 且寬為最小寬（〈尺寸契約〉最小尺寸列）時，`id` 只剩一字元加省略號、badge 完整
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 渲染 markdown | 捲動（由 `Panel.scrollable` 承載） | 建構 | 不適用：純顯示，無狀態集 | —（建構即渲染；`markdown` 由呼叫端傳值，關聯項點選引起的內容替換由頁面層重建本元件，元件不 watch 任何 provider，§2；節點詳情為 `nodeDetailBodyProvider`（`lib/screens/node_detail/node_detail_providers.dart`）以 `markdown` 傳值） | 本地即時（元件自身；內容為 frontmatter 結尾分隔線之後的本文，見 slot 契約；是否渲染由頁面層等確認才決定） |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本元件為純顯示且無資料態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純顯示且無資料態變更——0.1 連結渲染為一般文字、無 `InkWell`（`onTapLink` 不接線即不渲染為可點，SPEC-003 FR-06 合法形態 a；外部開啟契約 `0.1.0-W1-036` 落於各畫面的「開啟原始檔」動作，非本元件），不進入 Tab 順序（無障礙子節），狀態矩陣僅 default 一列；捲動為 4.30 `Panel.scrollable` 的操作路徑（`scroll-nodeDetail-content`，SPEC-003 §3.6）；關聯項點選引起的內容替換（cross-fade `Motion.transition`、主欄 offset 歸零，SPEC-003 §3.6 動畫提示）由畫面承載並由主欄標題 header 播報，本元件不播報（無障礙子節）；§1 子表 locate 列「跨畫面跳轉到節點」定位的是主欄容器，本元件為其內容 | — | — | 不適用（捲動與內容替換由 4.30 `Panel.scrollable` 與所在畫面承載） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：純顯示（捲動屬所在容器） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固有（依內容，由 `Panel.scrollable` 捲動） |
| 最小尺寸 | 寬：2 × `Space.xs`（自身內距）+ 一字元（一字元見 §4.0.3，取 h1 標題 slot 的 `AppFontSize.title`：段落與標題的超出處置皆為字元邊界換行，每個元素至少容得下自身字級的一字元，故由字級最大的 slot 決定最小寬；換行不截斷，不計省略號）；高：2 × `Space.xs` + 一行 |
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
| `markdown` | `String` | 是 | 呼叫端：原始檔 frontmatter 結尾分隔線之後的本文，不含 frontmatter；切分規則同 SPEC-006 FR-01 切分規則 1–4（Corpus 讀 UC 本文的 flow 區塊時使用同一切分，FR-09） |

**本文來源的界線**（1.141，`1.0.0-W3-673.1`）：

- 呼叫端不得傳入整檔。frontmatter 欄位由主欄分隔線以上的 `ListRow.meta`、`BadgeRow` 承載（見〈何時不用〉），本元件只承載本文；整檔傳入時 frontmatter 會在本文區以段落或 setext 標題重複渲染（`1.0.0-W3-673` 判定 F-4）。
- 讀取或切分失敗時不建構本元件：原始檔不存在或無法讀取、無法以 UTF-8 解碼、無 frontmatter、frontmatter 未閉合，這幾種情況下頁面層改放 `AppText.body`（`multiLine`，`maxLines` 3；文字 `nodeDetailBodyUnavailableMessage`）。不得退回整檔，也不得以節點標題代替本文。呈現與重新判定見 SPEC-001 §6〈主欄分隔線上下的內容〉。

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
| 內容 | 本文（原始檔內容），不經 i18n |
| 讀取或切分失敗時的替代說明（不由本元件渲染，頁面層放 `AppText.body`） | `nodeDetailBodyUnavailableMessage` |

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

**用途**：「這裡目前沒有內容」+ 至少一個非返回的前進動作（SPEC-001 FR-03，`page` 列舉狀態；無破洞與 `section` 例外見 SPEC-003 §2.7）；訊息、說明、動作為 slot。
**內容角色**：內文（訊息 + 說明）+ 動作（經 `ButtonRow`）。
**何時不用**：這個專案不適用本 App，或專案資料載入失敗（`BlockedState`，載入失敗內容見 §3.1 該列與 §3.6；例外：§10 變更記錄的讀取失敗、非 git 專案、找不到 git 用本元件——三者只影響本畫面、不阻擋專案的其他畫面，出口為同畫面的重試或重新檢查，不需 `BlockedState` 的切換專案出口）；原始檔已消失（`MissingSourceState`）；浮層無最近專案（只有一顆 `AppButton.text`，§3.7 第 3 項）。
**出現畫面**：§1（未選專案、空圖、未選格右欄、泳道 · 尚未選定 UC、泳道 · 投影準備中、泳道 · flow 未結構化、圖不可用）、§2（專案未就緒、無 UC、尚未選定 UC、flow 未結構化）、§3（專案未就緒、無提案、圖不可用）、§4（專案未就緒、無 ticket）、§5（專案未就緒、無破洞）、§6（專案未就緒、未選節點、圖不可用、節點不在目前的圖上）、§10（`page`：專案未就緒、非 git 專案、找不到 git、讀取失敗、已取消；`section`：期間內無事件，含「尚無 commit」變體）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `page` | 置中於內容區，訊息 `AppText.subtitle`、說明 `AppText.body`（`secondary`）、`ButtonRow` | SPEC-001 FR-03 列舉狀態與未選專案、未選節點、專案未就緒必填；無破洞（§5）為 0（前進動作於 `SplitRow.header`，見 §3.6 §5 無破洞列）；動作觸發後 jump 或同畫面轉換並設 `returnTo`（SPEC-003 §2.7、`0.1.0-W3-335.37` R10） | 全頁空狀態（八處） |
| `section` | 靠上對齊於所在區塊，訊息 `AppText.body`、說明可缺 | 動作可缺（前進動作在區塊外，如未選格右欄「前進動作即點格，在主欄」，SPEC-003 §3.1；泳道 · 尚未選定 UC 與 §2 尚未選定 UC 前進動作即矩陣點格或右欄選定 UC，泳道 · flow 未結構化前進動作為開啟原始檔／檢視關聯；圖不可用帶重新掃描 `action-domain-rescan`）；有動作時同 `page` | 區塊級：flow 未結構化（與 UC 基本資訊並列）、未選格右欄 `panel-domain-cell-detail-empty`、泳道 · 尚未選定 UC（`state-domain-swimlane-uc-unset`）、泳道 · flow 未結構化（`state-domain-swimlane-unstructured`）、§2 尚未選定 UC（`state-ucFlow-uc-unset`） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 訊息 + 說明（可缺）+ 動作列（`page` 依 §2.7 列舉） | 動作按鈕（`page`）；`section` 無動作時無 | 呼叫端渲染本元件（畫面級進入條件由 SPEC-001 承載） | 動作 → jump 或同畫面轉換（畫面級退出路徑由 SPEC-001 承載）；`section` 無動作時退出在區塊外（點格） | —（建構即渲染；`message` / `explanation` / `actions` 由呼叫端傳值，元件不 watch，§2。是否渲染本元件為畫面級資料態：破洞報告為 `gapReportProvider` 的 `GapReportNoGaps`（`lib/screens/gap_report/gap_report_provider.dart`）、追溯視圖為 `traceabilityStateProvider` 的 `TraceabilityNoProposal`（`lib/screens/trace/trace_providers.dart`）；Domain 視圖為 `domainViewStateProvider` 的 `DomainUnset`／`DomainEmpty` 與 `domainGraphUnavailableProvider`；UC Flow 為 `ucFlowStateProvider` 的 `UcFlowEmpty`／`UcFlowUcUnset`／`UcFlowUnstructured`；Ticket 清單為 `ticketListStateProvider` 的 `TicketsEmpty`；節點詳情為 `nodeDetailEffectiveStateProvider` 的 `NodeDetailUnset`／`NodeDetailGraphUnavailable`／`NodeDetailNodeAbsent`） | 本地即時（元件自身）；是否渲染由頁面 provider 等確認才決定（空狀態是解析或掃描完成後的判定，§2 樂觀更新政策：0.1 無樂觀操作） |

元件自身只有一個狀態；空狀態的畫面級進出（`state-<screen>-empty` 等錨點）由呼叫端承載。互動瞬態（hover / pressed / focused）由動作按鈕 4.4 `AppButton` 承載，本元件不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 動作按鈕的 affordance／focus／press-ack 依 4.4 `AppButton` 回饋契約，下表只寫本元件層級的補充；`section` 無動作時前三列不適用（無可互動子件）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 動作按鈕經 4.4 `AppButton`（hover 態、`SystemMouseCursors.click`）；訊息與說明文字無 hover、指標形狀預設 | 無（Material 內建，經 `AppButton`） | 無（同 4.4） | §1 子表「可互動提示」列（由 4.4 `AppButton` 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 動作按鈕經 4.4 `AppButton` 進入 Tab 內容區段（SPEC-003 §2.10）；訊息為 `Semantics.header`、說明接續，皆非停留點；`section` 無動作時無停留點（無障礙子節） | 無 | 無（同 4.4） | §1 子表「焦點」列（由 4.4 `AppButton` 承載） | 不適用（本元件單一狀態） | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 動作按鈕經 4.4 `AppButton`（pressed 態 + ripple，callback 恰一次）；呼叫端執行：jump 至目標畫面並設 `returnTo`（SPEC-003 §2.4、§2.7 空狀態動作列），或同畫面轉換（選擇資料夾 → 系統選擇器 → `state-domain-loading`，選擇器被取消則維持 `state-domain-unset` 且不出現 SnackBar，SPEC-003 §3.1） | Material 內建 ripple（經 `AppButton`）；狀態間 cross-fade `Motion.transition` 由畫面承載 | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2，經 4.4） | §1 子表「按下確認」列（由 4.4 `AppButton` 承載） | 不適用（結果為畫面級轉換，本元件單一狀態） | 反應／時限：UX 審查（SPEC-003 §2.2、§2.7、§3.1）；通道：規格撰寫者 |
| 定位提示 locate | 系統 | 一處場景：系統通知點擊導向且結果為 `state-gaps-none` 時，焦點移入本元件根節點、不高亮（SPEC-003 §2.2「點擊通知的導向」列）；焦點移入由頁面層（`ScanNotifier.activated` 消費者）執行，機制依 §4.0.10（觸發者、輔助技術與定位失敗列），本元件根節點須可接受焦點（`Focus` 節點，`skipTraversal: true` 不佔 Tab 順序；提案，SPEC-003 只定焦點落點未定載體）。其餘空狀態 0.1 無定位場景（由 4.28 `PageColumn` / 4.30 `Panel` 承載） | 無（不高亮） | 無（SPEC-003 §2.2 未設焦點移入時限；提案） | §1 子表「定位提示」列（輔助技術：焦點移入被定位項；視覺高亮不適用） | 不適用 | 反應：規格撰寫者（提案；SPEC-003 §2.2 定落點）；通道：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依畫面 provider 於前一狀態 → 空狀態時渲染本元件並播放 cross-fade；含載入完成、掃描完成、切換專案後重判等） | 進入本狀態時訊息以 `liveRegion` 播報一次（無障礙子節，提案）；自前一狀態 cross-fade（SPEC-003 各 §3.x 動畫提示）由畫面承載；本元件單一狀態，無內部過渡 | `Motion.transition`（由畫面承載；`disableAnimations` 下歸零，SPEC-003 §2.1） | 無（SPEC-003 各 §3.x 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡由畫面承載；無障礙播報適用（`liveRegion` 一次）；不升級系統通知——`state-gaps-none` 的升級由頁面層依 SPEC-003 §2.2「系統層通知」承載，本元件只是導向的落點） | 不適用（本元件單一狀態；畫面級狀態邊由 SPEC-001 承載） | 反應：規格撰寫者（`liveRegion` 提案，沿用無障礙子節）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層）由動作按鈕 4.4 `AppButton` 承載，本元件不另有自身互動層——第二層與第三層依 `actions` 內容而定：jump 類為第三層即結果通知本身（可見頁更換）；選擇資料夾類的第二層委派 4.24 `LoadingState`（`state-domain-loading` 出現）。服務類型：不固定——本元件的動作按鈕依 `actions` 內容而定，可能是本地即時（jump 類，兩軸：使用者感知等待為零、不可能失敗）或長時操作（選擇資料夾類，觸發 4.24 承載的服務受理與結果，兩軸：使用者感知等待秒至分鐘、可能失敗）；第一層本身不隨服務類型變動（SPEC-003 §2.12）。成功：依動作類型而定——jump 類為可見頁更換；長時操作類為 4.24 完成載入後的目標態；失敗：jump 類不可能發生（本地狀態操作）；長時操作類由 4.24 依政策呈現，本元件不重述；逾時：同失敗段之對應分支；服務不可用：同失敗段之對應分支。輸入阻擋範圍：不適用於本元件——jump 類不阻擋；長時操作類由 4.24 依政策阻擋頁面內容（SPEC-003 §2.12），非本元件自行阻擋。重複觸發防護：不適用於本元件——依不變式 INV-FEEDBACK-001，動作按鈕每次按下皆無條件回應，防護判斷在服務層（SPEC-003 §2.12） | Material 內建（經 `AppButton`） | `Motion.feedback`（經 4.4） | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12）；通道：規格撰寫者 |

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
| `actions` | `List<AppButton>`（0..3） | `page`：SPEC-001 FR-03 列舉狀態與未選專案、未選節點、專案未就緒必填（1..3，首個非 `backAction`）；無破洞（§5）為 0（前進動作於 `SplitRow.header`）；`section` 可空（`0.1.0-W3-335.37` R10） | 不適用 |
| `testKey` | `Key` | 是（`state-<screen>-<state>` / `panel-domain-cell-detail-empty` / `panel-history-empty`——§10 期間內無事件的狀態根錨點 `state-history-empty` 在外層 `Panel` 的 `panelKey`，故 `section` 另取 panel 錨點） | 不適用 |

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
| `message` | 呼叫端傳入：`emptyGraphMessage` / `emptyUcMessage` / `flowUnstructuredMessage` / `flowParseFailedMessage`（§4.0.6，`0.5.0-W1-114.1`） / `emptyProposalMessage` / `emptyTicketsMessage` / `noGapsMessage` / `noNodeSelectedMessage`（既有）、`cellDetailPrompt`、`projectUnreadyReasonNotSelected` / `projectUnreadyReasonLoading` / `projectUnreadyReasonIncompatible`（五畫面共用，依 Domain 視圖當時的狀態三選一，見 §4.0.6〈1.36 新增〉表）、`ucUnsetPrompt`（§2 尚未選定 UC，§4.0.6 新 key 總表 1.35）、`swimlaneUcUnsetPrompt`（泳道 · 尚未選定 UC，同上）；未選專案的訊息由畫面票宣告 |
| `explanation` | `noGapsScanScope`（既有）等 |
| 動作 | 經 `AppButton`（`chooseWorkspaceFolder` / `gotoGapsReportAction` / `gotoTraceabilityAction` / `openDocsFolderAction` / `openSourceFileAction` / `viewRelationsAction` / `gotoDomainViewAction`；`rescanAction` 已移出本元件動作列，改於 `SplitRow.header` 承載，見 §3.6 §5 無破洞列，`0.1.0-W3-335.37` R10；`backToDomainAction` 已隨 `action-ucFlow-back-to-domain` 移除，`0.1.0-W3-335.37` R7） |

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

- [ ] 一支測試渲染 `page`（零／一／二／三個動作，零動作限無破洞狀態）與 `section`（有／無動作、有／無說明）
- [ ] 兩種視窗尺寸下不溢位；`page` 內容置中
- [ ] 最長測試文案：訊息兩行末截斷、說明四行末截斷
- [ ] zh / en 全部既有 message key 皆不溢位
- [ ] `page` 動作非空時首個動作 label 不等於 `backAction`（FR-03 斷言，SPEC-001 FR-03 列舉狀態與未選專案、未選節點適用）；零動作限無破洞狀態，不觸發此斷言；動作點選呼叫 callback 恰一次
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「這個專案不適用本 App」、專案資料載入失敗 | `BlockedState` |
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 訊息 `AppText.subtitle` + 路徑 `AppText.mono`（`secondary`）+ `ButtonRow`[重新整理 `primary`]（本元件動作列只含重新整理，返回鍵由頁面框架於 `SplitRow.header` 統一渲染，見下方「回饋契約」與「slot 契約」） | 重新整理 | 呼叫端渲染（`state-nodeDetail-missing`） | 重新整理 → 三分支（仍不存在：維持 + SnackBar；完整 → normal；斷點 → partial）；返回 → 由頁面框架的返回鍵導向 `returnTo`（SPEC-003 §3.6） | —（建構即渲染；`path` 由呼叫端傳值，元件不 watch，§2。是否渲染本元件為節點詳情畫面的資料態（`state-nodeDetail-missing`），由 `nodeDetailEffectiveStateProvider` 的 `NodeDetailMissing(nodeId, lastKnownPath)` 判定，`path` 取 `lastKnownPath`） | 本地即時（元件自身）；是否渲染由頁面 provider 等確認才決定（開啟原始檔回 `notFound` 或重新整理三分支，SPEC-003 §3.6；§2 樂觀更新政策：0.1 無樂觀操作） |

互動瞬態（hover / pressed / focused）由重新整理按鈕 4.4 `AppButton` 承載，本元件不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 返回（`action-nodeDetail-back`）依 SPEC-003 §2.3 規則 4 由頁面框架渲染於 `SplitRow.header`，本元件不重複渲染，其回饋不在下表。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 重新整理按鈕經 4.4 `AppButton`（hover 態、`SystemMouseCursors.click`）；訊息與路徑文字無 hover | 無（Material 內建，經 `AppButton`） | 無（同 4.4） | §1 子表「可互動提示」列（由 4.4 `AppButton` 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 重新整理按鈕經 4.4 `AppButton` 進入 Tab 內容區段（SPEC-003 §2.10）；訊息為 `Semantics.header`、路徑接續唸出全文，皆非停留點（無障礙子節） | 無 | 無（同 4.4） | §1 子表「焦點」列（由 4.4 `AppButton` 承載） | 不適用（本元件單一狀態） | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 重新整理按鈕經 4.4 `AppButton`（pressed 態 + ripple）；呼叫 `onRefresh` 恰一次；呼叫端執行重新解析三分支：仍不存在 → 維持本狀態 + `AppSnackBar.plain`（`sourceFileStillMissingMessage`，停留 `Motion.snackBar`）；完整 → `state-nodeDetail-normal`；存在但 frontmatter 解析失敗 → 維持本狀態 + `AppSnackBar.plain`（`sourceFileUnparsableMessage`，停留 `Motion.snackBar`）；斷點 → `state-nodeDetail-partial` 在 0.x 不可達（SPEC-003 §3.6 重新整理三分支、〈部分損壞在 0.x 不可達〉） | Material 內建 ripple（經 `AppButton`）；轉態 cross-fade `Motion.transition` 由畫面承載 | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2，經 4.4）；三分支皆於 `Motion.cancelDeadline` 內抵達（SPEC-003 §3.6） | §1 子表「按下確認」列（由 4.4 `AppButton` 承載） | 不適用（結果為畫面級轉換或 SnackBar，本元件單一狀態） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.6）；通道：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.28 `PageColumn`）：0.1 無定位至本元件的場景——本狀態為全頁內容且由使用者操作進入，不落在 §1 子表 locate 列的適用場景 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依節點資料 provider 於開啟原始檔回 `notFound` 時渲染本元件（SPEC-003 §3.6 開啟原始檔（檔案不存在）列，狀態轉換即回饋、不出現 SnackBar），三分支轉出時拆除） | 進入本狀態時訊息以 `liveRegion` 播報一次（無障礙子節，同 4.21）；自 normal / partial cross-fade（SPEC-003 §3.6 動畫提示）由畫面承載；重新整理仍不存在時由 SnackBar 播報（無障礙子節），本元件維持不變、不重播 | `Motion.transition`（由畫面承載；`disableAnimations` 下歸零，SPEC-003 §2.1） | 無（SPEC-003 §3.6 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡由畫面承載；無障礙播報適用（`liveRegion` 一次）；不升級系統通知） | 不適用（本元件單一狀態；畫面級狀態邊 normal / partial → missing 由 SPEC-001 §6 承載） | 反應：規格撰寫者（`liveRegion` 提案，沿用無障礙子節）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層）由重新整理按鈕 4.4 `AppButton` 承載，本元件不另有自身互動層——第二層不適用（單檔重新整理不套用批次載入態），第三層即結果通知本身：轉態者為狀態轉換本身（normal；partial 在 0.x 不可達），狀態不變者為 4.26 `AppSnackBar.plain`（`sourceFileStillMissingMessage` 或 `sourceFileUnparsableMessage`）。服務類型：短暫非同步（依兩軸判定：使用者感知的等待為亞秒級，三分支直接於 `Motion.cancelDeadline` 內抵達、不套用批次載入態；失敗形態為可能失敗，重新整理後仍找不到檔案時經 SnackBar 通知，SPEC-003 §2.12、§3.6）。成功：重新解析完整 → `state-nodeDetail-normal` 狀態轉換（解析有斷點 → `state-nodeDetail-partial` 在 0.x 不可達，SPEC-003 §3.6）；失敗：仍不存在 → 維持本狀態 + 4.26 `AppSnackBar.plain`（`sourceFileStillMissingMessage`）；存在但 frontmatter 解析失敗 → 維持本狀態 + 4.26 `AppSnackBar.plain`（`sourceFileUnparsableMessage`）；逾時：`Motion.cancelDeadline` 保證三分支之一必於期限內抵達，不逾時停滯；服務不可用：同失敗段（檔案系統層級不可用亦歸入「仍不存在」分支處理，無獨立表現）。輸入阻擋範圍：不阻擋（短暫非同步類政策，SPEC-003 §2.12）。重複觸發防護：冪等——重複觸發重新整理為合法操作（短暫非同步類政策，SPEC-003 §2.12） | Material 內建（經 `AppButton`）；SnackBar 進出 Material 預設（4.26） | `Motion.cancelDeadline`（結果抵達上限）；SnackBar 停留 `Motion.snackBar` | §1 子表「等待與結果」列 | 不適用 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.12、§3.6）；通道：規格撰寫者 |

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
| `message` | 否（`AppText.subtitle` 契約鎖定單行，4.1 已核定行為） | 1 | 末行截斷 | `sourceFileMissingMessage`（en「Source file no longer exists」）；`TestCopy.longZh` |
| `path` | 否（`AppText.mono` 契約鎖定單行，4.1 已核定行為） | 1 | 末行截斷 | `lastKnownPathLabel`（path 代入 `TestCopy.filePath`）；`TestCopy.longToken` |

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

**用途**：「這個專案不適用本 App」+ 版本值（不是框架專案無）+ 說明 + 切換專案出口（恆可用，SPEC-001 FR-07）；無可消費的型別表時另提供「以 App 內建型別表檢視」條件式渲染出口（`action-domain-degraded-view`，`VERSION` 不高於內建表產生版本時渲染，SPEC-003 §3.1，`0.1.0-W1-035` 定案）；載入失敗時另提供「重新載入」出口（`action-domain-reload`，SPEC-001 §1「載入失敗」列，`0.5.0-W1-114.14.1`）。
**內容角色**：內文（訊息 + 說明）+ 數值（版本值）+ 動作。
**何時不用**：這裡沒有內容（`EmptyState`）；暫時性錯誤提示（`AppSnackBar`）。
**出現畫面**：§1（不是框架專案、無可消費的型別表、schema 不相容、載入失敗）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `plain` | 訊息 + 說明（可缺）+ 版本值（可缺）+ `ButtonRow`[切換專案 `primary`；無可消費的型別表且 `VERSION` 條件成立時另加「以 App 內建型別表檢視」`AppButton.secondary`（`action-domain-degraded-view`，條件式渲染，依 SPEC-003 §3.1）；載入失敗時另加「重新載入」`AppButton.secondary`（`action-domain-reload`，`onReload` 非 null 時渲染）] | 無展開；`action-domain-degraded-view`、`action-domain-reload` 觸發同畫面轉換，不改變本元件狀態（元件隨畫面轉換一併消失） | 不是框架專案、無可消費的型別表、載入失敗 |
| `withDetail` | 加 `AppButton.secondary`「檢視詳情」（`action-domain-schema-detail`）與可展開的 `Section.static`[`AppText.caption`, `AppText.mono`]（`panel-domain-schema-detail`，內容為「App 已知版本範圍：不高於 <內建版本>」一列） | 展開／收合（再次點擊或 Esc） | schema 不相容 |

`withDetail` 面板改放本體沒有的資訊（`0.1.0-W3-335.37` R4 的重評條件於「App 已知範圍」判準定案時觸發，SPEC-001 v1.19 §1 註記為重評結果）：本體 `message`（`schemaIncompatibleMessage`）已代入 `appVersion` / `projectVersion` 兩值；面板原為同兩值的帶標籤單行版本（R4 判為有意冗餘），現改為一列小標 `schemaKnownRangeLabel` + 值 `schemaKnownRangeValue`（代入 `appVersion`），告知「已知範圍」的判準（上界為 App 內建型別表產生版本，不高於者可載入），不再重複兩個版本值。`projectVersion` 為推定值（呼叫端 `isVersionInferred`）時本體與面板字面不變，推定來源由 4.27 `AppShell` 的 `badge-<screen>-inferred-version` 承載，本元件不另標示。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| collapsed | 依變體，詳情面板不存在 | 切換專案；`withDetail`：檢視詳情；`plain`（無可消費的型別表，`VERSION` 條件成立時）：以 App 內建型別表檢視；`plain`（載入失敗）：重新載入 | 呼叫端渲染 | 切換專案 → 浮層展開（覆蓋層，不改變本狀態）；檢視詳情 → expanded；重新載入 → 同畫面轉換至 `state-domain-loading`（同一資料夾、同一模式，SPEC-003 §3.1）；以 App 內建型別表檢視 → 同畫面轉換至 `state-domain-matrix` 或 `state-domain-empty`（疊加 `badge-domain-degraded-schema`，不經 `state-domain-loading`，SPEC-003 §3.1） | 資料態：受控 `isDetailExpanded` 存於 Domain 視圖頁面層（slot 契約：§2 頁面狀態保留）——`domainViewStateProvider` 的 `DomainSchemaIncompatible.isDetailExpanded`（`lib/app/domain_view_state.dart`），經 `copyWith(isDetailExpanded:)` 切換；頁面層 watch 後以 `isDetailExpanded` 傳值，元件不 watch。是否渲染本元件（三個阻擋狀態與載入失敗）同為該畫面 provider 的資料態 | 本地即時（面板開合為本地畫面狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作）；是否渲染由頁面 provider 等確認才決定（阻擋判定為載入完成後的結果） |
| expanded（`withDetail`） | 詳情面板出現於同一狀態根節點內，含「App 已知版本範圍：不高於 <內建版本>」一列 | 同上 + 再次點擊 / Esc 收合 | 點擊檢視詳情 | 再次點擊 / Esc → collapsed（SPEC-003 §1.4、§2.10） | 資料態：同上（`isDetailExpanded` 為 `true`） | 本地即時 |

互動瞬態（hover / pressed / focused）由切換專案、檢視詳情、降級檢視（`action-domain-degraded-view`，條件式渲染）各 4.4 `AppButton` 承載，本元件不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 兩顆按鈕經 4.4 `AppButton`（hover 態、`SystemMouseCursors.click`）；切換專案出口於三個阻擋狀態下恆為 enabled、恆有 hover（SPEC-003 §2.7 浮層可用性斷言）；訊息、說明、版本值、面板內容無 hover | 無（Material 內建，經 `AppButton`） | 無（同 4.4） | §1 子表「可互動提示」列（由 4.4 `AppButton` 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 兩顆按鈕經 4.4 `AppButton` 進入 Tab 內容區段（SPEC-003 §2.10）；expanded 時按 Esc 面板收合、其餘狀態不變（SPEC-003 §2.10 `panel-domain-schema-detail` 收合後列），焦點停在 `action-domain-schema-detail`（引用 SPEC-003 §2.10 新列，非提案）；訊息為 `Semantics.header`、版本值接續；檢視詳情按鈕 `expanded` 等於 `isDetailExpanded`（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列（由 4.4 `AppButton` 承載） | collapsed / expanded →（按鈕 focused）→ 原狀態；expanded → Esc → collapsed | 反應：UX 審查（SPEC-003 §2.10）；Esc 後焦點落點：SPEC-003 §2.10 新列（`0.1.0-W3-335.38` S-16）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 切換專案：經 4.4 `AppButton`（pressed 態 + ripple），呼叫 `onSwitchProject` 恰一次，呼叫端開啟 `SwitcherOverlay`（`state-switcher-expanded` 或 `state-switcher-no-recent` 出現，不改變 `IndexedStack` 索引，SPEC-003 §2.7 阻擋狀態動作列、§3.7）；檢視詳情（`withDetail`）：經 4.4 `AppButton`，呼叫 `onToggleDetail` 恰一次，呼叫端改 `isDetailExpanded`，`panel-domain-schema-detail` 出現／消失（SPEC-003 §3.1 檢視 schema 詳情列） | Material 內建 ripple（經 `AppButton`）；浮層 `Motion.overlay` 由 4.42 `SwitcherOverlay` 承載；面板高度變化 `Motion.transition`（SPEC-003 §3.1 動畫提示） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2，經 4.4）；浮層出現於 `Motion.overlay` 內（SPEC-003 §3.7 動畫提示） | §1 子表「按下確認」列（由 4.4 `AppButton` 承載） | collapsed → pressed（檢視詳情）→ expanded / expanded → pressed → collapsed；切換專案不改變本狀態（浮層為覆蓋層） | 反應／時限：UX 審查（SPEC-003 §2.2、§2.7、§3.1、§3.7）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.28 `PageColumn`）：0.1 無定位至本元件的場景——阻擋狀態為全頁內容；面板展開後若超出 viewport 由 `PageColumn` 的捲動承載，不對面板執行 scroll-into-view（SPEC-003 §3.1 未定義；提案）；後續版本若新增定位至本元件的場景，機制依 §4.0.10 | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依 `isDetailExpanded` 改傳值，含 Esc 引起的收合；進入本狀態由頁面層依載入結果渲染） | collapsed ↔ expanded：面板高度變化 `Motion.transition`（SPEC-003 §3.1 動畫提示「`panel-domain-schema-detail` 展開」），面板展開由檢視詳情按鈕的 `expanded` 旗標播報（無障礙子節）；進入本狀態時訊息以 `liveRegion` 播報一次（無障礙子節）；自 `state-domain-loading` cross-fade `Motion.transition`（SPEC-003 §3.1 動畫提示「載入中 → 三個阻擋狀態」）由畫面承載 | `Motion.transition`（面板高度，本元件承載；進入本狀態的 cross-fade 由畫面承載；`disableAnimations` 下皆歸零，SPEC-003 §2.1） | 無（SPEC-003 §3.1 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（面板）；無障礙播報適用（`expanded` 旗標、進入時 `liveRegion` 一次）；不升級系統通知） | collapsed → expanded（檢視詳情）/ expanded → collapsed（再次點擊、Esc） | 反應：UX 審查（SPEC-003 §3.1）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層）由兩顆 4.4 `AppButton` 承載，本元件不另有自身互動層——第二層不適用（浮層開合與面板展開皆無服務受理階段），第三層即結果通知本身（浮層出現 / 面板出現的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，面板值為載入時已判定的資料、浮層清單為本地 fixture／已探測結果；失敗形態為不可能失敗，純本地開合切換，SPEC-003 §2.12、§3.7）。成功：浮層出現或面板展開／收合；失敗：依兩軸判定不可能發生（純本地狀態操作），故本元件無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，開合切換無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建（經 `AppButton`）；`Motion.overlay`（浮層，由 4.42 承載） | `Motion.feedback`（經 4.4） | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.7、§2.12）；通道：規格撰寫者 |

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
| `explanation` | 是 | 4 | 末行截斷 | `notFrameworkProjectExplanation`（zh 較長，不是框架專案）／`schemaUnconsumableDegradedExplanation`（無可消費的型別表降級時，`0.1.0-W3-335.57` E2）；`TestCopy.longEn` |
| `version`（`plain` 的版本值） | 否 | 1 | 截斷 | 人工值 `2.42.1-rc.1+build.20260902`；`TestCopy.longToken` |
| 詳情面板範圍值（`schemaKnownRangeValue`） | 否 | 1 | 截斷 | 同上（`appVersion` 代入 `2.42.1-rc.1+build.20260902`） |
| 面板小標（`schemaKnownRangeLabel`） | 否 | 1 | 截斷 | `schemaKnownRangeLabel`（en「Supported schema version range」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`notFrameworkProjectMessage` / `schemaUnconsumableMessage` / `schemaIncompatibleMessage` / `schemaVersionUnreadableMessage` / `domainLoadFailedMessage`（載入失敗，§4.0.6〈1.86 新增〉）） |
| `explanation` | `String?` | 無可消費的型別表且 `onDegradedView` 非 null 時為降級說明必填，其餘否 | 呼叫端（`notFrameworkProjectExplanation`；無可消費的型別表降級說明改 `schemaUnconsumableDegradedExplanation`，新增，`0.1.0-W3-335.57` E2） |
| `version` | `String?` | 無可消費的型別表時必填（FR-07 顯示專案 `.claude/VERSION` 值） | 呼叫端（專案 `.claude/VERSION`，`0.1.0-W3-335.57` E2） |
| `appVersion` / `projectVersion` | `String`（`withDetail`） | `withDetail` 必填 | 呼叫端（資料值） |
| `onSwitchProject` | `VoidCallback` | 是 | 不適用 |
| `onDegradedView` | `VoidCallback?` | 無可消費的型別表且 `VERSION` 條件成立時必填，其餘 `null`（不渲染） | 不適用 |
| `onReload` | `VoidCallback?` | 載入失敗時必填，其餘 `null`（不渲染，`0.5.0-W1-114.14.1`） | 不適用 |
| `isDetailExpanded` / `onToggleDetail` | `bool` / `VoidCallback`（`withDetail`） | `withDetail` 必填（展開狀態存於頁面層，§2 頁面狀態保留） | 不適用 |
| `testKey` | `Key` | 是（`state-domain-not-framework` / `state-domain-schema-unconsumable` / `state-domain-schema-incompatible` / `state-domain-load-failed`；本體重新載入按鈕另計 `action-domain-reload`（僅載入失敗）；本體切換專案按鈕於四個狀態皆渲染，另計 `action-domain-switch-project`，與 `project-switcher-entry` 同結果，`0.1.0-W3-335.57` E9） | 不適用 |

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
| 訊息 / 說明 | `notFrameworkProjectMessage` / `notFrameworkProjectExplanation` / `schemaUnconsumableMessage` / `schemaIncompatibleMessage`（既有，呼叫端傳入）／`domainLoadFailedMessage`（新增，呼叫端傳入，§4.0.6〈1.86 新增〉）／`schemaUnconsumableDegradedExplanation`（新增，§4.0.6 新 key 總表，`0.1.0-W3-335.57` E2） |
| 切換專案 | `projectSwitcherEntryLabel`（既有，元件預設，參數可覆蓋） |
| 以 App 內建型別表檢視 | `useBuiltinSchemaAction`（新增，元件預設，§4.0.6 新 key 總表） |
| 重新載入 | `reloadAction`（新增，元件預設，§4.0.6〈1.86 新增〉） |
| 檢視詳情 | `viewSchemaDetailAction`（既有，元件預設） |
| 面板小標 / 面板值 | `schemaKnownRangeLabel` / `schemaKnownRangeValue`（新增，元件預設，§4.0.6〈1.45 新增〉；取代原 `schemaAppVersionLabel` / `schemaProjectVersionLabel`） |

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

- [ ] 一支測試渲染 `plain`（有／無版本值、有／無說明、有／無 `onDegradedView`）與 `withDetail`（collapsed / expanded）
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息三行、說明四行末截斷、版本值截斷
- [ ] zh / en 五個訊息 key 皆不溢位（含 `useBuiltinSchemaAction`）
- [ ] 切換專案呼叫 `onSwitchProject` 恰一次；`onDegradedView` 非 null 時呼叫恰一次；檢視詳情切換 `panel-domain-schema-detail` 存在性；expanded 下 Esc 收合、焦點停在 `action-domain-schema-detail`
- [ ] `find.byKey(AppShell.projectSwitcherEntryKey)` 存在且 enabled（與殼整合的畫面測試承接）
- [ ] 間距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 「此專案尚無圖譜節點」 | `EmptyState.page` |
| 「以純檔案模式檢視」（舊構想的降級策略措辭） | `0.1.0-W1-035` 已改為「以 App 內建型別表檢視」（`action-domain-degraded-view`），非本元件的獨立降級樣式，見 `plain` 變體 |

### 4.24 LoadingState

**用途**：骨架或進度 + 計數文字 + 取消；取消契約 C1–C8 與生命週期 L1–L2（SPEC-003 §2.5、§2.8，共 10 條）由本元件單一承擔，三處以目標態、進度型別與骨架版位差異化（SPEC-003 §2.11）。
**內容角色**：內文（訊息 + 計數）+ 數值（進度）+ 動作（取消）。
**何時不用**：非狀態級的短暫等待（0.1 無，SPEC-003 §2.6）；按鈕內 spinner（禁止，§2.2）。
**出現畫面**：§1（載入中）、§5（掃描中）、§10（讀取中，1.131）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `skeleton` | 骨架版位（`matrix` / `sections` / `rows` slot）shimmer + indeterminate + 計數文字 | 分母未知：不顯示百分比、不顯示預估、不自行推進（SPEC-003 §2.6 誠實性硬規則） | `state-domain-loading`（版位 `matrix`）、`state-gaps-scanning`（版位 `sections`）、`state-history-loading`（版位 `rows`：與 `TableRow` 同高的骨架列堆疊，對應事件清單版面；1.131） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| loading | 依變體；取消鈕 `AppButton.secondary` enabled，label `cancelLoadingAction` / `cancelScanAction` | 取消（C1：恆可用，含第一幀） | 呼叫端渲染 | 完成 → 目標正常態（呼叫端）；取消 → cancelling | 資料態：三處各自的載入 provider——破洞掃描為 `gapReportProvider`（`NotifierProvider<GapReportNotifier, GapReportState>`，`lib/screens/gap_report/gap_report_provider.dart`）的 `GapReportScanning`（`processedCount` → `countText`、`isCancelling` 為 `false`，`lib/screens/gap_report/gap_report_models.dart`）；Domain 視圖為 `domainViewStateProvider` 的 `DomainLoading`（`isCancelling`；`processedCount` 轉為 `countText`）；Ticket 清單無載入態，不渲染本元件；頁面層 watch 後以 `progress` / `countText` / `isCancelling` 傳值，元件不 watch（§2） | 等確認才顯示（進度值與計數為資料層實際已處理數，不得自行推進、不得顯示預估，SPEC-003 §2.6 誠實性硬規則；§2 樂觀更新政策：0.1 無樂觀操作） |
| cancelling | 版面不變、進度改 indeterminate、計數凍結於最後值（C3）；取消鈕 `enabled=false`、label `cancelInProgressAction`（C2） | 無 | 按下取消 | `Motion.cancelDeadline` 內抵達目標態（C4：`state-domain-unset` / `returnTo` 或 `nav-page-domain`） | 資料態：同上（`isCancelling` 為 `true`） | 本地即時（C2：按下取消後 `Motion.feedback` 內即轉 `isCancelling`，不等資料層確認）；抵達目標態則等確認才顯示（C4：資料層完成中止後由呼叫端轉態） |

互動瞬態（hover / pressed / focused）由取消鈕 4.4 `AppButton` 承載，本元件不另列；骨架與進度條為非互動元素。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本元件即 §1 子表「等待與結果」列三層中的**等待指示**層本身（SPEC-003 §2.2 畫面級載入態、§2.6）；取消契約 C1–C8 與生命週期 L1–L2（SPEC-003 §2.5、§2.8）分配至下表各列，不另立互動表。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 取消鈕經 4.4 `AppButton`（loading：hover 態、`SystemMouseCursors.click`；cancelling：disabled 無 hover overlay，§4.0.1 disabled 列）；骨架、進度條、訊息、計數無 hover | 無（Material 內建，經 `AppButton`） | 無（同 4.4） | §1 子表「可互動提示」列（由 4.4 `AppButton` 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 取消鈕經 4.4 `AppButton` 進入 Tab 內容區段，C1 期間恆可聚焦（SPEC-003 §2.5、§2.10）；cancelling 時 disabled 不可聚焦；骨架區朗讀 `loadingSkeletonA11yLabel`（無障礙子節），非停留點 | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列（由 4.4 `AppButton` 承載） | loading →（取消鈕 focused）→ loading | 反應：UX 審查（SPEC-003 §2.5 C1、§2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 取消鈕經 4.4 `AppButton`（pressed 態 + ripple）；`Motion.feedback` 內取消鈕 `enabled=false` 且 label 換為 `cancelInProgressAction`（C2）；呼叫 `onCancel` 恰一次，連按 N 次狀態轉換只發生一次（C8 冪等）；呼叫端執行批次中止（C4 實作約束） | Material 內建 ripple（經 `AppButton`）；取消鈕 enabled → disabled 為離散替換 | pressed 態與 C2 轉換皆於 `Motion.feedback` 內（SPEC-003 §2.2、§2.5 C2） | §1 子表「按下確認」列（由 4.4 `AppButton` 承載） | loading → pressed → cancelling | 反應／時限：UX 審查（SPEC-003 §2.2、§2.5 C2、C8）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 由容器承載（4.28 `PageColumn`）：0.1 無定位至本元件的場景——載入態為全頁內容；系統通知點擊時若已進入新一輪 `state-gaps-scanning`，只切頁、顯示當時進度、不定位（SPEC-003 §2.2「點擊通知的導向」列） | — | — | 由容器承載（§1 子表「定位提示」列） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依載入 provider 改 `progress` / `countText` / `isCancelling` 傳值；含切換導覽項後回到畫面顯示當時進度（L1）、切換專案中止（L2），SPEC-003 §2.8） | 計數文字更新：兩次更新間隔不小於 `Motion.progressTick`，文字以 `liveRegion` 播報（SPEC-003 §2.6；無障礙子節）；loading → cancelling：版面不變、進度改 indeterminate、計數凍結於最後值（C3），取消中由取消鈕 label 換文案播報（無障礙子節）；骨架 shimmer 循環 `Motion.skeletonCycle`，`disableAnimations` 時靜態灰塊（SPEC-003 §2.1、§2.6）；進入本狀態自前一狀態 cross-fade `Motion.transition`（SPEC-003 §3.1、§3.4、§3.5 動畫提示）由畫面承載，重新掃描時現有結果立即被骨架取代、不做兩段動畫（§3.5 動畫提示） | `Motion.skeletonCycle`（骨架，動畫類，`disableAnimations` 下歸零）；cross-fade `Motion.transition` 由畫面承載；進度條推進為 determinate 值變化無動畫（SPEC-003 §3.4 動畫提示） | `Motion.progressTick`（計數更新最小間隔，契約類不歸零，SPEC-003 §2.6）；`Motion.spinnerMinVisible`（一旦渲染的最短存續，極小資料亦然，SPEC-003 §2.6）；C3 期間逐幀骨架根錨點存在直至 `Motion.cancelDeadline`（SPEC-003 §2.5 C3 斷言方式） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（骨架、cross-fade）；無障礙播報適用（計數 `liveRegion`、取消鈕 label）；不升級系統通知——掃描**完成**的系統通知由頁面層依 SPEC-003 §2.2「系統層通知」承載，觸發於本元件被拆除的當下，非本元件的事件） | loading → loading（進度更新）/ loading → cancelling（C2）/ cancelling → 目標態（C4，由呼叫端拆除本元件） | 反應／時限：UX 審查（SPEC-003 §2.1、§2.5 C3、§2.6、§2.8）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點（本元件為承載他人第二層的載體，須分開寫）：**為誰承載**——本元件本身即長時操作類的第二層（服務受理層／等待指示），為畫面級載入態本體（SPEC-003 §2.2、§2.6，兩處形式：`state-domain-loading` 骨架矩陣版位 + 計數、`state-gaps-scanning` 骨架分節版位 + 計數），完成時由呼叫端拆除本元件轉入第三層（結果通知，狀態轉換本身）。**自身互動掛在哪一層**——取消鈕自身的第一層（互動元件層，pressed 態）由 4.4 `AppButton` 承載，依不變式 INV-FEEDBACK-001 每次按下無條件回應，不因等待中的服務狀態被抑制（C2）。兩者是不同的事：本元件是他人第二層的承載者，取消鈕是本元件自身的第一層互動，不可混寫。服務類型：長時操作（本元件即該類政策的實作本體；依兩軸判定：使用者感知的等待為秒至分鐘、需要進度指示與取消能力；失敗形態為可能失敗，SPEC-003 §2.12）。成功：完成 → 目標正常態的狀態轉換本身，由呼叫端拆除本元件；失敗：解析錯誤／平台錯誤／資料損壞由呼叫端於拆除本元件後的目標態依長時操作類政策呈現，本元件本身不顯示錯誤標記（C5：取消不出現任何 SnackBar / Dialog / 錯誤標記，部分結果全數丟棄 C6，再次觸發載入自 0 起算 C7）；逾時：C4 保證取消完成後於 `Motion.cancelDeadline` 內抵達目標態，不逾時停滯；服務不可用：同失敗段，由呼叫端於目標態呈現；切換專案中止於 `Motion.cancelDeadline` 內完成、不留背景任務（L2）。輸入阻擋範圍：阻擋頁面內容——本元件取代頁面內容本身即為阻擋機制（長時操作類政策，SPEC-003 §2.12），且依規則同時提供取消（本元件恆含取消鈕，C1：第一幀即 enabled）。重複觸發防護：禁用觸發來源——本元件存在期間觸發入口已被頁面內容取代而消失，非本元件主動停用；取消鈕自身的重複觸發由 C8 冪等保證（連按 N 次只轉態一次） | `Motion.skeletonCycle`；Material 內建（經 `AppButton`） | `Motion.cancelDeadline`（C4、L2 抵達上限）；`Motion.spinnerMinVisible`（最短顯示） | §1 子表「等待與結果」列 | cancelling → 目標態（C4）；loading → 目標態（完成） | 反應／時限：UX 審查（SPEC-003 §2.2、§2.5 C4–C7、§2.6、§2.8 L2、§2.12）；通道／狀態邊：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（取消鈕） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬與高）；骨架版位填滿、進度條版本內容置中 |
| 最小尺寸 | 寬：2 × `Space.md`（自身內距）+ 訊息一字元 + 省略號（一字元見 §4.0.3，取 `message` slot 的 `AppFontSize.body`）+ `Space.sm`（訊息與取消鈕間距）+ 取消鈕；`countText` 與訊息同處可換行的 `Wrap`（間距 `Space.sm`），寬不足時折至下一行，不計入最小寬；高：2 × `Space.md` + `LayoutSize.rowHeightRelaxed` × 3（骨架至少三列）+ `Space.sm`（骨架與訊息列間距）+ `LayoutSize.hitTargetMin`（實作 `loading_state.dart` `_LoadingStateState.build`／`_buildSkeletonBody`／`_messageFooter`，1.101 追認內距與間距項） |
| 最小命中區 | 取消鈕 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 無上限（骨架填滿） |
| `kMinWindowSize` 下的行為 | 維持（骨架列數隨高度裁切） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 否 | 1 | 截斷 | `domainLoading`（en「Resolving graph nodes…」）/ `gapReportScanning`；`TestCopy.longZh` |
| `countText` | 否 | 1 | 截斷 | `domainLoadingProcessedCount`（count 代入 99999）；`TestCopy.longEn` |
| 取消鈕 label | 經 `AppButton` | | | `cancelLoadingAction`（en「Cancel loading」）、`cancelInProgressAction`（en「Cancelling…」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`domainLoading` / `gapReportScanning`） |
| `countText` | `String?` | 否 | 呼叫端（`domainLoadingProcessedCount` / `gapsScanningProcessedCount`） |
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
| 訊息 / 計數 | `domainLoading` / `gapReportScanning` / `domainLoadingProcessedCount` / `gapsScanningProcessedCount`（既有）/ `historyLoading` / `historyLoadingProcessedCount`（§10，1.131） |
| 取消 | `cancelLoadingAction` / `cancelScanAction` / `cancelInProgressAction`（既有） |
| 骨架朗讀 | `loadingSkeletonA11yLabel` |

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
| 朗讀標籤 | 骨架區 `loadingSkeletonA11yLabel`；取消鈕經 `AppButton` |
| 狀態變化播報 | 計數文字為 `liveRegion`（更新間隔 `Motion.progressTick`）；取消中由取消鈕 label 換文案播報 |
| 非視覺替代訊號 | 進度由文字計數承載，進度條顏色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 取消鈕進入 Tab 內容區段；C1 期間恆可聚焦 |
| 對比 | 依 §4.0.2 表 1：計數文字 `textSecondary` / `surfaceBase` 4.71:1，通過；取消鈕 enabled 與 cancelling 後的 disabled 依 4.4（disabled label `textDisabled` 屬非作用中元件豁免） |


#### 測試點（widget test）

- [ ] 一支測試渲染 `skeleton`（`matrix` / `sections` / `rows`）× loading / cancelling
- [ ] 兩種視窗尺寸下不溢位
- [ ] 最長測試文案：訊息與計數截斷
- [ ] zh / en 全部 key 皆不溢位
- [ ] C1–C8 逐條：第一幀取消鈕 enabled；按下後 `pump(Motion.feedback)` 取消鈕 disabled 且文字為 `cancelInProgressAction`；逐幀 `pump(16 ms)` 至 `Motion.cancelDeadline` 根錨點恆存在、無 SnackBar / Dialog；連按取消 `onCancel` 只呼叫一次
- [ ] indeterminate 情境畫面無 `%` 字元、無 `LinearProgressIndicator(value: 非 null)`
- [ ] `pump(Motion.feedback)` 後根錨點仍存在（最短顯示）；`disableAnimations` 為 `true` 時骨架靜態
- [ ] 顏色、間距、時間值引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 按鈕內的等待指示 | 禁止（SPEC-003 §2.2） |
| 重新整理單檔的等待 | 不套用（SPEC-003 §3.6：`Motion.cancelDeadline` 內直接抵達分支） |

### 4.25（已退役）

> v1.118 起退役（`0.6.0-W1-108`）：原 `LoadPrompt` 元件隨 SPEC-001 v1.64 刪除 Ticket 清單載入態而無使用畫面，
> 元件與其 i18n key 已自 lib 移除。編號保留不遞補，避免外部引用錯位。

### 4.26 AppSnackBar

**用途**：「已在外部開啟」「找不到檔案」類的暫時訊息；Material 預設進出動畫不覆寫（SPEC-003 §2.2）。
**內容角色**：內文 + 可選動作。
**何時不用**：狀態改變本身即為結果（不用 SnackBar）；取消完成（C5 禁止）；持續性錯誤標示（`IssueMarker`）。
**出現畫面**：§1、§2、§4、§5、§6、§7（`denied` fallback 於任一畫面）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `plain` | 文字 | 停留 `Motion.snackBar` | 已在外部開啟、檔案仍不存在、Ticket 目標不在清單、選擇器無法開啟、資料夾不可讀或不存在、外部開啟失敗（`externalOpenFailedMessage`）；泳道／UC Flow 開啟原始檔找不到檔案（`0.1.0-W3-335.38` S-18／S-22：改為不帶動作） |
| `withAction` | 文字 + 一個動作（`AppButton.text` 形態） | 停留 `Motion.snackBarWithAction` | 破洞項外部開啟找不到檔案 + 重新掃描（`rescanAction`，見 4.40 `item`）；系統通知 `denied` fallback + `viewGapsAction`（SPEC-003 §2.2）；清除搜尋與篩選 + `undoAction`（SPEC-003 §3.4） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| shown | 依變體 | `withAction`：動作 | 呼叫端 `show` | 停留時間到、動作觸發、新的 SnackBar 取代（限新一則級別不低於本則，或本則級別未知；新一則級別較低時讓步、本則不受影響，SPEC-003 §2.13〈顯示位爭用時的約束與 0.1 的處置規則〉）、專案改變（SPEC-003 §2.8 切換專案（L2）列；`plain` 與 `withAction` 一律立即退出，不等停留時間到）→ dismissed | 互動瞬態（`show` 觸發、停留計時與取代由 Material `ScaffoldMessenger` 內部承載，不存於 provider；`message` / `actionLabel` 由呼叫端傳值，§2） | 本地即時（`show` 於觸發動作的結果返回後呼叫，SnackBar 本身不等待資料層；§2 樂觀更新政策：0.1 無樂觀操作） |
| dismissed | 不存在 | 無 | 上述退出 | 不適用：靜止（下一次 `show` 重新進入） | —（不存在即為預設；`show` 機制見 shown 列） | 本地即時 |

互動瞬態（hover / pressed / focused）由 `withAction` 的動作（`AppButton.text` 形態，4.4）承載，本元件不另列；`plain` 無可互動子件。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本元件即 §1 子表「等待與結果」列三層中的**結果通知**層載體之一（SPEC-003 §2.2：狀態不變的動作用 SnackBar），也是「狀態變更提示」列系統通知升級的 `denied` fallback 載體（SPEC-003 §2.2「系統層通知」權限 gate）；它是回饋通道本身，下表各列寫的是使用者與這個通道互動時的回饋。
> 本元件即本專案的終端回饋元件，依 §4.0.11 已於元件內部記錄顯示、靜默早退、使用者互動三類時刻；下表「反應」欄描述使用者可感知的行為，記錄行為本身見 §4.0.11。
> **下表各列的 `message` 與 `actionLabel` 實際文字須符合 §4.0.12 暫態提示的訊息設計要求**（成分／長度與版面保障／placeholder／成敗措辭區分／i18n key 命名五項）；本表填的是通道與時機，文字本身的約束不在本表逐列重複。**哪些事件該走本元件**由 SPEC-003 §2.13 判準 T 決定，不由本表的既有列反推——本表現有的列是判準的結果，不是判準本身。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | `withAction` 的動作經 4.4 `AppButton.text` 形態（hover 態、`SystemMouseCursors.click`）；訊息文字無 hover；`plain` 整體無 hover | 無（Material 內建，經 `AppButton`） | 無（同 4.4） | §1 子表「可互動提示」列（由 4.4 `AppButton` 承載；`plain` 不適用：無可互動子件） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | `withAction` 的動作於停留期間可 Tab 到，出現時不搶奪焦點（無障礙子節）；訊息以 `liveRegion` 播報（Material `SnackBar` 內建）；`plain` 無停留點 | 無 | 無（SPEC-003 §2.10 未定 SnackBar 焦點；提案） | §1 子表「焦點」列（由 4.4 `AppButton` 承載；`plain` 不適用） | shown →（動作 focused）→ shown | 反應：規格撰寫者（提案；SPEC-003 §2.10 未定）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 動作經 4.4 `AppButton.text` 形態（pressed 態 + ripple）；呼叫 `onAction` 恰一次，SnackBar 即時消失；呼叫端執行：重新掃描（§3.5：`state-gaps-scanning` 出現）／`viewGapsAction`（§2.2 `denied` fallback：等同「點擊通知的導向」列，切至 `nav-page-gaps` 並定位）／`undoAction`（§3.4〈帶目標跳入〉：復原清除搜尋與篩選前的畫面條件） | Material 內建 ripple（經 `AppButton`）；SnackBar 消失為 Material 預設動畫 | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2，經 4.4） | §1 子表「按下確認」列（由 4.4 `AppButton` 承載） | shown → pressed → dismissed | 反應／時限：UX 審查（SPEC-003 §2.2、§3.5、§3.6）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 不適用（無承載者）：本元件為覆蓋層、不放入任何容器（組合規則子節），不是被定位目標；`viewGapsAction` 觸發的定位（第一個 `card-gaps-<itemId>` scroll-into-view + 高亮 + 焦點移入）由頁面層依 SPEC-003 §2.2「點擊通知的導向」列執行，本元件只回呼 `onAction` | — | — | 不適用（覆蓋層無容器；`viewGapsAction` 的定位由頁面層承載） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（`show`：外部開啟結果返回後（SPEC-003 §2.2 外部開啟契約，`opened` / `notFound` / `failed` 各對應一則）、重新整理仍不存在（§3.6）、系統通知 `denied` fallback——視窗前景且可見頁非 `nav-page-gaps` 時立即，視窗非前景時延後至下一次 `resumed`（§2.2 權限 gate 表）、選擇器無法開啟（§3.1、§3.7）、資料夾不可用（§3.1、§3.7）、Ticket 目標不在清單（§3.4〈帶目標跳入〉）、清除搜尋與篩選（§3.4〈帶目標跳入〉）；新的 `show` 取代前一則） | shown ↔ dismissed：Material 預設進出動畫，不覆寫（SPEC-003 §2.2、§3.2 動畫提示）；出現即 `liveRegion` 播報一次（無障礙子節）；停留時間到自動消失（`plain`：`Motion.snackBar`；`withAction`：`Motion.snackBarWithAction`）；取消完成不得顯示（SPEC-003 §2.5 C5）；切換前發出、切換後才回來的結果不 `show`，只留痕（SPEC-003 §2.8 切換專案（L2）列） | Material 預設（不引用 `Motion.*` 動畫 token；`disableAnimations` 下由 Material 處理） | 停留 `Motion.snackBar` / `Motion.snackBarWithAction`（契約類，SPEC-003 §2.1） | §1 子表「狀態變更提示」列（本元件即該列 `denied` fallback 的載體；無障礙播報適用（`liveRegion`）） | dismissed → shown（`show`）/ shown → dismissed（停留時間到、動作觸發、被取代、專案改變（SPEC-003 §2.8 切換專案（L2）列）） | 反應／時限：UX 審查（SPEC-003 §2.1、§2.2、§2.5 C5）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：本元件即**結果通知**層（第三層）的載體之一（SPEC-003 §2.2 結果通知列：狀態不變的動作——外部開啟 `opened` / `failed`、重新整理無變化——用 SnackBar；有狀態轉換者不用 SnackBar），本元件的第一層（觸發動作的元件自身 pressed 態）與第二層（等待指示，若有）由觸發本次顯示的上游元件承載，非本元件；`withAction` 內動作按鈕自身另有獨立的第一層，由 4.4 `AppButton.text` 形態承載。服務類型：短暫非同步（本元件即該類政策對照表訂定的第三層載體，SPEC-003 §2.12：兩軸為使用者感知等待亞秒級、失敗形態可能失敗——本元件承載該類服務的成功與失敗訊息；`withAction` 動作觸發的後續操作可能另屬短暫非同步或長時操作，屬另一次事件，不影響本元件自身此刻的服務類型判定）。成功：`plain`／`withAction` 顯示對應成功訊息（如 `openedExternallyMessage`）；失敗：顯示對應失敗訊息（如 `sourceFileNotFoundSnackbarMessage`／`sourceFileStillMissingMessage`）；逾時：不適用於短暫非同步類（亞秒級無逾時概念，SPEC-003 §2.12）；服務不可用：同失敗段（短暫非同步類的服務不可用與失敗共用同一訊息呈現機制，皆經本元件顯示）。輸入阻擋範圍：不阻擋（短暫非同步類政策，SPEC-003 §2.12）。重複觸發防護：冪等——新的 `show` 取代前一則，重複觸發為合法操作（短暫非同步類政策，SPEC-003 §2.12）；取代限新一則級別不低於前一則或前一則級別未知，級別較低者讓步、不清除也不呈現（SPEC-003 §2.13〈顯示位爭用時的約束與 0.1 的處置規則〉、§2.15） | Material 預設 | 停留 `Motion.snackBar` / `Motion.snackBarWithAction` | §1 子表「等待與結果」列（結果通知＝SnackBar） | 不適用 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.12）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（`withAction` 的動作） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | Material `SnackBar` 預設（浮於內容區底部，寬依內容） |
| 最小尺寸 | 寬：2 × `Space.md`（水平內距）+ 一字元 + 省略號（一字元見 §4.0.3，取 `message` slot 的 `AppFontSize.body`）；`withAction` 另加 `Space.sm`（訊息與動作間距）+ 動作 label 最小寬（2 × `Space.xs` 水平內距 + 一字元 + 省略號，取動作 label 的 `AppFontSize.body`）；`withAction` 時訊息與動作以 3：1 比例分寬，兩者各自不小於上列最小寬；高：2 × `Space.sm`（垂直內距）+ `LayoutSize.hitTargetMin`（實作 `app_snack_bar.dart` `AppSnackBar` 的 `SnackBar.padding` 與 content `Row`、`_SnackBarActionLabelState.build`，1.101 追認並指名 token） |
| 最小命中區 | 動作 `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬：主區寬 − 2 × `Space.xl`；高：文字兩行 |
| `kMinWindowSize` 下的行為 | 維持（文字換行至兩行） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 2 | 末行截斷 | `sourceFileStillMissingMessage`（en「File still not found」）；`TestCopy.longEn` |
| 動作 label | 否 | 1 | 截斷 | `rescanAction`；`TestCopy.longToken` |

> 本表定行數與超出處置；**文案本身該含哪些成分、多長、placeholder 怎麼放，見 §4.0.12**（M1／M2／M3）。M2 明訂「觸發截斷時改寫文案，不放寬本表的行數上限」，且 `withAction` 下訊息與動作競爭列寬時由動作 label 先讓步——本表「最長測試文案」欄的核對對象因此是**全部語系的最長值**，不只來源語系。

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `message` | `String` | 是 | 呼叫端（`openedExternallyMessage` / `sourceFileNotFoundSnackbarMessage` / `sourceFileStillMissingMessage` / `ticketsTargetNotFoundMessage` / `chooseFolderUnavailableMessage` / `folderUnavailableMessage` / `workspaceNotRemembered` / `externalOpenFailedMessage` / `scanCompleteNoGapsSnackbarMessage` / `scanCompleteSnackbarMessage` / `ticketsFiltersClearedSnackbarMessage` / `preferencesEditorAppliedMessage` / `preferencesEditorSaveFailedMessage`） |
| `actionLabel` / `onAction` | `String` / `VoidCallback`（`withAction`） | `withAction` 必填 | 呼叫端（`rescanAction` / `viewGapsAction` / `undoAction`） |

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
| 訊息 | `openedExternallyMessage` / `sourceFileNotFoundSnackbarMessage` / `sourceFileStillMissingMessage`（既有，呼叫端傳入）；`ticketsTargetNotFoundMessage`（Ticket 帶目標跳入目標不在清單，SPEC-003 §3.4）／`chooseFolderUnavailableMessage`（選擇器無法開啟）／`folderUnavailableMessage`（資料夾不可讀或不存在，placeholder `reason`）（新增，§4.0.6 新 key 總表，`0.1.0-W3-335.38` S-11／S-13／S-38）；`workspaceNotRemembered`（選定成功但偏好設定寫入失敗，SPEC-003 §3.7；§4.0.6〈1.56 補登〉表，`0.3.3-W3-405`）；`externalOpenFailedMessage`（外部開啟失敗，SPEC-003 §2.2〈外部開啟契約〉）／`scanCompleteNoGapsSnackbarMessage`／`scanCompleteSnackbarMessage`（掃描完成系統通知 `denied` fallback，SPEC-003 §2.2〈系統層通知〉）／`ticketsFiltersClearedSnackbarMessage`（清除搜尋與篩選，SPEC-003 §3.4〈帶目標跳入〉，§4.0.6 新 key 總表 1.35） |
| 動作 | `rescanAction`（既有，破洞項外部開啟找不到檔案，見 4.40 `item`）；`viewGapsAction`（SPEC-003 §2.2 系統層通知 `denied` fallback，§4.0.6 新 key 總表，ARB 實檔由 `0.1.0-W3-064` 加）；`undoAction`（清除搜尋與篩選復原，SPEC-003 §3.4，§4.0.6 新 key 總表 1.35）；`refreshAction` 已移出本元件動作列——泳道／UC Flow 開啟原始檔找不到檔案改用 `plain`（`sourceFileNotFoundSnackbarMessage`，不帶動作），`refreshAction` 僅保留為 4.22 `MissingSourceState` 自身「重新整理」按鈕的標籤，非 SnackBar 動作（`0.1.0-W3-335.38` S-18／S-22） |

> 本表列的是**哪些 key**；key 的命名規則與 ARB `@<key>.description` 的填寫要求見 §4.0.12 M5。新增經本元件顯示的 key 時，§4.0.12 的 M1–M5 五項須同批核對——文案是 0.1 唯一沒有型別檢查也沒有編譯期徵兆的介面。

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
- [ ] 本元件 i18n 子節列出的每個 key，zh / en 皆不溢位（覆蓋對象為該子節的全部 key，不寫死 key 數；該子節增列 key 時本項自動涵蓋，見 §4.0.12 驗收段「不以該子節列舉的 key 數為上界」）
- [ ] `pump(Motion.snackBar)` 後 `plain` 消失；`withAction` 於 `Motion.snackBar` 後仍存在、`Motion.snackBarWithAction` 後消失；動作點選呼叫 `onAction` 恰一次
- [ ] 停留時間引用 `Motion` token 非字面值
- [ ] 專案改變後，顯示中的 `plain` 與 `withAction` 皆立即消失（不等停留時間到；`withAction` 的動作隨之消失，SPEC-003 §2.8 切換專案（L2）列）

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 取消完成的告知 | 禁止（C5） |
| 原始檔已消失的持續狀態 | `MissingSourceState` |
| 損壞標示 | `IssueMarker` |

### 4.27 AppShell（容器）

**用途**：根框架容器：標題列 / 側欄（`ProjectSwitcherEntry` + `NavItem` × 7 + 底部 `NavItem.action` × 3，見〈側欄底部 slot〉）/ 主區（`PageColumn` × 7 於 `IndexedStack`）三格（第七項變更記錄，SPEC-001 §10、SPEC-003 §2.8「七頁建構時機」）；承載視窗邊緣內距與專案切換覆蓋層；為傳值元件，不 watch（§2）；訂閱由組裝層 `lib/assembly/shell.dart` 的 `AppShell`（`ConsumerStatefulWidget`）承擔，watch 後傳值。漂移項（側欄寬、導覽項圖示、選取底色、標題列高）由 W1-005 對齊。
**內容角色**：容器（標題列另有一個標題 slot）。
**何時不用**：頁面內的區塊排列（`PageColumn` / `Panel`）。
**出現畫面**：殼。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 三格 + 當前可見頁 | 導覽、專案切換入口、內容區 | App 啟動（落地 `nav-page-domain`，SPEC-003 §2.8） | 開啟浮層 → overlayOpen | 資料態：`switcherOpenProvider`（`StateProvider<bool>`，`lib/app/project_switcher_providers.dart`）為 `false`；當前可見頁為 `selectedDestinationProvider`、返回列存在與否為 `returnToProvider`（皆 `lib/app/router.dart`）；組裝層 `lib/assembly/shell.dart` 的 `AppShell` watch 後傳入，本容器不 watch（§2 導覽狀態列） | 本地即時（導覽與浮層開合皆為本地 UI 狀態，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| overlayOpen | `SwitcherOverlay` 覆蓋於側欄入口下方；點擊背景任一處（含導覽項）依 4.42〈按下確認〉「點浮層外部」列被吸收：浮層收合、不切頁（同 SPEC-003 §3.4 F7，`0.1.0-W3-335.47` D13）；焦點限制於浮層（SPEC-003 §3.7、§2.10） | 浮層內操作、Esc、點外部 | `project-switcher-entry` 或阻擋狀態出口 | 收合 → default | 資料態：`switcherOpenProvider` 為 `true`（同上） | 本地即時 |

互動瞬態（hover / pressed / focused）由子件（4.7 `NavItem`、4.8 `ProjectSwitcherEntry`、內容區各元件）承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器自身無可點元素，affordance／press-ack 由子件承載；本表寫的是殼層級的焦點路徑、切頁與浮層開合的回饋。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：本容器無可點元素；側欄入口與導覽項的 hover 由 4.8 / 4.7 承載，標題列與分隔線無 hover、指標形狀預設 | — | — | 不適用（由 4.7 `NavItem` / 4.8 `ProjectSwitcherEntry` 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | Tab 四區段依序：入口 → 全部導覽項 → 側欄底部三項（設定 → 鍵盤快捷鍵 → 寫入清單）→ 內容區，區段內依 `ReadingOrderTraversalPolicy`（SPEC-003 §2.10）；overlayOpen 時焦點限制於浮層、Tab 不離開（`FocusScope`，由 4.42 承載）、Esc 收合後焦點回 `project-switcher-entry`（SPEC-003 §2.10 浮層兩列）；各停留點的焦點環由子件依 §4.0.1 承載，本容器不另繪；側欄與主區以 `Semantics(container: true)` 分組（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言順序與焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列（焦點環由子件承載；本容器承載三區段順序） | default ↔ overlayOpen 皆不改變（焦點路徑隨狀態切換：overlayOpen 時限制於浮層） | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由子件承載：導覽項 4.7（`selectedDestinationProvider` 改變，`IndexedStack` 索引切換無轉場，SPEC-003 §2.8）、入口 4.8（`switcherOpenProvider` 改 `true` → overlayOpen）、返回鍵 4.4 `secondary`（`action-<screen>-back`，讀 `returnToProvider` 切回來源頁並清為 `null`，SPEC-003 §2.3、§2.4）；本容器不渲染 ripple | Material 內建 ripple（經子件） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2，經子件） | §1 子表「按下確認」列（由 4.7 / 4.8 / 4.4 承載） | default → overlayOpen（入口）；切頁不改變本狀態 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.3、§2.4、§2.8）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 本容器承載跨畫面定位的**切頁**段：系統通知點擊／`viewGapsAction` 時將 `selectedDestinationProvider` 設為 `AppDestination.gaps`、`returnToProvider` 設為 `null`（SPEC-003 §2.2「點擊通知的導向」列、§2.3 規則 1）；頁內 scroll-into-view 與高亮不由本容器執行，依 §4.0.10 由 4.30 `Panel.scrollable`（`scroll-gaps-sections`）承載；本容器自身（側欄、標題列）常駐不捲動，不是被定位目標；overlayOpen 時通知點擊視同點外部（4.42 退出路徑）：先收合浮層（`switcherOpenProvider` 改 `false`，焦點依 4.42 收合契約回 `project-switcher-entry`）再執行切頁段與定位段，使焦點移入被定位項不與浮層 `FocusScope` 衝突；定位段的焦點移入覆蓋收合的焦點歸位（收合先把焦點交回入口，定位段隨後移入被定位項，最終落點為被定位項）（提案） | 無（`IndexedStack` 切頁無轉場，SPEC-003 §2.8） | 無（SPEC-003 §2.2 未設切頁時限；提案） | §1 子表「定位提示」列（切頁段由本容器承載，定位段依 §4.0.10） | overlayOpen → default（通知點擊先收合浮層，提案）；default 下切頁不改變本狀態 | 反應：UX 審查（SPEC-003 §2.2）；分工：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（組裝層 `lib/assembly/shell.dart` 的 `AppShell` 以 `ref.watch` 讀取後傳值，依 `switcherOpenProvider` 渲染／移除 `overlay` slot、依 `returnToProvider` 渲染／移除返回列、依 `selectedDestinationProvider` 切換 `IndexedStack` 索引並對首次成為 index 的頁發首次可見訊號（provider 層 visited set，`visitedDestinationsProvider` / `firstVisibleProvider`，`lib/app/router.dart`；W1-031、SPEC-003 §2.8「七頁建構時機」）） | 浮層出現／收合為 `Motion.overlay`，由 4.42 承載；返回列出現／消失為離散替換（`action-<screen>-back` 依 `returnTo` 存在／消失，SPEC-003 §2.3 規則 4）；降級徽章 `badge-<screen>-degraded-schema` 依降級旗標渲染／移除，與返回列同一列常駐（`Badge.tag`，文字含 App 內建型別表產生版本與專案 `.claude/VERSION` 兩個值，SPEC-001 §1 降級註記 (4)、SPEC-003 §2.4，`0.1.0-W3-335.57` E3）；推定版本徽章 `badge-<screen>-inferred-version` 依推定版本旗標（`inferredVersion` 非 `null`）渲染／移除，位置與方式同降級徽章（`Badge.tag`，文字 `inferredVersionBadgeLabel` 含推定版本值，SPEC-001 §1〈推定版本〉註記；兩旗標互斥，不會同時出現）；路徑模式來源徽章 `badge-gaps-builtin-path-pattern` 依 `isPathPatternFromBuiltin` 渲染／移除，**只在破洞報告頁**，位置與方式同降級徽章（`Badge.tag`，文字 `builtinPathPatternBadgeLabel`，SPEC-001 §1〈路徑模式取自內建表〉註記；與降級徽章互斥、可與推定版本徽章並存）；切頁無轉場，當前頁的 `PageTitle` header 承載播報（無障礙子節）；視窗尺寸變更不重置任何狀態、捲動容器 offset 夾在新範圍（SPEC-003 §2.8，由各捲動容器承載） | `Motion.overlay`（浮層，由 4.42 承載）；其餘無 | 返回列於 `Motion.feedback` 內出現／消失（W1-031 契約，沿用既有）；浮層於 `Motion.overlay` 內（SPEC-003 §3.7 動畫提示） | §1 子表「狀態變更提示」列（`Motion.*` 過渡由 4.42 承載；無障礙播報由當前頁 `PageTitle` header 承載；不升級系統通知——通知的發送由頁面層依 SPEC-003 §2.2 承載，本容器只執行導向的切頁段） | default → overlayOpen（入口／阻擋狀態出口）/ overlayOpen → default（Esc、點外部、選取專案） | 反應：UX 審查（SPEC-003 §2.3、§2.8、§3.7）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用——本容器不承載三層中任一層，全部由子件承載（點擊確認：4.7／4.8／4.4 返回鈕；等待指示：各頁內容 slot 的 4.24 `LoadingState`，SPEC-003 §2.6；結果通知：切頁／浮層開合的狀態轉換本身，或 4.26 經 `ScaffoldMessenger` 承載，本容器提供 `Scaffold` 宿主）。服務類型：不適用於本容器本身——本容器只協調子件的顯示與切換，不直接觸發服務，各子件的服務類型見其各自條目（SPEC-003 §2.12）。成功／失敗／逾時／服務不可用：皆不適用於本容器本身，四段結局由承載對應層級的子件各自呈現，本容器不重述。輸入阻擋範圍：不適用於本容器——阻擋範圍由觸發長時操作的內容 slot（4.24）自行決定，本容器（側欄、標題列）本身恆可互動不受阻擋（切換導覽項不因內容區載入中而阻擋，SPEC-003 §2.8 L1）。重複觸發防護：不適用於本容器——本容器無自身觸發動作，防護判斷在各子件與其服務層 | — | — | 不適用（三層皆由子件或內容 slot 承載；`Scaffold` 宿主非回饋通道） | 不適用 | 規格撰寫者 |

#### 側欄底部 slot

側欄底部固定三項，讓不屬導覽頁的三個面板在畫面上有入口（出處：設定、鍵盤快捷鍵兩項為 `0.7.0-W1-007` 用戶裁決 2026-11-09；寫入清單為 `1.0.0-W3-553.3` 用戶裁定 2026-11-11，SPEC-001 §12）。

| 項目 | 定義 |
|------|------|
| 項目與順序 | 由上到下：「設定」（`nav-action-preferences`，標籤 `sidebarSettingsLabel`，圖示 `AppIcon` 齒輪）→「鍵盤快捷鍵」（`nav-action-shortcuts`，標籤 `keyboardShortcutsTitle`，圖示 `AppIcon` 鍵盤）→「寫入清單」（`nav-action-writeLog`，標籤 `writeLogTitle`，圖示 `AppIcon` 清單，`badge` 為失敗計數 `Badge.count`，`badge-writeLog-failure-count`）；三項皆為 4.7 `NavItem.action`，順序同 SPEC-003 §2.9 側欄底部項類別的列序 |
| 動作 | 「設定」開啟偏好設定面板（SPEC-001 §9、SPEC-003 §3.8）；「鍵盤快捷鍵」開啟鍵盤快捷鍵面板（SPEC-001 §11、SPEC-003 §3.10）；「寫入清單」開啟寫入清單面板（SPEC-001 §12、SPEC-003 §3.12）。三項不屬 `AppDestination`，不改變導覽選取與 `returnTo` |
| 失敗計數 | 數值為 SPEC-001 §12〈失敗計數徽章〉的定義（寫入結果不是 `written`、或驗證狀態為 `failed`、`unavailable` 的列數）；為 0 時 `badge` 傳 `null`、不渲染。資料來源為 Edit domain 的 session 寫入清單，組裝層 watch 後以 `int` 傳入，本容器不 watch（§2） |
| 位置 | 側欄內貼齊底部內距（`Space.md`）；與上方導覽項之間為彈性空白，空白與三項之間一條 `Divider`（4.3），`Divider` 上下各 `Space.sm` |
| Tab 順序 | 第三區段，接在七個導覽項之後、內容區之前：設定 → 鍵盤快捷鍵 → 寫入清單（SPEC-003 §2.10） |
| 錨點 | `nav-action-preferences`、`nav-action-shortcuts`、`nav-action-writeLog`、`badge-writeLog-failure-count`（SPEC-003 §2.9 側欄底部項類別與寫入清單面板錨點） |
| 不溢位的尺寸依據（`kMinWindowSize`） | 側欄可用高 = 視窗內容高 640 − `LayoutSize.titleBarHeight`（36）− 2 × `Space.md`（側欄垂直內距，24）= 580。側欄內容固有高 = 入口 33（`LayoutSize.iconLg` 17 + 2 × `Space.sm` 16，4.8 尺寸契約）+ `Space.sm`（8）+ 導覽項 7 × 33（4.7 尺寸契約，同上算式）= 231 + 底部區 2 × `Space.sm` + `Divider` 1 + 3 × 33 = 116，合計 388。388 ≤ 580，剩餘 192 由彈性空白吸收，不需捲動；`NavItem` 標籤單行截斷（4.7 內容政策），寬度不受語系影響；失敗計數徽章的高不超過列高（4.7〈`badge` slot〉），不改變列高。代入值不含文字高以外的字型差異，實機字型與測試字型同值（不隨字型） |
| 空間不足策略 | 依上列算式在 `kMinWindowSize` 以上不觸發；為防日後導覽項增加，導覽項區段若高度不足則該區段垂直捲動，底部三項維持固定可見（不隨導覽項捲走） |
| 浮層展開時 | 點三項依 4.42〈按下確認〉「點浮層外部」列被吸收：浮層收合、不開啟面板（同導覽項） |

**實作註記**：state-change 列「返回列」契約寫「注入當前 `PageColumn` 的頁面級動作列」，但 `pages` slot 是呼叫端已建構完成的 `List<PageColumn>`，容器無法改寫其內部結構。實作改為獨立的返回列疊於 `IndexedStack` 內容之上（沿用既有版面慣例），對外可觀察行為（`action-<screen>-back` 錨點依 `returnTo` 存在/消失）與契約一致，僅視覺層級（注入 vs 疊加）不同。降級徽章 `badge-<screen>-degraded-schema` 比照同一實作方式，與返回列同一列疊於 `IndexedStack` 內容之上，依降級旗標渲染／移除（`0.1.0-W3-335.57` E3）。推定版本徽章 `badge-<screen>-inferred-version` 同此方式，依推定版本旗標渲染／移除（SPEC-001 v1.19）。唯讀降級徽章 `badge-<screen>-readonly-workspace`（`Badge.tag`，文字依原因 `readonlyWorkspaceNotGitBadge`／`readonlyWorkspaceGitMissingBadge` 二選一）同此方式，依工作區唯讀旗標渲染／移除；與降級徽章、推定版本徽章可同時出現，同一列依序排列（SPEC-001 §1〈「唯讀降級」同樣是疊加旗標〉，`1.0.0-W3-553.3.1`）。路徑模式來源徽章 `badge-gaps-builtin-path-pattern` 同此方式，僅破洞報告頁渲染（SPEC-001 v1.21）。

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：本容器自身無可點元素（互動由子件承載）；鍵盤四區段路徑見回饋契約焦點列 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿視窗 |
| 最小尺寸 | `kMinWindowSize`（macOS `minSize`） |
| 最小命中區 | 不適用（容器） |
| 最大尺寸 | 無（可最大化） |
| 標題列高 | `LayoutSize.titleBarHeight`（36；`shell.dart` 現行 Material `AppBar` 預設高屬漂移，待實作票對齊） |
| 側欄寬 | `LayoutSize.sidebarWidth` |
| `kMinWindowSize` 下的行為 | 維持（側欄固定寬，主區吸收剩餘寬；不切換版型，§1）；側欄底部 slot 不溢位，算式見〈側欄底部 slot〉 |
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
| `navItems` | `List<NavItem>` | 是（恰 7，依 `AppDestination.values` 順序） | 不適用 |
| `pages` | `List<PageColumn>` | 是（恰 7，與 `navItems` 同序） | 不適用 |
| `bottomItems` | `List<NavItem>`（`action` 變體） | 是（恰 3，依序：設定 `nav-action-preferences`、鍵盤快捷鍵 `nav-action-shortcuts`、寫入清單 `nav-action-writeLog`） | 不適用 |
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
| 側欄底部三項標籤 | `sidebarSettingsLabel`、`keyboardShortcutsTitle`（1.133 登記）、`writeLogTitle`（1.143 登記），§4.0.6；經 4.7 `NavItem.action` 呼叫端傳入 |
| 唯讀降級徽章 | `readonlyWorkspaceNotGitBadge`、`readonlyWorkspaceGitMissingBadge`（1.143 登記，§4.0.6） |

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
| 焦點順序與操作路徑（桌機） | 四區段 Tab 順序（SPEC-003 §2.10）；overlayOpen 時焦點限制於浮層 |
| 對比 | 依 §4.0.2（標題文字 `textPrimary` / `surfaceChip` 通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染 default / overlayOpen
- [ ] `kMinWindowSize` 與 `kDesignSize` 下三格皆不溢位；側欄寬等於 `LayoutSize.sidebarWidth`
- [ ] `kMinWindowSize` 下側欄底部三項完整可見、貼齊側欄底，與最後一個導覽項不重疊；點三項不改變 `selectedDestinationProvider`
- [ ] 失敗計數為 0 時 `badge-writeLog-failure-count` 不存在、為 1 時存在且文字為 1；對照：計數由 0 變 1 時徽章出現
- [ ] 唯讀旗標為真時七畫面皆有 `badge-<screen>-readonly-workspace`，兩種原因各渲染對應文字；對照：旗標為假時不存在
- [ ] 標題最長測試文案截斷
- [ ] zh / en `appTitle` 不溢位
- [ ] Tab 序列依四區段（側欄底部三項接在七個導覽項之後）；overlayOpen 時 Tab 不離開浮層；`returnTo` 非 `null` 時 `action-<screen>-back` 存在、`null` 時不存在
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
**出現畫面**：§1–§6、§10。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 頁首 + 內容 | 由子件承載 | 建構（`IndexedStack` 一次建構全部導覽頁） | 不適用：容器無自身狀態集；畫面狀態由內容 slot 的狀態元件承載 | —（建構即渲染；`header` / `content` 由頁面層依畫面 provider 傳值換件，本容器不 watch，§2） | 本地即時（換件時機由頁面層依資料態決定，本容器只播過渡；§2 樂觀更新政策：0.1 無樂觀操作） |

互動瞬態（hover / pressed / focused）由子件承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器自身無互動，前三列不適用；本表寫內容 slot 換件（畫面級狀態轉換）的過渡由本容器承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器無可點元素，hover 由頁首右格與內容 slot 的子件承載 | — | — | 不適用（由子件承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 不適用：本容器非停留點；內容區段內頁首右側動作列先於內容（閱讀順序，無障礙子節；SPEC-003 §2.10），非可見頁排除於語意樹 | — | — | 不適用（順序由 `ReadingOrderTraversalPolicy` 承載，焦點環由子件承載） | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 不適用：容器無可點元素 | — | — | 不適用（由子件承載） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 0.1 無定位至本容器內容的場景：內容 slot 為單一子件（面板或全頁狀態元件，5.2），不需 scroll-into-view；4.21 `state-gaps-none` 與 4.23 阻擋狀態的焦點落點由頁面層執行（4.21 locate 列），本容器不參與；頁內定位依 §4.0.10 由持有 `ScrollController` 的 4.30 / 4.36–4.38 承載 | — | — | 不適用（無承載場景；頁內定位依 §4.0.10） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層於 `ref.listen` 依畫面 provider 換 `content` slot 子件，本容器不比對） | 內容 slot 換件 cross-fade（SPEC-003 §2.1〈未列轉換的預設〉與各 §3.x〈動畫提示〉）；`disableAnimations` 時一幀抵達（SPEC-003 §2.1）；播報由新內容的 header / `liveRegion` 承載（無障礙子節），本容器不播報 | `Motion.transition`（本容器承載 cross-fade） | 無（SPEC-003 各 §3.x 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（本容器）；無障礙播報由新內容承載；不升級系統通知） | 不適用（本容器單一狀態；畫面級狀態邊由 SPEC-001 與內容 slot 元件承載） | 反應：UX 審查（SPEC-003 §2.1、§3.x 動畫提示）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用——本容器不承載三層中任一層，全部由內容 slot 子件承載（等待指示：4.24 `LoadingState`，SPEC-003 §2.6；結果通知：換件本身，SPEC-003 §2.2 結果通知列；點擊確認：由子件承載）。服務類型：不適用於本容器本身——本容器只協調內容 slot 換件，不直接觸發服務，各子件的服務類型見其各自條目（SPEC-003 §2.12）。成功／失敗／逾時／服務不可用：皆不適用於本容器本身，由承載對應層級的子件各自呈現。輸入阻擋範圍：不適用於本容器——阻擋範圍由內容 slot（如 4.24）自行決定。重複觸發防護：不適用於本容器——本容器無自身觸發動作 | — | — | 不適用（三層皆由內容 slot 子件承載） | 不適用 | 規格撰寫者 |

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
| `content` | `Panel` \| `Panel.scrollable` \| `TwoColumnLayout` \| `EmptyState.page` \| `BlockedState` \| `LoadingState` \| `MissingSourceState` | 是（恰 1） | 不適用 |
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
**出現畫面**：§1–§6、§10（`header`）、§4（`footer`）、§1 詳情卡（`header`）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `header` | 高 `LayoutSize.headerHeight`、底邊框 `AppColors.border`、底 `surfaceBase`；詳情卡內不套固定高與邊框（`compactHeader` 修飾參數） | 無 | 頁首、詳情卡標題列 |
| `footer` | 高 `LayoutSize.rowHeightRelaxed`、頂邊框 | 無 | Ticket 清單摘要底列 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 左格 + 右格 | 由子件承載 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`leading` / `trailing` 由呼叫端傳值，本容器不 watch，§2） | 本地即時 |

互動瞬態（hover / pressed / focused）由右格子件承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本容器為純佈局容器且無自身狀態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純佈局容器——無可點元素、非 Tab 停留點、無自身狀態集（狀態矩陣僅 default 一列），左格截斷與右格固有寬為佈局不變式非回饋（5.3）；右格子件（`SegmentedControl` / `ButtonRow` / `AppButton.text`）的六類回饋依各自條目；頁首常駐於 `PageColumn` 頂端不捲動、詳情卡標題列釘於 `Panel.scrollable` 首格，皆不是被定位目標 | — | — | 不適用（由 4.10 / 4.34 / 4.4 子件承載；定位無承載場景） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定（依變體） |
| 最小尺寸 | 寬：2 × 水平內距（`header` 為 `Space.xl`；`footer` 與 `compactHeader` 詳情卡標題列為 `Space.sm`，見〈使用 design token〉間距列）+ 左格最小寬（一字元 + 省略號；一字元見 §4.0.3，取 `leading` 子件決定最小寬之文字 slot 的字級：`PageTitle` 依 4.11 取 `AppFontSize.subtitle`、`AppText.subtitle` 取 `AppFontSize.subtitle`、`AppText.body` 取 `AppFontSize.body`；左格依 5.3〈排列不變式〉不重疊列為截斷，計省略號）+ `Space.md` + 右格固有寬（無右格時後兩項不計）；高：依變體 |
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
**出現畫面**：§1–§6、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 無捲動 | `fill` slot 的子件吸收剩餘高；「恰一個填滿」由 slot 型別保證（單一 `Widget`，必填），呼叫端不包 `Expanded`；`leading`／`trailing` 依內容高排在其上下 | 矩陣、泳道、Ticket 列表、UC 步驟表，以及以 `EmptyState.section` 為主體的面板 |
| `scrollable` | 主體垂直捲動（`scroll-*` 錨點）；傳 `footer` 時面板底部多一條固定列 | 子件總高超過面板高時捲動；`footer` 不隨捲動移動（見下方〈固定底部 slot〉） | 追溯樹、破洞分節、主題分節、節點詳情主欄與右欄、格詳情卡；偏好設定面板與鍵盤快捷鍵面板（帶 `footer`） |

**固定底部 slot**（`scrollable`，`footer`，1.136）：面板內分上下兩格——上格為 `children` 的捲動區（`scrollKey` 掛於此格），下格為 `footer`，常駐可見、不進入捲動區。不傳 `footer` 時版面與 1.135 以前相同（只有捲動區），既有呼叫端不需改動。採用理由：鍵盤快捷鍵面板高 524（`LayoutSize.overlayWidth` × 2）時，標題加十列 `ListRow.shortcut` 加關閉鈕的總高超過面板高，關閉鈕若在 `children` 尾端就要捲到底才點得到；關閉是面板的離開路徑，不應依賴捲動位置。偏好設定面板（高 `LayoutSize.overlayWidth`）的編輯器清單長度隨本機安裝的編輯器而變，同一問題可能發生，故同步改用 `footer` 承載關閉鈕。

| 項目 | 值 |
|------|-----|
| 接受型別 | `AppButton` \| `ButtonRow`（面板層級的離開或確認動作；資料內容不得放入） |
| 版面 | 上格捲動區以 `Expanded` 吸收剩餘高；下格高為子件固有高；兩格之間間距 `Space.sm`；面板內距 `Space.md` 包住兩格（下格不另加內距） |
| 對齊 | 下格子件靠右（`AppButton` 單顆時亦同），與 `ButtonRow` 慣例一致 |
| Tab 順序 | 捲動區（容器停留點與其內可用動作）先，`footer` 後；面板開啟時的初始焦點由 `footer` 內 `AppButton` 的 `autofocus` 指定（4.4〈開啟時取得焦點〉） |
| `kMinWindowSize`（960 × 640）下的尺寸依據 | 主區可用高 = 640 − `LayoutSize.titleBarHeight`（36）= 604，不小於快捷鍵面板高 524，面板不被裁切。面板內：捲動區高 = 524 − 2 × `Space.md`（24）− `LayoutSize.hitTargetMin`（28，`footer` 內 `AppButton` 高）− `Space.sm`（8）= 464，不小於 `LayoutSize.rowHeightRelaxed`（34），至少一列可見；超出部分由捲動區捲動。偏好設定面板同式：262 − 24 − 28 − 8 = 202，同樣不小於 34 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 表面 + 子件 | `scrollable`：捲動 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`children` 由呼叫端傳值，本容器不 watch；`scrollable` 的 offset 由頁面層持有的 `ScrollController` 承載，屬 §2 頁面狀態保留的畫面級狀態，非本矩陣的狀態列） | 本地即時 |

互動瞬態（hover / pressed / focused）由子件承載；`scrollable` 容器可聚焦（SPEC-003 §2.10），其焦點環見回饋契約焦點列，不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> `scrollable` 變體持有 `scroll-gaps-sections` / `scroll-traceability-tree` / `scroll-tickets-topics` 等一維捲動錨點，是 §4.0.10 定位提示的一維執行端；`default` 變體六列皆不適用（資料視圖子件自行捲動）。捲動本身為操作路徑（操作機制子節），非六類回饋事件，其不變式列於表後。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器無可點元素；`scrollable` 的可捲性由捲軸指示承載（Flutter 預設 `Scrollbar`，操作機制子節），指標形狀預設 | — | — | 不適用（捲軸指示為操作機制的回饋通道，非六類事件） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | `scrollable`：容器為 Tab 內容區段的停留點（SPEC-003 §2.10 內容區段含捲動容器），焦點環依 §4.0.1 focused（提案：SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，容器的裝飾同元件）；聚焦後 PageUp / PageDown 為 Flutter 預設（方向鍵不列入 0.1 下界，操作機制子節）；`default`：非停留點；子件依堆疊順序（無障礙子節） | 無 | 無（SPEC-003 §2.10 不設時限；提案） | §1 子表「焦點」列（`default` 不適用：非停留點） | 不適用（本容器單一狀態） | 反應：UX 審查（SPEC-003 §2.10）；容器焦點環：規格撰寫者（提案）；通道：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 不適用：容器無可點元素；子件的點選由各自條目承載 | — | — | 不適用（由子件承載） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | `scrollable`：依 §4.0.10 執行——(a) `scroll-gaps-sections`：系統通知點擊／`viewGapsAction` 時頁面層以第一個分節第一個 `card-gaps-<itemId>` 的 key 呼叫定位入口，本容器 `jumpTo` / `ensureVisible`（`Duration.zero`）使該列 rect 與 viewport 有交集，並將焦點移入該列；高亮由 4.40 `ListRow.item` 依 `isLocated` 渲染，本容器不繪（SPEC-003 §2.2「點擊通知的導向」列）；(b) `scroll-traceability-tree`：4.39 `Tree` 展開後子層第一列在 viewport 外時的最小捲動（§4.0.10 場景 c），不高亮；(c) `scroll-tickets-topics` 與其餘 `scrollable` 實例：0.1 無定位場景。目標不存在時不捲動、不拋錯（§4.0.10 定位失敗列）；`default`：不適用（資料視圖子件自行承載） | 無（`jumpTo` 瞬間；高亮無入場動畫，§4.0.10） | 無（SPEC-003 §2.2 未設定位時限；§4.0.10 高亮時長為焦點機制非數值；提案） | §1 子表「定位提示」列（一維執行端；高亮由被定位子件渲染） | 不適用（本容器單一狀態；被定位子件的 located 邊見 4.40） | 反應：規格撰寫者（提案，§4.0.10；SPEC-003 §2.2 定目標與焦點落點）；通道：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（頁面層或子件依資料態換件） | 不適用：容器無語意狀態；子件換件的過渡由 4.28 `PageColumn`（內容 slot）/ 4.31 `TwoColumnLayout`（右欄）/ 4.41 `Section`（展開收合）承載，本容器只提供表面與捲動 | — | — | 不適用（過渡由 4.28 / 4.31 / 4.41 承載；不升級系統通知） | 不適用 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用於服務三層模型——本容器的自身互動（捲動、`scrollable` 作為 §4.0.10 一維執行端的定位）不觸發服務、不屬六類回饋事件的「等待與結果」範疇，其行為契約另由〈捲動操作路徑的不變式〉（表後）與 §4.0.10 定位提示承載；子件觸發的服務三層仍全數由子件或內容 slot 元件承載（SPEC-003 §2.2），本容器不涉入。服務類型：不適用——捲動與定位非服務觸發行為，不落入 SPEC-003 §2.12 四類分類（該分類軸為服務的等待與失敗形態，捲動無等待概念、不可能失敗）。成功／失敗／逾時／服務不可用：不適用（同上，捲動非服務行為，無四種結局概念）。輸入阻擋範圍：不適用——捲動恆可操作，不受阻擋政策管轄。重複觸發防護：不適用——捲動天然可重複、無需防護（非服務觸發，不落入 §2.12 重複觸發防護模型） | — | — | 不適用 | 不適用 | 規格撰寫者 |

**捲動操作路徑的不變式**（`scrollable`，非六類回饋事件，供測試點引用）：`ScrollController.offset` 隨捲動改變，內容不足一屏時 offset 維持 0 且不拋錯（SPEC-003 §1.1）；與其他捲動區不連動（FR-10、§1.1 連動禁令）；視窗尺寸變更時 offset 夾在新範圍、不歸零（SPEC-003 §2.8）；排序／換選引起的 offset 歸零由呼叫端經 controller 執行（SPEC-003 §3.4、§3.1），本容器不自行歸零。

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
| `leading` | 具名清單（`default`）：`Toolbar` \| `AppText` \| `ListRow.meta` \| `EmptyState.section` \| `BadgeRow`（§10 淺層 clone 標示，置於 `Toolbar` 之上，1.131）（順序即堆疊順序，位於 `fill` 之上） | 否（0..4） | 不適用 |
| `fill` | `Widget`（`default`）：`DataTable` \| `MatrixGrid` \| `SwimlaneGrid` \| `EmptyState.section`（吸收剩餘高；容器以 `Expanded` 承載，呼叫端不包） | `default` 必填（恰 1） | 不適用 |
| `trailing` | 具名清單（`default`）：`SplitRow.footer` \| `BadgeRow`（順序即堆疊順序，位於 `fill` 之下） | 否（0..2） | 不適用 |
| `children` | 具名清單（`scrollable`）：`Toolbar` \| `SplitRow` \| `Tree` \| `Section` \| `BadgeRow` \| `Divider` \| `AppText` \| `DocumentBody` \| `ListRow` \| `EmptyState.section` \| `ButtonRow`（順序即堆疊順序；總高超過面板高時捲動，無填滿子件） | `scrollable` 必填（1..12） | 不適用 |
| `footer` | `Widget?`（`scrollable`）：`AppButton` \| `ButtonRow`（固定於面板底部、不捲動，見〈固定底部 slot〉） | 否（0..1；偏好設定面板與鍵盤快捷鍵面板傳關閉鈕，其餘呼叫端不傳、行為不變） | 不適用 |
| `scrollKey` | `Key`（`scrollable`） | `scrollable` 必填（`scroll-<screen>-<area>`，掛於捲動區） | 不適用 |
| `panelKey` | `Key?` | 否（`panel-domain-cell-detail` / `panel-domain-cell-detail-empty` / `state-history-normal` / `state-history-empty`——§10 兩態的狀態根錨點落在面板，使淺層標示與篩選列位於狀態根之內，SPEC-003 §3.9〈淺層 clone 標示〉） | 不適用 |
| `locateTarget` | `Key?`（`scrollable`；§4.0.10 定位入口：值自 `null` 變為某子件 key 的那次 build，本容器於 post-frame 對該 key 執行捲動；焦點移入與高亮只於被定位子件接受 `isLocated` 時執行（§4.0.10 場景 a，4.40 `ListRow.item`），頁面層於高亮結束時改回 `null`；場景 c（4.39 樹展開後子項）只做最小捲動、不移焦點，頁面層於捲動完成的 post-frame 改回 `null`；同值不重複定位） | 否（提案） | 不適用 |

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

- [ ] 一支測試渲染 `default`（`fill` 為資料視圖，`leading`／`trailing` 各有與皆空兩種）與 `scrollable`（子件總高超過與不足一屏）
- [ ] `default`：`fill` 子件的高等於面板內高扣除內距、`leading`／`trailing` 內容高與子件間距；`fill` 為靠上對齊的 `EmptyState.section` 時，訊息上緣與不經 `fill` 直接堆疊時相同
- [ ] 兩種視窗尺寸下不溢位；`scrollable` 超出時 drag 後 offset 改變、不足時 offset 為 0 且無錯誤
- [ ] 無自有文字（本項不適用）
- [ ] 兩個獨立 `Panel.scrollable` 並排時捲動互不影響
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 主欄 + 右欄並排 | `TwoColumnLayout` |
| 分節（節首 + 項目） | `Section` |
| 呼叫端以 `Expanded` 包裹某個子件來指定填滿（容器看不到也驗不了「恰一個」，且頁面依賴容器內部為 Flex） | `default` 的 `fill` slot（component-contract-design 路徑 C 步驟 3〈佈局輔助的歸屬轉置〉） |

### 4.31 TwoColumnLayout（容器）

**用途**：主欄 `Panel`（填滿）+ 右欄 `Panel.scrollable`（固定寬 `LayoutSize.detailPaneWidth`）水平並排；兩欄各自獨立捲動（SPEC-003 FR-10、§1.1 連動禁令）。右欄常駐不隱藏（SPEC-001 §1 註記）。
**內容角色**：容器。
**何時不用**：單一面板（`Panel`）；三欄以上（0.1 無）。
**出現畫面**：§1（正常·矩陣、已選格）、§2（尚未選定 UC、flow 未結構化、正常：右欄為〈UC 選擇入口〉，§3.6）、§6（正常、部分損壞）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（右欄寬單一值，§3.7 第 21 項） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 兩欄 | 由子件承載 | 建構 | 不適用：容器無自身狀態集（右欄內容的提示／詳情卡切換是右欄 `Panel` 子件換件，非本容器狀態） | —（建構即渲染；`main` / `detail` 由頁面層依畫面 provider 傳值換件，本容器不 watch，§2） | 本地即時（換件時機由頁面層依資料態決定，本容器只播過渡；§2 樂觀更新政策：0.1 無樂觀操作） |

互動瞬態（hover / pressed / focused）由兩欄子件承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器自身無互動，前三列不適用；本表寫右欄換件（提示 ↔ 詳情卡、換選、關聯項替換）的過渡由本容器承載。兩欄捲動不連動（SPEC-003 §1.1 #8/#9、#1/#11）為操作路徑的不變式，非六類事件。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器無可點元素 | — | — | 不適用（由兩欄子件承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 不適用：本容器非停留點；主欄先、右欄後（閱讀順序，無障礙子節；SPEC-003 §2.10） | — | — | 不適用（順序由 `ReadingOrderTraversalPolicy` 承載） | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 不適用：容器無可點元素 | — | — | 不適用（由子件承載） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 0.1 無定位至本容器的場景：SPEC-003 §3.2「檢視關聯」jump 至節點詳情並「定位於關聯右欄」的對象是右欄本身——右欄常駐、固定寬（SPEC-001 §1 右欄常駐），jump 後右欄可見即為定位，不需捲動與高亮（提案：焦點落點沿用 §2.10 內容區段閱讀順序，不特別移入右欄）；主欄與右欄內部的定位依 §4.0.10 由各自的 4.30 `Panel.scrollable` 承載 | — | — | 不適用（無承載場景；欄內定位依 §4.0.10 由 4.30 承載） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層於 `ref.listen` 依選取格 provider（Domain 視圖）或節點 provider（節點詳情）換右欄或主欄子件） | 右欄換件 cross-fade（提示 ↔ 詳情卡、詳情卡內容換選，SPEC-003 §3.1 動畫提示）；主欄換件 cross-fade（關聯項點擊造成的主欄內容替換，SPEC-003 §3.6 動畫提示）；換件時另一欄寬與 offset 不變（SPEC-003 §3.1、§3.6：主欄 offset 歸零、右欄 offset 保留由呼叫端經 controller 執行）；播報由新內容的 header 承載（詳情卡標題／主欄標題，無障礙子節） | `Motion.transition`（本容器承載兩欄各自的 cross-fade） | 無（SPEC-003 §3.1、§3.6 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（本容器）；無障礙播報由新內容 header 承載；不升級系統通知） | 不適用（本容器單一狀態；右欄提示 ↔ 詳情卡為 4.21 `section` ↔ 詳情卡 `Panel.scrollable` 的換件） | 反應：UX 審查（SPEC-003 §3.1、§3.6）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用——本容器不承載三層中任一層，換件的資料為本地已解析內容、無等待指示（SPEC-003 §3.1「不顯示任何等待指示」、§3.6），結果通知為換件本身（SPEC-003 §2.2 結果通知列），皆由承載換件的呼叫端／子件負責，本容器只提供版面。服務類型：不適用於本容器本身——本容器不直接觸發服務。成功／失敗／逾時／服務不可用：皆不適用於本容器本身。輸入阻擋範圍：不適用於本容器——本容器無自身觸發動作。重複觸發防護：不適用於本容器——本容器無自身觸發動作 | — | — | 不適用 | 不適用 | 規格撰寫者 |

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

**用途**：Panel 首格的篩選列，水平、底邊框。`default`：`SearchField`（填滿）+ `FilterDropdown` × N + `IssueMarker.damagedDetail`（可點損壞計數，§3.7 第 14 項）；`history`：`SegmentedControl`（期間選擇）+ `AppCheckbox`（包含 ticket 建檔），靠左排列（SPEC-001 §10 篩選列，1.131）。
**內容角色**：容器。
**何時不用**：頁面級動作（`SplitRow.header` 右格 `ButtonRow`）；徽章列（`BadgeRow`）。
**出現畫面**：§4、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 子件：`search` + `filters` + `marker?`；`SearchField` 吸收剩餘寬 | 無 | Ticket 清單 |
| `history` | 子件：`period`（`SegmentedControl` 三段）+ `toggle`（`AppCheckbox`），子件固有寬、靠左，剩餘寬留白 | 無 | 變更記錄（§10 正常、期間內無事件） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 子件一列 | 由子件承載 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`history` 的 `period` / `toggle` 由第七畫面頁面層依期間篩選值與「包含 ticket 建檔」值傳值；`search` / `filters` / `marker` 由呼叫端傳值，含損壞疊加態時 `marker` 存在與否由頁面層依 Ticket 清單 provider 決定（`ticketListStateProvider` 的 `TicketsReady.corruptedCount` 大於 0），本容器不 watch，§2） | 本地即時 |

互動瞬態（hover / pressed / focused）由子件（4.12 / 4.13 / 4.6）承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本容器為純佈局容器且無自身狀態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純佈局容器——無可點元素、非 Tab 停留點、無自身狀態集；搜尋、篩選、損壞計數的六類回饋依 4.12 / 4.13 / 4.6 各自條目；篩選選單為子件的覆蓋層，不擠壓本容器版面（SPEC-003 §3.4 F4）；本容器釘於 `Panel` 首格常駐不捲動，不是被定位目標，搜尋命中的定位在 0.1 亦不存在（§4.0.10「搜尋命中列為子集重建」） | — | — | 不適用（由 4.12 / 4.13 / 4.6 子件承載；定位無承載場景） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；含底邊框的框體高固定 = 子件列高 + 2 × `Space.xs`（框體內上下內距各 `Space.xs`），不隨 ScreenUtil 縮放；子件列高：`default` 為 `LayoutSize.hitTargetMin`（框體高 `hitTargetMin` + 2 × `Space.xs`），`history` 為 `SegmentedControl` 元件固有高 `hitTargetMin` + 2 × `Space.xxs`（4.10；框體高 `hitTargetMin` + 2 × `Space.xxs` + 2 × `Space.xs`）；框體下方另有間距 `Space.sm`（見〈使用 design token〉間距列），不計入此固定高 |
| 最小尺寸 | 寬：`default` 為 `SearchField` 最小寬 + Σ `FilterDropdown` 固有寬 + `IssueMarker` 寬 + (N + 1) × `Space.sm`；`history` 為 `SegmentedControl` 固有寬 + `AppCheckbox` 固有寬 + `Space.sm` |
| 最小命中區 | 不適用 |
| 最大尺寸 | 寬無上限；高固定 |
| `kMinWindowSize` 下的行為 | 維持（`default`：`SearchField` 吸收剩餘寬；`history`：`AppCheckbox` 固有寬，`SegmentedControl` 取有界寬、超出時各段 label 截斷；5.6） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `search` | `SearchField` | `default` 必填（恰 1，首格）；`history` 不接受 | 不適用 |
| `filters` | `List<FilterDropdown>` | `default` 必填（1..3）；`history` 不接受 | 不適用 |
| `marker` | `IssueMarker.damagedDetail?` | 否（`default` 含損壞疊加態時存在，末格靠右；`history` 不接受） | 不適用 |
| `period` | `SegmentedControl`（`segments` 長度 3，錨點 `option-history-period-<period>`） | `history` 必填（恰 1，首格）；`default` 不接受 | 不適用 |
| `toggle` | `AppCheckbox`（`action-history-include-ticket-created`） | `history` 必填（恰 1，接於 `period` 之後）；`default` 不接受 | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.borderStrong`（底邊框，畫布） |
| 間距 | 子件最小間距 `Space.sm`；框體上下內距 `Space.xs`（計入〈尺寸契約〉固定高）；底邊框下方與後續內容的間距 `Space.sm`（在框體之外，不計入固定高） |
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
| 焦點順序與操作路徑（桌機） | `default`：搜尋 → 篩選 × N → 損壞計數；`history`：期間三段 → 包含 ticket 建檔（閱讀順序） |
| 對比 | 不適用 |

#### 測試點（widget test）

- [ ] 一支測試渲染 `default`（N = 1 / 2 / 3 × 有無 `marker`）與 `history`
- [ ] 兩種視窗尺寸下不溢位；`default` 的 `SearchField` 寬等於剩餘寬；`history` 兩子件靠左、`AppCheckbox` 左緣 = `SegmentedControl` 右緣 + `Space.sm`
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
**出現畫面**：§1、§2、§6、§10（淺層 clone 標示）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 無邊框 | 無 | 標籤列、事件標籤 |
| `legend` | 頂邊框 `AppColors.border`、頂部內距 `Space.sm` | 無（間距同 `default`，§3.7 第 12 項） | 面板底部圖例列 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 一列或多列徽章 | 無（子件非互動） | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`children` 由呼叫端傳值，本容器不 watch，§2） | 本地即時 |

無互動瞬態：容器與子件（4.5 `Badge`）皆非互動元素。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本容器與其子件皆為純顯示且無自身狀態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純佈局容器且子件非互動——不進入 Tab 順序（無障礙子節）、無自身狀態集；換行為佈局不變式（5.7）非回饋；徽章文字改變隨父件重建，播報由所在列或詳情卡標題承載（4.5）；圖例列釘於面板底部、標籤列位於詳情卡與步驟表格內，皆不是被定位目標 | — | — | 不適用（無互動，無承載者） | 不適用 | 規格撰寫者 |

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

**用途**：`AppButton` × 1..3 水平；狀態元件動作區、頁首右側頁面級動作區（§3.7 第 17、18 項）、格詳情卡動作區；1.150 起另用於可修正破洞項 `ListRow.item` 的 trailing（`wrap: false`，SPEC-001 §5〈破洞報告的編輯入口〉）。
**內容角色**：容器。
**何時不用**：徽章列（`BadgeRow`）；單一 `AppButton.text` 於浮層末格（直接放入 `SwitcherOverlay`）。
**出現畫面**：§1–§6、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；`alignment` 參數（`start` / `center` / `end`）；`wrap` 參數（預設 `true`，1.150） | `wrap: false` 時不換行，子件恆在同一列 | `wrap: false` 只用於 `ListRow.item` trailing：列高須維持 `item` 的固有兩行高，換行會變成兩列按鈕；其餘使用處維持預設 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 一列或換行的按鈕（`wrap: false` 時恆為一列） | 由子件承載 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`children` / `alignment` / `wrap` 由呼叫端傳值，本容器不 watch，§2） | 本地即時 |

互動瞬態（hover / pressed / focused）由子件 4.4 `AppButton` 承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉；本容器為純佈局容器且無自身狀態變更，依範本整節填一列。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 不適用（六類事件全部） | — | 理由：純佈局容器——本容器無可點元素、非 Tab 停留點、無自身狀態集；按鈕的六類回饋依 4.4 `AppButton`（`primary` 先於其餘，閱讀順序，無障礙子節）；換行為佈局不變式（5.8）非回饋；動作區位於狀態元件內、頁首右格或詳情卡末格，皆不是被定位目標 | — | — | 不適用（由 4.4 `AppButton` 承載；定位無承載場景） | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動 | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（Σ 按鈕寬 + (N − 1) × `Space.sm`）；父格位寬不足時換行。`wrap: false`：不換行，固有寬即最小寬，由父格位保證不小於它（`ListRow.item` 的核對見 5.14〈可修正破洞項的寬度核對〉）。父格位寬小於固有寬時仍維持一列，不換行、不截斷 label，超出部分溢位（以一列的 `Row` 實作）。宿主違約的回報就是 `RenderFlex` 自身的溢位回報（debug 期經 `FlutterError.reportError`，不中斷 layout、不替換子樹），本元件不另做自訂回報。理由：溢位已由 `RenderFlex` 回報一次，再加自訂回報會變成兩筆，測試取回的是「Multiple exceptions」；沿用框架回報也不必處理寬度比較的浮點容差。release 下不回報、不記日誌。不用 `developer.log`：SPEC-010 FR-04 規定 writer 以外不得直接呼叫，且 layout 期會反覆觸發，屬高頻事件。debug 版 App 中，這筆回報經 `installGlobalErrorHandlers` 的 `FlutterError.onError` 進入 `reportFatalError`（`lib/main.dart`），畫面換成致命錯誤狀態，與現有其他 `RenderFlex` 溢位走同一條路；它在開發期就會被看見，不會靜默。實作現況：`lib/components/button_row.dart` 以 `Wrap` 實作，放在 `ListRow` 的 `Row` 內屬非 flex 子件、寬度無上限，所以預設的 `wrap: true` 在該處本來也不會換行；`wrap: false` 讓這個行為成為明文契約，並在受限父格位下以 debug 期回報揭露違約，而不是靜默換行 |
| 最小尺寸 | 寬：最寬單一按鈕的最小寬（`LayoutSize.hitTargetMin`）；`wrap: false` 時為固有寬；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | 不適用（子件各自） |
| 最大尺寸 | 寬：父格位寬（`wrap: false` 違約時例外：寬為固有寬，超出父格位的部分溢位，見尺寸模式）；高：3 列 × `LayoutSize.hitTargetMin` + 2 × `Space.sm`；`wrap: false` 時高固定為 `LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（換行）；`wrap: false` 時維持一列（5.14 核對成立） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `children` | `List<AppButton>` | 是（1..3；`primary` 至多 1 且置於首位） | 不適用 |
| `alignment` | `start` / `center` / `end` | 否（預設 `start`；狀態元件內 `center`、頁首右格 `end`、`ListRow.item` trailing `end`） | 不適用 |
| `wrap` | `bool` | 否（預設 `true`；`false` 只限 `ListRow.item` 的 trailing，1.150） | 不適用 |

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
| 可放入的容器 | `SplitRow.header`（右格）、`Panel.scrollable`（詳情卡末格）；作為 `EmptyState` / `BlockedState` / `LoadingState` / `LoadPrompt` / `MissingSourceState` 的內部動作區；`ListRow.item` 的 trailing（限 `wrap: false`、恰兩個 `AppButton.text`，1.150） |
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
- [ ] `wrap: false`（1.150）的 E1 對照：同一組兩鈕，直接放進寬為「固有寬 − 1」的受限父格位（以 `SizedBox` 給有界寬，不經 `ListRow`，理由是 `ListRow` 的 `Row` 給 trailing 無上限寬，兩值都不換行，無鑑別力），各跑一次傳與不傳。不傳時為兩列（高 = 2 × `LayoutSize.hitTargetMin` + `Space.sm`），子件不相交；傳 `wrap: false` 時為一列（高 = `LayoutSize.hitTargetMin`），且 `tester.takeException()` 取回的是 `RenderFlex` 的溢位回報（訊息含 overflowed，只此一筆，不是「Multiple exceptions」）；不傳時 `takeException()` 為 `null`。兩者產物不同。`reportError` 不中斷 layout，所以「排成一列」與「有回報」可在同一次執行中一起斷言
- [ ] `wrap: false`：父寬等於固有寬時兩鈕同列、不相交，高等於 `LayoutSize.hitTargetMin`，`tester.takeException()` 為 `null`
- [ ] 無自有文字（本項不適用）
- [ ] 子件最長測試文案下仍不相交
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 四個以上動作 | 禁止（0.1 上限 3；出現需求走待決出口） |
| 徽章列 | `BadgeRow` |

### 4.35 TableRow（容器）

**實作類別**：`AppTableRow`（契約名 `TableRow` 與 `package:flutter/widgets.dart` 內建 `TableRow`（`Table` widget 用）撞名，依 `AppButton`／`AppText` 既有前綴慣例更名；本節條目名與契約值不變）。

**用途**：欄寬對齊表頭的水平格線列；`header`（欄首）、`ticket`（票列，列表與主題模式共用欄序 ID / 標題 / 狀態 / 優先 / blockedBy / 標記，§3.7 第 15 項；blockedBy 欄 SPEC-001 §4 v1.9）、`step`（序號 / 步驟名 / domain / 事件）、`eventFlow`（事件 / 發出 / 消費 / 孤立事件標記，SPEC-001 §2〈事件流小表〉）。
**內容角色**：容器。
**何時不用**：主文字填滿的清單列（`ListRow`）；二維格線（`MatrixGrid`）。
**出現畫面**：§2、§4、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `header` | 底邊框 `AppColors.borderStrong`；格為 `TableColumnHeader` | 無 | 表頭 |
| `ticket` | 底邊框 `AppColors.border`；格：`AppText.mono`（ID）、`AppText.body`（標題）、`Badge.status`（inline）、`AppText.caption`（優先）、`AppText.mono`（blockedBy：被阻擋的 ticket ID 以「, 」串接，無則「—」，單行截斷）、`IssueMarker.damagedDetail?`（標記） | 整列可點 → 開票（`card-tickets-<ticketId>`）；可被定位（located，SPEC-003 §3.4〈帶目標跳入〉） | Ticket 清單列表與主題模式 |
| `historyEvent` | 底邊框 `AppColors.border`；格：`Badge.category`（變動：`historyEventAdded` tone `positive` / `historyEventRemoved` tone `negative`，inline）、`AppText.mono`（邊型鍵名原值）、`RelationItem`（宣告端節點 ID，`isMono=true`，`action-history-open-<index>-declarer`）、`RelationItem` 或 `AppText.mono`（對端：節點 ID 時為 `RelationItem`，`action-history-open-<index>-counterpart`；`domain_dependency` 的 domain 名稱時為 `AppText.mono` 純文字、無錨點，SPEC-008 FR-07 規則 4）、`AppText.mono`（commit 短 hash）、`AppText.caption`（日期 `yyyy-MM-dd`）、`AppText.body`（`historyEventAuthorMessage`：作者與訊息首行） | **列本體非互動**（SPEC-003 §3.9 無列點擊條文，只有節點格的 jump）；節點格各自承載點擊；不可被定位（0.7 無定位至事件列的場景） | 變更記錄事件清單（SPEC-001 §10，1.131） |
| `eventFlow` | 底邊框 `AppColors.border`；格：`AppText.mono`（EVT ID）、`AppText.body`（發出：`eventFlowStepDomain`，多個發出步驟時以「、」串接，缺則 `eventOutsideUc`，`0.1.0-W3-335.38` S-24）、`AppText.body`（消費：同上，多個以「、」串接）、`AppIcon?`（孤立事件標記：warning 圖示 `AppColors.error`，非互動，testKey `badge-ucFlow-event-orphan-<evtId>`，朗讀 `orphanEventMarkerLabel`） | **非互動列**（SPEC-003 §3.2〈事件流小表〉無列點擊條文）；格內 domain 值的資料來源依賴 FlowStep 所屬 domain 的定案（`0.1.0-W3-341`，CLAUDE.md §6 現行待決），本變體只定呈現；可被定位（located，SPEC-003 §3.5 事件類破洞項） | UC Flow 事件流小表 |
| `step` | 底邊框 `AppColors.border`；格：`StepNumber`、`AppText.body`（步驟名）、`RelationItem`（domain，`isMono=false`）、`BadgeRow`（事件） | 整列可點 → 節點詳情（`card-ucFlow-step-<stepId>`）；domain 格另有自己的點擊；可被定位（located，flow 類破洞項跳入，SPEC-001 §5，`0.5.0-W1-114.23`） | UC Flow 步驟表 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 一列格 | `ticket` / `step`：點選整列 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`cells` 由 4.36 `DataTable` 或 4.41 `Section.collapsible` 依列資料傳值，本容器不 watch，§2；列資料的來源見 4.36） | 本地即時 |
| hover（僅指標形態，`ticket` / `step`） | 依 §4.0.1（整列） | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed（`ticket` / `step`） | 依 §4.0.1（整列） | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused（`ticket` / `step`） | 依 §4.0.1（整列） | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |
| located（`ticket` / `eventFlow` / `step`） | 底 `AppColors.surfaceIconTint`（整列，§4.0.10 高亮 token） | 同所屬變體 | `isLocated` 為 `true`：`ticket` 由 SPEC-003 §3.4〈帶目標跳入〉定位；`eventFlow` 由 SPEC-003 §3.5 事件類破洞項跳入定位；`step` 由 flow 類破洞項跳入定位（SPEC-001 §5，J2；§4.0.10 場景 g） | 焦點離開本列或任一指標按下 → 呼叫端改 `isLocated` 為 `false`（§4.0.10 高亮時長列，同 4.40 `item`） | 資料態：被定位列 id 由頁面層持有並傳值，本容器不 watch（§2） | 本地即時 |

`historyEvent` 列本體同樣無 hover／pressed／focused、不進入 Tab 順序（非按鈕，`Semantics` label 為 `historyEventA11yLabel`）；列內 `RelationItem` 各為 Tab 停留點，其瞬態與回饋依 4.19。`header` / `eventFlow` 變體無 hover／pressed／focused（列本體非互動；`eventFlow` 不進入 Tab 順序，located 時焦點移入僅供輔助技術朗讀，`Semantics.focusable` 為 `true`、非按鈕；提案）（列本體非互動；可排序欄首的瞬態由 4.14 承載）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 六列皆只適用 `ticket` / `step` 變體（整列可點）；`historyEvent` 列本體非互動、六類事件不適用於列本體，節點格的回饋依 4.19（press-ack：jump 至 `nav-page-nodeDetail`、`returnTo` 設為 `history`，SPEC-003 §3.9；服務類型本地即時），列集合改變（篩選、重新整理完成）由 4.36 承載、無列動畫（SPEC-003 §3.9〈動畫提示〉「同一狀態內只替換清單與事件數，不做動畫」）；`header` 為非互動列，其欄首格的回饋依 4.14。格內可點子件（`step` 的 `RelationItem` 4.19、`ticket` 的 `IssueMarker` 4.6）各自承載回饋且不觸發列點擊。drag 為容器操作路徑（不可拖曳，觸發所在 `DataTable` 捲動，SPEC-003 §1.3），非六類回饋事件，由 4.36 承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 整列 hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為整列）；指標形狀 `SystemMouseCursors.click`；`header` 無 hover | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列（`header` 不適用：非互動列） | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 整列焦點環（§4.0.1 focused）；列為 Tab 內容區段的一個停留點，列內可點格（`RelationItem` / `IssueMarker`）緊接其後（SPEC-003 §2.10；無障礙子節）；虛擬化下焦點移至未建構列時由 4.36 自動捲入；朗讀 `Semantics.button` label（各格文字依序串接，無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列（`header` 不適用） | default → focused → default | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 整列 pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行：`ticket` → jump 至 `nav-page-nodeDetail`、`returnTo` 設為 `tickets`（SPEC-003 §3.4 開票列）；`step` → jump 至 `nav-page-nodeDetail`、`returnTo` 設為 `ucFlow`（SPEC-003 §3.2）；點 domain 格或標記格不觸發列 `onTap`（由 4.19 / 4.6 承載；測試點子節）；篩選選單展開時點列只收合選單、不 jump（SPEC-003 §3.4 篩選 · 點外部收合列） | Material 內建 ripple；跨畫面切頁無轉場（`IndexedStack`，SPEC-003 §2.8） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列（`header` 不適用） | default → pressed → default（本列狀態不變；結果落在另一畫面） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.2、§3.4）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | `ticket` / `eventFlow`（1.35 起有場景，原「0.1 無定位至票列」判讀由 SPEC-003 v1.27 取代）：本列為被定位目標，捲動由所在 4.36 `DataTable`（`scroll-tickets-list` / `scroll-ucFlow-steps`）執行 scroll-into-view，本列依 `isLocated` 渲染整列底 `surfaceIconTint` 並接受焦點移入（定位手法同 SPEC-003 §2.2「系統層通知」點擊導向列；SPEC-003 §3.4〈帶目標跳入〉、§3.5 事件類列）；`step`（1.91 起有場景，`0.5.0-W1-114.23`）：flow 類破洞項跳入時本列為被定位目標（SPEC-001 §5〈破洞項的主操作與次要操作〉flow 類「定位到出錯的步驟」，用戶裁決 J2；§4.0.10 場景 g），捲動由 4.36 步驟表（`scroll-ucFlow-steps`）執行，高亮與焦點移入同 `ticket`；搜尋、篩選、排序後的 offset 歸零屬結果通知非定位（SPEC-003 §3.4） | — | — | 由容器承載（§1 子表「定位提示」列；依 §4.0.10） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：4.36 `DataTable` / 4.41 `Section` 依列資料重建本列；含排序、篩選、搜尋後的列集合改變與切換專案重置） | 本列無語意狀態，格內容隨重建替換：列表重繪無 cross-fade、無逐列入場動畫（SPEC-003 §3.4 動畫提示「列表首次渲染」「篩選或排序後的列表重繪」、§3.2「步驟表首次渲染」）；`Badge.status` / `IssueMarker` 的出現由各自條目承載；列數變化由 `SplitRow.footer` 摘要文字播報（4.36 無障礙子節），本列不播報 | 無（SPEC-003 §3.2、§3.4 明訂無列動畫） | 無（列表重建隨資料態瞬切；SPEC-003 無列級時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報由 4.36 / 4.29 `footer` 承載；不升級系統通知） | 不適用（本列單一語意狀態） | 反應：UX 審查（SPEC-003 §3.2、§3.4 動畫提示）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，整列 pressed 態）由本列自身承載（`ticket` / `step` 變體）——第二層不適用（jump 為本地運算無服務受理階段），第三層即結果通知本身（`IndexedStack` 可見頁更換的狀態轉換，SPEC-003 §2.2 結果通知列）。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，jump 無載入、節點詳情資料為本地已解析內容，SPEC-003 §2.6；失敗形態為不可能失敗，純本地頁面切換，SPEC-003 §2.12）。成功：`IndexedStack` 切至節點詳情頁；失敗：依兩軸判定不可能發生（純本地狀態操作），故本列無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，本地已解析內容無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.6、§2.12）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `ticket` / `step`：依 §4.0.7 點選列（整列為一個 Tab 停留點；格內的 `RelationItem` / `IssueMarker` 另為停留點）；`historyEvent`：列本體不適用，格內 `RelationItem` 依 4.19 點選；`header` / `eventFlow`：不適用（非互動列） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定 `LayoutSize.rowHeightRelaxed` |
| 最小尺寸 | 寬：2 × `Space.sm`（自身水平內距）+ Σ 固定寬欄 + 填滿欄所需寬 + (欄數 − 1) × `Space.md`。各變體有兩個填滿欄（`ticket` 標題 flex 2／blockedBy flex 1；`step` 步驟名與事件各 flex 1；`eventFlow` 發出與消費各 flex 1；`header` 沿用所對齊變體的欄規格），剩餘寬依 flex 比例分配，故填滿欄所需寬 = max over 各填滿欄（該欄最小寬 × Σflex ÷ 該欄 flex）。各填滿欄最小寬：文字子件為一字元 + 省略號（一字元見 §4.0.3，取該欄文字子件字級：`AppText.body` 與 `AppText.mono` 取 `AppFontSize.body`，`header` 的 `TableColumnHeader` 依 4.14 取 `AppFontSize.caption`；省略號依本表 `kMinWindowSize` 列的截斷敘述計入；截斷或換行由呼叫端以 `AppText.singleLine`／`AppText.multiLine` 明示，元件不依內容自行猜測（4.1 `AppText`〈內容政策〉，`0.5.0-W1-508.1`））；`step` 事件欄子件為 `BadgeRow`，不適用一字元加省略號，取 4.33 `BadgeRow` 最小寬（實作 `app_table_row.dart` `AppTableRow.ticketColumns`／`stepColumns`／`eventFlowColumns` 與 `_buildColumnChildren`，1.101 追認複數填滿欄）；高：`LayoutSize.rowHeightRelaxed` |
| 最小命中區 | `ticket` / `step` 整列高 `LayoutSize.rowHeightRelaxed` ≥ `LayoutSize.hitTargetMin` |
| 最大尺寸 | 寬無上限；高固定 |
| 欄規格（`ticket`） | ID 固定寬 `LayoutSize.ticketIdColumnWidth`（132）、標題填滿 `flex(2)`、狀態 `LayoutSize.ticketStatusColumnWidth`（84）、優先 `LayoutSize.ticketPriorityColumnWidth`（40）、blockedBy 填滿 `flex(1)`（無專屬寬度 token；ID 清單長度不定，固定寬會在多值時全部截斷，填滿欄以比例讓標題優先，提案）、標記 `LayoutSize.ticketMarkerColumnWidth`（22） |
| 欄規格（`eventFlow`） | 事件 `LayoutSize.ticketIdColumnWidth`（沿用 ID 欄寬，EVT ID 與 ticket ID 同為等寬識別字，提案）、發出與消費兩填滿欄等分 `flex(1)`、標記 `LayoutSize.ticketMarkerColumnWidth`（22）；`header` 同欄規格，標記欄首無文字 |
| 欄規格（`step`） | 序號 `LayoutSize.stepNumberColumnWidth`（26）、步驟名填滿、domain `LayoutSize.stepDomainColumnWidth`（118）、事件填滿（兩個填滿欄等分，畫布 `1fr 118px 1fr`） |
| 欄規格（`historyEvent`） | 變動 `LayoutSize.ticketStatusColumnWidth`（84，en「Removed」最長）、邊型 `LayoutSize.ticketIdColumnWidth`（132，鍵名如 `bundle_dependency` 為等寬識別字，同 ID 欄理由）、宣告端 `flex(1)`、對端 `flex(1)`、commit `LayoutSize.ticketStatusColumnWidth`（84，7 位短 hash）、日期 `LayoutSize.ticketStatusColumnWidth`（84，`yyyy-MM-dd`）、作者與訊息 `flex(2)`（訊息首行長度不定，比例上讓它優先）。全部沿用既有寬度 token，不新增 token；`header` 同欄規格，欄首 `columnChange` … `columnAuthorMessage` |
| `kMinWindowSize` 下的行為 | 維持（填滿欄截斷） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（格文字依各子件契約：ID `TestCopy.nodeId`、標題 `TestCopy.nodeTitle`、步驟名 `TestCopy.stepName`） | | | |

`ticket` 解析失敗列（`0.1.0-W3-335.38` S-07）：ID 格取檔名；其餘文字格（標題、狀態、優先、blockedBy）顯示「—」；標記格 `IssueMarker.damagedDetail`。

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `columns` | `List<ColumnSpec>`（`fixed(LayoutSize.*)` / `flex(n)`），由 `DataTable` 統一傳入 | 是 | 不適用 |
| `cells` | 依變體固定型別序列（見變體表）；上限 = 欄數（依各變體欄規格列） | 是 | 不適用 |
| `isLocated` | `bool`（`ticket` / `eventFlow` / `step`；§4.0.10 高亮傳值，預設 `false`） | 否（其餘變體不接受） | 不適用 |
| `onTap` | `VoidCallback`（`ticket` / `step`） | 是（`historyEvent` 不接受：列本體非互動，點擊由格內 `RelationItem.onTap` 承載） | 不適用 |
| `semanticLabel` | `String`（`historyEvent`） | `historyEvent` 必填（`historyEventA11yLabel` 組字，含截斷欄的完整值）；其餘變體不接受 | 呼叫端（i18n key 取值） |
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
| 可放入的容器 | `DataTable`（`header` 恰 1 + 資料列 × N；`eventFlow` 只放入 UC Flow 事件流小表的 `DataTable.plain`；`historyEvent` 只放入變更記錄事件清單的 `DataTable.virtual`）、`Section.collapsible`（主題節內 `ticket` × N） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 格垂直置中；文字欄 `start`、優先欄 `start`、序號欄置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `ticket` / `step`：`Semantics.button`，label 為各格文字依序串接（`ticket`：ID，標題，狀態，優先，blockedBy 完整值不截斷）；`eventFlow`：非按鈕，label 為事件，發出，消費，有標記時附 `orphanEventMarkerLabel`；`historyEvent`：非按鈕，label 為 `historyEventA11yLabel`（變動、邊型、宣告端、對端、hash、日期、作者、訊息首行完整值），格內 `RelationItem` 另依 4.19 朗讀；`header`：各格 header |
| 狀態變化播報 | 不適用 |
| 非視覺替代訊號 | 損壞由 `IssueMarker` 標籤承載；孤立事件由 `orphanEventMarkerLabel` 承載（紅色圖示非唯一訊號）；located 高亮以焦點移入為非視覺替代 |
| 焦點順序與操作路徑（桌機） | 列為 Tab 停留點；列內可點格緊接其後；Space / Enter 開票 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染全部變體（`ticket` 含 / 不含標記、blockedBy 空（「—」）/ 多值截斷；`step` 事件欄 0 / 5 個徽章；`eventFlow` 含 / 不含孤立事件標記、發出或消費為 `eventOutsideUc`）
- [ ] `ticket` / `eventFlow` / `step` 的 `isLocated` 為 `true` 時整列底色為 `surfaceIconTint`，`false` 時無底色；`eventFlow` 點擊不呼叫任何回呼（非互動）
- [ ] `step` 以 `isLocated: true` 渲染時列點選仍呼叫 `onTap` 恰一次（located 不改變互動）
- [ ] `historyEvent`：對端為節點時渲染兩個 `RelationItem`（錨點 `action-history-open-<index>-declarer`／`-counterpart`），對端為 domain 名稱時只有宣告端錨點、對端為 `AppText.mono`（對照組：同一列資料只換對端型別，錨點數 2 → 1）；點列本體空白處不呼叫任何回呼；變動欄 `historyEventAdded` tone `positive`、`historyEventRemoved` tone `negative`
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

**實作類別**：`AppDataTable`（契約名 `DataTable` 與 `package:flutter/material.dart` 內建 `DataTable` 撞名，依 `AppTableRow` 既有前綴慣例更名；本節條目名與契約值不變）。

**用途**：`TableRow.header` + `TableRow` × N 垂直；Ticket 清單為虛擬捲動（`scroll-tickets-list`），UC Flow 為一般捲動（`scroll-ucFlow-steps`）。傳值 + callback，不 watch；捲動 offset 由頁面層持有的 `ScrollController` 傳入（§2，`0.6.0-W1-193` 裁決）。
**內容角色**：容器。
**何時不用**：二維格線（`MatrixGrid`）；依深度縮排的列（`Tree`）；分節（`Section`）。
**出現畫面**：§2、§4、§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `virtual` | 同 | 列以 `ListView.builder` + 固定 `itemExtent`（`LayoutSize.rowHeightRelaxed`）虛擬化；不分頁 | Ticket 清單（真實規模不低於 1300 筆）；變更記錄事件清單（`scroll-history-events`，全部歷史的事件數隨 commit 數成長、無上限，1.131） |
| `plain` | 同 | 一般 `ListView` | UC Flow 步驟表 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 表頭 + 列 | 捲動、列點選、排序（表頭） | 建構（資料由畫面層以 `select` 訂閱後傳入） | 不適用：容器無自身狀態集（空資料由畫面改渲染 `EmptyState`，本容器不承載 empty） | 資料態：列集合與排序來自所在畫面的資料 provider——Ticket 清單（`virtual`：已載入票列經搜尋詞、篩選值、`order` 過濾排序後的子集）與 UC Flow（`plain`：選定 UC 的 `FlowStep` 列）分別來自 `ticketListStateProvider` 的 `TicketsReady.tickets`（畫面層過濾排序後以 `rows` 傳入）與 `ucFlowUcListProvider` 選定 UC 的 `steps`（事件附錄另讀 `ucFlowEventGapsProvider`）；本容器不 watch：畫面層以 `ref.watch(provider.select(...))` 取得列集合後以 `rows` 傳入（§2 最小重繪邊界，`0.6.0-W1-193` 裁決），列以 builder 逐列建構；offset 由頁面層持有的 `ScrollController` 以 `controller` 參數傳入本容器（§2 頁面狀態保留） | 等確認才顯示（列集合為最後完成輪次結果的資料態，Ticket 清單無載入態，SPEC-001 §4〈Ticket 清單由掃描輪次衍生〉；搜尋、篩選、排序的子集重排為本地即時，SPEC-003 §3.4；§2 樂觀更新政策：0.1 無樂觀操作） |

互動瞬態（hover / pressed / focused）由列（4.35）與可排序欄首（4.14）承載，本容器不另列；本容器可聚焦以承載鍵盤捲動（SPEC-003 §2.10 內容區段含捲動容器）。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器為資料視圖容器，持有 `scroll-tickets-list` / `scroll-ucFlow-steps`，是 §4.0.10 定位提示的一維執行端（1.35 起有場景：`scroll-tickets-list` 定位 `TableRow.ticket`、`scroll-ucFlow-steps` 定位 `appendix` 內的 `TableRow.eventFlow`，見 §4.0.10 場景 d／e）；列與欄首的 affordance／press-ack 由 4.35 / 4.14 承載。捲動為操作路徑，非六類回饋事件，其不變式列於表後。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器自身無可點元素；列 hover 由 4.35、可排序欄首 hover 由 4.14 承載；可捲性由捲軸指示承載（操作機制子節） | — | — | 不適用（由 4.35 / 4.14 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 表頭可排序格 → 列依序（閱讀順序，SPEC-003 §2.10；無障礙子節）；`virtual` 下焦點移至未建構列時本容器自動捲入（Flutter `ensureVisible`，無障礙子節）；本容器為 scrollable 語意節點、可聚焦後以 PageUp / PageDown 捲動（Flutter 預設），焦點環依 §4.0.1（提案，同 4.30）；各停留點的焦點環由 4.35 / 4.14 承載 | 無 | 無（SPEC-003 §2.10 不設時限；提案） | §1 子表「焦點」列（順序與自動捲入由本容器承載；焦點環由子件承載） | 不適用（本容器單一狀態） | 反應：UX 審查（SPEC-003 §2.10）；容器焦點環與自動捲入：規格撰寫者（提案）；通道：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由子件承載：列點選 4.35（jump 至節點詳情）、欄首排序 4.14（`onSort`）；排序後由頁面層對其持有的 `ScrollController` 呼叫 `jumpTo(0)` 將 offset 歸零，本容器不自行歸零（SPEC-003 §3.4 排序 · 循環／換欄列；`0.6.0-W1-193` 裁決） | Material 內建 ripple（經子件） | pressed 態出現於 `Motion.feedback` 內（經子件） | §1 子表「按下確認」列（由 4.35 / 4.14 承載） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 依 §4.0.10 為一維執行端，0.1 無定位場景：搜尋為子集重建而非命中列高亮（SPEC-003 §3.4 搜尋列，4.12 locate 列所述「命中列定位」在 0.1 不發生）；篩選與排序後 offset 歸零屬結果通知（SPEC-003 §3.4）；跨畫面 jump 的目標是節點詳情，本容器是來源。機制備註（提案，供後續版本）：`virtual` 變體的目標列可能未建構，定位須以列索引 × `LayoutSize.rowHeightRelaxed`（`itemExtent`）計算 offset 後 `jumpTo`，不得用 `ensureVisible`；`plain` 變體依 §4.0.10 捲動方式 | — | — | §1 子表「定位提示」列（一維執行端，0.1 無場景） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（畫面層於 `ref.listen` 比對資料 provider 的列集合／`order` 新舊值，改傳 `rows`，本容器依傳入值重建列；排序循環、篩選選取後的 offset 歸零與切換專案重置，由頁面層對其持有的 `ScrollController` 呼叫；含搜尋 debounce 到期、篩選選取、排序循環、切換專案重置（SPEC-003 §3.4 生命週期；`0.6.0-W1-193` 裁決）） | 列集合改變為直接重建：無 cross-fade、無逐列入場動畫（SPEC-003 §3.4 動畫提示「列表首次渲染」「篩選或排序後的列表重繪」、§3.2「步驟表首次渲染」）；排序時 offset 歸零、篩選選取時 offset 歸零、搜尋時 offset 保留（SPEC-003 §3.4 搜尋列未定歸零，提案：保留）；列數變化由 `SplitRow.footer` 摘要文字承載播報（無障礙子節），本容器不另播報；`virtual` 捲至末端不拋 framework 錯誤（SPEC-003 §3.4 清單捲動列） | 無（SPEC-003 §3.4 明訂無動畫） | 搜尋引起的列集合更新於輸入停止 `Motion.searchDebounce` 後（SPEC-003 §3.4 搜尋列，防抖由搜尋詞 provider 承載，非 4.12 元件）；清空輸入立即還原；篩選與排序引起者隨 `onChanged` / `onSort` 瞬切（SPEC-003 §3.4 篩選 · 選取列、排序 · 循環列） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報由 4.29 `footer` 承載；不升級系統通知） | 不適用（本容器單一狀態；列集合為資料態的值變化非狀態邊） | 反應／時限：UX 審查（SPEC-003 §3.2、§3.4）；搜尋後 offset 保留：規格撰寫者（提案）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點（本容器兼具承載他人某層與自身操作路徑，須分開寫）：**為誰承載**——本容器是搜尋／篩選／排序結果通知（第三層）的顯示載體本身（列集合改變即結果通知，SPEC-003 §2.2 結果通知列：筆數與首末列改變）；初始 Ticket 載入的第二層由 4.24 `LoadingState` 承載，本容器於載入完成後才渲染（不承載等待指示，SPEC-003 §2.6、§3.4）；點擊確認（第一層）由列與欄首子件 4.35／4.14 承載。**自身互動掛在哪一層**——捲動與虛擬化捲入不屬六類回饋事件的三層模型，是本容器獨立的操作路徑（見表後〈捲動操作路徑的不變式〉），與上述三層無涉，不可混寫。服務類型：本容器承載的結果通知皆屬本地即時（搜尋、篩選、排序三者依 SPEC-003 §2.12 兩軸皆為零等待、不可能失敗）；初始 Ticket 載入的長時操作類第二層由 4.24 承載，非本容器自身的服務類型。成功：列集合依搜尋／篩選／排序更新，筆數與首末列改變；失敗：依兩軸判定不可能發生（純本地子集重排運算），故本容器無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，本地運算無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12；搜尋的防抖由 4.12 呼叫端 provider 承擔，非本容器，見 4.12 條目與 `0.1.0-W3-110`／`0.1.0-W3-126`） | — | — | 不適用（三層由 4.24 / 4.35 / 4.14 與列集合轉換承載） | 不適用 | 規格撰寫者 |

**捲動操作路徑的不變式**（非六類回饋事件，供測試點引用）：offset 隨捲動改變；`virtual` 捲至末端不拋 framework 錯誤（SPEC-003 §3.4）；視窗尺寸變更時 offset 夾在新範圍（SPEC-003 §2.8）；切換導覽項時 offset 保留、切換專案時重置（SPEC-003 §3.4 生命週期）。

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
| `rows` | `List<TableRow>`（`ticket`、`step`、`eventFlow` 或 `historyEvent`，單一變體）或 builder | 是（0..無上限） | 不適用 |
| `scrollKey` | `Key` | `appendix` 內的表不接受（不持有捲動）；其餘必填（`scroll-tickets-list` / `scroll-ucFlow-steps` / `scroll-history-events`） | 不適用 |
| `appendix` | `DataTable.plain`（`rows` 為 `eventFlow`，無 `scrollKey`，testKey `panel-ucFlow-event-flow`）；1.35 新增，只用於 UC Flow 步驟表之下的事件流小表（SPEC-001 §2〈事件流小表〉「位置：步驟表下方」） | 否（`plain` 限定，0..1；`virtual` 不接受——虛擬化列表無「最後一列之後」的固定位置） | 不適用 |

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

**用途**：domain × UC 二維格線：欄首 `TableColumnHeader.twoLine`、列首 `AppText`（可點選 domain，`action-domain-select-<domainId>`）、格 `MatrixCell`、小計 `AppText.caption`；欄首與列首釘選、二維捲動（`scroll-domain-matrix`，委派 `two_dimensional_scrollables`，`pubspec.yaml` 已宣告依賴，`0.1.0-W1-038`）。傳值 + callback，不 watch；二維捲動 offset 由頁面層持有的 `ScrollController` 傳入（§2，`0.6.0-W1-193` 裁決）。
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 格線，無高亮列 | 點格、點列首、捲動 | 建構 | 點格或點列首 → rowSelected | 資料態：Domain 視圖的選取 provider（選取列 `selectedDomainId` 與選取格 `selectedCell` 兩值，與 4.15 同一 provider）為 `null`；格線資料（`columnHeaders` / `rows`）來自該畫面的圖資料 provider——選取為 `domainViewStateProvider` 的 `DomainReady.selectedDomainId`／`selectedCell`，格線資料為 `domainMatrixProvider`（`lib/screens/domain_view/domain_view_providers.dart`）的 `columns`／`rows`；本容器不 watch：畫面層以 `ref.watch(provider.select(...))` 取得選取值與格線資料後傳入（§2 最小重繪邊界，`0.6.0-W1-193` 裁決），本容器依傳入值以 `isSelected` / `isRowSelected` 向 4.15 傳值；二維 offset 由頁面層持有的兩顆 `ScrollController`（水平、垂直）以參數傳入本容器（§2 頁面狀態保留：SPEC-003 §3.1 生命週期） | 格線資料等確認才顯示（解析完成後才進入 `state-domain-matrix`，SPEC-003 §3.1）；選取為本地即時（§2 樂觀更新政策：0.1 無樂觀操作） |
| rowSelected | 該列（列首 + 格 + 小計）底 `AppColors.surfaceIconTint` | 同上 + Esc（有選格時） | `selectedDomainId` 非 `null` | 點另一列列首 → 高亮移動（選格清除）；切換專案 → default | 資料態：同上（`selectedDomainId` 非 `null`） | 本地即時 |

選格（`MatrixCell.selected`）為格的狀態，與本容器 rowSelected 連動：選格時所在列高亮；列高亮唯一（SPEC-003 §3.1「右欄內容須與高亮列一致」）。

互動瞬態（hover / pressed / focused）：格由 4.15 承載；列首格為本容器內部互動區（slot 契約子節），其三態依 §4.0.1、來源為互動瞬態、同步策略本地即時，不另拆列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 格的六類回饋由 4.15 `MatrixCell` 承載；本表寫列首格（容器內部互動區）與列高亮的回饋。二維捲動為操作路徑，非六類回饋事件，其不變式列於表後。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 列首格 hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為列首格）；指標形狀 `SystemMouseCursors.click`；欄首（`TableColumnHeader.twoLine`）與小計無 hover（SPEC-003 §3.4 S7）；格由 4.15 承載 | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列（格由 4.15 承載） | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 依閱讀順序：欄首（不可焦點）→ 每列列首 → 該列各格（無障礙子節；SPEC-003 §2.10 `ReadingOrderTraversalPolicy`）；列首格焦點環依 §4.0.1；有選格時按 Esc 選取清除、焦點停在原格、offset 不變（SPEC-003 §2.10 矩陣已選格列，由本容器呼叫 `onClearSelection`）；列首朗讀「{domain}，`matrixSubtotalA11yLabel`」+ `selected` 旗標（無障礙子節） | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default / rowSelected →（列首 focused）→ 原狀態；rowSelected（有選格）→ Esc → rowSelected（選格清除、列高亮保留） | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 列首格 pressed 態 + Material ripple（§4.0.1）；呼叫 `onSelectDomain` 恰一次；呼叫端執行：該列高亮、已選格若在他列則清除且右欄回 `panel-domain-cell-detail-empty`、同列則選格不變（SPEC-003 §3.1「選 domain 與選格的關係」列）；點格由 4.15 承載並經 `onTap` 使本容器同步列高亮（SPEC-003 §3.1 選格列） | Material 內建 ripple；右欄 cross-fade `Motion.transition` 由 4.31 承載，本容器不播 | pressed 態出現於 `Motion.feedback` 內；列高亮於 `Motion.feedback` 內呈現（SPEC-003 §2.2、§3.1 選格列） | §1 子表「按下確認」列 | default → pressed（列首）→ rowSelected；rowSelected → pressed（另一列列首）→ rowSelected（高亮移動）；rowSelected → pressed（同列列首）→ rowSelected（無變化） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.1）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 依 §4.0.10 為二維執行端，0.1 無定位至格或列的場景：已選格捲離 viewport 時選取態與右欄皆不變、不自動捲回（SPEC-003 §3.1 矩陣捲動列；4.15 locate 列）；自泳道切回時 offset 還原、不執行 scroll-into-view（SPEC-003 §3.1 生命週期「矩陣的捲動 offset 被保留」）；矩陣 → 泳道的定位由 4.38 執行（§4.0.10 場景 b），本容器是來源；欄首與列首釘選非定位 | — | — | §1 子表「定位提示」列（二維執行端，0.1 無場景） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（畫面層於 `ref.listen` 比對選取 provider 新舊值，改傳選取值；本容器依傳入值改列高亮與向 4.15 傳值（`0.6.0-W1-193` 裁決）；含 Esc、`action-domain-cell-clear`、切換專案（選取清除，SPEC-003 §3.1 生命週期）等非列首點選引起的改變） | 列高亮（`surfaceIconTint`）的出現、移動、消失為離散替換，無入場動畫（持續性標記，同 SPEC-003 §3.1「矩陣格的選取標記出現」）；列首 `selected` 旗標改變由輔助技術播報（無障礙子節，原生旗標不另組字）；首次渲染不做逐格入場動畫（SPEC-003 §3.1 動畫提示） | 無（SPEC-003 §3.1 明訂無入場動畫；右欄 `Motion.transition` 由 4.31 承載） | `Motion.feedback`（選格或選列引起者，SPEC-003 §3.1 選格列）；清除與切換專案引起的 default 回復無時限條文（本地即時；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報適用（列首 `selected` 旗標）；不升級系統通知） | default → rowSelected（列首或格被選）/ rowSelected → rowSelected（高亮移動）/ rowSelected → default（切換專案） | 反應／時限：UX 審查（SPEC-003 §3.1）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，列首格 pressed 態）由本容器自身承載——列首格為容器內部互動區（非獨立元件），與 4.15 `MatrixCell` 的格點擊各自獨立——第二層不適用（選列／選格為本地運算無服務受理階段），第三層即結果通知本身（列高亮與右欄內容的狀態轉換，SPEC-003 §2.2 結果通知列）。載入期間由 4.24 承載，本容器於 `state-domain-matrix` 才渲染——此為渲染時機描述，非本容器承載他人第二層。服務類型：本地即時（依兩軸判定：使用者感知的等待為零，選取為本地狀態、右欄資料為本地已解析內容，SPEC-003 §3.1「不顯示任何等待指示」；失敗形態為不可能失敗，純本地選取運算，SPEC-003 §2.12）。成功：列高亮、右欄內容更新；失敗：依兩軸判定不可能發生（純本地狀態操作），故本容器無失敗態需呈現；逾時：同（不可能發生）；服務不可用：同（不可能發生，選取為本地運算無外部依賴）。輸入阻擋範圍：不阻擋（本地即時類政策，SPEC-003 §2.12）。重複觸發防護：無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.1）；通道：規格撰寫者 |

**二維捲動操作路徑的不變式**（非六類回饋事件，供測試點引用）：水平與垂直 offset 隨捲動改變；列首與欄首釘選、rect 不隨 offset 改變；已選格捲離 viewport 時選取態與右欄不變（SPEC-003 §3.1）；自泳道切回時 offset 還原（SPEC-003 §3.1 生命週期）；視窗尺寸變更以左上角為錨定保留 offset（SPEC-003 §3.1）；與 `scroll-domain-cell-detail` 不連動（SPEC-003 §1.1 連動禁令）。

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
| `rows` | `List<MatrixRow{domainName, cells: List<MatrixCell>, subtotal: int}>` | 是（1..無上限；每列 `cells` 長度 = 欄數） | 列首顯示 `domainName` 原值（`DomainBundle.domain` 字面，未知 domain 亦顯示原值；不經 i18n，同 4.38 `lanes` 的 domain 列）；同值亦為精確比對用的資料值 |
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

**用途**：泳道列（`AppText` 泳道名 + `SwimlaneNode` 置於步驟欄）× N 垂直、列間虛線；底部步驟箭頭列（裝飾）；列序、欄序、邊形狀依 SPEC-001 §1〈泳道布局規則〉（「畫面」列 + 每個 DomainBundle 一列依 `bundle_dependency` 推導層序與同層字母序、主線清單順序與分支（含巢狀）插欄、前向直線與回指弧線；0.1 為假資料靜態排版，SPEC-001 設計約束）；二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`）。列首 `AppText` 由本容器包成可點（`InkWell` + `action-domain-select-<domainId>`，同 4.37，`0.1.0-W3-335.38` S-14）。傳值 + callback，不 watch；二維捲動 offset 由頁面層持有的 `ScrollController` 傳入，本容器不自行建立 controller；§4.0.10 場景 b／f 的 `jumpTo` 定位在 controller 上移後須重新驗證（§2，`0.6.0-W1-193` 裁決）。
**內容角色**：容器。
**何時不用**：矩陣（`MatrixGrid`）。
**出現畫面**：§1（泳道）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 泳道列 + 節點 | 捲動、拖曳 | 建構（`state-domain-swimlane`；或 `state-domain-swimlane-uc-unset`、`state-domain-swimlane-projection-pending`，零個節點，`0.1.0-W3-335.47` D8、`0.5.0-W1-205.1`） | 不適用：容器無自身狀態集（選取 domain 的列高亮由 `laneHighlight` 參數呈現，非本容器狀態） | 資料態：泳道資料（`lanes`，0.1 為假資料，欄序由假資料給定）與 `laneHighlight`（等於 Domain 視圖選取 provider 的 `selectedDomainId`，與 4.37 同一 provider）——`lanes` 為 `domainSwimlaneProvider` 的 `DomainSwimlane.lanes`（零節點時改用 `domainEmptyLanesProvider`，兩者在 `lib/screens/domain_view/domain_view_providers.dart`），`laneHighlight` 為 `domainViewStateProvider` 的 `DomainReady.selectedDomainId`；本容器不 watch：畫面層以 `ref.watch(provider.select(...))` 取得 `lanes` 與 `laneHighlight` 後傳入（§2 最小重繪邊界，`0.6.0-W1-193` 裁決），本容器依傳入值以 `isActive`（該步驟 `traverses` 含 `selectedDomainId`，`0.1.0-W3-335.47` D6）向 4.16 傳值；二維 offset 由頁面層持有的兩顆 `ScrollController`（水平、垂直）以參數傳入本容器，本容器不自行建立 controller（§2 頁面狀態保留：SPEC-003 §3.1 生命週期） | 泳道資料等確認才顯示（進入 `state-domain-swimlane` 前已解析）；列高亮為本地即時（§2 樂觀更新政策：0.1 無樂觀操作） |

無互動瞬態：節點不可點、不可焦點（4.16、無障礙子節），本容器可聚焦以承載鍵盤捲動（SPEC-003 §2.10 內容區段含捲動容器），焦點環見回饋契約焦點列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器為資料視圖容器，持有 `scroll-domain-swimlane` / `drag-domain-swimlane`，是 §4.0.10 定位提示的二維執行端（0.1 場景 b：矩陣 → 泳道）。拖曳與捲動為操作路徑，非六類回饋事件，其不變式列於表後。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：無可點元素（節點不可點，SPEC-003 §1.3、4.16）；畫布可拖曳性不以指標形狀提示（Flutter 預設指標，提案：不自訂 grab 游標，桌機捲軸為等價路徑，操作機制子節）；可捲性由雙軸捲軸指示承載 | — | — | 不適用（無可互動子件；拖曳為操作機制，捲軸指示為其回饋通道） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 列首依序為停留點，其後為容器本身（可聚焦後以捲軸／滾輪捲動，無障礙子節），焦點環依 §4.0.1（提案，同 4.30；列首焦點環同 4.37）；節點不可焦點（0.1 無節點動作）；每列朗讀 `laneA11yLabel`，箭頭列排除於語意樹（無障礙子節） | 無 | 無（SPEC-003 §2.10 不設時限；提案） | §1 子表「焦點」列（列首依序為停留點，其後為容器本身，`0.1.0-W3-335.38` S-14） | 不適用（本容器單一狀態） | 反應：UX 審查（SPEC-003 §2.10）；容器焦點環：規格撰寫者（提案）；通道：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 不適用：無可點元素；對節點按下並拖曳不產生 pressed 態、節點不移動、觸發畫布平移（SPEC-003 §1.3；4.16 回饋契約） | — | — | 不適用（無可點元素；拖曳見表後不變式） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 依 §4.0.10 執行場景 b：自詳情卡 `action-domain-cell-goto-swimlane` 進入時，頁面層以已選格對應的泳道列為目標呼叫定位入口，本容器 `jumpTo` 使該列 rect 與 viewport 有交集（不用 `animateTo`，SPEC-003 §3.1 動畫提示「矩陣 → 泳道的定位」）；間接依賴格另帶目標欄（SPEC-001 §1〈間接依賴格的「在泳道中檢視」跳轉目標〉：來源 X 列欄號最小的節點，1.92 起，`0.5.0-W1-114.24`）——目標列取來源 X 的列，本容器於同一 post-frame 另做水平 `jumpTo`，使（目標列, 目標欄）節點 rect 與 viewport 有交集；直接貫穿格無目標欄、不做水平捲動；高亮由 `laneHighlight`（該列即選取 domain 的列，底 `surfaceIconTint`）承載，為持續性標記非短暫高亮，不另加 §4.0.10 的焦點綁定高亮；焦點停在本容器（提案：SPEC-003 §3.1 未定焦點落點，泳道列非停留點）；目標列不存在（選格已清除）時不捲動、不拋錯（§4.0.10 定位失敗列） | 無（`jumpTo` 瞬間） | 無（SPEC-003 §3.1 定形式不設時限；提案） | §1 子表「定位提示」列（二維執行端；高亮由 `laneHighlight` 承載） | 不適用（本容器單一狀態） | 反應：UX 審查（SPEC-003 §3.1）；焦點落點：規格撰寫者（提案）；通道：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（畫面層於 `ref.listen` 比對選取 provider 新舊值，改傳 `laneHighlight`；本容器依傳入值向 4.16 傳 `isActive`；切換專案時的 offset 重置由頁面層對其持有的 `ScrollController` 呼叫（`0.6.0-W1-193` 裁決）；含切換專案清除、切回矩陣後再切回泳道） | 列高亮的出現、移動、消失為離散替換，無入場動畫（持續性標記，同 4.37）；節點 active ↔ inactive 隨重建替換、不播報（4.16）；列高亮改變不播報（`laneA11yLabel` 不含選取旗標，提案：沿用無障礙子節「狀態變化播報不適用」） | 無 | 無（本地即時；SPEC-003 §3.1 無泳道列高亮時限條文；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報不適用（列高亮無旗標）；不升級系統通知） | 不適用（本容器單一狀態） | 反應：規格撰寫者（提案）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用於服務三層模型——本容器無可點元素（節點不可點，SPEC-003 §1.3），自身互動限於捲動與拖曳（畫布平移），已另由〈拖曳與捲動操作路徑的不變式〉（表後）承載，不落入六類回饋事件的「等待與結果」範疇；模式切換（矩陣 ↔ 泳道）由 4.10 `SegmentedControl` 觸發，非本容器自身事件，其三層歸屬見 4.10 條目；泳道定位機制依 §4.0.10，屬定位提示列非本列。服務類型：不適用——本容器無自身服務觸發行為，不落入 SPEC-003 §2.12 四類分類。成功／失敗／逾時／服務不可用：不適用（同上，無服務觸發行為，無四種結局概念）。輸入阻擋範圍：不適用——本容器無自身觸發動作，不受阻擋政策管轄。重複觸發防護：不適用——本容器無自身觸發動作，不落入重複觸發防護模型 | — | — | 不適用 | 不適用 | 規格撰寫者 |

**拖曳與捲動操作路徑的不變式**（非六類回饋事件，供測試點引用）：拖曳（`drag-domain-swimlane`）內容平移量等於位移、比例 1:1，至內容邊界生硬停止（無回彈）、無慣性，與捲軸共用同一 offset（SPEC-003 §1.3）；對節點 drag 節點不移動、觸發畫布平移（SPEC-003 §1.3）；捲動（`scroll-domain-swimlane`）offset 改變；切換導覽項時 offset 保留、切換專案時重置（SPEC-003 §3.1 生命週期）；在列首按下後位移未超過拖曳閾值時視為點擊（觸發 `action-domain-select-<domainId>`），超過閾值則視為拖曳（觸發畫布平移，`0.1.0-W3-335.38` S-14）；捲動與拖曳只平移視窗、不改變內容，`edges` 屬內容的一部分：任一條邊落在 viewport 內的部分一律可見，與其起點欄、終點欄是否在 viewport 內無關（起點欄捲出時，跨入 viewport 的邊段仍須繪製；PM 處置 2026-10-13，畫布平移不變式的直接後果，`0.5.0-W1-114.11` 修正輪回報）。

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
| 步驟欄寬 | 由假資料座標決定（SPEC-001 設計約束：欄寬靜態），不設 token |
| `kMinWindowSize` 下的行為 | 維持（二維捲動） |
| `kDesignSize` 下的行為 | 維持 |

**實作註記**：底部箭頭列（裝飾）視覺上仍固定位於所有泳道列之後，但捲動時不釘選在視窗底部——`two_dimensional_scrollables` 套件對「釘選末列 + `ScrollController.jumpTo`」組合有已知限制（釘選列與跳轉互動觸發套件內部斷言失敗，與資料規模無關），改為一般（非釘選）末列規避，屬套件版本限制的實作層面迴避，非契約值變更。

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 泳道名（`AppText.body`） | 否 | 1 | 截斷 | `TestCopy.domainName`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `lanes` | `List<Lane{key, kind: screen\|domain\|unplaced, nodes: List<(SwimlaneNode, column)>}>` | 是（列數＝DomainBundle 數＋1（「畫面」列），有未定位步驟時＋2（另加「未定位」列，置於全部 DomainBundle 列之後、為最末列），本專案為 9 列，`0.5.0-W1-114` PM 處置 N4、`0.5.0-W1-114.1` PM 處置 NC-a；依 SPEC-001 §1〈泳道布局規則〉列序；`kind: screen` 僅「畫面」列一列，`kind: unplaced` 至多一列且只在有 `traverses` 值全部未宣告或缺鍵的步驟時出現，其節點欄號依清單順序） | `domain` 列列首顯示 `key` 原值（`DomainBundle.domain` 字面，未知 domain 亦顯示原值，不經 i18n）；「畫面」列與「未定位」列經 i18n（§4.0.6 `swimlaneScreenLaneName`、`swimlaneUnplacedLaneName`） |
| `edges` | `List<Edge{fromColumn, toColumn, shape: straight\|arc}>` | 否（0.1 為空） | 不適用；`shape` 由欄號比較決定（目標 > 來源為 `straight`，否則 `arc`），繞線屬 Layout 內部演算法 |
| `laneHighlight` | `String?`（選取 domain 的 domainId，1.107 起，`0.5.0-W1-209`：以 `Lane.domainId` 精確比對，列首顯示字面不參與比對——同一 domain 字面可對應多個 bundle，以字面比對會同時高亮多列；`kind` 非 `domain` 的列 domainId 為 `null`，恆不高亮） | 否 | 不適用 |
| `locateLane` | `String?`（§4.0.10 場景 b 定位入口：值自 `null` 變為某 domainId 的那次 build，本容器於 post-frame 對該泳道列 `jumpTo`；頁面層於 `action-domain-cell-goto-swimlane` 進入時設值、切回矩陣時清為 `null`） | 否（提案） | 不適用 |
| `locateColumn` | `int?`（§4.0.10 場景 b 的目標欄，1.92 起，`0.5.0-W1-114.24`：與 `locateLane` 於同一次 build 設值；非 `null` 時本容器於 `locateLane` 的同一 post-frame 另對該欄做水平 `jumpTo`，使（`locateLane`, `locateColumn`）節點 rect 與 viewport 有交集；`null` 時不做水平捲動；`locateLane` 為 `null` 時忽略本值；清除時機同 `locateLane`） | 否 | 不適用 |
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
- [ ] 依 SPEC-001 §1〈泳道布局規則〉：渲染 9 列且列序固定（「畫面」列在頂）；「畫面」列列首不可點、不受 `laneHighlight` 高亮；`edges` 的 `arc` 與 `straight` 各渲染一條
- [ ] 捲動使某條跨欄邊的起點欄完全捲出 viewport、終點欄仍在 viewport 內時，該邊在 viewport 內的部分仍繪製（對照：捲動前同一條邊可見），見〈拖曳與捲動操作路徑的不變式〉
- [ ] 兩種視窗尺寸下不溢位；drag `Offset(dx, dy)` 後內容平移量等於位移；至邊界後再 drag 不再改變
- [ ] 泳道名最長測試文案截斷
- [ ] 資料值不溢位
- [ ] `jumpTo` 目標列 rect 與 viewport 相交
- [ ] 兩列列首顯示字面相同、domainId 不同時，`laneHighlight` 只高亮 domainId 相符的一列；E1 對照：`laneHighlight` 改為另一列的 domainId 時，高亮移至該列（1.107 起，`0.5.0-W1-209`）
- [ ] `locateColumn` 指向初始 viewport 外的欄時，定位後（`locateLane`, `locateColumn`）節點 rect 與 viewport 相交；E1 對照：同一 `locateLane`、`locateColumn` 為 `null` 時水平 offset 不變
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 自行決定列序、欄序或邊形狀 | 依 SPEC-001 §1〈泳道布局規則〉計算後傳入（本容器只渲染）；0.1 不做（SPEC-001 設計約束） |
| 把「畫面」列加進矩陣 | 禁止（SPEC-001 §1〈「畫面」列是泳道的例外，不進矩陣〉） |
| 橡皮筋回彈 | 禁止（SPEC-003 §1.3） |

### 4.39 Tree（容器，資料視圖）

**用途**：`ListRow.tree` × N 垂直，依深度縮排；展開收合改變列集合（`scroll-traceability-tree`）。傳值 + callback，不 watch（§2，`0.6.0-W1-193` 裁決）。
**內容角色**：容器。
**何時不用**：無層級的清單（`Section` / `DataTable`）。
**出現畫面**：§3、§6（來源鏈，`sourceChain` 變體）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 依深度縮排，列 leading 為 `ExpanderIcon` | 展開收合改變列集合；展開集合存於 `expandedTraceNodesProvider` | 追溯視圖（§3） |
| `sourceChain` | 依深度縮排；根列為選定的 Ticket（深度 0），其下依序 UC（1）、SPEC（2）、PROP（3）；每列 leading 一律 `ExpanderIcon.leaf`（保留寬度不渲染箭頭） | 恆全部展開，無展開器、不持有展開集合（SPEC-003 §3.6〈來源鏈〉無展開收合列）；非根列可點，根列不可點（即目前主欄節點） | 節點詳情主欄的來源鏈區塊（§6，見下方〈`sourceChain` 變體〉） |

**`sourceChain` 變體**（SPEC-001 §6〈來源鏈〉、SPEC-003 §3.6〈來源鏈〉）：

| 項目 | 規則 |
|------|------|
| 選擇理由 | 來源鏈與追溯樹同為「節點 + 深度 + 缺口列」的層級資料，差別只在根為 Ticket、方向向上；方向只影響列資料由誰計算，不影響列外觀，故沿用 `Tree` 與 `ListRow.tree`，不另立向上的列變體。不沿用 `default`：`default` 綁定追溯視圖的展開集合與其初始值規則，來源鏈則恆全部展開、與追溯視圖的展開狀態無關 |
| 承載位置 | 主欄 `Divider` 之後、`DocumentBody` 之前，外包 `Section.static`（小標 `sourceChainTitle`，testKey `panel-nodeDetail-source-chain`）；置於內文之前，使維護者不需捲過全文即可看到鏈與缺口 |
| 尺寸約束 | 寬填滿主欄；高固有，隨列數增長，不持有 `ScrollController`、不設最大高，捲動由主欄 `Panel.scrollable` 承載（規模約 1～15 列，見 SPEC-001 §6〈來源鏈〉裁決依據）；深度上限 3，縮排最多 3 × `LayoutSize.treeIndent`；列高 `LayoutSize.rowHeightDense`；`kMinWindowSize` 下列主文字單行截斷，不溢位 |
| 節點列 | `ListRow.tree`：主文字為節點 ID 與標題、trailing `Badge.status`；非根列 testKey `card-nodeDetail-chain-<nodeId>`，`onTap` 由畫面層傳入（主欄內容替換為該節點，`returnTo` 不變，同 SPEC-003 §3.6「關聯項」）；同一節點經多條路徑抵達時每個出現位置一列，同一 testKey 多實例 |
| 缺上游列 | 位於缺上游節點之下一層：`ListRow.tree`，主文字 `sourceChainNoUpstream`（`layer` 代入缺的那一層型別名）、trailing `IssueMarker.gap`（testKey `badge-nodeDetail-chain-broken-<缺上游節點 nodeId>`）；整列 `onTap` 為 null，點擊由 `IssueMarker.gap` 承載（jump 破洞報告，`returnTo` 設為 `nodeDetail`）；PROP 為頂端，不產生缺上游列 |
| 不渲染 | 選定節點不是 Ticket，或不在 `state-nodeDetail-normal`：整個 `Section.static` 不建構 |
| 資料來源 | 畫面層依最後完成輪次的圖計算來源鏈後傳入，本容器不 watch（§2）；輪次更新時依新傳入值重建 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 可見列集合（依展開集合） | 展開收合、點節點、捲動 | 建構 | 不適用：容器無自身狀態集（展開集合存於 provider） | 資料態：展開集合為 `expandedTraceNodesProvider`（`StateProvider<Set<String>>`，`lib/screens/trace/trace_providers.dart`）；節點樹為 `traceabilityStateProvider`（`StateProvider<TraceabilityScreenState>`，同檔）的正常／鏈路斷裂狀態所含資料；本容器不 watch：畫面層以 `ref.watch(provider.select(...))` 取得展開集合與節點樹後傳入（§2 最小重繪邊界，`0.6.0-W1-193` 裁決），本容器依傳入值以 `isExpanded` 向 4.18、以列資料向 4.40 傳值；offset 由頁面層持有的 `ScrollController`（4.30 `scroll-traceability-tree`）承載（§2 頁面狀態保留：SPEC-003 §3.3 生命週期） | 節點樹等確認才顯示（依已建立的圖判定，SPEC-003 §3.3 首次可見「無載入態」）；展開集合為本地即時（§2 樂觀更新政策：0.1 無樂觀操作） |

互動瞬態（hover / pressed / focused）由列（4.40 `tree`）、展開器（4.18）與缺口標記（4.6）承載，本容器不另列。

**展開集合初始值與缺口列**（1.35，SPEC-001 §3 註記、SPEC-003 §3.3 生命週期「展開集合初始值」列，用戶簽核 2026-09-14）：

| 項目 | 規則 |
|------|------|
| 初始值的計算時機 | 首次可見與切換專案後各算一次，寫入 `expandedTraceNodesProvider`；之後只由使用者展開收合改變（切至其他導覽項保留，SPEC-003 §3.3） |
| 預設 | 空集合：只顯示 PROP 層（全部 PROP 收合） |
| 含缺口的分支 | 自根 PROP 至每個缺下游父節點的路徑上，所有祖先與該父節點本身皆加入展開集合，使其下的缺口列首次渲染即可見；不含缺口的分支不加入 |
| 缺口列 | 位於缺下游父節點之下一層：`ListRow.tree`，leading 為 `ExpanderIcon.leaf`（保留寬度不渲染箭頭）、主文字 `traceabilityNoDownstream`（`layer` 代入缺的那一層型別名）、trailing `IssueMarker.gap`（testKey `badge-traceability-broken-<父節點 nodeId>`）；缺口列本身不可點（整列 `onTap` 為 null，點擊由 trailing `IssueMarker.gap` 承載），不帶 `card-traceability-*` testKey |
| 展開集合鍵 | 以節點 ID 為鍵（`Set<String>`）；多父節點下同一節點 ID 的全部出現位置共用同一筆展開狀態，展開其一即展開全部出現位置（SPEC-001 §3 註記〈多父節點〉、SPEC-003 §3.3〈互動反應〉表下段，`0.1.0-W3-335.38` S-27） |
| 由本容器計算的理由 | 缺口位置由節點樹資料決定，節點樹已由畫面層傳入本容器；由頁面層另算須再遍歷一次同一份樹（本容器只依傳入值計算，不 watch，§2，`0.6.0-W1-193` 裁決） |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器為資料視圖容器但不持有 `ScrollController`（高固有，由 4.30 `Panel.scrollable` 捲動，尺寸契約子節）；§4.0.10 場景 c 由本容器決定目標、4.30 執行捲動。列、展開器、缺口標記的 affordance／press-ack 由 4.40 / 4.18 / 4.6 承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器自身無可點元素；列 hover 由 4.40、展開器 hover 由 4.18、缺口標記 hover 由 4.6 承載 | — | — | 不適用（由 4.40 / 4.18 / 4.6 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 可見列依序：展開器 → 列本體 → 缺口標記（無障礙子節；SPEC-003 §2.10 閱讀順序）；收合節點的子層不在元件樹、不進入 Tab 順序；每列附 `treeDepthA11yLabel`（depth 代入），展開狀態由 4.18 `expanded` 旗標承載（無障礙子節）；本容器非停留點（捲動容器為 4.30） | 無 | 無（SPEC-003 §2.10 不設時限；提案） | §1 子表「焦點」列（順序由本容器的列序承載；焦點環由子件承載） | 不適用（本容器單一狀態） | 反應：UX 審查（SPEC-003 §2.10）；通道：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由子件承載：展開器 4.18（`onToggle` → 本容器經呼叫端改展開集合，子層出現或消失、offset 不歸零，SPEC-003 §3.3 展開收合列）、列 4.40 `tree`（jump 至 `nav-page-nodeDetail`、`returnTo` 設為 `traceability`，SPEC-003 §3.3 節點列）、缺口標記 4.6 `gap`（jump 至 `nav-page-gaps`、`returnTo` 設為 `traceability`，SPEC-003 §3.3 缺口層虛線框列） | Material 內建 ripple（經子件）；子層高度 `Motion.transition` 由本容器承載（見 state-change 列） | pressed 態出現於 `Motion.feedback` 內（經子件） | §1 子表「按下確認」列（由 4.18 / 4.40 / 4.6 承載） | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 依 §4.0.10 場景 c（提案，§1 子表 locate 列「樹節點展開後的子項」；4.18 locate 列路由至此）：展開後子層第一列若在 4.30 viewport 外，本容器以該列 key 為目標經頁面層呼叫 4.30 的定位入口做最小捲動（`ensureVisible` 帶 `Duration.zero`、`alignmentPolicy: keepVisibleAtEnd`），使子層第一列進入 viewport 且展開器所在列不捲離；不高亮（焦點停在展開器，SPEC-003 §3.3 未移焦點）；offset 不歸零（SPEC-003 §3.3 展開收合列）；收合不定位。跨畫面 jump 至節點詳情的定位對象是主欄節點，本容器是來源 | 無（`ensureVisible` 帶 `Duration.zero`；子層高度動畫另見 state-change 列） | 無（SPEC-003 §3.3 未設定位時限；提案） | §1 子表「定位提示」列（目標由本容器決定，捲動由 4.30 執行，不高亮） | 不適用（本容器單一狀態） | 反應：規格撰寫者（提案，§4.0.10）；通道：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（畫面層於 `ref.listen` 比對 `expandedTraceNodesProvider`、`traceabilityStateProvider` 新舊值後改傳值，本容器依傳入值重建可見列集合並播子層過渡、重建節點樹（`0.6.0-W1-193` 裁決）；含切換專案時展開集合清空、offset 歸零（SPEC-003 §3.3 生命週期）） | 子層列出現或消失的高度變化 `Motion.transition`，`disableAnimations` 時瞬間展開（SPEC-003 §3.3 動畫提示）；子層出現由 4.18 `expanded` 旗標播報（無障礙子節）；缺口虛線框靜態、不閃爍（SPEC-003 §3.3 動畫提示）；各畫面狀態之間的 cross-fade（SPEC-003 §3.3 動畫提示）由 4.28 承載 | `Motion.transition`（子層高度，本容器承載） | 無（SPEC-003 §3.3 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（本容器）；無障礙播報由 4.18 承載；不升級系統通知） | 不適用（本容器單一狀態；展開集合為資料態的值變化） | 反應：UX 審查（SPEC-003 §3.3）；通道：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用——本容器不承載三層中任一層，全部由子件承載（點擊確認：4.18 `ExpanderIcon` ／ 4.40 `ListRow.tree` ／ 4.6 `IssueMarker.gap`；結果通知：子層出現／消失即 4.18 承載的同一事件在容器層級的匯總描述，非本容器另有的獨立事件，SPEC-003 §2.2 結果通知列）；無等待指示（無載入態，SPEC-003 §3.3 首次可見；展開為本地重建，SPEC-003 §2.6「0.1 無非狀態級短暫等待」）。本容器亦無自身捲動（不持有 `ScrollController`，捲動委派 4.30 `Panel.scrollable`）。服務類型：不適用於本容器本身——本容器只協調子件的顯示與展開集合，不直接觸發服務，各子件的服務類型見其各自條目（SPEC-003 §2.12：4.18／4.40／4.6 皆為本地即時）。成功／失敗／逾時／服務不可用：皆不適用於本容器本身，由承載對應層級的子件各自呈現。輸入阻擋範圍：不適用於本容器——本容器無自身觸發動作。重複觸發防護：不適用於本容器——本容器無自身觸發動作，防護判斷在各子件 | — | — | 不適用 | 不適用 | 規格撰寫者 |

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
- [ ] 初始展開：無缺口時可見列只有 PROP 層；有缺口時每個 `badge-traceability-broken-<nodeId>` 首次渲染即存在，不含缺口的 PROP 仍收合；同層兩個父節點皆缺下游時存在兩個標記
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
**出現畫面**：§1（詳情卡步驟）、§2（UC 選擇清單）、§3（樹節點、缺口列）、§4（主題節首）、§5（分節首、破洞項）、§6（節點 meta 列）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `tree` | leading `ExpanderIcon`、主文字 `AppText.body`（PROP 層 `emphasis`）、trailing `Badge.status` 或 `IssueMarker.gap`；高 `LayoutSize.rowHeightDense` | 整列可點 → 節點詳情（`card-traceability-<nodeId>`）；缺口列（trailing `IssueMarker.gap`）整列不可點，見 4.39〈展開集合初始值與缺口列〉。於 `Tree.sourceChain` 內：leading 恆為 `ExpanderIcon.leaf`，非根列整列可點 → 主欄替換為該節點（`card-nodeDetail-chain-<nodeId>`），根列與缺上游列不可點，見 4.39〈`sourceChain` 變體〉 | 追溯樹列；節點詳情來源鏈列 |
| `sectionHeader` | leading `ExpanderIcon` 或 `Badge.category`、主文字 `AppText.body`（`emphasis`，`accentStrong`）、trailing `AppText.caption`（計數 / 摘要）；高 `rowHeightDense` | 展開由 leading `ExpanderIcon` 承載；列本體不可點 | 主題節首、破洞類別節首 |
| `item` | 主文字 `AppText.body` + 次文字 `AppText.caption`（檔案路徑；來源含行號時附行號，無行號者只顯示路徑，`0.1.0-W3-335.37` R11 修訂）堆疊；頂邊框；高固有（兩行）。項目沒有說明 key 時（例：事件類、0.1 起既有類別），路徑連同行號移到主文字，不渲染次文字，高為一行（PM 處置 2026-10-12，`0.5.0-W1-114.15`：`ListRow` 主文字必填、次文字可選的直接後果，路徑與行號維持在同一行）。trailing 依指向節點：有指向者 `AppButton.text`（leading 外開圖示 + `openSourceFileAction`，testKey `action-gaps-open-source-<itemId>`，次要操作）；無指向者 `AppIcon`（外開箭頭，`openExternallyA11yLabel`）。1.1 起，可修正的破洞項（SPEC-001 §5〈破洞報告的編輯入口〉）trailing 改為 `ButtonRow`（`alignment: end`、`wrap: false`）[`AppButton.text`（`editFieldsAction`，不帶 leading 圖示，testKey `action-gaps-edit-<itemId>`；唯讀降級時 disabled，`disabledReason` 為唯讀降級徽章文字）, 上述開啟原始檔的 `AppButton.text`]。編輯欄位不帶圖示，理由：外開圖示表示離開 App，編輯留在 App 內；且 `editFieldsAction` 在節點詳情也不帶圖示 | 整列可點（`card-gaps-<itemId>`），結果依指向節點型別（SPEC-003 §3.5 四列）：ticket → jump Ticket 清單並定位；其他圖節點 → jump 節點詳情；事件類 → 寫入選定 UC 後 jump UC Flow 並定位事件列；無指向 → 外部開啟。點 trailing 次要操作不觸發列 `onTap` | 破洞項 |
| `option` | 主文字 `AppText.body`（UC ID + 空格 + 標題，單行截斷）；無 leading／trailing；高 `rowHeightDense`；`selected` 時底 `AppColors.surfaceIconTint`、主文字 `emphasis` | 整列可點 → 寫入選定 UC（`action-ucFlow-select-uc-<ucId>`，SPEC-003 §3.2「選擇 UC」列）；點已選定者為合法操作，值不變 | UC Flow 右欄〈UC 選擇入口〉（§3.6；UC-03 步驟 1） |
| `meta` | leading `Badge.type`、主文字 `AppText.mono`（路徑）；高 `rowHeightDense` | 無 | 節點詳情 meta 列 |
| `numbered` | leading `StepNumber`、主文字 `AppText.body`；高 `rowHeightDense` | 無 | 格詳情卡步驟清單 |
| `shortcut` | leading `AppText.mono`（按鍵字面，固定寬 `LayoutSize.ticketIdColumnWidth`，不截斷：最長字面「↑／↓／Home／End」在該寬內）、主文字 `AppText.body`（作用）+ 次文字 `AppText.caption`（作用情境）堆疊；無 trailing；高固有（兩行），列間頂邊框同 `item` | 無：整列不可點、不取得焦點（SPEC-003 §3.10〈清單為靜態內容〉）；朗讀以 `shortcutRowA11yLabel` 合併為一個節點 | 鍵盤快捷鍵面板清單（SPEC-001 §11） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體 | `tree` / `item`：點選列；`sectionHeader`：展開器 | 建構 | 不適用：容器無自身狀態集 | —（建構即渲染；`leading` / `primary` / `secondary` / `trailing` 由 4.39 `Tree` / 4.41 `Section` 或頁面層依列資料傳值，本容器不 watch，§2） | 本地即時 |
| located（`item`） | 底 `AppColors.surfaceIconTint`（整列，§4.0.10 高亮 token；文字色不變） | 點選列 | `isLocated` 為 `true`（§4.0.10 場景 a：系統通知點擊／`viewGapsAction` 定位至第一個 `card-gaps-<itemId>`） | 焦點離開本列或任一指標按下 → 呼叫端改 `isLocated` 為 `false` → default（§4.0.10 高亮時長列） | 資料態：破洞報告畫面的定位狀態（`ScanNotifier.activated` 的消費者持有「被定位項 id」，SPEC-003 §2.2）——載體為頁面 `State` 或 provider 由對應畫面票補填本格（破洞報告）；頁面層持有後以 `isLocated` 傳值，本容器不 watch（§2 頁面狀態保留） | 本地即時（定位為本地事件的結果，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| selected（`option`） | 底 `surfaceIconTint`、主文字 `emphasis` | 點選列（值不變） | `isSelected` 為 `true`：該 UC 等於 App 層選定 UC（SPEC-003 §2.8〈選定 UC〉） | 選定 UC 改寫為他值或清除（切換專案）→ 呼叫端改 `isSelected` 為 `false` | 資料態：選定 UC 共用值由頁面層 watch 後以 `isSelected` 傳值，本容器不 watch（§2） | 本地即時（寫入為本地狀態操作） |
| hover（僅指標形態，`tree` / `item` / `option`） | 依 §4.0.1（整列） | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed（`tree` / `item` / `option`） | 依 §4.0.1（整列） | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused（`tree` / `item` / `option`） | 依 §4.0.1（整列） | 點選（Space / Enter） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

`sectionHeader` / `meta` / `numbered` 變體的列本體無互動瞬態；`sectionHeader` 的展開器瞬態由 4.18 承載。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。只適用 `option` 變體；`tree`／`item` 點選為導覽或外部開啟，第 1 問判為動作；`sectionHeader`／`meta`／`numbered` 列本體非互動。以上皆填不適用。`option` 有兩個使用處，第 3、4 問的答案不同，分欄填寫。

| # | 問句 | UC Flow〈UC 選擇入口〉（§3.6） | 偏好設定面板的編輯器選項（SPEC-001 §9） |
|---|------|------|------|
| 1 | 設定或動作 | 設定——寫入選定 UC，不執行命令、不開視窗 | 設定——寫入編輯器偏好，不執行命令、不開視窗 |
| 2 | 套用時點 | (a)–(e) 皆不成立：單一值；本地狀態操作；可換選 → 立即提交 | (a)–(e) 皆不成立：單一值；不需預覽或比較；可再選回 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——選項清單常駐於右欄 | 是——面板只有編輯器一項單選 → 選取即關閉面板。面板日後加入其他設定時改答否：面板保持開啟、選項旁顯示「已儲存」、關閉鈕叫「完成」 |
| 4 | 生效是否當下可見 | 有——轉入 `state-ucFlow-normal` 或 `state-ucFlow-unstructured`，右欄顯示該 UC 的步驟，回饋契約關卡二第 2 問答是 | 沒有——效果要到下次開啟原始檔時才出現，畫面上只有選取標示改變，關卡二第 2 問答否。關閉面板時以暫態提示告知「已改用 X，下次開啟原始檔時生效」，載體由 SPEC-003 §3.8 依 §2.13 判定（用戶裁決 2026-11-09，出處 `0.7.0-W1-008`） |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 六列皆只適用 `tree` / `item` / `option` 變體（整列可點；`option` 除 press-ack 與等待與結果兩列另述外，同 `tree`：本地即時、無定位場景，其 selected 的出現／消失為離散替換、由 `Semantics.selected` 旗標播報）；1.35 起 `item` 的點擊結果依指向節點型別分流，下表 press-ack 與等待與結果兩列中「`item` → 外部開啟」的描述只適用無指向節點的破洞項，有指向者為本地即時 jump（同 `tree`），其外部開啟改由 trailing `AppButton.text` 承載（回饋契約見 4.4，結果三值同本表原述）；`option` press-ack：呼叫 `onTap` 恰一次，呼叫端寫入選定 UC 並依 SPEC-003 §3.2 轉入 `state-ucFlow-normal` 或 `state-ucFlow-unstructured`，換選時 `scroll-ucFlow-steps` offset 歸零；`sectionHeader` / `meta` / `numbered` 的列本體非互動，其 leading / trailing 子件（4.18 / 4.6 / 4.5 / 4.17）各自承載回饋且不觸發列點擊。`item` 變體是 §4.0.10 場景 a 的被定位目標。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 整列 hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為整列、圓角 `Radius.sm`）；指標形狀 `SystemMouseCursors.click`；`sectionHeader` / `meta` / `numbered` 列本體無 hover | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文；提案） | §1 子表「可互動提示」列（非互動變體不適用） | 不適用 | 反應：規格撰寫者（抄 §4.0.1 提案列）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 整列焦點環（§4.0.1 focused）；Tab 順序：leading 可點子件 → 列本體 → trailing 可點子件（無障礙子節；SPEC-003 §2.10）；朗讀 `Semantics.button` label（主文字 + 次文字 + trailing 文字，`item` 含 `openExternallyA11yLabel`；`tree` 另附 4.39 `treeDepthA11yLabel`）；located 列的焦點由 §4.0.10 定位事件移入，焦點離開即退出 located | 無 | 無（SPEC-003 §2.10 只斷言焦點兩態裝飾可區分，不設時限；提案） | §1 子表「焦點」列 | default → focused → default；located → focused（定位時同時進入）→（焦點離開）→ default | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 整列 pressed 態 + Material ripple（§4.0.1）；呼叫 `onTap` 恰一次；呼叫端執行：`tree` → jump 至 `nav-page-nodeDetail`、`returnTo` 設為 `traceability`（SPEC-003 §3.3 節點列）；`item` 依指向節點型別分流（SPEC-003 §3.5 四列）：ticket → jump `nav-page-tickets`、`returnTo` 設為 `gaps`；其他圖節點 → jump `nav-page-nodeDetail`、`returnTo` 設為 `gaps`；事件類 → 寫入選定 UC 後 jump `nav-page-ucFlow`、`returnTo` 設為 `gaps` 並定位事件列；無指向 → `ExternalOpener.open(path)` 以系統預設方式開啟原始檔、0.1 不定位至行號，結果 `opened` → SnackBar `openedExternallyMessage`、`notFound` → `AppSnackBar.withAction`（`rescanAction`）、`failed` → SnackBar `externalOpenFailedMessage`，畫面狀態不變（SPEC-003 §2.2 外部開啟契約）；點 leading 展開器或 trailing 標記不觸發列 `onTap`（測試點子節） | Material 內建 ripple；`item` 無指向分支的 SnackBar 進出為 Material 預設（4.26） | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1）；`item` 無指向分支的外部開啟期間不顯示等待指示，SnackBar 於結果返回後出現（SPEC-003 §2.2 外部開啟契約） | §1 子表「按下確認」列 | default / located → pressed → default（`item` 點選同時結束 located：指標按下即退出，§4.0.10；本列狀態不因外部開啟或 jump 改變） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.3、§3.5）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | `item`：本列為 §4.0.10 場景 a 的被定位目標——捲動由 4.30 `Panel.scrollable`（`scroll-gaps-sections`）執行，本列只依 `isLocated` 渲染整列底 `surfaceIconTint`（§4.0.10 高亮 token）並接受焦點移入（SPEC-003 §2.2「點擊通知的導向」列）；高亮至焦點離開或任一指標按下為止（§4.0.10 高亮時長列，機制非數值）；`tree`：0.1 無定位至樹列的場景（展開後子項的定位不高亮，§4.0.10 場景 c；跨畫面 jump 本列是來源）；其餘變體不適用 | 無（高亮離散出現，§4.0.10） | 無（§4.0.10 高亮時長為焦點機制非數值；提案） | §1 子表「定位提示」列（被定位目標：高亮由本列渲染，捲動由 4.30 執行；`tree` 與其餘變體不適用） | default → located（定位事件）/ located → default（焦點離開、指標按下） | 反應：規格撰寫者（提案，§4.0.10；SPEC-003 §2.2 定目標與焦點落點）；通道／狀態邊：規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：4.39 / 4.41 或頁面層依列資料重建本列；`item` 的 `isLocated` 由頁面層依定位事件與焦點／指標事件改傳值） | located 底色的出現／消失為離散替換、無入場動畫（§4.0.10）；本列其餘無語意狀態，格內容隨重建替換；`sectionHeader` trailing 計數改變隨重建唸出（`Semantics.header`，無障礙子節）；缺口標記靜態（SPEC-003 §3.3） | 無 | 無（本地即時；SPEC-003 無列級時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡不適用；無障礙播報：located 不播報（§4.0.10），其餘由子件承載；不升級系統通知） | default ↔ located（`item`，見 locate 列） | 反應：規格撰寫者（提案，§4.0.10）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層，整列 pressed 態）由本列自身承載，適用 `tree`／`item` 兩個可點變體；`sectionHeader`／`meta`／`numbered` 三變體列本體無互動，全數委派 leading／trailing 子件（4.18／4.6／4.5／4.17）——第二層與第三層依變體而定：`tree` 第二層不適用、第三層即 `IndexedStack` 可見頁更換的結果通知；`item` 第二層不適用（外部開啟不顯示等待指示）、第三層委派 4.26 `AppSnackBar`（狀態不變的動作用 SnackBar）。服務類型：依變體而定——`tree` 為本地即時（依兩軸：零等待、不可能失敗，jump 無載入）；`item` 為短暫非同步（依兩軸：亞秒等待、可能失敗，SPEC-003 §2.12 0.1 實例逐字命中「外部開啟」，實測 600 ms 內）；`sectionHeader`／`meta`／`numbered` 不適用（列本體無互動）。成功：`tree` 為可見頁更換；`item` 為 `opened` → `AppSnackBar`（`openedExternallyMessage`）；失敗：`tree` 依兩軸判定不可能發生；`item` 為 `failed` → `AppSnackBar`（`externalOpenFailedMessage`）；逾時：`tree` 同不可能發生；`item` 短暫非同步類無獨立逾時概念（600 ms 內必有結果）；服務不可用：`tree` 同不可能發生；`item` 為 `notFound` → `AppSnackBar.withAction`（`rescanAction`）。輸入阻擋範圍：不阻擋（`tree` 本地即時類政策；`item` 短暫非同步類政策，皆為不阻擋，SPEC-003 §2.12）。重複觸發防護：`tree` 無需（本地狀態操作天然冪等）；`item` 冪等（重複開啟同一檔案為合法操作，短暫非同步類政策，SPEC-003 §2.12） | Material 內建 | `Motion.feedback`；`item` 的 SnackBar 停留 `Motion.snackBar` / `Motion.snackBarWithAction`（由 4.26 承載） | §1 子表「等待與結果」列（`item` 結果通知＝SnackBar） | 不適用 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.12、§3.3、§3.5）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | `tree` / `item`：依 §4.0.7 點選列；`sectionHeader` / `meta` / `numbered`：不適用（列本體無互動，互動在 leading / trailing 子件） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 填滿父容器（寬）；高固定（`rowHeightDense`）或固有（`item` 兩行 + 2 × `Space.sm`） |
| 最小尺寸 | 寬：leading 寬 + `Space.sm` + 一字元 + 省略號（一字元見 §4.0.3，取 `primary` slot 的 `AppFontSize.body`；`body` 與 `mono` 同字級）+ `Space.sm` + trailing 寬；高：`LayoutSize.rowHeightDense`（≥ `LayoutSize.hitTargetMin`） |
| 最小命中區 | `tree` / `item`：整列高 |
| 最大尺寸 | 寬無上限；高：`item` 兩行 |
| `kMinWindowSize` 下的行為 | 維持（主文字截斷，兩端固定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot（截斷責任歸呼叫端：主文字／次文字的行數政策由呼叫端建構 `AppText` 時以 `AppText.singleLine`（單行省略號）或 `AppText.multiLine`（`maxLines` 必填）明示，本容器重染主文字時經 `copyWithModifiers` 原樣保留，不代為決定截斷或換行；主文字 / 次文字 / trailing 依 `AppText` 各變體契約：主文字 `TestCopy.nodeTitle` / `TestCopy.topicName` / `TestCopy.gapTitle`、次文字 `TestCopy.gapDescription`、trailing `topicSectionSummary` / `gapSectionCount`） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `leading` | `ExpanderIcon` \| `AppIcon` \| `Badge` \| `StepNumber` | 依變體（`tree` / `sectionHeader` / `meta` / `numbered` 必填） | 不適用 |
| `primary` | `AppText`（`body` / `mono`） | 是（恰 1，填滿） | 文字由呼叫端 |
| `secondary` | `AppText.caption` | `item` 必填，其餘不接受 | 文字由呼叫端（`item`：檔案路徑，來源含行號時附行號，`0.1.0-W3-335.37` R11 修訂；追修票核對組字 i18n key 是否以行號為必填佔位） |
| `trailing` | `Badge` \| `AppIcon` \| `AppText.caption` \| `IssueMarker` \| `AppButton.text`（限 `item` 有指向節點者）\| `ButtonRow`（限 `item` 可修正的破洞項，恰兩個 `AppButton.text`：編輯欄位、開啟原始檔，1.1 起） | 否（恰 0..1；`option` 不接受） | 文字由呼叫端 |
| `onTap` | `VoidCallback?`（`tree` / `item` / `option`） | 該三變體必填，唯 `tree` 缺口列為 null | 不適用 |
| `testKey` | `Key`（`card-traceability-<nodeId>` / `card-nodeDetail-chain-<nodeId>` / `card-gaps-<itemId>` / `action-ucFlow-select-uc-<ucId>`） | 該三變體必填，唯 `tree` 缺口列、缺上游列與來源鏈根列不帶 | 不適用 |
| `isSelected` | `bool`（`option`，預設 `false`） | 否（其餘變體不接受） | 不適用 |
| `isLocated` | `bool`（`item`；§4.0.10 場景 a 的高亮傳值，預設 `false`） | 否（其餘變體不接受） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`（`item` 頂邊）、`accentStrong`（`sectionHeader` 主文字）、`surfaceIconTint`（`item` located 底，§4.0.10；`option` selected 底） |
| 間距 | 子件最小間距 `Space.sm`；`item` 主次文字間 `Space.xxs`、垂直內距 `Space.sm` |
| 字體 | 經 `AppText` |
| 圓角 | `Radius.sm`（hover / 焦點區） |
| 動畫 | `Motion.feedback` |
| 尺寸 | `LayoutSize.rowHeightDense` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `item` trailing 朗讀 | 無指向：`openExternallyA11yLabel`；有指向：`openSourceFileAction`（既有，按鈕可見文字即朗讀）；可修正的破洞項（1.1 起）：`editFieldsAction`、`openSourceFileAction` 各為一個按鈕節點，Tab 順序依序為列本體、編輯欄位、開啟原始檔 |
| `tree` 缺口列主文字 | `traceabilityNoDownstream`（呼叫端傳入） |
| `tree` 缺上游列主文字（`Tree.sourceChain`） | `sourceChainNoUpstream`（呼叫端傳入） |
| `sectionHeader` trailing | `topicSectionSummary` / `gapSectionCount`（呼叫端傳入） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Tree`（`tree`）、`Section`（`sectionHeader` 節首、`item` 項目、`option` 項目——限 `Section.static`）、`Panel` / `Panel.scrollable`（`meta`、`numbered`） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 子件垂直置中；`item` 以上緣（次文字換行時） |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `tree` / `item` / `option`：`Semantics.button`，label 為主文字 + 次文字 + trailing 文字（`item` 有指向者 trailing 為獨立按鈕，不併入列 label）；`option` 另帶 `Semantics.selected`；`tree` 缺口列：非按鈕，label 為主文字，缺口標記自身為按鈕；`sectionHeader`：`Semantics.header`；`meta` / `numbered`：依序唸出子件 |
| 狀態變化播報 | 展開由 4.18 承載；`option` 的 selected 改變由 `Semantics.selected` 旗標播報 |
| 非視覺替代訊號 | 由子件承載 |
| 焦點順序與操作路徑（桌機） | leading 可點子件 → 列本體（可點變體）→ trailing 可點子件 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染全部變體 × leading / trailing 有無（`item` 含有指向（trailing `AppButton.text`）、可修正破洞項（trailing `ButtonRow`，`wrap: false`，1.150）與無指向（trailing `AppIcon`）三形態；`option` 含 selected / 非 selected；`tree` 含缺口列）
- [ ] 兩種視窗尺寸下不溢位；主文字截斷、兩端子件寬不變
- [ ] 可修正破洞項（1.150）：以 en 最長文案（`Edit fields`、`Open Source File`）在列寬 439 渲染，兩鈕同列、互不相交、label 不截斷，列高等於只有一顆 trailing 按鈕時的列高；列寬 724（`kMinWindowSize` 下的破洞報告列寬）時同樣成立
- [ ] 無自有文字（本項不適用）；子件以最長測試文案渲染
- [ ] `tree` / `item` / `option` 列點選呼叫 `onTap` 恰一次；點 leading 展開器、`item` trailing 次要操作按鈕（含可修正破洞項的兩鈕）、缺口列 trailing `IssueMarker.gap` 皆不觸發列 `onTap`
- [ ] 可修正破洞項的 Tab 順序為列本體 → 編輯欄位 → 開啟原始檔；唯讀降級時編輯欄位 disabled，不進 Tab 順序
- [ ] `option` 以 `isSelected: true` 渲染時整列底色等於 `surfaceIconTint` 且 `Semantics.selected` 為 `true`
- [ ] `item` 以 `isLocated: true` 渲染時整列底色等於 `AppColors.surfaceIconTint`，`false` 時無底色（§4.0.10）
- [ ] 子件兩兩邊界盒不相交
- [ ] 尺寸與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 票列（欄對齊） | `TableRow.ticket` |
| 浮層專案項 | `RecentProjectItem` |

### 4.41 Section（容器）

**用途**：節首 + 項目垂直堆疊：主題節（`ListRow.sectionHeader` + `TableRow.ticket` × N）、破洞類別節（`ListRow.sectionHeader` + `ListRow.item` × N）、關聯群（`AppText.caption` + `RelationItem` × N）、schema 詳情面板（`AppText.caption` + `AppText.mono`）。
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

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| expanded | 節首 + 項目 | 收合（`collapsible`） | 預設 | 點展開器 → collapsed | 資料態（`collapsible`）：受控 `isExpanded`——破洞類別節為頁面 `State`（`_isExpanded`，`lib/screens/gap_report/gap_report_screen.dart`；§2 頁面狀態保留允許的第二種載體，非 provider，與 4.18 同一來源）；Ticket 清單主題節為 `ticketListStateProvider` 的 `TicketsReady.expandedTopics`，與 4.18 同一來源；頁面層持有後以 `isExpanded` 傳值、`items` 依資料傳值，本容器不 watch（§2）。`static`：—（恆展開，建構即渲染） | 本地即時（展開為本地畫面狀態，項目資料已載入，無資料層確認；§2 樂觀更新政策：0.1 無樂觀操作） |
| collapsed（`collapsible`） | 只有節首 | 展開 | 點展開器 | 點展開器 → expanded | 資料態：同上（`isExpanded` 為 `false`） | 本地即時 |

互動瞬態（hover / pressed / focused）由節首展開器（4.18）與項目（4.35 `ticket` / 4.40 `item` / 4.19）承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器不持有 `ScrollController`（由 4.30 `Panel.scrollable` 捲動）；§4.0.10 場景 a 的被定位目標位於本容器的項目內，本容器不參與捲動與高亮，只保證目標存在（展開時項目在元件樹）。展開器與項目的 affordance／press-ack 由 4.18 與各項目條目承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 不適用：容器自身無可點元素；節首展開器 hover 由 4.18、項目 hover 由 4.35 / 4.40 / 4.19 承載；`static` 節首（`AppText.caption`）無 hover | — | — | 不適用（由 4.18 與項目條目承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 節首展開器 → 項目依序（無障礙子節；SPEC-003 §2.10 閱讀順序）；collapsed 時項目不在元件樹、不進入 Tab 順序；節首為 `Semantics.header`（無障礙子節）；本容器非停留點 | 無 | 無（SPEC-003 §2.10 不設時限；提案） | §1 子表「焦點」列（順序由本容器的堆疊承載；焦點環由子件承載） | 不適用（focus 不改變 expanded / collapsed） | 反應：UX 審查（SPEC-003 §2.10）；通道：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由子件承載：展開器 4.18（`onToggle` → 呼叫端改 `isExpanded`，項目出現或消失、`scroll-tickets-topics` / `scroll-gaps-sections` offset 不歸零，SPEC-003 §3.4 主題節展開收合列、§3.5 分節收合列）；項目點選由 4.35 `ticket`（開票）/ 4.40 `item`（外部開啟）/ 4.19（關聯跳轉）承載 | Material 內建 ripple（經子件）；高度變化 `Motion.transition` 由本容器承載（見 state-change 列） | pressed 態出現於 `Motion.feedback` 內（經子件） | §1 子表「按下確認」列（由 4.18 與項目條目承載） | expanded → pressed（展開器）→ collapsed / collapsed → pressed → expanded（推進由呼叫端決定） | 反應／時限：UX 審查（SPEC-003 §2.2、§3.4、§3.5）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 依 §4.0.10 場景 a，本容器為目標所在分節：第一個分節（破洞類別節，預設 expanded）內第一個 `card-gaps-<itemId>`（4.40 `item`）為被定位目標，捲動由 4.30 執行、高亮由 4.40 渲染，本容器不參與；目標所在分節 collapsed 時定位不執行、不自動展開（§4.0.10 定位失敗列）；主題節（Ticket 清單）與 `static` 節 0.1 無定位場景；4.18 locate 列「展開後子項」的定位在本容器內不執行（分節項目為平面清單，展開後由使用者捲動，提案：只有樹（4.39）做場景 c） | — | — | §1 子表「定位提示」列（目標所在分節；捲動與高亮由 4.30 / 4.40 承載） | 不適用（定位不改變 expanded / collapsed） | 規格撰寫者（提案，§4.0.10） |
| 狀態變更提示 state-change | 呼叫端（§2 過渡提示觸發點：頁面層依展開狀態改 `isExpanded` 傳值、依資料改 `items`；含切換專案時主題節重置（SPEC-003 §3.4 生命週期）） | expanded ↔ collapsed：項目出現或消失的高度變化 `Motion.transition`，`disableAnimations` 時瞬間（SPEC-003 §3.4 動畫提示「列表 ↔ 主題」之外的分節高度、§3.5 動畫提示「分節收合」）；展開由 4.18 `expanded` 旗標播報（無障礙子節）；「未歸屬」由節首文字承載，虛線非唯一訊號（無障礙子節） | `Motion.transition`（高度，本容器承載） | 無（SPEC-003 §3.4、§3.5 動畫提示只定形式不設時限；提案） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（本容器）；無障礙播報由 4.18 承載；不升級系統通知） | expanded → collapsed / collapsed → expanded | 反應：UX 審查（SPEC-003 §3.4、§3.5）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：不適用——本容器不承載三層中任一層，全部由子件承載（點擊確認：展開器 4.18 與項目條目 4.35／4.40／4.19；結果通知：項目出現／消失的狀態轉換本身，SPEC-003 §2.2 結果通知列）；無等待指示（項目資料已載入，展開為本地重建，SPEC-003 §2.6「0.1 無非狀態級短暫等待」）。本容器亦無自身捲動（不持有 `ScrollController`，捲動委派 4.30 `Panel.scrollable`）。服務類型：不適用於本容器本身——本容器只協調展開集合與項目顯示，不直接觸發服務，各子件的服務類型見其各自條目（SPEC-003 §2.12）。成功／失敗／逾時／服務不可用：皆不適用於本容器本身，由承載對應層級的子件各自呈現。輸入阻擋範圍：不適用於本容器——本容器無自身觸發動作。重複觸發防護：不適用於本容器——本容器無自身觸發動作，防護判斷在各子件 | — | — | 不適用 | 不適用 | 規格撰寫者 |

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
| 不適用 | 無自有文字 slot（`static` 節首為 `AppText.caption`，文案如關聯群名 `implements`、`schemaKnownRangeLabel`） | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `header` | `ListRow.sectionHeader`（`collapsible`）\| `AppText.caption`（`static`） | 是（恰 1） | 文字由呼叫端 |
| `items` | `List<TableRow.ticket>` \| `List<ListRow.item>` \| `List<ListRow.option>`（限 `static`，UC 選擇清單）\| `List<RelationItem>` \| `List<AppText>`（單一型別） | 是（0..無上限；0 時只渲染節首） | 不適用 |
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

**用途**：專案切換覆蓋層：`AppText.caption` 標題 + `RecentProjectItem` × N（垂直捲動 `scroll-switcher-recent`）+ `Divider` + `AppButton.text`（選擇其他資料夾）；自入口向下展開，Esc / 點外部收合，焦點限制於浮層內。「選擇其他」選資料夾失敗時，按鈕下方相鄰處另有一則常駐原因文字（`chooseOtherFailureReason`，SPEC-003 §3.7〈浮層內選資料夾失敗的常駐原因文字〉，1.88）。
**內容角色**：容器（另有標題 slot）。
**何時不用**：任何其他覆蓋表面（0.1 唯一 overlay，§1 覆蓋表面對映）。
**出現畫面**：§7（展開、無最近專案）。
**層級**：L3

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；零項時只渲染標題 + `AppButton.text`（`state-switcher-no-recent`，訊息 `switcherChooseFolderPrompt` 作為按鈕 label） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| expanded（`state-switcher-expanded`） | 標題 + 專案項 + 分隔線 + 選擇其他；`chooseOtherFailureReason` 非 `null` 時另於選擇其他下方顯示失敗原因文字（不構成另一個狀態，1.88） | 選專案、選資料夾、Esc、點外部、捲動 | `project-switcher-entry` 或阻擋狀態出口 | 選取 → 收合並重載；Esc / 點外部 → 收合（SPEC-001 §7）；系統通知點擊（視同點外部，見 4.27 locate 列）→ 收合 | 資料態：`switcherOpenProvider`（`StateProvider<bool>`，`lib/app/project_switcher_providers.dart`）為 `true` 且 `recentProjectsProvider`（`Provider<List<RecentProjectFixture>>`，同檔）非空；`AppShell` watch 後渲染本容器並以 `items` 傳值，本容器不 watch（§2）；清單 offset 為本容器內部 `ScrollController`，收合即釋放（SPEC-003 §3.7 捲動列：收合後不保留） | 本地即時（浮層開合為本地 UI 狀態；專案項的 `enabled` 為探測結果，等確認才顯示，見 4.9；§2 樂觀更新政策：0.1 無樂觀操作） |
| noRecent（`state-switcher-no-recent`） | 標題 + 選擇其他；失敗原因文字同 expanded 列（1.88） | 選資料夾、Esc、點外部（`0.1.0-W3-335.47` D14） | 首次使用（無最近專案） | 選取 → 收合並載入；Esc／點外部 → 收合（`0.1.0-W3-335.47` D14）；系統通知點擊（視同點外部，見 4.27 locate 列）→ 收合 | 資料態：`switcherOpenProvider` 為 `true` 且 `recentProjectsProvider` 為空（同上） | 本地即時 |

收合態不是本容器的狀態（本容器不存在），由 `ProjectSwitcherEntry` 承載。展開／收合的過渡（淡入 + 向下展開及其反向）為本容器自身的出場／退場動畫，由 `AppShell` 渲染或移除本容器時觸發，屬 §2 呼叫端觸發，不構成本容器的第三個狀態。

互動瞬態（hover / pressed / focused）由子件（4.9 `RecentProjectItem`、4.4 `AppButton.text`）承載，本容器不另列。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。
> 「時間門檻」填「無」者為 SPEC-003 無時限條文且機制為本地即時，不另設數值（提案，填寫者欄標明）。
> 本容器為 0.1 唯一覆蓋層（§1 覆蓋表面對映）；專案項與按鈕的 affordance／press-ack 由 4.9 / 4.4 承載，本表寫浮層層級的焦點限制、點外部、展開收合過渡。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由子件承載：專案項 hover 4.9、選擇其他 hover 4.4 `text`；標題、分隔線、健康徽章無 hover（SPEC-003 §3.7 健康徽章列：非互動元素、不呈按鈕形態）；浮層外部無 hover | 無（Material 內建，經子件） | 無（同 4.9 / 4.4） | §1 子表「可互動提示」列（由 4.9 / 4.4 承載） | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 展開時焦點移入浮層首個可聚焦項（專案項或選擇其他）並唸出 `switcherTitle`（`Semantics(scopesRoute: true)`，無障礙子節）；焦點限制於浮層（`FocusScope` + `FocusTraversalGroup`）、Tab 依序項目 × N → 選擇其他、不離開浮層（SPEC-003 §2.10「浮層展開時」列）；收合時焦點回到 `project-switcher-entry`，三條收合路徑皆同——Esc（SPEC-003 §2.10、§3.7 按 Esc 列）、點浮層外部（§3.7 點浮層外部列）、系統通知點擊（視同點外部，見 4.27 locate 列；該路徑下焦點交回入口後再由定位段移入被定位項，最終落點為被定位項）；各停留點焦點環由 4.9 / 4.4 依 §4.0.1 承載 | 無 | 無（SPEC-003 §2.10 只斷言限制與落點，不設時限；提案） | §1 子表「焦點」列（焦點限制與三條收合路徑的焦點歸位由本容器承載；焦點環由子件承載） | expanded / noRecent → Esc／點外部／通知點擊 →（本容器消失，入口回 collapsed，4.8；焦點回入口，通知點擊路徑再移入被定位項） | 反應：UX 審查（SPEC-003 §2.10、§3.7）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | 專案項經 4.9（pressed + ripple，`onTap` 恰一次）→ 呼叫端先收合浮層再由 Domain 視圖轉入 `state-domain-loading`，兩段不重疊（SPEC-003 §3.7 動畫提示「選取專案後的重載」、§2.8 L2 全部導覽頁重置）；選擇其他經 4.4 `text`（`action-switcher-choose-folder`）→ 開啟系統資料夾選擇器，選定後收合並載入、取消則維持展開（SPEC-003 §3.7）；選擇器無法開啟、或選定資料夾不可讀或不存在時維持展開，呼叫端傳入 `chooseOtherFailureReason`，按鈕下方出現常駐原因文字，不顯示 SnackBar；專案項點選後判定不可讀或不存在時維持展開，該項轉 disabled 並於同列顯示原因（4.9），不顯示 SnackBar；已有失敗原因文字時再次點選選擇其他或任一可用的專案項，呼叫端於點選當下將 `chooseOtherFailureReason` 傳回 `null`（SPEC-003 §3.7 該表清除時機兩列）（SPEC-003 §3.7〈浮層內選資料夾失敗的常駐原因文字〉，1.88）；點浮層外部 → 呼叫 `onDismiss` 恰一次，收合、不改變當前專案、無 pressed 態（barrier 非按鈕；SPEC-003 §3.7 點浮層外部列）；展開期間點擊背景任一處（含導覽項）同被吸收：浮層收合、不切頁（同 SPEC-003 §3.4 F7，`0.1.0-W3-335.47` D13；SPEC-003 §3.7 生命週期） | Material 內建 ripple（經子件）；收合 `Motion.overlay`（本容器承載） | pressed 態出現於 `Motion.feedback` 內（經子件）；收合於 `Motion.overlay` 內（SPEC-003 §3.7 動畫提示） | §1 子表「按下確認」列（由 4.9 / 4.4 承載；點外部由本容器 barrier 承載） | expanded → pressed（專案項）→ 收合並重載；expanded / noRecent → pressed（選擇其他）→ 收合並載入或維持原狀態；expanded → 點外部 → 收合 | 反應／時限：UX 審查（SPEC-003 §2.2、§2.8、§3.7）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 不適用（無承載場景）：本容器為覆蓋層，每次展開自頂端、offset 不保留（SPEC-003 §3.7 捲動列），無定位至專案項的場景；目前專案項以 `selected` 態（4.9）標示，非定位；本容器不是被定位目標（§1 子表 locate 列適用場景皆在導覽頁內） | — | — | 不適用（覆蓋層無定位場景） | expanded／noRecent → 消失（通知點擊視同點外部，見 4.27 locate 列） | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（組裝層 `lib/assembly/shell.dart` 的 `AppShell` 以 `ref.watch` 讀取後傳值，依 `switcherOpenProvider` 渲染／移除本容器，依 `recentProjectsProvider` 傳 `items`；含 Esc、點外部、選取專案、選擇資料夾後的收合） | 展開：淡入 + 自入口向下展開；收合：反向（SPEC-003 §3.7 動畫提示）；`disableAnimations` 下依 §2.1 歸零；展開時焦點移入並唸出標題、收合時焦點回入口（無障礙子節）；expanded ↔ noRecent 不在同一次展開內切換（`items` 於展開時已定）；專案項 `enabled` 隨探測結果更新由 4.9 承載（SPEC-003 §3.7 探測逾時）；`chooseOtherFailureReason` 由 `null` 轉為非 `null` 時失敗原因文字瞬切出現、無過渡動畫，並播報一次（無障礙子節；1.88，提案） | `Motion.overlay`（展開與收合，本容器承載） | 浮層出現／收合於 `Motion.overlay` 內（SPEC-003 §3.7 動畫提示） | §1 子表「狀態變更提示」列（`Motion.*` 過渡適用（本容器）；無障礙播報適用（`scopesRoute` 唸出標題）；不升級系統通知） | （不存在）→ expanded / noRecent（入口或阻擋狀態出口）/ expanded / noRecent →（不存在）（Esc、點外部、選取、選定資料夾） | 反應／時限：UX 審查（SPEC-003 §2.1、§3.7）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（互動元件層）由子件 4.9／4.4 承載；點外部的 barrier dismiss（`onDismiss`）為本容器自身的第一層（無 pressed 態，barrier 非按鈕）——第二層與第三層依觸發動作而定：浮層自身開合的第三層即結果通知本身（收合的狀態轉換）；選取專案後的重載委派 4.24（`state-domain-loading`）；選擇資料夾為系統 UI，無等待指示。服務類型：浮層自身開合為本地即時（依兩軸：使用者感知的等待為零、不可能失敗，清單為本地 fixture／已探測結果，探測逾時期間浮層仍可操作、其餘項不受影響，SPEC-003 §3.7）；選取專案後的重載為長時操作，委派 4.24（見 4.9 條目）；第一層本身不隨後續服務類型變動。成功：浮層出現／收合；選取專案後 4.24 完成載入的目標態；失敗：浮層開合依兩軸判定不可能發生（純本地狀態操作）；選取專案的失敗由 4.24 依長時操作類政策呈現，本容器不重述；選資料夾與開啟最近專案項於載入開始之前即判定失敗者（選擇器無法開啟、資料夾不可讀或不存在）不進入 4.24，其第三層為浮層內常駐文字（「選擇其他」為本容器的 `chooseOtherFailureReason`，專案項為 4.9 的 `reason`），不使用 4.26 `AppSnackBar`（SPEC-003 §3.7、§2.13 對照表列 17、18，1.88）；逾時：浮層開合同不可能發生；選取專案同由 4.24 承載；服務不可用：浮層開合同不可能發生；選取專案同由 4.24 承載。輸入阻擋範圍：浮層開合不阻擋（本地即時類政策）；展開期間點擊背景任一處（含導覽項）被吸收（浮層收合、不切頁，`0.1.0-W3-335.47` D13）屬焦點限制機制（`FocusScope`），非服務類阻擋（SPEC-003 §3.7 生命週期）。重複觸發防護：浮層開合無需——本地狀態操作天然冪等（本地即時類政策，SPEC-003 §2.12） | `Motion.overlay`（收合） | 收合於 `Motion.overlay` 內；載入態的等待由 4.24 承載 | §1 子表「等待與結果」列（結果通知＝收合 + 載入態轉換） | 不適用 | 反應：UX 審查（SPEC-003 §2.2、§2.12、§3.7）；通道：規格撰寫者 |

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
| `chooseOtherFailureReason`（`AppText` body 字級、tone `textSecondary`，1.95；1.88 原寫 `AppText.caption`，但 4.1 `caption` 變體恆為單行，與本列「可換行、2 行」矛盾，改比照 4.9 `reason` 的實作字級） | 是 | 2 | 末行截斷（比照 4.9 `reason`：浮層寬有限，原因須可讀；提案） | `switcherChooseFolderUnavailableReason` 的 zh／en 實際值；`switcherFolderUnavailableReason`（`reason` 代入 `TestCopy.longZh`） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `title` | `String` | 否 | 元件預設 `switcherTitle`（參數可覆蓋） |
| `items` | `List<RecentProjectItem>` | 是（0..無上限） | 不適用 |
| `chooseOther` | `AppButton.text` | 是（恰 1；label 由呼叫端：`switcherChooseOtherFolder` / 零項時 `switcherChooseFolderPrompt`） | 不適用 |
| `chooseOtherFailureReason`（1.88） | `String?` | 否（`null` 時不渲染、不佔高度） | 呼叫端（`switcherChooseFolderUnavailableReason` / `switcherFolderUnavailableReason` 取值）；傳回 `null` 的時機由呼叫端依 SPEC-003 §3.7〈浮層內選資料夾失敗的常駐原因文字〉清除時機兩列決定：開始新的嘗試（再次點選選擇其他或任一可用的專案項）的點選當下、浮層收合。本容器不持有該值，收合再展開時呼叫端傳入 `null`（§2 畫面級狀態不存於元件內部） |
| `onDismiss` | `VoidCallback` | 是 | 不適用 |
| `testKey` / `scrollKey` | `Key` | 是（`state-switcher-expanded` / `state-switcher-no-recent`；`scroll-switcher-recent`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`（底）、`borderStrong`（邊框）、`textSecondary`（失敗原因文字，同 4.9 原因，1.88） |
| 間距 | 內距 `Space.sm`；子件最小間距 `Space.xxs`；標題內距 `Space.xs` × `Space.sm`；失敗原因文字水平內距同標題（`Space.sm`，提案） |
| 字體 | 經子件；失敗原因文字 `AppFontSize.caption`（同 4.9 原因） |
| 圓角 | `Radius.lg` |
| 動畫 | `Motion.overlay` |
| 尺寸 | `LayoutSize.overlayWidth` |

陰影：Material `elevation` 預設（畫布 box-shadow 不入 token，提案）。

#### i18n

| 文字 | i18n key |
|------|---------|
| 標題 | `switcherTitle` |
| 選擇其他 | `switcherChooseOtherFolder` / `switcherChooseFolderPrompt`（既有，呼叫端傳入） |
| 選擇其他的失敗原因 | `switcherChooseFolderUnavailableReason` / `switcherFolderUnavailableReason`（新增，§4.0.6〈1.88 新增〉表，呼叫端傳入） |

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
| 狀態變化播報 | 展開時焦點移入浮層（首個可聚焦項）並唸出標題；收合時焦點回入口。選資料夾失敗的原因文字出現時播報一次：`chooseOtherFailureReason` 以 `Semantics(liveRegion: true)` 包覆；專案項點選後判定失敗者，由本容器於傳入該項新的 `reason` 時播報該文字（4.9 自身不設 live region）。理由：失敗後焦點停在原觸發元件、浮層不收合，改為常駐文字後若不播報，輔助技術使用者得不到任何結果（1.88，提案） |
| 非視覺替代訊號 | 不適用 |
| 焦點順序與操作路徑（桌機） | 焦點限制於浮層（`FocusScope` + `FocusTraversalGroup`）；Tab 依序：項目 × N → 選擇其他；失敗原因文字不可聚焦、不進入 Tab 序列；Esc 收合 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染 expanded（1 / 5 / 50 項）與 noRecent
- [ ] 兩種視窗尺寸下不溢位；50 項於 `kMinWindowSize` 高度內可捲動且高不超過上限
- [ ] 標題最長測試文案截斷
- [ ] 本條目 i18n 子節所列各 key 的 zh / en 值皆不溢位
- [ ] Esc 呼叫 `onDismiss` 且焦點回到入口；點外部呼叫 `onDismiss`；Tab 序列不含浮層外元件；收合再展開 offset 為 0
- [ ] 寬、圓角、動畫引用 token 非硬編碼
- [ ] `chooseOtherFailureReason` 傳與不傳各渲染一次（expanded 與 noRecent 皆測）：不傳時找不到該文字且浮層高度與未加入本 slot 前相同；傳入時文字出現於選擇其他下方、兩行末截斷、兩種視窗尺寸下不溢位、不進入 Tab 序列；由非 `null` 改傳 `null` 重建後找不到該文字（1.88）

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 以 4.26 `AppSnackBar` 呈現浮層內選資料夾的失敗結果（1.88） | `chooseOtherFailureReason` 或 4.9 `reason`（SPEC-003 §3.7；§3.1 內容區觸發者仍用 `AppSnackBar`） |
| 以 `showDialog` / `AlertDialog` 呈現（原 `shell.dart` 空殼，**整改完成**：`lib/` 內 `showDialog` / `AlertDialog` / `showModalBottomSheet` / `Drawer(` 實查 0 命中，`0.1.0-W3-169` 複驗 2026-09-09；本列自此為整改記錄，非現存衝突） | 本容器（W1-005 對齊） |
| schema 詳情面板 | `BlockedState.withDetail` 內展開 |

### 4.43 AppCheckbox

**實作類別**：`AppCheckbox`（以 Material `Checkbox` 為內部實作，頁面層禁直用 `Checkbox`，§6）。

**用途**：單一布林設定的常駐切換：核取框 + 文字 label，點擊（核取框或文字皆可）切換值並呼叫 `onChanged`。0.7 唯一使用處為變更記錄篩選列的「包含 ticket 建檔」（`action-history-include-ticket-created`，預設未核取，SPEC-001 §10、SPEC-003 §3.9、SPEC-008 FR-07 規則 2）。
**新增元件而非沿用既有元件的理由**（1.131）：`AppButton` 是一次性動作，沒有開／關兩個持續狀態，也不產生 `checked` 朗讀旗標；`SegmentedControl` 以兩段表示開／關時需要兩個錨點，而 SPEC-003 §3.9 對此控制只定義一個錨點、觸發為「點擊（切換）」；`ListRow.option` 是清單中的互斥選項，選取後不能以再點一次取消；`FilterDropdown` 的值域含「全部」且需展開選單，布林值不需要選單。
**內容角色**：動作 + 狀態（label slot + 核取值）。
**何時不用**：互斥單選（`SegmentedControl`、`ListRow.option`）；一次性動作（`AppButton`）；多值篩選（`FilterDropdown`）。
**出現畫面**：§10。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體（核取框在前、label 在後） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| unchecked | 核取框外框 `AppColors.textSecondary`、無填色；label `textPrimary` | 點選 | `value` 為 `false` | 點選 → checked（經呼叫端改 `value`） | 資料態：第七畫面頁面狀態持有的「包含 ticket 建檔」值（SPEC-008 FR-07 規則 2，預設否；切換導覽項保留、切換專案回到預設，SPEC-003 §3.9〈生命週期〉）；頁面層以 `value` 傳值，元件不 watch（§2） | 本地即時（在記憶體結果上重新查詢，不重新掃描，SPEC-008 FR-07 規則 5） |
| checked | 核取框填色 `AppColors.accent`、勾號 `surfaceBase`；label `textPrimary` | 點選 | `value` 為 `true` | 點選 → unchecked | 資料態：同上 | 本地即時 |
| hover（僅指標形態） | 依 §4.0.1（命中區為核取框 + label 整體） | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | 點選（Space） | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |
| locked（1.148，僅 `AppCheckboxGroup` 內） | 外觀同 disabled；核取值維持送出前；已持有焦點者保留焦點 | 無 | `locked` 為 `true`（由 4.53 下發，4.44〈值格鎖定〉） | `locked` 改為 `false` → 依 `value` 回 unchecked／checked | 資料態：Edit domain 的寫入進行中旗標 | 等確認才顯示 |
| disabled（1.148，僅 `AppCheckboxGroup` 內） | 依 §4.0.1 disabled；不進 Tab 順序 | 無 | `enabled` 為 `false`（由 4.53 下發） | 由 4.53 承載 | 資料態：Edit domain 的編輯狀態 | 等確認才顯示 |

`Toolbar.history` 內無 locked 與 disabled：篩選列只在正常與期間內無事件兩態渲染，兩態皆可切換；其餘狀態不渲染本元件（SPEC-001 §10）。兩列只在 `AppCheckboxGroup`（4.53）內出現；該處的套用時點、回饋契約與同步策略（等確認才顯示，不樂觀切換）以 4.53 為準，本條目下方的套用時點與回饋契約只描述 `Toolbar.history` 用法。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉（v3.14.0）。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——改變事件清單的篩選條件，不執行命令、不開視窗 |
| 2 | 套用時點 | (a)–(e) 皆不成立：單一布林值；切換為本地即時（SPEC-003 §3.9〈服務類型〉）；可隨時切回；不在需儲存的表單內 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——本元件常駐於 `Toolbar.history` |
| 4 | 生效是否當下可見 | 有——事件清單與 `historyPeriodSummary` 的事件數同步更新，或狀態轉為 `state-history-normal`／`state-history-empty`（SPEC-003 §3.9 包含 ticket 建檔列） |

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄；反應與時間門檻抄 SPEC-003，通道與對應狀態邊由本檔填。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | hover 態（§4.0.1：Material `InkWell` 內建 overlay，範圍為核取框 + label）；指標形狀 `SystemMouseCursors.click` | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文） | §1 子表「可互動提示」列 | 不適用 | 反應：規格撰寫者（抄 §4.0.1）；通道：規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 焦點環（§4.0.1 focused）；為 Tab 內容區段的一個停留點（SPEC-003 §2.10）；朗讀 label + `checked` 旗標 | 無 | 無（SPEC-003 §2.10 不設時限） | §1 子表「焦點」列 | unchecked / checked → focused → 原狀態 | 反應：UX 審查（SPEC-003 §2.10）；通道／狀態邊：規格撰寫者 |
| 按下確認 press-ack | 使用者 | pressed 態 + Material ripple（§4.0.1）；呼叫 `onChanged(!value)` 恰一次；核取框外觀於呼叫端改傳 `value` 後的同一 frame 更新。按下確認掛在本元件（第一層），不等查詢結果 | Material 內建 ripple | pressed 態出現於 `Motion.feedback` 內（SPEC-003 §2.2、§2.1） | §1 子表「按下確認」列 | unchecked → pressed → checked；checked → pressed → unchecked | 反應／時限：UX 審查（SPEC-003 §2.2、§3.9）；通道／狀態邊：規格撰寫者 |
| 定位提示 locate | 系統 | 不適用：本元件常駐於 `Toolbar.history`（`Panel` 首格，不捲動），無定位至本元件的場景 | — | — | 不適用（無承載場景） | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（頁面層改傳 `value`；切換專案時回到 `false`，SPEC-003 §3.9〈生命週期〉） | 核取框外觀離散替換，無動畫；`checked` 旗標改變由輔助技術播報（原生旗標，不另組字）；清單的更新由 4.36 承載、無列動畫，狀態根改變時的 cross-fade `Motion.transition` 由畫面承載（SPEC-003 §3.9〈動畫提示〉） | 無（本元件不播動畫；畫面層 `Motion.transition`） | 無（本地即時，與 `value` 同步瞬切） | §1 子表「狀態變更提示」列（無障礙狀態播報適用；不升級系統通知） | unchecked ↔ checked | 反應：UX 審查（SPEC-003 §3.9）；通道／狀態邊：規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層（本元件 pressed 態與核取外觀）——第二層不適用（查詢在記憶體結果上運算，無服務受理階段），第三層為結果通知本身（清單與事件數更新，或 `state-history-normal`／`state-history-empty` 轉換）。服務類型：本地即時（SPEC-003 §3.9〈服務類型〉）。成功：查詢結果依新值更新；失敗：依 SPEC-003 §2.12 本地即時類不可能失敗（純記憶體查詢），無失敗態；逾時：同（不可能發生）；服務不可用：同（不可能發生——本元件只在已有完成結果的兩態渲染，結果不在記憶體時不渲染）。輸入阻擋範圍：不阻擋。重複觸發防護：無需——每次點擊翻轉一次值，連點兩次回到原值，與使用者意圖一致 | Material 內建 | `Motion.feedback` | §1 子表「等待與結果」列 | 不適用 | 反應：UX 審查（SPEC-003 §2.12、§3.9）；通道：規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（核取框與 label 共用一個命中區、一個 Tab 停留點；Space 切換） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 固有尺寸（核取框 `LayoutSize.iconLg` + `Space.xs` + label 寬，水平內距 `Space.xs`） |
| 最小尺寸 | 寬：`LayoutSize.hitTargetMin`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（核取框 + label 整體） |
| 最大尺寸 | 寬：父格位寬（超出時 label 截斷）；高：`LayoutSize.hitTargetMin` |
| `kMinWindowSize` 下的行為 | 維持（`Toolbar.history` 可用寬遠大於固有寬，5.6） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷 | `historyIncludeTicketCreatedLabel`（en「Include ticket creation」）；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是 | 呼叫端（i18n key 取值：`historyIncludeTicketCreatedLabel`） |
| `value` | `bool` | 是 | 不適用 |
| `onChanged` | `ValueChanged<bool>` | 是 | 不適用 |
| `locked` | `bool` | 否（預設 `false`；1.148，由 4.53 下發） | 不適用 |
| `enabled` | `bool` | 否（預設 `true`；1.148，由 4.53 下發） | 不適用 |
| `testKey` | `Key` | 是（`action-history-include-ticket-created`；`AppCheckboxGroup` 內由 4.53 推導 `option-nodeDetail-field-<fieldKey>-<value>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textSecondary`（unchecked 外框）、`accent`（checked 填色）、`surfaceBase`（勾號）、`textPrimary`（label） |
| 間距 | 核取框與 label 間 `Space.xs`；水平內距 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.sm`（核取框） |
| 動畫 | `Motion.feedback` |
| 尺寸 | `LayoutSize.iconLg`（核取框邊長）、`LayoutSize.hitTargetMin` |

#### i18n

| 文字 | i18n key |
|------|---------|
| `label` | `historyIncludeTicketCreatedLabel`（呼叫端傳入，§4.0.6 1.131 新增） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `Toolbar.history`（`toggle` 格）；`AppCheckboxGroup`（4.53，1.148） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 垂直置中於所在列 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics` 含 `checked` 旗標，label 等於 `label`；核取框與文字合併為單一語意節點（不重複朗讀） |
| 狀態變化播報 | `checked` 旗標改變由輔助技術播報 |
| 非視覺替代訊號 | 核取狀態以填色、勾號與 `checked` 旗標三者承載，顏色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | Tab 內容區段，接於期間選擇之後；Space 切換；焦點裝飾依 §4.0.1 |
| 對比 | 依 §4.0.2 表 1：label `textPrimary` / `surfaceBase` 5.79:1；checked 核取框 `accent` / `surfaceBase` 5.84:1、勾號 `surfaceBase` / `accent` 5.84:1；unchecked 外框 `textSecondary` / `surfaceBase` 4.71:1（核取框屬非文字圖形，門檻 3:1，SC 1.4.11），皆通過。外框不用 `borderStrong`：其對 `surfaceBase` 僅 1.55:1，未達 3:1 |

#### 測試點（widget test）

- [ ] 一支測試渲染 unchecked / checked
- [ ] 兩種視窗尺寸下不溢位；高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] zh / en `historyIncludeTicketCreatedLabel` 皆不溢位
- [ ] 點核取框與點 label 各呼叫 `onChanged` 恰一次，值為 `!value`（對照：`value` 為 `false` 與 `true` 各測一次，兩次傳出值不同）
- [ ] `Semantics` 的 `checked` 與 `value` 一致
- [ ] `locked: true` 時點擊不呼叫 `onChanged`、焦點保留；`enabled: false` 時不進 Tab 順序（1.148；對照：兩者皆預設時照常呼叫）
- [ ] 顏色、間距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 互斥單選 | `SegmentedControl` / `ListRow.option` |
| 觸發一次性命令（重新整理、重試） | `AppButton` |
| 需要「儲存」才生效的表單欄位 | 0.7 無此需求；出現時另建元件票 |

### 4.44 AppTextInput

> **1.140 新增（`1.0.0-W3-553.6`，依 SPEC-009 FR-09）；1.143 回填編輯狀態（`1.0.0-W3-553.3.1`，依 SPEC-001 v1.89 §6〈編輯模式〉、SPEC-003 v1.94 §3.6）。** 4.44–4.48 為 1.0 編輯用表單元件。1.140 標「待決（1.0.0-W3-553.3）」的欄位已於 1.143 回填；失焦草稿、寫入結果時的焦點、欄位排列與 Tab 順序三項依用戶裁定 2026-11-11（`1.0.0-W3-553.3.1` 題 1–3）。本組條目是否可被畫面票引用，以 `1.0.0-W3-553.6` 重驗〈契約齊全的定義〉的結果為準（§4.0.9）。

**本組共用的值格鎖定與錨點**（1.143）：

| 項目 | 定義 |
|------|------|
| `enabled: false`（disabled） | 只用於「外部已改阻擋」：各欄不可送出、未送出的值保留顯示（SPEC-001 §6）。唯讀降級時不可能進入編輯模式（SPEC-009 FR-01），本組元件不會以唯讀降級為由 disabled |
| `locked: true`（唯讀鎖定） | 寫入進行中（發出到受理）全部值格的狀態：外觀同 disabled、保留焦點、不可輸入、不可提交、不展開選單；不進 Tab 順序，但已持有焦點者不失去焦點。用 `locked` 而不用 disabled 的理由：Flutter 的值格 disabled 時會失去焦點，送出後焦點消失會打斷輸入（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2 (e)） |
| `hasError` | 該欄最近一次寫入結果為 `blocked(snapshotFailed)`、`blocked(rewriteNotIsolated)` 或 `ioFailed`（SPEC-003 §2.14 列 24），且之後尚未再送出。下一次送出（進入 writing）時清除。驗證 `failed` 不設 `hasError`：值已寫入，問題不在這一欄的輸入 |
| 錨點 | 值格可操作節點 `action-nodeDetail-field-<fieldKey>`（文字輸入框、下拉與引用選擇器的觸發器）；選單 `menu-nodeDetail-field-<fieldKey>`；選項 `option-nodeDetail-field-<fieldKey>-<value>`；引用選擇器過濾框 `action-nodeDetail-field-<fieldKey>-filter`；`FieldBlock` 提示格 `badge-nodeDetail-field-<fieldKey>-hint`。`<fieldKey>` 取 frontmatter 鍵名字面值，與 `FieldBlock` 根節點 `card-nodeDetail-field-<fieldKey>`（SPEC-003 §2.9）同源；類別皆為 SPEC-003 §2.9 既有類別 |
| 值的來源 | `value`／`selected` 由呼叫端傳入 Edit domain 的 M 中的欄位值，及寫入受理為 `written` 後的值，不是最後完成輪次的節點資料（SPEC-003 §3.6〈生命週期〉：輪次更新不改 FieldList 的值）。1.0 不允許樂觀更新（§2） |
| 草稿捨棄 | 完成、點關聯、返回、判定順序 1–4 命中時 FieldList 整個移除，草稿隨元件卸載捨棄；放棄並重讀成功時呼叫端以新的 widget key 重建各值格，草稿捨棄、值改為磁碟上的值（SPEC-003 §3.6 放棄並重讀列）。切至其他導覽項時元件不卸載（`IndexedStack`），草稿保留 |

**實作類別**：`AppTextInput`（以 Material `TextField` 為內部實作；頁面層禁直用 `TextField`，§6）。

**用途**：表單欄位的自由文字值輸入（SPEC-009 FR-09「自由文字：單行；段落為多行」），以及值域尚無機器定義的列舉欄位在過渡期的輸入（FR-09〈值域來源〉）。只放在 `FieldBlock` 的值格；欄位 label、提示、錯誤文字由 `FieldBlock` 承載，本元件不帶 label。
**新增元件而非沿用 4.12 `SearchField` 的理由**：`SearchField` 是對清單的即時過濾，每次輸入即 `onChanged`、結果是清單子集，退出路徑是清空；本元件的輸入是待提交的欄位值，退出路徑是提交（寫入）或還原，兩者退出路徑不同。`SearchField` 另帶搜尋圖示、清除鈕與固定錨點，組合規則只允許 `Toolbar` 首格。
**內容角色**：數值（可編輯的欄位值）+ 標籤（空值時的 placeholder）。
**何時不用**：搜尋過濾（`SearchField`）；值域有機器定義的列舉（`AppDropdown`、`AppRadioGroup`）；單一引用（`ReferencePicker`）；唯讀值（`FieldBlock.readOnly` 值格放 `AppText`）；文件內文（1.3，不在本版）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6「編輯中」「外部已改預警」「外部已改阻擋」），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `singleLine` | 單行，固定高 | Enter 提交；值超出寬度時隨游標水平捲動 | FR-09 單行欄位（title、proposed_by、subdomain、owner、primary_actor、name、canonical_name，及過渡期以單行輸入的列舉欄位） |
| `multiLine` | 3–8 行可見，超出 8 行內部垂直捲動 | Enter 換行，⌘Enter 提交 | FR-09 多行欄位（EVT payload） |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| idle | 框 `AppColors.border`；值 `textPrimary`；值為空字串時顯示 placeholder `fieldEmptyValue`（`textSecondary`） | 點選或 Tab 進入 | 未取得焦點 | 取得焦點 → editing | —（`value` 由呼叫端傳入已落檔值，元件不 watch，§2） | 等確認才顯示（`value` 只在寫入結果為 `written` 後由呼叫端更新，SPEC-009 FR-05、§2 樂觀更新政策列） |
| editing | 框 `AppColors.accent`（焦點裝飾，§4.0.1）+ 文字游標；顯示草稿 | 輸入、提交、還原 | 取得焦點 | 提交（`singleLine` Enter、`multiLine` ⌘Enter）→ 呼叫 `onSubmitted(draft)`，焦點保留，呼叫端隨即傳 `locked: true` → locked；Esc → 草稿還原為 `value`、不呼叫、焦點保留；失焦 → idle，草稿保留、不提交（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 1）；草稿與 `value` 不同時以 `onDirtyChanged(true)` 告知呼叫端，`FieldBlock` 顯示未送出提示 | 互動瞬態（草稿為元件內部 `TextEditingController`，存在於元件掛載期間，失焦不清除，不存於 provider；捨棄時點見本組〈草稿捨棄〉） | 本地即時（草稿回顯） |
| locked | 外觀同 disabled（框 `border`、值 `textDisabled`）；仍持有焦點者保留文字游標位置但不閃爍 | 無（不可輸入、不可提交、Esc 無作用） | `locked` 為 `true`（寫入進行中，見本組〈值格鎖定〉） | `locked` 改為 `false` → 仍持有焦點者回 editing，否則回 idle | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發（4.50），元件不 watch | 等確認才顯示 |
| error | 框 `AppColors.error` | 同 idle／editing | `hasError` 為 `true`（本組〈`hasError`〉：該欄最近一次寫入被拒或讀寫失敗） | 下一次提交 → 呼叫端改 `hasError` 為 `false` | 資料態：該欄最近一次 `WriteResult`，經 `FieldBlock` 傳入 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled；值改 `textDisabled`；不可輸入、不進 Tab 順序；未送出的草稿保留顯示 | 無 | `enabled` 為 `false`（外部已改阻擋，本組〈值格鎖定〉） | 放棄並重讀成功 → 呼叫端以新 key 重建（草稿捨棄）；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| hover（僅指標形態） | 依 §4.0.1（`InputDecoration` hover 底色，`ThemeData` 預設） | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 不適用：`TextField` 無 pressed 態 | — | — | — | 互動瞬態 | 本地即時 |

editing 與 error 可並存（框色以 error 優先，焦點另以文字游標與 textField 語意承載）。locked 與 disabled 互斥：外部已改阻擋時沒有寫入可以發出。

#### 套用時點

不適用：非選擇類元件（自由文字輸入，不從選項中選取）。提交時點由狀態矩陣 editing 列的退出路徑定義。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄。寫入的發出、受理、結果三時刻由 `FieldBlock`（4.48）承載，本元件只承載輸入層。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | `TextField` 內建 hover；指標形狀 `SystemMouseCursors.text` | 無（Material 內建） | 無（SPEC-003 無 hover 時限條文） | §1 子表「可互動提示」列 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 框 `accent` + 文字游標；朗讀 `semanticLabel` 與目前值 | 無 | 無 | §1 子表「焦點」列 | idle → editing → idle；editing → locked（焦點保留）→ editing | 規格撰寫者；欄位間 Tab 順序見 4.50 無障礙（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 3） |
| 按下確認 press-ack | 使用者 | 輸入字元即時回顯；IME 組字中不視為草稿變更；提交鍵呼叫 `onSubmitted(draft)` 恰一次（草稿與 `value` 相同時不呼叫）；Esc 還原草稿。掛載點為本元件第一層，不等寫入受理 | 無 | 回顯無時限條文（原生行為） | §1 子表「按下確認」列 | editing →（提交）→ locked | 規格撰寫者 |
| 定位提示 locate | 系統 | 不移動焦點：寫入結果與驗證結果回來時焦點維持原處（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2）；結果由 `FieldBlock` 提示格以文字與 `liveRegion` 承載 | 無 | 無 | §1 子表「定位提示」列 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（寫入結果 `written` 後改傳 `value`） | 值離散替換、無動畫；`written` 的值即剛提交的草稿，草稿與 `value` 相同，未送出提示消失。編輯期間收到外部改動（EVT-CORPUS-001）時 `value` 不變、草稿保留（M 在放棄並重讀前不更新，SPEC-003 §3.6〈生命週期〉）；放棄並重讀成功時以新 key 重建（本組〈草稿捨棄〉） | 無 | 無 | §1 子表「狀態變更提示」列 | locked → editing／idle（受理）；任一態 → 重建（放棄並重讀） | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為本元件（回顯與提交）；第二層為 `FieldBlock` writing（提示格 `fieldWriteInProgress`，本元件 locked）；第三層為 `FieldBlock` 的寫入結果與驗證狀態（4.48 回饋契約四段結局） | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 鍵盤輸入（`TextInputType.text`；`multiLine` 為 `TextInputType.multiline`；IME 允許）；`singleLine` Enter 提交、`multiLine` ⌘Enter 提交；Esc 還原 | 字元級 | 足夠 | 無 | 視覺（值即時顯示） |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位（`FieldBlock` 值格）；高：`singleLine` 固定，`multiLine` 隨行數 |
| 最小尺寸 | 寬：`Space.sm` + 4 字元（`AppFontSize.body`，§4.0.3）+ `Space.sm`；高：`singleLine` 為 `LayoutSize.hitTargetMin`，`multiLine` 為 3 行 + 2 × `Space.xs` |
| 最小命中區 | `LayoutSize.hitTargetMin`（整個輸入框） |
| 最大尺寸 | 寬：父格位寬；高：`singleLine` 為 `LayoutSize.hitTargetMin`，`multiLine` 為 8 行 + 2 × `Space.xs`（超出內部捲動） |
| `singleLine` 高的內部條件 | 一行（`AppFontSize.body` 行高）+ 2 × `Space.xs` ≤ `LayoutSize.hitTargetMin`。測試字型（Ahem，行高 = 字級）：12 + 8 = 20 ≤ 28 成立。實機字型：body 行高 ≤ 20 即成立，由 `integration_test/real_font_layout_test.dart` 斷言 |
| `kMinWindowSize` 下的行為 | 維持（約束由 `FieldBlock` 與其父格位決定） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `value`（`singleLine`，可編輯） | 否 | 1 | 不截斷：隨游標水平捲動（可編輯文字不適用顯示文字的四選一） | `TestCopy.nodeTitle`；`TestCopy.longToken` |
| `value`（`multiLine`，可編輯） | 是 | 8（可見） | 不截斷：超出內部垂直捲動 | `TestCopy.longZh`；`TestCopy.longEn` |
| placeholder | 否 | 1 | 截斷 | `fieldEmptyValue`（en「Not set」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `value` | `String` | 是（受控，已落檔值；欄位缺值時傳空字串） | 呼叫端（文件 frontmatter 值，資料值不進 i18n） |
| `onSubmitted` | `ValueChanged<String>` | 是（草稿 trim 後為空時照常呼叫、傳原草稿；寫入 `null` 或擋下由呼叫端依 SPEC-009 FR-09〈可否清空〉決定，元件不判斷欄位是否必填。用戶裁定 2026-11-11，`1.0.0-W3-686`） | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端（與 `FieldBlock` label 同一字串） |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `locked` | `bool` | 否（預設 `false`；本組〈值格鎖定〉） | 不適用 |
| `hasError` | `bool` | 否（預設 `false`） | 不適用 |
| `onDirtyChanged` | `ValueChanged<bool>?` | 否（`FieldBlock` 內使用時必傳，用於未送出提示） | 不適用 |
| `testKey` | `Key` | 是（`action-nodeDetail-field-<fieldKey>`，本組〈錨點〉） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`、`accent`（focused 框）、`error`（error 框）、`textPrimary`（值）、`textSecondary`（placeholder）、`textDisabled`（disabled）、`surfaceBase`（底） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直） |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 尺寸 | `LayoutSize.hitTargetMin` |

#### i18n

| 文字 | i18n key |
|------|---------|
| placeholder | `fieldEmptyValue`（§4.0.6 1.140 新增） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊 |
| 作為表格或列表的一欄時 | 不適用（1.0 無表格列編輯，FR-09 結構化區塊自 1.4 起） |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.textField`；label 為 `semanticLabel`，value 為目前值；`multiLine` 帶 multiline 旗標 |
| 狀態變化播報 | 值改變由 textField 語意播報；錯誤文字由 `FieldBlock` 提示格承載（4.48 無障礙） |
| 非視覺替代訊號 | error 框色非唯一訊號：錯誤文字由 `FieldBlock` 提示格以文字呈現 |
| 焦點順序與操作路徑（桌機） | 進入 Tab 順序（disabled、locked 除外；locked 時已持有的焦點保留）；提交與還原鍵見操作機制；欄位間 Tab 順序見 4.50 無障礙 |
| 對比 | 依 §4.0.2：值 `textPrimary` / `surfaceBase` 5.79:1、placeholder `textSecondary` / `surfaceBase` 4.71:1，通過；error 框 `error` / `surfaceBase` 屬表 1 通過列（非文字 3:1 亦通過） |

#### 測試點（widget test）

- [ ] 一支測試渲染兩變體 × idle / editing / locked / error / disabled
- [ ] 失焦時草稿保留、不呼叫 `onSubmitted`，`onDirtyChanged(true)` 被呼叫；對照：草稿等於 `value` 時失焦不呼叫 `onDirtyChanged(true)`
- [ ] 提交後傳 `locked: true`：焦點仍在本元件、輸入字元不改變文字；對照：傳 `enabled: false` 時焦點離開本元件
- [ ] 兩種視窗尺寸下不溢位；`singleLine` 高等於 `LayoutSize.hitTargetMin`；`multiLine` 高介於 3 行與 8 行之間
- [ ] `TestCopy.longToken` 輸入後 `singleLine` 無溢位錯誤；`TestCopy.longZh` 於 `multiLine` 換行、超過 8 行內部捲動
- [ ] zh / en placeholder 皆不溢位
- [ ] `singleLine` Enter、`multiLine` ⌘Enter 各呼叫 `onSubmitted` 恰一次；對照：`multiLine` 按 Enter 不呼叫、插入換行；草稿與 `value` 相同時不呼叫
- [ ] Esc 還原草稿為 `value` 且不呼叫 `onSubmitted`
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 清單搜尋過濾 | `SearchField` |
| 值域已有機器定義的列舉欄位 | `AppDropdown` / `AppRadioGroup` |
| 選另一個節點或版本 | `ReferencePicker` |
| 顯示唯讀值 | `FieldBlock.readOnly`（值格 `AppText`） |

### 4.45 AppDropdown

**實作類別**：`AppDropdown`（選單以覆蓋層實作，同 4.13 的覆蓋層機制；頁面層禁直用 `DropdownButton` / `DropdownMenu`，§6）。

**用途**：表單欄位的列舉值選擇（SPEC-009 FR-09「等級（有序）」「生命週期（文件節點）」：下拉），選項取自 `tracking_schema.json` 或 doc CLI 的機器定義值域（FR-09〈值域來源〉）。1.0 現行使用處：PROP status（`VALID_STATUSES`）；其餘列舉欄位於值域補上後改用本元件。
**新增元件而非沿用 4.13 `FilterDropdown` 的理由**：`FilterDropdown` 首項固定為「全部」並回傳 `null`（F3），表單欄位沒有「不篩選」值；其 active 態（框色 `accent`）表示「有篩選」，表單無此語意；觸發器文字為「{label}：{value}」複合字串，表單的 label 由 `FieldBlock` 承載；表單另須呈現值域外的既有值（檔案內手寫值），篩選不會遇到。兩者的退出路徑也不同：篩選為本地即時、改選「全部」即復原，表單選取觸發寫入（SPEC-009 FR-05）。
**內容角色**：標籤（取值來自有限列舉）。
**何時不用**：篩選（`FilterDropdown`）；值域小且需並列比較的分類（`AppRadioGroup`，FR-09 分類列）；引用另一個對象（`ReferencePicker`）；無機器定義值域的欄位（`AppTextInput.singleLine`，FR-09〈值域來源〉）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6 三個編輯狀態），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| empty | 觸發器顯示 `fieldEmptyValue`（`textSecondary`）+ 向下箭頭 | 點選 → open | `selected` 為 `null`（欄位缺值） | 選取任一選項 → 呼叫 `onChanged`，呼叫端傳 `locked: true` → locked；寫入結果為 `written` 後呼叫端改傳 `selected` → set | —（`selected` 由呼叫端傳入已落檔值，元件不 watch，§2） | 等確認才顯示（SPEC-009 FR-05、§2） |
| set | 觸發器顯示目前選項的 `label`（`textPrimary`）+ 向下箭頭 | 點選 → open | `selected` 為 `options` 之一 | 同 empty | — | 等確認才顯示 |
| outOfDomain | 觸發器顯示原值（`textPrimary`）+ 向下箭頭；`FieldBlock` 提示格顯示 `fieldValueOutOfDomain`（用戶裁定 2026-11-11，`1.0.0-W3-675`） | 點選 → open | `selected` 非 `null` 且不在 `options` 內（檔案內手寫值） | 同 empty | — | 等確認才顯示 |
| open | 選單以覆蓋層展開（D1–D7）；觸發器顯示不變 | 走選項、選取、Esc、點外部、再點觸發器、Tab | 點選觸發器或聚焦時 Enter／Space／↓ | 選取且值改變 → 收合，呼叫 `onChanged(value)`；值相同、Esc、點外部、再點觸發器、Tab → 收合，不呼叫 | 互動瞬態（選單開合為元件內部 overlay 狀態） | 本地即時 |
| locked | 外觀同 disabled；觸發器顯示原值（不顯示剛選的值，不允許樂觀更新）；仍持有焦點 | 無（不可展開） | `locked` 為 `true`（寫入進行中，4.44〈值格鎖定〉） | `locked` 改為 `false` → 依 `selected` 回 empty／set／outOfDomain（焦點保留） | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled；不可展開 | 無 | `enabled` 為 `false`（外部已改阻擋，4.44〈值格鎖定〉） | 放棄並重讀成功 → 以新 key 重建；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | Enter / Space / ↓ 展開 | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

不允許樂觀更新：選取後觸發器不立即顯示新值，等呼叫端依寫入結果改傳 `selected`（§2）。寫入進行中觸發器為 locked、顯示原值，`FieldBlock` 提示格顯示 `fieldWriteInProgress`；寫入被拒或讀寫失敗時觸發器維持原值，提示格說明檔案未改。本元件無草稿：選取即提交，失焦不涉及未送出的值。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選取改變欄位值，不執行命令、不開視窗（選單為本元件內部覆蓋層） |
| 2 | 套用時點 | (a) 不成立（一次寫入只改目標欄位，SPEC-009 FR-03）；(b) 不成立（寫入受理延遲依 SPEC-009 NFR-01，不需預覽）；(c) 不成立；(d) 不成立（可經 FR-02 快照取回）；(e) 不成立：逐欄立即提交，沒有表單層級的儲存（用戶裁定 2026-11-11，`1.0.0-W3-675`；SPEC-001 §6〈編輯模式〉逐欄送出、立即寫入）→ 立即提交，提交點為「選取且值改變」 |
| 3 | 容器何時關閉 | 是——選單只含本欄位一組單選 → 選取即收合 |
| 4 | 生效是否當下可見 | 有——寫入受理為 `written` 後觸發器顯示新值，`FieldBlock` 提示格顯示驗證狀態（SPEC-003 §3.6 欄位送出列）；受理前觸發器維持原值、提示格顯示寫入中。選取標示不算已生效（不允許樂觀更新），回饋契約關卡二第 2 問以受理後的觸發器值為結果 |

#### 回饋契約

> 選單內的逐操作反應為本元件的操作路徑，規格在〈選單的元件級契約〉D1–D7。寫入的三時刻由 `FieldBlock` 承載。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 觸發器與各選項 hover 態（§4.0.1）；指標形狀 `SystemMouseCursors.click` | 無（Material 內建） | 無 | §1 子表「可互動提示」列 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 觸發器焦點環；展開時焦點移至目前值對應選項（empty、outOfDomain 時為首項），↑／↓／Home／End 移動不循環、不呼叫 `onChanged`；Esc／選取後焦點回觸發器 | 無 | 無 | §1 子表「焦點」列 | empty / set / outOfDomain → focused → 原狀態 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 觸發器 pressed + ripple，選單展開；選項 pressed + ripple，選取且值改變 → `onChanged(value)` 恰一次、選單收合；掛載點為本元件第一層，不等寫入受理 | Material 內建 ripple；選單 `Motion.overlay` | pressed 於 `Motion.feedback` 內；選單於 `Motion.overlay` 內 | §1 子表「按下確認」列 | 原狀態 → pressed → open；open →（選取）→ 原狀態 | 規格撰寫者（時限沿用 4.13 所抄 SPEC-003 §2.2、§3.4） |
| 定位提示 locate | 系統 | 選單收合後焦點回觸發器（D1–D7）；寫入結果與驗證結果回來時不移動焦點（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） | 無 | 無 | §1 子表「定位提示」列 | open → locked（焦點在觸發器） | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（寫入結果 `written` 後改傳 `selected`） | 觸發器文字離散替換、無動畫；重建即唸出新值（`dropdownA11yLabel`） | 無 | 無 | §1 子表「狀態變更提示」列 | empty / set / outOfDomain →（選取）→ locked →（`written`）→ set；locked →（被拒、讀寫失敗）→ 原狀態 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為本元件（選取的 pressed 與選單收合）；第二層為 `FieldBlock` writing（本元件 locked）；第三層為 `FieldBlock` 的寫入結果與驗證狀態，四段結局見 4.48 | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（觸發器）；選單內 ↑／↓／Home／End 走選項，Enter／Space 選取，Esc 收合 | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位（`FieldBlock` 值格；與 4.13 取固有寬不同，表單欄位對齊值格）；高固有 |
| 最小尺寸 | 寬：`Space.sm` + 4 字元（`AppFontSize.body`）+ `Space.xs` + `LayoutSize.iconMd`（箭頭）+ `Space.sm`；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（觸發器與每個選項） |
| 最大尺寸 | 寬：父格位寬；高：`LayoutSize.hitTargetMin` |
| 選單尺寸 | 寬等於觸發器寬；高 = N × `LayoutSize.hitTargetMin` + 2 × `Space.xs`，N ≤ 10（slot 契約上限，由下列算式推導），全數展開不捲動 |
| `kMinWindowSize` 下的行為 | 維持。觸發器上下兩側中較大者 ≥ (640 − `LayoutSize.titleBarHeight` 36 − 28) / 2 = 288；選單全數展開不捲動須 N × `LayoutSize.hitTargetMin` + 2 × `Space.xs` ≤ 288，即 N × 28 + 8 ≤ 288 → N ≤ 10。上限 10 時選單最大高 = 288（不隨字型），依 D4 選側即放得下（1.144：上限由提案值 8 改為本推導值，用戶裁定 2026-11-11，`1.0.0-W3-553.6`） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 觸發器與選項 `options[i].label`、outOfDomain 原值 | 否 | 1 | 截斷 | `TestCopy.status`；`TestCopy.longToken` |
| 空值文字 | 否 | 1 | 截斷 | `fieldEmptyValue` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `options` | `List<DropdownOption{value, label}>`，1..10 項（推導上限：`kMinWindowSize` 下選單全數展開不捲動，N × 28 + 8 ≤ 288 → N ≤ 10，算式見尺寸契約；值域超過 10 項時回規格裁定） | 是 | 呼叫端（值域原值，資料值不進 i18n） |
| `selected` | `String?`（`null` = 欄位缺值；不在 `options` 內 = outOfDomain） | 是 | 不適用 |
| `onChanged` | `ValueChanged<String>` | 是 | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端（與 `FieldBlock` label 同一字串） |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `locked` | `bool` | 否（預設 `false`；4.44〈值格鎖定〉） | 不適用 |
| `testKey` | `Key` | 是（觸發器 `action-nodeDetail-field-<fieldKey>`；選單 `menu-nodeDetail-field-<fieldKey>`、選項 `option-nodeDetail-field-<fieldKey>-<value>` 由元件推導；4.44〈錨點〉） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border`、`textPrimary`、`textSecondary`（空值文字）、`textDisabled`（箭頭，純裝飾，§4.0.2 表 2；disabled） |
| 間距 | 內距 `Space.sm`（水平）× `Space.xs`（垂直）；文字與箭頭間 `Space.xs`；選單內距 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`；`Motion.overlay`（選單） |
| 尺寸 | `LayoutSize.hitTargetMin`、`iconMd` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 空值文字 | `fieldEmptyValue` |
| 朗讀標籤 | `dropdownA11yLabel`（§4.0.6 1.140 新增） |
| outOfDomain 提示（由 `FieldBlock` 提示格顯示） | `fieldValueOutOfDomain`（§4.0.6 1.140 新增） |

#### 選單的元件級契約（跨操作恆成立，由本元件單一承擔）

| # | 條件 | 可觀察結果 |
|---|------|-----------|
| D1 | 任一時刻 | 全 App 同時至多一個選單展開（與 4.13 F1 共用同一約束） |
| D2 | 選單展開時 | 觸發器顯示只由 `selected` 決定，不因展開或走選項改變 |
| D3 | 選單展開時（內容） | 依 `options` 順序列出，無「全部」項；outOfDomain 的原值不列入選項；目前值項（若在 `options` 內）`selected` 為 `true` |
| D4 | 選單展開時（幾何） | 覆蓋層，左緣對齊觸發器左緣、寬等於觸發器寬；預設頂緣貼觸發器底緣，底緣超出視窗且觸發器上方空間較大時改為底緣貼觸發器頂緣；版面其餘元素 rect 不變 |
| D5 | 展開／走選項／收合 | 皆不呼叫 `onChanged`；唯一呼叫點是「選取且值改變」 |
| D6 | 選單展開時（播報） | 選單根 `role` 為 `menu`、選項 `role` 為 `menuItem`；觸發器 `expanded` 隨展開與收合改變 |
| D7 | 選單展開期間 | 點外部吸收收合，不穿透 |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | `Semantics.button`；label 為 `dropdownA11yLabel`（`semanticLabel` 與目前值代入；empty 時代入 `fieldEmptyValue`）；`expanded` 等於是否 open |
| 狀態變化播報 | 呼叫端改傳 `selected` 後重建即唸出新值，不另發 `SemanticsService.announce` |
| 非視覺替代訊號 | 值以文字呈現；outOfDomain 以 `FieldBlock` 提示格文字說明，不只靠顏色 |
| 焦點順序與操作路徑（桌機） | 觸發器進入 Tab 順序（disabled、locked 除外；locked 時已持有的焦點保留）；選單內鍵盤操作見操作機制；欄位間 Tab 順序見 4.50 無障礙 |
| 對比 | 依 §4.0.2：值 `textPrimary` / `surfaceBase` 5.79:1、空值文字 `textSecondary` / `surfaceBase` 4.71:1，通過；箭頭 `textDisabled` 3.06:1 達非文字 3:1，純裝飾 |

#### 測試點（widget test）

- [ ] 一支測試渲染 empty / set / outOfDomain / open / locked / disabled
- [ ] 選取新值後傳 `locked: true`：觸發器仍顯示原值、焦點在觸發器、不可展開；對照：傳 `enabled: false` 時焦點離開
- [ ] 兩種視窗尺寸下不溢位；觸發器高等於 `LayoutSize.hitTargetMin`；`kMinWindowSize` 下 10 個選項時選單全數展開、不捲動、整體在視窗內
- [ ] 最長測試文案截斷；zh / en 空值文字不溢位
- [ ] 選取且值改變呼叫 `onChanged` 恰一次；對照：選取目前值不呼叫；選取後觸發器文字在 `selected` 改傳前不變（不允許樂觀更新）
- [ ] D3：無「全部」項、順序同 `options`、outOfDomain 原值不在選項內；D4：觸發器置於視窗底部時選單向上展開且整體在視窗內；D6、D7 同 4.13 F6、F7 的斷言形式
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 清單篩選 | `FilterDropdown` |
| 選項數隨資料增減的引用 | `ReferencePicker` |
| 互斥、值域小且固定、需並列比較的分類（SPEC-009 FR-09 分類列） | `AppRadioGroup` |

### 4.46 ReferencePicker

**實作類別**：`ReferencePicker`（觸發器 + 覆蓋層，覆蓋層內含元件自帶的過濾輸入框與可捲動選項清單；頁面層禁直用 `DropdownMenu`、`Autocomplete`，§6）。

**用途**：表單欄位的單一引用選擇（SPEC-009 FR-09「單一引用：可搜尋下拉」）。1.0 使用處：PROP target_version（選項為 todolist 的版本）、SPEC domain（選項為已宣告的 domain，以 `DomainBundle` 的 `domain` 原值呈現，CLAUDE.md §6 domain 名稱權威寫法）。
**新增元件而非併入 `AppDropdown` 的理由**：內容角色不同——引用值指名另一個對象（版本、DomainBundle），讀者據以辨認「是哪一個」，屬標題類；`AppDropdown` 的值是列舉，屬標籤類。行為不同——選項來自專案資料、數量隨專案增減，需捲動與文字過濾；列舉選項固定且至多 10 項（4.45〈尺寸契約〉推導值）、全數展開不捲動。選單內的過濾框屬本元件自帶子件，不放 4.12 `SearchField`（其組合規則只允許 `Toolbar` 首格，且語意為清單過濾而非選取）。
**內容角色**：標題（被引用對象的識別值）。
**何時不用**：列舉值（`AppDropdown`）；多值引用（節點 ID 用 `ReferenceChips`，4.52；domain 用 `AppCheckboxGroup`，4.53）；清單篩選（`FilterDropdown`、`SearchField`）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6 三個編輯狀態），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；可否選空值為參數 `allowEmpty`（選單首項為 `fieldEmptyValue`），不另立變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| empty | 觸發器 `fieldEmptyValue`（`textSecondary`）+ 向下箭頭 | 點選 → open | `selected` 為 `null` | 選取 → 呼叫 `onChanged`，呼叫端傳 `locked: true` → locked；`written` 後呼叫端改傳 `selected` → set | —（`selected` 與 `options` 由呼叫端傳入，元件不 watch，§2） | 等確認才顯示 |
| set | 觸發器顯示目前選項 `label`（`textPrimary`） | 點選 → open | `selected` 在 `options` 內 | 同 empty | — | 等確認才顯示 |
| outOfDomain | 觸發器顯示原值；`FieldBlock` 提示格 `fieldValueOutOfDomain`（用戶裁定 2026-11-11，`1.0.0-W3-675`） | 點選 → open | `selected` 非 `null` 且不在 `options` 內（版本不在 todolist、domain 未宣告） | 同 empty | — | 等確認才顯示 |
| open | 覆蓋層展開：首列過濾輸入框（placeholder `searchPlaceholder`，焦點自動移入），其下選項清單；`allowEmpty` 時清單首列為 `fieldEmptyValue`，不參與過濾、固定在首列（`1.0.0-W3-686`，主控依用戶裁定推導）；無符合項時清單區顯示 `referencePickerNoMatch`（首列仍在） | 輸入過濾、走選項、選取、Esc、點外部 | 點選觸發器或聚焦時 Enter／Space／↓ | 選取且值改變 → 收合並呼叫 `onChanged`；值相同、Esc、點外部 → 收合，不呼叫；過濾字串於收合時清空 | 互動瞬態（開合、過濾字串、走選項位置皆為元件內部狀態） | 本地即時（過濾為已傳入選項的子集運算） |
| locked | 外觀同 disabled；觸發器顯示原值；仍持有焦點 | 無（不可展開） | `locked` 為 `true`（寫入進行中，4.44〈值格鎖定〉） | `locked` 改為 `false` → 依 `selected` 回 empty／set／outOfDomain（焦點保留） | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled | 無 | `enabled` 為 `false`（外部已改阻擋，4.44〈值格鎖定〉） | 放棄並重讀成功 → 以新 key 重建；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| hover（僅指標形態） | 依 §4.0.1 | 點選 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 點選 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1 | Enter / Space / ↓ 展開 | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選取改變欄位值；不導覽至被引用對象 |
| 2 | 套用時點 | 同 4.45：(a)–(e) 皆不成立 → 立即提交（用戶裁定，`1.0.0-W3-675`），提交點為「選取且值改變」 |
| 3 | 容器何時關閉 | 是——覆蓋層只含本欄位一組單選 → 選取即收合 |
| 4 | 生效是否當下可見 | 同 4.45：有——受理為 `written` 後顯示新值；受理前維持原值 |

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 觸發器與選項 hover 態（§4.0.1）；過濾框指標 `SystemMouseCursors.text` | 無（Material 內建） | 無 | §1 子表「可互動提示」列 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 觸發器焦點環；展開時焦點移入過濾框，↑／↓ 在過濾後的選項間移動高亮（焦點留在過濾框，選項以 `selected` 以外的 active 標示）；Esc／選取後焦點回觸發器 | 無 | 無 | §1 子表「焦點」列 | 原狀態 → open → 原狀態 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 觸發器 pressed + ripple，覆蓋層展開；過濾框輸入即時縮減清單；選項點選或 Enter：值改變時 `onChanged(value)` 恰一次、收合。掛載點為本元件第一層 | Material 內建 ripple；覆蓋層 `Motion.overlay` | pressed 於 `Motion.feedback` 內；覆蓋層於 `Motion.overlay` 內；過濾回顯無時限條文（本地即時，不防抖） | §1 子表「按下確認」列 | 原狀態 → open →（選取）→ 原狀態 | 規格撰寫者 |
| 定位提示 locate | 系統 | 展開時清單捲動至目前值所在列（`jumpTo`，§4.0.10 捲動方式）；寫入結果與驗證結果回來時不移動焦點（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） | 無 | 無 | §1 子表「定位提示」列 | open | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（`written` 後改傳 `selected`） | 觸發器文字離散替換、重建唸出新值（`dropdownA11yLabel`） | 無 | 無 | §1 子表「狀態變更提示」列 | →（選取）→ locked →（`written`）→ set；locked →（被拒、讀寫失敗）→ 原狀態 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為本元件；過濾為本地即時，不經服務：讀取的選項於呼叫端傳入 `options` 時已載入（todolist 與 DomainBundle 由掃描結果提供），選項為空時顯示 `referencePickerNoMatch`；寫入的第二層為 `FieldBlock` writing（本元件 locked），第三層為 `FieldBlock` 的寫入結果與驗證狀態，四段結局見 4.48 | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（觸發器）；展開後鍵盤輸入過濾（IME 允許，組字中不過濾）、↑／↓ 走選項、Enter 選取、Esc 收合；指標點選選項 | 字元級（過濾）；命中一列（選取） | 足夠 | 無 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 觸發器寬填滿父格位；高固有 |
| 最小尺寸 | 寬：同 4.45（`Space.sm` + 4 字元 + `Space.xs` + `LayoutSize.iconMd` + `Space.sm`）；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（觸發器、過濾框、每個選項） |
| 最大尺寸 | 寬：父格位寬；高：`LayoutSize.hitTargetMin` |
| 覆蓋層尺寸 | 寬 = 觸發器寬；高 = `Space.xs` + `LayoutSize.hitTargetMin`（過濾框）+ `Space.xs` + min(N, 8) × `LayoutSize.hitTargetMin` + `Space.xs`（N 為清單列數，`allowEmpty` 時含首項）；N > 8 時清單區垂直捲動；向上或向下展開規則同 4.45 D4，選定方向的可用高不足時清單區再縮至可用高並捲動 |
| `kMinWindowSize` 下的行為 | 維持。覆蓋層最大高 = 3 × `Space.xs` + 9 × `LayoutSize.hitTargetMin` = 264（不隨字型：只由 token 組成）；觸發器上下兩側中較大者 ≥ (640 − `LayoutSize.titleBarHeight` 36 − 28) / 2 = 288 ≥ 264，選較大一側展開即放得下；D4 先試向下，向下不足且向上較大時改向上 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 觸發器與選項 `label`、outOfDomain 原值 | 否 | 1 | 截斷 | `TestCopy.domainName`；`TestCopy.longToken` |
| 過濾輸入（可編輯） | 否 | 1 | 不截斷：隨游標水平捲動 | `TestCopy.longToken` |
| 無符合項文字 | 否 | 1 | 截斷 | `referencePickerNoMatch`（en「No matching items」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `options` | `List<ReferenceOption{value, label}>`，0..N（無上限） | 是 | 呼叫端（識別值原文，資料值不進 i18n） |
| `selected` | `String?` | 是 | 不適用 |
| `allowEmpty` | `bool` | 否（預設 `false`）。1.0 使用處：PROP target_version 傳 `true`，SPEC domain 傳 `false`（用戶裁定 2026-11-11，`1.0.0-W3-686`）。選取首項時 `onChanged(null)`，呼叫端寫入 `null`：清空的寫法與改寫隔離判定見 SPEC-009 FR-03〈清空〉 | 不適用 |
| `locked` | `bool` | 否（預設 `false`；4.44〈值格鎖定〉） | 不適用 |
| `onChanged` | `ValueChanged<String?>` | 是（`allowEmpty` 時可傳 `null`） | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端 |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `testKey` | `Key` | 是（觸發器 `action-nodeDetail-field-<fieldKey>`；過濾框 `action-nodeDetail-field-<fieldKey>-filter`、選單 `menu-nodeDetail-field-<fieldKey>`、選項 `option-nodeDetail-field-<fieldKey>-<value>` 由元件推導；4.44〈錨點〉） | 不適用 |

過濾規則：對 `value` 與 `label` 做不分大小寫的子字串比對，順序保持 `options` 原序。

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border`、`accent`（過濾框焦點框）、`surfaceIconTint`（走選項高亮，同 §4.0.10 高亮 token）、`textPrimary`、`textSecondary`、`textDisabled`（箭頭，純裝飾） |
| 間距 | 觸發器內距 `Space.sm` × `Space.xs`；覆蓋層內距 `Space.xs` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 動畫 | `Motion.feedback`；`Motion.overlay` |
| 尺寸 | `LayoutSize.hitTargetMin`、`iconMd` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 空值文字 | `fieldEmptyValue` |
| 過濾框 placeholder | `searchPlaceholder`（沿用 4.12 既有 key） |
| 無符合項 | `referencePickerNoMatch`（§4.0.6 1.140 新增） |
| 朗讀標籤 | `dropdownA11yLabel` |
| outOfDomain 提示 | `fieldValueOutOfDomain` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 觸發器 `Semantics.button`，label `dropdownA11yLabel`，`expanded` 隨開合；過濾框 `Semantics.textField`，label `searchPlaceholder`；選項 `role` 為 `menuItem`，目前值 `selected` 為 `true` |
| 狀態變化播報 | 過濾後清單筆數不另播報（清單本身可走訪）；無符合項時 `referencePickerNoMatch` 為 live region |
| 非視覺替代訊號 | 走選項高亮以焦點語意（active descendant）承載，非只靠底色 |
| 焦點順序與操作路徑（桌機） | 觸發器進入 Tab 順序（disabled、locked 除外；locked 時已持有的焦點保留）；展開後焦點在過濾框，↑／↓ 走選項，Enter 選取，Esc 收合回觸發器；Tab 收合並離開；欄位間 Tab 順序見 4.50 無障礙 |
| 對比 | 依 §4.0.2：`textPrimary` / `surfaceBase` 5.79:1、`textPrimary` / `surfaceIconTint` 4.89:1、`textSecondary` / `surfaceBase` 4.71:1，通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染 empty / set / outOfDomain / open / open 無符合項 / locked / disabled
- [ ] 選取新值後傳 `locked: true`：觸發器仍顯示原值、焦點在觸發器
- [ ] 兩種視窗尺寸下不溢位；選項 20 筆時清單區捲動、覆蓋層在視窗內
- [ ] 最長測試文案截斷
- [ ] 輸入過濾字串後清單只剩符合項且順序不變；對照：清空過濾字串後恢復全部
- [ ] 選取且值改變呼叫 `onChanged` 恰一次；對照：選取目前值不呼叫；`allowEmpty` 為 `true` 時首項存在且傳 `null`，為 `false` 時首項不存在；`allowEmpty` 為 `true` 時輸入不命中任何選項的過濾字串，首項仍在首列
- [ ] 展開時焦點在過濾框；Esc 收合後焦點回觸發器
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 列舉值 | `AppDropdown` |
| 跳轉到被引用的節點 | `RelationItem` |
| 清單搜尋 | `SearchField` |

### 4.47 AppRadioGroup

**實作類別**：`AppRadioGroup`（以 Material `Radio` 為內部實作；頁面層禁直用 `Radio` / `RadioListTile`，§6）。

**用途**：表單欄位的分類值選擇（SPEC-009 FR-09「分類（互斥、值域小且固定、需並列比較）：單選鈕組」）。1.0 使用處：SPEC has_functional_requirements（是／否）、EVT category；UC platform、extension_status、runtime_surface 於值域補上後改用本元件。
**新增元件而非沿用既有元件的理由**：4.10 `SegmentedControl`——SPEC-009 FR-09 約束已裁定不借用（`1.0.0-W1-104` WRAP 的 P）：它是檢視模式與期間的常駐切換，選取為本地即時；本元件的選取觸發寫入，受 FR-05 三時刻與「不允許樂觀更新」約束，借用會讓同一元件承載兩種提交語意。4.43 `AppCheckbox`——布林單值單一 label，FR-09 指定是／否以兩個可讀選項呈現。4.40 `ListRow.option`——清單中的導覽式選取（選 UC），選項數隨資料增減，不是欄位值。
**內容角色**：標籤（每個選項一個 label slot）。
**何時不用**：檢視模式切換（`SegmentedControl`）；單一布林篩選（`AppCheckbox`）；有序等級或文件節點生命週期的列舉（`AppDropdown`，SPEC-009 FR-09 等級、生命週期列；依欄位功能判斷，不依選項數）；引用（`ReferencePicker`）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6 三個編輯狀態），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體；選項恆垂直堆疊（用戶裁定 2026-11-11，`1.0.0-W3-675`） | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| none | 全部選項未選（外圈 `textSecondary`） | 選取任一項 | `selected` 為 `null` | 選取 → 呼叫 `onChanged`，呼叫端傳 `locked: true` → locked；`written` 後呼叫端改傳 `selected` → set | —（`selected` 由呼叫端傳入已落檔值，元件不 watch，§2） | 等確認才顯示 |
| set | 目前值選項為選中（外圈與內點 `accent`），其餘未選 | 選取另一項 | `selected` 在 `options` 內 | 同 none | — | 等確認才顯示 |
| outOfDomain | 全部選項未選；`FieldBlock` 提示格 `fieldValueOutOfDomain`（用戶裁定 2026-11-11，`1.0.0-W3-675`） | 選取任一項 | `selected` 非 `null` 且不在 `options` 內 | 同 none | — | 等確認才顯示 |
| locked | 外觀同 disabled；選中標示維持原值（不移到剛選的項，不允許樂觀更新）；焦點留在剛操作的選項 | 無 | `locked` 為 `true`（寫入進行中，4.44〈值格鎖定〉） | `locked` 改為 `false` → 依 `selected` 回 none／set／outOfDomain（焦點保留） | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled（選項外圈與 label 改 `textDisabled`） | 無 | `enabled` 為 `false`（外部已改阻擋，4.44〈值格鎖定〉） | 放棄並重讀成功 → 以新 key 重建；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| hover（僅指標形態） | 依 §4.0.1（命中區為單一選項的圓鈕 + label） | 選取 | 指標進入 | 指標離開 | 互動瞬態 | 本地即時 |
| pressed | 依 §4.0.1 | 選取 | 按下 | 放開 | 互動瞬態 | 本地即時 |
| focused | 依 §4.0.1（焦點環在單一選項） | ↑／↓ 移動、Space 選取 | 取得焦點 | 焦點移走 | 互動瞬態 | 本地即時 |

不允許樂觀更新：點選後選中標示不立即移動，等呼叫端依寫入結果改傳 `selected`（§2）。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——選取改變欄位值 |
| 2 | 套用時點 | 同 4.45：(a)–(e) 皆不成立 → 立即提交（用戶裁定，`1.0.0-W3-675`），提交點為 Space 或點選使選中值改變 |
| 3 | 容器何時關閉 | 無可關閉的容器——常駐於 `FieldBlock` 值格 |
| 4 | 生效是否當下可見 | 同 4.45：有——受理為 `written` 後顯示新值；受理前維持原值 |

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 單一選項 hover 態（§4.0.1）；指標形狀 `SystemMouseCursors.click` | 無（Material 內建） | 無 | §1 子表「可互動提示」列 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 全組一個 Tab 停留點：進入時焦點在選中項（none／outOfDomain 時為首項）；↑／↓ 移動焦點**不選取**（用戶裁定 2026-11-11，`1.0.0-W3-675`；偏離 WAI-ARIA radio group「焦點即選取」，理由：每次選取即寫入）；Space 選取 | 無 | 無 | §1 子表「焦點」列 | 原狀態 → focused → 原狀態 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 選項 pressed + ripple；選取值與 `selected` 不同時 `onChanged(value)` 恰一次；掛載點為本元件第一層 | Material 內建 ripple | `Motion.feedback` 內 | §1 子表「按下確認」列 | 原狀態 → pressed → 原狀態（選中標示待 `selected` 改傳） | 規格撰寫者 |
| 定位提示 locate | 系統 | 不移動焦點：寫入結果與驗證結果回來時焦點維持在剛操作的選項（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） | 無 | 無 | §1 子表「定位提示」列 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（`written` 後改傳 `selected`） | 選中標示離散移動、無動畫；`checked` 旗標改變由輔助技術播報 | 無 | 無 | §1 子表「狀態變更提示」列 | none / set / outOfDomain →（選取）→ locked →（`written`）→ set；locked →（被拒、讀寫失敗）→ 原狀態 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為本元件；第二層為 `FieldBlock` writing（本元件 locked）；第三層為 `FieldBlock` 的寫入結果與驗證狀態，四段結局見 4.48 | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（每個選項的圓鈕與 label 共用一個命中區）；鍵盤 ↑／↓ 移動焦點、Space 選取（用戶裁定，`1.0.0-W3-675`） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高 = N × 選項高 + (N − 1) × `Space.xxs` |
| 選項尺寸 | 高 `LayoutSize.hitTargetMin`；寬 = `Space.xs` + `LayoutSize.iconLg`（圓鈕）+ `Space.xs` + label 寬 + `Space.xs` |
| 最小尺寸 | 寬：`Space.xs` + `LayoutSize.iconLg` + `Space.xs` + 4 字元（`AppFontSize.body`）+ `Space.xs`（label 截斷）；高：2 × `LayoutSize.hitTargetMin` + `Space.xxs`（N 下限 2） |
| 最小命中區 | `LayoutSize.hitTargetMin`（每個選項） |
| 最大尺寸 | 寬：父格位寬；高：無上限（N 不設上限，高 = N × `LayoutSize.hitTargetMin` + (N − 1) × `Space.xxs`；主軸由 `FieldBlock` 的父格位捲動承接，5.17） |
| `kMinWindowSize` 下的行為 | 維持（主軸高由 `FieldBlock` 父格位捲動承接，5.17） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `options[i].label` | 否 | 1 | 截斷 | `TestCopy.status`；`TestCopy.longToken`；has_functional_requirements 的兩選項取 `radioYes`／`radioNo`（en「Yes」／「No」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `options` | `List<RadioOption{value, label}>`，2..N 項（下限 2：互斥選擇至少兩個選項；不設上限，選用本元件與否依 SPEC-009 FR-09 的欄位功能，不依選項數；用戶裁定 2026-11-11，`1.0.0-W3-553.6`） | 是 | 呼叫端（值域原值；布林欄位的是／否取 `radioYes`／`radioNo`） |
| `selected` | `String?` | 是 | 不適用 |
| `onChanged` | `ValueChanged<String>` | 是 | 不適用 |
| `semanticLabel` | `String`（群組名） | 是 | 呼叫端（與 `FieldBlock` label 同一字串） |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `locked` | `bool` | 否（預設 `false`；4.44〈值格鎖定〉） | 不適用 |
| `testKey` | `Key` | 是（群組根節點不另設錨點，由 `FieldBlock` 根 `card-nodeDetail-field-<fieldKey>` 承載；選項 `option-nodeDetail-field-<fieldKey>-<value>` 由元件推導；4.44〈錨點〉。原提案的 `group-` 不是 SPEC-003 §2.9 的類別，不採用） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textSecondary`（未選外圈）、`accent`（選中）、`textPrimary`（label）、`textDisabled`（disabled） |
| 間距 | 選項內距 `Space.xs`；圓鈕與 label 間 `Space.xs`；選項間 `Space.xxs` |
| 字體 | `AppFontSize.body` |
| 動畫 | `Motion.feedback` |
| 尺寸 | `LayoutSize.iconLg`（圓鈕）、`LayoutSize.hitTargetMin` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 布林欄位選項 | `radioYes` / `radioNo`（§4.0.6 1.140 新增） |
| outOfDomain 提示 | `fieldValueOutOfDomain` |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊；選項內圓鈕與 label 垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 群組 `Semantics` label 為 `semanticLabel`；每個選項 `inMutuallyExclusiveGroup` 為 `true`、`checked` 對應是否選中、label 為選項文字；圓鈕與 label 合併為單一語意節點 |
| 狀態變化播報 | `checked` 旗標改變由輔助技術播報 |
| 非視覺替代訊號 | 選中以內點、外圈色與 `checked` 旗標三者承載 |
| 焦點順序與操作路徑（桌機） | 全組一個 Tab 停留點（disabled、locked 除外；locked 時已持有的焦點保留）；↑／↓ 移動、Space 選取（用戶裁定，`1.0.0-W3-675`）；欄位間 Tab 順序見 4.50 無障礙 |
| 對比 | 依 §4.0.2：label `textPrimary` / `surfaceBase` 5.79:1；選中 `accent` / `surfaceBase` 5.84:1；未選外圈 `textSecondary` / `surfaceBase` 4.71:1（非文字 3:1），皆通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染 none / set / outOfDomain / locked / disabled，選項 2 與 12 各一次（12 項時垂直延伸、不溢位）
- [ ] Space 選取新值後傳 `locked: true`：選中標示仍在原值、焦點在剛操作的選項
- [ ] 兩種視窗尺寸下不溢位；選項高等於 `LayoutSize.hitTargetMin`
- [ ] 最長測試文案截斷
- [ ] 點選非選中項呼叫 `onChanged` 恰一次；對照：點選目前選中項不呼叫；點選後選中標示在 `selected` 改傳前不移動
- [ ] ↑／↓ 只移動焦點、不呼叫 `onChanged`；Space 呼叫一次
- [ ] `Semantics` 的 `checked` 與 `selected` 一致，`inMutuallyExclusiveGroup` 為 `true`
- [ ] 顏色、間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 檢視模式切換 | `SegmentedControl` |
| 有序等級、文件節點生命週期（SPEC-009 FR-09） | `AppDropdown` |
| 單一布林篩選 | `AppCheckbox` |

### 4.48 FieldBlock（容器）

**實作類別**：`FieldBlock`（頁面層禁直用 `FormField` / `TextFormField` / `InputDecorator` 自組欄位，§6）。

**用途**：一個文件欄位的承載：label + 值格 + 提示或錯誤文字的垂直堆疊；值格依欄位放輸入元件或唯讀值。寫入的三個可觀測時刻（SPEC-009 FR-05：發出、受理、結果）與驗證狀態在本容器呈現，輸入元件只承載輸入層。
**內容角色**：標籤（欄位 label）+ 數值（值格）+ 內文（提示或錯誤）。
**何時不用**：非編輯畫面的欄位顯示（節點詳情的 meta 列用 `ListRow.meta`）；篩選列（`Toolbar`）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6「編輯中」「外部已改預警」「外部已改阻擋」），為 `FieldList`（4.50）的子件。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `editable` | 值格放 `AppTextInput` / `AppDropdown` / `ReferencePicker` / `AppRadioGroup` / `ReferenceChips` / `AppCheckboxGroup` 之一（後兩者 1.148） | 呈現寫入結果與驗證狀態 | FR-09「自」不晚於目前版本的欄位（1.0 起；1.1 加入 FR-09「自」為 1.1 的欄位） |
| `readOnly` | 值格放 `AppText`（`body`；ID、路徑、日期用 `mono`） | 無寫入 | FR-09 標唯讀或「自」晚於目前版本的欄位 |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| idle | label + 值格；提示格不渲染，outOfDomain 時渲染 `fieldValueOutOfDomain`（用戶裁定 2026-11-11，`1.0.0-W3-675`） | 依值格 | 本欄沒有寫入過，或最近一次寫入的提示已被下一個狀態取代 | 值格提交 → writing；草稿與值不同 → 未送出 | 資料態：Edit domain 的編輯狀態（該欄最近一次 `WriteResult` 與 `ValidationStatus`），經 `FieldList` 傳入，本容器不 watch（§2） | 等確認才顯示 |
| 未送出 | 提示格 `fieldDraftUnsentHint`（`multiLine` 值格用 `fieldDraftUnsentHintMultiLine`），一般色 | 依值格（送出、Esc 還原） | 值格回報 `onDirtyChanged(true)`（4.44；只有 `AppTextInput` 有草稿） | 送出 → writing；Esc 或草稿改回與值相同 → 回原狀態；草稿捨棄時點見 4.44〈草稿捨棄〉 | 互動瞬態（草稿屬值格元件） | 本地即時 |
| writing | 提示格 `fieldWriteInProgress`；值格 locked（顯示送出前的值，不做樂觀更新） | 無（全部值格唯讀鎖定，4.50） | 值格提交、寫入發出（SPEC-009 FR-05 發出時刻） | 受理 → written · 驗證中／寫入失敗；`blocked(externallyModified)` → 回 idle（該欄提示格不承載，由 4.50 橫幅承載），未送出的草稿保留 | 資料態：同 idle（寫入進行中旗標與送出中的欄位鍵） | 等確認才顯示 |
| written · 驗證中 | 值格顯示新值（受理的值）；提示格 `validationRunning`，有快照時另接 `fieldSeeWriteLogHint` | 依值格 | `WriteResult.written` 且 `ValidationStatus.running` | → 驗證通過／驗證失敗／驗證不可用；下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| written · 驗證通過 | 提示格 `validationPassed`，有快照時另接 `fieldSeeWriteLogHint` | 依值格 | `ValidationStatus.passed` | 下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| written · 驗證失敗 | 提示格 `validationFailed`（代入新增問題數），錯誤色（`isError`）；有快照時另接 `fieldSeeWriteLogHint`。檔案不自動回滾（SPEC-009 FR-05），取回方式在寫入清單（SPEC-001 §6〈只有檔案層級的結果成列〉） | 依值格 | `ValidationStatus.failed` | 下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| written · 驗證不可用 | 提示格 `validationUnavailable` 加原因（五種原因 key 之一），一般色；有快照時另接 `fieldSeeWriteLogHint` | 依值格 | `ValidationStatus.unavailable` | 下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| 寫入失敗 | 提示格錯誤色（`isError`），依結果 `fieldBlockedSnapshotFailed`、`fieldBlockedRewriteNotIsolated`（含改用外部編輯器）、`fieldIoFailed`；值格 `hasError`，值不變（檔案未改），草稿保留 | 依值格（重送、調整值、Esc） | `WriteResult.blocked(snapshotFailed)`、`blocked(rewriteNotIsolated)`、`ioFailed`（SPEC-003 §2.14 列 24） | 下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| 部分寫入（1.1） | 提示格依觸發原因取文案（代入未還原的檔數）：`ioFailed` 為 `fieldPartiallyWritten`（再送一次即可補齊）；`blocked(externallyModified)` 為 `fieldPartiallyWrittenReloadFirst`（放棄並重讀後再送一次），理由是此時各值格 disabled、無法直接重送（4.50）。錯誤色（`isError`），另接 `fieldSeeWriteLogHint`；值格 `hasError`，值不變（正向檔未落檔，SPEC-009 FR-03〈`rename` 順序〉）；觸發原因為 `blocked(externallyModified)` 時，另由 4.50 頂端橫幅進入外部已改阻擋 | 依值格（重送同一修正、調整值、Esc）。重送同一修正即可補齊：已落檔的反向檔與改寫後的值一致，不列入寫入集合，只剩正向檔一個檔（SPEC-009 FR-03〈寫入集合〉） | `WriteResult.partiallyWritten`（SPEC-009 FR-05；只發生於多檔寫入，值格為 4.52 `ReferenceChips` 的 `source_proposal`） | 下一次提交 → writing | 資料態：同 idle | 等確認才顯示 |
| 必填空白 | 提示格 `fieldRequiredEmpty`，錯誤色（`isError`）；值格不進 error（沒有發出寫入），值不變，草稿保留 | 依值格（調整值、Esc） | 必填欄位送出的草稿 trim 後為空，呼叫端不發出寫入（SPEC-009 FR-09〈可否清空〉，`1.0.0-W3-686`） | 草稿改為非空並送出 → writing；Esc 或草稿改回與值相同 → 回原狀態 | 互動瞬態（呼叫端判定，不經 Edit domain） | 本地即時 |
| readOnly | label + `AppText` 值；提示格 `fieldNotEditableHint` | 無 | `readOnly` 變體（SPEC-009 FR-09 標唯讀或「自」晚於目前版本的欄位） | 不適用（變體由欄位決定，不轉換） | — | 本地即時 |

提示格同一時間只顯示一則訊息，多個條件同時成立時依此優先序取第一個：writing > 部分寫入（1.1）> 寫入失敗 > 必填空白 > 未送出 > written 各態 > outOfDomain。值格為 `ReferenceChips` 時的 `fieldReferenceNotFound`、為 `AppCheckboxGroup` 時的 `checkboxGroupNoOptions` 與 outOfDomain 同級（同一值格不會同時出現兩者）（1.148）。理由：越前面的越需要使用者當下處理；被蓋掉的寫入與驗證結果仍在寫入清單（SPEC-001 §12）。

容器自身無互動瞬態，hover／pressed／focused 由值格元件承載。外部已改阻擋時各欄值格 disabled（4.50 下發），提示格維持阻擋前的內容。

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由值格元件承載 | — | — | 由值格承載 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 由值格元件承載；label 與提示格經語意關聯朗讀（無障礙） | — | — | 由值格承載 | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由值格元件承載（第一層） | — | — | 由值格承載 | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 不移動焦點：寫入結果與驗證結果回來時焦點維持原處（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） | 無 | 無 | §1 子表「定位提示」列 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（編輯狀態改變） | 提示格內容靜態替換、不做動畫（SPEC-003 §3.6〈動畫提示〉）；提示格以 `Semantics(liveRegion: true)` 包裝，內容改變時播報（題 2：結果以文字與播報承載，不移焦點） | 無 | 無 | §1 子表「狀態變更提示」列 | idle／未送出 → writing → written · 驗證中 → 通過／失敗／不可用；writing → 寫入失敗；writing → idle（`externallyModified`）；未送出 → 必填空白（送出空白，不發出寫入）→ writing／原狀態（1.146）；writing → 部分寫入 → writing（1.1） | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為值格元件；第二層為本容器 writing（提示格 `fieldWriteInProgress`，全部值格 locked）；第三層為本容器 written · 驗證四態與寫入失敗，`blocked(externallyModified)` 例外由 4.50 頂端橫幅承載。輸入阻擋範圍：寫入進行中鎖定全部值格（4.50）；重複觸發防護即此鎖定。四段結局與呈現：成功 = `written` 後驗證 `passed`；失敗 = `blocked`、`ioFailed`、驗證 `failed`，以及 1.1 多檔寫入的 `partiallyWritten`（本容器「部分寫入」列；正向檔未落檔，不跑驗證）；逾時 = 寫入不另設逾時結局：`git` 子行程逾時 5 秒，`git show` 逾時視同 H 無法判定走快照分支、`hash-object` 逾時歸 `blocked(snapshotFailed)`，即落入上述「失敗」；本地檔案 IO 不設逾時（SPEC-009 FR-01，用戶裁定 2026-11-11，`1.0.0-W3-676`）。驗證子行程逾時 30 秒，結局為驗證 `unavailable(timedOut)`，即落入下述「服務不可用」（SPEC-009 FR-05）；服務不可用 = 驗證 `unavailable`（`uv` 或 doc CLI 不可執行）。四段的呈現皆為本容器提示格的文字（見狀態矩陣），不顯示進度指示；結果同時記入寫入清單（SPEC-001 §12），全程不送出暫態提示（SPEC-003 §2.14 列 23–25） | 無（提示格靜態替換） | 寫入：`git` 子行程 5 秒（SPEC-009 FR-01），受理延遲依 SPEC-009 NFR-01；驗證：子行程 30 秒（SPEC-009 FR-05） | §1 子表「等待與結果」列 | 同上 | 規格撰寫者（逾時段依 `1.0.0-W3-676`；呈現依 `1.0.0-W3-553.3.1`） |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動（值格元件依 4.44–4.47 各自的操作機制） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高隨子件（主軸無界） |
| 最小尺寸 | 寬：子件最小寬的最大值（5.17 交叉軸代入）；高：label 一行 + `Space.xs` + 值格最小高 |
| 最小命中區 | 不適用於容器本身（由值格元件承載） |
| 最大尺寸 | 寬：父格位寬；高：無上限（父格位須可垂直捲動） |
| `kMinWindowSize` 下的行為 | 維持（5.17） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `label` | 否 | 1 | 截斷（完整文字由朗讀承載） | `TestCopy.longZh`；`TestCopy.longEn` |
| 唯讀值（`readOnly` 值格） | 是 | 3 | 末行截斷 | `TestCopy.nodeTitle`；`TestCopy.filePath`（`mono`） |
| 提示或錯誤文字 | 是 | 3 | 末行截斷（完整文字由朗讀承載） | `fieldValueOutOfDomain`（代入 `TestCopy.longToken`）；`fieldBlockedRewriteNotIsolated` 與 `validationUnavailableExecutableMissing` 接 `fieldSeeWriteLogHint`（zh、en 中較長者）；`fieldDraftUnsentHintMultiLine` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `label` | `String` | 是 | 呼叫端：frontmatter 鍵名字面值（如 `title`、`target_version`），為資料值不進 i18n。理由：1.0 的欄位清單依節點型別而定（SPEC-009 FR-09），鍵名即使用者在檔案中看到的名稱，翻成顯示名會讓畫面與檔案對不上；顯示名若日後需要，另案登記 |
| `value`（值格） | `editable`：`AppTextInput` / `AppDropdown` / `ReferencePicker` / `AppRadioGroup` 之一；`readOnly`：`AppText` | 是（恰 1） | 依值格元件 |
| `supportingText` | `String?` | 否 | 呼叫端（i18n key 取值） |
| `isError` | `bool` | 否（預設 `false`；`true` 時提示格以錯誤色呈現） | 不適用 |
| `writeState` | `FieldWriteState?`：寫入中 \| `WriteResult` 加（`written` 時）`ValidationStatus` 與 `hasSnapshot` | 否（`null` 表示本欄沒有寫入過，即 idle） | 資料來源：Edit domain 的編輯狀態中該欄最近一次寫入（SPEC-009 FR-05 的 `WriteResult`、`ValidationStatus`），已判定完成；本容器依值取 i18n key，不自行判定寫入結果 |
| `locked` | `bool` | 否（預設 `false`；由 4.50 下發，轉傳給值格） | 不適用 |
| `isDirty` | `bool` | 否（預設 `false`；值格 `onDirtyChanged` 回報，由本容器自行持有） | 不適用 |
| `testKey` | `Key` | 是（`card-nodeDetail-field-<fieldKey>`，SPEC-003 §2.9；內部錨點見 4.44〈錨點〉） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.textSecondary`（label、提示）、`error`（錯誤文字）、`textPrimary`（唯讀值） |
| 間距 | 子件間 `Space.xs` |
| 字體 | `AppFontSize.body`（label、值）、`caption`（提示） |
| 動畫 | 無（提示格靜態替換，SPEC-003 §3.6〈動畫提示〉） |

#### i18n

| 文字 | i18n key |
|------|---------|
| outOfDomain 提示 | `fieldValueOutOfDomain` |
| 欄位 label | 不進 i18n（見 slot 契約 `label` 列） |
| 未送出 | `fieldDraftUnsentHint`、`fieldDraftUnsentHintMultiLine` |
| 寫入中、寫入失敗 | `fieldWriteInProgress`、`fieldBlockedSnapshotFailed`、`fieldBlockedRewriteNotIsolated`、`fieldIoFailed` |
| 必填空白 | `fieldRequiredEmpty` |
| 部分寫入（1.1） | `fieldPartiallyWritten`（觸發原因 `ioFailed`）、`fieldPartiallyWrittenReloadFirst`（觸發原因 `externallyModified`），皆接 `fieldSeeWriteLogHint` |
| 驗證狀態 | `validationRunning`、`validationPassed`、`validationFailed`、`validationUnavailable` + 五種原因（`validationUnavailable*`）；有快照時接 `fieldSeeWriteLogHint` |
| 唯讀欄位 | `fieldNotEditableHint` |

以上 1.143 登記，§4.0.6。驗證狀態的 key 與寫入清單（4.51）共用，同一個結果在兩處說法一致。

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldList`（4.50，1.143 定案；原提案 `Panel.scrollable` 不採用，理由見 4.50 存在必要性：寫入期間的跨欄鎖定須由容器承載）。4.30 子件清單不需修改 |
| 不得放置的區域 | 依 §4.0.8；父格位不可垂直捲動者不得放（主軸無界） |
| 對齊基準 | 子件起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 值格元件的 `semanticLabel` 等於 `label`；提示或錯誤文字以 `Semantics` hint 關聯至值格，焦點進入值格時一併朗讀 |
| 狀態變化播報 | 提示格以 `Semantics(liveRegion: true)` 包裝，寫入中、寫入結果、驗證狀態、未送出提示改變時播報；不移動焦點（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） |
| 非視覺替代訊號 | 錯誤以文字呈現，錯誤色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 容器不是停留點；值格元件為停留點；`readOnly` 的唯讀值不進 Tab 順序 |
| 對比 | 依 §4.0.2：label `textSecondary` / `surfaceBase` 4.71:1、錯誤 `error` / `surfaceBase` 通過；父格位底色若非 `surfaceBase`，依帶色表面規則改 `textPrimary` |

#### 測試點（widget test）

- [ ] 一支測試渲染 `editable`（四種值格各一）與 `readOnly`，提示格有／無、`isError` 真／假
- [ ] 兩種視窗尺寸、5.17 交叉軸最小格位下不溢位
- [ ] label 最長文案截斷、唯讀值與提示超過 3 行末行截斷
- [ ] 值格元件的語意節點含 label 與提示文字
- [ ] 狀態矩陣各列的提示格文字與 `isError` 各一（未送出、必填空白、writing、written × 驗證四態含有無快照、寫入失敗三種、readOnly）
- [ ] 提示格優先序：writing 與未送出同時成立時顯示 writing；寫入失敗與未送出同時成立時顯示寫入失敗；必填空白與未送出同時成立時顯示必填空白（1.146）
- [ ] 必填空白：提示格為 `fieldRequiredEmpty` 且 `isError` 為 `true`，值格未進 error、值不變；對照：草稿改為非空並送出後提示格改為 `fieldWriteInProgress`（1.146）
- [ ] 部分寫入（1.1）：提示格為 `fieldPartiallyWritten` 接 `fieldSeeWriteLogHint` 且 `isError` 為 `true`，值格 `hasError`、值不變；與未送出、寫入失敗同時成立時顯示部分寫入；觸發原因為 `externallyModified` 時提示格仍顯示部分寫入，文案為 `fieldPartiallyWrittenReloadFirst`；對照：觸發原因為 `ioFailed` 時文案為 `fieldPartiallyWritten`，兩者不同；單檔的 `externallyModified` 提示格不顯示，見下一條
- [ ] 提示格節點 `liveRegion` 為 `true`；提示改變時焦點節點不變
- [ ] `blocked(externallyModified)` 時本容器提示格不顯示該結果（由 4.50 橫幅承載）；對照：`snapshotFailed` 時提示格顯示 `fieldBlockedSnapshotFailed`
- [ ] 顏色、間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 節點詳情的唯讀 meta 列 | `ListRow.meta` |
| 多欄位並排 | 本容器只承載一個欄位；並排需求回規格裁定 |

### 4.49 NoticeBanner

> **1.143 新增（`1.0.0-W3-553.3.1`，依 SPEC-001 §6〈編輯模式〉、SPEC-003 §2.14 列 23、§3.6）。** 存在必要性：既有元件中，`BlockedState`（4.23）承載整個畫面的阻擋並取代內容區，`EmptyState`（4.21）承載無內容的畫面，`AppSnackBar`（4.26）是暫態提示且 SPEC-003 §2.14 列 23 明定寫入被拒不得用它。三者都不能在保留下方內容的同時，常駐說明一件「影響整個區塊、需要使用者決定」的事。新增本元件，理由是行為差異：常駐、不取代內容、附一個決策動作。

**實作類別**：`NoticeBanner`（頁面層禁直用 `MaterialBanner`，§6）。

**用途**：區塊頂端的常駐說明列：一則訊息加 0..1 個動作，說明區塊目前所處的狀況與出口。1.0 唯一的使用處是 FieldList 頂端（4.50）的編輯區橫幅，錨點 `panel-nodeDetail-edit-banner`。
**內容角色**：內文（訊息）+ 動作（0..1 個 `AppButton`）。
**何時不用**：暫態結果通知（`AppSnackBar`）；整個畫面不可用（`BlockedState`／`EmptyState`）；單一欄位的錯誤（`FieldBlock` 提示格）；跨畫面常駐的旗標（返回列徽章，4.27）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6「外部已改預警」「外部已改阻擋」兩列，及兩列內的重讀讀取失敗）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `warning` | 底 `AppColors.warningSurface`、訊息 `textPrimary`、leading `AppIcon` 警示（`warning` 色） | 無：區塊內其他操作照常可用 | 區塊仍可操作、但使用者應知悉的狀況：外部已改預警（`editBannerExternallyModifiedWarning`） |
| `negative` | 底 `AppColors.errorSurface`、訊息 `textPrimary`、leading `AppIcon` 錯誤（`error` 色） | 無：本元件不鎖定區塊；區塊內哪些操作不可用由所在容器決定（4.50） | 區塊的主要操作已不可用，或剛發生的操作失敗：外部已改阻擋（`editBannerExternallyModifiedBlocked`）、重讀讀取失敗（`editBannerReloadFailed`） |

外觀隨狀況改變，但兩者都只有取色差異、沒有各自的可操作性，依 `component-contract-design` 判別問句應為值對映參數；仍立為變體的理由是 leading 圖示不同（警示與錯誤），且 SPEC-003 §2.14 列 23 與〈明確排除〉的外部已改預警分屬不同注意力級別，變體名直接對應級別，呼叫端不必自行對映。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依變體；訊息 + 動作鈕 | 動作鈕 | 呼叫端渲染 | 呼叫端移除，或換變體與訊息 | —（`variant`、`message` 由呼叫端依編輯狀態傳入，元件不 watch，§2） | 等確認才顯示（訊息只在編輯狀態轉換後改變） |

元件自身無互動瞬態；動作鈕的 hover／pressed／focused／disabled 由 `AppButton`（4.4）承載。

#### 回饋契約

> 六類事件與通道值的來源見 §1〈回饋通道子表〉，本表「回饋通道（桌機）」欄逐列引用不重抄。

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由動作鈕承載（4.4） | — | — | 由 `AppButton` 承載 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 由動作鈕承載；訊息不是停留點 | — | — | 由 `AppButton` 承載 | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由動作鈕承載（第一層） | — | — | 由 `AppButton` 承載 | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 不適用：本元件出現時不移動焦點、不捲動（SPEC-003 §2.14〈明確排除〉外部已改預警：不佔用使用者呈現焦點通道）。橫幅位於 FieldList 頂端，主欄捲動不在頂端時使用者可能看不到，此風險由寫入前閘門承接（送出時仍判為外部已改，SPEC-003 §2.14 列 23） | — | — | 不適用 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（編輯狀態轉換：編輯中 ↔ 預警 ↔ 阻擋；重讀失敗改訊息） | 出現與消失隨 FieldList 的 cross-fade（`Motion.transition`，SPEC-003 §3.6〈動畫提示〉）；同一橫幅內換變體與訊息為離散替換；訊息以 `Semantics.liveRegion` 播報，出現與訊息改變時各播報一次 | `Motion.transition`（出現與消失，由 4.50 承載） | 無 | §1 子表「狀態變更提示」列 | 不存在 → `warning`（預警）；不存在／`warning` → `negative`（阻擋）；`warning`／`negative` → `negative`（重讀失敗，訊息改 `editBannerReloadFailed`）；→ 不存在（重讀成功、完成、退出模式） | 規格撰寫者（不搶焦點、以 `liveRegion` 播報依用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2） |
| 等待與結果 | 系統 | 掛載點：第一層為動作鈕；本元件是外部已改（阻擋為寫入結果 `blocked(externallyModified)`，預警為 EVT-CORPUS-001 的重讀比較）的第三層承載。動作「放棄並重讀」為本地讀檔，屬短暫非同步：不顯示等待指示，讀取期間動作鈕 disabled（重複觸發防護，`reasonShownNearby: true`，原因即本橫幅訊息）；成功 → 本元件消失；`notFound` → 畫面轉原始檔已消失；其他失敗 → 訊息改 `editBannerReloadFailed`、變體 `negative`，動作鈕恢復可用；逾時：本地檔案 IO 不設逾時（SPEC-009 FR-01）；服務不可用：不適用（不經外部程序） | — | 無 | §1 子表「等待與結果」列 | 見 state-change 列 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：本元件自身無互動（動作鈕依 4.4） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高隨訊息行數（主軸無界，父格位須可垂直捲動） |
| 最小尺寸 | 寬：2 × `Space.sm`（自身水平內距）+ `LayoutSize.iconMd` + `Space.sm` + 一字元（§4.0.3，`AppFontSize.body`）；動作鈕在訊息下方另起一列，不計入寬；高：2 × `Space.sm` + 一行 + `Space.sm` + 動作鈕高（`LayoutSize.hitTargetMin`） |
| 最小命中區 | 不適用於本元件（動作鈕依 4.4） |
| 最大尺寸 | 寬：父格位寬；高：訊息最多 4 行 + 動作鈕列 |
| `kMinWindowSize` 下的行為 | 維持（父格位為節點詳情主欄，4.50 交叉軸條件） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| `message` | 是 | 4 | 末行截斷（完整訊息由朗讀承載） | `editBannerExternallyModifiedBlocked`（zh、en 中較長者）；`TestCopy.longZh` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `variant` | `warning` \| `negative` | 是 | 不適用 |
| `message` | `String` | 是 | 呼叫端（i18n key 取值：`editBannerExternallyModifiedWarning`／`editBannerExternallyModifiedBlocked`／`editBannerReloadFailed`）。資料來源：Edit domain 的編輯狀態（外部已改預警、外部已改阻擋、重讀結果），已判定完成；本元件不讀檔、不比對 M |
| `action` | `AppButton?`（限 `secondary`） | 否（0..1；編輯區橫幅恆為「放棄並重讀」`action-nodeDetail-edit-reload`，`editDiscardAndReloadAction`） | 呼叫端 |
| `testKey` | `Key` | 是（編輯區橫幅：`panel-nodeDetail-edit-banner`，SPEC-003 §2.9） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.warningSurface`／`errorSurface`（底）、`warning`／`error`（leading 圖示）、`textPrimary`（訊息） |
| 間距 | 內距 `Space.sm`；圖示與訊息間 `Space.sm`；訊息與動作鈕列間 `Space.sm` |
| 字體 | `AppFontSize.body` |
| 圓角 | `Radius.md` |
| 尺寸 | `LayoutSize.iconMd` |
| 動畫 | 無（出現與消失由 4.50 承載） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 訊息 | 呼叫端傳入（編輯區橫幅三則，1.143 登記，§4.0.6） |
| 動作 | 呼叫端傳入（`editDiscardAndReloadAction`，1.143 登記） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldList`（4.50）的頂端格位，恰 0..1 |
| 不得放置的區域 | 依 §4.0.8；不得放在可捲動區之外固定懸浮（會遮住欄位） |
| 對齊基準 | 起始側對齊；動作鈕起始側對齊於訊息 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 訊息以 `Semantics(liveRegion: true)` 包裝，出現與改變時播報；leading 圖示裝飾性（`semanticLabel` 為 `null`），語意由訊息承載 |
| 狀態變化播報 | 同上；不移動焦點 |
| 非視覺替代訊號 | 底色非唯一訊號：訊息文字本身說明狀況，兩個變體的 leading 圖示形狀不同 |
| 焦點順序與操作路徑（桌機） | 本元件不是停留點；動作鈕為 FieldList 的第一個停留點（4.50 無障礙） |
| 對比 | 訊息 `textPrimary` 置於帶色表面（§4.0.2 帶色表面規則）：`textPrimary` / `warningSurface` 5.17:1、`textPrimary` / `errorSurface` 4.94:1，皆通過（WCAG 相對亮度公式，代入 `lib/tokens/colors.dart` 的 `gray700` #5C6866、`amber100` #FBF1DF、`red100` #FBE9E7；同式代入 `textPrimary` / `surfaceBase` 得 5.79:1，與 §4.0.2 表 1 一致；1.144 回填） |

#### 測試點（widget test）

- [ ] 一支測試渲染兩變體 × 有／無動作鈕，三則編輯區訊息各一
- [ ] 主欄 476 寬（4.50 交叉軸代入）與最小寬下不溢位；`TestCopy.longZh` 超過 4 行末行截斷
- [ ] 訊息節點 `liveRegion` 為 `true`；對照：動作鈕節點不帶 `liveRegion`
- [ ] 本元件出現時焦點所在節點不變
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 寫入成功、開啟外部檔案成功等結果通知 | `AppSnackBar`（SPEC-003 §2.13） |
| 單一欄位的寫入失敗 | `FieldBlock` 提示格（SPEC-003 §2.14 列 24） |
| 工作區唯讀 | 返回列 `badge-<screen>-readonly-workspace`（4.27） |

### 4.50 FieldList（容器）

> **1.143 新增（`1.0.0-W3-553.3.1`，依 SPEC-001 §6〈編輯模式〉、SPEC-003 §3.6）。** 存在必要性：編輯模式的欄位區有一條跨欄位的排列不變式——同一時間至多一個欄位在寫入，寫入期間其他欄位不可送出、「完成」不可用（SPEC-001 §6〈寫入期間不可並行送出〉）。`Section`（4.41）與 `Panel`（4.30）只承載排列，不承載跨子件的鎖定，若用它們，這條不變式會落在每個頁面的呼叫端。新增本容器，理由是行為差異。本容器也是 4.48 `FieldBlock` 原標「提案：`Panel.scrollable`」的父容器定案（§4.0.9 原封鎖項）。

**實作類別**：`FieldList`。

**用途**：節點詳情編輯模式中，分隔線以上的區塊：頂端橫幅（0..1）+ 各欄位的 `FieldBlock`（1..N）+ 「完成」鈕。取代正常狀態分隔線以上的 `ListRow.meta`、`AppText.title`、`BadgeRow` 三者（見下方〈取代範圍〉），錨點 `panel-nodeDetail-field-list`。
**內容角色**：容器。
**何時不用**：非編輯畫面的欄位顯示（`ListRow.meta`）；單一欄位（`FieldBlock` 直接放）。
**出現畫面**：SPEC-001 §6「編輯中」「外部已改預警」「外部已改阻擋」三列。
**層級**：L3

**取代範圍**：FieldList 取代分隔線以上整區（`ListRow.meta`、`AppText.title`、`BadgeRow`，連同「編輯欄位」鈕與讀取失敗說明），對應 SPEC-001 §6〈主欄分隔線上下的內容〉的「frontmatter 欄位的呈現」三項。理由：FieldList 已含每個欄位（標題、狀態皆為欄位），只取代 `ListRow.meta` 會使標題與狀態各出現兩次。SPEC-001 v1.90 與 SPEC-003 v1.95 已同步此寫法（主控審查同意，2026-11-11）。

#### 變體

不適用：單一形態。橫幅的有無與變體由編輯狀態決定，屬狀態矩陣。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| editing | 無橫幅；各欄 `FieldBlock`；「完成」可用 | 各可編輯欄位輸入與送出、完成 | `state-nodeDetail-editing` 且沒有寫入進行中 | 某欄送出 → writing；EVT-CORPUS-001 重讀與 M 不同 → warning；送出得 `blocked(externallyModified)` → blocked | 資料態：Edit domain 的編輯狀態（模式、M、寫入進行中旗標、各欄寫入結果與驗證狀態），組裝層 watch 後傳入，本容器不 watch（§2） | 等確認才顯示 |
| writing | 送出中的欄位提示格顯示 `fieldWriteInProgress`；全部可編輯值格唯讀鎖定（外觀同 disabled、保留焦點、不可輸入與送出）；「完成」disabled（`reasonShownNearby: true`，原因即該欄提示格）；橫幅的「放棄並重讀」disabled（有橫幅時）。按鈕用 disabled 而不是唯讀鎖定，理由是按鈕不承載輸入焦點 | 無（等待受理；用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2 (e)） | 任一欄位送出、寫入發出（SPEC-009 FR-05 發出時刻） | 受理 → editing／warning（依寫入前所處狀態，`written`、`snapshotFailed`、`rewriteNotIsolated`、`ioFailed`）或 blocked（`externallyModified`） | 同上（寫入進行中旗標） | 等確認才顯示 |
| warning | 頂端 `NoticeBanner.warning`（`editBannerExternallyModifiedWarning`）+ 放棄並重讀；欄位同 editing，未送出的值保留 | 同 editing + 放棄並重讀 | `state-nodeDetail-edit-warning` | 放棄並重讀成功 → editing；送出得 `written` → editing；送出得 `blocked(externallyModified)` → blocked；重讀讀取失敗 → 維持，橫幅改 `negative`／`editBannerReloadFailed` | 同上 | 等確認才顯示 |
| blocked | 頂端 `NoticeBanner.negative`（`editBannerExternallyModifiedBlocked`）+ 放棄並重讀；各欄值格不可送出（disabled），未送出的值保留顯示 | 放棄並重讀、完成 | `state-nodeDetail-edit-blocked` | 放棄並重讀成功 → editing；重讀讀取失敗 → 維持，橫幅訊息改 `editBannerReloadFailed` | 同上 | 等確認才顯示 |

「完成」、點關聯、返回、判定順序 1–4 命中時本容器整個消失（SPEC-001 §6）；消失不是本容器的狀態，由頁面層移除。

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由子件承載 | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 由子件承載；容器以 `FocusTraversalGroup` 包住，Tab 順序見無障礙 | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由子件承載 | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 寫入結果與驗證結果回來時不移動焦點，結果由該欄提示格文字與 `liveRegion` 播報承載；橫幅出現時同樣不移動焦點（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2）。進入編輯模式時，「編輯欄位」鈕隨 meta 區一併被取代，焦點移至 Tab 順序的第一個停留點（無橫幅時即第一個可編輯值格）；放棄並重讀成功後同。理由：原焦點節點已不存在，不指定落點焦點會掉回頁面根 | 無 | 無 | §1 子表「定位提示」列 | 正常 → editing（焦點移入）；warning／blocked → editing（放棄並重讀，焦點移入） | 規格撰寫者（依題 2、題 3 裁定推導；進入模式的落點為本條目決定） |
| 狀態變更提示 state-change | 呼叫端（編輯狀態轉換） | 與正常狀態的 meta 區互換、橫幅出現或消失：cross-fade `Motion.transition`，主欄 offset 保留（SPEC-003 §3.6〈動畫提示〉）；writing 的鎖定與解鎖為離散替換 | `Motion.transition` | 無 | §1 子表「狀態變更提示」列 | 見狀態矩陣 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為值格元件；第二層為送出欄位的 `FieldBlock` writing；第三層為該欄 `FieldBlock` 的寫入結果與驗證狀態，`externallyModified` 例外由本容器頂端橫幅承載。本容器承載的是輸入阻擋範圍：寫入進行中阻擋其他欄位送出、完成、放棄並重讀；重複觸發防護即此阻擋（SPEC-001 §6〈寫入期間不可並行送出〉）。四段結局見 4.48 | — | 見 4.48 | §1 子表「等待與結果」列 | editing → writing → editing／warning／blocked | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 不適用：容器自身無互動（子件依 4.4、4.44–4.49） | — | — | — | — |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位（節點詳情主欄 `Panel.scrollable` 內寬）；高隨子件（主軸無界） |
| 最小尺寸 | 寬：子件最小寬的最大值（5.18 交叉軸代入）；高：一個 `FieldBlock` 最小高 + `Space.md` + 「完成」鈕高 |
| 最小命中區 | 不適用於容器本身 |
| 最大尺寸 | 寬：父格位寬；高：無上限（由主欄捲動承接） |
| `kMinWindowSize` 下的行為 | 維持（5.18） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 不適用 | 無自有文字 slot；子件依各自契約 | | | |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `banner` | `NoticeBanner?` | 否（warning、blocked 時存在） | 依 4.49 |
| `fields` | `List<FieldBlock>` | 是（1..N，N 為該節點型別在 SPEC-009 FR-09 中列出的欄位數；排列依 SPEC-009 FR-09 該型別的表列序，每種型別固定，不依目標檔的鍵順序；用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 3） | 依 4.48。每個 `FieldBlock` 的值與寫入結果來自 Edit domain 的編輯狀態（M 中的欄位值，及該欄最近一次寫入的 `WriteResult`、`ValidationStatus`），不是最後完成輪次的節點資料（SPEC-003 §3.6〈生命週期〉：輪次更新不改 FieldList 的值） |
| `doneButton` | `AppButton.primary` | 是（恰 1；`editDoneAction`，`action-nodeDetail-edit-done`） | 呼叫端 |
| `writeInProgress` | `bool` | 是 | 不適用（Edit domain 的寫入進行中旗標） |
| `isBlocked` | `bool` | 是 | 不適用（`state-nodeDetail-edit-blocked` 時為 `true`） |
| `testKey` | `Key` | 是（`panel-nodeDetail-field-list`） | 不適用 |

鎖定由本容器統一下發：`writeInProgress` 為 `true` 時，本容器對全部 `FieldBlock` 傳唯讀鎖定，對 `doneButton` 與橫幅動作傳 `enabled: false`；`isBlocked` 為 `true` 時對全部 `FieldBlock` 傳 disabled。呼叫端不得另行傳入這些鎖定，避免兩處各自判斷。

#### 使用 design token

| 面向 | token |
|------|-------|
| 間距 | 橫幅與第一個欄位間 `Space.md`；欄位間 `Space.md`；最後一個欄位與「完成」鈕間 `Space.md` |
| 動畫 | `Motion.transition`（與 meta 區互換、橫幅出現或消失） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 完成 | `editDoneAction`（1.143 登記，§4.0.6） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | 節點詳情主欄 `Panel.scrollable`（`scroll-nodeDetail-content`），位於 `Divider` 之上、取代〈取代範圍〉所列三者 |
| 不得放置的區域 | 依 §4.0.8；父格位不可垂直捲動者不得放 |
| 對齊基準 | 子件起始側對齊；「完成」鈕起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 容器以 `Semantics(container: true)` 分組，不另加 label |
| 狀態變化播報 | 橫幅由 4.49 播報；欄位寫入結果由 4.48 播報 |
| 非視覺替代訊號 | 由子件承載 |
| 焦點順序與操作路徑（桌機） | 橫幅「放棄並重讀」（有橫幅時）→ 可編輯欄位的值格依排列順序 →「完成」；唯讀值、唯讀鎖定中與 disabled 的值格不停留（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 3）。以 `FocusTraversalGroup` 加 `OrderedTraversalPolicy` 實作，順序與排列順序一致 |
| 對比 | 不適用（容器） |

#### 測試點（widget test）

- [ ] 一支測試渲染 editing、writing、warning、blocked 四態
- [ ] writing：全部值格唯讀鎖定（送出中的欄位保留焦點）、「完成」與「放棄並重讀」disabled；對照：editing 時三者可用
- [ ] blocked：全部值格 disabled 且仍顯示未送出的值；「放棄並重讀」與「完成」可用
- [ ] 主欄 476 寬與 5.18 最小寬下不溢位；欄位數 1 與 FR-09 最多欄位的型別各一
- [ ] Tab 順序：有橫幅時依序為「放棄並重讀」、各可編輯值格（FR-09 表列序）、「完成」；唯讀值格不在序列中；對照：writing 時送出中的欄位不在序列中但仍持有焦點
- [ ] 進入 editing 後焦點在第一個可編輯值格；寫入結果回來後焦點節點不變
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 正常狀態的 frontmatter 呈現 | `ListRow.meta` + `AppText.title` + `BadgeRow` |
| 多個檔案的欄位同時編輯 | 不支援；編輯模式以單一檔案為單位（SPEC-001 §6〈以檔案為單位進出模式〉） |

### 4.51 WriteLogRow（容器）

> **1.143 新增（`1.0.0-W3-553.3.1`，依 SPEC-001 §12〈列的內容〉、SPEC-003 §3.12）。** 存在必要性：相鄰的 `ListRow`（4.40）只有主文字、次文字、trailing 三個文字位置，且整列只有一種點擊行為。本列要承載路徑、欄位名、寫入結果、驗證狀態、取回說明、所屬專案六項，其中路徑可點、取回說明可選取，兩種手勢分屬列內不同區域。併入 `ListRow` 須新增多個只有本變體使用的 slot，並放寬整列點擊的不變式。新增本容器，理由是結構與行為差異。`TableRow`（4.35）的欄寬對齊表頭，而本列的取回說明長度不定、須換行，不適用欄對齊。

**實作類別**：`WriteLogRow`。

**用途**：寫入清單面板的一列，代表本 session 發出過的一次寫入，錨點 `card-writeLog-row-<index>`（`<index>` 為發出順序，自 0 起）。
**內容角色**：容器（數值：路徑、欄位名；標籤：寫入結果、驗證狀態；內文：取回說明）。
**何時不用**：破洞項（`ListRow.item`）；票列（`TableRow.ticket`）。
**出現畫面**：SPEC-001 §12「寫入清單」。
**層級**：L3

#### 變體

不適用：單一形態。哪些子件渲染由列資料決定（見〈子件的渲染條件〉）。

**子件的渲染條件**（SPEC-001 §12〈列的內容〉）：

| 子件 | 渲染條件 | 元件 |
|------|---------|------|
| 路徑 | 恆渲染 | 可點時為 `AppButton.text`（文字 `AppText.mono` 樣式，`action-writeLog-goto-node-<index>`）；不可點時為 `AppText.mono` |
| 欄位名 | 恆渲染 | `AppText.body`（`singleLine`），欄位鍵名字面值 |
| 所屬專案 | 恆渲染 | `AppText.caption`（`writeLogProjectLabel`，代入專案名稱） |
| 寫入結果 | 恆渲染 | `Badge.category` 短標籤：寫入中 tone `neutral`（`fieldWriteInProgress`）、已寫入 `positive`（`writeResultWritten`）、未寫入 `negative`（`writeResultBlocked`，三種 `blocked` 共用）、讀寫失敗 `negative`（`writeResultIoFailed`）、部分寫入 `negative`（`writeResultPartiallyWritten`，1.1） |
| 寫入結果說明 | 寫入結果為 `blocked`、`ioFailed` 或 `partiallyWritten` | `AppText.body`（`multiLine`，`maxLines: null`）：依原因 `writeResultExternallyModified`、`fieldBlockedSnapshotFailed`、`fieldBlockedRewriteNotIsolated`、`fieldIoFailed`。`partiallyWritten` 時先接 `writeLogPartiallyWrittenNote`（代入未還原的檔數），再接觸發失敗的原因（`writeResultExternallyModified` 或 `fieldIoFailed`，SPEC-009 FR-03〈中途失敗的回復〉第 3、4 步）。說明與徽章分開，理由是徽章單行截斷，原因說明（含「改用外部編輯器」）不得被截斷 |
| 同批檔案（1.1） | `batchFiles` 非空：寫入結果為 `written` 的多檔寫入（寫入集合中正向檔以外的檔），或 `partiallyWritten`（已落檔且未還原的檔） | 小標 `AppText.caption`：`written` 時 `writeLogBatchFilesLabel`，`partiallyWritten` 時 `writeLogUnrevertedFilesLabel`；其下每個檔一組：路徑 `AppText.mono`（不可點；可導覽的是正向檔，即列首路徑）+ 取回指令 `AppText.code` + 該檔有快照時接 `writeLogSnapshotExpiryNote`。多檔寫入整批一列（SPEC-009 FR-08〈多檔寫入的列法（1.1）〉） |
| 驗證狀態 | 寫入結果為 `written` | `Badge.category` 短標籤：驗證中 `neutral`（`validationRunning`）、驗證通過 `positive`（`validationPassed`）、發現 N 個新問題 `negative`（`validationFailed`，代入 `count`）、無法驗證 `warning`（`validationUnavailable`） |
| 驗證不可用原因 | 驗證狀態為 `unavailable` | `AppText.body`（`multiLine`，`maxLines: null`）：依原因 `validationUnavailableExecutableMissing`、`validationUnavailableUnexpectedExitCode`、`validationUnavailableUnparsableOutput`、`validationUnavailableTimedOut`、`validationUnavailableBaselineNotReady`（SPEC-009 FR-05 五種原因） |
| 取回說明 | 寫入結果為 `written` | 小標 `AppText.caption`（`writeLogColumnRestore`）之下接 `AppText.code`（4.1）：有快照時 `git cat-file -p <sha> > <路徑>`，無快照時 `git checkout HEAD -- <路徑>`（SPEC-009 FR-02），為資料值，不進 i18n |
| 快照期限說明 | 寫入結果為 `written` 且有快照 | `AppText.caption`（`writeLogSnapshotExpiryNote`） |

路徑可點的條件（SPEC-003 §3.12 列的路徑列）：該列屬目前專案，且路徑可查得對應節點。兩者有一不成立時渲染為不可點的 `AppText.mono`，不渲染錨點。

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| default | 依〈子件的渲染條件〉 | 點路徑（可點時）、選取取回說明 | 建構 | 列資料更新 → 原地重建（受理、驗證完成） | 資料態：Edit domain 的 session 寫入清單（記憶體中，SPEC-009 FR-07、FR-08），頁面層 watch 後傳入列資料，本容器不 watch（§2） | 等確認才顯示（寫入結果在受理後、驗證狀態在驗證完成後才改變） |

列本體無互動瞬態；路徑按鈕與取回說明的瞬態由 4.4、4.1 承載。

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由路徑按鈕（4.4）與取回說明（4.1 `code`）承載；列本體無 hover | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 由子件承載；列內 Tab 順序：路徑（可點時）→ 取回說明 | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 點路徑：由 4.4 承載；結果為面板關閉、節點詳情顯示該節點（SPEC-003 §3.12） | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 定位提示 locate | 系統 | 不適用：新列加在最上方時捲動位置不變（SPEC-003 §3.12〈列的更新〉），不定位 | — | — | 不適用 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（受理、驗證完成） | 寫入結果與驗證狀態徽章離散替換、無動畫；不發暫態提示、不播報（SPEC-003 §2.14 列 25：留痕由本列與側欄徽章承載） | 無 | 無 | §1 子表「狀態變更提示」列 | 寫入中 → 已寫入／被拒／讀寫失敗／部分寫入（1.1）；驗證中 → 通過／發現 N 個新問題／無法驗證 | 規格撰寫者 |
| 等待與結果 | 系統 | 本列是寫入結果與驗證狀態的留痕載體（SPEC-003 §2.14 列 24、25），不是等待的掛載點：寫入中以徽章文字 `fieldWriteInProgress` 表示，不顯示進度指示 | — | — | §1 子表「等待與結果」列 | 同上 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 點路徑（依 §4.0.7）；拖曳選取取回說明後 ⌘C | 字元級（選取） | 足夠 | 鍵盤：Tab 至取回說明後 Shift＋方向鍵選取（4.1 `code`） | 視覺（選取範圍） |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高隨內容（取回說明換行） |
| 最小尺寸 | 寬：5.19 交叉軸代入；高：2 × `Space.sm` + 三行（路徑與欄位名、所屬專案、寫入結果徽章）+ 2 × `Space.xs` |
| 最小命中區 | 路徑按鈕依 4.4 |
| 最大尺寸 | 寬：父格位寬；高：無上限（取回說明不截斷），由面板捲動承接 |
| `kMinWindowSize` 下的行為 | 維持（5.19） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 路徑 | 否 | 1 | 截斷於開頭（保留檔名，完整路徑由朗讀承載） | `TestCopy.filePath` |
| 欄位名 | 否 | 1 | 截斷 | `TestCopy.longToken` |
| 所屬專案 | 否 | 1 | 截斷 | `writeLogProjectLabel` 代入 `TestCopy.longZh` |
| 寫入結果說明 | 是 | 無上限 | 不截斷（原因說明含「改用外部編輯器」，見〈子件的渲染條件〉） | `fieldBlockedRewriteNotIsolated`（zh、en 中較長者）（1.144） |
| 驗證不可用原因 | 是 | 無上限 | 不截斷 | 五種原因 key 中 zh、en 最長者（現為 `validationUnavailableBaselineNotReady` 的 en）（1.151） |
| 取回說明小標 | 否 | 1 | 截斷 | `writeLogColumnRestore`（1.144） |
| 取回說明 | 是 | 無上限 | 不截斷（4.1 `code`） | 有快照的指令代入 `TestCopy.filePath` |
| 快照期限說明 | 是 | 2 | 末行截斷 | `writeLogSnapshotExpiryNote`（zh、en 較長者） |
| 部分寫入說明（1.1） | 是 | 無上限 | 不截斷（同寫入結果說明） | `writeLogPartiallyWrittenNote` 接 `writeResultExternallyModified`（zh、en 中較長者） |
| 同批檔案小標（1.1） | 否 | 1 | 截斷 | `writeLogBatchFilesLabel`、`writeLogUnrevertedFilesLabel`（zh、en 中較長者） |
| 同批檔案路徑（1.1） | 否 | 1 | 截斷於開頭（同列首路徑；檔案為不可點的 `AppText.mono`） | `TestCopy.filePath` |
| 同批檔案取回指令（1.1） | 是 | 無上限 | 不截斷（4.1 `code`） | 有快照的指令代入 `TestCopy.filePath` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `index` | `int` | 是 | 不適用（發出順序，自 0 起） |
| `path` | `String` | 是 | Edit domain 寫入清單的工作區相對路徑（SPEC-009 FR-07：只記識別，不記欄位值）；資料值不進 i18n |
| `fieldKey` | `String` | 是 | 同上，frontmatter 鍵名字面值 |
| `projectName` | `String` | 是 | 同上，寫入發出時的專案名稱；切換專案後不改（SPEC-001 §12〈切換專案〉） |
| `writeResult` | 寫入中 \| `WriteResult`（`written`／`blocked(原因)`／`ioFailed`／`partiallyWritten(觸發原因)`，最後一種 1.1） | 是 | 同上；元件依值取 i18n key。`path`、`fieldKey` 恆為正向檔（使用者編輯的檔） |
| `batchFiles` | `List<WriteLogFile{path, restoreCommand, hasSnapshot}>`，0..N（1.1；寫入集合最多兩個檔，SPEC-009 FR-03〈多值欄位的加入與移除（1.1）〉，實際 0..1） | 否（預設空清單；單檔寫入恆為空） | Edit domain 依 SPEC-009 FR-08〈多檔寫入的列法（1.1）〉與 FR-05 `partiallyWritten` 的攜帶內容；指令由 Edit domain 依 FR-02 組好，本元件不組字 |
| `validation` | `ValidationStatus?` | `written` 時必填 | 同上（`running`／`passed`／`failed(新增問題數)`／`unavailable(原因)`） |
| `restoreCommand` | `String?` | `written` 時必填 | Edit domain 依 SPEC-009 FR-02 組好的完整指令（含 sha 或 `HEAD`，及工作區相對路徑）；本元件不組字 |
| `hasSnapshot` | `bool` | `written` 時必填 | 同上 |
| `onPathTap` | `VoidCallback?` | 否（`null` 時路徑不可點） | 不適用 |
| `testKey` | `Key` | 是（`card-writeLog-row-<index>`） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.border`（列間頂邊框）；其餘經子件 |
| 間距 | 垂直內距 `Space.sm`；列內各行間 `Space.xs`；同一行子件間 `Space.sm` |
| 字體 | 經 `AppText` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 寫入結果 | 徽章 `fieldWriteInProgress`、`writeResultWritten`、`writeResultBlocked`、`writeResultIoFailed`；說明 `writeResultExternallyModified`、`fieldBlockedSnapshotFailed`、`fieldBlockedRewriteNotIsolated`、`fieldIoFailed` |
| 驗證狀態 | `validationRunning`、`validationPassed`、`validationFailed`、`validationUnavailable` + 原因 `validationUnavailableExecutableMissing`、`validationUnavailableUnexpectedExitCode`、`validationUnavailableUnparsableOutput`、`validationUnavailableTimedOut`、`validationUnavailableBaselineNotReady` |
| 所屬專案、快照期限、取回說明小標、朗讀 | `writeLogProjectLabel`、`writeLogSnapshotExpiryNote`、`writeLogColumnRestore`、`writeLogRowA11yLabel`（欄名 `writeLogColumnPath`、`writeLogColumnField`、`writeLogColumnResult`、`writeLogColumnValidation`） |
| 多檔寫入與部分寫入（1.1） | `writeResultPartiallyWritten`、`writeLogPartiallyWrittenNote`、`writeLogBatchFilesLabel`、`writeLogUnrevertedFilesLabel` |

1.143 登記；1.1 的四個 key 於 1.149 登記，§4.0.6。

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | 寫入清單面板的 `Panel.scrollable`（`scroll-writeLog-list`，§3.6 §12 列） |
| 不得放置的區域 | 依 §4.0.8；不得對整列掛點擊手勢（會與取回說明的選取競爭） |
| 對齊基準 | 子件起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 列以 `Semantics(container: true)` 分組，label 為 `writeLogRowA11yLabel`（代入路徑、欄位名、寫入結果、驗證狀態）；路徑按鈕與取回說明為獨立節點 |
| 狀態變化播報 | 不播報（見回饋契約 state-change 列） |
| 非視覺替代訊號 | 寫入結果與驗證狀態以徽章文字表達，tone 色非唯一訊號 |
| 焦點順序與操作路徑（桌機） | 列內：路徑（可點時）→ 取回說明 → 同批檔案的各取回指令（1.1，依 `batchFiles` 順序）；列間依清單順序（新的在上） |
| 對比 | 經子件（`Badge` 依 4.5，`AppText` 依 4.1） |

#### 測試點（widget test）

- [ ] 一支測試渲染寫入中、`written`×驗證四態、`blocked` 三原因、`ioFailed`，各一列
- [ ] `written` 有快照時渲染 `cat-file` 指令與期限說明，無快照時渲染 `checkout` 指令、無期限說明；對照：非 `written` 列無取回說明與驗證徽章
- [ ] `onPathTap` 為 `null` 時無 `action-writeLog-goto-node-<index>`；非 `null` 時點擊呼叫恰一次
- [ ] 面板內寬（5.19）下 `TestCopy.filePath` 路徑截斷、取回說明換行不溢位
- [ ] 取回說明可選取並複製，複製結果等於 `restoreCommand`
- [ ] 多檔寫入（1.1）：`written` 且 `batchFiles` 一筆時，渲染 `writeLogBatchFilesLabel`、該檔路徑與取回指令，驗證徽章只有一個（正向檔）；對照：`batchFiles` 為空時不渲染同批小標
- [ ] 部分寫入（1.1）：渲染 `writeResultPartiallyWritten` 徽章、`writeLogPartiallyWrittenNote` 接觸發原因、`writeLogUnrevertedFilesLabel` 與未還原檔的取回指令；不渲染驗證徽章與列首取回說明（正向檔未落檔）；觸發原因 `externallyModified` 與 `ioFailed` 各一列，說明不同
- [ ] 間距與顏色引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 顯示寫入的欄位值 | 不顯示：清單只記識別，不記欄位值（SPEC-009 FR-07） |
| 提供「還原」按鈕 | 不提供：App 內不執行還原（SPEC-009 FR-02），只給可複製的指令 |

### 4.52 ReferenceChips（容器）

**實作類別**：`ReferenceChips`（已選值的 chip 列 + 末端「加入」觸發器 + 覆蓋層；chip 與加入觸發器為元件自帶子件，不另匯出；頁面層禁直用 `Chip`／`InputChip`／`Wrap` 自組，§6）。

**用途**：表單欄位的多值引用編輯（SPEC-009 FR-09「多值引用（節點 ID）：chips 加搜尋加入」）。1.1 使用處：PROP related_proposals；SPEC related_usecases、related_specs、implements_requirements、source_proposal（provenance 邊的 `forward_cardinality` 為 many，`tracking_schema`；多檔寫入，SPEC-009 FR-03〈多檔寫入（1.1）〉）；UC source_proposal（多檔寫入，SPEC-009 v1.11）、related_specs、related_usecases、ticket_refs；EVT source_proposal（多檔寫入，SPEC-009 v1.11）；DomainBundle source_specs、related_usecases、depends_on_bundles。
**新增元件而非併入 `ReferencePicker` 的理由**：值的形狀不同——本元件的值是有序清單，操作是「加入一項」與「移除一項」兩種，各為一次寫入；`ReferencePicker` 的值是單一引用，操作是「取代」。把兩者併成一個元件需要以參數切換值型別與 `onChanged` 簽名，兩種呼叫端互不相容。加入時的覆蓋層（過濾框 + 可捲動選項清單）與 4.46 同形，共用基底的抽取見 `1.1.0-W1-115`。
**內容角色**：標題（每個 chip 為被引用節點的識別值）+ 動作（加入、移除）。
**何時不用**：單一引用（`ReferencePicker`）；值為已宣告 domain 的多值欄位（`AppCheckboxGroup`，4.53）；字串清單（1.4）；跳轉到被引用的節點（`RelationItem`）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體。chip 的已解析／找不到兩種外觀為值對映參數（見 slot 契約 `resolvedValues`），不另立變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| empty | `fieldEmptyValue`（`textSecondary`，`AppText.body`）+ 加入觸發器（「＋」圖示 + `referenceChipsAdd`），同列 | 加入 → open | `selected` 為空清單 | 加入一項 → 呼叫 `onAdded`，呼叫端傳 `locked: true` → locked；`written` 後呼叫端改傳 `selected` → set | —（`selected`、`options`、`resolvedValues` 由呼叫端傳入，元件不 watch，§2） | 等確認才顯示 |
| set | chip 依 `selected` 原序排列，末端接加入觸發器 | 加入 → open；移除任一 chip | `selected` 非空 | 加入或移除 → 呼叫 `onAdded`／`onRemoved` → locked | — | 等確認才顯示 |
| open | 覆蓋層展開，形狀與鍵盤同 4.46 open：首列過濾框（`searchPlaceholder`，焦點自動移入），其下為 `options` 扣除已在 `selected` 內的值；無可加入項時清單區顯示 `referencePickerNoMatch` | 輸入過濾、走選項、選取、Esc、點外部 | 點選加入觸發器或聚焦時 Enter／Space／↓ | 選取 → 收合並呼叫 `onAdded(value)`；Esc、點外部 → 收合，不呼叫；過濾字串於收合時清空 | 互動瞬態 | 本地即時 |
| locked | chip 與觸發器外觀同 disabled；顯示送出前的清單（不樂觀加入或移除）；已持有焦點者保留焦點 | 無（不可展開、不可移除） | `locked` 為 `true`（寫入進行中，4.44〈值格鎖定〉） | `locked` 改為 `false` → 依 `selected` 回 empty／set | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled；chip 移除鈕與觸發器不進 Tab 順序 | 無 | `enabled` 為 `false`（外部已改阻擋，4.44〈值格鎖定〉） | 放棄並重讀成功 → 以新 key 重建；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| hover／pressed／focused | 依 §4.0.1，分別作用於加入觸發器與各 chip 的移除鈕；chip 本體不可點，無互動瞬態 | 點選 | 依 §4.0.1 | 依 §4.0.1 | 互動瞬態 | 本地即時 |

移除後焦點落點：被移除的 chip 卸載，焦點移到新清單中、原位置之後第一個 chip 的移除鈕（同值的其他 chip 一併卸載，F4，不計入）；之後沒有 chip 時移到加入觸發器。焦點在受理後隨 chip 卸載移動，locked 期間保留在原移除鈕上。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——加入或移除改變欄位值；不導覽至被引用節點 |
| 2 | 套用時點 | 一次加入或一次移除為一次提交：(a) 單一欄位；(b) 寫入受理延遲依 SPEC-009 NFR-01；(c) 不需預覽；(d) 可再加回，且寫入前已建快照（SPEC-009 FR-02）；(e) `FieldList` 沒有整批儲存（4.50，用戶裁定 `1.0.0-W3-675` 的立即提交）→ 立即提交。`source_proposal` 一次提交可能寫多個檔（SPEC-009 FR-03〈多檔寫入（1.1）〉），仍是一次提交 |
| 3 | 容器何時關閉 | 是——覆蓋層一次只加入一項，選取即收合。移除不經覆蓋層：無可關閉的容器，移除鈕常駐於 chip 上 |
| 4 | 生效是否當下可見 | 有——受理為 `written` 後 chip 出現或消失；受理前維持原清單 |

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 加入觸發器與移除鈕的 hover 態（§4.0.1）；過濾框指標 `SystemMouseCursors.text` | 無（Material 內建） | 無 | §1 子表「可互動提示」列 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 觸發器與移除鈕焦點環；覆蓋層內同 4.46；移除後的焦點落點見狀態矩陣下方 | 無 | 無 | §1 子表「焦點」列 | 原狀態 → open → 原狀態 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 觸發器或移除鈕 pressed + ripple；選取選項時 `onAdded(value)` 恰一次並收合；移除鈕 `onRemoved(value)` 恰一次。掛載點為本元件第一層 | Material 內建 ripple；覆蓋層 `Motion.overlay` | pressed 於 `Motion.feedback` 內；覆蓋層於 `Motion.overlay` 內 | §1 子表「按下確認」列 | set → open →（選取）→ locked；set →（移除）→ locked | 規格撰寫者 |
| 定位提示 locate | 系統 | 展開時清單從首列開始（無「目前值」可捲動對齊）；寫入結果回來時不移動焦點，移除造成的焦點移動除外（用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2 的例外：焦點所在節點卸載時必須有落點） | 無 | 無 | §1 子表「定位提示」列 | open | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（`written` 後改傳 `selected`） | chip 離散出現或消失，不做動畫；chip 列的朗讀（`referenceChipsA11yLabel`）隨筆數重建 | 無 | 無 | §1 子表「狀態變更提示」列 | locked →（`written`）→ set／empty；locked →（被拒、讀寫失敗）→ 原狀態 | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為本元件；過濾為本地即時，`options` 由呼叫端自掃描結果傳入；寫入的第二層為 `FieldBlock` writing（本元件 locked），第三層為 `FieldBlock` 的寫入結果與驗證狀態，四段結局見 4.48；多檔寫入只成功一部分（SPEC-009 `partiallyWritten`）時由 4.48「部分寫入」列呈現，本元件維持送出前的清單；寫入清單的留痕見 4.51〈同批檔案〉（1.149） | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 加入：依 §4.0.7 點選加入觸發器，展開後鍵盤操作同 4.46；移除：依 §4.0.7 點選 chip 的移除鈕（Tab 走到後 Space／Enter） | 字元級（過濾）；命中一列（選取）；命中一個移除鈕 | 足夠 | 無 | 視覺 |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高隨 chip 列數（chip 與觸發器依序橫排，排不下換列，5.20） |
| 最小尺寸 | 寬：chip 最小寬（`Space.sm` + 一字元 + 省略號 + `Space.xs` + `LayoutSize.hitTargetMin`）與觸發器最小寬（`Space.sm` + `LayoutSize.iconMd` + `Space.xs` + 一字元 + 省略號 + `Space.sm`）取大，算式見 5.20；高：`LayoutSize.hitTargetMin` |
| 最小命中區 | `LayoutSize.hitTargetMin`（加入觸發器、每個移除鈕、過濾框、每個選項） |
| 最大尺寸 | 寬：父格位寬；高：不設上限（列數隨 `selected` 筆數，溢出由 `FieldList` 的垂直捲動承接） |
| 覆蓋層尺寸 | 同 4.46 覆蓋層算式，寬改為本元件寬（觸發器寬太窄，不作為選項列寬） |
| `kMinWindowSize` 下的行為 | 維持。覆蓋層高的上限與展開方向同 4.46（≤ 264 ≤ 288，觸發器高同為 `LayoutSize.hitTargetMin`，算式不依觸發器所在列） |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| chip 文字（`selected` 的值，`AppText.mono`） | 否 | 1 | 截斷 | `TestCopy.nodeId`；`TestCopy.longToken` |
| 空值文字（empty） | 否 | 1 | 截斷 | `fieldEmptyValue`（en「Not set」） |
| 加入觸發器文字 | 否 | 1 | 截斷 | `referenceChipsAdd`（en「Add」） |
| 選項 `label`（「ID 標題」） | 否 | 1 | 截斷 | `TestCopy.nodeId` + `TestCopy.nodeTitle` |
| 過濾輸入（可編輯） | 否 | 1 | 不截斷：隨游標水平捲動 | `TestCopy.longToken` |
| 無可加入項文字 | 否 | 1 | 截斷 | `referencePickerNoMatch`（en「No matching items」） |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `selected` | `List<String>`，0..N（無上限），依 frontmatter 原序 | 是 | 不適用（識別值原文，資料值不進 i18n） |
| `options` | `List<ReferenceOption{value, label}>`，0..N（無上限）；呼叫端已排除節點自身 | 是 | 呼叫端：Graph domain 的節點清單依欄位的目標型別過濾（例 related_specs 取 SPEC 節點），`value` 為節點 ID、`label` 為「ID 標題」 |
| `resolvedValues` | `Set<String>`：`selected` 中在目前專案找得到節點的值 | 是 | 不適用。值對映（分類形式）：在集合內 → 一般 chip；不在 → 找不到外觀（`AppColors.error` 外框 + 警示圖示 `AppIcon`，文字不變色），並由 `FieldBlock` 提示格顯示 `fieldReferenceNotFound`。用好壞色的依據：找不到即 `danglingRef` 破洞（SPEC-001 §5），規格寫明其為缺陷；非顏色線索為圖示與朗讀 |
| `onAdded` | `ValueChanged<String>` | 是 | 不適用 |
| `onRemoved` | `void Function(int index, String value)` | 是。必填欄位移除最後一項時，呼叫端不發出寫入，`FieldBlock` 顯示「必填空白」（4.48） | 不適用 |
| `locked` | `bool` | 否（預設 `false`；4.44〈值格鎖定〉） | 不適用 |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端（欄位 label） |
| `testKey` | `Key` | 是（加入觸發器 `action-nodeDetail-field-<fieldKey>`；過濾框 `action-nodeDetail-field-<fieldKey>-filter`、選單 `menu-nodeDetail-field-<fieldKey>`、選項 `option-nodeDetail-field-<fieldKey>-<value>`、chip `badge-nodeDetail-field-<fieldKey>-chip-<index>`、移除鈕 `action-nodeDetail-field-<fieldKey>-remove-<index>` 由元件推導，`<index>` 見下方重複值規則；類別皆為 SPEC-003 §2.9 既有類別） | 不適用 |

過濾規則同 4.46。`selected` 內的重複值依原樣顯示（不合併，每一筆一個 chip）；chip 與移除鈕的 widget key 與 testKey 以 `<index>`（該值在 `selected` 中的位置，0 起算）推導，同值的兩筆因此不撞 key。移除時傳出 `(index, value)`；寫入層移除該值的全部出現（SPEC-009 FR-03〈多值欄位的加入與移除（1.1）〉F4，用戶裁定 2026-11-13），受理後同值的所有 chip 一起消失，焦點落點依被點的那一筆計算。

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | `AppColors.surfaceBase`、`border`（chip 外框）、`error`（找不到的 chip 外框與圖示）、`accent`（過濾框焦點框）、`surfaceIconTint`、`textPrimary`、`textSecondary`（觸發器文字與圖示） |
| 間距 | chip 內距起始側 `Space.sm`、文字與移除鈕間 `Space.xs`；chip 間與列間 `Space.xs`（5.20）；覆蓋層同 4.46 |
| 字體 | `AppFontSize.body`（chip 文字以 `AppText.mono`） |
| 圓角 | `Radius.md`（chip、觸發器） |
| 動畫 | `Motion.feedback`；`Motion.overlay` |
| 尺寸 | `LayoutSize.hitTargetMin`、`iconMd`、`iconSm`（移除鈕圖示） |

#### i18n

| 文字 | i18n key |
|------|---------|
| 加入觸發器 | `referenceChipsAdd` |
| 移除鈕朗讀 | `referenceChipsRemoveA11y` |
| chip 列朗讀 | `referenceChipsA11yLabel` |
| 找不到的提示 | `fieldReferenceNotFound`（`FieldBlock` 提示格） |
| 過濾框、無符合項 | 同 4.46（`searchPlaceholder`、`referencePickerNoMatch`） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊；同列 chip 與觸發器垂直置中 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 根節點 `Semantics` label `referenceChipsA11yLabel`（代入欄位 label 與筆數）；chip 為文字節點，找不到者附 `fieldReferenceNotFound`；移除鈕 `Semantics.button`，label `referenceChipsRemoveA11y`（代入值）；加入觸發器 `Semantics.button`，`expanded` 隨開合；覆蓋層同 4.46 |
| 狀態變化播報 | 筆數變化經 `FieldBlock` 提示格的 live region 播報寫入結果（4.48），本元件不另播 |
| 非視覺替代訊號 | 找不到以圖示與朗讀承載，不只靠外框色 |
| 焦點順序與操作路徑（桌機） | 依 chip 原序走各移除鈕，最後為加入觸發器（disabled、locked 除外；locked 時已持有的焦點保留）；覆蓋層內同 4.46；欄位間 Tab 順序見 4.50 |
| 對比 | 依 §4.0.2：`textPrimary` / `surfaceBase` 5.79:1；`error` 外框與圖示屬非文字圖形，門檻 3:1，`error` / `surfaceBase` 6.54:1（§4.0.2 表 1），通過 |

#### 測試點（widget test）

- [ ] 一支測試渲染 empty / set（含找不到的 chip）/ open / open 無可加入項 / locked / disabled
- [ ] 加入：選取呼叫 `onAdded` 恰一次並收合；對照：Esc 收合不呼叫
- [ ] open 的選項不含已在 `selected` 內的值；對照：`selected` 為空時選項等於 `options`
- [ ] 移除鈕呼叫 `onRemoved` 恰一次；locked 時不呼叫
- [ ] `selected` 含重複值時每筆各一個 chip、testKey 依位置不重複，移除第二筆傳出的 index 為其位置（對照：移除第一筆傳出的 index 不同）
- [ ] 傳 `locked: true` 後清單維持送出前的內容（不樂觀加入或移除）
- [ ] 移除後改傳 `selected`：焦點移到下一個移除鈕；移除最後一項時移到加入觸發器
- [ ] 兩種視窗尺寸下不溢位；`selected` 20 筆時換列、高隨列數增加
- [ ] chip 最長測試文案截斷
- [ ] 顏色、內距、圓角引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 單一引用 | `ReferencePicker` |
| 已宣告 domain 的多值欄位 | `AppCheckboxGroup` |
| 點 chip 跳到被引用節點 | `RelationItem`（檢視模式） |
| 顯示非互動的分類標記 | `Badge` |

### 4.53 AppCheckboxGroup（容器）

**實作類別**：`AppCheckboxGroup`（`AppCheckbox` × N 垂直；頁面層禁以 `Column` 自組多個 `AppCheckbox`，§6）。

**用途**：表單欄位的多值選擇，值為已宣告的 domain（SPEC-009 FR-09「多值引用（domain）：核取清單」）。1.1 使用處：SPEC depends_on_domains；EVT producers、consumers。
**新增容器而非沿用 `ReferenceChips` 的理由**：值域是專案已宣告的 domain，數量小且整份可見（以 `docs/system-layer.md` §1.3 的 domain 清單為準），使用者需要一次看到全部候選並比較；chips 只顯示已選的值，未選的要開覆蓋層才看得到。
**內容角色**：標籤（每個核取項為一個 domain 名）+ 動作 + 狀態（核取值）。
**何時不用**：節點 ID 的多值引用（`ReferenceChips`）；單一布林設定（`AppCheckbox` 單獨使用）；互斥單選（`AppRadioGroup`）。
**出現畫面**：節點詳情的編輯模式（SPEC-001 §6），經 `FieldList`（4.50）與 `FieldBlock`（4.48）。
**層級**：L2

#### 變體

| 變體 | 外觀差異 | 行為差異 | 何時選用 |
|------|---------|---------|---------|
| `default` | 單一變體 | | |

#### 狀態矩陣

| 狀態 | 顯示 | 可用操作 | 進入條件 | 退出路徑 | 來源 | 同步策略 |
|------|------|---------|---------|---------|------|---------|
| ready | 依 `options` 原序列出核取項，`selected` 內者 checked；`selected` 中不在 `options` 的值接在最後，checked，`FieldBlock` 提示格顯示 `fieldValueOutOfDomain` | 切換任一項 | 預設 | 切換 → 呼叫 `onToggled(value, checked)`，呼叫端傳 `locked: true` → locked | —（`selected` 與 `options` 由呼叫端傳入，元件不 watch，§2） | 等確認才顯示 |
| locked | 全部核取項外觀同 disabled，核取值維持送出前（不樂觀切換）；已持有焦點者保留焦點 | 無 | `locked` 為 `true`（4.44〈值格鎖定〉） | `locked` 改為 `false` → ready | 資料態：Edit domain 的寫入進行中旗標，經 `FieldList` 下發 | 等確認才顯示 |
| disabled | 依 §4.0.1 disabled；不進 Tab 順序 | 無 | `enabled` 為 `false`（外部已改阻擋） | 放棄並重讀成功 → 以新 key 重建；完成 → FieldList 移除 | 資料態：Edit domain 的編輯狀態，經 `FieldList` 下發 | 等確認才顯示 |
| 選項為空 | 不渲染核取項；`FieldBlock` 提示格 `checkboxGroupNoOptions` | 無 | `options` 與 `selected` 皆為空（專案未宣告任何 domain） | 重新掃描後呼叫端改傳 `options` → ready | — | 等確認才顯示 |

互動瞬態由各 `AppCheckbox` 承載（4.43）。

#### 套用時點

> 判準：`component-contract-design` skill〈套用時點的四問〉。

| # | 問句 | 答 |
|---|------|----|
| 1 | 設定或動作 | 設定——切換改變欄位值 |
| 2 | 套用時點 | 一次切換為一次提交，(a)–(e) 判法同 4.52 → 立即提交 |
| 3 | 容器何時關閉 | 無可關閉的容器——清單常駐於 `FieldBlock` 值格 |
| 4 | 生效是否當下可見 | 有——受理為 `written` 後核取值改變；受理前維持原值 |

#### 回饋契約

| 事件 | 觸發者 | 反應 | 動畫 token | 時間門檻 | 回饋通道（桌機） | 對應狀態邊 | 填寫者 |
|------|--------|------|-----------|---------|-----------------|-----------|--------|
| 可互動提示 affordance | 使用者接近 | 由各 `AppCheckbox` 承載（4.43） | — | — | 由子件承載 | 不適用 | 規格撰寫者 |
| 焦點 focus | 使用者／輔助技術 | 由各 `AppCheckbox` 承載；群組以 `Semantics` 容器朗讀欄位 label | 無 | 無 | §1 子表「焦點」列 | 不適用 | 規格撰寫者 |
| 按下確認 press-ack | 使用者 | 由被點的 `AppCheckbox` 承載（第一層）；本容器將其 `onChanged(v)` 轉為 `onToggled(value, v)` 恰一次；核取外觀不在點擊當下改變，等呼叫端改傳 `selected`（與 4.43 在變更記錄的本地即時用法不同） | Material 內建 ripple | pressed 於 `Motion.feedback` 內 | §1 子表「按下確認」列 | ready → locked | 規格撰寫者 |
| 定位提示 locate | 系統 | 不移動焦點（`1.0.0-W3-553.3.1` 題 2） | 無 | 無 | §1 子表「定位提示」列 | 不適用 | 規格撰寫者 |
| 狀態變更提示 state-change | 呼叫端（`written` 後改傳 `selected`） | 被切換項的核取外觀離散替換；`checked` 旗標改變由輔助技術播報（4.43） | 無 | 無 | §1 子表「狀態變更提示」列 | locked →（`written`）→ ready（新值）；locked →（被拒、讀寫失敗）→ ready（原值） | 規格撰寫者 |
| 等待與結果 | 系統 | 掛載點：第一層為被點的 `AppCheckbox`；第二層為 `FieldBlock` writing（本容器 locked）；第三層為 `FieldBlock` 的寫入結果與驗證狀態，四段結局見 4.48 | — | 見 4.48 | §1 子表「等待與結果」列 | 不適用 | 規格撰寫者 |

#### 操作機制

| 形態 | 主要動作 | 任務所需精度 | 該形態輸入精度 | 替代機制 | 回饋通道 |
|------|---------|-------------|--------------|---------|---------|
| 桌機 | 依 §4.0.7 點選列（每個核取項一個 Tab 停留點，Space 切換） | | | | |

#### 尺寸契約

| 項目 | 值 |
|------|-----|
| 尺寸模式 | 寬填滿父格位；高 = 核取項數 × `LayoutSize.hitTargetMin` + 間距（5.21） |
| 最小尺寸 | 寬：`Space.xs` + `LayoutSize.iconLg` + `Space.xs` + 4 × `AppFontSize.body` + `Space.xs`（同 `AppRadioGroup`，5.17）；高：`LayoutSize.hitTargetMin`（一項時） |
| 最小命中區 | `LayoutSize.hitTargetMin`（每個核取項的核取框 + label 整體，4.43） |
| 最大尺寸 | 寬：父格位寬；高：不設上限，不內嵌捲動（溢出由 `FieldList` 的垂直捲動承接） |
| `kMinWindowSize` 下的行為 | 維持 |
| `kDesignSize` 下的行為 | 維持 |

#### 內容政策

| 文字 slot | 可否換行 | 最大行數 | 超出處置 | 最長測試文案 |
|-----------|---------|---------|---------|-------------|
| 核取項 label（domain 原值） | 否 | 1 | 截斷（4.43） | `TestCopy.domainName`；`TestCopy.longToken` |

#### slot 契約

| slot | 接受型別 | 必填 | 文字來源 |
|------|---------|------|---------|
| `options` | `List<String>`，0..N（無上限） | 是 | 呼叫端：Graph domain 的已宣告 domain 清單（`DomainBundle` 的 `domain` 原值，CLAUDE.md §6 domain 名稱權威寫法），依 domain 名字母序；資料值不進 i18n |
| `selected` | `List<String>`，依 frontmatter 原序 | 是 | 不適用 |
| `onToggled` | `void Function(String value, bool checked)` | 是。必填欄位取消最後一項時，呼叫端不發出寫入，`FieldBlock` 顯示「必填空白」（4.48） | 不適用 |
| `locked` | `bool` | 否（預設 `false`） | 不適用 |
| `enabled` | `bool` | 否（預設 `true`） | 不適用 |
| `semanticLabel` | `String` | 是 | 呼叫端（欄位 label） |
| `testKey` | `Key` | 是（群組根 `action-nodeDetail-field-<fieldKey>`；核取項 `option-nodeDetail-field-<fieldKey>-<value>` 由元件推導，類別為 SPEC-003 §2.9 既有類別） | 不適用 |

#### 使用 design token

| 面向 | token |
|------|-------|
| 色彩 | 由 `AppCheckbox` 承載（4.43） |
| 間距 | 核取項間 0（命中區相鄰，5.21） |
| 字體 | 由 `AppCheckbox` 承載 |
| 圓角 | 由 `AppCheckbox` 承載 |
| 動畫 | 由 `AppCheckbox` 承載 |
| 尺寸 | `LayoutSize.hitTargetMin` |

#### i18n

| 文字 | i18n key |
|------|---------|
| 選項為空 | `checkboxGroupNoOptions`（`FieldBlock` 提示格） |
| 值域外 | `fieldValueOutOfDomain`（沿用） |

#### 組合規則

| 項目 | 值 |
|------|-----|
| 可放入的容器 | `FieldBlock.editable`（值格） |
| 不得放置的區域 | 依 §4.0.8 |
| 對齊基準 | 值格起始側對齊 |
| 作為表格或列表的一欄時 | 不適用 |

#### 無障礙

| 面向 | 要求 |
|------|------|
| 朗讀標籤 | 群組 `Semantics(container: true)`，label 為 `semanticLabel`；各核取項依 4.43 |
| 狀態變化播報 | 依 4.43（`checked` 旗標）；寫入結果由 `FieldBlock` 提示格 live region 播報 |
| 非視覺替代訊號 | 依 4.43 |
| 焦點順序與操作路徑（桌機） | 核取項依顯示順序進入 Tab 順序（disabled、locked 除外；locked 時已持有的焦點保留）；Space 切換；欄位間 Tab 順序見 4.50 |
| 對比 | 依 4.43 |

#### 測試點（widget test）

- [ ] 一支測試渲染 ready（含值域外的值）/ locked / disabled / 選項為空
- [ ] 點核取項呼叫 `onToggled` 恰一次，`checked` 為點擊前值的反面；對照：checked 與 unchecked 各點一次，兩次傳出值不同
- [ ] 點擊後未改傳 `selected` 時核取外觀不變（不樂觀切換）
- [ ] 值域外的值接在最後且為 checked
- [ ] 兩種視窗尺寸下不溢位；`options` 20 筆時高隨筆數增加、無內嵌捲動
- [ ] 最長測試文案截斷
- [ ] 間距引用 token 非硬編碼

#### 反例

| 不該拿它做什麼 | 應改用 |
|---------------|--------|
| 節點 ID 的多值引用 | `ReferenceChips` |
| 互斥單選 | `AppRadioGroup` |
| 篩選列的布林開關 | `AppCheckbox`（單獨使用，`Toolbar.history`） |

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
| 子件數量上限 | 標題列 1；側欄 1 + 7；主區 7；覆蓋層 0..1（合計上限 17） |
| 安全區 | 無 SafeArea 需求（§1 禁放區與安全區列：macOS 視窗無瀏海與手勢區）；視窗邊緣內距由本容器承載：側欄內距 `Space.md`（垂直）× `Space.sm`（水平）、標題列水平內距 `Space.md`、主區內距交由 `PageColumn`（`Space.xl`） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 標題列、側欄、主區三個區域互斥（垂直：標題列 / 主體；主體水平：側欄 / 主區）；側欄內子件垂直堆疊兩兩不相交；覆蓋層允許疊於側欄與主區之上（覆蓋層非佈局流子件）；測試以兩種尺寸 × 上限驗證 |
| 最小間距 | 側欄：入口與導覽項間 `Space.sm`，導覽項間 `Space.xxs`；側欄與主區以邊框線相接（§4.0.3 線寬）；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 8（側欄）；`LayoutSize.titleBarHeight`（36）+ 2 × `Space.md` + `ProjectSwitcherEntry` 高 + `Space.sm` + 7 × `NavItem` 高 + 6 × `Space.xxs` ≤ `kMinWindowSize.height`；主區寬 = 視窗寬 − `LayoutSize.sidebarWidth` ≥ `PageColumn` 最小寬 |

### 5.2 PageColumn

**對應第 4 章條目**：4.28

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `SplitRow.header`；內容：`Panel` \| `Panel.scrollable` \| `TwoColumnLayout` \| `EmptyState.page` \| `BlockedState` \| `LoadingState` \| `MissingSourceState` |
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
| 空間不足策略 | 不觸發：上限 2；trailing 固有寬 + `Space.md` + leading 最小寬（一字元 + 省略號；一字元見 §4.0.3，字級依 `leading` 子件，同 4.29〈尺寸契約〉最小尺寸列）≤ 可用寬（列寬扣除兩側水平內距，4.29〈尺寸契約〉最小尺寸列）；trailing 為 `ButtonRow` 時其自身以換行承載（5.8），本列高隨之增加至多 3 列 |

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
| 空間不足策略 | 不觸發：上限 2；`LayoutSize.detailPaneWidth` + `Space.md` + 主欄最小寬 ≤ 可用寬（= 視窗寬 − `LayoutSize.sidebarWidth` − 2 × `Space.xl`）；主欄最小寬 = 2 × `Space.md` + 其資料視圖最小寬（§6：`DocumentBody` 最小寬，4.20；§1：`MatrixGrid` 最小寬，含 `matrixColumnWidth`（122，已核定），5.11） |

### 5.6 Toolbar

**對應第 4 章條目**：4.32

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `default`：`SearchField`、`FilterDropdown`、`IssueMarker.damagedDetail`；`history`：`SegmentedControl`、`AppCheckbox` |
| 子件數量上限 | `default` 5（搜尋 1 + 篩選 1..3 + 標記 0..1）；`history` 2（期間 1 + 切換 1） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 單列水平互斥；`default` 由 `SearchField` 吸收剩餘寬，`history` 的 `AppCheckbox` 取固有寬、`SegmentedControl` 取有界寬，兩者靠左 |
| 最小間距 | `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | `history`：上限 2；`SegmentedControl` 格位為有界寬 = 可用寬（= `Panel` 內寬）− `AppCheckbox` 固有寬 − `Space.sm`，不超出時取固有寬、靠左；`SegmentedControl` 固有寬 > 有界寬時觸發，各段 label 截斷（4.10 最大尺寸），`AppCheckbox` 維持固有寬，不縮放、不換行。觸發條件只在字型寬於預期時成立（測試字型、極端系統字型），測試以 `kMinWindowSize`、en 長 label 與測試字型代入，斷言不溢位且段 label 截斷。`default`：不觸發，上限 5；`SearchField` 最小寬 + Σ `FilterDropdown` 固有寬（以最長選項文案計）+ `IssueMarker` 寬 + 4 × `Space.sm` ≤ 可用寬（= `Panel` 內寬）；測試以 `TestCopy` 最長值與 `kMinWindowSize` 代入斷言 |

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
| 不重疊 | 同列水平互斥、列間垂直互斥；單一按鈕寬超過可用寬時自身截斷 label（4.4）。`wrap: false` 不適用截斷：label 不截斷，可用寬不足屬宿主違約，依 4.34 尺寸模式以 `RenderFlex` 的 debug 期溢位回報揭露 |
| 最小間距 | `Space.sm`（水平與列間）；呼叫端不得覆寫 |
| 空間不足策略 | 換行（wrap）；觸發條件：Σ 按鈕固有寬 + (n − 1) × `Space.sm` > 可用寬（右欄 `LayoutSize.detailPaneWidth` − 2 × `Space.md` 為最窄宿主，最長文案下兩顆可能觸發，故不採「不觸發」）。`wrap: false`（1.150，只用於 `ListRow.item` trailing）：不換行、不觸發，前提是宿主列寬不小於固有寬，核對見 5.14〈可修正破洞項的寬度核對〉；宿主寬不足屬兩份契約互斥，不得以截斷或換行吸收 |

### 5.9 TableRow

**對應第 4 章條目**：4.35

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `header`：`TableColumnHeader`；`ticket`：`AppText.mono`、`AppText.body`、`Badge.status`、`AppText.caption`、`AppText.mono`（blockedBy）、`IssueMarker.damagedDetail`；`step`：`StepNumber`、`AppText.body`、`RelationItem`、`BadgeRow`；`eventFlow`：`AppText.mono`、`AppText.body` × 2、`AppIcon`（孤立事件標記，0..1）；`historyEvent`：`Badge.category`、`AppText.mono`（邊型）、`RelationItem`（宣告端）、`RelationItem` 或 `AppText.mono`（對端）、`AppText.mono`（hash）、`AppText.caption`（日期）、`AppText.body`（作者與訊息） |
| 子件數量上限 | = 欄數（依 4.35 各變體欄規格列） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 格依欄規格水平互斥；填滿欄子件截斷（`AppText`）或換行（`BadgeRow`，列高固定時改為單列截斷，提案：`step` 事件欄 `BadgeRow` 限一列） |
| 最小間距 | `Space.md`（欄間）；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：Σ 固定寬欄（`ticketIdColumnWidth` + `ticketStatusColumnWidth` + `ticketPriorityColumnWidth` + `ticketMarkerColumnWidth`；`stepNumberColumnWidth` + `stepDomainColumnWidth`；`ticketIdColumnWidth` + `ticketMarkerColumnWidth`（`eventFlow`）；`ticketIdColumnWidth` + 3 × `ticketStatusColumnWidth`（`historyEvent`，= 384））+ 填滿欄最小寬 × 填滿欄數 + (欄數 − 1) × `Space.md` + 2 × `Space.sm` ≤ 列寬（= `Panel` 內寬）。`historyEvent` 代入 `kMinWindowSize`：384 + 6 × 12 + 16 = 472，列寬 724，餘 252 分給 4 個 flex 單位（每單位 63），大於填滿欄最小寬，不觸發；窄視窗下宣告端與對端截斷，完整值由 `historyEventA11yLabel` 承載 |

### 5.10 DataTable

**對應第 4 章條目**：4.36

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `TableRow.header`（1）、`TableRow.ticket`／`TableRow.step`／`TableRow.eventFlow`／`TableRow.historyEvent`（單一變體）；`plain` 另接受 `appendix`：`DataTable.plain`（0..1，其自身不得再帶 `appendix`） |
| 子件數量上限 | 表頭 1；資料列無上限；`appendix` 0..1 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 列垂直互斥、高固定 `LayoutSize.rowHeightRelaxed`（`virtual` 以 `itemExtent` 保證）；表頭釘選於頂且不與首列相交；水平方向承 5.9 |
| 最小間距 | 列間以 `TableRow` 底邊框線寬分隔（§4.0.3）；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，`scroll-tickets-list` / `scroll-ucFlow-steps` / `scroll-history-events`；篩選改變後 offset 歸零、切換導覽項保留，SPEC-003 §3.9）；觸發條件：列數 × `LayoutSize.rowHeightRelaxed`（有 `appendix` 時加上其表頭高 + 列數 × `rowHeightRelaxed` + `Space.lg` 間隔，提案）> 可用高 − 表頭高。`appendix` 高固有、隨外層表捲動，外層表頭釘選時 `appendix` 的表頭不釘選。水平方向不觸發（承 5.9 公式） |

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
| 子件數量上限 | 無上限（深度上限 4；缺口列計入所在深度） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 列垂直互斥、高固定 `LayoutSize.rowHeightDense`；列內縮排 = 深度 × `LayoutSize.treeIndent`（24），列主文字截斷；缺口列緊接其父節點列之下（父節點展開時位於其既有子列之後），每個缺下游的父節點恰一列 |
| 最小間距 | 列間 0（留白由列高承載）；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，由所在 `Panel.scrollable` 的 `scroll-traceability-tree` 承載，本容器不自設捲動區）；觸發條件：可見列數 × `LayoutSize.rowHeightDense` > 面板可用高。水平：不觸發：3 × `treeIndent` + `ListRow.tree` 最小寬 ≤ 可用寬 |

### 5.14 ListRow

**對應第 4 章條目**：4.40

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | leading：`ExpanderIcon` \| `AppIcon` \| `Badge` \| `StepNumber`；primary：`AppText`；secondary：`AppText.caption`；trailing：`Badge` \| `AppIcon` \| `AppText.caption` \| `IssueMarker` \| `AppButton.text`（限 `item`）\| `ButtonRow`（限 `item` 可修正的破洞項，恰兩個 `AppButton.text`，1.150） |
| 子件數量上限 | 4（leading 0..1 + primary 1 + secondary 0..1 + trailing 0..1；trailing 為 `ButtonRow` 時算一個子件） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | leading / 文字塊 / trailing 水平互斥，兩端固有寬、文字塊填滿並截斷；secondary 堆疊於 primary 下 |
| 最小間距 | `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 不觸發：上限 4；leading 固有寬 + trailing 固有寬 + 2 × `Space.sm` + primary 最小寬（一字元 + 省略號；一字元見 §4.0.3，取 `primary` slot 的 `AppFontSize.body`，同 4.40〈尺寸契約〉最小尺寸列）≤ 列寬；最窄宿主為 `Tree` 第四層（承 5.13 水平公式）。trailing 為 `ButtonRow` 的 `item` 另見下方〈可修正破洞項的寬度核對〉 |

**可修正破洞項的寬度核對**（1.150，`1.1.0-W1-111` Step 4.5 第 3 項）：trailing 是兩個 `AppButton.text`，是 `item` 最寬的 trailing。`AppButton` 固有寬 = label 寬 + 2 × `Space.md`，帶圖示另加 `LayoutSize.iconMd` + `Space.xs`（4.4）。label 字級為 `AppFontSize.body`（12）。Ahem 每字元（含空格）寬 1em。實機字型中，拉丁字母與空格的字寬小於 1em，所以 en 的 Ahem 欄是上界；CJK 字寬約等於 1em，zh 的實機值與 Ahem 值相近，不視為上界。

| 子件 | 最小寬（token 式） | 實機字型代入 | 測試字型（Ahem）代入 |
|------|-------------------|-------------|--------------------|
| 編輯欄位（`editFieldsAction`，en `Edit fields` 11 字元，不帶圖示） | label + 2 × `Space.md` | < 156 | 132 + 24 = 156 |
| 開啟原始檔（`openSourceFileAction`，en `Open Source File` 16 字元，帶外開圖示） | label + 2 × `Space.md` + `LayoutSize.iconMd` + `Space.xs` | < 235 | 192 + 24 + 15 + 4 = 235 |
| trailing `ButtonRow`（`wrap: false`） | 兩鈕 + `Space.sm`（5.8） | < 399 | 156 + 8 + 235 = 399 |
| primary（截斷） | 一字元 + 省略號 | ≤ 24 | 24 |
| **列最小寬**（leading 寬計 0） | 依上方〈空間不足策略〉的通式：leading 寬 + trailing 寬 + 2 × `Space.sm` + primary | **< 439** | **439** |

通式含 2 個 `Space.sm`；沒有 leading 時，實作只放 trailing 前的一個間距（`lib/components/list_row.dart`），實際為 431。本表取通式的 439，作為保守值。

zh 文案較短（`編輯欄位` 4 字、`開啟原始檔` 5 字，Ahem 下兩鈕 72、103，列最小寬 24 + 16 + 183 = 223；CJK 實機值與此相近），所以以 en 為準。

比較對象：破洞報告 `Panel.scrollable` 內寬 = 視窗寬 − `LayoutSize.sidebarWidth` − 2 × `Space.xl`（頁面內距，5.2）− 2 × `Space.md`（面板內距，4.30）。`Section` 與 `ListRow` 沒有水平內距。`kMinWindowSize`（寬 960）下 = 960 − 172 − 40 − 24 = 724；`kDesignSize`（寬 1280）下為 1044。

| 比較 | 實機字型 | 測試字型（Ahem） |
|------|---------|----------------|
| 列最小寬 ≤ 列寬（`kMinWindowSize`） | < 439 ≤ 724，成立 | 439 ≤ 724，成立 |

**空間不足策略**（此情形）：
- 在 `kMinWindowSize` 以上不觸發。
- 列寬介於列最小寬與「leading 寬 + trailing 寬 + 2 × `Space.sm` + primary 全文寬」（同上方通式，leading 寬計 0）之間時，trailing 維持固有寬、兩鈕不截斷，由 primary 與 secondary 吸收剩餘寬並以省略號截斷（4.40 內容政策）。
- 在 `ListRow` 內，`ButtonRow` 一律以 `wrap: false` 建構（4.34、5.8）：換行會讓列高變成兩列按鈕，破壞 `item` 的固有兩行高。兩鈕必須在同一列。
- 日後若把此 `item` 放進列寬小於 439 的宿主，屬兩份契約互斥，須改宿主寬或改 trailing 形式（例如收進溢出選單），不得以截斷按鈕或換行吸收。

### 5.15 Section

**對應第 4 章條目**：4.41

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | header：`ListRow.sectionHeader` \| `AppText.caption`；items：`TableRow.ticket` \| `ListRow.item` \| `ListRow.option`（限 `static`）\| `RelationItem` \| `AppText.mono`（單一型別） |
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
| 接受的子件類型 | `AppText.caption`（標題；選擇其他的失敗原因文字，1.88）、`RecentProjectItem`、`Divider`、`AppButton.text` |
| 子件數量上限 | 標題 1、`Divider` 1、`AppButton.text` 1、失敗原因文字 0 或 1；`RecentProjectItem` 無上限 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 標題 / 清單區 / 分隔線 / 按鈕 / 失敗原因文字（存在時，位於按鈕之下）垂直互斥；清單區高 = 浮層高 − 其餘各者高 − 間距 |
| 最小間距 | `Space.xxs`；內距 `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 捲動（垂直，僅清單區，`scroll-switcher-recent`；標題、分隔線、按鈕、失敗原因文字不捲離）；觸發條件：標題高 + N × `RecentProjectItem` 高 + (N − 1) × `Space.xxs` + `Divider` 高 + `LayoutSize.hitTargetMin` + 失敗原因文字高（存在時，至多兩行，另加 `Space.xxs`）+ 2 × `Space.sm` > 最大高（入口下緣至視窗下緣 − `Space.xl`） |

### 5.17 FieldBlock

**對應第 4 章條目**：4.48（1.140 新增，`1.0.0-W3-553.6`）

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | label：`AppText.body`（`secondary`）；值格：`editable` 為 `AppTextInput`、`AppDropdown`、`ReferencePicker`、`AppRadioGroup`、`ReferenceChips`（5.20）、`AppCheckboxGroup`（5.21）之一，`readOnly` 為 `AppText.body` 或 `AppText.mono`；提示格：`AppText.caption` |
| 子件數量上限 | label 1、值格 1、提示格 0..1（共 3） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | label / 值格 / 提示格垂直互斥，單欄堆疊；交叉軸（寬）各子件填滿容器寬 |
| 最小間距 | `Space.xs`；呼叫端不得覆寫 |
| 空間不足策略 | 主軸（垂直）：不觸發——主軸無界，容器高 = 子件高之和 + 間距，不設固定高；溢出由父格位的垂直捲動承接（4.48 組合規則：父格位不可捲動者不得放）。交叉軸（寬）：固定為父格位寬，條件見下表 |

**交叉軸條件**（容器寬固定為父格位寬，無自身內距；三個子件皆可收縮：label 與唯讀值截斷或換行、輸入元件寬填滿且內部截斷或捲動，故代入尺寸契約的最小寬，§4.0.3「一字元」= 該 slot 字級 1em）：

| 子件 | 最小寬（token 式） | 實機字型代入 | 測試字型（Ahem）代入 |
|------|-------------------|-------------|--------------------|
| label（`AppText.body`，截斷） | 一字元 + 省略號（4.1） | 12 + 省略號寬 ≤ 24 | 12 + 12 = 24 |
| `AppTextInput` | `Space.sm` + 4 × `AppFontSize.body` + `Space.sm` | 64 | 64 |
| `AppDropdown` / `ReferencePicker` | `Space.sm` + 4 × `AppFontSize.body` + `Space.xs` + `LayoutSize.iconMd` + `Space.sm` | 83 | 83 |
| `AppRadioGroup` | `Space.xs` + `LayoutSize.iconLg` + `Space.xs` + 4 × `AppFontSize.body` + `Space.xs` | 77 | 77 |
| `ReferenceChips`（1.148） | 見 5.20 | ≤ 64 | 64 |
| `AppCheckboxGroup`（1.148） | 同 `AppRadioGroup`（5.21） | 77 | 77 |
| 唯讀值、提示格（換行或截斷） | 一字元 + 省略號 | ≤ 24 | 24 |
| **容器最小寬（最大值）** | | **83** | **83** |

輸入元件的最小寬是約束值（內容在其內截斷或捲動），不量測字形，故兩欄同值；label 與文字子件在實機字型下省略號寬小於 1em，取 ≤ 24。比較對象：父格位寬。父容器為 `FieldList`（4.50，1.143 定案），其格位寬 = 節點詳情主欄 `Panel.scrollable` 內寬，算式見 5.18：`kMinWindowSize` 下為 476。

| 比較 | 實機字型 | 測試字型（Ahem） |
|------|---------|----------------|
| 容器最小寬 ≤ 父格位寬 | 83 ≤ 476，成立 | 83 ≤ 476，成立 |

日後若把 `FieldBlock` 放進更窄的格位（例如右欄，內寬 212），83 ≤ 212 仍成立；格位寬小於 83 時屬兩份契約互斥，須改父格位或本容器子件的最小寬，不得以截斷吸收。

### 5.18 FieldList

**對應第 4 章條目**：4.50（1.143 新增，`1.0.0-W3-553.3.1`）

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 頂端：`NoticeBanner`（4.49）；欄位：`FieldBlock`（4.48）；底部：`AppButton.primary`（「完成」） |
| 子件數量上限 | 橫幅 0..1、`FieldBlock` 1..N（N 為該節點型別在 SPEC-009 FR-09 列出的欄位數）、「完成」1 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 橫幅 / 各 `FieldBlock` / 「完成」垂直互斥，單欄堆疊，依序為橫幅、欄位（FR-09 表列序）、「完成」；交叉軸（寬）各子件填滿容器寬，「完成」取固有寬、起始側對齊 |
| 最小間距 | `Space.md`；呼叫端不得覆寫 |
| 空間不足策略 | 主軸（垂直）：不觸發——主軸無界，容器高 = 子件高之和 + 間距；溢出由節點詳情主欄的垂直捲動（`scroll-nodeDetail-content`）承接。交叉軸（寬）：固定為父格位寬，條件見下表 |
| 寫入期間的鎖定 | 同一時間至多一個 `FieldBlock` 處於 writing；`writeInProgress` 為 `true` 期間全部值格唯讀鎖定、「完成」與橫幅動作 disabled（SPEC-001 §6〈寫入期間不可並行送出〉；鎖定方式依用戶裁定 2026-11-11，`1.0.0-W3-553.3.1` 題 2 (e)）。鎖定由本容器下發，不由呼叫端逐欄傳入（4.50 slot 契約） |

**交叉軸條件**（容器寬固定為父格位寬，無自身內距；子件皆可收縮：`FieldBlock` 見 5.17，橫幅訊息換行，「完成」鈕 label 截斷）：

| 子件 | 最小寬（token 式） | 實機字型代入 | 測試字型（Ahem）代入 |
|------|-------------------|-------------|--------------------|
| `FieldBlock` | 5.17 容器最小寬 | 83 | 83 |
| `NoticeBanner` | 2 × `Space.sm` + `LayoutSize.iconMd` + `Space.sm` + 一字元（`AppFontSize.body`） | 16 + 15 + 8 + 12 = 51 | 51 |
| 「完成」與橫幅動作 `AppButton` | `LayoutSize.hitTargetMin`（4.4） | 28 | 28 |
| **容器最小寬（最大值）** | | **83** | **83** |

橫幅訊息換行，最小寬只計一字元，不量測字形，兩欄同值。父格位寬 = 節點詳情主欄 `Panel.scrollable` 內寬 = （視窗寬 − `LayoutSize.sidebarWidth` − 2 × `Space.xl` − `LayoutSize.detailPaneWidth` − `Space.md`）− 2 × `Space.md`；`kMinWindowSize`（寬 960）下 = （960 − 172 − 40 − 236 − 12）− 24 = 476，`kDesignSize`（寬 1280）下為 796。

| 比較 | 實機字型 | 測試字型（Ahem） |
|------|---------|----------------|
| 容器最小寬 ≤ 父格位寬（`kMinWindowSize`） | 83 ≤ 476，成立 | 83 ≤ 476，成立 |

### 5.19 WriteLogRow

**對應第 4 章條目**：4.51（1.143 新增，`1.0.0-W3-553.3.1`）

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 路徑：`AppButton.text` 或 `AppText.mono`；欄位名：`AppText.body`；所屬專案：`AppText.caption`；寫入結果與驗證狀態：`Badge.category`；說明與不可用原因：`AppText.body`（`multiLine`）；取回說明：`AppText.code`；快照期限：`AppText.caption` |
| 子件數量上限 | 路徑 1、欄位名 1、所屬專案 1、寫入結果徽章 1、寫入結果說明 0..1、驗證徽章 0..1、驗證不可用原因 0..1、取回說明小標 0..1、取回說明 0..1、快照期限 0..1（共 10）；渲染條件見 4.51〈子件的渲染條件〉 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 垂直分行，由上到下：路徑與欄位名（同一行，水平互斥，路徑在前）、所屬專案、寫入結果徽章與說明、驗證徽章與不可用原因、取回說明、快照期限；各行之間垂直互斥。同一行內路徑與欄位名水平互斥，交叉軸（高）取兩者單行高，兩者皆單行不撐開 |
| 最小間距 | 行間 `Space.xs`；同一行子件間 `Space.sm`；呼叫端不得覆寫 |
| 空間不足策略 | 主軸（垂直）：不觸發——主軸無界，取回說明換行使列增高，由面板捲動（`scroll-writeLog-list`）承接。交叉軸（寬）：固定為父格位寬，條件見下表；路徑與欄位名同一行寬度不足時兩者各自截斷，路徑截斷於開頭 |

**交叉軸條件**（容器寬固定為父格位寬，無自身水平內距；路徑、欄位名、所屬專案、徽章截斷，說明、原因、取回說明換行，皆可收縮，代入最小寬）：

| 子件或行 | 最小寬（token 式） | 實機字型代入 | 測試字型（Ahem）代入 |
|---------|-------------------|-------------|--------------------|
| 路徑與欄位名同一行 | （一字元 + 省略號）+ `Space.sm` +（一字元 + 省略號），字級 `AppFontSize.body` | ≤ 24 + 8 + ≤ 24 ≤ 56 | 24 + 8 + 24 = 56 |
| 所屬專案 | 一字元 + 省略號（`AppFontSize.caption`） | ≤ 20 | 20 |
| `Badge.category`（chip） | 一字元 + 省略號（`caption`）+ 2 × `Space.sm`（4.5） | ≤ 36 | 36 |
| 說明、原因（`body` 換行）、取回說明（`code` 依字元斷行） | 一字元 | 12 | 12 |
| **容器最小寬（最大值）** | | **≤ 56** | **56** |

父格位寬 = 寫入清單面板 `Panel.scrollable` 內寬 = `LayoutSize.overlayWidth` − 2 × `Space.md` = 262 − 24 = 238（面板呈現方式同偏好設定面板，SPEC-001 §12；不隨視窗尺寸）。

| 比較 | 實機字型 | 測試字型（Ahem） |
|------|---------|----------------|
| 容器最小寬 ≤ 父格位寬 | ≤ 56 ≤ 238，成立 | 56 ≤ 238，成立 |

### 5.20 ReferenceChips

**對應第 4 章條目**：4.52（1.148 新增，`1.1.0-W1-111`）

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | 元件自帶子件：chip（`AppText.mono` 值 + 移除鈕）× N、加入觸發器 × 1；不接受呼叫端傳入的 widget |
| 子件數量上限 | chip 不設上限（隨 `selected`）；加入觸發器恰 1，恆在最後 |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | chip 與觸發器依序橫排，同列互斥；排不下的子件整個移到下一列，不在列內縮小到最小寬以下 |
| 最小間距 | 水平與垂直皆 `Space.xs`；呼叫端不得覆寫 |
| 空間不足策略 | 主軸（水平）：換列。單一子件寬超過容器寬時，該子件獨佔一列並縮至容器寬，chip 文字截斷（4.52 內容政策）。交叉軸（垂直）：不觸發——高 = 列數 × `LayoutSize.hitTargetMin` + (列數 − 1) × `Space.xs`，不設上限，溢出由 `FieldList` 的垂直捲動承接 |

**最小寬**（§4.0.3「一字元」= 該 slot 字級 1em）：

| 子件 | 最小寬（token 式） | 實機字型代入 | 測試字型（Ahem）代入 |
|------|-------------------|-------------|--------------------|
| chip | `Space.sm` + 一字元 + 省略號 + `Space.xs` + `LayoutSize.hitTargetMin` | ≤ 8 + 24 + 4 + 28 = 64 | 64 |
| 加入觸發器 | `Space.sm` + `LayoutSize.iconMd` + `Space.xs` + 一字元 + 省略號 + `Space.sm` | ≤ 8 + 15 + 4 + 24 + 8 = 59 | 59 |
| **容器最小寬（最大值）** | | **≤ 64** | **64** |

比較對象：`FieldBlock` 值格寬，`kMinWindowSize` 下為 476（5.17、5.18）。64 ≤ 476，成立；本容器的最小寬小於 5.17 既有最大值 83，`FieldBlock` 容器最小寬不變。

### 5.21 AppCheckboxGroup

**對應第 4 章條目**：4.53（1.148 新增，`1.1.0-W1-111`）

#### 子件契約

| 項目 | 值 |
|------|-----|
| 接受的子件類型 | `AppCheckbox`（4.43，`locked`／`enabled` 由本容器下發） |
| 子件數量上限 | 不設上限（隨 `options` 與值域外的 `selected`） |

#### 排列不變式

| 不變式 | 值 |
|--------|-----|
| 不重疊 | 核取項垂直互斥，單欄堆疊；交叉軸（寬）各核取項填滿容器寬 |
| 最小間距 | 0：相鄰核取項的命中區相接，視覺間距由各項自身的高（`LayoutSize.hitTargetMin`）與內距承載；呼叫端不得覆寫 |
| 空間不足策略 | 主軸（垂直）：不觸發——高 = 項數 × `LayoutSize.hitTargetMin`，不設上限，溢出由 `FieldList` 的垂直捲動承接，不內嵌捲動（避免巢狀捲動）。交叉軸（寬）：固定為父格位寬，label 截斷（4.43） |

**最小寬**：`Space.xs` + `LayoutSize.iconLg` + `Space.xs` + 4 × `AppFontSize.body` + `Space.xs` = 77（同 5.17 的 `AppRadioGroup` 列）。比較對象同 5.20：77 ≤ 476，成立；`FieldBlock` 容器最小寬不變。

---

## 6. 原生元件禁用對照表

> 禁止直接使用的原生元件，及應改用的封裝元件。適用範圍：元件庫統一匯出入口（`lib/components/`，W1-005 建立）之外的所有頁面層程式碼；元件庫內部實作原生 widget 屬正常。（`0.1.0-W1-044.2` 填，提案）執法現況（2026-11-05 查證）：PostEdit hook `.claude/hooks/dart-style-guardian-hook.py` 攔下新增的 `TextButton`、`ElevatedButton`、`Card`、`AlertDialog`、`showDialog`、`Divider`、`Chip`、`ChoiceChip` 直用；本表其餘列目前無工具執法，批次掃描腳本 `style_checker.py` 也不偵測既有存量，目前無承接（原規劃的 `0.1.0-W1-046` 已以 not_executable 關閉）。

| 禁止直接使用 | 改用 | 理由 |
|-------------|------|------|
| `Text` / `RichText` / `SelectableText` | `AppText` | 字級與顏色只經 token 變體；內容政策由元件承載（`SelectableText` 只經 `AppText.code`，1.143） |
| `MaterialBanner` | `NoticeBanner`（4.49） | 底色、圖示與播報由元件承載；不經 `ScaffoldMessenger`，固定於所在容器頂端（1.143） |
| `Icon` | `AppIcon` | 尺寸只取具名階；語意標籤規則統一 |
| `Divider` / `VerticalDivider` | `Divider`（本檔 4.3）；側欄與主區分隔為 `AppShell` 內部 | 顏色與線寬統一 |
| `ElevatedButton` / `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton` | `AppButton` | 三變體與 disabled 常駐說明契約；禁 icon-only |
| `Chip` / `ActionChip` / `FilterChip` / `InputChip` | `Badge`（非互動）/ `FilterDropdown`（篩選）/ `ReferenceChips`（表單多值引用，1.148） | 徽章明訂非互動；篩選有自己的狀態集；多值引用的加入與移除各為一次寫入、不樂觀更新 |
| `TextField` / `TextFormField` | `SearchField`（清單搜尋）/ `AppTextInput`（表單欄位，1.140） | 防抖動與清除契約；表單欄位的提交與還原契約 |
| `DropdownButton` / `DropdownMenu` / `PopupMenuButton` / `Autocomplete` | `FilterDropdown`（篩選）/ `AppDropdown`（表單列舉）/ `ReferencePicker`（表單引用）（後兩者 1.140） | 篩選狀態集與播報（待 W1-057）；表單無「全部」項、值域外值的呈現 |
| `Radio` / `RadioListTile` / `RadioGroup`（Flutter） | `AppRadioGroup`（1.140） | 選取等寫入確認才移動標示、鍵盤只移焦點不選取（用戶裁定，`1.0.0-W3-675`） |
| `FormField` / `Form` / `InputDecorator` 自組欄位 | `FieldBlock`（1.140） | label、提示與寫入狀態集中於單一容器 |
| `DataTable`（Material）/ `Table` | `DataTable`（本檔 4.36）+ `TableRow` | 虛擬捲動與欄規格 |
| `ListTile` | `ListRow` | 五變體與兩端固定策略 |
| `Checkbox` / `CheckboxListTile` / `Switch` / `SwitchListTile` | `AppCheckbox`；多個核取項排成清單時用 `AppCheckboxGroup`（1.148） | 文字與核取框同一命中區、朗讀 `checked` 旗標（1.131）；清單的鎖定與值域外值由容器承載 |
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
- [ ] 每個元件的回饋契約（六類事件／動畫 token／時間門檻）已定義
- [ ] 終端回饋元件（本專案：4.26 `AppSnackBar`）已依 §4.0.11 在元件內部記錄顯示／靜默早退／使用者互動三類時刻，且日誌斷言未取代版面可讀性斷言
- [ ] 經終端回饋元件顯示的每個 i18n key 皆符合 §4.0.12 五項（M1 成分／M2 長度與版面保障／M3 placeholder 型別與位置／M4 成敗措辭區分／M5 key 命名），其中 M2 的斷言併入 4.26 測試點既有兩項、未另立測試
- [ ] 每個元件的尺寸契約涵蓋形態因素矩陣的每種尺寸
- [ ] 每個文字 slot 有內容政策（換行 / 最大行數 / 超出處置 / 最長測試文案）
- [ ] 每個元件的 slot 契約已列，文字來源符合〈元件文字歸屬〉
- [ ] 每個元件的組合規則已列，且未另定間距
- [ ] 每個元件的 token 依賴、i18n key、測試點、反例已列
- [ ] 元件清單總表中每個排列關係都有容器元件，容器的排列不變式三項齊全
- [ ] 原生禁用對照表與豁免清單完整
- [ ] 元件文字經中英文溢位測試
- [ ] 容器的排列不變式與「不觸發」判定，代入值分列實機字型與測試字型兩欄（CCD 3.15.0；1.140 起新增條目適用，例 5.17）
- [ ] 編輯用表單元件（4.44–4.48、5.17）的「待決（1.0.0-W3-553.3）」欄位已依編輯狀態定稿回填，提案值已核定（1.143 已回填；§4.0.9 封鎖項待 `1.0.0-W3-553.6` 重驗後解除）
- [ ] 1.143 新增的 4.49 `NoticeBanner`、4.50 `FieldList`（5.18）、4.51 `WriteLogRow`（5.19）與 4.1、4.7、4.27 的修改各有承接的元件票（`component-contract-design` step 5）

---

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.151 | 2026-11-13 | `1.0.0-W3-698`（對齊 SPEC-009 v1.7）：§4.0.6 新增 `validationUnavailableBaselineNotReady`（`unavailable(baselineNotReady)` 的原因）；4.48 提示格與狀態表、4.51 WriteLogRow〈驗證不可用原因〉的原因清單由四種改為五種，4.51〈i18n〉驗證狀態列補新 key，〈內容政策〉最長測試文案改為五種原因 key 中最長者。「部分寫入」列與〈同批檔案〉未動。 |
| 1.150 | 2026-11-13 | `1.1.0-W1-111` Step 4.5 第 3 項（破洞報告的編輯入口，對齊 SPEC-001 v1.93、SPEC-003 v1.97）：4.40 `item` 變體新增可修正破洞項的 trailing：`ButtonRow`（`end`）[`AppButton.text`（`editFieldsAction`，不帶圖示，`action-gaps-edit-<itemId>`，唯讀降級時 disabled）, 開啟原始檔]；slot 契約 `trailing` 接受型別補 `ButtonRow`（限此情形，恰兩鈕）；i18n 朗讀列補兩鈕的 Tab 順序；§3 對照表 §5「有破洞」列與 §4.0.6 `editFieldsAction` 使用處同步；5.14 子件契約補 `ButtonRow`，新增〈可修正破洞項的寬度核對〉（en 最長文案，依通式 Ahem 下列最小寬 439 ≤ `kMinWindowSize` 列寬 724；拉丁字母實機為上界，CJK 不視為上界）與此情形的空間不足策略（primary 截斷吸收、`ButtonRow` 在列內不換行）。4.34 `ButtonRow` 新增 `wrap` 參數（預設 `true`；`false` 只用於 `ListRow.item` trailing）。用途、變體、狀態矩陣來源欄、slot 契約（`wrap` 列，`alignment` 補 `end` 用處）、尺寸契約、組合規則、測試點同步。尺寸契約定義父寬小於固有寬時維持一列，宿主違約的回報直接沿用 `RenderFlex` 的 debug 期溢位回報，不另做自訂回報（避免兩筆回報），release 不記；debug 版 App 經 `installGlobalErrorHandlers` 轉為致命錯誤狀態；不用 `developer.log`，以符合 SPEC-010 FR-04。最大尺寸列排除這種違約情形；也記下實作現況：`Wrap` 在 `ListRow` 內寬度無上限。測試點改為受限父格位下傳與不傳的 E1 對照，以 `tester.takeException()` 取回回報。5.8 空間不足策略補 `wrap: false`，〈不重疊〉的截斷排除 `wrap: false`。5.14 空間不足策略第 2 條的上界改用兩個間距的通式。4.40 測試點補可修正破洞項的形態、寬度與 Tab 順序。§3.1 總表的 `ListRow`、`ButtonRow` 兩列同步。§4.0.9 補 1.150 重驗紀錄（4.40、4.34 依〈契約齊全的定義：六條〉逐條通過）；開頭〈版本〉行補 1.150 摘要。另對齊 SPEC-009 v1.11：4.52 使用處補 UC、EVT `source_proposal`。不新增 key、不新增元件 |
| 1.149 | 2026-11-13 | `1.1.0-W1-111` Step 4.5 第 2 項（`partiallyWritten` 的畫面呈現；以 SPEC-009 v1.10 的操作單位為前提，一次寫入最多兩個檔，部分寫入只會是「反向檔已落檔且還原失敗、正向檔未動」）。<br>- 4.48 新增「部分寫入」狀態：提示格依觸發原因取 `fieldPartiallyWritten`（`ioFailed`，再送一次即可補齊）或 `fieldPartiallyWrittenReloadFirst`（`externallyModified`，各值格 disabled，須先放棄並重讀），接 `fieldSeeWriteLogHint`、錯誤色，值不變；補齊依據是已落檔的反向檔不再列入寫入集合；觸發原因為 `externallyModified` 時另進入外部已改阻擋。提示優先序、等待與結果的失敗段、狀態邊、測試點同步。<br>- 4.51 新增 `batchFiles` slot 與〈同批檔案〉子件（`written` 列出同批寫入的檔，`partiallyWritten` 列出未還原的檔，各附取回指令），寫入結果徽章與說明增 `partiallyWritten`；內容政策、焦點順序、測試點同步。多檔寫入整批一列（SPEC-009 FR-08 Q2）。<br>- 4.52 兩格待決解除（SPEC-009 v1.10 F4：移除刪除全部出現，焦點落點依新清單計算）。<br>- §4.0.6 新增六個 key，帶規格先行標記（`1.1.0-W2-003`）；§4.0.9 寫回 |
| 1.148 | 2026-11-13 | `1.1.0-W1-111` Step 4.5 第 1 項（component-contract-design，起點判定為路徑 A：兩個新元件無實作與呼叫端，來源為 SPEC-009 FR-09 逐欄位表）。<br>- 新增 4.52 `ReferenceChips`（容器，5.20）：FR-09「多值引用（節點 ID）」；加入與移除各為一次立即提交（套用時點四問，與 `1.0.0-W3-675` 同一判法）；找不到的值為值對映參數，提示 `fieldReferenceNotFound`；重複值逐筆顯示，chip 與移除鈕的 key 依位置推導；正向檔多值的寫法待決（SPEC-009 v1.10），`partiallyWritten` 呈現待決（第 2 項）。<br>- 新增 4.53 `AppCheckboxGroup`（容器，5.21）：FR-09「多值引用（domain）」；一次切換為一次立即提交；值域外的值接在最後。<br>- 4.43 `AppCheckbox` 增 `locked`、`enabled`（僅在 4.53 內）。<br>- 4.48 值格清單、`editable`／`readOnly` 判定改為依 FR-09「自」與目前版本，提示格優先序補兩則；5.17 子件類型與最小寬表；4.46〈何時不用〉；§3 兩列；§6 `Chip`、`Checkbox` 兩列。<br>- §4.0.6 新增五個 key，帶規格先行標記（`1.1.0-W2-001`、`1.1.0-W2-002`）。<br>- §4.0.9 寫回重驗結果：4.52 待 SPEC-009 v1.10 與第 2 項。<br>- frontmatter 版號原停在 1.146（1.147 漏改），本版一併更正 |
| 1.147 | 2026-11-12 | `1.1.0-W1-108`：§4.0.6 新增〈規格先行標記〉，定義標記格式與移除時點；讀本表的契約測試對帶標記的列跳過比對 |
| 1.146 | 2026-11-11 | `1.0.0-W3-553.6`：重驗 4.46 第 1 條（1.145 `allowEmpty` 定案後全節無佔位標記），六條通過；§4.0.9〈1.144 的重驗結果〉4.46 列改為可被畫面票引用。4.48 在 1.145 新增「必填空白」後重驗，六條仍通過；補測試點（狀態矩陣列舉、與未送出的優先序、必填空白的對照）與回饋契約 state-change 的狀態邊。至此 4.44–4.51 全部可被畫面票引用 |
| 1.145 | 2026-11-11 | `1.0.0-W3-686`。依用戶裁定 2026-11-11；Q1–Q3 由主控依該裁定推導。<br>**4.46 `ReferencePicker`**<br>- `allowEmpty` 定案：PROP target_version 傳 `true`，SPEC domain 傳 `false`；清空時寫入 `null`，寫法見 SPEC-009 FR-03〈清空〉。<br>- 改寫隔離的引用原誤寫為「SPEC-009 FR-04」，改為 FR-03。<br>- open 態的 `allowEmpty` 首項不參與過濾、固定在首列；覆蓋層算式的 N 含首項；驗收補一條對照。<br>- 修正兩處 `1.0.0-W3-553.6` 刻意留下的殘留：〈新增元件而非併入 `AppDropdown` 的理由〉的列舉上限 8 改為 10；〈`kMinWindowSize` 下的行為〉的可用高扣除 `LayoutSize.titleBarHeight`，改為 288（結論不變：264 ≤ 288）。<br>**4.44 `AppTextInput`**<br>- `onSubmitted`：草稿 trim 後為空時照常呼叫，由呼叫端依 SPEC-009 FR-09〈可否清空〉寫入 `null` 或擋下。<br>**4.48 `FieldBlock`**<br>- 新增「必填空白」狀態，提示格優先序排在寫入失敗之後、未送出之前；i18n 表補一列。<br>**§4.0.6**<br>- 新增〈1.145 新增〉：`fieldRequiredEmpty`。<br>**§4.0.9 重驗**<br>- 4.46 第 1 條待 `1.0.0-W3-553.6` 重驗，結果由該票回寫。 |
| 1.144 | 2026-11-11 | `1.0.0-W3-553.6`（重驗 4.44–4.51、5.17–5.19 與 4.1／4.7／4.27 的 1.143 修改，依 `component-contract-design` step 4〈契約齊全的定義〉）：§4.0.9 新增〈1.144 的重驗結果〉，4.44、4.45、4.47–4.51 與 4.1／4.7／4.27 的修改通過，4.46 因 `allowEmpty` 待決（1.0.0-W3-686）未通過。`options` 上限依用戶裁定 2026-11-11：4.45 定為推導值 10（`kMinWindowSize` 下 N × 28 + 8 ≤ 288），4.47 不設上限、下限 2；4.45、4.47 的「何時不用」「反例」與 §3.1 總表把「超過 8 項」的數量判準改為 SPEC-009 FR-09 的功能判準，測試點同步。重驗中補齊的缺口：4.48、4.49、4.50 操作機制空白格改為「不適用」加理由（與 4.27、4.28、4.31、4.41 同寫法）；4.49 對比回填 5.17:1、4.94:1；4.51 內容政策補三列最長測試文案；4.45 `kMinWindowSize` 選單算式扣除標題列（306 → 288，結論不變） |
| 1.143 | 2026-11-11 | `1.0.0-W3-553.3.1`（依 SPEC-001 v1.89 §1、§6〈編輯模式〉、§12 與 SPEC-003 v1.94 §2.9、§2.14 列 23–25、§3.6、§3.12；`component-contract-design` 3.17.0）：新增 4.49 `NoticeBanner`（`warning`／`negative`，編輯區頂端橫幅）、4.50 `FieldList`（容器，橫幅 + `FieldBlock` × N + 完成，承載寫入期間的跨欄鎖定；§5.18）、4.51 `WriteLogRow`（容器，寫入清單列；§5.19）；4.1 `AppText` 加 `code` 變體（等寬、換行、可選取，取回指令）；4.7 `NavItem` 加 `badge` slot，4.5 `Badge.count` 加寫入清單失敗計數用途；4.27 `AppShell` 側欄底部改為三項（加 `nav-action-writeLog`，算式改為 388 ≤ 580）並加唯讀降級徽章 `badge-<screen>-readonly-workspace`。4.44–4.48 回填 1.140 的「待決（1.0.0-W3-553.3）」欄位：出現畫面、error／disabled 進入條件、套用時點第 2、4 問、回饋契約 locate／state-change／等待與結果、錨點（改用 SPEC-003 §2.9 既有類別，`action-`／`menu-`／`option-`／`badge-nodeDetail-field-<fieldKey>…`）、4.48 狀態矩陣全列（含新增的「未送出」與提示格優先序）、`label` 不進 i18n、父容器定為 `FieldList`；4.44–4.47 新增 locked 狀態列。依用戶裁定 2026-11-11（`1.0.0-W3-553.3.1`）：題 1 失焦保留草稿並標示未送出；題 2 寫入與驗證結果不移動焦點、以提示格與 `liveRegion` 承載，寫入期間值格改用唯讀鎖定（`locked`）而不用 disabled（(e)，主控採用）；題 3 欄位依 SPEC-009 FR-09 表列序排列，Tab 順序為放棄並重讀 → 可編輯值格 → 完成。§3.1 總表補三列並修改四列，定案數改為元件 32、容器 19；§3.6 對照表補 §6 三列與 §12 兩列（共 60 列，與 SPEC-001〈狀態總數〉一致），§6 正常列補「編輯欄位」鈕與讀取失敗說明；§4.0.6 新增〈1.143 新增〉表；§4.0.9 記 1.143 狀態（待 `1.0.0-W3-553.6` 重驗）；5.17 父格位改為 `FieldList`（476）；§9 新增一項驗收。4.46 `allowEmpty` 對 PROP target_version 的預設改標待決（1.0.0-W3-686），不屬編輯狀態。同版依主控審查：§3.6 §6「編輯中」列與 4.50〈取代範圍〉改寫為取代分隔線以上整區 |
| 1.142 | 2026-11-11 | `1.0.0-W3-676`（用戶裁定 2026-11-11，對應 SPEC-009 v1.2）：4.48 `FieldBlock` 回饋契約〈等待與結果〉的逾時段由待決改為定案——寫入不另設逾時結局，`git` 子行程 5 秒逾時落入失敗（`snapshotFailed`）或走快照分支，本地 IO 不設逾時；驗證子行程 30 秒逾時落入服務不可用（`unavailable(timedOut)`）；時間門檻欄填入兩個值。§4.0.9 封鎖項與 4.44 前言移除逾時段，解除條件只剩 `1.0.0-W3-553.3` |
| 1.141 | 2026-11-11 | `1.0.0-W3-673.1`（`1.0.0-W3-673` 判定 F-4：元件組成已要求內文不含 frontmatter，但 slot 來源寫「檔案內容」，實作依 slot 表傳入整檔）：4.20 `DocumentBody` slot 契約的 `markdown` 來源改為 frontmatter 結尾分隔線之後的本文，切分規則同 SPEC-006 FR-01 規則 1–4；新增〈本文來源的界線〉：不得傳入整檔，讀取或切分失敗時頁面層改放 `AppText.body`（`nodeDetailBodyUnavailableMessage`），不退回整檔、不以標題代替；狀態矩陣同步策略欄與 i18n 子節同步。§3.6 §6 正常列顯示欄同步；§4.0.6 新增〈1.141 新增〉一個 key。對應 SPEC-001 v1.87 |
| 1.140 | 2026-11-11 | `1.0.0-W3-553.6`（依 SPEC-009 FR-09，`component-contract-design` step 2～4 路徑 A）：新增編輯用表單元件 4.44 `AppTextInput`（`singleLine`／`multiLine`）、4.45 `AppDropdown`、4.46 `ReferencePicker`、4.47 `AppRadioGroup` 與容器 4.48 `FieldBlock`（`editable`／`readOnly`），§5 新增 5.17（交叉軸代入值分實機字型與測試字型兩欄）；各條目記不沿用 `SearchField`／`FilterDropdown`／`SegmentedControl`／`AppCheckbox`／`ListRow.option` 的理由。依賴編輯狀態的子節與欄標「待決（1.0.0-W3-553.3）」，outOfDomain 呈現、單選方向與鍵盤、文字失焦提交為提案；§4.0.9 登記封鎖項。§3.1 總表補五列與定案數註記；§4.0.6 新增〈1.140 新增〉表六個 key（zh／en 提案，ARB 由元件票建立）；§6 `TextField`、`DropdownButton` 兩列補表單對應元件並新增 `Radio`、`FormField` 兩列；§9 新增兩項驗收。未改既有元件契約。同版經用戶裁定（2026-11-11，`1.0.0-W3-675`）定案四項：逐欄立即提交、outOfDomain 觸發器顯示原值並以提示格註明、`AppRadioGroup` 恆垂直、↑↓ 只移焦點且 Space 選取；文字失焦提交、錨點命名、欄位堆疊父容器仍為提案，隨 `1.0.0-W3-553.3` 裁定；4.48 逾時段待 `1.0.0-W3-676`。兩者完成前本組條目不可被畫面票引用 |
| 1.139 | 2026-11-10 | `1.0.0-W3-553.1`：§2 樂觀更新政策列對編輯能力規格的引用改為指名 SPEC-009 FR-05（原寫「edit domain 的編輯能力規格」，當時 SPEC-009 尚未建立）。條文不變 |
| 1.138 | 2026-11-10 | 引用字面更正（`1.0.0-W1-110` 停放票分診，用戶裁決移入 1.1.0 候選池）：4.6 `IssueMarker` default 列「恢復條件見 SPEC-001 §6」的票 ID 由 `1.0.0-W3-656` 改為 `1.1.0-W3-656`；變更歷史列保留原文。條文不變 |
| 1.137 | 2026-11-10 | `1.0.0-W3-553`（用戶裁定，1.0 編輯能力四項架構決策）：§2 樂觀更新政策列由「0.x 不允許（提案）＋ 1.0 規劃時重評」改為「0.x 與 1.0 皆不允許」；1.0 寫入等位元組落檔才顯示新值，CLI 驗證結果以獨立的驗證狀態呈現（進行中 → 通過／失敗），驗證失敗不自動回滾；三個可觀測時刻與寫入結果型別改由 edit domain 的編輯能力規格定義；刪除原重評條件與「允許類別限低風險可逆欄位」的預想。決策依據見 `docs/tech-decisions.md`〈補記：2026-11-10 — 1.0 編輯能力四項架構決策定案〉。未新增元件與 i18n key |
| 1.136 | 2026-11-10 | `0.7.0-W1-007.6`（補 `0.7.0-W1-007.4` 回報的 SPEC-003 §3.10 三項缺口）：4.30 `Panel.scrollable` 新增 optional `footer` slot〈固定底部 slot〉（不隨捲動、不傳時版面不變，含 `kMinWindowSize` 下的尺寸算式），偏好設定面板與鍵盤快捷鍵面板的關閉鈕改放 `footer`（§3.6 §9、§11 兩列同步）；4.4 `AppButton` 新增〈開啟時取得焦點〉`autofocus` 參數；4.7 `NavItem` 新增〈`action` 變體的焦點節點〉`focusNode` 參數供面板關閉後焦點歸位；正文版本行由 1.133 修正。未新增元件與 i18n key |
| 1.135 | 2026-11-10 | `0.7.0-W1-012.18`（用戶裁決，承 `0.7.0-W1-012.12` 合併閘門 `real_font_layout_test` history 兩案紅燈）：4.32 子件列高 `hitTargetMin` 與 4.10 元件固有高 `hitTargetMin` + 2 × `Space.xxs` 互斥。4.10 尺寸契約分清段高 `hitTargetMin`（命中區）與元件固有高；4.32 `history` 子件列高改為 `hitTargetMin` + 2 × `Space.xxs`、框體高加 2 × `Space.xs`，`default` 不變；5.6 `history` 空間不足策略由「不觸發」改為期間選擇取有界寬、超出時各段 label 截斷，刪除「合計不到可用寬的一半」斷言；篩選列不再以縮放吸收超寬。 |
| 1.134 | 2026-11-09 | 登記節點詳情來源鏈（對應 SPEC-001 v1.84 §6〈來源鏈〉、SPEC-003 v1.88 §3.6〈來源鏈〉與 §2.9）：4.39 `Tree` 新增 `sourceChain` 變體（恆全部展開、無展開器、不持有展開集合；選擇理由、承載位置、尺寸約束、節點列、缺上游列、不渲染條件、資料來源），總表同步；4.40 `ListRow.tree` 補來源鏈列行為、`testKey` 與 i18n；§3.6 §6 正常列組成補 `Section.static`[`Tree.sourceChain`]；§4.0.6 新增 `sourceChainTitle`、`sourceChainNoUpstream`（zh／en）。ARB 同批 |
| 1.133 | 2026-11-09 | `0.7.0-W1-007.1`（`0.7.0-W1-007` 用戶裁決三項，對應 SPEC-001 v1.83、SPEC-003 v1.86）：4.27 `AppShell` 新增〈側欄底部 slot〉（設定、鍵盤快捷鍵兩項的順序、動作、錨點、Tab 順序接在七個導覽項之後、`kMinWindowSize` 下不溢位的 token 算式），slot 表增 `bottomItems`，焦點路徑三區段改四區段，i18n 與測試點同步；4.7 `NavItem` 增 `action` 變體（恆 unselected、不改導覽狀態）；4.40 `ListRow` 增 `shortcut` 變體（按鍵、作用、情境）；§3.6 補 SPEC-001 §11「快捷鍵清單」一列（`Panel.scrollable` + `ListRow.shortcut`）；§4.0.6 新增〈1.133 新增〉表登記 20 個 key，並註明主選單標題不進 ARB。未新增元件 |
| 1.132 | 2026-11-09 | `0.7.0-W1-009.1`（對應 SPEC-003 v1.85 §3.8、§2.13 列 20／21）：§4.0.6 新增兩 key 並登記 zh／en 與用處，4.26 `AppSnackBar` `message` 呼叫端清單補兩 key；ARB 同批 |
| 1.131 | 2026-11-09 | `0.7.0-W1-012.2`（對應 SPEC-001 v1.80 §10、SPEC-003 v1.83 §3.9、SPEC-008 FR-06～FR-09）：補齊第七畫面變更記錄的元件。新增 4.43 `AppCheckbox`（「包含 ticket 建檔」，`AppButton`／`SegmentedControl`／`ListRow.option`／`FilterDropdown` 不適用的理由記於該條）；4.10 `SegmentedControl` 段數由恰 2 放寬為 2–3，承載期間選擇（`option-history-period-<period>`，不用 `FilterDropdown` 的理由記於該條）；4.35 `TableRow` 增 `historyEvent` 變體（七欄，沿用既有寬度 token，`kMinWindowSize` 代入值記於 5.9）；4.32 `Toolbar` 增 `history` 變體（5.6 同步）；4.19 `RelationItem` 承載事件列節點（`action-history-open-<index>-<side>`，domain 名稱對端改 `AppText.mono`）；4.5 `Badge.category` 承載變動欄與淺層 clone 標示（`badge-history-shallow-clone`）；4.24 `LoadingState` 增版位 `rows`；4.21 `EmptyState` 補 §10 用法與讀取失敗等三態不用 `BlockedState` 的例外；4.30 `Panel` 的 `leading` 接受 `BadgeRow`、`panelKey` 接受 `state-history-normal`／`state-history-empty`；4.36 `DataTable` 增 `scroll-history-events`（5.10 同步）；§3.1 總表補列並把元件定案數改為 27；§3.2、§3.4、4.27、5.1 側欄與主區由 6 改為 7；§3.6 補 §10 八列；§4.0.6 登記新 key；§6 補 `Checkbox` 類禁用列；frontmatter 補 UC-07、SPEC-008。`depends_on_domains` 不變 |
| 1.130 | 2026-11-09 | `0.7.0-W1-012.1`（SPEC-003 v1.83 第七畫面同步）：4.27 `AppShell` state-change 列對 SPEC-003 §2.8 錨點的逐字引用「六頁建構時機」改為「七頁建構時機」。其餘第七畫面元件與 §3.6 對照表補列不在本版 |
| 1.129 | 2026-11-09 | `0.7.0-W1-008.1`（`0.7.0-W1-008` 用戶裁決：元件契約新增「套用時點」欄，只適用選擇類元件，判準為 `component-contract-design` skill v3.14.0〈套用時點的四問〉）：4.10 `SegmentedControl`、4.13 `FilterDropdown`、4.14 `TableColumnHeader`（限 `sortable`）、4.15 `MatrixCell`、4.40 `ListRow`（限 `option`）各在回饋契約前新增〈套用時點〉子節。前四者與 4.40 的 UC 選擇入口皆為立即提交、生效當下可見；4.40 的偏好設定面板編輯器選項為立即提交、選取即關閉、生效當下不可見，關閉時以暫態提示告知生效範圍。4.7 `NavItem`、4.8 `ProjectSwitcherEntry`、4.9 `RecentProjectItem` 的選取會執行導覽或開浮層，第 1 問判為動作，不填此欄。不改既有回饋契約列。正文版號行由 1.126 補記至本版 |
| 1.128 | 2026-11-09 | `0.6.0-W1-202`（來源含 `0.6.0-W1-196`，主控裁決方案 A：元件一律傳值，訂閱在上層）：4.15 `MatrixCell` default 列資料態欄與 state-change 列改為畫面層 watch 後經 `MatrixGrid` 傳值，不再寫 `ConsumerWidget`、§2 容器例外、`ref.listen`。§2「導覽狀態」列、4.27 `AppShell` 用途段、default 列、state-change 列改為元件庫 `AppShell` 傳值、訂閱由組裝層 `lib/assembly/shell.dart` 承擔（`ref.watch` 後傳值），刪除「實作雛形」一句（含元件樹表 AppShell 列同款句）；4.42 專案切換浮層 state-change 列同款敘述同步改。不改 key 表與條文編號 |
| 1.127 | 2026-11-06 | `0.6.0-W1-193.1`（`0.6.0-W1-193` 用戶裁決 D 案）：§2 刪除「容器元件的例外」列，「元件接收狀態形式」列明寫資料視圖容器同樣傳值 + callback；「最小重繪邊界」列改為畫面層 `ref.watch(provider.select(...))`、元件與容器不 watch；「過渡提示觸發點」列刪除容器自行 `ref.listen` 的分支。4.36 `DataTable`、4.37 `MatrixGrid`、4.38 `SwimlaneGrid`、4.39 `Tree` 的用途段、狀態矩陣來源欄與 state-change 列改為傳值，觸發方改為畫面層；4.36–4.38 寫明 offset 由頁面層持有的 `ScrollController` 傳入容器，排序歸零與切換專案重置由頁面層呼叫，4.38 不自行建立 controller，`jumpTo` 定位須重新驗證。4.16 與 4.39〈由本容器計算的理由〉同步刪除對容器例外的引用。§3.7 第 19 列補註裁決。§2「導覽狀態」列與 4.27 `AppShell` 的 `ConsumerWidget` 敘述不在本次範圍，另由 `0.6.0-W1-196` 追蹤 |
| 1.126 | 2026-11-05 | `0.6.0-W1-191.2`（依 `0.6.0-W1-191` 時效型註記盤點，讀碼查證）：狀態矩陣「來源」欄與相關散文 19 處「provider 尚未建立，欄位名由對應畫面票補填」改為實際承載者（4.4、4.6、4.10、4.12–4.15、4.18–4.24、4.32、4.36–4.38、4.41）；Ticket 清單無載入態、節點詳情損壞外觀在 0.x 不可達者改寫為不渲染。§6 原寫「執法 pattern 由 `dart-style-guardian` 承接」，改為執法現況：PostEdit hook 攔八種新增直用，其餘列目前無承接。不改契約；4.36–4.38「本容器為 `ConsumerWidget`」與實作（傳值、不自行訂閱）不一致，另票處理 |
| 1.125 | 2026-11-05 | `0.6.0-W1-191.1`（依 `0.6.0-W1-191` 時效型註記盤點）：§4.0.6 各批次說明與表列「使用處」欄的「ARB 待建」「ARB 實檔狀態待建，由對應票加入」改為現況（表內 key 全數已在 ARB，`spec004_key_table_contract_test` 的待加入豁免為空可證），淘汰 key 段改為「已自 ARB 刪除」；§4.0 測試基座「由 `0.1.0-W1-034` 承接，為所有元件票的 blockedBy」改為已建立；4.37 `MatrixGrid`「依賴宣告待 `0.1.0-W1-038`」改為 `pubspec.yaml` 已宣告。zh／en 值欄未動，不改契約 |
| 1.124 | 2026-11-05 | `0.6.0-W1-086.1`（依 `0.6.0-W1-086` 規則 7 盤點）：三處依賴型票號引用改寫為定案內容，不改契約。§3.5 漂移表「畫布頂端標題列高 36…」列列出對應的 `LayoutSize` token 名；§4.0.6〈EVT-CORPUS-003 項目說明〉前導句的「原因碼識別名未定」改為列出 `CarrierParseFailureReason` 與 `UnreadableReason` 的識別名；4.35〈尺寸契約〉最小尺寸列的「截斷或換行的責任歸屬待裁決」改為 4.1〈內容政策〉已定案的呼叫端明示規則。frontmatter 版號由 1.122 對齊至本版（原與正文 1.123 不一致） |
| 1.123 | 2026-11-04 | `0.6.0-W1-075.2`（對應 SPEC-001 v1.78、UC-02 v1.16）：§4.0.6 登記 `pathDeclarationBundlesMalformed`（{count} 個 domain 的路徑宣告格式錯誤），宣告狀態行 `{detail}` 的 bundle 格式錯誤片段，接在 bundle 側片段之後；ARB 同批建立。不新增元件，狀態總數不變 |
| 1.122 | 2026-11-04 | `0.6.0-W1-070.2`（對應 SPEC-001 v1.76、SPEC-003 v1.82）：§3.6 對照表補 SPEC-001 §9 兩列（編輯器清單、無可選編輯器，歸屬 `Panel.scrollable` + `ListRow.option`）；§4.0.6 新增〈1.122 新增〉表登記 `openedWithoutEditorMessage`、`preferencesTitle`、`preferencesEditorSystemOption`、`preferencesNoEditorsExplanation` 四個 key，與 zh／en ARB 同批 |
| 1.121 | 2026-11-04 | `0.6.0-W1-152.1`（用戶裁定）：§4.0.6 `degradedSchemaBadgeLabel` 列 zh／en 改為 ARB 現值（保留「降級」一詞）；新增補登表登記 `eventOutsideUcBare`、`scanCompleteUndeterminableNotificationBody`、`scanCompleteUndeterminableSnackbarMessage`；`ucSelectorTitle` en、`swimlaneUcUnsetPrompt` zh／en、`swimlaneProjectionPendingPrompt` zh 以規格為準，ARB 同批改齊，規格列不動 |
| 1.120 | 2026-11-04 | `0.6.0-W1-019.1`：4.9 `RecentProjectItem` disabled 列進入條件拆為探測逾時（`probeTimeoutReason`，逾時值引 SPEC-005 §2.5）與探測判定不可讀或不存在（`WorkspaceUnavailable.reason`，與點選失敗同源）；內容政策表後補表外說明 `reason` 兩種取值。§4.0.6 與各綁定 ARB 的表列未動（PC-GPD-075）。來源 `0.6.0-W1-019` 用戶裁決 |
| 1.119 | 2026-11-03 | `0.6.0-W1-018.1`：4.9 `RecentProjectItem` 狀態矩陣 enabled／selected／disabled 來源欄與回饋契約狀態變更提示列，陳舊的 `RecentProjectFixture`／`currentProjectIndexProvider` 更正為 `recentProjectsProvider`（`StateProvider<List<RecentProject>>`）、`switcherUnavailableProjectsProvider`、`currentWorkspaceStateProvider`；新增〈無計數快照〉段，slot `summary` 改選填、朗讀標籤補無摘要形；正文版號行補記 1.118。對應 SPEC-001 v1.74、SPEC-005 v1.4 |
| 1.118 | 2026-11-03 | `0.6.0-W1-108`：退役 `LoadPrompt`（4.25 改為已退役標示）與 `LoadingState.progressBar` 變體（4.24 變體列、slot `progress`、無障礙與測試點同步刪除）；§3.1 總表、反例、容器接受清單移除 `LoadPrompt`；§4.0.6 刪 `progressA11yLabel`、`traceabilityTicketsNotLoadedHint`、`gotoTicketsListAction`；`ticketsLoadPrompt`、`ticketsLoadingProgress` 隨元件移除。lib 與 ARB 同批 |
| 1.117 | 2026-11-03 | `0.6.0-W1-113.3`：§4.0.6 新增 `ticketsNoTopicFilesNotice`（此專案無主題檔 / This project has no topic files），Ticket 清單主題模式指派檔不存在時的頂部說明列；ARB 同批，對應 SPEC-001 v1.73 |
| 1.116 | 2026-11-03 | `0.6.0-W1-113.2`：§4.0.6 將 1.115 以表外敘述登記的三個 key 加入表列（分節標籤表加 `gapCategoryTopicFilesMalformed`，新增「EVT-CORPUS-006 項目說明」表列 `gapTopicFilesUnreadable`、`gapTopicFilesUnregisteredTopics`），文案逐字沿用；刪除「暫不列入」敘述；ARB 與 P7 契約測試計數（32 → 35）同批 |
| 1.115 | 2026-11-03 | 對齊 SPEC-001 v1.69（`0.6.0-W1-112`，EVT-CORPUS-006 同批建立）：§4.0.6 以表外敘述登記分節標籤 `gapCategoryTopicFilesMalformed` 與項目說明 `gapTopicFilesUnreadable`、`gapTopicFilesUnregisteredTopics`（ICU plural）的定案文案；不列入 key 表，表列、ARB 與 P7 契約測試計數由 `0.6.0-W1-113` 同批加入（P7 逐列比對 key 表與 ARB，表列先行會使閘門翻紅） |
| 1.114 | 2026-11-02 | 對齊 SPEC-001 v1.67、SPEC-003 v1.76（`0.6.0-W1-110`，追溯視圖接真資料）：§3.6 對照表補 §3「圖不可用」（`EmptyState.page`，動作前往 Domain 視圖，不設重新掃描）、§3 正常列補父子取自最後完成輪次的三條邊；§4.0.6 新增〈1.114 新增〉`traceabilityGraphUnavailableMessage`（提案文案）；§3.1 總表與 4.21〈出現畫面〉`EmptyState` 補 §3 圖不可用；4.21〈出現畫面〉另補 1.113 漏列的 §6「圖不可用」「節點不在目前的圖上」 |
| 1.113 | 2026-11-02 | 對齊 SPEC-001 v1.65、SPEC-003 v1.75（`0.6.0-W1-105.2`，依 `0.6.0-W1-105` 缺口 G-N1、G-N2 與用戶裁定 2026-11-02）：§3.6 對照表補 §6「圖不可用」（`EmptyState.page`，動作前往 Domain 視圖，不設重新掃描）、「節點不在目前的圖上」（`EmptyState.page`，動作前往追溯視圖，不用 `MissingSourceState`）兩列；§4.0.6 新增〈1.113 新增〉表 `nodeDetailGraphUnavailableMessage`、`nodeDetailNodeAbsentMessage`、`nodeDetailNodeAbsentHint`（提案文案）；§3.1 總表 `EmptyState` 出現畫面補兩態；正文版本行補記 1.112 漏更新 |
| 1.112 | 2026-11-02 | 對齊 SPEC-001 v1.64、SPEC-003 v1.74（`0.6.0-W1-105.1`，Ticket 清單改由掃描輪次衍生，用戶裁定 2026-11-02）：§3.6 刪 §4「未載入」「載入中」兩列；§3 正常、鏈路斷裂兩列刪「Ticket 清單未載入時」常駐說明列；§3.1 總表 `LoadingState` 出現畫面刪 §4、`progressBar` 標無使用畫面，`LoadPrompt` 出現畫面改「無」；4.24 出現畫面、`progressBar` 變體列、cancelling 目標態與等待與結果列刪 Ticket 載入；4.25 開頭加無使用畫面註記；4.23 何時不用刪 `LoadPrompt` 一項；Ticket 清單容器的資料態描述改指掃描輪次；i18n 表 `traceabilityTicketsNotLoadedHint`、`gotoTicketsListAction` 標無使用處。元件與 key 的退役（含 lib）由 `0.6.0-W1-105.1` 的 spawn request 承接 |
| 1.111 | 2026-10-31 | `0.5.0-W1-573`（承 `0.5.0-W1-572` 驗收發現）：4.32 `Toolbar` 尺寸模式列「高固定 `hitTargetMin` + 2 × `Space.xs`」與間距列「底部內距 `Space.sm`」判定為措辭歧義而非矛盾：兩列指不同對象。前者是含底邊框的框體高（框體內上下內距各 `Space.xs`），後者是框體下方、底邊框之外與後續內容的間距，不計入固定高；原文「內距」一詞使後者讀似落在框體內。兩列改寫為指明各自對象，間距列補列框體上下內距 `Space.xs`。對照 `lib/components/toolbar.dart`（`0.5.0-W1-572` 修正後）一致，可見行為不變 |
| 1.110 | 2026-10-31 | `0.5.0-W1-513.1.1`（用戶裁定以 SPEC-003 為準，`0.5.0-W1-513.1`）：§3.7 出處補記第 18 項重新掃描鈕由「無破洞與有破洞兩狀態」改為「無破洞、有破洞與無法判定破洞三狀態」（三種原因皆顯示，`action-gaps-rescan` → `state-gaps-scanning`）；§3.6 §5 無法判定破洞列原已要求該鈕，不改；`GapReportHeaderTrailing` 顯示條件同步 |
| 1.109 | 2026-10-30 | 引用字面更正（`0.5.0-W1-213.7`）：`lib/app/shell.dart` 改為現址 `lib/assembly/shell.dart`（組裝根移出 `lib/app`，`0.5.0-W1-213.2`）、`lib/screens/project_switcher/project_switcher_providers.dart` 改為 `lib/app/project_switcher_providers.dart`（`0.5.0-W1-213.4`）；只改路徑字面，不改判斷敘述。正文版號行同步補 1.108、1.109 敘述（先前停在 1.107） |
| 1.108 | 2026-10-30 | 4.22 `MissingSourceState` 回饋契約隨 SPEC-003 v1.69 同步（`0.5.0-W1-540.1.2`，依 `0.5.0-W1-540.1` 用戶裁決 C 與問題 1 裁決 A）：「按下確認」與「等待與結果」兩列的重新解析分支補「存在但 frontmatter 解析失敗 → 維持本狀態 + `AppSnackBar.plain`（`sourceFileUnparsableMessage`）」，「斷點 → `state-nodeDetail-partial`」標為 0.x 不可達。元件本身不變 |
| 1.107 | 2026-10-30 | 泳道列高亮改以 domain id 指定（`0.5.0-W1-209`，承 `0.5.0-W1-114.21` Phase 4 審查）：4.38 `SwimlaneGrid` slot `laneHighlight` 的值由「選取 domain 的列首字面」改為選取 domain 的 domainId，以 `Lane.domainId` 精確比對、列首字面不參與比對（同一 domain 字面可對應多個 bundle，字面比對會同時高亮多列，且畫面須以名稱反查）；slot 名稱不變。測試點新增「兩列同字面只高亮 domainId 相符的一列」與 E1 對照 |
| 1.106 | 2026-10-29 | 停用原因由同區文案承載（`0.5.0-W1-503.1`，承 `0.5.0-W1-503` 用戶裁決 A）：4.4 `AppButton` 新增 slot `reasonShownNearby`（`bool`，預設 `false`）與〈停用原因由同區文案承載〉段，適用條件兩項（承載文案同區常駐可見、朗讀順序與按鈕相鄰），FR-06 (b) 未接線停用不適用；`disabledReason` 契約改為停用時須為非空字串或宣告旗標，明寫空字串不合法（原兩處以空字串滿足必填，使停用分支渲染空 caption、間距與空 hint）；disabled 列資料態「0.1 唯一停用場景」過期，改列 4.24 取消鈕與 `action-domain-rescan`（`0.5.0-W1-486.2` 引入）兩場景；回饋契約狀態變更提示列、無障礙狀態變化播報列、測試點同步 |
| 1.105 | 2026-10-29 | 切換專案時暫態提示的退出路徑（`0.5.0-W1-168.1`，承 `0.5.0-W1-168` 用戶裁決 A，對應 SPEC-003 v1.68 §2.8 切換專案（L2）列）：4.26 `AppSnackBar` 狀態矩陣 shown 列與回饋契約「狀態變更提示」列的 shown→dismissed 退出路徑補「專案改變」（`plain`、`withAction` 一律立即退出）；回饋契約「狀態變更提示」列反應欄補「切換前發出、切換後才回來的結果不 `show`，只留痕」，與既有「取消完成不得顯示（C5）」並列；測試點補「專案改變後顯示中的 `plain` 與 `withAction` 皆立即消失」。規格只寫不呈現、只留痕，不規定判定機制 |
| 1.104 | 2026-10-28 | `0.5.0-W1-508.8` 合併後（主控裁決，`0.5.0-W1-508` 收尾）：4.1 截斷責任歸屬句原寫「過渡期保留的預設建構子維持舊行為……於 `0.5.0-W1-508.8` 移除」，改為「預設建構子已於 `0.5.0-W1-508.8` 移除，未明示行數政策的呼叫在編譯期報錯」，使規格與程式的行數政策一致 |
| 1.103 | 2026-10-28 | `0.5.0-W1-508.14.1`（用戶裁決 508.14 方案 A）：§3.6 §1 正常 · 泳道的解析失敗提示與 §4.0.6 `swimlaneFlowParseFailedHint` 使用處，由 `AppText.caption` 改為 `AppText.multiLine`（`maxLines: 2`、`secondary: true`）；此句約 80 字元，caption 單行在窄視窗會截掉「只呈現第一個合法區塊」，multiLine 只支援 body，maxLines 取 2 與 4.42、4.9 的 reason 一致 |
| 1.102 | 2026-10-28 | `0.5.0-W1-508.1`（用戶裁定 508 方案 C）：4.1 `AppText` `body` 行數政策改為必須明示——新增 `AppText.multiLine`（`maxLines` 必填）與 `AppText.singleLine`；變體表、內容政策表同步，並寫明截斷責任歸呼叫端。4.40 `ListRow` 內容政策補截斷責任歸屬與 `copyWithModifiers` 重染保留政策。預設建構子過渡保留至 `0.5.0-W1-508.8` |
| 1.101 | 2026-10-27 | `0.5.0-W3-008` 條文追認（依實作讀碼，未實機，不改行為）：4.14 `TableColumnHeader` `sortable` 最小寬補 label 與排序指示間 `Space.xs`（排序中才計）；4.24 `LoadingState` 最小尺寸補自身內距 2 × `Space.md`、訊息與取消鈕間 `Space.sm`、骨架與訊息列間 `Space.sm`，`countText` 為可換行不計入；4.26 `AppSnackBar` 內距指名水平 2 × `Space.md`／垂直 2 × `Space.sm`，`withAction` 補 `Space.sm` 與動作 label 最小寬（2 × `Space.xs` + 一字元 + 省略號）及 3：1 分寬；4.35 `TableRow` 填滿欄由單數改為各變體兩個填滿欄依 flex 比例計算所需寬，`step` 事件欄取 4.33 `BadgeRow` 最小寬；4.21 `EmptyState`〈何時不用〉與反例表補「專案資料載入失敗」改用 `BlockedState`（ticket 記為 4.22，實際位於 4.21）。4.29／4.35／4.40 主文字截斷或換行的責任歸屬未改，候選待用戶裁決 |
| 1.100 | 2026-10-27 | `0.5.0-W1-486.1` 修正（對齊 SPEC-001 v1.58，用戶裁定 2026-10-27；SPEC-003 v1.67 同批）：§3.6「圖不可用」列補掃描輪次進行期間的列內呈現——`EmptyState.section` 訊息換成 `domainGraphUnavailableScanning`、附計數文字 `gapsScanningProcessedCount`（indeterminate），重新掃描 disabled，結束後換回原因文字或離開本列；§4.0.6〈1.99 新增〉表補 `domainGraphUnavailableScanning`（提案文案）；正文版本行補記 1.99 漏寫的「頁首模式切換渲染範圍」 |
| 1.99 | 2026-10-27 | `0.5.0-W1-486.1`（對齊 SPEC-001 v1.57 §1 新增「圖不可用」，`0.5.0-W1-486` 用戶裁定 B+；SPEC-003 v1.66 同批）：§3.6 對照表補一列（`EmptyState.section` 帶 `AppButton.secondary` 重新掃描 `action-domain-rescan`，矩陣與泳道同一組成）；§4.0.6 新增〈1.99 新增〉表 `domainGraphUnavailableMessage`（placeholder `appVersion`，提案文案；原因與載入當下阻擋態同一 reason，並說明型別表未修正前重掃仍不可用）；動作沿用 `rescanAction`；4.21 `EmptyState` 出現畫面與 `section` 變體、頁首模式切換渲染範圍補本狀態 |
| 1.98 | 2026-10-21 | `0.5.0-W1-205.1`（對齊 SPEC-001 v1.55 §1 新增「泳道 · 投影準備中」）：§3.6 對照表補一列（`Panel`[`AppText.subtitle`, `EmptyState.section`, `SwimlaneGrid` 零節點]）；§4.0.6〈1.35 新增〉表新增 `swimlaneProjectionPendingPrompt`（提案文案）；`EmptyState` 出現畫面兩處、頁首模式切換渲染範圍、4.38 `SwimlaneGrid` default 建構狀態補本狀態 |
| 1.97 | 2026-10-21 | `0.5.0-W1-459`：§4.0.6〈1.80 提案〉`gapCategoryGraphDefectFlow` 使用處欄與 4.30 定位場景 (g) 的「flow 四子類」改為「flow 各子類」（1.96 新增「事件引用未解析」後兩處未同步）。文案、key 與行為不變 |
| 1.96 | 2026-10-21 | `0.5.0-W1-458.3`（SPEC-007 v1.34、SPEC-001 v1.54、SPEC-003 v1.62 同批，`0.5.0-W1-458` 用戶裁決題 E）：§4.0.6 新增〈1.96 新增〉表——`gapFlowEventUnresolved`（stepId、field、value），flow 子類「事件引用未解析」的項目說明；分節標籤沿用 `gapCategoryGraphDefectFlow`。key 與 zh／en 文案 PM 確認，比照 1.80／1.94 先例；ARB 由 `0.5.0-W1-458.4` 建立。不新增元件，狀態總數不變 |
| 1.95 | 2026-10-21 | `0.5.0-W1-167.3`（承 `0.5.0-W1-167.2` 實作回報）：4.42 內容政策表 `chooseOtherFailureReason` 字級由 `AppText.caption` 改為 `AppText` body 字級、tone `textSecondary`。理由：4.1 `caption` 變體恆為單行，與同列「可換行、最多 2 行」矛盾；4.9 `reason` 同為浮層內 2 行常駐原因，實作即用 body＋`textSecondary`，兩處對齊。不擴充 `caption` 為多行，以免改動全部 `caption` 使用處的單行契約。不新增元件，狀態總數不變 |
| 1.94 | 2026-10-20 | `0.5.0-W1-114.22.2`（SPEC-001 v1.52 同批，承 `0.5.0-W1-114.22` 派發前查證：事件類破洞項目無說明 key，同一 EVT 兩個 domain 未對應的兩項在畫面上無從區分）：§4.0.6 新增〈1.94 新增〉表——`gapOrphanEventEmittedNotConsumed`、`gapOrphanEventConsumedNotEmitted`、`gapEventConsumerUnmatched`、`gapEventProducerUnmatched`（後兩者帶 `domain`，宣告值原樣不經 i18n）；分節標籤沿用 1.51 既有兩 key。key 與 zh／en 文案 PM 確認，比照 1.80／1.81 先例；ARB 由 `0.5.0-W1-114.22` 建立。正文版本行補記 1.93（該版未同步本行）。不新增元件，狀態總數不變 |
| 1.93 | 2026-10-20 | `0.5.0-W1-443`（用戶裁決 2026-10-20，SPEC-001 v1.51 同批）：§4.0.6 新增 `pathDeclarationNoBundles`（尚未宣告任何 domain／no domains declared），bundle 總數為 0 時取代 `pathDeclarationBundlesPartial` 作為宣告狀態行的 bundle 側片段；`pathDeclarationNonDomainMalformed` 列的「ARB 待建」改為已建（`0.5.0-W1-119.2`）。不新增元件，狀態總數不變 |
<!-- rule8-exempt: illustration:比照既有變更歷史列引用票號格式 -->
| 1.92 | 2026-10-20 | `0.5.0-W1-114.24`（承 `0.5.0-W1-114.12` 回報：間接依賴格「在泳道中檢視」依 SPEC-001 §1 應定位到來源 X 列欄號最小的節點，畫面已算出目標欄，但 4.38 只有 `locateLane`（列），跳轉只切列不捲到目標欄）：4.38 slot 表新增 `locateColumn`（`int?`，與 `locateLane` 同次 build 設值、同一 post-frame 另做水平 `jumpTo`，`null` 不做水平捲動，`locateLane` 為 `null` 時忽略）；回饋契約 locate 列補間接依賴格的目標列取來源 X 列與水平定位；測試點新增目標欄定位與 `locateColumn` 為 `null` 的 E1 對照；§4.0.10 場景 b 同步。高亮仍由 `laneHighlight` 承載，不新增焦點綁定高亮；狀態總數不變。PM 處置：既有裁決（SPEC-001 §1 跳轉目標，`0.5.0-W1-114.2` J2）的直接後果 |
| 1.91 | 2026-10-20 | `0.5.0-W1-114.23`（承 `0.5.0-W1-114.18` 回報：UC Flow 已能接收 flow 類跳轉的 step id 並捲動至步驟列，但 4.35 `step` 變體不接受 `isLocated`，步驟列無法高亮；SPEC-001 §5 flow 類「定位到出錯的步驟」為用戶裁決 J2）：4.35 變體表 `step` 列補「可被定位」；狀態矩陣 located 列擴及 `step`，進入條件補 flow 類破洞項跳入；回饋契約 locate 列 `step` 由「無場景，不接受 `isLocated`」改為被定位目標（捲動由 4.36 `scroll-ucFlow-steps` 執行，高亮與焦點移入同 `ticket`）；slot `isLocated` 擴及 `step`；測試點補 `step` 高亮與 located 時 `onTap` 不受影響兩項。§4.0.10 0.1 場景新增 (g)：flow 四子類帶 step id 時定位並高亮，EVT-CORPUS-004 無 step id 時不定位。手法比照既有 `ticket`／`eventFlow`，不新增 token；狀態總數不變。PM 處置：既有裁決的直接後果 |
| 1.90 | 2026-10-13 | `0.5.0-W1-177.1`（承 `0.5.0-W1-177`：規格稽核腳本補上「載入失敗」狀態後報出本表缺漏；v1.86 新增該狀態時 §3.6 已補、§3.1 未同步）：§3.1 總表 `BlockedState` 列的出現處欄補「載入失敗」，用途欄補一句對照——載入失敗不屬「不適用」，訊息為結果與原因（`domainLoadFailedMessage`）、提供「重新載入」（`action-domain-reload`）與切換專案出口、無版本值與說明。內容取自 §3.6 既有列，不新增行為；變體欄不變（沿用 `plain`）。e1 PM 處置：既有條文的直接後果 |
| 1.89 | 2026-10-13 | `0.5.0-W3-007`（承 `0.5.0-W3-005` 範圍外發現與 `0.5.0-W1-114.11` 審查的範圍追加；§4.0.3「一字元」定義來自 `0.5.0-W1-071`）：(1) 其餘七處「一字元 + 省略號」改引用 §4.0.3 並標明字級 slot，是否計省略號依各條目的超出處置（七處皆為截斷，皆計）。字級：4.11 `PageTitle` 取 `title` slot 的 `AppFontSize.subtitle`（`subtitle` slot 字級較小，不決定最小寬）；4.14 `TableColumnHeader` 的 `static`／`sortable` 取 `AppFontSize.caption`、`twoLine` 取第一行的 `AppFontSize.body`，`blank` 無文字 slot、本項不計；4.19 `RelationItem` 取 `id` slot 的 `AppFontSize.body`；4.29 `SplitRow` 左格依 `leading` 子件（`PageTitle` 與 `AppText.subtitle` 取 `AppFontSize.subtitle`、`AppText.body` 取 `AppFontSize.body`）；4.35 `TableRow` 填滿欄取 `AppFontSize.body`、`header` 變體依 4.14 取 `AppFontSize.caption`；5.3、5.14 空間不足策略列改指向 4.29、4.40 的最小尺寸列。原條文未指名字級，公式的項數不變，數值自此可由 token 算出。(2) 4.19 最小寬依 `isProposed` 分列：`false` 維持原式；`true` 新增「+ `Space.sm` + `Badge.category` 固有寬」——〈組合規則〉既定 badge 不截斷、不換行，為不可壓縮的固定部分（比照 4.40 計入 trailing 寬），屬既有條文的直接後果；測試點補一條（最小寬下 `id` 只剩一字元加省略號、badge 完整）。(3) frontmatter 新增 `has_functional_requirements: false`：元件庫規格以逐元件契約表達，不含 FR 為設計（`0.5.0-W1-159` 判定），覆蓋檢查據此不執行 FR 比對。截斷與換行行為皆未變更，實作不變 |
| 1.88 | 2026-10-13 | `0.5.0-W1-156.1`（承 `0.5.0-W1-156` 用戶裁決 2026-10-12，對應 SPEC-003 v1.60、SPEC-001 v1.50）：專案切換浮層內選資料夾失敗由 4.26 `AppSnackBar` 改為浮層內常駐文字。(1) §4.0.6 新增〈1.88 新增〉表：`switcherChooseFolderUnavailableReason`、`switcherFolderUnavailableReason`（文案沿用既有 SnackBar key 現值，因載體與內容政策不同而另立 key）；最近專案項沿用 `projectUnavailableReasonLabel`，不新增 key；`chooseFolderUnavailableMessage`、`folderUnavailableMessage` 兩列使用處限縮為 SPEC-003 §3.1。(2) 4.42 `SwitcherOverlay`：新增 `chooseOtherFailureReason` slot（`String?`，`null` 時不渲染），用途、狀態矩陣兩列顯示欄、回饋契約（press-ack、state-change、等待與結果三列）、內容政策、design token、i18n、無障礙（播報與 Tab 序列）、測試點、反例同步；清除時機依 SPEC-003 §3.7（用戶裁決 2026-10-13：開始新的嘗試的點選當下清除、浮層收合後不保留），由呼叫端傳回 `null`。(3) 4.9 `RecentProjectItem`：點選後開啟該路徑判定不可讀或不存在時進入 disabled 態、同列顯示 `reason`，本次展開期間維持，重試須收合浮層再展開（用戶裁決 2026-10-13），press-ack 列、i18n `reason` 列、無障礙播報列、測試點同步。(4) 5.16 子件契約與排列不變式補失敗原因文字。4.26 的 slot 與 i18n 清單不變（兩個 SnackBar key 仍由 §3.1 內容區使用） |
| 1.87 | 2026-10-13 | `0.5.0-W1-114.11` 修正輪回報（4a，2026-10-13）：`SwimlaneGrid` 的邊掛在 min(from,to) 格繪製，起點格捲出被回收後整條跨欄邊消失。PM 處置：4.38〈拖曳與捲動操作路徑的不變式〉既定捲動與拖曳為畫布平移（只移視窗、內容 1:1 平移），邊屬內容，故補一句「任一條邊落在 viewport 內的部分一律可見，與起點欄、終點欄是否在 viewport 內無關」，屬既有不變式的直接後果，不改使用者可見規則；測試點補一條（起點欄捲出、終點欄在內，邊段仍繪製，附捲動前對照）。不規定繪製方式（整列覆蓋層或其他） |
| 1.86 | 2026-10-12 | `0.5.0-W1-114.14.1` 用戶裁決（對應 SPEC-001 v1.49、SPEC-003 v1.59）：§3.6 對照表 §1 補「載入失敗」列（`BlockedState.plain`），§2–§6「專案未就緒」五列改四選一；§4.0.6 新增〈1.86 新增〉表（`domainLoadFailedMessage`、`reloadAction`、`projectUnreadyReasonLoadFailed`）；4.23 用途、出現畫面、`plain` 變體、狀態矩陣、slot 契約（`message` 來源、新增 `onReload`、`testKey` 補 `state-domain-load-failed` 與 `action-domain-reload`；`action-domain-switch-project` 渲染於四個狀態）、i18n 同步。frontmatter `version` 原停在 1.84（1.85 只改正文版本行與本表），本版一併對齊 |
| 1.85 | 2026-10-12 | `0.5.0-W3-005`（PM 裁決，2026-10-12；承 `0.5.0-W1-071` 的 §4.0.3「一字元」定義）：六個條目〈尺寸契約〉最小尺寸列的「一字元」改引用 §4.0.3 並標明字級 slot，是否計省略號依各條目〈內容政策〉的超出處置（截斷計、換行不計）。數值變化：(1) 4.16 `SwimlaneNode`、4.24 `LoadingState`、4.26 `AppSnackBar`、4.40 `ListRow` 的寬各新增「+ 省略號」項，字級取 `AppFontSize.body`（依序為 `label`、`message`、`message`、`primary` slot）；(2) 4.1 `AppText` 字級取各變體自身的 `AppFontSize.*`（`mono` 取 `body`），原「一個字元 + 省略號可見」統一為「一字元 + 省略號」，`body` 未傳 `maxLines` 時為換行、不計省略號（原文全變體皆計）；(3) 4.20 `DocumentBody` 字級由未指明改為 h1 標題 slot 的 `AppFontSize.title`（段落與標題皆字元邊界換行，由字級最大的 slot 決定最小寬），不計省略號；h1 字級的出處為 4.20〈使用 design token〉字體列（`title`（h1）），實作為 `lib/components/document_body.dart` 的 `MarkdownStyleSheet`（`test/unit/components/document_body_test.dart` 已斷言）。各列的高、內距與間距項未變。實作不變 |
| 1.84 | 2026-10-12 | `0.5.0-W1-114.15` PM 處置：4.40 `item` 項目沒有說明 key 時，路徑與行號移到主文字、不渲染次文字 |
| 1.83 | 2026-10-12 | `0.5.0-W1-114.15` 用戶裁決：掃描輪次拋出非預期例外時落「無法判定破洞」；§3.6 §5 原因說明改三選一，§4.0.6 新增 `gapsUndeterminableReasonScanFailed`（對應 SPEC-001 v1.48） |
| 1.82 | 2026-10-11 | `0.5.0-W1-114.17` 回報（PM 處置）：`gapNonDomainPathsNonStringElements` en 改為 ICU plural 字串；〈1.80 提案〉更正「沿用既有」為「ARB 由 114.17 建立」；淘汰的 `gapCategoryMissingFrontmatter` 自 §4.0.6 表格移至〈已淘汰的 key〉註記 |
| 1.81 | 2026-10-09 | PM 確認〈1.80 提案〉全部 key 識別名與 zh／en 文案；依用戶裁決 M1 淘汰 `gapCategoryMissingFrontmatter`（SPEC-001 v1.42 同批） |
| 1.80 | 2026-10-09 | `0.5.0-W1-114.16`（SPEC-001 v1.41 同批）：§4.0.6 新增〈1.80 提案〉——五個分節標籤 key、EVT-CORPUS-003 八個項目說明 key（含歸屬型別不明）、EVT-CORPUS-004 一個、`graphDefect` 主圖、flow 子圖與 domain 重複宣告共十二個；EVT-CORPUS-005 沿用既有 `gapNonDomainPaths*`。key 識別名與 zh／en 文案皆為提案，待 PM 確認，ARB 待建 |
| 1.79 | 2026-10-08 | `0.5.0-W1-114.5` PM 處置（lavender NeedsContext）：§4.0.6 新增 `gapNonDomainPathsYamlInvalid`、`gapNonDomainPathsKeyMissing`、`gapNonDomainPathsNotList`，補齊 `nonDomainPathsMalformed` 其餘三個子原因的破洞項目說明；`gapNonDomainPathsNonStringElements` 的 en 文案經 PM 確認 |
| 1.78 | 2026-10-08 | `0.5.0-W1-114.5`（依 `0.5.0-W1-114.4` 用戶裁決第五批 NC-7，G1；SPEC-001 v1.39、SPEC-006 v1.20 同批）：§4.0.6 新增 `gapNonDomainPathsNonStringElements`（「清單內 {count} 個非字串元素」，`count` 參數，en 單複數），供 SPEC-001 §5 `elementNotString` 破洞項目說明；ARB 待建 |
| 1.77 | 2026-10-08 | `0.5.0-W1-114.1` 第二小輪（PM 處置 NC-a／NC-f／NC-g，SPEC-001 v1.37 同批）：4.38 `lanes` 列數約束改為「DomainBundle 數＋1，有未定位步驟時＋2」，`kind` 新增 `unplaced`（「未定位」列，置於全部 DomainBundle 列後為最末列、只在有此類步驟時出現、欄號依清單順序）；§3.1 `SwimlaneGrid` 列同步；§4.0.6 新增 `swimlaneUnplacedLaneName`（未定位／Unplaced，lavender 提案）；`swimlaneFlowParseFailedHint`、`flowParseFailedMessage`、`pathDeclarationNonDomainMalformed` 三個 key 與文案、提示元件 `AppText.caption` 置於 `SwimlaneGrid` 之上，由提案改為已定；`flowParseFailedMessage` 註明 §2 同用 |
| 1.76 | 2026-10-08 | `0.5.0-W1-114.1`（依 `0.5.0-W1-114` PM 處置 N4、用戶裁決 F1，`0.5.0-W1-096.7` 用戶裁決 NC-1，SPEC-001 v1.36 同批）：4.38 `lanes` 約束由「恆 9 列」改為「DomainBundle 數＋1（「畫面」列），本專案 9 列」，用途與 §3.1 `SwimlaneGrid` 列同步改「每個 DomainBundle 一列」；§3.6 §1 正常 · 泳道補解析失敗提示（`AppText.caption`，提案）、泳道 · flow 未結構化補解析失敗文案（同一 `EmptyState.section`，動作共用 `openSourceFileAction`）；4.26 `message` 補 `flowParseFailedMessage`；§4.0.6 提案三個新 key：`swimlaneFlowParseFailedHint`、`flowParseFailedMessage`、`pathDeclarationNonDomainMalformed`（key 與文案待 PM 決定） |
| 1.75 | 2026-10-08 | `0.5.0-W1-103.1` PM 處置：§4.0.6 `relationItemProposedA11yLabel` 朗讀整句確認，移除「提案／未經用戶確認」標記 |
| 1.74 | 2026-10-08 | `0.5.0-W1-096.9` PM 處置：§4.0.6 登記 `pathDeclarationIncompleteLine`、`pathDeclarationBundlesPartial`、`pathDeclarationNonDomainMissing`、`pathDeclarationNoneLine` 四個新 key 的 zh／en 文案（SPEC-001 v1.35 §5 專案層級宣告狀態一行） |
| 1.73 | 2026-10-08 | `0.5.0-W1-103.1` 用戶裁決第二輪 I2：4.19 `RelationItem` proposed 標記由 `Badge.tag` tone `neutral` 改為 `Badge.category` tone `warning`（原提案與 chip 同為 `surfaceChip` 底色，區分不出），slot、token、i18n、組合規則、無障礙對比、測試點同步；4.5 `category` 用途欄補此用法；§4.0.6 `relationProposedLabel` 文案改 zh「暫定」／en「Proposed」，`relationItemProposedA11yLabel` zh 用詞對齊為「暫定邊」（整句仍為提案） |
| 1.72 | 2026-10-08 | `0.5.0-W1-103.1`（依 `0.5.0-W1-103` 用戶裁決：使用中的 proposed 邊在詳情卡與鄰接查詢標示 proposed）：4.19 `RelationItem` 新增 `isProposed` slot（依 SPEC-007 FR-08 回傳項 `layer` 判定，不依鍵名），`true` 時尾端加 `Badge.tag`（沿用固定 tone `neutral`，不新增變體）並改用 proposed 朗讀標籤；i18n、組合規則、無障礙、測試點同步；§4.0.6 登記 `relationProposedLabel`、`relationItemProposedA11yLabel`（ARB 待建，`0.5.0-W1-103.2`）。視覺與文案為提案，見該票 NeedsContext |
| 1.71 | 2026-10-08 | `0.5.0-W1-106` 修訂輪（用戶裁決 K6，`docs/tech-decisions.md` 2026-10-08 補記）：§4.0.6 1.69 表刪除 8 個 `domainDisplayName<Domain>` key，只留「畫面」列（`presentation`）key 並改名 `swimlaneScreenLaneName`；4.37 `MatrixGrid` `rows` 與 4.38 `SwimlaneGrid` `lanes` 列首來源改為 `DomainBundle.domain` 原值（未知 domain 亦顯示原值），僅「畫面」列經 i18n；取代 1.69 的 domain 列首 i18n 規則 |
| 1.70 | 2026-10-08 | `0.5.0-W1-092.2`（用戶裁決 2026-10-08 第 1、2 項，SPEC-001 v1.29 同批）：§3.1 `SwimlaneGrid` 列與 4.38 用途的括注由「8 個 DomainBundle 列固定順序、主線 `next` 鏈」改為「依 `bundle_dependency` 推導層序與同層字母序、主線清單順序與分支（含巢狀）」；slot `lanes` 與測試點引用〈泳道布局規則〉列序，不改字面 |
| 1.69 | 2026-10-08 | `0.5.0-W1-106`（SR-1 落地，承 `0.5.0-W1-095.3`）：§4.0.6 新增「1.69 新增」表，8 個 DomainBundle domain 與「畫面」列（`presentation`）的 zh／en 列首顯示名 key（狀態待建）；4.37 `MatrixGrid` slot `rows` 來源欄由「列首文字為資料值」改為以 domain key 由 i18n 取，與 4.38 `lanes` 一致；正文版號行補記 1.65–1.69（該行自 1.65 起未隨 frontmatter 更新，第三度漂移） |
| 1.68 | 2026-10-07 | `0.5.0-W1-093.1`（依 `0.5.0-W1-093` 用戶裁決 A3，SPEC-001 v1.26 同批）：4.15 `MatrixCell` 三變體「何時選用」補判定式序號並指向 SPEC-001 §1〈間接依賴判定式〉，補「變體由頁面層計算傳入」與期望分布 19／10／19；§3.6 已選格組合補依賴路徑 `AppText.body` × N（僅 `indirect` 格）與 `indirect` 格「在泳道中檢視」定位目標 |
| 1.67 | 2026-10-07 | `0.5.0-W1-092.1`（依 `0.5.0-W1-092` 用戶裁決 R1／C2／B2／E2，SPEC-001 v1.25 同批）：§3.1 `SwimlaneGrid` 列與 4.38 用途改為依 SPEC-001 §1〈泳道布局規則〉——「畫面」列 + 8 個 DomainBundle 列固定 9 列、主線 `next` 鏈與分支插欄、前向直線與回指弧線；4.38 刪「何時不用：有布局演算法的泳道」；slot `lanes` 改含 `key`／`kind`（screen 或 domain）且恆 9 列、列首名由 i18n 取，新增 `edges` slot（`shape` 依欄號比較）；反例改為「自行決定列序欄序邊形狀」與「把畫面列加進矩陣」；測試點補一列 |
| 1.66 | 2026-10-07 | `0.5.0-W1-071`（e1 裁決，2026-10-07）：(1) §4.0.3 新增「一字元」定義（該文字 slot 字級的 1em）；4.7／4.8／4.9 最小尺寸改為「一字元 + 省略號」並引用 §4.0.3、字級取 `AppFontSize.body`；(2) 4.9 摘要與降級徽章間距定為 `Space.sm`；(3) 4.9 徽章固有寬亦放不下時，摘要縮至 0 後才截斷徽章（名稱 > 徽章 > 摘要）。(1)–(3) 與現行實作一致 |
| 1.65 | 2026-10-06 | `0.5.0-W3-001` 派發前 NeedsContext 兩項（e1 裁決）：4.9 RecentProjectItem——(1) NC-2：降級徽章與摘要同一列、接在摘要之後，寬度不足時摘要先截斷、徽章維持固有寬度（依據：尺寸契約最大高為「最小高 + `reason` 兩行」，未計徽章列）；(2) NC-1：內容政策「降級標籤」列的最長測試文案由 `TestCopy.longToken` 改為 `degradedSchemaShortLabel` 的 zh／en 實際值於最小寬下截斷不溢位（標籤文字由元件內部取 l10n，slot 只有 `isDegraded: bool`，不為測試注入另開文字 slot） |
| 1.64 | 2026-09-30 | `0.4.0-W3-001`（component-contract-design 3.13.0 路徑 C 步驟 3〈佈局輔助的歸屬轉置〉；本專案頁面層掃描見票面）：(1) 4.30 Panel `default` 的 `children` 拆為 `leading`（0..4）／`fill`（恰 1）／`trailing`（0..2）三個具名 slot，「恰一個填滿」由 `fill` 的單一型別保證，呼叫端不再包 `Expanded`；`scrollable` 維持 `children`。變體表、slot 契約、測試點、反例同步。原條文「子件中恰一個填滿」在三處以 `EmptyState.section` 為主體的面板上實際為 0 個填滿子件，改由 `fill` 承載後渲染不變（`section` 靠上對齊）；(2) 4.14 TableColumnHeader 新增 `blank` 變體（無文字、無語意節點），取代表頭空白格的 `SizedBox.shrink()`（用戶裁決 B：不包子件的空節點不是佈局輔助；表頭空白格屬元件層缺口）；`label` 必填性、朗讀標籤、測試點同步 |
| 1.63 | 2026-09-30 | `0.3.3-W3-405`（承 `0.3.3-W3-404` 稽核浮出）：4.26 slot 契約 `message` 列的呼叫端清單與 i18n 訊息列補 `workspaceNotRemembered`（選定成功但偏好設定寫入失敗，對齊 SPEC-003 v1.53 §3.7 新增列與 §2.13 列 15）。該 key 已登於 §4.0.6〈1.56 補登〉表，本次只補 4.26 內的兩處清單 |
| 1.62 | 2026-09-30 | `0.3.3-W3-395`（承 `0.3.3-W3-386` 分流）：ARB 同步四項 key 後規格對齊——§4.0.6〈1.56 補登〉表 `noUcNodesMessage` 列改登 `emptyUcMessage`（同文案；UC Flow 無 UC 改用 4.21 `message` 列既列的 key，`noUcNodesMessage` 自 ARB 移除）。`swimlanePanelTitle`（ARB 新增）、`matrixSubtotalA11yLabel`（MatrixGrid 列首 label「{domain}，小計 N」）本檔既有列已符合，未改；`backToDomainAction` 自 ARB 移除，4.4 `label` 列與 4.21 動作列既有「已移除」註記維持 |
| 1.61 | 2026-09-30 | `0.3.3-W3-403`（承 `0.3.3-W3-392` 判讀 #45、#46）：SPEC-003 §3.4 F1–F7 委派本檔 4.13 單一承擔且其 F3 含選項錨點，本檔 4.13 缺——F3 補錨點子句（首項 `option-tickets-filter-<key>-all`、其後 `option-tickets-filter-<key>-<value>`）、slot `testKey` 列補選單根與選項錨點由 `<key>` 推導、測試點補選項錨點斷言。`lib/components/filter_dropdown.dart` 既有實作（`menu-…`、`option-…-<value>`）與 `filter_dropdown_test` 既有斷言已符合，規格補登，實作不變 |
| 1.60 | 2026-09-29 | 用戶裁決（2026-09-29，經 e1 以 AUQ）兩項落規格：(1) `0.3.3-W3-377` 候選 C——§4.0.6 `chooseFolderUnavailableMessage` 改為 zh「無法開啟資料夾選取面板，應用程式可能安裝不完整」／en「Could not open the folder picker; the app may not be installed correctly」，衝突註記改寫為已決（結果陳述＋一般語言原因符合 M1，不開例外）；(2) `0.3.3-W3-378` 候選 B——§4.0.6 登記既有 `workspaceUnavailable` 為 §1 未選專案說明區的常駐文字（還原失敗降級時顯示，取代 `folderAccessRationale`），對齊 SPEC-001 v1.24、SPEC-003 v1.51。ARB 與畫面實作由實作票承接 |
| 1.59 | 2026-09-29 | `0.3.3-W3-389`：§2（uc_flow）、§5（gap_report）、§6（node_detail）「專案未就緒」改為與 §3、§4 相同的依原因三選一（`projectUnreadyReason*`）與 `gotoDomainViewAction`，五畫面共用 `ProjectUnreadyView`；ARB 移除 `projectUnreadyMessage`、`gotoDomainAction`。本檔同步：〈1.36 新增〉表 `gotoDomainAction` 列改為 `gotoDomainViewAction`（括號留原名）、〈1.56 補登〉表刪除 `projectUnreadyMessage` 與 `gotoDomainViewAction` 兩列（前者已移除、後者併入 1.36 表）、4.4 `label` 列與 4.21 動作列的引用改名。歷史變更列不改 |
| 1.58 | 2026-09-29 | `0.3.3-W3-391`（承 `0.3.3-W3-382` SPEC-003 v1.48）：§4.0.1 互動瞬態表 focused 列原寫「元件祖先鏈存在 `decoration` 非 `null` 的 `DecoratedBox`」的存在性抄錄（未取得焦點時亦成立，無鑑別力），改為焦點環承載於 `BoxDecoration.border`、取得焦點時 `AppColors.accent` 外框／焦點移走後無或透明，斷言引用 SPEC-003 §2.10〈焦點裝飾（斷言方式，對照形）〉不重述；§1 子表「焦點」列「存在性斷言」改「兩態對照斷言」；各條目回饋契約「焦點」列時間門檻欄的「SPEC-003 §2.10 只斷言裝飾存在」共 19 處改為「只斷言焦點兩態裝飾可區分」（語意為不設時限的理由，未改其結論） |
| 1.57 | 2026-09-29 | `0.3.3-W3-387`：全檔 42 條「最小尺寸」逐條對照實作內距，5 條漏計元件自身內距（與 1.52 的 4.29 同型）已補並指名 token——4.7 `NavItem` 寬 + 2 × `Space.md`、4.8 `ProjectSwitcherEntry` 寬 + 2 × `Space.sm`（原式的 2 × `Space.sm` 註明為內部間距）、4.9 `RecentProjectItem` 寬 + 2 × `Space.sm`、4.20 `DocumentBody` 寬高各 + 2 × `Space.xs`、4.35 `TableRow` 寬 + 2 × `Space.sm`（與 5.9 空間不足策略既有的「+ 2 × `Space.sm`」對齊）。容器公式複核：5.5 `TwoColumnLayout` 主欄最小寬的「`DocumentBody` 一字元」改引 4.20 最小寬；4.36 `DataTable` 以名稱引用 `TableRow` 最小寬，隨之生效；5.1 `AppShell` 只引用 4.7／4.8 的高（未變）；其餘引用者不受影響。掃描清單見該票 |
| 1.56 | 2026-09-29 | `0.3.3-W3-384`（承 `0.3.3-W3-376` 全量差集第 1、3、5 類）：(1) 同義異名改用 lib 實際使用的 ARB 名——〈1.36 新增〉表 `projectUnreadyUnsetMessage`／`projectUnreadyLoadingMessage`／`projectUnreadyBlockedMessage` 改為 `projectUnreadyReasonNotSelected`／`projectUnreadyReasonLoading`／`projectUnreadyReasonIncompatible`，〈1.38 新增〉表 `gotoTicketsAction` 改為 `gotoTicketsListAction`，4.21 `message` 列與 §3.6 §3 列的引用同步；文案差異：Loading zh「專案載入中」→ ARB「圖譜載入中」、en 兩處取 ARB 現值，依據為 SPEC-001「專案未就緒」列只定原因「載入中」、未定字面，未改 ARB。(3) 新增〈1.56 補登〉表：`folderAccessRationale`、`noUcNodesMessage`、`projectUnreadyMessage`、`gotoDomainViewAction`、`workspaceNotRemembered`、`scanCompleteNotificationTitle`（後者權威在 SPEC-003 §2.2，本列僅對照）。(5) `schemaAppVersionLabel`／`schemaProjectVersionLabel` 列改記 ARB 已移除。歷史變更列中的舊 key 名不改 |
| 1.55 | 2026-09-29 | `0.3.3-W3-282`：§2「樂觀更新政策」列三處修正。(1) 重評條件原為「PROP-005〈0.x — 編輯〉階段落為提案票時」，非 ticket ID 且原指的承接票（`0.1.1-W3-073`／`0.1.1-W3-281`）已由 `0.2.0-W1-030` 收束關閉，改綁 1.0 規劃票 `1.0.0-W3-553`（`docs/system-layer.md` §6 同項 trigger 同步改綁）。(2) 移除對 PROP-004〈範圍界定〉的引用（該段「首版唯讀」框法已於 2026-08-27 撤回），改引 PROP-005〈1.0 — 編輯〉與 `0.4.0-W1-040`。(3) 唯讀前提由「0.1 為唯讀展示殼」改為「決策層已定 1.0 起可寫、0.x 實作層唯讀」，政策標題相應改為 0.x。各條目「§2 樂觀更新政策：0.1 無樂觀操作」引用句（0.1 屬 0.x 範圍內，仍成立）不動 |
| 1.54 | 2026-09-29 | `0.3.3-W3-245`：4.26 狀態矩陣 shown 列退出路徑「新的 SnackBar 取代」與回饋契約「等待與結果」列「冪等——新的 `show` 取代前一則」兩處補級別條件（新一則級別不低於前一則或前一則級別未知時取代，較低時讓步不清除不呈現），對齊 SPEC-003 §2.13〈顯示位爭用時的約束與 0.1 的處置規則〉既有條文與 `app_snack_bar.dart` `_resolvePreemption`，非新規則。§4.0.11 判定不補列 `showId`／`origin`：本節記錄三類時刻的落地狀態，仲裁欄位的權威定義在 SPEC-003〈仲裁決策事件的七項欄位（本專案落地）〉，於「顯示發生」列改為引用，避免兩處欄位清單漂移 |
| 1.53 | 2026-09-29 | `0.3.3-W3-129`：4.8〈尺寸契約〉最小尺寸的高原寫 `LayoutSize.hitTargetMin`，把命中區下界寫成內容高度，使「高固有」與「最大尺寸：高同最小」讀成固定 28 而互相矛盾；改寫為與 4.7 同構的內容組成 `LayoutSize.iconLg` + 2 × `Space.sm`（不小於 `LayoutSize.hitTargetMin`），「高同最小」因此指內容固有高，與 `project_switcher_entry.dart` 的 `ConstrainedBox(minHeight: hitTargetMin)` + `Padding(Space.sm)` 一致。實作不變 |
| 1.52 | 2026-09-29 | `0.3.3-W3-128`：4.29〈尺寸契約〉最小尺寸列的寬公式原只計左格最小寬 + `Space.md` + 右格固有寬，與同節〈使用 design token〉間距列的水平內距矛盾；補 2 × 水平內距（`header` 為 `Space.xl`，`footer` 與 `compactHeader` 為 `Space.sm`，與 `split_row.dart` 的 `_horizontalPadding` 一致），並註明無右格時不計間距與右格。5.3〈空間不足策略〉原式不變，「可用寬」明示為列寬扣除兩側水平內距。實作不變 |
| 1.51 | 2026-09-29 | `0.3.3-W3-376`：§4.0.6 新增〈1.51 補登〉表，登記 `gapCategoryOrphanEvent`、`gapCategoryEventDeclarationMismatch` 兩個既存 key（`gap_report_screen.dart` 破洞分節標籤已使用，zh／en ARB 皆有值，key 表未登記）；zh／en 取 ARB 現值。ARB 鍵集合對 §4.0.6 的全量差集記於該票，其餘差集項不在本版次處理 |
| 1.50 | 2026-09-29 | `0.3.2-W3-368` 核對：§4.0.6〈1.38 新增〉表的 `folderPickerUnavailableMessage` 與既有 `chooseFolderUnavailableMessage`（`project_switcher_overlay.dart` 的 `ChooseFolderUnavailable` 分支已使用）語意完全重疊，改列既有 key 並記 ARB 現值；4.26 `message` 來源兩處同步改名。ARB 現值後半為操作指引，與 §4.0.12 M1 衝突，另案處理。`folderUnavailableMessage` 保留並補理由：對象為剛選定的資料夾，與既有 `workspaceUnavailable`（啟動還原「先前的資料夾」）語意不同 |
| 1.49 | 2026-09-29 | §4.0.6 新增〈1.49 補登〉表：`gapCategoryMissingFrontmatter`、`gapItemLineLabel` 兩個 key 自 `0.1.0-W2-004` 起只存在 `app_zh.arb`，en 語系回退為繁中樣板、gen-l10n 每次警告 2 則未翻譯；zh 取 ARB 現值，en 新擬，ARB 實檔由 `0.3.2-W3-548` 加入 |
| 1.48 | 2026-09-25 | 對齊 SPEC-001 v1.23（用戶裁決 2026-09-25，WRAP 方案 D）：§4.0.6 新增〈1.48 新增〉key `schemaVersionUnreadableMessage`（schema 不相容且型別表版本無法判讀時的本體訊息，不代入版本值）；4.23 `BlockedState` `message` 來源列補此 key |
| 1.47 | 2026-09-25 | 對齊 SPEC-001 v1.22（用戶裁決 2026-09-25，WRAP）：§4.0.6〈1.46 新增〉表的 `gapsUndeterminableReasonVersionTooNew` 改名為 `gapsUndeterminableReasonVersionOutOfRange`，zh／en 文案改為「版本不在 App 已知範圍」（涵蓋高於、缺席、無法解析）；§3.6 §5「無法判定破洞」列同步 key 名。ARB 實檔尚未建立，改名無既有消費端 |
| 1.46 | 2026-09-24 | 對齊 SPEC-001 v1.21（`0.3.0-W1-082`，SPEC-006 FR-06 規則 7／FR-08）：§3.6 對照表 §5「有破洞」列後補「無法判定破洞」列（`Panel.scrollable` + `Section.static` 頁首說明，不使用 `EmptyState`）；§4.0.6 新增〈1.46 新增〉key 表四列（`builtinPathPatternBadgeLabel`、`gapsUndeterminableTitle`、兩個原因 key）。4.27 `AppShell` 回饋契約 state-change 列與實作註記補路徑模式來源徽章 `badge-gaps-builtin-path-pattern`（只在破洞報告頁，位置與方式同降級徽章） |
| 1.45 | 2026-09-23 | 對齊 SPEC-001 v1.19（`0.2.0-W1-040`，承 `0.2.0-W1-038` 方案 A 與 `0.2.0-W1-024`「App 已知範圍」定案）：4.23 `withDetail` 變體表面板組成由 `AppText.caption` × 2 + `AppText.mono` × 2 改為各一，內容改放「App 已知版本範圍：不高於 <內建版本>」；R4 有意冗餘註記改寫為已重評（面板改放本體沒有的資訊，推定值時字面不變、來源由 4.27 徽章承載）；狀態矩陣 expanded 列、回饋契約等待與結果列、內容政策面板兩列、i18n 面板小標列同步；§3.1 元件總表 `BlockedState` 列、§3.4 排列關係盤點 §1 schema 不相容列、§3.6 對照表 §1 schema 不相容列、4.41 `Section` 用途段與 i18n 列同步；§4.0.6 新增〈1.45 新增〉key 表（`schemaKnownRangeLabel`／`schemaKnownRangeValue`／`inferredVersionBadgeLabel`），既有 `schemaAppVersionLabel`／`schemaProjectVersionLabel` 列標記不再使用（ARB 移除交實作票）；4.27 `AppShell` 回饋契約 state-change 列與實作註記補推定版本徽章 `badge-<screen>-inferred-version`（位置與方式同降級徽章，兩旗標互斥）。檔頭版本段對齊 frontmatter（1.44 時未同步，一併校正）。SPEC-003 §3.1「檢視 schema 詳情」列面板內容描述另票同步 |
| 1.44 | 2026-09-23 | §4.0.6 `healthBadgeA11yLabel` en 改單複數形，備註補計數 0 不渲染（`0.1.0-W1-027`，SPEC-001 1.17 §7） |
| 1.43 | 2026-09-15 | 追修 V4 第四輪門檻外矛盾裁決（`0.1.0-W3-335.69`，依 `0.1.0-W3-335.65` WRAP 裁決 SPEC-004 組 4-01～4-03，對應 SPEC-001 v1.16、SPEC-003 v1.37）：§3.1 總表 `SwimlaneGrid` 列用途欄與 4.38〈用途〉「0.1 以寫死座標的假資料靜態排版」改「0.1 以假資料靜態排版（節點所屬列依 `FlowStep.traverses` 計算，列序與欄序由假資料給定；SPEC-001 設計約束）」（4-01，落實 `0.1.0-W3-345` traverses 定案的同步缺漏）；4.38〈狀態矩陣〉default 列資料態「泳道資料（`lanes`，0.1 為寫死座標的假資料）」改「（0.1 為假資料，欄序由假資料給定）」、步驟欄寬列「由假資料座標決定（SPEC-001 設計約束「寫死座標」）」改「（SPEC-001 設計約束：欄寬靜態）」（4-02）；4.24 `LoadingState`〈用途〉「三處以『目標態』與『進度型別』參數差異化」改「三處以目標態、進度型別與骨架版位差異化（SPEC-003 §2.11）」（4-03，回應 SPEC-004 已定 `skeletonLayout` slot 契約與 `enum SkeletonLayout` 實作事實）。全檔「寫死座標」字面已無殘留（`grep -c` 為 0）；§3.3 第 20 項「靜態座標泳道」為提案原文記錄（節首理由欄涵蓋，不隨上游改版回改），不屬本次處置範圍 |
| 1.42 | 2026-09-15 | 同步稽核追修票（`0.1.0-W3-335.62`，依 `0.1.0-W3-335.59` WRAP 裁決最終追修清單 SPEC-004 組 4-01～4-20，對應 SPEC-001 v1.15、SPEC-003 v1.36）：§3.1 總表 `LoadingState` 用途改引用 C1–C8 與生命週期 L1–L2（共 10 條，4-01）；`ButtonRow` 用途刪返回、返回 Domain（4-02）；`AppSnackBar` 出現畫面補 §4、§7 並註記 `denied` fallback（4-04，同步 4.26〈出現畫面〉）；`MatrixCell` 用途改「可點擊選格」、狀態補 selected（4-09）；`AppButton` 用途補以 App 內建型別表檢視／前往追溯視圖／前往 Ticket 清單／切換專案（阻擋狀態本體，4-15）；`Panel` 變體欄改引用 SPEC-003 §1.1〈捲動處清單〉不逐列錨點（4-14）。§3.5 畫布漂移表「十個捲動處」改引用〈捲動處清單〉不寫數字（4-13）。§3.6 §6 原始檔已消失列歸屬改 `MissingSourceState` 單顆按鈕、返回改由頁面框架渲染（4-03）；§1 空圖列顯示欄改「前往破洞報告；切換專案由殼層入口承載」（4-19）；〈SPEC-001 狀態列顯示欄 → 本檔〉表前刪「本版對齊 SPEC-001 v1.11」（4-17）；〈UC 選擇入口〉排位列 `Panel.scrollable` 補 scrollKey `scroll-ucFlow-uc-list`、上游缺口列改記已補（SPEC-003 §1.1 SR-5 落地，4-12）。§3.3 標題下首段補理由欄記錄提案當時（2026-09-02）行為與計數、不隨上游改版回改（4-18）；§3.7 前導句改「§3.1 總表與本表核定欄不一致處以本表為準；理由欄記錄核定當時的行為與計數，現行值以 §3.1 與 SPEC-001／SPEC-003 條文為準，不回改」（4-18）。4.15 MatrixCell 詳細段已一致，不改。4.18 `ExpanderIcon` slot 契約 testKey 補 `expander-tickets-unassigned`（4-11）。4.21 `EmptyState` 變體表 `section` 何時選用補泳道 · 尚未選定 UC／泳道 · flow 未結構化／§2 尚未選定 UC、i18n `message` 補 `ucUnsetPrompt`／`swimlaneUcUnsetPrompt`（4-10）。4.23 `BlockedState` 狀態矩陣表下說明改列切換專案／檢視詳情／降級檢視三動作、不寫顆數（4-16）。4.26 `AppSnackBar`〈變體〉`plain` 補外部開啟失敗、`withAction` 補系統通知 `denied` fallback 與清除搜尋篩選（4-05）；slot 契約 `message`／`actionLabel` 與 i18n 訊息／動作兩列補 `externalOpenFailedMessage`／`scanCompleteNoGapsSnackbarMessage`／`scanCompleteSnackbarMessage`／`ticketsFiltersClearedSnackbarMessage`／`viewGapsAction`／`undoAction`（4-06）；回饋契約按下確認列改引用重新掃描／`viewGapsAction`／`undoAction`、狀態變更提示列補四則觸發（4-07）。4.28 `PageColumn` 與 4.10 `SegmentedControl` 狀態變更提示列改引用 SPEC-003 §2.1〈未列轉換的預設〉取代「三個狀態之間」等舊字面（4-20）。4.40 `ListRow`〈回饋契約〉按下確認列 `item` 分支依指向節點型別改四分支：ticket → jump Ticket 清單、其他圖節點 → jump 節點詳情、事件類 → 寫入選定 UC 後 jump UC Flow、無指向 → 外部開啟三結果（4-08）。稽核腳本 `matrix.py`／`counts.py` 由 `0.1.0-W3-335.54` scratchpad 移入 `docs/spec/ui/audit/` 並新增 `README.md`，重跑結果記錄於本票 Completion Info |
| 1.41 | 2026-09-14 | V4 第四輪前追修票 C（`0.1.0-W3-335.57`，依 `0.1.0-W3-335.53` WRAP 裁決 E1／E2／E3／E5／E8／E9，對應 SPEC-001 v1.14、SPEC-003 v1.35，承 `0.1.0-W3-335.55`／`.56` 留下的連動點）：§3.1 元件總表 `LoadPrompt` 列、`ButtonRow` 列與 §3.6 §4 未載入列刪「返回」字樣（4.25 用途段「返回由頁面框架承載」為準，ButtonRow 子件同步改 `[AppButton.primary]`，E1，含 `0.1.0-W3-335.55` 連動點 1）；§3.6 §1 無可消費的型別表列顯示欄補「降級說明（條件）」、4.23 slot `version` 文字來源改「呼叫端（專案 `.claude/VERSION`）」、`explanation` 補無可消費的型別表降級分支（新增 `schemaUnconsumableDegradedExplanation`，placeholder `builtinVersion`）（E2）；4.27 `AppShell` 狀態變更提示列與實作註記補降級徽章 `badge-<screen>-degraded-schema` 依降級旗標與返回列同一列常駐渲染（新增 `degradedSchemaBadgeLabel`，placeholder `builtinVersion`／`projectVersion`）（E3）；4.25 狀態變更提示列與狀態矩陣同步策略欄「切換專案重置」補「（下次可見且圖已建立時）」（E5）；§3.6 §1 正常 · 泳道、泳道 · flow 未結構化兩列 `AppText.subtitle` 補文字組成（新增 `swimlanePanelTitle`，placeholder `ucId`／`ucTitle`）（E8）；4.23 slot 契約 `testKey` 列補切換專案按鈕 `action-domain-switch-project`，既有實作 `lib/components/blocked_state.dart`／`test/unit/components/blocked_state_test.dart` 已使用，本票落檔與既有實作一致（E9）。§4.0.6 新增〈1.41 新增〉key 表 3 個 key，皆已 grep `lib/l10n/` 確認無同名既存 key。追修時核對項：4.24 狀態變更提示列「骨架」字樣 3 處經覆核非缺漏（同段落已提及「進度條推進為 determinate 值變化無動畫」涵蓋 Ticket 清單形式），維持現狀不改（`0.1.0-W3-335.55` 連動點 3）。票 A（`0.1.0-W3-335.55`）／票 B（`0.1.0-W3-335.56`）／票 C（本票）合計完成本輪 SPEC-004 6 項全部 |
| 1.40 | 2026-09-14 | V4 第二輪矛盾追修票 C（`0.1.0-W3-335.51`，依 `0.1.0-W3-335.47` WRAP 裁決 D2／D6／D8／D9／D13／D14，對應 SPEC-003 v1.33、SPEC-001 v1.13）：§3.6 對照表 §2 尚未選定 UC 顯示欄限定措辭「步驟表屬正常態、UC 基本資訊屬 flow 未結構化態」（D9）；§4 含損壞列末欄補錨點 `badge-tickets-corrupted-<ticketId>`（D2）；§1 正常 · 泳道列 `BadgeRow.legend` 補圖例內容，沿用既有 key `laneNodeActive`／`laneNodeInactive`（不新增 key，D6）；4.6 `IssueMarker` 變體表 `damagedDetail`、slot 契約 `testKey` 補列末錨點（D2）；4.16 `SwimlaneNode` 變體表何時選用改依 `traverses` 含選中 domain 判定、狀態矩陣來源欄「isActive 隨選中 domain 改變」（D6）；4.27 `AppShell` 狀態矩陣 overlayOpen 顯示欄、4.42 `SwitcherOverlay` 回饋契約按下確認列與等待結果列，「背景導覽項不可點」改「點擊背景任一處被吸收：浮層收合、不切頁」（同 SPEC-003 §3.4 F7，D13）；4.38 `SwimlaneGrid` 狀態矩陣 default 進入條件補 `state-domain-swimlane-uc-unset` 零節點分支（D8）、來源欄寫明 `isActive` 判定依據（D6）；4.42 `SwitcherOverlay` 狀態矩陣 noRecent 列可用操作與退出路徑補「點外部」（D14）。票 A（`0.1.0-W3-335.48`）／票 B（`0.1.0-W3-335.49`）／票 C（本票）合計完成 SPEC-004 14 項全部 |
| 1.39 | 2026-09-14 | V4 第二輪矛盾追修票 A（`0.1.0-W3-335.48`，依 `0.1.0-W3-335.47` WRAP 裁決 D3／D4／D5，對應 SPEC-003 v1.32）：§3.1 元件總表 `EmptyState` 列出現畫面補「泳道 · 尚未選定 UC」「泳道 · flow 未結構化」「尚未選定 UC」與 §2–§6 專案未就緒，用途補「`page` 列舉狀態；無破洞與 `section` 例外見 SPEC-003 §2.7」；`BlockedState` 列補「版本值（不是框架專案無）」。4.21 `EmptyState`〈用途〉同步補例外句、〈出現畫面〉同步補齊、變體表 `page` 行為差異與 slot 契約 `actions` 必填列舉補「專案未就緒」、狀態矩陣 default 顯示欄「動作列（`page` 必有）」改「動作列（`page` 依 §2.7 列舉）」。4.23 `BlockedState`〈用途〉補「版本值（不是框架專案無）」。本票範圍外的 §3.6 三列、4.6、4.16、4.27、4.38、4.42 留待 `0.1.0-W3-335.51` |
| 1.38 | 2026-09-14 | `0.1.0-W3-335.38` 真缺口追修（票 C，對應 SPEC-001 v1.12、SPEC-003 v1.31）15 項（對應 12 改動點）：S-07（4.35 `ticket` 內容政策補解析失敗列：ID 取檔名、其餘欄「—」）；S-24（4.35 `eventFlow` 發出格多個以「、」串接）；S-11／S-13／S-38（4.26 i18n 表與 §4.0.6 新增 `ticketsTargetNotFoundMessage`／`folderPickerUnavailableMessage`／`folderUnavailableMessage`）；S-18／S-22（4.26 `withAction` 用例與動作列移除 `refreshAction`，泳道／UC Flow 開啟原始檔找不到檔案改用 `plain` 不帶動作，`refreshAction` 僅保留為 4.22 自身按鈕標籤）；S-14（4.38 用途補列首可點 `action-domain-select-<domainId>`、焦點列改列首依序為停留點、拖曳不變式補位移閾值判準）；S-15（併入 1.37：§3.6 §1 表下補 `SplitRow.header` 與 `SegmentedControl` 僅渲染五列）；S-16（併入 1.37：4.23 焦點列引用 SPEC-003 §2.10 新列）；S-20（§4.0.10 定位場景表補 (f) 由 UC Flow domain 欄 jump 進入 Domain 視圖，矩陣由 4.37、泳道由 4.38 執行）；S-27（4.39 補展開集合以節點 ID 為鍵，多父節點出現位置共用）；S-28（§3.6 §3 正常／鏈路斷裂列補 Ticket 未載入常駐說明列歸屬，§4.0.6 新增 `traceabilityTicketsNotLoadedHint`／`gotoTicketsAction`）；S-34（4.9 slot 契約增 `isDegraded`、內容政策增降級標籤、§4.0.6 新增 `degradedSchemaShortLabel`、測試點補有／無降級）；S-37（4.9 disabled 列進入條件補探測未完成、§4.0.6 新增 `probingReason`）。S-18／S-22／S-13／S-38 另涉 SPEC-001 §8.2、i18n 提案沿革已於 .37／.38 分析票記錄，本檔僅落 SPEC-004 承接部分 |
| 1.37 | 2026-09-14 | `0.1.0-W3-335.37` 矛盾裁決追修 SPEC-004 剩餘 7 項（票 C，對應 SPEC-001 v1.12、SPEC-003 v1.31）：R4（4.23 `withDetail` 變體表補兩值有意冗餘註記）；R7（刪除「返回 Domain 視圖」與 `backToDomainAction`：§3.1 總表、§3.6 §2 flow 未結構化列、4.4 變體表與 i18n `label` 列、4.21 i18n 動作列共 5 處）；R10 三處（§3.6 §5 無破洞列改「`EmptyState.page` 無動作 + `SplitRow.header` 重新掃描」；4.21 變體表 `page`／slot 契約 `actions`／測試點改動作必填範圍為 FR-03 列舉狀態與未選專案、未選節點，無破洞為 0；§3.7 出處補記第 18 項補「涵蓋無破洞與有破洞兩狀態」）；R11（4.40 `ListRow.item` 變體表與 slot 契約 `secondary` 補「檔案路徑，來源含行號時附行號」）；附帶（4.23 用途段、元件清單總表、反例表移除「0.1 不渲染以純檔案模式檢視，待 `0.1.0-W1-035`」，改引用 `0.1.0-W1-035` 已定案的 `action-domain-degraded-view`，`plain` 變體補該條件式渲染出口與 `onDegradedView` slot、`useBuiltinSchemaAction` key）；併入 `0.1.0-W3-335.38` S-16（4.23 焦點列「Esc 後焦點落點」由提案改引用 SPEC-003 §2.10 新列）。本版不含 .38 其餘 S 項（票 C 15 項，另於 1.38 落檔） |
| 1.36 | 2026-09-14 | R9 追修回寫（`0.1.0-W3-335.37` WRAP 裁決，對應 SPEC-001 v1.11、SPEC-003 v1.30；`0.1.0-W3-335.40` 落地）：§3.6 對照表新增 §2–§6 各一列「專案未就緒」（`EmptyState.page`，動作 `AppButton.primary` 前往 Domain 視圖，`action-<screen>-goto-domain`），標頭已改引用 SPEC-001〈狀態總數〉不寫死數字（`0.1.0-W3-335.16`），故只需補列；4.21 `EmptyState`〈出現畫面〉補五處、i18n `message`／動作兩列補新 key 引用；§4.0.6 新增〈1.36 新增〉key 表：`projectUnreadyUnsetMessage`／`projectUnreadyLoadingMessage`／`projectUnreadyBlockedMessage`（依 Domain 視圖當時狀態三選一，五畫面共用）、`gotoDomainAction`（ARB 實檔待建，由對應畫面票加入） |
| 1.35 | 2026-09-14 | 對齊上游回寫（`0.1.0-W3-335.16`，對應 SPEC-001 v1.9、SPEC-003 v1.27；承 `0.1.0-W3-335.13`／`.18`／`.19` 與 `0.1.0-W3-335.14` 稽核清單）：(1) §3.7 新增〈出處補記〉，為 11 項無上游出處的核定逐項補出處或標撰寫期決策並指向相接的 SPEC-001／003 章節，核定結論不變；(2) UC Flow 視圖新增〈UC 選擇入口〉（§3.6）：`TwoColumnLayout` 右欄 `Panel.scrollable`[`Section.static`[`ListRow.option` × N]]，出處 UC-03 步驟 1，不採下拉的理由為 SPEC-003 §3.2 每 UC 一個直接可點錨點；`ListRow` 新增 `option` 變體（selected 態）；(3) `IssueMarker.gap` 錨點 `<layer>` → `<nodeId>`（缺下游的父節點）；(4) 4.39 `Tree` 新增〈展開集合初始值與缺口列〉（預設只顯示 PROP 層、含缺口分支自動展開至缺口層；缺口列不可點）；(5) §3.6 標題與列數改引用 SPEC-001〈狀態總數〉不寫數字，新增 §1 泳道 · 尚未選定 UC、§1 泳道 · flow 未結構化、§2 尚未選定 UC 三列並改寫 §2、§3、§4、§5 相關列；§2 樂觀更新政策列同改引用；(6) 事件流小表：`TableRow` 新增 `eventFlow` 變體（非互動、可被定位；孤立事件標記為非互動 `AppIcon`——SPEC-003 §3.2 無標記點擊條文，故不用恆可點的 `IssueMarker`），`DataTable.plain` 新增 `appendix` slot 使小表接在步驟表之下共用 `scroll-ucFlow-steps`；(7) `TableRow.ticket` 補 blockedBy 欄（`flex(1)`，欄首 `static`）與 located 態；(8) 破洞項 `ListRow.item` 主操作依指向節點型別，有指向者 trailing 為次要操作 `AppButton.text`（`action-gaps-open-source-<itemId>`）；(9) §4.0.10 新增定位場景 d（ticket 帶目標跳入）、e（事件流列）；(10) §4.0.6 新增 key 表（ARB 待建）。FlowStep 所屬 domain 的來源未定案（`0.1.0-W3-341`），事件流小表發出／消費格的 domain 值依賴該票，本檔只定呈現不定來源。SPEC-002 同步 1.6 |
| 1.34 | 2026-09-09 | `0.1.0-W3-170`（承 `0.1.0-W3-169` SR-11）：**4.26 測試點子節單列修正**——原「zh / en 五個 key 皆不溢位」寫死 key 數，而該元件 i18n 子節現列的 key 已多於五個（`viewGapsAction` 於 `0.1.0-W3-063` 新增後未同步此列），改為引用該子節列出的全部 key，並接上 §4.0.12 驗收段「不以該子節列舉的 key 數為上界」一句（`document-format-rules` 規則 10：可變計數不實例化）。**只改這一列**：4.26 其餘子節、§4.0.12、其他元件條目、§9 驗收標準皆未動。本票的測試驗收形態主體落在 `.claude/skills/tdd/references/layered-test-strategy.md`（新增「終端回饋訊息的三類驗收」段）與同目錄 `test-object-catalogue.md`（新增「終端回饋訊息」來源類別），本檔不重述 |
| 1.33 | 2026-09-09 | `0.1.0-W3-169`（承 `0.1.0-W3-167`）：**追加 §4.0.12「暫態提示的訊息設計要求」**（§4.0.11 之後，既有 §4.0.1–4.0.11 與 §4.1–4.42 編號未動）。五項可驗收要求——M1 訊息成分（結果陳述必要；操作指引禁置於 `message` 應由 `actionLabel` 承載；技術細節與檔案路徑禁止）、M2 長度與版面保障（核對對象為全部語系最長值 × 兩種測試尺寸，觸發截斷時改寫文案不放寬行數上限，`withAction` 下動作 label 先讓步；引 `ux-design-evaluation`〈按鈕級回饋〉「關鍵回饋文字要有版面保障」以標題文字不重述）、M3 placeholder（至多 1 個、型別限 `int` 與短識別 `String`、不得位於句首、各語系名稱與數量一致、零值另立不帶 placeholder 的 key）、M4 成敗措辭區分（句首即可區分，不依賴顏色——4.26 無變體級成敗配色；失敗再分「找不到目標」與「動作無法執行」，因後續處置不同）、M5 i18n key 命名（後綴慣例、載體標示、依事件非依畫面命名、`@<key>.description` 須寫觸發時機與畫面）。**不新增元件契約欄位**，各元件條目「回饋契約」子節既有欄位不改寫，§4 對應表不變，〈契約齊全的定義〉的機械判準因此不需同步。4.26 的「回饋契約」「內容政策」「i18n」三個子節各補一段引用本節（連同「哪些事件該走本元件由 SPEC-003 §2.13 判準 T 決定，不由本表既有列反推」一句）。§9 驗收標準新增一列（追加於 §4.0.11 該列之後）。§4.42 `SwitcherOverlay` 反例列的「既有 `shell.dart` 空殼」改為「原 … 整改完成」並附複驗結果（`lib/` 內 `showDialog` 類 0 命中，`0.1.0-W3-167` SR-9 併入本票）——該列自此為整改記錄非現存衝突。**§1〈回饋通道子表〉的「（提案）」標記維持不變**：其解除條件不在本票範圍 |
| 1.32 | 2026-09-09 | `0.1.0-W3-166`：新增 §4.0.11「終端回饋元件的元件層回饋日誌」，承接方法論〈元件層回饋日誌（觀測對偶）〉條款——本專案 0.1 唯一終端回饋元件 4.26 `AppSnackBar` 已於 `0.1.0-W3-165` 在元件內部加入顯示／靜默早退／使用者互動三類記錄，本節記其落地狀態並標明日誌不取代 4.26 內容政策子節既有的版面可讀性斷言。不新增元件契約欄位、不改寫任何元件條目的「回饋契約」子節既有欄位（§4 對應表不變）。不裁定提示元件的使用時機與類型分化，該議題另案（`0.1.0-W3-167`）處理 |
| 1.31 | 2026-09-09 | `0.1.0-W3-106.4`：§4.27–4.42 容器元件回饋契約格式更新（父票 `0.1.0-W3-106` 四張子票之四，最後一段，承接 AppShell 至 SwitcherOverlay）。逐容器依「把資料抽掉還有沒有互動」判別：4.27 `AppShell`／4.28 `PageColumn`／4.31 `TwoColumnLayout`／4.39 `Tree`／4.41 `Section` 五者不承載三層任一層、全數委派子件（掛載點寫「不適用」+ 委派清單，服務類型/四段/阻擋/防抖皆標「不適用於本容器本身」）；4.30 `Panel`／4.38 `SwimlaneGrid` 二者自身互動限於捲動或拖曳，不落入六類回饋事件的三層模型（掛載點寫「不適用於服務三層模型」，另由〈捲動／拖曳操作路徑的不變式〉承載，四段與服務類型比照標「不適用」）；4.35 `TableRow`／4.37 `MatrixGrid` 二者有自身第一層互動（整列 pressed／列首格 pressed），判定「本地即時」；4.40 `ListRow` 依變體分流（`tree` 本地即時、`item` 短暫非同步，逐字命中 SPEC-003 §2.12「外部開啟」實例）；4.36 `DataTable`／4.42 `SwitcherOverlay` 二者兼具「承載他人某層」與「自身互動」，比照 4.24 `LoadingState` 拆為「為誰承載」與「自身互動掛在哪一層」兩段書寫（DataTable：承載搜尋/篩選/排序第三層 vs 自身捲動路徑；SwitcherOverlay：承載選取專案後委派 4.24 的長時操作 vs 自身開合與點外部 dismiss 的本地即時第一層）。4.42 處理前 `rg` 實查全文「浮層開合由 4.42 承載」的全部引用（4.8／4.9／4.23 三處，非僅記憶中的清單），確認三處皆與本條目的服務類型判定一致（本地即時）。4.29 `SplitRow`／4.32 `Toolbar`／4.33 `BadgeRow`／4.34 `ButtonRow` 純佈局容器零互動，既有「不適用（六類事件全部）」單列已是顯式呈現，不需改動。既有語意判斷未被改寫，與方法論三層歸屬表比對無衝突。父票 `0.1.0-W3-106` 的全部元件條目（§4.1–4.42）至此皆已補齊顯式掛載點、失敗路徑四段與服務類型標註。檔頭版本段對齊 frontmatter |
| 1.30 | 2026-09-09 | `0.1.0-W3-106.3`：§4.15–4.26 資料視圖與狀態元件回饋契約格式更新（父票 `0.1.0-W3-106` 四張子票之三，承接 MatrixCell 至 AppSnackBar）。九個互動元件的「等待與結果」列改寫，格式與 `0.1.0-W3-106.1`／`106.2` 一致，惟服務類型判定改依 SPEC-003 §2.12 的兩軸（使用者感知的等待長度／失敗形態）直接判定，不再類比外推既有實例清單：4.15 `MatrixCell`／4.18 `ExpanderIcon`／4.19 `RelationItem`／4.23 `BlockedState` 判定為「本地即時」（選格、展開收合、跳轉、浮層與面板開合皆本地零等待且不可能失敗）；4.21 `EmptyState`／4.25 `LoadPrompt` 因動作按鈕實際觸發服務不同而分別判定為「不固定（依 actions 而定）」與「長時操作」；4.22 `MissingSourceState` 依兩軸判定為「短暫非同步」（亞秒等待、可能失敗）；4.26 `AppSnackBar` 判定為「短暫非同步」（本元件即該類政策對照表的第三層載體）。4.24 `LoadingState` 為長時操作類第二層本身的承載者，掛載點欄依「為誰承載哪一層」與「自身互動（取消鈕）掛在哪一層」拆分兩段書寫，避免混寫使讀者無法判斷取消按鈕第一層由誰保證（§2.5 取消契約與 §2.12「阻擋頁面內容時必須同時提供取消」在此交會）。4.16 `SwimlaneNode`／4.17 `StepNumber`／4.20 `DocumentBody` 純顯示零互動層級，既有「不適用（六類事件全部）」單列已是顯式呈現，不需改動。既有語意判斷未被改寫，與方法論三層歸屬表比對無衝突。檔頭版本段對齊 frontmatter |
| 1.29 | 2026-09-09 | `0.1.0-W3-106.2`：§4.8–4.14 互動元件回饋契約格式更新（父票 `0.1.0-W3-106` 四張子票之二，承接 ProjectSwitcherEntry 至 TableColumnHeader）。六個互動元件的「等待與結果」列改寫，格式與 `0.1.0-W3-106.1` 一致（掛載點固定句首 + 服務類型逐字取自 SPEC-003 §2.12 + 成功／失敗／逾時／服務不可用四段 + 輸入阻擋範圍／重複觸發防護）：4.8 `ProjectSwitcherEntry`／4.10 `SegmentedControl`／4.13 `FilterDropdown`／4.14 `TableColumnHeader`（`sortable` 變體）判定為「本地即時」（浮層開合、模式切換、篩選選取、排序重排，皆為本地已載入資料的同步操作）；4.9 `RecentProjectItem` 判定為「長時操作」（點選觸發專案切換與 Domain 載入，第二／三層委派 4.24 `LoadingState`）；4.12 `SearchField` 判定為「延遲觸發」（逐字取自 SPEC-003 §2.12 0.1 實例），其重複觸發防護欄同步 `0.1.0-W3-110`／`0.1.0-W3-126` 既有的防抖歸屬定案（防抖由呼叫端搜尋詞 provider 承擔，非本元件），措辭一致無牴觸。4.11 `PageTitle` 純顯示零互動層級，既有「不適用（六類事件全部）」單列已是顯式呈現，不需改動。既有語意判斷（含 `0.1.0-W1-057` 補件的 4.13／4.14 選單開合與排序循環契約）皆未被改寫，只補顯式標籤與四段結構；六者與方法論三層歸屬表比對後無衝突，Solution 無需記錄衝突項。檔頭版本段對齊 frontmatter |
| 1.28 | 2026-09-09 | `0.1.0-W3-106.1`：§4.1–4.7 基礎元件回饋契約格式更新（父票 `0.1.0-W3-106` 四張子票之一，本票承接 AppText 至 NavItem）。實查全節後，純顯示元件 4.1 `AppText`／4.2 `AppIcon`／4.3 `Divider`／4.5 `Badge` 四者的回饋契約既以「不適用（六類事件全部）」單列涵蓋全部六類事件並附理由，已是顯式掛載點呈現（零互動層級可掛），不需改動。互動元件 4.4 `AppButton`／4.6 `IssueMarker`／4.7 `NavItem` 三者的「等待與結果」列改寫：反應欄首段改為「掛載點：第 N 層……」固定句首明示承載層級（依方法論〈掛載點〉三層歸屬表，`component-library-bidirectional-constraint-methodology.md`）；補「服務類型」標註（類別名逐字取自 SPEC-003 §2.12：4.6／4.7 為「本地即時」，4.4 因泛用於全部四類故列舉四名並註明第一層不隨服務類型變動）；「成功／失敗／逾時／服務不可用」四段呈現（依方法論〈失敗路徑覆蓋〉，重複結局寫「同」不留空；4.6／4.7 的失敗／逾時／服務不可用三段引用 SPEC-003 §2.12「本地即時類不可能失敗」的分類理由，非空泛「不會發生」）；補「輸入阻擋範圍」與「重複觸發防護」（4.4 因第二三層委派呼叫端而標「不適用於本元件」並引 SPEC-003 §2.12 判準表與不變式 INV-FEEDBACK-001；4.6／4.7 依本地即時類政策標「不阻擋」「無需（天然冪等）」）。既有語意判斷（承載哪一層、何時觸發、成功結局的具體內容）皆未被改寫，只補顯式標籤與四段結構；三者與方法論三層歸屬表比對後無衝突，Solution 無需記錄衝突項。檔頭版本段對齊 frontmatter |
| 1.27 | 2026-09-09 | `0.1.0-W3-126`：修訂 4.12 `SearchField` 與 4.36 `DataTable` 的防抖歸屬敘述，改為服務層歸屬（承接 `0.1.0-W3-110` 移除元件層 `_debounceTimer`，用戶裁示：防抖由服務承擔）。4.12 state-change 列「反應」欄改為「元件每次非組字輸入即呼叫一次 `onChanged`，元件不防抖，防抖由呼叫端搜尋詞 provider 承擔」，同列「時間門檻」欄的 `onChanged` 值同步由「輸入停止後 `Motion.searchDebounce`」改為「無（元件每次輸入即呼叫）」；測試點驗收改為「輸入後 `pump` 即 `onChanged` 恰一次」。4.36 state-change 列「時間門檻」欄「防抖由 4.12 承載」改為「防抖由搜尋詞 provider 承載，非 4.12 元件」。`Motion.searchDebounce` token 與其 300 ms 時限（定義於 SPEC-003 §2.1）未被改動——本次只改「誰做防抖」不改「防抖多久」。檔頭版本段對齊 frontmatter |
| 1.26 | 2026-09-08 | `0.1.0-W3-069`：(1) SPEC-003 §3.1 列名展開的錨點同步——三處逐字引用「格選中態出現」（L591 §4.0.10 高亮 token 列、4.37 `MatrixGrid` state-change 列、4.36 `DataTable` state-change 列）改為新列名「矩陣格的選取標記出現」，字串比對仍成立；L2102 4.13 `FilterDropdown` active 列引用的是 SPEC-003 §3.4 可觀察結果句「該篩選呈選中態」（非本次改動的列名），不動。(2) 併入 `0.1.0-W3-068` 預告的未來斷點：4.42 `SwitcherOverlay` 焦點列由僅寫 Esc 路徑擴為三條收合路徑（Esc、點浮層外部、系統通知點擊視同點外部）皆焦點回 `project-switcher-entry`，並註明通知點擊路徑下焦點隨後由定位段移入被定位項；對應狀態邊與回饋通道欄同步，使 4.27 locate 列對「4.42 收合契約」的引用有焦點列與 state-change 列兩個獨立支撐點，不再單獨依賴 state-change 列。檔頭版本段對齊 frontmatter |
| 1.25 | 2026-09-08 | `0.1.0-W3-068`：§4.0.10 接線的指向端同步（basil-writing-critic 複驗 `0.1.0-W3-066`，四項 warning 同一根因——接線只做單邊）：(1) §4.0.10 引言改為逐一對應實際措辭「4.18／4.21／4.23 各以『機制依 §4.0.10』回指本節」並註明各自角色（4.18 場景 c 容器分工、4.21 焦點移入、4.23 0.1 無場景後續版本適用），不再以「由容器條目補」統稱；(2) 4.18 locate 列刪「短暫高亮的 token 與時長由該容器條目定義」與尾端「提案：由容器條目補」，改為單一權威句「子項若落在 viewport 外由承載子層的容器執行捲動，機制依 §4.0.10（場景 c：最小捲動、不高亮，焦點停在展開器）」，消除高亮／不高亮並置矛盾；(3) 4.27 locate 列引用來源由「焦點列」改「4.42 收合契約」，並補「定位段的焦點移入覆蓋收合的焦點歸位」；(4) 4.42 expanded／noRecent 退出路徑補「系統通知點擊（視同點外部，見 4.27 locate 列）→ 收合」，locate 列對應狀態邊由「不適用」改「expanded／noRecent → 消失（通知點擊視同點外部，見 4.27 locate 列）」。info 三項：4.21 引用改「（觸發者、輔助技術與定位失敗列）」；§4.0.10 高亮時長列宣稱範圍收窄為場景 a 並註明場景 b（`laneHighlight` 持續性標記）／場景 c（不高亮）不適用；執行端列錨點清單加限定語「0.1 定位場景涉及的…等錨點」。檔頭版本段對齊 frontmatter |
| 1.24 | 2026-09-08 | `0.1.0-W3-065`：全檔用語統一（承接 `0.1.0-W3-066` 留給本票的用語項，basil-writing-critic 終版審查 info）：正文「用戶」改「使用者」（39/373 兩處，即 L368「用戶補充」、L373「用戶另裁示」、L397「用戶經 WRAP 重評裁決」），「用戶簽核」作為核定狀態標記的既有用法不動（frontmatter 與其他 spec 同用，另票處理）；正文「選中」改「選取」共 19 處（L140、L312 兩處、L460、L611、L1450、L1742、L1800、L1826、L1828、L1830、L1834、L1850、L1937、L2103、L2181、L2462、L2824、L3822），L591／L2102／L2395／L5042 四處為 SPEC-003 表格列名的逐字引用錨點（「格選中態出現」「該篩選呈選中態」）不動。另承接既有導覽頁計數慣例（4.27 焦點列「六個導覽項」、§2.8 引用處「六頁」「一次建構六頁」等，`0.1.0-W3-066` info）：導覽頁集合由 SPEC-001 決定，正文改引用式描述「全部導覽頁／全部導覽項」，共 21 處（含 §3.1 總表 `AppIcon`／`NavItem` 用途欄、§4.7 `NavItem` 全節、4.27 `AppShell` 焦點列、4.28 `PageColumn` default 列、4.42 `SwitcherOverlay` 按下確認／等待結果列）；§3.2 視覺盤點表（L192 `NavItem` × 6）為畫布觀察記錄非行為契約敘述，L3855「六頁建構時機」為 SPEC-003 表格列名逐字引用錨點，兩者不動；「六類事件／六類回饋事件」（方法論〈回饋契約〉六類事件分類）與 L237／L286／L1197 三處列舉合併的自身計數（六者、六種水平列、六種 tone）與 SPEC-001 導覽頁集合無關，不在本票範圍。檔頭版本段對齊 frontmatter |
| 1.23 | 2026-09-08 | `0.1.0-W3-066`：§4.0.10 定位提示約定三項契約自洽修正（basil-writing-critic 對 1.22 的終版審查）：(1) 雙向接線——4.18／4.21／4.23 locate 列各補「機制依 §4.0.10」，與 §4.0.10 引言的單向指向對齊；(2) 4.30 `locateTarget` 說明補場景分支——焦點移入與高亮只於被定位子件接受 `isLocated` 時執行（場景 a），場景 c 只做最小捲動不移焦點、頁面層於捲動完成的 post-frame 改回 `null`，不加參數；(3) 4.27 locate 列補 overlayOpen 時通知點擊視同點外部、先收合浮層再執行切頁段與定位段，狀態邊改為 overlayOpen → default，與焦點列（浮層 `FocusScope`）不再衝突。計數字面：§4.0.10 執行端列刪「三個」，4.39 state-change 列「三個畫面狀態」改「各畫面狀態（SPEC-003 §3.3 動畫提示）」。變更歷史 1.22 列補記 4.36 篩選後 offset 由保留修正為歸零。info 機械項：4.26 dismissed 來源列「同上」改「不存在即為預設；`show` 機制見 shown 列」、§4.0.1 段末去重述、§4.0.10 高亮時長列補「§1 子表與 SPEC-003 §2.2 的『短暫』於 0.1 即指此焦點綁定機制」。用語（「用戶／選中／六個導覽項」）不動，由 `0.1.0-W3-065` 承接；檔頭版本段對齊 frontmatter |
| 1.22 | 2026-09-08 | `0.1.0-W3-060.5`：4.27–4.42 十六個容器條目「互動反應」子節依範本 1.13.0 改名「回饋契約」並展開為回饋事件六類（欄位同 1.19），全檔不再有「互動反應」子節；通道欄逐列引用 §1〈回饋通道子表〉不重抄，反應與時間門檻抄 SPEC-003（§1.1、§1.3、§2.1、§2.2 含外部開啟契約與系統層通知、§2.3、§2.4、§2.6、§2.8、§2.10、§3.1–§3.7），通道與對應狀態邊由本票填。純佈局容器 4.29 `SplitRow`／4.32 `Toolbar`／4.33 `BadgeRow`／4.34 `ButtonRow` 整節填一列「不適用 + 理由」；4.27 `AppShell`／4.28 `PageColumn`／4.30 `Panel`／4.31 `TwoColumnLayout` 前三列不適用、state-change 與 locate 列寫容器承載的過渡與分工；可點列 4.35 `TableRow`／4.40 `ListRow` 與資料視圖容器 4.36–4.39、覆蓋層 4.42 六列全填。新增 §4.0.10「定位提示（locate）的容器執行約定」（提案）：一維執行端 4.30 `Panel.scrollable`／4.36、二維 4.37／4.38，即時定位不用 `animateTo`，高亮 token `AppColors.surfaceIconTint`，高亮時長為焦點機制非數值（不新設 `Motion` token），定位失敗只切頁不拋錯、不改變展開集合，0.1 三場景（系統通知點擊／`viewGapsAction` → 第一個 `card-gaps-<itemId>`；矩陣 → 泳道列；樹展開後子項最小捲動不高亮），並接線 SPEC-003 §2.2 點擊導向與 4.18／4.21／4.23「由容器條目補」提案；4.40 `ListRow.item` 新增 located 狀態與 `isLocated` 傳值、4.30 新增 `locateTarget`、4.38 新增 `locateLane` 定位入口（提案）。既有互動反應表中的捲動／拖曳／視窗尺寸不變式移為各容器回饋契約表後的「操作路徑不變式」段。十六條目狀態矩陣加「來源」「同步策略」兩欄：4.27／4.42 `switcherOpenProvider`（4.27 另含 `selectedDestinationProvider`／`returnToProvider`／`visitedDestinationsProvider`／`firstVisibleProvider`）、4.39 `expandedTraceNodesProvider`／`traceabilityStateProvider`、4.41 破洞類別節為頁面 `State`；Domain 視圖、Ticket 清單、UC Flow、破洞報告定位狀態的 provider 未建者標由畫面票補填（以畫面名為鍵）；4.35／4.40 合併瞬態列拆為範本三列，其餘容器以一句註明由子件承載。時限依 PM 裁決：hover／focus／本地即時切換填「無」標提案；等待與結果、state-change 過渡抄 SPEC-003（`Motion.feedback`／`transition`／`overlay`／`searchDebounce`／`snackBar`），未建待決票。併修 060.4 二次審查（basil-writing-critic）七項：§4.0.1 拆列規則補「內嵌 `AppButton` 或子件承載者不拆列」例外、來源欄段首補用途句、「資料態」括號擴為含 §2 允許的頁面 `State`、「互動瞬態」括號補「含命令式 show／dismiss 開合」；4.26 shown 來源改「互動瞬態（`ScaffoldMessenger` 內部承載）」；4.24／4.26 回饋契約引言補回時間門檻「無」句；4.21 locate 列「其餘七處」改「其餘」；`viewGapsAction` 登記 §4.0.6 新 key 總表與 4.26 i18n（ARB 由 `0.1.0-W3-064` 加）。併修 4.13 press-ack 列「篩選七列」改「篩選各列」。§4.0 對應表「回饋契約」列改為純靜態映射、§4.0.1 末段落成進度括號刪除、§4.0.9 一處「互動反應」改「回饋契約」；4.36 state-change 列篩選後 offset 由保留修正為歸零（對齊 SPEC-003 §3.4）；檔頭版本段對齊 frontmatter |
| 1.21 | 2026-09-08 | `0.1.0-W3-060.4`：4.15–4.26 十二條目「互動反應」子節依範本 1.13.0 改名「回饋契約」並展開為回饋事件六類（欄位同 1.19）；通道欄逐列引用 §1〈回饋通道子表〉不重抄，反應與時間門檻抄 SPEC-003（§2.1、§2.2 含外部開啟契約與系統層通知、§2.5 C1–C8、§2.6、§2.7、§2.8 L1–L2、§2.10、§3.1–§3.7 互動反應／動畫提示／生命週期），通道與對應狀態邊由本票填。純顯示元件 4.16 `SwimlaneNode`／4.17 `StepNumber`／4.20 `DocumentBody` 整節填一列「不適用 + 理由」（drag 平移與泳道列定位由 4.38、捲動與內容替換由 4.30 承載）；可點元件 4.15 `MatrixCell`／4.18 `ExpanderIcon`／4.19 `RelationItem` 六列全填，locate 列一律「由容器承載」並寫明容器與 0.1 無定位場景的依據（4.15 已選格捲離不捲回、4.18 展開後子項定位由 4.39／4.41 容器條目定義、4.19 為跳轉來源非目標）；內嵌 `AppButton` 的狀態元件 4.21 `EmptyState`／4.22 `MissingSourceState`／4.23 `BlockedState`／4.24 `LoadingState`／4.25 `LoadPrompt`／4.26 `AppSnackBar` 前三列路由至 4.4、只寫元件層級補充，4.21 locate 列補系統通知導向 `state-gaps-none` 的焦點落點（根節點 `Focus`，提案）、4.24 明文為等待指示層本身並將 C1–C8／L1–L2 分配至各列、4.26 明文為結果通知層與 `denied` fallback 載體。時限依 PM 裁決：hover／focus／本地即時切換填「無」標提案；等待與結果、state-change 過渡抄 SPEC-003（4.15 `Motion.feedback`、4.22 與 4.24 `Motion.cancelDeadline`、4.24 `Motion.progressTick`／`spinnerMinVisible`、4.26 `Motion.snackBar`／`snackBarWithAction`），未建待決票。十二條目狀態矩陣加「來源」「同步策略」兩欄：4.18 `expandedTraceNodesProvider`（破洞報告分節為頁面 `State`）、4.21 `gapReportProvider.GapReportNoGaps`／`traceabilityStateProvider.TraceabilityNoProposal`、4.24 `gapReportProvider.GapReportScanning`（loading 等確認才顯示、cancelling 本地即時）；4.19 default／damaged 為等確認才顯示；Domain 視圖、UC Flow、Ticket 清單、節點詳情 provider 未建者標由畫面票補填；4.15／4.18／4.19 合併瞬態列拆為範本三列，4.21–4.26 互動瞬態由內嵌 4.4 承載以一句註明不另列。併修 060.3 二次審查（basil-writing-critic）四項 warning：§4.0.1「來源」欄三值定義依 PM 裁決方案一擴充「互動瞬態」括號（含元件內部 overlay 開合等不存於 provider 的本地狀態）、退出路徑句限定於 hover／pressed／focused 三列、補混填 Consequence 一句、「由對應畫面票補填」後加「（以畫面名為鍵）」；4.11 回饋契約「選中的回饋」改「選取的回饋」；4.13 回饋契約引言「篩選七列」改「篩選各列」（計數字面）。§4.0 對應表與 §4.0.1 末段的落成範圍同步；檔頭版本段對齊 frontmatter。4.27 以後條目不動（`060.5`） |
| 1.20 | 2026-09-08 | `0.1.0-W3-060.3`：4.8–4.14 七條目「互動反應」子節依範本 1.13.0 改名「回饋契約」並展開為回饋事件六類（欄位同 1.19）；通道欄逐列引用 §1〈回饋通道子表〉不重抄，反應與時間門檻抄 SPEC-003（§2.1、§2.2、§2.6、§2.10、§3.1、§3.4 篩選七列／F1–F7／S1–S7／動畫提示、§3.7），通道與對應狀態邊由本票填。純顯示元件 4.11 `PageTitle` 整節填一列「不適用 + 理由」；可互動元件 4.8 `ProjectSwitcherEntry`／4.9 `RecentProjectItem`／4.10 `SegmentedControl`／4.12 `SearchField`／4.13 `FilterDropdown`／4.14 `TableColumnHeader` 六列全填，locate 列一律「由容器承載」（4.12 為搜尋來源，命中列定位由 4.36 `DataTable` 執行；4.14 `static`／`twoLine` 依 S7 逐列註明不適用，不另立整節不適用列）。4.12 state-change 時限抄 SPEC-003 §3.4（`Motion.searchDebounce`／清除立即），4.13 press-ack 選單開合 `Motion.overlay`，4.14 state-change 指示更新於 `Motion.feedback` 內；hover／focus／選取切換等本地即時列時間門檻填「無」標提案（PM 裁決自 060.2 驗收），未建待決票。七條目狀態矩陣加「來源」「同步策略」兩欄：4.8 `switcherOpenProvider`／`currentProjectNameProvider`、4.9 `recentProjectsProvider.enabled`（等確認才顯示）／`currentProjectIndexProvider`、4.13 open 為元件內部 overlay 瞬態（F7 保證切頁時必為收合態）；4.10／4.12／4.13／4.14 的 Ticket 清單與 Domain 視圖 provider 未建者標由畫面票補填；合併瞬態列拆為範本三列（4.12 pressed 列註明 `TextField` 無 pressed 態、由清除鈕承載）。併修 060.2 二次審查（basil-writing-critic）三項 warning：狀態矩陣「來源」欄枚舉值收斂為互動瞬態／資料態／—，4.1／4.2／4.3／4.5 default 與 4.4 enabled 五處建構即渲染列改「—」並於 §4.0.1 末段明文三種值；§3.7 引言的 DOC-GPD-003 字面移為段末 HTML 註解；4.7 state-change 列兩處「選中」改「選取」（本票新增段落一律用「選取」，既有 27 處另票）。info 兩項一併採納：4.3 `Divider` 通道格改「不適用（無互動，無承載者）」、4.4 disabled 來源欄 `isCancelling` 改寫為 `GapReportScanning.isCancelling`（`gap_report_models.dart`，由 `gapReportProvider` 持有）。§4.0 對應表與 §4.0.1 末段的落成範圍同步；檔頭版本段對齊 frontmatter。4.15 以後條目不動（`060.4`–`060.5`） |
| 1.19 | 2026-09-08 | `0.1.0-W3-060.2`：4.1–4.7 七條目「互動反應」子節依範本 1.13.0 改名「回饋契約」並展開為回饋事件六類（欄：事件／觸發者／反應／動畫 token／時間門檻／回饋通道（桌機）／對應狀態邊／填寫者）；通道欄逐列引用 §1〈回饋通道子表〉不重抄，反應與時間門檻抄 SPEC-003（§2.1、§2.2、§2.5 C2、§2.10、§3.3、§3.4），通道與對應狀態邊由本票填，填寫者欄逐列標明。純顯示元件 4.1 `AppText`／4.2 `AppIcon`／4.3 `Divider`／4.5 `Badge` 整節填一列「不適用 + 理由」；可點元件 4.4 `AppButton`／4.6 `IssueMarker`／4.7 `NavItem` 六列全填，locate 列填「由容器承載」（非資料視圖容器不執行 scroll-into-view）。SPEC-003 無時限條文的 hover／focus／導覽項選中切換，時間門檻填「無」標提案（機制為本地即時，不另設數值），未建待決票。七條目狀態矩陣加「來源」「同步策略」兩欄：互動瞬態填「互動瞬態／本地即時」，資料態填 provider 名（4.7 `selectedDestinationProvider`、4.4 disabled 為 `gapReportProvider` 的 `isCancelling`、4.6 `gap` 為 `traceabilityStateProvider`；Domain／Ticket 載入 provider 未建者標由畫面票補填）；既有合併列「hover / pressed / focused」拆為範本三列，§4.0.1 末段規則同步改寫。併入 060.1 SR-2：§3.7 引言與 §4.0 引言三處欄位計數字面改引用方法論〈元件契約欄位表〉，§4.0 引言下補「方法論欄位 ↔ 本檔子節」對應表取代不存在的檔頭註解（DOC-GPD-003）；檔頭版本段由陳舊的 1.17 對齊 frontmatter。4.8 以後條目不動（`060.3`–`060.5`） |
| 1.18 | 2026-09-08 | `0.1.0-W3-063`：§1〈回饋通道子表〉state-change 列的「不在視野時是否升級 macOS 系統通知」由**待核定**改為已簽核（用戶簽核 2026-09-08）——升級條件「掃描完成 AND（視窗非前景 OR 已離開觸發頁）」，規格引用 SPEC-003 §2.2「系統層通知」（v1.9），0.1 僅此一處升級；本表狀態段移除待核定句。只動 §1 一列與狀態段，第 4 章逐元件條目不動（`060.2`–`060.5`） |
| 1.17 | 2026-09-08 | `0.1.0-W3-060.1`：依範本 1.13.0 與方法論 1.14.0，§1「回饋通道」列展開為〈回饋通道子表〉（回饋事件六類 × 桌機單欄，提案）：affordance = hover、focus = 焦點環 + 鍵盤導覽、press-ack = pressed + ripple 於 `Motion.feedback` 內、locate = scroll-into-view + 短暫高亮 + 輔助技術焦點移入、state-change = `Motion.*` 過渡 + 無障礙播報（不在視野時升級 macOS 系統通知列標**待核定**，0.1 預設不用）、等待與結果 = SPEC-003 §2.2 三層；無觸覺、無聲音。§2 新增「過渡提示觸發點」（提案：呼叫端顯式觸發，容器例外於 `ref.listen` 內比對新舊值後觸發仍屬呼叫端）與「樂觀更新政策」（提案：0.1 不允許，同步策略欄不得填「樂觀更新後確認」；重評綁定 PROP-005〈0.x — 編輯〉落為提案票時）兩列。檔頭版本段由陳舊的 1.10 對齊 frontmatter；層級定位段「十一欄位」字面改為引用方法論〈元件契約欄位表〉（DOC-GPD-003）。第 4 章逐元件條目不動（`060.2`–`060.5`） |
| 1.16 | 2026-09-03 | `0.1.0-W1-061`：對齊 4.11 `PageTitle` 副標的語意角色——內容角色明寫 `subtitle` 為 slot 名、渲染變體為 `AppText.body` 非 `AppText.subtitle`（後者恆為 `Semantics.header`，副標不得為 header）；狀態矩陣補 `secondary: true` + `maxLines: 1` 與著色寫法選擇理由（依 4.1 優先序取 `secondary` 而非 `tone: textSecondary`）；token 字體列標明畫面名／副標各自變體；無障礙朗讀標籤列補副標非 header。4.1 `AppText` 變體表：`subtitle` 行為差異補「恆標記 `Semantics.header`（header 語意，非副標用途）」與替代寫法（`body` + `secondary` + `maxLines: 1`）；`body` 何時選用補頁首副標；`caption` 何時選用移除「副標」改指向 `body` 列。契約值與 `lib/components/page_title.dart` 現況一致，實作不變 |
| 1.15 | 2026-09-03 | 回填元件票實作偏離對齊：4.10 `segments` 型別 `Segment` 改 `SegmentItem`（撞名，實作已更名，語意不變）；4.35／4.36 首段補實作類別名（`AppTableRow`／`AppDataTable`，撞名更名，契約條目名與契約值不變）；4.13 `FilterDropdown` 去「待決」標記，依 SPEC-003 §3.4 篩選七列與 F1–F7 元件級契約補齊狀態矩陣 `open` 列、互動反應、無障礙播報、選單的元件級契約子節與 F7 實作註記；§4.0.9 待決清單移除 4.13 一列（全部 42 條目無待決欄位）；4.24／4.27／4.38 新增實作註記（進度百分比等價轉換、返回列以獨立疊加列取代注入 `PageColumn`、底部箭頭列因套件限制不釘選），皆為實作層面說明、非契約值變更。其餘型別放寬類偏離（`AppButton.leading`／`IssueMarker.child`／`PageColumn.header`／`content`／`Panel.children`／`Toolbar.filters`／`ListRow.leading`／`trailing`／`AppShell.overlay` 暫以 `Widget` 承接；`ListRow.sectionHeader`／`RecentProjectItem`／`NavItem` 取色繞過 `AppText`；`BlockedState.withDetail` 動作列改用 `Wrap`；4.11 `PageTitle` 副標變體）不改本檔契約內容，維持現況待對應收斂票落地 |
<!-- rule8-exempt: illustration:比照既有變更歷史列引用票號格式 -->
| 1.14 | 2026-09-03 | `0.1.0-W1-066`：4.4 `AppButton` slot 契約新增 `semanticExpanded`（`bool?`，`null` 不附加旗標）與無障礙「狀態變化播報」列說明，讓帶展開語意的動作按鈕（如 4.23 `BlockedState.withDetail` 檢視詳情鈕）不需呼叫端外部包裹 `Semantics(expanded: ...)` 即可維持 `AppButton` 型別，回收 4.34 `ButtonRow` 的 `List<AppButton>` 型別限定 |
| 1.13 | 2026-09-03 | 補齊 4.1 `AppText` 語意色參數：新增修飾參數 `tone`（`AppTextTone` 列舉，五色對應 `AppColors` 語意色）與「修飾參數優先序」子節，消除元件內繞過 `AppText` 直接建 `Text` 的三處（`ListRow.sectionHeader` 主色、`RecentProjectItem` name／summary、`NavItem` icon 色由 `isSelected` 推導） |
| 1.12 | 2026-09-02 | `TableColumnHeader` 元件票實作時依 SPEC-003 §3.4 S1–S7 補齊 4.14 `sortable` 變體的互動反應（點選呼叫 `onSort`，下一個 `order` 由呼叫端決定）、狀態矩陣退出路徑、無障礙狀態變化播報值，去除本條目「待決」標記；§4.0.9 待決清單移除 4.14 一列（餘 4.13 `FilterDropdown` 一項），41 條目無待決欄位 |
| 1.11 | 2026-09-02 | `LoadPrompt` 元件票實作時修正 4.25 `LoadPrompt` 內容政策與測試點：`message` 原標「可換行、最大行數 2、末行截斷」與同條目「最小尺寸」列（訊息一行）及 slot 契約（訊息取 `AppText.subtitle`，單行變體）自相矛盾，`AppText`（4.1）subtitle 變體恆為單行不接受 `maxLines`；改為「不可換行、最大行數 1、末端省略」，測試點「最長測試文案兩行末截斷」同步改「最長測試文案單行末端省略」 |
| 1.10 | 2026-09-02 | 實作校正（`MissingSourceState` 元件票）：4.22 狀態矩陣「顯示」「可用操作」「退出路徑」三欄與「互動反應」「slot 契約」（僅 `path`／`onRefresh`／`testKey`，無 `returnTo`）內部不一致——`ButtonRow` 移除「返回」按鈕，改註明返回鍵由頁面框架於 `SplitRow.header` 統一渲染，與 §3011 既有澄清對齊；內容政策 `message`／`path` 兩列原標可換行（2／3 行）與 `AppText.subtitle`／`AppText.mono` 已核定的單行鎖定契約（4.1）矛盾，改標單行截斷，與實作行為一致 |
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
