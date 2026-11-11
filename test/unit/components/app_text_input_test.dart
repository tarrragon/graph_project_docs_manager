/// AppTextInput 元件測試（SPEC-004 4.44）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_text_input.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _testKey = ValueKey('action-nodeDetail-field-title');

Widget _single({
  String value = '',
  ValueChanged<String>? onSubmitted,
  bool enabled = true,
  bool locked = false,
  bool hasError = false,
  ValueChanged<bool>? onDirtyChanged,
}) => AppTextInput.singleLine(
  value: value,
  onSubmitted: onSubmitted ?? (_) {},
  semanticLabel: 'title',
  enabled: enabled,
  locked: locked,
  hasError: hasError,
  onDirtyChanged: onDirtyChanged,
  testKey: _testKey,
);

Widget _multi({
  String value = '',
  ValueChanged<String>? onSubmitted,
  bool enabled = true,
  bool locked = false,
  bool hasError = false,
  ValueChanged<bool>? onDirtyChanged,
}) => AppTextInput.multiLine(
  value: value,
  onSubmitted: onSubmitted ?? (_) {},
  semanticLabel: 'payload',
  enabled: enabled,
  locked: locked,
  hasError: hasError,
  onDirtyChanged: onDirtyChanged,
  testKey: _testKey,
);

Finder get _editable => find.descendant(
  of: find.byKey(_testKey),
  matching: find.byType(EditableText),
);

bool get _hasFocus =>
    tester0.widget<EditableText>(_editable).focusNode.hasFocus;

late WidgetTester tester0;

/// 同一元件實例就地換 props（pumpHarness 每次重建外殼，會重掛載 State）。
Future<ValueNotifier<Widget>> _pumpHost(
  WidgetTester tester,
  Widget first,
) async {
  tester0 = tester;
  final host = ValueNotifier<Widget>(first);
  addTearDown(host.dispose);
  await pumpHarness(
    tester,
    child: ValueListenableBuilder<Widget>(
      valueListenable: host,
      builder: (_, w, _) => w,
    ),
  );
  return host;
}

Color _borderColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(_testKey),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color;
}

Color _textColor(WidgetTester tester) =>
    tester.widget<EditableText>(_editable).style.color!;

