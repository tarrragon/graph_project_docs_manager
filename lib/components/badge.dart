/// 非互動標籤／數值標記元件（SPEC-004 §4.5）。
///
/// 八個語意變體（[BadgeVariant]）：`count` / `status` / `type` / `category` /
/// `event` / `tag` / `legend` / `health`。外觀（chip 底或 inline 純文字）
/// 由呼叫端依所在容器格位決定（SPEC-004 §3.7 第 5 項），不是第二個變體軸，
/// 故以 [Badge.inline] 布林參數表達，非列舉值。
///
/// `status` 變體的 tone 由 [Badge.status] 依 [_statusToneMap] 自動對映，
/// 呼叫端不可覆寫（SPEC-004 §4.5「對映表為元件常數」）；`category` 變體
/// 的 tone 必填由呼叫端指定；其餘變體有固定或預設 tone。
///
/// `secondary` tone（底 `surfaceChip`、字 `textSecondary`）對比 4.02:1
/// 未達 WCAG AA，已依 SPEC-004 v1.9（2026-09-02）刪除；`rejected` /
/// `superseded` / `revised` 改對映 [BadgeTone.neutral]（§4.0.2 帶色表面
/// 規則：`textPrimary` 後與 `neutral` 無差異）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';

/// 八個語意變體（SPEC-004 §4.5「變體」表）。
enum BadgeVariant {
  /// 損壞計數（`IssueMarker.damagedDetail` 內部 slot）。
  count,

  /// 票列狀態、節點 draft chip、樹列狀態。
  status,

  /// PROP / SPEC / UC / Ticket 型別。
  type,

  /// 破洞類別，tone 由呼叫端指定。
  category,

  /// 事件標籤（`emits X` / `consumes X`）。
  event,

  /// 標籤（`domain: schema`、`N 個 FR`）。
  tag,

  /// 矩陣與泳道圖例（符號 + 文字，無底色）。
  legend,

  /// 專案健康計數（`badge-switcher-health-<index>`）。
  health,
}

/// 語意色參數（非變體軸，SPEC-004 §4.5）。
enum BadgeTone {
  /// 底 `surfaceChip`、字 `textPrimary`。
  neutral,

  /// 底 `surfaceIconTint`、字 `accentStrong`。
  accent,

  /// 底 `surfaceChip`、字 `success`。
  positive,

  /// 底 `warningSurface`、字 `warning`。
  warning,

  /// 底 `errorSurface`、字 `error`。
  negative,
}

/// `status` 值到 [BadgeTone] 的固定對映（SPEC-004 §4.5，元件常數）。
const Map<String, BadgeTone> _statusToneMap = {
  'completed': BadgeTone.positive,
  'confirmed': BadgeTone.positive,
  'approved': BadgeTone.positive,
  'implemented': BadgeTone.positive,
  'baseline': BadgeTone.positive,
  'draft': BadgeTone.warning,
  'pending': BadgeTone.warning,
  'review': BadgeTone.warning,
  'in_progress': BadgeTone.warning,
  'rejected': BadgeTone.neutral,
  'superseded': BadgeTone.neutral,
  'revised': BadgeTone.neutral,
};

/// tone 決定的底色與字色（chip / inline 共用計算，形態差異在渲染層）。
class _ToneColors {
  const _ToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const Map<BadgeTone, _ToneColors> _toneColors = {
  BadgeTone.neutral: _ToneColors(AppColors.surfaceChip, AppColors.textPrimary),
  BadgeTone.accent: _ToneColors(
    AppColors.surfaceIconTint,
    AppColors.accentStrong,
  ),
  BadgeTone.positive: _ToneColors(AppColors.surfaceChip, AppColors.success),
  BadgeTone.warning: _ToneColors(AppColors.warningSurface, AppColors.warning),
  BadgeTone.negative: _ToneColors(AppColors.errorSurface, AppColors.error),
};

/// legend 符號到符號色的固定對映（SPEC-004 §4.5「使用 design token」，
/// 依表列順序 accent / textSecondary / borderStrong 對應三個符號）。
const Map<String, Color> _legendSymbolColors = {
  '●': AppColors.accentStrong,
  '○': AppColors.textSecondary,
  '·': AppColors.borderStrong,
};

/// 非互動的標籤／數值標記（SPEC-004 §4.5）。
///
/// 點擊無反應、不進入 Tab 順序（`Semantics.button` 為 `false`）。文字
/// slot 一律不換行、超出以省略號截斷（`count` 例外，數字固有寬不截斷）。
class Badge extends StatelessWidget {
  const Badge._({
    super.key,
    required this.variant,
    this.tone,
    this.label,
    this.count,
    this.symbol,
    this.semanticLabel,
    this.inline = false,
  });

