/// ReferencePicker 元件測試（SPEC-004 4.46）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/reference_picker.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _testKey = ValueKey('action-nodeDetail-field-target_version');
const _filterKey = ValueKey('action-nodeDetail-field-target_version-filter');
const _menuKey = ValueKey('menu-nodeDetail-field-target_version');
const _emptyKey = ValueKey('option-nodeDetail-field-target_version-__empty__');

ValueKey<String> _optionKey(String v) =>
    ValueKey('option-nodeDetail-field-target_version-$v');

const _options = [
  ReferenceOption(value: '0.1.0', label: '0.1.0'),
  ReferenceOption(value: '0.2.0', label: '0.2.0'),
  ReferenceOption(value: '1.0.0', label: '1.0.0'),
];

Widget _picker({
  String? selected,
  ValueChanged<String?>? onChanged,
  bool enabled = true,
  bool locked = false,
  bool allowEmpty = false,
  List<ReferenceOption> options = _options,
}) => ReferencePicker(
  options: options,
  selected: selected,
  onChanged: onChanged ?? (_) {},
  semanticLabel: '目標版本',
  enabled: enabled,
  locked: locked,
  allowEmpty: allowEmpty,
  testKey: _testKey,
);

/// 同一實例就地換 props。
Future<ValueNotifier<Widget>> _pumpHost(
  WidgetTester tester,
  Widget first, {
  WindowSize size = WindowSize.min,
}) async {
  final host = ValueNotifier<Widget>(first);
  addTearDown(host.dispose);
  await pumpHarness(
    tester,
    size: size,
    child: Align(
      alignment: Alignment.topLeft,
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
    FocusManager.instance.primaryFocus?.debugLabel == 'ReferencePicker.trigger';

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_testKey));
  await tester.pumpAndSettle();
}

