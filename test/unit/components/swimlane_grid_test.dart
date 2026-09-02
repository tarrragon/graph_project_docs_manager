/// SwimlaneGrid 元件測試（SPEC-004 4.38、5.12）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const scrollKey = ValueKey('scroll-domain-swimlane');
  const dragKey = ValueKey('drag-domain-swimlane');

  List<SwimlaneLane> buildLanes({
    int laneCount = 6,
    int columnCount = 6,
    String Function(int lane)? nameOf,
  }) {
    return List.generate(laneCount, (laneIndex) {
      final name = nameOf?.call(laneIndex) ?? 'lane-$laneIndex';
      return SwimlaneLane(
        name: name,
        nodes: [
          for (var column = 0; column < columnCount; column++)
            (
              SwimlaneNode(
                key: ValueKey('node-$laneIndex-$column'),
                label: 'step-$laneIndex-$column',
                isActive: column.isEven,
              ),
              column,
            ),
        ],
      );
    });
  }

  group('變體：default（6 泳道 × 6 步驟假資料）', () {
    testWidgetsAtEachSize('渲染全部泳道與節點，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SwimlaneGrid(
          lanes: buildLanes(),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('node-0-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('node-5-5')), findsOneWidget);
    });
  });

  group('互動反應：拖曳與捲動共用同一 offset（SPEC-004 4.38）', () {
    testWidgets('drag Offset(dx, dy) 後內容平移量等於位移', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 200,
          child: SwimlaneGrid(
            lanes: buildLanes(laneCount: 12, columnCount: 12),
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );

      final before = tester.getTopLeft(find.byKey(const ValueKey('node-0-0')));
      const delta = Offset(-40, -30);
      // 拖曳中心點取 scrollKey（外層 Scrollable 的自身盒界=viewport，恆在
      // 可見範圍內）；內層 dragKey 的自身盒界=內容全寬（可能超出 viewport），
      // 兩者位於同一點，仍能同時觸發水平／垂直兩個捲動識別器。
      await tester.drag(find.byKey(scrollKey), delta);
      await tester.pump();
      final after = tester.getTopLeft(find.byKey(const ValueKey('node-0-0')));

      expect(after.dx - before.dx, closeTo(delta.dx, 0.5));
      expect(after.dy - before.dy, closeTo(delta.dy, 0.5));
    });

    testWidgets('至內容邊界後再 drag 不再改變 offset', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 200,
          child: SwimlaneGrid(
            lanes: buildLanes(laneCount: 12, columnCount: 12),
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );

      // 已在起點（offset 0），再往正方向拖（超出頂端邊界）不應改變位置。
      final before = tester.getTopLeft(find.byKey(const ValueKey('node-0-0')));
      await tester.drag(find.byKey(scrollKey), const Offset(200, 200));
      await tester.pump();
      final after = tester.getTopLeft(find.byKey(const ValueKey('node-0-0')));

      expect(after, before);
    });
  });

  group('內容政策：泳道名最長測試文案截斷、資料值不溢位', () {
    testWidgetsAtEachSize('泳道名使用 TestCopy 最長文案不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SwimlaneGrid(
          lanes: buildLanes(
            laneCount: 2,
            columnCount: 2,
            nameOf: (i) => i == 0 ? TestCopy.domainName : TestCopy.longToken,
          ),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('互動反應：jumpTo 使命中列 rect 與 viewport 相交（自詳情卡進入）', () {
    testWidgets('laneHighlight 指向不在可視範圍的泳道時自動捲動至可見', (tester) async {
      final lanes = buildLanes(laneCount: 20, columnCount: 2);
      final container = SizedBox(
        width: 300,
        height: 200,
        child: SwimlaneGrid(
          lanes: lanes,
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );
      await pumpHarness(tester, child: container);

      // 目標泳道（第 19 條）在初始 viewport 之外。
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 200,
          child: SwimlaneGrid(
            lanes: lanes,
            laneHighlight: 'lane-19',
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );
      await tester.pump();

      final viewportRect = tester.getRect(find.byKey(dragKey));
      final laneRect = tester.getRect(find.byKey(const ValueKey('node-19-0')));

      expect(laneRect.overlaps(viewportRect), isTrue);
    });
  });

  group('尺寸與顏色引用 token 非硬編碼', () {
    testWidgets('泳道列高為 LayoutSize.laneRowHeight', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: SwimlaneGrid(
          lanes: buildLanes(laneCount: 1, columnCount: 1),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      final laneRowFinder = find.ancestor(
        of: find.byKey(const ValueKey('node-0-0')),
        matching: find.byType(Container),
      );
      final laneRowHeight = tester.getSize(laneRowFinder.first).height;

      expect(laneRowHeight, LayoutSize.laneRowHeight);
    });
  });

  group('排列不變式（SPEC-004 5.12）', () {
    testWidgets('不重疊：同列相鄰節點兩兩不相交', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 600,
          height: 200,
          child: SwimlaneGrid(
            lanes: buildLanes(laneCount: 1, columnCount: 4),
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );

      final rect0 = tester.getRect(find.byKey(const ValueKey('node-0-0')));
      final rect1 = tester.getRect(find.byKey(const ValueKey('node-0-1')));
      final rect2 = tester.getRect(find.byKey(const ValueKey('node-0-2')));
      final rect3 = tester.getRect(find.byKey(const ValueKey('node-0-3')));

      expect(rect0.overlaps(rect1), isFalse);
      expect(rect1.overlaps(rect2), isFalse);
      expect(rect2.overlaps(rect3), isFalse);
    });

    testWidgets('最小間距：節點與欄邊至少 Space.xs', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: SizedBox(
          width: 600,
          height: 200,
          child: SwimlaneGrid(
            lanes: buildLanes(laneCount: 1, columnCount: 1),
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );

      // 節點左緣位於欄內距（含泳道名欄寬），驗證非緊貼欄邊（0 間距）。
      final nodeRect = tester.getRect(find.byKey(const ValueKey('node-0-0')));
      final columnStart = LayoutSize.laneLabelWidth;

      expect(nodeRect.left - columnStart, greaterThanOrEqualTo(Space.xs));
    });

    testWidgetsAtEachSize('空間不足策略：泳道數與步驟欄數超出可用空間時可捲動不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SwimlaneGrid(
          lanes: buildLanes(laneCount: 20, columnCount: 20),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      expectNoOverflow(tester);
      // 超出可用空間的節點仍存在於元件樹（捲動承載，非裁切遺失）。
      expect(find.byKey(const ValueKey('node-19-19')), findsOneWidget);
    });
  });
}
