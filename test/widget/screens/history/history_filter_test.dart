// 變更記錄篩選列與期間描述（測試設計 §3.3，FL-1～FL-11）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_en.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';

import '../../../helpers/history/history_screen_fixtures.dart';

final _zh = AppLocalizationsZh();
final _en = AppLocalizationsEn();

Finder _key(String k) => find.byKey(Key(k));

bool _selected(WidgetTester tester, String key) =>
    tester.widget<Semantics>(_key(key)).properties.selected ?? false;

bool _checked(WidgetTester tester) =>
    (tester
        .widget<Semantics>(_key('action-history-include-ticket-created'))
        .properties
        .checked ??
    false);

int _rowCount(WidgetTester tester) =>
    tester.widgetList(find.byType(AppTableRow)).length - 1;

String _summary(WidgetTester tester) =>
    tester.widget<AppText>(_key('text-history-period-summary')).text;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FL-1 初始：預設期間選取、包含 ticket 建檔未勾選', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_selected(tester, 'option-history-period-default'), isTrue);
    expect(_selected(tester, 'option-history-period-all'), isFalse);
    expect(_checked(tester), isFalse);
  });

  testWidgets('FL-2 依序切換期間與勾選：事件數更新，不觸發 enter／refresh', (tester) async {
    final fake = await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    final enterBefore = fake.enterCalls;
    await _tap(tester, 'option-history-period-all');
    expect(_rowCount(tester), 4);
    await _tap(tester, 'option-history-period-recent30');
    expect(_rowCount(tester), 3);
    await _tap(tester, 'option-history-period-default');
    expect(_rowCount(tester), 3);
    await _tap(tester, 'action-history-include-ticket-created');
    expect(_rowCount(tester), 4);
    expect(fake.enterCalls, enterBefore);
    expect(fake.refreshCalls, 0);
  });

  testWidgets('FL-3 期間描述 zh', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_summary(tester), 'v0.6.0 之後 · 3 筆事件');
  });

  testWidgets('FL-3 期間描述 en，且不出現中文字面', (tester) async {
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapTagged()),
      locale: const Locale('en'),
    );
    expect(_summary(tester), 'Since v0.6.0 · 3 events');
    expect(find.textContaining('之後'), findsNothing);
  });

  testWidgets('FL-4 無 tag：期間描述為最近 30 天', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapNoTag()));
    expect(
      _summary(tester),
      _zh.historyPeriodSummary(_zh.historyPeriodRecent30Label, 1),
    );
  });

  testWidgets('FL-5 選全部歷史：期間描述為全部歷史', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    await _tap(tester, 'option-history-period-all');
    expect(
      _summary(tester),
      _zh.historyPeriodSummary(_zh.historyPeriodAllLabel, 4),
    );
    expect(_en.historyPeriodAllLabel, isNotEmpty);
  });

  testWidgets('FL-6 include 開關前後結果不同（E4 出現）', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(find.text('0.7.0-W1-012.4'), findsNothing);
    await _tap(tester, 'action-history-include-ticket-created');
    expect(find.text('0.7.0-W1-012.4'), findsOneWidget);
    expect(_checked(tester), isTrue);
    await _tap(tester, 'action-history-include-ticket-created');
    expect(find.text('0.7.0-W1-012.4'), findsNothing);
  });

  testWidgets('FL-7 篩選後結果空：normal 轉 empty，篩選列仍在', (tester) async {
    var now = kHistoryTestNow;
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapTagged()),
      extra: [historyClockProvider.overrideWithValue(() => now)],
    );
    expect(_key('state-history-normal'), findsOneWidget);
    now = DateTime.utc(2027, 3, 1);
    await _tap(tester, 'option-history-period-recent30');
    expect(_key('state-history-empty'), findsOneWidget);
    expect(_key('state-history-normal'), findsNothing);
    expect(_key('option-history-period-all'), findsOneWidget);
  });

  testWidgets('FL-8 期間內無事件：顯示全部歷史後 normal 且事件數 2', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapEmptyDefault()));
    await _tap(tester, 'action-history-show-all');
    expect(_selected(tester, 'option-history-period-all'), isTrue);
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_rowCount(tester), 2);
  });

  testWidgets('FL-9 全歷史無事件：維持 empty，顯示全部歷史仍可見', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapAllEmpty()));
    await _tap(tester, 'action-history-show-all');
    expect(_key('state-history-empty'), findsOneWidget);
    expect(_key('action-history-show-all'), findsOneWidget);
  });

  testWidgets('FL-10 變更期間後捲動 offset 歸零', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapMany()));
    final scrollable = find.descendant(
      of: _key('scroll-history-events'),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    await _tap(tester, 'option-history-period-all');
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
  });

  testWidgets('FL-11 重新整理後篩選值保留', (tester) async {
    final fake = await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    await _tap(tester, 'option-history-period-all');
    await _tap(tester, 'action-history-include-ticket-created');
    await _tap(tester, 'action-history-refresh');
    expect(fake.refreshCalls, 1);
    final c = historyContainer(tester);
    expect(c.read(historyPeriodChoiceProvider), PeriodChoice.allHistory);
    expect(c.read(historyIncludeTicketCreationProvider), isTrue);
  });
}
