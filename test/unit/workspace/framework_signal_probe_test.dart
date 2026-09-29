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

  group('DefaultFrameworkSignalProbe.readVersion 與 schemaJsonExists', () {
    late Directory tempDir;
    const probe = DefaultFrameworkSignalProbe();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'framework_signal_probe_disk_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        // 還原可能被 chmod 000 的檔案權限，避免刪除失敗。
        await Process.run('chmod', ['-R', 'u+rwx', tempDir.path]);
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> writeAt(String relativePath, String content) async {
      final file = File('${tempDir.path}/$relativePath');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return file;
    }

    const versionPath = DefaultFrameworkSignalProbe.versionRelativePath;
    const schemaPath = DefaultFrameworkSignalProbe.schemaJsonRelativePath;

    test('readVersion：檔案不存在時回傳 null', () async {
      expect(await probe.readVersion(tempDir.path), isNull);
    });

    test('readVersion：空內容（含純空白）回傳 null', () async {
      await writeAt(versionPath, '  \n');

      expect(await probe.readVersion(tempDir.path), isNull);
    });

    test('readVersion：正常值回傳去除前後空白的版本字串', () async {
      await writeAt(versionPath, '1.2.3\n');

      expect(await probe.readVersion(tempDir.path), '1.2.3');
    });

    // 讀取失敗做法：檔案存在但以 chmod 000 移除讀取權限，
    // exists() 為 true 而 readAsString 拋 FileSystemException，走 catch 分支。
    // 路徑為目錄的做法無效：File.exists() 對目錄回傳 false，只會走「不存在」分支。
    test('readVersion：讀取失敗（無讀取權限）回傳 null 而非拋出', () async {
      final file = await writeAt(versionPath, '9.9.9');
      await Process.run('chmod', ['000', file.path]);

      expect(await probe.readVersion(tempDir.path), isNull);
    }, skip: Platform.isWindows ? '需要 POSIX 權限語意' : false);

    test('schemaJsonExists：檔案存在回傳 true', () async {
      await writeAt(schemaPath, '{}');

      expect(await probe.schemaJsonExists(tempDir.path), isTrue);
    });

    test('schemaJsonExists：檔案不存在回傳 false', () async {
      expect(await probe.schemaJsonExists(tempDir.path), isFalse);
    });
  });
}
