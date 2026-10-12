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

  test('L5-1b 同一步驟 next 非空且帶 return_to：兩條邊都畫', () {
    final flow = buildFlow([
      stepRow('a', next: ['b']),
      stepRow('b', next: ['c'], returnTo: 'a'),
      stepRow('c'),
    ]);
    final layout = buildSwimLaneLayout(flow: flow, bundleOrder: const []);
    final fromB = {
      for (final e in layout.edges)
        if (flow.steps[e.fromStep].id == 'b')
          '${e.source.name}:${edgeLabel(flow, e)}': e.shape,
    };
    expect(fromB, {
      'next:b>c': EdgeShape.straight,
      'returnTo:b>a': EdgeShape.arc,
    });
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

  // 0.5.0-W1-137 改寫前的 Layout 輸出，作為回歸基準。
  // 格式：UC|來源欄位|fromStep|toStep|形狀（兩語料快照，共 58 筆）。
  const baselineEdges = {
    'graph_project_docs_manager': [
      'UC-01|next|0|1|straight',
      'UC-01|next|1|2|straight',
      'UC-01|next|2|3|straight',
      'UC-01|branchFrom|0|4|straight',
      'UC-01|returnTo|4|0|arc',
      'UC-01|branchFrom|2|5|straight',
      'UC-01|branchFrom|1|6|straight',
      'UC-01|returnTo|6|0|arc',
      'UC-02|next|0|1|straight',
      'UC-02|next|1|2|straight',
      'UC-02|next|2|3|straight',
      'UC-02|branchFrom|1|4|straight',
      'UC-02|branchFrom|0|5|straight',
      'UC-02|next|5|1|straight',
      'UC-02|branchFrom|2|6|straight',
      'UC-02|returnTo|6|0|arc',
      'UC-03|next|0|1|straight',
      'UC-03|next|1|2|straight',
      'UC-03|branchFrom|1|3|straight',
      'UC-03|branchFrom|1|4|straight',
      'UC-03|returnTo|4|1|arc',
      'UC-03|branchFrom|0|5|straight',
      'UC-03|returnTo|5|0|arc',
      'UC-04|next|0|1|straight',
      'UC-04|next|1|2|straight',
      'UC-04|next|2|3|straight',
      'UC-04|branchFrom|0|4|straight',
      'UC-04|next|4|2|straight',
      'UC-04|branchFrom|1|5|straight',
      'UC-04|returnTo|5|1|arc',
      'UC-05|next|0|1|straight',
      'UC-05|next|1|2|straight',
      'UC-05|next|2|3|straight',
      'UC-05|branchFrom|2|4|straight',
      'UC-05|returnTo|4|2|arc',
      'UC-05|branchFrom|1|5|straight',
      'UC-05|returnTo|5|0|arc',
      'UC-05|branchFrom|1|6|straight',
      'UC-06|next|0|1|straight',
      'UC-06|next|1|2|straight',
      'UC-06|next|2|3|straight',
      'UC-06|branchFrom|3|4|straight',
      'UC-06|next|4|1|arc',
      'UC-06|returnTo|4|1|arc',
      'UC-06|branchFrom|1|5|straight',
      'UC-06|branchFrom|1|6|straight',
    ],
    'flutter_balance': [
      'UC-01|next|0|1|straight',
      'UC-01|next|1|2|straight',
      'UC-01|next|2|3|straight',
      'UC-01|next|3|4|straight',
      'UC-01|branchFrom|2|5|straight',
      'UC-01|returnTo|5|2|arc',
      'UC-01|branchFrom|2|6|straight',
      'UC-01|returnTo|6|2|arc',
      'UC-01|branchFrom|0|7|straight',
      'UC-01|returnTo|7|0|arc',
      'UC-01|branchFrom|1|8|straight',
      'UC-01|returnTo|8|1|arc',
    ],
  };

  Set<String> edgeKeysOf(Map<String, FlowSubgraph> flows) => {
    for (final entry in flows.entries)
      for (final e in buildSwimLaneLayout(
        flow: entry.value,
        bundleOrder: projectBundleOrder,
      ).edges)
        '${entry.key}|${e.source.name}|${e.fromStep}|${e.toStep}|'
            '${e.shape.name}',
  };

  test('L5-7 R1 兩語料完整邊集合與改寫前基準相同（含 source、端點、形狀）', () {
    expect(
      edgeKeysOf(project),
      equals({...baselineEdges['graph_project_docs_manager']!}),
    );
    expect(edgeKeysOf(balance), equals({...baselineEdges['flutter_balance']!}));
  });

  test('L5-8 R2 主線 next 指向不存在或重複 id：不畫該邊、不拋例外，可解析者照畫', () {
    final cases = {
      'missing': [
        stepRow('bad', next: ['ghost']),
        stepRow('ok', next: ['target']),
        stepRow('target'),
      ],
      'duplicate': [
        stepRow('bad', next: ['dup']),
        stepRow('ok', next: ['target']),
        stepRow('dup'),
        stepRow('dup'),
        stepRow('target'),
      ],
    };
    for (final entry in cases.entries) {
      final flow = buildFlow(entry.value);
      late SwimLaneLayout layout;
      expect(
        () => layout = buildSwimLaneLayout(flow: flow, bundleOrder: const []),
        returnsNormally,
        reason: entry.key,
      );
      final nextLabels = [
        for (final e in layout.edges)
          if (e.source == EdgeSource.next) edgeLabel(flow, e),
      ];
      expect(nextLabels, ['ok>target'], reason: entry.key);
    }
  });
}
