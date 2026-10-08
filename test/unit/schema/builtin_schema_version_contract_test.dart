// 跨語言契約 K4：內建型別表副本 ↔ builtin_schema_version.json
// （SPEC-006-test-design.md §3.4）。
//
// 讀真實 asset 檔案（非 fixture）：確保實際入庫的兩份資產彼此一致，這是
// 契約測試的意義所在——用最小建構器驗證不到「真實檔案是否同步」。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/schema_version.dart';

const _builtinTrackingSchemaPath =
    'assets/schema/builtin_tracking_schema.json';
const _builtinSchemaVersionPath = 'assets/schema/builtin_schema_version.json';

String? _readVersionField(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return json['schema_generated_at_framework_version'] as String?;
}

/// K4 斷言邏輯抽出為函式：兩份輸入的版本欄位是否一致（守衛正向對照用）。
bool _versionsConsistent(String? a, String? b) => a != null && a == b;

void main() {
  group('K4-1 內建型別表副本的版本等於 builtin_schema_version.json', () {
    test('兩份真實資產的 schema_generated_at_framework_version 一致', () {
      final tableVersion = _readVersionField(_builtinTrackingSchemaPath);
      final gateVersion = _readVersionField(_builtinSchemaVersionPath);

      expect(tableVersion, isNotNull, reason: '內建型別表副本缺 schema_generated_at_framework_version');
      expect(gateVersion, isNotNull, reason: 'builtin_schema_version.json 缺該欄位');
      expect(
        tableVersion,
        gateVersion,
        reason: '0.3.0-W2-001：內建型別表副本與版本閘門資產的版本必須同步',
      );
    });
  });

  group('K4-3 內建版本閘門與專案 JSON 對齊（0.5.0-W1-070.2）', () {
    const projectPath =
        '.claude/skills/doc/doc_system/core/tracking_schema.json';

    test('E1 專案 JSON 版本在內建版本範圍內；舊內建版本 2.60.13 則判超出', () {
      final projectVersion = _readVersionField(projectPath)!;
      final builtinVersion = _readVersionField(_builtinSchemaVersionPath)!;
      expect(isWithinKnownSchemaRange(projectVersion, builtinVersion), isTrue);
      expect(isWithinKnownSchemaRange(projectVersion, '2.60.13'), isFalse);
    });

    test('E2 版本高於內建時仍判超出已知範圍（守衛正向對照）', () {
      final builtinVersion = _readVersionField(_builtinSchemaVersionPath)!;
      expect(isWithinKnownSchemaRange('2.78.0', builtinVersion), isFalse);
    });

    test('內建型別表副本與專案 JSON 逐位元組一致', () {
      expect(
        File(_builtinTrackingSchemaPath).readAsBytesSync(),
        File(projectPath).readAsBytesSync(),
      );
    });
  });

  group('K6 內建副本含 non-domain 路徑 carrier 位置欄位（0.5.0-W1-096.8）', () {
    Map<String, dynamic> readBuiltin() => jsonDecode(
          File(_builtinTrackingSchemaPath).readAsStringSync(),
        ) as Map<String, dynamic>;

    test('K6-1 non_domain_paths_file 與 non_domain_paths_key 存在且值正確', () {
      final json = readBuiltin();
      expect(json['non_domain_paths_file'], 'docs/non-domain-paths.yaml');
      expect(json['non_domain_paths_key'], 'non_domain_path_patterns');
    });

    test('K6-2（守衛，E2 正向對照）缺欄位的 JSON 使同一斷言失敗', () {
      final stripped = readBuiltin()
        ..remove('non_domain_paths_file')
        ..remove('non_domain_paths_key');
      expect(stripped['non_domain_paths_file'], isNull);
      expect(stripped['non_domain_paths_key'], isNull);
      expect(
        stripped['non_domain_paths_file'] == 'docs/non-domain-paths.yaml',
        isFalse,
      );
    });
  });

  group('K4-2（守衛，E2）以兩個不同值的測試輸入作正向對照', () {
    test('版本不一致時，比對邏輯回報不一致（證明 K4-1 的斷言對真實漂移有鑑別力）', () {
      expect(_versionsConsistent('2.60.13', '2.60.13'), isTrue);
      expect(_versionsConsistent('2.60.13', '2.40.3'), isFalse);
      expect(_versionsConsistent(null, '2.60.13'), isFalse);
    });
  });
}
