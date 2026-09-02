/// Section 元件測試（SPEC-004 4.41、5.15）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('section-test');

  Widget buildHeader({String text = 'header'}) => AppText(text);

  List<Widget> buildItems(int count) =>
      List.generate(count, (i) => AppText('item-$i', key: ValueKey('item-$i')));

  group('變體與狀態矩陣：collapsible expanded/collapsed、static', () {
    testWidgetsAtEachSize('collapsible expanded 渲染節首與 50 項且不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        // Section 依 SPEC-004 5.15「可放入的容器」置於 Panel.scrollable；
        // 本容器自身不設捲動區，50 項需外層捲動容器承載。
        child: SingleChildScrollView(
          child: Section(
            variant: SectionVariant.collapsible,
            header: buildHeader(),
            items: buildItems(50),
            isExpanded: true,
            testKey: testKey,
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.byKey(const ValueKey('item-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('item-49')), findsOneWidget);
    });

    testWidgetsAtEachSize('collapsible collapsed 只渲染節首（0 項）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: Section(
          variant: SectionVariant.collapsible,
          header: buildHeader(),
          items: buildItems(50),
          isExpanded: false,
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      // 收合後項目不存在於元件樹（SPEC-004 4.41 測試點）——0 項渲染，不需捲動容器。
      expect(find.byKey(const ValueKey('item-0')), findsNothing);
    });

    testWidgetsAtEachSize('collapsible 0 項時只渲染節首，不例外', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: Section(
          variant: SectionVariant.collapsible,
          header: buildHeader(),
          items: const [],
          isExpanded: true,
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgetsAtEachSize('static 恆展開，忽略 isExpanded', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: Section(
          variant: SectionVariant.static,
          header: AppText('關聯群', variant: AppTextVariant.caption),
          items: buildItems(3),
          isExpanded: false,
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('item-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('item-2')), findsOneWidget);
    });

    testWidgetsAtEachSize('dashedTop 修飾不影響渲染且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: Section(
          variant: SectionVariant.collapsible,
          header: buildHeader(),
          items: buildItems(2),
          isExpanded: true,
          dashedTop: true,
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });
  });

  group('排列不變式（SPEC-004 5.15）：不重疊、最小間距、空間不足策略', () {
    testWidgets('header 與 items 依序垂直堆疊，不重疊', (tester) async {
      await pumpHarness(
        tester,
        child: Section(
          variant: SectionVariant.collapsible,
          header: buildHeader(),
          items: buildItems(2),
          isExpanded: true,
          testKey: testKey,
        ),
      );

      final headerBottom = tester.getBottomLeft(find.text('header')).dy;
      final firstItemTop = tester.getTopLeft(
        find.byKey(const ValueKey('item-0')),
      ).dy;

      // 不重疊：第一個項目頂端不早於節首底部。
      expect(firstItemTop, greaterThanOrEqualTo(headerBottom));
    });

    testWidgets('最小間距為 Space.xxs（項目之間）', (tester) async {
      await pumpHarness(
        tester,
        child: Section(
          variant: SectionVariant.collapsible,
          header: buildHeader(),
          items: buildItems(2),
          isExpanded: true,
          testKey: testKey,
        ),
      );

      final item0Bottom = tester.getBottomLeft(
        find.byKey(const ValueKey('item-0')),
      ).dy;
      final item1Top = tester.getTopLeft(
        find.byKey(const ValueKey('item-1')),
      ).dy;

      expect(item1Top - item0Bottom, Space.xxs);
    });

    testWidgetsAtEachSize('空間不足時：50 項置於捲動容器可捲至末端', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          key: const ValueKey('scroll-test-panel'),
          child: Section(
            variant: SectionVariant.collapsible,
            header: buildHeader(),
            items: buildItems(50),
            isExpanded: true,
            testKey: testKey,
          ),
        ),
      );

      expectNoOverflow(tester);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('item-49')),
        find.byKey(const ValueKey('scroll-test-panel')),
        const Offset(0, -300),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('item-49')), findsOneWidget);
    });
  });

  group('展開收合行為', () {
    testWidgets('展開收合不改變父捲動 offset（SPEC-004 4.41 測試點）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final state = _ToggleState();

      await pumpHarness(
        tester,
        child: _ToggleHarness(
          state: state,
          controller: controller,
          header: buildHeader(),
          items: buildItems(20),
          testKey: testKey,
        ),
      );

      controller.jumpTo(500);
      await tester.pump();
      final before = controller.offset;

      state.setExpanded(false);
      await tester.pump();
      await tester.pump(
        Motion.transition(tester.element(find.byKey(testKey))),
      );

      expect(controller.offset, before);
    });
  });
}

/// 供測試切換 [Section.isExpanded] 的可變容器（避免 closure 捕獲值不觸發重建）。
class _ToggleState {
  VoidCallback? _listener;
  bool expanded = true;

  void setExpanded(bool value) {
    expanded = value;
    _listener?.call();
  }
}

class _ToggleHarness extends StatefulWidget {
  const _ToggleHarness({
    required this.state,
    required this.controller,
    required this.header,
    required this.items,
    required this.testKey,
  });

  final _ToggleState state;
  final ScrollController controller;
  final Widget header;
  final List<Widget> items;
  final Key testKey;

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  @override
  void initState() {
    super.initState();
    widget.state._listener = () => setState(() {});
  }

  @override
  void dispose() {
    widget.state._listener = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.controller,
      child: Column(
        children: [
          SizedBox(height: 2000),
          Section(
            variant: SectionVariant.collapsible,
            header: widget.header,
            items: widget.items,
            isExpanded: widget.state.expanded,
            testKey: widget.testKey,
          ),
        ],
      ),
    );
  }
}
