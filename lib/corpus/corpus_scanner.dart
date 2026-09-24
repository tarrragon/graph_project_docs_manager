/// 需求：[SPEC-006 FR-02、FR-03、FR-04、FR-05、FR-07、NFR-01] Corpus
/// 掃描器：遍歷 `docs/**/*.md`，逐檔分類、判型、組裝失敗事件，並產出可
/// 驗證的摘要計數（EVT-CORPUS-001）。
///
/// 依賴方向：本檔屬 Corpus domain（`docs/domain-map.md` §5），只 import
/// `lib/schema/`，不 import `lib/diagnostics/`；工作區根目錄不自行推導，
/// 由呼叫端傳入已綁定該根的 [DocsFileSystem]（C8-6：取自 Workspace 公開
/// 面）。
library;

import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import 'docs_file_system.dart';
import 'frontmatter_classifier.dart';
import 'node_typer.dart';
import 'parse_failure_event.dart';
import 'parse_failure_event_builder.dart';
import 'parse_outcome.dart';
import 'scan_summary.dart';

/// FR-02 掃描起點：工作區根目錄下固定的 `docs/` 子目錄（規則：範圍與
/// PROP-005 §0.3 量測時一致）。
const _docsRoot = 'docs';

/// 副檔名比對只認小寫 `.md`（FR-02 規則）。
const _markdownExtension = '.md';

/// EVT-CORPUS-001 的一筆節點（C10-5：帶完整 frontmatter map、相對路徑、
/// 判定型別；不含邊）。
class RawNode {
  const RawNode({
    required this.path,
    required this.frontmatter,
    required this.typeName,
  });

  final String path;
  final Map<String, dynamic> frontmatter;
  final String typeName;
}

/// EVT-CORPUS-001 的一筆 `parseErrors`（FR-04：路徑、原因、行號）。保留
/// 原始 [ParseOutcome] 值型別，不重複儲存文字；[reasonText] 投影顯示文字
/// 時與 `parse_failure_event_builder.dart` 的 `parseOutcomeReasonText` 共用
/// 同一份對照（0.3.0-W3-534：原因文字只存在一處）。
class ParseError {
  const ParseError({required this.path, required this.outcome});

  final String path;
  final ParseOutcome outcome;

  /// FR-01／FR-05 分類對應的顯示文字，與 [ParseFailureEvent.reason] 共用
  /// 同一份對照（`parseOutcomeReasonText`）。
  String get reasonText => parseOutcomeReasonText(outcome);
}

/// FR-03：`id` 互斥保證被打破的可用檔案——路徑與全部候選型別（0.3.0-W3-534：
/// 先前只計入 [ScanSummary.nonNodeWithFrontmatterCount] 的一部分，歧義本身
/// 不可追溯；本欄位讓歧義檔案以路徑與候選型別出現在掃描結果）。
class SchemaAmbiguousNode {
  const SchemaAmbiguousNode({required this.path, required this.candidateTypes});

  final String path;
  final List<String> candidateTypes;
}

/// 一輪掃描的完整結果。
class CorpusScanResult {
  const CorpusScanResult({
    required this.rawNodes,
    required this.parseErrors,
    required this.parseFailureEvents,
    required this.schemaAmbiguousNodes,
    required this.summary,
  });

  final List<RawNode> rawNodes;
  final List<ParseError> parseErrors;
  final List<ParseFailureEvent> parseFailureEvents;

  /// FR-03：`id` 互斥被打破的可用檔案，各附路徑與候選型別（0.3.0-W3-534）。
  final List<SchemaAmbiguousNode> schemaAmbiguousNodes;
  final ScanSummary summary;
}

/// 測試用查詢種子（`@visibleForTesting`）：預設呼叫真正的
/// [lookupCarrierPathType]；測試以自訂函式包裝計數，驗證每個失敗檔只查
/// 一次 carrier（0.3.0-W3-534 acceptance）。
typedef CarrierPathLookupFn = CarrierPathLookupResult Function(
  TypeTable table,
  String path,
);

