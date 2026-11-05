import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

/// SPEC-007 FR-03〈closed_by 的略過規則〉驗收（0.6.0-W1-169.4）。
GraphBuiltEvent _build(List<RawNode> nodes) {
  final inputs = graphInputsFrom();
  return buildGraphFromInputs(
    rawNodes: nodes,
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
  );
}

ReferenceClassification _classify(List<RawNode> nodes) {
  final inputs = graphInputsFrom();
  return classifyGraphReferences(
    rawNodes: nodes,
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
  );
}

RawNode _a(String field, Object? value) =>
    buildRawNode(id: '0.1.0-W1-001', extra: {field: value});

final _target = buildRawNode(id: '0.6.0-W1-010');

void main() {
  group('closed_by 略過規則（FR-03）', () {
    test('CB-1 E2 正向對照：語料內存在的票號建 closed_by 邊', () {
      final event = _build([_a('closed_by', '0.6.0-W1-010'), _target]);
      final edge = event.edges.singleWhere((e) => e.edgeType == 'closed_by');
      expect(edge.from, '0.1.0-W1-001');
      expect(edge.to, '0.6.0-W1-010');
      expect(edge.layer, 'proposed');
      expect(edge.isUndirected, isFalse);
      expect(event.skippedCount, 0);
    });

    for (final value in [
      'tarrragon/claude#60',
      'flutter_balance:W4-007',
      'none',
    ]) {
      test('CB-2 非語料值略過：$value', () {
        final event = _build([_a('closed_by', value)]);
        expect(event.edges.where((e) => e.edgeType == 'closed_by'), isEmpty);
        expect(event.danglingRefCount, 0);
        expect(event.malformedRefCount, 0);
        expect(event.skippedCount, 1);
      });
    }

    test('CB-3 正向對照：符合 id_pattern 但語料內不存在：danglingRef', () {
      final event = _build([_a('closed_by', '0.6.0-W1-999')]);
      final d = event.graphDefects.whereType<DanglingRefGraphDefect>().single;
      expect(d.reason, DanglingReason.targetMissing);
      expect(event.danglingRefCount, 1);
      expect(event.skippedCount, 0);
    });

    test('CB-4 形狀不合法（42）：invalidShape，不略過', () {
      final event = _build([_a('closed_by', 42)]);
      final m = event.graphDefects.whereType<MalformedRefGraphDefect>().single;
      expect(m.reason, MalformedReason.invalidShape);
      expect(event.skippedCount, 0);
    });

    test('CB-5 守恆式：欄位值總數 = 引用值總數 + 略過數', () {
      final nodes = [
        buildRawNode(id: '0.1.0-W1-001', extra: {'closed_by': '0.6.0-W1-010'}),
        buildRawNode(id: '0.1.0-W1-002', extra: {'closed_by': 'none'}),
        buildRawNode(
          id: '0.1.0-W1-003',
          extra: {'closed_by': 'tarrragon/claude#60'},
        ),
        _target,
      ];
      final r = _classify(nodes);
      expect(r.skippedCount, 2);
      expect(r.totalReferences, 1);
      expect(
        r.resolved.length + r.dangling.length + r.malformed.length,
        r.totalReferences,
      );
      expect(r.totalReferences + r.skippedCount, 3);
    });

    test('CB-6 E2 不外溢：同值放 source_ticket 仍為 malformedRef', () {
      final event = _build([_a('source_ticket', 'tarrragon/claude#60')]);
      final m = event.graphDefects.whereType<MalformedRefGraphDefect>().single;
      expect(m.reason, MalformedReason.patternMismatch);
      expect(event.skippedCount, 0);
    });

    test('CB-7 重複 ID 目標（符合格式）：targetDuplicated', () {
      final event = _build([
        _a('closed_by', '0.6.0-W1-010'),
        _target,
        buildRawNode(id: '0.6.0-W1-010', path: 'docs/dup.md'),
      ]);
      final d = event.graphDefects.whereType<DanglingRefGraphDefect>().single;
      expect(d.reason, DanglingReason.targetDuplicated);
      expect(event.skippedCount, 0);
    });

    test('CB-8 自我引用不略過：selfReference', () {
      final event = _build([_a('closed_by', '0.1.0-W1-001')]);
      final m = event.graphDefects.whereType<MalformedRefGraphDefect>().single;
      expect(m.reason, MalformedReason.selfReference);
    });
  });
}
