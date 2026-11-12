/// 開檔入口的路徑解析（SPEC-003 §2.2：ExternalOpener.open 前提為絕對路徑）。
library;

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import 'workspace_io_log_event.dart';
import 'workspace_types.dart';

/// 把畫面持有的檔案路徑解析為可交給 `ExternalOpener` 的絕對路徑。
///
/// 規則：
/// 1. 以 `/` 開頭：原樣回傳，不論 workspace 狀態。
/// 2. 相對路徑且 workspace 為 [WorkspaceReady]：以專案根目錄組合。
/// 3. 相對路徑且 workspace 非 Ready：記 warning、回傳 null，
///    呼叫端不呼叫 opener，走 notFound 回饋。
String? resolveOpenPath(
  WorkspaceState workspace,
  String path, {
  LogSink<OpenPathLogEvent>? log,
}) {
  if (path.startsWith('/')) return path;
  if (workspace is WorkspaceReady) return '${workspace.path}/$path';
  (log ?? defaultOpenPathLogSink)(
    OpenPathLogEvent.relativePathUnresolved,
    LogFields({
      WorkspaceIoLogKeys.workspaceState: LogValue.fieldName(
        workspace.runtimeType.toString(),
      ),
      WorkspaceIoLogKeys.path: LogValue.path('/', '/$path'),
    }),
    level: LogLevel.warning,
    source: ErrorSource.gateBlocked,
  );
  return null;
}