/// 需求：[SPEC-006 FR-02、FR-03、FR-04、FR-05、FR-07、NFR-01] 掃描
/// [fileSystem] 綁定的工作區下 `docs/**/*.md`，逐檔分類、判型、組裝失敗
/// 事件，回傳彙整結果。
///
/// [table] 用於 FR-03 節點判型與 FR-06 路徑對型別查詢；來源判定（專案
/// JSON／內建表三分）屬另一票範圍，本函式只依收到的型別表內容判斷查詢
/// 是否可用（`table.pathParticipatingTypes.isEmpty` 即不可用，與
/// `parse_failure_event.dart` 的內部判定一致）。
///
/// 單檔失敗不中止整輪掃描（NFR-01）：例外只發生在單一檔案的讀取或分類
/// 步驟時被就地攔截並歸類為「無法讀取」，不往外傳播到本函式的迴圈。
Future<CorpusScanResult> scanCorpus({
  required DocsFileSystem fileSystem,
  required TypeTable table,
  CarrierPathLookupFn lookupCarrierPath = lookupCarrierPathType,
}) async {
  final paths = await _listMarkdownFiles(fileSystem, _docsRoot);
  final carrierPathQueryAvailable = table.pathParticipatingTypes.isNotEmpty;
  final acc = _ScanAccumulator();

  for (final path in paths) {
    final outcome = await _readAndClassify(fileSystem, path);
    switch (outcome) {
      case Available(:final frontmatter):
        acc.addAvailable(table, path, frontmatter);
      default:
        acc.addFailure(
          table,
          path,
          outcome,
          carrierPathQueryAvailable,
          lookupCarrierPath,
        );
    }
  }

  return acc.toResult(paths.length, carrierPathQueryAvailable);
}

/// 需求：[SPEC-006 FR-01、FR-05、NFR-01] 讀取單一檔案並分類；讀取失敗直接
/// 映射為「無法讀取」對應子原因，成功時交給 [classifyFrontmatter]。
///
/// 外層包 try/catch 是 NFR-01 的最後一道防線：即使注入的 [fileSystem] 實作
/// 拋出非 [DocsReadResult] 契約內的非預期例外，該檔仍歸類為無法讀取，不
/// 讓例外往外傳播中止整輪掃描（C11-4）。
Future<ParseOutcome> _readAndClassify(
  DocsFileSystem fileSystem,
  String path,
) async {
  try {
    final read = await fileSystem.readBytes(path);
    return switch (read) {
      DocsReadSuccess(:final bytes) => classifyFrontmatter(bytes),
      DocsReadFailure(:final reason) => ParseOutcome.unreadable(reason),
    };
  } catch (e) {
    developer.log(
      '讀取單檔時發生非預期例外，歸類為無法讀取：$path', // i18n-exempt: 開發者 debug log
      name: 'CorpusScanner',
      level: 900,
      error: e,
    );
    return ParseOutcome.unreadable(UnreadableReason.fileDeleted);
  }
}

/// 需求：[SPEC-006 FR-02] 遞迴列出 [root] 底下所有副檔名為小寫 `.md` 的
/// 檔案；不進入符號連結目錄（規則：不追符號連結，C8-4）；[root] 不存在時
/// [DocsFileSystem.listEntries] 回傳空清單，等同 0 檔（C8-1）。回傳結果
/// 排序後回傳，讓掃描結果與檔案系統列舉順序無關（C11-3 順序不影響結果）。
Future<List<String>> _listMarkdownFiles(
  DocsFileSystem fileSystem,
  String root,
) async {
  final matches = <String>[];
  final queue = <String>[root];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    final entries = await fileSystem.listEntries(current);
    for (final entry in entries) {
      switch (entry.kind) {
        case DocsFileSystemEntryKind.directory:
          queue.add(entry.path);
        case DocsFileSystemEntryKind.file:
          if (entry.path.endsWith(_markdownExtension)) {
            matches.add(entry.path);
          }
        case DocsFileSystemEntryKind.symlink:
          break;
      }
    }
  }
  matches.sort();
  return matches;
}

