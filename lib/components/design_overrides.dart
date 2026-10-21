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

/// 設計覆寫容器，僅供測試與研究入口注入；產品碼不得使用。
class DesignOverrides extends InheritedWidget {
  const DesignOverrides({
    super.key,
    required super.child,
    this.buttonColors = const {},
    this.sectionItemGap,
    this.issueMarkerColor,
  });

  /// A 類：依 [AppButtonVariant] 覆寫按鈕顏色（改變主次視覺權重）。
  final Map<AppButtonVariant, ButtonColorOverride> buttonColors;

  /// B 類：覆寫 `Section` 項目間距（預設 `Space.xxs`）。
  final double? sectionItemGap;

  /// C' 類：覆寫 `IssueMarker` 的標記色（預設 `AppColors.error`）。
  final Color? issueMarkerColor;

  /// 取最近的覆寫；未注入回傳 `null`。
  static DesignOverrides? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignOverrides>();

  @override
  bool updateShouldNotify(DesignOverrides oldWidget) =>
      buttonColors != oldWidget.buttonColors ||
      sectionItemGap != oldWidget.sectionItemGap ||
      issueMarkerColor != oldWidget.issueMarkerColor;
}
