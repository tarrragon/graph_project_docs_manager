// SPEC-001 §1〈泳道布局規則〉列鍵比對、節點所屬列、「traverses 異常的步驟」；
// 測試設計 §3 L4-1～L4-4、L7-1～L7-9。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec001/flow_builder.dart';
import '../../helpers/spec001/layout_probe.dart';

SwimLaneLayout layoutWith(
  FlowSubgraph flow,
  List<BundleOrderEntry> bundleOrder,
) => buildSwimLaneLayout(flow: flow, bundleOrder: bundleOrder);

List<String> labels(SwimLaneLayout layout) => [
  for (final lane in layout.lanes) laneLabel(lane),
];

bool hasUnplaced(SwimLaneLayout layout) =>
    layout.lanes.any((l) => l is UnplacedLane);

const balanceOrder = [(domain: 'balance-sheet', layer: 0)];

void main() {
  late Map<String, FlowSubgraph> project;
  late Map<String, FlowSubgraph> balance;

  setUpAll(() async {
    project = await loadSnapshotFlows('graph_project_docs_manager');
    balance = await loadSnapshotFlows('flutter_balance');
  });

  group('L4 節點所屬列與「畫面」列', () {
    test('L4-1 UC-02 enter-from-ticket 在 graph、ticketdetail 兩列欄 1 各一節點', () {
      final flow = project['UC-02']!;
      final layout = layoutWith(flow, projectBundleOrder);
      final nodes = layout.nodes.where(
        (n) => flow.steps[n.stepIndex].id == 'enter-from-ticket',
      );
      expect(
        {for (final n in nodes) laneLabel(n.lane): n.column},
        {'graph': 1, 'ticketdetail': 1},
      );
      expect(nodes, hasLength(2));
      // locate-domain 於「畫面」列欄 0。
      expect(laneLabelsById(flow, layout)['locate-domain'], ['畫面']);
      expect(columnsById(flow, layout)['locate-domain'], 0);
      // 全部已宣告：無「未定位」列（L7-1 正向對照）。
      expect(hasUnplaced(layout), isFalse);
    });

    test('L4-2 traverses [] 只在「畫面」列一個節點', () {
      final flow = buildFlow([stepRow('s')], declaredDomains: ['graph']);
      final layout = layoutWith(flow, orderOf(['graph']));
      expect(laneLabelsById(flow, layout)['s'], ['畫面']);
      expect(layout.nodes, hasLength(1));
    });

    test('L4-3 E1 精確比對：Graph 落未定位列，graph 落 graph 列，所在列不同', () {
      final upper = buildFlow(
        [
          stepRow('s', traverses: ['Graph']),
        ],
        declaredDomains: ['graph'],
      );
      final lower = buildFlow(
        [
          stepRow('s', traverses: ['graph']),
        ],
        declaredDomains: ['graph'],
      );
      final upperLayout = layoutWith(upper, orderOf(['graph']));
      final lowerLayout = layoutWith(lower, orderOf(['graph']));
      expect(laneLabelsById(upper, upperLayout)['s'], ['未定位']);
      expect(laneLabelsById(lower, lowerLayout)['s'], ['graph']);
      expect(hasUnplaced(upperLayout), isTrue);
      expect(hasUnplaced(lowerLayout), isFalse);
      expect(
        laneLabelsById(upper, upperLayout)['s'],
        isNot(laneLabelsById(lower, lowerLayout)['s']),
      );
    });

    test('L4-4 「畫面」列恆在最上且僅一列', () {
      final flow = project['UC-02']!;
      final layout = layoutWith(flow, projectBundleOrder);
      expect(layout.lanes.first, isA<ScreenLane>());
      expect(layout.lanes.whereType<ScreenLane>(), hasLength(1));
      final other = layoutWith(buildFlow([stepRow('s')]), orderOf(['a', 'b']));
      expect(other.lanes.first, isA<ScreenLane>());
      expect(other.lanes.whereType<ScreenLane>(), hasLength(1));
    });
  });

  group('L7 traverses 異常的步驟與「未定位」列', () {
    test('L7-1 守衛：值未宣告的步驟只在「未定位」列一個節點', () {
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['nope']),
        ],
        declaredDomains: ['graph'],
      );
      final layout = layoutWith(flow, orderOf(['graph']));
      expect(laneLabelsById(flow, layout)['S'], ['未定位']);
      expect(layout.nodes, hasLength(1));
      expect(layout.lanes.last, isA<UnplacedLane>());
      expectStepsConserved(flow, layout);
    });

    test('L7-2 E1 缺鍵對 []：S1 在未定位列、S2 在畫面列，所在列不同', () {
      final flow = buildFlow([
        stepRow('S1', traverses: traversesAbsent),
        stepRow('S2'),
      ]);
      final layout = layoutWith(flow, orderOf(['graph']));
      final byId = laneLabelsById(flow, layout);
      expect(byId['S1'], ['未定位']);
      expect(byId['S2'], ['畫面']);
      expect(byId['S1'], isNot(byId['S2']));
      expectStepsConserved(flow, layout);
    });

    test('L7-3 部分已宣告：只在 graph 列一個節點、無未定位列', () {
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['graph', 'nope']),
        ],
        declaredDomains: ['graph'],
      );
      final layout = layoutWith(flow, orderOf(['graph']));
      expect(laneLabelsById(flow, layout)['S'], ['graph']);
      expect(layout.nodes, hasLength(1));
      expect(hasUnplaced(layout), isFalse);
      expectStepsConserved(flow, layout);
    });

    test('L7-4 E1 列只在有異常步驟時出現：N+1 對 N+2，除未定位外逐值相同', () {
      final order = orderOf(['a', 'b', 'c']);
      final ucA = buildFlow(
        [
          stepRow('x', traverses: ['a']),
          stepRow('y', traverses: ['b', 'c']),
        ],
        declaredDomains: ['a', 'b', 'c'],
      );
      final ucB = buildFlow(
        [
          stepRow('x', traverses: ['a']),
          stepRow('y', traverses: traversesAbsent),
        ],
        declaredDomains: ['a', 'b', 'c'],
      );
      final lanesA = labels(layoutWith(ucA, order));
      final lanesB = labels(layoutWith(ucB, order));
      expect(lanesA, hasLength(order.length + 1));
      expect(lanesB, hasLength(order.length + 2));
      expect(lanesB.where((l) => l != '未定位').toList(), lanesA);
    });

    test('L7-5 成環 bundle 與未定位步驟並存：未定位恆為最末列', () {
      const order = <BundleOrderEntry>[
        (domain: 'a', layer: 0),
        (domain: 'b', layer: 1),
        (domain: 'x', layer: null),
        (domain: 'y', layer: null),
      ];
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['nope']),
        ],
        declaredDomains: ['a', 'b', 'x', 'y'],
      );
      expect(labels(layoutWith(flow, order)), [
        '畫面',
        'a',
        'b',
        'x',
        'y',
        '未定位',
      ]);
    });

    test('L7-6 E1 欄號依清單順序不接在最後；懸空步驟接在最後，兩類規則不同', () {
      final anomaly = buildFlow([
        stepRow('a'),
        stepRow('u', traverses: traversesAbsent),
        stepRow('b'),
      ]);
      final dangling = buildFlow([
        stepRow('a'),
        stepRow('d', branchFrom: 'ghost'),
        stepRow('b'),
      ]);
      final anomalyColumns = columnsById(anomaly, layoutWith(anomaly, []));
      final danglingColumns = columnsById(dangling, layoutWith(dangling, []));
      expect(anomalyColumns, {'a': 0, 'u': 1, 'b': 2});
      expect(danglingColumns, {'a': 0, 'b': 1, 'd': 2});
      expect(anomalyColumns['u'], isNot(danglingColumns['d']));
    });

    test('L7-7 重複宣告的 domain 視同未宣告：節點層級與列層級皆落未定位', () {
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['corpus']),
        ],
        declaredDomains: ['corpus', 'corpus'],
      );
      final layout = layoutWith(flow, orderOf(['corpus', 'corpus']));
      expect(laneLabelsById(flow, layout)['S'], ['未定位']);
      expect(labels(layout), ['畫面', 'corpus', 'corpus', '未定位']);
      expect(layout.nodes.where((n) => n.lane is BundleLane), isEmpty);
      // 列層級也取解析結果：重複宣告時 assembleSwimLanes 同樣出「未定位」列。
      final lanes = assembleSwimLanes(
        bundleOrder: orderOf(['corpus', 'corpus']),
        stepResolutions: [flow.steps.single.traversesResolution],
      );
      expect(lanes.last, isA<UnplacedLane>());
      // 對照：單一宣告時同一步驟落 corpus 列、無未定位列。
      final single = buildFlow(
        [
          stepRow('S', traverses: ['corpus']),
        ],
        declaredDomains: ['corpus'],
      );
      final singleLayout = layoutWith(single, orderOf(['corpus']));
      expect(laneLabelsById(single, singleLayout)['S'], ['corpus']);
      expect(hasUnplaced(singleLayout), isFalse);
      expectStepsConserved(flow, layout);
    });

    test('L7-8 flutter_balance UC-01：九節點全在未定位列，欄號 0～8', () {
      final flow = balance['UC-01']!;
      final layout = layoutWith(flow, balanceOrder);
      expect(labels(layout), ['畫面', 'balance-sheet', '未定位']);
      expect(layout.nodes, hasLength(9));
      expect(layout.nodes.every((n) => n.lane is UnplacedLane), isTrue);
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
      final shapes = layout.edges.map((e) => e.shape);
      expect(shapes.where((s) => s == EdgeShape.arc), hasLength(4));
      expect(shapes.where((s) => s == EdgeShape.straight), hasLength(8));
    });

    test('L7-10 不變式違反（解析名稱不在 FR-13 列內）：程式錯誤，assert', () {
      // release 路徑的落點（退落未定位列）不屬測試契約。
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['ghost']),
        ],
        declaredDomains: ['ghost'],
      );
      expect(
        () => layoutWith(flow, orderOf(['graph'])),
        throwsA(isA<AssertionError>()),
      );
    });

    test('L7-9 步驟總數守恆：異常步驟不消失', () {
      final inputs = <FlowSubgraph>[
        buildFlow([
          stepRow('S', traverses: ['nope']),
        ]),
        buildFlow([stepRow('S1', traverses: traversesAbsent), stepRow('S2')]),
        buildFlow(
          [
            stepRow('S', traverses: ['graph', 'nope']),
          ],
          declaredDomains: ['graph'],
        ),
        buildFlow(
          [
            stepRow('S', traverses: ['corpus']),
          ],
          declaredDomains: ['corpus', 'corpus'],
        ),
        balance['UC-01']!,
      ];
      for (final flow in inputs) {
        expectStepsConserved(
          flow,
          layoutWith(flow, orderOf(['graph', 'corpus', 'balance-sheet'])),
        );
      }
    });
  });
}
