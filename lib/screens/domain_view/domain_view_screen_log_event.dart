/// SPEC-010 Domain 視圖畫面層日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// Domain 視圖畫面事件（載入編排事件見 `DomainViewLogEvent`）。
enum DomainViewScreenLogEvent {
  /// 投影準備中重啟輪次失敗，error、`internal`。
  roundRestartFailed,

  /// 開啟 docs 目錄時工作區非 Ready，warning、`gate_blocked`。
  openDocsWorkspaceNotReady,

  /// 圖不可用列的重新掃描失敗，error、`internal`。
  rescanFailed,
}

/// 生產預設：經共用 writer 輸出，domain 為 `domain_view`。
final LogSink<DomainViewScreenLogEvent> defaultDomainViewScreenLogSink =
    defaultLogSink<DomainViewScreenLogEvent>('domain_view');

/// 畫面層 sink；測試以 override 注入記錄器。
final domainViewScreenLogSinkProvider =
    Provider<LogSink<DomainViewScreenLogEvent>>(
      (ref) => defaultDomainViewScreenLogSink,
    );
