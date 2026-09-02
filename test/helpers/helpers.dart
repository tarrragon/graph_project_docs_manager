/// 測試基座單一入口。
///
/// 元件票與畫面票只需 `import '../helpers/helpers.dart';`（相對於
/// `test/widget/<dir>/`）即取得全部基座：
///
/// | 模組 | 提供 |
/// |------|------|
/// | `window_sizes.dart` | [WindowSize]（min / design）、[setWindowSize]、[testWidgetsAtEachSize] |
/// | `pump_harness.dart` | [pumpHarness]（狀態注入 + 渲染）、[pumpApp]、[pumpContract]、[expectNoOverflow]、[kTestLocales] |
/// | `anchors.dart` | [Screen]、[Anchor]（組 Key）、[AnchorFinder]（組 Finder） |
/// | `test_copy.dart` | [TestCopy] 最長文案常數（SPEC-004 §4.0.4） |
library;

export 'anchors.dart';
export 'pump_harness.dart';
export 'test_copy.dart';
export 'window_sizes.dart';
