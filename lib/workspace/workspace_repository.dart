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

/// 管理「使用者選定的工作資料夾」。
///
/// App Sandbox 已關閉（見 macos/Runner/*.entitlements），因此不需要
/// security-scoped bookmark —— 記住路徑字串即可跨啟動存取。這個簡化的
/// 代價是 App 無法上架 Mac App Store，那是刻意的取捨：本 App 需要執行
/// 專案內的 doc CLI，沙盒下做不到。
class WorkspaceRepository {
  static const _pathKey = 'workspace.path';

  /// 開啟系統面板讓使用者選取資料夾。回傳 null 表示使用者取消。
  Future<WorkspaceState?> chooseFolder() async {
    final path = await getDirectoryPath();
    if (path == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
    return _inspect(path);
  }

  /// App 啟動時呼叫，還原先前選定的資料夾。
  Future<WorkspaceState> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    if (path == null) return const WorkspaceUnset();
    return _inspect(path);
  }

  /// 路徑字串會過期（資料夾被搬移、重新命名、刪除，或位於未掛載的磁碟），
  /// 因此每次取用都要實際確認，不能假設存下來就一直有效。
  ///
  /// 這是路徑字串相對於 security-scoped bookmark 的取捨：bookmark 追蹤的是
  /// 檔案系統節點、能跟著搬移，路徑字串不能。對開發者工具而言可接受 ——
  /// 專案資料夾被搬走時，讓使用者重選一次是合理的。
  Future<WorkspaceState> _inspect(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: '資料夾不存在或所在磁碟未掛載',
      );
    }
    try {
      await dir.list().first;
    } on FileSystemException catch (e) {
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: e.osError?.message ?? '無法讀取資料夾內容',
      );
    } on StateError {
      // 空資料夾：list().first 找不到元素，但資料夾本身可讀。
    }
    return WorkspaceReady(path);
  }
}
