// 監看輪次通知的權限 gate 與 SnackBar fallback（SPEC-003 §2.2 權限 gate
// 三路徑、監看輪次列；0.6.0-W1-080 批 B8）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/screens/gap_report/watch_round_notification_adapter.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';

class _FakeNotifier implements ScanNotifier {
  _FakeNotifier(this.status, {this.requested, this.delivery});

  NotificationAuthorization status;
  final NotificationAuthorization? requested;
  final ScanNotificationDelivery? delivery;
  int showCalls = 0;
  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<void> withdraw() async {}

  @override
  Future<ScanNotificationDelivery> show(ScanCompleteNotification n) async {
    showCalls++;
    return delivery ?? ScanNotificationDelivery.delivered;
  }

  @override
  Future<NotificationAuthorization> authorizationStatus() async {
    statusCalls++;
    return status;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requestCalls++;
    return requested ?? NotificationAuthorization.denied;
  }

  @override
  Stream<void> get activated => const Stream<void>.empty();
}

void main() {
  late List<ScanCompleteNotification> fallbacks;
  setUp(() => fallbacks = <ScanCompleteNotification>[]);

  ScanNotifierWatchPort portOf(_FakeNotifier n) =>
      ScanNotifierWatchPort(n, onFallback: fallbacks.add);

  test('denied：不呼叫 show、走 SnackBar fallback，帶監看旗標與總數', () async {
    final n = _FakeNotifier(NotificationAuthorization.denied);
    await portOf(n).sendWatchNotification(3);
    expect(n.showCalls, 0);
    expect(n.requestCalls, 0);
    expect(fallbacks.single.gapCount, 3);
    expect(fallbacks.single.isWatchRound, isTrue);
  });

  test('正向對照 granted：照常 show、不走 fallback', () async {
    final n = _FakeNotifier(NotificationAuthorization.granted);
    await portOf(n).sendWatchNotification(3);
    expect(n.showCalls, 1);
    expect(fallbacks, isEmpty);
  });

  test('發送失敗：show 一次後走 fallback', () async {
    final n = _FakeNotifier(
      NotificationAuthorization.granted,
      delivery: ScanNotificationDelivery.failed,
    );
    await portOf(n).sendWatchNotification(2);
    expect(n.showCalls, 1);
    expect(fallbacks.single.gapCount, 2);
  });

  test('notDetermined 請求被拒：不 show、走 fallback', () async {
    final n = _FakeNotifier(NotificationAuthorization.notDetermined);
    await portOf(n).sendWatchNotification(1);
    expect(n.requestCalls, 1);
    expect(n.showCalls, 0);
    expect(fallbacks, hasLength(1));
  });

  test('notDetermined 請求獲准：補發、不走 fallback', () async {
    final n = _FakeNotifier(
      NotificationAuthorization.notDetermined,
      requested: NotificationAuthorization.granted,
    );
    await portOf(n).sendWatchNotification(1);
    expect(n.showCalls, 1);
    expect(fallbacks, isEmpty);
  });

  test('每次觸發重新查詢授權，不快取', () async {
    final n = _FakeNotifier(NotificationAuthorization.granted);
    final port = portOf(n);
    await port.sendWatchNotification(1);
    n.status = NotificationAuthorization.denied;
    await port.sendWatchNotification(1);
    expect(n.statusCalls, 2);
    expect(n.showCalls, 1);
    expect(fallbacks, hasLength(1));
  });
}
