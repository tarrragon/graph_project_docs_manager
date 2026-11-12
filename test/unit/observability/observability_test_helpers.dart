import 'package:graph_project_docs_manager/observability/log_file_port.dart';

/// 測試專用事件 enum（SPEC-010 test-design §1.4）。
enum TestEvent { sampleCompleted, sampleFailed }

/// 固定時鐘。
DateTime fixedClock() => DateTime.utc(2026, 11, 10, 13, 52, 6, 123);

const String secretMarker = 'SECRET-CONTENT-7f3a';

/// 記錄每次轉呼 developer.log 的參數。
class RecordingDevLog {
  final List<DevLogCall> calls = [];

  void call(
    String message, {
    required String name,
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) => calls.add(DevLogCall(message, name, level, error, stackTrace));

  List<DevLogCall> get warnings => calls.where((c) => c.level == 900).toList();
}

class DevLogCall {
  DevLogCall(this.message, this.name, this.level, this.error, this.stackTrace);
  final String message;
  final String name;
  final int level;
  final Object? error;
  final StackTrace? stackTrace;
}

/// 記憶體檔案系統；檔案內容以字串保存，大小以 UTF-8 長度之外的假值可覆寫。
class FakeLogFilePort implements LogFilePort {
  final Map<String, String> files = {};
  final Map<String, int> sizeOverride = {};
  bool failEnsureDirectory = false;
  bool failAppendAfter = false;
  bool failRename = false;
  int ensureCalls = 0;
  int appendCount = 0;

  /// 第 n 次（1 起算）append 之後的 append 皆失敗；null 表示不失敗。
  int? failAppendFrom;

  @override
  Future<void> ensureDirectory() async {
    ensureCalls++;
    if (failEnsureDirectory) throw StateError('mkdir failed');
  }

  @override
  Future<int> sizeOf(String name) async =>
      sizeOverride[name] ?? (files[name]?.length ?? 0);

  @override
  Future<bool> exists(String name) async => files.containsKey(name);

  @override
  Future<void> append(String name, String line) async {
    appendCount++;
    if (failAppendFrom != null && appendCount >= failAppendFrom!) {
      throw StateError('write failed');
    }
    files[name] = (files[name] ?? '') + line;
    sizeOverride.remove(name);
  }

  @override
  Future<void> rename(String from, String to) async {
    if (failRename) throw StateError('rename failed');
    files[to] = files.remove(from)!;
    final size = sizeOverride.remove(from);
    if (size != null) sizeOverride[to] = size;
  }

  @override
  Future<void> delete(String name) async {
    files.remove(name);
    sizeOverride.remove(name);
  }
}
