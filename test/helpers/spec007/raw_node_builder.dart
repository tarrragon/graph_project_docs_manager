import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';

/// 以 id、型別、路徑與額外 frontmatter 建 [RawNode]（SPEC-007 測試設計 §1.4）。
RawNode buildRawNode({
  required String id,
  String typeName = 'Ticket',
  String? path,
  Map<String, dynamic> extra = const {},
}) {
  return RawNode(
    path: path ?? 'docs/$id.md',
    frontmatter: {'id': id, ...extra},
    typeName: typeName,
  );
}
