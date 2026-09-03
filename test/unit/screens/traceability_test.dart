// 追溯視圖（SPEC-001 §3；SPEC-003 §3.3）三個狀態的渲染與退出路徑測試。
//
// 涵蓋：
//   正常      state-traceability-normal      Panel.scrollable[Tree[ListRow.tree]]
//   鏈路斷裂  state-traceability-broken       同上，缺口列 IssueMarker.gap
//   無提案    state-traceability-no-proposal  EmptyState.page
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_fixtures.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_providers.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_screen.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_state.dart';

import '../../helpers/helpers.dart';

void main() {
  group('正常態 state-traceability-normal', () {
    testWidgetsAtEachSize('渲染 Panel.scrollable[Tree[ListRow.tree]]',
        (tester, size) async {
      await pumpHarness(tester, child: const TraceabilityScreen(), size: size);

      expect(AnchorFinder.state(Screen.traceability, 'normal'), findsOneWidget);
      expect(find.byType(Panel), findsOneWidget);
      expect(find.byType(Tree), findsOneWidget);
      expect(find.byType(ListRow), findsWidgets);
      expectNoOverflow(tester);
    });

    testWidgets('展開 PROP-001 後子層 SPEC-001 列出現', (tester) async {
      await pumpHarness(tester, child: const TraceabilityScreen());

      expect(find.byKey(const Key('card-traceability-SPEC-001')), findsNothing);

      await tester.tap(find.byKey(const Key('expander-traceability-PROP-001')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('card-traceability-SPEC-001')),
        findsOneWidget,
      );
    });

    testWidgets('card-traceability-<id> → jump 至節點詳情，returnTo 設為 traceability',
        (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.traceability,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('card-traceability-PROP-001')));
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.nodeDetail,
      );
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });

  group('鏈路斷裂態 state-traceability-broken', () {
    testWidgetsAtEachSize('缺口列 trailing 顯示 IssueMarker.gap',
        (tester, size) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityBroken(TraceabilityFixtures.broken),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.traceability, 'broken'), findsOneWidget);
      expect(find.byType(IssueMarker), findsOneWidget);
      expect(
        find.byKey(const Key('badge-traceability-broken-spec')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });

    testWidgets(
        'badge-traceability-broken-<layer> → jump 至破洞報告，returnTo 設為 traceability',
        (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityBroken(TraceabilityFixtures.broken),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.traceability,
          ),
        ],
      );

      await tester.tap(
        find.byKey(const Key('badge-traceability-broken-spec')),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });

  group('無提案態 state-traceability-no-proposal', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityNoProposal(),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.traceability, 'no-proposal'),
        findsOneWidget,
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets(
        'action-traceability-goto-gaps → jump 至破洞報告，returnTo 設為 traceability',
        (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityNoProposal(),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.traceability,
          ),
        ],
      );

      await tester.tap(
        find.byKey(const Key('action-traceability-goto-gaps')),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });
}
