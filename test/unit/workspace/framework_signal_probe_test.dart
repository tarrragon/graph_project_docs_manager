// 需求：0.3.0-W3-546 — DefaultFrameworkSignalProbe.readSchemaJsonVersion
// 六種情境的單元測試，以暫存目錄實檔進行，不 mock dart:io。
library;

import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultFrameworkSignalProbe.readSchemaJsonVersion', () {
    late Directory tempDir;
    const probe = DefaultFrameworkSignalProbe();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'framework_signal_probe_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> writeSchemaJson(String content) async {
      final schemaFile = File(
        '${tempDir.path}/${DefaultFrameworkSignalProbe.schemaJsonRelativePath}',
      );
      await schemaFile.parent.create(recursive: true);
      await schemaFile.writeAsString(content);
    }

    test('檔案不存在時回傳 null', () async {
      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, isNull);
    });

    test('正常情況回傳版本字串', () async {
      await writeSchemaJson(
        jsonEncode({'schema_generated_at_framework_version': '1.2.3'}),
      );

      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, '1.2.3');
    });

    test('欄位缺席時回傳 null', () async {
      await writeSchemaJson(jsonEncode({'other_field': 'x'}));

      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, isNull);
    });

    test('欄位非字串時回傳 null', () async {
      await writeSchemaJson(
        jsonEncode({'schema_generated_at_framework_version': 123}),
      );

      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, isNull);
    });

    test('JSON 無法解析時回傳 null', () async {
      await writeSchemaJson('{not valid json');

      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, isNull);
    });

    test('最上層為陣列時回傳 null 而非拋出 TypeError', () async {
      await writeSchemaJson(jsonEncode(['a', 'b', 'c']));

      final result = await probe.readSchemaJsonVersion(tempDir.path);

      expect(result, isNull);
    });
  });
}
