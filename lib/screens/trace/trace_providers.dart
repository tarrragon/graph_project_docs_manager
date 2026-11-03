/// 追溯視圖的狀態注入點（SPEC-003 §設計約束「狀態注入而非等待真實解析」）。
library;

import 'package:graph_project_docs_manager/state/state_holder.dart';

export 'package:graph_project_docs_manager/state/state_holder.dart'
    show StateHolderOverride;

import '../../app/graph_status.dart';
import '../../app/scan_round.dart';
import '../../corpus/corpus_scanner.dart';
import '../../corpus/node_type_names.dart';
import '../../graph/graph_built_event.dart';
import '../../graph/light_node.dart';
import 'trace_state.dart';

const String _propType = 'PROP';
const String _specType = 'SPEC';
const String _ucType = 'UC';
const String _absentStatus = '—'; // i18n-exempt: 資料態佔位符，非 UI 文案

/// 目前畫面狀態；預設由最後完成輪次衍生（SPEC-001 §3〈四層樹由掃描輪次
/// 衍生〉）。測試以 `overrideWith` 注入其餘狀態。
final traceabilityStateProvider = stateHolderProvider<TraceabilityScreenState>(
  (ref) => traceabilityStateOf(
    ref.watch(projectUnreadyReasonProvider),
    ref.watch(lastCompletedRoundProvider),
  ),
);

/// 需求：[SPEC-001 §3] 判定順序：1 專案未就緒、2 圖不可用、3 無提案、
/// 4 鏈路斷裂、5 正常。「圖不可用」在此自行判定，不引用其他畫面。
TraceabilityScreenState traceabilityStateOf(
  ProjectUnreadyReason? reason,
  ScanRoundResult? round,
) {
  if (reason != null) return TraceabilityProjectUnready(reason);
  if (round == null) {
    return const TraceabilityProjectUnready(ProjectUnreadyReason.loading);
  }
  final graph = round.graph;
  if (graph is! GraphBuildAvailable) {
    return const TraceabilityGraphUnavailable();
  }
  final roots = traceRootsOfRound(graph.event.nodes, round.scan.rawNodes);
  if (roots.isEmpty) return const TraceabilityNoProposal();
  return roots.any(_subtreeHasGap)
      ? TraceabilityBroken(roots)
      : TraceabilityNormal(roots);
}

bool _subtreeHasGap(TraceNode node) =>
    node.hasGap || node.children.any(_subtreeHasGap);

/// 需求：[SPEC-001 §3] 三跳建樹：PROP←SPEC `source_proposal`（反查）、
/// SPEC←UC `related_specs`（反查，不取 SPEC 的 `related_usecases`）、
/// UC→Ticket `ticket_refs`（正查）。指向不存在節點的值不成子節點。
List<TraceNode> traceRootsOfRound(
  List<LightNode> nodes,
  List<RawNode> rawNodes,
) {
  final fields = _fieldsById(rawNodes);
  final byType = _nodesByType(nodes);
  final ids = {for (final n in nodes) n.id: n};
  List<String> refs(String id, String key) => _stringValues(fields[id]?[key]);

  TraceNode leaf(LightNode n, {List<TraceNode> children = const []}) {
    final gapLayer = children.isEmpty ? _gapLayerOf(n.typeName) : null;
    return TraceNode(
      id: n.id,
      label: _labelOf(n),
      status: n.status ?? _absentStatus,
      hasGap: gapLayer != null,
      gapLayer: gapLayer,
      children: children,
    );
  }

  TraceNode ucNode(LightNode uc) => leaf(
    uc,
    children: [
      for (final t in refs(uc.id, 'ticket_refs').toSet())
        if (ids[t]?.typeName == ticketTypeName) leaf(ids[t]!),
    ],
  );
  TraceNode specNode(LightNode spec) => leaf(
    spec,
    children: [
      for (final uc in byType[_ucType] ?? const <LightNode>[])
        if (refs(uc.id, 'related_specs').contains(spec.id)) ucNode(uc),
    ],
  );
  return [
    for (final prop in byType[_propType] ?? const <LightNode>[])
      leaf(
        prop,
        children: [
          for (final spec in byType[_specType] ?? const <LightNode>[])
            if (refs(spec.id, 'source_proposal').contains(prop.id))
              specNode(spec),
        ],
      ),
  ];
}

