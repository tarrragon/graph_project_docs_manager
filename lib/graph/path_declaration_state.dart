/// 需求：[UC-02〈ticket 定位的五種狀態與整體未宣告〉、〈ticket 定位〉比對語意；
/// SPEC-006 FR-10 規則 2b、3、4] Graph 的 `where.files` 路徑比對器。
///
/// 輸入為各 DomainBundle 的 `path_patterns`（缺席 `null`／`[]`／清單三態）
/// 與 Corpus 公開面 [NonDomainPathsReadResult]；Graph 不直讀檔案，也不依賴
/// Diagnostics（系統層 §2）。不推測 `lib/<domain>/` 預設規則。
library;

import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';

/// 單一路徑的定位狀態（UC-02 五狀態）。
enum PathLocationState {
  /// 命中某 bundle 的 `path_patterns`。
  domainHit,

  /// 命中非 domain 清單。
  nonDomainLayer,

  /// 兩側皆已宣告但皆未命中；唯一計入 `unlocatable` 的狀態。
  unlocatable,

  /// 只有 domain 側完整宣告，未命中者。
  nonDomainUndeclared,

  /// domain 側未完整宣告（含非 domain 清單缺席且部分宣告），未命中者。
  domainUndeclared,
}

/// 非 domain 側的宣告狀態（供宣告狀態行區分「格式錯誤」與「缺席」）。
enum NonDomainSideState { absent, malformed, declared }

/// 逐路徑結果；[path] 為正規化後的路徑。
class PathClassification {
  const PathClassification({
    required this.path,
    required this.state,
    this.domains = const [],
  });

  final String path;
  final PathLocationState state;

  /// 宣告此路徑（最長前綴）的所有 bundle，依名稱排序；只有
  /// [PathLocationState.domainHit] 非空。等長多 bundle 宣告時全部列入
  /// （UC-02 v1.11 X1），受影響路徑數仍以路徑計。
  final List<String> domains;
}

/// 票列表摘要三值。兩側皆無宣告或票無路徑時為 [undetermined]，與
/// [notLocatable] 不同。
enum TicketLocatability { locatable, notLocatable, undetermined }

/// 一次比對的完整輸出，供 W1-119 消費。
///
/// 兩種粒度並存：[paths]、[affectedPathCount] 與其衍生 getter 是單票值
/// （[affectedPathCount] 在整體未宣告時為 `null`）；[nonDomainSide]、
/// [declaredBundleCount]、[totalBundleCount]、[overallUndeclared] 是語料層狀態，
/// 與傳入的 where.files 無關。
class PathDeclarationReport {
  PathDeclarationReport({
    required List<PathClassification> paths,
    required this.nonDomainSide,
    required this.overallUndeclared,
    required this.declaredBundleCount,
    required this.totalBundleCount,
  }) : paths = List<PathClassification>.unmodifiable(paths);

  /// 逐路徑狀態；整體未宣告時為空（不逐張判定）。
  final List<PathClassification> paths;

  final NonDomainSideState nonDomainSide;

  /// 兩側皆無：專案整體「未宣告路徑」。
  final bool overallUndeclared;

  /// `path_patterns` 已宣告的 bundle 數／bundle 總數。
  final int declaredBundleCount;
  final int totalBundleCount;

  /// 標為兩種「未宣告」的路徑數；整體未宣告時不提供（`null`）。
  int? get affectedPathCount => overallUndeclared
      ? null
      : paths
            .where(
              (p) =>
                  p.state == PathLocationState.nonDomainUndeclared ||
                  p.state == PathLocationState.domainUndeclared,
            )
            .length;

  /// 計入破洞報告 `unlocatable` 類的路徑數。
  int get unlocatableCount =>
      paths.where((p) => p.state == PathLocationState.unlocatable).length;

  /// 矩陣高亮：各路徑命中 domain 的聯集。
  Set<String> get highlightedDomains => {for (final p in paths) ...p.domains};

  /// 票列表摘要：任一路徑命中 domain 即可定位；兩側皆無宣告，或票的
  /// `where.files` 為空（沒有可判定的對象）時不判定（UC-02 v1.12）。
  TicketLocatability get locatability {
    if (overallUndeclared || paths.isEmpty) {
      return TicketLocatability.undetermined;
    }
    return paths.any((p) => p.state == PathLocationState.domainHit)
        ? TicketLocatability.locatable
        : TicketLocatability.notLocatable;
  }
}

