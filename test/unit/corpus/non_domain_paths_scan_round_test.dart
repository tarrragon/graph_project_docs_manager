// 需求：[SPEC-006 FR-07、FR-08 第三項、FR-10；EVT-CORPUS-005 接進掃描輪次]
// 掃描輪次帶本輪 EVT-CORPUS-005（至多一筆），比照 EVT-CORPUS-003／004。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

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

const _listFile = 'docs/non-domain-paths.yaml';

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
  group('EVT-CORPUS-005 進掃描輪次', () {
    test('E1 同語料清單檔正常與格式錯誤各掃一次，事件數 0 對 1', () async {
      final ok = await _scan(const {
        _listFile: 'non_domain_path_patterns:\n  - docs/a.md\n',
      });
      final bad = await _scan(const {
        _listFile: 'non_domain_path_patterns: nope\n',
      });

      expect(ok.nonDomainPathsParseFailedEvent, isNull);
      expect(ok.summary.nonDomainPathsMalformedCount, 0);
      final event = bad.nonDomainPathsParseFailedEvent;
      expect(event, isNotNull);
      expect(event!.path, _listFile);
      expect(event.reason, NonDomainPathsMalformedReason.notList);
      expect(bad.summary.nonDomainPathsMalformedCount, 1);
    });

    test('清單檔缺席：無事件，計數 0', () async {
      final result = await _scan(const {});

      expect(result.nonDomainPathsParseFailedEvent, isNull);
      expect(result.summary.nonDomainPathsMalformedCount, 0);
    });

    test('elementNotString：一輪至多一筆，帶非字串元素數', () async {
      final result = await _scan(const {
        _listFile: 'non_domain_path_patterns:\n  - docs/a.md\n  - 1\n  - 2\n',
      });

      final event = result.nonDomainPathsParseFailedEvent;
      expect(event!.reason, NonDomainPathsMalformedReason.elementNotString);
      expect(event.nonStringElementCount, 2);
      expect(result.summary.nonDomainPathsMalformedCount, 1);
    });

    test('不依賴 FR-06 路徑查詢：型別表無路徑模式仍發出事件', () async {
      final result = await _scan(const {
        _listFile: 'non_domain_path_patterns: nope\n',
      });

      expect(result.summary.carrierPathQueryAvailable, isFalse);
      expect(result.nonDomainPathsParseFailedEvent, isNotNull);
    });
  });
}
