/// [ButtonRow] widget test（SPEC-004 §4.34「測試點」、§5.8 排列不變式）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 建構 [count] 個 [AppButton]，第一個為 primary、其餘 secondary。
List<AppButton> _buildButtons(int count, {String Function(int)? labelOf}) {
  return [
    for (var i = 0; i < count; i++)
      AppButton(
        label: labelOf == null ? '按鈕$i' : labelOf(i),
        onPressed: () {},
        testKey: Key('button-row-child-$i'),
        variant: i == 0 ? AppButtonVariant.primary : AppButtonVariant.secondary,
      ),
  ];
}

/// 取得 [key] 對應 widget 在螢幕上的 [Rect]。
Rect _rectOf(WidgetTester tester, Key key) =>
    tester.getRect(find.byKey(key));

/// 兩個矩形是否相交（含邊界貼齊視為不相交）。
bool _intersects(Rect a, Rect b) => a.overlaps(b);

void main() {
  group('N=1/2/3 × 三種 alignment 渲染', () {
    for (final size in WindowSize.values) {
      for (final count in [1, 2, 3]) {
        for (final alignment in ButtonRowAlignment.values) {
          testWidgets(
            'N=$count / ${alignment.name} @ ${size.label} 不溢位',
            (tester) async {
              await pumpHarness(
                tester,
                size: size,
                child: ButtonRow(
                  alignment: alignment,
                  children: _buildButtons(count),
                ),
              );

              expectNoOverflow(tester);
              for (var i = 0; i < count; i++) {
                expect(find.byKey(Key('button-row-child-$i')), findsOneWidget);
              }
            },
          );
        }
      }
    }
  });

  group('空間不足換行', () {
    testWidgets('父寬受限至單一按鈕寬時換為多列且子件兩兩不相交', (tester) async {
      await pumpHarness(
        tester,
        child: Center(
          child: SizedBox(
            width: LayoutSize.hitTargetMin * 1.5,
            child: ButtonRow(children: _buildButtons(3)),
          ),
        ),
      );

      expectNoOverflow(tester);

      final rects = [
        for (var i = 0; i < 3; i++) _rectOf(tester, Key('button-row-child-$i')),
      ];

      // 換行：三顆按鈕不在同一水平列（top 座標不全相同）。
      final tops = rects.map((r) => r.top).toSet();
      expect(tops.length, greaterThan(1));

      // 兩兩不相交。
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            _intersects(rects[i], rects[j]),
            isFalse,
            reason: '子件 $i 與 $j 相交',
          );
        }
      }
    });
  });

  group('最長測試文案下仍不相交', () {
    testWidgets('子件最長測試文案（TestCopy.longZh）不觸發相交', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: Center(
          child: SizedBox(
            width: LayoutSize.detailPaneWidth - 2 * Space.md,
            child: ButtonRow(
              children: _buildButtons(
                2,
                labelOf: (i) => i == 0 ? TestCopy.longZh : '取消',
              ),
            ),
          ),
        ),
      );

      expectNoOverflow(tester);

      final rects = [
        _rectOf(tester, const Key('button-row-child-0')),
        _rectOf(tester, const Key('button-row-child-1')),
      ];
      expect(_intersects(rects[0], rects[1]), isFalse);
    });
  });

  group('間距引用 token（非硬編碼）', () {
    testWidgets('Wrap 的 spacing / runSpacing 引用 Space.sm', (tester) async {
      await pumpHarness(
        tester,
        child: ButtonRow(children: _buildButtons(2)),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, Space.sm.w);
      expect(wrap.runSpacing, Space.sm.h);
    });
  });

  group('slot 契約', () {
    testWidgets('primary 變體至多 1 且置於首位（違反時 assert 拋出）', (
      tester,
    ) async {
      expect(
        () => ButtonRow(
          children: [
            AppButton(
              label: '次要',
              onPressed: () {},
              testKey: const Key('a'),
              variant: AppButtonVariant.secondary,
            ),
            AppButton(
              label: '主要',
              onPressed: () {},
              testKey: const Key('b'),
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('子件數量超過 3 時 assert 拋出', (tester) async {
      expect(() => ButtonRow(children: _buildButtons(4)), throwsAssertionError);
    });

    testWidgets('子件數量為 0 時 assert 拋出', (tester) async {
      expect(() => ButtonRow(children: const []), throwsAssertionError);
    });
  });

  group('對齊方式', () {
    testWidgets('alignment 對映至 Wrap.alignment', (tester) async {
      for (final alignment in ButtonRowAlignment.values) {
        await pumpHarness(
          tester,
          child: ButtonRow(alignment: alignment, children: _buildButtons(1)),
        );

        final wrap = tester.widget<Wrap>(find.byType(Wrap));
        final expected = switch (alignment) {
          ButtonRowAlignment.start => WrapAlignment.start,
          ButtonRowAlignment.center => WrapAlignment.center,
          ButtonRowAlignment.end => WrapAlignment.end,
        };
        expect(wrap.alignment, expected);
      }
    });
  });
}
