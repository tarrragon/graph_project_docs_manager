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

import '../app/attention_level.dart';
import '../tokens/tokens.dart';

/// [AppSnackBar] 的兩種變體（SPEC-004 §4.26「變體」）。
enum AppSnackBarVariant {
  /// 純文字，停留 [Motion.snackBar]。
  plain,

  /// 文字 + 一個動作，停留 [Motion.snackBarWithAction]。
  withAction,
}

/// 一次 [AppSnackBar.show] 的發起者（SPEC-003〈截斷事件的日誌等級〉）。
///
/// 截斷日誌的等級以本列舉為鍵，不以 [AppSnackBarVariant] 為鍵——變體會
/// 同時誤判兩邊（`withAction` 亦可能是使用者發起；背景發起亦可能是 `plain`）。
enum AppSnackBarOrigin {
  /// 呼叫來自使用者互動回呼（`onTap` / `onPressed` 路徑）。截斷時使用者
  /// 剛做過動作、沒反應會注意到，故為 info。
  userInitiated,

  /// 呼叫來自背景 listener（如掃描完成）。截斷後使用者無任何線索指出
  /// 曾發生過什麼，故為 warning。
  background,
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

  /// 截斷發生的當下，由截斷者記錄（0.1.0-W3-205）。攜帶「誰截斷了誰」的
  /// 關聯（[preemptedShowId]），與被截斷者自身的 `closed{reason: hide}`
  /// 合起來回答「被截斷的是哪一則」。
  preempted,

  /// 低級別讓步、決定不呈現時記錄（0.1.0-W3-205）。被丟棄的請求從未進入
  /// [shown]，此事件是它唯一的痕跡——`0.1.0-W3-239` 裁定不引入佇列，讓步
  /// 的處置是不呈現並留痕，不是排隊等待。
  yielded,
}

/// 呼叫端已知的當前通道持有者快照（0.1.0-W3-205，過渡形態）。
///
/// `currentHolder == null` 的語意是**未知**，不是「通道為空」——過渡期
/// 呼叫端無資訊來源，一律傳 null，此時行為與現況一致（截斷後呈現），但
/// 事件必帶 `holderUnknown: true`，使「這個判斷還沒有輸入」本身可被搜尋。
///
/// 過渡形態：`0.1.0-W3-207` 的仲裁器合併後，本型別與 `currentHolder` 參數
/// 一併由 `AttentionAccepted.preempted` 取代（收斂由該票承擔）。
final class AttentionHolderHint {
  const AttentionHolderHint({required this.showId, required this.level});

  /// 被截斷者的識別，與本檔 [AppSnackBarLogSink] 的 `showId` 同一空間。
  final int showId;

  /// 持有者目前顯示中訊息的級別。
  final AttentionLevel level;
}

/// 截斷裁決結果（0.1.0-W3-205）。私有——不進入公開面。
///
/// 把「要不要清除」與「事件欄位怎麼填」由同一個值決定，避免兩處各自判斷
/// 而漂移。
enum _Preemption {
  /// 持有者未知（過渡期正式路徑恆走此值）。
  holderUnknown,

  /// 持有者級別低於新請求，可被搶佔。
  preemptLower,

  /// 持有者級別與新請求相同，截斷並留痕（`0.1.0-W3-239` 具名例外）。
  replaceSameLevel,

  /// 持有者級別高於新請求，新請求須讓步（不清除、不呈現）。
  yieldToHolder,
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

  // dart:developer 承自 package:logging 的 Level 值（INFO=800、WARNING=900）；
  // 專案既有 warning 皆為 900（2.4 日誌等級規則表）。
  static const int _levelInfo = 800;
  static const int _levelWarning = 900;

  // 一次 show 呼叫的關聯識別（D1）：process 內單調遞增，供四個日誌事件
  // 共享同一值以配對；不重置、不提供重置 API（少一個公開面）。單執行緒事件
  // 迴圈、遞增之間無 await，無競態。
  static int _lastShowId = 0;

  // 不記錄任何日誌事件（C-1）——可稽核性已由 shown／skippedUnmounted 兩者
  // 之一必然攜帶本次 showId 達成，不需額外一筆「show 被呼叫」事件。
  static int _nextShowId() {
    _lastShowId += 1;
    return _lastShowId;
  }

  // 等級判定純函式（M3，D3）：輸入恰為 (reason, origin)，不接受 variant，
  // 故其函式體不可能引用 variant（V-2 的結構性可讀出性質）。
  static int? _resolveClosedLevel(
    SnackBarClosedReason reason,
    AppSnackBarOrigin origin,
  ) {
    if (reason != SnackBarClosedReason.hide) {
      return null;
    }
    if (origin == AppSnackBarOrigin.background) {
      return _levelWarning;
    }
    return _levelInfo;
  }

  // 截斷裁決純函式（唯一裁決點，0.1.0-W3-205 T-205-17）：輸入恰兩項，
  // 不接受 variant／origin／message／錨點，函式體因此不可能引用它們
  // （結構性可讀出）。比較鍵恆為級別的序，不得以載體型別、變體或呼叫
  // 路徑為鍵。
  static _Preemption _resolvePreemption(
    AttentionLevel incoming,
    AttentionHolderHint? holder,
  ) {
    if (holder == null) {
      return _Preemption.holderUnknown;
    }
    if (holder.level.index < incoming.index) {
      return _Preemption.preemptLower;
    }
    if (holder.level.index == incoming.index) {
      return _Preemption.replaceSameLevel;
    }
    return _Preemption.yieldToHolder;
  }

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

