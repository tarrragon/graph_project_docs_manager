// 淺層標示與降級徽章為疊加旗標，不增加狀態（測試設計 §3.6）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../../helpers/history/history_screen_fixtures.dart';

final _l10n = AppLocalizationsZh();

Finder _key(String k) => find.byKey(Key(k));

const _shallowBadge = 'badge-history-shallow-clone';

HistoryScanSnapshot _shallowEmptyDefault() {
  final base = snapEmptyDefault();
  return HistoryScanSnapshot(
    key: base.key,
    events: base.events,
    mainline: base.mainline,
    tags: base.tags,
    isShallow: true,
    isBuiltinTableDegraded: false,
    shallowBoundaryDate: DateTime.utc(2026, 10, 1),
  );
}

void main() {
  testWidgets('OV-1 淺層：標示可見、含邊界日期、位於清單上方、不可點', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapShallow()));
    expect(_key(_shallowBadge), findsOneWidget);
    expect(
      find.text(_l10n.historyShallowCloneBadge('2026-10-01')),
      findsOneWidget,
    );
    final badgeTop = tester.getTopLeft(_key(_shallowBadge)).dy;
    final listTop = tester.getTopLeft(_key('scroll-history-events')).dy;
    expect(badgeTop, lessThan(listTop));
    expect(
      find.descendant(
        of: _key(_shallowBadge),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testWidgets('OV-2 淺層且結果為空：空狀態內同一標示可見', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(_shallowEmptyDefault()));
    expect(_key('state-history-empty'), findsOneWidget);
    expect(_key(_shallowBadge), findsOneWidget);
  });

  testWidgets('OV-3（對照）非淺層：無標示', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_key(_shallowBadge), findsNothing);
  });

  testWidgets('OV-4 非結果狀態：無標示', (tester) async {
    for (final state in <HistoryViewState>[
      const HistoryLoading(),
      const HistoryNotGitRepo(),
      const HistoryGitNotFound(),
      const HistoryFailed(GitFailureReason.scanNonZeroExit),
      const HistoryCancelled(),
      const HistorySchemaBlocked(),
    ]) {
      await pumpHistoryApp(tester, state, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_key(_shallowBadge), findsNothing, reason: '${state.runtimeType}');
    }
  });

  testWidgets('OV-5 淺層不增加狀態：恰一個狀態根且為正常', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapShallow()));
    final roots = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('state-history-'),
    );
    expect(roots, findsOneWidget);
    expect(_key('state-history-normal'), findsOneWidget);
  });

  testWidgets('OV-6 降級：殼層徽章可見；未降級時不存在', (tester) async {
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapDegraded()),
      extra: [
        degradedSchemaProvider.overrideWithInitial((ref) => true),
        degradedSchemaVersionsProvider.overrideWithInitial(
          (ref) => const DegradedSchemaVersions(
            builtinVersion: '0.0.1',
            projectVersion: '0.0.3',
          ),
        ),
      ],
    );
    expect(_key('badge-history-degraded-schema'), findsOneWidget);
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_key('badge-history-degraded-schema'), findsNothing);
  });
}
