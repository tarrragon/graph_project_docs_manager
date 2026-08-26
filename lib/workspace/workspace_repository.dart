import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/secure_bookmark.dart';

/// 還原先前工作資料夾的結果。
sealed class WorkspaceState {
  const WorkspaceState();
}

/// 從未選過資料夾。
class WorkspaceUnset extends WorkspaceState {
  const WorkspaceUnset();
}

/// 已取得存取權，可讀寫 [path]。
class WorkspaceReady extends WorkspaceState {
  const WorkspaceReady(this.path);
  final String path;
}

/// 先前選過資料夾，但授權已無法還原（資料夾被刪除、外接磁碟未掛載、
/// bookmark 損毀等）。[lastKnownPath] 供 UI 提示使用者是哪一個。
class WorkspaceUnavailable extends WorkspaceState {
  const WorkspaceUnavailable({required this.lastKnownPath, required this.reason});
  final String? lastKnownPath;
  final String reason;
}

/// 管理「使用者授權的工作資料夾」的完整生命週期。
///
/// 職責邊界：[SecureBookmark] 只做原生通訊，本類別負責決定何時建立、
/// 何時重建、失敗時如何收場。
class WorkspaceRepository {
  /// [bookmark] 可注入替身供測試使用；預設走真實的 platform channel。
  WorkspaceRepository({SecureBookmark? bookmark})
      : _bookmark = bookmark ?? const SecureBookmark();

  final SecureBookmark _bookmark;

  static const _bookmarkKey = 'workspace.bookmark';
  static const _lastPathKey = 'workspace.last_path';

  /// 開啟系統面板讓使用者選取資料夾，並把授權保存下來。
  ///
  /// 回傳 null 表示使用者取消。
  Future<WorkspaceState?> chooseFolder() async {
    final path = await getDirectoryPath();
    if (path == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPathKey, path);

    if (!SecureBookmark.isSupported) {
      // 非 macOS 平台沒有 sandbox 限制，記住路徑即可。
      return WorkspaceReady(path);
    }

    try {
      await prefs.setString(_bookmarkKey, await _bookmark.create(path));
      return WorkspaceReady(path);
    } on PlatformException catch (e) {
      return WorkspaceUnavailable(
        lastKnownPath: path,
        reason: e.message ?? '無法保存資料夾授權',
      );
    }
  }

  /// App 啟動時呼叫，還原先前的授權。
  Future<WorkspaceState> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPath = prefs.getString(_lastPathKey);

    if (!SecureBookmark.isSupported) {
      return lastPath == null ? const WorkspaceUnset() : WorkspaceReady(lastPath);
    }

    final stored = prefs.getString(_bookmarkKey);
    if (stored == null) return const WorkspaceUnset();

    try {
      final resolved = await _bookmark.resolve(stored);
      if (!resolved.granted) {
        return WorkspaceUnavailable(
          lastKnownPath: lastPath,
          reason: '系統拒絕了先前的資料夾授權',
        );
      }
      // isStale 代表 bookmark 還能解析但已過期；此時必須趁著手上還有存取權
      // 立刻重建，否則下一次很可能就完全解不開了。
      if (resolved.isStale) {
        await prefs.setString(_bookmarkKey, await _bookmark.create(resolved.path));
      }
      await prefs.setString(_lastPathKey, resolved.path);
      return WorkspaceReady(resolved.path);
    } on PlatformException catch (e) {
      // 策略選擇：此處「保留」失效的 bookmark 而非清除，讓 UI 能顯示
      // lastKnownPath 提示使用者是哪個資料夾出了問題（例如外接磁碟沒插）。
      // 若偏好「失效即忘記」，在這裡 remove 兩個 key 即可。
      return WorkspaceUnavailable(
        lastKnownPath: lastPath,
        reason: e.message ?? '先前的資料夾授權已失效',
      );
    }
  }

  /// 釋放所有存取權。應在 App 結束前呼叫。
  Future<void> release() async {
    if (SecureBookmark.isSupported) await _bookmark.stopAll();
  }
}
