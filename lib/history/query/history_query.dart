// SPEC-008 FR-07：記憶體內篩選查詢，不重新掃描。
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/query/default_period.dart';

enum PeriodChoice { defaultPeriod, last30Days, allHistory }

/// `domain_dependency` 的值是 domain 名稱而非節點 ID（FR-07 規則 4）。
const String domainDependencyEdgeName = 'domain_dependency';

class HistoryEventView {
  const HistoryEventView({
    required this.event,
    required this.counterpartIsNode,
  });

  final EdgeEvent event;

  /// false 表示對端為 domain 名稱原值，畫面不可跳轉。
  final bool counterpartIsNode;
}

class HistoryQuery {
  HistoryQuery({
    required this.events,
    required this.mainline,
    required this.tags,
    required this.head,
    required this.clock,
  });

  /// 掃描完成結果的事件（主線由舊到新處理順序）。
  final List<EdgeEvent> events;

  /// `rev-list --first-parent` 輸出（由新到舊）。
  final List<String> mainline;
  final List<GitTagRef> tags;
  final String head;
  final DateTime Function() clock;

  HistoryPeriod get defaultPeriod => resolveDefaultPeriod(
    mainline: mainline,
    tags: tags,
    head: head,
    now: clock(),
  );

  /// 需求：[SPEC-008 FR-07 規則 2、3、5] 期間與「包含 ticket 建檔」篩選，
  /// 主線新到舊，同 commit 內沿用原事件順序（FR-04 規則 4）。
  List<HistoryEventView> run({
    PeriodChoice period = PeriodChoice.defaultPeriod,
    bool includeTicketCreation = false,
  }) {
    final window = _window(period);
    final order = {for (var i = 0; i < mainline.length; i++) mainline[i]: i};
    final kept = [
      for (var i = 0; i < events.length; i++)
        if (_passes(events[i], window, includeTicketCreation)) i,
    ];
    kept.sort((a, b) {
      final byCommit = _rank(
        order,
        events[a],
      ).compareTo(_rank(order, events[b]));
      return byCommit != 0 ? byCommit : a.compareTo(b);
    });
    return [for (final i in kept) _view(events[i])];
  }

  bool _passes(EdgeEvent e, HistoryPeriod? window, bool includeTicket) {
    if (e.isTicketCreation && !includeTicket) return false;
    return window?.containsCommit(e.commitId, e.committedAtSeconds) ?? true;
  }

  HistoryPeriod? _window(PeriodChoice period) => switch (period) {
    PeriodChoice.defaultPeriod => defaultPeriod,
    PeriodChoice.last30Days => recentPeriod(now: clock()),
    PeriodChoice.allHistory => null,
  };

  int _rank(Map<String, int> order, EdgeEvent e) =>
      order[e.commitId] ?? mainline.length;

  HistoryEventView _view(EdgeEvent e) => HistoryEventView(
    event: e,
    counterpartIsNode: e.key.edgeTypeName != domainDependencyEdgeName,
  );
}
