// 第七畫面生命週期（測試設計 §3.7）：真實 HistoryNotifier，fake 程序執行器。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/app_lifecycle.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/history/fake_process_runner.dart';
import '../../../helpers/history/history_screen_fixtures.dart';

Finder _key(String k) => find.byKey(Key(k));

/// 前置檢查可暫停的 runner。
class _GatedRunner extends FakeProcessRunner {
  Completer<void>? gate;

  @override
  Future<GitCommandResult> run(GitInvocation invocation) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.run(invocation);
  }
}

int _preflights(FakeProcessRunner r) =>
    r.callKinds.where((k) => k == 'version').length;

Future<void> _goTo(WidgetTester tester, String destination) async {
  await tester.tap(_key('nav-item-$destination'));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('LC-1 未進入第七畫面：git 0 次、Idle', (tester) async {
    final runner = FakeProcessRunner();
    await pumpHistoryRealApp(tester, runner, start: AppDestination.domain);
    expect(runner.calls, isEmpty);
    expect(historyContainer(tester).read(historyProvider), isA<HistoryIdle>());
  });

  testWidgets('LC-2 點導覽：自動進入讀取中，前置檢查 1 次', (tester) async {
    final script = FakeScanScript.manual();
    final runner = FakeProcessRunner(scanFactory: () => script);
    await pumpHistoryRealApp(tester, runner, start: AppDestination.domain);
    await _goTo(tester, 'history');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    expect(_preflights(runner), 1);
  });

  testWidgets('LC-3 專案未就緒不讀取；就緒後自動開始', (tester) async {
    final reason = stateHolderProvider<ProjectUnreadyReason?>(
      (ref) => ProjectUnreadyReason.notSelected,
    );
    final runner = FakeProcessRunner();
    await pumpHistoryRealApp(
      tester,
      runner,
      start: AppDestination.domain,
      extra: [
        projectUnreadyReasonProvider.overrideWith((ref) => ref.watch(reason)),
      ],
    );
    await _goTo(tester, 'history');
    expect(runner.calls, isEmpty);
    expect(_key('state-history-project-unready'), findsOneWidget);
    historyContainer(tester).read(reason.notifier).state = null;
    await tester.pumpAndSettle();
    expect(_preflights(runner), 1);
    expect(_key('state-history-project-unready'), findsNothing);
  });

  testWidgets('LC-4 再次可見：前置檢查期間維持正常，不出現讀取中', (tester) async {
    final runner = _GatedRunner();
    await pumpHistoryRealApp(tester, runner);
    expect(
      _key('state-history-empty').evaluate().length +
          _key('state-history-normal').evaluate().length,
      1,
    );
    runner.gate = Completer<void>();
    await _goTo(tester, 'domain');
    await _goTo(tester, 'history');
    expect(_key('state-history-loading'), findsNothing);
    expect(
      historyContainer(tester).read(historyProvider),
      isA<HistoryLoaded>(),
    );
    runner.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('LC-5 讀取中導覽離開再回來：不中斷、無 SnackBar', (tester) async {
    final script = FakeScanScript.manual();
    final runner = FakeProcessRunner(scanFactory: () => script);
    await pumpHistoryRealApp(tester, runner, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    await _goTo(tester, 'domain');
    expect(runner.killCount, 0);
    await _goTo(tester, 'history');
    expect(runner.killCount, 0);
    expect(_key('state-history-loading'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await script.finish();
    await tester.pumpAndSettle();
    expect(
      historyContainer(tester).read(historyProvider),
      isA<HistoryLoaded>(),
    );
  });

  testWidgets('LC-6 導覽離開再回來：篩選保留', (tester) async {
    final runner = FakeProcessRunner();
    await pumpHistoryRealApp(tester, runner);
    final c = historyContainer(tester);
    c.read(historyPeriodChoiceProvider.notifier).state =
        PeriodChoice.allHistory;
    c.read(historyIncludeTicketCreationProvider.notifier).state = true;
    await _goTo(tester, 'domain');
    await _goTo(tester, 'history');
    await tester.pumpAndSettle();
    expect(c.read(historyPeriodChoiceProvider), PeriodChoice.allHistory);
    expect(c.read(historyIncludeTicketCreationProvider), isTrue);
  });

  testWidgets('LC-7 讀取中切換專案：取消、清除、篩選重置、新專案重新判定', (tester) async {
    final runner = FakeProcessRunner(
      scanFactory: () => FakeScanScript.manual(),
    );
    await pumpHistoryRealApp(tester, runner, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    final c = historyContainer(tester);
    c.read(historyPeriodChoiceProvider.notifier).state =
        PeriodChoice.allHistory;
    c.read(currentWorkspaceStateProvider.notifier).state = const WorkspaceReady(
      '/other',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(runner.killCount, 1);
    expect(c.read(historyPeriodChoiceProvider), PeriodChoice.defaultPeriod);
    expect(c.read(historyIncludeTicketCreationProvider), isFalse);
    expect(_preflights(runner), 2);
  });

  testWidgets('LC-8 視窗回到前景：前置檢查呼叫數不變', (tester) async {
    final runner = FakeProcessRunner();
    await pumpHistoryRealApp(tester, runner);
    final before = _preflights(runner);
    historyContainer(tester).read(appLifecycleStateProvider.notifier).state =
        AppLifecycleState.resumed;
    await tester.pumpAndSettle();
    expect(_preflights(runner), before);
  });
}
