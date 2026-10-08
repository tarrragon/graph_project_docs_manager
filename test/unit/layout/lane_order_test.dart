// SPEC-001 §1〈泳道布局規則〉列集合與列序；測試設計 §3.1 L1-4、L2-5、L2-6、L8。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';

import '../../helpers/spec001/bundle_graph_builder.dart';

/// 以字面值表示列：'畫面'、domain 名、'未定位'。
List<String> labelsOf(List<SwimLane> lanes) => [
  for (final lane in lanes)
    switch (lane) {
      ScreenLane() => '畫面',
      BundleLane(:final domain) => domain,
      UnplacedLane() => '未定位',
    },
];

const projectOrder = <BundleOrderEntry>[
  (domain: 'schema', layer: 0),
  (domain: 'workspace', layer: 0),
  (domain: 'corpus', layer: 1),
  (domain: 'history', layer: 1),
  (domain: 'diagnostics', layer: 2),
  (domain: 'graph', layer: 2),
  (domain: 'ticketdetail', layer: 2),
  (domain: 'layout', layer: 3),
];

const projectLabels = [
  '畫面',
  'schema',
  'workspace',
  'corpus',
  'history',
  'diagnostics',
  'graph',
  'ticketdetail',
  'layout',
];

void main() {
  group('層推導', () {
    test('L1-4 單一 bundle 無邊：無異常步驟 2 列、有缺鍵步驟 3 列', () {
      final edges = buildBundleDependencyEdges({'app': []});
      expect(edges, isEmpty);
      const order = <BundleOrderEntry>[(domain: 'app', layer: 0)];
      final normal = assembleSwimLanes(
        bundleOrder: order,
        stepTraverses: const [
          ['app'],
          [],
        ],
      );
      final missingKey = assembleSwimLanes(
        bundleOrder: order,
        stepTraverses: const [
          ['app'],
          null,
        ],
      );
      expect(labelsOf(normal), ['畫面', 'app']);
      expect(labelsOf(missingKey), ['畫面', 'app', '未定位']);
    });
  });

  group('同層排序與結構異常', () {
    test('L2-5 不產生 ghost 列、指向 ghost 的邊不畫、X 其餘依賴邊照畫', () {
      final edges = buildBundleDependencyEdges({
        'a': [],
        'x': ['a', 'ghost'],
      });
      const order = <BundleOrderEntry>[
        (domain: 'a', layer: 0),
        (domain: 'x', layer: null),
      ];
      final lanes = assembleSwimLanes(
        bundleOrder: order,
        stepTraverses: const [
          ['x'],
        ],
      );
      expect(labelsOf(lanes), ['畫面', 'a', 'x']);
      // 正向對照：輸入確實含指向 ghost 的邊。
      expect(edges, contains((from: 'x', to: 'ghost')));
      expect(drawableDependencyEdges(lanes: lanes, edges: edges), [
        (from: 'x', to: 'a'),
      ]);
    });

    test('L2-6 同一 FR-13 清單、六個不同 UC，列序逐值相同', () {
      const ucSteps = <List<List<String>?>>[
        [
          [],
          ['graph'],
          ['graph', 'ticketdetail'],
        ],
        [
          ['corpus'],
        ],
        [],
        [
          ['layout'],
          [],
        ],
        [
          ['schema', 'workspace'],
        ],
        [
          ['history'],
          ['diagnostics'],
        ],
      ];
      final results = [
        for (final steps in ucSteps)
          labelsOf(
            assembleSwimLanes(bundleOrder: projectOrder, stepTraverses: steps),
          ),
      ];
      expect(results, hasLength(6));
      for (final labels in results) {
        expect(labels, projectLabels);
      }
    });
  });

  group('列序來源（L8）', () {
    test('L8-1 本專案快照排序 → 9 列', () {
      final lanes = assembleSwimLanes(
        bundleOrder: projectOrder,
        stepTraverses: const [
          ['graph'],
        ],
      );
      expect(labelsOf(lanes), projectLabels);
      expect(lanes, hasLength(9));
    });

    test('L8-2 Layout 照單使用 FR-13 清單，不自行推導', () {
      const altered = <BundleOrderEntry>[
        (domain: 'layout', layer: 3),
        (domain: 'schema', layer: 0),
        (domain: 'workspace', layer: 0),
        (domain: 'corpus', layer: 1),
        (domain: 'history', layer: 1),
        (domain: 'diagnostics', layer: 2),
        (domain: 'graph', layer: 2),
        (domain: 'ticketdetail', layer: 2),
      ];
      final lanes = assembleSwimLanes(
        bundleOrder: altered,
        stepTraverses: const [
          ['graph'],
        ],
      );
      expect(labelsOf(lanes), [
        '畫面',
        'layout',
        'schema',
        'workspace',
        'corpus',
        'history',
        'diagnostics',
        'graph',
        'ticketdetail',
      ]);
      expect(labelsOf(lanes), isNot(projectLabels));
    });

    test('L8-3 有缺鍵步驟：畫面、FR-13 排序、未定位', () {
      final lanes = assembleSwimLanes(
        bundleOrder: projectOrder,
        stepTraverses: const [
          ['graph'],
          null,
        ],
      );
      expect(labelsOf(lanes), [...projectLabels, '未定位']);
    });

    test('L8-4 層號 null 的 X、Y 照原樣放排序段末、未定位之前', () {
      const tail = <BundleOrderEntry>[
        (domain: 'a', layer: 0),
        (domain: 'x', layer: null),
        (domain: 'y', layer: null),
      ];
      const head = <BundleOrderEntry>[
        (domain: 'x', layer: null),
        (domain: 'y', layer: null),
        (domain: 'a', layer: 0),
      ];
      const steps = <List<String>?>[
        ['unknown'],
      ];
      final tailLanes = assembleSwimLanes(
        bundleOrder: tail,
        stepTraverses: steps,
      );
      final headLanes = assembleSwimLanes(
        bundleOrder: head,
        stepTraverses: steps,
      );
      expect(labelsOf(tailLanes), ['畫面', 'a', 'x', 'y', '未定位']);
      expect(labelsOf(headLanes), ['畫面', 'x', 'y', 'a', '未定位']);
    });
  });
}
