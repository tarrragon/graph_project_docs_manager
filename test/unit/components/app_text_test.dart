// AppText widget test（SPEC-004 §4.1「測試點」）。
//
// 涵蓋：
//   - 五個變體 × emphasis / secondary 修飾，兩種尺寸皆不溢位
//   - 每個變體以本條目最長測試文案渲染，單行變體截斷、body 換行
//   - zh / en 兩語系值皆不溢位
//   - title / subtitle 的 Semantics.header 為 true，body 不是 header
//   - 字級與顏色引用 token 非硬編碼
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 置於寬度受限的父格位（SPEC-004 §4.1 測試點第二項的寫法）。
Widget _constrained(Widget child) => SizedBox(width: 120, child: child);

/// 每個變體對應 SPEC-004 §4.1 內容政策表的最長測試文案（各兩條）。
const Map<AppTextVariant, List<String>> _longestPerVariant = {
  AppTextVariant.title: [TestCopy.nodeTitle, TestCopy.longToken],
  AppTextVariant.subtitle: [TestCopy.ucName, TestCopy.longZh],
  AppTextVariant.body: [TestCopy.longEn],
  AppTextVariant.caption: [TestCopy.longZh],
  AppTextVariant.mono: [TestCopy.filePath, TestCopy.longToken],
};

/// 既有五個變體（`code` 另有專屬測試群組，內容政策與這些迴圈相反）。
final List<AppTextVariant> _existingVariants = AppTextVariant.values
    .where((v) => v != AppTextVariant.code)
    .toList();

