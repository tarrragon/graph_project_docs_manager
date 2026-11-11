/// History 的 git 程序 driven port（SPEC-008 FR-01、FR-08、FR-10）。
///
/// 前置檢查以結束碼與結構化輸出分類，不比對 stderr 文字；掃描行程可取消；
/// 行程啟動、結束、終止逐點記 `developer.log`（observability 規則 5）。
library;

import 'dart:async';

import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/git/git_scan_command.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// tripwire 閾值（FR-10 規則 2）：輸出位元組數超過 256 MiB。
const int tripwireOutputBytes = 256 * 1024 * 1024;

/// stderr 摘要的最大字元數。
const int stderrSummaryMaxChars = 512;

const int _commitHeaderMarker = 0x1e;

String summarizeStderr(String stderr) => stderr.length <= stderrSummaryMaxChars
    ? stderr
    : stderr.substring(0, stderrSummaryMaxChars);

/// 發出一筆事件（事件名是穩定契約）；負載值只收 FR-03 白名單型別。
void _emit(
  LogSink<HistoryLogEvent> sink,
  HistoryLogEvent event,
  Map<String, LogValue> payload, {
  LogLevel level = LogLevel.info,
}) => sink(event, LogFields(payload), level: level);

/// 一次性呼叫無法啟動：不記 `GitLaunchException.message`（自由文字）。
void _emitLaunchFailed(LogSink<HistoryLogEvent> sink) => _emit(
  sink,
  HistoryLogEvent.processLaunchFailed,
  const {},
  level: LogLevel.warning,
);

/// [GitHistoryPort.open] 的結果。
sealed class GitOpenOutcome {
  const GitOpenOutcome();
}

/// Schema 阻擋：未呼叫任何 git。
final class GitOpenBlocked extends GitOpenOutcome {
  const GitOpenBlocked();
}

/// 前置檢查未達正常（非 git 專案、找不到 git、尚無 commit、讀取失敗）。
final class GitOpenStopped extends GitOpenOutcome {
  const GitOpenStopped(this.outcome);

  final GitPreflightOutcome outcome;
}

/// 已啟動掃描。
final class GitOpenScanning extends GitOpenOutcome {
  const GitOpenScanning({
    required this.ready,
    required this.scan,
    required this.isBuiltinTableDegraded,
  });

  final GitPreflightReady ready;
  final GitScan scan;

  /// Schema 以內建型別表降級（FR-08 規則 6）。
  final bool isBuiltinTableDegraded;
}

/// 前置檢查中途的診斷資訊（僅供日誌）。
class _Diagnostics {
  String version = '';
  int? exitCode;
  String stderr = '';
}

class GitHistoryPort {
  GitHistoryPort({
    required GitProcessRunner runner,
    LogSink<HistoryLogEvent>? logSink,
  }) : _runner = runner, // ignore: prefer_initializing_formals
       _log = logSink ?? defaultHistoryLogSink;

  final GitProcessRunner _runner;
  final LogSink<HistoryLogEvent> _log;

  /// Schema 就緒度決定是否進入 git；阻擋時不呼叫任何 git（FR-08 規則 6）。
  Future<GitOpenOutcome> open({
    required String root,
    required HistorySchemaReadiness schema,
  }) async {
    if (schema == HistorySchemaReadiness.blocked) {
      _emit(_log, HistoryLogEvent.degraded, {
        HistoryLogKeys.reason: const LogEnumValue(
          HistoryDegradeReason.schemaBlocked,
        ),
      }, level: LogLevel.warning);
      return const GitOpenBlocked();
    }
    final outcome = await preflight(root);
    if (outcome is! GitPreflightReady) return GitOpenStopped(outcome);
    final scan = await startScan(root, outcome);
    return GitOpenScanning(
      ready: outcome,
      scan: scan,
      isBuiltinTableDegraded:
          schema == HistorySchemaReadiness.degradedBuiltinTable,
    );
  }

