/// SPEC-006 FR-11 規則 9 (a)（D1）、SPEC-003 §2.2〈系統層通知〉監看輪次列
/// （0.6.0-W1-080 Phase 2 紅燈）。
///
/// Phase 3b 待補 stub：`lib/app/watch_round_notification.dart`；平台端的實際
/// 撤回／發送與 i18n key `scanCompleteWatchNotification*` 由 Phase 3b 同批加入。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/watch_round_notification.dart';

WatchNotificationDecision _decide(
  Set<String>? prev,
  Set<String> cur, {
  bool foreground = false,
  bool onGaps = false,
}) => decideWatchNotification(
  previousItemIds: prev,
  currentItemIds: cur,
  isForeground: foreground,
  isOnGapsPage: onGaps,
);

class _RecordingPort implements GapsNotificationPort {
  _RecordingPort({this.withdrawFails = false});
  final bool withdrawFails;
  final List<String> calls = <String>[];

  @override
  Future<void> withdrawPending() async {
    calls.add('withdraw');
    if (withdrawFails) throw StateError('withdraw failed');
  }

  @override
  Future<void> sendWatchNotification(int count) async =>
      calls.add('send:$count');
}

void main() {
  group('D1 改變判準（itemId 兩向差集）', () {
    test('新增一項 → 發送，added=1', () {
      final d = _decide({'a'}, {'a', 'b'});
      expect(d.shouldSend, isTrue);
      expect(d.addedCount, 1);
      expect(d.removedCount, 0);
    });

    test('消失一項 → 發送，removed=1', () {
      final d = _decide({'a', 'b'}, {'a'});
      expect(d.shouldSend, isTrue);
      expect(d.removedCount, 1);
    });

    test('對照：集合相同 → 不發送', () {
      expect(_decide({'a', 'b'}, {'b', 'a'}).shouldSend, isFalse);
    });

    test('上一輪無結果以空集合比較：有項目 → 發送；空 → 不發送', () {
      expect(_decide(null, {'a'}).shouldSend, isTrue);
      expect(_decide(null, <String>{}).shouldSend, isFalse);
    });
  });

  group('D1 可見性條件', () {
    test('前景且在破洞頁 → 不發送（即使集合改變）', () {
      expect(
        _decide({'a'}, {'b'}, foreground: true, onGaps: true).shouldSend,
        isFalse,
      );
    });

    test('前景但不在破洞頁 → 發送', () {
      expect(_decide({'a'}, {'b'}, foreground: true).shouldSend, isTrue);
    });

    test('非前景且在破洞頁 → 發送', () {
      expect(_decide({'a'}, {'b'}, onGaps: true).shouldSend, isTrue);
    });
  });

  group('D1 發送前撤回', () {
    const send = WatchNotificationDecision(
      shouldSend: true,
      addedCount: 1,
      removedCount: 0,
    );
    const skip = WatchNotificationDecision(
      shouldSend: false,
      addedCount: 0,
      removedCount: 0,
    );

    test('先撤回舊通知再發送，內文帶破洞總數', () async {
      final port = _RecordingPort();
      await deliverWatchNotification(port: port, decision: send, count: 3);
      expect(port.calls, ['withdraw', 'send:3']);
    });

    test('撤回失敗不阻擋發送', () async {
      final port = _RecordingPort(withdrawFails: true);
      await deliverWatchNotification(port: port, decision: send, count: 2);
      expect(port.calls, ['withdraw', 'send:2']);
    });

    test('對照：判定不發送時不撤回也不發送', () async {
      final port = _RecordingPort();
      await deliverWatchNotification(port: port, decision: skip, count: 2);
      expect(port.calls, isEmpty);
    });
  });
}
