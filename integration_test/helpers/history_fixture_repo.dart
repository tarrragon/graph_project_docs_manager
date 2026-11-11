// SPEC-008 測試設計 §1.4：fixture repo 建構器與完整管線執行器。
// 以真實 git 在暫存目錄建 repo（不 mock git），並提供「前置檢查 → 掃描 → 解析 → 事件」
// 的整合管線，供 IT-H1、IT-H2、RG 共用。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// ticket 節點 id_pattern（測試設計 §1.4 邊型表建構器列）。
final RegExp historyTicketIdPattern = RegExp(
  r'^\d+\.\d+\.\d+-W\d+-\d+(\.\d+)*$',
);

/// 隔離使用者 git 設定的環境，並固定作者。
const Map<String, String> _fixtureGitEnv = {
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_AUTHOR_NAME': 'Fixture',
  'GIT_AUTHOR_EMAIL': 'fixture@example.invalid',
  'GIT_COMMITTER_NAME': 'Fixture',
  'GIT_COMMITTER_EMAIL': 'fixture@example.invalid',
};

/// 以真實 git 建在暫存目錄的 repo。
class FixtureRepo {
  FixtureRepo._(this.dir);

  final Directory dir;

  String get path => dir.path;

  /// 建立暫存目錄；[init] 為 false 時不執行 `git init`（非 git 目錄）。
  static Future<FixtureRepo> create({bool init = true}) async {
    final dir = await Directory.systemTemp.createTemp('history_fixture_');
    // 解析符號連結（macOS 的 /var 指向 /private/var），避免路徑比對歧義。
    final repo = FixtureRepo._(Directory(await dir.resolveSymbolicLinks()));
    if (init) await repo.git(['init', '-q', '-b', 'main']);
    return repo;
  }

