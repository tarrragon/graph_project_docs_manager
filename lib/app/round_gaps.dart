/// 輪次結果 → 破洞（讀 ScanRoundResult 與 schema 的部分）。
///
/// id 規則在 `diagnostics/gap_item_ids.dart`；本檔屬編排層，可依賴 app 與 schema。
library;

import 'package:graph_project_docs_manager/app/app_log_event.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_item_ids.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';

/// 輪次結果的各類破洞與供投影查詢的節點。
typedef RoundGaps = ({
  GapDetectionResult parse,
  GraphDefectGapResult defects,
  List<LightNode> nodes,
});

/// 需求：[SPEC-001 §5] 輪次結果 → 解析類與 graphDefect 破洞。
RoundGaps detectRoundGaps(ScanRoundResult round) =>
    _gapsCache[round] ??= _computeRoundGaps(round);

/// 同一輪結果只偵測一次：監看事件的 id 集合與破洞頁投影共用。
final Expando<RoundGaps> _gapsCache = Expando<RoundGaps>('roundGaps');
final Expando<EventGapReport> _eventGapsCache = Expando<EventGapReport>(
  'roundEventGaps',
);

RoundGaps _computeRoundGaps(ScanRoundResult round) {
  final (defects, nodes) = _detectGraphDefects(round);
  return (
    parse: _detectParseFailures(round, round.schemaResolution),
    defects: defects,
    nodes: nodes,
  );
}

/// 事件類破洞（SPEC-001 v1.52 §5）。
EventGapReport detectRoundEventGaps(ScanRoundResult round) =>
    _eventGapsCache[round] ??= detectEventGaps(
      graph: round.graph,
      rawNodes: round.scan.rawNodes,
    ).report;

/// 需求：[SPEC-001 §5 表二] 輪次結果 → 破洞項 id 集合；規則與破洞頁
/// `item.id` 一致（含 `#N` 後綴），配發順序同投影。
Set<String> gapItemIdsOf(ScanRoundResult round) {
  final gaps = detectRoundGaps(round);
  final events = detectRoundEventGaps(round);
  final alloc = GapItemIdAllocator();
  return {
    for (final g in gaps.parse.gaps) alloc.next(parseFailureIdComponents(g)),
    for (final g in _defectsOf(gaps.defects))
      alloc.next(graphDefectIdComponents(g)),
    for (final g in events.orphanEvents) alloc.next(orphanEventIdComponents(g)),
    for (final g in events.mismatches) alloc.next(eventMismatchIdComponents(g)),
  };
}

List<GraphDefectGap> _defectsOf(GraphDefectGapResult result) =>
    switch (result) {
      GraphDefectsDetected(:final gaps) => gaps,
      GraphDefectUndetermined() => const <GraphDefectGap>[],
    };

GapDetectionResult _detectParseFailures(
  ScanRoundResult round,
  SchemaSourceResolution resolution,
) {
  final scan = round.scan;
  return detectParseFailureGaps(
    events: scan.parseFailureEvents,
    undeterminedCount: scan.summary.undeterminedCount,
    unavailableReason: _pathQueryUnavailableReason(
      resolution.pathPatternSource,
    ),
    flowEvents: scan.flowParseFailedEvents,
    nonDomainPathsEvent: scan.nonDomainPathsParseFailedEvent,
    topicFilesEvents: scan.topicFilesParseFailedEvents,
  );
}

/// FR-06 查詢不可用的原因碼；可用時 `null`。
UndeterminedGapReason? _pathQueryUnavailableReason(PathPatternSource source) =>
    switch (source) {
      PathPatternSource.projectJson || PathPatternSource.builtinTable => null,
      PathPatternSource.projectVersionOutOfKnownRange =>
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      PathPatternSource.noPathPattern => UndeterminedGapReason.noPathPattern,
    };

/// 建圖結果 → graphDefect 破洞與供投影查詢的節點。建圖不可用時節點改由
/// 掃描的原始節點建（004 的 UC 仍是節點，不因建圖不可用而查無）。
(GraphDefectGapResult, List<LightNode>) _detectGraphDefects(
  ScanRoundResult round,
) => switch (round.graph) {
  GraphBuildAvailable(:final event) => (
    detectGraphDefectGaps(GraphDefectInputAvailable(event)),
    event.nodes,
  ),
  GraphBuildUnavailable(:final reason) => (
    detectGraphDefectGaps(
      GraphDefectInputUnavailable(undeterminedReasonFromGraph(reason)),
    ),
    buildLightNodes(round.scan.rawNodes).nodes,
  ),
};

/// 需求：[SPEC-007 v1.24 FR-09] 建圖不可用的四個原因碼皆轉為「專案版本
/// 不在已知範圍」；區分只留在日誌。
UndeterminedGapReason undeterminedReasonFromGraph(
  EdgeTypeUnavailableReason reason,
) {
  appLogSink(
    AppLogEvent.graphUnavailableUndetermined,
    LogFields({AppLogKeys.reason: LogValue.enumValue(reason)}),
    level: LogLevel.error,
  );
  return switch (reason) {
    EdgeTypeUnavailableReason.projectVersionOutOfKnownRange ||
    EdgeTypeUnavailableReason.missingForwardCardinality ||
    EdgeTypeUnavailableReason.invalidEdgeTypeEntry ||
    EdgeTypeUnavailableReason.missingDirection =>
      UndeterminedGapReason.projectVersionOutOfKnownRange,
  };
}
