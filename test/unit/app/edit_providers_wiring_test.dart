// 需求：1.0.0-W3-553.15.1。wiring test：不 override 三個目標 provider，
// 只覆寫 driven port 與上游狀態；唯讀旗標值取自 EditWorkspace 探測。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/app_shell.dart'
    show ReadonlyWorkspaceReason;
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/spec009/fake_edit_file_port.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/fake_validator_port.dart';

class _FixedLastRound extends LastCompletedRoundNotifier {
  _FixedLastRound(this._round);
  final ScanRoundResult? _round;
  @override
  ScanRoundResult? build() => _round;
}

ProviderContainer _container(
  FakeEditGitPort git, {
  WorkspaceState workspace = const WorkspaceReady('/ws/fake'),
  ScanRoundResult? round,
}) {
  final container = ProviderContainer(
    overrides: [
      editGitPortProvider.overrideWithValue(git),
      editFilePortProvider.overrideWithValue(FakeEditFilePort()),
      lastCompletedRoundProvider.overrideWith(() => _FixedLastRound(round)),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentWorkspaceStateProvider.notifier).state = workspace;
  return container;
}

Future<ReadonlyWorkspaceReason?> _reasonOf(ProviderContainer c) async {
  await c.read(editWorkspaceProvider.future);
  return c.read(readonlyWorkspaceReasonProvider);
}

void main() {
  group('唯讀旗標取自探測（正向對照：三種探測結果各異）', () {
    test('git repo：可寫，旗標 null', () async {
      final c = _container(FakeEditGitPort.repo());
      expect(await _reasonOf(c), isNull);
      expect(
        (await c.read(editWorkspaceProvider.future))!.mode,
        EditMode.writable,
      );
    });

    test('非 git repo：notGit', () async {
      final c = _container(FakeEditGitPort((_) => GitExit(128)));
      expect(await _reasonOf(c), ReadonlyWorkspaceReason.notGit);
    });

    test('git 無法啟動：gitMissing', () async {
      final c = _container(FakeEditGitPort((_) => const GitLaunchFail()));
      expect(await _reasonOf(c), ReadonlyWorkspaceReason.gitMissing);
    });
  });

  test('工作區未就緒：EditWorkspace 為 null、旗標 null', () async {
    final c = _container(
      FakeEditGitPort.repo(),
      workspace: const WorkspaceUnset(),
    );
    expect(await c.read(editWorkspaceProvider.future), isNull);
    expect(c.read(readonlyWorkspaceReasonProvider), isNull);
  });

  test('EditWorkspace 以工作區路徑開啟（git 呼叫帶 -C 路徑）', () async {
    final git = FakeEditGitPort.repo();
    final c = _container(git, workspace: const WorkspaceReady('/ws/other'));
    await c.read(editWorkspaceProvider.future);
    expect(git.calls.first.arguments.take(2), ['-C', '/ws/other']);
  });

  group('fieldDomainSourceProvider', () {
    test('無完成輪次：空來源', () {
      final c = _container(FakeEditGitPort.repo());
      final source = c.read(fieldDomainSourceProvider);
      expect(source.completenessFields('SPEC'), isEmpty);
      expect(source.hasMachineDefinedEnum('SPEC', 'status'), isFalse);
    });

    test('有完成輪次：讀該輪型別表', () {
      final round = fakeRound(
        typeTable: TypeTable({
          'SPEC': NodeTypeEntry(
            name: 'SPEC',
            completenessFields: const {'title'},
          ),
        }, nonDomainPathsKey: 'non_domain_path_patterns'),
      );
      final c = _container(FakeEditGitPort.repo(), round: round);
      expect(c.read(fieldDomainSourceProvider).completenessFields('SPEC'), {
        'title',
      });
    });
  });

  group('驗證器 port（SPEC-009 FR-05）', () {
    test('工作區就緒：預設為以工作區根為工作目錄的 IoEditValidatorPort', () {
      final c = _container(FakeEditGitPort.repo());
      final port = c.read(editValidatorPortProvider);
      expect(port, isA<IoEditValidatorPort>());
      expect((port! as IoEditValidatorPort).workingDirectory, '/ws/fake');
    });

    test('正向對照：工作區未就緒為 null', () {
      final c = _container(
        FakeEditGitPort.repo(),
        workspace: const WorkspaceUnset(),
      );
      expect(c.read(editValidatorPortProvider), isNull);
    });

    test('validator 經 editWorkspaceProvider 傳入：開始編輯即啟動驗證', () async {
      final dir = Directory.systemTemp.createTempSync('wiring_validator_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final root = dir.resolveSymbolicLinksSync();
      final path = WorkspaceRelativePath.from(root, 'a.md')!;
      final files = FakeEditFilePort()
        ..files[path.absolute] = Uint8List.fromList(
          utf8.encode('---\nid: A\n---\n'),
        );
      final validator = FakeValidatorPort();
      final c = ProviderContainer(
        overrides: [
          editGitPortProvider.overrideWithValue(FakeEditGitPort.repo()),
          editFilePortProvider.overrideWithValue(files),
          editValidatorPortProvider.overrideWithValue(validator),
          lastCompletedRoundProvider.overrideWith(() => _FixedLastRound(null)),
        ],
      );
      addTearDown(c.dispose);
      c.read(currentWorkspaceStateProvider.notifier).state = WorkspaceReady(
        root,
      );
      final workspace = await c.read(editWorkspaceProvider.future);
      await workspace!.beginEditing(path);
      await Future<void>.delayed(Duration.zero);
      expect(validator.calls, isNotEmpty);
    });
  });
}
