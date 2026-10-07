// 契約：框架 tracking_schema.json 的產生版本不得高於 App 內建版本。
//
// 讀真實檔案（非 fixture）。重產 JSON 後忘記改回產生版本時，現有 K4 只比
// 兩份內建資產、漂移測試只比 VERSION 與內建，沒有測試比對框架 JSON 本身。
// 判定沿用 classifySchemaVersion，不另寫版本比較。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/schema_version.dart';

const _frameworkSchemaPath =
    '.claude/skills/doc/doc_system/core/tracking_schema.json';
const _builtinSchemaVersionPath = 'assets/schema/builtin_schema_version.json';

String? _readVersionField(String path) {
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return schemaVersionOf(json);
}

/// 斷言邏輯抽出供 E2 正向對照共用；失敗訊息指出兩條處置路徑。
void _expectInKnownRange(String? version, String builtin) {
  final result = classifySchemaVersion(version, builtin);
  expect(
    result,
    isA<InKnownRange>(),
    reason:
        '框架 tracking_schema.json 產生版本 $version 相對 App 內建版本 '
        '$builtin 為 ${result.runtimeType}。處置路徑二擇一：'
        '(a) 把框架 JSON 的 schema_generated_at_framework_version 改回與內建一致'
        '（重產時未保留產生版本）；'
        '(b) 同步更新兩份內建資產（assets/schema/builtin_tracking_schema.json '
        '整份覆寫、assets/schema/builtin_schema_version.json 版本欄），並跑 K4。',
  );
}

void main() {
  final builtin = _readVersionField(_builtinSchemaVersionPath)!;

  test('框架 tracking_schema.json 產生版本相對內建版本為 InKnownRange', () {
    _expectInKnownRange(_readVersionField(_frameworkSchemaPath), builtin);
  });

  group('E2 正向對照：高於內建版本的輸入必須不是 InKnownRange', () {
    final parts = builtin.split('.').map(int.parse).toList();
    final patchUp = '${parts[0]}.${parts[1]}.${parts[2] + 1}';
    final minorUp = '${parts[0]}.${parts[1] + 1}.${parts[2]}';

    for (final higher in [patchUp, minorUp]) {
      test('$higher 高於內建 $builtin，守衛斷言失敗', () {
        expect(
          () => _expectInKnownRange(higher, builtin),
          throwsA(isA<TestFailure>()),
        );
        expect(
          classifySchemaVersion(higher, builtin),
          isA<HigherThanBuiltin>(),
        );
      });
    }
  });
}
