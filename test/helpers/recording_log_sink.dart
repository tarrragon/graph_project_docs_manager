/// 泛型 log 記錄器：實作 `LogSink<E>`，可查詢事件、等級與負載（SPEC-010 FR-04）。
library;

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 一筆被記錄的日誌；[payload] 為白名單值的序列化結果。
class RecordedLog<E extends Enum> {
  const RecordedLog({
    required this.event,
    required this.payload,
    required this.level,
    this.source,
  });

  final E event;
  final Map<String, Object?> payload;
  final LogLevel level;
  final ErrorSource? source;
}

class RecordingLogSink<E extends Enum> {
  final List<RecordedLog<E>> entries = [];

  void sink(
    E event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) {
    entries.add(
      RecordedLog<E>(
        event: event,
        payload: fields.toJson(),
        level: level,
        source: source,
      ),
    );
  }

  List<RecordedLog<E>> ofEvent(E event) => [
    for (final entry in entries)
      if (entry.event == event) entry,
  ];

  /// info 以上（會寫檔）的記錄。
  List<RecordedLog<E>> get writtenToFile => [
    for (final entry in entries)
      if (entry.level != LogLevel.debug) entry,
  ];
}

/// O4-4／O4-5 判定：info 以上的記錄除 [aggregate] 外為 0 筆（逐檔事件皆 debug），
/// 且 [aggregate] 至多一筆（一輪一筆聚合）。
bool isDebugOrSingleAggregate<E extends Enum>(
  Iterable<RecordedLog<E>> entries,
  Set<E> aggregate,
) {
  final written = [
    for (final e in entries)
      if (e.level != LogLevel.debug) e,
  ];
  final nonAggregate = written.where((e) => !aggregate.contains(e.event));
  return nonAggregate.isEmpty && written.length <= 1;
}
