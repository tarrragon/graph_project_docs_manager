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
/// 的入口與成功／失敗，皆經 `LogSink<ServicesLogEvent>` 記錄（SPEC-010；
/// 負載只用白名單型別，平台例外走 `error:`）。
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/services/services_log_event.dart';

import 'scan_notifier.dart';

/// `MethodChannel` 名稱：實作票與 macOS 原生端共用的契約識別。
const String scanNotifierChannelName =
    'graph_project_docs_manager/scan_notifier';

class MacosScanNotifier implements ScanNotifier {
  MacosScanNotifier({
    MethodChannel? channel,
    LogSink<ServicesLogEvent>? logSink,
  }) : _channel = channel ?? const MethodChannel(scanNotifierChannelName),
       _log = logSink ?? defaultServicesLogSink() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final LogSink<ServicesLogEvent> _log;
  final StreamController<void> _activatedController =
      StreamController<void>.broadcast();

  /// 通知標題產生器；未設定時使用開發期 fallback（不應在正式路徑觸發，
  /// controller 於 build 時即設定）。
  String Function() titleBuilder = () =>
      'Gap scan complete'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// `state-gaps-found` 內文產生器。
  String Function(int gapCount) foundBodyBuilder = (count) =>
      '$count gaps detected'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// `state-gaps-none` 內文產生器。
  String Function() noGapsBodyBuilder = () =>
      'No gaps detected'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// `state-gaps-undeterminable` 內文產生器。
  String Function() undeterminableBodyBuilder = () =>
      'Gaps could not be determined'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// 監看輪次通知標題產生器。
  String Function() watchTitleBuilder = () =>
      'Gap report updated'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// 監看輪次通知內文產生器。
  String Function(int gapCount) watchBodyBuilder = (count) =>
      'Rescanned after file changes: $count gaps now'; // i18n-exempt: fallback，正式路徑由 controller 覆寫

  /// controller 於每次 build 時呼叫，注入當前語系的字串產生器
  /// （[AppLocalizations] 需要 `BuildContext`，本類別無法自行取得）。
  void updateLocalizedStrings({
    required String Function() title,
    required String Function(int gapCount) foundBody,
    required String Function() noGapsBody,
    required String Function() undeterminableBody,
    String Function()? watchTitle,
    String Function(int gapCount)? watchBody,
  }) {
    if (watchTitle != null) watchTitleBuilder = watchTitle;
    if (watchBody != null) watchBodyBuilder = watchBody;
    titleBuilder = title;
    foundBodyBuilder = foundBody;
    noGapsBodyBuilder = noGapsBody;
    undeterminableBodyBuilder = undeterminableBody;
  }

  @override
  Stream<void> get activated => _activatedController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onActivated') {
      _log(ServicesLogEvent.notificationActivated, LogFields.empty);
      _activatedController.add(null);
    }
    return null;
  }

  /// 平台失敗（PlatformException／MissingPluginException）統一記錄：
  /// 例外走 `error:`（只留型別），來源為平台 I/O。
  void _logPlatformFailure(ServicesLogEvent event, Object error) {
    _log(
      event,
      LogFields.empty,
      level: LogLevel.warning,
      source: ErrorSource.platformIo,
      error: error,
    );
  }

  @override
  Future<NotificationAuthorization> authorizationStatus() async {
    _log(ServicesLogEvent.authorizationQueried, LogFields.empty);
    try {
      final result = await _channel.invokeMethod<String>('authorizationStatus');
      final status = _parseAuthorization(result);
      _log(
        ServicesLogEvent.authorizationResolved,
        LogFields({ServicesLogKeys.status: LogValue.enumValue(status)}),
      );
      return status;
    } on PlatformException catch (error) {
      _logPlatformFailure(ServicesLogEvent.authorizationQueryFailed, error);
      return NotificationAuthorization.denied;
    } on MissingPluginException catch (error) {
      _logPlatformFailure(ServicesLogEvent.authorizationQueryFailed, error);
      return NotificationAuthorization.denied;
    }
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    _log(ServicesLogEvent.authorizationRequested, LogFields.empty);
    try {
      final result = await _channel.invokeMethod<String>(
        'requestAuthorization',
      );
      final status = _parseAuthorization(result);
      _log(
        ServicesLogEvent.authorizationRequestResolved,
        LogFields({ServicesLogKeys.status: LogValue.enumValue(status)}),
      );
      return status;
    } on PlatformException catch (error) {
      _logPlatformFailure(ServicesLogEvent.authorizationRequestFailed, error);
      return NotificationAuthorization.denied;
    } on MissingPluginException catch (error) {
      _logPlatformFailure(ServicesLogEvent.authorizationRequestFailed, error);
      return NotificationAuthorization.denied;
    }
  }

  @override
  Future<ScanNotificationDelivery> show(
    ScanCompleteNotification notification,
  ) async {
    final gapCount = notification.gapCount;
    _log(
      ServicesLogEvent.notificationShowRequested,
      LogFields({ServicesLogKeys.gapCount: LogValue.integer(gapCount)}),
    );
    final title = notification.isWatchRound
        ? watchTitleBuilder()
        : titleBuilder();
    final body = notification.isWatchRound
        ? watchBodyBuilder(gapCount)
        : notification.isUndeterminable
        ? undeterminableBodyBuilder()
        : gapCount == 0
        ? noGapsBodyBuilder()
        : foundBodyBuilder(gapCount);
    try {
      await _channel.invokeMethod<void>('show', <String, Object?>{
        'title': title,
        'body': body,
      });
      return ScanNotificationDelivery.delivered;
    } on PlatformException catch (error) {
      _logPlatformFailure(ServicesLogEvent.notificationShowFailed, error);
      return ScanNotificationDelivery.failed;
    } on MissingPluginException catch (error) {
      _logPlatformFailure(ServicesLogEvent.notificationShowFailed, error);
      return ScanNotificationDelivery.failed;
    }
  }

  @override
  Future<void> withdraw() async {
    _log(ServicesLogEvent.notificationWithdrawRequested, LogFields.empty);
    try {
      await _channel.invokeMethod<void>('withdraw');
    } on PlatformException catch (error) {
      // SPEC-003 §2.2「不重複發送」列：撤回失敗不阻擋、不轉狀態，只記 log。
      _logPlatformFailure(ServicesLogEvent.notificationWithdrawFailed, error);
    } on MissingPluginException catch (error) {
      _logPlatformFailure(ServicesLogEvent.notificationWithdrawFailed, error);
    }
  }

  NotificationAuthorization _parseAuthorization(String? raw) => switch (raw) {
    'granted' => NotificationAuthorization.granted,
    'notDetermined' => NotificationAuthorization.notDetermined,
    _ => NotificationAuthorization.denied,
  };
}
