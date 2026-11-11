// P-9 正向對照：以 WorkspaceRelativePath 呼叫寫入入口，零 error。
import 'package:graph_project_docs_manager/edit/edit_workspace.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

Future<BeginEditingResult> caller(
  EditWorkspace workspace,
  WorkspaceRelativePath path,
) => workspace.beginEditing(path);
