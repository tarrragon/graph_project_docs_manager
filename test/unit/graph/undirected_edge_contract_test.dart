import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _seeAlsoTypes = {
  'association',
  'spec_association',
  'uc_association',
  'proposal_association',
};

Map<String, dynamic> _edgeEntry(Map<String, dynamic> table, String name) =>
    (table['edge_types'] as Map<String, dynamic>)[name] as Map<String, dynamic>;

/// 內建表副本，指定邊型的 `direction` 改為 [direction]。
Map<String, dynamic> _builtinWith(String name, String direction) {
  final table = loadBuiltinSchemaJson();
  _edgeEntry(table, name)['direction'] = direction;
  return table;
}

Set<String> _undirectedTypesOf(GraphBuiltEvent event) => {
  for (final e in event.edges)
    if (e.isUndirected) e.edgeType,
};

/// 語料：四種 see-also 邊型各建出一條邊。
GraphBuiltEvent _buildSeeAlsoGraph([Map<String, dynamic>? schema]) =>
    buildGraphEvent([
      buildRawNode(
        id: 'SPEC-001',
        typeName: 'SPEC',
        extra: {
          'relatedTo': ['SPEC-002'],
          'related_specs': ['SPEC-003'],
          'related_usecases': ['UC-01'],
          'related_proposals': ['PROP-001'],
        },
      ),
      buildRawNode(id: 'SPEC-002', typeName: 'SPEC'),
      buildRawNode(id: 'SPEC-003', typeName: 'SPEC'),
      buildRawNode(id: 'UC-01', typeName: 'UC'),
      buildRawNode(id: 'PROP-001', typeName: 'PROP'),
    ], schema);

/// fixture：A 的 [field] 列出 B，B 未列 A。
List<RawNode> _fixture(String field) => [
  buildRawNode(
    id: 'SPEC-001',
    typeName: 'SPEC',
    extra: {
      field: ['SPEC-002'],
    },
  ),
  buildRawNode(id: 'SPEC-002', typeName: 'SPEC'),
];

AdjacencyQuery _queryOf(List<RawNode> nodes, Map<String, dynamic> project) =>
    AdjacencyQuery(
      buildResult: buildGraph(
        rawNodes: nodes,
        projectSchemaJson: project,
        builtinSchemaJson: loadBuiltinSchemaJson(),
      ),
    );

List<AdjacencyEntry> _entries(AdjacencyQuery q, String id) =>
    (q.query(id) as AdjacencyAvailable).entries;

void main() {
  group('S6-13 無向判定讀 direction 欄（SPEC-007 FR-05、D6）', () {
    final builtin = loadBuiltinSchemaJson();

    test('asset 中 direction 為 undirected 的集合等於 Graph 認定的無向集合', () {
      final assetUndirected = {
        for (final e in (builtin['edge_types'] as Map<String, dynamic>).entries)
          if ((e.value as Map)['direction'] == 'undirected') e.key,
      };
      final event = _buildSeeAlsoGraph();
      expect(event.edges.map((e) => e.edgeType).toSet(), _seeAlsoTypes);
      expect(_undirectedTypesOf(event), assetUndirected);
      expect(assetUndirected, {'association'});
    });

    test('三種 see-also 邊型 direction 為 directed，association 欄位形狀不變', () {
      for (final name in const [
        'spec_association',
        'uc_association',
        'proposal_association',
      ]) {
        expect(
          _edgeEntry(builtin, name)['direction'],
          'directed',
          reason: name,
        );
      }
      expect(_edgeEntry(builtin, 'association')['forward_field'], 'relatedTo');
      expect(_edgeEntry(builtin, 'association')['reverse_field'], isNull);
    });

    test('association：A 列出 B，A、B 鄰接均含對方且標無向', () {
      final q = _queryOf(_fixture('relatedTo'), builtin);
      for (final (id, other) in [
        ('SPEC-001', 'SPEC-002'),
        ('SPEC-002', 'SPEC-001'),
      ]) {
        final entries = _entries(q, id);
        expect(entries.single.otherId, other);
        expect(entries.single.direction, AdjacencyEntryDirection.undirected);
      }
    });

    test('正向對照：spec_association 改 undirected 即做對稱聯集', () {
      final event = _buildSeeAlsoGraph(
        _builtinWith('spec_association', 'undirected'),
      );
      expect(_undirectedTypesOf(event), {'association', 'spec_association'});
      final q = _queryOf(
        _fixture('related_specs'),
        _builtinWith('spec_association', 'undirected'),
      );
      expect(
        _entries(q, 'SPEC-002').single.direction,
        AdjacencyEntryDirection.undirected,
      );
    });

    test('E1：僅 association 改 directed，建出有向 A→B，B 查得入，與改前不同', () {
      final before = _queryOf(_fixture('relatedTo'), builtin);
      final after = _queryOf(
        _fixture('relatedTo'),
        _builtinWith('association', 'directed'),
      );
      expect(
        _entries(before, 'SPEC-002').single.direction,
        AdjacencyEntryDirection.undirected,
      );
      expect(
        _entries(after, 'SPEC-002').single.direction,
        AdjacencyEntryDirection.incoming,
      );
      expect(
        _entries(after, 'SPEC-001').single.direction,
        AdjacencyEntryDirection.out,
      );
      final event = _buildSeeAlsoGraph(_builtinWith('association', 'directed'));
      expect(_undirectedTypesOf(event), isEmpty);
    });
  });

  group('S6-14 專案表缺 direction，鄰接部分（SPEC-007 FR-01）', () {
    test('association 仍為無向，A、B 鄰接均含對方（缺欄不得當 directed）', () {
      final q = _queryOf(
        _fixture('relatedTo'),
        loadBuiltinSchemaJsonWithoutDirection(),
      );
      for (final id in ['SPEC-001', 'SPEC-002']) {
        expect(
          _entries(q, id).single.direction,
          AdjacencyEntryDirection.undirected,
          reason: id,
        );
      }
    });
  });
}
