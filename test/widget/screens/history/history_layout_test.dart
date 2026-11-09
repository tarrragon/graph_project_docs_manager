// 第七畫面版面與語系（測試設計 §3.8）。本檔只含 LY-1（八狀態）；
// LY-2、LY-3（事件列、期間分段）由 0.7.0-W1-012.12 補入。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/history/history_screen_fixtures.dart';
import '../../../helpers/pump_harness.dart';
import '../../../helpers/window_sizes.dart';

void main() {
  group('LY-1 八狀態 x zh／en x 視窗最小尺寸 無溢位', () {
    for (final locale in kTestLocales) {
      testWidgets(locale.languageCode, (tester) async {
        for (final (rootKey, state) in historyStateCases()) {
          await pumpHistoryApp(
            tester,
            state,
            locale: locale,
            size: WindowSize.min,
            settle: false,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(Key(rootKey)),
            findsOneWidget,
            reason: '${locale.languageCode} $rootKey',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${locale.languageCode} $rootKey',
          );
        }
      });
    }
  });
}
