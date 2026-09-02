// SPEC-004 §4.2 AppIcon 測試點。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  group('三個尺寸階 × 主要顏色', () {
    for (final size in IconSize.values) {
      for (final color in <Color>[
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.accent,
      ]) {
        testWidgetsAtEachSize(
          '${size.name} / $color 不溢位且尺寸正確',
          (tester, windowSize) async {
            await pumpHarness(
              tester,
              size: windowSize,
              child: AppIcon(icon: Icons.folder, size: size, color: color),
            );
            expectNoOverflow(tester);

            final renderedIcon = tester.widget<Icon>(find.byType(Icon));
            expect(renderedIcon.size, size.logicalSize);
            expect(renderedIcon.color, color);
          },
        );
      }
    }
  });

  group('兩種視窗尺寸下尺寸不變', () {
    testWidgets('min 與 design 尺寸下圖示邏輯像素相同', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: const AppIcon(icon: Icons.folder, size: IconSize.lg),
      );
      final minRendered = tester.widget<Icon>(find.byType(Icon)).size;

      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: const AppIcon(icon: Icons.folder, size: IconSize.lg),
      );
      final designRendered = tester.widget<Icon>(find.byType(Icon)).size;

      expect(minRendered, designRendered);
      expect(minRendered, LayoutSize.iconLg);
    });
  });

  group('無障礙：semanticLabel', () {
    testWidgets('semanticLabel 為 null 時語意樹無節點', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: const AppIcon(icon: Icons.folder),
      );
      expect(
        find.descendant(
          of: find.byType(AppIcon),
          matching: find.bySemanticsLabel(RegExp('.*')),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('semanticLabel 非 null 時節點 label 等於該值', (tester) async {
      final handle = tester.ensureSemantics();
      const label = '資料夾';
      await pumpHarness(
        tester,
        child: const AppIcon(icon: Icons.folder, semanticLabel: label),
      );
      expect(tester.getSemantics(find.byType(AppIcon)).label, label);
      handle.dispose();
    });
  });
}
