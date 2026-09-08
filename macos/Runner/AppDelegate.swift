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

  /// 建立 `scan_notifier` channel 的時機。
  ///
  /// **不可改回 `applicationDidFinishLaunching`**：實測（0.1.0-W3-097）該
  /// callback 在本 app 從未被呼叫——以 `forName: nil` 的全域觀察者掃過整段啟動
  /// 序列，只見 `WillFinishLaunching`、`DidFinishRestoringWindows`、
  /// `WillBecomeActive`、`DidBecomeActive`，`NSApplicationDidFinishLaunching`
  /// 一次都沒有發出。原本掛在該 callback 的註冊因此整段不執行，Dart 端四個方法
  /// 全部拿到 `MissingPluginException`。
  ///
  /// `applicationWillFinishLaunching` 則實測必定執行，且此時 nib 已載入完畢
  /// （`MainFlutterWindow.awakeFromNib` 先於本 callback），`mainFlutterWindow`
  /// 與其 `contentViewController` 皆已就緒——`FlutterAppDelegate` 自己也是在這個
  /// 時點讀 `mainFlutterWindow` 來設定視窗標題。
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    registerScanNotifierChannel()
  }

  /// 取得 `FlutterViewController` 並掛上 channel handler。
  ///
  /// 取不到 controller 時必須留下可見訊號（quality-baseline 規則 4）：這條路徑
  /// 失敗會讓整套系統通知在實機零可用，而 Dart 端依 SPEC-003 §2.2 把
  /// `MissingPluginException` 收斂為 `denied`，畫面上與「使用者拒絕授權」完全同形。
  /// 沒有這行 log，缺陷就只剩 DevTools Logging 裡一行 WARNING 可循。
  private func registerScanNotifierChannel() {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      NSLog(
        "[AppDelegate] 找不到 FlutterViewController，%@ channel 未註冊；"
          + "系統通知（授權查詢／請求／發送／撤回／點擊回傳）將全面失效",
        scanNotifierChannelName)
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
    NSLog("[AppDelegate] %@ channel 已註冊", scanNotifierChannelName)
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
