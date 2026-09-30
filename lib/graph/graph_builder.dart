/// SPEC-007 FR-04～FR-06 建邊、`relatedTo` 聯集與建圖入口。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

/// 無向邊以鍵名識別（SPEC-007 FR-04 表格：`association`）。
const undirectedEdgeName = 'association';

/// 需求：[SPEC-007 FR-01、FR-06] 建圖入口。
///
/// 邊型不可用時回傳 [GraphBuildUnavailable] 並記「建圖不可用」；可用時建圖並
/// 記「建圖完成」結果值。[projectSchemaJson] 為 null 代表型別表缺席。
GraphBuildResult buildGraph({
  required List<RawNode> rawNodes,
  required Map<String, dynamic>? projectSchemaJson,
  required Map<String, dynamic> builtinSchemaJson,
  GraphLogSink? logSink,
}) {
  final log = logSink ?? defaultGraphLogSink;
  final resolution = resolveEdgeTypes(
    projectSchemaJson: projectSchemaJson,
    builtinSchemaJson: builtinSchemaJson,
  );
  final reason = resolution.unavailableReason;
  if (reason != null) {
    log(
      'graph build unavailable: ${reason.name}', // i18n-exempt: debug log
      event: GraphLogEvent.buildUnavailable,
      payload: {GraphLogKeys.reason: reason.name},
      level: 900,
    );
    return GraphBuildUnavailable(reason);
  }
  final nodeTypes = typeTableFromJson(projectSchemaJson ?? builtinSchemaJson)
      .nodeTypes;
  final event = buildGraphFromInputs(
    rawNodes: rawNodes,
    edgeTypes: resolution.activeEdgeTypes,
    nodeTypes: nodeTypes,
  );
  log(
    'graph build completed', // i18n-exempt: debug log
    event: GraphLogEvent.buildCompleted,
    payload: _completedPayload(event),
  );
  return GraphBuildAvailable(event);
}

Map<String, Object?> _completedPayload(GraphBuiltEvent event) => {
  GraphLogKeys.nodeCount: event.nodeCount,
  GraphLogKeys.edgeCount: event.edgeCount,
  GraphLogKeys.danglingRefCount: event.danglingRefCount,
  GraphLogKeys.malformedRefCount: event.malformedRefCount,
  GraphLogKeys.duplicateIdCount: event.duplicateIdCount,
  GraphLogKeys.multiSourceCount: event.multiSourceCount,
  GraphLogKeys.resolvedCount: event.resolvedCount,
  GraphLogKeys.totalReferences: event.totalReferences,
};

/// 需求：[SPEC-007 FR-04～FR-06] 由使用中邊型與節點型別建圖（純函式，不記日誌）。
GraphBuiltEvent buildGraphFromInputs({
  required List<RawNode> rawNodes,
  required Iterable<EdgeTypeEntry> edgeTypes,
  required Map<String, NodeTypeEntry> nodeTypes,
  void Function()? onIdLookup,
}) {
  final edgeList = edgeTypes.toList();
  final classified = classifyGraphReferences(
    rawNodes: rawNodes,
    edgeTypes: edgeList,
    nodeTypes: nodeTypes,
    onIdLookup: onIdLookup,
  );
  final edges = _buildEdges(classified.resolved);
  final defects = <GraphDefect>[
    for (final d in classified.dangling) DanglingRefGraphDefect(d),
    for (final m in classified.malformed) MalformedRefGraphDefect(m),
    for (final d in classified.duplicates) DuplicateIdGraphDefect(d),
    ..._multiSourceDefects(edges, edgeList),
  ];
  return GraphBuiltEvent(
    nodes: classified.lightNodes,
    edges: edges,
    graphDefects: defects,
    totalReferences: classified.totalReferences,
    resolvedCount: classified.resolved.length,
  );
}

/// 同一條邊（型別、起點、終點；無向為端點集合）只建一次，宣告來源取聯集。
List<GraphEdge> _buildEdges(List<ResolvedRef> resolved) {
  final merged = <String, GraphEdge>{};
  for (final r in resolved) {
    final edge = _edgeOf(r);
    final key = '${edge.edgeType}\u0000${edge.from}\u0000${edge.to}';
    final existing = merged[key];
    merged[key] = existing == null
        ? edge
        : GraphEdge(
            edgeType: edge.edgeType,
            from: edge.from,
            to: edge.to,
            declaredBy: {...existing.declaredBy, ...edge.declaredBy},
            isUndirected: edge.isUndirected,
          );
  }
  return merged.values.toList()..sort(_compareEdges);
}

GraphEdge _edgeOf(ResolvedRef r) {
  final source = r.ref.sourceId;
  final target = r.targetId;
  final type = r.ref.edgeTypeName;
  if (type == undirectedEdgeName) {
    final ordered = source.compareTo(target) <= 0
        ? (source, target)
        : (target, source);
    return GraphEdge(
      edgeType: type,
      from: ordered.$1,
      to: ordered.$2,
      declaredBy: {source},
      isUndirected: true,
    );
  }
  final isReverse = r.ref.isReverse;
  return GraphEdge(
    edgeType: type,
    from: isReverse ? target : source,
    to: isReverse ? source : target,
    declaredBy: {source},
    isUndirected: false,
  );
}

int _compareEdges(GraphEdge a, GraphEdge b) {
  final byType = a.edgeType.compareTo(b.edgeType);
  if (byType != 0) return byType;
  final byFrom = a.from.compareTo(b.from);
  return byFrom != 0 ? byFrom : a.to.compareTo(b.to);
}

/// 正向基數為 `one` 的邊型，一個起點指向兩個以上不同終點時回報一筆。
List<MultiSourceGraphDefect> _multiSourceDefects(
  List<GraphEdge> edges,
  List<EdgeTypeEntry> edgeTypes,
) {
  final oneTypes = {
    for (final t in edgeTypes)
      if (t.forwardCardinality == EdgeCardinality.one &&
          t.name != undirectedEdgeName)
        t.name,
  };
  final groups = <String, List<GraphEdge>>{};
  for (final e in edges.where((e) => oneTypes.contains(e.edgeType))) {
    groups.putIfAbsent('${e.edgeType}\u0000${e.from}', () => []).add(e);
  }
  return [
    for (final group in groups.values)
      if (group.length >= 2)
        MultiSourceGraphDefect(
          from: group.first.from,
          edgeType: group.first.edgeType,
          targets: [
            for (final e in group)
              MultiSourceTarget(to: e.to, declaredBy: e.declaredBy),
          ],
        ),
  ];
}
