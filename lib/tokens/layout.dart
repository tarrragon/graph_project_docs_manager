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
}
