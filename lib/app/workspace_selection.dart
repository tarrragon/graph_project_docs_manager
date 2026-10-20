/// 選定工作區的共用成功路徑（0.5.0-W1-206.1）。
///
/// 專案切換浮層與 Domain 視圖的選擇資料夾按鈕共用同一份；浮層收合與失敗
/// 回饋載體不在本檔，由呼叫端處理。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/domain_view/gate_detection_notifier.dart';
import '../screens/project_switcher/project_switcher_overlay.dart';
import '../screens/project_switcher/project_switcher_providers.dart';
import '../workspace/current_workspace_provider.dart';
import '../workspace/workspace_types.dart';
import 'degraded_schema.dart';
import 'scan_round.dart';

/// 套用 [WorkspaceReady]：設定目前工作區、重置降級與推定旗標、丟棄舊掃描
/// 輪次、執行 gate 偵測、寫入最近專案清單（0.2.0-W1-042）。
Future<void> selectWorkspace(WidgetRef ref, WorkspaceReady state) async {
  ref.read(currentWorkspaceStateProvider.notifier).state = state;
  ref.read(degradedSchemaProvider.notifier).state = false;
  ref.read(degradedSchemaVersionsProvider.notifier).state = null;
  ref.read(inferredVersionProvider.notifier).state = null;
  // 同路徑重選時輪次監聽不會 discard；gate 即將重讀 JSON，舊輪次（含舊降級
  // 狀態）必須在此丟棄。僅限使用者主動選專案，缺口報告再次可見不經此處。
  ref.read(scanRoundProvider.notifier).discard('project-reselected');
  await ref.read(gateDetectionNotifierProvider.notifier).detect(state.path);
  await _persistRecentProjectSelection(ref, state.path);
}

/// 成功載入後寫入最近專案清單（SPEC-005 §2.4「寫入時機：成功載入後」）。
/// 寫入失敗不影響本次載入結果，失敗原因已由 repository 內部記錄。
Future<void> _persistRecentProjectSelection(WidgetRef ref, String path) async {
  final repository = ref.read(workspaceRepositoryProvider);
  final success = await repository.addRecentProject(path);
  if (!success) return;
  final updated = await repository.loadRecentProjects();
  ref.read(recentProjectsProvider.notifier).state = updated;
}
