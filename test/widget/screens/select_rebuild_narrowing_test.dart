// 需求：0.6.0-W1-198；五處整值 watch 改為 select（Ticket 清單 _ReadyListView／
// _ReadyTopicView、Domain 視圖頂層／_MatrixBody／_SwimlaneBody、
// domainSwimlaneProvider）。
// E1 對照：改動「沒用到的欄位」時不重建；改動「用到的欄位」時重建。
// 以 debugOnRebuildDirtyWidget 依 widget 型別計重建次數。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

const _tickets = [
  TicketFixtureItem(
    id: 'T-1',
    title: 'Alpha',
    status: 'pending',
    priority: 'P1',
  ),
];

final _rebuilds = <String, int>{};

void _startCounting() {
  _rebuilds.clear();
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final name = element.widget.runtimeType.toString();
    _rebuilds[name] = (_rebuilds[name] ?? 0) + 1;
  };
}

int _count(String type) => _rebuilds[type] ?? 0;

void main() {
  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<ProviderContainer> pumpTickets(
    WidgetTester tester,
    TicketsReady initial,
  ) async {
    await pumpHarness(
      tester,
      child: const TicketListScreen(),
      overrides: [
        ticketListStateProvider.overrideWithInitial((ref) => initial),
      ],
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(TicketListScreen)),
    );
  }

  void writeTickets(
    ProviderContainer c,
    TicketsReady Function(TicketsReady) f,
  ) {
    c.read(ticketListStateProvider.notifier).state = f(
      c.read(ticketListStateProvider) as TicketsReady,
    );
  }

  group('_ReadyListView', () {
    testWidgets('改 expandedTopics（未用）不重建；改 searchQuery（用到）重建', (tester) async {
      final c = await pumpTickets(
        tester,
        const TicketsReady(tickets: _tickets),
      );
      _startCounting();
      writeTickets(c, (s) => s.copyWith(expandedTopics: {'a'}));
      await tester.pump();
      expect(_count('_ReadyListView'), 0);

      writeTickets(c, (s) => s.copyWith(searchQuery: 'x'));
      await tester.pump();
      expect(_count('_ReadyListView'), 1);
    });
  });

  group('_ReadyTopicView', () {
    testWidgets('改 searchQuery（未用）不重建；改 expandedTopics（用到）重建', (tester) async {
      final c = await pumpTickets(
        tester,
        const TicketsReady(tickets: _tickets, mode: TicketListMode.topic),
      );
      _startCounting();
      writeTickets(c, (s) => s.copyWith(searchQuery: 'x'));
      await tester.pump();
      expect(_count('_ReadyTopicView'), 0);

      writeTickets(c, (s) => s.copyWith(expandedTopics: {'unassigned'}));
      await tester.pump();
      expect(_count('_ReadyTopicView'), 1);
    });
  });

  group('Domain 視圖', () {
    late ScanRoundResult round;

    setUpAll(() async {
      round = fakeRound(
        event: await loadSnapshotEvent('graph_project_docs_manager'),
      );
    });

    Future<(FakeScanRound, ProviderContainer)> pumpDomain(
      WidgetTester tester,
      DomainReady initial,
    ) async {
      final fake = FakeScanRound(produce: () => round, initial: round);
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          scanRoundProvider.overrideWith(() => fake),
          domainViewStateProvider.overrideWithInitial((ref) => initial),
        ],
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(DomainViewScreen)),
      );
      c.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/a');
      fake.completeExternally(round);
      await tester.pump();
      return (fake, c);
    }

    void writeDomain(ProviderContainer c, DomainReady Function(DomainReady) f) {
      c.read(domainViewStateProvider.notifier).state = f(
        c.read(domainViewStateProvider) as DomainReady,
      );
    }

    testWidgets('頂層與 _ReadyBody：改 selectedDomainId／isDegraded 不重建', (
      tester,
    ) async {
      final (_, c) = await pumpDomain(
        tester,
        const DomainReady(mode: DomainMode.matrix),
      );
      _startCounting();
      writeDomain(c, (s) => s.copyWith(selectedDomainId: () => 'schema'));
      await tester.pump();
      writeDomain(c, (s) => s.copyWith(isDegraded: true));
      await tester.pump();
      expect(_count('DomainViewScreen'), 0);
      expect(_count('_ReadyBody'), 0);
    });

    testWidgets('頂層：切到非 Ready 態（用到）重建', (tester) async {
      final (_, c) = await pumpDomain(
        tester,
        const DomainReady(mode: DomainMode.matrix),
      );
      _startCounting();
      c.read(domainViewStateProvider.notifier).state = const DomainEmpty();
      await tester.pump();
      expect(_count('DomainViewScreen'), 1);
    });

    testWidgets('_MatrixBody：改 isDegraded（未用）不重建；改 selectedDomainId 重建', (
      tester,
    ) async {
      final (_, c) = await pumpDomain(
        tester,
        const DomainReady(mode: DomainMode.matrix),
      );
      _startCounting();
      writeDomain(c, (s) => s.copyWith(isDegraded: true));
      await tester.pump();
      expect(_count('_MatrixBody'), 0);

      writeDomain(c, (s) => s.copyWith(selectedDomainId: () => 'schema'));
      await tester.pump();
      expect(_count('_MatrixBody'), 1);
    });

    testWidgets('_SwimlaneBody：改 isDegraded（未用）不重建；改 selectedDomainId 重建', (
      tester,
    ) async {
      final (_, c) = await pumpDomain(
        tester,
        const DomainReady(mode: DomainMode.swimlane),
      );
      _startCounting();
      writeDomain(c, (s) => s.copyWith(isDegraded: true));
      await tester.pump();
      expect(_count('_SwimlaneBody'), 0);

      writeDomain(c, (s) => s.copyWith(selectedDomainId: () => 'schema'));
      await tester.pump();
      expect(_count('_SwimlaneBody'), 1);
    });

    testWidgets('domainSwimlaneProvider：輪次的 isDegraded（未用）不重算；換建圖事件重算', (
      tester,
    ) async {
      final (fake, c) = await pumpDomain(
        tester,
        const DomainReady(mode: DomainMode.swimlane),
      );
      c.read(selectedUcProvider.notifier).state = 'UC-04';
      await tester.pump();
      var recomputed = 0;
      c.listen(domainSwimlaneProvider, (_, _) => recomputed++);

      fake.completeExternally(
        ScanRoundResult(
          workspacePath: round.workspacePath,
          scan: round.scan,
          graph: round.graph,
          schemaResolution: round.schemaResolution,
          isDegraded: !round.isDegraded,
        ),
      );
      await tester.pump();
      expect(recomputed, 0);

      fake.completeExternally(fakeRound());
      await tester.pump();
      expect(recomputed, 1);
    });
  });
}
