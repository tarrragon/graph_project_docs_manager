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
  }) : hasNoCommit = false;

  /// 尚無 commit：結果完成、事件空、帶標記（FR-08 規則 4；不是失敗）。
  const HistoryScanSnapshot.noCommit({
    required this.key,
    required this.isBuiltinTableDegraded,
  }) : events = const [],
       mainline = const [],
       tags = const [],
       isShallow = false,
       hasNoCommit = true;

  final HistoryCacheKey key;
  final List<EdgeEvent> events;
  final List<String> mainline;
  final List<GitTagRef> tags;
  final bool isShallow;
  final bool isBuiltinTableDegraded;
  final bool hasNoCommit;

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
  const HistoryLoading();
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
  const HistoryFailed(this.reason);

  final GitFailureReason reason;
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
  });

  final HistorySchemaReadiness schemaReadiness;
  final String tableIdentity;

  /// 每次掃描建立新的建構器（內含逐 commit 狀態）。
  final EdgeEventBuilder Function() createBuilder;
}
