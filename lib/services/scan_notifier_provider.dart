/// [ScanNotifier] 的 Riverpod 掛點（SPEC-003 §2.2「介面」）。
///
/// 正式路徑供 [MacosScanNotifier]；測試以 `overrideWithValue` /
/// `overrideWith` 注入 fake，畫面層與 controller 只依賴 [ScanNotifier]
/// 抽象，不知道底下是原生載體還是測試替身。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'macos_scan_notifier.dart';
import 'scan_notifier.dart';

final scanNotifierProvider = Provider<ScanNotifier>((ref) {
  return MacosScanNotifier();
});
