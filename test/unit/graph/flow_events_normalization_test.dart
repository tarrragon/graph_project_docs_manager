import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_key.dart';
import 'package:graph_project_docs_manager/graph/flow_query.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';

import '../../helpers/spec007/bundle_graph_fixture.dart';

FlowStepNode _stepWith(Map<String, dynamic> extra) {
  final result = buildResultOf([
    RawNode(
      path: 'docs/usecases/UC-01-open-project-and-reach-usable-state.md',
      frontmatter: {'id': 'UC-01'},
      typeName: flowSourceTypeName,
      flowSteps: [
        {'id': 's1', ...extra},
      ],
    ),
  ]);
  final flow = FlowQuery(buildResult: result).flowOf('UC-01');
  return (flow as FlowOfAvailable).subgraph.steps.single;
}

void main() {
  group('emits／consumes 正規化（FR-10 步驟屬性，單一實作）', () {
    test('F2-1 純量視同單元素清單', () {
      expect(flowKeysOf('EVT-A'), ['EVT-A']);
      expect(_stepWith({'emits': 'EVT-A'}).emitsNames, ['EVT-A']);
    });

    test('F2-2 空元素略過（null、空字串、空清單）', () {
      expect(flowKeysOf(['EVT-A', null, '', [], 'EVT-B']), ['EVT-A', 'EVT-B']);
      expect(flowKeysOf(null), isEmpty);
      expect(flowKeysOf(''), isEmpty);
      expect(_stepWith({'consumes': <Object?>[]}).consumesNames, isEmpty);
    });

    test('F2-3 非字串元素以 flowKeyOf 轉字串', () {
      expect(flowKeysOf([7, 'EVT-A']), ['7', 'EVT-A']);
      expect(_stepWith({'consumes': 7}).consumesNames, ['7']);
    });

    test('F2-4 缺鍵給空清單；emits 與 consumes 各自獨立', () {
      final step = _stepWith({'emits': 'EVT-A'});
      expect(step.emitsNames, ['EVT-A']);
      expect(step.consumesNames, isEmpty);
    });
  });
}
