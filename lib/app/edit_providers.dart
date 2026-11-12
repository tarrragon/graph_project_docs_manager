/// 節點詳情編輯模式的接線 provider（1.0.0-W3-553.15.1）。
///
/// 三項：值域來源、EditWorkspace、工作區唯讀降級旗標。皆以預設 build 接好，
/// 不依賴 app root override；測試以 port provider 覆寫。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/app_shell.dart'
    show ReadonlyWorkspaceReason;
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/screens/edit/field_input_mapping.dart';
import 'package:graph_project_docs_manager/screens/edit/type_table_field_domain_source.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// git driven port；測試覆寫為替身。
final editGitPortProvider = Provider<EditGitPort>(
  (ref) => const IoEditGitPort(),
);

/// 檔案系統 driven port；測試覆寫為替身。
final editFilePortProvider = Provider<EditFilePort>(
  (ref) => const IoEditFilePort(),
);

/// 值域來源：讀最近一輪完成的型別表；尚無輪次時為空來源。
final fieldDomainSourceProvider = Provider<FieldDomainSource>((ref) {
  final round = ref.watch(lastCompletedRoundProvider);
  final table = round?.schemaResolution.typeTable;
  return table == null
      ? const TypeTableFieldDomainSource.empty()
      : TypeTableFieldDomainSource(table);
});

/// 目前工作區的 EditWorkspace；工作區未就緒時為 null。工作區換路徑即重建。
final editWorkspaceProvider = FutureProvider<EditWorkspace?>((ref) async {
  final workspace = ref.watch(currentWorkspaceStateProvider);
  if (workspace is! WorkspaceReady) return null;
  return EditWorkspace.open(
    root: workspace.path,
    git: ref.watch(editGitPortProvider),
    files: ref.watch(editFilePortProvider),
  );
});

/// 工作區唯讀降級旗標：值來自 EditWorkspace 的唯讀降級探測，畫面層不重算。
/// null 代表可寫，或探測尚未完成／工作區未就緒。
final readonlyWorkspaceReasonProvider = Provider<ReadonlyWorkspaceReason?>((
  ref,
) {
  final reason = ref.watch(editWorkspaceProvider).value?.readonlyReason;
  return switch (reason) {
    EditReadonlyReason.notGit => ReadonlyWorkspaceReason.notGit,
    EditReadonlyReason.gitMissing => ReadonlyWorkspaceReason.gitMissing,
    null => null,
  };
});
