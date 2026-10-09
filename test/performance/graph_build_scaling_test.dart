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

/// 含 flow 步驟的 UC 語料（G9-INV：G9-1 本身不改，另補 G9-2）。
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
  test('G9-2 含 flow 的語料：ID 索引查詢次數不受 flow 步驟影響，仍與引用值成正比', () {
    expect(_lookupsOf(_flowCorpus(100)), 0);
    expect(_lookupsOf(_flowCorpus(1000)), 0);
    final small = _lookupsOf([..._syntheticCorpus(100), ..._flowCorpus(100)]);
    final large = _lookupsOf([..._syntheticCorpus(1000), ..._flowCorpus(1000)]);
    expect(small, _measure(100).lookups);
    expect(large, small * 10);
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
