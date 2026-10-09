// 需求：SPEC-007 FR-12 / SPEC-007-test-design G12-1～G12-15
// 期望值取規格（SPEC-001 §1〈本專案期望分布〉）與凍結快照，不由實作輸出自算。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/domain_uc_relation.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec007/bundle_graph_fixture.dart';

DomainUcRelationAvailable _relation(
  List<RawNode> nodes,
  String bundleKey, [
  String ucId = 'UC-01',
]) =>
    DomainUcRelationQuery(buildResult: buildResultOf(nodes))
            .relationOf(bundleIdOf(bundleKey), ucId)
        as DomainUcRelationAvailable;

List<String> _domains(List<BundleLayerEntry> entries) => [
  for (final e in entries) e.domain,
];

List<List<String>> _domainPaths(DomainUcRelationAvailable r) => [
  for (final p in r.paths) [for (final b in p) b.domain],
];

DomainUcRelationAvailable _snapshotCell(
  GraphBuiltEvent event,
  String domain,
  String ucId,
) {
  final id = event.domainResolver.bundleIds.firstWhere(
    (b) => event.domainResolver.domainOf(b) == domain,
  );
  final query = DomainUcRelationQuery(buildResult: GraphBuildAvailable(event));
  return query.relationOf(id, ucId) as DomainUcRelationAvailable;
}

const _ucIds = ['UC-01', 'UC-02', 'UC-03', 'UC-04', 'UC-05', 'UC-06'];

