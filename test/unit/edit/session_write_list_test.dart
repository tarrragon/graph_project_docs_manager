import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';
import '../../helpers/spec009/manual_edit_timer.dart';

/// 需求：[SPEC-009 FR-08] session 寫入清單（test-design §3 C-1～C-5）。
/// 日誌側（C-4 的 `snapshotTaken`）由 FR-07 承接票處理，本檔斷言清單側。
const String _secretMarker = 'SECRET-CONTENT-7f3a';
const String _otherRelative = 'docs/proposals/PROP-900.md';

Future<EditSession> _beginOther(EditHarness h) async {
  Directory('${h.root}/docs/proposals').createSync(recursive: true);
  final path = WorkspaceRelativePath.from(h.root, _otherRelative)!;
  h.files.files[path.absolute] = fixtureBytes(docPlainText);
  final result = await h.workspace.beginEditing(path);
  expect(result, isA<EditingStarted>());
  return (result as EditingStarted).session;
}

void main() {
  test('C-1 兩次寫入：兩列，含路徑、欄位名、節點 ID、驗證狀態', () async {
    final h = await EditHarness.create(validator: FakeValidatorPort());
    final spec = await h.begin();
    final prop = await _beginOther(h);
    await spec.writeField(field: 'title', newValue: '新標題');
    await prop.writeField(field: 'priority', newValue: 'P0');
    await spec.validationIdle;
    await prop.validationIdle;
    final rows = h.workspace.writeList.entries;
    expect(rows.map((e) => (e.relativePath, e.field, e.nodeId)), [
      (targetRelative, 'title', 'SPEC-900'),
      (_otherRelative, 'priority', 'PROP-900'),
    ]);
    expect(rows.map((e) => e.validationStatus), everyElement(isNotNull));
  });

  test('C-2 寫入值含 secretMarker：清單序列化不含標記（正向對照：檔案含標記）', () async {
    final h = await EditHarness.create(validator: FakeValidatorPort());
    final session = await h.begin();
    await session.writeField(field: 'title', newValue: _secretMarker);
    await session.validationIdle;
    final text = h.workspace.writeList.entries.map((e) => '$e').join('\n');
    expect(text, isNot(contains(_secretMarker)));
    expect(String.fromCharCodes(h.target!), contains(_secretMarker));
  });

  test('C-3 驗證延後以 failed 完成：該列 running 轉 failed，他檔不受影響', () async {
    final timer = ManualEditTimer();
    final port = FakeValidatorPort(
      ucVerify: [
        validatorOk,
        ValidatorAfter(
          const Duration(seconds: 5),
          1,
          ucViolationOutput(unregisteredUc, 1),
        ),
      ],
      timer: timer,
    );
    final h = await EditHarness.create(validator: port, timer: timer);
    final spec = await h.begin();
    await pumpEventQueue();
    await spec.writeField(field: 'title', newValue: '新標題');
    final row = h.workspace.writeList.entries.single;
    expect(row.validationStatus, isA<ValidationRunning>());
    final prop = await _beginOther(h);
    await pumpEventQueue();
    timer.advance(const Duration(seconds: 5));
    await pumpEventQueue();
    await spec.validationIdle;
    expect(row.validationStatus, isA<ValidationFailed>());
    expect(prop.externalChangeWarning, isFalse);
    expect(prop.baseline, isA<Uint8List>());
  });

  test('C-4 W != H 的寫入帶快照 SHA；W = H 的寫入不帶（對照）', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    await session.writeField(field: 'title', newValue: 'a');
    await session.writeField(field: 'title', newValue: 'b');
    final rows = h.workspace.writeList.entries;
    expect(rows[0].snapshotSha, isNull);
    expect(rows[1].snapshotSha, FakeEditGitPort.defaultSha);
  });

  test('C-5 寫入不呼叫 git commit、add、stash', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    await session.writeField(field: 'title', newValue: 'a');
    await session.writeField(field: 'title', newValue: 'b');
    expect(
      h.git.subcommands,
      isNot(containsAny(<String>['commit', 'add', 'stash'])),
    );
  });

  test('未受理的寫入不進清單', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.files[h.path.absolute] = flipLastByte(h.target!);
    expect(
      await session.writeField(field: 'title', newValue: 'a'),
      isA<Blocked>(),
    );
    expect(h.workspace.writeList.entries, isEmpty);
  });
}

Matcher containsAny(List<String> items) =>
    anyOf([for (final item in items) contains(item)]);
