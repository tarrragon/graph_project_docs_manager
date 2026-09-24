/// FR-06 型別表模型：路徑對型別查詢所需的最小資料結構（規則 1～6）。
///
/// 對應 `tracking_schema.json` 的 `node_types[].carrier_path_patterns`
/// 欄位形態（`.claude/skills/doc/doc_system/core/tracking_schema.py`）。
/// 本模型不負責讀 JSON 或內建 asset，只描述「查詢需要什麼資料」；來源
/// 判定（專案 JSON／內建表三分）屬另一票範圍（FR-06 規則 7）。
library;

/// 單一路徑模式與其具體度（規則 6）。
///
/// `specificity` 由上游（`tracking_schema.py`）依路徑樣板計算並匯出，
/// 本層只讀值比較，不重算（SPEC-006-test-design.md §3.1 S2 附註）。
class CarrierPathPattern {
  const CarrierPathPattern({required this.pattern, required this.specificity});

  /// 比對相對路徑（含檔名）用的正則字串，與 `id_pattern` 同一方言
  /// （`python-re`）。ASCII 語意由 Dart [RegExp] 預設提供：未啟用
  /// `unicode` 旗標時 `\d`／`\w` 只匹配 ASCII 字元，與規則 2 的裁決一致。
  final String pattern;

  /// `[literalSegmentCount, crossSegmentWildcardCount]`（規則 6）。
  final List<int> specificity;

  /// 編譯後的 [RegExp]，供查詢時重複比對。
  RegExp toRegExp() => RegExp(pattern);
}

/// 單一節點型別的型別表條目。
class NodeTypeEntry {
  const NodeTypeEntry({
    required this.name,
    this.carrierPathPatterns,
    this.idPattern,
    this.completenessFields = const <String>{},
  });

  /// 型別名稱（如 `SPEC`、`DomainBundle`）。
  final String name;

  /// `null` 代表型別表中不帶 `carrier_path_patterns` 欄位，不參與路徑
  /// 比對（規則 3：依欄位存在與否判定，不依型別名，SPEC-006 D9）。
  final List<CarrierPathPattern>? carrierPathPatterns;

  /// 判型用的 `id_pattern`（FR-03 使用，FR-06 查詢不需要）。
  final String? idPattern;

  /// 完整性集合（FR-04 `lostFields` 使用，FR-06 查詢不需要）。
  final Set<String> completenessFields;
}

/// 型別表：型別名稱對條目的對照。
class TypeTable {
  const TypeTable(this.nodeTypes);

  final Map<String, NodeTypeEntry> nodeTypes;

  /// 只回傳帶 `carrierPathPatterns` 欄位的型別（規則 3）。
  Iterable<NodeTypeEntry> get pathParticipatingTypes =>
      nodeTypes.values.where((entry) => entry.carrierPathPatterns != null);
}
