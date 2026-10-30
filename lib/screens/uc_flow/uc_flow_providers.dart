/// UC Flow 視圖的狀態計算入口（0.5.0-W1-114.18）。
///
/// UC 清單、步驟與事件流由共用掃描輪次（`scanRoundProvider`）與 Graph
/// 公開面 `flowOf` 驅動，不讀 `UcFlowFixtures`（測試以
/// `ucFlowUcListProvider.overrideWithValue` 注入 `UcFlowFixtures`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/domain_uc_columns.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart'
    show RawNode;
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart'
    show FlowParseFailedEvent;
import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';
import 'package:graph_project_docs_manager/graph/flow_key.dart';
import 'package:graph_project_docs_manager/graph/flow_query.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import 'uc_flow_state.dart';

/// 專案內 UC 清單；輪次未完成或建圖不可用時為空。測試以
/// `overrideWithValue(const [])` 驗證「無 UC」分支。
final ucFlowUcListProvider = Provider<List<UcFlowUcItem>>((ref) {
  final round = ref.watch(scanRoundProvider);
  if (round is! ScanRoundCompleted) return const [];
  final graph = round.result.graph;
  if (graph is! GraphBuildAvailable) return const [];
  return projectUcFlowItems(
    event: graph.event,
    failedEvents: round.result.scan.flowParseFailedEvents,
    rawNodes: round.result.scan.rawNodes,
  );
});

/// 需求：[SPEC-003 §3.2／§3.5] 事件類破洞偵測結果；判準只由偵測端決定，
/// 畫面僅以 EVT id 查詢。輪次未完成時為零筆，建圖不可用時偵測端自回零筆。
final ucFlowEventGapsProvider = Provider<EventGapReport>((ref) {
  final round = ref.watch(scanRoundProvider);
  if (round is! ScanRoundCompleted) return const EventGapReport.empty();
  return detectEventGaps(
    graph: round.result.graph,
    rawNodes: round.result.scan.rawNodes,
  ).report;
});

/// 需求：[SPEC-001 §2] UC 清單取圖上全部 UC 型別節點（欄序同 Domain 矩陣），
/// 步驟取 `flowOf`，解析失敗旗標取 EVT-CORPUS-004 對應的同路徑 UC；
/// 事件流小表「本 UC 外」附帶的對側 domain 取 [rawNodes] 中 EVT 節點的
/// `producers`／`consumers`（找不到 EVT 節點的事件不產生對側宣告）。
List<UcFlowUcItem> projectUcFlowItems({
  required GraphBuiltEvent event,
  required Iterable<FlowParseFailedEvent> failedEvents,
  Iterable<RawNode> rawNodes = const [],
}) {
  final flows = FlowQuery(buildResult: GraphBuildAvailable(event));
  final failedIds = flowParseFailedUcIdsOf(
    failedEvents: failedEvents,
    event: event,
  );
  final sides = _eventSidesOf(rawNodes);
  return [
    for (final id in orderedUcColumnIds(event.nodes))
      _toUcItem(event, flows, id, failedIds.contains(id), sides),
  ];
}

/// EVT id → 對側宣告；同 id 先出現者勝（同 [detectEventGaps] 取法）。
Map<String, UcFlowEventSides> _eventSidesOf(Iterable<RawNode> rawNodes) {
  final result = <String, UcFlowEventSides>{};
  for (final n in rawNodes) {
    final id = flowKeyOf(n.frontmatter['id']);
    if (n.typeName != eventTypeName || id == null) continue;
    result.putIfAbsent(
      id,
      () => UcFlowEventSides(
        producers: flowKeysOf(n.frontmatter['producers']),
        consumers: flowKeysOf(n.frontmatter['consumers']),
      ),
    );
  }
  return result;
}

UcFlowUcItem _toUcItem(
  GraphBuiltEvent event,
  FlowQuery flows,
  String ucId,
  bool isFailed,
  Map<String, UcFlowEventSides> sides,
) {
  final node = event.nodes.firstWhere((n) => n.id == ucId);
  final subgraph = switch (flows.flowOf(ucId)) {
    FlowOfAvailable(:final subgraph) => subgraph,
    _ => null,
  };
  return UcFlowUcItem(
    id: ucId,
    title: node.displayTitle,
    filePath: node.path,
    steps: [
      for (final s in subgraph?.steps ?? const <FlowStepNode>[]) _step(s),
    ],
    isFlowParseFailed: isFailed,
    eventSides: sides,
  );
}

UcFlowStepItem _step(FlowStepNode step) {
  final domains = step.traversesResolution;
  return UcFlowStepItem(
    id: flowKeyOf(step.id),
    label: flowKeyOf(step.name) ?? flowKeyOf(step.id) ?? '',
    domain: [
      for (final d in domains.resolved) d.name,
      for (final u in domains.undeclared) '$u',
    ].join(', '), // i18n-exempt: domain 清單分隔符
    emits: step.emitsNames,
    consumes: step.consumesNames,
  );
}

/// 目前畫面狀態：依 [projectUnreadyReasonProvider]、[ucFlowUcListProvider]、
/// [selectedUcProvider] 三者計算（SPEC-001 §2）。
final ucFlowStateProvider = Provider<UcFlowState>((ref) {
  final unreadyReason = ref.watch(projectUnreadyReasonProvider);
  if (unreadyReason != null) {
    return UcFlowProjectUnready(unreadyReason);
  }
  final ucList = ref.watch(ucFlowUcListProvider);
  if (ucList.isEmpty) {
    return const UcFlowEmpty();
  }
  final selectedUcId = ref.watch(selectedUcProvider);
  if (selectedUcId == null) {
    return const UcFlowUcUnset();
  }
  final uc = ucList.where((uc) => uc.id == selectedUcId).firstOrNull;
  if (uc == null || !uc.hasFlowStep) {
    return UcFlowUnstructured(
      ucId: selectedUcId,
      isParseFailed: uc?.isFlowParseFailed ?? false,
    );
  }
  return UcFlowNormal(ucId: selectedUcId);
});
