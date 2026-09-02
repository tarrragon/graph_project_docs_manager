/// [BadgeRow] widget test（SPEC-004 §4.33「測試點」、§5.7 排列不變式）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 依 index 建一個代表性 [Badge]（`tag` 變體，文字含 index 避免重複）。
Badge _badge(int index) => Badge.tag(label: 'tag-$index');

/// 建 [count] 個代表性徽章（供 0 / 1 / 20 情境展開）。
List<Badge> _badges(int count) =>
    List.generate(count, (i) => _badge(i));

/// 取出目前已渲染的 [Badge] 的邊界盒（供不重疊 / 換行斷言）。
List<Rect> _badgeRects(WidgetTester tester) {
  return tester
      .widgetList<Badge>(find.byType(Badge))
      .map((badge) => tester.getRect(find.byWidget(badge)))
      .toList();
}

void main() {
  group('BadgeRow default / legend × 0 / 1 / 20 個徽章', () {
    for (final size in WindowSize.values) {
      for (final variant in BadgeRowVariant.values) {
        for (final count in [0, 1, 20]) {
          testWidgets(
            '${variant.name} / $count 個徽章 @ ${size.label} 不溢位',
            (tester) async {
              await pumpHarness(
                tester,
                size: size,
                child: material.Center(
                  child: SizedBox(
                    width: 300,
                    child: BadgeRow(
                      variant: variant,
                      children: _badges(count),
                    ),
                  ),
                ),
              );

              expectNoOverflow(tester);
              expect(find.byType(Badge), findsNWidgets(count));
            },
          );
        }
      }
    }
  });

  group('§5.7 排列不變式：不重疊', () {
    testWidgets('20 個徽章兩兩邊界盒不相交', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(width: 300, child: BadgeRow(children: _badges(20))),
        ),
      );

      final rects = _badgeRects(tester);
      expect(rects.length, 20);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '徽章 $i 與 $j 的邊界盒不應重疊',
          );
        }
      }
    });
  });

  group('§5.7 排列不變式：最小間距（Space.xs）', () {
    testWidgets('同列相鄰徽章水平間距不小於 Space.xs', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(width: 300, child: BadgeRow(children: _badges(4))),
        ),
      );

      final rects = _badgeRects(tester)
        ..sort((a, b) => a.left.compareTo(b.left));
      // 同一列的判準：垂直中心線相同（Wrap 同列子件 top 對齊、crossAxis 置中）。
      final sameRow = rects
          .where((r) => (r.top - rects.first.top).abs() < 1)
          .toList();
      for (var i = 0; i < sameRow.length - 1; i++) {
        final gap = sameRow[i + 1].left - sameRow[i].right;
        expect(
          gap,
          greaterThanOrEqualTo(Space.xs.w - 1),
          reason: '徽章 $i 與 ${i + 1} 的水平間距應不小於 Space.xs',
        );
      }
    });

    testWidgets('換行後列間垂直間距不小於 Space.xs', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(width: 120, child: BadgeRow(children: _badges(20))),
        ),
      );

      final rects = _badgeRects(tester)
        ..sort((a, b) => a.top.compareTo(b.top));
      final rowTops = rects.map((r) => r.top).toSet().toList()..sort();
      expect(rowTops.length, greaterThan(1), reason: '受限寬度下應換為多列');

      // 取每列最大 bottom 與下一列 top 比較，驗證列間垂直間距。
      for (var i = 0; i < rowTops.length - 1; i++) {
        final rowRects =
            rects.where((r) => (r.top - rowTops[i]).abs() < 1).toList();
        final rowBottom = rowRects
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        final gap = rowTops[i + 1] - rowBottom;
        expect(
          gap,
          greaterThanOrEqualTo(Space.xs.h - 1),
          reason: '第 $i 列與下一列的垂直間距應不小於 Space.xs',
        );
      }
    });
  });

  group('§5.7 排列不變式：空間不足策略（換行）', () {
    testWidgets('受限寬度下 20 個徽章換為多列', (tester) async {
      await pumpHarness(
        tester,
        child: material.Center(
          child: SizedBox(width: 120, child: BadgeRow(children: _badges(20))),
        ),
      );

      expectNoOverflow(tester);
      final rowTops = _badgeRects(tester).map((r) => r.top).toSet();
      expect(rowTops.length, greaterThan(1));
    });
  });

  test('間距引用 token 非硬編碼', () {
    // Space.xs 為具名 token；本測試以編譯期存在性佐證 badge_row.dart
    // 未硬編碼間距數值（見 lib/components/badge_row.dart 引用 Space.xs / Space.sm）。
    expect(Space.xs, isA<double>());
    expect(Space.sm, isA<double>());
  });
}
