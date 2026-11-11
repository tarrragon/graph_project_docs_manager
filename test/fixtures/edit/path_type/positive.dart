// P-9 正向對照：以 WorkspaceRelativePath 呼叫寫入函式，零 error。
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

Future<void> writeDocument(WorkspaceRelativePath path, String content) async {}

Future<void> caller(WorkspaceRelativePath path) => writeDocument(path, 'x');
