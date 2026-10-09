// 需求：SPEC-007 FR-13 / SPEC-007-test-design G13-1～G13-13
// 期望值取規格與凍結快照（SPEC-001 §1 列序期望值），不由實作輸出自算。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/domain_uc_relation.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:intl/intl.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec007/bundle_graph_fixture.dart';

List<BundleLayerEntry> _order(List<RawNode> nodes) {
  final result = BundleLayerQuery(buildResult: buildResultOf(nodes))
      .orderedBundles();
  return (result as BundleOrderAvailable).entries;
}

List<String> _domains(List<BundleLayerEntry> entries) => [
  for (final e in entries) e.domain,
];

Map<String, int?> _layerByDomain(List<BundleLayerEntry> entries) => {
  for (final e in entries) e.domain: e.layer,
};

/// Layout 已在用的列序形狀；轉接放呼叫端，這裡驗證可無損轉換。
List<({String domain, int? layer})> _asLayoutRecords(
  List<BundleLayerEntry> entries,
) => [for (final e in entries) (domain: e.domain, layer: e.layer)];

const _snapshotOrder = <({String domain, int? layer})>[
  (domain: 'schema', layer: 0),
  (domain: 'workspace', layer: 0),
  (domain: 'corpus', layer: 1),
  (domain: 'history', layer: 1),
  (domain: 'diagnostics', layer: 2),
  (domain: 'graph', layer: 2),
  (domain: 'ticketdetail', layer: 2),
  (domain: 'layout', layer: 3),
];

Future<GraphBuiltEvent> _snapshot() =>
    loadSnapshotEvent('graph_project_docs_manager');

