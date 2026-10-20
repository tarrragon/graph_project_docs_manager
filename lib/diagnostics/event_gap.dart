/// 需求：[SPEC-003 §3.5〈孤立事件判準〉〈事件宣告與 flow 不符判準〉]
/// Diagnostics 偵測事件類破洞（`orphan-event`、`event-declaration-mismatch`）。
///
/// 輸入取 Graph 公開面（flow 子圖已正規化的 `emitsNames`／`consumesNames`／
/// `traversesResolution`）與 corpus 的 EVT `RawNode.frontmatter`
/// （`producers`／`consumers`／`category` 不在 `LightNode` 上）；Diagnostics
/// 不直讀檔案。結果同時供破洞報告投影與 UC Flow 孤立事件標記共用，後者以
/// EVT id 查詢（[EventGapReport.orphanOf]）。負載不含在地化字串。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_key.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// EVT 節點的型別表節點型別名。
const eventTypeName = 'EVT';

/// 本專案本地保留字：畫面層（SPEC-003 §3.5〈`presentation` 本地保留字〉）。
const presentationReservedWord = 'presentation';

const _domainEventCategory = 'domain_event';

/// 孤立事件的形態。
enum OrphanEventShape { emittedNotConsumed, consumedNotEmitted }

/// 宣告不符的方向（EVT 宣告欄位）。
enum EventDeclarationDirection { consumers, producers }

/// 一筆孤立事件（每個符合的 EVT 一項）。
class OrphanEventGap {
  OrphanEventGap({
    required this.evtId,
    required this.shape,
    required List<String> ucIds,
  }) : ucIds = List.unmodifiable(ucIds);

  final String evtId;
  final OrphanEventShape shape;

  /// 引用該 EVT 的 UC id，已排序、去重；無引用時為空。
  final List<String> ucIds;
}

/// 一筆宣告不符（每個未對應的宣告 domain 一項）。
class EventDeclarationMismatchGap {
  EventDeclarationMismatchGap({
    required this.evtId,
    required this.direction,
    required this.domain,
    required List<String> ucIds,
  }) : ucIds = List.unmodifiable(ucIds);

  final String evtId;
  final EventDeclarationDirection direction;

  /// 未對應的宣告值原字面（含 `presentation` 與未宣告值）。
  final String domain;
  final List<String> ucIds;
}

/// 一輪事件類破洞偵測的項目集合，附 EVT id 查詢。
class EventGapReport {
  EventGapReport({
    required List<OrphanEventGap> orphanEvents,
    required List<EventDeclarationMismatchGap> mismatches,
  }) : orphanEvents = List.unmodifiable(orphanEvents),
       mismatches = List.unmodifiable(mismatches),
       _orphanById = {for (final o in orphanEvents) o.evtId: o};

  const EventGapReport.empty()
    : orphanEvents = const [],
      mismatches = const [],
      _orphanById = const {};

  /// 依 EVT id 排序。
  final List<OrphanEventGap> orphanEvents;

  /// 依 EVT id、方向（consumers 先）、domain 排序。
  final List<EventDeclarationMismatchGap> mismatches;
  final Map<String, OrphanEventGap> _orphanById;

  OrphanEventGap? orphanOf(String evtId) => _orphanById[evtId];

  bool isOrphan(String evtId) => _orphanById.containsKey(evtId);

  List<EventDeclarationMismatchGap> mismatchesOf(String evtId) => [
    for (final m in mismatches)
      if (m.evtId == evtId) m,
  ];
}

/// 偵測結果（sealed）：建圖可用為 [EventGapsDetected]，不可用為
/// [EventGapsUndetermined]（零筆，E2 守衛）。[report] 兩種結局皆可讀。
sealed class EventGapDetection {
  const EventGapDetection();
  EventGapReport get report;
}

class EventGapsDetected extends EventGapDetection {
  const EventGapsDetected(this.report);

  @override
  final EventGapReport report;
}

/// 建圖不可用：無法判定，零筆。
class EventGapsUndetermined extends EventGapDetection {
  const EventGapsUndetermined(this.reason);

  final EdgeTypeUnavailableReason reason;

  @override
  EventGapReport get report => const EventGapReport.empty();
}

/// 需求：[SPEC-003 §3.5] 由建圖結果與 EVT 節點偵測事件類破洞。
///
/// [rawNodes] 取 `typeName == 'EVT'` 且 `id` 為非空字串者（同 id 先出現者勝）；
/// 其餘略過。
EventGapDetection detectEventGaps({
  required GraphBuildResult graph,
  required Iterable<RawNode> rawNodes,
}) => switch (graph) {
  GraphBuildUnavailable(:final reason) => EventGapsUndetermined(reason),
  GraphBuildAvailable(:final event) => EventGapsDetected(
    _detect(_FlowIndex(event.flowSubgraphs.values), _eventsOf(rawNodes)),
  ),
};

