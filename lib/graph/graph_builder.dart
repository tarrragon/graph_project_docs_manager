/// SPEC-007 FR-04～FR-06 建邊、`relatedTo` 聯集與建圖入口。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// 需求：[SPEC-007 FR-01、FR-06] 建圖入口。
///
/// 邊型不可用時回傳 [GraphBuildUnavailable] 並記「建圖不可用」；可用時建圖並
/// 記「建圖完成」結果值。[projectSchemaJson] 為 null 代表型別表缺席。
GraphBuildResult buildGraph({
  required List<RawNode> rawNodes,
  required Map<String, dynamic>? projectSchemaJson,
  required Map<String, dynamic> builtinSchemaJson,
  LogSink<GraphLogEvent>? logSink,
}) {
  final log = logSink ?? defaultGraphLogSink;
  final resolution = resolveEdgeTypes(
    projectSchemaJson: projectSchemaJson,
    builtinSchemaJson: builtinSchemaJson,
  );
  final reason = resolution.unavailableReason;
  if (reason != null) {
    log(
      GraphLogEvent.buildUnavailable,
      LogFields({GraphLogKeys.reason: LogValue.enumValue(reason)}),
      level: LogLevel.warning,
    );
    return GraphBuildUnavailable(reason);
  }
  final nodeTypes = nodeTypesFromSchemaJson(
    projectSchemaJson ?? builtinSchemaJson,
  );
  final event = buildGraphFromInputs(
    rawNodes: rawNodes,
    edgeTypes: resolution.activeEdgeTypes,
    nodeTypes: nodeTypes,
  );
  log(GraphLogEvent.buildCompleted, _completedFields(event));
  return GraphBuildAvailable(event);
}

LogFields _completedFields(GraphBuiltEvent event) => LogFields({
  GraphLogKeys.nodeCount: LogValue.integer(event.nodeCount),
  GraphLogKeys.edgeCount: LogValue.integer(event.edgeCount),
  GraphLogKeys.danglingRefCount: LogValue.integer(event.danglingRefCount),
  GraphLogKeys.malformedRefCount: LogValue.integer(event.malformedRefCount),
  GraphLogKeys.duplicateIdCount: LogValue.integer(event.duplicateIdCount),
  GraphLogKeys.multiSourceCount: LogValue.integer(event.multiSourceCount),
  GraphLogKeys.flowDefectCount: LogValue.integer(event.flowDefectCount),
  GraphLogKeys.resolvedCount: LogValue.integer(event.resolvedCount),
  GraphLogKeys.totalReferences: LogValue.integer(event.totalReferences),
});

/// 需求：[SPEC-007 FR-04～FR-06] 由使用中邊型與節點型別建圖（純函式，不記日誌）。
GraphBuiltEvent buildGraphFromInputs({
  required List<RawNode> rawNodes,
  required Iterable<EdgeTypeEntry> edgeTypes,
  required Map<String, NodeTypeEntry> nodeTypes,
  void Function()? onIdLookup,
  LogSink<GraphLogEvent>? logSink,
}) {
  final log = logSink ?? defaultGraphLogSink;
  final edgeList = edgeTypes.toList();
  final classified = classifyGraphReferences(
    rawNodes: rawNodes,
    edgeTypes: [
      for (final t in edgeList)
        if (t.name != _nameResolvedEdgeType) t,
    ],
    nodeTypes: nodeTypes,
    onIdLookup: onIdLookup,
    logSink: log,
  );
  final nodeIds = {for (final n in classified.lightNodes) n.id};
  final resolver = DomainNameResolver.fromRawNodes(rawNodes, nodeIds);
  final named = _classifyDomainNames(rawNodes, edgeList, {
    for (final d in classified.duplicates) d.id,
  }, resolver);
  final undirectedTypes = {
    for (final t in edgeList)
      if (t.isUndirected) t.name,
  };
  final layers = {for (final t in edgeList) t.name: t.layer};
  final resolvedRefs = [...classified.resolved, ...named.resolved];
  final edges = _buildEdges(resolvedRefs, undirectedTypes, layers);
  final flow = buildFlowSubgraphs(rawNodes, nodeIds, resolver);
  final defects = <GraphDefect>[
    ...classified.dangling,
    ...named.dangling,
    ...classified.malformed,
    ...named.malformed,
    ...classified.duplicates,
    ..._multiSourceDefects(edges, edgeList),
    ...flow.defects,
    for (final d in resolver.duplicates)
      DomainDuplicateDeclarationGraphDefect(
        domain: d.domain,
        bundleIds: d.bundleIds,
      ),
    ..._nodeLevelDefects(classified.lightNodes, edges, {
      for (final t in edgeList) t.name,
    }, log),
  ];
  return GraphBuiltEvent(
    nodes: classified.lightNodes,
    edges: edges,
    graphDefects: defects,
    flowSubgraphs: flow.subgraphs,
    domainResolver: resolver,
    totalReferences: classified.totalReferences + named.total,
    resolvedCount: resolvedRefs.length,
    skippedCount: classified.skippedCount,
  );
}