  /// 前置檢查（FR-01 規則 2）：版本 → 工作樹 → HEAD → 主線 → tag。
  Future<GitPreflightOutcome> preflight(String root) async {
    _emit(_log, HistoryLogEvent.preflightEntered, const {});
    final diagnostics = _Diagnostics();
    final outcome = await _classify(root, diagnostics);
    _logPreflightResult(outcome, diagnostics);
    return outcome;
  }

  Future<GitPreflightOutcome> _classify(String root, _Diagnostics diag) async {
    final version = await _runOrNull(gitVersionInvocation(root));
    if (version == null) return const GitPreflightGitNotFound();
    if (version.exitCode != 0) return _failed(version, diag);
    final supported = isSupportedGitVersion(version.stdout);
    if (supported == null) {
      return const GitPreflightFailed(
        reason: GitFailureReason.gitVersionUnreadable,
      );
    }
    diag.version = gitVersionNumber(version.stdout);
    if (!supported) {
      return const GitPreflightFailed(
        reason: GitFailureReason.gitVersionTooOld,
      );
    }
    return _classifyRepository(root, diag);
  }

  Future<GitPreflightOutcome> _classifyRepository(
    String root,
    _Diagnostics diag,
  ) async {
    final tree = await _runOrNull(gitWorkTreeInvocation(root));
    if (tree == null) return const GitPreflightGitNotFound();
    final flags = tree.stdout.split('\n').map((l) => l.trim()).toList();
    if (tree.exitCode != 0 || flags.first != 'true') {
      diag
        ..exitCode = tree.exitCode
        ..stderr = summarizeStderr(tree.stderr);
      return const GitPreflightNotWorkTree();
    }
    final isShallow = flags.length > 1 && flags[1] == 'true';
    final head = await _runOrNull(gitHeadInvocation(root));
    if (head == null) return const GitPreflightGitNotFound();
    if (head.exitCode == 1) {
      diag.exitCode = 1;
      return GitPreflightNoCommit(gitVersion: diag.version);
    }
    if (head.exitCode != 0) return _failed(head, diag);
    return _collectRefs(root, diag, isShallow, head.stdout.trim());
  }

  Future<GitPreflightOutcome> _collectRefs(
    String root,
    _Diagnostics diag,
    bool isShallow,
    String head,
  ) async {
    final mainline = await _runOrNull(gitMainlineInvocation(root));
    if (mainline == null) return const GitPreflightGitNotFound();
    if (mainline.exitCode != 0) return _failed(mainline, diag);
    final tags = await _runOrNull(gitTagsInvocation(root));
    if (tags == null) return const GitPreflightGitNotFound();
    if (tags.exitCode != 0) return _failed(tags, diag);
    return GitPreflightReady(
      gitVersion: diag.version,
      isShallow: isShallow,
      head: head,
      mainline: _lines(mainline.stdout),
      tags: _parseTags(tags.stdout),
    );
  }

  GitPreflightFailed _failed(GitCommandResult result, _Diagnostics diag) {
    final summary = summarizeStderr(result.stderr);
    diag
      ..exitCode = result.exitCode
      ..stderr = summary;
    return GitPreflightFailed(
      reason: GitFailureReason.preflightCommandFailed,
      exitCode: result.exitCode,
      stderrSummary: summary,
    );
  }

