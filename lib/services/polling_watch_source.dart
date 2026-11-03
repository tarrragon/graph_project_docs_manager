/// [SPEC-006 FR-11] 以輪詢實作 [WatchSource]（0.6.0-W1-080，批 B11）。
///
/// 只供測試 override：宿主機 FSEvents 不推送即時事件時（0.6.0-W1-141），
/// 端對端測試以輪詢取代原生監看。正式環境預設的 provider 不變。
library;

import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/services/directory_watch_source.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const String _docsDirName = 'docs';

class PollingWatchSource implements WatchSource {
  PollingWatchSource({required this.pollingInterval});

  /// 輪詢間隔；測試取短值。
  final Duration pollingInterval;

  final Map<String, PollingDirectoryWatcher> _watchers =
      <String, PollingDirectoryWatcher>{};

  static String _docsPathOf(String root) => p.join(root, _docsDirName);

  @override
  bool targetExists(String workspaceRoot) =>
      Directory(_docsPathOf(workspaceRoot)).existsSync();

  @override
  Stream<WatchChange> watch(String workspaceRoot) {
    final watcher = PollingDirectoryWatcher(
      _docsPathOf(workspaceRoot),
      pollingDelay: pollingInterval,
    );
    _watchers[workspaceRoot] = watcher;
    return watcher.events.map(
      (e) => DirectoryWatchSource.toWatchChange(workspaceRoot, e),
    );
  }

  @override
  Future<void> ready(String workspaceRoot) =>
      _watchers[workspaceRoot]?.ready ?? Future<void>.value();
}
