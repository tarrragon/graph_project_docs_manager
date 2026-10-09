// SPEC-001 §1〈泳道布局規則〉邊的來源、形狀、端點；測試設計 §3 L5-1～L5-6。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec001/flow_builder.dart';
import '../../helpers/spec001/layout_probe.dart';

Map<String, EdgeShape> shapesOf(FlowSubgraph flow, SwimLaneLayout layout) => {
  for (final e in layout.edges) edgeLabel(flow, e): e.shape,
};

void main() {
  late Map<String, FlowSubgraph> project;
  late Map<String, FlowSubgraph> balance;

  setUpAll(() async {
    project = await loadSnapshotFlows('graph_project_docs_manager');
    balance = await loadSnapshotFlows('flutter_balance');
  });

  test('L5-1 UC-02 flow-not-structured 同時帶分支起點與 return_to：兩條都畫', () {
    final flow = project['UC-02']!;
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: projectBundleOrder,
    );
    final touching = [
      for (final e in layout.edges)
        if (flow.steps[e.fromStep].id == 'flow-not-structured' ||
            flow.steps[e.toStep].id == 'flow-not-structured')
          edgeLabel(flow, e),
    ];
    expect(
      touching,
      unorderedEquals([
        'switch-to-swimlane>flow-not-structured',
        'flow-not-structured>locate-domain',
      ]),
    );
    // 形狀（SPEC-001 期望值欄）：5→0 弧線；1→2 直線。
    final shapes = shapesOf(flow, layout);
    expect(shapes['flow-not-structured>locate-domain'], EdgeShape.arc);
    expect(
      shapes['enter-from-ticket>read-traversal-count'],
      EdgeShape.straight,
    );
  });

  test('L5-2 目標欄 > 來源欄：直線', () {
    final flow = buildFlow([
      stepRow('a', next: ['b']),
      stepRow('b'),
    ]);
    final layout = buildSwimLaneLayout(flow: flow, bundleOrder: const []);
    expect(shapesOf(flow, layout), {'a>b': EdgeShape.straight});
  });

  test('L5-3 E1 形狀由欄號決定：return_to 指向更大欄為直線，next 指向較小欄為弧線', () {
    final flow = buildFlow([
      stepRow('A', returnTo: 'C'),
      stepRow('B'),
      stepRow('C', next: ['A']),
    ]);
    final layout = buildSwimLaneLayout(flow: flow, bundleOrder: const []);
    final byKey = {
      for (final e in layout.edges)
        '${e.source.name}:${edgeLabel(flow, e)}': e.shape,
    };
    expect(byKey, {
      'returnTo:A>C': EdgeShape.straight,
      'next:C>A': EdgeShape.arc,
    });
    expect(byKey['returnTo:A>C'], isNot(byKey['next:C>A']));
  });

  test('L5-4 目標欄 = 來源欄（自指）：弧線', () {
    final flow = buildFlow([
      stepRow('a', next: ['a']),
    ]);
    final layout = buildSwimLaneLayout(flow: flow, bundleOrder: const []);
    expect(shapesOf(flow, layout), {'a>a': EdgeShape.arc});
  });

  test('L5-5 多列節點的步驟：邊端點為最上方節點所在列', () {
    final flow = buildFlow(
      [
        stepRow('multi', next: ['next'], traverses: ['lower', 'upper']),
        stepRow('next', traverses: ['lower']),
      ],
      declaredDomains: ['upper', 'lower'],
    );
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: orderOf(['upper', 'lower']),
    );
    final edge = layout.edges.single;
    expect(laneLabel(edge.from.lane), 'upper');
    expect(laneLabel(edge.to.lane), 'lower');
    // 兩列各有 multi 的節點，端點取列序在上者。
    expect(
      layout.nodes.where((n) => n.stepIndex == 0).map((n) => laneLabel(n.lane)),
      containsAll(['upper', 'lower']),
    );
  });

  test('L5-6 flutter_balance：4 弧線、8 直線', () {
    final flow = balance['UC-01']!;
    final layout = buildSwimLaneLayout(
      flow: flow,
      bundleOrder: const [(domain: 'balance-sheet', layer: 0)],
    );
    final shapes = layout.edges.map((e) => e.shape);
    expect(shapes.where((s) => s == EdgeShape.arc), hasLength(4));
    expect(shapes.where((s) => s == EdgeShape.straight), hasLength(8));
    final arcs = {
      for (final e in layout.edges)
        if (e.shape == EdgeShape.arc) edgeLabel(flow, e),
    };
    expect(arcs, {
      'backup-restore>create-accounts',
      'reject-invalid-input>first-inventory',
      'currency-switch>view-net-worth',
      'cashflow-runway>view-net-worth',
    });
  });
}
