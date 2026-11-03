/// 監看輪次完成 → 系統通知的轉接層（SPEC-003 §2.2 監看輪次列、
/// SPEC-006 FR-11 規則 9 (a)；0.6.0-W1-080 批 B6）。
///
/// 純邏輯：prev 取自上一輪完成的 itemId 集合，可見性由呼叫端以函式注入
/// （沿用 [ScanNotificationController] 已訂閱的 destination 與 lifecycle），
/// 判定與發送順序委派 `watch_round_notification.dart`。
library;

import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/app/watch_round_notification.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';

/// 以 [ScanNotifier] 實作 [GapsNotificationPort]：撤回走 `withdraw()`，
/// 發送走 `show(...)`（監看專用文案）。
class ScanNotifierWatchPort implements GapsNotificationPort {
  const ScanNotifierWatchPort(this._notifier);

  final ScanNotifier _notifier;

  @override
  Future<void> withdrawPending() => _notifier.withdraw();

  @override
  Future<void> sendWatchNotification(int count) async {
    await _notifier.show(
      ScanCompleteNotification(gapCount: count, isWatchRound: true),
    );
  }
}

class WatchRoundNotificationAdapter {
  WatchRoundNotificationAdapter({
    required this.port,
    required this.isForeground,
    required this.isOnGapsPage,
  });

  final GapsNotificationPort port;
  final bool Function() isForeground;
  final bool Function() isOnGapsPage;

  Set<String>? _previousItemIds;

  /// 輪次完成事件入口；失敗輪次（itemIds 為 null）不更新 prev、不通知。
  /// 非監看觸發的輪次只更新 prev。
  Future<void> onRoundCompleted(WatchRoundCompleted event) async {
    final current = event.itemIds;
    if (current == null) return;
    final previous = _previousItemIds;
    _previousItemIds = current;
    if (event.trigger != ScanTrigger.watch) return;
    final decision = decideWatchNotification(
      previousItemIds: previous,
      currentItemIds: current,
      isForeground: isForeground(),
      isOnGapsPage: isOnGapsPage(),
    );
    await deliverWatchNotification(
      port: port,
      decision: decision,
      count: current.length,
    );
  }

  /// 專案切換後上一輪結果不再可比。
  void reset() => _previousItemIds = null;
}
