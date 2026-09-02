/// 佈局尺寸 token（SPEC-002 FR-04；SPEC-004 §3.7 第 21 項）。
///
/// 畫布固定佈局尺寸的原始值來自 0.1.0-W1-044.1 NeedsContext 第 1 項
/// （量測環境：`design/*.dc.html` 內聯樣式，設計基準無縮放）。多數項目
/// 為單一元素的單一原始值，非產生器輸出的雜訊尺度，故逐一具名，不比照
/// 間距／字級歸階為離散階；僅「表格列高」與「主副雙欄右欄寬」有多值
/// 需收斂，收斂方式見下方兩節。
///
/// | token | 值 | 原始值 | 用途 |
/// |-------|----|--------|------|
/// | [LayoutSize.sidebarWidth] | 172 | 172 | 側欄固定寬 |
/// | [LayoutSize.headerHeight] | 52 | 52 | 頁首高 |
/// | [LayoutSize.rowHeightDense] | 29 | 28、29、31（見〈表格列高歸併〉） | 結構性列（節首／巢狀列） |
/// | [LayoutSize.rowHeightRelaxed] | 34 | 32、34、36（見〈表格列高歸併〉） | 扁平內容列 |
/// | [LayoutSize.detailPaneWidth] | 236 | 236、216（見〈右欄寬收斂〉） | 主副雙欄右欄寬 |
/// | [LayoutSize.overlayWidth] | 262 | 262 | 專案切換浮層寬 |
/// | [LayoutSize.matrixLeadColumnWidth] | 132 | 132 | 矩陣首欄寬 |
/// | [LayoutSize.matrixSubtotalWidth] | 46 | 46 | 矩陣小計欄寬 |
/// | [LayoutSize.laneLabelWidth] | 106 | 106 | 泳道名欄寬 |
/// | [LayoutSize.laneRowHeight] | 52 | 52 | 泳道列高（與 [LayoutSize.headerHeight] 恰好同值，各自獨立量測，非共用來源） |
/// | [LayoutSize.iconSm] | 13 | 13 | 圖示尺寸階：小 |
/// | [LayoutSize.iconMd] | 15 | 15 | 圖示尺寸階：中 |
/// | [LayoutSize.iconLg] | 17 | 17 | 圖示尺寸階：大 |
/// | [LayoutSize.hitTargetMin] | 28 | 25～31（見〈最小命中區〉） | 可點元件最小命中區（桌機指標形態） |
/// | [LayoutSize.titleBarHeight] | 36 | 36（九份 artboard 頂端標題列 height，一致） | `AppShell` 標題列高（SPEC-004 4.27） |
/// | [LayoutSize.ticketIdColumnWidth] | 132 | 132（`TicketListA` grid-template-columns 第 1 欄） | `TableRow.ticket` ID 固定寬欄（SPEC-004 4.35） |
/// | [LayoutSize.ticketStatusColumnWidth] | 84 | 84（`TicketListA` 第 3 欄） | `TableRow.ticket` 狀態固定寬欄 |
/// | [LayoutSize.ticketPriorityColumnWidth] | 40 | 40（`TicketListA` 第 4 欄） | `TableRow.ticket` 優先固定寬欄 |
/// | [LayoutSize.ticketMarkerColumnWidth] | 22 | 22（`TicketListA` 第 5 欄） | `TableRow.ticket` 標記固定寬欄（欄間 gap 12 = [Space.md]，非本檔範圍） |
/// | [LayoutSize.stepNumberColumnWidth] | 26 | 26（`UCFlowB` grid-template-columns 第 1 欄） | `TableRow.step` 序號固定寬欄（SPEC-004 4.35） |
/// | [LayoutSize.stepDomainColumnWidth] | 118 | 118（`UCFlowB` 第 3 欄） | `TableRow.step` domain 固定寬欄（第 2、4 欄為 `1fr` 等分填滿欄，非固定寬，不建 token） |
/// | [LayoutSize.treeIndent] | 24 | 24（`TraceA` 各層 padding-left 0/24/48/72，等差） | `Tree` 每層縮排（SPEC-004 4.39） |
/// | [LayoutSize.stepNumberSize] | 24 | 16（`Main` 詳情卡方形 `border-radius:4px`）與 24（`UCFlowB` 圓形 `border-radius:12px`）兩值，見〈StepNumber 尺寸收斂〉 | `StepNumber` 直徑（SPEC-004 4.17） |
/// | [LayoutSize.matrixColumnWidth] | 122 | 畫布為 `repeat(5,1fr)` 無固定值，由 `Main` 版面推算，見〈MatrixGrid UC 欄寬定案〉。已核定 | `MatrixGrid` UC 欄寬（SPEC-004 4.37；委派 `two_dimensional_scrollables` 需固定欄寬） |
///
/// 導覽項的 padding（實測 7、10）不在本檔新增：兩值已落於
/// `spacing.dart` 的 [Space.sm]（8，吸收原始值 7、8、9、10）區間內，
/// 沿用既有 token，不重複建值。
///
/// ### 表格列高歸併（[LayoutSize.rowHeightDense] / [LayoutSize.rowHeightRelaxed]）
///
/// 六個實測列高（節首 28、主題模式票列 29、樹列 31、矩陣資料列 32、
/// 列表模式票列 34、表頭列 36）非設計過的離散階，是各元件各自獨立量測
/// 的產生器輸出。依實際用途分兩群，非就近湊整為單一值：
///
/// | 階 | 值 | 吸收的原始值（用途） |
/// |----|----|------------------------|
/// | [LayoutSize.rowHeightDense] | 29 | 28（節首列）、29（主題模式票列）、31（樹列）— 皆為巢狀／結構性列，取三值中位數 |
/// | [LayoutSize.rowHeightRelaxed] | 34 | 32（矩陣資料列）、34（列表模式票列）、36（表頭列）— 皆為扁平內容列，取三值中位數 |
///
/// ### 右欄寬收斂（[LayoutSize.detailPaneWidth]）
///
/// 畫布兩處「主副雙欄」右欄寬不同：矩陣格詳情卡 236、節點詳情右欄 216。
/// SPEC-004 §3.7 第 21 項核定收斂為單一值。矩陣格詳情卡內容較多（標題／
/// 說明／步驟／標籤堆疊），取兩者中較寬的 236，避免內容被壓縮；節點
/// 詳情右欄沿用同一寬度，內容較少時多出的留白不影響可讀性。
///
/// ### 最小命中區（[LayoutSize.hitTargetMin]）
///
/// SPEC-004 §1「最小命中區」列（桌機指標形態）。`design/Main.dc.html` 兩處
/// 最小可點元件實測：側欄導覽項（padding 7px 10px + 17px 圖示，高度
/// 7+17+7=31px）、頁首檢視切換分頁（padding 5px 12px + 12.5px 文字行高約
/// 15px，高度 5+15+5=25px），範圍 25～31px。桌機指標（滑鼠／trackpad）不像
/// 觸控需 44pt 級門檻，取 macOS 標準控制項 regular 高度 28pt 作為下限，
/// 落於實測範圍內，可點元件的尺寸契約引用本值作最小命中區下限。
///
/// ### StepNumber 尺寸收斂（[LayoutSize.stepNumberSize]）
///
/// 畫布兩處 `StepNumber` 尺寸不同：`Main` 詳情卡步驟清單用 16px 方形
/// （`border-radius:4px`），`UCFlowB` 步驟流用 24px 圓形
/// （`border-radius:12px`，半徑恰為直徑一半）。SPEC-004 §3.7 第 11 項已核定
/// 形態統一為圓形，故收斂值採圓形所在的 24，非方形的 16。
///
/// ### MatrixGrid UC 欄寬定案（[LayoutSize.matrixColumnWidth]）
///
/// 畫布 `Main.dc.html` 的 `DomainSwimlane` 矩陣格 grid-template-columns 為
/// `132px repeat(5,1fr) 46px`（無 gap），5 個 UC 欄以 `1fr` 等分，無固定
/// 像素值可直接量測；`MatrixGrid` 委派 `two_dimensional_scrollables` 做二維
/// 捲動，欄寬須為固定值，故以 `Main` 版面實際可用寬度反推：
///
/// ```text
/// artboard 寬 1280 − sidebarWidth 172 = 1108
/// 1108 − 內容區 padding 20×2           = 1068（雙欄列寬）
/// 1068 − 右欄 detailPaneWidth 236 − 雙欄 gap 14 = 818（矩陣面板寬）
/// 818 − 面板 padding 14×2 − border 1×2  = 788（grid 內容寬）
/// 788 − matrixLeadColumnWidth 132 − matrixSubtotalWidth 46 = 610（5 UC 欄合計）
/// 610 / 5 = 122
/// ```
///
/// 推算值 122 非畫布直接量測值，屬依既有面板尺寸鏈反推的提案值；PM 已於
/// 2026-09-02 核定（SPEC-004 §3.7 第 24 項），可供元件票排入正式畫面。
library;

