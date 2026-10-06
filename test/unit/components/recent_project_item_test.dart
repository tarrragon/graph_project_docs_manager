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

const _degradedZh = '內建型別表';
const _degradedEn = 'Built-in schema';

/// SPEC-004 4.9 尺寸契約最小寬：2 × `Space.sm` + `iconLg` + `Space.sm` + 一字元。
const _minItemWidth = 3 * Space.sm + LayoutSize.iconLg + AppFontSize.body;

RecentProjectItem _degraded({
  required bool enabled,
  required bool isCurrent,
  Key testKey = _enabledKey,
  VoidCallback? onTap,
}) {
  return RecentProjectItem(
    name: 'book_overview_app',
    summary: '237 節點 · 2419 票',
    enabled: enabled,
    isCurrent: isCurrent,
    reason: enabled ? null : '無法使用：逾時',
    onTap: onTap ?? () {},
    testKey: testKey,
    isDegraded: true,
  );
}

const _degradedStates = <String, (bool, bool)>{
  'enabled': (true, false),
  'selected': (true, true),
  'disabled': (false, false),
};

void main() {
  group('isDegraded 降級徽章（SPEC-004 4.9 S-34）', () {
    for (final entry in _degradedStates.entries) {
      final (enabled, isCurrent) = entry.value;

      testWidgets('${entry.key} + isDegraded 渲染 Badge.tag「內建型別表」', (
        tester,
      ) async {
        await pumpHarness(
          tester,
          child: SizedBox(
            width: LayoutSize.overlayWidth,
            child: _degraded(enabled: enabled, isCurrent: isCurrent),
          ),
        );

        final badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.variant, BadgeVariant.tag);
        expect(badge.label, _degradedZh);
      });

      for (final size in WindowSize.values) {
        testWidgets('${entry.key} + isDegraded @ ${size.label} 不溢位', (
          tester,
        ) async {
          await pumpHarness(
            tester,
            size: size,
            child: SizedBox(
              width: LayoutSize.overlayWidth,
              child: _degraded(enabled: enabled, isCurrent: isCurrent),
            ),
          );

          expectNoOverflow(tester);
        });
      }
    }

    testWidgets('未傳 isDegraded 不渲染 Badge.tag', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(width: LayoutSize.overlayWidth, child: _enabled()),
      );

      expect(find.byType(Badge), findsNothing);
      expect(find.text(_degradedZh), findsNothing);
    });

    testWidgets('isDegraded: false 不渲染 Badge.tag', (tester) async {
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
            testKey: _enabledKey,
            isDegraded: false,
          ),
        ),
      );

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('徽章與摘要同一列、位於摘要之後', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _degraded(enabled: true, isCurrent: false),
        ),
      );

      final summaryRect = tester.getRect(find.text('237 節點 · 2419 票'));
      final badgeRect = tester.getRect(find.byType(Badge));
      expect(badgeRect.left, greaterThanOrEqualTo(summaryRect.right));
      expect(badgeRect.top, lessThan(summaryRect.bottom));
      expect(badgeRect.bottom, greaterThan(summaryRect.top));
    });

    testWidgets('enabled + isDegraded 點選呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _degraded(
            enabled: true,
            isCurrent: false,
            onTap: () => callCount++,
          ),
        ),
      );

      await tester.tap(find.byKey(_enabledKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('disabled + isDegraded 點選不呼叫 onTap', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _degraded(
            enabled: false,
            isCurrent: false,
            testKey: _disabledKey,
            onTap: () => callCount++,
          ),
        ),
      );

      await tester.tap(find.byKey(_disabledKey), warnIfMissed: false);
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('isDegraded 不改變 Semantics.selected / enabled', (tester) async {
      await pumpHarness(
        tester,
        child: _degraded(enabled: true, isCurrent: true, testKey: _selectedKey),
      );

      final selected = tester.getSemantics(find.byKey(_selectedKey));
      expect(selected.flagsCollection.isSelected.toString(), contains('True'));
      expect(selected.flagsCollection.isEnabled.toString(), contains('True'));
    });

    testWidgets('disabled + isDegraded 的 Semantics.enabled 為 false', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: _degraded(
          enabled: false,
          isCurrent: false,
          testKey: _disabledKey,
        ),
      );

      final disabled = tester.getSemantics(find.byKey(_disabledKey));
      expect(disabled.flagsCollection.isEnabled.toString(), contains('False'));
      expect(
        disabled.flagsCollection.isSelected.toString(),
        isNot(contains('True')),
      );
    });

    testWidgets('en 語系「Built-in schema」不溢位', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _degraded(enabled: true, isCurrent: false),
        ),
      );

      expect(find.text(_degradedEn), findsOneWidget);
      expectNoOverflow(tester);
    });

    for (final locale in const [Locale('zh'), Locale('en')]) {
      testWidgets('最小寬下 ${locale.languageCode} 降級標籤截斷不溢位、摘要先截斷', (
        tester,
      ) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: SizedBox(
            width: _minItemWidth,
            child: _degraded(enabled: true, isCurrent: false),
          ),
        );

        expectNoOverflow(tester);
      });
    }

    testWidgets('寬度不足時摘要先截斷、徽章維持固有寬度', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: _degraded(enabled: true, isCurrent: false),
        ),
      );
      final intrinsicBadgeWidth = tester.getSize(find.byType(Badge)).width;

      await pumpHarness(
        tester,
        child: SizedBox(
          width: LayoutSize.overlayWidth,
          child: RecentProjectItem(
            name: 'book_overview_app',
            summary: TestCopy.longEn,
            enabled: true,
            isCurrent: false,
            onTap: () {},
            testKey: _enabledKey,
            isDegraded: true,
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(tester.getSize(find.byType(Badge)).width, intrinsicBadgeWidth);
    });
  });

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

    testWidgets('selected 點選仍呼叫 onTap（SPEC-003 §3.7 視同選取）', (tester) async {
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
      await pumpHarness(tester, child: _disabled(reason: '無法使用：逾時'));

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
