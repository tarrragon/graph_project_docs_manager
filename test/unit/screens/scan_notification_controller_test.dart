// 掃描完成系統層通知（SPEC-003 §2.2）測試斷言十二列。
//
// 以 fake `ScanNotifier` 注入（`scanNotifierProvider.overrideWithValue`）
// 與可控 `GapReportNotifier`（`_ControllableGapReportNotifier`）驅動
// 「state-gaps-scanning 轉換至 state-gaps-none/state-gaps-found」，逐列
// 驗證 SPEC-003 §2.2「測試斷言」表。
library;

import 'dart:async';

import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/app_lifecycle.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/shell.dart' show AppShell;
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/services/scan_notifier.dart';
import 'package:graph_project_docs_manager/services/scan_notifier_provider.dart';

import '../../helpers/helpers.dart';

const _foundOneItem = GapReportFound([
  GapReportCategory(
    id: 'missing-frontmatter',
    items: [
      GapReportItem(id: 'a', filePath: 'a.md', lineNumber: 1),
    ],
  ),
]);

const _foundThreeItems = GapReportFound([
  GapReportCategory(
    id: 'missing-frontmatter',
    items: [
      GapReportItem(id: 'a', filePath: 'a.md', lineNumber: 1),
      GapReportItem(id: 'b', filePath: 'b.md', lineNumber: 1),
      GapReportItem(id: 'c', filePath: 'c.md', lineNumber: 1),
    ],
  ),
]);

