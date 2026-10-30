// UC Flow 視圖（SPEC-001 §2；SPEC-003 §3.2；SPEC-004 §3.6）五個狀態的
// 渲染與退出路徑測試。
//
// 涵蓋：
//   專案未就緒    state-ucFlow-project-unready  EmptyState.page
//   無 UC        state-ucFlow-empty            EmptyState.page
//   尚未選定 UC   state-ucFlow-uc-unset         TwoColumnLayout + EmptyState.section + UC 選擇入口
//   flow 未結構化 state-ucFlow-unstructured     TwoColumnLayout + ListRow.meta + AppText.title + EmptyState.section（ButtonRow：開啟原始檔、檢視關聯）+ UC 選擇入口
//   正常         state-ucFlow-normal           TwoColumnLayout + AppDataTable（步驟表 + appendix 事件流小表）+ UC 選擇入口
//
// 三態依 `0.1.0-W2-010`（承接 `0.1.0-W2-002` NeedsContext，元件庫缺件已由
// `0.1.0-W3-634`／`0.1.0-W3-635` 補齊）依 SPEC-004 §3.6 §2 組成，本檔斷言
// 對應元件型別存在。`0.1.0-W2-013` 補齊 flow 未結構化態的 `ListRow.meta`
// ／`AppText.title`／`ButtonRow` 兩動作、步驟列點擊跳轉，見對應群組。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_fixtures.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_state.dart';

import '../../helpers/helpers.dart';

/// 本檔斷言畫面組成，UC 清單以固定 fixture 注入（真實資料路徑見
/// `uc_flow/uc_flow_real_data_test.dart`）。
final _withFixtures = ucFlowUcListProvider.overrideWithValue(
  UcFlowFixtures.ucList,
);

