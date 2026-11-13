/// FieldBlock 元件測試（SPEC-004 4.48、5.17）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_text.dart';
import 'package:graph_project_docs_manager/components/field_block.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const blockKey = ValueKey('card-nodeDetail-field-title');
  const cellKey = ValueKey('test-value-cell');
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  /// 值格替身：可取得焦點，高度固定。
  Widget cell() => Focus(
    child: const SizedBox(key: cellKey, height: 32, width: double.infinity),
  );

  FieldBlock editable({
    FieldWriteState? writeState,
    bool isDirty = false,
    bool isMultiLine = false,
    bool requiredEmpty = false,
    String? outOfDomainValue,
    String? supportingText,
    bool isError = false,
    String label = 'title',
  }) => FieldBlock.editable(
    label: label,
    value: cell(),
    writeState: writeState,
    isDirty: isDirty,
    isMultiLine: isMultiLine,
    requiredEmpty: requiredEmpty,
    outOfDomainValue: outOfDomainValue,
    supportingText: supportingText,
    isError: isError,
    testKey: blockKey,
  );

  Future<void> pumpBlock(
    WidgetTester tester,
    Widget block, {
    WindowSize size = WindowSize.min,
    double? width,
  }) => pumpHarness(
    tester,
    size: size,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: block),
      ),
    ),
  );

  Finder hint() => find.descendant(
    of: find.byKey(blockKey),
    matching: find.byKey(FieldBlock.hintKey),
  );

  Text hintText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: hint(), matching: find.byType(Text)),
  );

  group('變體與提示格有無', () {
    testWidgetsAtEachSize('editable 無提示：不渲染提示格', (tester, size) async {
      await pumpBlock(tester, editable(), size: size);
      expect(hint(), findsNothing);
      expect(find.byKey(cellKey), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('readOnly：AppText 值 + fieldNotEditableHint', (
      tester,
      size,
    ) async {
      await pumpBlock(
        tester,
        FieldBlock.readOnly(
          label: 'id',
          value: const AppText.singleLine(
            TestCopy.nodeId,
            variant: AppTextVariant.mono,
          ),
          testKey: blockKey,
        ),
        size: size,
      );
      expect(hintText(tester).data, zh.fieldNotEditableHint);
      expect(find.text(TestCopy.nodeId), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('supportingText 為最低優先；isError 真時錯誤色，假時次要色', (tester) async {
      await pumpBlock(tester, editable(supportingText: 'note', isError: true));
      expect(hintText(tester).data, 'note');
      expect(hintText(tester).style!.color, AppColors.error);
      await pumpBlock(tester, editable(supportingText: 'note'));
      expect(hintText(tester).style!.color, AppColors.textSecondary);
    });
  });

  group('狀態矩陣：每列提示文字與 isError', () {
    String sep(String a, String b) => '$a${FieldBlock.hintSeparator}$b';
    final cases = <(String, FieldBlock Function(), String, bool)>[
      (
        '未送出（單行）',
        () => editable(isDirty: true),
        zh.fieldDraftUnsentHint,
        false,
      ),
      (
        '未送出（多行）',
        () => editable(isDirty: true, isMultiLine: true),
        zh.fieldDraftUnsentHintMultiLine,
        false,
      ),
      (
        '必填空白',
        () => editable(requiredEmpty: true),
        zh.fieldRequiredEmpty,
        true,
      ),
      (
        'writing',
        () => editable(writeState: const FieldWriteState.writing()),
        zh.fieldWriteInProgress,
        false,
      ),
      (
        'written 驗證中（無快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.running,
          ),
        ),
        zh.validationRunning,
        false,
      ),
      (
        'written 驗證中（有快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.running,
            hasSnapshot: true,
          ),
        ),
        sep(zh.validationRunning, zh.fieldSeeWriteLogHint),
        false,
      ),
      (
        'written 通過（無快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.passed,
          ),
        ),
        zh.validationPassed,
        false,
      ),
      (
        'written 通過（有快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.passed,
            hasSnapshot: true,
          ),
        ),
        sep(zh.validationPassed, zh.fieldSeeWriteLogHint),
        false,
      ),
      (
        'written 失敗（無快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.failed,
            newIssueCount: 3,
          ),
        ),
        zh.validationFailed(3),
        true,
      ),
      (
        'written 失敗（有快照）',
        () => editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.failed,
            newIssueCount: 3,
            hasSnapshot: true,
          ),
        ),
        sep(zh.validationFailed(3), zh.fieldSeeWriteLogHint),
        true,
      ),
      for (final (reason, text) in [
        (
          FieldValidationUnavailableReason.executableMissing,
          zh.validationUnavailableExecutableMissing,
        ),
        (
          FieldValidationUnavailableReason.unexpectedExitCode,
          zh.validationUnavailableUnexpectedExitCode,
        ),
        (
          FieldValidationUnavailableReason.unparsableOutput,
          zh.validationUnavailableUnparsableOutput,
        ),
        (
          FieldValidationUnavailableReason.timedOut,
          zh.validationUnavailableTimedOut,
        ),
        (
          FieldValidationUnavailableReason.baselineNotReady,
          zh.validationUnavailableBaselineNotReady,
        ),
      ]) ...[
        (
          'written 不可用 ${reason.name}（無快照）',
          () => editable(
            writeState: FieldWriteState.written(
              validation: FieldValidation.unavailable,
              unavailableReason: reason,
            ),
          ),
          sep(zh.validationUnavailable, text),
          false,
        ),
        (
          'written 不可用 ${reason.name}（有快照）',
          () => editable(
            writeState: FieldWriteState.written(
              validation: FieldValidation.unavailable,
              unavailableReason: reason,
              hasSnapshot: true,
            ),
          ),
          sep(sep(zh.validationUnavailable, text), zh.fieldSeeWriteLogHint),
          false,
        ),
      ],
      (
        '寫入失敗 snapshotFailed',
        () => editable(
          writeState: const FieldWriteState.blocked(
            FieldBlockedReason.snapshotFailed,
          ),
        ),
        zh.fieldBlockedSnapshotFailed,
        true,
      ),
      (
        '寫入失敗 rewriteNotIsolated',
        () => editable(
          writeState: const FieldWriteState.blocked(
            FieldBlockedReason.rewriteNotIsolated,
          ),
        ),
        zh.fieldBlockedRewriteNotIsolated,
        true,
      ),
      (
        '寫入失敗 ioFailed',
        () => editable(writeState: const FieldWriteState.ioFailed()),
        zh.fieldIoFailed,
        true,
      ),
      (
        'outOfDomain',
        () => editable(outOfDomainValue: 'x9'),
        zh.fieldValueOutOfDomain('x9'),
        false,
      ),
    ];

    for (final (name, build, expected, expectError) in cases) {
      testWidgetsAtEachSize(name, (tester, size) async {
        await pumpBlock(tester, build(), size: size);
        final text = hintText(tester);
        expect(text.data, expected);
        expect(
          text.style!.color,
          expectError ? AppColors.error : AppColors.textSecondary,
        );
        expectNoOverflow(tester);
      });
    }

    testWidgets('en 語系取 en 文案（plural 代入）', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: editable(
          writeState: const FieldWriteState.written(
            validation: FieldValidation.failed,
            newIssueCount: 1,
          ),
        ),
      );
      expect(hintText(tester).data, en.validationFailed(1));
    });
  });

  group('優先序 writing > 寫入失敗 > 必填空白 > 未送出 > written > outOfDomain', () {
    testWidgets('writing 與未送出同時成立 -> writing', (tester) async {
      await pumpBlock(
        tester,
        editable(
          writeState: const FieldWriteState.writing(),
          isDirty: true,
          requiredEmpty: true,
        ),
      );
      expect(hintText(tester).data, zh.fieldWriteInProgress);
    });

    testWidgets('寫入失敗與未送出同時成立 -> 寫入失敗', (tester) async {
      await pumpBlock(
        tester,
        editable(
          writeState: const FieldWriteState.ioFailed(),
          isDirty: true,
          requiredEmpty: true,
        ),
      );
      expect(hintText(tester).data, zh.fieldIoFailed);
    });

    testWidgets('必填空白與未送出同時成立 -> 必填空白（錯誤色）', (tester) async {
      await pumpBlock(tester, editable(isDirty: true, requiredEmpty: true));
      expect(hintText(tester).data, zh.fieldRequiredEmpty);
      expect(hintText(tester).style!.color, AppColors.error);
    });

    testWidgets('未送出 > written；written > outOfDomain', (tester) async {
      const written = FieldWriteState.written(
        validation: FieldValidation.passed,
      );
      await pumpBlock(tester, editable(writeState: written, isDirty: true));
      expect(hintText(tester).data, zh.fieldDraftUnsentHint);
      await pumpBlock(
        tester,
        editable(writeState: written, outOfDomainValue: 'x'),
      );
      expect(hintText(tester).data, zh.validationPassed);
    });
  });

  group('必填空白：值格不被本容器改動，送出後轉 writing', () {
    testWidgets('必填空白時值格仍在且未被包成錯誤態；改傳 writing 後提示格替換', (tester) async {
      final notifier = ValueNotifier<FieldBlock>(
        editable(requiredEmpty: true, isDirty: true),
      );
      addTearDown(notifier.dispose);
      await pumpHarness(
        tester,
        child: ValueListenableBuilder<FieldBlock>(
          valueListenable: notifier,
          builder: (_, block, _) => block,
        ),
      );
      expect(hintText(tester).data, zh.fieldRequiredEmpty);
      expect(find.byKey(cellKey), findsOneWidget);
      notifier.value = editable(
        writeState: const FieldWriteState.writing(),
        isDirty: true,
      );
      await tester.pump();
      expect(hintText(tester).data, zh.fieldWriteInProgress);
    });
  });

  group('blocked(externallyModified) 不在提示格顯示', () {
    testWidgets('externallyModified 提示格不渲染；對照 snapshotFailed 顯示', (
      tester,
    ) async {
      await pumpBlock(
        tester,
        editable(
          writeState: const FieldWriteState.blocked(
            FieldBlockedReason.externallyModified,
          ),
        ),
      );
      expect(hint(), findsNothing);
      await pumpBlock(
        tester,
        editable(
          writeState: const FieldWriteState.blocked(
            FieldBlockedReason.snapshotFailed,
          ),
        ),
      );
      expect(hintText(tester).data, zh.fieldBlockedSnapshotFailed);
    });

    testWidgets('externallyModified 時未送出草稿提示保留', (tester) async {
      await pumpBlock(
        tester,
        editable(
          writeState: const FieldWriteState.blocked(
            FieldBlockedReason.externallyModified,
          ),
          isDirty: true,
        ),
      );
      expect(hintText(tester).data, zh.fieldDraftUnsentHint);
    });
  });

  group('無障礙：liveRegion 與焦點', () {
    testWidgets('提示格節點 liveRegion 為 true；改變時焦點節點不變', (tester) async {
      final handle = tester.ensureSemantics();
      final notifier = ValueNotifier<FieldBlock>(editable(isDirty: true));
      addTearDown(notifier.dispose);
      await pumpInSemanticsContainer(
        tester,
        child: ValueListenableBuilder<FieldBlock>(
          valueListenable: notifier,
          builder: (_, block, _) => block,
        ),
      );
      final focusBefore = FocusManager.instance.primaryFocus;
      Focus.of(tester.element(find.byKey(cellKey))).requestFocus();
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      expect(focusBefore, isNot(same(focused)));

      SemanticsNode live() => tester.getSemantics(hint());
      expect(live().flagsCollection.isLiveRegion, isTrue);

      notifier.value = editable(writeState: const FieldWriteState.writing());
      await tester.pump();
      expect(live().flagsCollection.isLiveRegion, isTrue);
      expect(FocusManager.instance.primaryFocus, same(focused));
      handle.dispose();
    });

    testWidgets('值格語意含提示文字（hint 關聯）', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBlock(tester, editable(isDirty: true));
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(zh.fieldDraftUnsentHint))),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('5.17 排列不變式', () {
    /// 兩組代入值：實機字型（83 ≤ 476）與測試字型 Ahem（同值，5.17 表）。
    const minContainerWidth = 83.0; // 5.17 容器最小寬（最大值）
    const mainColumnWidth = 476.0; // 5.18 kMinWindowSize 主欄內寬

    for (final width in [minContainerWidth, mainColumnWidth]) {
      testWidgetsAtEachSize('寬 $width：最長文案不溢位、各子件交叉軸填滿', (tester, size) async {
        await pumpBlock(
          tester,
          editable(
            label: TestCopy.longZh,
            writeState: const FieldWriteState.blocked(
              FieldBlockedReason.rewriteNotIsolated,
            ),
          ),
          size: size,
          width: width,
        );
        expectNoOverflow(tester);
        expect(tester.getSize(find.byKey(blockKey)).width, width);
        expect(tester.getSize(find.byKey(cellKey)).width, width);
        expect(tester.getSize(hint()).width, width);
      });
    }

    testWidgets('三子件垂直互斥、間距 Space.xs、容器高為子件高加間距', (tester) async {
      await pumpBlock(tester, editable(isDirty: true), width: mainColumnWidth);
      final labelBox = tester.getRect(
        find.descendant(
          of: find.byKey(blockKey),
          matching: find.byKey(FieldBlock.labelKey),
        ),
      );
      final cellBox = tester.getRect(find.byKey(cellKey));
      final hintBox = tester.getRect(hint());
      expect(cellBox.top - labelBox.bottom, Space.xs);
      expect(hintBox.top - cellBox.bottom, Space.xs);
      final block = tester.getRect(find.byKey(blockKey));
      expect(block.height, hintBox.bottom - labelBox.top);
    });

    testWidgets('提示超過 3 行末行截斷', (tester) async {
      await pumpBlock(
        tester,
        editable(supportingText: List.filled(60, 'abcdefgh').join(' ')),
        width: 200,
      );
      final text = hintText(tester);
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('label 單行截斷', (tester) async {
      await pumpBlock(
        tester,
        editable(label: TestCopy.longEn),
        width: minContainerWidth,
      );
      expectNoOverflow(tester);
      final label = tester.widget<AppText>(
        find.descendant(
          of: find.byKey(blockKey),
          matching: find.byKey(FieldBlock.labelKey),
        ),
      );
      expect(label.maxLines, 1);
    });
  });

  group('token', () {
    testWidgets('提示格字級取 caption token', (tester) async {
      await pumpBlock(tester, editable(isDirty: true));
      expect(hintText(tester).style!.fontSize, isNotNull);
    });
  });
}
