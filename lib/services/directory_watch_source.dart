/// [SPEC-006 FR-11] 以 `package:watcher` 的 `DirectoryWatcher` 實作 [WatchSource]
/// （0.6.0-W1-080，批 B4）。真實 FSEvents 行為交實機驗證。
library;

import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const String _docsDirName = 'docs';
const String _posixSeparator = '/';

class DirectoryWatchSource implements WatchSource {
  const DirectoryWatchSource();

  /// 只監看 `<root>/docs`；錯誤原樣經串流傳出。
  @override
  Stream<WatchChange> watch(String workspaceRoot) {
    final docsPath = p.join(workspaceRoot, _docsDirName);
    // docs 不存在時套件會無限重試；改為立即回報錯誤，由 CorpusWatcher 記錄並停止。
    if (!Directory(docsPath).existsSync()) {
      return Stream<WatchChange>.error(
        PathNotFoundException(docsPath, const OSError()),
      );
    }
    final watcher = DirectoryWatcher(docsPath);
    return watcher.events.map((e) => toWatchChange(workspaceRoot, e));
  }

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
