import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/stale_open_result.dart';

void main() {
  tearDown(() => staleOpenLogSink = defaultStaleOpenLogSink);

  group('openResultKey', () {
    test('三種結果各對應既有 i18n key 名', () {
      expect(
        openResultKey(ExternalOpenResult.opened),
        'openedExternallyMessage',
      );
      expect(
        openResultKey(ExternalOpenResult.notFound),
        'sourceFileNotFoundSnackbarMessage',
      );
      expect(
        openResultKey(ExternalOpenResult.failed),
        'externalOpenFailedMessage',
      );
    });
  });

  group('logStaleOpenResult', () {
    test('sink 收到呼叫端 tag 與含 key 名、丟棄原因的訊息', () {
      final events = <(String, String)>[];
      staleOpenLogSink = (name, message) => events.add((name, message));

      logStaleOpenResult(tag: 'SomeScreen', i18nKey: 'openedExternallyMessage');

      expect(events, hasLength(1));
      expect(events.single.$1, 'SomeScreen');
      expect(events.single.$2, contains('openedExternallyMessage'));
      expect(events.single.$2, contains('因專案已改變而丟棄'));
    });

    test('預設 sink 不拋例外', () {
      logStaleOpenResult(tag: 'SomeScreen', i18nKey: 'k');
    });
  });
}
