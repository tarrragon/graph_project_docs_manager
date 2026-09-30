import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _builtinPath = 'assets/schema/builtin_tracking_schema.json';
const _expectedSeeAlso = {
  'association',
  'spec_association',
  'uc_association',
  'proposal_association',
};

/// 建圖結果中 isUndirected 為真的邊型集合（驗 Graph 建圖行為，非常數）。
Set<String> _undirectedTypesOf(GraphBuiltEvent event) => {
  for (final e in event.edges)
    if (e.isUndirected) e.edgeType,
};

/// 語料：四種 see-also 邊型各建出一條邊。
GraphBuiltEvent _buildSeeAlsoGraph() => buildGraphEvent([
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
]);

/// 型別表 JSON 中 established 且 class 為 see-also 的邊型。
Map<String, EdgeTypeEntry> _seeAlsoEstablished(Map<String, dynamic> json) {
  final resolution = resolveEdgeTypes(
    projectSchemaJson: json,
    builtinSchemaJson: json,
  );
  return {
    for (final e in resolution.edgeTypes.values)
      if (e.layer == 'established' && e.edgeClass == 'see-also') e.name: e,
  };
}

/// 契約：see-also 集合恰為四種，且建圖結果中只有 association 邊為無向。
void _expectContract(Map<String, dynamic> table, GraphBuiltEvent event) {
  expect(_seeAlsoEstablished(table).keys.toSet(), _expectedSeeAlso);
  expect(event.edges.map((e) => e.edgeType).toSet(), _expectedSeeAlso);
  expect(_undirectedTypesOf(event), {'association'});
}

/// 正向對照輸入：spec_association 邊被標為無向的建圖結果。
GraphBuiltEvent _eventWithUndirectedSpecAssociation() {
  final good = _buildSeeAlsoGraph();
  return GraphBuiltEvent(
    nodes: good.nodes,
    edges: [
      for (final e in good.edges)
        GraphEdge(
          edgeType: e.edgeType,
          from: e.from,
          to: e.to,
          declaredBy: e.declaredBy,
          isUndirected: e.isUndirected || e.edgeType == 'spec_association',
        ),
    ],
    graphDefects: good.graphDefects,
    totalReferences: good.totalReferences,
    resolvedCount: good.resolvedCount,
  );
}

Map<String, dynamic> _tableWithExtraSeeAlso() => buildEdgeTableJson(
  version: '1.0.0',
  edges: {
    'association': const EdgeSpec(forwardField: 'relatedTo'),
    'spec_association': const EdgeSpec(forwardField: 'spec_refs'),
    'uc_association': const EdgeSpec(forwardField: 'uc_refs'),
    'proposal_association': const EdgeSpec(forwardField: 'prop_refs'),
    'extra_see_also': const EdgeSpec(forwardField: 'extra_refs'),
  },
);

void main() {
  group('S6-13 無向邊鍵名例外契約（SPEC-007 FR-05、D6）', () {
    final builtin = jsonDecode(
      File(_builtinPath).readAsStringSync(),
    ) as Map<String, dynamic>;

    test('established see-also 邊型集合恰為四種', () {
      expect(_seeAlsoEstablished(builtin).keys.toSet(), _expectedSeeAlso);
    });

    test('association 的 forward_field 為 relatedTo、reverse_field 為 null', () {
      final association = _seeAlsoEstablished(builtin)['association']!;
      expect(association.forwardField, 'relatedTo');
      expect(association.reverseField, isNull);
    });

    test('建圖結果中無向邊的邊型集合恰為 {association}，四種邊型皆出現', () {
      final event = _buildSeeAlsoGraph();
      expect(event.edges.map((e) => e.edgeType).toSet(), _expectedSeeAlso);
      expect(_undirectedTypesOf(event), {'association'});
    });

    test('內建表滿足契約', () {
      _expectContract(builtin, _buildSeeAlsoGraph());
    });

    test('正向對照：多一個 established see-also 邊型時契約斷言翻紅', () {
      expect(
        () => _expectContract(_tableWithExtraSeeAlso(), _buildSeeAlsoGraph()),
        throwsA(isA<TestFailure>()),
      );
    });

    test('正向對照：spec_association 被標為無向的建圖結果使契約斷言翻紅', () {
      expect(
        () => _expectContract(builtin, _eventWithUndirectedSpecAssociation()),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
