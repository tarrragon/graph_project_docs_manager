// SPEC-009 測試設計 §2.2 IT-E2：快照與不動使用者狀態（真實 git）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/edit_fixture_repo.dart';

Future<EditSession> _begin(EditFixtureRepo repo) async {
  final workspace = await EditWorkspace.open(
    root: repo.workspaceRoot,
    git: repo.gitPort(),
    files: const IoEditFilePort(),
    now: () => DateTime(2026, 11, 10),
  );
  final path = WorkspaceRelativePath.from(
    repo.workspaceRoot,
    editTargetRelative,
  )!;
  return ((await workspace.beginEditing(path)) as EditingStarted).session;
}

/// 使用者可觀察的 git 狀態。
Future<List<String>> _userState(
  EditFixtureRepo repo, {
  bool withIndex = false,
}) async => [
  await repo.git(['stash', 'list']),
  await repo.git(['reflog']),
  await repo.git(['log', '--format=%H']),
  if (withIndex) await repo.git(['status', '--porcelain']),
  if (withIndex) await repo.git(['diff', '--cached', '--name-only']),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('IT-E2-1 R0 寫入前後 stash／reflog／log 逐字相同，index 未被動', () async {
    final repo = await EditFixtureRepo.r0();
    addTearDown(repo.dispose);
    final before = await _userState(repo);
    final session = await _begin(repo);
    final result = await session.writeField(field: 'title', newValue: '新');
    expect(result, isA<Written>());
    expect(await _userState(repo), before);
    // 寫入本身使工作區欄出現修改，且只有該欄：沒有任何已 staged 的項目。
    expect(
      await repo.git(['status', '--porcelain']),
      ' M $editTargetRelative\n',
    );
  });

  test('IT-E2-2 R8 他人的 staged 與 stash 逐字不變；寫入確實發生', () async {
    final repo = await EditFixtureRepo.r8();
    addTearDown(repo.dispose);
    final before = await _userState(repo, withIndex: true);
    final session = await _begin(repo);
    final result = await session.writeField(field: 'priority', newValue: 'P0');
    expect((result as Written).snapshotSha, isNotNull);
    expect(await _userState(repo, withIndex: true), before);
    expect(
      await repo.git(['status', '--porcelain']),
      contains(' M $editTargetRelative'),
    );
    expect(await repo.git(['stash', 'list']), isNotEmpty);
  });

  for (final variant in ['R4', 'R4b']) {
    test('IT-E2-3 $variant 換行轉換下取回逐位元組等於 W', () async {
      final repo = variant == 'R4'
          ? await EditFixtureRepo.r4()
          : await EditFixtureRepo.r4b();
      addTearDown(repo.dispose);
      final session = await _begin(repo);
      final w = repo.read(editTargetRelative);
      final result = await session.writeField(field: 'title', newValue: '新');
      final sha = (result as Written).snapshotSha;
      expect(sha, isNotNull);
      final blob = await repo.gitBytes(['cat-file', 'blob', sha!]);
      expect(blob, w);
      expect(w, contains(13)); // CRLF 的 CR：fixture 確為 CRLF
      // 正向對照：帶路徑的 hash-object 會套用過濾，SHA 與 --stdin 不同，
      // 證明 fixture 確實觸發換行轉換。
      final filtered = (await repo.git(['hash-object', editTargetRelative]))
          .trim();
      expect(filtered, isNot(sha));
    });
  }

  test('IT-E2-4 R10 寫入後權限仍為 0640', () async {
    final repo = await EditFixtureRepo.r10();
    addTearDown(repo.dispose);
    final session = await _begin(repo);
    final result = await session.writeField(field: 'title', newValue: '新');
    expect(result, isA<Written>());
    final mode = File(repo.targetPath).statSync().mode & 0x1FF; // 0o777
    expect(mode.toRadixString(8), '640');
  });
}
