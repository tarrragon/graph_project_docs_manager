/// 工具列容器（SPEC-004 4.32、5.6）。
///
/// [SearchField]（填滿剩餘寬）+ 1..3 個篩選下拉 + 可選
/// [IssueMarker.damagedDetail] 水平排列，底邊框 `AppColors.borderStrong`。
/// 容器自身無自有狀態、無自有互動（SPEC-004 4.32「狀態矩陣」「互動反應」，
/// 皆由子件承載），子件垂直置中對齊。
///
/// | slot | 型別 | 必填 | 說明 |
/// |------|------|------|------|
/// | [search] | [SearchField] | 是（恰 1，首格） | 吸收剩餘寬（SPEC-004 5.6「不重疊」） |
/// | [filters] | `List<Widget>` | 是（1..3） | 契約型別為 `FilterDropdown`；該元件尚未建立前，slot 以 [Widget] 承接（AppButton 慣例） |
/// | [marker] | [IssueMarker]? | 否 | 含損壞疊加態時傳入，恆置末格靠右 |
/// | [testKey] | [Key] | 是 | 呼叫端定址 key |
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';
import 'issue_marker.dart';
import 'search_field.dart';

/// SPEC-004 §4.32 容器：`SearchField` + `FilterDropdown` × N +
/// `IssueMarker.damagedDetail`? 水平排列。
///
/// 不重疊：單列水平互斥，[search] 吸收剩餘寬；最小間距水平皆 [Space.sm]，
/// 呼叫端不得覆寫；空間不足策略不觸發（SPEC-004 5.6：子件上限 5，
/// `SearchField` 最小寬 + Σ `FilterDropdown` 固有寬 + `IssueMarker` 寬 +
/// 4 × `Space.sm` 恆 <= `Panel` 內寬）。
class Toolbar extends StatelessWidget {
  Toolbar({
    super.key,
    required this.search,
    required this.filters,
    required this.testKey,
    this.marker,
  }) : assert(
         filters.isNotEmpty && filters.length <= 3,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'Toolbar filters 數量須介於 1..3（SPEC-004 5.6 子件契約）',
       );

  /// 首格：搜尋框，吸收剩餘寬。
  final SearchField search;

  /// 第 2..N 格：篩選下拉（1..3 個）。契約型別為 `FilterDropdown`；
  /// 該元件尚未建立前以 [Widget] 承接。
  final List<Widget> filters;

  /// 末格：損壞計數標記，含損壞疊加態時傳入（SPEC-004 5.6 slot 契約）。
  final IssueMarker? marker;

  /// 呼叫端定址 key（SPEC-004 4.32 slot 契約）。
  final Key testKey;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[Expanded(child: search)];
    for (final filter in filters) {
      children
        ..add(SizedBox(width: Space.sm.w))
        ..add(filter);
    }
    final trailingMarker = marker;
    if (trailingMarker != null) {
      children
        ..add(SizedBox(width: Space.sm.w))
        ..add(trailingMarker);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Space.sm.h),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          key: testKey,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderStrong)),
          ),
          child: SizedBox(
            height: (LayoutSize.hitTargetMin + 2 * Space.xs).h,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Space.xs.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
