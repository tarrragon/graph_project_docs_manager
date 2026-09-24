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
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
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

    testWidgets(
      'action-domain-select-<domainId> 點列首 → selectedDomainId 改變，'
      '與矩陣模式共用同一選中值',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            domainViewStateProvider.overrideWith(
              (ref) => const DomainReady(mode: DomainMode.swimlane),
            ),
            selectedUcProvider.overrideWith((ref) => 'UC-02'),
          ],
        );

        var state = container.read(domainViewStateProvider) as DomainReady;
        expect(state.selectedDomainId, isNull);

        await tester.tap(find.byKey(const Key('action-domain-select-graph')));
        await tester.pumpAndSettle();

        state = container.read(domainViewStateProvider) as DomainReady;
        expect(state.selectedDomainId, 'graph');

        // 矩陣與泳道共用同一 domainViewStateProvider：模式切換不重置
        // selectedDomainId（頁首 SegmentedControl 由 lib/app/shell.dart 接線，
        // 不在 DomainViewScreen 樹內，此處直接切換 mode 驗證同一 provider
        // 承載的值不因模式切換清除）。
        container.read(domainViewStateProvider.notifier).state = state
            .copyWith(mode: DomainMode.matrix);
        await tester.pumpAndSettle();

        state = container.read(domainViewStateProvider) as DomainReady;
        expect(state.mode, DomainMode.matrix);
        expect(state.selectedDomainId, 'graph');
      },
    );
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
      // EmptyState 存在：與「空圖」等其他 EmptyState.page 狀態共用型別，
      // 鑑別力來自 SwimlaneGrid 同時存在（下一行）——僅 EmptyState 本身
      // 不足以區分此狀態與其他 EmptyState 狀態。
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(find.byType(SwimlaneNode), findsNothing);
      // BadgeRow.legend 不存在：SPEC-004 §3.6 §1 明訂「不渲染
      // BadgeRow.legend（無節點可圖例）」，此為與「正常 · 泳道」狀態
      // （同樣渲染 SwimlaneGrid，但額外渲染 BadgeRow.legend）的鑑別點。
      expect(find.byType(BadgeRow), findsNothing);
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
      // EmptyState 存在 + SwimlaneGrid 不存在：兩者合看才有鑑別力——
      // 「泳道 · 尚未選定 UC」同樣有 EmptyState 但 SwimlaneGrid 存在，
      // 「正常 · 泳道」則兩者相反（無 EmptyState、有 SwimlaneGrid）。
      expect(find.byType(EmptyState), findsOneWidget);
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

        // 寫入端接線（0.1.0-W2-014）：觸發降級檢視時，app 層旗標與版本
        // 文字須同步寫入——此斷言在寫入端未接線時應翻紅（旗標維持預設
        // 值 false / null）。
        expect(container.read(degradedSchemaProvider), isTrue);
        final versions = container.read(degradedSchemaVersionsProvider);
        expect(versions, isNotNull);
        expect(versions!.projectVersion, '0.0.3');
        expect(versions.builtinVersion, isNotEmpty);
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

    testWidgets(
      '以現行 .claude/VERSION 實值驅動：高於內建資產版本時不提供降級出口'
      '（0.1.0-W2-012：防止只用遠低於門檻的 fixture 值掩蓋真實漂移）',
      (tester) async {
        final liveVersion = File(
          '.claude/VERSION',
        ).readAsStringSync().trim();

        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            domainViewStateProvider.overrideWith(
              (ref) => DomainSchemaUnconsumable(version: liveVersion),
            ),
          ],
        );

        // 本 repo 現行 .claude/VERSION 已高於內建資產版本
        // （assets/schema/builtin_schema_version.json，見同名 provider），
        // SPEC-001 §1／SPEC-003 §3.1 此時不提供降級出口。
        expect(
          find.byKey(const Key('action-domain-degraded-view')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('action-domain-switch-project')),
          findsOneWidget,
        );
      },
    );
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
      expect(find.text('App 已知版本範圍'), findsOneWidget);
      expect(find.text('不高於 2.60.1'), findsOneWidget);
      expect(find.text('App 支援版本'), findsNothing);
      expect(find.text('專案版本'), findsNothing);
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

  group('降級旗標寫入端真實執行路徑（0.1.0-W2-014）', () {
    testWidgets(
      '真實 App（非 degradedSchemaProvider override）：觸發降級檢視後'
      'badge-domain-degraded-schema 可見，徽章文字含兩個版本值',
      (tester) async {
        // 僅覆寫 domainViewStateProvider 以抵達「無可消費的型別表」列，
        // 與同檔其餘測試同一慣例；degradedSchemaProvider /
        // degradedSchemaVersionsProvider 完全不覆寫，走真實寫入路徑。
        await pumpApp(
          tester,
          overrides: [
            domainViewStateProvider.overrideWith(
              (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
            ),
          ],
        );

        expect(
          find.byKey(const Key('badge-domain-degraded-schema')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('action-domain-degraded-view')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('badge-domain-degraded-schema')),
          findsOneWidget,
        );

        final label = tester
            .widget<Badge>(find.byKey(const Key('badge-domain-degraded-schema')))
            .label;
        expect(label, contains('0.0.3'));
      },
    );
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
