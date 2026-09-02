/// 徽章列容器（SPEC-004 §4.33、§5.7）。
///
/// 水平排列 [Badge] × N，空間不足時換行（[Wrap]）。`legend` 變體加頂邊框
/// 與頂部內距，供面板底部圖例列使用；外觀差異外行為相同（§4.33「變體」
/// 表：`legend` 間距同 `default`，§3.7 第 12 項）。容器與子件皆無互動，
/// 不進入 Tab 順序、無自身狀態集（§4.33「狀態矩陣」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';
import 'badge.dart';

/// [BadgeRow] 的兩個變體（SPEC-004 §4.33「變體」）。
enum BadgeRowVariant {
  /// 無邊框：標籤列、事件標籤。
  default_,

  /// 頂邊框 + 頂部內距：面板底部圖例列。
  legend,
}

/// [Badge] × N 的換行容器（SPEC-004 §4.33）。
///
/// 子件水平以 [Space.xs] 為最小間距排列，可用寬不足時換行，列間同樣
/// 以 [Space.xs] 分隔（§5.7「最小間距」）；子件為 0 個時不渲染任何內容
/// （§4.33「slot 契約」）。子件對齊：`start`、每列垂直置中（§4.33「組合
/// 規則」）。
class BadgeRow extends StatelessWidget {
  const BadgeRow({
    super.key,
    required this.children,
    this.variant = BadgeRowVariant.default_,
  });

  /// 子件（`Badge` 全變體），0..無上限（§5.7「子件契約」）。
  final List<Badge> children;

  /// 外觀變體，預設 [BadgeRowVariant.default_]。
  final BadgeRowVariant variant;

  @override
  Widget build(BuildContext context) {
    final wrap = Wrap(
      spacing: Space.xs.w,
      runSpacing: Space.xs.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );

    if (variant == BadgeRowVariant.default_) {
      return wrap;
    }

    return Container(
      padding: EdgeInsets.only(top: Space.sm.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: wrap,
    );
  }
}
