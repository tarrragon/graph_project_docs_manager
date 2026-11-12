import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import 'observability_test_helpers.dart';

void main() {
  group('欄位值白名單', () {
    test('O3-2 工作區內路徑轉相對路徑', () {
      expect(
        WorkspaceRelativePath.tryCreate('/w', '/w/docs/spec/a.md')?.toJson(),
        'docs/spec/a.md',
      );
    });

    test('O3-3 工作區外絕對路徑建構失敗並改記 LogLocation', () {
      expect(
        WorkspaceRelativePath.tryCreate('/w', '/Users/someone/b.md'),
        isNull,
      );
      final fallback = LogValue.path('/w', '/Users/someone/b.md');
      expect(fallback.toJson(), 'other');
      expect(fallback.toJson().toString(), isNot(contains('/Users/')));
    });

    test('O3-4 前綴相同但不在根下、正規化後逃出根皆失敗', () {
      expect(WorkspaceRelativePath.tryCreate('/w', '/w2/a.md'), isNull);
      expect(WorkspaceRelativePath.tryCreate('/w', '/w/../x/a.md'), isNull);
      expect(WorkspaceRelativePath.tryCreate('/w', '/w/a.md'), isNotNull);
    });

    test('O3-5 合法欄位名', () {
      for (final n in ['blockedBy', 'spawned_tickets', 'a-b']) {
        expect(FieldName.tryCreate(n), isNotNull, reason: n);
      }
    });

    test('O3-6 不合法欄位名失敗並改記 fieldNameRejected', () {
      for (final n in ['a b', '欄位', '', '1abc', 'a' * 65]) {
        expect(FieldName.tryCreate(n), isNull, reason: n);
        expect(LogValue.fieldName(n).toJson(), 'fieldNameRejected');
      }
      expect(FieldName.tryCreate('a' * 64), isNotNull);
    });

    test('O3-7 合法節點 ID', () {
      for (final id in [
        'SPEC-007',
        'UC-03',
        '0.1.0-W1-001',
        '1.0.0-W3-553.2.1',
      ]) {
        expect(NodeId.tryCreate(id), isNotNull, reason: id);
      }
    });

    test('O3-8 不合法節點 ID 失敗並改記 nodeIdRejected', () {
      for (final id in ['a/b', 'a\nb', 'a' * 65]) {
        expect(NodeId.tryCreate(id), isNull, reason: id);
        expect(LogValue.nodeId(id).toJson(), 'nodeIdRejected');
      }
    });

    test('O3-9 commit SHA 只收 40 字元小寫十六進位', () {
      final ok = 'a1b2c3d4e5' * 4;
      expect(CommitSha.tryCreate(ok)?.toJson(), ok);
      expect(CommitSha.tryCreate('a' * 39), isNull);
      expect(CommitSha.tryCreate('${'a' * 39}g'), isNull);
      expect(CommitSha.tryCreate(ok.toUpperCase()), isNull);
    });

    test('O3-10 enum、整數、布林序列化', () {
      expect(
        const LogValue.enumValue(TestEvent.sampleFailed).toJson(),
        'sampleFailed',
      );
      expect(const LogValue.integer(7).toJson(), 7);
      expect(const LogValue.boolean(true).toJson(), true);
      expect(
        const LogValue.enumValue(LogLocation.appSupport).toJson(),
        'appSupport',
      );
    });
  });
}
