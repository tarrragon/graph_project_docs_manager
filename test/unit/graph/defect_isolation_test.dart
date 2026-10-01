import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _dup = '0.3.0-W1-090';

/// 七種缺陷各插入一筆（皆掛在新節點上，不改動基準節點的欄位）。
List<RawNode> _injected() => [
  buildRawNode(id: '0.3.0-W1-001', extra: {'source_ticket': '0.3.0-W9-999'}),
  buildRawNode(
    id: '0.3.0-W1-002',
    extra: {
      'relatedTo': [_dup],
    },
  ),
  buildRawNode(id: '0.3.0-W1-003', extra: {'discovered_during': 'PENDING x'}),
  buildRawNode(
    id: '0.3.0-W1-004',
    extra: {
      'blockedBy': [42],
    },
  ),
  buildRawNode(id: '0.3.0-W1-005', extra: {'parent_id': '0.3.0-W1-005'}),
  buildRawNode(id: _dup, path: 'docs/dup-x.md'),
  buildRawNode(id: _dup, path: 'docs/dup-y.md'),
  buildRawNode(
    id: '0.3.0-W1-010',
    extra: {
      'source_ticket': ['0.3.0-W1-011', '0.3.0-W1-012'],
    },
  ),
  buildRawNode(id: '0.3.0-W1-011'),
  buildRawNode(id: '0.3.0-W1-012'),
];

Set<String> _defectSignatures(GraphBuiltEvent event) => {
  for (final d in event.graphDefects)
    switch (d) {
      DanglingRefGraphDefect(:final ref, :final reason) =>
        'dangling:${ref.sourceId}:${reason.name}',
      MalformedRefGraphDefect(:final ref, :final reason) =>
        'malformed:${ref.sourceId}:${reason.name}',
      DuplicateIdGraphDefect(:final id) => 'dup:$id',
      MultiSourceGraphDefect() => 'multi:${d.from}:${d.edgeType}',
    },
};

void main() {
  group('G8 缺陷隔離（NFR-01）', () {
    final baseNodes = buildKnownDistribution().rawNodes;
    final e0 = buildGraphEvent(baseNodes);

    test('G8-1 基準 fixture 建圖結果（E0）為既有已知值', () {
      final known = buildKnownDistribution();
      expect(e0.nodeCount, known.nodeCount);
      expect(e0.multiSourceCount, 0);
      expect(e0.resolvedCount, known.resolved);
    });

    test('G8-2 各插入一筆缺陷：建圖完成，原有邊與分類不變，新增缺陷各一筆', () {
      final event = buildGraphEvent([...baseNodes, ..._injected()]);

      expect(edgeKeys(event).containsAll(edgeKeys(e0)), isTrue);
      expect(edgeKeys(event).difference(edgeKeys(e0)), {
        'spawn|0.3.0-W1-010|0.3.0-W1-011|0.3.0-W1-010',
        'spawn|0.3.0-W1-010|0.3.0-W1-012|0.3.0-W1-010',
      });
      expect(
        _defectSignatures(event).containsAll(_defectSignatures(e0)),
        isTrue,
      );
      expect(_defectSignatures(event).difference(_defectSignatures(e0)), {
        'dangling:0.3.0-W1-001:${DanglingReason.targetMissing.name}',
        'dangling:0.3.0-W1-002:${DanglingReason.targetDuplicated.name}',
        'malformed:0.3.0-W1-003:${MalformedReason.patternMismatch.name}',
        'malformed:0.3.0-W1-004:${MalformedReason.invalidShape.name}',
        'malformed:0.3.0-W1-005:${MalformedReason.selfReference.name}',
        'dup:$_dup',
        'multi:0.3.0-W1-010:spawn',
      });
      expect(event.graphDefects.length, e0.graphDefects.length + 7);
    });

    test('G8-3 插入節點排在 rawNodes 最前與最後：結果相同', () {
      final last = buildGraphEvent([...baseNodes, ..._injected()]);
      final first = buildGraphEvent([..._injected(), ...baseNodes]);
      expect(edgeKeys(first), edgeKeys(last));
      expect(_defectSignatures(first), _defectSignatures(last));
      expect(first.edgeCount, last.edgeCount);
      expect(first.totalReferences, last.totalReferences);
    });
  });
}
