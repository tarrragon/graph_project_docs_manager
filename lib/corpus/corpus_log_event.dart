/// Corpus domain 的日誌事件與 sink（SPEC-010 FR-04）。
///
/// 掃描與監看路徑的逐檔事件記 `debug`（不寫檔，FR-05），一輪結束時以
/// [CorpusLogEvent.scanCompleted] 聚合成一筆 `info`；其餘 `warning` 皆為
/// 例外狀況（讀取失敗、解析失敗），不是逐檔常態事件。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 掃描路徑日誌事件（穩定契約）。
enum CorpusLogEvent {
  /// 一輪掃描開始（debug）。
  scanStarted,

  /// 一輪掃描結束的聚合記錄（info，一輪一筆；負載見 [CorpusLogKeys]）。
  scanCompleted,

  /// 讀取單檔拋出非預期例外，歸類為無法讀取（warning；帶 path）。
  fileReadUnexpectedError,

  /// 檔案系統讀取失敗（warning；帶 path）。
  fileReadFailed,

  /// 目錄無法列出（warning；帶 path）。
  directoryUnlistable,

  /// 非 domain 路徑清單檔讀取拋出非預期例外（warning）。
  nonDomainPathsUnexpectedError,

  /// 主題檔讀取拋出非預期例外（warning）。
  topicFilesUnexpectedError,

  /// UC flow 擷取拋出非預期例外（warning；帶 path）。
  flowExtractionUnexpectedError,

  /// 發出 EVT-CORPUS-004（warning；帶 path）。
  flowParseFailedEmitted,

  /// UC 本文結尾有未閉合且含頂層 flow 的圍欄（warning；帶 path）。
  flowFenceUnclosed,

  /// UC 的 yaml 區塊解析失敗（warning；帶 path、isFlowBlock）。
  yamlBlockInvalid,

  /// 型別表兩邊都沒有非 domain 路徑清單檔位置（warning）。
  nonDomainPathsLocationMissing,

  /// 非 domain 路徑清單檔無法讀取，視同缺席（info；帶 path、reason）。
  nonDomainPathsUnreadable,

  /// 非 domain 路徑清單檔 YAML 無效（warning；帶 path）。
  nonDomainPathsYamlInvalid,

  /// 非 domain 路徑清單檔格式錯誤（warning；帶 path、reason）。
  nonDomainPathsMalformed,

  /// 非 domain 路徑清單有非字串元素被略過（warning；帶 path、count）。
  nonDomainPathsElementsSkipped,

  /// 兩個主題檔讀取摘要（debug；帶兩檔狀態、mappedCount）。
  topicFilesSummarized,

  /// 主題檔非 UTF-8（warning；帶 path）。
  topicFileNotUtf8,

  /// 主題檔無法讀取（warning；帶 path、reason）。
  topicFileUnreadable,

  /// 指派檔被略過的行數（debug；帶 count）。
  topicAssignmentLinesSkipped,
}

/// 監看路徑日誌事件（穩定契約）。
enum CorpusWatchLogEvent {
  /// `docs/` 缺席，不建立監看（info；非失敗）。
  watchSkippedDocsAbsent,

  /// 監看已啟動（info）。
  watchStarted,

  /// 無法寫金絲雀，略過存活檢查（info）。
  aliveCheckSkipped,

  /// 金絲雀已寫入（debug）。
  canaryWritten,

  /// 殘留金絲雀已清除（debug）。
  residualCanaryRemoved,

  /// 殘留金絲雀清除失敗（warning）。
  residualCanaryRemovalFailed,

  /// 殘留金絲雀掃描失敗（warning）。
  residualCanaryScanFailed,

  /// 金絲雀刪除失敗（warning）。
  canaryRemovalFailed,

  /// 收到金絲雀事件（debug）。
  canaryEventReceived,

  /// 逐檔變動事件（debug；帶 path、kind、kept）。
  changeObserved,

  /// 一窗去抖合併後送出（debug；帶 changeCount、各 kind 個數）。
  changesFlushed,

  /// 監看失敗並停止（warning；帶 reason）。
  watchFailed,
}

/// 監看失敗原因碼。
enum WatchFailReason {
  streamError,
  streamClosed,
  readyTimeout,
  readyError,
  aliveTimeout,
}

/// 掃描事件負載鍵（具名常數，測試以常數比對）。
abstract final class CorpusLogKeys {
  static const path = 'path';
  static const reason = 'reason';
  static const count = 'count';
  static const isFlowBlock = 'isFlowBlock';
  static const fileCount = 'fileCount';
  static const nodeCount = 'nodeCount';
  static const failureCount = 'failureCount';
  static const unlistableDirectoryCount = 'unlistableDirectoryCount';
  static const flowMalformedUcCount = 'flowMalformedUcCount';
  static const assignmentsStatus = 'assignmentsStatus';
  static const registryStatus = 'registryStatus';
  static const mappedCount = 'mappedCount';
}

/// 監看事件負載鍵。
abstract final class CorpusWatchLogKeys {
  static const path = 'path';
  static const kind = 'kind';
  static const kept = 'kept';
  static const reason = 'reason';
  static const changeCount = 'changeCount';
  static const createdCount = 'createdCount';
  static const modifiedCount = 'modifiedCount';
  static const deletedCount = 'deletedCount';
}

/// 生產預設：經共用 writer 輸出，domain 為 `corpus`。
final LogSink<CorpusLogEvent> defaultCorpusLogSink =
    defaultLogSink<CorpusLogEvent>('corpus');

/// 生產預設監看 sink。
final LogSink<CorpusWatchLogEvent> defaultCorpusWatchLogSink =
    defaultLogSink<CorpusWatchLogEvent>('corpus');

/// 測試替身注入點；測試須在 tearDown 還原為 [defaultCorpusLogSink]。
LogSink<CorpusLogEvent> corpusLogSink = defaultCorpusLogSink;

/// Corpus 內的路徑一律為工作區相對路徑；轉為 FR-03 白名單值。
LogValue corpusPathValue(String relativePath) =>
    LogValue.path('/', '/$relativePath');