  static List<String> _lines(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  static List<GitTagRef> _parseTags(String text) {
    final tags = <GitTagRef>[];
    for (final line in _lines(text)) {
      final fields = line.split('\u0000');
      if (fields.length < 2) continue;
      final peeled = fields.length > 2 ? fields[2] : '';
      tags.add(
        GitTagRef(
          name: fields[0],
          commitId: peeled.isEmpty ? fields[1] : peeled,
        ),
      );
    }
    return tags;
  }

  /// 執行一次性呼叫；無法啟動回傳 null（FR-08 規則 2）。
  Future<GitCommandResult?> _runOrNull(GitInvocation invocation) async {
    _emit(_log, HistoryLogEvent.processStarted, {
      HistoryLogKeys.argumentCount: LogValue.integer(
        invocation.arguments.length,
      ),
    }, level: LogLevel.debug);
    try {
      final result = await _runner.run(invocation);
      _emit(_log, HistoryLogEvent.processExited, {
        HistoryLogKeys.exitCode: LogValue.integer(result.exitCode),
      }, level: LogLevel.debug);
      return result;
    } on GitLaunchException {
      _emitLaunchFailed(_log);
      return null;
    }
  }

  void _logPreflightResult(GitPreflightOutcome outcome, _Diagnostics diag) {
    final category = LogEnumValue(switch (outcome) {
      GitPreflightReady() => HistoryLogCategory.ready,
      GitPreflightNotWorkTree() => HistoryLogCategory.notWorkTree,
      GitPreflightGitNotFound() => HistoryLogCategory.gitNotFound,
      GitPreflightNoCommit() => HistoryLogCategory.noCommit,
      GitPreflightFailed() => HistoryLogCategory.failed,
    });
    _emit(_log, HistoryLogEvent.preflightResult, {
      HistoryLogKeys.category: category,
    });
    if (outcome is GitPreflightReady) return;
    final exitCode = diag.exitCode;
    _emit(_log, HistoryLogEvent.degraded, {
      HistoryLogKeys.category: category,
      if (exitCode != null) HistoryLogKeys.exitCode: LogValue.integer(exitCode),
    }, level: LogLevel.warning);
  }

  /// 啟動掃描（FR-01 規則 3）。啟動失敗時回傳結果為 [GitScanFailed] 的掃描。
  Future<GitScan> startScan(String root, GitPreflightReady ready) async {
    final invocation = gitScanInvocation(root);
    _emit(_log, HistoryLogEvent.scanStarted, {
      HistoryLogKeys.head: LogValue.commitSha(ready.head),
    });
    _emit(_log, HistoryLogEvent.processStarted, {
      HistoryLogKeys.argumentCount: LogValue.integer(
        invocation.arguments.length,
      ),
    }, level: LogLevel.debug);
    try {
      final process = await _runner.start(invocation);
      return GitScan._(process, _log);
    } on GitLaunchException {
      _emitLaunchFailed(_log);
      return GitScan._failedToLaunch(_log);
    }
  }
}

/// 一次進行中（或已結束）的掃描。
///
/// 呼叫端必須訂閱 [stdout]（單訂閱）；取消後部分輸出不再外露。
class GitScan {
  GitScan._(GitScanProcess process, this._log) : _process = process {
    _stopwatch.start();
    final subscription = process.stdout.listen(
      _onData,
      onError: _onStreamError,
      onDone: _onDone,
      cancelOnError: true,
    );
    _subscription = subscription;
    _controller
      ..onPause = subscription.pause
      ..onResume = subscription.resume;
  }

  GitScan._failedToLaunch(this._log) : _process = null {
    _controller.close();
    _finish(
      const GitScanFailed(
        reason: GitFailureReason.scanLaunchFailed,
        exitCode: -1,
        stderrSummary: '',
      ),
    );
  }

  final GitScanProcess? _process;
  final LogSink<HistoryLogEvent> _log;
  final Stopwatch _stopwatch = Stopwatch();
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  final Completer<GitScanResult> _result = Completer<GitScanResult>();
  StreamSubscription<List<int>>? _subscription;
  int _bytes = 0;
  int _commits = 0;
  bool _tripwireLogged = false;
  bool _cancelled = false;

  /// 掃描輸出位元組串流。
  Stream<List<int>> get stdout => _controller.stream;

  /// 結束結果：完成、讀取失敗或已取消。
  Future<GitScanResult> get result => _result.future;

  void _onData(List<int> chunk) {
    if (_cancelled) return;
    _bytes += chunk.length;
    for (final byte in chunk) {
      if (byte == _commitHeaderMarker) _commits++;
    }
    _checkTripwire();
    _controller.add(chunk);
  }

