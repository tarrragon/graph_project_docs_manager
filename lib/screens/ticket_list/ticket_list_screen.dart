/// Ticket 清單（SPEC-001 §4；SPEC-003 §3.4；SPEC-004 §3.6）。
///
/// 七個狀態列（含「含損壞」疊加態）依 [TicketListState] 切換；正常 ·
/// 列表／正常 · 主題共用 [TicketsReady]，實際子列由 [TicketsReady.mode]
/// 分派（[_ReadyListView] / [_ReadyTopicView]）。內容由
/// [TicketListFixtures] 供給（本票決策：假資料驅動，不串真實資料）。
/// 頁首模式切換（`SegmentedControl`）由 [TicketsHeaderTrailing] 承載，經
/// `lib/app/shell.dart` 接線至 `SplitRow.header` 右格（同
/// `DomainHeaderTrailing` 慣例，僅 `AppDestination.tickets` 一行條件式
/// trailing）。
///
/// 缺件：`blockedBy` 欄（SPEC-001 §4 現行版本票列欄位之一）在 SPEC-004
/// §3.6 `TicketListA` 契約中無對應 slot（`AppTableRow.ticket` 固定欄序為
/// ID／標題／狀態／優先／損壞標記，見 `app_table_row.dart`）；本票依
/// 元件現有契約實作（不含 blockedBy 欄渲染），資料保留於
/// [TicketFixtureItem.blockedBy]，見本票 NeedsContext，不在頁面層繞路
/// 自製欄位。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'ticket_list_fixtures.dart';
import 'ticket_list_providers.dart';
import 'ticket_list_state.dart';

/// Ticket 清單畫面。
class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketListStateProvider);
    return switch (state) {
      TicketsProjectUnready() => _ProjectUnreadyView(state: state),
      TicketsUnloaded() => _UnloadedView(state: state),
      TicketsLoading() => _LoadingView(state: state),
      TicketsEmpty() => const _EmptyView(),
      TicketsReady() => state.mode == TicketListMode.list
          ? _ReadyListView(state: state)
          : _ReadyTopicView(state: state),
    };
  }
}

/// 頁首右格（`lib/app/shell.dart` 接線，見檔頭說明）：僅 [TicketsReady]
/// 渲染 `SegmentedControl`，其餘狀態不渲染頁首模式切換。
class TicketsHeaderTrailing extends ConsumerWidget {
  const TicketsHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ticketListStateProvider);
    if (state is! TicketsReady) {
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
      selectedIndex: state.mode == TicketListMode.list ? 0 : 1,
      onChanged: (index) =>
          ref.read(ticketListStateProvider.notifier).state = state.copyWith(
            mode: index == 0 ? TicketListMode.list : TicketListMode.topic,
          ),
    );
  }
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 §4 共用定義）。
class _ProjectUnreadyView extends ConsumerWidget {
  const _ProjectUnreadyView({required this.state});

  final TicketsProjectUnready state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      testKey: const Key('state-tickets-project-unready'),
      message: switch (state.reason) {
        ProjectUnreadyReason.notSelected =>
          l10n.projectUnreadyReasonNotSelected,
        ProjectUnreadyReason.loading => l10n.projectUnreadyReasonLoading,
        ProjectUnreadyReason.incompatible =>
          l10n.projectUnreadyReasonIncompatible,
      },
      actions: [
        AppButton(
          label: l10n.gotoDomainViewAction,
          testKey: const Key('action-tickets-goto-domain'),
          onPressed: () =>
              navigateTo(ref.read, AppDestination.domain, NavIntent.jump),
        ),
      ],
    );
  }
}

/// 未載入：`LoadPrompt`；返回動作由頁面框架承載（元件檔頭說明），僅
/// `returnTo` 非 `null` 時渲染（SPEC-003 §2.3 規則 4）。
class _UnloadedView extends ConsumerWidget {
  const _UnloadedView({required this.state});

  final TicketsUnloaded state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final returnTo = ref.watch(returnToProvider);
    return Column(
      children: [
        Expanded(
          child: LoadPrompt(
            count: state.count,
            onStart: () => ref.read(ticketListStateProvider.notifier).state =
                TicketsLoading(total: state.count),
            testKey: const Key('state-tickets-unloaded'),
            startKey: const Key('action-tickets-start-load'),
          ),
        ),
        if (returnTo != null)
          ButtonRow(
            alignment: ButtonRowAlignment.end,
            children: [
              AppButton(
                label: l10n.backAction,
                variant: AppButtonVariant.secondary,
                onPressed: () => consumeReturnTo(ref.read),
                testKey: const Key('action-tickets-back'),
              ),
            ],
          ),
      ],
    );
  }
}

/// 載入中：`LoadingState.progressBar`（已解析筆數 + 取消）。
class _LoadingView extends ConsumerWidget {
  const _LoadingView({required this.state});

