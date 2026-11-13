// edit domain 寫入路徑的 FR-07 語意層事件（test-design 0.11 L-2～L-7、L-9～L-11、
// L-19、L-25；1.0.0-W3-553.12.1）。L-1 集合相等守衛由 553.12.2 補齊後轉綠。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_file_port.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';
import '../../helpers/spec009/manual_edit_timer.dart';
import '../observability/observability_test_helpers.dart';

class _Entry {
  _Entry(this.event, this.payload, this.level, this.source, this.error);
  final EditLogEvent event;
  final Map<String, Object> payload;
  final LogLevel level;
  final ErrorSource? source;
  final Object? error;

  String get text => jsonEncode({
    'event': event.name,
    'payload': payload,
    'level': level.name,
    'source': source?.name,
    'error': error?.toString(),
  });
}

class _Recorder {
  final entries = <_Entry>[];

  void call(
    EditLogEvent event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) => entries.add(_Entry(event, fields.toJson(), level, source, error));

  List<EditLogEvent> get events => [for (final e in entries) e.event];

  /// 排除開啟工作區時的模式事件。
  List<_Entry> get afterOpen => [
    for (final e in entries)
      if (e.event != EditLogEvent.editModeDetermined) e,
  ];

  _Entry only(EditLogEvent event) =>
      entries.singleWhere((e) => e.event == event);

  String get text => entries.map((e) => e.text).join('\n');
}

/// W != H 的 repo，`hash-object` 以 [hashReply] 回應。
FakeEditGitPort _repoWithHash(FakeGitReply Function() hashReply) {
  final git = FakeEditGitPort.repo(head: fixtureBytes('${docPlainText}X'));
  final base = git.respond;
  git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'hash-object'
      ? hashReply()
      : base(args);
  return git;
}

Future<(EditHarness, _Recorder)> _harness({
  FakeEditGitPort? git,
  String? content,
  ManualEditTimer? timer,
}) async {
  final rec = _Recorder();
  final h = await EditHarness.create(
    git: git,
    content: content,
    timer: timer,
    logSink: rec.call,
  );
  return (h, rec);
}

