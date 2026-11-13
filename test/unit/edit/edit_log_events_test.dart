// edit domain 日誌事件碼契約（SPEC-010 FR-02、FR-04；1.0.0-W3-553.2.3.4.1）。
//
// 斷言綁事件碼、等級、error_source 與白名單負載，不比對訊息文字。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_edit_file_port.dart';
import '../../helpers/spec009/fake_edit_git_port.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';
import '../../helpers/spec009/manual_edit_timer.dart';

class _Entry {
  _Entry(this.event, this.payload, this.level, this.source, this.error);
  final EditLogEvent event;
  final Map<String, Object> payload;
  final LogLevel level;
  final ErrorSource? source;
  final Object? error;
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

  _Entry only(EditLogEvent event) =>
      entries.singleWhere((e) => e.event == event);
}

void main() {
  group('editModeDetermined', () {
    test('可寫：info、無 error_source、mode=writable', () async {
      final rec = _Recorder();
      await EditHarness.create(logSink: rec.call);
      final e = rec.only(EditLogEvent.editModeDetermined);
      expect(e.level, LogLevel.info);
      expect(e.source, isNull);
      expect(e.payload, {EditLogKeys.mode: 'writable'});
    });

    test('git 無法啟動：gitLaunchFailed（external_process）加唯讀 gitMissing', () async {
      final rec = _Recorder();
      await EditHarness.create(
        git: FakeEditGitPort((_) => const GitLaunchFail()),
        logSink: rec.call,
      );
      final failed = rec.only(EditLogEvent.gitLaunchFailed);
      expect(failed.level, LogLevel.warning);
      expect(failed.source, ErrorSource.externalProcess);
      expect(failed.error, isNotNull);
      expect(rec.only(EditLogEvent.editModeDetermined).payload, {
        EditLogKeys.mode: 'readOnly',
        EditLogKeys.readonlyReason: 'gitMissing',
      });
    });

    test('git 逾時：gitTimedOut（external_process），不帶 error 物件', () async {
      final rec = _Recorder();
      final timer = ManualEditTimer();
      final opening = EditWorkspace.open(
        root: Directory.systemTemp.path,
        git: FakeEditGitPort((_) => const GitHang()),
        files: FakeEditFilePort(),
        timer: timer.call,
        logSink: rec.call,
      );
      await Future<void>.delayed(Duration.zero);
      timer.advance(const Duration(seconds: gitTimeoutSeconds));
      await opening;
      final e = rec.only(EditLogEvent.gitTimedOut);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.level, LogLevel.warning);
      expect(e.error, isNull);
    });

    test('git 執行期拋例外：gitRunFailed（external_process），例外走 error', () async {
      final rec = _Recorder();
      final deferred = GitDeferred();
      final opening = EditWorkspace.open(
        root: Directory.systemTemp.path,
        git: FakeEditGitPort((_) => deferred),
        files: FakeEditFilePort(),
        logSink: rec.call,
      );
      await Future<void>.delayed(Duration.zero);
      deferred.completer.completeError(StateError('boom'));
      await opening;
      final e = rec.only(EditLogEvent.gitRunFailed);
      expect(e.source, ErrorSource.externalProcess);
      expect(e.error, isA<StateError>());
    });
  });

  group('session 與 workspace 的 IO 失敗', () {
    test('rename 失敗：ioFailed error／platform_io，負載為操作與錯誤碼', () async {
      final rec = _Recorder();
      final h = await EditHarness.create(logSink: rec.call);
      final session = await h.begin();
      h.files.failOp('rename', errorCode: 13);
      await session.writeField(field: 'title', newValue: '新標題');
      final e = rec.only(EditLogEvent.ioFailed);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.platformIo);
      expect(e.payload, {
        EditLogKeys.operation: 'rename',
        EditLogKeys.errorCode: 13,
      });
    });

    test('開始編輯讀取目標失敗：beginEditingReadFailed 無錯誤碼時空負載', () async {
      final rec = _Recorder();
      final h = await EditHarness.create(logSink: rec.call);
      h.files.files.remove(h.path.absolute);
      await h.workspace.beginEditing(h.path);
      final e = rec.only(EditLogEvent.beginEditingReadFailed);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.platformIo);
      expect(e.payload, isEmpty);
    });
  });

  group('驗證事件', () {
    test(
      '驗證通過：baselineMeasured 與 validationCompleted(passed) 為 info 且無來源',
      () async {
        final rec = _Recorder();
        final h = await EditHarness.create(
          validator: FakeValidatorPort(),
          logSink: rec.call,
        );
        final session = await h.begin();
        await session.baselineIdle;
        await session.writeField(field: 'title', newValue: '新標題');
        await session.validationIdle;
        final baseline = rec.only(EditLogEvent.baselineMeasured);
        expect(baseline.level, LogLevel.info);
        expect(baseline.payload, {
          EditLogKeys.path: targetRelative,
          EditLogKeys.measure: 'ready',
        });
        final done = rec.only(EditLogEvent.validationCompleted);
        expect(done.level, LogLevel.info);
        expect(done.source, isNull);
        expect(done.payload[EditLogKeys.outcome], 'passed');
      },
    );

    test(
      '驗證器無法啟動：validatorLaunchFailed 帶 tool，結果為 unavailable 且不重記來源',
      () async {
        final rec = _Recorder();
        final h = await EditHarness.create(
          validator: FakeValidatorPort(
            validate: const [ValidatorLaunchFail(), ValidatorLaunchFail()],
          ),
          logSink: rec.call,
        );
        final session = await h.begin();
        await session.baselineIdle;
        await session.writeField(field: 'title', newValue: '新標題');
        await session.validationIdle;
        final failed = rec.entries
            .where((e) => e.event == EditLogEvent.validatorLaunchFailed)
            .first;
        expect(failed.level, LogLevel.warning);
        expect(failed.source, ErrorSource.externalProcess);
        expect(failed.payload, {EditLogKeys.tool: 'docValidate'});
        final done = rec.only(EditLogEvent.validationCompleted);
        expect(done.level, LogLevel.warning);
        expect(done.source, isNull);
        expect(done.payload[EditLogKeys.outcome], 'unavailable');
        expect(
          done.payload[EditLogKeys.unavailableReason],
          'executableMissing',
        );
      },
    );
  });

  group('rewriteNotIsolated', () {
    test('anchor 檔：error／gate_blocked，負載為拒絕原因', () {
      final rec = _Recorder();
      final result = rewriteFrontmatterField(
        original: fixtureBytes(docAnchorText),
        field: 'title',
        newValue: '新標題',
        today: DateTime(2026, 11, 10),
        logSink: rec.call,
      );
      expect(result, isA<FieldRewriteNotIsolated>());
      final e = rec.only(EditLogEvent.rewriteNotIsolated);
      expect(e.level, LogLevel.error);
      expect(e.source, ErrorSource.gateBlocked);
      expect(e.payload, {EditLogKeys.reason: 'targetNotRewritable'});
    });

    test('正向對照：可改寫的檔不發事件', () {
      final rec = _Recorder();
      rewriteFrontmatterField(
        original: fixtureBytes(docPlainText),
        field: 'title',
        newValue: '新標題',
        today: DateTime(2026, 11, 10),
        logSink: rec.call,
      );
      expect(rec.events, isEmpty);
    });
  });

  group('IoEditFilePort.delete', () {
    test('暫存路徑是目錄而刪除失敗：tempDeleteFailed（platform_io，warning）', () async {
      final rec = _Recorder();
      final dir = Directory.systemTemp.createTempSync('edit_log_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final subdir = Directory('${dir.path}/subdir')..createSync();
      await IoEditFilePort(logSink: rec.call).delete(subdir.path);
      final e = rec.only(EditLogEvent.tempDeleteFailed);
      expect(e.level, LogLevel.warning);
      expect(e.source, ErrorSource.platformIo);
      expect(e.error, isA<FileSystemException>());
    });

    test('正向對照：目標不存在不發事件', () async {
      final rec = _Recorder();
      final dir = Directory.systemTemp.createTempSync('edit_log_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await IoEditFilePort(logSink: rec.call).delete('${dir.path}/absent');
      expect(rec.events, isEmpty);
    });
  });
}
