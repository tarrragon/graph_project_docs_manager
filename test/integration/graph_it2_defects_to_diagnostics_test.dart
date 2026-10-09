/// IT-2 缺陷交給 Diagnostics 整合測試。需求：[SPEC-007 FR-03、FR-09；
/// test-design §2.5 IT2-A1～IT2-A6]。
///
/// 只有本檔（`graph_it*`）可同時 import Graph 日誌與 Diagnostics（§1.3），
/// 故建圖不可用原因 → `UndeterminedGapReason` 的映射寫在本檔，扮演編排層
/// （0.3.0 `corpus_it2_gap_classification_test.dart` 同一前例）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../helpers/spec007/graph_manifest_materializer.dart';

const _corpora = ['graph_project_docs_manager', 'flutter_balance'];

/// 編排層映射（SPEC-007 v1.5 FR-09 #3）：兩種建圖不可用原因在 Diagnostics
/// 一律回報「專案版本不在已知範圍」。
UndeterminedGapReason _toUndeterminedReason(EdgeTypeUnavailableReason reason) =>
    switch (reason) {
      EdgeTypeUnavailableReason.projectVersionOutOfKnownRange ||
      EdgeTypeUnavailableReason.missingForwardCardinality ||
      EdgeTypeUnavailableReason.invalidEdgeTypeEntry ||
      EdgeTypeUnavailableReason.missingDirection =>
        UndeterminedGapReason.projectVersionOutOfKnownRange,
    };

GraphDefectGapResult _diagnose(CorpusGraphRun run) {
  final result = run.buildResult;
  return switch (result) {
    GraphBuildAvailable(:final event) => detectGraphDefectGaps(
      GraphDefectInputAvailable(event),
    ),
    GraphBuildUnavailable(:final reason) => detectGraphDefectGaps(
      GraphDefectInputUnavailable(_toUndeterminedReason(reason)),
    ),
  };
}

/// key 排序後的 canonical JSON（原始值以 JSON 往返正規化）。
String _canonical(Object? value) =>
    jsonEncode(_sorted(jsonDecode(jsonEncode(value))));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final x in v) _sorted(x)];
  return v;
}

String _gapKey(GraphDefectGap gap) => switch (gap.defect) {
  final DanglingRefGraphDefect d => _refKey(
    gap.kind.name,
    d.ref,
    d.reason.name,
  ),
  final MalformedRefGraphDefect d => _refKey(
    gap.kind.name,
    d.ref,
    d.reason.name,
  ),
  DuplicateIdGraphDefect(:final id, :final paths) => _canonical({
    'kind': 'duplicateId',
    'id': id,
    'paths': (paths.toList()..sort()),
  }),
  MultiSourceGraphDefect(:final from, :final edgeType, :final targets) =>
    _canonical({
      'kind': 'multiSource',
      'from': from,
      'edge_type': edgeType,
      'targets': [
        for (final t
            in (targets.toList()..sort((a, b) => a.to.compareTo(b.to))))
          {'to': t.to, 'declared_by': (t.declaredBy.toList()..sort())},
      ],
    }),
  FlowGraphDefect(:final ucId, :final stepId, :final field, :final rawValue) =>
    _canonical({
      'kind': gap.kind.name,
      'uc_id': ucId,
      'step_id': stepId,
      'field': field,
      'raw_value': rawValue,
    }),
};

String _refKey(String kind, ReferenceValue ref, String reason) => _canonical({
  'kind': kind,
  'source_id': ref.sourceId,
  'path': ref.sourcePath,
  'field': ref.fieldName,
  'raw_value': ref.value,
  'edge_type': ref.edgeTypeName,
  'reason': reason,
});

List<String> _expectedDefectKeys(String host) => [
  for (final d
      in (loadSpec007Fixture('expected_defects')['corpora'][host] as List))
    _canonical(d),
];

/// 守恆比對器：回傳差異說明（空字串代表與凍結總數相等）。
String _compareConservation({
  required int resolved,
  required int dangling,
  required int malformed,
  required int frozenTotal,
}) {
  final sum = resolved + dangling + malformed;
  return sum == frozenTotal ? '' : '待測合計 $sum != 凍結 $frozenTotal';
}

