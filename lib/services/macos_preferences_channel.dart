/// 偏好設定的 macOS 原生通道（Dart 端）：⌘, 選單事件與編輯器 handler 查詢。
///
/// 兩件事共用一條 `MethodChannel`（macos/Runner/AppDelegate.swift）：
/// - 原生端 → Dart：`openPreferences`（選單列「Preferences…」，⌘,）。
/// - Dart → 原生端：`hasHandler`（`NSWorkspace.urlForApplication(toOpen:)`
///   唯讀查詢，不啟動任何應用程式）。
///
/// 查詢失敗（原生端未註冊、平台例外）一律視為「無 handler」，使設定面板
/// 與開檔都落到系統預設的保守路徑（SPEC-003 §3.8、§2.2〈行號定位〉）。
///
/// 可觀測性（observability 規則 5）：查詢入口與結果、選單事件、平台例外皆以
/// `LogSink<ServicesLogEvent>` 記錄（SPEC-010；負載只用白名單型別）。
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/services/services_log_event.dart';

import '../workspace/editor_preference.dart';

/// `MethodChannel` 名稱：須與 AppDelegate.swift 的 `preferencesChannelName` 一致。
const String preferencesChannelName = 'graph_project_docs_manager/preferences';

class MacosPreferencesChannel implements EditorHandlerProbe {
  MacosPreferencesChannel({
    MethodChannel? channel,
    LogSink<ServicesLogEvent>? logSink,
  }) : _channel = channel ?? const MethodChannel(preferencesChannelName),
       _log = logSink ?? defaultServicesLogSink() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final LogSink<ServicesLogEvent> _log;
  final StreamController<void> _openRequestedController =
      StreamController<void>.broadcast();

  /// 使用者按選單列「Preferences…」或 ⌘, 時發出。
  Stream<void> get openRequested => _openRequestedController.stream;

  final StreamController<void> _openShortcutsController =
      StreamController<void>.broadcast();

  /// 使用者按說明選單「鍵盤快捷鍵」時發出（SPEC-003 §3.11〈選單動作的通道〉）。
  Stream<void> get openKeyboardShortcutsRequested =>
      _openShortcutsController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'openPreferences') {
      _log(ServicesLogEvent.preferencesOpenRequested, LogFields.empty);
      _openRequestedController.add(null);
    } else if (call.method == 'openKeyboardShortcuts') {
      _log(ServicesLogEvent.keyboardShortcutsOpenRequested, LogFields.empty);
      _openShortcutsController.add(null);
    }
    return null;
  }

  /// 平台失敗統一記錄：例外走 `error:`（只留型別），來源為平台 I/O。
  void _logPlatformFailure(Object error) {
    _log(
      ServicesLogEvent.handlerQueryFailed,
      LogFields.empty,
      level: LogLevel.warning,
      source: ErrorSource.platformIo,
      error: error,
    );
  }

  @override
  Future<bool> hasHandler(String scheme) async {
    final schemeField = LogValue.fieldName(scheme);
    _log(
      ServicesLogEvent.handlerQueried,
      LogFields({ServicesLogKeys.scheme: schemeField}),
    );
    try {
      final found = await _channel.invokeMethod<bool>('hasHandler', {
        'scheme': scheme,
      });
      _log(
        ServicesLogEvent.handlerQueryResolved,
        LogFields({
          ServicesLogKeys.scheme: schemeField,
          ServicesLogKeys.found: LogValue.boolean(found ?? false),
        }),
      );
      return found ?? false;
    } on PlatformException catch (error) {
      _logPlatformFailure(error);
      return false;
    } on MissingPluginException catch (error) {
      _logPlatformFailure(error);
      return false;
    }
  }
}

/// 通道的 Riverpod 掛點；測試以 override 注入 fake。
final preferencesChannelProvider = Provider<MacosPreferencesChannel>((ref) {
  return MacosPreferencesChannel();
});

/// handler 查詢的掛點：正式路徑走 [preferencesChannelProvider]。
final editorHandlerProbeProvider = Provider<EditorHandlerProbe>((ref) {
  return ref.watch(preferencesChannelProvider);
});
