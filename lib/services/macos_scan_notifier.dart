/// [ScanNotifier] 的 macOS 載體（SPEC-003 §2.2「介面」）。
///
/// 透過 `MethodChannel` 呼叫原生 `UNUserNotificationCenter`
/// （macos/Runner/AppDelegate.swift）。標題／內文由呼叫端（controller，
/// 持有 `BuildContext` 故能取得 [AppLocalizations]）透過
/// [updateLocalizedStrings] 設定；本類別不持有 `BuildContext`。
///
/// 三個授權值以外的平台結果（`provisional`、查詢／請求逾時或拋錯、API
/// 不可用）一律收斂為 [NotificationAuthorization.denied]（SPEC-003 §2.2
/// 權限 gate 三路徑「其他」列），不外洩至畫面層。
///
/// 可觀測性（observability 規則 5）：授權查詢／請求入口與結果、發送與撤回
/// 的入口與成功／失敗，皆以 `developer.log` 記錄（開發者診斷字串，非
/// 使用者可見文字，不進 i18n）。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'scan_notifier.dart';

const String _tag = 'MacosScanNotifier';

/// `MethodChannel` 名稱：實作票與 macOS 原生端共用的契約識別。
const String scanNotifierChannelName =
    'graph_project_docs_manager/scan_notifier';

class MacosScanNotifier implements ScanNotifier {
  MacosScanNotifier({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(scanNotifierChannelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<void> _activatedController =
      StreamController<void>.broadcast();

  /// 通知標題產生器；未設定時使用開發期 fallback（不應在正式路徑觸發，
  /// controller 於 build 時即設定）。
  String Function() titleBuilder =
      () => 'Gap scan complete'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// `state-gaps-found` 內文產生器。
  String Function(int gapCount) foundBodyBuilder =
      (count) =>
          '$count gaps detected'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// `state-gaps-none` 內文產生器。
  String Function() noGapsBodyBuilder =
      () => 'No gaps detected'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// controller 於每次 build 時呼叫，注入當前語系的字串產生器
  /// （[AppLocalizations] 需要 `BuildContext`，本類別無法自行取得）。
  void updateLocalizedStrings({
    required String Function() title,
    required String Function(int gapCount) foundBody,
    required String Function() noGapsBody,
  }) {
    titleBuilder = title;
    foundBodyBuilder = foundBody;
    noGapsBodyBuilder = noGapsBody;
  }

  @override
  Stream<void> get activated => _activatedController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onActivated') {
      developer.log('通知被點擊', name: _tag); // i18n-exempt: 開發者診斷 log
      _activatedController.add(null);
    }
    return null;
  }

  @override
  Future<NotificationAuthorization> authorizationStatus() async {
    developer.log('查詢授權狀態', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final result = await _channel.invokeMethod<String>(
        'authorizationStatus',
      );
      final status = _parseAuthorization(result);
      developer.log('授權狀態：$status', name: _tag); // i18n-exempt: 開發者診斷 log
      return status;
    } on PlatformException catch (error) {
      developer.log(
        '查詢授權狀態失敗（視為 denied）：${error.code} ${error.message}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return NotificationAuthorization.denied;
    } on MissingPluginException catch (error) {
      developer.log(
        '查詢授權狀態失敗，原生端未註冊 handler（視為 denied）：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return NotificationAuthorization.denied;
    }
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    developer.log('請求授權', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final result = await _channel.invokeMethod<String>(
        'requestAuthorization',
      );
      final status = _parseAuthorization(result);
      developer.log('請求授權結果：$status', name: _tag); // i18n-exempt: 開發者診斷 log
      return status;
    } on PlatformException catch (error) {
      developer.log(
        '請求授權失敗（視為 denied）：${error.code} ${error.message}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return NotificationAuthorization.denied;
    } on MissingPluginException catch (error) {
      developer.log(
        '請求授權失敗，原生端未註冊 handler（視為 denied）：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return NotificationAuthorization.denied;
    }
  }

  @override
  Future<void> show(ScanCompleteNotification notification) async {
    final gapCount = notification.gapCount;
    developer.log(
      '發送通知：gapCount=$gapCount', // i18n-exempt: 開發者診斷 log
      name: _tag,
    );
    final title = titleBuilder();
    final body =
        gapCount == 0 ? noGapsBodyBuilder() : foundBodyBuilder(gapCount);
    try {
      await _channel.invokeMethod<void>('show', <String, Object?>{
        'title': title,
        'body': body,
      });
    } on PlatformException catch (error) {
      developer.log(
        '發送通知失敗：${error.code} ${error.message}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    } on MissingPluginException catch (error) {
      developer.log(
        '發送通知失敗，原生端未註冊 handler：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    }
  }

  @override
  Future<void> withdraw() async {
    developer.log('撤回通知', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      await _channel.invokeMethod<void>('withdraw');
    } on PlatformException catch (error) {
      // SPEC-003 §2.2「不重複發送」列：撤回失敗不阻擋、不轉狀態，只記 log。
      developer.log(
        '撤回通知失敗（不阻擋、不轉狀態）：${error.code} ${error.message}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    } on MissingPluginException catch (error) {
      developer.log(
        '撤回通知失敗，原生端未註冊 handler（不阻擋）：$error', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    }
  }

  NotificationAuthorization _parseAuthorization(String? raw) => switch (raw) {
    'granted' => NotificationAuthorization.granted,
    'notDetermined' => NotificationAuthorization.notDetermined,
    _ => NotificationAuthorization.denied,
  };
}
