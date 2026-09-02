/// [SwimlaneNode] widget test（SPEC-004 §4.16「測試點」）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  group('兩個變體 × 兩種視窗尺寸 不溢位', () {
    for (final size in WindowSize.values) {
      for (final isActive in [true, false]) {
        testWidgets(
          '${isActive ? 'active' : 'inactive'} @ ${size.label} 不溢位（固定寬步驟欄）',
          (tester) async {
            await pumpHarness(
              tester,
              size: size,
              child: material.Center(
                child: SizedBox(
                  width: 118,
                  child: SwimlaneNode(label: '掃描', isActive: isActive),
                ),
              ),
            );

            expectNoOverflow(tester);
          },
        );
      }
    }
  });

  group('最長測試文案截斷', () {
    testWidgets('TestCopy.stepName 截斷為一行（不拋出溢位例外）', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(
            width: 118,
            child: SwimlaneNode(label: TestCopy.stepName, isActive: true),
          ),
        ),
      );

      expectNoOverflow(tester);
      final textWidget = tester.widget<Text>(find.text(TestCopy.stepName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('TestCopy.longToken（無斷字機會）截斷為一行不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(
            width: 118,
            child: SwimlaneNode(label: TestCopy.longToken, isActive: false),
          ),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('zh / en 兩語系資料值不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('${locale.languageCode} 語系資料值不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: material.Center(
            child: SizedBox(
              width: 118,
              child: material.Column(
                children: [
                  SwimlaneNode(label: TestCopy.longZh, isActive: true),
                  SwimlaneNode(label: TestCopy.longEn, isActive: false),
                ],
              ),
            ),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('點擊無反應；drag 不由本元件承接', () {
    testWidgets('元件樹無 InkWell / ButtonStyleButton，點擊不產生反應', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '解析', isActive: true),
      );

      expect(find.byType(material.InkWell), findsNothing);
      expect(find.byType(material.ButtonStyleButton), findsNothing);

      await tester.tap(find.byType(SwimlaneNode));
      await tester.pump();

      expect(find.byType(material.InkWell), findsNothing);
      expect(find.byType(material.ButtonStyleButton), findsNothing);
    });
  });

  group('token 引用（非硬編碼）', () {
    testWidgets('active 底色引用 AppColors.accent，字色引用 surfaceBase', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '掃描', isActive: true),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.accent);

      final textWidget = tester.widget<Text>(find.text('掃描'));
      expect(textWidget.style?.color, AppColors.surfaceBase);
    });

    testWidgets('inactive 底色引用 AppColors.surfaceChip，字色引用 textPrimary', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '建圖', isActive: false),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surfaceChip);

      final textWidget = tester.widget<Text>(find.text('建圖'));
      expect(textWidget.style?.color, AppColors.textPrimary);
    });

    testWidgets('圓角引用 Radius.md', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '掃描', isActive: true),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(
        (decoration.borderRadius! as BorderRadius).topLeft.x,
        Radius.md.r,
      );
    });
  });

  group('無障礙朗讀標籤', () {
    testWidgets('active 變體朗讀 label + laneNodeActive', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '掃描', isActive: true),
      );

      final semantics = tester.getSemantics(find.byType(SwimlaneNode));
      expect(semantics.label, '掃描，作用中');
    });

    testWidgets('inactive 變體朗讀 label + laneNodeInactive', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '解析', isActive: false),
      );

      final semantics = tester.getSemantics(find.byType(SwimlaneNode));
      expect(semantics.label, '解析，非作用中');
    });

    testWidgets('en 語系朗讀對映 en 值', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: SwimlaneNode(label: 'scan', isActive: true),
      );

      final semantics = tester.getSemantics(find.byType(SwimlaneNode));
      expect(semantics.label, 'scan，Active');
    });

    testWidgets('不進入 Tab 順序（非 button）', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneNode(label: '掃描', isActive: true),
      );

      final semantics = tester.getSemantics(find.byType(SwimlaneNode));
      expect(semantics.flagsCollection.isButton, isFalse);
    });
  });
}
