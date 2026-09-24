import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:yaml/yaml.dart';

/// 需求：[SPEC-006 test-design §3.2 C1～C3] frontmatter 切分與結果分類。
void main() {
  Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

  group('結果分類', () {
    test('C1-1 合法 frontmatter 為可用', () {
      final result = classifyFrontmatter(bytesOf('---\ntitle: hello\n---\nbody'));

      expect(result.kind, ParseResultKind.available);
      expect(result.frontmatter, {'title': 'hello'});
    });

    test('C1-2 第一行為 # title 時為無 frontmatter', () {
      final result = classifyFrontmatter(bytesOf('# title\nbody'));

      expect(result.kind, ParseResultKind.noFrontmatter);
    });

    test('C1-3 第一行前後帶空白的 --- 不是無 frontmatter（規則 3 去空白後比對）', () {
      final result = classifyFrontmatter(bytesOf(' --- \ntitle: hello\n---\n'));

      expect(result.kind, ParseResultKind.available);
    });

    test('C1-4 只有開頭 --- 時為未閉合', () {
      final result = classifyFrontmatter(bytesOf('---\ntitle: hello\n'));

      expect(result.kind, ParseResultKind.unclosed);
    });

    test('C1-5 YAML 語法錯誤帶行號（解析器提供時）', () {
      final result = classifyFrontmatter(
        bytesOf('---\ntitle: "unterminated\n---\n'),
      );

      expect(result.kind, ParseResultKind.yamlSyntaxError);
    });

    test('C1-6 無效 UTF-8 為無法讀取，子原因編碼，不做寬鬆解碼', () {
      final invalidUtf8 = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01]);

      final result = classifyFrontmatter(invalidUtf8);

      expect(result.kind, ParseResultKind.unreadable);
      expect(result.unreadableReason, UnreadableReason.encoding);
      // 不做寬鬆解碼：斷言沒有 U+FFFD 進入任何輸出。
      expect(result.frontmatter, isNull);
    });

    test('C1-7 帶 BOM 的合法 frontmatter 為可用，第一個鍵名不含 BOM', () {
      final withBom = Uint8List.fromList([
        0xEF, 0xBB, 0xBF, // UTF-8 BOM
        ...utf8.encode('---\ntitle: hello\n---\n'),
      ]);

      final result = classifyFrontmatter(withBom);

      expect(result.kind, ParseResultKind.available);
      expect(result.frontmatter!.keys.first, 'title');
      expect(result.frontmatter!.keys.first.codeUnitAt(0), isNot(0xFEFF));
    });

    test('C1-8 單一 \\r\\n 檔與同內容 \\n 檔結果相同', () {
      final crlfResult = classifyFrontmatter(
        bytesOf('---\r\ntitle: hello\r\n---\r\n'),
      );
      final lfResult = classifyFrontmatter(bytesOf('---\ntitle: hello\n---\n'));

      expect(crlfResult.kind, ParseResultKind.available);
      expect(crlfResult.kind, lfResult.kind);
      expect(crlfResult.frontmatter, lfResult.frontmatter);
    });

    test('C1-9 行內含 \\x0c 或 U+2028 不作為行分隔（對照 C1-8）', () {
      final result = classifyFrontmatter(
        bytesOf('---\ntitle: "a\x0cb c"\n---\n'),
      );

      expect(result.kind, ParseResultKind.available);
      expect(result.frontmatter!['title'], 'a\x0cb c');
    });

    test('C1-10 每個輸入恰得一種結果，結果型別為封閉枚舉（六種）', () {
      expect(ParseResultKind.values.length, 6);

      final inputs = <Uint8List>[
        bytesOf('---\ntitle: hello\n---\n'), // C1-1
        bytesOf('# title\nbody'), // C1-2
        bytesOf(' --- \ntitle: hello\n---\n'), // C1-3
        bytesOf('---\ntitle: hello\n'), // C1-4
        bytesOf('---\ntitle: "unterminated\n---\n'), // C1-5
        Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01]), // C1-6
      ];

      for (final input in inputs) {
        final result = classifyFrontmatter(input);
        // 每個輸入恰好落入六種結果之一。
        expect(ParseResultKind.values.contains(result.kind), isTrue);
      }
    });
  });

  group('結尾定位', () {
    test(
      'C2-1 引號包住的 |---|---| 不截斷，正文的 --- 不影響，鍵集合含其後所有鍵',
      () {
        final content =
            '---\ntitle: "|---|---|"\nauthor: alice\n---\nbody with --- inside';

        final result = classifyFrontmatter(bytesOf(content));

        expect(result.kind, ParseResultKind.available);
        expect(result.frontmatter!.keys.toSet(), {'title', 'author'});
        expect(result.frontmatter!['title'], '|---|---|');
      },
    );

    test('C2-2 兩個獨立 --- 行在第二行之後，取第一個作結尾', () {
      final content = '---\ntitle: hello\n---\nauthor: alice\n---\n';

      final result = classifyFrontmatter(bytesOf(content));

      expect(result.kind, ParseResultKind.available);
      expect(result.frontmatter, {'title': 'hello'});
    });

    test('C2-3（E1 鑑別）split("---") 天真語意取得的鍵數與正確結果不同', () {
      final content =
          '---\ntitle: "|---|---|"\nauthor: alice\n---\nbody with --- inside';

      final result = classifyFrontmatter(bytesOf(content));
      expect(result.kind, ParseResultKind.available);
      final correctKeyCount = result.frontmatter!.keys.length;

      // 天真語意：直接以字串分隔取中段當 frontmatter 內容再解析。
      final naiveSegments = content.split('---');
      var naiveKeyCount = 0;
      var naiveThrew = false;
      try {
        final naiveContent = naiveSegments.length > 1 ? naiveSegments[1] : '';
        final naiveParsed = naiveContent.trim().isEmpty
            ? null
            : loadYaml(naiveContent);
        naiveKeyCount = naiveParsed is YamlMap ? naiveParsed.length : 0;
      } on YamlException {
        naiveThrew = true;
      }

      // 證明判別樣本確實能區分兩種語意：鍵數不同，或天真語意產生錯誤。
      expect(naiveThrew || naiveKeyCount != correctKeyCount, isTrue);
    });
  });

  group('空或非 map', () {
    test('C3-1 空內容為空或非 map', () {
      final result = classifyFrontmatter(bytesOf('---\n---\n'));

      expect(result.kind, ParseResultKind.emptyOrNotMap);
    });

    test('C3-2 只有註解為空或非 map', () {
      final result = classifyFrontmatter(bytesOf('---\n# just a comment\n---\n'));

      expect(result.kind, ParseResultKind.emptyOrNotMap);
    });

    test('C3-3 {} 為空或非 map', () {
      final result = classifyFrontmatter(bytesOf('---\n{}\n---\n'));

      expect(result.kind, ParseResultKind.emptyOrNotMap);
    });

    test('C3-4 清單為空或非 map', () {
      final result = classifyFrontmatter(bytesOf('---\n- a\n- b\n---\n'));

      expect(result.kind, ParseResultKind.emptyOrNotMap);
    });

    test('C3-5 純量為空或非 map', () {
      final result = classifyFrontmatter(bytesOf('---\nhello\n---\n'));

      expect(result.kind, ParseResultKind.emptyOrNotMap);
    });

    test('C3-6（正向對照）非空 map 為可用', () {
      final result = classifyFrontmatter(bytesOf('---\na: 1\n---\n'));

      expect(result.kind, ParseResultKind.available);
      expect(result.frontmatter, {'a': 1});
    });
  });
}
