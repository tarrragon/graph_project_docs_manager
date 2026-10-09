// SPEC-001〈間接依賴格的「在泳道中檢視」跳轉目標〉：
// 「給定一列，回傳欄號最小的節點」查詢；測試設計 §3 L9-1～L9-4。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec001/flow_builder.dart';

void main() {
  test('L9-1 UC-04 快照列 graph：欄號最小且 traverses 含 graph 的節點', () async {
    final flow = (await loadSnapshotFlows(
      'graph_project_docs_manager',
    ))['UC-04']!;
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: projectBundleOrder,
    );
    final node = layout.firstNodeInLane(const BundleLane('graph'))!;
    // 分支 reverse-trace 插在起點 select-proposal 之後（欄 1），欄號小於檔內第一個
    // 含 graph 的 expand-downstream（欄 2）。
    expect('${flow.steps[node.stepIndex].id}', 'reverse-trace');
    expect(node.column, 1);
    expect(node.lane, const BundleLane('graph'));
  });

  test('L9-2 E1 欄號對清單順序：回傳欄號較小者，取清單第一步會得另一個', () {
    final flow = buildFlow(
      [
        stepRow('M'),
        stepRow('A', traverses: ['x']),
        stepRow('B', branchFrom: 'M', traverses: ['x']),
      ],
      declaredDomains: ['x'],
    );
    final layout = buildSwimLaneLayout(flow: flow, bundleOrder: orderOf(['x']));
    // 欄序 M 0、B 1、A 2：B 在檔內較後，欄號卻較小。
    final picked = layout.firstNodeInLane(const BundleLane('x'))!;
    final firstInFileOrder = flow.steps.firstWhere(
      (s) => s.traversesResolution.resolved.isNotEmpty,
    );
    expect('${flow.steps[picked.stepIndex].id}', 'B');
    expect('${firstInFileOrder.id}', 'A');
    // 取清單順序第一步（A）會得欄 2，實際回傳欄 1。
    expect(layout.columnOfStep[firstInFileOrder.index], 2);
    expect(picked.column, 1);
  });

  test('L9-3 多列節點：回傳指定列上的節點，不是該步驟最上方節點', () {
    final flow = buildFlow(
      [
        stepRow('multi', next: ['solo'], traverses: ['graph', 'corpus']),
        stepRow('solo', traverses: ['corpus']),
      ],
      declaredDomains: ['graph', 'corpus'],
    );
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: orderOf(['graph', 'corpus']),
    );
    final node = layout.firstNodeInLane(const BundleLane('corpus'))!;
    expect('${flow.steps[node.stepIndex].id}', 'multi');
    expect(node.lane, const BundleLane('corpus'));
    expect(node.lane, isNot(const BundleLane('graph')));
  });

  test('L9-4 列存在但無節點：回傳 null，可與有節點區分', () {
    final flow = buildFlow(
      [
        stepRow('s', traverses: ['graph']),
      ],
      declaredDomains: ['graph', 'empty'],
    );
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: orderOf(['graph', 'empty']),
    );
    expect(layout.firstNodeInLane(const BundleLane('empty')), isNull);
    expect(layout.firstNodeInLane(const BundleLane('graph')), isNotNull);
    // 重複宣告列：兩列皆無節點。
    final dup = buildFlow(
      [
        stepRow('s', traverses: ['corpus']),
      ],
      declaredDomains: ['corpus', 'corpus'],
    );
    final dupLayout = buildSwimLaneLayout(
      flow: dup,
      bundleOrder: orderOf(['corpus', 'corpus']),
    );
    expect(dupLayout.firstNodeInLane(const BundleLane('corpus')), isNull);
    expect(dupLayout.firstNodeInLane(const UnplacedLane()), isNotNull);
  });
}
