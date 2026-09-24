/// FR-06 型別表 JSON 解析（SPEC-006-test-design.md §3.4 K2、K3）。
///
/// 把 `tracking_schema.json`（`.claude/skills/doc/doc_system/core/
/// tracking_schema.py` 的衍生產物）解碼後的 `Map` 轉成 [TypeTable]。本檔
/// 只做資料轉換，不負責讀檔或決定來源（專案 JSON／內建表三分屬 FR-06
/// 規則 7，另一票範圍）。
library;

import 'package:graph_project_docs_manager/schema/type_table.dart';

/// 把 `tracking_schema.json` 解碼後的頂層 [Map] 轉成 [TypeTable]。
///
/// `node_types` 提供每個型別的 `carrier_path_patterns`（可缺）與
/// `id_pattern`（可缺）；`completeness_fields` 是與 `node_types` 平行的
/// 頂層鍵，依型別名合併進對應的 [NodeTypeEntry]（規則 3：依欄位存在與否
/// 判定是否參與路徑比對，不依型別名，SPEC-006 D9）。
TypeTable typeTableFromJson(Map<String, dynamic> json) {
  final nodeTypesJson = json['node_types'] as Map<String, dynamic>? ?? const {};
  final completenessJson =
      json['completeness_fields'] as Map<String, dynamic>? ?? const {};

  final entries = <String, NodeTypeEntry>{};
  for (final typeName in nodeTypesJson.keys) {
    final typeJson = nodeTypesJson[typeName] as Map<String, dynamic>;
    entries[typeName] = NodeTypeEntry(
      name: typeName,
      carrierPathPatterns: _parseCarrierPathPatterns(typeJson['carrier_path_patterns']),
      idPattern: typeJson['id_pattern'] as String?,
      completenessFields: _parseCompletenessFields(completenessJson[typeName]),
    );
  }

  return TypeTable(Map.unmodifiable(entries));
}

/// `null` 代表型別表中不帶 `carrier_path_patterns` 欄位（規則 3）；
/// 非 `null` 時逐元素轉成 [CarrierPathPattern]。
List<CarrierPathPattern>? _parseCarrierPathPatterns(dynamic raw) {
  if (raw == null) {
    return null;
  }
  final list = raw as List<dynamic>;
  return list
      .map((element) {
        final map = element as Map<String, dynamic>;
        final specificity = (map['specificity'] as List<dynamic>)
            .map((value) => value as int)
            .toList(growable: false);
        return CarrierPathPattern(
          pattern: map['pattern'] as String,
          specificity: specificity,
        );
      })
      .toList(growable: false);
}

Set<String> _parseCompletenessFields(dynamic raw) {
  if (raw == null) {
    return const <String>{};
  }
  return (raw as List<dynamic>).map((value) => value as String).toSet();
}
