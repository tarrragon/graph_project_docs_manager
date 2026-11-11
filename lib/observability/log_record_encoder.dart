/// SPEC-010 FR-01：把一筆記錄編碼為一行 JSON（JSON Lines）。
library;

import 'dart:convert';

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 編碼一筆記錄，結尾含 `\n`。
///
/// [domain] 為空字串時拋 [ArgumentError]（必填欄位缺失不得寫出）。
/// 例外物件只取 `runtimeType`，不讀 toString 與 message（C-2）。
String encodeLogRecord({
  required DateTime now,
  required LogLevel level,
  required String domain,
  required Enum event,
  required LogFields fields,
  ErrorSource? source,
  Object? error,
}) {
  if (domain.isEmpty) {
    throw ArgumentError.value(domain, 'domain', '必填欄位不可為空');
  }
  final record = <String, Object>{
    'ts': now.toUtc().toIso8601String(),
    'level': level.wireName,
    'domain': domain,
    'event': event.name,
    'fields': fields.toJson(),
    if (source != null) 'error_source': source.wireName,
    if (error != null) 'error_type': error.runtimeType.toString(),
  };
  return '${jsonEncode(record)}\n';
}
