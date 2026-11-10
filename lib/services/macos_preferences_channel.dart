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
/// `developer.log` 記錄（開發者診斷字串，非使用者可見文字，不進 i18n）。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace/editor_preference.dart';

const String _tag = 'MacosPreferencesChannel';

/// `MethodChannel` 名稱：須與 AppDelegate.swift 的 `preferencesChannelName` 一致。
const String preferencesChannelName = 'graph_project_docs_manager/preferences';

class MacosPreferencesChannel implements EditorHandlerProbe {
  MacosPreferencesChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(preferencesChannelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
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
      developer.log('收到偏好設定開啟請求', name: _tag); // i18n-exempt: 開發者診斷 log
      _openRequestedController.add(null);
    } else if (call.method == 'openKeyboardShortcuts') {
      developer.log('收到鍵盤快捷鍵開啟請求', name: _tag); // i18n-exempt: 開發者診斷 log
      _openShortcutsController.add(null);
    }
    return null;
  }

  @override
  Future<bool> hasHandler(String scheme) async {
    developer.log('查詢 handler：$scheme', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final found = await _channel.invokeMethod<bool>('hasHandler', {
        'scheme': scheme,
      });
      developer.log(
        'handler 查詢結果：$scheme=$found',
        name: _tag,
      ); // i18n-exempt: 開發者診斷 log
      return found ?? false;
    } on PlatformException catch (error) {
      developer.log(
        'handler 查詢失敗（視為無）：${error.code} ${error.message}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return false;
    } on MissingPluginException catch (error) {
      developer.log(
        'handler 查詢失敗，原生端未註冊（視為無）：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
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
