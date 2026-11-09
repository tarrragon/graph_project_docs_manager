// SPEC-008 FR-08 規則 3：淺層邊界（測試設計 §3.7 B-1～B-3）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../../helpers/history/synthetic_git_log.dart';
import '../../../helpers/spec007/edge_table_builder.dart';

final _ticketPattern = RegExp(r'^[\w.]+-W\d+-\d+(\.\d+)*$');
const _path = 'docs/work-logs/v0.1.0/tickets/0.1.0-W1-001.md';
const _id = '0.1.0-W1-001';

List<List<EdgeEvent>> _run(SyntheticLogBuilder log, {required bool shallow}) {
  final table = buildEdgeTableJson(
    edges: const {
      'blockedBy': EdgeSpec(forwardField: 'blockedBy', direction: 'directed'),
    },
  );
  final resolution = resolveEdgeTypes(
    projectSchemaJson: table,
    builtinSchemaJson: table,
  );
  final builder = EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: resolution.activeEdgeTypes,
      closedByIdPatterns: [_ticketPattern],
    ),
    ticketIdPattern: _ticketPattern,
  );
  final parser = ScanStreamParser();
  final results = [...parser.addChunk(log.toBytes()), ...parser.close()];
  return [
    for (final r in results)
      builder.processCommitWithShallow(r, isShallow: shallow),
  ];
}

SyntheticLogBuilder _log({List<String> blockedBy = const ['A', 'B', 'C']}) {
  final fields = {'id': _id, 'blockedBy': blockedBy};
  return SyntheticLogBuilder().commit(
    'root',
    files: [LogFileEntry.added(_path, frontmatterLines(fields))],
  );
}

void main() {
  group('B 淺層邊界（FR-08 規則 3）', () {
    test('B-1 淺層首 commit 無事件，後續 commit 照常產生', () {
      final log = _log().commit(
        'next',
        parents: ['root'],
        files: [
          LogFileEntry.modified(
            _path,
            before: frontmatterLines({
              'id': _id,
              'blockedBy': ['A', 'B', 'C'],
            }),
            after: frontmatterLines({
              'id': _id,
              'blockedBy': ['A', 'B', 'C', 'D'],
            }),
          ),
        ],
      );
      final ev = _run(log, shallow: true);
      expect(ev[0], isEmpty);
      expect(ev[1].map((e) => e.key.to), ['D']);
    });

    test('B-2 非淺層根 commit 產生 3 筆新增（正向對照）', () {
      final ev = _run(_log(), shallow: false);
      expect(ev[0].map((e) => e.type), everyElement(EdgeEventType.added));
      expect(ev[0], hasLength(3));
    });

    test('B-3 邊界後刪除邊界時已存在的邊：一筆移除', () {
      final log = _log().commit(
        'next',
        parents: ['root'],
        files: [
          LogFileEntry.modified(
            _path,
            before: frontmatterLines({
              'id': _id,
              'blockedBy': ['A', 'B', 'C'],
            }),
            after: frontmatterLines({
              'id': _id,
              'blockedBy': ['A', 'C'],
            }),
          ),
        ],
      );
      final ev = _run(log, shallow: true);
      expect(ev[0], isEmpty);
      expect(ev[1], hasLength(1));
      expect(ev[1].single.type, EdgeEventType.removed);
      expect(ev[1].single.key.to, 'B');
    });
  });
}
