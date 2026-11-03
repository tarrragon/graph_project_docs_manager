/// [SPEC-006 FR-11] 以 `package:watcher` 的 `DirectoryWatcher` 實作 [WatchSource]
/// （0.6.0-W1-080，批 B4）。真實 FSEvents 行為交實機驗證。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const String _docsDirName = 'docs';
const String _posixSeparator = '/';
const String _tag = 'DirectoryWatchSource';
const int _traceLevel = 500; // magic-exempt: developer.log 500 級別，B10 實機定位用

class DirectoryWatchSource implements WatchSource {
  DirectoryWatchSource();

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
      developer.log(
        // i18n-exempt: developer log
        'raw event type=${e.type} path=${e.path} root=$workspaceRoot',
        name: _tag,
        level: _traceLevel,
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
