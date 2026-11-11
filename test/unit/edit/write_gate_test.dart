import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

/// 需求：[SPEC-009 FR-01] 寫入前閘門（test-design §3 G-1～G-23）。
final Uint8List _plain = fixtureBytes(docPlainText);
final Uint8List _other = fixtureBytes('${docPlainText}X');

Future<WriteResult> _writeTitle(EditSession session) =>
    session.writeField(field: 'title', newValue: '新標題');

void main() {
  test('G-1 W≠M：blocked(externallyModified)，無寫入、git 零呼叫', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.readScript[1] = flipLastByte(_plain);
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
    expect(h.files.kinds, isNot(contains('write')));
    expect(h.files.kinds, isNot(contains('rename')));
    expect(h.git.calls, isEmpty);
  });

  test('G-2 W=M≠H：先 show 再 hash-object，written 帶 SHA', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _other));
    final session = await h.begin();
    final result = await _writeTitle(session);
    expect(h.git.subcommands, ['show', 'hash-object']);
    expect(result, isA<Written>());
    expect((result as Written).snapshotSha, FakeEditGitPort.defaultSha);
  });

  test('G-3 W=M=H：written 不帶 SHA，只有 show', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    final result = await _writeTitle(session);
    expect(result, isA<Written>());
    expect((result as Written).snapshotSha, isNull);
    expect(h.git.subcommands, ['show']);
  });

  test('G-4 show 回 128 且路徑不在 HEAD：走快照分支', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo());
    final session = await h.begin();
    await _writeTitle(session);
    expect(h.git.subcommands, ['show', 'hash-object']);
  });

  test('G-5 show 回 128（其他訊息）與 1：都走快照分支', () async {
    for (final reply in [
      GitExit(128, stderr: 'fatal: bad object HEAD'),
      GitExit(1),
    ]) {
      final git = FakeEditGitPort.repo();
      final base = git.respond;
      git.respond = (args) =>
          FakeEditGitPort.subcommandOf(args) == 'show' ? reply : base(args);
      final h = await EditHarness.create(git: git);
      final session = await h.begin();
      await _writeTitle(session);
      expect(h.git.subcommands, ['show', 'hash-object']);
    }
  });

  test('G-6 比較的是位元組：非 UTF-8 的 W 與 H 相同時不快照', () async {
    final bytes = Uint8List.fromList([...fixtureBytes(docPlainText), 0xFF]);
    // 真實改寫經 Corpus 嚴格解碼會拒絕非 UTF-8 內文（見 Solution 的缺口記錄），
    // 此處以替身改寫器隔離出「W 與 H 的位元組比較」這一步。
    final h = await EditHarness.create(
      bytes: bytes,
      rewriter: ({
        required original,
        required field,
        newValue,
        required today,
      }) => FieldRewritten(original),
    );
    final session = await h.begin();
    final result = await _writeTitle(session);
    expect(result, isA<Written>());
    expect((result as Written).snapshotSha, isNull);
    expect(h.git.subcommands, ['show']);
  });

  test('G-7 快照失敗：blocked(snapshotFailed)，目標檔不變、無暫存檔', () async {
    final git = FakeEditGitPort.repo(head: _other);
    final base = git.respond;
    git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'hash-object'
        ? GitExit(128)
        : base(args);
    final h = await EditHarness.create(git: git);
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
    expect(h.files.kinds, isNot(contains('write')));
  });

  test('G-8 fsync 後目標檔被改：blocked(externallyModified)，暫存檔已刪', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    final changed = flipLastByte(_plain);
    h.files.afterOp('fsync', () => h.files.files[h.path.absolute] = changed);
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
    expect(h.strayFiles, isEmpty);
    expect(h.target, changed);
  });

  test('G-9 步驟 1 檔案不存在：blocked(externallyModified)', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.readScript[1] = const EditFileException(notFound: true);
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
  });

  test('G-10 步驟 1 讀取失敗 errorCode 13：ioFailed', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.readScript[1] = const EditFileException(errorCode: 13);
    final result = await _writeTitle(session);
    expect(result, isA<IoFailed>());
    expect((result as IoFailed).failure.errorCode, 13);
  });

  test('G-11 步驟 5 檔案不存在：blocked(externallyModified)，暫存檔已刪', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    h.files.readScript[2] = const EditFileException(notFound: true);
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
    expect(h.strayFiles, isEmpty);
  });

  test('G-12 改寫不隔離：blocked(rewriteNotIsolated)，git 零呼叫', () async {
    final h = await EditHarness.create(content: docAnchorText);
    final session = await h.begin();
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.rewriteNotIsolated,
      ),
    );
    expect(h.git.subcommands, isNot(contains('hash-object')));
    expect(h.git.calls, isEmpty);
  });

  test('G-13 show 引數恰為 -C <根> show HEAD:./<相對路徑>', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    await _writeTitle(session);
    expect(h.git.callOf('show').arguments, [
      '-C',
      h.root,
      'show',
      'HEAD:./$targetRelative',
    ]);
  });

  test('G-14 開始編輯讀取失敗：回傳讀取失敗，不產生 session', () async {
    final h = await EditHarness.create();
    h.files.readScript[1] = const EditFileException(errorCode: 13);
    final result = await h.workspace.beginEditing(h.path);
    expect(result, isA<EditingReadFailed>());
  });

  test('G-15 M 取自開始編輯的讀取：W 等於該位元組時不判外部已改', () async {
    final h = await EditHarness.create(content: '${docPlainText}ZZ');
    final session = await h.begin();
    expect(session.baseline, h.target);
    expect(await _writeTitle(session), isA<Written>());
  });

  group('G-16 唯讀降級', () {
    for (final reply in [
      GitExit(128, stderr: 'fatal: not a git repository'),
      const GitLaunchFail(),
    ]) {
      test('探測回報 ${reply.runtimeType}：beginEditing 為唯讀、零寫入', () async {
        final h = await EditHarness.create(git: FakeEditGitPort((_) => reply));
        final result = await h.workspace.beginEditing(h.path);
        expect(h.workspace.mode, EditMode.readOnly);
        expect(result, isA<EditingReadOnly>());
        expect(h.files.kinds, isNot(contains('write')));
        expect(h.files.kinds, isNot(contains('rename')));
      });
    }

    test('正向對照：探測回報為 repo 時可寫', () async {
      final h = await EditHarness.create();
      expect(h.workspace.mode, EditMode.writable);
      expect(await h.workspace.beginEditing(h.path), isA<EditingStarted>());
    });
  });

  test('G-17 編輯中 git 變為無法啟動且 W=M≠H：blocked(snapshotFailed)', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _other));
    final session = await h.begin();
    h.git.respond = (_) => const GitLaunchFail();
    expect(
      await _writeTitle(session),
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.snapshotFailed,
      ),
    );
  });

  test('G-18 每次 git 呼叫（含探測）環境都含 LC_ALL=C', () async {
    final h = await EditHarness.create(git: FakeEditGitPort.repo(head: _other));
    final session = await h.begin();
    await _writeTitle(session);
    expect(h.git.calls, isNotEmpty);
    for (final call in h.git.calls) {
      expect(call.environment['LC_ALL'], 'C');
    }
  });

  test('G-18 探測呼叫（EditWorkspace.open）環境含 LC_ALL=C', () async {
    final h = await EditHarness.create();
    expect(h.probeCalls, hasLength(1));
    expect(h.probeCalls.single.arguments, contains('rev-parse'));
    expect(h.probeCalls.single.environment['LC_ALL'], 'C');
  });

  test('G-19 連續兩次寫入：第二次以第一次落檔位元組為 M，不被擋', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    expect(await _writeTitle(session), isA<Written>());
    final second = await session.writeField(field: 'status', newValue: 'done');
    expect(second, isA<Written>());
  });

  group('G-20 非 written 不更新 M', () {
    test('rewriteNotIsolated 之後', () async {
      final h = await EditHarness.create(content: docAnchorText);
      final session = await h.begin();
      expect(await _writeTitle(session), isA<Blocked>());
      expect(
        await session.writeField(field: 'id', newValue: 'PROP-999'),
        isA<Written>(),
      );
    });

    test('ioFailed（步驟 4 失敗）之後', () async {
      final h = await EditHarness.create();
      final session = await h.begin();
      h.files.failOp('write');
      expect(await _writeTitle(session), isA<IoFailed>());
      h.files.clearFaults();
      expect(
        await session.writeField(field: 'status', newValue: 'done'),
        isA<Written>(),
      );
    });

    test('snapshotFailed 之後', () async {
      final git = FakeEditGitPort.repo(head: _other);
      final base = git.respond;
      var hashCalls = 0;
      git.respond = (args) =>
          FakeEditGitPort.subcommandOf(args) == 'hash-object' &&
              hashCalls++ == 0
          ? GitExit(128)
          : base(args);
      final h = await EditHarness.create(git: git);
      final session = await h.begin();
      expect(await _writeTitle(session), isA<Blocked>());
      expect(h.target, _plain);
      expect(
        await session.writeField(field: 'status', newValue: 'done'),
        isA<Written>(),
      );
    });
  });

  test('G-21 鑑別力：M 停在開始編輯時的 session 會被判外部已改', () async {
    final h = await EditHarness.create();
    final updating = await h.begin();
    final stale = await h.begin(); // 模擬「M 停在開始編輯時」的錯誤實作行為
    expect(await _writeTitle(updating), isA<Written>());
    final result = await stale.writeField(field: 'status', newValue: 'done');
    expect(
      result,
      isA<Blocked>().having(
        (b) => b.reason,
        'reason',
        BlockedReason.externallyModified,
      ),
    );
    // 正向對照（G-19）：更新 M 的 session 第二次寫入被受理。
    expect(
      await updating.writeField(field: 'priority', newValue: 'P0'),
      isA<Written>(),
    );
  });

  test('G-22 show 逾時 5 秒：子行程被終止，走快照分支', () async {
    final git = FakeEditGitPort.repo(head: _other);
    final base = git.respond;
    git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'show'
        ? const GitHang()
        : base(args);
    final h = await EditHarness.create(git: git);
    final session = await h.begin();
    final pending = _writeTitle(session);
    await pumpEventQueue();
    h.timer.advance(const Duration(seconds: 5));
    final result = await pending;
    expect(h.git.killed.single, contains('show'));
    expect(h.git.subcommands, ['show', 'hash-object']);
    expect((result as Written).snapshotSha, FakeEditGitPort.defaultSha);
  });

  test('G-23 本地檔案讀取 60 秒後才完成：不產生逾時結果', () async {
    final h = await EditHarness.create();
    final session = await h.begin();
    final slow = Completer<Uint8List>();
    h.files.readScript[1] = slow.future;
    final pending = _writeTitle(session);
    await pumpEventQueue();
    h.timer.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    slow.complete(_plain);
    expect(await pending, isA<Written>());
    expect(h.git.killed, isEmpty);
  });
}
