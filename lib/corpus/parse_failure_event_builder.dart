/// 需求：[SPEC-006 FR-04、FR-06、D6、D7；EVT-CORPUS-003〈負載結構〉]
/// 組裝解析失敗事件（EVT-CORPUS-003）的負載，以及掃描器與事件共用的
/// `reason` 文字對照（0.3.0-W3-534，吸收 0.3.0-W3-529）。
library;

import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import 'lost_fields.dart';
import 'parse_failure_event.dart';
import 'parse_outcome.dart';

/// 需求：[SPEC-006 FR-04、FR-06、D6、D7] 給一份已知該發 EVT-CORPUS-003 的
/// 失敗檔案，組裝事件負載，回傳恆非 `null`。
///
/// 呼叫端（`corpus_scanner.dart`）負責先行篩選才呼叫本函式：[outcome] 已
/// 排除 [Available]（事件只對失敗檔，FR-04〈觸發條件〉）、查詢可用性已
/// 確認（FR-06 規則 7）、[lookup] 的型別 [CarrierPathHit] 本身即排除
/// 未命中結果（carrier 外的失敗檔不發事件，`docs/domain-map.md` §7
/// 〈觸發條件比原本設想的窄得多〉；0.3.0-W3-540：未命中不再是執行期
/// 才發現的契約違反，而是編譯期即不可傳入）。呼叫端算出 [lookup] 的同一
/// 次 `lookupCarrierPathType` 呼叫是本輪唯一一次查詢，本函式不重查
/// （0.3.0-W3-534：先前掃描器判斷命中與否、與建構事件各自呼叫一次，同一
/// 檔查兩次）。
///
/// `lostFields` 依 [lostFields] 純函式計算，失敗檔沒有可用 frontmatter，
/// 「實際寫出的鍵」恆為空（見 `test/unit/corpus/lost_fields_test.dart`
/// C6 系列，及 `parse_failure_event.dart` N1 設計註記）。
ParseFailureEvent buildParseFailureEvent({
  required String path,
  required ParseOutcome outcome,
  required CarrierPathHit lookup,
  required TypeTable table,
}) {
  final String? nodeType;
  final List<String> candidateTypes;
  final bool schemaAmbiguous;
  final Set<String>? completenessFields;

  switch (lookup) {
    case CarrierPathSingleMatch(:final typeName):
      nodeType = typeName;
      candidateTypes = [typeName];
      schemaAmbiguous = false;
      completenessFields = table.nodeTypes[typeName]?.completenessFields;
    case CarrierPathTie(:final candidateTypeNames):
      nodeType = null;
      candidateTypes = candidateTypeNames;
      schemaAmbiguous = true;
      completenessFields = null;
  }

  return ParseFailureEvent(
    path: path,
    reason: parseOutcomeReasonText(outcome),
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

/// 需求：[SPEC-006 FR-01、FR-05；EVT-CORPUS-003〈負載結構〉] `reason` 值域。
///
/// 這些字串是資料值（事件的 `reason` 值域、`ParseError.reasonText` 投影
/// 的顯示文字共用同一份對照），非畫面顯示規範，對應 SPEC-006／
/// EVT-CORPUS-003 明文列出的中文值域，非 UI Text 字面。對照只存在這一處
/// （0.3.0-W3-534：吸收 0.3.0-W3-529，消除掃描器與事件曾經各自維護一份的
/// 風險）。[Available] 分支結構上不會被呼叫（呼叫端已在進入前排除
/// available 結果），switch 仍須窮舉六種子類別以取得編譯器保證，因此回傳
/// 空字串而非 throw（Phase 4 審查：消費端不應含執行期 throw 分支——本例
/// 有可行的 sentinel 回傳值，不同於上方 [CarrierPathNoMatch] 分支無合理
/// 負載可組裝的情形）。
String parseOutcomeReasonText(ParseOutcome outcome) => switch (outcome) {
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
