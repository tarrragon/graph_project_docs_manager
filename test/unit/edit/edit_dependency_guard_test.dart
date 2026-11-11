import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 需求：[SPEC-009-test-design §1.3 E-DEP-1] 依賴方向守衛：`lib/corpus/` 不得
/// import 或 export `lib/edit/`（edit domain-map §2「Corpus 不依賴本 domain」）。
const String _pkg = 'package:graph_project_docs_manager/';
final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
);

/// 回傳 [source]（位於 lib/[libPath]）中指向 lib/edit/ 的 import／export 目標。
List<String> editTargetsIn(String libPath, String source) => [
  for (final line in source.split('\n'))
    if (_directive.firstMatch(line)?.group(1) case final target?)
      if (_resolve(libPath, target).startsWith('edit/')) target,
];

String _resolve(String fromLibPath, String target) {
  if (target.startsWith(_pkg)) return target.substring(_pkg.length);
  if (target.contains(':')) return target;
  final parts = fromLibPath.split('/')..removeLast();
  for (final segment in target.split('/')) {
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (segment != '.') {
      parts.add(segment);
    }
  }
  return parts.join('/');
}

void main() {
  test('E-DEP-1 lib/corpus/ 不 import 也不 export lib/edit/', () {
    final violations = <String, List<String>>{};
    for (final entity in Directory('lib/corpus').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final hits = editTargetsIn(
        entity.path.substring('lib/'.length),
        entity.readAsStringSync(),
      );
      if (hits.isNotEmpty) violations[entity.path] = hits;
    }
    expect(violations, isEmpty);
  });

  test('E-DEP-1 正向對照：掃描函式對 package 與相對路徑的 edit import 判紅', () {
    expect(
      editTargetsIn(
        'corpus/x.dart',
        "import 'package:graph_project_docs_manager/edit/field_rewrite.dart';",
      ),
      isNotEmpty,
    );
    expect(
      editTargetsIn('corpus/x.dart', "export '../edit/field_rewrite.dart';"),
      isNotEmpty,
    );
    expect(
      editTargetsIn(
        'corpus/x.dart',
        "import 'package:graph_project_docs_manager/schema/edge_type.dart';",
      ),
      isEmpty,
    );
  });
}
