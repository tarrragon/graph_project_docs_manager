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

/// 文字語意色（SPEC-004 §4.1「修飾參數」語意色軸）。
///
/// 值限 [AppColors] 語意色名，不接受任意 [Color]——呼叫端無法傳入畫布外
/// 顏色，維持 SPEC-002「畫面只引用語意層與元件層」的邊界。
enum AppTextTone {
  /// [AppColors.textPrimary]。
  textPrimary,

  /// [AppColors.textSecondary]。
  textSecondary,

  /// [AppColors.textTitle]。
  textTitle,

  /// [AppColors.accentStrong]。
  accentStrong,

  /// [AppColors.textDisabled]。
  textDisabled,
}

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
    this.tone,
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

  /// 顏色改 `AppColors.textSecondary`（非變體）。忽略：[tone] 已傳入時
  /// （見「修飾參數優先序」）。
  final bool secondary;

  /// 語意色軸（非變體）；傳入時覆蓋 [secondary] 與變體預設色，[emphasis]
  /// 仍獨立生效（字重與顏色為正交修飾）。優先序：[tone] > [secondary] >
  /// 變體預設色。
  final AppTextTone? tone;

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
    final baseColor = _resolveColor();
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

  /// 依「修飾參數優先序」解析最終顏色：[tone] > [secondary] > 變體預設色。
  Color _resolveColor() {
    if (tone != null) return _colorForTone(tone!);
    if (secondary) return AppColors.textSecondary;
    return _defaultColor;
  }

  Color _colorForTone(AppTextTone tone) => switch (tone) {
        AppTextTone.textPrimary => AppColors.textPrimary,
        AppTextTone.textSecondary => AppColors.textSecondary,
        AppTextTone.textTitle => AppColors.textTitle,
        AppTextTone.accentStrong => AppColors.accentStrong,
        AppTextTone.textDisabled => AppColors.textDisabled,
      };

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
