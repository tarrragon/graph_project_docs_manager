/// Ticket 清單的狀態注入點與純函式運算（SPEC-003 §設計約束「狀態注入而非
/// 等待真實解析」，同 `domain_view_providers.dart`／`trace_providers.dart`
/// 慣例）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../app/graph_status.dart';
import '../../app/jump_targets.dart';
import '../../app/scan_round.dart';
import '../../corpus/node_type_names.dart';
import '../../corpus/topic_files_reader.dart';
import '../../ticket_detail/ticket_detail.dart';
import '../../tokens/tokens.dart';
import 'ticket_list_state.dart';

/// 優先值序（框架 `PRIORITY_LEVELS` 序的固定字面對映，S8「優先依框架
/// `PRIORITY_LEVELS` 序，P0 在前為 asc；未知值排最後」）；同時作為篩選
/// 下拉的選項來源（`action-tickets-filter-priority`）。
const List<String> priorityLevels = ['P0', 'P1', 'P2', 'P3'];

/// 狀態值序（框架 ticket 生命週期序的固定字面對映，S8 同段）；同時作為
/// 篩選下拉的選項來源（`action-tickets-filter-status`）。
const List<String> statusValues = [
  'pending',
  'in_progress',
  'completed',
  'closed',
];

/// 缺席欄位的資料態佔位符（SPEC-001 §4〈票列欄位的取值來源〉）。
const String _absentPlaceholder = '—'; // i18n-exempt: 資料態佔位符，非 UI 文案

String? _stringOrNull(Object? value) => value is String ? value : null;

List<String> _blockedByOf(Object? value) => value is List
    ? [
        for (final e in value)
          if (e is String) e,
      ]
    : const [];

/// 需求：[SPEC-001 §4〈票列欄位的取值來源〉] 正常票各欄取 TicketDetail 的
/// frontmatter；標題缺席或非字串以佔位符頂替。
TicketFixtureItem ticketRowOf(
  Map<String, dynamic> frontmatter, {
  String? topic,
}) {
  return TicketFixtureItem(
    topic: topic,
    id: frontmatter['id'] as String,
    title: _stringOrNull(frontmatter['title']) ?? _absentPlaceholder,
    status: _stringOrNull(frontmatter['status']),
    priority: _stringOrNull(frontmatter['priority']),
    blockedBy: _blockedByOf(frontmatter['blockedBy']),
  );
}

TicketFixtureItem _corruptedRowOf(String path, Map<String, String> topics) {
  final fileName = path.split('/').last;
  final id = fileName.endsWith('.md')
      ? fileName.substring(0, fileName.length - 3)
      : fileName;
  return TicketFixtureItem(
    id: id,
    title: fileName,
    corrupted: true,
    topic: topics[id],
  );
}

/// 需求：[SPEC-001 §4〈Ticket 清單由掃描輪次衍生〉] 一輪的票列：正常票（該輪
/// TicketDetail 收錄者，依 rawNodes 序）+ 損壞票（EVT-CORPUS-003 歸屬型別為
/// Ticket 者）。重複 ID 查無 TicketDetail，不成列。
List<TicketFixtureItem> ticketRowsOfRound(ScanRoundResult round) {
  final detail = TicketDetail.fromRawNodes(round.scan.rawNodes);
  final topics = round.scan.topicFilesRead.ticketTopics;
  final seen = <String>{};
  final rows = <TicketFixtureItem>[];
  for (final node in round.scan.rawNodes) {
    final id = node.frontmatter['id'];
    if (node.typeName != ticketTypeName || id is! String) continue;
    final frontmatter = detail.findById(id);
    if (frontmatter != null && seen.add(id)) {
      rows.add(ticketRowOf(frontmatter, topic: topics[id]));
    }
  }
  for (final event in round.scan.parseFailureEvents) {
    if (event.nodeType == ticketTypeName) {
      rows.add(_corruptedRowOf(event.path, topics));
    }
  }
  return rows;
}

