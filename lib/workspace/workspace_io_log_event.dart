/// Workspace domain 內外部開啟、框架訊號探測、編輯器偏好、開檔路徑解析的
/// 日誌事件與 sink（SPEC-010 FR-04）。
///
/// 事件均為使用者操作或失敗路徑，不是掃描、監看那類逐檔高頻事件。
/// `WorkspaceLogEvent`（`workspace_repository.dart`）與 `StaleOpenLogEvent`
/// 各自維持原檔。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// [ExternalOpener] 日誌事件（穩定契約）。
enum ExternalOpenerLogEvent {
  /// 呼叫發出（INV-PORT-OBSERVE-001；info；帶 hasLine）。
  openRequested,

  /// 前置存在檢查判定路徑不存在（warning）。
  pathNotFound,

  /// 所選編輯器無 handler，退回系統預設（warning；帶 editorId）。
  editorHandlerMissing,

  /// 外部程序無法 spawn（warning）。
  launchFailed,

  /// 外部程序成功開啟（info）。
  opened,

  /// 外部程序回傳非零 exitCode（warning；帶 exitCode）。
  openExitNonZero,
}

/// 框架訊號探測日誌事件（穩定契約；皆為 warning）。
enum FrameworkSignalProbeLogEvent {
  versionReadFailed,
  schemaJsonNotObject,
  schemaJsonReadFailed,
  schemaJsonParseFailed,
}

/// 編輯器偏好日誌事件（穩定契約）。
enum EditorPreferenceLogEvent {
  /// 讀取失敗，視為系統預設（warning）。
  readFailed,

  /// 寫入完成（info；帶 editorId、saved）。
  written,

  /// 寫入失敗（warning；帶 editorId）。
  writeFailed,
}

/// 開檔路徑解析日誌事件（穩定契約）。
enum OpenPathLogEvent {
  /// 相對路徑但 workspace 非 Ready，無法解析（warning；帶 workspaceState、path）。
  relativePathUnresolved,
}

/// 負載鍵（具名常數，測試以常數比對）。
abstract final class WorkspaceIoLogKeys {
  static const hasLine = 'hasLine';
  static const editorId = 'editorId';
  static const exitCode = 'exitCode';
  static const saved = 'saved';
  static const workspaceState = 'workspaceState';
  static const path = 'path';
}

/// 生產預設：經共用 writer 輸出，domain 為 `workspace`。
final LogSink<ExternalOpenerLogEvent> defaultExternalOpenerLogSink =
    defaultLogSink<ExternalOpenerLogEvent>('workspace');

final LogSink<FrameworkSignalProbeLogEvent> defaultFrameworkSignalProbeLogSink =
    defaultLogSink<FrameworkSignalProbeLogEvent>('workspace');

final LogSink<EditorPreferenceLogEvent> defaultEditorPreferenceLogSink =
    defaultLogSink<EditorPreferenceLogEvent>('workspace');

final LogSink<OpenPathLogEvent> defaultOpenPathLogSink =
    defaultLogSink<OpenPathLogEvent>('workspace');

/// 測試替身注入點；測試須在 tearDown 還原為對應的 default。
LogSink<ExternalOpenerLogEvent> externalOpenerLogSink =
    defaultExternalOpenerLogSink;

LogSink<FrameworkSignalProbeLogEvent> frameworkSignalProbeLogSink =
    defaultFrameworkSignalProbeLogSink;

LogSink<EditorPreferenceLogEvent> editorPreferenceLogSink =
    defaultEditorPreferenceLogSink;
