// SPEC-008 FR-04：邊鍵換算與邊事件（測試設計 §3.4 K-1～K-9、§4.4 不變式 1～3）。
// 輸入經 012.6 的解析器與合成 git log，斷言只讀事件。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/events/edge_key.dart';
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
  'spawn': EdgeSpec(
    forwardField: 'source_ticket',
    reverseField: 'spawned_tickets',
    direction: 'directed',
  ),
  'association': EdgeSpec(forwardField: 'relatedTo', direction: 'undirected'),
};

EdgeEventBuilder newBuilder() {
  final table = buildEdgeTableJson(edges: _edges);
  final resolution = resolveEdgeTypes(
    projectSchemaJson: table,
    builtinSchemaJson: table,
  );
  return EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: resolution.activeEdgeTypes,
      closedByIdPatterns: [_ticketPattern],
    ),
    ticketIdPattern: _ticketPattern,
  );
}

List<List<EdgeEvent>> eventsPerCommit(
  SyntheticLogBuilder log, [
  EdgeEventBuilder? builder,
]) {
  final b = builder ?? newBuilder();
  final parser = ScanStreamParser();
  final results = [...parser.addChunk(log.toBytes()), ...parser.close()];
  return [for (final r in results) b.processCommit(r)];
}

List<String> fm(Map<String, Object?> fields) => frontmatterLines(fields);

LogFileEntry add(String path, Map<String, Object?> fields) =>
    LogFileEntry.added(path, fm(fields));

LogFileEntry change(
  String path,
  Map<String, Object?> before,
  Map<String, Object?> after,
) => LogFileEntry.modified(path, before: fm(before), after: fm(after));

LogFileEntry remove(String path, Map<String, Object?> fields) =>
    LogFileEntry.deleted(path, fm(fields));

String show(EdgeEvent e) =>
    '${e.type.name}|${e.key.edgeTypeName}|${e.key.from}|${e.key.to}';

