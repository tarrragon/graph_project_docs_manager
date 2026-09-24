/// FR-06 型別表模型：路徑對型別查詢所需的最小資料結構（規則 1～6）。
///
/// 對應 `tracking_schema.json` 的 `node_types[].carrier_path_patterns`
/// 欄位形態（`.claude/skills/doc/doc_system/core/tracking_schema.py`）。
/// 本模型不負責讀 JSON 或內建 asset，只描述「查詢需要什麼資料」；來源
/// 判定（專案 JSON／內建表三分）屬另一票範圍（FR-06 規則 7）。
library;

/// 路徑模式具體度（規則 6）：字面段數與跨段萬用成分數的具名組合。
///
/// 取代先前的 `List<int>` 索引存取（`[0]`／`[1]` 易誤用、長度不對時只能在
/// 使用處才炸），由 `typeTableFromJson` 於解析時驗證長度並拒收不合法的
/// 原始資料（0.3.0-W3-531）。
typedef PathSpecificity = ({
  int literalSegmentCount,
  int crossSegmentWildcardCount,
});

/// 比較兩個 [PathSpecificity]（規則 6）：字面段數多者優先；相同時跨段
/// 萬用成分數少者優先。回傳值遵循 [Comparator] 慣例（負數＝`a` 優先）。
///
/// 查詢排序、取單一型別內最佳候選、判斷多型別是否平手三處共用本函式，
/// 具體度比較邏輯只定義一次（0.3.0-W3-531，先前三處各自實作易失準）。
int comparePathSpecificity(PathSpecificity a, PathSpecificity b) {
  if (a.literalSegmentCount != b.literalSegmentCount) {
    return b.literalSegmentCount - a.literalSegmentCount;
  }
  return a.crossSegmentWildcardCount - b.crossSegmentWildcardCount;
}

/// 單一路徑模式與其具體度（規則 6）。
///
/// `specificity` 由上游（`tracking_schema.py`）依路徑樣板計算並匯出，
/// 本層只讀值比較，不重算（SPEC-006-test-design.md §3.1 S2 附註）。
///
/// 建構時即編譯 [pattern] 為 [RegExp]（規則 2），查詢時重複呼叫
/// [toRegExp] 不再重新編譯。呼叫端須確保 [pattern] 可編譯——
/// `typeTableFromJson` 在解析時已驗證並拒收不合法的模式，不會建出帶壞
/// 模式的 [CarrierPathPattern]（0.3.0-W3-531）。
class CarrierPathPattern {
  CarrierPathPattern({required this.pattern, required this.specificity})
      : _compiled = RegExp(pattern);

  /// 比對相對路徑（含檔名）用的正則字串，與 `id_pattern` 同一方言
  /// （`python-re`）。ASCII 語意由 Dart [RegExp] 預設提供：未啟用
  /// `unicode` 旗標時 `\d`／`\w` 只匹配 ASCII 字元，與規則 2 的裁決一致。
  final String pattern;

  /// 具體度（規則 6）。
  final PathSpecificity specificity;

  final RegExp _compiled;

  /// 回傳建構時已編譯好的 [RegExp]，不重新編譯。
  RegExp toRegExp() => _compiled;
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
  ///
  /// 空清單（`[]`）代表欄位存在但其中所有模式在解析時皆因不合法而被拒收
  /// （或原本就沒有任何模式），仍計入「有此欄位」的型別集合，與 `null`
  /// 語意不同（0.3.0-W3-531：壞模式拒收，不影響同型別其他合法模式）。
  final List<CarrierPathPattern>? carrierPathPatterns;

  /// 判型用的 `id_pattern`（FR-03 使用，FR-06 查詢不需要）。
  ///
  /// `typeTableFromJson` 於解析時已驗證此字串可被 [RegExp] 編譯；不合法
  /// 者拒收為 `null`，不會把無法編譯的字串交給消費端（0.3.0-W3-531）。
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

  /// FR-06 路徑查詢是否可用的單一權威（規則 3、7）：至少有一個型別帶
  /// `carrierPathPatterns` 欄位時為 `true`。
  ///
  /// 先前查詢可用性散落於呼叫端各自判斷 `pathParticipatingTypes.isNotEmpty`
  /// （0.3.0-W3-531 前無單一權威）；本欄位讓消費端不需重複這個判斷式。
  bool get isPathQueryAvailable => pathParticipatingTypes.isNotEmpty;
}
