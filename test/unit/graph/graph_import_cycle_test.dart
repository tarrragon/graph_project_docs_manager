// domain_name_resolver.dart 與 flow_key.dart 不得 import flow_subgraph.dart
// （flow_subgraph.dart 依賴它們；反向 import 會形成循環）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// 回傳原始碼中指向 flow_subgraph.dart 的 import／export 目標。
List<String> flowSubgraphImportsIn(String source) => [
  for (final line in source.split('\n'))
    if (_importPattern.firstMatch(line)?.group(1) case final t?
        when t.endsWith('flow_subgraph.dart'))
      t,
];

void main() {
  test('E2 正向對照：違規樣本被攔下', () {
    const sample =
        "import 'package:graph_project_docs_manager/graph/flow_subgraph.dart'\n"
        "    show flowKeyOf;\n"
        "import 'package:graph_project_docs_manager/graph/flow_key.dart';\n"
        "export 'flow_subgraph.dart';\n";
    expect(flowSubgraphImportsIn(sample), [
      'package:graph_project_docs_manager/graph/flow_subgraph.dart',
      'flow_subgraph.dart',
    ]);
  });

  test('被依賴的底層檔不 import flow_subgraph.dart', () {
    for (final path in [
      'lib/graph/domain_name_resolver.dart',
      'lib/graph/flow_key.dart',
    ]) {
      expect(
        flowSubgraphImportsIn(File(path).readAsStringSync()),
        isEmpty,
        reason: path,
      );
    }
  });
}
