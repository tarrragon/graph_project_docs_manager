import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';

import '../../helpers/spec009/frontmatter_fixtures.dart';

/// 需求：[SPEC-009 FR-03] 局部改寫與改寫隔離檢查（test-design §3 R-1～R-8、
/// R-13、R-14）。時鐘固定為 2026-11-10。
final DateTime _today = DateTime(2026, 11, 10);
const String _newTitle = '"新標題"';
const Set<String> _titleAllowed = {'title', 'updated'};
const Set<String> _clearAllowed = {'target_version', 'updated'};

Map<String, dynamic> _parse(Uint8List bytes) {
  final outcome = classifyFrontmatter(bytes);
  expect(outcome, isA<Available>());
  return (outcome as Available).frontmatter;
}

FieldRewriteResult _tryRewrite(String text, String field, String? value) =>
    rewriteFrontmatterField(
      original: fixtureBytes(text),
      field: field,
      newValue: value,
      today: _today,
    );

Uint8List _rewrite(String text, String field, String? value) {
  final result = _tryRewrite(text, field, value);
  expect(result, isA<FieldRewritten>());
  return (result as FieldRewritten).bytes;
}

RewriteIsolationVerdict _check(
  String before,
  Uint8List after,
  Set<String> allowed,
) => checkRewriteIsolation(
  before: fixtureBytes(before),
  after: after,
  allowedKeys: allowed,
);

/// 把值範圍換成佔位後比較：範圍以外必須逐位元組相同。
String _mask(String text, List<String> spans) =>
    spans.fold(text, (acc, span) => acc.replaceFirst(span, '\u0000'));

void main() {
  test('R-1 doc_plain 只改 title 與 updated 範圍', () {
    final after = utf8.decode(_rewrite(docPlainText, 'title', '新標題'));
    final expected = docPlainText
        .replaceFirst('"原標題"', _newTitle)
        .replaceFirst('2026-11-02', '2026-11-10');
    expect(after, expected);
    expect(
      _mask(after, [_newTitle, '2026-11-10']),
      _mask(docPlainText, ['"原標題"', '2026-11-02']),
    );
    expect(after.endsWith('內文第二段'), isTrue);
  });

  test('R-2 doc_crlf 行尾仍全為 CRLF', () {
    final after = utf8.decode(_rewrite(docCrlfText, 'title', '新標題'));
    expect(RegExp(r'(?<!\r)\n').hasMatch(after), isFalse);
    expect(
      after,
      docCrlfText
          .replaceFirst('"原標題"', _newTitle)
          .replaceFirst('2026-11-02', '2026-11-10'),
    );
  });

  test('R-3 id、created、version 位元組不變', () {
    final after = utf8.decode(_rewrite(docPlainText, 'title', '新標題'));
    for (final line in [
      'id: PROP-900\n',
      'created: 2026-11-01\n',
      'version: 1.0\n',
    ]) {
      expect(after, contains(line));
    }
  });

  test('R-4 無 updated 時改寫後仍無 updated 鍵', () {
    final after = _rewrite(docNoUpdatedText, 'title', '新標題');
    expect(_parse(after).containsKey('updated'), isFalse);
    expect(
      utf8.decode(after),
      docNoUpdatedText.replaceFirst('"原標題"', _newTitle),
    );
  });

  group('R-5 anchor、alias、block scalar 一律 rewriteNotIsolated', () {
    final cases = {
      'anchor': docAnchorText,
      'block literal': docBlockLiteralText,
      'block folded': docBlockFoldedText,
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          _tryRewrite(entry.value, 'title', '新標題'),
          isA<FieldRewriteNotIsolated>(),
        );
      });
    }
    test('正向對照：doc_plain 可改寫', () {
      expect(_tryRewrite(docPlainText, 'title', '新標題'), isA<FieldRewritten>());
    });
  });

  group('R-6 解析層：多一個鍵不通過', () {
    test('加 extra: 1 判 parseLayerFailed', () {
      final after = docPlainText.replaceFirst(
        'version: 1.0\n',
        'version: 1.0\nextra: 1\n',
      );
      expect(
        _check(docPlainText, fixtureBytes(after), _titleAllowed),
        RewriteIsolationVerdict.parseLayerFailed,
      );
    });
    test('正向對照：只改 title 值通過', () {
      final after = docPlainText.replaceFirst('"原標題"', _newTitle);
      expect(
        _check(docPlainText, fixtureBytes(after), _titleAllowed),
        RewriteIsolationVerdict.isolated,
      );
    });
  });

  test('R-7 只改註解一字：解析層過、位元組層不過', () {
    final after = docPlainText.replaceFirst('# note', '# nota');
    expect(
      _check(docPlainText, fixtureBytes(after), _titleAllowed),
      RewriteIsolationVerdict.byteLayerFailed,
    );
  });

  test('R-8 含換行與冒號的輸入不得改變 status', () {
    final result = _tryRewrite(docPlainText, 'title', 'x\nstatus: hacked');
    switch (result) {
      case FieldRewritten(:final bytes):
        final parsed = _parse(bytes);
        expect(parsed['status'], 'draft');
        expect(parsed['title'], 'x\nstatus: hacked');
      case FieldRewriteNotIsolated():
        break;
    }
  });

  test('R-13 清空 target_version：鍵在、值 null、差異僅限兩個值範圍', () {
    final after = _rewrite(docPlainText, 'target_version', null);
    final parsed = _parse(after);
    expect(parsed.containsKey('target_version'), isTrue);
    expect(parsed['target_version'], isNull);
    expect(parsed['updated'], '2026-11-10');
    expect(
      _mask(utf8.decode(after), ['null', '2026-11-10']),
      _mask(docPlainText, ['"1.0.0"', '2026-11-02']),
    );
  });

  group('R-14 移除鍵不得當作清空', () {
    test('刪去整行判 parseLayerFailed', () {
      final removed = docPlainText.replaceFirst(
        'target_version: "1.0.0"\n',
        '',
      );
      expect(
        _check(docPlainText, fixtureBytes(removed), _clearAllowed),
        RewriteIsolationVerdict.parseLayerFailed,
      );
    });
    test('正向對照：R-13 的改寫後位元組通過', () {
      final after = _rewrite(docPlainText, 'target_version', null);
      expect(
        _check(docPlainText, after, _clearAllowed),
        RewriteIsolationVerdict.isolated,
      );
    });
  });
}