/// 孤島判定的節點型別（FR-09〈孤島與缺必要邊〉判準一；Ticket 不判定）。
const _isolationTypes = {'PROP', 'SPEC', 'UC', 'EVT', 'DomainBundle'};

/// 一條必要邊要求：[nodeType] 的節點須至少有一條 [edgeTypes] 之一的出邊。
typedef _RequiredEdge = ({String nodeType, List<String> edgeTypes});

/// 必要邊集合（FR-09 表；列序即報告序，邊型名取自型別表）。
const List<_RequiredEdge> _requiredEdges = [
  (nodeType: 'UC', edgeTypes: ['provenance']),
  (nodeType: 'UC', edgeTypes: ['spec_association']),
  (nodeType: 'UC', edgeTypes: ['uc_ticket_refs']),
  (nodeType: 'EVT', edgeTypes: ['provenance', 'spec_association']),
];

/// 使用中邊型不含某條要求的任何邊型時，該條要求跳過並記一筆日誌
/// （SPEC-007 FR-09〈孤島與缺必要邊〉；該條件下要求無從滿足，不構成缺陷）。
List<_RequiredEdge> _activeRequirements(
  Set<String> activeEdgeTypes,
  LogSink<GraphLogEvent> log,
) {
  final result = <_RequiredEdge>[];
  for (final r in _requiredEdges) {
    if (r.edgeTypes.any(activeEdgeTypes.contains)) {
      result.add(r);
      continue;
    }
    log(
      GraphLogEvent.requiredEdgeSkipped,
      LogFields.empty,
      level: LogLevel.debug,
    );
  }
  return result;
}

/// 需求：[SPEC-007 FR-09〈孤島與缺必要邊〉] 於主圖邊集合上判定孤島與缺必要邊。
///
/// 孤島只報一筆且不再判該節點的缺必要邊。「出邊」以邊的起點為準（有向）；
/// 無向邊任一端皆算。
List<GraphDefect> _nodeLevelDefects(
  List<LightNode> nodes,
  List<GraphEdge> edges,
  Set<String> activeEdgeTypes,
  LogSink<GraphLogEvent> log,
) {
  final requirements = _activeRequirements(activeEdgeTypes, log);
  final touched = <String>{
    for (final e in edges) ...[e.from, e.to],
  };
  final outTypes = <String, Set<String>>{};
  for (final e in edges) {
    outTypes.putIfAbsent(e.from, () => {}).add(e.edgeType);
    if (e.isUndirected) outTypes.putIfAbsent(e.to, () => {}).add(e.edgeType);
  }
  return [
    for (final n in nodes)
      if (_isolationTypes.contains(n.typeName) && !touched.contains(n.id))
        IsolatedNodeGraphDefect(
          nodeId: n.id,
          nodeType: n.typeName,
          path: n.path,
        )
      else
        for (final r in requirements)
          if (r.nodeType == n.typeName &&
              !r.edgeTypes.any((t) => outTypes[n.id]?.contains(t) ?? false))
            MissingRequiredEdgeGraphDefect(
              nodeId: n.id,
              nodeType: n.typeName,
              path: n.path,
              edgeTypes: r.edgeTypes,
            ),
  ];
}

