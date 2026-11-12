/// SPEC-006 FR-11 驗收 1、8：監看 → 去抖 → 排程 → 整輪 [scanCorpus]
/// （0.6.0-W1-080 Phase 2 紅燈）。
///
/// 以假 [WatchSource]、[ManualDebounceClock]、記憶體檔案系統串起元件，掃描用
/// 真實 [scanCorpus]；真實 FSEvents 交實機驗證。Phase 3b 待補 stub：
/// [CorpusWatcher]、[ScanScheduler]。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';

import '../../../helpers/fake_watch_source.dart';
import '../../../helpers/manual_debounce_clock.dart';
import '../../../helpers/spec006/fake_docs_fs.dart';
import '../../../helpers/spec006/real_type_table.dart';

const _target = 'docs/proposals/PROP-900-watch.md';

final _valid = utf8.encode('---\nid: PROP-900\ntitle: t\n---\nbody\n');
final _broken = utf8.encode('---\nid: [unclosed\ntitle: t\n---\nbody\n');

void main() {
  late FakeDocsFileSystem fs;
  late FakeWatchSource source;
  late ManualDebounceClock clock;
  late List<CorpusScanResult> evt001;
  late ScanScheduler scheduler;
  late CorpusWatcher watcher;

  setUp(() {
    fs = FakeDocsFileSystem()..addFile(_target, _valid);
    source = FakeWatchSource();
    clock = ManualDebounceClock();
    evt001 = <CorpusScanResult>[];
    final table = readRealTypeTable();
    scheduler = ScanScheduler(
      runRound: (_) async => evt001.add(
        await scanCorpus(fileSystem: fs, table: table, builtinTable: table),
      ),
    );
    watcher = CorpusWatcher(
      source: source,
      clock: clock,
      onChanged: (_) => scheduler.request(ScanTrigger.watch),
      log: (_, _, {level = LogLevel.info, source, error}) {},
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    '驗收 1：外部把 frontmatter 改為 YAML 錯誤 → 不經操作發出 EVT-CORPUS-001，含該檔 parseFailure',
    () async {
      await watcher.start('/ws');
      fs.addFile(_target, _broken);
      source.controllers['/ws']!.add(
        const WatchChange(_target, WatchChangeKind.modified),
      );
      await settle();
      clock.advance(watchMaxWait);
      await pumpEventQueue();

      expect(evt001, hasLength(1));
      expect(evt001.single.parseErrors.map((e) => e.path), contains(_target));
    },
  );

  test('驗收 1 對照：無檔案事件時不發出 EVT-CORPUS-001', () async {
    await watcher.start('/ws');
    clock.advance(watchMaxWait);
    await pumpEventQueue();
    expect(evt001, isEmpty);
  });

  test('驗收 8：監看串流錯誤後，手動重掃仍完成一輪', () async {
    await watcher.start('/ws');
    source.controllers['/ws']!.addError(const FileSystemWatchFailure());
    await settle();
    expect(watcher.isWatching, isFalse);

    scheduler.request(ScanTrigger.manual);
    await pumpEventQueue();
    expect(evt001, hasLength(1));
  });
}
