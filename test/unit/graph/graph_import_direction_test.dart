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

/// [root] 底下（遞迴）全部 .dart 檔。
List<File> dartFilesUnder(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// 檔案路徑 → 其違規 import；無違規的檔案不出現。
Map<String, List<String>> violationsUnder(Directory root) => {
  for (final file in dartFilesUnder(root))
    if (forbiddenImportsIn(file.readAsStringSync()) case final bad
        when bad.isNotEmpty)
      file.path: bad,
};

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

  test('E2 正向對照：子目錄中的違規檔案被遞迴掃描攔下', () {
    final temp = Directory.systemTemp.createTempSync('graph_import_dir_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final nested = Directory('${temp.path}/sub/deeper')
      ..createSync(recursive: true);
    File('${nested.path}/bad.dart').writeAsStringSync(
      "import 'package:graph_project_docs_manager/layout/lane_order.dart';\n",
    );
    File('${temp.path}/ok.dart').writeAsStringSync(
      "import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';\n",
    );
    expect(violationsUnder(temp), {
      '${nested.path}/bad.dart': [
        'package:graph_project_docs_manager/layout/lane_order.dart',
      ],
    });
  });

  test('lib/graph（含子目錄）不 import layout／screens／components', () {
    expect(dartFilesUnder(Directory('lib/graph')), isNotEmpty);
    expect(violationsUnder(Directory('lib/graph')), isEmpty);
  });
}
