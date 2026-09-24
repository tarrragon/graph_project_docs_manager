/// 需求：[SPEC-006 FR-08；test-design §3.3 D1、D2]
/// Diagnostics 由 `EVT-CORPUS-003` 產生 `parseFailure` 破洞。
///
/// 只依賴 `lib/corpus/`（`docs/domain-map.md` §2 已刪除
/// Diagnostics → Schema 依賴邊），不得 import `lib/schema/`。
library;

import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';

import 'parse_failure_gap.dart';

/// 需求：[SPEC-006 FR-08〈規則〉] 一筆 `EVT-CORPUS-003` 對應一筆破洞，
/// 資訊要足以讓使用者直接去修。
///
/// [carrierPathQueryAvailable] 對應 FR-06 規則 7：路徑對型別查詢是否
/// 可用，由呼叫端（Corpus 掃描摘要）提供，本函式不重新判定。查詢不
/// 可用時不產生任何 `parseFailure` 破洞，回傳 [Undetermined]
/// （FR-08〈規則〉第 2 項）；[undeterminedCount] 對應 FR-07「失敗檔中
/// 未判定的數量」，直接採信呼叫端提供的計數，改為必填避免預設值 0
/// 靜默吃掉真實數量（0.3.0-W4-001 Phase 4 耦合審查）。[reason] 為無法
/// 判定的原因碼，同樣改為必填：預設值會讓「專案版本高於內建」與「無
/// 路徑模式」兩種情境在呼叫端漏傳時被靜默標成錯的原因碼，與
/// [undeterminedCount] 的必填理由相同（不因查詢可用時本參數不生效而
/// 放寬）。兩種原因的實際判定邏輯在 Schema domain（Diagnostics 不
/// import Schema，依賴邊已刪），映射交由編排層負責。
GapDetectionResult detectParseFailureGaps({
  required List<ParseFailureEvent> events,
  required bool carrierPathQueryAvailable,
  required int undeterminedCount,
  required UndeterminedGapReason reason,
}) {
  if (!carrierPathQueryAvailable) {
    return Undetermined(undeterminedCount: undeterminedCount, reason: reason);
  }

  return GapsDetected(events.map(_toGap).toList(growable: false));
}

/// 需求：[SPEC-006 FR-08〈規則〉] 一筆事件一筆破洞，逐欄位對齊。
ParseFailureGap _toGap(ParseFailureEvent event) => ParseFailureGap(
  path: event.path,
  reason: event.reason,
  nodeType: event.nodeType,
  candidateTypes: event.candidateTypes,
  schemaAmbiguous: event.schemaAmbiguous,
);
