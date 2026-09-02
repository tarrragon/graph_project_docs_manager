/// [TableColumnHeader] widget test（SPEC-004 §4.14「測試點」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 固定寬欄容器：欄首「填滿父格位」的尺寸契約需要有寬度可填滿
/// （SPEC-004 §4.14 尺寸契約），測試一律置於此寬度受限的欄位下斷言。
Widget _column(Widget child) => SizedBox(width: 100, child: child);

void main() {
  const sortKey = ValueKey('action-tickets-sort-title');

  group('三個變體 × sortable 三種 order 逐一渲染不溢位', () {
    testWidgetsAtEachSize('plain', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _column(const TableColumnHeader.plain(label: 'ID')),
      );
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('twoLine', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _column(
          const TableColumnHeader.twoLine(
            label: 'UC-01',
            secondLine: '節點瀏覽',
          ),
        ),
      );
      expectNoOverflow(tester);
    });

    for (final order in SortOrder.values) {
      testWidgetsAtEachSize('sortable / order=${order.name}', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          child: _column(
            TableColumnHeader.sortable(
              label: '標題',
              order: order,
              onSort: () {},
              testKey: sortKey,
            ),
          ),
        );
        expectNoOverflow(tester);
        expect(find.byKey(sortKey), findsOneWidget);
      });
    }
  });

  group('最長測試文案截斷（含第二行）', () {
    testWidgets('plain 最長文案截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.plain(label: TestCopy.longToken),
        ),
      );
      expectNoOverflow(tester);
      final textWidget = tester.widget<Text>(find.text(TestCopy.longToken));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('twoLine 第一行與第二行最長文案截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.twoLine(
            label: TestCopy.longToken,
            secondLine: TestCopy.ucName,
          ),
        ),
      );
      expectNoOverflow(tester);

      final secondLineWidget = tester.widget<Text>(
        find.text(TestCopy.ucName),
      );
      expect(secondLineWidget.maxLines, 1);
      expect(secondLineWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('sortable 最長文案截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: TestCopy.longToken,
            order: SortOrder.none,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );
      expectNoOverflow(tester);
      final textWidget = tester.widget<Text>(find.text(TestCopy.longToken));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('zh / en 七個 column* key 皆不溢位', () {
    const keys = [
      'columnId',
      'columnTitle',
      'columnStatus',
      'columnPriority',
      'columnStep',
      'columnDomain',
      'columnEvents',
    ];

    String labelFor(AppLocalizations l10n, String key) => switch (key) {
      'columnId' => l10n.columnId,
      'columnTitle' => l10n.columnTitle,
      'columnStatus' => l10n.columnStatus,
      'columnPriority' => l10n.columnPriority,
      'columnStep' => l10n.columnStep,
      'columnDomain' => l10n.columnDomain,
      'columnEvents' => l10n.columnEvents,
      _ => throw ArgumentError('未知 key: $key'),
    };

    for (final key in keys) {
      for (final locale in kTestLocales) {
        testWidgets('$key ${locale.languageCode} 不溢位', (tester) async {
          late String label;
          await pumpHarness(
            tester,
            locale: locale,
            child: Builder(
              builder: (context) {
                label = labelFor(AppLocalizations.of(context), key);
                return _column(TableColumnHeader.plain(label: label));
              },
            ),
          );
          expectNoOverflow(tester);
          expect(find.text(label), findsOneWidget);
        });
      }
    }
  });

  group('sortable 互動與無障礙播報', () {
    testWidgets('點選呼叫 onSort 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.none,
            onSort: () => callCount++,
            testKey: sortKey,
          ),
        ),
      );

      await tester.tap(find.byKey(sortKey));
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('鍵盤 Enter 觸發 onSort', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.none,
            onSort: () => callCount++,
            testKey: sortKey,
          ),
        ),
      );

      await tester.tap(find.byKey(sortKey));
      await tester.pump();
      callCount = 0; // 重置 tap 造成的計數，本測試只驗鍵盤路徑

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('鍵盤 Space 觸發 onSort', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.none,
            onSort: () => callCount++,
            testKey: sortKey,
          ),
        ),
      );

      await tester.tap(find.byKey(sortKey));
      await tester.pump();
      callCount = 0;

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('朗讀標籤含 order 值：none → sortNone', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.none,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );

      final data = tester.getSemantics(find.byKey(sortKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, contains('未排序'));
    });

    testWidgets('朗讀標籤含 order 值：asc → sortAscending', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.asc,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );

      final data = tester.getSemantics(find.byKey(sortKey));
      expect(data.label, contains('遞增'));
    });

    testWidgets('朗讀標籤含 order 值：desc → sortDescending', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.desc,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );

      final data = tester.getSemantics(find.byKey(sortKey));
      expect(data.label, contains('遞減'));
    });

    testWidgets('asc 渲染向上指示圖示，desc 渲染向下指示圖示', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.asc,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.desc,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('none 不渲染排序指示圖示', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.none,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  group('plain / twoLine 非互動', () {
    testWidgets('plain 無 Semantics.button，Semantics.header 為 true', (
      tester,
    ) async {
      const key = ValueKey('plain-header-test');
      await pumpHarness(
        tester,
        child: _column(
          const TableColumnHeader.plain(key: key, label: 'ID'),
        ),
      );

      final data = tester.getSemantics(find.byKey(key));
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.flagsCollection.isHeader, isTrue);
    });

    testWidgets('twoLine 朗讀標籤為「{ID}，{名稱}」', (tester) async {
      const key = ValueKey('two-line-header-test');
      await pumpHarness(
        tester,
        child: _column(
          const TableColumnHeader.twoLine(
            key: key,
            label: 'UC-01',
            secondLine: '節點瀏覽',
          ),
        ),
      );

      final data = tester.getSemantics(find.byKey(key));
      expect(data.label, 'UC-01，節點瀏覽');
      expect(data.flagsCollection.isButton, isFalse);
    });
  });

  group('token 引用', () {
    testWidgets('label 顏色引用 textSecondary，字重半粗', (tester) async {
      await pumpHarness(
        tester,
        child: _column(const TableColumnHeader.plain(label: '標題')),
      );

      final text = tester.widget<Text>(find.text('標題'));
      expect(text.style?.color, AppColors.textSecondary);
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('sortable 排序指示圖示顏色引用 accentStrong', (tester) async {
      await pumpHarness(
        tester,
        child: _column(
          TableColumnHeader.sortable(
            label: '標題',
            order: SortOrder.asc,
            onSort: () {},
            testKey: sortKey,
          ),
        ),
      );

      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.color, AppColors.accentStrong);
    });
  });
}
