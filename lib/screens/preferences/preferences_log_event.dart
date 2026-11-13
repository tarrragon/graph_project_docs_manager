/// SPEC-010 偏好設定面板日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 偏好設定 domain 事件。
enum PreferencesLogEvent {
  /// 編輯器偵測完成（debug），負載 `available_count`。
  editorsDetected,

  /// 選定編輯器並寫入成功（info）。
  editorSaved,

  /// 選定編輯器但寫入失敗，warning、`platform_io`。
  editorSaveFailed,
}

/// 事件負載鍵。
abstract final class PreferencesLogKeys {
  static const availableCount = 'available_count';
}

/// 生產預設：經共用 writer 輸出，domain 為 `preferences`。
final LogSink<PreferencesLogEvent> defaultPreferencesLogSink =
    defaultLogSink<PreferencesLogEvent>('preferences');

/// 偏好設定 sink；測試以 override 注入記錄器。
final preferencesLogSinkProvider = Provider<LogSink<PreferencesLogEvent>>(
  (ref) => defaultPreferencesLogSink,
);
