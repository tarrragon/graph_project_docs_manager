/// 需求：[SPEC-006 FR-08；EVT-DIAGNOSTICS-001〈設計註記〉]
/// Diagnostics 破洞的值型別。
library;

import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';

/// EVT-DIAGNOSTICS-001〈設計註記〉定義的破洞四類。0.3.0 只實際產生
/// [parseFailure]；0.4.0 起另產生 [graphDefect]（SPEC-007 FR-09，產生端
/// `lib/diagnostics/graph_defect_gap.dart`）；其餘兩類保留列舉位置供後續
/// 版本擴充。
enum GapCategory {
  /// 解析失敗（由 `parse_failure_gap.dart` 產生）。
  parseFailure,

  /// 圖結構缺陷（0.4.0 起產生，SPEC-007 FR-09；產生端
  /// `lib/diagnostics/graph_defect_gap.dart`）。
  graphDefect,

  /// 追溯缺口（本版不產生）。
  traceGap,

  /// ticket 無法定位（本版不產生）。
  unlocatable,
}

/// `EVT-CORPUS-005` 對應破洞的原因碼（FR-08；資料值，不是顯示字串）。
const nonDomainPathsMalformedGapReasonCode = 'nonDomainPathsMalformed';

/// 004 破洞的歸屬型別（FR-09 規則 6：UC 仍是節點，型別已知）。
const flowBlockMalformedGapNodeType = 'UC';

/// 一筆 `parseFailure` 破洞（FR-08，sealed）：一筆 `EVT-CORPUS-003`、`-004`
/// 或 `-005` 對應一個子型別，各子型別只帶自己來源的欄位——消費端以
/// `switch` 窮舉三種子型別，不靠 `null` 欄位猜來源。
sealed class ParseFailureGap {
  const ParseFailureGap({required this.path, required this.reason});

  /// 破洞類別，本版恆為 [GapCategory.parseFailure]。
  GapCategory get category => GapCategory.parseFailure;

  /// 相對於工作區根目錄的路徑。
  final String path;

  /// 資訊要足以讓使用者直接去修（FR-08〈規則〉）。
  final String reason;
}

/// EVT-CORPUS-003 來源：命中 carrier 的失敗檔。
///
/// 欄位語意與 `EVT-CORPUS-003` 對齊：[nodeType] 命中一型時為該型名稱，
/// 平手時為 `null`；[candidateTypes] 命中一型時為單一元素清單，平手時
/// 列出全部候選型別；[schemaAmbiguous] 為 `true` 代表平手（schema 歧義）。
class CarrierParseFailureGap extends ParseFailureGap {
  const CarrierParseFailureGap({
    required super.path,
    required super.reason,
    this.nodeType,
    required this.candidateTypes,
    required this.schemaAmbiguous,
  });

  /// 命中一型時為該型名稱；平手時為 `null`。
  final String? nodeType;

  /// 命中一型時為單一元素清單；平手時列出全部候選型別。
  final List<String> candidateTypes;

  /// `true` 代表路徑對型別查詢平手（schema 歧義）。
  final bool schemaAmbiguous;
}

/// EVT-CORPUS-004 來源：UC flow 區塊解析失敗。歸屬型別恆為 UC
/// （[nodeType]），無候選型別與歧義標記。
class FlowBlockMalformedGap extends ParseFailureGap {
  const FlowBlockMalformedGap({
    required super.path,
    required super.reason,
    required this.reasonCode,
  });

  /// 原因碼，正常為 `flowBlockMalformed`（`flowBlockMalformedReasonCode`）；
  /// 事件 reason 不以該原因碼開頭時的保存內容見 `gap_detector.dart`。
  final String reasonCode;

  /// 歸屬型別，恆為 UC。
  String get nodeType => flowBlockMalformedGapNodeType;
}

/// EVT-CORPUS-005 來源：非 domain 路徑清單檔格式錯誤。清單檔不是節點，
/// 沒有型別欄位；原因碼恆為 `nonDomainPathsMalformed`（[reasonCode]）。
class NonDomainPathsMalformedGap extends ParseFailureGap {
  const NonDomainPathsMalformedGap({
    required super.path,
    required super.reason,
    required this.subReason,
    this.nonStringElementCount,
  });

  /// 原因碼，恆為 [nonDomainPathsMalformedGapReasonCode]。
  String get reasonCode => nonDomainPathsMalformedGapReasonCode;

  /// 格式錯誤子原因（FR-10 規則 2、2a）。
  final NonDomainPathsMalformedReason subReason;

  /// 非字串元素數（D1-10）：只在 [subReason] 為 `elementNotString` 時
  /// 有值，其餘為 `null`。
  final int? nonStringElementCount;
}

/// FR-06 查詢不可用時「無法判定破洞」的原因碼（FR-08〈規則〉第 2 項）。
///
/// 原因碼是資料值，不是顯示字串；顯示文字由畫面經 l10n 投影
/// （SPEC-004 v1.46 已有對應 key），Diagnostics 不產生在地化字串
/// （用戶裁決 2026-09-24，SPEC-006 v1.6 FR-08）。
enum UndeterminedGapReason {
  /// 專案型別表版本不在 App 已知範圍（高於內建、缺席或無法解析）。
  projectVersionOutOfKnownRange,

  /// 型別表沒有路徑模式。
  noPathPattern,
}

/// 一輪 `parseFailure` 破洞偵測的結果（sealed）：查詢可用時為
/// [GapsDetected]，查詢不可用時為 [Undetermined]，兩種結局由編譯器保證
/// 互斥（0.3.0-W4-001 Phase 4 linux：先前互斥關係只寫在註解）。
///
/// [gaps] 在兩種結局都存在且不可變：查詢可用時含 003、004、005 全部；
/// 查詢不可用時只含不依賴路徑查詢的 004、005（FR-08 N4／NC-e）。
sealed class GapDetectionResult {
  const GapDetectionResult();

  /// 本輪產生的破洞（不可變）。
  List<ParseFailureGap> get gaps;
}

/// 查詢可用：[gaps] 為本輪產生的破洞，可為空清單（零筆事件時）。
class GapsDetected extends GapDetectionResult {
  GapsDetected(List<ParseFailureGap> gaps)
    : gaps = List<ParseFailureGap>.unmodifiable(gaps);

  @override
  final List<ParseFailureGap> gaps;
}

/// FR-06 查詢不可用時的「無法判定破洞」回報（FR-08〈規則〉第 2 項）。
///
/// [gaps] 只含 004、005 來源的破洞；EVT-CORPUS-003 來源的破洞恆不在此。
class Undetermined extends GapDetectionResult {
  Undetermined({
    required this.undeterminedCount,
    required this.reason,
    List<ParseFailureGap> gaps = const <ParseFailureGap>[],
  }) : gaps = List<ParseFailureGap>.unmodifiable(gaps);

  @override
  final List<ParseFailureGap> gaps;

  /// FR-07「失敗檔中未判定的數量」，本結構不重新計算，直接採信呼叫端
  /// 提供的掃描摘要計數。
  final int undeterminedCount;

  /// 無法判定的原因碼（資料值，顯示文字由畫面經 l10n 投影）。
  final UndeterminedGapReason reason;
}
