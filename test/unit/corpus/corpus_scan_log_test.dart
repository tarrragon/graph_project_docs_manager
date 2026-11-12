import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_log_event.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/recording_log_sink.dart';
import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';

/// SPEC-010 test-design O4-4：掃描 3 個檔案，逐檔事件皆 debug，
/// 或整輪只有一筆 info 以上的聚合記錄。
void main() {
  late RecordingLogSink<CorpusLogEvent> recorder;

  setUp(() {
    recorder = RecordingLogSink<CorpusLogEvent>();
    corpusLogSink = recorder.sink;
  });
  tearDown(() => corpusLogSink = defaultCorpusLogSink);

  Future<void> scanThree() async {
    final fs = FakeDocsFileSystem();
    for (final name in ['a', 'b', 'c']) {
      fs.addFile('docs/$name.md', utf8.encode('---\nid: X-$name\n---\n'));
    }
    // 非 domain 清單檔位置取自內建表，檔案存在且格式正確：本輪沒有任何
    // 非逐檔的告警，info 以上只剩聚合記錄。
    fs.addFile(
      'docs/non-domain-paths.yaml',
      utf8.encode('non_domain_path_patterns:\n  - docs/a.md\n'),
    );
    final table = TypeTableBuilder()
        .addType('Alpha', idPattern: r'^X-')
        .build();
    final builtin = typeTableFromJson(
      jsonDecode(
        File('assets/schema/builtin_tracking_schema.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    await scanCorpus(fileSystem: fs, table: table, builtinTable: builtin);
  }

  group('O4-4 掃描路徑逐檔事件不以 info 以上逐筆記錄', () {
    test('3 檔一輪：info 以上只有一筆聚合記錄（fileCount 為 3）', () async {
      await scanThree();

      expect(
        isDebugOrSingleAggregate(recorder.entries, {
          CorpusLogEvent.scanCompleted,
        }),
        isTrue,
      );
      final done = recorder.ofEvent(CorpusLogEvent.scanCompleted);
      expect(done, hasLength(1));
      expect(done.single.level, LogLevel.info);
      expect(done.single.payload[CorpusLogKeys.fileCount], 3);
      expect(
        recorder.ofEvent(CorpusLogEvent.scanStarted).single.level,
        LogLevel.debug,
      );
    });

    test('正向對照：逐檔以 info 記錄 3 筆的輸入，判定函式判紅', () {
      final perFileInfo = RecordingLogSink<CorpusLogEvent>();
      for (var i = 0; i < 3; i++) {
        perFileInfo.sink(CorpusLogEvent.fileReadFailed, LogFields.empty);
      }

      expect(
        isDebugOrSingleAggregate(perFileInfo.entries, {
          CorpusLogEvent.scanCompleted,
        }),
        isFalse,
      );
    });

    test('負載鍵皆為 FR-03 白名單序列化結果（整數）', () async {
      await scanThree();

      final payload = recorder
          .ofEvent(CorpusLogEvent.scanCompleted)
          .single
          .payload;
      expect(payload.keys.toSet(), {
        CorpusLogKeys.fileCount,
        CorpusLogKeys.nodeCount,
        CorpusLogKeys.failureCount,
        CorpusLogKeys.unlistableDirectoryCount,
        CorpusLogKeys.flowMalformedUcCount,
      });
      expect(payload.values.every((v) => v is int), isTrue);
    });
  });
}
