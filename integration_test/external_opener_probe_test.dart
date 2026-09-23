import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:graph_project_docs_manager/workspace/external_opener.dart';

/// 0.1.0-W1-068 AC5：實機驗證 [MacosExternalOpener] 在沙盒關閉的 debug .app
/// 內直接呼叫，觀察真實 `Process.run('/usr/bin/open', ...)` 的行為。
///
/// 本檔獨立於 `integration_test/app_test.dart`，**不併入常態
/// `fvm flutter test integration_test/ -d macos` 批次執行**——`app_test.dart`
/// 已記載「一次 flutter test 呼叫只能啟動一次 app」，本檔預設以
/// [_runProbe] 關閉（未帶 `RUN_OPEN_PROBE=true` 時兩案例皆 skip），僅供
/// 單獨手動執行：
/// `fvm flutter test integration_test/external_opener_probe_test.dart -d macos
/// --dart-define=RUN_OPEN_PROBE=true`
///
/// 開關關閉的理由：此測試會實際開啟 Finder／文字編輯器視窗，不該在每次
/// 整合測試時觸發。
const bool _runProbe = bool.fromEnvironment('RUN_OPEN_PROBE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MacosExternalOpener 實機探測（AC5）', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'external_opener_probe_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      '開啟真實檔案',
      (tester) async {
        final file = File('${tempDir.path}/probe.txt')
          ..writeAsStringSync('probe');
        final opener = MacosExternalOpener();

        final result = await opener.open(file.path);

        // 例外：integration test 的 stdout 是唯一能被讀回主線程的通道，
        // 用來把觀測到的真實結果值帶出測試進程供 PM 記錄。
        // ignore: avoid_print
        print('PROBE file result=$result');

        expect(result, ExternalOpenResult.opened);
      },
      skip: !_runProbe,
    );

    testWidgets(
      '開啟真實目錄',
      (tester) async {
        final opener = MacosExternalOpener();

        final result = await opener.open(tempDir.path);

        // 例外：同上，integration test 的 stdout 是唯一能被讀回的通道。
        // ignore: avoid_print
        print('PROBE dir result=$result');

        expect(result, ExternalOpenResult.opened);
      },
      skip: !_runProbe,
    );
  });
}
