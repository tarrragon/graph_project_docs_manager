/// 需求：[SPEC-006 FR-04、FR-06、D6、D7；EVT-CORPUS-003〈負載結構〉]
/// 組裝解析失敗事件（EVT-CORPUS-003）的負載。
library;

import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import 'lost_fields.dart';
import 'parse_outcome.dart';

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

/// 需求：[SPEC-006 FR-04、FR-06、D6、D7] 給一份解析失敗的檔案，回傳應發出
/// 的 EVT-CORPUS-003 負載；不該發事件時回傳 `null`。
///
/// 三種情形回傳 `null`（FR-04〈觸發條件〉、C5-6、C5-7）：
/// - [outcome] 為 [ParseResultKind.available]（事件只對失敗檔）
/// - FR-06 查詢不可用（[table] 沒有任何型別帶 `carrier_path_patterns`
///   欄位，FR-06 規則 7 的下界情形——來源三分判定屬另一票範圍，本函式只
///   依型別表內容本身判斷是否可用）
/// - FR-06 查詢未命中任何 carrier（`docs/domain-map.md` §7〈觸發條件比原
///   本設想的窄得多〉：carrier 外的失敗檔不發事件，否則破洞報告的輸入
///   有九成以上是雜訊）
///
/// 命中一型或平手時組裝負載：`lostFields` 依 [lostFields] 純函式計算，
/// 失敗檔沒有可用 frontmatter，「實際寫出的鍵」恆為空（見
/// `test/unit/corpus/lost_fields_test.dart` C6 系列，及本檔 N1 設計註記）。
ParseFailureEvent? buildParseFailureEvent({
  required String path,
  required ParseOutcome outcome,
  required TypeTable table,
}) {
  if (outcome is Available) {
    return null;
  }
  if (!_isCarrierPathQueryAvailable(table)) {
    return null;
  }

  final lookup = lookupCarrierPathType(table, path);
  return switch (lookup) {
    CarrierPathNoMatch() => null,
    CarrierPathSingleMatch(:final typeName) => _buildEvent(
      path: path,
      outcome: outcome,
      nodeType: typeName,
      candidateTypes: [typeName],
      schemaAmbiguous: false,
      completenessFields: table.nodeTypes[typeName]?.completenessFields,
    ),
    CarrierPathTie(:final candidateTypeNames) => _buildEvent(
      path: path,
      outcome: outcome,
      nodeType: null,
      candidateTypes: candidateTypeNames,
      schemaAmbiguous: true,
      completenessFields: null,
    ),
  };
}

ParseFailureEvent _buildEvent({
  required String path,
  required ParseOutcome outcome,
  required String? nodeType,
  required List<String> candidateTypes,
  required bool schemaAmbiguous,
  required Set<String>? completenessFields,
}) {
  return ParseFailureEvent(
    path: path,
    reason: _reasonForOutcome(outcome),
    line: _yamlErrorLineOf(outcome),
    nodeType: nodeType,
    candidateTypes: candidateTypes,
    schemaAmbiguous: schemaAmbiguous,
    // 需求：[SPEC-006 FR-04] 0.3.0 一律為空清單，不做部分救回。
    salvagedFields: const <String>[],
    lostFields: lostFields(
      completenessFields: completenessFields,
      writtenFields: const <String, Object?>{},
      isTied: schemaAmbiguous,
    ),
    // 需求：[SPEC-006 FR-04] 0.3.0 一律為 edgeAffecting。
    severity: ParseFailureSeverity.edgeAffecting,
  );
}

/// 需求：[SPEC-006 FR-06 規則 7] 查詢是否可用——型別表中沒有任何型別帶
/// `carrier_path_patterns` 欄位時，代表專案 JSON 與內建表都取不到路徑
/// 模式（規則 7 的下界情形），查詢不可用。
bool _isCarrierPathQueryAvailable(TypeTable table) =>
    table.pathParticipatingTypes.isNotEmpty;

/// 需求：[SPEC-006 FR-01、FR-05；EVT-CORPUS-003〈負載結構〉] `reason` 值域。
///
/// 這些字串是事件負載的資料值（`reason` 值域，非畫面顯示文字），對應
/// SPEC-006／EVT-CORPUS-003 明文列出的中文值域，非 UI Text 字面。[Available]
/// 分支結構上不會被呼叫（呼叫端 [buildParseFailureEvent] 已在進入此函式前
/// 排除 available 結果），switch 仍須窮舉六種子類別以取得編譯器保證，
/// 因此回傳空字串而非 throw（Phase 4 審查：消費端不應含執行期 throw 分支）。
String _reasonForOutcome(ParseOutcome outcome) => switch (outcome) {
  Available() => '', // i18n-exempt: 結構上不可達，見上方說明
  NoFrontmatter() => '無 frontmatter', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  Unclosed() => 'frontmatter 未閉合', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  EmptyOrNotMap() => 'frontmatter 為空或非 map', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  YamlSyntaxError() => 'YAML 語法錯誤', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  Unreadable(:final reason) =>
    '無法讀取（${_unreadableSubReasonText(reason)}）', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
};

/// YAML 語法錯誤時解析器提供的行號（1-indexed）；其餘結果為 `null`。
int? _yamlErrorLineOf(ParseOutcome outcome) => switch (outcome) {
  YamlSyntaxError(:final lineNumber) => lineNumber,
  _ => null,
};

String _unreadableSubReasonText(UnreadableReason reason) => switch (reason) {
  UnreadableReason.encoding => '編碼', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  UnreadableReason.permission => '權限', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
  UnreadableReason.fileDeleted => '檔案消失', // i18n-exempt: 事件負載資料值，非 UI 顯示字串
};
