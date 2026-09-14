/// 圖是否已建立（App 層共用值；SPEC-001 §1 之後的「專案未就緒」共用定義；
/// `0.1.0-W3-335.37` R9）。
///
/// 五個非 Domain 畫面（UC Flow、追溯視圖、Ticket 清單、破洞報告、節點詳情）
/// 共用同一個判斷：Domain 視圖是否已建立圖（未選專案、載入中、或三個
/// 阻擋狀態之一時圖尚未建立）。0.1 不接真實 workspace 狀態與圖建置整合
/// （CLAUDE.md §6「跨邊界驗證是正交屬性」現況盤點），本 provider 只提供
/// 接線點：預設「已建立」，使既有畫面行為不變；真實整合落地後改為依
/// workspace 狀態與 Domain 視圖建置進度計算。測試以
/// `graphBuiltProvider.overrideWithValue(false)` 驗證「未就緒」分支。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Domain 視圖是否已建立圖。
final graphBuiltProvider = Provider<bool>((ref) => true);
