/// 真實語料快照載入器（最小版，供 Layout L3～L9 錨點使用）。
///
/// 讀凍結快照，經真實 Corpus 掃描與 Graph 建圖，交出 flow 子圖。快照的 UC
/// 檔只含 flow 圍欄、無 frontmatter（MANIFEST 擷取規則），故實體化到暫存樹時
/// 依檔名前綴補最小 frontmatter（`id: UC-NN`）；其餘檔位元組原樣複製。
/// 合成 frontmatter 是刻意的：凍結快照依 MANIFEST 擷取規則只保留 flow 圍欄，
/// 不含 UC 的 frontmatter，真實 Corpus 沒有 `id` 就不會產生 UC 節點；補上的
/// 只有 `id`，不影響 flow 內容。
/// 外圈載入器（IT-D1～IT-D3）屬 0.5.0-W1-114.13，不在此範圍。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

const _snapshotRoot = 'test/fixtures/spec001/corpus_snapshot';
const _schemaPath = '.claude/skills/doc/doc_system/core/tracking_schema.json';
final _ucFileName = RegExp(r'^(UC-\d+)');

/// 快照名：`graph_project_docs_manager` 或 `flutter_balance`。
Future<Map<String, FlowSubgraph>> loadSnapshotFlows(String snapshot) async =>
    (await loadSnapshotEvent(snapshot)).flowSubgraphs;

/// 同 [loadSnapshotFlows]，回傳整個 GraphBuilt 事件（含邊與缺陷）。
Future<GraphBuiltEvent> loadSnapshotEvent(String snapshot) async {
  final temp = await Directory.systemTemp.createTemp('spec001_snapshot_');
  try {
    final source = Directory('$_snapshotRoot/$snapshot');
    await _materialize(source, temp);
    return await _scanAndBuild(temp.path);
  } finally {
    await temp.delete(recursive: true);
  }
}

Future<void> _materialize(Directory source, Directory target) async {
  for (final entity in source.listSync(recursive: true)) {
    if (entity is! File || entity.path.endsWith('MANIFEST.md')) continue;
    final relative = entity.path.substring(source.path.length + 1);
    final copy = File('${target.path}/$relative');
    await copy.parent.create(recursive: true);
    final ucId = _ucFileName.firstMatch(entity.uri.pathSegments.last)?.group(1);
    final isUc = relative.startsWith('docs/usecases/') && ucId != null;
    await copy.writeAsString(
      isUc
          ? '---\nid: $ucId\n---\n${entity.readAsStringSync()}'
          : entity.readAsStringSync(),
    );
  }
}

Future<GraphBuiltEvent> _scanAndBuild(String root) async {
  final schemaJson = jsonDecode(
    File('$root/$_schemaPath').readAsStringSync(),
  ) as Map<String, dynamic>;
  final table = typeTableFromJson(schemaJson);
  final scan = await scanCorpus(
    fileSystem: DefaultDocsFileSystem(root),
    table: table,
    builtinTable: table,
  );
  final result = buildGraph(
    rawNodes: scan.rawNodes,
    projectSchemaJson: schemaJson,
    builtinSchemaJson: schemaJson,
  );
  expect(
    result,
    isA<GraphBuildAvailable>(),
    // i18n-exempt: 測試診斷訊息
    reason: '建圖不可用：${result is GraphBuildUnavailable ? result.reason : result}',
  );
  return (result as GraphBuildAvailable).event;
}
