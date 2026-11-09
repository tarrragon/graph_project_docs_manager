/// 變更記錄畫面（第七畫面；SPEC-001 §10、SPEC-003 §3.9）。
///
/// 八狀態依 [historyProvider] 的 [HistoryViewState] 與「專案未就緒」共用判斷
/// 切換。本畫面首次可見時才呼叫 `enter()`（FR-09 規則 1）；讀取中導覽離開不
/// 取消、回來沿用進行中的讀取。篩選列與事件列由 0.7.0-W1-012.12 承接，本檔
/// 只提供期間描述、清單容器與各狀態的退出路徑。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/degraded_schema.dart';
import '../../app/domain_view_providers.dart';
import '../../app/graph_status.dart';
import '../../app/history_providers.dart';
import '../../app/project_unready_view.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../../history/application/history_state.dart';
import '../../history/query/history_query.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/current_workspace_provider.dart';
import '../../workspace/workspace_types.dart';

/// 邊界日期未知時淺層標示的佔位（淺層 clone 必有邊界 commit，僅防禦用）。
const String _unknownBoundaryDate = '-';

/// 變更記錄畫面。
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  Object? _enteredKey;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final reason = ref.watch(projectUnreadyReasonProvider);
    final root = ref.watch(
      currentWorkspaceStateProvider.select(
        (s) => s is WorkspaceReady ? s.path : null,
      ),
    );
    _enterWhenVisible(state: state, isReady: reason == null && root != null);
    return _viewFor(state, reason: reason, hasWorkspace: root != null);
  }

  /// 需求：[SPEC-003 §3.9] 首次可見與再次可見才進入；讀取中、已取消與三種
  /// 降級狀態不因再次可見而重啟（出口由各狀態的動作承擔）。
  void _enterWhenVisible({
    required HistoryViewState state,
    required bool isReady,
  }) {
    final visible =
        ref.watch(selectedDestinationProvider) == AppDestination.history;
    final key = (
      ref.watch(currentWorkspaceStateProvider.select(_pathOf)),
      ref.watch(domainViewStateProvider).runtimeType,
      ref.watch(degradedSchemaProvider),
    );
    if (!visible || !isReady) {
      _enteredKey = null;
      return;
    }
    if (_enteredKey == key || !_canEnterFrom(state)) return;
    _enteredKey = key;
    Future.microtask(() {
      if (mounted) ref.read(historyProvider.notifier).enter();
    });
  }

  static String? _pathOf(WorkspaceState s) =>
      s is WorkspaceReady ? s.path : null;

  static bool _canEnterFrom(HistoryViewState state) =>
      state is HistoryIdle ||
      state is HistorySchemaBlocked ||
      state is HistoryLoaded;

  Widget _viewFor(
    HistoryViewState state, {
    required ProjectUnreadyReason? reason,
    required bool hasWorkspace,
  }) {
    final unready =
        reason ??
        switch (state) {
          HistorySchemaBlocked() => ProjectUnreadyReason.incompatible,
          HistoryIdle() when !hasWorkspace => ProjectUnreadyReason.notSelected,
          _ => null,
        };
    if (unready != null) {
      return ProjectUnreadyView(
        reason: unready,
        stateKey: const Key('state-history-project-unready'),
        actionKey: const Key('action-history-goto-domain'),
      );
    }
    return switch (state) {
      HistoryIdle() => const _LoadingView(processedCount: 0),
      HistoryLoading(:final processedCount) => _LoadingView(
        processedCount: processedCount,
      ),
      HistoryLoaded(:final snapshot) => _ResultView(snapshot: snapshot),
      HistoryNotGitRepo() => const _RecoverView(
        stateKey: 'state-history-not-git',
        actionKey: 'action-history-recheck',
        kind: _RecoverKind.notGit,
      ),
      HistoryGitNotFound() => const _RecoverView(
        stateKey: 'state-history-git-missing',
        actionKey: 'action-history-recheck',
        kind: _RecoverKind.gitMissing,
      ),
      HistoryFailed() => _FailedView(state: state),
      HistoryCancelled() => const _RecoverView(
        stateKey: 'state-history-cancelled',
        actionKey: 'action-history-reload',
        kind: _RecoverKind.cancelled,
      ),
      HistorySchemaBlocked() => const SizedBox.shrink(),
    };
  }
}

/// 讀取中：骨架 + 已處理 commit 數 + 取消；無百分比（SPEC-003 §2.6）。
class _LoadingView extends ConsumerWidget {
  const _LoadingView({required this.processedCount});

  final int processedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return LoadingState.skeleton(
      message: l10n.historyLoading,
      skeletonLayout: SkeletonLayout.sections,
      isCancelling: false,
      onCancel: () => ref.read(historyProvider.notifier).cancel(),
      testKey: const Key('state-history-loading'),
      cancelKey: const Key('action-history-cancel'),
      countText: l10n.historyLoadingProcessedCount(processedCount),
    );
  }
}

enum _RecoverKind { notGit, gitMissing, cancelled }

/// 非 git、找不到 git、已取消：單一訊息加一個重新開始的出口。
class _RecoverView extends ConsumerWidget {
  const _RecoverView({
    required this.stateKey,
    required this.actionKey,
    required this.kind,
  });

