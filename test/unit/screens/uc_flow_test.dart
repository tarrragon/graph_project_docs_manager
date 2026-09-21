// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）五個狀態的
// 渲染與退出路徑測試。
//
// 涵蓋：
//   專案未就緒    state-ucFlow-project-unready  EmptyState.page
//   無 UC        state-ucFlow-empty            EmptyState.page
//   尚未選定 UC   state-ucFlow-uc-unset         元件庫缺件（見 uc_flow_screen.dart 檔頭）
//   flow 未結構化 state-ucFlow-unstructured     元件庫缺件（同上）
//   正常         state-ucFlow-normal           元件庫缺件（同上）
//
// 後三態依 `0.1.0-W2-002` NeedsContext（`ListRow.option`／`TableRow.eventFlow`／
// `AppDataTable.appendix` 缺件）僅斷言狀態切換正確與 testKey 存在，不斷言
// SPEC-004 §3.6 元件型別（該三態尚未依規格組成）。
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
  group('專案未就緒 state-ucFlow-project-unready', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [graphBuiltProvider.overrideWithValue(false)],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'project-unready'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
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

  group('尚未選定 UC state-ucFlow-uc-unset（元件庫缺件，僅驗證狀態切換）', () {
    testWidgetsAtEachSize('選定 UC 為空時渲染狀態 testKey', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => null)],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'uc-unset'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });

  group('flow 未結構化 state-ucFlow-unstructured（元件庫缺件，僅驗證狀態切換）', () {
    testWidgetsAtEachSize('選定無 FlowStep 的 UC 時渲染狀態 testKey', (
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
      expectNoOverflow(tester);
    });
  });

  group('正常 state-ucFlow-normal（元件庫缺件，僅驗證狀態切換）', () {
    testWidgetsAtEachSize('選定含 FlowStep 的 UC 時渲染狀態 testKey', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [selectedUcProvider.overrideWith((ref) => 'UC-02')],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
