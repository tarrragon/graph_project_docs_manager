/// SPEC-007 FR-11 domain 名稱解析器：以 DomainBundle 的 `domain` 欄建名稱索引。
///
/// 不綁 FlowStep 型別：輸入是名稱字串、輸出是 DomainBundle 節點 ID 或未宣告，
/// 日後 `depends_on_domains` 建邊接同一解析器。本檔不依賴其他 graph 模組。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart'
    show flowKeyOf;

/// DomainBundle 的節點型別名（型別表節點型別名）。
const domainBundleTypeName = 'DomainBundle';

/// DomainBundle 宣告 domain 名稱的 frontmatter 欄位。
const domainBundleDomainField = 'domain';

/// 兩個以上 DomainBundle 宣告相同 `domain`（FR-11〈重複 domain 宣告〉）。
class DuplicateDomainDeclaration {
  DuplicateDomainDeclaration({
    required this.domain,
    required List<String> bundleIds,
  }) : bundleIds = List.unmodifiable(bundleIds);

  final String domain;

  /// 衝突的 DomainBundle ID，依輸入順序。
  final List<String> bundleIds;
}

/// 名稱索引：精確比對（區分大小寫、不去空白、不正規化），不以 ID 拼接代替查詢。
class DomainNameResolver {
  DomainNameResolver._(this._byName, this._byBundleId, this.duplicates);

  /// 無任何 DomainBundle 的索引（所有名稱皆未宣告）。
  factory DomainNameResolver.empty() =>
      DomainNameResolver._(const {}, const {}, const []);

  /// 由 (DomainBundle 節點 ID, `domain` 原值) 建索引；`domain` 非字串者不入索引。
  factory DomainNameResolver.fromDeclarations(
    Iterable<(String id, Object? domain)> declarations,
  ) {
    final idsByDomain = <String, List<String>>{};
    final byBundleId = <String, String>{};
    for (final (id, domain) in declarations) {
      // 空字串不是名稱：不入索引，`traverses: ['']` 必為未宣告。
      if (domain is! String || domain.isEmpty) continue;
      idsByDomain.putIfAbsent(domain, () => []).add(id);
      byBundleId[id] = domain;
    }
    return DomainNameResolver._(
      {
        for (final e in idsByDomain.entries)
          if (e.value.length == 1) e.key: e.value.single,
      },
      Map.unmodifiable(byBundleId),
      List.unmodifiable([
        for (final e in idsByDomain.entries)
          if (e.value.length >= 2)
            DuplicateDomainDeclaration(domain: e.key, bundleIds: e.value),
      ]),
    );
  }

  /// 由 rawNode 清單建索引；只取 [bundleIds] 內（已進圖、非重複 ID）的 DomainBundle。
  factory DomainNameResolver.fromRawNodes(
    List<RawNode> rawNodes,
    Set<String> bundleIds,
  ) => DomainNameResolver.fromDeclarations([
    for (final raw in rawNodes)
      if (raw.typeName == domainBundleTypeName &&
          raw.frontmatter['id'] is String &&
          bundleIds.contains(raw.frontmatter['id']))
        (
          raw.frontmatter['id']! as String,
          raw.frontmatter[domainBundleDomainField],
        ),
  ]);

  final Map<String, String> _byName;
  final Map<String, String> _byBundleId;

  /// 重複宣告（每個重複的 `domain` 值一筆）；這些 DomainBundle 不在正向索引。
  final List<DuplicateDomainDeclaration> duplicates;

  /// 正向：名稱 → DomainBundle 節點 ID；未宣告（含因重複宣告被排除）回傳 null。
  ///
  /// 非字串先轉字串再比對（FR-11 值正規化，沿用 FR-10 的 [flowKeyOf]）；
  /// 空字串與空值不解析。
  String? resolve(Object? name) {
    final key = flowKeyOf(name);
    return key == null ? null : _byName[key];
  }

  /// 反查：DomainBundle 節點 ID → 其宣告的 `domain` 原值；非 DomainBundle 或
  /// `domain` 非字串回傳 null。重複宣告的 DomainBundle 仍可反查（其列仍存在）。
  String? domainOf(String bundleId) => _byBundleId[bundleId];

  /// 全部有字串 `domain` 的 DomainBundle 節點 ID，依輸入順序。
  Iterable<String> get bundleIds => _byBundleId.keys;
}
