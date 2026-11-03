/// 需求：[SPEC-006 FR-12；EVT-CORPUS-006] Corpus 公開面：讀取被觀測專案的
/// 兩個主題檔，產出 ticket→主題映射、兩檔狀態與主題檔破洞事件。
///
/// 依賴方向：只依賴本 domain 的檔案系統埠；Ticket 清單經輪次結果取得映射，
/// 不自行讀檔。
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'docs_file_system.dart';
import 'parse_outcome.dart';

const _tag = 'corpus.topic_files_reader';

/// 需求：[SPEC-006 FR-12 規則 1] 指派檔位置（隨框架 ticket 系統固定）。
const topicAssignmentsPath = 'docs/work-logs/topic-assignments.txt';

/// 需求：[SPEC-006 FR-12 規則 1] 主題清單位置。
const topicsRegistryPath = 'docs/work-logs/topics-registry.txt';

/// 兩檔各自的狀態（EVT-CORPUS-001 的主題檔狀態）。
enum TopicFileStatus { present, absent, unreadable }

/// EVT-CORPUS-006 的子原因。
enum TopicFilesMalformedReason { unreadable, registryMismatch }

/// EVT-CORPUS-006 的負載。
class TopicFilesParseFailedEvent {
  const TopicFilesParseFailedEvent({
    required this.path,
    required this.reason,
    this.unregisteredTopicCount,
  });

  final String path;
  final TopicFilesMalformedReason reason;

  /// 只在 `registryMismatch` 時有值（>= 1）。
  final int? unregisteredTopicCount;
}

/// 一輪主題檔讀取結果。
class TopicFilesReadResult {
  /// 呼叫端須傳入不可變集合（[readTopicFiles] 已處理）。
  const TopicFilesReadResult({
    required this.ticketTopics,
    required this.assignmentsStatus,
    required this.registryStatus,
    required this.events,
  });

  /// 兩檔皆缺席（舊框架專案的常態，也是例外時的退路）。
  const TopicFilesReadResult.absent()
    : ticketTopics = const <String, String>{},
      assignmentsStatus = TopicFileStatus.absent,
      registryStatus = TopicFileStatus.absent,
      events = const <TopicFilesParseFailedEvent>[];

  /// FR-12 規則 5、10：ticket id → 最後一筆主題，不比對節點。
  final Map<String, String> ticketTopics;
  final TopicFileStatus assignmentsStatus;
  final TopicFileStatus registryStatus;

  /// 一輪至多三筆（規則 8）。
  final List<TopicFilesParseFailedEvent> events;
}

class _FileRead {
  const _FileRead(this.status, this.lines);

  final TopicFileStatus status;
  final List<String> lines;
}

/// 需求：[SPEC-006 FR-12 規則 2～8] 讀兩檔並產出映射、狀態與事件。
Future<TopicFilesReadResult> readTopicFiles({
  required DocsFileSystem fileSystem,
}) async {
  final assignments = await _readLines(fileSystem, topicAssignmentsPath);
  final registry = await _readLines(fileSystem, topicsRegistryPath);
  final pairs = _parseAssignments(assignments.lines);
  final events = <TopicFilesParseFailedEvent>[
    ..._unreadableEvents(assignments, registry),
    ..._mismatchEvents(assignments, registry, pairs),
  ];
  final a = assignments.status.name;
  final r = registry.status.name;
  // i18n-exempt: 開發者診斷 log
  _log('assignments=$a registry=$r mapped=${pairs.length}', 500);
  return TopicFilesReadResult(
    ticketTopics: Map.unmodifiable({for (final p in pairs) p.key: p.value}),
    assignmentsStatus: assignments.status,
    registryStatus: registry.status,
    events: List.unmodifiable(events),
  );
}

Future<_FileRead> _readLines(DocsFileSystem fs, String path) async {
  final read = await fs.readBytes(path);
  switch (read) {
    case DocsReadFailure(:final reason):
      return _failedRead(path, reason);
    case DocsReadSuccess(:final bytes):
      try {
        final text = utf8.decode(bytes);
        final lines = text.split('\n').map(_stripCr).toList();
        return _FileRead(TopicFileStatus.present, lines);
      } on FormatException catch (e) {
        // i18n-exempt: 開發者診斷 log
        _log('topic file not utf-8: $path ($e)', 900);
        return const _FileRead(TopicFileStatus.unreadable, <String>[]);
      }
  }
}

_FileRead _failedRead(String path, UnreadableReason reason) {
  if (reason == UnreadableReason.fileDeleted) {
    return const _FileRead(TopicFileStatus.absent, <String>[]);
  }
  // i18n-exempt: 開發者診斷 log
  _log('topic file unreadable: $path (${reason.name})', 900);
  return const _FileRead(TopicFileStatus.unreadable, <String>[]);
}

String _stripCr(String line) =>
    line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

/// 規則 4：空行、無 tab、任一側為空者跳過；回傳依檔案順序的所有有效行。
List<MapEntry<String, String>> _parseAssignments(List<String> lines) {
  final pairs = <MapEntry<String, String>>[];
  var skipped = 0;
  for (final line in lines) {
    final tab = line.indexOf('\t');
    final id = tab < 0 ? '' : line.substring(0, tab);
    final topic = tab < 0 ? '' : line.substring(tab + 1);
    if (id.isEmpty || topic.isEmpty) {
      skipped++;
      continue;
    }
    pairs.add(MapEntry(id, topic));
  }
  // i18n-exempt: 開發者診斷 log
  _log('assignment lines skipped=$skipped', 500);
  return pairs;
}

List<TopicFilesParseFailedEvent> _unreadableEvents(
  _FileRead assignments,
  _FileRead registry,
) => [
  if (assignments.status == TopicFileStatus.unreadable)
    const TopicFilesParseFailedEvent(
      path: topicAssignmentsPath,
      reason: TopicFilesMalformedReason.unreadable,
    ),
  if (registry.status == TopicFileStatus.unreadable)
    const TopicFilesParseFailedEvent(
      path: topicsRegistryPath,
      reason: TopicFilesMalformedReason.unreadable,
    ),
];

/// 規則 7：兩檔皆可讀時，指派檔全部有效行（含被覆蓋的舊行）的相異主題名
/// 不在清單者，合成一筆事件。
List<TopicFilesParseFailedEvent> _mismatchEvents(
  _FileRead assignments,
  _FileRead registry,
  List<MapEntry<String, String>> pairs,
) {
  if (assignments.status != TopicFileStatus.present ||
      registry.status != TopicFileStatus.present) {
    return const <TopicFilesParseFailedEvent>[];
  }
  final registered = registry.lines.toSet();
  final missing = {
    for (final p in pairs)
      if (!registered.contains(p.value)) p.value,
  };
  if (missing.isEmpty) return const <TopicFilesParseFailedEvent>[];
  return [
    TopicFilesParseFailedEvent(
      path: topicAssignmentsPath,
      reason: TopicFilesMalformedReason.registryMismatch,
      unregisteredTopicCount: missing.length,
    ),
  ];
}

void _log(String message, int level) {
  developer.log(message, name: _tag, level: level);
}
