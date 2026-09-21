/// Ticket 清單的狀態注入點與純函式運算（SPEC-003 §設計約束「狀態注入而非
/// 等待真實解析」，同 `domain_view_providers.dart`／`trace_providers.dart`
/// 慣例）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ticket_list_fixtures.dart';
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

/// 目前畫面狀態；預設未載入（[TicketListFixtures.all] 的票數）。測試以
/// `overrideWith` 切換至其餘狀態，畫面直接渲染，不經真實載入或解析。
final ticketListStateProvider = StateProvider<TicketListState>(
  (ref) => TicketsUnloaded(count: TicketListFixtures.all.length),
);

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
      ..sort((a, b) => _compare(a, b, sortKey));
    list = state.sortOrder == TicketSortOrder.desc
        ? sorted.reversed.toList()
        : sorted;
  }

  return list;
}

int _compare(TicketFixtureItem a, TicketFixtureItem b, TicketSortKey key) {
  return switch (key) {
    TicketSortKey.id => _naturalCompare(a.id, b.id),
    TicketSortKey.title => a.title.compareTo(b.title),
    TicketSortKey.status => _indexCompare(a.status, b.status, statusValues),
    TicketSortKey.priority => _indexCompare(
      a.priority,
      b.priority,
      priorityLevels,
    ),
  };
}

/// ID 自然序（S8：以 `-`、`.` 分段，數字段依數值比）。
int _naturalCompare(String a, String b) {
  final segmentsA = a.split(RegExp(r'[-.]'));
  final segmentsB = b.split(RegExp(r'[-.]'));
  final length = segmentsA.length < segmentsB.length
      ? segmentsA.length
      : segmentsB.length;
  for (var i = 0; i < length; i++) {
    final numA = int.tryParse(segmentsA[i]);
    final numB = int.tryParse(segmentsB[i]);
    final cmp = (numA != null && numB != null)
        ? numA.compareTo(numB)
        : segmentsA[i].compareTo(segmentsB[i]);
    if (cmp != 0) return cmp;
  }
  return segmentsA.length.compareTo(segmentsB.length);
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
