/// 語意圖示（SPEC-004 §4.2）。
///
/// 純顯示原子元件，無變體、無狀態集、無互動。尺寸只取具名階
/// （[IconSize.sm] / [IconSize.md] / [IconSize.lg]），不接受任意數值。
///
/// **可點需求由所屬元件承載**（例如 `AppButton.text` 的 leading icon）；
/// 本元件本身不處理點擊。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// [AppIcon] 的尺寸階，對應 [LayoutSize.iconSm] / [iconMd] / [iconLg]。
enum IconSize {
  /// [LayoutSize.iconSm]。
  sm(LayoutSize.iconSm),

  /// [LayoutSize.iconMd]，預設值。
  md(LayoutSize.iconMd),

  /// [LayoutSize.iconLg]。
  lg(LayoutSize.iconLg);

  const IconSize(this.logicalSize);

  /// 對應的 [LayoutSize] 邏輯像素值。
  final double logicalSize;
}

/// 語意圖示元件（SPEC-004 §4.2）。
///
/// | slot | 說明 |
/// |------|------|
/// | [icon] | 必填，圖示資料 |
/// | [size] | 尺寸階，預設 [IconSize.md] |
/// | [color] | 顏色，預設 [AppColors.textPrimary] |
/// | [semanticLabel] | 朗讀標籤；`null` 時排除於語意樹（裝飾性） |
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.icon,
    this.size = IconSize.md,
    this.color = AppColors.textPrimary,
    this.semanticLabel,
  });

  /// 圖示資料（Material Icons，沿用 `lib/app/shell.dart` 既有慣例）。
  final IconData icon;

  /// 尺寸階，預設 [IconSize.md]。
  final IconSize size;

  /// 顏色，限 [AppColors] 語意層 token。
  final Color color;

  /// 朗讀標籤；`null` 時本元件為裝飾性，排除於語意樹（SPEC-004 §4.2 無障礙）。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: size.logicalSize, color: color);
    if (semanticLabel == null) {
      return ExcludeSemantics(child: glyph);
    }
    return Semantics(label: semanticLabel, image: true, child: glyph);
  }
}
