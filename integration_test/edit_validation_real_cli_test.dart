// SPEC-009 測試設計 §2.6 IT-E6：真實驗證器（FR-05，PROP-005 §1.0 整合測試）。
// 需要 `uv` 與 doc CLI；找不到時以說明訊息判為失敗，不跳過（§6 第 5 項）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/spec009/frontmatter_fixtures.dart';
import 'helpers/edit_fixture_repo.dart';

Future<EditSession> _begin(EditFixtureRepo repo) async {
  final workspace = await EditWorkspace.open(
    root: repo.workspaceRoot,
    git: repo.gitPort(),
    files: const IoEditFilePort(),
    validator: IoEditValidatorPort(workingDirectory: repo.workspaceRoot),
    now: () => DateTime(2026, 11, 10),
  );
  final path = WorkspaceRelativePath.from(
    repo.workspaceRoot,
    ucTargetRelative,
  )!;
  final started = await workspace.beginEditing(path);
  expect(started, isA<EditingStarted>());
  final session = (started as EditingStarted).session;
  // 前置條件（test-design §2.6）：baseline 量測完成後才寫入，本檔測的才是差集
  // 判定，而不是 baseline 與寫入的競態（V-19）。
  await session.baselineIdle;
  return session;
}

Future<ValidationStatus> _write(
  EditSession session,
  String field,
  String value,
) async {
  final result = await session.writeField(field: field, newValue: value);
  expect(result, isA<Written>());
  await session.validationIdle;
  return session.lastValidationStatus!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final uv = await Process.run('uv', ['--version']);
    expect(uv.exitCode, 0, reason: '前置條件：PATH 上需有 uv（test-design §2.6）');
    final probe = await Process.run('doc', ['--help']);
    expect(
      probe.exitCode,
      0,
      reason: '需要 uv 與 PATH 上的 doc CLI（CLAUDE.md §6）：${probe.stderr}',
    );
  });

  test('IT-E6-1 新值含未登記 UC：written，驗證 failed 新增 1，新值未被改回', () async {
    final repo = await EditFixtureRepo.r0Uc(bodyMentions: false);
    addTearDown(repo.dispose);
    final session = await _begin(repo);
    final status = await _write(
      session,
      'primary_actor',
      '使用者 $unregisteredUc2',
    );
    expect(
      status,
      isA<ValidationFailed>().having((s) => s.newIssueCount, 'count', 1),
    );
    expect(
      File('${repo.workspaceRoot}/$ucTargetRelative').readAsStringSync(),
      contains('使用者 $unregisteredUc2'),
    );
  });

  test('IT-E6-2 內文已含兩次提及：修正 title 驗證 passed', () async {
    final repo = await EditFixtureRepo.r0Uc(bodyMentions: true);
    addTearDown(repo.dispose);
    final session = await _begin(repo);
    expect(await _write(session, 'title', '新標題'), isA<ValidationPassed>());
  });

  test('IT-E6-3 正向對照：IT-E6-1 的 fixture 改 title 為 passed', () async {
    final repo = await EditFixtureRepo.r0Uc(bodyMentions: false);
    addTearDown(repo.dispose);
    final session = await _begin(repo);
    expect(await _write(session, 'title', '新標題'), isA<ValidationPassed>());
  });
}
