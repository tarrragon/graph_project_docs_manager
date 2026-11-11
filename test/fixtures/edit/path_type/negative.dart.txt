// P-9 負向輸入：以 String 呼叫寫入函式，必須有 error。
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';

Future<void> writeDocument(WorkspaceRelativePath path, String content) async {}

Future<void> caller() => writeDocument('docs/a.md', 'x');
