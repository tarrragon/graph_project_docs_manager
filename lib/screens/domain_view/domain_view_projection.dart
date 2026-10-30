/// Domain 視圖投影（SPEC-001 §1 正常 · 矩陣／已選格／正常 · 泳道／
/// 泳道 · flow 未結構化）：由 Graph 建圖結果與 Layout 布局算出畫面模型。
///
/// 純函式：不讀檔、不碰 provider。只依賴 Graph／Layout 公開面與本畫面模型
/// （`domain_view_state.dart`）；關係種類與依賴路徑取 SPEC-007 FR-12、列序取
/// FR-13、flow 子圖取 FR-10，本檔不另推導。
library;

import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/domain_uc_relation.dart';
import 'package:graph_project_docs_manager/graph/flow_query.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';

/// 依賴路徑各 domain 之間的連接字面（SPEC-001 §1：`X → … → Y`）。
const dependencyPathSeparator = ' → ';

/// 需求：[SPEC-001 §1 正常 · 矩陣／已選格] 列＝DomainBundle（FR-13 列序），
/// 欄＝[ucIds]（依傳入順序），格關係取 FR-12，列末小計＝直接貫穿格數。
DomainMatrix projectDomainMatrix({
  required GraphBuiltEvent event,
  required List<String> ucIds,
}) {
  final available = GraphBuildAvailable(event);
  final relations = DomainUcRelationQuery(buildResult: available);
  final flows = FlowQuery(buildResult: available);
  return DomainMatrix(
    columns: [for (final id in ucIds) _ucColumn(event, flows, id)],
    rows: [
      for (final bundle in _orderedBundles(available))
        _row(bundle, ucIds, relations, flows),
    ],
  );
}

/// 需求：[SPEC-001 §1 正常 · 泳道／泳道 · flow 未結構化] 選定 UC 的泳道資料。
///
/// [flowParseFailedUcIds] 為有 flow 區塊解析失敗的 UC（SPEC-006 EVT-CORPUS-004，
/// 由呼叫端自 Corpus 結果轉成 UC id 集合）：有 FlowStep 者帶提示旗標，無者
/// 標為「flow 區塊皆解析失敗」。
DomainSwimlaneView projectDomainSwimlane({
  required GraphBuiltEvent event,
  required String ucId,
  Set<String> flowParseFailedUcIds = const {},
}) {
  final available = GraphBuildAvailable(event);
  final isFailed = flowParseFailedUcIds.contains(ucId);
  final flow = _flowOf(FlowQuery(buildResult: available), ucId);
  if (flow == null || flow.steps.isEmpty) {
    return DomainSwimlaneUnstructured(isFlowParseFailed: isFailed);
  }
  final bundles = _orderedBundles(available);
  final layout = buildSwimLaneLayout(
    flow: flow,
    bundleOrder: [for (final e in bundles) (domain: e.domain, layer: e.layer)],
  );
  return DomainSwimlane(
    lanes: _lanes(layout, bundles, flow),
    edges: [for (final edge in layout.edges) _edge(layout, edge)],
    hasFlowParseFailure: isFailed,
  );
}

/// 需求：[SPEC-001 §1 泳道 · 尚未選定 UC] 未選定 UC 的列結構：頂端「畫面」列 +
/// FR-13 列序的各 DomainBundle 列（與 [projectDomainSwimlane] 共用
/// [_orderedBundles]），皆無節點。
List<DomainLane> projectEmptyLanes(GraphBuiltEvent event) => [
  const DomainLane(domainId: null, kind: DomainLaneKind.screen, nodes: []),
  for (final bundle in _orderedBundles(GraphBuildAvailable(event)))
    DomainLane(
      domainId: bundle.bundleId,
      domainName: bundle.domain,
      nodes: const [],
    ),
];

/// 需求：[SPEC-001 §1 間接依賴格的「在泳道中檢視」跳轉目標] 給定 UC 與列的
/// domain 字面，回傳 Layout 公開面「該列欄號最小的節點」（L9）；UC 無 flow
/// 或該列無節點時為 null。畫面不自行組合欄號。
LayoutNode? firstNodeInLaneOf({
  required GraphBuiltEvent event,
  required String ucId,
  required String domain,
}) {
  final available = GraphBuildAvailable(event);
  final flow = _flowOf(FlowQuery(buildResult: available), ucId);
  if (flow == null || flow.steps.isEmpty) return null;
  final bundles = _orderedBundles(available);
  final layout = buildSwimLaneLayout(
    flow: flow,
    bundleOrder: [for (final e in bundles) (domain: e.domain, layer: e.layer)],
  );
  return layout.firstNodeInLane(BundleLane(domain));
}

/// FR-13 列序；投影只在建圖可用時呼叫，不可用分支不會發生。
List<BundleLayerEntry> _orderedBundles(GraphBuildAvailable available) =>
    switch (BundleLayerQuery(buildResult: available).orderedBundles()) {
      BundleOrderAvailable(:final entries) => entries,
      BundleOrderGraphUnavailable() => const [],
    };

FlowSubgraph? _flowOf(FlowQuery flows, String ucId) =>
    switch (flows.flowOf(ucId)) {
      FlowOfAvailable(:final subgraph) => subgraph,
      _ => null,
    };

DomainUc _ucColumn(GraphBuiltEvent event, FlowQuery flows, String ucId) {
  final node = event.nodes.where((n) => n.id == ucId).firstOrNull;
  return DomainUc(
    id: ucId,
    title: node?.displayTitle ?? '',
    hasFlowStep: _flowOf(flows, ucId)?.steps.isNotEmpty ?? false,
    filePath: node?.path,
  );
}

