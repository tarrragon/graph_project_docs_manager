// 需求：[SPEC-006 FR-10；UC-02〈ticket 定位的五種狀態與整體未宣告〉；
// EVT-CORPUS-005] Corpus 讀取非 domain 路徑清單檔的三態與格式錯誤。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

/// 只提供 readBytes 的記憶體檔案系統；不在 [files] 內的路徑回報檔案不存在。
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

const _defaultFile = 'docs/non-domain-paths.yaml';

TypeTable _builtinTable() => typeTableFromJson(
  jsonDecode(
        File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
      )
      as Map<String, dynamic>,
);

TypeTable _projectTableWithoutLocation() =>
    const TypeTable(<String, NodeTypeEntry>{});

Future<NonDomainPathsReadResult> _read(Map<String, String> files) =>
    readNonDomainPaths(
      fileSystem: _MemoryFileSystem(files),
      projectTable: _projectTableWithoutLocation(),
      builtinTable: _builtinTable(),
    );

/// Graph 原始碼中不得出現的直讀訊號；回傳命中的訊號清單。
List<String> _graphDirectReadViolations(String source) => [
  for (final signal in const [
    "import 'dart:io'",
    'nonDomainPathsFile',
    'non-domain-paths.yaml',
  ])
    if (source.contains(signal)) signal,
];

