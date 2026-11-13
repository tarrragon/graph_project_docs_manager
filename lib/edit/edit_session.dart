import 'dart:async';
import 'dart:io' show pid;
import 'dart:math';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/corpus_parsed_source.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_validation.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/edit/session_write_list.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart'
    hide WorkspaceRelativePath;

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
    required this.writeList,
    required this.workspaceRoot,
    this.validator,
    this.logSink,
  });

  /// 所屬專案（工作區根），寫入清單的列據此標示所屬專案。
  final String workspaceRoot;

  final EditFilePort files;
  final EditGitRunner git;
  final DateTime Function() now;
  final FieldRewriter rewriter;

  /// 本 App session 的寫入清單（SPEC-009 FR-08）。
  final SessionWriteList writeList;

  /// 寫入後驗證（SPEC-009 FR-05）；null 表示不驗證。
  final EditValidatorRunner? validator;

  /// edit domain 日誌 sink；null 表示用共用 writer 的預設 sink。
  final LogSink<EditLogEvent>? logSink;
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
  EditSession(
    this._context,
    this._path,
    Uint8List baseline, {
    CorpusParsedSource? corpusParsed,
  }) : _baseline = baseline {
    _corpusSubscription = corpusParsed?.parsed.listen(
      (_) => unawaited(checkExternalChange()),
    );
    final runner = _context.validator;
    if (runner != null) {
      _validation = ValidationCoordinator(
        runner: runner,
        relativePath: _path.relative,
        onStatus: _onValidationStatus,
        logSink: _context.logSink,
      )..startBaseline();
    }
  }

  final EditGateContext _context;
  final WorkspaceRelativePath _path;
  Uint8List _baseline;
  ValidationCoordinator? _validation;
  ValidationStatus? _lastValidation;
  StreamSubscription<Object?>? _corpusSubscription;
  bool _externalChangeWarning = false;
  final List<WriteListEntry> _awaitingValidation = [];
  final StreamController<void> _warningChanges =
      StreamController<void>.broadcast(sync: true);

  /// 最近一次 rename 前，baseline 量測是否尚未完成（SPEC-009 FR-05 v1.7）。
  bool _baselinePendingAtRename = false;
  final StreamController<WriteObservation> _observations =
      StreamController<WriteObservation>.broadcast(sync: true);

  /// 目前的 M。
  Uint8List get baseline => _baseline;

  /// 寫入的三個可觀測時刻（SPEC-009 FR-05）：進行中、受理、驗證結果。
  Stream<WriteObservation> get observations => _observations.stream;

  /// 最近一次寫入後驗證的狀態；尚無寫入為 null。
  ValidationStatus? get lastValidationStatus => _lastValidation;

  /// 已排入的寫入後驗證全部完成（不含 baseline 量測）。
  Future<void> get validationIdle => _validation?.idle ?? Future.value();

  /// 開始編輯（或放棄並重讀）時的 baseline 量測完成或被丟棄。
  Future<void> get baselineIdle => _validation?.baselineIdle ?? Future.value();

  /// 外部已改預警（SPEC-009 FR-06）：預警不阻擋寫入、不捨棄未寫入值。
  bool get externalChangeWarning => _externalChangeWarning;

  /// 預警狀態轉換通知（false 轉 true，與放棄並重讀清除時發出）。
  Stream<void> get externalChangeWarningChanges => _warningChanges.stream;

  /// 需求：[SPEC-009 FR-06] 重讀正在編輯的檔案與 M 比較：不同或不存在即轉為
  /// 預警；相同或讀取失敗時狀態不變。判定只來自重讀內容，不讀事件負載。
  Future<void> checkExternalChange() async {
    final disk = await _readDisk(IoOperation.readTarget);
    final differs = switch (disk.stop) {
      null => !_sameBytes(disk.value!, _baseline),
      Blocked() => true, // notFound：視為 W != M
      _ => false, // 讀取失敗無法判定：狀態不變，由閘門把關
    };
    if (differs && !_externalChangeWarning) {
      _externalChangeWarning = true;
      _warningChanges.add(null);
    }
  }

  /// 結束編輯：取消 EVT-CORPUS-001 訂閱。
  Future<void> dispose() async => _corpusSubscription?.cancel();

  /// 放棄並重讀（SPEC-009 FR-06 的 M 與 baseline 部分）：以磁碟內容重新開始
  /// 編輯，M 改為新讀入的內容並重跑驗證 baseline。讀取失敗時回傳失敗分類，
  /// M 與 baseline 不變。
  Future<IoFailure?> discardAndReload() async {
    final disk = await _readDisk(IoOperation.readTarget);
    final stop = disk.stop;
    if (stop != null) {
      return stop is IoFailed ? stop.failure : null;
    }
    _baseline = disk.value!;
    if (_externalChangeWarning) {
      _externalChangeWarning = false;
      _warningChanges.add(null);
    }
    _validation?.startBaseline();
    return null;
  }

  /// 寫入 [field]；[newValue] 為 null 表示清空（寫成 YAML null）。
  ///
  /// 需求：[SPEC-009 FR-05] 受理為 `written` 後才啟動寫入後驗證；驗證非同步、
  /// 不阻擋本呼叫，結果由 [observations] 送出。
  Future<WriteResult> writeField({
    required String field,
    required String? newValue,
  }) async {
    final entry = _context.writeList.begin(
      relativePath: _path.relative,
      field: field,
      workspaceRoot: _context.workspaceRoot,
    );
    final result = await _gatedWrite(field, newValue);
    _logGateOutcome(result, field);
    _context.writeList.settle(entry, result);
    _observations.add(WriteAccepted(result));
    if (result is Written) {
      if (_validation != null) _awaitingValidation.add(entry);
      _validation?.validateAfterWrite(
        baselineWasPending: _baselinePendingAtRename,
      );
    }
    return result;
  }

  /// 驗證依序完成：`running` 屬最新一次寫入，終態依先進先出對應各列。
  void _updateWriteList(ValidationStatus status) {
    if (_awaitingValidation.isEmpty) return;
    final writeList = _context.writeList;
    if (status is ValidationRunning) {
      writeList.updateStatus(_awaitingValidation.last, status);
    } else {
      writeList.updateStatus(_awaitingValidation.removeAt(0), status);
    }
  }

  void _onValidationStatus(ValidationStatus status) {
    _updateWriteList(status);
    _lastValidation = status;
    _observations.add(ValidationObserved(status));
  }

  Future<WriteResult> _gatedWrite(String field, String? newValue) async {
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
    _logWriteIssued(field);
    _observations.add(const WriteInProgress());
    return _commit(current, rewritten.bytes, snapshot.value);
  }

  Future<_Step<Uint8List>> _readDisk(IoOperation operation) async {
    try {
      return _Step.ok(await _context.files.read(_path.absolute));
    } on EditFileException catch (error) {
      if (error.notFound) {
        return const _Step.stop(Blocked(BlockedReason.externallyModified));
      }
      _logIoFailed(EditLogEvent.readIoFailed, operation, error.errorCode);
      return _Step.stop(
        IoFailed(IoFailure(operation, errorCode: error.errorCode)),
      );
    }
  }

  /// H 存在且與 W 逐位元組相同時不快照；其餘（H 不存在、無法判定、逾時、
  /// git 無法啟動）一律走快照。`git show` 失敗不記失敗事件（SPEC-009 FR-07）。
  Future<_Step<String?>> _snapshotUnlessInHead(Uint8List current) async {
    final head = await _context.git.run(['show', 'HEAD:./${_path.relative}']);
    if (head is EditGitCompleted &&
        head.result.exitCode == 0 &&
        _sameBytes(head.result.stdout, current)) {
      return const _Step.ok(null);
    }
    final hashed = await _hashObject(current);
    final failure = hashed.failure;
    if (failure != null) {
      _logSnapshotFailed(failure);
      return const _Step.stop(Blocked(BlockedReason.snapshotFailed));
    }
    _logSnapshotTaken(hashed.sha!);
    return _Step.ok(hashed.sha);
  }

  /// `hash-object` 的結局：成功帶 [sha]，失敗帶三擇一的 [failure]
  /// （SPEC-009 FR-07〈`snapshotFailed` 的三擇一〉）。
  Future<({String? sha, Map<String, LogValue>? failure})> _hashObject(
    Uint8List current,
  ) async {
    final outcome = await _context.git.run([
      'hash-object',
      '-w',
      '--stdin',
    ], stdin: current);
    return switch (outcome) {
      EditGitLaunchFailed() || EditGitRunFailed() => (
        sha: null,
        failure: {EditLogKeys.executableMissing: const LogValue.boolean(true)},
      ),
      EditGitTimedOut() => (
        sha: null,
        failure: {EditLogKeys.timedOut: const LogValue.boolean(true)},
      ),
      EditGitCompleted(:final result) => _hashResult(result),
    };
  }

  ({String? sha, Map<String, LogValue>? failure}) _hashResult(
    EditGitResult result,
  ) {
    final sha = String.fromCharCodes(result.stdout).trim();
    if (result.exitCode == 0 && _shaPattern.hasMatch(sha)) {
      return (sha: sha, failure: null);
    }
    return (
      sha: null,
      failure: {EditLogKeys.exitCode: LogValue.integer(result.exitCode)},
    );
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
      await _deleteTemp(temp);
      return failure;
    }
    _baseline = next;
    return Written(snapshotSha: sha);
  }

  /// 刪除暫存檔；失敗是獨立失敗（留下殘檔），另記一筆 `tempDeleteFailed`。
  Future<void> _deleteTemp(String temp) async {
    try {
      await _context.files.delete(temp);
    } on EditFileException catch (error) {
      final errorCode = error.errorCode;
      _emit(
        EditLogEvent.tempDeleteFailed,
        {
          if (errorCode != null)
            EditLogKeys.errorCode: LogValue.integer(errorCode),
        },
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
      );
    }
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
    _baselinePendingAtRename = _validation?.baselinePending ?? false;
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
      _logIoFailed(EditLogEvent.writeIoFailed, operation, error.errorCode);
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

  /// 每次呼叫才取 sink，不在建立時捕捉 writer（553.2.3.4.4）。
  void _emit(
    EditLogEvent event,
    Map<String, LogValue> fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
  }) => (_context.logSink ?? defaultEditLogSink())(
    event,
    LogFields({EditLogKeys.path: editLogPath(_path.relative), ...fields}),
    level: level,
    source: source,
  );

  void _logWriteIssued(String field) => _emit(EditLogEvent.writeIssued, {
    EditLogKeys.field: LogValue.fieldName(field),
  });

  /// 受理只在位元組落檔時記；失敗結局已各記一筆失敗事件（一次失敗一筆）。
  void _logGateOutcome(WriteResult result, String field) {
    switch (result) {
      case Written():
        _emit(EditLogEvent.writeAccepted, {
          EditLogKeys.field: LogValue.fieldName(field),
        });
      case Blocked(:final reason) when reason != BlockedReason.snapshotFailed:
        _emit(
          EditLogEvent.writeBlocked,
          {EditLogKeys.reason: LogValue.enumValue(reason)},
          level: LogLevel.warning,
          source: ErrorSource.gateBlocked,
        );
      case _:
        break;
    }
  }

  void _logSnapshotTaken(String sha) => _emit(EditLogEvent.snapshotTaken, {
    EditLogKeys.blobSha: LogValue.commitSha(sha),
  });

  void _logSnapshotFailed(Map<String, LogValue> failure) => _emit(
    EditLogEvent.writeBlocked,
    {
      EditLogKeys.reason: const LogValue.enumValue(
        BlockedReason.snapshotFailed,
      ),
      ...failure,
    },
    level: LogLevel.error,
    source: ErrorSource.externalProcess,
  );

  void _logIoFailed(
    EditLogEvent event,
    IoOperation operation,
    int? errorCode,
  ) => _emit(
    event,
    {
      EditLogKeys.operation: LogValue.enumValue(operation),
      if (errorCode != null) EditLogKeys.errorCode: LogValue.integer(errorCode),
    },
    level: LogLevel.error,
    source: ErrorSource.platformIo,
  );
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
