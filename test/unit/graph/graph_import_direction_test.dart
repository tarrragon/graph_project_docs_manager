// 需求：系統層 §2 Graph 不依賴 Layout／畫面／元件（0.5.0-W1-114.7 import 方向檢查）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
final _forbiddenTarget = RegExp(
  r'^(?:package:graph_project_docs_manager/|(?:\.\./)+)(?:layout|screens|components)/',
);

/// 回傳原始碼中指向 layout／screens／components 的 import／export 目標。
List<String> forbiddenImportsIn(String source) => [
  for (final line in source.split('\n'))
    if (_importPattern.firstMatch(line)?.group(1) case final t?
        when _forbiddenTarget.hasMatch(t))
      t,
];

void main() {
  test('E2 正向對照：違規樣本被攔下，合法 import 放行', () {
    const sample =
        "import 'package:graph_project_docs_manager/layout/lane_order.dart';\n"
        "import 'package:graph_project_docs_manager/screens/home.dart' as h;\n"
        "export '../components/button.dart';\n"
        "import 'package:graph_project_docs_manager/graph/flow_key.dart';\n"
        "import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';\n";
    expect(forbiddenImportsIn(sample), [
      'package:graph_project_docs_manager/layout/lane_order.dart',
      'package:graph_project_docs_manager/screens/home.dart',
      '../components/button.dart',
    ]);
  });

  test('lib/graph 不 import layout／screens／components', () {
    final files = Directory('lib/graph')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        forbiddenImportsIn(file.readAsStringSync()),
        isEmpty,
        reason: file.path,
      );
    }
  });
}
