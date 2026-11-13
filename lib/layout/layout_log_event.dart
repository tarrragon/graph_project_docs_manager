/// SPEC-010 泳道布局日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 布局事件。
enum LayoutLogEvent {
  /// 解析名稱不在 FR-13 列序內（程式錯誤）；warning、`error_source` 為 `internal`。
  laneInvariantViolated,
}

/// 事件負載鍵。
abstract final class LayoutLogKeys {
  static const missingCount = 'missingCount';
}

/// 生產預設：經共用 writer 輸出，domain 為 `layout`。
final LogSink<LayoutLogEvent> defaultLayoutLogSink =
    defaultLogSink<LayoutLogEvent>('layout');
