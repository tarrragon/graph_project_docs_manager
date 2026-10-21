/// 設計覆寫接縫（僅供測試與研究入口使用）。
///
/// 466 變體研究需要「真正改了設計」的壞版本。本接縫以單一
/// [InheritedWidget] 提供三類覆寫點，範圍以 466 變體目錄為限：
///
/// | 類 | 覆寫點 | 對應元件 |
/// |----|--------|---------|
/// | A 主次操作視覺權重 | [DesignOverrides.buttonColors] | `AppButton` |
/// | B 相關元件鄰近分組 | [DesignOverrides.sectionItemGap] | `Section` |
/// | C' 相似元件外觀區分 | [DesignOverrides.issueMarkerColor] | `IssueMarker` |
/// | 樹縮排 | [DesignOverrides.treeIndent] | `Tree` |
/// | 展開圖示 | [DesignOverrides.expanderIconExpanded]、[DesignOverrides.expanderIconCollapsed] | `ExpanderIcon` |
/// | 篩選下拉配色 | [DesignOverrides.filterDropdownColors] | `FilterDropdown` |
///
/// 未注入（[DesignOverrides.maybeOf] 回傳 `null`）或欄位為 `null` 時，元件
/// 走原本的 token 常數，外觀與無接縫時一致。產品入口 `lib/main.dart` 不
/// 注入本接縫。
library;

import 'package:flutter/widgets.dart';

import 'app_button.dart';

/// 單一按鈕變體的覆寫色（欄位為 `null` 者沿用原值）。
@immutable
class ButtonColorOverride {
  const ButtonColorOverride({this.background, this.foreground, this.border});

  /// 覆寫底色。
  final Color? background;

  /// 覆寫字色。
  final Color? foreground;

  /// 覆寫邊框色。
  final Color? border;
}

/// 篩選下拉觸發器的覆寫色（欄位為 `null` 者沿用原值）。
@immutable
class FilterDropdownColorOverride {
  const FilterDropdownColorOverride({
    this.background,
    this.border,
    this.activeBorder,
  });

  /// 觸發器與選單底色（預設 `AppColors.surfaceBase`）。
  final Color? background;

  /// 未選值且未聚焦的邊框色（預設 `AppColors.border`）。
  final Color? border;

  /// 已選值或聚焦時的邊框色（預設 `AppColors.accent`）。
  final Color? activeBorder;
}

/// 設計覆寫容器，僅供測試與研究入口注入；產品碼不得使用。
class DesignOverrides extends InheritedWidget {
  const DesignOverrides({
    super.key,
    required super.child,
    this.buttonColors = const {},
    this.sectionItemGap,
    this.issueMarkerColor,
    this.treeIndent,
    this.expanderIconExpanded,
    this.expanderIconCollapsed,
    this.filterDropdownColors,
  });

  /// A 類：依 [AppButtonVariant] 覆寫按鈕顏色（改變主次視覺權重）。
  final Map<AppButtonVariant, ButtonColorOverride> buttonColors;

  /// B 類：覆寫 `Section` 項目間距（預設 `Space.xxs`）。
  final double? sectionItemGap;

  /// C' 類：覆寫 `IssueMarker` 的標記色（預設 `AppColors.error`）。
  final Color? issueMarkerColor;

  /// 覆寫 `Tree` 每層縮排寬（預設 `LayoutSize.treeIndent`）。
  final double? treeIndent;

  /// 覆寫 `ExpanderIcon` 展開態圖示（預設 `Icons.keyboard_arrow_down`）。
  final IconData? expanderIconExpanded;

  /// 覆寫 `ExpanderIcon` 收合態圖示（預設 `Icons.keyboard_arrow_right`）。
  final IconData? expanderIconCollapsed;

  /// 覆寫 `FilterDropdown` 配色。
  final FilterDropdownColorOverride? filterDropdownColors;

  /// 取最近的覆寫；未注入回傳 `null`。
  static DesignOverrides? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignOverrides>();

  @override
  bool updateShouldNotify(DesignOverrides oldWidget) =>
      buttonColors != oldWidget.buttonColors ||
      sectionItemGap != oldWidget.sectionItemGap ||
      issueMarkerColor != oldWidget.issueMarkerColor ||
      treeIndent != oldWidget.treeIndent ||
      expanderIconExpanded != oldWidget.expanderIconExpanded ||
      expanderIconCollapsed != oldWidget.expanderIconCollapsed ||
      filterDropdownColors != oldWidget.filterDropdownColors;
}
