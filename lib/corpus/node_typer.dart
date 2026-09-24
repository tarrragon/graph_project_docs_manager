/// 需求：[SPEC-006 FR-03] 節點判型 —— 以可用檔案的 `id` 比對型別表各型的
/// `id_pattern`，型別判別以 `id_pattern` 為準，不以 carrier 路徑為準
/// （`docs/domain-map.md` §7）。
library;

import 'package:graph_project_docs_manager/schema/type_table.dart';

/// 節點判型結果，二選一（FR-03 規則）：
/// - [NodeTypingMatch]：`id` 恰好命中一型，產生節點
/// - [NodeTypingNonNode]：不產生節點也不產生破洞——`id` 缺席、不命中任何
///   型別，或互斥保證被打破（一個 `id` 同時命中多型，標記 schema 歧義）
sealed class NodeTypingResult {
  const NodeTypingResult();
}

/// `id` 恰好命中一型。
class NodeTypingMatch extends NodeTypingResult {
  const NodeTypingMatch(this.typeName);

  /// 命中的型別名稱（如 `SPEC`、`DomainBundle`）。
  final String typeName;
}

/// 不產生節點：`id` 缺席、不命中任何型別、或互斥被打破。
class NodeTypingNonNode extends NodeTypingResult {
  const NodeTypingNonNode({
    this.schemaAmbiguous = false,
    this.candidateTypes = const <String>[],
  });

  /// true 代表互斥保證被打破——一個 `id` 同時命中多個型別的 `id_pattern`
  /// （上游 conformance 測試理應保證互斥，此為防禦性標記，FR-03 規則）。
  final bool schemaAmbiguous;

  /// [schemaAmbiguous] 為 true 時，全部命中的候選型別名稱（依名稱排序，
  /// 供 `CorpusScanResult` 的 FR-03 歧義清單使用，0.3.0-W3-534）；否則為
  /// 空清單。
  final List<String> candidateTypes;
}

/// 型別名稱與其 `id_pattern` 預先編譯出的 [RegExp]（0.3.0-W3-534）。
class _CompiledIdPattern {
  const _CompiledIdPattern(this.typeName, this.regex);

  final String typeName;
  final RegExp regex;
}

/// 依 [TypeTable] 物件身分快取已編譯的 `id_pattern`，同一次掃描重複呼叫
/// [classifyNodeType] 不再逐檔重新編譯（0.3.0-W3-534：判型改用預編譯
/// regex）。`Expando` 不阻止 [table] 被回收，快取生命週期與 [table] 相同。
final _compiledIdPatternsCache = Expando<List<_CompiledIdPattern>>(
  'node_typer.compiledIdPatterns',
);

List<_CompiledIdPattern> _compiledIdPatternsOf(TypeTable table) {
  final cached = _compiledIdPatternsCache[table];
  if (cached != null) {
    return cached;
  }
  final compiled = <_CompiledIdPattern>[
    for (final entry in table.nodeTypes.values)
      if (entry.idPattern != null)
        _CompiledIdPattern(entry.name, RegExp(entry.idPattern!)),
  ];
  _compiledIdPatternsCache[table] = compiled;
  return compiled;
}

/// 需求：[SPEC-006 FR-03] 以 frontmatter 的 `id` 比對型別表各型的
/// `id_pattern`，判定這份可用檔案是否為節點、屬於哪個型別。
///
/// 只用於結果為「可用」的檔案（FR-01）；沒拿到可用 frontmatter 的檔案改走
/// FR-06 的路徑對型別查詢（見 `lib/schema/carrier_path_lookup.dart`）。
NodeTypingResult classifyNodeType(
  TypeTable table,
  Map<String, dynamic> frontmatter,
) {
  final id = frontmatter['id'];
  if (id is! String) {
    return const NodeTypingNonNode();
  }

  final matchedTypeNames = <String>[
    for (final compiled in _compiledIdPatternsOf(table))
      if (compiled.regex.hasMatch(id)) compiled.typeName,
  ];

  if (matchedTypeNames.isEmpty) {
    return const NodeTypingNonNode();
  }
  if (matchedTypeNames.length == 1) {
    return NodeTypingMatch(matchedTypeNames.single);
  }
  matchedTypeNames.sort();
  return NodeTypingNonNode(
    schemaAmbiguous: true,
    candidateTypes: matchedTypeNames,
  );
}
