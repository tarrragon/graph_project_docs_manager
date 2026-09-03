// 破洞報告畫面（SPEC-001 §5）三個狀態的渲染與退出路徑測試。
//
// 依 `pump_harness.dart` 慣例：以 `gapReportProvider.overrideWith` 直接注入
// 目標狀態，不等真實掃描完成（掃描完成的 microtask 時序另由
// `gap_report_provider.dart` 自身邏輯負責，非本檔驗收範圍）。逐狀態斷言
// SPEC-004 §3.6 對應行的契約內元件型別存在，並驗證每個狀態的退出路徑
// （取消、重新掃描、破洞項）可實際操作走通。
library;

import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';

const _foundState = GapReportFound([
  GapReportCategory(
    id: 'missing-frontmatter',
    items: [
      GapReportItem(
        id: 'spec-readme',
        filePath: 'docs/spec/README.md',
        lineNumber: 1,
      ),
    ],
  ),
]);

void main() {
  group('掃描中（state-gaps-scanning）', () {
    testWidgetsAtEachSize('渲染 LoadingState.skeleton', (tester, size) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(const GapReportScanning()),
          ),
        ],
        size: size,
        settle: false,
      );

      expect(AnchorFinder.state(Screen.gaps, 'scanning'), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-gaps-cancel-scan：Motion.cancelDeadline 內抵達 Domain 視圖', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(const GapReportScanning()),
          ),
        ],
        settle: false,
      );

      await tester.tap(AnchorFinder.action(Screen.gaps, 'cancel-scan'));
      await pumpContract(tester, Motion.cancelDeadline);
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
    });
  });

  group('無破洞（state-gaps-none）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(const GapReportNoGaps()),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.gaps, 'none'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-gaps-rescan：可操作，觸發後不拋出例外', (tester) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(
            () => _FixedNotifier(const GapReportNoGaps()),
          ),
        ],
        settle: false,
      );

      await tester.tap(AnchorFinder.action(Screen.gaps, 'rescan'));
      await tester.pump();

      expectNoOverflow(tester);
    });
  });

  group('有破洞（state-gaps-found）', () {
    testWidgetsAtEachSize('渲染 Panel.scrollable + Section.collapsible', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(_foundState)),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.gaps, 'found'), findsOneWidget);
      expect(find.byType(Panel), findsOneWidget);
      expect(find.byType(Section), findsOneWidget);
      expect(find.byKey(const Key('expander-gaps-missing-frontmatter')),
          findsOneWidget);
      expect(find.byKey(const Key('card-gaps-spec-readme')), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-gaps-rescan：可操作，觸發後不拋出例外', (tester) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(_foundState)),
        ],
        settle: false,
      );

      await tester.tap(AnchorFinder.action(Screen.gaps, 'rescan'));
      await tester.pump();

      expectNoOverflow(tester);
    });

    testWidgets('card-gaps-<itemId>：檔案不存在時顯示提示（開啟原始檔退出路徑可操作）', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: const GapReportScreen(),
        overrides: [
          gapReportProvider.overrideWith(() => _FixedNotifier(_foundState)),
        ],
      );

      await tester.tap(find.byKey(const Key('card-gaps-spec-readme')));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

/// 測試用固定狀態 notifier：`build()` 直接回傳注入值，不觸發真實掃描
/// microtask，維持狀態穩定供斷言（`overrideWith` 慣例，見
/// `pump_harness.dart` 檔頭說明）。
class _FixedNotifier extends GapReportNotifier {
  _FixedNotifier(this._fixed);

  final GapReportState _fixed;

  @override
  GapReportState build() => _fixed;
}
