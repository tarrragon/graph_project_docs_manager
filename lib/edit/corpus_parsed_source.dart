import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';

/// 需求：[SPEC-009 FR-06] EVT-CORPUS-001（一輪解析完成）的到達通知。
/// Edit 只把它當重讀時機，不讀負載；EVT-CORPUS-002 不跨界，不在此暴露。
abstract interface class CorpusParsedSource {
  Stream<CorpusScanResult> get parsed;
}
