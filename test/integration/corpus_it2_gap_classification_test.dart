/// IT-2 整合測試：依凍結 manifest 在暫存目錄實體化檔案樹，經
/// [scanCorpus]／[detectParseFailureGaps] 端到端分類，逐列與凍結的
/// 獨立參照實作輸出比對，需求：[SPEC-006 FR-01、FR-05、FR-06、FR-08；
/// SPEC-006 D3；test-design §2.2 IT2-A1～IT2-A6]。
///
/// 測資：`test/fixtures/spec006/it2/manifest.json`（凍結，7472 列，見同
/// 目錄 `test/fixtures/spec006/README.md`）。manifest `path` 欄帶
/// `<專案>/<相對路徑>` 前綴（`synthetic` 專案除外，本身已是 `docs/...`），
/// 每個專案需要獨立工作區根才能各自只掃該專案的 `docs/`（[scanCorpus]
/// 一次只掃一個綁定工作區）；本檔依 `project` 分組、各自實體化與掃描，
/// 再以專案前綴回組出與 manifest `path` 一致的鍵集合做逐列比對。
///
/// manifest 未保留真實 `id`（`shape: usable` 且 `node` 的 6174 列，見
/// `manifest_materializer.dart` `kSyntheticNodeIds`）。0.3.0-W3-530 已在
/// `_synthetic_it2_rows()` 補第 6 筆合成列，涵蓋 test-design §2.2〈樣本
/// 覆蓋〉表列的「多型別命中、具體度可分出者」失敗檔類別（
/// `docs/spec/<d>/domain-map.md` 無 frontmatter 同時命中 DomainBundle 與
/// SPEC、以具體度分出 DomainBundle 的案例）；本檔 [_missingCoverageCategories]
/// 七類自此齊全，見 IT2-A5。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../helpers/spec006/manifest_materializer.dart';

/// `EVT-CORPUS-003` 的 `reason` 文字（`lib/corpus/parse_failure_event_builder.dart`
/// `parseOutcomeReasonText`）與 manifest `shape`／`expected.reason` 詞彙的
/// 對照，兩邊詞彙表刻意分離維護——manifest 用 FR-01/FR-05 英文列舉詞彙，
/// 事件負載用中文顯示文字，本表是測試專屬的橋接，不改動任一邊的權威定義。
const _reasonTextByShape = <String, String>{
  'no_frontmatter': '無 frontmatter',
  'unclosed': 'frontmatter 未閉合',
  'empty_or_non_map': 'frontmatter 為空或非 map',
  'yaml_error': 'YAML 語法錯誤',
  'unreadable_encoding': '無法讀取（編碼）',
};

/// 一個專案工作區的掃描結果，路徑鍵已回組為與 manifest `path` 一致的
/// 完整鍵（含專案前綴；`synthetic` 專案本身已是完整鍵）。
class _ProjectScanOutcome {
  _ProjectScanOutcome({
    required this.summary,
    required this.nodeTypeByPath,
    required this.gapByPath,
    required this.unmatchedFailurePaths,
  });

  final ScanSummary summary;
  final Map<String, String> nodeTypeByPath;
  final Map<String, ParseFailureGap> gapByPath;
  final Set<String> unmatchedFailurePaths;
}

