// 破洞頁輪次完成事件源收斂（0.6.0-W1-139，080 Phase 4 P4-2）。
//
// 完成訊號只認 scanRoundProvider 的 Running→Completed；失敗與不可用仍由
// WatchRoundCompleted 承載（ScanRoundState 無失敗狀態）。
// 「E1」標註對照輸入。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

/// 不對外發任何輪次事件的監看控制器（排程照常運作）。
class _SilentWatch extends CorpusWatchController {
  _SilentWatch(super.ref);

  @override
  Stream<WatchRoundEvent> get events => const Stream<WatchRoundEvent>.empty();
}

final _onGaps = selectedDestinationProvider.overrideWithInitial(
  (ref) => AppDestination.gaps,
);
final _ready = currentWorkspaceStateProvider.overrideWithInitial(
  (ref) => const WorkspaceReady('/ws/a'),
);

/// 結果頁的項目總數；非結果態為 -1。
int _itemCount(GapReportState s) => s is GapReportFound
    ? s.categories.fold(0, (n, c) => n + c.items.length)
    : -1;

void main() {
  Future<ProviderContainer> pumpWith(
    WidgetTester tester,
    FakeScanRound fake, {
    List<Override> extra = const [],
  }) async {
    final container = await pumpHarness(
      tester,
      child: const SizedBox.shrink(),
      overrides: [
        _onGaps,
        scanRoundProvider.overrideWith(() => fake),
        ...extra,
      ],
    );
    container.listen(gapReportProvider, (_, _) {});
    return container;
  }

  group('回歸網（改寫前後皆綠）', () {
    testWidgets('(a) scheduler 觸發的 watch 輪次完成 → 呈現新結果', (tester) async {
      var files = 1;
      final fake = FakeScanRound(
        produce: () => fakeRound(
          parseFailureEvents: [
            for (var i = 0; i < files; i++) fakeCarrierEvent('docs/$i.md'),
          ],
        ),
      );
      final container = await pumpWith(tester, fake, extra: [_ready]);
      await pumpContract(tester, Motion.spinnerMinVisible);
      final before = _itemCount(container.read(gapReportProvider));
      expect(before, greaterThan(0));

      files = 3;
      container.read(corpusWatchProvider).scheduler.request(ScanTrigger.watch);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(
        _itemCount(container.read(gapReportProvider)),
        greaterThan(before),
      );
    });

    testWidgets('(b) 專案未就緒後他人建立並完成輪次 → 呈現該輪', (tester) async {
      final fake = FakeScanRound(produce: () => null);
      final container = await pumpWith(tester, fake);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());

      fake.completeExternally(
        fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      await tester.pump();

      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('(c) 失敗輪次 → 無法判定', (tester) async {
      final fake = FakeScanRound(produce: () => throw StateError('boom'));
      final container = await pumpWith(tester, fake, extra: [_ready]);
      await pumpContract(tester, Motion.spinnerMinVisible);

      final state = container.read(gapReportProvider);
      expect(state, isA<GapReportUndeterminable>());
      expect((state as GapReportUndeterminable).isScanFailure, isTrue);
    });

    testWidgets('(d) 取消後完成的輪次被忽略', (tester) async {
      final fake = FakeScanRound(
        produce: () => fakeRound(),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpWith(tester, fake, extra: [_ready]);
      await tester.pump();

      container.read(gapReportProvider.notifier).cancelScan();
      fake.completeExternally(
        fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      await pumpContract(tester, Motion.spinnerMinVisible);

      final state = container.read(gapReportProvider);
      expect(state, isA<GapReportScanning>());
      expect((state as GapReportScanning).isCancelling, isTrue);
      await tester.pump(Motion.cancelDeadline);
    });
  });

  testWidgets('鑑別：事件流靜默，scheduler 輪次 Running→Completed 仍呈現結果', (tester) async {
    final fake = FakeScanRound(
      produce: () =>
          fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
    );
    final container = await pumpWith(
      tester,
      fake,
      extra: [
        _ready,
        corpusWatchProvider.overrideWith((ref) => _SilentWatch(ref)),
      ],
    );
    await pumpContract(tester, Motion.spinnerMinVisible);

    expect(container.read(gapReportProvider), isA<GapReportFound>());
  });

  testWidgets('計數：一輪完成只通知呈現層一次（狀態只轉為結果一次）', (tester) async {
    final fake = FakeScanRound(
      produce: () =>
          fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
    );
    final container = await pumpHarness(
      tester,
      child: const SizedBox.shrink(),
      overrides: [_onGaps, _ready, scanRoundProvider.overrideWith(() => fake)],
    );
    var foundEmissions = 0;
    container.listen(gapReportProvider, (_, next) {
      if (next is GapReportFound) foundEmissions++;
    });
    await pumpContract(tester, Motion.spinnerMinVisible);
    await pumpContract(tester, Motion.spinnerMinVisible);

    expect(container.read(gapReportProvider), isA<GapReportFound>());
    expect(foundEmissions, 1);
  });

  testWidgets('E1 對照：無 scheduler 輪次且非等待中，他人完成的輪次不覆蓋', (tester) async {
    final fake = FakeScanRound(
      produce: () =>
          fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
    );
    final container = await pumpWith(tester, fake, extra: [_ready]);
    await pumpContract(tester, Motion.spinnerMinVisible);
    final before = _itemCount(container.read(gapReportProvider));

    fake.completeExternally(fakeRound());
    await tester.pump();

    expect(_itemCount(container.read(gapReportProvider)), before);
  });
}
