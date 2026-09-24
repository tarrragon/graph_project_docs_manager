/// IT-1 整合測試：待測實作（[classifyFrontmatter]）與凍結的框架函式輸出
/// 逐檔比對，需求：[SPEC-006 FR-01；traceability 第三軸契約 K1]。
///
/// 測資：`test/fixtures/spec006/it1/expected.json`（凍結，見同目錄
/// README.md），斷言依 `docs/spec/corpus/SPEC-006-test-design.md` §2.1
/// IT1-A1～IT1-A6。
///
/// 對照該規格描述與實際凍結測資的兩處既知偏離（README〈偏離票面之處〉）：
/// - IT1-A2「frontmatter 文字等於 `frontmatter_text`」：[classifyFrontmatter]
///   的公開介面只回傳解析後的 map（[ParseOutcome.frontmatter]），不回傳切出
///   的原始 YAML 文字（`parse_outcome.dart` 未定義此欄位）。改以語意等價
///   驗證：鍵集合相等 + `frontmatter_text` 以框架同款 YAML 解析器
///   （`package:yaml`）獨立解析後與待測結果值相等，取代不可得的原始文字
///   位元組比對。
/// - IT1-A5「每個 `samples/` 檔案恰有一筆紀錄，反之亦然」：本票測資未落地
///   為獨立 `samples/*.md` 檔案（樣本以 `content_base64` 內嵌於單一
///   `expected.json`），完整性檢查改為驗證 `expected.json` 內部的樣本組成
///   完整（IT1-S1～IT1-S8 各恰一筆、無重複名稱、真實樣本數等於
///   `discriminating_real_files_n`）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:yaml/yaml.dart';

/// 排除規則（test-design §2.1）：樣本不得含這些字元，樣本必須是合法 UTF-8。
const Set<int> _excludedLineSeparators = {
  0x0b,
  0x0c,
  0x1c,
  0x1d,
  0x1e,
  0x85,
  0x2028,
  0x2029,
};

/// SPEC-006 FR-01 六類結果名稱（與 IT-2 manifest `shape` 欄同款詞彙，見
/// test-design §2.2）對應到 [ParseResultKind] 封閉枚舉。
ParseResultKind _kindFromExpectedResult(String expectedResult) {
  switch (expectedResult) {
    case 'usable':
      return ParseResultKind.available;
    case 'no_frontmatter':
      return ParseResultKind.noFrontmatter;
    case 'unclosed':
      return ParseResultKind.unclosed;
    case 'empty_or_non_map':
      return ParseResultKind.emptyOrNotMap;
    case 'yaml_error':
      return ParseResultKind.yamlSyntaxError;
    case 'unreadable_encoding':
      return ParseResultKind.unreadable;
    default:
      throw ArgumentError('未知的 expected_result: $expectedResult');
  }
}

/// 掃描文字是否含排除字元（切分規則 2 排除清單）。
bool _containsExcludedLineSeparator(String text) =>
    text.runes.any(_excludedLineSeparators.contains);

/// 樣本清單中，`requiredNames` 有哪些不在 `presentNames` 內（完整性檢查）。
Set<String> _missingRequiredSamples(
  List<String> presentNames,
  Set<String> requiredNames,
) => requiredNames.difference(presentNames.toSet());