/// 佈局尺寸離散值。畫面只引用具名常數，不接受任意數字。
abstract final class LayoutSize {
  static const double sidebarWidth = 172; // magic-exempt token 定義本身
  static const double headerHeight = 52; // magic-exempt token 定義本身
  static const double rowHeightDense = 29; // magic-exempt token 定義本身
  static const double rowHeightRelaxed = 34; // magic-exempt token 定義本身
  static const double detailPaneWidth = 236; // magic-exempt token 定義本身
  static const double overlayWidth = 262; // magic-exempt token 定義本身
  static const double matrixLeadColumnWidth = 132; // magic-exempt token 定義本身
  static const double matrixSubtotalWidth = 46; // magic-exempt token 定義本身
  static const double laneLabelWidth = 106; // magic-exempt token 定義本身
  static const double laneRowHeight = 52; // magic-exempt token 定義本身
  static const double iconSm = 13; // magic-exempt token 定義本身
  static const double iconMd = 15; // magic-exempt token 定義本身
  static const double iconLg = 17; // magic-exempt token 定義本身
  static const double hitTargetMin = 28; // magic-exempt token 定義本身
  static const double titleBarHeight = 36; // magic-exempt token 定義本身
  static const double ticketIdColumnWidth = 132; // magic-exempt token 定義本身
  static const double ticketStatusColumnWidth = 84; // magic-exempt token 定義本身
  static const double ticketPriorityColumnWidth = 40; // magic-exempt token 定義本身
  static const double ticketMarkerColumnWidth = 22; // magic-exempt token 定義本身
  static const double stepNumberColumnWidth = 26; // magic-exempt token 定義本身
  static const double stepDomainColumnWidth = 118; // magic-exempt token 定義本身
  static const double treeIndent = 24; // magic-exempt token 定義本身
  static const double stepNumberSize = 24; // magic-exempt token 定義本身
  /// 已核定值（見 dartdoc〈MatrixGrid UC 欄寬定案〉推算過程）。
  static const double matrixColumnWidth = 122; // magic-exempt token 定義本身
}
