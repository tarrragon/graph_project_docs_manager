/// SPEC-010 FR-04：全 App 唯一的 LogSink 型別與生產預設實作。
library;

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/observability/log_writer.dart';

/// 全 App 唯一的 sink 型別；事件 enum 由各 domain 宣告並擁有。
typedef LogSink<E extends Enum> = void Function(
  E event,
  LogFields fields, {
  LogLevel level,
  ErrorSource? source,
  Object? error,
});

/// 生產預設共用 writer；日誌目錄於啟動接線時以 [LogWriter.port] 決定，
/// 未接線前為降級模式（只轉呼 developer.log，寫檔降級一次）。
LogWriter sharedLogWriter = LogWriter(port: null);

/// 生產預設 sink：把 [domain] 的事件交給 [sharedLogWriter]。
LogSink<E> defaultLogSink<E extends Enum>(String domain) =>
    (event, fields, {level = LogLevel.info, source, error}) => sharedLogWriter
        .log(domain, event, fields, level: level, source: source, error: error);

/// 舊版整數等級（`developer.log` 數值）對應到 [LogLevel]；null 視為 info。
LogLevel logLevelFromDevLevel(int? level) {
  if (level == null) return LogLevel.info;
  if (level >= LogLevel.error.devLogLevel) return LogLevel.error;
  if (level >= LogLevel.warning.devLogLevel) return LogLevel.warning;
  if (level >= LogLevel.info.devLogLevel) return LogLevel.info;
  return LogLevel.debug;
}
