import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 視窗尺寸下限。桌面視窗可被使用者拖到任意小，這是版面不跑版的第一道
  /// 防線 —— 沒有它，任何 layout 都能被拉爆。
  ///
  /// 這組數值必須與 Dart 端 `kMinWindowSize`（lib/main.dart）保持一致：
  /// 整合測試以 Dart 端的值為驗收下限，若此處放得更寬鬆，就會出現
  /// 「測試綠燈但實機拉窄後跑版」的破口。
  static let minimumSize = NSSize(width: 960, height: 640)

  /// 首次啟動的視窗尺寸，同時也是 Dart 端的設計稿基準
  /// （`kDesignSize`），使開發時所見即 1:1 設計稿。
  static let defaultSize = NSSize(width: 1280, height: 800)

  private let bookmarkHandler = SecureBookmarkHandler()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.minSize = MainFlutterWindow.minimumSize
    self.setContentSize(MainFlutterWindow.defaultSize)
    self.center()

    let channel = FlutterMethodChannel(
      name: SecureBookmarkHandler.channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.bookmarkHandler.handle(call, result: result)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

/// 以 security-scoped bookmark 提供「跨 App 啟動」的資料夾存取授權。
///
/// App Sandbox 下，使用者透過開啟面板選取的資料夾只在該次執行期間有效。
/// 要讓授權活過重新啟動，必須把 URL 序列化成 security-scoped bookmark
/// 存起來，下次啟動再解回 URL 並呼叫 `startAccessingSecurityScopedResource()`。
///
/// 此類別刻意與 `MainFlutterWindow` 放在同一檔案：Xcode 的 Runner target
/// 以明確檔案清單建置，新增 .swift 需同步修改 project.pbxproj，手動編輯
/// 該檔案的風險高於拆分帶來的整潔。待需要第二個原生模組時再一併拆出。
final class SecureBookmarkHandler {
  static let channelName = "app/secure_bookmark"

  /// 目前持有存取權的 URL，以路徑為鍵。
  ///
  /// `startAccessingSecurityScopedResource()` 必須與 `stop...()` 成對呼叫，
  /// 且系統對同時開啟的數量有上限；不追蹤就無法釋放，最終會靜默失敗。
  private var accessing: [String: URL] = [:]

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      createBookmark(call, result)
    case "resolve":
      resolveBookmark(call, result)
    case "stopAccessing":
      stopAccessing(call, result)
    case "stopAll":
      accessing.values.forEach { $0.stopAccessingSecurityScopedResource() }
      accessing.removeAll()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 將已授權的路徑轉為可長期保存的 bookmark（base64）。
  private func createBookmark(_ call: FlutterMethodCall, _ result: FlutterResult) {
    guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
      result(Self.badArguments("path"))
      return
    }
    do {
      let data = try URL(fileURLWithPath: path).bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      result(data.base64EncodedString())
    } catch {
      result(
        FlutterError(
          code: "create_failed",
          message: "無法建立 security-scoped bookmark：\(error.localizedDescription)",
          details: path
        ))
    }
  }

  /// 解回 bookmark 並取得存取權。
  ///
  /// 回傳的 `isStale` 表示 bookmark 仍可解析但已過期（例如資料夾被搬移或
  /// 系統升級），應在取得存取權後立即重建一份新的並覆寫舊值。
  private func resolveBookmark(_ call: FlutterMethodCall, _ result: FlutterResult) {
    guard let encoded = (call.arguments as? [String: Any])?["bookmark"] as? String,
      let data = Data(base64Encoded: encoded)
    else {
      result(Self.badArguments("bookmark"))
      return
    }
    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      let granted = url.startAccessingSecurityScopedResource()
      if granted {
        accessing[url.path] = url
      }
      result(["path": url.path, "isStale": isStale, "granted": granted])
    } catch {
      result(
        FlutterError(
          code: "resolve_failed",
          message: "無法解析 security-scoped bookmark：\(error.localizedDescription)",
          details: nil
        ))
    }
  }

  private func stopAccessing(_ call: FlutterMethodCall, _ result: FlutterResult) {
    guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
      result(Self.badArguments("path"))
      return
    }
    accessing.removeValue(forKey: path)?.stopAccessingSecurityScopedResource()
    result(nil)
  }

  private static func badArguments(_ key: String) -> FlutterError {
    FlutterError(code: "bad_arguments", message: "缺少必要參數 \(key)", details: nil)
  }
}
