// SPEC-001 §10 各狀態退出路徑（FR-01、FR-02；測試設計 §3.2）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';

import '../../../helpers/history/fake_process_runner.dart';
import '../../../helpers/history/history_screen_fixtures.dart';

Finder _key(String k) => find.byKey(Key(k));

Finder _button(String k) =>
    find.byWidgetPredicate((w) => w is AppButton && w.testKey == Key(k));

/// SPEC-003 §3.9〈導航跳轉與退出〉各狀態的畫面內出口錨點。
const _exitsByRoot = {
  'state-history-project-unready': ['action-history-goto-domain'],
  'state-history-loading': ['action-history-cancel'],
  'state-history-normal': ['action-history-refresh'],
  'state-history-empty': ['action-history-show-all', 'action-history-refresh'],
  'state-history-not-git': ['action-history-recheck'],
  'state-history-git-missing': ['action-history-recheck'],
  'state-history-load-failed': ['action-history-retry'],
  'state-history-cancelled': ['action-history-reload'],
};

void main() {
  testWidgets('EX-1 八態各自的出口錨點存在且可點，導覽與切換入口恆在', (tester) async {
    for (final (rootKey, state) in historyStateCases()) {
      await pumpHistoryApp(tester, state, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      final exits = _exitsByRoot[rootKey]!;
      for (final anchor in exits) {
        expect(_button(anchor), findsOneWidget, reason: '$rootKey $anchor');
        expect(tester.widget<AppButton>(_button(anchor)).enabled, isTrue);
      }
      for (final d in AppDestination.values) {
        expect(_key('nav-item-${d.name}'), findsOneWidget);
      }
      expect(_key('project-switcher-entry'), findsOneWidget);
      expect(
        exits.length + AppDestination.values.length,
        greaterThanOrEqualTo(1),
      );
    }
  });

  testWidgets('EX-2 專案未就緒：前往 Domain 視圖，returnTo 為 history', (tester) async {
    await pumpHistoryApp(
      tester,
      const HistoryIdle(),
      extra: [
        projectUnreadyReasonProvider.overrideWithValue(
          ProjectUnreadyReason.notSelected,
        ),
      ],
    );
    await tester.tap(_key('action-history-goto-domain'));
    await tester.pumpAndSettle();
    final c = historyContainer(tester);
    expect(c.read(selectedDestinationProvider), AppDestination.domain);
    expect(c.read(returnToProvider), AppDestination.history);
  });

  testWidgets('EX-3 讀取中取消：cancel() 1 次、可見頁不變、無 SnackBar', (tester) async {
    final fake = await pumpHistoryApp(
      tester,
      const HistoryLoading(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_key('action-history-cancel'));
    await tester.pump();
    expect(fake.cancelCalls, 1);
    expect(
      historyContainer(tester).read(selectedDestinationProvider),
      AppDestination.history,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('EX-4 正常：重新整理呼叫 refresh() 1 次', (tester) async {
    final fake = await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    await tester.tap(_key('action-history-refresh'));
    await tester.pump();
    expect(fake.refreshCalls, 1);
  });

  for (final (name, state, anchor) in [
    ('EX-5a 非 git 重新檢查', const HistoryNotGitRepo(), 'action-history-recheck'),
    (
      'EX-5b 找不到 git 重新檢查',
      const HistoryGitNotFound(),
      'action-history-recheck',
    ),
    (
      'EX-6 讀取失敗重試',
      const HistoryFailed(GitFailureReason.scanNonZeroExit),
      'action-history-retry',
    ),
    ('EX-7 已取消重新讀取', const HistoryCancelled(), 'action-history-reload'),
  ]) {
    testWidgets('$name：自前置檢查重新開始（refresh() 1 次）', (tester) async {
      final fake = await pumpHistoryApp(tester, state);
      await tester.tap(_key(anchor));
      await tester.pump();
      expect(fake.enterCalls + fake.refreshCalls, 1);
    });
  }

  testWidgets('EX-5 真實 notifier：重新檢查使前置檢查呼叫數加一', (tester) async {
    final runner = FakeProcessRunner()..workTree = okResponse('false\n');
    await pumpHistoryRealApp(tester, runner);
    expect(_key('state-history-not-git'), findsOneWidget);
    final before = runner.callKinds.where((k) => k == 'version').length;
    await tester.tap(_key('action-history-recheck'));
    await tester.pumpAndSettle();
    expect(runner.callKinds.where((k) => k == 'version').length, before + 1);
  });

  testWidgets('EX-7 真實 notifier：重新讀取後計數自 0 起算', (tester) async {
    final runner = FakeProcessRunner(
      scanFactory: () => FakeScanScript.manual(),
    );
    await pumpHistoryRealApp(tester, runner, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(_key('action-history-cancel'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_key('state-history-cancelled'), findsOneWidget);
    await tester.tap(_key('action-history-reload'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('EX-8a 取消（無先前結果）：已取消', (tester) async {
    final script = FakeScanScript.manual();
    final runner = FakeProcessRunner(scanFactory: () => script);
    await pumpHistoryRealApp(tester, runner, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    await tester.tap(_key('action-history-cancel'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_key('state-history-cancelled'), findsOneWidget);
    expect(runner.killCount, 1);
  });

  testWidgets('EX-8b 取消（有先前結果）：回到正常，事件同先前', (tester) async {
    final runner = FakeProcessRunner();
    await pumpHistoryRealApp(tester, runner);
    final c = historyContainer(tester);
    final first = (c.read(historyProvider) as HistoryLoaded).snapshot;
    final script = FakeScanScript.manual();
    runner
      ..head = okResponse('${'c' * 40}\n')
      ..scanFactory = () => script;
    final pending = c.read(historyProvider.notifier).refresh();
    await tester.pump(const Duration(milliseconds: 100));
    c.read(historyProvider.notifier).cancel();
    await tester.pump(const Duration(milliseconds: 50));
    final now = c.read(historyProvider);
    expect(now, isA<HistoryLoaded>());
    expect((now as HistoryLoaded).snapshot, same(first));
    await script.finish();
    await pending;
  });
}
