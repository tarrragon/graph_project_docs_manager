/// 共用掃描輪次 → 破洞報告狀態（0.5.0-W1-114.15）。
///
/// 純函式：輪次結果經 Diagnostics（003／004／005 與 graphDefect）與
/// `projectGapReport` 投影為 [GapReportState]。查詢不可用的原因碼轉換屬
/// 編排層（SPEC-007 v1.24 FR-09），在本檔完成。
library;

import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';

import 'gap_report_models.dart';
import 'gap_report_projection.dart';

const String _tag = 'GapReportRoundState';

/// 需求：[SPEC-001 §5、SPEC-006 FR-08、SPEC-007 FR-09] 輪次結果 → 報告狀態。
///
/// 判定優先序：路徑模式查詢不可用或建圖不可用 → [GapReportUndeterminable]
/// （原因取路徑模式查詢優先，其次建圖）；否則依破洞數為
/// [GapReportNoGaps]／[GapReportFound]，並帶「路徑模式取自內建表」旗標。
/// [nonDomainPathsKey] 為 EVT-CORPUS-005 說明的 `{key}` 值。
GapReportState gapReportStateFromRound(
  ScanRoundResult round, {
  required String nonDomainPathsKey,
}) {
  final resolution = round.schemaResolution;
  final parse = _detectParseFailures(round, resolution);
  final (defects, nodes) = _detectGraphDefects(round);
  final categories = projectGapReport(
    parseFailures: parse.gaps,
    graphDefects: switch (defects) {
      GraphDefectsDetected(:final gaps) => gaps,
      GraphDefectUndetermined() => const <GraphDefectGap>[],
    },
    nodes: nodes,
    nonDomainPathsKey: nonDomainPathsKey,
  );
  final declaration = _declarationOf(round);
  final reason = _undeterminedReasonOf(parse, defects);
  if (reason != null) {
    return GapReportUndeterminable(
      reason: reason,
      categories: categories,
      pathDeclaration: declaration,
    );
  }
  final fromBuiltin = resolution.isPathPatternFromBuiltin;
  return categories.isEmpty
      ? GapReportNoGaps(
          isPathPatternFromBuiltin: fromBuiltin,
          pathDeclaration: declaration,
        )
      : GapReportFound(
          categories,
          isPathPatternFromBuiltin: fromBuiltin,
          pathDeclaration: declaration,
        );
}

/// 需求：[SPEC-001 §5〈專案層級宣告狀態一行〉] 專案層宣告彙整由 Graph 提供，
/// 本檔只轉交；宣告缺口不進破洞分節、不計入破洞數。
ProjectPathDeclaration _declarationOf(ScanRoundResult round) =>
    summarizeProjectPathDeclaration(
      rawNodes: round.scan.rawNodes,
      nonDomain: round.scan.nonDomainPathsRead,
    );

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
  developer.log(
    // i18n-exempt: 開發者診斷 log
    'graph unavailable reason=${reason.name}',
    name: _tag,
    level: 900,
  );
  return switch (reason) {
    EdgeTypeUnavailableReason.projectVersionOutOfKnownRange ||
    EdgeTypeUnavailableReason.missingForwardCardinality ||
    EdgeTypeUnavailableReason.invalidEdgeTypeEntry ||
    EdgeTypeUnavailableReason.missingDirection =>
      UndeterminedGapReason.projectVersionOutOfKnownRange,
  };
}

UndeterminedGapReason? _undeterminedReasonOf(
  GapDetectionResult parse,
  GraphDefectGapResult defects,
) => switch ((parse, defects)) {
  (Undetermined(:final reason), _) => reason,
  (_, GraphDefectUndetermined(:final reason)) => reason,
  _ => null,
};
