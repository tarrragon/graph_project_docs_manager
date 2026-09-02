// AppText widget test（SPEC-004 §4.1「測試點」）。
//
// 涵蓋：
//   - 五個變體 × emphasis / secondary 修飾，兩種尺寸皆不溢位
//   - 每個變體以本條目最長測試文案渲染，單行變體截斷、body 換行
//   - zh / en 兩語系值皆不溢位
//   - title / subtitle 的 Semantics.header 為 true，body 不是 header
//   - 字級與顏色引用 token 非硬編碼
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 置於寬度受限的父格位（SPEC-004 §4.1 測試點第二項的寫法）。
Widget _constrained(Widget child) =>
    SizedBox(width: 120, child: child);

/// 每個變體對應 SPEC-004 §4.1 內容政策表的最長測試文案（各兩條）。
const Map<AppTextVariant, List<String>> _longestPerVariant = {
  AppTextVariant.title: [TestCopy.nodeTitle, TestCopy.longToken],
  AppTextVariant.subtitle: [TestCopy.ucName, TestCopy.longZh],
  AppTextVariant.body: [TestCopy.longEn],
  AppTextVariant.caption: [TestCopy.longZh],
  AppTextVariant.mono: [TestCopy.filePath, TestCopy.longToken],
};

void main() {
  group('全變體 × emphasis / secondary 修飾', () {
    for (final variant in AppTextVariant.values) {
      for (final emphasis in [false, true]) {
        for (final secondary in [false, true]) {
          testWidgetsAtEachSize(
            '${variant.name} emphasis=$emphasis secondary=$secondary 不溢位',
            (tester, size) async {
              await pumpHarness(
                tester,
                size: size,
                child: _constrained(
                  AppText(
                    TestCopy.longZh,
                    variant: variant,
                    emphasis: emphasis,
                    secondary: secondary,
                  ),
                ),
              );
              expectNoOverflow(tester);

              final style = tester.widget<Text>(find.byType(Text)).style!;
              if (emphasis) {
                expect(style.fontWeight, FontWeight.bold);
              }
              if (secondary) {
                expect(style.color, AppColors.textSecondary);
              }
            },
          );
        }
      }
    }
  });

  group('最長測試文案：單行截斷／多行換行', () {
    for (final variant in AppTextVariant.values) {
      for (final copy in _longestPerVariant[variant]!) {
        testWidgetsAtEachSize(
          '${variant.name} / ${copy.substring(0, 6)}… 依內容政策渲染',
          (tester, size) async {
            await pumpHarness(
              tester,
              size: size,
              child: _constrained(AppText(copy, variant: variant)),
            );
            expectNoOverflow(tester);

            final text = tester.widget<Text>(find.byType(Text));
            expect(text.overflow, TextOverflow.ellipsis);
            if (variant == AppTextVariant.body) {
              expect(text.softWrap, isTrue, reason: 'body 可換行');
              expect(text.maxLines, isNull, reason: 'body 預設無行數上限');
            } else {
              expect(text.softWrap, isFalse, reason: '單行變體不換行');
              expect(text.maxLines, 1, reason: '單行變體固定一行截斷');
            }
          },
        );
      }
    }
  });

  group('zh / en 兩語系值皆不溢位', () {
    for (final locale in kTestLocales) {
      for (final variant in AppTextVariant.values) {
        testWidgetsAtEachSize(
          '${locale.languageCode} / ${variant.name} 不溢位',
          (tester, size) async {
            await pumpHarness(
              tester,
              size: size,
              locale: locale,
              child: _constrained(
                Builder(
                  builder: (context) => AppText(
                    AppLocalizations.of(context).notFrameworkProjectExplanation,
                    variant: variant,
                  ),
                ),
              ),
            );
            expectNoOverflow(tester);
          },
        );
      }
    }
  });

  group('無障礙：Semantics.header', () {
    testWidgets('title 標記 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText('t', variant: AppTextVariant.title),
      );
      expect(
        tester.getSemantics(find.text('t')),
        matchesSemantics(isHeader: true, label: 't'),
      );
    }, semanticsEnabled: true);

    testWidgets('subtitle 標記 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText('s', variant: AppTextVariant.subtitle),
      );
      expect(
        tester.getSemantics(find.text('s')),
        matchesSemantics(isHeader: true, label: 's'),
      );
    }, semanticsEnabled: true);

    testWidgets('body 不是 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText('b', variant: AppTextVariant.body),
      );
      expect(
        tester.getSemantics(find.text('b')),
        matchesSemantics(isHeader: false, label: 'b'),
      );
    }, semanticsEnabled: true);
  });

  group('字級與顏色引用 token', () {
    final expectedFontSize = {
      AppTextVariant.title: AppFontSize.title,
      AppTextVariant.subtitle: AppFontSize.subtitle,
      AppTextVariant.body: AppFontSize.body,
      AppTextVariant.caption: AppFontSize.caption,
      AppTextVariant.mono: AppFontSize.body,
    };
    final expectedColor = {
      AppTextVariant.title: AppColors.textTitle,
      AppTextVariant.subtitle: AppColors.textTitle,
      AppTextVariant.body: AppColors.textPrimary,
      AppTextVariant.caption: AppColors.textSecondary,
      AppTextVariant.mono: AppColors.textPrimary,
    };

    for (final variant in AppTextVariant.values) {
      testWidgets('${variant.name} 字級與顏色符合 token 值', (tester) async {
        // WindowSize.design：ScreenUtil 縮放係數 1.0，.sp 值即 token 原值。
        await pumpHarness(
          tester,
          size: WindowSize.design,
          child: AppText('x', variant: variant),
        );
        final style = tester.widget<Text>(find.byType(Text)).style!;
        expect(style.fontSize, expectedFontSize[variant]! * 1.0);
        expect(style.color, expectedColor[variant]);
      });
    }
  });
}
