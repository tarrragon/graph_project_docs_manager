/// [Toolbar] widget test（SPEC-004 §4.32「測試點」、§5.6 排列不變式）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 建構 [SearchField]（`filters` 尚未建立前的固定佔位篩選器測試替身）。
SearchField _buildSearch({String value = ''}) {
  return SearchField(
    value: value,
    onChanged: (_) {},
    testKey: const Key('toolbar-search'),
  );
}

/// 建構 [count] 個固定寬度篩選器替身（契約型別為 `FilterDropdown`，
/// 該元件尚未建立前以固定寬 [SizedBox] 模擬 slot 型別 [Widget]）。
List<Widget> _buildFilters(int count, {double width = 60}) {
  return [
    for (var i = 0; i < count; i++)
      SizedBox(
        key: Key('toolbar-filter-$i'),
        width: width,
        height: LayoutSize.hitTargetMin,
      ),
  ];
}

IssueMarker _buildMarker() {
  return IssueMarker.damagedDetail(
    count: 3,
    onTap: () {},
    testKey: const Key('toolbar-marker'),
  );
}

/// 取得 [key] 對應 widget 在螢幕上的 [Rect]。
Rect _rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// 兩個矩形是否相交。
bool _intersects(Rect a, Rect b) => a.overlaps(b);

void main() {
  group('N=1/2/3 × 有無 marker 渲染', () {
    for (final size in WindowSize.values) {
      for (final count in [1, 2, 3]) {
        for (final hasMarker in [false, true]) {
          testWidgets(
            'N=$count / marker=$hasMarker @ ${size.label} 不溢位',
            (tester) async {
              await pumpHarness(
                tester,
                size: size,
                child: Toolbar(
                  testKey: const Key('toolbar'),
                  search: _buildSearch(),
                  filters: _buildFilters(count),
                  marker: hasMarker ? _buildMarker() : null,
                ),
              );

              expectNoOverflow(tester);
              expect(find.byKey(const Key('toolbar-search')), findsOneWidget);
              for (var i = 0; i < count; i++) {
                expect(
                  find.byKey(Key('toolbar-filter-$i')),
                  findsOneWidget,
                );
              }
              expect(
                find.byKey(const Key('toolbar-marker')),
                hasMarker ? findsOneWidget : findsNothing,
              );
            },
          );
        }
      }
    }
  });

  group('SearchField 吸收剩餘寬', () {
    testWidgets('search 寬 = toolbar 寬 - 篩選器與間距', (tester) async {
      await pumpHarness(
        tester,
        child: Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: _buildFilters(2, width: 60),
          marker: _buildMarker(),
        ),
      );

      final toolbarRect = _rectOf(tester, const Key('toolbar'));
      final searchRect = _rectOf(tester, const Key('toolbar-search'));
      final filterRects = [
        _rectOf(tester, const Key('toolbar-filter-0')),
        _rectOf(tester, const Key('toolbar-filter-1')),
      ];
      final markerRect = _rectOf(tester, const Key('toolbar-marker'));

      final consumedByOthers =
          filterRects.fold<double>(0, (sum, r) => sum + r.width) +
          markerRect.width +
          3 * Space.sm.w; // 3 個間距：search-filter0、filter0-filter1、filter1-marker

      expect(
        searchRect.width,
        closeTo(toolbarRect.width - consumedByOthers, 1),
      );
    });
  });

  group('子件兩兩邊界盒不相交', () {
    testWidgets('search / filters × 3 / marker 全展開兩兩不相交', (tester) async {
      await pumpHarness(
        tester,
        child: Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: _buildFilters(3),
          marker: _buildMarker(),
        ),
      );

      expectNoOverflow(tester);

      final keys = [
        const Key('toolbar-search'),
        const Key('toolbar-filter-0'),
        const Key('toolbar-filter-1'),
        const Key('toolbar-filter-2'),
        const Key('toolbar-marker'),
      ];
      final rects = [for (final key in keys) _rectOf(tester, key)];

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

  group('空間不足策略：不觸發（最長測試文案下仍不溢位不相交）', () {
    testWidgets('kMinWindowSize + TestCopy.longZh 搜尋值下仍不溢位', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(value: TestCopy.longZh),
          filters: _buildFilters(3),
          marker: _buildMarker(),
        ),
      );

      expectNoOverflow(tester);

      final rects = [
        _rectOf(tester, const Key('toolbar-search')),
        _rectOf(tester, const Key('toolbar-filter-0')),
        _rectOf(tester, const Key('toolbar-filter-1')),
        _rectOf(tester, const Key('toolbar-filter-2')),
        _rectOf(tester, const Key('toolbar-marker')),
      ];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(_intersects(rects[i], rects[j]), isFalse);
        }
      }
    });
  });

  group('最小間距（不重疊，Space.sm）', () {
    testWidgets('search 與相鄰篩選器間距等於 Space.sm', (tester) async {
      await pumpHarness(
        tester,
        child: Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: _buildFilters(1),
        ),
      );

      final searchRect = _rectOf(tester, const Key('toolbar-search'));
      final filterRect = _rectOf(tester, const Key('toolbar-filter-0'));

      expect(filterRect.left - searchRect.right, closeTo(Space.sm.w, 0.5));
    });
  });

  group('間距與顏色引用 token（非硬編碼）', () {
    testWidgets('底邊框顏色為 AppColors.borderStrong', (tester) async {
      await pumpHarness(
        tester,
        child: Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: _buildFilters(1),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byKey(const Key('toolbar')),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.border!.bottom.color, AppColors.borderStrong);
    });
  });

  group('slot 契約', () {
    testWidgets('filters 為空清單時 assert 拋出', (tester) async {
      expect(
        () => Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: const [],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('filters 超過 3 個時 assert 拋出', (tester) async {
      expect(
        () => Toolbar(
          testKey: const Key('toolbar'),
          search: _buildSearch(),
          filters: _buildFilters(4),
        ),
        throwsAssertionError,
      );
    });
  });
}