Future<_ProjectScanOutcome> _scanProject({
  required String project,
  required List<ManifestRow> rows,
  required Directory workspaceRoot,
  required TypeTable table,
}) async {
  await materializeManifestRows(rows: rows, workspaceRoot: workspaceRoot);

  final fileSystem = DefaultDocsFileSystem(workspaceRoot.path);
  final result = await scanCorpus(fileSystem: fileSystem, table: table);
  // 兩種原因碼（專案版本高於內建／無路徑模式）的映射屬編排層職責
  // （0.1.0-W1-025），Diagnostics 不 import Schema。本輪各專案掃描恆用
  // 可路徑查詢的型別表（IT2-A6 另建不可用型別表獨立測試，見下方），
  // 查詢不可用時暫依 [ScanSummary.carrierPathQueryAvailable] 直接映射為
  // 「無路徑模式」。
  final gapResult = detectParseFailureGaps(
    events: result.parseFailureEvents,
    undeterminedCount: result.summary.undeterminedCount,
    unavailableReason: result.summary.carrierPathQueryAvailable
        ? null
        : UndeterminedGapReason.noPathPattern,
  );
  final gaps = switch (gapResult) {
    GapsDetected(gaps: final g) => g,
    Undetermined() => const <ParseFailureGap>[],
  };

  String fullPath(String relative) =>
      project == 'synthetic' ? relative : '$project/$relative';

  final nodeTypeByPath = <String, String>{
    for (final node in result.rawNodes) fullPath(node.path): node.typeName,
  };

  final gapByPath = <String, ParseFailureGap>{
    for (final gap in gaps) fullPath(gap.path): gap,
  };

  final unmatchedFailurePaths = <String>{
    for (final error in result.parseErrors)
      if (!gapByPath.containsKey(fullPath(error.path))) fullPath(error.path),
  };

  return _ProjectScanOutcome(
    summary: result.summary,
    nodeTypeByPath: nodeTypeByPath,
    gapByPath: gapByPath,
    unmatchedFailurePaths: unmatchedFailurePaths,
  );
}

/// 測試專屬合成型別，只用於 IT-2 平手／id_pattern 互斥 fixture，不代表
/// test-design §2.2〈樣本覆蓋〉表要求「每個具路徑模式的型別各 1 列可用
/// 判為節點」的涵蓋對象（見 `header.type_table_note`）。
const _testOnlySyntheticTypeNames = {'SyntheticTie', 'ClashB'};

/// test-design §2.2〈樣本覆蓋〉七類逐一判定 [rows] 是否至少涵蓋，回傳
/// 缺漏類別的中文標籤集合（空集合代表全數涵蓋）。
Set<String> _missingCoverageCategories(List<ManifestRow> rows, TypeTable table) {
  final missing = <String>{};

  const failureShapes = {
    'unclosed': ManifestRowShape.unclosed,
    'no_frontmatter': ManifestRowShape.noFrontmatter,
    'empty_or_non_map': ManifestRowShape.emptyOrNonMap,
    'yaml_error': ManifestRowShape.yamlError,
    'unreadable_encoding': ManifestRowShape.unreadableEncoding,
  };
  for (final entry in failureShapes.entries) {
    final hasHitCarrier = rows.any(
      (r) => r.shape == entry.value && r.expected.kind == 'gap',
    );
    if (!hasHitCarrier) {
      missing.add('命中 carrier 一型的失敗檔：${entry.key}');
    }
  }

  final unmatchedCount = rows
      .where((r) => r.expected.kind == 'failure_unmatched')
      .length;
  if (unmatchedCount < 2) {
    missing.add('未命中的失敗檔（至少 2 列）');
  }

  final hasTie = rows.any(
    (r) => r.expected.kind == 'gap' && r.expected.schemaAmbiguous,
  );
  if (!hasTie) {
    missing.add('多型別衝突（平手）的失敗檔');
  }

  final hasSpecificityResolved = rows.any((row) {
    if (row.expected.kind != 'gap' || row.expected.schemaAmbiguous) {
      return false;
    }
    final hitTypes = table.pathParticipatingTypes.where(
      (entry) => (entry.carrierPathPatterns ?? const <CarrierPathPattern>[])
          .any((pattern) => pattern.toRegExp().hasMatch(row.relativePath)),
    );
    return hitTypes.length > 1;
  });
  if (!hasSpecificityResolved) {
    missing.add('多型別命中、具體度可分出者的失敗檔');
  }

  final hasCarrierUnreadable = rows.any(
    (r) =>
        r.shape == ManifestRowShape.unreadableEncoding &&
        r.expected.kind == 'gap',
  );
  if (!hasCarrierUnreadable) {
    missing.add('無法讀取（編碼）：carrier 內');
  }
  final hasNonCarrierUnreadable = rows.any(
    (r) =>
        r.shape == ManifestRowShape.unreadableEncoding &&
        r.expected.kind == 'failure_unmatched',
  );
  if (!hasNonCarrierUnreadable) {
    missing.add('無法讀取（編碼）：carrier 外');
  }

  final pathParticipatingTypeNames = table.pathParticipatingTypes
      .map((entry) => entry.name)
      .where((name) => !_testOnlySyntheticTypeNames.contains(name));
  for (final typeName in pathParticipatingTypeNames) {
    final hasNode = rows.any(
      (r) => r.expected.kind == 'node' && r.expected.nodeType == typeName,
    );
    if (!hasNode) {
      missing.add('可用且判為節點：$typeName');
    }
  }

  final nonNodeCount = rows.where((r) => r.expected.kind == 'non_node').length;
  if (nonNodeCount < 2) {
    missing.add('可用但非節點（至少 2 列）');
  }

  return missing;
}

