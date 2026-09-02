import 'dart:math' as math;

import 'package:graph_project_docs_manager/tokens/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 相對亮度對比契約測試（SPEC-002 §已知的顏色分佈／無障礙對比調整）。
///
/// 驗證 2026-09-02 對比調整（方案 C）落地後，三組語意色組合達到核定的
/// 對比門檻。公式為 WCAG 2.x 相對亮度公式，非近似值。
void main() {
  group('AppColors 對比契約', () {
    test('textSecondary 對 surfaceBase 達 AA 一般字級（>= 4.5:1）', () {
      final ratio = _contrastRatio(
        AppColors.textSecondary,
        AppColors.surfaceBase,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('textPrimary 對 surfaceSegmentTrack 達 AA 一般字級（>= 4.5:1）', () {
      final ratio = _contrastRatio(
        AppColors.textPrimary,
        AppColors.surfaceSegmentTrack,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('textDisabled 對 surfaceBase 達非文字對比門檻（>= 3.0:1）', () {
      final ratio = _contrastRatio(
        AppColors.textDisabled,
        AppColors.surfaceBase,
      );
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });
}

/// 計算兩色的 WCAG 對比值：`(L1 + 0.05) / (L2 + 0.05)`，L1 為較亮者。
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG 相對亮度公式：sRGB 各通道先線性化，再依 0.2126/0.7152/0.0722 加權。
double _relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearize(double channel) {
  if (channel <= 0.03928) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}
