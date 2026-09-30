/// IT-3 輕節點與全文分離整合測試。需求：[SPEC-007 FR-02、FR-07；
/// test-design §2.6 IT3-A1～IT3-A6]。
///
/// 實體化時先依 manifest 寫最小 frontmatter，再以樣本的完整 frontmatter
/// 覆寫同一路徑（每個路徑最終只有一份檔案）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/ticket_detail/ticket_detail.dart';

import '../helpers/spec007/graph_manifest_materializer.dart';

const _corpora = ['graph_project_docs_manager', 'flutter_balance'];

/// 樣本的一列。
typedef _Sample = ({
  String corpus,
  String path,
  String id,
  Map<String, dynamic> frontmatter,
});

List<_Sample> _loadSamples() => [
  for (final s
      in loadSpec007Fixture('ticket_detail_samples')['samples'] as List)
    (
      corpus: s['corpus'] as String,
      path: s['path'] as String,
      id: s['id'] as String,
      frontmatter: Map<String, dynamic>.from(s['frontmatter'] as Map),
    ),
];

/// 使用中邊型（established 扣 `domain_dependency`，D6）的正反向欄位名。
Set<String> _activeEdgeFieldNames() {
  final edgeTypes =
      loadSpec007Fixture('type_table')['edge_types'] as Map<String, dynamic>;
  return {
    for (final e in edgeTypes.entries)
      if ((e.value as Map)['layer'] == 'established' &&
          e.key != 'domain_dependency') ...[
        (e.value as Map)['forward_field'] as String,
        ?((e.value as Map)['reverse_field'] as String?),
      ],
  };
}

String _json(Object? v) => jsonEncode(jsonDecode(jsonEncode(v)));

/// 樣本與 manifest 一致性檢查器：回傳不一致說明清單（空代表全部一致）。
List<String> _checkSamples(
  List<_Sample> samples,
  List<ManifestNodeRow> rows,
  Set<String> edgeFields,
) {
  final byKey = {for (final r in rows) '${r.host}|${r.path}': r};
  final problems = <String>[];
  for (final s in samples) {
    final row = byKey['${s.corpus}|${s.path}'];
    if (row == null) {
      problems.add('缺列：${s.corpus} ${s.path}');
      continue;
    }
    if (s.id != row.id) problems.add('${s.path} id 不一致');
    if (_json(s.frontmatter['status']) != _json(row.status)) {
      problems.add('${s.path} status 不一致');
    }
    if (_json(s.frontmatter['title']) != _json(row.title)) {
      problems.add('${s.path} title 不一致');
    }
    for (final field in edgeFields) {
      final inSample = s.frontmatter.containsKey(field);
      final inRow = row.edgeFields.containsKey(field);
      if (inSample != inRow ||
          (inSample &&
              _json(s.frontmatter[field]) != _json(row.edgeFields[field]))) {
        problems.add('${s.path} 欄位 $field 不一致');
      }
    }
  }
  return problems;
}

/// status 覆蓋檢查器：回傳缺漏的 status 值。
Set<String> _missingStatuses(List<_Sample> samples, String corpus) {
  final recorded =
      ((loadSpec007Fixture('ticket_detail_samples')['header']
                  as Map)['status_values']
              as Map)[corpus]
          as Map;
  final present = {
    for (final s in samples)
      if (s.corpus == corpus && s.frontmatter['status'] is String)
        s.frontmatter['status'] as String,
  };
  return {...recorded.keys.cast<String>()}..removeAll(present);
}

