// SPEC-003 §3.5〈孤立事件判準〉與〈事件宣告與 flow 不符判準〉，
// 預期表為 docs/spec/diagnostics/domain-map.md §3 末四列。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';

import '../../helpers/spec007/bundle_graph_fixture.dart';

RawNode _uc(String id, List<Map<String, dynamic>> steps) => RawNode(
  path: 'docs/usecases/$id.md',
  frontmatter: {'id': id},
  typeName: 'UC',
  flowSteps: steps,
);

Map<String, dynamic> _step(
  String id, {
  Object? emits,
  Object? consumes,
  Object? traverses = const <String>[],
}) => {
  'id': id,
  'emits': ?emits,
  'consumes': ?consumes,
  'traverses': ?traverses,
};

RawNode _evt(
  String id, {
  String? category = 'domain_event',
  Object? producers = const <String>[],
  Object? consumers = const <String>[],
}) => RawNode(
  path: 'docs/events/x/$id-slug.md',
  frontmatter: {
    'id': id,
    'category': ?category,
    'producers': producers,
    'consumers': consumers,
  },
  typeName: 'EVT',
);

EventGapDetection _detect(List<RawNode> ucs, List<RawNode> evts) {
  final graph = buildResultOf([
    bundleNode('alpha'),
    bundleNode('beta'),
    ...ucs,
  ]);
  return detectEventGaps(graph: graph, rawNodes: evts);
}

EventGapReport _report(List<RawNode> ucs, List<RawNode> evts) =>
    (_detect(ucs, evts) as EventGapsDetected).report;

