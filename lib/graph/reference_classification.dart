/// SPEC-007 FR-03 引用值有序分類：格式錯誤 → 自我引用 → 斷邊 → 解析成功。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

const _flowStepTypeName = 'FlowStep';

enum MalformedReason { invalidShape, patternMismatch, selfReference }

enum DanglingReason { targetMissing, targetDuplicated }

/// 解析成功的引用值（參與 FR-04／FR-05 建邊）。
class ResolvedRef {
  const ResolvedRef({required this.ref, required this.targetId});

  final ReferenceValue ref;
  final String targetId;
}

/// 輕節點、重複 ID 與三類分類結果。
class ReferenceClassification {
  const ReferenceClassification({
    required this.lightNodes,
    required this.duplicates,
    required this.resolved,
    required this.dangling,
    required this.malformed,
    required this.totalReferences,
    this.skippedCount = 0,
  });

  final List<LightNode> lightNodes;
  final List<DuplicateIdGraphDefect> duplicates;
  final List<ResolvedRef> resolved;
  final List<DanglingRefGraphDefect> dangling;
  final List<MalformedRefGraphDefect> malformed;

  /// 抽取階段的引用值總數（獨立於三類加總）。
  final int totalReferences;

  /// `closed_by` 略過數（FR-03〈closed_by 的略過規則〉）；不計入 [totalReferences]。
  final int skippedCount;
}

/// 需求：[SPEC-007 FR-02、FR-03] 建輕節點、抽取引用值並依序分類。
///
/// 重複 ID 節點不抽取、不計入總數；不部分救回（D3）。
ReferenceClassification classifyGraphReferences({
  required List<RawNode> rawNodes,
  required Iterable<EdgeTypeEntry> edgeTypes,
  required Map<String, NodeTypeEntry> nodeTypes,
  void Function()? onIdLookup,
  LogSink<GraphLogEvent>? logSink,
}) {
  final log = logSink ?? defaultGraphLogSink;
  final build = buildLightNodes(rawNodes);
  final graphIds = {for (final node in build.nodes) node.id};
  final duplicateIds = build.duplicateIds;
  final patterns = [
    for (final type in nodeTypes.values)
      if (type.idRegExp != null) type.idRegExp!,
  ];
  // FlowStep 的 id 是流程內區域名稱（小寫單字），不是圖上的語料節點；其 pattern
  // 會誤收 `none` 這類哨兵值，故判定外部格式時不計入（見 Solution 的規格缺口）。
  final closedByPatterns = [
    for (final entry in nodeTypes.entries)
      if (entry.key != _flowStepTypeName && entry.value.idRegExp != null)
        entry.value.idRegExp!,
  ];
  final resolved = <ResolvedRef>[];
  final dangling = <DanglingRefGraphDefect>[];
  final malformed = <MalformedRefGraphDefect>[];
  var total = 0;
  var skipped = 0;
  for (final raw in rawNodes) {
    final id = raw.frontmatter['id'];
    if (id is! String || duplicateIds.contains(id)) {
      continue;
    }
    final refs = extractReferenceValues(
      node: raw,
      sourceId: id,
      edgeTypes: edgeTypes,
    );
    for (final ref in refs) {
      if (_isClosedBySkipped(ref, closedByPatterns)) {
        skipped++;
        log(
          GraphLogEvent.closedBySkipped,
          LogFields.empty,
          level: LogLevel.debug,
        );
        continue;
      }
      total++;
      final reason = _malformedReason(ref, patterns);
      if (reason != null) {
        malformed.add(MalformedRefGraphDefect(ref: ref, reason: reason));
      } else if (_lookupId(graphIds, ref.value, onIdLookup)) {
        resolved.add(ResolvedRef(ref: ref, targetId: ref.value! as String));
      } else {
        dangling.add(
          DanglingRefGraphDefect(
            ref: ref,
            reason: _danglingReason(ref, duplicateIds),
          ),
        );
      }
    }
  }
  return ReferenceClassification(
    lightNodes: build.nodes,
    duplicates: build.duplicates,
    resolved: resolved,
    dangling: dangling,
    malformed: malformed,
    totalReferences: total,
    skippedCount: skipped,
  );
}

/// 需求：[SPEC-007 FR-03〈closed_by 的略過規則〉] 字串值在圖上無同 id 節點且非
/// 字串值不符合任何本專案 id_pattern（外部格式）即略過；符合格式但語料內
/// 不存在者照常分類為 danglingRef（用戶改判，2026-11-05）；形狀不合法不略過。
bool _isClosedBySkipped(ReferenceValue ref, List<RegExp> patterns) {
  final value = ref.value;
  return ref.edgeTypeName == closedByEdgeTypeName &&
      ref.isShapeValid &&
      value is String &&
      !patterns.any((pattern) => pattern.hasMatch(value));
}

/// ID 索引查詢；每次查詢通知 [onIdLookup]（G9 計數注入點）。
bool _lookupId(Set<String> graphIds, Object? id, void Function()? onIdLookup) {
  onIdLookup?.call();
  return graphIds.contains(id);
}

MalformedReason? _malformedReason(ReferenceValue ref, List<RegExp> patterns) {
  final value = ref.value;
  if (!ref.isShapeValid || value is! String) {
    return MalformedReason.invalidShape;
  }
  if (!patterns.any((pattern) => pattern.hasMatch(value))) {
    return MalformedReason.patternMismatch;
  }
  return value == ref.sourceId ? MalformedReason.selfReference : null;
}

DanglingReason _danglingReason(ReferenceValue ref, Set<String> duplicateIds) =>
    duplicateIds.contains(ref.value)
    ? DanglingReason.targetDuplicated
    : DanglingReason.targetMissing;
