/// [SPEC-006 FR-11] 以 `package:watcher` 的 `DirectoryWatcher` 實作 [WatchSource]
/// （0.6.0-W1-080，批 B4）。真實 FSEvents 行為交實機驗證。
library;

import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/services/services_log_event.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const String _docsDirName = 'docs';
const String _posixSeparator = '/';

class DirectoryWatchSource implements WatchSource {
  DirectoryWatchSource({LogSink<ServicesLogEvent>? logSink})
    : _log = logSink ?? defaultServicesLogSink();

  final LogSink<ServicesLogEvent> _log;

  final Map<String, DirectoryWatcher> _watchers = <String, DirectoryWatcher>{};

  static String _docsPathOf(String root) => p.join(root, _docsDirName);

  /// docs 不存在時套件會無限重試；由 CorpusWatcher 先檢查而不建立監看。
  @override
  bool targetExists(String workspaceRoot) =>
      Directory(_docsPathOf(workspaceRoot)).existsSync();

  /// 只監看 `<root>/docs`；呼叫前須先確認 [targetExists]。
  @override
  Stream<WatchChange> watch(String workspaceRoot) {
    final watcher = DirectoryWatcher(_docsPathOf(workspaceRoot));
    _watchers[workspaceRoot] = watcher;
    return watcher.events.map((e) {
      _log(
        ServicesLogEvent.watchRawEventReceived,
        LogFields({
          ServicesLogKeys.changeType: LogValue.fieldName(e.type.toString()),
          ServicesLogKeys.path: LogValue.path(workspaceRoot, e.path),
        }),
        level: LogLevel.debug,
      );
      return toWatchChange(workspaceRoot, e);
    });
  }

  @override
  Future<void> ready(String workspaceRoot) =>
      _watchers[workspaceRoot]?.ready ?? Future<void>.value();

  /// 絕對路徑轉相對工作區根的 `/` 形式，ADD/MODIFY/REMOVE 對應三值。
  static WatchChange toWatchChange(String workspaceRoot, WatchEvent event) {
    final relative = p.relative(event.path, from: workspaceRoot);
    return WatchChange(
      p.split(relative).join(_posixSeparator),
      switch (event.type) {
        ChangeType.ADD => WatchChangeKind.created,
        ChangeType.MODIFY => WatchChangeKind.modified,
        ChangeType.REMOVE => WatchChangeKind.deleted,
        _ => WatchChangeKind.modified,
      },
    );
  }
}
