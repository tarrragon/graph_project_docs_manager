// 破洞報告頁對監看輪次的呈現（0.6.0-W1-080 B5；SPEC-003 §3.5、SPEC-001 §5）。
//
// W4：監看輪次不出現 `state-gaps-scanning`，保留舊結果；D2：監看輪次中按
// `action-gaps-rescan` 立即出現，兩輪皆完成才轉結果；D3：無既有結果時監看
// 輪次完成，之後可見不自動掃描。「對照」為正向對照輸入（E1／E2）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, ProviderScope;
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/main.dart' show DocsManagerApp;
import 'package:graph_project_docs_manager/tokens/motion.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/fake_watch_source.dart';
import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

const _latency = Duration(seconds: 1);

Finder get _scanning => AnchorFinder.state(Screen.gaps, 'scanning');
Finder get _none => AnchorFinder.state(Screen.gaps, 'none');
Finder get _found => AnchorFinder.state(Screen.gaps, 'found');

/// 第一輪（可見觸發）零破洞，之後每輪有一筆 003 破洞。
class _Harness {
  late final FakeScanRound round;
  late final ProviderContainer container;
  int calls = 0;

  Future<void> pump(WidgetTester tester, {bool onGaps = true}) async {
    round = FakeScanRound(
      latency: _latency,
      produce: () => ++calls == 1
          ? fakeRound()
          : fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
    );
    await pumpApp(
      tester,
      settle: false,
      overrides: <Override>[
        if (onGaps)
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.gaps,
          ),
        scanRoundProvider.overrideWith(() => round),
        watchSourceProvider.overrideWithValue(FakeWatchSource()),
        currentWorkspaceStateProvider.overrideWith(
          (ref) => const WorkspaceReady('/ws/fake'),
        ),
      ],
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(DocsManagerApp)),
      listen: false,
    );
    // 常駐殼已啟動監看控制器；此處取得同一份。
    container.read(corpusWatchProvider);
  }

  ScanScheduler get scheduler => container.read(corpusWatchProvider).scheduler;

  Future<void> settleFirstRound(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(_latency);
    await tester.pump(Motion.spinnerMinVisible);
  }
}

void main() {
  testWidgets('W4：監看輪次期間無 scanning 錨點，仍顯示上一輪結果', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.settleFirstRound(tester);
    expect(_none, findsOneWidget);

    h.scheduler.request(ScanTrigger.watch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.round.produced, 2, reason: '監看輪次確實在進行');
    expect(_scanning, findsNothing);
    expect(_none, findsOneWidget);

    await tester.pump(_latency);
    await tester.pump();
    expect(_scanning, findsNothing);
    expect(_found, findsOneWidget, reason: '完成後直接替換結果');
  });

  testWidgets('W4 對照：手動重掃有 scanning 錨點', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.settleFirstRound(tester);

    await tester.tap(AnchorFinder.action(Screen.gaps, 'rescan'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scanning, findsOneWidget);
    expect(_none, findsNothing);

    await tester.pump(_latency);
    await tester.pump(Motion.spinnerMinVisible);
    expect(_scanning, findsNothing);
    expect(_found, findsOneWidget);
  });

  testWidgets('D2：監看輪次中按重掃，立即出現錨點，兩輪皆完成才顯示結果', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.settleFirstRound(tester);

    h.scheduler.request(ScanTrigger.watch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scanning, findsNothing);

    await tester.tap(AnchorFinder.action(Screen.gaps, 'rescan'));
    await tester.pump();
    expect(_scanning, findsOneWidget, reason: '立即出現');

    // 監看輪次完成：仍有待重跑，維持 scanning、不替換結果。
    await tester.pump(_latency);
    await tester.pump(Motion.spinnerMinVisible);
    expect(h.round.produced, 3, reason: '接續一輪已開始');
    expect(_scanning, findsOneWidget);
    expect(_found, findsNothing);

    // 接續輪完成才轉結果。
    await tester.pump(_latency);
    await tester.pump(Motion.spinnerMinVisible);
    expect(_scanning, findsNothing);
    expect(_found, findsOneWidget);
  });

  testWidgets('D3：無既有結果時監看輪次完成，之後可見不自動掃描', (tester) async {
    final h = _Harness();
    await h.pump(tester, onGaps: false);
    await tester.pump(_latency);
    // 常駐殼的其他消費者（Domain 視圖）可能已完成一輪；以此為基準計數。
    final base = h.round.produced;

    h.scheduler.request(ScanTrigger.watch);
    await tester.pump();
    await tester.pump(_latency);
    await tester.pump();
    expect(h.round.produced, base + 1, reason: '監看輪次確實執行');

    h.container.read(selectedDestinationProvider.notifier).state =
        AppDestination.gaps;
    await tester.pump();
    await tester.pump(Motion.spinnerMinVisible);
    expect(h.round.produced, base + 1, reason: '可見時不再掃描');
    expect(_scanning, findsNothing);
    expect(_found, findsOneWidget, reason: '直接呈現監看輪次的結果');
  });
}
