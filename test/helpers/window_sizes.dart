/// 測試視窗尺寸集合（SPEC-004 §1「測試尺寸集合」）。
///
/// 兩種：`kMinWindowSize`（macOS `minSize`，最嚴苛）與 `kDesignSize`
/// （設計基準，ScreenUtil 係數 1.0）。數值不在此複述，引用 `lib/main.dart`
/// 常數，Swift 端與 Dart 端一致性另由 `test/window_size_contract_test.dart`
/// 守住。不加入第三種尺寸：SPEC-004 §1 核定「填滿父容器的元件以最大尺寸
/// 契約承載拉伸上限」，第三種尺寸無專案決策來源。
///
/// 整合測試（`integration_test/app_test.dart`）另有四尺寸 `kViewports`，
/// 那是畫面級整合驗收；元件 widget test 依 SPEC-004 §4.0.5 只跑本檔兩種。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/main.dart';

/// 一種測試視窗尺寸。[name] 進測試描述，讓紅燈直接指出是哪個尺寸。
enum WindowSize {
  /// 視窗下限（macOS `minSize`）。水平溢位最先在這裡出現。
  min('min', kMinWindowSize),

  /// 設計基準（預設視窗尺寸），縮放係數 1.0。
  design('design', kDesignSize);

  const WindowSize(this.name, this.size);

  /// 測試描述用的短名。
  final String name;

  /// 邏輯像素尺寸。
  final Size size;

  /// 描述用字串，例：`min(960x640)`。
  String get label =>
      '$name(${size.width.toInt()}x${size.height.toInt()})';
}

/// 把 [tester] 的視窗設為 [windowSize]，並登記 tearDown 還原。
///
/// devicePixelRatio 固定 1.0：SPEC-004 §1 的尺寸契約以邏輯像素書寫，
/// dpr 只影響點陣資源挑選，對溢位與否無影響（`integration_test` 同一結論）。
/// 每次呼叫都 `addTearDown(reset)`，同一測試內多次切換尺寸也安全。
void setWindowSize(WidgetTester tester, WindowSize windowSize) {
  tester.view.physicalSize = windowSize.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 對兩種尺寸各註冊一支 `testWidgets`，描述為 `<description> @ <label>`。
///
/// 兩種尺寸拆成獨立測試而非在同一支內迴圈：紅燈時測試名直接指出尺寸，
/// 且一種尺寸失敗不遮蔽另一種的結果。
///
/// ```dart
/// testWidgetsAtEachSize('AppText.title 不溢位', (tester, size) async {
///   await pumpHarness(tester, child: ..., size: size);
///   expect(tester.takeException(), isNull);
/// });
/// ```
void testWidgetsAtEachSize(
  String description,
  Future<void> Function(WidgetTester tester, WindowSize size) body, {
  Iterable<WindowSize> sizes = WindowSize.values,
  bool? skip,
}) {
  for (final size in sizes) {
    testWidgets(
      '$description @ ${size.label}',
      (tester) => body(tester, size),
      skip: skip,
    );
  }
}
