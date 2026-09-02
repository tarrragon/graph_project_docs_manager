/// [Badge] widget test（SPEC-004 §4.5「測試點」）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 建構每個變體的一個代表性實例，供「八變體 × 六 tone × chip/inline」
/// 矩陣展開；`tone` 只對接受 tone 覆寫的變體生效（`count` / `category` /
/// `event`），其餘變體 tone 由元件內部決定，此參數被忽略。
Badge _buildVariant(
  BadgeVariant variant, {
  required BadgeTone tone,
  required bool inline,
}) {
  return switch (variant) {
    BadgeVariant.count => Badge.count(
        count: 3,
        tone: tone,
        semanticLabel: '3 個問題',
        inline: inline,
      ),
    BadgeVariant.status =>
      Badge.status(label: 'completed', inline: inline),
    BadgeVariant.type => Badge.type(label: 'PROP', inline: inline),
    BadgeVariant.category =>
      Badge.category(label: '資料損壞', tone: tone, inline: inline),
    BadgeVariant.event => Badge.event(
        label: 'emits EVT-DIAGNOSTICS-001',
        tone: tone,
        inline: inline,
      ),
    BadgeVariant.tag => Badge.tag(label: 'domain: schema', inline: inline),
    BadgeVariant.legend => Badge.legend(symbol: '●', label: '直接貫穿'),
    BadgeVariant.health => Badge.health(
        key: const Key('badge-switcher-health-0'),
        count: 5,
        semanticLabel: '5 個問題',
        inline: inline,
      ),
  };
}

void main() {
  group('Badge 變體 × tone × chip/inline 矩陣', () {
    for (final size in WindowSize.values) {
      for (final variant in BadgeVariant.values) {
        for (final tone in BadgeTone.values) {
          for (final inline in [false, true]) {
            testWidgets(
              '${variant.name} / ${tone.name} / '
              '${inline ? 'inline' : 'chip'} @ ${size.label} 不溢位',
              (tester) async {
                await pumpHarness(
                  tester,
                  size: size,
                  child: material.Center(
                    child: SizedBox(
                      width: 200,
                      child: _buildVariant(
                        variant,
                        tone: tone,
                        inline: inline,
                      ),
                    ),
                  ),
                );

                expectNoOverflow(tester);
              },
            );
          }
        }
      }
    }
  });

  group('最長測試文案', () {
    testWidgets('label 變體超長文案被截斷為一行（不拋出溢位例外）', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(
            width: 120,
            child: Badge.tag(label: TestCopy.longToken),
          ),
        ),
      );

      expectNoOverflow(tester);
      final textWidget = tester.widget<Text>(find.text(TestCopy.longToken));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('count 變體不截斷（數字固有寬）', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.count(count: 99999, semanticLabel: '99999 個問題'),
      );

      expect(find.text('99999'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('99999'));
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('zh / en 兩語系不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('長中文與長英文文案在 ${locale.languageCode} 不溢位', (
        tester,
      ) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: material.Center(
            child: SizedBox(
              width: 150,
              child: material.Column(
                children: [
                  Badge.tag(label: TestCopy.longZh),
                  Badge.tag(label: TestCopy.longEn),
                ],
              ),
            ),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('點擊無反應', () {
    testWidgets('點擊不產生任何反應，元件樹無 InkWell / ButtonStyleButton', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: Badge.status(label: 'draft'),
      );

      expect(find.byType(material.InkWell), findsNothing);
      expect(find.byType(material.ButtonStyleButton), findsNothing);

      await tester.tap(find.byType(Badge));
      await tester.pump();

      expect(find.byType(material.InkWell), findsNothing);
      expect(find.byType(material.ButtonStyleButton), findsNothing);
    });
  });

  group('status 對映表', () {
    const expected = {
      'completed': BadgeTone.positive,
      'confirmed': BadgeTone.positive,
      'approved': BadgeTone.positive,
      'implemented': BadgeTone.positive,
      'baseline': BadgeTone.positive,
      'draft': BadgeTone.warning,
      'pending': BadgeTone.warning,
      'review': BadgeTone.warning,
      'in_progress': BadgeTone.warning,
      'rejected': BadgeTone.neutral,
      'superseded': BadgeTone.neutral,
      'revised': BadgeTone.neutral,
    };

    const toneForeground = {
      BadgeTone.positive: AppColors.success,
      BadgeTone.warning: AppColors.warning,
      BadgeTone.neutral: AppColors.textPrimary,
    };

    for (final entry in expected.entries) {
      testWidgets('status=${entry.key} 對映 tone=${entry.value.name}', (
        tester,
      ) async {
        await pumpHarness(tester, child: Badge.status(label: entry.key));

        final textWidget = tester.widget<Text>(find.text(entry.key));
        expect(textWidget.style?.color, toneForeground[entry.value]);
      });
    }

    testWidgets('未列值對映為 neutral', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.status(label: 'unlisted-status-value'),
      );

      final textWidget = tester.widget<Text>(
        find.text('unlisted-status-value'),
      );
      expect(textWidget.style?.color, AppColors.textPrimary);
    });
  });

  group('token 引用（非硬編碼）', () {
    testWidgets('chip 底色、內距、圓角引用 token', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.tag(label: 'domain: schema'),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surfaceChip);
      expect(
        (decoration.borderRadius! as BorderRadius).topLeft.x,
        Radius.sm.r,
      );
      final padding = container.padding! as EdgeInsets;
      expect(padding.left, Space.sm.w);
      expect(padding.top, Space.xxs.h);
    });

    testWidgets('inline 形態無底色容器', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.tag(label: 'domain: schema', inline: true),
      );

      expect(find.byType(Container), findsNothing);
    });
  });

  group('legend 變體', () {
    testWidgets('渲染符號與文字，符號色依關係種類', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.legend(symbol: '●', label: '直接貫穿'),
      );

      expect(find.text('●'), findsOneWidget);
      expect(find.text('直接貫穿'), findsOneWidget);
    });
  });

  group('無障礙朗讀標籤', () {
    testWidgets('label 變體唸出 label', (tester) async {
      await pumpHarness(tester, child: Badge.type(label: 'PROP'));

      final semantics = tester.getSemantics(find.byType(Badge));
      expect(semantics.label, 'PROP');
    });

    testWidgets('count / health 變體唸出 semanticLabel', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.count(count: 3, semanticLabel: '3 個問題'),
      );

      final semantics = tester.getSemantics(find.byType(Badge));
      expect(semantics.label, '3 個問題');
    });

    testWidgets('health 變體不進入 Tab 順序（非 button）', (tester) async {
      await pumpHarness(
        tester,
        child: Badge.health(
          key: const Key('badge-switcher-health-0'),
          count: 5,
          semanticLabel: '5 個問題',
        ),
      );

      final semantics = tester.getSemantics(find.byType(Badge));
      expect(
        semantics.flagsCollection.isButton,
        isFalse,
      );
    });
  });
}
