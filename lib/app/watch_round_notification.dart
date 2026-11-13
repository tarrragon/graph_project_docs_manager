/// [SPEC-006 FR-11 規則 9 (a)（D1）；SPEC-003 §2.2〈系統層通知〉監看輪次列]
/// 監看輪次完成時的系統層通知判定（0.6.0-W1-080）。
library;

import 'package:graph_project_docs_manager/app/app_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 判定結果。
class WatchNotificationDecision {
  const WatchNotificationDecision({
    required this.shouldSend,
    required this.addedCount,
    required this.removedCount,
  });

  final bool shouldSend;
  final int addedCount;
  final int removedCount;
}

/// 改變判準（itemId 兩向差集）AND 可見性條件（非前景或不在破洞頁）。
/// [previousItemIds] 為 null 時以空集合比較。
WatchNotificationDecision decideWatchNotification({
  required Set<String>? previousItemIds,
  required Set<String> currentItemIds,
  required bool isForeground,
  required bool isOnGapsPage,
}) {
  final previous = previousItemIds ?? const <String>{};
  final added = currentItemIds.difference(previous).length;
  final removed = previous.difference(currentItemIds).length;
  final changed = added > 0 || removed > 0;
  final visible = !(isForeground && isOnGapsPage);
  return WatchNotificationDecision(
    shouldSend: changed && visible,
    addedCount: added,
    removedCount: removed,
  );
}

/// 通知平台埠。
abstract interface class GapsNotificationPort {
  /// 撤回本 App 尚未被點擊的舊通知。
  Future<void> withdrawPending();

  /// 發送監看專用通知（`scanCompleteWatchNotification*`）。
  Future<void> sendWatchNotification(int count);
}

/// 依判定發送：先撤回舊通知再發送；撤回失敗不阻擋發送；不發送時兩者皆不呼叫。
Future<void> deliverWatchNotification({
  required GapsNotificationPort port,
  required WatchNotificationDecision decision,
  required int count,
}) async {
  if (!decision.shouldSend) return;
  try {
    await port.withdrawPending();
  } catch (error) {
    appLogSink(
      AppLogEvent.watchNotificationWithdrawFailed,
      LogFields.empty,
      level: LogLevel.error,
      source: ErrorSource.platformIo,
      error: error,
    );
  }
  await port.sendWatchNotification(count);
}
