/// 破洞報告項目投影（SPEC-001 §5〈破洞報告項目投影：`parseFailure` 與
/// `graphDefect`〉表一～三與〈定案〉M1／O1／J2）。
///
/// 純函式：不讀檔、不碰 provider。輸入 Diagnostics 的破洞與圖輕節點，輸出
/// 依 O1 排序的 [GapReportCategory] 清單；空分節不產生。
library;

import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import 'gap_report_models.dart';

/// 分節 category id（SPEC-001 §5 表一）。
const gapCategoryIdParseFailure = 'parse-failure';
const gapCategoryIdFlowBlockMalformed = 'flow-block-malformed';
const gapCategoryIdNonDomainPathsMalformed = 'non-domain-paths-malformed';
const gapCategoryIdGraphDefect = 'graph-defect';
const gapCategoryIdGraphDefectFlow = 'graph-defect-flow';
const gapCategoryIdOrphanEvent = 'orphan-event';
const gapCategoryIdEventDeclarationMismatch = 'event-declaration-mismatch';

/// 分節順序（SPEC-001 §5〈定案〉O1）。
const gapCategoryOrder = <String>[
  gapCategoryIdParseFailure,
  gapCategoryIdFlowBlockMalformed,
  gapCategoryIdNonDomainPathsMalformed,
  gapCategoryIdGraphDefect,
  gapCategoryIdGraphDefectFlow,
  gapCategoryIdOrphanEvent,
  gapCategoryIdEventDeclarationMismatch,
];

/// 節點型別名：來源節點為此型別時指向型別為 [GapItemPointerType.ticket]。
const _ticketTypeName = 'Ticket';

const _tag = 'GapReportProjection';

/// 需求：[SPEC-001 §5 表一～三、〈定案〉O1] 投影破洞為報告分節與項目。
///
/// [nodes] 供查節點路徑與型別（`GraphBuiltEvent.nodes`）；
/// [eventGaps] 為 Diagnostics 的事件類偵測結果（SPEC-001 v1.52 §5〈事件類項目
/// 投影〉）；[nonDomainPathsKey] 是 EVT-CORPUS-005 說明的 `{key}` 值
/// （型別表 `non_domain_paths_key`，缺欄時由呼叫端取內建表值）。
List<GapReportCategory> projectGapReport({
  required List<ParseFailureGap> parseFailures,
  required List<GraphDefectGap> graphDefects,
  required List<LightNode> nodes,
  required String nonDomainPathsKey,
  EventGapReport eventGaps = const EventGapReport.empty(),
}) {
  final projector = _Projector(nodes, nonDomainPathsKey);
  final byCategory = <String, List<GapReportItem>>{
    for (final id in gapCategoryOrder) id: <GapReportItem>[],
  };
  for (final gap in parseFailures) {
    final (category, item) = projector.parseFailure(gap);
    byCategory[category]!.add(item);
  }
  for (final gap in graphDefects) {
    final (category, item) = projector.graphDefect(gap);
    byCategory[category]!.add(item);
  }
  for (final gap in eventGaps.orphanEvents) {
    byCategory[gapCategoryIdOrphanEvent]!.add(projector.orphanEvent(gap));
  }
  for (final gap in eventGaps.mismatches) {
    byCategory[gapCategoryIdEventDeclarationMismatch]!.add(
      projector.eventMismatch(gap),
    );
  }
  return [
    for (final id in gapCategoryOrder)
      if (byCategory[id]!.isNotEmpty)
        GapReportCategory(id: id, items: byCategory[id]!),
  ];
}

/// 需求：[SPEC-001 §5 表二] 各成分以 URI component 編碼後以 `:` 串接。
/// 編碼後成分不含 `:`，串接結果與成分序列一對一。
String gapItemIdOf(List<Object?> components) =>
    components.map((c) => Uri.encodeComponent('$c')).join(':');

/// 以 code point 序取最小者（SPEC-001 §5 表三 `duplicateId`／domain 重複宣告）。
String _minByCodePoint(Iterable<String> values) =>
    values.reduce((a, b) => _compareCodePoints(a, b) <= 0 ? a : b);

int _compareCodePoints(String a, String b) {
  final ra = a.runes.iterator;
  final rb = b.runes.iterator;
  while (true) {
    final hasA = ra.moveNext();
    final hasB = rb.moveNext();
    if (!hasA || !hasB) return hasA == hasB ? 0 : (hasA ? 1 : -1);
    if (ra.current != rb.current) return ra.current.compareTo(rb.current);
  }
}

class _Projector {
  _Projector(List<LightNode> nodes, this._nonDomainPathsKey)
    : _byId = {for (final n in nodes) n.id: n},
      _idByPath = {for (final n in nodes) n.path: n.id};

  final Map<String, LightNode> _byId;
  final Map<String, String> _idByPath;
  final String _nonDomainPathsKey;

