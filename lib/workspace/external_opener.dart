/// 以系統預設方式開啟檔案或目錄的抽象（SPEC-003 §2.2「外部開啟契約」）。
///
/// 四處畫面（泳道開啟原始檔、開啟 docs 目錄、開啟原始檔、破洞項開啟原始檔）
/// 共用同一個可注入抽象；各畫面的互動反應表只引用 [ExternalOpenResult] 三值，
/// 不各自描述實作。
///
/// 三時刻覆蓋（SPEC-003 §2.2「兩個 port 的三時刻覆蓋」`INV-PORT-OBSERVE-001`）：
/// 呼叫發出以入口日誌承載（見〈呼叫發出日誌〉表）；受理不適用（`Process.run`
/// 為 fire-and-wait，外部程序不回中間 acknowledge）；結果由 [open] 的回傳值
/// 與日誌兩者共同承載，不互相抵扣。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 呼叫端標籤，供 `developer.log` 的 `name` 參數使用。
const String _tag = 'ExternalOpener';

/// [ExternalOpener.open] 的三種結果（SPEC-003 §2.2「介面」）。
enum ExternalOpenResult {
  /// 外部程序成功開啟（`exitCode == 0`）。
  opened,

  /// 前置存在檢查判定路徑不存在，未呼叫外部程序。
  notFound,

  /// 外部程序回傳非零 exitCode（含無應用程式能開啟等情況）。
  failed,
}

/// 以系統預設方式開啟檔案或目錄的介面。檔案與目錄走同一入口。
abstract interface class ExternalOpener {
  /// [path] 為呼叫端傳入的絕對路徑。
  Future<ExternalOpenResult> open(String path);
}

/// [ExternalOpener] 的 macOS 載體：呼叫 `/usr/bin/open`。
///
/// 不新增第三方依賴——`url_launcher_macos` 等價於 `NSWorkspace.open(URL)`，
/// 回傳同為成功／失敗二值，無額外資訊（SPEC-003 §2.2「實作（macOS）」列）。
class MacosExternalOpener implements ExternalOpener {
  MacosExternalOpener({this._executable = '/usr/bin/open'});

  /// 可注入的執行檔路徑，預設 `/usr/bin/open`；測試藉此觸發
  /// `ProcessException`（傳入不存在的執行檔路徑）驗證例外處理分支。
  final String _executable;

  @override
  Future<ExternalOpenResult> open(String path) async {
    // 呼叫發出日誌：必須在前置檢查之前，使無論走哪條結果分支都留下一筆
    // 記錄（INV-PORT-OBSERVE-001，SPEC-003 §2.2〈呼叫發出日誌〉表）。
    developer.log(path, name: _tag);

    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) {
      developer.log(
        '路徑不存在：$path', // i18n-exempt: 開發者診斷字串，非使用者可見文字
        name: _tag,
        level: 900, // warning
      );
      return ExternalOpenResult.notFound;
    }

    final ProcessResult result;
    try {
      result = await Process.run(_executable, [path]);
    } on ProcessException catch (e) {
      // Process.run 無法 spawn 執行檔時（權限、沙盒等）拋 ProcessException，
      // 不會回傳非零 exitCode——三值契約必須在此攔截，否則例外會繞過
      // ExternalOpenResult 直接傳到呼叫端。
      developer.log(
        '呼叫失敗：$path，${e.message}', // i18n-exempt: 開發者診斷字串，非使用者可見文字
        name: _tag,
        level: 900, // warning
      );
      return ExternalOpenResult.failed;
    }

    if (result.exitCode == 0) {
      developer.log(
        '已開啟：$path', // i18n-exempt: 開發者診斷字串，非使用者可見文字
        name: _tag,
      );
      return ExternalOpenResult.opened;
    }

    developer.log(
      '開啟失敗：$path，stderr=${result.stderr}', // i18n-exempt: 開發者診斷字串，非使用者可見文字
      name: _tag,
      level: 900, // warning
    );
    return ExternalOpenResult.failed;
  }
}

/// 測試替身：記錄呼叫路徑，並依配置回傳指定結果。
///
/// 預設所有路徑回傳 [ExternalOpenResult.opened]；用
/// [resultFor]（單一路徑覆寫）或 [defaultResult]（整體預設值）調整。
class FakeExternalOpener implements ExternalOpener {
  FakeExternalOpener({this.defaultResult = ExternalOpenResult.opened});

  /// 未於 [resultFor] 指定路徑時的回傳值。
  ExternalOpenResult defaultResult;

  /// 依路徑指定回傳值的覆寫表。
  final Map<String, ExternalOpenResult> resultFor = {};

  /// 每次 [open] 呼叫依序記錄的路徑，供測試斷言呼叫次數與順序。
  final List<String> calls = [];

  @override
  Future<ExternalOpenResult> open(String path) async {
    calls.add(path);
    return resultFor[path] ?? defaultResult;
  }
}

/// [ExternalOpener] 的 Riverpod 掛點。正式路徑供 [MacosExternalOpener]；
/// 測試以 `overrideWithValue` 注入 [FakeExternalOpener]。
final externalOpenerProvider = Provider<ExternalOpener>((ref) {
  return MacosExternalOpener();
});
