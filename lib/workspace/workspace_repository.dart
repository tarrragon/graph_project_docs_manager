import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 工作資料夾的狀態。
sealed class WorkspaceState {
  const WorkspaceState();
}

/// 從未選過資料夾。
class WorkspaceUnset extends WorkspaceState {
  const WorkspaceUnset();
}

/// 資料夾存在且可讀。
class WorkspaceReady extends WorkspaceState {
  const WorkspaceReady(this.path);
  final String path;
}

/// 先前選過資料夾，但現在無法使用（已刪除、外接磁碟未掛載、權限變更）。
/// [lastKnownPath] 供 UI 提示使用者是哪一個。
class WorkspaceUnavailable extends WorkspaceState {
  const WorkspaceUnavailable({
    required this.lastKnownPath,
    required this.reason,
  });
  final String? lastKnownPath;
  final String reason;
}

/// `chooseFolder()` 的結局。與 [WorkspaceState] 正交：
/// [WorkspaceState] 描述「資料夾現在能不能用」，本型別描述「這次選取這個
/// 動作的結局」。
sealed class ChooseFolderResult {
  const ChooseFolderResult();
}

/// 使用者關閉面板未選取。對應現行 null 回傳。
class ChooseFolderCancelled extends ChooseFolderResult {
  const ChooseFolderCancelled();
}

/// 選取面板本身開不起來（MissingPluginException、PlatformException）。
class ChooseFolderUnavailable extends ChooseFolderResult {
  const ChooseFolderUnavailable(this.reason);
  final String reason;
}

/// 已選定且已持久化：下次啟動 restore() 讀得回來。
class ChooseFolderSelected extends ChooseFolderResult {
  const ChooseFolderSelected(this.state);
  final WorkspaceState state;
}

/// 已選定但未能記住：本次可用，下次啟動會回到 WorkspaceUnset，使用者需重選。
class ChooseFolderNotRemembered extends ChooseFolderResult {
  const ChooseFolderNotRemembered({required this.state, required this.reason});
  final WorkspaceState state;
  final String reason;
}

/// 開啟系統面板讓使用者選取資料夾（file_selector 平台通道）的介面。
/// 生產預設為 [getDirectoryPath]。
typedef DirectoryPathPicker = Future<String?> Function();

/// 包裝一個已開啟的偏好設定儲存管道，讓讀寫動作可被替換或觀察。
abstract interface class WorkspacePreferencesHandle {
  String? readString(String key);
  Future<bool> writeString(String key, String value);
}

/// 開啟偏好設定儲存管道的介面。對應 [SharedPreferences.getInstance] 這個
/// 「取得儲存管道」的受理時刻載體。
abstract interface class WorkspacePreferencesPort {
  Future<WorkspacePreferencesHandle> open();
}

/// 包裝 dart:io 的資料夾探測動作，讓 `_inspect()` 的兩個呼叫可被觀察或替換。
abstract interface class WorkspaceDirectoryProbePort {
  Future<bool> exists(String path);
  Future<void> readFirstEntry(String path);
}

/// 日誌投影的接縫。生產預設轉呼 `developer.log(name: 'WorkspaceRepository')`。
typedef WorkspaceLogSink = void Function(
  String message, {
  int? level,
  Object? error,
});

