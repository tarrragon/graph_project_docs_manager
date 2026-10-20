/// 破洞報告頁測試用的共用輪次替身（0.5.0-W1-114.15）。
///
/// [FakeScanRound] 取代 `scanRoundProvider` 的擁有者，記錄各入口的呼叫次數；
/// [fakeRound] 建出不經真實檔案系統的 `ScanRoundResult`。畫面層的測試只需
/// 關心輪次結果，不重測 `scan_round_test.dart` 已覆蓋的輪次生命週期。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// 測試用 UC 節點（004 破洞指向它；`flowUcId` 為此 id）。
const fakeUcNode = LightNode(
  id: 'UC-01',
  typeName: 'UC',
  status: null,
  title: null,
  path: 'docs/usecases/UC-01.md',
);

const fakeUcPath = 'docs/usecases/UC-01.md';

/// 003 破洞用的缺 frontmatter 事件。
ParseFailureEvent fakeCarrierEvent(String path) => ParseFailureEvent(
  path: path,
  reason: 'noFrontmatter',
  failureReason: CarrierParseFailureReason.noFrontmatter,
  candidateTypes: const ['SPEC'],
  schemaAmbiguous: false,
  salvagedFields: const [],
  lostFields: const [],
  severity: ParseFailureSeverity.edgeAffecting,
);

/// 005 破洞用事件（`keyMissing`，說明帶鍵名）。
NonDomainPathsParseFailedEvent fakeNonDomainPathsEvent() =>
    NonDomainPathsReadMalformed(
      path: 'docs/non-domain.yaml',
      reason: NonDomainPathsWholeFileReason.keyMissing,
    ).malformedEvent;

/// 005 事件 → 產生該事件的讀取結果（無事件為缺席）。
NonDomainPathsReadResult _readOfEvent(NonDomainPathsParseFailedEvent? e) {
  if (e == null) return const NonDomainPathsReadAbsent();
  if (e.reason == NonDomainPathsMalformedReason.elementNotString) {
    return NonDomainPathsReadDeclaredWithBadElements(
      path: e.path,
      patterns: const [],
      nonStringElementCount: e.nonStringElementCount!,
    );
  }
  return NonDomainPathsReadMalformed(
    path: e.path,
    reason: NonDomainPathsWholeFileReason.values.firstWhere(
      (r) => r.eventReason == e.reason,
    ),
  );
}

/// 一份已完成輪次結果；預設為「路徑查詢可用、建圖可用、零破洞」。
ScanRoundResult fakeRound({
  List<ParseFailureEvent> parseFailureEvents = const [],
  List<FlowParseFailedEvent> flowEvents = const [],
  NonDomainPathsParseFailedEvent? nonDomainPathsEvent,
  List<GraphDefect> graphDefects = const [],
  EdgeTypeUnavailableReason? graphUnavailable,
  PathPatternSource pathSource = PathPatternSource.projectJson,
  List<LightNode> nodes = const [fakeUcNode],
  bool isDegraded = false,
  GraphBuiltEvent? event,
  List<RawNode> extraRawNodes = const [],
  NonDomainPathsReadResult? nonDomainRead,
}) {
  final scan = CorpusScanResult(
    rawNodes: [
      for (final n in nodes)
        RawNode(path: n.path, frontmatter: {'id': n.id}, typeName: n.typeName),
      ...extraRawNodes,
    ],
    nonDomainPathsRead: nonDomainRead ?? _readOfEvent(nonDomainPathsEvent),
    parseErrors: const [],
    parseFailureEvents: parseFailureEvents,
    schemaAmbiguousNodes: const [],
    summary: const ScanSummary(
      totalFilesScanned: 0,
      nodeCount: 0,
      nonNodeWithFrontmatterCount: 0,
      failureReasonCounts: <ParseResultKind, int>{},
      hitCarrierCount: 0,
      noHitCount: 0,
      undeterminedCount: 0,
      carrierPathQueryAvailable: true,
    ),
    flowParseFailedEvents: flowEvents,
  );
  return ScanRoundResult(
    workspacePath: '/ws/fake',
    scan: scan,
    graph: graphUnavailable != null
        ? GraphBuildUnavailable(graphUnavailable)
        : GraphBuildAvailable(
            event ??
                GraphBuiltEvent(
                  nodes: nodes,
                  edges: const [],
                  graphDefects: graphDefects,
                  totalReferences: 0,
                  resolvedCount: 0,
                ),
          ),
    schemaResolution: SchemaSourceResolution(
      typeTable: const TypeTable(
        {},
        nonDomainPathsKey: 'non_domain_path_patterns',
      ),
      pathPatternSource: pathSource,
    ),
    isDegraded: isDegraded,
  );
}