/// 值為 domain 名稱（而非節點 ID）、經 [DomainNameResolver] 解析的邊型（FR-11）。
const _nameResolvedEdgeType = 'domain_dependency';

/// 名稱型引用值的分類結果。
typedef _NameClassification = ({
  List<ResolvedRef> resolved,
  List<DanglingRefGraphDefect> dangling,
  List<MalformedRefGraphDefect> malformed,
  int total,
});

/// 需求：[SPEC-007 FR-03、FR-11] `domain_dependency` 的引用值以名稱索引解析。
///
/// 值不是 ID，不比對 `id_pattern`：非字串為 `invalidShape`；索引查無（未宣告、
/// 或因重複宣告被排除）為 `danglingRef`（`targetMissing`）；其餘解析成功。
_NameClassification _classifyDomainNames(
  List<RawNode> rawNodes,
  List<EdgeTypeEntry> edgeTypes,
  Set<String> duplicateIds,
  DomainNameResolver resolver,
) {
  final named = [
    for (final t in edgeTypes)
      if (t.name == _nameResolvedEdgeType) t,
  ];
  final resolved = <ResolvedRef>[];
  final dangling = <DanglingRefGraphDefect>[];
  final malformed = <MalformedRefGraphDefect>[];
  var total = 0;
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (named.isEmpty || id is! String || duplicateIds.contains(id)) continue;
    final refs = extractReferenceValues(
      node: raw,
      sourceId: id,
      edgeTypes: named,
    );
    total += refs.length;
    for (final ref in refs) {
      final target = ref.isShapeValid ? resolver.resolve(ref.value) : null;
      if (!ref.isShapeValid) {
        malformed.add(
          MalformedRefGraphDefect(
            ref: ref,
            reason: MalformedReason.invalidShape,
          ),
        );
      } else if (target == null) {
        dangling.add(
          DanglingRefGraphDefect(
            ref: ref,
            reason: DanglingReason.targetMissing,
          ),
        );
      } else {
        resolved.add(ResolvedRef(ref: ref, targetId: target));
      }
    }
  }
  return (
    resolved: resolved,
    dangling: dangling,
    malformed: malformed,
    total: total,
  );
}

/// 同一條邊（型別、起點、終點；無向為端點集合）只建一次，宣告來源取聯集。
List<GraphEdge> _buildEdges(
  List<ResolvedRef> resolved,
  Set<String> undirectedTypes,
  Map<String, String> layers,
) {
  final merged = <String, GraphEdge>{};
  for (final r in resolved) {
    final edge = _edgeOf(r, undirectedTypes, layers);
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
            layer: edge.layer,
          );
  }
  return merged.values.toList()..sort(_compareEdges);
}

/// 無向與否取自 [undirectedTypes]（`EdgeTypeEntry.isUndirected`，D6）。
GraphEdge _edgeOf(
  ResolvedRef r,
  Set<String> undirectedTypes,
  Map<String, String> layers,
) {
  final source = r.ref.sourceId;
  final target = r.targetId;
  final type = r.ref.edgeTypeName;
  final layer = layers[type]!;
  if (undirectedTypes.contains(type)) {
    final ordered = source.compareTo(target) <= 0
        ? (source, target)
        : (target, source);
    return GraphEdge(
      edgeType: type,
      from: ordered.$1,
      to: ordered.$2,
      declaredBy: {source},
      isUndirected: true,
      layer: layer,
    );
  }
  final isReverse = r.ref.isReverse;
  return GraphEdge(
    edgeType: type,
    from: isReverse ? target : source,
    to: isReverse ? source : target,
    declaredBy: {source},
    isUndirected: false,
    layer: layer,
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
      if (t.forwardCardinality == EdgeCardinality.one && !t.isUndirected)
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