Map<String, Map<String, dynamic>> _eventsOf(Iterable<RawNode> rawNodes) {
  final result = <String, Map<String, dynamic>>{};
  for (final n in rawNodes) {
    final id = n.frontmatter['id'];
    if (n.typeName != eventTypeName || id is! String || id.isEmpty) continue;
    result.putIfAbsent(id, () => n.frontmatter);
  }
  return result;
}

EventGapReport _detect(
  _FlowIndex flow,
  Map<String, Map<String, dynamic>> events,
) {
  final ids = events.keys.toList()..sort();
  final orphans = <OrphanEventGap>[];
  final mismatches = <EventDeclarationMismatchGap>[];
  for (final id in ids) {
    final fm = events[id]!;
    final orphan = _orphanOf(id, fm, flow);
    if (orphan != null) orphans.add(orphan);
    mismatches.addAll(_mismatchesOf(id, fm, flow));
  }
  return EventGapReport(orphanEvents: orphans, mismatches: mismatches);
}

/// 孤立事件：形態兩條件皆須成立，且只對 `category: domain_event` 生效。
OrphanEventGap? _orphanOf(String id, Map<String, dynamic> fm, _FlowIndex flow) {
  if (fm['category'] != _domainEventCategory) return null;
  final emitted = flow.emitters(id).isNotEmpty;
  final consumed = flow.consumers(id).isNotEmpty;
  final OrphanEventShape shape;
  if (emitted && !consumed && flowKeysOf(fm['consumers']).isEmpty) {
    shape = OrphanEventShape.emittedNotConsumed;
  } else if (consumed && !emitted && flowKeysOf(fm['producers']).isEmpty) {
    shape = OrphanEventShape.consumedNotEmitted;
  } else {
    return null;
  }
  return OrphanEventGap(evtId: id, shape: shape, ucIds: flow.ucIdsOf(id));
}

List<EventDeclarationMismatchGap> _mismatchesOf(
  String id,
  Map<String, dynamic> fm,
  _FlowIndex flow,
) => [
  for (final dir in EventDeclarationDirection.values)
    for (final domain in _declaredDomains(fm, dir))
      if (!_isMatched(id, dir, domain, flow))
        EventDeclarationMismatchGap(
          evtId: id,
          direction: dir,
          domain: domain,
          ucIds: flow.ucIdsOf(id),
        ),
];

/// 宣告值去重並排序（精確字面，不做大小寫轉換）。
List<String> _declaredDomains(
  Map<String, dynamic> fm,
  EventDeclarationDirection dir,
) => (flowKeysOf(fm[dir.name]).toSet().toList())..sort();

bool _isMatched(
  String id,
  EventDeclarationDirection dir,
  String domain,
  _FlowIndex flow,
) {
  final isConsumers = dir == EventDeclarationDirection.consumers;
  final steps = isConsumers ? flow.consumers(id) : flow.emitters(id);
  if (domain == presentationReservedWord) {
    // producers 的 presentation 與未宣告值同視為未對應。
    return isConsumers && steps.any(_hasEmptyTraverses);
  }
  return steps.any(
    (s) => s.traversesResolution.resolved.any((r) => r.name == domain),
  );
}

/// `traverses == []`：鍵存在且無任何值（含未宣告值）。
bool _hasEmptyTraverses(FlowStepNode step) {
  final t = step.traversesResolution;
  return !t.keyAbsent && t.resolved.isEmpty && t.undeclared.isEmpty;
}

/// 全專案 flow 步驟對 EVT 的發出／消費索引。
class _FlowIndex {
  _FlowIndex(Iterable<FlowSubgraph> subgraphs) {
    for (final sg in subgraphs) {
      for (final step in sg.steps) {
        for (final e in step.emitsNames) {
          _add(_emitters, e, step, sg.ucId);
        }
        for (final e in step.consumesNames) {
          _add(_consumers, e, step, sg.ucId);
        }
      }
    }
  }

  final Map<String, List<FlowStepNode>> _emitters = {};
  final Map<String, List<FlowStepNode>> _consumers = {};
  final Map<String, Set<String>> _ucIds = {};

  void _add(
    Map<String, List<FlowStepNode>> side,
    String evtId,
    FlowStepNode step,
    String ucId,
  ) {
    side.putIfAbsent(evtId, () => []).add(step);
    _ucIds.putIfAbsent(evtId, () => {}).add(ucId);
  }

  List<FlowStepNode> emitters(String evtId) => _emitters[evtId] ?? const [];
  List<FlowStepNode> consumers(String evtId) => _consumers[evtId] ?? const [];

  /// 引用該 EVT（發出或消費）的 UC id，已排序。
  List<String> ucIdsOf(String evtId) =>
      (_ucIds[evtId] ?? const <String>{}).toList()..sort();
}