/// 需求：[UC-02 ticket 定位] 逐路徑分類 [whereFiles]。
///
/// [bundlePathPatterns] 的值：`null` 為欄位缺席（未宣告）、`[]` 為已宣告且
/// 不收任何路徑。
PathDeclarationReport classifyTicketPaths({
  required Map<String, List<String>?> bundlePathPatterns,
  required NonDomainPathsReadResult nonDomain,
  required List<String> whereFiles,
}) {
  final declaredCount = bundlePathPatterns.values
      .where((v) => v != null)
      .length;
  final total = bundlePathPatterns.length;
  final nonDomainPatterns = nonDomain.declaration.declaredPatterns;
  final overall = declaredCount == 0 && nonDomainPatterns == null;
  final side = _sideStateOf(nonDomain);
  if (overall) {
    return PathDeclarationReport(
      paths: const [],
      nonDomainSide: side,
      overallUndeclared: true,
      declaredBundleCount: declaredCount,
      totalBundleCount: total,
    );
  }
  final fallback = _unmatchedState(
    // 零 bundle 不得空真：domain 側視為未宣告。
    allBundlesDeclared: total > 0 && declaredCount == total,
    nonDomainDeclared: nonDomainPatterns != null,
  );
  return PathDeclarationReport(
    paths: [
      for (final raw in whereFiles)
        _classifyOne(
          normalizeWhereFilesPath(raw),
          bundlePathPatterns,
          nonDomainPatterns,
          fallback,
        ),
    ],
    nonDomainSide: side,
    overallUndeclared: false,
    declaredBundleCount: declaredCount,
    totalBundleCount: total,
  );
}

/// 需求：[票面正規化] 只套用在 `where.files`：截除 `::` 起的後綴；
/// 最後一段無副檔名且無尾斜線者補 `/`。宣告值不經此函式。
String normalizeWhereFilesPath(String raw) {
  final cut = raw.indexOf('::');
  final path = cut < 0 ? raw : raw.substring(0, cut);
  if (path.isEmpty || path.endsWith('/')) return path;
  final lastSegment = path.substring(path.lastIndexOf('/') + 1);
  return lastSegment.contains('.') ? path : '$path/';
}

NonDomainSideState _sideStateOf(NonDomainPathsReadResult result) {
  return switch (result) {
    NonDomainPathsReadAbsent() => NonDomainSideState.absent,
    NonDomainPathsReadMalformed() => NonDomainSideState.malformed,
    NonDomainPathsReadDeclared() ||
    NonDomainPathsReadDeclaredWithBadElements() => NonDomainSideState.declared,
  };
}

PathLocationState _unmatchedState({
  required bool allBundlesDeclared,
  required bool nonDomainDeclared,
}) {
  if (allBundlesDeclared && nonDomainDeclared) {
    return PathLocationState.unlocatable;
  }
  if (allBundlesDeclared) return PathLocationState.nonDomainUndeclared;
  return PathLocationState.domainUndeclared;
}

PathClassification _classifyOne(
  String path,
  Map<String, List<String>?> bundles,
  List<String>? nonDomainPatterns,
  PathLocationState fallback,
) {
  final domains = <String>[];
  var domainLen = -1;
  for (final entry in bundles.entries) {
    final len = _longestMatch(path, entry.value);
    if (len > domainLen) {
      domainLen = len;
      domains.clear();
    }
    if (len >= 0 && len == domainLen) domains.add(entry.key);
  }
  domains.sort();
  final nonDomainLen = _longestMatch(path, nonDomainPatterns);
  // 等長時歸 domain（UC-02 v1.8 T1）；最長前綴優先。
  if (domainLen >= 0 && domainLen >= nonDomainLen) {
    return PathClassification(
      path: path,
      state: PathLocationState.domainHit,
      domains: List<String>.unmodifiable(domains),
    );
  }
  if (nonDomainLen >= 0) {
    return PathClassification(
      path: path,
      state: PathLocationState.nonDomainLayer,
    );
  }
  return PathClassification(path: path, state: fallback);
}

/// 命中的最長宣告值長度；無命中為 -1。
int _longestMatch(String path, List<String>? patterns) {
  var best = -1;
  for (final pattern in patterns ?? const <String>[]) {
    if (!_isMatchable(pattern) || !_matches(path, pattern)) continue;
    if (pattern.length > best) best = pattern.length;
  }
  return best;
}

/// 以 `/` 結尾為前綴比對，否則精確比對（C3′）。
bool _matches(String path, String pattern) =>
    pattern.endsWith('/') ? path.startsWith(pattern) : path == pattern;

final _globChars = RegExp(r'[*?\[\]{}]');

/// 上游判為格式違規的值不命中任何路徑：空字串、以 `/` 或 `./` 開頭、
/// 含 `..` 段、含 glob 字元。
bool _isMatchable(String pattern) {
  if (pattern.isEmpty || pattern.startsWith('/') || pattern.startsWith('./')) {
    return false;
  }
  if (pattern.split('/').contains('..')) return false;
  return !_globChars.hasMatch(pattern);
}
