/// 需求：[SPEC-006 FR-08；test-design §3.3 D1、D2]
/// Diagnostics 由 `EVT-CORPUS-003`、`-004`、`-005` 產生 `parseFailure` 破洞。
///
/// 只依賴 `lib/corpus/`（`docs/system-layer.md` §2 已刪除
/// Diagnostics → Schema 依賴邊），不得 import `lib/schema/`。
library;

import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/uc_flow_extractor.dart';

import 'parse_failure_gap.dart';

/// 需求：[SPEC-006 FR-08〈規則〉] 一筆 `EVT-CORPUS-003` 對應一筆破洞，
/// 資訊要足以讓使用者直接去修；一筆 `EVT-CORPUS-004`、一筆
/// `EVT-CORPUS-005` 各對應一筆破洞。破洞數 = 命中 carrier 數 + flow
/// 失敗 UC 數 + 清單檔格式錯誤數（0 或 1）。
///
/// [unavailableReason] 是 FR-06 規則 7「路徑對型別查詢是否可用」與
/// 「不可用時的原因碼」合一的單一參數：`null` 代表查詢可用（回傳
/// [GapsDetected]）；非 `null` 代表查詢不可用（回傳 [Undetermined]，
/// 帶入同一個原因碼）。查詢可用與否、原因碼皆由呼叫端（Corpus 掃描
/// 摘要）判定，本函式不重新判定。[undeterminedCount] 對應 FR-07
/// 「失敗檔中未判定的數量」，直接採信呼叫端提供的計數。
///
/// 查詢不可用只抑制 [events]（003）的破洞；[flowEvents]（004）與
/// [nonDomainPathsEvent]（005）不依賴路徑查詢，照常產生並放入
/// [Undetermined.gaps]（`0.5.0-W1-113` N4、`0.5.0-W1-114.1` NC-e）。
GapDetectionResult detectParseFailureGaps({
  required List<ParseFailureEvent> events,
  required int undeterminedCount,
  required UndeterminedGapReason? unavailableReason,
  List<FlowParseFailedEvent> flowEvents = const <FlowParseFailedEvent>[],
  NonDomainPathsParseFailedEvent? nonDomainPathsEvent,
}) {
  final independentGaps = <ParseFailureGap>[
    ...flowEvents.map(_toFlowGap),
    if (nonDomainPathsEvent != null) _toNonDomainPathsGap(nonDomainPathsEvent),
  ];
  if (unavailableReason != null) {
    return Undetermined(
      undeterminedCount: undeterminedCount,
      reason: unavailableReason,
      gaps: List.unmodifiable(independentGaps),
    );
  }

  return GapsDetected(<ParseFailureGap>[
    ...events.map(_toGap),
    ...independentGaps,
  ]);
}

/// 需求：[SPEC-006 FR-08〈規則〉] 一筆事件一筆破洞，逐欄位對齊。
ParseFailureGap _toGap(ParseFailureEvent event) => CarrierParseFailureGap(
  path: event.path,
  reason: event.reason,
  nodeType: event.nodeType,
  candidateTypes: event.candidateTypes,
  schemaAmbiguous: event.schemaAmbiguous,
);

/// 需求：[SPEC-006 v1.25 FR-08〈規則〉第 2 條、EVT-CORPUS-004] 破洞原因碼由
/// 事件類別決定，恆為 `flowBlockMalformed`，不從 reason 解析。reason 未以
/// 原因碼開頭（前綴比對）視為上游違反 EVT-CORPUS-004 約定：寫 warning
/// （UC 路徑與 reason 前 [_reasonLogLimit] 字），破洞照常產生。
ParseFailureGap _toFlowGap(FlowParseFailedEvent event) {
  if (!event.reason.startsWith(flowBlockMalformedReasonCode)) {
    _warnFlowReasonPrefixViolation(event);
  }
  return FlowBlockMalformedGap(path: event.path, reason: event.reason);
}

/// warning 日誌帶入的 reason 字數上限。
const _reasonLogLimit = 80;

void _warnFlowReasonPrefixViolation(FlowParseFailedEvent event) {
  final reason = event.reason;
  final excerpt = reason.length > _reasonLogLimit
      ? reason.substring(0, _reasonLogLimit)
      : reason;
  developer.log(
    // i18n-exempt: 開發者診斷 log
    'EVT-CORPUS-004 reason 未以原因碼開頭（上游違約），破洞照常產生：'
    '${event.path} reason=$excerpt',
    name: 'diagnostics.gap_detector',
    level: 900,
  );
}

/// 需求：[SPEC-006 FR-08〈規則〉第 3 條、EVT-CORPUS-005] 破洞帶清單檔路徑、
/// 原因碼 `nonDomainPathsMalformed` 與子原因；子原因為 `elementNotString`
/// 時另帶 `nonStringElementCount`（D1-10）；事件側保證其餘子原因為 `null`
/// （`NonDomainPathsParseFailedEvent` 建構子私有），直接沿用。負載不含
/// 在地化字串。
ParseFailureGap _toNonDomainPathsGap(NonDomainPathsParseFailedEvent event) =>
    NonDomainPathsMalformedGap(
      path: event.path,
      reason: event.reason.name,
      subReason: event.reason,
      nonStringElementCount: event.nonStringElementCount,
    );
