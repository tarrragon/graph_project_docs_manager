/// 真實型別表 fixture（SPEC-006-test-design.md §1.4）。
///
/// 讀取 `.claude/skills/doc/doc_system/core/tracking_schema.json`（上游
/// SSOT `tracking_schema.py` 的衍生產物），供 S1、S2、K2、K3 群組測試真實
/// 型別表內容，不使用 `type_table_builder.dart` 的最小宣告式 fixture。
library;

import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

/// `tracking_schema.json` 相對專案根目錄的路徑（`flutter test` 預設
/// 工作目錄即為專案根目錄）。
const _trackingSchemaJsonPath =
    '.claude/skills/doc/doc_system/core/tracking_schema.json';

/// 讀取並解析真實 `tracking_schema.json` 為 [TypeTable]。
///
/// 找不到檔案時直接拋出 [FileSystemException]，讓測試以紅燈明示環境缺
/// 少上游 SSOT，不靜默降級（型別表缺席時的降級策略屬 App 執行期行為，
/// CLAUDE.md §6，非測試 fixture 職責）。
TypeTable readRealTypeTable() {
  final file = File(_trackingSchemaJsonPath);
  final jsonText = file.readAsStringSync();
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  return typeTableFromJson(decoded);
}

/// 讀取並回傳真實 `tracking_schema.json` 解碼後的原始 [Map]，供需要直接
/// 檢視 JSON 結構（而非已轉換為 [TypeTable]）的測試使用（如 K3 檢查
/// `completeness_semantics` 是否存在）。
Map<String, dynamic> readRealTrackingSchemaJson() {
  final file = File(_trackingSchemaJsonPath);
  final jsonText = file.readAsStringSync();
  return jsonDecode(jsonText) as Map<String, dynamic>;
}
