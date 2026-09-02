/// [RecentProjectItem] widget test（SPEC-004 §4.9「測試點」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _enabledKey = ValueKey('card-switcher-recent-0');
const _selectedKey = ValueKey('card-switcher-recent-1');
const _disabledKey = ValueKey('card-switcher-recent-2');
const _withHealthKey = ValueKey('card-switcher-recent-3');

RecentProjectItem _enabled({
  String name = 'book_overview_app',
  String summary = '237 節點 · 2419 票',
  Key testKey = _enabledKey,
  VoidCallback? onTap,
}) {
  return RecentProjectItem(
    name: name,
    summary: summary,
    enabled: true,
    isCurrent: false,
    onTap: onTap ?? () {},
    testKey: testKey,
  );
}

RecentProjectItem _selected({
  String name = 'book_overview_app',
  String summary = '237 節點 · 2419 票',
  Key testKey = _selectedKey,
}) {
  return RecentProjectItem(
    name: name,
    summary: summary,
    enabled: true,
    isCurrent: true,
    onTap: () {},
    testKey: testKey,
  );
}

RecentProjectItem _disabled({
  String name = 'book_overview_app',
  String summary = '237 節點 · 2419 票',
  String reason = '無法使用：逾時',
  Key testKey = _disabledKey,
  VoidCallback? onTap,
}) {
  return RecentProjectItem(
    name: name,
    summary: summary,
    enabled: false,
    isCurrent: false,
    reason: reason,
    onTap: onTap ?? () {},
    testKey: testKey,
  );
}

void main() {
  group('三狀態 × 兩尺寸 不溢位', () {
    for (final size in WindowSize.values) {
      testWidgets('enabled @ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(width: LayoutSize.overlayWidth, child: _enabled()),
        );

        expectNoOverflow(tester);
      });

      testWidgets('selected @ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(width: LayoutSize.overlayWidth, child: _selected()),
        );

        expectNoOverflow(tester);
      });

      testWidgets('disabled @ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(width: LayoutSize.overlayWidth, child: _disabled()),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('health slot', () {
    testWidgets('傳入 health 徽章時渲染且不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: RecentProjectItem(
            name: 'book_overview_app',
            summary: '237 節點 · 2419 票',
            enabled: true,
            isCurrent: false,
            onTap: () {},
            testKey: _withHealthKey,
            health: const Badge.health(
              key: Key('badge-switcher-health-0'),
              count: 3,
              semanticLabel: '3 個問題',
            ),
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const Key('badge-switcher-health-0')), findsOneWidget);
    });

    testWidgets('未傳入 health 時不渲染徽章', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(width: LayoutSize.overlayWidth, child: _enabled()),
      );

      expect(find.byType(Badge), findsNothing);
    });
  });

  group('最長測試文案不溢位', () {
    testWidgets('name / summary 以最長文案渲染不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _enabled(name: TestCopy.longToken, summary: TestCopy.longEn),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('disabled reason 以最長文案渲染不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _disabled(reason: TestCopy.longZh),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('點選行為', () {
    testWidgets('enabled 點選呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _enabled(onTap: () => callCount++),
        ),
      );

      await tester.tap(find.byKey(_enabledKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('selected 點選仍呼叫 onTap（SPEC-003 §3.7 視同選取）', (
      tester,
    ) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: RecentProjectItem(
            name: 'book_overview_app',
            summary: '237 節點 · 2419 票',
            enabled: true,
            isCurrent: true,
            onTap: () => callCount++,
            testKey: _selectedKey,
          ),
        ),
      );

      await tester.tap(find.byKey(_selectedKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('disabled 點選不呼叫 onTap', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _disabled(onTap: () => callCount++),
        ),
      );

      await tester.tap(find.byKey(_disabledKey), warnIfMissed: false);
      await tester.pump();

      expect(callCount, 0);
    });
  });

  group('無障礙', () {
    testWidgets('enabled 朗讀標籤為「{name}，{summary}」', (tester) async {
      await pumpHarness(tester, child: _enabled());

      final semantics = tester.getSemantics(find.byKey(_enabledKey));
      expect(semantics.label, 'book_overview_app，237 節點 · 2419 票');
    });

    testWidgets('selected 朗讀標籤附加 currentProjectA11yLabel', (tester) async {
      await pumpHarness(tester, child: _selected());

      final semantics = tester.getSemantics(find.byKey(_selectedKey));
      expect(semantics.label, contains('目前專案'));
      expect(semantics.flagsCollection.isSelected.toString(), contains('True'));
    });

    testWidgets('disabled 的 hint 為 reason', (tester) async {
      await pumpHarness(
        tester,
        child: _disabled(reason: '無法使用：逾時'),
      );

      final semantics = tester.getSemantics(find.byKey(_disabledKey));
      expect(semantics.hint, '無法使用：逾時');
      expect(semantics.flagsCollection.isEnabled.toString(), contains('False'));
    });

    testWidgets('button 語意旗標恆為 true', (tester) async {
      await pumpHarness(tester, child: _enabled());

      final semantics = tester.getSemantics(find.byKey(_enabledKey));
      expect(semantics.flagsCollection.isButton, isTrue);
    });
  });
}
