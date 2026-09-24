/// FR-06 型別表來源三分（規則 7；SPEC-006-test-design.md §3.1 S5、§3.4 K4）。
///
/// 判斷路徑模式（`carrier_path_patterns`）該取自專案 `tracking_schema.json`
/// 或 App 內建型別表副本。`id_pattern`、完整性集合等其他欄位不受本決策
/// 影響，永遠取自專案 JSON（S5-6：只補路徑模式，非整表替換）。
///
/// 依賴方向：本檔屬 Schema domain（L0），不得 import 任何上層 domain
/// （`docs/domain-map.md` §2）。版本比較邏輯住在同層的
/// `schema_version.dart`（L0），`lib/screens/domain_view/domain_view_schema_version.dart`
/// （L4 畫面狀態層）經 import／export 取用同一份實作——L4 依賴 L0 為
/// 允許方向，不是「避免反向依賴」（先前檔頭說法有誤，已更正）。
library;

import 'package:graph_project_docs_manager/schema/schema_version.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

/// 路徑模式的來源判定（規則 7 三選一）。
enum PathPatternSource {
  /// 專案 JSON 有 `carrier_path_patterns` 欄位，直接使用。
  projectJson,

  /// 專案 JSON 缺欄位，但版本不高於內建版本，從內建表補上。
  builtinTable,

  /// 專案 JSON 缺欄位，且（版本高於內建版本，或內建表也沒有），查詢不可用。
  unavailable,
}

/// 型別表來源三分的結果。
class SchemaSourceResolution {
  const SchemaSourceResolution({
    required this.typeTable,
    required this.pathPatternSource,
  });

  /// 決議後的型別表：路徑模式依 [pathPatternSource] 決定來源，
  /// `id_pattern`／完整性集合固定取自專案 JSON（不存在則為 `null`／空集合）。
  final TypeTable typeTable;

  final PathPatternSource pathPatternSource;

  /// SPEC-001 §1 畫面旗標：路徑模式是否取自內建表（供「路徑模式取自內建表」
  /// 提示使用）。
  bool get isPathPatternFromBuiltin =>
      pathPatternSource == PathPatternSource.builtinTable;

  /// FR-06 查詢是否可用（規則 7：兩者都取不到時查詢不可用）。
  bool get isQueryAvailable =>
      pathPatternSource != PathPatternSource.unavailable;
}

/// 決議型別表來源（規則 7）。
///
/// [projectSchemaJson] 為專案 `tracking_schema.json` 解碼後的頂層 `Map`，
/// 不存在專案 JSON 時傳 `null`（等同缺欄位路徑，因為沒有欄位可言）。
/// [builtinSchemaJson] 為 App 內建型別表副本
/// （`assets/schema/builtin_tracking_schema.json`）解碼後的頂層 `Map`，
/// 必要參數：內建副本隨 App 內嵌，恆存在。
SchemaSourceResolution resolveSchemaSource({
  required Map<String, dynamic>? projectSchemaJson,
  required Map<String, dynamic> builtinSchemaJson,
}) {
  final builtinTable = typeTableFromJson(builtinSchemaJson);
  final builtinVersion =
      builtinSchemaJson['schema_generated_at_framework_version'] as String?;

  if (projectSchemaJson == null) {
    return _resolveWithoutProjectPathPatterns(
      projectTable: null,
      projectVersion: null,
      builtinTable: builtinTable,
      builtinVersion: builtinVersion,
    );
  }

  final projectTable = typeTableFromJson(projectSchemaJson);
  if (projectTable.pathParticipatingTypes.isNotEmpty) {
    return SchemaSourceResolution(
      typeTable: projectTable,
      pathPatternSource: PathPatternSource.projectJson,
    );
  }

  final projectVersion =
      projectSchemaJson['schema_generated_at_framework_version'] as String?;
  return _resolveWithoutProjectPathPatterns(
    projectTable: projectTable,
    projectVersion: projectVersion,
    builtinTable: builtinTable,
    builtinVersion: builtinVersion,
  );
}

/// 專案 JSON 缺路徑模式欄位時的分支（規則 7 後半段）。
///
/// [projectTable] 為 `null` 代表沒有專案 JSON 可言（型別表整體視為空）；
/// 非 `null` 但缺路徑模式時，`id_pattern`／完整性集合仍取自它（S5-6）。
SchemaSourceResolution _resolveWithoutProjectPathPatterns({
  required TypeTable? projectTable,
  required String? projectVersion,
  required TypeTable builtinTable,
  required String? builtinVersion,
}) {
  final builtinHasPatterns = builtinTable.pathParticipatingTypes.isNotEmpty;
  // 版本缺席（任一為 null）時直接判定查詢不可用，不呼叫版本比較
  // （`isHigherThanBuiltinSchemaVersion` 要求兩個非 null 字串參數；
  // 沒有版本可比較時沒有「補內建表是否安全」可言）。
  final versionAllowsBuiltin =
      projectVersion != null &&
      builtinVersion != null &&
      !isHigherThanBuiltinSchemaVersion(projectVersion, builtinVersion);

  if (builtinHasPatterns && versionAllowsBuiltin) {
    return SchemaSourceResolution(
      typeTable: _mergeBuiltinPathPatterns(
        projectTable: projectTable,
        builtinTable: builtinTable,
      ),
      pathPatternSource: PathPatternSource.builtinTable,
    );
  }

  return SchemaSourceResolution(
    typeTable: projectTable ?? const TypeTable(<String, NodeTypeEntry>{}),
    pathPatternSource: PathPatternSource.unavailable,
  );
}

/// 合併：路徑模式取自內建表，`id_pattern`／完整性集合固定取自專案 JSON
/// （S5-2、S5-6）——只補路徑模式，非整表替換。專案 JSON 該型別缺
/// `id_pattern` 時，結果保留 `null`（[NodeTypeEntry.idPattern] 本為
/// nullable），不退回內建表：內建表的 `id_pattern` 屬另一來源（可能與
/// 專案定義衝突），S5-6 鑑別的正是「不可混用」。
TypeTable _mergeBuiltinPathPatterns({
  required TypeTable? projectTable,
  required TypeTable builtinTable,
}) {
  final merged = <String, NodeTypeEntry>{};
  final allNames = <String>{
    ...?projectTable?.nodeTypes.keys,
    ...builtinTable.nodeTypes.keys,
  };

  for (final name in allNames) {
    final projectEntry = projectTable?.nodeTypes[name];
    final builtinEntry = builtinTable.nodeTypes[name];
    merged[name] = NodeTypeEntry(
      name: name,
      carrierPathPatterns: builtinEntry?.carrierPathPatterns,
      idPattern: projectEntry?.idPattern,
      completenessFields: projectEntry?.completenessFields ?? const <String>{},
    );
  }

  return TypeTable(Map.unmodifiable(merged));
}