void main() {
  group('孤立事件：有發出無消費', () {
    test('OE-1 三條件皆成立即列入，帶引用 UC 清單', () {
      final r = _report(
        [
          _uc('UC-02', [
            _step('a', emits: 'EVT-X-001', traverses: ['alpha']),
          ]),
        ],
        [_evt('EVT-X-001')],
      );
      expect(r.orphanEvents, hasLength(1));
      final o = r.orphanEvents.single;
      expect(o.evtId, 'EVT-X-001');
      expect(o.shape, OrphanEventShape.emittedNotConsumed);
      expect(o.ucIds, ['UC-02']);
    });

    test('OE-2 條件2：有 flow 消費即不列入', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
            _step('b', consumes: ['EVT-X-001']),
          ]),
        ],
        [_evt('EVT-X-001')],
      );
      expect(r.orphanEvents, isEmpty);
    });

    test('OE-3 條件3：consumers 已宣告即不列入（交由宣告不符）', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['beta']),
        ],
      );
      expect(r.orphanEvents, isEmpty);
      expect(r.mismatches, hasLength(1));
    });

    test('OE-4 條件1：無任何 flow 引用的 EVT 不列入', () {
      expect(_report([], [_evt('EVT-X-001')]).orphanEvents, isEmpty);
    });
  });

  group('孤立事件：有消費無發出', () {
    test('OE-5 三條件皆成立即列入', () {
      final r = _report(
        [
          _uc('UC-01', [_step('a', consumes: 'EVT-X-001')]),
        ],
        [_evt('EVT-X-001')],
      );
      expect(r.orphanEvents.single.shape, OrphanEventShape.consumedNotEmitted);
    });

    test('OE-6 條件2：有 flow 發出即不列入', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001']),
          ]),
          _uc('UC-02', [
            _step('a', emits: ['EVT-X-001']),
          ]),
        ],
        [_evt('EVT-X-001')],
      );
      expect(r.orphanEvents, isEmpty);
    });

    test('OE-7 條件3：producers 已宣告即不列入', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001']),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['alpha']),
        ],
      );
      expect(r.orphanEvents, isEmpty);
    });
  });

  group('孤立事件：排除與 E1 對照', () {
    final ucs = [
      _uc('UC-01', [
        _step('a', emits: ['EVT-X-001']),
      ]),
    ];

    test('OE-8 process_event 不列入', () {
      expect(
        _report(ucs, [
          _evt('EVT-X-001', category: 'process_event'),
        ]).orphanEvents,
        isEmpty,
      );
    });

    test('OE-9 E1 對照：同一 EVT 改 domain_event 即列入', () {
      expect(
        _report(ucs, [_evt('EVT-X-001')]).orphanEvents.map((o) => o.evtId),
        ['EVT-X-001'],
      );
    });

    test('OE-9b E1 category 缺席：與 OE-9 同條件但無 category 鍵即不列入', () {
      final noCategory = _evt('EVT-X-001', category: null);
      expect(noCategory.frontmatter.containsKey('category'), isFalse);
      expect(_report(ucs, [noCategory]).orphanEvents, isEmpty);
      expect(_report(ucs, [_evt('EVT-X-001')]).orphanEvents, hasLength(1));
    });

    test('OE-10 consumers 缺鍵或 null 視同空', () {
      final evt = RawNode(
        path: 'p.md',
        frontmatter: {'id': 'EVT-X-001', 'category': 'domain_event'},
        typeName: 'EVT',
      );
      expect(_report(ucs, [evt]).orphanEvents, hasLength(1));
    });

    test('OE-11 每個符合的 EVT 一項，依 EVT id 排序', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-002', 'EVT-X-001']),
          ]),
        ],
        [_evt('EVT-X-002'), _evt('EVT-X-001')],
      );
      expect(r.orphanEvents.map((o) => o.evtId), ['EVT-X-001', 'EVT-X-002']);
    });
  });

  group('UC 引用清單（E1 對照）', () {
    test('UL-1多個 UC 引用時依 UC id 排序且去重', () {
      final r = _report(
        [
          _uc('UC-03', [
            _step('a', emits: ['EVT-X-001']),
          ]),
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
            _step('b', emits: ['EVT-X-001']),
          ]),
        ],
        [_evt('EVT-X-001')],
      );
      expect(r.orphanEvents.single.ucIds, ['UC-01', 'UC-03']);
    });

    test('UL-2無 UC 引用時清單為空（宣告不符）', () {
      final r = _report([], [
        _evt('EVT-X-001', consumers: ['alpha']),
      ]);
      expect(r.mismatches.single.ucIds, isEmpty);
    });
  });

  group('宣告不符：consumers 方向', () {
    test('MM-1 宣告的消費 domain 無 flow 即一項', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001'], traverses: ['alpha']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['beta']),
        ],
      );
      final m = r.mismatches.single;
      expect(m.evtId, 'EVT-X-001');
      expect(m.direction, EventDeclarationDirection.consumers);
      expect(m.domain, 'beta');
      expect(m.ucIds, ['UC-01']);
    });

    test('MM-2 包含比對：traverses 為多值且含該 domain 即對應', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: ['alpha', 'beta']),
            _step('b', emits: ['EVT-X-001'], traverses: ['alpha']),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['alpha'], consumers: ['beta']),
        ],
      );
      expect(r.mismatches, isEmpty);
    });

    test('MM-3 該 domain 的步驟只 emits 不 consumes 仍不對應', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001'], traverses: ['beta']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['beta']),
        ],
      );
      expect(r.mismatches.single.domain, 'beta');
    });

    test('MM-4 跨 UC 對應：全專案任一 UC 命中即算', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
          ]),
          _uc('UC-02', [
            _step('a', consumes: ['EVT-X-001'], traverses: ['beta']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['beta']),
        ],
      );
      expect(r.mismatches, isEmpty);
    });
  });

  group('宣告不符：producers 方向', () {
    test('MM-5 宣告的發出 domain 無 flow 即一項', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: ['beta']),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['alpha']),
        ],
      );
      final m = r.mismatches.single;
      expect(m.direction, EventDeclarationDirection.producers);
      expect(m.domain, 'alpha');
    });

    test('MM-6 對應時不列入', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001'], traverses: ['alpha']),
            _step('b', consumes: ['EVT-X-001'], traverses: ['beta']),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['alpha']),
        ],
      );
      expect(r.mismatches, isEmpty);
    });
  });

  group('宣告不符：粒度', () {
    test('MM-7 同一 EVT 兩個 domain 未對應即兩項（依方向、domain 排序）', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['beta'], consumers: ['beta', 'alpha']),
        ],
      );
      expect(r.mismatches.map((m) => (m.direction.name, m.domain)), [
        ('consumers', 'alpha'),
        ('consumers', 'beta'),
        ('producers', 'beta'),
      ]);
    });

    test('MM-8 process_event 不排除宣告不符', () {
      final r = _report([], [
        _evt('EVT-X-001', category: 'process_event', consumers: ['alpha']),
      ]);
      expect(r.mismatches, hasLength(1));
    });

    test('MM-9 重複宣告的同一 domain 只算一項', () {
      final r = _report([], [
        _evt('EVT-X-001', consumers: ['alpha', 'alpha']),
      ]);
      expect(r.mismatches, hasLength(1));
    });
  });

  group('presentation 保留字', () {
    test('PR-1 consumers 的 presentation 對應 traverses 為空的消費步驟', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001'], traverses: ['alpha']),
            _step('b', consumes: ['EVT-X-001'], traverses: <String>[]),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['presentation']),
        ],
      );
      expect(r.mismatches, isEmpty);
    });

    test('PR-2 consumers 的 presentation 無空 traverses 消費步驟即一項', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: ['alpha']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['presentation']),
        ],
      );
      expect(r.mismatches.single.domain, 'presentation');
    });

    test('PR-3 traverses 缺鍵的步驟不是 traverses == []', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: null),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['presentation']),
        ],
      );
      expect(r.mismatches, hasLength(1));
    });

    test('PR-4 producers 的 presentation 視為未對應，即使有空 traverses 發出步驟', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001'], traverses: <String>[]),
          ]),
        ],
        [
          _evt('EVT-X-001', producers: ['presentation']),
        ],
      );
      final m = r.mismatches.single;
      expect(m.direction, EventDeclarationDirection.producers);
      expect(m.domain, 'presentation');
    });

    test('PR-5 大小寫不同的 Presentation 為其他值，視為未對應', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: <String>[]),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['Presentation']),
        ],
      );
      expect(r.mismatches.single.domain, 'Presentation');
    });

    test('PR-6 未宣告的 domain 值視為未對應，即使步驟 traverses 寫同名', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', consumes: ['EVT-X-001'], traverses: ['ghost']),
          ]),
        ],
        [
          _evt('EVT-X-001', consumers: ['ghost']),
        ],
      );
      expect(r.mismatches.single.domain, 'ghost');
    });
  });

  group('451 查詢入口', () {
    test('Q-1 以 EVT id 查孤立事件，命中與未命中', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('a', emits: ['EVT-X-001']),
          ]),
        ],
        [_evt('EVT-X-001'), _evt('EVT-X-002')],
      );
      expect(r.orphanOf('EVT-X-001')?.evtId, 'EVT-X-001');
      expect(r.isOrphan('EVT-X-001'), isTrue);
      expect(r.isOrphan('EVT-X-002'), isFalse);
      expect(r.orphanOf('EVT-NONE-999'), isNull);
    });

    test('Q-2 以 EVT id 查宣告不符項', () {
      final r = _report([], [
        _evt('EVT-X-001', consumers: ['alpha', 'beta']),
      ]);
      expect(r.mismatchesOf('EVT-X-001'), hasLength(2));
      expect(r.mismatchesOf('EVT-X-002'), isEmpty);
    });
  });

  group('建圖不可用（E2 守衛）', () {
    final evts = [
      _evt('EVT-X-001', consumers: ['alpha']),
    ];

    test('G-1 不可用時回報無法判定與原因碼，不含項目', () {
      final d = detectEventGaps(
        graph: unavailableBuildResult(),
        rawNodes: evts,
      );
      expect(d, isA<EventGapsUndetermined>());
      expect(d.report.orphanEvents, isEmpty);
      expect(d.report.mismatches, isEmpty);
      expect(d.report.isOrphan('EVT-X-001'), isFalse);
    });

    test('G-2 正向對照：同一 EVT 輸入在建圖可用時偵測到項目', () {
      final d = _detect([], evts);
      expect(d, isA<EventGapsDetected>());
      expect(d.report.mismatches, hasLength(1));
    });

    test('G-3 孤立事件正向對照：可用時 isOrphan 為真，不可用時為假且零筆', () {
      final ucs = [
        _uc('UC-01', [
          _step('a', emits: ['EVT-X-001']),
        ]),
      ];
      final orphanEvts = [_evt('EVT-X-001')];
      final ok = _detect(ucs, orphanEvts);
      expect(ok.report.isOrphan('EVT-X-001'), isTrue);
      expect(ok.report.orphanOf('EVT-X-001'), isNotNull);
      final d = detectEventGaps(
        graph: unavailableBuildResult(),
        rawNodes: orphanEvts,
      );
      expect(d, isA<EventGapsUndetermined>());
      expect(d.report.isOrphan('EVT-X-001'), isFalse);
      expect(d.report.orphanEvents, isEmpty);
    });
  });

  group('與「事件引用未解析」不重疊', () {
    test('D4-8（守衛）不存在的 EVT id 不成為事件類破洞；孤立 EVT-A 為正向對照', () {
      final r = _report(
        [
          _uc('UC-01', [
            _step('s', emits: ['EVT-GHOST']),
            _step('a', emits: ['EVT-A']),
          ]),
        ],
        [_evt('EVT-A')],
      );
      expect([for (final o in r.orphanEvents) o.evtId], ['EVT-A']);
      expect(r.isOrphan('EVT-GHOST'), isFalse);
      expect(r.mismatches.where((m) => m.evtId == 'EVT-GHOST'), isEmpty);
    });
  });

  group('輸入過濾', () {
    test('F-1 非 EVT 型別節點與缺 id 的節點略過', () {
      final r = _report([], [
        RawNode(
          path: 'a.md',
          frontmatter: {
            'id': 'EVT-X-001',
            'consumers': ['alpha'],
          },
          typeName: 'UC',
        ),
        RawNode(
          path: 'b.md',
          frontmatter: {
            'consumers': ['alpha'],
          },
          typeName: 'EVT',
        ),
      ]);
      expect(r.mismatches, isEmpty);
    });
  });
}