  final String stateKey;
  final String actionKey;
  final _RecoverKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      testKey: Key(stateKey),
      message: switch (kind) {
        _RecoverKind.notGit => l10n.historyNotGitMessage,
        _RecoverKind.gitMissing => l10n.historyGitMissingMessage,
        _RecoverKind.cancelled => l10n.historyCancelledMessage,
      },
      explanation: kind == _RecoverKind.gitMissing
          ? l10n.historyGitMissingExplanation
          : null,
      actions: [
        AppButton(
          label: kind == _RecoverKind.cancelled
              ? l10n.historyReloadAction
              : l10n.historyRecheckAction,
          testKey: Key(actionKey),
          onPressed: () => ref.read(historyProvider.notifier).refresh(),
        ),
      ],
    );
  }
}

/// 讀取失敗：訊息、stderr 摘要原文、重試。
class _FailedView extends ConsumerWidget {
  const _FailedView({required this.state});

  final HistoryFailed state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = state.stderrSummary.isEmpty
        ? state.reason.name
        : state.stderrSummary;
    return EmptyState(
      variant: EmptyStateVariant.page,
      testKey: const Key('state-history-load-failed'),
      message: l10n.historyLoadFailedMessage,
      explanation: l10n.historyLoadFailedDetail(summary),
      actions: [
        AppButton(
          label: l10n.retryAction,
          testKey: const Key('action-history-retry'),
          onPressed: () => ref.read(historyProvider.notifier).refresh(),
        ),
      ],
    );
  }
}

/// 已有掃描結果：正常或期間內無事件（含尚無 commit 變體）。
class _ResultView extends ConsumerWidget {
  const _ResultView({required this.snapshot});

  final HistoryScanSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = snapshot.query(clock: ref.watch(historyClockProvider));
    final choice = ref.watch(historyPeriodChoiceProvider);
    final events = snapshot.hasNoCommit
        ? const <HistoryEventView>[]
        : query.run(
            period: choice,
            includeTicketCreation: ref.watch(
              historyIncludeTicketCreationProvider,
            ),
          );
    final isEmpty = events.isEmpty;
    return Column(
      key: Key(isEmpty ? 'state-history-empty' : 'state-history-normal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.isShallow) _ShallowBadge(snapshot: snapshot),
        _HeaderRow(
          summary: snapshot.hasNoCommit
              ? null
              : l10n.historyPeriodSummary(
                  _periodLabel(l10n, query, choice),
                  events.length,
                ),
        ),
        Expanded(
          child: isEmpty
              ? _EmptyBody(hasNoCommit: snapshot.hasNoCommit)
              : const Panel.scrollable(
                  scrollKey: Key('scroll-history-events'),
                  children: <Widget>[],
                ),
        ),
      ],
    );
  }

  /// 期間描述由畫面層組字：預設期間有基準 tag 時為「自 tag 起」，否則為最近
  /// 30 天；不顯示 `HistoryPeriod.description`（中文字面，非 i18n）。
  String _periodLabel(
    AppLocalizations l10n,
    HistoryQuery query,
    PeriodChoice choice,
  ) => switch (choice) {
    PeriodChoice.allHistory => l10n.historyPeriodAllLabel,
    PeriodChoice.last30Days => l10n.historyPeriodRecent30Label,
    PeriodChoice.defaultPeriod => switch (query.defaultPeriod.baseTag) {
      final tag? => l10n.historyPeriodSinceTag(tag.name),
      null => l10n.historyPeriodRecent30Label,
    },
  };
}

/// 淺層 clone 標示：疊加旗標，不是狀態，不可點（SPEC-003 §3.9）。
class _ShallowBadge extends StatelessWidget {
  const _ShallowBadge({required this.snapshot});

  final HistoryScanSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = snapshot.shallowBoundaryDate;
    return Badge.tag(
      key: const Key('badge-history-shallow-clone'),
      label: l10n.historyShallowCloneBadge(
        date == null ? _unknownBoundaryDate : _formatDate(date),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 期間描述與重新整理。
class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: summary == null
              ? const SizedBox.shrink()
              : AppText.singleLine(
                  summary!,
                  key: const Key('text-history-period-summary'),
                ),
        ),
        AppButton(
          label: l10n.refreshAction,
          testKey: const Key('action-history-refresh'),
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.read(historyProvider.notifier).refresh(),
        ),
      ],
    );
  }
}

/// 期間內無事件；尚無 commit 變體不提供「顯示全部歷史」。
class _EmptyBody extends ConsumerWidget {
  const _EmptyBody({required this.hasNoCommit});

  final bool hasNoCommit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (hasNoCommit) {
      return EmptyState(
        variant: EmptyStateVariant.page,
        testKey: const Key('panel-history-empty'),
        message: l10n.historyNoCommitsMessage,
        pageActionsException:
            EmptyStatePageActionsException.actionsRelocatedToHeader,
      );
    }
    return EmptyState(
      variant: EmptyStateVariant.page,
      testKey: const Key('panel-history-empty'),
      message: l10n.historyEmptyMessage,
      actions: [
        AppButton(
          label: l10n.historyShowAllAction,
          testKey: const Key('action-history-show-all'),
          onPressed: () =>
              ref.read(historyPeriodChoiceProvider.notifier).state =
                  PeriodChoice.allHistory,
        ),
      ],
    );
  }
}
