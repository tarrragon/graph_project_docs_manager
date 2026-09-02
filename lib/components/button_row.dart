/// ButtonRow（SPEC-004 §4.34、§5.8）。
///
/// 容器元件：水平排列 1..3 個 [AppButton]，狀態元件動作區、頁首右側
/// 頁面級動作區、格詳情卡動作區共用。`primary` 變體至多 1 個且須置於
/// 首位（SPEC-004 §4.34 slot 契約）。父格位寬不足時換行（§5.8 空間不足
/// 策略），子件垂直置中。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_button.dart';
import '../tokens/spacing.dart';

/// [ButtonRow] 子件對齊方式（SPEC-004 §4.34 slot 契約）。
enum ButtonRowAlignment {
  /// 靠父格位起始端對齊，預設值。
  start,

  /// 置中對齊，狀態元件內動作區使用。
  center,

  /// 靠父格位末端對齊，頁首右格使用。
  end,
}

/// SPEC-004 §4.34 容器：`AppButton` × 1..3 水平排列。
///
/// 不重疊：同列水平互斥、列間垂直互斥；最小間距水平與列間皆
/// [Space.sm]，呼叫端不得覆寫；空間不足時換行（[Wrap] 原生行為）。
class ButtonRow extends StatelessWidget {
  ButtonRow({
    super.key,
    required this.children,
    this.alignment = ButtonRowAlignment.start,
  }) : assert(
         children.isNotEmpty && children.length <= 3,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'ButtonRow 子件數量須介於 1..3（SPEC-004 §4.34 slot 契約）',
       ),
       assert(
         _primaryCountValid(children),
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'primary 變體至多 1 個且須置於首位（SPEC-004 §4.34 slot 契約）',
       );

  /// 子件（1..3 個 [AppButton]；`primary` 至多 1 個且置於首位）。
  final List<AppButton> children;

  /// 對齊方式，預設 [ButtonRowAlignment.start]。
  final ButtonRowAlignment alignment;

  static bool _primaryCountValid(List<AppButton> children) {
    final primaryIndexes = <int>[
      for (var i = 0; i < children.length; i++)
        if (children[i].variant == AppButtonVariant.primary) i,
    ];
    if (primaryIndexes.length > 1) {
      return false;
    }
    return primaryIndexes.isEmpty || primaryIndexes.first == 0;
  }

  WrapAlignment get _wrapAlignment => switch (alignment) {
    ButtonRowAlignment.start => WrapAlignment.start,
    ButtonRowAlignment.center => WrapAlignment.center,
    ButtonRowAlignment.end => WrapAlignment.end,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: _wrapAlignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.sm.w,
      runSpacing: Space.sm.h,
      children: children,
    );
  }
}
