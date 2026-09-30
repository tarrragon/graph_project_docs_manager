import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _child = '0.1.0-W1-001';
const _parentA = '0.1.0-W1-002';
const _parentB = '0.1.0-W1-003';

MultiSourceGraphDefect _multiSource(GraphBuiltEvent event) =>
    event.graphDefects.whereType<MultiSourceGraphDefect>().single;

void main() {
  group('G4 建邊來源與宣告來源（FR-04）', () {
    test('G4-1 只在父票 spawned_tickets：一條 spawn，宣告來源 {父}', () {
      final event = buildGraphEvent([
        buildRawNode(id: _child),
        buildRawNode(
          id: _parentA,
          extra: {
            'spawned_tickets': [_child],
          },
        ),
      ]);
      expect(edgeKeys(event), {'spawn|$_child|$_parentA|$_parentA'});
    });

    test('G4-2 父子兩側都宣告：一條邊，宣告來源 {子, 父}', () {
      final event = buildGraphEvent([
        buildRawNode(id: _child, extra: {'source_ticket': _parentA}),
        buildRawNode(
          id: _parentA,
          extra: {
            'spawned_tickets': [_child],
          },
        ),
      ]);
      expect(edgeKeys(event), {'spawn|$_child|$_parentA|$_child,$_parentA'});
    });

    test('G4-3 子票 source_ticket A 且父 B 列出子票：兩條邊與一筆 multiSource', () {
      final event = buildGraphEvent([
        buildRawNode(id: _child, extra: {'source_ticket': _parentA}),
        buildRawNode(id: _parentA),
        buildRawNode(
          id: _parentB,
          extra: {
            'spawned_tickets': [_child],
          },
        ),
      ]);
      expect(edgeKeys(event), {
        'spawn|$_child|$_parentA|$_child',
        'spawn|$_child|$_parentB|$_parentB',
      });
      final defect = _multiSource(event);
      expect(defect.from, _child);
      expect(defect.edgeType, 'spawn');
      expect(
        {
          for (final t in defect.targets)
            t.to: (t.declaredBy.toList()..sort()).join(','),
        },
        {_parentA: _child, _parentB: _parentB},
      );
    });

    test('G4-4 守衛：source_ticket 指向不存在的 X 只回報 danglingRef，不回報 multiSource', () {
      final rawNodes = [
        buildRawNode(id: _child, extra: {'source_ticket': '0.1.0-W9-999'}),
        buildRawNode(
          id: _parentB,
          extra: {
            'spawned_tickets': [_child],
          },
        ),
      ];
      final event = buildGraphEvent(rawNodes);
      expect(edgeKeys(event), {'spawn|$_child|$_parentB|$_parentB'});
      expect(event.danglingRefCount, 1);
      expect(event.multiSourceCount, 0);

      // 正向對照：X 存在時同結構會回報 multiSource（G4-3）。
      final control = buildGraphEvent([
        ...rawNodes,
        buildRawNode(id: '0.1.0-W9-999'),
      ]);
      expect(control.multiSourceCount, 1);
    });

    test(
      'G4-5 UC 兩個 source_proposal 且兩 PROP 皆列 UC：兩條 provenance 兩端，無 multiSource',
      () {
        final event = buildGraphEvent([
          buildRawNode(
            id: 'UC-01',
            typeName: 'UC',
            extra: {
              'source_proposal': ['PROP-003', 'PROP-002'],
            },
          ),
          for (final prop in ['PROP-002', 'PROP-003'])
            buildRawNode(
              id: prop,
              typeName: 'PROP',
              extra: {
                'outputs': {
                  'usecase_refs': ['UC-01'],
                },
              },
            ),
        ]);
        expect(edgeKeys(event), {
          'provenance|UC-01|PROP-002|PROP-002,UC-01',
          'provenance|UC-01|PROP-003|PROP-003,UC-01',
        });
        expect(event.multiSourceCount, 0);
      },
    );

    test(
      'G4-6 PROP outputs.spec_refs 與 SPEC source_proposal 互指：一條 provenance 兩端',
      () {
        final event = buildGraphEvent([
          buildRawNode(
            id: 'PROP-001',
            typeName: 'PROP',
            extra: {
              'outputs': {
                'spec_refs': ['SPEC-001'],
              },
            },
          ),
          buildRawNode(
            id: 'SPEC-001',
            typeName: 'SPEC',
            extra: {
              'source_proposal': ['PROP-001'],
            },
          ),
        ]);
        expect(edgeKeys(event), {
          'provenance|SPEC-001|PROP-001|PROP-001,SPEC-001',
        });
      },
    );

    test('G4-7 基數 one 的欄位寫成兩項清單：兩條邊與一筆 multiSource', () {
      final event = buildGraphEvent([
        buildRawNode(
          id: _child,
          extra: {
            'source_ticket': [_parentA, _parentB],
          },
        ),
        buildRawNode(id: _parentA),
        buildRawNode(id: _parentB),
      ]);
      expect(event.edgeCount, 2);
      expect(event.multiSourceCount, 1);
    });

    test('G4-8 E1 鑑別：同 fixture 基數改為 many 則無 multiSource', () {
      final rawNodes = [
        buildRawNode(
          id: _child,
          extra: {
            'source_ticket': [_parentA, _parentB],
          },
        ),
        buildRawNode(id: _parentA),
        buildRawNode(id: _parentB),
      ];
      final manySchema = loadBuiltinSchemaJson();
      final spawn =
          (manySchema['edge_types'] as Map<String, dynamic>)['spawn']
              as Map<String, dynamic>;
      spawn['forward_cardinality'] = 'many';

      final withOne = buildGraphEvent(rawNodes);
      final withMany = buildGraphEvent(rawNodes, manySchema);
      expect(withOne.multiSourceCount, 1);
      expect(withMany.multiSourceCount, 0);
      expect(edgeKeys(withMany), edgeKeys(withOne));
    });

    test('G4-9 reverse_field 為 null 的邊型：只依起點建邊，宣告來源 {起點}', () {
      final event = buildGraphEvent([
        buildRawNode(
          id: _child,
          extra: {
            'blockedBy': [_parentA],
          },
        ),
        buildRawNode(id: _parentA),
      ]);
      expect(edgeKeys(event), {'blocking|$_child|$_parentA|$_child'});
    });
  });
}