void main() {
  late Map<String, dynamic> fixture;
  late List<Map<String, dynamic>> samples;

  setUpAll(() {
    final file = File('test/fixtures/spec006/it1/expected.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    samples = (fixture['samples'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  });

  Uint8List bytesOf(Map<String, dynamic> sample) =>
      base64Decode(sample['content_base64'] as String);

  group('IT1-A1 結果分類等於 expected_result', () {
    test('expected.json 所列每個樣本，待測實作分類等於 expected_result', () {
      for (final sample in samples) {
        final result = classifyFrontmatter(bytesOf(sample));

        expect(
          result.kind,
          _kindFromExpectedResult(sample['expected_result'] as String),
          reason: '${sample['name']} 分類不符',
        );
      }
    });
  });

  group('IT1-A2 split 樣本的切分文字與鍵集合一致', () {
    test('framework_result 為 split 的樣本，鍵集合與語意內容相等', () {
      final splitSamples = samples.where(
        (s) => s['framework_result'] == 'split',
      );

      for (final sample in splitSamples) {
        final result = classifyFrontmatter(bytesOf(sample));
        final expectedText = sample['frontmatter_text'] as String;

        if (result.kind == ParseResultKind.available) {
          // 鍵集合相等（test-design 明文「不比值」，僅比鍵）。
          final expectedKeys = (sample['keys'] as List).cast<String>().toSet();
          expect(
            result.frontmatter!.keys.toSet(),
            expectedKeys,
            reason: '${sample['name']} 鍵集合不符',
          );

          // 語意等價驗證（見檔頭說明）：frontmatter_text 以同款 YAML 解析器
          // 獨立解析後應與待測結果值相等。
          final reparsed = loadYaml(expectedText);
          expect(
            reparsed is YamlMap
                ? Map<String, dynamic>.from(reparsed)
                : reparsed,
            result.frontmatter,
            reason: '${sample['name']} frontmatter_text 語意不等價',
          );
        } else {
          // emptyOrNotMap／yamlSyntaxError：frontmatter_text 存在但不解析為
          // 非空 map，驗證兩邊在「是否為非空 map」這件事上一致。
          Object? reparsed;
          var threw = false;
          try {
            reparsed = loadYaml(expectedText);
          } on YamlException {
            threw = true;
          }
          final expectedAvailable = !threw && reparsed is YamlMap && reparsed.isNotEmpty;
          expect(
            expectedAvailable,
            isFalse,
            reason: '${sample['name']} frontmatter_text 應非可用內容',
          );
        }
      }
    });
  });

  group('IT1-A3 判別樣本在天真語意下有鑑別力', () {
    test('真實語料樣本：naive_yaml_error 為 true，或天真鍵數小於待測實作鍵數', () {
      final realSamples = samples.where((s) => s['source'] != 'synthetic');

      for (final sample in realSamples) {
        final result = classifyFrontmatter(bytesOf(sample));
        expect(result.kind, ParseResultKind.available, reason: '${sample['name']} 應為可用');

        final naiveYamlError = sample['naive_yaml_error'] as bool;
        final naiveKeyCount = sample['naive_key_count'] as int?;
        final actualKeyCount = result.frontmatter!.keys.length;

        final hasDiscriminatingPower =
            naiveYamlError ||
            (naiveKeyCount != null && naiveKeyCount < actualKeyCount);

        expect(
          hasDiscriminatingPower,
          isTrue,
          reason: '${sample['name']} 天真語意下不具鑑別力（FR-01 規則 6 失效）',
        );
      }
    });
  });

  group('IT1-A4 排除字元與合法 UTF-8（守衛，E2）', () {
    test('全部樣本原始位元組不含排除字元且為合法 UTF-8', () {
      for (final sample in samples) {
        final bytes = bytesOf(sample);
        late final String decoded;
        expect(
          () => decoded = utf8.decode(bytes, allowMalformed: false),
          returnsNormally,
          reason: '${sample['name']} 應為合法 UTF-8',
        );
        expect(
          _containsExcludedLineSeparator(decoded),
          isFalse,
          reason: '${sample['name']} 不應含排除字元',
        );
      }
    });

    test('正向對照：含 U+2028 的字串會被排除檢查攔下', () {
      const withLineSeparator = 'title: a b';

      expect(_containsExcludedLineSeparator(withLineSeparator), isTrue);
    });
  });

  group('IT1-A5 樣本組成完整性（守衛，E2）', () {
    const requiredSyntheticNames = {
      'IT1-S1',
      'IT1-S2',
      'IT1-S3',
      'IT1-S4',
      'IT1-S5',
      'IT1-S6',
      'IT1-S7',
      'IT1-S8',
    };

    test('IT1-S1～IT1-S8 各恰一筆、無重複名稱，真實樣本數等於凍結計數', () {
      final names = samples.map((s) => s['name'] as String).toList();

      expect(names.toSet().length, names.length, reason: '樣本名稱不應重複');
      expect(
        _missingRequiredSamples(names, requiredSyntheticNames),
        isEmpty,
        reason: '合成樣本 IT1-S1～IT1-S8 應各恰一筆',
      );

      final realCount = samples.where((s) => s['source'] != 'synthetic').length;
      expect(realCount, fixture['discriminating_real_files_n']);
    });

    test('正向對照：缺一筆合成樣本的清單，完整性檢查回報缺漏', () {
      final namesMissingOne = samples
          .map((s) => s['name'] as String)
          .where((name) => name != 'IT1-S3')
          .toList();

      final missing = _missingRequiredSamples(
        namesMissingOne,
        requiredSyntheticNames,
      );

      expect(missing, {'IT1-S3'});
    });
  });

  group('IT1-A6 來源統計', () {
    test('至少一筆 corpus 來源且 IT1-A3 對它成立；IT1-S1～IT1-S7 各至少一筆', () {
      final corpusSamples = samples.where(
        (s) => (s['source'] as String).startsWith('corpus:'),
      );
      expect(corpusSamples, isNotEmpty);

      for (final sample in corpusSamples) {
        final result = classifyFrontmatter(bytesOf(sample));
        expect(result.kind, ParseResultKind.available);
        final naiveYamlError = sample['naive_yaml_error'] as bool;
        final naiveKeyCount = sample['naive_key_count'] as int?;
        final actualKeyCount = result.frontmatter!.keys.length;
        expect(
          naiveYamlError ||
              (naiveKeyCount != null && naiveKeyCount < actualKeyCount),
          isTrue,
        );
      }

      final syntheticNames = samples
          .where((s) => s['source'] == 'synthetic')
          .map((s) => s['name'] as String)
          .toSet();
      for (final expectedName in [
        'IT1-S1',
        'IT1-S2',
        'IT1-S3',
        'IT1-S4',
        'IT1-S5',
        'IT1-S6',
        'IT1-S7',
      ]) {
        expect(syntheticNames.contains(expectedName), isTrue, reason: '$expectedName 應至少一筆');
      }
    });
  });
}
