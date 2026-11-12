// SPEC-009 測試設計 §2.4 IT-E4：symlink（FR-04），fixture R5。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/spec009/frontmatter_fixtures.dart';

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

  test('IT-E4-3 正向對照：界內一般檔可建構，且寫入結果為 written', () async {
    final path = WorkspaceRelativePath.from(work, 'docs/spec/x/SPEC-900.md');
    expect(path, isNotNull);
    File(path!.absolute).writeAsBytesSync(fixtureBytes(docPlainText));
    final git = await Process.run('git', [
      'init',
      '-q',
    ], workingDirectory: work);
    expect(git.exitCode, 0);
    final workspace = await EditWorkspace.open(
      root: work,
      git: IoEditGitPort(
        baseEnvironment: {
          'GIT_CONFIG_GLOBAL': '/dev/null',
          'GIT_CONFIG_NOSYSTEM': '1',
          'HOME': base.path,
        },
      ),
      files: const IoEditFilePort(),
    );
    final started = await workspace.beginEditing(path);
    expect(started, isA<EditingStarted>());
    final result = await (started as EditingStarted).session.writeField(
      field: 'title',
      newValue: '新標題',
    );
    expect(result, isA<Written>());
    expect(File(path.absolute).readAsStringSync(), contains('新標題'));
  });
}
