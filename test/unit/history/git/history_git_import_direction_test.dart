// SPEC-008 H3 依賴方向（測試設計 §1.3）：lib/history 不得 import／export
// lib/corpus 與 lib/graph（package: 與相對路徑皆計入）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _package = 'graph_project_docs_manager';

List<String> _directivesOf(File file) {
  // i18n-exempt: 解析 import／export 指令的樣式
  final pattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
  return [
    for (final line in file.readAsLinesSync())
      if (pattern.firstMatch(line) case final m?) m.group(1)!,
  ];
}

bool _reachesForbidden(String directive, File from) {
  const forbidden = ['corpus', 'graph'];
  if (directive.startsWith('package:$_package/')) {
    final path = directive.substring('package:$_package/'.length);
    return forbidden.any((d) => path.startsWith('$d/'));
  }
  if (directive.startsWith('package:') || directive.startsWith('dart:')) {
    return false;
  }
  final resolved = from.absolute.parent.uri.resolve(directive).toFilePath();
  return forbidden.any((d) => resolved.contains('/lib/$d/'));
}

void main() {
  test('lib/history 不依賴 lib/corpus 與 lib/graph', () {
    final files = Directory('lib/history')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final violations = <String>[];
    for (final file in files) {
      for (final directive in _directivesOf(file)) {
        if (_reachesForbidden(directive, file)) {
          violations.add('${file.path}: $directive');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('正向對照：判準能辨識違規指令', () {
    final probe = File('lib/history/git/x.dart');
    expect(
      _reachesForbidden('package:$_package/graph/light_node.dart', probe),
      isTrue,
    );
    expect(_reachesForbidden('../../corpus/a.dart', probe), isTrue);
    expect(
      _reachesForbidden('package:$_package/schema/type_table.dart', probe),
      isFalse,
    );
  });
}
