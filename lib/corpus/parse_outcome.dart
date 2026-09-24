/// 需求：[SPEC-006 FR-01、FR-05] frontmatter 切分與結果分類的值型別
///
/// 每個檔案恰好落入 [ParseResultKind] 六種結果之一。分類細節（frontmatter
/// map、YAML 錯誤行號、無法讀取子原因）附掛於對應的具名建構子。
library;

/// 結果分類，封閉枚舉（六種），對應 SPEC-006 FR-01、FR-05。
enum ParseResultKind {
  /// YAML 解析成功，且結果是非空 map。
  available,

  /// 違反切分規則 3：第一行去除前後空白後不等於 `---`。
  noFrontmatter,

  /// 符合規則 3，但規則 4 找不到結尾 `---`。
  unclosed,

  /// 已閉合、YAML 無語法錯誤，但解析結果不是非空 map。
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

/// FR-01、FR-05 分類結果。以具名建構子保證每個 [kind] 只攜帶對應的欄位。
class ParseOutcome {
  const ParseOutcome._(
    this.kind, {
    this.frontmatter,
    this.yamlErrorLine,
    this.unreadableReason,
  });

  /// 結果分類（封閉枚舉，六種）。
  final ParseResultKind kind;

  /// [ParseResultKind.available] 專屬：解析成功的 frontmatter map。
  final Map<String, dynamic>? frontmatter;

  /// [ParseResultKind.yamlSyntaxError] 專屬：解析器提供時的行號（1-indexed）。
  final int? yamlErrorLine;

  /// [ParseResultKind.unreadable] 專屬：子原因。
  final UnreadableReason? unreadableReason;

  /// 需求：[SPEC-006 FR-01] 可用 —— YAML 解析成功，且結果是非空 map。
  factory ParseOutcome.available(Map<String, dynamic> frontmatter) =>
      ParseOutcome._(ParseResultKind.available, frontmatter: frontmatter);

  /// 需求：[SPEC-006 FR-01 規則 3] 無 frontmatter。
  factory ParseOutcome.noFrontmatter() =>
      const ParseOutcome._(ParseResultKind.noFrontmatter);

  /// 需求：[SPEC-006 FR-01 規則 4] frontmatter 未閉合。
  factory ParseOutcome.unclosed() =>
      const ParseOutcome._(ParseResultKind.unclosed);

  /// 需求：[SPEC-006 FR-01] frontmatter 為空或非 map。
  factory ParseOutcome.emptyOrNotMap() =>
      const ParseOutcome._(ParseResultKind.emptyOrNotMap);

  /// 需求：[SPEC-006 FR-01] YAML 語法錯誤。
  factory ParseOutcome.yamlSyntaxError({int? lineNumber}) => ParseOutcome._(
    ParseResultKind.yamlSyntaxError,
    yamlErrorLine: lineNumber,
  );

  /// 需求：[SPEC-006 FR-05] 無法讀取，附子原因。
  factory ParseOutcome.unreadable(UnreadableReason reason) =>
      ParseOutcome._(ParseResultKind.unreadable, unreadableReason: reason);

  @override
  String toString() {
    // i18n-exempt: 開發除錯用 toString，非 user-facing 顯示字串
    final buffer = StringBuffer('ParseOutcome(kind: $kind, ');
    buffer.write('frontmatter: $frontmatter, '); // i18n-exempt: debug 輸出
    buffer.write('yamlErrorLine: $yamlErrorLine, '); // i18n-exempt: debug 輸出
    buffer.write('unreadableReason: $unreadableReason)'); // i18n-exempt: debug 輸出
    return buffer.toString();
  }
}
