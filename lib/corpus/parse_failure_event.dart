/// 需求：[SPEC-006 FR-04、FR-06、D6、D7；EVT-CORPUS-003〈負載結構〉]
/// 解析失敗事件（EVT-CORPUS-003）的負載值型別。
///
/// 只含值型別，不含建構邏輯——組裝負載見
/// `lib/corpus/parse_failure_event_builder.dart` 的 `buildParseFailureEvent`
/// （0.3.0-W3-534：分離值型別與建構函式，使 `lib/diagnostics/` 的 import
/// 只能碰到本檔，碰不到建構函式）。
library;

/// 需求：[SPEC-006 FR-04] `severity` 本版一律為 [edgeAffecting]（`detailOnly`
/// 保留供未來版本區分兩種強度的畫面標記，本版不會產生）。
enum ParseFailureSeverity {
  /// 失敗檔沒有進入圖譜，它原本承載的邊全部遺失。
  edgeAffecting,

  /// 僅影響詳情內容（本版不產生）。
  detailOnly,
}

/// EVT-CORPUS-003 的負載（`docs/events/corpus/EVT-CORPUS-003-parse-failed.md`
/// 〈負載結構〉）。
class ParseFailureEvent {
  const ParseFailureEvent({
    required this.path,
    required this.reason,
    this.line,
    this.nodeType,
    required this.candidateTypes,
    required this.schemaAmbiguous,
    required this.salvagedFields,
    required this.lostFields,
    required this.severity,
  });

  /// 相對於工作區根目錄的路徑。
  final String path;

  /// FR-01 結果分類或 FR-05「無法讀取」子原因對應的文字（見
  /// [_reasonForOutcome]）。
  final String reason;

  /// YAML 語法錯誤時解析器提供的行號（1-indexed），其餘結果為 null。
  final int? line;

  /// FR-06 查詢命中一型時為該型名稱；平手時為 null。
  final String? nodeType;

  /// 命中一型時為單一元素清單；平手時列出全部候選型別。
  final List<String> candidateTypes;

  /// true 代表 FR-06 查詢平手（schema 歧義）。
  final bool schemaAmbiguous;

  /// 0.3.0 一律為空清單，不做部分救回（FR-04）。
  final List<String> salvagedFields;

  /// 依 EVT-CORPUS-003〈lostFields 的算法〉：歸屬型別的完整性集合減去
  /// 實際寫出的鍵；平手時為空清單。
  final List<String> lostFields;

  /// 0.3.0 一律為 [ParseFailureSeverity.edgeAffecting]。
  final ParseFailureSeverity severity;
}