/// 由最後完成輪次與專案未就緒原因算出的基底狀態（尚未疊加搜尋、篩選等
/// 畫面操作）。
TicketListState ticketBaseStateOf(
  ProjectUnreadyReason? reason,
  ScanRoundResult? round,
) {
  if (reason != null) return TicketsProjectUnready(reason);
  if (round == null) {
    return const TicketsProjectUnready(ProjectUnreadyReason.loading);
  }
  final rows = ticketRowsOfRound(round);
  if (rows.isEmpty) return const TicketsEmpty();
  // 需求：[SPEC-001 §4] 僅指派檔不存在時提示；unreadable 交由破洞報告。
  final absent =
      round.scan.topicFilesRead.assignmentsStatus == TopicFileStatus.absent;
  return TicketsReady(tickets: rows, noTopicFilesNotice: absent);
}

/// 輪次或未就緒原因變動時同步畫面狀態：同一專案的新輪次只替換票列，保留
/// 模式、搜尋、篩選、排序（SPEC-003 §3.4〈生命週期〉）；切換專案則重置。
/// 以監聽回呼帶來的新值計算，不讀衍生 provider（其重算時機晚於回呼）。
void _syncWithRound(
  Ref ref, {
  required ProjectUnreadyReason? reason,
  required ScanRoundResult? round,
  required bool sameProject,
}) {
  final base = ticketBaseStateOf(reason, round);
  final notifier = ref.read(ticketListStateProvider.notifier);
  final current = notifier.state;
  if (sameProject && current is TicketsReady && base is TicketsReady) {
    notifier.state = current.copyWith(
      tickets: base.tickets,
      noTopicFilesNotice: base.noTopicFilesNotice,
    );
  } else {
    notifier.state = base;
    if (!sameProject) {
      ref.read(ticketSearchInputProvider.notifier).state = null;
    }
  }
  _applyTicketTarget(ref);
}

/// 目前畫面狀態：預設由最後完成輪次衍生（SPEC-001 §4）；搜尋、篩選、排序、
/// 模式等畫面操作直接寫入本 provider（含 [TicketSearchDebouncer]）。測試
/// 以 `overrideWith` 注入其餘狀態。
final NotifierProvider<StateHolder<TicketListState>, TicketListState>
ticketListStateProvider = stateHolderProvider<TicketListState>((ref) {
  ref.read(_ticketRoundSyncProvider);
  ref.read(ticketTargetSyncProvider);
  return ticketBaseStateOf(
    ref.read(projectUnreadyReasonProvider),
    ref.read(lastCompletedRoundProvider),
  );
});

/// 需求：[SPEC-003 §3.4] 消費跳轉意圖（`ticketListTargetProvider`）：清單為
/// [TicketsReady] 時併入 `targetTicketId` 並清空意圖；未就緒則保留，待狀態
/// 變動後再套用。測試覆寫狀態 provider 時可直接讀本 provider。
final ticketTargetSyncProvider = Provider<void>((ref) {
  ref.listen<String?>(ticketListTargetProvider, (_, _) {
    _applyTicketTarget(ref);
  });
  Future.microtask(() {
    if (ref.mounted) _applyTicketTarget(ref);
  });
});

/// 清單為 [TicketsReady] 且有待定位意圖時，併入 `targetTicketId` 並清空意圖。
void _applyTicketTarget(Ref ref) {
  final id = ref.read(ticketListTargetProvider);
  if (id == null) return;
  final notifier = ref.read(ticketListStateProvider.notifier);
  final current = notifier.state;
  if (current is! TicketsReady) return;
  notifier.state = current.copyWith(targetTicketId: () => id);
  ref.read(ticketListTargetProvider.notifier).state = null;
}

/// 輪次與未就緒原因的同步掛點；由 [ticketListStateProvider] 初始化時啟動
/// （獨立 provider：listener 回呼需回寫畫面狀態，不能在其建構函式內讀自己）。
final _ticketRoundSyncProvider = Provider<void>((ref) {
  ref.listen<ScanRoundResult?>(lastCompletedRoundProvider, (prev, next) {
    _syncWithRound(
      ref,
      reason: ref.read(projectUnreadyReasonProvider),
      round: next,
      sameProject:
          prev != null &&
          next != null &&
          prev.workspacePath == next.workspacePath,
    );
  });
  ref.listen<ProjectUnreadyReason?>(
    projectUnreadyReasonProvider,
    (prev, next) => _syncWithRound(
      ref,
      reason: next,
      round: ref.read(lastCompletedRoundProvider),
      sameProject: true,
    ),
  );
});

