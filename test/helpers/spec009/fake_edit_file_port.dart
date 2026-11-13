import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_file_port.dart';

/// 一次檔案操作的記錄。
class FileOp {
  const FileOp(this.kind, this.path);

  final String kind;
  final String path;

  @override
  String toString() => '$kind:$path';
}

/// 需求：[SPEC-009-test-design §1.4] 記憶體檔案集合；記錄操作序列；可指定
/// 「第 n 次讀取回傳指定內容／失敗」「指定操作失敗」「指定操作完成後改動
/// 目標檔」。讀取次數自 [resetCounters] 起算（從 1 開始）。
class FakeEditFilePort implements EditFilePort {
  final Map<String, Uint8List> files = {};
  final Map<String, int> modes = {};
  final List<FileOp> ops = [];

  /// 第 n 次讀取的腳本：[Uint8List]、[EditFileException]、[Future<Uint8List>]。
  final Map<int, Object> readScript = {};
  final Map<String, EditFileException> _opFaults = {};
  final Map<String, void Function()> _afterOp = {};
  int _reads = 0;

  void resetCounters() {
    ops.clear();
    _reads = 0;
    readScript.clear();
  }

  /// 指定操作種類（write／fsync／setMode／rename／delete）一律失敗。
  void failOp(String kind, {int? errorCode = 5}) =>
      _opFaults[kind] = EditFileException(errorCode: errorCode);

  /// 指定操作種類完成後執行 [action]（例：外部改動目標檔）。
  void afterOp(String kind, void Function() action) => _afterOp[kind] = action;

  void clearFaults() => _opFaults.clear();

  List<String> get kinds => [for (final op in ops) op.kind];

  void _record(String kind, String path) {
    ops.add(FileOp(kind, path));
    final fault = _opFaults[kind];
    if (fault != null) throw fault;
  }

  void _after(String kind) => _afterOp[kind]?.call();

  @override
  Future<Uint8List> read(String path) async {
    ops.add(FileOp('read', path));
    final script = readScript[++_reads];
    if (script is EditFileException) throw script;
    if (script is Uint8List) return script;
    if (script is Future<Uint8List>) return script;
    final bytes = files[path];
    if (bytes == null) throw const EditFileException(notFound: true);
    return Uint8List.fromList(bytes);
  }

  @override
  Future<int?> mode(String path) async => modes[path];

  @override
  Future<void> write(String path, Uint8List bytes) async {
    _record('write', path);
    files[path] = Uint8List.fromList(bytes);
    _after('write');
  }

  @override
  Future<void> fsync(String path) async {
    _record('fsync', path);
    _after('fsync');
  }

  @override
  Future<void> setMode(String path, int mode) async {
    _record('setMode', path);
    modes[path] = mode;
  }

  @override
  Future<void> rename(String from, String to) async {
    _record('rename', '$from->$to');
    files[to] = files.remove(from)!;
    final mode = modes.remove(from);
    if (mode != null) modes[to] = mode;
    _after('rename');
  }

  @override
  Future<void> delete(String path) async {
    _record('delete', path);
    files.remove(path);
    modes.remove(path);
  }
}
