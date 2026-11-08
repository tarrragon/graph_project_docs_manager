/// Ticket 清單（SPEC-001 §4；SPEC-003 §3.4；SPEC-004 §3.6）。
///
/// 各狀態列（含「含損壞」疊加態）依 [TicketListState] 切換；正常 ·
/// 列表／正常 · 主題共用 [TicketsReady]，實際子列由 [TicketsReady.mode]
/// 分派（[_ReadyListView] / [_ReadyTopicView]）。內容取自最後完成的掃描輪次
/// （SPEC-001 §4〈Ticket 清單由掃描輪次衍生〉，`ticket_list_providers.dart`）。
/// 頁首模式切換（`SegmentedControl`）由 [TicketsHeaderTrailing] 承載，經
/// `lib/assembly/shell.dart` 接線至 `SplitRow.header` 右格（同
/// `DomainHeaderTrailing` 慣例，僅 `AppDestination.tickets` 一行條件式
/// trailing）。
///
/// `blockedBy` 欄（SPEC-001 §4 v1.9；SPEC-004 §3.6／4.35）已由
/// `AppTableRow.ticket` 補齊（欄序 ID／標題／狀態／優先／blockedBy／損壞
/// 標記，見 `app_table_row.dart`），本頁渲染 [TicketFixtureItem.blockedBy]。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/attention_level.dart';
import '../../app/jump_targets.dart';
import '../../app/project_unready_view.dart';
import '../../app/router.dart';
import '../../app/workspace_selection.dart' show projectGenerationProvider;
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../multi_value_separator.dart';
import 'ticket_list_providers.dart';
import 'ticket_list_state.dart';

/// Ticket 清單畫面。
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  /// 清單捲動 offset 由頁面層持有（SPEC-004 §2）；排序與切換專案時歸零，
  /// 切換導覽項（IndexedStack 不 dispose）時保留。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetOffset() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(projectGenerationProvider, (_, _) => _resetOffset());
    // 只訂閱用到的欄位：狀態種類、unready 原因、模式。
    final (kind, reason, mode) = ref.watch(
      ticketListStateProvider.select(
        (s) => (
          s.runtimeType,
          s is TicketsProjectUnready ? s.reason : null,
          s is TicketsReady ? s.mode : null,
        ),
      ),
    );
    return switch (kind) {
      const (TicketsProjectUnready) => ProjectUnreadyView(
        reason: reason!,
        stateKey: const Key('state-tickets-project-unready'),
        actionKey: const Key('action-tickets-goto-domain'),
      ),
      const (TicketsEmpty) => const _EmptyView(),
      _ =>
        mode == TicketListMode.list
            ? _ReadyListView(
                scrollController: _scrollController,
                onSorted: _resetOffset,
              )
            : const _ReadyTopicView(),
    };
  }
}

/// 頁首右格（`lib/assembly/shell.dart` 接線，見檔頭說明）：僅 [TicketsReady]
/// 渲染 `SegmentedControl`，其餘狀態不渲染頁首模式切換。
class TicketsHeaderTrailing extends ConsumerWidget {
  const TicketsHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      ticketListStateProvider.select((s) => s is TicketsReady ? s.mode : null),
    );
    if (mode == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return SegmentedControl(
      segments: [
        SegmentItem(
          label: l10n.modeListLabel,
          semanticLabel: l10n.ticketsSwitchToListAction,
          testKey: const Key('mode-tickets-list'),
        ),
        SegmentItem(
          label: l10n.modeTopicLabel,
          semanticLabel: l10n.ticketsSwitchToTopicAction,
          testKey: const Key('mode-tickets-topic'),
        ),
      ],
      selectedIndex: mode == TicketListMode.list ? 0 : 1,
      onChanged: (index) {
        final current = ref.read(ticketListStateProvider);
        if (current is! TicketsReady) return;
        ref.read(ticketListStateProvider.notifier).state = current.copyWith(
          mode: index == 0 ? TicketListMode.list : TicketListMode.topic,
        );
      },
    );
  }
}

/// 無 ticket：`EmptyState.page`。
class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.emptyTicketsMessage,
      testKey: const Key('state-tickets-empty'),
      actions: [
        AppButton(
          label: l10n.gotoGapsReportAction,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.gaps, NavIntent.jump),
          testKey: const Key('action-tickets-goto-gaps'),
        ),
      ],
    );
  }
}

/// 正常 · 列表（含損壞為其上的計算疊加，`corruptedCount > 0` 時
/// `Toolbar.marker` 與各損壞列的 `AppTableRow.ticket.marker` 皆渲染）。
class _ReadyListView extends ConsumerWidget {
  const _ReadyListView({
    required this.scrollController,
    required this.onSorted,
  });

