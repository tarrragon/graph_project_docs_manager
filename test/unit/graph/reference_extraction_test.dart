import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

ReferenceClassification _run(
  List<RawNode> nodes, [
  Map<String, dynamic>? schema,
]) {
  final inputs = graphInputsFrom(schema);
  return classifyGraphReferences(
    rawNodes: nodes,
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
  );
}

Map<String, dynamic> _schemaWith(void Function(Map<String, dynamic> edges) f) {
  final json = loadBuiltinSchemaJson();
  f(json['edge_types'] as Map<String, dynamic>);
  return json;
}

Set<String> _edgeKeys(ReferenceClassification r) => {
  for (final x in r.resolved)
    '${x.ref.edgeTypeName}:${x.ref.sourceId}->${x.targetId}',
};

void main() {
  group('G2 引用值抽取（FR-03）', () {
    test('G2-1 缺席、null、空字串、空清單皆不產生引用值', () {
      final r = _run([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {'relatedTo': null, 'blockedBy': '', 'parent_id': <dynamic>[]},
        ),
        buildRawNode(id: '0.1.0-W1-002'),
      ]);
      expect(r.totalReferences, 0);
    });

    test('G2-2 清單內 null 不計、非字串為 invalidShape', () {
      final r = _run([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'blockedBy': ['0.1.0-W1-002', 42, null],
          },
        ),
        buildRawNode(id: '0.1.0-W1-002'),
      ]);
      expect(r.totalReferences, 2);
      expect(r.resolved, hasLength(1));
      expect(r.malformed.single.reason, MalformedReason.invalidShape);
    });

    test('G2-3 純量欄位為布林：一個 invalidShape', () {
      final r = _run([
        buildRawNode(id: '0.1.0-W1-001', extra: {'parent_id': true}),
      ]);
      expect(r.totalReferences, 1);
      expect(r.malformed.single.reason, MalformedReason.invalidShape);
    });

    test('G2-4 純量欄位為 map：一個 invalidShape', () {
      final r = _run([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'parent_id': {'a': 'b'},
          },
        ),
      ]);
      expect(r.totalReferences, 1);
      expect(r.malformed.single.reason, MalformedReason.invalidShape);
    });

    test('G2-5 outputs 子鍵為 provenance 反向引用值', () {
      final r = _run([
        buildRawNode(
          id: 'PROP-001',
          typeName: 'PROP',
          extra: {
            'outputs': {
              'design_refs': ['SPEC-001'],
            },
          },
        ),
        buildRawNode(id: 'SPEC-001', typeName: 'SPEC'),
      ]);
      final ref = r.resolved.single.ref;
      expect(ref.edgeTypeName, 'provenance');
      expect(ref.isReverse, isTrue);
      expect(r.resolved.single.targetId, 'SPEC-001');
    });

    test('G2-6 outputs 兩個子鍵各兩項：四個引用值', () {
      final r = _run([
        buildRawNode(
          id: 'PROP-001',
          typeName: 'PROP',
          extra: {
            'outputs': {
              'a_refs': ['SPEC-001', 'SPEC-002'],
              'new_key_refs': ['UC-01', 'UC-02'],
            },
          },
        ),
      ]);
      expect(r.totalReferences, 4);
    });

    test('G2-7 outputs 子鍵非清單：一個 invalidShape', () {
      final r = _run([
        buildRawNode(
          id: 'PROP-001',
          typeName: 'PROP',
          extra: {
            'outputs': {'notes': 'x'},
          },
        ),
      ]);
      expect(r.totalReferences, 1);
      expect(r.malformed.single.reason, MalformedReason.invalidShape);
    });

    test('G2-8 不檢查終點節點型別', () {
      final r = _run([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'blockedBy': ['SPEC-001'],
          },
        ),
        buildRawNode(id: 'SPEC-001', typeName: 'SPEC'),
      ]);
      expect(r.resolved, hasLength(1));
    });

    test('G2-9 新增 established 邊型自動被抽取；未加的表無此邊', () {
      final nodes = [
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'test_refs': ['0.1.0-W1-002'],
          },
        ),
        buildRawNode(id: '0.1.0-W1-002'),
      ];
      final withEdge = _run(
        nodes,
        _schemaWith((edges) {
          edges['testEdge'] = {
            'class': 'see-also',
            'forward_field': 'test_refs',
            'reverse_field': null,
            'layer': 'established',
            'forward_cardinality': 'many',
          };
        }),
      );
      final without = _run(nodes);
      expect(_edgeKeys(withEdge), {'testEdge:0.1.0-W1-001->0.1.0-W1-002'});
      expect(_edgeKeys(without), isEmpty);
    });

    test('G2-10 forward_field 改名後只讀新欄位', () {
      final nodes = [
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'blockedBy': ['0.1.0-W1-002'],
            'blocks_x': ['0.1.0-W1-003'],
          },
        ),
        buildRawNode(id: '0.1.0-W1-002'),
        buildRawNode(id: '0.1.0-W1-003'),
      ];
      final renamed = _run(
        nodes,
        _schemaWith((edges) {
          (edges['blocking'] as Map<String, dynamic>)['forward_field'] =
              'blocks_x';
        }),
      );
      expect(_edgeKeys(renamed), {'blocking:0.1.0-W1-001->0.1.0-W1-003'});
      expect(_edgeKeys(_run(nodes)), {'blocking:0.1.0-W1-001->0.1.0-W1-002'});
    });
  });
}
