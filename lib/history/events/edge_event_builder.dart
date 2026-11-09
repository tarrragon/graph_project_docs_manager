// SPEC-008 FR-04、FR-05：以 commit 為單位比較邊鍵的宣告來源集合，產生邊事件。
// 純函式風格：輸入為 012.6 的每 commit 路徑前後 frontmatter，無 I/O。
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_key.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';

class _PathState {
  const _PathState(this.nodeId, this.entries);
  final String? nodeId;
  final List<MapEntry<EdgeKey, EdgeSource>> entries;
}

class EdgeEventBuilder {
  /// [ticketIdPattern]：Schema 中 ticket 節點型別的 `id_pattern`（FR-05 規則 1）。
  EdgeEventBuilder({required this.extractor, required this.ticketIdPattern});

  final DeclarationExtractor extractor;
  final RegExp ticketIdPattern;
  final Map<String, _PathState> _paths = {};
  final Map<EdgeKey, Set<EdgeSource>> _sources = {};

  /// 「非字串值」計數（FR-03 規則 4）。
  int nonStringValues = 0;

  /// 「無 ID 檔案」計數（FR-03 規則 1）。
  int filesWithoutId = 0;

  /// 需求：[SPEC-008 FR-04 規則 2] 依序處理主線 commit，回傳該 commit 的事件
  /// （已依邊型鍵名、起點、終點排序）。
  List<EdgeEvent> processCommit(ScanCommitResult result) {
    final before = <EdgeKey, Set<EdgeSource>>{};
    final createdTickets = <String>{};
    for (final change in result.changes) {
      _applyChange(change, before, createdTickets);
    }
    final keys = before.keys.toList()..sort();
    return [
      for (final key in keys)
        ?_eventFor(key, before[key]!, result.commit, createdTickets),
    ];
  }

  /// 需求：[SPEC-008 FR-08 規則 3] 淺層邊界 commit（父欄位為空且前置檢查回報淺層）
  /// 只建初始狀態，不產生事件；其餘情況照 [processCommit]（含非淺層的根 commit）。
  List<EdgeEvent> processCommitWithShallow(
    ScanCommitResult result, {
    required bool isShallow,
  }) {
    if (!isShallow || result.commit.parents.isNotEmpty) {
      return processCommit(result);
    }
    for (final change in result.changes) {
      _applyChange(change, {}, {});
    }
    return const [];
  }

  void _applyChange(
    PathChange change,
    Map<EdgeKey, Set<EdgeSource>> before,
    Set<String> createdTickets,
  ) {
    final next = _nextState(change);
    if (next == null) return;
    for (final entry in _paths[change.path]?.entries ?? const []) {
      _snapshot(before, entry.key);
      _remove(entry.key, entry.value);
    }
    for (final entry in next.entries) {
      _snapshot(before, entry.key);
      _sources.putIfAbsent(entry.key, () => {}).add(entry.value);
    }
    _paths[change.path] = next;
    final id = next.nodeId;
    if (change.created && id != null && ticketIdPattern.hasMatch(id)) {
      createdTickets.add(change.path);
    }
  }

  /// 無法解析的版本沿用前一版宣告（回傳 null 表示不變）。
  _PathState? _nextState(PathChange change) {
    final extraction = extractor.extract(change.after);
    if (extraction.parseFailed) return null;
    nonStringValues += extraction.nonStringValues;
    if (extraction.missingId) filesWithoutId++;
    final id = extraction.nodeId;
    return _PathState(id, [
      if (id != null)
        for (final d in extraction.declarations)
          MapEntry(
            edgeKeyOf(
              edgeType: d.edgeType,
              field: d.field,
              declarerId: id,
              value: d.value,
            ),
            EdgeSource(
              path: change.path,
              field: d.field,
              value: d.value,
              declarerId: id,
            ),
          ),
    ]);
  }

  void _snapshot(Map<EdgeKey, Set<EdgeSource>> before, EdgeKey key) {
    before.putIfAbsent(key, () => Set.of(_sources[key] ?? const {}));
  }

  void _remove(EdgeKey key, EdgeSource source) {
    final set = _sources[key];
    if (set == null) return;
    set.remove(source);
    if (set.isEmpty) _sources.remove(key);
  }

  EdgeEvent? _eventFor(
    EdgeKey key,
    Set<EdgeSource> sourcesBefore,
    HistoryCommit commit,
    Set<String> createdTickets,
  ) {
    final sourcesAfter = _sources[key] ?? const <EdgeSource>{};
    if (sourcesBefore.isEmpty == sourcesAfter.isEmpty) return null;
    final added = sourcesBefore.isEmpty;
    return EdgeEvent(
      type: added ? EdgeEventType.added : EdgeEventType.removed,
      key: key,
      declarersBefore: _declarers(sourcesBefore),
      declarersAfter: _declarers(sourcesAfter),
      commitId: commit.id,
      committedAtSeconds: commit.committedAtSeconds,
      author: commit.author,
      subject: commit.subject,
      isTicketCreation:
          added && sourcesAfter.any((s) => createdTickets.contains(s.path)),
    );
  }

  List<String> _declarers(Iterable<EdgeSource> sources) =>
      {for (final s in sources) s.declarerId}.toList()..sort();
}
