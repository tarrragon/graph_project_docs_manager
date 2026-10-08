/// 路徑宣告建構器（SPEC-001-test-design.md §1.5）。
///
/// 宣告各 bundle 的 `path_patterns`（缺席／`[]`／清單）與非 domain 清單
/// 狀態（有／無／格式錯誤），供 P1～P4 各自獨立建構 fixture。
library;

import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';

/// [declared] 為已宣告 bundle（值可為 `[]`），[absent] 為欄位缺席的 bundle。
Map<String, List<String>?> buildBundlePathPatterns({
  Map<String, List<String>> declared = const {},
  List<String> absent = const [],
}) => {...declared, for (final name in absent) name: null};

/// 非 domain 清單：缺席。
NonDomainPathsReadResult nonDomainAbsent() => const NonDomainPathsReadAbsent();

/// 非 domain 清單：已宣告（可為 `[]`）。
NonDomainPathsReadResult nonDomainDeclared(List<String> patterns) =>
    NonDomainPathsReadDeclared(patterns);

/// 非 domain 清單：整份格式錯誤。
NonDomainPathsReadResult nonDomainMalformed() => NonDomainPathsReadMalformed(
  path: 'docs/non-domain-paths.yaml',
  reason: NonDomainPathsWholeFileReason.yamlInvalid,
);
