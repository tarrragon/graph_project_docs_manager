/// 需求：[SPEC-006 FR-07] 掃描結果摘要與守恆式。
library;

import 'parse_outcome.dart';

/// 一輪掃描的可驗證計數（FR-07〈計數項〉）。
class ScanSummary {
  const ScanSummary({
    required this.totalFilesScanned,
    required this.nodeCount,
    required this.nonNodeWithFrontmatterCount,
    required this.failureReasonCounts,
    required this.hitCarrierCount,
    required this.noHitCount,
    required this.undeterminedCount,
    required this.carrierPathQueryAvailable,
    this.unlistableDirectories = const <String>[],
  });

  /// 掃描到的檔案總數。刻意作為獨立觀測值傳入、不由其他欄位推導——讓
  /// [checkScanSummaryConservation] 真的有可能偵測到少算的情形
  /// （SPEC-006-test-design.md §3.2 C10-4 守衛）。
  final int totalFilesScanned;

  final int nodeCount;

  /// FR-03：`id` 缺席、不命中任何型別、或互斥被打破的可用檔案。
  final int nonNodeWithFrontmatterCount;

  /// key 為 FR-01／FR-05 五種失敗結果分類之一（不含
  /// [ParseResultKind.available]）。
  final Map<ParseResultKind, int> failureReasonCounts;

  /// 失敗檔中命中 carrier 的數量（含平手，FR-07〈計數項〉附註：「平手的
  /// 檔案也發事件、也產生一筆帶候選型別的破洞」）。
  final int hitCarrierCount;

  /// 失敗檔中未命中任何 carrier 的數量。
  final int noHitCount;

  /// FR-06 查詢不可用時，失敗檔全部計入本項（C10-3）。
  final int undeterminedCount;

  /// FR-06 規則 7：路徑對型別查詢是否可用（串接要求：供 Diagnostics 的
  /// `detectParseFailureGaps` 使用）。
  final bool carrierPathQueryAvailable;

  /// FR-02：本輪掃描中無法列出的目錄（相對路徑），如沒有讀取權限。目錄內
  /// 有幾個檔案本來就無從得知，不計入 [totalFilesScanned]，不影響守恆式
  /// （用戶裁決 2026-09-24，Phase 4 審查）。
  final List<String> unlistableDirectories;

  int get totalFailureCount =>
      failureReasonCounts.values.fold(0, (sum, count) => sum + count);
}

/// 需求：[SPEC-006 FR-07〈守恆式〉]：
/// 1. 掃描檔案總數 = 節點數 + 有 frontmatter 的非節點數 + 各失敗原因數量總和
/// 2. 各失敗原因數量總和 = 命中 carrier 數 + 未命中數 + 未判定數
///
/// 回傳 `false` 代表任一式不成立（C10-4 守衛：刻意少算
/// [ScanSummary.totalFilesScanned] 一檔的輸入必須觸發本函式回傳 `false`，
/// 證明本檢查器真的會抓到少算，不是恆真判斷）。
bool checkScanSummaryConservation(ScanSummary summary) {
  final firstEquationHolds =
      summary.totalFilesScanned ==
      summary.nodeCount +
          summary.nonNodeWithFrontmatterCount +
          summary.totalFailureCount;
  final secondEquationHolds =
      summary.totalFailureCount ==
      summary.hitCarrierCount +
          summary.noHitCount +
          summary.undeterminedCount;
  return firstEquationHolds && secondEquationHolds;
}
