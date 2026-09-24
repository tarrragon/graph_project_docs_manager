import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/lost_fields.dart';

void main() {
  group('lostFields (SPEC-006-test-design §3.2 C6, EVT-CORPUS-003)', () {
    test('C6-1 DomainBundle 失敗檔（無寫出鍵）', () {
      final result = lostFields(
        completenessFields: {'id', 'domain'},
        writtenFields: const {},
        isTied: false,
      );

      expect(result, unorderedEquals({'id', 'domain'}));
    });

    test(
      'C6-2（E1 鑑別，守衛）以鍵存在而非真值判斷；null／空清單算已寫出',
      () {
        final withNullAndEmpty = lostFields(
          completenessFields: {'id', 'title', 'status'},
          writtenFields: const {'id': 'X', 'title': null, 'status': <String>[]},
          isTied: false,
        );

        expect(
          withNullAndEmpty,
          isEmpty,
          reason: 'title:null、status:[] 皆算已寫出的鍵，不列入 lostFields',
        );

        // 對照輸入：只寫出 id，title/status 完全未出現在寫出鍵集合中。
        final withoutTitleStatus = lostFields(
          completenessFields: {'id', 'title', 'status'},
          writtenFields: const {'id': 'X'},
          isTied: false,
        );

        expect(withoutTitleStatus, unorderedEquals({'title', 'status'}));

        // 兩者結果必須不同，證明實作以「鍵是否存在於寫出鍵集合」判斷，
        // 而非以「值是否為真」判斷（若誤用真值判斷，null/[] 會被誤報為
        // 缺漏，withNullAndEmpty 會等於 withoutTitleStatus）。
        expect(withNullAndEmpty, isNot(equals(withoutTitleStatus)));
      },
    );

    test('C6-3 平手', () {
      final result = lostFields(
        completenessFields: {'id', 'domain'},
        writtenFields: const {},
        isTied: true,
      );

      expect(result, isEmpty);
    });

    test('C6-4 Ticket（無完整性集合）', () {
      final result = lostFields(
        completenessFields: const <String>{},
        writtenFields: const {},
        isTied: false,
      );

      expect(result, isEmpty);
    });

    test('C6-5 型別表無 completeness_fields 鍵（W1-079 之前的 JSON）', () {
      final result = lostFields(
        completenessFields: null,
        writtenFields: const {},
        isTied: false,
      );

      expect(result, isEmpty);
    });

    test('C6-6 集合順序：結果為集合語意，順序不影響相等判斷', () {
      final a = lostFields(
        completenessFields: {'id', 'domain', 'title'},
        writtenFields: const {},
        isTied: false,
      );
      final b = lostFields(
        completenessFields: {'title', 'id', 'domain'},
        writtenFields: const {},
        isTied: false,
      );

      expect(a.toSet(), b.toSet());
      expect(a.toSet(), {'id', 'domain', 'title'});
    });
  });
}
