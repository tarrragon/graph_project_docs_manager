/// 字級 token（SPEC-002 FR-04）。
///
/// artboard 實測字級為 9、10、11、12、13、14、15、19（SPEC-002 文件表列
/// 10–15、19，缺漏 9），同屬產生器輸出而非設計過的尺度，歸納為 4 階：
///
/// | 階 | 值 | 吸收的 artboard 原始值 | 觀察到的用途 |
/// |----|----|------------------------|--------------|
/// | [AppFontSize.caption] | 10 | 9、10 | 輔助說明、次要標籤 |
/// | [AppFontSize.body] | 12 | 11、12、13 | 內文、清單項（實測最大宗） |
/// | [AppFontSize.subtitle] | 14 | 14、15 | 小標題、強調文字 |
/// | [AppFontSize.title] | 19 | 19（僅 1 次，未歸併） | 頁面標題 |
library;

/// 字級離散尺度。畫面只引用具名階，不接受任意數字。
abstract final class AppFontSize {
  static const double caption = 10; // magic-exempt token 定義本身
  static const double body = 12; // magic-exempt token 定義本身
  static const double subtitle = 14; // magic-exempt token 定義本身
  static const double title = 19; // magic-exempt token 定義本身
}
