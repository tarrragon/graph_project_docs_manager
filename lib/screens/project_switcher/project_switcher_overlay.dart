/// 專案切換浮層的組裝（SPEC-004 §3.6 §7 三列；SPEC-003 §3.7）。
///
/// 展開態（items 非空）與無最近專案態（items 為空）由同一個 [SwitcherOverlay]
/// 容器承載——元件本身依 items 是否為空決定渲染形態（SPEC-004 4.42
/// 「變體」）。收合態不經本檔：`switcherOpenProvider` 為 `false` 時呼叫端
/// 不應呼叫本函式，浮層 slot 直接傳 `null`（SPEC-004 4.42「收合態不是本
/// 容器的狀態」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/attention_level.dart';
import '../../app/degraded_schema.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../workspace/workspace_repository.dart';
import '../../workspace/workspace_types.dart';
import 'project_switcher_providers.dart';

/// [WorkspaceRepository] 的接縫；測試可覆寫以注入替身，避免碰觸真實檔案
/// 系統與平台面板（0.2.0-W1-019）。
final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(),
);

/// 組裝 [SwitcherOverlay]；呼叫端只在浮層展開時呼叫本函式。
SwitcherOverlay buildProjectSwitcherOverlay({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final l10n = AppLocalizations.of(context);
  final projects = ref.watch(recentProjectsProvider);
  final currentIndex = ref.watch(currentProjectIndexProvider);
  final hasItems = projects.isNotEmpty;

  return SwitcherOverlay(
    items: [
      for (var i = 0; i < projects.length; i++)
        _buildRecentProjectItem(
          l10n: l10n,
          ref: ref,
          project: projects[i],
          index: i,
          isCurrent: i == currentIndex,
        ),
    ],
    chooseOther: AppButton(
      label: hasItems
          ? l10n.switcherChooseOtherFolder
          : l10n.switcherChooseFolderPrompt,
      onPressed: () => _chooseFolder(context, ref),
      variant: AppButtonVariant.text,
      testKey: const Key('action-switcher-choose-folder'),
    ),
    onDismiss: () => _dismiss(ref),
    testKey: hasItems
        ? const Key('state-switcher-expanded')
        : const Key('state-switcher-no-recent'),
    scrollKey: const Key('scroll-switcher-recent'),
  );
}

RecentProjectItem _buildRecentProjectItem({
  required AppLocalizations l10n,
  required WidgetRef ref,
  required RecentProjectFixture project,
  required int index,
  required bool isCurrent,
}) {
  return RecentProjectItem(
    name: project.name,
    summary: l10n.projectSummaryLabel(project.nodeCount, project.ticketCount),
    enabled: project.enabled,
    isCurrent: isCurrent,
    reason: project.enabled
        ? null
        : l10n.projectUnavailableReasonLabel(l10n.probeTimeoutReason),
    health: project.healthIssueCount > 0
        ? Badge.health(
            key: Key('badge-switcher-health-$index'),
            count: project.healthIssueCount,
            semanticLabel: l10n.healthBadgeA11yLabel(project.healthIssueCount),
          )
        : null,
    onTap: () => _selectProject(ref, index),
    testKey: Key('card-switcher-recent-$index'),
  );
}

void _selectProject(WidgetRef ref, int index) {
  ref.read(currentProjectIndexProvider.notifier).state = index;
  ref.read(switcherOpenProvider.notifier).state = false;
  // 寫入端接線（0.1.0-W2-014）：切換專案重置降級旗標（SPEC-001 §1「切換
  // 專案時旗標重置」）。
  ref.read(degradedSchemaProvider.notifier).state = false;
  ref.read(degradedSchemaVersionsProvider.notifier).state = null;
}

void _dismiss(WidgetRef ref) {
  ref.read(switcherOpenProvider.notifier).state = false;
}

/// 「選擇其他」按鈕的處理（SPEC-003 §3.7）：呼叫 [WorkspaceRepository] 開啟
/// 系統資料夾選擇器，依 [ChooseFolderResult] 四變體回饋。
Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(workspaceRepositoryProvider);
  final result = await repository.chooseFolder();
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  switch (result) {
    case ChooseFolderCancelled():
      // 選擇器被取消：浮層維持展開，不寫回饋（SPEC-003 §3.7「選擇其他」列）。
      break;
    case ChooseFolderUnavailable():
      // reason 不外露：可能含平台例外字串，使用者只看到固定文案
      // （SPEC-003 §3.7「選擇其他（選擇器無法開啟）」列）。
      AppSnackBar.show(
        context,
        message: l10n.chooseFolderUnavailableMessage,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
    case ChooseFolderSelected(:final state):
      _handleChosenState(context, ref, l10n, state);
    case ChooseFolderNotRemembered(:final state):
      _handleChosenState(context, ref, l10n, state);
      AppSnackBar.show(
        context,
        message: l10n.workspaceNotRemembered,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
  }
}

/// 依 [state]（[ChooseFolderSelected] / [ChooseFolderNotRemembered] 共用的
/// 內層狀態）決定浮層是否收合：可用即切換專案並收合，不可用則維持展開並
/// 提示原因（SPEC-003 §3.7「選擇其他（選定資料夾不可讀或不存在）」列）。
void _handleChosenState(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  WorkspaceState state,
) {
  switch (state) {
    case WorkspaceReady():
      _dismiss(ref);
    case WorkspaceUnavailable(:final reason):
      AppSnackBar.show(
        context,
        message: l10n.workspaceUnavailable(reason),
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
    case WorkspaceUnset():
      // chooseFolder() 成功持久化後不應回到未選狀態；防禦性維持展開、
      // 不做動作（sealed class 窮盡分支，非預期路徑僅為編譯期保證）。
      break;
  }
}
