import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_record_encoder.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import 'observability_test_helpers.dart';

String _encode({
  String domain = 'graph',
  LogFields fields = LogFields.empty,
  DateTime? now,
  LogLevel level = LogLevel.info,
  ErrorSource? source,
  Object? error,
}) => encodeLogRecord(
  now: now ?? fixedClock(),
  level: level,
  domain: domain,
  event: TestEvent.sampleCompleted,
  fields: fields,
  source: source,
  error: error,
);

void main() {
  group('記錄信封', () {
    test('O1-1 一行 JSON、以換行結尾、必填欄位齊全', () {
      final line = _encode(
        fields: const LogFields({'count': LogValue.integer(3)}),
      );
      expect('\n'.allMatches(line).length, 1);
      expect(line.endsWith('\n'), isTrue);
      final m = jsonDecode(line) as Map<String, dynamic>;
      expect(m['ts'], isA<String>());
      expect(m['level'], 'info');
      expect(m['domain'], 'graph');
      expect(m['event'], isA<String>());
      expect(m['fields'], isA<Map<String, dynamic>>());
    });

    test('O1-2 fields 為空時為 {} 不省略', () {
      final m = jsonDecode(_encode()) as Map<String, dynamic>;
      expect(m['fields'], <String, dynamic>{});
    });

    test('O1-3 無例外無來源時不含 error_source / error_type', () {
      final m = jsonDecode(_encode()) as Map<String, dynamic>;
      expect(m.containsKey('error_source'), isFalse);
      expect(m.containsKey('error_type'), isFalse);
    });

    test('O1-4 ts 為 UTC ISO 8601 毫秒；本地時間先轉 UTC', () {
      final a = jsonDecode(_encode()) as Map<String, dynamic>;
      expect(a['ts'], '2026-11-10T13:52:06.123Z');
      final local = fixedClock().toLocal();
      final b = jsonDecode(_encode(now: local)) as Map<String, dynamic>;
      expect(b['ts'], '2026-11-10T13:52:06.123Z');
    });

    test('O1-5 event 為 enum 值名稱原樣', () {
      final m = jsonDecode(_encode()) as Map<String, dynamic>;
      expect(m['event'], 'sampleCompleted');
    });

    test('O1-6 domain 為空字串拋 ArgumentError，非空則正常（正向對照）', () {
      expect(_encode(), isNotEmpty);
      expect(() => _encode(domain: ''), throwsArgumentError);
    });
  });

  group('錯誤來源', () {
    test('O2-1 序列化值集合與 FR-02 分類表一致', () {
      expect(
        {for (final s in ErrorSource.values) s.wireName},
        {
          'platform_io',
          'external_process',
          'parse',
          'gate_blocked',
          'internal',
        },
      );
      expect(ErrorSource.values.length, 5);
    });

    test('O2-2 parse 加例外物件', () {
      final m = jsonDecode(
        _encode(source: ErrorSource.parse, error: StateError('x')),
      ) as Map<String, dynamic>;
      expect(m['error_source'], 'parse');
      expect(m['error_type'], 'StateError');
    });
  });
}
