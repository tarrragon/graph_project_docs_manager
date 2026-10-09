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

/// 任何讀取都拋出非 [DocsReadResult] 契約內的例外。
class _ThrowingFileSystem implements DocsFileSystem {
  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async =>
      const <DocsFileSystemEntry>[];

  @override
  Future<DocsReadResult> readBytes(String relativePath) async =>
      throw StateError('simulated read failure');
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

    test('M1：專案表缺 non_domain_paths_file、內建表有 → 依內建位置讀到事件', () async {
      final builtin = _builtinTable();
      const projectTable = TypeTable(<String, NodeTypeEntry>{});
      expect(projectTable.nonDomainPathsFile, isNull);
      expect(builtin.nonDomainPathsFile, _listFile);
      final files = {_listFile: 'non_domain_path_patterns: nope\n'};

      final withBuiltin = await scanCorpus(
        fileSystem: _MemoryFileSystem(files),
        table: projectTable,
        builtinTable: builtin,
      );
      // 對照：內建表同樣缺位置時讀不到清單檔，證明上一個結果來自內建表。
      final withoutBuiltinLocation = await scanCorpus(
        fileSystem: _MemoryFileSystem(files),
        table: projectTable,
        builtinTable: projectTable,
      );

      expect(withBuiltin.nonDomainPathsParseFailedEvent?.path, _listFile);
      expect(withoutBuiltinLocation.nonDomainPathsParseFailedEvent, isNull);
    });

    test('L2：讀取拋出例外時掃描照常完成、無事件、計數 0', () async {
      final result = await scanCorpus(
        fileSystem: _ThrowingFileSystem(),
        table: const TypeTable(<String, NodeTypeEntry>{}),
        builtinTable: _builtinTable(),
      );

      expect(result.nonDomainPathsParseFailedEvent, isNull);
      expect(result.summary.nonDomainPathsMalformedCount, 0);
      expect(result.summary.totalFilesScanned, 0);
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
