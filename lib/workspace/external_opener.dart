/// 以系統預設方式開啟檔案或目錄的抽象（SPEC-003 §2.2「外部開啟契約」）。
///
/// 四處畫面（泳道開啟原始檔、開啟 docs 目錄、開啟原始檔、破洞項開啟原始檔）
/// 共用同一個可注入抽象；各畫面的互動反應表只引用 [ExternalOpenResult] 四值，
/// 不各自描述實作。
///
/// 三時刻覆蓋（SPEC-003 §2.2「兩個 port 的三時刻覆蓋」`INV-PORT-OBSERVE-001`）：
/// 呼叫發出以入口日誌承載（見〈呼叫發出日誌〉表）；受理不適用（`Process.run`
/// 為 fire-and-wait，外部程序不回中間 acknowledge）；結果由 [open] 的回傳值
/// 與日誌兩者共同承載，不互相抵扣。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../services/macos_preferences_channel.dart';
import 'editor_preference.dart';
import 'workspace_io_log_event.dart';

/// [ExternalOpener.open] 的四種結果（SPEC-003 §2.2「介面」）。
enum ExternalOpenResult {
  /// 外部程序成功開啟（`exitCode == 0`）。
  opened,

  /// 所選編輯器已不可用（查無 handler），已退回系統預設方式開啟且未定位
  /// （SPEC-003 §2.2〈行號定位〉）。
  openedWithoutEditor,

  /// 前置存在檢查判定路徑不存在，未呼叫外部程序。
  notFound,

  /// 外部程序回傳非零 exitCode（含無應用程式能開啟等情況）。
  failed,
}

/// 以系統預設方式開啟檔案或目錄的介面。檔案與目錄走同一入口。
abstract interface class ExternalOpener {
  /// [path] 為呼叫端傳入的絕對路徑；[line] 為 1 起算的行號，`null` 表示
  /// 不定位。
  Future<ExternalOpenResult> open(String path, {int? line});
}

/// 外部程序呼叫的可注入接縫，預設 [Process.run]。
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// [ExternalOpener] 的 macOS 載體：呼叫 `/usr/bin/open`。
///
/// 不新增第三方依賴——`url_launcher_macos` 等價於 `NSWorkspace.open(URL)`，
/// 回傳同為成功／失敗二值，無額外資訊（SPEC-003 §2.2「實作（macOS）」列）。
///
/// 只有 [open] 收到 `line != null` 時才參考選定編輯器；未傳行號的開啟
/// （§3.1、§3.2、§3.6，含 docs 目錄）行為不因選定編輯器而改變。
class MacosExternalOpener implements ExternalOpener {
  MacosExternalOpener({
    this._executable = '/usr/bin/open',
    this._runner = Process.run,
    this._probe,
    this._store = const SharedPreferencesEditorStore(),
  });

  /// 可注入的執行檔路徑，預設 `/usr/bin/open`；測試藉此觸發
  /// `ProcessException`（傳入不存在的執行檔路徑）驗證例外處理分支。
  final String _executable;
  final ProcessRunner _runner;

  /// 未注入時視同所有編輯器皆查無 handler。
  final EditorHandlerProbe? _probe;
  final EditorPreferenceStore _store;

  @override
  Future<ExternalOpenResult> open(String path, {int? line}) async {
    // 呼叫發出日誌：必須在前置檢查之前，使無論走哪條結果分支都留下一筆
    // 記錄（INV-PORT-OBSERVE-001，SPEC-003 §2.2〈呼叫發出日誌〉表）。
    externalOpenerLogSink(
      ExternalOpenerLogEvent.openRequested,
      LogFields({WorkspaceIoLogKeys.hasLine: LogValue.boolean(line != null)}),
    );

    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) {
      externalOpenerLogSink(
        ExternalOpenerLogEvent.pathNotFound,
        LogFields.empty,
        level: LogLevel.warning,
      );
      return ExternalOpenResult.notFound;
    }

    final editor = line == null ? null : await _selectedEditor();
    if (editor == null) return _launch(path, ExternalOpenResult.opened);
    if (await _hasHandler(editor)) {
      return _launch(
        editorUrlFor(editor, path, line!),
        ExternalOpenResult.opened,
      );
    }
    externalOpenerLogSink(
      ExternalOpenerLogEvent.editorHandlerMissing,
      LogFields({WorkspaceIoLogKeys.editorId: LogValue.fieldName(editor.id)}),
      level: LogLevel.warning,
    );
    return _launch(path, ExternalOpenResult.openedWithoutEditor);
  }

  /// 已持久化且仍在對照表內的編輯器；系統預設與未知 id 回傳 `null`。
  Future<EditorSpec?> _selectedEditor() async {
    return editorById(await _store.read());
  }

  Future<bool> _hasHandler(EditorSpec editor) async {
    final probe = _probe;
    return probe != null && await probe.hasHandler(editor.scheme);
  }

  /// 以 [_executable] 開啟 [target]（路徑或編輯器 URL），成功時回傳 [onSuccess]。
  Future<ExternalOpenResult> _launch(
    String target,
    ExternalOpenResult onSuccess,
  ) async {
    final ProcessResult result;
    try {
      result = await _runner(_executable, [target]);
    } on ProcessException catch (e) {
      // Process.run 無法 spawn 執行檔時（權限、沙盒等）拋 ProcessException，
      // 不會回傳非零 exitCode——契約必須在此攔截，否則例外會繞過
      // ExternalOpenResult 直接傳到呼叫端。
      externalOpenerLogSink(
        ExternalOpenerLogEvent.launchFailed,
        LogFields.empty,
        level: LogLevel.warning,
        source: ErrorSource.externalProcess,
        error: e,
      );
      return ExternalOpenResult.failed;
    }

    if (result.exitCode == 0) {
      externalOpenerLogSink(ExternalOpenerLogEvent.opened, LogFields.empty);
      return onSuccess;
    }

    externalOpenerLogSink(
      ExternalOpenerLogEvent.openExitNonZero,
      LogFields({
        WorkspaceIoLogKeys.exitCode: LogValue.integer(result.exitCode),
      }),
      level: LogLevel.warning,
      source: ErrorSource.externalProcess,
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

  /// 與 [calls] 平行記錄的行號（未傳為 `null`）。
  final List<int?> lines = [];

  @override
  Future<ExternalOpenResult> open(String path, {int? line}) async {
    calls.add(path);
    lines.add(line);
    return resultFor[path] ?? defaultResult;
  }
}

/// [ExternalOpener] 的 Riverpod 掛點。正式路徑供 [MacosExternalOpener]；
/// 測試以 `overrideWithValue` 注入 [FakeExternalOpener]。
final externalOpenerProvider = Provider<ExternalOpener>((ref) {
  return MacosExternalOpener(
    probe: ref.watch(editorHandlerProbeProvider),
    store: ref.watch(editorPreferenceStoreProvider),
  );
});
