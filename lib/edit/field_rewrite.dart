import 'dart:convert';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:yaml/yaml.dart';

const String _updatedKey = 'updated';
const String _delimiter = '---';
const List<int> _bom = [0xEF, 0xBB, 0xBF];

/// 一次改寫的結果。
sealed class FieldRewriteResult {
  const FieldRewriteResult();
}

/// 改寫成功，[bytes] 為改寫後的完整檔案位元組。
final class FieldRewritten extends FieldRewriteResult {
  const FieldRewritten(this.bytes);
  final Uint8List bytes;
}

/// 無法安全改寫，對應 `blocked(rewriteNotIsolated)`。
final class FieldRewriteNotIsolated extends FieldRewriteResult {
  const FieldRewriteNotIsolated();
}

/// 兩道隔離檢查的判定。
enum RewriteIsolationVerdict { isolated, parseLayerFailed, byteLayerFailed }

/// 需求：[SPEC-009 FR-03] 局部改寫：只換掉 [field] 與（已存在的）`updated`
/// 的值所在位元組範圍，其餘位元組原樣保留；[newValue] 為 `null` 表示清空，
/// 寫成 YAML 的 `null`，不寫空字串也不移除鍵。anchor、alias、block scalar、
/// 非純量值、目標鍵缺席，以及任一道隔離檢查不通過，都回傳
/// [FieldRewriteNotIsolated]。
FieldRewriteResult rewriteFrontmatterField({
  required Uint8List original,
  required String field,
  required String? newValue,
  required DateTime today,
}) {
  final located = _locate(original);
  final replacements = located == null
      ? null
      : _replacementsFor(located, field, newValue, today);
  if (located == null || replacements == null) {
    return const FieldRewriteNotIsolated();
  }
  final rewritten = _splice(located, replacements);
  final verdict = checkRewriteIsolation(
    before: original,
    after: rewritten,
    allowedKeys: {field, _updatedKey},
  );
  if (verdict != RewriteIsolationVerdict.isolated) {
    return const FieldRewriteNotIsolated();
  }
  return FieldRewritten(rewritten);
}

/// 需求：[SPEC-009 FR-03] 改寫隔離檢查，兩道都通過才回傳 isolated。
/// 解析層：以 Corpus 的 [classifyFrontmatter] 解析前後位元組，改寫後須可用，
/// 且只有 [allowedKeys] 內的鍵的值改變（鍵集合須相同）。位元組層：扣除
/// [allowedKeys] 的值所在範圍後，其餘位元組逐位元組相同。
RewriteIsolationVerdict checkRewriteIsolation({
  required Uint8List before,
  required Uint8List after,
  required Set<String> allowedKeys,
}) {
  if (!_parseLayerIsolated(before, after, allowedKeys)) {
    return RewriteIsolationVerdict.parseLayerFailed;
  }
  if (!_byteLayerIsolated(before, after, allowedKeys)) {
    return RewriteIsolationVerdict.byteLayerFailed;
  }
  return RewriteIsolationVerdict.isolated;
}

bool _parseLayerIsolated(
  Uint8List before,
  Uint8List after,
  Set<String> allowedKeys,
) {
  final b = classifyFrontmatter(before);
  final a = classifyFrontmatter(after);
  if (b is! Available || a is! Available) {
    return false;
  }
  final beforeMap = b.frontmatter;
  final afterMap = a.frontmatter;
  if (beforeMap.length != afterMap.length ||
      !beforeMap.keys.every(afterMap.containsKey)) {
    return false;
  }
  return beforeMap.keys
      .where((k) => !allowedKeys.contains(k))
      .every((k) => _deepEqual(beforeMap[k], afterMap[k]));
}

bool _deepEqual(Object? x, Object? y) {
  if (x is Map && y is Map) {
    return x.length == y.length &&
        x.keys.every((k) => y.containsKey(k) && _deepEqual(x[k], y[k]));
  }
  if (x is List && y is List) {
    return x.length == y.length &&
        List.generate(x.length, (i) => _deepEqual(x[i], y[i])).every((e) => e);
  }
  return x == y;
}

bool _byteLayerIsolated(
  Uint8List before,
  Uint8List after,
  Set<String> allowedKeys,
) {
  final b = _locate(before);
  final a = _locate(after);
  if (b == null || a == null || b.hasBom != a.hasBom) {
    return false;
  }
  return _outside(b.text, _valueSpans(b, allowedKeys)) ==
      _outside(a.text, _valueSpans(a, allowedKeys));
}

