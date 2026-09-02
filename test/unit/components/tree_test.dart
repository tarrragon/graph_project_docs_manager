/// Tree 元件測試（SPEC-004 4.39、5.13）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  ListRow buildRow(String id, {Widget? trailing}) => ListRow.tree(
    leading: ExpanderIcon(
      isExpanded: true,
      testKey: ValueKey('expander-$id'),
    ),
    primary: AppText(id),
    trailing: trailing,
    onTap: () {},
    testKey: ValueKey('row-$id'),
  );

  /// 四層鏈：depth0 -> depth1 -> depth2 -> depth3，depth0 另有一個
  /// 含缺口列的兄弟節點（葉節點，SPEC-004 4.39「缺口列」）。
  List<TreeNode> buildFourLayerChain() {
    return [
      TreeNode(
        id: 'n0',
        row: buildRow('n0'),
        depth: 0,
        children: [
          TreeNode(
            id: 'n1',
            row: buildRow('n1'),
            depth: 1,
            children: [
              TreeNode(
                id: 'n2',
                row: buildRow('n2'),
                depth: 2,
                children: [
                  TreeNode(id: 'n3', row: buildRow('n3'), depth: 3),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        id: 'gap0',
        depth: 0,
        row: ListRow.tree(
          leading: ExpanderIcon(
            isExpanded: false,
            isLeaf: true,
            testKey: const ValueKey('expander-gap0'),
          ),
          primary: AppText('gap0'),
          trailing: IssueMarker.gap(
            onTap: () {},
            testKey: const ValueKey('gap-marker-gap0'),
          ),
          onTap: () {},
          testKey: const ValueKey('row-gap0'),
        ),
      ),
    ];
  }

  group('渲染四層 × 全收合 / 全展開 / 含缺口列', () {
    testWidgetsAtEachSize('全展開：四層與缺口列皆可見且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: Tree(
            nodes: buildFourLayerChain(),
            expanded: const {'n0', 'n1', 'n2'},
            onToggle: (_) {},
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('row-n0')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-n2')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-n3')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-gap0')), findsOneWidget);
      expect(find.byKey(const ValueKey('gap-marker-gap0')), findsOneWidget);
    });

    testWidgetsAtEachSize('全收合：只見第一層與缺口列，子層不渲染', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: Tree(
          nodes: buildFourLayerChain(),
          expanded: const {},
          onToggle: (_) {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('row-n0')), findsOneWidget);
      expect(find.byKey(const ValueKey('row-n1')), findsNothing);
      expect(find.byKey(const ValueKey('row-n2')), findsNothing);
      expect(find.byKey(const ValueKey('row-n3')), findsNothing);
      expect(find.byKey(const ValueKey('row-gap0')), findsOneWidget);
    });
  });

  group('排列不變式（SPEC-004 5.13）：不重疊、最小間距、空間不足策略', () {
    testWidgets('不重疊：同層相鄰列垂直互斥', (tester) async {
      await pumpHarness(
        tester,
        child: Tree(
          nodes: buildFourLayerChain(),
          expanded: const {},
          onToggle: (_) {},
        ),
      );

      final row0Bottom = tester.getBottomLeft(
        find.byKey(const ValueKey('row-n0')),
      ).dy;
      final gapTop = tester.getTopLeft(
        find.byKey(const ValueKey('row-gap0')),
      ).dy;

      expect(gapTop, greaterThanOrEqualTo(row0Bottom));
    });

    testWidgets('最小間距為 0：列間留白全由列高承載', (tester) async {
      await pumpHarness(
        tester,
        child: Tree(
          nodes: buildFourLayerChain(),
          expanded: const {},
          onToggle: (_) {},
        ),
      );

      final row0Bottom = tester.getBottomLeft(
        find.byKey(const ValueKey('row-n0')),
      ).dy;
      final gapTop = tester.getTopLeft(
        find.byKey(const ValueKey('row-gap0')),
      ).dy;

      expect(gapTop - row0Bottom, 0);
    });

    testWidgetsAtEachSize('水平不觸發：3 × treeIndent + 最小寬 於可用寬內不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: Tree(
          nodes: buildFourLayerChain(),
          expanded: const {'n0', 'n1', 'n2'},
          onToggle: (_) {},
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('垂直空間不足：捲動由外層 Panel.scrollable 承載', (
      tester,
      size,
    ) async {
      final nodes = List.generate(
        50,
        (i) => TreeNode(id: 'many-$i', row: buildRow('many-$i'), depth: 0),
      );

      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          key: const ValueKey('scroll-tree-panel'),
          child: Tree(nodes: nodes, expanded: const {}, onToggle: (_) {}),
        ),
      );

      expectNoOverflow(tester);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('row-many-49')),
        find.byKey(const ValueKey('scroll-tree-panel')),
        const Offset(0, -300),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('row-many-49')), findsOneWidget);
    });
  });

  group('縮排（SPEC-004 4.39 尺寸契約 / 測試點）', () {
    testWidgets('第 n 層列左緣 x = n × treeIndent', (tester) async {
      await pumpHarness(
        tester,
        child: Tree(
          nodes: buildFourLayerChain(),
          expanded: const {'n0', 'n1', 'n2'},
          onToggle: (_) {},
        ),
      );

      final x0 = tester.getTopLeft(find.byKey(const ValueKey('row-n0'))).dx;
      final x1 = tester.getTopLeft(find.byKey(const ValueKey('row-n1'))).dx;
      final x2 = tester.getTopLeft(find.byKey(const ValueKey('row-n2'))).dx;
      final x3 = tester.getTopLeft(find.byKey(const ValueKey('row-n3'))).dx;

      expect(x1 - x0, LayoutSize.treeIndent.w);
      expect(x2 - x0, LayoutSize.treeIndent.w * 2);
      expect(x3 - x0, LayoutSize.treeIndent.w * 3);
    });
  });

  group('展開收合行為', () {
    testWidgets('展開收合子層出現/消失，不改變父捲動 offset', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final state = _ToggleState();

      await pumpHarness(
        tester,
        child: _ToggleHarness(state: state, controller: controller),
      );

      expect(find.byKey(const ValueKey('row-n1')), findsNothing);

      controller.jumpTo(500);
      await tester.pump();
      final before = controller.offset;

      state.setExpanded(true);
      await tester.pump();
      await tester.pump(
        Motion.transition(tester.element(find.byKey(const ValueKey('row-n0')))),
      );

      expect(find.byKey(const ValueKey('row-n1')), findsOneWidget);
      expect(controller.offset, before);
    });
  });
}