void main() {
  group('K 邊鍵與事件（FR-04）', () {
    test('K-1 子寫 parent_id 產生新增（宣告者→值）；父補 children 無事件', () {
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit(
              'a',
              files: [
                add('docs/c.md', {'id': 'C', 'parent_id': 'P'}),
              ],
            )
            .commit(
              'b',
              parents: ['a'],
              files: [
                add('docs/p.md', {
                  'id': 'P',
                  'children': ['C'],
                }),
              ],
            ),
      );
      expect(ev[0].map(show), ['added|blood|C|P']);
      expect(ev[1], isEmpty);
    });

    test('K-2 刪 parent_id 而 children 仍在無事件；再刪 children 一筆移除', () {
      const child = {'id': 'C', 'parent_id': 'P'};
      const childNo = {'id': 'C'};
      const parent = {
        'id': 'P',
        'children': ['C'],
      };
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit('a', files: [add('docs/c.md', child)])
            .commit('b', parents: ['a'], files: [add('docs/p.md', parent)])
            .commit(
              'c',
              parents: ['b'],
              files: [change('docs/c.md', child, childNo)],
            )
            .commit(
              'd',
              parents: ['c'],
              files: [
                change('docs/p.md', parent, {'id': 'P'}),
              ],
            ),
      );
      expect(ev[2], isEmpty);
      expect(ev[3].map(show), ['removed|blood|C|P']);
    });

    test('K-3 無向邊兩端依字典序，兩側宣告同一邊鍵只有一筆新增', () {
      for (final order in [
        ['X', 'Y'],
        ['Y', 'X'],
      ]) {
        final ev = eventsPerCommit(
          SyntheticLogBuilder()
              .commit(
                'a',
                files: [
                  add('docs/${order[0]}.md', {
                    'id': order[0],
                    'relatedTo': [order[1]],
                  }),
                ],
              )
              .commit(
                'b',
                parents: ['a'],
                files: [
                  add('docs/${order[1]}.md', {
                    'id': order[1],
                    'relatedTo': [order[0]],
                  }),
                ],
              ),
        );
        expect(ev[0].map(show), ['added|association|X|Y']);
        expect(ev[1], isEmpty);
      }
    });

    const nFields = {
      'id': 'N',
      'relatedTo': ['Y', 'Z'],
    };

    SyntheticLogBuilder moveLog(Map<String, Object?> newFields) =>
        SyntheticLogBuilder()
            .commit('a', files: [add('docs/a/n.md', nFields)])
            .commit(
              'b',
              parents: ['a'],
              files: [
                remove('docs/a/n.md', nFields),
                add('docs/b/n.md', newFields),
              ],
            );

    test('K-4 同 commit 移到另一路徑：無事件', () {
      expect(eventsPerCommit(moveLog(nFields))[1], isEmpty);
    });

    test('K-6 同 K-4 但新路徑少一個值：一筆移除（正向對照）', () {
      final ev = eventsPerCommit(
        moveLog({
          'id': 'N',
          'relatedTo': ['Y'],
        }),
      );
      expect(ev[1].map(show), ['removed|association|N|Z']);
    });

    test('K-5 兩檔同 id 宣告同一邊：刪一檔無事件，刪另一檔一筆移除', () {
      const f = {'id': 'C', 'parent_id': 'P'};
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit('a', files: [add('docs/c1.md', f), add('docs/c2.md', f)])
            .commit('b', parents: ['a'], files: [remove('docs/c1.md', f)])
            .commit('c', parents: ['b'], files: [remove('docs/c2.md', f)]),
      );
      expect(ev[0].map(show), ['added|blood|C|P']);
      expect(ev[1], isEmpty);
      expect(ev[2].map(show), ['removed|blood|C|P']);
    });

    test('K-7 同 commit 多事件依邊型、起點、終點字典序，重跑一致', () {
      SyntheticLogBuilder log() => SyntheticLogBuilder().commit(
        'a',
        files: [
          add('docs/s.md', {'id': 'S1', 'source_ticket': 'S0'}),
          add('docs/b.md', {'id': 'B1', 'parent_id': 'P1'}),
          add('docs/r.md', {
            'id': 'R1',
            'relatedTo': ['R0'],
          }),
        ],
      );
      final expected = [
        'added|association|R0|R1',
        'added|blood|B1|P1',
        'added|spawn|S1|S0',
      ];
      expect(eventsPerCommit(log())[0].map(show), expected);
      expect(eventsPerCommit(log())[0].map(show), expected);
    });

    test('K-8 節點 id 改名：舊鍵移除、新鍵新增', () {
      final ev = eventsPerCommit(
        SyntheticLogBuilder()
            .commit(
              'a',
              files: [
                add('docs/x.md', {'id': 'X', 'parent_id': 'P'}),
              ],
            )
            .commit(
              'b',
              parents: ['a'],
              files: [
                change(
                  'docs/x.md',
                  {'id': 'X', 'parent_id': 'P'},
                  {'id': 'X2', 'parent_id': 'P'},
                ),
              ],
            ),
      );
      expect(ev[1].map(show).toSet(), {
        'removed|blood|X|P',
        'added|blood|X2|P',
      });
    });

    test('K-9 事件欄位；宣告者以節點 ID 去重', () {
      const f = {'id': 'C', 'parent_id': 'P'};
      final ev = eventsPerCommit(
        SyntheticLogBuilder().commit(
          'abc123',
          time: 1700000123,
          author: 'alice',
          subject: '首行',
          files: [add('docs/c1.md', f), add('docs/c2.md', f)],
        ),
      );
      final e = ev[0].single;
      expect(e.type, EdgeEventType.added);
      expect(e.key, const EdgeKey('blood', 'C', 'P'));
      expect(e.declarersBefore, isEmpty);
      expect(e.declarersAfter, ['C']);
      expect(e.commitId, 'abc123');
      expect(e.committedAtSeconds, 1700000123);
      expect(e.author, 'alice');
      expect(e.subject, '首行');
      expect(e.isTicketCreation, isFalse);
    });

    test('計數：非字串值與無 ID 檔案累計', () {
      final b = newBuilder();
      eventsPerCommit(
        SyntheticLogBuilder().commit(
          'a',
          files: [
            add('docs/a.md', {
              'id': 'A',
              'relatedTo': [3, true, 'B'],
            }),
            add('docs/n.md', {'parent_id': 'P'}),
          ],
        ),
        b,
      );
      expect(b.nonStringValues, 2);
      expect(b.filesWithoutId, 1);
    });
  });
}
