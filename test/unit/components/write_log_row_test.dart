/// WriteLogRow 元件測試（SPEC-004 4.51、5.19）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/app_button.dart';
import 'package:graph_project_docs_manager/components/badge.dart' as ui;
import 'package:graph_project_docs_manager/components/field_block.dart';
import 'package:graph_project_docs_manager/components/write_log_row.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _catFile = 'git cat-file -p 3f2a9c1 > docs/a.md';
const _checkout = 'git checkout HEAD -- docs/a.md';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  const panelWidth = 238.0; // 5.19 父格位寬 = 262 − 2 × Space.md
  const minWidth = 56.0; // 5.19 容器最小寬（實機字型 ≤ 56、Ahem 56）

  WriteLogRow row({
    int index = 0,
    FieldWriteState? state,
    String path = 'docs/a.md',
    String? restoreCommand,
    VoidCallback? onPathTap,
  }) {
    final s = state ?? const FieldWriteState.writing();
    return WriteLogRow(
      index: index,
      path: path,
      fieldKey: 'title',
      projectName: 'demo',
      writeState: s,
      restoreCommand: s.isWritten ? (restoreCommand ?? _catFile) : null,
      onPathTap: onPathTap,
      testKey: ValueKey('card-writeLog-row-$index'),
    );
  }

  Future<void> pumpRow(
    WidgetTester tester,
    List<Widget> rows, {
    double width = panelWidth,
    WindowSize size = WindowSize.min,
  }) => pumpHarness(
    tester,
    size: size,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: Column(children: rows)),
      ),
    ),
  );

  Finder inRow(int i, Finder f) => find.descendant(
    of: find.byKey(ValueKey('card-writeLog-row-$i')),
    matching: f,
  );

  const written = FieldWriteState.written;

  group('子件渲染條件', () {
    testWidgetsAtEachSize('寫入中、written×驗證四態、blocked 三原因、ioFailed 各一列', (
      tester,
      size,
    ) async {
      final states = <FieldWriteState>[
        const FieldWriteState.writing(),
        written(validation: FieldValidation.running),
        written(validation: FieldValidation.passed),
        written(validation: FieldValidation.failed, newIssueCount: 2),
        written(
          validation: FieldValidation.unavailable,
          unavailableReason: FieldValidationUnavailableReason.timedOut,
        ),
        const FieldWriteState.blocked(FieldBlockedReason.externallyModified),
        const FieldWriteState.blocked(FieldBlockedReason.snapshotFailed),
        const FieldWriteState.blocked(FieldBlockedReason.rewriteNotIsolated),
        const FieldWriteState.ioFailed(),
      ];
      await pumpRow(tester, [
        for (var i = 0; i < states.length; i++) row(index: i, state: states[i]),
      ], size: size);
      expect(find.byType(WriteLogRow), findsNWidgets(states.length));
      expect(inRow(0, find.text(zh.fieldWriteInProgress)), findsOneWidget);
      expect(inRow(1, find.text(zh.validationRunning)), findsOneWidget);
      expect(inRow(2, find.text(zh.validationPassed)), findsOneWidget);
      expect(inRow(3, find.text(zh.validationFailed(2))), findsOneWidget);
      expect(inRow(4, find.text(zh.validationUnavailable)), findsOneWidget);
      expect(
        inRow(4, find.text(zh.validationUnavailableTimedOut)),
        findsOneWidget,
      );
      expect(inRow(5, find.text(zh.writeResultBlocked)), findsOneWidget);
      expect(
        inRow(5, find.text(zh.writeResultExternallyModified)),
        findsOneWidget,
      );
      expect(
        inRow(6, find.text(zh.fieldBlockedSnapshotFailed)),
        findsOneWidget,
      );
      expect(
        inRow(7, find.text(zh.fieldBlockedRewriteNotIsolated)),
        findsOneWidget,
      );
      expect(inRow(8, find.text(zh.writeResultIoFailed)), findsOneWidget);
      expect(inRow(8, find.text(zh.fieldIoFailed)), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('written 有快照：cat-file 指令與期限說明；無快照：checkout、無期限說明', (
      tester,
    ) async {
      await pumpRow(tester, [
        row(
          index: 0,
          state: written(validation: FieldValidation.passed, hasSnapshot: true),
        ),
        row(
          index: 1,
          state: written(validation: FieldValidation.passed),
          restoreCommand: _checkout,
        ),
      ]);
      expect(inRow(0, find.text(_catFile)), findsOneWidget);
      expect(
        inRow(0, find.text(zh.writeLogSnapshotExpiryNote)),
        findsOneWidget,
      );
      expect(inRow(0, find.text(zh.writeLogColumnRestore)), findsOneWidget);
      expect(inRow(1, find.text(_checkout)), findsOneWidget);
      expect(inRow(1, find.text(zh.writeLogSnapshotExpiryNote)), findsNothing);
    });

    testWidgets('非 written 列無取回說明、無驗證徽章、無期限說明', (tester) async {
      await pumpRow(tester, [
        row(index: 0),
        row(index: 1, state: const FieldWriteState.ioFailed()),
        row(
          index: 2,
          state: const FieldWriteState.blocked(
            FieldBlockedReason.snapshotFailed,
          ),
        ),
      ]);
      for (var i = 0; i < 3; i++) {
        expect(
          inRow(i, find.byKey(WriteLogRow.restoreHeadingKey)),
          findsNothing,
        );
        expect(
          inRow(i, find.byKey(WriteLogRow.validationBadgeKey)),
          findsNothing,
        );
        expect(inRow(i, find.byKey(WriteLogRow.expiryNoteKey)), findsNothing);
        expect(inRow(i, find.text(zh.writeLogColumnRestore)), findsNothing);
      }
    });

    testWidgets('所屬專案以 writeLogProjectLabel 代入', (tester) async {
      await pumpRow(tester, [row()]);
      expect(find.text(zh.writeLogProjectLabel('demo')), findsOneWidget);
    });

    testWidgets('寫入結果 tone：written positive、blocked／ioFailed negative', (
      tester,
    ) async {
      await pumpRow(tester, [
        row(index: 0, state: written(validation: FieldValidation.passed)),
        row(index: 1, state: const FieldWriteState.ioFailed()),
      ]);
      ui.Badge badge(int i) => tester.widget<ui.Badge>(
        inRow(i, find.byKey(WriteLogRow.resultBadgeKey)),
      );
      expect(badge(0).tone, ui.BadgeTone.positive);
      expect(badge(1).tone, ui.BadgeTone.negative);
    });
  });

  group('驗證不可用原因 baselineNotReady', () {
    for (final (reason, text) in [
      (
        FieldValidationUnavailableReason.baselineNotReady,
        zh.validationUnavailableBaselineNotReady,
      ),
      (
        FieldValidationUnavailableReason.unexpectedExitCode,
        zh.validationUnavailableUnexpectedExitCode,
      ),
    ]) {
      testWidgets('原因 ${reason.name} 顯示對應文案', (tester) async {
        await pumpRow(tester, [
          row(
            state: written(
              validation: FieldValidation.unavailable,
              unavailableReason: reason,
            ),
          ),
        ]);
        expect(find.text(text), findsOneWidget);
      });
    }
  });

  group('5.19 排列不變式', () {
    for (final width in [minWidth, panelWidth]) {
      testWidgetsAtEachSize('寬 $width：最長文案不溢位、容器寬為父格位寬', (tester, size) async {
        await pumpRow(
          tester,
          [
            row(
              state: written(
                validation: FieldValidation.unavailable,
                unavailableReason: FieldValidationUnavailableReason.timedOut,
                hasSnapshot: true,
              ),
              path: TestCopy.filePath,
              restoreCommand: 'git cat-file -p 3f2a9c1 > ${TestCopy.filePath}',
            ),
            row(
              index: 1,
              state: const FieldWriteState.blocked(
                FieldBlockedReason.rewriteNotIsolated,
              ),
            ),
          ],
          width: width,
          size: size,
        );
        expectNoOverflow(tester);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('card-writeLog-row-0')))
              .width,
          width,
        );
      });
    }

    testWidgets('行間 Space.xs：專案行緊接路徑行下方', (tester) async {
      await pumpRow(tester, [row()]);
      final project = tester.getRect(
        find.text(zh.writeLogProjectLabel('demo')),
      );
      final path = tester.getRect(find.text('docs/a.md'));
      expect(project.top - path.bottom, greaterThanOrEqualTo(Space.xs));
    });

    testWidgets('路徑與欄位名同一行：水平互斥、路徑在前', (tester) async {
      await pumpRow(tester, [row()]);
      final path = tester.getRect(find.text('docs/a.md'));
      final field = tester.getRect(find.text('title'));
      expect(path.right + Space.sm, lessThanOrEqualTo(field.left));
      expect((path.center.dy - field.center.dy).abs(), lessThan(2));
    });
  });

  group('路徑開頭截斷（4.51 內容政策）', () {
    const deepPath =
        'docs/spec/some-very-deep-directory/another-dir/SPEC-004.md';

    String pathText(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('card-writeLog-row-0')),
          matching: find.byType(Text),
        ),
      );
      return texts
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains('…') || s.contains('/'));
    }

    testWidgets('窄寬：TestCopy.filePath 以省略號開頭、以檔名尾段結尾', (tester) async {
      await pumpRow(tester, [row(path: TestCopy.filePath)], width: panelWidth);
      final shown = pathText(tester);
      expect(shown.startsWith('…'), isTrue);
      expect(shown.endsWith('contract.md'), isTrue);
      expectNoOverflow(tester);
    });

    testWidgets('窄寬：目錄深、檔名短時檔名完整保留', (tester) async {
      await pumpRow(tester, [row(path: deepPath)], width: panelWidth);
      final shown = pathText(tester);
      expect(shown.startsWith('…'), isTrue);
      expect(shown.endsWith('SPEC-004.md'), isTrue);
    });

    testWidgets('寬度足夠時不截斷', (tester) async {
      await pumpRow(tester, [row(path: 'docs/a.md')], width: panelWidth);
      expect(find.text('docs/a.md'), findsOneWidget);
    });

    testWidgets('朗讀 label 含完整路徑', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, [row(path: TestCopy.filePath)], width: panelWidth);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(TestCopy.filePath))),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('路徑點擊', () {
    testWidgets('onPathTap 為 null：無 action-writeLog-goto-node-<index>', (
      tester,
    ) async {
      await pumpRow(tester, [row()]);
      expect(find.byKey(WriteLogRow.pathButtonKey(0)), findsNothing);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('onPathTap 非 null：點擊呼叫恰一次，整列無其他點擊手勢', (tester) async {
      var taps = 0;
      await pumpRow(tester, [row(onPathTap: () => taps++)]);
      expect(find.byKey(WriteLogRow.pathButtonKey(0)), findsOneWidget);
      await tester.tap(find.byKey(WriteLogRow.pathButtonKey(0)));
      await tester.pump();
      expect(taps, 1);
      // 點整列其他區域（專案行）不觸發。
      await tester.tap(find.text(zh.writeLogProjectLabel('demo')));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('取回說明', () {
    testWidgets('可選取，內容等於 restoreCommand', (tester) async {
      await pumpRow(tester, [
        row(
          state: written(validation: FieldValidation.passed, hasSnapshot: true),
        ),
      ]);
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.data ?? selectable.textSpan?.toPlainText(), _catFile);
    });
  });

  group('無障礙', () {
    testWidgets('列朗讀為 writeLogRowA11yLabel；非 written 省略驗證段', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, [
        row(index: 0, state: written(validation: FieldValidation.passed)),
        row(index: 1, state: const FieldWriteState.ioFailed()),
      ]);
      expect(
        find.bySemanticsLabel(
          zh.writeLogRowA11yLabel(
            zh.writeLogColumnPath,
            'docs/a.md',
            zh.writeLogColumnField,
            'title',
            zh.writeLogColumnResult,
            zh.writeResultWritten,
            zh.writeLogColumnValidation,
            zh.validationPassed,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '${zh.writeLogColumnPath} docs/a.md，${zh.writeLogColumnField} title，'
          '${zh.writeLogColumnResult} ${zh.writeResultIoFailed}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