void main() {
  group('L-2 W = M = H', () {
    test('依序記 writeIssued、writeAccepted，皆 info、無 error_source', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      final events = rec.afterOpen;
      expect(
        [for (final e in events) e.event],
        [EditLogEvent.writeIssued, EditLogEvent.writeAccepted],
      );
      for (final e in events) {
        expect(e.level, LogLevel.info);
        expect(e.source, isNull);
        expect(e.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.field: 'title',
        });
      }
    });
  });

  group('L-3 W != H', () {
    test('另記 snapshotTaken（info），blob_sha 為 40 字元小寫十六進位', () async {
      final (h, rec) = await _harness(
        git: FakeEditGitPort.repo(head: fixtureBytes('${docPlainText}X')),
      );
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.snapshotTaken);
      expect(e.level, LogLevel.info);
      expect(e.source, isNull);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.blobSha: FakeEditGitPort.defaultSha,
      });
      final sha = e.payload[EditLogKeys.blobSha]! as String;
      expect(RegExp(r'^[0-9a-f]{40}$').hasMatch(sha), isTrue);
    });

    test('正向對照：W = H 時沒有 snapshotTaken', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      expect(rec.events, isNot(contains(EditLogEvent.snapshotTaken)));
    });
  });

  group('L-4 閘門阻擋', () {
    test(
      '外部已改：writeBlocked(externallyModified)，warning、gate_blocked',
      () async {
        final (h, rec) = await _harness();
        final session = await h.begin();
        h.files.files[h.path.absolute] = fixtureBytes('$docPlainText外部');
        await session.writeField(field: 'title', newValue: '新標題');
        final e = rec.only(EditLogEvent.writeBlocked);
        expect(e.level, LogLevel.warning);
        expect(e.source, ErrorSource.gateBlocked);
        expect(e.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.reason: 'externallyModified',
        });
        expect(rec.events, isNot(contains(EditLogEvent.writeIssued)));
        expect(rec.events, isNot(contains(EditLogEvent.writeAccepted)));
      },
    );

    test(
      '改寫不隔離：writeBlocked(rewriteNotIsolated)，warning、gate_blocked',
      () async {
        final (h, rec) = await _harness(content: docAnchorText);
        final session = await h.begin();
        await session.writeField(field: 'title', newValue: '新標題');
        final e = rec.only(EditLogEvent.writeBlocked);
        expect(e.level, LogLevel.warning);
        expect(e.source, ErrorSource.gateBlocked);
        expect(e.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.reason: 'rewriteNotIsolated',
        });
        expect(rec.events, isNot(contains(EditLogEvent.writeIssued)));
      },
    );
  });

  group('L-5 hash-object 失敗（三擇一）', () {
    test('結束碼 128：帶 exitCode，不帶 executableMissing／timedOut', () async {
      final (h, rec) = await _harness(git: _repoWithHash(() => GitExit(128)));
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.writeBlocked);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.reason: 'snapshotFailed',
        EditLogKeys.exitCode: 128,
      });
      expect(rec.afterOpen, hasLength(1));
    });

    test('無法啟動：帶 executableMissing，不帶 exitCode', () async {
      final (h, rec) = await _harness(
        git: _repoWithHash(() => const GitLaunchFail()),
      );
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.writeBlocked);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.reason: 'snapshotFailed',
        EditLogKeys.executableMissing: true,
      });
      expect(rec.afterOpen, hasLength(1));
    });
  });

  group('L-6 IO 失敗分界', () {
    test('開始編輯讀取失敗（errorCode 13）：readIoFailed(readTarget)', () async {
      final (h, rec) = await _harness();
      h.files.readScript[1] = const EditFileException(errorCode: 13);
      await h.workspace.beginEditing(h.path);
      final e = rec.only(EditLogEvent.readIoFailed);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.platformIo);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.operation: 'readTarget',
        EditLogKeys.errorCode: 13,
      });
    });

    test('rename 前重讀失敗：readIoFailed(readBeforeRename)', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.readScript[2] = const EditFileException(errorCode: 13);
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.readIoFailed);
      expect(e.payload[EditLogKeys.operation], 'readBeforeRename');
      expect(e.payload[EditLogKeys.errorCode], 13);
      expect(rec.events, isNot(contains(EditLogEvent.writeIoFailed)));
    });

    test('rename 失敗：writeIoFailed(rename)，error、platform_io', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.failOp('rename', errorCode: 13);
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.writeIoFailed);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.platformIo);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.operation: 'rename',
        EditLogKeys.errorCode: 13,
      });
      expect(rec.events, isNot(contains(EditLogEvent.readIoFailed)));
    });
  });

  group('L-7 osError 為 null', () {
    test('writeIoFailed 不含 errorCode 欄位', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.failOp('write', errorCode: null);
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.writeIoFailed);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.operation: 'writeTemp',
      });
    });
  });

  group('L-9 守衛：欄位值不進日誌與錯誤型別', () {
    bool leaks(String text) => text.contains(secretMarker);

    test('偵測器自身：含標記的文字判為洩漏（正向對照）', () {
      expect(leaks('x $secretMarker y'), isTrue);
      expect(leaks('x y'), isFalse);
    });

    Future<void> failAndCheck(
      Future<(EditHarness, _Recorder)> Function() setup,
      void Function(EditHarness h) arrange,
      EditLogEvent expected,
    ) async {
      final (h, rec) = await setup();
      final session = await h.begin();
      arrange(h);
      final result = await session.writeField(
        field: 'title',
        newValue: secretMarker,
      );
      expect(rec.events, contains(expected), reason: '失敗事件必須存在，守衛才非空轉');
      expect(leaks(rec.text), isFalse);
      expect(leaks(result.toString()), isFalse);
      if (result is Blocked) expect(leaks(result.reason.toString()), isFalse);
      if (result is IoFailed) expect(leaks(result.failure.toString()), isFalse);
    }

    test('externallyModified', () {
      return failAndCheck(
        _harness,
        (h) => h.files.files[h.path.absolute] = fixtureBytes('$docPlainText外部'),
        EditLogEvent.writeBlocked,
      );
    });

    test('rewriteNotIsolated', () {
      return failAndCheck(
        () => _harness(content: docAnchorText),
        (_) {},
        EditLogEvent.writeBlocked,
      );
    });

    test('snapshotFailed', () {
      return failAndCheck(
        () => _harness(git: _repoWithHash(() => GitExit(128))),
        (_) {},
        EditLogEvent.writeBlocked,
      );
    });

    test('ioFailed', () {
      return failAndCheck(
        _harness,
        (h) => h.files.failOp('rename', errorCode: 13),
        EditLogEvent.writeIoFailed,
      );
    });

    test('正向對照：同一新值寫入成功時，標記確實送進寫入層', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      final result = await session.writeField(
        field: 'title',
        newValue: secretMarker,
      );
      expect(result, isA<Written>());
      expect(utf8.decode(h.target!), contains(secretMarker));
      expect(rec.events, contains(EditLogEvent.writeAccepted));
      expect(leaks(rec.text), isFalse);
    });
  });

  group('L-10 守衛：讀取失敗的例外訊息不進日誌', () {
    test('IoEditFilePort 讀取失敗轉為不帶訊息的例外', () async {
      final dir = Directory.systemTemp.createTempSync('edit_log_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final target = Directory('${dir.path}/$secretMarker')..createSync();
      try {
        await const IoEditFilePort().read(target.path);
        fail('讀取目錄應失敗');
      } on EditFileException catch (error) {
        expect(error.toString(), isNot(contains(secretMarker)));
      }
    });

    test('session 讀取失敗後的日誌與 IoFailed 不含標記', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.readScript[1] = const EditFileException(errorCode: 13);
      final result = await session.writeField(field: 'title', newValue: 'v');
      expect(rec.events, contains(EditLogEvent.readIoFailed));
      expect(rec.text, isNot(contains(secretMarker)));
      expect(
        (result as IoFailed).failure.toString(),
        isNot(contains(secretMarker)),
      );
    });
  });

  group('L-11 hash-object 逾時', () {
    test(
      '一筆 writeBlocked，帶 timedOut，不帶 exitCode 與 executableMissing',
      () async {
        final timer = ManualEditTimer();
        final (h, rec) = await _harness(
          git: _repoWithHash(() => const GitHang()),
          timer: timer,
        );
        final session = await h.begin();
        final writing = session.writeField(field: 'title', newValue: '新標題');
        await pumpEventQueue();
        timer.advance(const Duration(seconds: gitTimeoutSeconds));
        await writing;
        final e = rec.only(EditLogEvent.writeBlocked);
        expect(e.level, LogLevel.error);
        expect(e.source, ErrorSource.externalProcess);
        expect(e.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.reason: 'snapshotFailed',
          EditLogKeys.timedOut: true,
        });
        expect(rec.afterOpen, hasLength(1));
      },
    );

    test('show 逾時走快照分支，不記失敗事件', () async {
      final timer = ManualEditTimer();
      final git = FakeEditGitPort.repo(head: fixtureBytes(docPlainText));
      final base = git.respond;
      git.respond = (args) => FakeEditGitPort.subcommandOf(args) == 'show'
          ? const GitHang()
          : base(args);
      final (h, rec) = await _harness(git: git, timer: timer);
      final session = await h.begin();
      final writing = session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      timer.advance(const Duration(seconds: gitTimeoutSeconds));
      await writing;
      expect(rec.events, isNot(contains(EditLogEvent.writeBlocked)));
      expect(rec.events, contains(EditLogEvent.snapshotTaken));
    });
  });

  group('L-19 editModeDetermined', () {
    test('可寫：info、無 error_source、mode=writable', () async {
      final (_, rec) = await _harness();
      final e = rec.only(EditLogEvent.editModeDetermined);
      expect(e.level, LogLevel.info);
      expect(e.source, isNull);
      expect(e.payload, {EditLogKeys.mode: 'writable'});
      expect(rec.events, [EditLogEvent.editModeDetermined]);
    });

    test('git 無法啟動：唯讀 gitMissing，只有這一筆事件', () async {
      final (_, rec) = await _harness(
        git: FakeEditGitPort((_) => const GitLaunchFail()),
      );
      expect(rec.events, [EditLogEvent.editModeDetermined]);
      expect(rec.entries.single.source, isNull);
      expect(rec.entries.single.payload, {
        EditLogKeys.mode: 'readOnly',
        EditLogKeys.readonlyReason: 'gitMissing',
      });
    });

    test('rev-parse 逾時：唯讀 gitMissing，只有這一筆事件', () async {
      final rec = _Recorder();
      final timer = ManualEditTimer();
      final opening = EditWorkspace.open(
        root: Directory.systemTemp.path,
        git: FakeEditGitPort((_) => const GitHang()),
        files: FakeEditFilePort(),
        timer: timer.call,
        logSink: rec.call,
      );
      await pumpEventQueue();
      timer.advance(const Duration(seconds: gitTimeoutSeconds));
      await opening;
      expect(rec.events, [EditLogEvent.editModeDetermined]);
      expect(rec.entries.single.payload, {
        EditLogKeys.mode: 'readOnly',
        EditLogKeys.readonlyReason: 'gitMissing',
      });
    });
  });

  group('L-25 hash-object 三擇一邊界', () {
    test('結束碼 0 但輸出不是合法 SHA：帶結束碼 0', () async {
      final (h, rec) = await _harness(
        git: _repoWithHash(() => GitExit.text(0, 'not-a-sha\n')),
      );
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.writeBlocked);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.reason: 'snapshotFailed',
        EditLogKeys.exitCode: 0,
      });
    });

    test('等待結果時拋出執行期例外：帶 executableMissing', () async {
      final deferred = GitDeferred();
      final (h, rec) = await _harness(git: _repoWithHash(() => deferred));
      final session = await h.begin();
      final writing = session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      deferred.completer.completeError(StateError('boom'));
      await writing;
      final e = rec.only(EditLogEvent.writeBlocked);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.reason: 'snapshotFailed',
        EditLogKeys.executableMissing: true,
      });
    });
  });
}