void main() {
  group('SPEC-003 §2.2 系統層通知：測試斷言十二列', () {
    testWidgets('掃描完成時視窗前景且 nav-page-gaps 可見：show 0 次、無 SnackBar', (
      tester,
    ) async {
      final fixture = await _pumpFixture(tester);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.gaps;
      fixture.gapNotifier.complete(_foundOneItem);
      await tester.pump();

      expect(fixture.fake.showCalls, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      '已切至 nav-page-tickets，fake 回 granted：show 恰一次且 gapCount 正確；'
      'authorizationStatus 先於 show',
      (tester) async {
        final fixture = await _pumpFixture(tester);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();

        expect(fixture.fake.showCalls, 1);
        expect(fixture.fake.lastGapCount, 3);
        expect(fixture.fake.authorizationStatusCalls, 1);
        expect(fixture.fake.showOrder, greaterThan(fixture.fake.authOrder));
      },
    );

    testWidgets('視窗背景 → 前景往返兩次：show 仍為一次', (tester) async {
      final fixture = await _pumpFixture(tester);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.tickets;
      fixture.gapNotifier.complete(_foundThreeItems);
      await tester.pump();

      final lifecycleNotifier = fixture.container.read(
        appLifecycleStateProvider.notifier,
      );
      lifecycleNotifier.state = AppLifecycleState.paused;
      lifecycleNotifier.state = AppLifecycleState.resumed;
      lifecycleNotifier.state = AppLifecycleState.paused;
      lifecycleNotifier.state = AppLifecycleState.resumed;
      await tester.pump();

      expect(fixture.fake.showCalls, 1);
    });

    testWidgets('點 nav-item-gaps：withdraw 恰一次', (tester) async {
      final fixture = await _pumpFixture(tester);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.tickets;
      fixture.gapNotifier.complete(_foundThreeItems);
      await tester.pump();

      await tester.tap(find.byKey(const Key('nav-item-gaps')));
      await tester.pump();

      expect(fixture.fake.withdrawCalls, 1);
    });

    testWidgets(
      '點 action-gaps-rescan：withdraw 恰一次；新一輪完成且條件成立時 show 累計兩次',
      (tester) async {
        final fixture = await _pumpFixture(tester);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();
        expect(fixture.fake.showCalls, 1);

        fixture.gapNotifier.rescan();
        await tester.pump();
        expect(fixture.fake.withdrawCalls, 1);

        fixture.gapNotifier.complete(_foundOneItem);
        await tester.pump();

        expect(fixture.fake.showCalls, 2);
      },
    );

    testWidgets(
      'fake 回 denied，視窗前景、可見頁為 nav-page-tickets：'
      'show 為 0、requestAuthorization 為 0；SnackBar 文字與動作正確',
      (tester) async {
        final fake = FakeScanNotifier(
          authorization: NotificationAuthorization.denied,
        );
        final fixture = await _pumpFixture(tester, fake: fake);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();

        expect(fake.showCalls, 0);
        expect(fake.requestAuthorizationCalls, 0);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.byKey(const Key('action-scan-complete-view-gaps')),
          findsOneWidget,
        );
      },
    );

    testWidgets('fake 回 denied，視窗非前景：完成當下 findsNothing；resumed 後 SnackBar 出現', (
      tester,
    ) async {
      final fake = FakeScanNotifier(
        authorization: NotificationAuthorization.denied,
      );
      final fixture = await _pumpFixture(tester, fake: fake);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.tickets;
      fixture.container.read(appLifecycleStateProvider.notifier).state =
          AppLifecycleState.paused;
      fixture.gapNotifier.complete(_foundThreeItems);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);

      fixture.container.read(appLifecycleStateProvider.notifier).state =
          AppLifecycleState.resumed;
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'fake 回 denied，視窗非前景，resumed 前已點 nav-item-gaps：resumed 後仍 findsNothing',
      (tester) async {
        final fake = FakeScanNotifier(
          authorization: NotificationAuthorization.denied,
        );
        final fixture = await _pumpFixture(tester, fake: fake);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.container.read(appLifecycleStateProvider.notifier).state =
            AppLifecycleState.paused;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();

        await tester.tap(find.byKey(const Key('nav-item-gaps')));
        await tester.pump();

        fixture.container.read(appLifecycleStateProvider.notifier).state =
            AppLifecycleState.resumed;
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'fake 回 notDetermined，請求回 granted：requestAuthorization 恰一次且在 show 之前；show 恰一次',
      (tester) async {
        final fake = FakeScanNotifier(
          authorization: NotificationAuthorization.notDetermined,
          requestResult: NotificationAuthorization.granted,
        );
        final fixture = await _pumpFixture(tester, fake: fake);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();

        expect(fake.requestAuthorizationCalls, 1);
        expect(fake.showCalls, 1);
        expect(fake.showOrder, greaterThan(fake.requestOrder));
      },
    );

    testWidgets('fake 回 notDetermined，請求回 denied：requestAuthorization 恰一次；show 為 0', (
      tester,
    ) async {
      final fake = FakeScanNotifier(
        authorization: NotificationAuthorization.notDetermined,
        requestResult: NotificationAuthorization.denied,
      );
      final fixture = await _pumpFixture(tester, fake: fake);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.tickets;
      fixture.gapNotifier.complete(_foundThreeItems);
      await tester.pump();

      expect(fake.requestAuthorizationCalls, 1);
      expect(fake.showCalls, 0);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'fake 於 activated 發事件：selectedDestinationProvider 等於 gaps、returnToProvider 為 null',
      (tester) async {
        final fixture = await _pumpFixture(tester);
        fixture.container.read(selectedDestinationProvider.notifier).state =
            AppDestination.tickets;
        fixture.gapNotifier.complete(_foundThreeItems);
        await tester.pump();

        fixture.fake.fireActivated();
        await tester.pump();

        expect(
          fixture.container.read(selectedDestinationProvider),
          AppDestination.gaps,
        );
        expect(fixture.container.read(returnToProvider), isNull);
      },
    );

    testWidgets('掃描中按 action-gaps-cancel-scan：show 為 0、requestAuthorization 為 0', (
      tester,
    ) async {
      final fixture = await _pumpFixture(tester);
      fixture.container.read(selectedDestinationProvider.notifier).state =
          AppDestination.tickets;

      fixture.gapNotifier.cancelScan();
      // 模擬原排定的完成任務仍在取消之後回報結果——SPEC-003 §2.5 C5：
      // 取消完成不通知，controller 須依 `previous.isCancelling` 判別跳過。
      fixture.gapNotifier.complete(_foundThreeItems);
      await tester.pump();

      expect(fixture.fake.showCalls, 0);
      expect(fixture.fake.requestAuthorizationCalls, 0);
    });
  });
}

class _Fixture {
  _Fixture(this.container, this.fake, this.gapNotifier);

  final ProviderContainer container;
  final FakeScanNotifier fake;
  final _ControllableGapReportNotifier gapNotifier;
}

Future<_Fixture> _pumpFixture(WidgetTester tester, {FakeScanNotifier? fake}) async {
  final resolvedFake = fake ?? FakeScanNotifier();
  final gapNotifierInstance = _ControllableGapReportNotifier();
  await pumpApp(
    tester,
    overrides: [
      scanNotifierProvider.overrideWithValue(resolvedFake),
      gapReportProvider.overrideWith(() => gapNotifierInstance),
    ],
    settle: false,
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(AppShell.shellKey)),
  );
  return _Fixture(container, resolvedFake, gapNotifierInstance);
}

/// 可程式化控制完成時機的 [GapReportNotifier]：不排定真實掃描
/// microtask，測試直接呼叫 [complete] 模擬「掃描完成」這個事件本身。
class _ControllableGapReportNotifier extends GapReportNotifier {
  @override
  GapReportState build() => const GapReportScanning();

  /// 模擬掃描完成：直接把 [next] 設為新狀態。
  void complete(GapReportState next) {
    state = next;
  }

  @override
  void rescan() {
    state = const GapReportScanning();
  }

  @override
  void cancelScan() {
    final current = state;
    if (current is! GapReportScanning || current.isCancelling) return;
    state = const GapReportScanning(isCancelling: true);
  }
}

/// 測試替身：記錄各方法呼叫次數與順序（SPEC-003 §2.2「測試斷言」表要求
/// 的「概述表『外部程序呼叫』形式」）。
class FakeScanNotifier implements ScanNotifier {
  FakeScanNotifier({
    this.authorization = NotificationAuthorization.granted,
    this.requestResult = NotificationAuthorization.granted,
  });

  NotificationAuthorization authorization;
  NotificationAuthorization requestResult;

  int authorizationStatusCalls = 0;
  int requestAuthorizationCalls = 0;
  int showCalls = 0;
  int withdrawCalls = 0;
  int? lastGapCount;

  int _callSequence = 0;
  int authOrder = -1;
  int requestOrder = -1;
  int showOrder = -1;

  final StreamController<void> _activatedController =
      StreamController<void>.broadcast();

  void fireActivated() => _activatedController.add(null);

  @override
  Stream<void> get activated => _activatedController.stream;

  @override
  Future<NotificationAuthorization> authorizationStatus() async {
    authorizationStatusCalls++;
    authOrder = _callSequence++;
    return authorization;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requestAuthorizationCalls++;
    requestOrder = _callSequence++;
    return requestResult;
  }

  @override
  Future<void> show(ScanCompleteNotification notification) async {
    showCalls++;
    showOrder = _callSequence++;
    lastGapCount = notification.gapCount;
  }

  @override
  Future<void> withdraw() async {
    withdrawCalls++;
  }
}
