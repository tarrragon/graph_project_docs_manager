/// 真實語料快照載入器（SPEC-001-test-design §1.5）。
///
/// 讀凍結快照，經真實 Corpus 掃描與 Graph 建圖，交出 flow 子圖。快照的 UC
/// 檔只含 flow 圍欄、無 frontmatter（MANIFEST 擷取規則），故實體化到暫存樹時
/// 依檔名前綴補最小 frontmatter（`id: UC-NN`）；其餘檔位元組原樣複製。
/// 合成 frontmatter 是刻意的：凍結快照依 MANIFEST 擷取規則只保留 flow 圍欄，
/// 不含 UC 的 frontmatter，真實 Corpus 沒有 `id` 就不會產生 UC 節點；補上的
/// 只有 `id`，不影響 flow 內容。
///
/// 外圈（IT-D1～IT-D4，0.5.0-W1-114.13）另用 [materializeSnapshotWorkspace]
/// 取得實體化後的工作區根目錄（可帶檔案轉換以構造宣告狀態變體），快照路徑
/// 經 [snapshotRoot] 解析：integration_test 的 .app 工作目錄不是 repo 根，
/// 故找不到 repo 根時明確失敗，不讀空目錄。
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

const _snapshotRelative = 'test/fixtures/spec001/corpus_snapshot';
const _schemaPath = '.claude/skills/doc/doc_system/core/tracking_schema.json';
final _ucFileName = RegExp(r'^(UC-\d+)');

/// 快照名：`graph_project_docs_manager` 或 `flutter_balance`。
Future<Map<String, FlowSubgraph>> loadSnapshotFlows(String snapshot) async =>
    (await loadSnapshotEvent(snapshot)).flowSubgraphs;

/// 同 [loadSnapshotFlows]，回傳整個 GraphBuilt 事件（含邊與缺陷）。
Future<GraphBuiltEvent> loadSnapshotEvent(String snapshot) async {
  final temp = await materializeSnapshotWorkspace(snapshot);
  try {
    return await _scanAndBuild(temp.path);
  } finally {
    await temp.delete(recursive: true);
  }
}

/// 解析快照根目錄：先試目前工作目錄，再由執行檔路徑往上找含快照目錄的祖先
/// （.app 位於 repo 的 build/ 下；本機、worktree、CI 皆適用）。找不到即拋
/// [StateError]，避免讀到空目錄後讓計數斷言以 0 筆恆真通過。
String snapshotRoot() {
  final starts = [Directory.current, File(Platform.resolvedExecutable).parent];
  for (final start in starts) {
    var dir = start.absolute;
    while (true) {
      final candidate = Directory('${dir.path}/$_snapshotRelative');
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError(
    // i18n-exempt: 測試診斷訊息
    '找不到快照根目錄 $_snapshotRelative：已從 ${Directory.current.path} 與 '
    '${Platform.resolvedExecutable} 往上尋找',
  );
}

/// 檔案內容轉換：取原內容回新內容。
typedef SnapshotTransform = String Function(String original);

/// 將 [snapshot] 實體化為暫存工作區並回傳根目錄；呼叫端負責刪除。
///
/// [transforms]：鍵為快照內相對路徑，在 UC 補 frontmatter 之後套用，用於構造
/// 宣告狀態變體；[extraFiles]：快照外新增的檔（相對路徑 → 內容）。
Future<Directory> materializeSnapshotWorkspace(
  String snapshot, {
  Map<String, SnapshotTransform> transforms = const {},
  Map<String, String> extraFiles = const {},
}) async {
  final source = Directory('${snapshotRoot()}/$snapshot');
  if (!source.existsSync()) {
    throw StateError('快照目錄不存在：${source.path}'); // i18n-exempt: 測試診斷訊息
  }
  final temp = await Directory.systemTemp.createTemp('spec001_workspace_');
  await _materialize(source, temp, transforms);
  for (final entry in extraFiles.entries) {
    final file = File('${temp.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return temp;
}

Future<void> _materialize(
  Directory source,
  Directory target,
  Map<String, SnapshotTransform> transforms,
) async {
  for (final entity in source.listSync(recursive: true)) {
    if (entity is! File || entity.path.endsWith('MANIFEST.md')) continue;
    final relative = entity.path.substring(source.path.length + 1);
    final copy = File('${target.path}/$relative');
    await copy.parent.create(recursive: true);
    final ucId = _ucFileName.firstMatch(entity.uri.pathSegments.last)?.group(1);
    final isUc = relative.startsWith('docs/usecases/') && ucId != null;
    final original = isUc
        ? '---\nid: $ucId\n---\n${entity.readAsStringSync()}'
        : entity.readAsStringSync();
    await copy.writeAsString(transforms[relative]?.call(original) ?? original);
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
