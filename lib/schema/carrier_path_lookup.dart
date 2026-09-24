/// FR-06 路徑對型別查詢（SPEC-006 §「FR-06：路徑對型別查詢」規則 1～6）。
library;

import 'package:graph_project_docs_manager/schema/type_table.dart';

/// 路徑對型別查詢的結果。三選一，窮舉區分（規則 5、S3-4）：
/// - [CarrierPathNoMatch]：未命中任何型別
/// - [CarrierPathSingleMatch]：命中恰好一型
/// - [CarrierPathTie]：多個型別同時命中且具體度打平（schema 歧義）
sealed class CarrierPathLookupResult {
  const CarrierPathLookupResult();
}

/// 未命中任何型別。
class CarrierPathNoMatch extends CarrierPathLookupResult {
  const CarrierPathNoMatch();
}

/// 命中恰好一型。
class CarrierPathSingleMatch extends CarrierPathLookupResult {
  const CarrierPathSingleMatch(this.typeName);

  final String typeName;
}

/// 具體度打平，多個候選型別（schema 歧義，規則 5、6）。
class CarrierPathTie extends CarrierPathLookupResult {
  CarrierPathTie(Iterable<String> candidateTypeNames)
      : candidateTypeNames = List.unmodifiable(
          [...candidateTypeNames]..sort(),
        );

  /// 依名稱排序，確保結果穩定（實際順序不影響語意，僅供測試比對）。
  final List<String> candidateTypeNames;
}

/// 給一個相對路徑，回傳它命中的節點型別（FR-06）。
///
/// 只用於沒拿到可用 frontmatter 的檔案；有可用 frontmatter 的檔案依
/// FR-03 以 `id_pattern` 判型，不經本查詢。
CarrierPathLookupResult lookupCarrierPathType(TypeTable table, String path) {
  final matches = <MapEntry<String, PathSpecificity>>[];
  for (final entry in table.pathParticipatingTypes) {
    final best = _bestSpecificityFor(entry, path);
    if (best != null) {
      matches.add(MapEntry(entry.name, best));
    }
  }

  if (matches.isEmpty) {
    return const CarrierPathNoMatch();
  }

  // 排序依規則 6，比較邏輯統一由 comparePathSpecificity 提供。
  matches.sort((a, b) => comparePathSpecificity(a.value, b.value));

  final top = matches.first.value;
  final winners = matches
      .where((m) => comparePathSpecificity(m.value, top) == 0)
      .map((m) => m.key)
      .toList(growable: false);

  if (winners.length == 1) {
    return CarrierPathSingleMatch(winners.single);
  }
  return CarrierPathTie(winners);
}

/// 一個型別可能有多個路徑模式元素，取其中命中路徑且具體度最高者
/// （規則 6 附註：「以該型命中元素中最高的具體度參與比較」，S2-4）。
PathSpecificity? _bestSpecificityFor(NodeTypeEntry entry, String path) {
  PathSpecificity? best;
  for (final candidate in entry.carrierPathPatterns ?? const <CarrierPathPattern>[]) {
    if (!candidate.toRegExp().hasMatch(path)) {
      continue;
    }
    if (best == null || comparePathSpecificity(candidate.specificity, best) < 0) {
      best = candidate.specificity;
    }
  }
  return best;
}
