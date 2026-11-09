// SPEC-008 FR-07：查詢（測試設計 §3.8 Q-1～Q-4、Q-6；Q-5 以無 I/O 依賴結構保證）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_key.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';

final _now = DateTime.utc(2026, 11, 9);
final _nowSeconds = _now.millisecondsSinceEpoch ~/ 1000;
const _day = 86400;

/// 主線由新到舊。
const _mainline = ['c3', 'c2', 'c1', 'c0'];

EdgeEvent _ev(
  String commit,
  String to, {
  bool ticket = false,
  String type = 'blockedBy',
  int? at,
}) => EdgeEvent(
  type: EdgeEventType.added,
  key: EdgeKey(type, 'X', to),
  declarersBefore: const [],
  declarersAfter: const ['X'],
  commitId: commit,
  committedAtSeconds: at ?? _nowSeconds,
  author: 'a',
  subject: 's',
  isTicketCreation: ticket,
);

HistoryQuery _query(
  List<EdgeEvent> events, {
  List<GitTagRef> tags = const [],
}) => HistoryQuery(
  events: events,
  mainline: _mainline,
  tags: tags,
  head: 'c3',
  clock: () => _now,
);

List<String> _tos(List<HistoryEventView> v) => [
  for (final e in v) e.event.key.to,
];

void main() {
  group('Q 查詢（FR-07）', () {
    test('Q-1 包含 ticket 建檔：否 3 筆、是 5 筆，前者為後者子集且不同', () {
      final q = _query([
        _ev('c1', 'a', ticket: true),
        _ev('c1', 'b', ticket: true),
        _ev('c2', 'c'),
        _ev('c2', 'd'),
        _ev('c3', 'e'),
      ]);
      final without = _tos(q.run(period: PeriodChoice.allHistory));
      final withAll = _tos(
        q.run(period: PeriodChoice.allHistory, includeTicketCreation: true),
      );
      expect(without, hasLength(3));
      expect(withAll, hasLength(5));
      expect(withAll, containsAll(without));
      expect(without, isNot(equals(withAll)));
    });

    test('Q-2 全部歷史包含所有事件，不受 tag 基準限制', () {
      final q = _query(
        [_ev('c0', 'a'), _ev('c3', 'b')],
        tags: [const GitTagRef(name: 'v1.0.0', commitId: 'c2')],
      );
      expect(_tos(q.run(period: PeriodChoice.allHistory)), ['b', 'a']);
      expect(_tos(q.run()), ['b']);
    });

    test('Q-3 主線新到舊，同 commit 內維持原順序', () {
      final q = _query([
        _ev('c1', 'a'),
        _ev('c2', 'b1'),
        _ev('c2', 'b2'),
        _ev('c3', 'c'),
      ]);
      expect(_tos(q.run(period: PeriodChoice.allHistory)), [
        'c',
        'b1',
        'b2',
        'a',
      ]);
    });

    test('Q-4 domain_dependency 對端標為非節點，其他為節點', () {
      final q = _query([
        _ev('c3', 'domain-b', type: domainDependencyEdgeName),
        _ev('c3', 'N'),
      ]);
      final v = q.run(period: PeriodChoice.allHistory);
      expect(v[0].counterpartIsNode, isFalse);
      expect(v[1].counterpartIsNode, isTrue);
    });

    test('Q-6 有基準 tag 時預設期間與最近 30 天結果可不同', () {
      final old = _nowSeconds - 60 * _day;
      final q = _query(
        [_ev('c1', 'old-in-default', at: old), _ev('c3', 'recent')],
        tags: [const GitTagRef(name: 'v1.0.0', commitId: 'c0')],
      );
      expect(_tos(q.run()), ['recent', 'old-in-default']);
      expect(_tos(q.run(period: PeriodChoice.last30Days)), ['recent']);
    });
  });
}
