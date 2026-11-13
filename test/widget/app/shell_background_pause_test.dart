// 需求：0.6.0-W1-107；riverpod 3「不可見時暫停監聽」對跨頁行為的回歸防護
// （0.6.0-W1-079 行為變更評估第 3 項）。
//
// 暫停條件是 widget 所在子樹的 TickerMode 關閉；AppShell 以 IndexedStack 承載
// 六頁，非選取頁處於該狀態。本檔走真實 AppShell、真實 GapReportNotifier、
// 真實 ScanNotificationController，只替換輪次擁有者與系統通知管道，
// 時序以 `tester.pump(duration)`（假時鐘）驅動。
// 「對照」標註的斷言：暫停導致錯誤時（停在掃描中／舊結果／通知漏發）會翻紅。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/assembly/shell.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/services/scan_notifier_provider.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/pump_harness.dart' show lastWinsByProvider;
import '../../helpers/stub_workspace_repository.dart';
import '../../unit/screens/scan_notification_controller_test.dart'
    show FakeScanNotifier;

const _uc02 = LightNode(
  id: 'UC-02',
  typeName: 'UC',
  status: null,
  title: null,
  path: 'docs/usecases/UC-02-assess-change-impact-by-domain.md',
);

/// 第 1 輪：零破洞、僅 UC-01。第 2 輪：一個破洞、多一個 UC-02。
ScanRoundResult _roundA() => fakeRound();
ScanRoundResult _roundB() => fakeRound(
  nodes: const [fakeUcNode, _uc02],
  parseFailureEvents: [fakeCarrierEvent('docs/spec/broken.md')],
);

class _Rig {
  _Rig(this.notifier, this.container);
  final FakeScanNotifier notifier;
  final ProviderContainer container;
}

/// 啟動真實 AppShell；第 1 次產生輪次回 A，之後回 B。
Future<_Rig> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final notifier = FakeScanNotifier();
  late FakeScanRound fake;
  late BuildContext captured;
  fake = FakeScanRound(
    produce: () => fake.produced <= 1 ? _roundA() : _roundB(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: lastWinsByProvider([
        workspaceRepositoryProvider.overrideWithValue(
          StubWorkspaceRepository(const WorkspaceReady('/ws')),
        ),
        frameworkSignalProbeProvider.overrideWithValue(
          const StubFrameworkSignalProbe(version: '0.0.1', schemaJson: true),
        ),
        builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
        scanRoundProvider.overrideWith(() => fake),
        scanNotifierProvider.overrideWithValue(notifier),
        // 殼讀寫入清單（553.17）；不開真實 git 探測。
        editWorkspaceProvider.overrideWith((ref) async => null),
      ]),
      child: ScreenUtilInit(
        designSize: const Size(1280, 800),
        builder: (context, child) => MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              captured = context;
              return const AppShell();
            },
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return _Rig(notifier, ProviderScope.containerOf(captured));
}

Future<void> _goTo(WidgetTester tester, _Rig rig, AppDestination d) async {
  navigateTo(rig.container.read, d, NavIntent.rail);
  await tester.pump();
  await tester.pump();
}

Future<void> _elapseScan(WidgetTester tester) async {
  await tester.pump(Motion.spinnerMinVisible);
  await tester.pump(const Duration(milliseconds: 50));
}

/// 在破洞報告頁按「重新掃描」，回傳時掃描已開始但尚未過最短可見時間。
Future<void> _startRescanOnGaps(WidgetTester tester, _Rig rig) async {
  await _goTo(tester, rig, AppDestination.gaps);
  expect(find.byKey(const Key('state-gaps-none')), findsOneWidget);
  await tester.tap(find.byKey(const Key('action-gaps-rescan')));
  await tester.pump();
  expect(find.byKey(const Key('state-gaps-scanning')), findsOneWidget);
}

void main() {
  testWidgets('情境 1：掃描中切走、完成後切回 → 顯示完成結果，不停在掃描中或舊結果', (tester) async {
    final rig = await _pump(tester);
    await _startRescanOnGaps(tester, rig);

    await _goTo(tester, rig, AppDestination.domain);
    await _elapseScan(tester);
    await _goTo(tester, rig, AppDestination.gaps);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('state-gaps-found')), findsOneWidget);
    // 對照：暫停導致錯誤時會停在掃描中（骨架）或舊結果（無破洞）。
    expect(find.byKey(const Key('state-gaps-scanning')), findsNothing);
    expect(find.byKey(const Key('state-gaps-none')), findsNothing);
  });

  testWidgets('情境 2：Domain 視圖在背景時輪次完成 → 切回後矩陣反映最新輪次', (tester) async {
    final rig = await _pump(tester);
    expect(find.text('UC-02', skipOffstage: false), findsNothing);

    await _startRescanOnGaps(tester, rig);
    await _elapseScan(tester);
    await _goTo(tester, rig, AppDestination.domain);
    await tester.pump(const Duration(milliseconds: 50));

    // 對照：暫停導致 Domain 頁漏收新輪次時，畫面欄首仍只有 UC-01。
    expect(find.byKey(const Key('state-domain-matrix')), findsOneWidget);
    expect(find.text('UC-02'), findsWidgets);
  });

  testWidgets('情境 3：在其他頁時掃描完成 → 掃描完成通知照常觸發', (tester) async {
    final rig = await _pump(tester);
    await _startRescanOnGaps(tester, rig);
    await _goTo(tester, rig, AppDestination.tickets);
    await _elapseScan(tester);

    // 對照：暫停導致 shell 層監聽漏收時，兩者皆為 0。
    expect(rig.notifier.authorizationStatusCalls, 1);
    expect(rig.notifier.showCalls, 1);
    expect(rig.notifier.lastGapCount, 1);
  });

  testWidgets('情境 3 對照：掃描完成時使用者正看著破洞報告 → 不發通知', (tester) async {
    final rig = await _pump(tester);
    await _startRescanOnGaps(tester, rig);
    await _elapseScan(tester);

    expect(find.byKey(const Key('state-gaps-found')), findsOneWidget);
    expect(rig.notifier.showCalls, 0);
  });

  testWidgets('情境 4：hidden／paused 期間掃描完成，resumed 後通知與結果正確', (tester) async {
    final rig = await _pump(tester);
    await _startRescanOnGaps(tester, rig);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _elapseScan(tester);

    // 視窗不在前景：即使可見頁是 gaps 也須發通知（對照：暫停漏收則為 0）。
    expect(rig.notifier.showCalls, 1);
    expect(rig.notifier.withdrawCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));

    // 回前景且可見頁為 gaps：結果已被看見，通知撤回；畫面為完成結果。
    expect(rig.notifier.withdrawCalls, 1);
    expect(find.byKey(const Key('state-gaps-found')), findsOneWidget);
    expect(find.byKey(const Key('state-gaps-scanning')), findsNothing);
  });
}
