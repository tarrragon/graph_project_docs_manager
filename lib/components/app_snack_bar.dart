/// AppSnackBar（SPEC-004 §4.26）。
///
/// 「已在外部開啟」「找不到檔案」類的暫時訊息之唯一承載元件；Material
/// 進出動畫不覆寫（SPEC-003 §2.2），停留時間統一取 [Motion.snackBar] /
/// [Motion.snackBarWithAction]。不放入任何容器——經 [ScaffoldMessenger]
/// 顯示於主區覆蓋層（SPEC-004 §4.26 組合規則），故本元件不是渲染進
/// widget tree 的 [Widget]，而是呼叫端以 [AppSnackBar.show] 觸發的
/// 靜態入口。
library;

import 'dart:developer' as developer;

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

/// [AppSnackBar] 診斷日誌的事件類別（0.1.0-W3-165）。
///
/// 測試斷言依此列舉與 [AppSnackBarLogSink] 的 `fields` 結構化欄位判斷「發生
/// 了什麼」，不比對日誌散文字面——`0.1.0-W3-132` 尚未把日誌訊息改為事件識別
/// 碼，比對字面會與其目標衝突。
enum AppSnackBarLogEvent {
  /// 顯示入口：variant／訊息／停留時長／動作標籤已決定，即將呼叫
  /// [ScaffoldMessenger.showSnackBar]。
  shown,

  /// 靜默早退：`context` 已卸載，未呼叫 [ScaffoldMessenger]（元件加掛日誌前
  /// 唯一無痕跡的失敗路徑；`0.1.0-W3-078` 起因）。
  skippedUnmounted,

  /// 動作按鈕被按下（`withAction` 變體，第三層回饋的消費點）。
  actionPressed,

  /// SnackBar 結束，[SnackBarClosedReason] 可由 `closed` future 判定時記錄。
  closed,
}

/// 日誌投影的接縫。生產預設轉呼 `developer.log(name: 'AppSnackBar')`；
/// `fields` 攜帶結構化欄位（測試取用），組句給人閱讀由接收端自行處理。
typedef AppSnackBarLogSink = void Function(
  AppSnackBarLogEvent event,
  Map<String, Object?> fields, {
  int? level,
});

/// SnackBar 唯一承載元件（SPEC-004 §4.26）。
///
/// 呼叫端以 [show] 觸發；`withAction` 變體必須提供 [actionLabel]、
/// [onAction]、[actionTestKey]（slot 契約）。
abstract final class AppSnackBar {
  static const String
  _actionSlotAssertMessage = // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
      'actionLabel 與 onAction 於 withAction 變體為必填（SPEC-004 §4.26 slot 契約）';

  static const String _tag = 'AppSnackBar';

  static void _defaultLogSink(
    AppSnackBarLogEvent event,
    Map<String, Object?> fields, {
    int? level,
  }) {
    final detail = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    if (level != null) {
      developer.log(
        '$event：$detail',
        name: _tag,
        level: level,
      ); // i18n-exempt: 開發者診斷 log
      return;
    }
    developer.log('$event：$detail', name: _tag); // i18n-exempt: 開發者診斷 log
  }

  /// 日誌投影的接縫（測試替身注入點；正式路徑固定用 [_defaultLogSink]）。
  @visibleForTesting
  static AppSnackBarLogSink logSink = _defaultLogSink;

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

    // 靜默早退（唯一無痕跡的失敗路徑，0.1.0-W3-078 起因）：context 已卸載時
    // ScaffoldMessenger.of 查找不安全，記錄 warning 後直接返回。
    if (!context.mounted) {
      logSink(AppSnackBarLogEvent.skippedUnmounted, {
        'variant': variant,
        'message': message,
      }, level: 900);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // 新的 SnackBar 取代 → dismissed（SPEC-004 §4.26 狀態矩陣退出路徑）。
    messenger.hideCurrentSnackBar();
    final isWithAction = variant == AppSnackBarVariant.withAction;
    final durationToken = isWithAction
        ? 'Motion.snackBarWithAction'
        : 'Motion.snackBar';
    logSink(AppSnackBarLogEvent.shown, {
      'variant': variant,
      'message': message,
      'duration': durationToken,
      if (isWithAction) 'actionLabel': actionLabel,
    });
    final controller = messenger.showSnackBar(
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
                    logSink(AppSnackBarLogEvent.actionPressed, {
                      'actionLabel': actionLabel,
                    });
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
    // 結束原因可由 Material 的 closed future 判定（SnackBarClosedReason：
    // action／dismiss／hide／remove／swipe／timeout），故記錄而非省略
    // （how.strategy 決策點 4）。
    controller.closed.then((reason) {
      logSink(AppSnackBarLogEvent.closed, {'reason': reason});
    });
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
