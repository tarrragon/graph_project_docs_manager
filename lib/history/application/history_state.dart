// SPEC-008 FR-09：History 結果狀態與快取鍵（純 Dart，不依賴 Riverpod）。
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';

/// 快取鍵（FR-09 規則 2）：工作區根、HEAD、型別表識別。
class HistoryCacheKey {
  const HistoryCacheKey({
    required this.root,
    required this.head,
    required this.tableIdentity,
  });

  final String root;
  final String head;
  final String tableIdentity;

  @override
  bool operator ==(Object other) =>
      other is HistoryCacheKey &&
      other.root == root &&
      other.head == head &&
      other.tableIdentity == tableIdentity;

  @override
  int get hashCode => Object.hash(root, head, tableIdentity);
}

/// 掃描完成的結果；查詢在記憶體內進行，不重新掃描（FR-07）。
class HistoryScanSnapshot {
  const HistoryScanSnapshot({
    required this.key,
    required this.events,
    required this.mainline,
    required this.tags,
    required this.isShallow,
    required this.isBuiltinTableDegraded,
    this.shallowBoundaryDate,
  }) : hasNoCommit = false;

  /// 尚無 commit：結果完成、事件空、帶標記（FR-08 規則 4；不是失敗）。
  const HistoryScanSnapshot.noCommit({
    required this.key,
    required this.isBuiltinTableDegraded,
  }) : events = const [],
       mainline = const [],
       tags = const [],
       isShallow = false,
       shallowBoundaryDate = null,
       hasNoCommit = true;

  final HistoryCacheKey key;
  final List<EdgeEvent> events;
  final List<String> mainline;
  final List<GitTagRef> tags;
  final bool isShallow;
  final bool isBuiltinTableDegraded;
  final bool hasNoCommit;

  /// 淺層邊界日期：無 parent 之 commit 的 committer 時間（UTC）；
  /// 非淺層或無邊界 commit 時為 `null`（SPEC-003 §3.9 淺層標示）。
  final DateTime? shallowBoundaryDate;

  HistoryQuery query({required DateTime Function() clock}) => HistoryQuery(
    events: events,
    mainline: mainline,
    tags: tags,
    head: key.head,
    clock: clock,
  );
}

/// 第七畫面可見的狀態。
sealed class HistoryViewState {
  const HistoryViewState();
}

/// 尚未進入第七畫面：不呼叫任何 git（FR-09 規則 1）。
final class HistoryIdle extends HistoryViewState {
  const HistoryIdle();
}

final class HistoryLoading extends HistoryViewState {
  const HistoryLoading({this.processedCount = 0});

  /// 已處理的 commit 數（SPEC-001 §10 讀取中；不推算百分比）。
  final int processedCount;

  @override
  bool operator ==(Object other) =>
      other is HistoryLoading && other.processedCount == processedCount;

  @override
  int get hashCode => Object.hash(HistoryLoading, processedCount);
}

final class HistoryLoaded extends HistoryViewState {
  const HistoryLoaded(this.snapshot);

  final HistoryScanSnapshot snapshot;
}

/// 不是 git 工作樹（定案降級）。
final class HistoryNotGitRepo extends HistoryViewState {
  const HistoryNotGitRepo();
}

/// 找不到 git（定案降級）。
final class HistoryGitNotFound extends HistoryViewState {
  const HistoryGitNotFound();
}

/// 讀取失敗（可重試）。
final class HistoryFailed extends HistoryViewState {
  const HistoryFailed(this.reason, {this.stderrSummary = ''});

  final GitFailureReason reason;

  /// git 的 stderr 摘要原文（可空）；畫面據此顯示原因（historyLoadFailedDetail）。
  final String stderrSummary;
}

/// 掃描輪次不可用：等待型別表的輪次失敗，或被取消且無後續輪次
/// （SPEC-008 FR-09 規則 1、FR-08 規則 5；與 git 原因碼分開，可重試）。
final class HistoryScanRoundUnavailable extends HistoryViewState {
  const HistoryScanRoundUnavailable();
}

/// 掃描被取消；部分事件不外露。
final class HistoryCancelled extends HistoryViewState {
  const HistoryCancelled();
}

/// Schema 阻擋：不掃描、不呼叫 git（FR-08 規則 6）。
final class HistorySchemaBlocked extends HistoryViewState {
  const HistorySchemaBlocked();
}

/// 組裝端注入的掃描輸入（Schema 就緒度、型別表識別、事件建構器工廠）。
class HistoryScanInputs {
  const HistoryScanInputs({
    required this.schemaReadiness,
    required this.tableIdentity,
    required this.createBuilder,
    this.awaitTypeTable = _typeTableAlwaysReady,
  });

  /// 等到本工作區有可用的型別表（SPEC-008 FR-09 規則 1）。回傳 `false`
  /// 代表輪次結束而沒有結果（失敗或被取消且無後續輪次）。預設立即就緒。
  final Future<bool> Function() awaitTypeTable;

  final HistorySchemaReadiness schemaReadiness;
  final String tableIdentity;

  /// 每次掃描建立新的建構器（內含逐 commit 狀態）。
  final EdgeEventBuilder Function() createBuilder;
}

Future<bool> _typeTableAlwaysReady() => Future.value(true);
