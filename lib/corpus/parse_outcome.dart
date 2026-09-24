/// 需求：[SPEC-006 FR-01、FR-05] frontmatter 切分與結果分類的值型別
///
/// 每個檔案恰好落入 [ParseOutcome] 的六種具名子類別之一。[ParseOutcome] 為
/// sealed class：呼叫端以 switch／pattern matching 存取各分類專屬欄位，編譯
/// 器保證窮舉六種情形，不需要 `!` 或執行期 throw 分支（0.3.0-W4-001 Phase 4
/// 審查：原本的 kind 列舉 + 可為 null 欄位設計是「假 sum type」，欄位是否有
/// 值取決於執行期 kind，編譯器無法強制檢查）。
library;

/// 結果分類，封閉枚舉（六種），對應 SPEC-006 FR-01、FR-05。供不需要窮舉
/// pattern matching 的呼叫端（如依分類計數）查詢；六種子類別各自覆寫
/// [ParseOutcome.kind] 回傳對應值，兩者恆一致。
enum ParseResultKind {
  /// YAML 解析成功，且結果是非空 map。
  available,

  /// 違反切分規則 3：第一行去除前後空白後不等於 `---`。
  noFrontmatter,

  /// 符合規則 3，但規則 4 找不到結尾 `---`。
  unclosed,

  /// 已閉合、YAML 無語法錯誤，但解析結果不是非空 map（含頂層鍵非字串，
  /// Phase 4 審查：不應被誤歸為「無法讀取」）。
  emptyOrNotMap,

  /// YAML 解析器回報語法錯誤。
  yamlSyntaxError,

  /// 檔案內容取不到（FR-05）。
  unreadable,
}

/// 「無法讀取」的子原因（FR-05）。本票（0.3.0-W2-005）只產生 [encoding]；
/// [permission]、[fileDeleted] 由掃描器（C9）產生，型別在此共用以利重用。
enum UnreadableReason {
  /// 無法以 UTF-8 解碼。
  encoding,

  /// 沒有讀取權限。
  permission,

  /// 列出後、讀取前被刪除或移走。
  fileDeleted,
}

/// FR-01、FR-05 分類結果，sealed class（六個具名子類別）。
sealed class ParseOutcome {
  const ParseOutcome();

  /// 對應的封閉枚舉值，供依分類計數等不需窮舉 pattern matching 的呼叫端
  /// 使用（如 `corpus_scanner.dart` 的 `failureReasonCounts`）。
  ParseResultKind get kind;

  /// 需求：[SPEC-006 FR-01] 可用 —— YAML 解析成功，且結果是非空 map。
  /// [frontmatter] 必須是不含 `YamlMap`／`YamlList`、且不可變的一般
  /// `Map<String, dynamic>`（呼叫端負責保證，見 `frontmatter_classifier.dart`
  /// 的 `_toImmutableFrontmatter`）。
  factory ParseOutcome.available(Map<String, dynamic> frontmatter) =>
      Available(frontmatter);

  /// 需求：[SPEC-006 FR-01 規則 3] 無 frontmatter。
  factory ParseOutcome.noFrontmatter() => const NoFrontmatter();

  /// 需求：[SPEC-006 FR-01 規則 4] frontmatter 未閉合。
  factory ParseOutcome.unclosed() => const Unclosed();

  /// 需求：[SPEC-006 FR-01] frontmatter 為空或非 map（含頂層鍵非字串）。
  factory ParseOutcome.emptyOrNotMap() => const EmptyOrNotMap();

  /// 需求：[SPEC-006 FR-01] YAML 語法錯誤。
  factory ParseOutcome.yamlSyntaxError({int? lineNumber}) =>
      YamlSyntaxError(lineNumber: lineNumber);

  /// 需求：[SPEC-006 FR-05] 無法讀取，附子原因。
  factory ParseOutcome.unreadable(UnreadableReason reason) =>
      Unreadable(reason);
}

/// [ParseResultKind.available]：解析成功的 frontmatter map。
final class Available extends ParseOutcome {
  const Available(this.frontmatter);

  /// 不含 `YamlMap`／`YamlList`、且不可變（`Map.unmodifiable` 建構，含巢狀）。
  final Map<String, dynamic> frontmatter;

  @override
  ParseResultKind get kind => ParseResultKind.available;

  @override
  String toString() => 'Available(frontmatter: $frontmatter)'; // i18n-exempt: debug 輸出
}

/// [ParseResultKind.noFrontmatter]：第一行不是 `---`。
final class NoFrontmatter extends ParseOutcome {
  const NoFrontmatter();

  @override
  ParseResultKind get kind => ParseResultKind.noFrontmatter;

  @override
  String toString() => 'NoFrontmatter()'; // i18n-exempt: debug 輸出
}

/// [ParseResultKind.unclosed]：找不到結尾 `---`。
final class Unclosed extends ParseOutcome {
  const Unclosed();

  @override
  ParseResultKind get kind => ParseResultKind.unclosed;

  @override
  String toString() => 'Unclosed()'; // i18n-exempt: debug 輸出
}

/// [ParseResultKind.emptyOrNotMap]：已閉合、YAML 無語法錯誤，但解析結果
/// 不是非空 map（含頂層鍵非字串）。
final class EmptyOrNotMap extends ParseOutcome {
  const EmptyOrNotMap();

  @override
  ParseResultKind get kind => ParseResultKind.emptyOrNotMap;

  @override
  String toString() => 'EmptyOrNotMap()'; // i18n-exempt: debug 輸出
}

/// [ParseResultKind.yamlSyntaxError]：YAML 解析器回報語法錯誤。
final class YamlSyntaxError extends ParseOutcome {
  const YamlSyntaxError({this.lineNumber});

  /// 解析器提供時的行號（1-indexed）；解析器未提供時為 `null`。
  final int? lineNumber;

  @override
  ParseResultKind get kind => ParseResultKind.yamlSyntaxError;

  @override
  String toString() => 'YamlSyntaxError(lineNumber: $lineNumber)'; // i18n-exempt: debug 輸出
}

/// [ParseResultKind.unreadable]：檔案內容取不到，附子原因。
final class Unreadable extends ParseOutcome {
  const Unreadable(this.reason);

  final UnreadableReason reason;

  @override
  ParseResultKind get kind => ParseResultKind.unreadable;

  @override
  String toString() => 'Unreadable(reason: $reason)'; // i18n-exempt: debug 輸出
}
