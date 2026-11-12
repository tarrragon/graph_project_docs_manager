import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';

/// 晚回開啟結果的留痕事件（SPEC-010 FR-04：取代原純字串 sink）。
enum StaleOpenLogEvent {
  /// 切換專案前發出、切換後才回來的開啟結果被丟棄，不呈現。
  openResultDiscarded,
}

/// 事件負載鍵：[screen] 為呼叫點畫面的 `_tag`，[i18nKey] 為結果對應的 key 名。
abstract final class StaleOpenLogKeys {
  static const String screen = 'screen';
  static const String i18nKey = 'i18nKey';
}

/// 開啟結果對應的 i18n key 名（留痕用，結果本身不呈現）。
String openResultKey(ExternalOpenResult result) => switch (result) {
  ExternalOpenResult.opened => 'openedExternallyMessage',
  ExternalOpenResult.openedWithoutEditor => 'openedWithoutEditorMessage',
  ExternalOpenResult.notFound => 'sourceFileNotFoundSnackbarMessage',
  ExternalOpenResult.failed => 'externalOpenFailedMessage',
};

/// 預設實作（供測試還原）：經共用 writer 輸出，domain 為 `workspace`。
final LogSink<StaleOpenLogEvent> defaultStaleOpenLogSink =
    defaultLogSink<StaleOpenLogEvent>('workspace');

/// 測試替身注入點；測試須在 tearDown 還原為 [defaultStaleOpenLogSink]。
LogSink<StaleOpenLogEvent> staleOpenLogSink = defaultStaleOpenLogSink;

/// 切換專案前發出、切換後才回來的開啟結果不呈現，只留痕
/// （SPEC-003 §2.8 切換專案列、SPEC-004 §4.26 等待與結果列）。
/// [tag] 由呼叫端傳入其畫面 `_tag`（SPEC-003 §2.8 L2 列）；
/// 兩者皆為識別字（欄位名字元集），不合法時依 FR-03 退為替代值。
void logStaleOpenResult({required String tag, required String i18nKey}) {
  staleOpenLogSink(
    StaleOpenLogEvent.openResultDiscarded,
    LogFields({
      StaleOpenLogKeys.screen: LogValue.fieldName(tag),
      StaleOpenLogKeys.i18nKey: LogValue.fieldName(i18nKey),
    }),
  );
}
