// 需求：0.6.0-W1-080 B9；SPEC-006 FR-11 規則 1、10 與對應驗收條件。
// 就緒閘門在 ScanRoundNotifier.ensureRound（所有首輪路徑共用）。
// 「E2」標註正向對照輸入（test-assertion-design-rules）。逾時以注入時鐘推進。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/corpus_watcher_provider.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/app/domain_view_loader.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/fake_watch_source.dart';
import '../../helpers/manual_debounce_clock.dart';
import '../../helpers/spec006/fake_docs_fs.dart';

const _builtinJson = <String, dynamic>{
  'schema_generated_at_framework_version': '1.0.0',
  'node_types': <String, dynamic>{
    'BuiltinType': <String, dynamic>{'id_pattern': r'^B-[0-9]+$'},
  },
};

const _emptySummary = ScanSummary(
  totalFilesScanned: 0,
  nodeCount: 0,
  nonNodeWithFrontmatterCount: 0,
  failureReasonCounts: <ParseResultKind, int>{},
  hitCarrierCount: 0,
  noHitCount: 0,
  undeterminedCount: 0,
  carrierPathQueryAvailable: false,
);

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [
        watchSourceProvider.overrideWithValue(source),
        watchClockProvider.overrideWithValue(clock),
        scanCorpusFnProvider.overrideWithValue(({
          required fileSystem,
          required table,
          required builtinTable,
        }) async {
          scans++;
          return const CorpusScanResult(
            rawNodes: <RawNode>[],
            parseErrors: <ParseError>[],
            parseFailureEvents: [],
            schemaAmbiguousNodes: [],
            summary: _emptySummary,
          );
        }),
        buildGraphFnProvider.overrideWithValue(
          ({
            required rawNodes,
            required projectSchemaJson,
            required builtinSchemaJson,
          }) => const GraphBuildUnavailable(
            EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
          ),
        ),
        docsFileSystemFactoryProvider.overrideWithValue(
          (_) => FakeDocsFileSystem(),
        ),
        builtinTrackingSchemaJsonProvider.overrideWith((ref) => _builtinJson),
        builtinSchemaVersionProvider.overrideWith((ref) async => '1.0.0'),
      ],
    );
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws');
    container.listen(scanRoundProvider, (_, _) {});
  }

  final FakeWatchSource source = FakeWatchSource();
  final ManualDebounceClock clock = ManualDebounceClock();
  late final ProviderContainer container;
  int scans = 0;

  ScanRoundNotifier get rounds => container.read(scanRoundProvider.notifier);
  CorpusWatcher get watcher => container.read(corpusWatcherProvider);

  Future<void> settle() => pumpEventQueue();
}

void main() {
  late _Harness h;
  late Completer<void> ready;

  setUp(() {
    h = _Harness();
    addTearDown(h.container.dispose);
    ready = Completer<void>();
  });

  test('E2 正向對照：監看就緒已完成時，ensureRound 立即開始掃描', () async {
    await h.watcher.start('/ws');
    await h.settle();
    unawaited(h.rounds.ensureRound());
    await h.settle();
    expect(h.scans, 1);
  });

  test('實驗組：就緒前 ensureRound 不掃描且佔住進行中狀態，就緒後才掃描', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    final first = h.rounds.ensureRound();
    final second = h.rounds.ensureRound();
    await h.settle();
    expect(h.scans, 0);
    expect(h.container.read(scanRoundProvider), isA<ScanRoundRunning>());
    ready.complete();
    final results = await Future.wait([first, second]);
    expect(h.scans, 1);
    expect(results.first, isNotNull);
    expect(identical(results.first, results.last), isTrue);
  });

  test('對照組：manual（rescan）在就緒前照常開始', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    unawaited(h.rounds.rescan());
    await h.settle();
    expect(h.scans, 1);
  });

  test('Domain 路徑：domainViewLoader.load 經 ensureRound，就緒前不掃描', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    final loading = h.container.read(domainViewLoaderProvider.notifier).load();
    await h.settle();
    expect(h.scans, 0);
    ready.complete();
    await loading;
    expect(h.scans, 1);
  });

  test('F2：等待就緒期間 discard，就緒後不開輪', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    final waiting = h.rounds.ensureRound();
    await h.settle();
    h.rounds.discard('cancel');
    ready.complete();
    expect(await waiting, isNull);
    await h.settle();
    expect(h.scans, 0);
    expect(h.container.read(scanRoundProvider), isA<ScanRoundIdle>());
  });

  test('F3：就緒逾時視同失敗，停止監看，等待中的首輪照常開始', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    final waiting = h.rounds.ensureRound();
    await h.settle();
    h.clock.advance(watchReadyTimeout - const Duration(milliseconds: 1));
    await h.settle();
    expect(h.scans, 0);
    expect(h.watcher.isWatching, isTrue);
    h.clock.advance(const Duration(milliseconds: 1));
    expect(await waiting, isNotNull);
    expect(h.scans, 1);
    expect(h.watcher.isWatching, isFalse);
  });

  test('驗收：首輪等待就緒時取消，就緒後不掃描、不發完成事件', () async {
    h.source.readyBuilder = (_) => ready.future;
    final controller = h.container.read(corpusWatchProvider);
    await h.settle();
    final events = <WatchRoundEvent>[];
    controller.events.listen(events.add);
    controller.scheduler.request(ScanTrigger.visibility);
    await h.settle();
    controller.scheduler.cancel();
    h.rounds.discard('cancel');
    ready.complete();
    await h.settle();
    expect(h.scans, 0);
    expect(events.whereType<WatchRoundCompleted>(), isEmpty);
  });

  test('規則 10：就緒失敗時首輪照常開始', () async {
    h.source.readyBuilder = (_) => Future<void>.error(StateError('boom'));
    await h.watcher.start('/ws');
    expect(await h.rounds.ensureRound(), isNotNull);
    expect(h.scans, 1);
  });

  test('F3 對照：就緒在逾時前完成，不停止監看', () async {
    h.source.readyBuilder = (_) => ready.future;
    await h.watcher.start('/ws');
    ready.complete();
    await h.settle();
    h.clock.advance(watchReadyTimeout * 2);
    expect(h.watcher.isWatching, isTrue);
  });
}
