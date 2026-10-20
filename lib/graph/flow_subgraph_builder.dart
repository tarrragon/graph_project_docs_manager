/// SPEC-007 FR-10 flow 子圖建構與 flow 缺陷產生。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

/// [buildFlowSubgraphs] 結果：每個 UC 一份子圖，加上全部 flow 缺陷。
class FlowBuildResult {
  const FlowBuildResult({required this.subgraphs, required this.defects});

  final Map<String, FlowSubgraph> subgraphs;
  final List<FlowGraphDefect> defects;
}

/// 需求：[SPEC-007 FR-10] 對進入圖的 UC（[ucIds]）建子圖並回報 flow 缺陷。
FlowBuildResult buildFlowSubgraphs(
  List<RawNode> rawNodes,
  Set<String> ucIds,
  DomainNameResolver domainResolver,
) {
  final subgraphs = <String, FlowSubgraph>{};
  final defects = <FlowGraphDefect>[];
  final eventIds = _eventIdsOf(rawNodes);
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (raw.typeName != flowSourceTypeName || id is! String) continue;
    if (!ucIds.contains(id)) continue;
    final subgraph = _buildOne(id, raw.flowSteps, domainResolver);
    subgraphs[id] = subgraph;
    defects.addAll(_defectsOf(subgraph, eventIds));
  }
  return FlowBuildResult(subgraphs: subgraphs, defects: defects);
}

/// EVT 節點的型別名（Graph 不得依賴 Diagnostics，故自有一份）。
const _eventTypeName = 'EVT';

/// 需求：[SPEC-007 FR-10〈事件引用〉] 事件節點 id 集合：`rawNodes` 中型別為 EVT、
/// `id` 為非空字串者。不取輕節點（主圖遇重複 ID 兩節點都不建，重複 EVT id 須算存在）。
Set<String> _eventIdsOf(List<RawNode> rawNodes) {
  final ids = <String>{};
  for (final n in rawNodes) {
    final id = n.frontmatter['id'];
    if (n.typeName == _eventTypeName && id is String && id.isNotEmpty) {
      ids.add(id);
    }
  }
  return ids;
}

FlowSubgraph _buildOne(
  String ucId,
  List<Map<String, dynamic>> rawSteps,
  DomainNameResolver domainResolver,
) {
  final idIndex = <String, List<int>>{};
  for (var i = 0; i < rawSteps.length; i++) {
    final key = flowKeyOf(rawSteps[i][FlowFields.id]);
    if (key != null) idIndex.putIfAbsent(key, () => []).add(i);
  }
  return FlowSubgraph(
    ucId: ucId,
    steps: [
      for (var i = 0; i < rawSteps.length; i++)
        FlowStepNode(
          index: i,
          step: rawSteps[i],
          idIndex: idIndex,
          domainResolver: domainResolver,
        ),
    ],
  );
}

/// 缺陷順序：先全部「step id 重複」，再依步驟順序列未解析參照。
List<FlowGraphDefect> _defectsOf(FlowSubgraph g, Set<String> eventIds) {
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
    for (final s in g.steps) ..._traversesDefects(g.ucId, s),
    for (final s in g.steps) ..._eventRefDefects(g.ucId, s, eventIds),
  ];
}

/// 需求：[SPEC-007 FR-10〈事件引用〉] `emits`、`consumes` 元素比對不到 EVT id 者各報一筆；
/// 同步驟同欄位同值（轉字串後）只報一筆，原始值記該元素原值。
List<FlowGraphDefect> _eventRefDefects(
  String ucId,
  FlowStepNode s,
  Set<String> eventIds,
) => [
  for (final field in const [FlowFields.emits, FlowFields.consumes])
    for (final raw in _unresolvedEventsOf(s.step[field], eventIds))
      FlowGraphDefect(
        kind: FlowDefectKind.eventUnresolved,
        ucId: ucId,
        stepId: s.id,
        field: field,
        rawValue: raw,
      ),
];

/// 正規化同 `flowKeysOf`（純量視同單元素、空元素略過）；回傳未命中元素的原值。
List<Object?> _unresolvedEventsOf(Object? raw, Set<String> eventIds) {
  final seen = <String>{};
  final result = <Object?>[];
  for (final e in raw is Iterable ? raw : [raw]) {
    final key = flowKeyOf(e);
    if (key == null || eventIds.contains(key) || !seen.add(key)) continue;
    result.add(e);
  }
  return result;
}

/// 需求：[SPEC-007 FR-11] 缺鍵一筆（原始值 null）；未宣告值逐值各一筆。
List<FlowGraphDefect> _traversesDefects(String ucId, FlowStepNode s) {
  final r = s.traversesResolution;
  FlowGraphDefect defect(FlowDefectKind kind, Object? raw) => FlowGraphDefect(
    kind: kind,
    ucId: ucId,
    stepId: s.id,
    field: FlowFields.traverses,
    rawValue: raw,
  );
  return [
    if (r.keyAbsent) defect(FlowDefectKind.traversesKeyAbsent, null),
    for (final v in r.undeclared) defect(FlowDefectKind.traversesUndeclared, v),
  ];
}