DomainRow _row(
  BundleLayerEntry bundle,
  List<String> ucIds,
  DomainUcRelationQuery relations,
  FlowQuery flows,
) {
  final cells = [
    for (final uc in ucIds) _cell(bundle, uc, relations, _flowOf(flows, uc)),
  ];
  return DomainRow(
    domainId: bundle.bundleId,
    domainName: bundle.domain,
    cells: cells,
    subtotal: cells.where((c) => c.relation == DomainRelation.direct).length,
  );
}

/// 需求：[SPEC-003 §3.1 格詳情卡的內容契約] 步驟取 `traverses` 解析含該 domain
/// 者（flow 順序），事件取其 emits／consumes，依賴路徑取 FR-12；說明無資料來源。
DomainCell _cell(
  BundleLayerEntry bundle,
  String ucId,
  DomainUcRelationQuery relations,
  FlowSubgraph? flow,
) {
  final relation = relations.relationOf(bundle.bundleId, ucId);
  final steps = [
    for (final step in flow?.steps ?? const <FlowStepNode>[])
      if (step.traversesResolution.resolved.any(
        (r) => r.bundleId == bundle.bundleId,
      ))
        step,
  ];
  return DomainCell(
    domainId: bundle.bundleId,
    ucId: ucId,
    relation: _relationOf(relation),
    steps: [for (final s in steps) _stepLabel(s)],
    events: _cellEventTags(steps),
    dependencyPaths: _dependencyPaths(relation),
    indirectSource: _indirectSource(relation),
  );
}

String? _indirectSource(DomainUcRelationResult result) => switch (result) {
  DomainUcRelationAvailable(
    kind: DomainUcRelationKind.indirect,
    :final paths,
  ) =>
    paths.firstOrNull?.firstOrNull?.domain,
  _ => null,
};

DomainRelation _relationOf(DomainUcRelationResult result) => switch (result) {
  DomainUcRelationAvailable(kind: DomainUcRelationKind.direct) =>
    DomainRelation.direct,
  DomainUcRelationAvailable(kind: DomainUcRelationKind.indirect) =>
    DomainRelation.indirect,
  _ => DomainRelation.none,
};

List<String> _dependencyPaths(DomainUcRelationResult result) =>
    switch (result) {
      DomainUcRelationAvailable(:final paths) => [
        for (final path in paths)
          [for (final b in path) b.domain].join(dependencyPathSeparator),
      ],
      _ => const [],
    };

/// 需求：[SPEC-003 §3.1 事件標籤] 每個（事件, 方向）一筆；不同事件依首次出現
/// 的步驟序，同一步驟首次出現者依 emits 清單、再 consumes 清單順序；同一事件
/// 兩筆相鄰、emits 在前。
List<(String, bool)> _cellEventTags(List<FlowStepNode> steps) {
  final order = <String>{};
  final emitted = <String>{};
  final consumed = <String>{};
  for (final step in steps) {
    for (final name in step.emitsNames) {
      order.add(name);
      emitted.add(name);
    }
    for (final name in step.consumesNames) {
      order.add(name);
      consumed.add(name);
    }
  }
  return [
    for (final name in order) ...[
      if (emitted.contains(name)) (name, true),
      if (consumed.contains(name)) (name, false),
    ],
  ];
}

/// 步驟顯示字面：`name`，缺或空時退用 `id`。
String _stepLabel(FlowStepNode step) =>
    flowKeyOf(step.name) ?? flowKeyOf(step.id) ?? '';

List<DomainLane> _lanes(
  SwimLaneLayout layout,
  List<BundleLayerEntry> bundles,
  FlowSubgraph flow,
) {
  final byDomain = _bundlesByDomain(bundles);
  return [
    for (final lane in layout.lanes)
      switch (lane) {
        ScreenLane() => _lane(layout, flow, lane, DomainLaneKind.screen),
        UnplacedLane() => _lane(layout, flow, lane, DomainLaneKind.unplaced),
        BundleLane(:final domain) => _lane(
          layout,
          flow,
          lane,
          DomainLaneKind.domain,
          bundle: byDomain[domain]!.removeAt(0),
        ),
      },
  ];
}

/// 以 domain 字面查 FR-13 項。同一字面可對應多個 bundle（重複宣告、FR-13 Z3
/// 的無效 domain 皆可能列首文字相同），依 FR-13 先後逐一取用。
Map<String, List<BundleLayerEntry>> _bundlesByDomain(
  List<BundleLayerEntry> bundles,
) {
  final byDomain = <String, List<BundleLayerEntry>>{};
  for (final entry in bundles) {
    (byDomain[entry.domain] ??= []).add(entry);
  }
  return byDomain;
}

DomainLane _lane(
  SwimLaneLayout layout,
  FlowSubgraph flow,
  SwimLane lane,
  DomainLaneKind kind, {
  BundleLayerEntry? bundle,
}) => DomainLane(
  domainId: bundle?.bundleId,
  domainName: bundle?.domain,
  kind: kind,
  nodes: [
    for (final node in layout.nodes)
      if (node.lane == lane) _node(flow.steps[node.stepIndex], node.column),
  ],
);

DomainLaneNode _node(FlowStepNode step, int column) => DomainLaneNode(
  stepLabel: _stepLabel(step),
  column: column,
  stepTraverses: [
    for (final r in step.traversesResolution.resolved) r.bundleId,
  ],
  stepId: flowKeyOf(step.id),
);

DomainLaneEdge _edge(SwimLaneLayout layout, LayoutEdge edge) => DomainLaneEdge(
  fromColumn: edge.from.column,
  toColumn: edge.to.column,
  fromLane: layout.lanes.indexOf(edge.from.lane),
  toLane: layout.lanes.indexOf(edge.to.lane),
  shape: edge.shape == EdgeShape.straight
      ? DomainLaneEdgeShape.straight
      : DomainLaneEdgeShape.arc,
);
