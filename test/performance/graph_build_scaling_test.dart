/// G9 NFR-02：建圖計算量與引用值總數成正比。
///
/// 以注入計數器記 ID 索引查詢次數，不以牆鐘時間作 pass-fail（D1）。
/// 執行：`fvm flutter test test/performance/`。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import '../helpers/spec007/known_distribution_fixture.dart';
import '../helpers/spec007/raw_node_builder.dart';

List<RawNode> _syntheticCorpus(int n) => [
  for (var i = 0; i < n; i++)
    buildRawNode(
      id: '0.1.0-W1-${i + 1}',
      extra: {
        'blockedBy': ['0.1.0-W1-${(i + 1) % n + 1}'],
      },
    ),
];

({int lookups, int references}) _measure(int n) {
  var lookups = 0;
  final inputs = graphInputsFrom();
  final event = buildGraphFromInputs(
    rawNodes: _syntheticCorpus(n),
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
    onIdLookup: () => lookups++,
  );
  return (lookups: lookups, references: event.totalReferences);
}

/// 含 flow 步驟的 UC 語料（G9-INV：G9-1 本身不改，另補 G9-2；
/// G9-2 只驗證 flow 解析不走主圖 ID 索引，不宣稱 flow 解析本身的計算量）。
List<RawNode> _flowCorpus(int n) => [
  for (var i = 0; i < n; i++)
    RawNode(
      path: 'docs/UC-$i.md',
      frontmatter: {'id': 'UC-$i'},
      typeName: 'UC',
      flowSteps: [
        {'id': 's1'},
        {'id': 's2', 'branch_from': 's1', 'next': 'ghost'},
      ],
    ),
];

int _lookupsOf(List<RawNode> nodes) {
  var lookups = 0;
  final inputs = graphInputsFrom();
  buildGraphFromInputs(
    rawNodes: nodes,
    edgeTypes: inputs.edgeTypes,
    nodeTypes: inputs.nodeTypes,
    onIdLookup: () => lookups++,
  );
  return lookups;
}

void main() {
  test('G9-2 flow 解析不走主圖 ID 索引：加入 flow 語料不增加查詢次數', () {
    expect(_lookupsOf(_flowCorpus(100)), 0);
    expect(_lookupsOf(_flowCorpus(1000)), 0);
    for (final n in [100, 1000]) {
      final withFlow = _lookupsOf([..._syntheticCorpus(n), ..._flowCorpus(n)]);
      expect(withFlow, _measure(n).lookups, reason: 'n=$n');
    }
  });

  test('G9-1 ID 索引查詢次數與引用值總數成正比（N 與 10N）', () {
    final small = _measure(100);
    final large = _measure(1000);
    expect(small.references, 100);
    expect(large.references, 1000);
    expect(small.lookups, small.references);
    expect(large.lookups, large.references);
    expect(large.lookups, small.lookups * 10);
  });
}
