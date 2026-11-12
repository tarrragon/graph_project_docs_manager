import 'dart:async';

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/edit/corpus_parsed_source.dart';

const ScanSummary _emptySummary = ScanSummary(
  totalFilesScanned: 0,
  nodeCount: 0,
  nonNodeWithFrontmatterCount: 0,
  failureReasonCounts: <ParseResultKind, int>{},
  hitCarrierCount: 0,
  noHitCount: 0,
  undeterminedCount: 0,
  carrierPathQueryAvailable: false,
);

/// 需求：[SPEC-009-test-design §1.4] 送出 EVT-CORPUS-001 到達的通知；負載為空
/// 的 [CorpusScanResult]，刻意不含正在編輯的檔案。Edit 不讀負載，只以此為
/// 重讀時機。
class FakeCorpusParsedSource implements CorpusParsedSource {
  final StreamController<CorpusScanResult> _controller =
      StreamController<CorpusScanResult>.broadcast(sync: true);

  bool get hasListener => _controller.hasListener;

  @override
  Stream<CorpusScanResult> get parsed => _controller.stream;

  /// 送出一輪「解析完成」。
  void emitRound() => _controller.add(
    const CorpusScanResult(
      rawNodes: <RawNode>[],
      parseErrors: <ParseError>[],
      parseFailureEvents: [],
      schemaAmbiguousNodes: [],
      summary: _emptySummary,
    ),
  );
}
