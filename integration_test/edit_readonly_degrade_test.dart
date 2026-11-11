// SPEC-009 測試設計 §2.5 IT-E5：唯讀降級（真實 git 與真實檔案系統）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/edit_fixture_repo.dart';

Future<(EditWorkspace, BeginEditingResult)> _open(
  EditFixtureRepo repo,
  EditGitPort git,
) async {
  final workspace = await EditWorkspace.open(
    root: repo.workspaceRoot,
    git: git,
    files: const IoEditFilePort(),
  );
  final path = WorkspaceRelativePath.from(
    repo.workspaceRoot,
    editTargetRelative,
  )!;
  return (workspace, await workspace.beginEditing(path));
}

Future<void> _expectReadOnlyAndUntouched(
  EditFixtureRepo repo,
  EditGitPort git,
) async {
  final file = File(repo.targetPath);
  final contentBefore = file.readAsBytesSync();
  final mtimeBefore = file.statSync().modified;
  final (workspace, result) = await _open(repo, git);
  expect(workspace.mode, EditMode.readOnly);
  expect(result, isA<EditingReadOnly>());
  expect(file.readAsBytesSync(), contentBefore);
  expect(file.statSync().modified, mtimeBefore);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('IT-E5-1 R6 非 git 工作區：唯讀降級，檔案不變', () async {
    final repo = await EditFixtureRepo.r6();
    addTearDown(repo.dispose);
    await _expectReadOnlyAndUntouched(repo, repo.gitPort());
  });

  test('IT-E5-2 R7 git 無法執行：唯讀降級，檔案不變', () async {
    final repo = await EditFixtureRepo.r0();
    addTearDown(repo.dispose);
    // 以不存在的執行檔等價於「PATH 不含 git」：行程無法啟動。
    await _expectReadOnlyAndUntouched(
      repo,
      repo.gitPort(executable: '${repo.base.path}/no-such-dir/git'),
    );
  });

  test('IT-E5-3 正向對照：R0 可寫', () async {
    final repo = await EditFixtureRepo.r0();
    addTearDown(repo.dispose);
    final (workspace, result) = await _open(repo, repo.gitPort());
    expect(workspace.mode, EditMode.writable);
    expect(result, isA<EditingStarted>());
  });
}
