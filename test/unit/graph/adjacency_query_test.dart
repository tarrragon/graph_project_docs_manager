import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _child = '0.1.0-W1-002';
const _parent = '0.1.0-W1-001';
const _other = '0.1.0-W1-003';

AdjacencyQuery _queryOf(
  List<RawNode> rawNodes, {
  Map<String, dynamic>? projectSchemaJson,
}) => AdjacencyQuery(
  buildResult: buildGraph(
    rawNodes: rawNodes,
    projectSchemaJson: projectSchemaJson ?? loadBuiltinSchemaJson(),
    builtinSchemaJson: loadBuiltinSchemaJson(),
  ),
);

const _bundleA = 'DOMAIN-MAP-a';
const _bundleB = 'DOMAIN-MAP-b';

RawNode _bundleNode(String id, {List<String>? dependsOn}) => buildRawNode(
  id: id,
  typeName: 'DomainBundle',
  extra: {
    'domain': id.substring('DOMAIN-MAP-'.length),
    'depends_on_bundles': ?dependsOn,
  },
);

List<RawNode> _g78Fixture() => [
  _bundleNode(_bundleA, dependsOn: [_bundleB]),
  _bundleNode(_bundleB),
  buildRawNode(id: _parent),
  buildRawNode(id: _child, extra: {'source_ticket': _parent}),
];

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
      expect(out.single.layer, 'established');
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
        (bad as AdjacencyBuildUnavailable).edgeTypeReason,
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

    test('G7-7 預設邊型含 bundle_dependency', () {
      final entries = _entries(_queryOf(_g78Fixture()).query(_bundleA));
      expect(entries.map((e) => e.edgeType), contains('bundle_dependency'));
    });

    test('G7-8 bundle_dependency 回傳項 layer 為 proposed；子票項為 established', () {
      final q = _queryOf(_g78Fixture());
      final a = _entries(q.query(_bundleA, direction: AdjacencyDirection.out));
      expect(a, hasLength(1));
      expect(a.single.edgeType, 'bundle_dependency');
      expect(a.single.otherId, _bundleB);
      expect(a.single.layer, 'proposed');
      final child = _entries(
        q.query(_child, direction: AdjacencyDirection.out),
      );
      expect(child.single.layer, 'established');
    });

    test('G7-9 E1 鑑別：型別表把 bundle_dependency 改為 established，layer 跟著變', () {
      final table = loadBuiltinSchemaJson();
      final edges = table['edge_types'] as Map<String, dynamic>;
      (edges['bundle_dependency'] as Map<String, dynamic>)['layer'] =
          'established';
      final q = _queryOf(_g78Fixture(), projectSchemaJson: table);
      final a = _entries(q.query(_bundleA, direction: AdjacencyDirection.out));
      expect(a.single.layer, 'established');
    });

    test('G7-10 守衛：指向不存在的 DOMAIN-MAP 成一筆 danglingRef，不建邊（對照 G7-8）', () {
      final result = buildGraph(
        rawNodes: [
          _bundleNode(_bundleA, dependsOn: ['DOMAIN-MAP-nope']),
        ],
        projectSchemaJson: loadBuiltinSchemaJson(),
        builtinSchemaJson: loadBuiltinSchemaJson(),
      );
      final event = (result as GraphBuildAvailable).event;
      final dangling = event.graphDefects
          .whereType<DanglingRefGraphDefect>()
          .toList();
      expect(dangling, hasLength(1));
      expect(dangling.single.reason, DanglingReason.targetMissing);
      expect(dangling.single.ref.edgeTypeName, 'bundle_dependency');
      expect(event.edges, isEmpty);
      expect(event.domainResolver.resolve('DOMAIN-MAP-nope'), isNull);
      final positive = _entries(_queryOf(_g78Fixture()).query(_bundleA));
      expect(positive, isNotEmpty);
    });
  });

  group('本專案語料快照（0.5.0-W1-103.2）', () {
    test('bundle_dependency 7 條邊進主圖，layer 為 proposed，無破洞', () async {
      final event = await loadSnapshotEvent('graph_project_docs_manager');
      final bundleEdges = event.edges
          .where((e) => e.edgeType == 'bundle_dependency')
          .toList();
      expect(bundleEdges, hasLength(7));
      expect(bundleEdges.every((e) => e.layer == 'proposed'), isTrue);
      final dangling = event.graphDefects
          .whereType<DanglingRefGraphDefect>()
          .where((d) => d.ref.edgeTypeName == 'bundle_dependency');
      expect(dangling, isEmpty);
    });
  });

  group('不可變結果（0.4.1-W1-004）', () {
    test('entries 與 AdjacencyEntry.declaredBy 寫入拋 UnsupportedError', () {
      final q = _queryOf([
        buildRawNode(id: _parent),
        buildRawNode(id: _child, extra: {'source_ticket': _parent}),
      ]);
      final entries = _entries(q.query(_child));
      expect(() => entries.add(entries.first), throwsUnsupportedError);
      expect(() => entries.first.declaredBy.add('X'), throwsUnsupportedError);
    });
  });
}