/// 一輪掃描的累加器：把「可用」與「失敗」兩種分支各自的計數與產出集中在
/// 一處，讓 [scanCorpus] 的主迴圈維持精簡（僅負責讀檔與分派）。
class _ScanAccumulator {
  final rawNodes = <RawNode>[];
  final parseErrors = <ParseError>[];
  final parseFailureEvents = <ParseFailureEvent>[];
  final schemaAmbiguousNodes = <SchemaAmbiguousNode>[];
  final failureReasonCounts = <ParseResultKind, int>{};
  var nonNodeCount = 0;
  var hitCarrierCount = 0;
  var noHitCount = 0;
  var undeterminedCount = 0;

  /// 需求：[SPEC-006 FR-03] 可用檔案：判型命中即記入 [rawNodes]，否則計入
  /// 「有 frontmatter 的非節點」（`id` 缺席、不命中、或互斥被打破）；互斥
  /// 被打破的檔案另以路徑與候選型別記入 [schemaAmbiguousNodes]
  /// （0.3.0-W3-534：先前只計數，歧義檔案本身不可追溯）。
  void addAvailable(
    TypeTable table,
    String path,
    Map<String, dynamic> frontmatter,
  ) {
    final typing = classifyNodeType(table, frontmatter);
    switch (typing) {
      case NodeTypingMatch(:final typeName):
        rawNodes.add(
          RawNode(path: path, frontmatter: frontmatter, typeName: typeName),
        );
      case NodeTypingNonNode(:final schemaAmbiguous, :final candidateTypes):
        nonNodeCount++;
        if (schemaAmbiguous) {
          schemaAmbiguousNodes.add(
            SchemaAmbiguousNode(path: path, candidateTypes: candidateTypes),
          );
        }
    }
  }

  /// 需求：[SPEC-006 FR-04、FR-06、FR-07] 失敗檔一律記入 `parseErrors`；
  /// FR-06 查詢不可用時全部計入未判定（C10-3），可用時依 carrier 命中與
  /// 否分流，命中（含平手）者另組裝 EVT-CORPUS-003。[lookupCarrierPath]
  /// 每個失敗檔只呼叫一次——查詢結果同時決定命中分流與（命中時）組裝事件
  /// 所需的候選型別，不像先前分兩處各自查一次（0.3.0-W3-534）。
  void addFailure(
    TypeTable table,
    String path,
    ParseOutcome outcome,
    bool carrierPathQueryAvailable,
    CarrierPathLookupFn lookupCarrierPath,
  ) {
    parseErrors.add(ParseError(path: path, outcome: outcome));
    failureReasonCounts.update(
      outcome.kind,
      (count) => count + 1,
      ifAbsent: () => 1,
    );

    if (!carrierPathQueryAvailable) {
      undeterminedCount++;
      return;
    }

    final lookup = lookupCarrierPath(table, path);
    if (lookup is! CarrierPathHit) {
      noHitCount++;
      return;
    }

    hitCarrierCount++;
    parseFailureEvents.add(
      buildParseFailureEvent(
        path: path,
        outcome: outcome,
        lookup: lookup,
        table: table,
      ),
    );
  }

  CorpusScanResult toResult(
    int totalFilesScanned,
    bool carrierPathQueryAvailable,
  ) {
    return CorpusScanResult(
      rawNodes: rawNodes,
      parseErrors: parseErrors,
      parseFailureEvents: parseFailureEvents,
      schemaAmbiguousNodes: schemaAmbiguousNodes,
      summary: ScanSummary(
        totalFilesScanned: totalFilesScanned,
        nodeCount: rawNodes.length,
        nonNodeWithFrontmatterCount: nonNodeCount,
        failureReasonCounts: Map.unmodifiable(failureReasonCounts),
        hitCarrierCount: hitCarrierCount,
        noHitCount: noHitCount,
        undeterminedCount: undeterminedCount,
        carrierPathQueryAvailable: carrierPathQueryAvailable,
      ),
    );
  }
}
