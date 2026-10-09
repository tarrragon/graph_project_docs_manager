/// 需求：[SPEC-007-test-design.md §1.4／§2.2.2〈實體化流程〉] IT-1～IT-3 共用
/// helper：解析凍結 manifest、每個語料實體化一棵暫存樹、經真實 Corpus 掃描與
/// 建圖。測試不得把 manifest 直接餵給 Graph。
library;

import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

const _fixtureDir = 'test/fixtures/spec007';

/// 讀 `test/fixtures/spec007/<name>.json`。
Map<String, dynamic> loadSpec007Fixture(String name) =>
    jsonDecode(File('$_fixtureDir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// 讀內建型別表 asset。
Map<String, dynamic> loadBuiltinSchema() => jsonDecode(
  File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
) as Map<String, dynamic>;

/// 深拷貝（型別表變體用，避免共享 mutable 狀態）。
Map<String, dynamic> deepCopyJson(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

/// manifest 的一列。
class ManifestNodeRow {
  ManifestNodeRow({
    required this.corpus,
    required this.host,
    required this.path,
    required this.id,
    required this.status,
    required this.title,
    required this.edgeFields,
    required this.synthetic,
    required this.covers,
  });

  factory ManifestNodeRow.fromJson(Map<String, dynamic> json) {
    final synthetic = json['synthetic'] as bool;
    final corpus = json['corpus'] as String;
    return ManifestNodeRow(
      corpus: corpus,
      host: synthetic ? json['synthetic_host'] as String : corpus,
      path: json['path'] as String,
      id: json['id'] as String,
      status: json['status'],
      title: json['title'],
      edgeFields: Map<String, dynamic>.from(json['edge_fields'] as Map),
      synthetic: synthetic,
      covers: (json['covers'] as List).cast<String>(),
    );
  }

  final String corpus;

  /// 實體化目標樹（合成列取 `synthetic_host`）。
  final String host;
  final String path;
  final String id;
  final Object? status;
  final Object? title;
  final Map<String, dynamic> edgeFields;
  final bool synthetic;
  final List<String> covers;
}

/// 讀 manifest 全部列。
List<ManifestNodeRow> loadManifestRows() => [
  for (final r in loadSpec007Fixture('graph_manifest')['rows'] as List)
    ManifestNodeRow.fromJson(r as Map<String, dynamic>),
];

/// 依實體化目標樹分組（`host`）。
Map<String, List<ManifestNodeRow>> groupByHost(List<ManifestNodeRow> rows) {
  final result = <String, List<ManifestNodeRow>>{};
  for (final row in rows) {
    result.putIfAbsent(row.host, () => []).add(row);
  }
  return result;
}

/// §2.2.1 全部 `covers` 類別。
const requiredCoverCategories = <String>{
  'related_one_side',
  'related_both_sides',
  'spawn_reverse_only',
  'spawn_multi_source',
  'provenance_multi_source',
  'dangling',
  'malformed_pattern',
  'duplicate_id',
  'self_reference',
  'invalid_shape',
  'target_duplicated',
  'outputs_non_list_subkey',
  'null_in_list',
  'non_string_status_title',
};

/// 覆蓋檢查器：回傳缺漏類別（空集合代表齊全）。
Set<String> findMissingCoverage(List<ManifestNodeRow> rows) =>
    {...requiredCoverCategories}
      ..removeAll({for (final r in rows) ...r.covers});

/// 實體化器拒絕的值型別（不略過）。
class UnserializableFrontmatterValue extends ArgumentError {
  UnserializableFrontmatterValue(String key, Object value)
    // i18n-exempt: 測試診斷訊息
    : super('欄位 $key 含無法序列化的值型別：${value.runtimeType}');
}

Object? _checked(String key, Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is List) return [for (final v in value) _checked(key, v)];
  if (value is Map) {
    return {for (final e in value.entries) '${e.key}': _checked(key, e.value)};
  }
  throw UnserializableFrontmatterValue(key, value);
}

/// 一列的最小 frontmatter：`id`、`status`／`title`（非 null 才寫）、邊欄位。
Map<String, dynamic> minimalFrontmatter(ManifestNodeRow row) => {
  'id': row.id,
  'status': ?row.status,
  'title': ?row.title,
  ...row.edgeFields,
};

/// 序列化為 frontmatter 檔文字；JSON 值是合法 YAML flow 值，保留型別、
/// null、空字串與巢狀 map。遇未知值型別拋 [UnserializableFrontmatterValue]。
String serializeFrontmatter(Map<String, dynamic> frontmatter) {
  final buffer = StringBuffer('---\n');
  for (final entry in frontmatter.entries) {
    final encoded = jsonEncode(_checked(entry.key, entry.value));
    buffer.writeln('${entry.key}: $encoded');
  }
  buffer.write('---\n');
  return buffer.toString();
}

/// 把 [rows] 寫成 [root] 底下的檔案樹；[overrides]（key 為 path）以完整
/// frontmatter 覆寫同一路徑（每個路徑最終只有一份檔案）。
Future<void> materializeRows({
  required List<ManifestNodeRow> rows,
  required Directory root,
  Map<String, Map<String, dynamic>> overrides = const {},
}) async {
  for (final row in rows) {
    final text = serializeFrontmatter(
      overrides[row.path] ?? minimalFrontmatter(row),
    );
    final file = File('${root.path}/${row.path}');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }
}

/// 一個語料一輪掃描與建圖的結果。
class CorpusGraphRun {
  CorpusGraphRun({
    required this.rawNodes,
    required this.buildResult,
    required this.logs,
  });

  final List<RawNode> rawNodes;
  final GraphBuildResult buildResult;
  final List<({GraphLogEvent event, Map<String, Object?> payload})> logs;

  GraphBuiltEvent get event => (buildResult as GraphBuildAvailable).event;
}

/// 建暫存樹 → 真實 Corpus 掃描 → 建圖（型別表 [schemaJson] 缺省為凍結表）。
Future<CorpusGraphRun> scanAndBuild({
  required List<ManifestNodeRow> rows,
  Map<String, Map<String, dynamic>> overrides = const {},
  Map<String, dynamic>? schemaJson,
}) async {
  final root = await Directory.systemTemp.createTemp('spec007_it_');
  try {
    await materializeRows(rows: rows, root: root, overrides: overrides);
    final typeTable = typeTableFromJson(loadSpec007Fixture('type_table'));
    final scan = await scanCorpus(
      fileSystem: DefaultDocsFileSystem(root.path),
      table: typeTable,
      builtinTable: typeTable,
    );
    return buildFromRawNodes(scan.rawNodes, schemaJson: schemaJson);
  } finally {
    await root.delete(recursive: true);
  }
}

/// 以既有 rawNodes 建圖並記錄日誌（型別表變體用）。
CorpusGraphRun buildFromRawNodes(
  List<RawNode> rawNodes, {
  Map<String, dynamic>? schemaJson,
}) {
  final logs = <({GraphLogEvent event, Map<String, Object?> payload})>[];
  final result = buildGraph(
    rawNodes: rawNodes,
    projectSchemaJson: schemaJson ?? loadSpec007Fixture('type_table'),
    builtinSchemaJson: loadBuiltinSchema(),
    logSink: (message, {required event, required payload, level}) =>
        logs.add((event: event, payload: payload)),
  );
  return CorpusGraphRun(rawNodes: rawNodes, buildResult: result, logs: logs);
}

/// 邊的比對鍵：`type|from|to|宣告來源（排序後逗號串接）`。
String edgeKeyOf(String type, String from, String to, Iterable<String> by) =>
    '$type|$from|$to|${(by.toList()..sort()).join(',')}';

/// 待測圖的邊鍵。
List<String> builtEdgeKeys(GraphBuiltEvent event) => [
  for (final e in event.edges)
    edgeKeyOf(e.edgeType, e.from, e.to, e.declaredBy),
];

/// 凍結的邊鍵（某語料）。
List<String> expectedEdgeKeys(String host) => [
  for (final e
      in (loadSpec007Fixture('expected_edges')['corpora'][host] as List))
    edgeKeyOf(
      e['edge_type'] as String,
      e['from'] as String,
      e['to'] as String,
      (e['declared_by'] as List).cast<String>(),
    ),
];

/// 雙向差集說明（空字串代表相等）。
String diffReport(Iterable<String> actual, Iterable<String> expected) {
  final a = actual.toList();
  final e = expected.toList();
  final extra = _multisetMinus(a, e);
  final missing = _multisetMinus(e, a);
  if (extra.isEmpty && missing.isEmpty) return '';
  // i18n-exempt: 測試診斷訊息
  return '多出 ${extra.length}：${extra.take(20).toList()}\n'
      // i18n-exempt: 測試診斷訊息
      '缺少 ${missing.length}：${missing.take(20).toList()}';
}

List<String> _multisetMinus(List<String> left, List<String> right) {
  final counts = <String, int>{};
  for (final r in right) {
    counts[r] = (counts[r] ?? 0) + 1;
  }
  final result = <String>[];
  for (final l in left) {
    final c = counts[l] ?? 0;
    if (c > 0) {
      counts[l] = c - 1;
    } else {
      result.add(l);
    }
  }
  return result;
}
