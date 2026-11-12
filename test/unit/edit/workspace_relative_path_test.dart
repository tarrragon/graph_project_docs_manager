// SPEC-009 測試設計 §3 P 組（FR-04）：路徑界內型別，使用真實暫存目錄。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

void main() {
  late Directory base;
  late String real;
  late String work;

  setUp(() {
    base = Directory.systemTemp.createTempSync('p_group_');
    // 先解析暫存根，避免 /var → /private/var 干擾斷言。
    real = base.resolveSymbolicLinksSync();
    work = '$real/work';
    Directory('$work/docs/spec').createSync(recursive: true);
    Directory('$real/workspace').createSync();
    Directory('$real/outside').createSync();
    File('$work/docs/spec/a.md').writeAsStringSync('x');
  });
  tearDown(() => base.deleteSync(recursive: true));

  WorkspaceRelativePath? build(String input, {String? root}) =>
      WorkspaceRelativePath.from(root ?? work, input);

  test('P-1 父目錄與檔案皆存在可建構', () {
    final p = build('docs/spec/a.md');
    expect(p, isNotNull);
    expect(p!.relative, 'docs/spec/a.md');
    expect(p.absolute, '$work/docs/spec/a.md');
  });

  test('P-2 檔案不存在、父目錄存在可建構', () {
    expect(build('docs/new.md'), isNotNull);
  });

  test('P-3 穿越輸入皆失敗（對照 P-1）', () {
    expect(build('docs/spec/a.md'), isNotNull);
    expect(build('../outside/a.md'), isNull);
    expect(build('docs/../../outside/a.md'), isNull);
  });

  test('P-4 點段、空段、NUL 皆失敗（對照 P-1）', () {
    expect(build('docs/spec/a.md'), isNotNull);
    expect(build('./docs/a.md'), isNull);
    expect(build('docs/./a.md'), isNull);
    expect(build('docs//a.md'), isNull);
    expect(build('docs/a\u0000.md'), isNull);
  });

  test('P-5 絕對路徑失敗，即使在界內', () {
    expect(build('docs/spec/a.md'), isNotNull);
    expect(build('$work/docs/spec/a.md'), isNull);
  });

  test('P-6 前綴相同的兄弟目錄經 symlink 進入時失敗（對照：根為 workspace）', () {
    Link('$work/ws').createSync('$real/workspace');
    File('$real/workspace/a.md').writeAsStringSync('x');
    expect(build('ws/a.md'), isNull);
    expect(build('a.md', root: '$real/workspace'), isNotNull);
  });

  test('P-6b 父目錄 symlink 指向工作區外失敗', () {
    Link('$work/docs/linkdir').createSync('$real/outside');
    expect(build('docs/linkdir/a.md'), isNull);
  });

  test('P-7 檔名為 symlink 一律失敗，即使目標在界內', () {
    File('$work/docs/real.md').writeAsStringSync('x');
    Link('$work/docs/link.md').createSync('$work/docs/real.md');
    expect(build('docs/real.md'), isNotNull);
    expect(build('docs/link.md'), isNull);
  });

  test('P-8 工作區根本身經過 symlink 仍可建構', () {
    Link('$real/rootlink').createSync(work);
    expect(build('docs/spec/a.md', root: '$real/rootlink'), isNotNull);
  });

  test('空輸入與父目錄不存在失敗', () {
    expect(build(''), isNull);
    expect(build('nodir/a.md'), isNull);
  });
}
