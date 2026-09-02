// 契約測試：lib/tokens/motion.dart 的十個 Duration token（SPEC-003 §2.1）。
//
// 涵蓋範圍：
// 1. 每個 token 值回溯 SPEC-003 §2.1 表列值。
// 2. disableAnimations 為 true 時，三個動畫類 token 回傳 Duration.zero；
//    七個契約類 token 維持原值（SPEC-003 §2.1「減少動態效果」規則）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

/// 以指定的 disableAnimations 值包裹 [child]，供動畫類 token 求值。
Widget _wrapWithDisableAnimations({
  required bool disableAnimations,
  required Widget child,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  group('Motion 契約類 token 回溯 SPEC-003 §2.1', () {
    test('feedback 回溯 100 ms', () {
      expect(Motion.feedback, const Duration(milliseconds: 100));
    });

    test('spinnerMinVisible 回溯 300 ms', () {
      expect(Motion.spinnerMinVisible, const Duration(milliseconds: 300));
    });

    test('cancelDeadline 回溯 500 ms', () {
      expect(Motion.cancelDeadline, const Duration(milliseconds: 500));
    });

    test('progressTick 回溯 200 ms', () {
      expect(Motion.progressTick, const Duration(milliseconds: 200));
    });

    test('snackBar 回溯 4 s', () {
      expect(Motion.snackBar, const Duration(seconds: 4));
    });

    test('snackBarWithAction 回溯 8 s', () {
      expect(Motion.snackBarWithAction, const Duration(seconds: 8));
    });

    test('searchDebounce 回溯 300 ms', () {
      expect(Motion.searchDebounce, const Duration(milliseconds: 300));
    });
  });

  group('Motion 動畫類 token（依 context 求值）回溯 SPEC-003 §2.1', () {
    testWidgets('transition 於 disableAnimations=false 回溯 150 ms', (
      tester,
    ) async {
      late Duration value;
      await tester.pumpWidget(
        _wrapWithDisableAnimations(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              value = Motion.transition(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(value, const Duration(milliseconds: 150));
    });

    testWidgets('overlay 於 disableAnimations=false 回溯 200 ms', (
      tester,
    ) async {
      late Duration value;
      await tester.pumpWidget(
        _wrapWithDisableAnimations(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              value = Motion.overlay(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(value, const Duration(milliseconds: 200));
    });

    testWidgets('skeletonCycle 於 disableAnimations=false 回溯 1200 ms', (
      tester,
    ) async {
      late Duration value;
      await tester.pumpWidget(
        _wrapWithDisableAnimations(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              value = Motion.skeletonCycle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(value, const Duration(milliseconds: 1200));
    });
  });

  group('disableAnimations=true：動畫類歸零、契約類不歸零', () {
    testWidgets('transition/overlay/skeletonCycle 皆為 Duration.zero', (
      tester,
    ) async {
      late Duration transition;
      late Duration overlay;
      late Duration skeletonCycle;
      await tester.pumpWidget(
        _wrapWithDisableAnimations(
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              transition = Motion.transition(context);
              overlay = Motion.overlay(context);
              skeletonCycle = Motion.skeletonCycle(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(transition, Duration.zero);
      expect(overlay, Duration.zero);
      expect(skeletonCycle, Duration.zero);
    });

    test('七個契約類 token 維持原值（不受 disableAnimations 影響）', () {
      expect(Motion.feedback, const Duration(milliseconds: 100));
      expect(Motion.spinnerMinVisible, const Duration(milliseconds: 300));
      expect(Motion.cancelDeadline, const Duration(milliseconds: 500));
      expect(Motion.progressTick, const Duration(milliseconds: 200));
      expect(Motion.snackBar, const Duration(seconds: 4));
      expect(Motion.snackBarWithAction, const Duration(seconds: 8));
      expect(Motion.searchDebounce, const Duration(milliseconds: 300));
    });
  });
}