void main() {
  group('狀態矩陣：兩變體 x idle / editing / locked / error / disabled', () {
    for (final variant in ['singleLine', 'multiLine']) {
      Widget build({
        bool enabled = true,
        bool locked = false,
        bool hasError = false,
      }) => variant == 'singleLine'
          ? _single(
              value: 'abc',
              enabled: enabled,
              locked: locked,
              hasError: hasError,
            )
          : _multi(
              value: 'abc',
              enabled: enabled,
              locked: locked,
              hasError: hasError,
            );

      testWidgetsAtEachSize('$variant 五態渲染且不溢位、框色與字色符合契約', (
        tester,
        size,
      ) async {
        tester0 = tester;
        await pumpHarness(tester, size: size, child: build());
        expectNoOverflow(tester);
        expect(_borderColor(tester), AppColors.border);
        expect(_textColor(tester), AppColors.textPrimary);

        await tester.tap(find.byKey(_testKey));
        await tester.pump();
        expect(_borderColor(tester), AppColors.accent);

        await pumpHarness(tester, size: size, child: build(hasError: true));
        expect(_borderColor(tester), AppColors.error);

        await pumpHarness(tester, size: size, child: build(locked: true));
        expect(_borderColor(tester), AppColors.border);
        expect(_textColor(tester), AppColors.textDisabled);

        await pumpHarness(tester, size: size, child: build(enabled: false));
        expect(_borderColor(tester), AppColors.border);
        expect(_textColor(tester), AppColors.textDisabled);
        expectNoOverflow(tester);
      });
    }

    testWidgets('error 與 editing 並存時框色 error 優先', (tester) async {
      tester0 = tester;
      await pumpHarness(tester, child: _single(value: 'a', hasError: true));
      await tester.tap(find.byKey(_testKey));
      await tester.pump();
      expect(_hasFocus, isTrue);
      expect(_borderColor(tester), AppColors.error);
    });
  });

  group('草稿與失焦', () {
    testWidgets('失焦保留草稿、不呼叫 onSubmitted，onDirtyChanged(true) 被呼叫', (
      tester,
    ) async {
      tester0 = tester;
      final submitted = <String>[];
      final dirty = <bool>[];
      await pumpHarness(
        tester,
        child: Column(
          children: [
            _single(
              value: 'old',
              onSubmitted: submitted.add,
              onDirtyChanged: dirty.add,
            ),
            const Focus(child: SizedBox(width: 10, height: 10)),
          ],
        ),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.pump();
      await tester.enterText(_editable, 'new');
      await tester.pump();
      expect(dirty, [true]);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(_hasFocus, isFalse);
      expect(find.text('new'), findsOneWidget);
      expect(submitted, isEmpty);
      expect(dirty, [true]);
    });

    testWidgets('對照：草稿等於 value 時失焦不呼叫 onDirtyChanged(true)', (tester) async {
      tester0 = tester;
      final dirty = <bool>[];
      await pumpHarness(
        tester,
        child: _single(value: 'same', onDirtyChanged: dirty.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.pump();
      await tester.enterText(_editable, 'same');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(dirty.contains(true), isFalse);
    });

    testWidgets('草稿改回與 value 相同時回報 onDirtyChanged(false)', (tester) async {
      tester0 = tester;
      final dirty = <bool>[];
      await pumpHarness(
        tester,
        child: _single(value: 'v', onDirtyChanged: dirty.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'x');
      await tester.pump();
      await tester.enterText(_editable, 'v');
      await tester.pump();
      expect(dirty, [true, false]);
    });

    testWidgets('value 更新（written）時未改草稿跟隨新值；有草稿則保留', (tester) async {
      tester0 = tester;
      final host = await _pumpHost(tester, _single(value: 'a'));
      host.value = _single(value: 'b');
      await tester.pump();
      expect(find.text('b'), findsOneWidget);

      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'draft');
      await tester.pump();
      host.value = _single(value: 'c');
      await tester.pump();
      expect(find.text('draft'), findsOneWidget);
    });
  });

  group('locked 與 disabled', () {
    testWidgets('locked：保留焦點、輸入字元不改變文字；對照 enabled false 焦點離開', (tester) async {
      tester0 = tester;
      final host = await _pumpHost(tester, _single(value: 'abc'));
      await tester.tap(find.byKey(_testKey));
      await tester.pump();
      expect(_hasFocus, isTrue);

      host.value = _single(value: 'abc', locked: true);
      await tester.pump();
      expect(_hasFocus, isTrue);
      await tester.enterText(_editable, 'zzz');
      await tester.pump();
      expect(find.text('abc'), findsOneWidget);
      expect(find.text('zzz'), findsNothing);

      host.value = _single(value: 'abc');
      await tester.pump();
      expect(_hasFocus, isTrue);
      host.value = _single(value: 'abc', enabled: false);
      await tester.pump();
      expect(_hasFocus, isFalse);
    });

    testWidgets('locked 時 Enter 不提交', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      final host = await _pumpHost(
        tester,
        _single(value: 'a', onSubmitted: submitted.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'b');
      host.value = _single(
        value: 'a',
        onSubmitted: submitted.add,
        locked: true,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, isEmpty);
    });
  });

  group('提交與還原', () {
    testWidgets('singleLine Enter 呼叫 onSubmitted 恰一次，焦點保留', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      await pumpHarness(
        tester,
        child: _single(value: 'a', onSubmitted: submitted.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'b');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, ['b']);
      expect(_hasFocus, isTrue);
    });

    testWidgets('草稿與 value 相同時 Enter 不呼叫', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      await pumpHarness(
        tester,
        child: _single(value: 'a', onSubmitted: submitted.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, isEmpty);
    });

    testWidgets('草稿 trim 後為空照常呼叫 onSubmitted 傳原草稿', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      await pumpHarness(
        tester,
        child: _single(value: 'a', onSubmitted: submitted.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, '   ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, ['   ']);
    });

    testWidgets('multiLine ⌘Enter 提交一次；Enter 不呼叫並保留換行', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      await pumpHarness(
        tester,
        child: _multi(value: 'a', onSubmitted: submitted.add),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'a\nb');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, isEmpty);
      expect(find.text('a\nb'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(submitted, ['a\nb']);
    });

    testWidgets('Esc 還原草稿為 value 且不呼叫 onSubmitted，焦點保留', (tester) async {
      tester0 = tester;
      final submitted = <String>[];
      final dirty = <bool>[];
      await pumpHarness(
        tester,
        child: _single(
          value: 'orig',
          onSubmitted: submitted.add,
          onDirtyChanged: dirty.add,
        ),
      );
      await tester.tap(find.byKey(_testKey));
      await tester.enterText(_editable, 'changed');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('orig'), findsOneWidget);
      expect(submitted, isEmpty);
      expect(dirty, [true, false]);
      expect(_hasFocus, isTrue);
    });
  });

  group('尺寸與內容政策', () {
    testWidgetsAtEachSize('singleLine 高等於 hitTargetMin，長 token 無溢位', (
      tester,
      size,
    ) async {
      tester0 = tester;
      await pumpHarness(
        tester,
        size: size,
        child: _single(value: TestCopy.longToken),
      );
      expectNoOverflow(tester);
      expect(
        tester.getSize(find.byKey(_testKey)).height,
        LayoutSize.hitTargetMin,
      );
    });

    testWidgetsAtEachSize('multiLine 高介於 3 行與 8 行之間，長文換行無溢位', (
      tester,
      size,
    ) async {
      tester0 = tester;
      await pumpHarness(
        tester,
        size: size,
        child: _multi(value: TestCopy.longZh),
      );
      expectNoOverflow(tester);
      const line = AppFontSize.body;
      final h = tester.getSize(find.byKey(_testKey)).height;
      expect(h, greaterThanOrEqualTo(3 * line + 2 * Space.xs));
      expect(h, lessThanOrEqualTo(8 * line + 2 * Space.xs + 1));

      final many = List.generate(20, (i) => 'line$i').join('\n');
      await pumpHarness(
        tester,
        size: size,
        child: _multi(value: many),
      );
      expectNoOverflow(tester);
      expect(
        tester.getSize(find.byKey(_testKey)).height,
        lessThanOrEqualTo(8 * line + 2 * Space.xs + 1),
      );
    });

    testWidgetsAtEachSize('zh / en placeholder 皆不溢位', (tester, size) async {
      tester0 = tester;
      for (final locale in kTestLocales) {
        await pumpHarness(tester, size: size, locale: locale, child: _single());
        expectNoOverflow(tester);
        expect(
          find.text(locale.languageCode == 'zh' ? '未填' : 'Not set'),
          findsOneWidget,
        );
      }
    });
  });

  group('語意', () {
    testWidgets('textField 語意帶 label 與 value；multiLine 帶 multiline', (
      tester,
    ) async {
      tester0 = tester;
      final handle = tester.ensureSemantics();
      await pumpHarness(tester, child: _multi(value: 'hi'));
      final node = tester.getSemantics(find.byKey(_testKey));
      expect(node.label, 'payload');
      expect(node.value, 'hi');
      expect(node.flagsCollection.isMultiline, isTrue);
      handle.dispose();
    });
  });
}
