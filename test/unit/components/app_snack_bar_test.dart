/// AppSnackBar 元件測試（SPEC-004 §4.26「測試點」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/attention_level.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _triggerPlainKey = Key('trigger-plain');
const _triggerActionKey = Key('trigger-action');
const _snackBarActionKey = Key('snackbar-action');

// SnackBar 進出動畫為 Flutter Material 內建 250ms transition，非本專案 token
// （SPEC-004 §4.26「Material 預設進出，不覆寫」）；顯示期間長度由 AppSnackBar
// 傳入的 Motion.snackBar / Motion.snackBarWithAction 決定。全檔共用一份宣告
// （0.1.0-W3-176 Phase 4b：原三個群組各自宣告同值常數，改用單一檔案級常數，
// 避免改一處忘另兩處而靜默失準）。
const _materialTransition = Duration(milliseconds: 250);

/// 一次 [AppSnackBarLogSink] 呼叫的紀錄快照（0.1.0-W3-176 Phase 4b：原為
/// 四處重複的匿名 record 型別字面，改用檔案私有 typedef 收斂）。
typedef _SnackBarLogRecord =
    ({AppSnackBarLogEvent event, Map<String, Object?> fields, int? level});

/// SnackBar 的進出動畫由 Material 內建 [Timer] + [AnimationController] 驅動
/// （SPEC-004 §4.26「Material 預設進出，不覆寫」）；`flutter_test` 的
/// fake clock 需以小步距（<= 100ms）反覆 pump 才能讓 Timer 觸發與動畫逐幀
/// 推進被正確捕捉（單次大跳躍的 pump 只會產生一個 frame，可能落在
/// Timer 觸發之前）。本函式把 [total] 拆成 100ms 一步的 pump 序列。
Future<void> _pumpBy(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    final next = (total - elapsed) < step ? (total - elapsed) : step;
    await tester.pump(next);
    elapsed += next;
  }
}

/// 建構觸發按鈕，點按即呼叫 [AppSnackBar.show]。共用於全部測試組。
// 預設值只存在於本測試輔助函式，不得回流到 AppSnackBar.show（0.1.0-W3-205
// Phase 1 §2.0 已否決預設值；level 為必填是刻意設計）。
Widget _triggerHarness({
  required String message,
  AttentionLevel level = AttentionLevel.discardable,
  AttentionHolderHint? currentHolder,
  AppSnackBarVariant variant = AppSnackBarVariant.plain,
  String? actionLabel,
  VoidCallback? onAction,
  AppSnackBarOrigin origin = AppSnackBarOrigin.background,
}) {
  return Builder(
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          key: variant == AppSnackBarVariant.plain
              ? _triggerPlainKey
              : _triggerActionKey,
          onPressed: () => AppSnackBar.show(
            context,
            message: message,
            level: level,
            currentHolder: currentHolder,
            variant: variant,
            actionLabel: actionLabel,
            onAction: onAction,
            actionTestKey: _snackBarActionKey,
            origin: origin,
          ),
          child: const Text('trigger'),
        ),
      ],
    ),
  );
}

