/// SPEC-007 版本契約第 5 欄日誌事件：事件名與負載鍵。
///
/// 事件名是測試斷言綁定的穩定契約；接縫為 SPEC-010 的 `LogSink<GraphLogEvent>`，
/// 生產預設經共用 writer 輸出。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 建圖日誌事件（穩定契約）。
enum GraphLogEvent {
  /// 建圖完成，負載帶結果值（[GraphLogKeys]）。
  buildCompleted,

  /// 建圖不可用，負載帶原因碼（[GraphLogKeys.reason]）。
  buildUnavailable,

  /// 鄰接查詢時圖不可用（每個查詢實例只記一次），負載帶原因碼。
  adjacencyUnavailable,

  /// `flowOf` 查詢時圖不可用（與鄰接查詢同形：同一 buildResult 只記一次），
  /// 負載帶原因碼。
  flowUnavailable,

  /// FR-13 `orderedBundles` 查詢時圖不可用（與鄰接查詢同形），負載帶原因碼。
  bundleOrderUnavailable,

  /// FR-12 `relationOf` 查詢時圖不可用（與鄰接查詢同形），負載帶原因碼。
  domainUcRelationUnavailable,

  /// FR-09 必要邊要求因其邊型皆未啟用而跳過（debug）。
  requiredEdgeSkipped,

  /// `closed_by` 引用依略過規則不分類（debug；每筆引用一次，不得高於 debug）。
  closedBySkipped,
}

/// 圖不可用日誌的「同一 buildResult 只記一次」登記（與鄰接查詢同形）。
///
/// [_loggedBuilds] 由各查詢類別以 static 持有（跨實例共用）；
/// buildResult 為 null 時以本登記實例（即查詢實例）為單位。
class UnavailableLogOnce {
  UnavailableLogOnce(this._loggedBuilds);

  final Expando<bool> _loggedBuilds;
  bool _nullLogged = false;

  /// 回傳 true 代表此單位尚未記過，並登記為已記。
  bool mark(Object? buildResult) {
    if (buildResult == null) {
      final first = !_nullLogged;
      _nullLogged = true;
      return first;
    }
    if (_loggedBuilds[buildResult] == true) return false;
    _loggedBuilds[buildResult] = true;
    return true;
  }
}

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class GraphLogKeys {
  static const nodeCount = 'nodeCount';
  static const edgeCount = 'edgeCount';
  static const danglingRefCount = 'danglingRefCount';
  static const malformedRefCount = 'malformedRefCount';
  static const duplicateIdCount = 'duplicateIdCount';
  static const multiSourceCount = 'multiSourceCount';
  static const flowDefectCount = 'flowDefectCount';
  static const resolvedCount = 'resolvedCount';
  static const totalReferences = 'totalReferences';
  static const reason = 'reason';
}

/// 生產預設：經共用 writer 輸出，domain 為 `graph`。
final LogSink<GraphLogEvent> defaultGraphLogSink =
    defaultLogSink<GraphLogEvent>('graph');
