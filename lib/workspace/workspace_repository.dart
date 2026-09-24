import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_types.dart';

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

/// [WorkspaceUnavailable.reason] 固定文案：資料夾整個不存在或所在磁碟未掛載。
// i18n-exempt: 使用者可見欄位，本票沿用既有中文字面慣例，未接 ARB。
const _reasonFolderMissing = '資料夾不存在或所在磁碟未掛載';

/// [WorkspaceUnavailable.reason] 固定文案：資料夾存在但內容讀取失敗
/// （權限被收回、磁碟 I/O 異常等）。刻意不插入 [FileSystemException] 的
/// `osError?.message`——那是 OS 語系文字，不受應用程式語系控制。
// i18n-exempt: 使用者可見欄位，本票沿用既有中文字面慣例，未接 ARB。
const _reasonFolderUnreadable = '無法讀取資料夾內容';

/// [WorkspaceUnavailable.reason] 固定文案：偏好設定儲存管道本身開不起來
/// （`SharedPreferences.getInstance()` 拋例外）。
// i18n-exempt: 使用者可見欄位，本票沿用既有中文字面慣例，未接 ARB。
const _reasonPreferencesUnavailable = '無法讀取已儲存的工作資料夾設定';

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

  /// 版號 key。與 [_pathKey] 分開儲存（而非合併成單一 JSON 值）是刻意的：
  /// 分開儲存讓「版號讀取失敗」與「path 讀取失敗」在 SharedPreferences 層
  /// 可各自觀察（雖然目前的判定邏輯不利用此區別，見
  /// `docs/tech-decisions.md` 補記「shared_preferences key 版本化與遷移
  /// 策略」）。
  static const _schemaVersionKey = 'workspace.schemaVersion';

  /// 目前的 schema 版本。改動 [_pathKey] 對應的值格式（例如從單一路徑字串
  /// 改成清單）時，必須遞增此常數並在 [_migrateSchema] 補上對應版本的轉換
  /// 分支——版號常數與遷移函式集中於此檔是決策的一部分，見
  /// `docs/tech-decisions.md` 同一補記段。
  static const _currentSchemaVersion = 1;

  /// 最近專案清單 key（SPEC-005 §2.4）。與 [_pathKey] 分開儲存——沿用同一
  /// 個偏好設定管道，不新增 port。
  static const _recentProjectsKey = 'workspace.recentProjects';

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
    return _persistAndInspect(path);
  }

  /// 持久化 [path] 並探測其可用性，回傳對應的 [ChooseFolderResult]。
  ///
  /// [_inspect] 刻意放在 try/catch **之外**、且只呼叫一次：持久化的
  /// 成敗與資料夾本身是否可用是兩件事，若把 [_inspect] 留在同一個 try
  /// 內，它拋出的非吞型例外會被本函式的 catch 誤判為「持久化失敗」，
  /// 且該 catch 分支若仍呼叫一次 `_inspect(path)` 組裝回傳值，就會對
  /// 同一個 path 探測兩次。
  Future<ChooseFolderResult> _persistAndInspect(String path) async {
    _log(
      '準備持久化，key=$_pathKey，path=$path', // i18n-exempt: 開發者 debug log
    );
    String? failureReason;
    try {
      final handle = await _preferencesPort.open();
      _log('偏好設定儲存已就緒'); // i18n-exempt: 開發者 debug log
      // 版號 key 與 path key 的首次寫入是同一次操作（0.2.0-W1-021 acceptance
      // 第 3 條、呼應 0.1.0-W3-121 裁決 B 的交叉判據前提）：只要 path 曾被
      // 寫入，版號一定同時存在，不會出現「有 path 但版號 key 從未寫過」這種
      // 中間態，讓 restore() 端的判定邏輯（見 [_migrateSchema]）少一種要
      // 處理的組合。寫入順序刻意 path 在前、版號在後——若寫到一半失敗，
      // 寧可「有 path 無版號」（會被判為 v0 舊資料而觸發遷移路徑，仍可讀出
      // path）也不要「有版號無 path」（版號對不上任何資料，判定邏輯無從
      // 補救）。
      final success = await handle.writeString(_pathKey, path);
      if (success) {
        await handle.writeString(
          _schemaVersionKey,
          '$_currentSchemaVersion',
        );
        _log('已持久化'); // i18n-exempt: 開發者 debug log
      } else {
        _log(
          '持久化失敗：寫入回報 false', // i18n-exempt: 開發者 debug log
          level: 900,
        );
        failureReason = '寫入回報 false'; // i18n-exempt: 診斷用回傳值，非 log
      }
    } catch (e) {
      _log('持久化失敗（例外）', level: 900, error: e); // i18n-exempt: 開發者 debug log
      failureReason = '$e'; // i18n-exempt: 診斷用回傳值，非 log
    }
    final state = await _inspect(path);
    if (failureReason == null) {
      return ChooseFolderSelected(state);
    }
    return ChooseFolderNotRemembered(state: state, reason: failureReason);
  }

  /// App 啟動時呼叫，還原先前選定的資料夾。
  Future<WorkspaceState> restore() async {
    _log('還原工作資料夾，key=$_pathKey'); // i18n-exempt: 開發者 debug log
    WorkspacePreferencesHandle handle;
    try {
      handle = await _preferencesPort.open();
    } catch (e) {
      // 不互相抵扣：例外細節留給日誌診斷，reason 是使用者可能看見的欄位，
      // 固定為穩定文案常數（見 WorkspaceUnavailable 契約），不外露原始
      // 例外字串。
      _log('還原失敗（例外）', level: 900, error: e); // i18n-exempt: 開發者 debug log
      return const WorkspaceUnavailable(
        lastKnownPath: null,
        reason: _reasonPreferencesUnavailable,
      );
    }
    _log('偏好設定儲存已就緒'); // i18n-exempt: 開發者 debug log
    final rawPath = handle.readString(_pathKey);
    final rawVersion = handle.readString(_schemaVersionKey);
    final migration = _migrateSchema(
      storedVersion: _parseSchemaVersion(rawVersion),
      storedPath: rawPath,
    );
    final path = switch (migration) {
      SchemaCurrent(:final path) => path,
      SchemaMigrated(:final path) => path,
      SchemaMigrationFailed() => null,
    };
    if (migration is SchemaMigrated) {
      _log('偵測到舊版資料，已就地遷移'); // i18n-exempt: 開發者 debug log
    }
    if (migration is SchemaMigrationFailed) {
      // 遷移失敗不阻擋 App：與 0.1.0-W3-121 裁決一致（restore() 任何失敗
      // 皆降級為 WorkspaceUnset/WorkspaceUnavailable，不丟例外、不中斷
      // App 啟動）。因不信任舊結構，選擇當作「從未選過資料夾」而非嘗試
      // 沿用可能已損毀的值——見 tech-decisions.md 同一補記段的決策記錄。
      _log(
        '版號無法辨識，判定遷移失敗（storedVersion=${migration.storedVersion}）', // i18n-exempt: 開發者 debug log
        level: 900,
      );
      return const WorkspaceUnset();
    }
    if (path == null) {
      _log('無已儲存路徑'); // i18n-exempt: 開發者 debug log
      return const WorkspaceUnset();
    }
    _log('已還原：$path'); // i18n-exempt: 開發者 debug log
    return _inspect(path);
  }

  /// 判定版號並在需要時就地轉換資料結構。純函式：只依賴輸入引數，方便以
  /// 假資料測試「舊版資料能被讀成新版結構」（acceptance 第 1 條）。
  ///
  /// 版號讀取失敗（SharedPreferences 本身有值但解析失敗）與「首次啟動、
  /// 從未寫過版號」在此函式的輸入層面無法區分——兩者對呼叫端而言都是
  /// `storedVersion == null`。決策：不特別區分，統一視為「無版號」，再用
  /// `storedPath` 是否存在判斷是 v0 舊資料（有 path）還是真的沒資料（無
  /// path）。理由與風險見 tech-decisions.md 同一補記段。
  SchemaMigrationResult _migrateSchema({
    required int? storedVersion,
    required String? storedPath,
  }) {
    if (storedVersion == null) {
      if (storedPath == null) {
        // 無版號也無 path：乾淨的首次啟動，無需遷移。
        return SchemaCurrent(storedPath);
      }
      // 有 path 無版號：0.2.0-W1-021 之前寫入的舊資料（v0，單一路徑字串，
      // 與目前的 v1 儲存格式相同），就地判定為 v1，無需轉換內容本身。
      return SchemaMigrated(storedPath);
    }
    if (storedVersion == _currentSchemaVersion) {
      return SchemaCurrent(storedPath);
    }
    if (storedVersion < _currentSchemaVersion) {
      // 尚無 v1 以外的舊版本存在，此分支預留給下一次格式變更時填入實際
      // 轉換邏輯（例如單一路徑字串 -> 清單）。
      return SchemaMigrated(storedPath);
    }
    // storedVersion > _currentSchemaVersion：資料是被更新版本的 App 寫入
    // 的，本版邏輯不認得其結構，不嘗試猜測式讀取。
    return SchemaMigrationFailed(storedVersion);
  }

  int? _parseSchemaVersion(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  /// 讀取最近專案清單（SPEC-005 §2.4）。不拋例外：管道開不起來或內容損壞
  /// 一律回空清單，失敗原因只進日誌（不互相抵扣，同 [restore] 契約）。
  Future<List<RecentProject>> loadRecentProjects() async {
    _log(
      '讀取最近專案清單，key=$_recentProjectsKey', // i18n-exempt: 開發者 debug log
    );
    WorkspacePreferencesHandle handle;
    try {
      handle = await _preferencesPort.open();
    } catch (e) {
      _log(
        '讀取最近專案清單失敗（開啟儲存管道例外）', // i18n-exempt: 開發者 debug log
        level: 900,
        error: e,
      );
      return const [];
    }
    return _readRecentProjects(handle);
  }

  /// 新增或更新一筆最近專案（成功載入後呼叫，SPEC-005 §2.4「寫入時機」）：
  /// 讀出現有清單、移除同 [path] 項、以目前時刻為 `lastOpenedAt` 插入頂端後
  /// 整份寫回。清單損壞時以空清單為基底寫入（損壞內容被取代，見規格
  /// 「損壞時不覆寫的邊界」），並記一筆 level 900 日誌使遺失可被觀測。
  Future<bool> addRecentProject(String path) async {
    _log('新增最近專案，path=$path'); // i18n-exempt: 開發者 debug log
    WorkspacePreferencesHandle handle;
    try {
      handle = await _preferencesPort.open();
    } catch (e) {
      _log(
        '新增最近專案失敗（開啟儲存管道例外）', // i18n-exempt: 開發者 debug log
        level: 900,
        error: e,
      );
      return false;
    }
    final existing = _readRecentProjectsForWrite(handle);
    final updated = [
      RecentProject(path: path, lastOpenedAt: DateTime.now().toUtc()),
      for (final project in existing)
        if (project.path != path) project,
    ];
    final encoded = jsonEncode([
      for (final project in updated)
        {
          'path': project.path,
          'lastOpenedAt': project.lastOpenedAt.toIso8601String(),
        },
    ]);
    try {
      final success = await handle.writeString(_recentProjectsKey, encoded);
      if (success) {
        _log('已寫入最近專案清單，項數=${updated.length}'); // i18n-exempt: 開發者 debug log
      } else {
        _log(
          '新增最近專案失敗：寫入回報 false', // i18n-exempt: 開發者 debug log
          level: 900,
        );
      }
      return success;
    } catch (e) {
      _log('新增最近專案失敗（例外）', level: 900, error: e); // i18n-exempt: 開發者 debug log
      return false;
    }
  }

  /// [loadRecentProjects] 的讀取＋排序邏輯，共用已開啟的 [handle]。
  List<RecentProject> _readRecentProjects(WorkspacePreferencesHandle handle) {
    final raw = handle.readString(_recentProjectsKey);
    if (raw == null) {
      _log('最近專案清單不存在，回空清單'); // i18n-exempt: 開發者 debug log
      return const [];
    }
    final parsed = _parseRecentProjects(raw);
    if (parsed == null) {
      _log(
        '最近專案清單格式損壞，回空清單', // i18n-exempt: 開發者 debug log
        level: 900,
      );
      return const [];
    }
    _log('已讀取最近專案清單，項數=${parsed.length}'); // i18n-exempt: 開發者 debug log
    parsed.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return parsed;
  }

  /// [addRecentProject] 用：讀取現有清單作為新項的基底，損壞時回空清單並
  /// 記錄「以損壞內容為基底被取代」（SPEC-005 §2.4「損壞時不覆寫的邊界」）。
  List<RecentProject> _readRecentProjectsForWrite(
    WorkspacePreferencesHandle handle,
  ) {
    final raw = handle.readString(_recentProjectsKey);
    if (raw == null) return const [];
    final parsed = _parseRecentProjects(raw);
    if (parsed == null) {
      _log(
        '既有最近專案清單損壞，以空清單為基底被取代', // i18n-exempt: 開發者 debug log
        level: 900,
      );
      return const [];
    }
    return parsed;
  }

  /// 解析 `workspace.recentProjects` 的 JSON 內容；任何結構或型別不符皆
  /// 視為整份損壞（不部分採用），回傳 `null` 供呼叫端統一處理。
  List<RecentProject>? _parseRecentProjects(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final result = <RecentProject>[];
      for (final item in decoded) {
        if (item is! Map) return null;
        final path = item['path'];
        final lastOpenedAtRaw = item['lastOpenedAt'];
        if (path is! String || lastOpenedAtRaw is! String) return null;
        final lastOpenedAt = DateTime.tryParse(lastOpenedAtRaw);
        if (lastOpenedAt == null) return null;
        result.add(RecentProject(path: path, lastOpenedAt: lastOpenedAt));
      }
      return result;
    } catch (e) {
      return null;
    }
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
        reason: _reasonFolderMissing,
      );
    }
    _log('讀取資料夾內容：$path'); // i18n-exempt: 開發者 debug log
    try {
      await _directoryProbe.readFirstEntry(path);
    } on FileSystemException catch (e) {
      // 降級為 WorkspaceUnavailable 前先留下診斷日誌（觀測性規則 1）：
      // 這裡吞掉的是使用者可自行排除的環境問題（磁碟未掛載、權限被收回），
      // 不是需要中斷 App 的致命例外。原始 OSError 訊息只進日誌，不進
      // reason——那是 OS 語系文字，不受應用程式語系控制。
      _log(
        '資料夾探測失敗：$path', // i18n-exempt: 開發者 debug log，非使用者可見文字
        level: 900,
        error: e,
      );
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: _reasonFolderUnreadable,
      );
    } on StateError {
      // 空資料夾：list().first 找不到元素，但資料夾本身可讀。
    }
    return WorkspaceReady(path);
  }
}
