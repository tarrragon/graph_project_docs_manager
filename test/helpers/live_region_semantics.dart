/// liveRegion 語意斷言的共用基座（SPEC-004 元件 liveRegion 測試點）。
///
/// 只提供「外層容器 pump」「子樹判定」「畫面尺寸比較基準」三項；斷言
/// （`expect`）留在各測試案例內，逐條獨立的案例結構與失敗輸出不受影響。
library;

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_harness.dart';
import 'window_sizes.dart';

/// 以外層 `Semantics(container: true)` 包住 [child] 後渲染。
///
/// 外層 container 模擬畫面層語意容器：未設 container 的 liveRegion 會併入
/// 它（531 傾印實測）。[settle] 為 false 時（含不停動畫的元件）改以一次
/// `pump()` 推進首幀。
Future<void> pumpInSemanticsContainer(
  WidgetTester tester, {
  required Widget child,
  WindowSize size = WindowSize.min,
  bool settle = true,
}) async {
  await pumpHarness(
    tester,
    size: size,
    settle: settle,
    child: Semantics(container: true, child: child),
  );
  if (!settle) await tester.pump();
}

/// [node] 是否位於以 [root] 為根的語意子樹內（含 [root] 自身）。
bool isInSemanticsSubtree(SemanticsNode node, SemanticsNode root) {
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.id == root.id) return true;
  }
  return false;
}

/// 目前視窗的邏輯尺寸，作為「live 節點非全畫面」的比較基準。
///
/// 數值來自呼叫端傳給 pump 的 `size`（[setWindowSize]），此處不寫死。
Size logicalViewSize(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;
