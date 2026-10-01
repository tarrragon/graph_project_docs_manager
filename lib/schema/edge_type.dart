/// SPEC-007 FR-01 邊型模型與解碼結果（設計約束 D6）。
///
/// 欄位名、基數、是否有反向欄位一律取自型別表；程式內的鍵名例外集中在本檔
/// 兩處：排除 `domain_dependency`（[EdgeTypeResolution.activeEdgeTypes]）、
/// 認定 `association` 為無向（`isUndirected`，FR-05〈無向的判定〉）。
/// 兩處皆由 `0.5.0-W1-001` 移除；Graph 只讀旗標，不再比對鍵名。
///
/// 依賴方向：Schema domain（L0），不得 import 上層 domain。
library;

import 'package:graph_project_docs_manager/schema/schema_version.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

export 'package:graph_project_docs_manager/schema/type_table.dart'
    show EdgeCardinality;

/// 單一邊型。
class EdgeTypeEntry {
  const EdgeTypeEntry({
    required this.name,
    required this.edgeClass,
    required this.forwardField,
    required this.reverseField,
    required this.forwardCardinality,
    required this.layer,
    this.isUndirected = false,
  });

  final String name;
  final String edgeClass;
  final String forwardField;
  final String? reverseField;
  final EdgeCardinality forwardCardinality;
  final String layer;

  /// 無向邊（端點集合，無方向）；由 [resolveEdgeTypes] 依鍵名填入（D6）。
  final bool isUndirected;
}

/// 建圖不可用的原因碼（與 SPEC-006 FR-08「版本不在已知範圍」同一套）。
enum EdgeTypeUnavailableReason {
  /// 缺 `edge_types`，且版本不在 App 已知範圍。
  projectVersionOutOfKnownRange,

  /// `edge_types` 有邊型缺正向基數且無法從內建表補。
  missingForwardCardinality,

  /// `edge_types` 有條目不合法被拒收，且版本高於內建表而無法補回
  /// （SPEC-007 v1.8 FR-01）；優先於 [missingForwardCardinality]（v1.9）。
  invalidEdgeTypeEntry,
}

/// 邊型解碼結果。
class EdgeTypeResolution {
  const EdgeTypeResolution({required this.edgeTypes, this.unavailableReason});

  /// 全部邊型（含 proposed 與 `domain_dependency`）。
  final Map<String, EdgeTypeEntry> edgeTypes;

  /// 非 `null` 代表建圖不可用。
  final EdgeTypeUnavailableReason? unavailableReason;

  /// 使用中邊型：established 扣 `domain_dependency`（D6）。
  Iterable<EdgeTypeEntry> get activeEdgeTypes => edgeTypes.values.where(
    (edge) => edge.layer == 'established' && edge.name != _excludedByKeyName,
  );
}

const _excludedByKeyName = 'domain_dependency';

/// D6 鍵名例外：`association` 為無向邊（FR-05）。
const _undirectedByKeyName = 'association';

/// 決議邊型（FR-01）：專案表有完整 `edge_types` 直接用；缺席或缺正向基數時，
/// 版本在已知範圍內從內建表補，否則回報原因碼。
EdgeTypeResolution resolveEdgeTypes({
  required Map<String, dynamic>? projectSchemaJson,
  required Map<String, dynamic> builtinSchemaJson,
}) {
  final builtin =
      typeTableFromJson(builtinSchemaJson).edgeTypes ??
      const <String, EdgeTypeDecl>{};
  final builtinVersion = schemaVersionOf(builtinSchemaJson);
  final projectVersion = schemaVersionOf(projectSchemaJson);
  final inRange =
      builtinVersion != null &&
      isWithinKnownSchemaRange(projectVersion, builtinVersion);
  final projectTable = projectSchemaJson == null
      ? null
      : typeTableFromJson(projectSchemaJson);
  final project = projectTable?.edgeTypes;

  if (project == null) {
    return inRange
        ? _fillMissingCardinality(builtin, builtin, true)
        : EdgeTypeResolution(
            edgeTypes: const {},
            unavailableReason:
                EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
          );
  }
  final rejected = projectTable!.rejectedEdgeTypes;
  if (rejected.isNotEmpty && !inRange) {
    // v1.9：解碼階段的拒收先於基數補值判定，只回報本原因碼。
    return EdgeTypeResolution(
      edgeTypes: const {},
      unavailableReason: EdgeTypeUnavailableReason.invalidEdgeTypeEntry,
    );
  }
  final restored = <String, EdgeTypeDecl>{
    for (final name in rejected)
      if (builtin[name] != null) name: builtin[name]!,
    ...project,
  };
  return _fillMissingCardinality(restored, builtin, inRange);
}

/// 解碼宣告 + 決議後的基數 → 已決議邊型（D6：`association` 為無向）。
EdgeTypeEntry _entryFromDecl(EdgeTypeDecl raw, EdgeCardinality cardinality) =>
    EdgeTypeEntry(
      name: raw.name,
      edgeClass: raw.edgeClass,
      forwardField: raw.forwardField,
      reverseField: raw.reverseField,
      forwardCardinality: cardinality,
      layer: raw.layer,
      isUndirected: raw.name == _undirectedByKeyName,
    );

EdgeTypeResolution _fillMissingCardinality(
  Map<String, EdgeTypeDecl> project,
  Map<String, EdgeTypeDecl> builtin,
  bool inRange,
) {
  final result = <String, EdgeTypeEntry>{};
  var missing = false;
  for (final raw in project.values) {
    final cardinality =
        raw.forwardCardinality ??
        (inRange ? builtin[raw.name]?.forwardCardinality : null);
    if (cardinality == null) {
      missing = true;
      continue;
    }
    result[raw.name] = _entryFromDecl(raw, cardinality);
  }
  return EdgeTypeResolution(
    edgeTypes: result,
    unavailableReason: missing
        ? EdgeTypeUnavailableReason.missingForwardCardinality
        : null,
  );
}
