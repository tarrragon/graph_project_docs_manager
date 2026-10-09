/// SPEC-007 FR-10 UC flow 子圖 `flowOf(ucId)`（Graph 公開面）。
///
/// FlowStep 不進主圖：子圖不產生輕節點、不進 EVT-GRAPH-001 的邊集合。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

/// 只有此節點型別的 rawNode 附掛 flow 步驟（型別表節點型別名）。
const flowSourceTypeName = 'UC';

/// FlowStep 欄位名（缺陷負載的「欄位」值）。
class FlowFields {
  FlowFields._();

  static const id = 'id';
  static const name = 'name';
  static const next = 'next';
  static const emits = 'emits';
  static const consumes = 'consumes';
  static const traverses = 'traverses';
  static const branchFrom = 'branch_from';
  static const returnTo = 'return_to';
}

/// 一個參照（`branch_from`／`return_to`／分支步 `next`）；[target] 為 null 即未解析。
class FlowReference {
  const FlowReference({
    required this.field,
    required this.rawValue,
    required this.target,
  });

  final String field;
  final Object? rawValue;
  final FlowStepNode? target;

  bool get isResolved => target != null;
}

/// 子圖中的一步，屬性皆為 flow 區塊的原值。
class FlowStepNode {
  FlowStepNode({
    required this.index,
    required this.step,
    required this.isMainline,
  });

  /// 在步驟清單中的位置。
  final int index;
  final Map<String, dynamic> step;
  final bool isMainline;

  /// 非空 `branch_from` 的解析結果；主線步驟為 null。
  FlowReference? branchFrom;

  /// 非空 `return_to` 的解析結果。
  FlowReference? returnTo;

  /// 分支步非空 `next` 的解析結果；主線步驟恆為 null（主線 `next` 不解析）。
  FlowReference? nextRef;

  Object? get id => step[FlowFields.id];
  Object? get name => step[FlowFields.name];
  Object? get next => step[FlowFields.next];
  Object? get emits => step[FlowFields.emits];
  Object? get consumes => step[FlowFields.consumes];
  Object? get traverses => step[FlowFields.traverses];
}

/// 一個 UC 的 flow 子圖。
class FlowSubgraph {
  FlowSubgraph({required this.ucId, required List<FlowStepNode> steps})
    : steps = List.unmodifiable(steps);

  final String ucId;

  /// 全部步驟，依清單順序。
  final List<FlowStepNode> steps;

  /// 主線：`branch_from` 為空者，依清單順序。
  List<FlowStepNode> get mainline => [
    for (final s in steps)
      if (s.isMainline) s,
  ];

  /// 分支：`branch_from` 非空者，依清單順序。
  List<FlowStepNode> get branches => [
    for (final s in steps)
      if (!s.isMainline) s,
  ];

  /// 回指：`return_to` 非空者，依清單順序。
  List<FlowStepNode> get returns => [
    for (final s in steps)
      if (s.returnTo != null) s,
  ];
}

/// [buildFlowSubgraphs] 結果：每個 UC 一份子圖，加上全部 flow 缺陷。
class FlowBuildResult {
  const FlowBuildResult({required this.subgraphs, required this.defects});

  final Map<String, FlowSubgraph> subgraphs;
  final List<FlowGraphDefect> defects;
}

/// 需求：[SPEC-007 FR-10] 對進入圖的 UC（[ucIds]）建子圖並回報 flow 缺陷。
FlowBuildResult buildFlowSubgraphs(List<RawNode> rawNodes, Set<String> ucIds) {
  final subgraphs = <String, FlowSubgraph>{};
  final defects = <FlowGraphDefect>[];
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (raw.typeName != flowSourceTypeName || id is! String) continue;
    if (!ucIds.contains(id)) continue;
    final built = _buildOne(id, raw.flowSteps);
    subgraphs[id] = built.subgraph;
    defects.addAll(built.defects);
  }
  return FlowBuildResult(subgraphs: subgraphs, defects: defects);
}

