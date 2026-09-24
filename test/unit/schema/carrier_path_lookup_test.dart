// FR-06 路徑對型別查詢（SPEC-006-test-design.md §3.1 S1～S4）。
//
// 本檔只用 test/helpers/spec006/type_table_builder.dart 建構的最小型別表，
// 不讀專案或內建的 tracking_schema.json（依賴方向：test/unit/schema/ 不得
// import lib/corpus/、lib/diagnostics/，§1.3）。S1、S2-1 需要「真實型別表」
// 語意的案例，以與 tracking_schema.py 一致的路徑模式在本檔內宣告，不依賴
// 另一支 real_type_table.dart helper（該 helper 不在本票 where.files 範圍）。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/spec006/type_table_builder.dart';

/// 與 `.claude/skills/doc/doc_system/core/tracking_schema.py` 的
/// `GRAPH_NODE_TYPES` 一致的最小子集：SPEC、UC、Ticket、DomainBundle。
TypeTable _realLikeTypeTable() {
  return TypeTableBuilder()
      .addType(
        'SPEC',
        carrierPathPatterns: const [
          PathPatternSpec(
            pattern: r'^docs/spec/[^/]+/(?!README\.md$)[^/]+\.md$',
            specificity: [2, 0],
          ),
        ],
      )
      .addType(
        'UC',
        carrierPathPatterns: const [
          PathPatternSpec(
            pattern: r'^docs/usecases/UC-\d{2,}-[^/]+\.md$',
            specificity: [2, 0],
          ),
        ],
      )
      .addType(
        'Ticket',
        carrierPathPatterns: const [
          PathPatternSpec(
            pattern: r'^docs/work-logs/(?:[^/]+/)+tickets/[^/]+\.md$',
            specificity: [3, 1],
          ),
        ],
      )
      .addType(
        'DomainBundle',
        carrierPathPatterns: const [
          PathPatternSpec(
            pattern: r'^docs/spec/[^/]+/domain-map\.md$',
            specificity: [3, 0],
          ),
          PathPatternSpec(
            pattern: r'^docs/domain-map\.md$',
            specificity: [2, 0],
          ),
        ],
      )
      .build();
}

