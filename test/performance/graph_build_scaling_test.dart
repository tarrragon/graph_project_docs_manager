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

void main() {
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
