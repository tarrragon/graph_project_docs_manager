/// 需求：[SPEC-006 FR-08；EVT-DIAGNOSTICS-001〈設計註記〉]
/// Diagnostics 破洞的值型別。
library;

/// EVT-DIAGNOSTICS-001〈設計註記〉定義的破洞四類。0.3.0 只實際產生
/// [parseFailure]；其餘三類保留列舉位置供後續版本擴充。
enum GapCategory {
  /// 解析失敗（本版唯一會產生的類別）。
  parseFailure,

  /// 圖結構缺陷（本版不產生）。
  graphDefect,

  /// 追溯缺口（本版不產生）。
  traceGap,

  /// ticket 無法定位（本版不產生）。
  unlocatable,
}

/// 一筆 `parseFailure` 破洞（FR-08），由一筆 `EVT-CORPUS-003` 一對一組成。
///
/// 欄位語意與 `EVT-CORPUS-003` 對齊：[nodeType] 命中一型時為該型名稱，
/// 平手時為 `null`；[candidateTypes] 命中一型時為單一元素清單，平手時
/// 列出全部候選型別；[schemaAmbiguous] 為 `true` 代表平手（schema 歧義）。
class ParseFailureGap {
  const ParseFailureGap({
    required this.path,
    required this.reason,
    this.nodeType,
    required this.candidateTypes,
    required this.schemaAmbiguous,
  });

  /// 破洞類別，本版恆為 [GapCategory.parseFailure]。
  GapCategory get category => GapCategory.parseFailure;

  /// 相對於工作區根目錄的路徑。
  final String path;

  /// 資訊要足以讓使用者直接去修（FR-08〈規則〉）。
  final String reason;

  /// 命中一型時為該型名稱；平手時為 `null`。
  final String? nodeType;

  /// 命中一型時為單一元素清單；平手時列出全部候選型別。
  final List<String> candidateTypes;

  /// `true` 代表路徑對型別查詢平手（schema 歧義）。
  final bool schemaAmbiguous;
}

/// FR-06 查詢不可用時的「無法判定破洞」回報（FR-08〈規則〉第 2 項）。
class UndeterminedGapsReport {
  const UndeterminedGapsReport({
    required this.undeterminedCount,
    required this.reason,
  });

  /// FR-07「失敗檔中未判定的數量」，本結構不重新計算，直接採信呼叫端
  /// 提供的掃描摘要計數。
  final int undeterminedCount;

  /// 無法判定的原因說明，供畫面直接顯示。
  final String reason;
}

/// 一輪 `parseFailure` 破洞偵測的結果。[gaps] 與 [undetermined] 恰有一個
/// 非空／非 `null`：查詢可用時只填 [gaps]（可為空清單），查詢不可用時
/// [gaps] 恆為空清單且 [undetermined] 非 `null`。
class GapDetectionResult {
  const GapDetectionResult({required this.gaps, this.undetermined});

  final List<ParseFailureGap> gaps;
  final UndeterminedGapsReport? undetermined;
}