void main() {
  group('狀態矩陣', () {
    testWidgets('empty／set／outOfDomain 觸發器文字', (tester) async {
      final host = await _pumpHost(tester, _picker());
      expect(find.text('未填'), findsOneWidget);
      host.value = _picker(selected: '0.2.0');
      await tester.pumpAndSettle();
      expect(find.text('0.2.0'), findsOneWidget);
      host.value = _picker(selected: '9.9.9');
      await tester.pumpAndSettle();
      expect(find.text('9.9.9'), findsOneWidget);
      expect(find.text('未填'), findsNothing);
    });

    testWidgets('open：過濾框、選項、menu 存在', (tester) async {
      await _pumpHost(tester, _picker(selected: '0.1.0'));
      await _open(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      expect(find.byKey(_filterKey), findsOneWidget);
      expect(find.byKey(_optionKey('1.0.0')), findsOneWidget);
    });

    testWidgets('open 無符合項顯示 referencePickerNoMatch', (tester) async {
      await _pumpHost(tester, _picker());
      await _open(tester);
      await tester.enterText(find.byKey(_filterKey), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('沒有符合的項目'), findsOneWidget);
      expect(find.byKey(_optionKey('0.1.0')), findsNothing);
    });

    testWidgets('locked 與 disabled 不可展開', (tester) async {
      final host = await _pumpHost(tester, _picker(selected: '0.1.0'));
      host.value = _picker(selected: '0.1.0', locked: true);
      await tester.pumpAndSettle();
      await _open(tester);
      expect(find.byKey(_menuKey), findsNothing);
      host.value = _picker(selected: '0.1.0', enabled: false);
      await tester.pumpAndSettle();
      await _open(tester);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('朗讀 label 代入 semanticLabel 與目前值', (tester) async {
      final host = await _pumpHost(tester, _picker(selected: '0.2.0'));
      expect(tester.getSemantics(find.byKey(_testKey)).label, '目標版本，目前：0.2.0');
      host.value = _picker();
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(_testKey)).label, '目標版本，目前：未填');
    });
  });

  group('locked：焦點保留；對照 enabled false 焦點離開', () {
    testWidgets('選取後傳 locked：觸發器仍顯示原值、焦點在觸發器', (tester) async {
      final host = await _pumpHost(tester, _picker(selected: '0.1.0'));
      await _open(tester);
      await tester.tap(find.byKey(_optionKey('0.2.0')));
      await tester.pumpAndSettle();
      host.value = _picker(selected: '0.1.0', locked: true);
      await tester.pumpAndSettle();
      expect(find.text('0.1.0'), findsOneWidget);
      expect(_triggerHasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);

      host.value = _picker(selected: '0.1.0', enabled: false);
      await tester.pumpAndSettle();
      expect(_triggerHasFocus, isFalse);
    });
  });

  group('過濾', () {
    testWidgets('過濾後只剩符合項、順序不變；清空後恢復', (tester) async {
      await _pumpHost(tester, _picker());
      await _open(tester);
      await tester.enterText(find.byKey(_filterKey), '1');
      await tester.pumpAndSettle();
      expect(find.byKey(_optionKey('0.1.0')), findsOneWidget);
      expect(find.byKey(_optionKey('1.0.0')), findsOneWidget);
      expect(find.byKey(_optionKey('0.2.0')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(_optionKey('0.1.0'))).dy,
        lessThan(tester.getTopLeft(find.byKey(_optionKey('1.0.0'))).dy),
      );
      await tester.enterText(find.byKey(_filterKey), '');
      await tester.pumpAndSettle();
      expect(find.byKey(_optionKey('1.0.0')), findsOneWidget);
    });

    testWidgets('不分大小寫，且比對 label', (tester) async {
      await _pumpHost(
        tester,
        _picker(
          options: const [
            ReferenceOption(value: 'a-1', label: 'Alpha Domain'),
            ReferenceOption(value: 'b-1', label: 'Beta'),
          ],
        ),
      );
      await _open(tester);
      await tester.enterText(find.byKey(_filterKey), 'ALPHA');
      await tester.pumpAndSettle();
      expect(find.byKey(_optionKey('a-1')), findsOneWidget);
      expect(find.byKey(_optionKey('b-1')), findsNothing);
    });
  });

  group('選取與 onChanged', () {
    testWidgets('值改變呼叫恰一次；選目前值不呼叫', (tester) async {
      final calls = <String?>[];
      await _pumpHost(tester, _picker(selected: '0.1.0', onChanged: calls.add));
      await _open(tester);
      await tester.tap(find.byKey(_optionKey('0.1.0')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.byKey(_menuKey), findsNothing);
      await _open(tester);
      await tester.tap(find.byKey(_optionKey('1.0.0')));
      await tester.pumpAndSettle();
      expect(calls, ['1.0.0']);
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('allowEmpty true：首項存在，選取傳 null', (tester) async {
      final calls = <String?>[];
      await _pumpHost(
        tester,
        _picker(selected: '0.1.0', allowEmpty: true, onChanged: calls.add),
      );
      await _open(tester);
      expect(find.byKey(_emptyKey), findsOneWidget);
      await tester.tap(find.byKey(_emptyKey));
      await tester.pumpAndSettle();
      expect(calls, [null]);
    });

    testWidgets('allowEmpty false：首項不存在', (tester) async {
      await _pumpHost(tester, _picker(selected: '0.1.0'));
      await _open(tester);
      expect(find.byKey(_emptyKey), findsNothing);
    });

    testWidgets('allowEmpty true：不命中的過濾字串時首項仍在首列', (tester) async {
      await _pumpHost(tester, _picker(allowEmpty: true));
      await _open(tester);
      await tester.enterText(find.byKey(_filterKey), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(_emptyKey), findsOneWidget);
      expect(find.text('沒有符合的項目'), findsOneWidget);
      await tester.enterText(find.byKey(_filterKey), '1.0');
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(_emptyKey)).dy,
        lessThan(tester.getTopLeft(find.byKey(_optionKey('1.0.0'))).dy),
      );
    });
  });

  group('焦點與鍵盤', () {
    testWidgets('展開時焦點在過濾框；Esc 收合後焦點回觸發器', (tester) async {
      await _pumpHost(tester, _picker(selected: '0.1.0'));
      await _open(tester);
      final filterFocus = Focus.of(
        tester.element(find.byKey(_filterKey)),
        scopeOk: false,
      );
      expect(filterFocus.hasPrimaryFocus || filterFocus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      expect(_triggerHasFocus, isTrue);
    });

    testWidgets('↓ 走選項後 Enter 選取', (tester) async {
      final calls = <String?>[];
      await _pumpHost(tester, _picker(onChanged: calls.add));
      await _open(tester);
      // 高亮起點為第一列（無 selected），↓ 一次到第二列。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, ['0.2.0']);
    });

    testWidgets('點外部收合且不呼叫 onChanged', (tester) async {
      final calls = <String?>[];
      await _pumpHost(tester, _picker(onChanged: calls.add));
      await _open(tester);
      await tester.tapAt(const Offset(900, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      expect(calls, isEmpty);
    });
  });

  group('尺寸', () {
    for (final size in [WindowSize.min, WindowSize.design]) {
      testWidgets('20 筆選項不溢位、覆蓋層在視窗內（$size）', (tester) async {
        final many = [
          for (var i = 0; i < 20; i++)
            ReferenceOption(value: 'v$i', label: 'version-$i'),
        ];
        await _pumpHost(tester, _picker(options: many), size: size);
        await _open(tester);
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byKey(_menuKey));
        final view = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(view.height));
      });
    }

    testWidgets('最長測試文案截斷不溢位', (tester) async {
      await _pumpHost(
        tester,
        _picker(
          selected: 'x',
          options: [
            ReferenceOption(value: 'x', label: TestCopy.longToken),
            ReferenceOption(value: 'y', label: TestCopy.domainName),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      await _open(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('token', () {
    testWidgets('觸發器高為 hitTargetMin', (tester) async {
      await _pumpHost(tester, _picker());
      expect(
        tester.getSize(find.byKey(_testKey)).height,
        LayoutSize.hitTargetMin,
      );
    });
  });
}