bool _isEmptyRef(Object? value) => value == null || value == '';

({FlowSubgraph subgraph, List<FlowGraphDefect> defects}) _buildOne(
  String ucId,
  List<Map<String, dynamic>> rawSteps,
) {
  final nodes = [
    for (var i = 0; i < rawSteps.length; i++)
      FlowStepNode(
        index: i,
        step: rawSteps[i],
        isMainline: _isEmptyRef(rawSteps[i][FlowFields.branchFrom]),
      ),
  ];
  final byId = <Object?, List<FlowStepNode>>{};
  for (final n in nodes) {
    final id = n.id;
    if (id is String) byId.putIfAbsent(id, () => []).add(n);
  }
  final defects = <FlowGraphDefect>[
    for (final e in byId.entries)
      if (e.value.length >= 2)
        FlowGraphDefect(
          kind: FlowDefectKind.duplicateStepId,
          ucId: ucId,
          stepId: e.key,
          field: FlowFields.id,
          rawValue: e.key,
        ),
  ];
  for (final n in nodes) {
    _resolveStep(ucId, n, byId, defects);
  }
  return (subgraph: FlowSubgraph(ucId: ucId, steps: nodes), defects: defects);
}

/// 參照只在同 UC 範圍解析；目標 id 缺席或重複皆為未解析。
void _resolveStep(
  String ucId,
  FlowStepNode node,
  Map<Object?, List<FlowStepNode>> byId,
  List<FlowGraphDefect> defects,
) {
  FlowReference? resolve(String field) {
    final raw = node.step[field];
    if (_isEmptyRef(raw)) return null;
    final hits = raw is String ? byId[raw] : null;
    final target = hits != null && hits.length == 1 ? hits.single : null;
    if (target == null) {
      defects.add(
        FlowGraphDefect(
          kind: FlowDefectKind.unresolvedReference,
          ucId: ucId,
          stepId: node.id,
          field: field,
          rawValue: raw,
        ),
      );
    }
    return FlowReference(field: field, rawValue: raw, target: target);
  }

  if (!node.isMainline) {
    node.branchFrom = resolve(FlowFields.branchFrom);
    node.nextRef = resolve(FlowFields.next);
  }
  node.returnTo = resolve(FlowFields.returnTo);
}

/// `flowOf` 結果：子圖、不存在、圖不可用三者可窮舉區分。
sealed class FlowOfResult {
  const FlowOfResult();
}

class FlowOfAvailable extends FlowOfResult {
  const FlowOfAvailable(this.subgraph);
  final FlowSubgraph subgraph;
}

/// UC ID 不在圖上、或不是 UC。
class FlowOfNotFound extends FlowOfResult {
  const FlowOfNotFound();
}

/// 建圖不可用或尚未完成。
class FlowOfGraphUnavailable extends FlowOfResult {
  const FlowOfGraphUnavailable(this.cause);
  final AdjacencyUnavailableCause cause;
}

/// 需求：[SPEC-007 FR-10] Graph 公開面 `flowOf(ucId)`。
///
/// [buildResult] 為 null 代表尚未完成建圖。
class FlowQuery {
  const FlowQuery({required this.buildResult});

  final GraphBuildResult? buildResult;

  FlowOfResult flowOf(String ucId) => switch (buildResult) {
    GraphBuildAvailable(:final event) => _lookup(event, ucId),
    GraphBuildUnavailable() => const FlowOfGraphUnavailable(
      AdjacencyUnavailableCause.buildUnavailable,
    ),
    null => const FlowOfGraphUnavailable(
      AdjacencyUnavailableCause.buildNotCompleted,
    ),
  };

  FlowOfResult _lookup(GraphBuiltEvent event, String ucId) {
    final subgraph = event.flowSubgraphs[ucId];
    return subgraph == null
        ? const FlowOfNotFound()
        : FlowOfAvailable(subgraph);
  }
}
