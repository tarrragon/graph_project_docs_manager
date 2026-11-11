// SPEC-009 測試設計 §2.4 IT-E4：symlink（FR-04），fixture R5。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory base;
  late String work;
  late String outside;

  setUp(() {
    base = Directory.systemTemp.createTempSync('it_e4_');
    final real = base.resolveSymbolicLinksSync();
    work = '$real/work';
    outside = '$real/outside';
    Directory('$work/docs/spec/x').createSync(recursive: true);
    Directory(outside).createSync();
    File('$outside/a.md').writeAsStringSync('outside-original');
    File('$work/docs/spec/x/SPEC-900.md').writeAsStringSync('base');
    Link('$work/docs/link.md').createSync('$outside/a.md');
    Link('$work/docs/linkdir').createSync(outside);
  });
  tearDown(() => base.deleteSync(recursive: true));

  test('IT-E4-1 檔名 symlink 建構失敗，界外檔不變', () {
    expect(WorkspaceRelativePath.from(work, 'docs/link.md'), isNull);
    expect(File('$outside/a.md').readAsStringSync(), 'outside-original');
  });

  test('IT-E4-2 父目錄 symlink 指向界外建構失敗', () {
    expect(WorkspaceRelativePath.from(work, 'docs/linkdir/a.md'), isNull);
  });

  // 「成功並 written」的寫入段待寫入函式票；此處只斷言建構成功。
  test('IT-E4-3 正向對照：界內一般檔可建構', () {
    expect(
      WorkspaceRelativePath.from(work, 'docs/spec/x/SPEC-900.md'),
      isNotNull,
    );
  });
}
