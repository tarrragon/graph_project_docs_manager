import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';

const _builtinPath = 'assets/schema/builtin_tracking_schema.json';
const _expectedSeeAlso = {
  'association',
  'spec_association',
  'uc_association',
  'proposal_association',
};

/// Graph 認定為無向的邊型集合（目前為單一鍵名例外）。
Set<String> _graphUndirectedNames() => {undirectedEdgeName};

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

/// 契約：see-also 集合恰為四種，且其中只有 Graph 認定的無向邊型是 association。
void _expectContract(Map<String, dynamic> table) {
  expect(_seeAlsoEstablished(table).keys.toSet(), _expectedSeeAlso);
  expect(_graphUndirectedNames(), {'association'});
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
    final builtin =
        jsonDecode(File(_builtinPath).readAsStringSync())
            as Map<String, dynamic>;

    test('established see-also 邊型集合恰為四種', () {
      expect(_seeAlsoEstablished(builtin).keys.toSet(), _expectedSeeAlso);
    });

    test('association 的 forward_field 為 relatedTo、reverse_field 為 null', () {
      final association = _seeAlsoEstablished(builtin)['association']!;
      expect(association.forwardField, 'relatedTo');
      expect(association.reverseField, isNull);
    });

    test('Graph 認定為無向的邊型集合恰為 {association}', () {
      expect(_graphUndirectedNames(), {'association'});
    });

    test('內建表滿足契約', () {
      _expectContract(builtin);
    });

    test('正向對照：多一個 established see-also 邊型時契約斷言翻紅', () {
      expect(
        () => _expectContract(_tableWithExtraSeeAlso()),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
