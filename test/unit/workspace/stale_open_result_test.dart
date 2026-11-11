import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/stale_open_result.dart';

void main() {
  tearDown(() => staleOpenLogSink = defaultStaleOpenLogSink);

  group('openResultKey', () {
    test('四種結果各對應 i18n key 名', () {
      expect(
        openResultKey(ExternalOpenResult.opened),
        'openedExternallyMessage',
      );
      expect(
        openResultKey(ExternalOpenResult.openedWithoutEditor),
        'openedWithoutEditorMessage',
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
    test('sink 收到丟棄事件碼與呼叫端 tag、key 名', () {
      final events = <(StaleOpenLogEvent, Map<String, Object>)>[];
      staleOpenLogSink = (
        event,
        fields, {
        level = LogLevel.info,
        source,
        error,
      }) => events.add((event, fields.toJson()));

      logStaleOpenResult(tag: 'SomeScreen', i18nKey: 'openedExternallyMessage');

      expect(events, hasLength(1));
      expect(events.single.$1, StaleOpenLogEvent.openResultDiscarded);
      expect(events.single.$2, {
        StaleOpenLogKeys.screen: 'SomeScreen',
        StaleOpenLogKeys.i18nKey: 'openedExternallyMessage',
      });
    });

    test('tag 不合法（正向對照上一案）：退為替代值而不洩漏原字串', () {
      final events = <Map<String, Object>>[];
      staleOpenLogSink = (
        event,
        fields, {
        level = LogLevel.info,
        source,
        error,
      }) => events.add(fields.toJson());

      logStaleOpenResult(tag: '/Users/x/secret', i18nKey: 'k');

      expect(events.single[StaleOpenLogKeys.screen], 'fieldNameRejected');
    });

    test('預設 sink 不拋例外', () {
      logStaleOpenResult(tag: 'SomeScreen', i18nKey: 'k');
    });
  });
}