/// 扣除各範圍後的剩餘文字；範圍位置以佔位字元保留，避免兩範圍相鄰時誤判。
String _outside(String text, List<_Span> spans) {
  final sorted = [...spans]..sort((x, y) => x.start.compareTo(y.start));
  final buffer = StringBuffer();
  var cursor = 0;
  for (final span in sorted) {
    buffer
      ..write(text.substring(cursor, span.start))
      ..write('\u0000');
    cursor = span.end;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

List<_Span> _valueSpans(_Located located, Set<String> keys) => [
  for (final key in keys)
    if (located.valueNodeOf(key) case final node?) located.spanOf(node),
];

List<_Replacement>? _replacementsFor(
  _Located located,
  String field,
  String? newValue,
  DateTime today,
) {
  final target = located.rewritableNodeOf(field);
  if (target == null) {
    return null;
  }
  final replacements = [
    _Replacement(located.spanOf(target), _encodeValue(newValue)),
  ];
  if (field == _updatedKey || located.valueNodeOf(_updatedKey) == null) {
    return replacements;
  }
  final updated = located.rewritableNodeOf(_updatedKey);
  if (updated == null) {
    return null;
  }
  replacements.add(_Replacement(located.spanOf(updated), _encodeDate(today)));
  return replacements;
}

/// 字串一律寫成雙引號純量（JSON 字串即合法的 YAML 雙引號純量），換行與
/// 冒號都被跳脫，不會被解讀為新鍵；`null` 寫成 YAML 的 `null`。
String _encodeValue(String? value) =>
    value == null ? 'null' : jsonEncode(value);

String _encodeDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$year-${two(date.month)}-${two(date.day)}';
}

Uint8List _splice(_Located located, List<_Replacement> replacements) {
  final sorted = [...replacements]
    ..sort((x, y) => y.span.start.compareTo(x.span.start));
  var text = located.text;
  for (final r in sorted) {
    text = text.replaceRange(r.span.start, r.span.end, r.text);
  }
  return Uint8List.fromList([
    if (located.hasBom) ..._bom,
    ...utf8.encode(text),
  ]);
}

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;
}

class _Replacement {
  const _Replacement(this.span, this.text);
  final _Span span;
  final String text;
}

/// 已定位 frontmatter 的文件：[text] 為去 BOM 後的全文，[contentStart] 為
/// frontmatter 內容在全文中的起點，[root] 為內容的 YAML 根節點。
class _Located {
  _Located(this.text, this.hasBom, this.contentStart, this.root);
  final String text;
  final bool hasBom;
  final int contentStart;
  final YamlMap root;

  MapEntry<dynamic, YamlNode>? _entryOf(String key) {
    for (final entry in root.nodes.entries) {
      final k = entry.key;
      if (k is YamlScalar && k.value == key) {
        return entry;
      }
    }
    return null;
  }

  YamlNode? valueNodeOf(String key) => _entryOf(key)?.value;

  _Span spanOf(YamlNode node) => _Span(
    contentStart + node.span.start.offset,
    contentStart + node.span.end.offset,
  );

  /// 可安全改寫的值節點：須為非 block 的純量，且不帶 anchor／alias／tag。
  YamlNode? rewritableNodeOf(String key) {
    final entry = _entryOf(key);
    final node = entry?.value;
    if (entry == null || node is! YamlScalar || _isBlockOrAliased(entry)) {
      return null;
    }
    final span = spanOf(node);
    final keyEnd = contentStart + (entry.key as YamlScalar).span.end.offset;
    if (keyEnd > span.start || span.start >= span.end) {
      return null;
    }
    final lead = text.substring(keyEnd, span.start);
    return _hasIndicator(lead + text[span.start]) ? null : node;
  }

  bool _isBlockOrAliased(MapEntry<dynamic, YamlNode> entry) {
    final node = entry.value as YamlScalar;
    final block =
        node.style == ScalarStyle.LITERAL || node.style == ScalarStyle.FOLDED;
    final shared = root.nodes.entries.any(
      (e) => !identical(e.key, entry.key) && identical(e.value, node),
    );
    return block || shared;
  }

  bool _hasIndicator(String text) => RegExp('[&*!|>]').hasMatch(text);
}

/// 切出 frontmatter 內容並以 [loadYamlNode] 取得節點；任何一步失敗回傳 null。
_Located? _locate(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == _bom[0] &&
      bytes[1] == _bom[1] &&
      bytes[2] == _bom[2];
  final String text;
  try {
    text = utf8.decode(
      hasBom ? bytes.sublist(3) : bytes,
      allowMalformed: false,
    );
  } on FormatException {
    return null;
  }
  final bounds = _contentBounds(text);
  if (bounds == null) {
    return null;
  }
  try {
    final node = loadYamlNode(text.substring(bounds.start, bounds.end));
    return node is YamlMap ? _Located(text, hasBom, bounds.start, node) : null;
  } on YamlException {
    return null;
  }
}

/// 內容為開頭 `---` 行之後，到第一個去空白後等於 `---` 的行之前。
_Span? _contentBounds(String text) {
  final starts = _lineStarts(text);
  if (_lineText(text, starts, 0).trim() != _delimiter) {
    return null;
  }
  for (var i = 1; i < starts.length; i++) {
    if (_lineText(text, starts, i).trim() == _delimiter) {
      return _Span(starts[1], starts[i]);
    }
  }
  return null;
}

List<int> _lineStarts(String text) {
  final starts = <int>[0];
  for (var i = text.indexOf('\n'); i >= 0; i = text.indexOf('\n', i + 1)) {
    starts.add(i + 1);
  }
  return starts;
}

String _lineText(String text, List<int> starts, int index) {
  final end = index + 1 < starts.length ? starts[index + 1] : text.length;
  return text.substring(starts[index], end).replaceAll(RegExp(r'\r?\n$'), '');
}
