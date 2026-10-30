/// 選定工作區的共用成功路徑（0.5.0-W1-206.1）。
///
/// 專案切換浮層與 Domain 視圖的選擇資料夾按鈕共用同一份；浮層收合與失敗
/// 回饋載體不在本檔，由呼叫端處理。
///
/// 副作用由 [WorkspaceSelectionNotifier] 以自身 `ref` 執行（隨
/// ProviderContainer 存活）：呼叫端 widget 在 gate 偵測期間可能因狀態轉換
/// 而卸載（Domain 視圖的 `_UnsetView`），不能讓 await 之後的步驟依賴
/// 呼叫端的 `WidgetRef`（0.5.0-W1-206.2）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gate_detection_notifier.dart';
import '../workspace/workspace_repository.dart'
    show workspaceRepositoryProvider;
import 'project_switcher_providers.dart';
import '../workspace/current_workspace_provider.dart';
import '../workspace/workspace_types.dart';
import 'degraded_schema.dart';
import 'scan_round.dart';

/// 專案世代（SPEC-003 §2.8 切換專案列、SPEC-004 §4.26）：每次進入
/// [WorkspaceSelectionNotifier.select] 即遞增，含同路徑重選。殼層監聽此值，
/// 於專案改變當下清除顯示中的暫態提示。選定失敗路徑不經 select()，故不遞增。
final projectGenerationProvider = StateProvider<int>((ref) => 0);

/// 選定工作區流程的執行者；不持有狀態。
class WorkspaceSelectionNotifier extends Notifier<void> {
  @override
  void build() {}

  /// 套用 [WorkspaceReady]：設定目前工作區、重置降級與推定旗標、丟棄舊掃描
  /// 輪次、執行 gate 偵測、寫入最近專案清單（0.2.0-W1-042）。
  Future<void> select(WorkspaceReady state) async {
    // 世代遞增必須是第一行、位於任何 await 之前（殼層清除先於後續提示）。
    ref.read(projectGenerationProvider.notifier).state++;
    ref.read(currentWorkspaceStateProvider.notifier).state = state;
    ref.read(degradedSchemaProvider.notifier).state = false;
    ref.read(degradedSchemaVersionsProvider.notifier).state = null;
    ref.read(inferredVersionProvider.notifier).state = null;
    // 同路徑重選時輪次監聽不會 discard；gate 即將重讀 JSON，舊輪次（含舊降級
    // 狀態）必須在此丟棄。僅限使用者主動選專案，缺口報告再次可見不經此處。
    ref.read(scanRoundProvider.notifier).discard('project-reselected');
    await ref.read(gateDetectionNotifierProvider.notifier).detect(state.path);
    await _persistRecentProjectSelection(state.path);
  }

  /// 成功載入後寫入最近專案清單（SPEC-005 §2.4「寫入時機：成功載入後」）。
  /// 寫入失敗不影響本次載入結果，失敗原因已由 repository 內部記錄。
  Future<void> _persistRecentProjectSelection(String path) async {
    final repository = ref.read(workspaceRepositoryProvider);
    final success = await repository.addRecentProject(path);
    if (!success) return;
    final updated = await repository.loadRecentProjects();
    ref.read(recentProjectsProvider.notifier).state = updated;
  }
}

final workspaceSelectionProvider =
    NotifierProvider<WorkspaceSelectionNotifier, void>(
      WorkspaceSelectionNotifier.new,
    );

/// 薄包裝：在任何 await 之前取得 notifier，其後不再使用 [ref]。
Future<void> selectWorkspace(WidgetRef ref, WorkspaceReady state) {
  final notifier = ref.read(workspaceSelectionProvider.notifier);
  return notifier.select(state);
}
