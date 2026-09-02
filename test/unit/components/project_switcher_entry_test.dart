/// ProjectSwitcherEntry 元件測試（SPEC-004 4.8）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('project-switcher-test');

  group('狀態矩陣：collapsed / expanded × 有專案名 / 無專案名', () {
    testWidgetsAtEachSize('collapsed + 有專案名 不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text(TestCopy.projectName), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgetsAtEachSize('expanded + 有專案名 不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: true,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgetsAtEachSize('collapsed + 無專案名 顯示元件預設 key', (
      tester,
      size,
    ) async {
      final container = await pumpHarness(
        tester,
        size: size,
        child: ProjectSwitcherEntry(
          isExpanded: false,
          onTap: () {},
          testKey: testKey,
        ),
      );
      final l10n = await AppLocalizations.delegate.load(kDefaultTestLocale);

      expectNoOverflow(tester);
      expect(find.text(l10n.projectSwitcherEntryLabel), findsOneWidget);
      container.dispose();
    });
  });

  group('高不小於最小命中區', () {
    testWidgetsAtEachSize('高等於 LayoutSize.hitTargetMin', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final box = tester.getSize(find.byKey(testKey));
      expect(box.height, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
    });
  });

  group('最長測試文案截斷', () {
    for (final copy in TestCopy.longCopies) {
      testWidgetsAtEachSize('longCopies 不溢位：${copy.substring(0, 8)}...', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          child: ProjectSwitcherEntry(
            projectName: copy,
            isExpanded: false,
            onTap: () {},
            testKey: testKey,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('zh / en 預設 key 值不溢位', () {
    for (final locale in kTestLocales) {
      testWidgetsAtEachSize('locale=${locale.languageCode} 不溢位', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          locale: locale,
          child: ProjectSwitcherEntry(
            isExpanded: false,
            onTap: () {},
            testKey: testKey,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動與無障礙播報', () {
    testWidgets('點選呼叫 onTap 恰一次；Semantics.expanded 與 isExpanded 一致', (
      tester,
    ) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      expect(callCount, 1);

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded.toBoolOrNull(), isFalse);
      expect(data.label, contains(TestCopy.projectName));
    });

    testWidgets('expanded=true 時 Semantics.expanded 反映真值', (tester) async {
      await pumpHarness(
        tester,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: true,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
    });

    testWidgets('鍵盤 Enter 觸發 onTap', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      callCount = 0; // 重置 tap 造成的計數，本測試只驗鍵盤路徑

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('鍵盤 Space 觸發 onTap', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      callCount = 0;

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(callCount, 1);
    });
  });

  group('disableAnimations', () {
    testWidgets('disableAnimations 下無動畫，渲染仍成功', (tester) async {
      await pumpHarness(
        tester,
        disableAnimations: true,
        child: ProjectSwitcherEntry(
          projectName: TestCopy.projectName,
          isExpanded: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });
  });
}