  /// 損壞計數。`tone` 預設 [BadgeTone.negative]，呼叫端可覆寫。
  const Badge.count({
    Key? key,
    required int count,
    BadgeTone tone = BadgeTone.negative,
    String? semanticLabel,
    bool inline = false,
  }) : this._(
         key: key,
         variant: BadgeVariant.count,
         count: count,
         tone: tone,
         semanticLabel: semanticLabel,
         inline: inline,
       );

  /// 票列狀態、節點 draft chip、樹列狀態。`tone` 由 [label] 值依
  /// [_statusToneMap] 自動決定，呼叫端不可覆寫（SPEC-004 §4.5）。
  const Badge.status({
    Key? key,
    required String label,
    bool inline = false,
  }) : this._(
         key: key,
         variant: BadgeVariant.status,
         label: label,
         inline: inline,
       );

  /// PROP / SPEC / UC / Ticket 型別，tone 固定 [BadgeTone.neutral]。
  const Badge.type({Key? key, required String label, bool inline = false})
    : this._(
        key: key,
        variant: BadgeVariant.type,
        label: label,
        inline: inline,
      );

  /// 破洞類別，`tone` 由呼叫端指定（SPEC-004 §4.5「category 必填」）。
  const Badge.category({
    Key? key,
    required String label,
    required BadgeTone tone,
    bool inline = false,
  }) : this._(
         key: key,
         variant: BadgeVariant.category,
         label: label,
         tone: tone,
         inline: inline,
       );

  /// 事件標籤，`tone` 預設 [BadgeTone.accent]，呼叫端可改
  /// [BadgeTone.negative]。
  const Badge.event({
    Key? key,
    required String label,
    BadgeTone tone = BadgeTone.accent,
    bool inline = false,
  }) : this._(
         key: key,
         variant: BadgeVariant.event,
         label: label,
         tone: tone,
         inline: inline,
       );

  /// `domain: schema`、`N 個 FR` 等標籤，tone 固定 [BadgeTone.neutral]。
  const Badge.tag({Key? key, required String label, bool inline = false})
    : this._(
        key: key,
        variant: BadgeVariant.tag,
        label: label,
        inline: inline,
      );

  /// 矩陣與泳道圖例：符號 slot（`●` / `○` / `·`）+ 文字，無底色。
  const Badge.legend({
    Key? key,
    required String symbol,
    required String label,
  }) : this._(
         key: key,
         variant: BadgeVariant.legend,
         symbol: symbol,
         label: label,
       );

  /// 專案健康計數。`semanticLabel` 與 `key`（`badge-switcher-health-<index>`）
  /// 皆必填（SPEC-004 §4.5「slot 契約」）。
  const Badge.health({
    required Key key,
    required int count,
    required String semanticLabel,
    bool inline = false,
  }) : this._(
         key: key,
         variant: BadgeVariant.health,
         count: count,
         tone: BadgeTone.negative,
         semanticLabel: semanticLabel,
         inline: inline,
       );

  /// 語意變體。
  final BadgeVariant variant;

  /// 語意色（`status` 由元件常數決定，本欄位對 `status` 不生效）。
  final BadgeTone? tone;

  /// 文字內容（數值變體不使用）。
  final String? label;

  /// 數值內容（`count` / `health` 使用）。
  final int? count;

  /// legend 符號（`●` / `○` / `·`）。
  final String? symbol;

  /// 朗讀用文字（`count` / `health` 使用）。
  final String? semanticLabel;

  /// 外觀由容器格位決定：`true` 為 inline（無底色、只取 tone 字色），
  /// `false`（預設）為 chip（底色 + `Radius.sm`）。
  final bool inline;

  BadgeTone get _resolvedTone {
    if (variant == BadgeVariant.status) {
      return _statusToneMap[label] ?? BadgeTone.neutral;
    }
    return tone ?? BadgeTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = variant == BadgeVariant.legend
        ? _buildLegend()
        : _buildLabelOrCount();

    return Semantics(
      label: _resolvedSemanticLabel,
      button: false,
      excludeSemantics: true,
      child: content,
    );
  }

  String get _resolvedSemanticLabel {
    if (variant == BadgeVariant.count || variant == BadgeVariant.health) {
      return semanticLabel ?? '$count';
    }
    return label ?? '';
  }

  Widget _buildLabelOrCount() {
    final colors = _toneColors[_resolvedTone]!;
    final isNumeric =
        variant == BadgeVariant.count || variant == BadgeVariant.health;
    final text = isNumeric ? '$count' : (label ?? '');
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.caption.sp,
        fontWeight: FontWeight.w600,
        color: colors.foreground,
      ),
    );
    if (inline) {
      return textWidget;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Space.sm.w,
        vertical: Space.xxs.h,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(Radius.sm.r),
      ),
      child: textWidget,
    );
  }

  Widget _buildLegend() {
    final symbolColor =
        _legendSymbolColors[symbol] ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol ?? '',
          style: TextStyle(fontSize: AppFontSize.caption.sp, color: symbolColor),
        ),
        SizedBox(width: Space.xs.w),
        Flexible(
          child: Text(
            label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSize.caption.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