class _DefaultWorkspacePreferencesHandle
    implements WorkspacePreferencesHandle {
  _DefaultWorkspacePreferencesHandle(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? readString(String key) => _prefs.getString(key);

  @override
  Future<bool> writeString(String key, String value) =>
      _prefs.setString(key, value);
}

class _DefaultWorkspacePreferencesPort implements WorkspacePreferencesPort {
  const _DefaultWorkspacePreferencesPort();

  @override
  Future<WorkspacePreferencesHandle> open() async {
    final prefs = await SharedPreferences.getInstance();
    return _DefaultWorkspacePreferencesHandle(prefs);
  }
}

class _DefaultWorkspaceDirectoryProbePort
    implements WorkspaceDirectoryProbePort {
  const _DefaultWorkspaceDirectoryProbePort();

  @override
  Future<bool> exists(String path) => Directory(path).exists();

  @override
  Future<void> readFirstEntry(String path) async {
    await Directory(path).list().first;
  }
}

void _defaultLogSink(String message, {int? level, Object? error}) {
  developer.log(
    message, // i18n-exempt: 開發者 debug log
    name: 'WorkspaceRepository',
    level: level ?? 0,
    error: error,
  );
}

/// 管理「使用者選定的工作資料夾」。
///
/// App Sandbox 已關閉（見 macos/Runner/*.entitlements），因此不需要
/// security-scoped bookmark —— 記住路徑字串即可跨啟動存取。這個簡化的
/// 代價是 App 無法上架 Mac App Store，那是刻意的取捨：本 App 需要執行
/// 專案內的 doc CLI，沙盒下做不到。
class WorkspaceRepository {
  WorkspaceRepository({
    DirectoryPathPicker? pickDirectoryPath,
    WorkspacePreferencesPort? preferencesPort,
    WorkspaceDirectoryProbePort? directoryProbe,
    WorkspaceLogSink? logSink,
  })  : _pickDirectoryPath = pickDirectoryPath ?? getDirectoryPath,
        _preferencesPort =
            preferencesPort ?? const _DefaultWorkspacePreferencesPort(),
        _directoryProbe =
            directoryProbe ?? const _DefaultWorkspaceDirectoryProbePort(),
        _log = logSink ?? _defaultLogSink;

  static const _pathKey = 'workspace.path';

  final DirectoryPathPicker _pickDirectoryPath;
  final WorkspacePreferencesPort _preferencesPort;
  final WorkspaceDirectoryProbePort _directoryProbe;
  final WorkspaceLogSink _log;

  /// 開啟系統面板讓使用者選取資料夾。
  Future<ChooseFolderResult> chooseFolder() async {
    _log('開啟資料夾選取面板'); // i18n-exempt: 開發者 debug log
    String? path;
    try {
      path = await _pickDirectoryPath();
    } catch (e) {
      _log('面板不可用', level: 900, error: e); // i18n-exempt: 開發者 debug log
      return ChooseFolderUnavailable('$e');
    }
    if (path == null) {
      _log('使用者取消選取'); // i18n-exempt: 開發者 debug log
      return const ChooseFolderCancelled();
    }
    _log('已選取：$path'); // i18n-exempt: 開發者 debug log

    _log(
      '準備持久化，key=$_pathKey，path=$path', // i18n-exempt: 開發者 debug log
    );
    try {
      final handle = await _preferencesPort.open();
      _log('偏好設定儲存已就緒'); // i18n-exempt: 開發者 debug log
      final success = await handle.writeString(_pathKey, path);
      if (!success) {
        _log(
          '持久化失敗：寫入回報 false', // i18n-exempt: 開發者 debug log
          level: 900,
        );
        return ChooseFolderNotRemembered(
          state: await _inspect(path),
          reason: '寫入回報 false', // i18n-exempt: 開發者 debug log
        );
      }
      _log('已持久化'); // i18n-exempt: 開發者 debug log
      return ChooseFolderSelected(await _inspect(path));
    } catch (e) {
      _log('持久化失敗（例外）', level: 900, error: e); // i18n-exempt: 開發者 debug log
      return ChooseFolderNotRemembered(state: await _inspect(path), reason: '$e');
    }
  }

  /// App 啟動時呼叫，還原先前選定的資料夾。
  Future<WorkspaceState> restore() async {
    _log('還原工作資料夾，key=$_pathKey'); // i18n-exempt: 開發者 debug log
    WorkspacePreferencesHandle handle;
    try {
      handle = await _preferencesPort.open();
    } catch (e) {
      _log('還原失敗（例外）', level: 900, error: e); // i18n-exempt: 開發者 debug log
      return WorkspaceUnavailable(
        lastKnownPath: null,
        reason: '$e', // i18n-exempt: 例外訊息，非固定使用者文案
      );
    }
    _log('偏好設定儲存已就緒'); // i18n-exempt: 開發者 debug log
    final path = handle.readString(_pathKey);
    if (path == null) {
      _log('無已儲存路徑'); // i18n-exempt: 開發者 debug log
      return const WorkspaceUnset();
    }
    _log('已還原：$path'); // i18n-exempt: 開發者 debug log
    return _inspect(path);
  }

  /// 路徑字串會過期（資料夾被搬移、重新命名、刪除，或位於未掛載的磁碟），
  /// 因此每次取用都要實際確認，不能假設存下來就一直有效。
  ///
  /// 這是路徑字串相對於 security-scoped bookmark 的取捨：bookmark 追蹤的是
  /// 檔案系統節點、能跟著搬移，路徑字串不能。對開發者工具而言可接受 ——
  /// 專案資料夾被搬走時，讓使用者重選一次是合理的。
  Future<WorkspaceState> _inspect(String path) async {
    _log('探測資料夾是否存在：$path'); // i18n-exempt: 開發者 debug log
    if (!await _directoryProbe.exists(path)) {
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: '資料夾不存在或所在磁碟未掛載', // i18n-exempt: 既有欄位，本票未變更其 i18n 狀態
      );
    }
    _log('讀取資料夾內容：$path'); // i18n-exempt: 開發者 debug log
    try {
      await _directoryProbe.readFirstEntry(path);
    } on FileSystemException catch (e) {
      // 降級為 WorkspaceUnavailable 前先留下診斷日誌（觀測性規則 1）：
      // 這裡吞掉的是使用者可自行排除的環境問題（磁碟未掛載、權限被收回），
      // 不是需要中斷 App 的致命例外。
      _log(
        '資料夾探測失敗：$path', // i18n-exempt: 開發者 debug log，非使用者可見文字
        level: 900,
        error: e,
      );
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: e.osError?.message ?? '無法讀取資料夾內容', // i18n-exempt: 既有欄位，本票未變更其 i18n 狀態
      );
    } on StateError {
      // 空資料夾：list().first 找不到元素，但資料夾本身可讀。
    }
    return WorkspaceReady(path);
  }
}
