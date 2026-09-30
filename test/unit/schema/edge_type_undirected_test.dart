import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

const _builtinPath = 'assets/schema/builtin_tracking_schema.json';

/// 需求：[SPEC-007 FR-05、D6] `resolveEdgeTypes` 依鍵名填 `isUndirected`。
void main() {
  group('EdgeTypeEntry.isUndirected（SPEC-007 D6 鍵名例外集中於 Schema）', () {
    final builtin = jsonDecode(
      File(_builtinPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final edges = resolveEdgeTypes(
      projectSchemaJson: builtin,
      builtinSchemaJson: builtin,
    ).edgeTypes;

    test('association 為無向', () {
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

    test('無向邊型集合恰為 {association}', () {
      final undirected = {
        for (final e in edges.values)
          if (e.isUndirected) e.name,
      };
      expect(undirected, {'association'});
    });
  });
}
