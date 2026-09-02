// SPEC-003 §2.3 單槽來源記錄與 §2.8 首次可見訊號的 provider 層契約測試。
//
// 直接以 [ProviderContainer] 呼叫 [navigateTo] / [consumeReturnTo]（兩者
// 皆接受 [ProviderReader] 簽章，`container.read` 與 `WidgetRef.read`
// 都符合），不需經過 widget tree，測的是與 shell.dart 相同的一份實作，
// 而非重新複寫邏輯。AppShell 的返回鍵渲染由 test/widget/app/shell_test.dart
// 另外驗證。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';

void main() {
  group('returnToProvider 單槽（SPEC-003 §2.3 四條規則）', () {
    test('rail 切換後 returnTo 為 null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      navigateTo(container.read, AppDestination.tickets, NavIntent.jump);
      navigateTo(container.read, AppDestination.gaps, NavIntent.rail);

      expect(container.read(returnToProvider), isNull);
      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
    });

    test('jump 切換後 returnTo 等於跳轉前 destination', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 預設落地在 domain，從此處 jump 到 nodeDetail。
      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);

      expect(container.read(returnToProvider), AppDestination.domain);
      expect(
        container.read(selectedDestinationProvider),
        AppDestination.nodeDetail,
      );
    });

    test('連續兩次 jump（A→B→C）returnTo 為 B，非未定義行為', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // domain(A) → tickets(B) → nodeDetail(C)
      navigateTo(container.read, AppDestination.tickets, NavIntent.jump);
      navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);

      expect(container.read(returnToProvider), AppDestination.tickets);
    });

    test('consumeReturnTo 切至來源並隨即清空', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      navigateTo(container.read, AppDestination.gaps, NavIntent.jump);
      consumeReturnTo(container.read);

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), isNull);
    });

    test('returnTo 為 null 時 consumeReturnTo 不改變選取項', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      consumeReturnTo(container.read);

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), isNull);
    });
  });

  group('firstVisibleProvider（SPEC-003 §2.8 首次可見訊號）', () {
    test('啟動後只有預設落地頁的訊號為 true，其餘皆 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final destination in AppDestination.values) {
        final expected = destination == AppDestination.domain;
        expect(
          container.read(firstVisibleProvider(destination)),
          expected,
          reason: '$destination 啟動當下的首次可見訊號應為 $expected',
        );
      }
    });

    test('切走再切回同一畫面只收到一次', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 首次讀取即觸發 visited 記錄（副作用延後至 microtask）。
      expect(
        container.read(firstVisibleProvider(AppDestination.tickets)),
        false,
      );

      navigateTo(container.read, AppDestination.tickets, NavIntent.rail);
      expect(
        container.read(firstVisibleProvider(AppDestination.tickets)),
        true,
      );
      // 等待 microtask 落地 visited 集合。
      await Future<void>.delayed(Duration.zero);

      navigateTo(container.read, AppDestination.gaps, NavIntent.rail);
      navigateTo(container.read, AppDestination.tickets, NavIntent.rail);

      expect(
        container.read(firstVisibleProvider(AppDestination.tickets)),
        false,
      );
    });

    test('IndexedStack 一次建構六頁：六個 destination 皆可安全讀取', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 對照 shell.dart 的 `for (final item in AppDestination.values)`：
      // 六個畫面在同一 frame 內都會讀一次 firstVisibleProvider，
      // 確認讀取本身不因批次呼叫而拋錯或互相干擾。
      for (final destination in AppDestination.values) {
        expect(
          () => container.read(firstVisibleProvider(destination)),
          returnsNormally,
        );
      }
    });
  });
}