  /// 頁面層持有的清單捲動 controller。
  final ScrollController scrollController;

  /// 排序後回呼（頁面層將 offset 歸零）。
  final VoidCallback onSorted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketListStateProvider);
    if (state is! TicketsReady) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final visible = visibleListTickets(state);
    final corrupted = state.corruptedCount;

    // 讀目前 provider 值而非閉包捕捉的 build 時 `state`——`AppSnackBar`
    // 的 `onAction`（復原）在較晚的一輪呼叫，若仍套用捕捉當下的舊
    // `state`，會把中途已寫入的 `targetFiltersAutoCleared: true` 覆寫回
    // 舊值，使一次性清除誤判為未清除而重新觸發（SPEC-003 §3.4〈帶目標
    // 跳入〉「復原」段）。
    void update(TicketsReady Function(TicketsReady) transform) {
      final current = ref.read(ticketListStateProvider);
      if (current is! TicketsReady) return;
      ref.read(ticketListStateProvider.notifier).state = transform(current);
    }

    SortOrder orderFor(TicketSortKey key) => state.sortKey == key
        ? _toComponentOrder(state.sortOrder)
        : SortOrder.none;

    void onSort(TicketSortKey key) {
      update((s) => _advanceSort(s, key));
      onSorted();
    }

    void onOpenTicket(String id) => jumpToNodeDetail(ref.read, id);

    void onCorruptedTap() =>
        navigateTo(ref.read, AppDestination.gaps, NavIntent.jump);

    // 帶目標跳入（SPEC-003 §3.4〈帶目標跳入〉）：目標存在於已載入票但被
    // 搜尋詞或篩選隱藏時，清除搜尋與篩選（`order` 不變）並顯示
    // `AppSnackBar.withAction`（`undoAction` 還原清除前的值，不撤銷定位）。
    // 目標僅因主題節收合而不可見的分支屬主題模式，不在本視圖範圍。
    final targetId = state.targetTicketId;
    if (targetId != null &&
        !state.targetFiltersAutoCleared &&
        state.tickets.any((t) => t.id == targetId) &&
        !visible.any((t) => t.id == targetId)) {
      final restoreSearch = state.searchQuery;
      final restoreStatus = state.statusFilter;
      final restorePriority = state.priorityFilter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(ticketSearchInputProvider.notifier).state = '';
        update(
          (s) => s.copyWith(
            searchQuery: '',
            statusFilter: () => null,
            priorityFilter: () => null,
            targetFiltersAutoCleared: true,
          ),
        );
        AppSnackBar.show(
          context,
          message: l10n.ticketsFiltersClearedSnackbarMessage,
          level: AttentionLevel.discardable,
          origin: AppSnackBarOrigin.userInitiated,
          variant: AppSnackBarVariant.withAction,
          actionLabel: l10n.undoAction,
          actionTestKey: const Key('undoAction'),
          onAction: () {
            ref.read(ticketSearchInputProvider.notifier).state = restoreSearch;
            update(
              (s) => s.copyWith(
                searchQuery: restoreSearch,
                statusFilter: () => restoreStatus,
                priorityFilter: () => restorePriority,
              ),
            );
          },
        );
      });
    }

    // 目標不在已載入清單（SPEC-003 §3.4〈帶目標跳入〉末列）：不捲動、不切
    // 模式、不清篩選，僅顯示 `ticketsTargetNotFoundMessage`（plain）；
    // `targetNotFoundNotified` 防重入，同一次進入只發送一次。
    if (targetId != null &&
        !state.targetNotFoundNotified &&
        !state.tickets.any((t) => t.id == targetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        update((s) => s.copyWith(targetNotFoundNotified: true));
        AppSnackBar.show(
          context,
          message: l10n.ticketsTargetNotFoundMessage,
          level: AttentionLevel.discardable,
          origin: AppSnackBarOrigin.userInitiated,
        );
      });
    }

    final header = AppTableRow.header(
      columns: AppTableRow.ticketColumns,
      cells: [
        TableColumnHeader.sortable(
          label: l10n.columnId,
          order: orderFor(TicketSortKey.id),
          onSort: () => onSort(TicketSortKey.id),
          testKey: const Key('action-tickets-sort-id'),
        ),
        TableColumnHeader.sortable(
          label: l10n.columnTitle,
          order: orderFor(TicketSortKey.title),
          onSort: () => onSort(TicketSortKey.title),
          testKey: const Key('action-tickets-sort-title'),
        ),
        TableColumnHeader.sortable(
          label: l10n.columnStatus,
          order: orderFor(TicketSortKey.status),
          onSort: () => onSort(TicketSortKey.status),
          testKey: const Key('action-tickets-sort-status'),
        ),
        TableColumnHeader.sortable(
          label: l10n.columnPriority,
          order: orderFor(TicketSortKey.priority),
          onSort: () => onSort(TicketSortKey.priority),
          testKey: const Key('action-tickets-sort-priority'),
        ),
        TableColumnHeader.plain(label: l10n.columnBlockedBy),
        const TableColumnHeader.blank(),
      ],
    );

    final rows = [
      for (final ticket in visible)
        _ticketRow(
          ticket,
          blockedBySeparator: multiValueSeparator(l10n),
          onOpenTicket: onOpenTicket,
          onCorruptedTap: onCorruptedTap,
          targetId: targetId,
        ),
    ];

    return Panel(
      key: const Key('state-tickets-list'),
      leading: [
        Toolbar(
          search: SearchField(
            value: ref.watch(ticketSearchInputProvider) ?? state.searchQuery,
            onChanged: ref.read(ticketSearchDebouncerProvider).onInput,
            testKey: const Key('input-tickets-search'),
          ),
          filters: [
            FilterDropdown(
              label: l10n.filterStatusLabel,
              options: [
                for (final value in statusValues)
                  FilterOption(value: value, label: value),
              ],
              selected: state.statusFilter,
              onChanged: (value) =>
                  update((s) => s.copyWith(statusFilter: () => value)),
              testKey: const Key('action-tickets-filter-status'),
              screen: 'tickets',
              kind: 'filter-status',
            ),
            FilterDropdown(
              label: l10n.filterPriorityLabel,
              options: [
                for (final value in priorityLevels)
                  FilterOption(value: value, label: value),
              ],
              selected: state.priorityFilter,
              onChanged: (value) =>
                  update((s) => s.copyWith(priorityFilter: () => value)),
              testKey: const Key('action-tickets-filter-priority'),
              screen: 'tickets',
              kind: 'filter-priority',
            ),
          ],
          marker: corrupted > 0
              ? IssueMarker.damagedDetail(
                  count: corrupted,
                  onTap: onCorruptedTap,
                  testKey: const Key('badge-tickets-corrupted'),
                )
              : null,
          testKey: const Key('toolbar-tickets-list'),
        ),
      ],
      fill: AppDataTable(
        variant: AppDataTableVariant.virtual,
        columns: AppTableRow.ticketColumns,
        header: header,
        rows: rows,
        scrollKey: const Key('scroll-tickets-list'),
        controller: scrollController,
      ),
      trailing: [
        SplitRow.footer(
          leading: AppText.singleLine(
            l10n.ticketsSummaryLabel(
              visible.isEmpty ? 0 : 1,
              visible.length,
              state.tickets.length,
            ),
          ),
          trailing: AppText.singleLine(
            l10n.ticketsVirtualScrollNote,
            variant: AppTextVariant.caption,
          ),
        ),
      ],
    );
  }
}

