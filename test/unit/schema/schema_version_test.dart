// 版本比較單一實作（SPEC-006-test-design.md S5-7；0.3.0-W3-533）。
//
// 依賴方向：test/unit/schema/ 不得 import lib/corpus/、lib/diagnostics/。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/schema_version.dart';

void main() {
  group('isHigherThanBuiltinSchemaVersion', () {
    test('S5-7：2.40.3 對 2.40.10 判為低於（數值逐段比較，非字串比較）', () {
      // 若採字串比較，"2.40.3" > "2.40.10" 會成立（'3' > '1'）。
      expect(isHigherThanBuiltinSchemaVersion('2.40.3', '2.40.10'), isFalse);
    });

    test('版本相同判為不高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.40.3', '2.40.3'), isFalse);
    });

    test('版本較高判為高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.41.0', '2.40.3'), isTrue);
    });

    test('段數不足補零：2.40 對 2.40.0 判為不高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.40', '2.40.0'), isFalse);
    });

    test('無法解析為整數的段落視為高於（安全預設拒絕降級出口）', () {
      expect(isHigherThanBuiltinSchemaVersion('2.x.0', '2.40.3'), isTrue);
    });
  });

  group('isWithinKnownSchemaRange（0.3.0-W3-543：與 schema 不相容關卡共用的單一判定式）', () {
    test('version 為 null 判為不在範圍', () {
      expect(isWithinKnownSchemaRange(null, '2.40.3'), isFalse);
    });

    test('version 無法解析判為不在範圍', () {
      expect(isWithinKnownSchemaRange('2.x.0', '2.40.3'), isFalse);
    });

    test('version 高於內建判為不在範圍', () {
      expect(isWithinKnownSchemaRange('2.41.0', '2.40.3'), isFalse);
    });

    test('version 等於內建判為在範圍', () {
      expect(isWithinKnownSchemaRange('2.40.3', '2.40.3'), isTrue);
    });

    test('version 低於內建判為在範圍', () {
      expect(isWithinKnownSchemaRange('2.30.0', '2.40.3'), isTrue);
    });
  });

  group('classifySchemaVersion（0.3.0-W3-545：分辨版本太新與版本無法判讀）', () {
    test('version 為 null 分類為 Unreadable', () {
      expect(
        classifySchemaVersion(null, '2.40.3'),
        isA<Unreadable>(),
      );
    });

    test('version 為 "unknown" 分類為 Unreadable', () {
      expect(
        classifySchemaVersion('unknown', '2.40.3'),
        isA<Unreadable>(),
      );
    });

    test('version 高於內建分類為 HigherThanBuiltin', () {
      expect(
        classifySchemaVersion('2.41.0', '2.40.3'),
        isA<HigherThanBuiltin>(),
      );
    });

    test('version 等於內建分類為 InKnownRange', () {
      expect(
        classifySchemaVersion('2.40.3', '2.40.3'),
        isA<InKnownRange>(),
      );
    });

    test('version 低於內建分類為 InKnownRange', () {
      expect(
        classifySchemaVersion('2.30.0', '2.40.3'),
        isA<InKnownRange>(),
      );
    });

    test('段數不足補零：2.40 對 2.40.0 分類為 InKnownRange', () {
      expect(
        classifySchemaVersion('2.40', '2.40.0'),
        isA<InKnownRange>(),
      );
    });
  });
}
