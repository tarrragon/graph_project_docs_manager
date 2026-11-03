/// 0.6.0-W1-080 B4：工作區切換時監看啟停。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/fake_watch_source.dart';

class _RecordingSource extends FakeWatchSource {
  final List<String> started = <String>[];

  @override
  Stream<WatchChange> watch(String workspaceRoot) {
    started.add(workspaceRoot);
    return super.watch(workspaceRoot);
  }
}

void main() {
  late _RecordingSource source;
  late ProviderContainer container;

  setUp(() {
    source = _RecordingSource();
    container = ProviderContainer(
      overrides: [watchSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
  });

  test('WorkspaceReady 時 start，切換路徑重啟，其他狀態 stop', () async {
    final controller = container.read(corpusWatchProvider);
    await pumpEventQueue();
    expect(controller.isWatching, isFalse);

    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws-a');
    await pumpEventQueue();
    expect(controller.isWatching, isTrue);
    expect(source.started, ['/ws-a']);

    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws-b');
    await pumpEventQueue();
    expect(source.started, ['/ws-a', '/ws-b']);

    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceUnset();
    await pumpEventQueue();
    expect(controller.isWatching, isFalse);
  });
}
