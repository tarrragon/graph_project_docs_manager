/// SPEC-010 FR-04～FR-06、NFR-01：共用 structured log writer。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_file_port.dart';
import 'package:graph_project_docs_manager/observability/log_record_encoder.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// 轉呼 developer.log 的函式簽名；測試以記錄器取代。
typedef DevLogFn = void Function(
  String message, {
  required String name,
  required int level,
  Object? error,
  StackTrace? stackTrace,
});

void _defaultDevLog(
  String message, {
  required String name,
  required int level,
  Object? error,
  StackTrace? stackTrace,
}) => developer.log(
  message,
  name: name,
  level: level,
  error: error,
  stackTrace: stackTrace,
);

const int _mebibyte = 1024 * 1024;
const String _currentFileName = 'app.jsonl';
const String _writerDomain = 'observability';
const String _recordRejectedCode = 'recordRejected';

/// 寫檔降級原因，值即 SPEC-010〈錯誤處理〉的錯誤碼。
enum LogDegradeReason { logDirUnavailable, logWriteFailed }

/// 共用 writer；寫入在單一佇列內依序執行。
///
/// [port] 為 null 表示日誌目錄無法決定（例如取不到 bundle id），直接降級。
class LogWriter {
  LogWriter({
    required this.port,
    this.devLog = _defaultDevLog,
    DateTime Function()? clock,
    this.rotateBytes = 5 * _mebibyte,
    this.historyCount = 4,
  }) : _clock = clock ?? DateTime.now;

  final LogFilePort? port;
  final DevLogFn devLog;
  final DateTime Function() _clock;
  final int rotateBytes;
  final int historyCount;

  Future<void> _tail = Future<void>.value();
  bool _degraded = false;
  bool _directoryReady = false;

  /// 發出一筆記錄；永不拋出。
  void log(
    String domain,
    Enum event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final String line;
    try {
      line = encodeLogRecord(
        now: _clock(),
        level: level,
        domain: domain,
        event: event,
        fields: fields,
        source: source,
        error: error,
      );
    } on ArgumentError {
      _warn(_recordRejectedCode);
      return;
    }
    devLog(
      '${event.name} ${jsonEncode(fields.toJson())}',
      name: domain,
      level: level.devLogLevel,
      error: error,
      stackTrace: stackTrace,
    );
    if (level.devLogLevel < LogLevel.info.devLogLevel) return;
    _tail = _tail.then((_) => _writeLine(line));
  }

  /// 等待佇列清空（測試與關閉時使用）。
  Future<void> flush() => _tail;

  Future<void> _writeLine(String line) async {
    final target = port;
    if (target == null) return _degrade(LogDegradeReason.logDirUnavailable);
    if (_degraded) return;
    if (!_directoryReady) {
      try {
        await target.ensureDirectory();
        _directoryReady = true;
      } on Object {
        return _degrade(LogDegradeReason.logDirUnavailable);
      }
    }
    try {
      await _rotateIfNeeded(target);
      await target.append(_currentFileName, line);
    } on Object {
      _degrade(LogDegradeReason.logWriteFailed);
    }
  }

  Future<void> _rotateIfNeeded(LogFilePort port) async {
    if (await port.sizeOf(_currentFileName) < rotateBytes) return;
    final oldest = _historyName(historyCount);
    if (await port.exists(oldest)) await port.delete(oldest);
    for (var n = historyCount - 1; n >= 1; n--) {
      final from = _historyName(n);
      if (await port.exists(from)) await port.rename(from, _historyName(n + 1));
    }
    await port.rename(_currentFileName, _historyName(1));
  }

  String _historyName(int n) => 'app.$n.jsonl';

  /// 降級原因每個 session 只報一次（NFR-01）。
  void _degrade(LogDegradeReason reason) {
    if (_degraded) return;
    _degraded = true;
    _warn(reason.name);
  }

  void _warn(String message) =>
      devLog(message, name: _writerDomain, level: LogLevel.warning.devLogLevel);
}
