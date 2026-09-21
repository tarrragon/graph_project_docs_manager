// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）五個狀態的
// 渲染與退出路徑測試。
//
// 涵蓋：
//   專案未就緒    state-ucFlow-project-unready  EmptyState.page
//   無 UC        state-ucFlow-empty            EmptyState.page
//   尚未選定 UC   state-ucFlow-uc-unset         TwoColumnLayout + EmptyState.section + UC 選擇入口
//   flow 未結構化 state-ucFlow-unstructured     同上（簡化組成，見 uc_flow_screen.dart 檔頭）
//   正常         state-ucFlow-normal           TwoColumnLayout + AppDataTable（步驟表 + appendix 事件流小表）+ UC 選擇入口
//
// 三態依 `0.1.0-W2-010`（承接 `0.1.0-W2-002` NeedsContext，元件庫缺件已由
// `0.1.0-W3-634`／`0.1.0-W3-635` 補齊）依 SPEC-004 §3.6 §2 組成，本檔斷言
// 對應元件型別存在。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';

import '../../helpers/helpers.dart';

void main() {
  group('專案未就緒 state-ucFlow-project-unready（UcFlowProjectUnready）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [graphBuiltProvider.overrideWithValue(false)],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'project-unready'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('尚未進入 Domain 視圖'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-ucFlow-goto-domain → 切至 Domain 視圖', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          graphBuiltProvider.overrideWithValue(false),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.ucFlow,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-goto-domain')));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), AppDestination.ucFlow);
    });
  });

  group('無 UC state-ucFlow-empty', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [ucFlowUcListProvider.overrideWithValue(const [])],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'empty'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-ucFlow-goto-gaps → 切至破洞報告', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          ucFlowUcListProvider.overrideWithValue(const []),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.ucFlow,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-goto-gaps')));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.ucFlow);
    });
  });

  group('尚未選定 UC state-ucFlow-uc-unset（UcFlowUcUnset）', () {
    testWidgetsAtEachSize('渲染 TwoColumnLayout + EmptyState.section + UC 選擇入口', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => null)],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'uc-unset'), findsOneWidget);
      expect(find.byType(TwoColumnLayout), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('選擇一條 UC 以檢視 flow'), findsOneWidget);
      expect(find.byKey(const Key('panel-ucFlow-uc-selector')), findsOneWidget);
      expect(find.byType(ListRow), findsNWidgets(3));
      expectNoOverflow(tester);
    });

    testWidgets('選擇 UC → 切至正常態', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => null)],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-select-uc-UC-02')));
      await tester.pump();

      expect(container.read(selectedUcProvider), 'UC-02');
      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
    });
  });

  group('flow 未結構化 state-ucFlow-unstructured（UcFlowUnstructured）', () {
    testWidgetsAtEachSize('渲染 TwoColumnLayout + EmptyState.section + UC 選擇入口', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => 'UC-06')],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'unstructured'), findsOneWidget);
      expect(find.byType(TwoColumnLayout), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('尚未填寫結構化 flow'), findsOneWidget);
      expect(find.byKey(const Key('panel-ucFlow-uc-selector')), findsOneWidget);
      expect(
        find.byKey(const Key('action-ucFlow-select-uc-UC-06')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });

    testWidgets('選擇另一條含 FlowStep 的 UC → 切至正常態', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => 'UC-06')],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-select-uc-UC-04')));
      await tester.pump();

      expect(container.read(selectedUcProvider), 'UC-04');
      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
    });
  });

  group('正常 state-ucFlow-normal（UcFlowNormal）', () {
    testWidgetsAtEachSize(
      '渲染 TwoColumnLayout + 步驟表 + 事件流小表 + UC 選擇入口',
      (tester, size) async {
        await pumpHarness(
          tester,
          child: const UcFlowScreen(),
          overrides: [selectedUcProvider.overrideWith((ref) => 'UC-02')],
          size: size,
        );

        expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
        expect(find.byType(TwoColumnLayout), findsOneWidget);
        expect(find.byType(AppDataTable), findsNWidgets(2));
        expect(find.byType(StepNumber), findsNWidgets(3));
        expect(find.byType(RelationItem), findsNWidgets(3));
        expect(
          find.byKey(const Key('scroll-ucFlow-steps')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('panel-ucFlow-event-flow')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('panel-ucFlow-uc-selector')),
          findsOneWidget,
        );
        expectNoOverflow(tester);
      },
    );

    testWidgetsAtEachSize('本 UC 無事件時不渲染事件流小表', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => 'UC-04')],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
      expect(find.byType(AppDataTable), findsOneWidget);
      expect(
        find.byKey(const Key('panel-ucFlow-event-flow')),
        findsNothing,
      );
      expectNoOverflow(tester);
    });

    testWidgets('點 domain → 切至 Domain 視圖', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.ucFlow,
          ),
        ],
      );

      await tester.tap(
        find.byKey(const Key('action-ucFlow-goto-domain-UC-02-0')),
      );
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), AppDestination.ucFlow);
    });
  });
}
