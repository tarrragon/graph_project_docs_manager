import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';

/// 合法 frontmatter 位元組：`id: $id`。
List<int> _validFrontmatter(String id) => utf8.encode('---\nid: $id\n---\n');

/// FR-01 規則 3 違反：第一行不是 `---`。
final List<int> _noFrontmatterBytes = utf8.encode('# title\n');

/// FR-01 規則 4 違反：沒有結尾 `---`。
final List<int> _unclosedBytes = utf8.encode('---\nkey: 1\n');

/// 已閉合、YAML 無語法錯誤，但結果不是非空 map（YAML 清單）。
final List<int> _emptyOrNotMapBytes = utf8.encode('---\n- a\n- b\n---\n');

/// YAML 語法錯誤：未閉合的引號。
final List<int> _yamlSyntaxErrorBytes = utf8.encode(
  '---\nkey: "unterminated\n---\n',
);

/// 無法以 UTF-8 解碼的位元組。
const List<int> _invalidUtf8Bytes = [0x80, 0x81];

/// 一個型別，`carrierPathPatterns` 為 `null`（不參與路徑比對），供 C8/C9
/// 只關心掃描範圍或讀取結果、不需要 carrier 分流的測試使用。
TypeTable _tableWithoutCarrier() =>
    TypeTableBuilder().addType('Alpha', idPattern: r'^A-\d+$').build();

/// 測試專用投影：[ParseOutcome] 為 sealed class，僅 [Unreadable] 帶
/// `reason`。呼叫端已在呼叫處確認結果為無法讀取，此處以型別轉型（非 `!`
/// 或 throw 分支）取出欄位。
UnreadableReason unreadableReasonOf(ParseOutcome outcome) =>
    (outcome as Unreadable).reason;

