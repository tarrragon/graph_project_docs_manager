import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/ticket_detail/ticket_detail.dart';

import '../../helpers/spec007/raw_node_builder.dart';

void main() {
  final fullFields = <String, dynamic>{
    'who': {'current': 'a'},
    'what': '做事',
    'when': '隨時',
    'where': {'layer': 'Domain'},
    'why': '因為',
    'how': {'task_type': 'Implementation'},
  };

  group('T1 以 ID 查全文（SPEC-007 FR-07）', () {
    test('T1-1 以 ID 查得 frontmatter 逐鍵相等', () {
      final node = buildRawNode(id: 'T-1', extra: fullFields);
      final detail = TicketDetail.fromRawNodes([node]);
      expect(detail.findById('T-1'), equals(node.frontmatter));
    });

    test('T1-2 不存在的 ID 回傳 null 不拋例外', () {
      final detail = TicketDetail.fromRawNodes([buildRawNode(id: 'T-1')]);
      expect(() => detail.findById('T-9'), returnsNormally);
      expect(detail.findById('T-9'), isNull);
    });

    test('T1-3 非 Ticket 節點查詢回傳 null（正向對照 T1-1）', () {
      final detail = TicketDetail.fromRawNodes([
        buildRawNode(id: 'T-1'),
        buildRawNode(id: 'SPEC-001', typeName: 'SPEC'),
      ]);
      expect(detail.findById('SPEC-001'), isNull);
      expect(detail.findById('T-1'), isNotNull);
    });

    test('T1-4 重複 ID 回傳 null', () {
      final detail = TicketDetail.fromRawNodes([
        buildRawNode(id: 'T-1', path: 'a.md'),
        buildRawNode(id: 'T-1', path: 'b.md'),
        buildRawNode(id: 'T-2'),
      ]);
      expect(detail.findById('T-1'), isNull);
      expect(detail.findById('T-2'), isNotNull);
    });

    test('T1-5 新輸入取代舊輸入後舊輪獨有 ID 不存在', () {
      final old = TicketDetail.fromRawNodes([buildRawNode(id: 'T-OLD')]);
      expect(old.findById('T-OLD'), isNotNull);
      final fresh = TicketDetail.fromRawNodes([buildRawNode(id: 'T-NEW')]);
      expect(fresh.findById('T-OLD'), isNull);
      expect(fresh.findById('T-NEW'), isNotNull);
    });
  });

  test('T-immutable findById 回傳的 frontmatter 寫入拋 UnsupportedError', () {
    final node = buildRawNode(id: 'T-1', extra: fullFields);
    final detail = TicketDetail.fromRawNodes([node]);
    expect(() => detail.findById('T-1')!['x'] = 1, throwsUnsupportedError);
    expect(detail.findById('T-1'), equals(node.frontmatter));
  });
}