  /// 同輪內已出現的 id 次數；成分完全相同者第二筆起加 `#N` 後綴。
  final Map<String, int> _seen = {};

  String _uniqueId(List<Object?> components) {
    final base = gapItemIdOf(components);
    final count = (_seen[base] ?? 0) + 1;
    _seen[base] = count;
    return count == 1 ? base : '$base#$count';
  }

  (String, GapReportItem) parseFailure(ParseFailureGap gap) => switch (gap) {
    CarrierParseFailureGap() => (gapCategoryIdParseFailure, _carrierItem(gap)),
    FlowBlockMalformedGap() => (
      gapCategoryIdFlowBlockMalformed,
      _flowBlockItem(gap),
    ),
    NonDomainPathsMalformedGap() => (
      gapCategoryIdNonDomainPathsMalformed,
      _nonDomainPathsItem(gap),
    ),
  };

  GapReportItem _carrierItem(CarrierParseFailureGap gap) => GapReportItem(
    id: _uniqueId([gapCategoryIdParseFailure, gap.path]),
    filePath: gap.path,
    lineNumber: gap.lineNumber,
    description: GapItemDescription(_carrierKind(gap)),
    ambiguousTypes: gap.schemaAmbiguous ? gap.candidateTypes : const [],
  );

  GapReportItem _flowBlockItem(FlowBlockMalformedGap gap) {
    final ucId = _idByPath[gap.path];
    const description = GapItemDescription(
      GapDescriptionKind.flowBlockMalformed,
    );
    final id = _uniqueId([gapCategoryIdFlowBlockMalformed, gap.path]);
    if (ucId == null) {
      // 004 的 UC 查無節點：不變式違反（UC 仍是節點，SPEC-006 FR-09）。
      _reportUnresolvedNode('flowBlockMalformed', gap.path);
      return _unresolvedItem(id, gap.path, description);
    }
    return GapReportItem(
      id: id,
      filePath: gap.path,
      pointerType: GapItemPointerType.flow,
      pointerNodeId: ucId,
      flowUcId: ucId,
      description: description,
    );
  }

  /// 降級落點（SPEC-001 §5〈定案〉）：節點查不到時，debug 下 assert 並寫
  /// warning log，release 下降為無法指向任何節點且不提供開檔。
  void _reportUnresolvedNode(String subclass, String nodeId) {
    developer.log(
      // i18n-exempt: 開發者診斷 log
      'projection: node not found subclass=$subclass id=$nodeId',
      name: _tag,
      level: 900,
    );
    assert(false, 'projection: node not found subclass=$subclass id=$nodeId');
  }

  /// 降級項目：[filePath] 放查不到的節點 ID（只顯示，不可開檔）。
  GapReportItem _unresolvedItem(
    String id,
    String nodeId,
    GapItemDescription description,
  ) => GapReportItem(
    id: id,
    filePath: nodeId,
    isOpenable: false,
    description: description,
  );

  GapReportItem _nonDomainPathsItem(NonDomainPathsMalformedGap gap) =>
      GapReportItem(
        id: _uniqueId([gapCategoryIdNonDomainPathsMalformed, gap.path]),
        filePath: gap.path,
        description: _nonDomainPathsDescription(gap),
      );

  GapItemDescription _nonDomainPathsDescription(
    NonDomainPathsMalformedGap gap,
  ) => switch (gap.subReason) {
    NonDomainPathsMalformedReason.yamlInvalid => const GapItemDescription(
      GapDescriptionKind.nonDomainPathsYamlInvalid,
    ),
    NonDomainPathsMalformedReason.keyMissing => GapItemDescription(
      GapDescriptionKind.nonDomainPathsKeyMissing,
      {'key': _nonDomainPathsKey},
    ),
    NonDomainPathsMalformedReason.notList => GapItemDescription(
      GapDescriptionKind.nonDomainPathsNotList,
      {'key': _nonDomainPathsKey},
    ),
    NonDomainPathsMalformedReason.elementNotString => GapItemDescription(
      GapDescriptionKind.nonDomainPathsNonStringElements,
      {'count': gap.nonStringElementCount ?? 0},
    ),
  };

  /// 需求：[SPEC-001 v1.52 §5 表二、表三] 孤立事件項目。
  GapReportItem orphanEvent(OrphanEventGap gap) => _eventItem(
    components: [gapCategoryIdOrphanEvent, gap.evtId],
    evtId: gap.evtId,
    ucIds: gap.ucIds,
    description: GapItemDescription(switch (gap.shape) {
      OrphanEventShape.emittedNotConsumed =>
        GapDescriptionKind.orphanEventEmittedNotConsumed,
      OrphanEventShape.consumedNotEmitted =>
        GapDescriptionKind.orphanEventConsumedNotEmitted,
    }),
  );