void main() {
  group('scanCorpus 掃描範圍（SPEC-006-test-design §3.2 C8, FR-02）', () {
    test('C8-1 無 docs/：掃描完成，全部計數 0，無錯誤', () async {
      final fs = FakeDocsFileSystem();

      final result = await scanCorpus(
        fileSystem: fs,
        table: _tableWithoutCarrier(),
      );

      expect(result.rawNodes, isEmpty);
      expect(result.parseErrors, isEmpty);
      expect(result.parseFailureEvents, isEmpty);
      expect(result.summary.totalFilesScanned, 0);
      expect(checkScanSummaryConservation(result.summary), isTrue);
    });

    test('C8-2 docs/a/b/c/x.md 多層：進入結果', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/a/b/c/x.md', _noFrontmatterBytes);

      final result = await scanCorpus(
        fileSystem: fs,
        table: _tableWithoutCarrier(),
      );

      expect(
        result.parseErrors.map((e) => e.path),
        contains('docs/a/b/c/x.md'),
      );
    });

    test(
      'C8-3（守衛）docs/X.MD、根層 README.md、docs/x.txt 不進入；'
      '同目錄 docs/x.md 進入（正向對照）',
      () async {
        final fs = FakeDocsFileSystem()
          ..addFile('docs/X.MD', _noFrontmatterBytes)
          ..addFile('README.md', _noFrontmatterBytes)
          ..addFile('docs/x.txt', _noFrontmatterBytes)
          ..addFile('docs/x.md', _noFrontmatterBytes);

        final result = await scanCorpus(
          fileSystem: fs,
          table: _tableWithoutCarrier(),
        );

        final scannedPaths = result.parseErrors.map((e) => e.path).toSet();
        expect(scannedPaths, {'docs/x.md'});
      },
    );

    test(
      'C8-4（守衛）docs/link 為符號連結目錄：不經連結重複列出，'
      'docs/spec/ 下的檔案只出現一次',
      () async {
        final fs = FakeDocsFileSystem()
          ..addFile('docs/spec/domain-map.md', _noFrontmatterBytes)
          ..addSymlinkDirectory('docs/link');

        final result = await scanCorpus(
          fileSystem: fs,
          table: _tableWithoutCarrier(),
        );

        final matches = result.parseErrors
            .where((e) => e.path == 'docs/spec/domain-map.md')
            .toList();
        expect(matches, hasLength(1));
      },
    );

    test('C8-5 回傳路徑相對於工作區根、以 / 分隔、不含前導 ./', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/a/b/x.md', _noFrontmatterBytes);

      final result = await scanCorpus(
        fileSystem: fs,
        table: _tableWithoutCarrier(),
      );

      final path = result.parseErrors.single.path;
      expect(path, 'docs/a/b/x.md');
      expect(path.startsWith('./'), isFalse);
      expect(path.contains(r'\'), isFalse);
    });

    test(
      'C8-6 工作區根取自注入的 DocsFileSystem（fake Workspace 提供），'
      '不自行推導：兩個獨立的 fake 各自獨立產生對應結果',
      () async {
        final workspaceA = FakeDocsFileSystem()
          ..addFile('docs/a.md', _noFrontmatterBytes);
        final workspaceB = FakeDocsFileSystem();

        final resultA = await scanCorpus(
          fileSystem: workspaceA,
          table: _tableWithoutCarrier(),
        );
        final resultB = await scanCorpus(
          fileSystem: workspaceB,
          table: _tableWithoutCarrier(),
        );

        expect(resultA.summary.totalFilesScanned, 1);
        expect(resultB.summary.totalFilesScanned, 0);
      },
    );
  });

  group('scanCorpus 讀取失敗（SPEC-006-test-design §3.2 C9, FR-05）', () {
    TypeTable tableWithCarrier() => TypeTableBuilder()
        .addType(
          'CarrierType',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .build();

    test('C9-1 carrier 內非 UTF-8：無法讀取／編碼；發事件；成為破洞', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/carrier/bad.md', _invalidUtf8Bytes);

      final result = await scanCorpus(
        fileSystem: fs,
        table: tableWithCarrier(),
      );

      final error = result.parseErrors.single;
      expect(error.outcome.kind, ParseResultKind.unreadable);
      expect(unreadableReasonOf(error.outcome), UnreadableReason.encoding);
      expect(result.parseFailureEvents, hasLength(1));
    });

    test('C9-2 carrier 外非 UTF-8：記入 parseErrors，不發事件，掃描完成', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/other/bad.md', _invalidUtf8Bytes);

      final result = await scanCorpus(
        fileSystem: fs,
        table: tableWithCarrier(),
      );

      expect(result.parseErrors, hasLength(1));
      expect(
        unreadableReasonOf(result.parseErrors.single.outcome),
        UnreadableReason.encoding,
      );
      expect(result.parseFailureEvents, isEmpty);
    });

    test('C9-3 carrier 內權限拒絕：無法讀取／權限', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/carrier/denied.md', _validFrontmatter('A-1'))
        ..denyReadPermission('docs/carrier/denied.md');

      final result = await scanCorpus(
        fileSystem: fs,
        table: tableWithCarrier(),
      );

      final error = result.parseErrors.single;
      expect(error.outcome.kind, ParseResultKind.unreadable);
      expect(unreadableReasonOf(error.outcome), UnreadableReason.permission);
    });

    test('C9-4 列出後、讀取前消失：無法讀取／檔案消失；掃描完成', () async {
      final fs = FakeDocsFileSystem()
        ..addFile('docs/carrier/gone.md', _validFrontmatter('A-1'))
        ..markDisappearedAfterListing('docs/carrier/gone.md');

      final result = await scanCorpus(
        fileSystem: fs,
        table: tableWithCarrier(),
      );

      final error = result.parseErrors.single;
      expect(error.outcome.kind, ParseResultKind.unreadable);
      expect(unreadableReasonOf(error.outcome), UnreadableReason.fileDeleted);
    });
  });

  group('scanCorpus 計數與守恆（SPEC-006-test-design §3.2 C10, FR-07）', () {
    /// C10-1 分布：節點 1、非節點 1、五種失敗原因各 1（noFrontmatter 命中
    /// 一型、unclosed 平手、emptyOrNotMap 未命中、yamlSyntaxError 命中一型、
    /// unreadable 未命中）。
    TypeTable distributionTable() => TypeTableBuilder()
        .addType('Alpha', idPattern: r'^A-\d+$')
        .addType(
          'CarrierType',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .addType(
          'TieTypeA',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/tie/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .addType(
          'TieTypeB',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/tie/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .build();

    FakeDocsFileSystem distributionFixture() => FakeDocsFileSystem()
      ..addFile('docs/node.md', _validFrontmatter('A-1'))
      ..addFile('docs/nonnode.md', utf8.encode('---\ntitle: 無 id\n---\n'))
      ..addFile('docs/carrier/nofm.md', _noFrontmatterBytes)
      ..addFile('docs/tie/unclosed.md', _unclosedBytes)
      ..addFile('docs/other/empty.md', _emptyOrNotMapBytes)
      ..addFile('docs/carrier/badyaml.md', _yamlSyntaxErrorBytes)
      ..addFile('docs/other/unreadable.md', _invalidUtf8Bytes);

    test('C10-1 各計數項等於已知值，兩條守恆式成立', () async {
      final result = await scanCorpus(
        fileSystem: distributionFixture(),
        table: distributionTable(),
      );
      final summary = result.summary;

      expect(summary.totalFilesScanned, 7);
      expect(summary.nodeCount, 1);
      expect(summary.nonNodeWithFrontmatterCount, 1);
      expect(
        summary.failureReasonCounts[ParseResultKind.noFrontmatter],
        1,
      );
      expect(summary.failureReasonCounts[ParseResultKind.unclosed], 1);
      expect(
        summary.failureReasonCounts[ParseResultKind.emptyOrNotMap],
        1,
      );
      expect(
        summary.failureReasonCounts[ParseResultKind.yamlSyntaxError],
        1,
      );
      expect(summary.failureReasonCounts[ParseResultKind.unreadable], 1);
      expect(summary.hitCarrierCount, 3);
      expect(summary.noHitCount, 2);
      expect(summary.undeterminedCount, 0);
      expect(checkScanSummaryConservation(summary), isTrue);
    });

    test('C10-2 平手的失敗檔：計入命中 carrier 數', () async {
      final result = await scanCorpus(
        fileSystem: distributionFixture(),
        table: distributionTable(),
      );

      final tieEvent = result.parseFailureEvents.singleWhere(
        (e) => e.path == 'docs/tie/unclosed.md',
      );
      expect(tieEvent.schemaAmbiguous, isTrue);
      // 命中 carrier 數（3）包含這筆平手事件，非額外獨立計數（FR-07 附註）。
      expect(result.summary.hitCarrierCount, 3);
    });

    test('C10-3 查詢不可用的型別表跑 C10-1 fixture：失敗檔全部計入未判定，'
        '第二條守恆式仍成立，命中與未命中為 0', () async {
      final unavailableTable = TypeTableBuilder()
          .addType('Alpha', idPattern: r'^A-\d+$')
          .build();

      final result = await scanCorpus(
        fileSystem: distributionFixture(),
        table: unavailableTable,
      );
      final summary = result.summary;

      expect(summary.carrierPathQueryAvailable, isFalse);
      expect(summary.hitCarrierCount, 0);
      expect(summary.noHitCount, 0);
      expect(summary.undeterminedCount, 5);
      expect(result.parseFailureEvents, isEmpty);
      expect(checkScanSummaryConservation(summary), isTrue);
    });

    test('C10-4（守衛）守恆檢查器：刻意少算一檔的計數回報失敗', () {
      const brokenSummary = ScanSummary(
        totalFilesScanned: 6, // 正確值應為 7（1+1+5）
        nodeCount: 1,
        nonNodeWithFrontmatterCount: 1,
        failureReasonCounts: {
          ParseResultKind.noFrontmatter: 1,
          ParseResultKind.unclosed: 1,
          ParseResultKind.emptyOrNotMap: 1,
          ParseResultKind.yamlSyntaxError: 1,
          ParseResultKind.unreadable: 1,
        },
        hitCarrierCount: 3,
        noHitCount: 2,
        undeterminedCount: 0,
        carrierPathQueryAvailable: true,
      );

      expect(checkScanSummaryConservation(brokenSummary), isFalse);

      // 正向對照：totalFilesScanned 改為正確值 7 時應成立。
      const fixedSummary = ScanSummary(
        totalFilesScanned: 7,
        nodeCount: 1,
        nonNodeWithFrontmatterCount: 1,
        failureReasonCounts: {
          ParseResultKind.noFrontmatter: 1,
          ParseResultKind.unclosed: 1,
          ParseResultKind.emptyOrNotMap: 1,
          ParseResultKind.yamlSyntaxError: 1,
          ParseResultKind.unreadable: 1,
        },
        hitCarrierCount: 3,
        noHitCount: 2,
        undeterminedCount: 0,
        carrierPathQueryAvailable: true,
      );
      expect(checkScanSummaryConservation(fixedSummary), isTrue);
    });

    test(
      'C10-5 EVT-CORPUS-001 rawNodes：每筆帶完整 frontmatter map、'
      '相對路徑、判定型別；不含邊',
      () async {
        final fs = FakeDocsFileSystem()
          ..addFile(
            'docs/node.md',
            utf8.encode('---\nid: A-1\nextra: value\n---\n'),
          );
        final table = TypeTableBuilder()
            .addType('Alpha', idPattern: r'^A-\d+$')
            .build();

        final result = await scanCorpus(fileSystem: fs, table: table);

        final node = result.rawNodes.single;
        expect(node.path, 'docs/node.md');
        expect(node.typeName, 'Alpha');
        expect(node.frontmatter, {'id': 'A-1', 'extra': 'value'});
      },
    );
  });

  group('scanCorpus FR-03 歧義檔案（0.3.0-W3-534）', () {
    test(
      '互斥被打破的可用檔案：以路徑與候選型別出現在 schemaAmbiguousNodes，'
      '並仍計入 nonNodeWithFrontmatterCount（先前只計數，歧義檔案本身不可追溯）',
      () async {
        final ambiguousTable = TypeTableBuilder()
            .addType('Alpha', idPattern: r'^X-\d+$')
            .addType('Beta', idPattern: r'^X-\d+$')
            .build();
        final fs = FakeDocsFileSystem()
          ..addFile('docs/ambiguous.md', _validFrontmatter('X-1'));

        final result = await scanCorpus(fileSystem: fs, table: ambiguousTable);

        expect(result.schemaAmbiguousNodes, hasLength(1));
        final node = result.schemaAmbiguousNodes.single;
        expect(node.path, 'docs/ambiguous.md');
        expect(node.candidateTypes, ['Alpha', 'Beta']);
        expect(result.summary.nonNodeWithFrontmatterCount, 1);
        expect(result.rawNodes, isEmpty);
      },
    );

    test('正向對照：只留一型時同一個 id 判為節點，不進入歧義清單', () async {
      final singleTable = TypeTableBuilder()
          .addType('Alpha', idPattern: r'^X-\d+$')
          .build();
      final fs = FakeDocsFileSystem()
        ..addFile('docs/single.md', _validFrontmatter('X-1'));

      final result = await scanCorpus(fileSystem: fs, table: singleTable);

      expect(result.schemaAmbiguousNodes, isEmpty);
      expect(result.rawNodes, hasLength(1));
    });
  });

  group('scanCorpus carrier 查詢單次呼叫（0.3.0-W3-534）', () {
    TypeTable tableWithCarrier() => TypeTableBuilder()
        .addType(
          'CarrierType',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .build();

    test(
      '每個失敗檔只呼叫一次 lookupCarrierPath：命中 carrier（組裝事件）與'
      '未命中 carrier 各只查一次，不因後續組裝事件而重查',
      () async {
        var callCount = 0;
        CarrierPathLookupResult countingLookup(TypeTable table, String path) {
          callCount++;
          return lookupCarrierPathType(table, path);
        }

        final fs = FakeDocsFileSystem()
          ..addFile('docs/carrier/hit.md', _noFrontmatterBytes)
          ..addFile('docs/other/miss.md', _noFrontmatterBytes);

        final result = await scanCorpus(
          fileSystem: fs,
          table: tableWithCarrier(),
          lookupCarrierPath: countingLookup,
        );

        expect(callCount, 2);
        expect(result.parseFailureEvents, hasLength(1));
      },
    );
  });

  group('scanCorpus 失敗隔離（SPEC-006-test-design §3.2 C11, NFR-01）', () {
    TypeTable table() => TypeTableBuilder()
        .addType('Alpha', idPattern: r'^A-\d+$')
        .addType(
          'CarrierType',
          carrierPathPatterns: [
            PathPatternSpec(pattern: r'^docs/carrier/.*\.md$', specificity: [
              2,
              0,
            ]),
          ],
        )
        .build();

    FakeDocsFileSystem baselineFixture() => FakeDocsFileSystem()
      ..addFile('docs/one.md', _validFrontmatter('A-1'))
      ..addFile('docs/two.md', _validFrontmatter('A-2'));

    Map<String, ParseResultKind> resultByPath(CorpusScanResult r) => {
      for (final n in r.rawNodes) n.path: ParseResultKind.available,
      for (final e in r.parseErrors) e.path: e.outcome.kind,
    };

    test('C11-1 基準 fixture 一輪結果 R0（基準）', () async {
      final r0 = await scanCorpus(fileSystem: baselineFixture(), table: table());

      expect(r0.rawNodes, hasLength(2));
    });

    test(
      'C11-2 另插入每種單檔失敗各一：原有檔案結果與 R0 逐項相同，'
      '新增檔各得對應結果',
      () async {
        final r0 = await scanCorpus(
          fileSystem: baselineFixture(),
          table: table(),
        );
        final r0Results = resultByPath(r0);

        final fs = baselineFixture()
          ..addFile('docs/carrier/enc.md', _invalidUtf8Bytes)
          ..addFile('docs/carrier/unc.md', _unclosedBytes)
          ..addFile('docs/carrier/empty.md', _emptyOrNotMapBytes)
          ..addFile('docs/carrier/yamlerr.md', _yamlSyntaxErrorBytes)
          ..addFile('docs/carrier/perm.md', _validFrontmatter('A-3'))
          ..denyReadPermission('docs/carrier/perm.md')
          ..addFile('docs/carrier/gone.md', _validFrontmatter('A-4'))
          ..markDisappearedAfterListing('docs/carrier/gone.md');

        final result = await scanCorpus(fileSystem: fs, table: table());
        final results = resultByPath(result);

        for (final entry in r0Results.entries) {
          expect(results[entry.key], entry.value, reason: entry.key);
        }
        expect(results['docs/carrier/enc.md'], ParseResultKind.unreadable);
        expect(results['docs/carrier/unc.md'], ParseResultKind.unclosed);
        expect(
          results['docs/carrier/empty.md'],
          ParseResultKind.emptyOrNotMap,
        );
        expect(
          results['docs/carrier/yamlerr.md'],
          ParseResultKind.yamlSyntaxError,
        );
        expect(results['docs/carrier/perm.md'], ParseResultKind.unreadable);
        expect(results['docs/carrier/gone.md'], ParseResultKind.unreadable);
      },
    );

    test('C11-3 失敗檔排在列舉順序最前與最後兩種排列：結果相同', () async {
      final fsFirst = FakeDocsFileSystem()
        ..addFile('docs/carrier/bad.md', _invalidUtf8Bytes)
        ..addFile('docs/one.md', _validFrontmatter('A-1'))
        ..addFile('docs/two.md', _validFrontmatter('A-2'));

      final fsLast = FakeDocsFileSystem()
        ..addFile('docs/one.md', _validFrontmatter('A-1'))
        ..addFile('docs/two.md', _validFrontmatter('A-2'))
        ..addFile('docs/carrier/bad.md', _invalidUtf8Bytes);

      final resultFirst = await scanCorpus(
        fileSystem: fsFirst,
        table: table(),
      );
      final resultLast = await scanCorpus(fileSystem: fsLast, table: table());

      expect(resultByPath(resultFirst), resultByPath(resultLast));
    });

    test(
      'C11-4（E1 鑑別）以會拋非預期例外的 fake 讀取插入一檔：'
      '該檔歸入無法讀取，其他檔案結果與 R0 相同，不是整輪中止',
      () async {
        final r0 = await scanCorpus(
          fileSystem: baselineFixture(),
          table: table(),
        );
        final r0Results = resultByPath(r0);

        final throwing = _ThrowingDocsFileSystem(
          delegate: baselineFixture()
            ..addFile('docs/carrier/throws.md', _validFrontmatter('A-9')),
          throwOnReadPath: 'docs/carrier/throws.md',
        );

        final result = await scanCorpus(fileSystem: throwing, table: table());
        final results = resultByPath(result);

        for (final entry in r0Results.entries) {
          expect(results[entry.key], entry.value, reason: entry.key);
        }
        expect(
          results['docs/carrier/throws.md'],
          ParseResultKind.unreadable,
        );
      },
    );
  });
}

/// C11-4 專用：包裝一個 [DocsFileSystem]，讀取 [throwOnReadPath] 時拋出一個
/// 非 [DocsReadResult] 契約內的非預期例外型別（[StateError]），驗證
/// [scanCorpus] 不因此整輪中止（NFR-01 最後一道防線）。
class _ThrowingDocsFileSystem implements DocsFileSystem {
  _ThrowingDocsFileSystem({required this.delegate, required this.throwOnReadPath});

  final DocsFileSystem delegate;
  final String throwOnReadPath;

  @override
  Future<List<DocsFileSystemEntry>> listEntries(String relativePath) =>
      delegate.listEntries(relativePath);

  @override
  Future<DocsReadResult> readBytes(String relativePath) {
    if (relativePath == throwOnReadPath) {
      throw StateError('非預期例外（C11-4 測試用）');
    }
    return delegate.readBytes(relativePath);
  }
}