/// gate 通過後 Domain 視圖載入走共用輪次（0.5.0-W1-114.14）；經 shell／gate
/// 啟動的測試以此取代真實掃描，輪次為「建圖可用、有節點」。
///
/// 輪次的降級與否於產生當下讀 `degradedSchemaProvider`（對齊真實擁有者
/// `_runRound`），不由呼叫端寫死：降級動作若未設旗標，輪次即非降級。
Override fakeScanRoundOverride() => scanRoundProvider.overrideWith(() {
  late final FakeScanRound fake;
  fake = FakeScanRound(produce: () => fakeRound(isDegraded: fake.degradedFlag));
  return fake;
});

/// `scanRoundProvider` 替身。[produce] 回傳 `null` 代表輪次不可用（非
/// WorkspaceReady 或等待中被丟棄）；[latency] 為每次產生輪次的假時鐘耗時。
class FakeScanRound extends ScanRoundNotifier {
  FakeScanRound({
    required this.produce,
    this.initial,
    this.latency = Duration.zero,
  });

  ScanRoundResult? Function() produce;
  final ScanRoundResult? initial;
  final Duration latency;

  int ensureCalls = 0;
  int rescanCalls = 0;
  int discardCalls = 0;

  /// 實際產生輪次（即「掃描函式被呼叫」）的次數。
  int produced = 0;

  /// 目前的降級旗標（`degradedSchemaProvider`）。
  bool get degradedFlag => ref.read(degradedSchemaProvider);

  @override
  ScanRoundState build() {
    // 對齊真實擁有者：工作區路徑變更即丟棄現有輪次。
    ref.listen<WorkspaceState>(currentWorkspaceStateProvider, (prev, next) {
      final same =
          prev is WorkspaceReady &&
          next is WorkspaceReady &&
          prev.path == next.path;
      if (!same) discard('workspace-changed');
    });
    return initial == null
        ? const ScanRoundIdle()
        : ScanRoundCompleted(initial!);
  }

  @override
  Future<ScanRoundResult?> ensureRound() {
    ensureCalls++;
    final current = state;
    if (current is ScanRoundCompleted) return Future.value(current.result);
    // 對齊真實擁有者：進行中的輪次共用，不重複產生。
    return _inFlight ??= _produceRound();
  }

  @override
  Future<ScanRoundResult?> rescan() {
    rescanCalls++;
    discard('rescan');
    return _inFlight = _produceRound();
  }

  Future<ScanRoundResult?>? _inFlight;

  /// 模擬其他消費者（如 Domain 視圖）完成了一輪。
  void completeExternally(ScanRoundResult result) {
    state = ScanRoundCompleted(result);
  }

  @override
  void discard([String reason = 'cancel']) {
    discardCalls++;
    _generation++;
    _inFlight = null;
    state = const ScanRoundIdle();
  }

  /// 對齊真實 `_runGuarded`：輪次進行中被 discard 即作廢，回傳 `null`
  /// 且不寫回狀態。
  int _generation = 0;

  Future<ScanRoundResult?> _produceRound() async {
    produced++;
    final generation = ++_generation;
    state = const ScanRoundRunning('/ws/fake');
    // 讓出一個 microtask，確保呼叫端先登記 _inFlight 再完成。
    await Future<void>.value();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (generation != _generation) return null;
    _inFlight = null;
    final ScanRoundResult? result;
    try {
      result = produce();
    } catch (_) {
      // 對齊真實 _runGuarded：失敗時狀態回 Idle 再往外拋。
      state = const ScanRoundIdle();
      rethrow;
    }
    state = result == null ? const ScanRoundIdle() : ScanRoundCompleted(result);
    return result;
  }
}
