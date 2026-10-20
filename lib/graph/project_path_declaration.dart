/// 需求：[SPEC-001 §5〈專案層級宣告狀態一行〉；UC-02〈ticket 定位的五種狀態與
/// 整體未宣告〉；0.5.0-W1-119.2] Graph 的專案層宣告彙整。
///
/// 輸入為掃描輪次的原始節點與 Corpus 公開的非 domain 清單讀取結果；逐票
/// 比對交 [classifyTicketPaths]，本檔只做專案層加總。報告頁只消費本檔結果，
/// 不在畫面或 Diagnostics 計算（SPEC-001 §5「受影響路徑數來源」）。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';

import 'domain_name_resolver.dart';
import 'path_declaration_state.dart';

const _ticketTypeName = 'Ticket';
const _pathPatternsField = 'path_patterns';

/// 專案層宣告狀態（供報告頁宣告狀態行）。
class ProjectPathDeclaration {
  const ProjectPathDeclaration({
    required this.declaredBundleCount,
    required this.totalBundleCount,
    required this.nonDomainSide,
    required this.overallUndeclared,
    this.affectedPathCount,
  });

  /// `path_patterns` 已宣告的 DomainBundle 數／DomainBundle 總數。
  final int declaredBundleCount;
  final int totalBundleCount;

  final NonDomainSideState nonDomainSide;

  /// 兩側皆無：整體「未宣告路徑」。
  final bool overallUndeclared;

  /// 各票受影響路徑數加總；整體未宣告時為 `null`（P3-4：不顯示路徑數）。
  final int? affectedPathCount;

  /// domain 側完整宣告：至少一個 bundle 且全數已宣告（零 bundle 不空真，
  /// 與比對器一致）。
  bool get isBundleSideComplete =>
      totalBundleCount > 0 && declaredBundleCount == totalBundleCount;

  /// 任何一側有宣告缺口（含整體未宣告）；兩側完整宣告時為 `false`。
  bool get hasGap =>
      overallUndeclared ||
      !isBundleSideComplete ||
      nonDomainSide != NonDomainSideState.declared;
}

/// 需求：[SPEC-001 §5、UC-02] 彙整專案層宣告狀態。
///
/// 每張 Ticket（`typeName == 'Ticket'`）的 `where.files` 經 [classifyTicketPaths]
/// 比對，受影響路徑數（標為兩種「未宣告」者）逐票加總；非字串元素略過。
ProjectPathDeclaration summarizeProjectPathDeclaration({
  required List<RawNode> rawNodes,
  required NonDomainPathsReadResult nonDomain,
}) {
  final bundles = _bundlePathPatterns(rawNodes);
  final tickets = [
    for (final raw in rawNodes)
      if (raw.typeName == _ticketTypeName) _whereFilesOf(raw),
  ];
  final reports = [
    for (final files in tickets)
      classifyTicketPaths(
        bundlePathPatterns: bundles,
        nonDomain: nonDomain,
        whereFiles: files,
      ),
  ];
  final base = classifyTicketPaths(
    bundlePathPatterns: bundles,
    nonDomain: nonDomain,
    whereFiles: const [],
  );
  return ProjectPathDeclaration(
    declaredBundleCount: base.declaredBundleCount,
    totalBundleCount: base.totalBundleCount,
    nonDomainSide: base.nonDomainSide,
    overallUndeclared: base.overallUndeclared,
    affectedPathCount: base.overallUndeclared
        ? null
        : reports.fold<int>(0, (sum, r) => sum + (r.affectedPathCount ?? 0)),
  );
}

/// DomainBundle 的 `path_patterns`：欄位缺席或值不是清單為 `null`（未宣告），
/// 清單內非字串元素略過。以節點 `id`（缺則路徑）為鍵。
Map<String, List<String>?> _bundlePathPatterns(List<RawNode> rawNodes) => {
  for (final raw in rawNodes)
    if (raw.typeName == domainBundleTypeName)
      _bundleKey(raw): switch (raw.frontmatter[_pathPatternsField]) {
        final List<dynamic> list => list.whereType<String>().toList(),
        _ => null,
      },
};

String _bundleKey(RawNode raw) {
  final id = raw.frontmatter['id'];
  return id is String ? id : raw.path;
}

List<String> _whereFilesOf(RawNode ticket) {
  final where = ticket.frontmatter['where'];
  if (where is! Map) return const [];
  final files = where['files'];
  if (files is! List) return const [];
  return files.whereType<String>().toList();
}
