// 追溯視圖（SPEC-001 §3；SPEC-003 §3.3）四個狀態的渲染與退出路徑測試。
//
// 涵蓋：
//   專案未就緒 state-traceability-project-unready  EmptyState.page
//   正常      state-traceability-normal      Panel.scrollable[Tree[ListRow.tree]]
//   鏈路斷裂  state-traceability-broken       同上，缺口列 IssueMarker.gap
//   無提案    state-traceability-empty       EmptyState.page
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
      // 3 個缺口：PROP-005、PROP-006（根節點自身即缺口）與 SPEC-007
      // （巢狀於 PROP-007 之下，展開集合初始值自動展開至缺口層才可見，
      // SPEC-003 §3.3〈生命週期〉「展開集合初始值」）。
      expect(find.byType(IssueMarker), findsNWidgets(3));
      expect(
        find.byKey(const Key('badge-traceability-broken-PROP-005')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('badge-traceability-broken-PROP-006')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('badge-traceability-broken-SPEC-007')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });

    testWidgets(
        '展開集合初始值：不含缺口的 PROP-001 分支維持收合，'
        '含缺口的 PROP-007 分支自動展開至缺口層', (tester) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityBroken(TraceabilityFixtures.broken),
          ),
        ],
      );

      expect(find.byKey(const Key('card-traceability-SPEC-001')), findsNothing);
      expect(
        find.byKey(const Key('card-traceability-SPEC-007')),
        findsOneWidget,
      );
    });

    testWidgets(
        'badge-traceability-broken-<nodeId> → jump 至破洞報告，returnTo 設為 traceability',
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
        find.byKey(const Key('badge-traceability-broken-PROP-005')),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.traceability);
    });

    testWidgets('多父節點各自獨立 key，第二個缺口列亦可觸發跳轉', (tester) async {
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
        find.byKey(const Key('badge-traceability-broken-PROP-006')),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });

  group('專案未就緒態 state-traceability-project-unready', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityProjectUnready(
              ProjectUnreadyReason.notSelected,
            ),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.traceability, 'project-unready'),
        findsOneWidget,
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets(
        'action-traceability-goto-domain → jump 至 Domain 視圖，'
        'returnTo 設為 traceability', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityProjectUnready(
              ProjectUnreadyReason.loading,
            ),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.traceability,
          ),
        ],
      );

      await tester.tap(
        find.byKey(const Key('action-traceability-goto-domain')),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.domain);
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });

  group('前往 Ticket 清單 action-traceability-goto-tickets', () {
    testWidgets('Ticket 未載入時（預設）渲染該動作', (tester) async {
      await pumpHarness(tester, child: const TraceabilityScreen());

      expect(
        find.byKey(const Key('action-traceability-goto-tickets')),
        findsOneWidget,
      );
    });

    testWidgets('Ticket 已載入時不渲染該動作（正向對照）', (tester) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          ticketsLoadedProvider.overrideWith((ref) => true),
        ],
      );

      expect(
        find.byKey(const Key('action-traceability-goto-tickets')),
        findsNothing,
      );
    });

    testWidgets('點擊 → jump 至 Ticket 清單，returnTo 設為 traceability',
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

      await tester.tap(
        find.byKey(const Key('action-traceability-goto-tickets')),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.tickets,
      );
      expect(container.read(returnToProvider), AppDestination.traceability);
    });
  });

  group('展開集合切換專案重設（0.1.0-W3-335.38 S-28）', () {
    testWidgets('狀態改變（模擬切換專案）後展開集合重新計算為初始值',
        (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) => const TraceabilityBroken(TraceabilityFixtures.broken),
          ),
        ],
      );

      // 手動展開 PROP-001（不含缺口分支，非初始展開集合成員）。
      await tester.tap(find.byKey(const Key('expander-traceability-PROP-001')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card-traceability-SPEC-001')), findsOneWidget);

      // 模擬切換專案：狀態改回正常態（新的樹），展開集合應重設為該態
      // 的初始值（正常態無缺口，故全部收合）。
      container.read(traceabilityStateProvider.notifier).state =
          const TraceabilityNormal(TraceabilityFixtures.normal);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card-traceability-SPEC-001')), findsNothing);
    });
  });

  group('多父節點（SPEC-003 §3.3〈多父節點〉，0.1.0-W3-383）', () {
    /// 找出 `card-traceability-<rootId>` 所在節點自身的子樹容器（`_buildNode`
    /// 為非葉節點回傳的 `Column`），供後續 `find.descendant` 依出現位置
    /// 區分特定實例（AC3：斷言以祖先限定 finder，不使用 findsOneWidget）。
    Finder rootSubtree(String rootId) => find
        .ancestor(
          of: find.byKey(Key('card-traceability-$rootId')),
          matching: find.byType(Column),
        )
        .first;

    testWidgets('展開集合共用：展開 PROP-008 下的 SPEC-008 後，'
        'PROP-009 下的 SPEC-008 亦已展開（無需再次點擊，E1 對照）', (tester) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) =>
                const TraceabilityBroken(TraceabilityFixtures.multiParent),
          ),
        ],
      );

      // 展開 PROP-008，露出其下的 SPEC-008（此時 SPEC-008 只有一個實例，
      // PROP-009 分支仍收合）。
      await tester.tap(find.byKey(const Key('expander-traceability-PROP-008')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('expander-traceability-SPEC-008')),
        findsOneWidget,
      );

      // 展開 SPEC-008（PROP-008 分支），露出 UC-08。
      await tester.tap(find.byKey(const Key('expander-traceability-SPEC-008')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: rootSubtree('PROP-008'),
          matching: find.byKey(const Key('card-traceability-UC-08')),
        ),
        findsOneWidget,
      );

      // 對照：展開 PROP-009（另一出現位置），其下的 SPEC-008 應已是展開
      // 狀態（未對 PROP-009 分支的 SPEC-008 額外點擊），UC-08 直接可見——
      // 證明展開集合以節點 ID 為鍵、跨出現位置共用（SPEC-004 4.39）。
      await tester.tap(find.byKey(const Key('expander-traceability-PROP-009')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: rootSubtree('PROP-009'),
          matching: find.byKey(const Key('card-traceability-UC-08')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('缺口標示按出現位置各自渲染：PROP-010／PROP-011 下的 '
        'SPEC-009 各有獨立的 badge-traceability-broken-SPEC-009', (tester) async {
      await pumpHarness(
        tester,
        child: const TraceabilityScreen(),
        overrides: [
          traceabilityStateProvider.overrideWith(
            (ref) =>
                const TraceabilityBroken(TraceabilityFixtures.multiParent),
          ),
        ],
      );

      // 缺口分支依「展開集合初始值」規則自動展開至缺口所在層，兩個
      // 出現位置皆不需手動點擊即可見（SPEC-003 §3.3〈生命週期〉）。
      expect(
        find.byKey(const Key('badge-traceability-broken-SPEC-009')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: rootSubtree('PROP-010'),
          matching:
              find.byKey(const Key('badge-traceability-broken-SPEC-009')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rootSubtree('PROP-011'),
          matching:
              find.byKey(const Key('badge-traceability-broken-SPEC-009')),
        ),
        findsOneWidget,
      );
    });
  });

  group('無提案態 state-traceability-empty', () {
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
        AnchorFinder.state(Screen.traceability, 'empty'),
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
