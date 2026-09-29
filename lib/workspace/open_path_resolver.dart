/// 開檔入口的路徑解析（SPEC-003 §2.2：ExternalOpener.open 前提為絕對路徑）。
library;

import 'dart:developer' as developer;

import 'workspace_types.dart';

const String _tag = 'OpenPathResolver';

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
  void Function(String message, {int level}) log = _defaultLog,
}) {
  if (path.startsWith('/')) return path;
  if (workspace is WorkspaceReady) return '${workspace.path}/$path';
  log(
    '無法解析相對路徑：workspace 非 WorkspaceReady（${workspace.runtimeType}），路徑 $path', // i18n-exempt: 開發者診斷 log
    level: 900,
  );
  return null;
}

void _defaultLog(String message, {int level = 900}) =>
    developer.log(message, name: _tag, level: level);
