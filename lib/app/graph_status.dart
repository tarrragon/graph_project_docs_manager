/// 專案未就緒的原因（App 層共用值；SPEC-001 §1 之後的「專案未就緒」共用
/// 定義；`0.1.0-W3-335.37` R9；`0.3.3-W3-389` 由 bool 改為帶原因）。
///
/// 五個非 Domain 畫面（UC Flow、追溯視圖、Ticket 清單、破洞報告、節點詳情）
/// 共用同一個判斷：Domain 視圖是否已建立圖，未建立時原因為何（未選專案、
/// 載入中、或三個阻擋狀態之一）。0.1 不接真實 workspace 狀態與圖建置整合
/// （CLAUDE.md §6「跨邊界驗證是正交屬性」現況盤點），本 provider 只提供
/// 接線點：預設 `null`（圖已建立），使既有畫面行為不變；真實整合落地後改為
/// 依 workspace 狀態與 Domain 視圖建置進度計算原因。測試以
/// `projectUnreadyReasonProvider.overrideWithValue(<原因>)` 驗證「未就緒」
/// 分支。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「專案未就緒」的三個原因（SPEC-001 共用定義，`0.1.0-W3-335.37` R9）。
enum ProjectUnreadyReason {
  /// Domain 視圖尚未選擇專案。
  notSelected,

  /// Domain 視圖圖譜載入中。
  loading,

  /// Domain 視圖處於三個阻擋狀態之一（不是框架專案／無可消費的型別表／
  /// schema 不相容），畫面不區分三者，統一顯示「此專案不適用本 App」。
  incompatible,
}

/// 專案未就緒的原因；`null` 表 Domain 視圖已建立圖。
final projectUnreadyReasonProvider = Provider<ProjectUnreadyReason?>(
  (ref) => null,
);
