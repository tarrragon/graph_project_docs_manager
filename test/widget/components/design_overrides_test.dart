/// 設計覆寫接縫測試（0.5.0-W1-466.5）。
///
/// 每類各跑「不注入」與「注入」，斷言兩者不同（E1），並斷言不注入時等於
/// 原 token 值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/components/design_overrides.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  Widget button() =>
      AppButton(label: 'go', onPressed: () {}, testKey: const ValueKey('btn'));

  Widget section() => Section(
    variant: SectionVariant.static,
    header: const AppText.singleLine('h'),
    items: const [
      AppText.singleLine('a', key: ValueKey('a')),
      AppText.singleLine('b', key: ValueKey('b')),
    ],
    testKey: const ValueKey('sec'),
  );

  Widget marker() =>
      IssueMarker.damagedDetail(onTap: () {}, testKey: const ValueKey('mk'));

  Color? buttonBackground(WidgetTester tester) {
    final b = tester.widget<TextButton>(find.byKey(const ValueKey('btn')));
    return b.style?.backgroundColor?.resolve({});
  }

  double itemGap(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const ValueKey('b'))).dy -
      tester.getTopLeft(find.byKey(const ValueKey('a'))).dy;

  Color markerColor(WidgetTester tester) => tester
      .widget<AppIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('mk')),
          matching: find.byType(AppIcon),
        ),
      )
      .color;

  testWidgets('A 按鈕：不注入為原色，注入後不同', (tester) async {
    await pumpHarness(tester, child: button());
    final base = buttonBackground(tester);
    expect(base, AppColors.accent);

    await pumpHarness(
      tester,
      child: DesignOverrides(
        buttonColors: const {
          AppButtonVariant.primary: ButtonColorOverride(
            background: Color(0xFF123456),
          ),
        },
        child: button(),
      ),
    );
    expect(buttonBackground(tester), const Color(0xFF123456));
    expect(buttonBackground(tester), isNot(base));
  });

  testWidgets('B 分節：不注入間距為 Space.xxs 加列高，注入後不同', (tester) async {
    await pumpHarness(tester, child: section());
    final base = itemGap(tester);

    await pumpHarness(
      tester,
      child: DesignOverrides(sectionItemGap: 20, child: section()),
    );
    expect(itemGap(tester), isNot(base));
    expect(itemGap(tester) - base, 20 - Space.xxs);
  });

  testWidgets("C' 標記：不注入為 error 色，注入後不同", (tester) async {
    await pumpHarness(tester, child: marker());
    final base = markerColor(tester);
    expect(base, AppColors.error);

    await pumpHarness(
      tester,
      child: DesignOverrides(
        issueMarkerColor: const Color(0xFF00AA00),
        child: marker(),
      ),
    );
    expect(markerColor(tester), const Color(0xFF00AA00));
    expect(markerColor(tester), isNot(base));
  });

  Widget tree() => Tree(
    expanded: const {},
    onToggle: (_) {},
    nodes: [
      TreeNode(
        id: 'n',
        depth: 2,
        row: ListRow.tree(
          leading: const SizedBox(),
          primary: const AppText.singleLine('r'),
          onTap: () {},
          testKey: const ValueKey('row'),
        ),
      ),
    ],
  );

  testWidgets('樹縮排：不注入為 LayoutSize.treeIndent，注入後不同', (tester) async {
    await pumpHarness(tester, child: tree());
    final base = tester.getTopLeft(find.byKey(const ValueKey('row'))).dx;

    await pumpHarness(
      tester,
      child: DesignOverrides(treeIndent: 60, child: tree()),
    );
    final changed = tester.getTopLeft(find.byKey(const ValueKey('row'))).dx;
    expect(changed, isNot(base));
    expect(changed, greaterThan(base));
  });

  Widget expander() =>
      const ExpanderIcon(isExpanded: false, testKey: ValueKey('ex'));

  IconData expanderIconData(WidgetTester tester) => tester
      .widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('ex')),
          matching: find.byType(Icon),
        ),
      )
      .icon!;

  testWidgets('展開圖示：不注入為預設箭頭，注入後不同', (tester) async {
    await pumpHarness(tester, child: expander());
    final base = expanderIconData(tester);
    expect(base, Icons.keyboard_arrow_right);

    await pumpHarness(
      tester,
      child: DesignOverrides(
        expanderIconCollapsed: Icons.add,
        child: expander(),
      ),
    );
    expect(expanderIconData(tester), Icons.add);
    expect(expanderIconData(tester), isNot(base));
  });

  Widget filter() => FilterDropdown(
    label: 'L',
    options: const [FilterOption(value: 'a', label: 'A')],
    selected: null,
    onChanged: (_) {},
    testKey: const ValueKey('fd'),
    screen: 'tickets',
    kind: 'filter-status',
  );

  BoxDecoration filterDecoration(WidgetTester tester) {
    final c = tester.widget<Container>(
      find.descendant(
        of: find.byType(FilterDropdown),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      ),
    );
    return c.decoration! as BoxDecoration;
  }

  testWidgets('篩選下拉配色：不注入為原 token，注入後不同', (tester) async {
    await pumpHarness(tester, child: filter());
    final base = filterDecoration(tester);
    expect(base.color, AppColors.surfaceBase);

    await pumpHarness(
      tester,
      child: DesignOverrides(
        filterDropdownColors: const FilterDropdownColorOverride(
          background: Color(0xFF223344),
        ),
        child: filter(),
      ),
    );
    expect(filterDecoration(tester).color, const Color(0xFF223344));
    expect(filterDecoration(tester).color, isNot(base.color));
  });
}
