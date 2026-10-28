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

  /// 說明、內文、列主文字。行數政策由呼叫端明示：[AppText.multiLine]
  /// （`maxLines` 必填）或 [AppText.singleLine]。
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
  /// 明示單行：恆一行、超出以省略號截斷（任一變體，預設 `body`）。
  ///
  /// 截斷責任由呼叫端以本建構子明示承擔（SPEC-004 §4.1／§4.40）。
  const AppText.singleLine(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.emphasis = false,
    this.secondary = false,
    this.tone,
    this.textAlign,
  })  : maxLines = 1,
        _forceSingleLine = true,
        _explicitWrap = false;

  /// 明示多行：`body` 變體，`maxLines` 必填——`null` 為無上限（真的換行），
  /// 整數為限行、超出末行省略號。漏傳在編譯期暴露。
  const AppText.multiLine(
    this.text, {
    super.key,
    required this.maxLines,
    this.emphasis = false,
    this.secondary = false,
    this.tone,
    this.textAlign,
  })  : variant = AppTextVariant.body,
        _forceSingleLine = false,
        _explicitWrap = true;

  const AppText._(
    this.text, {
    required this.variant,
    required this.maxLines,
    required this._forceSingleLine,
    required this._explicitWrap,
    required this.emphasis,
    required this.secondary,
    required this.tone,
    required this.textAlign,
  });

  final bool _forceSingleLine;

  /// 僅 [AppText.multiLine] 為真：明示換行，無上限時 overflow 用 clip。
  final bool _explicitWrap;

  /// 顯示文字，唸出全文（截斷不影響朗讀）。
  final String text;

  /// 語意角色，決定字級、顏色、單行或多行。
  final AppTextVariant variant;

  /// 僅 [AppTextVariant.body] 生效：限制最大行數，超出末行截斷；`null`
  /// 為無上限。其餘變體固定單行，此參數被忽略。
  ///
  /// 行數政策一律由 [AppText.singleLine] 或 [AppText.multiLine] 明示。
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

  /// 只改修飾（粗體、語意色），保留文字、變體與行數政策。容器需重染主文字
  /// 時用此法，避免重建而丟失呼叫端明示的行數政策。
  AppText copyWithModifiers({bool? emphasis, AppTextTone? tone}) =>
      AppText._(
        text,
        variant: variant,
        maxLines: maxLines,
        forceSingleLine: _forceSingleLine,
        explicitWrap: _explicitWrap,
        emphasis: emphasis ?? this.emphasis,
        secondary: secondary,
        tone: tone ?? this.tone,
        textAlign: textAlign,
      );

  bool get _isSingleLine => _forceSingleLine || variant != AppTextVariant.body;

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
        // 無行數上限時 ellipsis 會被引擎當成單行截斷（508 根因），故明示
        // 換行（multiLine）且無上限時用 clip。
        overflow: _explicitWrap && maxLines == null
            ? TextOverflow.clip
            : TextOverflow.ellipsis,
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
