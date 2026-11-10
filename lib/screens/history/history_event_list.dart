/// 變更記錄事件清單（SPEC-001 §10）：表頭七欄加一列一個邊事件。
///
/// 節點格（宣告端、對端為節點時）點擊跳至節點詳情並設 returnTo；
/// `domain_dependency` 的對端是 domain 名稱，以純文字呈現、不可點。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/history_providers.dart';
import '../../app/jump_targets.dart';
import '../../components/components.dart';
import '../../history/events/edge_event.dart';
import '../../history/query/history_query.dart';
import '../../l10n/app_localizations.dart';

/// commit 短 hash 位數。
const int _shortHashLength = 7;

/// 事件清單；篩選改變時以 key 重建捲動容器，使捲動位置歸零。
class HistoryEventList extends ConsumerWidget {
  const HistoryEventList({super.key, required this.events});

  final List<HistoryEventView> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filterKey = (
      ref.watch(historyPeriodChoiceProvider),
      ref.watch(historyIncludeTicketCreationProvider),
    );
    return Panel.scrollable(
      key: ValueKey(filterKey),
      scrollKey: const Key('scroll-history-events'),
      children: [
        _header(l10n),
        for (var i = 0; i < events.length; i++) _row(l10n, ref, i, events[i]),
      ],
    );
  }

  Widget _header(AppLocalizations l10n) => AppTableRow.header(
    columns: AppTableRow.historyEventColumns,
    cells: [
      TableColumnHeader.plain(label: l10n.columnChange),
      TableColumnHeader.plain(label: l10n.columnEdgeType),
      TableColumnHeader.plain(label: l10n.columnDeclarer),
      TableColumnHeader.plain(label: l10n.columnCounterpart),
      TableColumnHeader.plain(label: l10n.columnCommit),
      TableColumnHeader.plain(label: l10n.columnDate),
      TableColumnHeader.plain(label: l10n.columnAuthorMessage),
    ],
  );

  Widget _row(
    AppLocalizations l10n,
    WidgetRef ref,
    int index,
    HistoryEventView view,
  ) {
    final e = view.event;
    final added = e.type == EdgeEventType.added;
    final change = added ? l10n.historyEventAdded : l10n.historyEventRemoved;
    final hash = _shortHash(e.commitId);
    final date = formatHistoryDate(e.committedAtSeconds);
    return AppTableRow.historyEvent(
      change: Badge.event(
        label: change,
        tone: added ? BadgeTone.positive : BadgeTone.negative,
      ),
      edgeType: AppText.singleLine(
        e.key.edgeTypeName,
        variant: AppTextVariant.mono,
      ),
      declarer: _node(ref, index, 'declarer', e.key.from),
      counterpart: view.counterpartIsNode
          ? _node(ref, index, 'counterpart', e.key.to)
          : AppText.singleLine(e.key.to, variant: AppTextVariant.mono),
      commit: AppText.singleLine(hash, variant: AppTextVariant.mono),
      date: AppText.singleLine(date, variant: AppTextVariant.mono),
      authorMessage: AppText.singleLine(
        l10n.historyEventAuthorMessage(e.author, e.subject),
      ),
      semanticLabel: l10n.historyEventA11yLabel(
        change,
        e.key.edgeTypeName,
        e.key.from,
        e.key.to,
        hash,
        date,
        e.author,
        e.subject,
      ),
    );
  }

  RelationItem _node(WidgetRef ref, int index, String side, String id) =>
      RelationItem(
        id: id,
        testKey: Key('action-history-open-$index-$side'),
        onTap: () => jumpToNodeDetail(ref.read, id),
      );

  static String _shortHash(String id) =>
      id.length <= _shortHashLength ? id : id.substring(0, _shortHashLength);
}

/// UTC 日期 `yyyy-MM-dd`。
String formatHistoryDate(int epochSeconds) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * 1000,
    isUtc: true,
  );
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
