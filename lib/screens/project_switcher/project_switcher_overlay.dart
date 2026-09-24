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
import '../domain_view/gate_detection_notifier.dart';
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
  final workspaceState = ref.watch(currentWorkspaceStateProvider);
  final currentPath =
      workspaceState is WorkspaceReady ? workspaceState.path : null;
  final hasItems = projects.isNotEmpty;

  return SwitcherOverlay(
    items: [
      for (var i = 0; i < projects.length; i++)
        _buildRecentProjectItem(
          context: context,
          l10n: l10n,
          ref: ref,
          project: projects[i],
          index: i,
          isCurrent: projects[i].path == currentPath,
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
  required BuildContext context,
  required AppLocalizations l10n,
  required WidgetRef ref,
  required RecentProject project,
  required int index,
  required bool isCurrent,
}) {
  // 節點數／票數摘要與健康徽章計數來源為真實 domain 掃描結果，0.1 尚未
  // 接線（SPEC-001 §7 註記：「計數來源... 不在本輪範圍」）；可用性探測
  // （SPEC-003 §3.7〈生命週期〉展開時逐項探測）亦非本票範圍——本票只把
  // 標籤與清單資料來源改為 [WorkspaceRepository] 持久化資料，故本票一律
  // `enabled: true`、不渲染健康徽章（`0.2.1-W1-003`）。
  return RecentProjectItem(
    name: folderNameOf(project.path),
    summary: l10n.projectSummaryLabel(0, 0),
    enabled: true,
    isCurrent: isCurrent,
    reason: null,
    health: null,
    onTap: () => _selectProject(context, ref, project),
    testKey: Key('card-switcher-recent-$index'),
  );
}

/// 點擊最近專案項（SPEC-003 §3.7 最近專案項列）：與「選擇其他資料夾」
/// 選定後走同一段載入路徑（[WorkspaceRepository.openPath] 共用
/// `_persistAndInspect`，本函式共用 [_handleChooseFolderResult]），差別
/// 只在路徑來源不經系統選擇器（`0.2.1-W1-054`，修復先前只改標籤、不載入
/// 的缺口）。
Future<void> _selectProject(
  BuildContext context,
  WidgetRef ref,
  RecentProject project,
) async {
  final repository = ref.read(workspaceRepositoryProvider);
  final result = await repository.openPath(project.path);
  if (!context.mounted) return;
  await _handleChooseFolderResult(context, ref, result);
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
  await _handleChooseFolderResult(context, ref, result);
}

/// [ChooseFolderResult] 四變體的共用回饋處理（SPEC-003 §3.7）。由
/// [_chooseFolder]（選擇其他資料夾）與 [_selectProject]（點擊最近專案項）
/// 共用，避免同一組分支重複兩份（`0.2.1-W1-054`）。
Future<void> _handleChooseFolderResult(
  BuildContext context,
  WidgetRef ref,
  ChooseFolderResult result,
) async {
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
      await _handleChosenState(context, ref, l10n, state);
    case ChooseFolderNotRemembered(:final state):
      await _handleChosenState(context, ref, l10n, state);
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: l10n.workspaceNotRemembered,
        level: AttentionLevel.discardable,
        origin: AppSnackBarOrigin.userInitiated,
      );
  }
}

/// 依 [state]（[ChooseFolderSelected] / [ChooseFolderNotRemembered] 共用的
/// 內層狀態）決定浮層是否收合：可用即重置降級／推定旗標、執行 gate 偵測
/// 並收合（`0.2.0-W1-042`），不可用則維持展開並提示原因（SPEC-003 §3.7
/// 「選擇其他（選定資料夾不可讀或不存在）」列）。
Future<void> _handleChosenState(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  WorkspaceState state,
) async {
  switch (state) {
    case WorkspaceReady(:final path):
      ref.read(currentWorkspaceStateProvider.notifier).state = state;
      ref.read(degradedSchemaProvider.notifier).state = false;
      ref.read(degradedSchemaVersionsProvider.notifier).state = null;
      ref.read(inferredVersionProvider.notifier).state = null;
      await ref.read(gateDetectionNotifierProvider.notifier).detect(path);
      await _persistRecentProjectSelection(ref, path);
      if (!context.mounted) return;
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

/// 成功載入後寫入最近專案清單（SPEC-005 §2.4「寫入時機：成功載入後」；
/// SPEC-003 §3.7〈互動反應〉「成功載入後該項移至頂端」）。寫入失敗
/// （`addRecentProject` 回 `false`）不影響本次載入結果，失敗原因已由
/// repository 內部記錄，此處不重試、不改變浮層或畫面狀態。
Future<void> _persistRecentProjectSelection(WidgetRef ref, String path) async {
  final repository = ref.read(workspaceRepositoryProvider);
  final success = await repository.addRecentProject(path);
  if (!success) return;
  final updated = await repository.loadRecentProjects();
  ref.read(recentProjectsProvider.notifier).state = updated;
}
