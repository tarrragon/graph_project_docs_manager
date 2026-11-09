// SPEC-008 FR-06：版本 tag 與預設期間（測試設計 §3.6 V-1～V-9）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/query/default_period.dart';

final _now = DateTime.utc(2026, 11, 9);
final _cutoff = DateTime.utc(2026, 10, 10).millisecondsSinceEpoch ~/ 1000;

/// 主線由新到舊：c9 為 HEAD。
final _mainline = [for (var i = 9; i >= 0; i--) 'c$i'];

HistoryPeriod _period(
  List<GitTagRef> tags, {
  String head = 'c9',
  DateTime? now,
  List<String>? mainline,
}) => resolveDefaultPeriod(
  mainline: mainline ?? _mainline,
  tags: tags,
  head: head,
  now: now ?? _now,
);

GitTagRef _tag(String name, String commit) =>
    GitTagRef(name: name, commitId: commit);

/// 以序號推出期間內的 commit（時間皆為遠古，僅驗證序號判定）。
List<String> _members(HistoryPeriod p) => [
  for (final id in _mainline.reversed)
    if (p.containsCommit(id, 0)) id,
];

void main() {
  group('V 版本 tag 與預設期間（FR-06）', () {
    test('V-1 基準 v0.6.0，期間 c7～c9', () {
      final p = _period([_tag('v0.5.0', 'c3'), _tag('v0.6.0', 'c6')]);
      expect(p.baseTag!.name, 'v0.6.0');
      expect(_members(p), ['c7', 'c8', 'c9']);
      expect(p.description, 'v0.6.0 之後');
    });

    test('V-2 HEAD 本身帶 tag：基準取前一個', () {
      final p = _period([_tag('v0.5.0', 'c3'), _tag('v0.6.0', 'c9')]);
      expect(p.baseTag!.name, 'v0.5.0');
      expect(_members(p), ['c4', 'c5', 'c6', 'c7', 'c8', 'c9']);
    });

    test('V-3 tag 所在 commit 未出現在掃描輸出仍為基準（只依主線清單）', () {
      final p = _period([_tag('v0.6.0', 'c6')]);
      expect(p.baseTag!.commitId, 'c6');
    });

    test('V-4 只有非版本樣式 tag：無基準，最近 30 天', () {
      final p = _period([_tag('release-1', 'c3'), _tag('v1.0.0-rc1', 'c4')]);
      expect(p.baseTag, isNull);
      expect(p.description, '最近 30 天');
      expect(p.containsCommit('c9', _cutoff + 1), isTrue);
    });

    test('V-5 無 v 前綴的 1.0.0 為基準（V-4 的正向對照）', () {
      final p = _period([
        _tag('release-1', 'c3'),
        _tag('v1.0.0-rc1', 'c4'),
        _tag('1.0.0', 'c5'),
      ]);
      expect(p.baseTag!.name, '1.0.0');
    });

    test('V-6 tag 指向不在主線清單的 commit：不採用', () {
      final p = _period([_tag('v0.7.0', 'branch-x')]);
      expect(p.baseTag, isNull);
    });

    test('V-7 annotated tag 以剝殼後的 commit 判定', () {
      final p = _period([_tag('v0.6.0', 'c4')]);
      expect(_members(p), ['c5', 'c6', 'c7', 'c8', 'c9']);
    });

    for (final c in [
      (_cutoff, false, '邊界值不含'),
      (_cutoff - 1, false, '早 1 秒不含'),
      (_cutoff + 1, true, '晚 1 秒含'),
    ]) {
      test('V-8 30 天邊界：${c.$3}', () {
        expect(_period(const []).containsCommit('c9', c.$1), c.$2);
      });
    }

    test('V-9 時鐘改為 2026-12-09，期間改變', () {
      final at = _cutoff + 1;
      expect(_period(const []).containsCommit('c9', at), isTrue);
      final later = _period(const [], now: DateTime.utc(2026, 12, 9));
      expect(later.containsCommit('c9', at), isFalse);
    });
  });
}
