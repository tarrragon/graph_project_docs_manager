// SPEC-008 IT-H1 的解析端實測：以本 repo 實際 `git log -p` 輸出餵入解析器。
// 耗時與追蹤文字量只記錄、不作斷言門檻（D1）；僅在 HISTORY_REAL_SCAN=1 時執行。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';

void main() {
  test(
    '本 repo 主線掃描：失步計數為 0（記錄耗時與追蹤文字量）',
    () async {
      final proc = await Process.start('git', [
        '-c',
        'core.quotePath=false',
        'log',
        '-p',
        '--reverse',
        '--first-parent',
        '--diff-merges=first-parent',
        '--no-renames',
        '--no-color',
        '--no-ext-diff',
        '--no-textconv',
        '--no-show-signature',
        '--src-prefix=a/',
        '--dst-prefix=b/',
        '--relative',
        '--format=%x1e%H%x00%P%x00%ct%x00%an%x00%s',
        '--',
        'docs/',
      ]);
      final parser = ScanStreamParser();
      var commits = 0;
      var bytes = 0;
      var changes = 0;
      final watch = Stopwatch()..start();
      await for (final chunk in proc.stdout) {
        bytes += chunk.length;
        for (final c in parser.addChunk(chunk)) {
          commits++;
          changes += c.changes.length;
        }
      }
      for (final c in parser.close()) {
        commits++;
        changes += c.changes.length;
      }
      watch.stop();
      final k = parser.counters;
      // ignore: avoid_print
      print(
        'history-scan commits=$commits bytes=$bytes pathChanges=$changes '
        'ms=${watch.elapsedMilliseconds} peakTrackedChars='
        '${parser.peakTrackedChars} desyncs=${k.desyncs} '
        'unparsable=${k.unparsableVersions} undecodable=${k.undecodableLines} '
        'yamlParses=${k.yamlParses}',
      );
      expect(k.desyncs, 0);
    },
    skip: Platform.environment['HISTORY_REAL_SCAN'] == '1'
        ? false
        : '僅於 HISTORY_REAL_SCAN=1 時執行（非主套件紅綠判準）',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
