/// SPEC-007 版本契約第 5 欄日誌事件：事件名、負載鍵與注入接縫。
///
/// 形態沿用 `WorkspaceRepository.logSink`：事件名是測試斷言綁定的穩定契約，
/// `message` 只是可自由改寫的除錯文案。生產預設轉呼 `developer.log`。
library;

import 'dart:developer' as developer;

/// 建圖日誌事件（穩定契約）。
enum GraphLogEvent {
  /// 建圖完成，負載帶結果值（[GraphLogKeys]）。
  buildCompleted,

  /// 建圖不可用，負載帶原因碼（[GraphLogKeys.reason]）。
  buildUnavailable,
}

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class GraphLogKeys {
  static const nodeCount = 'nodeCount';
  static const edgeCount = 'edgeCount';
  static const danglingRefCount = 'danglingRefCount';
  static const malformedRefCount = 'malformedRefCount';
  static const duplicateIdCount = 'duplicateIdCount';
  static const multiSourceCount = 'multiSourceCount';
  static const resolvedCount = 'resolvedCount';
  static const totalReferences = 'totalReferences';
  static const reason = 'reason';
}

/// 日誌投影的接縫。
typedef GraphLogSink = void Function(
  String message, {
  required GraphLogEvent event,
  required Map<String, Object?> payload,
  int? level,
});

/// 生產預設：轉呼 `developer.log(name: 'GraphBuilder')`。
void defaultGraphLogSink(
  String message, {
  required GraphLogEvent event,
  required Map<String, Object?> payload,
  int? level,
}) {
  developer.log(
    '[${event.name}] $message $payload', // i18n-exempt: 開發者 debug log
    name: 'GraphBuilder',
    level: level ?? 0,
  );
}