  /// 需求：[SPEC-001 v1.52 §5 表二、表三] 事件宣告不符項目；說明帶 domain 原值。
  GapReportItem eventMismatch(EventDeclarationMismatchGap gap) => _eventItem(
    components: [
      gapCategoryIdEventDeclarationMismatch,
      gap.evtId,
      gap.direction.name,
      gap.domain,
    ],
    evtId: gap.evtId,
    ucIds: gap.ucIds,
    description: GapItemDescription(
      switch (gap.direction) {
        EventDeclarationDirection.consumers =>
          GapDescriptionKind.eventConsumerUnmatched,
        EventDeclarationDirection.producers =>
          GapDescriptionKind.eventProducerUnmatched,
      },
      {'domain': gap.domain},
    ),
  );

  GapReportItem _eventItem({
    required List<Object?> components,
    required String evtId,
    required List<String> ucIds,
    required GapItemDescription description,
  }) {
    final id = _uniqueId(components);
    final evt = _byId[evtId];
    if (evt == null) {
      _reportUnresolvedNode('event', evtId);
      return _unresolvedItem(id, evtId, description);
    }
    return GapReportItem(
      id: id,
      filePath: evt.path,
      pointerType: GapItemPointerType.event,
      pointerNodeId: evtId,
      eventId: evtId,
      eventUcId: ucIds.firstOrNull,
      description: description,
    );
  }

  (String, GapReportItem) graphDefect(GraphDefectGap gap) {
    final kind = gap.kind;
    return switch (gap.defect) {
      final DanglingRefGraphDefect d => (
        gapCategoryIdGraphDefect,
        _danglingItem(kind, d),
      ),
      final MalformedRefGraphDefect d => (
        gapCategoryIdGraphDefect,
        _malformedItem(kind, d),
      ),
      final DuplicateIdGraphDefect d => (
        gapCategoryIdGraphDefect,
        _duplicateIdItem(kind, d),
      ),
      final MultiSourceGraphDefect d => (
        gapCategoryIdGraphDefect,
        _multiSourceItem(kind, d),
      ),
      final DomainDuplicateDeclarationGraphDefect d => (
        gapCategoryIdGraphDefect,
        _domainDuplicateItem(kind, d),
      ),
      final FlowGraphDefect d => (
        gapCategoryIdGraphDefectFlow,
        _flowItem(kind, d),
      ),
    };
  }

  GapItemPointerType _nodePointerType(String nodeId) =>
      _byId[nodeId]?.typeName == _ticketTypeName
      ? GapItemPointerType.ticket
      : GapItemPointerType.otherNode;

  GapReportItem _danglingItem(GraphDefectKind kind, DanglingRefGraphDefect d) =>
      GapReportItem(
        id: _uniqueId([
          kind.name,
          d.ref.sourceId,
          d.ref.fieldName,
          d.ref.value,
        ]),
        filePath: d.ref.sourcePath,
        pointerType: _nodePointerType(d.ref.sourceId),
        pointerNodeId: d.ref.sourceId,
        description: GapItemDescription(
          d.reason == DanglingReason.targetMissing
              ? GapDescriptionKind.danglingRefTargetMissing
              : GapDescriptionKind.danglingRefTargetDuplicated,
          {'field': d.ref.fieldName, 'value': '${d.ref.value}'},
        ),
      );

  GapReportItem _malformedItem(
    GraphDefectKind kind,
    MalformedRefGraphDefect d,
  ) => GapReportItem(
    id: _uniqueId([kind.name, d.ref.sourceId, d.ref.fieldName, d.ref.value]),
    filePath: d.ref.sourcePath,
    pointerType: _nodePointerType(d.ref.sourceId),
    pointerNodeId: d.ref.sourceId,
    description: GapItemDescription(_malformedKind(d.reason), {
      'field': d.ref.fieldName,
      'value': '${d.ref.value}',
    }),
  );

  GapReportItem _duplicateIdItem(
    GraphDefectKind kind,
    DuplicateIdGraphDefect d,
  ) => GapReportItem(
    id: _uniqueId([kind.name, d.id]),
    filePath: _minByCodePoint(d.paths),
    description: GapItemDescription(GapDescriptionKind.duplicateId, {
      'id': d.id,
      'count': d.paths.length,
      'paths': d.paths,
    }),
  );

  GapReportItem _multiSourceItem(
    GraphDefectKind kind,
    MultiSourceGraphDefect d,
  ) {
    final origin = _byId[d.from];
    final id = _uniqueId([kind.name, d.from, d.edgeType]);
    final description = GapItemDescription(GapDescriptionKind.multiSource, {
      'edgeType': d.edgeType,
      'targets': [for (final t in d.targets) t.to],
    });
    if (origin == null) {
      _reportUnresolvedNode(kind.name, d.from);
      return _unresolvedItem(id, d.from, description);
    }
    return GapReportItem(
      id: id,
      filePath: origin.path,
      pointerType: _nodePointerType(d.from),
      pointerNodeId: d.from,
      description: description,
    );
  }