/// 正常 · 主題：`Panel.scrollable`[`Section.collapsible` × N（含未歸屬節，
/// `dashedTop`）, `AppText.caption`]。
class _ReadyTopicView extends ConsumerWidget {
  const _ReadyTopicView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketListStateProvider);
    if (state is! TicketsReady) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final groups = topicGroups(state);

    void toggle(String key) {
      final expanded = Set<String>.of(state.expandedTopics);
      if (!expanded.add(key)) {
        expanded.remove(key);
      }
      ref.read(ticketListStateProvider.notifier).state = state.copyWith(
        expandedTopics: expanded,
      );
    }

    void onOpenTicket(String id) => jumpToNodeDetail(ref.read, id);

    void onCorruptedTap() =>
        navigateTo(ref.read, AppDestination.gaps, NavIntent.jump);

    return Panel.scrollable(
      key: const Key('state-tickets-topic'),
      scrollKey: const Key('scroll-tickets-topics'),
      children: [
        if (state.noTopicFilesNotice)
          AppText.singleLine(
            l10n.ticketsNoTopicFilesNotice,
            variant: AppTextVariant.caption,
            key: const Key('text-tickets-no-topic-files'),
          ),
        for (final group in groups)
          _TopicSection(
            group: group,
            isExpanded: state.expandedTopics.contains(
              group.topic ?? 'unassigned',
            ),
            onToggle: () => toggle(group.topic ?? 'unassigned'),
            onOpenTicket: onOpenTicket,
            onCorruptedTap: onCorruptedTap,
            targetId: state.targetTicketId,
          ),
        AppText.singleLine(
          l10n.ticketsVirtualScrollNote,
          variant: AppTextVariant.caption,
        ),
      ],
    );
  }
}