void main() {
  group('全變體 × emphasis / secondary 修飾', () {
    for (final variant in _existingVariants) {
      for (final emphasis in [false, true]) {
        for (final secondary in [false, true]) {
          testWidgetsAtEachSize(
            '${variant.name} emphasis=$emphasis secondary=$secondary 不溢位',
            (tester, size) async {
              await pumpHarness(
                tester,
                size: size,
                child: _constrained(
                  AppText.singleLine(
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
    for (final variant in _existingVariants) {
      for (final copy in _longestPerVariant[variant]!) {
        testWidgetsAtEachSize(
          '${variant.name} / ${copy.substring(0, 6)}… 依內容政策渲染',
          (tester, size) async {
            await pumpHarness(
              tester,
              size: size,
              child: _constrained(AppText.singleLine(copy, variant: variant)),
            );
            expectNoOverflow(tester);

            final text = tester.widget<Text>(find.byType(Text));
            expect(text.overflow, TextOverflow.ellipsis);
            expect(text.softWrap, isFalse, reason: '單行不換行');
            expect(text.maxLines, 1, reason: '單行固定一行截斷');
          },
        );
      }
    }
  });

  group('zh / en 兩語系值皆不溢位', () {
    for (final locale in kTestLocales) {
      for (final variant in _existingVariants) {
        testWidgetsAtEachSize('${locale.languageCode} / ${variant.name} 不溢位', (
          tester,
          size,
        ) async {
          await pumpHarness(
            tester,
            size: size,
            locale: locale,
            child: _constrained(
              Builder(
                builder: (context) => AppText.singleLine(
                  AppLocalizations.of(context).notFrameworkProjectExplanation,
                  variant: variant,
                ),
              ),
            ),
          );
          expectNoOverflow(tester);
        });
      }
    }
  });

  group('行數政策明示（508.1）', () {
    const long = TestCopy.longEn;
    // Scaffold body 給緊約束，需 Align 才讓 120 寬生效。
    Widget narrow(Widget c) =>
        Align(alignment: Alignment.topLeft, child: _constrained(c));

    testWidgets('singleLine 只畫一行並省略號', (tester) async {
      await pumpHarness(tester, child: narrow(const AppText.singleLine(long)));
      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('multiLine 無上限時真的換行', (tester) async {
      await pumpHarness(tester, child: narrow(const AppText.singleLine(long)));
      final oneLine = tester.getSize(find.byType(AppText)).height;
      await pumpHarness(
        tester,
        child: narrow(const AppText.multiLine(long, maxLines: null)),
      );
      final multi = tester.getSize(find.byType(AppText)).height;
      expect(multi, greaterThan(oneLine), reason: '多行高度應大於單行');
      expect(tester.widget<Text>(find.text(long)).softWrap, isTrue);
    });

    testWidgets('multiLine 有 maxLines 時限行並省略號', (tester) async {
      await pumpHarness(
        tester,
        child: narrow(const AppText.multiLine(long, maxLines: 2)),
      );
      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('無障礙：Semantics.header', () {
    testWidgets('title 標記 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText.singleLine('t', variant: AppTextVariant.title),
      );
      expect(
        tester.getSemantics(find.text('t')),
        matchesSemantics(isHeader: true, label: 't'),
      );
    }, semanticsEnabled: true);

    testWidgets('subtitle 標記 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText.singleLine('s', variant: AppTextVariant.subtitle),
      );
      expect(
        tester.getSemantics(find.text('s')),
        matchesSemantics(isHeader: true, label: 's'),
      );
    }, semanticsEnabled: true);

    testWidgets('body 不是 header', (tester) async {
      await pumpHarness(
        tester,
        child: const AppText.singleLine('b', variant: AppTextVariant.body),
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

    for (final variant in _existingVariants) {
      testWidgets('${variant.name} 字級與顏色符合 token 值', (tester) async {
        // WindowSize.design：ScreenUtil 縮放係數 1.0，.sp 值即 token 原值。
        await pumpHarness(
          tester,
          size: WindowSize.design,
          child: AppText.singleLine('x', variant: variant),
        );
        final style = tester.widget<Text>(find.byType(Text)).style!;
        expect(style.fontSize, expectedFontSize[variant]! * 1.0);
        expect(style.color, expectedColor[variant]);
      });
    }
  });

  group('code 變體（SPEC-004 §4.1，1.143）', () {
    Widget narrow212(Widget c) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 212, child: c),
    );

    testWidgetsAtEachSize('longToken 依字元斷行：無省略號、無溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: narrow212(const AppText.code(TestCopy.longToken)),
      );
      expectNoOverflow(tester);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.maxLines, isNull, reason: '不限行數');
      expect(editable.style.overflow, isNot(TextOverflow.ellipsis));
      final box = tester.getSize(find.byType(AppText));
      expect(box.height, greaterThan(editable.style.fontSize! * 1.5));
      expect(box.width, lessThanOrEqualTo(212));
    });

    testWidgets('對照：mono 同文案出現省略號且不可選取', (tester) async {
      await pumpHarness(
        tester,
        child: narrow212(
          const AppText.singleLine(
            TestCopy.longToken,
            variant: AppTextVariant.mono,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byType(Text)).overflow,
        TextOverflow.ellipsis,
      );
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('字級與顏色引用 token', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: const AppText.code('x'),
      );
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(style.fontSize, AppFontSize.body * 1.0);
      expect(style.color, AppColors.textPrimary);
    });

    testWidgets('回饋契約：游標為 text 形狀', (tester) async {
      await pumpHarness(
        tester,
        child: narrow212(const AppText.code('git cat-file -p abc')),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(SelectableText)));
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
      );
    });

    testWidgets('回饋契約：進入 Tab 順序並取得焦點', (tester) async {
      await pumpHarness(
        tester,
        child: narrow212(const AppText.code('git status')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final node = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(node.hasFocus, isTrue);
    });

    testWidgets('焦點後全選並 ⌘C，複製結果等於 text', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const cmd = 'git cat-file -p ${TestCopy.filePath}';
      await pumpHarness(tester, child: narrow212(const AppText.code(cmd)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, platform: 'macos');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, platform: 'macos');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
      await tester.pump();
      expect(copied, cmd);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