  /// 在 [dir] 內執行 git，非 0 結束碼拋例外；回傳 stdout。
  Future<String> git(
    List<String> args, {
    Map<String, String> env = const {},
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: workingDirectory ?? path,
      environment: {..._fixtureGitEnv, ...env},
    );
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} 失敗：${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  Future<void> write(String relativePath, String content) async {
    final file = File('$path/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// 暫存全部變更並 commit；[epochSeconds] 固定 committer／author 時間。回傳新 commit id。
  Future<String> commitAll(String message, {required int epochSeconds}) async {
    final date = '$epochSeconds +0000';
    await git(['add', '-A']);
    await git(
      ['commit', '-q', '--allow-empty', '-m', message],
      env: {'GIT_AUTHOR_DATE': date, 'GIT_COMMITTER_DATE': date},
    );
    return head();
  }

  Future<String> head() => git(['rev-parse', 'HEAD']);

  Future<void> tag(String name) => git(['tag', name]);

  Future<void> checkoutNewBranch(String name) =>
      git(['checkout', '-q', '-b', name]);

  Future<void> checkout(String name) => git(['checkout', '-q', name]);

  /// 非快轉合併，merge commit 時間固定為 [epochSeconds]。
  Future<String> mergeNoFf(
    String branch,
    String message, {
    required int epochSeconds,
  }) async {
    final date = '$epochSeconds +0000';
    await git(
      ['merge', '-q', '--no-ff', '-m', message, branch],
      env: {'GIT_AUTHOR_DATE': date, 'GIT_COMMITTER_DATE': date},
    );
    return head();
  }

  Future<void> setConfig(String key, String value) =>
      git(['config', key, value]);

  /// `git clone --depth <depth> file://<此 repo>`；回傳淺層 clone 的目錄。
  Future<FixtureRepo> shallowClone({int depth = 1}) async {
    final target = await Directory.systemTemp.createTemp('history_shallow_');
    final resolved = await target.resolveSymbolicLinks();
    await git([
      'clone',
      '-q',
      '--depth',
      '$depth',
      'file://$path',
      '$resolved/clone',
    ]);
    return FixtureRepo._(Directory('$resolved/clone'));
  }

  Future<void> dispose() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// 組出帶 block 清單的 frontmatter 全文。
String frontmatterDoc(Map<String, Object> fields) {
  final buffer = StringBuffer('---\n');
  fields.forEach((key, value) {
    if (value is List) {
      buffer.writeln('$key:');
      for (final item in value) {
        buffer.writeln('  - $item');
      }
    } else {
      buffer.writeln('$key: $value');
    }
  });
  buffer.writeln('---\n正文');
  return buffer.toString();
}

/// 在 [pathDirs]（模擬的 PATH）中找 `git` 的 runner；找不到即「無法啟動」。
class PathRestrictedRunner implements GitProcessRunner {
  PathRestrictedRunner(this.pathDirs, {this.extraEnvironment = const {}});

  final List<String> pathDirs;

  /// 併入每次呼叫的額外環境（模擬使用者啟動環境，如 LANG）。
  final Map<String, String> extraEnvironment;

  /// 每次呼叫收到的環境（供斷言 `LC_ALL=C`）。
  final List<Map<String, String>> seenEnvironments = [];

  GitProcessRunner _delegate(GitInvocation invocation) {
    seenEnvironments.add(invocation.environment);
    for (final dir in pathDirs) {
      final candidate = File('$dir/git');
      if (candidate.existsSync()) {
        return IoGitProcessRunner(executable: candidate.path);
      }
    }
    throw const GitLaunchException('git 不在 PATH');
  }

  GitInvocation _withEnv(GitInvocation invocation) => GitInvocation(
    arguments: invocation.arguments,
    environment: {...extraEnvironment, ...invocation.environment},
  );

  @override
  Future<GitCommandResult> run(GitInvocation invocation) =>
      _delegate(invocation).run(_withEnv(invocation));

  @override
  Future<GitScanProcess> start(GitInvocation invocation) =>
      _delegate(invocation).start(_withEnv(invocation));
}

/// 取自 `PATH` 環境變數的目錄清單（真實 PATH）。
List<String> realPathDirs() => (Platform.environment['PATH'] ?? '')
    .split(':')
    .where((d) => d.isNotEmpty)
    .toList();

/// 一筆被記錄的日誌。
class RecordedHistoryLog {
  const RecordedHistoryLog(this.event, this.payload);

  final HistoryLogEvent event;
  final Map<String, Object?> payload;
}

/// 完整管線的結果。
class HistoryPipelineResult {
  HistoryPipelineResult({
    required this.open,
    required this.logs,
    this.scanResult,
    this.events = const [],
    this.changedPaths = const [],
    this.commitTimes = const [],
    this.parseDuration = Duration.zero,
    this.counters,
    this.filesWithoutId = 0,
    this.nonStringValues = 0,
    this.peakTrackedChars = 0,
  });

  final GitOpenOutcome open;
  final List<RecordedHistoryLog> logs;
  final GitScanResult? scanResult;
  final List<EdgeEvent> events;

  /// 解析器回報的全部 PathChange 路徑（相對於工作區根）。
  final List<String> changedPaths;

  /// 主線 commit 的 committer 時間（由舊到新）。
  final List<int> commitTimes;
  final Duration parseDuration;
  final ScanCounters? counters;
  final int filesWithoutId;
  final int nonStringValues;
  final int peakTrackedChars;

  /// 結果型別；完成的掃描歸為 [GitScanCompleted]。
  Type get kind => switch (open) {
    GitOpenStopped(:final outcome) => outcome.runtimeType,
    GitOpenScanning() => scanResult.runtimeType,
    GitOpenBlocked() => GitOpenBlocked,
  };

  /// 是否為「讀取失敗」（前置檢查或掃描）。
  bool get isReadFailure => switch (open) {
    GitOpenStopped(:final outcome) => outcome is GitPreflightFailed,
    GitOpenScanning() => scanResult is GitScanFailed,
    GitOpenBlocked() => false,
  };

  GitPreflightReady? get ready => switch (open) {
    GitOpenScanning(:final ready) => ready,
    _ => null,
  };
}

/// 以 App 內建型別表建 extractor 與 builder。
Future<EdgeEventBuilder> buildEdgeEventBuilder() async {
  final raw = await rootBundle.loadString(
    builtinTrackingSchemaAssetPath,
    cache: false,
  );
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final resolution = resolveEdgeTypes(
    projectSchemaJson: json,
    builtinSchemaJson: json,
  );
  return EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: resolution.activeEdgeTypes,
      closedByIdPatterns: [historyTicketIdPattern],
    ),
    ticketIdPattern: historyTicketIdPattern,
  );
}

/// 對 [root] 跑完整管線：前置檢查 → 掃描 → 解析 → 事件。耗時分別量測。
Future<HistoryPipelineResult> runHistoryPipeline(
  String root,
  GitProcessRunner runner,
) async {
  final logs = <RecordedHistoryLog>[];
  final port = GitHistoryPort(
    runner: runner,
    logSink: (event, fields, {level = LogLevel.info, source, error}) =>
        logs.add(RecordedHistoryLog(event, fields.toJson())),
  );
  final open = await port.open(
    root: root,
    schema: HistorySchemaReadiness.ready,
  );
  if (open is! GitOpenScanning) {
    return HistoryPipelineResult(open: open, logs: logs);
  }
  return _consumeScan(open, logs, await buildEdgeEventBuilder());
}

Future<HistoryPipelineResult> _consumeScan(
  GitOpenScanning open,
  List<RecordedHistoryLog> logs,
  EdgeEventBuilder builder,
) async {
  final parser = ScanStreamParser();
  final events = <EdgeEvent>[];
  final paths = <String>[];
  final times = <int>[];
  final parseWatch = Stopwatch();
  void consume(List<ScanCommitResult> results) {
    for (final r in results) {
      times.add(r.commit.committedAtSeconds);
      paths.addAll(r.changes.map((c) => c.path));
      events.addAll(
        builder.processCommitWithShallow(r, isShallow: open.ready.isShallow),
      );
    }
  }

  await for (final chunk in open.scan.stdout) {
    parseWatch.start();
    consume(parser.addChunk(chunk));
    parseWatch.stop();
  }
  parseWatch.start();
  consume(parser.close());
  parseWatch.stop();
  final result = await open.scan.result;
  open.scan.reportParse(
    parseDuration: parseWatch.elapsed,
    eventCount: events.length,
    counters: _counterMap(parser.counters, builder),
  );
  return HistoryPipelineResult(
    open: open,
    logs: logs,
    scanResult: result,
    events: events,
    changedPaths: paths,
    commitTimes: times,
    parseDuration: parseWatch.elapsed,
    counters: parser.counters,
    filesWithoutId: builder.filesWithoutId,
    nonStringValues: builder.nonStringValues,
    peakTrackedChars: parser.peakTrackedChars,
  );
}

Map<String, int> _counterMap(ScanCounters c, EdgeEventBuilder b) => {
  'undecodableLines': c.undecodableLines,
  'unparsableVersions': c.unparsableVersions,
  'desyncs': c.desyncs,
  'filesWithoutId': b.filesWithoutId,
  'nonStringValues': b.nonStringValues,
};
