// SPEC-007-test-design.md §3.1 S6：邊型解碼（FR-01）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/spec007/edge_table_builder.dart';

Map<String, dynamic> _builtinJson() =>
    jsonDecode(
          File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Set<String> _keys(EdgeTypeResolution r) => r.edgeTypes.keys.toSet();

EdgeTypeResolution _resolve(Map<String, dynamic>? project) => resolveEdgeTypes(
  projectSchemaJson: project,
  builtinSchemaJson: _builtinJson(),
);

void main() {
  final builtin = _builtinJson();
  final builtinEdges = builtin['edge_types'] as Map<String, dynamic>;
  final builtinVersion =
      builtin['schema_generated_at_framework_version'] as String;

  test('S6-1 內建表解碼：鍵集合與各欄位', () {
    final result = _resolve(builtin);
    expect(_keys(result), builtinEdges.keys.toSet());
    for (final entry in builtinEdges.entries) {
      final edge = result.edgeTypes[entry.key]!;
      final raw = entry.value as Map<String, dynamic>;
      expect(edge.name, entry.key);
      expect(edge.edgeClass, raw['class']);
      expect(edge.forwardField, raw['forward_field']);
      expect(edge.reverseField, raw['reverse_field']);
      expect(edge.forwardCardinality.name, raw['forward_cardinality']);
      expect(edge.layer, raw['layer']);
    }
  });

  test('S6-2 使用中邊型 = established 扣 domain_dependency', () {
    final expected = builtinEdges.entries
        .where((e) => (e.value as Map)['layer'] == 'established')
        .map((e) => e.key)
        .toSet()
      ..remove('domain_dependency');
    final result = _resolve(builtin);
    expect(result.activeEdgeTypes.map((e) => e.name).toSet(), expected);
    expect(expected, isNotEmpty);
  });

  test('S6-3 新增 established 邊型 testEdge 成為使用中', () {
    final table = buildEdgeTableJson(
      version: builtinVersion,
      edges: {'testEdge': const EdgeSpec(forwardField: 'test_refs')},
    );
    final active = _resolve(table).activeEdgeTypes;
    expect(active.map((e) => e.name), contains('testEdge'));
    expect(
      active.firstWhere((e) => e.name == 'testEdge').forwardField,
      'test_refs',
    );
  });

  test('S6-4 forward_field 改名後解碼帶新欄位名', () {
    final table = buildEdgeTableJson(
      version: builtinVersion,
      edges: {'association': const EdgeSpec(forwardField: 'renamed_refs')},
    );
    final edge = _resolve(table).edgeTypes['association']!;
    expect(edge.forwardField, 'renamed_refs');
    expect(edge.forwardField, isNot('relatedTo'));
  });

  test('S6-5 缺 edge_types、版本等於內建：同內建表且可用', () {
    final result = _resolve(buildEdgeTableJson(version: builtinVersion));
    expect(_keys(result), builtinEdges.keys.toSet());
    expect(result.isGraphAvailable, isTrue);
    expect(result.unavailableReason, isNull);
  });

  test('S6-6 缺 edge_types、版本低於內建：同 S6-5', () {
    final result = _resolve(buildEdgeTableJson(version: '0.0.1'));
    expect(_keys(result), builtinEdges.keys.toSet());
    expect(result.isGraphAvailable, isTrue);
  });

  test('S6-7 守衛：缺 edge_types、版本高於內建 -> 不可用（對照 S6-5）', () {
    final result = _resolve(buildEdgeTableJson(version: '999.0.0'));
    expect(result.isGraphAvailable, isFalse);
    expect(
      result.unavailableReason,
      EdgeTypeUnavailableReason.versionOutOfKnownRange,
    );
    final positive = _resolve(buildEdgeTableJson(version: builtinVersion));
    expect(positive.isGraphAvailable, isTrue);
  });

  test('S6-8 守衛：缺正向基數、版本高於內建 -> 不可用；版本等於內建則補值可用', () {
    Map<String, dynamic> table(String version) => buildEdgeTableJson(
      version: version,
      edges: {
        'association': const EdgeSpec(
          forwardField: 'relatedTo',
          forwardCardinality: null,
        ),
      },
    );
    final high = _resolve(table('999.0.0'));
    expect(high.isGraphAvailable, isFalse);
    expect(
      high.unavailableReason,
      EdgeTypeUnavailableReason.missingForwardCardinality,
    );
    final equal = _resolve(table(builtinVersion));
    expect(equal.isGraphAvailable, isTrue);
    expect(
      equal.edgeTypes['association']!.forwardCardinality,
      EdgeCardinality.many,
    );
  });

  test('S6-9 proposed 邊型不在使用中', () {
    final table = buildEdgeTableJson(
      version: builtinVersion,
      edges: {
        'draftEdge': const EdgeSpec(forwardField: 'd', layer: 'proposed'),
        'liveEdge': const EdgeSpec(forwardField: 'l'),
      },
    );
    final names = _resolve(table).activeEdgeTypes.map((e) => e.name);
    expect(names, isNot(contains('draftEdge')));
    expect(names, contains('liveEdge'));
  });

  test('S6-10 含 edge_types 不改變 node_types 解碼', () {
    final without = typeTableFromJson(
      buildEdgeTableJson(version: builtinVersion),
    );
    final withEdges = typeTableFromJson(
      buildEdgeTableJson(
        version: builtinVersion,
        edges: {'association': const EdgeSpec(forwardField: 'relatedTo')},
      ),
    );
    expect(withEdges.nodeTypes.keys, without.nodeTypes.keys);
    expect(
      withEdges.nodeTypes['SPEC']!.idPattern,
      without.nodeTypes['SPEC']!.idPattern,
    );
    final real = typeTableFromJson(builtin);
    expect(
      real.nodeTypes.keys.toSet(),
      (builtin['node_types'] as Map).keys.toSet(),
    );
  });
}