void main() {
  late Manifest manifest;
  late TypeTable typeTable;
  late Directory tempRoot;

  late Map<String, String> nodeTypeByPath;
  late Map<String, ParseFailureGap> gapByPath;
  late Set<String> unmatchedFailurePaths;

  late int totalFilesScanned;
  late int totalNodeCount;
  late int totalNonNodeCount;
  late Map<ParseResultKind, int> totalFailureReasonCounts;
  late int totalHitCarrierCount;
  late int totalNoHitCount;
  late int totalUndeterminedCount;

  setUpAll(() async {
    manifest = Manifest.load('test/fixtures/spec006/it2/manifest.json');
    typeTable = typeTableFromJson({
      'node_types': manifest.header['type_table'],
      'completeness_fields': const <String, dynamic>{},
    });

    tempRoot = Directory.systemTemp.createTempSync('spec006_it2_');
    addTearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    nodeTypeByPath = {};
    gapByPath = {};
    unmatchedFailurePaths = {};
    totalFilesScanned = 0;
    totalNodeCount = 0;
    totalNonNodeCount = 0;
    totalFailureReasonCounts = {};
    totalHitCarrierCount = 0;
    totalNoHitCount = 0;
    totalUndeterminedCount = 0;

    for (final entry in manifest.rowsByProject.entries) {
      final project = entry.key;
      final rows = entry.value;
      final workspaceRoot = Directory('${tempRoot.path}/$project');
      await workspaceRoot.create(recursive: true);

      final outcome = await _scanProject(
        project: project,
        rows: rows,
        workspaceRoot: workspaceRoot,
        table: typeTable,
      );

      nodeTypeByPath.addAll(outcome.nodeTypeByPath);
      gapByPath.addAll(outcome.gapByPath);
      unmatchedFailurePaths.addAll(outcome.unmatchedFailurePaths);

      totalFilesScanned += outcome.summary.totalFilesScanned;
      totalNodeCount += outcome.summary.nodeCount;
      totalNonNodeCount += outcome.summary.nonNodeWithFrontmatterCount;
      for (final e in outcome.summary.failureReasonCounts.entries) {
        totalFailureReasonCounts.update(
          e.key,
          (v) => v + e.value,
          ifAbsent: () => e.value,
        );
      }
      totalHitCarrierCount += outcome.summary.hitCarrierCount;
      totalNoHitCount += outcome.summary.noHitCount;
      totalUndeterminedCount += outcome.summary.undeterminedCount;
    }
  });

  group('IT2-A1 逐列分類等於 expected', () {
    test('全部列的實際分類與 manifest expected 一致', () {
      for (final row in manifest.rows) {
        final kind = row.expected.kind;
        if (kind == 'node') {
          expect(
            nodeTypeByPath[row.path],
            row.expected.nodeType,
            reason: '${row.path} 節點型別不符',
          );
        } else if (kind == 'non_node') {
          expect(
            nodeTypeByPath.containsKey(row.path),
            isFalse,
            reason: '${row.path} 不應被判為節點',
          );
          expect(
            gapByPath.containsKey(row.path),
            isFalse,
            reason: '${row.path} 不應產生破洞',
          );
        } else if (kind == 'gap') {
          final gap = gapByPath[row.path];
          expect(gap, isNotNull, reason: '${row.path} 應產生破洞');
          expect(
            gap!.nodeType,
            row.expected.nodeType,
            reason: '${row.path} 破洞歸屬型別不符',
          );
          expect(
            gap.schemaAmbiguous,
            row.expected.schemaAmbiguous,
            reason: '${row.path} 歧義標記不符',
          );
          // manifest 慣例：`candidate_types` 只在平手（schema_ambiguous）
          // 時才列出候選；單一命中時為空清單（見上方 fixture 樣本），
          // 此時已由 [nodeType] 斷言涵蓋，不重複比對 candidateTypes。
          if (row.expected.schemaAmbiguous) {
            expect(
              gap.candidateTypes.toSet(),
              row.expected.candidateTypes.toSet(),
              reason: '${row.path} 候選型別不符',
            );
          }
          expect(
            gap.reason,
            _reasonTextByShape[row.expected.reason],
            reason: '${row.path} 原因不符',
          );
        } else if (kind == 'failure_unmatched') {
          expect(
            unmatchedFailurePaths.contains(row.path),
            isTrue,
            reason: '${row.path} 應為未命中失敗',
          );
          expect(
            gapByPath.containsKey(row.path),
            isFalse,
            reason: '${row.path} 不應產生破洞',
          );
        } else {
          fail('未知的 expected.kind: $kind（${row.path}）');
        }
      }
    });
  });

  group('IT2-A2 破洞集合與 gap 列一一對應', () {
    test('破洞路徑集合等於 manifest gap 列路徑集合，無多出或缺少', () {
      final expectedGapPaths = manifest.rows
          .where((r) => r.expected.kind == 'gap')
          .map((r) => r.path)
          .toSet();

      expect(gapByPath.keys.toSet(), expectedGapPaths);
    });
  });

  group('IT2-A3 FR-07 計數與守恆式', () {
    test('計數等於 manifest 檔頭 expected_counts', () {
      final expectedCounts =
          manifest.header['expected_counts'] as Map<String, dynamic>;
      final expectedFailureReasonCounts =
          expectedCounts['failure_reason_counts'] as Map<String, dynamic>;

      expect(totalFilesScanned, expectedCounts['total_files']);
      expect(totalNodeCount, expectedCounts['node_count']);
      expect(totalNonNodeCount, expectedCounts['non_node_count']);
      expect(
        totalFailureReasonCounts[ParseResultKind.noFrontmatter] ?? 0,
        expectedFailureReasonCounts['no_frontmatter'],
      );
      expect(
        totalFailureReasonCounts[ParseResultKind.yamlSyntaxError] ?? 0,
        expectedFailureReasonCounts['yaml_error'],
      );
      expect(
        totalFailureReasonCounts[ParseResultKind.unreadable] ?? 0,
        expectedFailureReasonCounts['unreadable_encoding'],
      );
      expect(
        totalFailureReasonCounts[ParseResultKind.unclosed] ?? 0,
        expectedFailureReasonCounts['unclosed'],
      );
      expect(
        totalFailureReasonCounts[ParseResultKind.emptyOrNotMap] ?? 0,
        expectedFailureReasonCounts['empty_or_non_map'],
      );
      expect(totalHitCarrierCount, expectedCounts['gap_count']);
      expect(totalNoHitCount, expectedCounts['unmatched_count']);
      expect(totalUndeterminedCount, expectedCounts['unjudged_count']);
    });

    test('兩條守恆式成立', () {
      final totalFailureCount = totalFailureReasonCounts.values.fold(
        0,
        (sum, count) => sum + count,
      );

      expect(
        totalFilesScanned,
        totalNodeCount + totalNonNodeCount + totalFailureCount,
        reason: '守恆式 1 不成立',
      );
      expect(
        totalFailureCount,
        totalHitCarrierCount + totalNoHitCount + totalUndeterminedCount,
        reason: '守恆式 2 不成立',
      );
    });
  });

  group('IT2-A4 實體化器對未知 shape 拒絕（守衛，E2）', () {
    Map<String, dynamic> rowJson(String shape) => {
      'path': 'docs/unknown.md',
      'project': 'synthetic',
      'shape': shape,
      'id': null,
      'expected': {
        'kind': 'gap',
        'node_type': 'Ticket',
        'candidate_types': <String>[],
        'schema_ambiguous': false,
        'reason': shape,
      },
      'synthetic': true,
    };

    test('未知 shape 值拒絕而非略過', () {
      expect(
        () => ManifestRow.fromJson(rowJson('not_a_real_shape')),
        throwsArgumentError,
      );
    });

    test('正向對照：已知 shape 值可正常解析', () {
      expect(
        () => ManifestRow.fromJson(rowJson('no_frontmatter')),
        returnsNormally,
      );
    });
  });

  group('IT2-A5 manifest 覆蓋檢查（守衛，E2）', () {
    test('七類齊全；0.3.0-W3-530 已補「多型別命中、具體度可分出者」合成列', () {
      final missing = _missingCoverageCategories(manifest.rows, typeTable);

      // 0.3.0-W3-530：manifest 新增第 6 筆合成列
      // `docs/spec/synthetic-domain/domain-map.md`（無 frontmatter，同時
      // 命中 DomainBundle [3,0] 與 SPEC [2,0]，依具體度歸 DomainBundle，
      // 非平手）。test-design §2.2〈樣本覆蓋〉七類自此齊全。
      expect(missing, isEmpty);
    });

    test('正向對照：移除平手列與具體度分出列後，覆蓋檢查回報缺漏（含新缺口）', () {
      // 0.3.0-W3-530：具體度分出列（gap、schema_ambiguous=false、命中路徑
      // 多型別）與平手列（gap、schema_ambiguous=true）分屬不同缺口類別，
      // 須一併移除才能同時觸發兩者缺漏。
      final withoutTieOrSpecificity = manifest.rows.where((r) {
        if (r.expected.kind != 'gap') return true;
        if (r.expected.schemaAmbiguous) return false;
        final hitTypes = typeTable.pathParticipatingTypes.where(
          (entry) => (entry.carrierPathPatterns ?? const <CarrierPathPattern>[])
              .any((pattern) => pattern.toRegExp().hasMatch(r.relativePath)),
        );
        return hitTypes.length <= 1;
      }).toList();

      final missing = _missingCoverageCategories(
        withoutTieOrSpecificity,
        typeTable,
      );

      expect(
        missing,
        containsAll({
          '多型別衝突（平手）的失敗檔',
          '多型別命中、具體度可分出者的失敗檔',
        }),
      );
    });
  });

  group('IT2-A6 路徑模式取不到的型別表（鑑別對照，E1）', () {
    test('同一實體化樹再掃一次：破洞為 0、失敗檔全計入未判定、回報無法判定', () async {
      final syntheticRows = manifest.rowsByProject['synthetic']!;
      final unavailableWorkspace = Directory(
        '${tempRoot.path}/synthetic_unavailable',
      );
      await unavailableWorkspace.create(recursive: true);

      // 型別表中沒有任何型別帶 carrier_path_patterns（FR-06 規則 7 的
      // 下界情形），使查詢不可用。
      final unavailableTable = TypeTable(
        Map.unmodifiable({
          for (final entry in typeTable.nodeTypes.entries)
            entry.key: NodeTypeEntry(
              name: entry.value.name,
              idPattern: entry.value.idPattern,
              completenessFields: entry.value.completenessFields,
            ),
        }),
      );
      expect(unavailableTable.pathParticipatingTypes, isEmpty);

      final outcome = await _scanProject(
        project: 'synthetic',
        rows: syntheticRows,
        workspaceRoot: unavailableWorkspace,
        table: unavailableTable,
      );

      expect(outcome.gapByPath, isEmpty, reason: '查詢不可用時不應產生破洞');
      expect(outcome.summary.hitCarrierCount, 0);
      expect(outcome.summary.noHitCount, 0);
      expect(
        outcome.summary.undeterminedCount,
        outcome.summary.totalFailureCount,
        reason: '失敗檔應全數計入未判定',
      );

      final gapResult = detectParseFailureGaps(
        events: const [],
        undeterminedCount: outcome.summary.undeterminedCount,
        // unavailableTable 移除了所有 carrierPathPatterns（見上方建構），
        // 屬「無路徑模式」情境，非版本比較。
        unavailableReason: UndeterminedGapReason.noPathPattern,
      );
      expect(gapResult, isA<Undetermined>(), reason: '應回報無法判定');
      expect(
        (gapResult as Undetermined).undeterminedCount,
        outcome.summary.undeterminedCount,
      );

      // 正常型別表下，同一批合成列會產生非零破洞數，對照出本組的差異。
      expect(gapByPath.keys.any((path) => syntheticRows.any((r) => r.path == path)), isTrue);
    });
  });
}
