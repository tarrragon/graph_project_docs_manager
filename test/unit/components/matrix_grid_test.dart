/// MatrixGrid 元件測試（SPEC-004 4.37、5.11）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const scrollKey = ValueKey('scroll-domain-matrix');

  List<TableColumnHeader> buildHeaders(int count) => List.generate(
    count,
    (i) => TableColumnHeader.twoLine(label: 'UC-0$i', secondLine: 'UC $i 名稱'),
  );

  MatrixCell buildCell(String rowId, int col, {bool selected = false}) =>
      MatrixCell(
        relation: Relation.direct,
        isSelected: selected,
        isRowSelected: false,
        semanticLabel: 'cell-$rowId-$col',
        onTap: () {},
        testKey: ValueKey('cell-domain-$rowId-$col'),
      );

  List<MatrixRow> buildRows(int rowCount, int colCount) => List.generate(
    rowCount,
    (r) => MatrixRow(
      domainId: 'domain-$r',
      domainName: 'domain-$r 名稱',
      cells: List.generate(colCount, (c) => buildCell('domain-$r', c)),
      subtotal: r,
    ),
  );

  Widget buildGrid({
    int colCount = 3,
    int rowCount = 2,
    String? selectedDomainId,
    (String, String)? selectedCell,
    ValueChanged<String>? onSelectDomain,
    VoidCallback? onClearSelection,
  }) {
    return SizedBox(
      width: 700,
      height: 400,
      child: MatrixGrid(
        columnHeaders: buildHeaders(colCount),
        rows: buildRows(rowCount, colCount),
        selectedDomainId: selectedDomainId,
        selectedCell: selectedCell,
        onSelectDomain: onSelectDomain ?? (_) {},
        onClearSelection: onClearSelection ?? () {},
        scrollKey: scrollKey,
      ),
    );
  }

  group('測試契約：渲染全部子件與最長測試文案，不溢位', () {
    testWidgetsAtEachSize('欄首、列首、格、小計皆渲染且不溢位', (tester, size) async {
      await pumpHarness(tester, size: size, child: buildGrid());

      expectNoOverflow(tester);
      expect(find.byKey(scrollKey), findsOneWidget);
      expect(find.text('UC-00'), findsOneWidget);
      expect(find.text('domain-0 名稱'), findsOneWidget);
      expect(find.byKey(const ValueKey('cell-domain-domain-0-0')), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // subtotal row 0
    });

    testWidgetsAtEachSize('子件數量上限情境：大量列與欄不溢位（依 5.11 捲動）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: buildGrid(colCount: 12, rowCount: 40),
      );

      expectNoOverflow(tester);
      expect(find.byKey(scrollKey), findsOneWidget);
    });

    testWidgetsAtEachSize('最長測試文案（domain 名 TestCopy.longToken）截斷不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 700,
          height: 400,
          child: MatrixGrid(
            columnHeaders: buildHeaders(2),
            rows: [
              MatrixRow(
                domainId: 'd0',
                domainName: TestCopy.longToken,
                cells: [buildCell('d0', 0), buildCell('d0', 1)],
                subtotal: 999,
              ),
            ],
            selectedDomainId: null,
            selectedCell: null,
            onSelectDomain: (_) {},
            onClearSelection: () {},
            scrollKey: scrollKey,
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('action-domain-select-d0')), findsOneWidget);
    });
  });

  group('互動反應', () {
    testWidgets('點列首呼叫 onSelectDomain 並傳入 domainId', (tester) async {
      String? selected;
      await pumpHarness(
        tester,
        child: buildGrid(onSelectDomain: (id) => selected = id),
      );

      await tester.tap(find.byKey(const ValueKey('action-domain-select-domain-0')));
      await tester.pump();

      expect(selected, 'domain-0');
    });

    testWidgets('selectedDomainId 對應列以 surfaceIconTint 高亮', (tester) async {
      await pumpHarness(
        tester,
        child: buildGrid(selectedDomainId: 'domain-0'),
      );

      final decoratedBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) =>
                (box.decoration as BoxDecoration).color ==
                AppColors.surfaceIconTint,
          );

      expect(decoratedBoxes, isNotEmpty);
    });

    testWidgets('Esc 有選格時呼叫 onClearSelection', (tester) async {
      var cleared = false;
      await pumpHarness(
        tester,
        child: buildGrid(
          selectedCell: ('domain-0', 'UC-00'),
          onClearSelection: () => cleared = true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(cleared, isTrue);
    });

    testWidgets('Esc 無選格時不呼叫 onClearSelection', (tester) async {
      var cleared = false;
      await pumpHarness(
        tester,
        child: buildGrid(
          selectedCell: null,
          onClearSelection: () => cleared = true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(cleared, isFalse);
    });
  });

  group('排列不變式（SPEC-004 5.11）', () {
    testWidgets('不重疊：相鄰列列首不重疊', (tester) async {
      await pumpHarness(tester, child: buildGrid(rowCount: 2));

      final row0Bottom = tester
          .getBottomLeft(find.text('domain-0 名稱'))
          .dy;
      final row1Top = tester.getTopLeft(find.text('domain-1 名稱')).dy;

      expect(row1Top, greaterThanOrEqualTo(row0Bottom));
    });

    testWidgets('最小間距：列間為 Space.xxs', (tester) async {
      await pumpHarness(tester, child: buildGrid(rowCount: 2));

      final row0Bottom = tester
          .getBottomLeft(find.text('domain-0 名稱'))
          .dy;
      final row1Top = tester.getTopLeft(find.text('domain-1 名稱')).dy;

      expect(row1Top - row0Bottom, Space.xxs);
    });

    testWidgets('空間不足策略：欄數超出可用寬時仍可渲染（委派二維捲動）', (tester) async {
      await pumpHarness(
        tester,
        child: buildGrid(colCount: 10, rowCount: 30),
      );

      expectNoOverflow(tester);
      // 觸發條件成立（10 欄遠超 700 寬可用空間）時，容器不裁切拋例外，
      // 而是交由 TableView 的二維 Scrollable 承載，驗證其存在。
      expect(find.byType(TwoDimensionalScrollable), findsWidgets);
    });
  });
}