String? _gapLayerOf(String typeName) => switch (typeName) {
  _propType => 'spec',
  _specType => 'uc',
  _ucType => 'ticket',
  _ => null,
};

String _labelOf(LightNode n) =>
    n.displayTitle.isEmpty ? n.id : '${n.id} ${n.displayTitle}';

Map<String, List<LightNode>> _nodesByType(List<LightNode> nodes) {
  final byType = <String, List<LightNode>>{};
  final seen = <String>{};
  for (final n in nodes) {
    if (seen.add(n.id)) byType.putIfAbsent(n.typeName, () => []).add(n);
  }
  return byType;
}

Map<String, Map<String, dynamic>> _fieldsById(List<RawNode> rawNodes) {
  final fields = <String, Map<String, dynamic>>{};
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (id is String) fields.putIfAbsent(id, () => raw.frontmatter);
  }
  return fields;
}

List<String> _stringValues(Object? value) => switch (value) {
  String s => [s],
  List<dynamic> l => [
    for (final e in l)
      if (e is String) e,
  ],
  _ => const [],
};

/// 目前展開的樹節點 id 集合（SPEC-004 §5.13 slot 契約：存於呼叫端
/// provider）。初始值依 [traceabilityStateProvider] 目前的樹計算（SPEC-003
/// §3.3〈生命週期〉：首次可見與切換專案後只顯示 PROP 層，含缺口的分支
/// 自動展開至缺口所在層）——藉由 `ref.watch` 依附狀態 provider，狀態改變
/// （即本票以 fixture 切換模擬的「切換專案」）會使本 provider 重新計算，
/// 天然滿足展開集合重設（`0.1.0-W3-335.38` S-28／S-29）。本票不接真實
/// 專案切換 listener，狀態改變仍需由呼叫端（測試或未來真實資料層）觸發。
final expandedTraceNodesProvider = stateHolderProvider<Set<String>>(
  (ref) => _initialExpansion(ref.watch(traceabilityStateProvider)),
);

/// 計算首次渲染（或狀態重新計算）時應展開的節點 id 集合：只有「子樹含
/// 缺口」的節點需要展開（缺口父節點本身亦展開，其下為缺口列）；PROP 層若不含缺口分支則維持收合（用戶簽核 2026-09-14）。
Set<String> _initialExpansion(TraceabilityScreenState state) {
  final roots = switch (state) {
    TraceabilityNormal(:final roots) => roots,
    TraceabilityBroken(:final roots) => roots,
    TraceabilityNoProposal() => const <TraceNode>[],
    TraceabilityProjectUnready() => const <TraceNode>[],
    TraceabilityGraphUnavailable() => const <TraceNode>[],
  };
  final expand = <String>{};
  for (final root in roots) {
    _markGapAncestors(root, expand);
  }
  return expand;
}

/// 遞迴標記 [node] 的子樹是否含缺口；含缺口且有子節點者加入 [expand]。
/// 回傳值供上層呼叫判斷自身子樹是否亦含缺口。
bool _markGapAncestors(TraceNode node, Set<String> expand) {
  var subtreeHasGap = node.hasGap;
  for (final child in node.children) {
    if (_markGapAncestors(child, expand)) {
      subtreeHasGap = true;
    }
  }
  // 缺口父節點本身亦展開，使其下缺口列首次渲染即可見（SPEC-004 4.39）。
  if (subtreeHasGap && (node.children.isNotEmpty || node.hasGap)) {
    expand.add(node.id);
  }
  return subtreeHasGap;
}
