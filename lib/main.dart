import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app/shell.dart';
import 'components/components.dart' show BlockedState;
import 'l10n/app_localizations.dart';
import 'tokens/tokens.dart';
import 'workspace/workspace_repository.dart';

/// 設計稿基準尺寸（logical pixels）。
///
/// ScreenUtil 的所有換算都以此為 1:1 基準：視窗寬度 / [kDesignSize].width
/// 即為 `.w` 的縮放係數。此值刻意等同 macOS 端的預設視窗尺寸
/// （MainFlutterWindow.defaultSize），使 App 一開啟時縮放係數為 1.0，
/// 開發時所見即 1:1 設計稿。
const Size kDesignSize = Size(1280, 800);

/// 視窗尺寸下限，必須與 macOS 端 `MainFlutterWindow.minimumSize` 一致。
///
/// 桌面與行動裝置的根本差異：視窗尺寸是連續且使用者可控的，不是一組
/// 離散的機型。因此「不跑版」的驗收範圍由這個下限定義 —— 整合測試以
/// 此尺寸作為最嚴苛的 viewport。
const Size kMinWindowSize = Size(960, 640);

/// 全域錯誤攔截三層的單一出口。
///
/// 三層（框架 [FlutterError.onError]／平台 [PlatformDispatcher.onError]／
/// 非同步 [runZonedGuarded]）攔截到的例外皆匯流於此，而非各自處理——
/// 這樣「顯示什麼」只需維護一處。載體是畫面而非檔案（見
/// docs/tech-decisions.md 2026-08-27 補記段「執行期 log 的裁決」）：
/// 未預期例外不寫入 log 檔，改由 [DocsManagerApp] 監聽並以
/// [BlockedState.plain] 取代半渲染的畫面，避免使用者卡在一個不動的畫面
/// 卻毫無徵兆。
///
/// 標記 [visibleForTesting]：正式流程只由三層攔截寫入，測試需要直接
/// 觸發/重置以驗證單一出口的行為。
@visibleForTesting
final ValueNotifier<Object?> fatalErrorNotifier = ValueNotifier<Object?>(null);

/// 記錄診斷日誌並通知 [fatalErrorNotifier]。
///
/// `source` 只用於日誌區分攔截點，不進入使用者可見的畫面文字。
///
/// 標記 [visibleForTesting]：三層攔截各自把（未攔截的）例外轉呼叫到此，
/// 測試需要能直接呼叫以驗證「匯流至單一出口」這件事，而不必真的讓
/// Widget 拋錯或啟動整個 App。
@visibleForTesting
void reportFatalError(String source, Object error, StackTrace stack) {
  developer.log(
    '未攔截例外（$source）', // i18n-exempt: 開發者 debug log，非使用者可見文字
    name: 'main',
    level: 900,
    error: error,
    stackTrace: stack,
  );
  fatalErrorNotifier.value = error;
}

/// 安裝框架層與平台層的錯誤攔截。
///
/// 從 [main] 抽出成獨立函式：`main()` 本身不可單元測試（呼叫
/// [runApp] 啟動整個 App），但攔截器的安裝與觸發邏輯可以——測試直接
/// 呼叫本函式後觸發 `FlutterError.onError!(...)` /
/// `PlatformDispatcher.instance.onError!(...)`，驗證兩層是否正確匯流至
/// [reportFatalError]。
@visibleForTesting
void installGlobalErrorHandlers() {
  // 框架層：Widget build/layout/paint 期間拋出的例外。
  FlutterError.onError = (details) {
    reportFatalError(
      'FlutterError',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  // 平台層：非 Flutter 框架管轄、由 engine/platform channel 拋出的例外。
  PlatformDispatcher.instance.onError = (error, stack) {
    reportFatalError('PlatformDispatcher', error, stack);
    // 回傳 true 表示已處理，阻止 engine 印出預設的未處理例外訊息，
    // 避免與本函式的日誌重複。
    return true;
  };
}

void main() {
  installGlobalErrorHandlers();
  // 非同步層：runApp 之外、未被上兩層捕捉到的 Future/Stream 例外
  // （例如未 await 的非同步呼叫）。
  runZonedGuarded(
    () => runApp(const ProviderScope(child: DocsManagerApp())),
    (error, stack) => reportFatalError('runZonedGuarded', error, stack),
  );
}

class DocsManagerApp extends StatelessWidget {
  const DocsManagerApp({super.key, this.locale, this.repository});

  /// 工作資料夾的資料來源；測試可注入替身，避免碰到真實檔案系統。
  final WorkspaceRepository? repository;

  /// 強制指定語系；`null` 表示跟隨系統設定。
  ///
  /// 整合測試藉此鎖定語系來斷言字串，未來若要做「語系切換」設定頁，
  /// 也是把使用者選擇注入到這個參數。
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    // ScreenUtilInit 必須位於 MaterialApp 之上：它需要先取得 MediaQuery
    // 完成換算表初始化，底下的 widget 才能安全使用 .w / .h / .sp。
    return ScreenUtilInit(
      designSize: kDesignSize,
      // 字級取寬／高縮放的較小值，避免視窗被拉寬時字級跟著暴增。
      minTextAdapt: true,
      // 這是 Android 分割畫面專用的補償，桌面單一視窗情境下不適用。
      splitScreenMode: false,
      builder: (context, child) => MaterialApp(
        // title 是靜態字串，取不到 localizations；onGenerateTitle 會在
        // Localizations 就緒後才呼叫，才能拿到當前語系的名稱。
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.accent,
        ),
        home: child,
      ),
      child: const FatalErrorGate(child: AppShell()),
    );
  }
}

/// 全域錯誤攔截的單一出口在畫面上的落點。
///
/// 監聽 [fatalErrorNotifier]；一旦非空即以 [BlockedState.plain] 取代
/// [child]，讓未預期例外抵達使用者眼前而非停在半渲染畫面。
///
/// message 直接顯示例外本身的診斷文字而非固定文案：此情境沒有既有 ARB
/// key 可用（見票面 NeedsContext），與其掛一段語意不符的既有文案，
/// 顯示真實錯誤內容對排查更有意義且不構成硬編碼 UI 文案。
@visibleForTesting
class FatalErrorGate extends StatelessWidget {
  const FatalErrorGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: fatalErrorNotifier,
      builder: (context, error, _) {
        if (error == null) return child;
        return BlockedState.plain(
          message: '$error',
          onSwitchProject: () => fatalErrorNotifier.value = null,
          testKey: const Key('state-fatal-error'),
        );
      },
    );
  }
}
