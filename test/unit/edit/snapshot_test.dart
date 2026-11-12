import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/restore_instruction.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

/// 需求：[SPEC-009 FR-02] 快照（test-design §3 S-1～S-7）。
final Uint8List _plain = fixtureBytes(docPlainText);
final Uint8List _head = fixtureBytes('${docPlainText}X');

Future<WriteResult> _writeTitle(EditSession session) =>
    session.writeField(field: 'title', newValue: '新標題');

FakeEditGitPort _repoWithHash(FakeGitReply Function() hashReply) {
  final git = FakeEditGitPort.repo(head: _head);
  final base = git.respond;
  git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'hash-object'
      ? hashReply()
      : base(args);
  return git;
}

void main() {
  test('S-1 引數恰為 hash-object -w --stdin，標準輸入為 W', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _head));
    final session = await h.begin();
    await _writeTitle(session);
    final call = h.git.callOf('hash-object');
    expect(call.arguments, ['-C', h.root, 'hash-object', '-w', '--stdin']);
    expect(call.arguments, isNot(contains('--path')));
    expect(call.arguments, isNot(contains(h.path.relative)));
    expect(call.stdin, _plain);
  });

  test('S-2 hash-object 回傳 40 字元 SHA：written 帶該 SHA', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _head));
    final session = await h.begin();
    expect(
      await _writeTitle(session),
      isA<Written>().having(
        (w) => w.snapshotSha,
        'sha',
        FakeEditGitPort.defaultSha,
      ),
    );
  });

  test('S-3 hash-object 無法啟動：blocked(snapshotFailed)，目標檔不變', () async {
    final h = await EditHarness.create(
      git: _repoWithHash(() => const GitLaunchFail()),
    );
    final session = await h.begin();
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.snapshotFailed,
      ),
    );
    expect(h.target, _plain);
  });

  test('S-4 取回說明：有快照與無快照', () {
    const path = 'docs/spec/x/SPEC-900.md';
    expect(
      restoreInstruction(
        relativePath: path,
        snapshotSha: FakeEditGitPort.defaultSha,
      ),
      'git cat-file -p ${FakeEditGitPort.defaultSha} > $path',
    );
    expect(
      restoreInstruction(relativePath: path),
      'git checkout HEAD -- $path',
    );
  });

  test('S-5 git 呼叫不含 add／stash／update-ref／commit／reset／checkout', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _head));
    final session = await h.begin();
    await _writeTitle(session);
    const banned = {
      'add',
      'stash',
      'update-ref',
      'commit',
      'reset',
      'checkout',
    };
    expect(h.git.subcommands.toSet().intersection(banned), isEmpty);
    expect(h.git.subcommands, contains('hash-object'));
  });

  test('S-6 hash-object 逾時 5 秒：終止、snapshotFailed、目標檔不變', () async {
    final h = await EditHarness.create(
      git: _repoWithHash(() => const GitHang()),
    );
    final session = await h.begin();
    final pending = _writeTitle(session);
    await pumpEventQueue();
    h.timer.advance(const Duration(seconds: 5));
    final result = await pending;
    expect(h.git.killed.single, contains('hash-object'));
    expect(
      result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.snapshotFailed,
      ),
    );
    expect(h.target, _plain);
    expect(h.files.kinds, isNot(contains('write')));
  });

  test('S-7 對照：4.9 秒回傳 SHA，不提前終止', () async {
    final deferred = GitDeferred();
    final h = await EditHarness.create(git: _repoWithHash(() => deferred));
    final session = await h.begin();
    final pending = _writeTitle(session);
    await pumpEventQueue();
    h.timer.advance(const Duration(milliseconds: 4900));
    await pumpEventQueue();
    deferred.completer.complete(
      EditGitResult(
        exitCode: 0,
        stdout: fixtureBytes('${FakeEditGitPort.defaultSha}\n'),
      ),
    );
    final result = await pending;
    expect(h.git.killed, isEmpty);
    expect(result, isA<Written>());
  });
}
