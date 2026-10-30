/// SwimlaneGrid 元件測試（SPEC-004 4.38、5.12）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_en.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const scrollKey = ValueKey('scroll-domain-swimlane');
  const dragKey = ValueKey('drag-domain-swimlane');

  List<SwimlaneLane> buildLanes({
    int laneCount = 6,
    int columnCount = 6,
    String Function(int lane)? nameOf,
    bool withDomainId = false,
  }) {
    return List.generate(laneCount, (laneIndex) {
      final name = nameOf?.call(laneIndex) ?? 'lane-$laneIndex';
      return SwimlaneLane(
        name: name,
        domainId: withDomainId ? 'lane-$laneIndex' : null,
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
      // 用 pumpAndSettle 而非單次 pump：讓桌機捲軸淡出等過場動畫（與捲動
      // offset 無關）走完，避免瞬時視覺狀態造成的次像素位置雜訊。
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byKey(const ValueKey('node-0-0')));

      expect((after - before).distance, lessThan(1));
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
      final lanes = buildLanes(
        laneCount: 20,
        columnCount: 2,
        withDomainId: true,
      );
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

  group('高亮以 domainId 比對：兩列同字面（SPEC-004 4.38 laneHighlight）', () {
    // 20 列全部同字面、domainId 各異；命中列以 jumpTo 可觀測
    // （第 19 列在初始 viewport 外，第 0 列在其內）。
    final lanes = buildLanes(
      laneCount: 20,
      columnCount: 2,
      nameOf: (_) => 'same-name',
      withDomainId: true,
    );

    Future<void> pumpHighlight(WidgetTester tester, String? id) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 200,
          child: SwimlaneGrid(
            lanes: lanes,
            laneHighlight: id,
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );
      await tester.pump();
    }

    // 表格延遲建構：視窗外的節點不存在，視為不可見。
    bool lastLaneVisible(WidgetTester tester) {
      final node = find.byKey(const ValueKey('node-19-0'));
      if (node.evaluate().isEmpty) return false;
      return tester.getRect(node).overlaps(tester.getRect(find.byKey(dragKey)));
    }

    testWidgets('指向 lane-19 的 domainId：只該列命中並捲動至可見', (tester) async {
      await pumpHighlight(tester, 'lane-19');
      expect(lastLaneVisible(tester), isTrue);
    });

    testWidgets('E1 對照：改指向 lane-0 的 domainId：高亮在首列，末列不捲入', (tester) async {
      await pumpHighlight(tester, 'lane-0');
      expect(lastLaneVisible(tester), isFalse);
    });
  });

  group('互動反應：locateColumn 水平捲到目標欄（SPEC-004 4.38）', () {
    Widget gridWith(List<SwimlaneLane> lanes, {int? column, String? lane}) {
      return SizedBox(
        width: 400,
        height: 200,
        child: SwimlaneGrid(
          lanes: lanes,
          laneHighlight: lane,
          locateColumn: column,
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );
    }

    testWidgets('locateColumn 指向 viewport 外的欄時目標節點與 viewport 相交', (
      tester,
    ) async {
      final lanes = buildLanes(
        laneCount: 3,
        columnCount: 20,
        withDomainId: true,
      );
      await pumpHarness(tester, child: gridWith(lanes));
      await pumpHarness(
        tester,
        child: gridWith(lanes, lane: 'lane-1', column: 15),
      );
      await tester.pump();

      final viewportRect = tester.getRect(find.byKey(dragKey));
      final nodeRect = tester.getRect(find.byKey(const ValueKey('node-1-15')));
      expect(nodeRect.overlaps(viewportRect), isTrue);
    });

    testWidgets('E1 對照：locateColumn 為 null 時不做水平捲動', (tester) async {
      final lanes = buildLanes(laneCount: 3, columnCount: 20);
      await pumpHarness(tester, child: gridWith(lanes));
      await pumpHarness(tester, child: gridWith(lanes, lane: 'lane-1'));
      await tester.pump();

      final viewportRect = tester.getRect(find.byKey(dragKey));
      final nodeRect = tester.getRect(find.byKey(const ValueKey('node-1-0')));
      expect(nodeRect.overlaps(viewportRect), isTrue);
      expect(find.byKey(const ValueKey('node-1-15')), findsNothing);
    });
  });

  group('尺寸與顏色引用 token 非硬編碼', () {
    testWidgets('泳道列高為 LayoutSize.laneRowHeight', (tester) async {
      // TableView 的列高由 rowBuilder 的 TableSpan.extent 決定，非獨立可
      // find 的 Container；改量相鄰兩泳道列同欄節點的垂直間距，等於
      // TableSpan 給的列高（本測試 1 欄 2 泳道，兩節點分屬相鄰列同欄）。
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: SwimlaneGrid(
          lanes: buildLanes(laneCount: 2, columnCount: 1),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      final row0Top = tester
          .getTopLeft(find.byKey(const ValueKey('node-0-0')))
          .dy;
      final row1Top = tester
          .getTopLeft(find.byKey(const ValueKey('node-1-0')))
          .dy;

      expect(row1Top - row0Top, LayoutSize.laneRowHeight);
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

    testWidgetsAtEachSize('空間不足策略：泳道數與步驟欄數超出可用空間時可捲動不溢位', (tester, size) async {
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
      // TableView 為 lazy 渲染，畫面外節點本就不在元件樹（非裁切遺失，
      // 是延遲建構）；驗證「可捲動」改為拖曳至邊界後，原本畫面外的最後
      // 一格能進入畫面。
      await tester.drag(find.byKey(scrollKey), const Offset(-100000, -100000));
      await tester.pump();
      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('node-19-19')), findsOneWidget);
    });
  });

  group('onSelectDomain（SPEC-003 §3.1，比照 MatrixGrid.onSelectDomain）', () {
    List<SwimlaneLane> buildLanesWithDomainId() => [
      const SwimlaneLane(name: 'lane-0', domainId: 'domain-0', nodes: []),
      const SwimlaneLane(name: 'lane-1', domainId: 'domain-1', nodes: []),
    ];

    testWidgets('不傳 onSelectDomain：泳道名格維持唯讀，無 button 語意、無 InkWell（對照組）', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SwimlaneGrid(
          lanes: buildLanesWithDomainId(),
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );

      expect(
        find.byKey(const ValueKey('action-domain-select-domain-0')),
        findsNothing,
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('傳 onSelectDomain：泳道名格為可點 button 語意，點擊觸發回呼傳出該列 domainId', (
      tester,
    ) async {
      String? tapped;

      await pumpHarness(
        tester,
        child: SwimlaneGrid(
          lanes: buildLanesWithDomainId(),
          scrollKey: scrollKey,
          dragKey: dragKey,
          onSelectDomain: (domainId) => tapped = domainId,
        ),
      );

      final selectKey = find.byKey(
        const ValueKey('action-domain-select-domain-0'),
      );
      expect(selectKey, findsOneWidget);
      final semantics = tester.getSemantics(selectKey);
      expect(semantics.flagsCollection.isButton, isTrue);

      await tester.tap(selectKey);
      await tester.pump();
      expect(tapped, 'domain-0');
    });

    testWidgets('domainId 為 null 時維持唯讀，即使有傳 onSelectDomain', (tester) async {
      await pumpHarness(
        tester,
        child: SwimlaneGrid(
          lanes: buildLanes(laneCount: 1, columnCount: 1),
          scrollKey: scrollKey,
          dragKey: dragKey,
          onSelectDomain: (_) {},
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('0.5.0 lanes kind／edges（K2、K4）', () {
    const en = Locale('en');

    Widget gridOf(
      List<SwimlaneLane> lanes, {
      List<SwimlaneEdge> edges = const [],
      String? highlight,
      ValueChanged<String>? onSelect,
    }) => SizedBox(
      width: 700,
      height: 500,
      child: SwimlaneGrid(
        lanes: lanes,
        edges: edges,
        laneHighlight: highlight,
        onSelectDomain: onSelect,
        scrollKey: scrollKey,
        dragKey: dragKey,
      ),
    );

    SwimlaneNode nodeOf(String id) => SwimlaneNode(label: id, isActive: false);

    List<SwimlaneLane> mixedLanes() => [
      const SwimlaneLane(
        name: 'presentation',
        kind: SwimlaneLaneKind.screen,
        domainId: 'presentation',
        nodes: [],
      ),
      const SwimlaneLane(name: 'ticketdetail', domainId: 'td', nodes: []),
      SwimlaneLane(
        name: 'unplaced-raw',
        kind: SwimlaneLaneKind.unplaced,
        nodes: [(nodeOf('u1'), 0), (nodeOf('u2'), 1)],
      ),
    ];

    testWidgets('K2-1：zh 畫面列與 domain 原值', (tester) async {
      await pumpHarness(tester, child: gridOf(mixedLanes()));
      expect(find.text('畫面'), findsOneWidget);
      expect(find.text('ticketdetail'), findsOneWidget);
      expect(find.text('presentation'), findsNothing);
    });

    testWidgets('K2-1：en 畫面列', (tester) async {
      await pumpHarness(tester, locale: en, child: gridOf(mixedLanes()));
      expect(find.text('Screen'), findsOneWidget);
      expect(find.text('ticketdetail'), findsOneWidget);
    });

    testWidgets('K2-5：未定位列列首走 i18n，節點依欄號渲染', (tester) async {
      await pumpHarness(tester, child: gridOf(mixedLanes()));
      expect(find.text('未定位'), findsOneWidget);
      expect(find.text('unplaced-raw'), findsNothing);
      expect(find.text('u1'), findsOneWidget);
      expect(find.text('u2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('u1')).dx,
        lessThan(tester.getTopLeft(find.text('u2')).dx),
      );
      await pumpHarness(tester, locale: en, child: gridOf(mixedLanes()));
      expect(find.text('Unplaced'), findsOneWidget);
    });

    testWidgets('K2-2：畫面列與未定位列列首不可點、不高亮', (tester) async {
      final taps = <String>[];
      await pumpHarness(
        tester,
        child: gridOf(
          mixedLanes(),
          highlight: 'presentation',
          onSelect: taps.add,
        ),
      );
      await tester.tap(find.text('畫面'));
      await tester.tap(find.text('未定位'));
      expect(taps, isEmpty);
      expect(
        find.byKey(const Key('action-domain-select-presentation')),
        findsNothing,
      );
      // 對照：domain 列可點
      await tester.tap(find.text('ticketdetail'));
      expect(taps, ['td']);
    });

    testWidgets('K2-3（E1）：straight／arc 各渲染一條，空 edges 無邊', (tester) async {
      await pumpHarness(tester, child: gridOf(mixedLanes()));
      expect(find.byType(CustomPaint).evaluate().where(_isEdge), isEmpty);
      await pumpHarness(
        tester,
        child: gridOf(
          mixedLanes(),
          edges: const [
            SwimlaneEdge(
              fromColumn: 0,
              toColumn: 1,
              shape: SwimlaneEdgeShape.straight,
            ),
            SwimlaneEdge(
              fromColumn: 1,
              toColumn: 0,
              shape: SwimlaneEdgeShape.arc,
            ),
          ],
        ),
      );
      final straight = find.byKey(const Key('swimlane-edge-straight-0-1'));
      final arc = find.byKey(const Key('swimlane-edge-arc-1-0'));
      expect(straight, findsOneWidget);
      expect(arc, findsOneWidget);
      final straightRender = tester.renderObject(straight);
      final arcRender = tester.renderObject(arc);
      expect(straightRender, paints..line());
      expect(straightRender, isNot(paints..path()));
      expect(arcRender, paints..path());
      expect(arcRender, isNot(paints..line()));
    });

    SwimlaneEdge edgeOf(int from, int to, SwimlaneEdgeShape shape) =>
        SwimlaneEdge(fromColumn: from, toColumn: to, shape: shape);

    testWidgets('F2：邊 rect 左緣為起欄左緣、右緣為訖欄右緣', (tester) async {
      final lanes = mixedLanes();
      await pumpHarness(
        tester,
        child: gridOf(lanes, edges: [edgeOf(0, 1, SwimlaneEdgeShape.straight)]),
      );
      final u1 = tester.getCenter(find.text('u1')).dx;
      final u2 = tester.getCenter(find.text('u2')).dx;
      final step = u2 - u1;
      final rect = tester.getRect(
        find.byKey(const Key('swimlane-edge-straight-0-1')),
      );
      expect(rect.left, closeTo(u1 - step / 2, 0.5));
      expect(rect.right, closeTo(u2 + step / 2, 0.5));

      // 較小欄號 > 0：前向 (1,2) 與回指 (2,1)，rect 涵蓋欄 1 左緣至欄 2 右緣。
      await pumpHarness(
        tester,
        child: gridOf(
          [
            SwimlaneLane(
              name: 'dom',
              nodes: [(nodeOf('c0'), 0), (nodeOf('c1'), 1), (nodeOf('c2'), 2)],
            ),
          ],
          edges: [
            edgeOf(1, 2, SwimlaneEdgeShape.straight),
            edgeOf(2, 1, SwimlaneEdgeShape.arc),
          ],
        ),
      );
      final c1 = tester.getCenter(find.text('c1')).dx;
      final c2 = tester.getCenter(find.text('c2')).dx;
      final colStep = c2 - c1;
      for (final key in const [
        Key('swimlane-edge-straight-1-2'),
        Key('swimlane-edge-arc-2-1'),
      ]) {
        final edgeRect = tester.getRect(find.byKey(key));
        expect(edgeRect.left, closeTo(c1 - colStep / 2, 0.5), reason: '$key');
        expect(edgeRect.right, closeTo(c2 + colStep / 2, 0.5), reason: '$key');
      }
    });

    testWidgets('F2：跨欄邊溢出起始格時不被格裁切（寬度為兩欄）', (tester) async {
      await pumpHarness(
        tester,
        child: gridOf(
          mixedLanes(),
          edges: [edgeOf(0, 1, SwimlaneEdgeShape.straight)],
        ),
      );
      final rect = tester.getRect(
        find.byKey(const Key('swimlane-edge-straight-0-1')),
      );
      final u1 = tester.getCenter(find.text('u1')).dx;
      final u2 = tester.getCenter(find.text('u2')).dx;
      expect(rect.width, closeTo(2 * (u2 - u1), 0.5));
    });

    // SPEC-004 v1.87 4.38：起點欄完全捲出、終點欄仍在畫面內時邊段仍繪製；
    // 捲動前同一條邊可見作為對照。
    testWidgets('F2：起始格捲出視窗後跨欄邊的存續', (tester) async {
      const edgeKey = Key('swimlane-edge-straight-0-12');
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 700,
          height: 300,
          child: SwimlaneGrid(
            lanes: [
              SwimlaneLane(
                name: 'dom',
                nodes: [
                  (nodeOf('n0'), 0),
                  (nodeOf('n12'), 12),
                  (nodeOf('n15'), 15),
                ],
              ),
            ],
            edges: [edgeOf(0, 12, SwimlaneEdgeShape.straight)],
            scrollKey: scrollKey,
            dragKey: dragKey,
          ),
        ),
      );
      final viewport = tester.getRect(find.byKey(scrollKey));
      expect(find.byKey(edgeKey), findsOneWidget, reason: '對照：捲動前可見');
      final before = tester.getRect(find.byKey(edgeKey));
      expect(before.overlaps(viewport), isTrue, reason: '對照：捲動前落在視窗內');

      final hState = tester
          .state<TwoDimensionalScrollableState>(
            find.byType(TwoDimensionalScrollable),
          )
          .horizontalScrollable;
      final delta = 10 * 96.w;
      hState.position.jumpTo(delta);
      await tester.pump();

      // 起點欄完全捲出（超出快取範圍，格已回收）；終點欄仍在視窗內。
      expect(find.text('n0'), findsNothing, reason: '前提：起點欄已完全捲出');
      expect(find.text('n12'), findsOneWidget, reason: '前提：終點欄仍在畫面內');
      expect(
        viewport.contains(tester.getCenter(find.text('n12'))),
        isTrue,
        reason: '前提：終點欄落在視窗內',
      );
      expect(find.byKey(edgeKey), findsOneWidget, reason: '邊段仍須繪製');
      final after = tester.getRect(find.byKey(edgeKey));
      expect(after.overlaps(viewport), isTrue, reason: '邊段落在視窗內');
      expect(after.left, closeTo(before.left - delta, 0.5), reason: '1:1 位移');
      expect(after.right, closeTo(before.right - delta, 0.5));
    });

    testWidgets('F3：空 edges 不增邊列，有 edges 恰多一個邊列高', (tester) async {
      double extentOf(WidgetTester t) => t
          .state<TwoDimensionalScrollableState>(
            find.byType(TwoDimensionalScrollable),
          )
          .verticalScrollable
          .position
          .maxScrollExtent;
      Widget small({List<SwimlaneEdge> edges = const []}) => SizedBox(
        width: 700,
        height: 100,
        child: SwimlaneGrid(
          lanes: mixedLanes(),
          edges: edges,
          scrollKey: scrollKey,
          dragKey: dragKey,
        ),
      );
      await pumpHarness(tester, child: small());
      final empty = extentOf(tester);
      expect(empty, closeTo(3 * LayoutSize.laneRowHeight.h + 28.h - 100, 0.5));
      await pumpHarness(
        tester,
        child: small(edges: [edgeOf(0, 1, SwimlaneEdgeShape.straight)]),
      );
      expect(extentOf(tester) - empty, closeTo(28.h, 0.5));
    });

    testWidgets('K2-4（E1）：列數取自輸入（2 列與 9 列）', (tester) async {
      List<SwimlaneLane> make(int n) => [
        const SwimlaneLane(name: 'p', kind: SwimlaneLaneKind.screen, nodes: []),
        for (var i = 1; i < n; i++)
          SwimlaneLane(name: 'dom-$i', nodes: const []),
      ];
      await pumpHarness(tester, child: gridOf(make(2)));
      expect(find.textContaining('dom-'), findsOneWidget);
      await pumpHarness(tester, child: gridOf(make(9)));
      expect(find.textContaining('dom-'), findsNWidgets(8));
    });

    test('K4-1／K4-2：ARB 值與 §4.0.6 逐字一致', () {
      final zh = AppLocalizationsZh();
      final enL = AppLocalizationsEn();
      expect(zh.swimlaneScreenLaneName, '畫面');
      expect(enL.swimlaneScreenLaneName, 'Screen');
      expect(zh.swimlaneUnplacedLaneName, '未定位');
      expect(enL.swimlaneUnplacedLaneName, 'Unplaced');
      expect(zh.relationProposedLabel, '暫定');
      expect(enL.relationProposedLabel, 'Proposed');
      expect(zh.relationItemProposedA11yLabel('X'), '關聯節點 X，暫定邊，形狀可能變動');
      expect(
        enL.relationItemProposedA11yLabel('X'),
        'Related node X, proposed edge, shape may change',
      );
    });
  });
}

bool _isEdge(Element e) => e.widget.key.toString().contains('swimlane-edge');