void main() {
  group('專案未就緒 state-ucFlow-project-unready（UcFlowProjectUnready）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          projectUnreadyReasonProvider.overrideWithValue(
            ProjectUnreadyReason.notSelected,
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.ucFlow, 'project-unready'),
        findsOneWidget,
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('尚未選擇專案'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-ucFlow-goto-domain → 切至 Domain 視圖', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          projectUnreadyReasonProvider.overrideWithValue(
            ProjectUnreadyReason.notSelected,
          ),
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
      final l10n = AppLocalizations.of(
        tester.element(find.byType(UcFlowScreen)),
      );
      expect(find.text(l10n.emptyUcMessage), findsOneWidget);
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
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => null),
        ],
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
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => null),
        ],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-select-uc-UC-02')));
      await tester.pump();

      expect(container.read(selectedUcProvider), 'UC-02');
      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
    });
  });

  group('flow 未結構化 state-ucFlow-unstructured（UcFlowUnstructured）', () {
    // 鑑別力對照（SPEC-004 §3.6 §2）：本測試修改前的組成只有
    // `EmptyState.section` + UC 選擇入口（與「尚未選定 UC」相同），下列
    // `ListRow`／`ButtonRow`／兩個動作鍵斷言在該舊組成下皆為
    // `findsNothing`，本次補齊後才轉為 `findsOneWidget`——回歸到舊組成會
    // 使本測試翻紅，具鑑別力。
    testWidgetsAtEachSize(
      '渲染 TwoColumnLayout + ListRow.meta + AppText.title + EmptyState.section + UC 選擇入口',
      (tester, size) async {
        await pumpHarness(
          tester,
          child: const UcFlowScreen(),
          overrides: [
            _withFixtures,
            selectedUcProvider.overrideWith((ref) => 'UC-06'),
          ],
          size: size,
        );

        expect(
          AnchorFinder.state(Screen.ucFlow, 'unstructured'),
          findsOneWidget,
        );
        expect(find.byType(TwoColumnLayout), findsOneWidget);
        expect(
          find.byKey(const Key('panel-ucFlow-unstructured-meta')),
          findsOneWidget,
        );
        expect(
          find.text('docs/usecases/UC-06-find-and-fix-document-gaps.md'),
          findsOneWidget,
        );
        expect(find.text('找出並修復文件破洞'), findsOneWidget);
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('尚未填寫結構化 flow'), findsOneWidget);
        expect(find.byType(ButtonRow), findsOneWidget);
        expect(
          find.byKey(const Key('action-ucFlow-open-source')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('action-ucFlow-view-relations')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('panel-ucFlow-uc-selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('action-ucFlow-select-uc-UC-06')),
          findsOneWidget,
        );
        expectNoOverflow(tester);
      },
    );

    testWidgets('選擇另一條含 FlowStep 的 UC → 切至正常態', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-select-uc-UC-04')));
      await tester.pump();

      expect(container.read(selectedUcProvider), 'UC-04');
      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
    });

    testWidgets('action-ucFlow-view-relations → 切至節點詳情', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.ucFlow,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-ucFlow-view-relations')));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.nodeDetail,
      );
      expect(container.read(returnToProvider), AppDestination.ucFlow);
    });
  });

  group('正常 state-ucFlow-normal（UcFlowNormal）', () {
    testWidgetsAtEachSize('渲染 TwoColumnLayout + 步驟表 + 事件流小表 + UC 選擇入口', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
      expect(find.byType(TwoColumnLayout), findsOneWidget);
      expect(find.byType(AppDataTable), findsNWidgets(2));
      expect(find.byType(StepNumber), findsNWidgets(3));
      expect(find.byType(RelationItem), findsNWidgets(3));
      expect(find.byKey(const Key('scroll-ucFlow-steps')), findsOneWidget);
      expect(find.byKey(const Key('panel-ucFlow-event-flow')), findsOneWidget);
      expect(find.byKey(const Key('panel-ucFlow-uc-selector')), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('本 UC 無事件時不渲染事件流小表', (tester, size) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => 'UC-04'),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
      expect(find.byType(AppDataTable), findsOneWidget);
      expect(find.byKey(const Key('panel-ucFlow-event-flow')), findsNothing);
      expectNoOverflow(tester);
    });

    // 事件流小表缺側回退（SPEC-001 §2〈事件流小表〉「本 UC 外」列）。E1 對照：
    // 同一事件在兩側皆有時不出現回退文案；只剩一側時恰出現一次。
    Future<void> pumpEventUc(
      WidgetTester tester,
      List<UcFlowStepItem> steps, {
      Map<String, UcFlowEventSides> eventSides = const {},
    }) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          ucFlowUcListProvider.overrideWithValue([
            UcFlowUcItem(
              id: 'edge-case',
              title: 'edge-uc', // i18n-exempt: 測試 UC 標題
              filePath: 'docs/usecases/edge-case.md', // i18n-exempt: 測試路徑
              steps: steps,
              eventSides: eventSides,
            ),
          ]),
          selectedUcProvider.overrideWith((ref) => 'edge-case'),
        ],
      );
    }

    // 預期文字取自 SPEC-001 v1.62 §2／SPEC-003 v1.70 §3.2 條文；原
    // '本 UC 外（）' 斷言反映的是未接線缺口而非規格行為（0.5.0-W1-547）。
    const outside = '本 UC 外'; // i18n-exempt: 斷言 zh 樣板文案
    const eventKey = 'x.y.z'; // i18n-exempt: 測試事件 ID
    const emitStep = UcFlowStepItem(
      label: 'e', // i18n-exempt: 測試步驟標籤
      domain: 'graph',
      emits: ['x.y.z'], // i18n-exempt: 測試事件 ID
    );
    const consumeStep = UcFlowStepItem(
      label: 'c', // i18n-exempt: 測試步驟標籤
      domain: 'graph',
      consumes: ['x.y.z'], // i18n-exempt: 測試事件 ID
    );

    testWidgets('事件兩側皆在本 UC 內時不顯示「本 UC 外」（對照）', (tester) async {
      await pumpEventUc(
        tester,
        [emitStep, consumeStep],
        eventSides: {
          eventKey: const UcFlowEventSides(consumers: ['storage']),
        },
      );

      expect(find.byKey(const Key('panel-ucFlow-event-flow')), findsOneWidget);
      expect(find.textContaining(outside), findsNothing);
    });

    testWidgets('缺消費側時附 EVT consumers 所列 domain（多個以「、」串接）', (tester) async {
      await pumpEventUc(
        tester,
        [emitStep],
        eventSides: {
          eventKey: const UcFlowEventSides(
            producers: ['ignored'], // i18n-exempt: 對側以外的欄位不得顯示
            consumers: ['storage', 'graph'],
          ),
        },
      );

      expect(find.text('$outside（storage、graph）'), findsOneWidget);
      expect(find.textContaining('ignored'), findsNothing);
    });

    testWidgets('缺發出側時附 EVT producers 所列 domain', (tester) async {
      await pumpEventUc(
        tester,
        [consumeStep],
        eventSides: {
          eventKey: const UcFlowEventSides(
            producers: ['corpus'],
            consumers: ['ignored'], // i18n-exempt: 對側以外的欄位不得顯示
          ),
        },
      );

      expect(find.text('$outside（corpus）'), findsOneWidget);
      expect(find.textContaining('ignored'), findsNothing);
    });

    testWidgets('對側值為 presentation 時顯示「畫面」', (tester) async {
      await pumpEventUc(
        tester,
        [emitStep],
        eventSides: {
          eventKey: const UcFlowEventSides(
            consumers: ['presentation', 'graph'],
          ),
        },
      );

      expect(find.text('$outside（畫面、graph）'), findsOneWidget);
      expect(find.textContaining('presentation'), findsNothing);
    });

    testWidgets('對側清單為空時顯示「本 UC 外」不帶括號', (tester) async {
      await pumpEventUc(
        tester,
        [emitStep],
        eventSides: {eventKey: const UcFlowEventSides()},
      );

      expect(find.text(outside), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });

    testWidgets('找不到 EVT 節點時發出側顯示「本 UC 外」不帶括號', (tester) async {
      await pumpEventUc(tester, [consumeStep]);

      expect(find.text(outside), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });

    testWidgets('找不到 EVT 節點時消費側顯示「本 UC 外」不帶括號', (tester) async {
      await pumpEventUc(tester, [emitStep]);

      expect(find.text(outside), findsOneWidget);
      expect(find.textContaining('（'), findsNothing);
    });

    testWidgets('點 domain → 切至 Domain 視圖', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
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

    testWidgets('點步驟 → 切至節點詳情', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _withFixtures,
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.ucFlow,
          ),
        ],
      );

      // 點步驟文字格（非 domain 格，domain 格自身的 `RelationItem` 另有
      // onTap，會遮蔽列層級的 onTap）。
      await tester.tap(find.text('選擇資料夾'));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.nodeDetail,
      );
      expect(container.read(returnToProvider), AppDestination.ucFlow);
    });
  });
}
