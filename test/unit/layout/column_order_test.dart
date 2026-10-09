// SPEC-001 §1〈泳道布局規則〉主線、欄序、欄序無法輸出的步驟；
// 測試設計 §3 L3-1～L3-5、L6-1～L6-4。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec001/flow_builder.dart';
import '../../helpers/spec001/layout_probe.dart';

SwimLaneLayout layoutOf(FlowSubgraph flow, [List<String> domains = const []]) =>
    buildSwimLaneLayout(flow: flow, bundleOrder: orderOf(domains));

const balanceOrder = [(domain: 'balance-sheet', layer: 0)];

void main() {
  late Map<String, FlowSubgraph> project;
  late Map<String, FlowSubgraph> balance;

  setUpAll(() async {
    project = await loadSnapshotFlows('graph_project_docs_manager');
    balance = await loadSnapshotFlows('flutter_balance');
  });

  group('L3 主線與欄序', () {
    test('L3-1 UC-02 快照欄序 0..6（SPEC-001 期望值欄）', () {
      final flow = project['UC-02']!;
      final layout = buildSwimLaneLayout(
        flow: flow,
        bundleOrder: projectBundleOrder,
      );
      expect(stepIdsByColumn(flow, layout), [
        'locate-domain',
        'enter-from-ticket',
        'read-traversal-count',
        'matrix-overview-only',
        'switch-to-swimlane',
        'flow-not-structured',
        'inspect-steps',
      ]);
      expect(layout.columnOfStep, hasLength(7));
    });

    test('L3-2 flutter_balance UC-01 欄序依 §1.2 表', () {
      final flow = balance['UC-01']!;
      final layout = buildSwimLaneLayout(flow: flow, bundleOrder: balanceOrder);
      expect(columnsById(flow, layout), {
        'create-accounts': 0,
        'backup-restore': 1,
        'first-inventory': 2,
        'reject-invalid-input': 3,
        'view-net-worth': 4,
        'currency-switch': 5,
        'cashflow-runway': 6,
        'assess-leverage': 7,
        'periodic-inventory': 8,
      });
    });

    test('L3-3 E1 檔內順序 A、C、B 對 next 鏈 A→B→C：兩者結果不同', () {
      final flow = buildFlow([
        stepRow('A', next: ['B']),
        stepRow('C'),
        stepRow('B', next: ['C']),
      ]);
      final layout = layoutOf(flow);
      final byFileOrder = stepIdsByColumn(flow, layout);
      expect(byFileOrder, ['A', 'C', 'B']);
      // 對照組：由輸入實際推導的 next 鏈順序（自第一步沿 next 走）。
      final byNextChain = <String>[];
      FlowStepNode? cursor = flow.steps.first;
      while (cursor != null) {
        byNextChain.add('${cursor.id}');
        final nextIds = cursor.next as List;
        cursor = nextIds.isEmpty
            ? null
            : flow.steps.firstWhere((s) => s.id == nextIds.first);
      }
      expect(byNextChain, ['A', 'B', 'C']);
      expect(byFileOrder, isNot(byNextChain));
    });

    test('L3-4 巢狀分支：M、B、B2、B3（B2 緊接 B 之後再輸出 B3）', () {
      final flow = buildFlow([
        stepRow('M'),
        stepRow('B', branchFrom: 'M'),
        stepRow('B3', branchFrom: 'M'),
        stepRow('B2', branchFrom: 'B'),
      ]);
      expect(stepIdsByColumn(flow, layoutOf(flow)), ['M', 'B', 'B2', 'B3']);
    });

    test('L3-5 每步驟恰一欄：欄號集合為 0..n-1 無重複無缺號', () {
      final flows = [
        project['UC-02']!,
        project['UC-04']!,
        balance['UC-01']!,
        buildFlow([
          stepRow('M'),
          stepRow('B', branchFrom: 'M'),
          stepRow('B2', branchFrom: 'B'),
        ]),
      ];
      for (final flow in flows) {
        final columns = layoutOf(flow).columnOfStep;
        expect(columns.toSet(), {for (var i = 0; i < columns.length; i++) i});
        expect(columns, hasLength(flow.steps.length));
      }
    });
  });

  group('L6 欄序無法輸出的步驟（結構異常接在最後）', () {
    test('L6-1 守衛：懸空 branch_from 的 X 接在最後一欄之後、不畫其 branch_from 邊', () {
      final flow = buildFlow([
        stepRow('X', branchFrom: 'ghost'),
        stepRow('a'),
        stepRow('b'),
      ]);
      final layout = layoutOf(flow);
      expect(stepIdsByColumn(flow, layout), ['a', 'b', 'X']);
      expect(
        layout.edges.where((e) => e.source == EdgeSource.branchFrom),
        isEmpty,
      );
      // 正向對照（L3-1 形態）：同一步驟的 branch_from 有效時依分支規則落在起點後。
      final control = buildFlow([
        stepRow('X', branchFrom: 'a'),
        stepRow('a'),
        stepRow('b'),
      ]);
      final controlLayout = layoutOf(control);
      expect(stepIdsByColumn(control, controlLayout), ['a', 'X', 'b']);
      expect(
        controlLayout.edges.where((e) => e.source == EdgeSource.branchFrom),
        hasLength(1),
      );
      expectStepsConserved(flow, layout);
    });

    test('L6-2 守衛：Y、Z 互為 branch_from 依檔內順序接在最後，邊照畫、形狀依欄號', () {
      final flow = buildFlow([
        stepRow('Y', branchFrom: 'Z'),
        stepRow('Z', branchFrom: 'Y'),
        stepRow('m'),
      ]);
      final layout = layoutOf(flow);
      expect(stepIdsByColumn(flow, layout), ['m', 'Y', 'Z']);
      final shapes = {
        for (final e in layout.edges) edgeLabel(flow, e): e.shape,
      };
      // 邊為起點 → 分支步驟：Z>Y（欄 2→1）回指，Y>Z（欄 1→2）前向。
      expect(shapes, {'Z>Y': EdgeShape.arc, 'Y>Z': EdgeShape.straight});
      // 正向對照：無循環時 Y、Z 不會排在 m 之後。
      final control = buildFlow([
        stepRow('Y', branchFrom: 'm'),
        stepRow('Z', branchFrom: 'm'),
        stepRow('m'),
      ]);
      expect(stepIdsByColumn(control, layoutOf(control)), ['m', 'Y', 'Z']);
      expect(columnsById(control, layoutOf(control))['m'], 0);
      expectStepsConserved(flow, layout);
    });

    test('L6-3 懸空 X 與循環 Y、Z 交錯：三者依檔內順序平鋪接在最後', () {
      // 交錯順序：若尾段遞迴輸出巢狀，Y 之後會緊接 Z（M、Y、Z、X）。
      final flow = buildFlow([
        stepRow('Y', branchFrom: 'Z'),
        stepRow('M'),
        stepRow('X', branchFrom: 'ghost'),
        stepRow('Z', branchFrom: 'Y'),
      ]);
      final layout = layoutOf(flow);
      expect(stepIdsByColumn(flow, layout), ['M', 'Y', 'X', 'Z']);
      expectStepsConserved(flow, layout);
    });

    test('L6-5 (c) 依附異常：C 的 branch_from 指向懸空 X，平鋪且 branch_from 邊照畫', () {
      // 檔內 C、M、X、D：C 掛在 X 之下，X 懸空；D 也掛在 X。
      final flow = buildFlow([
        stepRow('C', branchFrom: 'X'),
        stepRow('M'),
        stepRow('X', branchFrom: 'ghost'),
        stepRow('D', branchFrom: 'X'),
      ]);
      final layout = layoutOf(flow);
      // 平鋪依檔內順序：C、X、D（X 之後不緊接其子步驟）。
      expect(stepIdsByColumn(flow, layout), ['M', 'C', 'X', 'D']);
      final branchEdges = {
        for (final e in layout.edges)
          if (e.source == EdgeSource.branchFrom) edgeLabel(flow, e): e.shape,
      };
      // X 的 branch_from（懸空）不畫；C、D 的邊照畫：X>C 欄 2→1 弧線，X>D 欄 2→3 直線。
      expect(branchEdges, {'X>C': EdgeShape.arc, 'X>D': EdgeShape.straight});
      expectStepsConserved(flow, layout);
    });

    test('L6-4 步驟總數守恆：L6-1～L6-3 輸入各驗輸出欄數 = 輸入步驟數', () {
      final inputs = [
        [stepRow('X', branchFrom: 'ghost'), stepRow('a')],
        [
          stepRow('Y', branchFrom: 'Z'),
          stepRow('Z', branchFrom: 'Y'),
          stepRow('m'),
        ],
        [
          stepRow('X', branchFrom: 'ghost'),
          stepRow('Y', branchFrom: 'Z'),
          stepRow('Z', branchFrom: 'Y'),
          stepRow('m'),
        ],
      ];
      for (final rows in inputs) {
        final flow = buildFlow(rows);
        final layout = layoutOf(flow);
        expect(layout.columnOfStep, hasLength(rows.length));
        expectStepsConserved(flow, layout);
      }
    });
  });
}
