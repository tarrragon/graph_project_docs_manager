import Cocoa
import FlutterMacOS
import UserNotifications

/// 掃描完成系統通知的 `MethodChannel` 名稱，須與
/// `lib/services/macos_scan_notifier.dart` 的 `scanNotifierChannelName`
/// 一致（SPEC-003 §2.2「介面」）。
private let scanNotifierChannelName = "graph_project_docs_manager/scan_notifier"

/// 掃描完成通知的識別碼：每次 `show` 覆蓋前一則，天然滿足「每次掃描完成
/// 至多發送一則」（SPEC-003 §2.2「不重複發送」列）。
private let scanCompleteNotificationIdentifier = "scan-complete-notification"

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  private var scanNotifierChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    UNUserNotificationCenter.current().delegate = self
    let channel = FlutterMethodChannel(
      name: scanNotifierChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    scanNotifierChannel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        result(Self.authorizationString(for: settings.authorizationStatus))
      }
    case "requestAuthorization":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
        result(granted ? "granted" : "denied")
      }
    case "show":
      let args = call.arguments as? [String: Any]
      let title = args?["title"] as? String ?? ""
      let body = args?["body"] as? String ?? ""
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      let request = UNNotificationRequest(
        identifier: scanCompleteNotificationIdentifier,
        content: content,
        trigger: nil
      )
      UNUserNotificationCenter.current().add(request) { _ in
        result(nil)
      }
    case "withdraw":
      UNUserNotificationCenter.current().removeDeliveredNotifications(
        withIdentifiers: [scanCompleteNotificationIdentifier]
      )
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 使用者點擊通知本體（SPEC-003 §2.2「點擊通知的導向」列）。
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier == scanCompleteNotificationIdentifier {
      scanNotifierChannel?.invokeMethod("onActivated", arguments: nil)
    }
    completionHandler()
  }

  private static func authorizationString(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized:
      return "granted"
    case .notDetermined:
      return "notDetermined"
    default:
      return "denied"
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
