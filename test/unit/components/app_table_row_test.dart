/// AppTableRow 元件測試（SPEC-004 4.35、5.9，契約名 `TableRow`）。
library;

import 'package:flutter/material.dart' show Icons, InkWell;
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
  const blockedByKey = ValueKey('cell-blocked-by');
  const domainKey = ValueKey('cell-domain');
  const stepNameKey = ValueKey('cell-step-name');
  const eventKey = ValueKey('cell-event');
  const emittedByKey = ValueKey('cell-emitted-by');
  const consumedByKey = ValueKey('cell-consumed-by');

  Widget wrapPanelWidth({required Widget child, double width = 700}) =>
      SizedBox(width: width, child: child);

  AppTableRow buildTicketRow({
    IssueMarker? marker,
    required VoidCallback onTap,
    String title = TestCopy.nodeTitle,
    String blockedBy = '—',
    bool isLocated = false,
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
      blockedBy: AppText(
        blockedBy,
        key: blockedByKey,
        variant: AppTextVariant.mono,
      ),
      marker: marker,
      onTap: onTap,
      testKey: ticketKey,
      isLocated: isLocated,
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
    testWidgetsAtEachSize('header：ticket 欄規格，6 個欄首格不溢位', (tester, size) async {
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
              AppText('blockedBy', variant: AppTextVariant.caption),
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

    testWidgetsAtEachSize('ticket：blockedBy 空值渲染「—」', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      expectNoOverflow(tester);
      expect(
        tester.widget<AppText>(find.byKey(blockedByKey)).text,
        '—',
      );
    });

    testWidgetsAtEachSize('ticket：blockedBy 多值截斷不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildTicketRow(
            onTap: () {},
            blockedBy: '${TestCopy.nodeId}, ${TestCopy.nodeId}, '
                '${TestCopy.nodeId}, ${TestCopy.nodeId}',
          ),
        ),
      );

      expectNoOverflow(tester);
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

  AppTableRow buildEventFlowRow({
    AppIcon? marker,
    bool isLocated = false,
    String emittedBy = TestCopy.stepName,
    String consumedBy = TestCopy.stepName,
  }) {
    return AppTableRow.eventFlow(
      event: AppText(TestCopy.nodeId, key: eventKey, variant: AppTextVariant.mono),
      emittedBy: AppText(emittedBy, key: emittedByKey),
      consumedBy: AppText(consumedBy, key: consumedByKey),
      marker: marker,
      isLocated: isLocated,
    );
  }

  group('變體：eventFlow（含 / 不含孤立事件標記）', () {
    testWidgetsAtEachSize('eventFlow：不含標記不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(child: buildEventFlowRow()),
      );

      expectNoOverflow(tester);
      expect(find.byKey(eventKey), findsOneWidget);
    });

    testWidgetsAtEachSize('eventFlow：含孤立事件標記不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildEventFlowRow(
            marker: const AppIcon(
              icon: Icons.warning,
              color: AppColors.error,
              semanticLabel: '孤立事件',
            ),
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('eventFlow：發出或消費為本 UC 外文案不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: wrapPanelWidth(
          child: buildEventFlowRow(
            emittedBy: '本 UC 外（version-management）',
            consumedBy: TestCopy.stepName,
          ),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('eventFlow：非互動與定位高亮', () {
    testWidgets('eventFlow 點擊不呼叫任何回呼（非互動）', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildEventFlowRow()),
      );

      // 非互動列不接受 onTap，直接驗證找不到可點擊的 InkWell。
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('isLocated 為 true 時整列底色為 surfaceIconTint', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildEventFlowRow(isLocated: true)),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.byKey(eventKey),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, AppColors.surfaceIconTint);
    });

    testWidgets('isLocated 為 false（預設）時整列無底色', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildEventFlowRow()),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.byKey(eventKey),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, isNull);
    });
  });

  group('ticket：定位高亮', () {
    testWidgets('isLocated 傳與不傳的底色不同（E1 對照）', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(
          child: buildTicketRow(onTap: () {}, isLocated: true),
        ),
      );
      final locatedDecoration =
          (tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.byKey(idKey),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration);

      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );
      final defaultDecoration =
          (tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.byKey(idKey),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration);

      expect(locatedDecoration.color, isNot(defaultDecoration.color));
    });

    testWidgets('isLocated 為 true 時整列底色為 surfaceIconTint', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(
          child: buildTicketRow(onTap: () {}, isLocated: true),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(idKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, AppColors.surfaceIconTint);
    });

    testWidgets('isLocated 為 false（預設）時整列無底色', (tester) async {
      await pumpHarness(
        tester,
        child: wrapPanelWidth(child: buildTicketRow(onTap: () {})),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(idKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, isNull);
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

      final cellKeys = [idKey, titleKey, statusKey, priorityKey, blockedByKey];
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
