// ExternalOpener 契約測試（SPEC-003 §2.2「外部開啟契約」「兩個 port 的
// 三時刻覆蓋」）。0.1.0-W1-068 落地。
//
// 分組依據：
// - G1 FakeExternalOpener 契約：記錄呼叫路徑與次數，供未來畫面票整合測試
//   依此斷言（概述表「外部程序呼叫」形式）。
// - G2 MacosExternalOpener 前置檢查：notFound 路徑不呼叫外部程序，只測
//   安全（不啟動真實應用程式）的分支；`opened`／`failed` 分支會實際喚起
//   系統應用程式，依 SPEC-003 §2.2「測試斷言」列改由整合測試注入 fake
//   驗證，本檔不重覆執行真實開啟。
// - G3 呼叫發出日誌的靜態結構驗證：SPEC-003 §2.2〈呼叫發出日誌〉表「驗收」
//   列明定「靜態可讀出，不需執行」，故以原始碼文字定位驗證語句順序。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/workspace/external_opener.dart';

void main() {
  group('G1｜FakeExternalOpener 契約', () {
    test('G1-1 依序記錄每次呼叫的路徑', () async {
      final fake = FakeExternalOpener();

      await fake.open('/a/one.md');
      await fake.open('/a/two.md');
      await fake.open('/a/one.md');

      expect(fake.calls, ['/a/one.md', '/a/two.md', '/a/one.md']);
    });

    test('G1-2 未設定覆寫時回傳 defaultResult', () async {
      final fake = FakeExternalOpener(
        defaultResult: ExternalOpenResult.failed,
      );

      final result = await fake.open('/a/one.md');

      expect(result, ExternalOpenResult.failed);
    });

    test('G1-3 resultFor 依路徑覆寫個別回傳值', () async {
      final fake = FakeExternalOpener();
      fake.resultFor['/missing.md'] = ExternalOpenResult.notFound;
      fake.resultFor['/broken.md'] = ExternalOpenResult.failed;

      expect(await fake.open('/missing.md'), ExternalOpenResult.notFound);
      expect(await fake.open('/broken.md'), ExternalOpenResult.failed);
      expect(await fake.open('/ok.md'), ExternalOpenResult.opened);
      expect(fake.calls, ['/missing.md', '/broken.md', '/ok.md']);
    });
  });

  group('G2｜MacosExternalOpener 前置檢查（notFound 不 spawn 外部程序）', () {
    test('G2-1 不存在的路徑回傳 notFound', () async {
      final opener = MacosExternalOpener();
      final tempDir = Directory.systemTemp.createTempSync(
        'external_opener_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final missingPath = '${tempDir.path}/does-not-exist.md';

      final result = await opener.open(missingPath);

      expect(result, ExternalOpenResult.notFound);
    });
  });

  group('G3｜呼叫發出日誌的靜態結構驗證（INV-PORT-OBSERVE-001）', () {
    test('G3-1 open 方法體第一語句為入口日誌，位於前置檢查之前', () {
      final source = File(
        'lib/workspace/external_opener.dart',
      ).readAsStringSync();

      final methodStart = source.indexOf('Future<ExternalOpenResult> open(');
      final entryLogIndex = source.indexOf(
        'developer.log(path, name: _tag);',
      );
      final precheckIndex = source.indexOf('FileSystemEntity.type(path)');
      final processRunIndex = source.indexOf("Process.run('/usr/bin/open'");

      expect(methodStart, greaterThanOrEqualTo(0));
      expect(entryLogIndex, greaterThan(methodStart));
      expect(entryLogIndex, lessThan(precheckIndex));
      expect(precheckIndex, lessThan(processRunIndex));
    });
  });
}