/// 搜尋輸入框的即時顯示值；`null` 代表尚未輸入，顯示值取
/// [TicketsReady.searchQuery]。過濾詞（`searchQuery`）才經防抖更新。
final ticketSearchInputProvider = stateHolderProvider<String?>((ref) => null);

/// 搜尋防抖服務（SPEC-003 §3.4；`0.6.0-W3-124`）：輸入值即時寫入
/// [ticketSearchInputProvider]，過濾詞延遲 [Motion.searchDebounce] 才寫入
/// [TicketsReady.searchQuery]；清空輸入不等防抖立即生效。
class TicketSearchDebouncer {
  TicketSearchDebouncer(this._ref);

  final Ref _ref;
  Timer? _timer;

  void onInput(String value) {
    _ref.read(ticketSearchInputProvider.notifier).state = value;
    _timer?.cancel();
    if (value.isEmpty) {
      _apply(value);
      return;
    }
    _timer = Timer(Motion.searchDebounce, () => _apply(value));
  }

  void _apply(String value) {
    final current = _ref.read(ticketListStateProvider);
    if (current is! TicketsReady) return;
    _ref.read(ticketListStateProvider.notifier).state = current.copyWith(
      searchQuery: value,
    );
  }

  void dispose() => _timer?.cancel();
}

final ticketSearchDebouncerProvider = Provider<TicketSearchDebouncer>((ref) {
  final debouncer = TicketSearchDebouncer(ref);
  ref.onDispose(debouncer.dispose);
  return debouncer;
});

/// [visibleListTickets] 的衍生值：只在搜尋詞、篩選、排序或票集變動時重算，
/// 其他 build 觸發沿用快取結果，不在 widget build 內排序或篩選。
final visibleListTicketsProvider = Provider<List<TicketFixtureItem>>((ref) {
  final fields = ref.watch(
    ticketListStateProvider.select(
      (s) => s is TicketsReady
          ? (
              tickets: s.tickets,
              searchQuery: s.searchQuery,
              statusFilter: s.statusFilter,
              priorityFilter: s.priorityFilter,
              sortKey: s.sortKey,
              sortOrder: s.sortOrder,
            )
          : null,
    ),
  );
  if (fields == null) return const [];
  return visibleListTickets(
    TicketsReady(
      tickets: fields.tickets,
      searchQuery: fields.searchQuery,
      statusFilter: fields.statusFilter,
      priorityFilter: fields.priorityFilter,
      sortKey: fields.sortKey,
      sortOrder: fields.sortOrder,
    ),
  );
});

/// 正常 · 列表的可見票（依搜尋詞、篩選、排序運算，S5：三者獨立）。
List<TicketFixtureItem> visibleListTickets(TicketsReady state) {
  var list = state.tickets;

  final query = state.searchQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    list = [
      for (final t in list)
        if (t.id.toLowerCase().contains(query) ||
            t.title.toLowerCase().contains(query))
          t,
    ];
  }

  final status = state.statusFilter;
  if (status != null) {
    list = [
      for (final t in list)
        if (t.status == status) t,
    ];
  }

  final priority = state.priorityFilter;
  if (priority != null) {
    list = [
      for (final t in list)
        if (t.priority == priority) t,
    ];
  }

  final sortKey = state.sortKey;
  if (sortKey != null && state.sortOrder != TicketSortOrder.none) {
    final sorted = List<TicketFixtureItem>.of(list)
      ..sort(_comparatorFor(list, sortKey));
    list = state.sortOrder == TicketSortOrder.desc
        ? sorted.reversed.toList()
        : sorted;
  }

  return list;
}

/// 排序比較器；id 鍵先一次性預切段（避免 O(n log n) 次比較各做兩次 regex split）。
int Function(TicketFixtureItem, TicketFixtureItem) _comparatorFor(
  List<TicketFixtureItem> list,
  TicketSortKey key,
) {
  return switch (key) {
    TicketSortKey.id => _idComparator(list),
    TicketSortKey.title => (a, b) => a.title.compareTo(b.title),
    TicketSortKey.status => (a, b) => _indexCompare(
      a.status,
      b.status,
      statusValues,
    ),
    TicketSortKey.priority => (a, b) => _indexCompare(
      a.priority,
      b.priority,
      priorityLevels,
    ),
  };
}

