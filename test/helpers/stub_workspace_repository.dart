/// 啟動 restore 結果的固定替身（0.3.3-W3-398）。
///
/// shell 啟動後依 `restore()` 結果改寫 Domain 視圖狀態，經 shell 啟動的測試
/// 因此不能再靠 `domainViewStateProvider.overrideWith` 注入狀態（會被啟動
/// 改寫覆蓋）；改注入本替身讓 restore 回固定結果，再視需要搭配訊號探測替身
/// 讓 gate 判出目標狀態。
library;

import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// `restore()` 回傳固定 [state]；其餘方法為無副作用的最小實作。
class StubWorkspaceRepository implements WorkspaceRepository {
  StubWorkspaceRepository(this._state);

  final WorkspaceState _state;

  @override
  Future<WorkspaceState> restore() async => _state;

  @override
  Future<ChooseFolderResult> chooseFolder() async =>
      ChooseFolderSelected(_state);

  @override
  Future<ChooseFolderResult> openPath(String path) async =>
      ChooseFolderSelected(_state);

  @override
  Future<List<RecentProject>> loadRecentProjects() async => const [];

  @override
  Future<bool> addRecentProject(String path) async => true;
}

/// 固定回傳指定訊號的 gate 探測替身；[schemaJson] 為 false 時 gate 判
/// `DomainSchemaUnconsumable`，為 true 且 [version] 等於內建版本時判
/// `DomainReady`。
class StubFrameworkSignalProbe implements FrameworkSignalProbePort {
  const StubFrameworkSignalProbe({
    required this.version,
    required this.schemaJson,
  });

  final String? version;
  final bool schemaJson;

  @override
  Future<String?> readVersion(String workspacePath) async => version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => schemaJson;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async =>
      schemaJson ? version : null;
}
