// SPEC-008 FR-05：ticket 建檔事件標記（測試設計 §3.5 T-1～T-6、§4.4 不變式 9）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../../helpers/history/synthetic_git_log.dart';
import '../../../helpers/spec007/edge_table_builder.dart';

final _ticketPattern = RegExp(r'^[\w.]+-W\d+-\d+(\.\d+)*$');

const _edges = <String, EdgeSpec>{
  'blood': EdgeSpec(
    forwardField: 'parent_id',
    reverseField: 'children',
    direction: 'directed',
  ),
  'blockedBy': EdgeSpec(forwardField: 'blockedBy', direction: 'directed'),
  'spec_related': EdgeSpec(
    forwardField: 'related_specs',
    direction: 'directed',
  ),
};

const _ticketA = '0.1.0-W1-001';
const _ticketPath = 'docs/work-logs/v0.1.0/tickets/$_ticketA.md';

List<List<EdgeEvent>> eventsPerCommit(SyntheticLogBuilder log) {
  final table = buildEdgeTableJson(edges: _edges);
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
  return [for (final r in results) builder.processCommit(r)];
}

LogFileEntry add(String path, Map<String, Object?> fields) =>
    LogFileEntry.added(path, frontmatterLines(fields));

String show(EdgeEvent e) =>
    '${e.type.name}|${e.key.edgeTypeName}|${e.key.from}|${e.key.to}'
    '|${e.isTicketCreation}';

void main() {
  group('T ticket 建檔事件（FR-05）', () {
    test('T-1 新建 ticket 檔：parent_id 與 blockedBy 兩筆皆為建檔事件', () {
      final ev = eventsPerCommit(
        SyntheticLogBuilder().commit(
          'a',
          files: [
            add(_ticketPath, {
              'id': _ticketA,
              'parent_id': 'P',
              'blockedBy': ['B'],
            }),
          ],
        ),
      );
      expect(ev[0].map(show).toSet(), {
        'added|blockedBy|$_ticketA|B|true',
        'added|blood|$_ticketA|P|true',
      });
    });

    test('T-2 下一 commit 補 blockedBy 值：不是建檔事件（正向對照）', () {
      final before = {
        'id': _ticketA,
        'blockedBy': ['B'],
      };
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit('a', files: [add(_ticketPath, before)])
            .commit(
              'b',
              parents: ['a'],
              files: [
                LogFileEntry.modified(
                  _ticketPath,
                  before: frontmatterLines(before),
                  after: frontmatterLines({
                    'id': _ticketA,
                    'blockedBy': ['B', 'C'],
                  }),
                ),
              ],
            ),
      );
      expect(ev[1].map(show), ['added|blockedBy|$_ticketA|C|false']);
    });

    test('T-3 新建 SPEC 檔：不是建檔事件', () {
      final ev = eventsPerCommit(
        SyntheticLogBuilder().commit(
          'a',
          files: [
            add('docs/spec/x/SPEC-009.md', {
              'id': 'SPEC-009',
              'related_specs': ['SPEC-001'],
            }),
          ],
        ),
      );
      expect(ev[0].map(show), ['added|spec_related|SPEC-009|SPEC-001|false']);
    });

    test('T-4 新建 ticket 檔的同一 commit 刪除他檔的邊：移除事件不是建檔事件', () {
      const p = {
        'id': 'P',
        'children': ['X'],
      };
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit('a', files: [add('docs/p.md', p)])
            .commit(
              'b',
              parents: ['a'],
              files: [
                LogFileEntry.deleted('docs/p.md', frontmatterLines(p)),
                add(_ticketPath, {'id': _ticketA, 'parent_id': 'Q'}),
              ],
            ),
      );
      expect(ev[1].map(show).toSet(), {
        'removed|blood|X|P|false',
        'added|blood|$_ticketA|Q|true',
      });
    });

    test('T-5 位於 docs/proposals/ 但 id 符合 ticket 樣式：視為 ticket', () {
      final ev = eventsPerCommit(
        SyntheticLogBuilder().commit(
          'a',
          files: [
            add('docs/proposals/odd.md', {'id': _ticketA, 'parent_id': 'P'}),
          ],
        ),
      );
      expect(ev[0].map(show), ['added|blood|$_ticketA|P|true']);
    });

    test('T-6 邊的來源只含既有檔的宣告（新建 ticket 未宣告該邊）：不是建檔事件', () {
      const before = {'id': 'P'};
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit('a', files: [add('docs/p.md', before)])
            .commit(
              'b',
              parents: ['a'],
              files: [
                LogFileEntry.modified(
                  'docs/p.md',
                  before: frontmatterLines(before),
                  after: frontmatterLines({
                    'id': 'P',
                    'children': [_ticketA],
                  }),
                ),
                add(_ticketPath, {
                  'id': _ticketA,
                  'blockedBy': ['B'],
                }),
              ],
            ),
      );
      expect(ev[1].map(show).toSet(), {
        'added|blood|$_ticketA|P|false',
        'added|blockedBy|$_ticketA|B|true',
      });
    });
  });
}
