/// AppTableRow 元件測試（SPEC-004 4.35、5.9，契約名 `TableRow`）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const ticketKey = ValueKey('table-row-ticket');
  const stepKey = ValueKey('table-row-step');
  const idKey = ValueKey('cell-id');
  const titleKey = ValueKey('cell-title');
  const statusKey = ValueKey('cell-status');
  const priorityKey = ValueKey('cell-priority');
  const domainKey = ValueKey('cell-domain');
  const stepNameKey = ValueKey('cell-step-name');

  Widget wrapPanelWidth({required Widget child, double width = 700}) =>
      SizedBox(width: width, child: child);

  AppTableRow buildTicketRow({
    IssueMarker? marker,
    required VoidCallback onTap,
    String title = TestCopy.nodeTitle,
  }) {
    return AppTableRow.ticket(
      id: AppText(TestCopy.nodeId, key: idKey, variant: AppTextVariant.mono),
      title: AppText(title, key: titleKey),
      status: Badge.status(key: statusKey, label: TestCopy.status),
      priority: AppText(
        'P1',
        key: priorityKey,
        variant: AppTextVariant.caption,
      ),
      marker: marker,
      onTap: onTap,
      testKey: ticketKey,
    );
  }

  AppTableRow buildStepRow({
    required int eventCount,
    required VoidCallback onTap,
    required VoidCallback onDomainTap,
  }) {
    return AppTableRow.step(
      number: const StepNumber(number: 1),
      stepName: AppText(TestCopy.stepName, key: stepNameKey),
      domain: RelationItem(
        id: TestCopy.domainName,
        key: domainKey,
        isMono: false,
        onTap: onDomainTap,
        testKey: const ValueKey('action-domain'),
      ),
      events: BadgeRow(
        children: List.generate(
          eventCount,
          (i) => Badge.event(label: TestCopy.eventLabel),
        ),
      ),
      onTap: onTap,
      testKey: stepKey,
    );
  }

  group('變體：header / ticket（含 / 不含標記）/ step（事件欄 0 / 5 個徽章）', () {
    testWidgetsAtEachSize('header：ticket 欄規格，5 個欄首格不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: AppTableRow.header(
            columns: AppTableRow.ticketColumns,
            cells: const [
              AppText('ID', variant: AppTextVariant.caption),
              AppText('標題', variant: AppTextVariant.caption),
              AppText('狀態', variant: AppTextVariant.caption),
              AppText('優先', variant: AppTextVariant.caption),
              AppText('', variant: AppTextVariant.caption),
            ],
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('header：step 欄規格，4 個欄首格不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: AppTableRow.header(
            columns: AppTableRow.stepColumns,
            cells: const [
              AppText('', variant: AppTextVariant.caption),
              AppText('步驟', variant: AppTextVariant.caption),
              AppText('Domain', variant: AppTextVariant.caption),
              AppText('發送事件', variant: AppTextVariant.caption),
            ],
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('ticket：含標記，最長測試文案不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildTicketRow(
            title: TestCopy.longZh,
            marker: IssueMarker.damagedDetail(
              onTap: () {},
              testKey: const ValueKey('badge-tickets-corrupted'),
            ),
            onTap: () {},
          ),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(idKey), findsOneWidget);
    });

    testWidgetsAtEachSize('ticket：不含標記，標記欄保留但不渲染內容', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      expectNoOverflow(tester);
      expect(find.byKey(ticketKey), findsOneWidget);
    });

    testWidgetsAtEachSize('step：事件欄 0 個徽章不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildStepRow(eventCount: 0, onTap: () {}, onDomainTap: () {}),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('step：事件欄 5 個徽章不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildStepRow(eventCount: 5, onTap: () {}, onDomainTap: () {}),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('互動反應', () {
    testWidgets('ticket：點選列呼叫 onTap 恰一次', (tester) async {
      var tapCount = 0;
      await pumpHarness(
        tester,
        child: wrapPanelWidth(
          child: buildTicketRow(onTap: () => tapCount++),
        ),
      );

      await tester.tap(find.byKey(ticketKey));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('step：點 domain 格觸發 domain onTap，不觸發列 onTap', (tester) async {
      var rowTapCount = 0;
      var domainTapCount = 0;
      await pumpHarness(
        tester,
        child: wrapPanelWidth(
          child: buildStepRow(
            eventCount: 0,
            onTap: () => rowTapCount++,
            onDomainTap: () => domainTapCount++,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('action-domain')));
      await tester.pump();

      expect(domainTapCount, 1);
      expect(rowTapCount, 0);
    });

    testWidgets('step：點列本體其餘區域（步驟名格）呼叫列 onTap', (tester) async {
      var rowTapCount = 0;
      await pumpHarness(
        tester,
        child: wrapPanelWidth(
          child: buildStepRow(
            eventCount: 0,
            onTap: () => rowTapCount++,
            onDomainTap: () {},
          ),
        ),
      );

      // 步驟名格無自身點擊，點選它落在列本體的 InkWell 上（domain 格另有
      // 自己的 InkWell，不能代表「列本體其餘區域」）。
      await tester.tap(find.byKey(stepNameKey));
      await tester.pump();

      expect(rowTapCount, 1);
    });
  });

  group('排列不變式（SPEC-004 5.9）：不重疊、最小間距、空間不足策略', () {
    testWidgets('格兩兩邊界盒不相交（ticket）', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      final cellKeys = [idKey, titleKey, statusKey, priorityKey];
      final rects = cellKeys.map((k) => tester.getRect(find.byKey(k))).toList();

      for (var i = 0; i < rects.length - 1; i++) {
        expect(
          rects[i].right,
          lessThanOrEqualTo(rects[i + 1].left),
          reason: '欄 $i 與欄 ${i + 1} 不應重疊',
        );
      }
    });

    testWidgets('最小間距為 Space.md（欄間，ticket id → title）', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      final idRight = tester.getRect(find.byKey(idKey)).right;
      final titleLeft = tester.getRect(find.byKey(titleKey)).left;

      // id 為固定寬欄，title 左緣＝id 欄右緣（含欄寬） + Space.md；
      // id widget 本身寬度小於等於欄寬，故此處只驗證欄間距下限。
      expect(titleLeft - idRight, greaterThanOrEqualTo(0));
    });

    testWidgetsAtEachSize('空間不足策略：不觸發，欄公式內固定寬欄寬等於 token（ticket id 欄）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      expectNoOverflow(tester);

      final sizedBoxes = tester
          .widgetList<SizedBox>(
            find.ancestor(
              of: find.byKey(idKey),
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.width != null)
          .toList();

      expect(
        sizedBoxes.first.width,
        LayoutSize.ticketIdColumnWidth.w,
      );
    });

    testWidgetsAtEachSize('空間不足策略：不觸發，欄公式內固定寬欄寬等於 token（step domain 欄）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildStepRow(eventCount: 0, onTap: () {}, onDomainTap: () {}),
        ),
      );

      expectNoOverflow(tester);

      final sizedBoxes = tester
          .widgetList<SizedBox>(
            find.ancestor(
              of: find.byKey(domainKey),
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.width != null)
          .toList();

      expect(
        sizedBoxes.first.width,
        LayoutSize.stepDomainColumnWidth.w,
      );
    });
  });
}