void main() {
  group('三態', () {
    test('E1：檔案缺席與顯式空清單讀取結果不同', () async {
      final absent = await _read(const {});
      final empty = await _read(const {
        _defaultFile: 'non_domain_path_patterns: []\n',
      });

      expect(absent.declaration, isA<NonDomainPathsAbsent>());
      expect(absent.declaration.declaredPatterns, isNull);
      expect(empty.declaration, isA<NonDomainPathsDeclared>());
      expect(empty.declaration.declaredPatterns, isEmpty);
      expect(
        absent.declaration.declaredPatterns,
        isNot(equals(empty.declaration.declaredPatterns)),
      );
      expect(absent.malformedEvent, isNull);
      expect(empty.malformedEvent, isNull);
    });

    test('有值時回傳模式清單（保留原順序）', () async {
      final result = await _read(const {
        _defaultFile: 'non_domain_path_patterns:\n  - .claude/\n  - lib/app/\n',
      });

      expect(result.declaration.declaredPatterns, ['.claude/', 'lib/app/']);
      expect(result.malformedEvent, isNull);
    });
  });

  group('格式錯誤（EVT-CORPUS-005）', () {
    test('E2：YAML 語法錯誤發出一筆事件，非 domain 側視為未宣告', () async {
      final result = await _read(const {
        _defaultFile: 'non_domain_path_patterns: [unclosed\n',
      });

      expect(result.declaration, isA<NonDomainPathsMalformed>());
      expect(result.declaration.declaredPatterns, isNull);
      expect(result.malformedEvent, isNotNull);
      expect(result.malformedEvent!.path, _defaultFile);
      expect(
        result.malformedEvent!.reason,
        NonDomainPathsMalformedReason.yamlInvalid,
      );
    });

    test('缺鍵發出 keyMissing', () async {
      final result = await _read(const {_defaultFile: 'other_key: []\n'});

      expect(
        result.malformedEvent?.reason,
        NonDomainPathsMalformedReason.keyMissing,
      );
      expect(result.declaration.declaredPatterns, isNull);
    });

    test('值為字串發出 notList', () async {
      final result = await _read(const {
        _defaultFile: 'non_domain_path_patterns: lib/\n',
      });

      expect(
        result.malformedEvent?.reason,
        NonDomainPathsMalformedReason.notList,
      );
      expect(result.declaration.declaredPatterns, isNull);
    });

    test('檔案不存在不發事件，分類與格式錯誤相同（未宣告）', () async {
      final absent = await _read(const {});
      final malformed = await _read(const {
        _defaultFile: 'non_domain_path_patterns: [unclosed\n',
      });

      expect(absent.malformedEvent, isNull);
      expect(malformed.malformedEvent, isNotNull);
      expect(absent.declaration.declaredPatterns, isNull);
      expect(malformed.declaration.declaredPatterns, isNull);
    });
  });

  group('位置來源（FR-10 規則 1）', () {
    test('專案型別表缺兩欄時依內建表值定位清單檔', () async {
      final fileSystem = _MemoryFileSystem(const {
        _defaultFile: 'non_domain_path_patterns:\n  - tool/\n',
      });

      final result = await readNonDomainPaths(
        fileSystem: fileSystem,
        projectTable: _projectTableWithoutLocation(),
        builtinTable: _builtinTable(),
      );

      expect(fileSystem.readPaths, [_defaultFile]);
      expect(result.declaration.declaredPatterns, ['tool/']);
    });

    test('專案型別表帶兩欄時以專案值為準（對照）', () async {
      final fileSystem = _MemoryFileSystem(const {
        'custom/paths.yaml': 'custom_key:\n  - tool/\n',
        _defaultFile: 'non_domain_path_patterns:\n  - other/\n',
      });
      final projectTable = typeTableFromJson(<String, dynamic>{
        'node_types': <String, dynamic>{},
        'non_domain_paths_file': 'custom/paths.yaml',
        'non_domain_paths_key': 'custom_key',
      });

      final result = await readNonDomainPaths(
        fileSystem: fileSystem,
        projectTable: projectTable,
        builtinTable: _builtinTable(),
      );

      expect(fileSystem.readPaths, ['custom/paths.yaml']);
      expect(result.declaration.declaredPatterns, ['tool/']);
    });
  });

  group('Graph 不直讀非 domain 路徑清單檔（只經 Corpus 公開面）', () {
    test('E2 正向對照：已知違規樣本判為違規', () {
      const violating = """
import 'dart:io';
final f = typeTable.nonDomainPathsFile;
const p = 'non-domain-paths.yaml';
""";
      expect(_graphDirectReadViolations(violating), hasLength(3));
      expect(_graphDirectReadViolations("import 'dart:async';\n"), isEmpty);
    });

    test('掃描到的 lib/graph 檔案數 > 0，且無違規', () {
      final graphSources = Directory('lib/graph')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      expect(graphSources, isNotEmpty);
      for (final file in graphSources) {
        expect(
          _graphDirectReadViolations(file.readAsStringSync()),
          isEmpty,
          reason: file.path,
        );
      }
    });
  });

  group('非字串元素（FR-10 規則 2a）', () {
    Future<NonDomainPathsReadResult> readList(String items) =>
        _read({_defaultFile: 'non_domain_path_patterns: $items\n'});

    test('E1：含 null 時其餘生效、發一筆 elementNotString，與去掉壞元素的對照模式相同', () async {
      final withBad = await readList('["docs/a/", null, "docs/b/"]');
      final clean = await readList('["docs/a/", "docs/b/"]');

      expect(withBad.declaration, isA<NonDomainPathsDeclared>());
      expect(withBad.declaration.declaredPatterns, ['docs/a/', 'docs/b/']);
      expect(withBad.declaration.declaredPatterns, isNot(contains('null')));
      expect(
        withBad.declaration.declaredPatterns,
        clean.declaration.declaredPatterns,
      );
      expect(
        withBad.malformedEvent?.reason,
        NonDomainPathsMalformedReason.elementNotString,
      );
      expect(withBad.malformedEvent?.nonStringElementCount, 1);
      expect(withBad.malformedEvent?.path, _defaultFile);
      expect(clean.malformedEvent, isNull);
    });

    test('兩個壞元素只發一筆，nonStringElementCount 為 2', () async {
      final result = await readList('["docs/a/", 1, true]');

      expect(result.declaration.declaredPatterns, ['docs/a/']);
      expect(
        result.malformedEvent?.reason,
        NonDomainPathsMalformedReason.elementNotString,
      );
      expect(result.malformedEvent?.nonStringElementCount, 2);
    });

    test('全為壞元素時為已宣告的空清單，不視為未宣告', () async {
      final result = await readList('[null, 1]');

      expect(result.declaration, isA<NonDomainPathsDeclared>());
      expect(result.declaration.declaredPatterns, isEmpty);
      expect(result.malformedEvent?.nonStringElementCount, 2);
    });

    test('字串元素不檢查格式：空字串、/ 開頭、glob 照收且不發事件', () async {
      final result = await readList('["", "docs/a/", "/docs/", "docs/*.md"]');

      expect(result.declaration.declaredPatterns, [
        '',
        'docs/a/',
        '/docs/',
        'docs/*.md',
      ]);
      expect(result.malformedEvent, isNull);
    });

    test('三種整份格式錯誤的事件 nonStringElementCount 為 null', () async {
      for (final content in const [
        'non_domain_path_patterns: [\n',
        'other: []\n',
        'non_domain_path_patterns: docs/\n',
      ]) {
        final result = await _read({_defaultFile: content});
        expect(result.declaration, isA<NonDomainPathsMalformed>());
        expect(result.malformedEvent, isNotNull);
        expect(result.malformedEvent?.nonStringElementCount, isNull);
      }
    });
  });

  group('位置欄位空字串（FR-10 規則 1）', () {
    Future<_MemoryFileSystem> readWith(Map<String, dynamic> extra) async {
      final fileSystem = _MemoryFileSystem(const {
        _defaultFile: 'non_domain_path_patterns: [docs/a/]\n',
      });
      await readNonDomainPaths(
        fileSystem: fileSystem,
        projectTable: typeTableFromJson(<String, dynamic>{
          'node_types': <String, dynamic>{},
          ...extra,
        }),
        builtinTable: _builtinTable(),
      );
      return fileSystem;
    }

    test('E2：file 為空字串時依內建表檔名讀取，不以空字串為路徑', () async {
      final fileSystem = await readWith({'non_domain_paths_file': ''});
      final missing = await readWith({});

      expect(fileSystem.readPaths, [_defaultFile]);
      expect(fileSystem.readPaths, isNot(contains('')));
      expect(fileSystem.readPaths, missing.readPaths);
    });

    test('key 為空字串與缺 key 並列比對：結果相同，皆依內建表鍵名取清單', () async {
      Future<NonDomainPathsReadResult> readWithKey(
        Map<String, dynamic> extra,
      ) => readNonDomainPaths(
        fileSystem: _MemoryFileSystem(const {
          _defaultFile: 'non_domain_path_patterns: [docs/a/]\n',
        }),
        projectTable: typeTableFromJson(<String, dynamic>{
          'node_types': <String, dynamic>{},
          ...extra,
        }),
        builtinTable: _builtinTable(),
      );

      final emptyKey = await readWithKey({'non_domain_paths_key': ''});
      final missingKey = await readWithKey({});

      expect(emptyKey.declaration.declaredPatterns, ['docs/a/']);
      expect(emptyKey.malformedEvent, isNull);
      expect(
        emptyKey.declaration.declaredPatterns,
        missingKey.declaration.declaredPatterns,
      );
      expect(emptyKey.malformedEvent, missingKey.malformedEvent);
    });
  });
}
