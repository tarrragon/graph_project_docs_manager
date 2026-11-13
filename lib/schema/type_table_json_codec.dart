/// FR-06 型別表 JSON 解析（SPEC-006-test-design.md §3.4 K2、K3）。
///
/// 把 `tracking_schema.json`（`.claude/skills/doc/doc_system/core/
/// tracking_schema.py` 的衍生產物）解碼後的 `Map` 轉成 [TypeTable]。本檔
/// 只做資料轉換，不負責讀檔或決定來源（專案 JSON／內建表三分屬 FR-06
/// 規則 7，另一票範圍）。
library;

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/schema/schema_log_event.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

/// 把 `tracking_schema.json` 解碼後的頂層 [Map] 轉成 [TypeTable]。
///
/// `node_types` 提供每個型別的 `carrier_path_patterns`（可缺）與
/// `id_pattern`（可缺）；`completeness_fields` 是與 `node_types` 平行的
/// 頂層鍵，依型別名合併進對應的 [NodeTypeEntry]（規則 3：依欄位存在與否
/// 判定是否參與路徑比對，不依型別名，SPEC-006 D9）。
///
/// 載入時即驗證並編譯所有路徑模式與 `id_pattern`（規則 1、2，NFR-01，
/// 0.3.0-W3-531）：不合法的模式在此拒收並寫警告日誌，不中止整輪掃描，
/// 同批其他合法模式與型別照常載入；查詢階段不再因壞模式拋
/// [FormatException]。
TypeTable typeTableFromJson(
  Map<String, dynamic> json, {
  LogSink<SchemaLogEvent>? logSink,
}) {
  final log = logSink ?? defaultSchemaLogSink;
  final nodeTypesJson = json['node_types'] as Map<String, dynamic>? ?? const {};
  final completenessJson =
      json['completeness_fields'] as Map<String, dynamic>? ?? const {};

  final entries = <String, NodeTypeEntry>{};
  for (final typeName in nodeTypesJson.keys) {
    final typeJson = nodeTypesJson[typeName] as Map<String, dynamic>;
    entries[typeName] = NodeTypeEntry(
      name: typeName,
      carrierPathPatterns: _parseCarrierPathPatterns(
        typeName,
        typeJson['carrier_path_patterns'],
        log,
      ),
      idPattern: _parseIdPattern(
        typeName,
        typeJson['id_pattern'] as String?,
        log,
      ),
      completenessFields: _parseCompletenessFields(completenessJson[typeName]),
    );
  }

  final parsedEdges = _parseEdgeTypes(json['edge_types'], log);
  return TypeTable(
    Map.unmodifiable(entries),
    edgeTypes: parsedEdges.edges,
    rejectedEdgeTypes: parsedEdges.rejected,
    nonDomainPathsFile: _parseOptionalString(json['non_domain_paths_file']),
    nonDomainPathsKey: _parseOptionalString(json['non_domain_paths_key']),
  );
}

/// 需求：[SPEC-006 FR-10 規則 1] 非字串、去頭尾空白後為空（含缺欄）一律視為
/// 缺欄回傳 `null`，由消費端回落內建表值；非空值照原值回傳、不修剪。
String? _parseOptionalString(dynamic raw) =>
    raw is String && raw.trim().isNotEmpty ? raw : null;

/// `edges` 為 `null` 代表缺 `edge_types` 鍵；缺必要欄位的邊型拒收並寫日誌，
/// 鍵名交給 `rejected`（視同缺席，由 `resolveEdgeTypes` 依版本補回或判不可用，
/// SPEC-007 v1.7 FR-01）。正向基數缺席保留為 `null`。
({Map<String, EdgeTypeDecl>? edges, Set<String> rejected}) _parseEdgeTypes(
  dynamic raw,
  LogSink<SchemaLogEvent> log,
) {
  if (raw is! Map<String, dynamic>) {
    return (edges: null, rejected: const <String>{});
  }
  final result = <String, EdgeTypeDecl>{};
  final rejected = <String>{};
  for (final entry in raw.entries) {
    final decl = _parseEdgeTypeEntry(entry.key, entry.value, log);
    if (decl == null) {
      rejected.add(entry.key);
    } else {
      result[entry.key] = decl;
    }
  }
  return (
    edges: Map.unmodifiable(result),
    rejected: Set.unmodifiable(rejected),
  );
}

