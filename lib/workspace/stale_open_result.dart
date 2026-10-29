import 'dart:developer' as developer;

import 'external_opener.dart';

/// 晚回開啟結果的留痕接縫：[name] 為呼叫點畫面的 `_tag`，[message] 為完整留痕訊息。
typedef StaleOpenLogSink = void Function(String name, String message);

/// 開啟結果對應的 i18n key 名（留痕用，結果本身不呈現）。
String openResultKey(ExternalOpenResult result) => switch (result) {
  ExternalOpenResult.opened => 'openedExternallyMessage',
  ExternalOpenResult.notFound => 'sourceFileNotFoundSnackbarMessage',
  ExternalOpenResult.failed => 'externalOpenFailedMessage',
};

void _defaultSink(String name, String message) {
  developer.log(message, name: name);
}

/// 預設實作（供測試還原）。
const StaleOpenLogSink defaultStaleOpenLogSink = _defaultSink;

/// 測試替身注入點；測試須在 tearDown 還原為 [defaultStaleOpenLogSink]。
StaleOpenLogSink staleOpenLogSink = _defaultSink;

/// 切換專案前發出、切換後才回來的開啟結果不呈現，只留痕
/// （SPEC-003 §2.8 切換專案列、SPEC-004 §4.26 等待與結果列）。
/// [tag] 由呼叫端傳入其畫面 `_tag`（SPEC-003 §2.8 L2 列）。
void logStaleOpenResult({required String tag, required String i18nKey}) {
  staleOpenLogSink(
    tag,
    '開啟結果未呈現（$i18nKey）：因專案已改變而丟棄', // i18n-exempt: 開發者診斷 log
  );
}
