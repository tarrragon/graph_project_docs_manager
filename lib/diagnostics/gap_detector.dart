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
/// [unavailableReason] 是 FR-06 規則 7「路徑對型別查詢是否可用」與
/// 「不可用時的原因碼」合一的單一參數：`null` 代表查詢可用（回傳
/// [GapsDetected]）；非 `null` 代表查詢不可用（回傳 [Undetermined]，
/// 帶入同一個原因碼）。查詢可用與否、原因碼皆由呼叫端（Corpus 掃描
/// 摘要）判定，本函式不重新判定，也不接受「可用但帶原因」這種無意義
/// 組合（先前拆兩參數會強迫查詢可用的呼叫端傳入不會被讀的佔位原因碼，
/// PM 退回意見）。[undeterminedCount] 對應 FR-07「失敗檔中未判定的
/// 數量」，直接採信呼叫端提供的計數，改為必填避免預設值 0 靜默吃掉
/// 真實數量（0.3.0-W4-001 Phase 4 耦合審查）。兩種原因碼
/// （[UndeterminedGapReason.projectVersionOutOfKnownRange]／
/// [UndeterminedGapReason.noPathPattern]）的實際判定邏輯在 Schema
/// domain（Diagnostics 不 import Schema，依賴邊已刪），映射交由編排層
/// 負責。
GapDetectionResult detectParseFailureGaps({
  required List<ParseFailureEvent> events,
  required int undeterminedCount,
  required UndeterminedGapReason? unavailableReason,
}) {
  if (unavailableReason != null) {
    return Undetermined(
      undeterminedCount: undeterminedCount,
      reason: unavailableReason,
    );
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
