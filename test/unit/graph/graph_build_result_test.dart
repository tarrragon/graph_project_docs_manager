import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

RawNode _bundle(String id, String domain) => buildRawNode(
  id: id,
  typeName: domainBundleTypeName,
  extra: {domainBundleDomainField: domain},
);

RawNode _ucNode(List<Map<String, dynamic>> steps) => RawNode(
  path: 'docs/usecases/UC-01.md',
  frontmatter: {'id': 'UC-01'},
  typeName: flowSourceTypeName,
  flowSteps: steps,
);

Map<String, dynamic> _step(
  String id, {
  List<Object?> traverses = const [],
  String? branchFrom,
}) => {'id': id, 'traverses': traverses, 'branch_from': ?branchFrom};

/// flow 四子類各一的 UC。
RawNode _flowFourSubclassUc() => _ucNode([
  _step('a'),
  _step('b', branchFrom: 'ghost'),
  _step('x'),
  _step('x'),
  _step('c', traverses: ['nope']),
  {'id': 'd'},
]);

/// 無任何主圖缺陷。
List<RawNode> _cleanMainGraph() => [
  buildRawNode(
    id: '0.1.0-W1-001',
    extra: {
      'relatedTo': ['0.1.0-W1-002'],
    },
  ),
  buildRawNode(id: '0.1.0-W1-002'),
];

/// 主圖四類各一：斷邊、格式錯誤、duplicateId、multiSource。
List<RawNode> _mainGraphFourDefects() => [
  buildRawNode(id: '0.1.0-W1-001', extra: {'source_ticket': '0.1.0-W9-999'}),
  buildRawNode(
    id: '0.1.0-W1-002',
    extra: {
      'relatedTo': [42],
    },
  ),
  buildRawNode(id: '0.1.0-W1-005', path: 'docs/dup-a.md'),
  buildRawNode(id: '0.1.0-W1-005', path: 'docs/dup-b.md'),
  buildRawNode(id: '0.2.0-W1-001'),
  buildRawNode(id: '0.2.0-W1-004', extra: {'source_ticket': '0.2.0-W1-001'}),
  buildRawNode(
    id: '0.2.0-W1-005',
    extra: {
      'spawned_tickets': ['0.2.0-W1-004'],
    },
  ),
];

void main() {
  group('G6 建圖結果與事件（FR-06）', () {
    test('G6-1 分布已知 fixture：各計數項等於已知值，守恆式成立', () {
      final known = buildKnownGraphDistribution();
      final event = buildGraphEvent(known.rawNodes);
      expect(event.nodeCount, known.nodeCount);
      expect(event.duplicateIdCount, known.duplicateIdCount);
      expect(event.edgeCount, known.edgeCount);
      expect(event.edgesByType, known.edgesByType);
      final directed = event.directedShapeCounts;
      expect(
        directed[DirectedDeclarationShape.fromOnly],
        known.directedFromOnly,
      );
      expect(directed[DirectedDeclarationShape.toOnly], known.directedToOnly);
      expect(directed[DirectedDeclarationShape.both], known.directedBoth);
      expect(event.undirectedOneEndCount, known.undirectedOneEnd);
      expect(event.undirectedBothCount, known.undirectedBoth);
      expect(event.totalReferences, known.totalReferences);
      expect(event.resolvedCount, known.resolved);
      expect(event.danglingRefCount, known.dangling);
      expect(event.malformedRefCount, known.malformed);
      expect(event.multiSourceCount, known.multiSourceCount);
      expect(
        event.totalReferences,
        event.resolvedCount + event.danglingRefCount + event.malformedRefCount,
      );
    });

    test('G6-2 rawNodes 為空：建出空圖，計數全為 0，非錯誤', () {
      final event = buildGraphEvent(const []);
      expect(event.nodeCount, 0);
      expect(event.edgeCount, 0);
      expect(event.graphDefects, isEmpty);
    });

    test('G6-3 graphDefects 筆數 = 主圖四類 + flow 四子類', () {
      final event = buildGraphEvent([
        ..._mainGraphFourDefects(),
        _flowFourSubclassUc(),
      ]);
      expect(event.danglingRefCount, 1);
      expect(event.malformedRefCount, 1);
      expect(event.duplicateIdCount, 1);
      expect(event.multiSourceCount, 1);
      expect(
        event.graphDefects.whereType<FlowGraphDefect>().map((d) => d.kind),
        unorderedEquals(FlowDefectKind.values),
      );
      expect(event.graphDefects.length, 8);
    });

    test('FR-06 驗收（NC-4）：再加 domain 重複宣告，筆數 9', () {
      final withDup = buildGraphEvent([
        ..._mainGraphFourDefects(),
        _flowFourSubclassUc(),
        _bundle('B1', 'corpus'),
        _bundle('B2', 'corpus'),
      ]);
      expect(withDup.graphDefects.length, 9);
      expect(
        withDup.graphDefects.whereType<DomainDuplicateDeclarationGraphDefect>(),
        hasLength(1),
      );
    });

    test('G6-5 守衛：主圖無缺陷、一步 traverses 未宣告名稱 -> 恰 1 筆', () {
      final event = buildGraphEvent([
        ..._cleanMainGraph(),
        _ucNode([
          _step('a', traverses: ['nope']),
        ]),
      ]);
      final d = event.graphDefects.single as FlowGraphDefect;
      expect(d.kind, FlowDefectKind.traversesUndeclared);
    });

    test('G6-6 對照：未宣告改為已宣告名稱 -> 1 對 0，節點與邊數相同', () {
      final bad = buildGraphEvent([
        ..._cleanMainGraph(),
        _bundle('B1', 'corpus'),
        _ucNode([
          _step('a', traverses: ['nope']),
        ]),
      ]);
      final good = buildGraphEvent([
        ..._cleanMainGraph(),
        _bundle('B1', 'corpus'),
        _ucNode([
          _step('a', traverses: ['corpus']),
        ]),
      ]);
      expect(bad.graphDefects.length, 1);
      expect(good.graphDefects.length, 0);
      expect(bad.edgeCount, good.edgeCount);
      expect(bad.nodeCount, good.nodeCount);
    });

    test('G6-4 同一邊多次宣告：edgeCount 只計一次', () {
      final event = buildGraphEvent([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'source_ticket': '0.1.0-W1-002',
            'relatedTo': ['0.1.0-W1-002', '0.1.0-W1-002'],
          },
        ),
        buildRawNode(
          id: '0.1.0-W1-002',
          extra: {
            'spawned_tickets': ['0.1.0-W1-001', '0.1.0-W1-001'],
            'relatedTo': ['0.1.0-W1-001'],
          },
        ),
      ]);
      expect(event.edgesByType, {'spawn': 1, 'association': 1});
      expect(event.edgeCount, 2);
    });
  });
}
