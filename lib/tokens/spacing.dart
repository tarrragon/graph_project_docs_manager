/// 間距與圓角 token（SPEC-002 FR-04）。
///
/// artboard 實測的 padding／gap 原始值遠多於 SPEC-002 文件表列的七種
/// （實測涵蓋 1、2、3、4、5、6、7、8、9、10、12、14、16、18、20 共 15 種，
/// 非文件所載的 1／2／7／8／9／10／12）。這些原始值是產生器輸出而非
/// 設計過的尺度，故不逐一收錄，改歸納為 6 階離散尺度，將鄰近值吸收進
/// 最接近的階，噪音不進入規格。
///
/// | 階 | 值 | 吸收的 artboard 原始值 |
/// |----|----|------------------------|
/// | [Space.xxs] | 2 | 1、2、3 |
/// | [Space.xs] | 4 | 4、5、6 |
/// | [Space.sm] | 8 | 7、8、9、10（實測最大宗，橫跨此區間） |
/// | [Space.md] | 12 | 12、14 |
/// | [Space.lg] | 16 | 16、18 |
/// | [Space.xl] | 20 | 20 |
///
/// 圓角實測值為 4、5、6、7、8、9、11、12（SPEC-002 文件載 5／7／8，
/// 同樣有遺漏），歸納為 3 階：
///
/// | 階 | 值 | 吸收的 artboard 原始值 |
/// |----|----|------------------------|
/// | [Radius.sm] | 6 | 4、5、6 |
/// | [Radius.md] | 8 | 7、8、9 |
/// | [Radius.lg] | 12 | 11、12 |
library;

/// 間距離散尺度。畫面只引用具名階，不接受任意數字。
abstract final class Space {
  static const double xxs = 2; // magic-exempt token 定義本身
  static const double xs = 4; // magic-exempt token 定義本身
  static const double sm = 8; // magic-exempt token 定義本身
  static const double md = 12; // magic-exempt token 定義本身
  static const double lg = 16; // magic-exempt token 定義本身
  static const double xl = 20; // magic-exempt token 定義本身
}

/// 圓角離散尺度。畫面只引用具名階，不接受任意數字。
abstract final class Radius {
  static const double sm = 6; // magic-exempt token 定義本身
  static const double md = 8; // magic-exempt token 定義本身
  static const double lg = 12; // magic-exempt token 定義本身
}
