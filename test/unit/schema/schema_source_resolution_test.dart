// S5 型別表來源三分（FR-06 規則 7；契約 K4，SPEC-006-test-design.md §3.1）。
//
// 依賴方向：test/unit/schema/ 不得 import lib/corpus/、lib/diagnostics/。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';

Map<String, dynamic> _schemaJson({
  required String version,
  required Map<String, dynamic> nodeTypes,
  Map<String, dynamic> completenessFields = const {},
}) => {
  'schema_generated_at_framework_version': version,
  'node_types': nodeTypes,
  'completeness_fields': completenessFields,
};

void main() {
  // 內建表：SPEC 型別帶一個會命中 `docs/spec/*.md` 的路徑模式，
  // id_pattern 與 S5-6 測試中使用的專案值刻意不同。
  final builtinJson = _schemaJson(
    version: '2.40.3',
    nodeTypes: {
      'SPEC': {
        'carrier_path_patterns': [
          {
            'pattern': r'^docs/spec/.+\.md$',
            'specificity': [1, 1],
          },
        ],
        'id_pattern': r'^SPEC-\d+$',
      },
    },
  );

  group('S5-1 專案 JSON 有路徑模式欄位', () {
    test('查詢以 JSON 的模式執行；模式來源回報為專案 JSON', () {
      final projectJson = _schemaJson(
        version: '9.9.9',
        nodeTypes: {
          'SPEC': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/spec/.+\.md$',
                'specificity': [1, 1],
              },
            ],
            'id_pattern': r'^SPEC-\d+$',
          },
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: builtinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.projectJson);
      expect(result.isPathPatternFromBuiltin, isFalse);
      expect(result.isQueryAvailable, isTrue);
      expect(
        result.typeTable.nodeTypes['SPEC']!.carrierPathPatterns,
        isNotNull,
      );
    });
  });

  group('S5-2 專案 JSON 缺欄位，JSON 版本等於內建版本', () {
    test('路徑模式取自內建表；id_pattern、完整性集合仍取自專案 JSON；模式來源回報為內建表', () {
      final projectJson = _schemaJson(
        version: '2.40.3',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
        completenessFields: {
          'SPEC': ['id', 'title', 'status'],
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: builtinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.builtinTable);
      expect(result.isPathPatternFromBuiltin, isTrue);
      expect(result.isQueryAvailable, isTrue);

      final specEntry = result.typeTable.nodeTypes['SPEC']!;
      expect(specEntry.carrierPathPatterns, isNotNull);
      expect(specEntry.carrierPathPatterns!.single.pattern, r'^docs/spec/.+\.md$');
      expect(specEntry.idPattern, r'^SPEC-\d+-project$');
      expect(specEntry.completenessFields, {'id', 'title', 'status'});
    });
  });

  group('S5-3 專案 JSON 缺欄位，JSON 版本低於內建版本', () {
    test('同 S5-2：路徑模式取自內建表', () {
      final projectJson = _schemaJson(
        version: '2.30.0',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: builtinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.builtinTable);
      expect(result.isQueryAvailable, isTrue);
    });
  });

  group('S5-4（守衛）專案 JSON 缺欄位，JSON 版本高於內建版本', () {
    test('查詢不可用', () {
      final projectJson = _schemaJson(
        version: '2.41.0',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: builtinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.unavailable);
      expect(result.isQueryAvailable, isFalse);
      expect(result.isPathPatternFromBuiltin, isFalse);
    });

    test('正向對照：同一 JSON 版本改為等於內建即可用（S5-2 反覆驗證守衛有鑑別力）', () {
      final equalVersionJson = _schemaJson(
        version: '2.40.3',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: equalVersionJson,
        builtinSchemaJson: builtinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.builtinTable);
      expect(result.isQueryAvailable, isTrue);
    });
  });

  group('S5-5 專案 JSON 與內建表都沒有路徑模式', () {
    test('查詢不可用', () {
      final emptyBuiltinJson = _schemaJson(version: '2.40.3', nodeTypes: {
        'SPEC': {'id_pattern': r'^SPEC-\d+$'},
      });
      final projectJson = _schemaJson(
        version: '1.0.0',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: emptyBuiltinJson,
      );

      expect(result.pathPatternSource, PathPatternSource.unavailable);
      expect(result.isQueryAvailable, isFalse);
    });
  });

  group('S5-6（E1 鑑別）S5-2 的型別表，專案 JSON id_pattern 刻意與內建表不同', () {
    test('判型用專案 JSON 的 id_pattern（證明只補路徑模式，非整表替換）', () {
      final projectJson = _schemaJson(
        version: '2.40.3',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^PROJECT-ONLY-\d+$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectJson,
        builtinSchemaJson: builtinJson,
      );

      final specEntry = result.typeTable.nodeTypes['SPEC']!;
      expect(specEntry.idPattern, r'^PROJECT-ONLY-\d+$');
      expect(specEntry.idPattern, isNot(builtinJson['node_types']['SPEC']['id_pattern']));
      // 正向對照：路徑模式確實來自內建表（否則本案例對「只補路徑模式」無鑑別力）。
      expect(specEntry.carrierPathPatterns!.single.pattern, r'^docs/spec/.+\.md$');
    });
  });

  group('S5-7 版本比較', () {
    test('2.40.3 對 2.40.10 判為低於（數值逐段比較，非字串比較）', () {
      final builtinAtDot10 = _schemaJson(
        version: '2.40.10',
        nodeTypes: {
          'SPEC': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/spec/.+\.md$',
                'specificity': [1, 1],
              },
            ],
            'id_pattern': r'^SPEC-\d+$',
          },
        },
      );
      final projectAtDot3 = _schemaJson(
        version: '2.40.3',
        nodeTypes: {
          'SPEC': {'id_pattern': r'^SPEC-\d+-project$'},
        },
      );

      final result = resolveSchemaSource(
        projectSchemaJson: projectAtDot3,
        builtinSchemaJson: builtinAtDot10,
      );

      // 若採字串比較，"2.40.3" > "2.40.10" 會成立（'3' > '1'），得到 unavailable；
      // 數值逐段比較下 2.40.3 < 2.40.10，應可從內建表補上。
      expect(result.pathPatternSource, PathPatternSource.builtinTable);
      expect(result.isQueryAvailable, isTrue);
    });
  });
}
