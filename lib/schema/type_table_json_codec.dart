/// FR-06 型別表 JSON 解析（SPEC-006-test-design.md §3.4 K2、K3）。
///
/// 把 `tracking_schema.json`（`.claude/skills/doc/doc_system/core/
/// tracking_schema.py` 的衍生產物）解碼後的 `Map` 轉成 [TypeTable]。本檔
/// 只做資料轉換，不負責讀檔或決定來源（專案 JSON／內建表三分屬 FR-06
/// 規則 7，另一票範圍）。
library;

import 'dart:developer' as developer show log;

import 'package:graph_project_docs_manager/schema/type_table.dart';

const _tag = 'schema.type_table_json_codec';

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
TypeTable typeTableFromJson(Map<String, dynamic> json) {
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
      ),
      idPattern: _parseIdPattern(typeName, typeJson['id_pattern'] as String?),
      completenessFields: _parseCompletenessFields(completenessJson[typeName]),
    );
  }

  return TypeTable(Map.unmodifiable(entries));
}

/// `null` 代表型別表中不帶 `carrier_path_patterns` 欄位（規則 3）；
/// 非 `null` 時逐元素轉成 [CarrierPathPattern]，壞元素拒收並寫日誌，不影響
/// 同批其他元素（0.3.0-W3-531）。
List<CarrierPathPattern>? _parseCarrierPathPatterns(String typeName, dynamic raw) {
  if (raw == null) {
    return null;
  }
  final list = raw as List<dynamic>;
  final patterns = <CarrierPathPattern>[];
  for (final element in list) {
    final map = element as Map<String, dynamic>;
    final pattern = map['pattern'] as String;
    final specificity = _parseSpecificity(typeName, pattern, map['specificity']);
    if (specificity == null) {
      continue;
    }
    try {
      patterns.add(CarrierPathPattern(pattern: pattern, specificity: specificity));
    } on FormatException catch (error) {
      developer.log(
        '型別 $typeName 的 carrier_path_patterns 模式無法編譯，已拒收：$pattern（$error）', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    }
  }
  return patterns;
}

/// `specificity` 必須是長度為 2 的整數清單（規則 6）；長度不對時拒收該筆
/// 模式並寫日誌，回傳 `null`。
PathSpecificity? _parseSpecificity(String typeName, String pattern, dynamic raw) {
  final list = raw as List<dynamic>;
  if (list.length != 2) {
    developer.log(
      '型別 $typeName 的模式 $pattern specificity 長度應為 2，實得 ${list.length}，已拒收', // i18n-exempt: 開發者診斷 log
      name: _tag,
      level: 900,
    );
    return null;
  }
  return (
    literalSegmentCount: list[0] as int,
    crossSegmentWildcardCount: list[1] as int,
  );
}

/// 驗證 `id_pattern` 可被 [RegExp] 編譯；不合法者拒收為 `null` 並寫日誌
/// （0.3.0-W3-531：消費端不應收到無法編譯的字串）。
String? _parseIdPattern(String typeName, String? raw) {
  if (raw == null) {
    return null;
  }
  try {
    RegExp(raw);
    return raw;
  } on FormatException catch (error) {
    developer.log(
      '型別 $typeName 的 id_pattern 無法編譯，已拒收：$raw（$error）', // i18n-exempt: 開發者診斷 log
      name: _tag,
      level: 900,
    );
    return null;
  }
}

Set<String> _parseCompletenessFields(dynamic raw) {
  if (raw == null) {
    return const <String>{};
  }
  return (raw as List<dynamic>).map((value) => value as String).toSet();
}
