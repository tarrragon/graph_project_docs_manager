// edit domain 的 FR-07 語意層事件（test-design 0.11 L-2～L-7、L-9～L-11、
// L-19、L-25：1.0.0-W3-553.12.1；L-1、L-8、L-12、L-20～L-24：1.0.0-W3-553.12.2）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_file_port.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/fake_validator_port.dart';
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
  FakeValidatorPort? validator,
}) async {
  final rec = _Recorder();
  final h = await EditHarness.create(
    git: git,
    content: content,
    timer: timer,
    validator: validator,
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

  group('L-1 事件集合等於 FR-07 表中未標 1.1 的列', () {
    test('集合相等', () {
      final spec = File(_specPath).readAsStringSync();
      final expected = _specEventNames(spec);
      expect(expected, isNotEmpty);
      expect({for (final e in EditLogEvent.values) e.name}, expected);
    });

    test('正向對照：表多一列或少一列時比對為紅', () {
      final actual = {for (final e in EditLogEvent.values) e.name};
      final spec = File(_specPath).readAsStringSync();
      final base = _specEventNames(spec);
      expect(actual, base);
      expect(actual, isNot(equals({...base, 'extraEvent'})));
      expect(actual, isNot(equals(base.difference({'writeIssued'}))));
    });

    test('解析器：標 1.1 的列不計入', () {
      const table =
          '日誌事件 enum\n'
          '| 事件 | level |\n|---|---|\n'
          '| `a` | info |\n'
          '| `b`（1.1） | info |\n'
          '| `c`（原因 `x`） | info |\n'
          '**約束條件**\n| `d` | info |\n';
      expect(_specEventNames(table), {'a', 'c'});
    });
  });

  group('L-8 驗證完成', () {
    test('passed 為 info、無 error_source，帶節點 ID', () async {
      final (h, rec) = await _harness(validator: FakeValidatorPort());
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationCompleted);
      expect(e.level, LogLevel.info);
      expect(e.source, isNull);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.nodeId: 'SPEC-900',
        EditLogKeys.outcome: 'passed',
      });
    });

    test('failed 為 warning、無 error_source，帶新增問題數', () async {
      final (h, rec) = await _harness(
        validator: FakeValidatorPort(
          ucVerify: const [validatorOk, ValidatorExit(1, 'x.md:1:ZZ-99')],
        ),
      );
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationCompleted);
      expect(e.level, LogLevel.warning);
      expect(e.source, isNull);
      expect(e.payload[EditLogKeys.outcome], 'failed');
      expect(e.payload[EditLogKeys.newIssueCount], 1);
    });

    test('unavailable（結束碼 3）為 warning、external_process，帶結束碼', () async {
      final (h, rec) = await _harness(
        validator: FakeValidatorPort(
          validate: const [validatorOk, ValidatorExit(3)],
        ),
      );
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationCompleted);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.nodeId: 'SPEC-900',
        EditLogKeys.outcome: 'unavailable',
        EditLogKeys.exitCode: 3,
      });
      expect(
        rec.events.where((e) => e == EditLogEvent.validationCompleted),
        hasLength(1),
      );
    });
  });

  group('L-12 驗證逾時', () {
    test('帶原因 timedOut，不帶結束碼，external_process', () async {
      final timer = ManualEditTimer();
      final (h, rec) = await _harness(
        timer: timer,
        validator: FakeValidatorPort(
          validate: const [validatorOk, ValidatorHang()],
        ),
      );
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      timer.advance(const Duration(seconds: validatorTimeoutSeconds));
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationCompleted);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.payload[EditLogKeys.unavailableReason], 'timedOut');
      expect(e.payload.containsKey(EditLogKeys.exitCode), isFalse);
    });
  });

  group('L-20 baselineMeasured', () {
    test('ready：info、無 error_source', () async {
      final (h, rec) = await _harness(validator: FakeValidatorPort());
      final session = await h.begin();
      await session.baselineIdle;
      final e = rec.only(EditLogEvent.baselineMeasured);
      expect(e.level, LogLevel.info);
      expect(e.source, isNull);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.measure: 'ready',
      });
    });

    test(
      'doc validate 結束碼 3：unavailable、external_process、帶結束碼，無另一筆失敗事件',
      () async {
        final (h, rec) = await _harness(
          validator: FakeValidatorPort(validate: const [ValidatorExit(3)]),
        );
        final session = await h.begin();
        await session.baselineIdle;
        final e = rec.only(EditLogEvent.baselineMeasured);
        expect(e.level, LogLevel.warning);
        expect(e.source, ErrorSource.externalProcess);
        expect(e.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.measure: 'unavailable',
          EditLogKeys.exitCode: 3,
        });
        expect(rec.afterOpen, hasLength(1));
      },
    );

    test('無法啟動：改帶原因 enum，不帶結束碼', () async {
      final (h, rec) = await _harness(
        validator: FakeValidatorPort(validate: const [ValidatorLaunchFail()]),
      );
      final session = await h.begin();
      await session.baselineIdle;
      final e = rec.only(EditLogEvent.baselineMeasured);
      expect(e.payload[EditLogKeys.unavailableReason], 'executableMissing');
      expect(e.payload.containsKey(EditLogKeys.exitCode), isFalse);
    });
  });

  group('L-21 守衛：沿用 baseline 原因不重記 external_process', () {
    test('baseline unavailable 後寫入：validationCompleted 不帶來源，整體恰一筆', () async {
      final (h, rec) = await _harness(
        validator: FakeValidatorPort(validate: const [ValidatorExit(3)]),
      );
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final done = rec.only(EditLogEvent.validationCompleted);
      expect(done.payload[EditLogKeys.outcome], 'unavailable');
      expect(done.source, isNull);
      expect(
        rec.entries.where((e) => e.source == ErrorSource.externalProcess),
        hasLength(1),
      );
    });

    test('正向對照：baseline ready、寫入後結束碼 3 時 validationCompleted 帶來源', () async {
      final (h, rec) = await _harness(
        validator: FakeValidatorPort(
          validate: const [validatorOk, ValidatorExit(3)],
        ),
      );
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      expect(
        rec.only(EditLogEvent.validationCompleted).source,
        ErrorSource.externalProcess,
      );
    });
  });

  group('L-22 baselineNotReady', () {
    test('baseline 未完成即寫入：不帶 error_source，原因 baselineNotReady', () async {
      final timer = ManualEditTimer();
      final (h, rec) = await _harness(
        timer: timer,
        validator: FakeValidatorPort(
          timer: timer,
          ucVerify: const [
            ValidatorAfter(Duration(seconds: 10), 0),
            validatorOk,
          ],
        ),
      );
      final session = await h.begin();
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationCompleted);
      expect(e.source, isNull);
      expect(e.payload[EditLogKeys.unavailableReason], 'baselineNotReady');
      timer.advance(const Duration(seconds: 10));
      await session.baselineIdle;
    });
  });

  group('L-23 internal 失敗', () {
    test('baseline 量測拋出未預期例外：一筆 baselineFailed', () async {
      final (h, rec) = await _harness(validator: _ThrowingValidatorPort(0));
      final session = await h.begin();
      await session.baselineIdle;
      final e = rec.only(EditLogEvent.baselineFailed);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.internal);
      expect(e.payload, {EditLogKeys.path: targetRelative});
    });

    test('驗證佇列工作拋出未預期例外：一筆 validationJobFailed', () async {
      final (h, rec) = await _harness(validator: _ThrowingValidatorPort(2));
      final session = await h.begin();
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: '新標題');
      await session.validationIdle;
      final e = rec.only(EditLogEvent.validationJobFailed);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.internal);
      expect(e.payload, {EditLogKeys.path: targetRelative});
      expect(rec.events, isNot(contains(EditLogEvent.baselineFailed)));
      expect(rec.events, isNot(contains(EditLogEvent.validationCompleted)));
    });
  });

  group('L-24 tempDeleteFailed', () {
    test('rename 失敗後刪暫存檔也失敗：writeIoFailed 與 tempDeleteFailed 各一', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.failOp('rename', errorCode: 13);
      h.files.failOp('delete', errorCode: 13);
      await session.writeField(field: 'title', newValue: '新標題');
      expect(
        rec.only(EditLogEvent.writeIoFailed).payload,
        containsPair(EditLogKeys.operation, 'rename'),
      );
      final e = rec.only(EditLogEvent.tempDeleteFailed);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.platformIo);
      expect(e.payload, {
        EditLogKeys.path: targetRelative,
        EditLogKeys.errorCode: 13,
      });
    });

    test('正向對照：暫存檔刪除成功時只有 writeIoFailed', () async {
      final (h, rec) = await _harness();
      final session = await h.begin();
      h.files.failOp('rename', errorCode: 13);
      await session.writeField(field: 'title', newValue: '新標題');
      expect(rec.events, isNot(contains(EditLogEvent.tempDeleteFailed)));
      expect(rec.events, contains(EditLogEvent.writeIoFailed));
    });

    test('IoEditFilePort.delete：目錄刪除失敗拋 EditFileException，不自行記日誌', () async {
      final dir = Directory.systemTemp.createTempSync('edit_log_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final subdir = Directory('${dir.path}/subdir')..createSync();
      await expectLater(
        const IoEditFilePort().delete(subdir.path),
        throwsA(isA<EditFileException>()),
      );
    });

    test('正向對照：IoEditFilePort.delete 目標不存在不拋', () async {
      final dir = Directory.systemTemp.createTempSync('edit_log_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await const IoEditFilePort().delete('${dir.path}/absent');
    });
  });
}

const _specPath = 'docs/spec/edit/SPEC-009-edit-write-path.md';

/// FR-07 事件表中未標（1.1）的事件名。
Set<String> _specEventNames(String spec) {
  final start = spec.indexOf('日誌事件 enum');
  final end = spec.indexOf('**約束條件**', start);
  final names = <String>{};
  for (final line in spec.substring(start, end).split('\n')) {
    final cells = line.split('|');
    if (cells.length < 3) continue;
    final name = RegExp(r'`(\w+)`').firstMatch(cells[1])?.group(1);
    if (name != null && !cells[1].contains('（1.1）')) names.add(name);
  }
  return names;
}

/// 前 [okCalls] 次呼叫回傳成功，之後拋出未預期例外。
class _ThrowingValidatorPort extends FakeValidatorPort {
  _ThrowingValidatorPort(this.okCalls);

  final int okCalls;
  int _seen = 0;

  @override
  Future<EditValidatorCall> start(EditValidatorInvocation invocation) {
    if (_seen++ >= okCalls) throw StateError('boom');
    return super.start(invocation);
  }
}
