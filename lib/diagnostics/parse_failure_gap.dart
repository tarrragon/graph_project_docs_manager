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

/// FR-06 查詢不可用時「無法判定破洞」的原因碼（FR-08〈規則〉第 2 項）。
///
/// 原因碼是資料值，不是顯示字串；顯示文字由畫面經 l10n 投影
/// （SPEC-004 v1.46 已有對應 key），Diagnostics 不產生在地化字串
/// （用戶裁決 2026-09-24，SPEC-006 v1.6 FR-08）。
enum UndeterminedGapReason {
  /// 專案型別表版本高於 App 內建版本。
  projectVersionHigherThanBuiltin,

  /// 型別表沒有路徑模式。
  noPathPattern,
}

/// 一輪 `parseFailure` 破洞偵測的結果（sealed）：查詢可用時為
/// [GapsDetected]，查詢不可用時為 [Undetermined]，兩種結局由編譯器保證
/// 互斥（0.3.0-W4-001 Phase 4 linux：先前互斥關係只寫在註解）。
sealed class GapDetectionResult {
  const GapDetectionResult();
}

/// 查詢可用：[gaps] 為本輪產生的破洞，可為空清單（零筆事件時）。
class GapsDetected extends GapDetectionResult {
  const GapsDetected(this.gaps);

  final List<ParseFailureGap> gaps;
}

/// FR-06 查詢不可用時的「無法判定破洞」回報（FR-08〈規則〉第 2 項）。
class Undetermined extends GapDetectionResult {
  const Undetermined({required this.undeterminedCount, required this.reason});

  /// FR-07「失敗檔中未判定的數量」，本結構不重新計算，直接採信呼叫端
  /// 提供的掃描摘要計數。
  final int undeterminedCount;

  /// 無法判定的原因碼（資料值，顯示文字由畫面經 l10n 投影）。
  final UndeterminedGapReason reason;
}