int Function(TicketFixtureItem, TicketFixtureItem) _idComparator(
  List<TicketFixtureItem> list,
) {
  final segments = <String, List<String>>{
    for (final t in list) t.id: t.id.split(RegExp(r'[-.]')),
  };
  return (a, b) => _naturalCompareSegments(segments[a.id]!, segments[b.id]!);
}

/// ID 自然序（S8：以 `-`、`.` 分段，數字段依數值比）。
int _naturalCompareSegments(List<String> a, List<String> b) {
  final length = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final numA = int.tryParse(a[i]);
    final numB = int.tryParse(b[i]);
    final cmp = (numA != null && numB != null)
        ? numA.compareTo(numB)
        : a[i].compareTo(b[i]);
    if (cmp != 0) return cmp;
  }
  return a.length.compareTo(b.length);
}

/// 依固定序清單比較；值不在序清單中（未知值）排最後（S8）。
int _indexCompare(String? a, String? b, List<String> order) {
  final indexA = a == null ? order.length : order.indexOf(a);
  final indexB = b == null ? order.length : order.indexOf(b);
  final rankA = indexA < 0 ? order.length : indexA;
  final rankB = indexB < 0 ? order.length : indexB;
  return rankA.compareTo(rankB);
}

/// 一個主題節：主題名（`null` 為未歸屬）+ 節內票清單。
class TicketTopicGroup {
  const TicketTopicGroup({required this.topic, required this.tickets});

  final String? topic;
  final List<TicketFixtureItem> tickets;
}

/// 主題節排序（SPEC-003 §3.4〈主題模式的排序與歸屬比照框架〉，S-09）：
/// 節序鍵為（最高優先級 asc、票數降冪），同值維持首次出現序；未歸屬節
/// 固定排最後（含未歸屬節，`dashedTop`）。主題模式一律呈現全部已載入票，
/// 不受搜尋詞與篩選作用（S6／R1）。
List<TicketTopicGroup> topicGroups(TicketsReady state) {
  final grouped = <String?, List<TicketFixtureItem>>{};
  final firstIndex = <String?, int>{};
  for (var i = 0; i < state.tickets.length; i++) {
    final ticket = state.tickets[i];
    grouped.putIfAbsent(ticket.topic, () => []).add(ticket);
    firstIndex.putIfAbsent(ticket.topic, () => i);
  }

  final named = <TicketTopicGroup>[
    for (final entry in grouped.entries)
      if (entry.key != null)
        TicketTopicGroup(topic: entry.key, tickets: entry.value),
  ];

  int topPriorityRank(TicketTopicGroup group) {
    var best = priorityLevels.length;
    for (final t in group.tickets) {
      final rank = t.priority == null
          ? priorityLevels.length
          : priorityLevels.indexOf(t.priority!);
      final resolved = rank < 0 ? priorityLevels.length : rank;
      if (resolved < best) best = resolved;
    }
    return best;
  }

  named.sort((a, b) {
    final rankCmp = topPriorityRank(a).compareTo(topPriorityRank(b));
    if (rankCmp != 0) return rankCmp;
    final countCmp = b.tickets.length.compareTo(a.tickets.length);
    if (countCmp != 0) return countCmp;
    return firstIndex[a.topic]!.compareTo(firstIndex[b.topic]!);
  });

  final unassigned = grouped[null];
  return [
    ...named,
    if (unassigned != null) TicketTopicGroup(topic: null, tickets: unassigned),
  ];
}

/// 主題節「最高優先級」的顯示字面（節首摘要 `topicSectionSummary` 用）；
/// 無票或全部票皆無優先值時回傳 `null`（不顯示）。
String? topGroupPriorityLabel(TicketTopicGroup group) {
  String? best;
  var bestRank = priorityLevels.length;
  for (final t in group.tickets) {
    final p = t.priority;
    if (p == null) continue;
    final rank = priorityLevels.indexOf(p);
    final resolved = rank < 0 ? priorityLevels.length : rank;
    if (resolved < bestRank) {
      bestRank = resolved;
      best = p;
    }
  }
  return best;
}
