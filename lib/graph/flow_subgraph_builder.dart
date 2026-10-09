/// SPEC-007 FR-10 flow 子圖建構與 flow 缺陷產生。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

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
    final subgraph = _buildOne(id, raw.flowSteps);
    subgraphs[id] = subgraph;
    defects.addAll(_defectsOf(subgraph));
  }
  return FlowBuildResult(subgraphs: subgraphs, defects: defects);
}

FlowSubgraph _buildOne(String ucId, List<Map<String, dynamic>> rawSteps) {
  final idIndex = <String, List<int>>{};
  for (var i = 0; i < rawSteps.length; i++) {
    final key = flowKeyOf(rawSteps[i][FlowFields.id]);
    if (key != null) idIndex.putIfAbsent(key, () => []).add(i);
  }
  return FlowSubgraph(
    ucId: ucId,
    steps: [
      for (var i = 0; i < rawSteps.length; i++)
        FlowStepNode(index: i, step: rawSteps[i], idIndex: idIndex),
    ],
  );
}

/// 缺陷順序：先全部「step id 重複」，再依步驟順序列未解析參照。
List<FlowGraphDefect> _defectsOf(FlowSubgraph g) {
  final groups = <String, List<FlowStepNode>>{};
  for (final s in g.steps) {
    final key = flowKeyOf(s.id);
    if (key != null) groups.putIfAbsent(key, () => []).add(s);
  }
  return [
    for (final group in groups.values)
      if (group.length >= 2)
        // 重複組內原值可能不同（1 與 "1"）：取清單中第一個的原值。
        FlowGraphDefect(
          kind: FlowDefectKind.duplicateStepId,
          ucId: g.ucId,
          stepId: group.first.id,
          field: FlowFields.id,
          rawValue: group.first.id,
        ),
    for (final s in g.steps)
      for (final ref in s.references)
        if (!ref.isResolved)
          FlowGraphDefect(
            kind: FlowDefectKind.unresolvedReference,
            ucId: g.ucId,
            stepId: s.id,
            field: ref.field,
            rawValue: ref.rawValue,
          ),
  ];
}