void main() {
  group('完整路徑與大小寫（S1，FR-06 規則 1、4）', () {
    final table = _realLikeTypeTable();

    test('S1-1（守衛）docs/spec/ui/README.md 未命中', () {
      final result = lookupCarrierPathType(table, 'docs/spec/ui/README.md');
      expect(result, isA<CarrierPathNoMatch>());
    });

    test('S1-2（S1-1 正向對照）docs/spec/ui/SPEC-001-x.md 命中 SPEC', () {
      final result = lookupCarrierPathType(table, 'docs/spec/ui/SPEC-001-x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'SPEC');
    });

    test('S1-3 docs/work-logs/v0/note.md 未命中', () {
      final result = lookupCarrierPathType(table, 'docs/work-logs/v0/note.md');
      expect(result, isA<CarrierPathNoMatch>());
    });

    test('S1-4（S1-3 正向對照）docs/work-logs/v0/v0.1/tickets/0.1.0-W1-001.md 命中 Ticket', () {
      final result = lookupCarrierPathType(
        table,
        'docs/work-logs/v0/v0.1/tickets/0.1.0-W1-001.md',
      );
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'Ticket');
    });

    test('S1-5 大小寫不同的路徑皆未命中（區分大小寫）', () {
      final specResult = lookupCarrierPathType(table, 'docs/Spec/ui/SPEC-001-x.md');
      final ucResult = lookupCarrierPathType(table, 'docs/usecases/uc-01-x.md');
      expect(specResult, isA<CarrierPathNoMatch>());
      expect(ucResult, isA<CarrierPathNoMatch>());
    });

    test('S1-6（S1-5 正向對照）docs/usecases/UC-01-x.md 命中 UC', () {
      final result = lookupCarrierPathType(table, 'docs/usecases/UC-01-x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'UC');
    });

    test('S1-7 比對含檔名：目錄可匹配但副檔名不符者未命中', () {
      final dirOnlyTable = TypeTableBuilder()
          .addType(
            'TestDirType',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/testdir/[^/]+\.md$',
                specificity: [2, 0],
              ),
            ],
          )
          .build();

      final result = lookupCarrierPathType(dirOnlyTable, 'docs/testdir/thing.txt');
      expect(result, isA<CarrierPathNoMatch>());

      // 正向對照：同目錄、同檔名主幹，副檔名為 .md 時應命中。
      final positive = lookupCarrierPathType(dirOnlyTable, 'docs/testdir/thing.md');
      expect(positive, isA<CarrierPathSingleMatch>());
    });
  });

  group('具體度（S2，FR-06 規則 6）', () {
    test('S2-1 docs/spec/corpus/domain-map.md 回傳 DomainBundle（字面段 3 > SPEC 的 2）', () {
      final table = _realLikeTypeTable();
      final result = lookupCarrierPathType(table, 'docs/spec/corpus/domain-map.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'DomainBundle');
    });

    test('S2-2 字面段多者優先，即使跨段萬用較多', () {
      final table = TypeTableBuilder()
          .addType(
            'A',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/multi\.md$', specificity: [3, 1]),
            ],
          )
          .addType(
            'B',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/multi\.md$', specificity: [2, 0]),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/multi.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'A');
    });

    test('S2-3 字面段相同時，跨段萬用少者優先', () {
      final table = TypeTableBuilder()
          .addType(
            'A',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/multi\.md$', specificity: [2, 1]),
            ],
          )
          .addType(
            'B',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/multi\.md$', specificity: [2, 0]),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/multi.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'B');
    });

    test('S2-4 同一型別多個模式元素，取命中元素中最高具體度參與比較', () {
      final table = TypeTableBuilder()
          .addType(
            'DomainBundle',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/spec/[^/]+/domain-map\.md$',
                specificity: [3, 0],
              ),
              PathPatternSpec(
                pattern: r'^docs/domain-map\.md$',
                specificity: [2, 0],
              ),
            ],
          )
          .addType(
            'Rival',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/spec/[^/]+/domain-map\.md$',
                specificity: [2, 1],
              ),
            ],
          )
          .build();

      // 巢狀路徑命中 DomainBundle 具體度 [3,0]（優於 Rival 的 [2,1]），
      // 而非誤取 DomainBundle 根層元素的 [2,0]。
      final result = lookupCarrierPathType(table, 'docs/spec/ui/domain-map.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'DomainBundle');
    });
  });

  group('平手（S3，FR-06 規則 5、6）', () {
    test('S3-1 具體度皆 [2,0] → 平手，候選為 {A, B}', () {
      final table = TypeTableBuilder()
          .addType(
            'A',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie\.md$', specificity: [2, 0]),
            ],
          )
          .addType(
            'B',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie\.md$', specificity: [2, 0]),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/tie.md');
      expect(result, isA<CarrierPathTie>());
      expect((result as CarrierPathTie).candidateTypeNames, ['A', 'B']);
    });

    test('S3-2 三型打平，候選列出全部三型', () {
      final table = TypeTableBuilder()
          .addType(
            'A',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie3\.md$', specificity: [1, 0]),
            ],
          )
          .addType(
            'B',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie3\.md$', specificity: [1, 0]),
            ],
          )
          .addType(
            'C',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie3\.md$', specificity: [1, 0]),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/tie3.md');
      expect(result, isA<CarrierPathTie>());
      expect((result as CarrierPathTie).candidateTypeNames, ['A', 'B', 'C']);
    });

    test('S3-3（S3-1 鑑別對照）B 改為 [3,0] 後回傳 B，不再平手', () {
      final table = TypeTableBuilder()
          .addType(
            'A',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie\.md$', specificity: [2, 0]),
            ],
          )
          .addType(
            'B',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/tie\.md$', specificity: [3, 0]),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/tie.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'B');
    });

    test('S3-4 回傳值型別窮舉三種結果，無第四種', () {
      CarrierPathLookupResult classify(CarrierPathLookupResult r) => r;

      String describe(CarrierPathLookupResult result) {
        // sealed class 的 switch 必須窮盡所有子型別，缺一種即編譯錯誤，
        // 此測試本身即為「無第四種」的靜態證明。
        return switch (classify(result)) {
          CarrierPathNoMatch() => 'no_match',
          CarrierPathSingleMatch() => 'single_match',
          CarrierPathTie() => 'tie',
        };
      }

      expect(describe(const CarrierPathNoMatch()), 'no_match');
      expect(describe(const CarrierPathSingleMatch('X')), 'single_match');
      expect(describe(CarrierPathTie(['X', 'Y'])), 'tie');
    });
  });

  group('無路徑模式的型別不參與（S4，FR-06 規則 3、SPEC-006 D9）', () {
    test('S4-1（守衛）FlowStep 不帶 carrierPathPatterns，查 UC 路徑回傳 UC', () {
      final table = TypeTableBuilder()
          .addType('FlowStep') // 不傳 carrierPathPatterns：欄位不存在
          .addType(
            'UC',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/usecases/UC-\d{2,}-[^/]+\.md$',
                specificity: [2, 0],
              ),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/usecases/UC-01-x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'UC');
    });

    test('S4-2 任意不帶欄位的型別從不出現在結果中（排除依欄位而非型別名）', () {
      final table = TypeTableBuilder().addType('Widget').build();

      final result = lookupCarrierPathType(table, 'docs/anything/x.md');
      expect(result, isA<CarrierPathNoMatch>());
    });

    test('S4-3（S4-1 正向對照）同名 FlowStep 改為帶命中模式後會參與比較並形成候選', () {
      final table = TypeTableBuilder()
          .addType(
            'FlowStep',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/usecases/UC-\d{2,}-[^/]+\.md$',
                specificity: [2, 0],
              ),
            ],
          )
          .addType(
            'UC',
            carrierPathPatterns: const [
              PathPatternSpec(
                pattern: r'^docs/usecases/UC-\d{2,}-[^/]+\.md$',
                specificity: [2, 0],
              ),
            ],
          )
          .build();

      final result = lookupCarrierPathType(table, 'docs/usecases/UC-01-x.md');
      expect(result, isA<CarrierPathTie>());
      expect((result as CarrierPathTie).candidateTypeNames, ['FlowStep', 'UC']);
    });
  });

  group('載入時驗證壞模式（規則 1、NFR-01，0.3.0-W3-531）', () {
    test('壞的 pattern 被拒收，不中止整輪掃描，同批合法模式照常載入', () {
      final json = {
        'node_types': {
          'Broken': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/broken/(.md$', // 括號未閉合，非法 regex
                'specificity': [1, 0],
              },
            ],
          },
          'Good': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/good/[^/]+\.md$',
                'specificity': [2, 0],
              },
            ],
          },
        },
      };

      final table = typeTableFromJson(json);

      expect(table.nodeTypes['Broken']!.carrierPathPatterns, isEmpty);
      expect(table.nodeTypes['Good']!.carrierPathPatterns, hasLength(1));

      final result = lookupCarrierPathType(table, 'docs/good/x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'Good');
    });

    test('（正向對照）全部型別皆合法時，壞模式路徑不存在，兩型皆正常載入', () {
      final json = {
        'node_types': {
          'A': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/a/[^/]+\.md$',
                'specificity': [2, 0],
              },
            ],
          },
          'B': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/b/[^/]+\.md$',
                'specificity': [2, 0],
              },
            ],
          },
        },
      };

      final table = typeTableFromJson(json);

      expect(table.nodeTypes['A']!.carrierPathPatterns, hasLength(1));
      expect(table.nodeTypes['B']!.carrierPathPatterns, hasLength(1));
    });

    test('specificity 長度不對的模式在解析時被拒收，不影響其他合法模式', () {
      final json = {
        'node_types': {
          'Broken': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/broken/[^/]+\.md$',
                'specificity': [1], // 長度應為 2
              },
            ],
          },
          'Good': {
            'carrier_path_patterns': [
              {
                'pattern': r'^docs/good/[^/]+\.md$',
                'specificity': [2, 0],
              },
            ],
          },
        },
      };

      final table = typeTableFromJson(json);

      expect(table.nodeTypes['Broken']!.carrierPathPatterns, isEmpty);
      expect(table.nodeTypes['Good']!.carrierPathPatterns, hasLength(1));
    });

    test('壞的 id_pattern 被拒收為 null，不影響其他欄位', () {
      final json = {
        'node_types': {
          'Broken': {
            'id_pattern': r'^SPEC-(\d+$', // 括號未閉合
          },
        },
      };

      final table = typeTableFromJson(json);

      expect(table.nodeTypes['Broken']!.idPattern, isNull);
    });

    test('（正向對照）合法 id_pattern 正常載入', () {
      final json = {
        'node_types': {
          'Good': {'id_pattern': r'^SPEC-\d+$'},
        },
      };

      final table = typeTableFromJson(json);

      expect(table.nodeTypes['Good']!.idPattern, r'^SPEC-\d+$');
    });
  });

  group('查詢不重編 RegExp（規則 2，0.3.0-W3-531）', () {
    test('同一 CarrierPathPattern 兩次 toRegExp() 回傳同一個 RegExp 實例', () {
      final pattern = CarrierPathPattern(
        pattern: r'^docs/x\.md$',
        specificity: (literalSegmentCount: 1, crossSegmentWildcardCount: 0),
      );

      expect(identical(pattern.toRegExp(), pattern.toRegExp()), isTrue);
    });
  });

  group('具體度比較單一來源（規則 6，0.3.0-W3-531）', () {
    test('comparePathSpecificity：字面段數多者優先', () {
      const a = (literalSegmentCount: 3, crossSegmentWildcardCount: 1);
      const b = (literalSegmentCount: 2, crossSegmentWildcardCount: 0);
      expect(comparePathSpecificity(a, b), lessThan(0));
    });

    test('comparePathSpecificity：字面段數相同時，跨段萬用少者優先', () {
      const a = (literalSegmentCount: 2, crossSegmentWildcardCount: 0);
      const b = (literalSegmentCount: 2, crossSegmentWildcardCount: 1);
      expect(comparePathSpecificity(a, b), lessThan(0));
    });

    test('comparePathSpecificity：完全相同時回傳 0（平手）', () {
      const a = (literalSegmentCount: 2, crossSegmentWildcardCount: 1);
      const b = (literalSegmentCount: 2, crossSegmentWildcardCount: 1);
      expect(comparePathSpecificity(a, b), 0);
    });
  });

  group('isPathQueryAvailable（規則 3/7，0.3.0-W3-531）', () {
    test('有帶 carrierPathPatterns 的型別時為 true', () {
      final table = TypeTableBuilder()
          .addType(
            'SPEC',
            carrierPathPatterns: const [
              PathPatternSpec(pattern: r'^docs/spec/.+\.md$', specificity: [1, 0]),
            ],
          )
          .build();

      expect(table.isPathQueryAvailable, isTrue);
    });

    test('（守衛，正向對照）沒有任何型別帶 carrierPathPatterns 時為 false', () {
      final table = TypeTableBuilder().addType('FlowStep').build();

      expect(table.isPathQueryAvailable, isFalse);
    });
  });

  group('id_pattern 建構時預編譯（0.3.0-W3-540）', () {
    test('同一 NodeTypeEntry 兩次取用 idRegExp 回傳同一個 RegExp 實例', () {
      final entry = NodeTypeEntry(name: 'SPEC', idPattern: r'^SPEC-\d+$');

      expect(identical(entry.idRegExp, entry.idRegExp), isTrue);
    });

    test('idPattern 為 null 時 idRegExp 亦為 null', () {
      final entry = NodeTypeEntry(name: 'FlowStep');

      expect(entry.idRegExp, isNull);
    });
  });
}
