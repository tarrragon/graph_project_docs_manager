// SPEC-001-test-design §1.4：Layout 只依賴 Graph。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const forbiddenPrefixes = [
  'package:graph_project_docs_manager/corpus/',
  'package:graph_project_docs_manager/screens/',
  'package:graph_project_docs_manager/components/',
];

final importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// 回傳原始碼中違反依賴方向的 import 目標。
List<String> forbiddenImportsIn(String source, String filePath) {
  final found = <String>[];
  for (final line in source.split('\n')) {
    final target = importPattern.firstMatch(line)?.group(1);
    if (target == null) continue;
    if (forbiddenPrefixes.any(target.startsWith) ||
        _isForbiddenRelative(target, filePath)) {
      found.add(target);
    }
  }
  return found;
}

bool _isForbiddenRelative(String target, String filePath) {
  if (target.startsWith('package:') || target.startsWith('dart:')) {
    return false;
  }
  final resolved = File(filePath).parent.uri.resolve(target).path;
  return [
    '/lib/corpus/',
    '/lib/screens/',
    '/lib/components/',
  ].any(resolved.contains);
}

void main() {
  test('E2 正向對照：違規樣本被攔下', () {
    const sample =
        "import 'package:graph_project_docs_manager/corpus/x.dart';\n"
        "import 'package:graph_project_docs_manager/graph/y.dart';\n";
    expect(forbiddenImportsIn(sample, 'lib/layout/z.dart'), [
      'package:graph_project_docs_manager/corpus/x.dart',
    ]);
    expect(
      forbiddenImportsIn("import '../screens/a.dart';", '/w/lib/layout/z.dart'),
      ['../screens/a.dart'],
    );
  });

  test('E2 正向對照：export 違規樣本（package 與相對路徑）被攔下', () {
    const packageExport =
        "export 'package:graph_project_docs_manager/screens/x.dart';\n"
        "export 'package:graph_project_docs_manager/graph/y.dart';\n";
    expect(forbiddenImportsIn(packageExport, 'lib/layout/z.dart'), [
      'package:graph_project_docs_manager/screens/x.dart',
    ]);
    expect(
      forbiddenImportsIn("export '../corpus/a.dart';", '/w/lib/layout/z.dart'),
      ['../corpus/a.dart'],
    );
  });

  test('lib/layout 與 test/unit/layout 無違規 import', () {
    final files = [
      for (final dir in ['lib/layout', 'test/unit/layout'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    expect(files, isNotEmpty);
    final violations = {
      for (final f in files)
        if (forbiddenImportsIn(f.readAsStringSync(), f.absolute.path)
            case final v when v.isNotEmpty)
          f.path: v,
    };
    expect(violations, isEmpty);
  });
}
