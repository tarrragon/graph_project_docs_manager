import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_query.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';

const _root = 'test/fixtures/spec001/corpus_snapshot';

TypeTable _table() => TypeTableBuilder()
    .addType(
      'UC',
      idPattern: r'^UC-\d{2}$',
      carrierPathPatterns: const [
        PathPatternSpec(
          pattern: r'^docs/usecases/.*\.md$',
          specificity: [2, 0],
        ),
      ],
    )
    .build();

/// 快照 UC 檔只含 flow 區塊（無 frontmatter），補最小 frontmatter 後掃描。
Future<FlowQuery> _queryOf(String project) async =>
    FlowQuery(buildResult: await _buildOf(project));

Future<GraphBuildResult> _buildOf(String project) async {
  final fs = FakeDocsFileSystem();
  final dir = Directory('$_root/$project/docs/usecases');
  for (final file in dir.listSync().whereType<File>()) {
    final id = RegExp(r'^UC-\d+').firstMatch(file.uri.pathSegments.last)![0]!;
    fs.addFile('docs/usecases/$id.md', [
      ...utf8.encode('---\nid: $id\n---\n\n'),
      ...file.readAsBytesSync(),
    ]);
  }
  final scan = await scanCorpus(
    fileSystem: fs,
    table: _table(),
    builtinTable: _table(),
  );
  final result = buildGraph(
    rawNodes: scan.rawNodes,
    projectSchemaJson: loadBuiltinSchemaJson(),
    builtinSchemaJson: loadBuiltinSchemaJson(),
  );
  return result;
}

/// 分支步的期望：(id, branch_from, return_to 或 null, next 原值)。
typedef _Branch = (String, String, String?, List<String>);

class _Expected {
  const _Expected(this.mainline, this.branches, this.returns);
  final List<String> mainline;
  final List<_Branch> branches;
  final List<String> returns;
}

// 期望值逐字取自快照 flow 區塊（兩份語料共 7 個 UC、49 步）。
const _gpdm = <String, _Expected>{
  'UC-01': _Expected(
    ['select-folder', 'load-schema', 'parse-nodes', 'reach-domain-view'],
    [
      ('folder-unavailable', 'select-folder', 'select-folder', []),
      ('empty-graph', 'parse-nodes', null, []),
      ('schema-rejected', 'load-schema', 'select-folder', []),
    ],
    ['folder-unavailable', 'schema-rejected'],
  ),
  'UC-02': _Expected(
    [
      'locate-domain',
      'read-traversal-count',
      'switch-to-swimlane',
      'inspect-steps',
    ],
    [
      ('matrix-overview-only', 'read-traversal-count', null, []),
      ('enter-from-ticket', 'locate-domain', null, ['read-traversal-count']),
      ('flow-not-structured', 'switch-to-swimlane', 'locate-domain', []),
    ],
    ['flow-not-structured'],
  ),
  'UC-03': _Expected(
    ['select-uc', 'view-steps', 'jump-to-node'],
    [
      ('jump-to-domain', 'view-steps', null, []),
      ('inspect-event-flow', 'view-steps', 'view-steps', []),
      ('flow-block-absent', 'select-uc', 'select-uc', []),
    ],
    ['inspect-event-flow', 'flow-block-absent'],
  ),
  'UC-04': _Expected(
    [
      'select-proposal',
      'expand-downstream',
      'inspect-status',
      'jump-to-detail',
    ],
    [
      ('reverse-trace', 'select-proposal', null, ['inspect-status']),
      ('chain-broken', 'expand-downstream', 'expand-downstream', []),
    ],
    ['chain-broken'],
  ),
  'UC-05': _Expected(
    ['enter-ticket-list', 'trigger-load', 'switch-to-topic', 'locate-blocked'],
    [
      ('filter-in-list-mode', 'switch-to-topic', 'switch-to-topic', []),
      ('cancel-loading', 'trigger-load', 'enter-ticket-list', []),
      ('damaged-tickets', 'trigger-load', null, []),
    ],
    ['filter-in-list-mode', 'cancel-loading'],
  ),
  'UC-06': _Expected(
    ['enter-gap-report', 'view-categories', 'locate-item', 'open-source-file'],
    [
      ('rescan', 'open-source-file', 'view-categories', ['view-categories']),
      ('no-gaps', 'view-categories', null, []),
      ('gaps-undeterminable', 'view-categories', null, []),
    ],
    ['rescan'],
  ),
};

const _balance = <String, _Expected>{
  'UC-01': _Expected(
    [
      'create-accounts',
      'first-inventory',
      'view-net-worth',
      'assess-leverage',
      'periodic-inventory',
    ],
    [
      ('currency-switch', 'view-net-worth', 'view-net-worth', []),
      ('cashflow-runway', 'view-net-worth', 'view-net-worth', []),
      ('backup-restore', 'create-accounts', 'create-accounts', []),
      ('reject-invalid-input', 'first-inventory', 'first-inventory', []),
    ],
    [
      'currency-switch',
      'cashflow-runway',
      'backup-restore',
      'reject-invalid-input',
    ],
  ),
};

/// 記錄內含 List 時 == 為參照比較，改以字串鍵比對。
String _key(_Branch b) => '${b.$1}|${b.$2}|${b.$3}|${b.$4.join(',')}';

void _expectFlow(FlowQuery q, Map<String, _Expected> expected) {
  expected.forEach((ucId, want) {
    final g = (q.flowOf(ucId) as FlowOfAvailable).subgraph;
    expect([for (final s in g.mainline) s.id], want.mainline, reason: ucId);
    expect(
      [
        for (final s in g.branches)
          _key((
            s.id! as String,
            g.targetOf(s.branchFrom!)!.id! as String,
            s.returnTo == null ? null : g.targetOf(s.returnTo!)!.id! as String,
            List<String>.from(s.next! as List),
          )),
      ],
      want.branches.map(_key).toList(),
      reason: ucId,
    );
    expect([for (final s in g.returns) s.id], want.returns, reason: ucId);
  });
}

void main() {
  group('G10-16 兩語料的 flowOf 與 flow 區塊逐項一致（FR-10 驗收 1）', () {
    test('graph_project_docs_manager 六個 UC', () async {
      _expectFlow(await _queryOf('graph_project_docs_manager'), _gpdm);
    });

    test('flutter_balance 一個 UC', () async {
      _expectFlow(await _queryOf('flutter_balance'), _balance);
    });

    // 本測試的型別表不含 DomainBundle，故不測 traverses；`traverses` 缺陷
    // 排除後，FR-10 的 flow 缺陷（參照未解析、step id 重複）為 0。
    test('兩份語料的 FR-10 flow 缺陷數皆為 0（next 逐元素解析，FR-10 v1.24）', () async {
      for (final project in ['graph_project_docs_manager', 'flutter_balance']) {
        final built = await _buildOf(project) as GraphBuildAvailable;
        final flowDefects = built.event.graphDefects
            .whereType<FlowGraphDefect>()
            .where(
              (d) =>
                  d.kind == FlowDefectKind.unresolvedReference ||
                  d.kind == FlowDefectKind.duplicateStepId,
            )
            .toList();
        expect(flowDefects, isEmpty, reason: project);
      }
    });

    test('主線 next 屬性原樣為清單，不影響主線順序', () async {
      final q = await _queryOf('graph_project_docs_manager');
      final g = (q.flowOf('UC-01') as FlowOfAvailable).subgraph;
      expect(g.mainline.first.next, ['load-schema']);
      expect(g.mainline.last.next, <String>[]);
    });
  });
}
