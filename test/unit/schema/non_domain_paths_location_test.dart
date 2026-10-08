// 需求：[SPEC-006 FR-10 規則 1] 型別表解碼非 domain 路徑清單檔的位置欄位。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

void main() {
  test('專案 JSON 帶兩欄時解碼為該值', () {
    final table = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      'non_domain_paths_file': 'custom/paths.yaml',
      'non_domain_paths_key': 'custom_key',
    });

    expect(table.nonDomainPathsFile, 'custom/paths.yaml');
    expect(table.nonDomainPathsKey, 'custom_key');
  });

  test('專案 JSON 缺兩欄時兩欄為 null（由消費端回落內建表）', () {
    final table = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
    });

    expect(table.nonDomainPathsFile, isNull);
    expect(table.nonDomainPathsKey, isNull);
  });

  test('內建型別表副本解碼出 S2 位置與鍵名', () {
    final json = jsonDecode(
      File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final table = typeTableFromJson(json);

    expect(table.nonDomainPathsFile, 'docs/non-domain-paths.yaml');
    expect(table.nonDomainPathsKey, 'non_domain_path_patterns');
  });

  test('專案 JSON 兩欄為空字串時視為缺欄（與缺欄對照相同）', () {
    final table = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      'non_domain_paths_file': '',
      'non_domain_paths_key': '',
    });

    expect(table.nonDomainPathsFile, isNull);
    expect(table.nonDomainPathsKey, isNull);
  });

  test('R1/R2 純空白位置欄位視為缺欄，與缺欄對照（C1）結果相同', () {
    final whitespace = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      'non_domain_paths_file': ' ',
      'non_domain_paths_key': '\t ',
    });
    final missing = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
    });

    expect(whitespace.nonDomainPathsFile, isNull);
    expect(whitespace.nonDomainPathsKey, isNull);
    expect(whitespace.nonDomainPathsFile, missing.nonDomainPathsFile);
    expect(whitespace.nonDomainPathsKey, missing.nonDomainPathsKey);
  });

  test('R3/R4 前後帶空白的非空值照原值使用、不修剪', () {
    final table = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      'non_domain_paths_file': ' docs/x.yaml',
      'non_domain_paths_key': 'custom ',
    });

    expect(table.nonDomainPathsFile, ' docs/x.yaml');
    expect(table.nonDomainPathsKey, 'custom ');
  });

  test('C2 非字串值視為缺欄', () {
    final table = typeTableFromJson(<String, dynamic>{
      'node_types': <String, dynamic>{},
      'non_domain_paths_file': 42,
      'non_domain_paths_key': true,
    });

    expect(table.nonDomainPathsFile, isNull);
    expect(table.nonDomainPathsKey, isNull);
  });
}
