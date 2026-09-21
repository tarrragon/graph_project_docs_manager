// Domain 視圖（SPEC-001 §1；SPEC-003 §3.1；SPEC-004 §3.6）十一個狀態的
// 渲染與退出路徑測試。
//
// 涵蓋：
//   未選專案                  state-domain-unset                  EmptyState.page
//   載入中                    state-domain-loading                LoadingState.skeleton
//   正常 · 矩陣                state-domain-matrix                 TwoColumnLayout[Panel[MatrixGrid,...],...]
//   已選格（疊加）              panel-domain-cell-detail            右欄詳情卡
//   正常 · 泳道                state-domain-swimlane               Panel[...,SwimlaneGrid,...]
//   泳道 · 尚未選定 UC          state-domain-swimlane-uc-unset      EmptyState.section
//   泳道 · flow 未結構化        state-domain-swimlane-unstructured  EmptyState.section
//   空圖                      state-domain-empty                  EmptyState.page
//   不是框架專案                state-domain-not-framework          BlockedState.plain
//   無可消費的型別表            state-domain-schema-unconsumable    BlockedState.plain
//   schema 不相容               state-domain-schema-incompatible    BlockedState.withDetail
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_fixtures.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  group('未選專案 state-domain-unset', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-choose-folder → 進入載入中', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
        ],
      );

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pump();

      expect(container.read(domainViewStateProvider), isA<DomainLoading>());
    });
  });

  group('載入中 state-domain-loading', () {
    testWidgetsAtEachSize('渲染 LoadingState.skeleton', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainLoading()),
        ],
        size: size,
        settle: false,
      );

      expect(AnchorFinder.state(Screen.domain, 'loading'), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-cancel-load → 回到未選專案', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainLoading()),
        ],
        settle: false,
      );

      await tester.tap(find.byKey(const Key('action-domain-cancel-load')));
      await tester.pump();

      expect(container.read(domainViewStateProvider), isA<DomainUnset>());
    });
  });

  group('正常 · 矩陣 state-domain-matrix', () {
    testWidgetsAtEachSize(
      '渲染 TwoColumnLayout[Panel[MatrixGrid, BadgeRow.legend], '
      'Panel.scrollable[EmptyState.section]]',
      (tester, size) async {
        await pumpHarness(tester, child: const DomainViewScreen(), size: size);

        expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
        expect(find.byType(TwoColumnLayout), findsOneWidget);
        expect(find.byType(Panel), findsWidgets);
        expect(find.byType(MatrixGrid), findsOneWidget);
        expect(find.byType(BadgeRow), findsWidgets);
        expect(
          find.byKey(const Key('panel-domain-cell-detail-empty')),
          findsOneWidget,
        );
        expectNoOverflow(tester);
      },
    );

    testWidgets('點格子 → 已選格出現，panel-domain-cell-detail 內容正確', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);
      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsNothing,
      );
      // 三區塊皆有：說明 + 8 個編號步驟 + 事件標籤。
      expect(find.byType(ListRow), findsNWidgets(8));
      expect(find.byType(Badge), findsWidgets);
      expect(container.read(selectedUcProvider), 'UC-02');
    });

    testWidgets('已選格「無關」格顯示 cellDetailNotInvolved，不渲染步驟', (tester) async {
      await pumpHarness(tester, child: const DomainViewScreen());

      await tester.tap(find.byKey(const Key('cell-domain-schema-UC-02')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
    });

    testWidgets('action-domain-cell-clear → 回到未選格', (tester) async {
      await pumpHarness(tester, child: const DomainViewScreen());

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action-domain-cell-clear')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('panel-domain-cell-detail')), findsNothing);
    });

    testWidgets('Esc 清除選取（同 action-domain-cell-clear 效果）', (tester) async {
      await pumpHarness(tester, child: const DomainViewScreen());

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
    });

    testWidgets('換選另一格 → 詳情卡內容替換', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cell-domain-schema-UC-04')));
      await tester.pumpAndSettle();

      final state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, ('schema', 'UC-04'));
      expect(container.read(selectedUcProvider), 'UC-04');
    });

    testWidgets('action-domain-select-<domainId> 選不同列 → 選格清除，'
        '同列則保留', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();

      // 同一列（workspace）列首：選格不變。
      await tester.tap(find.byKey(const Key('action-domain-select-workspace')));
      await tester.pumpAndSettle();
      var state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, ('workspace', 'UC-02'));

      // 不同列（graph）列首：選格清除。
      await tester.tap(find.byKey(const Key('action-domain-select-graph')));
      await tester.pumpAndSettle();
      state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, isNull);
      expect(state.selectedDomainId, 'graph');
      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
    });

    testWidgets('action-domain-cell-goto-swimlane → 切至正常 · 泳道', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('action-domain-cell-goto-swimlane')),
      );
      await tester.pumpAndSettle();

      final state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.mode, DomainMode.swimlane);
      expect(state.selectedCell, ('workspace', 'UC-02'));
      expect(AnchorFinder.state(Screen.domain, 'swimlane'), findsOneWidget);
    });
  });

  group('正常 · 泳道 state-domain-swimlane', () {
    testWidgetsAtEachSize('渲染 Panel[AppText.subtitle, SwimlaneGrid, '
        'BadgeRow.legend]，節點所屬列依 traverses', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainReady(mode: DomainMode.swimlane),
          ),
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'swimlane'), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(
        find.byType(SwimlaneNode),
        findsNWidgets(10),
      ); // 8（workspace）+2（graph）
      expect(find.byType(BadgeRow), findsWidgets);
      expectNoOverflow(tester);
    });
  });

  group('泳道 · 尚未選定 UC state-domain-swimlane-uc-unset', () {
    testWidgetsAtEachSize('渲染 EmptyState.section + 0 節點的 SwimlaneGrid', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainReady(mode: DomainMode.swimlane),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-uc-unset'),
        findsOneWidget,
      );
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(find.byType(SwimlaneNode), findsNothing);
      expectNoOverflow(tester);
    });
  });

  group('泳道 · flow 未結構化 state-domain-swimlane-unstructured', () {
    testWidgetsAtEachSize('渲染 EmptyState.section，不渲染 SwimlaneGrid', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainReady(mode: DomainMode.swimlane),
          ),
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-unstructured'),
        findsOneWidget,
      );
      expect(find.byType(SwimlaneGrid), findsNothing);
      expectNoOverflow(tester);
    });
  });

  group('空圖 state-domain-empty', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'empty'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-goto-gaps → jump 至破洞報告', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.domain,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-domain-goto-gaps')));
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.domain);
    });

    testWidgets('docs 目錄不存在時不渲染 action-domain-open-docs（正向對照）', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainEmpty(docsDirExists: false),
          ),
        ],
      );

      expect(find.byKey(const Key('action-domain-open-docs')), findsNothing);
    });
  });

  group('不是框架專案 state-domain-not-framework', () {
    testWidgetsAtEachSize('渲染 BlockedState.plain', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainNotFramework(),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'not-framework'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-switch-project → 開啟切換浮層', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainNotFramework(),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-domain-switch-project')));
      await tester.pump();

      expect(container.read(switcherOpenProvider), isTrue);
    });
  });

  group('無可消費的型別表 state-domain-schema-unconsumable', () {
    testWidgetsAtEachSize('渲染 BlockedState.plain（版本值 slot）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'schema-unconsumable'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expect(find.text('0.0.3'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets(
      'VERSION 不高於內建型別表版本 → action-domain-degraded-view 按下後轉為降級檢視',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            domainViewStateProvider.overrideWith(
              (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
            ),
          ],
        );

        expect(
          find.byKey(const Key('action-domain-degraded-view')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('action-domain-degraded-view')),
        );
        await tester.pump();

        final state = container.read(domainViewStateProvider);
        expect(state, isA<DomainReady>());
        expect((state as DomainReady).isDegraded, isTrue);
        expect(
          AnchorFinder.state(Screen.domain, 'matrix'),
          findsOneWidget,
        );
      },
    );

    testWidgets('VERSION 高於內建型別表版本 → 不提供 action-domain-degraded-view', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '9.99.9'),
          ),
        ],
      );

      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('action-domain-switch-project')),
        findsOneWidget,
      );
    });
  });

  group('schema 不相容 state-domain-schema-incompatible', () {
    testWidgetsAtEachSize('渲染 BlockedState.withDetail', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaIncompatible(
              appVersion: '2.60.1',
              projectVersion: '9.99.9',
            ),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'schema-incompatible'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-schema-detail → 展開詳情面板', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaIncompatible(
              appVersion: '2.60.1',
              projectVersion: '9.99.9',
            ),
          ),
        ],
      );

      expect(find.byKey(const Key('panel-domain-schema-detail')), findsNothing);

      await tester.tap(find.byKey(const Key('action-domain-schema-detail')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-schema-detail')),
        findsOneWidget,
      );
    });
  });

  group('頁首模式切換（SplitRow.header 右格，lib/app/shell.dart 接線）', () {
    testWidgets('mode-domain-swimlane → 切至泳道；mode-domain-matrix → 切回矩陣', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('mode-domain-matrix')), findsOneWidget);
      expect(find.byKey(const Key('mode-domain-swimlane')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-domain-swimlane')));
      await tester.pumpAndSettle();
      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-uc-unset'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mode-domain-matrix')));
      await tester.pumpAndSettle();
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
    });

    testWidgets('未選專案等六列不渲染頁首模式切換（正向對照）', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
        ],
      );

      expect(find.byKey(const Key('mode-domain-matrix')), findsNothing);
      expect(find.byKey(const Key('mode-domain-swimlane')), findsNothing);
    });
  });

  group('假資料一致性（本票 acceptance 第四項）', () {
    test('矩陣列序與欄序為固定順序', () {
      expect(DomainViewFixtures.domainIds, [
        'workspace',
        'schema',
        'corpus',
        'graph',
      ]);
      expect(DomainViewFixtures.ucColumns.map((u) => u.id), [
        'UC-02',
        'UC-04',
        'UC-06',
      ]);
    });

    test('泳道節點所屬列依 FlowStep.traverses', () {
      final lanes = DomainViewFixtures.lanesForUc('UC-04');
      final graphLane = lanes.firstWhere((l) => l.domainId == 'graph');
      expect(graphLane.nodes.map((n) => n.column), [1, 2]);
      final workspaceLane = lanes.firstWhere((l) => l.domainId == 'workspace');
      expect(workspaceLane.nodes, isEmpty);
    });
  });
}
