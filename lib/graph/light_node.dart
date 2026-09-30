/// SPEC-007 FR-02 輕節點：圖只持有建圖需要的欄位（見 [LightNode]），不保留 frontmatter。
///
/// 依賴方向：Graph domain，只 import Corpus 的事件型別（`RawNode`）。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';

/// 輕節點：`id`、節點型別、`status`、`title`（非字串為 null）、相對路徑。
class LightNode {
  const LightNode({
    required this.id,
    required this.typeName,
    required this.status,
    required this.title,
    required this.path,
  });

  final String id;
  final String typeName;
  final String? status;
  final String? title;
  final String path;
}

/// 一筆 `duplicateId` 缺陷：同一 `id` 出現在兩個以上 rawNode。
class DuplicateIdDefect {
  const DuplicateIdDefect({required this.id, required this.paths});

  final String id;
  final List<String> paths;
}

/// 輕節點建構結果。
class LightNodeBuild {
  const LightNodeBuild({required this.nodes, required this.duplicates});

  final List<LightNode> nodes;
  final List<DuplicateIdDefect> duplicates;

  /// 重複 ID 集合（FR-03 分類為 `targetDuplicated` 的依據）。
  Set<String> get duplicateIds => {for (final d in duplicates) d.id};
}

/// 需求：[SPEC-007 FR-02] 重複 ID 的節點全數不建，回報一筆 `duplicateId`。
LightNodeBuild buildLightNodes(List<RawNode> rawNodes) {
  final byId = <String, List<RawNode>>{};
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (id is String) {
      byId.putIfAbsent(id, () => []).add(raw);
    }
  }
  final nodes = <LightNode>[];
  final duplicates = <DuplicateIdDefect>[];
  for (final entry in byId.entries) {
    if (entry.value.length == 1) {
      nodes.add(_toLightNode(entry.key, entry.value.single));
    } else {
      duplicates.add(
        DuplicateIdDefect(
          id: entry.key,
          paths: [for (final raw in entry.value) raw.path],
        ),
      );
    }
  }
  return LightNodeBuild(nodes: nodes, duplicates: duplicates);
}

LightNode _toLightNode(String id, RawNode raw) {
  final status = raw.frontmatter['status'];
  final title = raw.frontmatter['title'];
  return LightNode(
    id: id,
    typeName: raw.typeName,
    status: status is String ? status : null,
    title: title is String ? title : null,
    path: raw.path,
  );
}
