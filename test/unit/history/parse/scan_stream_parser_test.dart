// SPEC-008 FR-02：串流解析與檔案狀態追蹤（測試設計 §3.2 S-1～S-18、§3.11 L-7）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';

import '../../../helpers/history/synthetic_git_log.dart';

const _path = 'docs/a.md';

class _Run {
  _Run(this.results, this.parser, this.logs);
  final List<ScanCommitResult> results;
  final ScanStreamParser parser;
  final List<String> logs;
  ScanCounters get counters => parser.counters;
  PathChange? change(int commitIndex, [String path = _path]) {
    for (final c in results[commitIndex].changes) {
      if (c.path == path) return c;
    }
    return null;
  }
}

_Run run(
  SyntheticLogBuilder b, {
  bool Function(String)? parseCheck,
  int? chunkSize,
}) {
  final logs = <String>[];
  final parser = ScanStreamParser(
    parseCheck: parseCheck,
    logSink: (level, message) => logs.add('${level.name}:$message'),
  );
  final results = <ScanCommitResult>[];
  final chunks = chunkSize == null ? [b.toBytes()] : b.toChunks(chunkSize);
  for (final chunk in chunks) {
    results.addAll(parser.addChunk(chunk));
  }
  results.addAll(parser.close());
  return _Run(results, parser, logs);
}

List<String> spawnList(int n) => frontmatterLines(
  {
    'id': 'T-1',
    'spawned_tickets': [for (var i = 1; i <= n; i++) 'X-$i'],
  },
  body: ['body1', 'body2', 'body3', 'body4'],
);

