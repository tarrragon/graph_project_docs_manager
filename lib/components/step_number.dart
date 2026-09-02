/// 步驟序號元件（SPEC-004 §4.17）。
///
/// 純顯示的圓形序號，用於步驟列與格詳情卡步驟清單（§3.7 第 11 項核定
/// 統一圓形，直徑 [LayoutSize.stepNumberSize]）。單一變體、無互動、無
/// 狀態集——所在列的點擊由 `TableRow.step` / `ListRow.numbered` 承載
/// （SPEC-004 §4.17「互動反應」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 圓形步驟序號（SPEC-004 §4.17）。
///
/// [number] 自 1 起；三位數以上（`>= 1000`）改用 [AppFontSize.caption]
/// 以下再縮一階渲染，避免直徑固定下溢位（§4.17「內容政策」提案）。
class StepNumber extends StatelessWidget {
  const StepNumber({super.key, required this.number});

  /// 步驟序號，自 1 起。
  final int number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diameter = LayoutSize.stepNumberSize.r;
    final text = '$number';
    final isOverThreeDigits = number >= 1000;

    return Semantics(
      label: l10n.stepNumberA11yLabel(number),
      excludeSemantics: true,
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surfaceIconTint,
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize:
                (isOverThreeDigits
                        ? AppFontSize.caption - 2
                        : AppFontSize.caption)
                    .sp,
            fontWeight: FontWeight.w600,
            color: AppColors.accentStrong,
          ),
        ),
      ),
    );
  }
}