  /// 顯示一則 SnackBar，依級別裁決是否取代目前顯示的任何 SnackBar
  /// （0.1.0-W3-205〈截斷條件綁級別〉）。
  ///
  /// [message] 為必填內容 slot（呼叫端傳入已取好值的 i18n 字串）。
  /// [variant] 為 [AppSnackBarVariant.withAction] 時，[actionLabel]、
  /// [onAction]、[actionTestKey] 為必填。[level] 取值以標題文字引用
  /// SPEC-003〈注意力通道的到達類別與級別指派表〉，本元件內不另立一套
  /// 級別定義。[currentHolder] 為過渡形態（`0.1.0-W3-207` 合併前）：呼叫端
  /// 已知的當前通道持有者快照，`null` 語意為未知。
  static void show(
    BuildContext context, {
    required String message,
    required AttentionLevel level,
    AppSnackBarVariant variant = AppSnackBarVariant.plain,
    String? actionLabel,
    VoidCallback? onAction,
    Key? actionTestKey,
    AppSnackBarOrigin origin = AppSnackBarOrigin.background,
    AttentionHolderHint? currentHolder,
  }) {
    assert(
      variant != AppSnackBarVariant.withAction ||
          (actionLabel != null && onAction != null),
      _actionSlotAssertMessage,
    );

    // showId 在 mounted 判定之前產生（D1），使 skippedUnmounted 也有識別。
    final showId = _nextShowId();
    final baseFields = <String, Object?>{'showId': showId, 'origin': origin};

    // 早退關卡 1（必須位於裁決之前，T-205-8／既有 M7／M15）：靜默早退
    // （唯一無痕跡的失敗路徑，0.1.0-W3-078 起因）：context 已卸載時
    // ScaffoldMessenger.of 查找不安全，記錄 warning 後直接返回。
    if (!context.mounted) {
      logSink(AppSnackBarLogEvent.skippedUnmounted, {
        ...baseFields,
        'variant': variant,
        'message': message,
      }, level: _levelWarning);
      return;
    }

    // 裁決（唯一裁決點，輸入恰兩項）。
    final decision = _resolvePreemption(level, currentHolder);

    // 早退關卡 2（讓步，不清除、不呈現、不排隊，`0.1.0-W3-239` 裁決）：
    // 出口 1／出口 2 皆早於下方唯一的清除，使 INV-SNACKBAR-NOQUEUE
    // （T-205-16(c)(d)(e)）結構性成立——本區塊之後不得再出現任何 return。
    if (decision == _Preemption.yieldToHolder) {
      logSink(AppSnackBarLogEvent.yielded, {
        ...baseFields,
        'level': level,
        'holderShowId': currentHolder?.showId,
        'holderLevel': currentHolder?.level,
        'variant': variant,
        'message': message,
      }, level: origin == AppSnackBarOrigin.background ? _levelWarning : _levelInfo);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // 新的 SnackBar 取代 → dismissed（SPEC-004 §4.26 狀態矩陣退出路徑）。
    // 全檔唯一的「無引數清除」，緊接於本函式主體，其後恰接一次呈現
    // （INV-SNACKBAR-NOQUEUE，T-205-16）。
    messenger.hideCurrentSnackBar();
    logSink(AppSnackBarLogEvent.preempted, {
      ...baseFields,
      'level': level,
      'preemptedShowId': currentHolder?.showId,
      'preemptedLevel': currentHolder?.level,
      'sameLevelReplace': decision == _Preemption.replaceSameLevel,
      'holderUnknown': decision == _Preemption.holderUnknown,
    });
    final isWithAction = variant == AppSnackBarVariant.withAction;
    final durationToken = isWithAction
        ? 'Motion.snackBarWithAction'
        : 'Motion.snackBar';
    logSink(AppSnackBarLogEvent.shown, {
      ...baseFields,
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
                    // 順序：記錄 -> 帶原因清除 -> 回呼（0.1.0-W3-205
                    // 觀察 B 處置）。清除移到 onAction 之前保證的是「新的
                    // 一則」不被誤記——若 onAction 同步再顯示一則，此處的
                    // hide(reason: action) 對應的 completer 因 Flutter
                    // TickerFuture 取消語意（見 T-205-11 dartdoc 更正）
                    // 恆不完成，故舊的一則最終記為 reason: hide 而非
                    // action；新的一則因此不會被誤記為使用者一眼未見即
                    // 以 action 關掉（T-205-11）。此處帶引數清除不計入
                    // INV-SNACKBAR-NOQUEUE 的「無引數清除恰 1 次」。
                    logSink(AppSnackBarLogEvent.actionPressed, {
                      ...baseFields,
                      'actionLabel': actionLabel,
                    });
                    messenger.hideCurrentSnackBar(
                      reason: SnackBarClosedReason.action,
                    );
                    onAction!();
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
      // baseFields／origin 由本次呼叫的區域繫結經閉包捕獲，不讀取模組級
      // 現值——closed 完成時計數器可能已被後續 show 遞增（C-2、語言注意
      // 事項段）。
      logSink(AppSnackBarLogEvent.closed, {
        ...baseFields,
        'reason': reason,
      }, level: _resolveClosedLevel(reason, origin));
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
