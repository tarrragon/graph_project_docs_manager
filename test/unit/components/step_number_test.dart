/// [StepNumber] widget test（SPEC-004 §4.17「測試點」）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';

import '../../helpers/helpers.dart';

void main() {
  group('StepNumber 序號矩陣', () {
    // 人工值 999、一般值 39（§4.17「內容政策」最長測試文案），加 1 一般
    // 序號與一個四位數（觸發三位數以上縮字級分支）。
    const numbers = [1, 39, 999, 1000];

    for (final number in numbers) {
      testWidgetsAtEachSize('序號 $number 不溢位', (tester, size) async {
        await pumpHarness(
          tester,
          size: size,
          child: material.Center(child: StepNumber(number: number)),
        );

        expectNoOverflow(tester);
        expect(find.text('$number'), findsOneWidget);
      });
    }
  });

  testWidgets('朗讀標籤依 stepNumberA11yLabel 產生', (tester) async {
    await pumpHarness(
      tester,
      child: const material.Center(child: StepNumber(number: 39)),
    );

    final context = tester.element(find.byType(StepNumber));
    final l10n = AppLocalizations.of(context);

    expect(find.bySemanticsLabel(l10n.stepNumberA11yLabel(39)), findsOneWidget);
  });

  testWidgets('純顯示：Semantics 不進入 Tab 順序（button 為 false）', (tester) async {
    await pumpHarness(
      tester,
      child: const material.Center(child: StepNumber(number: 1)),
    );

    final semantics = tester.getSemantics(find.byType(StepNumber));
    expect(semantics.flagsCollection.isButton, isFalse);
  });
}
