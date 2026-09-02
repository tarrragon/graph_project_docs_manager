/// domain × UC 交叉格的關係符號元件（SPEC-004 §4.15）。
///
/// 三變體（`direct` / `indirect` / `none`）以符號 ● ○ · 承載，皆可點選
/// （SPEC-001 §1「無關格亦可選」）；無 disabled 態——同形的格不得一部分
/// 可點一部分不可點（SPEC-004 §4.15）。所在列是否高亮（`isRowSelected`）
/// 與本格是否為當前選格（`isSelected`）皆由 `MatrixGrid` 傳入，本元件不
/// 自行判斷選取邏輯。
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';

/// domain × UC 的關係種類（SPEC-004 §4.15「變體」）。
enum Relation {
  /// 符號 ●，[AppColors.accent]。直接貫穿。
  direct,

  /// 符號 ○，[AppColors.textSecondary]。間接依賴。
  indirect,

  /// 符號 ·，[AppColors.borderStrong]。無關（刻意弱化，SPEC-004 §4.0.2 表 2）。
  none,
}

extension on Relation {
  String get symbol => switch (this) {
    Relation.direct => '●',
    Relation.indirect => '○',
    Relation.none => '·',
  };

  Color get symbolColor => switch (this) {
    Relation.direct => AppColors.accent,
    Relation.indirect => AppColors.textSecondary,
    Relation.none => AppColors.borderStrong,
  };
}

/// domain × UC 交叉格（SPEC-004 §4.15）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [relation] | 是 | 對映三變體 |
/// | [isSelected] | 是 | 本格是否為當前選格（`selected` 態） |
/// | [isRowSelected] | 是 | 所在列是否高亮（`rowSelected` 態，由 `MatrixGrid` 判斷） |
/// | [semanticLabel] | 是 | 呼叫端取 `matrixCellA11yLabel` 組字 |
/// | [onTap] | 是 | 點選回呼；`isSelected` 為 `true` 時不呼叫（已選格再點無狀態改變） |
/// | [testKey] | 是 | `cell-domain-<rowId>-<colId>` |
class MatrixCell extends StatefulWidget {
  const MatrixCell({
    super.key,
    required this.relation,
    required this.isSelected,
    required this.isRowSelected,
    required this.semanticLabel,
    required this.onTap,
    required this.testKey,
  });

  /// 關係種類（SPEC-004 §4.15「變體」），決定符號與其未選色。
  final Relation relation;

  /// 是否為當前選格（`selected` 態）。
  final bool isSelected;

  /// 所在列是否高亮（`rowSelected` 態）。
  final bool isRowSelected;

  /// 朗讀標籤，呼叫端取 `matrixCellA11yLabel` 值。
  final String semanticLabel;

  /// 點選回呼；[isSelected] 為 `true` 時不呼叫（SPEC-004 §4.15「互動反應」）。
  final VoidCallback onTap;

  /// 測試錨點（`cell-domain-<rowId>-<colId>`）。
  final Key testKey;

  @override
  State<MatrixCell> createState() => _MatrixCellState();
}

class _MatrixCellState extends State<MatrixCell> {
  bool _focused = false;

  void _onFocusChange(bool focused) => setState(() => _focused = focused);

  Color get _background {
    if (widget.isSelected) return AppColors.accent;
    if (widget.isRowSelected) return AppColors.surfaceIconTint;
    return Colors.transparent; // color-exempt default 態透明底
  }

  Color get _symbolColor =>
      widget.isSelected ? AppColors.surfaceBase : widget.relation.symbolColor;

  @override
  Widget build(BuildContext context) {
    final cellBody = Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.all(Space.xs.w),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(Radius.sm.r),
      ),
      child: Text(
        widget.relation.symbol,
        style: TextStyle(fontSize: AppFontSize.subtitle.sp, color: _symbolColor),
      ),
    );

    final inkCell = InkWell(
      onTap: widget.isSelected ? null : widget.onTap,
      onFocusChange: _onFocusChange,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: LayoutSize.hitTargetMin,
          minHeight: LayoutSize.rowHeightRelaxed,
          maxHeight: LayoutSize.rowHeightRelaxed,
        ),
        child: cellBody,
      ),
    );

    // focused：祖先鏈存在 decoration 非 null 的 DecoratedBox（SPEC-003
    // §2.10；SPEC-004 §4.0.1）。
    final decoratedCell = DecoratedBox(
      decoration: BoxDecoration(
        border: _focused
            ? Border.all(color: AppColors.accent)
            : Border.all(
                color: Colors.transparent, // color-exempt 未聚焦時不可見邊框佔位
              ),
      ),
      child: inkCell,
    );

    return Semantics(
      key: widget.testKey,
      button: true,
      selected: widget.isSelected,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: decoratedCell,
    );
  }
}
