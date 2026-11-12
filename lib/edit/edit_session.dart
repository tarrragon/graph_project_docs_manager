import 'dart:developer' as developer;
import 'dart:io' show pid;
import 'dart:math';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

const String _tag = 'edit.session';
const int _errorLevel = 900;
const int _randomTailRange = 1 << 32; // magic-exempt
final RegExp _shaPattern = RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$');

/// 改寫函式（可注入；預設 [rewriteFrontmatterField]）。
typedef FieldRewriter = FieldRewriteResult Function({
  required Uint8List original,
  required String field,
  required String? newValue,
  required DateTime today,
});

/// 寫入前閘門依賴的外部世界。
class EditGateContext {
  const EditGateContext({
    required this.files,
    required this.git,
    required this.now,
    required this.rewriter,
  });

  final EditFilePort files;
  final EditGitRunner git;
  final DateTime Function() now;
  final FieldRewriter rewriter;
}

class _Step<T> {
  const _Step.ok(this.value) : stop = null;
  const _Step.stop(this.stop) : value = null;

  final T? value;
  final WriteResult? stop;
}

/// 需求：[SPEC-009 FR-01～FR-03] 一次編輯 session：持有開始編輯時讀入的 M，
/// 每次寫入依序執行閘門六步（讀 W 比 M、改寫隔離、取 H 與快照、寫暫存檔、
/// 重讀、rename）。M 只在開始編輯與 `written` 時設定。
class EditSession {
  EditSession(this._context, this._path, Uint8List baseline)
    : _baseline = baseline;

  final EditGateContext _context;
  final WorkspaceRelativePath _path;
  Uint8List _baseline;

  /// 目前的 M。
  Uint8List get baseline => _baseline;

  /// 寫入 [field]；[newValue] 為 null 表示清空（寫成 YAML null）。
  Future<WriteResult> writeField({
    required String field,
    required String? newValue,
  }) async {
    final disk = await _readDisk(IoOperation.readTarget);
    if (disk.stop != null) return disk.stop!;
    final current = disk.value!;
    if (!_sameBytes(current, _baseline)) {
      return const Blocked(BlockedReason.externallyModified);
    }
    final rewritten = _context.rewriter(
      original: current,
      field: field,
      newValue: newValue,
      today: _context.now(),
    );
    if (rewritten is! FieldRewritten) {
      return const Blocked(BlockedReason.rewriteNotIsolated);
    }
    final snapshot = await _snapshotUnlessInHead(current);
    if (snapshot.stop != null) return snapshot.stop!;
    return _commit(current, rewritten.bytes, snapshot.value);
  }

  Future<_Step<Uint8List>> _readDisk(IoOperation operation) async {
    try {
      return _Step.ok(await _context.files.read(_path.absolute));
    } on EditFileException catch (error) {
      if (error.notFound) {
        return const _Step.stop(Blocked(BlockedReason.externallyModified));
      }
      _log(
        'read failed: ${operation.name} code=${error.errorCode}',
      ); // i18n-exempt
      return _Step.stop(
        IoFailed(IoFailure(operation, errorCode: error.errorCode)),
      );
    }
  }

  /// H 存在且與 W 逐位元組相同時不快照；其餘（H 不存在、無法判定、逾時、
  /// git 無法啟動）一律走快照。
  Future<_Step<String?>> _snapshotUnlessInHead(Uint8List current) async {
    final head = await _context.git.run(['show', 'HEAD:./${_path.relative}']);
    if (head != null &&
        head.exitCode == 0 &&
        _sameBytes(head.stdout, current)) {
      return const _Step.ok(null);
    }
    final sha = await _hashObject(current);
    return sha == null
        ? const _Step.stop(Blocked(BlockedReason.snapshotFailed))
        : _Step.ok(sha);
  }

  Future<String?> _hashObject(Uint8List current) async {
    final result = await _context.git.run([
      'hash-object',
      '-w',
      '--stdin',
    ], stdin: current);
    if (result == null || result.exitCode != 0) return null;
    final sha = String.fromCharCodes(result.stdout).trim();
    return _shaPattern.hasMatch(sha) ? sha : null;
  }

  Future<WriteResult> _commit(
    Uint8List current,
    Uint8List next,
    String? sha,
  ) async {
    final temp = _tempPath();
    final failure =
        await _writeTemp(temp, next) ?? await _recheckAndRename(temp, current);
    if (failure != null) {
      await _context.files.delete(temp);
      return failure;
    }
    _baseline = next;
    return Written(snapshotSha: sha);
  }

  Future<WriteResult?> _writeTemp(String temp, Uint8List next) async {
    final files = _context.files;
    final mode = await files.mode(_path.absolute);
    return await _attempt(
          IoOperation.writeTemp,
          () => files.write(temp, next),
        ) ??
        await _attempt(IoOperation.syncTemp, () => files.fsync(temp)) ??
        (mode == null
            ? null
            : await _attempt(
                IoOperation.setMode,
                () => files.setMode(temp, mode),
              ));
  }

  Future<WriteResult?> _recheckAndRename(String temp, Uint8List current) async {
    final disk = await _readDisk(IoOperation.readBeforeRename);
    if (disk.stop != null) return disk.stop;
    if (!_sameBytes(disk.value!, current)) {
      return const Blocked(BlockedReason.externallyModified);
    }
    return _attempt(
      IoOperation.rename,
      () => _context.files.rename(temp, _path.absolute),
    );
  }

  Future<WriteResult?> _attempt(
    IoOperation operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return null;
    } on EditFileException catch (error) {
      _log(
        'io failed: ${operation.name} code=${error.errorCode}',
      ); // i18n-exempt
      return IoFailed(IoFailure(operation, errorCode: error.errorCode));
    }
  }

  /// 暫存檔與目標檔同目錄；以 `.` 開頭、帶行程 ID 與隨機尾碼、不以 `.md` 結尾。
  String _tempPath() {
    final absolute = _path.absolute;
    final slash = absolute.lastIndexOf('/');
    final tail = Random.secure().nextInt(_randomTailRange).toRadixString(16);
    return '${absolute.substring(0, slash + 1)}'
        '.${absolute.substring(slash + 1)}.$pid.$tail.tmp';
  }

  void _log(String message) =>
      developer.log(message, name: _tag, level: _errorLevel);
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