/// 單一主題節：節首（展開器 + 名稱 + 摘要）+ 節內票列。
class _TopicSection extends StatelessWidget {
  const _TopicSection({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenTicket,
    required this.onCorruptedTap,
    this.targetId,
  });

  final TicketTopicGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String ticketId) onOpenTicket;
  final VoidCallback onCorruptedTap;
  final String? targetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = group.topic ?? 'unassigned';
    final label = group.topic ?? l10n.ticketsUnassignedSection;
    final priority =
        topGroupPriorityLabel(group) ?? '—'; // i18n-exempt: 無優先值的資料態佔位符，非 UI 文案
    return Section(
      variant: SectionVariant.collapsible,
      isExpanded: isExpanded,
      dashedTop: group.topic == null,
      testKey: Key('state-tickets-topic-section-$key'),
      header: ListRow.sectionHeader(
        leading: ExpanderIcon(
          isExpanded: isExpanded,
          testKey: Key(
            group.topic == null
                ? 'expander-tickets-unassigned'
                : 'expander-tickets-topic-$key',
          ),
          onToggle: onToggle,
        ),
        primary: AppText.singleLine(label),
        trailing: AppText.singleLine(
          l10n.topicSectionSummary(group.tickets.length, priority),
          variant: AppTextVariant.caption,
        ),
      ),
      items: [
        for (final ticket in group.tickets)
          _ticketRow(
            ticket,
            blockedBySeparator: multiValueSeparator(l10n),
            onOpenTicket: onOpenTicket,
            onCorruptedTap: onCorruptedTap,
            targetId: targetId,
          ),
      ],
    );
  }
}

/// 票列（列表模式與主題模式共用）：欄序 ID／標題／狀態／優先／blockedBy／
/// 損壞標記（SPEC-004 §3.2 `TicketListA` 票列；blockedBy 值為被阻擋的
/// ticket ID 依語系以「、」（zh）或「, 」（en）串接，無則「—」，SPEC-001 §4）。[targetId] 與
/// `ticket.id` 相同時渲染定位高亮（SPEC-003 §3.4〈帶目標跳入〉，
/// SPEC-004 §4.0.10 場景 d，`0.1.0-W1-080`）。
AppTableRow _ticketRow(
  TicketFixtureItem ticket, {
  required String blockedBySeparator,
  required void Function(String ticketId) onOpenTicket,
  required VoidCallback onCorruptedTap,
  String? targetId,
}) {
  const placeholder = '—'; // i18n-exempt: 解析失敗票欄位的資料態佔位符，非 UI 文案
  return AppTableRow.ticket(
    id: AppText.singleLine(ticket.id, variant: AppTextVariant.mono),
    title: AppText.singleLine(ticket.title),
    status: Badge.status(label: ticket.status ?? placeholder),
    priority: AppText.singleLine(
      ticket.priority ?? placeholder,
      variant: AppTextVariant.caption,
    ),
    blockedBy: AppText.singleLine(
      ticket.blockedBy.isEmpty
          ? placeholder
          : ticket.blockedBy.join(blockedBySeparator),
      variant: AppTextVariant.mono,
    ),
    marker: ticket.corrupted
        ? IssueMarker.damagedDetail(
            onTap: onCorruptedTap,
            testKey: Key('badge-tickets-corrupted-${ticket.id}'),
          )
        : null,
    onTap: () => onOpenTicket(ticket.id),
    testKey: Key('card-tickets-${ticket.id}'),
    isLocated: targetId != null && targetId == ticket.id,
  );
}

SortOrder _toComponentOrder(TicketSortOrder order) => switch (order) {
  TicketSortOrder.none => SortOrder.none,
  TicketSortOrder.asc => SortOrder.asc,
  TicketSortOrder.desc => SortOrder.desc,
};

/// 排序欄首推進（SPEC-003 §3.4 S1–S2）：換欄一律自 `asc` 起算；同欄三態
/// 循環 `none → asc → desc → none`。
TicketsReady _advanceSort(TicketsReady state, TicketSortKey key) {
  if (state.sortKey != key) {
    return state.copyWith(sortKey: () => key, sortOrder: TicketSortOrder.asc);
  }
  final next = switch (state.sortOrder) {
    TicketSortOrder.none => TicketSortOrder.asc,
    TicketSortOrder.asc => TicketSortOrder.desc,
    TicketSortOrder.desc => TicketSortOrder.none,
  };
  if (next == TicketSortOrder.none) {
    return state.copyWith(sortKey: () => null, sortOrder: TicketSortOrder.none);
  }
  return state.copyWith(sortOrder: next);
}
