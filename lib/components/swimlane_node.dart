/// 泳道格內的動作標籤元件（SPEC-004 §4.16）。
///
/// 0.1 不可點、不可拖：`drag` 互動由所在 `SwimlaneGrid` 的捲動容器承接
/// （SPEC-003 §1.3），本元件本身無 `GestureDetector` / `InkWell`。`active` /
/// `inactive` 為變體（不隨互動改變），非狀態（SPEC-004 §4.16 狀態矩陣）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 泳道節點：作用中／非作用中兩變體。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [label] | 是 | 呼叫端傳入的資料值（步驟名） |
/// | [isActive] | 是 | 對映 `active` / `inactive` 變體 |
class SwimlaneNode extends StatelessWidget {
  const SwimlaneNode({super.key, required this.label, required this.isActive});

  /// 標籤文字（不換行、超出截斷，SPEC-004 §4.16 內容政策）。
  final String label;

  /// `true` 對映 `active` 變體（底 [AppColors.accent]），`false` 對映
  /// `inactive` 變體（底 [AppColors.surfaceChip]）。
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticLabel =
        '$label，${isActive ? l10n.laneNodeActive : l10n.laneNodeInactive}';

    return Semantics(
      label: semanticLabel,
      button: false,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: LayoutSize.laneRowHeight.h - 2 * Space.xs.h,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: Space.sm.w,
          vertical: Space.xs.h,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surfaceChip,
          borderRadius: BorderRadius.circular(Radius.md.r),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppFontSize.body.sp,
            color: isActive ? AppColors.surfaceBase : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
