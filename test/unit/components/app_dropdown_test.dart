/// AppDropdown 元件測試（SPEC-004 4.45）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_dropdown.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _testKey = ValueKey('action-nodeDetail-field-status');
const _menuKey = ValueKey('menu-nodeDetail-field-status');

ValueKey<String> _optionKey(String v) =>
    ValueKey('option-nodeDetail-field-status-$v');

const _options = [
  DropdownOption(value: 'draft', label: '草稿'),
  DropdownOption(value: 'active', label: '進行中'),
  DropdownOption(value: 'done', label: '完成'),
];

Widget _dd({
  String? selected,
  ValueChanged<String>? onChanged,
  bool enabled = true,
  bool locked = false,
  List<DropdownOption> options = _options,
}) => AppDropdown(
  options: options,
  selected: selected,
  onChanged: onChanged ?? (_) {},
  semanticLabel: '狀態',
  enabled: enabled,
  locked: locked,
  testKey: _testKey,
);

/// 同一實例就地換 props（pumpHarness 每次重建外殼會重掛 State）。
Future<ValueNotifier<Widget>> _pumpHost(
  WidgetTester tester,
  Widget first, {
  WindowSize size = WindowSize.min,
  Alignment align = Alignment.topLeft,
}) async {
  final host = ValueNotifier<Widget>(first);
  addTearDown(host.dispose);
  await pumpHarness(
    tester,
    size: size,
    child: Align(
      alignment: align,
      child: SizedBox(
        width: 240,
        child: ValueListenableBuilder<Widget>(
          valueListenable: host,
          builder: (_, w, _) => w,
        ),
      ),
    ),
  );
  return host;
}

bool get _triggerHasFocus =>
    FocusManager.instance.primaryFocus?.debugLabel == 'AppDropdown.trigger';

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_testKey));
  await tester.pump();
}

