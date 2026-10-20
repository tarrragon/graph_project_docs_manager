// 需求：[SPEC-006 FR-10；0.5.0-W1-119.2] 掃描結果公開本輪的非 domain 路徑
// 清單讀取結果（供 Graph 專案層宣告彙整），不只保留 EVT-CORPUS-005。
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
      )
      as Map<String, dynamic>,
);

Future<CorpusScanResult> _scan(Map<String, String> files) => scanCorpus(
  fileSystem: _MemoryFileSystem(files),
  table: const TypeTable(<String, NodeTypeEntry>{}),
  builtinTable: _builtinTable(),
);

void main() {
  group('掃描結果公開非 domain 路徑清單讀取結果', () {
    test('X1 缺席 → NonDomainPathsReadAbsent', () async {
      final result = await _scan(const {});

      expect(result.nonDomainPathsRead, isA<NonDomainPathsReadAbsent>());
    });

    test('X2 已宣告 → 帶模式清單（E1：與 X1 不同）', () async {
      final result = await _scan(const {
        _listFile: 'non_domain_path_patterns:\n  - docs/a.md\n',
      });

      final read = result.nonDomainPathsRead;
      expect(read, isA<NonDomainPathsReadDeclared>());
      expect(read.declaration.declaredPatterns, ['docs/a.md']);
    });

    test('X3 整份格式錯誤 → Malformed，事件與讀取結果同一份', () async {
      final result = await _scan(const {
        _listFile: 'non_domain_path_patterns: nope\n',
      });

      expect(result.nonDomainPathsRead, isA<NonDomainPathsReadMalformed>());
      expect(
        result.nonDomainPathsParseFailedEvent,
        same(result.nonDomainPathsRead.malformedEvent),
      );
    });

    test('X4 非字串元素 → DeclaredWithBadElements，仍為已宣告', () async {
      final result = await _scan(const {
        _listFile: 'non_domain_path_patterns:\n  - docs/a.md\n  - 1\n',
      });

      final read = result.nonDomainPathsRead;
      expect(read, isA<NonDomainPathsReadDeclaredWithBadElements>());
      expect(read.declaration.declaredPatterns, ['docs/a.md']);
    });
  });
}
