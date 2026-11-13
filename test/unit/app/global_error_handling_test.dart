/// 全域錯誤攔截三層與單一錯誤出口測試。
// rule8-exempt: illustration:worktree 路徑含 .claude/ 前綴觸發框架文件誤判，本檔為專案測試檔非框架文件
///
/// 三層攔截各自以人為拋出的例外驗證其被攔截並抵達單一出口
/// [fatalErrorNotifier]：
/// - 框架層：`FlutterError.onError`
/// - 平台層：`PlatformDispatcher.instance.onError`
/// - 非同步層：`runZonedGuarded`
///
/// 每個測試前後都還原 `FlutterError.onError` / `PlatformDispatcher`
/// 的原始 handler，避免污染同一個 test process 內的其他測試檔。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/observability/log_writer.dart';

import '../observability/observability_test_helpers.dart';

void main() {
  final originalFlutterOnError = FlutterError.onError;
  final originalPlatformOnError = PlatformDispatcher.instance.onError;

  setUp(() {
    fatalErrorNotifier.value = null;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
    fatalErrorNotifier.value = null;
  });

  group('全域錯誤攔截三層匯流至單一出口', () {
    test('框架層：FlutterError.onError 攔截例外並抵達單一出口', () {
      installGlobalErrorHandlers();

      final details = FlutterErrorDetails(
        exception: StateError('框架層人為拋出的例外'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);

      expect(fatalErrorNotifier.value, isA<StateError>());
      expect((fatalErrorNotifier.value as StateError).message, '框架層人為拋出的例外');
    });

    test('平台層：PlatformDispatcher.instance.onError 攔截例外並抵達單一出口', () {
      installGlobalErrorHandlers();

      final handled = PlatformDispatcher.instance.onError!(
        StateError('平台層人為拋出的例外'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(fatalErrorNotifier.value, isA<StateError>());
      expect((fatalErrorNotifier.value as StateError).message, '平台層人為拋出的例外');
    });

    test('非同步層：runZonedGuarded 攔截例外並抵達單一出口', () async {
      final completer = Completer<void>();

      runZonedGuarded(
        () {
          // 未 await 的非同步例外：不會被上兩層攔截，只有 runZonedGuarded
          // 的 error handler 能接住。
          Future<void>.delayed(Duration.zero, () {
            throw StateError('非同步層人為拋出的例外');
          }).whenComplete(completer.complete);
        },
        (error, stack) {
          reportFatalError('runZonedGuarded', error, stack);
        },
      );

      await completer.future;
      // 讓 zone 的 error handler 有機會在下一個 microtask 執行完畢。
      await Future<void>.delayed(Duration.zero);

      expect(fatalErrorNotifier.value, isA<StateError>());
      expect((fatalErrorNotifier.value as StateError).message, '非同步層人為拋出的例外');
    });

    test('reportFatalError 是三層共同匯流的單一出口', () {
      reportFatalError('unit-test', Exception('直接呼叫單一出口'), StackTrace.current);

      expect(fatalErrorNotifier.value, isA<Exception>());
    });
  });

  group('structured log（SPEC-010 FR-07）', () {
    late FakeLogFilePort port;
    final originalWriter = sharedLogWriter;

    setUp(() {
      port = FakeLogFilePort();
      sharedLogWriter = LogWriter(
        port: port,
        devLog: RecordingDevLog().call,
        clock: fixedClock,
      );
    });

    tearDown(() => sharedLogWriter = originalWriter);

    Future<List<Map<String, dynamic>>> records() async {
      await sharedLogWriter.flush();
      final text = port.files['app.jsonl'] ?? '';
      return const LineSplitter()
          .convert(text)
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();
    }

    test('O7-1：三個來源各寫一筆 internal 記錄', () async {
      // 單一注入點：fatal 出口與 defaultLogSink 讀同一個 sharedLogWriter。
      reportFatalError('FlutterError', StateError('x'), StackTrace.current);
      reportFatalError(
        'PlatformDispatcher',
        StateError('x'),
        StackTrace.current,
      );
      reportFatalError('runZonedGuarded', StateError('x'), StackTrace.current);

      final all = await records();
      expect(all, hasLength(3));
      for (final r in all) {
        expect(r['domain'], 'presentation');
        expect(r['event'], 'fatalUncaught');
        expect(r['level'], 'error');
        expect(r['error_source'], 'internal');
        expect(r['error_type'], 'StateError');
      }
      expect(all.map((r) => (r['fields'] as Map)['interceptor']), [
        'framework',
        'platform',
        'zone',
      ]);
    });

    test('O7-2：例外訊息全文不進入記錄', () async {
      reportFatalError(
        'FlutterError',
        StateError('leak $secretMarker'),
        StackTrace.current,
      );

      await sharedLogWriter.flush();
      final raw = port.files['app.jsonl'] ?? '';
      expect(raw, isNotEmpty, reason: '正向對照：記錄確實寫出');
      expect(raw, isNot(contains(secretMarker)));
    });

    test('O7-3：writer 拋例外時畫面通知照舊且出口不拋出', () {
      sharedLogWriter = _ThrowingWriter();
      final error = StateError('boom');

      expect(
        () => reportFatalError('FlutterError', error, StackTrace.current),
        returnsNormally,
      );
      expect(fatalErrorNotifier.value, same(error));
    });
  });
}

class _ThrowingWriter extends LogWriter {
  _ThrowingWriter() : super(port: null);

  @override
  void log(
    String domain,
    Enum event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
    StackTrace? stackTrace,
  }) => throw StateError('writer down');
}
