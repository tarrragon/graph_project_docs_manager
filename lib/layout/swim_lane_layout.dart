/// 泳道布局：欄序、節點所屬列、邊的來源／形狀／端點、欄序無法輸出的步驟、
/// `traverses` 異常步驟，以及「給定一列，回傳欄號最小的節點」查詢
/// （SPEC-001 §1〈泳道布局規則〉、〈間接依賴格的「在泳道中檢視」跳轉目標〉）。
///
/// 只依賴 Graph 公開面的 flow 子圖（含 `traversesResolution`）。欄序與查詢
/// 共用同一個 [SwimLaneLayout]，不另算欄號。
library;

import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';

const _tag = 'SwimLaneLayout';

/// 邊的形狀類別：前向直線、回指弧線。
enum EdgeShape { straight, arc }

/// 邊的來源欄位。
enum EdgeSource { next, branchFrom, returnTo }

/// 一個步驟在一列上的節點；[column] 為步驟的欄號。
class LayoutNode {
  const LayoutNode({
    required this.stepIndex,
    required this.column,
    required this.lane,
  });

  /// 步驟在 flow 子圖 `steps` 的位置。
  final int stepIndex;
  final int column;
  final SwimLane lane;
}

/// 一條邊；端點為各步驟最上方的節點。
class LayoutEdge {
  const LayoutEdge({
    required this.source,
    required this.fromStep,
    required this.toStep,
    required this.shape,
    required this.from,
    required this.to,
  });

  final EdgeSource source;
  final int fromStep;
  final int toStep;
  final EdgeShape shape;
  final LayoutNode from;
  final LayoutNode to;
}

/// 布局結果。
class SwimLaneLayout {
  SwimLaneLayout._({
    required List<SwimLane> lanes,
    required List<int> columnOfStep,
    required List<LayoutNode> nodes,
    required List<LayoutEdge> edges,
  }) : lanes = List.unmodifiable(lanes),
       columnOfStep = List.unmodifiable(columnOfStep),
       nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges);

  /// 列序（含「畫面」與必要時的「未定位」）。
  final List<SwimLane> lanes;

  /// 步驟位置 → 欄號。
  final List<int> columnOfStep;

  /// 全部節點，依欄號遞增、同欄依列序。
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;

  /// 需求：[SPEC-001 跳轉目標] 給定一列，回傳該列欄號最小的節點；空列回傳 null。
  LayoutNode? firstNodeInLane(SwimLane lane) {
    LayoutNode? best;
    for (final node in nodes) {
      if (node.lane != lane) continue;
      if (best == null || node.column < best.column) best = node;
    }
    return best;
  }
}

/// 需求：[SPEC-001 §1 泳道布局規則] 由 flow 子圖與 FR-13 列序建出布局。
SwimLaneLayout buildSwimLaneLayout({
  required FlowSubgraph flow,
  required List<BundleOrderEntry> bundleOrder,
}) {
  final steps = flow.steps;
  final lanes = assembleSwimLanes(
    bundleOrder: bundleOrder,
    stepResolutions: [for (final s in steps) s.traversesResolution],
  );
  final order = _columnOrder(steps);
  final columnOfStep = List<int>.filled(steps.length, 0);
  for (var column = 0; column < order.length; column++) {
    columnOfStep[order[column]] = column;
  }
  final nodesOfStep = _nodesPerStep(steps, lanes, columnOfStep);
  return SwimLaneLayout._(
    lanes: lanes,
    columnOfStep: columnOfStep,
    nodes: [for (final i in order) ...nodesOfStep[i]],
    edges: _edges(steps, columnOfStep, nodesOfStep),
  );
}

/// 欄序（SPEC-001 v1.43）：主線依檔內順序，分支緊接起點之後（巢狀遞迴）；
/// 沿 `branch_from` 到不了主線者（懸空、循環、依附異常）依檔內順序平鋪在
/// 最後一欄之後，尾段不套巢狀輸出。
List<int> _columnOrder(List<FlowStepNode> steps) {
  final childrenOf = <int, List<int>>{};
  for (final s in steps) {
    final parent = s.branchFrom?.targetIndex;
    if (parent != null) childrenOf.putIfAbsent(parent, () => []).add(s.index);
  }
  final order = <int>[];
  final seen = <int>{};
  void emit(int index) {
    if (!seen.add(index)) return;
    order.add(index);
    for (final child in childrenOf[index] ?? const <int>[]) {
      emit(child);
    }
  }

  for (final s in steps) {
    if (s.isMainline) emit(s.index);
  }
  for (final s in steps) {
    if (seen.add(s.index)) order.add(s.index);
  }
  return order;
}

/// 節點所屬列：缺鍵或無已宣告值者在「未定位」，`[]` 在「畫面」，
/// 其餘依已宣告值各列一節點（同欄）。
List<List<LayoutNode>> _nodesPerStep(
  List<FlowStepNode> steps,
  List<SwimLane> lanes,
  List<int> columnOfStep,
) {
  return [
    for (final s in steps)
      [
        for (final lane in _lanesOf(s, lanes))
          LayoutNode(
            stepIndex: s.index,
            column: columnOfStep[s.index],
            lane: lane,
          ),
      ],
  ];
}

