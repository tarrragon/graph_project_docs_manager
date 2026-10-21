// 破洞報告頁接共用掃描輪次（0.5.0-W1-114.15）。
//
// 測試名稱前綴對應票面期望：A1～A4、A6～A10（A3' 為 A3 改讀輪次後的版本）；
// 「E1」「E2」標註對照輸入／正向對照輸入（test-assertion-design-rules）。
// A5（通知送出與真實耗時）屬平台事實，不在單元測試斷言。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/components.dart'
    show AppText, AppTextVariant;
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_projection.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_round_state.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart'
    show RawNode;

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/spec007/bundle_graph_fixture.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec006/fake_docs_fs.dart';

const _key = 'non_domain_path_patterns';

const _flowEvent = FlowParseFailedEvent(
  path: fakeUcPath,
  reason: 'flowBlockMalformed',
);

GraphDefect _danglingDefect() => DanglingRefGraphDefect(
  ref: ReferenceValue(
    sourceId: 'UC-01',
    sourcePath: fakeUcPath,
    edgeTypeName: 'spawn',
    fieldName: 'spawned_tickets',
    isReverse: false,
    value: 'T-404',
    isShapeValid: true,
  ),
  reason: DanglingReason.targetMissing,
);

List<String> _categoryIds(GapReportState s) => switch (s) {
  GapReportFound(:final categories) ||
  GapReportUndeterminable(
    :final categories,
  ) => [for (final c in categories) c.id],
  _ => const [],
};

final _onGaps = selectedDestinationProvider.overrideWith(
  (ref) => AppDestination.gaps,
);

const _builtinJson = <String, dynamic>{
  'schema_generated_at_framework_version': '1.0.0',
  'node_types': <String, dynamic>{
    // 欄位存在（即使為空）即表示路徑模式查詢可用（FR-06 規則 3）。
    'BuiltinType': <String, dynamic>{
      'id_pattern': r'^B-[0-9]+$',
      'carrier_path_patterns': <dynamic>[],
    },
  },
};

/// 計數替身：記錄 scanCorpus／buildGraph 被呼叫次數；掃描回一筆 003 破洞。
class _Counters {
  int scans = 0;
  int builds = 0;

  ScanCorpusFn get scanFn =>
      ({required fileSystem, required table, required builtinTable}) async {
        scans++;
        return fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')])
            .scan;
      };

  BuildGraphFn get buildFn =>
      ({
        required rawNodes,
        required projectSchemaJson,
        required builtinSchemaJson,
      }) {
        builds++;
        return fakeRound().graph;
      };
}

