// 監看輪次通知轉接與 itemId 集合對照（SPEC-003 §2.2 監看輪次列；
// SPEC-006 FR-11 規則 9 (a)；0.6.0-W1-080 批 B6）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/round_gaps.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_en.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_round_state.dart';
import 'package:graph_project_docs_manager/screens/gap_report/watch_round_notification_adapter.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';

import '../../../helpers/gap_round_fakes.dart';

class _RecordingNotifier implements ScanNotifier {
  final List<String> calls = <String>[];
  final List<ScanCompleteNotification> shown = <ScanCompleteNotification>[];

  @override
  Future<void> withdraw() async => calls.add('withdraw');

  @override
  Future<ScanNotificationDelivery> show(
    ScanCompleteNotification notification,
  ) async {
    calls.add('show');
    shown.add(notification);
    return ScanNotificationDelivery.delivered;
  }

  @override
  Future<NotificationAuthorization> authorizationStatus() async =>
      NotificationAuthorization.granted;

  @override
  Future<NotificationAuthorization> requestAuthorization() async =>
      NotificationAuthorization.granted;

  @override
  Stream<void> get activated => const Stream<void>.empty();
}

WatchRoundCompleted _done(Set<String>? ids, {ScanTrigger? trigger}) =>
    WatchRoundCompleted(
      trigger ?? ScanTrigger.watch,
      itemIds: ids,
      rerunPending: false,
    );

({WatchRoundNotificationAdapter adapter, _RecordingNotifier notifier}) _make({
  bool foreground = false,
  bool onGaps = false,
}) {
  final notifier = _RecordingNotifier();
  final adapter = WatchRoundNotificationAdapter(
    port: ScanNotifierWatchPort(notifier),
    isForeground: () => foreground,
    isOnGapsPage: () => onGaps,
  );
  return (adapter: adapter, notifier: notifier);
}

List<GapReportCategory> _categoriesOf(GapReportState s) => switch (s) {
  GapReportFound(:final categories) ||
  GapReportUndeterminable(:final categories) => categories,
  _ => const <GapReportCategory>[],
};

void main() {
  group('轉接：D1', () {
    test('集合改變：先撤回再發送，帶專用旗標與總數', () async {
      final t = _make();
      await t.adapter.onRoundCompleted(_done({'a'}));
      expect(t.notifier.calls, ['withdraw', 'show']);
      expect(t.notifier.shown.single.isWatchRound, isTrue);
      expect(t.notifier.shown.single.gapCount, 1);
    });

    test('正向對照：集合與上一輪相同則不撤回也不發送', () async {
      final t = _make();
      await t.adapter.onRoundCompleted(_done({'a'}));
      t.notifier.calls.clear();
      await t.adapter.onRoundCompleted(_done({'a'}));
      expect(t.notifier.calls, isEmpty);
    });

    test('前景且在破洞頁：不發送', () async {
      final t = _make(foreground: true, onGaps: true);
      await t.adapter.onRoundCompleted(_done({'a'}));
      expect(t.notifier.calls, isEmpty);
    });

    test('prev 取自上一輪（含手動輪）：手動輪只更新 prev 不通知', () async {
      final t = _make();
      await t.adapter.onRoundCompleted(
        _done({'a'}, trigger: ScanTrigger.manual),
      );
      expect(t.notifier.calls, isEmpty);
      await t.adapter.onRoundCompleted(_done({'a'}));
      expect(t.notifier.calls, isEmpty);
    });

    test('失敗輪次（itemIds 為 null）不通知也不更新 prev', () async {
      final t = _make();
      await t.adapter.onRoundCompleted(_done({'a'}));
      t.notifier.calls.clear();
      await t.adapter.onRoundCompleted(_done(null));
      await t.adapter.onRoundCompleted(_done({'a'}));
      expect(t.notifier.calls, isEmpty);
    });
  });

  group('文案：新 key', () {
    test('en／zh 專用標題與內文帶 count，且不同於手動掃描文案', () {
      final en = AppLocalizationsEn();
      final zh = AppLocalizationsZh();
      expect(en.scanCompleteWatchNotificationTitle, 'Gap report updated');
      expect(
        en.scanCompleteWatchNotificationBody(3),
        'Rescanned after file changes: 3 gaps now',
      );
      expect(zh.scanCompleteWatchNotificationTitle, '破洞報告已更新');
      expect(zh.scanCompleteWatchNotificationBody(3), contains('3'));
      expect(
        en.scanCompleteWatchNotificationTitle,
        isNot(en.scanCompleteNotificationTitle),
      );
    });
  });

  group('對照：gapItemIdsOf 與破洞頁 item.id', () {
    test('同一輪結果的集合相等', () {
      final round = fakeRound(
        parseFailureEvents: [
          fakeCarrierEvent('docs/a.md'),
          fakeCarrierEvent('docs/b.md'),
        ],
      );
      final state = gapReportStateFromRound(round, nonDomainPathsKey: 'k');
      final pageIds = <String>{
        for (final c in _categoriesOf(state))
          for (final i in c.items) i.id,
      };
      expect(pageIds, isNotEmpty);
      expect(gapItemIdsOf(round), pageIds);
    });

    test('正向對照：輪次內容不同則集合不同', () {
      final one = fakeRound(
        parseFailureEvents: [fakeCarrierEvent('docs/a.md')],
      );
      final two = fakeRound(
        parseFailureEvents: [
          fakeCarrierEvent('docs/a.md'),
          fakeCarrierEvent('docs/b.md'),
        ],
      );
      expect(gapItemIdsOf(one), isNot(gapItemIdsOf(two)));
    });
  });
}
