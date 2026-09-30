import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _child = '0.1.0-W1-002';
const _parent = '0.1.0-W1-001';
const _other = '0.1.0-W1-003';

AdjacencyQuery _queryOf(List<RawNode> rawNodes) => AdjacencyQuery(
  buildResult: buildGraph(
    rawNodes: rawNodes,
    projectSchemaJson: loadBuiltinSchemaJson(),
    builtinSchemaJson: loadBuiltinSchemaJson(),
  ),
);

List<AdjacencyEntry> _entries(AdjacencyResult result) =>
    (result as AdjacencyAvailable).entries;

void main() {
  group('G7 鄰接查詢', () {
    test('G7-1 source_ticket：查子（出）得父，查父（入）得子，項目帶完整欄位', () {
      final q = _queryOf([
        buildRawNode(id: _parent),
        buildRawNode(id: _child, extra: {'source_ticket': _parent}),
      ]);
      final out = _entries(q.query(_child, direction: AdjacencyDirection.out));
      expect(out, hasLength(1));
      expect(out.single.edgeType, 'spawn');
      expect(out.single.otherId, _parent);
      expect(out.single.direction, AdjacencyEntryDirection.out);
      expect(out.single.declaredBy, {_child});
      final incoming = _entries(
        q.query(_parent, direction: AdjacencyDirection.incoming),
      );
      expect(incoming.single.otherId, _child);
      expect(incoming.single.direction, AdjacencyEntryDirection.incoming);
    });

    test('G7-2 守衛：只篩 blocking 不含 spawn；不篩選時兩者皆有', () {
      final q = _queryOf([
        buildRawNode(id: _parent),
        buildRawNode(id: _other),
        buildRawNode(
          id: _child,
          extra: {
            'source_ticket': _parent,
            'blockedBy': [_other],
          },
        ),
      ]);
      final filtered = _entries(q.query(_child, edgeTypes: {'blocking'}));
      expect(filtered.map((e) => e.edgeType).toSet(), {'blocking'});
      final all = _entries(q.query(_child));
      expect(all.map((e) => e.edgeType).toSet(), {'blocking', 'spawn'});
    });

    test('G7-3 無向邊：出、入、兩者皆回傳，方向標為無向', () {
      final q = _queryOf([
        buildRawNode(id: _parent),
        buildRawNode(
          id: _child,
          extra: {
            'relatedTo': [_parent],
          },
        ),
      ]);
      for (final direction in AdjacencyDirection.values) {
        for (final id in [_parent, _child]) {
          final entries = _entries(q.query(id, direction: direction));
          expect(entries, hasLength(1), reason: '$id $direction');
          expect(entries.single.direction, AdjacencyEntryDirection.undirected);
          expect(entries.single.otherId, id == _parent ? _child : _parent);
        }
      }
    });

    test('G7-4 不存在的 ID 回空清單', () {
      final q = _queryOf([buildRawNode(id: _parent)]);
      expect(_entries(q.query('0.9.9-W9-999')), isEmpty);
    });

    test('G7-5 守衛：圖不可用回圖不可用；可用圖查無鄰居回空清單；型別可窮舉區分', () {
      final unavailable = AdjacencyQuery(
        buildResult: buildGraph(
          rawNodes: const [],
          projectSchemaJson: buildEdgeTableJson(version: '99.0.0'),
          builtinSchemaJson: loadBuiltinSchemaJson(),
        ),
      );
      final bad = unavailable.query(_parent);
      expect(bad, isA<AdjacencyUnavailable>());
      expect(
        (bad as AdjacencyUnavailable).edgeTypeReason,
        EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
      );
      final good = _queryOf([buildRawNode(id: _parent)]).query(_parent);
      expect(good, isA<AdjacencyAvailable>());
      expect((good as AdjacencyAvailable).entries, isEmpty);
      // 窮舉 switch：缺任一子型別即編譯失敗
      String label(AdjacencyResult r) => switch (r) {
        AdjacencyAvailable() => 'available',
        AdjacencyUnavailable() => 'unavailable',
      };
      expect(label(bad), isNot(label(good)));
    });

    test('G7-6 尚未完成建圖回圖不可用', () {
      final result = AdjacencyQuery(buildResult: null).query(_parent);
      expect(result, isA<AdjacencyUnavailable>());
      expect(
        (result as AdjacencyUnavailable).cause,
        AdjacencyUnavailableCause.buildNotCompleted,
      );
    });

    test('G7-7 預設參數：全部邊型、方向兩者', () {
      final q = _queryOf([
        buildRawNode(id: _parent),
        buildRawNode(id: _other),
        buildRawNode(
          id: _child,
          extra: {
            'source_ticket': _parent,
            'blockedBy': [_other],
            'relatedTo': [_other],
          },
        ),
      ]);
      final byDefault = _entries(q.query(_child));
      final explicit = _entries(
        q.query(_child, edgeTypes: null, direction: AdjacencyDirection.both),
      );
      expect(byDefault.length, 3);
      expect(
        byDefault.map((e) => '${e.edgeType}|${e.otherId}').toSet(),
        explicit.map((e) => '${e.edgeType}|${e.otherId}').toSet(),
      );
    });
  });
}
