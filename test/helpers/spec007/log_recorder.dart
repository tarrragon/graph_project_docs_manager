/// log 記錄器（SPEC-007 測試設計 §1.4）：實作 [GraphLogSink]，可查詢事件與負載。
library;

import 'package:graph_project_docs_manager/graph/graph_log_event.dart';

/// 一筆被記錄的日誌。
class RecordedGraphLog {
  const RecordedGraphLog({
    required this.message,
    required this.event,
    required this.payload,
    required this.level,
  });

  final String message;
  final GraphLogEvent event;
  final Map<String, Object?> payload;
  final int? level;
}

class LogRecorder {
  final List<RecordedGraphLog> entries = [];

  void sink(
    String message, {
    required GraphLogEvent event,
    required Map<String, Object?> payload,
    int? level,
  }) {
    entries.add(
      RecordedGraphLog(
        message: message,
        event: event,
        payload: payload,
        level: level,
      ),
    );
  }

  List<RecordedGraphLog> ofEvent(GraphLogEvent event) => [
    for (final entry in entries)
      if (entry.event == event) entry,
  ];
}