void main() {
  group('分層', () {
    test('G13-1 本專案快照：排序與層號（回傳形狀可無損轉成 Layout record）', () async {
      final event = await _snapshot();
      final entries = orderBundlesOf(event);
      expect(_asLayoutRecords(entries), _snapshotOrder);
      // 正向對照：無環、無斷邊時沒有任何推不出層者。
      expect(entries.every((e) => e.layer != null), isTrue);
    });

    test('G13-2 E1：A→{B,C}、C→B 時 A 為 L2（max+1，非 min+1）', () {
      final layers = _layerByDomain(
        _order([
          bundleNode('a', dependsOn: ['b', 'c']),
          bundleNode('b'),
          bundleNode('c', dependsOn: ['b']),
        ]),
      );
      expect(layers['a'], 2);
      expect(layers['a'], isNot(1)); // 以最小層 +1 計算會得 1
      expect(layers['b'], 0);
      expect(layers['c'], 1);
    });

    test('G13-3 history 只依賴 workspace 時為 L1', () {
      final layers = _layerByDomain(
        _order([
          bundleNode('workspace'),
          bundleNode('history', dependsOn: ['workspace']),
        ]),
      );
      expect(layers, {'workspace': 0, 'history': 1});
    });
  });

  group('層內排序', () {
    test('G13-4 同層 graph、diagnostics、ticketdetail 依 code point 序', () {
      final order = _domains(
        _order([
          bundleNode('graph'),
          bundleNode('ticketdetail'),
          bundleNode('diagnostics'),
        ]),
      );
      expect(order, ['diagnostics', 'graph', 'ticketdetail']);
    });

    test('G13-5 E1：code point 序 B、a-z、a_z、b，與 locale 序不同', () {
      final order = _domains(_order(_g135Nodes()));
      expect(order, ['B', 'a-z', 'a_z', 'b']);
      // locale 序（不分大小寫）：B 排在 a-z、a_z 之後。
      expect(order, isNot(['a-z', 'a_z', 'b', 'B']));
      expect(order, isNot(['a-z', 'a_z', 'B', 'b']));
    });

    test('G13-6 E1：標點的 code point，a-c 先於 ab（與忽略標點的序相反）', () {
      final order = _domains(_order(_g136Nodes()));
      expect(order, ['a-c', 'ab']);
      expect(order, isNot(['ab', 'a-c']));
    });

    test('G13-7 執行環境 locale 切 zh 與 en 結果逐值相同', () {
      List<List<String>> run() => [
        _domains(_order(_g135Nodes())),
        _domains(_order(_g136Nodes())),
      ];
      final zh = Intl.withLocale('zh_TW', run);
      final en = Intl.withLocale('en', run);
      expect(zh, en);
      expect(zh, [
        ['B', 'a-z', 'a_z', 'b'],
        ['a-c', 'ab'],
      ]);
    });

    test('G13-5b code point 而非 UTF-16 碼元：補充平面字元大於 U+FFFF 以下字元', () {
      // U+20000 的 UTF-16 首碼元 0xD840 小於 U+FF21，但 code point 較大。
      final order = _domains(
        _order([
          bundleNode('p1', domain: '\u{20000}'),
          bundleNode('p2', domain: 'Ａ'),
        ]),
      );
      expect(order, ['Ａ', '\u{20000}']);
    });
  });

  group('推不出層與邊界', () {
    test('G13-8 守衛：成環 X、Y 接在可分層者之後，層號 null', () {
      final entries = _order([
        bundleNode('x', dependsOn: ['y']),
        bundleNode('y', dependsOn: ['x']),
        bundleNode('z'),
      ]);
      expect(_asLayoutRecords(entries), [
        (domain: 'z', layer: 0),
        (domain: 'x', layer: null),
        (domain: 'y', layer: null),
      ]);
    });

    test('G13-9 守衛：依賴指向未宣告的 ghost，X 接在最後且結果不含 ghost', () {
      final entries = _order([
        bundleNode('x', dependsOn: ['ghost']),
        bundleNode('z'),
      ]);
      expect(_domains(entries), ['z', 'x']);
      expect(entries.last.layer, isNull);
      expect(_domains(entries), isNot(contains('ghost')));
    });

    test('G13-10 兩種推不出層的原因不分組，三者依 code point 接在最後', () {
      final entries = _order([
        bundleNode('x', dependsOn: ['y']),
        bundleNode('y', dependsOn: ['x']),
        bundleNode('a', dependsOn: ['ghost']),
        bundleNode('z'),
      ]);
      expect(_domains(entries), ['z', 'a', 'x', 'y']);
      expect(entries.skip(1).every((e) => e.layer == null), isTrue);
    });

    test('G13-10b NC-8：c 依賴 L0 的 a 與成環 x，c 推不出層（不得算 L1）', () {
      final entries = _order([
        bundleNode('a'),
        bundleNode('c', dependsOn: ['a', 'x']),
        bundleNode('x', dependsOn: ['y']),
        bundleNode('y', dependsOn: ['x']),
      ]);
      expect(_asLayoutRecords(entries), [
        (domain: 'a', layer: 0),
        (domain: 'c', layer: null),
        (domain: 'x', layer: null),
        (domain: 'y', layer: null),
      ]);
      // 順著推不出層者傳遞：依賴 c 的 d 同樣推不出層。
      final chained = _layerByDomain(
        _order([
          bundleNode('a'),
          bundleNode('c', dependsOn: ['a', 'x']),
          bundleNode('d', dependsOn: ['c']),
          bundleNode('x', dependsOn: ['y']),
          bundleNode('y', dependsOn: ['x']),
        ]),
      );
      expect(chained['d'], isNull);
      expect(chained['a'], 0);
    });

    test('G13-11 E1：不寫死 domain 名，換名後層歸屬不變、層內序依新名稱', () async {
      final event = await _snapshot();
      const rename = {
        'schema': 'p8',
        'workspace': 'p7',
        'corpus': 'p6',
        'history': 'p5',
        'diagnostics': 'p3',
        'graph': 'p2',
        'ticketdetail': 'p1',
        'layout': 'p0',
      };
      final renamed = _order([
        for (final id in event.domainResolver.bundleIds)
          bundleNode(
            id.substring(bundleIdOf('').length),
            domain: rename[event.domainResolver.domainOf(id)],
            dependsOn: [
              for (final e in event.edges)
                if (e.edgeType == bundleDependencyEdgeType && e.from == id)
                  e.to.substring(bundleIdOf('').length),
            ],
          ),
      ]);
      final snapshotLayers = {
        for (final e in _snapshotOrder) rename[e.domain]!: e.layer,
      };
      expect(_layerByDomain(renamed), snapshotLayers);
      expect(_domains(renamed), [
        'p7',
        'p8',
        'p5',
        'p6',
        'p1',
        'p2',
        'p3',
        'p0',
      ]);
      expect(
        _domains(renamed),
        isNot([for (final e in _snapshotOrder) rename[e.domain]]),
      );
    });

    test('G13-12 守衛：圖不可用與未完成建圖不是空排序；正向對照為可用圖', () {
      final bad = BundleLayerQuery(buildResult: unavailableBuildResult())
          .orderedBundles();
      expect(
        (bad as BundleOrderGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildUnavailable,
      );
      final pending = BundleLayerQuery(buildResult: null).orderedBundles();
      expect(
        (pending as BundleOrderGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildNotCompleted,
      );
      final ok = BundleLayerQuery(buildResult: buildResultOf([bundleNode('a')]))
          .orderedBundles();
      expect(ok, isA<BundleOrderAvailable>());
      expect((ok as BundleOrderAvailable).entries, isNotEmpty);
    });
  });

  group('FR-12 共用排序', () {
    test('G13-13 E1：FR-12 路徑依 FR-13 層序（zeta L2 先於 alpha L3），非純 code point', () {
      final result = DomainUcRelationQuery(
        buildResult: buildResultOf([
          bundleNode('y'),
          bundleNode('m', dependsOn: ['y']),
          bundleNode('k', dependsOn: ['y', 'm']),
          bundleNode('zeta', dependsOn: ['m']),
          bundleNode('alpha', dependsOn: ['k']),
          ucNode('UC-01', [
            ['zeta'],
            ['alpha'],
          ]),
        ]),
      ).relationOf(bundleIdOf('y'), 'UC-01');
      final paths = (result as DomainUcRelationAvailable).paths;
      final domainPaths = [
        for (final p in paths) [for (final b in p) b.domain],
      ];
      expect(domainPaths, [
        ['zeta', 'm', 'y'],
        ['alpha', 'k', 'y'],
      ]);
      // 純 code point 排序會把 alpha 排前。
      expect(domainPaths.first.first, isNot('alpha'));
    });
  });
}

List<RawNode> _g135Nodes() => [
  bundleNode('n1', domain: 'b'),
  bundleNode('n2', domain: 'B'),
  bundleNode('n3', domain: 'a-z'),
  bundleNode('n4', domain: 'a_z'),
];

List<RawNode> _g136Nodes() => [
  bundleNode('n1', domain: 'ab'),
  bundleNode('n2', domain: 'a-c'),
];
