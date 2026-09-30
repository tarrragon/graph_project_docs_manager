/// SPEC-007 FR-01 邊型模型與解碼結果（設計約束 D6）。
///
/// 欄位名、基數、是否有反向欄位一律取自型別表；程式內唯一的鍵名例外是
/// 排除 `domain_dependency`（由 `0.5.0-W1-001` 移除）。
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
  });

  final String name;
  final String edgeClass;
  final String forwardField;
  final String? reverseField;
  final EdgeCardinality forwardCardinality;
  final String layer;
}

/// 建圖不可用的原因碼（與 SPEC-006 FR-08「版本不在已知範圍」同一套）。
enum EdgeTypeUnavailableReason {
  /// 缺 `edge_types`，且版本不在 App 已知範圍。
  versionOutOfKnownRange,

  /// `edge_types` 有邊型缺正向基數且無法從內建表補。
  missingForwardCardinality,
}

/// 邊型解碼結果。
class EdgeTypeResolution {
  const EdgeTypeResolution({required this.edgeTypes, this.unavailableReason});

  /// 全部邊型（含 proposed 與 `domain_dependency`）。
  final Map<String, EdgeTypeEntry> edgeTypes;

  /// 非 `null` 代表建圖不可用。
  final EdgeTypeUnavailableReason? unavailableReason;

  bool get isGraphAvailable => unavailableReason == null;

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
  final builtinVersion =
      builtinSchemaJson['schema_generated_at_framework_version'] as String?;
  final projectVersion =
      projectSchemaJson?['schema_generated_at_framework_version'] as String?;
  final inRange =
      builtinVersion != null &&
      isWithinKnownSchemaRange(projectVersion, builtinVersion);
  final project = projectSchemaJson == null
      ? null
      : typeTableFromJson(projectSchemaJson).edgeTypes;

  if (project == null) {
    return inRange
        ? _fillMissingCardinality(builtin, builtin, true)
        : EdgeTypeResolution(
            edgeTypes: const {},
            unavailableReason: EdgeTypeUnavailableReason.versionOutOfKnownRange,
          );
  }
  return _fillMissingCardinality(project, builtin, inRange);
}

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
    result[raw.name] = raw.toEntry(cardinality);
  }
  return EdgeTypeResolution(
    edgeTypes: result,
    unavailableReason: missing
        ? EdgeTypeUnavailableReason.missingForwardCardinality
        : null,
  );
}
