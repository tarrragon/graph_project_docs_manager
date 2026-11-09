/// 實機字型版面斷言（0.5.0-W1-465.2）。
///
/// 以實機系統字型重跑 widget test 既有的 `expectNoOverflow` 與
/// `expectNoVerticalClip`，補上「容器高度介於測試字型與實機字型固有高度之間」
/// 的缺口。預期值出處：尺寸集合 SPEC-004 §1「測試尺寸集合」（`WindowSize`）、
/// 六畫面 SPEC-004 §3 AppShell「NavItem x 6」（`AppDestination.values`）、
/// 不溢位 SPEC-004 §1「縮放策略」。
///
/// 單獨執行：`fvm flutter test integration_test/real_font_layout_test.dart -d macos`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_fixtures.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_providers.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_state.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../test/helpers/history/history_screen_fixtures.dart';
import '../test/helpers/pump_harness.dart';
import '../test/helpers/window_sizes.dart';
import 'domain_view_v050.dart'
    show ensureItBinding, pumpWidgetGuarded, settleGuarded;
import 'research/ux_variants.dart';

/// 元件 -> 其固定高度容器內的內容節點 finder（對照 test/unit/components）。
final Map<String, Finder Function(Finder host)> _contentOf = {
  'NavItem': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'SearchField': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'FilterDropdown': (h) => find.descendant(of: h, matching: find.byType(Row)),
  'ProjectSwitcherEntry': (h) =>
      find.descendant(of: h, matching: find.byType(Row)),
  'SegmentedControl': (h) =>
      find.descendant(of: h, matching: find.byType(Text)),
};

Finder _hosts(String name) => switch (name) {
  'NavItem' => find.byType(NavItem),
  'SearchField' => find.byType(SearchField),
  'FilterDropdown' => find.byType(FilterDropdown),
  'ProjectSwitcherEntry' => find.byType(ProjectSwitcherEntry),
  _ => find.byType(SegmentedControl),
};

/// 各畫面的就緒狀態根節點 key。出處：SPEC-003 畫面狀態矩陣（SPEC-001
/// 狀態定義）各畫面的正常／有內容列：domain=`state-domain-matrix`、
/// ucFlow=`state-ucFlow-normal`、traceability=`state-traceability-normal`、
/// tickets=`state-tickets-list`、gaps=`state-gaps-found`、
/// nodeDetail=`state-nodeDetail-normal`。畫面沒到位時斷言紅燈，不靜默略過。
const Map<AppDestination, String> _readyKey = {
  AppDestination.domain: 'state-domain-matrix',
  AppDestination.ucFlow: 'state-ucFlow-normal',
  AppDestination.traceability: 'state-traceability-normal',
  AppDestination.tickets: 'state-tickets-list',
  AppDestination.gaps: 'state-gaps-found',
  AppDestination.nodeDetail: 'state-nodeDetail-normal',
  AppDestination.history: 'state-history-normal',
};

// i18n-exempt: 版面測試用固定票列資料值
const List<TicketFixtureItem> _fixtureTickets = [
  TicketFixtureItem(
    id: '0.1.0-W1-002',
    title: '建立六項導覽的路由殼',
    status: 'completed',
    priority: 'P1',
    topic: 'shell',
  ),
  TicketFixtureItem(
    id: '0.1.0-W2-002',
    title: '實作破洞報告畫面',
    status: 'in_progress',
    priority: 'P1',
    blockedBy: ['0.1.0-W1-002'],
    topic: 'screens',
  ),
  TicketFixtureItem(
    id: '0.1.0-W3-076',
    title: '回填四軸追溯矩陣現況',
    status: 'pending',
    priority: 'P2',
  ),
  TicketFixtureItem(
    id: '0.25.0-W1-010',
    title: '0.25.0-W1-010.md',
    corrupted: true,
  ),
];

void main() {
  ensureItBinding();

  for (final destination in AppDestination.values) {
    for (final size in WindowSize.values) {
      testWidgets('實機字型 ${destination.name} @ ${size.label}', (tester) async {
        final fixture = UxFixture(
          snapshot: 'graph_project_docs_manager',
          locale: const Locale('zh'),
        );
        await fixture.materialize();
        addTearDown(fixture.dispose);
        setWindowSize(tester, size);
        await pumpWidgetGuarded(
          tester,
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              ...await fixtureOverrides(),
              if (destination != AppDestination.domain)
                selectedDestinationProvider.overrideWithInitial(
                  (ref) => destination,
                ),
              if (destination == AppDestination.ucFlow)
                selectedUcProvider.overrideWithInitial((ref) => 'UC-04'),
              if (destination == AppDestination.nodeDetail)
                nodeDetailStateProvider.overrideWithInitial(
                  (ref) => const NodeDetailReady(nodeId: 'UC-04'),
                ),
              if (destination == AppDestination.traceability)
                traceabilityStateProvider.overrideWithInitial(
                  (ref) =>
                      const TraceabilityNormal(TraceabilityFixtures.normal),
                ),
              // fixture 工作區不是 git 工作樹，history 不會自然進入 normal，
              // 固定為有事件的結果（比照 tickets、traceability）。
              if (destination == AppDestination.history)
                historyProvider.overrideWith(
                  () => FakeHistoryNotifier(HistoryLoaded(snapTagged())),
                ),
              if (destination == AppDestination.tickets)
                ticketListStateProvider.overrideWithInitial(
                  (ref) => const TicketsReady(tickets: _fixtureTickets),
                ),
            ],
            child: DocsManagerApp(
              locale: fixture.locale,
              repository: UxStubRepository(
                WorkspaceReady(fixture.workspace.path),
              ),
            ),
          ),
          '${destination.name} @ ${size.label} pumpWidget',
        );
        await settleGuarded(
          tester,
          '${destination.name} @ ${size.label} settle',
          timeout: const Duration(seconds: 30),
        );

        expectNoOverflow(tester);
        expect(
          find.byKey(Key(_readyKey[destination]!)),
          findsOneWidget,
          reason: '${destination.name} 未到達就緒狀態 ${_readyKey[destination]}',
        );
        final counts = <String, int>{};
        for (final name in _contentOf.keys) {
          final hosts = _hosts(name).evaluate().length;
          var checked = 0;
          for (var i = 0; i < hosts; i++) {
            final content = _contentOf[name]!(_hosts(name).at(i));
            for (var j = 0; j < content.evaluate().length; j++) {
              expectNoVerticalClip(tester, content.at(j));
              checked++;
            }
          }
          counts[name] = checked;
        }
        // ignore: avoid_print
        print('REAL_FONT_NODES ${destination.name} ${size.label} $counts');
        expect(counts['NavItem'], greaterThan(0), reason: '導覽殼必有 NavItem');
        if (destination == AppDestination.tickets) {
          expect(counts['SearchField'], greaterThan(0));
          expect(counts['FilterDropdown'], greaterThan(0));
        }
      });
    }
  }

  testWidgets('正向對照：固定高度小於內容固有高度時 expectNoVerticalClip 紅燈', (tester) async {
    await pumpWidgetGuarded(
      tester,
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 4,
            child: Row(
              children: [Text('測試 Ag', style: TextStyle(fontSize: 40))],
            ),
          ),
        ),
      ),
      '正向對照 pumpWidget',
    );
    tester.takeException();
    expect(
      () => expectNoVerticalClip(tester, find.byType(Text)),
      throwsA(isA<TestFailure>()),
    );
  });
}
