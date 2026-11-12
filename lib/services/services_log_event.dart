/// services 層（平台通道與檔案監看）的日誌事件（SPEC-010 FR-04）。
///
/// 事件名是測試斷言綁定的穩定契約；負載只用 FR-03 白名單型別。平台例外
/// 走 `error:` 並標 [ErrorSource.platformIo]，不把例外訊息放進負載。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// services 層日誌事件（穩定契約）。
enum ServicesLogEvent {
  /// 通知被點擊（原生端 onActivated）。
  notificationActivated,

  /// 查詢通知授權狀態入口。
  authorizationQueried,

  /// 通知授權狀態查詢結果，負載帶 [ServicesLogKeys.status]。
  authorizationResolved,

  /// 通知授權狀態查詢失敗（視為 denied）。
  authorizationQueryFailed,

  /// 請求通知授權入口。
  authorizationRequested,

  /// 通知授權請求結果，負載帶 [ServicesLogKeys.status]。
  authorizationRequestResolved,

  /// 通知授權請求失敗（視為 denied）。
  authorizationRequestFailed,

  /// 發送通知入口，負載帶 [ServicesLogKeys.gapCount]。
  notificationShowRequested,

  /// 發送通知失敗。
  notificationShowFailed,

  /// 撤回通知入口。
  notificationWithdrawRequested,

  /// 撤回通知失敗（不阻擋、不轉狀態）。
  notificationWithdrawFailed,

  /// 收到偏好設定開啟請求。
  preferencesOpenRequested,

  /// 收到鍵盤快捷鍵開啟請求。
  keyboardShortcutsOpenRequested,

  /// handler 查詢入口，負載帶 [ServicesLogKeys.scheme]。
  handlerQueried,

  /// handler 查詢結果，負載帶 [ServicesLogKeys.scheme]、[ServicesLogKeys.found]。
  handlerQueryResolved,

  /// handler 查詢失敗（視為無 handler）。
  handlerQueryFailed,

  /// 監看來源收到原始檔案事件（debug），負載帶類型與工作區相對路徑。
  watchRawEventReceived,
}

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class ServicesLogKeys {
  static const status = 'status';
  static const gapCount = 'gapCount';
  static const scheme = 'scheme';
  static const found = 'found';
  static const changeType = 'changeType';
  static const path = 'path';
}

/// services 層生產預設 sink 的 domain 名。
const String servicesLogDomain = 'services';

/// 建立 services 層生產預設 sink。
LogSink<ServicesLogEvent> defaultServicesLogSink() =>
    defaultLogSink<ServicesLogEvent>(servicesLogDomain);
