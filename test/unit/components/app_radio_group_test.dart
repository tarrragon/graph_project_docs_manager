/// AppRadioGroup 元件測試（SPEC-004 4.47）。
library;

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_radio_group.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const groupKey = ValueKey('card-nodeDetail-field-category');
  const prefix = 'option-nodeDetail-field-category-';

  List<RadioOption> options(int n, {String Function(int)? label}) => [
    for (var i = 0; i < n; i++)
      RadioOption(value: 'v$i', label: label?.call(i) ?? 'Option $i'),
  ];

  Widget build({
    int n = 2,
    String? selected,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    bool locked = false,
    String Function(int)? label,
  }) {
    return AppRadioGroup(
      options: options(n, label: label),
      selected: selected,
      onChanged: onChanged ?? (_) {},
      semanticLabel: 'Category',
      enabled: enabled,
      locked: locked,
      testKey: groupKey,
    );
  }

  Finder option(int i) => find.byKey(
    ValueKey(
      '$prefix'
      'v$i',
    ),
  );

  testWidgetsAtEachSize('none/set/outOfDomain/locked/disabled，2 與 12 項不溢位', (
    tester,
    size,
  ) async {
    for (final n in [2, 12]) {
      for (final selected in <String?>[null, 'v1', 'unknown']) {
        await pumpHarness(
          tester,
          size: size,
          child: SingleChildScrollView(
            child: build(n: n, selected: selected),
          ),
        );
        expectNoOverflow(tester);
      }
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: build(n: n, selected: 'v1', locked: true),
        ),
      );
      expectNoOverflow(tester);
      await pumpHarness(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: build(n: n, selected: 'v1', enabled: false),
        ),
      );
      expectNoOverflow(tester);
    }
  });

  testWidgetsAtEachSize('選項高等於 hitTargetMin，選項間距 Space.xxs', (
    tester,
    size,
  ) async {
    await pumpHarness(tester, size: size, child: build(n: 3));
    expect(tester.getSize(option(0)).height, LayoutSize.hitTargetMin);
    final gap =
        tester.getTopLeft(option(1)).dy - tester.getBottomLeft(option(0)).dy;
    expect(gap, Space.xxs);
  });

  testWidgetsAtEachSize('none 與 outOfDomain 全部未選，set 只選目標', (
    tester,
    size,
  ) async {
    for (final selected in <String?>[null, 'unknown']) {
      await pumpHarness(
        tester,
        size: size,
        child: build(selected: selected),
      );
      final handle = tester.ensureSemantics();
      for (var i = 0; i < 2; i++) {
        final d = tester.getSemantics(option(i)).getSemanticsData();
        expect(d.flagsCollection.isChecked, CheckedState.isFalse);
      }
      handle.dispose();
    }
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v1'),
    );
    final handle = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(option(1))
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
    expect(
      tester
          .getSemantics(option(0))
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isFalse,
    );
    handle.dispose();
  });

  testWidgetsAtEachSize('最長文案截斷不溢位', (tester, size) async {
    await pumpHarness(
      tester,
      size: size,
      child: SizedBox(
        width: 200,
        child: build(label: (_) => TestCopy.longToken),
      ),
    );
    expectNoOverflow(tester);
  });

  testWidgetsAtEachSize('點非選中項呼叫一次且標示不移動；點選中項不呼叫', (tester, size) async {
    final calls = <String>[];
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v0', onChanged: calls.add),
    );
    await tester.tap(option(1));
    await tester.pump();
    expect(calls, ['v1']);
    final handle = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(option(0))
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
    handle.dispose();
    await tester.tap(option(0));
    expect(calls, ['v1']);
  });

  testWidgetsAtEachSize('上下鍵只移動焦點不呼叫，Space 呼叫一次', (tester, size) async {
    final calls = <String>[];
    await pumpHarness(
      tester,
      size: size,
      child: build(n: 3, selected: 'v0', onChanged: calls.add),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(calls, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, ['v1']);
  });

  testWidgetsAtEachSize('全組一個 Tab 停留點，進入時焦點在選中項', (tester, size) async {
    await pumpHarness(
      tester,
      size: size,
      child: Column(children: [build(n: 3, selected: 'v2')]),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus!;
    final box = tester.getRect(option(2));
    expect(box.contains(focused.rect.center), isTrue);
  });

  testWidgetsAtEachSize('locked：不呼叫 onChanged、保留焦點、標示維持原值', (
    tester,
    size,
  ) async {
    final calls = <String>[];
    final locked = ValueNotifier(false);
    await pumpHarness(
      tester,
      size: size,
      child: ValueListenableBuilder<bool>(
        valueListenable: locked,
        builder: (_, v, _) =>
            build(n: 3, selected: 'v0', locked: v, onChanged: calls.add),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final held = FocusManager.instance.primaryFocus;
    expect(held?.debugLabel, 'AppRadioGroup.option1');
    locked.value = true;
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(held));
    await tester.tap(option(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgetsAtEachSize('disabled：點選不呼叫且不可聚焦；對照 enabled 可聚焦', (
    tester,
    size,
  ) async {
    final calls = <String>[];
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v0', enabled: false, onChanged: calls.add),
    );
    await tester.tap(option(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(calls, isEmpty);
    final focusedDisabled = FocusManager.instance.primaryFocus;
    expect(focusedDisabled?.debugLabel ?? '', isNot(contains('AppRadioGroup')));
    expect(groupFinder(), findsOneWidget);
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v0', onChanged: calls.add),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel ?? '',
      contains('AppRadioGroup'),
    );
  });

  testWidgetsAtEachSize('Semantics：群組 label、inMutuallyExclusiveGroup', (
    tester,
    size,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v1'),
    );
    final d = tester.getSemantics(option(1)).getSemanticsData();
    expect(d.label, contains('Option 1'));
    expect(d.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(find.bySemanticsLabel('Category'), findsWidgets);
    handle.dispose();
  });

  testWidgetsAtEachSize('錨點：選項由元件推導 option-...-<value>', (tester, size) async {
    await pumpHarness(tester, size: size, child: build(n: 2));
    expect(option(0), findsOneWidget);
    expect(option(1), findsOneWidget);
  });

  testWidgets('下限 2 項以 assert 擋', (tester) async {
    await pumpHarness(tester, child: build(n: 1));
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgetsAtEachSize('顏色引用 token', (tester, size) async {
    await pumpHarness(
      tester,
      size: size,
      child: build(selected: 'v0'),
    );
    final radio = tester.widget<Radio<String>>(
      find.byType(Radio<String>).first,
    );
    expect(radio.activeColor, AppColors.accent);
  });
}

Finder groupFinder() => find.byType(AppRadioGroup);
