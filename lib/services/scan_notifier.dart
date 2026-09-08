/// 掃描完成的系統層通知抽象（SPEC-003 §2.2「系統層通知」「介面」）。
///
/// 查詢、請求、發送、撤回四個動作由同一個可注入的抽象承擔，畫面層只消費
/// [ScanNotifier.activated] 串流執行「點擊通知的導向」列的行為；三個授權
/// 值以外的平台結果（`provisional`、查詢或請求逾時／拋錯、API 不可用）由
/// 實作端在抽象邊界內收斂為 [NotificationAuthorization.denied]，不外洩至
/// 畫面層（權限 gate「其他」列）。
library;

/// macOS 通知授權狀態（SPEC-003 §2.2 權限 gate 三路徑）。
enum NotificationAuthorization {
  /// 尚未詢問：於首次觸發條件成立時請求。
  notDetermined,

  /// 已授權：可發送系統通知。
  granted,

  /// 已拒絕（或其他不確定結果收斂而來）：走 App 內 SnackBar fallback。
  denied,
}

/// 掃描完成通知的內容（SPEC-003 §2.2「通知內容」列）。
class ScanCompleteNotification {
  const ScanCompleteNotification({required this.gapCount});

  /// 破洞總數。0 表示無破洞，對應 `scanCompleteNoGapsNotificationBody`。
  final int gapCount;
}

/// 掃描完成的系統層通知抽象（SPEC-003 §2.2）。
abstract class ScanNotifier {
  /// 查詢目前授權狀態，於**每次**觸發條件成立時呼叫（不快取上一次結果）。
  Future<NotificationAuthorization> authorizationStatus();

  /// 請求授權：僅於 [NotificationAuthorization.notDetermined] 時、首次
  /// 觸發條件成立的當下呼叫一次。
  Future<NotificationAuthorization> requestAuthorization();

  /// 發送掃描完成通知。
  Future<void> show(ScanCompleteNotification notification);

  /// 撤回尚未被點擊的通知；無通知時為 no-op。撤回失敗不阻擋、不轉狀態
  /// （SPEC-003 §2.2「不重複發送」列）。
  Future<void> withdraw();

  /// 使用者點擊通知本體時發出的事件。
  Stream<void> get activated;
}