void main() {
  group('S 串流解析與狀態追蹤', () {
    test('S-1 block 清單中段加一列，hunk 上下文不含欄位名', () {
      final before = frontmatterLines({
        'id': 'T-1',
        'spawned_tickets': ['X-1', 'X-2', 'X-3', 'X-4', 'X-5', 'X-6', 'X-7'],
      });
      final after = [...before]..insert(6, '  - X-NEW');
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            parents: ['c1'],
            files: [
              LogFileEntry.modified(
                _path,
                before: before,
                after: after,
                context: 1,
              ),
            ],
          );
      final r = run(b);
      final ch = r.change(1)!;
      expect(ch.before, isNot(contains('X-NEW')));
      expect(ch.after, contains('X-NEW'));
      expect(ch.after, contains('spawned_tickets:'));
      expect(r.counters.desyncs, 0);
    });

    test('S-2 刪除結尾 --- 輸出為 ----，不視為檔頭，範圍依全文重算', () {
      final before = frontmatterLines(
        {'id': 'T-1'},
        body: ['k: v', '---', 'more'],
      );
      final after = [...before]..removeAt(2);
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: before,
                after: after,
                context: 1,
              ),
            ],
          );
      final r = run(b);
      expect(r.counters.desyncs, 0);
      expect(r.parser.fileLines(_path), after);
      // 原結尾消失後，下一個單獨 --- 成為結尾：frontmatter 含 text
      expect(r.change(1)!.after, 'id: T-1\nk: v');
    });

    test('S-3 hunk 內容行恰為 --- a/ 與 +++ b/ 時視為內容', () {
      final before = ['x', '--- a/docs/x.md', '+++ b/docs/y.md', 'tail'];
      final after = ['x2', '--- a/docs/x.md', '+++ b/docs/y.md', 'tail'];
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            files: [LogFileEntry.modified(_path, before: before, after: after)],
          );
      final r = run(b);
      expect(r.parser.fileLines(_path), after);
      expect(r.parser.fileLines('docs/y.md'), isNull);
      expect(r.counters.desyncs, 0);
    });

    test('S-4 既有檔無 frontmatter，第 1 行插入 frontmatter', () {
      final before = ['body'];
      final after = ['---', 'parent_id: A', '---', 'body'];
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            files: [LogFileEntry.modified(_path, before: before, after: after)],
          );
      final r = run(b);
      expect(r.change(1)!.before, isNull);
      expect(r.change(1)!.after, 'parent_id: A');
      expect(r.counters.desyncs, 0);
    });

    test('S-5 CRLF 檔案 frontmatter 照常辨識', () {
      final lines = frontmatterLines(
        {'id': 'T-1', 'parent_id': 'A'},
        body: ['b'],
        eol: '\r',
      );
      final b = SyntheticLogBuilder().commit(
        'c1',
        files: [LogFileEntry.added(_path, lines)],
      );
      final r = run(b);
      expect(r.change(0)!.after, 'id: T-1\nparent_id: A');
    });

    test('S-6 空新增檔後下一個 commit 寫入內容', () {
      final content = frontmatterLines({'id': 'T-1', 'parent_id': 'A'});
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, [])])
          .commit(
            'c2',
            files: [LogFileEntry.modified(_path, before: [], after: content)],
          );
      final r = run(b);
      expect(r.change(0)!.created, isTrue);
      expect(r.change(0)!.after, isNull);
      expect(r.change(1)!.after, 'id: T-1\nparent_id: A');
      expect(r.counters.desyncs, 0);
    });

    test('S-7 檔尾無換行的修改，\\ 行不佔行數', () {
      final before = frontmatterLines({'id': 'T-1'}, body: ['a', 'last']);
      final after = frontmatterLines({'id': 'T-1'}, body: ['a', 'last2']);
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before, noEol: true)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: before,
                after: after,
                noEolBefore: true,
                noEolAfter: true,
              ),
            ],
          );
      final r = run(b);
      expect(r.parser.fileLines(_path), after);
      expect(r.counters.desyncs, 0);
    });

    test('S-8 無法解析的 YAML：宣告沿用前一可解析版本，計數 1，debug 日誌 1', () {
      final good = frontmatterLines({'id': 'T-1', 'parent_id': 'A'});
      final bad = [...good]..[1] = 'id: [broken';
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, good)])
          .commit(
            'c2',
            files: [LogFileEntry.modified(_path, before: good, after: bad)],
          )
          .commit(
            'c3',
            files: [LogFileEntry.modified(_path, before: bad, after: good)],
          );
      final r = run(b, parseCheck: (t) => !t.contains('[broken'));
      expect(r.change(1), isNull, reason: '宣告凍結，與前版相同，不報告變更');
      expect(r.change(2), isNull);
      expect(r.counters.unparsableVersions, 1);
      expect(r.logs.where((l) => l.startsWith('debug:')).length, 1);
      expect(r.parser.fileLines(_path), good);
    });

    test('S-9 只改 frontmatter 之後的內文：不重新解析', () {
      var calls = 0;
      final before = spawnList(2);
      final after = [...before]..[before.length - 1] = 'changed';
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: before,
                after: after,
                context: 0,
              ),
            ],
          );
      final r = run(
        b,
        parseCheck: (_) {
          calls++;
          return true;
        },
      );
      expect(calls, 1, reason: '只有新增時解析一次');
      expect(r.change(1), isNull);
    });

    test('S-10（E2）hunk 落在 frontmatter 內：解析次數加 1', () {
      var calls = 0;
      final before = spawnList(2);
      final after = [...before]..[3] = '  - X-9';
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, before)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: before,
                after: after,
                context: 0,
              ),
            ],
          );
      final r = run(
        b,
        parseCheck: (_) {
          calls++;
          return true;
        },
      );
      expect(calls, 2);
      expect(r.change(1)!.after, contains('X-9'));
    });

    test('S-11 舊側內容與追蹤全文不符：失步計數 1、warning、之後不報告', () {
      final tracked = frontmatterLines({'id': 'T-1'}, body: ['real']);
      final claimedBefore = frontmatterLines({'id': 'T-1'}, body: ['fake']);
      final after = frontmatterLines({'id': 'T-2'}, body: ['fake']);
      final later = frontmatterLines({'id': 'T-3'}, body: ['fake']);
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, tracked)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: claimedBefore,
                after: after,
                context: 5,
              ),
            ],
          )
          .commit(
            'c3',
            files: [
              LogFileEntry.modified(
                _path,
                before: after,
                after: later,
                context: 5,
              ),
            ],
          );
      final r = run(b);
      expect(r.counters.desyncs, 1);
      final warnings = r.logs.where((l) => l.startsWith('warning:')).toList();
      expect(warnings.length, 1);
      expect(warnings.single, contains(_path));
      expect(warnings.single, contains('c2'));
      expect(r.change(1), isNull);
      expect(r.change(2), isNull);
    });

    test('S-12（E2）同結構但舊側相符：失步 0、warning 0', () {
      final tracked = frontmatterLines({'id': 'T-1'}, body: ['real']);
      final after = frontmatterLines({'id': 'T-2'}, body: ['real']);
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, tracked)])
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(
                _path,
                before: tracked,
                after: after,
                context: 5,
              ),
            ],
          );
      final r = run(b);
      expect(r.counters.desyncs, 0);
      expect(r.logs.where((l) => l.startsWith('warning:')), isEmpty);
      expect(r.change(1)!.after, 'id: T-2');
    });

    test('S-13 非 UTF-8 位元組：掃描完成、計數 1、以替換字元代入', () {
      final lines = <LogLine>[
        '---',
        'id: T-1',
        '---',
        [0x61, 0xFF, 0xFE, 0x62],
      ];
      final b = SyntheticLogBuilder().commit(
        'c1',
        files: [LogFileEntry.added(_path, lines)],
      );
      final r = run(b);
      expect(r.counters.undecodableLines, 1);
      expect(r.parser.fileLines(_path)!.last, 'a\u{FFFD}\u{FFFD}b');
    });

    test('S-14 C-style 引號路徑還原為 UTF-8 路徑', () {
      final b = SyntheticLogBuilder().commit(
        'c1',
        files: [
          LogFileEntry.added('docs/文 x.md', [
            '---',
            'id: T-1',
            '---',
          ], pathText: r'"docs/\346\226\207 x.md"'),
        ],
      );
      // pathText 帶引號時，rendering 需含 a/ 前綴於引號內
      final r = run(b);
      expect(r.parser.fileLines('docs/文 x.md'), ['---', 'id: T-1', '---']);
    });

    test('S-15 /dev/null 建立與移除狀態，不成為狀態鍵', () {
      final content = ['---', 'id: T-1', '---'];
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, content)])
          .commit('c2', files: [LogFileEntry.deleted(_path, content)]);
      final r = run(b);
      expect(r.change(0)!.created, isTrue);
      expect(r.change(1)!.deleted, isTrue);
      expect(r.change(1)!.after, isNull);
      expect(r.parser.fileLines(_path), isNull);
      expect(r.parser.fileLines('/dev/null'), isNull);
    });

    test('S-16 只改 mode 的條目狀態不變', () {
      final content = ['---', 'id: T-1', '---'];
      final b = SyntheticLogBuilder()
          .commit('c1', files: [LogFileEntry.added(_path, content)])
          .commit('c2', files: [LogFileEntry.modeOnly(_path)]);
      final r = run(b);
      expect(r.parser.fileLines(_path), content);
      expect(r.change(1), isNull);
      expect(r.counters.desyncs, 0);
    });

    test('S-17 500 commit 分段餵入（段界切在字元與行中間）與一次餵入相同', () {
      final b = SyntheticLogBuilder();
      var lines = frontmatterLines(
        {
          'id': 'T-1',
          'relatedTo': ['中文'],
        },
        body: ['內文'],
      );
      b.commit('c0', files: [LogFileEntry.added(_path, lines)]);
      for (var i = 1; i < 500; i++) {
        final next = [...lines]..[lines.length - 1] = '內文$i';
        b.commit(
          'c$i',
          parents: ['c${i - 1}'],
          files: [LogFileEntry.modified(_path, before: lines, after: next)],
        );
        lines = next;
      }
      final whole = run(b);
      final chunked = run(b, chunkSize: 7);
      expect(chunked.results.length, 500);
      expect(chunked.parser.fileLines(_path), whole.parser.fileLines(_path));
      expect(
        chunked.results.map((c) => c.commit.id).toList(),
        whole.results.map((c) => c.commit.id).toList(),
      );
      expect(chunked.counters.desyncs, 0);
    });

    test('S-18 merge 標頭欄位正確分隔', () {
      final b = SyntheticLogBuilder().commit(
        'm1',
        parents: ['p1', 'p2'],
        time: 1700000123,
        author: '作者 A',
        subject: 'Merge branch x',
      );
      final c = run(b).results.single.commit;
      expect(c.id, 'm1');
      expect(c.parents, ['p1', 'p2']);
      expect(c.committedAtSeconds, 1700000123);
      expect(c.author, '作者 A');
      expect(c.subject, 'Merge branch x');
    });
  });

  group('L-7 日誌', () {
    test('失步 warning 與無法解析 debug 各 1', () {
      final good = frontmatterLines({'id': 'T-1'});
      final bad = [...good]..[1] = 'id: [broken';
      final b = SyntheticLogBuilder()
          .commit(
            'c1',
            files: [
              LogFileEntry.added(_path, good),
              LogFileEntry.added('docs/b.md', ['x']),
            ],
          )
          .commit(
            'c2',
            files: [
              LogFileEntry.modified(_path, before: good, after: bad),
              LogFileEntry.modified(
                'docs/b.md',
                before: ['other'],
                after: ['y'],
              ),
            ],
          );
      final r = run(b, parseCheck: (t) => !t.contains('[broken'));
      expect(r.logs.where((l) => l.startsWith('warning:')).length, 1);
      expect(r.logs.where((l) => l.startsWith('debug:')).length, 1);
    });
  });
}
