/// SPEC-010 節點詳情日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 節點詳情 domain 事件。
enum NodeDetailLogEvent {
  /// 重新整理開始（debug）。
  refreshStarted,

  /// 重新整理分類完成（debug），負載 `outcome_kind`（檔案不存在時缺席）。
  refreshClassified,

  /// 重新整理讀檔失敗，warning、`platform_io`。
  refreshReadFailed,

  /// 節點本文讀取失敗，warning、`platform_io`。
  bodyReadFailed,
}

/// 事件負載鍵。
abstract final class NodeDetailLogKeys {
  static const outcomeKind = 'outcome_kind';
}

/// 生產預設：經共用 writer 輸出，domain 為 `node_detail`。
final LogSink<NodeDetailLogEvent> defaultNodeDetailLogSink =
    defaultLogSink<NodeDetailLogEvent>('node_detail');

/// 節點詳情 sink；測試以 override 注入記錄器。
final nodeDetailLogSinkProvider = Provider<LogSink<NodeDetailLogEvent>>(
  (ref) => defaultNodeDetailLogSink,
);
