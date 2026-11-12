// SPEC-009 測試設計 §2.1 IT-E1、§2.3 IT-E3：三種判定與子目錄工作區（真實 git）。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/edit_fixture_repo.dart';

Future<EditSession> _begin(
  EditFixtureRepo repo,
  RecordingEditGitPort git,
  String relative,
) async {
  final workspace = await EditWorkspace.open(
    root: repo.workspaceRoot,
    git: git,
    files: const IoEditFilePort(),
    now: () => DateTime(2026, 11, 10),
  );
  final path = WorkspaceRelativePath.from(repo.workspaceRoot, relative)!;
  final result = await workspace.beginEditing(path);
  expect(result, isA<EditingStarted>());
  return (result as EditingStarted).session;
}

Future<WriteResult> _writeTitle(EditSession session) =>
    session.writeField(field: 'title', newValue: '新標題');

Future<Uint8List> _blob(EditFixtureRepo repo, String sha) =>
    repo.gitBytes(['cat-file', 'blob', sha]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('IT-E1-1 外部寫入後修正：blocked(externallyModified)', () async {
    final repo = await EditFixtureRepo.r0();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    repo.modifyTitle('外部標題');
    final external = repo.read(editTargetRelative);
    final result = await _writeTitle(session);
    expect(
      result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
    expect(repo.read(editTargetRelative), external);
  });

  test('IT-E1-2 R1：written 帶快照 SHA，blob 等於開始編輯時的位元組', () async {
    final repo = await EditFixtureRepo.r1();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    final atBegin = repo.read(editTargetRelative);
    final result = await session.writeField(field: 'priority', newValue: 'P0');
    final sha = (result as Written).snapshotSha;
    expect(sha, isNotNull);
    expect(await _blob(repo, sha!), atBegin);
  });

  test('IT-E1-3 R0：written 不帶 SHA，全程沒有 hash-object', () async {
    final repo = await EditFixtureRepo.r0();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    final result = await _writeTitle(session);
    expect(result, isA<Written>());
    expect((result as Written).snapshotSha, isNull);
    expect(
      git.calls.where((c) => c.arguments.contains('hash-object')),
      isEmpty,
    );
  });

  test('IT-E1-4 R2 未追蹤檔：written 帶快照 SHA', () async {
    final repo = await EditFixtureRepo.r2();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, 'docs/spec/x/SPEC-901.md');
    final result = await _writeTitle(session);
    expect((result as Written).snapshotSha, isNotNull);
  });

  test('IT-E1-5 R9 HEAD unborn：written 帶快照 SHA', () async {
    final repo = await EditFixtureRepo.r9();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    final result = await _writeTitle(session);
    expect((result as Written).snapshotSha, isNotNull);
  });

  test('IT-E1-6 非英文語系：每次 git 呼叫環境含 LC_ALL=C，判定同 IT-E1-4', () async {
    final repo = await EditFixtureRepo.r2();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(
      repo.gitPort(
        extraEnvironment: {'LANG': 'zh_TW.UTF-8', 'LC_MESSAGES': 'zh_TW.UTF-8'},
      ),
    );
    final session = await _begin(repo, git, 'docs/spec/x/SPEC-901.md');
    final result = await _writeTitle(session);
    expect((result as Written).snapshotSha, isNotNull);
    final names = [for (final c in git.calls) c.arguments[2]];
    expect(names, containsAll(['show', 'hash-object']));
    for (final call in git.calls) {
      expect(call.environment['LC_ALL'], 'C');
    }
  });

  test('IT-E3-1 R3 子目錄工作區：W=H 不快照（H 取自 proj/ 而非 repo 根）', () async {
    final repo = await EditFixtureRepo.r3();
    addTearDown(repo.dispose);
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    final result = await _writeTitle(session);
    expect(result, isA<Written>());
    expect((result as Written).snapshotSha, isNull);
  });

  test('IT-E3-2 R3 工作區內有未 commit 的改動：帶快照 SHA，blob 不等於對照檔', () async {
    final repo = await EditFixtureRepo.r3();
    addTearDown(repo.dispose);
    repo.modifyTitle('未提交標題');
    final git = RecordingEditGitPort(repo.gitPort());
    final session = await _begin(repo, git, editTargetRelative);
    final atBegin = repo.read(editTargetRelative);
    final result = await _writeTitle(session);
    final sha = (result as Written).snapshotSha;
    expect(sha, isNotNull);
    final blob = await _blob(repo, sha!);
    expect(blob, atBegin);
    final contrast = File('${repo.repoRoot}/$editTargetRelative')
        .readAsBytesSync();
    expect(blob, isNot(contrast));
  });
}
