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

import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'project_switcher_providers.dart';

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
      onPressed: () => _dismiss(ref),
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
}

void _dismiss(WidgetRef ref) {
  ref.read(switcherOpenProvider.notifier).state = false;
}
