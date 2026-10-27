import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守衛：test/ 內以專案相對路徑實讀 docs/ 的字面，必須落在 merge-gate.yaml
/// flutter 套件的 prefixes 內，否則改該檔時閘門不會選到 flutter 套件。
/// 已知限制：只改 merge-gate.yaml 縮窄前綴時 flutter 套件不會被選到，
/// 本守衛不會跑，該方向由 hooks 套件把關。
const _gatePath = '.claude/project-integration/merge-gate.yaml';
const _selfPath = 'test/unit/merge_gate/flutter_docs_prefix_guard_test.dart';
// 實讀呼叫：File('docs/..')、_readFile('docs/..')，或以常數名傳入的同形呼叫。
// 虛擬檔案系統的 addFile('docs/..') 不碰真實磁碟，不在掃描範圍。
final _readCall = RegExp(
  r"""(?<![A-Za-z])(?:File|_readFile)\(\s*(?:['"](docs/[^'"$]*)['"]|(\w+))""",
);
final _docsConst = RegExp(r"""const\s+(\w+)\s*=\s*['"](docs/[^'"$]*)['"]""");

List<String> flutterPrefixes(String yaml) {
  final lines = yaml.split('\n');
  final start = lines.indexWhere((l) => l.startsWith('  flutter:'));
  final line = lines
      .skip(start + 1)
      .firstWhere((l) => l.trimLeft().startsWith('prefixes:'));
  final body = line.substring(line.indexOf('[') + 1, line.indexOf(']'));
  return body.split(',').map((e) => e.trim()).toList();
}

List<String> uncoveredDocsLiterals(String source, List<String> prefixes) {
  final consts = {
    for (final m in _docsConst.allMatches(source)) m.group(1)!: m.group(2)!,
  };
  return _readCall
      .allMatches(source)
      .map((m) => m.group(1) ?? consts[m.group(2)])
      .whereType<String>()
      .where((p) => !prefixes.any(p.startsWith))
      .toList();
}

void main() {
  final prefixes = flutterPrefixes(File(_gatePath).readAsStringSync());

  test('flutter prefixes 含 docs/spec/ 且不含 docs/', () {
    expect(prefixes, contains('docs/spec/'));
    expect(prefixes, isNot(contains('docs/')));
  });

  test('test/ 實讀的 docs/ 字面皆落在 flutter prefixes 內', () {
    final violations = <String>[];
    for (final f in Directory('test').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path == _selfPath) {
        continue;
      }
      for (final p in uncoveredDocsLiterals(f.readAsStringSync(), prefixes)) {
        violations.add('${f.path}: $p');
      }
    }
    expect(violations, isEmpty);
  });

  test('正向對照：docs/research/ 路徑判紅，docs/spec/ 路徑不判紅', () {
    expect(
      uncoveredDocsLiterals("File('docs/research/x.md')", prefixes),
      ['docs/research/x.md'],
    );
    expect(
      uncoveredDocsLiterals("File('docs/spec/ui/a.md')", prefixes),
      isEmpty,
    );
    expect(
      uncoveredDocsLiterals(
        "const _p = 'docs/research/y.md'; _readFile(_p);",
        prefixes,
      ),
      ['docs/research/y.md'],
    );
    expect(
      uncoveredDocsLiterals("fs.addFile('docs/research/z.md', b)", prefixes),
      isEmpty,
    );
  });
}