  GapReportItem _domainDuplicateItem(
    GraphDefectKind kind,
    DomainDuplicateDeclarationGraphDefect d,
  ) {
    final bundleId = _minByCodePoint(d.bundleIds);
    final bundle = _byId[bundleId];
    final id = _uniqueId([kind.name, d.domain]);
    final description = GapItemDescription(
      GapDescriptionKind.domainDeclaredTwice,
      {'domain': d.domain, 'bundles': d.bundleIds},
    );
    if (bundle == null) {
      _reportUnresolvedNode(kind.name, bundleId);
      return _unresolvedItem(id, bundleId, description);
    }
    return GapReportItem(
      id: id,
      filePath: bundle.path,
      pointerType: GapItemPointerType.otherNode,
      pointerNodeId: bundleId,
      description: description,
    );
  }

  GapReportItem _flowItem(GraphDefectKind kind, FlowGraphDefect d) {
    final uc = _byId[d.ucId];
    final stepId = '${d.stepId}';
    final id = _uniqueId([kind.name, d.ucId, d.stepId, d.field, d.rawValue]);
    if (uc == null) {
      _reportUnresolvedNode(kind.name, d.ucId);
      return _unresolvedItem(id, d.ucId, _flowDescription(d, stepId));
    }
    return GapReportItem(
      id: id,
      filePath: uc.path,
      pointerType: GapItemPointerType.flow,
      pointerNodeId: d.ucId,
      flowUcId: d.ucId,
      flowStepId: stepId,
      description: _flowDescription(d, stepId),
    );
  }

  GapItemDescription _flowDescription(FlowGraphDefect d, String stepId) =>
      switch (d.kind) {
        FlowDefectKind.unresolvedReference => GapItemDescription(
          GapDescriptionKind.flowRefUnresolved,
          {'stepId': stepId, 'field': d.field, 'value': '${d.rawValue}'},
        ),
        FlowDefectKind.duplicateStepId => GapItemDescription(
          GapDescriptionKind.flowStepIdDuplicated,
          {'stepId': stepId},
        ),
        FlowDefectKind.traversesUndeclared => GapItemDescription(
          GapDescriptionKind.traversesUndeclared,
          {'stepId': stepId, 'value': '${d.rawValue}'},
        ),
        FlowDefectKind.traversesKeyAbsent => GapItemDescription(
          GapDescriptionKind.traversesMissing,
          {'stepId': stepId},
        ),
      };
}

GapDescriptionKind _malformedKind(MalformedReason reason) => switch (reason) {
  MalformedReason.invalidShape => GapDescriptionKind.malformedRefInvalidShape,
  MalformedReason.patternMismatch =>
    GapDescriptionKind.malformedRefPatternMismatch,
  MalformedReason.selfReference => GapDescriptionKind.malformedRefSelfReference,
};

/// EVT-CORPUS-003 型別化原因碼 → 項目說明識別名（與七個 `gapParse*` key
/// 一對一；`unreadable` 依子原因分三個）。
GapDescriptionKind _carrierKind(CarrierParseFailureGap gap) {
  if (gap.failureReason == CarrierParseFailureReason.unreadable &&
      gap.unreadableReason == null) {
    // 一致性 assert 已在 gap 建構時擋下；release 下退回編碼說明並記 warning。
    developer.log(
      // i18n-exempt: 開發者診斷 log
      'projection: unreadable gap without sub-reason path=${gap.path}',
      name: _tag,
      level: 900,
    );
  }
  return _carrierKindOf(gap);
}

GapDescriptionKind _carrierKindOf(
  CarrierParseFailureGap gap,
) => switch (gap.failureReason) {
  CarrierParseFailureReason.noFrontmatter =>
    GapDescriptionKind.parseNoFrontmatter,
  CarrierParseFailureReason.frontmatterUnclosed =>
    GapDescriptionKind.parseFrontmatterUnclosed,
  CarrierParseFailureReason.frontmatterNotMap =>
    GapDescriptionKind.parseFrontmatterNotMap,
  CarrierParseFailureReason.yamlInvalid => GapDescriptionKind.parseYamlInvalid,
  CarrierParseFailureReason.unreadable => switch (gap.unreadableReason) {
    UnreadableReason.permission => GapDescriptionKind.parseUnreadablePermission,
    UnreadableReason.fileDeleted => GapDescriptionKind.parseUnreadableMissing,
    UnreadableReason.encoding => GapDescriptionKind.parseUnreadableEncoding,
    null => GapDescriptionKind.parseUnreadableEncoding,
  },
};
