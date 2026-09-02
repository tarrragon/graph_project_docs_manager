/// SplitRow（SPEC-004 §4.29、§5.3）：左右兩端對齊的水平列容器。
///
/// 兩個變體：[SplitRow.header]（固定高 [LayoutSize.headerHeight]、底邊框、
/// `surfaceBase` 底）、[SplitRow.footer]（固定高 [LayoutSize.rowHeightRelaxed]、
/// 頂邊框）。leading 填滿剩餘寬並截斷，trailing 固有寬，兩者間最小間距
/// [Space.md]（§5.3 排列不變式，呼叫端不得覆寫）。
///
/// `compactHeader` 修飾參數：詳情卡內的 `header` 變體不套固定高與邊框
/// （SPEC-004 §4.29「變體」表 `header` 列）。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// [SplitRow] 的兩種變體（SPEC-004 §4.29「變體」）。
enum SplitRowVariant {
  /// 頁首、詳情卡標題列：高 [LayoutSize.headerHeight]、底邊框、`surfaceBase` 底。
  header,

  /// Ticket 清單摘要底列：高 [LayoutSize.rowHeightRelaxed]、頂邊框。
  footer,
}

/// 左右兩端對齊的水平列容器（SPEC-004 §4.29、§5.3）。
///
/// leading（恰 1，必填）填滿剩餘寬並截斷；trailing（0..1，選填）固有寬。
/// 容器自身無互動、無語意狀態集（§4.29 狀態矩陣）。
class SplitRow extends StatelessWidget {
  /// 頁首、詳情卡標題列變體。
  ///
  /// [compactHeader] 為 `true` 時不套固定高與底邊框／底色（詳情卡內用途，
  /// §4.29「變體」表 `header` 列 `compactHeader` 修飾參數）。
  const SplitRow.header({
    super.key,
    required this.leading,
    this.trailing,
    this.compactHeader = false,
  }) : variant = SplitRowVariant.header;

  /// Ticket 清單摘要底列變體。
  const SplitRow.footer({super.key, required this.leading, this.trailing})
    : variant = SplitRowVariant.footer,
      compactHeader = false;

  /// 左格：`PageTitle` | `AppText`（`body` / `subtitle`）。填滿剩餘寬並截斷。
  final Widget leading;

  /// 右格：`SegmentedControl` | `ButtonRow` | `AppText.caption` |
  /// `AppButton.text` | 空。固有寬，不縮放。
  final Widget? trailing;

  /// 變體（[SplitRowVariant.header] / [SplitRowVariant.footer]）。
  final SplitRowVariant variant;

  /// `header` 變體專用：`true` 時不套固定高與底邊框／底色（詳情卡內）。
  final bool compactHeader;

  double? get _fixedHeight {
    if (variant == SplitRowVariant.header && !compactHeader) {
      return LayoutSize.headerHeight;
    }
    if (variant == SplitRowVariant.footer) {
      return LayoutSize.rowHeightRelaxed;
    }
    return null;
  }

  Border? get _border {
    if (variant == SplitRowVariant.header && !compactHeader) {
      return const Border(bottom: BorderSide(color: AppColors.border));
    }
    if (variant == SplitRowVariant.footer) {
      return const Border(top: BorderSide(color: AppColors.border));
    }
    return null;
  }

  Color? get _background {
    if (variant == SplitRowVariant.header && !compactHeader) {
      return AppColors.surfaceBase;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: leading),
        if (trailing != null) ...[SizedBox(width: Space.md), trailing!],
      ],
    );

    final height = _fixedHeight;
    final content = height == null
        ? row
        : SizedBox(height: height, child: row);

    final border = _border;
    final background = _background;
    if (border == null && background == null) {
      return content;
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: background, border: border),
      child: content,
    );
  }
}
