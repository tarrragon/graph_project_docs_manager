import 'dart:io';

import 'package:flutter/services.dart';

/// 解析一份 security-scoped bookmark 的結果。
class BookmarkResolution {
  const BookmarkResolution({
    required this.path,
    required this.isStale,
    required this.granted,
  });

  /// bookmark 指向的實際路徑。資料夾被搬移或改名時，這會是「新」位置 ——
  /// bookmark 追蹤的是檔案系統節點，不是路徑字串。
  final String path;

  /// bookmark 仍可解析但已過期（資料夾搬移、系統升級等）。
  /// 此時應立即重建一份並覆寫舊值，否則下次可能就完全失效。
  final bool isStale;

  /// 是否成功取得存取權。為 false 時 [path] 不可讀寫。
  final bool granted;
}

/// macOS security-scoped bookmark 的低階封裝。
///
/// 僅負責與原生端通訊，不涉及儲存或生命週期決策 —— 那是
/// `WorkspaceRepository` 的職責。
class SecureBookmark {
  const SecureBookmark();

  static const MethodChannel _channel = MethodChannel('app/secure_bookmark');

  /// 這是 macOS App Sandbox 專屬機制，其他平台沒有對應概念。
  static bool get isSupported => Platform.isMacOS;

  /// 為已授權的 [path] 建立可長期保存的憑證（base64 字串）。
  ///
  /// 呼叫前該路徑必須已透過開啟面板取得授權，否則原生端會擲出
  /// `create_failed`。
  Future<String> create(String path) async {
    final bookmark = await _channel.invokeMethod<String>('create', {
      'path': path,
    });
    if (bookmark == null) {
      throw StateError('原生端未回傳 bookmark');
    }
    return bookmark;
  }

  /// 解回 [bookmark] 並開始存取。
  ///
  /// 每次成功呼叫都必須有對應的 [stopAccessing]，否則會耗盡系統對同時
  /// 存取數量的配額。
  Future<BookmarkResolution> resolve(String bookmark) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('resolve', {
      'bookmark': bookmark,
    });
    if (raw == null) {
      throw StateError('原生端未回傳解析結果');
    }
    return BookmarkResolution(
      path: raw['path'] as String,
      isStale: raw['isStale'] as bool,
      granted: raw['granted'] as bool,
    );
  }

  /// 釋放 [path] 的存取權。
  Future<void> stopAccessing(String path) =>
      _channel.invokeMethod<void>('stopAccessing', {'path': path});

  /// 釋放所有存取權。App 結束前應呼叫一次。
  Future<void> stopAll() => _channel.invokeMethod<void>('stopAll');
}
