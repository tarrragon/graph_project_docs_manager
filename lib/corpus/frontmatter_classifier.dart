import 'dart:convert';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import 'parse_outcome.dart';

/// Unicode BOM 字元（U+FEFF），需求：[SPEC-006 FR-01 規則 1] 先移除。
const String _bomChar = '﻿';

/// frontmatter 開閉分隔線的字面值，需求：[SPEC-006 FR-01 規則 3、4]。
const String _delimiter = '---';

/// 需求：[SPEC-006 FR-01、FR-05] 以位元組為輸入，切出 frontmatter 並分類結果。
///
/// 切分方式與框架既有函式
/// （`.claude/skills/doc/doc_system/core/frontmatter_parser.py`）逐行語意相同：
/// 去 BOM、行分隔只認 `\n` 與 `\r\n`、第一行須為 `---`、取第一個結尾 `---`。
/// 六種結果恰好命中一種，見 [ParseResultKind]。
ParseOutcome classifyFrontmatter(Uint8List bytes) {
  final decoded = _decodeUtf8Strict(bytes);
  if (decoded == null) {
    return ParseOutcome.unreadable(UnreadableReason.encoding);
  }

  final lines = _splitLines(_stripBom(decoded));
  if (lines.isEmpty || lines.first.trim() != _delimiter) {
    return ParseOutcome.noFrontmatter();
  }

  final closingIndex = _findClosingDelimiterIndex(lines);
  if (closingIndex == null) {
    return ParseOutcome.unclosed();
  }

  final contentLines = lines.sublist(1, closingIndex);
  return _parseYamlContent(contentLines);
}

/// 需求：[SPEC-006 FR-01 規則 1] 嚴格 UTF-8 解碼；無法解碼回傳 null 交由
/// 呼叫端轉為「無法讀取（編碼）」，不做寬鬆解碼（避免亂碼進入圖譜，C1-6）。
String? _decodeUtf8Strict(Uint8List bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return null;
  }
}

/// 需求：[SPEC-006 FR-01 規則 1] 移除開頭 BOM，確保第一個鍵名不含 BOM（C1-7）。
String _stripBom(String text) =>
    text.startsWith(_bomChar) ? text.substring(_bomChar.length) : text;

/// 需求：[SPEC-006 FR-01 規則 2] 行分隔只認 `\n` 與 `\r\n`。以 `\n` 切分後
/// 移除每行結尾的 `\r`，不把 `\x0c`、U+2028 等框架 `splitlines()` 認得的
/// 其他分隔字元當作換行（C1-9）。
List<String> _splitLines(String text) {
  return text.split('\n').map((line) {
    if (line.endsWith('\r')) {
      return line.substring(0, line.length - 1);
    }
    return line;
  }).toList();
}

/// 需求：[SPEC-006 FR-01 規則 4] 從第二行往下找第一個去除前後空白後等於
/// `---` 的行作為結尾；找不到回傳 null。
int? _findClosingDelimiterIndex(List<String> lines) {
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() == _delimiter) {
      return i;
    }
  }
  return null;
}

/// 需求：[SPEC-006 FR-01 規則 5、6] 以 YAML 解析分隔線之間的內容，禁止字串
/// 切分（不使用 `split('---')`，直接對定位出的行範圍解析）。結果分類：
/// 語法錯誤 → yamlSyntaxError；非空 map → available；其餘 → emptyOrNotMap。
ParseOutcome _parseYamlContent(List<String> contentLines) {
  final content = contentLines.join('\n');
  Object? parsed;
  try {
    parsed = loadYaml(content);
  } on YamlException catch (e) {
    return ParseOutcome.yamlSyntaxError(lineNumber: _errorLineNumber(e));
  }

  if (parsed is YamlMap && parsed.isNotEmpty) {
    return ParseOutcome.available(Map<String, dynamic>.from(parsed));
  }
  return ParseOutcome.emptyOrNotMap();
}

/// 需求：[SPEC-006 FR-01] YAML 語法錯誤帶行號（解析器提供時）。內容區段的
/// 第一行對應到原始檔案的第 2 行（第 1 行是開頭 `---`），故 1-indexed 換算
/// 為 `span.start.line + 2`。
int? _errorLineNumber(YamlException e) {
  final span = e.span;
  if (span == null) {
    return null;
  }
  return span.start.line + 2;
}