/// 單一邊型條目；不合法回傳 `null` 並寫日誌。
EdgeTypeDecl? _parseEdgeTypeEntry(
  String name,
  dynamic value,
  LogSink<SchemaLogEvent> log,
) {
  if (value is! Map) {
    _logRejected(log, SchemaLogEvent.edgeTypeRejected);
    return null;
  }
  final forwardField = value['forward_field'];
  final edgeClass = value['class'];
  final layer = value['layer'];
  final reverseField = value['reverse_field'];
  if (forwardField is! String ||
      edgeClass is! String ||
      layer is! String ||
      (reverseField != null && reverseField is! String)) {
    _logRejected(log, SchemaLogEvent.edgeTypeRejected);
    return null;
  }
  // direction 缺席合法（由 resolveEdgeTypes 補值）；存在則必須是合法值。
  final direction = EdgeDirection.values
      .where((v) => v.name == value['direction'])
      .firstOrNull;
  if (value.containsKey('direction') && direction == null) {
    _logRejected(log, SchemaLogEvent.edgeTypeRejected);
    return null;
  }
  return EdgeTypeDecl(
    name: name,
    edgeClass: edgeClass,
    forwardField: forwardField,
    reverseField: reverseField as String?,
    forwardCardinality: EdgeCardinality.values
        .where((v) => v.name == value['forward_cardinality'])
        .firstOrNull,
    layer: layer,
    direction: direction,
  );
}

/// 拒收一律 warning、`error_source` 為 `parse`（解析器判定輸入格式不符）；
/// 例外物件只進 `developer.log`，不進檔案（FR-06）。
void _logRejected(
  LogSink<SchemaLogEvent> log,
  SchemaLogEvent event, [
  Object? error,
]) => log(
  event,
  LogFields.empty,
  level: LogLevel.warning,
  source: ErrorSource.parse,
  error: error,
);

/// `null` 代表型別表中不帶 `carrier_path_patterns` 欄位（規則 3）；
/// 非 `null` 時逐元素轉成 [CarrierPathPattern]，壞元素拒收並寫日誌，不影響
/// 同批其他元素（0.3.0-W3-531）。
List<CarrierPathPattern>? _parseCarrierPathPatterns(
  String typeName,
  dynamic raw,
  LogSink<SchemaLogEvent> log,
) {
  if (raw == null) {
    return null;
  }
  final list = raw as List<dynamic>;
  final patterns = <CarrierPathPattern>[];
  for (final element in list) {
    final map = element as Map<String, dynamic>;
    final pattern = map['pattern'] as String;
    final specificity = _parseSpecificity(
      typeName,
      pattern,
      map['specificity'],
      log,
    );
    if (specificity == null) {
      continue;
    }
    try {
      patterns.add(
        CarrierPathPattern(pattern: pattern, specificity: specificity),
      );
    } on FormatException catch (error) {
      _logRejected(log, SchemaLogEvent.carrierPatternRejected, error);
    }
  }
  return patterns;
}

/// `specificity` 必須是長度為 2 的整數清單（規則 6）；長度不對時拒收該筆
/// 模式並寫日誌，回傳 `null`。
PathSpecificity? _parseSpecificity(
  String typeName,
  String pattern,
  dynamic raw,
  LogSink<SchemaLogEvent> log,
) {
  final list = raw as List<dynamic>;
  if (list.length != 2) {
    _logRejected(log, SchemaLogEvent.specificityRejected);
    return null;
  }
  return (
    literalSegmentCount: list[0] as int,
    crossSegmentWildcardCount: list[1] as int,
  );
}

/// 驗證 `id_pattern` 可被 [RegExp] 編譯；不合法者拒收為 `null` 並寫日誌
/// （0.3.0-W3-531：消費端不應收到無法編譯的字串）。
String? _parseIdPattern(
  String typeName,
  String? raw,
  LogSink<SchemaLogEvent> log,
) {
  if (raw == null) {
    return null;
  }
  try {
    RegExp(raw);
    return raw;
  } on FormatException catch (error) {
    _logRejected(log, SchemaLogEvent.idPatternRejected, error);
    return null;
  }
}

Set<String> _parseCompletenessFields(dynamic raw) {
  if (raw == null) {
    return const <String>{};
  }
  return (raw as List<dynamic>).map((value) => value as String).toSet();
}
