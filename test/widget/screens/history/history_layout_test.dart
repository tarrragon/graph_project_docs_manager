// 第七畫面版面與語系（測試設計 §3.8）。LY-1（八狀態）由 0.7.0-W1-012.11 建立，
// LY-2、LY-3（事件列、期間分段）由 0.7.0-W1-012.12 補入。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';

import '../../../helpers/test_copy.dart';

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

  group('LY-2 事件列超長值截斷不溢位，完整值在 Semantics', () {
    for (final locale in kTestLocales) {
      testWidgets(locale.languageCode, (tester) async {
        await pumpHistoryApp(
          tester,
          HistoryLoaded(snapLongValues(TestCopy.longToken)),
          locale: locale,
          size: WindowSize.min,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.contains(TestCopy.longToken) ?? false),
          ),
          findsWidgets,
        );
        expect(find.byType(AppTableRow), findsNWidgets(2));
        final header = tester.getRect(find.byType(AppTableRow).at(0));
        final row = tester.getRect(find.byType(AppTableRow).at(1));
        expect(row.left, header.left);
        expect(row.right, header.right);
      });
    }
  });

  group('LY-3 期間分段 zh／en 於最小視窗不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets(locale.languageCode, (tester) async {
        await pumpHistoryApp(
          tester,
          HistoryLoaded(snapTagged()),
          locale: locale,
          size: WindowSize.min,
        );
        expect(tester.takeException(), isNull);
        for (final p in ['default', 'recent30', 'all']) {
          expect(find.byKey(Key('option-history-period-$p')), findsOneWidget);
        }
      });
    }
  });
}