Map<String, dynamic> _variantTable({
  required bool dropEdgeTypes,
  String? dropCardinalityOf,
}) {
  final table = deepCopyJson(loadSpec007Fixture('type_table'));
  table['schema_generated_at_framework_version'] = '99.0.0';
  if (dropEdgeTypes) table.remove('edge_types');
  if (dropCardinalityOf != null) {
    ((table['edge_types'] as Map)[dropCardinalityOf] as Map).remove(
      'forward_cardinality',
    );
  }
  return table;
}

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
      Map<String, dynamic> counts() =>
          loadSpec007Fixture('expected_counts')['corpora'][host]
              as Map<String, dynamic>;

      test('IT2-A1 graphDefect 破洞集合與凍結值一一對應', () {
        final result = _diagnose(runs[host]!) as GraphDefectsDetected;
        final diff = diffReport(
          result.gaps.map(_gapKey),
          _expectedDefectKeys(host),
        );
        expect(diff, isEmpty, reason: diff);
      });

      test('IT2-A2 解析成功＋斷邊＋格式錯誤等於凍結的引用值總數', () {
        final event = runs[host]!.event;
        final diff = _compareConservation(
          resolved: event.resolvedCount,
          dangling: event.danglingRefCount,
          malformed: event.malformedRefCount,
          frozenTotal: counts()['reference_value_total'] as int,
        );
        expect(diff, isEmpty, reason: diff);
        expect(event.totalReferences, counts()['reference_value_total']);
      });

      test('IT2-A3 各項計數逐項等於凍結值', () {
        final event = runs[host]!.event;
        final c = counts();
        expect(event.nodeCount, c['node_count']);
        expect(event.edgeCount, c['edge_count']);
        expect(event.resolvedCount, c['resolved_count']);
        expect(event.danglingRefCount, c['dangling_count']);
        expect(event.malformedRefCount, c['malformed_count']);
        expect(event.duplicateIdCount, c['duplicate_id_count']);
        expect(event.multiSourceCount, c['multi_source_count']);
        expect(event.edgesByType, c['edges_by_type']);
        final completed = runs[host]!.logs
            .where((l) => l.event == GraphLogEvent.buildCompleted)
            .single
            .payload;
        expect(
          completed[GraphLogKeys.totalReferences],
          c['reference_value_total'],
        );
      });
    });
  }

  group('守衛與 E1 鑑別', () {
    test('IT2-A4 守恆比對器：相等通過、解析成功少 1 回報失敗', () {
      const host = 'graph_project_docs_manager';
      final event = runs[host]!.event;
      final total =
          loadSpec007Fixture(
                'expected_counts',
              )['corpora'][host]['reference_value_total']
              as int;
      expect(
        _compareConservation(
          resolved: event.resolvedCount,
          dangling: event.danglingRefCount,
          malformed: event.malformedRefCount,
          frozenTotal: total,
        ),
        isEmpty,
      );
      expect(
        _compareConservation(
          resolved: event.resolvedCount - 1,
          dangling: event.danglingRefCount,
          malformed: event.malformedRefCount,
          frozenTotal: total,
        ),
        isNotEmpty,
      );
    });

    test('IT2-A5 缺 edge_types 且版本高於內建：建圖不可用、無法判定，與 A1 不同', () {
      const host = 'graph_project_docs_manager';
      final rawNodes = runs[host]!.rawNodes;
      final run = buildFromRawNodes(
        rawNodes,
        schemaJson: _variantTable(dropEdgeTypes: true),
      );
      expect(run.buildResult, isA<GraphBuildUnavailable>());
      final result = _diagnose(run);
      expect(result, isA<GraphDefectUndetermined>());
      expect(
        (result as GraphDefectUndetermined).reason,
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      );
      expect(_diagnose(runs[host]!), isA<GraphDefectsDetected>());
      expect((_diagnose(runs[host]!) as GraphDefectsDetected).gaps, isNotEmpty);
    });

    test('IT2-A6 缺正向基數：日誌原因碼異於 A5，Diagnostics 原因相同', () {
      const host = 'graph_project_docs_manager';
      final rawNodes = runs[host]!.rawNodes;
      final a5 = buildFromRawNodes(
        rawNodes,
        schemaJson: _variantTable(dropEdgeTypes: true),
      );
      final a6 = buildFromRawNodes(
        rawNodes,
        schemaJson: _variantTable(
          dropEdgeTypes: false,
          dropCardinalityOf: 'association',
        ),
      );
      String logReason(CorpusGraphRun run) =>
          run.logs
                  .where((l) => l.event == GraphLogEvent.buildUnavailable)
                  .single
                  .payload[GraphLogKeys.reason]!
              as String;
      expect(
        logReason(a6),
        EdgeTypeUnavailableReason.missingForwardCardinality.name,
      );
      expect(logReason(a6), isNot(logReason(a5)));
      final r5 = _diagnose(a5) as GraphDefectUndetermined;
      final r6 = _diagnose(a6) as GraphDefectUndetermined;
      expect(r6.reason, UndeterminedGapReason.projectVersionOutOfKnownRange);
      expect(r6.reason, r5.reason);
    });
  });
}
