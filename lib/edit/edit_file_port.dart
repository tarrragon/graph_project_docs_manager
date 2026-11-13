/// Edit 的檔案系統 port（SPEC-009 FR-01、FR-03）。
///
/// 每個方法對應「寫入前閘門」的一個步驟，使測試可以記錄操作序列、指定步驟
/// 失敗，或在指定步驟之後改動目標檔。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

const int _modeMask = 4095; // 0o7777

/// 檔案操作失敗。[notFound] 為檔案不存在；其他失敗帶 [errorCode]（可能為空）。
class EditFileException implements Exception {
  const EditFileException({this.notFound = false, this.errorCode});

  final bool notFound;
  final int? errorCode;

  @override
  String toString() => 'EditFileException(notFound: $notFound, $errorCode)';
}

/// 檔案系統 driven port。
abstract interface class EditFilePort {
  Future<Uint8List> read(String path);

  /// 原檔權限位元；無法取得時回傳 null。
  Future<int?> mode(String path);

  Future<void> write(String path, Uint8List bytes);

  Future<void> fsync(String path);

  Future<void> setMode(String path, int mode);

  Future<void> rename(String from, String to);

  /// 刪除檔案；檔案不存在不視為失敗。
  Future<void> delete(String path);
}

/// 以 `dart:io` 實作。
class IoEditFilePort implements EditFilePort {
  const IoEditFilePort({this._logSink});

  final LogSink<EditLogEvent>? _logSink;

  @override
  Future<Uint8List> read(String path) =>
      _guard(() async => await File(path).readAsBytes());

  @override
  Future<int?> mode(String path) async {
    final stat = await FileStat.stat(path);
    return stat.type == FileSystemEntityType.notFound
        ? null
        : stat.mode & _modeMask;
  }

  @override
  Future<void> write(String path, Uint8List bytes) =>
      _guard(() => File(path).writeAsBytes(bytes, flush: false));

  @override
  Future<void> fsync(String path) => _guard(() async {
    final handle = await File(path).open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  });

  @override
  Future<void> setMode(String path, int mode) => _guard(() async {
    final result = await Process.run('chmod', [mode.toRadixString(8), path]);
    if (result.exitCode != 0) {
      throw EditFileException(errorCode: result.exitCode);
    }
  });

  @override
  Future<void> rename(String from, String to) =>
      _guard(() => File(from).rename(to));

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on PathNotFoundException {
      return;
    } on FileSystemException catch (error) {
      final errorCode = error.osError?.errorCode;
      (_logSink ?? defaultEditLogSink())(
        EditLogEvent.tempDeleteFailed,
        errorCode == null
            ? LogFields.empty
            : LogFields({EditLogKeys.errorCode: LogValue.integer(errorCode)}),
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
        error: error,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PathNotFoundException {
      throw const EditFileException(notFound: true);
    } on FileSystemException catch (error) {
      throw EditFileException(errorCode: error.osError?.errorCode);
    }
  }
}
