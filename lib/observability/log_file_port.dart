/// SPEC-010 FR-05：日誌檔案系統 port 與 dart:io 實作。
library;

import 'dart:io';

/// writer 對檔案系統的唯一依賴；測試以記憶體實作替換。
abstract class LogFilePort {
  /// 目錄不存在時建立。
  Future<void> ensureDirectory();

  /// 檔案大小（位元組）；不存在回 0。
  Future<int> sizeOf(String name);

  Future<bool> exists(String name);

  Future<void> append(String name, String line);

  Future<void> rename(String from, String to);

  Future<void> delete(String name);
}

/// 日誌目錄 `<home>/Library/Logs/<bundleId>`（無結尾斜線）。
String logDirectoryPath({required String home, required String bundleId}) =>
    '$home/Library/Logs/$bundleId';

/// 從 macOS App 的 Info.plist 於執行期取得 bundle id；取不到回 null。
String? resolveBundleIdFromExecutable(String resolvedExecutable) {
  final macOsDir = File(resolvedExecutable).parent;
  final plist = File('${macOsDir.parent.path}/Info.plist');
  try {
    final text = plist.readAsStringSync();
    final match = RegExp(
      r'<key>CFBundleIdentifier</key>\s*<string>([^<]+)</string>',
    ).firstMatch(text);
    return match?.group(1);
  } on FileSystemException {
    // 非 .app 啟動（例如 flutter test）沒有 Info.plist，由呼叫端降級。
    return null;
  }
}

/// 以 dart:io 實作的 port。
final class IoLogFilePort implements LogFilePort {
  IoLogFilePort(this.directory);

  final String directory;

  File _file(String name) => File('$directory/$name');

  @override
  Future<void> ensureDirectory() async {
    await Directory(directory).create(recursive: true);
  }

  @override
  Future<int> sizeOf(String name) async {
    final f = _file(name);
    return await f.exists() ? await f.length() : 0;
  }

  @override
  Future<bool> exists(String name) => _file(name).exists();

  @override
  Future<void> append(String name, String line) =>
      _file(name).writeAsString(line, mode: FileMode.append, flush: true);

  @override
  Future<void> rename(String from, String to) async {
    await _file(from).rename('$directory/$to');
  }

  @override
  Future<void> delete(String name) async {
    await _file(name).delete();
  }
}
