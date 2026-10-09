/// Layout 布局結果的讀取輔助（L3～L9 共用）：把步驟位置換回步驟 id、
/// 把列換成字面，使斷言可逐值對照規格表。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

/// 列的字面：'畫面'、domain 名、'未定位'。
String laneLabel(SwimLane lane) => switch (lane) {
  ScreenLane() => '畫面', // i18n-exempt: 測試斷言字面（規格列首字面）
  BundleLane(:final domain) => domain,
  UnplacedLane() => '未定位', // i18n-exempt: 測試斷言字面（規格列首字面）
};

/// 步驟 id → 欄號。
Map<String, int> columnsById(FlowSubgraph flow, SwimLaneLayout layout) => {
  for (final s in flow.steps) '${s.id}': layout.columnOfStep[s.index],
};

/// 依欄號遞增排列的步驟 id。
List<String> stepIdsByColumn(FlowSubgraph flow, SwimLaneLayout layout) {
  final byColumn = columnsById(flow, layout).entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in byColumn) e.key];
}

/// 步驟 id → 該步驟節點所在列字面（依列序由上而下）。
Map<String, List<String>> laneLabelsById(
  FlowSubgraph flow,
  SwimLaneLayout layout,
) => {
  for (final s in flow.steps)
    '${s.id}': [
      for (final n in layout.nodes)
        if (n.stepIndex == s.index) laneLabel(n.lane),
    ],
};

/// 邊的字面：`來源id>目標id`。
String edgeLabel(FlowSubgraph flow, LayoutEdge e) =>
    '${flow.steps[e.fromStep].id}>${flow.steps[e.toStep].id}';

/// 步驟總數守恆（L6-4、L7-9）：輸出欄數與有節點的步驟集合都等於輸入。
void expectStepsConserved(FlowSubgraph flow, SwimLaneLayout layout) {
  final n = flow.steps.length;
  expect(layout.columnOfStep, hasLength(n));
  expect({...layout.columnOfStep}, {for (var i = 0; i < n; i++) i});
  expect(
    {for (final node in layout.nodes) node.stepIndex},
    {for (var i = 0; i < n; i++) i},
  );
}
