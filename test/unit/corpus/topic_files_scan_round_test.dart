// 需求：[SPEC-006 FR-12 規則 2、9；EVT-CORPUS-001／006 接進掃描輪次]
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/topic_files_reader.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

const _assignments = 'docs/work-logs/topic-assignments.txt';
const _registry = 'docs/work-logs/topics-registry.txt';

class _MemoryFileSystem implements DocsFileSystem {
  _MemoryFileSystem(this.files);

  final Map<String, String> files;

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async =>
      const <DocsFileSystemEntry>[];

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    final content = files[relativePath];
    if (content == null) {
      return const DocsReadFailure(UnreadableReason.fileDeleted);
    }
    return DocsReadSuccess(Uint8List.fromList(utf8.encode(content)));
  }
}

class _ThrowingFileSystem implements DocsFileSystem {
  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async =>
      const <DocsFileSystemEntry>[];

  @override
  Future<DocsReadResult> readBytes(String relativePath) async =>
      throw StateError('simulated read failure');
}

TypeTable _builtinTable() => typeTableFromJson(
  jsonDecode(
    File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

Future<CorpusScanResult> _scan(Map<String, String> files) => scanCorpus(
  fileSystem: _MemoryFileSystem(files),
  table: const TypeTable(<String, NodeTypeEntry>{}),
  builtinTable: _builtinTable(),
);

void main() {
  group('主題檔進掃描輪次', () {
    test('輪次結果帶映射與兩檔狀態', () async {
      final r = await _scan({_assignments: 'A\tx\n', _registry: 'x\n'});
      expect(r.topicFilesRead.ticketTopics, {'A': 'x'});
      expect(r.topicFilesRead.assignmentsStatus, TopicFileStatus.present);
      expect(r.topicFilesRead.registryStatus, TopicFileStatus.present);
      expect(r.topicFilesParseFailedEvents, isEmpty);
    });

    test('對照：同語料主題清單缺 q 時事件 0 對 1', () async {
      final ok = await _scan({_assignments: 'A\tq\n', _registry: 'q\n'});
      final bad = await _scan({_assignments: 'A\tq\n', _registry: 'x\n'});
      expect(ok.topicFilesParseFailedEvents, isEmpty);
      expect(bad.topicFilesParseFailedEvents, hasLength(1));
      expect(
        bad.topicFilesParseFailedEvents.single.reason,
        TopicFilesMalformedReason.registryMismatch,
      );
    });

    test('兩檔缺席：映射空、狀態 absent、無事件', () async {
      final r = await _scan(const {});
      expect(r.topicFilesRead.ticketTopics, isEmpty);
      expect(r.topicFilesRead.assignmentsStatus, TopicFileStatus.absent);
      expect(r.topicFilesRead.registryStatus, TopicFileStatus.absent);
      expect(r.topicFilesParseFailedEvents, isEmpty);
    });

    test('失敗隔離：主題檔不一致不改變 FR-07 摘要', () async {
      final clean = await _scan({_assignments: 'A\tx\n', _registry: 'x\n'});
      final dirty = await _scan({_assignments: 'A\tq\n', _registry: 'x\n'});
      expect(dirty.summary.totalFilesScanned, clean.summary.totalFilesScanned);
      expect(dirty.summary.nodeCount, clean.summary.nodeCount);
      expect(dirty.rawNodes.length, clean.rawNodes.length);
    });

    test('讀取拋例外：掃描照常完成、視同缺席、無事件', () async {
      final r = await scanCorpus(
        fileSystem: _ThrowingFileSystem(),
        table: const TypeTable(<String, NodeTypeEntry>{}),
        builtinTable: _builtinTable(),
      );
      expect(r.topicFilesRead.assignmentsStatus, TopicFileStatus.absent);
      expect(r.topicFilesParseFailedEvents, isEmpty);
    });

    test('FR-08 第四項：topicFilesMalformedCount 0／1 對照', () async {
      final ok = await _scan({_assignments: 'A\tq\n', _registry: 'q\n'});
      final bad = await _scan({_assignments: 'A\tq\n', _registry: 'x\n'});
      expect(ok.summary.topicFilesMalformedCount, 0);
      expect(bad.summary.topicFilesMalformedCount, 1);
      expect(
        bad.summary.topicFilesMalformedCount,
        bad.topicFilesParseFailedEvents.length,
      );
    });
  });
}
