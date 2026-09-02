/// `AppText`：所有可見文字的唯一載體（SPEC-004 §4.1）。
///
/// 依字級 token 與語意角色渲染，每個變體恰一個文字 slot。內容政策（可否
/// 換行、超出處置）由變體決定，呼叫端不得傳入比 §4.1「內容政策」更寬鬆的
/// 處置——`softWrap` / `overflow` 不開放為建構子參數，`body` 只開放
/// `maxLines`。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';

/// 文字語意角色（SPEC-004 §4.1「變體」）。
enum AppTextVariant {
  /// 頁面標題、節點詳情主標。單行、`AppFontSize.title`、粗體。
  title,

  /// 面板標題、格詳情卡標題、泳道面板標題。單行、`AppFontSize.subtitle`、半粗。
  subtitle,

  /// 說明、內文、列主文字。可多行（`maxLines` 由呼叫端傳入）。
  body,

  /// 副標、欄首、小計、群組小標、次文字。單行、`AppFontSize.caption`。
  caption,

  /// ID、路徑、版本值。單行、等寬字型。
  mono,
}

/// 所有可見文字的唯一載體。
///
/// 用途、變體選用時機、反例見 SPEC-004 §4.1。文字內容一律由呼叫端傳入
/// （i18n key 取值或資料文字），本元件無自有 i18n key。
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.maxLines,
    this.emphasis = false,
    this.secondary = false,
    this.textAlign,
  });

  /// 顯示文字，唸出全文（截斷不影響朗讀）。
  final String text;

  /// 語意角色，決定字級、顏色、單行或多行。
  final AppTextVariant variant;

  /// 僅 [AppTextVariant.body] 生效：限制最大行數，超出末行截斷；
  /// 不傳則無上限。其餘變體固定單行，此參數被忽略。
  final int? maxLines;

  /// 粗體修飾（非變體）。
  final bool emphasis;

  /// 顏色改 `AppColors.textSecondary`（非變體）。
  final bool secondary;

  /// 格位內的水平對齊；不影響換行或截斷處置。
  final TextAlign? textAlign;

  bool get _isSingleLine => variant != AppTextVariant.body;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);
    final isHeader =
        variant == AppTextVariant.title || variant == AppTextVariant.subtitle;

    return Semantics(
      header: isHeader,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        softWrap: !_isSingleLine,
        maxLines: _isSingleLine ? 1 : maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  TextStyle _resolveStyle(BuildContext context) {
    final baseColor = secondary ? AppColors.textSecondary : _defaultColor;
    final baseWeight = emphasis ? FontWeight.bold : _defaultWeight;

    return TextStyle(
      fontSize: _fontSize.sp,
      color: baseColor,
      fontWeight: baseWeight,
      fontFamily: variant == AppTextVariant.mono
          ? DefaultTextStyle.of(context).style.fontFamily
          : null,
    );
  }

  double get _fontSize => switch (variant) {
        AppTextVariant.title => AppFontSize.title,
        AppTextVariant.subtitle => AppFontSize.subtitle,
        AppTextVariant.body => AppFontSize.body,
        AppTextVariant.caption => AppFontSize.caption,
        AppTextVariant.mono => AppFontSize.body,
      };

  Color get _defaultColor => switch (variant) {
        AppTextVariant.title => AppColors.textTitle,
        AppTextVariant.subtitle => AppColors.textTitle,
        AppTextVariant.body => AppColors.textPrimary,
        AppTextVariant.caption => AppColors.textSecondary,
        AppTextVariant.mono => AppColors.textPrimary,
      };

  FontWeight get _defaultWeight => switch (variant) {
        AppTextVariant.title => FontWeight.bold,
        AppTextVariant.subtitle => FontWeight.w600,
        AppTextVariant.body => FontWeight.normal,
        AppTextVariant.caption => FontWeight.normal,
        AppTextVariant.mono => FontWeight.normal,
      };
}