  final TicketsLoading state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = state.total == 0
        ? 0.0
        : state.processedCount / state.total;
    return LoadingState.progressBar(
      message: l10n.ticketsLoadingProgress(state.processedCount),
      progress: progress,
      isCancelling: state.isCancelling,
      onCancel: () => ref.read(ticketListStateProvider.notifier).state =
          TicketsUnloaded(count: state.total),
      testKey: const Key('state-tickets-loading'),
      cancelKey: const Key('action-tickets-cancel-load'),
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
          label: l10n.gotoTicketsListAction,
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
  const _ReadyListView({required this.state});

  final TicketsReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final visible = visibleListTickets(state);
    final corrupted = state.corruptedCount;

    void update(TicketsReady Function(TicketsReady) transform) {
      ref.read(ticketListStateProvider.notifier).state = transform(state);
    }

    SortOrder orderFor(TicketSortKey key) => state.sortKey == key
        ? _toComponentOrder(state.sortOrder)
        : SortOrder.none;

    void onSort(TicketSortKey key) => update((s) => _advanceSort(s, key));

    void onOpenTicket(String id) =>
        navigateTo(ref.read, AppDestination.nodeDetail, NavIntent.jump);

    void onCorruptedTap() =>
        navigateTo(ref.read, AppDestination.gaps, NavIntent.jump);

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
        const SizedBox.shrink(),
      ],
    );

    final rows = [
      for (final ticket in visible)
        _ticketRow(
          ticket,
          onOpenTicket: onOpenTicket,
          onCorruptedTap: onCorruptedTap,
        ),
    ];

    return Panel(
      key: const Key('state-tickets-list'),
      children: [
        Toolbar(
          search: SearchField(
            value: state.searchQuery,
            onChanged: (value) =>
                update((s) => s.copyWith(searchQuery: value)),
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
        Expanded(
          child: AppDataTable(
            variant: AppDataTableVariant.virtual,
            columns: AppTableRow.ticketColumns,
            header: header,
            rows: rows,
            scrollKey: const Key('scroll-tickets-list'),
          ),
        ),
        SplitRow.footer(
          leading: AppText(
            l10n.ticketsSummaryLabel(
              visible.isEmpty ? 0 : 1,
              visible.length,
              state.tickets.length,
            ),
          ),
          trailing: AppText(
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
  const _ReadyTopicView({required this.state});

  final TicketsReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    void onOpenTicket(String id) =>
        navigateTo(ref.read, AppDestination.nodeDetail, NavIntent.jump);

    void onCorruptedTap() =>
        navigateTo(ref.read, AppDestination.gaps, NavIntent.jump);

    return Panel.scrollable(
      key: const Key('state-tickets-topic'),
      scrollKey: const Key('scroll-tickets-topics'),
      children: [
        for (final group in groups)
          _TopicSection(
            group: group,
            isExpanded: state.expandedTopics.contains(
              group.topic ?? 'unassigned',
            ),
            onToggle: () => toggle(group.topic ?? 'unassigned'),
            onOpenTicket: onOpenTicket,
            onCorruptedTap: onCorruptedTap,
          ),
        AppText(
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
  });

  final TicketTopicGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String ticketId) onOpenTicket;
  final VoidCallback onCorruptedTap;

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
        primary: AppText(label),
        trailing: AppText(
          l10n.topicSectionSummary(group.tickets.length, priority),
          variant: AppTextVariant.caption,
        ),
      ),
      items: [
        for (final ticket in group.tickets)
          _ticketRow(
            ticket,
            onOpenTicket: onOpenTicket,
            onCorruptedTap: onCorruptedTap,
          ),
      ],
    );
  }
}

/// 票列（列表模式與主題模式共用）：欄序 ID／標題／狀態／優先／損壞標記
/// （SPEC-004 §3.2 `TicketListA` 票列，見檔頭「缺件」說明）。
AppTableRow _ticketRow(
  TicketFixtureItem ticket, {
  required void Function(String ticketId) onOpenTicket,
  required VoidCallback onCorruptedTap,
}) {
  const placeholder = '—'; // i18n-exempt: 解析失敗票欄位的資料態佔位符，非 UI 文案
  return AppTableRow.ticket(
    id: AppText(ticket.id, variant: AppTextVariant.mono),
    title: AppText(ticket.title),
    status: Badge.status(label: ticket.status ?? placeholder),
    priority: AppText(
      ticket.priority ?? placeholder,
      variant: AppTextVariant.caption,
    ),
    marker: ticket.corrupted
        ? IssueMarker.damagedDetail(
            onTap: onCorruptedTap,
            testKey: Key('badge-tickets-corrupted-${ticket.id}'),
          )
        : null,
    onTap: () => onOpenTicket(ticket.id),
    testKey: Key('card-tickets-${ticket.id}'),
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
    return state.copyWith(
      sortKey: () => null,
      sortOrder: TicketSortOrder.none,
    );
  }
  return state.copyWith(sortOrder: next);
}
