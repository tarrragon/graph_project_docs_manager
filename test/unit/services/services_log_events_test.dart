// services 與 app 層日誌事件碼契約（SPEC-010 FR-04；1.0.0-W3-553.2.3.3）。
//
// 事件斷言綁事件碼與白名單負載，不比對訊息文字。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/app_log_event.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/services/macos_preferences_channel.dart';
import 'package:graph_project_docs_manager/services/macos_scan_notifier.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';
import 'package:graph_project_docs_manager/services/services_log_event.dart';

class _Entry<E extends Enum> {
  _Entry(this.event, this.payload, this.level, this.source, this.error);
  final E event;
  final Map<String, Object> payload;
  final LogLevel level;
  final ErrorSource? source;
  final Object? error;
}

class _Recorder<E extends Enum> {
  final entries = <_Entry<E>>[];

  void call(
    E event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) => entries.add(_Entry(event, fields.toJson(), level, source, error));

  List<E> get events => [for (final e in entries) e.event];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('MacosScanNotifier', () {
    const channel = MethodChannel(scanNotifierChannelName);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('授權查詢成功：入口與結果事件，結果帶 status 列舉名', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 'granted');
      final rec = _Recorder<ServicesLogEvent>();
      await MacosScanNotifier(
        channel: channel,
        logSink: rec.call,
      ).authorizationStatus();
      expect(rec.events, [
        ServicesLogEvent.authorizationQueried,
        ServicesLogEvent.authorizationResolved,
      ]);
      expect(rec.entries.last.payload, {ServicesLogKeys.status: 'granted'});
    });

    test('PlatformException：失敗事件帶 platformIo 來源與 error，負載不含訊息', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'secret-code'),
      );
      final rec = _Recorder<ServicesLogEvent>();
      await MacosScanNotifier(
        channel: channel,
        logSink: rec.call,
      ).show(const ScanCompleteNotification(gapCount: 3));
      expect(rec.events, [
        ServicesLogEvent.notificationShowRequested,
        ServicesLogEvent.notificationShowFailed,
      ]);
      expect(rec.entries.first.payload, {ServicesLogKeys.gapCount: 3});
      final failed = rec.entries.last;
      expect(failed.source, ErrorSource.platformIo);
      expect(failed.level, LogLevel.warning);
      expect(failed.error, isA<PlatformException>());
      expect(failed.payload, isEmpty);
    });

    test('MissingPluginException：撤回失敗事件，不阻擋（正向對照：成功路徑無失敗事件）', () async {
      final rec = _Recorder<ServicesLogEvent>();
      await MacosScanNotifier(channel: channel, logSink: rec.call).withdraw();
      expect(rec.events.last, ServicesLogEvent.notificationWithdrawFailed);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final ok = _Recorder<ServicesLogEvent>();
      await MacosScanNotifier(channel: channel, logSink: ok.call).withdraw();
      expect(ok.events, [ServicesLogEvent.notificationWithdrawRequested]);
    });
  });

  group('MacosPreferencesChannel', () {
    const channel = MethodChannel(preferencesChannelName);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('handler 查詢：結果事件帶 scheme 與 found', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      final rec = _Recorder<ServicesLogEvent>();
      await MacosPreferencesChannel(
        channel: channel,
        logSink: rec.call,
      ).hasHandler('vscode');
      expect(rec.events, [
        ServicesLogEvent.handlerQueried,
        ServicesLogEvent.handlerQueryResolved,
      ]);
      expect(rec.entries.last.payload, {
        ServicesLogKeys.scheme: 'vscode',
        ServicesLogKeys.found: true,
      });
    });

    test('原生端未註冊：handlerQueryFailed 帶 platformIo', () async {
      final rec = _Recorder<ServicesLogEvent>();
      final found = await MacosPreferencesChannel(
        channel: channel,
        logSink: rec.call,
      ).hasHandler('zed');
      expect(found, isFalse);
      expect(rec.entries.last.event, ServicesLogEvent.handlerQueryFailed);
      expect(rec.entries.last.source, ErrorSource.platformIo);
    });
  });

  group('app 層 appLogSink', () {
    late LogSinkRestore restore;
    setUp(() => restore = LogSinkRestore());
    tearDown(() => restore.run());

    test(
      'ScanScheduler 輪次拋例外：schedulerRoundFailed 帶 error 與 internal 來源',
      () async {
        final rec = _Recorder<AppLogEvent>();
        appLogSink = rec.call;
        final scheduler = ScanScheduler(
          runRound: (_) async => throw StateError('boom'),
        );
        scheduler.request(ScanTrigger.manual);
        await Future<void>.delayed(Duration.zero);
        expect(rec.events, [AppLogEvent.schedulerRoundFailed]);
        expect(rec.entries.single.source, ErrorSource.internal);
        expect(rec.entries.single.error, isA<StateError>());
        expect(rec.entries.single.payload, isEmpty);
      },
    );
  });
}

/// 還原被替換的 [appLogSink]。
class LogSinkRestore {
  final _original = appLogSink;
  void run() => appLogSink = _original;
}
