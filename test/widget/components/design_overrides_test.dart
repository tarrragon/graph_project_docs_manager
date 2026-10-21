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
  Widget button() => AppButton(
    label: 'go',
    onPressed: () {},
    testKey: const ValueKey('btn'),
  );

  Widget section() => Section(
    variant: SectionVariant.static,
    header: const AppText('h'),
    items: const [
      AppText('a', key: ValueKey('a')),
      AppText('b', key: ValueKey('b')),
    ],
    testKey: const ValueKey('sec'),
  );

  Widget marker() => IssueMarker.damagedDetail(
    onTap: () {},
    testKey: const ValueKey('mk'),
  );

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
}
