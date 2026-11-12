/// FieldList 元件測試（SPEC-004 4.50、5.18）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const listKey = ValueKey('panel-nodeDetail-field-list');
  const bannerKey = ValueKey('panel-nodeDetail-edit-banner');
  const doneKey = ValueKey('action-nodeDetail-edit-done');
  const reloadKey = ValueKey('action-nodeDetail-edit-reload');
  final zh = lookupAppLocalizations(const Locale('zh'));

  FieldBlock textField(String name, {FieldWriteState? writeState}) =>
      FieldBlock.editable(
        label: name,
        writeState: writeState,
        testKey: ValueKey('card-nodeDetail-field-$name'),
        value: AppTextInput.singleLine(
          key: ValueKey('input-$name'),
          value: 'v-$name',
          onSubmitted: (_) {},
          semanticLabel: name,
          testKey: ValueKey('action-nodeDetail-field-$name'),
        ),
      );

  FieldBlock radioField(String name) => FieldBlock.editable(
    label: name,
    testKey: ValueKey('card-nodeDetail-field-$name'),
    value: AppRadioGroup(
      key: ValueKey('input-$name'),
      options: const [
        RadioOption(value: 'a', label: 'a'),
        RadioOption(value: 'b', label: 'b'),
      ],
      selected: 'a',
      onChanged: (_) {},
      semanticLabel: name,
      testKey: ValueKey('card-nodeDetail-radio-$name'),
    ),
  );

  FieldBlock readOnlyField(String name) => FieldBlock.readOnly(
    label: name,
    value: AppText.singleLine('ro-$name'),
    testKey: ValueKey('card-nodeDetail-field-$name'),
  );

  NoticeBanner banner(NoticeBannerVariant variant, String message) =>
      NoticeBanner(
        variant: variant,
        message: message,
        testKey: bannerKey,
        action: AppButton(
          label: zh.editDiscardAndReloadAction,
          onPressed: () {},
          testKey: reloadKey,
          variant: AppButtonVariant.secondary,
        ),
      );

  Widget list({
    NoticeBanner? bannerSlot,
    List<FieldBlock>? fields,
    bool writeInProgress = false,
    bool isBlocked = false,
    Future<FieldListReloadResult> Function()? onDiscardAndReload,
  }) => FieldList(
    banner: bannerSlot,
    fields: fields ?? [textField('title'), textField('status')],
    doneButton: AppButton(
      label: zh.editDoneAction,
      onPressed: () {},
      testKey: doneKey,
    ),
    writeInProgress: writeInProgress,
    isBlocked: isBlocked,
    onDiscardAndReload: onDiscardAndReload,
    testKey: listKey,
  );

  Future<void> pumpList(
    WidgetTester tester,
    Widget child, {
    WindowSize size = WindowSize.min,
    double width = 476,
  }) => pumpHarness(
    tester,
    size: size,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  );

  /// 同一實例就地換 props（pumpHarness 每次重建外殼，會重掛載 State）。
  Future<ValueNotifier<Widget>> pumpHost(
    WidgetTester tester,
    Widget first,
  ) async {
    final host = ValueNotifier<Widget>(first);
    addTearDown(host.dispose);
    await pumpList(
      tester,
      ValueListenableBuilder<Widget>(
        valueListenable: host,
        builder: (_, w, _) => w,
      ),
    );
    return host;
  }

  AppTextInput input(WidgetTester tester, String name) =>
      tester.widget<AppTextInput>(find.byKey(ValueKey('input-$name')));

  AppButton button(WidgetTester tester, Key key) => tester.widget<AppButton>(
    find.ancestor(of: find.byKey(key), matching: find.byType(AppButton)),
  );

  group('四態', () {
    testWidgets('editing：無橫幅、輸入可用、完成可用', (tester) async {
      await pumpList(tester, list());
      expect(find.byKey(bannerKey), findsNothing);
      expect(input(tester, 'title').locked, isFalse);
      expect(input(tester, 'title').enabled, isTrue);
      expect(button(tester, doneKey).enabled, isTrue);
    });

    testWidgets('writing：全部值格鎖定、完成與放棄並重讀 disabled', (tester) async {
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w'),
          fields: [textField('title'), radioField('status')],
          writeInProgress: true,
        ),
      );
      expect(input(tester, 'title').locked, isTrue);
      expect(
        tester
            .widget<AppRadioGroup>(find.byKey(const ValueKey('input-status')))
            .locked,
        isTrue,
      );
      final done = button(tester, doneKey);
      expect(done.enabled, isFalse);
      expect(done.reasonShownNearby, isTrue);
      expect(button(tester, reloadKey).enabled, isFalse);
    });

    testWidgets('warning：橫幅存在、欄位與動作皆可用', (tester) async {
      await pumpList(
        tester,
        list(bannerSlot: banner(NoticeBannerVariant.warning, 'w')),
      );
      expect(find.byKey(bannerKey), findsOneWidget);
      expect(input(tester, 'title').locked, isFalse);
      expect(button(tester, reloadKey).enabled, isTrue);
      expect(button(tester, doneKey).enabled, isTrue);
    });

    testWidgets('blocked：值格 disabled 且保留值，放棄並重讀與完成可用', (tester) async {
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.negative, 'n'),
          isBlocked: true,
        ),
      );
      expect(input(tester, 'title').enabled, isFalse);
      expect(input(tester, 'title').value, 'v-title');
      expect(button(tester, reloadKey).enabled, isTrue);
      expect(button(tester, doneKey).enabled, isTrue);
    });

    FieldBlock dropdownField() => FieldBlock.editable(
      label: 'dd',
      testKey: const ValueKey('card-nodeDetail-field-dd'),
      value: AppDropdown(
        key: const ValueKey('input-dd'),
        options: const [DropdownOption(value: 'a', label: 'a')],
        selected: 'a',
        onChanged: (_) {},
        semanticLabel: 'dd',
        locked: true,
        enabled: false,
        testKey: const ValueKey('action-nodeDetail-field-dd'),
      ),
    );

    FieldBlock pickerField() => FieldBlock.editable(
      label: 'rp',
      testKey: const ValueKey('card-nodeDetail-field-rp'),
      value: ReferencePicker(
        key: const ValueKey('input-rp'),
        options: const [ReferenceOption(value: 'a', label: 'a')],
        selected: 'a',
        onChanged: (_) {},
        semanticLabel: 'rp',
        allowEmpty: true,
        locked: true,
        enabled: false,
        testKey: const ValueKey('action-nodeDetail-field-rp'),
      ),
    );

    AppDropdown dd(WidgetTester t) =>
        t.widget<AppDropdown>(find.byKey(const ValueKey('input-dd')));
    ReferencePicker rp(WidgetTester t) =>
        t.widget<ReferencePicker>(find.byKey(const ValueKey('input-rp')));

    testWidgets('writing：AppDropdown 與 ReferencePicker 收到 locked', (
      tester,
    ) async {
      await pumpList(
        tester,
        list(fields: [dropdownField(), pickerField()], writeInProgress: true),
      );
      expect(dd(tester).locked, isTrue);
      expect(dd(tester).enabled, isTrue);
      expect(rp(tester).locked, isTrue);
      expect(rp(tester).enabled, isTrue);
      expect(rp(tester).allowEmpty, isTrue);
    });

    testWidgets('blocked：AppDropdown 與 ReferencePicker 收到 enabled false', (
      tester,
    ) async {
      await pumpList(
        tester,
        list(fields: [dropdownField(), pickerField()], isBlocked: true),
      );
      expect(dd(tester).enabled, isFalse);
      expect(dd(tester).locked, isFalse);
      expect(rp(tester).enabled, isFalse);
      expect(rp(tester).locked, isFalse);
    });

    testWidgets('editing：兩者覆寫呼叫端傳入值為 locked false／enabled true', (
      tester,
    ) async {
      await pumpList(tester, list(fields: [dropdownField(), pickerField()]));
      expect(dd(tester).locked, isFalse);
      expect(dd(tester).enabled, isTrue);
      expect(rp(tester).locked, isFalse);
      expect(rp(tester).enabled, isTrue);
    });

    testWidgets('呼叫端原本傳的 locked／enabled 被容器覆寫為下發值', (tester) async {
      final field = FieldBlock.editable(
        label: 'x',
        testKey: const ValueKey('card-nodeDetail-field-x'),
        value: AppTextInput.singleLine(
          key: const ValueKey('input-x'),
          value: 'v',
          onSubmitted: (_) {},
          semanticLabel: 'x',
          testKey: const ValueKey('action-nodeDetail-field-x'),
          locked: true,
          enabled: false,
        ),
      );
      await pumpList(tester, list(fields: [field]));
      expect(input(tester, 'x').locked, isFalse);
      expect(input(tester, 'x').enabled, isTrue);
    });

    testWidgets('寫入結果由各欄 FieldBlock 的提示格承載', (tester) async {
      await pumpList(
        tester,
        list(
          fields: [
            textField('title', writeState: const FieldWriteState.writing()),
          ],
          writeInProgress: true,
        ),
      );
      expect(find.text(zh.fieldWriteInProgress), findsOneWidget);
    });
  });

  group('排列', () {
    testWidgets('476 寬：欄位數 1 與多欄不溢位，且寬填滿', (tester) async {
      await pumpList(tester, list(fields: [textField('title')]));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(listKey)).width, 476);

      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w' * 80),
          fields: [
            for (final n in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) textField(n),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(listKey)).width, 476);
    });

    testWidgets('交叉軸最小寬 83 下不溢位（83 ≤ 476）', (tester) async {
      await pumpList(tester, list(), width: 83);
      expect(tester.takeException(), isNull);
    });

    testWidgets('垂直順序：橫幅、欄位依序、完成；間距為 Space.md', (tester) async {
      await pumpList(
        tester,
        list(bannerSlot: banner(NoticeBannerVariant.warning, 'w')),
      );
      final bannerRect = tester.getRect(find.byKey(bannerKey));
      final first = tester.getRect(
        find.byKey(const ValueKey('card-nodeDetail-field-title')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('card-nodeDetail-field-status')),
      );
      final done = tester.getRect(find.byKey(doneKey));
      expect(first.top - bannerRect.bottom, Space.md);
      expect(second.top - first.bottom, Space.md);
      expect(done.top - second.bottom, Space.md);
      expect(done.left, bannerRect.left);
    });
  });

  group('焦點', () {
    testWidgets('Tab 順序：放棄並重讀 → 可編輯值格 → 完成，唯讀值格不在序列', (tester) async {
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w'),
          fields: [
            textField('title'),
            readOnlyField('id'),
            textField('status'),
          ],
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final visited = <Key?>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        visited.add(_ownerKey(tester));
      }
      expect(visited, [
        reloadKey,
        const ValueKey('action-nodeDetail-field-title'),
        const ValueKey('action-nodeDetail-field-status'),
        doneKey,
      ]);
    });

    testWidgets('進入 editing 後焦點在第一個停留點（無橫幅時為第一個值格）', (tester) async {
      await pumpList(tester, list());
      await tester.pump();
      expect(
        _ownerKey(tester),
        const ValueKey('action-nodeDetail-field-title'),
      );
    });

    testWidgets('進入時有橫幅：第一個停留點為放棄並重讀', (tester) async {
      await pumpList(
        tester,
        list(bannerSlot: banner(NoticeBannerVariant.warning, 'w')),
      );
      await tester.pump();
      expect(_ownerKey(tester), reloadKey);
    });

    testWidgets('writing：送出中的欄位仍持有焦點，且寫入結果回來後焦點不變', (tester) async {
      final host = await pumpHost(tester, list());
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('action-nodeDetail-field-status')),
      );
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      host.value = list(writeInProgress: true);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(input(tester, 'status').locked, isTrue);
      host.value = list();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focused));
    });
  });

  group('放棄並重讀驅動橫幅', () {
    testWidgets('讀取期間動作鈕 disabled；成功後橫幅移除', (tester) async {
      final completer = Completer<FieldListReloadResult>();
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w'),
          onDiscardAndReload: () => completer.future,
        ),
      );
      await tester.tap(find.byKey(reloadKey));
      await tester.pump();
      expect(button(tester, reloadKey).enabled, isFalse);
      completer.complete(FieldListReloadResult.success);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(bannerKey), findsNothing);
    });

    testWidgets('失敗：訊息改 editBannerReloadFailed、變體 negative、動作恢復', (
      tester,
    ) async {
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w'),
          onDiscardAndReload: () async => FieldListReloadResult.failed,
        ),
      );
      await tester.tap(find.byKey(reloadKey));
      await tester.pump();
      await tester.pumpAndSettle();
      final shown = tester.widget<NoticeBanner>(
        find.ancestor(
          of: find.byKey(bannerKey),
          matching: find.byType(NoticeBanner),
        ),
      );
      expect(shown.message, zh.editBannerReloadFailed);
      expect(shown.variant, NoticeBannerVariant.negative);
      expect(button(tester, reloadKey).enabled, isTrue);
    });

    testWidgets('notFound：橫幅維持，動作恢復（畫面轉換由頁面層承載）', (tester) async {
      await pumpList(
        tester,
        list(
          bannerSlot: banner(NoticeBannerVariant.warning, 'w'),
          onDiscardAndReload: () async => FieldListReloadResult.notFound,
        ),
      );
      await tester.tap(find.byKey(reloadKey));
      await tester.pump();
      expect(find.byKey(bannerKey), findsOneWidget);
      expect(button(tester, reloadKey).enabled, isTrue);
    });
  });

  group('狀態變更提示', () {
    testWidgets('橫幅出現與消失為 cross-fade，期間新舊並存', (tester) async {
      final host = await pumpHost(tester, list());
      host.value = list(bannerSlot: banner(NoticeBannerVariant.warning, 'w'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byKey(const ValueKey('field-list-no-banner')),
        findsOneWidget,
      );
      expect(find.byKey(bannerKey), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('field-list-no-banner')), findsNothing);
      host.value = list();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(bannerKey), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(bannerKey), findsNothing);
    });
  });
}

/// 目前焦點所在的值格或按鈕錨點 key（向上找最近帶 key 的 testKey 祖先）。
Key? _ownerKey(WidgetTester tester) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  Key? found;
  context.visitAncestorElements((element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('action-')) {
      found = key;
      return false;
    }
    return true;
  });
  return found;
}
