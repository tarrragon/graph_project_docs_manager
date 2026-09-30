/// IT-1 聯集整合測試：暫存目錄真實檔案 → 真實 Corpus 掃描 → 建圖 → 與凍結的
/// 獨立參照實作輸出比對。需求：[SPEC-007 FR-04、FR-05、FR-08；
/// test-design §2.4 IT1-A1～IT1-A6]。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import '../helpers/spec007/graph_manifest_materializer.dart';

const _corpora = ['graph_project_docs_manager', 'flutter_balance'];

void main() {
  final rowsByHost = groupByHost(loadManifestRows());
  final runs = <String, CorpusGraphRun>{};

  setUpAll(() async {
    for (final host in _corpora) {
      runs[host] = await scanAndBuild(rows: rowsByHost[host]!);
    }
  });

  for (final host in _corpora) {
    group('語料 $host', () {
      test('IT1-A1 邊集合（含宣告來源）與凍結值完全相等', () {
        final diff = diffReport(
          builtEdgeKeys(runs[host]!.event),
          expectedEdgeKeys(host),
        );
        expect(diff, isEmpty, reason: diff);
      });

      test('IT1-A2 單側 relatedTo：未宣告端查得宣告端，且只讀自身欄位查不到', () {
        final rows = rowsByHost[host]!;
        final byId = {for (final r in rows) r.id: r};
        final query = AdjacencyQuery(buildResult: runs[host]!.buildResult);
        final oneSide = rows.where(
          (r) => r.covers.contains('related_one_side'),
        );
        expect(oneSide, isNotEmpty);
        for (final a in oneSide) {
          final partners = _oneSidePartners(host, a.id);
          expect(partners, isNotEmpty, reason: '${a.id} 在凍結邊中無單側宣告');
          for (final b in partners) {
            final result = query.query(b, edgeTypes: {'association'});
            final entries = (result as AdjacencyAvailable).entries;
            expect(
              entries.map((e) => e.otherId),
              contains(a.id),
              reason: '$b 的鄰接查詢應含宣告端 ${a.id}',
            );
            final ownField = byId[b]?.edgeFields['relatedTo'];
            final ownIds = ownField is List ? ownField : const [];
            expect(
              ownIds,
              isNot(contains(a.id)),
              reason: '$b 自己的欄位不應列出 ${a.id}',
            );
          }
        }
      });

      test('IT1-A3 只在反向的 spawn：子票查出得到父票，宣告來源為父', () {
        final rows = rowsByHost[host]!;
        final query = AdjacencyQuery(buildResult: runs[host]!.buildResult);
        final targets = rows.where(
          (r) => r.covers.contains('spawn_reverse_only'),
        );
        expect(targets, isNotEmpty);
        for (final child in targets) {
          final entries = (query.query(
            child.id,
            edgeTypes: {'spawn'},
            direction: AdjacencyDirection.out,
          ) as AdjacencyAvailable).entries;
          final parents = _reverseOnlyParents(host, child.id);
          expect(parents, isNotEmpty, reason: '${child.id} 無凍結的反向宣告 spawn');
          for (final parent in parents) {
            final hit = entries.where((e) => e.otherId == parent);
            expect(hit, isNotEmpty, reason: '${child.id} 應得到父票 $parent');
            expect(hit.first.declaredBy, {parent});
          }
        }
      });

      test('IT1-A4 宣告來源五組計數等於凍結值', () {
        final event = runs[host]!.event;
        final shapes =
            loadSpec007Fixture(
                  'expected_counts',
                )['corpora'][host]['declaration_shapes']
                as Map<String, dynamic>;
        final directed = shapes['directed'] as Map<String, dynamic>;
        final undirected = shapes['undirected'] as Map<String, dynamic>;
        final actual = event.directedShapeCounts;
        expect(
          actual[DirectedDeclarationShape.fromOnly],
          directed['from_only'],
        );
        expect(actual[DirectedDeclarationShape.toOnly], directed['to_only']);
        expect(actual[DirectedDeclarationShape.both], directed['both']);
        expect(event.undirectedOneEndCount, undirected['one_end']);
        expect(event.undirectedBothCount, undirected['both']);
      });
    });
  }

  group('守衛（E2 正向對照）', () {
    test('IT1-A5 manifest 覆蓋檢查器：齊全通過、缺 related_one_side 回報缺漏', () {
      final rows = loadManifestRows();
      expect(findMissingCoverage(rows), isEmpty);
      final without = [
        for (final r in rows)
          if (!r.covers.contains('related_one_side')) r,
      ];
      expect(findMissingCoverage(without), {'related_one_side'});
    });

    test('IT1-A6 實體化器拒絕無法序列化的值型別而非略過', () {
      expect(
        serializeFrontmatter({
          'id': 'X-1',
          'relatedTo': <Object?>['A'],
        }),
        contains('relatedTo'),
      );
      expect(
        () => serializeFrontmatter({'id': 'X-1', 'relatedTo': Object()}),
        throwsA(isA<UnserializableFrontmatterValue>()),
      );
      expect(
        () => serializeFrontmatter({
          'id': 'X-1',
          'relatedTo': [DateTime(2026)],
        }),
        throwsA(isA<UnserializableFrontmatterValue>()),
      );
    });
  });
}

List<Map<String, dynamic>> _frozenEdges(String host, String type) => [
  for (final e
      in (loadSpec007Fixture('expected_edges')['corpora'][host] as List))
    if (e['edge_type'] == type) e as Map<String, dynamic>,
];

/// 宣告端為 [a]、僅單側宣告的 association 邊的對端（未宣告端）。
Set<String> _oneSidePartners(String host, String a) => {
  for (final e in _frozenEdges(host, 'association'))
    if ((e['declared_by'] as List).length == 1 &&
        (e['declared_by'] as List).single == a)
      (e['from'] == a ? e['to'] : e['from']) as String,
};

/// [child] 為起點、且只由終點（父）宣告的 spawn 邊的終點。
Set<String> _reverseOnlyParents(String host, String child) => {
  for (final e in _frozenEdges(host, 'spawn'))
    if (e['from'] == child &&
        (e['declared_by'] as List).length == 1 &&
        (e['declared_by'] as List).single == e['to'])
      e['to'] as String,
};
