// edit domain 日誌事件碼契約中屬驗證路徑與下層檔案刪除的部分（SPEC-010 FR-02、
// FR-04；1.0.0-W3-553.2.3.4.1）。寫入路徑的語意層事件見 edit_log_test.dart
// （1.0.0-W3-553.12.1）；本檔剩餘事件由 1.0.0-W3-553.12.2 收合。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';

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
