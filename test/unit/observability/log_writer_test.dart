import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_file_port.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/observability/log_writer.dart';

import 'observability_test_helpers.dart';

const int _mib = 1024 * 1024;

({LogWriter writer, FakeLogFilePort port, RecordingDevLog dev}) _make({
  int rotateBytes = 5 * _mib,
}) {
  final port = FakeLogFilePort();
  final dev = RecordingDevLog();
  final writer = LogWriter(
    port: port,
    devLog: dev.call,
    clock: fixedClock,
    rotateBytes: rotateBytes,
  );
  return (writer: writer, port: port, dev: dev);
}

void _info(
  LogWriter w, {
  LogLevel level = LogLevel.info,
  String domain = 'graph',
}) => w.log(domain, TestEvent.sampleCompleted, LogFields.empty, level: level);

void main() {
  group('落地與輪替', () {
    test('O5-1 目錄為 <home>/Library/Logs/<bundle id>，原始碼無 bundle id 字面值', () {
      expect(
        logDirectoryPath(home: '/h', bundleId: 'x.y.z'),
        '/h/Library/Logs/x.y.z',
      );
      for (final f in Directory('lib/observability').listSync()) {
        if (f is File) {
          expect(f.readAsStringSync(), isNot(contains('com.example')));
        }
      }
    });

    test('O5-2 首次寫入前建立目錄', () async {
      final t = _make();
      _info(t.writer);
      await t.writer.flush();
      expect(t.port.ensureCalls, 1);
      expect(t.port.files['app.jsonl'], isNotNull);
    });

    test('O5-3 5 MiB - 1 不輪替', () async {
      final t = _make();
      t.port.files['app.jsonl'] = 'old\n';
      t.port.sizeOverride['app.jsonl'] = 5 * _mib - 1;
      _info(t.writer);
      await t.writer.flush();
      expect(t.port.files.containsKey('app.1.jsonl'), isFalse);
      expect(t.port.files['app.jsonl'], startsWith('old\n'));
    });

    test('O5-4 恰 5 MiB 先輪替', () async {
      final t = _make();
      t.port.files['app.jsonl'] = 'old\n';
      t.port.sizeOverride['app.jsonl'] = 5 * _mib;
      _info(t.writer);
      await t.writer.flush();
      expect(t.port.files['app.1.jsonl'], 'old\n');
      expect('\n'.allMatches(t.port.files['app.jsonl']!).length, 1);
      expect(t.port.files['app.jsonl'], isNot(contains('old')));
    });

    test('O5-5 已有 4 個歷史檔時刪最舊、其餘順移', () async {
      final t = _make();
      for (var n = 1; n <= 4; n++) {
        t.port.files['app.$n.jsonl'] = 'h$n\n';
      }
      t.port.files['app.jsonl'] = 'cur\n';
      t.port.sizeOverride['app.jsonl'] = 5 * _mib;
      _info(t.writer);
      await t.writer.flush();
      expect(t.port.files.keys.toSet(), {
        'app.jsonl',
        'app.1.jsonl',
        'app.2.jsonl',
        'app.3.jsonl',
        'app.4.jsonl',
      });
      expect(t.port.files.values.join(), isNot(contains('h4')));
      expect(t.port.files['app.4.jsonl'], 'h3\n');
      expect(t.port.files['app.1.jsonl'], 'cur\n');
    });

    test('O5-6 debug 不寫檔、兩者皆進 developer.log', () async {
      final t = _make();
      _info(t.writer, level: LogLevel.debug);
      _info(t.writer);
      await t.writer.flush();
      expect('\n'.allMatches(t.port.files['app.jsonl']!).length, 1);
      expect(t.dev.calls.length, 2);
    });

    test('O5-7 100 筆依序寫入、無交錯', () async {
      final t = _make();
      for (var i = 0; i < 100; i++) {
        t.writer.log(
          'graph',
          TestEvent.sampleCompleted,
          LogFields({'n': LogValue.integer(i)}),
        );
      }
      await t.writer.flush();
      final lines = const LineSplitter().convert(t.port.files['app.jsonl']!);
      expect(lines.length, 100);
      for (final l in lines) {
        expect(jsonDecode(l), isA<Map<String, dynamic>>());
      }
    });
  });

  group('並寫', () {
    test('O6-1 level 依序 500/800/900/1000，name 為 domain', () async {
      final t = _make();
      for (final l in LogLevel.values) {
        _info(t.writer, level: l);
      }
      await t.writer.flush();
      expect(t.dev.calls.map((c) => c.level), [500, 800, 900, 1000]);
      expect(t.dev.calls.every((c) => c.name == 'graph'), isTrue);
    });

    test('O6-2 message 以事件名開頭，檔案與 developer.log event 相同', () async {
      final t = _make();
      t.writer.log(
        'graph',
        TestEvent.sampleCompleted,
        const LogFields({'n': LogValue.integer(1)}),
      );
      await t.writer.flush();
      expect(t.dev.calls.single.message, startsWith('sampleCompleted '));
      final m = jsonDecode(t.port.files['app.jsonl']!) as Map<String, dynamic>;
      expect(m['event'], 'sampleCompleted');
    });

    test('O6-3 例外與堆疊只在 developer.log，檔案無堆疊', () async {
      final t = _make();
      final st = StackTrace.current;
      t.writer.log(
        'graph',
        TestEvent.sampleFailed,
        LogFields.empty,
        level: LogLevel.error,
        source: ErrorSource.internal,
        error: StateError('boom'),
        stackTrace: st,
      );
      await t.writer.flush();
      expect(t.dev.calls.single.error, isA<StateError>());
      expect(t.dev.calls.single.stackTrace, st);
      expect(t.port.files['app.jsonl'], isNot(contains('boom')));
      expect(t.port.files['app.jsonl'], isNot(contains('#0')));
    });

    test('O1-6 空 domain 不寫出、記一筆 warning（正向對照：非空寫出）', () async {
      final t = _make();
      _info(t.writer);
      _info(t.writer, domain: '');
      await t.writer.flush();
      expect('\n'.allMatches(t.port.files['app.jsonl']!).length, 1);
      expect(t.dev.warnings.length, 1);
    });

    test('O3-11 C-2：例外訊息不進檔案，只進 developer.log', () async {
      final t = _make();
      t.writer.log(
        'graph',
        TestEvent.sampleFailed,
        LogFields.empty,
        level: LogLevel.error,
        source: ErrorSource.platformIo,
        error: FileSystemException(secretMarker),
      );
      await t.writer.flush();
      final file = t.port.files['app.jsonl']!;
      expect(file, isNot(contains(secretMarker)));
      expect(file, contains('"error_type":"FileSystemException"'));
      expect(t.dev.calls.single.error.toString(), contains(secretMarker));
    });
  });

  group('失敗降級', () {
    test('N1-1 建立目錄失敗：零例外、3 筆記錄加恰 1 筆 warning', () async {
      final t = _make();
      t.port.failEnsureDirectory = true;
      for (var i = 0; i < 3; i++) {
        _info(t.writer);
      }
      await t.writer.flush();
      expect(t.dev.calls.where((c) => c.level == 800).length, 3);
      expect(t.dev.warnings.length, 1);
      expect(t.dev.warnings.single.message, 'logDirUnavailable');
      expect(t.port.files, isEmpty);
    });

    test('N1-2 第 2 筆寫入失敗：warning 恰 1 筆，第 3 筆只進 developer.log', () async {
      final t = _make();
      t.port.failAppendFrom = 2;
      for (var i = 0; i < 3; i++) {
        _info(t.writer);
      }
      await t.writer.flush();
      expect(t.dev.warnings.length, 1);
      expect(t.dev.warnings.single.message, 'logWriteFailed');
      expect('\n'.allMatches(t.port.files['app.jsonl']!).length, 1);
      expect(t.dev.calls.where((c) => c.level == 800).length, 3);
    });

    test('N1-3 輪替改名失敗同 N1-2', () async {
      final t = _make();
      t.port.files['app.jsonl'] = 'old\n';
      t.port.sizeOverride['app.jsonl'] = 5 * _mib;
      t.port.failRename = true;
      _info(t.writer);
      _info(t.writer);
      await t.writer.flush();
      expect(t.dev.warnings.length, 1);
      expect(t.dev.warnings.single.message, 'logWriteFailed');
      expect(t.port.files['app.jsonl'], 'old\n');
    });

    test('port 為 null（無法決定目錄）同降級，不拋出', () async {
      final dev = RecordingDevLog();
      final w = LogWriter(port: null, devLog: dev.call, clock: fixedClock);
      _info(w);
      _info(w);
      await w.flush();
      expect(dev.warnings.single.message, 'logDirUnavailable');
    });
  });
}
