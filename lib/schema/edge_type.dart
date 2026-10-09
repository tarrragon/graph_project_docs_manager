/// SPEC-007 FR-01 邊型模型與解碼結果（設計約束 D6）。
///
/// 欄位名、基數、是否有反向欄位一律取自型別表；程式內的鍵名例外集中在本檔
/// 一處：排除 `domain_dependency`（[EdgeTypeResolution.activeEdgeTypes]，
/// 由 `0.6.0-W1-074` 承接移除）。無向由型別表 `direction` 欄判定
/// （FR-05〈無向的判定〉），不比對鍵名。
///
/// 依賴方向：Schema domain（L0），不得 import 上層 domain。
library;

import 'package:graph_project_docs_manager/schema/schema_version.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

export 'package:graph_project_docs_manager/schema/type_table.dart'
    show EdgeCardinality, EdgeDirection, NodeTypeEntry;

/// 由 schema JSON 解碼節點型別表，供 Graph 取用而不必碰型別表編解碼細節。
Map<String, NodeTypeEntry> nodeTypesFromSchemaJson(
  Map<String, dynamic> schemaJson,
) => typeTableFromJson(schemaJson).nodeTypes;

/// 單一邊型。
class EdgeTypeEntry {
  const EdgeTypeEntry({
    required this.name,
    required this.edgeClass,
    required this.forwardField,
    required this.reverseField,
    required this.forwardCardinality,
    required this.layer,
    required this.direction,
    required this.directionSource,
  });

  final String name;
  final String edgeClass;
  final String forwardField;
  final String? reverseField;
  final EdgeCardinality forwardCardinality;
  final String layer;

  /// 方向性，取自型別表 `direction` 欄（缺欄時依來源補值，FR-01）。
  final EdgeDirection direction;

  /// [direction] 的來源。
  final DirectionSource directionSource;

  /// 無向邊（端點集合，無方向）：`direction == undirected`（FR-05）。
  bool get isUndirected => direction == EdgeDirection.undirected;
}

/// `direction` 的來源值（SPEC-007 FR-01）。[defaultDirected] 即「預設（有向）」。
enum DirectionSource { projectTable, builtinTable, defaultDirected }

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
        ? _fillMissingCardinality(builtin, builtin, true, builtin.keys.toSet())
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
  final restoredNames = {
    for (final name in rejected)
      if (builtin[name] != null) name,
  };
  return _fillMissingCardinality(restored, builtin, inRange, restoredNames);
}

/// 缺 `direction` 補值（FR-01）：版本在已知範圍內且內建表有該鍵名取內建表，
/// 否則照有向處理並回報 [DirectionSource.defaultDirected]。
({EdgeDirection direction, DirectionSource source})? _resolveDirection(
  EdgeTypeDecl raw,
  Map<String, EdgeTypeDecl> builtin,
  bool inRange,
  bool declFromBuiltin,
) {
  if (raw.direction != null) {
    return (
      direction: raw.direction!,
      source: declFromBuiltin
          ? DirectionSource.builtinTable
          : DirectionSource.projectTable,
    );
  }
  if (!inRange) {
    return null; // 繞過關卡呼叫路徑：版本不在已知範圍且缺 direction，建圖不可用（D2）
  }
  final fromBuiltin = builtin[raw.name]?.direction;
  return fromBuiltin == null
      ? (
          direction: EdgeDirection.directed,
          source: DirectionSource.defaultDirected,
        )
      : (direction: fromBuiltin, source: DirectionSource.builtinTable);
}

/// 解碼宣告 + 決議後的基數與方向 → 已決議邊型。
EdgeTypeEntry _entryFromDecl(
  EdgeTypeDecl raw,
  EdgeCardinality cardinality,
  ({EdgeDirection direction, DirectionSource source}) resolved,
) => EdgeTypeEntry(
  name: raw.name,
  edgeClass: raw.edgeClass,
  forwardField: raw.forwardField,
  reverseField: raw.reverseField,
  forwardCardinality: cardinality,
  layer: raw.layer,
  direction: resolved.direction,
  directionSource: resolved.source,
);

EdgeTypeResolution _fillMissingCardinality(
  Map<String, EdgeTypeDecl> project,
  Map<String, EdgeTypeDecl> builtin,
  bool inRange,
  Set<String> builtinSourced,
) {
  final result = <String, EdgeTypeEntry>{};
  var missing = false;
  var directionUnresolved = false;
  for (final raw in project.values) {
    final cardinality =
        raw.forwardCardinality ??
        (inRange ? builtin[raw.name]?.forwardCardinality : null);
    if (cardinality == null) {
      missing = true;
      continue;
    }
    final resolved = _resolveDirection(
      raw,
      builtin,
      inRange,
      builtinSourced.contains(raw.name),
    );
    if (resolved == null) {
      directionUnresolved = true;
      continue;
    }
    result[raw.name] = _entryFromDecl(raw, cardinality, resolved);
  }
  return EdgeTypeResolution(
    edgeTypes: result,
    unavailableReason: missing
        ? EdgeTypeUnavailableReason.missingForwardCardinality
        : directionUnresolved
        ? EdgeTypeUnavailableReason.projectVersionOutOfKnownRange
        : null,
  );
}
