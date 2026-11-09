// SPEC-001 §10 八狀態渲染（docs/test-design/SPEC-001-history-screen-test-design.md §3.1）。
//
// 篩選列（期間三選項、含 ticket 建檔）與事件列屬 0.7.0-W1-012.12，本檔不斷言。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';

import '../../../helpers/history/history_screen_fixtures.dart';

final _l10n = AppLocalizationsZh();

Finder _key(String k) => find.byKey(Key(k));

const _roots = [
  'state-history-project-unready',
  'state-history-loading',
  'state-history-normal',
  'state-history-empty',
  'state-history-not-git',
  'state-history-git-missing',
  'state-history-load-failed',
  'state-history-cancelled',
];

void main() {
  group('ST-1 專案未就緒（四原因）', () {
    final cases = {
      ProjectUnreadyReason.notSelected: _l10n.projectUnreadyReasonNotSelected,
      ProjectUnreadyReason.loading: _l10n.projectUnreadyReasonLoading,
      ProjectUnreadyReason.incompatible: _l10n.projectUnreadyReasonIncompatible,
      ProjectUnreadyReason.loadFailed: _l10n.projectUnreadyReasonLoadFailed,
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key.name, (tester) async {
        await pumpHistoryApp(
          tester,
          const HistoryIdle(),
          extra: [projectUnreadyReasonProvider.overrideWithValue(entry.key)],
        );
        expect(_key('state-history-project-unready'), findsOneWidget);
        expect(find.text(entry.value), findsWidgets);
        expect(_key('action-history-goto-domain'), findsOneWidget);
        expect(_key('action-history-refresh'), findsNothing);
        expect(_key('option-history-period-default'), findsNothing);
      });
    }
  });

  testWidgets('ST-2 HistorySchemaBlocked 渲染專案未就緒', (tester) async {
    await pumpHistoryApp(tester, const HistorySchemaBlocked());
    expect(_key('state-history-project-unready'), findsOneWidget);
  });

  testWidgets('ST-3 讀取中：訊息、計數、取消；無篩選列、無百分比', (tester) async {
    await pumpHistoryApp(
      tester,
      const HistoryLoading(processedCount: 7),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_key('state-history-loading'), findsOneWidget);
    expect(find.text(_l10n.historyLoading), findsOneWidget);
    expect(find.text(_l10n.historyLoadingProcessedCount(7)), findsOneWidget);
    expect(_key('action-history-cancel'), findsOneWidget);
    expect(_key('option-history-period-default'), findsNothing);
    expect(_key('action-history-include-ticket-created'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('ST-4 正常：容器、重新整理、期間描述與事件數', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_key('scroll-history-events'), findsOneWidget);
    expect(_key('action-history-refresh'), findsOneWidget);
    expect(
      find.text(
        _l10n.historyPeriodSummary(_l10n.historyPeriodSinceTag('v0.6.0'), 3),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ST-5 期間內無事件：訊息、顯示全部、重新整理', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapEmptyDefault()));
    expect(_key('state-history-empty'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('panel-history-empty'),
        matching: find.text(_l10n.historyEmptyMessage),
      ),
      findsOneWidget,
    );
    expect(_key('action-history-show-all'), findsOneWidget);
    expect(_key('action-history-refresh'), findsOneWidget);
  });

  testWidgets('ST-6 尚無 commit 變體：無顯示全部、無篩選、有重新整理', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapNoCommit()));
    expect(_key('state-history-empty'), findsOneWidget);
    expect(find.text(_l10n.historyNoCommitsMessage), findsOneWidget);
    expect(_key('action-history-show-all'), findsNothing);
    expect(_key('option-history-period-default'), findsNothing);
    expect(_key('action-history-include-ticket-created'), findsNothing);
    expect(_key('action-history-refresh'), findsOneWidget);
  });

  testWidgets('ST-7 非 git 專案', (tester) async {
    await pumpHistoryApp(tester, const HistoryNotGitRepo());
    expect(_key('state-history-not-git'), findsOneWidget);
    expect(find.text(_l10n.historyNotGitMessage), findsOneWidget);
    expect(_key('action-history-recheck'), findsOneWidget);
  });

  testWidgets('ST-8 找不到 git', (tester) async {
    await pumpHistoryApp(tester, const HistoryGitNotFound());
    expect(_key('state-history-git-missing'), findsOneWidget);
    expect(find.text(_l10n.historyGitMissingMessage), findsOneWidget);
    expect(find.text(_l10n.historyGitMissingExplanation), findsOneWidget);
    expect(_key('action-history-recheck'), findsOneWidget);
  });

  testWidgets('ST-9 讀取失敗：stderr 摘要原文與重試', (tester) async {
    await pumpHistoryApp(
      tester,
      const HistoryFailed(
        GitFailureReason.scanNonZeroExit,
        stderrSummary: 'fatal: bad object h3',
      ),
    );
    expect(_key('state-history-load-failed'), findsOneWidget);
    expect(find.text(_l10n.historyLoadFailedMessage), findsOneWidget);
    expect(
      find.text(_l10n.historyLoadFailedDetail('fatal: bad object h3')),
      findsOneWidget,
    );
    expect(_key('action-history-retry'), findsOneWidget);
  });

  testWidgets('ST-10 已取消', (tester) async {
    await pumpHistoryApp(tester, const HistoryCancelled());
    expect(_key('state-history-cancelled'), findsOneWidget);
    expect(find.text(_l10n.historyCancelledMessage), findsOneWidget);
    expect(_key('action-history-reload'), findsOneWidget);
  });

  testWidgets('ST-11 互斥：每態恰一個狀態根；頁首標題恆在；重新整理限三態', (tester) async {
    for (final (rootKey, state) in historyStateCases()) {
      await pumpHistoryApp(tester, state, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      final present = [
        for (final r in _roots)
          if (_key(r).evaluate().isNotEmpty) r,
      ];
      expect(present, [rootKey], reason: '${state.runtimeType}');
      expect(
        find.byWidgetPredicate(
          (w) => w is PageTitle && w.title == _l10n.navHistory,
        ),
        findsOneWidget,
      );
      final hasRefresh = _key('action-history-refresh').evaluate().isNotEmpty;
      expect(
        hasRefresh,
        rootKey == 'state-history-normal' || rootKey == 'state-history-empty',
      );
    }
    await pumpHistoryApp(tester, HistoryLoaded(snapNoCommit()));
    expect(_key('action-history-refresh'), findsOneWidget);
  });

  testWidgets('ST-12 三種降級狀態根互異，非 git／找不到 git 不顯示讀取失敗', (tester) async {
    final keys = <String>{};
    for (final (state, root) in [
      (const HistoryNotGitRepo(), 'state-history-not-git'),
      (const HistoryGitNotFound(), 'state-history-git-missing'),
      (
        const HistoryFailed(GitFailureReason.scanNonZeroExit),
        'state-history-load-failed',
      ),
    ]) {
      await pumpHistoryApp(tester, state);
      expect(_key(root), findsOneWidget);
      keys.add(root);
      if (state is! HistoryFailed) {
        expect(find.text(_l10n.historyLoadFailedMessage), findsNothing);
      }
    }
    expect(keys, hasLength(3));
  });
}
