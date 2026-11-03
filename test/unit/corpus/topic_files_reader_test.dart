// 需求：[SPEC-006 FR-12 規則 3～8；EVT-CORPUS-006] 主題檔讀取器單元測試。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/topic_files_reader.dart';

const _assignments = 'docs/work-logs/topic-assignments.txt';
const _registry = 'docs/work-logs/topics-registry.txt';

class _BytesFileSystem implements DocsFileSystem {
  _BytesFileSystem(this.files, {this.permissionDenied = const <String>{}});

  final Map<String, List<int>> files;
  final Set<String> permissionDenied;

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async =>
      const <DocsFileSystemEntry>[];

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    if (permissionDenied.contains(relativePath)) {
      return const DocsReadFailure(UnreadableReason.permission);
    }
    final bytes = files[relativePath];
    if (bytes == null) {
      return const DocsReadFailure(UnreadableReason.fileDeleted);
    }
    return DocsReadSuccess(Uint8List.fromList(bytes));
  }
}

Future<TopicFilesReadResult> _read(
  Map<String, String> texts, {
  Set<String> denied = const <String>{},
}) => readTopicFiles(
  fileSystem: _BytesFileSystem(
    texts.map((k, v) => MapEntry(k, utf8.encode(v))),
    permissionDenied: denied,
  ),
);

void main() {
  group('FR-12 規則 3～5 指派檔解析', () {
    test('一票多筆取最後一筆，三主題皆登錄則無事件', () async {
      final r = await _read({
        _assignments: 'A\tx\nB\ty\nA\tz\n',
        _registry: 'x\ny\nz\n',
      });
      expect(r.ticketTopics, {'A': 'z', 'B': 'y'});
      expect(r.events, isEmpty);
    });

    test('跳過空行、無 tab 行、ID 為空與主題為空；檔尾缺換行照收', () async {
      final r = await _read({
        _assignments: '\nno-tab\n\tx\nD\t\nC\tw',
        _registry: 'w\n',
      });
      expect(r.ticketTopics, {'C': 'w'});
      expect(r.events, isEmpty);
    });

    test('CRLF 分行，主題名不含 CR', () async {
      final r = await _read({_assignments: 'A\tx\r\n', _registry: 'x\r\n'});
      expect(r.ticketTopics['A'], 'x');
      expect(r.events, isEmpty);
    });

    test('以第一個 tab 切分，主題內含 tab 保留', () async {
      final r = await _read({_assignments: 'A\tx\ty\n'});
      expect(r.ticketTopics['A'], 'x\ty');
    });
  });

  group('FR-12 規則 6 缺檔', () {
    test('指派檔不存在：映射空、狀態 absent、無事件', () async {
      final r = await _read({_registry: 'x\n'});
      expect(r.ticketTopics, isEmpty);
      expect(r.assignmentsStatus, TopicFileStatus.absent);
      expect(r.registryStatus, TopicFileStatus.present);
      expect(r.events, isEmpty);
    });

    test('主題清單不存在：不做一致性檢查、映射照常、無事件', () async {
      final r = await _read({_assignments: 'A\tq\n'});
      expect(r.ticketTopics, {'A': 'q'});
      expect(r.registryStatus, TopicFileStatus.absent);
      expect(r.events, isEmpty);
    });
  });

  group('FR-12 規則 7 一致性', () {
    test('E2 對照：主題 q 不在清單，恰一筆 registryMismatch，映射仍含', () async {
      final r = await _read({
        _assignments: 'A\tq\nB\tq\nC\tr\n',
        _registry: 'x\n',
      });
      expect(r.ticketTopics, {'A': 'q', 'B': 'q', 'C': 'r'});
      expect(r.events, hasLength(1));
      final e = r.events.single;
      expect(e.path, _assignments);
      expect(e.reason, TopicFilesMalformedReason.registryMismatch);
      expect(e.unregisteredTopicCount, 2);
    });

    test('被後行覆蓋的舊行主題不在清單仍計入', () async {
      final r = await _read({_assignments: 'A\told\nA\tx\n', _registry: 'x\n'});
      expect(r.ticketTopics, {'A': 'x'});
      expect(r.events.single.unregisteredTopicCount, 1);
    });

    test('跳過的行不參與檢查', () async {
      final r = await _read({_assignments: 'A\t\n\tq\n', _registry: 'x\n'});
      expect(r.events, isEmpty);
    });
  });

  group('FR-12 規則 8 無法讀取', () {
    test('指派檔非 UTF-8：映射空、一筆 unreadable', () async {
      final r = await readTopicFiles(
        fileSystem: _BytesFileSystem({
          _assignments: [0xff, 0xfe, 0x41],
          _registry: utf8.encode('x\n'),
        }),
      );
      expect(r.ticketTopics, isEmpty);
      expect(r.assignmentsStatus, TopicFileStatus.unreadable);
      expect(r.events.single.reason, TopicFilesMalformedReason.unreadable);
      expect(r.events.single.path, _assignments);
      expect(r.events.single.unregisteredTopicCount, isNull);
    });

    test('兩檔皆無法讀取：兩筆 unreadable，不做規則 7', () async {
      final r = await _read(
        {_assignments: 'A\tq\n', _registry: 'x\n'},
        denied: {_assignments, _registry},
      );
      expect(r.events, hasLength(2));
      expect(
        r.events.map((e) => e.reason),
        everyElement(TopicFilesMalformedReason.unreadable),
      );
    });

    test('主題清單無法讀取：映射照常，不發 registryMismatch', () async {
      final r = await _read(
        {_assignments: 'A\tq\n', _registry: 'x\n'},
        denied: {_registry},
      );
      expect(r.ticketTopics, {'A': 'q'});
      expect(r.registryStatus, TopicFileStatus.unreadable);
      expect(r.events.single.path, _registry);
    });
  });
}
