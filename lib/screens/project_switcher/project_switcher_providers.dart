/// 專案切換浮層狀態（SPEC-001 §7）。
///
/// 目前專案標籤與最近專案清單改由 [WorkspaceRepository] 持久化資料驅動
/// （SPEC-005 §2.4，取代先前的 fixture）：[currentWorkspaceStateProvider]
/// 由 `AppShell._restoreWorkspaceAndDetect()`（啟動還原）與
/// `project_switcher_overlay.dart` 的 `_handleChosenState`（選取新資料夾）
/// 寫入；[recentProjectsProvider] 由 `loadRecentProjects()` 載入、由
/// `addRecentProject()` 成功後同步（`0.2.1-W1-003`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/workspace_types.dart';

/// 浮層展開態；`true` 對應 SPEC-001 §7「展開」或「無最近專案」（依
/// [recentProjectsProvider] 是否為空清單區分），`false` 對應「收合」。
final switcherOpenProvider = StateProvider<bool>((ref) => false);

/// 目前工作資料夾狀態；初始為 [WorkspaceUnset]（App 剛啟動、`restore()`
/// 尚未回傳，或從未選過資料夾）。
final currentWorkspaceStateProvider =
    StateProvider<WorkspaceState>((ref) => const WorkspaceUnset());

/// 最近專案清單；初始為空清單，由 `AppShell` 於啟動時以
/// `WorkspaceRepository.loadRecentProjects()` 載入寫入（SPEC-005 §2.4）。
final recentProjectsProvider =
    StateProvider<List<RecentProject>>((ref) => const []);

/// 側欄入口顯示的目前專案名；取 [currentWorkspaceStateProvider] 的
/// [WorkspaceReady.path] 資料夾名，非 [WorkspaceReady] 時回傳 `null`
/// （`ProjectSwitcherEntry` 顯示元件預設 `projectSwitcherEntryLabel`）。
final currentProjectNameProvider = Provider<String?>((ref) {
  final state = ref.watch(currentWorkspaceStateProvider);
  if (state is! WorkspaceReady) return null;
  return folderNameOf(state.path);
});

/// 從絕對路徑取最後一段資料夾名，供側欄標籤與最近專案項名稱共用
/// （`project_switcher_overlay.dart` 亦使用）。結尾斜線先去除，避免
/// 取到空字串。
String folderNameOf(String path) {
  var normalized = path;
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final index = normalized.lastIndexOf('/');
  if (index < 0) return normalized;
  return normalized.substring(index + 1);
}
