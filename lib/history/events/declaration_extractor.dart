// SPEC-008 FR-03：從 frontmatter 文字抽出該路徑的全部宣告。
// 邊型、欄位、反向欄位取自 Schema 邊型表，不在程式內寫死（SPEC-007 D6）。
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:yaml/yaml.dart';

const String _idField = 'id'; // i18n-exempt: frontmatter 欄位名

/// 一筆宣告：某邊型的某欄位列出的一個字串值。
class Declaration {
  const Declaration({
    required this.edgeType,
    required this.field,
    required this.value,
  });

  final EdgeTypeEntry edgeType;
  final String field;
  final String value;
}

/// 單一路徑的抽取結果。
class DeclarationExtraction {
  const DeclarationExtraction({
    required this.nodeId,
    required this.declarations,
    this.nonStringValues = 0,
    this.missingId = false,
    this.parseFailed = false,
  });

  /// 無 frontmatter：沒有宣告。
  static const DeclarationExtraction empty = DeclarationExtraction(
    nodeId: null,
    declarations: [],
  );

  final String? nodeId;
  final List<Declaration> declarations;

  /// 「非字串值」計數（FR-03 規則 4）。
  final int nonStringValues;

  /// 有 frontmatter 但無字串 `id`：計入「無 ID 檔案」（FR-03 規則 1）。
  final bool missingId;

  /// YAML 無法解析：呼叫端沿用前一版宣告。
  final bool parseFailed;
}

class DeclarationExtractor {
  /// [activeEdgeTypes]：使用中邊型（SPEC-007〈用詞〉）。
  /// [closedByIdPatterns]：`closed_by` 略過規則的主圖節點型別 id_pattern
  /// （呼叫端已排除 FlowStep，同 SPEC-007 FR-03）。
  DeclarationExtractor({
    required Iterable<EdgeTypeEntry> activeEdgeTypes,
    required Iterable<RegExp> closedByIdPatterns,
  }) : _edgeTypes = List.unmodifiable(activeEdgeTypes),
       _closedByPatterns = List.unmodifiable(closedByIdPatterns);

  final List<EdgeTypeEntry> _edgeTypes;
  final List<RegExp> _closedByPatterns;

  /// 需求：[SPEC-008 FR-03] [frontmatterText] 為 `null` 表示無 frontmatter。
  DeclarationExtraction extract(String? frontmatterText) {
    if (frontmatterText == null) return DeclarationExtraction.empty;
    final Object? doc;
    try {
      doc = loadYaml(frontmatterText);
    } on YamlException {
      return const DeclarationExtraction(
        nodeId: null,
        declarations: [],
        parseFailed: true,
      );
    }
    final id = doc is Map ? doc[_idField] : null;
    if (doc is! Map || id is! String) {
      return const DeclarationExtraction(
        nodeId: null,
        declarations: [],
        missingId: true,
      );
    }
    return _collect(doc, id);
  }

  DeclarationExtraction _collect(Map<Object?, Object?> doc, String id) {
    final out = <Declaration>[];
    var nonString = 0;
    for (final edge in _edgeTypes) {
      for (final field in _fieldsOf(edge)) {
        final values = _valuesOf(doc[field], field == edge.reverseField);
        nonString += values.nonString;
        for (final v in values.strings) {
          if (_skippedClosedBy(edge, v)) continue;
          out.add(Declaration(edgeType: edge, field: field, value: v));
        }
      }
    }
    return DeclarationExtraction(
      nodeId: id,
      declarations: out,
      nonStringValues: nonString,
    );
  }

  Iterable<String> _fieldsOf(EdgeTypeEntry edge) => {
    edge.forwardField,
    ?edge.reverseField,
  };

  bool _skippedClosedBy(EdgeTypeEntry edge, String value) =>
      edge.name == closedByEdgeTypeName &&
      !_closedByPatterns.any((p) => p.hasMatch(value));

  /// 純量一個值、清單每項一個值、反向欄位 map 每個子鍵清單每項一個值；
  /// `null`、空清單、空字串沒有值。
  ({List<String> strings, int nonString}) _valuesOf(
    Object? raw,
    bool allowMap,
  ) {
    final strings = <String>[];
    var nonString = 0;
    void take(Object? item) {
      if (item == null) return;
      if (item is String) {
        if (item.isNotEmpty) strings.add(item);
      } else {
        nonString++;
      }
    }

    void takeAll(Object? v) {
      if (v is List) {
        v.forEach(take);
      } else {
        take(v);
      }
    }

    if (raw is Map && allowMap) {
      raw.values.forEach(takeAll);
    } else {
      takeAll(raw);
    }
    return (strings: strings, nonString: nonString);
  }
}
