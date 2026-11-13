/// SPEC-010 導覽殼日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 導覽殼事件（皆為 debug）。
enum ShellLogEvent {
  /// 首幀後記錄 Domain 視圖狀態。
  firstFrameDomainState,

  /// 還原工作區完成，負載帶 [ShellLogKeys.ready]。
  workspaceRestored,

  /// 生命週期狀態轉換，負載帶 [ShellLogKeys.previous]、[ShellLogKeys.current]。
  lifecycleChanged,
}

/// 事件負載鍵。
abstract final class ShellLogKeys {
  static const previous = 'previous';
  static const current = 'current';
  static const ready = 'ready';
}

/// 導覽殼 sink；預設經共用 writer 輸出，domain 為 `shell`，測試以 override 注入記錄器。
final shellLogSinkProvider = Provider<LogSink<ShellLogEvent>>(
  (ref) => defaultLogSink<ShellLogEvent>('shell'),
);
