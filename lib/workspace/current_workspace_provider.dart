/// 目前工作資料夾狀態 provider（自 `screens/project_switcher` 下移，
/// 0.5.0-W1-114.19：lib/app 不得反向依賴 lib/screens）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// 目前工作資料夾狀態；初始為 [WorkspaceUnset]（App 剛啟動、`restore()`
/// 尚未回傳，或從未選過資料夾）。
final currentWorkspaceStateProvider = StateProvider<WorkspaceState>(
  (ref) => const WorkspaceUnset(),
);
