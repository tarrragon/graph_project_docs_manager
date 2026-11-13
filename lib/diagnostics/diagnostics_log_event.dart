/// SPEC-010 診斷日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 診斷事件。
enum DiagnosticsLogEvent {
  /// EVT-CORPUS-004 的 reason 未以原因碼開頭（上游違約），
  /// warning、`error_source` 為 `internal`。
  flowReasonPrefixViolation,
}

/// 生產預設：經共用 writer 輸出，domain 為 `diagnostics`。
final LogSink<DiagnosticsLogEvent> defaultDiagnosticsLogSink =
    defaultLogSink<DiagnosticsLogEvent>('diagnostics');
