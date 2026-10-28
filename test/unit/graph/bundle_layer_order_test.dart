// 需求：SPEC-007 FR-13 / SPEC-007-test-design G13-1～G13-13
// 期望值取規格與凍結快照（SPEC-001 §1 列序期望值），不由實作輸出自算。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/domain_uc_relation.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:intl/intl.dart';

import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/spec007/bundle_graph_fixture.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/log_recorder.dart';
import '../../helpers/spec007/raw_node_builder.dart';

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

  group('依賴來源前提', () {
    test('型別表 bundle_dependency 無反向欄位（_brokenDependents 不需過濾 isReverse）', () {
      final schema = loadBuiltinSchemaJson();
      final edge =
          (schema['edge_types']
                  as Map<String, dynamic>)[bundleDependencyEdgeType]
              as Map<String, dynamic>;
      expect(edge['reverse_field'], isNull);
      expect(edge['forward_field'], 'depends_on_bundles');
    });

    test('同一依賴值宣告兩次只算一條依賴邊', () {
      final event = (buildResultOf([
        bundleNode('a'),
        bundleNode('b', dependsOn: ['a', 'a']),
      ]) as GraphBuildAvailable).event;
      expect(bundleDependenciesOf(event), hasLength(1));
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

    // 限制：實作完全不讀 locale（以 runes 逐 code point 比較，未使用 Intl），
    // 切換 Intl locale 對結果沒有作用；本案例是規格案例本身的限制，只能固定「兩次結果相同」。
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

  group('0.5.0-W1-139 裁決落地', () {
    test('T3 Y1：depends_on_bundles 指向自己者推不出層、接在最後；E1 去掉自我依賴為 L0', () {
      final withSelf = _order([
        bundleNode('s', dependsOn: ['s']),
        bundleNode('z'),
      ]);
      expect(_asLayoutRecords(withSelf), [
        (domain: 'z', layer: 0),
        (domain: 's', layer: null),
      ]);
      final withoutSelf = _order([bundleNode('s'), bundleNode('z')]);
      expect(_asLayoutRecords(withoutSelf), [
        (domain: 's', layer: 0),
        (domain: 'z', layer: 0),
      ]);
      // 自我依賴與其他依賴並存：依宣告判定，仍推不出層，且依賴它者同樣推不出層。
      final mixed = _layerByDomain(
        _order([
          bundleNode('a'),
          bundleNode('s', dependsOn: ['a', 's']),
          bundleNode('d', dependsOn: ['s']),
        ]),
      );
      expect(mixed, {'a': 0, 's': null, 'd': null});
    });

    test('T4 Z3：四種無效 domain 皆出現、層號照算，同層排在有效者之後並依 bundle ID', () {
      final entries = _order([
        bundleNode('z', domain: 'zz'),
        _rawBundle('a', {domainBundleDomainField: 7}),
        _rawBundle('b', {domainBundleDomainField: null}),
        _rawBundle('c', const {}),
        _rawBundle('d', {domainBundleDomainField: ''}),
      ]);
      // 依列首文字排序會得 b、c、d、a（'' 先於 '7'）；依 bundle ID 則 a 在前。
      expect(_ids(entries), [
        bundleIdOf('z'),
        bundleIdOf('a'),
        bundleIdOf('b'),
        bundleIdOf('c'),
        bundleIdOf('d'),
      ]);
      // 列首：非字串轉字串，null、缺鍵、空字串為空字串；層號皆照依賴計算（無依賴即 L0）。
      expect(_asLayoutRecords(entries), [
        (domain: 'zz', layer: 0),
        (domain: '7', layer: 0),
        (domain: '', layer: 0),
        (domain: '', layer: 0),
        (domain: '', layer: 0),
      ]);
    });

    test('T4 Z3 E1：L0 domain 有效 vs 無效，下游層號相同、排序位置不同', () {
      List<RawNode> nodes(Map<String, dynamic> baseExtra) => [
        _rawBundle('base', baseExtra),
        bundleNode('m'),
        bundleNode('x', dependsOn: ['base']),
      ];
      final valid = _order(nodes({domainBundleDomainField: 'a'}));
      final invalid = _order(nodes({domainBundleDomainField: null}));
      Map<String, int?> layers(List<BundleLayerEntry> e) => {
        for (final x in e) x.bundleId: x.layer,
      };
      expect(layers(invalid), layers(valid));
      expect(layers(invalid), {
        bundleIdOf('base'): 0,
        bundleIdOf('m'): 0,
        bundleIdOf('x'): 1,
      });
      expect(_ids(valid), [
        bundleIdOf('base'),
        bundleIdOf('m'),
        bundleIdOf('x'),
      ]);
      expect(_ids(invalid), [
        bundleIdOf('m'),
        bundleIdOf('base'),
        bundleIdOf('x'),
      ]);
    });

    test('T4 Z3：推不出層者之間，domain 無效者排在有效者之後並依 bundle ID', () {
      final entries = _order([
        bundleNode('z'),
        bundleNode('x', dependsOn: ['y']),
        _rawBundle('y', {
          domainBundleDomainField: 7,
          'depends_on_bundles': [bundleIdOf('x')],
        }),
      ]);
      // 依列首文字排序會把 '7' 排在 'x' 之前。
      expect(_asLayoutRecords(entries), [
        (domain: 'z', layer: 0),
        (domain: 'x', layer: null),
        (domain: '7', layer: null),
      ]);
    });

    test('G13-21 Z3：domain 為 [] 與 {} 的 bundle 留列、列首為轉字串值、層號照算、同層排在有效者之後；E1 改為有效字串則排序位置不同', () {
      List<RawNode> nodes(Object? eDomain, Object? fDomain) => [
        bundleNode('z', domain: 'zz'),
        _rawBundle('e', {domainBundleDomainField: eDomain}),
        _rawBundle('f', {domainBundleDomainField: fDomain}),
        _rawBundle('d', {
          domainBundleDomainField: 'dd',
          'depends_on_bundles': [bundleIdOf('e')],
        }),
      ];
      final empty = _order(nodes(<Object?>[], <String, Object?>{}));
      expect(_ids(empty), [
        bundleIdOf('z'),
        bundleIdOf('e'),
        bundleIdOf('f'),
        bundleIdOf('d'),
      ]);
      expect(_asLayoutRecords(empty), [
        (domain: 'zz', layer: 0),
        (domain: '[]', layer: 0),
        (domain: '{}', layer: 0),
        (domain: 'dd', layer: 1),
      ]);
      // E1：同 fixture 改為有效字串 domain，層號相同、排序位置不同。
      final valid = _order(nodes('aa', 'bb'));
      expect(_ids(valid), [
        bundleIdOf('e'),
        bundleIdOf('f'),
        bundleIdOf('z'),
        bundleIdOf('d'),
      ]);
      Map<String, int?> layers(List<BundleLayerEntry> es) => {
        for (final x in es) x.bundleId: x.layer,
      };
      expect(layers(valid), layers(empty));
    });

    test('T5 依賴指向存在但不是 DomainBundle 的節點：推不出層', () {
      final entries = _order([
        buildRawNode(id: 'PROP-900', typeName: 'PROP'),
        bundleNode('x'),
        buildRawNode(
          id: bundleIdOf('c'),
          typeName: domainBundleTypeName,
          extra: {
            domainBundleDomainField: 'c',
            'depends_on_bundles': ['PROP-900'],
          },
        ),
      ]);
      expect(_asLayoutRecords(entries), [
        (domain: 'x', layer: 0),
        (domain: 'c', layer: null),
      ]);
    });

    test('T6 同 domain 同層：依 bundle ID code point 序；交換宣告順序結果不變', () {
      List<String> ids(List<RawNode> n) => [
        for (final e in _order(n)) e.bundleId,
      ];
      final forward = ids([
        bundleNode('p', domain: 'dup'),
        bundleNode('q', domain: 'dup'),
      ]);
      final reversed = ids([
        bundleNode('q', domain: 'dup'),
        bundleNode('p', domain: 'dup'),
      ]);
      expect(forward, [bundleIdOf('p'), bundleIdOf('q')]);
      expect(reversed, forward);
    });

    test('T7 圖不可用日誌：同一 buildResult 只記一次；null 以實例為單位', () {
      final recorder = LogRecorder();
      final shared = unavailableBuildResult();
      final a = BundleLayerQuery(buildResult: shared, logSink: recorder.sink);
      final b = BundleLayerQuery(buildResult: shared, logSink: recorder.sink);
      for (var i = 0; i < 3; i++) {
        a.orderedBundles();
        b.orderedBundles();
      }
      final logs = recorder.ofEvent(GraphLogEvent.bundleOrderUnavailable);
      expect(logs, hasLength(1));
      expect(recorder.entries, hasLength(1));
      expect(logs.single.payload.keys, [GraphLogKeys.reason]);
      final n1 = BundleLayerQuery(buildResult: null, logSink: recorder.sink);
      final n2 = BundleLayerQuery(buildResult: null, logSink: recorder.sink);
      for (var i = 0; i < 3; i++) {
        n1.orderedBundles();
        n2.orderedBundles();
      }
      expect(
        recorder.ofEvent(GraphLogEvent.bundleOrderUnavailable),
        hasLength(3),
      );
      // 正向對照：可用圖不記日誌。
      final before = recorder.entries.length;
      BundleLayerQuery(
        buildResult: buildResultOf([bundleNode('a')]),
        logSink: recorder.sink,
      ).orderedBundles();
      expect(recorder.entries, hasLength(before));
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

/// 以完整 frontmatter 建 DomainBundle（可缺 `domain` 鍵或給無效值）。
RawNode _rawBundle(String key, Map<String, dynamic> extra) => buildRawNode(
  id: bundleIdOf(key),
  typeName: domainBundleTypeName,
  extra: extra,
);

List<String> _ids(List<BundleLayerEntry> entries) => [
  for (final e in entries) e.bundleId,
];

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
