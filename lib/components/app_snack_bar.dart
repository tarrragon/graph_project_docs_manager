/// AppSnackBar（SPEC-004 §4.26）。
///
/// 「已在外部開啟」「找不到檔案」類的暫時訊息之唯一承載元件；Material
/// 進出動畫不覆寫（SPEC-003 §2.2），停留時間統一取 [Motion.snackBar] /
/// [Motion.snackBarWithAction]。不放入任何容器——經 [ScaffoldMessenger]
/// 顯示於主區覆蓋層（SPEC-004 §4.26 組合規則），故本元件不是渲染進
/// widget tree 的 [Widget]，而是呼叫端以 [AppSnackBar.show] 觸發的
/// 靜態入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';

/// [AppSnackBar] 的兩種變體（SPEC-004 §4.26「變體」）。
enum AppSnackBarVariant {
  /// 純文字，停留 [Motion.snackBar]。
  plain,

  /// 文字 + 一個動作，停留 [Motion.snackBarWithAction]。
  withAction,
}

/// SnackBar 唯一承載元件（SPEC-004 §4.26）。
///
/// 呼叫端以 [show] 觸發；`withAction` 變體必須提供 [actionLabel]、
/// [onAction]、[actionTestKey]（slot 契約）。
abstract final class AppSnackBar {
  static const String _actionSlotAssertMessage = // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
      'actionLabel 與 onAction 於 withAction 變體為必填（SPEC-004 §4.26 slot 契約）';

  /// 顯示一則 SnackBar，取代目前顯示的任何 SnackBar。
  ///
  /// [message] 為必填內容 slot（呼叫端傳入已取好值的 i18n 字串）。
  /// [variant] 為 [AppSnackBarVariant.withAction] 時，[actionLabel]、
  /// [onAction]、[actionTestKey] 為必填。
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarVariant variant = AppSnackBarVariant.plain,
    String? actionLabel,
    VoidCallback? onAction,
    Key? actionTestKey,
  }) {
    assert(
      variant != AppSnackBarVariant.withAction ||
          (actionLabel != null && onAction != null),
      _actionSlotAssertMessage,
    );

    final messenger = ScaffoldMessenger.of(context);
    // 新的 SnackBar 取代 → dismissed（SPEC-004 §4.26 狀態矩陣退出路徑）。
    messenger.hideCurrentSnackBar();
    final isWithAction = variant == AppSnackBarVariant.withAction;
    messenger.showSnackBar(
      SnackBar(
        // content 自組文字＋動作：Material 內建 SnackBarAction 的 Text 無
        // overflow 設定，單一不可斷詞的長 token 會使 Row 溢位；改由本元件
        // 掌控動作 slot 的截斷（SPEC-004 §4.26 內容政策：動作 label 單行、
        // 超出截斷）。
        content: Row(
          children: [
            Flexible(
              // message 佔多數寬度；withAction 時讓出空間給動作 slot
              // （下方 Flexible），兩者皆有界寬度，ellipsis 才會生效。
              flex: isWithAction ? 3 : 1,
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.body.sp,
                  color: AppColors.surfaceBase,
                ),
              ),
            ),
            if (isWithAction) ...[
              SizedBox(width: Space.sm.w),
              Flexible(
                flex: 1,
                child: _SnackBarActionLabel(
                  key: actionTestKey,
                  label: actionLabel!,
                  onPressed: () {
                    onAction!();
                    messenger.hideCurrentSnackBar(
                      reason: SnackBarClosedReason.action,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.textTitle,
        padding: EdgeInsets.symmetric(
          horizontal: Space.md.w,
          vertical: Space.sm.h,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radius.md.r),
        ),
        duration: isWithAction ? Motion.snackBarWithAction : Motion.snackBar,
      ),
    );
  }
}

/// 動作 label（單行、超出截斷；SPEC-004 §4.26 內容政策）。
///
/// 取代 Material 內建 [SnackBarAction]——其 `Text(label)` 無 overflow 設定，
/// 無法承接「超出處置：截斷」的契約，故以最小可命中區的 [InkWell] +
/// 單行 [Text] 自組，語意（button role、只觸發一次）由 [Semantics] 補上。
class _SnackBarActionLabel extends StatefulWidget {
  const _SnackBarActionLabel({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_SnackBarActionLabel> createState() => _SnackBarActionLabelState();
}

class _SnackBarActionLabelState extends State<_SnackBarActionLabel> {
  bool _triggered = false;

  void _handleTap() {
    // 動作只可觸發一次（Material SnackBarAction 慣例：後續點選忽略）。
    if (_triggered) {
      return;
    }
    setState(() => _triggered = true);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin),
        child: InkWell(
          onTap: _handleTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.xs.w),
            child: Center(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.body.sp,
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
