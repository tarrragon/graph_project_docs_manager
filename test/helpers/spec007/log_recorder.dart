/// log 記錄器（SPEC-007 測試設計 §1.4）：實作 `LogSink<GraphLogEvent>`，可查詢事件與負載。
library;

import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 一筆被記錄的日誌；[payload] 為白名單值的序列化結果。
class RecordedGraphLog {
  const RecordedGraphLog({
    required this.event,
    required this.payload,
    required this.level,
  });

  final GraphLogEvent event;
  final Map<String, Object?> payload;
  final LogLevel level;
}

class LogRecorder {
  final List<RecordedGraphLog> entries = [];

  void sink(
    GraphLogEvent event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) {
    entries.add(
      RecordedGraphLog(event: event, payload: fields.toJson(), level: level),
    );
  }

  List<RecordedGraphLog> ofEvent(GraphLogEvent event) => [
    for (final entry in entries)
      if (entry.event == event) entry,
  ];
}