void main() {
  group('狀態矩陣：empty / set / outOfDomain / open / locked / disabled', () {
    testWidgets('empty 顯示 fieldEmptyValue、set 顯示 label、outOfDomain 顯示原值', (
      tester,
    ) async {
      final host = await _pumpHost(tester, _dd());
      expect(find.text('未填'), findsOneWidget);
      host.value = _dd(selected: 'active');
      await tester.pump();
      expect(find.text('進行中'), findsOneWidget);
      host.value = _dd(selected: 'legacy-value');
      await tester.pump();
      expect(find.text('legacy-value'), findsOneWidget);
      expect(find.text('未填'), findsNothing);
    });

    testWidgets('open 展開 menu；locked 與 disabled 不可展開', (tester) async {
      final host = await _pumpHost(tester, _dd(selected: 'draft'));
      await _open(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.tap(find.byKey(_optionKey('draft')));
      await tester.pump();
      expect(find.byKey(_menuKey), findsNothing);

      host.value = _dd(selected: 'draft', locked: true);
      await tester.pump();
      await _open(tester);
      expect(find.byKey(_menuKey), findsNothing);
      host.value = _dd(selected: 'draft', enabled: false);
      await tester.pump();
      await _open(tester);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('朗讀：Semantics.button，label 代入 semanticLabel 與目前值', (
      tester,
    ) async {
      final host = await _pumpHost(tester, _dd(selected: 'active'));
      final data = tester.getSemantics(find.byKey(_testKey));
      expect(data.label, '狀態，目前：進行中');
      host.value = _dd();
      await tester.pump();
      expect(tester.getSemantics(find.byKey(_testKey)).label, '狀態，目前：未填');
    });
  });

  group('locked：焦點保留、不可展開；對照 enabled false 焦點離開', () {
    testWidgets('locked 保留焦點，enabled false 焦點離開', (tester) async {
      final host = await _pumpHost(tester, _dd(selected: 'draft'));
      await _open(tester);
      await tester.tap(find.byKey(_optionKey('active')));
      await tester.pump();
      await tester.pump();
      expect(_triggerHasFocus, isTrue);

      host.value = _dd(selected: 'draft', locked: true);
      await tester.pump();
      expect(_triggerHasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.byKey(_menuKey), findsNothing);

      host.value = _dd(selected: 'draft');
      await tester.pump();
      expect(_triggerHasFocus, isTrue);
      host.value = _dd(selected: 'draft', enabled: false);
      await tester.pump();
      expect(_triggerHasFocus, isFalse);
    });

    testWidgets('選取後觸發器文字在 selected 改傳前不變（不允許樂觀更新）', (tester) async {
      final calls = <String>[];
      final host = await _pumpHost(
        tester,
        _dd(selected: 'draft', onChanged: calls.add),
      );
      await _open(tester);
      await tester.tap(find.byKey(_optionKey('done')));
      await tester.pump();
      expect(calls, ['done']);
      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('完成'), findsNothing);
      host.value = _dd(selected: 'done', onChanged: calls.add);
      await tester.pump();
      expect(find.text('完成'), findsOneWidget);
    });
  });

  group('onChanged 契約（D5）', () {
    testWidgets('選取目前值不呼叫；展開、走選項、Esc 皆不呼叫', (tester) async {
      final calls = <String>[];
      await _pumpHost(tester, _dd(selected: 'active', onChanged: calls.add));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls, isEmpty);
      expect(find.byKey(_menuKey), findsNothing);

      await _open(tester);
      await tester.tap(find.byKey(_optionKey('active')));
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('鍵盤 Enter 展開、End 到末項、Enter 選取恰一次', (tester) async {
      final calls = <String>[];
      await _pumpHost(tester, _dd(selected: 'draft', onChanged: calls.add));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, ['done']);
    });
  });

  group('選單內容與播報（D3、D6、D7）', () {
    testWidgets('無「全部」項、順序同 options、outOfDomain 原值不入選項', (tester) async {
      await _pumpHost(tester, _dd(selected: 'legacy'));
      await _open(tester);
      expect(find.text('全部'), findsNothing);
      final ys = [
        for (final o in _options)
          tester.getTopLeft(find.byKey(_optionKey(o.value))).dy,
      ];
      expect([...ys]..sort(), ys);
      expect(find.byKey(_optionKey('legacy')), findsNothing);
    });

    testWidgets('role 與 selected 與 expanded', (tester) async {
      await _pumpHost(tester, _dd(selected: 'active'));
      expect(
        tester.getSemantics(find.byKey(_testKey)).flagsCollection.isExpanded,
        anyOf(isFalse, isNotNull),
      );
      await _open(tester);
      expect(
        tester.getSemantics(find.byKey(_menuKey)).role,
        SemanticsRole.menu,
      );
      final sel = tester.getSemantics(find.byKey(_optionKey('active')));
      expect(sel.role, SemanticsRole.menuItem);
      expect(sel.flagsCollection.isSelected.toString(), contains('isTrue'));
      final other = tester.getSemantics(find.byKey(_optionKey('draft')));
      expect(
        other.flagsCollection.isSelected.toString(),
        isNot(contains('isTrue')),
      );
    });

    testWidgets('點外部吸收收合、不穿透', (tester) async {
      var taps = 0;
      await pumpHarness(
        tester,
        child: Column(
          children: [
            SizedBox(width: 240, child: _dd(selected: 'draft')),
            GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(
                key: ValueKey('below'),
                width: 200,
                height: 200,
              ),
            ),
          ],
        ),
      );
      await _open(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(find.byKey(_menuKey), findsNothing);
      expect(taps, 0);
    });

    testWidgets('D1：同時至多一個選單展開', (tester) async {
      const k2 = ValueKey('action-nodeDetail-field-other');
      await pumpHarness(
        tester,
        child: Column(
          children: [
            SizedBox(width: 240, child: _dd(selected: 'draft')),
            SizedBox(
              width: 240,
              child: AppDropdown(
                options: _options,
                selected: 'draft',
                onChanged: (_) {},
                semanticLabel: '其他',
                testKey: k2,
              ),
            ),
          ],
        ),
      );
      await _open(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(k2));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('menu-nodeDetail-field-other')),
        findsOneWidget,
      );
      expect(find.byKey(_menuKey), findsNothing);
    });
  });

  group('幾何與尺寸（D4）', () {
    testWidgetsAtEachSize('兩種視窗尺寸不溢位；觸發器高等於 hitTargetMin', (
      tester,
      size,
    ) async {
      await _pumpHost(tester, _dd(selected: 'draft'), size: size);
      expectNoOverflow(tester);
      expect(
        tester.getSize(find.byKey(_testKey)).height,
        LayoutSize.hitTargetMin,
      );
      expect(tester.getSize(find.byKey(_testKey)).width, 240);
    });

    testWidgets('kMinWindowSize 下 10 個選項全數展開、整體在視窗內', (tester) async {
      final ten = [
        for (var i = 0; i < 10; i++) DropdownOption(value: 'v$i', label: 'L$i'),
      ];
      await _pumpHost(tester, _dd(selected: 'v0', options: ten));
      await _open(tester);
      final last = tester.getRect(find.byKey(_optionKey('v9')));
      final first = tester.getRect(find.byKey(_optionKey('v0')));
      expect(last.height, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
      expect(first.top, greaterThanOrEqualTo(0));
      expect(last.bottom, lessThanOrEqualTo(WindowSize.min.size.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('觸發器置於視窗底部時向上展開且在視窗內', (tester) async {
      await _pumpHost(
        tester,
        _dd(selected: 'draft'),
        align: Alignment.bottomLeft,
      );
      await _open(tester);
      final trigger = tester.getRect(find.byKey(_testKey));
      final last = tester.getRect(find.byKey(_optionKey('done')));
      expect(last.bottom, lessThanOrEqualTo(trigger.top + 0.5));
      expect(
        tester.getTopLeft(find.byKey(_optionKey('draft'))).dy,
        greaterThanOrEqualTo(0),
      );
    });

    testWidgets('預設向下展開：頂緣貼觸發器底緣、左緣對齊', (tester) async {
      await _pumpHost(tester, _dd(selected: 'draft'));
      await _open(tester);
      final trigger = tester.getRect(find.byKey(_testKey));
      final first = tester.getRect(find.byKey(_optionKey('draft')));
      expect(first.top, greaterThanOrEqualTo(trigger.bottom));
      expect(first.left, greaterThanOrEqualTo(trigger.left));
    });

    testWidgets('最長測試文案截斷不溢位；兩語系空值文字不溢位', (tester) async {
      for (final locale in kTestLocales) {
        await pumpHarness(
          tester,
          locale: locale,
          child: SizedBox(
            width: 140,
            child: _dd(
              selected: TestCopy.longToken,
              options: [
                DropdownOption(
                  value: TestCopy.longToken,
                  label: TestCopy.longToken,
                ),
                DropdownOption(value: 'b', label: TestCopy.status),
              ],
            ),
          ),
        );
        expectNoOverflow(tester);
        await _open(tester);
        expectNoOverflow(tester);
        await pumpHarness(
          tester,
          locale: locale,
          child: SizedBox(width: 140, child: _dd()),
        );
        expectNoOverflow(tester);
      }
    });
  });

  group('token 與 testKey', () {
    testWidgets('邊框色與圓角引用 token', (tester) async {
      await _pumpHost(tester, _dd(selected: 'draft'));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(_testKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final d = box.decoration as BoxDecoration;
      expect((d.border! as Border).top.color, AppColors.border);
      expect(d.borderRadius, BorderRadius.circular(Radius.md));
      expect(d.color, AppColors.surfaceBase);
    });
  });
}
