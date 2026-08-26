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

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.minSize = MainFlutterWindow.minimumSize
    self.setContentSize(MainFlutterWindow.defaultSize)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