/// 單一步驟所在的列，依列序由上而下。節點直接落 `BundleLane(解析名稱)`，
/// 不以字串比對判定「是否已宣告」。
///
/// 不變式（文件化）：Graph 解析出的名稱必在 FR-13 列序內（兩者出自同一批
/// DomainBundle）。違反屬程式錯誤、不是資料狀態（PM 處置 (a)）：先記一筆
/// warning（level 900，含步驟 id 與名稱），再 `assert`；release 下該名稱沒有
/// 對應列、節點不輸出，若因此一個節點也沒有，退落「未定位」列使步驟不消失
/// （release 落點不屬測試契約）。
List<SwimLane> _lanesOf(FlowStepNode step, List<SwimLane> lanes) {
  final resolution = step.traversesResolution;
  if (isUnplacedResolution(resolution)) return const [UnplacedLane()];
  final named = {for (final r in resolution.resolved) BundleLane(r.name)};
  final placed = [
    for (final lane in lanes)
      if (named.contains(lane)) lane,
  ];
  final missing = [
    for (final lane in named)
      if (!placed.contains(lane)) lane.domain,
  ];
  if (missing.isNotEmpty) _reportInvariantViolation(step, missing);
  if (placed.isNotEmpty) return placed;
  return resolution.resolved.isEmpty
      ? const [ScreenLane()]
      : const [UnplacedLane()];
}

void _reportInvariantViolation(FlowStepNode step, List<String> names) {
  developer.log(
    // i18n-exempt: 開發者 debug log
    '解析名稱不在 FR-13 列序內：step=${step.id}, names=$names',
    name: _tag,
    level: 900,
  );
  assert(
    false,
    // i18n-exempt: 開發者診斷訊息
    '解析名稱不在 FR-13 列序內：step=${step.id}, names=$names',
  );
}

/// 邊：每步驟的 `branch_from`（起點 → 本步）、`next` 各值、`return_to`。
/// 目標未解析者不畫；形狀只由欄號比較決定（目標欄 > 來源欄為直線）。
List<LayoutEdge> _edges(
  List<FlowStepNode> steps,
  List<int> columnOfStep,
  List<List<LayoutNode>> nodesOfStep,
) {
  final idIndex = _idIndex(steps);
  final edges = <LayoutEdge>[];
  void add(EdgeSource source, int from, int? to) {
    if (to == null || nodesOfStep[from].isEmpty || nodesOfStep[to].isEmpty) {
      return;
    }
    final shape = columnOfStep[to] > columnOfStep[from]
        ? EdgeShape.straight
        : EdgeShape.arc;
    edges.add(
      LayoutEdge(
        source: source,
        fromStep: from,
        toStep: to,
        shape: shape,
        from: nodesOfStep[from].first,
        to: nodesOfStep[to].first,
      ),
    );
  }

  for (final s in steps) {
    final parent = s.branchFrom?.targetIndex;
    if (parent != null) add(EdgeSource.branchFrom, parent, s.index);
    for (final target in _nextTargets(s, idIndex)) {
      add(EdgeSource.next, s.index, target);
    }
    add(EdgeSource.returnTo, s.index, s.returnTo?.targetIndex);
  }
  return edges;
}

/// `next` 各值的目標位置；主線 `next` Graph 不解析，由此以 id 唯一命中解析。
List<int?> _nextTargets(FlowStepNode s, Map<String, List<int>> idIndex) {
  final raw = s.next;
  final values = raw is Iterable ? raw : [raw];
  return [
    for (final v in values)
      if (flowKeyOf(v) case final key?) _uniqueStepIndex(idIndex, key),
  ];
}

/// 以 id 解析 `next` 目標：恰好一個步驟命中才算解析（缺席或重複皆未解析）。
/// 依據：SPEC-007 FR-10 規定 Graph 不解析主線 `next`，SPEC-001 卻要畫主線
/// `next` 邊，故 Layout 自行解析；規則對齊 FR-10 的參照解析（id 以
/// `flowKeyOf` 正規化、缺席或重複為未解析）。
/// 暫代，依 SPEC-007 v1.28 FR-10 N-a 由 0.5.0-W1-137 移除（改讀 Graph 解析結果）。
int? _uniqueStepIndex(Map<String, List<int>> idIndex, String key) {
  final hits = idIndex[key];
  return hits != null && hits.length == 1 ? hits.single : null;
}

Map<String, List<int>> _idIndex(List<FlowStepNode> steps) {
  final index = <String, List<int>>{};
  for (final s in steps) {
    final key = flowKeyOf(s.id);
    if (key != null) index.putIfAbsent(key, () => []).add(s.index);
  }
  return index;
}
