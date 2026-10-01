import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

ReferenceClassification _run(List<RawNode> nodes) {
  final inputs = graphInputsFrom();
  return classifyGraphReferences(
    rawNodes: nodes,
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
  );
}

RawNode _withRelated(String id, Object value) =>
    buildRawNode(id: id, extra: {'relatedTo': value});

void main() {
  group('G3 引用值分類（FR-03）', () {
    test('G3-1 圖上無該節點：targetMissing，不建邊', () {
      final r = _run([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {'source_ticket': '0.1.0-W3-181'},
        ),
      ]);
      expect(r.dangling.single.reason, DanglingReason.targetMissing);
      expect(r.resolved, isEmpty);
    });

    final cases = <String, (String, Object)>{
      'G3-2': ('relatedTo', ['0.1.0-W1-072 0.1.0-W1-073']),
      'G3-3': ('discovered_during', '0.2.1-W3-1057 驗收'),
      'G3-4': ('spawned_tickets', ['PENDING']),
    };
    for (final entry in cases.entries) {
      test('${entry.key} 不部分救回：patternMismatch', () {
        final r = _run([
          buildRawNode(
            id: '0.1.0-W1-001',
            extra: {entry.value.$1: entry.value.$2},
          ),
          buildRawNode(id: '0.1.0-W1-072'),
          buildRawNode(id: '0.1.0-W1-073'),
        ]);
        expect(r.malformed.single.reason, MalformedReason.patternMismatch);
        expect(r.resolved, isEmpty);
      });
    }

    test('G3-5 前導空白不去除；無空白版本解析成功', () {
      final target = buildRawNode(id: '0.1.0-W1-001');
      final bad = _run([
        target,
        _withRelated('0.1.0-W1-002', [' 0.1.0-W1-001']),
      ]);
      expect(bad.malformed.single.reason, MalformedReason.patternMismatch);
      expect(bad.resolved, isEmpty);
      final ok = _run([
        target,
        _withRelated('0.1.0-W1-002', ['0.1.0-W1-001']),
      ]);
      expect(ok.resolved, hasLength(1));
      expect(ok.malformed, isEmpty);
    });

    test('G3-6 自我引用為 selfReference；列出他人則解析成功', () {
      final self = _run([
        _withRelated('0.1.0-W1-001', ['0.1.0-W1-001']),
      ]);
      expect(self.malformed.single.reason, MalformedReason.selfReference);
      expect(self.resolved, isEmpty);
      final other = _run([
        _withRelated('0.1.0-W1-001', ['0.1.0-W1-002']),
        buildRawNode(id: '0.1.0-W1-002'),
      ]);
      expect(other.resolved, hasLength(1));
      expect(other.malformed, isEmpty);
    });

    test('G3-7 格式錯且不存在：歸格式錯誤', () {
      final r = _run([
        _withRelated('0.1.0-W1-001', ['not an id']),
      ]);
      expect(r.malformed, hasLength(1));
      expect(r.dangling, isEmpty);
    });

    test('G3-8 分布已知 fixture：三類計數與守恆', () {
      final known = buildKnownDistribution();
      final r = _run(known.rawNodes);
      expect(r.lightNodes, hasLength(known.nodeCount));
      expect(r.duplicates, hasLength(known.duplicateIdCount));
      expect(r.totalReferences, known.totalReferences);
      expect(r.resolved, hasLength(known.resolved));
      expect(r.dangling, hasLength(known.dangling));
      expect(r.malformed, hasLength(known.malformed));
      expect(
        conservationHolds(
          total: r.totalReferences,
          resolved: r.resolved.length,
          dangling: r.dangling.length,
          malformed: r.malformed.length,
        ),
        isTrue,
      );
    });

    test('G3-9 守恆檢查器對少算一個的計數回報失敗', () {
      expect(
        conservationHolds(total: 11, resolved: 4, dangling: 3, malformed: 4),
        isTrue,
      );
      expect(
        conservationHolds(total: 11, resolved: 4, dangling: 3, malformed: 3),
        isFalse,
      );
    });
  });
}