void main() {
  group('三值判定', () {
    test('G12-1 本專案快照：48 格 19／10／19，間接 10 格逐格一致', () async {
      final event = await loadSnapshotEvent('graph_project_docs_manager');
      final domains = [
        for (final id in event.domainResolver.bundleIds)
          event.domainResolver.domainOf(id)!,
      ];
      expect(domains, hasLength(8));
      final byKind = <DomainUcRelationKind, int>{};
      final indirect = <String>{};
      for (final domain in domains) {
        for (final uc in _ucIds) {
          final kind = _snapshotCell(event, domain, uc).kind;
          byKind[kind] = (byKind[kind] ?? 0) + 1;
          if (kind == DomainUcRelationKind.indirect) {
            indirect.add('$uc:$domain');
          }
        }
      }
      expect(byKind, {
        DomainUcRelationKind.direct: 19,
        DomainUcRelationKind.indirect: 10,
        DomainUcRelationKind.unrelated: 19,
      });
      expect(indirect, {
        for (final uc in ['UC-02', 'UC-03', 'UC-05']) ...[
          '$uc:schema',
          '$uc:workspace',
        ],
        'UC-04:corpus',
        'UC-04:schema',
        'UC-04:workspace',
        'UC-06:schema',
      });
    });

    test('G12-2 直接優先：UC 貫穿 X 與 Y，Y 亦自 X 可達 → 直接貫穿，路徑空', () {
      final r = _relation([
        bundleNode('y'),
        bundleNode('x', dependsOn: ['y']),
        ucNode('UC-01', [
          ['x'],
          ['y'],
        ]),
      ], 'y');
      expect(r.kind, DomainUcRelationKind.direct);
      expect(r.paths, isEmpty);
    });

    test('G12-3 E1：方向——Y 依賴 X（上游）為無關，反向後同格為間接', () {
      final upstream = _relation([
        bundleNode('x'),
        bundleNode('y', dependsOn: ['x']),
        ucNode('UC-01', [
          ['x'],
        ]),
      ], 'y');
      final downstream = _relation([
        bundleNode('y'),
        bundleNode('x', dependsOn: ['y']),
        ucNode('UC-01', [
          ['x'],
        ]),
      ], 'y');
      expect(upstream.kind, DomainUcRelationKind.unrelated);
      expect(downstream.kind, DomainUcRelationKind.indirect);
      expect(upstream.kind, isNot(downstream.kind));
    });

    test('G12-4 3 跳可達 X→A→B→Y 為間接（不限跳數）', () {
      final r = _relation([
        bundleNode('y'),
        bundleNode('b', dependsOn: ['y']),
        bundleNode('a', dependsOn: ['b']),
        bundleNode('x', dependsOn: ['a']),
        ucNode('UC-01', [
          ['x'],
        ]),
      ], 'y');
      expect(r.kind, DomainUcRelationKind.indirect);
      expect(_domainPaths(r), [
        ['x', 'a', 'b', 'y'],
      ]);
    });

    test('G12-5 兩個直接 domain 皆可達 Y：一個間接結果，兩個來源各一條路徑', () {
      final r = _relation([
        bundleNode('y'),
        bundleNode('x1', dependsOn: ['y']),
        bundleNode('x2', dependsOn: ['y']),
        ucNode('UC-01', [
          ['x1', 'x2'],
        ]),
      ], 'y');
      expect(r.kind, DomainUcRelationKind.indirect);
      expect(_domainPaths(r), [
        ['x1', 'y'],
        ['x2', 'y'],
      ]);
    });

    test('G12-6 flutter_balance 快照：間接 0 格', () async {
      final event = await loadSnapshotEvent('flutter_balance');
      final kinds = [
        for (final b in event.domainResolver.bundleIds)
          for (final uc in event.flowSubgraphs.keys)
            DomainUcRelationQuery(buildResult: GraphBuildAvailable(event))
                    .relationOf(b, uc)
                as DomainUcRelationAvailable,
      ];
      expect(kinds, isNotEmpty);
      expect(
        kinds.where((r) => r.kind == DomainUcRelationKind.indirect),
        isEmpty,
      );
    });
  });

  group('依賴路徑', () {
    test('G12-7 UC-04 × schema：間接依賴，兩條路徑依序 graph、ticketdetail 為來源', () async {
      final event = await loadSnapshotEvent('graph_project_docs_manager');
      final r = _snapshotCell(event, 'schema', 'UC-04');
      expect(r.kind, DomainUcRelationKind.indirect);
      expect(_domainPaths(r), [
        ['graph', 'corpus', 'schema'],
        ['ticketdetail', 'corpus', 'schema'],
      ]);
    });

    test(
      'G12-8 E1：UC-06 × schema 只有 corpus → schema，排除經直接 domain 的路徑',
      () async {
        final event = await loadSnapshotEvent('graph_project_docs_manager');
        final r = _snapshotCell(event, 'schema', 'UC-06');
        expect(_domainPaths(r), [
          ['corpus', 'schema'],
        ]);
        // 對照：中間節點 M 不是直接 domain 時，X → M → Y 會列出；
        // 是直接 domain 時只剩 M → Y（排除規則的鑑別）。
        final nodes = [
          bundleNode('y'),
          bundleNode('m', dependsOn: ['y']),
          bundleNode('x', dependsOn: ['m']),
        ];
        final viaPlain = _relation([
          ...nodes,
          ucNode('UC-01', [
            ['x'],
          ]),
        ], 'y');
        final viaDirect = _relation([
          ...nodes,
          ucNode('UC-01', [
            ['x', 'm'],
          ]),
        ], 'y');
        expect(_domainPaths(viaPlain), [
          ['x', 'm', 'y'],
        ]);
        expect(_domainPaths(viaDirect), [
          ['m', 'y'],
        ]);
      },
    );

    test('G12-9 同來源兩條同長最短路徑皆列，依中間節點在 FR-13 的先後（非 code point）', () {
      // p 為 L1，q 為 L2（q 另依賴 t）；code point 序 q 先於 p，FR-13 序 p 先於 q。
      final r = _relation([
        bundleNode('w'),
        bundleNode('y'),
        bundleNode('t', dependsOn: ['w']),
        bundleNode('p', domain: 'pz', dependsOn: ['y']),
        bundleNode('q', domain: 'qa', dependsOn: ['y', 't']),
        bundleNode('s', dependsOn: ['p', 'q']),
        ucNode('UC-01', [
          ['s'],
        ]),
      ], 'y');
      expect(_domainPaths(r), [
        ['s', 'pz', 'y'],
        ['s', 'qa', 'y'],
      ]);
    });

    test('G12-10 不同長度：短的在前（長路徑來源在 FR-13 序中排前，仍排後面）', () {
      // a、z 同為 L2，code point 序 a 先於 z：若不以長度優先，長路徑 a→m→y 會排前。
      final nodes = [
        bundleNode('w'),
        bundleNode('y'),
        bundleNode('t', dependsOn: ['w']),
        bundleNode('m', dependsOn: ['y']),
        bundleNode('a', dependsOn: ['m']),
        bundleNode('z', dependsOn: ['y', 't']),
        ucNode('UC-01', [
          ['a', 'z'],
        ]),
      ];
      final r = _relation(nodes, 'y');
      expect(_domainPaths(r), [
        ['z', 'y'],
        ['a', 'm', 'y'],
      ]);
      // 前提：FR-13 序中 a 確實排在 z 之前，使本案例對「長度優先」有鑑別力。
      final order = _domains(
        orderBundlesOf((buildResultOf(nodes) as GraphBuildAvailable).event),
      );
      expect(order.indexOf('a'), lessThan(order.indexOf('z')));
    });

    test('G12-10b 同一依賴值宣告兩次不產生重複路徑', () {
      final r = _relation([
        bundleNode('y'),
        bundleNode('x', dependsOn: ['y', 'y']),
        ucNode('UC-01', [
          ['x'],
        ]),
      ], 'y');
      expect(_domainPaths(r), [
        ['x', 'y'],
      ]);
    });

    test('G12-11 直接貫穿格、無關格的路徑為空', () {
      final nodes = [
        bundleNode('y'),
        bundleNode('x'),
        bundleNode('n'),
        ucNode('UC-01', [
          ['x', 'y'],
        ]),
      ];
      final direct = _relation(nodes, 'x');
      final unrelated = _relation(nodes, 'n');
      expect(direct.kind, DomainUcRelationKind.direct);
      expect(unrelated.kind, DomainUcRelationKind.unrelated);
      expect(direct.paths, isEmpty);
      expect(unrelated.paths, isEmpty);
    });

    test('G12-12 路徑元素為 DomainBundle 序列，可取回 domain 原值與節點 ID', () {
      final r = _relation([
        bundleNode('k1', domain: 'Dom-Y_1'),
        bundleNode('k2', domain: 'Dom-X 2', dependsOn: ['k1']),
        ucNode('UC-01', [
          ['Dom-X 2'],
        ]),
      ], 'k1');
      final path = r.paths.single;
      expect(path.map((b) => b.domain), ['Dom-X 2', 'Dom-Y_1']);
      expect(path.map((b) => b.bundleId), [bundleIdOf('k2'), bundleIdOf('k1')]);
    });
  });

  group('邊界', () {
    test('G12-13 E1：只計解析成功值——重複宣告、缺鍵不構成直接貫穿', () {
      final good = _relation([
        bundleNode('g', domain: 'graph'),
        ucNode('UC-01', [
          ['graph'],
        ]),
      ], 'g');
      final dup = _relation([
        bundleNode('g1', domain: 'graph'),
        bundleNode('g2', domain: 'graph'),
        ucNode('UC-01', [
          ['graph'],
        ]),
      ], 'g1');
      final absent = _relation([
        bundleNode('g', domain: 'graph'),
        ucNode('UC-01', [null]),
      ], 'g');
      final undeclared = _relation([
        bundleNode('g', domain: 'graph'),
        ucNode('UC-01', [
          ['nope'],
        ]),
      ], 'g');
      expect(good.kind, DomainUcRelationKind.direct);
      expect(dup.kind, DomainUcRelationKind.unrelated);
      expect(absent.kind, DomainUcRelationKind.unrelated);
      expect(undeclared.kind, DomainUcRelationKind.unrelated);
    });

    test('G12-14 守衛：圖不可用與未完成建圖不是「無關」；正向對照為可用圖的無關格', () {
      final bad = DomainUcRelationQuery(buildResult: unavailableBuildResult())
          .relationOf(bundleIdOf('x'), 'UC-01');
      expect(
        (bad as DomainUcRelationGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildUnavailable,
      );
      final pending = DomainUcRelationQuery(buildResult: null)
          .relationOf(bundleIdOf('x'), 'UC-01');
      expect(
        (pending as DomainUcRelationGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildNotCompleted,
      );
      final ok = _relation([
        bundleNode('x'),
        bundleNode('n'),
        ucNode('UC-01', [
          ['x'],
        ]),
      ], 'n');
      expect(ok.kind, DomainUcRelationKind.unrelated);
    });

    test('G12-15 NC-5：不在圖上的 DomainBundle 或 UC ID 回傳無關、路徑空，不拋例外', () {
      final nodes = [
        bundleNode('y'),
        bundleNode('x', dependsOn: ['y']),
        ucNode('UC-01', [
          ['x'],
        ]),
      ];
      final result = buildResultOf(nodes);
      final query = DomainUcRelationQuery(buildResult: result);
      final missingBundle = query.relationOf(bundleIdOf('nope'), 'UC-01');
      final missingUc = query.relationOf(bundleIdOf('y'), 'UC-99');
      for (final r in [missingBundle, missingUc]) {
        expect(r, isA<DomainUcRelationAvailable>());
        expect(
          (r as DomainUcRelationAvailable).kind,
          DomainUcRelationKind.unrelated,
        );
        expect(r.paths, isEmpty);
      }
      // 正向對照：同一張圖上存在的格得到間接依賴。
      final existing = query.relationOf(
        bundleIdOf('y'),
        'UC-01',
      ) as DomainUcRelationAvailable;
      expect(existing.kind, DomainUcRelationKind.indirect);
    });
  });
}
