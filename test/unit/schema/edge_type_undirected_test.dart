import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';

Map<String, dynamic> _builtin() => loadBuiltinSchemaJson();

Map<String, dynamic> _builtinWithoutDirection() =>
    loadBuiltinSchemaJsonWithoutDirection();

Map<String, EdgeTypeEntry> _resolve(Map<String, dynamic> project) =>
    resolveEdgeTypes(
      projectSchemaJson: project,
      builtinSchemaJson: _builtin(),
    ).edgeTypes;

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

    test('被拒收後由內建表補回：整筆採內建宣告，專案原寫的 direction 被忽略', () {
      final table = _builtin();
      final edges = table['edge_types'] as Map<String, dynamic>;
      // 專案表的 association 缺 forward_field 而被拒收，且寫了相反的 direction。
      (edges['association'] as Map<String, dynamic>)
        ..remove('forward_field')
        ..['direction'] = 'directed';
      final resolved = _resolve(table);
      expect(resolved['association']!.direction, EdgeDirection.undirected);
      expect(
        resolved['association']!.directionSource,
        DirectionSource.builtinTable,
      );
      // E1：同表未被拒收的邊型，來源為專案表。
      expect(
        resolved['spec_association']!.directionSource,
        DirectionSource.projectTable,
      );
    });

    test('E1：association 未被拒收且寫 directed 時，採專案值與專案來源', () {
      final table = _builtin();
      final edges = table['edge_types'] as Map<String, dynamic>;
      (edges['association'] as Map<String, dynamic>)['direction'] = 'directed';
      final resolved = _resolve(table)['association']!;
      expect(resolved.direction, EdgeDirection.directed);
      expect(resolved.directionSource, DirectionSource.projectTable);
    });

    test('direction 值不是 directed／undirected 時視同缺欄，補內建表值', () {
      final table = _builtin();
      final edges = table['edge_types'] as Map<String, dynamic>;
      (edges['association'] as Map<String, dynamic>)['direction'] = 'sideways';
      (edges['spec_association'] as Map<String, dynamic>)['direction'] = 7;
      final resolved = _resolve(table);
      expect(resolved['association']!.direction, EdgeDirection.undirected);
      expect(
        resolved['association']!.directionSource,
        DirectionSource.builtinTable,
      );
      expect(resolved['spec_association']!.direction, EdgeDirection.directed);
      expect(
        resolved['spec_association']!.directionSource,
        DirectionSource.builtinTable,
      );
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
