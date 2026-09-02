// 基座示範：以狀態注入單獨渲染 SPEC-003 §4 的三種狀態並逐列斷言。
//
// 本檔驗的是基座本身（注入 → 渲染 → 觸發錨點 → 斷言目標錨點），不是
// Domain 視圖的業務行為——畫面尚未實作，所以狀態型別與頁面 widget 都是
// 本檔私有的最小替身，只帶 SPEC-003 §2.9 的錨點與 §4 對應列的退出路徑。
// 畫面票落地後，各票以同一套呼叫形式換成真實 provider 與真實頁面即可。
//
// 涵蓋列（SPEC-003 §4）：
//   #3 正常 · 矩陣      state-domain-matrix
//   #8 schema 不相容    state-domain-schema-incompatible（阻擋態）
//   #2 載入中           state-domain-loading → 取消 → #1 state-domain-unset
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';

// ---------------------------------------------------------------------------
// 替身：Domain 視圖的四個狀態與最小頁面
// ---------------------------------------------------------------------------

sealed class _DomainState {
  const _DomainState();
}

class _Unset extends _DomainState {
  const _Unset();
}

class _Loading extends _DomainState {
  const _Loading();
}

class _Matrix extends _DomainState {
  const _Matrix();
}

class _SchemaIncompatible extends _DomainState {
  const _SchemaIncompatible();
}

/// 狀態注入點：測試用 `overrideWith` 指定初始狀態。
final _domainStateProvider = StateProvider<_DomainState>(
  (ref) => const _Unset(),
);

/// 最小頁面：依狀態渲染對應錨點與退出路徑。
class _DomainPageStub extends ConsumerWidget {
  const _DomainPageStub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_domainStateProvider);
    return switch (state) {
      _Unset() => SizedBox(key: Anchor.state(Screen.domain, 'unset')),
      _Matrix() => SizedBox(key: Anchor.state(Screen.domain, 'matrix')),
      _Loading() => _LoadingStub(
          onCancel: () {
            // SPEC-003 §2.5：按下取消後於 cancelDeadline 內抵達未選專案態。
            Timer(Motion.cancelDeadline, () {
              ref.read(_domainStateProvider.notifier).state = const _Unset();
            });
          },
        ),
      _SchemaIncompatible() => const _SchemaIncompatibleStub(),
    };
  }
}

class _LoadingStub extends StatelessWidget {
  const _LoadingStub({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Anchor.state(Screen.domain, 'loading'),
      children: [
        const CircularProgressIndicator(),
        TextButton(
          key: Anchor.action(Screen.domain, 'cancel-load'),
          onPressed: onCancel,
          child: const Text('cancel'),
        ),
      ],
    );
  }
}

/// 阻擋態：浮層入口恆可用（§4 #8），版本詳情面板內展開。
class _SchemaIncompatibleStub extends StatefulWidget {
  const _SchemaIncompatibleStub();

  @override
  State<_SchemaIncompatibleStub> createState() =>
      _SchemaIncompatibleStubState();
}

class _SchemaIncompatibleStubState extends State<_SchemaIncompatibleStub> {
  bool _detailOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Anchor.state(Screen.domain, 'schema-incompatible'),
      children: [
        TextButton(
          key: Anchor.projectSwitcherEntry,
          onPressed: () {},
          child: const Text('switch'),
        ),
        TextButton(
          key: Anchor.action(Screen.domain, 'schema-detail'),
          onPressed: () => setState(() => _detailOpen = true),
          child: const Text('detail'),
        ),
        if (_detailOpen)
          SizedBox(key: Anchor.panel(Screen.domain, 'schema-detail')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 示範測試
// ---------------------------------------------------------------------------

void main() {
  group('正常態 #3 state-domain-matrix', () {
    testWidgetsAtEachSize('注入後直接渲染矩陣態', (tester, size) async {
      await pumpHarness(
        tester,
        child: const _DomainPageStub(),
        overrides: [
          _domainStateProvider.overrideWith((ref) => const _Matrix()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
      expect(AnchorFinder.state(Screen.domain, 'loading'), findsNothing);
      expectNoOverflow(tester);
    });
  });

  group('阻擋態 #8 state-domain-schema-incompatible', () {
    testWidgetsAtEachSize('注入後渲染阻擋態，浮層入口可用', (tester, size) async {
      await pumpHarness(
        tester,
        child: const _DomainPageStub(),
        overrides: [
          _domainStateProvider.overrideWith(
            (ref) => const _SchemaIncompatible(),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'schema-incompatible'),
        findsOneWidget,
      );
      final entry = tester.widget<TextButton>(
        AnchorFinder.projectSwitcherEntry,
      );
      expect(entry.enabled, isTrue, reason: '§4 #8：浮層入口 enabled 恆為 true');
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-schema-detail → panel-domain-schema-detail',
        (tester) async {
      await pumpHarness(
        tester,
        child: const _DomainPageStub(),
        overrides: [
          _domainStateProvider.overrideWith(
            (ref) => const _SchemaIncompatible(),
          ),
        ],
      );
      expect(AnchorFinder.panel(Screen.domain, 'schema-detail'), findsNothing);

      await tester.tap(AnchorFinder.action(Screen.domain, 'schema-detail'));
      await tester.pumpAndSettle();

      expect(
        AnchorFinder.panel(Screen.domain, 'schema-detail'),
        findsOneWidget,
      );
    });
  });

  group('載入態 #2 state-domain-loading', () {
    testWidgetsAtEachSize('注入後渲染載入態（含無限動畫，settle: false）',
        (tester, size) async {
      await pumpHarness(
        tester,
        child: const _DomainPageStub(),
        overrides: [
          _domainStateProvider.overrideWith((ref) => const _Loading()),
        ],
        size: size,
        settle: false,
      );

      expect(AnchorFinder.state(Screen.domain, 'loading'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-cancel-load → cancelDeadline 內抵達 state-domain-unset',
        (tester) async {
      final container = await pumpHarness(
        tester,
        child: const _DomainPageStub(),
        overrides: [
          _domainStateProvider.overrideWith((ref) => const _Loading()),
        ],
        settle: false,
      );

      await tester.tap(AnchorFinder.action(Screen.domain, 'cancel-load'));
      // 時限走假時鐘（Motion 契約類 token），不量測真實耗時。
      await pumpContract(tester, Motion.cancelDeadline);
      await tester.pump();

      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(AnchorFinder.state(Screen.domain, 'loading'), findsNothing);
      expect(container.read(_domainStateProvider), isA<_Unset>());
    });
  });
}
