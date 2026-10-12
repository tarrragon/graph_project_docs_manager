/// FR-12／FR-13 測試共用：以宣告方式建 DomainBundle 與 UC 的建圖輸入。
///
/// bundle 以短鍵（小寫英數）宣告，節點 ID 為 `DOMAIN-MAP-<鍵>`，`domain` 字面另給，
/// 使 ID 與 domain 可獨立變動（排序只看 domain，ID 只負責邊的端點）。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import 'edge_table_builder.dart';
import 'known_distribution_fixture.dart';
import 'raw_node_builder.dart';

/// 鍵 → 節點 ID。
String bundleIdOf(String key) => 'DOMAIN-MAP-$key';

/// 一個 DomainBundle：[key] 決定節點 ID，[domain] 為宣告字面，[dependsOn] 為被依賴者的鍵。
RawNode bundleNode(
  String key, {
  String? domain,
  List<String> dependsOn = const [],
}) => buildRawNode(
  id: bundleIdOf(key),
  typeName: domainBundleTypeName,
  extra: {
    domainBundleDomainField: domain ?? key,
    if (dependsOn.isNotEmpty)
      'depends_on_bundles': [for (final k in dependsOn) bundleIdOf(k)],
  },
);

/// 一個 UC，步驟 `traverses` 依序給定；`null` 代表該步驟缺 `traverses` 鍵。
RawNode ucNode(String id, List<List<String>?> stepTraverses) => RawNode(
  path: 'docs/usecases/$id.md',
  frontmatter: {'id': id},
  typeName: 'UC',
  flowSteps: [
    for (var i = 0; i < stepTraverses.length; i++)
      {'id': 's$i', 'traverses': ?stepTraverses[i]},
  ],
);

GraphBuildResult buildResultOf(List<RawNode> nodes) => buildGraph(
  rawNodes: nodes,
  projectSchemaJson: loadBuiltinSchemaJson(),
  builtinSchemaJson: loadBuiltinSchemaJson(),
);

GraphBuildResult unavailableBuildResult() => buildGraph(
  rawNodes: const [],
  projectSchemaJson: buildEdgeTableJson(version: '99.0.0'),
  builtinSchemaJson: loadBuiltinSchemaJson(),
);
