/// 破洞項 id 的唯一產生點（SPEC-001 §5 表二）。
///
/// 破洞頁投影與 `app/round_gaps.dart` 的 id 集合共用本檔，id 規則只此一份。
/// 純函式：不讀檔、不碰 provider；不依賴輪次結果與 schema。
library;

import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

/// 分節 category id（SPEC-001 §5 表一）。
const gapCategoryIdParseFailure = 'parse-failure';
const gapCategoryIdFlowBlockMalformed = 'flow-block-malformed';
const gapCategoryIdNonDomainPathsMalformed = 'non-domain-paths-malformed';
const gapCategoryIdGraphDefect = 'graph-defect';
const gapCategoryIdGraphDefectFlow = 'graph-defect-flow';
const gapCategoryIdOrphanEvent = 'orphan-event';
const gapCategoryIdEventDeclarationMismatch = 'event-declaration-mismatch';

/// 需求：[SPEC-001 §5 表二] 各成分以 URI component 編碼後以 `:` 串接。
/// 編碼後成分不含 `:`，串接結果與成分序列一對一。
String gapItemIdOf(List<Object?> components) =>
    components.map((c) => Uri.encodeComponent('$c')).join(':');

/// 同輪內 id 配發器：成分完全相同者第二筆起加 `#N` 後綴。
class GapItemIdAllocator {
  final Map<String, int> _seen = {};

  String next(List<Object?> components) {
    final base = gapItemIdOf(components);
    final count = (_seen[base] ?? 0) + 1;
    _seen[base] = count;
    return count == 1 ? base : '$base#$count';
  }
}

/// 解析類破洞（003／004／005）的 id 成分。
List<Object?> parseFailureIdComponents(ParseFailureGap gap) => switch (gap) {
  CarrierParseFailureGap() => [gapCategoryIdParseFailure, gap.path],
  FlowBlockMalformedGap() => [gapCategoryIdFlowBlockMalformed, gap.path],
  NonDomainPathsMalformedGap() => [
    gapCategoryIdNonDomainPathsMalformed,
    gap.path,
  ],
};

/// 孤立事件的 id 成分。
List<Object?> orphanEventIdComponents(OrphanEventGap gap) => [
  gapCategoryIdOrphanEvent,
  gap.evtId,
];

/// 事件宣告不符的 id 成分。
List<Object?> eventMismatchIdComponents(EventDeclarationMismatchGap gap) => [
  gapCategoryIdEventDeclarationMismatch,
  gap.evtId,
  gap.direction.name,
  gap.domain,
];

/// graphDefect 的 id 成分。
List<Object?> graphDefectIdComponents(GraphDefectGap gap) {
  final kind = gap.kind.name;
  return switch (gap.defect) {
    final DanglingRefGraphDefect d => [
      kind,
      d.ref.sourceId,
      d.ref.fieldName,
      d.ref.value,
    ],
    final MalformedRefGraphDefect d => [
      kind,
      d.ref.sourceId,
      d.ref.fieldName,
      d.ref.value,
    ],
    final DuplicateIdGraphDefect d => [kind, d.id],
    final MultiSourceGraphDefect d => [kind, d.from, d.edgeType],
    final DomainDuplicateDeclarationGraphDefect d => [kind, d.domain],
    final FlowGraphDefect d => [kind, d.ucId, d.stepId, d.field, d.rawValue],
  };
}