  void _checkTripwire() {
    if (_tripwireLogged || _bytes <= tripwireOutputBytes) return;
    _tripwireLogged = true;
    _emit(_log, HistoryLogEvent.tripwire, {
      HistoryLogKeys.outputBytes: LogValue.integer(_bytes),
      HistoryLogKeys.commitCount: LogValue.integer(_commits),
    }, level: LogLevel.warning);
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_cancelled) return;
    _emit(_log, HistoryLogEvent.degraded, {
      HistoryLogKeys.reason: const LogEnumValue(
        HistoryDegradeReason.streamError,
      ),
    }, level: LogLevel.warning);
    _controller.close();
    _finish(
      GitScanFailed(
        reason: GitFailureReason.processTerminated,
        exitCode: -1,
        stderrSummary: summarizeStderr('$error'),
      ),
    );
  }

  Future<void> _onDone() async {
    final process = _process!;
    final exit = await process.exitCode;
    final stderr = summarizeStderr(await process.stderr);
    if (_cancelled) return;
    _stopwatch.stop();
    // 不 await：無人訂閱時單訂閱 controller 的 close 不會完成。
    unawaited(_controller.close());
    _emit(_log, HistoryLogEvent.processExited, {
      HistoryLogKeys.exitCode: LogValue.integer(exit),
    }, level: LogLevel.debug);
    _finish(_resultFor(exit, stderr));
  }

  GitScanResult _resultFor(int exit, String stderr) {
    if (exit == 0) {
      _emit(_log, HistoryLogEvent.scanFinished, {
        HistoryLogKeys.commitCount: LogValue.integer(_commits),
        HistoryLogKeys.outputBytes: LogValue.integer(_bytes),
        HistoryLogKeys.gitDurationMs: LogValue.integer(
          _stopwatch.elapsedMilliseconds,
        ),
      });
      return GitScanCompleted(
        outputBytes: _bytes,
        commitCount: _commits,
        gitDuration: _stopwatch.elapsed,
      );
    }
    _emit(_log, HistoryLogEvent.degraded, {
      HistoryLogKeys.category: const LogEnumValue(HistoryLogCategory.failed),
      HistoryLogKeys.exitCode: LogValue.integer(exit),
    }, level: LogLevel.warning);
    return GitScanFailed(
      reason: exit < 0
          ? GitFailureReason.processTerminated
          : GitFailureReason.scanNonZeroExit,
      exitCode: exit,
      stderrSummary: stderr,
    );
  }

  /// 取消：終止掃描程序、丟棄部分輸出，結果為已取消。已結束者不受影響。
  void cancel() {
    if (_cancelled || _result.isCompleted) return;
    _cancelled = true;
    _subscription?.cancel();
    _process?.kill();
    _emit(
      _log,
      HistoryLogEvent.processKilled,
      const {},
      level: LogLevel.warning,
    );
    _emit(_log, HistoryLogEvent.scanCancelled, {
      HistoryLogKeys.outputBytes: LogValue.integer(_bytes),
      HistoryLogKeys.commitCount: LogValue.integer(_commits),
    });
    _controller.close();
    _finish(const GitScanCancelled());
  }

  /// 解析端於解析完成後補報成本與計數（FR-10 規則 1）。
  void reportParse({
    required Duration parseDuration,
    required int eventCount,
    required Map<String, int> counters,
  }) {
    _emit(_log, HistoryLogEvent.scanParseReported, {
      HistoryLogKeys.parseDurationMs: LogValue.integer(
        parseDuration.inMilliseconds,
      ),
      HistoryLogKeys.eventCount: LogValue.integer(eventCount),
      // 計數器逐項攤平為整數欄位（FR-03 只收白名單值，不收 Map）。
      for (final entry in counters.entries)
        entry.key: LogValue.integer(entry.value),
    });
  }

  void _finish(GitScanResult result) {
    if (!_result.isCompleted) _result.complete(result);
  }
}