void main() {
  final rowsByHost = groupByHost(loadManifestRows());
  final samples = _loadSamples();
  final runs = <String, CorpusGraphRun>{};

  setUpAll(() async {
    for (final host in _corpora) {
      final overrides = {
        for (final s in samples)
          if (s.corpus == host) s.path: s.frontmatter,
      };
      runs[host] = await scanAndBuild(
        rows: rowsByHost[host]!,
        overrides: overrides,
      );
    }
  });

  for (final host in _corpora) {
    group('語料 $host', () {
      test('IT3-A1 圖節點欄位恰為輕節點五欄位，且值等於 manifest', () {
        final event = runs[host]!.event;
        final byPath = {for (final r in rowsByHost[host]!) r.path: r};
        expect(
          event.nodeCount,
          loadSpec007Fixture('expected_counts')['corpora'][host]['node_count'],
        );
        for (final node in event.nodes) {
          final row = byPath[node.path]!;
          expect(node.id, row.id);
          expect(node.status, row.status is String ? row.status : isNull);
          expect(node.title, row.title is String ? row.title : isNull);
          expect(node.typeName, isNotEmpty);
          expect(_lightNodeFields(node).keys, {
            'id',
            'typeName',
            'status',
            'title',
            'path',
          });
        }
      });

      test('IT3-A2 TicketDetail 回傳與樣本 frontmatter 逐鍵逐值相等', () {
        final detail = TicketDetail.fromRawNodes(runs[host]!.rawNodes);
        final mine = samples.where((s) => s.corpus == host).toList();
        expect(mine, isNotEmpty);
        for (final s in mine) {
          final found = detail.findById(s.id);
          expect(found, isNotNull, reason: '${s.id} 應可查得');
          expect(_json(found), _json(s.frontmatter), reason: s.id);
        }
      });

      test('IT3-A3 圖節點不暴露非輕節點欄位', () {
        final event = runs[host]!.event;
        final byId = {for (final n in event.nodes) n.id: n};
        final mine = samples.where((s) => s.corpus == host);
        for (final s in mine) {
          final node = byId[s.id]!;
          for (final leaked in ['what', 'how', 'who', 'frontmatter', 'where']) {
            expect(
              () => _dynamicField(node, leaked),
              throwsNoSuchMethodError,
              reason: '${s.id} 不應暴露 $leaked',
            );
          }
        }
      });

      test('IT3-A5 非 Ticket 節點 ID 查 TicketDetail 回傳不存在', () {
        final detail = TicketDetail.fromRawNodes(runs[host]!.rawNodes);
        final nonTicket = runs[host]!.event.nodes.where(
          (n) => n.typeName != 'Ticket',
        );
        expect(nonTicket, isNotEmpty);
        for (final node in nonTicket) {
          expect(detail.findById(node.id), isNull, reason: node.id);
        }
      });
    });
  }

  group('守衛（E2 正向對照）', () {
    test('IT3-A4 status 覆蓋檢查器：齊全通過、缺一種回報缺漏', () {
      for (final host in _corpora) {
        expect(_missingStatuses(samples, host), isEmpty);
      }
      const host = 'graph_project_docs_manager';
      final removed = samples.firstWhere((s) => s.corpus == host);
      final without = [
        for (final s in samples)
          if (!(s.corpus == host &&
              s.frontmatter['status'] == removed.frontmatter['status']))
            s,
      ];
      expect(_missingStatuses(without, host), {removed.frontmatter['status']});
    });

    test('IT3-A6 樣本與 manifest 一致性檢查器：一致通過、relatedTo 不同或缺列回報', () {
      final rows = loadManifestRows();
      final fields = _activeEdgeFieldNames();
      expect(_checkSamples(samples, rows, fields), isEmpty);

      final tampered = [
        for (final s in samples)
          (
            corpus: s.corpus,
            path: s.path,
            id: s.id,
            frontmatter: {
              ...s.frontmatter,
              if (s == samples.first) 'relatedTo': ['TAMPERED-1'],
            },
          ),
      ];
      expect(
        _checkSamples(tampered, rows, fields),
        contains(predicate<String>((p) => p.contains('relatedTo'))),
      );

      final orphan = [
        ...samples,
        (
          corpus: samples.first.corpus,
          path: 'docs/not-in-manifest.md',
          id: 'X-1',
          frontmatter: <String, dynamic>{'id': 'X-1'},
        ),
      ];
      expect(
        _checkSamples(orphan, rows, fields),
        contains(predicate<String>((p) => p.startsWith('缺列'))),
      );
    });
  });
}

Map<String, Object?> _lightNodeFields(LightNode n) => {
  'id': n.id,
  'typeName': n.typeName,
  'status': n.status,
  'title': n.title,
  'path': n.path,
};

Object? _dynamicField(Object node, String name) {
  final d = node as dynamic;
  return switch (name) {
    'what' => d.what,
    'how' => d.how,
    'who' => d.who,
    'where' => d.where,
    _ => d.frontmatter,
  };
}
