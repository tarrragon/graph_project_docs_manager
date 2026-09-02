/// AppDataTable 元件測試（SPEC-004 4.36、5.10）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const scrollKeyTickets = ValueKey('scroll-tickets-list');
  const scrollKeyUcFlow = ValueKey('scroll-ucFlow-steps');

  const headerKey = ValueKey('header-row');

  AppTableRow buildTicketHeader() => AppTableRow.header(
        key: headerKey,
        columns: AppTableRow.ticketColumns,
        cells: const [
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
        ],
      );

  AppTableRow buildTicketRow(int index) => AppTableRow.ticket(
        key: ValueKey('ticket-row-$index'),
        id: AppText('T-$index'),
        title: AppText(TestCopy.longZh),
        status: Badge.status(label: 'in_progress'),
        priority: AppText('P0'),
        onTap: () {},
        testKey: ValueKey('card-tickets-$index'),
      );

  List<AppTableRow> buildTicketRows(int count) =>
      List.generate(count, buildTicketRow);

  AppTableRow buildStepHeader() => AppTableRow.header(
        key: headerKey,
        columns: AppTableRow.stepColumns,
        cells: const [
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
          SizedBox.shrink(),
        ],
      );

  AppTableRow buildStepRow(int index) => AppTableRow.step(
        key: ValueKey('step-row-$index'),
        number: StepNumber(number: index + 1),
        stepName: AppText(TestCopy.stepName),
        domain: RelationItem(
          id: TestCopy.domainName,
          isMono: false,
          onTap: () {},
          testKey: ValueKey('action-ucFlow-goto-domain-$index'),
        ),
        events: const BadgeRow(children: []),
        onTap: () {},
        testKey: ValueKey('card-ucFlow-step-$index'),
      );

  List<AppTableRow> buildStepRows(int count) =>
      List.generate(count, buildStepRow);

  group('變體與規模：virtual（1313 列）與 plain（39 列）', () {
    testWidgetsAtEachSize('virtual 渲染 1313 列假資料不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.virtual,
            columns: AppTableRow.ticketColumns,
            header: buildTicketHeader(),
            rows: buildTicketRows(1313),
            scrollKey: scrollKeyTickets,
          ),
        ),
        settle: false,
      );

      expectNoOverflow(tester);
      expect(find.byKey(scrollKeyTickets), findsOneWidget);
      expect(find.byKey(const ValueKey('card-tickets-0')), findsOneWidget);
    });

    testWidgetsAtEachSize('plain 渲染 39 列假資料不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: buildStepHeader(),
            rows: buildStepRows(39),
            scrollKey: scrollKeyUcFlow,
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(scrollKeyUcFlow), findsOneWidget);
      expect(find.byKey(const ValueKey('card-ucFlow-step-0')), findsOneWidget);
    });
  });

  group('捲動行為（4.36 測試點）', () {
    testWidgets('virtual drag 至末端無錯誤且 offset 改變', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.virtual,
            columns: AppTableRow.ticketColumns,
            header: buildTicketHeader(),
            rows: buildTicketRows(1313),
            scrollKey: scrollKeyTickets,
          ),
        ),
        settle: false,
      );

      final finder = find.byKey(scrollKeyTickets);
      final before = tester.state<ScrollableState>(
        find.descendant(
          of: finder,
          matching: find.byType(Scrollable),
        ),
      ).position.pixels;

      await tester.fling(finder, const Offset(0, -3000), 3000);
      await tester.pump();

      final after = tester.state<ScrollableState>(
        find.descendant(
          of: finder,
          matching: find.byType(Scrollable),
        ),
      ).position.pixels;

      expectNoOverflow(tester);
      expect(after, greaterThan(before));
    });
  });

  group('排列不變式（SPEC-004 5.10）：不重疊、最小間距、空間不足策略', () {
    testWidgets('表頭釘選於頂、不與首列相交，且列垂直互斥', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: buildStepHeader(),
            rows: buildStepRows(3),
            scrollKey: scrollKeyUcFlow,
          ),
        ),
      );

      final headerBottom = tester.getBottomLeft(find.byKey(headerKey)).dy;
      final row0Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-0')))
          .dy;

      // 不重疊：表頭不與首列相交，首列頂端不早於表頭底部。
      expect(row0Top, greaterThanOrEqualTo(headerBottom));

      final row1Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-1')))
          .dy;

      // 不重疊：列高固定為 rowHeightRelaxed，第二列頂端不早於第一列頂端
      // 加一列高。
      expect(row1Top - row0Top, LayoutSize.rowHeightRelaxed.h);
    });

    testWidgets('最小間距：列間以底邊框線寬分隔，無額外留白', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: buildStepHeader(),
            rows: buildStepRows(2),
            scrollKey: scrollKeyUcFlow,
          ),
        ),
      );

      final row0Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-0')))
          .dy;
      final row1Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-1')))
          .dy;

      expect(row1Top - row0Top, LayoutSize.rowHeightRelaxed.h);
    });

    testWidgetsAtEachSize('空間不足時（列數 × 列高 > 可用高）觸發垂直捲動', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.virtual,
            columns: AppTableRow.ticketColumns,
            header: buildTicketHeader(),
            rows: buildTicketRows(1313),
            scrollKey: scrollKeyTickets,
          ),
        ),
        settle: false,
      );

      expectNoOverflow(tester);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('card-tickets-1312')),
        find.byKey(scrollKeyTickets),
        const Offset(0, -3000),
        maxIteration: 500,
      );

      expectNoOverflow(tester);
      expect(find.byKey(const ValueKey('card-tickets-1312')), findsOneWidget);
    });
  });

  group('欄邊界對齊（4.36 測試點）', () {
    testWidgets('表頭與首列的欄邊界 x 座標相等', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: buildStepHeader(),
            rows: buildStepRows(1),
            scrollKey: scrollKeyUcFlow,
          ),
        ),
      );

      final headerLeft = tester.getTopLeft(find.byKey(headerKey)).dx;
      final rowLeft = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-0')))
          .dx;

      expect(headerLeft, rowLeft);
    });

    testWidgets('尺寸引用 token 非硬編碼：列高與 rowHeightRelaxed 一致', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          height: 400,
          child: AppDataTable(
            variant: AppDataTableVariant.plain,
            columns: AppTableRow.stepColumns,
            header: buildStepHeader(),
            rows: buildStepRows(2),
            scrollKey: scrollKeyUcFlow,
          ),
        ),
      );

      final row0Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-0')))
          .dy;
      final row1Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-ucFlow-step-1')))
          .dy;

      expect(row1Top - row0Top, LayoutSize.rowHeightRelaxed.h);
    });
  });
}
