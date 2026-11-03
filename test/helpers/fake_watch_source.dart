/// 可控的 [WatchSource] 替身（0.6.0-W1-080，SPEC-006 FR-11）：每個工作區根
/// 一條 [StreamController]，測試直接 add 事件、addError 或 close。
library;

import 'dart:async';

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';

class FakeWatchSource implements WatchSource {
  final Map<String, StreamController<WatchChange>> controllers =
      <String, StreamController<WatchChange>>{};

  @override
  Stream<WatchChange> watch(String workspaceRoot) =>
      (controllers[workspaceRoot] = StreamController<WatchChange>()).stream;
}

/// 測試用監看錯誤值（取代平台錯誤）。
class FileSystemWatchFailure implements Exception {
  const FileSystemWatchFailure();
}
