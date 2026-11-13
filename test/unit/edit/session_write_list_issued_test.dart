import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

/// 需求：[SPEC-001 §12／SPEC-009 FR-08] 所有發出過的寫入都成列，不只
/// `written`；列附所屬專案；發出後到受理前為寫入中（1.0.0-W3-553.17.1）。
final Uint8List _plain = fixtureBytes(docPlainText);

Future<WriteResult> _write(EditSession s) =>
    s.writeField(field: 'title', newValue: '新標題');

void main() {
  test('對照：同一 fixture 下 written、ioFailed、blocked 各發一次，三列皆成列', () async {
    final h = await EditHarness.create();
    final s = await h.begin();
    expect(await _write(s), isA<Written>());
    h.files.resetCounters();
    h.files.readScript[1] = const EditFileException(errorCode: 13);
    expect(await _write(s), isA<IoFailed>());
    h.files.resetCounters();
    h.files.readScript[1] = flipLastByte(_plain);
    expect(await _write(s), isA<Blocked>());
    expect(h.workspace.writeList.entries.length, 3);
  });

  test('blocked(externallyModified) 成列', () async {
    final h = await EditHarness.create();
    final s = await h.begin();
    h.files.readScript[1] = flipLastByte(_plain);
    await _write(s);
    final e = h.workspace.writeList.entries.single;
    expect((e.relativePath, e.field), (targetRelative, 'title'));
    expect(e.workspaceRoot, h.root);
    expect(
      e.result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
  });

  test('blocked(snapshotFailed) 成列', () async {
    final git = FakeEditGitPort.repo(head: fixtureBytes('${docPlainText}X'));
    final base = git.respond;
    git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'hash-object'
        ? GitExit(128)
        : base(args);
    final h = await EditHarness.create(git: git);
    final s = await h.begin();
    await _write(s);
    expect(
      h.workspace.writeList.entries.single.result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.snapshotFailed,
      ),
    );
  });

  test('blocked(rewriteNotIsolated) 成列', () async {
    final h = await EditHarness.create(content: docAnchorText);
    final s = await h.begin();
    await _write(s);
    expect(
      h.workspace.writeList.entries.single.result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.rewriteNotIsolated,
      ),
    );
  });

  test('ioFailed 成列', () async {
    final h = await EditHarness.create();
    final s = await h.begin();
    h.files.readScript[1] = const EditFileException(errorCode: 13);
    await _write(s);
    expect(h.workspace.writeList.entries.single.result, isA<IoFailed>());
  });

  test('寫入中：發出後到受理前該列 result 為 null，受理後就地更新同一列', () async {
    final h = await EditHarness.create();
    final s = await h.begin();
    final pending = _write(s);
    final list = h.workspace.writeList;
    final during = list.entries.single;
    expect(during.result, isNull);
    await pending;
    expect(list.entries.single, same(during));
    expect(during.result, isA<Written>());
  });

  test('written 列附所屬專案；發出與結局各通知一次', () async {
    final h = await EditHarness.create();
    final s = await h.begin();
    var changes = 0;
    h.workspace.writeList.changes.listen((_) => changes++);
    await _write(s);
    final e = h.workspace.writeList.entries.single;
    expect(e.workspaceRoot, h.root);
    expect(e.result, isA<Written>());
    expect(changes, 2);
  });
}
