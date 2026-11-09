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

import 'package:graph_project_docs_manager/workspace/editor_preference.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';

class _FixedProbe implements EditorHandlerProbe {
  _FixedProbe(this.answer);

  final bool answer;
  final List<String> queried = [];

  @override
  Future<bool> hasHandler(String scheme) async {
    queried.add(scheme);
    return answer;
  }
}

class _FixedStore implements EditorPreferenceStore {
  _FixedStore(this.id);

  final String id;

  @override
  Future<String> read() async => id;

  @override
  Future<bool> write(String editorId) async => true;
}

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
      final fake = FakeExternalOpener(defaultResult: ExternalOpenResult.failed);

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

    test('G2-2 執行檔無法 spawn 時（ProcessException）回傳 failed', () async {
      // 可注入的執行檔路徑指向不存在的路徑，模擬 /usr/bin/open 在權限／
      // 沙盒限制下無法被 spawn 的情況（AC2 實機驗證要驗的失敗成因）。
      final opener = MacosExternalOpener(
        executable: '/no/such/executable-for-test',
      );
      final tempDir = Directory.systemTemp.createTempSync(
        'external_opener_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final target = File('${tempDir.path}/target.md')..writeAsStringSync('');

      final result = await opener.open(target.path);

      expect(result, ExternalOpenResult.failed);
    });
  });

  group('G4｜行號定位（SPEC-003 §2.2〈行號定位〉，E1 傳與不傳對照）', () {
    late Directory tempDir;
    late String target;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('external_opener_line_');
      target = (File(
        '${tempDir.path}/含 空白/檔案.md',
      )..createSync(recursive: true)).path;
    });
    tearDown(() => tempDir.deleteSync(recursive: true));

    MacosExternalOpener build({
      required String editorId,
      required bool handler,
      required List<List<String>> runs,
      int exitCode = 0,
    }) {
      return MacosExternalOpener(
        runner: (executable, args) async {
          runs.add([executable, ...args]);
          return ProcessResult(0, exitCode, '', '');
        },
        probe: _FixedProbe(handler),
        store: _FixedStore(editorId),
      );
    }

    test('G4-1 所選編輯器有 handler：以編輯器 URL 開啟並帶行號 -> opened', () async {
      final runs = <List<String>>[];
      final opener = build(editorId: 'vscode', handler: true, runs: runs);

      final result = await opener.open(target, line: 42);

      expect(result, ExternalOpenResult.opened);
      expect(runs.single, [
        '/usr/bin/open',
        editorUrlFor(editorById('vscode')!, target, 42),
      ]);
      expect(runs.single.last, startsWith('vscode://file/'));
      expect(runs.single.last, endsWith(':42'));
    });

    test('G4-2 對照：同一輸入 handler 失效 -> 退回不定位的原路徑 -> '
        'openedWithoutEditor', () async {
      final runs = <List<String>>[];
      final opener = build(editorId: 'vscode', handler: false, runs: runs);

      final result = await opener.open(target, line: 42);

      expect(result, ExternalOpenResult.openedWithoutEditor);
      expect(runs.single, ['/usr/bin/open', target]);
    });

    test('G4-3 退路的外部程序失敗 -> failed', () async {
      final runs = <List<String>>[];
      final opener = build(
        editorId: 'vscode',
        handler: false,
        runs: runs,
        exitCode: 1,
      );

      expect(await opener.open(target, line: 3), ExternalOpenResult.failed);
    });

    test('G4-4 選定系統預設：忽略 line，原路徑開啟 -> opened', () async {
      final runs = <List<String>>[];
      final opener = build(editorId: 'system', handler: true, runs: runs);

      final result = await opener.open(target, line: 42);

      expect(result, ExternalOpenResult.opened);
      expect(runs.single, ['/usr/bin/open', target]);
    });

    test('G4-5 未傳 line：不查 handler、原路徑開啟（目錄與三畫面行為不變）', () async {
      final runs = <List<String>>[];
      final probe = _FixedProbe(true);
      final opener = MacosExternalOpener(
        runner: (e, a) async {
          runs.add([e, ...a]);
          return ProcessResult(0, 0, '', '');
        },
        probe: probe,
        store: _FixedStore('vscode'),
      );

      final result = await opener.open(target);

      expect(result, ExternalOpenResult.opened);
      expect(runs.single, ['/usr/bin/open', target]);
      expect(probe.queried, isEmpty);
    });

    test('G4-6 未知的已存編輯器 id 視同系統預設', () async {
      final runs = <List<String>>[];
      final opener = build(editorId: 'emacs', handler: true, runs: runs);

      expect(await opener.open(target, line: 5), ExternalOpenResult.opened);
      expect(runs.single, ['/usr/bin/open', target]);
    });

    test('G4-7 路徑含空白與中文：URL 由 Uri 百分比編碼', () {
      final url = editorUrlFor(editorById('zed')!, '/a b/中文.md', 7);

      expect(url, startsWith('zed://file/a%20b/'));
      expect(url, endsWith(':7'));
      expect(url, isNot(contains(' ')));
    });
  });

  group('G3｜呼叫發出日誌的靜態結構驗證（INV-PORT-OBSERVE-001）', () {
    test('G3-1 open 方法體第一語句為入口日誌，位於前置檢查之前', () {
      final source = File('lib/workspace/external_opener.dart')
          .readAsStringSync();

      final methodStart = source.indexOf('Future<ExternalOpenResult> open(');
      final entryLogIndex = source.indexOf(
        "developer.log(line == null ? path : '\$path:\$line', name: _tag);",
      );
      final precheckIndex = source.indexOf('FileSystemEntity.type(path)');
      final processRunIndex = source.indexOf(
        'await _runner(_executable, [target])',
      );

      expect(methodStart, greaterThanOrEqualTo(0));
      expect(entryLogIndex, greaterThan(methodStart));
      expect(entryLogIndex, lessThan(precheckIndex));
      expect(precheckIndex, lessThan(processRunIndex));
    });
  });
}
