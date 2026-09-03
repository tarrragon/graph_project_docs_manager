/// BlockedState 元件測試（SPEC-004 4.23）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';

import '../../helpers/helpers.dart';

void main() {
  const plainKey = ValueKey('state-domain-not-framework');
  const withDetailKey = ValueKey('state-domain-schema-incompatible');
  const switchKey = ValueKey('action-domain-switch-project');
  const detailButtonKey = ValueKey('action-domain-schema-detail');
  const detailPanelKey = ValueKey('panel-domain-schema-detail');

  group('變體與狀態矩陣：plain（版本值有／無、說明有／無）', () {
    testWidgetsAtEachSize('plain 全欄位（訊息＋說明＋版本值）不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: BlockedState.plain(
          message: TestCopy.longZh,
          explanation: TestCopy.longEn,
          version: TestCopy.longToken,
          onSwitchProject: () {},
          testKey: plainKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(plainKey), findsOneWidget);
      expect(find.byKey(switchKey), findsOneWidget);
      expect(find.byKey(detailButtonKey), findsNothing);
    });

    testWidgetsAtEachSize('plain 缺說明與版本值（僅必填訊息）不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: BlockedState.plain(
          message: 'schema unavailable',
          onSwitchProject: () {},
          testKey: plainKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(plainKey), findsOneWidget);
    });
  });

  group('變體與狀態矩陣：withDetail（collapsed / expanded）', () {
    testWidgetsAtEachSize('withDetail collapsed 不渲染詳情面板且不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: BlockedState.withDetail(
          message: TestCopy.longZh,
          explanation: TestCopy.longEn,
          appVersion: TestCopy.longToken,
          projectVersion: TestCopy.longToken,
          onSwitchProject: () {},
          isDetailExpanded: false,
          onToggleDetail: () {},
          testKey: withDetailKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(withDetailKey), findsOneWidget);
      expect(find.byKey(detailButtonKey), findsOneWidget);
      expect(find.byKey(detailPanelKey), findsNothing);
    });

    testWidgetsAtEachSize('withDetail expanded 渲染詳情面板兩值且不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: BlockedState.withDetail(
          message: TestCopy.longZh,
          appVersion: TestCopy.longToken,
          projectVersion: TestCopy.longToken,
          onSwitchProject: () {},
          isDetailExpanded: true,
          onToggleDetail: () {},
          testKey: withDetailKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(detailPanelKey), findsOneWidget);
      expect(find.text(TestCopy.longToken), findsNWidgets(2));
    });
  });

  group('互動反應：切換專案、檢視詳情、Esc 收合', () {
    testWidgets('切換專案呼叫 onSwitchProject 恰一次', (tester) async {
      var count = 0;
      await pumpHarness(
        tester,
        child: BlockedState.plain(
          message: 'msg',
          onSwitchProject: () => count++,
          testKey: plainKey,
        ),
      );

      await tester.tap(find.byKey(switchKey));
      await tester.pumpAndSettle();

      expect(count, 1);
    });

    testWidgets('檢視詳情切換 panel-domain-schema-detail 存在性', (tester) async {
      var expanded = false;
      await pumpHarness(
        tester,
        child: _StatefulHarness(
          builder: (context, toggle) => BlockedState.withDetail(
            message: 'msg',
            appVersion: '1.0.0',
            projectVersion: '2.0.0',
            onSwitchProject: () {},
            isDetailExpanded: expanded,
            onToggleDetail: () => toggle(() => expanded = !expanded),
            testKey: withDetailKey,
          ),
        ),
      );

      expect(find.byKey(detailPanelKey), findsNothing);

      await tester.tap(find.byKey(detailButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(detailPanelKey), findsOneWidget);
    });

    testWidgets('expanded 下 Esc 收合', (tester) async {
      var expanded = true;
      await pumpHarness(
        tester,
        child: _StatefulHarness(
          builder: (context, toggle) => BlockedState.withDetail(
            message: 'msg',
            appVersion: '1.0.0',
            projectVersion: '2.0.0',
            onSwitchProject: () {},
            isDetailExpanded: expanded,
            onToggleDetail: () => toggle(() => expanded = !expanded),
            testKey: withDetailKey,
          ),
        ),
      );
      expect(find.byKey(detailPanelKey), findsOneWidget);

      // 直接請求子樹內按鈕的焦點（不觸發 onPressed），確保按鍵事件從本元件
      // 子樹的 primaryFocus 往上冒泡至 BlockedState 的 onKeyEvent。
      Focus.of(tester.element(find.byKey(detailButtonKey))).requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(detailPanelKey), findsNothing);
    });
  });

  group('組合規則：動作列由 ButtonRow 承載（SPEC-004 4.34 型別限定）', () {
    testWidgets('plain 動作列存在 ButtonRow 且無本地 Wrap 繞道', (tester) async {
      await pumpHarness(
        tester,
        child: BlockedState.plain(
          message: 'msg',
          onSwitchProject: () {},
          testKey: plainKey,
        ),
      );

      // ButtonRow 內部以單一 Wrap 排列子件（SPEC-004 4.34）；本斷言確認
      // 只有 ButtonRow 自身的 Wrap，無 blocked_state.dart 本地繞道的第二個。
      expect(find.byType(ButtonRow), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('withDetail 動作列存在 ButtonRow 且無本地 Wrap 繞道', (tester) async {
      await pumpHarness(
        tester,
        child: BlockedState.withDetail(
          message: 'msg',
          appVersion: '1.0.0',
          projectVersion: '2.0.0',
          onSwitchProject: () {},
          isDetailExpanded: false,
          onToggleDetail: () {},
          testKey: withDetailKey,
        ),
      );

      // ButtonRow 內部以單一 Wrap 排列子件（SPEC-004 4.34）；本斷言確認
      // 只有 ButtonRow 自身的 Wrap，無 blocked_state.dart 本地繞道的第二個。
      expect(find.byType(ButtonRow), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('withDetail 檢視詳情鈕 expanded 語意等於 isDetailExpanded', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: BlockedState.withDetail(
          message: 'msg',
          appVersion: '1.0.0',
          projectVersion: '2.0.0',
          onSwitchProject: () {},
          isDetailExpanded: true,
          onToggleDetail: () {},
          testKey: withDetailKey,
        ),
      );

      final semantics = tester.getSemantics(find.byKey(detailButtonKey));
      expect(semantics.flagsCollection.isExpanded.toBoolOrNull(), isTrue);

      handle.dispose();
    });
  });

  group('i18n：zh / en 四個訊息 key 皆不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('plain @ ${locale.languageCode}', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: BlockedState.plain(
            message: TestCopy.longZh,
            explanation: TestCopy.longEn,
            onSwitchProject: () {},
            testKey: plainKey,
          ),
        );
        expectNoOverflow(tester);
      });

      testWidgets('withDetail expanded @ ${locale.languageCode}', (
        tester,
      ) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: BlockedState.withDetail(
            message: TestCopy.longZh,
            appVersion: TestCopy.longToken,
            projectVersion: TestCopy.longToken,
            onSwitchProject: () {},
            isDetailExpanded: true,
            onToggleDetail: () {},
            testKey: withDetailKey,
          ),
        );
        expectNoOverflow(tester);
      });
    }
  });
}

/// 最小可變狀態外殼：讓 [BlockedState.withDetail] 的展開態測試能重建 widget
/// 樹以觀察呼叫端狀態轉換（SPEC-004 §2 傳值 + callback 慣例）。
class _StatefulHarness extends StatefulWidget {
  const _StatefulHarness({required this.builder});

  final Widget Function(BuildContext context, void Function(VoidCallback) setState)
  builder;

  @override
  State<_StatefulHarness> createState() => _StatefulHarnessState();
}

class _StatefulHarnessState extends State<_StatefulHarness> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context, setState);
  }
}
