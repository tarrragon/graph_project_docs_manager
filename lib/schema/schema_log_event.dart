/// SPEC-010 型別表解碼日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 型別表解碼拒收事件（皆為 warning，`error_source` 為 `parse`）。
enum SchemaLogEvent {
  /// 邊型條目缺必要欄位或欄位不合法，已拒收。
  edgeTypeRejected,

  /// `carrier_path_patterns` 模式無法編譯，已拒收。
  carrierPatternRejected,

  /// `specificity` 長度不為 2，已拒收。
  specificityRejected,

  /// `id_pattern` 無法編譯，已拒收。
  idPatternRejected,
}

/// 生產預設：經共用 writer 輸出，domain 為 `schema`。
final LogSink<SchemaLogEvent> defaultSchemaLogSink =
    defaultLogSink<SchemaLogEvent>('schema');