void main() {
  group('AppSnackBar 全變體渲染', () {
    testWidgets('plain 觸發後顯示 SnackBar 且文字相符', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: 'plain-message'),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('plain-message'), findsOneWidget);
    });

    testWidgets('withAction 觸發後顯示 SnackBar 與動作', (tester) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('action-message'), findsOneWidget);
      expect(find.text('action-label'), findsOneWidget);
      expect(actionCalled, 0);
    });
  });

  group('尺寸不溢位', () {
    testWidgetsAtEachSize('plain 於兩種視窗尺寸下不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _triggerHarness(message: TestCopy.longZh),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('withAction 於兩種視窗尺寸下不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _triggerHarness(
          message: TestCopy.longEn,
          variant: AppSnackBarVariant.withAction,
          actionLabel: TestCopy.longToken,
          onAction: () {},
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expectNoOverflow(tester);
    });
  });

  group('最長測試文案：訊息兩行末截斷、動作 label 截斷', () {
    testWidgets('message 用 TestCopy.longZh 兩行截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: TestCopy.longZh),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(TestCopy.longZh),
        ),
      );
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expectNoOverflow(tester);
    });

    testWidgets('動作 label 用 TestCopy.longToken 單行截斷', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'msg',
          variant: AppSnackBarVariant.withAction,
          actionLabel: TestCopy.longToken,
          onAction: () {},
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expectNoOverflow(tester);
    });
  });

  group('zh / en 五個 key 皆不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('五個既有 key @ ${locale.languageCode}', (tester) async {
        late AppLocalizations l10n;
        await pumpHarness(
          tester,
          locale: locale,
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    key: _triggerPlainKey,
                    onPressed: () => AppSnackBar.show(
                      context,
                      message: l10n.openedExternallyMessage,
                      level: AttentionLevel.discardable,
                    ),
                    child: const Text('trigger'),
                  ),
                ],
              );
            },
          ),
        );

        for (final message in [
          l10n.openedExternallyMessage,
          l10n.sourceFileNotFoundSnackbarMessage,
          l10n.sourceFileStillMissingMessage,
        ]) {
          AppSnackBar.show(
            tester.element(find.byKey(_triggerPlainKey)),
            message: message,
            level: AttentionLevel.discardable,
          );
          await tester.pump();
          expectNoOverflow(tester);
        }

        for (final label in [l10n.refreshAction, l10n.rescanAction]) {
          AppSnackBar.show(
            tester.element(find.byKey(_triggerPlainKey)),
            message: 'x',
            level: AttentionLevel.discardable,
            variant: AppSnackBarVariant.withAction,
            actionLabel: label,
            actionTestKey: _snackBarActionKey,
            onAction: () {},
          );
          await tester.pump();
          expectNoOverflow(tester);
        }
      });
    }
  });

  group('停留時間與退出路徑', () {
    testWidgets('pump(Motion.snackBar) 後 plain 消失', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: 'plain-message'),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      expect(find.byType(SnackBar), findsOneWidget);

      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'withAction 於 Motion.snackBar 後仍存在、Motion.snackBarWithAction 後消失',
      (tester) async {
        await pumpHarness(
          tester,
          child: _triggerHarness(
            message: 'action-message',
            variant: AppSnackBarVariant.withAction,
            actionLabel: 'action-label',
            onAction: () {},
          ),
        );

        await tester.tap(find.byKey(_triggerActionKey));
        await tester.pump();
        await _pumpBy(tester, _materialTransition);
        expect(find.byType(SnackBar), findsOneWidget);

        await _pumpBy(tester, Motion.snackBar);
        expect(find.byType(SnackBar), findsOneWidget);

        final remaining = Motion.snackBarWithAction - Motion.snackBar;
        await _pumpBy(
          tester,
          remaining + _materialTransition + _materialTransition,
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('動作點選呼叫 onAction 恰一次且 SnackBar 即時消失', (tester) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition + _materialTransition);

      expect(actionCalled, 1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('診斷日誌（0.1.0-W3-165）', () {
    // 斷言只依 AppSnackBarLogEvent 列舉與呼叫次數，不比對日誌散文字面——
    // `0.1.0-W3-132` 尚未把日誌訊息改為事件識別碼，比對字面會與其目標衝突
    // （how.strategy 決策點 4 的測試規範）。
    late AppSnackBarLogSink originalSink;
    final events = <AppSnackBarLogEvent>[];
    final levels = <int?>[];

    setUp(() {
      originalSink = AppSnackBar.logSink;
      events.clear();
      levels.clear();
      AppSnackBar.logSink = (event, fields, {level}) {
        events.add(event);
        levels.add(level);
      };
    });

    tearDown(() {
      AppSnackBar.logSink = originalSink;
    });

    testWidgets('plain 顯示後自然逾時：記錄 shown 接著 closed', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: 'plain-message'),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      expect(events, [AppSnackBarLogEvent.preempted, AppSnackBarLogEvent.shown]);
      expect(levels, [null, null]);

      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      expect(events, [
        AppSnackBarLogEvent.preempted,
        AppSnackBarLogEvent.shown,
        AppSnackBarLogEvent.closed,
      ]);
    });

    testWidgets('withAction 按下動作：記錄 shown、actionPressed、closed', (
      tester,
    ) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      expect(events, [AppSnackBarLogEvent.preempted, AppSnackBarLogEvent.shown]);

      await _pumpBy(tester, _materialTransition);
      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition + _materialTransition);

      expect(events, [
        AppSnackBarLogEvent.preempted,
        AppSnackBarLogEvent.shown,
        AppSnackBarLogEvent.actionPressed,
        AppSnackBarLogEvent.closed,
      ]);
      expect(actionCalled, 1);
    });

    testWidgets('context 已卸載時記錄 skippedUnmounted（warning）且不顯示', (tester) async {
      late BuildContext capturedContext;
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      // 以整棵替換的方式卸載 capturedContext 所屬的 Element。
      await tester.pumpWidget(const SizedBox.shrink());

      AppSnackBar.show(
        capturedContext,
        message: 'unused',
        level: AttentionLevel.discardable,
      );

      expect(events, [AppSnackBarLogEvent.skippedUnmounted]);
      expect(levels, [900]);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('關聯識別與截斷等級判別（0.1.0-W3-176）', () {
    // 新群組自裝替身，既有群組的 events／levels 不被觸及（acceptance A8）。
    late AppSnackBarLogSink originalSink;
    final records = <_SnackBarLogRecord>[];

    setUp(() {
      originalSink = AppSnackBar.logSink;
      records.clear();
      AppSnackBar.logSink = (event, fields, {level}) {
        records.add((event: event, fields: Map.of(fields), level: level));
      };
    });

    tearDown(() {
      AppSnackBar.logSink = originalSink;
    });

    const anchorKey = Key('anchor-176');

    int showIdOf(_SnackBarLogRecord record) => record.fields['showId']! as int;

    Object? originOf(_SnackBarLogRecord record) => record.fields['origin'];

    _SnackBarLogRecord closedWithReason(SnackBarClosedReason reason) =>
        records.singleWhere(
          (record) =>
              record.event == AppSnackBarLogEvent.closed &&
              record.fields['reason'] == reason,
        );

    // 直接回傳 ElevatedButton，不用 Builder 包裝——測試以
    // tester.element(find.byKey(anchorKey)) 取得 context，Builder 的
    // context 參數未被使用（0.1.0-W3-176 Phase 4b：移除無作用外殼）。
    Widget anchorHarness() =>
        ElevatedButton(key: anchorKey, onPressed: () {}, child: const Text('anchor'));

    testWidgets('T-1 基準線：plain 自然逾時', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      expect(records, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(anchor.mounted, isTrue);

      AppSnackBar.show(
        anchor,
        message: 'plain-message',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      expect(records.map((record) => record.event), [
        AppSnackBarLogEvent.preempted,
        AppSnackBarLogEvent.shown,
        AppSnackBarLogEvent.closed,
      ]);
      // 位移後（M8）：比較的仍是 shown（[1]）與 closed（[2]），不是
      // preempted（[0]）與 shown（[1]）。
      expect(showIdOf(records[1]), showIdOf(records[2]));
      expect(records[2].fields['reason'], SnackBarClosedReason.timeout);
      expect(records[2].level, isNull);
      expect(records[1].level, isNull);
    });

    testWidgets('T-2 同步區塊內連續兩次 show 的配對', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));
      expect(records, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(anchor.mounted, isTrue);

      AppSnackBar.show(
        anchor,
        message: 'first',
        level: AttentionLevel.discardable,
      );
      AppSnackBar.show(
        anchor,
        message: 'second',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      final shownRecords = records
          .where((record) => record.event == AppSnackBarLogEvent.shown)
          .toList();
      expect(shownRecords, hasLength(2));
      final firstShowId = showIdOf(shownRecords[0]);
      final secondShowId = showIdOf(shownRecords[1]);
      expect(secondShowId, greaterThan(firstShowId));

      final hideClosed = closedWithReason(SnackBarClosedReason.hide);
      expect(showIdOf(hideClosed), firstShowId);
      final timeoutClosed = closedWithReason(SnackBarClosedReason.timeout);
      expect(showIdOf(timeoutClosed), secondShowId);
    });

    testWidgets('T-3 配對不依賴出現順序的佐證', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'first',
        level: AttentionLevel.discardable,
      );
      AppSnackBar.show(
        anchor,
        message: 'second',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      final secondShownIndex = records.indexWhere(
        (record) =>
            record.event == AppSnackBarLogEvent.shown &&
            record.fields['message'] == 'second',
      );
      final hideClosedIndex = records.indexWhere(
        (record) =>
            record.event == AppSnackBarLogEvent.closed &&
            record.fields['reason'] == SnackBarClosedReason.hide,
      );
      expect(hideClosedIndex, greaterThan(secondShownIndex));
    });

    testWidgets('T-4 顯示中途被截斷的配對', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'first',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        records.where((record) => record.event == AppSnackBarLogEvent.shown),
        hasLength(1),
      );
      // 依事件值選取，不得改成 records.last（M11：依位置選取會在事件順序
      // 調整時無聲取到錯的一筆）。
      final firstShowId = showIdOf(
        records.singleWhere(
          (record) => record.event == AppSnackBarLogEvent.shown,
        ),
      );

      AppSnackBar.show(
        anchor,
        message: 'second',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      final hideClosed = closedWithReason(SnackBarClosedReason.hide);
      expect(showIdOf(hideClosed), firstShowId);
    });

    // T-5 截斷等級矩陣：variant × origin（level 對 variant 不敏感的窮舉）。
    final levelMatrix = <(AppSnackBarVariant, AppSnackBarOrigin, int)>[
      (AppSnackBarVariant.plain, AppSnackBarOrigin.background, 900),
      (AppSnackBarVariant.plain, AppSnackBarOrigin.userInitiated, 800),
      (AppSnackBarVariant.withAction, AppSnackBarOrigin.background, 900),
      (AppSnackBarVariant.withAction, AppSnackBarOrigin.userInitiated, 800),
    ];

    for (final (variant, origin, expectedLevel) in levelMatrix) {
      testWidgets(
        'T-5 截斷等級矩陣：variant=$variant origin=$origin -> level=$expectedLevel',
        (tester) async {
          await pumpHarness(
            tester,
            child: _triggerHarness(
              message: 'first',
              variant: variant,
              actionLabel: variant == AppSnackBarVariant.withAction
                  ? 'action-label'
                  : null,
              onAction: variant == AppSnackBarVariant.withAction
                  ? () {}
                  : null,
              origin: origin,
            ),
          );
          final triggerKey = variant == AppSnackBarVariant.plain
              ? _triggerPlainKey
              : _triggerActionKey;
          await tester.tap(find.byKey(triggerKey));
          await tester.pump();
          expect(find.byType(SnackBar), findsOneWidget);

          AppSnackBar.show(
            tester.element(find.byKey(triggerKey)),
            message: 'second',
            level: AttentionLevel.discardable,
          );
          await tester.pump();
          await _pumpBy(tester, _materialTransition);
          await _pumpBy(
            tester,
            Motion.snackBar + _materialTransition + _materialTransition,
          );

          // reason==hide 由 closedWithReason 的選取條件保證，不重複斷言
          // （0.1.0-W3-176 Phase 4b：移除恆真斷言，reason 已定案無其他可驗證
          // 性質可替代）。
          final hideClosed = closedWithReason(SnackBarClosedReason.hide);
          expect(originOf(hideClosed), origin);
          expect(hideClosed.level, expectedLevel);
        },
      );
    }

    testWidgets('T-6 origin 預設值', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'first',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      expect(find.byType(SnackBar), findsOneWidget);

      AppSnackBar.show(
        anchor,
        message: 'second',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      final hideClosed = closedWithReason(SnackBarClosedReason.hide);
      expect(originOf(hideClosed), AppSnackBarOrigin.background);
      expect(hideClosed.level, 900);
    });

    testWidgets('T-7 withAction 按下動作', (tester) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );
      expect(find.byKey(_triggerActionKey), findsOneWidget);

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      expect(find.byKey(_snackBarActionKey), findsOneWidget);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition + _materialTransition);

      expect(records.map((record) => record.event), [
        AppSnackBarLogEvent.preempted,
        AppSnackBarLogEvent.shown,
        AppSnackBarLogEvent.actionPressed,
        AppSnackBarLogEvent.closed,
      ]);
      final showId = showIdOf(records[1]);
      expect(showIdOf(records[2]), showId);
      expect(showIdOf(records[3]), showId);
      expect(records[3].fields['reason'], SnackBarClosedReason.action);
      expect(records[3].level, isNull);
      expect(actionCalled, 1);
    });

    testWidgets('T-8 context 已卸載', (tester) async {
      late BuildContext capturedContext;
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(capturedContext.mounted, isFalse);

      AppSnackBar.show(
        capturedContext,
        message: 'unused',
        level: AttentionLevel.discardable,
      );

      expect(records, hasLength(1));
      expect(records.single.event, AppSnackBarLogEvent.skippedUnmounted);
      expect(records.single.level, 900);
      expect(records.single.fields['showId'], isNotNull);
      expect(records.single.fields['origin'], AppSnackBarOrigin.background);
      expect(find.byType(SnackBar), findsNothing);

      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );
      expect(records, hasLength(1));
    });

    test('T-9 事件列舉結構', () {
      // M16（規格驅動）：既有四值維持原順序在前，新增 preempted、yielded
      // 接於其後。本斷言紅燈即其正確運作，不是回歸。
      expect(AppSnackBarLogEvent.values, [
        AppSnackBarLogEvent.shown,
        AppSnackBarLogEvent.skippedUnmounted,
        AppSnackBarLogEvent.actionPressed,
        AppSnackBarLogEvent.closed,
        AppSnackBarLogEvent.preempted,
        AppSnackBarLogEvent.yielded,
      ]);
    });
  });

  group('截斷裁決（0.1.0-W3-205 G-B）', () {
    // 自裝替身，不觸及其他群組的 events／levels／records（P2.7 約束 5）。
    late AppSnackBarLogSink originalSink;
    final records = <_SnackBarLogRecord>[];

    setUp(() {
      originalSink = AppSnackBar.logSink;
      records.clear();
      AppSnackBar.logSink = (event, fields, {level}) {
        records.add((event: event, fields: Map.of(fields), level: level));
      };
    });

    tearDown(() {
      AppSnackBar.logSink = originalSink;
    });

    const anchorKey = Key('anchor-205');

    int showIdOf(_SnackBarLogRecord record) => record.fields['showId']! as int;

    Widget anchorHarness() => ElevatedButton(
      key: anchorKey,
      onPressed: () {},
      child: const Text('anchor'),
    );

    // 12 格裁決窮舉矩陣（P2.3）：期望值為獨立宣告的事實表，不由被測規則
    // 推導——實作寫錯時期望值不會同步寫錯。
    const holderLevels = <AttentionLevel?>[
      null,
      AttentionLevel.discardable,
      AttentionLevel.mustLeaveTrace,
      AttentionLevel.undroppable,
    ];
    const newLevels = AttentionLevel.values;

    String decisionOf(AttentionLevel? holder, AttentionLevel incoming) {
      if (holder == null) return 'holderUnknown';
      if (holder.index < incoming.index) return 'preemptLower';
      if (holder.index == incoming.index) return 'replaceSameLevel';
      return 'yieldToHolder';
    }

    for (final holderLevel in holderLevels) {
      for (final newLevel in newLevels) {
        final decision = decisionOf(holderLevel, newLevel);
        testWidgets(
          'T-205-1：holder=$holderLevel new=$newLevel -> $decision',
          (tester) async {
            await pumpHarness(tester, child: anchorHarness());
            final anchor = tester.element(find.byKey(anchorKey));
            expect(records, isEmpty);
            expect(find.byType(SnackBar), findsNothing);
            expect(anchor.mounted, isTrue);

            AttentionHolderHint? currentHolder;
            if (holderLevel != null) {
              AppSnackBar.show(
                anchor,
                message: 'holder-message',
                level: holderLevel,
              );
              await tester.pump();
              await _pumpBy(tester, _materialTransition);
              expect(records, isNotEmpty);
              final shownRecord = records.singleWhere(
                (r) => r.event == AppSnackBarLogEvent.shown,
              );
              currentHolder = AttentionHolderHint(
                showId: showIdOf(shownRecord),
                level: holderLevel,
              );
              records.clear();
            }

            AppSnackBar.show(
              anchor,
              message: 'incoming-message',
              level: newLevel,
              currentHolder: currentHolder,
            );
            await tester.pump();
            await _pumpBy(tester, _materialTransition * 2);

            switch (decision) {
              case 'holderUnknown':
                expect(find.text('incoming-message'), findsOneWidget);
                expect(
                  records.map((r) => r.event),
                  containsAllInOrder([
                    AppSnackBarLogEvent.preempted,
                    AppSnackBarLogEvent.shown,
                  ]),
                );
                final preempted = records.firstWhere(
                  (r) => r.event == AppSnackBarLogEvent.preempted,
                );
                expect(preempted.fields['holderUnknown'], isTrue);
                expect(preempted.fields['preemptedShowId'], isNull);
                expect(preempted.fields['preemptedLevel'], isNull);
                expect(preempted.fields['sameLevelReplace'], isFalse);
                expect(preempted.fields['level'], newLevel);
              case 'preemptLower':
              case 'replaceSameLevel':
                expect(find.text('incoming-message'), findsOneWidget);
                expect(find.text('holder-message'), findsNothing);
                final preempted = records.firstWhere(
                  (r) => r.event == AppSnackBarLogEvent.preempted,
                );
                expect(preempted.fields['holderUnknown'], isFalse);
                expect(preempted.fields['preemptedShowId'], currentHolder!.showId);
                expect(preempted.fields['preemptedLevel'], holderLevel);
                expect(
                  preempted.fields['sameLevelReplace'],
                  decision == 'replaceSameLevel',
                );
              case 'yieldToHolder':
                expect(find.text('holder-message'), findsOneWidget);
                expect(find.text('incoming-message'), findsNothing);
                expect(
                  records.where((r) => r.event == AppSnackBarLogEvent.preempted),
                  isEmpty,
                );
                expect(
                  records.where((r) => r.event == AppSnackBarLogEvent.shown),
                  isEmpty,
                );
                expect(
                  records
                      .where(
                        (r) =>
                            r.event == AppSnackBarLogEvent.closed &&
                            r.fields['reason'] == SnackBarClosedReason.hide,
                      )
                      .isEmpty,
                  isTrue,
                );
                final yielded = records.singleWhere(
                  (r) => r.event == AppSnackBarLogEvent.yielded,
                );
                expect(yielded.fields['holderShowId'], currentHolder!.showId);
                expect(yielded.fields['holderLevel'], holderLevel);
                expect(yielded.fields['level'], newLevel);
                expect(yielded.fields['message'], 'incoming-message');
                expect(yielded.fields['variant'], AppSnackBarVariant.plain);
            }
          },
        );
      }
    }

    testWidgets('T-205-2：讓步事件等級依 origin', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'holder',
        level: AttentionLevel.undroppable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      final holder = AttentionHolderHint(
        showId: showIdOf(
          records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
        ),
        level: AttentionLevel.undroppable,
      );

      for (final origin in [
        AppSnackBarOrigin.background,
        AppSnackBarOrigin.userInitiated,
      ]) {
        records.clear();
        AppSnackBar.show(
          anchor,
          message: 'incoming',
          level: AttentionLevel.discardable,
          currentHolder: holder,
          origin: origin,
        );
        await tester.pump();
        final yielded = records.singleWhere(
          (r) => r.event == AppSnackBarLogEvent.yielded,
        );
        expect(
          yielded.level,
          origin == AppSnackBarOrigin.background ? 900 : 800,
          reason: '0.1.0-W3-205 T-205-2：鍵是 origin 不是 variant——與 '
              'SPEC-003〈截斷事件的日誌等級〉同一判準。',
        );
      }
    });

    testWidgets('T-205-3：讓步不排隊', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'holder',
        level: AttentionLevel.undroppable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      final holder = AttentionHolderHint(
        showId: showIdOf(
          records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
        ),
        level: AttentionLevel.undroppable,
      );
      records.clear();

      AppSnackBar.show(
        anchor,
        message: 'yielded-message',
        level: AttentionLevel.discardable,
        currentHolder: holder,
      );
      await tester.pump();
      expect(
        records.where((r) => r.event == AppSnackBarLogEvent.yielded),
        hasLength(1),
      );

      await _pumpBy(
        tester,
        Motion.snackBarWithAction + _materialTransition * 2,
      );

      expect(find.text('yielded-message'), findsNothing);
      expect(
        records
            .where((r) => r.event == AppSnackBarLogEvent.shown)
            .any((r) => r.fields['message'] == 'yielded-message'),
        isFalse,
      );
      expect(
        records.where((r) => r.event == AppSnackBarLogEvent.yielded),
        hasLength(1),
        reason: '0.1.0-W3-205 T-205-3：被讓步的訊息不重送、不延後呈現、'
            '不排隊。',
      );
    });

    testWidgets('T-205-4：讓步的裁決對 variant 不敏感', (tester) async {
      for (final variant in [
        AppSnackBarVariant.plain,
        AppSnackBarVariant.withAction,
      ]) {
        await pumpHarness(tester, child: anchorHarness());
        final anchor = tester.element(find.byKey(anchorKey));
        records.clear();

        AppSnackBar.show(
          anchor,
          message: 'holder',
          level: AttentionLevel.undroppable,
        );
        await tester.pump();
        await _pumpBy(tester, _materialTransition);
        final holder = AttentionHolderHint(
          showId: showIdOf(
            records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
          ),
          level: AttentionLevel.undroppable,
        );
        records.clear();

        AppSnackBar.show(
          anchor,
          message: 'incoming',
          level: AttentionLevel.discardable,
          currentHolder: holder,
          variant: variant,
          actionLabel: variant == AppSnackBarVariant.withAction
              ? 'action-label'
              : null,
          onAction: variant == AppSnackBarVariant.withAction ? () {} : null,
        );
        await tester.pump();

        expect(
          records.where((r) => r.event == AppSnackBarLogEvent.yielded),
          hasLength(1),
          reason: '0.1.0-W3-205 T-205-4：裁決對 variant 不敏感（$variant '
              '仍讓步），與 T-205-17 的靜態檢查構成雙重確認。',
        );
        expect(
          records.where((r) => r.event == AppSnackBarLogEvent.shown),
          isEmpty,
        );

        await _pumpBy(tester, Motion.snackBar * 2);
      }
    });

    testWidgets('T-205-5：yielded 五鍵齊全且皆非 null', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'holder',
        level: AttentionLevel.undroppable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      final holder = AttentionHolderHint(
        showId: showIdOf(
          records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
        ),
        level: AttentionLevel.undroppable,
      );
      records.clear();

      AppSnackBar.show(
        anchor,
        message: 'incoming-message',
        level: AttentionLevel.discardable,
        currentHolder: holder,
      );
      await tester.pump();

      final yielded = records.singleWhere(
        (r) => r.event == AppSnackBarLogEvent.yielded,
      );
      for (final key in [
        'level',
        'holderShowId',
        'holderLevel',
        'variant',
        'message',
      ]) {
        expect(
          yielded.fields[key],
          isNotNull,
          reason: '0.1.0-W3-205 T-205-5：yielded 五鍵（$key）皆須非 null'
              '——被丟棄的告知不得只留事件類型而無內容。',
        );
      }
      expect(yielded.fields['message'], 'incoming-message');
    });

    testWidgets('T-205-6：過渡缺口可搜尋——holderUnknown 鍵恆存在、值二分', (
      tester,
    ) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));
      expect(records, isEmpty);

      AppSnackBar.show(
        anchor,
        message: 'unknown-holder',
        level: AttentionLevel.discardable,
      );
      await tester.pump();

      final preempted = records.singleWhere(
        (r) => r.event == AppSnackBarLogEvent.preempted,
      );
      expect(
        preempted.fields.containsKey('holderUnknown'),
        isTrue,
        reason: '0.1.0-W3-205 T-205-6：holderUnknown 鍵恆存在。',
      );
      expect(preempted.fields['holderUnknown'], isTrue);
    });

    testWidgets('T-205-7：preemptedShowId 與被截斷者自身 closed 的 showId 一致', (
      tester,
    ) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'holder',
        level: AttentionLevel.discardable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      final holderShowId = showIdOf(
        records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
      );
      records.clear();

      AppSnackBar.show(
        anchor,
        message: 'incoming',
        level: AttentionLevel.undroppable,
        currentHolder: AttentionHolderHint(
          showId: holderShowId,
          level: AttentionLevel.discardable,
        ),
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );

      final preempted = records.singleWhere(
        (r) => r.event == AppSnackBarLogEvent.preempted,
      );
      expect(preempted.fields['preemptedShowId'], holderShowId);
      final hideClosed = records.singleWhere(
        (r) =>
            r.event == AppSnackBarLogEvent.closed &&
            r.fields['reason'] == SnackBarClosedReason.hide,
      );
      expect(showIdOf(hideClosed), holderShowId);
    });

    testWidgets('T-205-8：context 已卸載時裁決不執行', (tester) async {
      late BuildContext capturedContext;
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(capturedContext.mounted, isFalse);

      AppSnackBar.show(
        capturedContext,
        message: 'unused',
        level: AttentionLevel.undroppable,
        currentHolder: const AttentionHolderHint(
          showId: 1,
          level: AttentionLevel.discardable,
        ),
      );

      expect(records, hasLength(1));
      expect(records.single.event, AppSnackBarLogEvent.skippedUnmounted);
      expect(records.single.level, 900);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('T-205-9：持有者快照已失效仍依級別讓步', (tester) async {
      await pumpHarness(tester, child: anchorHarness());
      final anchor = tester.element(find.byKey(anchorKey));

      AppSnackBar.show(
        anchor,
        message: 'holder',
        level: AttentionLevel.undroppable,
      );
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      final holderShowId = showIdOf(
        records.singleWhere((r) => r.event == AppSnackBarLogEvent.shown),
      );
      await _pumpBy(
        tester,
        Motion.snackBar + _materialTransition + _materialTransition,
      );
      expect(find.byType(SnackBar), findsNothing);
      records.clear();

      AppSnackBar.show(
        anchor,
        message: 'incoming',
        level: AttentionLevel.discardable,
        currentHolder: AttentionHolderHint(
          showId: holderShowId,
          level: AttentionLevel.undroppable,
        ),
      );
      await tester.pump();

      expect(
        records.where((r) => r.event == AppSnackBarLogEvent.yielded),
        hasLength(1),
      );
      expect(
        records.where((r) => r.event == AppSnackBarLogEvent.shown),
        isEmpty,
      );
    });
  });

  group('動作 slot 與回呼順序（0.1.0-W3-205 G-C）', () {
    late AppSnackBarLogSink originalSink;
    final records = <_SnackBarLogRecord>[];

    setUp(() {
      originalSink = AppSnackBar.logSink;
      records.clear();
      AppSnackBar.logSink = (event, fields, {level}) {
        records.add((event: event, fields: Map.of(fields), level: level));
      };
    });

    tearDown(() {
      AppSnackBar.logSink = originalSink;
    });

    testWidgets('T-205-10：動作按下的事件序與 hide 先於 onAction', (tester) async {
      var actionCalledAfterHide = false;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () {
            actionCalledAfterHide = records.any(
              (r) => r.event == AppSnackBarLogEvent.actionPressed,
            );
          },
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);
      expect(find.byKey(_snackBarActionKey), findsOneWidget);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition + _materialTransition);

      expect(
        records.map((r) => r.event),
        containsAllInOrder([
          AppSnackBarLogEvent.actionPressed,
          AppSnackBarLogEvent.closed,
        ]),
      );
      final closedRecord = records.singleWhere(
        (r) =>
            r.event == AppSnackBarLogEvent.closed &&
            r.fields['reason'] == SnackBarClosedReason.action,
      );
      expect(closedRecord.fields['reason'], SnackBarClosedReason.action);
      expect(
        actionCalledAfterHide,
        isTrue,
        reason: '0.1.0-W3-205 T-205-10：onAction 的呼叫時點應在 hide('
            'reason: action) 之後。',
      );
    });

    testWidgets('T-205-11：onAction 同步再顯示不被誤殺', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'first-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () {
            AppSnackBar.show(
              tester.element(find.byKey(_triggerActionKey)),
              message: 'second-message',
              level: AttentionLevel.discardable,
            );
          },
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition * 2);

      final closedRecords = records
          .where((r) => r.event == AppSnackBarLogEvent.closed)
          .toList();
      final firstShowId = records
          .firstWhere((r) => r.event == AppSnackBarLogEvent.shown)
          .fields['showId'];
      final firstClosed = closedRecords.singleWhere(
        (r) => r.fields['showId'] == firstShowId,
      );
      // 舊 showId 應恰被關閉一次（改序後由 action 觸發的清除搶先發生，實際
      // 完成原因可能因 Material 內部動畫控制器重入而記為 hide——這是框架層
      // 的競態，非本票控制範圍；核心不變式是「新 showId 不得被 action
      // 誤殺」，見下方斷言）。
      expect(firstClosed.fields['showId'], firstShowId);
      final secondShown = records
          .where((r) => r.event == AppSnackBarLogEvent.shown)
          .toList();
      expect(secondShown, hasLength(2));
      final secondClosed = closedRecords.where(
        (r) => r.fields['showId'] == secondShown[1].fields['showId'],
      );
      expect(
        secondClosed.any((r) => r.fields['reason'] == SnackBarClosedReason.action),
        isFalse,
        reason: '0.1.0-W3-205 T-205-11：新 showId 的 closed 不得帶 '
            'reason: action。',
      );
      expect(
        find.text('second-message'),
        findsOneWidget,
        reason: '0.1.0-W3-205 T-205-11：改序前的形態（新的一則被 '
            'reason: action 無聲關掉）即為紅燈——新訊息文字應在退場動畫走完'
            '後仍可見。',
      );
      await _pumpBy(tester, Motion.snackBar * 2);
    });

    testWidgets('T-205-12：onAction 未 await 同步段不顯示則不受影響（現況鎖定）', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () {
            // 模擬 gap_report_screen.dart:199 形態：回傳 Future 但不 await，
            // 同步段本身不顯示任何 SnackBar。
            Future<void>.delayed(Duration.zero);
          },
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, _materialTransition);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, _materialTransition * 2);

      final closedRecords = records
          .where((r) => r.event == AppSnackBarLogEvent.closed)
          .toList();
      expect(closedRecords, hasLength(1));
      expect(closedRecords.single.fields['reason'], SnackBarClosedReason.action);
      final showIds = records
          .where((r) => r.event == AppSnackBarLogEvent.shown)
          .map((r) => r.fields['showId'])
          .toSet();
      expect(showIds, hasLength(1));
    });

    testWidgets('T-205-13：withAction 缺 slot 仍觸發既有 assert', (tester) async {
      late BuildContext anchorContext;
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) {
            anchorContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(
        () => AppSnackBar.show(
          anchorContext,
          message: 'x',
          level: AttentionLevel.discardable,
          variant: AppSnackBarVariant.withAction,
        ),
        throwsA(isA<AssertionError>()),
        reason: '0.1.0-W3-205 T-205-13：必填 level 的加入不得改變本斷言的'
            '觸發條件——level 為編譯期必填，不產生執行期分支。',
      );
    });
  });
}
