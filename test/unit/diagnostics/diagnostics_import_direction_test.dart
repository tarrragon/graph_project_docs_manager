// 需求：SPEC-007 FR-09／系統層 §2 Diagnostics 不依賴 Schema（0.5.0-W1-461 import 方向檢查）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
final _forbiddenTarget = RegExp(
  r'^(?:package:graph_project_docs_manager/|(?:\.\./)+)schema/',
);

/// 回傳原始碼中指向 schema 的 import／export 目標。
List<String> forbiddenImportsIn(String source) => [
  for (final line in source.split('\n'))
    if (_importPattern.firstMatch(line)?.group(1) case final t?
        when _forbiddenTarget.hasMatch(t))
      t,
];

List<File> dartFilesUnder(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

Map<String, List<String>> violationsUnder(Directory root) => {
  for (final file in dartFilesUnder(root))
    if (forbiddenImportsIn(file.readAsStringSync()) case final bad
        when bad.isNotEmpty)
      file.path: bad,
};

void main() {
  test('E2 正向對照：schema import 被攔下，合法 import 放行', () {
    const sample =
        "import 'package:graph_project_docs_manager/schema/edge_type.dart';\n"
        "export '../schema/edge_type.dart';\n"
        "import 'package:graph_project_docs_manager/graph/flow_key.dart';\n"
        "import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';\n";
    expect(forbiddenImportsIn(sample), [
      'package:graph_project_docs_manager/schema/edge_type.dart',
      '../schema/edge_type.dart',
    ]);
  });

  test('E2 正向對照：子目錄中的違規檔案被遞迴掃描攔下', () {
    final temp = Directory.systemTemp.createTempSync('diag_import_dir_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final nested = Directory('${temp.path}/sub')..createSync(recursive: true);
    File('${nested.path}/bad.dart').writeAsStringSync(
      "import 'package:graph_project_docs_manager/schema/edge_type.dart';\n",
    );
    File('${temp.path}/ok.dart').writeAsStringSync(
      "import 'package:graph_project_docs_manager/graph/flow_key.dart';\n",
    );
    expect(violationsUnder(temp), {
      '${nested.path}/bad.dart': [
        'package:graph_project_docs_manager/schema/edge_type.dart',
      ],
    });
  });

  test('lib/diagnostics（含子目錄）不 import schema', () {
    expect(dartFilesUnder(Directory('lib/diagnostics')), isNotEmpty);
    expect(violationsUnder(Directory('lib/diagnostics')), isEmpty);
  });
}
