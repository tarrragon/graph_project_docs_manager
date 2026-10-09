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
    final expected =
        builtinEdges.entries
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
    expect(result.unavailableReason, isNull);
    expect(result.unavailableReason, isNull);
  });

  test('S6-6 缺 edge_types、版本低於內建：同 S6-5', () {
    final result = _resolve(buildEdgeTableJson(version: '0.0.1'));
    expect(_keys(result), builtinEdges.keys.toSet());
    expect(result.unavailableReason, isNull);
  });

  test('S6-7 守衛：缺 edge_types、版本高於內建 -> 不可用（對照 S6-5）', () {
    final result = _resolve(buildEdgeTableJson(version: '999.0.0'));
    expect(result.unavailableReason, isNotNull);
    expect(
      result.unavailableReason,
      EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
    );
    final positive = _resolve(buildEdgeTableJson(version: builtinVersion));
    expect(positive.unavailableReason, isNull);
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
    expect(high.unavailableReason, isNotNull);
    expect(
      high.unavailableReason,
      EdgeTypeUnavailableReason.missingForwardCardinality,
    );
    final equal = _resolve(table(builtinVersion));
    expect(equal.unavailableReason, isNull);
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

  test('S6-11 守衛：型別表整份缺席（null）-> 不可用（對照 S6-12）', () {
    final result = _resolve(null);
    expect(result.unavailableReason, isNotNull);
    expect(
      result.unavailableReason,
      EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
    );
    expect(result.edgeTypes, isEmpty);
    expect(_resolve(builtin).unavailableReason, isNull);
  });

  test('S6-12 降級模式：內建表 asset 作為專案表傳入 -> 可用', () {
    final result = _resolve(builtin);
    final expected =
        builtinEdges.entries
            .where((e) => (e.value as Map)['layer'] == 'established')
            .map((e) => e.key)
            .toSet()
          ..remove('domain_dependency');
    expect(result.unavailableReason, isNull);
    expect(result.activeEdgeTypes.map((e) => e.name).toSet(), expected);
    expect(expected, isNotEmpty);
  });

  // 0.4.0-W4-004：壞邊型條目拒收，不擴散到整張型別表。
  // 專案內無 developer.log 攔截做法，故不斷言日誌，只斷言不拋例外與拒收結果。
  Map<String, dynamic> tableWithBad(dynamic badEntry) {
    final table = buildEdgeTableJson(
      version: builtinVersion,
      edges: {'liveEdge': const EdgeSpec(forwardField: 'l')},
    );
    (table['edge_types'] as Map<String, dynamic>)['badEdge'] = badEntry;
    return table;
  }

  Map<String, dynamic> validEdge() =>
      const EdgeSpec(forwardField: 'x').toJson();

  final badCases = <String, dynamic>{
    'A 邊型值為字串': 'oops',
    'B forward_field 為數字': validEdge()..['forward_field'] = 1,
    'C1 class 為數字': validEdge()..['class'] = 1,
    'C2 layer 為數字': validEdge()..['layer'] = 1,
    'D reverse_field 為數字': validEdge()..['reverse_field'] = 1,
  };

  for (final entry in badCases.entries) {
    test('W4-004 ${entry.key}：拒收該邊型，其餘保留，node_types 不受影響', () {
      final table = tableWithBad(entry.value);
      final decoded = typeTableFromJson(table);
      expect(decoded.edgeTypes!.keys, ['liveEdge']);
      final baseline = typeTableFromJson(
        buildEdgeTableJson(
          version: builtinVersion,
          edges: {'liveEdge': const EdgeSpec(forwardField: 'l')},
        ),
      );
      expect(decoded.nodeTypes.keys, baseline.nodeTypes.keys);
      expect(
        decoded.nodeTypes['SPEC']!.idPattern,
        baseline.nodeTypes['SPEC']!.idPattern,
      );
    });
  }

  // 0.4.0-W4-016：SPEC-007 v1.7～v1.9 FR-01，被拒收的邊型視同缺席。
  Map<String, dynamic> tableWithBadAssociation(
    String version, {
    Map<String, EdgeSpec> extra = const {},
  }) {
    final table = buildEdgeTableJson(version: version, edges: extra);
    (table['edge_types'] as Map<String, dynamic>)['association'] = 'oops';
    return table;
  }

  test('W4-016 壞邊型、版本等於內建：取內建表定義，建圖可用', () {
    final result = _resolve(tableWithBadAssociation(builtinVersion));
    expect(result.unavailableReason, isNull);
    final raw = builtinEdges['association'] as Map<String, dynamic>;
    final edge = result.edgeTypes['association']!;
    expect(edge.forwardField, raw['forward_field']);
    expect(edge.edgeClass, raw['class']);
    expect(edge.layer, raw['layer']);
    expect(edge.forwardCardinality.name, raw['forward_cardinality']);
  });

  test('W4-016 壞邊型、版本高於內建：不可用且為 invalidEdgeTypeEntry，node_types 照常', () {
    final table = tableWithBadAssociation('999.0.0');
    final result = _resolve(table);
    expect(result.unavailableReason, isNotNull);
    expect(
      result.unavailableReason,
      EdgeTypeUnavailableReason.invalidEdgeTypeEntry,
    );
    final decoded = typeTableFromJson(table);
    expect(decoded.nodeTypes.keys, ['SPEC']);
    expect(decoded.nodeTypes['SPEC']!.idPattern, r'^SPEC-\d+$');
  });

  test('W4-016 正向對照：去掉壞條目、版本高於內建 -> 可用', () {
    final table = buildEdgeTableJson(
      version: '999.0.0',
      edges: {
        'association': const EdgeSpec(
          forwardField: 'relatedTo',
          direction: 'undirected',
        ),
      },
    );
    expect(_resolve(table).unavailableReason, isNull);
  });

  test('W4-016 並存壞條目與缺正向基數、版本高於內建：只回報 invalidEdgeTypeEntry', () {
    final table = tableWithBadAssociation(
      '999.0.0',
      extra: {
        'custom': const EdgeSpec(forwardField: 'f', forwardCardinality: null),
      },
    );
    expect(
      _resolve(table).unavailableReason,
      EdgeTypeUnavailableReason.invalidEdgeTypeEntry,
    );
  });

  // 0.4.0-W4-017：SPEC-007 v1.10 FR-01，版本在已知範圍內、被拒收且內建表
  // 也沒有該鍵名：不建邊、建圖可用。日誌不斷言（同 W4-004 註記）。
  test('W4-017 壞邊型、版本等於內建、內建表無此鍵名：不建邊，建圖可用', () {
    const unknownKey = 'notInBuiltin';
    expect(builtinEdges.containsKey(unknownKey), isFalse);
    final table = buildEdgeTableJson(
      version: builtinVersion,
      edges: {'liveEdge': const EdgeSpec(forwardField: 'l')},
    );
    (table['edge_types'] as Map<String, dynamic>)[unknownKey] = 'oops';
    final result = _resolve(table);
    expect(result.unavailableReason, isNull);
    expect(result.unavailableReason, isNull);
    expect(result.edgeTypes.containsKey(unknownKey), isFalse);
    expect(result.edgeTypes.containsKey('liveEdge'), isTrue);
  });

  for (final card in <dynamic>[1, 'weird']) {
    test('W4-004 F forward_cardinality=$card 保留為 null，不拒收', () {
      final table = tableWithBad(validEdge()..['forward_cardinality'] = card);
      final edge = typeTableFromJson(table).edgeTypes!['badEdge']!;
      expect(edge.forwardCardinality, isNull);
    });
  }
}