/// 供測試切換 [Tree.expanded] 的可變容器（同 `section_test.dart` 慣例）。
class _ToggleState {
  VoidCallback? _listener;
  Set<String> expanded = const {};

  void setExpanded(bool expand) {
    expanded = expand ? const {'n0'} : const {};
    _listener?.call();
  }
}

class _ToggleHarness extends StatefulWidget {
  const _ToggleHarness({required this.state, required this.controller});

  final _ToggleState state;
  final ScrollController controller;

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
          const SizedBox(height: 2000),
          Tree(
            nodes: [
              TreeNode(
                id: 'n0',
                row: ListRow.tree(
                  leading: ExpanderIcon(
                    isExpanded: widget.state.expanded.contains('n0'),
                    testKey: const ValueKey('expander-n0'),
                  ),
                  primary: AppText('n0'),
                  onTap: () {},
                  testKey: const ValueKey('row-n0'),
                ),
                depth: 0,
                children: [
                  TreeNode(
                    id: 'n1',
                    row: ListRow.tree(
                      leading: ExpanderIcon(
                        isExpanded: false,
                        isLeaf: true,
                        testKey: const ValueKey('expander-n1'),
                      ),
                      primary: AppText('n1'),
                      onTap: () {},
                      testKey: const ValueKey('row-n1'),
                    ),
                    depth: 1,
                  ),
                ],
              ),
            ],
            expanded: widget.state.expanded,
            onToggle: (_) {},
          ),
        ],
      ),
    );
  }
}