void main() {
  group('A1／A2：四種來源皆進報告頁狀態', () {
    test('A2 003、004、005、graphDefect 各至少一筆', () {
      final state = gapReportStateFromRound(
        fakeRound(
          parseFailureEvents: [fakeCarrierEvent('docs/spec/README.md')],
          flowEvents: [_flowEvent],
          nonDomainPathsEvent: fakeNonDomainPathsEvent(),
          graphDefects: [_danglingDefect()],
        ),
        nonDomainPathsKey: _key,
      );

      expect(state, isA<GapReportFound>());
      expect(
        _categoryIds(state),
        containsAll([
          gapCategoryIdParseFailure,
          gapCategoryIdFlowBlockMalformed,
          gapCategoryIdNonDomainPathsMalformed,
          gapCategoryIdGraphDefect,
        ]),
      );
    });

    test('A1（E1）零事件零缺陷 → 無破洞；同輪加一筆 003 → 有破洞，兩者不同', () {
      final clean = gapReportStateFromRound(
        fakeRound(),
        nonDomainPathsKey: _key,
      );
      final dirty = gapReportStateFromRound(
        fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
        nonDomainPathsKey: _key,
      );

      expect(clean, isA<GapReportNoGaps>());
      expect(dirty, isA<GapReportFound>());
    });

    test('A2（E2）路徑查詢不可用：003 不列，004／005 仍出現', () {
      final state = gapReportStateFromRound(
        fakeRound(
          pathSource: PathPatternSource.noPathPattern,
          parseFailureEvents: [fakeCarrierEvent('docs/spec/README.md')],
          flowEvents: [_flowEvent],
          nonDomainPathsEvent: fakeNonDomainPathsEvent(),
        ),
        nonDomainPathsKey: _key,
      );

      expect(state, isA<GapReportUndeterminable>());
      expect(
        _categoryIds(state),
        containsAll([
          gapCategoryIdFlowBlockMalformed,
          gapCategoryIdNonDomainPathsMalformed,
        ]),
      );
      expect(_categoryIds(state), isNot(contains(gapCategoryIdParseFailure)));
    });
  });

  group('A7：無法判定破洞', () {
    test('路徑查詢不可用的兩個原因碼各映射到對應原因', () {
      GapReportUndeterminable run(PathPatternSource source) =>
          gapReportStateFromRound(
            fakeRound(pathSource: source),
            nonDomainPathsKey: _key,
          ) as GapReportUndeterminable;

      expect(
        run(PathPatternSource.projectVersionOutOfKnownRange).reason,
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      );
      expect(
        run(PathPatternSource.noPathPattern).reason,
        UndeterminedGapReason.noPathPattern,
      );
    });

    for (final reason in EdgeTypeUnavailableReason.values) {
      test('建圖不可用 ${reason.name} → 專案版本不在已知範圍，其餘類別照列', () {
        final state = gapReportStateFromRound(
          fakeRound(
            graphUnavailable: reason,
            flowEvents: [_flowEvent],
            nonDomainPathsEvent: fakeNonDomainPathsEvent(),
          ),
          nonDomainPathsKey: _key,
        );

        expect(state, isA<GapReportUndeterminable>());
        expect(
          (state as GapReportUndeterminable).reason,
          UndeterminedGapReason.projectVersionOutOfKnownRange,
        );
        // 004 的 UC 在建圖不可用時由原始節點查得，不降級（E2）。
        final flow = state.categories.firstWhere(
          (c) => c.id == gapCategoryIdFlowBlockMalformed,
        );
        expect(flow.items.single.pointerType, GapItemPointerType.flow);
        expect(flow.items.single.isOpenable, isTrue);
        expect(
          state.categories.map((c) => c.id),
          contains(gapCategoryIdNonDomainPathsMalformed),
        );
      });
    }

    test('E1 建圖可用 → 不是無法判定；不可用 → 是', () {
      final available = gapReportStateFromRound(
        fakeRound(),
        nonDomainPathsKey: _key,
      );
      final unavailable = gapReportStateFromRound(
        fakeRound(graphUnavailable: EdgeTypeUnavailableReason.missingDirection),
        nonDomainPathsKey: _key,
      );

      expect(available, isNot(isA<GapReportUndeterminable>()));
      expect(unavailable, isA<GapReportUndeterminable>());
    });

    test('四個建圖原因碼的轉換結果相同（區分只留在日誌）', () {
      final reasons = {
        for (final r in EdgeTypeUnavailableReason.values)
          undeterminedReasonFromGraph(r),
      };

      expect(reasons, {UndeterminedGapReason.projectVersionOutOfKnownRange});
    });
  });

  group('A8：路徑模式取自內建表徽章旗標', () {
    test('E1 builtinTable → 旗標為真；projectJson → 為假', () {
      bool flagOf(PathPatternSource source, {bool withGap = false}) {
        final state = gapReportStateFromRound(
          fakeRound(
            pathSource: source,
            parseFailureEvents: withGap
                ? [fakeCarrierEvent('docs/a.md')]
                : const [],
          ),
          nonDomainPathsKey: _key,
        );
        return switch (state) {
          GapReportNoGaps(:final isPathPatternFromBuiltin) =>
            isPathPatternFromBuiltin,
          GapReportFound(:final isPathPatternFromBuiltin) =>
            isPathPatternFromBuiltin,
          _ => throw StateError('unexpected ${state.runtimeType}'),
        };
      }

      expect(flagOf(PathPatternSource.builtinTable), isTrue);
      expect(flagOf(PathPatternSource.builtinTable, withGap: true), isTrue);
      expect(flagOf(PathPatternSource.projectJson), isFalse);
      expect(flagOf(PathPatternSource.projectJson, withGap: true), isFalse);
    });
  });

  group('A3\'／A6／A10：報告頁讀共用輪次', () {
    testWidgets('A3\' E1 已有完成輪次：首次可見不重掃、直接呈現', (tester) async {
      final withRound = FakeScanRound(
        initial: fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
        produce: fakeRound,
      );
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => withRound)],
      );
      final state = container.read(gapReportProvider);

      expect(withRound.produced, 0);
      expect(state, isA<GapReportFound>());
    });

    testWidgets('A3\' E1 無輪次：首次可見由輪次擁有者產生一次', (tester) async {
      final noRound = FakeScanRound(
        produce: () =>
            fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => noRound)],
      );
      expect(container.read(gapReportProvider), isA<GapReportScanning>());
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(noRound.produced, 1);
      expect(noRound.rescanCalls, 0);
      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('A6 重新掃描走 rescan()，呈現新輪次結果', (tester) async {
      var round = fakeRound(
        parseFailureEvents: [fakeCarrierEvent('docs/a.md')],
      );
      final fake = FakeScanRound(produce: () => round);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportFound>());

      round = fakeRound();
      container.read(gapReportProvider.notifier).rescan();
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(fake.rescanCalls, 1);
      expect(container.read(gapReportProvider), isA<GapReportNoGaps>());
    });

    testWidgets('A6 ensureRound() 回 null：不崩潰、不顯示舊輪結果（首次）', (tester) async {
      final fake = FakeScanRound(produce: () => null);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());
    });

    testWidgets('A6 rescan() 回 null：舊輪結果被丟棄而非保留', (tester) async {
      ScanRoundResult? next = fakeRound(
        parseFailureEvents: [fakeCarrierEvent('docs/a.md')],
      );
      final fake = FakeScanRound(produce: () => next);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportFound>());

      next = null;
      container.read(gapReportProvider.notifier).rescan();
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());
    });

    testWidgets('A10 掃描早於下限完成：載入態存續至 Motion.spinnerMinVisible', (tester) async {
      final fake = FakeScanRound(produce: () => fakeRound());
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);
      await tester.pump(
        Motion.spinnerMinVisible - const Duration(milliseconds: 1),
      );
      expect(container.read(gapReportProvider), isA<GapReportScanning>());

      await tester.pump(const Duration(milliseconds: 1));

      expect(container.read(gapReportProvider), isA<GapReportNoGaps>());
    });

    testWidgets('A10（E1）真實耗時長於下限：取較長者而非疊加', (tester) async {
      final slow = Motion.spinnerMinVisible * 2;
      final fake = FakeScanRound(produce: () => fakeRound(), latency: slow);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);

      await tester.pump(Motion.spinnerMinVisible);
      expect(
        container.read(gapReportProvider),
        isA<GapReportScanning>(),
        reason: '輪次尚未完成，不因下限到了就結束載入態',
      );
      await tester.pump(slow - Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportNoGaps>());
    });

    testWidgets('取消：進行中的輪次被丟棄，完成回呼不覆蓋取消態（C6）', (tester) async {
      final fake = FakeScanRound(
        produce: () => fakeRound(),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(gapReportProvider.notifier);
      await tester.pump();

      container.read(gapReportProvider.notifier).cancelScan();
      // 輪次完成時刻（300ms）早於取消導覽時限（500ms）：此時斷言取消態。
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(fake.discardCalls, 1);
      expect(container.read(scanRoundProvider), isA<ScanRoundIdle>());
      final state = container.read(gapReportProvider);
      expect(state, isA<GapReportScanning>());
      expect((state as GapReportScanning).isCancelling, isTrue);
      await tester.pump(Motion.cancelDeadline);
    });
  });

  group('輪次取不到後的恢復與工作區切換', () {
    const wsA = WorkspaceReady('/ws/a');
    const wsB = WorkspaceReady('/ws/b');

    testWidgets('必修1 E1 輪次 null 後工作區轉 ready：頁面再出結果', (tester) async {
      var ready = false;
      final fake = FakeScanRound(
        produce: () => ready
            ? fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')])
            : null,
      );
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.listen(gapReportProvider, (_, _) {});
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());

      ready = true;
      container.read(currentWorkspaceStateProvider.notifier).state = wsA;
      await tester.pump();
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('必修1 E1 對照：工作區未變、無他人輪次 → 維持專案未就緒', (tester) async {
      final fake = FakeScanRound(produce: () => null);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.listen(gapReportProvider, (_, _) {});
      await pumpContract(tester, Motion.spinnerMinVisible);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());
      expect(fake.produced, 1, reason: '沒有恢復條件時不得自行重掃');
    });

    testWidgets('必修1 其他消費者完成同工作區輪次：直接呈現', (tester) async {
      final fake = FakeScanRound(produce: () => null);
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [_onGaps, scanRoundProvider.overrideWith(() => fake)],
      );
      container.listen(gapReportProvider, (_, _) {});
      await pumpContract(tester, Motion.spinnerMinVisible);

      fake.completeExternally(
        fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      await tester.pump();

      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('必修2 A→B（皆 ready）：A 的結果不殘留，呈現 B 的結果', (tester) async {
      var current = 'a';
      final fake = FakeScanRound(
        produce: () => current == 'a'
            ? fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')])
            : fakeRound(flowEvents: [_flowEvent]),
      );
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: [
          _onGaps,
          scanRoundProvider.overrideWith(() => fake),
          currentWorkspaceStateProvider.overrideWith((ref) => wsA),
        ],
      );
      container.listen(gapReportProvider, (_, _) {});
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(_categoryIds(container.read(gapReportProvider)), [
        gapCategoryIdParseFailure,
      ]);

      current = 'b';
      container.read(currentWorkspaceStateProvider.notifier).state = wsB;
      await tester.pump();
      expect(
        container.read(gapReportProvider),
        isA<GapReportScanning>(),
        reason: '切換當下不得保留 A 的結果',
      );
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(_categoryIds(container.read(gapReportProvider)), [
        gapCategoryIdFlowBlockMalformed,
      ]);
    });
  });

  group('B／D／E：輪次三種回應、取消後恢復、離開再回到本頁', () {
    const wsA = WorkspaceReady('/ws/a');
    final wsOverride = currentWorkspaceStateProvider.overrideWith((ref) => wsA);

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

    testWidgets('B1 工作區不是 Ready → 專案未就緒（不接續新輪次）', (tester) async {
      final fake = FakeScanRound(produce: () => null);
      final container = await pumpWith(tester, fake);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());
      expect(fake.produced, 1);
    });

    testWidgets('B2 輪次等待中被丟棄 → 接續新輪次並呈現其結果', (tester) async {
      final fake = FakeScanRound(
        produce: () =>
            fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await tester.pump();
      // 他人在本頁等待期間重掃：舊輪被丟棄（ensureRound 回 null），新輪開始。
      unawaited(fake.rescan());
      await pumpContract(tester, Motion.spinnerMinVisible);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportFound>());
      expect(fake.produced, 2, reason: '接續共用新輪，不另開第三輪');
    });

    testWidgets('B2 連續被丟棄 5 次仍接續到最後一輪並呈現結果（無次數上限）', (tester) async {
      final fake = FakeScanRound(
        produce: () =>
            fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        unawaited(fake.rescan());
        await tester.pump(const Duration(milliseconds: 100));
      }
      await pumpContract(tester, Motion.spinnerMinVisible * 2);

      expect(container.read(gapReportProvider), isA<GapReportFound>());
      expect(fake.produced, 6);
    });

    testWidgets('B2 E1 輪次因取消被丟棄時不接續（不再開新輪）', (tester) async {
      final fake = FakeScanRound(
        produce: () => fakeRound(),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await tester.pump();

      container.read(gapReportProvider.notifier).cancelScan();
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(fake.discardCalls, 1);
      expect(fake.produced, 1, reason: '取消者自己丟棄輪次，不得接續開新輪');
      await tester.pump(Motion.cancelDeadline);
    });

    testWidgets('B2 E1 接續期間工作區切走時不接續', (tester) async {
      final fake = FakeScanRound(
        produce: () => fakeRound(),
        latency: Motion.spinnerMinVisible,
      );
      // 工作區維持預設（非 Ready），其就緒路徑鍵不變，本頁不會因重建而
      // 換代，單獨檢驗「工作區不是 Ready」這道守衛：拿掉它，本頁會接續
      // 他人開的新輪並呈現 Found。
      final container = await pumpWith(tester, fake);
      await tester.pump(const Duration(milliseconds: 100));

      unawaited(fake.rescan());
      // t=350ms：本頁原輪次（300ms）已作廢，外部新輪（400ms）尚未完成。
      await tester.pump(const Duration(milliseconds: 250));

      expect(fake.produced, 2, reason: '只有外部那一次重掃，本頁不接續');
      expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());
      // 外部輪次之後完成：同工作區輪次由等待中的本頁直接呈現（恢復路徑）。
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(gapReportProvider), isA<GapReportNoGaps>());
    });

    testWidgets('B3 輪次拋出非預期例外 → 無法判定破洞（掃描失敗）', (tester) async {
      final fake = FakeScanRound(produce: () => throw StateError('boom'));
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(
        container.read(scanRoundProvider),
        isA<ScanRoundIdle>(),
        reason: '失敗後輪次狀態回 Idle，與真實擁有者一致',
      );

      final state = container.read(gapReportProvider);
      expect(state, isA<GapReportUndeterminable>());
      expect((state as GapReportUndeterminable).isScanFailure, isTrue);
    });

    testWidgets('B3 畫面顯示掃描失敗原因說明', (tester) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(const GapReportUndeterminable.scanFailed()),
          ),
        ],
      );

      expect(
        find.text(AppLocalizationsZh().gapsUndeterminableReasonScanFailed),
        findsOneWidget,
      );
    });

    testWidgets('D 取消 → 離開 → 回到本頁會重新掃描，不停在取消中', (tester) async {
      final fake = FakeScanRound(
        produce: () => fakeRound(),
        latency: Motion.spinnerMinVisible,
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await tester.pump();

      container.read(gapReportProvider.notifier).cancelScan();
      await tester.pump(Motion.cancelDeadline);
      await tester.pump();
      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );

      container.read(selectedDestinationProvider.notifier).state =
          AppDestination.gaps;
      await tester.pump();
      await pumpContract(tester, Motion.spinnerMinVisible * 2);

      expect(container.read(gapReportProvider), isA<GapReportNoGaps>());
      expect(fake.produced, 2);
    });

    testWidgets('E(a) 完成後離開再回到本頁：維持結果、不重掃', (tester) async {
      final fake = FakeScanRound(
        produce: () =>
            fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await pumpContract(tester, Motion.spinnerMinVisible);
      final selected = container.read(selectedDestinationProvider.notifier);

      selected.state = AppDestination.domain;
      await tester.pump();
      selected.state = AppDestination.gaps;
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportFound>());
      expect(fake.produced, 1);
    });

    testWidgets('E(a) 未就緒後工作區轉 ready，離開再回到本頁：恢復出結果', (tester) async {
      var ready = false;
      final fake = FakeScanRound(
        produce: () => ready
            ? fakeRound(parseFailureEvents: [fakeCarrierEvent('d')])
            : null,
      );
      final container = await pumpWith(tester, fake);
      await pumpContract(tester, Motion.spinnerMinVisible);
      final selected = container.read(selectedDestinationProvider.notifier);

      selected.state = AppDestination.domain;
      await tester.pump();
      ready = true;
      selected.state = AppDestination.gaps;
      await pumpContract(tester, Motion.spinnerMinVisible);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('E(b) 不在等待輪次時忽略他人完成的輪次（拿掉守衛會紅）', (tester) async {
      final fake = FakeScanRound(
        produce: () =>
            fakeRound(parseFailureEvents: [fakeCarrierEvent('docs/a.md')]),
      );
      final container = await pumpWith(tester, fake, extra: [wsOverride]);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportFound>());

      fake.completeExternally(fakeRound());
      await tester.pump();

      expect(
        container.read(gapReportProvider),
        isA<GapReportFound>(),
        reason: '本頁已有自己的結果，他人的無破洞輪次不得覆蓋',
      );
    });
  });

  group('真實輪次擁有者（計數替身掛在 scanCorpus／buildGraph）', () {
    List<Override> wired(_Counters counters) => [
      _onGaps,
      scanCorpusFnProvider.overrideWithValue(counters.scanFn),
      buildGraphFnProvider.overrideWithValue(counters.buildFn),
      docsFileSystemFactoryProvider.overrideWithValue(
        // 專案型別表自帶（空）路徑模式欄位 → 查詢可用，不落入無法判定。
        (_) => FakeDocsFileSystem()
          ..addFile(
            projectSchemaRelativePath,
            utf8.encode(jsonEncode(_builtinJson)),
          ),
      ),
      builtinTrackingSchemaJsonProvider.overrideWith((ref) => _builtinJson),
      currentWorkspaceStateProvider.overrideWith(
        (ref) => const WorkspaceReady('/ws/a'),
      ),
    ];

    testWidgets('A3 報告頁與第二個消費者共用同一輪：掃描與建圖各一次', (tester) async {
      final counters = _Counters();
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: wired(counters),
      );
      container.read(gapReportProvider.notifier);
      final second = container.read(scanRoundProvider.notifier).ensureRound();
      await pumpContract(tester, Motion.spinnerMinVisible);
      await second;

      expect(container.read(gapReportProvider), isA<GapReportFound>());
      expect([counters.scans, counters.builds], [1, 1]);
    });

    testWidgets('A3 E1 第二個消費者先建立輪次：報告頁首次可見不再掃描', (tester) async {
      final counters = _Counters();
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: wired(counters),
      );
      await tester.runAsync(
        () => container.read(scanRoundProvider.notifier).ensureRound(),
      );
      expect([counters.scans, counters.builds], [1, 1]);

      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect([counters.scans, counters.builds], [1, 1]);
      expect(container.read(gapReportProvider), isA<GapReportFound>());
    });

    testWidgets('A6 rescan() 開新輪：掃描與建圖各增一次', (tester) async {
      final counters = _Counters();
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: wired(counters),
      );
      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);

      container.read(gapReportProvider.notifier).rescan();
      await pumpContract(tester, Motion.spinnerMinVisible);

      expect([counters.scans, counters.builds], [2, 2]);
    });
  });

  group('畫面：無法判定、徽章、項目說明', () {
    testWidgets('A7 state-gaps-undeterminable：原因說明二選一且與無破洞不同', (tester) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(
              const GapReportUndeterminable(
                reason: UndeterminedGapReason.noPathPattern,
                categories: [
                  GapReportCategory(
                    id: gapCategoryIdFlowBlockMalformed,
                    items: [GapReportItem(id: 'flow-a', filePath: fakeUcPath)],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      final l10n = AppLocalizationsZh();

      expect(
        find.byKey(const Key('state-gaps-undeterminable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('state-gaps-none')), findsNothing);
      expect(find.text(l10n.gapsUndeterminableTitle), findsOneWidget);
      expect(
        find.text(l10n.gapsUndeterminableReasonNoPathPattern),
        findsOneWidget,
      );
      expect(
        find.text(l10n.gapsUndeterminableReasonVersionOutOfRange),
        findsNothing,
      );
      expect(find.byKey(const Key('card-gaps-flow-a')), findsOneWidget);
    });

    testWidgets('A7 原因為版本不在已知範圍時顯示另一則說明', (tester) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(
              const GapReportUndeterminable(
                reason: UndeterminedGapReason.projectVersionOutOfKnownRange,
              ),
            ),
          ),
        ],
      );

      expect(
        find.text(
          AppLocalizationsZh().gapsUndeterminableReasonVersionOutOfRange,
        ),
        findsOneWidget,
      );
    });

    testWidgets('A8 E1 旗標為真顯示徽章、為假不顯示（有破洞與無破洞兩列）', (tester) async {
      Future<void> pumpState(GapReportState state) async {
        // 先卸載上一棵樹：同型別的 ProviderScope 會沿用舊 overrides。
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpHarness(
          tester,
          child: const GapReportScreen(),
          overrides: [
            gapReportProvider.overrideWith(() => _FixedNotifier(state)),
          ],
        );
      }

      const badge = Key('badge-gaps-builtin-path-pattern');
      const items = [
        GapReportCategory(
          id: gapCategoryIdParseFailure,
          items: [GapReportItem(id: 'a', filePath: 'docs/a.md')],
        ),
      ];

      await pumpState(
        const GapReportFound(items, isPathPatternFromBuiltin: true),
      );
      expect(find.byKey(badge), findsOneWidget);
      await pumpState(const GapReportFound(items));
      expect(find.byKey(badge), findsNothing);
      await pumpState(const GapReportNoGaps(isPathPatternFromBuiltin: true));
      expect(find.byKey(badge), findsOneWidget);
      await pumpState(const GapReportNoGaps());
      expect(find.byKey(badge), findsNothing);
    });

    testWidgets('C 主文字是項目說明，次文字（caption）是路徑與行號', (tester) async {
      final state = gapReportStateFromRound(
        fakeRound(
          parseFailureEvents: [fakeCarrierEvent('docs/spec/README.md')],
        ),
        nonDomainPathsKey: _key,
      );
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(state)),
        ],
      );
      final description = AppLocalizationsZh().gapParseNoFrontmatter;

      final primary = tester.widget<AppText>(
        find.widgetWithText(AppText, description),
      );
      final secondary = tester.widget<AppText>(
        find.widgetWithText(AppText, 'docs/spec/README.md'),
      );

      expect(primary.variant, isNot(AppTextVariant.caption));
      expect(secondary.variant, AppTextVariant.caption);
    });

    testWidgets('6 E1 有說明兩行、沒有說明一行（路徑與行號在主文字、無次文字）', (tester) async {
      Future<int> textCountOf(GapReportItem item) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpHarness(
          tester,
          child: const GapReportScreen(),
          overrides: [
            gapReportProvider.overrideWith(
              () => _FixedNotifier(
                GapReportFound([
                  GapReportCategory(
                    id: gapCategoryIdParseFailure,
                    items: [item],
                  ),
                ]),
              ),
            ),
          ],
        );
        return find
            .descendant(
              of: find.byKey(Key('card-gaps-${item.id}')),
              matching: find.byType(AppText),
            )
            .evaluate()
            .length;
      }

      final withDescription = await textCountOf(
        const GapReportItem(
          id: 'd',
          filePath: 'docs/a.md',
          lineNumber: 3,
          description: GapItemDescription(
            GapDescriptionKind.parseNoFrontmatter,
          ),
        ),
      );
      expect(
        tester
            .widget<AppText>(find.widgetWithText(AppText, 'docs/a.md · 第 3 行'))
            .variant,
        AppTextVariant.caption,
      );

      final withoutDescription = await textCountOf(
        const GapReportItem(id: 'n', filePath: 'docs/a.md', lineNumber: 3),
      );
      expect(
        tester
            .widget<AppText>(find.widgetWithText(AppText, 'docs/a.md · 第 3 行'))
            .variant,
        AppTextVariant.mono,
      );

      expect(withDescription, 2);
      expect(withoutDescription, 1);
    });

    testWidgets('A9 項目說明與歸屬型別不明附註以 l10n 渲染', (tester) async {
      final state = gapReportStateFromRound(
        fakeRound(parseFailureEvents: [_ambiguousEvent()]),
        nonDomainPathsKey: _key,
      );
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(state)),
        ],
      );
      final l10n = AppLocalizationsZh();

      expect(
        find.textContaining(l10n.gapParseNoFrontmatter, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          l10n.gapParseTypeAmbiguous('SPEC、UC'),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });

  group('R2-6～R2-8 事件類項目的輪次接線（SPEC-001 §3.6）', () {
    final bundles = [bundleNode('alpha'), bundleNode('beta')];

    RawNode uc(List<Map<String, dynamic>> steps) => RawNode(
      path: 'docs/usecases/UC-02-assess-change-impact-by-domain.md',
      frontmatter: {'id': 'UC-02'},
      typeName: 'UC',
      flowSteps: steps,
    );
    RawNode evt(String id, {List<String> consumers = const []}) => RawNode(
      path: 'docs/events/x/$id-slug.md',
      frontmatter: {
        'id': id,
        'category': 'domain_event',
        'producers': const <String>[],
        'consumers': consumers,
      },
      typeName: 'EVT',
    );
    Map<String, dynamic> step(String id, String emits, String traverse) => {
      'id': id,
      'emits': [emits],
      'traverses': [traverse],
    };

    ScanRoundResult round(
      List<RawNode> rawNodes, {
      EdgeTypeUnavailableReason? unavailable,
      PathPatternSource source = PathPatternSource.projectJson,
    }) => fakeRound(
      nodes: const [],
      extraRawNodes: rawNodes,
      pathSource: source,
      graphOverride: unavailable != null
          ? GraphBuildUnavailable(unavailable)
          : buildResultOf(rawNodes),
    );

    List<RawNode> orphanCorpus() => [
      ...bundles,
      uc([step('a', 'EVT-X-001', 'alpha')]),
      evt('EVT-X-001'),
    ];

    List<String> itemIds(GapReportState s, String category) => switch (s) {
      GapReportFound(:final categories) ||
      GapReportUndeterminable(:final categories) => [
        for (final c in categories)
          if (c.id == category) ...c.items.map((i) => i.id),
      ],
      _ => const [],
    };

    test('R2-6（E2）建圖不可用時事件分節不出現；同語料建圖可用則有一項', () {
      final unavailable = gapReportStateFromRound(
        round(
          orphanCorpus(),
          unavailable: EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
        ),
        nonDomainPathsKey: _key,
      );
      expect(unavailable, isA<GapReportUndeterminable>());
      expect(
        (unavailable as GapReportUndeterminable).reason,
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      );
      expect(_categoryIds(unavailable), isNot(contains('orphan-event')));
      expect(
        _categoryIds(unavailable),
        isNot(contains('event-declaration-mismatch')),
      );

      final available = gapReportStateFromRound(
        round(orphanCorpus()),
        nonDomainPathsKey: _key,
      );
      expect(itemIds(available, 'orphan-event'), ['orphan-event:EVT-X-001']);
    });

    test('R2-7 路徑模式查詢不可用、建圖可用：無法判定且孤立事件照常列出', () {
      final state = gapReportStateFromRound(
        round(orphanCorpus(), source: PathPatternSource.noPathPattern),
        nonDomainPathsKey: _key,
      );
      expect(state, isA<GapReportUndeterminable>());
      expect(itemIds(state, 'orphan-event'), ['orphan-event:EVT-X-001']);
    });

    test('R2-8 三類並存：分節順序依 O1，事件類項目計入破洞數', () {
      final corpus = [
        ...bundles,
        uc([
          step('a', 'EVT-X-001', 'alpha'),
          step('b', 'EVT-X-002', 'alpha'),
          step('c', 'EVT-X-001', 'gamma'),
        ]),
        evt('EVT-X-001'),
        evt('EVT-X-002', consumers: ['beta']),
      ];
      final state = gapReportStateFromRound(
        round(corpus),
        nonDomainPathsKey: _key,
      );
      expect(state, isA<GapReportFound>());
      final ids = _categoryIds(state);
      expect(ids, [
        'graph-defect-flow',
        'orphan-event',
        'event-declaration-mismatch',
      ]);
      final found = state as GapReportFound;
      // 步驟 c 的 traverses 含未宣告值 gamma：flow 子類 1 項。
      expect(itemIds(state, 'graph-defect-flow'), hasLength(1));
      expect(itemIds(state, 'orphan-event'), ['orphan-event:EVT-X-001']);
      expect(itemIds(state, 'event-declaration-mismatch'), [
        'event-declaration-mismatch:EVT-X-002:consumers:beta',
      ]);
      expect(found.categories.fold<int>(0, (n, c) => n + c.items.length), 3);
    });
  });
}

ParseFailureEvent _ambiguousEvent() => ParseFailureEvent(
  path: 'docs/spec/README.md',
  reason: 'noFrontmatter',
  failureReason: CarrierParseFailureReason.noFrontmatter,
  candidateTypes: const ['SPEC', 'UC'],
  schemaAmbiguous: true,
  salvagedFields: const [],
  lostFields: const [],
  severity: ParseFailureSeverity.edgeAffecting,
);

class _FixedNotifier extends GapReportNotifier {
  _FixedNotifier(this._fixed);

  final GapReportState _fixed;

  @override
  GapReportState build() => _fixed;
}
