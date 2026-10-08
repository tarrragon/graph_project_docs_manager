// 需求：[SPEC-006 FR-10 規則 1、3；UC-02〈ticket 定位的五種狀態與整體未宣告〉]
// 非 domain 清單位置欄位空白時回落內建表，並實際定位到內建位置的檔案。
// 路徑從型別表 JSON 起，經 typeTableFromJson 到 readNonDomainPaths，
// 以假檔案系統記錄的 readPaths 判定實際讀到的檔案。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

class _MemoryFileSystem implements DocsFileSystem {
  _MemoryFileSystem(this.files);

  final Map<String, String> files;
  final readPaths = <String>[];

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) async =>
      const <DocsFileSystemEntry>[];

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    readPaths.add(relativePath);
    final content = files[relativePath];
    if (content == null) {
      return const DocsReadFailure(UnreadableReason.fileDeleted);
    }
    return DocsReadSuccess(Uint8List.fromList(utf8.encode(content)));
  }
}

const _builtinFile = 'docs/non-domain-paths.yaml';
const _builtinKey = 'non_domain_path_patterns';

TypeTable _builtinTable() => typeTableFromJson(
  jsonDecode(
        File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

Future<(_MemoryFileSystem, NonDomainPathsReadResult)> _read(
  Map<String, String> files,
  Map<String, dynamic> locationFields,
) async {
  final fileSystem = _MemoryFileSystem(files);
  final result = await readNonDomainPaths(
    fileSystem: fileSystem,
    projectTable: typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      ...locationFields,
    }),
    builtinTable: _builtinTable(),
  );
  return (fileSystem, result);
}

void main() {
  group('非 domain 清單位置回落（消費端）', () {
    test('T1（E2）：file 為空白時讀內建位置的檔案，模式取自內建檔', () async {
      final (fs, result) = await _read(
        const {_builtinFile: '$_builtinKey: [builtin/]\n'},
        const {'non_domain_paths_file': ' '},
      );

      expect(fs.readPaths, ['docs/non-domain-paths.yaml']);
      expect(result.declaration, isA<NonDomainPathsDeclared>());
      expect(result.declaration.declaredPatterns, ['builtin/']);
    });

    test('T2（E2）：key 為 tab 加空白時依內建鍵名取到模式', () async {
      final (fs, result) = await _read(
        const {_builtinFile: '$_builtinKey: [builtin/]\n'},
        const {'non_domain_paths_key': '\t '},
      );

      expect(fs.readPaths, ['docs/non-domain-paths.yaml']);
      expect(result.declaration.declaredPatterns, ['builtin/']);
      expect(result.malformedEvent, isNull);
    });

    test('T3（E1 對照）：file 為合法值時讀該值指向的檔案，模式與 T1 不同', () async {
      const files = {
        _builtinFile: '$_builtinKey: [builtin/]\n',
        'docs/custom.yaml': '$_builtinKey: [custom/]\n',
      };
      final (blankFs, blank) = await _read(files, const {
        'non_domain_paths_file': ' ',
      });
      final (customFs, custom) = await _read(files, const {
        'non_domain_paths_file': 'docs/custom.yaml',
      });

      expect(customFs.readPaths, ['docs/custom.yaml']);
      expect(custom.declaration.declaredPatterns, ['custom/']);
      expect(blankFs.readPaths, ['docs/non-domain-paths.yaml']);
      expect(blank.declaration.declaredPatterns, ['builtin/']);
      expect(
        custom.declaration.declaredPatterns,
        isNot(blank.declaration.declaredPatterns),
      );
    });

    test('T4（規則 3）：前導空白的非空值照原值使用，找不到檔案視為不存在', () async {
      final (fs, result) = await _read(
        const {'docs/x.yaml': '$_builtinKey: [x/]\n'},
        const {'non_domain_paths_file': ' docs/x.yaml'},
      );

      expect(fs.readPaths, [' docs/x.yaml']);
      expect(result.declaration, isA<NonDomainPathsAbsent>());
      expect(result.malformedEvent, isNull);
    });
  });
}
