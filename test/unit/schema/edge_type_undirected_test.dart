import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';

const _builtinPath = 'assets/schema/builtin_tracking_schema.json';

Map<String, dynamic> _builtin() =>
    jsonDecode(File(_builtinPath).readAsStringSync()) as Map<String, dynamic>;

Map<String, EdgeTypeEntry> _resolve(Map<String, dynamic> project) =>
    resolveEdgeTypes(
      projectSchemaJson: project,
      builtinSchemaJson: _builtin(),
    ).edgeTypes;

/// 內建表移除全部邊型的 `direction` 欄（S6-14 的專案表）。
Map<String, dynamic> _builtinWithoutDirection() {
  final table = _builtin();
  for (final edge in (table['edge_types'] as Map<String, dynamic>).values) {
    (edge as Map<String, dynamic>).remove('direction');
  }
  return table;
}

/// 需求：[SPEC-007 FR-01、FR-05、D6] 方向性取自 `direction` 欄。
void main() {
  group('EdgeTypeEntry.direction（SPEC-007 FR-05，無鍵名例外）', () {
    final edges = _resolve(_builtin());

    test('association 為無向，direction 取自欄位', () {
      expect(edges['association']!.direction, EdgeDirection.undirected);
      expect(edges['association']!.isUndirected, isTrue);
    });

    test('其餘 see-also 邊型與 blocking 為有向', () {
      for (final name in const [
        'spec_association',
        'uc_association',
        'proposal_association',
        'blocking',
      ]) {
        expect(edges[name]!.isUndirected, isFalse, reason: name);
      }
    });

    test('無向邊型集合等於內建表 direction 為 undirected 的集合', () {
      final raw = _builtin()['edge_types'] as Map<String, dynamic>;
      final expected = {
        for (final e in raw.entries)
          if ((e.value as Map)['direction'] == 'undirected') e.key,
      };
      final actual = {
        for (final e in edges.values)
          if (e.isUndirected) e.name,
      };
      expect(actual, expected);
      expect(actual, isNotEmpty);
    });

    test('E1：宣告決定方向，與鍵名無關', () {
      final table = buildEdgeTableJson(
        version: '1.0.0',
        edges: {
          'association': const EdgeSpec(
            forwardField: 'relatedTo',
            direction: 'directed',
          ),
          'spec_association': const EdgeSpec(
            forwardField: 'spec_refs',
            direction: 'undirected',
          ),
        },
      );
      final resolved = _resolve(table);
      expect(resolved['association']!.isUndirected, isFalse);
      expect(resolved['spec_association']!.isUndirected, isTrue);
    });
  });

  group('direction 缺欄補值與來源（FR-01，S6-14、S6-15 schema 部分）', () {
    test('S6-14：缺欄補內建表值，來源為內建表；帶欄原表來源為專案表', () {
      final filled = _resolve(_builtinWithoutDirection())['association']!;
      final original = _resolve(_builtin())['association']!;
      expect(filled.direction, EdgeDirection.undirected);
      expect(filled.directionSource, DirectionSource.builtinTable);
      expect(original.direction, filled.direction);
      expect(original.directionSource, DirectionSource.projectTable);
      expect(filled.directionSource, isNot(original.directionSource));
    });

    test('S6-15：內建表沒有的邊型缺欄為有向，來源為預設（有向）', () {
      final table = _builtinWithoutDirection();
      (table['edge_types'] as Map<String, dynamic>)['testEdge'] =
          const EdgeSpec(forwardField: 'test_refs').toJson();
      final resolved = _resolve(table);
      expect(resolved['testEdge']!.direction, EdgeDirection.directed);
      expect(
        resolved['testEdge']!.directionSource,
        DirectionSource.defaultDirected,
      );
      expect(
        resolved['association']!.directionSource,
        DirectionSource.builtinTable,
      );
      expect(
        resolved['testEdge']!.directionSource,
        isNot(resolved['association']!.directionSource),
      );
    });
  });
}
